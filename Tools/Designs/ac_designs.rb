# encoding: utf-8
# Mockups: Bug Report Bundle (topic 37), screen 3: After a Crash. KR hooks
# PIF's pbPrintException (it writes errorlog.txt, then shows a plain message
# box), so before the game closes it can offer Make a Bug Report. On the next
# start, if the game closed unexpectedly, the Load Screen asks.
# Sample crash: NoMethodError in battle_handlers.rb:212 during a double battle.
# Each design is a pair: the crash (left), the next start (right).
# Design 1 = the notice look chosen for the Hook Checker's Update Alert.
# Usage (from this folder): ruby ac_designs.rb "<KIF Beta>" <work dir with metrics.json>
USRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "ua_designs.rb"), :encoding => "UTF-8")
eval(USRC.split("c = palette(2)\n")[0], binding, "ua_designs.rb")

ERR = "NoMethodError in battle_handlers.rb:212"
SAFE = "Your last save is safe: today 1:40 PM."
HERE2 = File.dirname(File.expand_path(__FILE__))
def battle_bg(c, dimv = 150)
  frame(c); OVER.bitmap.clear
  MAPS.bitmap = Bitmap.new(W, H)
  MAPS.bitmap.blt(0, 0, bmp(File.join(HERE2, "ebdx/doubles_command.png")), Rect.new(0, 0, W, H))
  BASE.bitmap.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 0))
  OVER.bitmap.fill_rect(0, 0, W, H, Color.new(0, 0, 0, dimv)) if dimv > 0
end
def two_buttons(o, c, x0, x1, y, a, b2, sel = 0)
  mid = (x0 + x1) / 2
  [[x0 + 16, mid - 6, a, 0], [mid + 6, x1 - 16, b2, 1]].each do |l, r, txt, i|
    on = i == sel
    UI.rbox(o, l, y, r, y + 28, 6, on ? c[:sel] : c[:dark], on ? c[:selb] : c[:line])
    P.text(o, l, y + 2, r - l, 24, txt, on ? c[:white] : c[:txt], PF::TEXT, 2)
  end
end
def clear_bar(c)
  OVER.bitmap.fill_rect(0, H - 28, W, 28, Color.new(0, 0, 0, 0))
  BASE.bitmap.fill_rect(0, H - 28, W, 28, c[:bg]); TOP.bitmap.fill_rect(0, H - 28, W, 28, Color.new(0, 0, 0, 0))
end

c = palette(2)

#================================================================ AC1 Recommended: a notice, as in the Update Alert; over the game when it crashes, over the Load Screen next time
def ac1(c, next_start)
  if next_start
    load_bg(c); o = OVER.bitmap; dim(o)
    x0 = 64; x1 = 448; y0 = 96
    UI.rbox(o, x0, y0, x1, y0 + 176, 8, c[:panel2], GOLD)
    P.text(o, x0, y0 + 6, x1 - x0, 26, "The Game Closed Unexpectedly", c[:title], PF::ROW, 2)
    P.small(o, x0, y0 + 34, x1 - x0, 16, "Last time, during a battle on Route 24.", c[:dim], 2)
    o.fill_rect(x0 + 12, y0 + 56, x1 - x0 - 24, 1, c[:line])
    P.small_wrap(o, "A bug report has the logs from that session. It helps get the bug fixed.", 344).each_with_index { |ln, k| P.small(o, x0 + 20, y0 + 64 + k * 17, 344, 16, ln, c[:txt]) }
    P.small(o, x0 + 20, y0 + 104, 344, 16, SAFE, GREEN)
    two_buttons(o, c, x0, x1, y0 + 134, "Make a Bug Report", "Not Now")
  else
    battle_bg(c); o = OVER.bitmap
    x0 = 64; x1 = 448; y0 = 90
    UI.rbox(o, x0, y0, x1, y0 + 190, 8, c[:panel2], RED)
    P.text(o, x0, y0 + 6, x1 - x0, 26, "Something Went Wrong", RED, PF::ROW, 2)
    P.small(o, x0, y0 + 34, x1 - x0, 16, ERR, c[:dim], 2)
    o.fill_rect(x0 + 12, y0 + 56, x1 - x0 - 24, 1, c[:line])
    P.small_wrap(o, "The game has to close. A bug report saves what happened, so it can be fixed.", 344).each_with_index { |ln, k| P.small(o, x0 + 20, y0 + 64 + k * 17, 344, 16, ln, c[:txt]) }
    P.small(o, x0 + 20, y0 + 110, 344, 16, SAFE, GREEN)
    two_buttons(o, c, x0, x1, y0 + 146, "Make a Bug Report", "Close the Game")
  end
  clear_bar(c)
  hints(c, [[:lr, "Choose"], [A_BTN, "Select"]])
