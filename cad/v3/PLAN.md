# v3 STL plan — "integral deck + open carousel"

Plan of record for the v3 reference design. The OpenSCAD sources in this folder
implement it and render clean; **STL export is deliberately not run yet** — see
section 9 for the remaining gates.

![v3 reference design](reference_design.png)

---

## 1. Design intent read from the reference

| Feature in the drawing | How it is built |
| :--- | :--- |
| Grey cylindrical container housing | 120 mm OD drum, 3 mm wall, 94 mm tall |
| Open carousel, **no outer wall** | Compartments are closed on the outside by the drum bore; the carousel is a hub + 8 radial dividers, nothing else |
| Dividers flush with the housing | 0.35 mm running gap to the deck below, 0.7 mm sweep gap to the bore |
| 8 compartments | 45 deg pitch, ~4.6 cm3 each |
| Direct servo drive shaft, no gears | MG90S above the carousel, printed shaft extension down to the hub |
| Servo support bracket | L bracket cantilevered from the inner wall to the axis, gusseted and ribbed |
| Discharge opening | One 24 deg wedge through the deck, feeding straight into the chute |
| 45 deg chute walls | Chute is integral to the housing: the channel ramps down and out through the wall |
| Pill catcher tray, opening flush with the chute walls | Mouth wall cut down; the chute lip overhangs into the well |

Load-bearing consequence of "no outer wall": the drum bore is a sealing surface,
so it must stay round and the carousel must never be forced against it. Every
clearance in section 5 follows from that.

---

## 2. Why the mechanism works, and the one number that makes it work

The deck holds the pills in. It has one wedge opening. The unit rests with the
**just-emptied compartment centred on that opening**, so there is nothing above
the opening to fall through. A 45 deg step sweeps the next compartment across the
opening and gravity empties it into the chute. One servo, no gate, no carousel
floor — the compartments are open bins exactly as drawn.

That only holds if the opening fits inside one compartment's interior with room
to spare, measured at the opening's inner radius, where a divider subtends the
most angle:

```
open_deg  <=  360/car_n - 2*asin(div_t / (2*open_r_in)) - 2*park_margin
24        <=  45        - 8.6                          - 12.4
```

So the design runs a **+/- 6.2 deg parking margin**: park more than that off
centre and the opening's edge slips past the divider and starts draining the next
compartment. `parameters_v3.scad` derives `park_margin` and every part echoes it,
so widening the opening or moving it inward fails loudly rather than silently.

Consequences worth knowing before you print:

- A **positional** servo is required. A continuous-rotation servo stepped on
  timing alone will drift past 6 deg within a few doses. A standard 180 deg MG90S
  parks to about 1 deg, well inside budget, and gives 45 deg steps across four
  stops per sweep.
- If you later want all 8 bins per fill from a continuous-rotation servo, the
  cheapest fix is one lever microswitch tripped once per revolution to re-zero,
  not a wider opening.

---

## 3. Why the housing is two prints

The deck — the surface the pills sit on and the dividers sweep — is a 114 mm disc
52 mm up inside a drum. As one piece that is either an unprintable bridge or a
support forest against the one surface that has to stay flat.

Split at the deck plane, both halves are trivial:

- **Deck body (A3)** prints as modelled: the deck's flat underside is the first
  layer, the wall rises from it, the wedge is just a hole, the pilot post grows
  upward. No supports.
- **Base body (B3)** prints open-end-down: the chute floor and the external run
  are 40-42 deg overhangs, self-supporting. No supports.

Three screwed ears outside the drum join them. Concentricity between the bodies
is deliberately not critical: the running surface *and* the bore are both on the
deck body, so only the chute has to line up, and +/- 1 mm there is harmless.

With the deck integral to the drum, the v1 failure where the drop plate rotated
instead of the carousel is designed out rather than fastened out.

---

## 4. STL manifest

Seven functional parts, three test coupons.

