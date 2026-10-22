# encoding: utf-8
# Mockups: the last two Quality of Life popups.
#   Auto-Repel Reuse: a Super Repel wore off and another was used (4 left),
#   on the map. Three designs.
#   Super Candy, when it's done: the party raised to the level cap (Lv 38),
#   Gyarados locked, Eevee stopped by its lock at Lv 25, Pikachu and
#   Genchoke learning a move on the way. Three designs.
# Sprites: python qa_assets.py "<KIF Beta>" first (writes art/ here).
# Usage (from this folder): ruby finish_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                           python <KR>/Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
load File.join(File.dirname(File.expand_path(__FILE__)), "qa_common.rb")
GFX = File.join(ARGV[0], "Graphics")

def map_only(o)
  o.clear
  o.blt(0, 0, QA_MAP.bitmap, Rect.new(0, 0, SW, SH))
end
def item_pic(o, item, cx, cy, size)
  bm = qa_bmp(File.join(GFX, "Items", "#{item}.png"))
  o.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), bm, Rect.new(0, 0, bm.width, bm.height))
end
# PIF's own message box (the speech frame's white box and dark text)
def message_box(o, text)
  x0 = 8; y0 = SH - 86; x1 = SW - 8; y1 = SH - 8
  P2.ui.rbox(o, x0, y0, x1, y1, 6, Color.new(248, 248, 248), Color.new(96, 96, 104))
  P2.ui.rbox(o, x0 + 3, y0 + 3, x1 - 3, y1 - 3, 4, Color.new(248, 248, 248), Color.new(200, 200, 208))
  P2.text(o, x0 + 18, y0 + 14, x1 - x0 - 36, 20, text, Color.new(72, 72, 80), PF::ROW)
  P2.ui.tri(o, x1 - 28, y1 - 22, :d, Color.new(220, 80, 70), 5)
end

DESIGNS = []

#================================================================ Auto-Repel Reuse
# 1 Recommended: a short line at the top for a moment (no button; you keep
# walking): the Repel, what happened, how many are left
DESIGNS << ["QA_AR1_toast", nil, proc { |o, c|
  map_only(o)
  words = "Used Another Super Repel"
  tw = P2.width(PF::TEXT, words); pw = P2.width(PF::TINY, "4 LEFT") + 12
  w = 34 + tw + 10 + pw + 10; h = 30; x = (SW - w) / 2; y = 10
  P2.ui.rbox(o, x, y, x + w, y + h, 7, c[:panel], c[:line])
  item_pic(o, "SUPERREPEL", x + 18, y + h / 2, 24)
  P2.text(o, x + 34, y + 6, tw + 2, 18, words, c[:txt], PF::TEXT)
  P2.pill(o, x + w - 10, y + 7, "4 LEFT", GOLD_FILL, GOLD_T, true)
}]

# 2: the game's own message box, as when a Repel wears off (A to go on)
DESIGNS << ["QA_AR2_message", nil, proc { |o, c|
  map_only(o)
  message_box(o, "Used another Super Repel. 4 left.")
}]

# 3: a small badge in the corner for a moment: the Repel and how many are
# left, nothing else
DESIGNS << ["QA_AR3_corner_badge", nil, proc { |o, c|
  map_only(o)
  x = SW - 96; y = 10
  P2.ui.rbox(o, x, y, x + 86, y + 34, 7, c[:panel], GOLD_T)
  item_pic(o, "SUPERREPEL", x + 20, y + 17, 26)
  P2.text(o, x + 36, y + 3, 44, 14, "AGAIN", GOLD_T, PF::TINY, 2)
  P2.text(o, x + 36, y + 15, 44, 16, "x4", c[:txt], PF::TEXT, 2)
}]

#================================================================ Super Candy, done
RAISED = [[:PIKACHU, "Pikachu", 34, 38, "Learned Thunder"], [:PIDGEOT, "Pidgeot", 36, 38, nil],
          [:GYARADOS, "Gyarados", 35, 35, :locked], [:EEVEE, "Eevee", 22, 25, :lock_stop],
          [:MACHOKE, "Genchoke", 37, 38, "Learned Shadow Ball"], [:GENGAR, "Gengar", 37, 38, nil]]
def raised_row(o, c, x, y, w, (sp, name, from, to, note))
  sp = :GENCHOKE if name == "Genchoke"
  art(o, sp, x + 14, y + 11, 22)
  P2.text(o, x + 32, y + 2, 100, 18, name, c[:txt], PF::TEXT)
  if note == :locked
    tw = P2.small(o, x + w - 120, y + 3, 120, 16, "Locked at Lv #{from}", GOLD_T, 1)
    lock_icon(o, x + w - tw - 14, y + 5, GOLD_T)
    return
  end
  P2.small(o, x + w - 30, y + 3, 30, 16, to.to_s, GREEN_T, 1)
  P2.ui.tri(o, x + w - 44, y + 7, :r, GREEN_T, 4)
  P2.small(o, x + w - 80, y + 3, 30, 16, from.to_s, c[:dim], 1)
  lock_icon(o, x + w - 100, y + 5, GOLD_T) if note == :lock_stop
  P2.small(o, x + 122, y + 3, w - 222, 16, note, PINK_T) if note.is_a?(String)
end

# 1 Recommended: what happened, in a popup like Super Candy's own: each
# Pokémon's levels, a new move where one was learned, the locks
DESIGNS << ["QA_SF1_result", [[A_PAD, "OK"]], proc { |o, c|
  w = 400; rh = 24; h = 42 + 18 + RAISED.length * rh + 12
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2
  popup(o, c, x, y, w, h, "Party Raised")
  P2.small(o, x, y + 38, w, 16, "Up to the level cap, Lv 38.", c[:dim], 2)
  RAISED.each_with_index { |r, i| raised_row(o, c, x + 14, y + 58 + i * rh, w - 28, r) }
}]

# 2: a notice: one line for what happened, the new moves named
DESIGNS << ["QA_SF2_notice", [[A_PAD, "Done"]], proc { |o, c|
  w = 340; h = 166
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2
  popup(o, c, x, y, w, h, "Party Raised")
  o.fill_rect(x + 12, y + 36, w - 24, 2, GREEN_T)
  item_pic(o, "RARECANDY", x + w / 2, y + 60, 32)
  P2.text(o, x, y + 80, w, 18, "5 Pokémon Rose to Lv 38", c[:txt], PF::TEXT, 2)
  P2.small(o, x, y + 102, w, 16, "Pikachu learned Thunder.", c[:dim], 2)
  P2.small(o, x, y + 118, w, 16, "Genchoke learned Shadow Ball.", c[:dim], 2)
  P2.small(o, x, y + 134, w, 16, "Gyarados and Eevee stopped at their locks.", GOLD_T, 2)
}]

# 3: no summary: only the game's own messages on the way (a level up, a new
# move, an evolution), as the Rare Candy shows them
DESIGNS << ["QA_SF3_game_messages", nil, proc { |o, c|
  map_only(o)
  message_box(o, "Pikachu learned Thunder!")
}]

run_designs("Quality of Life finishing designs", DESIGNS)
