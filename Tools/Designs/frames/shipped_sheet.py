import os, importlib.util
from PIL import Image, ImageDraw
spec = importlib.util.spec_from_file_location("m", "mock_frames.py")
src = open("mock_frames.py", encoding="utf-8").read().replace("\nmain()\n", "\n")
ns = {"__file__": os.path.abspath("mock_frames.py")}
exec(compile(src, "mock_frames.py", "exec"), ns)
skins = r"E:/Downloads/POKEMON/KIF Beta/Mods/KantoReloaded/Graphics/Windowskins"
names = ["Base", "Purple", "Ocean Blue", "Forest", "Kanto Red", "Ember Orange", "Aqua Cyan", "Sakura", "Thunder Yellow", "Midnight"]
cells = []
for n in names:
    sk = Image.open(os.path.join(skins, f"Theme {n}.png")).convert("RGBA")
    bg = Image.open(os.path.join(ns["KIF"], "Graphics", "Battlebacks", "battlebg", "bridge.png")).convert("RGBA")
    s = max(512 / bg.width, 384 / bg.height); bg = bg.resize((int(bg.width * s + .5), int(bg.height * s + .5)))
    base = Image.new("RGBA", (512, 384)); base.alpha_composite(bg.crop((0, 0, 512, 384)))
    ns["window"](base, sk, 320, 12, 180, 176); ns["window"](base, sk, 0, 288, 512, 96)
    d = ImageDraw.Draw(base)
    for i, item in enumerate(["Pokédex", "Pokémon", "Bag", "Save"]): ns["text"](d, 352, 26 + i * 38, item)
    ns["text"](d, 24, 302, f"Theme: {n}"); ns["text"](d, 24, 336, "Welcome to Pokémon Infinite Fusion!")
    cells.append(base.resize((256, 192), Image.LANCZOS))
sheet = Image.new("RGBA", (5 * 260, 2 * 196), (20, 20, 24, 255))
for i, c in enumerate(cells): sheet.alpha_composite(c, ((i % 5) * 260, (i // 5) * 196))
sheet.save("shipped_theme_frames.png"); print("ok")
