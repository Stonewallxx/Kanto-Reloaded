# encoding: utf-8
# The chosen Battle Menu (topic 11, design 1) and Battle Tools (topic 12,
# design 1) redrawn on EBDX's own battle scene (KR's battle features are EBDX
# only), in their agreed state: the Battle Menu lists Battle Info, Quick Throw
# (the Favourite), Turn Log and Mod Actions; Matchup View is a tab of Battle
# Info (tabs: Pikachu, Gyarados, Matchup, Field, Turn Log). The Field Strip sits
# above EBDX's command buttons; the catch chance beside Gyarados's HP bar.
# Backdrop: ebdx_backdrop.py singles command -> fx/e_singles_cmd.png
# Usage (from this folder): ruby ebdx_redraw.rb "<KIF Beta>" <work dir with metrics.json>
SRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "bmenu_designs.rb"), :encoding => "UTF-8")
eval(SRC.split("c = palette(2)\n")[0], binding, "bmenu_designs.rb")

def battle_text(c); end   # EBDX's own text is in the backdrop
MAPS.bitmap = Bitmap.new(File.join(HERE, "fx", "e_singles_cmd.png"))

MENU = [["Battle Info", "", "Stats and effects for every Pokémon, matchups and the field.", "SCOPELENS"],
        ["Quick Throw", "x12 · 52%", "Throws the Favourite ball without opening the Bag.", "POKEBALL"],
        ["Turn Log", "Turn 6", "What happened each turn: moves, damage, status and fainting.", "TOWNMAP"],
        ["Mod Actions", "2", "Commands added by other mods.", "DEVONSCOPE"]]
MENU_FAV = 1
MENU_SEL = 0
INFO_TABS = ["Pikachu", "Gyarados", "Matchup", "Field", "Turn Log"]
BALLS = [["NETBALL", "Net Ball", 4, 52, "x3.5 on Water"], ["ULTRABALL", "Ultra Ball", 6, 36, "x2"], ["GREATBALL", "Great Ball", 9, 27, "x1.5"],
         ["POKEBALL", "Poké Ball", 12, 18, "x1"], ["DUSKBALL", "Dusk Ball", 3, 18, "x3 at night"], ["QUICKBALL", "Quick Ball", 2, 18, "x5 on turn 1"]]
BEST = 0
# [move, type id, effect text, multiplier, colour key]
MATCH = [["Discharge", 13, "Super Effective", "x4", :good], ["Iron Tail", 8, "Not Very Effective", "x0.5", :bad],
         ["Dig", 4, "No Effect", "x0", :dim], ["Quick Attack", 0, "Effective", "x1", :ok]]
PROFILE = [["Weak To", [13, 5]], ["Resists", [1, 6, 8, 10, 11]], ["Immune To", [4]]]
def ecol(k, c); { :good => GREEN, :ok => c[:txt], :bad => RED, :dim => c[:dim] }[k]; end
def bar(b, x, y, w, pctv, colr, c)
  b.fill_rect(x, y, w, 5, c[:dark]); b.fill_rect(x, y, (w * pctv / 100.0).round, 5, colr)
end
# catch chance beside Gyarados's HP bar (EBDX's foe databox: (0, 52), 224 wide)
def catch_tag(c)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 228, 52, 300, 70, 6, col(c[:panel], 235), GREEN)
  item_icon(t, "NETBALL", 240, 61, 14)
  P.text(t, 250, 52, 48, 18, "52%", GREEN, PF::TEXT, 2)
end
# Battle Info's frame: a dimmed scene, the panel, the tab row
def info_frame(c, on)
  frame(c, 160)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 16, 16, W - 17, 352, 8, col(c[:panel], 248), c[:line])
  tw = (W - 48) / INFO_TABS.length
  INFO_TABS.each_with_index do |tb, i|
    sel = i == on
    UI.rbox(b, 24 + i * tw + 1, 24, 24 + (i + 1) * tw - 2, 44, 4, sel ? c[:sel] : c[:dark], sel ? c[:selb] : c[:line])
    P.text(t, 24 + i * tw, 24, tw, 20, tb, sel ? c[:white] : c[:dim], PF::TEXT, 2)
  end
end

c = palette(2)

#================================================================ Battle Menu: open over EBDX's command screen
frame(c)
b = BASE.bitmap; t = TOP.bitmap
field_strip(c, 305)
px = 126; pw = 260; py = 84
UI.rbox(b, px, py, px + pw, py + 26 + MENU.length * 24 + 6, 6, col(c[:panel], 240), c[:line])
P.text(t, px, py + 4, pw, 22, "Battle Menu", c[:title], PF::ROW, 2)
b.fill_rect(px + 8, py + 26, pw - 16, 1, c[:line])
MENU.each_with_index do |(l, st, d, ic), i|
  y = py + 30 + i * 24
  cursor_at(px + 4, y, pw - 8, 23) if i == MENU_SEL
  item_icon(t, ic, px + 18, y + 11, 18)
  P.text(t, px + 32, y, 140, 23, l, i == MENU_FAV ? GOLD : c[:txt], PF::TEXT)
  star(t, px + 34 + P.width(PF::TEXT, l) + 4, y + 8, GOLD) if i == MENU_FAV
  P.text(t, px + pw - 90, y, 80, 23, st, c[:acc], PF::TINY, 1) unless st.empty?
