"""Shared edge configuration for vision, serial, and telemetry."""

from __future__ import annotations

from pathlib import Path

# Camera
CAMERA_INDEX = 0
FRAME_WIDTH = 1280
FRAME_HEIGHT = 720

# Face gate (MediaPipe Face Detection)
FACE_MIN_CONFIDENCE = 0.65
FACE_STABLE_FRAMES = 8  # consecutive frames before allowing dispense

# Pill verification (OpenCV) — tune for your candy / lighting
PILL_HSV_LOWER = (0, 40, 40)
PILL_HSV_UPPER = (179, 255, 255)
PILL_MIN_AREA = 80
PILL_MAX_AREA = 8000
PILL_EXPECTED_COUNT = 1
PILL_VERIFY_TIMEOUT_S = 2.0

# Serial / mock hardware
SERIAL_BAUD = 115200
SERIAL_PORT = ""  # e.g. "/dev/ttyACM0" or "COM3"; empty = auto-skip to mock
MOCK_DISPENSE_LATENCY_MS = 350
DISPENSE_COMMAND = "DISPENSE\n"
ACK_TOKEN = "ACK_DISPENSE"
RETRY_LIMIT = 2

# Telemetry
PATIENT_ID = "patient_demo_001"
TELEMETRY_DIR = Path(__file__).resolve().parent / "logs" / "telemetry"
