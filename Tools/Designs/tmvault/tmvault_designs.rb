# encoding: utf-8
# Mockups: the TM Vault in Reloaded's plate look (topic tm-vault; the
# 2026-10-17 picks, Vault design 1 and Move Compare design 2, drawn before
# the plate look). With the 2026-10-23 decisions: Search in the header,
# NEW marks, Favorites (a star), a Type Filter, free teaching, the Checklist
# with map hints, a toast when a move is registered.
#
# The Vault (Vault, Relearn and Checklist tabs)
#   Design 1 Plates: the Party Screen's look. The list as slim plates lit in
#            each move's type (the highlighted one glows), the Type Filter
#            chips over it; the details panel as the Party Screen's, lit in
#            the move's type with its bands: the party (Knows It, Can Learn,
#            Can't), the move, its badges and text, Coverage.
#   Design 2 Party Strip: the party as five small cards across the top
#            (picking one shows only its moves), the list and the details
#            under them.
#   Design 3 Type Sidebar: the type chips down the left as a sidebar, the
#            list in plain rows, a big details panel.
# Move Compare (teaching Thunderbolt to Genchoke)
#   Design 1 Side by Side: the new move's plate on the left, the four it can
#            replace on the right (the one to forget marked), Coverage now
#            and after under them.
#   Design 2 Stacked: the new move across the top, the four as a two-by-two
#            grid, Coverage at the bottom.
#   Design 3 Swap Cards: the four as tabs; the one picked and the new move as
#            two big cards with an arrow between them.
# The Checklist (TMs not found yet, with where the game gives them)
#   Design 1 Where in the Panel: one row per TM, the details panel says where
#            (the map and how) above the move.
#   Design 2 Two-Line Rows: where under each TM's name, the panel the move.
#   Design 3 By Map: headings for the maps, the TMs under each.
# The Checklist, kinds only (his ask: not so specific, "Ground, Store")
#   Design 4 Kind in the Row: a pill on each TM's plate (GROUND, STORE,
#            GIFT), the panel the move.
#   Design 5 Kind in the Panel: the panel says the kind first, then the
#            move.
# The toast (a move registered)
#   Design 1 TM Disc: the TM's disc in its type, "Added to TM Vault", NEW.
#   Design 2 Type Icon: the type's icon, the TM's number in the pill.
# Sprites: python ../qa/qa_assets.py "<KIF Beta>" first (writes ../qa/art).
# Usage (from this folder): ruby tmvault_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                           python <KR>/Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
load File.join(File.dirname(File.expand_path(__FILE__)), "..", "qa", "party_common.rb")

PP = Reloaded::PartyPaint
QA_MAP.visible = false
MIXC = proc { |a, b, t| Reloaded::Palette.mix(a, b, t) }
def mx(a, b, t); Reloaded::Palette.mix(a, b, t); end
LB = "p:9"; RB = "p:10"

# [name, type, category (0 physical, 1 special, 2 status), power, accuracy, pp, source, favorite, new]
MOVES = [["Thunderbolt", :ELECTRIC, 1, 90, 100, 15, "TM24", true, false],
         ["Earthquake", :GROUND, 0, 100, 100, 10, "TM26", true, false],
         ["Ice Beam", :ICE, 1, 90, 100, 10, "TM13", false, true],
         ["Shadow Ball", :GHOST, 1, 80, 100, 15, "TM30", false, true],
         ["Flamethrower", :FIRE, 1, 90, 100, 15, "TM35", false, false],
         ["Psychic", :PSYCHIC, 1, 90, 100, 10, "TM29", false, false],
         ["Surf", :WATER, 1, 90, 100, 15, "HM03", false, false],
         ["Thunder Wave", :ELECTRIC, 2, nil, 90, 20, "TM45", false, false],
         ["Toxic", :POISON, 2, nil, 90, 10, "TM06", false, false],
         ["Body Slam", :NORMAL, 0, 85, 100, 15, "Tutor", false, false]].freeze
DESC = "A strong electric blast crashes down on the target. It may also leave the target with paralysis."
# the party check for Thunderbolt: index into MONS, word
CHECK = [[0, :knows], [1, :cant], [2, :cant], [3, :cant], [4, :learn]].freeze
CHECK_WORDS = { :knows => ["Knows It", :blue], :learn => ["Can Learn", :green], :cant => ["Can't", :dim] }.freeze
COVER_NOW = [:GHOST, :PSYCHIC, :NORMAL, :ICE, :ROCK, :STEEL, :DARK].freeze
COVER_ADD = [:WATER, :FLYING].freeze
GENCHOKE = [["Shadow Punch", :GHOST, 0, 60, nil, 20], ["Karate Chop", :FIGHTING, 0, 50, 100, 25],
            ["Hypnosis", :PSYCHIC, 2, nil, 60, 20], ["Seismic Toss", :FIGHTING, 0, nil, 100, 20]].freeze
