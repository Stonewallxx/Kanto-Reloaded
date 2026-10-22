# encoding: utf-8
# Mockups: Randomizer (topic 31), the unified Randomizer that takes over
# cody's screens (his engine, seed, presets, spoiler log and Entrances stay
# underneath; KR's parts join in). Five layouts, each two screens: the
# overview (what's on, the seed, Randomize Now) and one page (Pokémon data,
# with KR's Learnsets, Per Pokémon abilities).
# Design 1 = the improved Settings layout (pages as sections, an Overview
# section first).
# Usage (from this folder): ruby randu_designs.rb "<KIF Beta>" <work dir with metrics.json>
RSSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "runsetup_designs.rb"), :encoding => "UTF-8")
eval(RSSRC.split("rs1(c, 0); shot(\"RS1_setup\")")[0], binding, "runsetup_designs.rb")

PAGES = [["Overview", [214, 52, 60]], ["Pokémon", [90, 170, 100]], ["Trainers", [210, 80, 80]], ["Gyms", [230, 180, 60]], ["Items", [96, 160, 232]],
         ["Pokémon Data", [90, 170, 100]], ["Evolutions", [90, 170, 100]], ["Exclusions", [130, 140, 155]], ["Entrances", [60, 170, 160]], ["Seed", [180, 120, 220]]]
STATUS = [["Pokémon", "Swap", true], ["Trainers", "Random", true], ["Gyms", "Off", false], ["Items", "Mapped", true],
          ["Pokémon Data", "Custom", true], ["Evolutions", "Off", false], ["Exclusions", "49 Items", true], ["Entrances", "Off", false]]
DATA = [["Types", "Same"], ["Original Type", "Allowed"], ["Moves Follow Type", "Off"], ["Learnsets", "Random"], ["TMs Follow Type", "Off"],
        ["Abilities", "Per Pokémon"], ["No Self-Harm", "On"], ["Base Stats", "Same"]]
SEED = "K7Q2-9XMA"
def uframe(c, sec)
  frame(c); clear_over
  MAPS.bitmap = Bitmap.new(W, H)
  settings_frame(c, PAGES, sec)
  t = TOP.bitmap
  t.fill_rect(130, 2, 252, 28, CLEAR); P.text(t, 130, 2, 252, 28, "Randomizer", c[:title], PF::TITLE, 2)
end
def onoff_dot(b, x, y, on); UI.rbox(b, x, y, x + 9, y + 9, 4, on ? GREEN : Color.new(90, 96, 110)); end
def randomize_btn(c, b, t, x, y, w, changed = 3)
  UI.rbox(b, x, y, x + w, y + 28, 6, Color.new(70, 46, 14), AMBER)
  P.text(t, x, y + 2, w, 24, "Randomize Now (#{changed} Changed)", AMBER, PF::TEXT, 2)
end
DESC_LS = "Learnsets: level-up moves fully random, same levels, similar power."

c = palette(2)

#================================================================ RU1 Recommended: the Settings layout with an Overview section
uframe(c, 0)
b = BASE.bitmap; t = TOP.bitmap
P.heading(t, 190, W - 16, 43, "Overview", c[:head], c[:line])
STATUS.each_with_index do |(l, v, on), i|
  y = 54 + i * 25
  cursor_at(184, y, W - 194, 22) if i == 4
  onoff_dot(b, 196, y + 7, on)
  P.text(t, 212, y, 170, 22, l, c[:opt], PF::TEXT)
  P.text(t, 330, y, 160, 22, v, on ? c[:txt] : c[:dim], PF::TEXT, 1)
end
desc_box(c, "Seed #{SEED}", "Every part at a glance. A opens a part; changes wait for Randomize Now.")
hints(c, [[:ud, "Select"], [A_BTN, "Open"], [Y_BTN, "Randomize Now"], [B_BTN, "Sections"]])
dump_as("RU1_overview")
uframe(c, 5)
b = BASE.bitmap; t = TOP.bitmap
P.heading(t, 190, W - 16, 43, "Pokémon Data", c[:head], c[:line])
DATA.each_with_index do |(l, v), i|
  y = 54 + i * 25
  cursor_at(184, y, W - 194, 24) if i == 3
  P.text(t, 196, y, 200, 24, l, c[:opt], PF::ROW)
  t.fill_rect(196 + P.width(PF::ROW, l) + 4, y + 6, 4, 4, AMBER) if ["Learnsets", "Abilities"].include?(l)
  value_cell(t, c, W - 66, y, v, i == 3)
