# encoding: utf-8
# Mockup: the Reloaded Controls screen in the improved KIF Settings' layout.
# Boots the mod through the UI preview's stand-ins (KIF's pixel fonts, the
# mod's Palette, Pixel, ButtonIcons and Controls with KIF Beta's F1 bindings).
# Usage (cwd = KIF Beta): ruby controls.rb "<KIF Beta>" <work dir with metrics.json>
PREVIEW = File.join(ARGV[0], "Mods/KantoReloaded/Tools/UIPreview/preview.rb")
src = File.read(PREVIEW, :encoding => "UTF-8")
eval(src.split("#---------------------------------------------------------------- A: Ocean Blue")[0], binding, PREVIEW)

C = Reloaded::Controls
P = Reloaded::Pixel
BI = Reloaded::ButtonIcons
PF = KIF::PixelFont
UI = KIF::PixelUI
W = 512; H = 384
SIDE_X1 = 174; LIST_X0 = 180; LIST_X1 = W - 6; LIST_Y0 = 36; LIST_Y1 = H - 120
ROW_H = 26; HEAD_H = 18; NAME_X = LIST_X0 + 21
KEY_X = 322; PAD_X = 422

# The actions a first version would have, in headings (feature splits start on today's buttons)
GROUPS = {
  :up => "Movement", :down => "Movement", :left => "Movement", :right => "Movement",
  :confirm => "Buttons", :back => "Buttons", :action => "Buttons", :special => "Buttons",
  :x => "Buttons", :y => "Buttons", :page_left => "Buttons", :page_right => "Buttons"
}
[
  [:speed_up,    "Speed-Up",      :global,    :x,          "Speed",    "Speeds the game up while held, or toggles it (the Speed-Up setting)."],
  [:speed_next,  "Next Speed",    :global,    :page_left,  "Speed",    "KIF's speed-up: the next speed."],
  [:speed_reset, "Normal Speed",  :global,    :page_right, "Speed",    "KIF's speed-up: back to normal speed."],
  [:run,         "Run",           :overworld, :action,     "Walking",  "Run while held (or walk, with Default Movement on Run)."],
  [:ready_menu,  "Ready Menu",    :overworld, :special,    "Menus",    "Opens the Ready Menu of registered items."],
  [:quicksave,   "Quicksave",     :overworld, :y,          "Tools",    "Saves the game on the map (Quicksave with S)."],
  [:battle_info, "Battle Info",   :battle,    :action,     "Commands", "Opens Battle Info from the command menu."],
  [:shift,       "Shift",         :battle,    :special,    "Commands", "Shifts position in a triple battle."],
  [:default,     "Reset Setting", :menus,     :action,     "Settings", "Puts the selected setting back to its default."],
  [:search,      "Search",        :menus,     :special,    "Settings", "Opens search on the settings screen."]
].each_with_index do |(id, name, area, follows, group, desc), i|
  C.register(id, :name => name, :area => area, :follows => follows, :description => desc, :priority => 20 + i)
  GROUPS[id] = group
end
[
  [:run_toggle, "Run Toggle", :overworld, "Walking", "Switches between walking and running."],
  [:bike,       "Bike",       :overworld, "Walking", "Gets on or off your bike."],
  [:radar,      "Poké Radar", :overworld, "Tools",   "Uses the Poké Radar."],
  [:screenshot, "Screenshot", :global,    "Other",   "Saves a screenshot (F8 still works)."]
].each_with_index do |(id, name, area, group, desc), i|
  C.register(id, :name => name, :area => area, :description => desc, :priority => 40 + i)
  GROUPS[id] = group
end
C.bind(:quicksave, :keys, ["k:20"])              # Q: a clash with Next Speed, to show the warning
C.bind(:run_toggle, :pad, ["hold:p:3"])          # hold Y

SECTIONS = [[:global, "Global", [96, 160, 232]], [:overworld, "Overworld", [90, 170, 100]],
            [:menus, "Menus", [130, 140, 155]], [:battle, "Battle", [210, 80, 80]],
            [:feel, "Feel", [160, 110, 200]]]
FEEL = [:"controls.button_style", :"controls.swap_ab", :"controls.repeat", :"controls.hold_time", :"controls.trigger_press", :"controls.deadzone"]

$style = :xbox
def col(rgb); Color.new(*rgb); end

#---------------------------------------------------------------- layers
$vp = Viewport.new(0, 0, W, H)
$vp.z = 99_999
def layer(z); s = Sprite.new($vp); s.bitmap = Bitmap.new(W, H); s.z = z; s; end
BASE = layer(0)
CUR = Sprite.new($vp); CUR.z = 1
TOP = layer(2)
OVER = layer(3)

