# Builds KIF Beta's party screen (PIF 6.8.2 / Essentials v19 PokemonParty_Scene)
# for UI mockups: the six panels, the Cancel button, the help window, and
# either the command window (pbShowCommands) or the message box (pbDisplay).
# Placement follows KIF Beta's own code, line by line:
#   016_UI/005_UI_Party.rb                 PokemonPartyPanel, PokemonPartyBlankPanel,
#                                          PokemonPartyCancelSprite, Window_CommandPokemonColor,
#                                          PokemonParty_Scene#pbStartScene / pbShowCommands /
#                                          pbSetHelpText / pbDisplay
#   014_Pokemon/.../003_Pokemon_Sprites.rb PokemonIconSprite (Center origin, selected bob)
#   007_Objects and windows/004_SpriteWindow.rb      SpriteWindow 9-slice (skinformat 1)
#   007_Objects and windows/005_SpriteWindow_text.rb Window_UnformattedTextPokemon,
#                                          Window_AdvancedTextPokemon, Window_CommandPokemon
#   007_Objects and windows/010_DrawText.rb          pbDrawTextPositions, pbDrawShadowText,
#                                          drawTextEx / getLineBrokenChunks, getFormattedText
#   007_Objects and windows/002_MessageConfig.rb     pbBottomRight / pbBottomLeft(Lines),
#                                          system frame, default text colours
# plus KIF's hooks (990_KIF): F-POKE-03 Gender (♂/♀ colours, genderless icon),
# F-UI-03 GameFont (Default = Power Green 29 / Small 25), F-UI-02 BigIcons (Off
# by default, so no change). KIF Beta defaults: menu frame 0
# ("default_transparent"), no dark mode, Big Icons Off.
# Final, settled state: icons on frame 0, the selected icon on its bob frame 0
# (+4, +6), command cursor arrow drawn, message fully typed out.
# Also writes <out>.json with the rectangles mockups draw over, and <out>@2x.png
# (nearest-neighbour 2x, for looking at).
#
# Usage: python party_backdrop.py "<KIF Beta>" out.png
#          [--party "PIKACHU:Pikachu:34:78/95:m,LAPRAS:Lapras:32:120/130:f,..."]
#              entry = SPECIES:Name:level:hp/total:gender[:item][:status]
#              gender m / f / n (genderless) / p (KIF "pizza"); item = item / mail / - ;
#              status = SLP / PSN / BRN / PAR / FRZ / PKRS / - (hp 0 = fainted)
#          [--sel 0]                       panel 0-5, 6 = Cancel
#          [--commands "Summary,Switch,Item,Rain Dance,Cancel" --cmd-sel 3 --cmd-color "3:blue"]
#          [--help "Do what with Pikachu?"]
#          [--message "Pikachu used Rain Dance!"]
#          [--no-commands]                 pbShowCommands state without the command window itself
#          [--annotations "ABLE,NOT ABLE,..."]
import sys, os, math, json, argparse, re
import numpy as np
from PIL import Image, ImageFont, ImageDraw

W, H = 512, 384

ap = argparse.ArgumentParser(add_help=False)
ap.add_argument("root")
ap.add_argument("out")
ap.add_argument("--party", default="PIKACHU:Pikachu:34:78/95:m,LAPRAS:Lapras:32:120/130:f,"
                                    "GENGAR:Gengar:33:90/90:m,CHARMANDER:Charmander:21:52/52:m")
ap.add_argument("--sel", type=int, default=0, help="selected panel 0-5, 6 = Cancel")
ap.add_argument("--commands", default=None, help="comma-separated command list (pbShowCommands)")
ap.add_argument("--cmd-sel", type=int, default=0, help="highlighted command")
ap.add_argument("--cmd-color", default="", help='e.g. "3:blue" (field-move colour, colorKey 1)')
ap.add_argument("--help", dest="help_text", default=None, help="help window text")
ap.add_argument("--message", default=None, help="message box text (pbDisplay)")
ap.add_argument("--no-commands", action="store_true",
                help="with --commands: leave the command window out (help window keeps its pbShowCommands size)")
ap.add_argument("--annotations", default=None, help='comma-separated panel annotations ("ABLE", "NOT ABLE", ...)')
args = ap.parse_args()

ROOT = args.root
G = lambda *p: os.path.join(ROOT, "Graphics", *p)
PARTY = lambda n: G("Pictures", "Party", n + ".png")
_cache = {}

def load(path):
    if path not in _cache:
        _cache[path] = Image.open(path).convert("RGBA")
    return _cache[path]

def ruby_round(v):
    return int(math.floor(v + 0.5)) if v >= 0 else -int(math.floor(-v + 0.5))

#-------------------------------------------------------------------------------
# Sprite drawing the way mkxp-z does it (unscaled here: quad at x - ox, y - oy,
# src_rect crop, opacity scales alpha)
#-------------------------------------------------------------------------------
def draw_sprite(dst, img, x, y, ox=0, oy=0, src=None, opacity=255):
    if src is not None:
        sx, sy, sw, sh = src
        sx0, sy0 = max(0, sx), max(0, sy)
        sx1, sy1 = min(img.width, sx + sw), min(img.height, sy + sh)
        if sx1 <= sx0 or sy1 <= sy0:
            return
        img = img.crop((sx0, sy0, sx1, sy1))
        ox -= (sx0 - sx)
        oy -= (sy0 - sy)
    if opacity < 255:
        a = np.asarray(img).astype(np.float64)
        a[..., 3] *= opacity / 255.0
        img = Image.fromarray(np.round(a).astype(np.uint8), "RGBA")
    left, top = int(x - ox), int(y - oy)
    # clip to the destination
    cx0, cy0 = max(0, -left), max(0, -top)
    cx1, cy1 = min(img.width, dst.width - left), min(img.height, dst.height - top)
    if cx1 <= cx0 or cy1 <= cy0:
        return
    if (cx0, cy0, cx1, cy1) != (0, 0, img.width, img.height):
        img = img.crop((cx0, cy0, cx1, cy1))
    dst.alpha_composite(img, (left + cx0, top + cy0))

