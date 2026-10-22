# encoding: utf-8
# Mockups: Timing Profiler (topic 33), screen 1: the in-game Report Viewer.
# Sessions (newest first) are battles plus, new, map loads, menus and saving
# (Beyond Battles). Battle sections are old KR's (EBDX and KR Battle Menu
# work); the map load's are new. Slow = over 33.3 ms (two frames at 60).
# Each design is a pair: a Wild Battle, then a map load (Viridian City).
# Design 1 = the improved Settings layout (sessions as sections).
# Usage (from this folder): ruby tp_designs.rb "<KIF Beta>" <work dir with metrics.json>
PSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "patch_designs.rb"), :encoding => "UTF-8")
eval(PSRC.split("c = palette(2)\n")[0], binding, "patch_designs.rb")

KINDS = { :battle => ["B", [210, 80, 80]], :map => ["M", [60, 170, 160]], :menu => ["U", [96, 160, 232]], :save => ["S", [160, 110, 200]] }
SESSIONS = [["Wild Battle", :battle, :warn], ["Viridian City", :map, :err], ["Bag", :menu, :ok], ["Saving", :save, :ok],
            ["Brock", :battle, :ok], ["Pewter City", :map, :warn]]
# name, owner, calls, average ms, peak ms, slow frames (> 33.3 ms)
BATTLE = [["Target Icon Prewarm", "Kanto Reloaded", 1, 38.6, 38.6, 1], ["Battle Menu Draw", "Kanto Reloaded", 8, 6.8, 21.5, 0],
          ["Scene Frame Work", "EBDX", 1691, 0.9, 18.4, 0], ["Fight Refresh", "EBDX", 6, 4.4, 11.2, 0],
          ["Command Refresh", "EBDX", 12, 3.1, 9.8, 0], ["Native Frame Work", "PIF", 1691, 0.04, 5.2, 0],
          ["Double Abilities", "Kanto Reloaded", 6, 0.3, 0.9, 0], ["End-of-Round Phase", "PIF", 3, 0.6, 1.0, 0]]
OWNER_COL = { "Kanto Reloaded" => Color.new(214, 52, 60), "EBDX" => Color.new(230, 150, 60), "PIF" => Color.new(150, 160, 175), "KIF Beta" => Color.new(60, 170, 160) }
def owner_dot(t, x, y, owner); UI.rbox(t, x, y, x + 6, y + 6, 3, OWNER_COL[owner]); end
MAPLOAD = [["Map Data Load", "PIF", 3, 41.2, 88.5, 2], ["Tilemap Build", "PIF", 1, 54.0, 54.0, 1],
           ["Events Setup", "PIF", 1, 22.7, 22.7, 0], ["Fusion Sprite Load", "PIF", 4, 9.6, 17.3, 0],
           ["Cody's Map Cache", "KIF Beta", 3, 2.1, 4.8, 0], ["Overworld Pokémon", "Kanto Reloaded", 2, 3.1, 4.0, 0],
           ["Weather Start", "Kanto Reloaded", 1, 1.8, 1.8, 0], ["Music Change", "PIF", 1, 1.2, 1.2, 0]]
HEAD = { :battle => ["Wild Battle, Route 1", "16.7 s", "3 turns"], :map => ["Viridian City", "0.21 s", "from Route 1"] }
DESC = {
  :battle => ["Target Icon Prewarm", "Called once, 38.6 ms: one frame of battle froze while the target icons were drawn ahead of time.", ["KANTO RELOADED", "1 SLOW"]],
  :map => ["Map Data Load", "Viridian City and the two maps next to it, 3 loads, 88.5 ms at worst (Route 2). Nested in the Map Transfer: don't add sections together.", ["PIF", "2 SLOW"]]
}
def fmt(v); v < 1 ? format("%.2f", v) : format("%.1f", v); end
def peak_col(c, v); v > 33.3 ? RED2 : (v > 16.7 ? AMB : GREEN); end
def st_col(st); { :ok => GREEN, :warn => AMB, :err => RED2 }[st]; end
def rows_for(kind); kind == :battle ? BATTLE : MAPLOAD; end
def tp_frame(c, left = "Settings", right = "Mod Timings")
  page_frame(c, "Timing Profiler")
  b = BASE.bitmap; t = TOP.bitmap
  [[8, left], [W - 120, right]].each do |x, l|
    next unless l
    UI.rbox(b, x, 4, x + 112, 27, 5, c[:dark], c[:line]); P.text(t, x, 4, 112, 23, l, c[:dim], PF::TEXT, 2)
  end