def cursor_at(x, y, w, h)
  CUR.bitmap = P.cursor_bitmap(w, h)
  CUR.x = x; CUR.y = y; CUR.opacity = 200; CUR.visible = true
end

#---------------------------------------------------------------- the screen
def frame(c)
  BASE.bitmap.clear; TOP.bitmap.clear; OVER.bitmap.clear
  CUR.visible = false
  BASE.bitmap.fill_rect(0, 0, W, H, c[:bg])
end

def magnifier(base, ix, fg, hole)
  UI.rbox(base, ix, 9, ix + 9, 18, 4, fg)
  UI.rbox(base, ix + 2, 11, ix + 7, 16, 2, hole)
  3.times { |i| base.fill_rect(ix + 8 + i, 17 + i, 2, 2, fg) }
end

def title_bar(c, left_key, right_key)
  base = BASE.bitmap; top = TOP.bitmap
  base.fill_rect(0, 0, W, 32, c[:panel2])
  base.fill_rect(0, 31, W, 1, c[:line])
  P.text(top, 0, 2, W, 28, "Controls", c[:title], PF::TITLE, 2)
  [[8, "Search", true], [W - 120, "Layouts", false]].each do |bx, label, icon|
    UI.rbox(base, bx, 4, bx + 112, 27, 5, c[:dark], c[:line])
    lw = P.width(PF::TEXT, label)
    iw = icon ? 16 : 0
    lx = bx + (112 - lw - iw) / 2 + iw
    magnifier(base, lx - 17, c[:dim], c[:dark]) if icon
    P.text(top, lx, 4, lw + 2, 24, label, c[:dim])
  end
  BI.draw(top, 8 + 112 + 6, 8, left_key, c, $style)
  BI.draw(top, W - 120 - 6 - BI.width(right_key, $style), 8, right_key, c, $style)
end

def sidebar(c, sec, focus_side)
  base = BASE.bitmap; top = TOP.bitmap
  UI.rbox(base, 6, 36, SIDE_X1, LIST_Y1, 6, c[:panel])
  y = 40
  SECTIONS.each do |id, label, rgb|
    on = id == sec
    cursor_at(9, y - 1, SIDE_X1 - 3 - 9 + 1, 20) if on && focus_side
    UI.rbox(top, 14, y + 2, 28, y + 16, 3, col(rgb))
    P.glyph(top, 14, y + 2, 15, 15, label[0], Color.new(248, 248, 248))
    P.text(top, 33, y + 2, SIDE_X1 - 37, 15, label, on ? c[:white] : c[:dim])
    y += 20
  end
end

def items_for(area)
  out = []
  last = nil
  order = ["Movement", "Buttons", "Speed", "Walking", "Menus", "Tools", "Commands", "Settings", "Other"]
  C.actions(area).sort_by { |a| [order.index(GROUPS[a.id] || "Other") || 99, a.priority] }.each do |a|
    g = GROUPS[a.id] || "Other"
    out << [:head, g] if g != last
    last = g
    out << [:row, a]
  end
  out
end

def chips(b, x, x1, y, tokens, c, clash)
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
    P.small(b, x, y, 80, 18, "Not Bound", c[:dim])
  end
end

