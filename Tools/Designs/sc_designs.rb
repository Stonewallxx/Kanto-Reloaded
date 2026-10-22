# encoding: utf-8
# Mockups: Save Checker (topic 36), screen 1: Check Results. The full check
# of one save, opened from the Save Manager's health badge (the Health Check
# is its quick form). It loads the save on a copy, without starting the game.
# Sample: File A (Main Run), healthy with 2 notes: the Shiny Log needs an
# upgrade (version 2 to 3), and 2 Pokémon and 1 item the game no longer has.
# Each design is a pair: the overview (left), one part opened (right).
# Design 1 = the Settings layout.
# Usage (from this folder): ruby sc_designs.rb "<KIF Beta>" <work dir with metrics.json>
SSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "saves/save_designs.rb"), :encoding => "UTF-8")
eval(SSRC.split("#================================================================ S1 Recommended")[0], binding, "save_designs.rb")
OVER = layer(3)

ST = { :ok => ["OK", GREEN], :note => ["NOTE", GOLD], :bad => ["PROBLEM", RED] }
CHECKS = [[:ok, "File", "Loads. 1.8 MB, saved today 3:42 PM."], [:ok, "Kanto Reloaded Data", "Found: 12 parts."],
          [:note, "Upgrades", "Shiny Log: version 2 to 3."], [:ok, "Plain Values", "Loads without Kanto Reloaded."],
          [:note, "Missing Content", "2 Pokémon and 1 item."], [:ok, "Mod Data", "3 mods have data in this save."]]
PARTS = [["Settings", "2", :ok], ["Run Card", "1", :ok], ["Shiny Log", "2 to 3", :note], ["PC", "2", :ok], ["Wild Link", "1", :ok],
         ["Weather", "1", :ok], ["Expanded Dex", "1", :ok]]
def st_pill(t, x, y, st, right = true); l, colr = ST[st]; badge(t, x, y, l, colr, right); end
def sc_title(c, sub = nil)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, 34, c[:panel2]); b.fill_rect(0, 33, W, 1, c[:line])
  P.text(t, 0, 3, W, 28, "Save Check", c[:title], PF::TITLE, 2)
  UI.rbox(b, 8, 6, 14, 28, 2, Color.new(*TAGS[0]))
  P.text(t, 20, 7, 140, 20, "File A", c[:txt], PF::TEXT)
  P.small(t, W - 170, 10, 160, 16, sub || "Checked on a copy", c[:dim], 1)
end
def side(c, secs, sel)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 6, 40, 174, 262, 6, c[:panel])
  secs.each_with_index do |(l, st), i|
    y = 44 + i * 22
    UI.rbox(t, 14, y + 7, 20, y + 13, 3, ST[st][1])
    P.text(t, 26, y + 2, 146, 18, l, i == sel ? c[:white] : c[:dim])
  end
  UI.rbox(b, 180, 40, W - 6, 262, 6, c[:panel])
  UI.rbox(b, 6, 268, W - 6, H - 30, 6, c[:panel2], c[:line])
end
def desc(c, title, text, pills = [])
  t = TOP.bitmap
  P.text(t, 14, 269, 330, 26, title, c[:head], PF::ROW)
  x = W - 14
  pills.each { |p| x -= P.pill(t, x, 276, p, Color.new(40, 46, 60), c[:txt]) + 6 }
  P.small_wrap(t, text, W - 30).first(3).each_with_index { |ln, k| P.small(t, 14, 297 + k * 17, W - 34, 17, ln, c[:txt]) }
end
D_UP = ["Shiny Log", "Saved by Kanto Reloaded 1.9 (version 2). The next load upgrades it to version 3 (adds the encounter method). Nothing is lost.", ["UPGRADE"]]

c = palette(2)

#================================================================ SC1 Recommended: the Settings layout; Overview first, then each part
SECS = [["Overview", :note], ["File", :ok], ["Kanto Reloaded", :note], ["Missing Content", :note], ["Mod Data", :ok]]
def sc1(c, sec)
  frame(c); OVER.bitmap.clear
  sc_title(c); side(c, SECS, sec)
  t = TOP.bitmap
  if sec == 0
    P.heading(t, 190, W - 16, 47, "Overview: Healthy, 2 Notes", c[:head], c[:line])
    CHECKS.each_with_index do |(st, l, v), i|
      y = 58 + i * 34
      cursor_at(184, y, W - 194, 33) if i == 2
      P.text(t, 196, y, 220, 18, l, c[:opt], PF::TEXT)
      P.small(t, 196, y + 19, 230, 14, v, c[:dim])
      st_pill(t, W - 16, y + 7, st)
    end
    desc(c, *D_UP)
    hints(c, [[:ud, "Select"], [A_BTN, "Open"], [Y_BTN, "Check Again"], [B_BTN, "Back"]])
  else
    P.heading(t, 190, W - 16, 47, "Kanto Reloaded: 12 Parts", c[:head], c[:line])
    P.text(t, 330, 45, 100, 12, "VERSION", c[:dim], PF::TINY, 2)
    PARTS.each_with_index do |(n, v, st), i|
      y = 60 + i * 28
      cursor_at(184, y, W - 194, 26) if i == 2
      P.text(t, 196, y + 2, 150, 22, n, c[:opt], PF::TEXT)
      P.text(t, 330, y + 2, 100, 22, v, st == :ok ? c[:txt] : GOLD, PF::TEXT, 2)
      st_pill(t, W - 16, y + 6, st)
    end
    desc(c, *D_UP)
    hints(c, [[:ud, "Select"], [Y_BTN, "Check Again"], [B_BTN, "Sections"]])
  end
