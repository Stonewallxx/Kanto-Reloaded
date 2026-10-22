# encoding: utf-8
# Mockups: Weather System, Field Weather Moves, design 3: from the chosen
# Overworld Menu (Tabbed Panel, ow_designs.rb O4): a Weather Moves entry,
# then its page listing the party's weather moves. Route 24, clear.
# Usage (from this folder): ruby fwm_ow.rb "<KIF Beta>" <work dir with metrics.json>
OWSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "ow_designs.rb"), :encoding => "UTF-8")
eval(OWSRC.split("#================================================================ O1")[0], binding, "ow_designs.rb")

c = palette(2)
MAPS.bitmap = Bitmap.new(File.join(HERE, "wx", "route24_clear.png"))
ICONS = File.join(HERE, "wx", "icons")
WCOL = { :Rain => Color.new(110, 170, 250), :Sun => Color.new(250, 170, 60), :Snow => Color.new(200, 236, 255), :Sand => Color.new(220, 180, 120) }
def wicon(b, file, cx, cy, size)
  i = bmp(File.join(ICONS, file + ".png"))
  b.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), i, Rect.new(0, 0, i.width, i.height))
end
OW_ENTRIES = [["hr:BAG", "Quick Items", "4"], ["hr:POKEVIAL", "PokeVial", "3/5"], ["item:MAXPOTION", "Heal with Moves", "2"],
              ["item:DAMPROCK", "Weather Moves", "3"], ["item:TOWNMAP", "Fly", ""], ["item:REPEL", "Repel", "142"],
              ["item:OVALCHARM", "Egg Manager", "2 Eggs"], ["item:POKERADAR", "Wild Link", "Abra"], ["hr:SAVE", "Quick Save", ""]]
W_MOVES = [["mapRain_medium", "Rain Dance", "Pikachu", :Rain], ["mapStorm_medium", "Thunder", "Pikachu", :Storm],
           ["mapSun_medium", "Sunny Day", "Snorlax", :Sun], ["mapSnow", "Hail", "Gyarados", :Snow],
           ["mapSand", "Sandstorm", nil, :Sand]]
WEATHER_BOX = ["Route 24", "Clear until 6 PM", "Here: 2 of 6 Caught"]

def ow_menu(c, sel, sub)
  frame(c)
  base = BASE.bitmap; top = TOP.bitmap
  px0 = 4; pw = 220
  panel(base, px0, 4, px0 + pw - 1, 296, c, 235)
  if sub
    stext(top, px0, 6, pw, 22, "Weather Moves", c[:title], PF::ROW, 2, c)
    W_MOVES.each_with_index do |(ic, mv, who, w), i|
      y = 34 + i * 33
      cursor_at(px0 + 5, y, pw - 10, 32) if i == sel
      wicon(top, ic, px0 + 22, y + 16, 22)
      P.text(top, px0 + 40, y, 120, 18, mv, who ? (i == sel ? c[:white] : c[:txt]) : c[:dim], PF::TEXT)
      P.small(top, px0 + 40, y + 17, 160, 14, who || "No One Knows It", c[:dim])
    end
    base.fill_rect(px0 + 10, 202, pw - 20, 1, c[:line])
    P.small(top, px0 + 12, 208, pw - 24, 14, "Rain for 3 hours on Route 24.", c[:txt])
    P.small(top, px0 + 12, 226, pw - 24, 14, "More Water and Electric", c[:dim])
    P.small(top, px0 + 12, 240, pw - 24, 14, "types while it lasts.", c[:dim])
    P.small(top, px0 + 12, 260, pw - 24, 14, "Outdoors only. A map's own", c[:dim])
    P.small(top, px0 + 12, 274, pw - 24, 14, "weather can't be changed.", c[:dim])
  else
    stext(top, px0, 6, pw, 22, "Overworld Menu", c[:title], PF::ROW, 2, c)
    page_tabs(c, px0 + 8, 30, pw - 16)
    OW_ENTRIES.each_with_index do |(ic, label, status), i|
      y = 52 + i * 26
      cursor_at(px0 + 5, y, pw - 10, 25) if i == sel
      draw_icon(top, ic, px0 + 20, y + 12, 20)
      P.text(top, px0 + 36, y, 120, 25, label, i == sel ? c[:white] : c[:txt], PF::TEXT)
      P.text(top, px0 + pw - 70, y, 60, 25, status, GREEN, PF::TEXT, 1) unless status.empty?
    end
  end
  # the Area panel, with this area's weather
  panel(base, W - 186, 4, W - 5, 55, c)
  wicon(top, "mapClear", W - 166, 30, 26)
  P.text(top, W - 148, 8, 140, 16, WEATHER_BOX[0], c[:txt], PF::TEXT)
  P.small(top, W - 148, 24, 140, 14, WEATHER_BOX[1], c[:acc])
  P.small(top, W - 148, 38, 140, 14, WEATHER_BOX[2], c[:dim])
  PARTY.each_with_index do |(sp, name, lv, hp, tot, types), i|
    cw = 90; chh = 56
    px = W - 4 - 3 * (cw + 4) + 4 + (i % 3) * (cw + 4); py = 238 + (i / 3) * (chh + 4)
    panel(base, px, py, px + cw - 1, py + chh - 1, c, 228, 6)
    mon_icon(top, sp, px + 22, py + 28, 44)
    if sp
      P.text(top, px + 44, py + 5, 48, 12, PF.fit(PF::TINY, name, 48), c[:txt], PF::TINY)
      P.text(top, px + 44, py + 19, 48, 12, "Lv #{lv}", GOLD, PF::TINY)
      hp_bar(base, px + 44, py + 35, 44, hp, tot, c)
      P.text(top, px + 44, py + 41, 48, 12, "#{hp}/#{tot}", hp_color(hp, tot), PF::TINY)
    else
      P.text(top, px + 44, py + 22, 48, 12, "EGG", c[:dim], PF::TINY)
    end
  end
  panel(base, px0, 302, px0 + pw - 1, 352, c, 235)
  P.text(top, px0 + 10, 306, 120, 12, "QUICK ITEMS", c[:head], PF::TINY)
  ["item:SUPERROD", "item:BICYCLE", "item:ITEMFINDER", "item:ESCAPEROPE"].each_with_index do |ic, k|
    draw_icon(top, ic, px0 + 30 + k * 48, 334, 28)
  end
end

ow_menu(c, 3, false)
hints(c, [[:ud, "Choose"], [:lr, "Pages"], [A_BTN, "Use"], [Y_BTN, "Party View"], [B_BTN, "Close"]])
dump_as("FWM3_menu")
ow_menu(c, 0, true)
hints(c, [[:ud, "Choose"], [A_BTN, "Use"], [B_BTN, "Back"]])
dump_as("FWM3_moves")
