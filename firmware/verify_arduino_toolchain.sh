#!/usr/bin/env bash
# Verify Arduino toolchain can compile pill_dispenser.ino WITHOUT a board attached.
# Uses arduino-cli "compile" only (no upload).
#
# Usage (from repo root or this folder):
#   ./firmware/verify_arduino_toolchain.sh
#
# Prerequisites:
#   - arduino-cli on PATH  (https://arduino.github.io/arduino-cli/)
#     OR Arduino IDE 2.x with arduino-cli available in PATH
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKETCH="${ROOT}/firmware/pill_dispenser"
FQBN="arduino:mbed_nano:nano33ble"

echo "==> Automated Pill Dispenser — Arduino toolchain check (no board needed)"
echo "    Sketch: ${SKETCH}"
echo "    Board:  ${FQBN}"
echo

if ! command -v arduino-cli >/dev/null 2>&1; then
  cat <<'EOF'
ERROR: arduino-cli not found on PATH.

Install options:
  1) Standalone: https://arduino.github.io/arduino-cli/latest/installation/
  2) Arduino IDE 2.x: install IDE, then add its bundled arduino-cli to PATH
  3) Or in Arduino IDE GUI: open pill_dispenser.ino and click Verify (✓)
     — that also checks the toolchain without uploading.

EOF
  exit 1
fi

echo "==> arduino-cli version"
arduino-cli version
echo

echo "==> Ensuring board core is installed (arduino:mbed_nano)..."
arduino-cli core update-index
arduino-cli core install arduino:mbed_nano

echo
echo "==> Ensuring Servo library is installed..."
# Official Servo lib; ignore "already installed" style failures by checking list first
if ! arduino-cli lib list | grep -qi '^Servo '; then
  arduino-cli lib install Servo || true
fi

echo
echo "==> Compiling sketch (verify only — no upload)..."
arduino-cli compile --fqbn "${FQBN}" "${SKETCH}"

echo
echo "SUCCESS: Toolchain is working. pill_dispenser.ino compiled for Nano 33 BLE."
echo "When your board is plugged in, upload with:"
echo "  arduino-cli upload -p <PORT> --fqbn ${FQBN} ${SKETCH}"
echo "  Example port: /dev/ttyACM0 (Linux) or COM3 (Windows)"