end
def kind_box(t, x, y, kind)
  g, rgb = KINDS[kind]
  UI.rbox(t, x, y, x + 14, y + 14, 3, Color.new(*rgb)); P.glyph(t, x, y, 15, 15, g, Color.new(248, 248, 248))
end
def sessions_side(c, sel, focus = false)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 6, 36, 174, 262, 6, c[:panel])
  SESSIONS.each_with_index do |(n, k, st), i|
    y = 40 + i * 22
    UI.rbox(b, 9, y, 171, y + 20, 4, c[:sel], c[:selb]) if i == sel && focus
    kind_box(t, 14, y + 3, k)
    P.text(t, 33, y + 2, 118, 18, n, i == sel ? c[:white] : c[:dim])
    UI.rbox(t, 158, y + 7, 164, y + 13, 3, st_col(st))
  end
end
def boxes(c)
  b = BASE.bitmap
  UI.rbox(b, 180, 36, W - 6, 262, 6, c[:panel])
  UI.rbox(b, 6, 268, W - 6, H - 30, 6, c[:panel2], c[:line])
end

c = palette(2)

#================================================================ TP1 Recommended: the Settings layout; sessions as sections, sections sorted by peak
def tp1(c, kind, sel_session, sel)
  tp_frame(c); sessions_side(c, sel_session); boxes(c)
  t = TOP.bitmap
  P.heading(t, 190, 330, 43, HEAD[kind][0], c[:head], c[:line])
  [["PEAK", 404], ["SLOW", 452]].each { |l, x| P.text(t, x, 41, 46, 13, l, c[:dim], PF::TINY, 1) }
  rows_for(kind).each_with_index do |(n, owner, _, avg, pk, slow), i|
    y = 58 + i * 25
    cursor_at(184, y, W - 194, 24) if i == sel
    owner_dot(t, 194, y + 9, owner)
    P.text(t, 206, y, 196, 24, PF.fit(PF::TEXT, n, 196), c[:opt], PF::TEXT)
    P.text(t, 404, y, 46, 24, fmt(pk), peak_col(c, pk), PF::TEXT, 1)
    P.text(t, 452, y, 40, 24, slow.to_s, slow > 0 ? RED2 : c[:dim], PF::TEXT, 1)
  end
  d = DESC[kind]; desc_box(c, d[0], d[1], d[2])
  hints(c, [[:ud, "Select"], [Y_BTN, "Sort: Peak"], [X_BTN, "Owner"], [B_BTN, "Sessions"]])
end
tp1(c, :battle, 0, 0); dump_as("TP1_battle")
tp1(c, :map, 1, 0); dump_as("TP1_map")

#================================================================ TP2: the text report, in game: a session card (LB/RB) and the full table
def tp2(c, kind, sel)
  tp_frame(c, nil, nil)
  b = BASE.bitmap; t = TOP.bitmap
  h = HEAD[kind]
  UI.rbox(b, 6, 36, W - 6, 74, 6, c[:panel2], c[:line])
  kind_box(t, 16, 41, kind)
  P.text(t, 36, 38, 260, 22, h[0], c[:white], PF::ROW)
  P.small(t, 300, 47, 196, 16, "#{h[1]}, #{h[2]}", c[:dim], 2)
  UI.rbox(b, 6, 80, W - 6, 312, 6, c[:panel])
  cols = [["SECTION", 14, 0], ["CALLS", 214, 1], ["TOTAL", 268, 1], ["AVG", 316, 1], ["PEAK", 364, 1], [">16", 404, 1], [">33", 440, 1], [">50", 476, 1]]
  cols.each { |l, x, al| P.text(t, al == 1 ? x - 40 : x, 84, 40 + (al == 1 ? 0 : 160), 13, l, c[:dim], PF::TINY, al == 1 ? 2 : 0) }
  b.fill_rect(12, 99, W - 24, 1, c[:line])
  rows_for(kind).each_with_index do |(n, _, calls, avg, pk, slow), i|
    y = 104 + i * 25
    UI.rbox(b, 9, y - 1, W - 9, y + 22, 4, c[:sel], c[:selb]) if i == sel
    over16 = pk > 16.7 ? [calls, (pk > 33.3 ? 1 : 0) + 1].min : 0
    owner_dot(t, 14, y + 8, rows_for(kind)[i][1])
    P.small(t, 24, y + 3, 160, 16, n, c[:opt])
    [[calls.to_s, 214], [fmt(avg * calls), 268], [fmt(avg), 316], [fmt(pk), 364], [over16.to_s, 404], [slow.to_s, 440], [(pk > 50 ? 1 : 0).to_s, 476]].each_with_index do |(v, x), k|
      colr = k == 3 ? peak_col(c, pk) : ((k >= 4 && v != "0") ? AMB : c[:txt])
      P.small(t, x - 44, y + 3, 44, 16, v, colr, 2)
    end
  end
  P.small(t, 6, 316, W - 12, 16, "Nested sections overlap: don't add them together.", c[:dim], 2)
  hints(c, [["p:9", ""], ["p:10", "Sessions"], [:ud, "Select"], [Y_BTN, "Sort"], [B_BTN, "Back"]])
