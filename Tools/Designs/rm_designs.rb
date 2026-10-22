# encoding: utf-8
# Mockups: Bug Report Bundle (topic 37), screen 4: Report Made. Where the
# file was saved, its size, and what to do next. "GitHub Issues" is a
# stand-in for wherever Kanto Reloaded takes bug reports.
# Each design is a pair: made from Settings (left), made after a crash, where
# the game then closes (right). Design 1 = the chosen notice look.
# Usage (from this folder): ruby rm_designs.rb "<KIF Beta>" <work dir with metrics.json>
ASRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "ac_designs.rb"), :encoding => "UTF-8")
eval(ASRC.split("c = palette(2)\n")[0], binding, "ac_designs.rb")

FILE = "KR Bug Report 2026-10-18 14-05.zip"
WHERE = "Desktop"
SIZE = "214 KB"
SEND = "Send it in Kanto Reloaded's Discord, in the bug reports channel, with what happened."
def settings_bg(c)
  frame(c); OVER.bitmap.clear
  MAPS.bitmap = Bitmap.new(W, H)
  P.text(TOP.bitmap, 0, 4, W, 28, "Bug Report", c[:dim], PF::TITLE, 2)
  OVER.bitmap.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 120))
end

c = palette(2)

#================================================================ RM1 Recommended: the notice look; file, size, where it is, where to send it
def rm1(c, crash)
  crash ? battle_bg(c) : settings_bg(c)
  o = OVER.bitmap
  x0 = 64; x1 = 448; y0 = 80
  UI.rbox(o, x0, y0, x1, y0 + 214, 8, c[:panel2], GREEN)
  P.text(o, x0, y0 + 6, x1 - x0, 26, "Bug Report Made", GREEN, PF::ROW, 2)
  P.small(o, x0, y0 + 34, x1 - x0, 16, "#{WHERE}: #{FILE}", c[:txt], 2)
  P.small(o, x0, y0 + 52, x1 - x0, 16, "#{SIZE}, logs, settings, mods and the Save Check", c[:dim], 2)
  o.fill_rect(x0 + 12, y0 + 76, x1 - x0 - 24, 1, c[:line])
  P.small_wrap(o, SEND, 344).each_with_index { |ln, k| P.small(o, x0 + 20, y0 + 84 + k * 17, 344, 16, ln, c[:txt]) }
  P.small(o, x0 + 20, y0 + 124, 344, 16, crash ? "The game closes when you're done." : "Thank you: it helps get the bug fixed.", crash ? GOLD : c[:dim])
  two_buttons(o, c, x0, x1, y0 + 166, "Open the Folder", crash ? "Close the Game" : "Done")
  clear_bar(c)
  hints(c, [[:lr, "Choose"], [A_BTN, "Select"]])
end
rm1(c, false); dump_as("RM1_settings")
rm1(c, true); dump_as("RM1_crash")

