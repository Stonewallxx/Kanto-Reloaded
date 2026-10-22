# encoding: utf-8
# Mockups: Weather System (topic 22), five designs, each two screens:
#  - the Weather Forecast on KIF's Town Map (Graphics/Pictures/map/map.png,
#    16 px tiles, places from Data/town_map.dat), old KR's weather icons;
#  - the overworld (Route 24 in PIF's rain) with the Weather Alert.
# New, agreed: Seasons (a season chip; odds shift per season), Weather
# Encounters (matching types more common: shown per area). Field Weather
# Moves and the Fly map's icons come after the Forecast is picked.
# Design 1 = old KR's Forecast (map left, details right, Current/Next) and its
# upper-left alert, rebuilt in our UI kit.
# Usage (from this folder): ruby wx_designs.rb "<KIF Beta>" <work dir with metrics.json>
SRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "qa_designs.rb"), :encoding => "UTF-8")
eval(SRC.split("c = palette(2)\n")[0], binding, "qa_designs.rb")

X_BTN = "p:2"; Y_BTN = "p:3"
WHITE = Color.new(248, 248, 248); CLEAR = Color.new(0, 0, 0, 0)
OVER = layer(3); DIMMER = layer(2)
DIMMER.z = 3; OVER.z = 4
MAPIMG = File.join(GFX, "Pictures/map/map.png")
ICONS = File.join(HERE, "wx", "icons")
WCOL = { :Rain => Color.new(110, 170, 250), :Storm => Color.new(250, 210, 80), :Fog => Color.new(190, 196, 210),
         :Sun => Color.new(250, 170, 60), :Snow => Color.new(200, 236, 255), :Clear => Color.new(150, 160, 175) }
WNAME = { :Rain => "Rain", :Storm => "Storm", :Fog => "Fog", :Sun => "Sunny", :Snow => "Snow", :Clear => "Clear" }
# [name, tile x, tile y, weather, intensity]
CELLS = [["Route 24", 40, 3.5, :Rain, 6], ["Route 25", 42, 3, :Rain, 3], ["Cerulean City", 39.5, 5.5, :Rain, 4],
         ["Route 9", 41.5, 6, :Rain, 2], ["Route 10", 43, 8, :Storm, 5], ["Lavender Town", 43, 9, :Storm, 3],
         ["Celadon City", 36.5, 9, :Sun, 5], ["Route 16", 35, 10, :Sun, 3], ["Route 12", 43, 11.5, :Fog, 4],
         ["Route 13", 42, 13, :Fog, 2], ["Route 23", 43, 1.5, :Snow, 3], ["Cinnabar Island", 31, 17, :Sun, 6],
         ["Fuchsia City", 36.5, 14.5, :Rain, 2]]
NEXT = { "Route 24" => [:Storm, 7], "Route 25" => [:Rain, 5], "Cerulean City" => [:Rain, 6], "Route 9" => [:Clear, 0],
         "Route 10" => [:Storm, 3], "Lavender Town" => [:Rain, 2], "Celadon City" => [:Sun, 4], "Route 16" => [:Sun, 5],
         "Route 12" => [:Fog, 2], "Route 13" => [:Clear, 0], "Route 23" => [:Snow, 4], "Cinnabar Island" => [:Sun, 6],
         "Fuchsia City" => [:Clear, 0] }
HERE_TILE = [40, 3.5]   # the player: Route 24
SELN = "Route 24"

def clear_over; OVER.bitmap.clear; DIMMER.bitmap.clear; end
def backdrop(name); MAPS.bitmap = Bitmap.new(File.join(HERE, "wx", name)); end
def blank(c); frame(c); clear_over; MAPS.bitmap = Bitmap.new(W, H); end
def ow(c, name = "route24_rain.png"); frame(c, false); clear_over; backdrop(name); end
def icon_name(w, n)
  case w
  when :Rain, :Storm, :Fog, :Sun
    base = { :Rain => "mapRain", :Storm => "mapStorm", :Fog => "mapFog", :Sun => "mapSun" }[w]
    "#{base}_#{n >= 7 ? 'heavy' : (n >= 4 ? 'medium' : 'light')}"
  when :Snow then "mapSnow"
  else "mapClear"
  end
