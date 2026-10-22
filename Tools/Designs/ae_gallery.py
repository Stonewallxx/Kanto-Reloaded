# The Area Encounters gallery images for Roadmap Designs: ae-1 (Grass and
# Fishing side by side, wide), ae-2..ae-5.
# Usage: python ae_gallery.py <render dir> <roadmap_page/img/designs>
import os, sys
from PIL import Image
src, out = sys.argv[1], sys.argv[2]
def shot(name): return Image.open(os.path.join(src, name + "@2x.png")).convert("RGB")
wide = Image.new("RGB", (2080, 768), (14, 20, 34))
wide.paste(shot("AE1_wild_link_list"), (0, 0))
wide.paste(shot("AE1b_wild_link_list_fishing"), (1056, 0))
wide.save(os.path.join(out, "ae-1.png"))
for n, name in [(2, "AE2_one_list"), (3, "AE3_icon_grid"), (4, "AE4_area_panel"), (5, "AE5_columns")]:
    shot(name).save(os.path.join(out, "ae-%d.png" % n))
print("ok")
