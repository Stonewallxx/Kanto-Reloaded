# encoding: utf-8
# Mockups: Hook Checker (topic 34), output 3: In-Game Results. Only in
# Stonewall's copy (never shipped): the same run as the report (KIF Beta
# 0.21.52 to 0.21.60), opened from the Update Alert's Open Results.
# Each design is a pair: a broken hook (left), a hook whose method changed
# upstream, with the diff (right).
# Design 1 = the Settings layout, like the Patch Viewer.
# Usage (from this folder): ruby hr_designs.rb "<KIF Beta>" <work dir with metrics.json>
TSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "tp_designs.rb"), :encoding => "UTF-8")
eval(TSRC.split("c = palette(2)\n")[0], binding, "tp_designs.rb")

PURP = Color.new(170, 130, 230)
SECS = [["Broken", RED2], ["Changed", AMB], ["Shared", BLUE2], ["Takeovers", PURP], ["OK", GREEN]]
HEADS_ = { 0 => "Broken", 1 => "Changed Upstream", 2 => "Shared Methods", 3 => "Takeovers and Settings", 4 => "OK" }
HOOKS_BY = {
  0 => [["autosave_rows", "KIF::SettingsScreen.pif_items"]],
  1 => [["kif_bridge_desc", "KIF::SettingsScreen.description_for"], ["controls_splits_desc", "KIF::SettingsScreen.description_for"], ["controls_extra_actions", "Scene_Map#update"]],
  2 => [["controls_extra_actions", "Scene_Map#update"], ["controls_splits", "Input.trigger?"], ["global_small_text", "Object#pbSetSmallFont"]],
  3 => [["F-UI-05_SpeedUp", "Takes Over"], ["cody_battleinfo", "Lock"], ["qol_autosave", "Setting"]]
}
DIFF = [["-", "return entry[:desc] || \"\""], ["+", "text = entry[:desc] || \"\""], ["+", "text = KIF::Locks.note(entry, text) if entry[:locked]"], ["+", "return text"]]
D_BROKEN = ["autosave_rows", "KIF::SettingsScreen.pif_items is gone in 0.21.60; KIF has pif_rows instead (same arguments). Autosave's rows don't show. Core/Settings/AutosaveRows.rb:32", ["BROKEN", "CORE HOOK"]]
def res_frame(c, title = "Hook Check")
  page_frame(c, title)
  b = BASE.bitmap; t = TOP.bitmap
  P.small(t, 8, 9, 150, 16, "KIF Beta 0.21.60", c[:dim])
  UI.rbox(b, W - 120, 4, W - 8, 27, 5, c[:dark], c[:line]); P.text(t, W - 120, 4, 112, 23, "Run Again", c[:dim], PF::TEXT, 2)
end
def secs_side(c, sel)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 6, 36, 174, 262, 6, c[:panel])
  SECS.each_with_index do |(l, colr), i|
    y = 40 + i * 22
    UI.rbox(t, 14, y + 3, 28, y + 17, 3, colr); P.glyph(t, 14, y + 3, 15, 15, l[0], Color.new(20, 24, 30))
    P.text(t, 33, y + 2, 128, 18, l, i == sel ? c[:white] : c[:dim])
  end
end
def hook_rows(c, sec, sel, x0 = 184, x1 = W - 10, y0 = 56)
  t = TOP.bitmap
  (HOOKS_BY[sec] || []).each_with_index do |(id, target), i|
    y = y0 + i * 38
    cursor_at(x0, y, x1 - x0, 36) if i == sel
    P.text(t, x0 + 12, y, x1 - x0 - 20, 20, id, c[:opt], PF::TEXT)
    P.small(t, x0 + 12, y + 19, x1 - x0 - 20, 14, target, c[:dim])
  end
