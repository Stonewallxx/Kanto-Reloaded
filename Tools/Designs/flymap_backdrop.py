# Builds KIF Beta's Town Map / Fly map (PIF 6.8.2 BetterRegionMap, Kanto) for
# UI mockups, e.g. weather on the Fly map. Placement follows KIF Beta's code:
#   052_InfiniteFusion/Menus/BetterRegionMap.rb   BetterRegionMap#initialize, add_map_icons,
#                                                 init_cursor_position, center_window,
#                                                 move_cursor_to, adjust_window_if_not_visited_regions,
#                                                 update_text_at_location, update (arrows)
#   053_PIF_Hoenn/DynamicWeather/UI/DynamicWeather_TownMap.rb   draw_all_weather,
#                                                 get_full_weather_icon_name, update_weather_text,
#                                                 get_current_map_weather_icon
#   052_InfiniteFusion/System/DisplayText.rb      Kernel.pbDisplayText (the weather captions)
#   049_Compatibility/MarinUtilities.rb           SpriteHash#x= (moves only the sprites in
#                                                 @window), TextSprite, center_origins
#   Data/town_map.dat                             region 0: [nil, "map/map.png", points]
#   Data/messages.dat                             RegionNames[0] = "Map" (english.dat is not
#                                                 shipped, so MessageTypes uses the fallback)
# KIF Beta is the Kanto game: map/map.png (820x628), Johto to the left of x 352,
# the Sevii Islands below. $game_weather only exists in Hoenn (SaveData
# registers it under IF_HOENN), so in KIF Beta the weather parts never run:
# --weather simulates it for mockups.
# Final, settled state: cursor and fly icons on frame 0 (the fly wing shown),
# arrows at their resting place, the location text of the cursor's tile.
# Writes out.png, out@2x.png and out.json (the rectangles mockups draw over).
#
# Usage: python flymap_backdrop.py "<KIF Beta>" out.png --cursor 40,3 [--player 40,3 | --player none]
#          [--fly | --weather-mode]
#          [--weather "40,3:Rain:6;42,3:Rain:3;39,5:Rain:4;43,8:Storm:5;36,9:Sunny:5;43,11:Fog:4;43,1:Snow:3"]
#          [--no-cursor] [--visited all|none|"Pallet Town,Viridian City,..."] [--snap]
#          [--johto] [--sevii] [--postgame] [--opening-text]
#          [--weather-game-tiles] [--weather-unshifted] [--no-current-weather-icon]
#          [--icon-dir DIR]
import sys, os, math, json, argparse, re
import numpy as np
from PIL import Image, ImageFont, ImageDraw

W, H = 512, 384
HERE = os.path.dirname(os.path.abspath(__file__))

ap = argparse.ArgumentParser()
ap.add_argument("root")
ap.add_argument("out")
ap.add_argument("--cursor", default="40,3", help="tile x,y the cursor is on")
ap.add_argument("--player", default=None, help="tile x,y of location_icon (default: the cursor tile); 'none' hides it")
ap.add_argument("--fly", action="store_true", help="pbBetterRegionMap(-1, true, true): the Fly map")
ap.add_argument("--weather-mode", action="store_true", help="pbWeatherMap: wall map, show_weather")
ap.add_argument("--weather", default="", help='"x,y:Type:intensity;..." (Rain, Storm, Sunny, Fog, Wind, Snow, '
                                               'Sandstorm, HeavyRain, StrongWinds, HarshSun, Ash)')
ap.add_argument("--no-cursor", action="store_true")
ap.add_argument("--visited", default="all", help="fly spots counted as visited: all / none / comma list of names")
ap.add_argument("--snap", action="store_true", help="fly mode: apply on_stop_moving's snap to a fly spot within 2 tiles")
ap.add_argument("--johto", action="store_true", help="been_to_johto: the window may scroll left of x -352")
ap.add_argument("--sevii", action="store_true", help="been_to_sevii: the window may scroll down")
ap.add_argument("--postgame", action="store_true", help="map/map_postgame instead of map/map")
ap.add_argument("--opening-text", action="store_true",
                help="the text as the map opens (update_text runs before the cursor is placed: tile 0,0)")
