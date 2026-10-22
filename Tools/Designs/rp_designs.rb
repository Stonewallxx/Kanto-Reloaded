# encoding: utf-8
# Mockups: Battle Sandbox (topic 35), screen 4: Replay (Same Seed Replay).
# Battles with Record Inputs on keep their seed and every input; a replay
# runs the same battle again exactly, to reproduce a bug. Take Over hands
# control back at any turn. A recording that crashed keeps the error.
# Each design is a pair: the recordings (left), a replay running in the EBDX
# battle (right). Design 1 = the Settings layout.
# Usage (from this folder): ruby rp_designs.rb "<KIF Beta>" <work dir with metrics.json>
BSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "bs_designs.rb"), :encoding => "UTF-8")
eval(BSRC.split("c = palette(2)\n")[0], binding, "bs_designs.rb")
eval("SIDEX = " + BSRC.split("SIDEX = ")[1].split("bsx(c, 0, nil, 3)")[0], binding, "bs_designs.rb")   # the chosen Setup Screen (mix)

# name, setup, seed, turns, result, error, your icons, their icons
RECS = [["Wild Doubles Test", "Route 24, Doubles", "77C0-1B2E", 4, "Crashed", "NoMethodError at turn 3", %w[PIKACHU LAPRAS], %w[GYARADOS ONIX]],
        ["Double Abilities vs Rain", "Misty (Remix), Doubles", "4F2A-91C3", 7, "Won", nil, %w[PIKACHU GENGAR.LAPRAS], %w[FOMANTIS.AMAURA FROSLASS.LAPRAS]],
        ["Hidden Power Types", "Brock (Classic), Singles", "9A13-5D70", 5, "Lost", nil, %w[SNORLAX], %w[GEODUDE.PIDGEY DIGLETT.ONIX]],
        ["Shiny Sparkle Check", "Route 24, Singles", "0C4E-88F1", 1, "Ran", nil, %w[PIKACHU], %w[ABRA]]]
def res_col(r); { "Crashed" => RED2, "Won" => GREEN, "Lost" => AMB, "Ran" => BLUE2 }[r]; end
def battle_bg(c)
  frame(c); OVER.bitmap.clear
  MAPS.bitmap = Bitmap.new(W, H)
  MAPS.bitmap.blt(0, 0, bmp(File.join(HERE, "ebdx/doubles_command.png")), Rect.new(0, 0, W, H))
  BASE.bitmap.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 0))
end
def replay_bar(c, turn, of, paused = false)
  o = OVER.bitmap
  UI.rbox(o, 120, 4, 392, 28, 6, Color.new(20, 24, 34, 255), RED2)
  UI.rbox(o, 130, 11, 140, 21, 5, RED2)
  P.text(o, 146, 6, 240, 20, "REPLAY  Turn #{turn} of #{of}#{paused ? '  Paused' : ''}", c[:white], PF::TEXT)
end
D_CRASH = ["Wild Doubles Test", "Crashed at turn 3: NoMethodError in Double Abilities (battle_handlers.rb:212). Seed 77C0-1B2E, 31 inputs. A replays it exactly; X takes over at a turn.", ["CRASHED"]]

c = palette(2)

#================================================================ RP1 Recommended: the Settings layout; recordings as rows, the description box has the seed and the error
RSECS = [["Recordings", [230, 180, 60]], ["Crashed", [210, 80, 80]], ["Starred", [96, 160, 232]]]
def rp1_list(c)
  bs_frame(c, nil, nil)
  t = TOP.bitmap
  UI.rbox(BASE.bitmap, 6, 36, 174, 262, 6, c[:panel])
  RSECS.each_with_index do |(l, rgb), i|
    y = 40 + i * 22
    UI.rbox(t, 14, y + 3, 28, y + 17, 3, Color.new(*rgb)); P.glyph(t, 14, y + 3, 15, 15, l[0], Color.new(248, 248, 248))
    P.text(t, 33, y + 2, 136, 18, l, i == 0 ? c[:white] : c[:dim])
  end
  boxes(c)
  P.heading(t, 190, W - 16, 43, "Recordings", c[:head], c[:line])
  RECS.each_with_index do |(n, setup, seed, turns, res), i|
    y = 56 + i * 48
    cursor_at(184, y, W - 194, 46) if i == 0
    P.text(t, 196, y + 2, 220, 20, n, c[:opt], PF::TEXT)
    P.small(t, 196, y + 22, 220, 14, "#{setup}, #{turns} turns", c[:dim])
    P.pill(t, W - 18, y + 8, res.upcase, Color.new(res_col(res).red / 4, res_col(res).green / 4, res_col(res).blue / 4), res_col(res))
  end
  desc_box(c, *D_CRASH)
  hints(c, [[:ud, "Select"], [A_BTN, "Replay"], [X_BTN, "Take Over at..."], [Y_BTN, "Star"], [B_BTN, "Back"]])
