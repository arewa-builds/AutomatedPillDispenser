// Part D — Latch sliding gate + servo drive arm
// Separate STLs (no multi-body plate):
//   BUILD="gate" → stl/part_d_latch_gate.stl
//   BUILD="arm"  → stl/part_d_latch_horn_arm.stl
//   BUILD="both" → preview layout only (not for slicing)
// Bracket is Part H.

include <parameters.scad>;

$fn = 64;
BUILD = "gate";

module latch_gate() {
    difference() {
        union() {
            translate([0, 0, gate_thickness / 2])
                cube([gate_w, gate_l, gate_thickness], center = true);
            for (x = [-(drop_w / 2 + 2.5), (drop_w / 2 + 2.5)])
                translate([x, 0, gate_thickness / 2])
                    cube([1.8, gate_l - 2, gate_thickness + 1.2], center = true);
            translate([-gate_w / 2 - 6, gate_l / 2 - 6, gate_thickness / 2])
                cube([12, 8, gate_thickness], center = true);
        }
        translate([-gate_w / 2 - 8, gate_l / 2 - 6, gate_thickness / 2])
            hull() {
                translate([-3, 0, 0]) cylinder(h = gate_thickness + 2, d = 2.2, center = true);
                translate([3, 0, 0]) cylinder(h = gate_thickness + 2, d = 2.2, center = true);
            }
    }
}

module latch_servo_arm() {
    difference() {
        union() {
            cylinder(h = 3, d = 12, center = false);
            translate([0, -gate_travel / 2 - 4, 1.5])
                cube([6, gate_travel + 10, 3], center = true);
        }
        translate([0, 0, -0.1]) cylinder(h = 4, d = 2.2, center = false);
        translate([0, 0, 1.5]) cube([10, 1.4, 4], center = true);
        translate([0, 0, 1.5]) cube([1.4, 10, 4], center = true);
        translate([0, -gate_travel - 2, 1.5])
            cylinder(h = 4, d = 2.0, center = true);
    }
}

if (BUILD == "arm") {
    latch_servo_arm();
} else if (BUILD == "both") {
    latch_gate();
    translate([40, 0, 0]) latch_servo_arm();
} else {
    latch_gate();
}
