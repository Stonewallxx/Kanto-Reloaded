# encoding: utf-8
# Mockups: Timing Profiler (topic 33), screen 3: Profiler Settings (ModDev
# only). Turn the profiler on, pick what it times (Battles, Map Loads, Menus,
# Saving, Mod Timings), the slow-frame line, how many sessions to keep, the
# text report (old KR's TimingProfile.txt) and a way into the Report Viewer.
# Design 1 = a Developer section in Reloaded Settings (old KR and HR put the
# switch in their settings), in the improved Settings layout.
# Usage (from this folder): ruby ps_designs.rb "<KIF Beta>" <work dir with metrics.json>
TSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "tp_designs.rb"), :encoding => "UTF-8")
eval(TSRC.split("tp1(c, :battle, 0, 0); dump_as")[0], binding, "tp_designs.rb")

RSEC = [["Kanto Reloaded", [214, 52, 60]], ["Shinies", [230, 180, 60]], ["Battles", [210, 80, 80]], ["Pokémon", [90, 170, 100]],
        ["Graphics", [96, 160, 232]], ["Game", [60, 170, 160]], ["System", [130, 140, 155]], ["Developer", [160, 110, 200]]]
AREAS = [["Battles", "On"], ["Map Loads", "On"], ["Menus", "On"], ["Saving", "On"], ["Mod Timings", "On"]]
D_ON = ["Timing Profiler", "Times what you pick below while you play and keeps each session for the Report Viewer. Shown only with DEBUG on (Settings, Advanced).", ["DEBUG", "DEFAULT: OFF"]]
D_SLOW = ["Slow Frame", "A frame counts as slow above this: 33.3 ms is two frames at 60, 16.7 ms is one.", ["DEFAULT: 33.3 MS"]]
def set_frame(c, title = "Settings")
  frame(c); OVER.bitmap.clear; MAPS.bitmap = Bitmap.new(W, H)
  settings_frame(c, RSEC, 7)
  t = TOP.bitmap
  t.fill_rect(130, 2, 252, 28, Color.new(0, 0, 0, 0)); P.text(t, 130, 2, 252, 28, title, c[:title], PF::TITLE, 2)
end
def open_pill(t, c, y, label = "OPEN"); P.pill(t, W - 18, y + 5, label, c[:pill], c[:txt]); end
# items: [:head, l] | [:row, l, v] | [:link, l, pill]
def set_rows(c, items, sel, y0 = 40, step = 24, scroll = nil)
  t = TOP.bitmap; b = BASE.bitmap
  y = y0
  ri = -1
  avail_end = 258
  if scroll
    b.fill_rect(W - 11, 42, 2, 214, c[:line])
    b.fill_rect(W - 11, 42 + scroll * 120, 2, 94, c[:dim])
  end
  items.each do |it|
    if it[0] == :head
      break if y + 18 + step - 2 > avail_end
      P.heading(t, 190, W - 16, y + 3, it[1], c[:head], c[:line]); y += 18
      next
    end
    ri += 1
    break if y + step - 2 > avail_end
    cursor_at(184, y, W - 194, step - 1) if ri == sel
    P.text(t, 196, y, 210, step - 1, it[1], c[:opt], PF::TEXT)
    it[0] == :link ? open_pill(t, c, y, it[2]) : value_cell(t, c, W - 66, y, it[2], ri == sel)
    y += step
  end
end

c = palette(2)

#================================================================ PS1 Recommended: a Developer section in Reloaded Settings
PS1 = [[:head, "Timing Profiler"], [:row, "Timing Profiler", "On"], [:link, "Report Viewer", "OPEN"],
       [:head, "Time"]] + AREAS.map { |l, v| [:row, l, v] } +
      [[:head, "Report"], [:row, "Slow Frame", "33.3 ms"], [:row, "Keep Sessions", "25"], [:row, "Text Report", "On"]]
set_frame(c); set_rows(c, PS1, 0, 40, 24, 0)
desc_box(c, *D_ON); hints(c, [[:ud, "Select"], [:lr, "Change"], [X_BTN, "Default"], [B_BTN, "Sections"]]); dump_as("PS1_on")
set_frame(c); set_rows(c, PS1[3..-1], 5, 40, 24, 1)
desc_box(c, *D_SLOW); hints(c, [[:ud, "Select"], [:lr, "Change"], [X_BTN, "Default"], [B_BTN, "Sections"]]); dump_as("PS1_slow")

