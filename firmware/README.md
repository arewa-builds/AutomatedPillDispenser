# Firmware — Arduino Nano 33 BLE

## Sketch

- `pill_dispenser/pill_dispenser.ino` — non-blocking carousel + latch servo state machine

## Check Arduino IDE / toolchain without a board

You do **not** need the Nano plugged in to confirm the IDE/toolchain works. Compile (Verify) only:

**Option A — Arduino IDE GUI**

1. Install board pack: *Tools → Board → Boards Manager → “Arduino Mbed OS Nano Boards”*
2. Install library: *Tools → Manage Libraries → Servo*
3. Open `pill_dispenser/pill_dispenser.ino`
4. Select board: **Arduino Nano 33 BLE**
5. Click **Verify** (✓) — not Upload

**Option B — script (`arduino-cli`)**

```bash
# Linux / macOS / WSL
chmod +x firmware/verify_arduino_toolchain.sh
./firmware/verify_arduino_toolchain.sh
```

```powershell
# Windows PowerShell
.\firmware\verify_arduino_toolchain.ps1
```

Success means `Servo.h` resolved and the sketch built for `arduino:mbed_nano:nano33ble`.

## Upload later (board connected)

```bash
arduino-cli board list
arduino-cli upload -p /dev/ttyACM0 --fqbn arduino:mbed_nano:nano33ble firmware/pill_dispenser
```

Windows: use `COM3` (or your port) instead of `/dev/ttyACM0`.
