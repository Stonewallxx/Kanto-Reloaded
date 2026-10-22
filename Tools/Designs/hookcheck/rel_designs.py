# Mockups: Release Builder (topic 38), output 2: Release Notes and Discord
# Post. Both come from the Changelog (the Changelog Standard: fixed section
# order, empty sections removed at release, "Pokemon" spelling). The GitHub
# release notes (left, GitHub's dark page) and the Discord post (right,
# Discord's dark theme). A normal Discord message holds 2,000 characters.
# Sample: Kanto Reloaded Update #12 - Controls, v2.1.0 (sample entries).
# Writes rl-1..rl-5.png (2080x768). Usage: python rel_designs.py <out dir>
import sys, os, re
from PIL import Image, ImageDraw, ImageFont
OUT = sys.argv[1]
F = "C:/Windows/Fonts/"
def f(n, s): return ImageFont.truetype(F + n, s)
W, H = 1024, 768

# ---------------------------------------------------------------- a small Markdown renderer for both looks
class Look:
    def __init__(self, bg, fg, head, rule, link, code, base=16):
        self.bg, self.fg, self.head, self.rule, self.link, self.code = bg, fg, head, rule, link, code
        self.body = f("segoeui.ttf", base); self.bold = f("segoeuib.ttf", base)
        self.h1 = f("seguisb.ttf", base + 12); self.h2 = f("seguisb.ttf", base + 7); self.h3 = f("seguisb.ttf", base + 2); self.h4 = f("seguisb.ttf", base)
        self.small = f("segoeui.ttf", base - 3)
GH = Look((13, 17, 23), (230, 237, 243), (240, 246, 252), (48, 54, 61), (68, 147, 248), (110, 118, 129))
DC = Look((49, 51, 56), (219, 222, 225), (242, 243, 245), (63, 65, 71), (0, 168, 252), (148, 155, 164), 15)

def segs(L, text):
    out = []
    for p in re.split(r"(\*\*[^*]+\*\*|\[[^\]]+\]\([^)]+\)|<[^>]+>)", text):
        if not p: continue
        if p.startswith("**"): out.append((p[2:-2], L.bold, L.fg))
        elif p.startswith("["): out.append((re.match(r"\[([^\]]+)\]", p).group(1), L.body, L.link))
        elif p.startswith("<"): out.append((p[1:-1], L.body, L.link))
        else: out.append((p, L.body, L.fg))
    return out

def inline(d, L, x0, y, text, width, lh=24):
    x = 0; lines = 1
    for s, fnt, col in segs(L, text):
        for w in re.split(r"(\s+)", s):
            if not w: continue
            ww = d.textlength(w, font=fnt)
            if x + ww > width and w.strip():
                y += lh; x = 0; lines += 1
            if x == 0 and not w.strip(): continue
            d.text((x0 + x, y), w, font=fnt, fill=col); x += ww
    return y + lh

def md(d, L, x0, y, w, text):
    for r in text.splitlines():
        if r.startswith("# "): d.text((x0, y), r[2:], font=L.h1, fill=L.head); y += 40
        elif r.startswith("## "): d.text((x0, y), r[3:], font=L.h2, fill=L.head); y += 32; d.line([x0, y, x0 + w, y], fill=L.rule); y += 8
        elif r.startswith("### "): y += 4; d.text((x0, y), r[4:], font=L.h3, fill=L.head); y += 26
        elif r.startswith("#### "): d.text((x0, y), r[5:], font=L.h4, fill=L.head); y += 22
        elif re.match(r"\s*- ", r):
            ind = 22 if r.startswith("  ") else 0
            d.ellipse([x0 + 6 + ind, y + 9, x0 + 11 + ind, y + 14], fill=L.fg)
            y = inline(d, L, x0 + 20 + ind, y, r.strip()[2:], w - 20 - ind)
        elif r.strip() == "": y += 8
        elif r.startswith("-# "): d.text((x0, y), r[3:], font=L.small, fill=L.code); y += 20
        else: y = inline(d, L, x0, y, r, w) + 2
    return y

