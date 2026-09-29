"""Insert one dispense event into Databricks as it happens.

Uses the SQL Statement Execution API against a SQL warehouse. The local JSONL
file is still written; this is the extra hop that makes the same row appear in
a Bronze table during a demo.

Required environment variables:

    DATABRICKS_HOST          workspace URL, with or without https://
    DATABRICKS_TOKEN         a personal access token
    DATABRICKS_WAREHOUSE_ID  the SQL warehouse that runs the INSERT

Optional, with these defaults:

    DATABRICKS_CATALOG       unset — look up the catalog that holds the table
    DATABRICKS_SCHEMA        pill_dispenser
    DATABRICKS_TABLE         bronze_dispense_events

The live table is pill_dispenser.bronze_dispense_events. With the catalog unset,
the sink asks system.information_schema which catalog that table is in, then
inserts there. The warehouse default (often main) is not assumed. Set
DATABRICKS_CATALOG only to skip that lookup.

Create the table once with databricks/sql/bronze_dispense_events.sql.
Copy edge/.env.example to edge/.env and fill in the three values. The sink
reads that file on startup. A variable already set in the shell wins.
If the host, token, or warehouse is still unset, the sink stays off and the
pipeline keeps logging locally.
"""

from __future__ import annotations

import json
import logging
import os
import re
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlparse, urlunparse

logger = logging.getLogger(__name__)

_IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
_TERMINAL = {"SUCCEEDED", "FAILED", "CANCELED", "CLOSED"}

INSERT_SQL = """
INSERT INTO {table} (
  event_ts,
  patient_id,
  face_match_confidence,
  pills_detected,
  dispense_latency_ms,
  event_status,
  hardware_source,
  retry_count
) VALUES (
  CAST(:event_ts AS TIMESTAMP),
  :patient_id,
  :face_match_confidence,
  :pills_detected,
  :dispense_latency_ms,
  :event_status,
  :hardware_source,
  :retry_count
)
""".strip()

# Identifiers below are validated before this is formatted. A parameterized
# comparison against information_schema is not reliable on every warehouse.
LOOKUP_SQL = """
SELECT table_catalog
FROM system.information_schema.tables
WHERE table_schema = '{schema}'
  AND table_name = '{table}'
""".strip()


@dataclass(frozen=True)
class DatabricksConfig:
    host: str
    token: str
    warehouse_id: str
    catalog: str | None
    schema: str
    table: str

    @property
    def table_sql(self) -> str:
        return self.table

    @property
    def qualified_name(self) -> str:
        if self.catalog:
            return f"{self.catalog}.{self.schema}.{self.table}"
        return f"{self.schema}.{self.table}"


def _identifier(value: str, name: str) -> str:
    if not _IDENT.match(value):
        raise ValueError(f"{name} must be a plain SQL identifier, got {value!r}")
    return value


def normalize_host(host: str) -> str:
    """Workspace root only. A browser path such as /oidc makes the API URL 404."""
    host = host.strip().rstrip("/")
    if not host.startswith("http://") and not host.startswith("https://"):
        host = "https://" + host
    parsed = urlparse(host)
    return urlunparse((parsed.scheme, parsed.netloc, "", "", "", ""))


def parse_dotenv(text: str) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[len("export ") :].strip()
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
            value = value[1:-1]
        if key:
            values[key] = value
    return values


def load_dotenv() -> None:
    """Load edge/.env, then the repo-root .env, then the current directory.

    Existing process environment variables are left alone, so a shell override
    still wins. Values are never logged.
    """
    candidates = [
        Path(__file__).resolve().parent / ".env",
        Path(__file__).resolve().parent.parent / ".env",
        Path.cwd() / ".env",
    ]
    seen: set[Path] = set()
    for path in candidates:
        if path in seen or not path.is_file():
            continue
        seen.add(path)
        try:
            parsed = parse_dotenv(path.read_text(encoding="utf-8"))
        except OSError as exc:
            logger.error("event=dotenv_read_failed path=%s error=%s", path, exc)
            continue
        applied = 0
        for key, value in parsed.items():
            if key not in os.environ:
                os.environ[key] = value
                applied += 1
        logger.info("event=dotenv_loaded path=%s keys=%s", path, applied)


