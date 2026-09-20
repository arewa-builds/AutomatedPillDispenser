// ============================================================================
// v3 COUPON C2 — drive train fit
//
// Print this before E3. About 45 minutes to prove the three fits that the whole
// drive train hangs on, cut from the real parts so they carry the real numbers:
//
//   * MG90S body into the bracket's plate pocket   (servo_l/w + fit_slip)
//   * round horn into the shaft head's pocket      (horn_disc_d + fit_slip)
//   * shaft's hex foot into the carousel hub       (hex_af + hex_slip)
//
// Three pieces:
//   1. Plate pad — the bracket's servo plate on its own, with the pocket and the
//      two M2 flange holes.
//   2. Drive shaft — the real D3 part, not a cut-down of it. It is small enough
//      to print for the test, and if it passes you keep it.
//   3. Hub puck — the socket end of the carousel's hub, dividers cut off flush.
//      The journal end is C1's job.
//
// What to look for:
//   1. The MG90S drops into the pocket and its flange lands flat on the plate,
//      no forcing. Too tight: raise fit_slip. Too loose: the servo can rock and
//      the parked angle wanders, so shim it rather than leaving it.
//   2. The horn seats fully in the shaft head and its 4 screw holes line up with
//      the pilots. Nothing should stand proud of the head's face.
//   3. The hex foot enters the hub socket with a little slop and no wobble. Slop
//      is intentional — the pilot post defines the axis, not the shaft — but you
//      should not be able to twist the shaft noticeably before the hub follows.
//   4. Stack piece 2 into piece 3 and push the servo into piece 1: the shaft's
//      head must clear the plate's underside. That is the 1.5 mm the design
//      claims, and it is the one clearance a render can flatter.
//
// Print as laid out, no supports. The shaft prints head-down, so give it a brim.
// ============================================================================

include <parameters_v3.scad>;
include <lib_v3.scad>;
use <part_c3_carousel.scad>;
use <part_d3_drive_shaft.scad>;
use <part_e3_servo_bracket.scad>;

$fn = 96;

pad_x0_c    = -13.0;                       // plate pad, a little wider than the
pad_x1_c    = 23.0;                        // pocket so the pocket has a rim
pad_w_c     = 30.0;
// Same expression as head_top in part D3 — the shaft's top face.
shaft_top   = brk_arm_top - servo_nose_h - servo_shaft_h + horn_disc_h;
gap         = 14.0;

module c2_plate_pad() {
    intersection() {
        // Undo the bracket's mounting angle so the plate lands axis-aligned.
        rotate([0, 0, -brk_ctr]) servo_bracket_v3();
        translate([pad_x0_c, -pad_w_c / 2, brk_arm_top - brk_head_t])
            cube([pad_x1_c - pad_x0_c, pad_w_c, brk_head_t]);
    }
}

// Only the socket end of the hub. The journal end is already proved by C1, and a
// full-height hub is 26 mm of solid filament for nothing.
puck_h = hex_depth + 4.0;

module c2_hub_puck() {
    intersection() {
        carousel_v3();
        translate([0, 0, car_top - puck_h]) cylinder(h = puck_h, d = hub_od);
    }
}

// Plate pad flat, as it sits on the servo.
translate([0, -(pad_w_c / 2 + gap), -(brk_arm_top - brk_head_t)]) c2_plate_pad();

// Hub puck as modelled — flat on the bed, socket up.
translate([0, hub_od / 2 + gap, -(car_top - puck_h)]) c2_hub_puck();

// Drive shaft in its own print orientation: head down, exactly as part D3
// exports it.
translate([shaft_head_d / 2 + hub_od / 2 + 2 * gap, hub_od / 2 + gap, 0])
    rotate([180, 0, 0]) translate([0, 0, -shaft_top]) drive_shaft_v3();

echo(str("C2 fits: servo pocket ", servo_l + fit_slip, " x ", servo_w + fit_slip,
         " for a ", servo_l, " x ", servo_w, " case"));
echo(str("C2 fits: horn pocket ", horn_disc_d + fit_slip, " for a ", horn_disc_d,
         " disc; hex socket ", hex_af + hex_slip, " A/F for a ", hex_af, " foot"));
