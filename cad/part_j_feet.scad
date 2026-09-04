// Part J — Anti-slip feet (print 4)
// Stick under Part A corners (CA glue or double-sided tape).
// Export → stl/part_j_feet.stl
// Print flat. Optional TPU for grip; PLA OK with adhesive pad.

include <parameters.scad>;

$fn = 48;

module single_foot() {
    difference() {
        cylinder(h = foot_h, d = foot_od, center = false);
        // Recess for adhesive foam pad
        translate([0, 0, foot_h - 1])
            cylinder(h = 1.2, d = foot_od - 4, center = false);
        // Optional screw hole through
        translate([0, 0, -0.1])
            cylinder(h = foot_h + 0.2, d = 2.2, center = false);
    }
}

module part_j_feet() {
    for (i = [0 : 3])
        translate([(i % 2) * 20, floor(i / 2) * 20, 0])
            single_foot();
}

part_j_feet();
