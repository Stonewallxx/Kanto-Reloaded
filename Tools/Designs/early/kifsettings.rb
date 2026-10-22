# encoding: utf-8
# Mockup: KIF Settings improved (Reloaded Settings). Draws with KIF Beta's
# real pixel fonts and helpers (013/014), with the requested changes.
# Usage: ruby kifsettings.rb "<KIF Beta>" <work dir with metrics.json>
PREVIEW = File.join(ARGV[0], "Mods/KantoReloaded/Tools/UIPreview/preview.rb")
src = File.read(PREVIEW, :encoding => "UTF-8")
eval(src.split("#---------------------------------------------------------------- states")[0], binding, PREVIEW)
module KIF; module SettingsScreen; end; end
load File.join(KIF_ROOT, "Data/Scripts/990_KIF/000_Core/015_KIF_SettingsData.rb")

PF = KIF::PixelFont
UI = KIF::PixelUI
W = 512; H = 384
SIDE_X1 = 174; LIST_X0 = 180; LIST_X1 = W - 6; LIST_Y0 = 36; LIST_Y1 = H - 120
ROW_H = 26; HEAD_H = 18; SIDE_Y0 = 40; SIDE_DY = 20
NAME_X = LIST_X0 + 16; VAL_X1 = LIST_X1 - 12

# Capital-letter ink (top row, height) per pixel font, measured from the font data
# (flat capitals like H, E, K: Q and J hang lower and don't count)
CAPS = { [:system, 26] => [2, 18], [:narrow, 26] => [2, 18], [:small, 22] => [1, 14],
         [:small, 11] => [1, 7], [:system, 13] => [1, 9] }

# Text centred on its capitals' real height (KIF's helper uses a smaller
# "height" and so draws text a few pixels low).
def ctext(b, x, y, w, h, str, color, font = PF::TEXT, align = 0)
  str = str.to_s
  sw = PF.width(font, str)
  tx = case align when 1 then x + w - sw when 2 then x + (w - sw) / 2 else x end
  top, ink = CAPS[font] || [0, PF.height(font)]
  ty = y + (h - ink) / 2 - top
  PF.draw(b, tx, ty, str, font, color)
  return sw
end

# One character centred on its own pixels (not its spacing width): the
# section tiles' initials.
def center_glyph(b, x, y, w, h, ch, color, font = PF::TINY)
  g = PF.glyph(PF.data(font), ch)
  return unless g
  tx = x + (w - g[3]) / 2 - g[1]
  ty = y + (h - g[4]) / 2 - g[2]
  PF.draw(b, tx, ty, ch, font, color)
end

# Palettes: Base is cody's own colours; the others come from our themes.
def hexc(s); v = s.to_i(16); Color.new((v >> 16) & 255, (v >> 8) & 255, v & 255); end
def mix(a, b, t); Color.new((a.red + (b.red - a.red) * t).round, (a.green + (b.green - a.green) * t).round, (a.blue + (b.blue - a.blue) * t).round); end
BASE = { :name => "Base", :bg => UI::BG, :panel => UI::PANEL, :panel2 => UI::PANEL2, :line => UI::LINE, :txt => UI::TXT,
         :dim => UI::DIM, :sel => UI::SEL, :selb => UI::SELB, :acc => UI::ACC, :key => UI::KEY, :pill => UI::PILL,
         :dark => UI::DARK, :segon => Color.new(90, 110, 140), :sidesel => Color.new(52, 66, 86), :warn => UI::WARN,
         :dot => Color.new(232, 160, 48), :base => true }
def palette(index)
  return BASE if index.nil?
  t = Reloaded::OptionsUI::Theme::THEMES[index]
  bg = hexc(t[:bg]); panel = hexc(t[:panel])
  { :name => t[:name], :bg => bg, :panel => panel, :panel2 => mix(bg, panel, 0.5), :line => hexc(t[:line]),
    :txt => hexc(t[:text]), :dim => hexc(t[:muted]), :sel => hexc(t[:sel]), :selb => hexc(t[:accent]),
    :acc => hexc(t[:accent]), :key => hexc(t[:border]), :pill => hexc(t[:border]), :dark => bg,
    :segon => hexc(t[:inner]), :sidesel => hexc(t[:sel]), :warn => hexc(t[:gold]), :dot => hexc(t[:gold]) }
end

# Badge (KIF's pill) with its text centred.
def pill(b, c, x, y, label, right = true)
  w = PF.width(PF::TINY, label) + 12
  x -= w if right
  UI.rbox(b, x, y, x + w, y + 15, 4, c[:pill])
  ctext(b, x, y, w, 16, label, c[:txt], PF::TINY, 2)
  return w
end

