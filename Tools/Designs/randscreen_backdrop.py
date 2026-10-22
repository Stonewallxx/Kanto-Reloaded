# Builds KIF Beta's Randomizer screens (cody's C-RAND-01) for UI mockups: the
# main RandomizerOptionsScene and the per-part pages (KifRandPageScene), both
# PokemonOption_Scene subclasses drawn by KifRandOptionWindow.
#
# The rows, values and descriptions are read from the game's own Ruby code at
# run time (a small parser for the page DSL: enum / onoff / slider /
# ButtonOption / DynButton / EnumOption), so text changes in the code show up
# here. Placement follows KIF Beta's code, line by line:
#   990_KIF/ZZ_Cody/C-RAND-01_Randomizer/004_RandScreen.rb
#       page_* builders, page_state, MarkedEnum (" *" = changed), slider ("%s: %03d"),
#       RandomizerOptionsScene#pbGetOptions / initUIElements / getDefaultDescription,
#       KifRandPageScene (name colours: GREEN or MessageConfig::BLUE_TEXT_*),
#       KifRandWindowMixin#initOptionsWindow (list height = 384 - title - textbox + 32),
#       KifRandOptionWindow#drawItem / kif_name_width (name column = longest name + " *"
#       + 20, clamped to 3/10..11/20 of the row; values spread, or "< v >" when they
#       don't fit with 12 px gaps), KifScrollText (all lines drawn, 3+ lines scroll)
#   990_KIF/ZZ_Cody/C-RAND-01_Randomizer/014_RandEntrancesUI.rb   Entrances button
#       (main screen, before "Randomize now") + Entrances page; shown when
#       Data/KIF/entrances.dat loads (ER.available?)
#   990_KIF/ZZ_Cody/C-RAND-01_Randomizer/001/005/006/007/009/010/013   defaults
#       (DATA_DEFAULTS), changed_keys / mark, item bans (JUNK_ITEMS that exist)
#   990_KIF/SCOPE-02_PIFFixes/OptionScreens.rb   KIF::OptionScreenFix is prepended to
#       RandomizerOptionsScene (it existed from 025-Randomizer when the fix loaded):
#       the MAIN list is sized to the space (384 - 64 - 96 = 224). KifRandPageScene is
#       not in that list, so the PAGES keep the +32 list (256 high, last row behind
#       the description box).
#   016_UI/015_UI_Options.rb   Window_PokemonOption (sel colours, "Confirm" row in the
#       name colour +80 / -60, 9/20 column), PokemonOption_Scene#initUIElements
#       (title Window_UnformattedTextPokemon 0,0,512,64; textbox = pbCreateMessageWindow),
#       updateDescription (array description -> [current value], else default)
#   007_Objects and windows/004_SpriteWindow.rb   SpriteWindow skinformat 1 9-slice,
#       loadSkinFile (96x48 speech skins: skinrect 32,16,16,16, trim 32,16,16,16)
#   007_Objects and windows/005_SpriteWindow_text.rb   SpriteWindow_Selectable (rows of
#       32, cursor kept mid-page), UpDownArrowMixin, Window_DrawableCommand#drawCursor,
#       Window_UnformattedTextPokemon#refresh, Window_AdvancedTextPokemon#setText
#   007_Objects and windows/010_DrawText.rb   pbDrawShadowText, drawTextEx,
#       getFormattedText, drawSingleFormattedChar
#   007_Objects and windows/011_Messages.rb + 052_InfiniteFusion/System/SpeechBubbles.rb
#       pbCreateMessageWindow (no viewport, z 99999 -> drawn over the scene's viewport)
#   001_Technical/001_MKXP_Compatibility.rb   draw_text gets the text's own height
# Defaults (KIF Beta, default settings): menu frame 0 = "default_transparent"
# (48x48, dark -> white text, selarrow_white), speech frame 0 = "speech hgss 1"
# (96x48, dark body -> white text), Power Green 29 drawn at 26 px (F-UI-03 Default),
# no dark mode effect on option windows. Behind the scene: black (pbFadeOutIn's
# z-99999 black viewport stays up while the scene runs; every window is translucent).
# Settled state: faded in, option window active (scroll arrows on frame 0),
# description scrolled to the top (KifScrollText's first 1.5 s hold).
#
# Usage:
#   python randscreen_backdrop.py "<KIF Beta>" out.png main [--sel N|"Name"]
#   python randscreen_backdrop.py "<KIF Beta>" out.png page data [--sel N|"Name"]
#          [--set "types=1,abilities=Random"] [--changed "types,abilities"|set]
#          [--extra-rows "Learnsets:Same|Random:Description;Name@3:A|B:Desc A|Desc B"]
#          [--extra-values "abilities:Per Pokémon[:Description]"]
#   pages: pokemon trainers gyms items data evolutions exclusions entrances presets
#   other: --intro (opened during the new-game intro: no marks, no "Randomize now",
#          no "Entrance log"), --seed K7Q29XMA, --bans "pokemon=3,moves=0,abilities=1,items=40",
#          --no-entrances (as if Data/KIF/entrances.dat were missing), --desc "text"
#          (description box text for a mockup)
#   --set takes an index or the value's text; Confirm is the last row (--sel Confirm).
# Writes out.png, out@2x.png (nearest 2x) and out.json (rects for mockups).
import sys, os, re, math, json, argparse, struct
import numpy as np
from PIL import Image, ImageFont, ImageDraw

W, H = 512, 384

ap = argparse.ArgumentParser(add_help=False)
ap.add_argument("root")
ap.add_argument("out")
ap.add_argument("mode", choices=["main", "page"])
ap.add_argument("page", nargs="?", default=None)
ap.add_argument("--sel", default="0", help="selected row: index (Confirm = last) or a name prefix")
ap.add_argument("--set", dest="setv", default="", help='"key=index|value text,..." (setting keys from the code)')
ap.add_argument("--changed", default="", help='keys shown with " *" (changed, not applied); "set" = every --set key')
ap.add_argument("--extra-rows", default="", help='"Name[@pos]:Val1|Val2:Description[|per-value...];..."')
ap.add_argument("--extra-values", default="", help='"key:New value[:Description];..." (appended and current)')
ap.add_argument("--intro", action="store_true", help="opened during the new-game intro")
ap.add_argument("--seed", default="K7Q29XMA")
ap.add_argument("--bans", default="", help='"pokemon=N,moves=N,abilities=N,items=N" list lengths')
ap.add_argument("--no-entrances", action="store_true")
ap.add_argument("--desc", default=None, help="description box text instead of the selected row's")
args = ap.parse_args()

ROOT = args.root
SCRIPTS = os.path.join(ROOT, "Data", "Scripts")
RAND_DIR = os.path.join(SCRIPTS, "990_KIF", "ZZ_Cody", "C-RAND-01_Randomizer")
G = lambda *p: os.path.join(ROOT, "Graphics", *p)
_cache = {}

def load(path):
    if path not in _cache:
        _cache[path] = Image.open(path).convert("RGBA")
    return _cache[path]

def read_src(name):
    with open(os.path.join(RAND_DIR, name), encoding="utf-8") as f:
        return f.read()

def C(r, g, b, a=255):
    return (r, g, b, a)

#===============================================================================
# A small reader for the Ruby the pages are written in
#===============================================================================
OPEN = {"(": ")", "[": "]", "{": "}"}

class CodeChanged(Exception):
    pass

def prev_sig(src, i):
    j = i - 1
    while j >= 0 and src[j] in " \t":
        j -= 1
    return src[j] if j >= 0 else "\n"

