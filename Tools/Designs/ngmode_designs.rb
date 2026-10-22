# encoding: utf-8
# Mockups: New Game Setup (topic 29), part 1: Game Mode and Presets. Five
# designs, each two screens: choosing how to start (KIF's modes: Classic,
# Remix, Randomized, Legendary after NG+; plus the new Setup Presets and
# Share Codes), then a preset or share code. Backdrop: Oak (the intro look
# chosen for Difficulty and the Expanded Dex switch).
# Design 1 = the chosen Difficulty layout (rows beside Oak + a details panel).
# Usage (from this folder): ruby ngmode_designs.rb "<KIF Beta>" <work dir with metrics.json>
SRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "diff_designs.rb"), :encoding => "UTF-8")
eval(SRC.split("c = palette(2)\n")[0], binding, "diff_designs.rb")

XD = File.join(HERE, "xd")
BLUE2 = Color.new(130, 190, 250); PURP = Color.new(190, 140, 240)
# [name, short, colour, details, locked]
MODES = [["Classic", "The original teams", Color.new(130, 190, 250), ["Every Pokémon available", "Trainers as PIF made them"], false],
         ["Remix", "Teams from newer generations", Color.new(120, 220, 150), ["Community-made teams", "Newer Pokémon in the wild"], false],
         ["Randomized", "Trainers, wilds, items shuffled", Color.new(240, 170, 60), ["You choose what's randomized", "Seeded, so it can be shared"], false],
         ["Legendary", "Trainers fused with legendaries", PURP, ["A legendary starter", "Unlocks after New Game+"], true]]
PRESETS = [["Classic", "Normal, every option at its default", "CLASSIC"], ["Challenge", "Hard, tougher trainer IVs", "HARD"],
           ["Casual", "Easy, party EXP, Quick Throw on", "EASY"], ["Randomizer Run", "Randomized, Expanded Dex, Hard", "RANDOM"], ["Stonewall's Run", "Saved Oct 12", "YOURS"]]
CODE = "KR1-7F3A-91C2-E04B"
def mode_dot(b, x, y, colr); UI.rbox(b, x, y, x + 10, y + 10, 5, colr); end
def lock_icon(b, x, y, colr)
  UI.rbox(b, x + 2, y, x + 9, y + 7, 3, colr); UI.rbox(b, x + 4, y + 2, x + 7, y + 7, 1, Color.new(0, 0, 0, 0))
  UI.rbox(b, x, y + 5, x + 11, y + 13, 2, colr)
end
def code_field(c, b, t, x, y, w, text, active = true)
  UI.rbox(b, x, y, x + w, y + 30, 6, c[:dark], active ? c[:selb] : c[:line])
  P.text(t, x, y + 3, w, 24, text, c[:white], PF::ROW, 2)
end
def pill_tag(t, x, y, s, colr, right = true); P.pill(t, x, y, s, Color.new(colr.red / 4, colr.green / 4, colr.blue / 4), colr, right); end

c = palette(2)

#================================================================ NM1 Recommended: rows beside Oak with a details panel (like Difficulty)
def nm1(c, sel)
  intro(c)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 252, 16, 500, 340, 8, col(c[:panel], 245), c[:line])
  P.text(t, 252, 22, 248, 24, "New Game", c[:title], PF::ROW, 2)
  MODES.each_with_index do |(n, _, colr, _, locked), i|
    y = 52 + i * 28
    cursor_at(258, y, 236, 26) if i == sel
    mode_dot(b, 268, y + 8, locked ? c[:dim] : colr)
    P.text(t, 286, y + 1, 150, 24, n, locked ? c[:dim] : c[:txt], PF::ROW)
    lock_icon(t, 474, y + 6, c[:dim]) if locked
  end
  b.fill_rect(262, 168, 228, 1, c[:line])
  [["From a Preset", "5"], ["Enter a Share Code", ""]].each_with_index do |(n, v), i|
    y = 174 + i * 28
    cursor_at(258, y, 236, 26) if sel == 4 + i
    P.text(t, 270, y + 1, 180, 24, n, c[:txt], PF::ROW)
    P.small(t, 430, y + 5, 58, 16, v, c[:dim], 1)
  end
  b.fill_rect(262, 234, 228, 1, c[:line])
  if sel < 4
    n, short, colr, det, _ = MODES[sel]
    P.small(t, 266, 240, 224, 16, short, colr)
    det.each_with_index { |s, i| bullet(b, t, c, 268, 260 + i * 18, 224, s, colr) }
  else
    P.small(t, 266, 240, 224, 16, "Every choice filled in at once.", BLUE2)
    bullet(b, t, c, 268, 260, 224, "Change anything before you start", BLUE2)
    bullet(b, t, c, 268, 278, 224, "Save your own from the Run Card", BLUE2)
  end
  hints(c, [[:ud, "Choose"], [A_BTN, "Next"], [B_BTN, "Back"]])