FORGET = 2
# the Checklist: [TM, move, type, map, how]
MISSING = [["TM05", "Roar", :NORMAL, "Route 16", "On the Ground"], ["TM08", "Bulk Up", :FIGHTING, "Celadon Dept. Store", "A Shop"],
           ["TM11", "Sunny Day", :FIRE, "Celadon Dept. Store", "A Shop"], ["TM19", "Giga Drain", :GRASS, "Celadon Gym", "A Gift"],
           ["TM21", "Frustration", :NORMAL, "Celadon City", "A Gift"], ["TM31", "Brick Break", :FIGHTING, "Saffron City", "A Gift"],
           ["TM38", "Fire Blast", :FIRE, "Cinnabar Gym", "A Gift"], ["TM43", "Secret Power", :NORMAL, "Route 25", "On the Ground"],
           ["TM46", "Thief", :DARK, "Mt. Moon", "On the Ground"], ["TM50", "Overheat", :FIRE, "Victory Road", "On the Ground"]].freeze
VAULT_HINTS = [[:ud, "Choose"], [:lr, "Party"], [Y_PAD, "Favorite"], [A_PAD, "Teach"], [B_PAD, "Close"]].freeze
COMPARE_HINTS = [[:ud, "Choose"], [A_PAD, "Forget This"], [B_PAD, "Cancel"]].freeze
CHECK_HINTS = [[:ud, "Choose"], [X_PAD, "Tabs"], [B_PAD, "Close"]].freeze

#---------------------------------------------------------------- pieces
def tc(t); tcol(t); end
def cat_name(k); ["PHYSICAL", "SPECIAL", "STATUS"][k]; end
def type_icon(o, t, x, y)
  sheet = qa_bmp(File.join(KR_DIR, "Graphics", "OverworldMenu", "typesSmall16.png"))
  o.blt(x, y, sheet, Rect.new(0, TYPE_ROW[t] * 16, 16, 16))
end
# PIF's big type label, scaled
def big_type(o, t, x, y, k = 0.75)
  sheet = qa_bmp(File.join(GFX, "Pictures", "types.png"))
  o.stretch_blt(Rect.new(x, y, (64 * k).round, (28 * k).round), sheet, Rect.new(0, TYPE_ROW[t] * 28, 64, 28))
  return (64 * k).round
end
def big_cat(o, k, x, y, s = 0.75)
  sheet = qa_bmp(File.join(GFX, "Pictures", "category.png"))
  o.stretch_blt(Rect.new(x, y, (64 * s).round, (28 * s).round), sheet, Rect.new(0, k * 28, 64, 28))
  return (64 * s).round
end
def disc_icon(o, t, x, y, size = 24)
  bm = qa_bmp(File.join(GFX, "Items", "machine_#{t}.png"))
  o.stretch_blt(Rect.new(x, y, size, size), bm, Rect.new(0, 0, bm.width, bm.height))
end
def pill(o, c, x, y, label, tone_key, right = false)
  tone = c[tone_key] || tone_key
  fill = c[:light] ? mx(c[:panel2], tone, 0.22) : mx(c[:panel2], tone, 0.28)
  P2.pill(o, x, y, label, fill, tone, right)
end
def star(o, x, y, col); pix(o, OMS::STAR, x, y, col); end
def gold(c); c[:light] ? c[:gold] : GOLD_T; end

# the header: the title, Search on the left (a field you type into) and
# Sort on the right, as angled plates
def header(o, c, title, query = nil, sort = "Sort: Type")
  PP.paint_background(o, c)
  PP.paint_title(o, c, title)
  PP.chamfer_grad(o, 6, 4, 132, 26, 6, mx(c[:panel2], c[:selb], 0.15), c[:panel2], c[:line])
  P2.text(o, 14, 5, 110, 20, query || "Search", query ? c[:txt] : c[:dim], PF::TEXT)
  Reloaded::ButtonIcons.draw(o, 136, 6, LB, c, :xbox, 18)
  PP.chamfer_grad(o, SW - 132, 4, SW - 6, 26, 6, mx(c[:panel2], c[:selb], 0.15), c[:panel2], c[:line])
  P2.text(o, SW - 132, 5, 126, 20, sort, c[:txt], PF::TEXT, 2)
  Reloaded::ButtonIcons.draw(o, SW - 156, 6, RB, c, :xbox, 18)
end

