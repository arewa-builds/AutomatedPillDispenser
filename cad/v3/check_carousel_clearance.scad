// ============================================================================
// v3 CHECK — can the carousel actually turn?
//
// Not a printable part. The dividers are radial, so as the carousel turns it
// sweeps one solid ring: everything between car_z and car_top, from the hub out
// to car_r. Any fixed material inside that ring is a jam, not a tight fit, and
// it is easy to miss in a render because the bracket looks like it is behind the
// carousel when it is really in its path.
//
// So this intersects each fixed assembly with that swept ring. The swept ring is
// built by revolving the divider's own (r, z) profile, chamfer included, so the
// wall-root fillet does not read as a clash when the chamfer already clears it.
//
// How to read it: open in OpenSCAD, F5. Modes 0 and 2 must render NOTHING AT ALL
// (OpenSCAD reports an empty top level). Mode 1 must show only the pilot post —
// that one lives inside the hub's journal on purpose — and mode 3 only the drive
// shaft's hex foot, which turns with the carousel.
//
// Run this after moving the bracket, the wall, the rim or the divider height.
//
//   MODE = 0   bracket inside the swept ring          (must be empty)
//   MODE = 1   deck body inside the swept ring        (pilot post only)
//   MODE = 2   base body inside the swept ring        (must be empty)
//   MODE = 3   drive shaft inside the swept ring      (hex foot only)
//   MODE = 4   the swept ring alone, for orientation
// ============================================================================

include <parameters_v3.scad>;
include <lib_v3.scad>;
use <part_a3_deck_body.scad>;
use <part_b3_base_body.scad>;
use <part_d3_drive_shaft.scad>;
use <part_e3_servo_bracket.scad>;

MODE = 0;

$fn = 128;

div_r_in = hub_od / 2 - 0.5;               // as part C3 builds them

// The divider profile revolved a full turn, plus the hub. Authored bottom-up and
// mirrored, because the chamfer is on the outer BOTTOM corner.
module swept_ring() {
    translate([0, 0, car_z]) {
        translate([0, 0, div_h]) mirror([0, 0, 1])
            rotate_extrude(convexity = 4)
                polygon([[div_r_in, 0],
                         [car_r, 0],
                         [car_r, div_h - div_chamfer],
                         [car_r - div_chamfer, div_h],
                         [div_r_in, div_h]]);
        cylinder(h = div_h, d = hub_od);
    }
}

if (MODE == 0) {
    intersection() { servo_bracket_v3(); swept_ring(); }
} else if (MODE == 1) {
    intersection() { deck_body_v3(); swept_ring(); }
} else if (MODE == 2) {
    intersection() { base_body_v3(); swept_ring(); }
} else if (MODE == 3) {
    intersection() { drive_shaft_v3(); swept_ring(); }
} else {
    color("#c0392b") swept_ring();
}

echo(str("Swept ring: z ", car_z, " to ", car_top, ", r ", div_r_in, " to ", car_r,
         ", sweep gap to the bore ", h_ri - car_r, " per side"));
echo(str("Bracket starts at z ", brk_pad_z0, ", i.e. ", brk_pad_z0 - car_top,
         " above the dividers; gusset tip z ", brk_arm_z0 - brk_web_h,
         ", ribs z ", brk_arm_z0 - brk_rib_h));
echo(str("Wall screws at z ", brk_screw_z, " in wall that ends at z ", rim_z));
