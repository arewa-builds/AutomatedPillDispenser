// ============================================================================
// v2 ASSEMBLY PREVIEW — do not print this file
//
//   CUTAWAY = true   removes a wedge of drum wall above the plate
//   EXPLODED = true  lifts the stack apart
//   SHOW_PILLS       decorative tablets, for communication only
//
// openscad -o v2.png --imgsize=1800,1500 --camera=0,0,0,62,0,205,430 \
//          --autocenter --viewall assembly_preview_v2.scad
// ============================================================================

include <parameters_v2.scad>;
include <lib_v2.scad>;

use <part_a2_housing.scad>;
use <part_b2_fixed_plate.scad>;
use <part_c2_carousel.scad>;
use <part_d2_drop_chute.scad>;
use <part_e2_servo_bridge.scad>;
use <part_f2_catch_tray.scad>;
use <part_g2_base_cover.scad>;

CUTAWAY     = true;
EXPLODED    = false;
SHOW_PILLS  = true;
SHOW_BRIDGE = true;   // false = hide the spider so the bore is fully visible
SECTION     = false;  // true = slice the whole machine in half at x = 0

CUT_CTR   = 40;     // azimuth of the removed wedge
CUT_SPAN  = 150;

ez = EXPLODED ? 30 : 0;

$fn = 96;

// ---------------------------------------------------------------- drum
module v2_housing() {
    color("DarkSeaGreen")
    difference() {
        housing_v2();
        if (CUTAWAY)
            rotate([0, 0, CUT_CTR])
                translate([0, 0, plate_z - 2])
                    sector_prism(90, CUT_SPAN, h_top_z + 20 - plate_z);
    }
}

// ---------------------------------------------------------------- servo mock
module v2_servo() {
    // Flange plane sits on the bridge top face.
    fz = bridge_z + bridge_t;
    translate([0, 0, fz]) {
        color("Gainsboro")
            translate([servo_l / 2 - servo_shaft_in - servo_tab_span / 2, -servo_w / 2, -servo_tab_t])
                cube([servo_tab_span, servo_w, servo_tab_t]);
        color("#1f5fbf")
            translate([-servo_shaft_in, -servo_w / 2, -servo_tab_t])
                cube([servo_l, servo_w, servo_tab_t + servo_case_h - servo_nose_h]);
        color("#141414")
            translate([-servo_shaft_in, -servo_w / 2, -servo_nose_h])
                cube([servo_l, servo_w, servo_nose_h]);
        color("#141414") cylinder(h = 5.0, d = 5.8, center = false);
        // Output shaft, pointing down into the carousel hub.
        color("Silver") translate([0, 0, -servo_nose_h - servo_shaft_h])
            cylinder(h = servo_shaft_h + 0.5, d = 4.8);
    }
}

module v2_horn() {
    color("White")
        translate([0, 0, car_top - horn_disc_h])
            cylinder(h = horn_disc_h, d = horn_disc_d);
}

// ---------------------------------------------------------------- pills
module tablet(d = 7.0) { scale([1, 1, 0.45]) sphere(d = d); }
module capsule(l = 9.0, d = 4.6) {
    rotate([0, 90, 0]) hull() {
        translate([0, 0, -l / 2 + d / 2]) sphere(d = d);
        translate([0, 0,  l / 2 - d / 2]) sphere(d = d);
    }
}

pill_colors = ["White", "#ff9d2e", "#e8536b", "#f2f2f2", "#7d4fd1", "#f5d33c"];

module v2_pills() {
    zf = car_z + car_floor_t;
    for (i = [0 : car_n - 1]) {
        ctr = i * 60 + 30;
        if (ctr != open_deg_ctr) {
            n = 11;
            rr = rands(car_hole_r_in + 3, car_r - 6, n, 11 + i);
            aa = rands(-12, 12, n, 71 + i);   // pills sit in the drop hole
            hh = rands(0, 3.0, n, 131 + i);
            for (k = [0 : n - 1])
                color(pill_colors[(i + k) % len(pill_colors)])
                    rotate([0, 0, ctr + aa[k]])
                        translate([rr[k], 0, zf + 1.8 + hh[k]])
                            if ((i + k) % 3 == 0) capsule(); else tablet();
        }
    }
    // Dose in flight: through the plate opening and down the chute.
    for (k = [0 : 5])
        color("#f5d33c")
            translate([0, 34 + k * 7.5, plate_z - 2 - k * 6.0]) tablet(6.5);
    // Landed dose in the tray.
    tn = 9;
    tx = rands(-16, 16, tn, 5);
    ty = rands(tray_y0 + 14, tray_y0 + 40, tn, 9);
    for (k = [0 : tn - 1])
        color("#f5d33c") translate([tx[k], ty[k], base_z + tray_floor + 1.6]) tablet(6.5);
}

// ---------------------------------------------------------------- stack
module v2_machine() {
    v2_housing();
    color("Silver")         translate([0, 0, -ez * 0.4]) base_cover_v2();
    color("WhiteSmoke")     translate([0, 0,  ez * 0.6]) fixed_plate_v2();
    color("CornflowerBlue") translate([0, 0,  ez * 1.3]) carousel_v2();
    color("#7fa8dd")        translate([0, 0,  ez * 0.2]) drop_chute_v2();
    color("#7fa8dd")        catch_tray_v2();
    if (SHOW_BRIDGE) {
        color("Gainsboro") translate([0, 0, ez * 2.0]) servo_bridge_v2();
    }
    translate([0, 0, ez * 2.0]) v2_servo();
    translate([0, 0, ez * 1.3]) v2_horn();
    if (SHOW_PILLS && !EXPLODED) v2_pills();
}

if (SECTION) {
    difference() {
        v2_machine();
        translate([0, -120, -40]) cube([130, 260, 200]);
    }
} else {
    v2_machine();
}

echo("=============================================================");
echo("v2 PREVIEW — carousel-only rotation, fixed plate, direct drive");
echo(str("Drum ", h_od, " x ", h_top_z, " mm | ", car_n,
         " compartments | one plate opening ", open_deg, " deg"));
echo("=============================================================");
