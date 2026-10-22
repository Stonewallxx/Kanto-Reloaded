# encoding: utf-8
# Mockups: Battle Sandbox (topic 35), screen 3: Load a Trainer or Wild Table.
# Real data from KIF Beta (trainers.dat, trainers_remix.dat, encounters.dat):
# Gym Leaders' first teams (fusions: HEAD.BODY), and Route 24's wild table.
# A trainer comes in Classic, Remix or Expert, as the first battle or the
# rematch. A wild table is used as it is (the seed rolls each encounter) or
# one slot is picked.
# Each design is a pair: a trainer (left), a wild table (right).
# Design 1 = the Settings layout, like the chosen Setup Screen.
# Usage (from this folder): ruby lt_designs.rb "<KIF Beta>" <work dir with metrics.json>
BSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "bs_designs.rb"), :encoding => "UTF-8")
eval(BSRC.split("c = palette(2)\n")[0], binding, "bs_designs.rb")

# Remix, first battle (trainers_remix.dat, version 0)
LEADERS = [["Brock", "Pewter City", [["ARON.PSYDUCK", 9], ["STEELIX.MIMEJR", 12]]],
           ["Misty", "Cerulean City", [["FOMANTIS.AMAURA", 19, "None"], ["FROSLASS.LAPRAS", 22, "Oran Berry"]]],
           ["Lt. Surge", "Vermilion City", [["KOFFING.BRELOOM", 24], ["FLAAFFY.SCRAFTY", 24], ["HOUNDOOM.GALLADE", 26]]],
           ["Erika", "Celadon City", [["SCIZOR.BELLOSSOM", 33], ["SCOLIPEDE.VAPOREON", 33], ["VOLCARONA.GOLEM", 35]]],
           ["Koga", "Fuchsia City", [["GOLISOPOD.GRENINJA", 36], ["MIMIKYU.ZOROARK", 35], ["WEEZING.UMBREON", 36], ["HONCHKROW.ELECTIVIRE", 38]]]]
# Route 24 (map 8), encounters.dat
R24 = { "Land" => [["ABRA", 20, "8-12"], ["CATERPIE", 15, "7"], ["PIDGEY", 15, "11-13"], ["WEEDLE", 15, "7"], ["ODDISH", 13, "12-14"], ["BELLSPROUT", 12, "12-14"], ["KAKUNA", 5, "8"], ["METAPOD", 5, "8"]],
        "Water" => [["PSYDUCK", 50, "20-40"], ["SLOWPOKE", 50, "20-40"]],
        "Super Rod" => [["POLIWAG", 45, "15-25"], ["POLIWHIRL", 30, "20-30"], ["GYARADOS", 15, "15-25"], ["PSYDUCK", 5, "15-35"], ["SLOWPOKE", 5, "15-35"]] }
PLACES = [["Route 24", "Land, Water, Fishing"], ["Mt. Moon", "Cave, Rock Smash"], ["Viridian Forest", "Morning, Day, Night"], ["Route 1", "Morning, Day, Night"]]
def cap(s); s.split(".").map { |x| x.capitalize.sub("Mimejr", "Mime Jr.") }.join("/"); end
def lt_frame(c, left = nil, right = nil); bs_frame(c, left, right); end
def icons_row(t, team, x, cy, size = 26, step = 28); team.each_with_index { |m, k| mon(t, m[0], x + k * step, cy, size) }; end
def table_icons(t, c, x, y, slots, step = 38)
  slots.each_with_index do |(sp, pct, lv), k|
    mon(t, sp, x + k * step + 14, y + 14, 28)
    P.text(t, x + k * step - 2, y + 28, 34, 14, "#{pct}%", c[:txt], PF::TINY, 2)
  end
