# encoding: utf-8
# Mockups: Trainer Control (topic 16).
#  Designs 1-4, two screens each: the Battle Records screen (old KR's records:
#  wins, losses, win rate, battles, streak, best; rewards at 3, 7 and 12
#  wins; Pink Slips) and the moment before a battle in Cerulean (the record
#  toast and the Pink Slip wager offer).
#  Trainer Card A-B: the new Records on Trainer Card.
# Design 1 = old KR's Battle Records (list, detail, search) and its toast and
# Pink Slips prompts, rebuilt in our UI kit.
# Usage (from this folder): ruby tc_designs.rb "<KIF Beta>" <work dir with metrics.json>
SRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "bmenu_designs.rb"), :encoding => "UTF-8")
eval(SRC.split("c = palette(2)\n")[0], binding, "bmenu_designs.rb")

def battle_text(c); end
WARN = Color.new(240, 84, 72)
PINK = Color.new(240, 120, 170)
# [name, kind, trainer sprite, wins, losses, streak, best]
REC = [["Bug Catcher Rick", "Regular", "BUGCATCHER", 3, 0, 3, 3],
       ["Misty", "Gym Leader", "LEADER_Misty", 2, 1, 1, 2],
       ["Rival Blue", "Rival", "RIVAL1", 2, 2, 0, 1],
       ["Youngster Ben", "Regular", "YOUNGSTER", 4, 0, 4, 4],
       ["Lass Haley", "Rematch", "LASS", 1, 1, 0, 1],
       ["Camper Shane", "Regular", "CAMPER", 0, 1, 0, 0],
       ["Hiker Marcos", "Regular", "HIKER", 1, 0, 1, 1]]
SELR = 0
def backdrop(name); MAPS.bitmap = Bitmap.new(File.join(HERE, "fx", name)); end
def trainer_pic(b, sp, cx, cy, size)
  i = bmp(File.join(GFX, "Trainers", sp + ".png"))
  b.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), i, Rect.new(0, 0, i.height, i.height))
end
def search_field(c, x, y, w, text = "")
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, x, y, x + w, y + 22, 5, c[:dark], c[:line])
  UI.rbox(b, x + 8, y + 6, x + 17, y + 15, 4, c[:dim]); UI.rbox(b, x + 10, y + 8, x + 15, y + 13, 2, c[:dark])
  3.times { |k| b.fill_rect(x + 16 + k, y + 14 + k, 2, 2, c[:dim]) }
  P.text(t, x + 24, y, w - 28, 22, text.empty? ? "Search Trainers" : text, c[:dim])
end
def stat(t, c, x, y, label, value, color = nil)
  P.text(t, x, y, 90, 12, label.upcase, c[:head], PF::TINY)
  P.text(t, x, y + 12, 90, 22, value.to_s, color || c[:txt], PF::ROW)
end
def reward_pips(b, t, c, x, y, wins)
  [3, 7, 12].each_with_index do |n, i|
    got = wins >= n
    UI.rbox(b, x + i * 60, y, x + i * 60 + 52, y + 20, 6, got ? col(GOLD, 255) : c[:dark], got ? GOLD : c[:line])
    P.text(t, x + i * 60, y, 52, 20, "#{n} WINS", got ? Color.new(40, 30, 0) : c[:dim], PF::TINY, 2)
  end
end
def toast(c, x, y, w, sp, title, line)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, x, y, x + w, y + 44, 8, col(c[:panel], 240), c[:line])
  trainer_pic(t, sp, x + 24, y + 22, 40)
  P.text(t, x + 48, y + 3, w - 56, 20, title, c[:txt], PF::TEXT)
  P.small(t, x + 48, y + 23, w - 56, 16, line, c[:dim])
end
def bubble(b, t, x, y)
  UI.rbox(b, x, y, x + 18, y + 20, 6, Color.new(255, 255, 255), Color.new(40, 40, 48))
  P.text(t, x, y + 1, 18, 18, "!", WARN, PF::ROW, 2)
end
def ow(c)
  frame(c)
  backdrop("ow_trainer.png")
  bubble(BASE.bitmap, TOP.bitmap, 359, 116)
end
def choice(c, x, y, w, items, sel)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, x, y, x + w, y + 8 + items.length * 24, 6, col(c[:panel], 245), c[:line])
  items.each_with_index do |s, i|
    cursor_at(x + 4, y + 4 + i * 24, w - 8, 23) if i == sel
    P.text(t, x + 14, y + 4 + i * 24, w - 20, 23, s, c[:txt], PF::TEXT)
  end
