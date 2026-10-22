# encoding: utf-8
# Mockups: Save Checker (topic 36), screen 3: Mod Data in the Save. Each mod
# with data in this save, how much, and what removing the mod would do. The
# finding that matters most: a mod that stores its own objects (not plain
# values) is needed to load the save at all.
# Sample: File A: Kanto Reloaded (12 parts, plain), Multiplayer (1 value,
# plain), "Mega Mod" (a sample mod: a MegaMod::Data object, and the Mega Ring).
# Each design is a pair: the mods (left), Mega Mod opened (right).
# Design 1 = the chosen report card look.
# Usage (from this folder): ruby md_designs.rb "<KIF Beta>" <work dir with metrics.json>
MSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "mc_designs.rb"), :encoding => "UTF-8")
eval(MSRC.split("c = palette(2)\n")[0], binding, "mc_designs.rb")

# name, colour, what, KB, status, if removed
SMODS = [["Mega Mod", [200, 120, 230], "1 value, 1 item", 3, :bad, "Needed to load: it stores a MegaMod::Data object, which the game can't read without Mega Mod."],
         ["Kanto Reloaded", [214, 52, 60], "12 parts", 38, :ok, "Safe to remove: plain values only. Its .kr copy brings the data back when it's installed again."],
         ["Multiplayer", [96, 160, 232], "1 value", 2, :ok, "Safe to remove: plain values only. Its data waits in the save."]]
VERD = { :ok => ["SAFE TO REMOVE", GREEN], :bad => ["NEEDED TO LOAD", RED] }
def vpill(t, x, y, st); l, colr = VERD[st]; badge(t, x, y, l, colr, true); end
MEGA_VALUES = [["mega_mod", "MegaMod::Data", "Mega Evolutions seen, keystone level", :bad], ["Mega Ring", "Key Item", "Becomes Missing Content without Mega Mod", :note]]
def md_title(c); sc_title(c, "Mod Data"); end

c = palette(2)

#================================================================ MD1 Recommended: the report card look; a verdict, each mod with its data and what removing it does
def md1(c, open)
  frame(c); OVER.bitmap.clear
  md_title(c)
  b = BASE.bitmap; t = TOP.bitmap
  if open
    UI.rbox(b, 8, 40, W - 8, 82, 8, col(RED, 40), RED)
    P.text(t, 20, 42, 400, 24, "Mega Mod: Needed to Load", RED, PF::ROW)
    P.small(t, 20, 64, 470, 16, "Keep Mega Mod installed while you play this save.", c[:txt])
    UI.rbox(b, 8, 88, W - 8, 300, 6, c[:panel])
    P.small(t, 20, 94, 300, 14, "WHAT IT KEEPS IN THIS SAVE", c[:head])
    MEGA_VALUES.each_with_index do |(n, type, what, st), i|
      y = 112 + i * 46
      tick(t, 20, y + 10, st)
      P.text(t, 46, y, 200, 20, n, c[:opt], PF::TEXT)
      P.small(t, 46, y + 20, 300, 14, what, c[:dim])
      P.small(t, 330, y + 4, 164, 14, type, st == :bad ? RED : GOLD, 1)
    end
    P.small_wrap(t, "Without Mega Mod, the game can't read the MegaMod::Data object, so File A won't load. A backup is kept either way.", 470).each_with_index { |ln, k| P.small(t, 20, 214 + k * 17, 474, 16, ln, c[:txt]) }
    UI.rbox(b, 8, 306, 250, 348, 6, c[:sel], c[:selb]); P.text(t, 8, 316, 242, 22, "Back Up Now", c[:white], PF::TEXT, 2)
    UI.rbox(b, 262, 306, W - 8, 348, 6, c[:dark], c[:line]); P.text(t, 262, 316, W - 270, 22, "Save the Report", c[:txt], PF::TEXT, 2)
    hints(c, [[:lr, "Choose"], [A_BTN, "Select"], [B_BTN, "Back"]])
  else
    UI.rbox(b, 8, 40, W - 8, 82, 8, col(GOLD, 40), GOLD)
    P.text(t, 20, 42, 400, 24, "3 Mods, 1 Needed to Load", GOLD, PF::ROW)
    P.small(t, 20, 64, 470, 16, "File A can't load without Mega Mod. The others are safe to remove.", c[:txt])
    UI.rbox(b, 8, 88, W - 8, 300, 6, c[:panel])
    SMODS.each_with_index do |(n, rgb, what, kb, st, why), i|
      y = 94 + i * 64
      cursor_at(12, y - 2, W - 24, 62) if i == 0
      UI.rbox(t, 20, y + 4, 34, y + 18, 3, Color.new(*rgb)); P.glyph(t, 20, y + 4, 15, 15, n[0], Color.new(248, 248, 248))
      P.text(t, 42, y, 200, 22, n, c[:opt], PF::TEXT)
      P.small(t, 200, y + 4, 140, 14, "#{kb} KB", c[:dim])
      vpill(t, W - 18, y + 4, st)
      P.small_wrap(t, why, 450).first(2).each_with_index { |ln, k| P.small(t, 42, y + 24 + k * 15, 452, 15, ln, st == :bad ? RED : c[:txt]) }
    end
    UI.rbox(b, 8, 306, 250, 348, 6, c[:sel], c[:selb]); P.text(t, 8, 316, 242, 22, "Back Up Now", c[:white], PF::TEXT, 2)
    UI.rbox(b, 262, 306, W - 8, 348, 6, c[:dark], c[:line]); P.text(t, 262, 316, W - 270, 22, "Save the Report", c[:txt], PF::TEXT, 2)
    hints(c, [[:ud, "Select"], [A_BTN, "Details"], [X_BTN, "Back Up Now"], [B_BTN, "Back"]])
  end
