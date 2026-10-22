# encoding: utf-8
# Mockups: Battle Sandbox (topic 35, DEBUG only), screen 1: the Setup Screen.
# Both sides, battle size, wild or trainer, weather and field, the seed (Same
# Seed Replay), Saved Setups, and Start. The sandbox team is separate: your
# real party, items, money and Pokédex come back unchanged.
# Sample: Pikachu + Genras (Gengar head, Lapras body; Double Abilities) vs
# Leader Misty (Remix) in a double battle, rain with 3 turns left.
# Design 1 = the Settings layout. Design 3 uses the EBDX doubles backdrop.
# Usage (from this folder): ruby bs_designs.rb "<KIF Beta>" <work dir with metrics.json>
TSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "tp_designs.rb"), :encoding => "UTF-8")
eval(TSRC.split("c = palette(2)\n")[0], binding, "tp_designs.rb")

def icon_bmp(sp); bmp(File.join(GFX, "Pokemon/Icons/#{sp}.png")); end
# A fusion's icon for the mockup: the head's top half over the body's bottom half
def mon(t, spec, cx, cy, size = 40)
  if spec.include?(".")
    head, body = spec.split(".")
    h = size / 2
    t.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, h), icon_bmp(head), Rect.new(0, 0, 64, 32))
    t.stretch_blt(Rect.new(cx - size / 2, cy - size / 2 + h, size, size - h), icon_bmp(body), Rect.new(0, 32, 64, 32))
  else
    t.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), icon_bmp(spec), Rect.new(0, 0, 64, 64))
  end
end
# spec, name, level, ability, item
YOURS = [["PIKACHU", "Pikachu", 50, "Static", "Light Ball"], ["GENGAR.LAPRAS", "Genras", 50, "Cursed Body, Water Absorb", "Leftovers"]]
MISTY = [["STARMIE", "Starmie", 52, "Natural Cure", "Mystic Water"], ["GYARADOS", "Gyarados", 52, "Intimidate", "Sitrus Berry"],
         ["GOLDUCK", "Golduck", 51, "Swift Swim", "Damp Rock"], ["LAPRAS", "Lapras", 51, "Water Absorb", "Shell Bell"]]
BATTLE = [["Kind", "Trainer"], ["Opponent", "Misty (Remix)"], ["Size", "Doubles"], ["Weather", "Rain"], ["Weather Turns", "3 Left"],
          ["Field", "None"]]   # Seed and Record Inputs dropped with Replay (his call 2026-10-18)
SEED = "4F2A-91C3"
def bs_frame(c, left = "Saved", right = "Start")
  page_frame(c, "Battle Sandbox")
  b = BASE.bitmap; t = TOP.bitmap
  [[8, left, c[:dark], c[:line], c[:dim]], [W - 120, right, Color.new(24, 60, 40), GREEN, GREEN]].each do |x, l, f, bo, tc|
    next unless l
    UI.rbox(b, x, 4, x + 112, 27, 5, f, bo); P.text(t, x, 4, 112, 23, l, tc, PF::TEXT, 2)
  end
end
SIDE = [["Battle", [210, 80, 80]], ["Your Side", [96, 160, 232]], ["Other Side", [60, 170, 160]], ["Saved Setups", [230, 180, 60]]]
def side_secs(c, sel)
  t = TOP.bitmap
  UI.rbox(BASE.bitmap, 6, 36, 174, 262, 6, c[:panel])
  SIDE.each_with_index do |(l, rgb), i|
    y = 40 + i * 22
    UI.rbox(t, 14, y + 3, 28, y + 17, 3, Color.new(*rgb)); P.glyph(t, 14, y + 3, 15, 15, l[0], Color.new(248, 248, 248))
    P.text(t, 33, y + 2, 136, 18, l, i == sel ? c[:white] : c[:dim])
  end
  P.small(t, 14, 226, 156, 16, "Your party, items and", c[:dim]); P.small(t, 14, 242, 156, 16, "money stay safe.", c[:dim])
end
def team_rows(c, team, sel, y0 = 56, x0 = 184, x1 = W - 10)
  t = TOP.bitmap
  team.each_with_index do |(sp, n, lv, ab, it), i|
    y = y0 + i * 40
    cursor_at(x0, y, x1 - x0, 38) if i == sel
    mon(t, sp, x0 + 22, y + 19, 36)
    P.text(t, x0 + 46, y + 1, 150, 20, n, c[:opt], PF::TEXT)
    P.small(t, x0 + 46, y + 20, x1 - x0 - 110, 14, ab, c[:dim])
    P.text(t, x1 - 70, y + 1, 62, 20, "Lv. #{lv}", c[:txt], PF::TEXT, 1)
    P.small(t, x1 - 110, y + 20, 102, 14, it, c[:dim], 1)
  end
