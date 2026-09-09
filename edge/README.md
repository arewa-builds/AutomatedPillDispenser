# Edge Computer Vision & Telemetry

Python edge stack for face gating, mock/serial dispense, pill verification, and Bronze-ready JSONL logs.

## Docker (project-wide)

From the repo root:

```bash
docker compose build
docker compose run --rm app smoke
docker compose run --rm app edge --mode mock --headless
```

See [`docs/docker.md`](../docs/docker.md). Container installs use `requirements-docker.txt` (`opencv-python-headless`).

## Setup (laptop host venv)

```bash
cd edge
python3 -m venv .venv
# Windows Git Bash: source .venv/Scripts/activate
# Linux/macOS:      source .venv/bin/activate
source .venv/Scripts/activate

# If you previously installed OpenCV 5, remove it first:
pip uninstall -y opencv-python opencv-python-headless opencv-contrib-python

pip install -r requirements.txt
```

Requirements pin **OpenCV 4.x** (`<5`) and **MediaPipe ≥0.10.14**. Face detection uses the **MediaPipe Tasks** BlazeFace model in `models/blaze_face_short_range.tflite` (vendored; auto-downloaded if missing). Avoid OpenCV 5 — it lacks Haar face data and can leave face detection disabled.

## Run without Arduino (recommended now)

```bash
python pipeline.py --mode mock
```

Flow: stable face (MediaPipe Tasks) → mock `DISPENSE` → OpenCV tray pill count → `logs/telemetry/*.jsonl`.

Place candy in the lower-central tray ROI (drawn on screen). Press `q` to quit.

If the log shows `FaceGate backend: MediaPipe Tasks`, camera face detection is enabled.

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
