// Part J — Anti-slip foot
// Single-body STL (print qty 4 in slicer):
//   LAYOUT="single" → stl/part_j_foot.stl   (default)
//   LAYOUT="grid"   → preview of 4 only (not for slicing)

include <parameters.scad>;

$fn = 48;
LAYOUT = "single";

module single_foot() {
    difference() {
        cylinder(h = foot_h, d = foot_od, center = false);
        translate([0, 0, foot_h - 1])
            cylinder(h = 1.2, d = foot_od - 4, center = false);
        translate([0, 0, -0.1])
            cylinder(h = foot_h + 0.2, d = 2.2, center = false);
    }
}

if (LAYOUT == "grid") {
    for (i = [0 : 3])
        translate([(i % 2) * 20, floor(i / 2) * 20, 0])
            single_foot();
} else {
    single_foot();
}