end
desc_box(c, "Learnsets", "Level-up moves are fully random: same levels, similar power. Fusions follow.")
hints(c, [[:ud, "Select"], [:lr, "Change"], [Y_BTN, "Randomize Now"], [B_BTN, "Sections"]])
dump_as("RU1_page")

#================================================================ RU2: a dashboard of part tiles (3 x 3, Seed and Sharing last); a tile opens its page
TILES = STATUS + [["Seed", SEED, true]]
def tile_dash(c)
  frame(c); clear_over
  MAPS.bitmap = Bitmap.new(W, H)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, 32, c[:panel2]); b.fill_rect(0, 31, W, 1, c[:line])
  P.text(t, 0, 2, W, 28, "Randomizer", c[:title], PF::TITLE, 2)
  TILES.each_with_index do |(l, v, on), i|
    x = 8 + (i % 3) * 168; y = 40 + (i / 3) * 74
    UI.rbox(b, x, y, x + 160, y + 68, 8, c[:panel], i == 4 ? c[:selb] : (on ? GREEN : c[:line]))
    cursor_at(x - 2, y - 2, 164, 72) if i == 4
    onoff_dot(b, x + 10, y + 12, on)
    P.text(t, x + 26, y + 5, 130, 22, l, c[:txt], PF::TEXT)
    P.small(t, x + 10, y + 36, 144, 16, v, on ? c[:txt] : c[:dim])
  end
  randomize_btn(c, b, t, 8, 266, 496)
  P.small(t, 8, 300, 496, 16, "Changes wait for Randomize Now.", c[:dim], 2)
  hints(c, [[:ud, ""], [:lr, "Choose"], [A_BTN, "Open"], [Y_BTN, "Randomize Now"], [B_BTN, "Back"]])
end
tile_dash(c); dump_as("RU2_overview")
frame(c); clear_over; MAPS.bitmap = Bitmap.new(W, H)
b = BASE.bitmap; t = TOP.bitmap
b.fill_rect(0, 0, W, 32, c[:panel2]); b.fill_rect(0, 31, W, 1, c[:line])
P.text(t, 0, 2, W, 28, "Pokémon Data", c[:title], PF::TITLE, 2)
UI.rbox(b, 8, 40, 504, 262, 8, c[:panel], c[:line])
DATA.each_with_index do |(l, v), i|
  y = 46 + i * 26
  cursor_at(12, y, 488, 24) if i == 3
  P.text(t, 24, y, 220, 24, l, c[:opt], PF::ROW); value_cell(t, c, W - 72, y, v, i == 3)
end
UI.rbox(b, 6, 268, W - 6, H - 30, 6, c[:panel2], c[:line])
desc_box(c, "Learnsets", "Level-up moves are fully random: same levels, similar power.")
hints(c, [[:ud, "Select"], [:lr, "Change"], [B_BTN, "Back"]])
dump_as("RU2_page")

#================================================================ RU3: tabs across the top, two-column cards
TABS3 = ["POKÉMON", "TRAINERS", "ITEMS", "DATA", "WORLD", "SEED"]
def tabs3(c, sel)
  frame(c); clear_over; MAPS.bitmap = Bitmap.new(W, H)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, 32, c[:panel2]); b.fill_rect(0, 31, W, 1, c[:line])
  P.text(t, 0, 2, W, 28, "Randomizer", c[:title], PF::TITLE, 2)
  TABS3.each_with_index do |n, i|
    x = 8 + i * 83
    UI.rbox(b, x, 38, x + 79, 56, 5, i == sel ? c[:sel] : c[:dark], i == sel ? c[:selb] : c[:line])
    P.text(t, x, 39, 79, 16, n, i == sel ? c[:white] : c[:dim], PF::TINY, 2)
  end