end
def msg(c, text, sub = nil)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 8, 300, W - 8, 376, 8, col(c[:panel], 245), c[:line])
  P.text(t, 22, 308, W - 44, 24, text, c[:txt], PF::ROW)
  P.small(t, 22, 336, W - 44, 16, sub, c[:dim]) if sub
end
def shot(name); dump_as(name); end

c = palette(2)
r = REC[SELR]

#================================================================ TC1 Recommended: old KR's records, rebuilt; toast + wager dialog
frame(c)
b = BASE.bitmap; t = TOP.bitmap
b.fill_rect(0, 0, W, H, c[:bg])
b.fill_rect(0, 0, W, 32, c[:panel2]); b.fill_rect(0, 31, W, 1, c[:line])
P.text(t, 0, 2, W, 28, "Battle Records", c[:title], PF::TITLE, 2)
UI.rbox(b, 6, 36, 214, H - 30, 6, c[:panel])
search_field(c, 12, 42, 196)
REC.each_with_index do |(n, k, sp, w, l, _, _), i|
  y = 70 + i * 36
  cursor_at(10, y, 200, 34) if i == SELR
  trainer_pic(t, sp, 28, y + 17, 30)
  cls, short = n.include?(" ") ? [n[0...n.rindex(" ")], n[n.rindex(" ") + 1..-1]] : [k, n]
  cls = k if n == "Misty"
  P.text(t, 46, y + 1, 100, 18, short, c[:txt], PF::TEXT)
  P.text(t, 46, y + 19, 100, 12, cls.upcase, c[:head], PF::TINY)
  P.text(t, 150, y + 6, 54, 20, "#{w}-#{l}", w > l ? GREEN : (w < l ? RED : c[:dim]), PF::TEXT, 1)
end
UI.rbox(b, 220, 36, W - 6, H - 30, 6, c[:panel])
trainer_pic(t, r[2], 268, 82, 80)
P.text(t, 316, 50, 180, 22, r[0], c[:txt], PF::ROW)
P.text(t, 316, 74, 180, 12, "#{r[1].upcase} · ROUTE 24", c[:head], PF::TINY)
P.small(t, 316, 90, 180, 16, "Last battle: 2 days ago", c[:dim])
b.fill_rect(230, 128, W - 246, 1, c[:line])
stat(t, c, 236, 134, "Wins", r[3], GREEN); stat(t, c, 326, 134, "Losses", r[4], RED); stat(t, c, 416, 134, "Win Rate", "100%")
stat(t, c, 236, 172, "Battles", r[3] + r[4]); stat(t, c, 326, 172, "Streak", r[5], GOLD); stat(t, c, 416, 172, "Best", r[6])
b.fill_rect(230, 212, W - 246, 1, c[:line])
P.text(t, 236, 218, 200, 12, "REWARDS", c[:head], PF::TINY)
reward_pips(b, t, c, 236, 232, r[3])
P.small(t, 236, 258, 260, 16, "Next: 7 wins, a Rare Candy.", c[:dim])
P.text(t, 236, 284, 200, 12, "PINK SLIPS", c[:head], PF::TINY)
P.small(t, 236, 298, 260, 16, "Won 1, lost 0. Won his Beedrill.", c[:txt])
hints(c, [[:ud, "Trainer"], [X_BTN, "Search"], [Y_BTN, "Reset"], [B_BTN, "Back"]])
shot("TC1_records")
ow(c)
toast(c, 8, 8, 300, "BUGCATCHER", "Bug Catcher Rick", "3-0 · Streak 3 · Reward at 7 wins")
choice(c, 312, 238, 192, ["Wager a Pokémon", "Just Battle"], 0)
msg(c, "Pink Slips: Wager a Pokémon?", "Win and you claim one of his. Lose and he takes yours.")
shot("TC1_battle")

#================================================================ TC2 Trainer Cards grid; VS banner before battle
frame(c)
b = BASE.bitmap; t = TOP.bitmap
b.fill_rect(0, 0, W, H, c[:bg])
b.fill_rect(0, 0, W, 32, c[:panel2]); b.fill_rect(0, 31, W, 1, c[:line])
P.text(t, 0, 2, W, 28, "Battle Records", c[:title], PF::TITLE, 2)
REC.first(6).each_with_index do |(n, k, sp, w, l, s, _), i|
  x = 8 + (i % 3) * 166; y = 40 + (i / 3) * 152
  UI.rbox(b, x, y, x + 160, y + 144, 8, c[:panel], i == SELR ? c[:selb] : c[:line])
  cursor_at(x + 2, y + 2, 156, 140) if i == SELR
  trainer_pic(t, sp, x + 80, y + 52, 84)
  P.text(t, x, y + 96, 160, 20, n, c[:txt], PF::TEXT, 2)
  P.text(t, x, y + 116, 160, 20, "#{w}-#{l}", w > l ? GREEN : (w < l ? RED : c[:dim]), PF::ROW, 2)
  P.pill(t, x + 154, y + 6, "STREAK #{s}", Color.new(60, 50, 10), GOLD, true) if s >= 3
