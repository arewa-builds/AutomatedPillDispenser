"""
Local Bronze -> Silver transform (no Databricks cluster required).

Mirrors the Week 4 PySpark contract with explicit schema validation using
stdlib + json only, so you can develop offline before a workspace is ready.
"""

from __future__ import annotations

import argparse
import csv
import json
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


REQUIRED_FIELDS = {
    "timestamp": str,
    "patient_id": str,
    "face_match_confidence": (int, float),
    "pills_detected": int,
    "dispense_latency_ms": int,
    "event_status": str,
    "hardware_source": str,
}


@dataclass
class SilverRow:
    event_ts_utc: str
    patient_id: str
    face_match_confidence: float
    pills_detected: int
    dispense_latency_ms: int
    event_status: str
    hardware_source: str
    retry_count: int
    is_success: bool
    scheduled_window: str
    time_drift_minutes: float


def parse_ts(value: str) -> datetime:
    if value.endswith("Z"):
        value = value[:-1] + "+00:00"
    return datetime.fromisoformat(value).astimezone(timezone.utc)


def validate_bronze(row: dict[str, Any]) -> None:
    for key, expected in REQUIRED_FIELDS.items():
        if key not in row:
            raise ValueError(f"Missing required field: {key}")
        if not isinstance(row[key], expected):
            raise TypeError(f"Field {key} expected {expected}, got {type(row[key])}")
    if row["event_status"] not in {"success", "retry", "failure"}:
        raise ValueError(f"Invalid event_status: {row['event_status']}")


def scheduled_window(ts: datetime) -> str:
    hour = ts.hour
    if 5 <= hour < 11:
        return "morning"
    if 11 <= hour < 17:
        return "midday"
    if 17 <= hour < 23:
        return "evening"
    return "night"


def window_anchor(ts: datetime) -> datetime:
    """Anchor each event to nominal 08:00 / 20:00 local-UTC demo schedule."""
    window = scheduled_window(ts)
    hour = 8 if window in {"morning", "midday"} else 20
    return ts.replace(hour=hour, minute=0, second=0, microsecond=0)


def to_silver(row: dict[str, Any]) -> SilverRow:
    validate_bronze(row)
    ts = parse_ts(row["timestamp"])
    anchor = window_anchor(ts)
    drift = (ts - anchor).total_seconds() / 60.0
    retry_count = int(row.get("retry_count", 0))
    return SilverRow(
        event_ts_utc=ts.isoformat().replace("+00:00", "Z"),
        patient_id=str(row["patient_id"]),
        face_match_confidence=float(row["face_match_confidence"]),
        pills_detected=int(row["pills_detected"]),
        dispense_latency_ms=int(row["dispense_latency_ms"]),
        event_status=str(row["event_status"]),
        hardware_source=str(row["hardware_source"]),
        retry_count=retry_count,
        is_success=row["event_status"] in {"success", "retry"} and int(row["pills_detected"]) >= 1,
        scheduled_window=scheduled_window(ts),
        time_drift_minutes=round(drift, 2),
    )


def dedupe(rows: list[SilverRow]) -> list[SilverRow]:
    seen: set[tuple[str, str, int]] = set()
    out: list[SilverRow] = []
    for row in rows:
        key = (row.patient_id, row.event_ts_utc, row.pills_detected)
        if key in seen:
            continue
        seen.add(key)
        out.append(row)
    return out


def gold_adherence(rows: list[SilverRow]) -> list[dict[str, Any]]:
    by_patient: dict[str, list[SilverRow]] = {}
    for row in rows:
        by_patient.setdefault(row.patient_id, []).append(row)

    summary: list[dict[str, Any]] = []
    for patient_id, events in by_patient.items():
        total = len(events)
        success = sum(1 for e in events if e.is_success)
        avg_drift = sum(e.time_drift_minutes for e in events) / total if total else 0.0
        summary.append(
            {
                "patient_id": patient_id,
                "events": total,
                "success_events": success,
                "adherence_rate_7d": round(success / total, 4) if total else 0.0,
                "avg_time_drift_minutes": round(avg_drift, 2),
                "high_adherence_risk": avg_drift >= 15.0 or (success / total if total else 0.0) < 0.85,
            }
        )
    return summary


def main() -> int:
    parser = argparse.ArgumentParser(description="Local Bronze->Silver->Gold medallion")
    parser.add_argument(
        "--bronze",
        type=Path,
        default=Path(__file__).resolve().parent / "sample_data" / "bronze_dispense_events.jsonl",
    )
    parser.add_argument(
        "--silver-out",
        type=Path,
        default=Path(__file__).resolve().parent / "sample_data" / "silver_dispense_events.csv",
    )
    parser.add_argument(
        "--gold-out",
        type=Path,
        default=Path(__file__).resolve().parent / "sample_data" / "gold_adherence_7d.json",
    )
    args = parser.parse_args()

    if not args.bronze.exists():
        raise SystemExit(f"Bronze file missing: {args.bronze}. Run generate_synthetic_telemetry.py first.")

    bronze_rows: list[dict[str, Any]] = []
    with args.bronze.open("r", encoding="utf-8") as handle:
        for line_no, line in enumerate(handle, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                bronze_rows.append(json.loads(line))
            except json.JSONDecodeError as exc:
                raise SystemExit(f"Invalid JSON on line {line_no}: {exc}") from exc

    silver = dedupe([to_silver(row) for row in bronze_rows])
    args.silver_out.parent.mkdir(parents=True, exist_ok=True)
    with args.silver_out.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=list(SilverRow.__annotations__.keys()),
        )
        writer.writeheader()
        for row in silver:
            writer.writerow(row.__dict__)

    gold = gold_adherence(silver)
    with args.gold_out.open("w", encoding="utf-8") as handle:
        json.dump(gold, handle, indent=2)
        handle.write("\n")

    print(f"Bronze events: {len(bronze_rows)}")
    print(f"Silver events: {len(silver)} -> {args.silver_out}")
    print(f"Gold patients: {len(gold)} -> {args.gold_out}")
    for row in gold:
        print(
            f"  {row['patient_id']}: adherence={row['adherence_rate_7d']:.2%} "
            f"drift={row['avg_time_drift_minutes']}m risk={row['high_adherence_risk']}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
