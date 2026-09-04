// Part H — Dedicated latch MG90S mounting bracket
// Mounts secondary servo beside drop hole to drive Part D gate.
// Export → stl/part_h_latch_servo_bracket.stl
// Print flat on back plate. No supports.

include <parameters.scad>;

$fn = 48;

module part_h_latch_servo_bracket() {
    body_l = servo_l + 12;
    body_w = servo_w + 2 * bracket_wall + 2;
    body_h = 14;

    difference() {
        union() {
            // Back plate (screws to Part A side wall or plate post)
            translate([0, 0, 1.2])
                cube([body_w + 16, body_l + 4, 2.4], center = true);
            // Cradle around servo body
            translate([0, 0, body_h / 2])
                cube([body_w, body_l, body_h], center = true);
            // Horn clearance tower toward gate
            translate([body_w / 2 + 6, body_l / 2 - 4, 8])
                cube([14, 8, 10], center = true);
        }
        // Servo cavity
        translate([0, 0, body_h / 2 + 1])
            cube([servo_w + clearance_slip * 2, servo_l + clearance_slip * 2, body_h + 2], center = true);
        // Wire exit
        translate([0, -body_l / 2, 6])
            cube([8, 10, 6], center = true);
        // Tab screw holes (MG90S mounting ears)
        for (y = [-servo_tab_l / 2 + 3, servo_tab_l / 2 - 3])
            translate([0, y, body_h - 2])
                cylinder(h = 8, d = 1.8, center = true);
        // Bracket-to-housing screws
        for (x = [-(body_w / 2 + 5), (body_w / 2 + 5)])
            translate([x, 0, 1.2])
                cylinder(h = 6, d = 2.2, center = true);
        // Horn shaft clearance
        translate([body_w / 2 + 6, body_l / 2 - 4, 10])
            cylinder(h = 12, d = 10, center = true);
    }
}

part_h_latch_servo_bracket();
