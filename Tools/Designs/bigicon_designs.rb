# encoding: utf-8
# Mockups: Summary and Big Icons, part 4: KIF's Big Pokemon Icons in our
# screens. Five designs, each two screens: the chosen Overworld Menu's party
# cards (Tabbed Panel) and a PC box. KIF: a big icon is the battle sprite at
# 1/3 size (96 px where a 64 px icon goes), moved 16 px left; shinies keep
# their palette (the Lapras here is shiny, Wild style).
# Design 1 = KIF's big icons as they are, placed in our cards and boxes.
# Usage (from this folder): ruby bigicon_designs.rb "<KIF Beta>" <work dir with metrics.json>
OWSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "ow_designs.rb"), :encoding => "UTF-8")
eval(OWSRC.split("#================================================================ O1")[0], binding, "ow_designs.rb")

SH = File.join(HERE, "sh")
MAPS.bitmap = Bitmap.new(File.join(HERE, "wx", "route24_clear.png"))
GOLD2 = Color.new(240, 200, 70)
TEAM = [["PIKACHU", "Pikachu", 34, 78, 95, [13]], ["GYARADOS", "Gyarados", 36, 120, 120, [11, 2]],
        ["GENGAR", "Gengar", 35, 40, 110, [7, 3]], ["ALAKAZAM", "Alakazam", 33, 15, 90, [14]],
        ["SNORLAX", "Snorlax", 34, 160, 160, [0]], ["LAPRAS", "Lapras", 32, 120, 130, [11, 15]]]
BOX = ["ABRA", "ODDISH", "ZUBAT", "MAGIKARP", "EEVEE", "BULBASAUR", "PIKACHU", "GENGAR", nil, "LAPRAS", "SNORLAX", nil, "GYARADOS", nil, nil]
TYPEC = { 13 => [120, 100, 30], 11 => [40, 70, 120], 7 => [70, 50, 100], 14 => [110, 50, 80], 0 => [80, 80, 70], 12 => [50, 100, 50], 3 => [90, 50, 100] }
BOXT = { "ABRA" => 14, "ODDISH" => 12, "ZUBAT" => 3, "MAGIKARP" => 11, "EEVEE" => 0, "BULBASAUR" => 12, "PIKACHU" => 13, "GENGAR" => 7, "LAPRAS" => 11, "SNORLAX" => 0, "GYARADOS" => 11 }
def img(b, path, x, y, w, h, src = nil)
  i = bmp(path); src ||= Rect.new(0, 0, i.width, i.height)
  b.stretch_blt(Rect.new(x, y, w, h), i, src)
end
def shiny_path(sp, kind)
  return File.join(SH, "LAPRAS_wild.png") if sp == "LAPRAS" && kind == "big"
  File.join(SH, "#{kind}_#{sp}.png")
end
# style: :kif (96 px, 16 left), :framed (cropped to fit), :portrait (head crop), :normal (64 px icon)
def bigicon(b, sp, cx, cy, size, style)
  case style
  when :kif then img(b, shiny_path(sp, "big"), cx - size / 2 - size / 6, cy - size / 2, size, size)
  when :framed then img(b, File.join(SH, "bigc_#{sp}.png"), cx - size / 2, cy - size / 2, size, size)
  when :portrait then img(b, File.join(SH, "bigp_#{sp}.png"), cx - size / 2, cy - size / 2, size, size)
  else sp == "LAPRAS" ? img(b, File.join(SH, "LAPRAS_wild_icon.png"), cx - size / 2, cy - size / 2, size, size, Rect.new(0, 0, 64, 64)) : mon_icon(b, sp, cx, cy, size)
  end
end
def star5(b, x, y)
  ["..#..", ".###.", "#####", ".###.", "#.#.#"].each_with_index { |r, j| r.each_char.with_index { |ch, i| b.fill_rect(x + i, y + j, 1, 1, GOLD2) if ch == "#" } }