end
def diff_lines(t, c, x, y, w, lines, step = 16)
  lines.each_with_index do |(sign, code), i|
    colr = sign == "+" ? GREEN : (sign == "-" ? RED2 : c[:txt])
    P.small(t, x, y + i * step, 12, 14, sign, colr)
    P.small(t, x + 12, y + i * step, w - 12, 14, code, colr)
  end
end
def diff_box(c, title, pills, lines)
  t = TOP.bitmap
  P.text(t, 14, 269, 330, 26, title, c[:head], PF::ROW)
  x = W - 14
  pills.each { |p| x -= P.pill(t, x, 276, p, c[:pill], c[:txt]) + 6 }
  diff_lines(t, c, 14, 296, W - 30, lines)
end

c = palette(2)

#================================================================ HR1 Recommended: the Settings layout; results as sections, hooks as rows, the description box explains (or shows the diff)
def hr1(c, sec, sel)
  res_frame(c); secs_side(c, sec); boxes(c)
  P.heading(TOP.bitmap, 190, W - 16, 43, HEADS_[sec], c[:head], c[:line])
  hook_rows(c, sec, sel)
end
hr1(c, 0, 0); desc_box(c, *D_BROKEN)
hints(c, [[:ud, "Select"], [A_BTN, "Open Report"], [Y_BTN, "Run Again"], [B_BTN, "Sections"]]); dump_as("HR1_broken")
hr1(c, 1, 0); diff_box(c, "description_for (+3 -1)", ["CHANGED"], DIFF.first(3))
hints(c, [[:ud, "Select"], [A_BTN, "Full Diff"], [Y_BTN, "Run Again"], [B_BTN, "Sections"]]); dump_as("HR1_changed")

#================================================================ HR2: one list of every problem on the left, the detail on the right
ALL = [["autosave_rows", "Broken", RED2], ["qol_autosave", "Missing", RED2], ["kif_bridge_desc", "Changed", AMB], ["controls_splits_desc", "Changed", AMB],
       ["controls_extra_actions", "Changed", AMB], ["controls_splits", "Shared", BLUE2], ["global_small_text", "Shared", BLUE2]]
def kv(t, c, y, pairs)
  pairs.each do |k, lines|
    P.small(t, 266, y, 230, 14, k.upcase, c[:dim]); y += 14
    lines.each { |ln| P.small(t, 266, y, 236, 16, ln, c[:txt]); y += 15 }
    y += 4
  end
end
def hr2(c, sel)
  res_frame(c)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 6, 36, 250, H - 30, 6, c[:panel])
  ALL.each_with_index do |(id, res, colr), i|
    y = 42 + i * 28
    cursor_at(9, y, 238, 26) if i == sel
    UI.rbox(t, 16, y + 9, 22, y + 15, 3, colr)
    P.text(t, 28, y + 2, 150, 22, PF.fit(PF::TEXT, id, 150), c[:opt], PF::TEXT)
    P.small(t, 180, y + 5, 62, 16, res, colr, 2)
  end
  UI.rbox(b, 256, 36, W - 6, H - 30, 6, c[:panel2], c[:line])
  id, res, colr = ALL[sel]
  P.text(t, 266, 40, 230, 24, id, c[:head], PF::ROW)
  P.pill(t, W - 14, 46, res.upcase, Color.new(colr.red / 4, colr.green / 4, colr.blue / 4), colr)
  if res == "Broken"
    kv(t, c, 70, [["Target", ["KIF::SettingsScreen", ".pif_items"]], ["File", ["Core/Settings/", "AutosaveRows.rb:32"]], ["Feature", ["Core hook"]]])
    b.fill_rect(266, 204, 230, 1, c[:line])
    P.small_wrap(t, "Gone in 0.21.60. KIF has pif_rows instead, with the same arguments. Autosave's rows don't show in KIF Settings.", 230).each_with_index { |ln, k| P.small(t, 266, 210 + k * 17, 236, 16, ln, c[:txt]) }
  else
    kv(t, c, 70, [["Target", ["KIF::SettingsScreen", ".description_for"]], ["File", ["Core/Settings/KIFBridge.rb:87"]]])
    b.fill_rect(266, 158, 230, 1, c[:line])
    P.small(t, 266, 162, 230, 14, "WHAT CHANGED (+3 -1)", c[:dim])
    diff_lines(t, c, 266, 180, 236, [["-", "return entry[:desc] || \"\""], ["+", "text = entry[:desc] || \"\""], ["+", "text = KIF::Locks.note(entry,"], ["", "  text) if entry[:locked]"], ["+", "return text"]], 17)
    P.small_wrap(t, "Locked rows may show the lock note twice.", 230).each_with_index { |ln, k| P.small(t, 266, 274 + k * 17, 236, 16, ln, GOLD) }
  end
  hints(c, [[:ud, "Select"], [A_BTN, "Open Report"], [Y_BTN, "Run Again"], [B_BTN, "Back"]])
