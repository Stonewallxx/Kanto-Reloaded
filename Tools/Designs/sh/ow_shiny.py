# Overworld scenes for Overworld Sparkle: Route 24, a shiny Abra (its follower
# sprite recoloured like ABRA_rel) and EBDX's own shiny sparkle pieces
# (Graphics/Animations/ebShiny1-3, ebStar).
import sys, colorsys
from PIL import Image, ImageFilter
sys.path.insert(0, "sh")
G = r"E:/Downloads/POKEMON/KIF Beta/Graphics/"
from palettes import recolor
A = G + "Animations/"
sh1, sh2, sh3, star = [Image.open(A + f + ".png").convert("RGBA") for f in ["ebShiny1", "ebShiny2", "ebShiny3", "ebStar"]]
fol = Image.open(G + "Characters/Followers/ABRA.png").convert("RGBA").crop((0, 64, 64, 128))
fol = recolor(fol, 160, 1.1, 1.0)
base = Image.open("wx/route24_clear.png").convert("RGBA")
X0, Y0 = 368, 512
tx, ty = 22, 23
fx, fy = tx * 32 - X0 + 16 - 32, ty * 32 - Y0 + 32 - 64          # sprite top-left
def scene(name, extra=None, with_mon=True, under=None):
    m = base.copy()
    if under: under(m)
    if with_mon: m.alpha_composite(fol, (fx, fy))
    if extra: extra(m)
    m.convert("RGB").save("sh/" + name + ".png"); print("saved", name)
def sparkles(m):
    for (dx, dy, img) in [(4, 4, sh3), (44, 14, sh1), (14, 40, sh1), (40, 46, sh2), (30, -2, sh2)]:
        m.alpha_composite(img, (fx + dx, fy + dy))
def burst(m):
    for (dx, dy, img) in [(-12, -6, sh3), (40, -10, sh3), (50, 30, sh1), (-6, 36, sh1), (20, -18, sh2), (58, 8, sh2), (14, 52, sh2), (34, 50, sh1)]:
        m.alpha_composite(img, (fx + dx, fy + dy))
def glow(m):
    a = fol.split()[3].point(lambda v: 255 if v > 0 else 0)
    g = a.filter(ImageFilter.MaxFilter(7))
    halo = Image.new("RGBA", fol.size, (255, 220, 110, 0)); halo.putalpha(g.point(lambda v: 210 if v else 0))
    m.alpha_composite(halo, (fx, fy))
def starmark(m):
    m.alpha_composite(star, (fx + 20, fy + 2))
scene("sp_sparkle", sparkles)
scene("sp_plain")
scene("sp_burst", burst)
scene("sp_glow", None, True, glow)
scene("sp_star", starmark)
scene("sp_off", None, False)
