# encoding: utf-8
# Mockups: four Double Abilities designs (topic 15). Each is two screens:
#  - the pair picker when fusing Azumarill (head) with Medicham (body): the
#    head's ability and the body's ability, with Huge Power + Pure Power
#    banned and the reason shown (new: Banned Pairs Explained);
#  - EBDX's battle scene with both of Joltras's abilities announced (Volt
#    Absorb from Jolteon, Water Absorb from Lapras): EBDX has one ability
#    pop-up, so KR adds the second.
# Design 1 = old KR's head-then-body choice, rebuilt in the improved Settings
# layout (the template for settings-like KR screens).
# Usage (from this folder): ruby da_designs.rb "<KIF Beta>" <work dir with metrics.json>
SRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "bmenu_designs.rb"), :encoding => "UTF-8")
eval(SRC.split("c = palette(2)\n")[0], binding, "bmenu_designs.rb")

def battle_text(c); end
CLEAR = Color.new(0, 0, 0, 0)
WARN = Color.new(240, 84, 72)
WHITE = Color.new(255, 255, 255)
HEAD_AB = [["Thick Fat", "Halves Fire and Ice damage."], ["Huge Power", "Doubles its Attack."], ["Sap Sipper", "Absorbs Grass moves."]]
BODY_AB = [["Pure Power", "Doubles its Attack."], ["Telepathy", "Dodges its allies' attacks."]]
BAN_REASON = "Can't pair with Huge Power: Attack x4."

def backdrop(name); MAPS.bitmap = Bitmap.new(File.join(HERE, "fx", name)); end
def value_cell(t, c, cx, y, v, sel, color = nil)
  vw = P.width(PF::TEXT, v)
  P.text(t, cx - vw / 2, y, vw + 2, 24, v, color || c[:opt])
  arrow = sel ? c[:txt] : c[:dim]
  UI.tri(t, cx - vw / 2 - 14, y + 8, :l, arrow, 4); UI.tri(t, cx + vw / 2 + 6, y + 8, :r, arrow, 4)
end
def banned_pill(t, x, y); P.pill(t, x, y, "BANNED", Color.new(70, 24, 24), WARN, false); end
def head_body_icons(t, c, x, y)
  mon(t, "AZUMARILL", x + 32, y + 30, 56); P.text(t, x, y + 58, 64, 12, "HEAD", c[:head], PF::TINY, 2)
  P.text(t, x + 64, y + 22, 20, 20, "+", c[:dim], PF::ROW, 2)
  mon(t, "MEDICHAM", x + 116, y + 30, 56); P.text(t, x + 84, y + 58, 64, 12, "BODY", c[:head], PF::TINY, 2)
end
# EBDX's ability pop-up: abilityMessage.png, a 2px white border, the text centred
def ebdx_popup(b, t, x, top, text, icon = nil)
  src = bmp(File.join(GFX, "EBDX/Pictures/UI/abilityMessage.png"))
  b.stretch_blt(Rect.new(x, top, 220, 48), src, Rect.new(0, 0, 220, 48))
  border = Color.new(255, 255, 255, 160)
  b.fill_rect(x, top, 220, 2, border); b.fill_rect(x, top + 46, 220, 2, border)
  b.fill_rect(x, top, 2, 48, border); b.fill_rect(x + 218, top, 2, 48, border)
  tx = x; tw = 220
  if icon
    mon(t, icon, x + 22, top + 22, 36); tx = x + 36; tw = 184
  end
  P.small(t, tx + 1, top + 16, tw, 17, text, Color.new(32, 32, 32), 2)
  P.small(t, tx, top + 15, tw, 17, text, WHITE, 2)
end
def shot(name); dump_as(name); end

c = palette(2)

