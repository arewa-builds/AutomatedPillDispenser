// Part B — Stationary base plate (drop floor)
// Export STL → cad/stl/part_b_base_plate.stl
// Print flat on face. No supports.

include <parameters.scad>;

$fn = 96;

module part_b_base_plate() {
    difference() {
        cylinder(h = base_plate_h, d = base_plate_dia, center = false);

        // Servo shaft / horn clearance at center
        translate([0, 0, -0.1])
            cylinder(h = base_plate_h + 0.2, d = servo_shaft_clear_d, center = false);

        // Drop hole over chute (toward +Y)
        translate([0, drop_r_offset, base_plate_h / 2])
            cube([drop_w, drop_d, base_plate_h + 2], center = true);

        // Countersink ring so pills don't catch on hole edge
        translate([0, drop_r_offset, base_plate_h - 0.8])
            cube([drop_w + 1.5, drop_d + 1.5, 2], center = true);

        // Latch rail slots (Part D slides here) — shallow grooves beside drop hole
        translate([-(drop_w / 2 + 2.5), drop_r_offset, base_plate_h - 1.2])
            cube([2.2, gate_l - 4, 2.5], center = true);
        translate([+(drop_w / 2 + 2.5), drop_r_offset, base_plate_h - 1.2])
            cube([2.2, gate_l - 4, 2.5], center = true);

        // Alignment notches for enclosure (optional keying)
        for (a = [0, 180])
            rotate([0, 0, a])
                translate([base_plate_dia / 2 - 2, 0, base_plate_h / 2])
                    cube([4, 6, base_plate_h + 1], center = true);
    }

    // Small fence lip opposite drop hole to keep pills from escaping rear
    translate([0, -base_plate_dia / 2 + 3, base_plate_h + 1])
        cube([40, 2, 2], center = true);
}

part_b_base_plate();
