#!/usr/bin/env bash
# Regenerate all STLs and PNG previews for the printable prototype set.
# Parts D / I / J export as single-body STLs only (no floating multi-body plates).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
mkdir -p stl previews

# Remove legacy multi-body exports if present
rm -f \
  stl/part_d_latch_gate_only.stl \
  stl/part_i_cable_clips.stl \
  stl/part_j_feet.stl

parts=(
  part_a_base_enclosure
  part_b_base_plate
  part_c_carousel
  part_e_carousel_lid
  part_f_catch_tray
  part_g_chute_spout
  part_h_latch_servo_bracket
  part_k_pill_insert
  assembly_preview
)

for p in "${parts[@]}"; do
  echo "==> STL $p"
  openscad -o "stl/${p}.stl" "${p}.scad"
  echo "==> PNG $p"
  openscad -o "previews/${p}.png" --imgsize=1100,850 --autocenter --viewall \
    --colorscheme=Tomorrow "${p}.scad"
done

echo "==> STL/PNG Part D (gate + arm as separate files)"
openscad -D 'BUILD="gate"' -o stl/part_d_latch_gate.stl part_d_latch_gate.scad
openscad -D 'BUILD="arm"'  -o stl/part_d_latch_horn_arm.stl part_d_latch_gate.scad
openscad -D 'BUILD="both"' -o previews/part_d_latch_gate.png --imgsize=1100,850 \
  --autocenter --viewall --colorscheme=Tomorrow part_d_latch_gate.scad
openscad -D 'BUILD="arm"' -o previews/part_d_latch_horn_arm.png --imgsize=1100,850 \
  --autocenter --viewall --colorscheme=Tomorrow part_d_latch_gate.scad

echo "==> STL/PNG Part I (single clip)"
openscad -D 'LAYOUT="single"' -o stl/part_i_cable_clip.stl part_i_cable_clips.scad
openscad -D 'LAYOUT="single"' -o previews/part_i_cable_clip.png --imgsize=1100,850 \
  --autocenter --viewall --colorscheme=Tomorrow part_i_cable_clips.scad
# Keep a grid preview under the old preview name for docs
openscad -D 'LAYOUT="grid"' -o previews/part_i_cable_clips.png --imgsize=1100,850 \
  --autocenter --viewall --colorscheme=Tomorrow part_i_cable_clips.scad

echo "==> STL/PNG Part J (single foot)"
openscad -D 'LAYOUT="single"' -o stl/part_j_foot.stl part_j_feet.scad
openscad -D 'LAYOUT="single"' -o previews/part_j_foot.png --imgsize=1100,850 \
  --autocenter --viewall --colorscheme=Tomorrow part_j_feet.scad
openscad -D 'LAYOUT="grid"' -o previews/part_j_feet.png --imgsize=1100,850 \
  --autocenter --viewall --colorscheme=Tomorrow part_j_feet.scad

echo "Done. Outputs in cad/stl and cad/previews"
ls -la stl/part_d* stl/part_i* stl/part_j* 2>/dev/null || true
ls -la stl previews