# The list of an area: column names, headings, actions with their two cells
def action_list(c, area, sel, side, focus_list)
  base = BASE.bitmap; top = TOP.bitmap
  UI.rbox(base, LIST_X0, LIST_Y0, LIST_X1, LIST_Y1, 6, c[:panel])
  P.text(top, KEY_X, LIST_Y0 + 4, 90, 13, "KEYBOARD", c[:dim], PF::TINY)
  P.text(top, PAD_X, LIST_Y0 + 4, 90, 13, "CONTROLLER", c[:dim], PF::TINY)
  items = items_for(area)
  ys = []
  y = 0
  items.each { |k, _| ys << y; y += k == :head ? HEAD_H : ROW_H }
  rows = items.each_index.select { |i| items[i][0] == :row }
  si = rows[sel]
  top_y = LIST_Y0 + 18
  avail = LIST_Y1 - 4 - top_y
  scroll = 0
  scroll = ys[si] + ROW_H - avail if si && ys[si] + ROW_H > avail
  items.each_with_index do |(kind, what), i|
    yy = top_y + ys[i] - scroll
    next if ys[i] < scroll || ys[i] - scroll + (kind == :head ? HEAD_H : ROW_H) > avail
    if kind == :head
      P.heading(top, LIST_X0 + 10, LIST_X1 - 10, yy + 3, what, c[:head], c[:line])
      next
    end
    a = what
    clash = C.clashes(a.id).map { |_, t| t }
    if i == si && focus_list
      cursor_at(LIST_X0 + 4, yy, (LIST_X1 - 8) - (LIST_X0 + 4) + 1, ROW_H - 1)
      cx0 = side == :keys ? KEY_X - 5 : PAD_X - 5
      cx1 = side == :keys ? PAD_X - 8 : LIST_X1 - 10
      UI.rbox(top, cx0, yy + 1, cx1, yy + ROW_H - 3, 4, c[:selb])
      UI.rbox(top, cx0 + 1, yy + 2, cx1 - 1, yy + ROW_H - 4, 3, Reloaded::Palette.mix(c[:panel], c[:sel], 0.6))
    end
    if C.customized?(a.id)
      dy = yy + (ROW_H - 2) / 2 - 3
      UI.rrect(top, NAME_X - 11, dy, NAME_X - 6, dy + 5, 3, c[:dot])
    end
    P.text(top, NAME_X, yy, KEY_X - NAME_X - 6, ROW_H - 2, PF.fit(PF::ROW, a.name, KEY_X - NAME_X - 6), c[:opt], PF::ROW)
    chips(top, KEY_X, PAD_X - 10, yy + 3, C.bindings(a.id, :keys), c, clash)
    chips(top, PAD_X, LIST_X1 - 12, yy + 3, C.bindings(a.id, :pad), c, clash)
  end
  total = ys.last.to_i + ROW_H
  if total > avail
    track = LIST_Y1 - LIST_Y0 - 12
    bar = [track * avail / total, 12].max
    pos = (track - bar) * scroll / [total - avail, 1].max
    base.fill_rect(LIST_X1 - 5, LIST_Y0 + 6, 2, track, c[:line])
    base.fill_rect(LIST_X1 - 5, LIST_Y0 + 6 + pos, 2, bar, c[:dim])
  end
  return si ? items[si][1] : nil
end

# The Feel section: settings rows, as in the settings screen
def feel_list(c, sel, focus_list)
  base = BASE.bitmap; top = TOP.bitmap
  UI.rbox(base, LIST_X0, LIST_Y0, LIST_X1, LIST_Y1, 6, c[:panel])
  y = LIST_Y0 + 4
  P.heading(top, LIST_X0 + 10, LIST_X1 - 10, y + 3, "Feel", c[:head], c[:line])
  y += HEAD_H
  cx = LIST_X1 - 12 - 48
  FEEL.each_with_index do |k, i|
    d = Reloaded::Settings.definition(k)
    cursor_at(LIST_X0 + 4, y, (LIST_X1 - 8) - (LIST_X0 + 4) + 1, ROW_H - 1) if i == sel && focus_list
    P.text(top, NAME_X, y, 200, ROW_H - 2, d[:name], c[:opt], PF::ROW)
    v = Reloaded::Settings.display(k).to_s
    vw = P.width(PF::TEXT, v)
    P.text(top, cx - vw / 2, y, vw + 2, ROW_H - 2, v, c[:opt])
    arrow = i == sel ? c[:txt] : c[:dim]
    UI.tri(top, cx - vw / 2 - 14, y + 7, :l, arrow, 4)
    UI.tri(top, cx + vw / 2 + 6, y + 7, :r, arrow, 4)
    y += ROW_H
  end
  return Reloaded::Settings.definition(FEEL[sel])
end

def description(c, title, pills, body, warn = nil)
  base = BASE.bitmap; top = TOP.bitmap
  y0 = LIST_Y1 + 4
  UI.rbox(base, 6, y0, W - 6, H - 30, 6, c[:panel2], c[:line])
  P.text(top, 14, y0 + 1, 330, 26, title, c[:head], PF::ROW)
  x = W - 14
  pills.each { |p| x -= P.pill(top, x, y0 + 7, p, c[:pill], c[:txt]) + 6 }
  lines = P.small_wrap(top, body, W - 30)
  lines.first(warn ? 2 : 3).each_with_index { |ln, k| P.small(top, 14, y0 + 28 + k * 17, W - 34, 17, ln, c[:txt]) }
  P.small(top, 14, y0 + 28 + 2 * 17, W - 34, 17, warn, c[:warn]) if warn
end

def action_desc(c, a, warn = nil)
  area = SECTIONS.find { |id, _, _| id == a.area }[1].upcase
  pills = [area]
  pills << "ON #{C.action(a.follows).name.upcase}" if a.follows && !C.customized?(a.id)
  description(c, a.name, pills, a.description, warn)
