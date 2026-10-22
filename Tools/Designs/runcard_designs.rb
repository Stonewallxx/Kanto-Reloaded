# encoding: utf-8
# Mockups: New Game Setup, part 4: the Run Card. Five designs, each two
# screens: the summary before starting (mode, difficulty, dex, randomizer,
# rules, seed, the share code) with Start / Save as Preset / Edit, then
# saving it as a preset (named, typed straight in). The card is kept for the
# Trainer Card's Run Tags.
# Design 1 = the chosen layout beside Oak.
# Usage (from this folder): ruby runcard_designs.rb "<KIF Beta>" <work dir with metrics.json>
CCSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "charcreate_designs.rb"), :encoding => "UTF-8")
eval(CCSRC.split("c = palette(2)\n")[0], binding, "charcreate_designs.rb")

TAGS = [["RANDOMIZED", Color.new(240, 170, 60)], ["HARD", AMBER], ["EXPANDED", BLUE2]]
FACTS = [["Trainer", "Red, 14"], ["IVs", "Strong (20-31)"], ["Starters", "Johto"], ["Money", "$3,000, 1x"], ["Autosave", "On"], ["Seed", "7F3A91C2"]]
def tags(t, x, y, gap = 6)
  TAGS.each { |s, colr| x += pill_tag(t, x, y, s, colr, false) + gap }
end
def buttons(c, b, t, x, y, w, labels, sel)
  bw = (w - (labels.length - 1) * 6) / labels.length
  labels.each_with_index do |l, i|
    bx = x + i * (bw + 6)
    UI.rbox(b, bx, y, bx + bw, y + 26, 6, i == sel ? c[:sel] : c[:dark], i == sel ? c[:selb] : c[:line])
    P.text(t, bx, y + 2, bw, 22, l, i == sel ? c[:white] : c[:txt], PF::TEXT, 2)
  end
end
def save_preset(c, x, y, w)
  d = DIMMER.bitmap; o = OVER.bitmap
  d.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 120))
  UI.rbox(d, x, y, x + w, y + 150, 8, col(c[:panel], 255), c[:selb])
  P.text(o, x, y + 6, w, 22, "Save as Preset", c[:title], PF::ROW, 2)
  UI.rbox(d, x + 20, y + 40, x + w - 20, y + 68, 6, c[:dark], c[:selb])
  P.text(o, x + 28, y + 42, w - 56, 24, "Randomizer Hard", c[:white], PF::ROW)
  o.fill_rect(x + 30 + P.width(PF::ROW, "Randomizer Hard"), y + 46, 2, 18, c[:white])
  P.small(o, x, y + 76, w, 16, "Slot 6 of 12. Shows under From a Preset.", c[:dim], 2)
  UI.rbox(d, x + w / 2 - 60, y + 108, x + w / 2 + 60, y + 134, 6, c[:sel], c[:selb]); P.text(o, x + w / 2 - 60, y + 110, 120, 22, "Save", c[:white], PF::TEXT, 2)
end
H_RC = [[:lr, "Choose"], [A_BTN, "OK"], [X_BTN, "Copy Code"], [B_BTN, "Edit"]]

c = palette(2)

#================================================================ RC1 Recommended: beside Oak (the chosen layout)
def rc1(c)
  intro(c)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 196, 8, 504, 350, 8, col(c[:panel], 245), GOLD)
  P.text(t, 196, 12, 308, 24, "Your Run", GOLD, PF::ROW, 2)
  tags(t, 210, 40)
  FACTS.each_with_index do |(l, v), i|
    y = 64 + i * 24
    P.text(t, 214, y, 120, 22, l, c[:dim], PF::TEXT); P.text(t, 330, y, 160, 22, v, c[:txt], PF::TEXT, 1)
  end
  b.fill_rect(206, 214, 288, 1, c[:line])
  P.small(t, 196, 220, 308, 16, "Share Code", c[:dim], 2)
  UI.rbox(b, 216, 238, 484, 266, 6, c[:dark], c[:line]); P.text(t, 216, 240, 268, 24, CODE, c[:white], PF::ROW, 2)
  buttons(c, b, t, 210, 280, 280, ["Start", "Save Preset"], 0)
  P.small(t, 196, 316, 308, 16, "Kept on your Trainer Card's Run Tags.", c[:dim], 2)
  hints(c, H_RC)
end
rc1(c); shot("RC1_card")
rc1(c); save_preset(c, 86, 100, 340); shot("RC1_save")

#================================================================ RC2: the Trainer Card front (Lanyard ID), filled with the run
def rc2(c)
  frame(c); clear_over
  MAPS.bitmap = Bitmap.new(W, H)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, H, Color.new(40, 90, 150))
  UI.rbox(b, 30, 16, 482, 300, 14, Color.new(235, 240, 248), Color.new(255, 255, 255))
  UI.rbox(b, 30, 16, 482, 56, 14, Color.new(200, 60, 60))
  P.text(t, 30, 24, 452, 26, "RUN CARD", Color.new(255, 255, 255), PF::ROW, 2)
  UI.rbox(b, 50, 70, 180, 250, 8, Color.new(210, 220, 236), Color.new(150, 160, 180))
  trainer(t, 115, 248, 150)
  tags(t, 196, 72)
  FACTS.each_with_index do |(l, v), i|
    y = 96 + i * 24
    P.text(t, 196, y, 100, 22, l, Color.new(60, 70, 90), PF::TEXT); P.text(t, 300, y, 166, 22, v, Color.new(20, 24, 32), PF::TEXT, 1)
  end
  P.text(t, 196, 250, 270, 22, CODE, Color.new(40, 110, 200), PF::TEXT, 2)
  buttons(c, b, t, 30, 312, 452, ["Start", "Save Preset", "Edit"], 0)
  hints(c, H_RC)
