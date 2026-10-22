import os
from PIL import Image, ImageDraw
src = open("mock_frames2.py", encoding="utf-8").read()
src = src[:src.index("STYLES = [")]
ns = {"__file__": os.path.abspath("mock_frames2.py")}
exec(compile(src, "mock_frames2.py", "exec"), ns)
window, text, KIF, THEMES, c = ns["window"], ns["text"], ns["KIF"], ns["THEMES"], ns["c"]

def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

CHARCOAL = (46, 46, 52)
SLATE = (52, 60, 74)

def panel_for(kind, t):
    p = c(t["panel"])[:3]
    if kind == "Now": return p
    if kind == "Charcoal": return CHARCOAL
    if kind == "Slate": return SLATE
    return mix((60, 64, 74), c(t["inner"])[:3], 0.18)     # Theme Slate: grey tinted by the Theme

def skin(kind, t):
    im = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, 47, 47), radius=6, fill=c(t["bg"]))
    d.rounded_rectangle((1, 1, 46, 46), radius=5, fill=c(t["inner"]))
    d.rounded_rectangle((3, 3, 44, 44), radius=4, fill=panel_for(kind, t) + (245,))
    return im

def scene(kind, theme):
    bg = Image.open(os.path.join(KIF, "Graphics", "Battlebacks", "battlebg", "bridge.png")).convert("RGBA")
    s = max(512 / bg.width, 384 / bg.height)
    bg = bg.resize((int(bg.width * s + .5), int(bg.height * s + .5)), Image.NEAREST)
    base = Image.new("RGBA", (512, 384)); base.alpha_composite(bg.crop((0, 0, 512, 384)))
    sk = skin(kind, THEMES[theme])
    window(base, sk, 320, 12, 180, 176); window(base, sk, 0, 288, 512, 96)
    d = ImageDraw.Draw(base)
    for i, item in enumerate(["Pokédex", "Pokémon", "Bag", "Save"]): text(d, 352, 26 + i * 38, item)
    d.polygon([(336, 34), (336, 50), (344, 42)], fill=(248, 248, 248))
    text(d, 24, 302, f"{kind}: {theme}"); text(d, 24, 336, "Welcome to Pokémon Infinite Fusion!")
    return base

kinds = ["Now", "Charcoal", "Slate", "Theme Slate"]
sheet = Image.new("RGBA", (3 * 512 + 16, 4 * 384 + 24), (20, 20, 24, 255))
for r, k in enumerate(kinds):
    for col, th in enumerate(THEMES):
        sheet.alpha_composite(scene(k, th), (col * 520, r * 392))
    scene(k, "Purple").save(f"D{r}_{k.replace(' ', '')}.png")
sheet.save("dark_panels.png"); sheet.resize((sheet.width // 2, sheet.height // 2), Image.LANCZOS).save("dark_panels_small.png"); print("ok")
