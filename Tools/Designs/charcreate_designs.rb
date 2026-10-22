# encoding: utf-8
# Mockups: New Game Setup, part 3: Character Creation. Five designs, each two
# screens: PIF's choices (Name, Gender, Age 10-17, Skin Type A-F, Hair:
# Blonde / Light Brown / Dark Brown / Black) with a preview, then typing the
# name (typed straight into the field like cody's search; A opens PIF's
# naming screen on a controller).
# Design 1 = PIF's Trainer Application Form (Photo ID beside the fields),
# rebuilt in our kit.
# Usage (from this folder): ruby charcreate_designs.rb "<KIF Beta>" <work dir with metrics.json>
NMSRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "ngmode_designs.rb"), :encoding => "UTF-8")
eval(NMSRC.split("c = palette(2)\n")[0], binding, "ngmode_designs.rb")

CLEAR = Color.new(0, 0, 0, 0) unless defined?(CLEAR)
FIELDS = [["Name", "Red"], ["Gender", "Male"], ["Age", "14"], ["Skin", "Type A"], ["Hair", "Dark Brown"]]
SKINS = [[255, 224, 196], [240, 200, 160], [220, 170, 130], [190, 140, 100], [150, 105, 75], [110, 75, 55]]
HAIRS = [[240, 210, 120], [170, 120, 80], [110, 70, 40], [40, 36, 40]]
def trainer(b, cx, by, size, back = false)
  f = File.join(GFX, "Trainers", "POKEMONTRAINER_Red#{back ? '_back' : ''}.png")
  b.stretch_blt(Rect.new(cx - size / 2, by - size, size, size), bmp(f), Rect.new(0, 0, 160, 160))
end
def swatch(b, x, y, rgb, sel, c)
  UI.rbox(b, x, y, x + 18, y + 18, 5, Color.new(*rgb), sel ? c[:white] : Color.new(20, 22, 30))
  UI.rbox(b, x - 2, y - 2, x + 20, y + 20, 6, CLEAR, c[:selb]) if sel
end
def field_row(c, b, t, x, y, w, l, v, sel, editing = false)
  cursor_at(x, y, w, 30) if sel && !editing
  P.text(t, x + 12, y + 3, 90, 24, l, c[:opt], PF::ROW)
  if l == "Name"
    UI.rbox(b, x + 104, y + 3, x + w - 10, y + 27, 5, c[:dark], editing ? c[:selb] : c[:line])
    P.text(t, x + 112, y + 3, w - 130, 24, v, c[:white], PF::ROW)
    t.fill_rect(x + 112 + P.width(PF::ROW, v) + 2, y + 7, 2, 18, c[:white]) if editing
  else
    value_cell(t, c, x + w - 70, y + 3, v, sel)
  end
end
H_CC = [[:ud, "Choose"], [:lr, "Change"], [A_BTN, "Edit"], [Y_BTN, "Done"], [B_BTN, "Back"]]
H_NAME = [["Type", ""], [A_BTN, "Naming Screen"], [Y_BTN, "Done"], [B_BTN, "Back"]]

c = palette(2)

#================================================================ CC1 Recommended: PIF's Trainer Application Form, rebuilt
def cc1(c, editing)
  frame(c); clear_over
  MAPS.bitmap = Bitmap.new(W, H)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, 34, c[:panel2]); b.fill_rect(0, 33, W, 1, c[:line])
  P.poke_ball(t, 12, 9, 15); P.poke_ball(t, W - 27, 9, 15)
  P.text(t, 0, 3, W, 28, "Trainer Application Form", c[:title], PF::TITLE, 2)
  UI.rbox(b, 8, 42, 300, 300, 8, c[:panel], c[:line])
  FIELDS.each_with_index { |(l, v), i| field_row(c, b, t, 14, 52 + i * 40, 280, l, v, editing ? i == 0 : i == 4, editing) }
  HAIRS.each_with_index { |rgb, k| swatch(b, 128 + k * 26, 260, rgb, k == 2, c) }
  UI.rbox(b, 310, 42, 504, 300, 8, c[:panel], c[:line])
  P.text(t, 310, 46, 194, 16, "PHOTO ID", c[:head], PF::TINY, 2)
  UI.rbox(b, 330, 66, 484, 250, 8, Color.new(230, 236, 244), c[:line])
  trainer(t, 407, 246, 176)
  P.text(t, 310, 258, 194, 24, "Red, 14", c[:txt], PF::ROW, 2)
  UI.rbox(b, 310, 308, 504, 340, 8, c[:sel], c[:selb]); P.text(t, 310, 311, 194, 26, "Confirm", c[:white], PF::ROW, 2)
  hints(c, editing ? H_NAME : H_CC)
end
cc1(c, false); shot("CC1_form")
cc1(c, true); shot("CC1_name")