end

def hints(c, pairs)
  P.hints(BASE.bitmap, TOP.bitmap, c, pairs, $style)
end

def palette(theme)
  Reloaded::Settings.set(:"interface.theme", theme)
  return Reloaded::Palette.current
end

KEYS = { :left => "k:7", :right => "k:26", :use => "k:6", :act => "k:29", :back => "k:27" }
PADS = { :left => "p:9", :right => "p:10", :use => "p:0", :act => "p:2", :back => "p:1" }
def list_hints(k); [[:ud, "Select"], [:lr, "Column"], [k[:use], "Change"], [k[:act], "Default"], [k[:back], "Sections"]]; end
def side_hints(k); [[:ud, "Section"], [:lr, "Open"], [k[:back], "Close"]]; end

def screen(c, k, sec, sel, side, focus_list)
  frame(c)
  title_bar(c, k[:left], k[:right])
  sidebar(c, sec, !focus_list)
  return feel_list(c, sel, focus_list) if sec == :feel
  return action_list(c, sec, sel, side, focus_list)
end

#---------------------------------------------------------------- popups
def popup_list(c, title, rows, sel, desc)
  b = OVER.bitmap
  b.clear
  b.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 120))
  w = 300; rh = 24
  h = 40 + rows.length * rh + 8 + 44
  x = (W - w) / 2; y = (H - h) / 2
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
    lx += BI.draw(b, lx, ry + 3, icon, c, $style, 18) + 8 if icon
    P.text(b, lx, ry, w - (lx - x) - 12, rh - 2, label, c[:opt])
  end
  b.fill_rect(x + 10, y + h - 48, w - 20, 1, c[:line])
  P.small_wrap(b, desc, w - 28).first(2).each_with_index { |ln, i| P.small(b, x + 14, y + h - 44 + i * 18, w - 28, 18, ln, c[:dim]) }
end

#---------------------------------------------------------------- the states
c = palette(2)
screen(c, KEYS, :global, 0, :keys, false)
description(c, "Global", [], "Buttons that work everywhere, like moving, the game's buttons, speed-up and screenshots.")
hints(c, side_hints(KEYS))
dump("S1_global_sections")

a = screen(c, KEYS, :global, 4, :keys, true)
action_desc(c, a)
hints(c, list_hints(KEYS))
dump("S2_global_confirm_keyboard")

a = screen(c, KEYS, :overworld, 4, :keys, true)
action_desc(c, a, "Q is also Next Speed (Global): both happen on the map.")
hints(c, list_hints(KEYS))
dump("S3_overworld_clash")

$style = :playstation
a = screen(c, PADS, :overworld, 0, :pad, true)
action_desc(c, a)
hints(c, list_hints(PADS))
dump("S4_overworld_run_playstation")
$style = :xbox

d = screen(c, KEYS, :feel, 2, :keys, true)
description(c, d[:name], ["ALL SAVES", "DEFAULT: NORMAL"], d[:description])
hints(c, [[:ud, "Select"], [:lr, "Change"], [KEYS[:act], "Default"], [KEYS[:back], "Sections"]])
dump("S5_feel")

a = screen(c, KEYS, :overworld, 0, :keys, true)
action_desc(c, a)
hints(c, [[:ud, "Select"], [KEYS[:use], "Choose"], [KEYS[:back], "Close"]])
popup_list(c, "Run: Keyboard", [["k:225", "Remove"], ["k:29", "Remove"], [nil, "Add a Key"], [nil, "Add a Hold"],
                                [nil, "Back to Default (Action)"]], 2,
           "Press a key to add it. Run can have as many keys as you like.")
dump("S6_editor")

# Text in colours, wrapped to a width and centred, in the smaller text:
# segments [[text, colour], ...]
C_WHITE = Color.new(255, 255, 255)
def rich_small(b, x, y, w, line_h, segments)
  P.small_font(b)
  tokens = []
  # highlighted phrases (white) are never split across lines
  segments.each do |text, color|
    if color == C_WHITE
      tokens << [text, color]
    else
      text.scan(/\S+|\s+/).each { |t| tokens << [t, color] }
    end
  end
  lines = [[]]
  width = 0
  tokens.each do |t, color|
    tw = b.text_size(t).width
    if t =~ /\A\s+\z/
      next if lines.last.empty?
    elsif width + tw > w && !lines.last.empty?
      lines.last.pop while lines.last.last && lines.last.last[0] =~ /\A\s+\z/
      lines << []
      width = 0
    end
    lines.last << [t, color, tw]
    width += tw
  end
  lines.each_with_index do |line, i|
    lw = line.sum { |_, _, tw| tw }
    lx = x + (w - lw) / 2
    line.each { |t, color, tw| P.small(b, lx, y + i * line_h, tw + 2, line_h, t, color); lx += tw }
  end
  return lines.length
