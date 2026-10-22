# encoding: utf-8
# Mockups: Data Patches (topic 30): the Patch Viewer (new). Five designs,
# each two screens: what each mod's data patches change, then a conflict or
# a rejected patch explained. Example mods: Kanto Reloaded (Expanded Dex,
# In the Wild), Gen 9 Movepools (learnsets), Hard Trainers+ (trainers.classic).
# Conflict: two mods edit Gyarados's level-up learnset (load order decides).
# Rejected: a patch that teaches an unknown move (TERABLAST2).
# Design 1 = the improved Settings layout (mods as sections, targets as rows,
# the description box explains).
# Usage (from this folder): ruby patch_designs.rb "<KIF Beta>" <work dir with metrics.json>
SRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "qa_designs.rb"), :encoding => "UTF-8")
eval(SRC.split("c = palette(2)\n")[0], binding, "qa_designs.rb")

OVER = layer(3); OVER.z = 4
X_BTN = "p:2"; Y_BTN = "p:3"
AMB = Color.new(240, 170, 60); RED2 = Color.new(240, 100, 90); BLUE2 = Color.new(130, 190, 250)
MODS = [["Kanto Reloaded", [214, 52, 60], [["Species", "+522", "Added"], ["Moves", "+172", "Added"], ["Abilities", "+74", "Added"], ["Encounters", "48", "Edited"]], :ok],
        ["Gen 9 Movepools", [90, 170, 100], [["Learnsets", "120", "Edited"], ["Moves", "6", "Edited"]], :warn],
        ["Hard Trainers+", [210, 80, 80], [["Trainers", "64", "Edited"], ["Trainer Types", "3", "Added"], ["Learnsets", "1", "Rejected"]], :err]]
def status_pill(t, x, y, st, right = true)
  case st
  when :ok then P.pill(t, x, y, "OK", Color.new(24, 60, 40), GREEN, right)
  when :warn then P.pill(t, x, y, "1 CONFLICT", Color.new(70, 46, 14), AMB, right)
  else P.pill(t, x, y, "1 REJECTED", Color.new(70, 24, 24), RED2, right)
  end
end
def kind_col(c, k); { "Added" => GREEN, "Edited" => BLUE2, "Rejected" => RED2 }[k] || c[:txt]; end
def mod_sidebar(c, sel)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 6, 36, 174, 262, 6, c[:panel])
  MODS.each_with_index do |(n, rgb, _, st), i|
    y = 40 + i * 24
    UI.rbox(b, 9, y, 171, y + 22, 4, c[:sel], c[:selb]) if i == sel
    UI.rbox(t, 14, y + 4, 28, y + 18, 3, Color.new(*rgb))
    P.text(t, 33, y + 2, 120, 18, n, i == sel ? c[:white] : c[:dim])
    UI.rbox(t, 160, y + 8, 166, y + 14, 3, { :ok => GREEN, :warn => AMB, :err => RED2 }[st])
  end
end
def page_frame(c, title = "Data Patches")
  frame(c); OVER.bitmap.clear
  MAPS.bitmap = Bitmap.new(W, H)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, 32, c[:panel2]); b.fill_rect(0, 31, W, 1, c[:line])
  P.text(t, 0, 2, W, 28, title, c[:title], PF::TITLE, 2)
end
H_PV = [[:ud, "Select"], [A_BTN, "Details"], [B_BTN, "Back"]]

c = palette(2)