end
CATS = [["Gym Leaders", [210, 80, 80]], ["Elite Four", [160, 110, 200]], ["Rivals", [96, 160, 232]], ["Route Trainers", [90, 170, 100]], ["Wild Tables", [60, 170, 160]], ["Recent", [230, 180, 60]]]
def cats_side(c, sel)
  t = TOP.bitmap
  UI.rbox(BASE.bitmap, 6, 36, 174, 262, 6, c[:panel])
  CATS.each_with_index do |(l, rgb), i|
    y = 40 + i * 22
    UI.rbox(t, 14, y + 3, 28, y + 17, 3, Color.new(*rgb)); P.glyph(t, 14, y + 3, 15, 15, l[0], Color.new(248, 248, 248))
    P.text(t, 33, y + 2, 136, 18, l, i == sel ? c[:white] : c[:dim])
  end
end
D_MISTY = ["Misty (Remix)", "First battle: Fomantis/Amaura Lv. 19, Froslass/Lapras Lv. 22 holding an Oran Berry. A loads it as the other side; it can still be edited.", ["CERULEAN GYM"]]

c = palette(2)

#================================================================ LT1 Recommended: the Settings layout; kinds as sections, Mode and Battle rows, then the trainers
def lt1(c, wild)
  lt_frame(c); cats_side(c, wild ? 4 : 0); boxes(c)
  t = TOP.bitmap
  if wild
    P.heading(t, 190, W - 16, 43, "Wild Tables", c[:head], c[:line])
    PLACES.each_with_index do |(n, kinds), i|
      y = 56 + i * 30
      cursor_at(184, y, W - 194, 28) if i == 0
      P.text(t, 196, y + 2, 170, 24, n, c[:opt], PF::TEXT)
      P.small(t, 330, y + 6, 166, 16, kinds, c[:dim], 1)
    end
    P.text(t, 196, 210, 200, 22, "Use", c[:opt], PF::TEXT); value_cell(t, c, W - 76, 210, "Whole Table", false)
    P.text(t, 196, 234, 200, 22, "Method", c[:opt], PF::TEXT); value_cell(t, c, W - 76, 234, "Land", false)
    P.text(t, 14, 269, 330, 26, "Route 24: Land", c[:head], PF::ROW)
    table_icons(t, c, 14, 294, R24["Land"], 60)
    hints(c, [[:ud, "Select"], [A_BTN, "Load"], [B_BTN, "Sections"]])
  else
    P.heading(t, 190, W - 16, 43, "Gym Leaders", c[:head], c[:line])
    [["Mode", "Remix"], ["Battle", "First"]].each_with_index do |(l, v), i|
      y = 56 + i * 24
      P.text(t, 196, y, 200, 22, l, c[:opt], PF::TEXT); value_cell(t, c, W - 76, y, v, false)
    end
    t.fill_rect(190, 106, W - 206, 1, c[:line])
    LEADERS.each_with_index do |(n, place, team), i|
      y = 110 + i * 30
      cursor_at(184, y, W - 194, 28) if i == 1
      P.text(t, 196, y + 2, 100, 24, n, c[:opt], PF::TEXT)
      icons_row(t, team, 312, y + 14)
    end
    desc_box(c, *D_MISTY)
    hints(c, [[:ud, "Select"], [:lr, "Change"], [A_BTN, "Load"], [B_BTN, "Sections"]])
  end
end
lt1(c, false); dump_as("LT1_trainer")
lt1(c, true); dump_as("LT1_wild")