def skip_str(src, i):
    q = src[i]
    i += 1
    while i < len(src):
        c = src[i]
        if c == "\\":
            i += 2
            continue
        if c == q:
            return i + 1
        if q == '"' and c == "#" and src[i + 1:i + 2] == "{":
            i = match(src, i + 1) + 1
            continue
        i += 1
    raise CodeChanged("unterminated string")

def skip_regex(src, i):
    i += 1
    while i < len(src):
        c = src[i]
        if c == "\\":
            i += 2
            continue
        if c == "/":
            i += 1
            while i < len(src) and src[i].isalpha():
                i += 1
            return i
        i += 1
    raise CodeChanged("unterminated regexp")

def is_regex(src, i):
    return src[i] == "/" and prev_sig(src, i) in "(,=!~|&{[;\n"

def match(src, i):
    # index of the bracket closing src[i] (strings, regexps and comments skipped)
    stack = [OPEN[src[i]]]
    i += 1
    while i < len(src):
        c = src[i]
        if c in "\"'":
            i = skip_str(src, i)
            continue
        if c == "/" and is_regex(src, i):
            i = skip_regex(src, i)
            continue
        if c == "#":
            j = src.find("\n", i)
            i = j if j >= 0 else len(src)
            continue
        if c in OPEN:
            stack.append(OPEN[c])
        elif c in ")]}":
            if c != stack[-1]:
                raise CodeChanged("unbalanced %r" % c)
            stack.pop()
            if not stack:
                return i
        i += 1
    raise CodeChanged("no closing bracket")

def split_top(s, sep=","):
    # s split at top-level separators
    out, depth, start, i = [], 0, 0, 0
    while i < len(s):
        c = s[i]
        if c in "\"'":
            i = skip_str(s, i)
            continue
        if c == "/" and is_regex(s, i):
            i = skip_regex(s, i)
            continue
        if c == "#":
            j = s.find("\n", i)
            i = j if j >= 0 else len(s)
            continue
        if c in OPEN:
            depth += 1
        elif c in ")]}":
            depth -= 1
        elif depth == 0 and s.startswith(sep, i):
            out.append(s[start:i])
            start = i + len(sep)
            i += len(sep)
            continue
        i += 1
    out.append(s[start:])
    return [p.strip() for p in out if p.strip()]

def find_top(s, token):
    # first top-level position of token in s, or -1
    depth, i = 0, 0
    while i < len(s):
        c = s[i]
        if c in "\"'":
            i = skip_str(s, i)
            continue
        if c in OPEN:
            depth += 1
        elif c in ")]}":
            depth -= 1
        elif depth == 0 and s.startswith(token, i):
            return i
        i += 1
    return -1

def call_args(e, name_len):
    # e = "name(...)" exactly -> its argument strings
    i = name_len
    if e[i:i + 1] != "(":
        raise CodeChanged("call expected: %s" % e[:60])
    j = match(e, i)
    if e[j + 1:].strip():
        raise CodeChanged("trailing code after %s" % e[:60])
    return split_top(e[i + 1:j])

def unescape(s):
    return re.sub(r"\\(.)", lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), s)

class Proc:
    def __init__(self, body):
        self.body = body.strip()

class Sym(str):
    pass

#-------------------------------------------------------------------------------
# Settings (KIF::Rand.get / dget): a new randomized save leaves PIF's switches
# and the BST variables (195/197) at 0/off; DATA_DEFAULTS give the rest
#-------------------------------------------------------------------------------
ALL_SRC = "\n".join(read_src(f) for f in sorted(os.listdir(RAND_DIR)) if f.endswith(".rb"))
SRC004 = read_src("004_RandScreen.rb")
SRC014 = read_src("014_RandEntrancesUI.rb")

DEFAULTS = {}
m = re.search(r"DATA_DEFAULTS\s*=\s*\{([^}]*)\}", ALL_SRC)
if m:
    for k, v in re.findall(r":(\w+)\s*=>\s*(\d+)", m.group(1)):
        DEFAULTS[k] = int(v)
for k, v in re.findall(r"DATA_DEFAULTS\[:(\w+)\]\s*=\s*(\d+)", ALL_SRC):
    DEFAULTS[k] = int(v)
RAND_CONSTS = dict(re.findall(r'^\s*([A-Z_]+)\s*=\s*"([^"]*)"', read_src("001_RandCore.rb"), re.M))

settings = {}            # key -> index (or number for the sliders)
settings["log"] = 1      # log_on?: data[:log] != false -> On

def get(key):
    return settings.get(key, DEFAULTS.get(key, 0))

changed_keys = set()
def mark(key, text):
    # KIF::Rand.mark: " *" when the draft differs from what was applied
    return text + " *" if (not args.intro and key in changed_keys) else text

ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
seed = re.sub(r"[^A-Z0-9]", "", args.seed.upper())
if len(seed) != 8 or any(c not in ALPHABET for c in seed):
    ap.error("--seed: 8 letters/numbers without I, O, 0, 1")
def format_seed():
    return "%s-%s" % (seed[:4], seed[4:])

#-------------------------------------------------------------------------------
# Item bans start as JUNK_ITEMS that exist in Data/items.dat (Marshal + the
# data files' XOR key, as in dex_backdrop.py / flymap_backdrop.py)
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

def default_item_bans():
    src = read_src("007_RandItems.rb")
    i = src.index("JUNK_ITEMS = [") + len("JUNK_ITEMS = ")
    junk = re.findall(r":(\w+)", src[i:match(src, i) + 1])
    try:
        items = Marshal(read_dat(os.path.join(ROOT, "Data", "items.dat"))).load()
        names = set(k for k in items.keys() if isinstance(k, str))
        n = sum(1 for j in junk if j in names)
        return n, "%d of the %d JUNK_ITEMS exist in Data/items.dat (default_item_bans)" % (n, len(junk))
    except Exception as e:
        return len(junk), "Data/items.dat unreadable (%s): every JUNK_ITEMS entry counted" % e

bans = {"pokemon": 0, "moves": 0, "abilities": 0}
ITEM_BANS_NOTE = None
for part in [p for p in args.bans.split(",") if p.strip()]:
    k, v = part.split("=")
    bans[k.strip()] = int(v)
if "items" not in bans:
    bans["items"], ITEM_BANS_NOTE = default_item_bans()

def entrances_available():
    # KIF::Rand::ER.available?: Data/KIF/entrances.dat is a Hash with :doors / :edges
    if args.no_entrances:
        return False
    p = os.path.join(ROOT, "Data", "KIF", "entrances.dat")
    if not os.path.isfile(p):
        return False
    try:
        d = Marshal(open(p, "rb").read()).load()
        return isinstance(d, dict) and isinstance(d.get("doors"), list) and isinstance(d.get("edges"), dict)
    except Exception:
        return False

ER_AVAILABLE = entrances_available()

def page_state(page):
    # KIF::Rand.page_state (004) + the Entrances alias (014)
    on_off = lambda b: "On" if b else "Off"
    if page == "pokemon":     # SWITCH_RANDOM_WILD after sync_masters
        return on_off(get("wild_mode") > 0 or get("starters") > 0 or get("statics") == 1 or
                      get("gifts") == 1 or get("trades") > 0)
    if page == "trainers":
        return on_off(get("trainers") > 0)
    if page == "gyms":
        return on_off(get("gyms") == 1)
    if page == "items":       # SWITCH_RANDOM_ITEMS_GENERAL after sync_masters
        return on_off(get("found_items") == 1 or get("given_items") == 1 or get("found_tms") == 1 or
                      get("given_tms") == 1 or get("shop_items") == 1 or get("held_items") > 0)
    if page == "data":
        return on_off(get("types") > 0 or get("moves_follow") == 1 or get("tms_follow") == 1 or
                      get("abilities") > 0 or get("stats") > 0)
    if page == "evolutions":
        return on_off(get("evolutions") > 0)
    if page == "exclusions":
        return str(bans["pokemon"] + bans["moves"] + bans["abilities"])
    if page == "entrances":
        return on_off(get("entrances") > 0)
    return ""

