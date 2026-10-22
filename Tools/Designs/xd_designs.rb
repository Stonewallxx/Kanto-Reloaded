# encoding: utf-8
# Mockups: Expanded Dex (topic 28), part 1: the New Game Switch. Five
# designs, each two screens: choosing the Pokedex at New Game, then the lock
# confirm (or the switch shown locked in an existing save). Classic = PIF's
# 576; Expanded = +522 species (Gen 4-9, HR's bundle), 172 moves, 74
# abilities = 1,098. Sprites from HR's Expanded spritepack (xd/).
# Design 1 = the chosen Difficulty layout (rows beside Oak + What Changes).
# Usage (from this folder): ruby xd_designs.rb "<KIF Beta>" <work dir with metrics.json>
SRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "diff_designs.rb"), :encoding => "UTF-8")
eval(SRC.split("c = palette(2)\n")[0], binding, "diff_designs.rb")

XD = File.join(HERE, "xd")
NEW = ["SPRIGATITO", "FUECOCO", "QUAXLY", "ROWLET", "LITTEN", "POPPLIO", "SNIVY", "DREEPY", "TOXEL", "GLAMEOW", "SHELLOS", "STUNKY"]
CHANGES = ["522 Pokémon from Gen 4 to 9", "172 new moves, 74 abilities", "In the wild and the Randomizer", "Fuses like any Pokémon", "Can't be turned off later"]
def xicon(b, sp, cx, cy, size)
  b.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), bmp(File.join(XD, sp + "_icon.png")), Rect.new(0, 0, 64, 64))
end
def xspr(b, sp, cx, cy, size)
  b.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), bmp(File.join(XD, sp + ".png")), Rect.new(0, 0, 96, 96))
end
def lock_confirm(c)
  confirm(c, "Turn On Expanded Dex?", ["522 more Pokémon join this save.", "It can't be turned off later, because", "they'll be in your boxes and Pokédex."], "Turn On", "Back")
end
BLUE2 = Color.new(130, 190, 250)

c = palette(2)

#================================================================ XD1 Recommended: rows beside Oak with What Changes (like Difficulty)
def xd1(c)
  intro(c)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 252, 24, 500, 330, 8, col(c[:panel], 245), c[:line])
  P.text(t, 252, 30, 248, 24, "Choose a Pokédex", c[:title], PF::ROW, 2)
  [["Classic", "576"], ["Expanded", "1,098"]].each_with_index do |(n, cnt), i|
    y = 62 + i * 30
    cursor_at(258, y, 236, 28) if i == 1
    P.text(t, 270, y + 2, 140, 24, n, c[:txt], PF::ROW)
    P.small(t, 400, y + 6, 88, 16, cnt, c[:dim], 1)
  end
  b.fill_rect(262, 126, 228, 1, c[:line])
  P.text(t, 266, 132, 200, 12, "WHAT CHANGES", c[:head], PF::TINY)
  CHANGES.each_with_index { |s, i| bullet(b, t, c, 268, 148 + i * 18, 224, s, i == 4 ? AMBER : BLUE2) }
  NEW.first(6).each_with_index { |sp, k| xicon(t, sp, 280 + k * 36, 262, 36) }
  P.small(t, 262, 290, 232, 16, "Sprites: Expanded spritepack.", c[:dim], 2)
  hints(c, [[:ud, "Choose"], [A_BTN, "Start"], [B_BTN, "Back"]])
end
xd1(c); shot("XD1_new")
xd1(c); lock_confirm(c); shot("XD1_confirm")

#================================================================ XD2: two big cards with sample sprites
def xd2(c)
  intro(c)
  b = BASE.bitmap; t = TOP.bitmap
  P.text(t, 0, 8, W, 24, "Which Pokémon will you meet?", Color.new(30, 50, 60), PF::ROW, 2)
  [["Classic", "576 Pokémon", ["PIKACHU", "GENGAR", "LAPRAS"], false], ["Expanded", "1,098 Pokémon", ["SPRIGATITO", "FUECOCO", "QUAXLY"], true]].each_with_index do |(n, cnt, sps, xp), i|
    x = 20 + i * 240; sel = i == 1
    UI.rbox(b, x, 40, x + 232, 320, 10, col(c[:panel], 255), sel ? GOLD : c[:line])
    P.text(t, x, 48, 232, 24, n, sel ? GOLD : c[:txt], PF::ROW, 2)
    P.small(t, x, 72, 232, 16, cnt, c[:dim], 2)
    sps.each_with_index do |sp, k|
      xp ? xspr(t, sp, x + 40 + k * 76, 140, 76) : t.stretch_blt(Rect.new(x + 2 + k * 76, 102, 76, 76), bmp(File.join(GFX, "CustomBattlers/spritesheets/spritesheets_base/#{{"PIKACHU" => 25, "GENGAR" => 94, "LAPRAS" => 131}[sp]}.png")), Rect.new(0, 0, 96, 96))
    end
    lines = xp ? ["Gen 4 to 9 join Kanto", "172 moves, 74 abilities", "Locked for this save"] : ["PIF's Pokémon", "The most custom fusion art"]
    lines.each_with_index { |s, k| bullet(b, t, c, x + 14, 196 + k * 22, 206, s, xp && k == 2 ? AMBER : BLUE2) }
  end
  hints(c, [[:lr, "Choose"], [A_BTN, "Start"], [B_BTN, "Back"]])
