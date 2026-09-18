// ============================================================================
// v3 PART B3 — base body (lower): electronics bay + integral 45 deg chute
//
// Splitting the housing here is what makes both halves printable: this one goes
// open-end-down, so the chute floor and the wall notch are all self-supporting.
//
// The ramp is one continuous surface from under the deck's wedge to the lip over
// the tray: the stations are hulled in sequence, and the notch through the wall
// is cut with its sill on the ramp line so it never breaches the floor.
// ============================================================================

include <parameters_v3.scad>;
include <lib_v3.scad>;

$fn = 128;

n_st = len(chute_stations);

module b3_floor_station(st) {
    w = st[2] + 2 * chute_wall;
    translate([-w / 2, st[0] - 0.4, st[1] - st[4]])
        cube([w, 0.8, st[4]]);
}

module b3_wall_station(st, side) {
    h = max(0.8, st[3] - st[1]);
    mirror([side < 0 ? 1 : 0, 0, 0])
        translate([st[2] / 2, st[0] - 0.4, st[1]]) cube([chute_wall, 0.8, h]);
}

// The ramp, as one continuous surface from under the deck's wedge to the lip.
module b3_chute_floor() {
    for (i = [0 : n_st - 2]) hull() {
        b3_floor_station(chute_stations[i]);
        b3_floor_station(chute_stations[i + 1]);
    }
}

module b3_chute_walls() {
    for (i = [0 : n_st - 2], s = [-1, 1]) hull() {
        b3_wall_station(chute_stations[i], s);
        b3_wall_station(chute_stations[i + 1], s);
    }
}

// The notch is a box MINUS the chute itself, so it can only ever remove housing
// wall — the ramp and the chute's side walls survive whatever the box does.
// A plain box (the first attempt) sliced the ramp out exactly where it passes
// through the wall and left a hole a tablet dropped through. Putting the box's
// sill on the ramp line closed the hole but made the cut coplanar with the
// ramp's own top surface, which is fragile; subtracting the chute is exact.
module b3_wall_notch(w, z0, z_top) {
    difference() {
        translate([-w / 2, h_ri - 5, z0])
            cube([w, (h_od / 2 + 4) - (h_ri - 5), z_top - z0]);
        b3_chute_floor();
        b3_chute_walls();
    }
}

// Shoulder fins tying the chute back into the bore. They also stiffen the wall
// either side of the notch. Below the deck, so they cannot foul the carousel.
module b3_shoulder(side) {
    st = chute_stations[1];
    mirror([side < 0 ? 1 : 0, 0, 0])
        intersection() {
            translate([st[2] / 2, st[0] - 1.5, st[1] - st[4]])
                cube([30, 3.0, st[3] - st[1] + st[4]]);
            cylinder(h = deck_z, d = h_id + wall);   // buried in the wall, no coplanar faces
        }
}

module b3_ear() {
    hull() {
        translate([h_od / 2 - 2, -ear_w / 2, deck_z - ear_t]) cube([ear_out + 2, ear_w, ear_t]);
        translate([h_od / 2 - 2, -ear_w / 2, deck_z - ear_t - 2]) cube([2, ear_w, 2]);
    }
}

module base_body_v3() {
    difference() {
        union() {
            tube(h_od, h_id, deck_z);

            // Chute: continuous ramp plus side walls sealing up to the deck.
            b3_chute_floor();
            b3_chute_walls();

            for (s = [-1, 1]) b3_shoulder(s);

            // Base-cover posts, grown from the build plate.
            for (a = post_angles)
                rotate([0, 0, a]) translate([post_r, 0, 0])
                    cylinder(h = 16, d = post_d);

            for (a = ear_angles) rotate([0, 0, a]) b3_ear();
        }

        b3_wall_notch(chute_win_w, chute_win_z0, chute_win_z1);

        // Trim anything above the split plane.
        translate([0, 0, deck_z]) cylinder(h = 60, d = h_od + 20);

        for (a = post_angles)
            rotate([0, 0, a]) translate([post_r, 0, -0.1])
                cylinder(h = 13, d = m3_pilot_d);

        for (a = ear_angles)
            rotate([0, 0, a])
                translate([h_od / 2 + ear_out / 2, 0, deck_z - ear_t - 0.1])
                    cylinder(h = ear_t + 0.2, d = m3_pilot_d);

        rotate([0, 0, 180])
            translate([-cable_w / 2, -(h_od / 2 + 2), 5])
                cube([cable_w, wall + 4, cable_h]);
    }
}

base_body_v3();

echo(str("B3 base body: height ", deck_z, ", bay clear height ",
         chute_stations[n_st - 2][1] - chute_wall));
echo(str("B3 chute exit: ", chute_stations[n_st - 1][2], " mm wide at z ",
         chute_stations[n_st - 1][1]));