#================================================================ DA1 Recommended: one screen in the Settings layout; pop-ups stacked with head/body icons
frame(c)
b = BASE.bitmap; t = TOP.bitmap
b.fill_rect(0, 0, W, H, c[:bg])
b.fill_rect(0, 0, W, 32, c[:panel2]); b.fill_rect(0, 31, W, 1, c[:line])
P.text(t, 0, 2, W, 28, "Fusion", c[:title], PF::TITLE, 2)
UI.rbox(b, 6, 36, 174, 262, 6, c[:panel])
head_body_icons(t, c, 14, 52)
P.small(t, 6, 140, 168, 16, "Azumarill + Medicham", c[:txt], 2)
P.small_wrap(t, "Both abilities stay active: one from the head, one from the body.", 152).first(4).each_with_index { |ln, k| P.small(t, 14, 166 + k * 16, 152, 16, ln, c[:dim]) }
UI.rbox(b, 180, 36, W - 6, 262, 6, c[:panel])
rows = [[:h, "ABILITIES"], [:r, "Head Ability", "Huge Power", nil], [:r, "Body Ability", "Pure Power", :banned],
        [:h, "FUSION"], [:r, "Nature", "Adamant", nil], [:r, "Nickname", "Azumarill", nil], [:tool, "Banned Pairs", nil, nil]]
y = 40; idx = 0
rows.each do |kind, label, v, flag|
  if kind == :h
    P.heading(t, 190, W - 16, y + 3, label, c[:head], c[:line]); y += 18; next
  end
  cursor_at(184, y, W - 194, 24) if idx == 1
  P.text(t, 196, y, 190, 24, label, c[:opt], PF::ROW)
  if kind == :tool
    P.pill(t, W - 18, y + 5, "OPEN", c[:pill], c[:txt])
  else
    value_cell(t, c, W - 76, y, v, idx == 1, flag == :banned ? c[:dim] : nil)
  end
  y += 24; idx += 1
end
UI.rbox(b, 6, 268, W - 6, H - 30, 6, c[:panel2], c[:line])
P.text(t, 14, 269, 330, 26, "Pure Power", c[:head], PF::ROW)
banned_pill(t, W - 14 - P.width(PF::TINY, "BANNED") - 12, 276)
P.small(t, 14, 297, W - 34, 17, BODY_AB[0][1], c[:txt])
P.small(t, 14, 314, W - 34, 17, BAN_REASON + " Pick Telepathy instead.", WARN)
hints(c, [[:ud, "Select"], [:lr, "Change"], [A_BTN, "Fuse"], [B_BTN, "Cancel"]])
shot("DA1_pick")
frame(c)
backdrop("da_battle.png")
b = BASE.bitmap; t = TOP.bitmap
ebdx_popup(b, t, 10, 176, "Joltras's Volt Absorb", "JOLTEON")
ebdx_popup(b, t, 10, 228, "Joltras's Water Absorb", "LAPRAS")
shot("DA1_battle")

#================================================================ DA2 Two Steps over the fusion scene (old KR's flow, as list pop-ups); one combined pop-up
frame(c)
backdrop("dnabg.png")
b = BASE.bitmap; t = TOP.bitmap
mon(t, "AZUMARILL", 150, 110, 96); mon(t, "MEDICHAM", 362, 110, 96)
P.text(t, 0, 160, W, 22, "Step 2 of 2", Color.new(40, 90, 50), PF::TINY, 2)
px = 136; pw = 240; py = 178
UI.rbox(b, px, py, px + pw, py + 26 + BODY_AB.length * 40 + 8, 6, col(c[:panel], 245), c[:line])
P.text(t, px, py + 4, pw, 22, "Ability 2 · Medicham", c[:title], PF::ROW, 2)
b.fill_rect(px + 8, py + 26, pw - 16, 1, c[:line])
BODY_AB.each_with_index do |(n, d), i|
  y = py + 30 + i * 40
  cursor_at(px + 4, y, pw - 8, 38) if i == 0
  P.text(t, px + 12, y, 140, 20, n, i == 0 ? c[:dim] : c[:txt], PF::TEXT)
  banned_pill(t, px + pw - 12 - P.width(PF::TINY, "BANNED") - 12, y + 3) if i == 0
  P.small(t, px + 12, y + 19, pw - 24, 16, i == 0 ? "With Huge Power: Attack x4" : d, i == 0 ? WARN : c[:dim])
