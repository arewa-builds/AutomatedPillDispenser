"""Redraw docs/diagrams/servo_protractor.png — a printable dial for measuring travel.

Two jobs on the bench: measuring the servo's end-to-end travel during commissioning
(the number that decides whether a fill gives three doses or four), and checking a
45° step is really 45°. The 45° marks are the carousel's own bin pitch, so the dial
doubles as a reference for park alignment.

Drawn at 300 dpi and saved with that density so a printer at 100% scale gets the
geometry right; the 100 mm bar is there to prove it did. Needs Pillow:

    pip install pillow
    python docs/diagrams/servo_protractor.py
"""

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent / "servo_protractor.png"

DPI = 300
MM = DPI / 25.4                      # pixels per millimetre

W = int(200 * MM)
H = int(258 * MM)                    # fits Letter as well as A4
CX, CY = int(100 * MM), int(98 * MM)
R = int(85 * MM)                     # 170 mm across

INK = "#111418"
GREY = "#6b7480"
RED = "#d7263d"
BLUE = "#1f5fa9"

F = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FB = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
f_title = ImageFont.truetype(FB, int(5.2 * MM))
f_lab = ImageFont.truetype(FB, int(3.6 * MM))
f_bin = ImageFont.truetype(FB, int(2.6 * MM))
f_note = ImageFont.truetype(F, int(3.2 * MM))
f_small = ImageFont.truetype(F, int(2.8 * MM))

img = Image.new("RGB", (W, H), "#ffffff")
d = ImageDraw.Draw(img)


def at(deg, radius):
    """Dial degrees, zero at 12 o'clock, clockwise — to pixels."""
    a = math.radians(deg - 90)
    return CX + radius * math.cos(a), CY + radius * math.sin(a)


# ---------------------------------------------------------------- dial
d.ellipse([CX - R, CY - R, CX + R, CY + R], outline=INK, width=int(0.5 * MM))

for deg in range(0, 360):
    if deg % 45 == 0:
        inner, width, colour = R - 10 * MM, int(0.7 * MM), RED
    elif deg % 15 == 0:
        inner, width, colour = R - 6.5 * MM, int(0.4 * MM), INK
    elif deg % 5 == 0:
        inner, width, colour = R - 4 * MM, int(0.25 * MM), INK
    else:
        inner, width, colour = R - 2.2 * MM, int(0.15 * MM), GREY
    d.line([at(deg, inner), at(deg, R)], fill=colour, width=max(1, width))

for deg in range(0, 360, 15):
    x, y = at(deg, R - 13.5 * MM)
    d.text((x, y), str(deg), font=f_lab, fill=INK, anchor="mm")

# ---------------------------------------------------------------- the 203 deg line
arc_r = R - 22 * MM
d.arc([CX - arc_r, CY - arc_r, CX + arc_r, CY + arc_r], -90, -90 + 203, fill=BLUE,
      width=int(0.8 * MM))
d.line([at(203, arc_r - 4 * MM), at(203, arc_r + 4 * MM)], fill=BLUE, width=int(0.8 * MM))
tx, ty = at(203, arc_r - 8 * MM)
d.text((tx, ty), "203°", font=f_lab, fill=BLUE, anchor="mm")
d.text((CX, CY + 34 * MM), "sweep past 203° and a fill gives", font=f_small, fill=BLUE,
       anchor="mm")
d.text((CX, CY + 39 * MM), "four doses instead of three", font=f_small, fill=BLUE,
       anchor="mm")

# ---------------------------------------------------------------- centre
d.line([(CX - 11 * MM, CY), (CX + 11 * MM, CY)], fill=GREY, width=max(1, int(0.2 * MM)))
d.line([(CX, CY - 11 * MM), (CX, CY + 11 * MM)], fill=GREY, width=max(1, int(0.2 * MM)))
d.ellipse([CX - 4 * MM, CY - 4 * MM, CX + 4 * MM, CY + 4 * MM], outline=INK,
          width=int(0.4 * MM))
d.ellipse([CX - 0.7 * MM, CY - 0.7 * MM, CX + 0.7 * MM, CY + 0.7 * MM], fill=INK)
d.text((CX, CY + 7 * MM), "cut here, over the horn screw", font=f_small, fill=GREY,
       anchor="mm")

# ---------------------------------------------------------------- instructions
y0 = CY + R + 10 * MM
d.text((14 * MM, y0), "MG90S travel dial — v3 carousel", font=f_title, fill=INK)
d.text((14 * MM, y0 + 7.5 * MM),
       "Red ticks are the carousel's 8 bins, 45° apart: one DISPENSE should move the "
       "pointer exactly one red tick.", font=f_small, fill=RED)

steps = (
    "1.  Print at 100%. No 'fit to page', no 'shrink to fit'. Check the bar below "
    "measures 100 mm.",
    "2.  Cut the centre out and slip the dial over the servo's horn screw, dial flat "
    "against the servo.",
    "3.  Tape a straw or a toothpick along the horn so it overhangs the numbers, and "
    "tape the dial down.",
    "4.  python edge/bench_servo.py --ends --port COM3   — creep to one end, read the "
    "pointer, creep to the other.",
    "5.  The difference between the two readings is TRAVEL_DEG. Past the blue 203° line "
    "means four doses.",
    "6.  Put the two pulse values into US_MIN_SAFE / US_MAX_SAFE, TRAVEL_DEG into the "
    "sketch, and rebuild.",
)
for i, text in enumerate(steps):
    d.text((14 * MM, y0 + (15 + i * 6.4) * MM), text, font=f_note, fill=INK)

# ---------------------------------------------------------------- scale check
bar_y = H - 12 * MM
x1, x2 = 14 * MM, 114 * MM
d.line([(x1, bar_y), (x2, bar_y)], fill=INK, width=int(0.5 * MM))
for x in (x1, x2):
    d.line([(x, bar_y - 3 * MM), (x, bar_y + 3 * MM)], fill=INK, width=int(0.5 * MM))
for i in range(1, 10):
    x = x1 + (x2 - x1) * i / 10
    d.line([(x, bar_y - 1.5 * MM), (x, bar_y)], fill=GREY, width=max(1, int(0.3 * MM)))
d.text((x1, bar_y + 5.5 * MM), "100 mm — measure this first; if it is wrong, so are the "
                            "angles", font=f_small, fill=RED)

img.save(OUT, dpi=(DPI, DPI))
print(f"wrote {OUT} ({W}x{H} px, {W / MM:.0f}x{H / MM:.0f} mm at {DPI} dpi)")
