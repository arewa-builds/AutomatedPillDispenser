"""Redraw docs/diagrams/bench_wiring_3pad.png — the v3 bench wiring diagram.

Scripted rather than hand-drawn so the pad names, the shared ground and the pulse
budget notes stay in step with firmware/README.md. Needs Pillow:

    pip install pillow
    python docs/diagrams/bench_wiring.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent / "bench_wiring_3pad.png"

W, H = 1600, 1120
BG = "#f6f7f9"
INK = "#1d2430"
GREY = "#6b7480"
RED = "#d7263d"
BLACK = "#22262b"
ORANGE = "#ef8a17"
EDGE = "#39404a"

F = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FB = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
f_title = ImageFont.truetype(FB, 38)
f_sub = ImageFont.truetype(F, 23)
f_box = ImageFont.truetype(FB, 25)
f_cap = ImageFont.truetype(F, 20)
f_pin = ImageFont.truetype(FB, 20)
f_note = ImageFont.truetype(F, 21)

img = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(img)

WIRE = 7
Y_IN_P, Y_IN_N = 420, 480      # cell side, into the boost
Y_OUT_P, Y_OUT_N = 610, 690    # 5 V side, out to the servo
BOX_T, BOX_B = 300, 520


def box(x0, x1, title, subtitle=None, top=BOX_T, bottom=BOX_B):
    d.rounded_rectangle([x0, top, x1, bottom], 14, fill="#ffffff", outline=EDGE, width=3)
    cx = (x0 + x1) // 2
    d.text((cx, top + 38), title, font=f_box, fill=INK, anchor="mm")
    if subtitle:
        d.text((cx, top + 70), subtitle, font=f_sub, fill=GREY, anchor="mm")


def pad(x, y, label, where):
    d.rectangle([x - 7, y - 7, x + 7, y + 7], fill=EDGE)
    off = {"left": (18, 0, "lm"), "right": (-18, 0, "rm"), "below": (0, -24, "mm")}[where]
    d.text((x + off[0], y + off[1]), label, font=f_pin, fill=INK, anchor=off[2])


def wire(points, colour):
    d.line(points, fill=colour, width=WIRE, joint="curve")


def node(x, y, colour):
    d.ellipse([x - 10, y - 10, x + 10, y + 10], fill=colour)


# ---------------------------------------------------------------- header
d.text((60, 40), "v3 carousel drive — bench wiring, 3-pad boost module", font=f_title,
       fill=INK)
d.text((60, 92), "One GND pad serves input and output, which is exactly the shared "
                 "ground the servo and the Nano need.", font=f_sub, fill=GREY)

# ---------------------------------------------------------------- boards
box(60, 250, "LiPo", "3.7 V  500 mAh")
d.rectangle([243, Y_IN_P - 7, 257, Y_IN_P + 7], fill=EDGE)
d.rectangle([243, Y_IN_N - 7, 257, Y_IN_N + 7], fill=EDGE)
d.text((155, 548), "JST-PH pigtail", font=f_cap, fill=GREY, anchor="mm")

box(350, 590, "TP4056", "USB-C charger")
pad(350, Y_IN_P, "B+", "left")
pad(350, Y_IN_N, "B−", "left")
pad(590, Y_IN_P, "OUT+", "right")
pad(590, Y_IN_N, "OUT−", "right")
d.text((470, 548), "HW-373: all four pads on one edge,", font=f_cap, fill=GREY, anchor="mm")
d.text((470, 574), "printed OUT−  B−  B+  OUT+", font=f_cap, fill=GREY, anchor="mm")

box(720, 960, "Boost module", "0.9–5 V → 5 V")
pad(760, BOX_B, "VI", "below")
pad(840, BOX_B, "GND", "below")
pad(920, BOX_B, "VO", "below")

box(1150, 1420, "MG90S servo", None, top=480, bottom=730)
for y, label in ((560, "orange  ·  signal"), (Y_OUT_P, "red  ·  +5 V in"),
                 (Y_OUT_N, "brown  ·  ground")):
    d.rectangle([1143, y - 7, 1157, y + 7], fill=EDGE)
    d.text((1172, y), label, font=f_pin, fill=INK, anchor="lm")

d.rounded_rectangle([1080, 850, 1460, 1040], 14, fill="#ffffff", outline=EDGE, width=3)
d.text((1270, 950), "Arduino", font=f_box, fill=INK, anchor="mm")
d.text((1270, 982), "Nano 33 BLE", font=f_box, fill=INK, anchor="mm")
for x, label in ((1180, "GND"), (1330, "D9")):
    d.rectangle([x - 7, 843, x + 7, 857], fill=EDGE)
    d.text((x, 886), label, font=f_pin, fill=INK, anchor="mm")
d.rectangle([1460, 895, 1505, 927], fill=EDGE)
wire([(1505, 911), (1570, 911)], GREY)
d.text((1568, 945), "laptop USB\npower + serial", font=f_cap, fill=GREY, anchor="ra")

# ---------------------------------------------------------------- cell side in
wire([(250, Y_IN_P), (350, Y_IN_P)], RED)
wire([(250, Y_IN_N), (350, Y_IN_N)], BLACK)
wire([(590, Y_IN_P), (660, Y_IN_P), (660, 600), (760, 600), (760, BOX_B)], RED)
wire([(590, Y_IN_N), (700, Y_IN_N), (700, Y_OUT_N), (840, Y_OUT_N)], BLACK)

# ---------------------------------------------------------------- 5 V side out
wire([(920, BOX_B), (920, Y_OUT_P), (1143, Y_OUT_P)], RED)
wire([(840, BOX_B), (840, Y_OUT_N), (1143, Y_OUT_N)], BLACK)
node(840, Y_OUT_N, BLACK)

# ground carries on to the Nano — without it the pulse on D9 has no reference
wire([(980, Y_OUT_N), (980, 800), (1180, 800), (1180, 850)], BLACK)
node(980, Y_OUT_N, BLACK)

# ---------------------------------------------------------------- bulk capacitor
wire([(1060, Y_OUT_P), (1060, 645)], RED)
wire([(1060, 661), (1060, Y_OUT_N)], BLACK)
d.line([(1026, 645), (1094, 645)], fill=RED, width=9)
d.line([(1026, 661), (1094, 661)], fill=BLACK, width=9)
node(1060, Y_OUT_P, RED)
node(1060, Y_OUT_N, BLACK)
d.text((1016, 653), "470–1000 µF", font=f_pin, fill=INK, anchor="rm")

# ---------------------------------------------------------------- signal
wire([(1143, 560), (1120, 560), (1120, 240), (1490, 240), (1490, 815), (1330, 815),
      (1330, 850)], ORANGE)
d.text((1300, 214), "3.3 V logic drives an MG90S fine", font=f_cap, fill=GREY, anchor="mm")
d.text((1270, 1068), "nothing from the boost goes to 5V, VIN or 3V3", font=f_cap, fill=RED,
       anchor="mm")

# ---------------------------------------------------------------- legend
lx, ly = 60, 760
d.rounded_rectangle([lx, ly, lx + 790, ly + 320], 14, fill="#ffffff", outline="#d8dce2",
                    width=2)
for i, (colour, text) in enumerate((
        (RED, "3.7 V from the cell, then 5 V out of VO"),
        (BLACK, "ground — one net, shared by everything"),
        (ORANGE, "servo signal, into D9"))):
    y = ly + 40 + i * 36
    d.line([(lx + 26, y), (lx + 86, y)], fill=colour, width=WIRE)
    d.text((lx + 102, y), text, font=f_note, fill=INK, anchor="lm")

d.text((lx + 26, ly + 156), "Three wires on one GND pad", font=f_box, fill=INK)
for i, text in enumerate((
        "GND takes three: TP4056 OUT−, servo brown, Nano GND.",
        "Solder one pigtail to GND and join the other two on a breadboard row.",
        "Cap goes across VO and GND at the servo end, striped leg to ground.",
        "Check VO reads ~5.0 V unloaded before the servo is anywhere near it.")):
    d.text((lx + 26, ly + 202 + i * 30), "•  " + text, font=f_note, fill=GREY)

img.save(OUT)
print(f"wrote {OUT}")
