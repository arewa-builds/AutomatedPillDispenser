// ============================================================================
// v3 COUPON C1 — deck sector + carousel sector
//
// Print this before A3 and C3. About 25 minutes of printing to prove the two
// gaps the machine turns on, either of which would otherwise be found 10 hours
// into a print pair:
//
//   * running gap   0.35 mm, divider bottom to deck top
//   * sweep gap     0.7 mm per side, divider tip to bore
//
// Two pieces, both cut from the real parts so they carry the real dimensions.
// Each keeps its full centre — the deck slice keeps the pilot post, the carousel
// slice keeps the whole hub and its journal — so the pieces still centre on each
// other and can be spun by hand.
//
// What to look for, in order:
//   1. The journal drops onto the post with a little slop, no force.
//   2. Spin the carousel slice. No rub on the deck, no rub on the bore, no
//      rocking. If it rubs on the deck, raise car_gap; if it rubs on the bore,
//      raise the 1.4 mm in car_od. Nothing else changes.
//   3. Stand a tablet on the deck against a divider and push. It must sweep, not
//      slip underneath. If it slips under, car_gap is too big for that tablet.
//   4. Push a tablet over the wedge cut. It must fall cleanly through.
//
// Print as laid out, no supports.
// ============================================================================

include <parameters_v3.scad>;
include <lib_v3.scad>;
use <part_a3_deck_body.scad>;
use <part_c3_carousel.scad>;

$fn = 128;

deck_slice_deg = 74;                    // spans the 24 deg wedge with room either side
car_slice_deg  = 104;                   // two whole dividers plus one whole bin
hub_keep_d     = hub_od;                // keep the hub and journal whole, and cut
                                        // the other dividers off flush with it
post_keep_d    = pilot_d + 14;          // keep the pilot post whole
deck_keep_h    = 16.0;                  // enough wall to guide a divider
car_keep_h     = 14.0;                  // dividers cut down; full height proves nothing

// A wedge to intersect with, plus a full disc at the centre so whatever sits on
// the axis survives the cut.
module keep(deg, ctr, keep_d, z0, h) {
    translate([0, 0, z0]) union() {
        rotate([0, 0, ctr]) sector_prism(h_od, deg, h);
        cylinder(h = h, d = keep_d);
    }
}

module c1_deck_piece() {
    intersection() {
        deck_body_v3();
        keep(deck_slice_deg, open_ctr, post_keep_d, deck_z, deck_keep_h);
    }
}

module c1_carousel_piece() {
    intersection() {
        carousel_v3();
        // Offset half a pitch so the slice lands on two whole dividers with a
        // whole compartment between them, rather than splitting a divider.
        keep(car_slice_deg, open_ctr + car_pitch / 2, hub_keep_d, car_z, car_keep_h);
    }
}

// Both pieces flat on the bed, nested: the wedges point in opposite directions
// and their apexes are offset in Y, so the two fan out into each other's empty
// space. That packs them into roughly 120 x 105 mm instead of the 76 x 185 mm
// they take side by side.
spread = 22.0;

translate([0, -spread, -deck_z]) rotate([0, 0, -open_ctr])
    c1_deck_piece();

translate([0, spread, -car_z]) rotate([0, 0, 180 - open_ctr])
    c1_carousel_piece();

echo(str("C1: running gap ", car_gap, " mm, sweep gap ", (h_id - car_od) / 2,
         " mm per side, journal slip ", fit_slip, " mm"));
echo(str("C1: deck slice ", deck_slice_deg, " deg over the ", open_deg,
         " deg wedge; carousel slice ", car_slice_deg, " deg"));
