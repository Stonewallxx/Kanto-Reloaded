# Area Encounters mockup assets: silhouettes (as Wild Link's, wl/assets.py)
# for the species Route 24's player hasn't seen.
# Usage: python ae_assets.py "<KIF Beta>"   (writes ae/<SPECIES>_sil.png here)
import os, sys
from PIL import Image
G = os.path.join(sys.argv[1], "Graphics")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ae")
os.makedirs(OUT, exist_ok=True)
for sp in ["METAPOD", "POLIWHIRL", "GYARADOS"]:
    ic = Image.open(os.path.join(G, "Pokemon", "Icons", sp + ".png")).convert("RGBA").crop((0, 0, 64, 64))
    sil = Image.new("RGBA", ic.size, (12, 14, 22, 255))
    sil.putalpha(ic.split()[3])
    sil.save(os.path.join(OUT, sp + "_sil.png"))
print("ok")
