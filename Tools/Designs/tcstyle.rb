# encoding: utf-8
# Mockups: Trainer Card, the Style tab (five designs), in the locked style.
# Style picks one of each unlockable kind (Background, Plate Color, Title,
# Showcase Frame, Badge Case), edits the Showcase, shows or hides Run Tags, and
# keeps PIF's Glimmer Coins and Clothes / Hats. The card previews every change
# live (Background Preview). Base Blue background, as asked.
# Design 1 = the card's back as the Style menu, like Records and Stats.
# Usage (from this folder): ruby tcstyle.rb "<KIF Beta>" <work dir with metrics.json>
SRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "tcstats.rb"), :encoding => "UTF-8")
eval(SRC.split("c = palette(2)\n")[0], binding, "tcstats.rb")

# [label, value, kind]
STYLE = [["Background", "Blue", :pick], ["Plate Color", "Glass White", :pick], ["Title", "Ace Trainer", :pick],
         ["Showcase", "Edit", :tool], ["Showcase Frame", "Round", :pick], ["Badge Case", "Classic", :pick], ["Run Tags", "Show", :pick]]
INFO = [["Glimmer Coins", "1,250"], ["Clothes / Hats", "12/30"]]
BGS = [["BLUE", "Blue", :owned], ["CHARIZARD", "Charizard", :locked], ["EEVEE_FLOWERS", "Eevee Flowers", :owned], ["BOULDERBADGE", "Boulder Badge", :owned],
       ["CASCADEBADGE", "Cascade Badge", :owned], ["BLASTOISE", "Blastoise", :price], ["BLACK", "Black", :owned], ["BRONZE", "Bronze", :price], ["CACTI", "Cacti", :locked]]
def lock(b, x, y, color)
  UI.rbox(b, x + 2, y, x + 10, y + 7, 3, color); UI.rbox(b, x + 4, y + 2, x + 8, y + 7, 1, Color.new(0, 0, 0, 0))
  UI.rbox(b, x, y + 6, x + 12, y + 15, 2, color)
end
def thumb(t, name, x, y, w, h)
  i = bmp(File.join(GFX, "Pictures/Trainer Card/backgrounds/#{name}.png"))
  t.stretch_blt(Rect.new(x, y, w, h), i, Rect.new(0, 0, 512, 384))
end
def picker(t, cx, y, v, color = BLACK, font = PF::TEXT)
  vw = P.width(font, v)
  stx(t, cx - vw / 2, y, vw + 2, 20, v, color, font)
  UI.tri(t, cx - vw / 2 - 12, y + 6, :l, BLACK, 4); UI.tri(t, cx + vw / 2 + 5, y + 6, :r, BLACK, 4)
end
def edit_pill(b, t, x, y); UI.rbox(b, x - 36, y, x, y + 15, 5, pif("Blue")); P.text(t, x - 36, y, 36, 16, "EDIT", Color.new(255, 255, 255), PF::TINY, 2); end
def style_rows(b, t, x0, w, y0, step, sel)
  STYLE.each_with_index do |(l, v, k), i|
    y = y0 + i * step
    cursor_at(x0 - 6, y - 4, w + 12, step - 2) if i == sel
    stx(t, x0, y + 4, 100, 12, l.upcase, BLACK, PF::TINY)
    if k == :tool
      edit_pill(b, t, x0 + w, y + 2)
    else
      # arrows only on the selected row, like the Settings screen
      right = x0 + w - (i == sel ? 12 : 0)
      ssm(t, right - 120, y + 2, 120, 16, v, BLACK, 1)
      if i == sel
        vw = P.width(PF::TEXT, v) * 9 / 10
        UI.tri(t, right - vw - 14, y + 7, :l, BLACK, 4); UI.tri(t, right + 3, y + 7, :r, BLACK, 4)
      end
    end
  end
end
HST = [[:ud, "Select"], [:lr, "Change"], [A_BTN, "Keep"], [B_BTN, "Close"]]

c = palette(2)

