# Renders a map dumped by map_dump.rb (no events) to a PNG.
# Usage: python map_render.py "<KIF Beta>" map.json out.png [x0 y0 w h] (tiles)
import json, os, sys
from PIL import Image

AUTO = [
  [[27, 28, 33, 34], [5, 28, 33, 34], [27, 6, 33, 34], [5, 6, 33, 34],
   [27, 28, 33, 12], [5, 28, 33, 12], [27, 6, 33, 12], [5, 6, 33, 12]],
  [[27, 28, 11, 34], [5, 28, 11, 34], [27, 6, 11, 34], [5, 6, 11, 34],
   [27, 28, 11, 12], [5, 28, 11, 12], [27, 6, 11, 12], [5, 6, 11, 12]],
  [[25, 26, 31, 32], [25, 6, 31, 32], [25, 26, 31, 12], [25, 6, 31, 12],
   [15, 16, 21, 22], [15, 16, 21, 12], [15, 16, 11, 22], [15, 16, 11, 12]],
  [[29, 30, 35, 36], [29, 30, 11, 36], [5, 30, 35, 36], [5, 30, 11, 36],
   [39, 40, 45, 46], [5, 40, 45, 46], [39, 6, 45, 46], [5, 6, 45, 46]],
  [[25, 30, 31, 36], [15, 16, 45, 46], [13, 14, 19, 20], [13, 14, 19, 12],
   [17, 18, 23, 24], [17, 18, 11, 24], [41, 42, 47, 48], [5, 42, 47, 48]],
  [[37, 38, 43, 44], [37, 6, 43, 44], [13, 18, 19, 24], [13, 14, 43, 44],
   [37, 42, 43, 48], [17, 18, 47, 48], [13, 18, 43, 48], [1, 2, 7, 8]]
]

root, src, out = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(src))
w, h, zs = d["w"], d["h"], d["z"]
data = d["data"]

def find(folder, name):
    for ext in ("", ".png", ".PNG"):
        p = os.path.join(root, "Graphics", folder, name + ext)
        if os.path.isfile(p):
            return p
    return None

tileset = Image.open(find("Tilesets", d["tileset"])).convert("RGBA")
autos = []
for n in d["autotiles"]:
    p = find("Autotiles", n) if n else None
    autos.append(Image.open(p).convert("RGBA") if p else None)

cache = {}
def tile(tid):
    if tid in cache:
        return cache[tid]
    t = None
    if tid >= 384:
        i = tid - 384
        t = tileset.crop(((i % 8) * 32, (i // 8) * 32, (i % 8) * 32 + 32, (i // 8) * 32 + 32))
    elif tid >= 48:
        a = autos[tid // 48 - 1]
        if a is not None:
            t = Image.new("RGBA", (32, 32))
            if a.height <= 32:          # a single-tile autotile
                t = a.crop((0, 0, 32, 32))
            else:
                p = tid % 48
                for k, n in enumerate(AUTO[p // 8][p % 8]):
                    sx, sy = ((n - 1) % 6) * 16, ((n - 1) // 6) * 16
                    t.paste(a.crop((sx, sy, sx + 16, sy + 16)), ((k % 2) * 16, (k // 2) * 16))
    cache[tid] = t
    return t

x0, y0, tw, th = 0, 0, w, h
if len(sys.argv) > 4:
    x0, y0, tw, th = map(int, sys.argv[4:8])
img = Image.new("RGBA", (tw * 32, th * 32), (0, 0, 0, 255))
for z in range(zs):
    for y in range(y0, y0 + th):
        for x in range(x0, x0 + tw):
            tid = data[x + y * w + z * w * h]
            if tid == 0:
                continue
            t = tile(tid)
            if t is not None:
                img.alpha_composite(t, ((x - x0) * 32, (y - y0) * 32))
img.convert("RGB").save(out)
print("saved", out, img.size)
