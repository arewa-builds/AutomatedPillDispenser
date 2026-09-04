// Part G — Chute-to-tray spout extension
// Guides dispensed pill from housing chute into catch tray sweet spot.
// Export → stl/part_g_chute_spout.stl
// Print on side (long channel on bed) OR flat with supports in channel.

include <parameters.scad>;

$fn = 48;

module part_g_chute_spout() {
    difference() {
        union() {
            // Attachment flange (mates to Part A front wall / chute exit)
            translate([0, 0, 6])
                cube([chute_w + 10, 4, 16], center = true);
            // Sloped channel
            hull() {
                translate([0, 2, 6])
                    cube([chute_w + 2, 2, 12], center = true);
                translate([0, spout_len, 2])
                    cube([spout_flare, 2, 6], center = true);
            }
            // Side walls along channel
            for (x = [-(chute_w / 2 + 1), (chute_w / 2 + 1)])
                hull() {
                    translate([x, 2, 6]) cube([2.4, 2, 12], center = true);
                    translate([x * (spout_flare / chute_w), spout_len, 3])
                        cube([2.4, 2, 8], center = true);
                }
        }
        // Inner open channel
        hull() {
            translate([0, 1, 7])
                cube([chute_w - 1, 4, 10], center = true);
            translate([0, spout_len + 1, 3])
                cube([spout_flare - 4, 4, 5], center = true);
        }
        // Screw / glue holes on flange
        for (x = [-10, 10])
            translate([x, 0, 6])
                rotate([90, 0, 0])
                    cylinder(h = 8, d = 2.2, center = true);
    }
}

part_g_chute_spout();