end
P.text(t, 0, 304, W, 16, "ABILITY 1: HUGE POWER (AZUMARILL)", Color.new(40, 90, 50), PF::TINY, 2)
hints(c, [[:ud, "Select"], [A_BTN, "Choose"], [B_BTN, "Back to Ability 1"]])
shot("DA2_pick")
frame(c)
backdrop("da_battle.png")
b = BASE.bitmap; t = TOP.bitmap
src = bmp(File.join(GFX, "EBDX/Pictures/UI/abilityMessage.png"))
b.stretch_blt(Rect.new(10, 168, 220, 76), src, Rect.new(0, 0, 220, 48))
border = Color.new(255, 255, 255, 160)
b.fill_rect(10, 168, 220, 2, border); b.fill_rect(10, 242, 220, 2, border); b.fill_rect(10, 168, 2, 76, border); b.fill_rect(228, 168, 2, 76, border)
P.text(t, 11, 173, 220, 20, "Joltras's", Color.new(32, 32, 32), PF::TEXT, 2); P.text(t, 10, 172, 220, 20, "Joltras's", WHITE, PF::TEXT, 2)
P.text(t, 11, 195, 220, 20, "Volt Absorb", Color.new(32, 32, 32), PF::TEXT, 2); P.text(t, 10, 194, 220, 20, "Volt Absorb", WHITE, PF::TEXT, 2)
P.text(t, 11, 217, 220, 20, "Water Absorb", Color.new(32, 32, 32), PF::TEXT, 2); P.text(t, 10, 216, 220, 20, "Water Absorb", WHITE, PF::TEXT, 2)
shot("DA2_battle")

#================================================================ DA3 Head and Body Columns; the second pop-up from the other side
frame(c)
backdrop("dnabg.png")
b = BASE.bitmap; t = TOP.bitmap
UI.rbox(b, 8, 8, W - 8, 40, 6, col(c[:panel], 235), c[:line])
P.text(t, 8, 12, W - 16, 24, "Choose One Ability from Each", c[:title], PF::ROW, 2)
[[16, "AZUMARILL", "HEAD", HEAD_AB, 1], [264, "MEDICHAM", "BODY", BODY_AB, 0]].each_with_index do |(x, sp, tag, list, pick), col_i|
  UI.rbox(b, x, 48, x + 232, 300, 8, col(c[:panel], 240), c[:line])
  mon(t, sp, x + 30, 74, 48)
  P.text(t, x + 58, 58, 160, 20, sp.capitalize, c[:txt], PF::ROW)
  P.text(t, x + 58, 80, 100, 12, tag, c[:head], PF::TINY)
  list.each_with_index do |(n, d), i|
    y = 106 + i * 54
    on = i == pick
    banned = col_i == 1 && i == 0
    UI.rbox(b, x + 8, y, x + 224, y + 48, 6, on ? col(c[:sel], 255) : c[:dark], on ? (banned ? WARN : c[:selb]) : c[:line])
    P.text(t, x + 16, y + 3, 150, 20, n, banned ? c[:dim] : c[:txt], PF::TEXT)
    banned_pill(t, x + 216 - P.width(PF::TINY, "BANNED") - 12, y + 6) if banned
    P.small(t, x + 16, y + 24, 200, 16, banned ? "With Huge Power: Attack x4" : d, banned ? WARN : c[:dim])
  end
end
UI.rbox(b, 16, 308, W - 16, 348, 6, col(c[:panel2], 240), c[:line])
P.small(t, 24, 312, W - 48, 16, "Pure Power: " + BAN_REASON, WARN)
P.small(t, 24, 328, W - 48, 16, "Pick Telepathy, or change the head's ability.", c[:txt])
hints(c, [[:lr, "Head / Body"], [:ud, "Ability"], [A_BTN, "Fuse"], [B_BTN, "Cancel"]])
shot("DA3_pick")
frame(c)
backdrop("da_battle.png")
b = BASE.bitmap; t = TOP.bitmap
ebdx_popup(b, t, 10, 176, "Joltras's Volt Absorb")
ebdx_popup(b, t, 10, 228, "Joltras's Water Absorb")
P.pill(t, 10 + 220 - 4, 224, "2ND", Color.new(40, 40, 48), Color.new(255, 230, 120), true)
shot("DA3_battle")

