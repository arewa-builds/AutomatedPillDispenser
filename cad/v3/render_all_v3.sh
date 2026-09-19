#!/usr/bin/env bash
# Render the v3 set.
#
#   ./render_all_v3.sh              previews only (default)
#   ./render_all_v3.sh --stl        previews + STL export
#
# Needs openscad on PATH. Uses xvfb-run automatically when there is no display.
set -euo pipefail

cd "$(dirname "$0")"
OUT=previews
STL=stl
WITH_STL=${1:-}
mkdir -p "$OUT"
[[ "$WITH_STL" == "--stl" ]] && mkdir -p "$STL"

run() { if command -v xvfb-run >/dev/null 2>&1; then xvfb-run -a openscad "$@"; else openscad "$@"; fi; }

# Each part file renders in its PRINT orientation (the modules themselves work in
# assembly coordinates), and none of them lands centred on the origin, so every
# view gets an explicit look-at point and distance rather than using --viewall.
#   name | camera (transx,transy,transz,rotx,roty,rotz,dist)
PART_VIEWS=(
    "part_a3_deck_body|0,-3,21,58,0,25,300"
    "part_b3_base_body|0,10,26,62,0,200,320"
    "part_c3_carousel|0,0,13,58,0,205,250"
    "part_d3_drive_shaft|0,0,15,62,0,205,90"
    "part_e3_servo_bracket|39,0,20,62,0,325,210"
    "part_f3_catch_tray|0,99,7,60,0,205,200"
    "part_g3_base_cover|0,0,1.5,55,0,205,260"
)

# Extra detail views of single parts.
DETAIL_VIEWS=(
    "part_a3_deck_body|deck_wedge|0,0,21,0,0,0,360"
    "part_b3_base_body|chute|0,22,22,58,0,160,300"
)

for entry in "${PART_VIEWS[@]}"; do
    p=${entry%%|*}; cam=${entry##*|}
    echo "--- $p"
    run -o "$OUT/$p.png" --imgsize=1200,950 --colorscheme=Tomorrow --camera="$cam" "$p.scad"
    if [[ "$WITH_STL" == "--stl" ]]; then
        run -o "$STL/$p.stl" "$p.scad"
    fi
done

# Test coupons. Small pieces cut from the real parts — see PLAN.md section 8.
COUPON_VIEWS=(
    "coupon_1_sector|0,0,8,55,0,200,290"
    "coupon_2_drive_train|15,10,10,56,0,200,230"
    "coupon_3_chute_dock|0,72,12,64,0,195,240"
)

for entry in "${COUPON_VIEWS[@]}"; do
    p=${entry%%|*}; cam=${entry##*|}
    echo "--- $p"
    run -o "$OUT/$p.png" --imgsize=1200,950 --colorscheme=Tomorrow --camera="$cam" "$p.scad"
    if [[ "$WITH_STL" == "--stl" ]]; then
        run -o "$STL/$p.stl" "$p.scad"
    fi
done

for entry in "${DETAIL_VIEWS[@]}"; do
    IFS='|' read -r p tag cam <<< "$entry"
    echo "--- $p ($tag)"
    run -o "$OUT/${p}_${tag}.png" --imgsize=1100,1100 --colorscheme=Tomorrow --camera="$cam" "$p.scad"
done

# The drop-path check, rendered with the fall volume ghosted over the base body so
# the preview set carries the evidence and not just the claim.
echo "--- check: drop path"
run -o "$OUT/v3_drop_path.png" --imgsize=1200,950 --colorscheme=Tomorrow \
    -D MODE=2 --camera=0,16,24,58,0,190,340 check_drop_path.scad

# Assembly views. Flags live at the top of assembly_preview_v3.scad; each view is
# rendered from a throwaway copy with those flags rewritten.
view() {              # view <name> <sed-expr> <camera> [imgsize]
    local name=$1 expr=$2 cam=$3 size=${4:-1500,1150}
    echo "--- assembly: $name"
    sed -e "$expr" assembly_preview_v3.scad > ".view_$name.scad"
    run -o "$OUT/v3_$name.png" --imgsize="$size" --colorscheme=Tomorrow \
        --camera="$cam" ".view_$name.scad"
    rm -f ".view_$name.scad"
}

view cutaway   's/^SHOW_BRACKET = .*/SHOW_BRACKET = true;/'                      0,14,44,60,0,205,440
view assembled 's/^CUTAWAY    = .*/CUTAWAY    = false;/'                         0,10,46,62,0,205,460
view section   's/^CUTAWAY    = true;/CUTAWAY = false;/; s/^SECTION    = .*/SECTION = true;/'  0,20,45,78,0,88,400
# Same section, closed in on the chute: the one view that shows the ramp running
# unbroken from under the deck's wedge to the lip over the tray.
view chute     's/^CUTAWAY    = true;/CUTAWAY = false;/; s/^SECTION    = .*/SECTION = true;/'  0,36,33,82,0,88,280  1300,900
view top       's/^CUTAWAY    = .*/CUTAWAY    = false;/; s/^SHOW_BRACKET = .*/SHOW_BRACKET = false;/'  0,0,60,0,0,0,330  1150,1150
view exploded  's/^CUTAWAY    = .*/CUTAWAY    = false;/; s/^EXPLODED   = .*/EXPLODED   = true;/'       0,10,90,64,0,205,620

# Annotated hero, built from the cutaway. Skipped if Pillow is unavailable.
if python3 -c "import PIL" 2>/dev/null; then
    echo "--- hero (annotated)"
    python3 annotate_hero.py
else
    echo "--- hero skipped: pip install pillow to build it"
fi

echo "previews -> $OUT/"
[[ "$WITH_STL" == "--stl" ]] && echo "stl      -> $STL/"
exit 0
