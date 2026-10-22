# encoding: utf-8
# Weather on the Fly Map: the KR-style parts over KIF Beta's Fly map
# (bases from fly_designs.py): design 3's Y toggle hint, design 5's hover card.
# Usage (from this folder): ruby fly_kr.rb "<KIF Beta>" <work dir with metrics.json>
WXSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "wx_designs.rb"), :encoding => "UTF-8")
eval(WXSRC.split("wx1(c, false)\n")[0], binding, "wx_designs.rb")

def flybg(c, name); frame(c, false); clear_over; MAPS.bitmap = Bitmap.new(File.join(HERE, "wx", "fly", name + ".png")); end
def toggle_hint(c, on)
  b = BASE.bitmap; t = TOP.bitmap
  w = P.hints_width(t, [[Y_BTN, "Weather"]], $style) + 16
  UI.rbox(b, 492 - w, 4, 492, 28, 6, on ? c[:sel] : c[:panel], on ? c[:selb] : c[:line])
  P.draw_hints(t, 500 - w, 4, c, [[Y_BTN, "Weather"]], $style)
end
def card(c, x, y, name, w, n, wname, sub, nxt, nxt_w, types)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, x, y, x + 168, y + 118, 8, c[:panel], c[:selb])
  P.text(t, x, y + 4, 168, 22, name, c[:title], PF::TEXT, 2)
  b.fill_rect(x + 8, y + 27, 152, 1, c[:line])
  wicon(t, w, n, x + 26, y + 48, 32)
  P.text(t, x + 48, y + 30, 116, 22, wname, WCOL[w], PF::TEXT)
  P.small(t, x + 48, y + 50, 116, 16, sub, c[:dim])
  P.small(t, x + 10, y + 72, 60, 16, "Next", c[:dim])
  wicon(t, nxt_w, 4, x + 62, y + 80, 16)
  P.small(t, x + 74, y + 72, 90, 16, nxt, WCOL[nxt_w])
  types.each_with_index do |(id, tn), k|
    type_icon(t, id, x + 10 + k * 76, y + 96, 16); P.small(t, x + 30 + k * 76, y + 96, 50, 16, tn, c[:txt])
  end
end

c = palette(2)
flybg(c, "F3_off"); toggle_hint(c, false); shot("F3_off_k")
flybg(c, "F3_on"); toggle_hint(c, true); shot("F3_on_k")
flybg(c, "F5_cer"); card(c, 326, 120, "Cerulean City", :Rain, 4, "Rain", "Moderate", "Rain, 2h", :Rain, [[11, "Water"], [13, "Electric"]]); shot("F5_cer_k")
flybg(c, "F5_cel"); card(c, 280, 168, "Celadon City", :Sun, 5, "Sunny", "Moderate", "Sunny, 2h", :Sun, [[10, "Fire"], [12, "Grass"]]); shot("F5_cel_k")
flybg(c, "FM_now"); card(c, 326, 120, "Cerulean City", :Rain, 4, "Rain", "Moderate", "Rain, 2h", :Rain, [[11, "Water"], [13, "Electric"]]); shot("FM_now_k")
flybg(c, "FM_next"); card(c, 326, 120, "Cerulean City", :Rain, 6, "Rain", "Moderate, in 2h", "Rain, 8h", :Rain, [[11, "Water"], [13, "Electric"]]); shot("FM_next_k")
