# encoding: utf-8
# Mockups: Speed-Up Settings (topic 32). Old KR's Speed-Up rows (Hold or
# Toggle, Overworld and Battles speeds, Resting Speed, Toggle Limit, Speed
# Indicator) plus the new Toggle Speeds (Separate: the overworld and battles
# each remember their own toggled speed). The buttons are the Controls
# layer's Global actions Speed-Up, Next Speed and Reset Speed.
# Each design is a pair: Hold on the left, Toggle on the right.
# Built on controls.rb beside it (the Controls page mockup).
# Usage (cwd = KIF Beta): ruby spd_designs.rb "<KIF Beta>" <work dir with metrics.json>
CTRL = File.join(File.dirname(File.expand_path(__FILE__)), "controls.rb")
eval(File.read(CTRL, :encoding => "UTF-8").split("#---------------------------------------------------------------- the states")[0], binding, CTRL)

SECTIONS.insert(4, [:speed, "Speed-Up", [230, 180, 60]])
C.bind(:speed_up, :pad, ["a:5+"])            # RT (Pokémon-style layout)
C.bind(:speed_next, :pad, [])
C.bind(:speed_reset, :pad, [])
NAMES = { :speed_up => "Speed-Up", :speed_next => "Next Speed", :speed_reset => "Reset Speed" }
VAL_X = LIST_X1 - 12 - 48
GREEN = Color.new(96, 200, 120)
GOLD = Color.new(240, 200, 80)

def padlock(b, x, y, color)
  b.fill_rect(x + 1, y, 5, 1, color); b.fill_rect(x, y + 1, 1, 3, color); b.fill_rect(x + 6, y + 1, 1, 3, color)
  b.fill_rect(x - 1, y + 4, 9, 6, color)
end
def value_arrows(t, c, cx, y, v, sel, locked = false)
  vw = P.width(PF::TEXT, v)
  P.text(t, cx - vw / 2, y, vw + 2, ROW_H - 2, v, locked ? c[:dim] : c[:opt])
  if locked
    padlock(t, cx + vw / 2 + 6, y + 6, c[:dim])
  else
    arrow = sel ? c[:txt] : c[:dim]
    UI.tri(t, cx - vw / 2 - 14, y + 7, :l, arrow, 4)
    UI.tri(t, cx + vw / 2 + 6, y + 7, :r, arrow, 4)
  end
end
def col_labels(t, c, y)
  P.text(t, KEY_X, y, 90, 13, "KEYBOARD", c[:dim], PF::TINY)
  P.text(t, PAD_X, y, 90, 13, "CONTROLLER", c[:dim], PF::TINY)
end

