# encoding: utf-8
# Mockups: Save Checker (topic 36), screen 2: Missing Content. Pokémon,
# items and moves in the save that the game no longer has (the Expanded Dex
# isn't loaded, a mod was removed), where each one is, and the fix.
# Fixes: Keep Aside (the data waits in KR's part of the save and comes back
# with the content; recommended), Stand-In (a base Pokémon or item for now),
# or Remove. Sample: File A: Sprigatito (Box 4), Fuecoco (party: the risky
# one, a party member the game can't load), Mega Ring (Bag, from Mega Mod).
# Each design is a pair: the list (left), choosing a fix (right).
# Design 1 = the chosen Check Results' report card look.
# Usage (from this folder): ruby mc_designs.rb "<KIF Beta>" <work dir with metrics.json>
CSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "sc_designs.rb"), :encoding => "UTF-8")
eval(CSRC.split("c = palette(2)\n")[0], binding, "sc_designs.rb")

def tick(t, x, y, st)
  colr = ST[st][1]
  UI.rbox(t, x, y, x + 16, y + 16, 8, Color.new(colr.red / 4, colr.green / 4, colr.blue / 4), colr)
  if st == :ok
    [[4, 8], [5, 9], [6, 10], [7, 9], [8, 8], [9, 7], [10, 6], [11, 5]].each { |px, py| t.fill_rect(x + px, y + py, 2, 2, colr) }
  else
    t.fill_rect(x + 7, y + 4, 2, 6, colr); t.fill_rect(x + 7, y + 11, 2, 2, colr)
  end
end
# The game has no art for missing content: a question-mark tile
def unknown(t, c, cx, cy, size = 28)
  UI.rbox(t, cx - size / 2, cy - size / 2, cx + size / 2, cy + size / 2, 6, c[:dark], c[:line])
  P.text(t, cx - size / 2, cy - size / 2 + (size - 22) / 2, size, 22, "?", c[:dim], PF::ROW, 2)
end
# name, kind, where, from, risk
MISS = [["Fuecoco", "Pokémon, Lv. 9", "Party, slot 6", "Expanded Dex", :bad],
        ["Sprigatito", "Pokémon, Lv. 12", "Box 4, slot 7", "Expanded Dex", :note],
        ["Mega Ring", "Key Item", "Bag: Key Items", "Mega Mod", :note]]
def keep_text(src); "Kept in Kanto Reloaded's part of the save. It comes back when #{src == 'Mega Mod' ? 'Mega Mod is installed' : 'the Expanded Dex is loaded'} again. Nothing is lost."; end
FIXES = [["Keep Aside", "Kept in Kanto Reloaded's part of the save. It comes back when the Expanded Dex is loaded again."],
         ["Stand-In", "Shown as Bulbasaur (same level and moves) until the Expanded Dex is back; then it turns back into Fuecoco."],
         ["Remove", "Removed from the save for good. A backup is made first."]]
def mc_title(c); sc_title(c, "Missing Content"); end

c = palette(2)