#================================================================ LT2: search; type straight into the field, results grouped
def lt2(c, wild)
  lt_frame(c)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 8, 38, W - 8, 64, 6, c[:dark], c[:selb])
  magnifier(b, 20, c[:dim], c[:dark]) rescue nil
  q = wild ? "route 24" : "misty"
  P.text(t, 40, 39, 300, 24, q, c[:white], PF::TEXT)
  t.fill_rect(40 + P.width(PF::TEXT, q) + 2, 43, 2, 16, c[:white])
  P.small(t, W - 200, 43, 186, 16, "A: Naming Screen", c[:dim], 2)
  UI.rbox(b, 6, 70, W - 6, 262, 6, c[:panel])
  if wild
    P.heading(t, 16, W - 16, 74, "Wild: Route 24", c[:head], c[:line])
    R24.each_with_index do |(meth, slots), i|
      y = 92 + i * 56
      cursor_at(10, y, W - 20, 54) if i == 0
      P.text(t, 20, y + 2, 120, 20, meth, c[:opt], PF::TEXT)
      table_icons(t, c, 130, y + 4, slots.first(8), 46)
    end
    desc_box(c, "Route 24: Land", "Abra 20% (Lv. 8-12), Caterpie, Pidgey and Weedle 15%, Oddish 13%, Bellsprout 12%, Kakuna and Metapod 5%. The seed rolls each encounter.")
  else
    P.heading(t, 16, W - 16, 74, "Trainers", c[:head], c[:line])
    [["Misty", "Remix, First", LEADERS[1][2]], ["Misty", "Classic, First", [["JIGGLYPUFF.GOLDEEN", 19], ["ODDISH.STARYU", 22]]],
     ["Misty", "Remix, Rematch", [["AURORUS.LAPRAS", 69], ["JYNX.FROSLASS", 70], ["CHANDELURE.WEAVILE", 71], ["GLACEON.LOPUNNY", 68]]], ["Misty", "Classic, Rematch", [["WIGGLYTUFF.SEAKING", 68], ["KINGLER.QUAGSIRE", 68], ["STARMIE.SPIRITOMB", 71], ["FERALIGATR.LAPRAS", 70]]]].each_with_index do |(n, ver, team), i|
      y = 92 + i * 34
      cursor_at(10, y, W - 20, 32) if i == 0
      P.text(t, 20, y + 4, 90, 24, n, c[:opt], PF::TEXT)
      P.small(t, 100, y + 8, 160, 16, ver, c[:dim])
      icons_row(t, team, 300, y + 16, 28, 32)
    end
    desc_box(c, *D_MISTY)
  end
  hints(c, [[:ud, "Select"], [A_BTN, "Load"], [Y_BTN, "Naming Screen"], [B_BTN, "Back"]])
end
lt2(c, false); dump_as("LT2_trainer")
lt2(c, true); dump_as("LT2_wild")

#================================================================ LT3: the Town Map; move to a place, its trainers and wild tables beside it
def lt3(c, wild)
  frame(c); OVER.bitmap.clear
  MAPS.bitmap = Bitmap.new(W, H)
  MAPS.bitmap.blt(0, 0, bmp(File.join(HERE, "lt_map.png")), Rect.new(0, 0, W, H))
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 0))
  UI.rbox(b, 6, 30, 236, 350, 8, Color.new(c[:panel2].red, c[:panel2].green, c[:panel2].blue, 245), c[:selb])
  P.text(t, 16, 32, 210, 24, "Cerulean City", c[:head], PF::ROW)
  rows = [["Misty", "Gym Leader", LEADERS[1][2]], ["Route 24", "Wild, Land", R24["Land"]], ["Route 24", "Wild, Water", R24["Water"]],
          ["Route 24", "Wild, Super Rod", R24["Super Rod"]]]
  sel = wild ? 1 : 0
  rows.each_with_index do |(n, kind, team), i|
    y = 60 + i * 44
    UI.rbox(b, 10, y, 232, y + 40, 5, c[:sel], c[:selb]) if i == sel
    P.text(t, 18, y + 1, 130, 20, n, c[:opt], PF::TEXT)
    P.small(t, 18, y + 21, 110, 14, kind, c[:dim])
    icons_row(t, team.first(3), 150, y + 20, 26, 26)
  end
  if wild
    b.fill_rect(14, 240, 214, 1, c[:line])
    P.small(t, 16, 246, 210, 14, "LAND", c[:dim])
    table_icons(t, c, 16, 262, R24["Land"].first(5), 42)
  else
    b.fill_rect(14, 240, 214, 1, c[:line])
    P.small_wrap(t, "Remix, first battle. Fomantis/Amaura Lv. 19, Froslass/Lapras Lv. 22.", 210).each_with_index { |ln, k| P.small(t, 16, 246 + k * 16, 214, 16, ln, c[:txt]) }
  end
  BASE.bitmap.fill_rect(0, H - 28, W, 28, c[:bg])
  hints(c, [[:ud, "Move"], [A_BTN, "Choose"], ["p:9", ""], ["p:10", "Mode: Remix"], [B_BTN, "Back"]])