| # | Source file | STL | Qty | Function | Print orientation | Supports |
| ---: | :--- | :--- | ---: | :--- | :--- | :--- |
| 1 | `part_a3_deck_body.scad` | `part_a3_deck_body.stl` | 1 | Drum wall + integral deck + 24 deg wedge + pilot post + bracket screw seats + joint ears | Deck underside down | none |
| 2 | `part_b3_base_body.scad` | `part_b3_base_body.stl` | 1 | Bay + 45 deg chute + wall notch + shoulder fins + cover posts + cable port | Open end down, as modelled | none |
| 3 | `part_c3_carousel.scad` | `part_c3_carousel.stl` | 1 | Hub + 8 dividers, no floor, hex socket + pilot journal | Divider ends and hub flat on the bed | none |
| 4 | `part_d3_drive_shaft.scad` | `part_d3_drive_shaft.stl` | 1 | Horn pocket, column, hex foot | Head down | brim |
| 5 | `part_e3_servo_bracket.scad` | `part_e3_servo_bracket.stl` | 1 | Wall pad + gusset + ribbed arm + MG90S plate | Flipped, flange plane down: the pad's, arm's and servo plate's top faces are coplanar, so they form one flat footprint | none |
| 6 | `part_f3_catch_tray.scad` | `part_f3_catch_tray.stl` | 1 | Tray, mouth wall cut down to the chute lip | Flat | none |
| 7 | `part_g3_base_cover.scad` | `part_g3_base_cover.stl` | 1 | Electronics floor, foot pads | Flat | none |
| C1 | `coupon_1_sector.scad` | `coupon_1_sector.stl` | 1 | 74 deg deck sector with the wedge and pilot post + 104 deg carousel sector with the whole hub: proves the running and sweep gaps | laid out, both flat | none |
| C2 | `coupon_2_drive_train.scad` | `coupon_2_drive_train.stl` | 1 | Bracket's servo plate + the real D3 shaft + the hub's socket end: proves the three drive-train fits | laid out, shaft head down | brim under the shaft |
| C3 | `coupon_3_chute_dock.scad` | `coupon_3_chute_dock.stl` | 1 | Chute exit with the lip + the tray's mouth wall: proves the dock and the ramp in plastic | laid out, both as modelled | none |

Every part module works in assembly coordinates so the preview can use it as-is;
each file's top-level call applies that part's print orientation, which is what
`--stl` exports. So the STLs load onto the bed ready to slice — do not re-orient
them — while the preview still shows the parts where they actually sit.

Shared: `parameters_v3.scad`, `lib_v3.scad`, `assembly_preview_v3.scad`,
`check_drop_path.scad` (section 11), `render_all_v3.sh` (previews by default,
`--stl` to export).

---

## 5. Locked parameters

Drum and deck:

| Parameter | Value | Why |
| :--- | :--- | :--- |
| Drum OD / wall / bore | 120 / 3.0 / 114 mm | fits any 180 mm bed; 3 mm is 7 perimeters at 0.4 mm |
| Rim height | 94 mm | 10.6 mm of wall above the filled carousel |
| Deck thickness | 5 mm | it is structural now, not a drop-in plate |
| Deck top | z = 57 mm | leaves a 52 mm bay for the chute and electronics |
| Wall/deck fillet | 1.2 mm | dividers are chamfered 1.6 mm to clear it |
| Pilot post | 10.0 mm dia, 3.1 mm tall | the carousel's only bearing |
| Joint | 3 ears at 30/150/270 deg, 3x M3 | outside the drum, nothing in the pill path |

Carousel:

| Parameter | Value |
| :--- | :--- |
| Compartments | 8 at 45 deg pitch |
| Carousel OD | 112.6 mm, i.e. 0.7 mm sweep gap per side |
| Divider thickness / height | 2.4 / 26 mm |
| Running gap to deck | 0.35 mm |
| Hub | 28 mm OD, 7 mm A/F hex socket +0.4 mm slip |
| Capacity | ~4.6 cm3 per bin, roughly 10-14 standard tablets |

Discharge and chute:

