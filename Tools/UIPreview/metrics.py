"""Character advance widths and line heights for the game fonts, as mkxp-z renders
them (script font size x 0.9, floored). Writes metrics.json for the Ruby preview."""
import json, sys
from PIL import ImageFont

FONTS_DIR = sys.argv[1]
OUT = sys.argv[2]
FILES = {
    "Power Green": "power green.ttf",
    "Power Green Small": "power green small.ttf",
    "Power Green Narrow": "power green narrow.ttf",
}
SIZES = [14, 16, 18, 20, 22, 24, 25, 26, 27, 29, 32]
CHARS = [chr(c) for c in range(32, 127)] + list("éÉèàçùâêîôûëïüöäÄÖÜßñ…–—‹›×·’“”")

table = {}
for name, file in FILES.items():
    for size in SIZES:
        px = int(size * 0.9)
        font = ImageFont.truetype(FONTS_DIR + "/" + file, px)
        ascent, descent = font.getmetrics()
        table[f"{name}|{size}"] = {
            "px": px,
            "ascent": ascent,
            "height": ascent - descent,
            "advance": {ch: font.getlength(ch) for ch in CHARS},
        }
json.dump(table, open(OUT, "w", encoding="utf-8"), ensure_ascii=False)
print("wrote", len(table), "font sizes")
