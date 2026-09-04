# Automated Pill Dispenser — Agent Guide

This repository builds an **Automated Pill Dispensing & Visual Medication Compliance Monitor**: a low-cost MedTech prototype that dispenses medication, verifies patient presence and pill drop via computer vision, and tracks adherence risk in Databricks / MLflow / Power BI.

## Expert subagents

| Invoke | File | Role |
| :--- | :--- | :--- |
| `/medtech-lead-architect` | `.cursor/agents/medtech-lead-architect.md` | Systems architect — firmware, vision, Databricks, MLflow, Power BI |
| `/cad-embedded-hardware` | `.cursor/agents/cad-embedded-hardware.md` | CAD / STL — OpenSCAD enclosures, carousel, latch, Nano/MG90S/LiPo housing |

- Use **`/cad-embedded-hardware`** for all 3D-print, OpenSCAD, STL, fit/tolerance, and mechanical assembly work.
- Use **`/medtech-lead-architect`** for electronics firmware, edge Python, cloud, and ML.

## Default engineering constraints

- Arduino: non-blocking `millis()` timing only — never `delay()`.
- Servos: detach/idle after motion to protect LiPo / avoid overheating.
- Python edge & PySpark: explicit `try/except` + structured logging on I/O paths.
- Databricks: explicit `StructType` schemas — no production schema inference.
- Camera default: laptop built-in index `0` (budget path).
- CAD: parametric OpenSCAD, FDM-friendly (≤45° overhangs), exact Nano / MG90S / LiPo pockets.
- Budget target: hardware under ~$100 USD; total ~$93–$108 with cloud trial.

## 6-week roadmap (Aug 10 – Sep 20, 2026)

1. **Week 1** — Firmware & physical dispense (+ CAD enclosure / carousel STLs)  
2. **Week 2** — Edge CV (face + pill verify)  
3. **Week 3** — Serial/BLE integration + JSON telemetry  
4. **Week 4** — Databricks Bronze & Silver  
5. **Week 5** — Gold + MLflow adherence risk  
6. **Week 6** — Power BI, E2E test, docs  

Canonical schedule and BOM: `docs/project-context.md`. Product brief: `project.md`. CAD guide: `cad/README.md`.

## Repo layout

```
cad/          OpenSCAD sources + stl/ exports
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
