// Part E — Carousel lid / top cover
// Keeps pills in pockets during rotation; finger shield.
// Export → stl/part_e_carousel_lid.stl
// Print flat on top face (lip up). No supports.

include <parameters.scad>;

$fn = 96;

module part_e_carousel_lid() {
    difference() {
        union() {
            // Top disc
            cylinder(h = lid_h, d = lid_dia, center = false);
            // Descending lip that nests over carousel OD
            translate([0, 0, lid_h])
                difference() {
                    cylinder(h = lid_lip_h, d = lid_dia, center = false);
                    translate([0, 0, -0.1])
                        cylinder(h = lid_lip_h + 0.2, d = car_dia + lid_clearance * 2, center = false);
                }
        }
        // Center viewing / horn-screw access hole
        translate([0, 0, -0.1])
            cylinder(h = lid_h + lid_lip_h + 0.2, d = 12, center = false);
        // Optional refill window (pie cut) — leave one sector openable by rotating lid mark
        rotate([0, 0, 0])
            translate([lid_dia / 4 + 8, 0, lid_h / 2])
                cube([lid_dia / 2 - 10, 18, lid_h + 0.2], center = true);
    }
    // Finger grip tabs
    for (a = [90, 270])
        rotate([0, 0, a])
            translate([lid_dia / 2 - 1, 0, lid_h / 2])
                cube([4, 12, lid_h], center = true);
}

part_e_carousel_lid();
