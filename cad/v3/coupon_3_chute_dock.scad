// ============================================================================
// v3 COUPON C3 — chute lip to tray mouth
//
// Print this before B3 and F3. About 20 minutes to prove the dock, which is the
// last place a dose can be lost and the one place two separately printed parts
// have to line up without a step.
//
// Two pieces, cut from the real parts:
//   1. Chute exit — the last stretch of ramp, its side walls, the lip, and the
//      housing wall around the notch.
//   2. Tray mouth — the cut-down mouth wall and the strip of tray floor behind
//      it.
//
// What to look for:
//   1. Butt the tray piece up to the chute piece as they sit in the assembly.
//      The lip must overhang *into* the tray, past the mouth wall.
//   2. There must be clearance between the lip's underside and the top of the
//      mouth wall — 1.5 mm by design. It must not be so tight that the tray
//      cannot be lifted straight up, and not so open that a tablet on edge could
//      stand in the gap.
//   3. Roll a tablet and then a capsule down the ramp. Each must clear the lip
//      and land on the tray floor. Nothing should stop on the lip, catch on the
//      mouth wall, or bridge the two.
//   4. Look along the ramp against the light: the floor must be unbroken all the
//      way through the wall. This is the same thing check_drop_path.scad proves
//      in CAD; here you prove it in plastic.
//
// Print as laid out, no supports. The chute piece keeps its as-modelled
// orientation, so its ramp underside prints as the same 40-42 deg overhang it
// will have on the real part — which is also worth a look.
// ============================================================================

include <parameters_v3.scad>;
include <lib_v3.scad>;
use <part_b3_base_body.scad>;
use <part_f3_catch_tray.scad>;

$fn = 96;

exit_y0   = 44.0;                    // back far enough to include real ramp
exit_z1   = 36.0;                    // above this it is just drum band, which
                                     // proves nothing and costs 18 mm of wall
exit_x    = 46.0;                    // chute plus the wall either side
mouth_len = 22.0;                    // strip of tray kept behind the mouth wall
gap       = 16.0;

module c3_chute_piece() {
    intersection() {
        base_body_v3();
        translate([-exit_x / 2, exit_y0, -1])
            cube([exit_x, (h_od / 2 + 12) - exit_y0, exit_z1 + 1]);
    }
}

module c3_tray_piece() {
    intersection() {
        catch_tray_v3();
        translate([-exit_x / 2, tray_y0 - 2, base_z - 1])
            cube([exit_x, mouth_len, tray_h + 2]);
    }
}

// Both as modelled, dropped to the bed, and pulled apart in Y so they print
// clear of each other.
translate([0, -gap, 0]) c3_chute_piece();
translate([0, gap, -base_z]) c3_tray_piece();

echo(str("C3 dock: lip floor top z ",
         chute_stations[len(chute_stations) - 1][1],
         ", lip underside z ",
         chute_stations[len(chute_stations) - 1][1]
             - chute_stations[len(chute_stations) - 1][4],
         ", mouth wall top z ", base_z + tray_mouth_h));
