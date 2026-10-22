# Mockups: the lock mark on KIF Beta's party screen (his ask: level locks
# are set in the Level Lock Manager only, and a locked Pokémon shows a lock
# mark in the party). Three designs, drawn over the party screen as
# party_backdrop.py builds it; Gyarados (Lv 35) and Eevee (Lv 22) are locked.
#   LM1 a gold padlock after the level (Recommended)
#   LM2 a padlock badge on the Pokémon's icon
#   LM3 the level itself in gold
# Usage: python party_lock_designs.py "<KIF Beta>" <out folder>
import os, sys, json, subprocess
from PIL import Image, ImageDraw

ROOT, OUT = sys.argv[1], sys.argv[2]
HERE = os.path.dirname(os.path.abspath(__file__))
os.makedirs(OUT, exist_ok=True)
base_png = os.path.join(OUT, "party_base.png")
subprocess.run([sys.executable, os.path.join(HERE, "..", "party_backdrop.py"), ROOT, base_png,
                "--party", "PIKACHU:Pikachu:34:78/95:m,PIDGEOT:Pidgeot:36:120/120:f,GYARADOS:Gyarados:35:20/110:m,"
                           "EEVEE:Eevee:22:60/60:f,MACHOKE:Machoke:33:101/101:m,GENGAR:Gengar:37:90/90:m",
                "--sel", "2", "--help", "Choose a Pokémon or cancel."], check=True)
info = json.load(open(os.path.splitext(base_png)[0] + ".json"))
LOCKED = [2, 3]
GOLD = (240, 200, 80, 255)
GOLD_SHADOW = (90, 70, 20, 255)
DARK = (24, 32, 40, 255)

def padlock(d, x, y, col, shadow=None):
    """A padlock 9 x 11, top-left at x, y (shadow drawn 1 px down and right first)."""
    for (c, ox) in ([(shadow, 1)] if shadow else []) + [(col, 0)]:
        d.rectangle([x + 2 + ox, y + ox, x + 6 + ox, y + ox], fill=c)
        d.rectangle([x + 1 + ox, y + 1 + ox, x + 1 + ox, y + 4 + ox], fill=c)
        d.rectangle([x + 7 + ox, y + 1 + ox, x + 7 + ox, y + 4 + ox], fill=c)
        d.rectangle([x + ox, y + 5 + ox, x + 8 + ox, y + 10 + ox], fill=c)
    d.rectangle([x + 4, y + 7, x + 4, y + 8], fill=DARK)        # the keyhole

def save(img, name):
    p = os.path.join(OUT, name + ".png")
    img.save(p)
    img.resize((img.width * 2, img.height * 2), Image.NEAREST).save(os.path.join(OUT, name + "@2x.png"))
    print("saved", p)

base = Image.open(base_png).convert("RGBA")

# LM1: a gold padlock right after the level number
img = base.copy(); d = ImageDraw.Draw(img)
for i in LOCKED:
    lx, ly, lw, lh = info["panels"][i]["level_text"]["ink"]
    padlock(d, lx + lw + 4, ly + (lh - 11) // 2, GOLD, GOLD_SHADOW)
save(img, "QA_LM1_after_level")

# LM2: a padlock badge on the icon's lower left, where the held item isn't
img = base.copy(); d = ImageDraw.Draw(img)
for i in LOCKED:
    fx, fy, fw, fh = info["panels"][i]["icon"]["frame_rect"]
    bx, by = fx + 2, fy + fh - 18
    d.rounded_rectangle([bx, by, bx + 14, by + 15], radius=3, fill=DARK, outline=GOLD)
    padlock(d, bx + 3, by + 2, GOLD)
save(img, "QA_LM2_icon_badge")

# LM3: the level itself turns gold (the white of its digits)
img = base.copy(); px = img.load()
for i in LOCKED:
    lx, ly, lw, lh = info["panels"][i]["level_text"]["box"]
    for yy in range(ly, ly + lh):
        for xx in range(lx, lx + lw):
            r, g, b, a = px[xx, yy]
            if r > 200 and g > 200 and b > 200:
                px[xx, yy] = GOLD
            elif (r, g, b) == (40, 40, 40) or (r < 70 and g < 70 and b < 70 and a > 0):
                px[xx, yy] = GOLD_SHADOW
    lix, liy, liw, lih = info["panels"][i]["level_image"]
    for yy in range(liy, liy + lih):
        for xx in range(lix, lix + liw):
            r, g, b, a = px[xx, yy]
            if r > 200 and g > 200 and b > 200:
                px[xx, yy] = GOLD
save(img, "QA_LM3_gold_level")
