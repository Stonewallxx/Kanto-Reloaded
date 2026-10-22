# encoding: utf-8
# What the party screen mockups share (party_designs.rb, party_styled_designs.rb):
# the party, its pieces, and the card and details drawing.
load File.join(File.dirname(File.expand_path(__FILE__)), "qa_common.rb")

KR_DIR = File.expand_path(File.join(QA_HERE, "..", "..", ".."))
GFX = File.join(ARGV[0], "Graphics")
OMS = Reloaded::OverworldMenuScreen
BLUE_T = Color.new(130, 190, 250)
RED_T = Color.new(240, 100, 90)
AMBER_T = Color.new(240, 170, 60)

MONS = [
  { :sp => :PIKACHU, :name => "Pikachu", :lv => 34, :hp => 78, :tot => 95, :g => 0, :item => "LIGHTBALL", :types => [:ELECTRIC], :pkrs => true,
    :nature => "Timid", :ability => "Static",
    :moves => [["Thunderbolt", 15, 15, :ELECTRIC], ["Quick Attack", 30, 30, :NORMAL], ["Iron Tail", 15, 15, :STEEL], ["Double Team", 15, 15, :NORMAL]] },
  { :sp => :PIDGEOT, :name => "Pidgeot", :lv => 36, :hp => 0, :tot => 120, :g => 1, :shiny => :cyan, :types => [:NORMAL, :FLYING],
    :nature => "Jolly", :ability => "Keen Eye",
    :moves => [["Fly", 15, 15, :FLYING], ["Wing Attack", 35, 35, :FLYING], ["Quick Attack", 30, 30, :NORMAL], ["Sand Attack", 15, 15, :GROUND]] },
  { :sp => :GYARADOS, :name => "Gyarados", :lv => 35, :hp => 20, :tot => 110, :g => 0, :types => [:WATER, :FLYING], :lock => 35,
    :nature => "Adamant", :ability => "Intimidate",
    :moves => [["Waterfall", 15, 15, :WATER], ["Bite", 25, 25, :DARK], ["Dragon Rage", 10, 10, :DRAGON], ["Thrash", 8, 10, :NORMAL]] },
  { :sp => :EEVEE, :name => "Eevee", :lv => 22, :hp => 60, :tot => 60, :g => 1, :evolock => true, :types => [:NORMAL],
    :nature => "Bashful", :ability => "Adaptability",
    :moves => [["Bite", 25, 25, :DARK], ["Quick Attack", 30, 30, :NORMAL], ["Sand Attack", 15, 15, :GROUND], ["Growl", 40, 40, :NORMAL]] },
  { :sp => :GENCHOKE, :name => "Genchoke", :lv => 37, :hp => 70, :tot => 120, :g => 0, :status => :POISON, :types => [:GHOST, :FIGHTING],
    :fusion => "Gengar / Machoke", :nature => "Brave", :ability => "Guts",
    :moves => [["Shadow Punch", 20, 20, :GHOST], ["Karate Chop", 25, 25, :FIGHTING], ["Hypnosis", 20, 20, :PSYCHIC], ["Seismic Toss", 20, 20, :FIGHTING]] },
  { :sp => :EGG, :name => "Egg", :egg => true }
]
SEL = 2
TYPE_ROW = { :NORMAL => 0, :FIGHTING => 1, :FLYING => 2, :POISON => 3, :GROUND => 4, :ROCK => 5, :BUG => 6, :GHOST => 7, :STEEL => 8,
             :FIRE => 10, :WATER => 11, :GRASS => 12, :ELECTRIC => 13, :PSYCHIC => 14, :ICE => 15, :DRAGON => 16, :DARK => 17, :FAIRY => 18 }
TYPE_RGB = { :NORMAL => [168, 168, 120], :FIGHTING => [192, 48, 40], :FLYING => [168, 144, 240], :POISON => [160, 64, 160],
             :GROUND => [224, 192, 104], :ROCK => [184, 160, 56], :BUG => [168, 184, 32], :GHOST => [112, 88, 152], :STEEL => [184, 184, 208],
             :FIRE => [240, 128, 48], :WATER => [104, 144, 240], :GRASS => [120, 200, 80], :ELECTRIC => [248, 208, 48],
             :PSYCHIC => [248, 88, 136], :ICE => [152, 216, 216], :DRAGON => [112, 56, 248], :DARK => [112, 88, 72], :FAIRY => [238, 153, 172] }

#---------------------------------------------------------------- pieces
def tcol(t); Color.new(*TYPE_RGB[t]); end
def tint(c, m, sel = false)
  base = sel ? c[:sel] : c[:panel2]
  return base if m[:egg]
  Reloaded::Palette.mix(base, tcol(m[:types][0]), sel ? 0.18 : 0.26)
end
def type_icons(o, types, x, y)
  sheet = qa_bmp(File.join(KR_DIR, "Graphics", "OverworldMenu", "typesSmall16.png"))
  types.each_with_index { |t, k| o.blt(x + k * 18, y, sheet, Rect.new(0, TYPE_ROW[t] * 16, 16, 16)) }
  return types.length * 18 - 2
end
def item_icon(o, item, cx, cy, size = 24)
  bm = qa_bmp(File.join(GFX, "Items", "#{item}.png"))
  o.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), bm, Rect.new(0, 0, bm.width, bm.height))
