import os
from PIL import Image, ImageDraw
src = open("mock_frames2.py", encoding="utf-8").read()
src = src[:src.index("STYLES = [")]
ns = {"__file__": os.path.abspath("mock_frames2.py")}
exec(compile(src, "mock_frames2.py", "exec"), ns)
window, text, KIF, THEMES, c, rr, base_skin = ns["window"], ns["text"], ns["KIF"], ns["THEMES"], ns["c"], ns["rr"], ns["skin"]

def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

def light_skin(style, t):
    im = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    acc = c(t["accent"])[:3]
    panel = mix((248, 248, 248), acc, 0.10)          # near-white, tinted by the Theme
    if style == "Light":
        rr(d, (0, 0, 47, 47), 6, c(t["border"]))
        rr(d, (1, 1, 46, 46), 5, c(t["inner"]))
        rr(d, (3, 3, 44, 44), 4, panel + (250,))
    else:  # Light Glass
        rr(d, (0, 0, 47, 47), 6, c(t["border"], 230))
        rr(d, (1, 1, 46, 46), 5, c(t["inner"]))
        rr(d, (3, 3, 44, 44), 4, panel + (200,))
        d.line((6, 3, 41, 3), fill=(255, 255, 255, 200))
    return im

def scene(style, theme):
    bg = Image.open(os.path.join(KIF, "Graphics", "Battlebacks", "battlebg", "bridge.png")).convert("RGBA")
    s = max(512 / bg.width, 384 / bg.height)
    bg = bg.resize((int(bg.width * s + 0.5), int(bg.height * s + 0.5)), Image.NEAREST)
    base = Image.new("RGBA", (512, 384)); base.alpha_composite(bg.crop((0, 0, 512, 384)))
    light = style.startswith("Light")
    sk = light_skin(style, THEMES[theme]) if light else base_skin(style, THEMES[theme])
    window(base, sk, 320, 12, 180, 176); window(base, sk, 0, 288, 512, 96)
    d = ImageDraw.Draw(base)
    for i, item in enumerate(["Pokédex", "Pokémon", "Bag", "Save"]): text(d, 352, 26 + i * 38, item, not light)
    d.polygon([(336, 34), (336, 50), (344, 42)], fill=(80, 80, 88) if light else (248, 248, 248))
    text(d, 24, 302, f"{style}: {theme}", not light); text(d, 24, 336, "Welcome to Pokémon Infinite Fusion!", not light)
    return base

styles = ["Glass", "Light", "Light Glass"]
sheet = Image.new("RGBA", (3 * 512 + 16, 3 * 384 + 16), (20, 20, 24, 255))
for r, st in enumerate(styles):
    for col, th in enumerate(THEMES):
        sheet.alpha_composite(scene(st, th), (col * 520, r * 392))
    scene(st, "Purple").save(f"L{r}_{st.replace(' ', '')}.png")
sheet.save("theme_frame_light.png"); print("ok")
