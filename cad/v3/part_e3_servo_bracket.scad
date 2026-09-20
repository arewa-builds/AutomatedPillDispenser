// ============================================================================
// v3 PART E3 — servo support bracket
//
// Cantilever from a pad on the inner wall out to the drum axis, gusseted and
// ribbed because it has to hold the MG90S steady against its own reaction
// torque while the carousel turns.
//
// Nothing here may dip below car_top: the dividers sweep that whole ring, and a
// pad crossing it locks the carousel solid. Pad, gusset and ribs all start above
// it, which is why the wall runs up to rim_z — both screws need wall above the
// sweep. check_carousel_clearance.scad is the proof.
//
// Screws come from OUTSIDE the drum into this pad, so the wall itself carries no
// internal boss. That matters: nothing permanently intrudes into the bore, and
// removing the bracket (which you must do to get at the carousel anyway) leaves
// a clear 114 mm opening to lift the carousel straight out.
//
// Prints flipped, flange plane down — see the note above the top-level call.
// ============================================================================

include <parameters_v3.scad>;
include <lib_v3.scad>;

$fn = 64;

pad_x0     = h_ri - brk_pad_t;             // 51
arm_z0     = brk_arm_z0;                   // 104
head_x0    = -11.0;
head_x1    = 21.0;
head_w     = 26.0;
body_cx    = servo_l / 2 - servo_shaft_in; // 5.5
tab_dx     = servo_tab_span / 2 - 2.5;     // 13.6

// A 3 mm rib tucked just inside each edge of the arm, deepest at the wall where
// the bending moment is. Kept inside the arm's width so neither rib hangs off an
// edge: that would be an unsupported flange, and it would make the arm stiffer on
// one side than the other.
module e3_rib(side) {
    y0 = side > 0 ? brk_arm_w / 2 - 3 : -brk_arm_w / 2;
    hull() {
        translate([pad_x0 - 3, y0, arm_z0 - brk_rib_h]) cube([3, 3, brk_rib_h]);
        translate([head_x1 + 0.5, y0, arm_z0 - 2.5]) cube([3, 3, 2.5]);
    }
}

module servo_bracket_v3() {
    rotate([0, 0, brk_ctr])
    difference() {
        union() {
            // Wall pad.
            translate([pad_x0, -brk_pad_w / 2, brk_pad_z0])
                cube([brk_pad_t, brk_pad_w, brk_pad_h]);
            // Arm + servo head.
            translate([head_x1 - 0.01, -brk_arm_w / 2, arm_z0])
                cube([pad_x0 - head_x1 + 0.02, brk_arm_w, brk_arm_t]);
            translate([head_x0, -head_w / 2, brk_arm_top - brk_head_t])
                cube([head_x1 - head_x0, head_w, brk_head_t]);
            // Gusset web: a 45 deg triangle tying the arm back into the pad.
            translate([0, 1.5, 0]) rotate([90, 0, 0])
                linear_extrude(height = 3)
                    polygon([[pad_x0, arm_z0],
                             [pad_x0, arm_z0 - brk_web_h],
                             [pad_x0 - brk_web_h, arm_z0]]);
            for (s = [-1, 1]) e3_rib(s);
        }

        // MG90S pocket — output shaft lands on the drum axis.
        translate([-servo_shaft_in - fit_slip / 2, -(servo_w + fit_slip) / 2,
                   brk_arm_top - brk_head_t - 0.1])
            cube([servo_l + fit_slip, servo_w + fit_slip, brk_head_t + 0.2]);
        for (s = [-1, 1])
            translate([body_cx + s * tab_dx, 0, brk_arm_top - brk_head_t - 0.1])
                cylinder(h = brk_head_t + 0.2, d = m2_free_d);

        // Wall screws (pilots) — driven in from outside the drum.
        for (z = brk_screw_z)
            translate([h_ri + 0.5, 0, z]) rotate([0, 90, 0])
                cylinder(h = brk_pad_t + 1.0, d = m3_pilot_d);

        // Follow the bore so the pad sits flush against the curved wall.
        difference() {
            cylinder(h = 200, d = h_od + 40, center = true);
            cylinder(h = 200, d = h_id, center = true);
        }
    }
}

// The module works in assembly coordinates so the preview can use it as-is; the
// top-level call is the print orientation. The pad's top, the arm's top and the
// servo plate's top all sit in the flange plane, so flipping about that plane
// lands the part on one large flat footprint. Everything else — pad, gusset,
// ribs — then grows upward from it, so nothing needs support.
translate([0, 0, brk_arm_top]) rotate([180, 0, 0])
    rotate([0, 0, -brk_ctr]) servo_bracket_v3();

echo(str("E3 bracket: reach ", h_ri, " mm, arm ", brk_arm_w, " x ", brk_arm_t,
         " + ", brk_rib_h, " mm ribs, flange plane z ", brk_arm_top));