| Parameter | Value |
| :--- | :--- |
| Deck opening | 24 deg sector, r 16 to 57 (breaches the bore) |
| Park margin | +/- 6.2 deg, derived not asserted |
| Lead-in relief | 1.2 mm on the opening's top face |
| Chute inside width | 14 mm at the deck, 32 mm from mid-ramp out |
| Ramp | One continuous surface, y = 14 to 70. Starts *inside* the opening's 16 mm inner radius, so every tablet lands on ramp, never on its leading edge |
| Ramp slope | 38-42 deg on top; floor thickens 2.4 to 6.5 mm so the *underside* stays 40-42 deg |
| Wall notch | 32.8 mm wide, z 4 to 52. Cut as a box **minus the chute solid**, so the ramp and the chute's walls cannot be breached; only housing wall is removed |
| Notch hoop strip | Wall kept below z = 4 — closes the first layers into a full ring and stiffens the two wall ends |
| Chute lip | z = 8 mm at y = 70, overhanging the tray by 2 mm; tray mouth wall 3 mm, so 1.5 mm of clearance under the lip |

Drive train:

| Parameter | Value |
| :--- | :--- |
| Bracket reach | 57 mm; arm 22 x 8 mm plus 12 mm ribs; 26 mm gusset web |
| Wall screws | 2x M3 driven from outside into the bracket pad |
| Servo plate | 4.5 mm thick — thinner than the servo's 6 mm nose, or the shaft head fouls it |
| Flange plane | z = 112 mm |
| Shaft | 30.15 mm overall: 26 mm head, 10 mm column, 7 mm hex foot |
| Step per dose | 45 deg |

---

## 6. Print plan

| Part | Est. filament | Est. time |
| :--- | ---: | ---: |
| C1-C3 coupons | ~30 g | ~1.5 h |
| A3 deck body | ~88 g | ~7 h |
| B3 base body | ~85 g | ~7 h |
| C3 carousel | ~35 g | ~3 h |
| F3 tray | ~25 g | ~2.5 h |
| G3 base cover | ~25 g | ~1.5 h |
| E3 bracket + D3 shaft | ~23 g | ~2 h |
| **Total** | **~310 g** | **~24.5 h** |

PLA, 0.4 mm nozzle, 0.2 mm layers, 3 perimeters, 20-25 % infill, no supports on
any part. Iron the deck body's top face if your slicer can — that is the running
surface. The chute's underside is a 40-42 deg overhang: it prints unsupported but
will look slightly rough, and it is a cosmetic surface.

---

## 7. Bought parts

| Qty | Item | Note |
| ---: | :--- | :--- |
| 1 | MG90S, **positional** (not continuous rotation) | see section 2 |
| 1 | Round servo horn, 4-hole | 20.4 mm disc |
| 2 | M3 x 10 self-tapping | bracket, from outside the wall |
| 3 | M3 x 10 self-tapping | body joint ears |
| 3 | M3 x 10 self-tapping | base cover into the posts |
| 2 | M2 x 6 | servo flange |
| 4 | M2 x 6 self-tapping | horn into the shaft head |

No bearings, no rods, no gears, no second servo.

---

## 8. Print the coupons first

About 90 minutes of printing that de-risks 23 hours. Each coupon is cut from the
real parts, so it carries the real dimensions rather than a copy of them, and each
one isolates the fits that a render cannot prove. Full instructions are in the
header of each file.

1. **C1 sector** (`coupon_1_sector.scad`) — drop the carousel sector onto the deck
   sector and spin it. Looking for no rub on the deck, no rub on the bore, no
   rocking, and a tablet that sweeps rather than slipping under a divider. If it
   rubs on the deck, `car_gap` changes; if it rubs on the bore, the 1.4 mm in
   `car_od` changes. Nothing else does.
2. **C2 drive train** (`coupon_2_drive_train.scad`) — the MG90S must drop into the
   bracket pocket without forcing, the horn must seat flush in the shaft head, and
   the hex must engage the hub with a little slop but no wobble. Stacking all
   three also measures the shaft head's 1.5 mm clearance under the servo plate,
   which is the one clearance a render can flatter.
