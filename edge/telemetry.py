"""Structured dispense-cycle telemetry writer (Bronze-ready JSON lines)."""

from __future__ import annotations

import json
import logging
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Literal

from config import PATIENT_ID, TELEMETRY_DIR

logger = logging.getLogger(__name__)

EventStatus = Literal["success", "retry", "failure"]
HardwareSource = Literal["serial", "ble", "mock"]


@dataclass
class DispenseTelemetry:
    timestamp: str
    patient_id: str
    face_match_confidence: float
    pills_detected: int
    dispense_latency_ms: int
    event_status: EventStatus
    hardware_source: HardwareSource
    retry_count: int = 0

    def to_dict(self) -> dict:
        return asdict(self)


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def build_event(
    *,
    face_match_confidence: float,
    pills_detected: int,
    dispense_latency_ms: int,
    event_status: EventStatus,
    hardware_source: HardwareSource,
    patient_id: str = PATIENT_ID,
    retry_count: int = 0,
) -> DispenseTelemetry:
    return DispenseTelemetry(
        timestamp=utc_now_iso(),
        patient_id=patient_id,
        face_match_confidence=round(float(face_match_confidence), 4),
        pills_detected=int(pills_detected),
        dispense_latency_ms=int(dispense_latency_ms),
        event_status=event_status,
        hardware_source=hardware_source,
        retry_count=int(retry_count),
    )


class TelemetryWriter:
    """Appends one JSON object per line for later Bronze ingestion."""

    def __init__(self, directory: Path = TELEMETRY_DIR) -> None:
        self.directory = directory
        self.directory.mkdir(parents=True, exist_ok=True)
        day = datetime.now(timezone.utc).strftime("%Y%m%d")
        self.path = self.directory / f"dispense_events_{day}.jsonl"

    def write(self, event: DispenseTelemetry) -> Path:
        try:
            with self.path.open("a", encoding="utf-8") as handle:
                handle.write(json.dumps(event.to_dict(), separators=(",", ":")) + "\n")
            logger.info("Telemetry written: %s", event.to_dict())
        except Exception:
            logger.exception("Failed to write telemetry to %s", self.path)
            raise
        return self.path