end
rc2(c); shot("RC2_card")
rc2(c); save_preset(c, 86, 100, 340); shot("RC2_save")

#================================================================ RC3: a ticket (journey pass) with a tear-off share code stub
def rc3(c)
  intro(c)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, H, Color.new(10, 14, 24, 150))
  UI.rbox(b, 20, 60, 380, 280, 12, Color.new(245, 238, 220), Color.new(200, 180, 140))
  UI.rbox(b, 384, 60, 492, 280, 12, Color.new(245, 238, 220), Color.new(200, 180, 140))
  12.times { |k| b.fill_rect(381, 68 + k * 18, 2, 10, Color.new(160, 140, 110)) }
  P.text(t, 20, 70, 360, 26, "Kanto Journey Pass", Color.new(120, 60, 40), PF::ROW, 2)
  tags(t, 40, 100)
  FACTS.each_with_index do |(l, v), i|
    x = 40 + (i % 2) * 170; y = 128 + (i / 2) * 44
    P.small(t, x, y, 160, 16, l, Color.new(140, 110, 80)); P.text(t, x, y + 14, 160, 22, v, Color.new(40, 30, 24), PF::TEXT)
  end
  P.small(t, 384, 80, 108, 16, "SHARE", Color.new(140, 110, 80), 2)
  CODE.split("-").each_with_index { |p, k| P.text(t, 384, 104 + k * 34, 108, 26, p, Color.new(40, 30, 24), PF::ROW, 2) }
  buttons(c, b, t, 20, 300, 472, ["Start", "Save Preset", "Edit"], 0)
  hints(c, H_RC)
end
rc3(c); shot("RC3_card")
rc3(c); save_preset(c, 86, 100, 340); shot("RC3_save")

#================================================================ RC4: Oak reads it out (message), the card beside him
def rc4(c, saving)
  intro(c)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 220, 12, 500, 270, 10, col(c[:panel], 250), GOLD)
  P.text(t, 220, 18, 280, 24, "Your Run", GOLD, PF::ROW, 2)
  tags(t, 236, 46)
  FACTS.each_with_index do |(l, v), i|
    y = 72 + i * 22
    P.small(t, 238, y, 90, 16, l, c[:dim]); P.small(t, 330, y, 158, 16, v, c[:txt], 1)
  end
  P.text(t, 220, 214, 280, 22, CODE, c[:white], PF::TEXT, 2)
  UI.rbox(b, 8, 290, W - 8, 354, 8, col(c[:panel], 250), c[:line])
  P.text(t, 22, 296, W - 44, 24, "OAK: A Randomized, Hard journey with", c[:txt], PF::ROW)
  P.text(t, 22, 322, W - 44, 24, "Pokémon from far away. Ready, Red?", c[:txt], PF::ROW)
  UI.rbox(b, 20, 180, 200, 270, 8, col(c[:panel], 250), c[:line])
  ["Let's Go!", "Save as Preset", "Change Something"].each_with_index do |s, i|
    y = 186 + i * 28
    cursor_at(26, y, 168, 26) if i == 0
    P.text(t, 38, y + 1, 150, 24, s, c[:txt], PF::TEXT)
  end
  save_preset(c, 86, 100, 340) if saving
end
rc4(c, false); shot("RC4_card")
rc4(c, true); shot("RC4_save")

#================================================================ RC5: a checklist with an Edit jump per section
SECTIONS5 = [["Game Mode", "Randomized", "Preset: Randomizer Run"], ["Trainer", "Red, 14", "Male, Type A, Dark Brown"],
             ["Run Setup", "Hard, Expanded", "IVs Strong, Johto, $3,000"], ["Randomizer", "Seed 7F3A91C2", "Trainers, wilds, items"],
             ["Per-Save Settings", "4 changed", "Quick Throw, Wild Link..."]]
def rc5(c)
  frame(c); clear_over
  MAPS.bitmap = Bitmap.new(W, H)
  b = BASE.bitmap; t = TOP.bitmap
  P.text(t, 0, 4, W, 24, "Ready to Start?", c[:title], PF::ROW, 2)
  SECTIONS5.each_with_index do |(n, v, sub), i|
    y = 34 + i * 50
    UI.rbox(b, 8, y, 504, y + 46, 8, c[:panel], c[:line])
    cursor_at(10, y + 2, 492, 42) if i == 2
    UI.rbox(b, 18, y + 15, 34, y + 31, 8, GREEN)
    P.text(t, 44, y + 2, 180, 22, n, c[:txt], PF::TEXT); P.small(t, 44, y + 24, 240, 16, sub, c[:dim])
    P.text(t, 280, y + 10, 160, 24, v, c[:opt], PF::TEXT, 1)
    P.pill(t, 494, y + 15, "EDIT", c[:pill], c[:txt])
  end
  UI.rbox(b, 8, 290, 504, 320, 6, c[:dark], c[:line]); P.text(t, 8, 293, 496, 24, "Share Code  #{CODE}", c[:white], PF::TEXT, 2)
  hints(c, [[:ud, "Choose"], [A_BTN, "Edit"], [X_BTN, "Save Preset"], [Y_BTN, "Start"], [B_BTN, "Back"]])
end
rc5(c); shot("RC5_card")
rc5(c); save_preset(c, 86, 100, 340); shot("RC5_save")