ap.add_argument("--weather-game-tiles", action="store_true",
                help="weather keyed by town-map map id and drawn on that map's first tile, as draw_all_weather does")
ap.add_argument("--weather-unshifted", action="store_true",
                help="PIF's literal placement: @weatherIcons is not in @window, so the icons ignore the map scroll")
ap.add_argument("--no-current-weather-icon", action="store_true",
                help="leave out @sprites['weather'] (the player's map weather at 446,34)")
ap.add_argument("--icon-dir", default=None, help="extra weather icon folder searched first")
ap.add_argument("--dark", action="store_true", help="isDarkMode: Pokegear/bg_dark (hidden under mapbg anyway)")
args = ap.parse_args()
if args.fly and args.weather_mode:
    ap.error("--fly and --weather-mode are different screens (pbWeatherMap has can_fly = false)")

ROOT = args.root
G = lambda *p: os.path.join(ROOT, "Graphics", *p)
_cache = {}

def load(path):
    if path not in _cache:
        _cache[path] = Image.open(path).convert("RGBA")
    return _cache[path]

def ruby_round(v):
    return int(math.floor(v + 0.5)) if v >= 0 else -int(math.floor(-v + 0.5))

#-------------------------------------------------------------------------------
# Ruby Marshal (town_map.dat, messages.dat)
#-------------------------------------------------------------------------------
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

def region_name():
    # pbGetMessage(MessageTypes::RegionNames = 18, 0) from the fallback table
    # (Data/messages.dat, Encryption.xor). Cached beside this script.
    path = os.path.join(ROOT, "Data", "messages.dat")
    st = os.stat(path)
    key = "%d:%d" % (st.st_size, int(st.st_mtime))
    cache = os.path.join(HERE, "flymap_cache.json")
    try:
        c = json.load(open(cache, encoding="utf-8"))
        if c.get("messages_key") == key:
            return c["region_name"]
    except Exception:
        pass
    raw = np.fromfile(path, dtype=np.uint8)
    k = np.array([0x4A, 0x8F, 0x2C, 0xE1, 0x73, 0xB5, 0x96, 0x0D,
                  0x5E, 0xA2, 0x3F, 0xC7, 0x81, 0x14, 0x6B, 0xD9], dtype=np.uint8)
    dec = (raw ^ np.resize(k, raw.shape)).tobytes()
    m = Marshal(dec)
    assert chr(m.byte()) == "["
    m.fix()
    for _ in range(18):
        m.load()
    names = m.load()
    name = names[0] if isinstance(names, list) and names and names[0] else ""
    try:
        json.dump({"messages_key": key, "region_name": name}, open(cache, "w", encoding="utf-8"))
    except Exception:
        pass
    return name

TOWN = Marshal(open(os.path.join(ROOT, "Data", "town_map.dat"), "rb").read()).load()[0]
POINTS = TOWN[2]       # [x, y, name, poi, map_id, fly_x, fly_y, switch]

def loc_at(x, y):
    # find_location_at_position: the first entry on that tile
    for p in POINTS:
        if p[0] == x and p[1] == y:
            return p
    return None

def healing_spot(x, y):
    # pbGetHealingSpot: the first entry on the tile, needing map id + fly x/y
    p = loc_at(x, y)
    if p is None or p[4] is None or p[5] is None or p[6] is None:
        return None
    return (p[4], p[5], p[6])

#-------------------------------------------------------------------------------
# Text (as in party_backdrop.py): Power Green 29 drawn at floor(29 * 0.9);
# KIF's Bitmap#draw_text passes the text's own height, so the ascent line is at y
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
    # unscaled sprite: quad at (x - ox, y - oy), src_rect crop, viewport clip
    if src is not None:
        sx, sy, sw, sh = src
        img = img.crop((max(0, sx), max(0, sy), min(img.width, sx + sw), min(img.height, sy + sh)))
    left, top = int(x) - int(ox), int(y) - int(oy)
    cx0, cy0, cx1, cy1 = (0, 0, dst.width, dst.height) if clip is None else \
        (clip[0], clip[1], clip[0] + clip[2], clip[1] + clip[3])
    a0, b0 = max(left, cx0), max(top, cy0)
    a1, b1 = min(left + img.width, cx1), min(top + img.height, cy1)
    if a1 <= a0 or b1 <= b0:
        return None
    dst.alpha_composite(img.crop((a0 - left, b0 - top, a1 - left, b1 - top)), (a0, b0))
    return [a0, b0, a1 - a0, b1 - b0]

