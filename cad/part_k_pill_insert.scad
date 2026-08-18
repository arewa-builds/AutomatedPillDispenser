// Part K — Optional pill-pocket size insert (print up to 8)
// Snaps into a carousel pocket to shrink volume for small tablets.
// Export → stl/part_k_pill_insert.stl
// Print flat. PLA. Light press into Part C pocket.

include <parameters.scad>;

$fn = 48;

module part_k_pill_insert() {
    sector = 360 / car_pockets;
    pocket_angle = sector - 8;
    r_inner = car_hub_od / 2 + 2;
    r_outer = car_dia / 2 - car_wall - insert_outer_clear;

    difference() {
        // Pie wedge body
        rotate([0, 0, -pocket_angle / 2])
            intersection() {
                difference() {
                    cylinder(h = insert_h, r = r_outer, center = false);
                    translate([0, 0, -0.1])
                        cylinder(h = insert_h + 0.2, r = r_inner, center = false);
                }
                translate([0, 0, -0.05])
                    linear_extrude(height = insert_h + 0.1)
                        polygon([
                            [0, 0],
                            [r_outer * 2, 0],
                            [r_outer * 2 * cos(pocket_angle), r_outer * 2 * sin(pocket_angle)]
                        ]);
            }
        // Inner well for a single small tablet (open bottom)
        translate([(r_inner + r_outer) / 2, 0, -0.1])
            cylinder(h = insert_h + 0.2, d = 10, center = false);
    }
}

part_k_pill_insert();