end
def pix(o, rows, x, y, col)
  rows.each_with_index { |ln, r| ln.each_char.with_index { |ch, k| o.fill_rect(x + k, y + r, 1, 1, col) if ch == "#" } }
end
# gender, shiny star and the level lock, from x; returns the width
def marks(o, m, x, y)
  w = 0
  if m[:g] == 0 then pix(o, OMS::MALE, x, y, BLUE_T); w += 9
  elsif m[:g] == 1 then pix(o, OMS::FEMALE, x, y, PINK_T); w += 8
  end
  # KIF's shiny star, coloured by the kind of shiny (cyan here)
  if m[:shiny] then pix(o, OMS::STAR, x + w, y, m[:shiny] == :cyan ? Color.new(0, 255, 255) : GOLD_T); w += 10 end
  return w
end
def level(o, m, x, y, align = 0, w = 60)
  s = "LV #{m[:lv]}"
  tw = P2.width(PF::TINY, s) + (m[:lock] ? 13 : 0)
  x0 = align == 2 ? x + (w - tw) / 2 : (align == 1 ? x + w - tw : x)
  P2.text(o, x0, y, tw, 12, s, $level_col || GOLD_T, PF::TINY)
  lock_icon(o, x0 + tw - 9, y, $level_col || GOLD_T) if m[:lock]
  return tw
end
def hpbar(o, c, x, y, w, m, h = 4)
  f = m[:hp].to_f / m[:tot]
  col = f > 0.5 ? GREEN_T : (f > 0.25 ? AMBER_T : RED_T)
  # his ask: an outline round the bar (a light edge, then the dark track)
  if $hp_outline
    P2.ui.rbox(o, x - 2, y - 2, x + w + 2, y + h + 2, 2, $hp_outline)
    P2.ui.rbox(o, x - 1, y - 1, x + w + 1, y + h + 1, 1, Color.new(16, 20, 28))
  end
  P2.ui.rbox(o, x, y, x + w, y + h, 1, c[:dark])
  P2.ui.rbox(o, x, y, x + [(w * f).round, 2].max, y + h, 1, col) if m[:hp] > 0
end
def hptext(o, c, x, y, w, m, align = 1)
  P2.text(o, x, y, w, 12, "#{m[:hp]}/#{m[:tot]}", m[:hp] > 0 ? c[:txt] : RED_T, PF::TINY, align)
end
def status(o, m, x, y, right = true)
  word, rgb = m[:hp] == 0 && !m[:egg] ? ["FNT", [240, 100, 90]] : (m[:status] ? OMS::STATUS[m[:status]] : (m[:pkrs] ? ["PKRS", [230, 120, 220]] : nil))
  return 0 unless word
  P2.pill(o, x, y, word, Color.new(rgb[0] / 4, rgb[1] / 4, rgb[2] / 4), Color.new(*rgb), right)
end
def screen(o, c, title)
  o.clear
  o.fill_rect(0, 0, SW, SH, c[:bg])
  o.fill_rect(0, 0, SW, 30, c[:panel])
  o.fill_rect(0, 30, SW, 1, c[:line])
  P2.text(o, 0, 4, SW, 22, title, c[:txt], PF::ROW, 2)
  P2.hints(o, o, c, $qa_hints) if $qa_hints
end
def card(o, c, x0, y0, x1, y1, m, sel)
  fill = m[:hp] == 0 && !m[:egg] ? Reloaded::Palette.mix(sel ? c[:sel] : c[:panel2], RED_T, 0.22) : tint(c, m, sel)
  P2.ui.rbox(o, x0, y0, x1, y1, 6, fill, sel ? c[:selb] : c[:line])
end
# KIF's evolution lock padlock (12 x 15), as KIF draws it over a big icon
def evolock(o, x, y)
  dark = Color.new(64, 64, 64); gold = Color.new(232, 184, 48); shine = Color.new(255, 232, 140)
  o.fill_rect(x + 2, y, 8, 2, dark); o.fill_rect(x + 2, y, 2, 7, dark); o.fill_rect(x + 8, y, 2, 7, dark)
  o.fill_rect(x, y + 6, 12, 9, dark); o.fill_rect(x + 1, y + 7, 10, 7, gold); o.fill_rect(x + 2, y + 8, 3, 1, shine)
  o.fill_rect(x + 5, y + 9, 2, 3, dark)
end
def heading(o, c, x0, x1, y, label); P2.heading(o, x0, x1, y, label, c[:dim], c[:line]); end
# a move: a type-coloured chip, the name, its PP
def move_row(o, c, x, y, w, mv)
  name, pp, max, t = mv
  P2.ui.rbox(o, x, y + 3, x + 4, y + 13, 1, tcol(t))
  P2.text(o, x + 9, y, w - 50, 16, name, c[:txt], PF::TEXT)
  P2.text(o, x + w - 40, y + 2, 40, 12, "#{pp}/#{max}", pp < max ? AMBER_T : c[:dim], PF::TINY, 1)
end

MAIN_HINTS = [[:ud, "Choose"], [A_PAD, "Options"], [X_PAD, "Switch"], [Y_PAD, "Summary"], [B_PAD, "Close"]]
