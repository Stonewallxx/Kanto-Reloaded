# Builds KIF Beta's Pokédex screens (PIF 6.8.2 / Essentials v19) for UI
# mockups: the list screen (PokemonPokedex_Scene) and the info page
# (PokemonPokedexInfo_Scene, page 1). Placement follows KIF Beta's own code:
#   016_UI/Pokedex/003_UI_Pokedex_Main.rb   Window_Pokedex (drawItem, refresh, cursor_list),
#                                           PokemonPokedex_Scene#pbStartScene / pbGetDexList /
#                                           pbRefreshDexList / pbRefresh / setIconBitmap
#   016_UI/Pokedex/004_UI_Pokedex_Entry.rb  PokemonPokedexInfo_Scene#pbStartScene / drawPage /
#                                           drawPageInfo / drawEntryText / splitTextIntoPages
#   007_Objects and windows/005_SpriteWindow_text.rb  SpriteWindow_Selectable (rows of 32,
#                                           itemRect, cursor kept mid-page), Window_DrawableCommand
#   007_Objects and windows/004_SpriteWindow.rb       windowskin nil -> borderX/Y 32, contents
#                                           at x + 16, y + 16
#   007_Objects and windows/010_DrawText.rb           pbDrawTextPositions (+6), pbDrawShadowText
#                                           (+4), drawTextEx / getLineBrokenChunks
#   001_Technical/001_MKXP_Compatibility.rb           draw_text gets the text's own height
#                                           (ascent line at y, no vertical centring)
#   014_Pokemon/.../003_Pokemon_Sprites.rb  PokemonSprite (Center origin, zoom 2/3)
#   010_Data/.../009_Species_Files.rb + 052_InfiniteFusion/Fusion/Sprites/*.rb
#                                           sprite_bitmap -> BattleSpriteLoader#load_base_sprite ->
#                                           BaseSpriteExtracter: 96x96 cell of
#                                           CustomBattlers/spritesheets/spritesheets_base/<n>.png,
#                                           stretch_blt x3 (288x288), drawn at zoom 2/3 (192x192)
# plus KIF Beta's hooks (990_KIF): F-POKE-06 DexEvolutions (the "Shift: Evolutions" hint in the
# info title bar, credits box by default), F-DATA-01 SpeciesTweaks (Ferroseed/Ferrothorn/Phantump
# types), F-UI-03 GameFont (Default = Power Green 29 / Small 25, drawn by mkxp-z at 0.9x).
# Defaults: dark mode Off ($Trainer.pokenav.darkMode is nil until switched on), Dex Evolutions =
# Credits Box (not toggled), System.user_language en_US -> feet/lbs (this PC's locale).
# Final, settled state: faded in, sprites on frame 0, cursor drawn.
# Writes out.png, out@2x.png (nearest 2x) and out.json (the rectangles mockups draw over).
#
# Usage:
#   python dex_backdrop.py "<KIF Beta>" out.png list [--sel 25] [--top 21]
#          [--seen all|1-576|"1-151,573"] [--owned none|all|"1,4,7,25"]
#          [--extra "577:Shellos:SHELLOS:C:\path\SHELLOS.png,578:Glameow:GLAMEOW:C:\path\GLAMEOW.png"]
#          [--seen-count N] [--owned-count N] [--alt LETTER] [--dark] [--unseen-rows]
#   python dex_backdrop.py "<KIF Beta>" out.png info --species 25
#          [--not-owned] [--units us|metric] [--alt LETTER] [--dark] [--no-kif-hint] [--entry-page 1]
import sys, os, math, json, argparse, re, struct
import numpy as np
from PIL import Image, ImageFont, ImageDraw

W, H = 512, 384
HERE = os.path.dirname(os.path.abspath(__file__))

ap = argparse.ArgumentParser()
ap.add_argument("root")
ap.add_argument("out")
ap.add_argument("screen", choices=["list", "info"])
ap.add_argument("--sel", default=None, help="list: dex number of the highlighted species (default: the first listed)")
ap.add_argument("--top", default=None,
                help="list: dex number shown on the first row (default: where the game scrolls for --sel: "
                     "the cursor kept on row 5 of 10 when it can be)")
ap.add_argument("--seen", default="all", help='list: seen species, "all" or ranges "1-576,600" (unseen ones are not listed)')
ap.add_argument("--owned", default="none", help='list: owned species, "none", "all" or ranges/numbers')
ap.add_argument("--extra", default="", help='list: species beyond PIF\'s 576, "number:Name:SYMBOL:sprite.png,..." '
                                            '(always seen; owned when in --owned); the sprite is a 96x96 cell')
ap.add_argument("--seen-count", type=int, default=None, help="list: the Seen number (default: species seen here; "
                                                             "the game also counts seen fusions)")
ap.add_argument("--owned-count", type=int, default=None, help="list: the Owned number (default: species owned here)")
ap.add_argument("--unseen-rows", action="store_true",
                help='list: keep unseen numbers as "###  ----------" rows (Window_Pokedex#drawItem can draw them, '
                     'but KIF Beta\'s pbGetDexList only lists seen species, so the game never does)')
ap.add_argument("--species", default=None, help="info: dex number or SYMBOL")
ap.add_argument("--not-owned", action="store_true", help="info: seen but not owned (\"????? Pokémon\", no data)")
ap.add_argument("--units", choices=["us", "metric"], default="us",
                help='info: System.user_language[3..4] == "US" -> feet/lbs (default, en_US) else m/kg')
