"""More Theme frame variants, next to Clean: each a 48x48 PIF skin drawn from
a theme's colours, shown as the pause menu and a text box."""
import os
from PIL import Image, ImageDraw

src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "mock_frames.py"), encoding="utf-8").read()
ns = {"__file__": os.path.join(os.path.dirname(os.path.abspath(__file__)), "mock_frames.py")}
exec(compile(src.replace("\nmain()\n", "\n"), "mock_frames.py", "exec"), ns)
window, text, KIF, OUT = ns["window"], ns["text"], ns["KIF"], ns["OUT"]

THEMES = {
    "Purple": {"bg": "0e0a17", "panel": "160f24", "border": "3a2b5c", "inner": "6a55a0", "line": "2a1f44", "accent": "b48cff"},
    "Ocean Blue": {"bg": "08111f", "panel": "0f1b30", "border": "24406e", "inner": "4a78c0", "line": "1a2c4c", "accent": "6fb2ff"},
    "Thunder Yellow": {"bg": "151305", "panel": "201d08", "border": "6a5c14", "inner": "c8ac28", "line": "34300e", "accent": "ffe03c"},
}


def c(h, a=255):
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def rr(d, box, r, fill=None, outline=None, width=1):
    d.rounded_rectangle(box, radius=r, fill=fill, outline=outline, width=width)


def skin(style, t):
    im = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if style == "Clean":                         # the current one
        rr(d, (0, 0, 47, 47), 6, c(t["bg"]))
        rr(d, (1, 1, 46, 46), 5, c(t["inner"]))
        rr(d, (3, 3, 44, 44), 4, c(t["panel"], 245))
    elif style == "Accent":                      # Clean with the bright accent border
        rr(d, (0, 0, 47, 47), 6, c(t["bg"]))
        rr(d, (1, 1, 46, 46), 5, c(t["accent"]))
        rr(d, (3, 3, 44, 44), 4, c(t["panel"], 245))
    elif style == "Double":                      # border, a gap, then a thin inner line
        rr(d, (0, 0, 47, 47), 6, c(t["bg"]))
        rr(d, (1, 1, 46, 46), 5, c(t["inner"]))
        rr(d, (3, 3, 44, 44), 4, c(t["panel"], 245))
        rr(d, (5, 5, 42, 42), 3, outline=c(t["border"]))
    elif style == "Glass":                       # Clean's border, a see-through panel
        rr(d, (0, 0, 47, 47), 6, c(t["bg"], 230))
        rr(d, (1, 1, 46, 46), 5, c(t["inner"]))
        rr(d, (3, 3, 44, 44), 4, c(t["panel"], 190))
        d.line((6, 3, 41, 3), fill=c(t["accent"], 140))      # a glint along the top
    elif style == "Retro":                       # square, notched corners, like the GBA games
        d.rectangle((1, 0, 46, 47), fill=c(t["bg"]))
        d.rectangle((0, 1, 47, 46), fill=c(t["bg"]))
        d.rectangle((2, 1, 45, 46), fill=c(t["inner"]))
        d.rectangle((1, 2, 46, 45), fill=c(t["inner"]))
        d.rectangle((3, 3, 44, 44), fill=c(t["accent"]))
        d.rectangle((4, 4, 43, 43), fill=c(t["panel"], 250))
    elif style == "Soft":                        # big rounding, a soft lit edge
        rr(d, (0, 0, 47, 47), 9, c(t["bg"]))
        rr(d, (1, 1, 46, 46), 8, c(t["border"]))
        rr(d, (2, 2, 45, 45), 7, c(t["inner"]))
        rr(d, (3, 3, 44, 44), 6, c(t["panel"], 245))
        d.line((9, 2, 38, 2), fill=c(t["accent"]))           # light along the top
    elif style == "Banner":                      # a theme-coloured band along the top
        rr(d, (0, 0, 47, 47), 6, c(t["bg"]))
        rr(d, (1, 1, 46, 46), 5, c(t["inner"]))
        rr(d, (3, 3, 44, 44), 4, c(t["panel"], 245))
        d.rectangle((3, 3, 44, 6), fill=c(t["border"]))
        d.line((3, 7, 44, 7), fill=c(t["accent"], 200))
    return im


def scene(style, theme):
    bg = Image.open(os.path.join(KIF, "Graphics", "Battlebacks", "battlebg", "bridge.png")).convert("RGBA")
    s = max(512 / bg.width, 384 / bg.height)
    bg = bg.resize((int(bg.width * s + 0.5), int(bg.height * s + 0.5)), Image.NEAREST)
    base = Image.new("RGBA", (512, 384))
    base.alpha_composite(bg.crop((0, 0, 512, 384)))
    sk = skin(style, THEMES[theme])
    window(base, sk, 320, 12, 180, 176)
    window(base, sk, 0, 288, 512, 96)
    d = ImageDraw.Draw(base)
    for i, item in enumerate(["Pokédex", "Pokémon", "Bag", "Save"]):
        text(d, 352, 26 + i * 38, item)
    d.polygon([(336, 34), (336, 50), (344, 42)], fill=(248, 248, 248))
    text(d, 24, 302, f"{style}: {theme}")
    text(d, 24, 336, "Welcome to Pokémon Infinite Fusion!")
    return base


STYLES = ["Clean", "Accent", "Double", "Glass", "Retro", "Soft", "Banner"]
themes = list(THEMES)
sheet = Image.new("RGBA", (3 * 512 + 16, len(STYLES) * 384 + (len(STYLES) - 1) * 8), (20, 20, 24, 255))
for r, st in enumerate(STYLES):
    for col, th in enumerate(themes):
        sheet.alpha_composite(scene(st, th), (col * 520, r * 392))
    scene(st, "Purple").save(os.path.join(OUT, f"V{r}_{st}.png"))
sheet.save(os.path.join(OUT, "theme_frame_variants.png"))
sheet.resize((sheet.width // 2, sheet.height // 2), Image.LANCZOS).save(os.path.join(OUT, "theme_frame_variants_small.png"))
print("ok")
