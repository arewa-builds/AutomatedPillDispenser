# v3 STL plan — "integral deck + open carousel"

Plan of record for turning the v3 reference design into printable STLs. Nothing is
modelled yet; this document is the spec that the OpenSCAD sources will implement.

![v3 reference design](reference_design.png)

---

## 1. Design intent read from the reference

| Feature in the drawing | How it is built |
| :--- | :--- |
| Grey cylindrical container housing | 120 mm OD drum, 3 mm wall, 92 mm tall |
| Open carousel, **no outer wall** | Compartments are closed on the outside by the drum bore; carousel is a hub + 8 radial dividers only |
| Dividers flush with the housing | 0.35 mm running gap to the deck below, 0.7 mm sweep gap to the bore |
| 8 compartments | 45 deg pitch |
| Direct servo drive shaft, no gears | MG90S above the carousel, printed shaft extension down to the hub |
| Servo support bracket | L bracket, screwed to a pad on the drum's inner wall, cantilevered to the axis, gusseted |
| Discharge opening | One tapered wedge through the deck, feeding straight into the chute |
| 45 deg chute walls | Chute is integral to the housing: the wedge channel ramps down and out through the wall |
| Pill catcher tray, opening flush with the chute walls | Tray with a cut-down mouth wall that butts against the chute exit |

Load-bearing consequence of "no outer wall": the drum bore is a sealing surface, so
the bore must stay round and the carousel must never be forced against it. Every
clearance in section 5 follows from that.

---

## 2. The one problem this geometry has, and the two ways out

Pills sit directly on the deck. The deck has one opening. There is **no rotation
angle at which a compartment-sized opening is covered** — a divider is only 2.4 mm
thick, so at rest the opening always exposes part of two neighbouring compartments
and they dribble into the chute. This is not a tolerance issue; it is geometric.

**Variant A — hidden gate (recommended).** A flat shutter slides under the deck,
driven by the second MG90S already in the BOM. The drawn geometry is untouched:
open compartments with no floor, dividers flush to the deck, full-width discharge
wedge. The gate lives entirely below the deck and is invisible in every view of the
drawing. Parking tolerance becomes about +/- 20 deg, so servo repeatability stops
mattering, and `firmware/pill_dispenser/pill_dispenser.ino` already drives exactly
this pair (carousel servo + latch servo).

**Variant B — one servo only.** Keep a single servo by giving the carousel a floor
with one 22 deg drop hole per compartment plus ramped floors, and narrowing the deck
opening to 15 deg. Leak rule: `45 - 22 = 23 deg` of covering band must exceed the
15 deg opening, leaving only **+/- 4 deg** of parking error. That rules out a
continuous-rotation servo with timed steps and gives 4 doses per fill on a standard
180 deg MG90S (45 deg steps across its travel). It also changes the carousel from
the drawn open bins into holed bins.

Everything below builds Variant A; Variant B is a parameter flag (`GATE = false`)
that swaps two parts.

---

## 3. Why the housing splits into two prints