def config_from_env(env: dict[str, str] | None = None) -> DatabricksConfig | None:
    """Return a config when the three required variables are set, else None."""
    source = os.environ if env is None else env
    host = source.get("DATABRICKS_HOST", "").strip()
    token = source.get("DATABRICKS_TOKEN", "").strip()
    warehouse = source.get("DATABRICKS_WAREHOUSE_ID", "").strip()
    if not host or not token or not warehouse:
        return None
    raw_catalog = source.get("DATABRICKS_CATALOG", "").strip()
    catalog = _identifier(raw_catalog, "catalog") if raw_catalog else None
    schema = _identifier(source.get("DATABRICKS_SCHEMA", "pill_dispenser").strip() or "pill_dispenser", "schema")
    table = _identifier(
        source.get("DATABRICKS_TABLE", "bronze_dispense_events").strip() or "bronze_dispense_events",
        "table",
    )
    return DatabricksConfig(
        host=normalize_host(host),
        token=token,
        warehouse_id=warehouse,
        catalog=catalog,
        schema=schema,
        table=table,
    )


def _parameters(event: dict) -> list[dict[str, str]]:
    return [
        {"name": "event_ts", "value": str(event["timestamp"]), "type": "STRING"},
        {"name": "patient_id", "value": str(event["patient_id"]), "type": "STRING"},
        {"name": "face_match_confidence", "value": str(event["face_match_confidence"]), "type": "DOUBLE"},
        {"name": "pills_detected", "value": str(int(event["pills_detected"])), "type": "INT"},
        {"name": "dispense_latency_ms", "value": str(int(event["dispense_latency_ms"])), "type": "INT"},
        {"name": "event_status", "value": str(event["event_status"]), "type": "STRING"},
        {"name": "hardware_source", "value": str(event["hardware_source"]), "type": "STRING"},
        {"name": "retry_count", "value": str(int(event.get("retry_count", 0))), "type": "INT"},
    ]


