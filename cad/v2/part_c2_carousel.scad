// ============================================================================
// v2 PART C — carousel: hub + 6 radial dividers, no outer drum
//
// The drum wall closes the compartments on the outside (0.7 mm sweep gap), so
// this part is just a floor, six fins and a hub — the shape in the sketch.
//
// The floor carries one drop hole per compartment. That hole is what makes a
// single fixed-plate opening leak-proof: with open-bottomed compartments there
// is no park angle where a 46 deg opening is fully covered, so two neighbours
// would always be dribbling pills into the chute.
//
// Prints floor-down, fins up: no supports, and every fin is welded to the
// floor along its whole length.
// ============================================================================

include <parameters_v2.scad>;
include <lib_v2.scad>;

$fn = 96;

div_r_in  = car_hub_od / 2 - 0.5;
div_pitch = 360 / car_n;
flange_span = (div_pitch - car_hole_deg) / 2;

// Ramped floor flange: a plane hinged on the radial line at the hole edge and
// tilted up toward the divider, so no tablet can sit on a flat ledge and miss
// its dose. dir = +1 ramps counter-clockwise from the edge, -1 clockwise.
module c2_floor_ramp(a_edge, dir) {
    // render() collapses the ramp to one solid; without it the nested
    // intersections blow the CSG normalizer up in preview mode.
    render(convexity = 4)
    intersection() {
        rotate([0, 0, a_edge + dir * flange_span / 2])
            translate([0, 0, car_floor_t])
                ring_sector(div_r_in - 1, car_r, flange_span, ramp_max_h);
        translate([0, 0, car_floor_t])
            rotate([0, 0, a_edge])
                rotate([dir * ramp_phi, 0, 0])
                    translate([-200, -200, 0]) cube([400, 400, 80]);
    }
}

module carousel_v2() {
    translate([0, 0, car_z])
    difference() {
        union() {
            cylinder(h = car_floor_t, d = car_od);          // floor
            cylinder(h = car_floor_t + car_div_h, d = car_hub_od);  // hub

            for (i = [0 : car_n - 1])
                rotate([0, 0, i * div_pitch])
                    translate([div_r_in, -car_div_t / 2, 0])
                        cube([car_r - div_r_in, car_div_t, car_floor_t + car_div_h]);

            for (i = [0 : car_n - 1]) {
                ctr = i * div_pitch + div_pitch / 2;
                c2_floor_ramp(ctr + car_hole_deg / 2,  1);
                c2_floor_ramp(ctr - car_hole_deg / 2, -1);
            }
        }

        // One drop hole per compartment, centred between its two dividers.
        for (i = [0 : car_n - 1])
            rotate([0, 0, i * div_pitch + div_pitch / 2])
                translate([0, 0, -0.1])
                    ring_sector(car_hole_r_in, car_hole_r_out,
                                car_hole_deg, car_floor_t + 0.2);

        // Journal that drops onto the plate's pilot post.
        translate([0, 0, -0.1])
            cylinder(h = pilot_engage + 0.1, d = pilot_bore_d);

        // Round servo horn, splines up, screwed down into the hub.
        translate([0, 0, car_floor_t + car_div_h - horn_disc_h])
            cylinder(h = horn_disc_h + 0.1, d = horn_disc_d + fit_slip);
        translate([0, 0, car_floor_t + car_div_h - horn_boss_depth])
            cylinder(h = horn_boss_depth + 0.1, d = horn_boss_d);
        for (i = [0 : horn_screw_n - 1])
            rotate([0, 0, i * 360 / horn_screw_n])
                translate([horn_hole_r, 0, car_floor_t + car_div_h - horn_disc_h - 6])
                    cylinder(h = 6.2, d = m2_pilot_d);
    }
}

// Print orientation: as modelled, floor on the bed.
translate([0, 0, -car_z]) carousel_v2();

echo(str("C2 carousel: OD ", car_od, " mm, ", car_n, " compartments, fin height ",
         car_div_h, " mm"));
echo(str("C2 sweep gap to drum wall: ", (h_id - car_od) / 2, " mm per side"));