def draw_text(bmp, x, y, w, text, align, kind, color):
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

def pbDrawShadowText(bmp, x, y, w, s, base, shadow, kind):
    y += 4
    ink = None
    if shadow and shadow[3] > 0:
        for dx, dy in [(2, 0), (0, 2), (2, 2)]:
            ink = union(ink, draw_text(bmp, x + dx, y + dy, w, s, 0, kind, shadow))
    bi = draw_text(bmp, x, y, w, s, 0, kind, base) if base and base[3] > 0 else None
    return y, union(ink, bi)

def pbDrawTextPositions(bmp, textpos, kind="system"):
    out = []
    for s, x, y, al, base, shadow in textpos:
        tw = text_width(kind, s)
        y = y + 6
        if al is True or al == 1:
            x -= tw
        elif al == 2:
            x -= tw // 2
        ay, ink = pbDrawShadowText(bmp, x, y, tw, s, base, shadow, kind)
        out.append({"text": s, "box": [x, ay, tw, line_height(kind)],
                    "ink": [ink[0], ink[1], ink[2] - ink[0], ink[3] - ink[1]] if ink else None})
    return out

#-------------------------------------------------------------------------------
# Scene setup (BetterRegionMap#initialize)
#-------------------------------------------------------------------------------
def tile(s):
    x, y = s.split(",")
    return int(x), int(y)

cursor = tile(args.cursor)
player = None if (args.player or "").lower() == "none" else tile(args.player) if args.player else cursor
can_fly = args.fly
show_weather = args.weather_mode
wallmap = args.weather_mode
mode = "fly" if can_fly else ("weather" if show_weather else "town map")

TW = TH = 16
map_img = load(G("Pictures", "map", "map_postgame.png" if args.postgame else "map.png"))
MAPW, MAPH = map_img.size
MAPVP = (16, 32, 480, 320)                        # @mapvp / @mapoverlayvp
been_johto, been_sevii = args.johto, args.sevii

# visited fly spots (can_fly_to_location: healspot && visitedMaps[map id])
spot_tiles = [(p[0], p[1]) for p in POINTS if healing_spot(p[0], p[1]) and loc_at(p[0], p[1]) is p]
if args.visited == "all":
    visited = set(spot_tiles)
elif args.visited == "none":
    visited = set()
else:
    names = [n.strip().lower() for n in args.visited.split(",") if n.strip()]
    visited = set(t for t in spot_tiles if loc_at(*t)[2].lower() in names)
def can_fly_to(x, y):
    return healing_spot(x, y) is not None and (x, y) in visited

def find_nearby_spot(cx, cy, rng):
    # findNearbyHealingSpot: closest other visited spot within +-rng (x outer, y inner)
    best, bd = None, float("inf")
    for nx in range(cx - rng, cx + rng + 1):
        for ny in range(cy - rng, cy + rng + 1):
            if can_fly_to(nx, ny):
                d = math.sqrt((nx - cx) ** 2 + (ny - cy) ** 2)
                if d < bd and not (nx == cx and ny == cy):
                    bd, best = d, (nx, ny)
    return best

snap = find_nearby_spot(cursor[0], cursor[1], 2) if can_fly else None

