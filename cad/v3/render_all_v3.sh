#!/usr/bin/env bash
# Render the v3 set.
#
#   ./render_all_v3.sh              previews only (default)
#   ./render_all_v3.sh --stl        previews + STL export
#
# Needs openscad on PATH. On a headless box, prefix with xvfb-run -a.
set -euo pipefail

cd "$(dirname "$0")"
OUT=preview
STL=stl
WITH_STL=${1:-}
mkdir -p "$OUT"
[[ "$WITH_STL" == "--stl" ]] && mkdir -p "$STL"

PARTS=(
    part_a3_deck_body
    part_b3_base_body
    part_c3_carousel
    part_d3_drive_shaft
    part_e3_servo_bracket
    part_f3_catch_tray
    part_g3_base_cover
)

run() { if command -v xvfb-run >/dev/null 2>&1; then xvfb-run -a openscad "$@"; else openscad "$@"; fi; }

for p in "${PARTS[@]}"; do
    echo "--- $p"
    run -o "$OUT/$p.png" --imgsize=1100,900 --colorscheme=Tomorrow \
        --camera=0,0,0,58,0,205,300 --autocenter --viewall "$p.scad"
    if [[ "$WITH_STL" == "--stl" ]]; then
        run -o "$STL/$p.stl" "$p.scad"
    fi
done

# Assembly views. Flags live at the top of assembly_preview_v3.scad; each view
# is rendered from a throwaway copy with the flags rewritten.
view() {              # view <name> <sed-expr> <camera>
    local name=$1 expr=$2 cam=$3
    sed -e "$expr" assembly_preview_v3.scad > ".view_$name.scad"
    run -o "$OUT/v3_$name.png" --imgsize=1500,1150 --colorscheme=Tomorrow \
        --camera="$cam" ".view_$name.scad"
    rm -f ".view_$name.scad"
}

view cutaway  's/^SHOW_BRACKET = .*/SHOW_BRACKET = true;/'                       0,14,44,60,0,205,440
view assembled 's/^CUTAWAY    = .*/CUTAWAY    = false;/'                         0,10,46,62,0,205,460
view section  's/^CUTAWAY    = true;/CUTAWAY = false;/; s/^SECTION    = .*/SECTION = true;/'  0,20,45,78,0,88,400
view top      's/^CUTAWAY    = .*/CUTAWAY    = false;/; s/^SHOW_BRACKET = .*/SHOW_BRACKET = false;/'  0,0,60,0,0,0,330
view exploded 's/^CUTAWAY    = .*/CUTAWAY    = false;/; s/^EXPLODED   = .*/EXPLODED   = true;/'       0,10,90,64,0,205,620

echo "previews -> $OUT/"
[[ "$WITH_STL" == "--stl" ]] && echo "stl      -> $STL/"
exit 0
