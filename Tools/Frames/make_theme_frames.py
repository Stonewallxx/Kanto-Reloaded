"""Draws the Theme frames: 48x48 windowskins for every Theme (Core/UI/Palette.rb)
in each Theme Mode (picked 2026-10-17):

  Dark    "Theme <theme>": a dark outline, a 2px border in the theme's main
          colour, its panel colour inside (the "Clean" mockup)
  Glass   Dark's border around a see-through panel, a glint on top
  Light   a near-white panel tinted by the theme, its border
  Frost   Light, see-through, a white glint on top

Run it after changing a theme's colours:
  python Tools/Frames/make_theme_frames.py
It writes Graphics/Windowskins/Theme <mode> <theme>.png ("Theme <theme>.png"
for Dark): PIF's 48x48 skins, 16px corners and edges around a 16px centre.
PIF picks white or dark text from the skin's centre, so the light ones get
dark text.
"""
import os, re
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PALETTE = os.path.join(ROOT, "Core", "UI", "Palette.rb")
OUT = os.path.join(ROOT, "Graphics", "Windowskins")
LOOKS = ["", "Glass", "Light", "Frost"]


def themes():
    text = open(PALETTE, encoding="utf-8").read()
    out = {}
    for name, body in re.findall(r'"([^"]+)"\s*=>\s*\{([^}]*:bg\s*=>[^}]*)\}', text):
        cols = dict(re.findall(r':(\w+)\s*=>\s*"([0-9a-fA-F]{6})"', body))
        out[name] = {k: tuple(int(v[i:i + 2], 16) for i in (0, 2, 4)) for k, v in cols.items()}
    base = re.search(r"BASE = \{(.*?)\}\.freeze", text, re.S).group(1)
    b = {k: tuple(int(x) for x in v.split(",")) for k, v in re.findall(r":(\w+)\s*=>\s*\[([\d,\s]+)\]", base)}
    # Base is KIF Settings' own colours: its filled-bar colour is the border
    out["Base"] = {"bg": b["bg"], "panel": b["panel"], "inner": b["segon"], "border": b["line"], "accent": b["acc"]}
    return out


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def skin(look, t):
    im = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    light = look in ("Light", "Frost")
    glass = look in ("Glass", "Frost")
    outline = t["border"] if light else t["bg"]
    panel = mix((248, 248, 248), t["accent"], 0.10) if light else t["panel"]
    d.rounded_rectangle((0, 0, 47, 47), radius=6, fill=outline + ((230,) if glass else (255,)))   # outline
    d.rounded_rectangle((1, 1, 46, 46), radius=5, fill=t["inner"] + (255,))                       # 2px border
    alpha = (200 if light else 190) if glass else (250 if light else 245)
    d.rounded_rectangle((3, 3, 44, 44), radius=4, fill=panel + (alpha,))                           # panel
    if glass:                                                                                      # a glint along the top
        d.line((6, 3, 41, 3), fill=(255, 255, 255, 200) if light else t["accent"] + (140,))
    return im


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, cols in themes().items():
        for look in LOOKS:
            file = f"Theme {look + ' ' if look else ''}{name}.png"
            skin(look, cols).save(os.path.join(OUT, file))
            print("wrote", file)


main()