end
def wicon(b, w, n, cx, cy, size)
  i = bmp(File.join(ICONS, icon_name(w, n) + ".png"))
  b.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), i, Rect.new(0, 0, i.width, i.height))
end
def level_word(n); n >= 7 ? "Heavy" : (n >= 4 ? "Moderate" : "Light"); end
def type_icon(b, id, x, y, size = 16)
  b.stretch_blt(Rect.new(x, y, size, size), bmp(File.join(GFX, "Pictures/Battle/typesSmall.png")), Rect.new(0, id * 19, 19, 19))
end
def ring(b, x, y, w, h, r, color, th)
  tmp = Bitmap.new(w + 1, h + 1)
  UI.rbox(tmp, 0, 0, w, h, r, color)
  UI.rbox(tmp, th, th, w - th, h - th, [r - th, 1].max, CLEAR)
  b.blt(x, y, tmp, Rect.new(0, 0, w + 1, h + 1))
end
# The Town Map: dst rect, source origin, scale; returns a tile -> screen proc
def town_map(b, dx, dy, w, h, sx, sy, scale)
  b.stretch_blt(Rect.new(dx, dy, w, h), bmp(MAPIMG), Rect.new(sx, sy, w / scale, h / scale))
  proc { |tx, ty| [dx + ((tx * 16 + 8) - sx) * scale, dy + ((ty * 16 + 8) - sy) * scale] }
end
def map_icons(t, at, size, cells = CELLS, nxt = false, clip = [0, 0, W, H])
  cells.each do |n, tx, ty, w, i|
    w, i = NEXT[n] if nxt
    next if w == :Clear
    x, y = at.call(tx, ty)
    next if x - size / 2 < clip[0] || y - size / 2 < clip[1] || x + size / 2 > clip[2] || y + size / 2 > clip[3]
    wicon(t, w, i, x.round, y.round, size)
  end
end
def player_mark(t, at, size)
  x, y = at.call(*HERE_TILE)
  i = bmp(File.join(GFX, "Pictures/mapPlayerPOKEMONTRAINER_Red.png"))
  t.stretch_blt(Rect.new(x.round + size / 4, y.round - size - size / 4, size, size), i, Rect.new(0, 0, 32, 32))
end
def sel_ring(b, at, size, color)
  x, y = at.call(*HERE_TILE)
  ring(b, x.round - size / 2 - 3, y.round - size / 2 - 3, size + 6, size + 6, 5, color, 2)
end
def bar(b, x, y, n, colr, c, seg = 10, w = 9)
  10.times { |k| b.fill_rect(x + k * (w + 2), y, w, 6, k < n ? colr : c[:dark]) }
end
def season_chip(t, x, y, right = false); P.pill(t, x, y, "AUTUMN", Color.new(70, 40, 16), Color.new(250, 170, 90), right); end
def tabs(c, b, t, x, y, nxt = false)
  [["NOW", !nxt], ["NEXT", nxt]].each do |lbl, on|
    w = P.width(PF::TINY, lbl) + 16
    UI.rbox(b, x, y, x + w, y + 17, 5, on ? c[:sel] : c[:dark], on ? c[:selb] : c[:line])
    P.text(t, x, y + 1, w, 16, lbl, on ? c[:white] : c[:dim], PF::TINY, 2)
    x += w + 4
  end
end
def encounters(c, t, x, y, w = 150)
  P.heading(t, x, x + w, y, "More Common", c[:head], c[:line])
  [[11, "Water"], [13, "Electric"]].each_with_index do |(id, n), k|
    type_icon(t, id, x + k * 70, y + 18, 16); P.small(t, x + 20 + k * 70, y + 18, 50, 16, n, c[:txt])
  end
