# CAD v2 — carousel-only rotation

The v1 build failed on the bench in three specific ways. v2 is the redesign that fixes them:

| v1 bench failure | v2 fix |
| :--- | :--- |
| Internal "cross hair" ribs stopped the MG90S seating | No ribs and no servo well in the bore. The servo sits **above** the drum on a removable bridge and drives the hub straight down. |
| The drop plate rotated instead of the carousel | The plate has **three keys** that drop into notches in the drum ledge. It is mechanically incapable of turning. |
| The chute exit was a slit no tablet could pass | The exit is a **40 mm wide open trough** through a 45.6 mm window, falling at 38 deg inside and 45 deg outside. |

Everything is parametric — edit `parameters_v2.scad` and re-run `render_all_v2.sh`.

## How a dose works

1. The carousel parks with a **solid floor band** over the plate opening. Nothing can fall.
2. To dispense, the servo turns the carousel **one 60 deg step**.
3. During that step the next compartment's drop hole sweeps across the plate opening. The hole's trailing edge drags the tablets over the window and they fall.
4. Pills land on the 38 deg hopper floor, exit the drum through the wall window, run down the 45 deg external trough and land in the catch tray, where the laptop camera counts them.

### The leak rule (do not break this)

```
floor band  =  360/car_n  -  car_hole_deg      must be  >  open_deg
              (60)          (30)                         (18)
```

30 deg of band over an 18 deg opening leaves **+/- 6 deg of parking error** before a
neighbouring compartment starts dribbling pills into the chute. If you widen the
plate opening or the drop holes, re-check this inequality first. It is the reason
the plate opening is a modest window rather than a full compartment-sized sector,
and the reason each compartment floor is **ramped** — a narrower hole would
otherwise leave tablets parked on a flat ledge and short the dose.

## Servo choice — read before buying

Direct drive means one carousel step is a real 60 deg of servo output.

- **MG90S 360 deg (continuous rotation)** — recommended. Six doses per revolution, always turning the same way. Steps are timed, so calibrate `MS_PER_60_DEG` once and re-zero at every refill.
- **Standard 180 deg MG90S** — works for **three doses per fill**: park at 0 / 60 / 120 / 180, then sweep back. The return sweep re-crosses compartments 1-3, which are already empty, so nothing is lost. Fill compartments in rotation order.

Either way the hub is driven through a round horn keyed into a pocket, so the
carousel still lifts straight out of the drum for refilling.

## Print bill of materials

| ID | File | Qty | Notes |
| :--- | :--- | ---: | :--- |
| **A2** | `part_a2_housing.scad` | 1 | 120 x 86 mm drum. Open-ended tube, **no supports** — the plate ledge and chute window are 45 deg self-supporting. |
| **B2** | `part_b2_fixed_plate.scad` | 1 | The one opening, three keys, centre pilot post. Flat. |
| **C2** | `part_c2_carousel.scad` | 1 | Hub, 6 fins, ramped floors, 6 drop holes. Floor down, no supports. |
| **D2** | `part_d2_drop_chute.scad` | 1 | Hopper + spout + 45 deg run. Light supports under the external run if it droops. |
| **E2** | `part_e2_servo_bridge.scad` | 1 | Four-arm spider, MG90S pocket. Flat. |
| **F2** | `part_f2_catch_tray.scad` | 1 | Free-standing tray / camera zone. Flat. |
| **G2** | `part_g2_base_cover.scad` | 1 | Electronics floor. Flat. |

Print settings: PLA, 0.4 mm nozzle, 0.2 mm layers, 3 perimeters, 20-25% infill.
Print the carousel and plate at 0.15 mm if your printer is well tuned — the
0.6 mm running gap between them is the tightest fit in the machine.

## Fasteners

| Qty | Size | Where |
| ---: | :--- | :--- |
| 4 | M3 x 10 self-tapping | servo bridge into the four external drum bosses |
| 3 | M3 x 10 self-tapping | base cover up into the three internal posts |
| 2 | M2 x 6 | MG90S flange to the bridge |
| 4 | M2 x 6 self-tapping | round horn down into the carousel hub |

## Key fits

| Interface | Value |
| :--- | :--- |
| Carousel OD to drum bore | 0.7 mm per side (pill-proof sweep gap) |
| Carousel floor to plate | 0.6 mm running gap |
| Pilot post to hub journal | 10.0 / 10.35 mm |
| Plate to drum bore | 0.3 mm per side, resting on a 3 mm ledge |
| Servo shaft tip to hub | ~3.7 mm of spline engagement inside the horn pocket |

## Assembly order

1. Screw **G2** base cover on; tape the Nano, TP4056 and LiPo to it through the bore.
2. Feed **D2** chute in through the wall window from the outside until its collar laps the drum.
3. Drop **B2** plate in, keys into the ledge notches; it should not rotate by hand.
4. Screw the round horn into the **C2** hub, then lower the carousel onto the pilot post.
5. Bolt the MG90S into **E2**, then bolt the bridge to the four drum bosses — the shaft plugs down into the horn.
6. Set **F2** tray under the chute lip; aim the laptop camera at it.

## Regenerate

```bash
./cad/v2/render_all_v2.sh     # 7 STLs into stl/, previews into previews/
```

Views: `previews/assembly_cutaway.png`, `assembly_closed.png`,
`assembly_section.png`, `assembly_exploded.png`.

## Still open

- Parking accuracy relies on servo repeatability. A printed detent finger on the plate engaging six notches in the carousel rim would make it deterministic; not modelled yet.
- The electronics bay is deliberately oversized (16 mm under the chute, full width behind it). Shorten `plate_z` if you want a squatter machine.
