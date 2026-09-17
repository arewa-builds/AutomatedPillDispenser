from PIL import Image, ImageDraw, ImageFont

SRC = 'previews/v3_cutaway.png'
DST = 'previews/v3_hero_annotated.png'

PAD_L, PAD_R, PAD_T, PAD_B = 430, 430, 90, 40
FB = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
FR = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'

base = Image.open(SRC).convert('RGB')
W, H = base.size
canvas = Image.new('RGB', (W + PAD_L + PAD_R, H + PAD_T + PAD_B), (255, 255, 255))
canvas.paste(base, (PAD_L, PAD_T))
d = ImageDraw.Draw(canvas)

f_title = ImageFont.truetype(FB, 40)
f_lab = ImageFont.truetype(FB, 24)
f_sub = ImageFont.truetype(FR, 21)

INK = (25, 28, 32)
ACC = (0, 96, 190)
RED = (200, 30, 40)


def O(p):
    return (p[0] + PAD_L, p[1] + PAD_T)


# side, anchor in render coords, label, sub-lines, label y, accent
LABELS = [
    ('R', (770, 70), 'MG90S servo', ['Body sits above the plate,', 'output shaft points down'], 120, ACC),
    ('R', (975, 145), 'Support bracket', ['Screws in from OUTSIDE the wall,', 'so nothing intrudes into the bore'], 300, ACC),
    ('R', (795, 305), 'Printed drive shaft', ['Loose hex into the hub: passes', 'torque, never side-loads it'], 470, INK),
    ('R', (862, 505), 'Pills rest on the deck', ['Bins have no floor and no', 'outer wall, exactly as drawn'], 640, INK),
    ('R', (1032, 612), 'Two printed bodies,', ['three screwed ears. Split here so', 'both halves print support-free'], 810, INK),
    ('L', (565, 455), '8 open compartments', ['Dividers sweep 0.35 mm', 'above the deck'], 160, INK),
    ('L', (706, 600), '24\u00b0 discharge wedge', ['This bin has just dumped. At rest it', 'covers the wedge: \u00b16\u00b0 of park margin'], 380, RED),
    ('L', (612, 795), '45\u00b0 chute, integral', ['Wall opens from the deck down,', 'so no ledge can shelf a tablet'], 620, INK),
    ('L', (300, 1045), 'Catch tray', ['Mouth wall cut down; the chute', 'lip overhangs into the well'], 860, INK),
]

d.text((PAD_L + 10, 24), 'v3 concept \u2014 integral deck, 8 open compartments, single servo',
       font=f_title, fill=INK)

for side, anchor, title, subs, ly, accent in LABELS:
    ax, ay = O(anchor)
    tw = max(d.textlength(title, font=f_lab),
             max(d.textlength(s, font=f_sub) for s in subs))
    bh = 34 + 26 * len(subs)
    if side == 'R':
        bx = PAD_L + W + 26
        d.rectangle([bx - 12, ly + PAD_T - 8, bx + tw + 14, ly + PAD_T + bh], fill=(248, 249, 250))
        d.text((bx, ly + PAD_T), title, font=f_lab, fill=accent)
        for i, s in enumerate(subs):
            d.text((bx, ly + PAD_T + 30 + 26 * i), s, font=f_sub, fill=INK)
        elbow = (bx - 26, ly + PAD_T + 12)
    else:
        bx = PAD_L - 26
        d.rectangle([bx - tw - 14, ly + PAD_T - 8, bx + 12, ly + PAD_T + bh], fill=(248, 249, 250))
        d.text((bx - tw, ly + PAD_T), title, font=f_lab, fill=accent)
        for i, s in enumerate(subs):
            d.text((bx - tw, ly + PAD_T + 30 + 26 * i), s, font=f_sub, fill=INK)
        elbow = (bx + 26, ly + PAD_T + 12)
    d.line([elbow, (ax, ay)], fill=accent, width=3)
    d.ellipse([ax - 7, ay - 7, ax + 7, ay + 7], fill=accent)

canvas.save(DST)
print(DST, canvas.size)