end
def shot(name); dump_as(name); end

c = palette(2)

#================================================================ WX1 Recommended: old KR's Forecast and alert, rebuilt
def wx1(c, nxt)
  blank(c)
  b = BASE.bitmap; t = TOP.bitmap
  P.text(t, 0, 6, W, 24, "Weather Forecast", c[:title], PF::ROW, 2)
  season_chip(t, 10, 10)
  tabs(c, b, t, W - 98, 9, nxt)
  UI.rbox(b, 8, 36, 336, 354, 8, c[:panel], c[:line])
  at = town_map(b, 10, 38, 324, 314, 452, 0, 1)
  map_icons(t, at, 20, CELLS, nxt, [10, 38, 334, 352])
  sel_ring(b, at, 20, c[:selb])
  player_mark(t, at, 16)
  UI.rbox(b, 344, 36, 504, 354, 8, c[:panel], c[:line])
  w, i = nxt ? NEXT[SELN] : [:Rain, 6]
  P.text(t, 344, 42, 160, 24, SELN, c[:title], PF::ROW, 2)
  wicon(t, w, i, 374, 92, 40)
  P.text(t, 400, 74, 100, 24, WNAME[w], WCOL[w], PF::ROW)
  P.small(t, 400, 96, 100, 16, level_word(i), c[:dim])
  bar(b, 354, 120, i, WCOL[w], c, 10, 12)
  rows = [["Climate", "Temperate", c[:txt]], ["Trend", "Rising", Color.new(120, 230, 150)],
          [nxt ? "After" : "Next", nxt ? "Storm" : "Storm", WCOL[:Storm]], ["Season", "Autumn", Color.new(250, 170, 90)]]
  rows.each_with_index do |(l, v, colr), k|
    y = 136 + k * 22
    P.small(t, 354, y, 70, 16, l, c[:dim]); P.small(t, 424, y, 74, 16, v, colr, 1)
  end
  encounters(c, t, 354, 230, 140)
  b.fill_rect(354, 300, 140, 1, c[:line])
  P.small(t, 344, 310, 160, 16, "Updates in 2h 14m", c[:dim], 2)
  hints(c, [[:ud, ""], [:lr, "Move"], [X_BTN, nxt ? "Now" : "Next"], [Y_BTN, "Recentre"], [B_BTN, "Back"]])
end
wx1(c, false)
shot("WX1_forecast")
ow(c)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 8, 8, 184, 52, 8, c[:panel], c[:line])
wicon(t, :Rain, 6, 30, 30, 32)
P.text(t, 52, 9, 130, 24, "Rain Started", c[:txt], PF::TEXT)
P.small(t, 52, 31, 130, 16, "Route 24", c[:dim])
shot("WX1_alert")

#================================================================ WX2: the whole screen is the map (2x); details in a bottom card
blank(c)
b = BASE.bitmap; t = TOP.bitmap
at = town_map(b, 0, 0, W, 359, 520, 0, 2)
map_icons(t, at, 32, CELLS, false, [0, 0, W, 359])
sel_ring(b, at, 32, c[:selb])
player_mark(t, at, 20)
b = DIMMER.bitmap; t = OVER.bitmap
UI.rbox(b, -8, -8, W + 8, 32, 8, col(c[:panel], 240), c[:line])
P.text(t, 0, 4, W, 24, "Weather Forecast", c[:title], PF::ROW, 2)
season_chip(t, 10, 8)
tabs(c, b, t, W - 98, 7)
UI.rbox(b, 8, 262, 504, 352, 8, col(c[:panel], 250), c[:line])
wicon(t, :Rain, 6, 38, 292, 40)
P.text(t, 64, 268, 160, 24, "Route 24", c[:title], PF::ROW)
P.small(t, 64, 292, 160, 16, "Rain, Moderate", WCOL[:Rain])
bar(b, 20, 324, 6, WCOL[:Rain], c, 10, 12)
b.fill_rect(180, 272, 1, 72, c[:line])
P.small(t, 192, 272, 60, 16, "Next", c[:dim])
wicon(t, :Storm, 7, 202, 306, 24)
P.small(t, 218, 298, 80, 16, "Storm", WCOL[:Storm])
P.small(t, 192, 326, 120, 16, "In 2h 14m", c[:dim])
b.fill_rect(320, 272, 1, 72, c[:line])
encounters(c, t, 332, 272, 160)
P.small(t, 332, 318, 160, 16, "Temperate, Rising", c[:dim])
hints(c, [[:ud, ""], [:lr, "Move"], [X_BTN, "Next"], [Y_BTN, "Recentre"], [B_BTN, "Back"]])
shot("WX2_forecast")
ow(c)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 116, 8, 396, 44, 8, c[:panel], c[:line])
wicon(t, :Rain, 6, 140, 26, 28)
P.text(t, 160, 14, 230, 22, "Rain Started on Route 24", c[:txt], PF::TEXT, 2)
shot("WX2_alert")

