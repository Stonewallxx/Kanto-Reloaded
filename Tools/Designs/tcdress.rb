# encoding: utf-8
# Mockups: Trainer Card Style tab, three Dressing Room versions (he picked
# Style design 5). Each shows how many of each group you've unlocked:
# Backgrounds 13/110, Plate Colors 3/8, Titles 4/20, Showcase Frames 1/6,
# Badge Cases 1/3; plus Showcase (edit) and Run Tags (Show / Hide), and PIF's
# Glimmer Coins. Locked style: glass white, PIF colours, shadows (not on tags,
# badges, hints or the ID), Title Case.
# Usage (from this folder): ruby tcdress.rb "<KIF Beta>" <work dir with metrics.json>
SRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "tcstyle.rb"), :encoding => "UTF-8")
eval(SRC.split("c = palette(2)\n")[0], binding, "tcstyle.rb")

# [name, icon, unlocked, total or nil]
GROUPS = [["Backgrounds", "TOWNMAP", 13, 110], ["Plate Colors", "SHINYCHARM", 3, 8], ["Titles", "AMULETCOIN", 4, 20],
          ["Showcase", "POKEBALL", 3, nil], ["Showcase Frames", "OVALCHARM", 1, 6], ["Badge Cases", "EXPSHARE", 1, 3], ["Run Tags", "LINKINGCORD", nil, nil]]
def count_text(g); g[3] ? "#{g[2]}/#{g[3]}" : (g[0] == "Showcase" ? "Edit" : "Show"); end
def preview_panel(b, t, x, y, w)
  glass(b, x, y, w, 168, 10)
  stx(t, x, y + 6, w, 12, "BACKGROUNDS", BLACK, PF::TINY, 2)
  tw = w - 24; th = tw * 3 / 4
  thumb(t, "BLUE", x + 12, y + 22, tw, th)
  picker(t, x + w / 2, y + 26 + th, "Blue", BLACK, PF::TEXT)
  ssm(t, x, y + 48 + th, w, 16, "13 of 110 Unlocked", BLACK, 2)
end
def coins(b, t, x, y, w)
  glass(b, x, y, w, 44, 10)
  stx(t, x, y + 5, w, 12, "GLIMMER COINS", BLACK, PF::TINY, 2)
  stx(t, x, y + 18, w, 22, "1,250", pif("Purple"), PF::ROW, 2)
end
HD = [[:ud, "Group"], [:lr, "Change"], [A_BTN, "Keep"], [B_BTN, "Close"]]

c = palette(2)

#================================================================ TD1 Icon Strip with counts: each icon carries its count
base(c)
b = BASE.bitmap; t = TOP.bitmap
tabs_on(b, t, 236, 26, 3)
glass(b, 36, 48, 64, 300, 10)
GROUPS.each_with_index do |g, i|
  y = 54 + i * 41
  UI.rbox(b, 42, y, 94, y + 38, 8, i == 0 ? Color.new(40, 96, 176, 220) : Color.new(255, 255, 255, 120))
  icon(t, g[1], 68, y + 13, 20)
  P.text(t, 42, y + 25, 52, 12, count_text(g), i == 0 ? Color.new(255, 255, 255) : BLACK, PF::TINY, 2)
end
red(t, 214, 276, 170)
SHOW.each_with_index { |sp, i| glass(b, 134 + i * 56, 282, 50, 44, 10); mon(t, sp, 159 + i * 56, 304, 42) }
preview_panel(b, t, 314, 48, 172)
coins(b, t, 314, 226, 172)
hints(c, HD)
shot("TD1")

#================================================================ TD2 Named List: icon, name and count down the left
base(c)
b = BASE.bitmap; t = TOP.bitmap
tabs_on(b, t, 236, 26, 3)
glass(b, 36, 48, 168, 300, 10)
stx(t, 46, 54, 150, 12, "STYLE", BLACK, PF::TINY)
GROUPS.each_with_index do |g, i|
  y = 70 + i * 38
  UI.rbox(b, 42, y, 198, y + 34, 8, Color.new(40, 96, 176, 220)) if i == 0
  icon(t, g[1], 60, y + 17, 20)
  col_t = i == 0 ? Color.new(255, 255, 255) : BLACK
  i == 0 ? P.small(t, 76, y + 3, 120, 16, g[0], col_t) : ssm(t, 76, y + 3, 120, 16, g[0], col_t)
  P.text(t, 150, y + 19, 44, 12, count_text(g), col_t, PF::TINY, 1)
  if g[3]
    b.fill_rect(76, y + 23, 70, 4, Color.new(255, 255, 255, 140)); b.fill_rect(76, y + 23, [(70 * g[2] / g[3].to_f).round, 2].max, 4, i == 0 ? Color.new(255, 255, 255) : pif("Blue"))
  end
end
red(t, 262, 296, 140)
SHOW.each_with_index { |sp, i| mon(t, sp, 222 + i * 40, 316, 36) }
preview_panel(b, t, 318, 48, 168)
coins(b, t, 318, 226, 168)
hints(c, HD)
shot("TD2")

#================================================================ TD3 Bottom Shelf: the groups as a shelf along the bottom
base(c)
b = BASE.bitmap; t = TOP.bitmap
tabs_on(b, t, 236, 26, 3)
coins(b, t, 36, 48, 140)
red(t, 200, 250, 170)
SHOW.each_with_index { |sp, i| glass(b, 108 + i * 34, 220, 30, 30, 8); mon(t, sp, 123 + i * 34, 235, 28) } if false
preview_panel(b, t, 300, 48, 186)
glass(b, 36, 262, 450, 86, 10)
GROUPS.each_with_index do |g, i|
  x = 42 + i * 63
  UI.rbox(b, x, 268, x + 60, 342, 8, i == 0 ? Color.new(40, 96, 176, 220) : Color.new(255, 255, 255, 120))
  icon(t, g[1], x + 30, 286, 22)
  P.text(t, x, 302, 60, 12, g[0].upcase.sub("SHOWCASE FRAMES", "FRAMES").sub("PLATE COLORS", "PLATES").sub("BADGE CASES", "CASES").sub("BACKGROUNDS", "BACKS"), i == 0 ? Color.new(255, 255, 255) : BLACK, PF::TINY, 2) if false
  stx(t, x, 304, 60, 20, count_text(g), i == 0 ? Color.new(255, 255, 255) : BLACK, PF::TEXT, 2) if i != 0
  P.text(t, x, 304, 60, 20, count_text(g), Color.new(255, 255, 255), PF::TEXT, 2) if i == 0
end
ssm(t, 36, 246, 250, 16, "Backgrounds", BLACK, 0) if false
hints(c, [[:lr, "Group"], [:ud, "Change"], [A_BTN, "Keep"], [B_BTN, "Close"]])
shot("TD3")
