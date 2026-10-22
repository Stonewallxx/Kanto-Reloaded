# encoding: utf-8
# Mockups: a slider or number setting on an Overworld Menu page (his ask,
# 2026-10-21: Add a Setting allows them, and A opens a small popup, as Left
# and Right already switch pages). Music Volume at 80 is being changed to 65;
# Speed-Up Limit (a number) is beside it. Three designs, drawn over the real
# Overworld Menu (the preview's stand-ins).
# Design 1 = a slider dropped from the row, as a choice's dropdown is.
# Usage (from this folder): ruby slider_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                           python <KR>/Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
TEST = File.join(ARGV[0], "Mods/KantoReloaded/Tools/Tests/overworld_menu_preview.rb")
eval(File.read(TEST, :encoding => "UTF-8").split("#---------------------------------------------------------------- A: ")[0], binding, TEST)

SW = 512; SH = 384
HINT_TOP = SH - Reloaded::Pixel::HINT_H
P2 = Reloaded::Pixel
PF = ::KIF::PixelFont unless defined?(PF)
GOLD_T = Color.new(240, 200, 80)
B_PAD = "p:1"; A_PAD = "p:0"

# the page: two settings rows (stand-ins showing their values as statuses)
OM.register(:mock_music, :name => "Music Volume", :kind => :info, :priority => 1, :status => proc { ["80", :gold] })
OM.register(:mock_se, :name => "Sound Volume", :kind => :info, :priority => 2, :status => proc { ["100", :gold] })
OM.register(:mock_limit, :name => "Speed-Up Limit", :kind => :info, :priority => 3, :status => proc { ["x3", :gold] })
pg = OM.add_page("Sound")
pg["entries"] = ["mock_music", "mock_se", "mock_limit", "quick_save"]
OM.save_layout
$hints = nil
Reloaded::OverworldMenuScreen.prepend(Module.new { def hint_pairs; $hints || super; end })
Reloaded::Prompts.singleton_class.prepend(Module.new { def style; :xbox; end })

def popup(o, c, x, y, w, h, title = nil)
  Reloaded::Dialogs.send(:panel, o, c, x, y, w, h)
  Reloaded::Dialogs.send(:title_bar, o, c, x, y, w, title) if title
end
def bar(o, c, x0, x1, y, v, min, max)
  P2.ui.rbox(o, x0, y, x1, y + 6, 3, c[:dark], c[:line])
  P2.ui.rbox(o, x0, y, x0 + (x1 - x0) * (v - min) / (max - min), y + 6, 3, c[:selb])
  kx = x0 + (x1 - x0) * (v - min) / (max - min)
  P2.ui.rbox(o, kx - 5, y - 4, kx + 5, y + 10, 3, c[:txt], c[:selb])
end
def shot(name, hints)
  $hints = hints
  om.refresh
  yield(om.send(:overlay), om.send(:palette))
  dump(name)
end
ROW_Y = 60           # the Music Volume row on the page (60 to 86)

DESIGNS = []

# 1 Recommended: a slider dropped from the row (as a choice's dropdown
# drops): the bar, the value, Left and Right by 1, L and R by 10
DESIGNS << ["OW_SL1_dropped_slider", [[:lr, "Change"], [A_PAD, "Set"], [B_PAD, "Cancel"]], proc { |o, c|
  o.clear
  x0 = 10; x1 = 230; y = ROW_Y + 27
  popup(o, c, x0, y, x1 - x0, 54)
  P2.small(o, x0 + 10, y + 6, 40, 16, "0", c[:dim], 0)
  P2.text(o, x0, y + 3, x1 - x0, 20, "65", GOLD_T, PF::ROW, 2)
  P2.small(o, x1 - 50, y + 6, 40, 16, "100", c[:dim], 1)
  bar(o, c, x0 + 14, x1 - 14, y + 34, 65, 0, 100)
}]

# 2: Kanto Reloaded's number popup in the middle (as the Settings screen's
# own numbers open): the name, the value between arrows, the range under it
DESIGNS << ["OW_SL2_number_popup", [[:lr, "Change"], [A_PAD, "Set"], [B_PAD, "Cancel"]], proc { |o, c|
  o.clear
  w = 240; h = 110
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2
  popup(o, c, x, y, w, h, "Music Volume")
  P2.ui.tri(o, x + 60, y + 52, :l, c[:dim], 5)
  P2.text(o, x, y + 46, w, 22, "65", GOLD_T, PF::ROW, 2)
  P2.ui.tri(o, x + w - 70, y + 52, :r, c[:dim], 5)
  P2.small(o, x, y + h - 26, w, 16, "0 to 100. L and R: 10 at a time.", c[:dim], 2)
}]

# 3: in place: A puts the row in change mode (its value between arrows, a
# thin bar under the row); Left and Right change it, A or B leaves
DESIGNS << ["OW_SL3_in_place", [[:lr, "Change"], [A_PAD, "Done"], [B_PAD, "Undo"]], proc { |o, c|
  o.clear
  x0 = 16; x1 = 228
  # the row's own value covered by the change box; a thin bar along its foot
  P2.ui.rbox(o, x1 - 66, ROW_Y + 2, x1, ROW_Y + 22, 5, c[:sel], GOLD_T)
  P2.ui.tri(o, x1 - 60, ROW_Y + 7, :l, GOLD_T, 4)
  P2.text(o, x1 - 52, ROW_Y + 2, 38, 20, "65", GOLD_T, PF::ROW, 2)
  P2.ui.tri(o, x1 - 12, ROW_Y + 7, :r, GOLD_T, 4)
  o.fill_rect(x0, ROW_Y + 23, x1 - x0, 2, c[:dark])
  o.fill_rect(x0, ROW_Y + 23, (x1 - x0) * 65 / 100, 2, GOLD_T)
}]

queue = [at { i = OM.pages.length - 1; OM.page_index = i; om.instance_variable_set(:@page, i); om.instance_variable_set(:@sel, 0); om.refresh }]
DESIGNS.each { |name, hints, painter| queue << at { shot(name, hints, &painter) } }
queue << at { $hints = nil; om.send(:overlay).clear; om.refresh }
queue << I::BACK
on_map("Slider designs", queue)
puts "designs: #{DESIGNS.map(&:first).join(', ')}"
