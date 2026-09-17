// ============================================================================
// Automated Pill Dispenser — v2 "carousel-only rotation" architecture
// Shared parametric dimensions.   include <parameters_v2.scad>;
//
// Coordinate convention: z = 0 is the table / underside of the drum.
// +Y is the FRONT of the unit (chute, catch tray, camera side).
// Every part module is authored in ASSEMBLY coordinates; each part file
// applies its own print-orientation transform for STL export.
// ============================================================================

// ---------------------------------------------------------------- print / fit
layer_h        = 0.2;
nozzle_d       = 0.4;
wall           = 3.0;   // drum wall thickness
fit_slip       = 0.35;  // sliding fit (rotating / removable parts)
fit_press      = 0.10;  // press fit
m3_pilot_d     = 2.55;  // self-tapping M3 into PLA
m3_free_d      = 3.35;
m2_pilot_d     = 1.65;  // servo tab screws
m2_free_d      = 2.30;

// ---------------------------------------------------------------- drum (A)
h_od           = 120.0;
h_id           = h_od - 2 * wall;          // 114.0
h_ri           = h_id / 2;                 // 57.0
h_top_z        = 86.0;                     // top rim height

// ---------------------------------------------------------------- fixed plate (B)
plate_t        = 4.0;
plate_z        = 52.0;                     // plate UNDERSIDE
plate_top      = plate_z + plate_t;        // 56.0
plate_dia      = h_id - 0.6;               // 113.4  (0.3 gap per side)
plate_r        = plate_dia / 2;

ledge_w        = 3.0;                      // inward width of the support ledge
key_n          = 3;                        // anti-rotation keys
key_arc_w      = 10.0;                     // key width (chord, mm)
key_h          = 3.0;                      // key depth below the plate
key_angles     = [30, 150, 270];

// The one and only opening in the fixed plate. Opens right out to the rim so
// no pill can ever ride around on a closed outer ledge.
// Width is set by the leak rule below, not by taste.
open_deg       = 18.0;
open_r_in      = 15.0;
open_deg_ctr   = 90.0;                     // centred on +Y (front)

// Centre pilot: a post stands up from the plate and the carousel hub drops
// onto it. The post carries the carousel's weight, so the servo shaft only
// ever sees torque, and both halves print with no overhangs.
pilot_d        = 10.0;
pilot_engage   = 2.4;

// ---------------------------------------------------------------- carousel (C)
car_n          = 6;                        // compartments
car_od         = h_id - 1.4;               // 112.6 -> 0.7 mm pill-proof wall gap
car_r          = car_od / 2;
car_floor_t    = 2.4;
car_div_t      = 2.4;
car_div_h      = 24.0;                     // divider height ABOVE the floor
car_hub_od     = 28.0;
car_gap        = 0.6;                      // running gap, carousel floor -> plate
car_z          = plate_top + car_gap;      // 56.6 floor underside
car_top        = car_z + car_floor_t + car_div_h;

// One drop hole per compartment. THE LEAK RULE: the solid floor band between
// two holes (pitch - car_hole_deg) must be WIDER than the plate opening, or the
// parked carousel leaves part of the opening uncovered and its neighbours
// dribble pills into the chute. 60 - 30 = 30 deg of band over an 18 deg
// opening leaves +/- 6 deg of servo parking error before anything leaks.
car_hole_deg   = 30.0;
car_hole_r_in  = 15.5;
car_hole_r_out = car_r + 1.0;              // breaches the rim: nothing rides past

// Because the hole is narrower than the compartment, each floor flange is
// ramped so tablets roll into the hole instead of parking on a flat ledge.
ramp_phi       = 22.0;
ramp_max_h     = 6.0;

pilot_post_h   = car_gap + pilot_engage;   // 3.0, stands on the plate
pilot_bore_d   = pilot_d + fit_slip;       // 10.35 journal in the hub underside

// Round MG90S horn, screwed splines-up into the hub top. The servo shaft just
// plugs down into it, so the carousel still lifts straight out for refilling.
horn_disc_d    = 20.4;
horn_disc_h    = 4.2;
horn_hole_r    = 7.5;
horn_screw_n   = 4;
horn_boss_d    = 8.5;                      // spline boss / screw-head relief
horn_boss_depth= 8.0;

// ---------------------------------------------------------------- servo (MG90S)
servo_l        = 22.8;
servo_w        = 12.2;
servo_case_h   = 22.5;
servo_tab_span = 32.2;
servo_tab_t    = 2.5;
servo_shaft_in = 5.9;   // shaft axis, measured in from the flange-side case end
servo_nose_h   = 6.0;   // flange plane -> top of case
servo_shaft_h  = 4.7;   // shaft protrusion above the case

// ---------------------------------------------------------------- servo bridge (E)
bridge_t       = 4.0;
bridge_z       = h_top_z;                  // sits on the rim
bridge_ear_n   = 4;
bridge_ear_w   = 16.0;
boss_out       = 5.0;                      // external screw boss, radial depth
boss_h         = 14.0;                     // boss height below the rim
boss_angles    = [45, 135, 225, 315];

// ---------------------------------------------------------------- drop chute (D)
chute_wall     = 2.4;
chute_win_w    = 40.0 + 2 * chute_wall + 0.8;   // 45.6 wall window width
chute_win_z0   = 16.0;                          // window bottom
chute_win_z1   = 38.0;                          // window top (45 deg gable above)

// Trough stations: [ y, floor z, inside width, side-wall top z ].
// Inside the drum the side walls run right up to the plate underside so a
// tablet cannot bounce sideways into the electronics bay. The internal floor
// falls at 38 deg; the external run is the 45 deg section from the sketch.
chute_stations = [
    [15.0, 52.0, 20.0, 52.2],
    [50.0, 24.7, 48.0, 52.0],
    [57.0, 19.2, 40.0, 34.0],
    [70.0,  6.2, 40.0, 26.2],
];

// ---------------------------------------------------------------- catch tray (F)
tray_y0        = 68.0;                     // rear wall, just under the chute lip
tray_l         = 60.0;                     // outward (Y) length
tray_w         = 74.0;
tray_floor     = 2.0;
tray_h         = 14.0;
tray_rear_h    = 8.0;                      // low rear wall, clears the chute lip

// ---------------------------------------------------------------- base cover (G)
base_t         = 3.0;
base_z         = -base_t;                  // cover bottom = the table plane
post_d         = 9.0;
post_h         = 16.0;
post_r         = h_ri - post_d / 2 + 0.8;  // overlaps the wall so it fuses
post_angles    = [70, 190, 310];
cable_w        = 12.0;
cable_h        = 6.0;