def github(notes, tag="v2.1.0", title="Version 2.1.0"):
    im = Image.new("RGB", (W, H), GH.bg); d = ImageDraw.Draw(im)
    d.rectangle([0, 0, W, 44], fill=(1, 4, 9)); d.text((16, 12), "Stonewallxx / Kanto-Reloaded   Releases", font=GH.body, fill=GH.code)
    d.rounded_rectangle([16, 56, W - 16, H + 20], 8, outline=GH.rule, fill=(13, 17, 23))
    d.text((32, 66), title, font=GH.h1, fill=GH.head)
    d.rounded_rectangle([32 + d.textlength(title, font=GH.h1) + 14, 76, 32 + d.textlength(title, font=GH.h1) + 74, 98], 11, outline=(35, 134, 54), fill=(13, 17, 23))
    d.text((32 + d.textlength(title, font=GH.h1) + 24, 77), "Latest", font=GH.small, fill=(63, 185, 80))
    d.text((32, 106), f"{tag}  .  Assets: KantoReloaded.zip (2.1 MB), KantoReloaded-manifest.json", font=GH.small, fill=GH.code)
    md(d, GH, 32, 136, W - 64, notes)
    return im

def discord(posts, channel="kanto-reloaded-updates"):
    im = Image.new("RGB", (W, H), DC.bg); d = ImageDraw.Draw(im)
    d.rectangle([0, 0, W, 44], fill=(43, 45, 49)); d.text((16, 12), "#  " + channel, font=DC.bold, fill=DC.head)
    y = 60
    for k, body in enumerate(posts):
        if k == 0:
            d.ellipse([16, y, 56, y + 40], fill=(214, 52, 60)); d.text((26, y + 8), "KR", font=DC.bold, fill=(255, 255, 255))
            d.text((70, y), "Stonewall", font=DC.bold, fill=(242, 63, 66)); d.text((70 + d.textlength("Stonewall", font=DC.bold) + 8, y + 3), "Today at 2:30 PM", font=DC.small, fill=DC.code)
            y += 24
        y = md(d, DC, 70, y, W - 100, body) + 10
    return im

def pair(name, a, b):
    out = Image.new("RGB", (W * 2 + 32, H), (10, 14, 24)); out.paste(a, (0, 0)); out.paste(b, (W + 32, 0))
    out.save(os.path.join(OUT, name)); print(name)

NOTES = """## Kanto Reloaded Update #12 - Controls
v2.1.0
Release Date: October 18, 2026
### SUMMARY
Adds the Controls page: every button can be changed for the keyboard and the controller, per area, with tap and hold actions.
### FEATURES
- Added the Controls page
  - Added rebinding per area (Global, Overworld, Menus, Battle)
  - Added tap and hold actions on any button
- Added Button Icons that follow the controller in use
### IMPROVEMENTS
- Moved the Speed-Up buttons to the Controls page
### BUG FIXES
- Fixed command menu text colours on Pokemon menus"""
LINKS = "**Download:** <github.com/Stonewallxx/Kanto-Reloaded/releases/tag/v2.1.0>"

# ---------------------------------------------------------------- RL1 Recommended: the full update block on GitHub; a short Discord post (summary, top features, links) in one message
def rl1():
    a = github(NOTES)
    post = """# Kanto Reloaded 2.1.0: Controls
Adds the Controls page: every button can be changed for the keyboard and the controller, per area, with tap and hold actions.
- Added the Controls page, with rebinding per area
- Added tap and hold actions on any button
- Added Button Icons that follow the controller in use
""" + LINKS + """
Full notes: [GitHub release](x)
-# 486 of 2,000 characters"""
    pair("rl-1.png", a, discord([post]))

