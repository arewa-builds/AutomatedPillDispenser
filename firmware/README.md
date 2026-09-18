# Firmware — Arduino Nano 33 BLE

## Sketch

`pill_dispenser/pill_dispenser.ino` — non-blocking state machine for the v3
mechanism: **one** positional MG90S on D9, driving the carousel directly. There is
no latch servo; the v3 deck parks the just-emptied compartment over the discharge
opening, so nothing sits above it between doses and there is nothing to hold shut.
D10, the v1 latch channel, is free.

Geometry constants come from `cad/v3/parameters_v3.scad`. Two of them decide how
the sketch behaves:

| Constant | Value | Why |
| :--- | :--- | :--- |
| `STEP_DEG` | 45 | One of 8 compartments (`car_pitch`) |
| `DOSES_PER_FILL` | 4 | A 180 deg servo geared 1:1 reaches 5 stops, so 4 steps |

**Four doses per fill.** The servo drives the carousel 1:1, so its 180 deg span is
all the travel there is: stops at 0, 45, 90, 135, 180. After the fourth dose
`DISPENSE` returns `ERR_MAGAZINE_EMPTY` rather than pushing into the servo's end
stop and reporting a dose that never fell. `REZERO` then sweeps back to stop 0 —
safe only because the compartments it crosses are the four it just emptied. Refill
per `cad/v3/README.md` and the count starts again.

**Absolute angles, not timed steps.** Parking has only ±6.2 deg of margin before
the opening's edge slips past a divider and starts draining the next compartment,
which would be a silent double dose. A positional servo commanded to an absolute
angle parks to about 1 deg; a continuous-rotation servo stepped on timing drifts
past 6 deg within a few doses, so the sketch does not support one.

**Calibrate `PARK_TRIM_DEG` once.** The horn's spline is fine enough that stop 0
lands wherever the horn was pressed on. Trim all five stops together until the
emptied compartment is centred in the opening, by eye, on the first fill. The trim
also eats range at the far end, so a `static_assert` fails the build if it pushes
the last stop past 180.

## Serial protocol @ 115200

A superset of the v1 protocol, so hosts that only speak `DISPENSE` /
`ACK_DISPENSE` — including `edge/hardware_bridge.py` — need no changes.

| Host sends | Device replies | Notes |
| :--- | :--- | :--- |
| `DISPENSE` | `ACK_DISPENSE` | About 1 s: 400 ms step, 600 ms for the dose to reach the tray |
| | `ERR_BUSY` | Mid-cycle |
| | `ERR_MAGAZINE_EMPTY` | Stop 4 reached; refill and `REZERO` |
| `REZERO` | `ACK_REZERO` | Sweeps back to stop 0, up to 1.6 s |
| `SETSTOP n` | `ACK_SETSTOP` / `ERR_ARG` | Corrects the sketch's count **without moving** |
| `STATUS` | `STATE=n STOP=i/4 ANGLE=d` | |
| `PING` | `PONG` | |

The servo holds its angle mechanically when unpowered, so the carousel's position
survives a power cycle but the sketch's idea of it does not. On boot it assumes
stop 0 and deliberately commands no angle — writing one could sweep full
compartments across the opening and dump them. A host that logged the doses can
correct the count with `SETSTOP`.

## Check the behaviour without a board

```bash
./firmware/test/run.sh
```

Compiles the sketch on the host against small stubs — fake clock, fake serial,
recording servo — and drives it through four doses, the refusal after them, the
rezero sweep, and the argument handling. Needs only `g++`. See
`firmware/test/host_harness.cpp`.

This complements the toolchain check below rather than replacing it: one proves
the logic, the other proves it builds for the real target.

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
