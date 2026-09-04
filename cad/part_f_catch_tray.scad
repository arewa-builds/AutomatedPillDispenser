// Part F — Catch tray / vision landing dish
// High-contrast well for OpenCV pill verify (place in front of housing chute).
// Export → stl/part_f_catch_tray.stl
// Print flat. No supports. Suggested: dark filament or paint well floor.

include <parameters.scad>;

$fn = 64;

module part_f_catch_tray() {
    difference() {
        // Outer tray
        translate([0, 0, tray_h / 2])
            rounded_rect(tray_l, tray_w, tray_h, 6);
        // Inner well
        translate([0, 0, tray_h / 2 + tray_floor])
            rounded_rect(
                tray_l - 2 * tray_well_margin,
                tray_w - 2 * tray_well_margin,
                tray_h,
                4
            );
        // Spout inlet notch on -Y edge (faces housing chute)
        translate([0, -tray_w / 2, tray_h / 2 + 2])
            cube([chute_w + 4, 12, tray_h], center = true);
    }
    // Registration pegs to mate with spout (optional glue)
    for (x = [-12, 12])
        translate([x, -tray_w / 2 + 3, tray_floor])
            cylinder(h = 3, d = 3.0, center = false);

    // Corner camera-calibration L-marks (raised 0.4 mm)
    for (ix = [-1, 1], iy = [-1, 1])
        translate([ix * (tray_l / 2 - 10), iy * (tray_w / 2 - 10), tray_floor])
            cube([6, 1.2, 0.4], center = false);
}

module rounded_rect(x, y, z, r) {
    hull() for (ix = [-1, 1], iy = [-1, 1])
        translate([ix * (x / 2 - r), iy * (y / 2 - r), 0])
            cylinder(h = z, r = r, center = true);
}

part_f_catch_tray();