#================================================================ TY1 Recommended: the card's back as the Style menu
base(c)
b = BASE.bitmap; t = TOP.bitmap
tabs_on(b, t, 236, 26, 3)
card_back(b, t, "Style")
style_rows(b, t, 56, 160, 112, 26, 1)
b.fill_rect(56, 296, 160, 1, Color.new(255, 255, 255, 200))
INFO.each_with_index { |(l, v), i| y = 302 + i * 22; stx(t, 56, y + 4, 100, 12, l.upcase, BLACK, PF::TINY); stx(t, 56, y, 160, 20, v, BLACK, PF::TEXT, 1) }
red(t, 380, 236, 150)
glass(b, 284, 244, 192, 80, 10)
stx(t, 284, 250, 192, 12, "PLATE COLOR", BLACK, PF::TINY, 2)
stx(t, 284, 264, 192, 22, "Glass White", BLACK, PF::ROW, 2)
ssm(t, 284, 290, 192, 16, "3 of 8 Unlocked", BLACK, 2)
hints(c, HST)
shot("TY1")

#================================================================ TY2 Live Mini Card: the options, and a small copy of your Front
base(c)
b = BASE.bitmap; t = TOP.bitmap
tabs_on(b, t, 236, 26, 3)
card_back(b, t, "Style")
style_rows(b, t, 56, 160, 112, 26, 1)
b.fill_rect(56, 296, 160, 1, Color.new(255, 255, 255, 200))
INFO.each_with_index { |(l, v), i| y = 302 + i * 22; stx(t, 56, y + 4, 100, 12, l.upcase, BLACK, PF::TINY); stx(t, 56, y, 160, 20, v, BLACK, PF::TEXT, 1) }
# a half-size copy of the Front lanyard card
strap(b, 340, 360, 54, 74); clip(b, 350, 70)
glass(b, 300, 80, 104, 150, 8)
UI.rbox(b, 314, 86, 390, 120, 6, Color.new(255, 255, 255, 110)); red(t, 352, 120, 34)
stx(t, 300, 122, 104, 14, "Red", BLACK, PF::TEXT, 2)
P.text(t, 300, 138, 104, 12, "ACE TRAINER", BLACK, PF::TINY, 2)
4.times { |i| b.fill_rect(310, 154 + i * 12, 84, 6, Color.new(255, 255, 255, 140)) }
8.times { |k| UI.rbox(b, 310 + k * 11, 206, 319 + k * 11, 215, 4, Color.new(255, 255, 255, 120)) }
red(t, 440, 236, 110)
glass(b, 284, 250, 192, 64, 10)
stx(t, 284, 256, 192, 12, "LIVE PREVIEW", BLACK, PF::TINY, 2)
ssm(t, 284, 272, 192, 16, "Changes Show on the Card", BLACK, 2)
ssm(t, 284, 290, 192, 16, "A: Keep · B: Undo", BLACK, 2)
hints(c, HST)
shot("TY2")

#================================================================ TY3 Picker Grid: categories on the card, the choices in a grid beside it
base(c)
b = BASE.bitmap; t = TOP.bitmap
tabs_on(b, t, 236, 26, 3)
card_back(b, t, "Style")
cats = [["Background", "13/110"], ["Plate Color", "3/8"], ["Title", "4/20"], ["Showcase Frame", "1/6"], ["Badge Case", "1/3"], ["Run Tags", "Show"], ["Showcase", "Edit"]]
cats.each_with_index do |(l, v), i|
  y = 112 + i * 26
  UI.rbox(b, 50, y - 3, 222, y + 21, 6, Color.new(40, 96, 176, 200)) if i == 0
  stx(t, 58, y + 1, 120, 20, l, i == 0 ? Color.new(255, 255, 255) : BLACK, PF::TEXT) if i == 0
  stx(t, 58, y + 1, 120, 20, l, BLACK, PF::TEXT) if i != 0
  P.text(t, 56, y + 5, 160, 12, v, i == 0 ? Color.new(255, 255, 255) : BLACK, PF::TINY, 1)