ap.add_argument("--entry-page", type=int, default=1, help="info: entry text page (Use turns it when it has 2)")
ap.add_argument("--no-kif-hint", action="store_true", help="info: leave out F-POKE-06's \"Shift: Evolutions\" hint")
ap.add_argument("--hint-key", default=None, help="info: key name in the hint (default: from Data/keybindings.mkxp1)")
ap.add_argument("--alt", default="", help='sprite letter of the base spritesheet ("" = first cell; the game picks at '
                                          'random among the "main" letters and "")')
ap.add_argument("--dark", action="store_true", help="isDarkMode (KIF Settings > Graphics > Dark Mode)")
args = ap.parse_args()

ROOT = args.root
G = lambda *p: os.path.join(ROOT, "Graphics", *p)
DEX = lambda n: G("Pictures", "Pokedex", n + ".png")
DARK = args.dark
_cache = {}

def load(path):
    if path not in _cache:
        _cache[path] = Image.open(path).convert("RGBA")
    return _cache[path]

def dex_pic(name, dark_variant=True):
    # pbResolveBitmap(name + "_dark") when isDarkMode, else the normal one
    if DARK and dark_variant and os.path.exists(DEX(name + "_dark")):
        return DEX(name + "_dark")
    return DEX(name)

def rel(p):
    return os.path.relpath(p, ROOT).replace("\\", "/")

def ruby_round(v):
    return int(math.floor(v + 0.5)) if v >= 0 else -int(math.floor(-v + 0.5))

def C(r, g, b, a=255):
    return (r, g, b, a)

#-------------------------------------------------------------------------------
# Ruby Marshal + Encryption.xor (same reader as flymap_backdrop.py)
#-------------------------------------------------------------------------------
KEY = np.array([0x4A, 0x8F, 0x2C, 0xE1, 0x73, 0xB5, 0x96, 0x0D,
                0x5E, 0xA2, 0x3F, 0xC7, 0x81, 0x14, 0x6B, 0xD9], dtype=np.uint8)

def read_dat(path):
    raw = np.fromfile(path, dtype=np.uint8)
    if raw.size >= 2 and raw[0] == 4 and raw[1] == 8:
        return raw.tobytes()
    return (raw ^ np.resize(KEY, raw.shape)).tobytes()

class Marshal:
    def __init__(s, b, pos=2):
        s.b, s.p, s.syms, s.objs = b, pos, [], []
    def byte(s):
        v = s.b[s.p]; s.p += 1; return v
    def fix(s):
        c = s.byte()
        if c == 0: return 0
        if 5 <= c < 128: return c - 5
        if 128 <= c <= 0xfa: return c - 256 + 5
        if c < 5:
            v = int.from_bytes(s.b[s.p:s.p + c], "little"); s.p += c; return v
        n = 256 - c
        v = int.from_bytes(s.b[s.p:s.p + n], "little"); s.p += n
        return v - (1 << (8 * n))
    def raw(s):
        n = s.fix(); v = s.b[s.p:s.p + n]; s.p += n; return v
    def sym(s):
        c = chr(s.byte())
        if c == ":":
            v = s.raw().decode("utf-8", "replace"); s.syms.append(v); return v
        if c == ";":
            return s.syms[s.fix()]
        raise ValueError("symbol expected, got %r" % c)
    def reg(s, v):
        s.objs.append(v)
    def load(s):
        c = chr(s.byte())
        if c == "0": return None
        if c == "T": return True
        if c == "F": return False
        if c == "i": return s.fix()
        if c in ":;": s.p -= 1; return s.sym()
        if c == '"':
            v = s.raw(); s.reg(v); return v.decode("utf-8", "replace")
        if c == "I":
            v = s.load(); n = s.fix()
            for _ in range(n): s.sym(); s.load()
            return v
        if c == "[":
            n = s.fix(); a = []; s.reg(a)
            for _ in range(n): a.append(s.load())
            return a
        if c in "{}":
            n = s.fix(); d = {}; s.reg(d)
            for _ in range(n):
                k = s.load(); v = s.load()
                try: d[k] = v
                except TypeError: d[str(k)] = v
            if c == "}": s.load()
            return d
        if c == "@": return s.objs[s.fix()]
        if c == "f":
            v = s.raw(); s.reg(v)
            try: return float(v)
            except ValueError: return 0.0
        if c == "l":
            sign = s.byte(); n = s.fix()
            v = int.from_bytes(s.b[s.p:s.p + 2 * n], "little"); s.p += 2 * n; s.reg(v)
            return v if sign == ord("+") else -v
        if c in "oS":
            cls = s.sym(); o = {"__class__": cls}; s.reg(o); n = s.fix()
            for _ in range(n): k = s.sym(); o[k] = s.load()
            return o
        if c == "u":
            cls = s.sym(); data = s.raw(); o = {"__class__": cls, "__dump__": data}; s.reg(o); return o
        if c == "U":
            cls = s.sym(); o = {"__class__": cls}; s.reg(o); o["__data__"] = s.load(); return o
        if c in "eC":
            s.sym(); return s.load()
        if c == "/":
            v = s.raw(); s.byte(); s.reg(v); return v
        if c in "cmM":
            v = s.raw(); s.reg(v); return v
        raise ValueError("Marshal type %r at %d" % (c, s.p))

NB_POKEMON = 576    # Settings::NB_POKEMON

# GameData::Species (Data/species.dat) and GameData::Type (Data/types.dat)
SPECIES = Marshal(read_dat(os.path.join(ROOT, "Data", "species.dat"))).load()
TYPES = Marshal(read_dat(os.path.join(ROOT, "Data", "types.dat"))).load()
# F-DATA-01 SpeciesTweaks: KIF's type order for these three
for _sym, _t in {"FERROSEED": ("GRASS", "STEEL"), "FERROTHORN": ("GRASS", "STEEL"),
                 "PHANTUMP": ("GHOST", "GRASS")}.items():
    if _sym in SPECIES:
        SPECIES[_sym]["@type1"], SPECIES[_sym]["@type2"] = _t

