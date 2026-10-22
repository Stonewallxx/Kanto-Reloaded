# Builds a PIF battle backdrop (field, bases, Pikachu vs a wild Golduck,
# both databoxes, the command box with FIGHT selected) for the battle mockups.
# Placement follows PIF's own code (SceneConstants, Scene_Initialize,
# SceneElements, SceneMenus). Text is drawn later by the mockup script.
# Usage: python battle_backdrop.py "<KIF Beta>" out.png [--no-commands]
import sys, os
from PIL import Image

root, out = sys.argv[1], sys.argv[2]
G = lambda *p: os.path.join(root, "Graphics", *p)
W, H = 512, 384
img = Image.new("RGBA", (W, H), (0, 0, 0, 255))

def paste(im, x, y):
    img.alpha_composite(im, (int(x), int(y))) if x >= 0 and y >= 0 else img.paste(im, (int(x), int(y)), im)

bg = Image.open(G("Battlebacks", "battlebg", "field.png")).convert("RGBA")
paste(bg, 0, 0)
base = Image.open(G("Battlebacks", "base", "field.png")).convert("RGBA")
# foe base: centre (384, 176), origin at its middle
paste(base, 384 - base.width // 2, 176 - base.height // 2)
# player base: (128, 304), zoom 1.5, x - 50, y + 70, origin at its bottom middle
pb = base.resize((int(base.width * 1.5), int(base.height * 1.5)), Image.NEAREST)
paste(pb, 78 - pb.width // 2, 374 - pb.height)

def cell(species):
    sheet = Image.open(G("Battlers", "spritesheets_autogen", "%d.png" % species)).convert("RGBA")
    c = sheet.crop(((species % 10) * 96, (species // 10) * 96, (species % 10) * 96 + 96, (species // 10) * 96 + 96))
    return c.resize((192, 192), Image.NEAREST)

foe = cell(55)
paste(foe, 384 - 96, 176 - 192 + 30)
me = cell(25).transpose(Image.FLIP_LEFT_RIGHT)
paste(me, 128 - 96, 304 - 192 + 24)

# databoxes: player at (W - 244, H - 176), foe at (8, 0)
paste(Image.open(G("Pictures", "Battle", "databox_normal.png")).convert("RGBA"), W - 244, H - 176)
paste(Image.open(G("Pictures", "Battle", "databox_normal_foe.png")).convert("RGBA"), 8, 0)
# HP bars (overlay_hp rows: green on top) inside the boxes
hp = Image.open(G("Pictures", "Battle", "overlay_hp.png")).convert("RGBA")
green = hp.crop((0, 0, hp.width, hp.height // 3))
paste(green.crop((0, 0, int(green.width * 0.82), green.height)), W - 244 + 34 + 12, H - 176 + 40)
paste(green.crop((0, 0, int(green.width * 0.55), green.height)), 8 + 8 + 12, 0 + 40)

if "--no-commands" not in sys.argv:
    paste(Image.open(G("Pictures", "Battle", "overlay_message.png")).convert("RGBA"), 0, H - 96)
    paste(Image.open(G("Pictures", "Battle", "overlay_command.png")).convert("RGBA"), 0, H - 96)
    btn = Image.open(G("Pictures", "Battle", "cursor_command.png")).convert("RGBA")
    bw, bh = btn.width // 2, 46
    for i, cmd in enumerate([0, 2, 1, 3]):
        sx = bw if i == 0 else 0
        b = btn.crop((sx, cmd * bh, sx + bw, cmd * bh + bh))
        x = W - 260 + (0 if i % 2 == 0 else bw - 4)
        y = H - 96 + 6 + (0 if i // 2 == 0 else bh - 4)
        paste(b, x, y)
img.convert("RGB").save(out)
print("saved", out)