#================================================================ DA4 Pairs List: every legal pair as one row; one pop-up with a 1/2 tag
frame(c)
b = BASE.bitmap; t = TOP.bitmap
b.fill_rect(0, 0, W, H, c[:bg])
b.fill_rect(0, 0, W, 32, c[:panel2]); b.fill_rect(0, 31, W, 1, c[:line])
P.text(t, 0, 2, W, 28, "Choose a Pair", c[:title], PF::TITLE, 2)
head_body_icons(t, c, 180, 40)
pairs = [["Huge Power", "Telepathy", nil], ["Thick Fat", "Pure Power", nil], ["Thick Fat", "Telepathy", nil], ["Sap Sipper", "Pure Power", nil],
         ["Sap Sipper", "Telepathy", nil], ["Huge Power", "Pure Power", :banned]]
UI.rbox(b, 16, 116, W - 16, 300, 6, c[:panel])
P.text(t, 28, 120, 200, 12, "AZUMARILL", c[:head], PF::TINY); P.text(t, 268, 120, 200, 12, "MEDICHAM", c[:head], PF::TINY)
pairs.each_with_index do |(a, bb, flag), i|
  y = 134 + i * 26
  cursor_at(20, y, W - 40, 25) if i == 0
  banned = flag == :banned
  P.text(t, 28, y, 220, 25, a, banned ? c[:dim] : c[:txt], PF::TEXT)
  P.text(t, 240, y, 20, 25, "+", c[:dim], PF::TEXT)
  P.text(t, 268, y, 160, 25, bb, banned ? c[:dim] : c[:txt], PF::TEXT)
  banned_pill(t, W - 28 - P.width(PF::TINY, "BANNED") - 12, y + 5) if banned
end
UI.rbox(b, 16, 306, W - 16, 348, 6, c[:panel2], c[:line])
P.small(t, 24, 310, W - 48, 16, "Huge Power + Telepathy: Attack x2, dodges allies' attacks.", c[:txt])
P.small(t, 24, 326, W - 48, 16, "Banned pairs sit at the bottom with their reason.", c[:dim])
hints(c, [[:ud, "Pair"], [A_BTN, "Fuse"], [B_BTN, "Cancel"]])
shot("DA4_pick")
frame(c)
backdrop("da_battle.png")
b = BASE.bitmap; t = TOP.bitmap
ebdx_popup(b, t, 10, 176, "Joltras's Water Absorb")
P.pill(t, 10 + 220 - 4, 172, "2/2", Color.new(40, 40, 48), Color.new(255, 230, 120), true)
shot("DA4_battle")

#================================================================ DA chosen: design 1's Settings layout with design 3's columns
frame(c)
b = BASE.bitmap; t = TOP.bitmap
b.fill_rect(0, 0, W, H, c[:bg])
b.fill_rect(0, 0, W, 32, c[:panel2]); b.fill_rect(0, 31, W, 1, c[:line])
P.text(t, 0, 2, W, 28, "Fusion", c[:title], PF::TITLE, 2)
[[6, "AZUMARILL", "HEAD", HEAD_AB, 1], [258, "MEDICHAM", "BODY", BODY_AB, 0]].each_with_index do |(x, sp, tag, list, pick), ci|
  UI.rbox(b, x, 36, x + 248, 196, 6, c[:panel])
  mon(t, sp, x + 22, 54, 36)
  P.text(t, x + 42, 38, 150, 22, sp.capitalize, c[:txt], PF::ROW)
  P.text(t, x + 248 - 50, 44, 40, 12, tag, c[:head], PF::TINY, 1)
  b.fill_rect(x + 8, 64, 232, 1, c[:line])
  list.each_with_index do |(n, _), i|
    y = 70 + i * 28
    chosen = i == (ci == 0 ? 1 : 1)
    banned = ci == 1 && i == 0
    cursor_at(x + 4, y, 240, 26) if banned
    UI.rbox(b, x + 12, y + 8, x + 22, y + 18, 5, chosen ? c[:selb] : c[:dark], c[:line])
    P.text(t, x + 30, y + 1, 150, 24, n, banned ? c[:dim] : c[:txt], PF::TEXT)
    banned_pill(t, x + 240 - P.width(PF::TINY, "BANNED") - 12, y + 6) if banned
  end