end
hr2(c, 0); dump_as("HR2_broken")
hr2(c, 2); dump_as("HR2_changed")

#================================================================ HR3: a full-screen before and after; LB and RB go through the problems
def hr3(c, broken)
  res_frame(c)
  b = BASE.bitmap; t = TOP.bitmap
  colr = broken ? RED2 : AMB
  UI.rbox(b, 6, 36, W - 6, 74, 6, c[:panel2], colr)
  P.text(t, 16, 38, 330, 22, broken ? "autosave_rows" : "kif_bridge_desc", c[:white], PF::TEXT)
  P.small(t, 16, 56, 330, 16, broken ? "KIF::SettingsScreen.pif_items" : "KIF::SettingsScreen.description_for", c[:dim])
  P.pill(t, W - 16, 46, broken ? "BROKEN" : "CHANGED", Color.new(colr.red / 4, colr.green / 4, colr.blue / 4), colr)
  P.small(t, W - 190, 46, 80, 14, broken ? "1 of 4" : "2 of 4", c[:dim], 2)
  [[6, "0.21.52 (WHEN HOOKED)"], [260, "0.21.60 (NOW)"]].each do |x, l|
    UI.rbox(b, x, 80, x + 246, 312, 6, c[:panel], c[:line])
    P.small(t, x + 10, 84, 226, 14, l, c[:dim])
  end
  if broken
    diff_lines(t, c, 16, 104, 236, [["", "def pif_items(page)"], ["", "  rows = PIF_PAGES[page]"], ["", "  rows.map { |r| item(r) }"], ["", "end"]], 18)
    P.text(t, 270, 104, 226, 22, "Not Found", RED2, PF::TEXT)
    P.small_wrap(t, "Closest match: pif_rows(page), same arguments, same file (016_KIF_SettingsScreen.rb).", 226).each_with_index { |ln, k| P.small(t, 270, 130 + k * 17, 230, 16, ln, c[:txt]) }
  else
    diff_lines(t, c, 16, 104, 236, [["", "def description_for(entry)"], ["-", "  return entry[:desc] || \"\""], ["", "end"]], 18)
    diff_lines(t, c, 270, 104, 232, [["", "def description_for(entry)"], ["+", "  text = entry[:desc] || \"\""], ["+", "  text = KIF::Locks.note("], ["+", "    entry, text)"], ["+", "    if entry[:locked]"], ["+", "  return text"], ["", "end"]], 18)
  end
  hints(c, [["p:9", ""], ["p:10", "Problems"], [A_BTN, "Open Report"], [B_BTN, "Back"]])
end
hr3(c, true); dump_as("HR3_broken")
hr3(c, false); dump_as("HR3_changed")

