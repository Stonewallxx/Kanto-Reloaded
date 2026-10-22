# encoding: utf-8
# Mockups: Bug Report Bundle (topic 37), screen 1: Make a Bug Report (from
# Settings, System). One file with every log (KR's, KIF_log, KIF_errorlog,
# PIF's errorlog), the settings, the mod list, load order and versions, KR's
# hook summary and conflicts, and the current save's Save Check; plus What
# Happened (a note typed straight in, and a screenshot), Include the Save
# (off by default) and the Privacy Check.
# Each design is a pair: the form (left), the save added and the note being
# typed (right). Design 1 = the Settings layout.
# Usage (from this folder): ruby br_designs.rb "<KIF Beta>" <work dir with metrics.json>
MSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "mc_designs.rb"), :encoding => "UTF-8")
eval(MSRC.split("c = palette(2)\n")[0], binding, "mc_designs.rb")

NOTE = "Game froze after Gyarados used Thrash in a double battle."
SHOT = File.join(File.dirname(File.expand_path(__FILE__)), "ebdx/doubles_command.png")
INCL = [["Logs", "4 Files", :ok], ["Settings", "KR and KIF", :ok], ["Mods", "5, Load Order", :ok], ["Hooks", "Summary", :ok], ["Save Check", "File A", :ok]]
def br_title(c)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, 34, c[:panel2]); b.fill_rect(0, 33, W, 1, c[:line])
  P.text(t, 0, 3, W, 28, "Bug Report", c[:title], PF::TITLE, 2)
end
def shot(t, x, y, w)
  h = w * 3 / 4
  t.stretch_blt(Rect.new(x, y, w, h), bmp(SHOT), Rect.new(0, 0, 512, 384))
  t.fill_rect(x, y, w, 1, c_line = Color.new(120, 130, 150)); t.fill_rect(x, y + h - 1, w, 1, c_line); t.fill_rect(x, y, 1, h, c_line); t.fill_rect(x + w - 1, y, 1, h, c_line)
end
def field(c, x, y, w, text, typing)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, x, y, x + w, y + 44, 6, c[:dark], typing ? c[:selb] : c[:line])
  lines = P.small_wrap(t, text, w - 16)
  lines.first(2).each_with_index { |ln, k| P.small(t, x + 8, y + 5 + k * 17, w - 16, 16, ln, c[:white]) }
  if typing
    last = lines.first(2).last.to_s
    lx = x + 8 + (P.small_wrap(t, last, 999).length > 0 ? last.length * 0 : 0)
  end
end
def size_line(c, with_save); with_save ? "KR Bug Report 2026-10-18 14-05.zip, about 2.0 MB" : "KR Bug Report 2026-10-18 14-05.zip, about 214 KB"; end

c = palette(2)

#================================================================ BR1 Recommended: the Settings layout; What Happened, What's In It, Privacy as sections
def br1(c, with_save)
  frame(c); OVER.bitmap.clear
  br_title(c)
  side(c, [["What Happened", :ok], ["What's In It", :ok]], with_save ? 1 : 0)   # no Privacy section (his call): user names are cleared automatically
  b = BASE.bitmap; t = TOP.bitmap
  if with_save
    P.heading(t, 190, W - 16, 47, "What's In It", c[:head], c[:line])
    (INCL + [["Include the Save", "File A", :note]]).each_with_index do |(l, v, st), i|
      y = 60 + i * 30
      cursor_at(184, y, W - 194, 28) if i == 5
      tick(t, 194, y + 5, st == :note ? :ok : st)
      P.text(t, 218, y + 2, 170, 22, l, c[:opt], PF::TEXT)
      i == 5 ? value_cell_s(t, c, W - 70, y + 2, v, true) : P.text(t, 350, y + 2, 140, 22, v, c[:txt], PF::TEXT, 1)
    end
    P.small(t, 196, 242, 300, 16, "User names are taken out of paths.", c[:dim])
    desc(c, "Include the Save", "Adds a copy of File A (1.8 MB), so the bug can be played again. Your save itself isn't changed. #{size_line(c, true)}.", ["OFF BY DEFAULT"])
    hints(c, [[:ud, "Select"], [:lr, "Change"], [Y_BTN, "Make Report"], [B_BTN, "Sections"]])
  else
    P.heading(t, 190, W - 16, 47, "What Happened", c[:head], c[:line])
    field(c, 190, 62, 306, NOTE, false)
    P.text(t, 196, 110, 200, 22, "Screenshot", c[:opt], PF::TEXT)
    value_cell_s(t, c, W - 76, 110, "This Screen", false)
    shot(t, 196, 138, 128)
    P.small_wrap(t, "The screen as it was when you opened Settings. Or the last screenshot, or none.", 160).each_with_index { |ln, k| P.small(t, 334, 140 + k * 16, 164, 16, ln, c[:dim]) }
    cursor_at(184, 60, W - 194, 48)
    desc(c, "What Happened", "Type straight in: what you were doing and what went wrong. A opens the naming screen.", [])
    hints(c, [[:ud, "Select"], [A_BTN, "Naming Screen"], [Y_BTN, "Make Report"], [B_BTN, "Sections"]])
  end
  UI.rbox(BASE.bitmap, W - 140, 4, W - 8, 27, 5, Color.new(24, 60, 40), GREEN); P.text(TOP.bitmap, W - 140, 4, 132, 23, "Make Report", GREEN, PF::TEXT, 2)