end

c = palette(2)

#================================================================ BS1 Recommended: the Settings layout; Battle, Your Side, Other Side, Saved Setups as sections
def bs1(c, sec, sel)
  bs_frame(c); side_secs(c, sec); boxes(c)
  t = TOP.bitmap
  P.heading(t, 190, W - 16, 43, sec == 0 ? "Battle" : "Other Side: Misty (Remix)", c[:head], c[:line])
  if sec == 0
    BATTLE.each_with_index do |(l, v), i|
      y = 56 + i * 25
      cursor_at(184, y, W - 194, 24) if i == sel
      P.text(t, 196, y, 200, 24, l, c[:opt], PF::TEXT)
      l == "Opponent" ? P.pill(t, W - 18, y + 5, v.upcase, c[:pill], c[:txt]) : value_cell(t, c, W - 76, y, v, i == sel)
    end
  else
    team_rows(c, MISTY, sel)
    P.text(t, 196, 220, 220, 22, "Load a Trainer or Wild Table", c[:opt], PF::TEXT); P.pill(t, W - 18, 225, "OPEN", c[:pill], c[:txt])
  end
end
bs1(c, 0, 3); desc_box(c, "Weather", "The weather when the battle starts. Weather Turns sets how many turns it has left (Start Mid-Battle).", ["SANDBOX"])
hints(c, [[:ud, "Select"], [:lr, "Change"], [Y_BTN, "Start Battle"], [B_BTN, "Sections"]]); dump_as("BS1_battle")
bs1(c, 2, 1); desc_box(c, "Gyarados", "Lv. 52, Intimidate, Sitrus Berry: Misty's Remix team, loaded as it is in the game. A edits it for this battle only.", ["FROM THE GAME"])
hints(c, [[:ud, "Select"], [A_BTN, "Edit"], [Y_BTN, "Start Battle"], [B_BTN, "Sections"]]); dump_as("BS1_other")

#================================================================ BS2: the two teams facing each other; options as chips along the top
def chips_row(c, chips, sel)
  b = BASE.bitmap; t = TOP.bitmap
  x = 8
  chips.each_with_index do |ch, i|
    w = P.width(PF::TINY, ch) + 18
    UI.rbox(b, x, 38, x + w, 56, 5, i == sel ? c[:sel] : c[:dark], i == sel ? c[:selb] : c[:line])
    P.text(t, x, 40, w, 14, ch, i == sel ? c[:white] : c[:txt], PF::TINY, 2)
    x += w + 6
  end
end
def side_col(c, x0, x1, title, team, sel, slots = 6)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, x0, 62, x1, 308, 6, c[:panel], c[:line])
  P.text(t, x0, 64, x1 - x0, 22, title, c[:head], PF::TEXT, 2)
  slots.times do |i|
    y = 88 + i * 36
    m = team[i]
    cursor_at(x0 + 4, y, x1 - x0 - 8, 34) if i == sel
    if m
      mon(t, m[0], x0 + 22, y + 17, 32)
      P.text(t, x0 + 42, y, 120, 18, m[1], c[:opt], PF::TEXT)
      P.small(t, x0 + 42, y + 17, x1 - x0 - 50, 14, "Lv. #{m[2]}  #{m[4]}", c[:dim])
    else
      P.small(t, x0 + 12, y + 9, x1 - x0 - 24, 16, i == team.length ? "+ Add" : "", c[:dim])
    end
  end
end
def bs2(c, wild, sel_side, sel)
  bs_frame(c, nil, nil)
  b = BASE.bitmap; t = TOP.bitmap
  chips_row(c, wild ? ["WILD", "DOUBLES", "CLEAR", "SEED #{SEED}", "SAVE"] : ["TRAINER", "DOUBLES", "RAIN, 3 TURNS", "SEED #{SEED}", "SAVE"], sel_side == :chips ? sel : -1)
  side_col(c, 8, 230, "Your Side", YOURS, sel_side == :you ? sel : -1)
  wildt = [["ABRA", "Abra", 9, "Synchronize", "None"], ["ODDISH", "Oddish", 10, "Chlorophyll", "None"], ["BELLSPROUT", "Bellsprout", 10, "Chlorophyll", "None"]]
  side_col(c, 282, W - 8, wild ? "Route 24 (Wild)" : "Misty (Remix)", wild ? wildt : MISTY, sel_side == :them ? sel : -1)
  P.text(t, 230, 170, 52, 30, "VS", c[:head], PF::TITLE, 2)
  UI.rbox(b, 8, 314, W - 8, 344, 6, Color.new(24, 60, 40), GREEN); P.text(t, 8, 317, W - 16, 24, "Start Battle", GREEN, PF::TEXT, 2)
  hints(c, [[:ud, ""], [:lr, "Select"], [A_BTN, "Edit"], [Y_BTN, "Start"], [B_BTN, "Back"]])