end
md1(c, false); dump_as("MD1_list")
md1(c, true); dump_as("MD1_mega")

#================================================================ MD2: the Settings layout; mods as sections, each value as a row
def md2(c, sec)
  frame(c); OVER.bitmap.clear
  md_title(c)
  side(c, SMODS.map { |m| [m[0], m[4] == :bad ? :bad : :ok] }, sec)
  t = TOP.bitmap
  m = SMODS[sec]
  P.heading(t, 190, W - 16, 47, m[0], c[:head], c[:line])
  rows = sec == 0 ? MEGA_VALUES.map { |n, ty, wh, st| [n, ty, st] } : [["settings", "Plain Hash", :ok], ["run_card", "Plain Hash", :ok], ["shiny_log", "Plain Array", :ok], ["pc", "Plain Hash", :ok], ["wild_link", "Plain Hash", :ok]]
  rows.each_with_index do |(n, ty, st), i|
    y = 60 + i * 28
    cursor_at(184, y, W - 194, 26) if i == 0
    P.text(t, 196, y + 2, 170, 22, n, c[:opt], PF::TEXT)
    P.text(t, 330, y + 2, 120, 22, ty, st == :bad ? RED : (st == :note ? GOLD : c[:txt]), PF::TEXT, 1)
    tick(t, W - 32, y + 5, st)
  end
  desc(c, sec == 0 ? "mega_mod" : "settings", sec == 0 ? "A MegaMod::Data object: only Mega Mod can read it, so the save needs Mega Mod to load." : "Plain values (a Hash of settings): the save loads without Kanto Reloaded.", [sec == 0 ? "NEEDED TO LOAD" : "SAFE TO REMOVE"])
  hints(c, [[:ud, "Select"], [X_BTN, "Back Up Now"], [B_BTN, "Sections"]])
end
md2(c, 1); dump_as("MD2_kr")
md2(c, 0); dump_as("MD2_mega")

#================================================================ MD3: the save's size by owner; a bar, then each owner
def md3(c, sel)
  frame(c); OVER.bitmap.clear
  md_title(c)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 8, 40, W - 8, 112, 6, c[:panel2], c[:line])
  P.text(t, 18, 42, 300, 22, "File A: 1.8 MB", c[:white], PF::TEXT)
  parts = [["The Game", 1757, [130, 140, 155]], ["Kanto Reloaded", 38, [214, 52, 60]], ["Mega Mod", 3, [200, 120, 230]], ["Multiplayer", 2, [96, 160, 232]]]
  x = 18
  wtot = W - 36
  parts.each_with_index do |(n, kb, rgb), i|
    w = [(wtot * kb / 1800.0).round, 6].max
    w = 18 + wtot - x if i == parts.length - 1
    UI.rbox(b, x, 70, x + w - 2, 88, 3, Color.new(*rgb))
    x += w
  end
  P.small(t, 18, 92, 480, 16, "The mods' data is small; the game's own data is most of the file.", c[:dim])
  UI.rbox(b, 8, 118, W - 8, 300, 6, c[:panel])
  (parts.drop(1)).each_with_index do |(n, kb, rgb), i|
    y = 124 + i * 40
    st = n == "Mega Mod" ? :bad : :ok
    cursor_at(12, y - 2, W - 24, 38) if i == sel
    UI.rbox(t, 20, y + 6, 32, y + 18, 3, Color.new(*rgb))
    P.text(t, 40, y + 1, 200, 22, n, c[:opt], PF::TEXT)
    P.text(t, 230, y + 1, 80, 22, "#{kb} KB", c[:txt], PF::TEXT, 1)
    vpill(t, W - 18, y + 5, st)
  end
  m = SMODS.find { |s| s[0] == parts.drop(1)[sel][0] }
  P.small_wrap(t, m[5], 470).first(2).each_with_index { |ln, k| P.small(t, 20, 250 + k * 17, 474, 16, ln, m[4] == :bad ? RED : c[:txt]) }
  hints(c, [[:ud, "Select"], [A_BTN, "Details"], [X_BTN, "Back Up Now"], [B_BTN, "Back"]])
end
md3(c, 0); dump_as("MD3_kr")
md3(c, 1); dump_as("MD3_mega")

