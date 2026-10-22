# encoding: utf-8
# Mockup: the Reloaded Controls screen. Boots the mod through the UI
# preview's stand-ins (KIF's real pixel fonts, the mod's Palette, Pixel and
# Controls with KIF Beta's F1 bindings) and draws candidate screens.
# Usage (cwd = KIF Beta): ruby controls.rb "<KIF Beta>" <work dir with metrics.json>
PREVIEW = File.join(ARGV[0], "Mods/KantoReloaded/Tools/UIPreview/preview.rb")
src = File.read(PREVIEW, :encoding => "UTF-8")
eval(src.split("#---------------------------------------------------------------- A: Ocean Blue")[0], binding, PREVIEW)

C = Reloaded::Controls
IN = C::Inputs
P = Reloaded::Pixel
PF = KIF::PixelFont
UI = KIF::PixelUI
W = 512
H = 384

# The actions a first version would have (feature splits start on today's buttons)
[
  [:speed_up,    "Speed-Up",      :everywhere, :x,          "Speeds the game up while held, or toggles it (Speed-up type)."],
  [:speed_next,  "Next Speed",    :everywhere, :page_left,  "KIF's speed-up: the next speed."],
  [:speed_reset, "Normal Speed",  :everywhere, :page_right, "KIF's speed-up: back to normal speed."],
  [:run,         "Run",           :overworld,  :action,     "Run while held (or walk, with Default Movement on Run)."],
  [:ready_menu,  "Ready Menu",    :overworld,  :special,    "Opens the Ready Menu of registered items."],
  [:quicksave,   "Quicksave",     :overworld,  :y,          "Saves the game on the map (Quicksave with S)."],
  [:battle_info, "Battle Info",   :battle,     :action,     "Opens Battle Info from the command menu."],
  [:shift,       "Shift",         :battle,     :special,    "Shifts position in a triple battle."],
  [:default,     "Reset Setting", :menus,      :action,     "Puts the selected setting back to its default."],
  [:search,      "Search",        :menus,      :special,    "Opens search on the settings screen."]
].each_with_index do |(id, name, area, follows, desc), i|
  C.register(id, :name => name, :area => area, :follows => follows, :description => desc, :priority => 20 + i)
end
[
  [:run_toggle, "Run Toggle", :overworld, "Switches between walking and running."],
  [:bike,       "Bike",       :overworld, "Gets on or off your bike."],
  [:radar,      "Poké Radar", :overworld, "Uses the Poké Radar."],
  [:screenshot, "Screenshot", :everywhere, "Saves a screenshot (F8 still works)."]
].each_with_index do |(id, name, area, desc), i|
  C.register(id, :name => name, :area => area, :description => desc, :priority => 40 + i)
end
C.bind(:quicksave, :keys, ["k:20"])              # Q: a clash with Next Speed, to show the warning
C.bind(:run_toggle, :pad, ["hold:p:3"])          # hold Y

AREAS = [[:everywhere, "Everywhere", [96, 160, 232]], [:overworld, "Overworld", [90, 170, 100]],
         [:menus, "Menus", [130, 140, 155]], [:battle, "Battle", [210, 80, 80]]]

#---------------------------------------------------------------- button icons
BI = Reloaded::ButtonIcons
$style = :xbox
def col(rgb); Color.new(*rgb); end

def chips(b, x, x1, y, tokens, side, c, clash = [])
  shown = 0
  tokens.each do |t|
    w = BI.width(t, $style, 18)
    break if x + w > x1 && shown > 0
    BI.draw(b, x, y, t, c, $style, 18)
    b.fill_rect(x, y + 19, w, 2, c[:warn]) if clash.include?(t)
    x += w + 5
    shown += 1
  end
  if tokens.length > shown
    P.text(b, x, y, 20, 18, "...", c[:dim], PF::TINY)
  elsif tokens.empty?
    P.text(b, x, y, 80, 18, "-", c[:dim], PF::TEXT)
  end
end

#---------------------------------------------------------------- screen parts
$vp = Viewport.new(0, 0, W, H)
$vp.z = 99_999
def layer(z); s = Sprite.new($vp); s.bitmap = Bitmap.new(W, H); s.z = z; s; end
BASE = layer(0)
CUR = Sprite.new($vp); CUR.z = 1
TOP = layer(2)
OVER = layer(3)

def cursor_at(x, y, w, h)
  CUR.bitmap = P.cursor_bitmap(w, h)
  CUR.x = x
  CUR.y = y
  CUR.opacity = 200
  CUR.visible = true
end

