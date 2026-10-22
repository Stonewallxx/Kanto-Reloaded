# encoding: utf-8
# Mockups: Bug Report Bundle (topic 37), screen 2: Privacy Check. Every file
# that goes in, shown before the report is made; the Windows user name is
# taken out of every path (C:\Users\Ash\... becomes C:\Users\[you]\...).
# "Ash" is a stand-in user name. Each file can be left out, and Trainer Name
# can be hidden too.
# Each design is a pair: the list (left), one file looked at (right).
# Design 1 = the Settings layout (the chosen Make a Bug Report's Privacy section).
# Usage (from this folder): ruby pk_designs.rb "<KIF Beta>" <work dir with metrics.json>
BRSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "br_designs.rb"), :encoding => "UTF-8")
eval(BRSRC.split("c = palette(2)\n")[0], binding, "br_designs.rb")
def value_cell_s(t, c, cx, y, v, sel)
  vw = P.width(PF::TEXT, v)
  P.text(t, cx - vw / 2, y, vw + 2, 22, v, c[:opt], PF::TEXT)
  arrow = sel ? c[:txt] : c[:dim]
  UI.tri(t, cx - vw / 2 - 14, y + 7, :l, arrow, 4); UI.tri(t, cx + vw / 2 + 6, y + 7, :r, arrow, 4)
end

# file, what's in it, user name found (count)
PFILES = [["Kanto Reloaded.log", "This session's log", 14], ["KIF_errorlog.txt", "Crash text", 3], ["KIF_log.txt", "KIF's session log", 6],
          ["settings.txt", "KR and KIF settings", 0], ["mods.txt", "Mods and versions", 5], ["save-check.txt", "File A's Save Check", 1]]
LOGLINES = [[' 14:02:11  Hook kif_bridge_desc failed', nil], [' in C:\Users\[you]\Desktop', :hl], ['   \KIF Beta\Mods\KantoReloaded', nil],
            [' 14:02:11  Settings: rebuilt 9 rows', nil], [' 14:02:13  Battle: wild double, Route 24', nil], [' 14:02:40  NoMethodError, line 212', nil]]
def redact_note(c); "Your Windows user name (Ash) becomes [you] in 29 places."; end
def cleaned(n); n == 0 ? "Nothing to clean" : "#{n} path#{n == 1 ? '' : 's'} cleaned"; end

c = palette(2)

#================================================================ PK1 Recommended: the Settings layout; files as rows with Include, the description shows what was taken out
def pk1(c, looking)
  frame(c); OVER.bitmap.clear
  br_title(c)
  side(c, [["What Happened", :ok], ["What's In It", :ok], ["Privacy", :ok]], 2)
  t = TOP.bitmap
  UI.rbox(BASE.bitmap, W - 140, 4, W - 8, 27, 5, Color.new(24, 60, 40), GREEN); P.text(t, W - 140, 4, 132, 23, "Make Report", GREEN, PF::TEXT, 2)
  P.heading(t, 190, W - 16, 47, "Privacy", c[:head], c[:line])
  rows = [["User Name in Paths", "Removed"], ["Trainer Name", "Keep"]] + PFILES.first(5).map { |f, _, n| [f, "Include"] }
  rows.each_with_index do |(l, v), i|
    y = 60 + i * 27
    sel = looking ? i == 2 : i == 0
    cursor_at(184, y, W - 194, 25) if sel
    P.text(t, 196, y + 1, 190, 22, PF.fit(PF::TEXT, l, 180), c[:opt], PF::TEXT)
    value_cell_s(t, c, W - 66, y + 1, v, sel)
    t.fill_rect(190, 60 + 2 * 27 - 3, W - 206, 1, c[:line]) if i == 1
  end
  if looking
    P.text(t, 14, 269, 330, 26, "Kanto Reloaded.log", c[:head], PF::ROW)
    P.pill(t, W - 14, 276, "14 PATHS CLEANED", Color.new(40, 46, 60), c[:txt])
    LOGLINES.first(3).each_with_index { |(ln, hl), k| P.small(t, 14, 296 + k * 15, W - 28, 15, ln, hl ? GREEN : c[:txt]) }
    hints(c, [[:ud, "Select"], [:lr, "Include"], [A_BTN, "Look Inside"], [B_BTN, "Sections"]])
  else
    desc(c, "User Name in Paths", redact_note(c), ["ALWAYS ON"])
    hints(c, [[:ud, "Select"], [A_BTN, "Look Inside"], [Y_BTN, "Make Report"], [B_BTN, "Sections"]])
  end