#================================================================ PV1 Recommended: the Settings layout (mods as sections)
def pv1(c, sel_mod, sel_row)
  page_frame(c)
  b = BASE.bitmap; t = TOP.bitmap
  settings_frame(c, MODS.map { |m| [m[0], m[1]] }, sel_mod)
  t.fill_rect(130, 2, 252, 28, Color.new(0, 0, 0, 0)); P.text(t, 130, 2, 252, 28, "Data Patches", c[:title], PF::TITLE, 2)
  t.fill_rect(W - 118, 6, 108, 20, Color.new(0, 0, 0, 0)); UI.rbox(b, W - 120, 4, W - 8, 27, 5, c[:dark], c[:line]); P.text(t, W - 120, 4, 112, 23, "Load Order", c[:dim], PF::TEXT, 2)
  n, _, rows, st = MODS[sel_mod]
  P.heading(t, 190, W - 16, 43, n, c[:head], c[:line])
  status_pill(t, W - 18, 40, st)
  rows.each_with_index do |(l, cnt, k), i|
    y = 58 + i * 26
    cursor_at(184, y, W - 194, 24) if i == sel_row
    P.text(t, 196, y, 180, 24, l, c[:opt], PF::ROW)
    P.text(t, 364, y, 44, 24, cnt, c[:txt], PF::TEXT, 1)
    P.text(t, 412, y, 84, 24, k, kind_col(c, k), PF::TEXT, 1)
  end
end
pv1(c, 0, 0)
desc_box(c, "Species", "Kanto Reloaded adds 522 species (Expanded Dex, Gen 4 to 9) as numbers 577 to 1123. Nothing in PIF's 576 is changed.")
hints(c, H_PV); dump_as("PV1_list")
pv1(c, 2, 2)
desc_box(c, "Rejected: Learnsets", "Hard Trainers+ teaches Gyarados TERABLAST2, a move the game doesn't have. That patch was skipped; the rest of the mod works.", ["SKIPPED"])
hints(c, H_PV); dump_as("PV1_rejected")

#================================================================ PV2: a log grouped by kind (added, edited, conflicts, rejected)
def pv2(c, filter)
  page_frame(c)
  b = BASE.bitmap; t = TOP.bitmap
  ["ALL", "ADDED", "EDITED", "PROBLEMS"].each_with_index do |f, i|
    w = P.width(PF::TINY, f) + 16; x = 10 + [0, 44, 110, 180][i]
    UI.rbox(b, x, 38, x + w, 55, 5, i == filter ? c[:sel] : c[:dark], i == filter ? c[:selb] : c[:line])
    P.text(t, x, 39, w, 16, f, i == filter ? c[:white] : c[:dim], PF::TINY, 2)
  end
  lines = filter == 3 ? [[:warn, "Gen 9 Movepools, Hard Trainers+", "Both edit Gyarados's learnset. Load order: Hard Trainers+ wins."],
                         [:err, "Hard Trainers+", "Learnset: TERABLAST2 isn't a move. Skipped."]] :
          [[:ok, "Kanto Reloaded", "Added 522 species, 172 moves, 74 abilities."], [:ok, "Kanto Reloaded", "Edited 48 encounter tables (In the Wild)."],
           [:warn, "Gen 9 Movepools", "Edited 120 learnsets, 6 moves. 1 conflict."], [:err, "Hard Trainers+", "Edited 64 trainers, added 3 types. 1 rejected."]]
  lines.each_with_index do |(st, m, txt), i|
    y = 62 + i * 54
    UI.rbox(b, 8, y, 504, y + 50, 8, c[:panel], { :ok => c[:line], :warn => AMB, :err => RED2 }[st])
    cursor_at(10, y + 2, 492, 46) if i == 0
    P.text(t, 20, y + 4, 300, 22, m, c[:txt], PF::TEXT)
    status_pill(t, 494, y + 8, st)
    P.small(t, 20, y + 28, 470, 16, txt, c[:dim])
  end
  hints(c, [[:lr, "Filter"], [:ud, "Select"], [A_BTN, "Details"], [B_BTN, "Back"]])
end
pv2(c, 0); dump_as("PV2_log")
pv2(c, 3); dump_as("PV2_problems")

