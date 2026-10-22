# encoding: utf-8
# Mockups: Hook Checker (topic 34), output 2: the Update Alert. Only in
# Stonewall's copy (never shipped): at boot, when KIF Beta's version changed
# since the last check, the Hook Checker runs and says what it found.
# Backdrop: the chosen Load Screen (load/load_designs.rb, design 1).
# Each design is a pair: problems found (left), everything OK (right).
# Usage (from this folder): ruby ua_designs.rb "<KIF Beta>" <work dir with metrics.json>
LSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "load/load_designs.rb"), :encoding => "UTF-8")
L1_MARK = "#================================================================ L1 Recommended"
eval(LSRC.split(L1_MARK)[0], binding, "load_designs.rb")
L1_CODE = LSRC.split(L1_MARK)[1].split("#================================================================ L2")[0].sub('dump_as("L1_load")', "").split("\n", 2)[1]
OVER = layer(4)
def load_bg(c, hints_on = true)
  OVER.bitmap.clear
  eval(L1_CODE, binding, "load_designs.rb")
  CUR.visible = false
end

COUNTS = [["Broken", 1, RED], ["Changed Upstream", 2, GOLD], ["Shared Methods", 3, BLUE], ["Settings Missing", 1, RED], ["OK", 12, GREEN]]
UPD = "KIF Beta 0.21.52 to 0.21.60"
REPORT = "Logs/Hook Check 0.21.60.md"
def dim(o, a = 140); o.fill_rect(0, 0, W, H, Color.new(0, 0, 0, a)); end
def count_rows(o, c, x, y, w, rows, step = 22, font = PF::TEXT)
  rows.each_with_index do |(l, n, colr), i|
    yy = y + i * step
    UI.rbox(o, x, yy + 6, x + 8, yy + 14, 4, colr)
    P.text(o, x + 16, yy, w - 60, step, l, c[:txt], font)
    P.text(o, x + w - 44, yy, 44, step, n.to_s, n > 0 && colr != GREEN ? colr : c[:dim], font, 2)
  end
end
def bar_hints(c, pairs)
  BASE.bitmap.fill_rect(0, H - 28, W, 28, c[:bg]); TOP.bitmap.fill_rect(0, H - 28, W, 28, Color.new(0, 0, 0, 0))
  hints(c, pairs)
end

c = palette(2)

#================================================================ UA1 Recommended: a notice over the load screen; A opens the results
def ua1(c, ok)
  load_bg(c)
  o = OVER.bitmap
  dim(o)
  x0 = 96; x1 = 416; y0 = ok ? 110 : 64; y1 = ok ? 268 : 318
  UI.rbox(o, x0, y0, x1, y1, 8, c[:panel2], ok ? GREEN : RED)
  P.text(o, x0, y0 + 6, x1 - x0, 26, "KIF Beta Updated", c[:title], PF::ROW, 2)
  P.small(o, x0, y0 + 32, x1 - x0, 16, "0.21.52 to 0.21.60", c[:dim], 2)
  o.fill_rect(x0 + 12, y0 + 52, x1 - x0 - 24, 1, c[:line])
  if ok
    P.text(o, x0, y0 + 62, x1 - x0, 24, "All 15 Hooks OK", GREEN, PF::ROW, 2)
    P.small(o, x0, y0 + 90, x1 - x0, 16, "Takeovers, locks and settings are OK too.", c[:txt], 2)
    P.small(o, x0, y0 + 110, x1 - x0, 16, "Report: #{REPORT}", c[:dim], 2)
  else
    count_rows(o, c, x0 + 24, y0 + 60, x1 - x0 - 48, COUNTS)
    o.fill_rect(x0 + 12, y0 + 176, x1 - x0 - 24, 1, c[:line])
    P.small(o, x0, y0 + 184, x1 - x0, 16, "Report: #{REPORT}", c[:dim], 2)
    UI.rbox(o, x0 + 20, y0 + 210, x0 + 150, y0 + 238, 6, c[:sel], c[:selb]); P.text(o, x0 + 20, y0 + 212, 130, 24, "Open Results", c[:white], PF::TEXT, 2)
    UI.rbox(o, x1 - 150, y0 + 210, x1 - 20, y0 + 238, 6, c[:dark], c[:line]); P.text(o, x1 - 150, y0 + 212, 130, 24, "Later", c[:txt], PF::TEXT, 2)
  end
  bar_hints(c, ok ? [[A_BTN, "OK"]] : [[:lr, "Choose"], [A_BTN, "Select"], [B_BTN, "Later"]])
end
ua1(c, false); dump_as("UA1_problems")
ua1(c, true); dump_as("UA1_ok")