KEY_NAMES = {}
def key_name(button):
    # KIF::Keys.name: the first named key bound in Data/keybindings.mkxp1 (the
    # player's own copy in the save folder isn't read here), else C/X/Z/D/Q/W
    targets = {"USE": 13, "BACK": 12, "ACTION": 11, "SPECIAL": 16, "JUMPUP": 17, "JUMPDOWN": 18}
    defaults = {"USE": "C", "BACK": "X", "ACTION": "Z", "SPECIAL": "D", "JUMPUP": "Q", "JUMPDOWN": "W"}
    names = {}
    for i, c in enumerate("ABCDEFGHIJKLMNOPQRSTUVWXYZ"):
        names[4 + i] = c
    for n in range(1, 10):
        names[29 + n] = str(n)
    names.update({39: "0", 40: "Enter", 41: "Esc", 42: "Bksp", 43: "Tab", 44: "Space", 73: "Ins",
                  74: "Home", 75: "PgUp", 76: "Del", 77: "End", 78: "PgDn", 79: "Right", 80: "Left",
                  81: "Down", 82: "Up", 88: "Enter", 98: "Num0", 224: "Ctrl", 225: "Shift", 226: "Alt",
                  228: "Ctrl", 229: "Shift", 230: "Alt"})
    for n in range(1, 13):
        names[57 + n] = "F%d" % n
    for n in range(1, 10):
        names[88 + n] = "Num%d" % n
    p = os.path.join(ROOT, "Data", "keybindings.mkxp1")
    try:
        d = open(p, "rb").read()
        n = struct.unpack("<l", d[8:12])[0]
        for i in range(n):
            t, code, _x, target = struct.unpack("<4l", d[12 + i * 16:28 + i * 16])
            if t == 1 and target == targets[button] and code in names:
                return names[code]
    except Exception:
        pass
    return defaults.get(button, "?")

#-------------------------------------------------------------------------------
# Evaluating the expressions the rows are built from
#-------------------------------------------------------------------------------
def ev_string(e, ctx):
    # a double-quoted literal, interpolation evaluated
    if not (e.startswith('"') and skip_str(e, 0) == len(e)):
        raise CodeChanged("string expected: %s" % e[:60])
    out, i, s = [], 1, e
    while i < len(s) - 1:
        c = s[i]
        if c == "\\":
            out.append(unescape(s[i:i + 2]))
            i += 2
            continue
        if c == "#" and s[i + 1:i + 2] == "{":
            j = match(s, i + 1)
            out.append(str(ev(s[i + 2:j], ctx)))
            i = j + 1
            continue
        out.append(c)
        i += 1
    return "".join(out)

def intl(fmt, vals):
    return re.sub(r"\{(\d+)\}", lambda m: str(vals[int(m.group(1)) - 1]), fmt)

RAND = r"(?:r|KIF::Rand)"

def ev(e, ctx):
    e = e.strip()
    if e.startswith("_INTL("):
        a = call_args(e, 5)
        return intl(ev(a[0], ctx), [ev(x, ctx) for x in a[1:]])
    if e.startswith('"'):
        return ev_string(e, ctx)
    if e.startswith("["):
        if match(e, 0) != len(e) - 1:
            raise CodeChanged("list expected: %s" % e[:60])
        return [ev(x, ctx) for x in split_top(e[1:-1])]
    if e.startswith(':"'):
        return Sym(ev_string(e[1:], ctx))
    if re.fullmatch(r":\w+[?!]?", e):
        return Sym(e[1:])
    if e.startswith("proc {") or e.startswith("proc{"):
        i = e.index("{")
        if match(e, i) != len(e) - 1:
            raise CodeChanged("proc expected: %s" % e[:60])
        return Proc(e[i + 1:-1])
    if e == "nil":
        return None
    if re.fullmatch(r"-?\d+", e):
        return int(e)
    if e in ctx:
        return ctx[e]
    # the few calls the names and descriptions use
    m = re.fullmatch(RAND + r"\.mark\((.*)\)", e, re.S)
    if m:
        a = split_top(m.group(1))
        return mark(str(ev(a[0], ctx)), ev(a[1], ctx))
    m = re.fullmatch(RAND + r"\.page_state\((.*)\)", e)
    if m:
        return page_state(str(ev(m.group(1), ctx)))
    if re.fullmatch(RAND + r"\.format_seed", e):
        return format_seed()
    if re.fullmatch(RAND + r"\.item_bans\.length", e):
        return bans["items"]
    m = re.fullmatch(RAND + r"\.bans\((.*)\)\.length", e)
    if m:
        return bans[str(ev(m.group(1), ctx))]
    m = re.fullmatch(RAND + r"::([A-Z_]+)", e)
    if m and m.group(1) in RAND_CONSTS:
        return RAND_CONSTS[m.group(1)]
    m = re.fullmatch(r"KIF::Keys\.name\(Input::(\w+)\)", e)
    if m:
        return key_name(m.group(1))
    if re.fullmatch(RAND + r"\.respond_to\?\(:\w+\)", e):
        return True
    if re.fullmatch(RAND + r"\.changed_keys\.length", e):
        return 0 if args.intro else len(changed_keys)
    m = re.fullmatch(r"(\w+) > (\d+)", e)
    if m and m.group(1) in ctx:
        return ctx[m.group(1)] > int(m.group(2))
    q = find_top(e, " ? ")
    if q > 0:
        rest = e[q + 3:]
        c = find_top(rest, " : ")
        if c > 0:
            return ev(rest[:c], ctx) if ev(e[:q], ctx) else ev(rest[c + 3:], ctx)
    raise CodeChanged("expression not understood: %s" % e[:80])

def run_proc(p, ctx):
    # a name proc: statements, the last one's value is the name
    ctx = dict(ctx)
    val = None
    for st in [s for s in re.split(r"\n|;", p.body) if s.strip()]:
        m = re.fullmatch(r"\s*(\w+) = (.*)", st)
        if m:
            ctx[m.group(1)] = ev(m.group(2), ctx)
        else:
            val = ev(st, ctx)
    return val

#-------------------------------------------------------------------------------
# Options (the rows): what Window_PokemonOption gets
#-------------------------------------------------------------------------------
ONOFF_VALUES = None
SLIDER_FMT = None
def helper_defs():
    global ONOFF_VALUES, SLIDER_FMT
    m = re.search(r"def self\.onoff\(key, name, desc_off, desc_on\)\s*return enum\(key, name, (\[.*?\]), \[desc_off", SRC004)
    if not m:
        raise CodeChanged("KIF::Rand.onoff")
    ONOFF_VALUES = ev(m.group(1), {})
    m = re.search(r"def self\.slider\(key, name, desc\).*?sprintf\(\"([^\"]*)\"", SRC004, re.S)
    if not m:
        raise CodeChanged("KIF::Rand.slider")
    SLIDER_FMT = m.group(1)
helper_defs()

def opt_enum(key, name, values, descs, marked=True):
    return {"kind": "enum", "key": key, "name": mark(key, name) if marked else name,
            "base_name": name, "values": list(values), "desc": descs,
            "value": None}