end
bs2(c, false, :you, 1); dump_as("BS2_trainer")
bs2(c, true, :chips, 0); dump_as("BS2_wild")

#================================================================ BS3: the EBDX battle as a preview; pick a battler on it to edit; tabs below
def bs3(c, tab, sel_battler)
  frame(c); OVER.bitmap.clear
  MAPS.bitmap = Bitmap.new(W, H)
  bg = bmp(File.join(HERE, "ebdx/doubles_none.png"))
  MAPS.bitmap.stretch_blt(Rect.new(0, 0, W, 240), bg, Rect.new(0, 40, 512, 240))
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 0))
  b.fill_rect(0, 0, W, 26, Color.new(c[:panel2].red, c[:panel2].green, c[:panel2].blue, 230))
  P.text(t, 0, 0, W, 26, "Battle Sandbox", c[:title], PF::ROW, 2)
  boxes_at = { 0 => [376, 30, 130, 140], 1 => [396, 84, 100, 96], 2 => [40, 120, 110, 110], 3 => [150, 104, 120, 120] }
  if sel_battler
    x, y, w, h = boxes_at[sel_battler]
    UI.rbox(OVER.bitmap, x, y, x + w, y + h, 6, Color.new(0, 0, 0, 0), c[:selb])
    P.pill(OVER.bitmap, x + w - 4, y + h + 4, "WILD GYARADOS", c[:sel], c[:white])
  end
  b.fill_rect(0, 236, W, H - 236, c[:bg])
  tabs = ["BATTLE", "YOUR SIDE", "OTHER SIDE", "SAVED"]
  tabs.each_with_index do |n, i|
    x = 8 + i * 125
    UI.rbox(b, x, 242, x + 120, 260, 5, i == tab ? c[:sel] : c[:dark], i == tab ? c[:selb] : c[:line])
    P.text(t, x, 244, 120, 14, n, i == tab ? c[:white] : c[:dim], PF::TINY, 2)
  end
  UI.rbox(b, 6, 264, W - 6, H - 30, 6, c[:panel])
  rows = tab == 0 ? [["Kind", "Wild"], ["Size", "Doubles"], ["Weather", "Rain"], ["Seed", SEED]] : [["Gyarados", "Lv. 30"], ["Ability", "Moxie"], ["Item", "None"], ["HP", "50%"]]
  rows.each_with_index do |(l, v), i|
    x = 14 + (i % 2) * 250; y = 270 + (i / 2) * 26
    cursor_at(x - 4, y, 242, 24) if i == 0 && tab == 0
    P.text(t, x, y, 120, 24, l, c[:opt], PF::TEXT); value_cell(t, c, x + 186, y, v, i == 0 && tab == 0)
  end
  hints(c, tab == 0 ? [["p:9", ""], ["p:10", "Tabs"], [:ud, ""], [:lr, "Select"], [Y_BTN, "Start"], [B_BTN, "Back"]] : [[:lr, "Battlers"], [A_BTN, "Edit"], ["p:9", ""], ["p:10", "Tabs"], [Y_BTN, "Start"]])
end
bs3(c, 2, 0); dump_as("BS3_pick")
bs3(c, 0, nil); dump_as("BS3_battle")

#================================================================ BS4: steps, like the Run Setup: Battle, Your Side, Other Side, Start
STEPS = ["Battle", "Your Side", "Other Side", "Start"]
def steps_bar(c, cur)
  b = BASE.bitmap; t = TOP.bitmap
  STEPS.each_with_index do |s, i|
    x = 8 + i * 125
    done = i < cur; on = i == cur
    UI.rbox(b, x, 38, x + 120, 60, 5, on ? c[:sel] : c[:dark], on ? c[:selb] : (done ? GREEN : c[:line]))
    P.text(t, x, 39, 120, 20, "#{i + 1}. #{s}", on ? c[:white] : (done ? GREEN : c[:dim]), PF::TEXT, 2)
  end