end
hints(c, [[:ud, "Choose"], [A_BTN, "Details"], [X_BTN, "Search"], [B_BTN, "Back"]])
shot("TC2_records")
ow(c)
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 8, 8, W - 8, 92, 10, col(c[:panel], 240), c[:line])
trainer_pic(t, "BUGCATCHER", 52, 50, 76)
P.text(t, 96, 14, 200, 22, "Bug Catcher Rick", c[:txt], PF::ROW)
P.text(t, 96, 38, 200, 12, "3 WINS · 0 LOSSES · STREAK 3", c[:head], PF::TINY)
reward_pips(b, t, c, 96, 58, 3)
P.text(t, W - 70, 26, 60, 40, "VS", Color.new(240, 200, 70), PF::TITLE, 2)
msg(c, "Pink Slips: Wager a Pokémon?", "A: Wager · B: Just Battle")
shot("TC2_battle")

#================================================================ TC3 Logbook by area; record chip over the trainer, wager side panel
frame(c)
b = BASE.bitmap; t = TOP.bitmap
b.fill_rect(0, 0, W, H, c[:bg])
b.fill_rect(0, 0, W, 32, c[:panel2]); b.fill_rect(0, 31, W, 1, c[:line])
P.text(t, 0, 2, W, 28, "Battle Records", c[:title], PF::TITLE, 2)
UI.rbox(b, 6, 36, W - 6, H - 30, 6, c[:panel])
groups = [["ROUTE 24", [0, 3]], ["CERULEAN GYM", [1]], ["ROUTE 3", [4, 5, 6]], ["RIVAL", [2]]]
y = 40
groups.each do |g, idx|
  P.heading(t, 16, W - 16, y + 3, g, c[:head], c[:line]); y += 18
  idx.each do |i|
    n, k, sp, w, l, s, best = REC[i]
    cursor_at(10, y, W - 20, 24) if i == SELR
    trainer_pic(t, sp, 30, y + 12, 22)
    P.text(t, 48, y, 200, 24, n, c[:txt], PF::TEXT)
    P.text(t, 250, y, 60, 24, "#{w}-#{l}", w > l ? GREEN : (w < l ? RED : c[:dim]), PF::TEXT, 1)
    P.text(t, 330, y + 6, 160, 14, "STREAK #{s} · BEST #{best}", c[:dim], PF::TINY)
    y += 24
  end
end
hints(c, [[:ud, "Trainer"], [A_BTN, "Details"], [X_BTN, "Search"], [B_BTN, "Back"]])
shot("TC3_records")
ow(c)
b = BASE.bitmap; t = TOP.bitmap
P.pill(t, 312, 96, "3-0 · STREAK 3", col(c[:panel], 240), GREEN, false)
UI.rbox(b, 8, 124, 176, 292, 8, col(c[:panel], 245), c[:line])
P.text(t, 8, 128, 168, 20, "Wager Which?", c[:title], PF::TEXT, 2)
[["PIKACHU", "Pikachu", "Lv34"], ["LAPRAS", "Lapras", "Lv33"], ["ONIX", "Onix", "Lv30"]].each_with_index do |(sp, n, lv), i|
  yy = 152 + i * 34
  cursor_at(12, yy, 160, 32) if i == 1
  mon(t, sp, 32, yy + 16, 32)
  P.text(t, 52, yy + 4, 80, 22, n, c[:txt], PF::TEXT)
  P.text(t, 124, yy + 4, 44, 22, lv, c[:dim], PF::TINY, 1)
end
P.text(t, 8, 258, 168, 22, "Just Battle", c[:dim], PF::TEXT, 2)
msg(c, "Pink Slips: Wager a Pokémon?", "Win and you claim one of his.")
shot("TC3_battle")

