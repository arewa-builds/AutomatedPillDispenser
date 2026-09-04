// Part C — Rotating 8-compartment carousel
// Export STL → cad/stl/part_c_carousel.stl
// Print flat. Press-fit onto MG90S plastic horn. No supports.

include <parameters.scad>;

$fn = 80;

module part_c_carousel() {
    sector = 360 / car_pockets;
    wall_angle = 6;                 // spoke thickness in degrees
    pocket_angle = sector - wall_angle;
    rim = car_wall;
    hub_r = car_hub_od / 2;

    difference() {
        // Main drum
        cylinder(h = car_h, d = car_dia, center = false);

        // Pocket cavities (through-hole so pills can fall onto Part B)
        for (i = [0 : car_pockets - 1]) {
            rotate([0, 0, i * sector + wall_angle / 2])
                translate([hub_r + rim + 1, 0, -0.1])
                    rotate([0, 0, pocket_angle / 2])
                        translate([0, 0, 0])
                            linear_extrude(height = car_h + 0.2)
                                polygon([
                                    [0, 0],
                                    [(car_dia / 2 - rim - hub_r - 1) , 0],
                                    [(car_dia / 2 - rim - hub_r - 1) * cos(pocket_angle),
                                     (car_dia / 2 - rim - hub_r - 1) * sin(pocket_angle)]
                                ]);
        }

        // Horn bore + cross
        translate([0, 0, -0.1])
            cylinder(h = car_h + 0.2, d = car_hub_id, center = false);
        translate([0, 0, car_h / 2])
            cube([car_hub_id + 5, 1.5, car_h + 0.2], center = true);
        translate([0, 0, car_h / 2])
            cube([1.5, car_hub_id + 5, car_h + 0.2], center = true);
        // Horn screw access
        translate([0, 0, car_h - 3])
            cylinder(h = 4, d = 3.5, center = false);
    }
}

part_c_carousel();