end

def capture_popup(c, title, segments)
  b = OVER.bitmap
  b.clear
  b.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 120))
  w = 300; h = 112; x = (W - w) / 2; y = (H - h) / 2
  UI.rbox(b, x, y, x + w, y + h, 6, c[:panel2], c[:line])
  P.text(b, x, y + 6, w, 26, title, c[:title], PF::ROW, 2)
  b.fill_rect(x + 10, y + 34, w - 20, 1, c[:line])
  n = rich_small(b, x + 16, y + 44, w - 32, 18, segments)
  by = y + 50 + n * 18
  UI.rbox(b, x + 40, by, x + w - 40, by + 4, 2, c[:dark])
  UI.rbox(b, x + 40, by, x + 40 + (w - 80) * 2 / 3, by + 4, 2, c[:selb])
end

WAIT_HINT = [[nil, "Waiting... Nothing Pressed: It closes when the bar runs out."]]
a = screen(c, PADS, :overworld, 0, :pad, true)
action_desc(c, a)
hints(c, WAIT_HINT)
capture_popup(c, "Run: Controller", [["Press a Button", c[:white]], [" or ", c[:dim]], ["Move a Stick", c[:white]],
                                     [". Keep holding it to bind it as a Hold.", c[:dim]]])
dump("S7_press_a_button")

a = screen(c, KEYS, :overworld, 0, :keys, true)
action_desc(c, a)
hints(c, WAIT_HINT)
capture_popup(c, "Run: Keyboard", [["Press a Key", c[:white]], [". Keep holding it to bind it as a Hold.", c[:dim]]])
dump("S7b_press_a_key")

a = screen(c, KEYS, :global, 4, :keys, false)
description(c, "Global", [], "Buttons that work everywhere, like moving, the game's buttons, speed-up and screenshots.")
hints(c, [[:ud, "Select"], [KEYS[:use], "Choose"], [KEYS[:back], "Close"]])
popup_list(c, "Layouts", [[nil, "Game's Layout (F1)"], [nil, "Pokémon-Style"], [nil, "Reset Section (Global)"],
                          [nil, "Reset All to Default"], [nil, "Cancel"]], 2,
           "Puts every action in Global back to its default.")
dump("S8_layouts")

# Binding a key another action already has
a = screen(c, KEYS, :overworld, 4, :keys, true)
action_desc(c, a)
hints(c, [[:lr, "Choose"], [KEYS[:use], "Select"], [KEYS[:back], "Cancel"]])
b = OVER.bitmap
b.clear
b.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 120))
w = 330; h = 150; x = (W - w) / 2; y = (H - h) / 2
UI.rbox(b, x, y, x + w, y + h, 6, c[:panel2], c[:line])
P.text(b, x, y + 6, w, 26, "Quicksave: Keyboard", c[:title], PF::ROW, 2)
b.fill_rect(x + 10, y + 34, w - 20, 1, c[:line])
P.text(b, x, y + 42, w, 20, "Q is already Next Speed (Global).", c[:txt], nil, 2)
rich_small(b, x + 16, y + 66, w - 32, 18, [["Swap", c[:white]], [" gives Next Speed the S key. ", c[:dim]], ["Keep Both", c[:white]],
                                           [" lets Q do both on the map.", c[:dim]]])
labels = ["Swap", "Keep Both", "Cancel"]
widths = labels.map { |l| [P.width(PF::TEXT, l) + 28, 72].max }
bx = x + (w - widths.sum - 10 * (labels.length - 1)) / 2
by = y + h - 36
labels.each_with_index do |l, i|
  if i == 0
    UI.rbox(b, bx, by, bx + widths[i], by + 24, 5, c[:selb])
    P.text(b, bx, by, widths[i], 24, l, c[:dark], nil, 2)
  else
    UI.rbox(b, bx, by, bx + widths[i], by + 24, 5, c[:dark], c[:line])
    P.text(b, bx, by, widths[i], 24, l, c[:txt], nil, 2)
  end
  bx += widths[i] + 10
end
dump("S10_clash_prompt")

c = palette(0)
a = screen(c, KEYS, :battle, 0, :keys, true)
action_desc(c, a)
hints(c, list_hints(KEYS))
dump("S9_base_battle")
puts "mockups written"
