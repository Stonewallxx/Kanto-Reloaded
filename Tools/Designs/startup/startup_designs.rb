# encoding: utf-8
# Mockups: the startup checks, redrawn (his ask, 2026-10-23). KIF Beta's
# version check and mod update check still run before the load screen, as
# now (C-SYS-06_Updater, F-CORE-04_Mods/ModCatalog.rb); only their look
# changes. Nothing is on screen behind them yet, so they're on black.
#
# Checking (KIF::Updater.status: also KIF's own update download)
#   Now      KIF's: a dark screen, a title, a line, a green bar.
#   Design 1 Header Plate: a popup in the Hook Check alert's look, a row
#            for each check (KIF: done; Mods: reading, with a gold bar).
#   Design 2 Bottom Bar: one angled plate along the bottom, the black
#            screen otherwise left alone.
#   Design 3 Full Screen: KIF's layout in Reloaded's look (big title, the
#            two checks as steps, a gold bar).
# KIF Update Found (Updater.check's question)
#   Now      KIF's message: Update now, What's new, Later, Skip this version.
#   Design 1 Header Plate: the versions (1.1.0 to 1.2.0), then the four
#            choices as buttons, two by two.
#   Design 2 Choice List: the versions, then the four as rows, what the
#            highlighted one does under them.
#   Design 3 Two Buttons: Update Now and Later; What's New and Skip This
#            Version on Y and X in the hints.
# Mod Updates Found (ModCatalogUI.startup_check's question)
#   Now      KIF's message: "Updates for 3 mods. Open Mods > Updates?"
#   Design 1 Header Plate: each mod and its versions (old to new), then
#            Open Updates and Later.
#   Design 2 Update All: the same list, and Update All (KIF's own
#            installer, from the popup) beside Open Updates and Later.
#   Design 3 Count: how many, their names on one line, Open Updates and
#            Later.
# Usage (from this folder): ruby startup_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                           python <KR>/Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
load File.join(File.dirname(File.expand_path(__FILE__)), "..", "pokevial", "pokevial_common.rb")

QA_MAP.visible = false        # nothing behind the checks yet
BLACK = Color.new(0, 0, 0)
KIF_NOW = Color.new(16, 16, 24)
MODS = [["Kanto Reloaded", "2.0.0", "2.0.1"], ["Multiplayer", "1.4.2", "1.5.0"], ["EBDX", "1.3.0", "1.3.1"]].freeze

def black_shot(name, mode, hints = nil)
  S.set(:"interface.theme_mode", mode)
  $qa_hints = nil
  om.refresh
  o = om.send(:overlay)
  hidden = om.send(:sprites).reject { |s| s.bitmap.equal?(o) }
  hidden.each { |s| s.visible = false }
  o.clear
  o.fill_rect(0, 0, SW, SH, BLACK)
  c = om.send(:palette)
  yield(o, c)
  P2.hints(o, o, c, hints, :xbox) if hints
  dump(name)
  hidden.each { |s| s.visible = true }
end

def tone(c, key, dark_rgb)
  return c[key] if c[:light]
  return Color.new(*dark_rgb)
end
def green(c); tone(c, :green, [120, 230, 150]); end
def gold(c); tone(c, :gold, [240, 200, 80]); end

# KIF's own message window and choice box, as PIF draws them (a stand-in)
def pif_message(o, text, choices)
  white = Color.new(248, 248, 248); ink = Color.new(80, 80, 88); edge = Color.new(96, 112, 136)
  P2.ui.rbox(o, 12, SH - 92, SW - 12, SH - 12, 8, white, edge)
  P2.text(o, 30, SH - 80, SW - 60, 22, text, ink, PF::TEXT)
  return unless choices
  w = choices.map { |t| P2.width(PF::TEXT, t) }.max + 48
  h = choices.length * 26 + 18
  x = SW - 12 - w; y = SH - 100 - h
  P2.ui.rbox(o, x, y, x + w, y + h, 8, white, edge)
  choices.each_with_index do |t, i|
    P2.ui.tri(o, x + 14, y + 16 + i * 26, :r, ink, 4) if i == 0
    P2.text(o, x + 28, y + 8 + i * 26, w - 34, 22, t, ink, PF::TEXT)
  end