end
lt3(c, false); dump_as("LT3_trainer")
lt3(c, true); dump_as("LT3_wild")

#================================================================ LT4: a list on the left, a big team preview on the right; Classic, Remix, Expert tabs
def lt4(c, wild)
  lt_frame(c)
  b = BASE.bitmap; t = TOP.bitmap
  ["CLASSIC", "REMIX", "EXPERT"].each_with_index do |n, i|
    x = 8 + i * 63
    on = i == 1 && !wild
    UI.rbox(b, x, 38, x + 59, 56, 5, on ? c[:sel] : c[:dark], on ? c[:selb] : c[:line])
    P.text(t, x, 39, 59, 16, n, on ? c[:white] : c[:dim], PF::TINY, 2)
  end
  UI.rbox(b, 6, 62, 196, 262, 6, c[:panel])
  list = wild ? PLACES.map { |p| p[0] } : LEADERS.map { |l| l[0] }
  list.each_with_index do |n, i|
    y = 66 + i * 26
    cursor_at(9, y, 184, 24) if i == (wild ? 0 : 1)
    P.text(t, 18, y, 170, 24, n, c[:opt], PF::TEXT)
  end
  UI.rbox(b, 202, 38, W - 6, 262, 6, c[:panel2], c[:line])
  if wild
    P.text(t, 212, 40, 280, 24, "Route 24", c[:head], PF::ROW)
    R24["Land"].each_with_index do |(sp, pct, lv), k|
      x = 216 + (k % 4) * 72; y = 70 + (k / 4) * 84
      mon(t, sp, x + 30, y + 26, 48)
      P.text(t, x, y + 50, 64, 16, "#{pct}%", c[:txt], PF::TEXT, 2)
      P.small(t, x, y + 64, 64, 14, lv, c[:dim], 2)
    end
    desc_box(c, "Land", "Used as a whole table, the seed rolls each encounter; or A on one picks just that Pokémon.")
  else
    P.text(t, 212, 40, 280, 24, "Misty", c[:head], PF::ROW)
    P.small(t, 212, 64, 280, 16, "Cerulean Gym, Remix, first battle", c[:dim])
    LEADERS[1][2].each_with_index do |(sp, lv, item), k|
      x = 220 + k * 140
      mon(t, sp, x + 50, 140, 84)
      P.small(t, x - 10, 186, 120, 16, cap(sp), c[:opt], 2)
      P.small(t, x - 10, 204, 120, 16, "Lv. #{lv}", c[:dim], 2)
      P.small(t, x - 10, 220, 120, 16, item, c[:dim], 2)
    end
    desc_box(c, *D_MISTY)
  end
  hints(c, [["p:9", ""], ["p:10", "Mode"], [:ud, "Select"], [X_BTN, "First/Rematch"], [A_BTN, "Load"], [B_BTN, "Back"]])
end
lt4(c, false); dump_as("LT4_trainer")
lt4(c, true); dump_as("LT4_wild")

