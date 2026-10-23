# Quality of Life tools: the party's battle sprites (KIF's base spritesheet,
# first frame, as Big Pokémon Icons shows them), trimmed to the Pokémon itself.
# Usage: python qa_assets.py "<KIF Beta>"   (writes art/<SPECIES>.png here)
import os, sys
from PIL import Image
G = os.path.join(sys.argv[1], "Graphics")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "art")
os.makedirs(OUT, exist_ok=True)
DEX = {"PIKACHU": 25, "PIDGEOT": 18, "GYARADOS": 130, "EEVEE": 133, "MACHOKE": 67, "GENGAR": 94,
       "CHANSEY": 113, "ALAKAZAM": 65, "SNORLAX": 143, "ESPEON": 196}     # the last four: Healing Moves' healers
for sp, n in DEX.items():
    sheet = Image.open(os.path.join(G, "CustomBattlers", "spritesheets", "spritesheets_base", "%d.png" % n)).convert("RGBA")
    frame = sheet.crop((0, 0, 96, 96))
    box = frame.getchannel("A").point(lambda a: 255 if a > 16 else 0).getbbox()
    art = frame.crop(box)
    art.save(os.path.join(OUT, sp + ".png"))
    print(sp, "frame 96 -> art", art.size)

def trimmed(img):
    box = img.getchannel("A").point(lambda a: 255 if a > 16 else 0).getbbox()
    return img.crop(box)

# a fusion for the party screen: Gengar's head on Machoke's body (KIF's
# generated sheet for head 94, tile 67 = the body's number)
sheet = Image.open(os.path.join(G, "Battlers", "spritesheets_autogen", "94.png")).convert("RGBA")
trimmed(sheet.crop(((67 % 10) * 96, (67 // 10) * 96, (67 % 10) * 96 + 96, (67 // 10) * 96 + 96))).save(os.path.join(OUT, "GENCHOKE.png"))
# an Egg, as Big Pokemon Icons shows it
trimmed(Image.open(os.path.join(G, "Battlers", "Eggs", "000.png")).convert("RGBA")).save(os.path.join(OUT, "EGG.png"))
print("GENCHOKE, EGG")