end
pk1(c, false); dump_as("PK1_list")
pk1(c, true); dump_as("PK1_look")

#================================================================ PK2: the file list on the left, the file itself on the right, cleaned parts in green
def pk2(c, sel)
  frame(c); OVER.bitmap.clear
  br_title(c)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 6, 40, 200, 300, 6, c[:panel])
  PFILES.each_with_index do |(f, what, n), i|
    y = 44 + i * 40
    cursor_at(9, y, 188, 38) if i == sel
    P.text(t, 16, y + 1, 180, 18, PF.fit(PF::TEXT, f, 176), c[:opt], PF::TEXT)
    P.small(t, 16, y + 20, 180, 14, cleaned(n), n > 0 ? GREEN : c[:dim])
  end
  UI.rbox(b, 206, 40, W - 6, 300, 6, c[:dark], c[:line])
  f = PFILES[sel][0]
  P.text(t, 214, 42, 284, 20, f, c[:head], PF::TEXT)
  lines = sel == 0 ? LOGLINES : [[' Kanto Reloaded 2.0.0', nil], [' KIF Beta 0.21.60, PIF 6.8.2', nil], [' Mods (load order):', nil], ['  1. Kanto Reloaded', nil], ['  2. Multiplayer', nil], ['  3. Mega Mod', nil], [' Folder: C:\Users\[you]\Desktop', :hl], ['   \KIF Beta', nil]]
  lines.each_with_index { |(ln, hl), k| P.small(t, 214, 66 + k * 18, 286, 16, ln, hl ? GREEN : c[:txt]) }
  P.small(t, 8, 306, W - 16, 16, redact_note(c), c[:dim], 2)
  hints(c, [[:ud, "Files"], [:lr, "Scroll"], [X_BTN, "Leave Out"], [B_BTN, "Back"]])
end
pk2(c, 0); dump_as("PK2_log")
pk2(c, 4); dump_as("PK2_mods")

#================================================================ PK3: a summary card; what's taken out, what's kept, what you can hide
def pk3(c, open)
  frame(c); OVER.bitmap.clear
  br_title(c)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 8, 40, W - 8, 82, 8, col(GREEN, 40), GREEN)
  P.text(t, 20, 42, 400, 24, "Ready to Share", GREEN, PF::ROW)
  P.small(t, 20, 64, 470, 16, "Your user name is out of every path.", c[:txt])
  UI.rbox(b, 8, 88, W - 8, 300, 6, c[:panel])
  items = [[:ok, "Taken out", "Your Windows user name, in 29 paths"], [:ok, "Kept", "Logs, settings, mods and versions, the Save Check"],
           [:note, "Your choice", "Trainer Name (Red): Keep"], [:note, "Your choice", "A copy of File A: Off"]]
  items.each_with_index do |(st, l, v), i|
    y = 94 + i * 46
    cursor_at(12, y - 2, W - 24, 44) if (open ? 2 : 0) == i
    tick(t, 20, y + 10, st)
    P.text(t, 46, y, 200, 20, l, c[:opt], PF::TEXT)
    P.small(t, 46, y + 21, 440, 16, v, c[:dim])
  end
  UI.rbox(b, 8, 306, 250, 348, 6, Color.new(24, 60, 40), GREEN); P.text(t, 8, 316, 242, 22, "Make Report", GREEN, PF::TEXT, 2)
  UI.rbox(b, 262, 306, W - 8, 348, 6, c[:dark], c[:line]); P.text(t, 262, 316, W - 270, 22, "Look at Every File", c[:txt], PF::TEXT, 2)
  hints(c, open ? [[:ud, "Select"], [:lr, "Keep or Hide"], [B_BTN, "Back"]] : [[:ud, "Select"], [A_BTN, "Change"], [Y_BTN, "Make Report"], [B_BTN, "Back"]])