def build_option(e, ctx):
    e = re.sub(r"\A(\s*#[^\n]*\n)+", "", e).strip()     # comment lines before a row
    for head in ("enum", "onoff", "slider"):
        if e.startswith(head + "("):
            a = call_args(e, len(head))
            key = str(ev(a[0], ctx))
            name = ev(a[1], ctx)
            if head == "enum":
                return opt_enum(key, name, ev(a[2], ctx), ev(a[3], ctx))
            if head == "onoff":
                return opt_enum(key, name, ONOFF_VALUES, [ev(a[2], ctx), ev(a[3], ctx)])
            return {"kind": "button", "key": key, "name": mark(key, SLIDER_FMT % (name, get(key))),
                    "desc": ev(a[2], ctx), "slider": True}
    m = re.match(r"(?:r::|KIF::Rand::)?DynButton\.new", e)
    if m:
        a = call_args(e, m.end())
        return {"kind": "button", "key": None, "name": run_proc(ev(a[0], ctx), ctx),
                "desc": ev(a[2], ctx) if len(a) > 2 else ""}
    if e.startswith("ButtonOption.new"):
        a = call_args(e, len("ButtonOption.new"))
        return {"kind": "button", "key": None, "name": ev(a[0], ctx),
                "desc": ev(a[2], ctx) if len(a) > 2 else ""}
    if e.startswith("EnumOption.new"):
        a = call_args(e, len("EnumOption.new"))
        getter = ev(a[2], ctx)
        key = "log" if isinstance(getter, Proc) and "log_on?" in getter.body else None
        o = opt_enum(key, ev(a[0], ctx), ev(a[1], ctx), ev(a[4], ctx) if len(a) > 4 else "", marked=False)
        return o
    raise CodeChanged("row not understood: %s" % e[:80])

def statements_after(body, var):
    # "var << Expr(...)" statements in body: [(pos, expr)]
    out = []
    for m in re.finditer(r"\b%s << " % var, body):
        i = m.end()
        n = re.match(r"[\w:.]+", body[i:])
        j = i + n.end()
        while body[j] == " ":
            j += 1
        if body[j] != "(":
            raise CodeChanged("call expected after %s <<" % var)
        out.append((m.start(), body[i:match(body, j) + 1]))
    return out

def page_defs():
    pages = {}
    for src in (SRC004, SRC014):
        for m in re.finditer(r"def self\.page_(\w+)\s*\n\s*open_page\(", src):
            i = m.end() - 1
            j = match(src, i)
            a = split_top(src[i + 1:j])
            k = j + 1
            while src[k] in " \t":
                k += 1
            if src[k] != "{":
                raise CodeChanged("page_%s: builder block" % m.group(1))
            pages[m.group(1)] = (a, src[k + 1:match(src, k)])
    return pages

def build_page(name):
    pages = page_defs()
    if name not in pages:
        ap.error("page %r: pages are %s" % (name, ", ".join(sorted(pages))))
    a, body = pages[name]
    title, desc = ev(a[0], {}), ev(a[1], {})
    color = a[2].strip()
    b = body.strip()
    rows = []
    if b.startswith("["):
        j = match(b, 0)
        lst = b[:j + 1]
        rest = b[j + 1:].strip()
        if not rest:
            rows = [build_option(x, {}) for x in split_top(lst[1:-1])]
        else:
            mm = re.match(r"\.map do \|(\w+), (\w+)\|(.*)\bend\s*$", rest, re.S)
            if not mm:
                raise CodeChanged("page_%s: builder" % name)
            for item in split_top(lst[1:-1]):
                vals = [ev(x, {}) for x in split_top(item.strip()[1:-1])]
                rows.append(build_option(mm.group(3), {mm.group(1): vals[0], mm.group(2): vals[1]}))
    elif b.startswith("rows = ["):
        i = b.index("[")
        j = match(b, i)
        rows = [build_option(x, {}) for x in split_top(b[i + 1:j])]
        unless = b.find("unless $game_switches[SWITCH_DURING_INTRO]")
        for pos, e in statements_after(b[j:], "rows"):
            if unless >= 0 and pos + j > unless and args.intro:
                continue
            rows.append(build_option(e, {}))
    else:
        raise CodeChanged("page_%s: builder" % name)
    return title, desc, color, rows

def class_body(src, header):
    i = src.index(header)
    nxt = re.search(r"^class |^module |^KIF::", src[i + len(header):], re.M)
    return src[i:i + len(header) + (nxt.start() if nxt else len(src))]

def build_main():
    cls = class_body(SRC004, "class RandomizerOptionsScene < PokemonOption_Scene")
    title = ev(re.search(r'@sprites\["title"\]\.text = (_INTL\(.*\))', cls).group(1), {})
    m = re.search(r"def getDefaultDescription\s*return (_INTL\(.*\))", cls)
    default_desc = ev(m.group(1), {})
    d = cls.index("def pbGetOptions")
    body = cls[d:cls.index("return options", d)]
    each = re.search(r"\]\.each do \|(\w+), (\w+), (\w+)\|", body)
    lst_start = body.rfind("[[", 0, each.start())
    if match(body, lst_start) != each.start():
        raise CodeChanged("main: page list")
    line_start = body.rfind("\n", 0, lst_start) + 1
    indent = re.match(r"\s*", body[line_start:]).group(0)
    each_end = body.index("\n" + indent + "end", each.end())
    pages = [[ev(x, {}) for x in split_top(item.strip()[1:-1])]
             for item in split_top(body[lst_start + 1:each.start()])]
    unless = body.find("unless $game_switches[SWITCH_DURING_INTRO]")
    rows = []
    for pos, e in statements_after(body, "options"):
        if each.end() < pos < each_end:
            for pg in pages:
                ctx = {each.group(1): Sym(pg[0]), each.group(2): pg[1], each.group(3): pg[2]}
                o = build_option(e, ctx)
                o["page"] = str(pg[0])
                rows.append(o)
            continue
        if unless >= 0 and pos > unless:
            if args.intro:
                continue
            o = build_option(e, {})
            o["randomize_now"] = True
            rows.append(o)
            continue
        rows.append(build_option(e, {}))
    # 014: the Entrances button, before "Randomize now" when that's there
    if ER_AVAILABLE:
        m = re.search(r"btn = (r::DynButton\.new)", SRC014)
        j = match(SRC014, m.end(1))
        o = build_option(SRC014[m.start(1):j + 1], {})
        o["page"] = "entrances"
        idx = next((i for i, r in enumerate(rows) if r.get("randomize_now")), None)
        rows.insert(idx, o) if idx is not None else rows.append(o)
    return title, default_desc, rows

#-------------------------------------------------------------------------------
# Command line: settings, marks, the rows
#-------------------------------------------------------------------------------
def slug(s):
    return re.sub(r"[^a-z0-9]+", "_", s.lower()).strip("_")

if args.mode == "page" and not args.page:
    ap.error("page needs a name (pokemon, trainers, gyms, items, data, evolutions, exclusions, entrances, presets)")

set_raw = []
for part in [p for p in args.setv.split(",") if p.strip()]:
    if "=" not in part:
        ap.error("--set: key=value")
    k, v = [x.strip() for x in part.split("=", 1)]
    set_raw.append((k, v))
    if re.fullmatch(r"\d+", v):
        settings[k] = int(v)
for k in [c.strip() for c in args.changed.split(",") if c.strip()]:
    if k == "set":
        changed_keys.update(kk for kk, _ in set_raw)
    else:
        changed_keys.add({"seed": "__seed"}.get(k, k))
if args.intro and changed_keys:
    print("note: --intro: the draft isn't open during the intro, so no row is marked *")

if args.mode == "main":
    TITLE, DEFAULT_DESC, ROWS = build_main()
    NAME_COLORS = (C(35, 130, 200), C(20, 75, 115))      # MessageConfig::BLUE_TEXT_*
    COLOR_NOTE = "MessageConfig::BLUE_TEXT_MAIN/SHADOW_COLOR"
    def rebuild():
        return build_main()[2]