end
def cards3(c, rows, sel, desc)
  b = BASE.bitmap; t = TOP.bitmap
  rows.each_with_index do |(l, v), i|
    x = 8 + (i % 2) * 250; y = 64 + (i / 2) * 48
    UI.rbox(b, x, y, x + 244, y + 42, 6, c[:panel], i == sel ? c[:selb] : c[:line])
    P.small(t, x + 10, y + 4, 200, 16, l, c[:dim]); P.text(t, x + 10, y + 18, 220, 22, v, c[:txt], PF::TEXT)
  end
  P.small(t, 8, 260, 496, 16, desc, c[:txt], 2)
  randomize_btn(c, b, t, 8, 284, 496)
  hints(c, [["p:9", ""], ["p:10", "Tabs"], [:ud, ""], [:lr, "Select"], [A_BTN, "Change"], [Y_BTN, "Randomize"], [B_BTN, "Back"]])
end
tabs3(c, 0)
cards3(c, [["Wild Encounters", "Swap"], ["Starters", "1st"], ["Static", "On"], ["Gifts", "On"], ["Trades", "Swap"], ["Legendaries", "Off"], ["Expanded Dex", "In Pools"], ["Strength", "Close"]], 0,
       "Swap: each wild species becomes one other species everywhere.")
dump_as("RU3_overview")
tabs3(c, 3)
cards3(c, DATA, 3, DESC_LS)
dump_as("RU3_page")

#================================================================ RU4: no sidebar; options on the left, a live preview of the result on the right
def ru4(c, section)
  frame(c); clear_over; MAPS.bitmap = Bitmap.new(W, H)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, 32, c[:panel2]); b.fill_rect(0, 31, W, 1, c[:line])
  P.text(t, 0, 2, W, 28, "Randomizer", c[:title], PF::TITLE, 2)
  P.text(t, 10, 6, 150, 22, SEED, c[:dim], PF::TEXT)
  UI.rbox(b, 8, 38, 300, 62, 6, c[:dark], c[:line])
  UI.tri(b, 22, 50, :l, c[:selb], 5); UI.tri(b, 286, 50, :r, c[:selb], 5)
  P.text(t, 8, 39, 292, 22, section, c[:head], PF::TEXT, 2)
  UI.rbox(b, 8, 66, 300, 300, 6, c[:panel], c[:line])
  UI.rbox(b, 308, 38, 504, 300, 8, c[:panel2], GOLD)
  P.text(t, 308, 42, 196, 22, "Preview", GOLD, PF::TEXT, 2)
end
def ru4_rows(c, rows, sel)
  t = TOP.bitmap
  rows.each_with_index do |(l, v), i|
    y = 72 + i * 27
    cursor_at(12, y, 284, 24) if i == sel
    P.text(t, 20, y, 170, 24, l, c[:opt], PF::TEXT)
    value_cell(t, c, 236, y, v, i == sel)
  end
end
def icon(t, sp, cx, cy); t.stretch_blt(Rect.new(cx - 20, cy - 20, 40, 40), bmp(File.join(GFX, "Pokemon/Icons/#{sp}.png")), Rect.new(0, 0, 64, 64)); end
ru4(c, "Pokémon")
b = BASE.bitmap; t = TOP.bitmap
ru4_rows(c, [["Wild Encounters", "Swap"], ["Starters", "1st"], ["Static", "On"], ["Gifts", "On"], ["Trades", "Swap"], ["Legendaries", "Off"], ["Expanded Dex", "In Pools"], ["Strength", "Close"]], 0)
P.small(t, 318, 70, 176, 16, "Route 1 becomes", c[:dim])
[["PIDGEY", "GLIGAR"], ["RATTATA", "SNUBBULL"]].each_with_index do |(a, z), k|
  yy = 112 + k * 44
  icon(t, a, 356, yy); UI.tri(b, 406, yy, :r, c[:dim], 5); icon(t, z, 456, yy)