#================================================================ MC1 Recommended: the report card look; a verdict, each missing thing with where it is and its fix
def mc1(c, choosing)
  frame(c); OVER.bitmap.clear
  mc_title(c)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 8, 40, W - 8, 82, 8, col(GOLD, 40), GOLD)
  P.text(t, 20, 42, 400, 24, "2 Pokémon and 1 Item Missing", GOLD, PF::ROW)
  P.small(t, 20, 64, 470, 16, "The game doesn't have them now. Keep Aside saves them.", c[:txt])
  UI.rbox(b, 8, 88, W - 8, 300, 6, c[:panel])
  MISS.each_with_index do |(n, kind, where, from, st), i|
    y = 94 + i * 46
    cursor_at(12, y - 2, W - 24, 44) if i == 0
    tick(t, 20, y + 12, st)
    unknown(t, c, 58, y + 20, 30)
    P.text(t, 80, y, 150, 20, n, c[:opt], PF::TEXT)
    P.small(t, 80, y + 20, 170, 14, kind, c[:dim])
    P.small(t, 250, y + 3, 160, 14, where, st == :bad ? RED : c[:txt])
    P.small(t, 250, y + 20, 140, 14, "From: #{from}", c[:dim])
    P.text(t, 400, y + 8, 94, 20, "Keep Aside", c[:txt], PF::TEXT, 1)
  end
  P.small(t, 20, 236, 470, 16, "Fuecoco is in the party, so Keep Aside moves it out.", RED)
  UI.rbox(b, 8, 306, 250, 348, 6, c[:sel], c[:selb]); P.text(t, 8, 316, 242, 22, "Fix All Safely", c[:white], PF::TEXT, 2)
  UI.rbox(b, 262, 306, W - 8, 348, 6, c[:dark], c[:line]); P.text(t, 262, 316, W - 270, 22, "Save the Report", c[:txt], PF::TEXT, 2)
  if choosing
    o = OVER.bitmap
    o.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 130))
    UI.rbox(o, 96, 84, 416, 296, 8, c[:panel2], c[:selb])
    unknown(o, c, 126, 112, 32)
    P.text(o, 148, 94, 250, 22, "Fuecoco: Fix", c[:title], PF::ROW)
    FIXES.each_with_index do |(f, why), i|
      y = 134 + i * 28
      UI.rbox(o, 104, y, 408, y + 24, 4, c[:sel], c[:selb]) if i == 0
      P.text(o, 118, y + 1, 200, 22, f, c[:opt], PF::TEXT)
      P.text(o, 300, y + 1, 100, 22, i == 0 ? "RECOMMENDED" : "", GREEN, PF::TINY, 1) if i == 0
    end
    o.fill_rect(106, 222, 300, 1, c[:line])
    P.small_wrap(o, FIXES[0][1], 290).first(4).each_with_index { |ln, k| P.small(o, 112, 228 + k * 16, 294, 16, ln, c[:dim]) }
    o.fill_rect(0, H - 28, W, 28, Color.new(0, 0, 0, 0))
    BASE.bitmap.fill_rect(0, H - 28, W, 28, c[:bg]); TOP.bitmap.fill_rect(0, H - 28, W, 28, Color.new(0, 0, 0, 0))
    hints(c, [[:ud, "Choose"], [A_BTN, "Use This Fix"], [B_BTN, "Back"]])
  else
    hints(c, [[:ud, "Select"], [A_BTN, "Change Fix"], [X_BTN, "Fix All Safely"], [B_BTN, "Back"]])
  end
end
mc1(c, false); dump_as("MC1_list")
mc1(c, true); dump_as("MC1_fix")

#================================================================ MC2: the Settings layout; Pokémon, Items, Moves as sections, the fix as a value on each row
def mc2(c, sec)
  frame(c); OVER.bitmap.clear
  mc_title(c)
  side(c, [["Pokémon", :bad], ["Items", :note], ["Moves", :ok]], sec)
  t = TOP.bitmap
  rows = sec == 0 ? MISS.first(2) : MISS.last(1)
  P.heading(t, 190, W - 16, 47, sec == 0 ? "Pokémon: 2 Missing" : "Items: 1 Missing", c[:head], c[:line])
  rows.each_with_index do |(n, kind, where, from, st), i|
    y = 60 + i * 44
    cursor_at(184, y, W - 194, 42) if i == 0
    unknown(t, c, 204, y + 21, 28)
    P.text(t, 224, y + 2, 120, 20, n, c[:opt], PF::TEXT)
    P.small(t, 224, y + 22, 150, 14, where, st == :bad ? RED : c[:dim])
    vw = P.width(PF::TEXT, "Keep Aside")
    cx = W - 70
    P.text(t, cx - vw / 2, y + 10, vw + 2, 22, "Keep Aside", c[:opt], PF::TEXT)
    UI.tri(t, cx - vw / 2 - 14, y + 17, :l, i == 0 ? c[:txt] : c[:dim], 4); UI.tri(t, cx + vw / 2 + 6, y + 17, :r, i == 0 ? c[:txt] : c[:dim], 4)
  end
  n, kind, where, from = rows[0]
  desc(c, n, "#{kind}, #{where}, from #{from == 'Mega Mod' ? 'Mega Mod (not installed)' : 'the Expanded Dex (not loaded)'}. Keep Aside: #{keep_text(from)}", [sec == 0 ? "IN THE PARTY" : "BAG"])
  hints(c, [[:ud, "Select"], [:lr, "Fix"], [X_BTN, "Fix All Safely"], [B_BTN, "Sections"]])