end
nm1(c, 0); shot("NM1_mode")
intro(c)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 192, 16, 500, 340, 8, col(c[:panel], 245), c[:line])
P.text(t, 192, 22, 308, 24, "From a Preset", c[:title], PF::ROW, 2)
PRESETS.each_with_index do |(n, d, tag), i|
  y = 52 + i * 44
  cursor_at(198, y, 296, 42) if i == 1
  P.text(t, 210, y + 1, 180, 22, n, c[:txt], PF::ROW)
  P.small(t, 210, y + 22, 280, 16, d, c[:dim])
  pill_tag(t, 488, y + 5, tag, tag == "YOURS" ? GOLD : BLUE2)
end
b.fill_rect(202, 276, 288, 1, c[:line])
P.small(t, 206, 282, 290, 16, "Next: the Run Setup, already filled in.", c[:txt])
P.small(t, 206, 300, 290, 16, "Presets use KIF's preset slots.", c[:dim])
hints(c, [[:ud, "Choose"], [A_BTN, "Use"], [X_BTN, "Delete"], [B_BTN, "Back"]])
shot("NM1_preset")

#================================================================ NM2: four mode cards, presets and code as buttons below
def nm2(c)
  intro(c)
  b = BASE.bitmap; t = TOP.bitmap
  P.text(t, 0, 6, W, 24, "How Will You Play?", Color.new(30, 50, 60), PF::ROW, 2)
  MODES.each_with_index do |(n, short, colr, det, locked), i|
    x = 10 + i * 124
    UI.rbox(b, x, 36, x + 118, 260, 10, col(c[:panel], 250), i == 2 ? GOLD : (locked ? c[:line] : colr))
    UI.rbox(b, x + 8, 44, x + 110, 66, 6, locked ? c[:dark] : colr)
    P.text(t, x, 45, 118, 22, n, locked ? c[:dim] : Color.new(20, 24, 32), PF::TEXT, 2)
    P.small_wrap(t, short, 100).each_with_index { |ln, k| P.small(t, x + 9, 74 + k * 16, 102, 16, ln, locked ? c[:dim] : c[:txt]) }
    y2 = 132
    det.each do |s|
      P.small_wrap(t, s, 100).each { |ln| P.small(t, x + 9, y2, 102, 16, ln, c[:dim]); y2 += 16 }
      y2 += 8
    end
    lock_icon(t, x + 53, 236, c[:dim]) if locked
  end
  [["From a Preset", 10], ["Share Code", 264]].each do |l, x|
    UI.rbox(b, x, 270, x + 238, 300, 8, col(c[:panel], 250), c[:line])
    P.text(t, x, 273, 238, 24, l, c[:txt], PF::ROW, 2)
  end
  hints(c, [[:lr, "Choose"], [:ud, ""], [A_BTN, "Next"], [B_BTN, "Back"]])
end
nm2(c); shot("NM2_mode")
intro(c)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 56, 70, 456, 290, 10, col(c[:panel], 250), c[:selb])
P.text(t, 56, 78, 400, 24, "Enter a Share Code", c[:title], PF::ROW, 2)
code_field(c, b, t, 86, 112, 340, CODE)
P.small(t, 56, 150, 400, 16, "Type it, or A for the naming screen.", c[:dim], 2)
b.fill_rect(70, 174, 372, 1, c[:line])
[["Mode", "Randomized"], ["Difficulty", "Hard"], ["Pokédex", "Expanded"], ["Seed", "7F3A91C2"]].each_with_index do |(l, v), i|
  x = 80 + (i % 2) * 190; y = 182 + (i / 2) * 36
  P.small(t, x, y, 90, 16, l, c[:dim]); P.text(t, x, y + 14, 170, 20, v, c[:txt], PF::TEXT)
end
P.small(t, 56, 258, 400, 16, "From Stonewall's Run.", GREEN, 2)
hints(c, [[A_BTN, "Edit"], [X_BTN, "Use"], [B_BTN, "Back"]])
shot("NM2_code")

#================================================================ NM3: Quick Start (a preset) or Custom Setup
def nm3(c, sel)
  intro(c)
  b = BASE.bitmap; t = TOP.bitmap
  P.text(t, 0, 10, W, 24, "Start Your Journey", Color.new(30, 50, 60), PF::ROW, 2)
  [["Quick Start", "Pick a preset and go", ["Classic, Challenge, Casual", "or one you saved"]], ["Custom Setup", "Choose everything yourself", ["Mode, difficulty, Pokédex,", "Randomizer and more"]]].each_with_index do |(n, s, ls), i|
    x = 40 + i * 222
    UI.rbox(b, x, 50, x + 210, 230, 10, col(c[:panel], 250), i == sel ? GOLD : c[:line])
    P.text(t, x, 66, 210, 26, n, i == sel ? GOLD : c[:txt], PF::ROW, 2)
    P.small(t, x, 96, 210, 16, s, c[:dim], 2)
    ls.each_with_index { |l, k| P.small(t, x, 140 + k * 18, 210, 16, l, c[:txt], 2) }
  end
  UI.rbox(b, 152, 246, 360, 274, 8, col(c[:panel], 250), c[:line])
  P.text(t, 152, 248, 208, 24, "Enter a Share Code", c[:txt], PF::TEXT, 2)
  hints(c, [[:lr, "Choose"], [:ud, ""], [A_BTN, "Next"], [B_BTN, "Back"]])
