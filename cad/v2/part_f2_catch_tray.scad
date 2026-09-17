// ============================================================================
// v2 PART F — catch tray ("pill catcher")
//
// Free-standing, lifts away for the patient to take the dose, and doubles as
// the flat matte landing zone the laptop camera counts pills in. The rear wall
// is short so it tucks under the chute lip.
// ============================================================================

include <parameters_v2.scad>;
include <lib_v2.scad>;

$fn = 64;

corner_r = 6.0;

module f2_shell(inset, h, z0) {
    x = tray_w - 2 * inset;
    y = tray_l - 2 * inset;
    translate([0, tray_y0 + tray_l / 2, z0])
        hull() for (ix = [-1, 1], iy = [-1, 1])
            translate([ix * (x / 2 - corner_r), iy * (y / 2 - corner_r), 0])
                cylinder(h = h, r = corner_r);
}

module catch_tray_v2() {
    difference() {
        f2_shell(0, tray_h, base_z);
        // Well.
        f2_shell(tray_floor + 1.6, tray_h, base_z + tray_floor);
        // Drop the rear wall so the chute lip overhangs into the well.
        translate([-tray_w / 2 - 1, tray_y0 - 1, base_z + tray_rear_h])
            cube([tray_w + 2, 6, tray_h]);
    }
}

// Print orientation: as modelled, flat on the bed.
translate([0, 0, -base_z]) catch_tray_v2();

echo(str("F2 tray: ", tray_w, " x ", tray_l, " x ", tray_h, " mm"));
