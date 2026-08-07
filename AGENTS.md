# Automated Pill Dispenser — Agent Guide

This repository builds an **Automated Pill Dispensing & Visual Medication Compliance Monitor**: a low-cost MedTech prototype that dispenses medication, verifies patient presence and pill drop via computer vision, and tracks adherence risk in Databricks / MLflow / Power BI.

## Expert subagent

Use the project specialist for architecture, firmware, vision, cloud, and ML work:

| Invoke | File | Role |
| :--- | :--- | :--- |
| `/medtech-lead-architect` | `.cursor/agents/medtech-lead-architect.md` | Lead Technical Co-Developer & Systems Architect |

Delegate when working on Arduino Nano 33 BLE firmware, MG90S servos, MediaPipe/OpenCV, PySerial/BLE, Delta Lake medallion pipelines, MLflow adherence models, or Power BI clinical dashboards.

## Default engineering constraints

- Arduino: non-blocking `millis()` timing only — never `delay()`.
- Servos: detach/idle after motion to protect LiPo / avoid overheating.
- Python edge & PySpark: explicit `try/except` + structured logging on I/O paths.
- Databricks: explicit `StructType` schemas — no production schema inference.
- Camera default: laptop built-in index `0` (budget path).
- Budget target: hardware under ~$100 USD; total ~$93–$108 with cloud trial.

## 6-week roadmap (Aug 10 – Sep 20, 2026)

1. **Week 1** — Firmware & physical dispense  
2. **Week 2** — Edge CV (face + pill verify)  
3. **Week 3** — Serial/BLE integration + JSON telemetry  
4. **Week 4** — Databricks Bronze & Silver  
5. **Week 5** — Gold + MLflow adherence risk  
6. **Week 6** — Power BI, E2E test, docs  

Canonical schedule and BOM: `docs/project-context.md`. Product brief: `project.md`.

## Repo layout

```
firmware/     Arduino C++ (Nano 33 BLE)
edge/         Python vision + telemetry
databricks/   PySpark / Delta Lake notebooks
ml/           MLflow adherence models
docs/         Architecture, schedule, BOM
docker/       Container entrypoint
Dockerfile / docker-compose.yml
```

## Docker

Prefer the containerized software-first path when changing edge or medallion code:

```bash
docker compose build
docker compose run --rm app smoke
docker compose run --rm medallion
```

See `docs/docker.md`.
