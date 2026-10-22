# encoding: utf-8
# Mockups: Expanded Dex, part 2: the Expanded Pokedex. Five designs, each two
# screens, over KIF Beta's own Pokedex list (dex_backdrop.py: PIF's list
# lists seen species only, so HR's IDs skip numbers: 579 Glameow, 582
# Stunky, 606 Snivy, 751 Rowlet...). HR's real Expanded sprites (xd/).
# Design 1 = one list (expanded species after 576) with an EX tag, and a
# filter (Y) for All / Kanto / Expanded.
# Usage (from this folder): ruby expdex_designs.rb "<KIF Beta>" <work dir with metrics.json>
SRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "qa_designs.rb"), :encoding => "UTF-8")
eval(SRC.split("c = palette(2)\n")[0], binding, "qa_designs.rb")

XD = File.join(HERE, "xd")
OVER = layer(3); OVER.z = 4
EXC = Color.new(130, 190, 250); GOLD = Color.new(240, 200, 70); RED = Color.new(220, 60, 60); INK = Color.new(60, 60, 68)
X_BTN = "p:2"; Y_BTN = "p:3"
def bg(c, name); frame(c, false); OVER.bitmap.clear; MAPS.bitmap = Bitmap.new(File.join(XD, name)); end
def xicon(b, sp, cx, cy, size)
  b.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), bmp(File.join(XD, sp + "_icon.png")), Rect.new(0, 0, 64, 64))
end
def xspr(b, sp, cx, cy, size)
  b.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), bmp(File.join(XD, sp + ".png")), Rect.new(0, 0, 96, 96))
end
def ex_tag(t, x, y); P.pill(t, x, y, "EX", Color.new(30, 60, 100), EXC, true); end
# rows of dex_mix (top 571): 571-576 then 579, 582, 606, 751 at y = 46 + 32r
MIX_EX_ROWS = [6, 7, 8, 9]
def tag_rows(t, rows); rows.each { |r| ex_tag(t, 462, 46 + 32 * r + 9) }; end
def popup(c, x, y, w, h, title)
  d = OVER.bitmap
  UI.rbox(d, x, y, x + w, y + h, 8, col(c[:panel], 255), c[:selb])
  P.text(d, x, y + 4, w, 22, title, c[:title], PF::ROW, 2)
  d.fill_rect(x + 8, y + 28, w - 16, 1, c[:line])
end
def counts_box(c, kanto, ex)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 4, 304, 220, 376, 6, Color.new(248, 248, 248), RED)
  [["Kanto", kanto, 576, RED], ["Expanded", ex, 522, Color.new(40, 110, 200)]].each_with_index do |(l, v, mx, colr), k|
    y = 310 + k * 32
    P.text(t, 14, y, 90, 20, l, INK, PF::TEXT)
    P.text(t, 120, y, 90, 20, "#{v}/#{mx}", INK, PF::TEXT, 1)
    b.fill_rect(14, y + 22, 196, 4, Color.new(220, 220, 220)); b.fill_rect(14, y + 22, (196 * v / mx.to_f).round, 4, colr)
  end
end

c = palette(2)
shot = proc { |n| dump_as(n) }

#================================================================ ED1 Recommended: one list with EX tags; Y filters All / Kanto / Expanded
bg(c, "dex_mix.png"); tag_rows(TOP.bitmap, MIX_EX_ROWS)
P.pill(TOP.bitmap, 112 - 34, 90, "EXPANDED", Color.new(30, 60, 100), EXC, false)
shot.call("ED1_list")
bg(c, "dex_ex.png")
popup(c, 300, 120, 170, 120, "Show")
d = OVER.bitmap
[["All", "586"], ["Kanto", "576"], ["Expanded", "10"]].each_with_index do |(l, n), k|
  y = 154 + k * 26
  UI.rbox(d, 306, y, 464, y + 24, 5, c[:sel], c[:selb]) if k == 2
  P.text(d, 316, y, 100, 24, l, c[:txt], PF::TEXT); P.text(d, 400, y, 56, 24, n, c[:dim], PF::TEXT, 1)
