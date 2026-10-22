# encoding: utf-8
# Mockups: Trainer Card, the Records tab (five designs), in the Front's style:
# the lanyard card, Glass White, black text, coloured values (wins green,
# losses red, streaks gold, win rate by how high it is). Records come from
# Trainer Control (topic 16); A opens Battle Records.
# Design 1 = the Portrait card turned to its back.
# Usage (from this folder): ruby tcrecords.rb "<KIF Beta>" <work dir with metrics.json>
SRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "tclanyard.rb"), :encoding => "UTF-8")
eval(SRC.split("c = palette(2)\n")[0], binding, "tclanyard.rb")

WIN = pif("Green"); LOSS = pif("Red"); STREAK = BLACK
def rate_color(p); p >= 67 ? WIN : (p >= 34 ? pif("Orange") : LOSS); end
RECS = [["Wins", "42", WIN], ["Losses", "7", LOSS], ["Battles", "49", BLACK], ["Best Streak", "12", STREAK],
        ["Current Streak", "3", STREAK], ["Pink Slips Won", "5", pif("Magenta")], ["Gym Rematches", "9", BLACK]]
LAST5 = [true, true, false, true, true]
RIVALS = [["RIVAL1", "Rival Blue", 2, 2], ["LEADER_Misty", "Misty", 2, 1], ["BUGCATCHER", "Bug Catcher Rick", 3, 0]]
def tabs_on(b, t, x, y, on)
  widths = TABS.map { |p| P.width(PF::TINY, p.upcase) + 12 }
  TABS.each_with_index do |p, i|
    sel = i == on
    UI.rbox(b, x, y, x + widths[i], y + 15, 5, sel ? Color.new(40, 96, 176) : Color.new(250, 252, 255, 160))
    P.text(t, x, y, widths[i], 16, p.upcase, sel ? Color.new(255, 255, 255) : BLACK, PF::TINY, 2)
    x += widths[i] + 4
  end
end
def ring(b, cx, cy, r, th, pct, colr)
  steps = (2 * Math::PI * r).ceil
  (0...steps).each do |s|
    deg = s * 360.0 / steps
    a = (deg - 90) * Math::PI / 180
    on = deg < pct * 3.6
    th.times { |k| rr = r - k; b.fill_rect((cx + rr * Math.cos(a)).round, (cy + rr * Math.sin(a)).round, 2, 2, on ? colr : Color.new(255, 255, 255, 120)) }
  end
end
def pips(b, t, x, y)
  LAST5.each_with_index do |w, i|
    UI.rbox(b, x + i * 22, y, x + i * 22 + 18, y + 18, 9, w ? WIN : LOSS)
    P.text(t, x + i * 22, y + 1, 18, 16, w ? "W" : "L", Color.new(255, 255, 255), PF::TINY, 2)
  end
end
def trainer_pic(t, sp, cx, cy, size)
  i = bmp(File.join(GFX, "Trainers", sp + ".png"))
  t.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), i, Rect.new(0, 0, i.height, i.height))
end
HR = [[:lr, "Tabs"], [A_BTN, "Battle Records"], [B_BTN, "Close"]]

c = palette(2)

#================================================================ TR1 Recommended: the Portrait card turned to its back
base(c)
b = BASE.bitmap; t = TOP.bitmap
tabs_on(b, t, 236, 26, 1)
strap(b, 116, 152, 20, 58); clip(b, 136, 50)
glass(b, 44, 62, 184, 290, 10)
stx(t, 44, 68, 184, 22, "Records", BLACK, PF::ROW, 2)
title_id(t, 44, 184, 90, "RED", " · ID 04821")
b.fill_rect(56, 106, 160, 1, Color.new(255, 255, 255, 200))
RECS.each_with_index { |(l, v, cl), i| y = 112 + i * 22; stx(t, 56, y + 4, 110, 12, l.upcase, BLACK, PF::TINY); stx(t, 56, y, 160, 20, v, cl, PF::TEXT, 1) }
b.fill_rect(56, 270, 160, 1, Color.new(255, 255, 255, 200))
stx(t, 56, 276, 160, 12, "LAST 5 BATTLES", BLACK, PF::TINY)
pips(b, t, 56, 292)
red(t, 380, 236, 150)
glass(b, 300, 244, 160, 80, 10)
stx(t, 300, 250, 160, 12, "WIN RATE", BLACK, PF::TINY, 2)
stx(t, 300, 266, 160, 34, "86%", rate_color(86), PF::TITLE, 2)
ssm(t, 300, 300, 160, 16, "42 of 49 Battles", BLACK, 2)
hints(c, HR)
shot("TR1")

#================================================================ TR2 Two Cards: the records card clipped behind the ID
base(c)
b = BASE.bitmap; t = TOP.bitmap
tabs_on(b, t, 236, 26, 1)
strap(b, 150, 186, 20, 56); clip(b, 170, 48)
glass(b, 96, 70, 184, 250, 10, 110)
P.text(t, 96, 76, 184, 12, "RED · ID 04821", BLACK, PF::TINY, 2)
glass(b, 44, 96, 200, 248, 10, 175)
P.text(t, 44, 102, 200, 22, "Records", BLACK, PF::ROW, 2)
RECS.each_with_index { |(l, v, cl), i| y = 128 + i * 24; P.text(t, 56, y + 5, 120, 12, l.upcase, BLACK, PF::TINY); P.text(t, 56, y, 176, 22, v, cl, PF::ROW, 1) }
b.fill_rect(56, 300, 176, 1, Color.new(255, 255, 255, 200))
pips(b, t, 76, 310)
red(t, 400, 300, 170)
hints(c, HR)
shot("TR2")