end
pk3(c, false); dump_as("PK3_card")
pk3(c, true); dump_as("PK3_choice")

#================================================================ PK4: before and after one line; what the cleaning does, file by file
def pk4(c, fi)
  frame(c); OVER.bitmap.clear
  br_title(c)
  b = BASE.bitmap; t = TOP.bitmap
  P.small(t, 0, 40, W, 16, "#{PFILES[fi][0]}: line 2 of 214", c[:dim], 2)
  [["ON YOUR COMPUTER", 'C:\Users\Ash\Desktop\KIF Beta\Mods', RED, 60], ["IN THE REPORT", 'C:\Users\[you]\Desktop\KIF Beta\Mods', GREEN, 140]].each do |l, ln, colr, y|
    UI.rbox(b, 8, y, W - 8, y + 70, 6, c[:panel], colr)
    P.small(t, 18, y + 4, 300, 14, l, c[:head])
    P.text(t, 18, y + 26, 480, 22, ln, colr, PF::TEXT)
  end
  P.small_wrap(t, "Only the user name changes; the rest of the path stays, so the error still says where it happened.", 480).each_with_index { |ln, k| P.small(t, 18, 220 + k * 17, 480, 16, ln, c[:txt]) }
  P.small(t, 18, 260, 480, 16, "#{PFILES[fi][2]} lines in this file. 29 in the whole report.", c[:dim])
  hints(c, [[:ud, "Lines"], ["p:9", ""], ["p:10", "Files"], [B_BTN, "Back"]])
end
pk4(c, 0); dump_as("PK4_before")
pk4(c, 1); dump_as("PK4_errorlog")

#================================================================ PK5: tiles; a tile per file, A leaves one out; the tiles say what's inside
def pk5(c, out)
  frame(c); OVER.bitmap.clear
  br_title(c)
  b = BASE.bitmap; t = TOP.bitmap
  PFILES.each_with_index do |(f, what, n), i|
    x = 8 + (i % 3) * 168; y = 40 + (i / 3) * 112
    left_out = out.include?(i)
    UI.rbox(b, x, y, x + 160, y + 104, 8, left_out ? c[:dark] : col(GREEN, 24), i == 1 ? c[:selb] : (left_out ? c[:line] : GREEN))
    cursor_at(x - 2, y - 2, 164, 108) if i == 1
    P.text(t, x + 8, y + 6, 148, 20, PF.fit(PF::TEXT, f, 144), left_out ? c[:dim] : c[:white], PF::TEXT)
    P.small(t, x + 8, y + 30, 148, 16, what, c[:dim])
    P.small(t, x + 8, y + 54, 148, 16, cleaned(n), n > 0 ? GREEN : c[:dim])
    P.small(t, x + 8, y + 80, 148, 16, left_out ? "LEFT OUT" : "IN THE REPORT", left_out ? GOLD : GREEN)
  end
  UI.rbox(b, 8, 268, W - 8, H - 30, 6, c[:panel2], c[:line])
  P.text(t, 14, 270, 400, 24, out.empty? ? "Every File Included" : "1 File Left Out", out.empty? ? GREEN : GOLD, PF::ROW)
  P.small(t, 14, 298, 480, 16, out.empty? ? redact_note(c) : "KIF_errorlog.txt is left out: the crash text won't be in the report.", c[:txt])
  hints(c, [[:ud, ""], [:lr, "Select"], [A_BTN, "Leave Out"], [X_BTN, "Look Inside"], [B_BTN, "Back"]])
end
pk5(c, []); dump_as("PK5_all")
pk5(c, [1]); dump_as("PK5_out")
