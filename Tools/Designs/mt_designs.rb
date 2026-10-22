# encoding: utf-8
# Mockups: Timing Profiler (topic 33), screen 2: Mod Timings (new). How long
# each mod takes: startup (scripts and Data Patches) and its hooks while
# playing (per frame on the map and in battle, the slowest hook). Hooks are
# timed per mod when they go through Hooks.wrap.
# Each design is a pair: Kanto Reloaded (left), then Hard Trainers+ with a
# slow hook (right). Design 1 = the Settings layout, like the Report Viewer.
# Usage (from this folder): ruby mt_designs.rb "<KIF Beta>" <work dir with metrics.json>
TSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "tp_designs.rb"), :encoding => "UTF-8")
eval(TSRC.split("c = palette(2)\n")[0], binding, "tp_designs.rb")

# name, colour, status, startup ms, Data Patches ms, per frame map ms, per frame battle ms, peak ms, slowest hook, hooks
TMODS = [["Kanto Reloaded", [214, 52, 60], :warn, 412, 288, 0.31, 1.4, 38.6, "Target Icon Prewarm", 214],
         ["EBDX", [230, 150, 60], :ok, 640, 0, 0.0, 0.9, 18.4, "Scene Frame Work", 96],
         ["Multiplayer", [96, 160, 232], :ok, 120, 0, 0.12, 0.05, 6.2, "Player Sync", 41],
         ["Gen 9 Movepools", [90, 170, 100], :ok, 96, 92, 0.0, 0.0, 0.0, "", 0],
         ["Hard Trainers+", [180, 70, 70], :err, 31, 24, 0.0, 0.2, 64.0, "Trainer Team Build", 6]]
HOOKS = { 0 => [["Target Icon Prewarm", "Battle", 38.6], ["Battle Menu Draw", "Battle", 21.5], ["Overworld Pokémon", "Map", 4.0]],
          4 => [["Trainer Team Build", "Battle", 64.0], ["Trainer Dialogue", "Map", 1.1], ["Rematch Check", "Map", 0.4]] }
def mt_frame(c, left = "Sessions", right = "Settings")
  page_frame(c, "Mod Timings")
  b = BASE.bitmap; t = TOP.bitmap
  [[8, left], [W - 120, right]].each do |x, l|
    next unless l
    UI.rbox(b, x, 4, x + 112, 27, 5, c[:dark], c[:line]); P.text(t, x, 4, 112, 23, l, c[:dim], PF::TEXT, 2)
  end
end
def mods_side(c, sel)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 6, 36, 174, 262, 6, c[:panel])
  TMODS.each_with_index do |m, i|
    y = 40 + i * 22
    UI.rbox(t, 14, y + 3, 28, y + 17, 3, Color.new(*m[1])); P.glyph(t, 14, y + 3, 15, 15, m[0][0], Color.new(248, 248, 248))
    P.text(t, 33, y + 2, 128, 18, m[0], i == sel ? c[:white] : c[:dim])
  end
end
def ms(v); v == 0 ? "None" : (v >= 10 && v == v.round ? "#{v.round} ms" : v >= 100 ? "#{v.round} ms" : "#{fmt(v)} ms"); end
D_KR = ["Startup", "Kanto Reloaded takes 412 ms to start, 288 ms of it applying its Data Patches (the Expanded Dex).", ["KANTO RELOADED"]]
D_HT = ["Trainer Team Build", "Hard Trainers+ builds each trainer's team as the battle starts: 64.0 ms at worst (Brock), so the battle opens with a hitch.", ["HARD TRAINERS+", "1 SLOW"]]

c = palette(2)

#================================================================ MT1 Recommended: the Settings layout; mods as sections, its numbers then its slowest hooks
def mt1(c, mi, sel)
  mt_frame(c); mods_side(c, mi); boxes(c)
  t = TOP.bitmap
  m = TMODS[mi]
  P.heading(t, 190, W - 16, 43, m[0], c[:head], c[:line])
  rows = [["Startup", ms(m[3])], ["Data Patches", ms(m[4])], ["Per Frame, Map", ms(m[5])], ["Per Frame, Battle", ms(m[6])]]
  rows.each_with_index do |(l, v), i|
    y = 56 + i * 24
    cursor_at(184, y, W - 194, 23) if i == sel
    P.text(t, 196, y, 200, 23, l, c[:opt], PF::TEXT)
    P.text(t, 380, y, 112, 23, v, v == "None" ? c[:dim] : c[:txt], PF::TEXT, 1)
  end
  P.heading(t, 190, 380, 156, "Slowest Hooks", c[:head], c[:line])
  P.text(t, 404, 154, 46, 13, "PEAK", c[:dim], PF::TINY, 1)
  HOOKS[mi].each_with_index do |(n, where, pk), i|
    y = 170 + i * 24
    cursor_at(184, y, W - 194, 23) if sel == 4 + i
    P.text(t, 196, y, 170, 23, n, c[:opt], PF::TEXT)
    P.text(t, 392, y, 100, 23, "#{fmt(pk)} ms", peak_col(c, pk), PF::TEXT, 1)
  end
  hints(c, [[:ud, "Select"], [A_BTN, "Open in Sessions"], [B_BTN, "Mods"]])