end
tp2(c, :battle, 0); dump_as("TP2_battle")
tp2(c, :map, 0); dump_as("TP2_map")

#================================================================ TP3: bars; each section's peak against the 16.7 and 33.3 ms lines
def tp3(c, kind, sel_session, sel)
  tp_frame(c); sessions_side(c, sel_session); boxes(c)
  b = BASE.bitmap; t = TOP.bitmap
  P.heading(t, 190, W - 16, 43, HEAD[kind][0], c[:head], c[:line])
  x0 = 194; x1 = 494; scale = 60.0
  [16.7, 33.3].each do |ms|
    lx = x0 + ((x1 - x0) * ms / scale).to_i
    (58..252).step(4) { |yy| b.fill_rect(lx, yy, 1, 2, c[:line]) }
    P.text(t, lx - 20, 252, 40, 10, "#{ms}", c[:dim], PF::TINY, 2) if false
  end
  rows_for(kind).each_with_index do |(n, _, _, _, pk, _), i|
    y = 58 + i * 25
    cursor_at(184, y - 1, W - 194, 25) if i == sel
    owner_dot(t, x0, y + 4, rows_for(kind)[i][1])
    P.small(t, x0 + 10, y, 220, 14, n, c[:opt])
    P.small(t, x1 - 70, y, 70, 14, "#{fmt(pk)} ms", peak_col(c, pk), 2)
    w = [((x1 - x0) * [pk, scale].min / scale).to_i, 2].max
    UI.rbox(b, x0, y + 16, x0 + w, y + 21, 2, peak_col(c, pk))
  end
  d = DESC[kind]; desc_box(c, d[0], d[1], d[2])
  hints(c, [[:ud, "Select"], [Y_BTN, "Sort: Peak"], [B_BTN, "Sessions"]])
end
tp3(c, :battle, 0, 0); dump_as("TP3_battle")
tp3(c, :map, 1, 0); dump_as("TP3_map")

#================================================================ TP4: a frame-time graph of the session; pick a spike to see what ran in that frame
def graph(c, kind, spike)
  b = BASE.bitmap; t = TOP.bitmap
  gx0 = 14; gx1 = W - 14; gy0 = 64; gy1 = 168; scale = 50.0
  UI.rbox(b, 6, 36, W - 6, 176, 6, c[:panel])
  h = HEAD[kind]
  kind_box(t, 14, 41, kind); P.text(t, 34, 38, 300, 22, h[0], c[:white], PF::TEXT)
  P.small(t, W - 220, 42, 206, 16, "#{h[1]}, #{h[2]}", c[:dim], 2)
  [16.7, 33.3].each do |ms|
    ly = gy1 - ((gy1 - gy0) * ms / scale).to_i
    (gx0..gx1).step(4) { |xx| b.fill_rect(xx, ly, 2, 1, ms > 20 ? Color.new(120, 60, 60) : Color.new(110, 96, 50)) }
    P.text(t, gx0, ly - 12, 60, 12, "#{ms} ms", c[:dim], PF::TINY)
  end
  srand(kind == :battle ? 7 : 11)
  spikes = kind == :battle ? { 120 => 38.6, 300 => 21.5, 401 => 18.4 } : { 60 => 88.5, 200 => 54.0, 330 => 22.7 }
  (gx0..gx1).each_with_index do |xx, i|
    v = spikes[i] || (kind == :battle ? 1.0 + rand * 3.5 : 2.0 + rand * 6)
    hgt = [((gy1 - gy0) * [v, scale].min / scale).to_i, 1].max
    b.fill_rect(xx, gy1 - hgt, 1, hgt, peak_col(c, v))
  end
  sx = gx0 + spikes.keys[spike]
  b.fill_rect(sx, gy0 - 2, 1, gy1 - gy0 + 2, c[:white])
  return spikes.values[spike]
