// ============================================================================
// v3 PART A3 — deck body (upper): drum wall + integral deck + discharge wedge
//
// The deck is the surface the pills sit on and the dividers sweep. Making it
// integral to the drum means there is no separate plate that can rotate — the
// v1 failure is designed out rather than fastened out.
//
// Print as modelled: the deck's flat underside is the first layer, the wall
// rises from it, the wedge is just a hole, the pilot post grows upward. No
// supports. Iron the top face if your slicer can — it is the running surface.
// ============================================================================

include <parameters_v3.scad>;
include <lib_v3.scad>;

$fn = 128;

module a3_ear() {
    hull() {
        translate([h_od / 2 - 2, -ear_w / 2, deck_z]) cube([ear_out + 2, ear_w, ear_t]);
        translate([h_od / 2 - 2, -ear_w / 2, deck_z + ear_t]) cube([2, ear_w, 0.1]);
    }
}

module deck_body_v3() {
    difference() {
        union() {
            translate([0, 0, deck_z]) cylinder(h = deck_t, d = h_id);   // deck slab
            translate([0, 0, deck_z]) tube(h_od, h_id, rim_z - deck_z); // wall
            // Fillet at the wall root — the dividers are chamfered to clear it.
            translate([0, 0, deck_top])
                rotate_extrude(convexity = 4)
                    polygon([[h_ri - deck_fillet, 0], [h_ri, 0], [h_ri, deck_fillet]]);
            // Centre pilot post.
            translate([0, 0, deck_top - 0.01])
                cylinder(h = pilot_post_h + 0.01, d = pilot_d);
            for (a = ear_angles) rotate([0, 0, a]) a3_ear();
        }

        // The one opening, plus a lead-in relief so nothing pinches at its edge.
        rotate([0, 0, open_ctr]) {
            translate([0, 0, deck_z - 0.1])
                ring_sector(open_r_in, open_r_out + 2, open_deg, deck_t + 0.2);
            translate([0, 0, deck_top - open_relief])
                ring_sector(open_r_in - 1.2, open_r_out + 2,
                            open_deg + 4, open_relief + 0.1);
        }

        // Bracket screws: free holes through the wall, driven from outside.
        rotate([0, 0, brk_ctr])
            for (z = brk_screw_z) {
                translate([h_ri - 1, 0, z]) rotate([0, 90, 0])
                    cylinder(h = wall + 2, d = m3_free_d);
                // Shallow seat for the screw head on the outside.
                translate([h_od / 2 - 1.2, 0, z]) rotate([0, 90, 0])
                    cylinder(h = 1.4, d = m3_free_d + 3.2);
            }

        // Ear screw holes (free) — they thread into the base body's ears.
        for (a = ear_angles)
            rotate([0, 0, a])
                translate([h_od / 2 + ear_out / 2, 0, deck_z - 0.1])
                    cylinder(h = ear_t + 0.2, d = m3_free_d);
    }
}

// The module works in assembly coordinates so the preview can use it as-is; the
// top-level call is the print orientation. Deck underside on the bed, drum wall
// rising — the deck's top face and the wedge print with no supports.
translate([0, 0, -deck_z]) deck_body_v3();

echo(str("A3 deck body: OD ", h_od, ", deck top z ", deck_top, ", rim z ", rim_z));
echo(str("A3 opening: ", open_deg, " deg, r ", open_r_in, "-", open_r_out));
echo(str("A3 derived parking margin: +/- ", park_margin,
         " deg  (must stay positive and comfortably above servo repeatability)"));
