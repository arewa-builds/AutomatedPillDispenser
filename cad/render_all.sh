#!/usr/bin/env bash
# Regenerate all STLs and PNG previews for the printable prototype set.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
mkdir -p stl previews

parts=(
  part_a_base_enclosure
  part_b_base_plate
  part_c_carousel
  part_d_latch_gate
  part_e_carousel_lid
  part_f_catch_tray
  part_g_chute_spout
  part_h_latch_servo_bracket
  part_i_cable_clips
  part_j_feet
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

# Separate gate / arm STLs from Part D
echo "==> STL part_d gate + arm variants"
openscad -D 'BUILD="gate"' -o stl/part_d_latch_gate_only.stl part_d_latch_gate.scad
openscad -D 'BUILD="arm"'  -o stl/part_d_latch_horn_arm.stl part_d_latch_gate.scad

echo "Done. Outputs in cad/stl and cad/previews"
ls -la stl previews
