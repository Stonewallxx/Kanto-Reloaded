# Shiny palette stand-ins for the mockups: KIF Beta's base sprites recoloured
# by hue / saturation / value shifts (outlines, whites and near-greys kept),
# like HR's role-based recolours. Writes sh/<name>.png (96x96) and icons.
import colorsys
from PIL import Image
G = r"E:/Downloads/POKEMON/KIF Beta/Graphics/"
def load(n): return Image.open(G + "CustomBattlers/spritesheets/spritesheets_base/%d.png" % n).convert("RGBA").crop((0, 0, 96, 96))
def icon(sp): return Image.open(G + "Pokemon/Icons/%s.png" % sp).convert("RGBA").crop((0, 0, 64, 64))
def recolor(im, dh, ds=1.0, dv=1.0):
    out = im.copy(); px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a == 0: continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if s < 0.12 or v < 0.15: continue          # outlines, whites, greys stay
            h = (h + dh / 360.0) % 1.0; s = min(1, s * ds); v = min(1, v * dv)
            rr, gg, bb = colorsys.hsv_to_rgb(h, s, v)
            px[x, y] = (int(rr * 255), int(gg * 255), int(bb * 255), a)
    return out
SETS = {"LAPRAS": (131, [("base", 0, 1, 1), ("pif", 60, 1.0, 1.0), ("rel", -95, 1.15, 1.0), ("rel2", 150, 1.2, 1.05), ("wild", 200, 1.3, 0.95)]),
        "GENGAR": (94, [("base", 0, 1, 1), ("pif", -40, 1.0, 1.1), ("rel", 110, 1.1, 1.0), ("rel2", 200, 1.2, 1.0)]),
        "ABRA": (63, [("base", 0, 1, 1), ("rel", 160, 1.1, 1.0)]),
        "GYARADOS": (130, [("base", 0, 1, 1), ("pif", 150, 1.1, 1.0)]),
        "PIKACHU": (25, [("base", 0, 1, 1), ("rel", 120, 1.0, 1.0)]),
        "ODDISH": (43, [("base", 0, 1, 1), ("rel", 170, 1.1, 1.0)]),
        "MAGIKARP": (129, [("base", 0, 1, 1), ("pif", 40, 1.0, 1.0)]),
        "ZUBAT": (41, [("base", 0, 1, 1), ("wild", 140, 1.2, 1.0)])}
for sp, (n, vs) in SETS.items():
    base = load(n); ic = icon(sp)
    for name, dh, ds, dv in vs:
        recolor(base, dh, ds, dv).save("sh/%s_%s.png" % (sp, name))
        recolor(ic, dh, ds, dv).save("sh/%s_%s_icon.png" % (sp, name))
print("ok")
