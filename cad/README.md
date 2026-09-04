# CAD — Full Printable Prototype Set

Parametric **OpenSCAD** sources, **STL** meshes, and **PNG** previews for an adequate Automated Pill Dispenser mechanical prototype.

## Expert agent

`/cad-embedded-hardware` — refine fits, regenerate parts, adjust clearances.

## Explore the full assembly

1. Install [OpenSCAD](https://openscad.org/).
2. Open `assembly_preview.scad` → **F5**.
3. Toggle `EXPLODED = true/false`.

Or browse screenshots in `previews/`.

## Print bill of materials (3D parts)

| ID | File | Qty | Purpose |
| :--- | :--- | ---: | :--- |
| **A** | `part_a_base_enclosure.scad` | 1 | Main housing: Nano, LiPo/TP4056, carousel servo, chute |
| **B** | `part_b_base_plate.scad` | 1 | Drop floor with 20×15 mm hole + latch rails |
| **C** | `part_c_carousel.scad` | 1 | 8-pocket carousel + MG90S horn hub |
| **D** | `part_d_latch_gate.scad` | 1 gate + 1 arm | Sliding gate + servo horn arm (`BUILD`) |
| **E** | `part_e_carousel_lid.scad` | 1 | Lid / finger shield / anti-spill |
| **F** | `part_f_catch_tray.scad` | 1 | Vision landing tray (OpenCV ROI) |
| **G** | `part_g_chute_spout.scad` | 1 | Chute → tray guide |
| **H** | `part_h_latch_servo_bracket.scad` | 1 | Second MG90S mount for latch |
| **I** | `part_i_cable_clips.scad` | 4 (on plate) | USB / servo strain relief |
| **J** | `part_j_feet.scad` | 4 (on plate) | Anti-slip feet |
| **K** | `part_k_pill_insert.scad` | 0–8 | Optional pocket reducers for small tablets |

Shared dimensions: `parameters.scad`.

### Not printed (buy / reuse)

- Arduino Nano 33 BLE, 2× MG90S, LiPo 500 mAh, TP4056  
- M2/M2.5 screws, wire, **5V servo supply + common ground**  
- Laptop camera (index 0)  
- Homing sensor — **optional** for v1 (manual pocket #0 alignment)

## Regenerate STLs + PNGs

```bash
chmod +x cad/render_all.sh
./cad/render_all.sh
```

Manual: open a part → **F6** → **File → Export → STL** into `cad/stl/`.

## Suggested print settings

- PLA (or PETG for latch/gate), **0.4 mm** nozzle, **0.2 mm** layers  
- 3–4 perimeters, 20–30% infill (40% for carousel hub)  
- Supports: light under Part A chute underside and Part G channel if printed flat  

## Assembly order

1. J feet under A  
2. Carousel MG90S into A well; press C onto horn; seat B plate  
3. H bracket + latch MG90S; fit D gate into B rails; link D arm  
4. E lid on C  
5. G spout on A chute exit → F catch tray in front  
6. I clips on USB / servo leads  
7. K inserts only if tablets rattle in full-size pockets  

Firmware pins: carousel **D9**, latch **D10**.