end
def bs4(c, cur)
  bs_frame(c, nil, nil)
  b = BASE.bitmap; t = TOP.bitmap
  steps_bar(c, cur)
  UI.rbox(b, 6, 66, W - 6, 262, 6, c[:panel])
  if cur == 0
    BATTLE.first(7).each_with_index do |(l, v), i|
      y = 72 + i * 26
      cursor_at(10, y, W - 20, 25) if i == 0
      P.text(t, 24, y, 220, 24, l, c[:opt], PF::ROW)
      l == "Opponent" ? P.pill(t, W - 18, y + 5, v.upcase, c[:pill], c[:txt]) : value_cell(t, c, W - 76, y, v, i == 0)
    end
    desc_box(c, "Kind", "Wild Pokémon or a trainer. Trainers come from the game (Classic, Remix, Expert); wild Pokémon from a map's table or picked one by one.")
    hints(c, [[:ud, "Select"], [:lr, "Change"], [A_BTN, "Next"], [B_BTN, "Back"]])
  else
    P.text(t, 16, 70, 300, 24, "Ready", c[:head], PF::ROW)
    P.small(t, 16, 96, 480, 16, "Misty (Remix), Doubles, Rain 3 turns, Seed #{SEED}.", c[:txt])
    YOURS.each_with_index { |m, i| mon(t, m[0], 40 + i * 50, 140, 40) }
    P.text(t, 220, 126, 72, 30, "VS", c[:head], PF::ROW, 2)
    MISTY.each_with_index { |m, i| mon(t, m[0], 320 + i * 48, 140, 40) }
    [["Start Battle", Color.new(24, 60, 40), GREEN], ["Save This Setup", c[:dark], c[:line]]].each_with_index do |(l, f, bo), i|
      y = 184 + i * 34
      UI.rbox(b, 120, y, 392, y + 28, 6, f, bo); P.text(t, 120, y + 2, 272, 24, l, i == 0 ? GREEN : c[:txt], PF::TEXT, 2)
      cursor_at(118, y - 2, 276, 32) if i == 0
    end
    desc_box(c, "Start Battle", "Your party, items, money and Pokédex come back as they were when the battle ends.")
    hints(c, [[:ud, "Select"], [A_BTN, "Start"], [B_BTN, "Back"]])
  end
end
bs4(c, 0); dump_as("BS4_battle")
bs4(c, 3); dump_as("BS4_start")

#================================================================ BS5: Saved Setups first; one press starts a saved one
SAVED = [["Double Abilities vs Rain", "Trainer, Doubles, Rain 3, Seed 4F2A", %w[PIKACHU GENGAR.LAPRAS], %w[STARMIE GYARADOS]],
         ["Shiny Sparkle Check", "Wild, Singles, Route 24", %w[PIKACHU], %w[ABRA]],
         ["Hidden Power Types", "Trainer, Singles, Seed 77C0", %w[SNORLAX], %w[ALAKAZAM]],
         ["Weather Encounters", "Wild, Doubles, Sandstorm", %w[ONIX SANDSLASH], %w[CUBONE DIGLETT]]]
def bs5(c, sel, open)
  bs_frame(c, nil, nil)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 6, 36, W - 6, open ? 186 : 262, 6, c[:panel])
  P.heading(t, 16, W - 16, 43, "Saved Setups", c[:head], c[:line])
  (open ? SAVED.first(3) : SAVED).each_with_index do |(n, sum, a, z), i|
    y = 58 + i * 42
    cursor_at(10, y, W - 20, 40) if i == sel
    P.text(t, 20, y + 1, 280, 20, n, c[:opt], PF::TEXT)
    P.small(t, 20, y + 21, 280, 14, sum, c[:dim])
    a.each_with_index { |sp, k| mon(t, sp, 330 + k * 30, y + 20, 28) }
    P.text(t, 390, y + 8, 20, 20, "vs", c[:dim], PF::TEXT, 2)
    z.each_with_index { |sp, k| mon(t, sp, 428 + k * 30, y + 20, 28) }
  end
  if open
    UI.rbox(b, 6, 192, W - 6, 262, 6, c[:panel2], c[:selb])
    [["Start", Color.new(24, 60, 40), GREEN], ["Replay Last", c[:dark], c[:line]], ["Edit", c[:dark], c[:line]]].each_with_index do |(l, f, bo), i|
      x = 18 + i * 162
      UI.rbox(b, x, 210, x + 150, 238, 6, f, bo); P.text(t, x, 212, 150, 24, l, i == 0 ? GREEN : c[:txt], PF::TEXT, 2)
    end
    P.small(t, 18, 242, 470, 16, "Last played 14:02. Replay Last runs the recorded inputs.", c[:dim])
    desc_box(c, "Double Abilities vs Rain", "Pikachu and Genras against Misty's Remix team in the rain. Saved 2026-10-18.")
    hints(c, [[:lr, "Choose"], [A_BTN, "Select"], [B_BTN, "Back"]])
  else
    UI.rbox(b, W - 150, 4, W - 8, 27, 5, c[:dark], c[:line]); P.text(t, W - 150, 4, 142, 23, "New Setup", c[:dim], PF::TEXT, 2)
    desc_box(c, "Double Abilities vs Rain", "Trainer, Doubles, Rain 3 turns, Seed 4F2A. A shows Start, Replay Last and Edit.")
    hints(c, [[:ud, "Select"], [A_BTN, "Open"], [X_BTN, "New Setup"], [B_BTN, "Back"]])
  end