else:
    TITLE, DEFAULT_DESC, color, ROWS = build_page(args.page)
    if color == "GREEN":
        NAME_COLORS = (C(70, 170, 40), C(40, 100, 20))   # KIF::Rand::GREEN
        COLOR_NOTE = "KIF::Rand::GREEN"
    else:
        NAME_COLORS = (C(35, 130, 200), C(20, 75, 115))
        COLOR_NOTE = "MessageConfig::BLUE_TEXT_MAIN/SHADOW_COLOR (no page colour)"
    def rebuild():
        return build_page(args.page)[3]

# value text in --set ("abilities=Random") -> index, then rebuild with the values
need = False
for k, v in set_raw:
    if not re.fullmatch(r"\d+", v):
        row = next((r for r in ROWS if r.get("key") == k and r["kind"] == "enum"), None)
        if row is None:
            continue   # extra rows are handled below
        low = [x.lower() for x in row["values"]]
        if v.lower() not in low:
            ap.error("--set %s: %r is not one of %s" % (k, v, row["values"]))
        settings[k] = low.index(v.lower())
        need = True
if need or changed_keys or set_raw:
    ROWS = rebuild()

# --extra-values: appended to a row's list, and made its current value
for part in [p for p in args.extra_values.split(";") if p.strip()]:
    bits = part.split(":", 2)
    if len(bits) < 2:
        ap.error("--extra-values: key:Value[:Description]")
    row = next((r for r in ROWS if r.get("key") == bits[0].strip() and r["kind"] == "enum"), None)
    if row is None:
        ap.error("--extra-values: no setting row %r here" % bits[0])
    row["values"].append(bits[1])
    if len(bits) > 2:
        if not isinstance(row["desc"], list):
            row["desc"] = [row["desc"]] * (len(row["values"]) - 1)
        while len(row["desc"]) < len(row["values"]) - 1:
            row["desc"].append("")
        row["desc"].append(bits[2])
    settings[row["key"]] = len(row["values"]) - 1
    row["extra_value"] = bits[1]

# --extra-rows: appended (or inserted at @pos) as the window would get them
for part in [p for p in args.extra_rows.split(";") if p.strip()]:
    bits = part.split(":", 2)
    if len(bits) < 2:
        ap.error("--extra-rows: Name:Val1|Val2[:Description]")
    name, pos = bits[0], None
    mpos = re.fullmatch(r"(.*)@(\d+)", name)
    if mpos:
        name, pos = mpos.group(1), int(mpos.group(2))
    key = slug(name)
    desc = bits[2] if len(bits) > 2 else ""
    values = [v for v in bits[1].split("|")] if bits[1] else []
    if values:
        if "|" in desc:
            desc = desc.split("|")
        o = opt_enum(key, name, values, desc)
        for k, v in set_raw:
            if k == key:
                low = [x.lower() for x in values]
                settings[key] = int(v) if re.fullmatch(r"\d+", v) else (low.index(v.lower()) if v.lower() in low else
                                                                       ap.error("--set %s: %r not in %s" % (k, v, values)))
    else:
        o = {"kind": "button", "key": key, "name": mark(key, name), "desc": desc}
    o["extra_row"] = True
    ROWS.insert(pos, o) if pos is not None else ROWS.append(o)

KNOWN_KEYS = set(re.findall(r"\[:(\w+), :(?:enum|int), \d+\]", ALL_SRC)) | {"log"} | \
             set(r.get("key") for r in ROWS if r.get("key"))
for k, _ in set_raw:
    if k not in KNOWN_KEYS:
        print("note: --set %s: not a randomizer setting key (known: %s)" % (k, ", ".join(sorted(KNOWN_KEYS))))

for r in ROWS:
    if r["kind"] == "enum":
        v = get(r["key"]) if r["key"] else 0
        r["value"] = max(0, min(v, len(r["values"]) - 1))     # MarkedEnum's getter clamps

N_OPT = len(ROWS)
ITEM_MAX = N_OPT + 1          # Window_PokemonOption#itemCount: + "Confirm"

def resolve_sel(s):
    if re.fullmatch(r"-?\d+", s):
        v = int(s)
    else:
        low = s.lower()
        names = [r["name"].lower() for r in ROWS] + ["confirm"]
        cands = [i for i, n in enumerate(names) if n.startswith(low)]
        if not cands:
            cands = [i for i, n in enumerate(names) if low in n]
        if not cands:
            ap.error("--sel %r: no row named like that (%s)" % (s, ", ".join(r["name"] for r in ROWS)))
        v = cands[0]
    if not 0 <= v < ITEM_MAX:
        ap.error("--sel: 0..%d (Confirm = %d)" % (ITEM_MAX - 1, ITEM_MAX - 1))
    return v

SEL = resolve_sel(args.sel)

#===============================================================================
# Drawing (helpers as in party_backdrop.py)
#===============================================================================
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
    cx0, cy0 = max(0, -left), max(0, -top)
    cx1, cy1 = min(img.width, dst.width - left), min(img.height, dst.height - top)
    if cx1 <= cx0 or cy1 <= cy0:
        return
    if (cx0, cy0, cx1, cy1) != (0, 0, img.width, img.height):
        img = img.crop((cx0, cy0, cx1, cy1))
    dst.alpha_composite(img, (left + cx0, top + cy0))

FONT_FILE, FONT_SIZE = "power green.ttf", 29     # MessageConfig FONT_NAME / FONT_SIZE (F-UI-03 Default)
_font = ImageFont.truetype(os.path.join(ROOT, "Fonts", FONT_FILE), int(FONT_SIZE * 0.9))

def text_width(s):
    # Bitmap#text_size(s).width
    return int(round(_font.getlength(s))) if s else 0

def line_height():
    a, d = _font.getmetrics()
    return a + abs(d)

def union(a, b):
    if a is None:
        return b
    if b is None:
        return a
    return [min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3])]

def draw_text(bmp, x, y, w, text, align, color):
    # Bitmap#draw_text(x, y, w, text_size.height, text, align): the ascent line
    # at y, aligned by width, squeezed when too wide; returns the ink box
    if not text or w <= 0 or color[3] <= 0:
        return None
    adv = text_width(text)
    lh = line_height()
    bb = _font.getbbox(text)
    sw = max(adv, bb[2], 1)
    mask = Image.new("L", (sw + 8, max(lh, bb[3]) + 8), 0)
    ImageDraw.Draw(mask).text((0, 0), text, font=_font, fill=255)
    mask = mask.crop((0, 0, sw, max(lh, bb[3])))
    squeezed = False
    if sw > w:
        mask = mask.resize((w, mask.height), Image.NEAREST)
        sw = w
        squeezed = True
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
    return ([ax + ink[0], y + ink[1], ax + ink[2], y + ink[3]] if ink else None), squeezed

def pbDrawShadowText(bmp, x, y, w, s, base, shadow, align=0):
    # 010_DrawText: y += 4; shadow at (+2,0) (0,+2) (+2,+2), then the base
    y += 4
    ink, sq = None, False
    for dx, dy in [(2, 0), (0, 2), (2, 2)]:
        r = draw_text(bmp, x + dx, y + dy, w, s, align, shadow)
        if r:
            ink = union(ink, r[0])
    r = draw_text(bmp, x, y, w, s, align, base)
    base_ink = r[0] if r else None
    sq = r[1] if r else False
    return {"ascent_y": y, "base_ink": base_ink, "ink": union(ink, base_ink), "squeezed": sq}

def ink_rect(ink, ox=0, oy=0):
    return [ink[0] + ox, ink[1] + oy, ink[2] - ink[0], ink[3] - ink[1]] if ink else None

