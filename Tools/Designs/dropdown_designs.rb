# encoding: utf-8
# Mockups: Option Dropdowns (build first after the Roadmap), five designs in
# the improved KIF Settings layout. Every cycling option opens a dropdown of
# its choices with A (or a mouse click on its value); left/right still cycle;
# options with their own popup (Theme, Global Frame, colours) keep it.
# Each design shows two states: a short list (Text Speed) and a long one
# that scrolls (Autosave Interval).
# Design 1 = the dropdown from the Difficulty mix (topic 20), which he liked.
# Usage (from this folder): ruby dropdown_designs.rb "<KIF Beta>" <work dir with metrics.json>
SRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "qa_designs.rb"), :encoding => "UTF-8")
eval(SRC.split("c = palette(2)\n")[0], binding, "qa_designs.rb")

X_BTN = "p:2"; Y_BTN = "p:3"
OVER = layer(3); DIMMER = layer(2); DIMMER.z = 3; OVER.z = 4
def clear_over; OVER.bitmap.clear; DIMMER.bitmap.clear; end
ROWS_G = [["Text Speed", "Fast"], ["Speech Frame", "Theme"], ["Autosave Interval", "10 Minutes"], ["Battle Style", "Shift"], ["Battle Effects", "On"], ["Run Tags", "Show"]]
TEXT_SPEED = [["Slow", "One letter at a time, slowly."], ["Normal", "The standard speed."], ["Fast", "Quicker letters; the default."], ["Instant", "Each box appears all at once."]]
AUTOSAVE = ["Off", "1 Minute", "5 Minutes", "10 Minutes", "15 Minutes", "20 Minutes", "30 Minutes", "60 Minutes"]
def page(c, sel_row)
  frame(c); clear_over
  settings_frame(c, SECTIONS, 5)
  b = BASE.bitmap; t = TOP.bitmap
  P.heading(t, 190, W - 16, 43, "Game", c[:head], c[:line])
  ROWS_G.each_with_index do |(l, v), i|
    y = 58 + i * 24
    cursor_at(184, y, W - 194, 24) if i == sel_row
    P.text(t, 196, y, 180, 24, l, c[:opt], PF::ROW)
    value_cell(t, c, W - 76, y, v, i == sel_row)
  end
  b.fill_rect(W - 11, 44, 2, 212, c[:line]); b.fill_rect(W - 11, 44, 2, 90, c[:dim])
end
def desc(c, title, text)
  t = TOP.bitmap
  P.text(t, 14, 269, 330, 26, title, c[:head], PF::ROW)
  P.small(t, 14, 297, W - 30, 17, text, c[:txt])
end
def scrollbar(b, x, y, h, frac_top, frac_len, c)
  b.fill_rect(x, y, 3, h, c[:line]); b.fill_rect(x, y + (h * frac_top).round, 3, (h * frac_len).round, c[:selb])
end
H_DD = [[:ud, "Choose"], [A_BTN, "Pick"], [B_BTN, "Close"]]
def shot(name); dump_as(name); end

c = palette(2)

#================================================================ DD1 Recommended: anchored under the value (as in the Difficulty mix)
page(c, 0)
d = DIMMER.bitmap; o = OVER.bitmap
x0 = W - 160; y0 = 82
UI.rbox(d, x0, y0, W - 14, y0 + 8 + TEXT_SPEED.length * 24, 6, col(c[:panel2], 255), c[:selb])
TEXT_SPEED.each_with_index do |(n, _), i|
  y = y0 + 4 + i * 24
  UI.rbox(d, x0 + 4, y, W - 18, y + 22, 4, c[:sel]) if i == 1
  P.text(o, x0 + 14, y, 100, 22, n, c[:txt], PF::TEXT)
  P.pill(o, W - 22, y + 4, "NOW", Color.new(40, 70, 110), c[:selb], true) if n == "Fast"