def tabs(o, c, x, y, w, active, counts = { 0 => 10, 2 => 14 })
  labels = ["VAULT", "RELEARN", "CHECKLIST"]
  tw = (w - 8) / 3
  labels.each_with_index do |l, i|
    tx = x + i * (tw + 4)
    on = i == active
    PP.chamfer_grad(o, tx, y, tx + tw, y + 20, 6, on ? mx(c[:panel2], c[:selb], 0.55) : c[:panel2],
                    on ? mx(c[:panel2], c[:selb], 0.3) : mx(c[:panel2], c[:dark], 0.4), on ? c[:selb] : c[:line])
    txt = counts[i] ? "#{l} #{counts[i]}" : l
    P2.text(o, tx, y + 3, tw, 14, txt, on ? c[:strong] : c[:dim], PF::TINY, 2)
  end
end

# the Type Filter: ALL, then each type's icon (the active one ringed)
def chips(o, c, x, y, w, active = nil)
  PP.chamfer_grad(o, x, y, x + 30, y + 18, 5, active.nil? ? mx(c[:panel2], c[:selb], 0.5) : c[:panel2], c[:panel2],
                  active.nil? ? c[:selb] : c[:line])
  P2.text(o, x, y + 2, 30, 14, "ALL", active.nil? ? c[:strong] : c[:dim], PF::TINY, 2)
  types = [:NORMAL, :FIRE, :WATER, :ELECTRIC, :GRASS, :ICE, :FIGHTING, :POISON, :GROUND, :PSYCHIC, :GHOST]
  types.each_with_index do |t, i|
    ix = x + 36 + i * 17
    break if ix + 16 > x + w
    type_icon(o, t, ix, y + 1)
    o.fill_rect(ix, y + 18, 16, 2, c[:selb]) if t == active
  end
end

# a move's row as a slim plate lit in its type; the highlighted one glows
def move_plate(o, c, x, y, w, mv, sel, h = 24)
  name, t, _k, _p, _a, _pp, src, fav, new = mv
  col = tc(t)
  if sel
    PP.chamfer(o, x - 2, y - 2, x + w + 2, y + h + 2, 8, mx(c[:bg], c[:selb], 0.35), mx(c[:bg], c[:selb], 0.35))
  end
  PP.chamfer_grad(o, x, y, x + w, y + h, 6, mx(c[:panel2], col, sel ? 0.5 : 0.28), mx(c[:panel2], c[:dark], 0.45),
                  sel ? c[:selb] : mx(c[:line], col, 0.4))
  o.fill_rect(x + 3, y + 3, 3, h - 6, col)
  star(o, x + 10, y + 8, fav ? gold(c) : mx(c[:panel2], c[:line], 0.6))
  nw = P2.text(o, x + 22, y + 2, w - 110, 20, name, sel ? c[:strong] : c[:txt], PF::TEXT)
  pill(o, c, x + 22 + nw + 6, y + 4, "NEW", :green) if new
  P2.text(o, x + w - 66, y + 4, 40, 16, src, c[:dim], PF::TINY, 1)
  type_icon(o, t, x + w - 22, y + 4)
end

# the details panel, lit in the move's type with the Party Screen's bands
def panel(o, c, x0, y0, x1, y1, col, line_y)
  cut = 16
  top = mx(c[:panel], col, 0.4)
  bottom = mx(c[:panel], c[:dark], 0.4)
  PP.chamfer_grad(o, x0, y0, x1, y1, cut, top, bottom, mx(c[:line], col, 0.5))
  from = x1 - 48; to = x0 + 24
  (y0 + 1...y1 - 1).each do |y|
    t = (y - y0).to_f / (y1 - y0)
    left = x0 + 1 + [cut - (y - y0), 0].max
    right = x1 - 1 - [cut - (y1 - 1 - y), 0].max
    mid = from + (to - from) * t
    k = y < line_y ? 0.4 : 0.22 - 0.18 * (y - line_y).to_f / (y1 - line_y)
    tint = mx(mx(top, bottom, t), col, k)
    [[0, 56], [40, 8]].each do |off, bw|
      a = [(mid + off - bw / 2.0).round, left].max
      b = [(mid + off + bw / 2.0).round, right].min
      o.fill_rect(a, y, b - a, 1, tint) if b > a
    end
  end
  o.fill_rect(x0 + 8, line_y, x1 - x0 - 16, 2, PP::POKE_RED)
end

# the party: who knows it, who can learn it, who can't
def party_check(o, c, x, y, w, size = 30)
  step = w / CHECK.length
  CHECK.each_with_index do |(mi, how), i|
    m = MONS[mi]
    cx = x + i * step + step / 2
    art(o, m[:sp], cx, y + size / 2, size)
    word, tone = CHECK_WORDS[how]
    P2.text(o, cx - step / 2, y + size + 2, step, 12, word, c[tone] || c[:dim], PF::TINY, 2)
  end
end