end
sc1(c, 0); dump_as("SC1_overview")
sc1(c, 2); dump_as("SC1_kr")

#================================================================ SC2: a report card; a verdict, the checks ticked off, Fix Safely
def tick(t, x, y, st)
  colr = ST[st][1]
  UI.rbox(t, x, y, x + 16, y + 16, 8, Color.new(colr.red / 4, colr.green / 4, colr.blue / 4), colr)
  if st == :ok
    [[4, 8], [5, 9], [6, 10], [7, 9], [8, 8], [9, 7], [10, 6], [11, 5]].each { |px, py| t.fill_rect(x + px, y + py, 2, 2, colr) }
  else
    t.fill_rect(x + 7, y + 4, 2, 6, colr); t.fill_rect(x + 7, y + 11, 2, 2, colr)
  end
end
def sc2(c, open)
  frame(c); OVER.bitmap.clear
  sc_title(c)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 8, 40, W - 8, 82, 8, col(GOLD, 40), GOLD)
  P.text(t, 20, 42, 300, 24, "Healthy, 2 Notes", GOLD, PF::ROW)
  P.small(t, 20, 64, 400, 16, "Nothing is wrong with the file. 2 things are worth a look.", c[:txt])
  UI.rbox(b, 8, 88, W - 8, 300, 6, c[:panel])
  CHECKS.each_with_index do |(st, l, v), i|
    y = 92 + i * 34
    cursor_at(12, y - 1, W - 24, 33) if (open ? 4 : 2) == i
    tick(t, 20, y + 8, st)
    P.text(t, 46, y, 200, 18, l, c[:opt], PF::TEXT)
    P.small(t, 46, y + 19, 400, 14, v, c[:dim])
  end
  UI.rbox(b, 8, 306, 250, 348, 6, c[:sel], c[:selb]); P.text(t, 8, 316, 242, 22, "Fix Safely", c[:white], PF::TEXT, 2)
  UI.rbox(b, 262, 306, W - 8, 348, 6, c[:dark], c[:line]); P.text(t, 262, 316, W - 270, 22, "Save the Report", c[:txt], PF::TEXT, 2)
  hints(c, [[:ud, "Select"], [A_BTN, "Details"], [X_BTN, "Fix Safely"], [B_BTN, "Back"]])
end
sc2(c, false); dump_as("SC2_card")
sc2(c, true); dump_as("SC2_missing")

#================================================================ SC3: inside the Save Manager; the details panel gets a Health tab
def sc3(c, scrolled)
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
    i == 0 ? badge(t, 224, y + 4, "2 NOTES", GOLD, true) : health(t, s, 224, y + 4, true)
  end
  UI.rbox(b, 238, 62, 504, 352, 6, c[:panel])
  ["DETAILS", "HEALTH"].each_with_index do |n, i|
    x = 246 + i * 128
    UI.rbox(b, x, 68, x + 120, 86, 5, i == 1 ? c[:sel] : c[:dark], i == 1 ? c[:selb] : c[:line])
    P.text(t, x, 69, 120, 16, n, i == 1 ? c[:white] : c[:dim], PF::TINY, 2)
  end
  rows = scrolled ? CHECKS.drop(3) : CHECKS.first(4)
  rows.each_with_index do |(st, l, v), i|
    y = 94 + i * 46
    tick(t, 248, y + 4, st)
    P.text(t, 272, y, 220, 18, l, c[:opt], PF::TEXT)
    P.small_wrap(t, v, 222).first(2).each_with_index { |ln, k| P.small(t, 272, y + 20 + k * 14, 226, 14, ln, c[:dim]) }
  end
  if scrolled
    UI.rbox(b, 248, 300, 494, 344, 5, col(GOLD, 40), GOLD)
    P.text(t, 248, 302, 246, 20, "2 Notes: Fix Safely?", GOLD, PF::TEXT, 2)
    P.text(t, 248, 322, 246, 14, "X FIXES A COPY, KEPT AS A BACKUP", c[:dim], PF::TINY, 2)
  end
  hints(c, [[:ud, "Choose"], ["p:10", "Health"], [A_BTN, "Open"], [X_BTN, "Fix Safely"], [B_BTN, "Close"]])
end
sc3(c, false); dump_as("SC3_health")
sc3(c, true); dump_as("SC3_scrolled")

