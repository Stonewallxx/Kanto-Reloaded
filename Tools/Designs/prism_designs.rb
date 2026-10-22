# encoding: utf-8
# Mockups: Shinies (topic 26), part 1: Shiny Prism and Convert. Five designs,
# each two screens: using a Shiny Prism on a shiny Lapras (its Reloaded
# palette, a new Wild one after), and the result. HR: a Prism rerolls a
# part's palette (fusions pick Body, Head or Both = 2 Prisms); PC actions
# Convert Shiny (to Reloaded) and Convert to Default (PIF's own shiny).
# Palettes are stand-ins (sh/palettes.py) for HR's recolours.
# Design 1 = HR's flow (Bag > party > confirm, then the result), in our kit.
# Usage (from this folder): ruby prism_designs.rb "<KIF Beta>" <work dir with metrics.json>
SRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "qa_designs.rb"), :encoding => "UTF-8")
eval(SRC.split("c = palette(2)\n")[0], binding, "qa_designs.rb")

SH = File.join(HERE, "sh")
OVER = layer(3); DIMMER = layer(2); DIMMER.z = 3; OVER.z = 4
GOLD = Color.new(240, 200, 70); WILDC = Color.new(240, 140, 200); RELC = Color.new(130, 190, 250); DEFC = Color.new(200, 200, 210)
CLEAR = Color.new(0, 0, 0, 0); WHITE = Color.new(255, 255, 255)
X_BTN = "p:2"; Y_BTN = "p:3"
def clear_over; OVER.bitmap.clear; DIMMER.bitmap.clear; end
def bg(c, name); frame(c, false); clear_over; MAPS.bitmap = Bitmap.new(File.join(SH, name)); end
def blank(c); frame(c); clear_over; MAPS.bitmap = Bitmap.new(W, H); end
def spr(b, name, cx, cy, size)
  b.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), bmp(File.join(SH, name + ".png")), Rect.new(0, 0, 96, 96))
end
def icon(b, name, cx, cy, size)
  b.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), bmp(File.join(SH, name + "_icon.png")), Rect.new(0, 0, 64, 64))
end
def item(b, id, cx, cy, size)
  i = bmp(id == "SHINYPRISM" ? File.join(SH, "SHINYPRISM.png") : File.join(GFX, "Items", id + ".png"))
  b.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), i, Rect.new(0, 0, i.width, i.height))
end
def sparkle(b, cx, cy, r, color)
  b.fill_rect(cx - r, cy, 2 * r + 1, 1, color); b.fill_rect(cx, cy - r, 1, 2 * r + 1, color)
  b.fill_rect(cx - r / 2, cy - 1, r + 1, 3, color); b.fill_rect(cx - 1, cy - r / 2, 3, r + 1, color)
end
def burst(b, cx, cy, spread)
  [[-1.0, -0.6, 6], [-0.4, -1.0, 4], [0.3, -1.0, 7], [0.9, -0.5, 5], [1.0, 0.4, 4], [-0.9, 0.5, 4]].each do |fx, fy, r|
    x = (cx + fx * spread).round; y = (cy + fy * spread).round
    sparkle(b, x, y, r, Color.new(255, 236, 140)); sparkle(b, x, y, r / 2, WHITE)
  end
end
def style_pill(t, x, y, style, right = false)
  colr = { "RELOADED" => RELC, "WILD" => WILDC, "DEFAULT" => DEFC }[style]
  P.pill(t, x, y, style, Color.new(colr.red / 4, colr.green / 4, colr.blue / 4), colr, right)
end
def arrow(b, x, y, color); b.fill_rect(x, y + 4, 14, 3, color); UI.tri(b, x + 14, y, :r, color, 5); end
# A palette as six swatches sampled from the sprite's main colours
SWATCH = { "LAPRAS_rel" => [[60, 200, 90], [40, 150, 70], [230, 120, 200], [220, 220, 210], [150, 150, 140], [90, 90, 96]],
           "LAPRAS_wild" => [[240, 190, 40], [200, 140, 20], [60, 160, 230], [220, 220, 210], [150, 150, 140], [90, 90, 96]],
           "LAPRAS_pif" => [[150, 90, 230], [110, 60, 190], [230, 200, 120], [220, 220, 210], [150, 150, 140], [90, 90, 96]] }
def swatches(b, x, y, key, s = 12)
  SWATCH[key].each_with_index { |(r, g, bl), k| UI.rbox(b, x + k * (s + 3), y, x + k * (s + 3) + s, y + s, 3, Color.new(r, g, bl), Color.new(20, 22, 30)) }
end
def two_buttons(c, d, t, x, y, w, a, b2)
  [[a, true, x], [b2, false, x + w / 2 + 4]].each do |lbl, on, bx|
    UI.rbox(d, bx, y, bx + w / 2 - 4, y + 26, 6, on ? c[:sel] : c[:dark], on ? c[:selb] : c[:line])
    P.text(t, bx, y + 2, w / 2 - 4, 22, lbl, on ? c[:white] : c[:txt], PF::TEXT, 2)
  end
