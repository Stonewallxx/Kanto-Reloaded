"""Mockups of Theme frames: 48x48 Essentials skins drawn from a theme's
colours, shown as a menu window and a speech box over a battle backdrop."""
import os
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.dirname(os.path.abspath(__file__))
KIF = r"E:/Downloads/POKEMON/KIF Beta"
FONT = ImageFont.truetype(os.path.join(KIF, "Fonts", "power green.ttf"), 26)

THEMES = {
    "Ocean Blue": {"bg": "08111f", "panel": "0f1b30", "border": "24406e", "inner": "4a78c0", "line": "1a2c4c", "accent": "6fb2ff"},
    "Kanto Red": {"bg": "1a0b0b", "panel": "241010", "border": "6b1f1f", "inner": "b03a3a", "line": "3a1616", "accent": "ff6b6b"},
    "Thunder Yellow": {"bg": "151305", "panel": "201d08", "border": "6a5c14", "inner": "c8ac28", "line": "34300e", "accent": "ffe03c"},
}


def rgb(h, a=255):
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def rounded(d, box, r, fill):
    d.rounded_rectangle(box, radius=r, fill=fill)


def skin(style, t):
    """A 48x48 skin: 16px corners and edges around a 16px centre."""
    im = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if style == "Clean":
        rounded(d, (0, 0, 47, 47), 6, rgb(t["bg"]))            # dark outline
        rounded(d, (1, 1, 46, 46), 5, rgb(t["inner"]))         # 2px theme border
        rounded(d, (3, 3, 44, 44), 4, rgb(t["panel"], 245))    # panel
    elif style == "Bold":
        rounded(d, (0, 0, 47, 47), 4, rgb(t["bg"]))
        rounded(d, (1, 1, 46, 46), 3, rgb(t["inner"]))         # thick band
        d.line((3, 2, 44, 2), fill=rgb(t["accent"]))            # highlight on its top
        rounded(d, (5, 5, 42, 42), 3, rgb(t["border"]))        # band's inner shadow
        rounded(d, (6, 6, 41, 41), 3, rgb(t["panel"], 250))
    else:  # "Thin"
        rounded(d, (0, 0, 47, 47), 6, rgb(t["accent"], 255))  # 1px accent edge
        rounded(d, (1, 1, 46, 46), 5, rgb(t["panel"], 225))   # see-through panel
        d.rounded_rectangle((2, 2, 45, 45), radius=4, outline=rgb(t["border"]), width=1)
    return im


def window(base, sk, x, y, w, h):
    """Nine-slice the skin onto base (edges and centre tiled)."""
    parts = {}
    for cy, ry in enumerate((0, 16, 32)):
        for cx, rx in enumerate((0, 16, 32)):
            parts[(cx, cy)] = sk.crop((rx, ry, rx + 16, ry + 16))
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    for yy in range(y + 16, y + h - 16, 16):
        for xx in range(x + 16, x + w - 16, 16):
            layer.paste(parts[(1, 1)], (xx, yy))
    for xx in range(x + 16, x + w - 16, 16):
        layer.paste(parts[(1, 0)], (xx, y))
        layer.paste(parts[(1, 2)], (xx, y + h - 16))
    for yy in range(y + 16, y + h - 16, 16):
        layer.paste(parts[(0, 1)], (x, yy))
        layer.paste(parts[(2, 1)], (x + w - 16, yy))
    layer.paste(parts[(0, 0)], (x, y))
    layer.paste(parts[(2, 0)], (x + w - 16, y))
    layer.paste(parts[(0, 2)], (x, y + h - 16))
    layer.paste(parts[(2, 2)], (x + w - 16, y + h - 16))
    base.alpha_composite(layer)


def text(d, x, y, s, light=True):
    main, shadow = ((248, 248, 248), (72, 80, 88)) if light else ((80, 80, 88), (160, 160, 168))
    for dx, dy in ((2, 0), (0, 2), (2, 2)):
        d.text((x + dx, y + dy), s, font=FONT, fill=shadow)
    d.text((x, y), s, font=FONT, fill=main)


def scene(style, theme):
    bg = Image.open(os.path.join(KIF, "Graphics", "Battlebacks", "battlebg", "bridge.png")).convert("RGBA")
    scale = max(512 / bg.width, 384 / bg.height)
    bg = bg.resize((int(bg.width * scale + 0.5), int(bg.height * scale + 0.5)), Image.NEAREST)
    base = Image.new("RGBA", (512, 384), (40, 40, 40, 255))
    base.alpha_composite(bg.crop((0, 0, 512, 384)))
    sk = skin(style, THEMES[theme])
    window(base, sk, 320, 12, 180, 176)                       # the pause menu (Global Frame)
    window(base, sk, 0, 288, 512, 96)                         # a text box (Speech Frame: Theme)
    d = ImageDraw.Draw(base)
    for i, item in enumerate(["Pokédex", "Pokémon", "Bag", "Save"]):
        text(d, 352, 26 + i * 38, item)
    d.polygon([(336, 34), (336, 50), (344, 42)], fill=(248, 248, 248))
    text(d, 24, 302, "Welcome to the world of")
    text(d, 24, 336, "Pokémon Infinite Fusion!")
    return base, sk


def main():
    styles = ["Clean", "Bold", "Thin"]
    themes = list(THEMES)
    sheet = Image.new("RGBA", (len(themes) * 512 + (len(themes) - 1) * 8, len(styles) * 384 + (len(styles) - 1) * 8), (20, 20, 24, 255))
    for r, st in enumerate(styles):
        for c, th in enumerate(themes):
            sc, sk = scene(st, th)
            sheet.alpha_composite(sc, (c * 520, r * 392))
            sk.resize((192, 192), Image.NEAREST).save(os.path.join(OUT, f"skin_{st}_{th.replace(' ', '')}.png"))
        sc, _ = scene(st, "Ocean Blue")
        sc.save(os.path.join(OUT, f"F{r + 1}_{st}.png"))
    sheet.save(os.path.join(OUT, "theme_frames.png"))
    print("ok")


main()
