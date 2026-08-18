// Part D — Latch / side-gate (driven by second MG90S)
// Export:
//   cad/stl/part_d_latch_gate.stl
//   cad/stl/part_d_latch_horn_arm.stl  (set BUILD = "arm")
// Print gate flat; print arm flat. Snap gate into Part B rail grooves.

include <parameters.scad>;

$fn = 64;

// "gate" | "arm" | "both"
BUILD = "both";

module latch_gate() {
    // Sliding plate that covers/uncovers the drop hole
    difference() {
        union() {
            // Main gate blade
            translate([0, 0, gate_thickness / 2])
                cube([gate_w, gate_l, gate_thickness], center = true);
            // Side runners that ride in Part B grooves
            for (x = [-(drop_w / 2 + 2.5), (drop_w / 2 + 2.5)])
                translate([x, 0, gate_thickness / 2])
                    cube([1.8, gate_l - 2, gate_thickness + 1.2], center = true);
            // Drive tab toward servo ( -X )
            translate([-gate_w / 2 - 6, gate_l / 2 - 6, gate_thickness / 2])
                cube([12, 8, gate_thickness], center = true);
        }
        // Slot in drive tab for servo arm pin / screw
        translate([-gate_w / 2 - 8, gate_l / 2 - 6, gate_thickness / 2])
            rotate([0, 0, 0])
                hull() {
                    translate([-3, 0, 0]) cylinder(h = gate_thickness + 2, d = 2.2, center = true);
                    translate([3, 0, 0]) cylinder(h = gate_thickness + 2, d = 2.2, center = true);
                }
    }
}

module latch_servo_arm() {
    // Simple horn extension arm for MG90S → gate slot
    difference() {
        union() {
            cylinder(h = 3, d = 12, center = false);
            translate([0, -gate_travel / 2 - 4, 1.5])
                cube([6, gate_travel + 10, 3], center = true);
        }
        // Horn screw
        translate([0, 0, -0.1])
            cylinder(h = 4, d = 2.2, center = false);
        // Cross for stock horn
        translate([0, 0, 1.5])
            cube([10, 1.4, 4], center = true);
        translate([0, 0, 1.5])
            cube([1.4, 10, 4], center = true);
        // Pin hole at tip
        translate([0, -gate_travel - 2, 1.5])
            cylinder(h = 4, d = 2.0, center = true);
    }
}

module latch_servo_bracket() {
    // Optional micro bracket hint (printed with gate file as reference block)
    difference() {
        cube([servo_w + 8, servo_l + 10, 10], center = true);
        cube([servo_w + clearance_slip * 2, servo_l + clearance_slip * 2, 12], center = true);
        // Wire exit
        translate([0, servo_l / 2, 0])
            cube([6, 8, 6], center = true);
    }
}

if (BUILD == "gate") {
    latch_gate();
} else if (BUILD == "arm") {
    latch_servo_arm();
} else {
    latch_gate();
    translate([40, 0, 0]) latch_servo_arm();
    translate([40, 35, 5]) latch_servo_bracket();
}
