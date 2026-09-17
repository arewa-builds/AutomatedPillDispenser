// ============================================================================
// v3 PART D3 — drive shaft extension
//
// Top hat: a round MG90S horn screws into the head, the servo's spline plugs
// down into that horn, and the hex foot drops into the carousel hub. The hex is
// a loose fit on purpose — it transmits torque without side-loading the
// carousel, so the pilot post remains the only thing defining the axis.
//
// Print head-down on the bed: the head's underside becomes the first layer and
// the column tapers nowhere, so there is nothing to support.
// ============================================================================

include <parameters_v3.scad>;
include <lib_v3.scad>;

$fn = 96;

shaft_z0  = car_top - hex_depth;                 // hex foot bottom
head_top  = brk_arm_top - servo_nose_h - servo_shaft_h + horn_disc_h;
col_top   = head_top - shaft_head_t;

module drive_shaft_v3() {
    difference() {
        union() {
            translate([0, 0, shaft_z0])
                cylinder(h = hex_depth, d = hex_af / cos(30), $fn = 6);
            translate([0, 0, shaft_z0 + hex_depth - 0.01])
                cylinder(h = col_top - shaft_z0 - hex_depth + 0.01, d = shaft_body_d);
            translate([0, 0, col_top]) cylinder(h = shaft_head_t, d = shaft_head_d);
        }

        // Horn pocket, splines up.
        translate([0, 0, head_top - horn_disc_h])
            cylinder(h = horn_disc_h + 0.1, d = horn_disc_d + fit_slip);
        translate([0, 0, head_top - shaft_head_t])
            cylinder(h = shaft_head_t + 0.1, d = horn_boss_d);
        for (i = [0 : horn_screw_n - 1])
            rotate([0, 0, i * 360 / horn_screw_n])
                translate([horn_hole_r, 0, head_top - horn_disc_h - 5])
                    cylinder(h = 5.2, d = m2_pilot_d);
    }
}

rotate([180, 0, 0]) translate([0, 0, -head_top]) drive_shaft_v3();

echo(str("D3 shaft: ", head_top - shaft_z0, " mm overall, hex ", hex_af,
         " A/F +", hex_slip, " slip"));
