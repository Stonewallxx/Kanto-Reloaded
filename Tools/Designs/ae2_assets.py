# Area Encounters, bigger sprites: each species' battle sprite (KIF's base
# spritesheet, first frame, as Big Pokémon Icons shows it) trimmed to the
# Pokémon itself, plus a silhouette for the unseen ones.
# Usage: python ae2_assets.py "<KIF Beta>"   (writes ae2/<SPECIES>.png and _sil.png here)
import os, sys
from PIL import Image
G = os.path.join(sys.argv[1], "Graphics")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ae2")
os.makedirs(OUT, exist_ok=True)
DEX = {"ABRA": 63, "CATERPIE": 10, "PIDGEY": 16, "WEEDLE": 13, "ODDISH": 43, "BELLSPROUT": 69, "KAKUNA": 14,
       "METAPOD": 11, "PSYDUCK": 54, "SLOWPOKE": 79, "MAGIKARP": 129, "POLIWAG": 60, "GOLDEEN": 118,
       "POLIWHIRL": 61, "GYARADOS": 130}
for sp, n in DEX.items():
    sheet = Image.open(os.path.join(G, "CustomBattlers", "spritesheets", "spritesheets_base", "%d.png" % n)).convert("RGBA")
    frame = sheet.crop((0, 0, 96, 96))
    box = frame.getchannel("A").point(lambda a: 255 if a > 16 else 0).getbbox()
    art = frame.crop(box)
    art.save(os.path.join(OUT, sp + ".png"))
    sil = Image.new("RGBA", art.size, (12, 14, 22, 255))
    sil.putalpha(art.getchannel("A"))
    sil.save(os.path.join(OUT, sp + "_sil.png"))
    print(sp, "frame 96 -> art", art.size)
