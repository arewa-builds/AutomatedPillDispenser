// Part I — Cable / USB strain-relief clip
// Single-body STL (print qty 4 in slicer):
//   LAYOUT="single" → stl/part_i_cable_clip.stl   (default)
//   LAYOUT="grid"   → preview of 4 only (not for slicing)

include <parameters.scad>;

$fn = 32;
LAYOUT = "single";

module single_clip() {
    difference() {
        union() {
            translate([0, 0, 1])
                cube([clip_w + 4, 12, 2], center = true);
            translate([0, 0, 2])
                difference() {
                    translate([0, 0, clip_span / 2])
                        cube([clip_w, 8, clip_span + 2], center = true);
                    translate([0, 0, clip_span / 2 + 0.5])
                        cube([clip_w - 2.4, 9, clip_span], center = true);
                    translate([0, 5, clip_span / 2 + 0.5])
                        cube([clip_w - 2.4, 6, clip_span], center = true);
                }
        }
        cylinder(h = 8, d = 2.2, center = true);
    }
}

if (LAYOUT == "grid") {
    for (i = [0 : 3])
        translate([i * 18, 0, 0])
            single_clip();
} else {
    single_clip();
}