# Section heading: left-aligned with a line after it (cody's style), the
# text centred on the line.
def heading(b, c, x0, x1, y, label)
  label = label.to_s.upcase
  w = ctext(b, x0, y, 300, 13, label, c[:acc], PF::TINY, 0)
  b.fill_rect(x0 + w + 6, y + 6, x1 - (x0 + w + 6), 1, c[:line])
end

# Hints like our redesign: the button in text colour, its label dimmer.
def footer(b, c, hints)
  b.fill_rect(0, H - 25, W, 25, c[:panel2])
  b.fill_rect(0, H - 25, W, 1, c[:line])
  x = 10
  hints.each do |button, label|
    case button
    when :ud
      UI.tri(b, x, H - 19, :u, c[:txt], 4); UI.tri(b, x + 10, H - 15, :d, c[:txt], 4); x += 23
    when :lr
      UI.tri(b, x, H - 17, :l, c[:txt], 4); UI.tri(b, x + 10, H - 17, :r, c[:txt], 4); x += 23
    else
      x += ctext(b, x, H - 24, 200, 24, button, c[:txt], PF::TEXT) + 5
    end
    x += ctext(b, x, H - 24, 200, 24, label, c[:dim], PF::TEXT) + 14
  end
end

def wrap(str, width)
  out = []; line = ""
  str.split(/\s+/).each do |word|
    t = line.empty? ? word : "#{line} #{word}"
    if PF.width(PF::TEXT, t) > width && !line.empty? then out << line; line = word else line = t end
  end
  out << line unless line.empty?
  out
end

SECTIONS = [[:kanto_reloaded, "Kanto Reloaded", [96, 160, 232]]] + KIF::SettingsScreen::SECTIONS.map { |id, l, col, _| [id, l, col] }
ROWS = [
  [:head, "Battle"],
  [:opt, "Battle Animations", ["Off", "On"], 1],
  [:opt, "Battle Movement", ["Off", "On"], 1],
  [:opt, "Battle Type Icons", ["Off", "On"], 0, :changed],
  [:opt, "Type Display", ["Off", "Ico", "TCG", "Sqr", "FGM", "Txt"], 1],
  [:opt, "Swap BattleGUI", ["Off", "On"], 0],
  [:head, "Sprites"],
  [:opt, "Random Sprites", ["Off", "On"], 1]
]

# The Kanto Reloaded mod's cursor (Cursor Color): [fill, border] with alpha.
KR_CURSORS = {
  "Blue"   => [[100, 160, 220, 160], [60, 120, 180, 220]], "Purple" => [[160, 120, 220, 160], [100, 60, 170, 220]],
  "Green"  => [[80, 200, 100, 160], [40, 140, 60, 220]],   "Red"    => [[220, 100, 100, 160], [170, 50, 50, 220]],
  "Orange" => [[220, 160, 80, 160], [170, 110, 30, 220]],  "Cyan"   => [[80, 220, 220, 160], [30, 160, 160, 220]],
  "Pink"   => [[220, 120, 180, 160], [160, 60, 120, 220]], "Yellow" => [[220, 210, 80, 160], [160, 150, 30, 220]],
  "White"  => [[220, 220, 220, 160], [160, 160, 160, 220]], "Black" => [[60, 60, 70, 160], [30, 30, 40, 220]]
}
# Blend a colour with alpha a over an opaque one (the mockup is one flat
# image; in the game the cursor is its own see-through layer that pulses).
def over(under, rgba, alpha)
  t = alpha / 255.0
  Color.new((under.red + (rgba[0] - under.red) * t).round, (under.green + (rgba[1] - under.green) * t).round,
            (under.blue + (rgba[2] - under.blue) * t).round)
end
# KR's cursor at the middle of its pulse: fill alpha 130, border 195.
def kr_cursor(b, c, x0, y0, x1, y1, name)
  fill, border = KR_CURSORS[name]
  UI.rbox(b, x0, y0, x1, y1, 4, over(c[:panel], fill, 130), over(c[:panel], border, 195))
end