def move_info(o, c, x, y, w, mv, desc = DESC, lines = 3, cat = true)
  name, t, k, pw, acc, pp = mv
  P2.text(o, x, y, w, 22, name, c[:strong], PF::ROW)
  bx = x
  bx += big_type(o, t, bx, y + 26, 0.6) + 4
  bx += big_cat(o, k, bx, y + 26, 0.6) + 6 if cat
  P2.pill(o, bx, y + 27, "POW #{pw || '--'}", c[:pill], c[:txt], false)
  bx += P2.width(PF::TINY, "POW #{pw || '--'}") + 18
  P2.pill(o, bx, y + 27, "ACC #{acc || '--'}", c[:pill], c[:txt], false)
  bx += P2.width(PF::TINY, "ACC #{acc || '--'}") + 18
  P2.pill(o, bx, y + 27, "PP #{pp}", c[:pill], c[:txt], false)
  P2.small_wrap(o, desc, w).first(lines).each_with_index { |ln, i| P2.small(o, x, y + 48 + i * 16, w, 16, ln, c[:txt]) }
end

def coverage(o, c, x, y, w, who = "Genchoke")
  P2.heading(o, x, x + w, y, "Coverage (#{who})", c[:dim], c[:line])
  ix = x
  COVER_NOW.each { |t| type_icon(o, t, ix, y + 16); ix += 18 }
  P2.text(o, ix + 2, y + 15, 12, 16, "+", c[:green], PF::TEXT)
  ix += 14
  COVER_ADD.each { |t| type_icon(o, t, ix, y + 16); ix += 18 }
  P2.small(o, x, y + 34, w, 14, "Thunderbolt adds Water and Flying.", c[:green])
end

#================================================================ the Vault
def vault1(o, c, tab = 0)
  header(o, c, "TM Vault")
  tabs(o, c, 8, 36, 228, tab)
  chips(o, c, 8, 60, 228)
  MOVES.first(9).each_with_index { |mv, i| move_plate(o, c, 10, 84 + i * 28, 224, mv, i == 0) }
  px0 = 244; py0 = 36; px1 = SW - 6; py1 = HINT_TOP - 6
  panel(o, c, px0, py0, px1, py1, tc(:ELECTRIC), py0 + 66)
  party_check(o, c, px0 + 8, py0 + 6, px1 - px0 - 16)
  move_info(o, c, px0 + 14, py0 + 74, px1 - px0 - 28, MOVES[0])
  coverage(o, c, px0 + 14, py0 + 214, px1 - px0 - 28)
end

def vault2(o, c)
  header(o, c, "TM Vault")
  # the party as small cards; Genchoke picked: only what it can learn
  cw = 96; ch = 52
  MONS.first(5).each_with_index do |m, i|
    x = 8 + i * (cw + 4); y = 34
    t = tcol(m[:types][0])
    sel = i == 4
    PP.chamfer(o, x - 2, y - 2, x + cw + 2, y + ch + 2, 9, mx(c[:bg], c[:selb], 0.4), mx(c[:bg], c[:selb], 0.4)) if sel
    PP.chamfer_grad(o, x, y, x + cw, y + ch, 8, mx(c[:panel2], t, 0.45), mx(c[:panel2], c[:dark], 0.5), sel ? c[:selb] : mx(c[:line], t, 0.4))
    art(o, m[:sp], x + 22, y + 26, 34)
    P2.text(o, x + 40, y + 6, cw - 44, 16, m[:name], c[:txt], PF::TINY)
    word, tone = CHECK_WORDS[CHECK[i][1]]
    P2.text(o, x + 40, y + 30, cw - 44, 14, word, c[tone] || c[:dim], PF::TINY)
  end
  tabs(o, c, 8, 92, 228, 0, { 0 => 6, 2 => 14 })
  learn = [MOVES[0], MOVES[1], MOVES[3], MOVES[5], MOVES[7], MOVES[8]]
  learn.each_with_index { |mv, i| move_plate(o, c, 10, 118 + i * 28, 224, mv, i == 0) }
  px0 = 244; py0 = 92; px1 = SW - 6; py1 = HINT_TOP - 6
  panel(o, c, px0, py0, px1, py1, tc(:ELECTRIC), py0 + 132)
  move_info(o, c, px0 + 14, py0 + 10, px1 - px0 - 28, MOVES[0])
  coverage(o, c, px0 + 14, py0 + 140, px1 - px0 - 28)
end