end
UI.rbox(b, 6, 200, W - 6, 262, 6, c[:panel])
P.text(t, 18, 204, 100, 24, "Nature", c[:opt], PF::ROW); value_cell(t, c, 190, 204, "Adamant", false)
P.text(t, 268, 204, 100, 24, "Nickname", c[:opt], PF::ROW); value_cell(t, c, 432, 204, "Azumarill", false)
P.text(t, 18, 231, 200, 24, "Banned Pairs", c[:opt], PF::ROW); P.pill(t, W - 18, 236, "OPEN", c[:pill], c[:txt])
UI.rbox(b, 6, 268, W - 6, H - 30, 6, c[:panel2], c[:line])
P.text(t, 14, 269, 330, 26, "Pure Power", c[:head], PF::ROW)
banned_pill(t, W - 14 - P.width(PF::TINY, "BANNED") - 12, 276)
P.small(t, 14, 297, W - 34, 17, BODY_AB[0][1], c[:txt])
P.small(t, 14, 314, W - 34, 17, BAN_REASON + " Pick Telepathy instead.", WARN)
hints(c, [[:lr, "Head / Body"], [:ud, "Ability"], [A_BTN, "Fuse"], [B_BTN, "Cancel"]])
shot("DAX_pick")

#================================================================ DA chosen, second page: Banned Pairs (opened from the Fusion screen)
BANNED = [["Wonder Guard", "Sturdy", "Nothing could knock it out."],
          ["Huge Power", "Pure Power", "Attack would be quadrupled."],
          ["Huge Power", "Water Bubble", "Attack would be quadrupled."],
          ["Pure Power", "Water Bubble", "Attack would be quadrupled."],
          ["Multiscale", "Shadow Shield", "Full-HP damage would be cut twice."],
          ["Illusion", "Imposter", "The two disguises break each other."],
          ["Shadow Tag", "Perish Body", "Traps foes and knocks them out."]]
frame(c)
b = BASE.bitmap; t = TOP.bitmap
b.fill_rect(0, 0, W, H, c[:bg])
b.fill_rect(0, 0, W, 32, c[:panel2]); b.fill_rect(0, 31, W, 1, c[:line])
P.text(t, 0, 2, W, 28, "Banned Pairs", c[:title], PF::TITLE, 2)
UI.rbox(b, 6, 36, W - 6, 262, 6, c[:panel])
P.text(t, 18, 40, 200, 12, "HEAD OR BODY", c[:head], PF::TINY); P.text(t, 232, 40, 200, 12, "CAN'T PAIR WITH", c[:head], PF::TINY)
b.fill_rect(14, 54, W - 28, 1, c[:line])
BANNED.each_with_index do |(a, bb, _), i|
  y = 58 + i * 28
  cursor_at(10, y, W - 20, 26) if i == 1
  P.text(t, 18, y + 1, 190, 24, a, c[:txt], PF::TEXT)
  UI.tri(t, 206, y + 9, :r, c[:dim], 4)
  P.text(t, 232, y + 1, 190, 24, bb, c[:txt], PF::TEXT)
  P.pill(t, W - 18, y + 6, "x4 ATK", Color.new(70, 24, 24), WARN, true) if [1, 2, 3].include?(i)
end
UI.rbox(b, 6, 268, W - 6, H - 30, 6, c[:panel2], c[:line])
P.text(t, 14, 269, 400, 26, "Huge Power + Pure Power", c[:head], PF::ROW)
P.small(t, 14, 297, W - 34, 17, "Both double the Attack stat, so together it would be quadrupled.", c[:txt])
P.small(t, 14, 314, W - 34, 17, "Pick a different ability for the head or the body.", c[:dim])
hints(c, [[:ud, "Scroll"], [B_BTN, "Back"]])
shot("DAX_banned")