def messages():
    # Species#name / #category / #pokedex_entry: MessageTypes.get(Species = 1 / Kinds = 2 /
    # Entries = 3, id_number), else @real_*. KIF Beta ships no english.dat, so MessageTypes
    # reads Data/messages.dat. Parsing it takes seconds: cached beside this script.
    path = os.path.join(ROOT, "Data", "messages.dat")
    st = os.stat(path)
    key = "%d:%d" % (st.st_size, int(st.st_mtime))
    cache = os.path.join(HERE, "dex_cache.json")
    try:
        c = json.load(open(cache, encoding="utf-8"))
        if c.get("messages_key") == key:
            return c["names"], c["kinds"], c["entries"]
    except Exception:
        pass
    m = Marshal(read_dat(path))
    assert chr(m.byte()) == "["
    m.fix()
    m.load()
    lists = [m.load(), m.load(), m.load()]
    out = []
    for lst in lists:
        out.append({str(i): lst[i] for i in range(1, NB_POKEMON + 1)
                    if isinstance(lst, list) and i < len(lst) and lst[i]})
    try:
        json.dump({"messages_key": key, "names": out[0], "kinds": out[1], "entries": out[2]},
                  open(cache, "w", encoding="utf-8"), ensure_ascii=False)
    except Exception:
        pass
    return out[0], out[1], out[2]

MSG_NAMES, MSG_KINDS, MSG_ENTRIES = messages()

def species(key):
    if isinstance(key, str) and key.isdigit():
        key = int(key)
    if isinstance(key, str):
        key = key.upper()
    sp = SPECIES.get(key)
    if sp is None:
        raise SystemExit("species %r is not in Data/species.dat" % key)
    return sp

def sp_name(sp):
    return MSG_NAMES.get(str(sp["@id_number"])) or sp["@real_name"]

def sp_kind(sp):
    return MSG_KINDS.get(str(sp["@id_number"])) or sp["@real_category"]

def sp_entry(sp):
    return MSG_ENTRIES.get(str(sp["@id_number"])) or sp["@real_pokedex_entry"] or ""

def type_number(t):
    return TYPES[t]["@id_number"]

#-------------------------------------------------------------------------------
# Text (as in party_backdrop.py): Power Green 29 / Power Green Small 25 (F-UI-03
# Default), drawn by mkxp-z at floor(size * 0.9). KIF's Bitmap#draw_text passes
# the text's own height, so the ascent line sits at y; too-wide text is squeezed.
#-------------------------------------------------------------------------------
FONT_FILES = {"system": ("power green.ttf", 29), "small": ("power green small.ttf", 25)}
_fonts = {}

def font(kind):
    if kind not in _fonts:
        fn, size = FONT_FILES[kind]
        _fonts[kind] = ImageFont.truetype(os.path.join(ROOT, "Fonts", fn), int(size * 0.9))
    return _fonts[kind]

def text_width(kind, s):
    return int(round(font(kind).getlength(s))) if s else 0

def line_height(kind):
    a, d = font(kind).getmetrics()
    return a + abs(d)

def union(a, b):
    if a is None: return b
    if b is None: return a
    return [min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3])]

def draw_sprite(dst, img, x, y, ox=0, oy=0, src=None, clip=None):
    # unscaled sprite / Bitmap#blt: quad at (x - ox, y - oy), src_rect crop, clip rect
    if src is not None:
        sx, sy, sw, sh = src
        img = img.crop((max(0, sx), max(0, sy), min(img.width, sx + sw), min(img.height, sy + sh)))
    left, top = int(x) - int(ox), int(y) - int(oy)
    cx0, cy0, cx1, cy1 = (0, 0, dst.width, dst.height) if clip is None else \
        (max(0, clip[0]), max(0, clip[1]), min(dst.width, clip[0] + clip[2]), min(dst.height, clip[1] + clip[3]))
    a0, b0 = max(left, cx0), max(top, cy0)
    a1, b1 = min(left + img.width, cx1), min(top + img.height, cy1)
    if a1 <= a0 or b1 <= b0:
        return None
    dst.alpha_composite(img.crop((a0 - left, b0 - top, a1 - left, b1 - top)), (a0, b0))
    return [a0, b0, a1 - a0, b1 - b0]

def draw_text(bmp, x, y, w, text, align, kind, color):
    # Bitmap#draw_text(x, y, w, text_size.height, text, align); returns the ink box
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
    if not ink:
        return None
    # clipped to the bitmap, as the drawn pixels are
    r = [max(ax + ink[0], 0), max(y + ink[1], 0), min(ax + ink[2], bmp.width), min(y + ink[3], bmp.height)]
    return r if r[2] > r[0] and r[3] > r[1] else None

def pbDrawShadowText(bmp, x, y, w, s, base, shadow, kind):
    # 010_DrawText: y += 4; shadow at (+2,0) (0,+2) (+2,+2), then the base
    y += 4
    ink = None
    if shadow and shadow[3] > 0:
        for dx, dy in [(2, 0), (0, 2), (2, 2)]:
            ink = union(ink, draw_text(bmp, x + dx, y + dy, w, s, 0, kind, shadow))
    bi = draw_text(bmp, x, y, w, s, 0, kind, base) if base and base[3] > 0 else None
    return {"ascent_y": y, "ink": union(ink, bi), "base_ink": bi}

