// ============================================================================
// v2 PART B — fixed plate with exactly one opening
//
// This part never moves. Three keys drop into notches in the drum ledge, so
// carousel drag cannot spin it (the failure seen on the v1 build, where the
// plate turned instead of the carousel). The opening runs all the way out to
// the rim: a closed outer ledge would let pills hugging the drum wall ride
// past the drop point forever.
// ============================================================================

include <parameters_v2.scad>;
include <lib_v2.scad>;

$fn = 96;

module fixed_plate_v2() {
    translate([0, 0, plate_z])
    difference() {
        union() {
            cylinder(h = plate_t, d = plate_dia);

            // Anti-rotation keys, hanging below the rim into the ledge notches.
            for (a = key_angles)
                rotate([0, 0, a])
                    translate([plate_r - ledge_w, -key_arc_w / 2, -key_h])
                        cube([ledge_w, key_arc_w, key_h]);

            // Centre pilot post — the carousel's only bearing surface.
            translate([0, 0, plate_t - 0.01])
                cylinder(h = pilot_post_h + 0.01, d = pilot_d);
        }

        // The one opening.
        rotate([0, 0, open_deg_ctr])
            translate([0, 0, -0.1])
                ring_sector(open_r_in, plate_r + 2, open_deg, plate_t + 0.2);

        // Lead-in relief on the top face so a tablet cannot be pinched between
        // a carousel divider and the opening edge.
        rotate([0, 0, open_deg_ctr])
            translate([0, 0, plate_t - 1.0])
                ring_sector(open_r_in - 1.5, plate_r + 2, open_deg + 5, 1.2);

    }
}

// Print orientation: flat on the bed, pilot post and keys up. No supports.
translate([0, 0, -plate_z]) fixed_plate_v2();

echo(str("B2 plate: dia ", plate_dia, " x ", plate_t, " mm, opening ", open_deg, " deg"));