end
desc(c, "Normal", TEXT_SPEED[1][1])
hints(c, H_DD)
shot("DD1_short")
page(c, 2)
d = DIMMER.bitmap; o = OVER.bitmap
x0 = W - 170; y0 = 130
vis = 5; first = 1
UI.rbox(d, x0, y0, W - 14, y0 + 8 + vis * 24, 6, col(c[:panel2], 255), c[:selb])
AUTOSAVE[first, vis].each_with_index do |n, k|
  i = first + k; y = y0 + 4 + k * 24
  UI.rbox(d, x0 + 4, y, W - 24, y + 22, 4, c[:sel]) if n == "15 Minutes"
  P.text(o, x0 + 14, y, 110, 22, n, c[:txt], PF::TEXT)
  P.pill(o, W - 28, y + 4, "NOW", Color.new(40, 70, 110), c[:selb], true) if n == "10 Minutes"
end
UI.tri(o, x0 + 72, y0 - 9, :u, c[:selb], 4); UI.tri(o, x0 + 72, y0 + 10 + vis * 24, :d, c[:selb], 4)
scrollbar(d, W - 20, y0 + 6, vis * 24 - 4, 1 / 8.0, vis / 8.0, c)
desc(c, "15 Minutes", "Saves automatically every 15 minutes of play.")
hints(c, H_DD)
shot("DD1_long")

#================================================================ DD2 Centred Popup: a titled list in the middle, each choice explained below
[[:short, 0], [:long, 2]].each do |kind, row|
  page(c, row)
  d = DIMMER.bitmap; o = OVER.bitmap
  d.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 120))
  list = kind == :short ? TEXT_SPEED.map(&:first) : AUTOSAVE
  vis = [list.length, 6].min
  px = 156; pw = 200; py = 60
  UI.rbox(d, px, py, px + pw, py + 34 + vis * 24, 8, col(c[:panel], 255), c[:selb])
  P.text(o, px, py + 5, pw, 22, kind == :short ? "Text Speed" : "Autosave Interval", c[:title], PF::ROW, 2)
  d.fill_rect(px + 10, py + 28, pw - 20, 1, c[:line])
  first = kind == :short ? 0 : 1
  list[first, vis].each_with_index do |n, k|
    y = py + 32 + k * 24
    sel = kind == :short ? n == "Normal" : n == "15 Minutes"
    now = kind == :short ? n == "Fast" : n == "10 Minutes"
    UI.rbox(d, px + 6, y, px + pw - 10, y + 22, 4, c[:sel]) if sel
    UI.rbox(d, px + 14, y + 8, px + 20, y + 14, 3, c[:selb]) if now
    P.text(o, px + 28, y, 150, 22, n, c[:txt], PF::TEXT)
  end
  scrollbar(d, px + pw - 7, py + 34, vis * 24 - 4, 1 / 8.0, vis / 8.0, c) if kind == :long
  UI.rbox(d, 6, 268, W - 6, H - 30, 6, col(c[:panel2], 255), c[:line])
  P.text(o, 14, 269, 330, 26, kind == :short ? "Normal" : "15 Minutes", c[:head], PF::ROW)
  P.small(o, 14, 297, W - 30, 17, kind == :short ? TEXT_SPEED[1][1] : "Saves automatically every 15 minutes of play.", c[:txt])
  hints(c, H_DD)
  shot("DD2_#{kind}")
end

#================================================================ DD3 Inline Chips: the row opens in place as a row of choice chips
page(c, 0)
b = BASE.bitmap; t = TOP.bitmap
d = DIMMER.bitmap; o = OVER.bitmap
UI.rbox(d, 182, 82, W - 10, 112, 6, col(c[:panel2], 255), c[:selb])
x = 192
TEXT_SPEED.each do |n, _|
  w = P.width(PF::TEXT, n) + 20
  UI.rbox(d, x, 86, x + w, 108, 6, n == "Normal" ? c[:sel] : c[:dark], n == "Normal" ? c[:selb] : (n == "Fast" ? c[:acc] : c[:line]))
  P.text(o, x, 87, w, 20, n, c[:txt], PF::TEXT, 2)
  x += w + 6
