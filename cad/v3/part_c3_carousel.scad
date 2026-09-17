// ============================================================================
// v3 PART C3 — carousel: hub + 8 dividers, exactly as drawn
//
// No floor and no outer wall. The deck below holds the pills in, the drum bore
// closes the compartments on the outside. That is only safe because the deck
// opening is narrower than a compartment: see the sizing rule in
// parameters_v3.scad.
//
// Print as modelled — the divider ends and the hub sit flat on the bed, so the
// whole part is one continuous upward extrusion with no overhangs.
// ============================================================================

include <parameters_v3.scad>;
include <lib_v3.scad>;

$fn = 96;

div_r_in = hub_od / 2 - 0.5;

module c3_divider() {
    difference() {
        translate([div_r_in, -div_t / 2, 0]) cube([car_r - div_r_in, div_t, div_h]);
        // Chamfer the outer bottom corner to clear the deck/wall fillet.
        translate([car_r + 0.01, 0, 0])
            rotate([0, 45, 0])
                translate([-div_chamfer, -div_t, -div_chamfer])
                    cube([div_chamfer * 2, div_t * 2, div_chamfer * 2]);
    }
}

module carousel_v3() {
    translate([0, 0, car_z])
    difference() {
        union() {
            cylinder(h = div_h, d = hub_od);
            for (i = [0 : car_n - 1]) rotate([0, 0, i * car_pitch]) c3_divider();
        }

        // Journal onto the deck's pilot post.
        translate([0, 0, -0.1]) cylinder(h = pilot_engage + 0.1, d = pilot_bore_d);

        // Loose hex socket for the drive shaft.
        translate([0, 0, div_h - hex_depth])
            cylinder(h = hex_depth + 0.1, d = (hex_af + hex_slip) / cos(30), $fn = 6);

        // Lead-in chamfer at the socket mouth.
        translate([0, 0, div_h - 1.2])
            cylinder(h = 1.3, d1 = (hex_af + hex_slip) / cos(30),
                     d2 = (hex_af + hex_slip) / cos(30) + 2.4, $fn = 6);
    }
}

translate([0, 0, -car_z]) carousel_v3();

echo(str("C3 carousel: ", car_n, " compartments, OD ", car_od,
         ", divider ", div_t, " x ", div_h));
echo(str("C3 sweep gap ", (h_id - car_od) / 2, " per side, running gap ", car_gap));