# items: [:head, label] | [:row, name, value, locked] | [:bind, action] | [:bars, name, value, max, locked]
def spd_list(c, items, sel, x0 = LIST_X0, x1 = LIST_X1, y0 = LIST_Y0, y1 = LIST_Y1)
  base = BASE.bitmap; top = TOP.bitmap
  UI.rbox(base, x0, y0, x1, y1, 6, c[:panel])
  ys = []; y = 0
  items.each { |k, *_| ys << y; y += k == :head ? HEAD_H : ROW_H }
  rows = items.each_index.select { |i| items[i][0] != :head }
  si = rows[sel]
  top_y = y0 + 4
  avail = y1 - 4 - top_y
  scroll = 0
  scroll = ys[si] + ROW_H - avail if si && ys[si] + ROW_H > avail
  items.each_with_index do |it, i|
    kind = it[0]
    yy = top_y + ys[i] - scroll
    next if ys[i] < scroll || ys[i] - scroll + (kind == :head ? HEAD_H + ROW_H : ROW_H) > avail
    if kind == :head
      if it[1] == "Buttons"
        P.heading(top, x0 + 10, KEY_X - 10, yy + 3, it[1], c[:head], c[:line]); col_labels(top, c, yy + 3)
      else
        P.heading(top, x0 + 10, x1 - 10, yy + 3, it[1], c[:head], c[:line])
      end
      next
    end
    cursor_at(x0 + 4, yy, (x1 - 8) - (x0 + 4) + 1, ROW_H - 1) if i == si
    case kind
    when :row
      _, name, v, locked = it
      P.text(top, NAME_X, yy, 200, ROW_H - 2, name, locked ? c[:dim] : c[:opt], PF::ROW)
      value_arrows(top, c, VAL_X, yy, v, i == si, locked)
    when :bars
      _, name, v, max, locked = it
      P.text(top, NAME_X, yy, 140, ROW_H - 2, name, locked ? c[:dim] : c[:opt], PF::ROW)
      bx = 340
      10.times do |k|
        on = k < v; over = k >= max
        fill = over ? c[:dark] : (on ? (locked ? c[:dim] : GOLD) : c[:line])
        UI.rbox(base, bx + k * 12, yy + 7, bx + k * 12 + 9, yy + 17, 2, fill)
      end
      P.text(top, 464, yy, 36, ROW_H - 2, "#{v}x", locked ? c[:dim] : c[:opt], PF::TEXT, 2)
    when :link
      _, name, label = it
      P.text(top, NAME_X, yy, 200, ROW_H - 2, name, c[:opt], PF::ROW)
      P.pill(top, x1 - 14, yy + 5, label, c[:pill], c[:txt])
    when :bind
      a = it[1]
      P.text(top, NAME_X, yy, KEY_X - NAME_X - 6, ROW_H - 2, NAMES[a], c[:opt], PF::ROW)
      chips(top, KEY_X, PAD_X - 10, yy + 3, C.bindings(a, :keys), c, [])
      chips(top, PAD_X, x1 - 12, yy + 3, C.bindings(a, :pad), c, [])
    end
  end
  total = ys.last.to_i + ROW_H
  if total > avail
    track = y1 - y0 - 12
    bar = [track * avail / total, 12].max
    pos = (track - bar) * scroll / [total - avail, 1].max
    base.fill_rect(x1 - 5, y0 + 6, 2, track, c[:line])
    base.fill_rect(x1 - 5, y0 + 6 + pos, 2, bar, c[:dim])
  end
end
def ctl(c)
  frame(c); title_bar(c, PADS[:left], PADS[:right]); sidebar(c, :speed, false)
end
H_SET = [[:ud, "Select"], [:lr, "Change"], ["p:2", "Default"], ["p:1", "Sections"]]
D_TYPE = "Hold the Speed-Up button to go faster, or press it to step through the speeds."
D_SEP = "Separate: the overworld and battles each remember their own speed, and switch to it as a battle starts and ends. Shared: one speed for both."
def full_items(hold)
  [[:head, "Game Speed"],
   [:row, "Speed-Up Type", hold ? "Hold" : "Toggle", false],
   [:row, "Speed-Up (Overworld)", "4x", !hold],
   [:row, "Speed-Up (Battles)", "4x", !hold],
   [:row, "Resting Speed", "1x", !hold],
   [:row, "Toggle Limit", "5x", hold],
   [:row, "Toggle Speeds", "Separate", hold],
   [:row, "Speed Indicator", "On", false],
   [:head, "Buttons"], [:bind, :speed_up], [:bind, :speed_next], [:bind, :speed_reset]]
end

c = palette(2)

#================================================================ SD1 Recommended: old KR's rows as a Speed-Up section; the other type's rows locked
ctl(c); spd_list(c, full_items(true), 0)
description(c, "Speed-Up Type", ["ALL SAVES", "DEFAULT: HOLD"], D_TYPE)
hints(c, H_SET); dump("SD1_hold")
ctl(c); spd_list(c, full_items(false), 5)
description(c, "Toggle Speeds", ["NEW", "DEFAULT: SEPARATE"], D_SEP)
hints(c, H_SET); dump("SD1_toggle")

#================================================================ SD2: only the chosen type's rows
HOLD2 = [[:head, "Game Speed"], [:row, "Speed-Up Type", "Hold", false], [:row, "Speed-Up (Overworld)", "4x", false],
         [:row, "Speed-Up (Battles)", "4x", false], [:row, "Resting Speed", "1x", false], [:row, "Speed Indicator", "On", false],
         [:head, "Buttons"], [:bind, :speed_up]]
