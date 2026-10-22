# PIF's field-move cut-in (pbHiddenMoveAnimation, phase 3: the band open, the
# Pokemon centred) over Route 24 before the rain: hiddenMovebg.png (512x160) at
# y 112, the front sprite centred in it (clipped to the band), strobes streaming.
import random
from PIL import Image
G = r"E:/Downloads/POKEMON/KIF Beta/Graphics/"
random.seed(3)
scr = Image.open("route24_clear.png").convert("RGBA")
band = Image.new("RGBA", (512, 160))
band.alpha_composite(Image.open(G + "Pictures/hiddenMovebg.png").convert("RGBA"))
strobes = Image.open(G + "Pictures/hiddenMoveStrobes.png").convert("RGBA")
for i in range(15):
    s = strobes.crop((0, (i % 2) * 16, 52, (i % 2) * 16 + 16))
    if i % 2 == 1:   # z 0: behind the Pokemon
        band.alpha_composite(s, (random.randint(0, 511), 16 * (1 + random.randint(0, 160 // 16 - 3))))
sheet = Image.open(G + "CustomBattlers/spritesheets/spritesheets_base/25.png").convert("RGBA")
mon = sheet.crop((0, 0, 96, 96)).resize((288, 288), Image.NEAREST)
band.alpha_composite(mon, (256 - 144, 80 - 144)) if False else None
tmp = Image.new("RGBA", (512, 160)); tmp.alpha_composite(mon.crop((0, 64, 288, 224)), (256 - 144, 0))
band.alpha_composite(tmp)
for i in range(15):
    s = strobes.crop((0, (i % 2) * 16, 52, (i % 2) * 16 + 16))
    if i % 2 == 0:   # z 2: in front
        band.alpha_composite(s, (random.randint(0, 511), 16 * (1 + random.randint(0, 160 // 16 - 3))))
scr.alpha_composite(band, (0, 112))
scr.convert("RGB").save("cutin.png"); print("saved")