end
def value_cell_s(t, c, cx, y, v, sel)
  vw = P.width(PF::TEXT, v)
  P.text(t, cx - vw / 2, y, vw + 2, 22, v, c[:opt], PF::TEXT)
  arrow = sel ? c[:txt] : c[:dim]
  UI.tri(t, cx - vw / 2 - 14, y + 7, :l, arrow, 4); UI.tri(t, cx + vw / 2 + 6, y + 7, :r, arrow, 4)
end
br1(c, false); dump_as("BR1_note")
br1(c, true); dump_as("BR1_save")

#================================================================ BR2: the report card look; one form card, then Make Report
def br2(c, with_save)
  frame(c); OVER.bitmap.clear
  br_title(c)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 8, 40, W - 8, 300, 6, c[:panel])
  P.small(t, 18, 44, 200, 14, "WHAT HAPPENED", c[:head])
  field(c, 16, 60, 340, NOTE, !with_save)
  cursor_at(14, 58, 344, 48) unless with_save
  shot(t, 368, 46, 128)
  P.small(t, 368, 144, 128, 14, "This Screen", c[:dim], 2)
  b.fill_rect(16, 164, W - 32, 1, c[:line])
  P.small(t, 18, 170, 200, 14, "IN THE REPORT", c[:head])
  INCL.each_with_index do |(l, v, st), i|
    x = 18 + (i % 3) * 160; y = 188 + (i / 3) * 24
    tick(t, x, y + 2, st)
    P.small(t, x + 22, y + 2, 132, 16, l, c[:txt])
  end
  y = 240
  cursor_at(14, y - 2, W - 28, 28) if with_save
  UI.rbox(t, 20, y + 4, 36, y + 20, 3, with_save ? GREEN : c[:dark], with_save ? GREEN : c[:dim])
  [[4, 8], [5, 9], [6, 10], [7, 9], [8, 8], [9, 7], [10, 6], [11, 5]].each { |px, py| t.fill_rect(20 + px, y + 4 + py, 2, 2, Color.new(20, 40, 24)) } if with_save
  P.text(t, 46, y, 300, 22, "Include a copy of File A", c[:opt], PF::TEXT)
  P.small(t, 18, 270, 480, 16, size_line(c, with_save), c[:dim])
  UI.rbox(b, 8, 306, 250, 348, 6, Color.new(24, 60, 40), GREEN); P.text(t, 8, 316, 242, 22, "Make Report", GREEN, PF::TEXT, 2)
  UI.rbox(b, 262, 306, W - 8, 348, 6, c[:dark], c[:line]); P.text(t, 262, 316, W - 270, 22, "Privacy Check", c[:txt], PF::TEXT, 2)
  hints(c, [[:ud, "Select"], [A_BTN, with_save ? "Toggle" : "Type"], [X_BTN, "Privacy"], [Y_BTN, "Make"], [B_BTN, "Back"]])
end
br2(c, false); dump_as("BR2_note")
br2(c, true); dump_as("BR2_save")

#================================================================ BR3: steps; 1 What Happened, 2 What's In It, 3 Privacy, 4 Make
BSTEPS = ["Note", "What's In", "Privacy", "Make"]
def br3(c, cur)
  frame(c); OVER.bitmap.clear
  br_title(c)
  b = BASE.bitmap; t = TOP.bitmap
  BSTEPS.each_with_index do |s, i|
    x = 8 + i * 125
    on = i == cur; done = i < cur
    UI.rbox(b, x, 38, x + 120, 60, 5, on ? c[:sel] : c[:dark], on ? c[:selb] : (done ? GREEN : c[:line]))
    P.small(t, x, 41, 120, 16, "#{i + 1}. #{s}", on ? c[:white] : (done ? GREEN : c[:dim]), 2)
  end
  UI.rbox(b, 6, 66, W - 6, 300, 6, c[:panel])
  if cur == 0
    field(c, 16, 74, W - 32, NOTE, true)
    cursor_at(14, 72, W - 28, 48)
    P.text(t, 20, 130, 200, 22, "Screenshot", c[:opt], PF::TEXT); value_cell_s(t, c, 210, 130, "This Screen", false)
    shot(t, 316, 128, 176)
  else
    INCL.each_with_index do |(l, v, st), i|
      y = 74 + i * 30
      tick(t, 20, y + 4, st)
      P.text(t, 46, y + 2, 200, 22, l, c[:opt], PF::TEXT)
      P.text(t, 330, y + 2, 160, 22, v, c[:txt], PF::TEXT, 1)
    end
    cursor_at(10, 72 + 5 * 30, W - 20, 28)
    P.text(t, 46, 76 + 5 * 30, 220, 22, "Include the Save", c[:opt], PF::TEXT); value_cell_s(t, c, W - 76, 76 + 5 * 30, "File A", true)
  end
  P.small(t, 8, 306, W - 16, 16, cur == 0 ? "A opens the naming screen. Right: next step." : size_line(c, true), c[:dim], 2)
  hints(c, [[:ud, "Select"], [:lr, "Change"], ["p:10", "Next Step"], [B_BTN, "Back"]])
