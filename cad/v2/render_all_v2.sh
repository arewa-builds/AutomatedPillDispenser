#!/usr/bin/env bash
# Export every v2 part to STL plus a preview PNG, then render the assembly views.
#   ./render_all_v2.sh
set -euo pipefail

cd "$(dirname "$0")"
mkdir -p stl previews

OSC=${OPENSCAD:-openscad}
if ! command -v "$OSC" >/dev/null 2>&1; then
    echo "openscad not found; install it (apt-get install openscad) or set OPENSCAD=" >&2
    exit 1
fi
# Headless boxes need a virtual display for the PNG previews.
RUN=""
if [ -z "${DISPLAY:-}" ] && command -v xvfb-run >/dev/null 2>&1; then
    RUN="xvfb-run -a"
fi

PARTS=(
    part_a2_housing
    part_b2_fixed_plate
    part_c2_carousel
    part_d2_drop_chute
    part_e2_servo_bridge
    part_f2_catch_tray
    part_g2_base_cover
)

for p in "${PARTS[@]}"; do
    echo "--- $p"
    $RUN "$OSC" -o "stl/$p.stl" "$p.scad"
    $RUN "$OSC" -o "previews/$p.png" --imgsize=1200,1000 --colorscheme=Tomorrow \
        --camera=0,0,0,55,0,205,300 --autocenter --viewall "$p.scad"
done

echo "--- assembly views"
$RUN "$OSC" -o previews/assembly_cutaway.png --imgsize=2000,1500 --colorscheme=Tomorrow \
    --camera=0,0,0,40,0,205,400 --autocenter --viewall \
    -D SHOW_BRIDGE=false assembly_preview_v2.scad
$RUN "$OSC" -o previews/assembly_closed.png --imgsize=1700,1400 --colorscheme=Tomorrow \
    --camera=0,0,0,56,0,205,430 --autocenter --viewall \
    -D CUTAWAY=false -D SHOW_PILLS=false assembly_preview_v2.scad
$RUN "$OSC" -o previews/assembly_section.png --imgsize=1700,1400 --colorscheme=Tomorrow \
    --camera=0,0,0,70,0,115,420 --autocenter --viewall \
    -D SECTION=true -D CUTAWAY=false assembly_preview_v2.scad
$RUN "$OSC" -o previews/assembly_exploded.png --imgsize=1700,1650 --colorscheme=Tomorrow \
    --camera=0,0,0,60,0,205,620 --autocenter --viewall \
    -D EXPLODED=true -D CUTAWAY=false assembly_preview_v2.scad

echo "done: $(ls stl | wc -l) STLs, $(ls previews | wc -l) PNGs"