end
mt1(c, 0, 0); desc_box(c, *D_KR); dump_as("MT1_kr")
mt1(c, 4, 4); desc_box(c, *D_HT); dump_as("MT1_ht")

#================================================================ MT2: one table of every mod, sorted by cost per battle frame
def mt2(c, sel)
  mt_frame(c, nil, nil)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 6, 36, W - 6, 262, 6, c[:panel])
  cols = [["MOD", 16, 0], ["STARTUP", 250, 1], ["MAP", 320, 1], ["BATTLE", 392, 1], ["PEAK", 464, 1], ["HOOKS", 500, 1]]
  cols.each { |l, x, al| al == 1 ? P.text(t, x - 60, 41, 60, 13, l, c[:dim], PF::TINY, 2) : P.text(t, x, 41, 90, 13, l, c[:dim], PF::TINY) }
  b.fill_rect(12, 56, W - 24, 1, c[:line])
  TMODS.sort_by { |m| -m[7] }.each_with_index do |m, i|
    y = 62 + i * 26
    cursor_at(10, y, W - 20, 25) if i == sel
    UI.rbox(t, 16, y + 5, 28, y + 17, 3, Color.new(*m[1]))
    P.text(t, 34, y + 1, 150, 22, m[0], c[:opt], PF::TEXT)
    [[ms(m[3]), 250], [ms(m[5]), 320], [ms(m[6]), 392]].each { |v, x| P.small(t, x - 66, y + 4, 66, 16, v, v == "None" ? c[:dim] : c[:txt], 2) }
    P.small(t, 464 - 66, y + 4, 66, 16, ms(m[7]), m[7] == 0 ? c[:dim] : peak_col(c, m[7]), 2)
    P.small(t, 500 - 30, y + 4, 30, 16, m[9].to_s, c[:dim], 2)
  end
end
mt2(c, 1); desc_box(c, "Kanto Reloaded", "Slowest hook: Target Icon Prewarm, 38.6 ms in battle. 214 hooks; 288 ms of its startup is Data Patches.", ["1 SLOW"])
hints(c, [[:ud, "Select"], [Y_BTN, "Sort: Peak"], [A_BTN, "Open"], [B_BTN, "Back"]]); dump_as("MT2_kr")
mt2(c, 0); desc_box(c, *D_HT)
hints(c, [[:ud, "Select"], [Y_BTN, "Sort: Peak"], [A_BTN, "Open"], [B_BTN, "Back"]]); dump_as("MT2_ht")

#================================================================ MT3: where the time goes; stacked bars for startup and a battle frame
def stack(c, x0, x1, y, parts, label, total)
  b = BASE.bitmap; t = TOP.bitmap
  P.text(t, x0, y, 300, 20, label, c[:head], PF::TEXT)
  P.small(t, x1 - 120, y + 2, 120, 16, total, c[:dim], 2)
  sum = parts.sum { |_, v, _| v }.to_f
  x = x0
  parts.each_with_index do |(n, v, rgb), i|
    w = ((x1 - x0) * v / sum).round
    w = x1 - x if i == parts.length - 1
    UI.rbox(b, x, y + 22, x + w - 2, y + 40, 3, Color.new(*rgb)) if w > 2
    x += w
  end
end
def mt3(c, sel_mod)
  mt_frame(c, nil, nil)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 6, 36, W - 6, 262, 6, c[:panel])
  st = TMODS.map { |m| [m[0], m[3], m[1]] } + [["PIF and KIF", 1900, [130, 140, 155]]]
  bt = TMODS.map { |m| [m[0], m[6], m[1]] }.reject { |_, v, _| v == 0 } + [["PIF and KIF", 2.6, [130, 140, 155]]]
  stack(c, 16, W - 16, 42, st, "Startup", "3.2 s in all")
  stack(c, 16, W - 16, 92, bt, "A Battle Frame", "5.2 ms on average")
  b.fill_rect(16, 142, W - 32, 1, c[:line])
  (TMODS + [["PIF and KIF", [130, 140, 155], :ok, 1900, 0, 0, 2.6, 0, "", 0]]).each_with_index do |m, i|
    x = 16 + (i % 2) * 244; y = 150 + (i / 2) * 26
    cursor_at(x - 4, y - 1, 240, 24) if i == sel_mod
    UI.rbox(t, x, y + 5, x + 12, y + 17, 3, Color.new(*m[1]))
    P.text(t, x + 18, y, 150, 22, PF.fit(PF::TEXT, m[0], 140), c[:opt], PF::TEXT)
    P.small(t, x + 150, y + 3, 80, 16, m[6] == 0 ? "None" : "#{fmt(m[6])} ms", c[:dim], 2)
  end
end
mt3(c, 0); desc_box(c, "Kanto Reloaded", "13% of startup, 1.4 ms of each battle frame (27%). Slowest hook: Target Icon Prewarm, 38.6 ms.", ["1 SLOW"])
hints(c, [[:ud, ""], [:lr, "Select"], [A_BTN, "Open"], [B_BTN, "Back"]]); dump_as("MT3_kr")
mt3(c, 4); desc_box(c, *D_HT)
hints(c, [[:ud, ""], [:lr, "Select"], [A_BTN, "Open"], [B_BTN, "Back"]]); dump_as("MT3_ht")