def blt(dst, src, x, y, rect=None):
    # Bitmap#blt: unscaled, blended
    draw_sprite(dst, src, x, y, src=rect)

#-------------------------------------------------------------------------------
# Text: KIF's MessageConfig (Power Green 29 / Power Green Small 25; F-UI-03
# "Game's Font" Default), drawn by mkxp-z at floor(size * 0.9). KIF's
# Bitmap#draw_text override (001_MKXP_Compatibility) passes the text's own
# height, so the ascent line sits at y (no vertical centring); horizontal align
# by surface width, too-wide text is squeezed.
#-------------------------------------------------------------------------------
FONT_FILES = {"system": ("power green.ttf", 29), "small": ("power green small.ttf", 25)}
_fonts = {}

def font(kind):
    if kind not in _fonts:
        fn, size = FONT_FILES[kind]
        _fonts[kind] = ImageFont.truetype(os.path.join(ROOT, "Fonts", fn), int(size * 0.9))
    return _fonts[kind]

def text_width(kind, s):
    # Bitmap#text_size(s).width
    return int(round(font(kind).getlength(s))) if s else 0

def line_height(kind):
    # Bitmap#text_size(s).height (the font's height)
    a, d = font(kind).getmetrics()
    return a + abs(d)

def union(a, b):
    if a is None:
        return b
    if b is None:
        return a
    return [min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3])]

