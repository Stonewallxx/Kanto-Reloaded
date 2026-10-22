"""Replays recorded RGSS drawing calls the way mkxp-z draws them, with the game's
real fonts, and writes a 512x384 PNG (plus a 2x copy) per screen state.

mkxp-z rules reproduced (measured from in-game screenshots):
  - fonts render at int(script size * 0.9) pixels;
  - draw_text puts the top of the line (the ascent line) at the rect's top:
    it does not centre vertically (measured for rect heights 22, 28 and 32).
    Horizontally it aligns by advance width and squeezes text wider than
    the rect;
  - fill_rect replaces pixels; blt and text blend over them.
"""
import json, sys, glob, os
from PIL import Image, ImageFont, ImageDraw

FONTS_DIR, WORK = sys.argv[1], sys.argv[2]
FILES = {"Power Green": "power green.ttf", "Power Green Small": "power green small.ttf",
         "Power Green Narrow": "power green narrow.ttf"}
_fonts = {}

def font(name, size):
    key = (name, size)
    if key not in _fonts:
        _fonts[key] = ImageFont.truetype(os.path.join(FONTS_DIR, FILES[name]), int(size * 0.9))
    return _fonts[key]

def draw_text(img, x, y, w, h, text, align, fname, fsize, color):
    if not text or w <= 0:
        return
    f = font(fname, fsize)
    ascent, descent = f.getmetrics()
    line_h = ascent - descent
    adv = int(round(f.getlength(text)))
    layer = Image.new("RGBA", (max(adv, 1) + 4, line_h + 4), (0, 0, 0, 0))
    ImageDraw.Draw(layer).text((0, 0), text, font=f, fill=tuple(color))
    layer = layer.crop((0, 0, max(adv, 1), line_h))
    if adv > w:                       # mkxp-z squeezes text that doesn't fit
        layer = layer.resize((w, line_h), Image.NEAREST)
        adv = w
    ax = x
    if align == 1:
        ax += (w - adv) // 2
    elif align == 2:
        ax += w - adv
    ax = max(ax, x)
    ay = y
    img.alpha_composite(layer, (ax, ay)) if ax >= 0 and ay >= 0 else paste_clipped(img, layer, ax, ay)

def paste_clipped(img, layer, x, y):
    tmp = Image.new("RGBA", img.size, (0, 0, 0, 0))
    tmp.paste(layer, (x, y))
    img.alpha_composite(tmp)

def build(bitmaps, bid, cache):
    if bid in cache:
        return cache[bid]
    b = bitmaps[bid]
    img = Image.new("RGBA", (b["w"], b["h"]), (0, 0, 0, 0))
    for op in b["ops"]:
        kind = op[0]
        if kind == "clear":
            img = Image.new("RGBA", (b["w"], b["h"]), (0, 0, 0, 0))
        elif kind == "fill":
            _, x, y, w, h, c = op
            if w > 0 and h > 0:
                img.paste(Image.new("RGBA", (w, h), tuple(c)), (x, y))
        elif kind == "text":
            _, x, y, w, h, text, align, fname, fsize, color = op
            draw_text(img, x, y, w, h, text, align, fname, fsize, color)
        elif kind == "blt":
            _, x, y, src, sx, sy, sw, sh = op
            part = build(bitmaps, str(src), cache).crop((sx, sy, sx + sw, sy + sh))
            paste_clipped(img, part, x, y)
        elif kind == "file":                  # Bitmap.new(path): an image file
            img = Image.open(op[1]).convert("RGBA")
        elif kind == "sblt":                  # stretch_blt
            _, x, y, w, h, src, sx, sy, sw, sh = op[:10]
            opacity = op[10] if len(op) > 10 else 255
            if w > 0 and h > 0 and sw > 0 and sh > 0:
                part = build(bitmaps, str(src), cache).crop((sx, sy, sx + sw, sy + sh)).resize((w, h), Image.NEAREST)
                if opacity < 255:
                    a = part.getchannel("A").point(lambda v: v * opacity // 255)
                    part = part.copy()
                    part.putalpha(a)
                paste_clipped(img, part, x, y)
    cache[bid] = img
    return img

for path in sorted(glob.glob(os.path.join(WORK, "*.json"))):
    if path.endswith("metrics.json"):
        continue
    data = json.load(open(path, encoding="utf-8"))
    screen = Image.new("RGBA", (512, 384), (0, 0, 0, 255))
    cache = {}
    for i, s in sorted(enumerate(data["sprites"]), key=lambda t: (t[1]["z"], t[0])):
        if not s["visible"]:
            continue
        img = build(data["bitmaps"], str(s["bitmap"]), cache)
        src = s.get("src")
        if src and src[2] > 0 and src[3] > 0:      # the part of the bitmap the sprite shows
            img = img.crop((src[0], src[1], src[0] + src[2], src[1] + src[3]))
        zx, zy = s.get("zoom", [1.0, 1.0])
        if (zx, zy) != (1.0, 1.0):                  # zoomed about its origin (ox, oy)
            img = img.resize((max(1, round(img.width * zx)), max(1, round(img.height * zy))), Image.NEAREST)
        col = s.get("color", [0, 0, 0, 0])
        if col[3] > 0:                              # Sprite#color: blended over it by its alpha (255: a silhouette)
            k = col[3] / 255.0
            r, g, b, a = img.split()
            r, g, b = [ch.point(lambda v, t=t: round(v + (t - v) * k)) for ch, t in ((r, col[0]), (g, col[1]), (b, col[2]))]
            img = Image.merge("RGBA", (r, g, b, a))
        if s["opacity"] < 255:
            alpha = img.getchannel("A").point(lambda a: a * s["opacity"] // 255)
            img = img.copy(); img.putalpha(alpha)
        paste_clipped(screen, img, s["x"] - round(s.get("ox", 0) * zx), s["y"] - round(s.get("oy", 0) * zy))
    out = path[:-5] + ".png"
    screen.save(out)
    screen.resize((1024, 768), Image.NEAREST).save(path[:-5] + "@2x.png")
    print("rendered", os.path.basename(out))