end
desc(c, "Normal", TEXT_SPEED[1][1] + " (Fast is set now.)")
hints(c, [[:lr, "Choose"], [A_BTN, "Pick"], [B_BTN, "Close"]])
shot("DD3_short")
page(c, 2)
d = DIMMER.bitmap; o = OVER.bitmap
UI.rbox(d, 182, 130, W - 10, 186, 6, col(c[:panel2], 255), c[:selb])
AUTOSAVE.each_with_index do |n, i|
  x = 190 + (i % 4) * 78; y = 134 + (i / 4) * 26
  UI.rbox(d, x, y, x + 74, y + 22, 6, n == "15 Minutes" ? c[:sel] : c[:dark], n == "15 Minutes" ? c[:selb] : (n == "10 Minutes" ? c[:acc] : c[:line]))
  P.small(o, x, y + 3, 74, 16, n, c[:txt], 2)
end
desc(c, "15 Minutes", "Saves every 15 minutes of play. 10 Minutes is set now.")
hints(c, [[:lr, "Choose"], [:ud, "Row"], [A_BTN, "Pick"], [B_BTN, "Close"]])
shot("DD3_long")

#================================================================ DD4 Side Panel: a panel slides over the list with every choice and its description
[[:short, 0], [:long, 2]].each do |kind, row|
  page(c, row)
  d = DIMMER.bitmap; o = OVER.bitmap
  UI.rbox(d, 250, 36, W - 6, 262, 6, col(c[:panel], 255), c[:selb])
  P.text(o, 262, 40, 240, 22, kind == :short ? "Text Speed" : "Autosave Interval", c[:title], PF::ROW)
  d.fill_rect(258, 64, W - 270, 1, c[:line])
  if kind == :short
    TEXT_SPEED.each_with_index do |(n, ds), i|
      y = 70 + i * 46
      UI.rbox(d, 256, y, W - 12, y + 42, 5, c[:sel]) if n == "Normal"
      P.text(o, 266, y + 2, 140, 20, n, c[:txt], PF::TEXT)
      P.pill(o, W - 18, y + 4, "NOW", Color.new(40, 70, 110), c[:selb], true) if n == "Fast"
      P.small(o, 266, y + 22, W - 290, 16, ds, c[:dim])
    end
  else
    AUTOSAVE[1, 7].each_with_index do |n, k|
      y = 70 + k * 26
      UI.rbox(d, 256, y, W - 16, y + 24, 5, c[:sel]) if n == "15 Minutes"
      P.text(o, 266, y + 1, 150, 22, n, c[:txt], PF::TEXT)
      P.pill(o, W - 22, y + 5, "NOW", Color.new(40, 70, 110), c[:selb], true) if n == "10 Minutes"
    end
    scrollbar(d, W - 12, 70, 180, 1 / 8.0, 7 / 8.0, c)
  end
  desc(c, kind == :short ? "Text Speed" : "Autosave Interval", kind == :short ? "How fast text appears in message boxes." : "How often the game saves by itself.")
  hints(c, H_DD)
  shot("DD4_#{kind}")
end

#================================================================ DD5 Wheel: a picker that turns on the row, the neighbours faded above and below
[[:short, 0], [:long, 2]].each do |kind, row|
  page(c, row)
  d = DIMMER.bitmap; o = OVER.bitmap
  list = kind == :short ? TEXT_SPEED.map(&:first) : AUTOSAVE
  idx = kind == :short ? 1 : 4
  ry = 58 + row * 24
  top = [ry - 50, 38].max
  UI.rbox(d, W - 170, top, W - 14, top + 124, 8, col(c[:panel2], 255), c[:selb])
  UI.rbox(d, W - 166, ry, W - 18, ry + 24, 5, c[:sel])
  (-2..3).each do |k|
    i = idx + k
    next if i < 0 || i >= list.length
    y = ry + k * 24
    next if y < top + 2 || y + 22 > top + 124
    alpha = [255, 170, 90][k.abs]
    P.text(o, W - 166, y, 148, 24, list[i], Color.new(c[:txt].red, c[:txt].green, c[:txt].blue, alpha), PF::TEXT, 2)
  end
  UI.tri(o, W - 98, top + 2, :u, c[:selb], 4); UI.tri(o, W - 98, top + 114, :d, c[:selb], 4)
  desc(c, list[idx], kind == :short ? TEXT_SPEED[1][1] : "Saves automatically every 15 minutes of play.")
  hints(c, [[:ud, "Turn"], [A_BTN, "Pick"], [B_BTN, "Close"]])
  shot("DD5_#{kind}")
end
