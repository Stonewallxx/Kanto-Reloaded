# Wild Link mockup assets: the overworld target scene (Route 24, Abra roaming
# in the grass, PIF's ? reaction above it), silhouettes for unseen species,
# full sprites cropped from KIF's base spritesheets.
from PIL import Image
G = r"E:/Downloads/POKEMON/KIF Beta/Graphics/"
def follower(sp, row, col=0):
    return Image.open(G + "Characters/Followers/%s.png" % sp).convert("RGBA").crop((col * 64, row * 64, col * 64 + 64, row * 64 + 64))
emo = Image.open(G + "Animations/029-Emotion01.png").convert("RGBA")
q = emo.crop((576 + 64, 40, 576 + 128, 112))       # the full ? bubble (frame 3)
ex = emo.crop((384 + 64, 232, 384 + 128, 304))     # the full ! bubble (frame 7)
q = q.crop(q.getbbox()); ex = ex.crop(ex.getbbox())
def scene(out, sp, tile, row, bubble):
    m = Image.open("wx/route24_clear.png").convert("RGBA")
    x0, y0 = 368, 512                                  # the camera on Route 24 (player 19,21)
    tx, ty = tile[0] * 32 - x0, tile[1] * 32 - y0
    m.alpha_composite(follower(sp, row), (tx + 16 - 32, ty + 32 - 64))
    if bubble is not None:
        m.alpha_composite(bubble, (tx + 16 - bubble.width // 2, ty + 32 - 64 - bubble.height + 14))
    m.convert("RGB").save(out); print("saved", out)
scene("wl/ow_curious.png", "ABRA", (22, 23), 1, q)
scene("wl/ow_skittish.png", "ABRA", (22, 23), 2, ex)
for sp in ["METAPOD", "BUNEARY"]:
    ic = Image.open(G + "Pokemon/Icons/%s.png" % sp).convert("RGBA").crop((0, 0, 64, 64))
    a = ic.split()[3]
    sil = Image.new("RGBA", ic.size, (12, 14, 22, 255)); sil.putalpha(a)
    sil.save("wl/%s_sil.png" % sp)
for sp, n in [("ABRA", 63), ("ODDISH", 43)]:
    sh = Image.open(G + "CustomBattlers/spritesheets/spritesheets_base/%d.png" % n).convert("RGBA").crop((0, 0, 96, 96))
    sh.save("wl/%s_full.png" % sp)
print("ok")
