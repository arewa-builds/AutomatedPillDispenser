// ============================================================================
// v2 PART D — drop chute (internal hopper + through-wall spout + 45 deg run)
//
// One piece: the sloped floor under the plate opening, the side walls that seal
// up to the plate underside, the spout that keys into the drum window, and the
// external 45 deg run that lands pills in the catch tray.
//
// This is the fix for the v1 "slit" — the exit is a 40 mm wide open trough,
// not a slot, so nothing can jam in it.
// ============================================================================

include <parameters_v2.scad>;
include <lib_v2.scad>;

$fn = 64;

n_st = len(chute_stations);

// Floor slab station: a thin cross-section hulled to its neighbour.
module d2_floor_station(st) {
    w = st[2] + 2 * chute_wall;
    translate([-w / 2, st[0] - 0.4, st[1] - chute_wall])
        cube([w, 0.8, chute_wall]);
}

module d2_wall_station(st, side) {
    h = max(0.8, st[3] - st[1]);
    translate([side * (st[2] / 2), st[0] - 0.4, st[1]])
        cube([chute_wall, 0.8, h]);
}

// Frame collar on the outside of the drum: laps the window edges so the chute
// cannot slide in or out, without ever narrowing the pill path.
module d2_collar() {
    y  = h_od / 2;
    z0 = chute_win_z0 - 1.0;
    z1 = chute_win_z1 - 2.0;
    difference() {
        translate([-(chute_win_w / 2 + 4), y, z0])
            cube([chute_win_w + 8, 2.4, z1 - z0]);
        translate([-20.5, y - 1, 14.5])
            cube([41, 4.4, 22]);
    }
}

module drop_chute_v2() {
    difference() {
        union() {
            for (i = [0 : n_st - 2]) {
                hull() {
                    d2_floor_station(chute_stations[i]);
                    d2_floor_station(chute_stations[i + 1]);
                }
                for (s = [-1, 1]) hull() {
                    d2_wall_station(chute_stations[i], s);
                    d2_wall_station(chute_stations[i + 1], s);
                }
            }
            d2_collar();
        }
        // Trim the inner end square to the plate underside.
        translate([-60, chute_stations[0][0] - 30, plate_z])
            cube([120, 30.8, 40]);
    }
}

// Print orientation: as modelled. The floor underside is a 38-45 deg overhang,
// which FDM handles unsupported; add light supports under the external run if
// your first attempt droops.
drop_chute_v2();

echo(str("D2 chute: exit trough ", chute_stations[n_st - 1][2],
         " mm wide at z ", chute_stations[n_st - 1][1]));