def title_button(base, top, c, bx, label, focused = false, key = nil)
  if focused
    UI.rbox(base, bx, 4, bx + 112, 27, 5, c[:selb])
  else
    UI.rbox(base, bx, 4, bx + 112, 27, 5, c[:dark], c[:line])
  end
  fg = focused ? c[:dark] : c[:dim]
  lw = P.width(PF::TEXT, label)
  P.text(top, bx + (112 - lw) / 2, 4, lw + 2, 24, label, fg)
  BI.draw(top, bx + 118, 8, key, c, $style) if key
end

def frame(c, title)
  BASE.bitmap.clear; TOP.bitmap.clear; OVER.bitmap.clear
  CUR.visible = false
  b = BASE.bitmap
  b.fill_rect(0, 0, W, H, c[:bg])
  b.fill_rect(0, 0, W, 32, c[:panel2])
  b.fill_rect(0, 31, W, 1, c[:line])
  P.text(TOP.bitmap, 0, 2, W, 28, title, c[:title], PF::TITLE, 2)
end

def area_tabs(c, area, x0, x1, y)
  top = TOP.bitmap
  base = BASE.bitmap
  # LB / RB at the ends: the area tabs switch with them
  BI.draw(top, x0, y + 4, "p:9", c, $style)
  BI.draw(top, x1 - BI.width("p:10", $style), y + 4, "p:10", c, $style)
  bx0 = x0 + 28
  bx1 = x1 - 28
  tw = (bx1 - bx0) / AREAS.length
  UI.rbox(base, bx0 - 1, y, bx0 + tw * AREAS.length, y + 23, 5, c[:dark], c[:line])
  AREAS.each_with_index do |(id, label, rgb), k|
    tx = bx0 + k * tw
    on = id == area
    UI.rbox(base, tx + 1, y + 1, tx + tw - 1, y + 22, 4, c[:segon]) if on
    P.text(top, tx, y, tw, 24, label, on ? c[:white] : c[:dim], PF::TEXT, 2)
  end
end

KEY_X = 232
PAD_X = 376

def list_columns(c, x0, x1, y0, y1, area, sel, side, kx = KEY_X, px = PAD_X, name_x = nil)
  base = BASE.bitmap
  top = TOP.bitmap
  name_x ||= x0 + 22
  UI.rbox(base, x0, y0, x1, y1, 6, c[:panel])
  P.text(top, name_x, y0 + 3, 100, 13, "ACTION", c[:head], PF::TINY)
  P.text(top, kx, y0 + 3, 100, 13, "KEYBOARD", c[:head], PF::TINY)
  P.text(top, px, y0 + 3, 100, 13, "CONTROLLER", c[:head], PF::TINY)
  base.fill_rect(x0 + 8, y0 + 18, x1 - x0 - 16, 1, c[:line])
  rows = C.actions(area)
  y = y0 + 22
  rh = 26
  rows.each_with_index do |a, i|
    break if y + rh > y1 - 2
    clash = C.clashes(a.id).map { |_, t| t }
    if i == sel
      cursor_at(x0 + 4, y, x1 - x0 - 8, rh - 1)
      cx0 = side == :keys ? kx - 6 : px - 6
      cx1 = side == :keys ? px - 10 : x1 - 8
      UI.rbox(top, cx0, y + 1, cx1, y + rh - 3, 4, c[:selb])
      UI.rbox(top, cx0 + 1, y + 2, cx1 - 1, y + rh - 4, 3, P.ui::DARK)
      UI.rbox(top, cx0 + 1, y + 2, cx1 - 1, y + rh - 4, 3, Reloaded::Palette.mix(c[:panel], c[:sel], 0.6))
    end
    if C.customized?(a.id)
      dy = y + (rh - 2) / 2 - 3
      UI.rrect(top, name_x - 11, dy, name_x - 6, dy + 5, 3, c[:dot])
    end
    P.text(top, name_x, y, kx - name_x - 8, rh - 2, PF.fit(PF::ROW, a.name, kx - name_x - 10), c[:opt], PF::ROW)
    chips(top, kx, px - 12, y + 3, C.bindings(a.id, :keys), :keys, c, clash)
    chips(top, px, x1 - 10, y + 3, C.bindings(a.id, :pad), :pad, c, clash)
    y += rh
  end
  return rows
end