def vault3(o, c)
  header(o, c, "TM Vault")
  # the type chips as a sidebar
  PP.chamfer_grad(o, 6, 36, 64, HINT_TOP - 6, 8, c[:panel2], mx(c[:panel2], c[:dark], 0.4), c[:line])
  P2.text(o, 6, 40, 58, 14, "ALL", c[:strong], PF::TINY, 2)
  o.fill_rect(12, 56, 46, 1, c[:line])
  [:NORMAL, :FIRE, :WATER, :ELECTRIC, :GRASS, :ICE, :FIGHTING, :POISON, :GROUND, :PSYCHIC, :GHOST].each_with_index do |t, i|
    y = 62 + i * 24
    type_icon(o, t, 14, y)
    P2.text(o, 32, y + 2, 30, 14, (i % 3 + 1).to_s, c[:dim], PF::TINY)
  end
  tabs(o, c, 70, 36, 170, 0)
  MOVES.first(10).each_with_index do |mv, i|
    y = 62 + i * 26
    sel = i == 0
    Reloaded::Dialogs.send(:cursor_row, o, c, 70, y, 240, y + 24) if sel
    star(o, 74, y + 8, mv[7] ? gold(c) : mx(c[:panel2], c[:line], 0.6))
    nw = P2.text(o, 86, y + 2, 110, 20, mv[0], sel ? c[:strong] : c[:txt], PF::TEXT)
    pill(o, c, 86 + nw + 4, y + 4, "NEW", :green) if mv[8]
    type_icon(o, mv[1], 220, y + 4)
  end
  px0 = 248; py0 = 36; px1 = SW - 6; py1 = HINT_TOP - 6
  panel(o, c, px0, py0, px1, py1, tc(:ELECTRIC), py0 + 66)
  party_check(o, c, px0 + 8, py0 + 6, px1 - px0 - 16)
  move_info(o, c, px0 + 14, py0 + 74, px1 - px0 - 28, MOVES[0])
  coverage(o, c, px0 + 14, py0 + 214, px1 - px0 - 28)
end

#================================================================ Move Compare
def stats_line(mv)
  _n, _t, _k, pw, acc, pp = mv
  return "POW #{pw || '--'} ACC #{acc || '--'} PP #{pp}"
end

def old_plate(o, c, x, y, w, h, mv, forget)
  col = tc(mv[1])
  if forget
    PP.chamfer(o, x - 2, y - 2, x + w + 2, y + h + 2, 9, mx(c[:bg], c[:red], 0.4), mx(c[:bg], c[:red], 0.4))
  end
  PP.chamfer_grad(o, x, y, x + w, y + h, 8, mx(c[:panel2], col, forget ? 0.45 : 0.28), mx(c[:panel2], c[:dark], 0.45),
                  forget ? c[:red] : mx(c[:line], col, 0.4))
  P2.text(o, x + 10, y + 3, w - 80, 20, mv[0], forget ? c[:strong] : c[:txt], PF::TEXT)
  pill(o, c, x + w - 8, y + 5, "FORGET", :red, true) if forget
  type_icon(o, mv[1], x + 10, y + h - 20)
  big_cat(o, mv[2], x + 30, y + h - 21, 0.6)
  P2.small(o, x + 72, y + h - 21, w - 80, 16, stats_line(mv), c[:dim])
end

def cover_rows(o, c, x, y, w)
  P2.heading(o, x, x + w, y, "Coverage", c[:dim], c[:line])
  [["Now", COVER_NOW, []], ["After", COVER_NOW, COVER_ADD]].each_with_index do |(label, a, add), r|
    ry = y + 16 + r * 20
    P2.text(o, x, ry, 50, 16, label, c[:dim], PF::TEXT)
    ix = x + 52
    (a + add).each { |t| type_icon(o, t, ix, ry); ix += 18 }
  end
  P2.small(o, x, y + 58, w, 14, "Thunderbolt adds Water and Flying. Forgetting Hypnosis loses none.", c[:green])
end

def compare1(o, c)
  PP.paint_background(o, c)
  PP.paint_title(o, c, "Teach Thunderbolt to Genchoke?")
  x0 = 8; y0 = 36; x1 = 250; y1 = 262
  panel(o, c, x0, y0, x1, y1, tc(:ELECTRIC), y0 + 34)
  P2.text(o, x0 + 14, y0 + 6, 200, 14, "NEW MOVE", c[:head], PF::TINY)
  move_info(o, c, x0 + 14, y0 + 42, x1 - x0 - 28, MOVES[0], DESC, 5)
  GENCHOKE.each_with_index { |mv, i| old_plate(o, c, 258, 36 + i * 57, SW - 6 - 258, 51, mv, i == FORGET) }
  PP.chamfer_grad(o, 8, 268, SW - 6, HINT_TOP - 6, 10, c[:panel2], mx(c[:panel2], c[:dark], 0.4), c[:line])
  cover_rows(o, c, 20, 274, SW - 40)
end

