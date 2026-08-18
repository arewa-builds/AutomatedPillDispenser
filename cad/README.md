# CAD — Explore Housing, Carousel & Latch

Parametric OpenSCAD examples for the Automated Pill Dispenser. Use `/cad-embedded-hardware` to iterate; open these files in [OpenSCAD](https://openscad.org/) to explore.

## Quick start — explore the assembly

1. Install OpenSCAD.
2. Open `assembly_preview.scad`.
3. Press **F5** (preview).
4. Toggle at the top of the file:
   - `EXPLODED = true;` — parts separated (easiest to study)
   - `EXPLODED = false;` — seated stack

| Color | Part | What you’re looking at |
| :--- | :--- | :--- |
| Blue | **A** Housing | Nano, LiPo/TP4056, carousel servo well, 45° chute, camera lip |
| Orange | **B** Plate | 100 mm drop floor, center shaft hole, 20×15 mm drop slot |
| Green | **C** Carousel | 98 mm drum, 8 pockets, servo-horn press-fit hub |
| Red | **D** Latch | Sliding gate over drop hole + side MG90S hint |

## Printable part files

| File | Export STL to | Print notes |
| :--- | :--- | :--- |
| `part_a_base_enclosure.scad` | `stl/part_a_base_enclosure.stl` | Flat on bottom; light supports under chute if needed |
| `part_b_base_plate.scad` | `stl/part_b_base_plate.stl` | Flat; no supports |
| `part_c_carousel.scad` | `stl/part_c_carousel.stl` | Flat on open bottom; no supports; press onto MG90S horn |
| `part_d_latch_gate.scad` | `stl/part_d_latch_gate.stl` | Set `BUILD="gate"` / `"arm"` / `"both"`; print flat |

**Export:** Open part → **F6** (render) → **File → Export → Export as STL…**

Shared dimensions live in `parameters.scad` (edit once, all parts update after reload).

## Hardware these models fit

- Arduino Nano 33 BLE — 45×18×7 mm + USB cutout (−Y wall on Part A)
- MG90S ×2 — 22.8×12.2×28.5 mm (center carousel + side latch)
- LiPo 500 mAh — 30×20×6 mm pocket; TP4056 USB-C on +X wall

Firmware pins when assembling: carousel **D9**, latch **D10**.

## Preview images

Ready-made screenshots (also under `previews/`):

- `previews/assembly_preview.png` — exploded stack  
- `previews/part_a_base_enclosure.png` — housing  
- `previews/part_b_base_plate.png` — drop plate  
- `previews/part_c_carousel.png` — carousel  
- `previews/part_d_latch_gate.png` — gate + servo arm + bracket  

Exported example meshes are in `stl/` (regenerate anytime with OpenSCAD `-o`).

## Expert agent

`/cad-embedded-hardware` — refine tolerances, add screw bosses, change pocket count, or regenerate STLs after you dry-fit real parts.
