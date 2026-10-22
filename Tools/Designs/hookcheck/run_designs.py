# Mockups: Release Builder (topic 38), output 1: The Run, in the console
# (PowerShell window, Consolas). Old KR's Kanto Reloaded Publisher, pointed
# at KIF Beta/Mods/KantoReloaded, with the new checks (tests, Hook Checker,
# Patch Checker, Style Checker), the update manifest and the release notes.
# Each design is a pair: mid-run (left), a check that fails and stops it
# (right). Writes rn-1..rn-5.png (2080x768) to the given folder.
# Usage: python run_designs.py <out dir>
import sys, os
from PIL import Image, ImageDraw, ImageFont
OUT = sys.argv[1]
MONO = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 17)
MONOB = ImageFont.truetype("C:/Windows/Fonts/consolab.ttf", 17)
BG = (12, 12, 12); FG = (204, 204, 204); DIM = (118, 118, 118); GRN = (22, 198, 12); RED = (231, 72, 86)
YEL = (249, 241, 165); CYN = (58, 150, 221); WHT = (242, 242, 242); MAG = (180, 0, 158)
W, H = 1024, 768; LH = 22; X0 = 16

def panel(lines, title="Kanto Reloaded Publisher"):
    im = Image.new("RGB", (W, H), BG); d = ImageDraw.Draw(im)
    d.rectangle([0, 0, W, 30], fill=(32, 32, 32))
    d.text((12, 6), "PowerShell  " + title, font=MONO, fill=DIM)
    y = 42
    for ln in lines:
        x = X0
        if isinstance(ln, str): ln = [(ln, FG)]
        for seg in ln:
            txt, col = seg[0], seg[1]
            f = MONOB if len(seg) > 2 and seg[2] else MONO
            d.text((x, y), txt, font=f, fill=col)
            x += d.textlength(txt, font=f)
        y += LH
    return im

def pair(name, a, b):
    out = Image.new("RGB", (W * 2 + 32, H), (10, 14, 24))
    out.paste(a, (0, 0)); out.paste(b, (W + 32, 0))
    out.save(os.path.join(OUT, name)); print(name)

def bar(pct, width=40):
    n = int(width * pct / 100)
    return "[" + "#" * n + "-" * (width - n) + "]"

OKM = ("  OK  ", GRN); FAIL = (" FAIL ", RED); RUN = ("  ..  ", YEL); WAIT = ("      ", DIM)
HEAD = [[("Kanto Reloaded Publisher", WHT, True), ("   v2.1.0  Update #12: Controls", DIM)], [("Source  KIF Beta\\Mods\\KantoReloaded   Repo  Stonewallxx/Kanto-Reloaded", DIM)], ""]
STEPS = [("Project files", "mod.json 2.1.0, requires KIF >=0.21.52"), ("Changelog", "Update #12 finalized (Changelog Standard)"),
         ("Ruby syntax", "64 files"), ("Load order", "61 entries"), ("Tests", "116 checks passed"),
         ("Hook Checker", "KIF Beta 0.21.60: 15 hooks OK"), ("Patch Checker", "3 patch files OK"), ("Style Checker", "412 strings, no problems"),
         ("Build", "KantoReloaded.zip, dev files left out"), ("Verify zip", "Changelog inside matches"),
         ("GitHub release", "v2.1.0 published, upload verified"), ("Update manifest", "Version, SHA-256, size, changelog"),
         ("Notes and Discord", "release-notes.md, discord-post.txt")]
FAIL_HOOK = ("Hook Checker", "KIF Beta 0.21.60: 1 broken (autosave_rows)")

# ---------------------------------------------------------------- RN1 Recommended: old KR's look; the step log, one live progress line, the end summary
def rn1(fail):
    lines = list(HEAD)
    done = 5 if fail else 9
    for i, (s, v) in enumerate(STEPS[:done]):
        lines.append([("  done  ", GRN), (f"{s:<18}", FG), (v, DIM)])
    if fail:
        lines.append([("  FAIL  ", RED, True), (f"{'Hook Checker':<18}", WHT), (FAIL_HOOK[1], RED)])
        lines += ["", [("Stopped: nothing was built or published.", RED, True)],
                  [("  autosave_rows: KIF::SettingsScreen.pif_items is gone (now pif_rows).", FG)],
                  [("  Report: ", DIM), ("Logs\\Hook Check 0.21.60.md", CYN)], "",
                  [("Fix it, then run Publish Kanto Reloaded.bat again.", YEL)]]
    else:
        lines += ["", [("Kanto Reloaded Publisher ", FG), (bar(71), GRN), ("  71%  Verify zip: 214 files", FG)]]
    pair_cache.append(panel(lines))

