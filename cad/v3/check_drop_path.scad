// ============================================================================
// v3 CHECK — is the ramp continuous under the discharge wedge?
//
// Not a printable part. This intersects the base body with the exact volume a
// pill can fall through (the deck's wedge, extruded from the deck's underside
// down to the bay floor) and shows what material is inside it.
//
// How to read it: open in OpenSCAD, F5, then look straight down (Ctrl+4 / top
// view). The wedge footprint must be filled edge to edge. Any daylight through
// it is a hole a tablet will drop through, because the wall notch removes
// everything else under the wedge — whatever you see there is ramp.
//
// Run this after retuning chute_stations, open_deg, open_r_in or chute_win_w.
//
//   MODE = 0   ramp material inside the drop volume  (the check)
//   MODE = 1   the drop volume alone, for orientation
//   MODE = 2   the base body with the drop volume ghosted over it
// ============================================================================

include <parameters_v3.scad>;
include <lib_v3.scad>;
use <part_b3_base_body.scad>;

MODE = 0;

$fn = 128;

module drop_volume() {
    rotate([0, 0, open_ctr])
        ring_sector(open_r_in, open_r_out, open_deg, deck_z);
}

if (MODE == 0) {
    intersection() { base_body_v3(); drop_volume(); }
} else if (MODE == 1) {
    color("#c0392b") drop_volume();
} else {
    base_body_v3();
    color("#c0392b", 0.35) drop_volume();
}

echo(str("Drop volume: ", open_deg, " deg wedge, r ", open_r_in, "-", open_r_out,
         ", from the deck underside at z ", deck_z, " down to the bay floor"));
echo(str("Ramp reaches inward to y = ", chute_stations[0][0],
         " (must be less than open_r_in = ", open_r_in, ")"));