end

def bar(o, c, x, y, w, frac, h = 6)
  P2.ui.rbox(o, x, y, x + w, y + h, h / 2, c[:dark], c[:line])
  P2.ui.rbox(o, x + 1, y + 1, x + 1 + ((w - 2) * frac).to_i, y + h - 1, (h - 2) / 2, gold(c))
end

#================================================================ Checking
def a0(o, _c)
  o.fill_rect(0, 0, SW, SH, KIF_NOW)
  mid = SH / 2
  P2.text(o, 0, mid - 70, SW, 32, "Reading the mod list", Color.new(248, 248, 248), PF::ROW, 2)
  P2.text(o, 0, mid - 28, SW, 28, "KIF-Mods: 3 of 12", Color.new(248, 248, 248), PF::TEXT, 2)
  w = SW - 96
  o.fill_rect(48, mid + 10, w, 14, Color.new(56, 56, 72))
  o.fill_rect(48, mid + 10, w / 4, 14, Color.new(96, 200, 120))
end

# one check's row: its name, then a pill (done) or what it's on and a bar
def check_row(o, c, x, y, w, name, state, line = nil, frac = nil)
  P2.text(o, x, y, 120, 22, name, c[:txt], PF::TEXT)
  case state
  when :done
    P2.pill(o, x + w, y + 3, line, c[:light] ? Reloaded::Palette.mix(c[:panel2], c[:green], 0.22) : Color.new(24, 60, 36), green(c), true)
  when :busy
    P2.small(o, x, y, w, 20, line, c[:dim], 1)
    bar(o, c, x, y + 26, w, frac)
  when :wait
    P2.small(o, x, y, w, 20, "Waiting", c[:dim], 1)
  end
end

def a1(o, c)
  w = 320; h = 150
  x = (SW - w) / 2; y = (SH - h) / 2 - 10
  popup(o, c, x, y, w, h, "Checking for Updates", false)
  check_row(o, c, x + 24, y + 46, w - 48, "KIF", :done, "1.1.0 IS THE NEWEST")
  o.fill_rect(x + 12, y + 74, w - 24, 1, c[:line])
  check_row(o, c, x + 24, y + 82, w - 48, "Mods", :busy, "KIF-Mods: 3 of 12", 0.25)
  P2.small(o, x, y + h - 26, w, 16, "Mods are checked every 12 hours.", c[:dim], 2)
end

def a2(o, c)
  y0 = SH - 58; y1 = SH - 14
  PP.chamfer_grad(o, 14, y0, SW - 14, y1, 10, mix(c[:panel], c[:selb], 0.22), c[:panel], c[:line])
  P2.text(o, 30, y0 + 6, 260, 20, "Checking for Mod Updates", c[:txt], PF::TEXT)
  P2.small(o, 30, y0 + 6, SW - 60, 20, "KIF-Mods: 3 of 12", c[:dim], 1)
  bar(o, c, 30, y0 + 30, SW - 60, 0.25, 6)
  P2.small(o, 0, 12, SW - 16, 16, "KIF 1.1.0 Is the Newest", c[:dim], 1)
end

def a3(o, c)
  o.fill_rect(0, 0, SW, SH, c[:bg] || c[:panel])
  P2.text(o, 0, 96, SW, 30, "Checking for Updates", c[:title] || c[:head], PF::TITLE, 2)
  steps = [["KIF", :done], ["Mods", :busy]]
  sx = SW / 2 - 92
  steps.each_with_index do |(label, st), i|
    bx = sx + i * 104
    fill = st == :done ? (c[:light] ? Reloaded::Palette.mix(c[:panel2], c[:green], 0.25) : Color.new(24, 60, 36)) : c[:panel2]
    edge = st == :done ? green(c) : gold(c)
    PP.chamfer(o, bx, 150, bx + 80, 176, 7, fill, edge)
    P2.text(o, bx, 152, 80, 22, label, st == :done ? green(c) : gold(c), PF::TEXT, 2)
  end
  o.fill_rect(sx + 80, 163, 24, 1, c[:line])
  P2.text(o, 0, 200, SW, 22, "KIF-Mods: 3 of 12", c[:txt], PF::TEXT, 2)
  bar(o, c, 96, 232, SW - 192, 0.25, 10)
  P2.small(o, 0, 252, SW, 16, "25%", c[:dim], 2)
