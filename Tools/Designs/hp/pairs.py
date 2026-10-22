# Joins two @2x screens side by side (32 px gap, the roadmap's dark gap colour).
import sys
from PIL import Image
work, out = sys.argv[1], sys.argv[2]
for name, a, b in [p.split(":") for p in sys.argv[3:]]:
    A = Image.open(f"{work}/{a}@2x.png").convert("RGB"); B = Image.open(f"{work}/{b}@2x.png").convert("RGB")
    im = Image.new("RGB", (A.width + 32 + B.width, A.height), (10, 14, 24))
    im.paste(A, (0, 0)); im.paste(B, (A.width + 32, 0)); im.save(f"{out}/{name}.png"); print("pair", name, im.size)
