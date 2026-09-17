// ============================================================================
// Shared geometry helpers for the v2 print set.   include <lib_v2.scad>;
// ============================================================================

// Wedge prism, centred on +X, spanning +/- ang/2, rising from z = 0.
module sector_prism(r, ang, h, seg = 64) {
    steps = max(4, ceil(ang / 2.5));   // ~2.5 deg chords, independent of ang
    linear_extrude(height = h)
        polygon(concat(
            [[0, 0]],
            [for (i = [0 : steps])
                let (a = -ang / 2 + ang * i / steps) [r * cos(a), r * sin(a)]]
        ));
}

// Annular sector prism, centred on +X, rising from z = 0.
module ring_sector(r_in, r_out, ang, h, seg = 64) {
    difference() {
        sector_prism(r_out, ang, h, seg);
        translate([0, 0, -0.05]) cylinder(h = h + 0.1, r = r_in, $fn = seg);
    }
}

module tube(od, id, h) {
    difference() {
        cylinder(h = h, d = od);
        translate([0, 0, -0.05]) cylinder(h = h + 0.1, d = id);
    }
}

// Inward ledge with a 45 deg self-supporting underside. Top face at z_top.
module chamfered_ledge(r_wall, w, z_top) {
    rotate_extrude(convexity = 4)
        polygon([[r_wall - w, z_top],
                 [r_wall,     z_top],
                 [r_wall,     z_top - w]]);
}

// Thin slab used as a hull station for the chute trough.
module station_slab(y, z, w, t = 0.6) {
    translate([-w / 2, y - t / 2, z]) cube([w, t, 0.6]);
}
