// ============================================================================
// Automated Pill Dispenser — v3 "integral deck + open carousel"
// Shared parametric dimensions.   include <parameters_v3.scad>;
//
// z = 0 is the underside of the base body; the base cover hangs below it, so
// the table plane is z = base_z. +Y is the front (chute, tray, camera).
//
// Mechanism: the deck holds the pills in. It has ONE wedge opening. The unit
// parks with the JUST-EMPTIED compartment sitting over that opening, so
// nothing can leak; a 45 deg step sweeps the next compartment across the
// opening and gravity empties it. One servo, no gate, no carousel floor.
//
// Sizing rule that makes the park state leak-proof: the opening's angular
// width must fit inside one compartment's interior with margin to spare, at
// the opening's INNER radius (where a divider subtends the most angle):
//
//     open_deg  <=  360/car_n - 2*asin(div_t / (2*open_r_in)) - 2*park_margin
//     24        <=  45        - 8.6                           - 2*6.2
//
// Widening the opening or moving it inward eats the parking margin.
// ============================================================================

// ---------------------------------------------------------------- print / fit
layer_h        = 0.2;
nozzle_d       = 0.4;
wall           = 3.0;
fit_slip       = 0.35;
fit_press      = 0.10;
m3_pilot_d     = 2.55;
m3_free_d      = 3.35;
m2_pilot_d     = 1.65;
m2_free_d      = 2.30;

// ---------------------------------------------------------------- drum
h_od           = 120.0;
h_id           = h_od - 2 * wall;          // 114
h_ri           = h_id / 2;                 // 57
rim_z          = 94.0;                     // top of the deck body wall

// ---------------------------------------------------------------- deck (A3)
deck_z         = 52.0;                     // deck underside / body split plane
deck_t         = 5.0;                      // structural: the deck IS the drum
deck_top       = deck_z + deck_t;          // 57
deck_fillet    = 1.2;                      // fillet where the wall meets the deck

// The one opening.
open_deg       = 24.0;
open_r_in      = 16.0;
open_r_out     = h_ri;                     // breaches the bore: nothing rides past
open_ctr       = 90.0;                     // front (+Y)
open_relief    = 1.2;                      // lead-in relief on the deck top face

// Centre pilot: the carousel's only bearing. Post on the deck, journal in the
// hub, so the drive shaft never carries weight.
pilot_d        = 10.0;
pilot_engage   = 2.75;

// Body joint: three ears outside the drum. Concentricity between bodies is not
// critical — the running surface and the bore are both on the deck body.
ear_angles     = [30, 150, 270];
ear_w          = 18.0;
ear_out        = 7.0;
ear_t          = 8.0;

// ---------------------------------------------------------------- carousel (C3)
car_n          = 8;
car_pitch      = 360 / car_n;              // 45
car_od         = h_id - 1.4;               // 112.6 -> 0.7 mm sweep gap per side
car_r          = car_od / 2;
div_t          = 2.4;
div_h          = 26.0;
div_chamfer    = 1.6;                      // clears the deck/wall fillet
hub_od         = 28.0;
car_gap        = 0.35;                     // divider to deck running gap
car_z          = deck_top + car_gap;       // 57.35
car_top        = car_z + div_h;            // 83.35
pilot_post_h   = car_gap + pilot_engage;   // 3.1
pilot_bore_d   = pilot_d + fit_slip;       // 10.35

// Derived parking margin, echoed by the parts so a bad edit is loud.
park_margin    = (car_pitch - 2 * asin(div_t / (2 * open_r_in)) - open_deg) / 2;

// ---------------------------------------------------------------- drive train
// Hex socket, deliberately loose: it passes torque but cannot side-load the
// carousel, so the pilot post alone defines the axis.
hex_af         = 7.0;
hex_slip       = 0.40;
hex_depth      = 8.0;

shaft_body_d   = 10.0;
shaft_head_d   = 26.0;
shaft_head_t   = 6.0;

// MG90S
servo_l        = 22.8;
servo_w        = 12.2;
servo_case_h   = 22.5;
servo_tab_span = 32.2;
servo_tab_t    = 2.5;
servo_shaft_in = 5.9;
servo_nose_h   = 6.0;
servo_shaft_h  = 4.7;

horn_disc_d    = 20.4;
horn_disc_h    = 4.2;
horn_hole_r    = 7.5;
horn_screw_n   = 4;
horn_boss_d    = 8.5;

// ---------------------------------------------------------------- bracket (E3)
brk_ctr        = 270.0;                    // rear wall, opposite the chute
brk_pad_w      = 26.0;
brk_pad_h      = 40.0;
brk_pad_t      = 6.0;
brk_pad_z0     = 72.0;
brk_screw_z    = [78.0, 90.0];             // through the wall, from outside
brk_arm_w      = 22.0;
brk_arm_t      = 8.0;
brk_arm_top    = 112.0;                    // = the servo flange plane
// The servo plate has to be thinner than the servo's nose (6 mm from flange to
// case top) or the drive shaft's head fouls it. The beam keeps its full depth.
brk_head_t     = 4.5;
brk_rib_h      = 12.0;
brk_web_h      = 26.0;                     // gusset depth at the wall

// ---------------------------------------------------------------- chute (B3)
chute_wall     = 2.4;
// The notch is only as wide as the pill passage, so the chute's own side walls
// overlap the remaining drum wall and fuse into it. Cut it any wider and the
// chute floats free of the housing.
// 0.4 mm wider than the chute's inside width so the notch's cut faces are not
// coplanar with the chute's wall faces. The walls still overlap the drum wall by
// 2.0 mm, which is what fuses the chute into the housing.
chute_win_w    = 32.8;
chute_win_z0   = 8.0;                            // below the ramp's underside
chute_win_z1   = deck_z;                         // open right up to the deck

// [ y, floor top z, inside width, side-wall top z, floor thickness ]
// The floor thickens toward the exit so its UNDERSIDE runs at 40-42 deg rather
// than following the 38-40 deg top surface: it keeps the overhang printable and
// puts the material where the chute cantilevers out of the wall.
chute_stations = [
    [17.0, 52.0, 18.0, 51.9, 2.4],
    [45.0, 30.0, 32.0, 51.8, 6.0],
    [57.0, 19.0, 32.0, 36.0, 6.0],
    [70.0,  8.0, 32.0, 24.0, 6.5],
];

// ---------------------------------------------------------------- tray (F3)
tray_y0        = 68.0;
tray_l         = 62.0;
tray_w         = 78.0;
tray_floor     = 2.0;
tray_h         = 14.0;
tray_mouth_h   = 4.0;                      // cut-down wall; the chute lip overhangs it

// ---------------------------------------------------------------- base (G3)
base_t         = 3.0;
base_z         = -base_t;                  // table plane
post_d         = 9.0;
post_r         = h_ri - post_d / 2 + 0.8;
post_angles    = [70, 190, 310];
cable_w        = 12.0;
cable_h        = 6.0;