end
rp1_list(c); dump_as("RP1_list")
battle_bg(c); replay_bar(c, 3, 4)
o = OVER.bitmap
UI.rbox(o, 296, 270, 506, 312, 6, Color.new(20, 24, 34, 255), c[:line])
P.small(o, 306, 273, 196, 16, "Next: Lapras, Surf (input 23)", c[:txt])
P.small(o, 306, 291, 196, 16, "Speed 2x", c[:dim])
BASE.bitmap.fill_rect(0, H - 28, W, 28, c[:bg])
hints(c, [[A_BTN, "Take Over"], [Y_BTN, "Pause"], ["p:10", "Faster"], [B_BTN, "Stop"]]); dump_as("RP1_replay")

#================================================================ RP2: a recording as a turn timeline; pick the turn to start from
def rp2_tl(c)
  bs_frame(c, nil, nil)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 6, 36, W - 6, 80, 6, c[:panel2], RED2)
  P.text(t, 16, 38, 300, 22, "Wild Doubles Test", c[:white], PF::TEXT)
  P.small(t, 16, 58, 400, 16, "Route 24, Doubles. Seed 77C0-1B2E. Crashed at turn 3.", c[:dim])
  UI.rbox(b, 6, 86, W - 6, 262, 6, c[:panel])
  turns = [["1", "Pikachu: Thunderbolt", "Lapras: Ice Beam", "Gyarados: Bite", "Onix: Rock Throw"],
           ["2", "Pikachu: Thunderbolt", "Lapras: Surf", "Gyarados: Thrash", "Onix: Bind"],
           ["3", "Pikachu: Quick Attack", "Lapras: Surf", "Crash: NoMethodError", ""]]
  turns.each_with_index do |(n, a, b2, c1, d), i|
    y = 92 + i * 56
    crash = c1.start_with?("Crash")
    UI.rbox(t, 14, y + 4, 44, y + 46, 6, crash ? Color.new(70, 24, 24) : c[:dark], crash ? RED2 : (i == 1 ? c[:selb] : c[:line]))
    P.text(t, 14, y + 12, 30, 24, n, crash ? RED2 : c[:white], PF::ROW, 2)
    cursor_at(10, y + 1, W - 20, 50) if i == 1
    [[a, 56, y + 6], [b2, 56, y + 26], [c1, 280, y + 6], [d, 280, y + 26]].each { |s, x, yy| P.small(t, x, yy, 210, 16, s, s.start_with?("Crash") ? RED2 : c[:txt]) }
  end
  desc_box(c, "Turn 2", "Start from turn 2: the battle replays turn 1 by itself, then hands you control. A starts here.")
  hints(c, [[:ud, "Turns"], [A_BTN, "Start Here"], [Y_BTN, "Replay All"], [B_BTN, "Back"]])
end
rp2_tl(c); dump_as("RP2_timeline")
battle_bg(c)
o = OVER.bitmap
UI.rbox(o, 6, 4, W - 6, 30, 6, Color.new(20, 24, 34, 255), RED2)
3.times { |k| UI.rbox(o, 16 + k * 40, 10, 50 + k * 40, 24, 4, k < 1 ? GREEN : (k == 1 ? c[:selb] : c[:dark])); P.text(o, 16 + k * 40, 10, 34, 14, "T#{k + 1}", c[:white], PF::TINY, 2) }
P.text(o, 140, 6, 360, 22, "Your turn (from turn 2)", c[:white], PF::TEXT)
BASE.bitmap.fill_rect(0, H - 28, W, 28, c[:bg])
hints(c, [[:lr, "Choose"], [A_BTN, "Select"], [Y_BTN, "Back to Replay"]]); dump_as("RP2_takeover")

#================================================================ RP3: cards with the result first; crashes on top, the error on the card
def rp3_cards(c)
  bs_frame(c, nil, nil)
  b = BASE.bitmap; t = TOP.bitmap
  RECS.each_with_index do |(n, setup, seed, turns, res, err, you, them), i|
    x = 6 + (i % 2) * 254; y = 36 + (i / 2) * 114
    col = res_col(res)
    UI.rbox(b, x, y, x + 246, y + 108, 6, c[:panel], i == 0 ? c[:selb] : col)
    cursor_at(x - 2, y - 2, 250, 112) if i == 0
    P.pill(t, x + 238, y + 8, res.upcase, Color.new(col.red / 4, col.green / 4, col.blue / 4), col)
    P.text(t, x + 10, y + 4, 180, 22, PF.fit(PF::TEXT, n, 180), c[:white], PF::TEXT)
    P.small(t, x + 10, y + 26, 226, 14, setup, c[:dim])
    icons_y = y + 58
    you.each_with_index { |sp, k| mon(t, sp, x + 24 + k * 30, icons_y, 28) }
    P.text(t, x + 100, icons_y - 10, 30, 20, "vs", c[:dim], PF::TEXT, 2)
    them.each_with_index { |sp, k| mon(t, sp, x + 150 + k * 30, icons_y, 28) }
    P.small(t, x + 10, y + 82, 226, 16, err ? err : "Seed #{seed}, #{turns} turns", err ? RED2 : c[:dim])
  end
  hints(c, [[:ud, ""], [:lr, "Select"], [A_BTN, "Replay"], [X_BTN, "Take Over at..."], [B_BTN, "Back"]])