#================================================================ LT5: Recent and Starred first; Browse below
def lt5(c, starred_tab)
  lt_frame(c)
  b = BASE.bitmap; t = TOP.bitmap
  ["RECENT", "STARRED", "BROWSE"].each_with_index do |n, i|
    x = 8 + i * 84
    on = i == (starred_tab ? 1 : 0)
    UI.rbox(b, x, 38, x + 80, 56, 5, on ? c[:sel] : c[:dark], on ? c[:selb] : c[:line])
    P.text(t, x, 39, 80, 16, n, on ? c[:white] : c[:dim], PF::TINY, 2)
  end
  UI.rbox(b, 6, 62, W - 6, 262, 6, c[:panel])
  items = starred_tab ? [["Misty", "Remix, First", LEADERS[1][2], true], ["Route 24", "Wild, Super Rod", R24["Super Rod"].first(4), true], ["Giovanni", "Remix, Rematch", [["SABLEYE.SMEARGLE", 0], ["DITTO.PERSIAN", 0], ["SNORLAX.NIDOKING", 0]], true]] :
                        [["Misty", "Remix, First", LEADERS[1][2], true], ["Route 24", "Wild, Land", R24["Land"].first(4), false], ["Brock", "Classic, First", [["GEODUDE.PIDGEY", 9], ["DIGLETT.ONIX", 12]], false], ["Mt. Moon", "Wild, Cave", [["ZUBAT", 0], ["GEODUDE", 0], ["PARAS", 0], ["CLEFFA", 0]], false]]
  items.each_with_index do |(n, kind, team, star), i|
    y = 68 + i * 46
    cursor_at(10, y, W - 20, 44) if i == (starred_tab ? 1 : 0)
    P.text(t, 30, y + 2, 160, 22, n, c[:opt], PF::TEXT)
    P.small(t, 30, y + 24, 200, 16, kind, c[:dim])
    t.fill_rect(16, y + 10, 6, 6, GOLD) if star
    icons_row(t, team, 300, y + 22, 30, 36)
  end
  if starred_tab
    desc_box(c, "Route 24: Super Rod", "Poliwag 45%, Poliwhirl 30%, Gyarados 15%, Psyduck and Slowpoke 5%. Starred with Y.")
  else
    desc_box(c, *D_MISTY)
  end
  hints(c, [["p:9", ""], ["p:10", "Tabs"], [:ud, "Select"], [A_BTN, "Load"], [Y_BTN, "Star"], [B_BTN, "Back"]])
end
lt5(c, false); dump_as("LT5_recent")
lt5(c, true); dump_as("LT5_starred")

#================================================================ LTX mix (his ask): design 1 with search; the Settings layout's Search box at the top left
def search_box(c, text = nil)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 8, 4, 160, 27, 5, c[:dark], text ? c[:selb] : c[:line])
  magnifier(b, 16, 9, text ? c[:txt] : c[:dim], c[:dark])
  if text
    P.text(t, 32, 4, 120, 23, text, c[:white])
    t.fill_rect(32 + P.width(PF::TEXT, text) + 1, 8, 2, 15, c[:white])
  else
    P.text(t, 32, 4, 120, 23, "Search", c[:dim])
  end
end
def ltx(c, searching)
  if searching
    lt_frame(c); search_box(c, "misty"); cats_side(c, -1); boxes(c)
    t = TOP.bitmap
    P.heading(t, 190, W - 16, 43, "Results: Trainers", c[:head], c[:line])
    [["Misty", "Remix, First", LEADERS[1][2]], ["Misty", "Classic, First", [["JIGGLYPUFF.GOLDEEN", 19], ["ODDISH.STARYU", 22]]],
     ["Misty", "Remix, Rematch", [["AURORUS.LAPRAS", 69], ["JYNX.FROSLASS", 70], ["CHANDELURE.WEAVILE", 71]]], ["Misty", "Classic, Rematch", [["WIGGLYTUFF.SEAKING", 68], ["KINGLER.QUAGSIRE", 68], ["STARMIE.SPIRITOMB", 71]]]].each_with_index do |(n, ver, team), i|
      y = 58 + i * 34
      cursor_at(184, y, W - 194, 32) if i == 0
      P.text(t, 196, y + 1, 90, 20, n, c[:opt], PF::TEXT)
      P.small(t, 196, y + 18, 120, 14, ver, c[:dim])
      icons_row(t, team, 340, y + 16, 26, 28)
    end
    desc_box(c, *D_MISTY)
    hints(c, [[:ud, "Select"], [A_BTN, "Load"], [Y_BTN, "Naming Screen"], [B_BTN, "Clear Search"]])
  else
    lt1(c, false); search_box(c)
    BASE.bitmap.fill_rect(0, H - 28, W, 28, c[:bg]); TOP.bitmap.fill_rect(0, H - 28, W, 28, Color.new(0, 0, 0, 0))
    hints(c, [["p:9", "Search"], [:ud, "Select"], [:lr, "Change"], [A_BTN, "Load"], [B_BTN, "Sections"]])
  end
end
ltx(c, false); dump_as("LTX_browse")
ltx(c, true); dump_as("LTX_search")
