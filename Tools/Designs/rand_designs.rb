# encoding: utf-8
# Mockups: Randomizer (topic 31), designs 3 and 4 in our kit (1, 2 and 5 are
# cody's own screen with KR's rows: rz/ via randscreen_backdrop.py).
#  3: cody's whole Randomizer shown in the improved Settings layout (when
#     Reloaded Settings is on), KR's rows tagged KR; Seed and Sharing page.
#  4: inside the New Game Run Setup (beside Oak): the Randomizer row opens a
#     quick panel with the main parts and KR's; All Options opens cody's screen.
# Usage (from this folder): ruby rand_designs.rb "<KIF Beta>" <work dir with metrics.json>
RSSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "runsetup_designs.rb"), :encoding => "UTF-8")
eval(RSSRC.split("rs1(c, 0); shot(\"RS1_setup\")")[0], binding, "runsetup_designs.rb")

RSECTIONS = [["Pokémon", [90, 170, 100]], ["Trainers", [210, 80, 80]], ["Gyms", [230, 180, 60]], ["Items", [96, 160, 232]],
             ["Pokémon Data", [90, 170, 100]], ["Evolutions", [90, 170, 100]], ["Exclusions", [130, 140, 155]], ["Entrances", [60, 170, 160]], ["Seed and Sharing", [214, 52, 60]]]
DATA_ROWS = [["Types", "Same", false], ["Original Type", "Allowed", false], ["Moves Follow Type", "Off", false], ["Learnsets", "Random", true],
             ["TMs Follow Type", "Off", false], ["Abilities", "Per Pokémon", true], ["No Self-Harm", "Off", false]]
def kr_tag(t, x, y); P.pill(t, x, y, "KR", Color.new(70, 20, 24), Color.new(240, 110, 110), false); end
def rframe(c, sec, title = "Randomizer")
  frame(c); clear_over
  MAPS.bitmap = Bitmap.new(W, H)
  settings_frame(c, RSECTIONS, sec)
  t = TOP.bitmap
  t.fill_rect(130, 2, 252, 28, CLEAR); P.text(t, 130, 2, 252, 28, title, c[:title], PF::TITLE, 2)
end

c = palette(2)

#================================================================ RD3: cody's Randomizer in the improved Settings layout; KR rows tagged
rframe(c, 4)
b = BASE.bitmap; t = TOP.bitmap
P.heading(t, 190, W - 16, 43, "Pokémon Data", c[:head], c[:line])
DATA_ROWS.each_with_index do |(l, v, kr), i|
  y = 58 + i * 26
  cursor_at(184, y, W - 194, 24) if i == 5
  P.text(t, 196, y, 200, 24, l, c[:opt], PF::ROW)
  kr_tag(t, 196 + P.width(PF::ROW, l) + 8, y + 5) if kr
  value_cell(t, c, W - 66, y, v, i == 5)
end
desc_box(c, "Abilities", "Per Pokémon (Kanto Reloaded): every Pokémon rolls its own ability. Fusions get two legal ones with Double Abilities.", ["KANTO RELOADED"])
hints(c, [[:ud, "Select"], [:lr, "Change"], [Y_BTN, "Randomize Now"], [B_BTN, "Sections"]])
dump_as("RD3_data")
rframe(c, 8)
b = BASE.bitmap; t = TOP.bitmap
P.heading(t, 190, W - 16, 43, "Seed and Sharing", c[:head], c[:line])
[["Seed", "K7Q2-9XMA"], ["Settings Code", "Copy"], ["Presets", "Open"], ["Spoiler Log", "On"], ["Expanded Dex", "In Pools"]].each_with_index do |(l, v), i|
  y = 58 + i * 26
  cursor_at(184, y, W - 194, 24) if i == 0
  P.text(t, 196, y, 200, 24, l, c[:opt], PF::ROW)
  kr_tag(t, 196 + P.width(PF::ROW, l) + 8, y + 5) if l == "Expanded Dex"
  ["Copy", "Open"].include?(v) ? P.pill(t, W - 18, y + 5, v.upcase, c[:pill], c[:txt]) : value_cell(t, c, W - 66, y, v, i == 0)
end
desc_box(c, "Seed", "The same seed and settings give the same game. A for a new seed, or type one.")
hints(c, [[:ud, "Select"], [A_BTN, "New Seed"], [Y_BTN, "Randomize Now"], [B_BTN, "Sections"]])
dump_as("RD3_seed")

#================================================================ RD4: in the New Game Run Setup, a quick panel; All Options opens cody's screen
rs1(c, 2)
d = DIMMER.bitmap; o = OVER.bitmap
d.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 120))
UI.rbox(d, 20, 24, 492, 340, 8, col(c[:panel], 255), c[:selb])
P.text(o, 20, 30, 472, 24, "Randomizer", c[:title], PF::ROW, 2)
quick = [["Wild Pokémon", "Swap", false], ["Trainers", "Random", false], ["Items", "Mapped", false], ["Types", "Same", false],
         ["Abilities", "Per Pokémon", true], ["Learnsets", "Random", true], ["Expanded Dex", "In Pools", true]]
quick.each_with_index do |(l, v, kr), i|
  y = 60 + i * 28
  UI.rbox(d, 26, y, 486, y + 26, 5, c[:sel], c[:selb]) if i == 4
  P.text(o, 40, y + 1, 200, 24, l, c[:opt], PF::ROW)
  kr_tag(o, 40 + P.width(PF::ROW, l) + 8, y + 6) if kr
  value_cell(o, c, 430, y + 1, v, i == 4)
end
d.fill_rect(30, 262, 452, 1, c[:line])
P.small(o, 40, 268, 300, 16, "Seed K7Q2-9XMA", c[:dim])
UI.rbox(d, 300, 290, 480, 318, 6, c[:dark], c[:line]); P.text(o, 300, 292, 180, 24, "All Options", c[:txt], PF::TEXT, 2)
UI.rbox(d, 40, 290, 220, 318, 6, c[:sel], c[:selb]); P.text(o, 40, 292, 180, 24, "Done", c[:white], PF::TEXT, 2)
dump_as("RD4_panel")
