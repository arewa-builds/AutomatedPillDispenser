"""Generate a week of synthetic dispense telemetry JSONL for Bronze/Silver local testing."""

from __future__ import annotations

import argparse
import json
import random
from datetime import datetime, timedelta, timezone
from pathlib import Path


def build_rows(days: int, seed: int) -> list[dict]:
    rng = random.Random(seed)
    start = datetime(2026, 8, 24, 8, 0, 0, tzinfo=timezone.utc)
    rows: list[dict] = []

    for day in range(days):
        # Progressive time drift: +3 minutes/day (adherence risk signal)
        drift_minutes = day * 3
        base = start + timedelta(days=day, minutes=drift_minutes)
        # Morning + evening dose windows
        for dose_offset_h, patient in ((0, "patient_demo_001"), (12, "patient_demo_001")):
            ts = base + timedelta(hours=dose_offset_h, seconds=rng.randint(0, 90))
            miss = rng.random() < (0.05 + day * 0.01)
            pills = 0 if miss else 1
            status = "failure" if miss else ("retry" if rng.random() < 0.08 else "success")
            rows.append(
                {
                    "timestamp": ts.isoformat(timespec="milliseconds").replace("+00:00", "Z"),
                    "patient_id": patient,
                    "face_match_confidence": round(0.0 if miss and rng.random() < 0.4 else rng.uniform(0.72, 0.99), 4),
                    "pills_detected": pills,
                    "dispense_latency_ms": rng.randint(280, 1600),
                    "event_status": status,
                    "hardware_source": rng.choice(["mock", "serial"]),
                    "retry_count": 0 if status == "success" else rng.randint(1, 2),
                }
            )
    return rows


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--days", type=int, default=7)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument(
        "--out",
        type=Path,
        default=Path(__file__).resolve().parent / "sample_data" / "bronze_dispense_events.jsonl",
    )
    args = parser.parse_args()

    args.out.parent.mkdir(parents=True, exist_ok=True)
    rows = build_rows(args.days, args.seed)
    with args.out.open("w", encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(row, separators=(",", ":")) + "\n")
    print(f"Wrote {len(rows)} events -> {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