end
bs5(c, 0, false); dump_as("BS5_list")
bs5(c, 0, true); dump_as("BS5_open")

#================================================================ BSX mix (his ask): design 1's Settings layout, with design 2's teams facing as the party view
SIDEX = [["Battle", [210, 80, 80]], ["Teams", [96, 160, 232]], ["Saved Setups", [230, 180, 60]]]
def side_x(c, sel)
  t = TOP.bitmap
  UI.rbox(BASE.bitmap, 6, 36, 174, 262, 6, c[:panel])
  SIDEX.each_with_index do |(l, rgb), i|
    y = 40 + i * 22
    UI.rbox(t, 14, y + 3, 28, y + 17, 3, Color.new(*rgb)); P.glyph(t, 14, y + 3, 15, 15, l[0], Color.new(248, 248, 248))
    P.text(t, 33, y + 2, 136, 18, l, i == sel ? c[:white] : c[:dim])
  end
  P.small(t, 14, 226, 156, 16, "Your party, items and", c[:dim]); P.small(t, 14, 242, 156, 16, "money stay safe.", c[:dim])
end
def team_col(c, x0, x1, title, team, sel)
  b = BASE.bitmap; t = TOP.bitmap
  P.text(t, x0, 40, x1 - x0, 20, title, c[:head], PF::TEXT, 2)
  b.fill_rect(x0 + 4, 61, x1 - x0 - 8, 1, c[:line])
  6.times do |i|
    y = 66 + i * 32
    m = team[i]
    cursor_at(x0, y, x1 - x0, 30) if i == sel
    if m
      mon(t, m[0], x0 + 16, y + 15, 28)
      P.text(t, x0 + 34, y, x1 - x0 - 38, 16, m[1], c[:opt], PF::TEXT)
      P.small(t, x0 + 34, y + 15, x1 - x0 - 38, 14, "Lv. #{m[2]}", c[:dim])
    elsif i == team.length
      P.small(t, x0 + 10, y + 8, x1 - x0 - 16, 16, "+ Add", c[:dim])
    end
  end
end
def bsx(c, sec, sel_side, sel)
  bs_frame(c); side_x(c, sec); boxes(c)
  t = TOP.bitmap
  if sec == 0
    P.heading(t, 190, W - 16, 43, "Battle", c[:head], c[:line])
    BATTLE.each_with_index do |(l, v), i|
      y = 56 + i * 25
      cursor_at(184, y, W - 194, 24) if i == sel
      P.text(t, 196, y, 200, 24, l, c[:opt], PF::TEXT)
      l == "Opponent" ? P.pill(t, W - 18, y + 5, v.upcase, c[:pill], c[:txt]) : value_cell(t, c, W - 76, y, v, i == sel)
    end
  else
    team_col(c, 184, 334, "Your Side", YOURS, sel_side == :you ? sel : -1)
    P.text(t, 334, 140, 20, 24, "VS", c[:head], PF::TEXT, 2)
    team_col(c, 354, W - 10, "Misty (Remix)", MISTY, sel_side == :them ? sel : -1)
  end
end
bsx(c, 0, nil, 3); desc_box(c, "Weather", "The weather when the battle starts. Weather Turns sets how many turns it has left (Start Mid-Battle).", ["SANDBOX"])
hints(c, [[:ud, "Select"], [:lr, "Change"], [Y_BTN, "Start Battle"], [B_BTN, "Sections"]]); dump_as("BSX_battle")
bsx(c, 1, :them, 1); desc_box(c, "Gyarados", "Lv. 52, Intimidate, Sitrus Berry: Misty's Remix team, loaded as it is in the game. A edits it for this battle only; X loads another trainer or a wild table.", ["OTHER SIDE"])
hints(c, [[:ud, ""], [:lr, "Select"], [A_BTN, "Edit"], [X_BTN, "Load"], [Y_BTN, "Start Battle"], [B_BTN, "Sections"]]); dump_as("BSX_teams")