#================================================================ WX3: a list of every area's weather, with a small map
LIST = ["Route 24", "Route 25", "Cerulean City", "Route 9", "Route 23", "Route 10", "Lavender Town", "Celadon City",
        "Route 16", "Route 12", "Route 13", "Fuchsia City", "Cinnabar Island"]
blank(c)
b = BASE.bitmap; t = TOP.bitmap
P.text(t, 0, 6, W, 24, "Weather Forecast", c[:title], PF::ROW, 2)
season_chip(t, 10, 10)
tabs(c, b, t, W - 98, 9)
UI.rbox(b, 8, 36, 236, 354, 8, c[:panel], c[:line])
LIST.each_with_index do |n, k|
  cell = CELLS.find { |x| x[0] == n }
  y = 42 + k * 24
  cursor_at(12, y, 220, 24) if n == SELN
  wicon(t, cell[3], cell[4], 26, y + 12, 20)
  P.text(t, 42, y, 120, 24, n, c[:txt], PF::TEXT)
  P.small(t, 150, y + 4, 78, 16, WNAME[cell[3]], WCOL[cell[3]], 1)
end
UI.rbox(b, 244, 36, 504, 354, 8, c[:panel], c[:line])
at = town_map(b, 246, 38, 256, 170, 560, 0, 1)
map_icons(t, at, 16, CELLS, false, [246, 38, 502, 208])
sel_ring(b, at, 16, c[:selb])
b.fill_rect(252, 210, 244, 1, c[:line])
wicon(t, :Rain, 6, 272, 236, 32)
P.text(t, 294, 216, 200, 24, "Route 24", c[:title], PF::ROW)
P.small(t, 294, 238, 200, 16, "Rain, Moderate. Rising.", WCOL[:Rain])
P.small(t, 256, 262, 60, 16, "Next", c[:dim])
wicon(t, :Storm, 7, 312, 270, 18)
P.small(t, 326, 262, 80, 16, "Storm", WCOL[:Storm])
P.small(t, 400, 262, 96, 16, "In 2h 14m", c[:dim], 1)
encounters(c, t, 256, 290, 240)
hints(c, [[:ud, "Choose"], [X_BTN, "Next"], [Y_BTN, "Here"], [B_BTN, "Back"]])
shot("WX3_forecast")
ow(c)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 368, 8, 504, 64, 8, c[:panel], c[:line])
wicon(t, :Rain, 6, 436, 28, 32)
P.small(t, 368, 44, 136, 16, "Rain: Route 24", c[:txt], 2)
shot("WX3_alert")

#================================================================ WX4: Now and Next side by side (no tabs)
def wcard(c, b, t, x, y, w, h, label, wt, i, sub)
  UI.rbox(b, x, y, x + w, y + h, 8, c[:dark], c[:line])
  P.pill(t, x + 8, y + 8, label, label == "NOW" ? c[:sel] : c[:panel], label == "NOW" ? c[:white] : c[:dim], false)
  wicon(t, wt, i, x + 30, y + 50, 36)
  P.text(t, x + 56, y + 30, w - 60, 24, WNAME[wt], WCOL[wt], PF::ROW)
  P.small(t, x + 56, y + 52, w - 60, 16, sub, c[:dim])
  bar(b, x + 12, y + h - 14, i, WCOL[wt], c, 10, 14)