def getLineBrokenChunks(value, width):
    # 010_DrawText#getLineBrokenChunks(plain = true): [word, x, y, width, 32]
    x = y = 0
    ret = []
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
        tw = text_width(word)
        if x > 0 and x + tw > width:
            mw = text_width(re.sub(r"\s*", "", word))
            if x > 0 and x + mw > width:
                x = 0
                y += 32
        if tw > width and not re.search(r"\s", word):
            for ch in word:
                cw = text_width(ch)
                if x > 0 and x + cw > width:
                    x = 0
                    y += 32
                ret.append([ch, x, y, cw, 32])
                x += cw
            continue
        ret.append([word, x, y, tw, 32])
        x += tw
    return ret

def drawTextEx(bmp, x, y, width, text, base, shadow):
    # getLineBrokenChunks + renderLineBrokenChunksWithShadow (draw_text width + 2)
    lines = {}
    for word, wx, wy, ww, wh in getLineBrokenChunks(text, width):
        tx, ty = wx + x, wy + y
        ink = None
        for dx, dy in [(2, 0), (0, 2), (2, 2)]:
            r = draw_text(bmp, tx + dx, ty + dy, ww + 2, word, 0, shadow)
            if r:
                ink = union(ink, r[0])
        r = draw_text(bmp, tx, ty, ww + 2, word, 0, base)
        bi = r[0] if r else None
        ln = lines.setdefault(wy, {"x": tx, "ascent_y": ty, "width": 0, "text": "", "ink": None})
        ln["width"] = wx + ww - (ln["x"] - x)
        ln["text"] += word
        ln["ink"] = union(ln["ink"], union(ink, bi))
    return [lines[k] for k in sorted(lines)]

def getFormattedText(text, widthDst, lineheight=32):
    # 010_DrawText#getFormattedText for plain text behind a <c2=..> tag: one entry
    # per character, x advanced by text_size(char), word wrap when x + 2 > widthDst,
    # spaces before a newline dropped
    chars, internal = [], []
    x = y = 0
    lastword = [0, 0]
    hadspace = hadnonspace = False
    havenl = False
    for ch in text:
        width = text_width(ch)
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
# Windows: SpriteWindow skinformat 1 (004_SpriteWindow.rb privRefresh)
#-------------------------------------------------------------------------------
def is_dark_background(img, rect):
    # isDarkBackground: 16x16 samples (or the middle), alpha 0 skipped
    x0, y0, w, h = rect
    xseg, yseg = w // 16, h // 16
    xloop, yloop = (1 if xseg == 0 else 16), (1 if yseg == 0 else 16)
    xs = x0 + w // 2 if xseg == 0 else x0 + xseg // 2
    ys = y0 + h // 2 if yseg == 0 else y0 + yseg // 2
    r = g = b = n = 0
    yy = ys
    for _ in range(yloop):
        xx = xs
        for _ in range(xloop):
            c = img.getpixel((xx, yy))
            if c[3] != 0:
                r += c[0]; g += c[1]; b += c[2]; n += 1
            xx += xseg
        yy += yseg
    if n == 0:
        return True
    r //= n; g //= n; b //= n
    return (r * 0.299 + g * 0.587 + b * 0.114) < 160

