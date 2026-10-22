# Mockups: Style Checker (topic 39), output 2: Fix It for Me, in the console.
# The real findings from KR today (Splits.rb:35, the Color spellings). Each
# design is a pair: a fix being offered (left), the end (right).
# Writes sf-1..sf-5.png (2080x768). Usage: python fix_designs.py <out dir>
import sys, os
sys.argv = [sys.argv[0], sys.argv[1]]
HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, "run_designs.py"), encoding="utf-8").read().split("# ---------------------------------------------------------------- RN1")[0]
exec(src)

HEADF = [[("Kanto Reloaded Style Checker", WHT, True), ("   Fix It for Me", DIM)], [("KIF Beta\\Mods\\KantoReloaded   5 fixes, 4 ignored", DIM)], ""]
def end_summary(extra=None):
    lines = list(HEADF)
    lines += [[("Done.", GRN, True)], "",
              [("  Fixed     ", FG), ("4", GRN)], [("  Skipped   ", FG), ("1", YEL), ("   Splits.rb:35 (you'll see it next time)", DIM)], [("  Ignored   ", FG), ("0 new", DIM)], "",
              [("  Changed   ", FG), ("Palette.rb, Pages.rb, WindowFrames.rb", FG)],
              [("  Backup    ", FG), ("Logs\\Style Fixes 2026-10-18 14-25\\ (the 3 files as they were)", CYN)], ""]
    if extra: lines += extra
    return lines

# ---------------------------------------------------------------- SF1 Recommended: one at a time; the line before and after, then Y, N, I, A or Q
def sf1():
    a = list(HEADF) + [[("2 of 5  ", DIM), ("Spelling: Color", YEL, True)], [("Core\\UI\\Palette.rb:89", CYN)], "",
         [("  - ", RED), ("Colours of Kanto Reloaded's screens. Base keeps KIF Settings' own colours.", RED)],
         [("  + ", GRN), ("Colors of Kanto Reloaded's screens. Base keeps KIF Settings' own colors.", GRN)], "",
         [("[Y] Fix   [N] Skip   [I] Ignore from now on   [A] Fix all 4 Color   [Q] Stop", YEL)], [("> ", FG), ("y", WHT, True)]]
    pair("sf-1.png", panel(a, "Style Checker"), panel(end_summary(), "Style Checker"))

# ---------------------------------------------------------------- SF2: as a diff, file by file, like git; each change is a hunk
def sf2():
    a = list(HEADF) + [[("diff  Core/Interface/WindowFrames.rb", WHT, True)], [("@@ line 66 @@", MAG)],
         [("-  ", RED), ('"... Light a pale panel in the Theme\'s colour, Frost both."', RED)],
         [("+  ", GRN), ('"... Light a pale panel in the Theme\'s color, Frost both."', GRN)],
         [("@@ line 71 @@", MAG)],
         [("-  ", RED), ('"... Theme draws it in the Theme\'s colours, in the Theme Mode."', RED)],
         [("+  ", GRN), ('"... Theme draws it in the Theme\'s colors, in the Theme Mode."', GRN)], "",
         [("Apply this file's 2 changes? [y/n/e(dit)/q] ", YEL)]]
    pair("sf-2.png", panel(a, "Style Checker"), panel(end_summary(), "Style Checker"))

# ---------------------------------------------------------------- SF3: by rule; every finding of one rule, then fix them all or pick
def sf3():
    a = list(HEADF) + [[("Spelling: Color", YEL, True), ("   4 findings", DIM)], "",
         [("  1  ", DIM), ("Palette.rb:89         ", CYN), ("Colours ... colours  ->  Colors ... colors", FG)],
         [("  2  ", DIM), ("Pages.rb:21           ", CYN), ("colours  ->  colors", FG)],
         [("  3  ", DIM), ("WindowFrames.rb:66    ", CYN), ("colour  ->  color", FG)],
         [("  4  ", DIM), ("WindowFrames.rb:71    ", CYN), ("colours  ->  colors", FG)], "",
         [("Fix all 4? [Y] All  [P] Pick numbers  [N] None  ", YEL), ("Y", WHT, True)], "",
         [("Next rule: Capital After a Colon (1)", DIM)]]
    pair("sf-3.png", panel(a, "Style Checker"), panel(end_summary(), "Style Checker"))

# ---------------------------------------------------------------- SF4: preview first; every change numbered, then apply all, some, or none
def sf4():
    a = list(HEADF) + [[("Planned changes", WHT, True)], "",
         [("  #  File                  Line  Change", DIM)],
         [("  1  Splits.rb               35  ", FG), ("the -> The", GRN)],
         [("  2  Palette.rb              89  ", FG), ("Colours, colours -> Colors, colors", GRN)],
         [("  3  Pages.rb                21  ", FG), ("colours -> colors", GRN)],
         [("  4  WindowFrames.rb         66  ", FG), ("colour -> color", GRN)],
         [("  5  WindowFrames.rb         71  ", FG), ("colours -> colors", GRN)], "",
         [("Apply: [A] All   [numbers] e.g. 2-5   [N] None", YEL)], [("> ", FG), ("2-5", WHT, True)]]
    pair("sf-4.png", panel(a, "Style Checker"), panel(end_summary(), "Style Checker"))

# ---------------------------------------------------------------- SF5: never edits; writes a patch to review in VS Code
def sf5():
    a = list(HEADF) + [[("Writing a patch, nothing is changed yet.", FG)], "",
         [("  done  ", GRN), ("Splits.rb:35", CYN)], [("  done  ", GRN), ("Palette.rb:89", CYN)], [("  done  ", GRN), ("Pages.rb:21", CYN)],
         [("  done  ", GRN), ("WindowFrames.rb:66, 71", CYN)], "",
         [("Patch: ", FG), ("Logs\\style-fixes.patch", CYN), ("  (5 changes, 4 files)", DIM)]]
    b = list(HEADF) + [[("Patch ready.", GRN, True)], "",
         [("  Open it in VS Code to look over each change, then:", FG)],
         [("  git apply Logs\\style-fixes.patch", WHT)], "",
         [("  Or run Fix It for Me again with ", FG), ("--apply", YEL), (" to apply it here.", FG)]]
    pair("sf-5.png", panel(a, "Style Checker"), panel(b, "Style Checker"))

for fn in (sf1, sf2, sf3, sf4, sf5): fn()