#================================================================ TC4 Tabs and a table; record line in the message box
frame(c)
b = BASE.bitmap; t = TOP.bitmap
b.fill_rect(0, 0, W, H, c[:bg])
b.fill_rect(0, 0, W, 32, c[:panel2]); b.fill_rect(0, 31, W, 1, c[:line])
P.text(t, 0, 2, W, 28, "Battle Records", c[:title], PF::TITLE, 2)
tabs = ["All", "Gym Leaders", "Rematches", "Pink Slips"]
tw = (W - 16) / tabs.length
tabs.each_with_index do |tb, i|
  on = i == 0
  UI.rbox(b, 8 + i * tw + 1, 36, 8 + (i + 1) * tw - 2, 56, 4, on ? c[:sel] : c[:dark], on ? c[:selb] : c[:line])
  P.text(t, 8 + i * tw, 36, tw, 20, tb, on ? c[:white] : c[:dim], PF::TEXT, 2)
end
UI.rbox(b, 6, 62, W - 6, H - 30, 6, c[:panel])
cols = [["TRAINER", 18, 0], ["W", 250, 2], ["L", 296, 2], ["STREAK", 340, 2], ["BEST", 410, 2]]
cols.each { |l, x, a| P.text(t, x, 66, a == 2 ? 50 : 200, 12, l, c[:head], PF::TINY, a) }
b.fill_rect(14, 80, W - 28, 1, c[:line])
REC.each_with_index do |(n, k, sp, w, l, s, best), i|
  y = 84 + i * 26
  cursor_at(10, y, W - 20, 25) if i == SELR
  P.text(t, 18, y, 220, 25, n, c[:txt], PF::TEXT)
  P.text(t, 250, y, 50, 25, w.to_s, GREEN, PF::TEXT, 2)
  P.text(t, 296, y, 50, 25, l.to_s, RED, PF::TEXT, 2)
  P.text(t, 340, y, 50, 25, s.to_s, s >= 3 ? GOLD : c[:txt], PF::TEXT, 2)
  P.text(t, 410, y, 50, 25, best.to_s, c[:txt], PF::TEXT, 2)
end
hints(c, [[:lr, "Tabs"], [:ud, "Trainer"], [X_BTN, "Search"], [B_BTN, "Back"]])
shot("TC4_records")
ow(c)
msg(c, "Bug Catcher Rick: 3-0, Streak 3. Wager a Pokémon?", "Pink Slips: win and you claim one of his.")
choice(c, W - 176, 238, 168, ["Wager", "Just Battle"], 0)
shot("TC4_battle")

#================================================================ Trainer Card A: a Records side (flip the card)
card_text = lambda do |t, label, value, y|
  P.text(t, 35, y + 1, 200, 24, label, Color.new(160, 160, 160), PF::ROW); P.text(t, 34, y, 200, 24, label, Color.new(72, 72, 72), PF::ROW)
  P.text(t, 103, y + 1, 200, 24, value, Color.new(160, 160, 160), PF::ROW, 1); P.text(t, 102, y, 200, 24, value, Color.new(72, 72, 72), PF::ROW, 1)
end
frame(c)
backdrop("tcard.png")
b = BASE.bitmap; t = TOP.bitmap
P.text(t, 332, 40, 140, 22, "RECORDS", Color.new(72, 72, 72), PF::ROW, 2)
[["Wins", "42"], ["Losses", "7"], ["Best Streak", "12"], ["Pink Slips Won", "5"], ["Gym Rematches", "9"]].each_with_index { |(l, v), i| card_text.call(t, l, v, 64 + i * 48) }
P.pill(t, 482, 352, "SIDE 2/2", Color.new(40, 60, 110), Color.new(220, 235, 255), true)
hints(c, [[A_BTN, "Flip"], [B_BTN, "Close"]])
shot("TCA_card")

#================================================================ Trainer Card B: a record strip on the front
frame(c)
backdrop("tcard.png")
b = BASE.bitmap; t = TOP.bitmap
[["Name", "Red"], ["Money", "$12,450"], ["Pokédex", "88/140"], ["Time", "24:13"], ["Started", "Oct 12, 2026"]].each_with_index { |(l, v), i| card_text.call(t, l, v, 64 + i * 48) }
P.text(t, 332, 40, 140, 22, "ID 04821", Color.new(72, 72, 72), PF::ROW, 2)
UI.rbox(b, 332, 256, 470, 282, 6, Color.new(40, 60, 110, 220))
P.text(t, 332, 257, 138, 24, "42-7 · BEST 12", Color.new(230, 240, 255), PF::TEXT, 2)
hints(c, [[A_BTN, "Records"], [B_BTN, "Close"]])
shot("TCB_card")