TOG2 = [[:head, "Game Speed"], [:row, "Speed-Up Type", "Toggle", false], [:row, "Toggle Limit", "5x", false],
        [:row, "Toggle Speeds", "Separate", false], [:row, "Speed Indicator", "On", false],
        [:head, "Buttons"], [:bind, :speed_up], [:bind, :speed_next], [:bind, :speed_reset]]
ctl(c); spd_list(c, HOLD2, 1)
description(c, "Speed-Up (Overworld)", ["ALL SAVES", "DEFAULT: 4X"], "How fast the game runs while you hold the Speed-Up button, outside battle.")
hints(c, H_SET); dump("SD2_hold")
ctl(c); spd_list(c, TOG2, 2)
description(c, "Toggle Speeds", ["NEW", "DEFAULT: SEPARATE"], D_SEP)
hints(c, H_SET); dump("SD2_toggle")

#================================================================ SD3: speeds as bars (segments up to 10x; past the Toggle Limit greyed)
HOLD3 = [[:head, "Game Speed"], [:row, "Speed-Up Type", "Hold", false], [:bars, "Overworld", 4, 10, false],
         [:bars, "Battles", 4, 10, false], [:bars, "Resting", 1, 10, false], [:row, "Speed Indicator", "On", false],
         [:head, "Buttons"], [:bind, :speed_up]]
TOG3 = [[:head, "Game Speed"], [:row, "Speed-Up Type", "Toggle", false], [:bars, "Toggle Limit", 5, 10, false],
        [:row, "Toggle Speeds", "Separate", false], [:row, "Speed Indicator", "On", false],
        [:head, "Buttons"], [:bind, :speed_up], [:bind, :speed_next], [:bind, :speed_reset]]
ctl(c); spd_list(c, HOLD3, 1)
description(c, "Overworld", ["ALL SAVES", "DEFAULT: 4X"], "How fast the game runs while you hold the Speed-Up button, outside battle.")
hints(c, H_SET); dump("SD3_hold")
ctl(c); spd_list(c, TOG3, 2)
description(c, "Toggle Speeds", ["NEW", "DEFAULT: SEPARATE"], D_SEP)
hints(c, H_SET); dump("SD3_toggle")

#================================================================ SD4: Hold and Toggle as two cards, the one in use lit; shared rows below
def card(c, x0, x1, title, rows, on, sel)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, x0, 40, x1, 168, 6, on ? Reloaded::Palette.mix(c[:panel], c[:sel], 0.35) : c[:panel], on ? GREEN : c[:line])
  P.text(t, x0 + 10, 42, 90, 24, title, on ? c[:white] : c[:dim], PF::ROW)
  P.pill(t, x1 - 8, 48, on ? "IN USE" : "PRESS A", on ? Color.new(20, 70, 36) : c[:pill], on ? GREEN : c[:dim])
  b.fill_rect(x0 + 8, 68, x1 - x0 - 16, 1, c[:line])
  rows.each_with_index do |(l, v), i|
    y = 74 + i * 30
    cursor_at(x0 + 4, y - 2, x1 - x0 - 8, 26) if sel == i
    P.text(t, x0 + 10, y, 90, 22, l, on ? c[:opt] : c[:dim], PF::TEXT)
    P.text(t, x0 + 70, y, x1 - x0 - 80, 22, v, on ? c[:txt] : c[:dim], PF::TEXT, 1)
  end