#================================================================ PV3: look up one entry and see which mods touched it, in load order
def pv3(c, conflict)
  page_frame(c, "Data Patches: Lookup")
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 8, 40, 300, 66, 6, c[:dark], c[:selb]); magnifier(b, 26, 47, c[:dim], c[:dark])
  P.text(t, 44, 41, 250, 24, "Gyarados", c[:white], PF::TEXT)
  mon_icon = proc { |sp, cx, cy, s| t.stretch_blt(Rect.new(cx - s / 2, cy - s / 2, s, s), bmp(File.join(GFX, "Pokemon/Icons/#{sp}.png")), Rect.new(0, 0, 64, 64)) }
  mon_icon.call("GYARADOS", 344, 54, 48)
  P.text(t, 372, 42, 130, 24, "No. 130", c[:dim], PF::TEXT)
  P.heading(t, 14, 498, 76, "Learnset", c[:head], c[:line])
  [["PIF", "Base learnset", c[:dim], nil], ["Gen 9 Movepools", "Edit: + Dragon Dance at Lv. 30", BLUE2, :warn],
   ["Hard Trainers+", conflict ? "Edit: + Tera Blast 2 at Lv. 30 (skipped)" : "Edit: + Earthquake at Lv. 30", conflict ? RED2 : BLUE2, conflict ? :err : :warn]].each_with_index do |(m, d, colr, st), i|
    y = 94 + i * 46
    UI.rbox(b, 20, y + 14, 34, y + 28, 7, colr)
    b.fill_rect(26, y + 28, 2, 32, c[:line]) if i < 2
    P.text(t, 44, y + 4, 200, 22, m, c[:txt], PF::TEXT); P.small(t, 44, y + 24, 400, 16, d, c[:dim])
    status_pill(t, 498, y + 8, st) if st
  end
  P.heading(t, 14, 498, 240, "Result", c[:head], c[:line])
  P.small(t, 20, 258, 480, 16, conflict ? "Lv. 30: Dragon Dance (Hard Trainers+'s edit was skipped)." : "Lv. 30: Earthquake. The last mod in load order wins.", c[:txt])
  hints(c, [["Type", ""], [A_BTN, "Naming Screen"], [:ud, "Select"], [B_BTN, "Back"]])
end
pv3(c, false); dump_as("PV3_lookup")
pv3(c, true); dump_as("PV3_rejected")

#================================================================ PV4: a card per mod with counts and status
def pv4(c)
  page_frame(c)
  b = BASE.bitmap; t = TOP.bitmap
  MODS.each_with_index do |(n, rgb, rows, st), i|
    y = 38 + i * 104
    UI.rbox(b, 8, y, 504, y + 98, 8, c[:panel], { :ok => c[:line], :warn => AMB, :err => RED2 }[st])
    cursor_at(10, y + 2, 492, 94) if i == 1
    UI.rbox(t, 18, y + 10, 34, y + 26, 4, Color.new(*rgb))
    P.text(t, 42, y + 6, 300, 24, n, c[:txt], PF::ROW)
    status_pill(t, 494, y + 10, st)
    rows.each_with_index do |(l, cnt, k), j|
      x = 18 + (j % 2) * 240; yy = y + 38 + (j / 2) * 24
      P.small(t, x, yy, 140, 16, l, c[:dim]); P.text(t, x + 140, yy - 2, 80, 20, "#{cnt} #{k}", kind_col(c, k), PF::TEXT, 1)
    end
  end
  hints(c, H_PV)
end
pv4(c); dump_as("PV4_cards")
pv4(c)
d = OVER.bitmap
d.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 120))
UI.rbox(d, 66, 90, 446, 270, 8, col(c[:panel], 255), AMB)
P.text(d, 66, 96, 380, 22, "Conflict: Gyarados Learnset", AMB, PF::ROW, 2)
d.fill_rect(76, 122, 360, 1, c[:line])
["Gen 9 Movepools and Hard Trainers+ both", "change what Gyarados learns at Lv. 30.", "The mod loaded last wins: Hard Trainers+.", "Change the order in the Mod Manager."].each_with_index { |l, k| P.small(d, 66, 132 + k * 20, 380, 16, l, c[:txt], 2) }
UI.rbox(d, 196, 228, 316, 254, 6, c[:sel], c[:selb]); P.text(d, 196, 230, 120, 22, "OK", c[:white], PF::TEXT, 2)
dump_as("PV4_conflict")