end
ac1(c, false); dump_as("AC1_crash")
ac1(c, true); dump_as("AC1_next")

#================================================================ AC2: in the game's own message box, like PIF's messages; two choices
def msgbox(o, c, lines, choices, sel = 0)
  UI.rbox(o, 8, 262, W - 8, 352, 8, Color.new(248, 248, 240), Color.new(80, 84, 96))
  lines.each_with_index { |ln, k| P.text(o, 22, 268 + k * 24, 400, 22, ln, Color.new(48, 48, 56), PF::TEXT) }
  UI.rbox(o, W - 196, 168, W - 8, 168 + choices.length * 26 + 14, 8, Color.new(248, 248, 240), Color.new(80, 84, 96))
  choices.each_with_index do |ch, i|
    y = 175 + i * 26
    UI.tri(o, W - 186, y + 7, :r, Color.new(48, 48, 56), 5) if i == sel
    P.text(o, W - 172, y, 160, 22, ch, Color.new(48, 48, 56), PF::TEXT)
  end
end
def ac2(c, next_start)
  if next_start
    load_bg(c); o = OVER.bitmap; dim(o, 90)
    msgbox(o, c, ["The game closed unexpectedly last time.", "Make a bug report about it?", "Your last save is safe."], ["Make a Report", "Not Now"])
  else
    battle_bg(c, 60); o = OVER.bitmap
    msgbox(o, c, ["Something went wrong and the game has to close.", ERR, "Make a bug report first?"], ["Make a Report", "Close the Game"])
  end
  clear_bar(c)
  hints(c, [[:ud, "Choose"], [A_BTN, "Select"]])
end
ac2(c, false); dump_as("AC2_crash")
ac2(c, true); dump_as("AC2_next")

#================================================================ AC3: a calm full screen; what happened, what's safe, what you can do
def ac3(c, next_start)
  frame(c); OVER.bitmap.clear
  MAPS.bitmap = Bitmap.new(W, H)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, 34, c[:panel2]); b.fill_rect(0, 33, W, 1, c[:line])
  P.text(t, 0, 3, W, 28, next_start ? "Last Time" : "Something Went Wrong", next_start ? c[:title] : RED, PF::TITLE, 2)
  [["What Happened", next_start ? "The game closed during a battle on Route 24 (#{ERR})." : "#{ERR}, in a double battle on Route 24.", RED],
   ["What's Safe", "Your last save (today 1:40 PM, Route 24) and its 7 backups.", GREEN],
   ["What You Can Do", "Make a bug report: it keeps the logs from this session, a screenshot and a note.", BLUE]].each_with_index do |(h, txt, colr), i|
    y = 44 + i * 76
    UI.rbox(b, 8, y, W - 8, y + 70, 6, c[:panel], colr)
    P.text(t, 20, y + 4, 300, 22, h, colr, PF::TEXT)
    P.small_wrap(t, txt, 470).first(2).each_with_index { |ln, k| P.small(t, 20, y + 28 + k * 17, 474, 16, ln, c[:txt]) }
  end
  btns = next_start ? ["Make a Bug Report", "Not Now"] : ["Bug Report", "Copy Error", "Close"]
  bw = (W - 16 - (btns.length - 1) * 8) / btns.length
  btns.each_with_index do |l, i|
    x = 8 + i * (bw + 8)
    UI.rbox(b, x, 278, x + bw, 310, 6, i == 0 ? c[:sel] : c[:dark], i == 0 ? c[:selb] : c[:line])
    P.text(t, x, 282, bw, 24, l, i == 0 ? c[:white] : c[:txt], PF::TEXT, 2)
  end
  hints(c, [[:lr, "Choose"], [A_BTN, "Select"]])
end
ac3(c, false); dump_as("AC3_crash")
ac3(c, true); dump_as("AC3_next")

