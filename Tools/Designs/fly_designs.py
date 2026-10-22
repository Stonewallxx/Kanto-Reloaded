# Weather on the Fly Map (topic 22, part 3): base screens from KIF Beta's
# own Fly map (flymap_backdrop.py: BetterRegionMap, can_fly) plus the PIF-style
# parts each design adds (text in the map's own font, icons). The KR-style
# parts (hint, hover card, Now/Next pill) are drawn by fly_kr.rb on top.
# Writes wx/fly/<name>.png (512x384).
# Usage (from this folder): python fly_designs.py
import os, json, subprocess, sys
from PIL import Image, ImageDraw, ImageFont
ROOT = r"E:/Downloads/POKEMON/KIF Beta"
OUT = os.path.join("wx", "fly"); os.makedirs(OUT, exist_ok=True)
src = open("flymap_backdrop.py", encoding="utf8").read()
exec(src[src.index("FONT_FILES = "):src.index("#-------------------------------------------------------------------------------\n# Scene setup")])
WHITE, BLACK = (255, 255, 255, 255), (0, 0, 0, 255)
ICONS = os.path.join("wx", "icons")

NOW = "40,3:Rain:6;42,3:Rain:3;40,6:Rain:4;42,6:Rain:2;43,9:Storm:4;37,9:Sunny:5;35,10:Sunny:3;43,11:Fog:4;41,13:Fog:2;43,1:Snow:3;31,17:Sunny:6;36,15:Rain:2"
NEXT = "40,3:Storm:7;42,3:Rain:5;40,6:Rain:6;43,9:Rain:2;37,9:Sunny:4;35,10:Sunny:5;43,11:Fog:2;43,1:Snow:4;31,17:Sunny:6;34,10:Sunny:2"
CER, CEL = (40, 6), (37, 9)

def base(name, cursor, weather=None, visited=None):
    cmd = [sys.executable, "flymap_backdrop.py", ROOT, os.path.join(OUT, name + "_base.png"),
           "--cursor", "%d,%d" % cursor, "--player", "40,6", "--fly"]
    if weather: cmd += ["--weather", weather]
    if visited: cmd += ["--visited", visited]
    subprocess.run(cmd, check=True, capture_output=True)
    return Image.open(os.path.join(OUT, name + "_base.png")).convert("RGBA"), json.load(open(os.path.join(OUT, name + "_base.json")))

def icon(img, file, x, y, size):
    i = Image.open(os.path.join(ICONS, file + ".png")).convert("RGBA").resize((size, size), Image.NEAREST)
    img.alpha_composite(i, (x, y))

def icon_file(w, n):
    b = {"Rain": "mapRain", "Storm": "mapStorm", "Fog": "mapFog", "Sunny": "mapSun"}.get(w)
    if b: return "%s_%s" % (b, "heavy" if n >= 7 else ("medium" if n >= 4 else "light"))
    return {"Snow": "mapSnow"}.get(w, "mapClear")

def bar_right(img, text, wfile=None):
    # right-aligned in the bottom bar, where the point-of-interest text goes
    pbDrawTextPositions(img, [[text, 496, 354, 1, WHITE, BLACK]])
    if wfile:
        icon(img, wfile, 496 - text_width("system", text) - 30, 356, 26)

def top_right(img, text):
    pbDrawTextPositions(img, [[text, 496, 0, 1, WHITE, BLACK]])

def save(img, name): img.convert("RGB").save(os.path.join(OUT, name + ".png")); print("saved", name)

# 1 Recommended: PIF's own weather layer on the Fly map, Now / Next (Y), the place's weather in the bar
im, _ = base("f1_now", CER, NOW); bar_right(im, "Rain, Moderate", icon_file("Rain", 4)); top_right(im, "Weather: Now"); save(im, "F1_now")
im, _ = base("f1_next", CER, NEXT); bar_right(im, "Rain, Moderate", icon_file("Rain", 6)); top_right(im, "Weather: Next"); save(im, "F1_next")
# 2 The bar only: no icons on the map
im, _ = base("f2_cer", CER); bar_right(im, "Rain, Moderate", icon_file("Rain", 4)); save(im, "F2_cer")
im, _ = base("f2_cel", CEL); bar_right(im, "Sunny", icon_file("Sunny", 5)); save(im, "F2_cel")
# 3 A layer you switch on (Y): off, then on
im, _ = base("f3_off", CER); save(im, "F3_off")
im, _ = base("f3_on", CER, NOW); save(im, "F3_on")
# 4 The fly points become weather icons (towns with weather); routes stay plain
fly = json.load(open(os.path.join(OUT, "f3_off_base.json")))["fly_points"]
wtowns = {(40, 6): ("Rain", 4), (43, 9): ("Storm", 4), (37, 9): ("Sunny", 5), (36, 15): ("Rain", 2), (31, 17): ("Sunny", 6)}
names = ",".join(p["name"] for p in fly if tuple(p["tile"]) not in wtowns)
for nm, cur in [("F4_cer", CER), ("F4_cel", CEL)]:
    im, info = base(nm.lower(), cur, None, names)
    ox, oy = info["map_origin_on_screen"]
    for (tx, ty), (w, n) in wtowns.items():
        icon(im, icon_file(w, n), ox + 16 * tx - 8, oy + 16 * ty - 8, 32)
    if cur == CER: bar_right(im, "Rain, Moderate")
    else: bar_right(im, "Sunny")
    save(im, nm)
# 5 A hover card (drawn by fly_kr.rb) over the plain Fly map
im, _ = base("f5_cer", CER); save(im, "F5_cer")
im, _ = base("f5_cel", CEL); save(im, "F5_cel")
# Mix (his pick): design 1's layer with Now / Next, plus design 5's hover card (drawn by fly_kr.rb)
im, _ = base("fm_now", CER, NOW); top_right(im, "Weather: Now"); save(im, "FM_now")
im, _ = base("fm_next", CER, NEXT); top_right(im, "Weather: Next"); save(im, "FM_next")
