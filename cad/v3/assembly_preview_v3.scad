// ============================================================================
// v3 ASSEMBLY PREVIEW — do not print this file
//
//   CUTAWAY     remove a wedge of drum wall above the deck
//   SECTION     slice the whole machine in half at x = 0
//   DOSE_ANGLE  22.5 = at rest: the just-emptied compartment is centred on the
//               opening and covers it. Step by 45 deg to dump the next one.
// ============================================================================

include <parameters_v3.scad>;
include <lib_v3.scad>;

use <part_a3_deck_body.scad>;
use <part_b3_base_body.scad>;
use <part_c3_carousel.scad>;
use <part_d3_drive_shaft.scad>;
use <part_e3_servo_bracket.scad>;
use <part_f3_catch_tray.scad>;
use <part_g3_base_cover.scad>;

CUTAWAY    = true;
SECTION    = false;
EXPLODED   = false;
SHOW_PILLS = true;
SHOW_BRACKET = true;
DOSE_ANGLE = 22.5;   // carousel rotation, deg

CUT_CTR    = 55;
CUT_SPAN   = 110;

ez = EXPLODED ? 32 : 0;
$fn = 96;

GREY  = "#b9bdc2";
DGREY = "#9aa0a6";
CAR   = "#a7acb2";   // carousel, a shade darker so it reads in flat renders

module v3_bodies() {
    color(GREY) difference() {
        union() {
            translate([0, 0, ez]) deck_body_v3();
            base_body_v3();
        }
        if (CUTAWAY)
            rotate([0, 0, CUT_CTR])
                translate([0, 0, deck_top - 0.5])
                    sector_prism(CUT_SPAN, 150, rim_z + 20 - deck_top);
    }
}

module v3_servo() {
    fz = brk_arm_top;
    translate([0, 0, fz]) {
        color("Gainsboro")
            translate([servo_l / 2 - servo_shaft_in - servo_tab_span / 2,
                       -servo_w / 2, -servo_tab_t])
                cube([servo_tab_span, servo_w, servo_tab_t]);
        color("#2b2b2b")
            translate([-servo_shaft_in, -servo_w / 2, -servo_tab_t])
                cube([servo_l, servo_w, servo_tab_t + servo_case_h - servo_nose_h]);
        color("#151515")
            translate([-servo_shaft_in, -servo_w / 2, -servo_nose_h])
                cube([servo_l, servo_w, servo_nose_h]);
        color("#151515") cylinder(h = 5.5, d = 6.0);
    }
}

// ---------------------------------------------------------------- pills
// Height of the ramp's top surface at a given y, interpolated from the station
// table so the in-flight pills sit on the ramp whatever the chute is retuned to.
function ramp_seg(y, i) =
    chute_stations[i][1] + (y - chute_stations[i][0])
    * (chute_stations[i + 1][1] - chute_stations[i][1])
    / (chute_stations[i + 1][0] - chute_stations[i][0]);

function ramp_top(y) =
    y <= chute_stations[1][0] ? ramp_seg(y, 0)
  : y <= chute_stations[2][0] ? ramp_seg(y, 1)
  :                             ramp_seg(y, 2);

module tablet(d = 7.5) { scale([1, 1, 0.42]) sphere(d = d); }
module capsule(l = 10.0, d = 5.0) {
    rotate([0, 90, 0]) hull() {
        translate([0, 0, -l / 2 + d / 2]) sphere(d = d);
        translate([0, 0,  l / 2 - d / 2]) sphere(d = d);
    }
}

pill_sets = [
    ["White",   0], ["#e34b4b", 1], ["#e85fa8", 0], ["#c3d96b", 0],
    ["#f0b429", 0], ["#3a6fd8", 1], ["#f08a24", 0], ["WhiteSmoke", 0],
];

module v3_pills() {
    for (i = [0 : car_n - 1]) {
        ctr = i * car_pitch + car_pitch / 2 + DOSE_ANGLE;
        // The compartment sitting over the opening has already been emptied.
        if (abs(((ctr - open_ctr + 540) % 360) - 180) > car_pitch * 0.5) {
            n = 12;
            rr = rands(open_r_in + 6, car_r - 8, n, 17 + i);
            aa = rands(-15, 15, n, 53 + i);
            hh = rands(0, 3.5, n, 91 + i);
            for (k = [0 : n - 1])
                color(pill_sets[i][0])
                    rotate([0, 0, ctr + aa[k]])
                        translate([rr[k], 0, deck_top + 2.0 + hh[k]])
                            if (pill_sets[i][1] == 1) capsule(); else tablet();
        }
    }
    // Dose in flight down the chute, and landed in the tray. Follows the ramp's
    // top surface, so it moves with chute_stations rather than hard-coded slopes.
    for (k = [0 : 5]) {
        y = 24 + k * 8.0;
        z = ramp_top(y);
        color("#f0b429")
            translate([(k % 2 - 0.5) * 9, y, z + 1.7])
                rotate([-38, 0, 0]) tablet(7.0);
    }
    tn = 8;
    tx = rands(-18, 18, tn, 3);
    ty = rands(tray_y0 + 16, tray_y0 + 44, tn, 7);
    for (k = [0 : tn - 1])
        color("#f0b429")
            translate([tx[k], ty[k], base_z + tray_floor + 1.5]) tablet(7.0);
}

module v3_machine() {
    v3_bodies();
    color(DGREY)  base_cover_v3();
    color(CAR)    translate([0, 0, ez * 1.6]) rotate([0, 0, DOSE_ANGLE]) carousel_v3();
    color(DGREY)  translate([0, 0, ez * 2.4]) drive_shaft_v3();
    color("White") translate([0, 0, ez * 2.4 + brk_arm_top - servo_nose_h - servo_shaft_h])
        cylinder(h = horn_disc_h, d = horn_disc_d);
    if (SHOW_BRACKET) {
        color(DGREY) translate([0, 0, ez * 2.4]) servo_bracket_v3();
        translate([0, 0, ez * 2.4]) v3_servo();
    }
    color(GREY) catch_tray_v3();
    if (SHOW_PILLS && !EXPLODED) v3_pills();
}

if (SECTION) {
    difference() {
        v3_machine();
        translate([0, -140, -40]) cube([140, 280, 220]);
    }
} else {
    v3_machine();
}

echo("=============================================================");
echo("v3 PREVIEW — integral deck, 8 open compartments, one servo");
echo(str("Opening ", open_deg, " deg | parking margin +/- ", park_margin, " deg"));
echo(str("Overall ", h_od, " dia x ", rim_z, " tall, tray reaches y = ",
         tray_y0 + tray_l));
echo("=============================================================");