end
blank(c)
b = BASE.bitmap; t = TOP.bitmap
P.text(t, 0, 6, W, 24, "Weather Forecast", c[:title], PF::ROW, 2)
season_chip(t, 10, 10)
UI.rbox(b, 8, 36, 296, 354, 8, c[:panel], c[:line])
at = town_map(b, 10, 38, 284, 314, 476, 0, 1)
map_icons(t, at, 20, CELLS, false, [10, 38, 294, 352])
sel_ring(b, at, 20, c[:selb])
player_mark(t, at, 16)
UI.rbox(b, 304, 36, 504, 354, 8, c[:panel], c[:line])
P.text(t, 304, 42, 200, 24, SELN, c[:title], PF::ROW, 2)
wcard(c, b, t, 312, 70, 184, 92, "NOW", :Rain, 6, "Moderate")
UI.tri(b, 398, 168, :d, c[:dim], 5)
P.small(t, 412, 166, 90, 16, "2h 14m", c[:dim])
wcard(c, b, t, 312, 186, 184, 92, "NEXT", :Storm, 7, "Heavy, Rising")
encounters(c, t, 314, 290, 180)
P.small(t, 304, 334, 200, 16, "Temperate", c[:dim], 2)
hints(c, [[:ud, ""], [:lr, "Move"], [Y_BTN, "Recentre"], [B_BTN, "Back"]])
shot("WX4_forecast")
ow(c)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 8, 312, 236, 372, 8, c[:panel], c[:line])
wicon(t, :Rain, 6, 34, 342, 32)
P.text(t, 58, 316, 176, 24, "Rain Started", c[:txt], PF::TEXT)
P.small(t, 58, 338, 176, 16, "Route 24. Storm Next.", c[:dim])
shot("WX4_alert")

#================================================================ WX5: the older Weather mod's Weather Box, grown into a forecast card
ow(c)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 300, 8, 504, 238, 8, col(c[:panel], 245), c[:line])
wicon(t, :Rain, 6, 330, 38, 40)
P.text(t, 356, 14, 140, 24, "Rain", WCOL[:Rain], PF::ROW)
P.small(t, 356, 38, 140, 16, "Route 24", c[:dim])
season_chip(t, 494, 18, true)
b.fill_rect(310, 64, 184, 1, c[:line])
P.heading(t, 310, 494, 70, "Nearby", c[:head], c[:line])
[["Route 25", :Rain, 3], ["Cerulean City", :Rain, 4], ["Route 9", :Rain, 2], ["Route 23", :Snow, 3]].each_with_index do |(n, w, i), k|
  y = 88 + k * 22
  wicon(t, w, i, 320, y + 10, 18)
  P.small(t, 334, y + 2, 110, 16, n, c[:txt]); P.small(t, 420, y + 2, 76, 16, WNAME[w], WCOL[w], 1)
end
b.fill_rect(310, 180, 184, 1, c[:line])
P.small(t, 310, 186, 70, 16, "Next", c[:dim])
wicon(t, :Storm, 7, 362, 194, 18)
P.small(t, 376, 186, 60, 16, "Storm", WCOL[:Storm])
P.small(t, 420, 186, 76, 16, "2h 14m", c[:dim], 1)
type_icon(t, 11, 310, 210, 16); type_icon(t, 13, 330, 210, 16)
P.small(t, 352, 210, 144, 16, "More Common", c[:dim])
shot("WX5_card")
ow(c, "../backdrop.png")
OVER.bitmap.blt(0, 0, Bitmap.new(File.join(HERE, "wx", "icons", "Autumn.png")), Rect.new(0, 0, W, H))
shot("WX5_season")