end

#================================================================ KIF Update Found
KIF_CHOICES = ["Update Now", "What's New", "Later", "Skip This Version"].freeze

def b0(o, _c)
  pif_message(o, "KIF 1.2.0 is out (you have 1.1.0).", ["Update now", "What's new", "Later", "Skip this version"])
end

def versions(o, c, x, y, w)
  P2.text(o, x, y, w / 2 - 20, 26, "1.1.0", c[:dim], PF::ROW, 1)
  P2.ui.tri(o, x + w / 2 - 4, y + 9, :r, c[:dim], 5)
  P2.text(o, x + w / 2 + 14, y, w / 2 - 14, 26, "1.2.0", green(c), PF::ROW, 0)
  P2.small(o, x, y + 26, w / 2 - 20, 14, "YOU HAVE", c[:dim], 1)
  P2.small(o, x + w / 2 + 14, y + 26, w / 2, 14, "NEW", c[:dim], 0)
end

def b1(o, c)
  w = 340; h = 192
  x = (SW - w) / 2; y = (SH - h) / 2 - 14
  popup(o, c, x, y, w, h, "KIF Update", false)
  P2.small(o, x, y + 38, w, 16, "A new KIF is out.", c[:dim], 2)
  versions(o, c, x, y + 58, w)
  o.fill_rect(x + 12, y + 104, w - 24, 1, c[:line])
  bw = 146
  KIF_CHOICES.each_with_index do |label, i|
    bx = x + 18 + (i % 2) * (bw + 12); by = y + 114 + (i / 2) * 34
    button(o, c, bx, by, bx + bw, by + 28, label, i == 0)
  end
end

def b2(o, c)
  w = 320; rh = 26
  descs = ["Downloads it now, then restarts the game.", "What changed in 1.2.0.", "Asks again next time.",
           "Won't ask about 1.2.0 again. Options > System > Check for Updates still finds it."]
  h = 112 + KIF_CHOICES.length * rh + 40
  x = (SW - w) / 2; y = (SH - h) / 2 - 10
  popup(o, c, x, y, w, h, "KIF Update", false)
  versions(o, c, x, y + 42, w)
  KIF_CHOICES.each_with_index do |label, i|
    ry = y + 92 + i * rh
    cursor(o, c, x + 10, ry, x + w - 10, ry + rh - 2) if i == 0
    P2.text(o, x + 24, ry + 2, w - 48, 22, label, i == 0 ? c[:strong] : c[:txt], PF::TEXT)
  end
  o.fill_rect(x + 12, y + h - 46, w - 24, 1, c[:line])
  P2.small(o, x + 16, y + h - 40, w - 32, 16, descs[0], c[:dim])
end

def b3(o, c)
  w = 300; h = 150
  x = (SW - w) / 2; y = (SH - h) / 2 - 20
  popup(o, c, x, y, w, h, "KIF Update", false)
  P2.small(o, x, y + 38, w, 16, "A new KIF is out.", c[:dim], 2)
  versions(o, c, x, y + 58, w)
  button(o, c, x + 20, y + h - 40, x + w / 2 - 6, y + h - 12, "Update Now", true)
  button(o, c, x + w / 2 + 6, y + h - 40, x + w - 20, y + h - 12, "Later", false)
end
B3_HINTS = [[:lr, "Choose"], [A_PAD, "Select"], [Y_PAD, "What's New"], [X_PAD, "Skip This Version"]].freeze

#================================================================ Mod Updates Found
def c0(o, _c)
  pif_message(o, "Updates for 3 mods. Open Mods > Updates?", ["Yes", "Later"])
end