end
dy = py + 26 + MENU.length * 24 + 10
UI.rbox(b, px, dy, px + pw, dy + 58, 6, col(c[:panel2], 240), c[:line])
P.small_wrap(t, MENU[MENU_SEL][2], pw - 16).first(2).each_with_index { |ln, k| P.small(t, px + 8, dy + 6 + k * 16, pw - 16, 16, ln, c[:txt]) }
P.text(t, px, dy + 41, pw, 14, "PAGE 1/2  ·  LB/RB", c[:dim], PF::TINY, 2)
dump_as("EB_menu")

#================================================================ Battle Info: Gyarados's tab
info_frame(c, 1)
b = BASE.bitmap; t = TOP.bitmap
mon(t, "GYARADOS", 52, 74, 44)
P.text(t, 78, 56, 200, 20, "Gyarados  Lv31", c[:txt], PF::ROW)
P.text(t, 78, 78, 200, 14, "HP 55% · No Status", c[:dim], PF::TINY)
stage_rows(c, 32, 104, 260)
b.fill_rect(304, 56, 1, 280, c[:line])
x = 316; y = 58
[["Types", nil], ["Ability", "Intimidate (Revealed)"], ["Item", "Not Seen Yet"], ["Effects", "Leech Seed, Confused (2)"]].each_with_index do |(k, v), i|
  P.text(t, x, y + i * 34, 180, 12, k.upcase, c[:head], PF::TINY)
  if k == "Types"
    type_icon(t, 11, x, y + 14, 16); type_icon(t, 2, x + 20, y + 14, 16)
  else
    P.small(t, x, y + i * 34 + 13, 180, 16, v, i == 2 ? c[:dim] : c[:txt])
  end
end
hints(c, [[:lr, "Tabs"], [:ud, "Scroll"], [B_BTN, "Back"]])
dump_as("EB_info")

#================================================================ Quick Throw with the Ball Advisor
frame(c)
b = BASE.bitmap; t = TOP.bitmap
catch_tag(c)
px = 116; pw = 280; py = 80; rh = 24
UI.rbox(b, px, py, px + pw, py + 26 + BALLS.length * rh + 6, 6, col(c[:panel], 242), c[:line])
P.text(t, px, py + 4, pw, 22, "Quick Throw", c[:title], PF::ROW, 2)
b.fill_rect(px + 8, py + 26, pw - 16, 1, c[:line])
BALLS.each_with_index do |(ic, n, q, p, note), i|
  y = py + 30 + i * rh
  cursor_at(px + 4, y, pw - 8, rh - 1) if i == BEST
  item_icon(t, ic, px + 18, y + 11, 18)
  P.text(t, px + 32, y, 100, rh - 1, n, i == BEST ? GOLD : c[:txt], PF::TEXT)
  star(t, px + 34 + P.width(PF::TEXT, n) + 4, y + 8, GOLD) if i == BEST
  P.text(t, px + 130, y, 26, rh - 1, "x#{q}", c[:dim], PF::TINY)
  bar(b, px + 158, y + 9, 66, p, i == BEST ? GOLD : GREEN, c)
  P.text(t, px + 228, y, 44, rh - 1, "#{p}%", i == BEST ? GOLD : c[:txt], PF::TEXT, 1)
end
dy = py + 26 + BALLS.length * rh + 10
UI.rbox(b, px, dy, px + pw, dy + 40, 6, col(c[:panel2], 240), c[:line])
P.small(t, px + 8, dy + 4, pw - 16, 16, "Net Ball: x3.5 on Water and Bug types.", c[:txt])
P.small(t, px + 8, dy + 20, pw - 16, 16, "Gyarados at 55% HP, no status.", c[:dim])
dump_as("EB_throw")

#================================================================ Battle Info: the Matchup tab
info_frame(c, 2)
b = BASE.bitmap; t = TOP.bitmap
px = 24; pw = W - 48; py = 52
P.text(t, px + 10, py, 260, 12, "YOUR MOVES VS GYARADOS", c[:head], PF::TINY)
MATCH.each_with_index do |(m, ty, eff, mult, k), i|
  y = py + 16 + i * 24
  cursor_at(px + 4, y, pw - 8, 23) if i == 0
  type_icon(t, ty, px + 12, y + 4)
  P.text(t, px + 36, y, 160, 23, m, c[:txt], PF::TEXT)
  P.text(t, px + 220, y, 160, 23, eff, ecol(k, c), PF::TINY)
  P.text(t, px + pw - 60, y, 48, 23, mult, ecol(k, c), PF::TEXT, 1)
end
b.fill_rect(px + 8, py + 118, pw - 16, 1, c[:line])
P.text(t, px + 10, py + 124, 260, 12, "GYARADOS'S TYPE PROFILE", c[:head], PF::TINY)
type_icon(t, 11, px + pw - 50, py + 122); type_icon(t, 2, px + pw - 30, py + 122)
PROFILE.each_with_index do |(k, ids), i|
  y = py + 142 + i * 24
  P.text(t, px + 12, y, 110, 22, k, c[:txt], PF::TEXT)
  ids.each_with_index { |id, j| type_icon(t, id, px + 130 + j * 22, y + 3) }
end
P.text(t, px + 130 + 2 * 22 + 6, py + 142, 120, 22, "Electric x4", c[:dim], PF::TINY)
P.small(t, px + 12, py + 218, pw - 24, 16, "Types as seen in this battle; abilities count once revealed.", c[:dim])
hints(c, [[:lr, "Tabs"], [:ud, "Moves"], [B_BTN, "Back"]])
dump_as("EB_matchup")