#================================================================ RM2: the report card look, full screen; the report's details ticked off
def rm2(c, crash)
  frame(c); OVER.bitmap.clear
  MAPS.bitmap = Bitmap.new(W, H)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, 34, c[:panel2]); b.fill_rect(0, 33, W, 1, c[:line])
  P.text(t, 0, 3, W, 28, "Bug Report", c[:title], PF::TITLE, 2)
  UI.rbox(b, 8, 40, W - 8, 82, 8, col(GREEN, 40), GREEN)
  P.text(t, 20, 42, 400, 24, "Bug Report Made", GREEN, PF::ROW)
  P.small(t, 20, 64, 470, 16, crash ? "Saved before the game closes." : "Saved and ready to send.", c[:txt])
  UI.rbox(b, 8, 88, W - 8, 300, 6, c[:panel])
  [["File", FILE], ["Where", "#{WHERE} (and the game's Logs folder)"], ["Size", SIZE], ["Send It To", "Kanto Reloaded's GitHub Issues page"]].each_with_index do |(k, v), i|
    y = 96 + i * 44
    UI.rbox(t, 20, y + 4, 36, y + 20, 8, Color.new(24, 60, 40), GREEN)
    [[4, 8], [5, 9], [6, 10], [7, 9], [8, 8], [9, 7], [10, 6], [11, 5]].each { |px, py| t.fill_rect(20 + px, y + 4 + py, 2, 2, GREEN) }
    P.text(t, 46, y, 200, 20, k, c[:opt], PF::TEXT)
    P.small(t, 46, y + 21, 440, 16, v, c[:dim])
  end
  UI.rbox(b, 8, 306, 250, 348, 6, c[:sel], c[:selb]); P.text(t, 8, 316, 242, 22, "Open the Folder", c[:white], PF::TEXT, 2)
  UI.rbox(b, 262, 306, W - 8, 348, 6, c[:dark], c[:line]); P.text(t, 262, 316, W - 270, 22, crash ? "Close the Game" : "Done", c[:txt], PF::TEXT, 2)
  hints(c, [[:lr, "Choose"], [A_BTN, "Select"]])
end
rm2(c, false); dump_as("RM2_settings")
rm2(c, true); dump_as("RM2_crash")

#================================================================ RM3: a toast; it doesn't stop you; Settings then shows the last report
def rm3(c, crash)
  if crash
    battle_bg(c, 60)
  else
    frame(c); OVER.bitmap.clear; MAPS.bitmap = Bitmap.new(W, H)
    b = BASE.bitmap; t = TOP.bitmap
    b.fill_rect(0, 0, W, 34, c[:panel2]); b.fill_rect(0, 33, W, 1, c[:line])
    P.text(t, 0, 3, W, 28, "Bug Report", c[:title], PF::TITLE, 2)
    UI.rbox(b, 8, 40, W - 8, 300, 6, c[:panel])
    [["Make a Bug Report", ""], ["Last Report", "Today 2:05 PM, #{SIZE}"]].each_with_index do |(k, v), i|
      y = 50 + i * 34
      cursor_at(12, y - 2, W - 24, 30) if i == 1
      P.text(t, 24, y, 200, 24, k, c[:opt], PF::TEXT); P.text(t, 220, y, 274, 24, v, c[:txt], PF::TEXT, 1)
    end
  end
  o = OVER.bitmap
  UI.rbox(o, W - 286, 6, W - 6, 64, 6, Color.new(20, 24, 34, 255), GREEN)
  UI.rbox(o, W - 276, 16, W - 262, 30, 7, GREEN)
  P.text(o, W - 254, 8, 240, 22, "Bug Report Made", c[:white], PF::TEXT)
  P.small(o, W - 254, 30, 244, 16, "On the #{WHERE}, #{SIZE}.", c[:txt])
  P.small(o, W - 254, 46, 244, 16, crash ? "The game closes in 5 s." : "Hold Select: Open the Folder", c[:dim])
  clear_bar(c)
  hints(c, crash ? [[A_BTN, "Close Now"]] : [[:ud, "Select"], [A_BTN, "Open the Folder"], [B_BTN, "Back"]])
end
rm3(c, false); dump_as("RM3_settings")
rm3(c, true); dump_as("RM3_crash")