def pbDrawTextPositions(bmp, textpos, kind="system"):
    # [text, x, y, align, base, shadow]: y + 6; align 1 = right, 2 = centre (by text width)
    out = []
    for s, x, y, al, base, shadow in textpos:
        tw = text_width(kind, s)
        y = y + 6
        if al is True or al == 1:
            x -= tw
        elif al == 2:
            x -= tw // 2
        r = pbDrawShadowText(bmp, x, y, tw, s, base, shadow, kind)
        r["text"] = s
        r["box"] = [x, r["ascent_y"], tw, line_height(kind)]
        out.append(r)
    return out

def ink_rect(ink, ox=0, oy=0):
    return [ink[0] + ox, ink[1] + oy, ink[2] - ink[0], ink[3] - ink[1]] if ink else None

def text_info(r, ox=0, oy=0, kind="system"):
    b = r["box"]
    return {"text": r.get("text"), "box": [b[0] + ox, b[1] + oy, b[2], b[3]],
            "ink": ink_rect(r["ink"], ox, oy), "base_ink": ink_rect(r["base_ink"], ox, oy)}

def getLineBrokenChunks(kind, value, width):
    # 010_DrawText#getLineBrokenChunks(plain = true): [word, x, y, width, 32]
    x = y = 0
    ret = []
    if width <= 0:
        return ret
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
            continue
        ret.append([word, x, y, tw, 32])
        x += tw
    return ret

def drawTextEx(bmp, x, y, width, numlines, text, base, shadow, kind="system"):
    # getLineBrokenChunks + renderLineBrokenChunksWithShadow (draw_text width + 2,
    # lines with chunk y < numlines * 32)
    chunks = getLineBrokenChunks(kind, text, width)
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
        ln = lines.setdefault(wy, {"x": tx, "ascent_y": ty, "width": 0, "text": "", "ink": None})
        ln["width"] = wx + ww - (ln["x"] - x)
        ln["text"] += word
        ln["ink"] = union(ln["ink"], union(ink, bi))
    return [lines[k] for k in sorted(lines)]

#-------------------------------------------------------------------------------
# Front sprite as the game loads it (BaseSpriteExtracter): the alt letter's
# 96x96 cell of spritesheets_base/<n>.png (10 columns, letter index "" = 0,
# "a" = 1, ...), stretch_blt x3 to 288x288; PokemonSprite with Center origin
# (ox = oy = 144) at zoom 2/3 -> 192x192 on screen (nearest, = 2x the cell).
#-------------------------------------------------------------------------------
SPRITE_SIZE = 96
SHEETS = G("CustomBattlers", "spritesheets", "spritesheets_base")

def letters_to_index(letters):
    i = 0
    for ch in letters.lower():
        i = i * 26 + (ord(ch) - ord("a") + 1)
    return i

