// ============================================================================
// v2 PART A — cylindrical housing drum ("pill-proof green outer walls")
//
// The drum wall is the outer wall of every compartment, so the carousel needs
// no outer rim: a 0.7 mm sweep gap is narrower than any tablet.
// Prints as an open-ended tube — no supports anywhere. The chute window has a
// 45 deg gable roof and the plate ledge has a 45 deg underside so nothing
// bridges in mid-air.
// ============================================================================

include <parameters_v2.scad>;
include <lib_v2.scad>;

$fn = 96;

module a2_rim_boss() {
    hull() {
        translate([h_od / 2 - 1.5, -bridge_ear_w / 2, h_top_z - boss_h * 0.55])
            cube([boss_out + 1.5, bridge_ear_w, boss_h * 0.55]);
        translate([h_od / 2 - 1.5, -bridge_ear_w / 2, h_top_z - boss_h])
            cube([1.5, bridge_ear_w, 1.2]);
    }
}

// Gable-roofed window: the 45 deg roof means the top edge never bridges.
module a2_wall_window(w, z0, z1) {
    translate([0, h_od / 2 + 2, 0])
        rotate([90, 0, 0])
            linear_extrude(height = wall + 6)
                polygon([[-w / 2, z0],
                         [ w / 2, z0],
                         [ w / 2, z1],
                         [ 0,     z1 + w / 2],
                         [-w / 2, z1]]);
}

module housing_v2() {
    difference() {
        union() {
            tube(h_od, h_id, h_top_z);

            // Plate support ledge — top face is exactly the plate underside.
            chamfered_ledge(h_ri, ledge_w, plate_z);

            // Base-cover screw posts, grown from the build plate upward.
            for (a = post_angles)
                rotate([0, 0, a])
                    translate([post_r, 0, 0])
                        cylinder(h = post_h, d = post_d);

            // External bosses for the servo bridge — kept outside the wall so
            // the carousel can always be lifted straight out of the drum.
            for (a = boss_angles) rotate([0, 0, a]) a2_rim_boss();
        }

        // The single chute window, front (+Y).
        a2_wall_window(chute_win_w, chute_win_z0, chute_win_z1);

        // Anti-rotation notches through the ledge for the fixed plate keys.
        for (a = key_angles)
            rotate([0, 0, a])
                translate([h_ri - ledge_w - 1, -(key_arc_w + fit_slip) / 2, plate_z - key_h])
                    cube([ledge_w + 2, key_arc_w + fit_slip, key_h + 0.1]);

        // Bridge screw pilots.
        for (a = boss_angles)
            rotate([0, 0, a])
                translate([h_od / 2 + boss_out / 2, 0, h_top_z - 13])
                    cylinder(h = 14, d = m3_pilot_d);

        // Base-cover screw pilots, from the underside.
        for (a = post_angles)
            rotate([0, 0, a])
                translate([post_r, 0, -0.1])
                    cylinder(h = 13, d = m3_pilot_d);

        // Rear cable / USB port.
        rotate([0, 0, 180])
            translate([-cable_w / 2, -(h_od / 2 + 2), 4])
                cube([cable_w, wall + 4, cable_h]);
    }
}

// Print orientation: as modelled, open end down.
housing_v2();

echo(str("A2 housing: OD ", h_od, " x H ", h_top_z, " mm, wall ", wall));
echo(str("A2 chute window: ", chute_win_w, " wide, z ", chute_win_z0, "-", chute_win_z1));