end
glass(b, 240, 62, 244, 260, 10)
stx(t, 252, 68, 200, 12, "BACKGROUNDS", BLACK, PF::TINY)
BGS.each_with_index do |(f, n, st), i|
  x = 250 + (i % 3) * 78; y = 86 + (i / 3) * 76
  cursor_at(x - 3, y - 3, 76, 70) if i == 0
  thumb(t, f, x, y, 70, 52)
  UI.rbox(t, x, y, x + 70, y + 52, 4, Color.new(0, 0, 0, 120)) if st == :locked
  lock(t, x + 29, y + 18, Color.new(255, 255, 255)) if st == :locked
  P.pill(t, x + 70, y + 2, "$2,000", Color.new(40, 96, 176), Color.new(255, 255, 255), true) if st == :price
  stx(t, x - 4, y + 56, 78, 12, n.upcase, BLACK, PF::TINY, 2)
end
hints(c, [[:ud, "Category"], [:lr, "Choose"], [A_BTN, "Keep"], [B_BTN, "Close"]])
shot("TY3")

#================================================================ TY4 Carousel: the options on the card, backgrounds in a strip on the art
base(c)
b = BASE.bitmap; t = TOP.bitmap
tabs_on(b, t, 236, 26, 3)
card_back(b, t, "Style")
style_rows(b, t, 56, 160, 112, 26, 0)
b.fill_rect(56, 296, 160, 1, Color.new(255, 255, 255, 200))
INFO.each_with_index { |(l, v), i| y = 302 + i * 22; stx(t, 56, y + 4, 100, 12, l.upcase, BLACK, PF::TINY); stx(t, 56, y, 160, 20, v, BLACK, PF::TEXT, 1) }
red(t, 370, 200, 120)
glass(b, 240, 214, 244, 112, 10)
stx(t, 252, 220, 200, 12, "BACKGROUND · 13 OF 110 OWNED", BLACK, PF::TINY)
sizes = [[36, 27], [36, 27], [64, 48], [36, 27], [36, 27]]
x = 254
BGS.first(5).each_with_index do |(f, n, st), i|
  w, h = sizes[i]
  y = 262 - h / 2
  thumb(t, f, x, y, w, h)
  UI.rbox(t, x, y, x + w, y + h, 4, Color.new(0, 0, 0, 55)) if i != 2
  lock(t, x + w / 2 - 6, y + h / 2 - 8, Color.new(255, 255, 255)) if st == :locked
  x += w + 5
end
stx(t, 240, 296, 244, 20, "Eevee Flowers", BLACK, PF::TEXT, 2)
hints(c, HST)
shot("TY4")

#================================================================ TY5 Dressing Room: your trainer in the middle, categories down the left
base(c)
b = BASE.bitmap; t = TOP.bitmap
tabs_on(b, t, 236, 26, 3)
glass(b, 36, 56, 52, 280, 10)
icons = [["Background", "TOWNMAP"], ["Plate Color", "SHINYCHARM"], ["Title", "AMULETCOIN"], ["Showcase", "POKEBALL"], ["Showcase Frame", "OVALCHARM"], ["Badge Case", "EXPSHARE"], ["Run Tags", "LINKINGCORD"]]
icons.each_with_index do |(n, ic), i|
  y = 64 + i * 38
  UI.rbox(b, 42, y, 82, y + 34, 8, i == 0 ? Color.new(40, 96, 176, 220) : Color.new(255, 255, 255, 120))
  icon(t, ic, 62, y + 17, 24)
end
red(t, 240, 280, 180)
SHOW.each_with_index { |sp, i| glass(b, 160 + i * 56, 284, 50, 44, 10); mon(t, sp, 185 + i * 56, 306, 42) }
glass(b, 330, 56, 154, 160, 10)
stx(t, 330, 62, 154, 12, "BACKGROUND", BLACK, PF::TINY, 2)
thumb(t, "BLUE", 342, 80, 130, 97)
picker(t, 407, 184, "Blue", BLACK, PF::TEXT)
glass(b, 330, 224, 154, 52, 10)
stx(t, 330, 230, 154, 12, "GLIMMER COINS", BLACK, PF::TINY, 2)
stx(t, 330, 244, 154, 22, "1,250", pif("Purple"), PF::ROW, 2)
hints(c, [[:ud, "Category"], [:lr, "Change"], [A_BTN, "Keep"], [B_BTN, "Close"]])
shot("TY5")