end
def dim; DIMMER.bitmap.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 130)); end
def shot(name); dump_as(name); end

c = palette(2)

#================================================================ PR1 Recommended: HR's flow, rebuilt (Bag > party > confirm > result)
bg(c, "party_plain_s.png"); dim
d = DIMMER.bitmap; t = OVER.bitmap
UI.rbox(d, 96, 60, 416, 300, 8, col(c[:panel], 255), c[:selb])
P.text(t, 96, 66, 320, 22, "Use a Shiny Prism?", c[:title], PF::ROW, 2)
d.fill_rect(106, 92, 300, 1, c[:line])
spr(t, "LAPRAS_rel", 196, 150, 96)
P.text(t, 252, 108, 140, 22, "Lapras", c[:txt], PF::TEXT)
style_pill(t, 252, 132, "RELOADED")
swatches(d, 252, 156, "LAPRAS_rel")
P.small(t, 96, 206, 320, 16, "Rolls a new palette. The old one is lost.", c[:dim], 2)
item(t, "SHINYPRISM", 220, 236, 20); P.small(t, 234, 228, 120, 16, "Prisms: 3", c[:txt])
two_buttons(c, d, t, 132, 260, 248, "Use", "Cancel")
shot("PR1_confirm")
bg(c, "party_plain_w.png"); dim
d = DIMMER.bitmap; t = OVER.bitmap
UI.rbox(d, 96, 60, 416, 300, 8, col(c[:panel], 255), GOLD)
P.text(t, 96, 66, 320, 22, "New Colors!", GOLD, PF::ROW, 2)
spr(t, "LAPRAS_rel", 170, 150, 80); arrow(d, 244, 146, c[:dim])
spr(t, "LAPRAS_wild", 330, 150, 96); burst(t, 330, 150, 52)
style_pill(t, 170 - 34, 196, "RELOADED"); style_pill(t, 330 - 20, 206, "WILD")
swatches(d, 122, 232, "LAPRAS_rel", 10); swatches(d, 282, 232, "LAPRAS_wild", 10)
two_buttons(c, d, t, 136, 262, 240, "OK", "Use Another")
shot("PR1_result")

#================================================================ PR2: a Shiny Studio page (normal, PIF's shiny, this one; actions)
def studio(c, after)
  blank(c); b = BASE.bitmap; t = TOP.bitmap
  P.text(t, 0, 4, W, 24, "Shiny Studio", c[:title], PF::ROW, 2)
  P.small(t, 10, 8, 120, 16, "Lapras, Lv. 32", c[:dim])
  UI.rbox(b, 8, 34, 282, 300, 8, c[:panel], c[:line])
  [["LAPRAS_base", "Normal"], ["LAPRAS_pif", "PIF's Shiny"]].each_with_index do |(s, l), k|
    y = 44 + k * 126
    UI.rbox(b, 18, y, 98, y + 116, 6, c[:dark], c[:line])
    spr(t, s, 58, y + 48, 64); P.small(t, 18, y + 94, 80, 16, l, c[:dim], 2)
  end
  cur = after ? "LAPRAS_wild" : "LAPRAS_rel"
  UI.rbox(b, 106, 44, 274, 290, 6, c[:dark], after ? GOLD : c[:selb])
  spr(t, cur, 190, 150, 150)
  burst(t, 190, 150, 76) if after
  style_pill(t, 190 - (after ? 20 : 34), 236, after ? "WILD" : "RELOADED")
  swatches(b, 145, 260, cur)
  UI.rbox(b, 290, 34, 504, 300, 8, c[:panel], c[:line])
  P.heading(t, 300, 494, 40, "Actions", c[:head], c[:line])
  [["SHINYPRISM", "Use Shiny Prism", "3 Left"], ["MOONSTONE", "Convert to Default", "PIF's Shiny"], ["DAWNSTONE", "Convert Shiny", "To Reloaded"]].each_with_index do |(ic, l, s), k|
    y = 58 + k * 44
    cursor_at(294, y, 206, 42) if k == 0 && !after
    item(t, ic, 310, y + 20, 22)
    P.text(t, 326, y + 1, 174, 22, l, c[:txt], PF::TEXT); P.small(t, 326, y + 22, 174, 16, s, c[:dim])
  end
  P.small(t, 300, 196, 198, 16, after ? "Lapras's colors changed." : "Rolls a new palette.", after ? GOLD : c[:dim])
  P.small(t, 300, 240, 198, 16, "Fusions: Body and Head", c[:dim]); P.small(t, 300, 256, 198, 16, "each have their own.", c[:dim])
end
studio(c, false); hints(c, [[:ud, "Choose"], [A_BTN, "Use"], [B_BTN, "Back"]]); shot("PR2_studio")
studio(c, true); hints(c, [[A_BTN, "Again"], [B_BTN, "Done"]]); shot("PR2_result")

