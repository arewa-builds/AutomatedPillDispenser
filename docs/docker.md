# Docker Guide — Automated Pill Dispenser

Run the software-first stack (edge mock pipeline + local medallion) in a single container image. Firmware source is included in the image for reference; flashing the Nano 33 BLE still happens on the host via Arduino IDE / `arduino-cli`.

## Prerequisites

- Docker Engine 24+ and Docker Compose v2+
- Optional (camera profile): Linux host with `/dev/video0`
- Optional (serial profile): Arduino on `/dev/ttyACM0`

## Quick start

```bash
# Build the image
docker compose build

# Headless mock edge smoke (no camera / no Arduino)
docker compose run --rm app smoke

# Synthetic Bronze → Silver → Gold
docker compose run --rm medallion

# Help
docker compose run --rm app help
```

Artifacts land on the host via bind mounts:

| Host path | Container path |
| :--- | :--- |
| `edge/logs/` | `/app/edge/logs` |
| `databricks/sample_data/` | `/app/databricks/sample_data` |

## Services & profiles

| Service | Profile | Purpose |
| :--- | :--- | :--- |
| `app` | (default) | Edge mock headless smoke |
| `medallion` | (default) | Generate telemetry + local medallion |
| `shell` | `dev` | Interactive bash with repo mounted |
| `edge-camera` | `camera` | Mock edge with `/dev/video0` passthrough |
| `edge-serial` | `serial` | Real Arduino serial on `/dev/ttyACM0` |

```bash
docker compose run --rm medallion
docker compose --profile dev run --rm shell
docker compose --profile camera run --rm edge-camera
docker compose --profile serial run --rm edge-serial
```

## Entrypoint commands

The image entrypoint (`docker/entrypoint.sh`) accepts:

```text
smoke | edge | medallion | generate-telemetry | shell | python | help
```

Examples:

```bash
docker compose run --rm app edge --mode mock --headless --cycles 1
docker compose run --rm app python -c "import cv2, mediapipe; print(cv2.__version__)"
docker compose run --rm app shell
```

## Camera & GUI notes

- **Default container path is headless** (`opencv-python-headless`) — use `--headless` or the `smoke` command.
- For interactive `cv2.imshow` face/tray UI, run the host venv on your laptop (`edge/README.md`). X11-forwarding into Docker is possible but brittle across macOS/Windows.
- Linux camera passthrough:

```bash
docker compose --profile camera run --rm edge-camera
```

## Arduino serial (when hardware arrives)

```bash
# Confirm device on host first: ls /dev/ttyACM*
docker compose --profile serial run --rm edge-serial
```

If the device path differs, override:

```bash
docker compose run --rm --device=/dev/ttyUSB0:/dev/ttyACM0 app \
  edge --mode serial --port /dev/ttyACM0 --headless
```

## Image layout

```text
/app
  edge/           Python vision + telemetry
  databricks/     Local medallion scripts + sample_data
  firmware/       Arduino source (flash from host)
  docs/           Project docs
```

## Rebuild after code changes

```bash
docker compose build --no-cache
docker compose run --rm app smoke
```
