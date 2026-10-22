# encoding: utf-8
# Mockups: Weather System, Field Weather Moves (topic 22, part 2). Rain Dance,
# Sunny Day, Hail and Sandstorm used outside battle set your area's weather
# for 3 hours (outdoors only; a map's own guaranteed weather wins). Five
# designs, each two screens; this script draws designs 2 and 5 and the
# shared alert (design 1's chosen Forecast style), designs 1 and 4 need the
# party screen (party_backdrop.py), design 3 the Overworld Menu (fwm_ow.rb).
# Usage (from this folder): ruby fwm_designs.rb "<KIF Beta>" <work dir with metrics.json>
WXSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "wx_designs.rb"), :encoding => "UTF-8")
eval(WXSRC.split("wx1(c, false)\n")[0], binding, "wx_designs.rb")

GOLD2 = Color.new(240, 200, 70)
MOVES = [[:Rain, "Rain Dance", "Pikachu"], [:Storm, "Thunder", "Pikachu"], [:Sun, "Sunny Day", "Charmander"], [:Snow, "Hail", "Lapras"], [:Fog, "Mist", "Lapras"]]
def wicon2(b, w, n, cx, cy, size)
  return wicon(b, w, n, cx, cy, size) unless w == :Sand
  i = bmp(File.join(ICONS, "mapSand.png"))
  b.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), i, Rect.new(0, 0, i.width, i.height))
end
def star_mark(t, x, y)
  ["..#..", ".###.", "#####", ".###.", "#.#.#"].each_with_index { |r, j| r.each_char.with_index { |ch, i| t.fill_rect(x + i, y + j, 1, 1, GOLD2) if ch == "#" } }
end
# The chosen Forecast (design 1) with Route 24's state given
def forecast(c, w, i, rows)
  blank(c)
  b = BASE.bitmap; t = TOP.bitmap
  P.text(t, 0, 6, W, 24, "Weather Forecast", c[:title], PF::ROW, 2)
  season_chip(t, 10, 10)
  tabs(c, b, t, W - 98, 9)
  UI.rbox(b, 8, 36, 336, 354, 8, c[:panel], c[:line])
  at = town_map(b, 10, 38, 324, 314, 452, 0, 1)
  cells = CELLS.map { |x| x[0] == "Route 24" ? [x[0], x[1], x[2], w, i] : x }
  map_icons(t, at, 20, cells, false, [10, 38, 334, 352])
  sel_ring(b, at, 20, c[:selb])
  player_mark(t, at, 16)
  UI.rbox(b, 344, 36, 504, 354, 8, c[:panel], c[:line])
  P.text(t, 344, 42, 160, 24, SELN, c[:title], PF::ROW, 2)
  wicon(t, w, i, 374, 92, 40)
  P.text(t, 400, 74, 100, 24, WNAME[w], WCOL[w], PF::ROW)
  P.small(t, 400, 96, 100, 16, w == :Clear ? "" : level_word(i), c[:dim])
  bar(b, 354, 120, i, WCOL[w], c, 10, 12)
  rows.each_with_index do |(l, v, colr), k|
    y = 136 + k * 22
    P.small(t, 354, y, 70, 16, l, c[:dim]); P.small(t, 424, y, 74, 16, v, colr, 1)
  end
  [b, t, at]
end
def alert(c, title, sub, w = :Rain, n = 5)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 8, 8, 196, 52, 8, c[:panel], c[:line])
  wicon(t, w, n, 30, 30, 32)
  P.text(t, 52, 9, 140, 24, title, c[:txt], PF::TEXT)
  P.small(t, 52, 31, 140, 16, sub, c[:dim])
end

c = palette(2)

#================================================================ The shared result: rain starts, the chosen alert says why
ow(c)
alert(c, "Rain Started", "Rain Dance: 3 Hours")
shot("FWM_alert")

#================================================================ FWM2: from the Forecast (A on your area)
b, t, at = forecast(c, :Clear, 0, [["Climate", "Temperate", c[:txt]], ["Trend", "Steady", c[:txt]],
                                   ["Next", "Clear", WCOL[:Clear]], ["Season", "Autumn", Color.new(250, 170, 90)]])
P.small(t, 344, 310, 160, 16, "Updates in 2h 14m", c[:dim], 2)
hints(c, [[:ud, "Choose"], [A_BTN, "Use"], [B_BTN, "Back"]])
d = DIMMER.bitmap; o = OVER.bitmap
UI.rbox(d, 268, 148, 504, 336, 8, col(c[:panel], 255), c[:selb])
P.text(o, 268, 152, 236, 24, "Change Weather", c[:title], PF::ROW, 2)
d.fill_rect(278, 178, 216, 1, c[:line])
MOVES.each_with_index do |(w, mv, who), k|
  y = 184 + k * 24
  UI.rbox(d, 274, y, 498, y + 23, 5, c[:sel], c[:selb]) if k == 0
  wicon2(o, w, 3, 290, y + 12, 18)
  P.text(o, 306, y, 110, 24, mv, who ? (k == 0 ? c[:white] : c[:txt]) : c[:dim], PF::TEXT)
  P.small(o, 410, y + 4, 82, 16, who || "No One", who ? c[:dim] : col(c[:dim], 160), 1)