#================================================================ SC4: six tiles, one per check; A opens a tile
def sc4(c, open)
  frame(c); OVER.bitmap.clear
  sc_title(c)
  b = BASE.bitmap; t = TOP.bitmap
  if open
    UI.rbox(b, 8, 40, W - 8, 82, 6, col(GOLD, 40), GOLD)
    P.text(t, 20, 42, 300, 24, "Upgrades", GOLD, PF::ROW)
    P.small(t, 20, 64, 460, 16, "What the next load upgrades, part by part.", c[:txt])
    UI.rbox(b, 8, 88, W - 8, 262, 6, c[:panel])
    [["Shiny Log", "2 to 3", "Adds the encounter method to each entry.", :note], ["Run Card", "1", "Up to date.", :ok], ["PC", "2", "Up to date.", :ok]].each_with_index do |(n, v, why, st), i|
      y = 94 + i * 52
      cursor_at(12, y - 2, W - 24, 50) if i == 0
      P.text(t, 24, y, 200, 20, n, c[:opt], PF::TEXT)
      P.small(t, 24, y + 22, 380, 16, why, c[:dim])
      P.text(t, 300, y, 100, 20, "v#{v}", st == :ok ? c[:txt] : GOLD, PF::TEXT, 1)
      st_pill(t, W - 18, y + 4, st)
    end
    desc(c, *D_UP)
    hints(c, [[:ud, "Select"], [B_BTN, "Tiles"]])
  else
    CHECKS.each_with_index do |(st, l, v), i|
      x = 8 + (i % 3) * 168; y = 40 + (i / 3) * 112
      colr = ST[st][1]
      UI.rbox(b, x, y, x + 160, y + 104, 8, col(colr, 30), i == 2 ? c[:selb] : colr)
      cursor_at(x - 2, y - 2, 164, 108) if i == 2
      tick(t, x + 10, y + 10, st)
      P.text(t, x + 32, y + 8, 124, 20, l.sub("Kanto Reloaded Data", "KR Data").sub("Missing Content", "Missing"), c[:white], PF::TEXT)
      P.small_wrap(t, v, 140).first(3).each_with_index { |ln, k| P.small(t, x + 10, y + 40 + k * 16, 144, 16, ln, c[:txt]) }
    end
    UI.rbox(b, 8, 268, W - 8, H - 30, 6, c[:panel2], c[:line])
    P.text(t, 14, 270, 400, 24, "Healthy, 2 Notes", GOLD, PF::ROW)
    P.small(t, 14, 298, 480, 16, "Checked on a copy of File A; the save itself was not changed.", c[:txt])
    hints(c, [[:ud, ""], [:lr, "Select"], [A_BTN, "Open"], [Y_BTN, "Check Again"], [B_BTN, "Back"]])
  end
end
sc4(c, false); dump_as("SC4_tiles")
sc4(c, true); dump_as("SC4_open")

#================================================================ SC5: the check as it runs, line by line; then the summary
def sc5(c, done)
  frame(c); OVER.bitmap.clear
  sc_title(c, done ? "Done in 0.8 s" : "Checking...")
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 8, 40, W - 8, 52, 5, c[:dark]); UI.rbox(b, 8, 40, 8 + ((W - 16) * (done ? 1.0 : 0.6)).to_i, 52, 5, done ? GOLD : BLUE)
  UI.rbox(b, 8, 58, W - 8, 300, 6, c[:panel])
  lines = [[:ok, "Copied File A to a safe place."], [:ok, "The file loads (1.8 MB)."], [:ok, "Kanto Reloaded's data: 12 parts found."],
           [:note, "Shiny Log: version 2, upgraded to 3 on load."], [:ok, "Plain values only: loads without Kanto Reloaded."],
           [:note, "2 Pokémon and 1 item the game doesn't have."], [:ok, "3 mods have data in this save."]]
  shown = done ? lines : lines.first(4)
  shown.each_with_index do |(st, l), i|
    y = 64 + i * 26
    tick(t, 18, y + 4, st)
    P.text(t, 42, y, 450, 24, l, st == :ok ? c[:txt] : GOLD, PF::TEXT)
  end
  P.small(t, 42, 64 + shown.length * 26 + 4, 300, 16, "Checking plain values...", c[:dim]) unless done
  if done
    UI.rbox(b, 8, 306, 250, 348, 6, c[:sel], c[:selb]); P.text(t, 8, 316, 242, 22, "See the 2 Notes", c[:white], PF::TEXT, 2)
    UI.rbox(b, 262, 306, W - 8, 348, 6, c[:dark], c[:line]); P.text(t, 262, 316, W - 270, 22, "Done", c[:txt], PF::TEXT, 2)
  end
  hints(c, done ? [[:lr, "Choose"], [A_BTN, "Select"], [B_BTN, "Back"]] : [[B_BTN, "Stop"]])
end
sc5(c, false); dump_as("SC5_running")
sc5(c, true); dump_as("SC5_done")