def description(c, a, extra = nil)
  base = BASE.bitmap
  top = TOP.bitmap
  y0 = 268
  UI.rbox(base, 6, y0, W - 6, H - 30, 6, c[:panel2], c[:line])
  P.text(top, 14, y0 + 1, 330, 26, a.name, c[:head], PF::ROW)
  x = W - 14
  area = AREAS.find { |id, _, _| id == a.area }[1].upcase
  x -= P.pill(top, x, y0 + 7, area, c[:pill], c[:txt]) + 6
  if a.follows && !C.customized?(a.id)
    P.pill(top, x, y0 + 7, "ON #{C.action(a.follows).name.upcase}", c[:pill], c[:txt])
  end
  lines = P.small_wrap(top, a.description, W - 30)
  lines.first(2).each_with_index { |ln, k| P.small(top, 14, y0 + 28 + k * 17, W - 34, 17, ln, c[:txt]) }
  P.small(top, 14, y0 + 28 + 2 * 17, W - 34, 17, extra, c[:warn]) if extra
end

def hints(c, pairs)
  P.hints(BASE.bitmap, TOP.bitmap, c, pairs, $style)
end

PALS = { :ocean => [2, nil], :base => [0, nil] }
def palette(theme)
  Reloaded::Settings.set(:"interface.theme", theme)
  return Reloaded::Palette.current
end

#---------------------------------------------------------------- the states
$layout_key = "k:7"
MAIN_HINTS = [[:ud, "Select"], [:lr, "Keyboard/Controller"], ["k:6", "Change"], ["k:29", "Default"], ["k:20", "Area"], ["k:27", "Back"]]
PAD_HINTS = [[:ud, "Select"], [:lr, "Keyboard/Controller"], ["p:0", "Change"], ["p:2", "Default"], ["p:9", "Area"], ["p:1", "Back"]]

# A: area tabs and a full-width list
c = palette(2)
frame(c, "Controls")
title_button(BASE.bitmap, TOP.bitmap, c, 8, "Layouts", false, $layout_key)
area_tabs(c, :everywhere, 6, W - 6, 36)
list_columns(c, 6, W - 6, 64, 264, :everywhere, 4, :keys)
description(c, C.action(:confirm))
hints(c, MAIN_HINTS)
dump("A1_tabs_everywhere")

frame(c, "Controls")
title_button(BASE.bitmap, TOP.bitmap, c, 8, "Layouts", false, $layout_key)
area_tabs(c, :overworld, 6, W - 6, 36)
list_columns(c, 6, W - 6, 64, 264, :overworld, 2, :keys)
description(c, C.action(:quicksave), "Q is also Next Speed (Everywhere): both happen on the map.")
hints(c, MAIN_HINTS)
dump("A2_tabs_overworld_clash")

frame(c, "Controls")
title_button(BASE.bitmap, TOP.bitmap, c, 8, "Layouts", false, $layout_key)
area_tabs(c, :overworld, 6, W - 6, 36)
list_columns(c, 6, W - 6, 64, 264, :overworld, 0, :pad)
description(c, C.action(:run))
hints(c, MAIN_HINTS)
dump("A3_tabs_run_controller")

# B: a sidebar of areas, like the settings screen
def sidebar(c, area, focus_side)
  base = BASE.bitmap
  top = TOP.bitmap
  UI.rbox(base, 6, 36, 124, 264, 6, c[:panel])
  y = 40
  AREAS.each do |id, label, rgb|
    on = id == area
    cursor_at(9, y - 1, 113, 20) if on && focus_side
    UI.rbox(top, 14, y + 2, 28, y + 16, 3, col(rgb))
    P.glyph(top, 14, y + 2, 15, 15, label[0], Color.new(248, 248, 248))
    P.text(top, 33, y + 2, 88, 15, label, on ? c[:white] : c[:dim])
    y += 20
  end
end
frame(c, "Controls")
title_button(BASE.bitmap, TOP.bitmap, c, 8, "Layouts", false, $layout_key)
sidebar(c, :overworld, false)
list_columns(c, 130, W - 6, 36, 264, :overworld, 0, :keys, 262, 392, 148)
description(c, C.action(:run))
hints(c, MAIN_HINTS)
dump("B1_sidebar_overworld")