end
xd2(c); shot("XD2_new")
xd2(c); lock_confirm(c); shot("XD2_confirm")

#================================================================ XD3: one New Game summary page (every run setting) before starting
RUNSET = [["Difficulty", "Normal"], ["Pokédex", "Expanded"], ["Randomizer", "Off"], ["Nuzlocke", "Off"], ["IV Boundaries", "Vanilla"]]
def xd3(c, sel)
  intro(c)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 192, 16, 500, 340, 8, col(c[:panel], 245), c[:line])
  P.text(t, 192, 22, 308, 24, "Your New Game", c[:title], PF::ROW, 2)
  RUNSET.each_with_index do |(l, v), i|
    y = 54 + i * 28
    cursor_at(198, y, 296, 26) if i == sel
    P.text(t, 210, y + 1, 160, 24, l, c[:opt], PF::ROW)
    value_cell(t, c, 440, y + 1, v, i == sel)
  end
  b.fill_rect(202, 200, 288, 1, c[:line])
  P.text(t, 206, 206, 200, 12, "EXPANDED", c[:head], PF::TINY)
  P.small_wrap(t, "522 more Pokémon from Gen 4 to 9, in the wild and the Randomizer. Locked once you start.", 280).first(3).each_with_index { |ln, k| P.small(t, 206, 222 + k * 17, 284, 17, ln, c[:txt]) }
  NEW.first(7).each_with_index { |sp, k| xicon(t, sp, 222 + k * 38, 302, 36) }
  hints(c, [[:ud, "Choose"], [:lr, "Change"], [A_BTN, "Start"], [B_BTN, "Back"]])
end
xd3(c, 1); shot("XD3_new")
xd3(c, 1); lock_confirm(c); shot("XD3_confirm")

#================================================================ XD4: Oak asks (a message box with a sample strip)
def xd4(c)
  intro(c)
  b = BASE.bitmap; t = TOP.bitmap
  UI.rbox(b, 12, 40, 500, 150, 10, col(c[:panel], 240), GOLD)
  P.text(t, 12, 46, 488, 22, "Pokémon From Far Away", GOLD, PF::ROW, 2)
  NEW.each_with_index { |sp, k| xicon(t, sp, 38 + k * 40, 100, 40) }
  P.small(t, 12, 126, 488, 16, "522 Pokémon from other regions. Locked once you start.", c[:dim], 2)
  UI.rbox(b, 8, 290, W - 8, 354, 8, col(c[:panel], 250), c[:line])
  P.text(t, 22, 296, W - 44, 24, "OAK: Some Pokémon from far away", c[:txt], PF::ROW)
  P.text(t, 22, 322, W - 44, 24, "have come to Kanto. Want to meet them?", c[:txt], PF::ROW)
  UI.rbox(b, 380, 210, 500, 280, 8, col(c[:panel], 250), c[:line])
  [["Yes", true], ["No", false]].each_with_index do |(l, on), k|
    y = 216 + k * 30
    cursor_at(386, y, 108, 28) if on
    P.text(t, 400, y + 2, 80, 24, l, c[:txt], PF::ROW)
  end
end
xd4(c); shot("XD4_new")
xd4(c); lock_confirm(c); shot("XD4_confirm")

#================================================================ XD5: a Kanto Reloaded setting, New Game only (locked in a running save)
def xd5(c, locked)
  frame(c); clear_over
  MAPS.bitmap = Bitmap.new(W, H)
  settings_frame(c, SECTIONS, 0)
  b = BASE.bitmap; t = TOP.bitmap
  P.heading(t, 190, W - 16, 43, "Pokémon", c[:head], c[:line])
  cursor_at(184, 58, W - 194, 24)
  P.text(t, 196, 58, 200, 24, "Expanded Dex", locked ? c[:dim] : c[:opt], PF::ROW)
  if locked
    P.text(t, W - 110, 58, 90, 24, "Off", c[:dim], PF::TEXT, 1)
    P.pill(t, W - 18, 87, "SET AT NEW GAME", Color.new(40, 48, 62), c[:dim], true)
  else
    value_cell(t, c, W - 60, 58, "On", true)
  end
  [["Expanded in Wild", "On"], ["Expanded in Randomizer", "On"]].each_with_index do |(l, v), i|
    P.text(t, 196, 110 + i * 24, 220, 24, l, locked ? c[:dim] : c[:opt], PF::ROW)
    locked ? P.text(t, W - 110, 110 + i * 24, 90, 24, "-", c[:dim], PF::TEXT, 1) : value_cell(t, c, W - 60, 110 + i * 24, v, false)
  end
  P.text(t, 14, 269, 300, 26, "Expanded Dex", c[:head], PF::ROW)
  txt = locked ? "This save started without Expanded Dex. Start a new game to turn it on." : "Only at New Game: 522 more Pokémon. Locked once the game starts."
  P.small_wrap(t, txt, W - 160).first(3).each_with_index { |ln, k| P.small(t, 14, 297 + k * 17, W - 160, 17, ln, c[:txt]) }
  NEW.first(3).each_with_index { |sp, k| xicon(t, sp, W - 120 + k * 40, 310, 40) }
  hints(c, [[:ud, "Select"], [:lr, "Change"], [B_BTN, "Sections"]])
end
xd5(c, false); shot("XD5_new")
xd5(c, true); shot("XD5_locked")