#================================================================ UA2: a toast in the corner for a few seconds; Select opens the results
def ua2(c, ok)
  load_bg(c)
  o = OVER.bitmap
  colr = ok ? GREEN : RED
  x0 = W - 276; y0 = 6
  UI.rbox(o, x0, y0, W - 6, y0 + 58, 6, Color.new(20, 24, 34, 240), colr)
  UI.rbox(o, x0 + 10, y0 + 10, x0 + 24, y0 + 24, 7, colr)
  P.text(o, x0 + 32, y0 + 4, 236, 22, ok ? "Hooks OK on 0.21.60" : "Hook Check: 0.21.60", c[:white], PF::TEXT)
  P.small(o, x0 + 32, y0 + 26, 236, 16, ok ? "All hooks and settings are OK." : "1 broken, 2 changed, 1 missing.", ok ? c[:txt] : colr)
  P.small(o, x0 + 32, y0 + 40, 236, 14, ok ? "" : "Hold Select: Results", c[:dim])
  o.fill_rect(x0 + 6, y0 + 54, (W - 12 - x0) * 2 / 3, 2, colr)
end
ua2(c, false); dump_as("UA2_problems")
ua2(c, true); dump_as("UA2_ok")

#================================================================ UA3: in place of the What's New panel, until the next KIF update
def ua3(c, ok)
  load_bg(c)
  o = OVER.bitmap
  b = BASE.bitmap
  colr = ok ? GREEN : RED
  TOP.bitmap.fill_rect(284, 218, W - 284, 92, Color.new(0, 0, 0, 0))
  UI.rbox(o, 286, 220, 466, 308, 6, c[:panel2], colr)
  P.text(o, 296, 222, 160, 20, ok ? "Hooks OK" : "Hook Check", colr, PF::TEXT)
  P.small(o, 296, 242, 160, 14, "KIF Beta 0.21.60", c[:dim])
  if ok
    P.small(o, 296, 262, 160, 16, "All 15 hooks, takeovers", c[:txt])
    P.small(o, 296, 278, 160, 16, "and settings are OK.", c[:txt])
  else
    count_rows(o, c, 296, 255, 160, COUNTS.first(4).map { |l, n, cc| [l.sub("Shared Methods", "Shared").sub("Changed Upstream", "Changed").sub("Settings Missing", "Settings"), n, cc] }, 12, PF::TINY)
  end
  bar_hints(c, [[:ud, "Choose"], [:lr, "Save File"], [A_BTN, "Select"], ["p:9", ""], ["p:10", "Hook Check"]])
end
ua3(c, false); dump_as("UA3_problems")
ua3(c, true); dump_as("UA3_ok")

#================================================================ UA4: the version line says it; nothing pops up
def ua4(c, ok)
  load_bg(c)
  o = OVER.bitmap
  colr = ok ? GREEN : RED
  TOP.bitmap.fill_rect(250, 308, 220, 18, Color.new(0, 0, 0, 0))
  UI.rbox(o, 286, 309, 466, 327, 5, Color.new(colr.red / 5, colr.green / 5, colr.blue / 5, 230), colr)
  UI.rbox(o, 292, 315, 298, 321, 3, colr)
  P.text(o, 302, 311, 162, 14, ok ? "KIF Beta 0.21.60: Hooks OK" : "KIF Beta 0.21.60: 1 Broken Hook", colr, PF::TINY)
end
ua4(c, false); dump_as("UA4_problems")
ua4(c, true); dump_as("UA4_ok")

#================================================================ UA5: its own screen at boot, before the load screen
def ua5(c, ok)
  frame(c); OVER.bitmap.clear
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, 34, c[:panel2]); b.fill_rect(0, 33, W, 1, c[:line])
  P.text(t, 0, 3, W, 28, "Hook Check", c[:title], PF::TITLE, 2)
  P.text(t, 0, 44, W, 22, UPD, c[:txt], PF::TEXT, 2)
  UI.rbox(b, 96, 72, 416, 84, 6, c[:dark], c[:line]); UI.rbox(b, 96, 72, 416, 84, 6, ok ? GREEN : GOLD)
  P.small(t, 96, 88, 320, 16, "15 hooks, 1 takeover, 1 lock, 1 module, 6 settings checked.", c[:dim], 2)
  UI.rbox(b, 96, 112, 416, ok ? 200 : 262, 8, c[:panel], ok ? GREEN : RED)
  if ok
    P.text(t, 96, 130, 320, 26, "All OK", GREEN, PF::ROW, 2)
    P.small(t, 96, 160, 320, 16, "Continuing in 2 s.", c[:dim], 2)
  else
    count_rows(t, c, 120, 120, 272, COUNTS)
    P.small(t, 96, 238 - 4, 320, 16, "Report: #{REPORT}", c[:dim], 2)
    UI.rbox(b, 116, 276, 246, 304, 6, c[:sel], c[:selb]); P.text(t, 116, 278, 130, 24, "Open Results", c[:white], PF::TEXT, 2)
    UI.rbox(b, 266, 276, 396, 304, 6, c[:dark], c[:line]); P.text(t, 266, 278, 130, 24, "Continue", c[:txt], PF::TEXT, 2)
  end
  hints(c, ok ? [[A_BTN, "Continue"]] : [[:lr, "Choose"], [A_BTN, "Select"]])
end
ua5(c, false); dump_as("UA5_problems")
ua5(c, true); dump_as("UA5_ok")
