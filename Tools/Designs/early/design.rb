# encoding: utf-8
# Design mockups for Kanto Reloaded's own popups (menu, confirm, text entry),
# drawn with the mod's real Draw/Theme code and the game's fonts.
# Usage: ruby design.rb "<KIF Beta>" <work dir with metrics.json>
PREVIEW = File.join(ARGV[0], "Mods/KantoReloaded/Tools/UIPreview/preview.rb")
src = File.read(PREVIEW, :encoding => "UTF-8")
eval(src.split("#---------------------------------------------------------------- states")[0], binding, PREVIEW)

D = Reloaded::OptionsUI::Draw
W = 512
H = 384

scene = Reloaded::OptionsUI::Scene.new(false)
scene.start
iv = proc { |k, v| scene.instance_variable_set(k, v) }
items = proc { scene.instance_variable_get(:@items) }
iv.call(:@group, :general); iv.call(:@open_page, :interface); scene.build_items
iv.call(:@index, 0); iv.call(:@top, 0); scene.clamp_scroll
iv.call(:@focus, :title); iv.call(:@title_choice, 1)
scene.refresh
c = scene.palette
ov = scene.overlay.bitmap

def dim(b); b.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 120)); end

COMMANDS = [["Save Current As Preset", "Save every Kanto Reloaded setting under a name."],
            ["Load A Preset", "Load settings you saved before."],
            ["Delete A Preset", "Remove a saved preset."],
            ["Copy Share Code", "Copy your settings as one line of text to share."],
            ["Paste Share Code", "Load settings from a code someone shared."],
            ["Cancel", "Close this menu."]]

# A list row: selected = accent outline on the selection fill.
def menu_row(b, c, x, y, w, h, label, selected, font = :system)
  if selected
    D.rounded(b, x, y, w, h, c[:sel])
    D.outline(b, x, y, w, h, c[:accent])
  end
  font == :system ? pbSetSystemFont(b) : pbSetSmallFont(b)
  D.text(b, x + 12, y, w - 24, h, label, selected ? c[:text] : c[:opt], nil, 0)
end

#---------------------------------------------------------------- M1: centered dialog
ov.clear; dim(ov)
pw = 300; rows = COMMANDS.length; rh = 28
ph = 44 + rows * rh + 8 + 44
px = (W - pw) / 2; py = (H - ph) / 2
D.panel(ov, px, py, pw, ph, c)
pbSetSystemFont(ov)
D.text(ov, px, py + 8, pw, 26, "Presets", c[:head], c[:head_sh], 1)
ov.fill_rect(px + 12, py + 38, pw - 24, 2, c[:line])
COMMANDS.each_with_index { |(label, _), i| menu_row(ov, c, px + 8, py + 44 + i * rh, pw - 16, rh - 2, label, i == 0) }
ov.fill_rect(px + 12, py + ph - 48, pw - 24, 2, c[:line])
pbSetSmallFont(ov)
D.wrap(ov, COMMANDS[0][1], pw - 32, 2).each_with_index { |l, i| D.text(ov, px + 16, py + ph - 44 + i * 20, pw - 32, 20, l, c[:muted], nil, 0) }
dump("M1_menu_dialog", scene)

#---------------------------------------------------------------- M2: dropdown under the Presets button
ov.clear
pw = 230; rh = 26
ph = 8 + rows * rh + 6
px = W - 14 - pw; py = 36
D.panel(ov, px, py, pw, ph, c)
COMMANDS.each_with_index { |(label, _), i| menu_row(ov, c, px + 6, py + 6 + i * rh, pw - 12, rh - 2, label, i == 0, :small) }
# its explanation goes in the screen's own description box
dy = Reloaded::OptionsUI::Scene::DESC_Y
D.panel(ov, 4, dy, W - 8, Reloaded::OptionsUI::Scene::DESC_H, c)
pbSetSystemFont(ov)
D.text(ov, 16, dy + 6, 300, 28, COMMANDS[0][0], c[:accent], c[:bg], 0)
pbSetSmallFont(ov)
D.text(ov, 16, dy + 34, W - 32, 22, COMMANDS[0][1], c[:text], nil, 0)
ov.font.size = 20
D.text(ov, 16, dy + 84, 400, 20, "A Select   B Close   Up/Down Choose", c[:muted], nil, 0)
dump("M2_menu_dropdown", scene)

#---------------------------------------------------------------- C1: confirm (Yes/No) and notice (OK)
def dialog(ov, c, scene, title, text, buttons, choice, name)
  ov.clear; dim(ov)
  pw = 380
  pbSetSmallFont(ov)
  lines = D.wrap(ov, text, pw - 32, 4)
  ph = 44 + lines.length * 22 + 50
  px = (W - pw) / 2; py = (H - ph) / 2
  D.panel(ov, px, py, pw, ph, c)
  pbSetSystemFont(ov)
  D.text(ov, px, py + 8, pw, 26, title, c[:head], c[:head_sh], 1)
  pbSetSmallFont(ov)
  lines.each_with_index { |l, i| D.text(ov, px + 16, py + 40 + i * 22, pw - 32, 22, l, c[:text], nil, 1) }
  widths = buttons.map { |b| [ov.text_size(b).width + 28, 72].max }
  total = widths.sum + 10 * (buttons.length - 1)
  bx = px + (pw - total) / 2; by = py + ph - 38
  buttons.each_with_index do |label, i|
    if i == choice
      D.rounded(ov, bx, by, widths[i], 26, c[:accent])
      D.text(ov, bx, by, widths[i], 26, label, c[:on_accent], nil, 1)
    else
      D.outline(ov, bx, by, widths[i], 26, c[:border])
      D.text(ov, bx, by, widths[i], 26, label, c[:text], nil, 1)
    end
    bx += widths[i] + 10
  end
  dump(name, scene)
