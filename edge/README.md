# Edge Computer Vision & Telemetry

Python edge stack for face gating, mock/serial dispense, pill verification, and Bronze-ready JSONL logs.

## Setup (laptop)

```bash
cd edge
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Run without Arduino (recommended now)

```bash
python pipeline.py --mode mock
```

Flow: stable face (MediaPipe) → mock `DISPENSE` → OpenCV tray pill count → `logs/telemetry/*.jsonl`.

Place candy in the lower-central tray ROI (drawn on screen). Press `q` to quit.

### Headless smoke (CI / no camera UI)

```bash
python pipeline.py --mode mock --headless
```

## Run with Arduino later

```bash
python pipeline.py --mode serial --port /dev/ttyACM0   # Linux
python pipeline.py --mode serial --port COM3           # Windows
```

## Modules

| File | Role |
| :--- | :--- |
| `face_gate.py` | MediaPipe face presence + stability streak |
| `pill_verify.py` | HSV/contour pill count in tray ROI |
| `hardware_bridge.py` | PySerial bridge with mock fallback |
| `mock_arduino.py` | In-process Nano serial emulator |
| `telemetry.py` | JSONL event writer |
| `pipeline.py` | Orchestration |

Tune HSV / area thresholds in `config.py` for your candy and lighting.
