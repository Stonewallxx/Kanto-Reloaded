# Builds a KIF Beta Elite Battle DX (EBDX) battle screen for the battle mockups:
# singles (Pikachu vs a wild Gyarados) or doubles (Pikachu + Lapras vs wild
# Gyarados + Onix), with the command menu, the fight menu or no menu open.
# Placement follows KIF Beta's own EBDX code (Data/Scripts/660_EBDX):
#   006 Vector + 017 DefaultMetrics      camera vector, battler metrics
#   008 BattleSceneRoom                  backdrop, sky, clouds, trees, grass
#   010 PokeBattle_SceneEBDX             battler sprites, round shadows
#   007 DataBoxEBDX / CommandWindowEBDX / FightWindowEBDX   the UI
# plus KIF's own hooks (990_KIF: GameFont, Battle Info's 5th INFO button).
# Final, settled state: camera on the MAIN vector, menus after show(), no
# idle bob / wind / cloud scroll, selector on its first animation frame.
# Also writes <out>.json with the rectangles mockups draw over.
#
# Usage: python ebdx_backdrop.py "<KIF Beta>" out.png singles|doubles command|fight|target|none
#          [--moves "Discharge:13:1:15/15,Iron Tail:8:0:15/15,Dig:4:0:10/10,Quick Attack:0:0:30/30"]
#          [--sel 0] [--cmd 0] [--sprites base|autogen] [--no-info] [--owned]
#          [--genders m,m,f,m] [--exp 40] [--sel-frame 0] [--no-movement]
#          [--kr-layers] [--no-selector]
#          [--fused-ally HEAD.BODY] [--fusion-sprite auto|custom|autogen] [--fusion-alt LETTER]
#          [--target 1] [--target-kind NearOther] [--fusion-icons]          (target: doubles only)
import sys, os, math, json, argparse
import numpy as np
from PIL import Image, ImageFont, ImageDraw

W, H = 512, 384

ap = argparse.ArgumentParser()
ap.add_argument("root")
ap.add_argument("out")
ap.add_argument("mode", choices=["singles", "doubles"])
ap.add_argument("menu", choices=["command", "fight", "target", "none"])
ap.add_argument("--moves", default="Discharge:13:1:15/15,Iron Tail:8:0:15/15,Dig:4:0:10/10,Quick Attack:0:0:30/30")
ap.add_argument("--sel", type=int, default=0, help="highlighted move (fight)")
ap.add_argument("--cmd", type=int, default=0, help="highlighted command (command)")
ap.add_argument("--sprites", choices=["base", "autogen"], default="base",
                help="base = the main custom sprite the game loads (spritesheets_base cell 0); autogen = old mockups")
ap.add_argument("--no-info", action="store_true", help="Battle Info off / 'No button': 4 commands, not 5")
ap.add_argument("--owned", action="store_true", help="wild foes already caught: owned ball on their boxes")
ap.add_argument("--genders", default="m,m,f,m", help="battlers 0,1,2,3: m / f / n (genderless)")
ap.add_argument("--exp", type=int, default=40, help="Pikachu's EXP bar, 0-100 px (singles only)")
ap.add_argument("--sel-frame", type=int, default=0, help="selector animation frame 0-3 (0 = corners outermost)")
ap.add_argument("--no-movement", action="store_true", help="'Battle Movement' Off: no idle sprite offset")
ap.add_argument("--kr-layers", action="store_true", help="Kanto Reloaded's overlap fix: the highlighted move button drawn on top")
ap.add_argument("--no-selector", action="store_true", help="leave out EBDX's fight selector (a mockup draws its own cursor)")
ap.add_argument("--no-foe", action="store_true", help="the foe has fainted: no foe sprite or databox (e.g. while EXP is handed out)")
ap.add_argument("--fused-ally", default=None, metavar="HEAD.BODY",
                help="doubles: battler 2 is this fusion (e.g. 135.131 = Jolteon head, Lapras body)")
ap.add_argument("--fusion-sprite", choices=["auto", "custom", "autogen"], default="auto",
                help="auto = what the game loads from the files on disk (custom sprite if listed and its sheet "
                     "is here, else the autogen sheet)")
ap.add_argument("--fusion-alt", default=None, help="custom sprite alt letter (default: first 'main' one)")
ap.add_argument("--target", type=int, default=1, help="target menu: battler the selector is on (default 1)")
ap.add_argument("--target-kind", default="NearOther",
                help="target menu: the move's target type (NearOther = Iron Tail / Dig / Quick Attack, "
                     "AllNearOthers = Discharge, NearFoe, Foe, Other, NearAlly, UserOrNearAlly, ...)")
ap.add_argument("--fusion-icons", action="store_true",
                help="target menu: the fusion's real icon (KIF::FusionIcon.build) instead of KIF's DNA placeholder")
args = ap.parse_args()
if args.menu == "target" and args.mode != "doubles":
    ap.error("the target menu only opens in doubles (pbChooseTarget is skipped in single battles)")
if args.fused_ally and args.mode != "doubles":
    ap.error("--fused-ally needs doubles (it replaces battler 2)")

ROOT = args.root
G = lambda *p: os.path.join(ROOT, "Graphics", *p)
UI = lambda n: G("EBDX", "Pictures", "UI", n + ".png")
DOUBLES = args.mode == "doubles"
_cache = {}

def load(path):
    if path not in _cache:
        _cache[path] = Image.open(path).convert("RGBA")
    return _cache[path]

def ti(v):
    # RGSS Sprite x/y/ox/oy are integers: Ruby's NUM2INT truncates toward zero
    return int(v)

#-------------------------------------------------------------------------------
# Sprite drawing the way mkxp-z does it: quad at (x - ox*zx, y - oy*zy),
# nearest-neighbour sampling at pixel centres, mirror flips the src_rect,
# color blends RGB toward the colour by its alpha, opacity scales alpha.
#-------------------------------------------------------------------------------
def draw_sprite(dst, img, x, y, ox=0, oy=0, zx=1.0, zy=1.0, src=None, mirror=False,
                color=None, opacity=255):
    if src is not None:
        sx, sy, sw, sh = src
        sx0, sy0 = max(0, sx), max(0, sy)
        sx1, sy1 = min(img.width, sx + sw), min(img.height, sy + sh)
        if sx1 <= sx0 or sy1 <= sy0:
            return None
        # a src_rect hanging off the bitmap keeps its offset (e.g. src_rect.y = -4)
        img = img.crop((sx0, sy0, sx1, sy1))
        ox -= (sx0 - sx)
        oy -= (sy0 - sy)
    if mirror:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    if zx <= 0 or zy <= 0:
        return None
    arr = np.asarray(img).astype(np.float64)
    if color is not None and color[3] > 0:
        a = color[3] / 255.0
        arr[..., :3] = arr[..., :3] * (1 - a) + np.array(color[:3], np.float64) * a
    if opacity < 255:
        arr[..., 3] *= opacity / 255.0
    sw, sh = img.size
    left, top = x - ox * zx, y - oy * zy
    right, bottom = left + sw * zx, top + sh * zy
    X0, X1 = max(0, math.ceil(left - 0.5)), min(dst.width, math.ceil(right - 0.5))
    Y0, Y1 = max(0, math.ceil(top - 0.5)), min(dst.height, math.ceil(bottom - 0.5))
    if X1 > X0 and Y1 > Y0:
        u = np.clip(np.floor((np.arange(X0, X1) + 0.5 - left) / zx).astype(int), 0, sw - 1)
        v = np.clip(np.floor((np.arange(Y0, Y1) + 0.5 - top) / zy).astype(int), 0, sh - 1)
        patch = arr[v][:, u]
        layer = Image.fromarray(np.clip(np.round(patch), 0, 255).astype(np.uint8), "RGBA")
        dst.alpha_composite(layer, (X0, Y0))
    return (left, top, sw * zx, sh * zy)