#================================================================ AC4: small; a corner card when it crashes, a Load Screen panel next time
def ac4(c, next_start)
  if next_start
    load_bg(c)
    o = OVER.bitmap
    TOP.bitmap.fill_rect(284, 218, W - 284, 92, Color.new(0, 0, 0, 0))
    UI.rbox(o, 286, 220, 466, 308, 6, c[:panel2], GOLD)
    P.text(o, 296, 222, 160, 20, "Last Time", GOLD, PF::TEXT)
    P.small(o, 296, 242, 164, 16, "The game closed during a", c[:txt])
    P.small(o, 296, 258, 164, 16, "battle on Route 24.", c[:txt])
    P.small(o, 296, 282, 164, 16, "RB: Make a Bug Report", c[:dim])
    clear_bar(c)
    hints(c, [[:ud, "Choose"], [:lr, "Save File"], [A_BTN, "Select"], ["p:10", "Bug Report"]])
  else
    battle_bg(c, 0); o = OVER.bitmap
    UI.rbox(o, W - 276, 6, W - 6, 92, 6, Color.new(20, 24, 34, 255), RED)
    P.text(o, W - 266, 8, 250, 22, "Something Went Wrong", RED, PF::TEXT)
    P.small(o, W - 266, 30, 254, 16, "NoMethodError (line 212)", c[:dim])
    P.small(o, W - 266, 48, 254, 16, "A: Make a Bug Report", c[:txt])
    P.small(o, W - 266, 66, 254, 16, "B: Close the Game", c[:txt])
    clear_bar(c)
    hints(c, [[A_BTN, "Bug Report"], [B_BTN, "Close"]])
  end
end
ac4(c, false); dump_as("AC4_crash")
ac4(c, true); dump_as("AC4_next")

#================================================================ AC5: straight into the bug report; the note and screenshot already filled in
def ac5(c, next_start)
  frame(c); OVER.bitmap.clear
  MAPS.bitmap = Bitmap.new(W, H)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, 34, c[:panel2]); b.fill_rect(0, 33, W, 1, c[:line])
  P.text(t, 0, 3, W, 28, "Bug Report", c[:title], PF::TITLE, 2)
  UI.rbox(b, 8, 40, W - 8, 74, 6, col(RED, 40), RED)
  P.text(t, 18, 44, 480, 24, next_start ? "From Last Time: the game closed in a battle" : "The game hit an error and has to close", RED, PF::TEXT)
  UI.rbox(b, 8, 80, W - 8, 300, 6, c[:panel])
  P.small(t, 18, 84, 300, 14, "WHAT HAPPENED (FILLED IN, ADD TO IT)", c[:head])
  UI.rbox(b, 16, 100, 340, 144, 6, c[:dark], c[:selb])
  P.small_wrap(t, "#{ERR} during a double battle on Route 24. ", 312).first(2).each_with_index { |ln, k| P.small(t, 24, 105 + k * 17, 312, 16, ln, c[:white]) }
  cursor_at(14, 98, 328, 48)
  t.stretch_blt(Rect.new(352, 100, 144, 108), bmp(File.join(HERE2, "ebdx/doubles_command.png")), Rect.new(0, 0, 512, 384))
  P.small(t, 352, 210, 144, 14, next_start ? "Last screenshot" : "The moment it broke", c[:dim], 2)
  ["Logs", "Settings", "Mods", "Hooks", "Save Check"].each_with_index do |l, i|
    x = 18 + (i % 3) * 110; y = 160 + (i / 3) * 24
    UI.rbox(t, x, y + 2, x + 14, y + 16, 7, Color.new(24, 60, 40), GREEN)
    P.small(t, x + 20, y + 1, 90, 16, l, c[:txt])
  end
  P.small(t, 18, 214, 320, 16, "User names are taken out of paths.", c[:dim])
  UI.rbox(b, 8, 306, 250, 348, 6, Color.new(24, 60, 40), GREEN); P.text(t, 8, 316, 242, 22, "Make Report", GREEN, PF::TEXT, 2)
  UI.rbox(b, 262, 306, W - 8, 348, 6, c[:dark], c[:line]); P.text(t, 262, 316, W - 270, 22, next_start ? "Not Now" : "Close the Game", c[:txt], PF::TEXT, 2)
  hints(c, [[:ud, "Select"], [A_BTN, "Type"], [Y_BTN, "Make Report"], [B_BTN, next_start ? "Not Now" : "Close"]])
end
ac5(c, false); dump_as("AC5_crash")
ac5(c, true); dump_as("AC5_next")