The deck (the carousel's running surface) is a 114 mm disc 52 mm up inside a drum.
Printed as one piece it is either an unprintable 114 mm bridge or a support forest
against the surface that has to stay flat.

Splitting at the deck plane makes both halves trivial:

- **Upper "deck body"** — printed **deck-down**: the deck is the first layer (perfectly
  flat), the drum wall rises from it, the discharge wedge is just a hole, the bracket
  pad and pilot post grow upward. No supports.
- **Lower "base body"** — printed open-end-down: the 45 deg chute ramp and the
  external trough are 45 deg overhangs, self-supporting. No supports.

They lap on a 3 mm spigot and take three M3 screws. Bonus: with the deck integral to
the drum, the v1 "plate rotates instead of the carousel" failure becomes impossible —
there is no separate plate to rotate.

Alternative if you would rather keep the deck replaceable: a drop-in keyed plate as
in v2. Costs the anti-rotation keys and a ledge, gains tunability. Not the default.

---

## 4. STL manifest

Nine functional parts, three test coupons.

| # | Source file | STL | Qty | Function | Print orientation | Supports |
| ---: | :--- | :--- | ---: | :--- | :--- | :--- |
| 1 | `part_a3_deck_body.scad` | `part_a3_deck_body.stl` | 1 | Deck + drum wall + discharge wedge + pilot post + bracket pad + lap spigot | Deck down | none |
| 2 | `part_b3_base_body.scad` | `part_b3_base_body.stl` | 1 | Bay + 45 deg chute ramp + wall exit + trough lip + base posts + cable port | Open end down | none |
| 3 | `part_c3_carousel.scad` | `part_c3_carousel.stl` | 1 | Hub + 8 dividers, no outer wall, shaft socket + pilot journal | Divider ends down on the bed | none |
| 4 | `part_d3_drive_shaft.scad` | `part_d3_drive_shaft.stl` | 1 | Horn pocket on top, hex key into the hub | Vertical | brim |
| 5 | `part_e3_servo_bracket.scad` | `part_e3_servo_bracket.stl` | 1 | L bracket + gusset + MG90S pocket | Wall pad flat on the bed | none |
| 6 | `part_f3_gate.scad` (A) | `part_f3_gate.stl` | 1 | Sliding shutter, crank slot | Flat | none |
| 7 | `part_g3_gate_servo_mount.scad` (A) | `part_g3_gate_servo_mount.stl` | 1 | Second MG90S mount + crank pivot inside the bay | Flat | none |
| 8 | `part_h3_catch_tray.scad` | `part_h3_catch_tray.stl` | 1 | Tray, mouth wall cut down flush to the chute exit | Flat | none |
| 9 | `part_i3_base_cover.scad` | `part_i3_base_cover.stl` | 1 | Electronics floor, countersunk screws, foot pads | Flat | none |
| C1 | `coupon_1_sector.scad` | `coupon_1_sector.stl` | 1 | 45 deg slice of deck + one divider + pilot: proves the running gaps | as modelled | none |
| C2 | `coupon_2_servo_fit.scad` | `coupon_2_servo_fit.stl` | 1 | MG90S pocket + horn pocket + hub socket: proves the servo/shaft fits | as modelled | none |
| C3 | `coupon_3_chute_dock.scad` | `coupon_3_chute_dock.stl` | 1 | Chute exit lip + tray mouth: proves the flush dock | as modelled | none |

Variant B swaps #6 and #7 for a floored, ramped `part_c3_carousel` and a narrower
deck opening — no new files, just `GATE = false`.

Shared: `parameters_v3.scad`, `lib_v3.scad` (reused from v2), `assembly_preview_v3.scad`,
`render_all_v3.sh`.

---

## 5. Locked parameters

Drum and deck:

| Parameter | Value | Why |
| :--- | :--- | :--- |
| Drum OD / wall / bore | 120 / 3.0 / 114 mm | fits any 180 mm bed, 3 mm is 7 perimeters at 0.4 mm |
| Overall height (to rim) | 92 mm | bay 52 + carousel 26 + headroom |
| Deck thickness | 5 mm | it is now structural, not a drop-in plate |
| Deck top | z = 52 mm | leaves a 16 mm chute mouth above the bay floor |
| Lap spigot | 3 mm tall, 0.30 mm slip | joins the two bodies |
| Pilot post | 10.0 mm dia x 3.0 mm | carries carousel weight, journal is 10.35 mm |

Carousel:

| Parameter | Value |
| :--- | :--- |
| Compartments | 8 (45 deg pitch) |
| Carousel OD | 112.6 mm (0.7 mm sweep gap per side) |
| Divider thickness / height | 2.4 / 26 mm |
| Divider to deck running gap | 0.35 mm |
| Hub OD | 28 mm, with a 7 mm A/F hex shaft socket |
| Dose capacity | ~4.6 cm3 per compartment, roughly 10-14 standard tablets |

Discharge and chute:

| Parameter | Value (Variant A) | Value (Variant B) |
| :--- | :--- | :--- |
| Deck opening | 30 deg sector, r 18 to 56.7 (breaches the rim) | 15 deg sector |
| Carousel floor | none (open bins, as drawn) | 2.4 mm floor, 22 deg hole, 22 deg ramps |
| Gate travel | 26 mm, 2.4 mm thick, rails at z 46.5-49.5 | n/a |
| Internal ramp | 40 deg | 40 deg |
| Wall exit window | 46 wide x 24 tall, z 14-38, 45 deg gable roof | same |
| External run | 45 deg, exits at z = 6 mm | same |

Servo train:

| Parameter | Value |
| :--- | :--- |
| Bracket reach | 57 mm from bore to axis, arm 20 wide x 10 deep, 3 mm gusset web |
| Bracket pad | 26 x 34 x 6 mm, 2x M3 into the drum wall pad |
| Shaft extension | 10 mm dia x 30 mm, round-horn pocket up, 7 mm hex down |
| Carousel step | 45 deg per dose |
| Gate open/closed | 26 mm of linear travel from a 15 mm crank |

Tray:

| Parameter | Value |
| :--- | :--- |
| Footprint | 78 x 62 x 14 mm, 2 mm floor |
| Mouth | 44 wide x 16 tall cut-down wall, butts flush to the chute exit |

---

## 6. Print plan

| Part | Est. filament | Est. time |
| :--- | ---: | ---: |
| A3 deck body | ~85 g | ~7 h |
| B3 base body | ~70 g | ~6 h |
| C3 carousel | ~35 g | ~3 h |
| H3 tray | ~28 g | ~2.5 h |
| I3 base cover | ~20 g | ~1.5 h |
| E3 bracket, D3 shaft, F3 gate, G3 mount | ~25 g total | ~2.5 h |
| **Total** | **~265 g** | **~22 h** |

Settings: PLA, 0.4 mm nozzle, 0.2 mm layers (0.15 mm for C3 and the deck's top
surface if your printer is tuned), 3 perimeters, 20-25 % infill, no supports on any
functional part. PETG for `part_f3_gate` if it feels sticky in PLA.

---

## 7. Bought parts

| Qty | Item | Note |
| ---: | :--- | :--- |
| 2 | MG90S | carousel + gate (Variant A) |
| 4 | M3 x 10 self-tapping | 3 body-to-body, 1 spare |
| 2 | M3 x 10 self-tapping | bracket to wall pad |
| 3 | M3 x 10 self-tapping | base cover to posts |
| 4 | M2 x 6 | servo flanges (2 per servo) |
| 4 | M2 x 6 self-tapping | round horn into the carousel hub |
| 1 | M3 x 16 + nut | gate crank pivot |

No bearings, no rods, no gears.

---

## 8. Print the coupons first

Roughly 40 minutes of printing that de-risks 22 hours:

1. **C1 sector** — drop the carousel slice onto the deck slice and spin it. Looking
   for: no rub on the deck, no rub on the bore, and a tablet that cannot slip under a
   divider. If it rubs, `car_gap` and `sweep_gap` change and nothing else does.
2. **C2 servo fit** — MG90S must drop into the bracket pocket without forcing, and the
   shaft's hex must engage the hub socket with no slop.
3. **C3 chute dock** — the tray mouth should sit flush against the chute lip with no
   step for a tablet to catch on.

Only then print A3 and B3.

---

## 9. Build sequence

| Gate | Step | Done when |
| :--- | :--- | :--- |
| G0 | Lock the two decisions in section 2 and 3 | you confirm |
| G1 | `parameters_v3.scad` + `lib_v3.scad` | compiles, echoes the derived clearances |
| G2 | A3 deck body, B3 base body | render clean, lap joint mates in the preview |
| G3 | C3 carousel, D3 shaft, E3 bracket | preview shows the shaft engaging both ends |
| G4 | F3 gate + G3 mount (Variant A) | gate sweeps the full opening in the preview |
| G5 | H3 tray, I3 base cover | tray mouth flush in the section view |
| G6 | Assembly preview + half section + cutaway | pill path clear end to end |
| G7 | `render_all_v3.sh` | 9 STLs + 3 coupons, zero manifold warnings |
| G8 | Firmware constants updated | 45 deg steps, gate open/close angles |

---

## 10. Firmware touch points

`firmware/pill_dispenser/pill_dispenser.ino` already runs a carousel servo plus a
latch servo on a non-blocking `millis()` state machine, so Variant A needs constants,
not new logic:

- carousel step 45 deg (was 8 pockets / 45 deg in v1 — unchanged)
- gate open / closed angles from the 26 mm travel and 15 mm crank
- dose sequence: gate closed, advance 45 deg, settle, gate open, dwell, gate closed
- detach both servos between doses (existing behaviour)

---

## 11. Risks

| Risk | Mitigation |
| :--- | :--- |
| Bracket cantilever twists under servo reaction torque | 3 mm gusset web, 10 mm deep arm, two screws into the pad; if it still flexes, add a second arm to the opposite wall (a Y bridge) |
| Deck warps and the carousel binds | Deck prints as the first layer (best flatness); 0.35 mm gap absorbs the rest; coupon C1 proves it before the 7 h print |
| Gate friction after a few hundred cycles | Print the gate in PETG against PLA rails; rails are 0.4 mm wider than the gate |
| Tablets wedge at the discharge edge | 1.2 mm lead-in relief on the opening's top face, as in v2 |
| Continuous-rotation servo drift | Variant A makes it harmless; if you go Variant B, use a positional servo |

---

## 12. What is not in v3

- No homing sensor. Variant A does not need one.
- No lid. The drawing has none; the bracket occupies the rim. Easy to add later.
- No pocket inserts. Add them if small tablets rattle.