#================================================================ PV5: changes as before -> after (a diff of one entry's fields)
def pv5(c, sel)
  page_frame(c)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 8, 38, 190, 354, 8, c[:panel], c[:line])
  [["Gyarados", "2 mods"], ["Lapras", "1 mod"], ["Dragon Dance", "1 mod"], ["Leader Brock", "1 mod"], ["Route 24", "1 mod"]].each_with_index do |(n, m), i|
    y = 44 + i * 30
    cursor_at(12, y, 174, 28) if i == sel
    P.text(t, 22, y + 2, 120, 24, n, c[:txt], PF::TEXT); P.small(t, 126, y + 6, 56, 16, m, c[:dim], 1)
  end
  UI.rbox(b, 198, 38, 504, 354, 8, c[:panel], c[:line])
  P.text(t, 198, 42, 306, 24, "Gyarados", c[:title], PF::ROW, 2)
  [["Lv. 30 move", "Bite", "Earthquake", "Hard Trainers+"], ["Lv. 30 move", "Bite", "Dragon Dance", "Gen 9 Movepools (overridden)"], ["Lv. 44 move", "Hurricane", "Waterfall", "Gen 9 Movepools"]].each_with_index do |(f, a, z, m), i|
    y = 76 + i * 64
    P.small(t, 210, y, 280, 16, f, c[:dim])
    P.text(t, 210, y + 16, 110, 22, a, c[:dim], PF::TEXT)
    UI.tri(b, 316, y + 20, :r, c[:dim], 5)
    P.text(t, 332, y + 16, 160, 22, z, i == 1 ? c[:dim] : GREEN, PF::TEXT)
    t.fill_rect(332, y + 27, P.width(PF::TEXT, z), 1, c[:dim]) if i == 1
    P.small(t, 210, y + 40, 290, 16, m, i == 1 ? AMB : c[:dim])
  end
  hints(c, H_PV)
end
pv5(c, 0); dump_as("PV5_diff")
pv5(c, 0)
d = OVER.bitmap
d.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 120))
UI.rbox(d, 66, 100, 446, 260, 8, col(c[:panel], 255), RED2)
P.text(d, 66, 106, 380, 22, "Rejected Patch", RED2, PF::ROW, 2)
d.fill_rect(76, 132, 360, 1, c[:line])
["Hard Trainers+ tried to teach Gyarados", "TERABLAST2, which isn't a move here.", "Only that patch was skipped."].each_with_index { |l, k| P.small(d, 66, 142 + k * 20, 380, 16, l, c[:txt], 2) }
UI.rbox(d, 196, 220, 316, 246, 6, c[:sel], c[:selb]); P.text(d, 196, 222, 120, 22, "OK", c[:white], PF::TEXT, 2)
dump_as("PV5_rejected")

#================================================================ PVH: Hot Reload's report in design 1's look (ModDev only)
pv1(c, 1, 0)
b = BASE.bitmap; t = TOP.bitmap
d = OVER.bitmap
d.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 120))
UI.rbox(d, 76, 70, 436, 290, 8, col(c[:panel], 255), c[:selb])
P.text(d, 76, 76, 360, 22, "Patches Reloaded", c[:title], PF::ROW, 2)
P.small(d, 76, 100, 360, 16, "Gen 9 Movepools, 0.4 seconds, no restart", c[:dim], 2)
d.fill_rect(86, 122, 340, 1, c[:line])
[["Learnsets", "3 changed", BLUE2], ["Moves", "1 added", GREEN], ["Rejected", "1 new", RED2]].each_with_index do |(l, v, colr), k|
  y = 130 + k * 26
  P.text(d, 100, y, 160, 24, l, c[:txt], PF::TEXT); P.text(d, 260, y, 160, 24, v, colr, PF::TEXT, 1)
end
P.small(d, 76, 214, 360, 16, "Moves: \"SHADOWCLAWX\" has no type. Skipped.", RED2, 2)
UI.rbox(d, 196, 246, 316, 272, 6, c[:sel], c[:selb]); P.text(d, 196, 248, 120, 22, "OK", c[:white], PF::TEXT, 2)
desc_box(c, "Learnsets", "Gen 9 Movepools edits 120 learnsets.")
hints(c, [[:ud, "Select"], [A_BTN, "Details"], [Y_BTN, "Reload"], [B_BTN, "Back"]])
dump_as("PVH_reload")