def draw_screen(b, c, focus, section, sel, cursor = "Blue", title_focus = nil)
  b.clear
  b.fill_rect(0, 0, W, H, c[:bg])
  # title bar: Search button left, title centred, Presets button right
  b.fill_rect(0, 0, W, 32, c[:panel2])
  b.fill_rect(0, 31, W, 1, c[:line])
  ctext(b, 0, 2, W, 28, "KIF Settings", c[:txt], PF::TITLE, 2)
  [[8, "Search", :search], [W - 8 - 112, "Presets", :presets]].each do |bx, label, id|
    focused = title_focus == id
    if focused
      UI.rbox(b, bx, 4, bx + 112, 27, 5, c[:selb])
    else
      UI.rbox(b, bx, 4, bx + 112, 27, 5, c[:dark], c[:line])
    end
    fg = focused ? c[:dark] : c[:dim]
    lw = PF.width(PF::TEXT, label)
    icon = id == :search ? 16 : 0
    lx = bx + (112 - lw - icon) / 2 + icon
    if id == :search
      ix = lx - 17
      UI.rbox(b, ix, 9, ix + 9, 18, 4, fg); UI.rbox(b, ix + 2, 11, ix + 7, 16, 2, focused ? c[:selb] : c[:dark])
      3.times { |i| b.fill_rect(ix + 8 + i, 17 + i, 2, 2, fg) }
    end
    ctext(b, lx, 4, lw + 2, 24, label, fg, PF::TEXT)
  end
  # sidebar
  UI.rbox(b, 6, 36, SIDE_X1, LIST_Y1, 6, c[:panel])
  y = SIDE_Y0
  SECTIONS.first(11).each_with_index do |(id, label, col), i|
    active = i == section
    if active && focus == :side
      if c[:base]
        UI.rbox(b, 9, y - 1, SIDE_X1 - 3, y + SIDE_DY - 2, 4, c[:sel], c[:selb])
      else
        UI.rbox(b, 9, y - 1, SIDE_X1 - 3, y + SIDE_DY - 2, 4, c[:sel], c[:selb])
      end
    end
    UI.rbox(b, 14, y + 2, 28, y + 16, 3, Color.new(*col))
    center_glyph(b, 14, y + 2, 15, 15, label[0], UI::TXT)
    dimmed = [:pokemon, :selfbattle, :challenges].include?(id)
    color = active ? Color.new(255, 255, 255) : (dimmed ? mix(c[:dim], c[:panel], 0.45) : c[:dim])
    ctext(b, 33, y + 2, 140, 15, PF.fit(PF::TEXT, label, SIDE_X1 - 37), color, PF::TEXT)   # centred on the tile
    y += SIDE_DY
  end
  # list
  UI.rbox(b, LIST_X0, LIST_Y0, LIST_X1, LIST_Y1, 6, c[:panel])
  y = LIST_Y0 + 4
  opt_i = -1
  ROWS.each do |r|
    if r[0] == :head
      heading(b, c, LIST_X0 + 10, LIST_X1 - 10, y + 3, r[1])
      y += HEAD_H
      next
    end
    opt_i += 1
    selected = opt_i == sel && focus == :list
    kr_cursor(b, c, LIST_X0 + 4, y, LIST_X1 - 8, y + ROW_H - 2, cursor) if selected
    # changed from its default: a round dot in the theme's colour (Base: cody's orange)
    if r[4] == :changed
      dy = y + (ROW_H - 2) / 2 - 3
      UI.rrect(b, NAME_X - 11, dy, NAME_X - 6, dy + 5, 3, c[:base] ? c[:dot] : c[:selb])
    end
    ctext(b, NAME_X, y - 1, 330, ROW_H, r[1], c[:txt], PF::ROW)
    # KR style: the value between two arrows, cycling
    v = r[2][r[3]]
    vw = PF.width(PF::TEXT, v)
    area = 96
    cx = VAL_X1 - area / 2
    ctext(b, cx - vw / 2, y, vw + 2, ROW_H - 2, v, c[:txt], PF::TEXT)
    arrow = selected ? c[:txt] : c[:dim]
    UI.tri(b, cx - vw / 2 - 14, y + 7, :l, arrow, 4)
    UI.tri(b, cx + vw / 2 + 6, y + 7, :r, arrow, 4)
    y += ROW_H
  end
  # description: the selected setting, or the focused title button
  y0 = LIST_Y1 + 4
  UI.rbox(b, 6, y0, W - 6, H - 30, 6, c[:panel2], c[:line])
  if focus == :title
    name = title_focus == :search ? "Search" : "Presets"
    body = title_focus == :search ? "Find any setting by name, in every section. Results show as you type." :
                                    "Save your settings to load later, or share them as a code."
    ctext(b, 14, y0 + 1, 330, 26, name, c[:txt], PF::ROW)
  else
    ctext(b, 14, y0 + 1, 330, 26, "Type Display", c[:txt], PF::ROW)
    x = W - 14
    x -= pill(b, c, x, y0 + 7, "ALL SAVES") + 6
    pill(b, c, x, y0 + 7, "DEFAULT: ICO")
    body = "How each Pokémon's types show in battle: icons, TCG energy, square badges, FGM or text."
  end
  wrap(body, W - 30).each_with_index do |ln, k|
    ctext(b, 14, y0 + 28 + k * 17, W - 34, 17, ln, c[:txt], PF::TEXT)
  end
  footer(b, c, case focus
               when :side  then [[:ud, "Section"], [:lr, "Open"], ["D", "Search"], ["Esc", "Close"]]
               when :title then [[:lr, "Choose"], ["C", "Select"], [:ud, "Back to list"]]
               else             [[:ud, "Select"], [:lr, "Change"], ["Z", "Default"], ["D", "Search"], ["X", "Sections"]]
               end)
