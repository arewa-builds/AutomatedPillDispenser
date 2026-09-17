// ============================================================================
// v3 PART F3 — catch tray, mouth flush with the chute walls
//
// The mouth wall is cut down so the chute lip overhangs into the well with no
// step for a tablet to catch on. Free-standing: lift it out to take the dose.
// Its flat floor is the camera's pill-count zone, so keep it matte.
// ============================================================================

include <parameters_v3.scad>;
include <lib_v3.scad>;

$fn = 64;

corner_r = 6.0;

module f3_shell(inset, h, z0) {
    x = tray_w - 2 * inset;
    y = tray_l - 2 * inset;
    translate([0, tray_y0 + tray_l / 2, z0])
        hull() for (ix = [-1, 1], iy = [-1, 1])
            translate([ix * (x / 2 - corner_r), iy * (y / 2 - corner_r), 0])
                cylinder(h = h, r = corner_r);
}

module catch_tray_v3() {
    difference() {
        f3_shell(0, tray_h, base_z);
        f3_shell(tray_floor + 1.8, tray_h, base_z + tray_floor);
        // Cut the mouth wall down to clear the chute lip.
        translate([-(chute_win_w / 2 + 3), tray_y0 - 1, base_z + tray_mouth_h])
            cube([chute_win_w + 6, 6, tray_h]);
    }
}

translate([0, 0, -base_z]) catch_tray_v3();

echo(str("F3 tray: ", tray_w, " x ", tray_l, " x ", tray_h,
         ", mouth wall ", tray_mouth_h, " mm vs chute lip at z ",
         chute_stations[len(chute_stations) - 1][1]));