#================================================================ MT4: a card per mod with three meters and a weight (Light, Medium, Heavy)
def meter(b, t, c, x, y, w, label, frac, col, value)
  P.small(t, x, y, 70, 14, label, c[:dim])
  UI.rbox(t, x + 64, y + 4, x + w, y + 10, 3, c[:dark])
  UI.rbox(t, x + 64, y + 4, x + 64 + [((w - 64) * [frac, 1].min).to_i, 3].max, y + 10, 3, col) if frac > 0
end
def mt4(c, sel)
  mt_frame(c, nil, nil)
  b = BASE.bitmap; t = TOP.bitmap
  TMODS.first(4).each_with_index do |m, i|
    mi = i
    mi = 4 if i == 3
    m = TMODS[mi]
    x = 6 + (i % 2) * 254; y = 36 + (i / 2) * 114
    on = mi == sel
    UI.rbox(b, x, y, x + 246, y + 108, 6, c[:panel], on ? c[:selb] : c[:line])
    cursor_at(x - 2, y - 2, 250, 112) if on
    UI.rbox(t, x + 8, y + 8, x + 22, y + 22, 3, Color.new(*m[1])); P.glyph(t, x + 8, y + 8, 15, 15, m[0][0], Color.new(248, 248, 248))
    P.text(t, x + 28, y + 4, 140, 22, m[0], c[:white], PF::TEXT)
    wgt, wc = m[7] > 33.3 ? ["HEAVY", RED2] : (m[7] > 16.7 ? ["MEDIUM", AMB] : ["LIGHT", GREEN])
    P.pill(t, x + 238, y + 9, wgt, Color.new(30, 34, 44), wc)
    meter(b, t, c, x + 10, y + 34, 226, "Startup", m[3] / 700.0, Color.new(*m[1]), m[3])
    meter(b, t, c, x + 10, y + 56, 226, "Battle", m[6] / 2.0, Color.new(*m[1]), m[6])
    meter(b, t, c, x + 10, y + 78, 226, "Peak", [m[7] / 60.0, 1].min, peak_col(c, m[7]), m[7])
  end
end
mt4(c, 0); desc_box(c, "Kanto Reloaded", "Startup 412 ms, 1.4 ms a battle frame, slowest hook 38.6 ms (Target Icon Prewarm).", ["1 SLOW"])
hints(c, [[:ud, ""], [:lr, "Select"], [A_BTN, "Open"], [B_BTN, "Back"]]); dump_as("MT4_kr")
mt4(c, 4); desc_box(c, *D_HT)
hints(c, [[:ud, ""], [:lr, "Select"], [A_BTN, "Open"], [B_BTN, "Back"]]); dump_as("MT4_ht")

#================================================================ MT5: by game method; who hooks it, in call order, and how long each takes
CHAINS = [["Battle Start", [["Hard Trainers+", [180, 70, 70], 64.0], ["Kanto Reloaded", [214, 52, 60], 38.6], ["EBDX", [230, 150, 60], 12.0]]],
          ["Map Update", [["Kanto Reloaded", [214, 52, 60], 0.31], ["Multiplayer", [96, 160, 232], 0.12]]],
          ["Battle Menu", [["Kanto Reloaded", [214, 52, 60], 21.5], ["EBDX", [230, 150, 60], 3.1]]]]
def mt5(c, sel_chain, sel_part)
  mt_frame(c, nil, nil)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 6, 36, W - 6, 262, 6, c[:panel])
  y = 40
  CHAINS.each_with_index do |(meth, parts), ci|
    P.heading(t, 16, W - 16, y + 3, meth, c[:head], c[:line])
    y += 20
    parts.each_with_index do |(n, rgb, pk), k|
      cursor_at(10, y - 1, W - 20, 24) if ci == sel_chain && k == sel_part
      P.small(t, 18, y + 3, 20, 16, "#{k + 1}.", c[:dim])
      UI.rbox(t, 38, y + 5, 50, y + 17, 3, Color.new(*rgb))
      P.text(t, 56, y, 200, 22, n, c[:opt], PF::TEXT)
      P.text(t, 380, y, 112, 22, "#{fmt(pk)} ms", peak_col(c, pk), PF::TEXT, 1)
      y += 22
    end
    y += 2
  end
end
mt5(c, 1, 0); desc_box(c, "Map Update: Kanto Reloaded", "Runs first of 2 mods on every map frame: 0.31 ms on average. Its parts: Overworld Pokémon, Weather, Wild Link HUD.", [])
hints(c, [[:ud, "Select"], [A_BTN, "Open"], [B_BTN, "Back"]]); dump_as("MT5_kr")
mt5(c, 0, 0); desc_box(c, *D_HT)
hints(c, [[:ud, "Select"], [A_BTN, "Open"], [B_BTN, "Back"]]); dump_as("MT5_ht")