def compare2(o, c)
  PP.paint_background(o, c)
  PP.paint_title(o, c, "Teach Thunderbolt to Genchoke?")
  panel(o, c, 8, 36, SW - 6, 132, tc(:ELECTRIC), 130)
  P2.text(o, 22, 42, 200, 14, "NEW MOVE", c[:head], PF::TINY)
  move_info(o, c, 22, 54, SW - 44, MOVES[0], "A strong electric blast. It may also paralyze the target.", 1)
  GENCHOKE.each_with_index do |mv, i|
    old_plate(o, c, 8 + (i % 2) * 252, 140 + (i / 2) * 58, 246, 52, mv, i == FORGET)
  end
  PP.chamfer_grad(o, 8, 262, SW - 6, HINT_TOP - 6, 10, c[:panel2], mx(c[:panel2], c[:dark], 0.4), c[:line])
  cover_rows(o, c, 20, 268, SW - 40)
end

def compare3(o, c)
  PP.paint_background(o, c)
  PP.paint_title(o, c, "Teach Thunderbolt to Genchoke?")
  tw = (SW - 14 - 12) / 4
  GENCHOKE.each_with_index do |mv, i|
    tx = 8 + i * (tw + 4)
    on = i == FORGET
    PP.chamfer_grad(o, tx, 36, tx + tw, 58, 6, on ? mx(c[:panel2], c[:red], 0.4) : mx(c[:panel2], tc(mv[1]), 0.25),
                    c[:panel2], on ? c[:red] : c[:line])
    P2.text(o, tx, 39, tw, 16, mv[0], on ? c[:strong] : c[:txt], PF::TINY, 2)
  end
  cw = 226
  old = GENCHOKE[FORGET]
  panel(o, c, 8, 66, 8 + cw, 262, tc(old[1]), 96)
  P2.text(o, 22, 72, 200, 14, "FORGET", c[:red], PF::TINY)
  move_info(o, c, 22, 104, cw - 28, old, "Hypnotic suggestion is used to make the target fall into a deep sleep.", 4, false)
  P2.ui.tri(o, SW / 2 - 4, 158, :r, c[:txt], 8)
  panel(o, c, SW - 6 - cw, 66, SW - 6, 262, tc(:ELECTRIC), 96)
  P2.text(o, SW - 6 - cw + 14, 72, 200, 14, "LEARN", c[:green], PF::TINY)
  move_info(o, c, SW - 6 - cw + 14, 104, cw - 28, MOVES[0], "A strong electric blast. It may also paralyze the target.", 4, false)
  PP.chamfer_grad(o, 8, 268, SW - 6, HINT_TOP - 6, 10, c[:panel2], mx(c[:panel2], c[:dark], 0.4), c[:line])
  cover_rows(o, c, 20, 274, SW - 40)
end

#================================================================ the Checklist
def missing_plate(o, c, x, y, w, row, sel, h = 24, two = false)
  tm, name, t, map, how = row
  col = tc(t)
  PP.chamfer(o, x - 2, y - 2, x + w + 2, y + h + 2, 8, mx(c[:bg], c[:selb], 0.35), mx(c[:bg], c[:selb], 0.35)) if sel
  PP.chamfer_grad(o, x, y, x + w, y + h, 6, mx(c[:panel2], col, sel ? 0.4 : 0.18), mx(c[:panel2], c[:dark], 0.45),
                  sel ? c[:selb] : mx(c[:line], col, 0.3))
  disc_icon(o, t, x + 4, y + (two ? 6 : 1), 22)
  P2.text(o, x + 30, y + 2, 40, 20, tm, c[:dim], PF::TINY)
  P2.text(o, x + 70, y + 2, w - 96, 20, name, sel ? c[:strong] : c[:txt], PF::TEXT)
  type_icon(o, t, x + w - 22, y + 4)
  P2.small(o, x + 30, y + 22, w - 40, 14, "#{map} · #{how}", c[:dim]) if two
end

def where_box(o, c, x, y, w, row)
  _tm, _n, t, map, how = row
  P2.heading(o, x, x + w, y, "Where", c[:dim], c[:line])
  disc_icon(o, t, x, y + 16, 28)
  P2.text(o, x + 36, y + 14, w - 36, 20, map, c[:strong], PF::TEXT)
  pill(o, c, x + 36, y + 36, how.upcase, how == "A Shop" ? :gold : (how == "A Gift" ? :blue : :green))
end

def randomizer_note(o, c, x, y, w)
  P2.small_wrap(o, "Randomizer On: It may be somewhere else.", w).first(2).each_with_index { |ln, i| P2.small(o, x, y + i * 14, w, 14, ln, c[:dim]) }
end

