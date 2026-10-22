# Ruins of Alph research lab (Map354) as a 512x384 backdrop: the researcher
# (BW (82)) facing down at tile (7,7), the player (Red) facing up below her.
import sys
from PIL import Image
C = r"E:/Downloads/POKEMON/KIF Beta/Graphics/Characters/"
def put(m, f, tx, ty, row, cell):
    s = Image.open(C + f).convert("RGBA").crop((0, row * cell, cell, row * cell + cell))
    m.alpha_composite(s, (tx * 32 + 16 - cell // 2, ty * 32 + 32 - cell))
for name, mapf, npc, ptile in [("lab", "m354.png", [("BW (82).png", 7, 7, 0, 64)], (7, 8)),
                               ("chamber", "m677.png", [], (9, 8))]:
    m = Image.open(mapf).convert("RGBA")
    for f, tx, ty, row, cell in npc: put(m, f, tx, ty, row, cell)
    put(m, "trainer_POKEMONTRAINER_Red.png", ptile[0], ptile[1], 3, 64)
    cx, cy = ptile[0] * 32 + 16, ptile[1] * 32 + 16
    out = Image.new("RGBA", (512, 384), (0, 0, 0, 255))
    # the game camera centres the player, clamped to the map's edges
    x0 = min(max(cx - 256, 0), m.width - 512); y0 = min(max(cy - 176, 0), m.height - 384)
    out.alpha_composite(m.crop((x0, y0, x0 + 512, y0 + 384)))
    out.convert("RGB").save(name + ".png"); print("saved", name)
