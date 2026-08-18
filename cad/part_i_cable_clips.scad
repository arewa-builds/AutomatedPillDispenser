// Part I — Cable / USB strain-relief clips (print 4)
// Glue or screw inside Part A near Nano USB and servo leads.
// Export → stl/part_i_cable_clips.stl
// Print flat. No supports.

include <parameters.scad>;

$fn = 32;

module single_clip() {
    difference() {
        union() {
            // Base pad
            translate([0, 0, 1])
                cube([clip_w + 4, 12, 2], center = true);
            // Arch over cable
            translate([0, 0, 2])
                difference() {
                    translate([0, 0, clip_span / 2])
                        cube([clip_w, 8, clip_span + 2], center = true);
                    translate([0, 0, clip_span / 2 + 0.5])
                        cube([clip_w - 2.4, 9, clip_span], center = true);
                    // open front
                    translate([0, 5, clip_span / 2 + 0.5])
                        cube([clip_w - 2.4, 6, clip_span], center = true);
                }
        }
        // Mount hole
        cylinder(h = 8, d = 2.2, center = true);
    }
}

module part_i_cable_clips() {
    for (i = [0 : 3])
        translate([i * 18, 0, 0])
            single_clip();
}

part_i_cable_clips();
