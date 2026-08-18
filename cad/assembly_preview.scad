// Assembly preview — explore housing, carousel, plate, and latch together.
// Open in OpenSCAD and press F5. Toggle EXPLODED below.
// Do NOT print this file — export STLs from part_a / part_b / part_c / part_d instead.

include <parameters.scad>;

EXPLODED = true;
ez = EXPLODED ? 40 : 0;

$fn = 48;

// ----- Simplified inlined geometry for assembly view only -----

module rounded_box(x, y, z, r) {
    hull() for (ix = [-1, 1], iy = [-1, 1])
        translate([ix * (x / 2 - r), iy * (y / 2 - r), 0])
            cylinder(h = z, r = r, center = true);
}

module preview_housing() {
    color("SteelBlue", 0.85)
    difference() {
        translate([0, 0, base_outer_h / 2])
            rounded_box(base_outer_xy, base_outer_xy, base_outer_h, 6);
        translate([0, 0, base_outer_h / 2 + wall])
            rounded_box(base_outer_xy - 2 * wall, base_outer_xy - 2 * wall, base_outer_h, 4);
        translate([0, 0, servo_h / 2 + wall])
            cube([servo_w + 1, servo_l + 1, servo_h + 2], center = true);
        translate([-32, -28, wall + nano_h / 2])
            cube([nano_l + 1, nano_w + 1, nano_h + 1], center = true);
        translate([-32, -base_outer_xy / 2, wall + 3])
            cube([11, 20, 6], center = true);
        translate([30, -30, wall + lipo_h / 2])
            cube([lipo_l + 1, lipo_w + 1, lipo_h + 1], center = true);
        translate([base_outer_xy / 2, -8, wall + 3])
            cube([20, 12, 6], center = true);
        // chute hint
        hull() {
            translate([0, drop_r_offset, base_outer_h - 6]) cube([chute_w, 2, 8], center = true);
            translate([0, base_outer_xy / 2 - 6, 10]) rotate([45, 0, 0]) cube([chute_w, 2, 8], center = true);
        }
        translate([0, 0, base_outer_h - base_plate_h / 2])
            cylinder(h = base_plate_h + 0.5, d = base_plate_dia + 0.6, center = true);
    }
}

module preview_plate() {
    color("Orange", 0.9)
    translate([0, 0, base_outer_h + ez])
    difference() {
        cylinder(h = base_plate_h, d = base_plate_dia);
        translate([0, 0, -0.1]) cylinder(h = base_plate_h + 0.2, d = servo_shaft_clear_d);
        translate([0, drop_r_offset, base_plate_h / 2])
            cube([drop_w, drop_d, base_plate_h + 2], center = true);
    }
}

module preview_carousel() {
    color("SeaGreen", 0.92)
    translate([0, 0, base_outer_h + base_plate_h + ez * 2]) {
        difference() {
            cylinder(h = car_h, d = car_dia);
            for (i = [0 : car_pockets - 1]) {
                rotate([0, 0, i * 360 / car_pockets + 3])
                    translate([car_hub_od / 2 + 3, 0, -0.1])
                        linear_extrude(height = car_h + 0.2)
                            polygon([
                                [0, 0],
                                [car_dia / 2 - car_wall - car_hub_od / 2 - 3, 0],
                                [(car_dia / 2 - car_wall - car_hub_od / 2 - 3) * cos(360 / car_pockets - 6),
                                 (car_dia / 2 - car_wall - car_hub_od / 2 - 3) * sin(360 / car_pockets - 6)]
                            ]);
            }
            translate([0, 0, -0.1]) cylinder(h = car_h + 0.2, d = car_hub_id);
        }
    }
}

module preview_latch() {
    color("Crimson", 0.95)
    translate([0, drop_r_offset, base_outer_h + base_plate_h + 0.5 + ez * 1.2])
        cube([gate_w, drop_d + 4, gate_thickness], center = true);
    // latch servo body hint on side
    color("IndianRed", 0.8)
    translate([-42, drop_r_offset, base_outer_h - 10 + ez])
        cube([servo_w, servo_l, servo_h], center = true);
}

module preview_labels() {
    // OpenSCAD has no native text dependency guarantee across builds; skip 3D text.
}

preview_housing();
preview_plate();
preview_carousel();
preview_latch();

echo("====================================================");
echo("ASSEMBLY PREVIEW");
echo(EXPLODED ? "Mode: EXPLODED (set EXPLODED=false to seat parts)" : "Mode: SEATED");
echo("Parts: Blue=Housing A | Orange=Plate B | Green=Carousel C | Red=Latch D");
echo("Export printable STLs from part_a/b/c/d_*.scad (F6 then Export STL)");
echo("====================================================");