end
dialog(ov, c, scene, "Replace Preset?", "A preset named Nuzlocke already exists. Replace it with your current settings?", ["Replace", "Cancel"], 0, "C1_confirm")
dialog(ov, c, scene, "Preset Saved", "Saved your settings as Nuzlocke.", ["OK"], 0, "C2_notice")

#---------------------------------------------------------------- T1: text entry popup with a key grid
KEYS = ["ABCDEFGHIJ", "KLMNOPQRST", "UVWXYZ-'.&", "1234567890"]
def key_grid(ov, c, gx, gy, kw, kh, sel)
  KEYS.each_with_index do |row, r|
    row.each_char.with_index do |ch, i|
      x = gx + i * (kw + 4); y = gy + r * (kh + 4)
      if [r, i] == sel
        D.rounded(ov, x, y, kw, kh, c[:accent])
        D.text(ov, x, y, kw, kh, ch, c[:on_accent], nil, 1)
      else
        D.outline(ov, x, y, kw, kh, c[:border])
        D.text(ov, x, y, kw, kh, ch, c[:text], nil, 1)
      end
    end
  end
end
def entry_field(ov, c, x, y, w, h, text, placeholder = nil)
  D.rounded(ov, x, y, w, h, c[:bg])
  D.outline(ov, x, y, w, h, c[:accent])
  pbSetSystemFont(ov)
  if text.empty? && placeholder
    D.text(ov, x + 10, y, w - 20, h, placeholder, c[:muted], nil, 0)
    tw = 0
  else
    D.text(ov, x + 10, y, w - 20, h, text, c[:text], nil, 0)
    tw = ov.text_size(text).width
  end
  ov.fill_rect(x + 11 + tw, y + 5, 2, h - 10, c[:accent])     # caret
end
ov.clear; dim(ov)
pw = 456; ph = 300
px = (W - pw) / 2; py = (H - ph) / 2
D.panel(ov, px, py, pw, ph, c)
pbSetSystemFont(ov)
D.text(ov, px, py + 8, pw, 26, "Search", c[:head], c[:head_sh], 1)
entry_field(ov, c, px + 16, py + 42, pw - 32, 32, "speed")
pbSetSmallFont(ov)
key_grid(ov, c, px + 16 + 7, py + 86, 38, 30, [1, 8])
by = py + 86 + 4 * 34 + 4
[["Space", 120], ["Delete", 120], ["Done", 120]].each_with_index do |(label, bw), i|
  bx = px + 16 + 7 + i * (bw + 22)
  if i == 2
    D.rounded(ov, bx, by, bw, 28, c[:accent]); D.text(ov, bx, by, bw, 28, label, c[:on_accent], nil, 1)
  else
    D.outline(ov, bx, by, bw, 28, c[:border]); D.text(ov, bx, by, bw, 28, label, c[:text], nil, 1)
  end
end
ov.font.size = 20
D.text(ov, px, py + ph - 26, pw, 20, "Type with the keyboard any time   A Key   B Delete   Start Done", c[:muted], nil, 1)
dump("T1_text_popup", scene)

#---------------------------------------------------------------- T2: live search in the title bar
scene2 = scene
iv.call(:@focus, :list)
ov.clear
# the Search button becomes a field across the title bar; results filter as you type
D.panel(ov, 4, 4, W - 8, 34, c)
entry_field(ov, c, 14, 9, W - 28, 26, "sm", nil)
pbSetSmallFont(ov)
# results list (what the screen would show live)
D.panel(ov, 4, 42, W - 8, 226, c)
D.text(ov, 0, 46, W, 20, "1 result", c[:muted], nil, 1)
menu_row(ov, c, 10, 70, W - 20, 30, "Global Small Text", true)
pbSetSmallFont(ov)
D.text(ov, 220, 70, 120, 30, "Interface", c[:muted], nil, 0)
# compact key grid where the description box was (shown when a controller is used)
dy = Reloaded::OptionsUI::Scene::DESC_Y
D.panel(ov, 4, dy - 30, W - 8, 140, c)
KEYS.each_with_index do |row, r|
  row.each_char.with_index do |ch, i|
    x = 16 + i * 40; y = dy - 22 + r * 26
    sel = [r, i] == [1, 8]
    sel ? D.rounded(ov, x, y, 36, 22, c[:accent]) : D.outline(ov, x, y, 36, 22, c[:border])
    D.text(ov, x, y, 36, 22, ch, sel ? c[:on_accent] : c[:text], nil, 1)
  end
end
["Space", "Delete", "Done"].each_with_index do |label, i|
  x = 420; y = dy - 22 + i * 30
  D.outline(ov, x, y, 76, 24, c[:border]); D.text(ov, x, y, 76, 24, label, c[:text], nil, 1)
end
ov.font.size = 20
D.text(ov, 0, dy + 88, W, 20, "Results update as you type   A Key   B Delete   Start Done", c[:muted], nil, 1)
dump("T2_live_search", scene)
scene.finish