# window placement. The map opens with init_cursor_position(player) +
# center_window() (+ adjust_window_if_not_visited_regions). The cursor then
# reaches its tile the way #main moves it: one tile per press, the cursor
# moving until it hits the edge (x < 480 / x > 16 / y <= 320 / y > 32 on
# screen), after that the map scrolling 16 px (left only after Johto, down
# only after Sevii). A fly-mode snap goes through move_cursor_to.
wminx = min(0, -(MAPW - W))
wminy = min(0, -(MAPH - H))
def adjust(wx, wy):
    if not been_johto and wx >= -352:
        wx = -352
    if not been_sevii and wy < 0:
        wy = 0
    return wx, wy
start = player if player else cursor
wx = wy = 0
cx0, cy0 = 16 + TW * start[0], 32 + TH * start[1]
if cx0 > W // 2:
    wx = max(W // 2 - cx0, wminx)
if cy0 > H // 2:
    wy = max(H // 2 - cy0, wminy)
wx, wy = adjust(wx, wy)

def walk(frm, to, wx, wy):
    cx, cy = frm
    while cx != to[0]:
        sx = 16 + TW * cx + wx
        if to[0] > cx:
            if sx < 480: cx += 1
            elif wx > -(MAPW - 480): cx += 1; wx -= TW
            else: break
        else:
            if sx > 16: cx -= 1
            elif wx < 0 and been_johto: cx -= 1; wx += TW
            else: break
    while cy != to[1]:
        sy = 32 + TH * cy + wy
        if to[1] > cy:
            if sy <= 320: cy += 1
            elif wy > -(MAPH - 320) and been_sevii: cy += 1; wy -= TH
            else: break
        else:
            if sy > 32: cy -= 1
            elif wy < 0: cy -= 1; wy += TH
            else: break
    return (cx, cy), wx, wy

def move_cursor_to(x, y, wx, wy):
    vx, vy = 16 + TW * x, 32 + TH * y          # (no window offset, as in the code)
    if vx < 16:
        wx = min(wx + (16 - vx), 0)
    elif vx > W - 16:
        wx = max(wx - (vx - (W - 16)), wminx)
    if vy < 32:
        wy = min(wy + (32 - vy), 0)
    elif vy > H - 32:
        wy = max(wy - (vy - (H - 32)), wminy)
    return adjust(wx, wy)

reached = start
if cursor != start:
    reached, wx, wy = walk(start, cursor, wx, wy)
cursor_reachable = reached == cursor
if args.snap and snap:
    wx, wy = move_cursor_to(snap[0], snap[1], wx, wy)
    cursor = snap

ORIGIN = (MAPVP[0] + wx, MAPVP[1] + wy)           # map pixel (0,0) on screen
def tile_rect(tx, ty):
    return [ORIGIN[0] + TW * tx, ORIGIN[1] + TH * ty, TW, TH]
def clip_rect(r, c=MAPVP):
    x0, y0 = max(r[0], c[0]), max(r[1], c[1])
    x1, y1 = min(r[0] + r[2], c[0] + c[2]), min(r[1] + r[3], c[1] + c[3])
    return [x0, y0, max(0, x1 - x0), max(0, y1 - y0)]

screen = Image.new("RGBA", (W, H), (0, 0, 0, 255))
info = {"screen": [W, H], "mode": mode,
        "call": {"fly": "pbBetterRegionMap(-1, true, true)", "weather": "pbWeatherMap",
                 "town map": "pbBetterRegionMap (Town Map item / pbShowMap)"}[mode],
        "map_image": "Graphics/Pictures/map/%s" % ("map_postgame.png" if args.postgame else "map.png"),
        "map_size": [MAPW, MAPH], "tile_size": [TW, TH],
        "map_area": list(MAPVP),
        "window_offset": [wx, wy],
        "map_origin_on_screen": list(ORIGIN),
        "tile_to_screen": "screen_x = %d + 16 * tile_x, screen_y = %d + 16 * tile_y (16x16; visible inside map_area)"
                          % ORIGIN,
        "been_to_johto": been_johto, "been_to_sevii": been_sevii}
map_on_screen = [ORIGIN[0], ORIGIN[1], MAPW, MAPH]
info["map_image_rect"] = map_on_screen
info["map_image_visible_rect"] = clip_rect(map_on_screen)

# --- @viewport (z 99999): background, bg_frame (mapbg), txt ---------------------
if wallmap:
    bgname = "map/bg_wall.png"
else:
    bgname = "Pokegear/bg_dark.png" if args.dark else "Pokegear/bg.png"
draw_sprite(screen, load(G("Pictures", *bgname.split("/"))), 0, 0)
draw_sprite(screen, load(G("Pictures", "mapbg.png")), 0, 0)    # opaque: hides the background
info["background"] = "Graphics/Pictures/%s (covered by mapbg.png, which is fully opaque)" % bgname
info["frame"] = {"file": "Graphics/Pictures/mapbg.png", "inner_map_area": list(MAPVP)}

# update_text_at_location: region name at 16,0; place name at 16,354; POI right-aligned at 496,354
REGION = region_name()
text_tile = (0, 0) if args.opening_text else cursor
loc = loc_at(*text_tile)
place = loc[2] if loc else ""
poi = loc[3] if loc and loc[3] else ""
WHITE, BLACK = (255, 255, 255, 255), (0, 0, 0, 255)
txt = Image.new("RGBA", (W, H), (0, 0, 0, 0))
tr = pbDrawTextPositions(txt, [[REGION, 16, 0, 0, WHITE, BLACK], [place, 16, 354, 0, WHITE, BLACK],
                               [poi, 496, 354, 1, WHITE, BLACK]])
draw_sprite(screen, txt, 0, 0)
info["texts"] = {"region_name": tr[0], "location_name": tr[1], "poi": tr[2],
                 "text_tile": list(text_tile),
                 "note": "drawn in @viewport (z 99999), under the map viewport: the map covers anything "
                         "below y 32 (the descender of 'Map')"}
if args.opening_text:
    info["texts"]["state"] = "as opened: update_text runs before init_cursor_position (regionMapSel = 0,0)"

# --- @mapvp (z 100000): map, fly points, weather icons ---------------------------
draw_sprite(screen, map_img, ORIGIN[0], ORIGIN[1], clip=MAPVP)

fly_points = []
if can_fly:
    # add_map_icons: x-major scan over 0...(w/16.0), 0...(h/16.0); mapFly frame 0
    flyimg = load(G("Pictures", "map", "mapFly.png"))
    fh = flyimg.height
    for x in range(0, math.ceil(MAPW / TW)):
        for y in range(0, math.ceil(MAPH / TH)):
            if can_fly_to(x, y):
                px, py = TW * x + TW // 2 + wx, TH * y + TH // 2 + wy
                r = draw_sprite(screen, flyimg, MAPVP[0] + px, MAPVP[1] + py, fh // 2, fh // 2,
                                src=(0, 0, fh, fh), clip=MAPVP)
                rect = [MAPVP[0] + px - fh // 2, MAPVP[1] + py - fh // 2, fh, fh]
                fly_points.append({"tile": [x, y], "name": loc_at(x, y)[2], "map_id": healing_spot(x, y)[0],
                                   "rect": rect, "visible_rect": r})
    info["fly_points"] = fly_points
    info["fly_icon"] = "Graphics/Pictures/map/mapFly.png frame 0 of 2 (32x32, tile-centred)"
    info["fly_snap"] = {"would_snap_to": list(snap) if snap else None, "applied": bool(args.snap and snap),
                        "rule": "on_stop_moving: closest other visited fly spot within 2 tiles"}

# weather (simulated $game_weather)
def weather_icon_name(wtype, inten):
    base = {"Sunny": "mapSun", "Rain": "mapRain", "Fog": "mapFog", "Wind": "mapWind", "Storm": "mapStorm",
            "Sandstorm": "mapSand", "Snow": "mapSnow", "HeavyRain": "mapHeavyRain",
            "StrongWinds": "mapStrongWinds", "HarshSun": "mapHarshSun", "Ash": "mapAsh"}.get(wtype)
    if base is None:
        return None
    if wtype in ("Sandstorm", "Snow", "StrongWinds", "HeavyRain", "HarshSun", "Ash"):
        return base
    return base + ("_light" if inten <= 2 else "_medium" if inten <= 4 else "_heavy")

ICON_DIRS = ([args.icon_dir] if args.icon_dir else []) + [
    G("Pictures", "Weather"),                                   # what the game loads (absent in KIF Beta)
    os.path.join(HERE, "wx", "icons"),                          # old KR icons (= PIF Hoenn's)
    "E:/Downloads/POKEMON/Github/Hoenn-Clean/Graphics/Pictures/Weather"]   # PIF Hoenn, full set
def find_icon(name):
    for d in ICON_DIRS:
        p = os.path.join(d, name + ".png")
        if os.path.exists(p):
            return p
    return None

def caption(wtype, inten):
    i = inten
    def band(a, b, c, d, e):
        if -1 <= i <= 2: return a
        if 3 <= i <= 4: return b
        if 5 <= i <= 6: return c
        if 7 <= i <= 8: return d
        return e
    if wtype == "Sandstorm": return "Sandstorm"
    if wtype == "Snow":    # 5..6 has no branch in PIF -> "Blizzard"
        return "Light Snow" if -1 <= i <= 2 else "Heavy Snow" if 3 <= i <= 4 else "Snowstorm" if 7 <= i <= 8 else "Blizzard"
    if wtype == "StrongWinds": return "Heavy Winds"
    if wtype == "HeavyRain": return "Heavy Rain"
    if wtype == "HarshSun": return "Drought"
    if wtype == "Sunny": return band("Mild sunshine", "Warm sunshine", "Bright sunshine", "Hot sunshine", "Scorching sun")
    if wtype == "Rain": return band("Light rain", "Moderate rain", "Heavy rain", "Severe rain", "Extreme rain")
    if wtype == "Fog": return band("Thin fog", "Moderate fog", "Thick fog", "Dense fog", "Very dense fog")
    if wtype == "Wind": return band("Light wind", "Moderate wind", "Strong wind", "High wind", "Extreme wind")
    if wtype == "Storm":
        return band("Light thunderstorm", "Moderate thunderstorm", "Heavy thunderstorm",
                    "Severe thunderstorm", "Extreme thunderstorm")
    if wtype == "Ash": return "Volcanic Ash"
    return None

def intensity_text(wtype, inten):
    i = max(1, min(10, inten))
    if wtype == "Sandstorm": return "%d km/h" % (8 * i + 15)
    if wtype == "Snow": return "%s cm/h" % round(0.5 * i, 1)
    if wtype == "StrongWinds": return "%d km/h" % (10 * i + 40)
    if wtype == "HeavyRain": return "%d mm/h" % (5 * i + 5)
    if wtype == "HarshSun": return "%d °C" % (34 + ruby_round(i * 1.4))
    if wtype == "Sunny": return "%d °C" % (21 + ruby_round(i * 1.4))
    if wtype == "Rain": return "%d mm/h" % (2 * i)
    if wtype == "Ash": return "%s cm/h" % round(0.5 * i, 1)
    if wtype == "Fog": return "%d m visibility" % (1100 - i * 100)
    if wtype == "Wind": return "%d km/h" % (7 * i + 8)
    if wtype == "Storm": return "%d mm/h" % (2 * i)
    return ""

weather = []
for part in [p for p in args.weather.split(";") if p.strip()]:
    t, wtype, inten = part.strip().split(":")
    weather.append({"tile": tile(t), "type": wtype, "intensity": int(inten)})

def game_weather_lookup():
    # $game_weather.current_weather[map_id], from the requested tiles' own entries
    by_map = {}
    for w in weather:
        l = loc_at(*w["tile"])
        if l and l[4] is not None and l[4] not in by_map:
            by_map[l[4]] = w
    return by_map

weather_icons = []
missing_icons = set()
if weather:
    if args.weather_game_tiles:
        # draw_all_weather: x-major tile scan; every entry with a map id that has
        # weather gets the icon once, on the first tile found
        by_map = game_weather_lookup()
        placements, seen = [], set()
        for x in range(0, math.ceil(MAPW / TW)):
            for y in range(0, math.ceil(MAPH / TH)):
                for l in POINTS:
                    if l[0] == x and l[1] == y and l[4] is not None and l[4] not in seen and l[4] in by_map:
                        placements.append(((x, y), by_map[l[4]], l[4]))
                        seen.add(l[4])
        skipped = [w for w in weather if not (loc_at(*w["tile"]) and loc_at(*w["tile"])[4] is not None)]
    else:
        placements = [(w["tile"], w, (loc_at(*w["tile"]) or [None] * 5)[4]) for w in weather]
        skipped = []
    for (x, y), w, mid in placements:
        name = weather_icon_name(w["type"], w["intensity"])
        e = {"requested_tile": list(w["tile"]), "tile": [x, y], "type": w["type"], "intensity": w["intensity"],
             "icon": name, "town_map_map_id": mid}
        p = find_icon(name) if name else None
        if not p:
            missing_icons.add(name)
            e["file"] = None
            weather_icons.append(e)
            continue
        img = load(p)
        ih = img.height
        sx, sy = (0, 0) if args.weather_unshifted else (wx, wy)
        px, py = TW * x + TW // 2 + sx, TH * y + TH // 2 + sy
        r = draw_sprite(screen, img, MAPVP[0] + px, MAPVP[1] + py, ih // 2, ih // 2,
                        src=(0, 0, ih, ih), clip=MAPVP)
        e.update(file=p.replace("\\", "/"), size=[ih, ih],
                 rect=[MAPVP[0] + px - ih // 2, MAPVP[1] + py - ih // 2, ih, ih], visible_rect=r)
        weather_icons.append(e)
    info["weather_icons"] = weather_icons
    info["weather_placement"] = ("draw_all_weather (by town-map map id, first tile)" if args.weather_game_tiles
                                 else "at the requested tiles (mockup)")
    if skipped:
        info["weather_not_drawable_by_game"] = [list(w["tile"]) for w in skipped]
    info["weather_icon_search"] = [d.replace("\\", "/") for d in ICON_DIRS]
    if missing_icons:
        info["weather_icons_missing"] = sorted(n for n in missing_icons if n)

# --- @mapoverlayvp (z 100001): player icon (areahighlight is empty) -------------
if player:
    pimg = load(G("Pictures", "map", "location_icon.png"))
    px = int(TW * player[0] + TW / 2.0) + wx
    py = int(TH * player[1] + TH / 2.0) + wy
    r = draw_sprite(screen, pimg, MAPVP[0] + px, MAPVP[1] + py, pimg.width // 2, pimg.height // 2, clip=MAPVP)
    info["player_icon"] = {"tile": list(player), "file": "Graphics/Pictures/map/location_icon.png",
                           "rect": [MAPVP[0] + px - pimg.width // 2, MAPVP[1] + py - pimg.height // 2,
                                    pimg.width, pimg.height], "visible_rect": r}

# --- @viewport2 (z 100001, full screen): arrows (z 0), cursor (z 11), weather (z 5000)
arrows = {}
ar, ad = load(G("Pictures", "mapArrowRight.png")), load(G("Pictures", "mapArrowDown.png"))
vis = {"left": wx < 0 and been_johto, "right": wx > -(MAPW - 480),
       "up": wy < 0, "down": wy > -(MAPH - 320) and been_sevii}
spec = {"left": (ar.transpose(Image.FLIP_LEFT_RIGHT), 12, H // 2),
        "right": (ar, W - 12, H // 2),
        "up": (ad.transpose(Image.ROTATE_180), W // 2, 24),
        "down": (ad, W // 2, H - 24)}
for k in ["left", "right", "up", "down"]:
    img, ax, ay = spec[k]
    rect = [ax - img.width // 2, ay - img.height // 2, img.width, img.height]
    if vis[k]:
        draw_sprite(screen, img, ax, ay, img.width // 2, img.height // 2)
    arrows[k] = {"visible": vis[k], "rect": rect}
info["arrows"] = arrows

cur_img = load(G("Pictures", "mapCursor.png"))
ch = cur_img.height
co = (ch - TW) // 2                                   # ox = oy = (32 - 16) / 2.0
ccx, ccy = 16 + TW * cursor[0] + wx, 32 + TH * cursor[1] + wy
info["cursor"] = {"tile": list(cursor), "tile_rect": [ccx, ccy, TW, TH],
                  "sprite_rect": [ccx - co, ccy - co, ch, ch], "frame": 0, "drawn": not args.no_cursor,
                  "on_screen": MAPVP[0] <= ccx < MAPVP[0] + MAPVP[2] and MAPVP[1] <= ccy < MAPVP[1] + MAPVP[3],
                  "start_tile": list(start)}
if not cursor_reachable:
    info["cursor"]["note"] = ("the arrow keys can't get there from %s (stops at %s: Johto / Sevii not visited "
                              "or the map edge); drawn at the requested tile anyway" % (list(start), list(reached)))
if not args.no_cursor:
    draw_sprite(screen, cur_img, ccx, ccy, co, co, src=(0, 0, ch, ch))

# @sprites["weather"]: the player's map weather, top-left at 446,34, whole bitmap
cur_weather = None
if weather and player and not args.no_current_weather_icon:
    if args.weather_game_tiles:
        l = loc_at(*player)
        w = game_weather_lookup().get(l[4]) if l and l[4] is not None else None
    else:
        w = next((w for w in weather if w["tile"] == player), None)
    if w:
        name = weather_icon_name(w["type"], w["intensity"])
        p = find_icon(name) if name else None
        if p:
            img = load(p)
            draw_sprite(screen, img, 446, 34)
            cur_weather = {"file": p.replace("\\", "/"), "rect": [446, 34, img.width, img.height],
                           "weather": [w["type"], w["intensity"]]}
info["current_map_weather_icon"] = cur_weather

# --- Kernel.pbDisplayText (no viewport, z 9999999): weather captions --------------
captions = None
if show_weather and weather and not args.opening_text:
    if args.weather_game_tiles:
        l = loc_at(*cursor)
        w = game_weather_lookup().get(l[4]) if l and l[4] is not None else None
    else:
        w = next((w for w in weather if w["tile"] == cursor), None)
    if w:
        c1, c2 = caption(w["type"], w["intensity"]), intensity_text(w["type"], w["intensity"])
        if c1 and c2:
            hud = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            LB, LS = (248, 248, 248, 255), (72, 80, 88, 255)          # LIGHT_TEXT_MAIN / SHADOW
            captions = pbDrawTextPositions(hud, [[c1, 400, 25, 2, LB, LS], [c2, 400, 50, 2, LB, LS]])
            draw_sprite(screen, hud, 0, 0)
info["weather_captions"] = captions

info["notes"] = [
    "Rects are [x, y, w, h] in 512x384 screen pixels; text 'box' starts at the ascent line, 'ink' includes the shadow.",
    "Draw order: Pokegear bg < mapbg frame < texts (z 99999) < map, fly icons, weather icons (map viewport "
    "16,32,480,320, z 100000) < player icon (z 100001) < arrows < cursor < current-map weather icon "
    "(full-screen z 100001) < weather captions (z 9999999).",
    "Without been_to_johto the window is pinned at x -352 (map pixels 352..831 visible; the map is only 820 wide, "
    "so screen x 484..495 shows the frame's blue); without been_to_sevii it is pinned at y 0.",
    "Kanto's town_map.dat gives map ids only to the 35 fly-spot tiles; the game keys weather by map id, so "
    "draw_all_weather could only ever draw on those tiles. The player icon too (getPlayerPosition finds the "
    "current map's entry, else the last visited town)."]
if missing_icons:
    info["notes"].append("weather icons not found anywhere: %s" % ", ".join(sorted(n for n in missing_icons if n)))

out = args.out
os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
screen.convert("RGB").save(out)
base_name, ext = os.path.splitext(out)
screen.convert("RGB").resize((W * 2, H * 2), Image.NEAREST).save(base_name + "@2x" + ext)
with open(base_name + ".json", "w", encoding="utf-8") as f:
    json.dump(info, f, indent=1, ensure_ascii=False)
print("saved", out)
