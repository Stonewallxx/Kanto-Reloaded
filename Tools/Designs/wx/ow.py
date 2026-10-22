# Overworld backdrops for the Weather System mockups (512x384):
#   route24_rain.png  Route 24 (map 8) in rain: the map darkened like PIF's rain
#                     tone, PIF's own rain sprites (Graphics/Weather/rain_*.png)
#                     scattered, the player (Red) facing down on the path.
#   route24_clear.png the same without rain.
import random
from PIL import Image, ImageEnhance
K = r"E:/Downloads/POKEMON/KIF Beta/Graphics/"
random.seed(7)

def scene(mapf, ptile, row=0):
    m = Image.open(mapf).convert("RGBA")
    s = Image.open(K + "Characters/trainer_POKEMONTRAINER_Red.png").convert("RGBA").crop((0, row * 64, 64, row * 64 + 64))
    m.alpha_composite(s, (ptile[0] * 32 + 16 - 32, ptile[1] * 32 + 32 - 64))
    cx, cy = ptile[0] * 32 + 16, ptile[1] * 32 + 16
    x0 = min(max(cx - 256, 0), m.width - 512); y0 = min(max(cy - 176, 0), m.height - 384)
    return m.crop((x0, y0, x0 + 512, y0 + 384))

clear = scene("m8.png", (19, 21))
clear.convert("RGB").save("route24_clear.png")
rain = clear.copy()
# PIF's rain tone: a cooler, darker screen
r, g, b, a = rain.split()
r = r.point(lambda v: int(v * 0.74)); g = g.point(lambda v: int(v * 0.78)); b = b.point(lambda v: min(255, int(v * 0.86) + 6))
rain = Image.merge("RGBA", (r, g, b, a))
drops = [Image.open(K + "Weather/rain_%d.png" % i).convert("RGBA") for i in (1, 2, 3, 4)]
for _ in range(70):
    d = random.choice(drops)
    rain.alpha_composite(d, (random.randint(-16, 512), random.randint(-64, 384)))
rain.convert("RGB").save("route24_rain.png")
print("saved")