# ---------------------------------------------------------------- RL2: the whole changelog on Discord too, split into numbered parts under 2,000 characters
def rl2():
    a = github(NOTES)
    p1 = """# Kanto Reloaded 2.1.0: Controls (1/2)
Adds the Controls page: every button can be changed for the keyboard and the controller, per area, with tap and hold actions.
## Features
- Added the Controls page
  - Added rebinding per area (Global, Overworld, Menus, Battle)
  - Added tap and hold actions on any button
- Added Button Icons that follow the controller in use"""
    p2 = """**(2/2)**
## Improvements
- Moved the Speed-Up buttons to the Controls page
## Bug Fixes
- Fixed command menu text colours on Pokemon menus
""" + LINKS
    pair("rl-2.png", a, discord([p1, p2]))

# ---------------------------------------------------------------- RL3: a Highlights block above the full notes on GitHub; Discord gets the highlights and the update's picture
def rl3():
    notes = """### Highlights
- **Controls page:** change every button, per area
- **Tap and hold:** two actions on one button

""" + NOTES
    a = github(notes)
    im = discord(["""# Kanto Reloaded 2.1.0: Controls
- **Controls page:** change every button, per area
- **Tap and hold:** two actions on one button
""" + LINKS])
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([70, 250, 520, 480], 8, fill=(30, 31, 34), outline=(63, 65, 71))
    d.text((90, 352), "the update's picture (Public Roadmap image)", font=DC.small, fill=DC.code)
    pair("rl-3.png", a, im)

# ---------------------------------------------------------------- RL4: posted for you by a Discord webhook as an announcement card, with an Updates role ping
def rl4():
    a = github(NOTES)
    im = Image.new("RGB", (W, H), DC.bg); d = ImageDraw.Draw(im)
    d.rectangle([0, 0, W, 44], fill=(43, 45, 49)); d.text((16, 12), "#  announcements", font=DC.bold, fill=DC.head)
    d.ellipse([16, 60, 56, 100], fill=(214, 52, 60)); d.text((26, 68), "KR", font=DC.bold, fill=(255, 255, 255))
    d.text((70, 60), "Kanto Reloaded", font=DC.bold, fill=(242, 243, 245))
    d.rounded_rectangle([70 + d.textlength("Kanto Reloaded", font=DC.bold) + 8, 62, 70 + d.textlength("Kanto Reloaded", font=DC.bold) + 40, 78], 3, fill=(88, 101, 242))
    d.text((70 + d.textlength("Kanto Reloaded", font=DC.bold) + 12, 62), "APP", font=DC.small, fill=(255, 255, 255))
    d.text((70, 84), "@Kanto Reloaded Updates", font=DC.body, fill=(201, 205, 251))
    d.rounded_rectangle([70, 112, 700, 420], 6, fill=(43, 45, 49)); d.rectangle([70, 112, 74, 420], fill=(214, 52, 60))
    md(d, DC, 88, 124, 590, """**Kanto Reloaded 2.1.0: Controls**
Adds the Controls page: every button can be changed for the keyboard and the controller, per area, with tap and hold actions.
**Features**
- Added the Controls page, with rebinding per area
- Added Button Icons that follow the controller in use
**Bug Fixes**
- Fixed command menu text colours on Pokemon menus
[Download v2.1.0](x)""")
    d.text((70, 432), "Posted by the Release Builder (webhook). Asks before posting.", font=DC.small, fill=DC.code)
    pair("rl-4.png", a, im)

# ---------------------------------------------------------------- RL5: minimal; GitHub gets the summary and the section counts, Discord three lines
def rl5():
    a = github("""## Kanto Reloaded Update #12 - Controls
v2.1.0
Release Date: October 18, 2026
### SUMMARY
Adds the Controls page: every button can be changed for the keyboard and the controller, per area, with tap and hold actions.
- **Features:** 2 (plus 2 subentries)
- **Improvements:** 1
- **Bug Fixes:** 1
Full changelog: [Changelog.md](x)""")
    pair("rl-5.png", a, discord(["""**Kanto Reloaded 2.1.0: Controls** is out. Change every button, per area.
""" + LINKS]))

for fn in (rl1, rl2, rl3, rl4, rl5): fn()