end
P.small(o, 268, 308, 236, 16, "Rain for 3 hours here.", c[:dim], 2)
shot("FWM2_pick")
b, t, at = forecast(c, :Rain, 5, [["Climate", "Temperate", c[:txt]], ["From", "Rain Dance", GOLD2],
                                  ["Ends", "In 3h", c[:txt]], ["Season", "Autumn", Color.new(250, 170, 90)]])
encounters(c, t, 354, 230, 140)
b.fill_rect(354, 300, 140, 1, c[:line])
P.small(t, 344, 310, 160, 16, "Updates in 2h 14m", c[:dim], 2)
hints(c, [[:ud, ""], [:lr, "Move"], [A_BTN, "Weather"], [X_BTN, "Next"], [B_BTN, "Back"]])
shot("FWM2_done")

#================================================================ FWM1 Recommended: PIF's own way (Hoenn's weather field moves), now in Kanto
# The party menu lists weather moves as field moves (blue), then PIF's cut-in plays; the alert follows.
frame(c, false); clear_over; backdrop("party_cmd.png")
shot("FWM1_party")
frame(c, false); clear_over; backdrop("cutin.png")
shot("FWM1_cutin")

#================================================================ FWM4: a preview card before it's used
frame(c, false); clear_over; backdrop("party_plain.png")
d = DIMMER.bitmap; o = OVER.bitmap
d.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 120))
UI.rbox(d, 96, 54, 416, 314, 8, col(c[:panel], 255), c[:selb])
P.text(o, 96, 60, 320, 24, "Rain Dance", c[:title], PF::ROW, 2)
P.small(o, 96, 84, 320, 16, "Pikachu", c[:dim], 2)
d.fill_rect(106, 104, 300, 1, c[:line])
wicon(o, :Rain, 5, 136, 136, 40)
P.text(o, 164, 114, 240, 24, "Rain for 3 Hours", WCOL[:Rain], PF::ROW)
P.small(o, 164, 138, 240, 16, "Route 24, until 6:30 PM", c[:dim])
P.heading(o, 110, 402, 168, "While It Lasts", c[:head], c[:line])
P.small(o, 110, 188, 110, 16, "More Common", c[:dim])
type_icon(o, 11, 222, 188, 16); P.small(o, 242, 188, 50, 16, "Water", c[:txt])
type_icon(o, 13, 300, 188, 16); P.small(o, 320, 188, 70, 16, "Electric", c[:txt])
P.small(o, 110, 210, 110, 16, "In Battle", c[:dim])
P.small(o, 222, 210, 184, 16, "Water up, Fire down", c[:txt])
P.small(o, 110, 232, 110, 16, "Replaces", c[:dim])
wicon(o, :Clear, 0, 230, 240, 16); P.small(o, 242, 232, 100, 16, "Clear", c[:txt])
d.fill_rect(106, 256, 300, 1, c[:line])
[["Use", true, 124], ["Cancel", false, 266]].each do |lbl, on, x|
  UI.rbox(d, x, 268, x + 122, 294, 6, on ? c[:sel] : c[:dark], on ? c[:selb] : c[:line])
  P.text(o, x, 270, 122, 22, lbl, on ? c[:white] : c[:txt], PF::TEXT, 2)
end
shot("FWM4_preview")

#================================================================ FWM5: a Field Moves wheel on the overworld (every field move the party can use)
WHEEL = [[:w, :Rain, "Rain Dance", "Pikachu"], [:w, :Storm, "Thunder", "Pikachu"], [:t, 2, "Fly", "Gengar"],
         [:t, 11, "Surf", "Lapras"], [:w, :Snow, "Hail", "Lapras"], [:w, :Fog, "Mist", "Lapras"],
         [:w, :Sun, "Sunny Day", "Charmander"], [:t, 13, "Flash", "Pikachu"]]
ow(c, "route24_clear.png")
b = BASE.bitmap; t = TOP.bitmap
b.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 110))
UI.rbox(b, 176, 8, 336, 34, 8, c[:panel], c[:line])
P.text(t, 176, 9, 160, 24, "Field Moves", c[:title], PF::ROW, 2)
cx = 256; cy = 168; r = 104
WHEEL.each_with_index do |(kind, id, mv, who), k|
  a = -Math::PI / 2 + k * 2 * Math::PI / WHEEL.length
  x = (cx + r * Math.cos(a)).round; y = (cy + r * Math.sin(a)).round
  sel = k == 0
  rr = sel ? 24 : 19
  UI.rbox(b, x - rr, y - rr, x + rr, y + rr, rr, sel ? c[:sel] : c[:panel], sel ? c[:selb] : c[:line])
  kind == :w ? wicon(t, id, 4, x, y, sel ? 34 : 26) : type_icon(t, id, x - 9, y - 9, 18)
end
UI.rbox(b, 140, 296, 372, 350, 8, c[:panel], c[:line])
P.text(t, 140, 300, 232, 24, "Rain Dance", c[:title], PF::ROW, 2)
P.small(t, 140, 324, 232, 16, "Pikachu. Rain for 3 hours.", c[:dim], 2)
hints(c, [[:lr, "Choose"], [A_BTN, "Use"], [B_BTN, "Close"]])
shot("FWM5_wheel")