def blt(dst, src, x, y, rect=None):
    # Bitmap#blt: unscaled, blended
    if rect is not None:
        src = src.crop((rect[0], rect[1], rect[0] + rect[2], rect[1] + rect[3]))
    draw_sprite(dst, src, x, y)

#-------------------------------------------------------------------------------
# Text: KIF's MessageConfig (Power Green 29 / Power Green Small 25), drawn by
# mkxp-z at floor(size * 0.9). KIF's Bitmap#draw_text override passes the
# text's own height, so the ascent line sits at y (no vertical centring);
# horizontal align by advance width, too-wide text is squeezed.
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

def draw_text(bmp, x, y, w, text, align, kind, color):
    if not text or w <= 0 or color[3] <= 0:
        return
    f = font(kind)
    adv = text_width(kind, text)
    lh = line_height(kind)
    mask = Image.new("L", (adv + 8, lh + 8), 0)
    ImageDraw.Draw(mask).text((0, 0), text, font=f, fill=255)
    mask = mask.crop((0, 0, max(adv, 1), lh))
    if adv > w:
        mask = mask.resize((w, lh), Image.NEAREST)
        adv = w
    ax = x
    if align == 1:
        ax += (w - adv) // 2
    elif align == 2:
        ax += w - adv
    ax = max(ax, x)
    layer = Image.new("RGBA", mask.size, tuple(color[:3]) + (0,))
    layer.putalpha(mask.point(lambda m: m * color[3] // 255))
    draw_sprite(bmp, layer, ax, y)

def pbDrawOutlineText(bmp, x, y, w, h, s, base, shadow, align, kind):
    if shadow and shadow[3] > 0:
        for dx, dy in [(-2, -2), (0, -2), (2, -2), (-2, 0), (2, 0), (-2, 2), (0, 2), (2, 2)]:
            draw_text(bmp, x + dx, y + dy, w, s, align, kind, shadow)
    if base and base[3] > 0:
        draw_text(bmp, x, y, w, s, align, kind, base)

def pbDrawShadowText(bmp, x, y, w, h, s, base, shadow, align, kind):
    y += 4
    if shadow and shadow[3] > 0:
        for dx, dy in [(2, 0), (0, 2), (2, 2)]:
            draw_text(bmp, x + dx, y + dy, w, s, align, kind, shadow)
    if base and base[3] > 0:
        draw_text(bmp, x, y, w, s, align, kind, base)

def pbDrawTextPositions(bmp, textpos, kind):
    # returns the drawn text boxes (ascent-line top, advance width, line height)
    boxes = []
    for t in textpos:
        s, x, y, al, base, shadow = t[:6]
        tw = text_width(kind, s)
        y = y + 6
        if al is True or al == 1:
            x -= tw
        elif al == 2:
            x -= tw // 2
        pbDrawShadowText(bmp, x, y, tw, 0, s, base, shadow, 0, kind)
        boxes.append([x, y + 4, tw, line_height(kind)])
    return boxes

def darken(c, amt):
    # Color#darken -> Color.new(float...), truncated when used
    return (int(c[0] - c[0] * amt), int(c[1] - c[1] * amt), int(c[2] - c[2] * amt), 255)

WHITE = (255, 255, 255, 255)

#-------------------------------------------------------------------------------
# The battle (KIF Beta defaults: Default font, EBDX Camera Zoom Off, Type
# Display Off, Battle Info On -> INFO button, day time)
#-------------------------------------------------------------------------------
gmap = {"m": 0, "f": 1, "n": 2}
genders = [gmap.get(g.strip().lower(), 2) for g in args.genders.split(",")] + [2] * 4
BATTLERS = [
    dict(index=0, species=25, name="Pikachu", level=34, hp=78, total=95),
    dict(index=1, species=130, name="Gyarados", level=31, hp=57, total=104),
]
#-------------------------------------------------------------------------------
# Fusions (052_InfiniteFusion): dex = body * NB_POKEMON + head, name from
# SPLIT_NAMES (FusedSpecies#calculate_name), sprite from BattleSpriteLoader
#-------------------------------------------------------------------------------
NB_POKEMON = 576                                   # Settings::NB_POKEMON
GEN1 = ("BULBASAUR IVYSAUR VENUSAUR CHARMANDER CHARMELEON CHARIZARD SQUIRTLE WARTORTLE BLASTOISE CATERPIE "
        "METAPOD BUTTERFREE WEEDLE KAKUNA BEEDRILL PIDGEY PIDGEOTTO PIDGEOT RATTATA RATICATE SPEAROW FEAROW "
        "EKANS ARBOK PIKACHU RAICHU SANDSHREW SANDSLASH NIDORANfE NIDORINA NIDOQUEEN NIDORANmA NIDORINO NIDOKING "
        "CLEFAIRY CLEFABLE VULPIX NINETALES JIGGLYPUFF WIGGLYTUFF ZUBAT GOLBAT ODDISH GLOOM VILEPLUME PARAS "
        "PARASECT VENONAT VENOMOTH DIGLETT DUGTRIO MEOWTH PERSIAN PSYDUCK GOLDUCK MANKEY PRIMEAPE GROWLITHE "
        "ARCANINE POLIWAG POLIWHIRL POLIWRATH ABRA KADABRA ALAKAZAM MACHOP MACHOKE MACHAMP BELLSPROUT "
        "WEEPINBELL VICTREEBEL TENTACOOL TENTACRUEL GEODUDE GRAVELER GOLEM PONYTA RAPIDASH SLOWPOKE SLOWBRO "
        "MAGNEMITE MAGNETON FARFETCHD DODUO DODRIO SEEL DEWGONG GRIMER MUK SHELLDER CLOYSTER GASTLY HAUNTER "
        "GENGAR ONIX DROWZEE HYPNO KRABBY KINGLER VOLTORB ELECTRODE EXEGGCUTE EXEGGUTOR CUBONE MAROWAK "
        "HITMONLEE HITMONCHAN LICKITUNG KOFFING WEEZING RHYHORN RHYDON CHANSEY TANGELA KANGASKHAN HORSEA "
        "SEADRA GOLDEEN SEAKING STARYU STARMIE MRMIME SCYTHER JYNX ELECTABUZZ MAGMAR PINSIR TAUROS MAGIKARP "
        "GYARADOS LAPRAS DITTO EEVEE VAPOREON JOLTEON FLAREON PORYGON OMANYTE OMASTAR KABUTO KABUTOPS "
        "AERODACTYL SNORLAX ARTICUNO ZAPDOS MOLTRES DRATINI DRAGONAIR DRAGONITE MEWTWO MEW").split()

def species_symbol(n):
    if 1 <= n <= len(GEN1):
        return GEN1[n - 1]
    raise SystemExit("no species symbol for #%d (only Gen 1 is tabled)" % n)

_split = None
def split_names():
    global _split
    if _split is None:
        import re
        src = open(os.path.join(ROOT, "Data", "Scripts", "052_InfiniteFusion", "Fusion", "Data", "SplitNames.rb"),
                   encoding="utf-8").read()
        body, mapping = src.split("NAT_DEX_MAPPING", 1)
        _split = (re.findall(r'\["([^"]*)",\s*"([^"]*)"\]', body),
                  {int(a): int(b) for a, b in re.findall(r"(\d+)\s*=>\s*(\d+)", mapping)})
    return _split

def fusion_name(head, body):
    names, natdex = split_names()
    prefix = names[natdex.get(head, head)][0]
    suffix = names[natdex.get(body, body)][1]
    if prefix and suffix and prefix[-1] == suffix[0]:
        prefix = prefix[:-1]
    if prefix.endswith(" "):
        suffix = suffix.capitalize()
    return prefix + suffix

def fusion_sprite_choice(head, body):
    # BattleSpriteLoader#select_new_pif_fusion_sprite / load_fusion_sprite:
    # CUSTOM when Data/sprites/CUSTOM_SPRITES lists the pair and it has a "main"
    # (else "temp") letter in Sprite_Credits.csv; then the local indexed file,
    # then the custom spritesheet (downloaded when missing); AUTOGEN otherwise.
    import re
    letters = []
    for line in open(os.path.join(ROOT, "Data", "sprites", "CUSTOM_SPRITES"), encoding="utf-8"):
        m = re.match(r"^(\d+)\.(\d+)([a-zA-Z]*)\.png$", line.strip())
        if m and int(m.group(1)) == head and int(m.group(2)) == body:
            letters.append(m.group(3))
    status = {}
    name = "%d.%d" % (head, body)
    for line in open(os.path.join(ROOT, "Data", "sprites", "Sprite_Credits.csv"), encoding="utf-8", errors="replace"):
        if not line.startswith(name):
            continue
        row = line.strip().split(",")
        suffix = row[0][len(name):]
        if suffix == "" or suffix.isalpha():
            status[suffix] = row[2] if len(row) > 2 else ""
    main = sorted([k for k, v in status.items() if v == "main"], key=lambda s: (len(s), s))
    if not main:
        main = sorted([k for k, v in status.items() if v == "temp"], key=lambda s: (len(s), s))
    info = {"listed_custom_letters": letters, "main_letters": main}
    letter = args.fusion_alt if args.fusion_alt is not None else (main[0] if main else None)
    indexed = G("CustomBattlers", "local_sprites", "indexed", str(head), "%d.%d%s.png" % (head, body, letter or ""))
    sheet = G("CustomBattlers", "spritesheets", "spritesheets_custom", str(head), "%d%s.png" % (head, letter or ""))
    game_custom = bool(letters) and letter is not None
    info["game_would_use"] = "custom" if game_custom else "autogen"
    info["custom_on_disk"] = os.path.exists(indexed) or os.path.exists(sheet)
    want = args.fusion_sprite
    if want == "auto":
        want = "custom" if game_custom and info["custom_on_disk"] else "autogen"
        if game_custom and not info["custom_on_disk"]:
            info["note"] = "the game would download the custom sheet; autogen shown (what it shows offline)"
    if want == "custom":
        if os.path.exists(indexed):
            cell, src = load(indexed), indexed
        else:
            s = load(sheet)                                  # 20 columns (PIFSpriteExtracter::COLUMNS)
            cell, src = s.crop(((body % 20) * 96, (body // 20) * 96, (body % 20) * 96 + 96, (body // 20) * 96 + 96)), sheet
        info["used"], info["letter"] = "custom", letter
    else:
        s = load(G("Battlers", "spritesheets_autogen", "%d.png" % head))   # 10 columns, cell = body
        cell, src = s.crop(((body % 10) * 96, (body // 10) * 96, (body % 10) * 96 + 96, (body // 10) * 96 + 96)), \
            G("Battlers", "spritesheets_autogen", "%d.png" % head)
        info["used"] = "autogen"
    info["file"] = os.path.relpath(src, ROOT).replace("\\", "/")
    return cell, info

if DOUBLES:
    BATTLERS += [
        dict(index=2, species=131, name="Lapras", level=33, hp=118, total=134),
        dict(index=3, species=95, name="Onix", level=30, hp=66, total=66),
    ]
    if args.fused_ally:
        fh, fb = [int(v) for v in args.fused_ally.split(".")]
        cell, finfo = fusion_sprite_choice(fh, fb)
        BATTLERS[2].update(species=fb * NB_POKEMON + fh, name=fusion_name(fh, fb), fusion=(fh, fb),
                           cell=cell, fusion_info=finfo)
for b in BATTLERS:
    b["gender"] = genders[b["index"]]
    b["player"] = b["index"] % 2 == 0
if args.no_foe:
    BATTLERS[:] = [b for b in BATTLERS if b["player"]]
MOVES = []
for m in args.moves.split(","):
    name, typ, cat, pp = m.split(":")
    cur, tot = pp.split("/")
    MOVES.append(dict(name=name, type=int(typ), cat=int(cat), pp=int(cur), total=int(tot)))

# 017_EBDX_DefaultMetrics: vectors (x, y, angle, scale, zoom) and BATTLERPOS
VECTOR = (134, 328, 24, 262) if DOUBLES else (134, 328, 26, 242)
BATTLERPOS = {0: ((116, 92), (207, 205), (21, 21)), 1: ((234, 256), (152, 164), (11, 15)),
              2: ((116, 177), (207, 222), (21, 25)), 3: ((234, 198), (152, 152), (11, 11))}
ROOM_SCALE = 2.25                                  # EliteBattle::ROOM_SCALE

# BattleSceneRoom#update at the settled MAIN vector: bg at (x2, y2), ox/oy
# from sx/sy, zoom = ROOM_SCALE * 1.0**0.6
ang = math.radians(VECTOR[2])
sx = VECTOR[0] + math.cos(ang) * VECTOR[3]
sy = VECTOR[1] - math.sin(ang) * VECTOR[3]
BG = dict(x=ti(sx), y=ti(sy), ox=ti(sx / 1.5 - 16), oy=ti(sy / 1.5 + 16), zoom=ROOM_SCALE)

def room_pos(ex, ey):
    # BattleSceneRoom#position
    return (ti(BG["x"] - (BG["ox"] - ex) * BG["zoom"]), ti(BG["y"] - (BG["oy"] - ey) * BG["zoom"]))

# environment: EnvironmentEBDX::OUTDOOR + TerrainEBDX::TALLGRASS (merged by
# getDefaultEnvironmentData after getNextBattleEnv, so doubles keep all 7)
TREES = dict(x=[150, 271, 78, 288, 176, 42, 118, 348, 321], y=[108, 117, 118, 126, 126, 128, 136, 136, 145],
             zoom=[0.44, 0.44, 0.59, 0.59, 0.59, 0.64, 0.85, 0.7, 1],
             mirror=[False, False, True, True, True, False, False, True, False])
GRASS = dict(x=[124, 274, 204, 62, 248, 275, 182], y=[160, 140, 140, 185, 246, 174, 170],
             z=[2, 1, 2, 17, 27, 17, 17], zoom=[0.7, 0.35, 0.5, 1, 1.5, 0.7, 1],
             mirror=[False, True, False, True, False, True, False])

screen = Image.new("RGBA", (W, H), (0, 0, 0, 255))
info = {"screen": [W, H], "mode": args.mode, "menu": args.menu,
        "camera": {"vector": list(VECTOR), "bg": BG}}
scene = []          # (z, creation order, draw fn) for @viewport
def add(z, fn):
    scene.append((z, len(scene), fn))

# --- backdrop ---------------------------------------------------------------
bgbmp = load(G("EBDX", "Battlebacks", "battlebg", "Field.png"))
EL = lambda n: load(G("EBDX", "Battlebacks", "elements", n + ".png"))
add(0, lambda: draw_sprite(screen, bgbmp, BG["x"], BG["y"], BG["ox"], BG["oy"], BG["zoom"], BG["zoom"]))
sky = EL("skyDay")
def draw_sky():
    x, y = room_pos(0, sky.height)
    draw_sprite(screen, sky, x, y, 0, sky.height, BG["zoom"], BG["zoom"])
add(0, draw_sky)
for i in [1, 0]:                                   # clouds, coloured from the sky
    def draw_cloud(i=i):
        c = EL("cloud%d" % (i + 1))
        ey = [98, 91][i]
        x, y = room_pos(0, ey)
        col = sky.getpixel((0, ey))
        draw_sprite(screen, c, x, y, 0, c.height, BG["zoom"], BG["zoom"], color=(col[0], col[1], col[2], 255))
    add(0, draw_cloud)
sun = EL("sun")
def draw_sun():
    # day: oy = height*4, which puts the sun above the top of the screen
    x, y = room_pos(208, sky.height - 3)
    draw_sprite(screen, sun, x, y, sun.width // 2, sun.height * 4, BG["zoom"], BG["zoom"])
add(0, draw_sun)
tree = EL("tree")
for i in range(9):
    def draw_tree(i=i):
        t = tree.transpose(Image.FLIP_LEFT_RIGHT) if TREES["mirror"][i] else tree
        ex, ey = TREES["x"][i], TREES["y"][i]
        x, y = room_pos(ex, ey)
        col = bgbmp.getpixel((ex, ey))
        z = TREES["zoom"][i] * BG["zoom"]
        draw_sprite(screen, t, x, y, t.width // 2, t.height, z, z, color=(col[0], col[1], col[2], 255))
    add(1, draw_tree)
grass = EL("tallGrass")
for i in range(7):
    def draw_grass(i=i):
        g = grass.transpose(Image.FLIP_LEFT_RIGHT) if GRASS["mirror"][i] else grass
        ex, ey = GRASS["x"][i], GRASS["y"][i]
        x, y = room_pos(ex, ey)
        col = bgbmp.getpixel((ex, ey))
        z = GRASS["zoom"][i] * BG["zoom"]
        draw_sprite(screen, g, x, y, g.width // 2, g.height, z, z, color=(col[0], col[1], col[2], 255))
    add(GRASS["z"][i], draw_grass)

# --- battler sprites (KIF PokemonBattlerSprite) -------------------------------
def battler_bitmap(species, back, cell=None):
    if cell is not None:
        pass                                                  # fusion: chosen above
    elif args.sprites == "base":
        sheet = load(G("CustomBattlers", "spritesheets", "spritesheets_base", "%d.png" % species))
        cell = sheet.crop((0, 0, 96, 96))                      # main sprite (alt letter "")
    else:
        sheet = load(G("Battlers", "spritesheets_autogen", "%d.png" % species))
        c, r = species % 10, species // 10
        cell = sheet.crop((c * 96, r * 96, c * 96 + 96, r * 96 + 96))
    big = cell.resize((288, 288), Image.NEAREST)              # extractor scale 3
    if back:                                                  # BACKRPSPRITE_SCALE = 1
        return big
    return big.resize((192, 192), Image.NEAREST)              # FRONTSPRITE_SCALE = 2/3

def round_shadow():
    a = np.zeros((26, 100, 4), np.uint8)
    for py in range(26):
        for px in range(100):
            dx, dy = (px - 50.0) / 50.0, (py - 13.0) / 13.0
            d = math.sqrt(dx * dx + dy * dy)
            if d >= 1.0:
                continue
            a[py, px, 3] = int((1.0 - d) ** 1.2 * 255)
    return Image.fromarray(a, "RGBA")
RSHADOW = round_shadow()

def ruby_round(v):
    return int(math.floor(v + 0.5)) if v >= 0 else -int(math.floor(-v + 0.5))

def idle_offset(index, selected):
    # PokemonBattlerSprite#update(frameCounter = 0): the EBDX scene calls it
    # without a frame counter, so the "bob" is frozen at its frame-0 value
    if selected:                                   # @selected == 1 (fight menu)
        return 0                                   # (0 / QUARTER_ANIM_PERIOD) -> case 0 -> 0
    if args.no_movement:
        return 0
    fr = 40                                        # Graphics.frame_rate (001_MKXP_Compatibility)
    period, amp = fr * 4, 2
    phase = ruby_round(index * period * 0.7 / (2 * math.pi))
    t = (0 + phase) % period
    half = period / 2.0
    if t < half:
        return ruby_round((t / half) * amp * 2 - amp)
    return ruby_round(amp - ((t - half) / half) * amp * 2)

def clip_rect(r):
    x0, y0 = max(r[0], 0), max(r[1], 0)
    x1, y1 = min(r[0] + r[2], W), min(r[1] + r[3], H)
    return [x0, y0, max(0, x1 - x0), max(0, y1 - y0)]

col_n = 1 if DOUBLES else 0
yoff = 0 if DOUBLES else 25                                    # ebdxBattlerYOffset (1v1 only)
info["battlers"] = []
for b in sorted(BATTLERS, key=lambda b: b["index"]):
    i = b["index"]
    pos = BATTLERPOS[i]
    ex, ey, z = pos[0][col_n], pos[1][col_n], pos[2][col_n]
    bx, by = room_pos(ex, ey)
    bob = idle_offset(i, args.menu == "fight" and i == 0)      # pbSelectBattler(idxBattler) in the fight menu
    px, py = bx, by + yoff + bob
    bmp = battler_bitmap(b["species"], b["player"], b.get("cell"))
    ox, oy = bmp.width // 2, bmp.height
    def draw_mon(bmp=bmp, px=px, py=py, ox=ox, oy=oy, mirror=b["player"]):
        draw_sprite(screen, bmp, px, py, ox, oy, mirror=mirror)
    def draw_shadow(px=px, py=py):
        draw_sprite(screen, RSHADOW, px, py, 50, 26, 1.0, 0.16, opacity=int(255 * 0.55))
    add(z, draw_mon)
    add(z - 1, draw_shadow)
    vis = (bmp.transpose(Image.FLIP_LEFT_RIGHT) if b["player"] else bmp).getchannel("A").getbbox()
    full = [px - ox, py - oy, bmp.width, bmp.height]
    tight = [full[0] + vis[0], full[1] + vis[1], vis[2] - vis[0], vis[3] - vis[1]]
    info["battlers"].append({
        "index": i, "species": b["species"], "name": b["name"], "side": "player" if b["player"] else "foe",
        "sprite_rect": full, "opaque_rect": tight, "opaque_rect_onscreen": clip_rect(tight),
        "anchor_bottom_centre": [px, py], "idle_offset_y": bob, "z": z,
        "round_shadow_rect": [px - 50, py - 4, 100, 4],
        "back_sprite_mirrored": b["player"], "scale": 3 if b["player"] else 2,
        "metrics": {"ex": ex, "ey": ey}})
    if b.get("fusion"):
        info["battlers"][-1]["fusion"] = dict(head=b["fusion"][0], body=b["fusion"][1], **b["fusion_info"])

for _, _, fn in sorted(scene, key=lambda t: (t[0], t[1])):
    fn()

#-------------------------------------------------------------------------------
# @msgview: databoxes, command and fight windows (sorted by z, then creation)
#-------------------------------------------------------------------------------
ui = []
def uadd(z, fn, order=None):
    ui.append((z, len(ui) if order is None else order, fn))

# --- DataBoxEBDX --------------------------------------------------------------
databox_png, containers, barcolors = load(UI("dataBox")), load(UI("containers")), load(UI("barColors"))
owned_png = load(UI("battleBoxOwned"))
side0 = 2 if DOUBLES else 1
party1 = 2 if DOUBLES else 1
info["databoxes"] = []
# creation order: foes' boxes (rendered in loadWildBitmaps) then the player's
# (rendered again at send-out)
for b in sorted(BATTLERS, key=lambda b: (b["player"], b["index"])):
    i, player = b["index"], b["player"]
    showhp = player and not DOUBLES
    showexp = player and not DOUBLES
    defX = W - databox_png.width if player else 0
    defY = H - 130 if player else 52
    # DataBoxEBDX#defX / #defY
    if player:
        defX += (i // 2) * 8
    else:
        defX += (party1 - 1 - i // 2) * 8 - (party1 - 1) * 8
    if player and side0 > 1:
        defY -= 50 * ((2 - i) // 2) - 64 + (48 * (side0 - 1))
    if not player and DOUBLES:
        defY += 50 * (i // 2) - 16
    X, Y = defX, defY
    cont = (20 if player else 24, 6)
    name_e = ((22 if player else 26) - 16, -24)
    hp_e = (22 if player else 20, 9)
    hpbar = (cont[0] + 4, cont[1] + 2)
    expbar = (cont[0] + 4, cont[1] + 16)
    zone = 0
    if b["hp"] <= b["total"] * 0.50: zone = 1
    if b["hp"] <= b["total"] * 0.25: zone = 2
    hpw = b["hp"] * 168 / float(b["total"])
    expw = max(0, min(100, args.exp)) if showexp else 0

    # textName bitmap (container width + 32 x base height), small font
    tn = Image.new("RGBA", (containers.width + 32, databox_png.height), (0, 0, 0, 0))
    gstr = {0: "♂", 1: "♀"}.get(b["gender"], "")
    w = text_width("small", "%s%sLv.%d" % (b["name"], gstr, b["level"]))
    o = math.ceil((w - (168 + 4)) / 2.0) if w > 168 + 4 else 0
    nstr = b["name"] + " "
    shadow = (0, 0, 0, 125)
    pbDrawOutlineText(tn, 18 - o, 3, tn.width - 40, tn.height, nstr, WHITE, shadow, 0, "small")
    gx = text_width("small", nstr) + 18
    gcol = (53, 107, 208, 255) if b["gender"] == 0 else (180, 37, 77, 255)
    pbDrawOutlineText(tn, gx - o, 3, tn.width - 40, tn.height, gstr, gcol, shadow, 0, "small")
    lstr = "Lv.%d" % b["level"]
    pbDrawOutlineText(tn, 18 + o, 3, tn.width - 40, tn.height, lstr, WHITE, shadow, 2, "small")
    # textHP bitmap (container width x base height + 8)
    th = Image.new("RGBA", (containers.width, databox_png.height + 8), (0, 0, 0, 0))
    hstr = "%d/%d" % (b["hp"], b["total"])
    hp_box = None
    if showhp:
        hp_box = pbDrawTextPositions(th, [[hstr, th.width, 0, 1, WHITE, (0, 0, 0, 125)]], "small")[0]

    def draw_base(X=X, Y=Y, player=player):
        draw_sprite(screen, databox_png, X, Y, mirror=player)
    def draw_container(X=X, Y=Y, cont=cont, showexp=showexp):
        draw_sprite(screen, containers, X + cont[0], Y + cont[1], src=(0, 0, containers.width, 26 if showexp else 14))
    def draw_hp(X=X, Y=Y, zone=zone, hpw=hpw, hpbar=hpbar):
        col = barcolors.crop((zone * 2, 0, zone * 2 + 1, 6))
        draw_sprite(screen, col, X + hpbar[0], Y + hpbar[1], zx=hpw, zy=1.0)
    def draw_exp(X=X, Y=Y, expw=expw, expbar=expbar):
        col = barcolors.crop((0, 6, 1, 10))
        draw_sprite(screen, col, X + expbar[0], Y + expbar[1], zx=expw, zy=1.0)
    def draw_tn(X=X, Y=Y, tn=tn, name_e=name_e):
        draw_sprite(screen, tn, X + name_e[0], Y + name_e[1])
    def draw_owned(X=X, Y=Y, cont=cont):
        draw_sprite(screen, owned_png, X + cont[0] - 18, Y + cont[1] - 2)
    def draw_th(X=X, Y=Y, th=th, hp_e=hp_e):
        draw_sprite(screen, th, X + hp_e[0], Y + hp_e[1])
    uadd(0, draw_base)
    uadd(1, draw_container)
    uadd(1, draw_hp)
    uadd(1, draw_exp)
    uadd(9, draw_tn)
    if not player and args.owned:
        uadd(1, draw_owned)
    uadd(9, draw_th)

    tnx, tny = X + name_e[0], Y + name_e[1]
    lh = line_height("small")
    lw = text_width("small", lstr)
    box = {"index": i, "name": b["name"], "side": "player" if player else "foe",
           "rect": [X, Y, databox_png.width, databox_png.height], "mirrored": player,
           "visible_rect": [max(X, 0), Y, min(X + databox_png.width, W) - max(X, 0), databox_png.height],
           "container_rect": [X + cont[0], Y + cont[1], containers.width if showexp else containers.width, 26 if showexp else 14],
           "name_text": [tnx + 18 - o, tny + 3, text_width("small", b["name"]), lh],
           "level_text": [tnx + 18 + o + 168 - lw, tny + 3, lw, lh],
           "gender_text": [tnx + gx - o, tny + 3, text_width("small", gstr), lh] if gstr else None,
           "hp_bar": [X + hpbar[0], Y + hpbar[1], 168, 6], "hp_fill_w": int(math.ceil(hpw - 0.5)) if hpw > 0 else 0,
           "hp_zone": ["green", "yellow", "red"][zone], "hp": [b["hp"], b["total"]],
           "show_hp_numbers": showhp, "show_exp": showexp}
    if showhp:
        box["hp_text"] = [X + hp_e[0] + hp_box[0], Y + hp_e[1] + hp_box[1], hp_box[2], hp_box[3]]
    if showexp:
        box["exp_bar"] = [X + expbar[0], Y + expbar[1], 100, 4]
        box["exp_fill_w"] = expw
    if not player:
        box["owned_icon"] = [X + cont[0] - 18, Y + cont[1] - 2, owned_png.width, owned_png.height] if args.owned else None
    info["databoxes"].append(box)

# --- selector bitmap (pbSelBitmap from the 24x24 cmdSel) -----------------------
def sel_bitmap(rw, rh):
    bmp = load(UI("cmdSel"))
    qw, qh = bmp.width // 2, bmp.height // 2
    mw, mh = rw + qw * 2 - 8, rh + qh * 2 - 8
    full = Image.new("RGBA", (mw * 4, mh), (0, 0, 0, 0))
    for i in range(4):
        for j in range(4):
            m = i if i < 3 else i - 2
            x = (2 if j % 2 == 0 else -2) * m + mw * i + (0 if j % 2 == 0 else mw - qw)
            y = (2 if j // 2 == 0 else -2) * m + (0 if j // 2 == 0 else mh - qh)
            blt(full, bmp, x, y, (qw * (j % 2), qh * (j // 2), qw, qh))
    return full, mw, mh
frame = max(0, min(3, args.sel_frame))

# --- CommandWindowEBDX ---------------------------------------------------------
if args.menu == "command":
    btnCmd, btnEmp = load(UI("btnCmd")), load(UI("btnEmpty"))
    cmds = ["FIGHT", "BAG", "PARTY", "RUN"]
    if not args.no_info:
        cmds.append("INFO")                          # C-BATTLE-03 Battle Info (default On)
    n = len(cmds)
    h, w = btnCmd.height // 5, btnCmd.width // 2
    sel_i = max(0, min(n - 1, args.cmd))
    # bar: 512x40 black (alpha 150), y = height + 40, show() x8 -> -80
    bar_y = H + 40 - 8 * (40 // 4)
    def draw_cmd_bar():
        draw_sprite(screen, Image.new("RGBA", (W, 40), (0, 0, 0, 150)), 0, bar_y)
    uadd(0, draw_cmd_bar, order=-1)                # created in loadUIElements, before the databox sprites
    cmd_info = {"bar_rect": [0, bar_y, W, 40], "selected": sel_i, "buttons": []}
    for i, label in enumerate(cmds):
        bm = Image.new("RGBA", (btnEmp.width * 2, btnEmp.height), (0, 0, 0, 0))
        x = w if i > 3 else 0
        for j in range(2):
            blt(bm, btnEmp, j * btnEmp.width, 0)
            if j > 0:
                blt(bm, btnCmd, j * btnEmp.width + 2, 0, (x, h * i, w, h))
            c = darken(btnCmd.getpixel((x + 8, h * i + 8)), 0.6) if j > 0 else (51, 51, 51, 255)
            pbDrawOutlineText(bm, btnEmp.width * j, 11, btnEmp.width, h, label, WHITE, c, 1, "small")
        bx = (W // (n + 1)) * (i + 1)
        by = H - 36 + 80 - 8 * 10                    # show() x8: -10 each
        srcx = btnEmp.width if i == sel_i else 0
        def draw_btn(bm=bm, bx=bx, by=by, srcx=srcx):
            draw_sprite(screen, bm, bx, by, btnEmp.width // 2, btnEmp.height // 2, src=(srcx, 0, btnEmp.width, btnEmp.height))
        uadd(0, draw_btn)
        cmd_info["buttons"].append({"label": label, "rect": [bx - btnEmp.width // 2, by - btnEmp.height // 2, btnEmp.width, btnEmp.height],
                                    "centre": [bx, by], "selected": i == sel_i})
    sb, mw, mh = sel_bitmap(w, h)
    sbx = (W // (n + 1)) * (sel_i + 1)
    sby = H - 36 + 80 - 80 - 2
    def draw_sel():
        draw_sprite(screen, sb, sbx, sby, mw // 2, mh // 2, src=(mw * frame, 0, mw, mh))
    if not args.no_selector:
        uadd(99, draw_sel)
    cmd_info["selector_rect"] = [sbx - mw // 2, sby - mh // 2, mw, mh]
    step = W // (n + 1)
    cmd_info["draw_order"] = ("bar < buttons (all z 0, later buttons on top; %d buttons %d px apart, "
                              "%d px wide: %s) < selector z99"
                              % (n, step, btnEmp.width, "each overlaps the next by %d px" % (btnEmp.width - step)
                                 if btnEmp.width > step else "no overlap"))
    info["command"] = cmd_info

# --- FightWindowEBDX ---------------------------------------------------------
if args.menu == "fight":
    btnbmp, typebmp, catbmp = load(UI("moveSelButtons")), load(UI("types")), load(UI("category"))
    nummoves = len(MOVES)
    sel_i = max(0, min(nummoves - 1, args.sel))
    # background: 512x64 black (alpha 150), showPlay: y = height, show() x8: -8
    bar_y = H - 8 * (64 // 8)
    def draw_fbar():
        draw_sprite(screen, Image.new("RGBA", (W, 64), (0, 0, 0, 150)), 0, bar_y)
    uadd(100, draw_fbar)
    fight = {"bar_rect": [0, bar_y, W, 64], "selected": sel_i, "buttons": []}
    xs, ys = [], []
    for i in range(4):
        xs.append(W // 2 + (-1 if i % 2 == 0 else 1) * (W // 2 + 99))
        ys.append(H - 90 + (i // 2) * 44 + (22 if nummoves < 3 else 0))
    lift = 14 if nummoves < 3 else 20
    for i, mv in enumerate(MOVES[:4]):
        bm = Image.new("RGBA", (198 * 2, 74), (0, 0, 0, 0))
        t, cat = mv["type"], mv["cat"]
        blt(bm, btnbmp, 0, 0, (0, t * 74, 198, 74))
        blt(bm, btnbmp, 198, 0, (198, t * 74, 198, 74))
        blt(bm, catbmp, 65, 46, (0, cat * 22, 38, 22))
        blt(bm, typebmp, 3, 46, (0, t * 22, 72, 22))
        base = darken(btnbmp.getpixel((5, 32 + t * 74)), 0.4)
        pbDrawOutlineText(bm, 198, 10, 196, 42, mv["name"], WHITE, base, 1, "small")
        pp = "%d/%d" % (mv["pp"], mv["total"])
        pbDrawOutlineText(bm, 0, 48, 191, 26, pp, WHITE, base, 2, "small")
        name_box = pbDrawTextPositions(bm, [[mv["name"], 99, 4, 2, base, (0, 0, 0, 24)]], "system")[0]
        bx = xs[i] + (1 if i % 2 == 0 else -1) * (W // 16) * 8      # show() x8
        sel = i == sel_i
        by = ys[i] - (lift if sel else 0)
        srcx = 0 if sel else 198
        def draw_mbtn(bm=bm, bx=bx, by=by, srcx=srcx):
            draw_sprite(screen, bm, bx, by, 99, 0, src=(srcx, 0, 198, 74))
        # --kr-layers: Kanto Reloaded's fix puts the highlighted button on top (z 104)
        uadd(104 if sel and args.kr_layers else 102, draw_mbtn)
        left = bx - 99
        half = btnbmp.crop((srcx, t * 74, srcx + 198, t * 74 + 74)).getchannel("A").getbbox()
        grect = [left + half[0], by + half[1], half[2] - half[0], half[3] - half[1]]
        e = {"name": mv["name"], "type": t, "category": cat, "pp": [mv["pp"], mv["total"]], "selected": sel,
             "rect": [left, by, 198, 74], "graphic_rect": grect, "graphic_rect_onscreen": clip_rect(grect),
             "centre_x": bx, "base_colour": list(base[:3])}
        if sel:
            ppw = text_width("small", pp)
            e["name_text"] = [left + name_box[0], by + name_box[1], name_box[2], name_box[3]]
            e["type_icon"] = [left + 3, by + 46, 72, 22]
            e["category_icon"] = [left + 65, by + 46, 38, 22]
            e["pp_text"] = [left + 191 - ppw, by + 48, ppw, line_height("small")]
        else:
            nw = text_width("small", mv["name"])
            e["name_text"] = [left + (196 - min(nw, 196)) // 2, by + 10, min(nw, 196), line_height("small")]
        fight["buttons"].append(e)
    sb, mw, mh = sel_bitmap(192, 68)
    sbx = xs[sel_i] + (1 if sel_i % 2 == 0 else -1) * (W // 16) * 8
    sby = ys[sel_i] - lift + 74 // 2 - 1
    def draw_fsel():
        draw_sprite(screen, sb, sbx, sby, mw // 2, mh // 2, src=(mw * frame, 0, mw, mh))
    if not args.no_selector:
        uadd(199, draw_fsel)
    fight["selector_rect"] = [sbx - mw // 2, sby - mh // 2, mw, mh]
    fight["draw_order"] = ("bar z100 < buttons z102 in move order (a later button covers an earlier one, "
                           "so the bottom row hides the last 8 px of a lifted top-row button) < selector z199")
    info["fight"] = fight

# --- TargetWindowEBDX (doubles) --------------------------------------------------
# PokeBattle_SceneEBDX#pbChooseTarget hides the fight window first
# (@fightWindow.hidePlay); the command window was hidden when FIGHT was
# picked. So only the scene, the databoxes and this window are on screen.
if args.menu == "target":
    TARGETS = {  # GameData::Target: num_targets
        "None": 0, "User": 0, "NearAlly": 1, "UserOrNearAlly": 1, "UserAndAllies": 2, "NearFoe": 1,
        "RandomNearFoe": 1, "AllNearFoes": 2, "Foe": 1, "AllFoes": 2, "NearOther": 1, "AllNearOthers": 2,
        "Other": 1, "AllBattlers": 2, "UserSide": 0, "FoeSide": 0, "BothSides": 0}
    kind = args.target_kind
    if kind not in TARGETS:
        ap.error("unknown --target-kind %s" % kind)
    user = 0
    opposes = lambda a, b: (a & 1) != (b & 1)
    near = lambda a, b: a != b                       # nearBattlers? in 2v2: every other battler
    def can_target(iu, it):                          # PokeBattle_Battle#pbMoveCanTarget?
        if TARGETS[kind] == 0:
            return False
        if kind == "NearAlly":
            return not opposes(iu, it) and near(iu, it)
        if kind == "UserOrNearAlly":
            return iu == it or (not opposes(iu, it) and near(iu, it))
        if kind == "UserAndAllies":
            return not opposes(iu, it)
        if kind in ("NearFoe", "RandomNearFoe", "AllNearFoes"):
            return opposes(iu, it) and near(iu, it)
        if kind in ("Foe", "AllFoes"):
            return opposes(iu, it)
        if kind in ("NearOther", "AllNearOthers"):
            return near(iu, it)
        if kind == "Other":
            return iu != it
        return True
    texts = []                                       # pbCreateTargetTexts (note: (i, idxBattler) order)
    for i in range(4):
        if kind in ("None", "User", "RandomNearFoe"):
            show = i == user
        elif kind == "UserSide":
            show = not opposes(i, user)
        elif kind == "FoeSide":
            show = opposes(i, user)
        elif kind == "BothSides":
            show = True
        else:
            show = can_target(i, user)
        texts.append(next(b["name"] for b in BATTLERS if b["index"] == i) if show else None)
    mode = 0 if TARGETS[kind] == 1 else 1
    order = {0: [3, 1], 1: [2, 0], 2: [1, 3], 3: [0, 2]}[user]          # pbGetOpposingIndicesInOrder (2v2)
    if kind in ("NearAlly",):
        first = 2
    elif kind in ("NearFoe", "NearOther", "Foe", "Other"):
        first = order[0]
    else:
        first = user                                 # pbFirstTarget falls back to the user
    tindex = max(0, min(3, args.target))

    btn = load(UI("btnEmpty"))
    maxsize = 2
    rw = maxsize * (btn.width + 8)
    rh = 2 * (btn.height + 4)
    # background: 512x64 black (alpha 150), y = height - 64 + 80, showPlay: -8 x10
    tbar_y = H - 64 + 80 - 10 * 8
    def draw_tbar():
        draw_sprite(screen, Image.new("RGBA", (W, 64), (0, 0, 0, 150)), 0, tbar_y)
    uadd(100, draw_tbar, order=-1)                   # created in loadUIElements
    target = {"bar_rect": [0, tbar_y, W, 64], "kind": kind, "mode": "single target" if mode == 0 else "all marked",
              "selected": tindex, "game_first_target": first, "buttons": [],
              "texts": "none: the window draws no labels (pbCreateTargetTexts only decides which buttons get an icon)"}

    def fusion_icon(head, body):
        # KIF::FusionIcon.build: head icon, then the body icon from
        # height/2 + Settings::FUSION_ICON_SPRITE_OFFSET (10) down pasted over it
        hd = load(G("Pokemon", "Icons", species_symbol(head) + ".png"))
        bd = load(G("Pokemon", "Icons", species_symbol(body) + ".png"))
        fused = hd.copy()
        y0 = bd.height // 2 + 10
        h = min(bd.height, fused.height) - y0
        w = min(bd.width, fused.width)
        if h > 0 and w > 0:
            fused.paste((0, 0, 0, 0), (0, y0, w, y0 + h))
            fused.alpha_composite(bd.crop((0, y0, w, y0 + h)), (0, y0))
        return fused

    def icon_for(b):
        # GameData::Species.icon_filename_from_pokemon
        if b.get("fusion"):
            if args.fusion_icons:
                return fusion_icon(*b["fusion"]), "KIF::FusionIcon.build(%s, %s)" % (
                    species_symbol(b["fusion"][0]), species_symbol(b["fusion"][1]))
            return load(G("Icons", "iconDNA.png")), "Graphics/Icons/iconDNA.png"
        sym = species_symbol(b["species"])
        cands = ([sym + "_female"] if b["gender"] == 1 else []) + [sym]
        for c in cands:
            p = G("Pokemon", "Icons", c + ".png")
            if os.path.exists(p):
                return load(p), "Graphics/Pokemon/Icons/%s.png" % c
        raise SystemExit("no icon for " + sym)

    for i in range(4):
        b = next(bb for bb in BATTLERS if bb["index"] == i)
        bm = btn.copy()
        opacity = 255
        e = {"index": i, "name": b["name"], "valid_target": texts[i] is not None}
        if texts[i] is not None:
            icon, src = icon_for(b)
            iw = icon.width // 2                         # two-frame icon: first frame
            ix = (btn.width - iw) // 2
            iy = (btn.height - icon.height) // 2 - 9     # Ruby integer division floors
            rect_h = btn.height - 4 - iy
            if b["hp"] > 0:
                part = icon.crop((0, 0, iw, min(rect_h, icon.height)))
                a = np.asarray(part).astype(np.float64)
                a[..., 3] *= 216 / 255.0                 # blt opacity 216
                part = Image.fromarray(np.round(a).astype(np.uint8), "RGBA")
                draw_sprite(bm, part, ix, iy)
            vis_top, vis_bot = max(iy, 0), min(iy + min(rect_h, icon.height), btn.height)
            e["icon_source"] = src
            e["icon_frame_rect_local"] = [ix, iy, iw, icon.height]
            e["icon_visible_rect_local"] = [ix, vis_top, iw, vis_bot - vis_top]
        else:
            opacity = 0 if i // 2 > maxsize - 1 else 128
        x = (W - rw) // 2 + ((i // 2) if i % 2 == 0 else (maxsize - 1 - (i - 1) // 2)) * (btn.width + 8)
        y = (H - rh - 4) + (1 - i % 2) * (btn.height + 4)
        def draw_tbtn(bm=bm, x=x, y=y, opacity=opacity):
            draw_sprite(screen, bm, x, y, opacity=opacity)
        uadd(100, draw_tbtn)
        e.update(rect=[x, y, btn.width, btn.height], opacity=opacity, selected=i == tindex)
        if "icon_frame_rect_local" in e:
            fr, vr = e.pop("icon_frame_rect_local"), e.pop("icon_visible_rect_local")
            e["icon_frame_rect"] = [x + fr[0], y + fr[1], fr[2], fr[3]]
            e["icon_rect"] = [x + vr[0], y + vr[1], vr[2], vr[3]]
        target["buttons"].append(e)
    # SelectorSprite#target: pbSelBitmap(cmdSel, 96x42), centred on the button,
    # opacity follows the button, z 99999
    sb, mw, mh = sel_bitmap(btn.width, btn.height)
    tb = target["buttons"][tindex]
    scx, scy = tb["rect"][0] + btn.width // 2, tb["rect"][1] + btn.height // 2
    def draw_tsel():
        draw_sprite(screen, sb, scx, scy, mw // 2, mh // 2, src=(mw * frame, 0, mw, mh), opacity=tb["opacity"])
    if not args.no_selector:
        uadd(99999, draw_tsel)
    target["selector_rect"] = [scx - mw // 2, scy - mh // 2, mw, mh]
    target["draw_order"] = "bar z100 < buttons z100 (made later) < selector z99999; fight and command windows hidden"
    info["target"] = target

for _, _, fn in sorted(ui, key=lambda t: (t[0], t[1])):
    fn()

out = args.out
os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
screen.convert("RGB").save(out)
base_name, ext = os.path.splitext(out)
screen.convert("RGB").resize((W * 2, H * 2), Image.NEAREST).save(base_name + "@2x" + ext)
info["sprites_source"] = args.sprites
info["notes"] = ("Rects are [x, y, w, h] in 512x384 screen pixels. Text rects start at the ascent line "
                 "(mkxp-z draws the line top at y; capitals start 1 px lower in the small font, 2 px in the system font).")
with open(base_name + ".json", "w", encoding="utf-8") as f:
    json.dump(info, f, indent=1, ensure_ascii=False)
print("saved", out)