class UrllibStatementClient:
    """POST and GET against /api/2.0/sql/statements. The token is a header only."""

    def __init__(self, host: str, token: str, timeout_s: float = 30.0) -> None:
        self._host = host
        self._token = token
        self._timeout_s = timeout_s

    def post_statement(self, payload: dict) -> dict:
        return self._request("POST", "/api/2.0/sql/statements", payload)

    def get_statement(self, statement_id: str) -> dict:
        return self._request("GET", f"/api/2.0/sql/statements/{statement_id}", None)

    def _request(self, method: str, path: str, payload: dict | None) -> dict:
        body = None if payload is None else json.dumps(payload).encode("utf-8")
        request = urllib.request.Request(
            self._host + path,
            data=body,
            method=method,
            headers={
                "Authorization": f"Bearer {self._token}",
                "Content-Type": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=self._timeout_s) as response:
                raw = response.read().decode("utf-8")
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")[:500]
            logger.error("event=databricks_http_error status=%s body=%s", exc.code, detail)
            raise
        except (urllib.error.URLError, TimeoutError, OSError) as exc:
            logger.error("event=databricks_transport_error error=%s", exc)
            raise
        try:
            return json.loads(raw) if raw else {}
        except json.JSONDecodeError as exc:
            logger.error("event=databricks_bad_json error=%s", exc)
            raise


def _data_rows(result: dict) -> list[list[str]]:
    data = (result.get("result") or {}).get("data_array") or []
    rows: list[list[str]] = []
    for row in data:
        if isinstance(row, list):
            rows.append(["" if cell is None else str(cell) for cell in row])
    return rows


class DatabricksSink:
    def __init__(self, config: DatabricksConfig, client: UrllibStatementClient) -> None:
        self._config = config
        self._client = client
        self._resolved_catalog = config.catalog

    @classmethod
    def from_env(cls, env: dict[str, str] | None = None) -> "DatabricksSink | None":
        if env is None:
            load_dotenv()
        config = config_from_env(env)
        if config is None:
            logger.info("event=databricks_sink_off reason=missing_host_token_or_warehouse")
            return None
        logger.info(
            "event=databricks_sink_on host=%s table=%s",
            config.host,
            config.qualified_name,
        )
        return cls(config, UrllibStatementClient(config.host, config.token))

    def send(self, event: dict) -> bool:
        """Insert one telemetry dict. False on any failure; the caller keeps going."""
        catalog = self._catalog_for_insert()
        if catalog is None:
            return False
        payload = {
            "warehouse_id": self._config.warehouse_id,
            "catalog": catalog,
            "schema": self._config.schema,
            "statement": INSERT_SQL.format(table=self._config.table_sql),
            "parameters": _parameters(event),
            "wait_timeout": "30s",
            "on_wait_timeout": "CANCEL",
        }
        try:
            result = self._execute(payload)
        except Exception:
            logger.exception(
                "event=databricks_insert_failed patient_id=%s",
                event.get("patient_id"),
            )
            return False

        state = (result.get("status") or {}).get("state", "")
        statement_id = result.get("statement_id", "")
        table_name = f"{catalog}.{self._config.schema}.{self._config.table}"
        if state == "SUCCEEDED":
            logger.info(
                "event=databricks_insert_ok statement_id=%s patient_id=%s table=%s",
                statement_id,
                event.get("patient_id"),
                table_name,
            )
            return True
        error = (result.get("status") or {}).get("error") or {}
        logger.error(
            "event=databricks_insert_rejected state=%s statement_id=%s message=%s",
            state,
            statement_id,
            error.get("message", ""),
        )
        return False

    def _catalog_for_insert(self) -> str | None:
        if self._resolved_catalog:
            return self._resolved_catalog
        found = self._lookup_catalog()
        if found:
            self._resolved_catalog = found
        return found

    def _lookup_catalog(self) -> str | None:
        """Find the one catalog that holds schema.table. None if that is not unique."""
        schema = self._config.schema
        table = self._config.table
        payload = {
            "warehouse_id": self._config.warehouse_id,
            "statement": LOOKUP_SQL.format(schema=schema, table=table),
            "wait_timeout": "30s",
            "on_wait_timeout": "CANCEL",
        }
        try:
            result = self._execute(payload)
        except Exception:
            logger.exception(
                "event=databricks_catalog_lookup_failed table=%s.%s",
                schema,
                table,
            )
            return None
        state = (result.get("status") or {}).get("state", "")
        if state != "SUCCEEDED":
            error = (result.get("status") or {}).get("error") or {}
            logger.error(
                "event=databricks_catalog_lookup_rejected state=%s message=%s",
                state,
                error.get("message", ""),
            )
            return None
        catalogs: list[str] = []
        for row in _data_rows(result):
            name = row[0].strip() if row else ""
            if not name:
                continue
            if not _IDENT.match(name):
                logger.error("event=databricks_catalog_unusable catalog=%s", name)
                continue
            if name not in catalogs:
                catalogs.append(name)
        if len(catalogs) == 1:
            logger.info(
                "event=databricks_catalog_resolved catalog=%s table=%s.%s",
                catalogs[0],
                schema,
                table,
            )
            return catalogs[0]
        if not catalogs:
            logger.error(
                "event=databricks_table_missing table=%s.%s",
                schema,
                table,
            )
            return None
        logger.error(
            "event=databricks_catalog_ambiguous catalogs=%s table=%s.%s",
            ",".join(catalogs),
            schema,
            table,
        )
        return None

    def _execute(self, payload: dict) -> dict:
        result = self._client.post_statement(payload)
        for _ in range(5):
            state = (result.get("status") or {}).get("state", "")
            if state in _TERMINAL:
                return result
            statement_id = result.get("statement_id")
            if not statement_id:
                return result
            time.sleep(0.5)
            result = self._client.get_statement(statement_id)
        return result


def latest_logged_event(directory: Path | None = None) -> dict | None:
    """Return the last dispense event already written under logs/telemetry."""
    folder = directory if directory is not None else Path(__file__).resolve().parent / "logs" / "telemetry"
    try:
        files = sorted(folder.glob("dispense_events_*.jsonl"))
    except OSError as exc:
        logger.error("event=telemetry_log_unreadable path=%s error=%s", folder, exc)
        return None
    last = ""
    for path in files:
        try:
            text = path.read_text(encoding="utf-8")
        except OSError as exc:
            logger.error("event=telemetry_log_unreadable path=%s error=%s", path, exc)
            continue
        for line in text.splitlines():
            if line.strip():
                last = line.strip()
    if not last:
        return None
    try:
        event = json.loads(last)
    except json.JSONDecodeError as exc:
        logger.error("event=telemetry_log_bad_json error=%s", exc)
        return None
    required = {
        "timestamp",
        "patient_id",
        "face_match_confidence",
        "pills_detected",
        "dispense_latency_ms",
        "event_status",
        "hardware_source",
    }
    if not isinstance(event, dict) or not required <= event.keys():
        logger.error("event=telemetry_log_incomplete")
        return None
    return event


def main() -> int:
    """Insert the latest logged dispense event. A fake row is used only when no log exists."""
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s [%(name)s] %(message)s")
    sink = DatabricksSink.from_env()
    if sink is None:
        logger.error("event=databricks_test_skipped reason=missing_env")
        return 2
    event = latest_logged_event()
    if event is None:
        from telemetry import build_event

        event = build_event(
            face_match_confidence=0.0,
            pills_detected=0,
            dispense_latency_ms=0,
            event_status="failure",
            hardware_source="mock",
            patient_id="databricks_path_test",
            retry_count=0,
        ).to_dict()
        logger.info("event=databricks_using_placeholder patient_id=%s", event["patient_id"])
    else:
        logger.info(
            "event=databricks_using_logged_event patient_id=%s event_status=%s",
            event.get("patient_id"),
            event.get("event_status"),
        )
    return 0 if sink.send(event) else 1


if __name__ == "__main__":
    raise SystemExit(main())
