"""The Databricks insert is parameterized, and a down warehouse does not raise."""

from __future__ import annotations

import json

from databricks_sink import (
    DatabricksConfig,
    DatabricksSink,
    config_from_env,
    normalize_host,
    parse_dotenv,
)


class _FakeClient:
    def __init__(self, responses: list[dict]) -> None:
        self._responses = list(responses)
        self.posted: list[dict] = []
        self.gets: list[str] = []

    def post_statement(self, payload: dict) -> dict:
        self.posted.append(payload)
        return self._responses.pop(0)

    def get_statement(self, statement_id: str) -> dict:
        self.gets.append(statement_id)
        return self._responses.pop(0)


def _config() -> DatabricksConfig:
    return DatabricksConfig(
        host="https://example.cloud.databricks.com",
        token="secret-token",
        warehouse_id="wh-1",
        catalog="main",
        schema="pill_dispenser",
        table="bronze_dispense_events",
    )


def _event() -> dict:
    return {
        "timestamp": "2026-09-29T15:00:00.000Z",
        "patient_id": "patient_demo_001",
        "face_match_confidence": 0.97,
        "pills_detected": 1,
        "dispense_latency_ms": 1019,
        "event_status": "success",
        "hardware_source": "serial",
        "retry_count": 0,
    }


def test_missing_env_disables_the_sink() -> None:
    assert config_from_env({}) is None
    assert config_from_env({"DATABRICKS_HOST": "https://x"}) is None


def test_host_without_scheme_is_https() -> None:
    assert normalize_host("adb-1.cloud.databricks.com/") == "https://adb-1.cloud.databricks.com"


def test_browser_path_is_stripped_from_the_host() -> None:
    assert normalize_host("https://dbc-1.cloud.databricks.com/oidc") == "https://dbc-1.cloud.databricks.com"


def test_dotenv_parser_skips_comments_and_quotes() -> None:
    parsed = parse_dotenv(
        """
        # comment
        DATABRICKS_HOST=https://example.cloud.databricks.com
        DATABRICKS_TOKEN="dapi-secret"
        export DATABRICKS_WAREHOUSE_ID=wh-1
        """
    )
    assert parsed["DATABRICKS_HOST"] == "https://example.cloud.databricks.com"
    assert parsed["DATABRICKS_TOKEN"] == "dapi-secret"
    assert parsed["DATABRICKS_WAREHOUSE_ID"] == "wh-1"


def test_table_name_cannot_carry_sql() -> None:
    try:
        config_from_env(
            {
                "DATABRICKS_HOST": "https://x",
                "DATABRICKS_TOKEN": "t",
                "DATABRICKS_WAREHOUSE_ID": "w",
                "DATABRICKS_TABLE": "bronze; DROP TABLE bronze",
            }
        )
    except ValueError:
        return
    raise AssertionError("identifier with SQL was accepted")


def test_unset_catalog_is_omitted_from_the_statement() -> None:
    config = config_from_env(
        {
            "DATABRICKS_HOST": "https://x",
            "DATABRICKS_TOKEN": "t",
            "DATABRICKS_WAREHOUSE_ID": "w",
            "DATABRICKS_CATALOG": "   ",
        }
    )
    assert config is not None
    assert config.catalog is None
    assert config.schema == "pill_dispenser"
    assert config.table == "bronze_dispense_events"
    assert config.qualified_name == "pill_dispenser.bronze_dispense_events"
    client = _FakeClient([{"statement_id": "s-0", "status": {"state": "SUCCEEDED"}}])
    sink = DatabricksSink(config, client)
    assert sink.send(_event()) is True
    payload = client.posted[0]
    assert "catalog" not in payload
    assert payload["schema"] == "pill_dispenser"
    assert "INSERT INTO bronze_dispense_events" in payload["statement"]


def test_insert_uses_parameters_and_not_the_token_in_the_body() -> None:
    client = _FakeClient([{"statement_id": "s-1", "status": {"state": "SUCCEEDED"}}])
    sink = DatabricksSink(_config(), client)
    assert sink.send(_event()) is True
    payload = client.posted[0]
    assert payload["warehouse_id"] == "wh-1"
    assert payload["catalog"] == "main"
    assert payload["schema"] == "pill_dispenser"
    assert ":patient_id" in payload["statement"]
    assert "patient_demo_001" not in payload["statement"]
    names = {item["name"]: item for item in payload["parameters"]}
    assert names["patient_id"]["value"] == "patient_demo_001"
    assert names["face_match_confidence"]["type"] == "DOUBLE"
    assert names["pills_detected"]["type"] == "INT"
    encoded = json.dumps(payload)
    assert "secret-token" not in encoded


def test_pending_statement_is_polled() -> None:
    client = _FakeClient(
        [
            {"statement_id": "s-2", "status": {"state": "PENDING"}},
            {"statement_id": "s-2", "status": {"state": "SUCCEEDED"}},
        ]
    )
    sink = DatabricksSink(_config(), client)
    assert sink.send(_event()) is True
    assert client.gets == ["s-2"]


def test_rejected_insert_returns_false() -> None:
    client = _FakeClient(
        [
            {
                "statement_id": "s-3",
                "status": {"state": "FAILED", "error": {"message": "TABLE_OR_VIEW_NOT_FOUND"}},
            }
        ]
    )
    sink = DatabricksSink(_config(), client)
    assert sink.send(_event()) is False


def test_transport_error_returns_false() -> None:
    class _Boom:
        def post_statement(self, payload: dict) -> dict:
            raise OSError("network down")

        def get_statement(self, statement_id: str) -> dict:
            raise AssertionError("should not poll")

    sink = DatabricksSink(_config(), _Boom())
    assert sink.send(_event()) is False


if __name__ == "__main__":
    test_missing_env_disables_the_sink()
    test_host_without_scheme_is_https()
    test_browser_path_is_stripped_from_the_host()
    test_dotenv_parser_skips_comments_and_quotes()
    test_table_name_cannot_carry_sql()
    test_unset_catalog_is_omitted_from_the_statement()
    test_insert_uses_parameters_and_not_the_token_in_the_body()
    test_pending_statement_is_polled()
    test_rejected_insert_returns_false()
    test_transport_error_returns_false()
    print("ok")
