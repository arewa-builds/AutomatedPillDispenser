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
.cursor/agents/   Expert MedTech architect subagent
.cursor/rules/    Always-on project constraints
firmware/         Arduino C++ (Week 1+)
edge/             Python vision + telemetry (Week 2–3)
databricks/       PySpark / Delta Lake (Week 4–5)
ml/               MLflow models (Week 5)
docs/             Schedule, BOM, architecture notes
```

## Cursor expert agent

This repo includes a specialist subagent:

- **Name:** `medtech-lead-architect`
- **Invoke:** `/medtech-lead-architect` in Agent chat
- **Definition:** `.cursor/agents/medtech-lead-architect.md`

It encodes the Lead Technical Co-Developer persona (firmware, vision, Databricks, MLflow, Power BI) plus the 6-week plan and safety constraints. See `AGENTS.md` for usage.

## Current status

**Ready for Week 1** — Arduino C++ firmware & hardware testing (non-blocking servo control, pinout, Serial dispense commands).

## Quick links

- Product brief: [`project.md`](project.md)
- Full schedule & BOM: [`docs/project-context.md`](docs/project-context.md)
- Agent guide: [`AGENTS.md`](AGENTS.md)