def base_sprite_cell(num, alt=""):
    path = os.path.join(SHEETS, "%d.png" % num)
    if not os.path.exists(path):
        # handle_unloaded_sprites: Settings::DEFAULT_SPRITE_PATH
        p = G("Battlers", "Special", "000.png")
        return load(p), rel(p) + " (sheet missing: DEFAULT_SPRITE_PATH)", None
    sheet = load(path)
    idx = letters_to_index(alt)
    sx, sy = (idx % 10) * SPRITE_SIZE, (idx // 10) * SPRITE_SIZE
    if sy + SPRITE_SIZE > sheet.height:
        raise SystemExit("sprite letter %r is outside %s" % (alt, rel(path)))
    cell = Image.new("RGBA", (SPRITE_SIZE, SPRITE_SIZE), (0, 0, 0, 0))
    cell.alpha_composite(sheet.crop((sx, sy, sx + SPRITE_SIZE, sy + SPRITE_SIZE)))
    return cell, rel(path), [sx, sy, SPRITE_SIZE, SPRITE_SIZE]

def draw_front_sprite(screen, cell, cx, cy):
    # scale_bitmap(3) then the sprite at zoom 2/3, Center origin
    big = cell.resize((cell.width * 3, cell.height * 3), Image.NEAREST)
    zw, zh = int(big.width * 2 / 3), int(big.height * 2 / 3)
    shown = big.resize((zw, zh), Image.NEAREST)
    ox, oy = big.width // 2, big.height // 2
    left, top = cx - int(ox * 2 / 3), cy - int(oy * 2 / 3)
    draw_sprite(screen, shown, left, top)
    vis = shown.getchannel("A").getbbox()
    return {"bitmap_size": [big.width, big.height], "zoom": "2/3 (Settings::FRONTSPRITE_SCALE)",
            "anchor": [cx, cy], "origin": [ox, oy], "rect": [left, top, zw, zh],
            "opaque_rect": [left + vis[0], top + vis[1], vis[2] - vis[0], vis[3] - vis[1]] if vis else None}

def save(screen, info):
    out = args.out
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    screen.convert("RGB").save(out)
    base_name, ext = os.path.splitext(out)
    screen.convert("RGB").resize((W * 2, H * 2), Image.NEAREST).save(base_name + "@2x" + ext)
    with open(base_name + ".json", "w", encoding="utf-8") as f:
        json.dump(info, f, indent=1, ensure_ascii=False)
    print("saved", out)

BASE, SHADOW = C(88, 88, 80), C(168, 184, 184)
if DARK:
    BASE, SHADOW = SHADOW, BASE
WHITE, BLACK = C(248, 248, 248), C(0, 0, 0)
FONTS_INFO = {"system": "Fonts/power green.ttf (Power Green) size 29 -> drawn at 26 px",
              "small": "Fonts/power green small.ttf (Power Green Small) size 25 -> drawn at 22 px"}

#===============================================================================
# List screen
#===============================================================================
def parse_set(spec, universe):
    spec = (spec or "").strip().lower()
    if spec in ("", "none"):
        return set()
    if spec == "all":
        return set(universe)
    out = set()
    for part in spec.split(","):
        part = part.strip()
        if not part:
            continue
        if "-" in part:
            a, b = part.split("-", 1)
            out.update(range(int(a), int(b) + 1))
        else:
            out.add(int(part))
    return out

def parse_extras(spec):
    ext = {}
    if not spec.strip():
        return ext
    for e in re.split(r",(?=\s*\d+:)", spec):
        e = e.strip()
        if not e:
            continue
        f = e.split(":", 3)
        if len(f) < 3:
            ap.error("--extra entry needs number:Name:SYMBOL[:sprite.png] -> %r" % e)
        num = int(f[0])
        if num <= NB_POKEMON:
            ap.error("--extra %d: numbers 1-%d are PIF's own species" % (num, NB_POKEMON))
        path = f[3].strip() if len(f) > 3 and f[3].strip() else None
        if path and not os.path.exists(path):
            ap.error("--extra %d: sprite %s not found" % (num, path))
        ext[num] = {"name": f[1], "symbol": f[2].upper(), "sprite": path}
    return ext

def run_list():
    extras = parse_extras(args.extra)
    universe = list(range(1, NB_POKEMON + 1)) + sorted(extras)
    seen = parse_set(args.seen, range(1, NB_POKEMON + 1)) | set(extras)
    owned = parse_set(args.owned, universe) & set(universe)
    seen |= owned                       # owned implies seen
    # pbGetDexList: [id_number, name, 0, 0, i + 1, 0] for each seen species, in
    # order (MODENUMERICAL sorts by [4]); the number shown is [4] - 1 = i
    # ([5] = 0 is truthy in Ruby). --unseen-rows keeps the unseen ones.
    dexlist = []
    for n in universe:
        if n not in seen and not args.unseen_rows:
            continue
        if n in extras:
            name = extras[n]["name"]
        else:
            name = sp_name(species(n))
        dexlist.append({"number": n, "name": name, "seen": n in seen, "owned": n in owned, "extra": n in extras})
    # pbRefreshDexList (MODENUMERICAL): unseen species at the end of the list are removed
    while dexlist and not dexlist[-1]["seen"]:
        dexlist.pop()
    if not dexlist:
        ap.error("nothing is seen: the list is empty (the game doesn't open the Pokédex then)")
    numbers = [d["number"] for d in dexlist]
    count = len(dexlist)

    # Window_Pokedex.new(206, 30, 276, 364): windowskin nil -> borderX/Y 32,
    # contents (244 x 332) at (222, 46); rows of 32 -> page_row_max 10
    WX, WY, WW, WH = 206, 30, 276, 364
    CX, CY = WX + 16, WY + 16
    CW, CH = WW - 32, WH - 32
    ROW = 32
    page_rows = CH // ROW
    sel_num = int(args.sel) if args.sel is not None else numbers[0]
    if sel_num not in numbers:
        ap.error("--sel %d is not listed (unseen species are left out of the list)" % sel_num)
    sel = numbers.index(sel_num)
    # priv_update_cursor_rect: top_row = row - (page_row_max - 1) / 2, clamped
    game_top = max(min(sel - (page_rows - 1) // 2, count - page_rows), 0)
    if args.top is not None:
        t = int(args.top)
        cand = [i for i, n in enumerate(numbers) if n >= t]
        top = cand[0] if cand else count - 1
        top = max(0, min(top, count - 1))
    else:
        top = game_top
    if not (top <= sel < top + page_rows):
        ap.error("--sel %d is off the page that starts at %d (rows %d-%d)" %
                 (sel_num, numbers[top], numbers[top], numbers[min(top + page_rows, count) - 1]))

    screen = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    info = {"screen": [W, H], "state": "list", "dark_mode": DARK, "fonts": FONTS_INFO,
            "text_colours": {"base": list(BASE[:3]), "shadow": list(SHADOW[:3]),
                             "title_base": list(WHITE[:3]), "title_shadow": list(BLACK[:3])}}

    # addBackgroundPlane "background" (Pokedex/bg_list, plane z 0)
    bg_path = dex_pic("bg_list")
    draw_sprite(screen, load(bg_path), 0, 0)

    # @sprites["icon"]: PokemonSprite at (112, 196), Center, zoom 2/3 (z 0,
    # made after the window but drawn below it: the window is z 100)
    sel_entry = dexlist[sel]
    sprite_info = None
    if sel_entry["seen"]:
        if sel_entry["extra"]:
            ex = extras[sel_num]
            if not ex["sprite"]:
                ap.error("--extra %d has no sprite path" % sel_num)
            cell = Image.open(ex["sprite"]).convert("RGBA")
            if cell.size != (SPRITE_SIZE, SPRITE_SIZE):
                cell = cell.crop((0, 0, SPRITE_SIZE, SPRITE_SIZE))
            src, cellr = ex["sprite"], None
        else:
            cell, src, cellr = base_sprite_cell(sel_num, args.alt)
        sprite_info = draw_front_sprite(screen, cell, 112, 196)
        sprite_info["file"] = src
        if cellr:
            sprite_info["cell"] = cellr
            sprite_info["alt_letter"] = args.alt
    info["sprite"] = sprite_info

    # @sprites["overlay"] (512x384, z 0): pbRefresh
    ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    textpos = [["Pokédex", W // 2, -2, 2, WHITE, BLACK]]
    if sel_entry["seen"]:
        textpos.append([sel_entry["name"], 112, 46, 2, BASE, SHADOW])
    seen_count = args.seen_count if args.seen_count is not None else sum(1 for d in dexlist if d["seen"])
    owned_count = args.owned_count if args.owned_count is not None else sum(1 for d in dexlist if d["owned"])
    textpos += [["Seen:", 42, 302, 0, BASE, SHADOW],
                [str(seen_count), 182, 302, 1, BASE, SHADOW],
                ["Owned:", 42, 334, 0, BASE, SHADOW],
                [str(owned_count), 182, 334, 1, BASE, SHADOW]]
    tp = pbDrawTextPositions(ov, textpos)
    info["title"] = text_info(tp[0])
    i0 = 1
    if sel_entry["seen"]:
        info["species_name"] = text_info(tp[1])
        i0 = 2
    info["counts"] = {"seen_label": text_info(tp[i0]), "seen_value": text_info(tp[i0 + 1]),
                      "owned_label": text_info(tp[i0 + 2]), "owned_value": text_info(tp[i0 + 3]),
                      "seen": seen_count, "owned": owned_count,
                      "anchors": {"labels_x": 42, "values_right_x": 182, "seen_y": 302, "owned_y": 334}}
    # slider (icon_slider): arrows at 468,48 / 468,346, box between y 78 and 346
    slider = load(DEX("icon_slider"))
    sl = {"up_arrow": None, "down_arrow": None, "box": None}
    showslider = False
    if top > 0:
        draw_sprite(ov, slider, 468, 48, src=(0, 0, 40, 30))
        sl["up_arrow"] = [468, 48, 40, 30]
        showslider = True
    if top + page_rows < count:
        draw_sprite(ov, slider, 468, 346, src=(0, 30, 40, 30))
        sl["down_arrow"] = [468, 346, 40, 30]
        showslider = True
    if showslider:
        sliderheight = 268
        row_max = count
        boxheight = sliderheight * page_rows // row_max
        boxheight += min((sliderheight - boxheight) // 2, sliderheight // 6)
        boxheight = max(boxheight, 40)
        y = 78 + (sliderheight - boxheight) * top // (row_max - page_rows)
        draw_sprite(ov, slider, 468, y, src=(40, 0, 40, 8))
        i = 0
        while i * 16 < boxheight - 8 - 16:
            h = min(boxheight - 8 - 16 - i * 16, 16)
            draw_sprite(ov, slider, 468, y + 8 + i * 16, src=(40, 8, 40, h))
            i += 1
        draw_sprite(ov, slider, 468, y + boxheight - 16, src=(40, 24, 40, 16))
        sl["box"] = [468, y, 40, boxheight]
        sl["track"] = [468, 78, 40, sliderheight]
    info["slider"] = sl
    draw_sprite(screen, ov, 0, 0)

    # Window_Pokedex contents: drawItem for the page's rows, then drawCursor
    contents = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    own_icon = load(DEX("icon_own"))
    seen_icon_path = dex_pic("icon_seen")
    seen_icon = load(seen_icon_path)
    rows = []
    for idx in range(top, min(top + page_rows, count)):
        d = dexlist[idx]
        ry = (idx - top) * ROW                            # itemRect: y = idx * 32 - virtualOy
        rx, rw = 16, CW - 16                               # drawItem: x + 16, width - 16
        icon = None
        if d["seen"]:
            ib = own_icon if d["owned"] else seen_icon
            draw_sprite(contents, ib, rx - 6, ry + 8)
            icon = [CX + rx - 6, CY + ry + 8, ib.width, ib.height]
            num_s = "%03d" % d["number"]
            text = "%s%s %s" % (num_s, " ", d["name"])
        else:
            num_s = "%03d" % d["number"]
            text = "%s  ----------" % num_s
        r = pbDrawShadowText(contents, rx + 36, ry + 6, rw, text, BASE, SHADOW, "system")
        tx, ty = CX + rx + 36, CY + r["ascent_y"]
        lh = line_height("system")
        name_x = tx + text_width("system", num_s + "  ")
        rows.append({
            "index": idx, "number": d["number"], "name": d["name"], "seen": d["seen"], "owned": d["owned"],
            "extra": d["extra"], "selected": idx == sel,
            "row_rect": [CX, CY + ry, CW, ROW],
            "icon": ("own" if d["owned"] else "seen") if d["seen"] else None, "icon_rect": icon,
            "text": text,
            "text_box": [tx, ty, text_width("system", text), lh],
            "number_box": [tx, ty, text_width("system", num_s), lh],
            "name_box": [name_x, ty, text_width("system", d["name"]), lh] if d["seen"] else None,
            "text_ink": ink_rect(r["ink"], CX, CY),
            # draw_text box (x + 52, width 228) clipped to the 244 px contents
            "text_area": [tx, ty, min(rw, CW - (rx + 36)), lh]})
    cur = load(DEX("cursor_list"))
    cy0 = (sel - top) * ROW
    draw_sprite(contents, cur, 0, cy0)                     # drawCursor: selarrow at the row's top-left
    cvis = cur.getchannel("A").getbbox()
    # the window (z 100) is drawn over the overlay; contents src_rect (0, 0, 244, 332)
    draw_sprite(screen, contents, CX, CY, clip=(CX, CY, CW, CH))
    info["window"] = {"rect": [WX, WY, WW, WH], "contents_rect": [CX, CY, CW, CH],
                      "visible_contents_rect": [CX, CY, CW, min(CH, H - CY)],
                      "row_height": ROW, "rows_per_page": page_rows,
                      "row_layout": {"icon": "row x + 10, row y + 8 (28x28)",
                                     "text": "row x + 52, row y + 6 (+4 pbDrawShadowText), width 228",
                                     "format": "sprintf('%03d%s %s', number, ' ', name)"}}
    info["rows"] = rows
    info["cursor"] = {"rect": [CX, CY + cy0, cur.width, cur.height],
                      "graphic_rect": [CX + cvis[0], CY + cy0 + cvis[1], cvis[2] - cvis[0], cvis[3] - cvis[1]],
                      "graphic": "Graphics/Pictures/Pokedex/cursor_list.png",
                      "note": "blitted into the window contents after the rows (over their text), 244x44 "
                              "so it reaches 12 px into the next row"}
    info["list"] = {"count": count, "first_number": numbers[0], "last_number": numbers[-1],
                    "top_index": top, "top_number": numbers[top], "selected_index": sel, "selected_number": sel_num,
                    "game_top_number": numbers[game_top], "top_matches_game": top == game_top,
                    "extras": {str(k): {"name": v["name"], "symbol": v["symbol"], "sprite": v["sprite"]}
                               for k, v in extras.items()}}
    if top != game_top:
        print("note: --top %d differs from where the game scrolls for --sel %d (top %d)" %
              (numbers[top], sel_num, numbers[game_top]))
    # (outer edges incl. the 2-4 px black border, measured from bg_list.png)
    info["panels"] = {"header_bar": [0, 0, 512, 40], "name_box": [4, 48, 216, 40], "counts_box": [4, 304, 216, 72],
                      "list_panel": [224, 48, 240, 328], "list_red_strip": [228, 52, 36, 320],
                      "list_pink_line": [264, 52, 4, 320], "list_white_area": [268, 52, 192, 320],
                      "slider_track": [482, 74, 12, 276]}
    info["graphics"] = {"background": rel(bg_path), "cursor": "Graphics/Pictures/Pokedex/cursor_list.png",
                        "icon_own": "Graphics/Pictures/Pokedex/icon_own.png", "icon_seen": rel(seen_icon_path),
                        "slider": "Graphics/Pictures/Pokedex/icon_slider.png"}
    info["notes"] = ("Rects are [x, y, w, h] in 512x384 screen pixels. Text 'box' starts at the ascent line "
                     "(mkxp-z draws the line top at y) with the advance width and font height; 'ink' is the "
                     "drawn pixels including the shadow. Draw order: bg_list < species sprite < overlay "
                     "(title, name, counts, slider) < Pokedex window (z 100: rows, then cursor_list). "
                     "KIF Beta lists only seen species (pbGetDexList); its Seen/Owned numbers also count "
                     "seen/owned fusions, which this list leaves out unless --seen-count/--owned-count say so.")
    save(screen, info)

#===============================================================================
# Info page (PokemonPokedexInfo_Scene, page 1)
#===============================================================================
def action_key_name():
    # KIF::Keys.name(Input::ACTION): the first keyboard key bound to button A (11)
    # in keybindings.mkxp1 (System.data_directory first, then Data/), else "Z"
    names = {225: "Shift", 229: "Shift", 224: "Ctrl", 228: "Ctrl", 226: "Alt", 230: "Alt", 44: "Space",
             40: "Enter", 41: "Esc", 42: "Bksp", 43: "Tab"}
    for i in range(26):
        names[4 + i] = chr(ord("A") + i)
    for n in range(1, 10):
        names[29 + n] = str(n)
    names[39] = "0"
    path = os.path.join(ROOT, "Data", "keybindings.mkxp1")
    try:
        data = open(path, "rb").read()
        n = struct.unpack("<l", data[8:12])[0]
        for i in range(n):
            t, code, _x, target = struct.unpack("<4l", data[12 + i * 16:28 + i * 16])
            if t == 1 and target == 11 and code in names:
                return names[code], "Data/keybindings.mkxp1"
    except Exception:
        pass
    return "Z", "default"

def credits_for(name):
    path = os.path.join(ROOT, "Data", "sprites", "Sprite_Credits.csv")
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for line in f:
                row = line.split(",")
                if row[0] == name:
                    return row[1]
    except OSError:
        pass
    return None

def run_info():
    if args.species is None:
        ap.error("info needs --species")
    sp = species(args.species)
    num = sp["@id_number"]
    owned = not args.not_owned
    screen = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    info = {"screen": [W, H], "state": "info page 1", "dark_mode": DARK, "fonts": FONTS_INFO,
            "species": {"number": num, "symbol": sp["@id"], "name": sp_name(sp)}, "owned": owned,
            "text_colours": {"base": list(BASE[:3]), "shadow": list(SHADOW[:3]),
                             "title_base": list(WHITE[:3]), "title_shadow": list(BLACK[:3])}}
    # @sprites["background"]: IconSprite Pokedex/bg_info
    bg_path = dex_pic("bg_info")
    draw_sprite(screen, load(bg_path), 0, 0)
    # @sprites["infosprite"]: PokemonSprite at (104, 136), Center, zoom 2/3; the
    # pif sprite from obtain_pif_sprite -> select_new_pif_base_sprite
    cell, src, cellr = base_sprite_cell(num, args.alt)
    si = draw_front_sprite(screen, cell, 104, 136)
    si.update({"file": src, "cell": cellr, "alt_letter": args.alt})
    info["sprite"] = si

    ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    textpos = [["%03d  %s" % (num, sp_name(sp)), 246, 36, 0, WHITE, BLACK]]
    entry_lines, page_lines, types = [], [], []
    hw = {}
    if owned:
        textpos.append(["%s Pokémon" % sp_kind(sp), 246, 68, 0, BASE, SHADOW])
        weight_value = sp["@weight"] / 10.0
        height_value = sp["@height"] / 10.0
        if args.units == "us":
            weight_value = ruby_round((weight_value / 0.45359) * 10) / 10.0
            weight_unit = "lbs"
            total_inches = ruby_round(height_value / 0.0254)
            height_text = "%d'%d\"" % (total_inches // 12, total_inches % 12)
        else:
            weight_unit = "kg"
            height_text = "%r %s" % (height_value, "m")
        weight_text = "%r %s" % (weight_value, weight_unit)
        textpos.append([height_text, 224, 102, 0, BASE, SHADOW])
        textpos.append([weight_text, 224, 124, 0, BASE, SHADOW])
        hw = {"height": height_text, "weight": weight_text}
        # drawEntryText: species entry, 150 characters per page, drawTextEx at
        # (40, 244), width 432, 4 lines; "1/2" at (425, 340) when there are 2
        words = sp_entry(sp).split()
        pages, cur = [], ""
        for w_ in words:
            if len(cur) + len(w_) + 1 > 150:
                pages.append(cur.strip())
                cur = w_
            else:
                if cur:
                    cur += " "
                cur += w_
        if cur:
            pages.append(cur.strip())
        if not pages:
            pages = [""]
        ep = max(0, min(args.entry_page - 1, len(pages) - 1))
        if len(pages) > 1:
            page_lines = drawTextEx(ov, 425, 340, W - 80, 4, "%d/%d" % (ep + 1, len(pages)), BASE, SHADOW)
        entry_lines = drawTextEx(ov, 40, 244, W - 80, 4, pages[ep], BASE, SHADOW)
        info["entry_pages"] = len(pages)
        info["entry_page"] = ep + 1
        # type icons: icon_types rows of 32 by GameData::Type id_number
        tb = load(DEX("icon_types"))
        t1, t2 = sp["@type1"], sp["@type2"] or sp["@type1"]
        draw_sprite(ov, tb, 300, 120, src=(0, type_number(t1) * 32, 96, 32))
        types.append({"type": t1, "rect": [300, 120, 96, 32], "row": type_number(t1)})
        if t1 != t2:
            draw_sprite(ov, tb, 400, 120, src=(0, type_number(t2) * 32, 96, 32))
            types.append({"type": t2, "rect": [400, 120, 96, 32], "row": type_number(t2)})
    else:
        textpos.append(["????? Pokémon", 246, 68, 0, BASE, SHADOW])
    sprite_name = "%d%s" % (num, args.alt)
    sprite_author = credits_for(sprite_name) or ""
    dex_author = "Game Freak" if num <= NB_POKEMON else "Auto-generated"
    textpos.append(["Sprite: %s" % sprite_author, 224, 156, 0, BASE, SHADOW])
    if owned:
        textpos.append(["Entry:  %s" % dex_author, 224, 188, 0, BASE, SHADOW])
    tp = pbDrawTextPositions(ov, textpos)
    own_rect = None
    if owned:
        oi = load(DEX("icon_own"))
        draw_sprite(ov, oi, 212, 44)
        own_rect = [212, 44, oi.width, oi.height]
    # F-POKE-06 DexEvolutions#kif_draw_evo_hint: small font, right-aligned at 502, 2
    hint = None
    key_name, key_src = (args.hint_key, "--hint-key") if args.hint_key else action_key_name()
    if not args.no_kif_hint:
        hp = pbDrawTextPositions(ov, [["%s: Evolutions" % key_name, 502, 2, 1, WHITE, C(160, 40, 48)]], "small")
        hint = text_info(hp[0])
        hint["key_source"] = key_src
        hint["colours"] = {"base": [248, 248, 248], "shadow": [160, 40, 48]}
    draw_sprite(screen, ov, 0, 0)

    k = 0
    info["title"] = text_info(tp[k]); k += 1
    info["category"] = text_info(tp[k]); k += 1
    if owned:
        info["height"] = text_info(tp[k]); k += 1
        info["weight"] = text_info(tp[k]); k += 1
    info["sprite_credit"] = text_info(tp[k]); k += 1
    if owned:
        info["entry_credit"] = text_info(tp[k]); k += 1
    info["own_icon"] = own_rect
    info["types"] = types
    info["kif_hint"] = hint
    lh = line_height("system")
    info["entry_text"] = {"area": [40, 244, W - 80, 4 * 32], "line_height": 32,
                          "lines": [{"text": l["text"], "box": [l["x"], l["ascent_y"], l["width"], lh],
                                     "ink": ink_rect(l["ink"])} for l in entry_lines]}
    if page_lines:
        info["entry_text"]["page_number"] = {"text": page_lines[0]["text"],
                                             "box": [page_lines[0]["x"], page_lines[0]["ascent_y"],
                                                     page_lines[0]["width"], lh],
                                             "ink": ink_rect(page_lines[0]["ink"])}
    info["values"] = dict(hw, category="%s Pokémon" % sp_kind(sp) if owned else "????? Pokémon",
                          sprite_credit=sprite_author, entry_credit=dex_author if owned else None,
                          units=args.units)
    # boxes baked into bg_info (for mockups that redraw a panel)
    # (outer edges incl. the 2 px black border, measured from bg_info.png)
    info["panels"] = {"tabs_bar": [0, 0, 512, 36], "title_box": [208, 40, 292, 68],
                      "title_box_red_band": [210, 42, 288, 32], "title_box_pink_line_y": [74, 77], "size_box": [208, 110, 86, 48],
                      "credits_box": [208, 160, 292, 68], "credits_divider_y": 194,
                      "entry_box": [12, 236, 488, 136]}
    info["graphics"] = {"background": rel(bg_path), "icon_own": "Graphics/Pictures/Pokedex/icon_own.png",
                        "icon_types": "Graphics/Pictures/Pokedex/icon_types.png"}
    info["notes"] = ("Rects are [x, y, w, h]; text 'box' = ascent line + advance width + font height, 'ink' = "
                     "drawn pixels with shadow. Overlay order: entry text, type icons, text lines, icon_own, "
                     "KIF hint. The INFO / SPRITES tabs are part of bg_info.")
    save(screen, info)

if args.screen == "list":
    run_list()
else:
    run_info()