#================================================================ PS2: a panel over the Report Viewer (its Settings button)
def ps2(c, sel, desc)
  tp1(c, :battle, 0, -1)
  d = OVER.bitmap; o = OVER.bitmap
  d.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 130))
  UI.rbox(d, 96, 34, 416, 340, 8, c[:panel2], c[:selb])
  P.text(o, 96, 38, 320, 24, "Profiler Settings", c[:title], PF::ROW, 2)
  rows = [["Timing Profiler", "On"], ["Battles", "On"], ["Map Loads", "On"], ["Menus", "On"], ["Saving", "On"], ["Mod Timings", "On"],
          ["Slow Frame", "33.3 ms"], ["Keep Sessions", "25"], ["Text Report", "On"]]
  rows.each_with_index do |(l, v), i|
    y = 66 + i * 23
    UI.rbox(d, 102, y, 410, y + 21, 4, c[:sel], c[:selb]) if i == sel
    P.text(o, 116, y, 180, 21, l, i.between?(1, 5) ? c[:txt] : c[:opt], PF::TEXT)
    vw = P.width(PF::TEXT, v)
    P.text(o, 360 - vw / 2, y, vw + 2, 21, v, v == "On" ? GREEN : c[:opt], PF::TEXT)
  end
  d.fill_rect(106, 276, 300, 1, c[:line])
  P.small_wrap(o, desc, 290).first(3).each_with_index { |ln, k| P.small(o, 112, 282 + k * 17, 292, 16, ln, c[:dim]) }
  BASE.bitmap.fill_rect(0, H - 28, W, 28, c[:bg]); TOP.bitmap.fill_rect(0, H - 28, W, 28, Color.new(0, 0, 0, 0))
  o.fill_rect(0, H - 28, W, 28, Color.new(0, 0, 0, 0))
  hints(c, [[:ud, "Select"], [:lr, "Change"], [B_BTN, "Close"]])
end
ps2(c, 0, D_ON[1]); dump_as("PS2_on")
ps2(c, 6, D_SLOW[1]); dump_as("PS2_slow")

#================================================================ PS3: what to time as five tiles; the rest as rows
def ps3(c, sel_tile, sel_row, offs)
  set_frame(c)
  b = BASE.bitmap; t = TOP.bitmap
  P.heading(t, 190, W - 16, 43, "Timing Profiler", c[:head], c[:line])
  P.text(t, 196, 56, 200, 22, "Timing Profiler", c[:opt], PF::TEXT); value_cell(t, c, W - 66, 56, "On", false)
  P.text(t, 190, 84, 200, 13, "TIME", c[:dim], PF::TINY)
  AREAS.each_with_index do |(l, _), i|
    x = 188 + i * 63; y = 98
    on = !offs.include?(i)
    UI.rbox(b, x, y, x + 58, y + 58, 6, on ? Reloaded::Palette.mix(c[:panel], GREEN, 0.18) : c[:dark], i == sel_tile ? c[:selb] : (on ? GREEN : c[:line]))
    cursor_at(x - 2, y - 2, 62, 62) if i == sel_tile
    g = { 0 => "B", 1 => "M", 2 => "U", 3 => "S", 4 => "K" }[i]
    UI.rbox(t, x + 22, y + 8, x + 36, y + 22, 3, on ? GREEN : c[:dim]); P.glyph(t, x + 22, y + 8, 15, 15, g, Color.new(20, 24, 30))
    P.small_wrap(t, l, 54).first(2).each_with_index { |ln, k| P.small(t, x + 2, y + 26 + k * 14, 54, 14, ln, on ? c[:txt] : c[:dim], 2) }
  end
  [["Slow Frame", "33.3 ms"], ["Keep Sessions", "25"], ["Text Report", "On"]].each_with_index do |(l, v), i|
    y = 166 + i * 24
    cursor_at(184, y, W - 194, 23) if i == sel_row
    P.text(t, 196, y, 200, 23, l, c[:opt], PF::TEXT); value_cell(t, c, W - 66, y, v, i == sel_row)
  end
end
ps3(c, 1, -1, [])
desc_box(c, "Map Loads", "Times each map change: loading the map and the ones next to it, building the tiles, setting up events, fusion sprites and music.", ["ON"])
hints(c, [[:ud, ""], [:lr, "Select"], [A_BTN, "Toggle"], [B_BTN, "Sections"]]); dump_as("PS3_tiles")
ps3(c, -1, 0, [2, 3])
desc_box(c, *D_SLOW); hints(c, [[:ud, "Select"], [:lr, "Change"], [X_BTN, "Default"], [B_BTN, "Sections"]]); dump_as("PS3_slow")