#================================================================ RM4: next steps as a numbered list, each with its button
def rm4(c, crash)
  frame(c); OVER.bitmap.clear; MAPS.bitmap = Bitmap.new(W, H)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, 34, c[:panel2]); b.fill_rect(0, 33, W, 1, c[:line])
  P.text(t, 0, 3, W, 28, "Bug Report Made", GREEN, PF::TITLE, 2)
  steps = [["Find the File", "#{FILE} (#{SIZE}), on the #{WHERE}.", "Open the Folder"],
           ["Send It", "On Kanto Reloaded's GitHub Issues page, attach the file.", "Copy the Link"],
           ["Say What Happened", "Your note is in the file; a line in the post helps too.", nil]]
  steps.each_with_index do |(h, txt, btn), i|
    y = 42 + i * 84
    UI.rbox(b, 8, y, W - 8, y + 78, 6, c[:panel], i == 0 ? c[:selb] : c[:line])
    UI.rbox(t, 18, y + 8, 40, y + 30, 11, c[:sel], c[:selb]); P.text(t, 18, y + 9, 22, 20, (i + 1).to_s, c[:white], PF::TEXT, 2)
    P.text(t, 50, y + 6, 300, 22, h, c[:opt], PF::TEXT)
    P.small(t, 50, y + 30, 440, 16, txt, c[:dim])
    if btn
      UI.rbox(b, W - 172, y + 48, W - 18, y + 72, 5, i == 0 ? c[:sel] : c[:dark], i == 0 ? c[:selb] : c[:line])
      P.text(t, W - 172, y + 49, 154, 22, btn, i == 0 ? c[:white] : c[:txt], PF::TEXT, 2)
    end
  end
  UI.rbox(b, 8, 300, W - 8, 330, 6, c[:dark], c[:line]); P.text(t, 8, 303, W - 16, 24, crash ? "Close the Game" : "Done", c[:txt], PF::TEXT, 2)
  hints(c, [[:ud, "Choose"], [A_BTN, "Select"], [B_BTN, crash ? "Close" : "Done"]])
end
rm4(c, false); dump_as("RM4_settings")
rm4(c, true); dump_as("RM4_crash")

#================================================================ RM5: the reports you've made, newest first; open, or delete old ones
REPORTS = [["Today 2:05 PM", "Game froze after Gyarados used Thrash...", SIZE, true], ["Today 1:12 PM", "After a crash: NoMethodError", "2.0 MB", false],
           ["Oct 15", "Wild Link chain reset in Viridian Forest", "180 KB", false]]
def rm5(c, crash)
  frame(c); OVER.bitmap.clear; MAPS.bitmap = Bitmap.new(W, H)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, 34, c[:panel2]); b.fill_rect(0, 33, W, 1, c[:line])
  P.text(t, 0, 3, W, 28, "Bug Reports", c[:title], PF::TITLE, 2)
  UI.rbox(b, 8, 40, W - 8, 82, 8, col(GREEN, 40), GREEN)
  P.text(t, 20, 42, 400, 24, crash ? "Saved Before Closing" : "New Report Made", GREEN, PF::ROW)
  P.small(t, 20, 64, 470, 16, "#{WHERE}: #{FILE}", c[:txt])
  UI.rbox(b, 8, 88, W - 8, 300, 6, c[:panel])
  REPORTS.each_with_index do |(w, note, sz, nw), i|
    y = 94 + i * 46
    cursor_at(12, y - 2, W - 24, 44) if i == 0
    P.text(t, 20, y, 200, 20, w, c[:opt], PF::TEXT)
    P.small(t, 20, y + 21, 380, 16, note, c[:dim])
    P.text(t, 380, y + 6, 110, 20, sz, c[:txt], PF::TEXT, 1)
    badge(t, 300, y + 4, "NEW", GREEN, true) if nw
  end
  P.small(t, 20, 240, 470, 16, SEND, c[:dim])
  UI.rbox(b, 8, 306, 250, 348, 6, c[:sel], c[:selb]); P.text(t, 8, 316, 242, 22, "Open the Folder", c[:white], PF::TEXT, 2)
  UI.rbox(b, 262, 306, W - 8, 348, 6, c[:dark], c[:line]); P.text(t, 262, 316, W - 270, 22, crash ? "Close the Game" : "Done", c[:txt], PF::TEXT, 2)
  hints(c, [[:ud, "Select"], [A_BTN, "Open the Folder"], ["p:2", "Delete"], [B_BTN, crash ? "Close" : "Done"]])
end
rm5(c, false); dump_as("RM5_settings")
rm5(c, true); dump_as("RM5_crash")