# ---------------------------------------------------------------- RN2: a status column like a boot log: [ OK ] / [FAIL] / [ .. ]
def rn2(fail):
    lines = list(HEAD)
    for i, (s, v) in enumerate(STEPS):
        if fail:
            st = OKM if i < 5 else (FAIL if i == 5 else WAIT)
            vv = FAIL_HOOK[1] if i == 5 else (v if i < 5 else "skipped")
        else:
            st = OKM if i < 9 else (RUN if i == 9 else WAIT)
            vv = v if i < 9 else ("checking..." if i == 9 else "")
        lines.append([("[", DIM), st, ("] ", DIM), (f"{s:<18}", FG if st != WAIT else DIM), (vv, RED if st == FAIL else (DIM if st == WAIT else DIM))])
    lines += ["", [("1 check failed: stopped before Build.", RED, True)] if fail else [("9 of 13 steps done.", FG)]]
    pair_cache.append(panel(lines))

# ---------------------------------------------------------------- RN3: three stages (Check, Build, Publish) with times; a stage opens while it runs
def rn3(fail):
    lines = list(HEAD)
    lines.append([("CHECK    ", WHT, True), ("8 checks", DIM), ("        4.2 s  ", DIM), ("done" if not fail else "FAILED", GRN if not fail else RED, True)])
    if fail:
        for s, v in STEPS[:5]:
            lines.append([("   + ", GRN), (f"{s:<18}", FG), (v, DIM)])
        lines.append([("   x ", RED), (f"{'Hook Checker':<18}", WHT), (FAIL_HOOK[1], RED)])
        lines.append([("   - ", DIM), ("Patch Checker, Style Checker: skipped", DIM)])
        lines += ["", [("BUILD    ", DIM, True), ("not run", DIM)], [("PUBLISH  ", DIM, True), ("not run", DIM)], "",
                  [("Open the report? ", FG), ("[Y] Yes  [N] No", YEL)]]
    else:
        lines += [[("BUILD    ", WHT, True), ("zip and verify", DIM), ("  1.1 s  ", DIM), ("running", YEL, True)],
                  [("   + ", GRN), (f"{'Build':<18}", FG), ("KantoReloaded.zip (2.1 MB), 214 files", DIM)],
                  [("   . ", YEL), (f"{'Verify zip':<18}", FG), (bar(60, 24), YEL)],
                  [("PUBLISH  ", DIM, True), ("release, manifest, notes", DIM), ("        waiting", DIM)]]
    pair_cache.append(panel(lines))

# ---------------------------------------------------------------- RN4: minimal; one live line while it runs, a table at the end
def rn4(fail):
    lines = list(HEAD)
    if fail:
        lines += [[("Stopped at Hook Checker", RED, True)], ""]
        lines.append([(f"{'Step':<18}{'Result':<10}Details", DIM)])
        for s, v in STEPS[:5]:
            lines.append([(f"{s:<18}", FG), (f"{'OK':<10}", GRN), (v, DIM)])
        lines.append([(f"{'Hook Checker':<18}", WHT), (f"{'FAIL':<10}", RED), (FAIL_HOOK[1], RED)])
        lines += ["", [("Nothing was built or published.", FG)]]
    else:
        lines += [[(bar(71, 56), GRN), ("  71%", FG)], [("Verify zip: reading KantoReloaded/Changelog.md", DIM)], "", [("(the step table appears when it's done)", DIM)]]
    pair_cache.append(panel(lines))

# ---------------------------------------------------------------- RN5: a framed dashboard; the release card on top, the steps as a grid below
def box(lines, title, w=94):
    out = [[("+" + "-" * (w - 2) + "+", DIM)], [("| ", DIM), (f"{title:<{w - 4}}", WHT, True), (" |", DIM)]]
    for ln in lines:
        txt = "".join(s[0] for s in ln)
        out.append([("| ", DIM)] + ln + [(" " * max(0, w - 4 - len(txt)) + " |", DIM)])
    out.append([("+" + "-" * (w - 2) + "+", DIM)])
    return out
def rn5(fail):
    lines = box([[("v2.1.0  Update #12: Controls      Stonewallxx/Kanto-Reloaded", FG)], [("KIF Beta 0.21.60, requires >=0.21.52", DIM)]], "Kanto Reloaded Release")
    grid = []
    for i in range(0, len(STEPS), 3):
        row = []
        for j, (s, v) in enumerate(STEPS[i:i + 3]):
            k = i + j
            if fail:
                st, col = ("ok ", GRN) if k < 5 else (("FAIL", RED) if k == 5 else ("--", DIM))
            else:
                st, col = ("ok ", GRN) if k < 9 else (("..", YEL) if k == 9 else ("--", DIM))
            row += [(f"{st:<5}", col), (f"{s:<24}", FG if col != DIM else DIM)]
        grid.append(row)
    lines += [""] + box(grid, "Steps") + [""]
    lines.append([("Stopped: Hook Checker found 1 broken hook (autosave_rows).", RED, True)] if fail else [(bar(71, 56), GRN), ("  71%  Verify zip", FG)])
    pair_cache.append(panel(lines))

for k, fn in enumerate([rn1, rn2, rn3, rn4, rn5], start=1):
    pair_cache = []
    fn(False); fn(True)
    pair(f"rn-{k}.png", pair_cache[0], pair_cache[1])
