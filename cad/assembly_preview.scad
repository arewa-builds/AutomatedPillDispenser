// Final assembly preview — all printable prototype parts
// OpenSCAD F5 to explore. Toggle EXPLODED.
// Do not print this file — use individual part_*.scad exports.

include <parameters.scad>;

EXPLODED = true;
ez = EXPLODED ? 28 : 0;

$fn = 40;

module rounded_box(x, y, z, r) {
    hull() for (ix = [-1, 1], iy = [-1, 1])
        translate([ix * (x / 2 - r), iy * (y / 2 - r), 0])
            cylinder(h = z, r = r, center = true);
}

module rounded_rect(x, y, z, r) {
    hull() for (ix = [-1, 1], iy = [-1, 1])
        translate([ix * (x / 2 - r), iy * (y / 2 - r), 0])
            cylinder(h = z, r = r, center = true);
}

// A — Housing
module prev_a() {
    color("SteelBlue", 0.88)
    difference() {
        translate([0, 0, base_outer_h / 2])
            rounded_box(base_outer_xy, base_outer_xy, base_outer_h, 6);
        translate([0, 0, base_outer_h / 2 + wall])
            rounded_box(base_outer_xy - 2 * wall, base_outer_xy - 2 * wall, base_outer_h, 4);
        translate([0, 0, servo_h / 2 + wall])
            cube([servo_w + 1, servo_l + 1, servo_h + 2], center = true);
        translate([-32, -28, wall + 4]) cube([nano_l, nano_w, nano_h], center = true);
        translate([30, -30, wall + 3]) cube([lipo_l, lipo_w, lipo_h], center = true);
        translate([base_outer_xy / 2, -8, wall + 3]) cube([16, 12, 6], center = true);
        translate([-32, -base_outer_xy / 2, wall + 3]) cube([11, 16, 6], center = true);
        hull() {
            translate([0, drop_r_offset, base_outer_h - 6]) cube([chute_w, 2, 8], center = true);
            translate([0, base_outer_xy / 2 - 6, 10]) rotate([45, 0, 0]) cube([chute_w, 2, 8], center = true);
        }
        translate([0, 0, base_outer_h - base_plate_h / 2])
            cylinder(h = base_plate_h + 0.5, d = base_plate_dia + 0.6, center = true);
    }
}

// B — Plate
module prev_b() {
    color("DarkOrange", 0.92)
    translate([0, 0, base_outer_h + ez])
    difference() {
        cylinder(h = base_plate_h, d = base_plate_dia);
        translate([0, 0, -0.1]) cylinder(h = base_plate_h + 0.2, d = servo_shaft_clear_d);
        translate([0, drop_r_offset, base_plate_h / 2])
            cube([drop_w, drop_d, base_plate_h + 2], center = true);
    }
}

// C — Carousel
module prev_c() {
    z = base_outer_h + base_plate_h + ez * 2;
    color("SeaGreen", 0.9)
    translate([0, 0, z])
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

// D — Gate
module prev_d() {
    color("Crimson", 0.95)
    translate([0, drop_r_offset, base_outer_h + base_plate_h + 0.6 + ez * 1.3])
        cube([gate_w, drop_d + 4, gate_thickness], center = true);
}

// E — Lid
module prev_e() {
    z = base_outer_h + base_plate_h + car_h + ez * 3;
    color("LightSeaGreen", 0.85)
    translate([0, 0, z]) {
        difference() {
            cylinder(h = lid_h, d = lid_dia);
            translate([0, 0, -0.1]) cylinder(h = lid_h + 0.2, d = 12);
        }
        translate([0, 0, lid_h])
            difference() {
                cylinder(h = 4, d = lid_dia);
                translate([0, 0, -0.1]) cylinder(h = 4.2, d = car_dia + 1);
            }
    }
}

// F — Catch tray (in front of housing)
module prev_f() {
    color("Gold", 0.9)
    translate([0, base_outer_xy / 2 + tray_w / 2 + 8 + ez * 0.3, 0])
    difference() {
        translate([0, 0, tray_h / 2]) rounded_rect(tray_l, tray_w, tray_h, 6);
        translate([0, 0, tray_h / 2 + tray_floor])
            rounded_rect(tray_l - 12, tray_w - 12, tray_h, 4);
    }
}

// G — Spout
module prev_g() {
    color("SandyBrown", 0.92)
    translate([0, base_outer_xy / 2 - 2, 8 + ez * 0.2])
        rotate([-20, 0, 0])
            cube([chute_w + 4, spout_len, 8], center = false);
}

// H — Latch bracket + servo hint
module prev_h() {
    color("IndianRed", 0.9)
    translate([-40, drop_r_offset, base_outer_h - 12 + ez])
        cube([servo_w + 6, servo_l + 8, 12], center = true);
}

// I — Clips (shown inside housing corners)
module prev_i() {
    color("SlateGray", 0.9)
    for (p = [[-40, -40], [40, -40], [-40, 20]])
        translate([p[0], p[1], wall + 2 + ez * 0.1])
            cube([10, 8, 6], center = true);
}

// J — Feet
module prev_j() {
    color("DimGray", 0.95)
    for (ix = [-1, 1], iy = [-1, 1])
        translate([ix * (base_outer_xy / 2 - 10), iy * (base_outer_xy / 2 - 10), -foot_h - ez * 0.15])
            cylinder(h = foot_h, d = foot_od);
}

// K — One insert shown beside assembly
module prev_k() {
    color("MediumPurple", 0.9)
    translate([base_outer_xy / 2 + 35, 40, ez * 2])
        rotate([0, 0, 20])
            intersection() {
                difference() {
                    cylinder(h = insert_h, r = 28);
                    translate([0, 0, -0.1]) cylinder(h = insert_h + 0.2, r = 12);
                }
                translate([0, 0, -0.05])
                    linear_extrude(height = insert_h + 0.1)
                        polygon([[0, 0], [60, 0], [60 * cos(40), 60 * sin(40)]]);
            }
}

prev_j();
prev_a();
prev_b();
prev_c();
prev_d();
prev_e();
prev_f();
prev_g();
prev_h();
prev_i();
prev_k();

echo("============================================================");
echo("FINAL ASSEMBLY PREVIEW — full printable prototype set");
echo(EXPLODED ? "Mode: EXPLODED" : "Mode: SEATED");
echo("A Housing | B Plate | C Carousel | D Gate | E Lid");
echo("F Catch tray | G Spout | H Latch bracket | I Clips | J Feet | K Insert");
echo("Export STLs from part_a..part_k individually (F6 → Export STL)");
echo("============================================================");
