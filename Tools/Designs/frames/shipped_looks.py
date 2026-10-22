import os
from PIL import Image, ImageDraw
src = open("mock_frames.py", encoding="utf-8").read().replace("\nmain()\n", "\n")
ns = {"__file__": os.path.abspath("mock_frames.py")}
exec(compile(src, "mock_frames.py", "exec"), ns)
skins = r"E:/Downloads/POKEMON/KIF Beta/Mods/KantoReloaded/Graphics/Windowskins"
looks = ["", "Glass", "Light", "Frost"]
themes = ["Purple", "Ocean Blue", "Forest", "Kanto Red", "Thunder Yellow"]
bg0 = Image.open(os.path.join(ns["KIF"], "Graphics", "Battlebacks", "battlebg", "bridge.png")).convert("RGBA")
s = max(512 / bg0.width, 384 / bg0.height); bg0 = bg0.resize((int(bg0.width * s + .5), int(bg0.height * s + .5)))
sheet = Image.new("RGBA", (5 * 260, 4 * 196), (20, 20, 24, 255))
for r, look in enumerate(looks):
    for col, th in enumerate(themes):
        name = f"Theme {look + ' ' if look else ''}{th}"
        sk = Image.open(os.path.join(skins, name + ".png")).convert("RGBA")
        base = Image.new("RGBA", (512, 384)); base.alpha_composite(bg0.crop((0, 0, 512, 384)))
        ns["window"](base, sk, 320, 12, 180, 176); ns["window"](base, sk, 0, 288, 512, 96)
        light = look in ("Light", "Frost")
        d = ImageDraw.Draw(base)
        for i, item in enumerate(["Pokédex", "Pokémon", "Bag", "Save"]): ns["text"](d, 352, 26 + i * 38, item, not light)
        ns["text"](d, 24, 302, f"{'Theme ' + look if look else 'Theme'}: {th}", not light)
        ns["text"](d, 24, 336, "Welcome to Pokémon Infinite Fusion!", not light)
        sheet.alpha_composite(base.resize((256, 192), Image.LANCZOS), (col * 260, r * 196))
sheet.save("shipped_theme_looks.png"); print("ok")