#================================================================ PR3: the palette as swatches (what each colour becomes)
bg(c, "party_plain_s.png"); dim
d = DIMMER.bitmap; t = OVER.bitmap
UI.rbox(d, 56, 50, 456, 316, 8, col(c[:panel], 255), c[:selb])
P.text(t, 56, 56, 400, 22, "Shiny Prism: Lapras", c[:title], PF::ROW, 2)
spr(t, "LAPRAS_rel", 140, 150, 112)
style_pill(t, 140 - 34, 210, "RELOADED")
P.heading(t, 220, 444, 88, "Its Colors", c[:head], c[:line])
labels = ["Body", "Shade", "Fins", "Shell", "Spikes", "Outline"]
SWATCH["LAPRAS_rel"].each_with_index do |(r, g, bl), k|
  y = 104 + k * 22
  UI.rbox(d, 222, y, 246, y + 16, 3, Color.new(r, g, bl), Color.new(20, 22, 30))
  P.small(t, 254, y, 90, 16, labels[k], c[:txt])
  P.small(t, 344, y, 100, 16, k < 3 ? "Changes" : "Stays", k < 3 ? GOLD : c[:dim], 1)
end
item(t, "SHINYPRISM", 120, 252, 20); P.small(t, 134, 244, 100, 16, "Prisms: 3", c[:txt])
two_buttons(c, d, t, 72, 278, 368, "Roll New Colors", "Cancel")
shot("PR3_confirm")
bg(c, "party_plain_w.png"); dim
d = DIMMER.bitmap; t = OVER.bitmap
UI.rbox(d, 56, 50, 456, 316, 8, col(c[:panel], 255), GOLD)
P.text(t, 56, 56, 400, 22, "New Colors!", GOLD, PF::ROW, 2)
spr(t, "LAPRAS_wild", 140, 150, 112); burst(t, 140, 150, 60)
style_pill(t, 140 - 20, 210, "WILD")
P.heading(t, 220, 444, 88, "Before and After", c[:head], c[:line])
SWATCH["LAPRAS_rel"].each_with_index do |(r, g, bl), k|
  y = 104 + k * 22
  r2, g2, b2 = SWATCH["LAPRAS_wild"][k]
  UI.rbox(d, 222, y, 246, y + 16, 3, Color.new(r, g, bl), Color.new(20, 22, 30))
  arrow(d, 256, y + 4, c[:dim])
  UI.rbox(d, 282, y, 306, y + 16, 3, Color.new(r2, g2, b2), Color.new(20, 22, 30))
  P.small(t, 316, y, 90, 16, labels[k], c[:txt])
end
two_buttons(c, d, t, 72, 278, 368, "OK", "Use Another")
shot("PR3_result")

#================================================================ PR4: PIF's own party menu and message (no new windows)
bg(c, "party_cmd_s.png")
shot("PR4_menu")
bg(c, "party_msg_s.png")
t = OVER.bitmap
burst(t, 64, 40, 34)
shot("PR4_result")

#================================================================ PR5: a before / after split on one big sprite
def split_view(c, left, right, title, after)
  blank(c); b = BASE.bitmap; t = TOP.bitmap
  P.text(t, 0, 4, W, 24, title, after ? GOLD : c[:title], PF::ROW, 2)
  UI.rbox(b, 56, 34, 456, 300, 8, c[:panel], after ? GOLD : c[:line])
  tmp = Bitmap.new(240, 240)
  tmp.stretch_blt(Rect.new(0, 0, 240, 240), bmp(File.join(SH, left + ".png")), Rect.new(0, 0, 96, 96))
  tmp2 = Bitmap.new(240, 240)
  tmp2.stretch_blt(Rect.new(0, 0, 240, 240), bmp(File.join(SH, right + ".png")), Rect.new(0, 0, 96, 96))
  t.blt(136, 46, tmp, Rect.new(0, 0, 120, 240))
  t.blt(256, 46, tmp2, Rect.new(120, 0, 120, 240))
  b.fill_rect(255, 44, 2, 244, c[:white])
  UI.rbox(b, 246, 156, 266, 176, 10, c[:white])
  UI.tri(b, 247, 162, :l, c[:bg], 3); UI.tri(b, 259, 162, :r, c[:bg], 3)
  P.small(t, 66, 42, 120, 16, "Now", c[:dim]); P.small(t, 326, 42, 120, 16, "New", GOLD, 1)
  style_pill(t, 66, 274, "RELOADED"); style_pill(t, 446, 274, "WILD", true)
end
split_view(c, "LAPRAS_rel", "LAPRAS_wild", "Shiny Prism: Lapras", false)
hints(c, [[:lr, "Slide"], [A_BTN, "OK"]])
shot("PR5_compare")
blank(c); b = BASE.bitmap; t = TOP.bitmap
P.text(t, 0, 4, W, 24, "New Colors!", GOLD, PF::ROW, 2)
UI.rbox(b, 56, 34, 456, 300, 8, c[:panel], GOLD)
spr(t, "LAPRAS_wild", 256, 160, 220); burst(t, 256, 150, 110)
style_pill(t, 256 - 20, 274, "WILD")
hints(c, [[A_BTN, "OK"]])
shot("PR5_result")