class Skin:
    def __init__(self, name):
        self.name = name
        self.img = load(G("Windowskins", name + ".png"))
        sw, sh = self.img.size
        if (sw, sh) in [(192, 128), (128, 128)]:
            raise SystemExit("RGSS-format skin %s not handled" % name)
        # windowskin= : skinrect in the middle, trim = its corner
        sr = [(sw - 16) // 2, (sh - 16) // 2, 16, 16]
        trim = [sr[0], sr[1], sr[0], sr[1]]
        # loadSkinFile (run by setSkin and __resolveSystemFrame)
        if sw in (80, 96) and sh == 48:
            sr, trim = [32, 16, 16, 16], [32, 16, 16, 16]
        elif sw == 80 and sh == 80:
            sr, trim = [32, 32, 16, 16], [32, 16, 16, 48]
        self.sr, self.trim = sr, trim
        self.borderX = trim[0] + (sw - trim[2] - trim[0])
        self.borderY = trim[1] + (sh - trim[3] - trim[1])
        # isDarkWindowskin -> getDefaultTextColors
        if (sw, sh) == (96, 48):
            self.dark = is_dark_background(self.img, (32, 16, 16, 16))
        else:
            c = self.img.getpixel((sw // 2, sh // 2))
            self.dark = (c[0] * 0.299 + c[1] * 0.587 + c[2] * 0.114) < 160
        self.text = (C(248, 248, 248), C(72, 80, 88)) if self.dark else (C(80, 80, 88), C(160, 160, 168))

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

def draw_window(screen, skin, x, y, w, h, contents=None, ox=0, oy=0):
    # sprites in @spritekeys order: back, corner0, side0, ..., corner3, side3, contents
    img, sr, trim = skin.img, skin.sr, skin.trim
    startX, startY = sr[0], sr[1]
    cx, cy = sr[0] + sr[2], sr[1] + sr[3]
    endX, endY = img.width - cx, img.height - cy
    crop = lambda r: img.crop((r[0], r[1], r[0] + r[2], r[1] + r[3]))
    bw, bh = w - (startX + endX), h - (startY + endY)
    if bw > 0 and bh > 0:
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
    crect = [x + trim[0], y + trim[1], w - trimW, h - trimH]
    if contents is not None and w > trimW and h > trimH:
        draw_sprite(screen, contents, crect[0], crect[1], src=(ox, oy, crect[2], crect[3]))
    return {"rect": [x, y, w, h], "contents_rect": crect}

SYS = Skin("default_transparent")      # Settings::MENU_WINDOWSKINS[$PokemonSystem.frame = 0]
SPEECH = Skin("speech hgss 1")         # Settings::SPEECH_WINDOWSKINS[$PokemonSystem.textskin = 0]
SELARROW = load(G("Pictures", "selarrow_white.png" if SYS.dark else "selarrow.png"))
TEXTPADDING = 4

#===============================================================================
# The scene
#===============================================================================
screen = Image.new("RGBA", (W, H), (0, 0, 0, 255))     # pbFadeOutIn's black layer
info = {"screen": [W, H], "mode": args.mode, "page": args.page, "intro": args.intro,
        "skins": {"menu": "Graphics/Windowskins/default_transparent.png (frame 0, 48x48, skinrect 16,16,16,16; "
                          "dark -> white text, selarrow_white)",
                  "speech": "Graphics/Windowskins/speech hgss 1.png (textskin 0, 96x48, loadSkinFile: skinrect "
                            "32,16,16,16 trim 32,16,16,16 -> borderX 80, borderY 32; dark body -> white text)"},
        "font": "Fonts/power green.ttf (Power Green) size 29 -> drawn at 26 px",
        "colors": {"name": [list(NAME_COLORS[0][:3]), list(NAME_COLORS[1][:3])], "name_source": COLOR_NOTE,
                   "value": [list(SYS.text[0][:3]), list(SYS.text[1][:3])],
                   "value_selected": [[248, 48, 24], [248, 136, 128]],
                   "description": [list(SPEECH.text[0][:3]), list(SPEECH.text[1][:3])]}}

# Title: Window_UnformattedTextPokemon.newWithSize(..., 0, 0, 512, 64, @viewport)
TITLE_RECT = [0, 0, W, 64]
title_contents = Image.new("RGBA", (TITLE_RECT[2] - SYS.borderX, TITLE_RECT[3] - SYS.borderY), (0, 0, 0, 0))
title_lines = drawTextEx(title_contents, 0, 4, title_contents.width, TITLE.replace("\r", ""), *SYS.text)

# Textbox: pbCreateMessageWindow -> pbBottomLeftLines(2) -> 0, 288, 512, 96
TB_H = SPEECH.borderY + 2 * 32
TB_RECT = [0, H - TB_H, W, TB_H]

# Option list: KifRandWindowMixin#initOptionsWindow (+ OptionScreenFix on the main scene)
LIST_Y = TITLE_RECT[3]
if args.mode == "main":
    LIST_H = H - TITLE_RECT[3] - TB_H
    list_rule = "OptionScreenFix: 384 - title 64 - textbox %d = %d" % (TB_H, LIST_H)
else:
    LIST_H = (H - TITLE_RECT[3] - TB_H) + 32
    list_rule = "KifRandWindowMixin: (384 - title 64 - textbox %d) + 32 = %d (no OptionScreenFix on KifRandPageScene)" % (TB_H, LIST_H)
LIST_RECT = [0, LIST_Y, W, LIST_H]
CW, CH = W - SYS.borderX, LIST_H - SYS.borderY
PAGE_ROWS = CH // 32
top_row = max(min(SEL - (PAGE_ROWS - 1) // 2, ITEM_MAX - PAGE_ROWS), 0)
contents = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
CX0, CY0 = LIST_RECT[0] + SYS.trim[0], LIST_RECT[1] + SYS.trim[1]

SEL_BASE, SEL_SHADOW = C(248, 48, 24), C(248, 136, 128)   # Window_PokemonOption @selBaseColor / @selShadowColor
VAL_BASE, VAL_SHADOW = SYS.text
NAME_BASE, NAME_SHADOW = NAME_COLORS

ROW_W = CW                    # itemRect width: (512 - borderX) / 1
FULL = ROW_W - 16             # after drawCursor
names_w = [text_width(re.sub(r" \*\Z", "", r["name"]) + " *") for r in ROWS if r["kind"] == "enum"]
NAMEW = min(max((max(names_w) if names_w else 0) + 20, FULL * 3 // 10), FULL * 11 // 20)
VALW = FULL - NAMEW

def scr(r, lx, ly):
    return [lx + CX0, ly + CY0] + list(r[2:]) if r else None

def text_json(t, w, ox, oy, s, align=0):
    tw = min(text_width(s), w)
    bx = ox + ((w - tw) // 2 if align == 1 else 0)
    return {"text": s, "draw_rect": [ox, oy, w, 32], "box": [bx, oy + 4, tw, line_height()],
            "ink": ink_rect(t["ink"], CX0, CY0), "squeezed": t["squeezed"]}

rows_json = []
cursor_json = None
for i in range(ITEM_MAX):
    if i < top_row or i > top_row + PAGE_ROWS:
        continue
    ry = i * 32 - top_row * 32
    rect = [0, ry, ROW_W, 32]
    # drawCursor
    arrow = None
    if i == SEL:
        draw_sprite(contents, SELARROW, rect[0], rect[1])
        arrow = [CX0 + rect[0], CY0 + rect[1], SELARROW.width, SELARROW.height]
    rx, rw = rect[0] + 16, rect[2] - 16
    e = {"index": i, "selected": i == SEL, "row_rect": [CX0 + rect[0], CY0 + ry, ROW_W, 32],
         "arrow_rect": arrow}
    if i == N_OPT:
        # Window_PokemonOption#drawItem: "Confirm", name colour +80 (shadow -60), 9/20 column
        base = C(*[min(c + 80, 255) for c in NAME_BASE[:3]])
        shadow = C(*[max(c - 60, 0) for c in base[:3]])
        ow = rw * 9 // 20
        t = pbDrawShadowText(contents, rx, ry, ow, "Confirm", base, shadow)
        e.update({"kind": "confirm", "name": "Confirm",
                  "name_text": text_json(t, ow, CX0 + rx, CY0 + ry, "Confirm"),
                  "colors": [list(base[:3]), list(shadow[:3])]})
    else:
        o = ROWS[i]
        e.update({"kind": o["kind"], "key": o.get("key"), "name": o["name"]})
        if o.get("extra_row"):
            e["extra_row"] = True
        if o["kind"] == "button":
            t = pbDrawShadowText(contents, rx, ry, rw, o["name"], NAME_BASE, NAME_SHADOW)
            e["name_text"] = text_json(t, rw, CX0 + rx, CY0 + ry, o["name"])
        elif len(o["values"]) > 1:
            t = pbDrawShadowText(contents, rx, ry, NAMEW, o["name"], NAME_BASE, NAME_SHADOW)
            e["name_text"] = text_json(t, NAMEW, CX0 + rx, CY0 + ry, o["name"])
            widths = [text_width(v) for v in o["values"]]
            gaps = len(o["values"]) - 1
            vals = []
            if sum(widths) + gaps * 12 <= VALW:
                spacing = (VALW - sum(widths)) // gaps
                xpos = rx + NAMEW
                for vi, v in enumerate(o["values"]):
                    cur = vi == o["value"]
                    t = pbDrawShadowText(contents, xpos, ry, widths[vi] + 2, v,
                                         SEL_BASE if cur else VAL_BASE, SEL_SHADOW if cur else VAL_SHADOW)
                    vals.append(dict(text_json(t, widths[vi] + 2, CX0 + xpos, CY0 + ry, v), current=cur))
                    xpos += widths[vi] + spacing
                e["values_layout"] = "spread (spacing %d)" % spacing
            else:
                v = o["values"][o["value"]] if o["value"] < len(o["values"]) else ""
                s = "< %s >" % v
                t = pbDrawShadowText(contents, rx + NAMEW, ry, VALW, s, SEL_BASE, SEL_SHADOW, 1)
                vals.append(dict(text_json(t, VALW, CX0 + rx + NAMEW, CY0 + ry, s, 1), current=True))
                e["values_layout"] = "arrows (values need %d + %d gaps x 12 > %d)" % (sum(widths), gaps, VALW)
            e["values"] = vals
            e["value_index"] = o["value"]
            e["value_column"] = [CX0 + rx + NAMEW, CY0 + ry, VALW, 32]
        else:
            # one value: Window_PokemonOption#drawItem draws the name in both columns
            ow = rw * 9 // 20
            t = pbDrawShadowText(contents, rx, ry, ow, o["name"], NAME_BASE, NAME_SHADOW)
            e["name_text"] = text_json(t, ow, CX0 + rx, CY0 + ry, o["name"])
            pbDrawShadowText(contents, rx + ow, ry, ow, o["name"], VAL_BASE, VAL_SHADOW)
    vis_h = max(0, min(ry + 32, CH) - max(ry, 0))
    e["clipped_to_list"] = vis_h < 32
    bottom = CY0 + min(ry + 32, CH)
    e["behind_textbox_px"] = max(0, bottom - max(CY0 + ry, TB_RECT[1]))
    e["visible"] = vis_h > 0 and e["behind_textbox_px"] < vis_h
    rows_json.append(e)
    if i == SEL:
        cursor_json = {"index": i, "arrow_rect": arrow, "row_rect": e["row_rect"],
                       "behind_textbox_px": e["behind_textbox_px"]}

# Up/down arrows (UpDownArrowMixin: 8-frame strips, frame 0; window active)
arrows = []
if ITEM_MAX > PAGE_ROWS:
    if top_row != 0:
        ua = load(G("Pictures", "uparrow.png"))
        fw = ua.width // 8
        arrows.append(("up", ua.crop((0, 0, fw, ua.height)), LIST_RECT[0] + LIST_RECT[2] // 2 - fw // 2, LIST_RECT[1]))
    if top_row + PAGE_ROWS < ITEM_MAX:
        da = load(G("Pictures", "downarrow.png"))
        fw = da.width // 8
        arrows.append(("down", da.crop((0, 0, fw, da.height)), LIST_RECT[0] + LIST_RECT[2] // 2 - fw // 2,
                       LIST_RECT[1] + LIST_RECT[3] - da.height))

# Description: updateDescription (array -> [current value], "" or missing -> default)
if SEL >= N_OPT:
    desc_text, desc_src = DEFAULT_DESC, "getDefaultDescription (Confirm row)"
else:
    o = ROWS[SEL]
    d = o.get("desc")
    if isinstance(d, list):
        pos = o["value"] if o["kind"] == "enum" else 0
        if pos < len(d):
            desc_text, desc_src = d[pos], "description[%d]" % pos
        else:
            desc_text, desc_src = DEFAULT_DESC, "getDefaultDescription (no description for value %d)" % pos
    else:
        desc_text, desc_src = d, "description"
    if desc_text == "" or desc_text is None:
        desc_text, desc_src = DEFAULT_DESC, "getDefaultDescription (empty description)"
if args.desc is not None:
    desc_text, desc_src = args.desc, "--desc (mockup text)"

# KifScrollText: every line drawn into contents (bitmapheight + 8), shown from oy 0
WRAP = TB_RECT[2] - SPEECH.borderX - TEXTPADDING
chars = getFormattedText(desc_text, WRAP, 32)
bmp_w = max([c[1] + c[3] for c in chars] + [1])
bmp_h = max([c[2] + c[4] for c in chars] + [1])
tb_crect_w = TB_RECT[2] - (SPEECH.trim[0] + (SPEECH.sr[2] - SPEECH.trim[2] + SPEECH.trim[0]))
tb_crect_h = TB_RECT[3] - (SPEECH.trim[1] + (SPEECH.sr[3] - SPEECH.trim[3] + SPEECH.trim[1]))
tbc = Image.new("RGBA", (max(bmp_w, tb_crect_w), max(bmp_h + 8, tb_crect_h)), (0, 0, 0, 0))
# shadowctag: colours go through 15-bit RGB
q = lambda c: C(c[0] >> 3 << 3, c[1] >> 3 << 3, c[2] >> 3 << 3)
D_BASE, D_SHADOW = q(SPEECH.text[0]), q(SPEECH.text[1])
dlines = {}
for c in chars:
    ch, cx, cy = c[0], c[1], c[2] + 4
    texts = dlines.setdefault(cy, {"x0": cx, "x1": cx, "text": "", "ink": None})
    if ch != "\n":
        texts["text"] += ch
    if ch in ("\n", "\r", " "):
        continue
    ink = None
    for dx, dy in [(2, 0), (0, 2), (2, 2)]:
        r = draw_text(tbc, cx + dx, cy + dy, c[3] + 2, ch, 0, D_SHADOW)
        if r:
            ink = union(ink, r[0])
    r = draw_text(tbc, cx, cy, c[3], ch, 0, D_BASE)
    texts["x0"] = min(texts["x0"], cx)
    texts["x1"] = max(texts["x1"], cx + c[3] - 2)
    texts["ink"] = union(texts["ink"], union(ink, r[0] if r else None))
over = bmp_h - (TB_RECT[3] - SPEECH.borderY)
TBX, TBY = TB_RECT[0] + SPEECH.trim[0], TB_RECT[1] + SPEECH.trim[1]

#-------------------------------------------------------------------------------
# Compose: scene viewport (title z 100, list z 100, arrows z 101), then the
# textbox (no viewport, z 99999, made after the viewport -> on top)
#-------------------------------------------------------------------------------
draw_window(screen, SYS, *TITLE_RECT, title_contents)
draw_window(screen, SYS, *LIST_RECT, contents)
for _, img, ax, ay in arrows:
    draw_sprite(screen, img, ax, ay)
draw_window(screen, SPEECH, *TB_RECT, tbc)

#-------------------------------------------------------------------------------
# JSON
#-------------------------------------------------------------------------------
info["title"] = {"text": TITLE, "rect": TITLE_RECT,
                 "contents_rect": [SYS.trim[0], SYS.trim[1], TITLE_RECT[2] - 32, TITLE_RECT[3] - 32],
                 "lines": [{"text": l["text"], "box": [16 + l["x"], 16 + l["ascent_y"], l["width"], line_height()],
                            "ink": ink_rect(l["ink"], 16, 16)} for l in title_lines]}
info["list_window"] = {"rect": LIST_RECT, "contents_rect": [CX0, CY0, CW, CH], "height_rule": list_rule,
                       "row_height": 32, "page_rows": PAGE_ROWS, "item_count": ITEM_MAX, "top_row": top_row,
                       "selected": SEL, "name_column": {"width": NAMEW, "rule": "longest enum name + ' *' + 20 "
                       "(%d), clamped to %d..%d of the %d px row" % (max(names_w) + 20 if names_w else 0,
                                                                     FULL * 3 // 10, FULL * 11 // 20, FULL),
                                                         "value_width": VALW, "x": CX0 + 16},
                       "scroll_arrows": {a[0]: [a[2], a[3], a[1].width, a[1].height] for a in arrows}}
info["rows"] = rows_json
drawn = {r["index"]: r["visible"] for r in rows_json}
info["options"] = [{"index": i, "kind": o["kind"], "key": o.get("key"), "name": o["name"],
                    "values": o.get("values"), "value_index": o.get("value"), "description": o.get("desc"),
                    "extra_row": bool(o.get("extra_row")), "on_screen": drawn.get(i, False)}
                   for i, o in enumerate(ROWS)] + \
                  [{"index": N_OPT, "kind": "confirm", "name": "Confirm", "description": DEFAULT_DESC,
                    "on_screen": drawn.get(N_OPT, False)}]
info["cursor"] = cursor_json
info["description_box"] = {
    "rect": TB_RECT, "contents_rect": [TBX, TBY, tb_crect_w, tb_crect_h], "wrap_width": WRAP,
    "text": desc_text, "source": desc_src, "line_height": 32,
    "lines": [{"text": v["text"].strip(), "box": [TBX + v["x0"], TBY + k, v["x1"] - v["x0"], line_height()],
               "ink": ink_rect(v["ink"], TBX, TBY), "visible": k + 32 <= tb_crect_h + 4}
              for k, v in sorted(dlines.items())],
    "scrolls": over > 8,
    "note": ("%d lines: KifScrollText holds the top 1.5 s, scrolls %d px at 24 px/s, holds 1.5 s, starts over"
             % (bmp_h // 32, over + 4)) if over > 8 else "fits (no scrolling)"}
info["windows"] = {"title": TITLE_RECT, "list": LIST_RECT, "description": TB_RECT,
                   "z_order": "black (pbFadeOutIn) < title (z 100) < list (z 100) < scroll arrows (z 101), "
                              "all in the scene viewport z 99999 < description box (no viewport, z 99999, made later)"}
info["settings"] = {k: get(k) for k in sorted(set(list(DEFAULTS) + list(settings)))}
info["changed_marked"] = sorted(changed_keys) if not args.intro else []
info["seed"] = format_seed()
info["bans"] = dict(bans)
if ITEM_BANS_NOTE:
    info["bans_note"] = "items: " + ITEM_BANS_NOTE
info["entrances_available"] = ER_AVAILABLE
info["notes"] = ("Rects are [x, y, w, h] in 512x384 screen pixels. 'draw_rect' is the rect passed to "
                 "pbDrawShadowText; 'box' starts at the ascent line (y + 4) with the advance width and the font "
                 "height; 'ink' is the drawn pixels incl. the shadow. 'behind_textbox_px': rows of the list under "
                 "the description box (it is translucent, so they show through dimmed).")

out = args.out
os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
screen.convert("RGB").save(out)
base_name, ext = os.path.splitext(out)
screen.convert("RGB").resize((W * 2, H * 2), Image.NEAREST).save(base_name + "@2x" + ext)
with open(base_name + ".json", "w", encoding="utf-8") as f:
    json.dump(info, f, indent=1, ensure_ascii=False)
print("saved", out)