end
def sd4(c, hold, sel_card, sel_row)
  ctl(c)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(LIST_X0, LIST_Y0, LIST_X1 - LIST_X0, LIST_Y1 - LIST_Y0, c[:bg])
  card(c, LIST_X0, 326, "Hold", [["Overworld", "4x"], ["Battles", "4x"], ["Resting", "1x"]], hold, sel_card == 0 ? sel_row : nil)
  card(c, 332, LIST_X1, "Toggle", [["Limit", "5x"], ["Speeds", "Separate"]], !hold, sel_card == 1 ? sel_row : nil)
  UI.rbox(b, LIST_X0, 174, LIST_X1, LIST_Y1, 6, c[:panel])
  P.text(t, NAME_X, 178, 200, ROW_H - 2, "Speed Indicator", c[:opt], PF::ROW)
  value_arrows(t, c, VAL_X, 178, "On", false)
  b.fill_rect(LIST_X0 + 10, 206, LIST_X1 - LIST_X0 - 20, 1, c[:line])
  x = NAME_X
  (hold ? [:speed_up] : [:speed_up, :speed_next, :speed_reset]).each do |a|
    P.small(t, x, 214, 90, 16, NAMES[a], c[:dim])
    toks = C.bindings(a, :keys) + C.bindings(a, :pad)
    xx = x
    toks.first(2).each { |tk| BI.draw(t, xx, 232, tk, c, $style, 18); xx += BI.width(tk, $style, 18) + 4 }
    P.small(t, xx, 232, 70, 18, "Not Bound", c[:dim]) if toks.empty?
    x += 98
  end
end
sd4(c, true, 0, 0)
description(c, "Overworld (Hold)", ["ALL SAVES", "DEFAULT: 4X"], "How fast the game runs while you hold the Speed-Up button, outside battle. Press A on a card to use that type.")
hints(c, [[:ud, ""], [:lr, "Select"], ["p:0", "Use"], ["p:2", "Default"], ["p:1", "Sections"]]); dump("SD4_hold")
sd4(c, false, 1, 1)
description(c, "Speeds (Toggle)", ["NEW", "DEFAULT: SEPARATE"], D_SEP)
hints(c, [[:ud, ""], [:lr, "Select"], ["p:0", "Use"], ["p:2", "Default"], ["p:1", "Sections"]]); dump("SD4_toggle")

#================================================================ SD5: in Reloaded Settings (Game section), the buttons a link to the Controls page
RS = [[:kr, "Kanto Reloaded", [214, 52, 60]], [:shinies, "Shinies", [230, 180, 60]], [:battles, "Battles", [210, 80, 80]],
      [:pokemon, "Pokémon", [90, 170, 100]], [:graphics, "Graphics", [96, 160, 232]], [:game, "Game", [60, 170, 160]], [:system, "System", [130, 140, 155]]]
def sd5(c, hold, sel)
  saved = SECTIONS.dup; SECTIONS.replace(RS)
  frame(c); title_bar(c, PADS[:left], PADS[:right]); sidebar(c, :game, false)
  SECTIONS.replace(saved)
  t = TOP.bitmap; b = BASE.bitmap
  t.fill_rect(130, 2, 252, 28, Color.new(0, 0, 0, 0)); b.fill_rect(130, 2, 252, 28, c[:panel2])
  P.text(t, 130, 2, 252, 28, "Settings", c[:title], PF::TITLE, 2)
  t.fill_rect(122, 2, 40, 28, Color.new(0, 0, 0, 0)); t.fill_rect(W - 160, 2, 154, 28, Color.new(0, 0, 0, 0))
  UI.rbox(b, W - 120, 4, W - 8, 27, 5, c[:dark], c[:line]); P.text(t, W - 120, 4, 112, 23, "Presets", c[:dim], PF::TEXT, 2)
  items = [[:head, "Speed-Up"],
           [:row, "Speed-Up Type", hold ? "Hold" : "Toggle", false],
           [:row, "Speed-Up (Overworld)", "4x", !hold], [:row, "Speed-Up (Battles)", "4x", !hold], [:row, "Resting Speed", "1x", !hold],
           [:row, "Toggle Limit", "5x", hold], [:row, "Toggle Speeds", "Separate", hold],
           [:row, "Speed Indicator", "On", false], [:link, "Speed-Up Buttons", "CONTROLS"]]
  spd_list(c, items, sel)
end
sd5(c, true, 7)
description(c, "Speed-Up Buttons", [], "Opens the Controls page at Game Speed, where Speed-Up, Next Speed and Reset Speed are set for the keyboard and the controller.")
hints(c, [[:ud, "Select"], ["p:0", "Open"], ["p:1", "Sections"]]); dump("SD5_hold")
sd5(c, false, 5)
description(c, "Toggle Speeds", ["NEW", "DEFAULT: SEPARATE"], D_SEP)
hints(c, H_SET); dump("SD5_toggle")