end
def cards(c, style, tint = false)
  frame(c)
  MAPS.bitmap = Bitmap.new(File.join(HERE, "wx", "route24_clear.png"))
  base = BASE.bitmap; top = TOP.bitmap
  px0 = 4; pw = 220
  panel(base, px0, 4, px0 + pw - 1, 296, c, 235)
  stext(top, px0, 6, pw, 22, "Overworld Menu", c[:title], PF::ROW, 2, c)
  page_tabs(c, px0 + 8, 30, pw - 16)
  ENTRIES.first(9).each_with_index do |(ic, label, status), i|
    y = 52 + i * 26
    cursor_at(px0 + 5, y, pw - 10, 25) if i == 0
    draw_icon(top, ic, px0 + 20, y + 12, 20)
    P.text(top, px0 + 36, y, 120, 25, label, i == 0 ? c[:white] : c[:txt], PF::TEXT)
  end
  TEAM.each_with_index do |(sp, name, lv, hp, tot, types), i|
    cw = 90; chh = 72
    px = W - 4 - 3 * (cw + 4) + 4 + (i % 3) * (cw + 4); py = 196 + (i / 3) * (chh + 4)
    fill = tint && TYPEC[types[0]] ? Color.new(*TYPEC[types[0]], 235) : nil
    fill ? UI.rbox(base, px, py, px + cw - 1, py + chh - 1, 6, fill, c[:line]) : panel(base, px, py, px + cw - 1, py + chh - 1, c, 228, 6)
    size = style == :normal ? 44 : 50
    bigicon(top, sp, px + (style == :kif ? 28 : 23), py + 34, size, style)
    star5(top, px + 4, py + 4) if sp == "LAPRAS"
    P.text(top, px + 46, py + 6, 44, 12, PF.fit(PF::TINY, name, 44), c[:txt], PF::TINY)
    P.text(top, px + 46, py + 22, 44, 12, "Lv #{lv}", GOLD, PF::TINY)
    hp_bar(base, px + 46, py + 42, 40, hp, tot, c)
    P.text(top, px + 46, py + 50, 44, 12, "#{hp}/#{tot}", hp_color(hp, tot), PF::TINY)
  end
  hints(c, [[:ud, "Choose"], [:lr, "Pages"], [A_BTN, "Use"], [Y_BTN, "Party View"], [B_BTN, "Close"]])
end
def pcbox(c, style, tint = false)
  frame(c)
  MAPS.bitmap = Bitmap.new(W, H)
  base = BASE.bitmap; top = TOP.bitmap
  base.fill_rect(0, 0, W, H, c[:bg])
  P.text(top, 0, 4, W, 24, "Box 1", c[:title], PF::ROW, 2)
  UI.tri(top, 200, 12, :l, c[:dim], 5); UI.tri(top, 306, 12, :r, c[:dim], 5)
  BOX.each_with_index do |sp, i|
    x = 14 + (i % 5) * 98; y = 34 + (i / 5) * 98
    fill = tint && sp ? Color.new(*TYPEC[BOXT[sp]], 235) : c[:panel]
    UI.rbox(base, x, y, x + 92, y + 92, 8, fill, i == 9 ? c[:selb] : c[:line])
    cursor_at(x - 2, y - 2, 96, 96) if i == 9
    next unless sp
    bigicon(top, sp, x + 46, y + 46, style == :normal ? 64 : 84, style)
    star5(top, x + 6, y + 6) if sp == "LAPRAS"
  end
  hints(c, [[:ud, ""], [:lr, "Choose"], [A_BTN, "Pick Up"], [B_BTN, "Back"]])
end

c = palette(2)

#================================================================ BI1 Recommended: KIF's big icons as they are
cards(c, :kif); dump_as("BI1_cards")
pcbox(c, :kif); dump_as("BI1_box")

#================================================================ BI2: framed (the sprite cropped to fill its spot)
cards(c, :framed); dump_as("BI2_cards")
pcbox(c, :framed); dump_as("BI2_box")

#================================================================ BI3: portraits (head and shoulders)
cards(c, :portrait); dump_as("BI3_cards")
pcbox(c, :portrait); dump_as("BI3_box")

#================================================================ BI4: big icons on cards tinted by the first type
cards(c, :framed, true); dump_as("BI4_cards")
pcbox(c, :framed); dump_as("BI4_box")

#================================================================ BI5: big where there's room (cards), normal icons in dense grids
cards(c, :kif); dump_as("BI5_cards")
pcbox(c, :normal); dump_as("BI5_box")

#================================================================ BIX: his mix: KIF's big icons on design 4's type-tinted cards
cards(c, :kif, true); dump_as("BIX_cards")
pcbox(c, :kif, true); dump_as("BIX_box")