end
mc2(c, 0); dump_as("MC2_pokemon")
mc2(c, 1); dump_as("MC2_items")

#================================================================ MC3: where in the save; the party, the box and the bag drawn small, the missing slots marked
def party_strip(t, c, x, y, miss_slot)
  %w[PIKACHU GYARADOS GENGAR ALAKAZAM SNORLAX].each_with_index { |sp, k| mon(t, sp, x + 18 + k * 40, y + 18, 34) }
  UI.rbox(t, x + 18 + 5 * 40 - 19, y - 1, x + 18 + 5 * 40 + 19, y + 37, 6, RED)
  unknown(t, c, x + 18 + 5 * 40, y + 18, 34)
end
def box_grid(t, c, x, y, miss)
  30.times do |k|
    cx = x + (k % 6) * 22; cy = y + (k / 6) * 22
    UI.rbox(t, cx, cy, cx + 20, cy + 20, 3, k == miss ? Color.new(80, 60, 20) : c[:dark], k == miss ? GOLD : c[:line])
    P.text(t, cx, cy, 20, 20, "?", GOLD, PF::TEXT, 2) if k == miss
  end
end
def mc3(c, focus)
  frame(c); OVER.bitmap.clear
  mc_title(c)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 8, 40, W - 8, 92, 6, c[:panel], focus == 0 ? c[:selb] : c[:line])
  P.small(t, 18, 44, 200, 14, "PARTY", c[:head])
  party_strip(t, c, 14, 54, 5)
  P.small(t, 270, 60, 230, 16, "Slot 6: Fuecoco", RED)
  UI.rbox(b, 8, 98, 250, 262, 6, c[:panel], focus == 1 ? c[:selb] : c[:line])
  P.small(t, 18, 102, 200, 14, "BOX 4", c[:head])
  box_grid(t, c, 18, 120, 6)
  P.small(t, 18, 238, 220, 16, "Slot 7: Sprigatito", GOLD)
  UI.rbox(b, 256, 98, W - 8, 262, 6, c[:panel], focus == 2 ? c[:selb] : c[:line])
  P.small(t, 266, 102, 200, 14, "BAG: KEY ITEMS", c[:head])
  ["Bicycle", "Town Map", "Mega Ring", "Old Rod"].each_with_index do |it, k|
    y = 122 + k * 24
    if it == "Mega Ring"
      unknown(t, c, 278, y + 10, 20); P.text(t, 294, y, 160, 20, it, GOLD, PF::TEXT)
    else
      P.text(t, 294, y, 160, 20, it, c[:dim], PF::TEXT)
    end
  end
  cursor_at(focus == 0 ? 10 : (focus == 1 ? 10 : 258), focus == 0 ? 42 : 100, focus == 0 ? W - 20 : (focus == 1 ? 238 : W - 266), focus == 0 ? 48 : 160)
  n, kind, where, from = MISS[focus == 0 ? 0 : (focus == 1 ? 1 : 2)]
  desc(c, n, "#{kind}, from #{from == 'Mega Mod' ? 'Mega Mod (not installed)' : 'the Expanded Dex (not loaded)'}. Fix: Keep Aside (A changes it).", [focus == 0 ? "IN THE PARTY" : (focus == 1 ? "BOX 4" : "BAG")])
  hints(c, [[:ud, ""], [:lr, "Select"], [A_BTN, "Change Fix"], [X_BTN, "Fix All Safely"], [B_BTN, "Back"]])
end
mc3(c, 0); dump_as("MC3_party")
mc3(c, 1); dump_as("MC3_box")

