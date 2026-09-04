// Part A — Main base enclosure & electronics housing
// Open in OpenSCAD: F5 preview, F6 render, Export as STL → cad/stl/part_a_base_enclosure.stl
// Print flat on the large bottom face. Supports: light under chute underside only if needed.

include <parameters.scad>;

$fn = 64;

module nano_pocket() {
    // Pocket + USB exit toward -Y wall
    translate([0, 0, 0])
        cube([nano_l + clearance_slip * 2, nano_w + clearance_slip * 2, nano_h + 1.0], center = true);
}

module lipo_pocket() {
    cube([lipo_l + clearance_slip * 2, lipo_w + clearance_slip * 2, lipo_h + 1.0], center = true);
}

module tp4056_pocket() {
    cube([tp4056_l + clearance_slip * 2, tp4056_w + clearance_slip * 2, tp4056_h + 1.0], center = true);
}

module servo_well() {
    // Vertical MG90S well (body up through plate)
    cube([servo_w + clearance_slip * 2, servo_l + clearance_slip * 2, servo_h + 2], center = true);
}

module gravity_chute() {
    // 45° open channel from under drop zone toward +Y front
    hull() {
        translate([0, drop_r_offset, base_outer_h - 8])
            cube([chute_w, 2, 10], center = true);
        translate([0, base_outer_xy / 2 - 4, 8])
            rotate([chute_angle, 0, 0])
                cube([chute_w, 2, 10], center = true);
    }
}

module camera_alignment_lip() {
    // Thin front lip so laptop camera / tray can register against the housing
    translate([0, base_outer_xy / 2 - 1.2, base_outer_h - 3])
        cube([60, 2.4, 6], center = true);
}

module part_a_base_enclosure() {
    difference() {
        // Outer shell
        translate([0, 0, base_outer_h / 2])
            rounded_box(base_outer_xy, base_outer_xy, base_outer_h, 6);

        // Hollow interior
        translate([0, 0, base_outer_h / 2 + wall])
            rounded_box(base_outer_xy - 2 * wall, base_outer_xy - 2 * wall, base_outer_h, 4);

        // --- Component pockets (floor recesses) ---
        // Carousel servo centered
        translate([0, 0, servo_h / 2 + wall])
            servo_well();

        // Nano pocket — left rear, USB toward -Y
        translate([-32, -28, wall + nano_h / 2])
            nano_pocket();
        // USB cutout through outer wall
        translate([-32, -base_outer_xy / 2, wall + nano_h / 2])
            cube([nano_usb_w + 2, 20, nano_usb_h + 2], center = true);

        // LiPo pocket — right rear
        translate([30, -30, wall + lipo_h / 2])
            lipo_pocket();

        // TP4056 — right side wall, USB-C outward +X
        translate([base_outer_xy / 2 - wall - tp4056_l / 2 - 1, -8, wall + tp4056_h / 2])
            tp4056_pocket();
        translate([base_outer_xy / 2, -8, wall + tp4056_h / 2])
            cube([20, tp4056_usbc_w + 2, tp4056_usbc_h + 2], center = true);

        // Wire channel from servo to Nano
        translate([-12, -10, wall + 3])
            cube([40, 6, 6], center = true);

        // Chute void
        gravity_chute();

        // Top plate registration recess (Part B sits here)
        translate([0, 0, base_outer_h - base_plate_h / 2 + 0.01])
            cylinder(h = base_plate_h + 0.2, d = base_plate_dia + clearance_slip * 2, center = true);
    }

    // Servo mounting bosses (screw tabs)
    for (x = [-servo_tab_l / 2 + 2, servo_tab_l / 2 - 2])
        translate([x, 0, wall + 4])
            difference() {
                cube([6, servo_l + 8, 8], center = true);
                cylinder(h = 10, d = 1.8, center = true);
            }

    // Floor ribs under carousel for stiffness
    for (a = [0, 90])
        rotate([0, 0, a])
            translate([0, 0, wall + 1])
                cube([base_outer_xy - 20, 2.0, 2], center = true);

    camera_alignment_lip();
}

module rounded_box(x, y, z, r) {
    hull() {
        for (ix = [-1, 1], iy = [-1, 1])
            translate([ix * (x / 2 - r), iy * (y / 2 - r), 0])
                cylinder(h = z, r = r, center = true);
    }
}

part_a_base_enclosure();