def check1(o, c)
  header(o, c, "TM Vault", nil, "Sort: Number")
  tabs(o, c, 8, 36, 228, 2)
  MISSING.first(10).each_with_index { |row, i| missing_plate(o, c, 10, 62 + i * 28, 224, row, i == 0) }
  px0 = 244; py0 = 36; px1 = SW - 6; py1 = HINT_TOP - 6
  panel(o, c, px0, py0, px1, py1, tc(:NORMAL), py0 + 100)
  where_box(o, c, px0 + 14, py0 + 10, px1 - px0 - 28, MISSING[0])
  randomizer_note(o, c, px0 + 14, py0 + 64, px1 - px0 - 28)
  move_info(o, c, px0 + 14, py0 + 108, px1 - px0 - 28, ["Roar", :NORMAL, 2, nil, nil, 20],
            "The target is scared off and replaced by another Pokémon. In the wild, the battle ends.")
end

def check2(o, c)
  header(o, c, "TM Vault", nil, "Sort: Number")
  tabs(o, c, 8, 36, 228, 2)
  MISSING.first(7).each_with_index { |row, i| missing_plate(o, c, 10, 62 + i * 40, 224, row, i == 0, 36, true) }
  px0 = 244; py0 = 36; px1 = SW - 6; py1 = HINT_TOP - 6
  panel(o, c, px0, py0, px1, py1, tc(:NORMAL), py0 + 40)
  P2.text(o, px0 + 14, py0 + 10, 200, 20, "TM05", c[:dim], PF::TEXT)
  randomizer_note(o, c, px0 + 14, py0 + 280, px1 - px0 - 28)
  move_info(o, c, px0 + 14, py0 + 50, px1 - px0 - 28, ["Roar", :NORMAL, 2, nil, nil, 20],
            "The target is scared off and replaced by another Pokémon. In the wild, the battle ends.")
end

def check3(o, c)
  header(o, c, "TM Vault", nil, "Sort: Map")
  tabs(o, c, 8, 36, 228, 2)
  y = 62
  sel_done = false
  MISSING.group_by { |r| r[3] }.first(5).each do |map, rows|
    P2.heading(o, 12, 232, y + 2, map, c[:head], c[:line])
    y += 18
    rows.each do |row|
      missing_plate(o, c, 10, y, 224, row, !sel_done)
      sel_done = true
      y += 28
    end
    break if y > HINT_TOP - 60
  end
  px0 = 244; py0 = 36; px1 = SW - 6; py1 = HINT_TOP - 6
  panel(o, c, px0, py0, px1, py1, tc(:NORMAL), py0 + 100)
  where_box(o, c, px0 + 14, py0 + 10, px1 - px0 - 28, MISSING[0])
  randomizer_note(o, c, px0 + 14, py0 + 64, px1 - px0 - 28)
  move_info(o, c, px0 + 14, py0 + 108, px1 - px0 - 28, ["Roar", :NORMAL, 2, nil, nil, 20],
            "The target is scared off and replaced by another Pokémon. In the wild, the battle ends.")
end

#---------------------------------------------------------------- kinds only
KINDS = { "On the Ground" => ["GROUND", :green], "A Shop" => ["STORE", :gold], "A Gift" => ["GIFT", :blue] }.freeze
def kind_plate(o, c, x, y, w, row, sel)
  tm, name, t, _map, how = row
  col = tc(t)
  PP.chamfer(o, x - 2, y - 2, x + w + 2, y + 26, 8, mx(c[:bg], c[:selb], 0.35), mx(c[:bg], c[:selb], 0.35)) if sel
  PP.chamfer_grad(o, x, y, x + w, y + 24, 6, mx(c[:panel2], col, sel ? 0.4 : 0.18), mx(c[:panel2], c[:dark], 0.45),
                  sel ? c[:selb] : mx(c[:line], col, 0.3))
  disc_icon(o, t, x + 4, y + 1, 22)
  label, tone = KINDS[how]
  room = w - 30 - 26 - (P2.width(PF::TINY, label) + 12) - 8
  P2.text(o, x + 30, y + 2, room, 20, PF.fit(PF::TEXT, name, room), sel ? c[:strong] : c[:txt], PF::TEXT)
  pill(o, c, x + w - 26, y + 5, label, tone, true)
  type_icon(o, t, x + w - 22, y + 4)
end

def check4(o, c)
  header(o, c, "TM Vault", nil, "Sort: Number")
  tabs(o, c, 8, 36, 228, 2)
  MISSING.first(10).each_with_index { |row, i| kind_plate(o, c, 10, 62 + i * 28, 224, row, i == 0) }
  px0 = 244; py0 = 36; px1 = SW - 6; py1 = HINT_TOP - 6
  panel(o, c, px0, py0, px1, py1, tc(:NORMAL), py0 + 34)
  P2.text(o, px0 + 14, py0 + 8, 200, 20, "TM05", c[:dim], PF::TEXT)
  move_info(o, c, px0 + 14, py0 + 44, px1 - px0 - 28, ["Roar", :NORMAL, 2, nil, nil, 20],
            "The target is scared off and replaced by another Pokémon. In the wild, the battle ends.")
  randomizer_note(o, c, px0 + 14, py1 - 36, px1 - px0 - 28)