def draw_text(bmp, x, y, w, text, align, kind, color):
    # Bitmap#draw_text(x, y, w, text_size.height, text, align); returns the
    # ink box [x0, y0, x1, y1] in bmp coordinates (None if nothing drawn)
    if not text or w <= 0 or color[3] <= 0:
        return None
    f = font(kind)
    adv = text_width(kind, text)
    lh = line_height(kind)
    bb = f.getbbox(text)
    sw = max(adv, bb[2], 1)
    mask = Image.new("L", (sw + 8, max(lh, bb[3]) + 8), 0)
    ImageDraw.Draw(mask).text((0, 0), text, font=f, fill=255)
    mask = mask.crop((0, 0, sw, max(lh, bb[3])))
    if sw > w:
        mask = mask.resize((w, mask.height), Image.NEAREST)
        sw = w
    ax = x
    if align == 1:
        ax += (w - sw) // 2
    elif align == 2:
        ax += w - sw
    ax = max(ax, x)
    layer = Image.new("RGBA", mask.size, tuple(color[:3]) + (0,))
    layer.putalpha(mask.point(lambda m: m * color[3] // 255))
    draw_sprite(bmp, layer, ax, y)
    ink = mask.getbbox()
    return [ax + ink[0], y + ink[1], ax + ink[2], y + ink[3]] if ink else None

def pbDrawShadowText(bmp, x, y, w, h, s, base, shadow, align, kind):
    # 010_DrawText: y += 4; shadow at (+2,0) (0,+2) (+2,+2), then the base
    y += 4
    ink = None
    if shadow and shadow[3] > 0:
        for dx, dy in [(2, 0), (0, 2), (2, 2)]:
            ink = union(ink, draw_text(bmp, x + dx, y + dy, w, s, align, kind, shadow))
    base_ink = None
    if base and base[3] > 0:
        base_ink = draw_text(bmp, x, y, w, s, align, kind, base)
    return {"ascent_y": y, "base_ink": base_ink, "ink": union(ink, base_ink)}

def pbDrawTextPositions(bmp, textpos, kind):
    # [text, x, y, align, base, shadow]: y + 6, right / centre align by text width
    out = []
    for t in textpos:
        s, x, y, al, base, shadow = t[:6]
        tw = text_width(kind, s)
        y = y + 6
        if al is True or al == 1:
            x -= tw
        elif al == 2:
            x -= tw // 2
        r = pbDrawShadowText(bmp, x, y, tw, 0, s, base, shadow, 0, kind)
        r["box"] = [x, r["ascent_y"], tw, line_height(kind)]
        out.append(r)
    return out

def ink_rect(ink, ox=0, oy=0):
    return [ink[0] + ox, ink[1] + oy, ink[2] - ink[0], ink[3] - ink[1]] if ink else None

def C(r, g, b, a=255):
    return (r, g, b, a)

#-------------------------------------------------------------------------------
# Windows: SpriteWindow with KIF Beta's system frame. Settings::MENU_WINDOWSKINS
# [$PokemonSystem.frame = 0] = "default_transparent" (48x48 -> skinformat 1:
# skinrect (16,16,16,16), trim 16 all round, corners blitted, sides tiled,
# middle stretched; contents at (x+16, y+16) clipped to (w-32, h-32)). The
# skin's middle is (0,0,0,204) -> isDarkWindowskin -> light text
# (248,248,248)/(72,80,88) and Graphics/Pictures/selarrow_white.
#-------------------------------------------------------------------------------
SKIN_NAME = "default_transparent"
SKIN = load(G("Windowskins", SKIN_NAME + ".png"))

def skin_layout(skin):
    sw, sh = skin.size
    if (sw, sh) in [(192, 128), (128, 128)]:
        raise SystemExit("RGSS-format skin not handled (KIF Beta's default is a 48x48 skinformat-1 skin)")
    sr = ((sw - 16) // 2, (sh - 16) // 2, 16, 16)
    trim = [sr[0], sr[1], sr[0], sr[1]]
    return sr, trim

def is_dark_skin(skin):
    # isDarkWindowskin: a 48x48 skin -> centre pixel luminance < 160
    c = skin.getpixel((skin.width // 2, skin.height // 2))
    return (c[0] * 0.299 + c[1] * 0.587 + c[2] * 0.114) < 160

DARK_SKIN = is_dark_skin(SKIN)
TEXT_BASE, TEXT_SHADOW = ((C(248, 248, 248), C(72, 80, 88)) if DARK_SKIN      # LIGHT_TEXT_*
                          else (C(80, 80, 88), C(160, 160, 168)))              # DARK_TEXT_*
SELARROW = load(G("Pictures", "selarrow_white.png" if DARK_SKIN else "selarrow.png"))

def tile(dst_w, dst_h, src):
    out = Image.new("RGBA", (max(dst_w, 0), max(dst_h, 0)), (0, 0, 0, 0))
    if dst_w <= 0 or dst_h <= 0:
        return out
    yy = 0
    while yy < dst_h:
        xx = 0
        while xx < dst_w:
            out.paste(src, (xx, yy))
            xx += src.width
        yy += src.height
    return out

def draw_window(screen, x, y, w, h, contents=None, ox=0, oy=0):
    # SpriteWindow#privRefresh (skinformat 1), sprites in @spritekeys order:
    # back, corner0, side0, corner1, side1, corner2, side2, corner3, side3, contents
    skin = SKIN
    sr, trim = skin_layout(skin)
    startX, startY = sr[0], sr[1]
    cx, cy = sr[0] + sr[2], sr[1] + sr[3]
    endX, endY = skin.width - cx, skin.height - cy
    crop = lambda r: skin.crop((r[0], r[1], r[0] + r[2], r[1] + r[3]))
    bw, bh = w - startX - endX, h - startY - endY
    if bw > 0 and bh > 0:                                   # back: stretch_blt of the body rect
        draw_sprite(screen, crop(sr).resize((bw, bh), Image.NEAREST), x + startX, y + startY)
    sides = [(startX, 0, sr[2], startY), (0, startY, startX, sr[3]),
             (cx, startY, endX, sr[3]), (startX, cy, sr[2], endY)]
    corners = [((0, 0, startX, startY), (x, y)), ((cx, 0, endX, startY), (x + w - endX, y)),
               ((0, cy, startX, endY), (x, y + h - endY)), ((cx, cy, endX, endY), (x + w - endX, y + h - endY))]
    side_pos = [(x + startX, y, w - startX - endX, startY), (x, y + startY, startX, h - startY - endY),
                (x + w - endX, y + startY, endX, h - startY - endY), (x + startX, y + h - endY, w - startX - endX, endY)]
    for i in range(4):
        draw_sprite(screen, crop(corners[i][0]), *corners[i][1])
        sx, sy, sw_, sh_ = side_pos[i]
        draw_sprite(screen, tile(sw_, sh_, crop(sides[i])), sx, sy)
    trimW = trim[0] + (sr[2] - trim[2] + trim[0])
    trimH = trim[1] + (sr[3] - trim[3] + trim[1])
    if contents is not None and w > trimW and h > trimH:
        draw_sprite(screen, contents, x + trim[0], y + trim[1], src=(ox, oy, w - trimW, h - trimH))
    return {"rect": [x, y, w, h], "contents_rect": [x + trim[0], y + trim[1], w - trimW, h - trimH]}

BORDER_X = BORDER_Y = 32          # SpriteWindow#borderX / borderY for this skin
TEXTPADDING = 4                   # SpriteWindow_Base::TEXTPADDING

#-------------------------------------------------------------------------------
# Text layout ports
#-------------------------------------------------------------------------------
def getLineBrokenChunks(kind, value, width):
    # 010_DrawText#getLineBrokenChunks(plain = true): [word, x, y, width, 32], dims
    x = y = 0
    ret, dims = [], [0, 0]
    if width <= 0:
        return ret, dims
    msg = value
    pat = re.compile(r"\n|[^ \r\t\f\n\-]*\-+|(\S*([ \r\t\f]?))")
    while True:
        m = pat.match(msg)
        if m is None:
            break
        c = m.group(0)
        msg = msg[m.end():]
        if c == "":
            break
        if c == "\n":
            x = 0
            y += 32
            continue
        word = c
        tw = text_width(kind, word)
        if x > 0 and x + tw > width:
            mw = text_width(kind, re.sub(r"\s*", "", word))
            if x > 0 and x + mw > width:
                x = 0
                y += 32
        if tw > width and not re.search(r"\s", word):
            for ch in word:
                cw = text_width(kind, ch)
                if x > 0 and x + cw > width:
                    x = 0
                    y += 32
                ret.append([ch, x, y, cw, 32])
                x += cw
                dims[0] = max(dims[0], x)
            continue
        ret.append([word, x, y, tw, 32])
        x += tw
        dims[0] = max(dims[0], x)
    dims[1] = y + 32
    return ret, dims

def drawTextEx(bmp, x, y, width, numlines, text, base, shadow, kind="system"):
    # getLineBrokenChunks + renderLineBrokenChunksWithShadow (draw_text width+2)
    chunks, _ = getLineBrokenChunks(kind, text, width)
    maxh = numlines * 32
    lines = {}
    for word, wx, wy, ww, wh in chunks:
        if maxh != 0 and wy >= maxh:
            continue
        tx, ty = wx + x, wy + y
        ink = None
        for dx, dy in [(2, 0), (0, 2), (2, 2)]:
            ink = union(ink, draw_text(bmp, tx + dx, ty + dy, ww + 2, word, 0, kind, shadow))
        bi = draw_text(bmp, tx, ty, ww + 2, word, 0, kind, base)
        ln = lines.setdefault(wy, {"x": tx, "ascent_y": ty, "width": 0, "text": "", "ink": None, "base_ink": None})
        ln["width"] = wx + ww - (ln["x"] - x)
        ln["text"] += word
        ln["ink"] = union(ln["ink"], union(ink, bi))
        ln["base_ink"] = union(ln["base_ink"], bi)
    return [lines[k] for k in sorted(lines)]

def getFormattedText(kind, text, widthDst, lineheight=32):
    # 010_DrawText#getFormattedText for plain text behind a colour tag (the
    # controls path): one entry per character, x advanced by text_size(char),
    # word wrap when x + 2 > widthDst, spaces before a newline dropped
    chars, internal = [], []
    x = y = 0
    lastword = [0, 0]
    hadspace = hadnonspace = False
    havenl = False
    for ch in text:
        width = text_width(kind, ch)
        if ch == "\n":
            havenl = True
            chars.append(["\n", x, y * lineheight, 0, lineheight])
            internal.append([y, 0, 0])
            y += 1
            x = 0
            hadspace = True
            hadnonspace = False
            continue
        isspace = ch.isspace()
        if hadspace and not isspace:
            lastword = [len(chars), x]
            hadspace = False
            hadnonspace = True
        elif isspace:
            hadspace = True
        chars.append([ch, x, lineheight * y, width + 2, lineheight])
        internal.append([y, 0, 2])
        x += width
        if x + 2 > widthDst and lastword[1] != 0 and (not hadnonspace or not hadspace):
            havenl = True
            chars.insert(lastword[0], ["\n", x, y * lineheight, 0, lineheight])
            internal.insert(lastword[0], [y, 0, 0])
            lastword[0] += 1
            y += 1
            x = 0
            for i in range(lastword[0], len(chars)):
                chars[i][2] += lineheight
                internal[i][0] += 1
                cw = chars[i][3] - internal[i][2]
                chars[i][1] = x + internal[i][1]
                x += cw
            lastword[1] = 0
        elif x + 2 > widthDst and lastword[1] == 0 and chars and chars[-1][0] != "\n":
            havenl = True
            bi = len(chars) - 1
            chars.insert(bi, ["\n", 0, y * lineheight, 0, lineheight])
            internal.insert(bi, [y, 0, 0])
            y += 1
            x = 0
            for i in range(bi + 1, len(chars)):
                chars[i][2] += lineheight
                internal[i][0] += 1
                cw = chars[i][3] - internal[i][2]
                chars[i][1] = x + internal[i][1]
                x += cw
    if havenl:
        keep = [True] * len(chars)
        firstspace = -1
        for i, c in enumerate(chars):
            if c[0] == "\n" and firstspace >= 0:
                for j in range(firstspace, i):
                    keep[j] = False
                firstspace = -1
            elif c[0] in " \r\t":
                if firstspace < 0:
                    firstspace = i
            else:
                firstspace = -1
        if firstspace > 0:
            for j in range(firstspace, len(chars)):
                keep[j] = False
        chars = [c for c, k in zip(chars, keep) if k]
    return chars

#-------------------------------------------------------------------------------
# The party
#-------------------------------------------------------------------------------
STATUS_ROWS = {"SLP": 0, "PSN": 1, "BRN": 2, "PAR": 3, "FRZ": 4, "FNT": 5, "PKRS": 6}
party = []
for e in [p for p in args.party.split(",") if p.strip()]:
    f = e.strip().split(":")
    if len(f) < 5:
        ap.error("party entry needs SPECIES:Name:level:hp/total:gender -> %r" % e)
    hp, total = [int(v) for v in f[3].split("/")]
    party.append(dict(species=f[0].upper(), name=f[1], level=int(f[2]), hp=hp, total=total,
                      gender={"m": 0, "f": 1, "n": 2, "p": 3}.get(f[4].strip().lower(), 2),
                      item=(f[5].strip().lower() if len(f) > 5 and f[5].strip() not in ("", "-") else None),
                      status=(f[6].strip().upper() if len(f) > 6 and f[6].strip() not in ("", "-") else None)))
if len(party) > 6:
    ap.error("at most 6 party members")
if not party:
    ap.error("the party needs at least one Pokémon")
annotations = None
if args.annotations is not None:
    annotations = [a.strip() for a in args.annotations.split(",")]

def icon_path(pk):
    # GameData::Species.icon_filename: _female first for females, then the species
    cands = ([pk["species"] + "_female"] if pk["gender"] == 1 else []) + [pk["species"]]
    for c in cands:
        p = G("Pokemon", "Icons", c + ".png")
        if os.path.exists(p):
            return p
    raise SystemExit("no icon Graphics/Pokemon/Icons/%s.png" % pk["species"])

screen = Image.new("RGBA", (W, H), (0, 0, 0, 255))
info = {"screen": [W, H], "skin": "Graphics/Windowskins/%s.png" % SKIN_NAME,
        "fonts": {"system": "Fonts/power green.ttf (Power Green) size 29 -> drawn at 26 px",
                  "small": "Fonts/power green small.ttf (Power Green Small) size 25 -> drawn at 22 px"},
        "text_colours": {"window_base": list(TEXT_BASE[:3]), "window_shadow": list(TEXT_SHADOW[:3]),
                         "panel_base": [248, 248, 248], "panel_shadow": [40, 40, 40],
                         "field_move_base": [0, 80, 160], "field_move_shadow": [128, 192, 240]}}
scene = []          # (z, creation order, draw fn) for the party @viewport (z 99999)
def add(z, fn):
    scene.append((z, len(scene), fn))

# addBackgroundPlane(@sprites, "partybg", "Party/bg") -- plane, z 0, made first
bgimg = load(PARTY("bg"))
def draw_bg():
    yy = 0
    while yy < H:
        xx = 0
        while xx < W:
            draw_sprite(screen, bgimg, xx, yy)
            xx += bgimg.width
        yy += bgimg.height
add(0, draw_bg)

# @sprites["messagebox"] / ["helpwindow"] are made next (z 100, drawn after the
# panels); their draw fns are added further down with z 100.

sel = args.sel
WHITE_P, SHADOW_P = C(248, 248, 248), C(40, 40, 40)
MALE, FEMALE = (C(55, 148, 229), C(68, 98, 125)), (C(229, 55, 203), C(137, 73, 127))   # KIF::Gender
info["panels"] = []
for i in range(6):
    x = (i % 2) * W // 2
    y = 16 * (i % 2) + 96 * (i // 2)
    if i >= len(party):
        # PokemonPartyBlankPanel
        bmp = load(PARTY("panel_blank"))
        add(0, lambda bmp=bmp, x=x, y=y: draw_sprite(screen, bmp, x, y))
        vis = bmp.getchannel("A").getbbox()
        info["panels"].append({"index": i, "kind": "blank", "rect": [x, y, bmp.width, bmp.height],
                               "graphic_rect": [x + vis[0], y + vis[1], vis[2] - vis[0], vis[3] - vis[1]],
                               "graphic": "Graphics/Pictures/Party/panel_blank.png"})
        continue
    pk = party[i]
    active = i == 0
    selected = i == sel
    fainted = pk["hp"] <= 0
    text = annotations[i] if annotations and i < len(annotations) and annotations[i] else None
    shape = "round" if active else "rect"
    state = ("faintedsel" if fainted else "ablesel") if selected else ("fainted" if fainted else "able")
    pname = {"able": "panel_%s", "ablesel": "panel_%s_sel", "fainted": "panel_%s_faint",
             "faintedsel": "panel_%s_faint_sel"}[state] % shape
    panelbmp = load(PARTY(pname))
    add(0, lambda b=panelbmp, x=x, y=y: draw_sprite(screen, b, x, y))
    # @hpbgsprite (z 1) at +96, +50
    hpbg_vis = not text
    hpbgname = "overlay_hp_back_faint" if fainted else "overlay_hp_back"
    if hpbg_vis:
        hpbg = load(PARTY(hpbgname))
        add(1, lambda b=hpbg, x=x, y=y: draw_sprite(screen, b, x + 96, y + 50))
    # @ballsprite (z 1) at +10, +0
    ball = load(PARTY("icon_ball_sel" if selected else "icon_ball"))
    add(1, lambda b=ball, x=x, y=y: draw_sprite(screen, b, x + 10, y))
    # @pkmnsprite (z 2): Center origin -> ox = 32, oy = 64 * 5 / 8 = 40; frame 0;
    # selected -> @adjusted_x = 4, @adjusted_y = 6 (frame 0 of 2: not >= 1)
    ip = icon_path(pk)
    icon_sheet = load(ip)
    fh = icon_sheet.height
    frame = icon_sheet.crop((0, 0, fh, fh))
    adj = (4, 6) if selected else (0, 0)
    iox, ioy = fh // 2, fh * 5 // 8
    icx, icy = x + 60 + adj[0], y + 40 + adj[1]
    add(2, lambda b=frame, icx=icx, icy=icy, iox=iox, ioy=ioy: draw_sprite(screen, b, icx, icy, iox, ioy))
    # @helditemsprite (z 3) at +62, +48
    item_rect = None
    if pk["item"]:
        base_kind = "mail" if pk["item"] == "mail" else "item"
        ipth = PARTY("icon_%s" % base_kind)
        if pk["item"] not in ("item", "mail") and os.path.exists(PARTY("icon_item_%s" % pk["item"].upper())):
            ipth = PARTY("icon_item_%s" % pk["item"].upper())
        itm = load(ipth)
        add(3, lambda b=itm, x=x, y=y: draw_sprite(screen, b, x + 62, y + 48))
        item_rect = [x + 62, y + 48, itm.width, itm.height]
    # @overlaysprite (z 4): a 512x384 bitmap at the panel's x, y
    ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    textpos = [[pk["name"], 96, 10, 0, WHITE_P, SHADOW_P]]
    hp_bar = None
    status_rect = None
    if not text:
        textpos.append(["% 3d /% 3d" % (pk["hp"], pk["total"]), 224, 54, 1, WHITE_P, SHADOW_P])
        if pk["hp"] > 0:
            w = pk["hp"] * 96 * 1.0 / pk["total"]
            if w < 1:
                w = 1
            w = ruby_round(w / 2) * 2
            zone = 0
            if pk["hp"] <= pk["total"] // 2:
                zone = 1
            if pk["hp"] <= pk["total"] // 4:
                zone = 2
            blt(ov, load(PARTY("overlay_hp")), 128, 52, (0, zone * 8, w, 8))
            hp_bar = {"rect": [x + 128, y + 52, 96, 8], "fill_w": w, "zone": ["green", "yellow", "red"][zone]}
        else:
            hp_bar = {"rect": [x + 128, y + 52, 96, 8], "fill_w": 0, "zone": None}
        st = "FNT" if fainted else pk["status"]
        if st:
            if st not in STATUS_ROWS:
                ap.error("unknown status %s" % st)
            blt(ov, load(G("Pictures", "statuses.png")), 78, 68, (0, 16 * STATUS_ROWS[st], 44, 16))
            status_rect = [x + 78, y + 68, 44, 16]
    gender_idx = None
    if pk["gender"] in (0, 1):                     # KIF::Gender recolours the lone ♂ / ♀
        g = MALE if pk["gender"] == 0 else FEMALE
        gender_idx = len(textpos)
        textpos.append(["♂" if pk["gender"] == 0 else "♀", 224, 10, 0, g[0], g[1]])
    tp = pbDrawTextPositions(ov, textpos, "system")
    # level: overlay_lv at 20,70 then the small-font number at 42,57
    blt(ov, load(PARTY("overlay_lv")), 20, 70, (0, 0, 22, 14))
    lv = pbDrawTextPositions(ov, [[str(pk["level"]), 42, 57, 0, WHITE_P, SHADOW_P]], "small")[0]
    annot = None
    if text:
        annot = pbDrawTextPositions(ov, [[text, 96, 52, 0, WHITE_P, SHADOW_P]], "system")[0]
    # F-POKE-03 Gender: genderless icon at (224 - 14, 10 + 13), pizza at (224 - 18, 10 + 5)
    gicon = None
    if pk["gender"] == 2:
        gi = load(G("Pictures", "KIF", "gender_genderless.png"))
        blt(ov, gi, 210, 23)
        gicon = [x + 210, y + 23, gi.width, gi.height]
    elif pk["gender"] == 3:
        gi = load(G("Pictures", "KIF", "gender_pizza.png"))
        blt(ov, gi, 206, 15)
        gicon = [x + 206, y + 15, gi.width, gi.height]
    add(4, lambda b=ov, x=x, y=y: draw_sprite(screen, b, x, y))

    def trect(r):
        b = r["box"]
        return {"box": [x + b[0], y + b[1], b[2], b[3]], "ink": ink_rect(r["ink"], x, y),
                "base_ink": ink_rect(r["base_ink"], x, y)}
    vis = panelbmp.getchannel("A").getbbox()
    ivis = frame.getchannel("A").getbbox()
    itl = (icx - iox, icy - ioy)
    e = {"index": i, "kind": shape, "species": pk["species"], "name": pk["name"], "level": pk["level"],
         "hp": [pk["hp"], pk["total"]], "selected": selected, "fainted": fainted,
         "rect": [x, y, panelbmp.width, panelbmp.height],
         "graphic_rect": [x + vis[0], y + vis[1], vis[2] - vis[0], vis[3] - vis[1]],
         "graphic": "Graphics/Pictures/Party/%s.png" % pname,
         "ball_rect": [x + 10, y, ball.width, ball.height],
         "icon": {"file": os.path.relpath(ip, ROOT).replace("\\", "/"), "frame": 0,
                  "frame_rect": [itl[0], itl[1], fh, fh],
                  "opaque_rect": [itl[0] + ivis[0], itl[1] + ivis[1], ivis[2] - ivis[0], ivis[3] - ivis[1]],
                  "anchor": [icx, icy], "bob_offset": list(adj)},
         "name_text": trect(tp[0]),
         "level_image": [x + 20, y + 70, 22, 14], "level_text": trect(lv)}
    if hpbg_vis:
        hb = load(PARTY(hpbgname))
        e["hp_back"] = [x + 96, y + 50, hb.width, hb.height]
        e["hp_bar"] = hp_bar
        e["hp_text"] = trect(tp[1])
    if gender_idx is not None:
        e["gender_text"] = trect(tp[gender_idx])
    if gicon:
        e["gender_icon"] = gicon
    if status_rect:
        e["status_rect"] = status_rect
    if item_rect:
        e["item_icon"] = item_rect
    if annot:
        e["annotation_text"] = trect(annot)
    info["panels"].append(e)

# PokemonPartyCancelSprite: icon_cancel(_sel) at 398,328 (z 0), "CANCEL" overlay (z 1)
cb = load(PARTY("icon_cancel_sel" if sel == 6 else "icon_cancel"))
add(0, lambda: draw_sprite(screen, cb, 398, 328))
cov = Image.new("RGBA", cb.size, (0, 0, 0, 0))
ct = pbDrawTextPositions(cov, [["CANCEL", 56, 2, 2, WHITE_P, SHADOW_P]], "system")[0]
add(1, lambda: draw_sprite(screen, cov, 398, 328))
cvis = cb.getchannel("A").getbbox()
info["cancel"] = {"rect": [398, 328, cb.width, cb.height],
                  "graphic_rect": [398 + cvis[0], 328 + cvis[1], cvis[2] - cvis[0], cvis[3] - cvis[1]],
                  "selected": sel == 6,
                  "text": {"box": [398 + ct["box"][0], 328 + ct["box"][1], ct["box"][2], ct["box"][3]],
                           "ink": ink_rect(ct["ink"], 398, 328)}}

#-------------------------------------------------------------------------------
# Command window (pbShowCommands): Window_CommandPokemonColor, auto-sized
# (getAutoDims: widest command + 16 + 16 + TEXTPADDING, + borderX; 32 per row
# + borderY), pbBottomRight, z = viewport z + 1 (on top of everything)
#-------------------------------------------------------------------------------
commands = [c.strip() for c in args.commands.split(",")] if args.commands else None
showing_message = args.message is not None
cmd_info = None
cmd_draw = None
if commands:
    colorkey = {}
    for part in [p for p in args.cmd_color.split(",") if p.strip()]:
        k, v = part.split(":")
        if v.strip().lower() not in ("blue", "1", "field"):
            ap.error("--cmd-color: only colorKey 1 exists (blue, Window_CommandPokemonColor)")
        colorkey[int(k)] = 1
    n = len(commands)
    widest = max(text_width("system", c) for c in commands)
    cw = widest + 16 + 16 + TEXTPADDING
    cmdw = max(BORDER_X + 1, cw + BORDER_X)
    cmdh = min(max(BORDER_Y + 1, n * 32 + BORDER_Y), H)
    cmdx, cmdy = W - cmdw, H - cmdh
    csel = max(0, min(n - 1, args.cmd_sel))
    # SpriteWindow_Selectable: rows of 32, page = (h - borderY) / 32, the
    # cursor kept in the middle of the page when the list scrolls
    page = (cmdh - BORDER_Y) // 32
    top_row = max(min(csel - (page - 1) // 2, n - page), 0)
    contents = Image.new("RGBA", (cmdw - BORDER_X, cmdh - BORDER_Y), (0, 0, 0, 0))
    rows = []
    for idx, label in enumerate(commands):
        if idx < top_row or idx > top_row + page:
            continue
        rx, ry, rw, rh = 0, idx * 32 - top_row * 32, cmdw - BORDER_X, 32
        arrow = None
        if idx == csel:                            # drawCursor: selarrow at the row's top-left
            blt(contents, SELARROW, rx, ry)
            arrow = [cmdx + 16 + rx, cmdy + 16 + ry, SELARROW.width, SELARROW.height]
        tx, tw = rx + 16, rw - 16
        base, shadow = TEXT_BASE, TEXT_SHADOW
        if colorkey.get(idx) == 1:
            base, shadow = C(0, 80, 160), C(128, 192, 240)
        r = pbDrawShadowText(contents, tx, ry, tw, rh, label, base, shadow, 0, "system")
        rows.append({"index": idx, "label": label, "selected": idx == csel, "color_key": colorkey.get(idx, 0),
                     "visible": ry + rh <= cmdh - BORDER_Y,
                     "row_rect": [cmdx + 16 + rx, cmdy + 16 + ry, rw, rh],
                     "text_rect": [cmdx + 16 + tx, cmdy + 16 + ry, tw, rh],
                     "text_box": [cmdx + 16 + tx, cmdy + 16 + r["ascent_y"], text_width("system", label),
                                  line_height("system")],
                     "text_ink": ink_rect(r["ink"], cmdx + 16, cmdy + 16),
                     "base": list(base[:3]), "shadow": list(shadow[:3]), "arrow_rect": arrow})
    cmd_info = {"rect": [cmdx, cmdy, cmdw, cmdh], "contents_rect": [cmdx + 16, cmdy + 16, cmdw - 32, cmdh - 32],
                "row_height": 32, "selected": csel, "top_row": top_row, "rows": rows,
                "width_rule": "widest command (%d) + 16 + 16 + 4 + borderX 32" % widest,
                "drawn": not (args.no_commands or showing_message), "z": "viewport z + 1 = 100000"}
    # UpDownArrowMixin: Graphics/Pictures/uparrow / downarrow (8 frames, frame 0),
    # centred on the window's top / bottom edge, z = window z + 1
    arrows = []
    if n > page:
        if top_row != 0:
            ua = load(G("Pictures", "uparrow.png"))
            fw = ua.width // 8
            arrows.append(("up", ua.crop((0, 0, fw, ua.height)), cmdx + cmdw // 2 - fw // 2, cmdy))
        if top_row + page < n:
            da = load(G("Pictures", "downarrow.png"))
            fw = da.width // 8
            arrows.append(("down", da.crop((0, 0, fw, da.height)), cmdx + cmdw // 2 - fw // 2, cmdy + cmdh - da.height))
        cmd_info["scroll_arrows"] = {a[0]: [a[2], a[3], a[1].width, a[1].height] for a in arrows}
    def cmd_draw():
        draw_window(screen, cmdx, cmdy, cmdw, cmdh, contents)
        for _, img, ax, ay in arrows:
            draw_sprite(screen, img, ax, ay)
    info["command_window"] = cmd_info

#-------------------------------------------------------------------------------
# Help window (Window_UnformattedTextPokemon, z 100). pbStartScene /
# pbSetHelpText: pbBottomLeftLines(1) then width 398. pbShowCommands:
# resizeHeightToFit(text, Graphics.width - cmdwindow.width), pbBottomLeft.
# Its contents bitmap only grows (pbDoEnsureBitmap): after pbBottomLeftLines
# set width 512 it is 480 wide, and drawTextEx wraps at that width.
#-------------------------------------------------------------------------------
if commands:
    pkname = party[sel]["name"] if 0 <= sel < len(party) else party[0]["name"]
    help_text = args.help_text if args.help_text is not None else "Do what with %s?" % pkname
else:
    help_text = args.help_text if args.help_text is not None else (
        "Choose a Pokémon." if len(party) > 1 else "Choose Pokémon or cancel.")
if commands:
    hw = W - cmd_info["rect"][2]
    _, dims = getLineBrokenChunks("system", help_text, hw - BORDER_X - TEXTPADDING)
    hh = dims[1] + BORDER_Y
    hx, hy = 0, H - hh
    help_state = "pbShowCommands: resizeHeightToFit(text, %d - %d), pbBottomLeft" % (W, cmd_info["rect"][2])
else:
    hh = BORDER_Y + 1 * 32
    hx, hy, hw = 0, H - hh, 398
    help_state = "pbSetHelpText: pbBottomLeftLines(1), width 398"
help_contents_w = max(W - BORDER_X, hw - BORDER_X)
help_contents = Image.new("RGBA", (help_contents_w, max(hh - BORDER_Y, 32) + 8), (0, 0, 0, 0))
help_lines = drawTextEx(help_contents, 0, 4, help_contents_w, 0, help_text.replace("\r", ""),
                        TEXT_BASE, TEXT_SHADOW)
help_draw = lambda: draw_window(screen, hx, hy, hw, hh, help_contents)
vis_w = hw - BORDER_X
info["help_window"] = {
    "rect": [hx, hy, hw, hh], "contents_rect": [hx + 16, hy + 16, hw - 32, hh - 32],
    "text": help_text, "visible": not showing_message, "state": help_state,
    "lines": [{"text": l["text"], "box": [hx + 16 + l["x"], hy + 16 + l["ascent_y"], l["width"], line_height("system")],
               "ink": ink_rect(l["ink"], hx + 16, hy + 16),
               "clipped": (l["x"] + l["width"] > vis_w) or (l["ascent_y"] >= hh - BORDER_Y)} for l in help_lines]}

#-------------------------------------------------------------------------------
# Message box (Window_AdvancedTextPokemon, z 100): pbBottomLeftLines(2) ->
# (0, 288, 512, 96); pbDisplay hides the help window. Text wraps at
# width - borderX - TEXTPADDING; characters at (x, line * 32 + 4).
#-------------------------------------------------------------------------------
mx, mw, mh = 0, W, BORDER_Y + 2 * 32
my = H - mh
msg_draw = None
if showing_message:
    chars = getFormattedText("system", args.message, mw - BORDER_X - TEXTPADDING, 32)
    bw = max([c[1] + c[3] for c in chars] + [1])
    bh = max([c[2] + c[4] for c in chars] + [1]) + 4 + 8
    mcont = Image.new("RGBA", (max(bw, mw - 32), max(bh, mh - 32)), (0, 0, 0, 0))
    lines = {}
    for c in chars:
        ch, cx, cy = c[0], c[1], c[2] + 4
        if ch in ("\n", "\r", " "):
            continue
        ink = None
        for dx, dy in [(2, 0), (0, 2), (2, 2)]:
            ink = union(ink, draw_text(mcont, cx + dx, cy + dy, c[3] + 2, ch, 0, "system", TEXT_SHADOW))
        bi = draw_text(mcont, cx, cy, c[3], ch, 0, "system", TEXT_BASE)
        ln = lines.setdefault(cy, {"x0": cx, "x1": cx, "text": "", "ink": None})
        ln["x0"] = min(ln["x0"], cx)
        ln["x1"] = max(ln["x1"], cx + c[3] - 2)
        ln["ink"] = union(ln["ink"], union(ink, bi))
    # text per line (spaces included) for the JSON
    texts = {}
    for c in chars:
        if c[0] != "\n":
            texts[c[2] + 4] = texts.get(c[2] + 4, "") + c[0]
    nlines = len(set(c[2] for c in chars if c[0] != "\n"))
    # letter by letter: a "\1" pause goes in at the end of the last visible
    # line, so a longer message stops there with the pause arrow
    # (Graphics/Pictures/pause, 4 frames, frame 0; CURSOR_POSITION 1 = lower
    # right: x + width - 40 + fw / 2, y + height - 60 + fh / 2; z 100000)
    pause = None
    if nlines > 2:
        pimg = load(G("Pictures", "pause.png"))
        pfw = pimg.width // 4
        pause = (pimg.crop((0, 0, pfw, pimg.height)), mx + mw - 40 + pfw // 2, my + mh - 60 + pimg.height // 2)
    def msg_draw():
        draw_window(screen, mx, my, mw, mh, mcont)
    def pause_draw():
        if pause:
            draw_sprite(screen, pause[0], pause[1], pause[2])
    info["message_box"] = {
        "rect": [mx, my, mw, mh], "contents_rect": [mx + 16, my + 16, mw - 32, mh - 32],
        "text": args.message, "wrap_width": mw - BORDER_X - TEXTPADDING, "line_height": 32,
        "lines": [{"text": texts.get(k, "").strip(), "box": [mx + 16 + v["x0"], my + 16 + k, v["x1"] - v["x0"],
                                                            line_height("system")],
                   "ink": ink_rect(v["ink"], mx + 16, my + 16), "visible": k < mh - 32}
                  for k, v in sorted(lines.items())]}
    if nlines > 2:
        info["message_box"]["note"] = ("%d lines: shown as the game stops after line 2 (pause arrow); "
                                       "it scrolls on after a button press" % nlines)
        info["message_box"]["pause_arrow"] = [pause[1], pause[2], pause[0].width, pause[0].height]
else:
    info["message_box"] = {"rect": [mx, my, mw, mh], "contents_rect": [mx + 16, my + 16, mw - 32, mh - 32],
                           "visible": False}

# messagebox and helpwindow: z 100 in the party viewport, made before the panels
if showing_message:
    scene.append((100, -2, msg_draw))
else:
    scene.append((100, -1, help_draw))

for _, _, fn in sorted(scene, key=lambda t: (t[0], t[1])):
    fn()
if cmd_draw and not args.no_commands and not showing_message:
    cmd_draw()
if showing_message:
    pause_draw()

state = "message" if showing_message else ("commands" if commands else "choose")
if commands and args.no_commands and not showing_message:
    state = "commands (window left out)"
info["state"] = state
info["selected"] = sel
info["notes"] = ("Rects are [x, y, w, h] in 512x384 screen pixels. Text 'box' starts at the ascent line "
                 "(mkxp-z draws the line top at y) with the advance width and font height; 'ink' is the "
                 "drawn pixels including the shadow. Draw order: bg < panels (z 0 graphics, z 1 HP back + ball, "
                 "z 2 icons, z 3 held items, z 4 text overlays) < Cancel < help window / message box (z 100) "
                 "< command window (outside the viewport, z 100000).")

out = args.out
os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
screen.convert("RGB").save(out)
base_name, ext = os.path.splitext(out)
screen.convert("RGB").resize((W * 2, H * 2), Image.NEAREST).save(base_name + "@2x" + ext)
with open(base_name + ".json", "w", encoding="utf-8") as f:
    json.dump(info, f, indent=1, ensure_ascii=False)
print("saved", out)