3. **C3 chute dock** (`coupon_3_chute_dock.scad`) — the lip must overhang into the
   tray with clearance over the mouth wall, and a tablet rolled down the ramp must
   land on the tray floor without stopping on the lip or catching on the wall.
   Sight along the ramp against the light: this is where you confirm in plastic
   what section 11 proves in CAD.

Only then print A3 and B3.

---

## 9. Where this stands

| Gate | Step | State |
| :--- | :--- | :--- |
| G1 | `parameters_v3.scad`, `lib_v3.scad` | done — echoes the derived park margin |
| G2 | A3 deck body, B3 base body | done — render clean, chute fused into the wall |
| G3 | C3 carousel, D3 shaft, E3 bracket | done — shaft clears the servo plate by 1.5 mm |
| G4 | F3 tray, G3 base cover | done |
| G5 | Previews: 7 parts + 2 details + 5 assembly views + annotated hero | done, in `previews/` |
| G6 | Ramp continuity | done — `check_drop_path.scad`, see section 11 |
| G7 | `render_all_v3.sh --stl` | done — 7 STLs in `stl/`, each watertight, each in its print orientation |
| G8 | Coupons C1-C3 | done — cut from the real parts, exported to `stl/` |
| G9 | Firmware constants | **to do** — see section 10 |

---

## 10. Firmware touch points

`firmware/pill_dispenser/pill_dispenser.ino` already advances a carousel on a
non-blocking `millis()` state machine and detaches the servo between doses, so v3
needs constants rather than new logic:

- 45 deg per dose, absolute positions rather than timed steps
- park position = the opening's centre, so the emptied bin covers the wedge
- settle dwell after each step before the vision check reads the tray
- the v1 latch servo channel is unused in v3 and can be dropped

---

## 11. Checking the ramp is continuous

A tablet leaves the carousel through the deck's wedge and is then on its own until
it reaches the tray. Anywhere the ramp is interrupted, it drops into the
electronics bay instead — a silent partial dose, which is the worst failure this
machine has. Two things guarantee it cannot happen, and one check proves it.

The ramp starts at y = 14, inside the opening's 16 mm inner radius, so it extends
under the whole wedge rather than starting at its edge. And the notch through the
drum wall is cut as a box **minus the chute solid**, so the subtraction can only
ever remove housing wall — retuning `chute_stations`, `chute_win_w` or the notch
heights cannot put a hole in the floor.

`check_drop_path.scad` proves it rather than assuming it. It intersects the base
body with the exact volume a tablet can fall through (the wedge, extruded from the
deck's underside down to the bay floor) and shows what material is inside it. Open
it, F5, then look straight down: the wedge footprint must be filled edge to edge.
Since the notch removes everything else under the wedge, anything you see there is
ramp, and any daylight is a hole. Re-run it after touching the chute.

---

## 12. Risks

| Risk | Mitigation |
| :--- | :--- |
| Bracket twists under servo reaction torque | 26 mm gusset web, 12 mm ribs, two screws into the pad; if it still flexes, add a second arm to the opposite wall |
| Deck warps and the carousel binds | Deck prints as the first layer; the 0.35 mm gap absorbs the rest; coupon C1 proves it before the 7 h print |
| Servo parks outside +/- 6.2 deg | Use a positional servo; verify each stop by eye on the first fill |
| Tablets wedge at the wedge edge | 1.2 mm lead-in relief on the opening's top face |
| Chute cantilevers out of the notch | Notch is only as wide as the pill passage so the chute's own walls fuse into the wall, plus two shoulder fins back to the bore and a hoop strip under the notch |
| A tablet drops through a gap in the ramp | The notch cannot breach the floor by construction, and `check_drop_path.scad` proves it — section 11 |

---

## 13. Not in v3

- No gate or shutter. The park convention makes one unnecessary.
- No homing sensor. Only needed if you insist on a continuous-rotation servo.
- No lid. The drawing has none and the bracket occupies the rim.
- No pocket inserts. Add them if small tablets rattle in a 4.6 cm3 bin.