#================================================================ CC2: a big preview in the middle, choices around it
def cc2(c, editing)
  intro(c)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, H, Color.new(10, 14, 24, 170))
  P.text(t, 0, 6, W, 24, "Who Are You?", c[:title], PF::ROW, 2)
  UI.rbox(b, 166, 40, 346, 300, 12, c[:panel], GOLD)
  trainer(t, 256, 290, 220)
  [["Name", "Red", 8, 50], ["Gender", "Male", 8, 130], ["Age", "14", 8, 210], ["Skin", "Type A", 354, 50], ["Hair", "Dark Brown", 354, 130]].each_with_index do |(l, v, x, y), i|
    UI.rbox(b, x, y, x + 150, y + 70, 8, c[:panel], (editing ? i == 0 : i == 4) ? c[:selb] : c[:line])
    P.small(t, x + 10, y + 6, 130, 16, l, c[:dim])
    P.text(t, x + 10, y + 26, 130, 26, v, c[:txt], PF::ROW)
    t.fill_rect(x + 12 + P.width(PF::ROW, v), y + 30, 2, 20, c[:white]) if editing && i == 0
  end
  SKINS.each_with_index { |rgb, k| swatch(b, 362 + k * 22, 226, rgb, k == 0, c) }
  UI.rbox(b, 354, 258, 504, 300, 8, c[:sel], c[:selb]); P.text(t, 354, 266, 150, 26, "Confirm", c[:white], PF::ROW, 2)
  hints(c, editing ? H_NAME : [[:ud, ""], [:lr, "Choose"], [A_BTN, "Change"], [B_BTN, "Back"]])
end
cc2(c, false); shot("CC2_form")
cc2(c, true); shot("CC2_name")

#================================================================ CC3: beside Oak, like the Run Setup (rows + preview in the details)
def cc3(c, editing)
  intro(c)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 196, 8, 504, 350, 8, col(c[:panel], 245), c[:line])
  P.text(t, 196, 12, 308, 24, "About You", c[:title], PF::ROW, 2)
  FIELDS.each_with_index { |(l, v), i| field_row(c, b, t, 200, 42 + i * 34, 300, l, v, editing ? i == 0 : i == 1, editing) }
  b.fill_rect(206, 216, 288, 1, c[:line])
  UI.rbox(b, 290, 222, 410, 344, 8, Color.new(230, 236, 244), c[:line])
  trainer(t, 350, 342, 120)
  hints(c, editing ? H_NAME : H_CC)
end
cc3(c, false); shot("CC3_form")
cc3(c, true); shot("CC3_name")

#================================================================ CC4: the Trainer Card being filled in (the Lanyard ID front)
def cc4(c, editing)
  frame(c); clear_over
  MAPS.bitmap = Bitmap.new(W, H)
  b = BASE.bitmap; t = TOP.bitmap
  b.fill_rect(0, 0, W, H, Color.new(40, 90, 150))
  UI.rbox(b, 40, 30, 472, 300, 14, Color.new(235, 240, 248), Color.new(255, 255, 255))
  b.fill_rect(40, 30, 432, 40, Color.new(200, 60, 60)); UI.rbox(b, 40, 30, 472, 70, 14, Color.new(200, 60, 60))
  P.text(t, 40, 38, 432, 26, "TRAINER CARD", Color.new(255, 255, 255), PF::ROW, 2)
  UI.rbox(b, 60, 86, 190, 270, 8, Color.new(210, 220, 236), Color.new(150, 160, 180))
  trainer(t, 125, 268, 150)
  FIELDS.each_with_index do |(l, v), i|
    y = 88 + i * 36
    sel = editing ? i == 0 : i == 3
    UI.rbox(b, 204, y, 456, y + 30, 6, sel ? Color.new(200, 220, 250) : Color.new(225, 230, 240), sel ? Color.new(40, 110, 200) : Color.new(190, 196, 210))
    P.text(t, 214, y + 3, 90, 24, l, Color.new(60, 70, 90), PF::ROW)
    P.text(t, 300, y + 3, 150, 24, v, Color.new(20, 24, 32), PF::ROW)
    t.fill_rect(302 + P.width(PF::ROW, v), y + 7, 2, 18, Color.new(20, 24, 32)) if editing && i == 0
  end
  P.small(t, 204, 276, 252, 16, "IDNo. 04821", Color.new(60, 70, 90), 2)
  hints(c, editing ? H_NAME : H_CC)
end
cc4(c, false); shot("CC4_form")
cc4(c, true); shot("CC4_name")

#================================================================ CC5: the KIF Settings layout (sections Look / About) with a preview in the description
def cc5(c, editing)
  frame(c); clear_over
  MAPS.bitmap = Bitmap.new(W, H)
  b = BASE.bitmap; t = TOP.bitmap
  settings_frame(c, [["About You", [240, 200, 70]], ["Look", [130, 190, 250]]], 0)
  t.fill_rect(130, 2, 252, 28, CLEAR); P.text(t, 130, 2, 252, 28, "New Trainer", c[:title], PF::TITLE, 2)
  FIELDS.each_with_index do |(l, v), i|
    y = 40 + i * 30
    field_row(c, b, t, 184, y, W - 194, l, v, editing ? i == 0 : i == 2, editing)
  end
  UI.rbox(t, 380, 272, 460, 352, 6, Color.new(230, 236, 244))
  trainer(t, 420, 350, 80)
  P.text(t, 14, 269, 330, 26, editing ? "Name" : "Age", c[:head], PF::ROW)
  P.small(t, 14, 297, 350, 16, editing ? "Type your name, or A for the naming screen." : "10 to 17. Shown on your Trainer Card.", c[:txt])
  hints(c, editing ? H_NAME : H_CC)
end
cc5(c, false); shot("CC5_form")
cc5(c, true); shot("CC5_name")