end

# Cursor Color list: Theme + the 45 text colours. The KR mod's 10 keep
# their exact fill/border; the rest: the colour as fill, a darker border.
def cursor_entries
  list = [["Theme", nil]]
  Reloaded::OptionsUI::Theme::COLORS.each do |name, hex, _|
    if KR_CURSORS[name]
      list << [name, KR_CURSORS[name]]
    else
      v = hex.to_i(16); r, g, bl = (v >> 16) & 255, (v >> 8) & 255, v & 255
      list << [name, [[r, g, bl, 160], [(r * 0.65).round, (g * 0.65).round, (bl * 0.65).round, 220]]]
    end
  end
  list
end

def cursor_picker(b, c, index, top)
  entries = cursor_entries
  rows = 9
  pw = 240; rh = 22
  ph = 40 + rows * rh + 10
  px = (W - pw) / 2; py = (H - ph) / 2
  b.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 120))
  UI.rbox(b, px, py, px + pw, py + ph, 6, c[:panel2], c[:line])
  ctext(b, px, py + 6, pw, 26, "Cursor Color", c[:txt], PF::ROW, 2)
  b.fill_rect(px + 10, py + 34, pw - 20, 1, c[:line])
  rows.times do |k|
    i = top + k
    name, colours = entries[i]
    colours ||= [[c[:selb].red, c[:selb].green, c[:selb].blue, 160], [(c[:selb].red * 0.65).round, (c[:selb].green * 0.65).round, (c[:selb].blue * 0.65).round, 220]]
    y = py + 40 + k * rh
    # the selected row wears the cursor it would give you
    if i == index
      UI.rbox(b, px + 6, y, px + pw - 6, y + rh - 2, 4, over(c[:panel2], colours[0], 130), over(c[:panel2], colours[1], 195))
    end
    # swatch: a small cursor
    UI.rbox(b, px + 14, y + 4, px + 44, y + rh - 6, 4, over(c[:panel2], colours[0], 160), over(c[:panel2], colours[1], 220))
    ctext(b, px + 54, y, pw - 64, rh - 2, name, c[:txt], PF::TEXT)
  end
  UI.tri(b, px + pw / 2 - 4, py + 35, :u, c[:dim], 3) if top > 0
  UI.tri(b, px + pw / 2 - 4, py + ph - 8, :d, c[:dim], 3) if top + rows < entries.length
end

holder = Sprite.new(Viewport.new(0, 0, W, H))
holder.bitmap = Bitmap.new(W, H)
draw_screen(holder.bitmap, palette(nil), :list, 4, 3);      dump("K1_base_list", nil)
draw_screen(holder.bitmap, palette(nil), :side, 4, 3);      dump("K2_base_sidebar", nil)
draw_screen(holder.bitmap, palette(1), :list, 4, 3);        dump("K3_ocean_list", nil)
draw_screen(holder.bitmap, palette(1), :side, 4, 3);        dump("K4_ocean_sidebar", nil)
draw_screen(holder.bitmap, palette(3), :list, 4, 3, "Red");    dump("K5_red_theme_red_cursor", nil)
draw_screen(holder.bitmap, palette(1), :list, 4, 3, "Green");  dump("K6_ocean_green_cursor", nil)
draw_screen(holder.bitmap, palette(1), :title, 4, 3, "Blue", :search); dump("K7_ocean_search_focus", nil)
draw_screen(holder.bitmap, palette(nil), :title, 4, 3, "Blue", :presets); dump("K8_base_presets_focus", nil)
overlay = Sprite.new(Viewport.new(0, 0, W, H))
overlay.z = 5
overlay.bitmap = Bitmap.new(W, H)
draw_screen(holder.bitmap, palette(1), :list, 4, 3, "Blue")
blues = cursor_entries.index { |e| e[0] == "Blue" }
cursor_picker(overlay.bitmap, palette(1), blues, blues - 4); dump("K9_cursor_color_picker", nil)
overlay.bitmap.clear
draw_screen(holder.bitmap, palette(3), :list, 4, 3, "Red")
cursor_picker(overlay.bitmap, palette(3), 0, 0); dump("K10_cursor_picker_top", nil)
overlay.dispose
