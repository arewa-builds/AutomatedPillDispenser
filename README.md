# Automated Pill Dispensing & Visual Medication Compliance Monitor

Intelligent, low-cost MedTech station that physically dispenses medication, visually verifies patient presence and pill drop, and tracks adherence risk before missed doses become dangerous.

## Problem

Medication non-adherence costs the healthcare system billions and hits elderly and neurodivergent patients especially hard. This prototype combines a 3D-printed servo carousel, edge computer vision, and Databricks analytics to close that loop non-invasively.

## Architecture

| Layer | Stack | Responsibility |
| :--- | :--- | :--- |
| Embedded | Arduino Nano 33 BLE, 2× MG90S, LiPo + TP4056 | Carousel index + latch release |
| Edge CV | Python 3.10+, OpenCV, MediaPipe, PySerial | Face gate + pill contour/color/count |
| Data | Databricks Delta Lake (Bronze → Silver → Gold) | Telemetry ingest & compliance transforms |
| ML / BI | scikit-learn, MLflow, Power BI Desktop | Adherence risk forecast + clinical KPIs |

**Budget:** ~$73–$93 hardware (laptop camera preferred) · **$93–$108** all-in with cloud trial · Timeline **Aug 10 – Sep 20, 2026**.

## Repository

```
.cursor/agents/   Expert subagents (systems + CAD)
.cursor/rules/    Always-on project constraints
cad/              OpenSCAD / STL mechanical parts
firmware/         Arduino C++ (Week 1+)
edge/             Python vision + telemetry (Week 2–3)
databricks/       PySpark / Delta Lake (Week 4–5)
ml/               MLflow models (Week 5)
docs/             Schedule, BOM, architecture notes
```

## Cursor expert agents

| Invoke | Role |
| :--- | :--- |
| `/medtech-lead-architect` | Firmware, vision, Databricks, MLflow, Power BI |
| `/cad-embedded-hardware` | OpenSCAD/STL: carousel, latch, Nano/MG90S/LiPo housing |

See `AGENTS.md` and `cad/README.md`.

## Current status

**Software-first track active** — no Arduino required yet. You can develop vision, mock hardware, telemetry, and local medallion transforms on a laptop now. Firmware is compile-ready for when parts arrive.

## Run now (no hardware)

```bash
# Edge mock pipeline (laptop camera) or headless smoke
cd edge
python3 -m venv .venv; .\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python pipeline.py --mode mock --headless

# Synthetic Bronze -> Silver -> Gold (local)
cd ../databricks
python3 generate_synthetic_telemetry.py
python3 local_medallion.py
```

See [`docs/software-first-roadmap.md`](docs/software-first-roadmap.md).

## Quick links

- Product brief: [`project.md`](project.md)
- Full schedule & BOM: [`docs/project-context.md`](docs/project-context.md)
- Software-first plan: [`docs/software-first-roadmap.md`](docs/software-first-roadmap.md)
- Edge docs: [`edge/README.md`](edge/README.md)
- Agent guide: [`AGENTS.md`](AGENTS.md)
