// ============================================================================
// v2 PART E — servo bridge (direct drive, no gears)
//
// A four-arm spider that bolts to four external bosses on the drum rim. The
// MG90S drops through the centre pad with its flange resting on top, shaft
// pointing down into the carousel hub. Because the bosses are OUTSIDE the wall,
// nothing intrudes into the bore: undo four screws, lift the bridge, and the
// carousel comes straight out for refilling.
// ============================================================================

include <parameters_v2.scad>;
include <lib_v2.scad>;

$fn = 96;

pad_d      = 40.0;
arm_w      = 18.0;
arm_r      = h_od / 2 + boss_out;          // 65.0
screw_r    = h_od / 2 + boss_out / 2;      // 62.5
body_cx    = servo_l / 2 - servo_shaft_in; // 5.5 — body centre vs shaft axis
tab_screw_dx = servo_tab_span / 2 - 2.5;   // 13.6

module servo_bridge_v2() {
    translate([0, 0, bridge_z])
    difference() {
        union() {
            cylinder(h = bridge_t, d = pad_d);
            for (a = boss_angles)
                rotate([0, 0, a]) {
                    translate([0, -arm_w / 2, 0])
                        cube([arm_r - bridge_ear_w / 2, arm_w, bridge_t]);
                    translate([arm_r - bridge_ear_w / 2, 0, 0])
                        cylinder(h = bridge_t, d = bridge_ear_w);
                }
        }

        // MG90S body pocket — placed so the output shaft is on the drum axis.
        translate([-servo_shaft_in - fit_slip / 2, -(servo_w + fit_slip) / 2, -0.1])
            cube([servo_l + fit_slip, servo_w + fit_slip, bridge_t + 0.2]);

        // Servo flange screws.
        for (s = [-1, 1])
            translate([body_cx + s * tab_screw_dx, 0, -0.1])
                cylinder(h = bridge_t + 0.2, d = m2_free_d);

        // Bridge-to-drum screws.
        for (a = boss_angles)
            rotate([0, 0, a])
                translate([screw_r, 0, -0.1])
                    cylinder(h = bridge_t + 0.2, d = m3_free_d);
    }
}

// Print orientation: flat on the bed.
translate([0, 0, -bridge_z]) servo_bridge_v2();

echo(str("E2 bridge: 4 arms to r ", arm_r, " mm, servo pocket ",
         servo_l + fit_slip, " x ", servo_w + fit_slip));