#================================================================ MC4: before and after; what the party looks like now and after the fix
def mc4(c, fix)
  frame(c); OVER.bitmap.clear
  mc_title(c)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 8, 40, W - 8, 66, 6, c[:panel2], c[:line])
  ["Keep Aside", "Stand-In", "Remove"].each_with_index do |f, i|
    x = 16 + i * 162
    on = i == fix
    UI.rbox(b, x, 44, x + 154, 62, 5, on ? c[:sel] : c[:dark], on ? c[:selb] : c[:line])
    P.text(t, x, 44, 154, 18, f, on ? c[:white] : c[:dim], PF::TEXT, 2)
  end
  [["NOW", 72], ["AFTER THE FIX", 162]].each do |l, y|
    UI.rbox(b, 8, y, W - 8, y + 84, 6, c[:panel], c[:line])
    P.small(t, 18, y + 4, 300, 14, l, c[:head])
  end
  %w[PIKACHU GYARADOS GENGAR ALAKAZAM SNORLAX].each_with_index { |sp, k| mon(t, sp, 50 + k * 60, 122, 40); mon(t, sp, 50 + k * 60, 212, 40) }
  unknown(t, c, 350, 122, 38); P.small(t, 330, 144, 60, 14, "Fuecoco", RED, 2)
  case fix
  when 0
    P.small(t, 330, 206, 160, 16, "Party of 5.", c[:dim])
    P.small(t, 330, 222, 170, 16, "Fuecoco is kept aside.", GREEN)
  when 1
    mon(t, "BULBASAUR", 350, 212, 38); P.small(t, 330, 234, 60, 14, "Bulbasaur", GOLD, 2)
    P.small(t, 400, 206, 100, 16, "Lv. 9, same", c[:dim]); P.small(t, 400, 222, 100, 16, "moves", c[:dim])
  else
    P.small(t, 330, 206, 160, 16, "Party of 5.", c[:dim])
    P.small(t, 330, 222, 170, 16, "Fuecoco is gone for good.", RED)
  end
  desc(c, FIXES[fix][0], FIXES[fix][1], [fix == 0 ? "RECOMMENDED" : "FUECOCO"])
  hints(c, [[:lr, "Fix"], [A_BTN, "Use This Fix"], ["p:10", "Next Item"], [B_BTN, "Back"]])
end
mc4(c, 0); dump_as("MC4_keep")
mc4(c, 1); dump_as("MC4_standin")

#================================================================ MC5: one at a time; a card per missing thing with the three fixes
def mc5(c, idx)
  frame(c); OVER.bitmap.clear
  mc_title(c)
  b = BASE.bitmap; t = TOP.bitmap
  n, kind, where, from, st = MISS[idx]
  P.small(t, 0, 40, W, 16, "#{idx + 1} of #{MISS.length}", c[:dim], 2)
  3.times { |k| UI.rbox(b, 226 + k * 22, 58, 244 + k * 22, 62, 2, k <= idx ? c[:selb] : c[:line]) }
  UI.rbox(b, 56, 70, 456, 196, 10, c[:panel], st == :bad ? RED : GOLD)
  unknown(t, c, 106, 120, 60)
  P.text(t, 150, 82, 290, 26, n, c[:white], PF::ROW)
  P.small(t, 150, 110, 290, 16, kind, c[:dim])
  P.small(t, 150, 128, 290, 16, where, st == :bad ? RED : c[:txt])
  P.small(t, 150, 146, 290, 16, from == "Mega Mod" ? "From: Mega Mod (not installed)" : "From: the Expanded Dex (not loaded)", c[:dim])
  P.small(t, 150, 168, 290, 16, st == :bad ? "The game can't load it in the party." : "Safe there, but the game can't show it.", st == :bad ? RED : c[:dim])
  FIXES.each_with_index do |(f, _), i|
    x = 56 + i * 136
    UI.rbox(b, x, 206, x + 128, 238, 6, i == 0 ? c[:sel] : c[:dark], i == 0 ? c[:selb] : c[:line])
    P.text(t, x, 210, 128, 22, f, i == 0 ? c[:white] : c[:txt], PF::TEXT, 2)
  end
  P.small_wrap(t, keep_text(from), 400).first(3).each_with_index { |ln, k| P.small(t, 56, 244 + k * 15, 400, 15, ln, c[:dim]) }
  UI.rbox(b, 56, 294, 456, 320, 6, c[:dark], c[:line]); P.text(t, 56, 296, 400, 22, "Keep Aside for All 3", c[:txt], PF::TEXT, 2)
  hints(c, [[:lr, "Choose"], [A_BTN, "Use This Fix"], [X_BTN, "Same for All"], [B_BTN, "Back"]])
end
mc5(c, 0); dump_as("MC5_first")
mc5(c, 1); dump_as("MC5_second")