end
P.small(t, 318, 186, 176, 16, "Brock's Onix becomes", c[:dim])
icon(t, "STEELIX", 406, 228)
P.small(t, 8, 306, 496, 16, "Swap: each wild species becomes one other species everywhere.", c[:txt], 2)
hints(c, [["p:9", ""], ["p:10", "Sections"], [:ud, "Select"], [:lr, "Change"], [Y_BTN, "Randomize"], [B_BTN, "Back"]])
dump_as("RU4_overview")
ru4(c, "Pokémon Data")
b = BASE.bitmap; t = TOP.bitmap
ru4_rows(c, DATA, 3)
P.small(t, 318, 70, 176, 16, "Pikachu learns", c[:dim])
icon(t, "PIKACHU", 470, 82)
[["Lv. 5", "Ember"], ["Lv. 10", "Aqua Jet"], ["Lv. 13", "Dark Pulse"], ["Lv. 18", "Slam"], ["Lv. 21", "Leaf Blade"]].each_with_index do |(lv, m), k|
  P.small(t, 318, 104 + k * 20, 56, 16, lv, c[:dim]); P.small(t, 376, 104 + k * 20, 120, 16, m, c[:txt])
end
b.fill_rect(318, 210, 176, 1, c[:line])
P.small(t, 318, 218, 176, 16, "Ability: Swift Swim", c[:txt])
P.small(t, 8, 306, 496, 16, DESC_LS, c[:txt], 2)
hints(c, [["p:9", ""], ["p:10", "Sections"], [:ud, "Select"], [:lr, "Change"], [Y_BTN, "Randomize"], [B_BTN, "Back"]])
dump_as("RU4_page")

#================================================================ RU5: beside Oak (the New Game look) with a summary first
intro(c)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 196, 8, 504, 350, 8, col(c[:panel], 245), c[:line])
P.text(t, 196, 12, 308, 24, "Randomizer", c[:title], PF::ROW, 2)
P.small(t, 196, 36, 308, 16, "Seed #{SEED}", c[:dim], 2)
STATUS.each_with_index do |(l, v, on), i|
  y = 56 + i * 26
  cursor_at(200, y, 300, 24) if i == 4
  onoff_dot(b, 212, y + 8, on)
  P.text(t, 228, y, 150, 24, l, c[:opt], PF::TEXT)
  P.text(t, 330, y, 160, 24, v, on ? c[:txt] : c[:dim], PF::TEXT, 1)
end
randomize_btn(c, b, t, 210, 272, 280)
hints(c, [[:ud, "Choose"], [A_BTN, "Open"], [Y_BTN, "Randomize"], [B_BTN, "Back"]])
dump_as("RU5_overview")
intro(c)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 196, 8, 504, 350, 8, col(c[:panel], 245), c[:line])
P.text(t, 196, 12, 308, 24, "Pokémon Data", c[:title], PF::ROW, 2)
DATA.each_with_index do |(l, v), i|
  y = 40 + i * 26
  cursor_at(200, y, 300, 24) if i == 3
  P.text(t, 212, y, 170, 24, l, c[:opt], PF::TEXT)
  value_cell(t, c, 440, y, v, i == 3)
end
b.fill_rect(206, 256, 288, 1, c[:line])
P.small_wrap(t, DESC_LS, 280).each_with_index { |ln, k| P.small(t, 210, 262 + k * 17, 284, 16, ln, c[:txt]) }
hints(c, [[:ud, "Choose"], [:lr, "Change"], [B_BTN, "Back"]])
dump_as("RU5_page")

#================================================================ RUX mix: 5 when starting a run (Done; it randomizes as the run starts), 1 after the run is started (RU1_overview)
intro(c)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 196, 8, 504, 350, 8, col(c[:panel], 245), c[:line])
P.text(t, 196, 12, 308, 24, "Randomizer", c[:title], PF::ROW, 2)
P.small(t, 196, 36, 308, 16, "Seed #{SEED}", c[:dim], 2)
STATUS.each_with_index do |(l, v, on), i|
  y = 56 + i * 26
  cursor_at(200, y, 300, 24) if i == 4
  onoff_dot(b, 212, y + 8, on)
  P.text(t, 228, y, 150, 24, l, c[:opt], PF::TEXT)
  P.text(t, 330, y, 160, 24, v, on ? c[:txt] : c[:dim], PF::TEXT, 1)
end
UI.rbox(b, 270, 272, 430, 300, 6, c[:sel], c[:selb]); P.text(t, 270, 274, 160, 24, "Done", c[:white], PF::TEXT, 2)
P.small(t, 196, 306, 308, 16, "Randomized when the run starts.", c[:dim], 2)
hints(c, [[:ud, "Choose"], [A_BTN, "Open"], [B_BTN, "Back"]])
dump_as("RUX_start")
