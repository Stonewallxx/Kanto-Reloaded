"""Kanto Reloaded's sidebar icon: three Poke Ball designs on the real sidebar
render (01_ocean_sidebar_kr.png), at 1x and zoomed."""
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SHOTS = os.path.join(os.path.dirname(HERE), "kifs2")
TILE = (14, 42)                       # the first section's 15x15 tile

RED = (214, 52, 60)                   # the tile: a deeper red than Battles' (210, 80, 80)
BALL_RED = (238, 64, 64)
WHITE = (248, 248, 248)
INK = (28, 24, 30)


def ball(size, top, bottom, ink, button=WHITE):
    """A Poke Ball size x size: ink outline, top / bottom halves, a 1px band and a button."""
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    c = (size - 1) / 2.0
    r = size / 2.0
    for y in range(size):
        for x in range(size):
            d = ((x - c) ** 2 + (y - c) ** 2) ** 0.5
            if d > r - 0.15:
                continue
            if d > r - 1.2:
                col = ink
            elif abs(y - c) < 0.6:
                col = ink                          # the band
            else:
                col = top if y < c else bottom
            bd = max(abs(x - c), abs(y - c) * 1.0)
            if ((x - c) ** 2 + (y - c) ** 2) ** 0.5 <= 2.3:
                col = ink if ((x - c) ** 2 + (y - c) ** 2) ** 0.5 > 1.2 else button
            im.putpixel((x, y), col + (255,))
    return im


def tile(fill):
    im = Image.new("RGBA", (15, 15), (0, 0, 0, 0))
    ImageDraw.Draw(im).rounded_rectangle((0, 0, 14, 14), radius=3, fill=fill + (255,))
    return im


def icon(kind):
    if kind == "A":       # red tile, a red and white ball with a dark outline
        im = tile(RED)
        im.alpha_composite(ball(13, BALL_RED, WHITE, INK), (1, 1))
    elif kind == "B":     # no tile: the ball is the icon
        im = Image.new("RGBA", (15, 15), (0, 0, 0, 0))
        im.alpha_composite(ball(15, BALL_RED, WHITE, INK), (0, 0))
    else:                 # red tile, a white ball drawn like the letters
        im = tile(RED)
        im.alpha_composite(ball(13, WHITE, WHITE, RED, RED), (1, 1))
    return im


def main():
    base = Image.open(os.path.join(SHOTS, "01_ocean_sidebar_kr.png")).convert("RGBA")
    font = ImageFont.truetype(r"E:/Downloads/POKEMON/KIF Beta/Fonts/power green.ttf", 28)
    rows = []
    for kind, name in (("K", "Now"), ("A", "A: Red Tile, Red and White Ball"), ("B", "B: Ball Only"), ("C", "C: Red Tile, White Ball")):
        shot = base.copy()
        if kind != "K":
            # clear the old tile, then draw the new icon
            shot.paste(Image.new("RGBA", (15, 15), shot.getpixel((12, 49))), TILE)
            shot.alpha_composite(icon(kind), TILE)
        side = shot.crop((6, 36, 175, 160)).resize((169 * 3, 124 * 3), Image.NEAREST)
        zoom = shot.crop((10, 38, 34, 62)).resize((24 * 10, 24 * 10), Image.NEAREST)
        row = Image.new("RGBA", (side.width + zoom.width + 30, side.height + 44), (20, 20, 24, 255))
        ImageDraw.Draw(row).text((8, 4), name, font=font, fill=(240, 240, 240))
        row.alpha_composite(side, (0, 44))
        row.alpha_composite(zoom, (side.width + 20, 44 + (side.height - zoom.height) // 2))
        rows.append(row)
    sheet = Image.new("RGBA", (rows[0].width, sum(r.height for r in rows) + 8 * (len(rows) - 1)), (20, 20, 24, 255))
    y = 0
    for r in rows:
        sheet.alpha_composite(r, (0, y))
        y += r.height + 8
    sheet.save(os.path.join(HERE, "kr_icon_options.png"))
    print("ok")


main()