#================================================================ PS4: one Profile row with presets; Custom shows the rows
PROFILES = ["Off", "Battles Only", "Everything", "Mods Only", "Custom"]
def ps4(c, profile, sel)
  set_frame(c)
  t = TOP.bitmap
  P.heading(t, 190, W - 16, 43, "Timing Profiler", c[:head], c[:line])
  y = 56
  cursor_at(184, y, W - 194, 23) if sel == 0
  P.text(t, 196, y, 200, 23, "Profile", c[:opt], PF::TEXT); value_cell(t, c, W - 76, y, PROFILES[profile], sel == 0)
  y += 24
  if profile == 4
    (AREAS.map { |l, v| [l, l == "Menus" || l == "Saving" ? "Off" : v] } + [["Slow Frame", "33.3 ms"]]).each_with_index do |(l, v), i|
      cursor_at(184, y, W - 194, 23) if sel == i + 1
      P.text(t, 208, y, 200, 23, l, c[:opt], PF::TEXT); value_cell(t, c, W - 66, y, v, sel == i + 1)
      y += 24
    end
  else
    on = { 1 => "battles", 2 => "everything, mods included", 3 => "mods" }[profile]
    P.small(t, 208, y + 2, 290, 16, "Times #{on}.", c[:dim])
    y += 24
  end
  P.heading(t, 190, W - 16, y + 3, "Report", c[:head], c[:line]); y += 18
  P.text(t, 196, y, 200, 23, "Report Viewer", c[:opt], PF::TEXT); open_pill(t, c, y)
end
ps4(c, 2, 0)
desc_box(c, "Profile: Everything", "Times battles, map loads, menus, saving and every mod. Battles Only is old KR's profiler; Custom picks each one.", ["DEFAULT: OFF"])
hints(c, [[:ud, "Select"], [:lr, "Change"], [B_BTN, "Sections"]]); dump_as("PS4_profile")
ps4(c, 4, 3)
desc_box(c, "Menus", "Times opening and drawing menus: Bag, Party, PC, Summary, Pokédex. Off in this custom profile.", ["CUSTOM"])
hints(c, [[:ud, "Select"], [:lr, "Change"], [B_BTN, "Sections"]]); dump_as("PS4_custom")

#================================================================ PS5: record when you choose; Start and Stop, a REC badge on screen while it runs
def ps5(c, recording)
  set_frame(c)
  b = BASE.bitmap; t = TOP.bitmap
  P.heading(t, 190, W - 16, 43, "Timing Profiler", c[:head], c[:line])
  col = recording ? RED2 : GREEN
  UI.rbox(b, 190, 56, W - 16, 104, 8, Reloaded::Palette.mix(c[:panel], col, 0.2), col)
  cursor_at(188, 54, W - 202, 52)
  UI.rbox(t, 204, 72, 218, 86, 7, col) if recording
  UI.rbox(t, 204, 72, 218, 86, 3, col) unless recording
  P.text(t, 228, 58, 200, 26, recording ? "Stop Recording" : "Start Recording", c[:white], PF::ROW)
  P.small(t, 228, 82, 260, 16, recording ? "2 min 14 s, 3 sessions so far." : "Records until you stop it.", c[:dim])
  [["Auto", "Off"], ["Time", "Everything"], ["Slow Frame", "33.3 ms"], ["Keep Sessions", "25"]].each_with_index do |(l, v), i|
    y = 114 + i * 24
    P.text(t, 196, y, 200, 23, l, c[:opt], PF::TEXT); value_cell(t, c, W - 76, y, v, false)
  end
  P.text(t, 196, 212, 200, 23, "Report Viewer", c[:opt], PF::TEXT); open_pill(t, c, 212)
  if recording
    UI.rbox(OVER.bitmap, 8, H - 25, 64, H - 5, 6, Color.new(60, 16, 16), RED2)
    UI.rbox(OVER.bitmap, 14, H - 19, 22, H - 11, 4, RED2)
    P.text(OVER.bitmap, 26, H - 23, 38, 16, "REC", RED2, PF::TINY)
  end
end
ps5(c, false)
desc_box(c, "Start Recording", "Starts timing now (what Time is set to). A REC badge shows in the corner while it records, on every screen. Each battle, map load or menu becomes a session.", ["DEBUG"])
hints(c, [[:ud, "Select"], [A_BTN, "Start"], [B_BTN, "Sections"]]); dump_as("PS5_start")
ps5(c, true)
desc_box(c, "Stop Recording", "Stops and keeps the 3 sessions so far for the Report Viewer.", ["RECORDING"])
hints(c, [[:ud, "Select"], [A_BTN, "Stop"], [B_BTN, "Sections"]]); dump_as("PS5_rec")