#================================================================ TR3 Scoreboard: big W and L numbers on the art, a mini ID
base(c)
b = BASE.bitmap; t = TOP.bitmap
tabs_on(b, t, 236, 26, 1)
strap(b, 96, 120, 20, 50); clip(b, 108, 44)
glass(b, 44, 58, 128, 128, 10)
UI.rbox(b, 60, 66, 156, 132, 8, Color.new(255, 255, 255, 110))
red(t, 108, 132, 62)
P.text(t, 44, 136, 128, 22, "Red", BLACK, PF::ROW, 2)
P.text(t, 44, 160, 128, 12, "ID 04821", BLACK, PF::TINY, 2)
glass(b, 196, 58, 140, 110, 12)
P.text(t, 196, 64, 140, 12, "WINS", BLACK, PF::TINY, 2); P.text(t, 196, 82, 140, 60, "42", WIN, PF::TITLE, 2)
glass(b, 346, 58, 140, 110, 12)
P.text(t, 346, 64, 140, 12, "LOSSES", BLACK, PF::TINY, 2); P.text(t, 346, 82, 140, 60, "7", LOSS, PF::TITLE, 2)
chips = [["WIN RATE", "86%", rate_color(86)], ["BEST STREAK", "12", STREAK], ["STREAK", "3", STREAK], ["PINK SLIPS", "5", Color.new(210, 80, 150)], ["GYM REMATCHES", "9", BLACK], ["BATTLES", "49", BLACK]]
chips.each_with_index do |(l, v, cl), i|
  x = 44 + (i % 3) * 148; y = 192 + (i / 3) * 62
  glass(b, x, y, 140, 54, 10)
  P.text(t, x, y + 6, 140, 12, l, BLACK, PF::TINY, 2)
  P.text(t, x, y + 20, 140, 28, v, cl, PF::TITLE, 2)
end
pips(b, t, 200, 322)
hints(c, HR)
shot("TR3")

#================================================================ TR4 Rivals: totals on the card, your most-battled trainers beside it
base(c)
b = BASE.bitmap; t = TOP.bitmap
tabs_on(b, t, 236, 26, 1)
strap(b, 116, 152, 20, 58); clip(b, 136, 50)
glass(b, 44, 62, 184, 290, 10)
P.text(t, 44, 68, 184, 22, "Records", BLACK, PF::ROW, 2)
ring(b, 136, 146, 44, 6, 86, rate_color(86))
P.text(t, 92, 128, 88, 30, "86%", rate_color(86), PF::TITLE, 2)
P.text(t, 92, 158, 88, 12, "WIN RATE", BLACK, PF::TINY, 2)
RECS.first(5).each_with_index { |(l, v, cl), i| y = 200 + i * 22; P.text(t, 56, y + 4, 110, 12, l.upcase, BLACK, PF::TINY); P.text(t, 56, y, 160, 20, v, cl, PF::TEXT, 1) }
pips(b, t, 82, 316)
glass(b, 244, 62, 240, 250, 10)
P.text(t, 256, 68, 200, 12, "MOST BATTLED", BLACK, PF::TINY)
RIVALS.each_with_index do |(sp, n, w, l), i|
  y = 86 + i * 74
  UI.rbox(b, 252, y, 476, y + 68, 8, Color.new(255, 255, 255, 120))
  trainer_pic(t, sp, 286, y + 34, 60)
  P.text(t, 322, y + 8, 150, 22, n, BLACK, PF::TEXT)
  P.text(t, 322, y + 32, 70, 26, "#{w}-#{l}", w > l ? WIN : (w < l ? LOSS : BLACK), PF::ROW)
  P.text(t, 394, y + 38, 76, 12, "#{w + l} BATTLES", BLACK, PF::TINY, 1)
end
hints(c, HR)
shot("TR4")

#================================================================ TR5 Ring on the Art: a big win-rate ring by your trainer, chips around it
base(c)
b = BASE.bitmap; t = TOP.bitmap
tabs_on(b, t, 236, 26, 1)
ring(b, 262, 190, 84, 8, 86, rate_color(86))
red(t, 262, 250, 132)
glass(b, 210, 290, 104, 44, 10)
P.text(t, 210, 294, 104, 12, "WIN RATE", BLACK, PF::TINY, 2); P.text(t, 210, 306, 104, 22, "86%", rate_color(86), PF::ROW, 2)
left = [["WINS", "42", WIN], ["LOSSES", "7", LOSS], ["BATTLES", "49", BLACK]]
right = [["BEST STREAK", "12", STREAK], ["PINK SLIPS", "5", Color.new(210, 80, 150)], ["GYM REMATCHES", "9", BLACK]]
left.each_with_index { |(l, v, cl), i| y = 80 + i * 76; glass(b, 40, y, 128, 60, 10); P.text(t, 40, y + 6, 128, 12, l, BLACK, PF::TINY, 2); P.text(t, 40, y + 20, 128, 32, v, cl, PF::TITLE, 2) }
right.each_with_index { |(l, v, cl), i| y = 80 + i * 76; glass(b, 356, y, 128, 60, 10); P.text(t, 356, y + 6, 128, 12, l, BLACK, PF::TINY, 2); P.text(t, 356, y + 20, 128, 32, v, cl, PF::TITLE, 2) }
pips(b, t, 40, 322)
hints(c, HR)
shot("TR5")
