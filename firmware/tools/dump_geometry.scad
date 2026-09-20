// Not a part. Prints the handful of v3 numbers the firmware has to agree with,
// in one parseable line, so geometry_from_cad.sh can turn them into a header
// instead of someone retyping them into the sketch.
//
//   ../tools/geometry_from_cad.sh        (writes ../pill_dispenser/v3_geometry.h)

include <../../cad/v3/parameters_v3.scad>;

echo(str("V3GEOM bins=", car_n,
         " step=", car_pitch,
         " park_margin=", park_margin,
         " play=", hex_backlash));