end
br3(c, 0); dump_as("BR3_note")
br3(c, 1); dump_as("BR3_included")

#================================================================ BR4: the form on the left, the bundle's files on the right as it fills
FILES_IN = [["note.txt", "1 KB"], ["screenshot.png", "61 KB"], ["Kanto Reloaded.log", "48 KB"], ["Kanto Reloaded.old.log", "52 KB"], ["KIF_log.txt", "22 KB"], ["KIF_errorlog.txt", "6 KB"],
            ["errorlog.txt", "4 KB"], ["settings.txt", "8 KB"], ["mods.txt", "2 KB"], ["hooks.txt", "5 KB"], ["save-check.txt", "3 KB"]]
def br4(c, with_save)
  frame(c); OVER.bitmap.clear
  br_title(c)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 6, 40, 270, 300, 6, c[:panel])
  P.small(t, 16, 44, 200, 14, "WHAT HAPPENED", c[:head])
  field(c, 14, 60, 248, NOTE, false)
  P.text(t, 18, 112, 120, 22, "Screenshot", c[:opt], PF::TEXT); value_cell_s(t, c, 200, 112, "This Screen", false)
  P.text(t, 18, 138, 140, 22, "Include the Save", c[:opt], PF::TEXT); value_cell_s(t, c, 212, 138, with_save ? "File A" : "Off", with_save)
  cursor_at(10, 136, 256, 26) if with_save
  cursor_at(10, 58, 256, 48) unless with_save
  UI.rbox(b, 276, 40, W - 6, 300, 6, c[:panel2], c[:line])
  P.small(t, 286, 44, 200, 14, "THE REPORT'S FILES", c[:head])
  files = with_save ? FILES_IN.first(9) + [["File A.rxdata", "1.8 MB"]] : FILES_IN.first(10)
  files.each_with_index do |(n, s), i|
    y = 62 + i * 21
    hl = n.end_with?(".rxdata")
    P.small(t, 286, y, 150, 16, n, hl ? GOLD : c[:txt])
    P.small(t, 430, y, 66, 16, s, c[:dim], 1)
  end
  P.small(t, 286, 278, 210, 16, with_save ? "About 2.0 MB" : "About 214 KB", c[:txt], 1)
  UI.rbox(b, 8, 306, W - 8, 348, 6, Color.new(24, 60, 40), GREEN); P.text(t, 8, 316, W - 16, 22, "Make Report", GREEN, PF::TEXT, 2)
  hints(c, [[:ud, "Select"], [:lr, "Change"], [X_BTN, "Privacy Check"], [Y_BTN, "Make Report"], [B_BTN, "Back"]])
end
br4(c, false); dump_as("BR4_note")
br4(c, true); dump_as("BR4_save")

#================================================================ BR5: quick; a small panel over Settings, one press with the defaults, a note if you want
def br5(c, note)
  frame(c); OVER.bitmap.clear
  MAPS.bitmap = Bitmap.new(W, H)
  b = BASE.bitmap; t = TOP.bitmap
  P.text(t, 0, 4, W, 28, "Settings", c[:dim], PF::TITLE, 2)
  o = OVER.bitmap
  o.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 150))
  UI.rbox(o, 76, note ? 60 : 96, 436, note ? 328 : 292, 8, c[:panel2], c[:selb])
  y0 = note ? 66 : 102
  P.text(o, 76, y0, 360, 26, "Make a Bug Report", c[:title], PF::ROW, 2)
  P.small(o, 90, y0 + 30, 332, 16, "Logs, settings and mods in one file.", c[:txt], 2)
  if note
    UI.rbox(o, 90, y0 + 54, 422, y0 + 98, 6, c[:dark], c[:selb])
    P.small_wrap(o, NOTE, 316).first(2).each_with_index { |ln, k| P.small(o, 98, y0 + 59 + k * 17, 316, 16, ln, c[:white]) }
  end
  btn_y = note ? y0 + 112 : y0 + 60
  [["Make Report", true], ["Add a Note", false], ["More Options", false]].each_with_index do |(l, on), i|
    y = btn_y + i * 34
    l = "Note Added" if note && i == 1
    UI.rbox(o, 116, y, 396, y + 28, 6, on ? Color.new(24, 60, 40) : c[:dark], on ? GREEN : c[:line])
    P.text(o, 116, y + 2, 280, 24, l, on ? GREEN : c[:txt], PF::TEXT, 2)
  end
  P.small(o, 76, btn_y + 106, 360, 16, "About 214 KB", c[:dim], 2)
  o.fill_rect(0, H - 28, W, 28, Color.new(0, 0, 0, 0))
  hints(c, [[:ud, "Choose"], [A_BTN, "Select"], [B_BTN, "Cancel"]])
end
br5(c, false); dump_as("BR5_quick")
br5(c, true); dump_as("BR5_note")