end
def tp4(c, kind, spike, parts)
  tp_frame(c, nil, nil)
  b = BASE.bitmap; t = TOP.bitmap
  v = graph(c, kind, spike)
  UI.rbox(b, 6, 182, W - 6, 312, 6, c[:panel2], c[:line])
  P.text(t, 14, 184, 300, 24, "Frame at #{kind == :battle ? '3.2 s' : '0.04 s'}: #{fmt(v)} ms", peak_col(c, v), PF::ROW)
  parts.each_with_index do |(n, ms, owner), i|
    y = 212 + i * 22
    P.text(t, 24, y, 220, 20, n, c[:opt], PF::TEXT)
    P.small(t, 260, y + 2, 140, 16, owner, c[:dim])
    P.text(t, 400, y, 90, 20, "#{fmt(ms)} ms", c[:txt], PF::TEXT, 1)
  end
  hints(c, [[:lr, "Spikes"], ["p:9", ""], ["p:10", "Sessions"], [A_BTN, "Sections"], [B_BTN, "Back"]])
end
tp4(c, :battle, 0, [["Target Icon Prewarm", 35.9, "Kanto Reloaded"], ["Scene Frame Work", 2.1, "EBDX"], ["Native Frame Work", 0.6, "PIF"]])
dump_as("TP4_battle")
tp4(c, :map, 0, [["Map Data Load", 61.0, "PIF"], ["Fusion Sprite Load", 17.3, "PIF"], ["Cody's Map Cache", 4.8, "KIF Beta"], ["Overworld Pokémon", 4.0, "Kanto Reloaded"]])
dump_as("TP4_map")

#================================================================ TP5: a verdict first, then the three slowest; A opens the full list
def tp5(c, kind, sel_session)
  tp_frame(c); sessions_side(c, sel_session); boxes(c)
  b = BASE.bitmap; t = TOP.bitmap
  rows = rows_for(kind).sort_by { |r| -r[4] }
  slow = rows.sum { |r| r[5] }
  verdict, vc = slow == 0 ? ["Smooth", GREEN] : (slow <= 1 ? ["One Hitch", AMB] : ["#{slow} Hitches", RED2])
  UI.rbox(b, 186, 42, W - 12, 88, 6, Reloaded::Palette.mix(c[:panel], vc, 0.18), vc)
  P.text(t, 196, 42, 200, 26, verdict, vc, PF::ROW)
  P.small(t, 196, 66, 300, 16, kind == :battle ? "1 frame in 1691 took over 33 ms." : "3 frames took over 33 ms.", c[:txt])
  P.text(t, 188, 91, 200, 13, "SLOWEST", c[:dim], PF::TINY)
  rows.first(3).each_with_index do |(n, owner, _, _, pk, _), i|
    y = 106 + i * 50
    UI.rbox(b, 186, y, W - 12, y + 44, 6, c[:dark], i == 0 ? c[:selb] : c[:line])
    cursor_at(184, y - 2, W - 194, 48) if i == 0
    P.text(t, 196, y + 2, 220, 22, PF.fit(PF::TEXT, n, 220), c[:opt], PF::TEXT)
    P.small(t, 196, y + 24, 200, 16, owner, c[:dim])
    P.text(t, 400, y + 8, 90, 26, "#{fmt(pk)} ms", peak_col(c, pk), PF::ROW, 1)
  end
  d = DESC[kind]; desc_box(c, d[0], d[1], d[2])
  hints(c, [[:ud, "Select"], [A_BTN, "All Sections"], [B_BTN, "Sessions"]])
end
tp5(c, :battle, 0); dump_as("TP5_battle")
tp5(c, :map, 1); dump_as("TP5_map")