end
nm3(c, 1); shot("NM3_start")
intro(c)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 56, 30, 456, 330, 10, col(c[:panel], 250), GOLD)
P.text(t, 56, 36, 400, 24, "Custom Setup: Game Mode", c[:title], PF::ROW, 2)
MODES.each_with_index do |(n, short, colr, _, locked), i|
  y = 70 + i * 46
  cursor_at(64, y, 384, 44) if i == 0
  mode_dot(b, 78, y + 10, locked ? c[:dim] : colr)
  P.text(t, 96, y + 2, 200, 22, n, locked ? c[:dim] : c[:txt], PF::ROW)
  P.small(t, 96, y + 24, 340, 16, short, c[:dim])
end
P.small(t, 56, 260, 400, 16, "Step 1 of 4: Mode, Character, Run Setup, Run Card", c[:dim], 2)
hints(c, [[:ud, "Choose"], [A_BTN, "Next"], [B_BTN, "Back"]])
shot("NM3_mode")

#================================================================ NM4: tabs (Modes / Presets / Share Code) in one panel
def nm4(c, tab)
  intro(c)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 192, 16, 500, 340, 8, col(c[:panel], 245), c[:line])
  ["MODES", "PRESETS", "CODE"].each_with_index do |n, i|
    x = 200 + i * 100
    UI.rbox(b, x, 24, x + 94, 42, 5, i == tab ? c[:sel] : c[:dark], i == tab ? c[:selb] : c[:line])
    P.text(t, x, 25, 94, 16, n, i == tab ? c[:white] : c[:dim], PF::TINY, 2)
  end
  if tab == 0
    MODES.each_with_index do |(n, short, colr, _, locked), i|
      y = 54 + i * 50
      cursor_at(198, y, 296, 48) if i == 0
      mode_dot(b, 210, y + 10, locked ? c[:dim] : colr)
      P.text(t, 228, y + 2, 200, 22, n, locked ? c[:dim] : c[:txt], PF::ROW)
      P.small(t, 228, y + 24, 260, 16, short, c[:dim])
    end
  else
    PRESETS.each_with_index do |(n, d, tag), i|
      y = 54 + i * 44
      cursor_at(198, y, 296, 42) if i == 3
      P.text(t, 210, y + 1, 180, 22, n, c[:txt], PF::ROW)
      P.small(t, 210, y + 22, 280, 16, d, c[:dim])
      pill_tag(t, 488, y + 5, tag, tag == "YOURS" ? GOLD : BLUE2)
    end
  end
  hints(c, [["p:9", ""], ["p:10", "Tabs"], [:ud, "Choose"], [A_BTN, "Next"], [B_BTN, "Back"]])
end
nm4(c, 0); shot("NM4_modes")
nm4(c, 1); shot("NM4_presets")

#================================================================ NM5: PIF's own way (Oak asks in a message box), presets as one more choice
def msgbox(c, l1, l2)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 8, 290, W - 8, 354, 8, col(c[:panel], 250), c[:line])
  P.text(t, 22, 296, W - 44, 24, l1, c[:txt], PF::ROW); P.text(t, 22, 322, W - 44, 24, l2, c[:txt], PF::ROW)
end
def cmd_win(c, items, sel, x = 330, w = 170)
  b = BASE.bitmap; t = TOP.bitmap
  h = items.length * 28 + 12
  UI.rbox(b, x, 284 - h, x + w, 280, 8, col(c[:panel], 250), c[:line])
  items.each_with_index do |s, i|
    y = 290 - h + i * 28
    cursor_at(x + 6, y, w - 12, 26) if i == sel
    P.text(t, x + 18, y + 1, w - 24, 24, s, c[:txt], PF::ROW)
  end
end
intro(c); msgbox(c, "OAK: How would you like to play", "this time?"); cmd_win(c, ["Classic", "Remix", "Randomized", "A Preset", "Share Code"], 3); shot("NM5_mode")
intro(c); msgbox(c, "OAK: Which one shall it be?", "")
cmd_win(c, PRESETS.map { |p| p[0] }, 1, 300, 200); shot("NM5_preset")