def mod_rows(o, c, x, y, w, rh = 26)
  MODS.each_with_index do |(name, from, to), i|
    ry = y + i * rh
    P2.text(o, x, ry, w - 120, 22, name, c[:txt], PF::TEXT)
    tw = P2.width(PF::TEXT, to)
    P2.text(o, x + w - tw, ry, tw + 2, 22, to, green(c), PF::TEXT)
    P2.ui.tri(o, x + w - tw - 14, ry + 7, :r, c[:dim], 4)
    fw = P2.width(PF::TEXT, from)
    P2.text(o, x + w - tw - 22 - fw, ry, fw + 2, 22, from, c[:dim], PF::TEXT)
  end
end

def c1(o, c)
  w = 340; h = 40 + 20 + MODS.length * 26 + 56
  x = (SW - w) / 2; y = (SH - h) / 2 - 14
  popup(o, c, x, y, w, h, "Mod Updates", false)
  P2.small(o, x, y + 38, w, 16, "3 of your mods have updates.", c[:dim], 2)
  mod_rows(o, c, x + 24, y + 60, w - 48)
  o.fill_rect(x + 12, y + h - 50, w - 24, 1, c[:line])
  button(o, c, x + 20, y + h - 40, x + w / 2 - 6, y + h - 12, "Open Updates", true)
  button(o, c, x + w / 2 + 6, y + h - 40, x + w - 20, y + h - 12, "Later", false)
end

def c2(o, c)
  w = 420; h = 40 + 20 + MODS.length * 26 + 76
  x = (SW - w) / 2; y = (SH - h) / 2 - 14
  popup(o, c, x, y, w, h, "Mod Updates", false)
  P2.small(o, x, y + 38, w, 16, "3 of your mods have updates.", c[:dim], 2)
  mod_rows(o, c, x + 24, y + 60, w - 48)
  o.fill_rect(x + 12, y + h - 70, w - 24, 1, c[:line])
  bw = (w - 40 - 16) / 3
  ["Update All", "Open Updates", "Later"].each_with_index do |label, i|
    bx = x + 20 + i * (bw + 8)
    button(o, c, bx, y + h - 60, bx + bw, y + h - 32, label, i == 0)
  end
  P2.small(o, x, y + h - 26, w, 16, "Updated mods work from the next start.", c[:dim], 2)
end

def c3(o, c)
  w = 320; h = 164
  x = (SW - w) / 2; y = (SH - h) / 2 - 20
  popup(o, c, x, y, w, h, "Mod Updates", false)
  P2.text(o, x, y + 40, w, 30, "3", gold(c), PF::TITLE, 2)
  P2.small(o, x, y + 72, w, 16, "Mods with updates:", c[:dim], 2)
  P2.small(o, x + 12, y + 90, w - 24, 16, MODS.map(&:first).join(", "), c[:txt], 2)
  button(o, c, x + 20, y + h - 40, x + w / 2 - 6, y + h - 12, "Open Updates", true)
  button(o, c, x + w / 2 + 6, y + h - 40, x + w - 20, y + h - 12, "Later", false)
end

POP_HINTS = [[:lr, "Choose"], [A_PAD, "Select"], [B_PAD, "Later"]].freeze
SHOTS = [["ST_A0_now", :a0, nil], ["ST_A1_plate", :a1, nil], ["ST_A2_bar", :a2, nil], ["ST_A3_full", :a3, nil],
         ["ST_B0_now", :b0, nil], ["ST_B1_plate", :b1, POP_HINTS], ["ST_B2_list", :b2, [[:ud, "Choose"], [A_PAD, "Select"], [B_PAD, "Later"]]],
         ["ST_B3_two", :b3, B3_HINTS],
         ["ST_C0_now", :c0, nil], ["ST_C1_plate", :c1, POP_HINTS], ["ST_C2_all", :c2, POP_HINTS], ["ST_C3_count", :c3, POP_HINTS]].freeze

queue = []
SHOTS.each do |name, what, hints|
  queue << at { black_shot(name, 0, hints) { |o, c| send(what, o, c) } }
  queue << at { black_shot("#{name}_light", 2, hints) { |o, c| send(what, o, c) } } unless name.end_with?("now")
end
queue << at { S.set(:"interface.theme_mode", 0); om.send(:overlay).clear; om.refresh }
queue << I::BACK
on_map("Startup check designs", queue)
puts "designs done"
