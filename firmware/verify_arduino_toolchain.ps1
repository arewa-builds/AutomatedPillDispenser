# Verify Arduino toolchain can compile pill_dispenser.ino WITHOUT a board attached.
# Uses arduino-cli "compile" only (no upload).
#
# Usage (PowerShell, from repo root):
#   .\firmware\verify_arduino_toolchain.ps1

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
if (-not $Root) { $Root = (Resolve-Path "$PSScriptRoot\..").Path }
$Sketch = Join-Path $Root "firmware\pill_dispenser"
$Fqbn = "arduino:mbed_nano:nano33ble"

Write-Host "==> Automated Pill Dispenser — Arduino toolchain check (no board needed)"
Write-Host "    Sketch: $Sketch"
Write-Host "    Board:  $Fqbn"
Write-Host ""

$cli = Get-Command arduino-cli -ErrorAction SilentlyContinue
if (-not $cli) {
  Write-Host @"
ERROR: arduino-cli not found on PATH.

Install options:
  1) Standalone: https://arduino.github.io/arduino-cli/latest/installation/
  2) Arduino IDE 2.x: install IDE, then add its bundled arduino-cli to PATH
  3) Or in Arduino IDE GUI: open pill_dispenser.ino and click Verify (checkmark)
     — that also checks the toolchain without uploading.
"@
  exit 1
}

Write-Host "==> arduino-cli version"
arduino-cli version
Write-Host ""

Write-Host "==> Ensuring board core is installed (arduino:mbed_nano)..."
arduino-cli core update-index
arduino-cli core install arduino:mbed_nano

Write-Host ""
Write-Host "==> Ensuring Servo library is installed..."
$libList = arduino-cli lib list 2>$null | Out-String
if ($libList -notmatch '(?im)^Servo\s') {
  arduino-cli lib install Servo
}

Write-Host ""
Write-Host "==> Compiling sketch (verify only — no upload)..."
arduino-cli compile --fqbn $Fqbn $Sketch

Write-Host ""
Write-Host "SUCCESS: Toolchain is working. pill_dispenser.ino compiled for Nano 33 BLE."
Write-Host "When your board is plugged in, upload with:"
Write-Host "  arduino-cli upload -p COM3 --fqbn $Fqbn $Sketch"
Write-Host "  (Replace COM3 with your port from Device Manager)"