# The editor for one side of one action
def editor(c, title, rows, sel, desc)
  b = OVER.bitmap
  b.clear
  b.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 120))
  w = 300
  rh = 24
  h = 40 + rows.length * rh + 8 + 44
  x = (W - w) / 2
  y = (H - h) / 2
  UI.rbox(b, x, y, x + w, y + h, 6, c[:panel2], c[:line])
  P.text(b, x, y + 6, w, 26, title, c[:title], PF::ROW, 2)
  b.fill_rect(x + 10, y + 34, w - 20, 1, c[:line])
  rows.each_with_index do |(icon, label), i|
    ry = y + 40 + i * rh
    if i == sel
      fill, border = Reloaded::Palette.cursor
      UI.rbox(b, x + 6, ry, x + w - 6, ry + rh - 2, 4, Reloaded::Palette.over(c[:panel2], fill), Reloaded::Palette.over(c[:panel2], border))
    end
    lx = x + 18
    if icon
      lx += BI.draw(b, lx, ry + 3, icon, c, $style, 18) + 8
    end
    P.text(b, lx, ry, w - (lx - x) - 12, rh - 2, label, c[:opt])
  end
  b.fill_rect(x + 10, y + h - 48, w - 20, 1, c[:line])
  P.small_wrap(b, desc, w - 28).first(2).each_with_index { |ln, i| P.small(b, x + 14, y + h - 44 + i * 18, w - 28, 18, ln, c[:dim]) }
end

frame(c, "Controls")
title_button(BASE.bitmap, TOP.bitmap, c, 8, "Layouts", false, $layout_key)
area_tabs(c, :overworld, 6, W - 6, 36)
list_columns(c, 6, W - 6, 64, 264, :overworld, 0, :keys)
description(c, C.action(:run))
hints(c, [[:ud, "Select"], ["A", "Choose"], ["B", "Close"]])
editor(c, "Run: Keyboard", [["k:225", "Remove"], ["k:29", "Remove"], [nil, "Add a Key"], [nil, "Add a Hold"],
                            [nil, "Back to Default (Action)"]], 2,
       "Press a key to add it. Run can have as many keys as you like.")
dump("C1_editor_keyboard")

# Waiting for the new input
frame(c, "Controls")
title_button(BASE.bitmap, TOP.bitmap, c, 8, "Layouts", false, $layout_key)
area_tabs(c, :overworld, 6, W - 6, 36)
list_columns(c, 6, W - 6, 64, 264, :overworld, 0, :pad)
description(c, C.action(:run))
b = OVER.bitmap
b.clear
b.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 120))
w = 300; h = 130; x = (W - w) / 2; y = (H - h) / 2
UI.rbox(b, x, y, x + w, y + h, 6, c[:panel2], c[:line])
P.text(b, x, y + 6, w, 26, "Run: Controller", c[:title], PF::ROW, 2)
b.fill_rect(x + 10, y + 34, w - 20, 1, c[:line])
P.text(b, x, y + 42, w, 26, "Press a button", c[:txt], PF::ROW, 2)
P.small(b, x, y + 68, w, 18, "or move a stick. Keep holding it", c[:dim], 2)
P.small(b, x, y + 84, w, 18, "to bind it as a hold.", c[:dim], 2)
UI.rbox(b, x + 40, y + 108, x + w - 40, y + 112, 2, c[:dark])
UI.rbox(b, x + 40, y + 108, x + 40 + (w - 80) * 2 / 3, y + 112, 2, c[:selb])
hints(c, [[nil, "Waiting for a button... Nothing pressed: it closes when the bar runs out."]])
dump("C2_press_a_button")

# Layouts
frame(c, "Controls")
title_button(BASE.bitmap, TOP.bitmap, c, 8, "Layouts", false, $layout_key)
area_tabs(c, :everywhere, 6, W - 6, 36)
list_columns(c, 6, W - 6, 64, 264, :everywhere, 4, :keys)
description(c, C.action(:confirm))
hints(c, [[:ud, "Select"], ["A", "Choose"], ["B", "Close"]])
editor(c, "Layouts", [[nil, "Game's Layout (F1)"], [nil, "Pokemon-Style"], [nil, "Reset All to Default"], [nil, "Cancel"]], 1,
       "B runs, X opens the menu, Y is Speed-Up: the layout of the Pokemon games.")
dump("C3_layouts")

# A PlayStation controller
$style = :playstation
$layout_key = "p:8"
frame(c, "Controls")
title_button(BASE.bitmap, TOP.bitmap, c, 8, "Layouts", false, $layout_key)
area_tabs(c, :overworld, 6, W - 6, 36)
list_columns(c, 6, W - 6, 64, 264, :overworld, 0, :pad)
description(c, C.action(:run))
hints(c, PAD_HINTS)
dump("A5_playstation_overworld")
$style = :xbox
$layout_key = "k:7"

# Base theme, for comparison
c = palette(0)
frame(c, "Controls")
title_button(BASE.bitmap, TOP.bitmap, c, 8, "Layouts", false, $layout_key)
area_tabs(c, :battle, 6, W - 6, 36)
list_columns(c, 6, W - 6, 64, 264, :battle, 0, :keys)
description(c, C.action(:battle_info))
hints(c, MAIN_HINTS)
dump("A4_base_battle")
puts "mockups written"