end
rp3_cards(c); dump_as("RP3_cards")
battle_bg(c); replay_bar(c, 3, 4)
o = OVER.bitmap
UI.rbox(o, 96, 120, 416, 230, 8, Color.new(30, 14, 16, 240), RED2)
P.text(o, 96, 126, 320, 24, "The Crash Is Next", RED2, PF::ROW, 2)
P.small(o, 106, 154, 300, 16, "Input 24: Gyarados's Double Abilities.", c[:txt], 2)
P.small(o, 106, 172, 300, 16, "NoMethodError (battle_handlers.rb:212)", c[:dim], 2)
P.small(o, 106, 196, 300, 16, "A: Step In.  Y: Let It Crash.  B: Stop.", c[:txt], 2)
BASE.bitmap.fill_rect(0, H - 28, W, 28, c[:bg])
hints(c, [[A_BTN, "Step In"], [Y_BTN, "Let It Crash"], [B_BTN, "Stop"]]); dump_as("RP3_crash")

#================================================================ RP4: inside the Setup Screen; each Saved Setup keeps its recordings
def rp4_setup(c)
  bs_frame(c); side_x(c, 2); boxes(c)
  t = TOP.bitmap
  P.heading(t, 190, W - 16, 43, "Saved Setups", c[:head], c[:line])
  [["Double Abilities vs Rain", nil], ["  Played 14:02, Won", "WON"], ["  Played 13:40, Lost", "LOST"], ["Wild Doubles Test", nil], ["  Played 12:15, Crashed", "CRASHED"]].each_with_index do |(n, res), i|
    y = 56 + i * 26
    cursor_at(184, y, W - 194, 25) if i == 4
    P.text(t, 196, y, 220, 24, n.strip, res ? c[:txt] : c[:opt], res ? PF::TEXT : PF::ROW) if !res
    if res
      P.small(t, 216, y + 4, 200, 16, n.strip, c[:txt])
      col = res_col(res.capitalize)
      P.pill(t, W - 18, y + 5, res, Color.new(col.red / 4, col.green / 4, col.blue / 4), col)
    end
  end
  desc_box(c, *D_CRASH)
  hints(c, [[:ud, "Select"], [A_BTN, "Replay"], [X_BTN, "Take Over at..."], [Y_BTN, "Start Battle"], [B_BTN, "Sections"]])
end
rp4_setup(c); dump_as("RP4_setup")
battle_bg(c); replay_bar(c, 2, 4)
BASE.bitmap.fill_rect(0, H - 28, W, 28, c[:bg])
hints(c, [[A_BTN, "Take Over"], [Y_BTN, "Pause"], ["p:10", "Faster"], [B_BTN, "Stop"]]); dump_as("RP4_replay")

#================================================================ RP5: the replay controls are the focus: a player bar over the battle (pause, step, speed, take over)
def rp5_bar(c, paused)
  battle_bg(c)
  o = OVER.bitmap
  UI.rbox(o, 6, 4, W - 6, 64, 8, Color.new(20, 24, 34, 255), RED2)
  P.text(o, 16, 6, 300, 22, "Wild Doubles Test", c[:white], PF::TEXT)
  P.small(o, W - 220, 9, 206, 16, "Seed 77C0-1B2E", c[:dim], 2)
  UI.rbox(o, 16, 34, W - 16, 42, 4, c[:dark])
  UI.rbox(o, 16, 34, 16 + ((W - 32) * 0.62).to_i, 42, 4, RED2)
  4.times { |k| o.fill_rect(16 + (W - 32) * (k + 1) / 4, 32, 2, 12, c[:line]) }
  o.fill_rect(16 + ((W - 32) * 0.70).to_i, 30, 3, 16, Color.new(255, 90, 90))
  P.small(o, 16, 46, 300, 16, paused ? "Paused: turn 3, input 22 of 31" : "Turn 3, input 22 of 31   Speed 2x", c[:txt])
  P.small(o, W - 220, 46, 206, 16, "Crash at input 24", RED2, 2)
  BASE.bitmap.fill_rect(0, H - 28, W, 28, c[:bg])
  hints(c, paused ? [[:lr, "Step"], [Y_BTN, "Play"], [A_BTN, "Take Over"], [B_BTN, "Stop"]] : [[Y_BTN, "Pause"], ["p:9", "Slower"], ["p:10", "Faster"], [A_BTN, "Take Over"], [B_BTN, "Stop"]])
end
rp5_bar(c, false); dump_as("RP5_playing")
rp5_bar(c, true); dump_as("RP5_paused")