end
shot.call("ED1_filter")

#================================================================ ED2: two dexes as tabs in the title bar (Kanto / Expanded)
def dex_tabs(c, sel)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(150, 4, 212, 26, Color.new(220, 50, 50))
  [["KANTO", 576], ["EXPANDED", 522]].each_with_index do |(n, cnt), i|
    x = 156 + i * 102
    UI.rbox(b, x, 6, x + 98, 26, 5, i == sel ? Color.new(248, 248, 248) : Color.new(170, 30, 30))
    P.text(t, x, 7, 98, 18, n, i == sel ? RED : Color.new(248, 220, 220), PF::TINY, 2)
  end
end
bg(c, "../dex/a_list_576.png"); dex_tabs(c, 0)
shot.call("ED2_kanto")
bg(c, "dex_ex.png"); dex_tabs(c, 1)
shot.call("ED2_expanded")

#================================================================ ED3: by generation (a Gen tag on the name; Y jumps by generation)
GENS = [["Gen 4", 2, 107], ["Gen 5", 1, 156], ["Gen 6", 0, 72], ["Gen 7", 3, 88], ["Gen 8", 2, 89], ["Gen 9", 2, 120]]
bg(c, "dex_ex.png")
P.pill(TOP.bitmap, 112 - 22, 90, "GEN 4", Color.new(30, 60, 100), EXC, false)
shot.call("ED3_list")
bg(c, "dex_ex.png")
popup(c, 230, 50, 240, 230, "Jump to Generation")
d = OVER.bitmap
GENS.each_with_index do |(g, n, mx), k|
  y = 86 + k * 30
  UI.rbox(d, 236, y, 464, y + 28, 5, c[:sel], c[:selb]) if k == 3
  P.text(d, 248, y + 2, 80, 24, g, c[:txt], PF::TEXT)
  d.fill_rect(320, y + 12, 80, 5, c[:dark]); d.fill_rect(320, y + 12, [(80 * n / mx.to_f).round, 2].max, 5, EXC)
  P.small(d, 404, y + 6, 56, 16, "#{n}/#{mx}", c[:dim], 1)
end
shot.call("ED3_jump")

#================================================================ ED4: an info card for expanded species (origin, sprite credit)
bg(c, "dex_mix.png"); tag_rows(TOP.bitmap, MIX_EX_ROWS)
shot.call("ED4_list")
bg(c, "dex_mix.png")
popup(c, 56, 40, 400, 290, "No. 579 Glameow")
d = OVER.bitmap
xspr(d, "GLAMEOW", 140, 150, 150)
P.pill(d, 236, 80, "EXPANDED DEX", Color.new(30, 60, 100), EXC, false)
[["From", "Gen 4 (Sinnoh)"], ["Type", "Normal"], ["Seen", "Route 24, Oct 18"], ["Owned", "Yes"], ["Sprite", "HR Expanded Pack"]].each_with_index do |(l, v), k|
  y = 104 + k * 24
  P.small(d, 236, y, 60, 16, l, c[:dim]); P.small(d, 296, y, 156, 16, v, c[:txt])
end
P.small_wrap(d, "It claws if displeased and purrs when affectionate.", 360).first(2).each_with_index { |ln, k| P.small(d, 76, 238 + k * 17, 360, 17, ln, c[:txt]) }
P.small(d, 76, 290, 360, 16, "Shift: Evolutions (Purugly, Lv. 38)", c[:dim])
shot.call("ED4_info")

#================================================================ ED5: the counts box split into Kanto and Expanded with progress bars
bg(c, "dex_mix.png"); tag_rows(TOP.bitmap, MIX_EX_ROWS); counts_box(c, 576, 10)
shot.call("ED5_seen")
bg(c, "dex_mix.png"); tag_rows(TOP.bitmap, MIX_EX_ROWS); counts_box(c, 209, 3)
b = BASE.bitmap; t = TOP.bitmap
P.pill(t, 216, 306, "OWNED", Color.new(60, 20, 20), Color.new(248, 248, 248), true)
shot.call("ED5_owned")
