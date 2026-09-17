// ============================================================================
// v3 PART G3 — base cover / electronics floor
//
// Closes the bay under the deck and gives the Nano 33 BLE, TP4056 and LiPo a
// flat mounting floor. Three M3 screws pull it up into the posts moulded into
// the base body wall.
// ============================================================================

include <parameters_v3.scad>;
include <lib_v3.scad>;

$fn = 96;

foot_pad_d = 14.0;
foot_pad_r = h_od / 2 - 12.0;

module base_cover_v3() {
    translate([0, 0, base_z])
    difference() {
        cylinder(h = base_t, d = h_od);

        for (a = post_angles)
            rotate([0, 0, a]) {
                translate([post_r, 0, -0.1])
                    cylinder(h = base_t + 0.2, d = m3_free_d);
                // Countersink relief so screw heads sit flush with the table.
                translate([post_r, 0, -0.1])
                    cylinder(h = 1.8, d1 = m3_free_d + 3.0, d2 = m3_free_d);
            }

        // Shallow recesses to locate stick-on rubber feet.
        for (a = [45, 135, 225, 315])
            rotate([0, 0, a])
                translate([foot_pad_r, 0, -0.1])
                    cylinder(h = 0.8, d = foot_pad_d);
    }
}

// Print orientation: flat on the bed.
translate([0, 0, -base_z]) base_cover_v3();

echo(str("G3 base cover: dia ", h_od, " x ", base_t, " mm"));