end

def check5(o, c)
  header(o, c, "TM Vault", nil, "Sort: Number")
  tabs(o, c, 8, 36, 228, 2)
  MISSING.first(10).each_with_index { |row, i| missing_plate(o, c, 10, 62 + i * 28, 224, row, i == 0) }
  px0 = 244; py0 = 36; px1 = SW - 6; py1 = HINT_TOP - 6
  panel(o, c, px0, py0, px1, py1, tc(:NORMAL), py0 + 100)
  P2.heading(o, px0 + 14, px1 - 14, py0 + 10, "Where", c[:dim], c[:line])
  disc_icon(o, :NORMAL, px0 + 14, py0 + 26, 28)
  P2.text(o, px0 + 50, py0 + 24, 200, 20, "On the Ground", c[:strong], PF::TEXT)
  P2.small(o, px0 + 50, py0 + 44, px1 - px0 - 64, 14, "Look for an item ball.", c[:dim])
  randomizer_note(o, c, px0 + 14, py0 + 64, px1 - px0 - 28)
  move_info(o, c, px0 + 14, py0 + 108, px1 - px0 - 28, ["Roar", :NORMAL, 2, nil, nil, 20],
            "The target is scared off and replaced by another Pokémon. In the wild, the battle ends.")
end

#================================================================ the toast (on the map)
def toast_shot(o, c, kind)
  QA_MAP.visible = true
  text = "Added to TM Vault: Ice Beam"
  tw = P2.width(PF::TEXT, text)
  end_w = kind == 1 ? P2.width(PF::TINY, "NEW") + 12 : P2.width(PF::TINY, "TM13") + 12
  w = 34 + tw + 10 + end_w + 10
  x = (SW - w) / 2; y = 10
  P2.ui.rbox(o, x, y, x + w - 1, y + 29, 7, c[:panel], c[:line])
  kind == 1 ? disc_icon(o, :ICE, x + 6, y + 3, 24) : type_icon(o, :ICE, x + 10, y + 7)
  P2.text(o, x + 34, y + 6, tw + 2, 18, text, c[:txt], PF::TEXT)
  kind == 1 ? pill(o, c, x + w - 10, y + 7, "NEW", :green, true) : pill(o, c, x + w - 10, y + 7, "TM13", :gold, true)
end

#================================================================ run
def full_shot(name, mode, hints)
  S.set(:"interface.theme_mode", mode)
  $qa_hints = nil
  om.refresh
  o = om.send(:overlay)
  hidden = om.send(:sprites).reject { |s| s.bitmap.equal?(o) }
  hidden.each { |s| s.visible = false }
  QA_MAP.visible = false
  o.clear
  c = om.send(:palette)
  yield(o, c)
  P2.hints(o, o, c, hints, :xbox) if hints
  dump(name)
  hidden.each { |s| s.visible = true }
  QA_MAP.visible = false
end

SHOTS = [["TV1_plates", :vault1, VAULT_HINTS], ["TV2_strip", :vault2, VAULT_HINTS], ["TV3_sidebar", :vault3, VAULT_HINTS],
         ["MC1_side", :compare1, COMPARE_HINTS], ["MC2_stacked", :compare2, COMPARE_HINTS], ["MC3_swap", :compare3, COMPARE_HINTS],
         ["CL1_panel", :check1, CHECK_HINTS], ["CL2_two_line", :check2, CHECK_HINTS], ["CL3_by_map", :check3, CHECK_HINTS],
         ["CL4_kind_row", :check4, CHECK_HINTS], ["CL5_kind_panel", :check5, CHECK_HINTS]].freeze
queue = []
SHOTS.each do |name, what, hints|
  [[name, 0], ["#{name}_light", 2]].each do |file, mode|
    queue << at { full_shot(file, mode, hints) { |o, c| send(what, o, c) } }
  end
end
[["TT1_disc", 1], ["TT2_type", 2]].each do |name, kind|
  [[name, 0], ["#{name}_light", 2]].each do |file, mode|
    queue << at {
      S.set(:"interface.theme_mode", mode)
      om.refresh
      o = om.send(:overlay)
      hidden = om.send(:sprites).reject { |s| s.bitmap.equal?(o) }
      hidden.each { |s| s.visible = false }
      QA_MAP.visible = true
      o.clear
      toast_shot(o, om.send(:palette), kind)
      dump(file)
      hidden.each { |s| s.visible = true }
      QA_MAP.visible = false
    }
  end
end
queue << at { S.set(:"interface.theme_mode", 0); om.send(:overlay).clear; om.refresh }
queue << I::BACK
on_map("TM Vault designs", queue)
puts "designs done"