#================================================================ HR4: by KR file; each file a section, its hooks with their results
FILES_ = [["AutosaveRows.rb", RED2], ["KIFBridge.rb", AMB], ["Splits.rb", AMB], ["ExtraActions.rb", AMB], ["mod.json", RED2], ["7 More Files", GREEN]]
FHOOKS = { 0 => [["autosave_rows", "Broken", RED2]], 1 => [["kif_bridge_desc", "Changed", AMB], ["kif_bridge_rebuild", "OK", GREEN], ["kif_bridge_choice", "OK", GREEN], ["kif_bridge_defaults", "OK", GREEN]] }
def hr4(c, fi, sel)
  res_frame(c)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 6, 36, 174, 262, 6, c[:panel])
  FILES_.each_with_index do |(l, colr), i|
    y = 40 + i * 22
    UI.rbox(t, 14, y + 7, 20, y + 13, 3, colr)
    P.text(t, 26, y + 2, 140, 18, l, i == fi ? c[:white] : c[:dim])
  end
  boxes(c)
  P.heading(t, 190, W - 16, 43, "Core/" + (fi == 0 ? "Settings/AutosaveRows.rb" : "Settings/KIFBridge.rb"), c[:head], c[:line])
  FHOOKS[fi].each_with_index do |(id, res, colr), i|
    y = 58 + i * 25
    cursor_at(184, y, W - 194, 24) if i == sel
    P.text(t, 196, y, 220, 24, id, c[:opt], PF::TEXT)
    P.text(t, 400, y, 92, 24, res, colr, PF::TEXT, 1)
  end
end
hr4(c, 0, 0); desc_box(c, *D_BROKEN)
hints(c, [[:ud, "Select"], [A_BTN, "Open Report"], [B_BTN, "Files"]]); dump_as("HR4_broken")
hr4(c, 1, 0); diff_box(c, "kif_bridge_desc (+3 -1)", ["CHANGED"], DIFF.first(3))
hints(c, [[:ud, "Select"], [A_BTN, "Full Diff"], [B_BTN, "Files"]]); dump_as("HR4_changed")

#================================================================ HR5: a checklist; A ticks a problem off as fixed, Y runs the check again
TODO = [["Hook pif_rows in autosave_rows", "Must Fix", RED2], ["Find qol_autosave's new name", "Must Fix", RED2], ["Lock note twice in description_for?", "Check", AMB],
        ["Play steps with extra actions bound", "Check", AMB]]
def hr5(c, done, sel)
  res_frame(c)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 6, 36, W - 6, 262, 6, c[:panel])
  P.heading(t, 16, W - 16, 43, "To Do (#{done.length} of #{TODO.length} Done)", c[:head], c[:line])
  TODO.each_with_index do |(l, kind, colr), i|
    y = 58 + i * 30
    cursor_at(10, y, W - 20, 28) if i == sel
    on = done.include?(i)
    UI.rbox(t, 20, y + 6, 36, y + 22, 3, on ? GREEN : c[:dark], on ? GREEN : c[:dim])
    if on
      t.fill_rect(24, y + 13, 3, 3, Color.new(20, 40, 24)); t.fill_rect(27, y + 15, 3, 3, Color.new(20, 40, 24)); t.fill_rect(30, y + 10, 3, 6, Color.new(20, 40, 24))
    end
    P.text(t, 46, y + 2, 340, 24, l, on ? c[:dim] : c[:opt], PF::TEXT)
    P.small(t, 400, y + 6, 96, 16, on ? "Fixed" : kind, on ? GREEN : colr, 2)
  end
end
hr5(c, [], 0); desc_box(c, *D_BROKEN)
hints(c, [[:ud, "Select"], [A_BTN, "Tick"], [Y_BTN, "Run Again"], [B_BTN, "Back"]]); dump_as("HR5_broken")
hr5(c, [0, 1], 2); diff_box(c, "description_for (+3 -1)", ["CHECK"], DIFF.first(3))
hints(c, [[:ud, "Select"], [A_BTN, "Tick"], [Y_BTN, "Run Again"], [B_BTN, "Back"]]); dump_as("HR5_changed")