#================================================================ MD4: what if I remove it? pick a mod, see the result
def md4(c, mi)
  frame(c); OVER.bitmap.clear
  md_title(c)
  b = BASE.bitmap; t = TOP.bitmap
  P.small(t, 0, 40, W, 16, "WHAT IF I REMOVE...", c[:head], 2)
  SMODS.each_with_index do |(n, rgb), i|
    x = 30 + i * 154
    on = i == mi
    UI.rbox(b, x, 58, x + 146, 82, 6, on ? c[:sel] : c[:dark], on ? c[:selb] : c[:line])
    P.text(t, x, 59, 146, 22, n, on ? c[:white] : c[:dim], PF::TEXT, 2)
  end
  m = SMODS[mi]
  bad = m[4] == :bad
  UI.rbox(b, 30, 92, 482, 300, 10, col(bad ? RED : GREEN, 30), bad ? RED : GREEN)
  P.text(t, 30, 98, 452, 26, bad ? "File A Won't Load" : "File A Still Loads", bad ? RED : GREEN, PF::ROW, 2)
  lines = bad ? [[:bad, "The game can't read MegaMod::Data."], [:note, "The Mega Ring becomes Missing Content."], [:ok, "A backup of File A is kept."]] :
                [[:ok, "Plain values only: nothing breaks."], [:ok, "KR's features turn off for this save."], [:ok, "Its .kr copy brings the data back later."]]
  lines.each_with_index do |(st, l), i|
    y = 140 + i * 30
    tick(t, 50, y + 3, st)
    P.text(t, 76, y, 390, 22, l, st == :bad ? RED : c[:txt], PF::TEXT)
  end
  P.small(t, 30, 246, 452, 16, "Nothing is removed here; this only shows what would happen.", c[:dim], 2)
  UI.rbox(b, 150, 268, 362, 292, 6, c[:dark], c[:line]); P.text(t, 150, 269, 212, 22, "Back Up Now", c[:txt], PF::TEXT, 2)
  hints(c, [[:lr, "Mods"], [X_BTN, "Back Up Now"], [B_BTN, "Back"]])
end
md4(c, 1); dump_as("MD4_kr")
md4(c, 0); dump_as("MD4_mega")

#================================================================ MD5: in the Save Manager; the save's details list the mods it needs
def md5(c, health)
  frame(c); OVER.bitmap.clear
  b = BASE.bitmap; t = TOP.bitmap
  header(c, "Save Manager", ["Active", "Backups", "Deleted"], 0)
  UI.rbox(b, 8, 62, 232, 352, 6, c[:panel])
  SAVES.each_with_index do |s, i|
    y = 68 + i * 44
    cursor_at(12, y, 217, 42) if i == 0
    UI.rbox(b, 14, y + 4, 18, y + 38, 2, Color.new(*TAGS[i]))
    P.text(t, 24, y + 2, 120, 18, s[0], c[:txt], PF::TEXT)
    note = NOTES[i].empty? ? "No Note" : NOTES[i]
    P.text(t, 24, y + 22, 196, 14, PF.fit(PF::TINY, note, 196), NOTES[i].empty? ? c[:dim] : GOLD, PF::TINY)
    i == 0 ? badge(t, 224, y + 4, "NEEDS A MOD", RED, true) : health(t, s, 224, y + 4, true)
  end
  UI.rbox(b, 238, 62, 504, 352, 6, c[:panel])
  UI.rbox(b, 246, 68, 252, 84, 2, Color.new(*TAGS[0]))
  P.text(t, 258, 66, 240, 20, "File A", c[:txt], PF::ROW)
  detail_rows(c, 248, 90, 246, save_rows(SAVES[0]).first(4))
  b.fill_rect(248, 174, 246, 1, c[:line])
  P.text(t, 248, 180, 200, 12, "MODS IN THIS SAVE", c[:head], PF::TINY)
  SMODS.each_with_index do |(n, rgb, what, kb, st), i|
    y = 196 + i * 30
    UI.rbox(t, 250, y + 4, 262, y + 16, 3, Color.new(*rgb))
    P.text(t, 268, y, 120, 20, n, c[:opt], PF::TEXT)
    st == :bad ? badge(t, 494, y + 2, "NEEDED", RED, true) : badge(t, 494, y + 2, "OPTIONAL", GREEN, true)
  end
  if health
    UI.rbox(b, 248, 300, 494, 344, 5, col(RED, 40), RED)
    P.text(t, 248, 302, 246, 20, "Needs Mega Mod to Load", RED, PF::TEXT, 2)
    P.text(t, 248, 322, 246, 14, "A OPENS THE SAVE CHECK", c[:dim], PF::TINY, 2)
  end
  hints(c, [[:ud, "Choose"], [A_BTN, "Options"], [Y_BTN, "Note"], ["p:9", "Tabs"], [B_BTN, "Close"]])
end
md5(c, false); dump_as("MD5_details")
md5(c, true); dump_as("MD5_warning")
