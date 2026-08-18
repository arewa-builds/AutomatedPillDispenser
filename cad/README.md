# CAD — 3D-Printed Dispenser Assembly

Parametric **OpenSCAD** sources and exported **STL** meshes for the Automated Pill Dispenser mechanical build (carousel, latch, Nano / MG90S / LiPo housing).

## Expert subagent

| Invoke | Role |
| :--- | :--- |
| `/cad-embedded-hardware` | Lead CAD & Embedded Hardware Engineer |

Use this agent for all STL/OpenSCAD work. It designs to exact Nano 33 BLE, MG90S, and LiPo/TP4056 tolerances and keeps prints FDM-friendly.

## Parts

| Part | File (planned) | Purpose |
| :--- | :--- | :--- |
| A | `part_a_base_enclosure.scad` | Main chassis: Nano, LiPo/TP4056, carousel servo, 45° chute |
| B | `part_b_base_plate.scad` | 100 mm drop floor with 20×15 mm hole |
| C | `part_c_carousel.scad` | 98 mm / 8-pocket carousel + servo-horn hub |
| D | `part_d_latch_gate.scad` | Second MG90S side gate over drop hole |
| — | `parameters.scad` | Shared dimensions & clearances |
| — | `stl/` | Exported meshes for your slicer |

## Tooling

1. Install [OpenSCAD](https://openscad.org/) (or use an online OpenSCAD editor).
2. Open a `part_*.scad` file.
3. **F5** preview → **F6** render → **File → Export → Export as STL**.
4. Slice in Cura / PrusaSlicer / Bambu Studio (PLA, 0.4 mm nozzle, 0.2 mm layers recommended).

## Hardware the models must fit

- Arduino Nano 33 BLE — 45 × 18 × 7 mm + USB cutout  
- MG90S ×2 — 22.8 × 12.2 × 28.5 mm  
- LiPo 500 mAh pocket — 30 × 20 × 6 mm + TP4056 USB-C access  

Firmware servo pins (for assembly orientation): carousel **D9**, latch **D10**.

## Status

OpenSCAD part files are generated on demand by `/cad-embedded-hardware`. Start with Part A or Part C when you invoke the agent.
