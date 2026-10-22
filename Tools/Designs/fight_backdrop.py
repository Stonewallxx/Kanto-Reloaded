# Builds a PIF battle backdrop with the Fight menu open, for the Move
# Effectiveness mockups: singles (Pikachu vs a wild Gyarados) or doubles
# (Pikachu + Lapras vs Gyarados + Onix). Placement follows PIF's own code
# (SceneConstants.pbBattlerPosition, PokemonDataBox.initializeDataBoxGraphic,
# FightMenuDisplay). Text is drawn later by the mockup script.
# Usage: python fight_backdrop.py "<KIF Beta>" out.png singles|doubles "13,8,4,0" <selected>
import sys, os
from PIL import Image

root, out, mode = sys.argv[1], sys.argv[2], sys.argv[3]
move_types = [int(t) for t in sys.argv[4].split(",")]
sel = int(sys.argv[5])
G = lambda *p: os.path.join(root, "Graphics", *p)
W, H = 512, 384
img = Image.new("RGBA", (W, H), (0, 0, 0, 255))

def paste(im, x, y):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    layer.paste(im, (int(x), int(y)), im)
    img.alpha_composite(layer)

paste(Image.open(G("Battlebacks", "battlebg", "field.png")).convert("RGBA"), 0, 0)
base = Image.open(G("Battlebacks", "base", "field.png")).convert("RGBA")
paste(base, 384 - base.width // 2, 176 - base.height // 2)
pb = base.resize((int(base.width * 1.5), int(base.height * 1.5)), Image.NEAREST)
paste(pb, 78 - pb.width // 2, 374 - pb.height)

def cell(species):
    sheet = Image.open(G("Battlers", "spritesheets_autogen", "%d.png" % species)).convert("RGBA")
    c = sheet.crop(((species % 10) * 96, (species // 10) * 96, (species % 10) * 96 + 96, (species // 10) * 96 + 96))
    return c.resize((192, 192), Image.NEAREST)

def foe(species, cx, bottom):
    paste(cell(species), cx - 96, bottom - 192 + 30)

def mine(species, cx, bottom):
    paste(cell(species).transpose(Image.FLIP_LEFT_RIGHT), cx - 96, bottom - 192 + 24)

hp = Image.open(G("Pictures", "Battle", "overlay_hp.png")).convert("RGBA")
green = hp.crop((0, 0, hp.width, hp.height // 3))
yellow = hp.crop((0, hp.height // 3, hp.width, 2 * hp.height // 3))

def databox(name, x, y, base_x, frac, bar=None):
    paste(Image.open(G("Pictures", "Battle", name + ".png")).convert("RGBA"), x, y)
    bar = bar or green
    paste(bar.crop((0, 0, max(1, int(bar.width * frac)), bar.height)), x + base_x + 12, y + 40)

if mode == "singles":
    foe(130, 384, 176)
    mine(25, 128, 304)
    databox("databox_normal", W - 244, H - 176, 34, 0.82)
    databox("databox_normal_foe", 8, 0, 8, 0.55, yellow)
else:
    # foes: index 3 (behind, left) then index 1; ours: index 0 then index 2
    foe(95, 384 - 32, 176 - 16)
    foe(130, 384 + 48, 176)
    mine(25, 128 - 48, 304)
    mine(131, 128 + 32, 304 + 16)
    databox("databox_thin_foe", 8 + 12, 0 - 6, 8, 0.55, yellow)
    databox("databox_thin_foe", 8, 0 + 28, 8, 0.9)
    databox("databox_thin", W - 244 - 12, H - 176 - 18, 34, 0.82)
    databox("databox_thin", W - 244, H - 176 + 16, 34, 0.7)

# Fight menu: background, then the four move buttons coloured by type
paste(Image.open(G("Pictures", "Battle", "overlay_fight.png")).convert("RGBA"), 0, H - 96)
btn = Image.open(G("Pictures", "Battle", "cursor_fight.png")).convert("RGBA")
bw, bh = btn.width // 2, 46
for i, t in enumerate(move_types):
    sx = bw if i == sel else 0
    b = btn.crop((sx, t * bh, sx + bw, t * bh + bh))
    paste(b, 4 + (0 if i % 2 == 0 else bw - 4), H - 96 + 6 + (0 if i // 2 == 0 else bh - 4))
img.convert("RGB").save(out)
print("saved", out)
