# encoding: utf-8
# Mockups: five styled takes on party screen Design 1 (Cards and Details),
# his ask (2026-10-21): "more styled/creative looking for the background /
# borders", with the game's big type labels (Graphics/Pictures/types.png,
# as the Summary uses) in the details panel. Same party and layout as
# QA_PS1; only the background, header, card and panel looks change.
#   S1 Type Stripe    a stripe of each type down the card's edge, pinstripes behind
#   S2 Glow           cards lit from the top in their type's colour, a soft vignette
#   S3 Watermark      each card's type symbol big and faint behind it, Poké Balls behind
#   S4 Angled         cut corners and a slash of type colour behind the sprite
#   S5 Field Notes    a paper-and-ink look: cream cards, a type tab, a ruled panel
# Sprites: python qa_assets.py "<KIF Beta>" first (writes art/ here).
# Usage (from this folder): ruby party_styled_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                           python <KR>/Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
load File.join(File.dirname(File.expand_path(__FILE__)), "party_common.rb")

MIX = Reloaded::Palette.method(:mix)
WHITE = Color.new(248, 248, 248)
POKE_RED = Color.new(220, 60, 60)

#---------------------------------------------------------------- drawing pieces
def grad(o, x0, y0, x1, y1, top, bottom, inset = nil)
  h = [y1 - y0, 1].max
  (y0...y1).each do |y|
    a, b = inset ? inset.call(y) : [0, 0]
    o.fill_rect(x0 + a, y, x1 - x0 - a - b, 1, MIX.call(top, bottom, (y - y0).to_f / h))
  end
end
# how far in a rounded box's row starts, at y
def round_inset(y0, y1, r)
  proc do |y|
    d = y - y0 < r ? r - (y - y0) : (y1 - 1 - y < r ? r - (y1 - 1 - y) : 0)
    k = d > 0 ? (r - Math.sqrt([r * r - d * d, 0].max)).round : 0
    [k, k]
  end
end
def round_grad(o, x0, y0, x1, y1, r, top, bottom, edge)
  P2.ui.rbox(o, x0, y0, x1, y1, r, edge)
  grad(o, x0 + 1, y0 + 1, x1 - 1, y1 - 1, top, bottom, round_inset(y0 + 1, y1 - 1, r - 1))
end
# a box with its top-left and bottom-right corners cut
def chamfer(o, x0, y0, x1, y1, cut, fill, edge)
  (y0...y1).each do |y|
    l = [cut - (y - y0), 0].max; r = [cut - (y1 - 1 - y), 0].max
    o.fill_rect(x0 + l, y, x1 - x0 - l - r, 1, edge)
  end
  (y0 + 1...y1 - 1).each do |y|
    l = [cut - (y - y0), 0].max; r = [cut - (y1 - 1 - y), 0].max
    o.fill_rect(x0 + 1 + l, y, x1 - x0 - 2 - l - r, 1, fill)
  end
end
# a cut-corner box lit from the top (top colour to bottom colour)
def chamfer_grad(o, x0, y0, x1, y1, cut, top, bottom, edge)
  chamfer(o, x0, y0, x1, y1, cut, edge, edge)
  inset = proc { |y| [[cut - (y - y0), 0].max, [cut - (y1 - 1 - y), 0].max] }
  grad(o, x0 + 1, y0 + 1, x1 - 1, y1 - 1, top, bottom, inset)
end
def circle(o, cx, cy, r, col)
  (0...360).step(3) { |a| t = a * Math::PI / 180; o.fill_rect((cx + r * Math.cos(t)).round, (cy + r * Math.sin(t)).round, 1, 1, col) }
end
def disc(o, cx, cy, r, top, bottom = nil)
  (-r..r).each do |dy|
    w = Math.sqrt(r * r - dy * dy).round
    o.fill_rect(cx - w, cy + dy, 2 * w + 1, 1, bottom && dy > 0 ? bottom : top)
  end
end
def pokeball(o, cx, cy, r)
  disc(o, cx, cy, r, Color.new(30, 30, 36))
  disc(o, cx, cy, r - 1, POKE_RED, WHITE)
  o.fill_rect(cx - r, cy - 1, 2 * r + 1, 2, Color.new(30, 30, 36))
  disc(o, cx, cy, 3, Color.new(30, 30, 36)); disc(o, cx, cy, 2, WHITE)
end
# the white symbol of a type's small icon, k times as big, mixed toward bg
# by t (a faint watermark), top-left at x, y
def symbol(o, type, x, y, k, bg, t)
  sheet = qa_bmp(File.join(KR_DIR, "Graphics", "OverworldMenu", "typesSmall16.png"))
  row = TYPE_ROW[type] * 16
  (2..13).each do |sy|
    (2..13).each do |sx|          # inside the icon's light border
      px = sheet.get_pixel(sx, row + sy)
      next unless px.alpha > 128 && px.red > 200 && px.green > 200 && px.blue > 200
      o.fill_rect(x + sx * k, y + sy * k, k, k, MIX.call(bg, tcol(type), t))
    end
  end
end
# the game's big type label (64 x 28), as the Summary shows it
def big_type(o, type, x, y, k = 1.0)
  sheet = qa_bmp(File.join(GFX, "Pictures", "types.png"))
  o.stretch_blt(Rect.new(x, y, (64 * k).round, (28 * k).round), sheet, Rect.new(0, TYPE_ROW[type] * 28, 64, 28))
end
def fainted?(m); m[:hp] == 0 && !m[:egg]; end
def tone(c, m); m[:egg] ? c[:line] : (fainted?(m) ? RED_T : tcol(m[:types][0])); end

#---------------------------------------------------------------- what's on a card and the panel (as QA_PS1)
def card_content(o, c, x, y, cw, ch, m, ink = nil)
  ink ||= c[:txt]
  art(o, m[:sp], x + 30, y + 46, m[:egg] ? 34 : 50)
  evolock(o, x + 6, y + 64) if m[:evolock]
  if m[:egg]
    P2.text(o, x + 60, y + 28, cw - 66, 18, "Egg", ink, PF::TEXT)
    if m[:annot] && $annot_painter
      $annot_painter.call(o, c, x, y, cw, ch, m)
    else
      P2.small(o, x + 60, y + 48, cw - 66, 16, "Soon", c[:dim])
    end
    return
  end
  item_icon(o, m[:item], x + cw - 14, y + 14, 20) if m[:item]
  P2.text(o, x + 60, y + 6, cw - 84, 18, m[:name], ink, PF::TEXT)
  lw = level(o, m, x + 60, y + 28)
  marks(o, m, x + 60 + lw + 5, y + 30)
  type_icons(o, m[:types], x + 60, y + 44)
  status(o, m, x + cw - 6, y + 44)
  if m[:annot]
    $annot_painter ? $annot_painter.call(o, c, x, y, cw, ch, m) : nil
    return
  end
  P2.text(o, x + 60, y + 66, cw - 66, 12, "#{m[:hp]}/#{m[:tot]}", m[:hp] > 0 ? ink : RED_T, PF::TINY, 1)
  # outlined, the bar keeps clear of the cut corner
  $hp_outline ? hpbar(o, c, x + 10, y + ch - 13, cw - 28, m) : hpbar(o, c, x + 8, y + ch - 12, cw - 16, m)
end
def details_content(o, c, dx, dy, dw, m, ink = nil, dim = nil, line = nil)
  ink ||= c[:txt]; dim ||= c[:dim]; line ||= c[:line]
  art(o, m[:sp], dx + dw / 2, dy + 40, 64)
  P2.text(o, dx, dy + 76, dw, 18, m[:name], ink, PF::TEXT, 2)
  level(o, m, dx, dy + 95, 2, dw)
  k = $type_scale || 1.0
  lw = (64 * k).round; lh = (28 * k).round
  tw = m[:types].length * (lw + 2) - 2
  m[:types].each_with_index { |t, j| big_type(o, t, dx + (dw - tw) / 2 + j * (lw + 2), dy + 110 + (28 - lh) / 2, k) }
  P2.heading(o, dx + 8, dx + dw - 8, dy + 144, "About", dim, line)
  [["Nature", m[:nature]], ["Ability", m[:ability]], ["Item", "None"]].each_with_index do |(k, v), j|
    P2.small(o, dx + 8, dy + 158 + j * 16, 60, 16, k, dim)
    P2.small(o, dx + 66, dy + 158 + j * 16, dw - 74, 16, v, ink)
  end
  P2.heading(o, dx + 8, dx + dw - 8, dy + 208, "Moves", dim, line)
  m[:moves].each_with_index do |(name, pp, max, t), j|
    yy = dy + 222 + j * 17
    P2.ui.rbox(o, dx + 8, yy + 3, dx + 12, yy + 13, 1, tcol(t))
    P2.text(o, dx + 17, yy, dw - 66, 16, name, ink, PF::TEXT)
    P2.text(o, dx + dw - 48, yy + 2, 40, 12, "#{pp}/#{max}", pp < max ? AMBER_T : dim, PF::TINY, 1)
  end
end

CW = 152; CH = 96; GX = 8; GY = 38
DX = GX + 2 * CW + 14; DW = SW - 8 - DX; DH = 3 * CH + 12
def layout(o, c, st)
  o.clear
  st[:bg].call(o, c)
  st[:header].call(o, c, "Party")
  P2.hints(o, o, c, $qa_hints)
  MONS.each_with_index do |m, i|
    x = GX + (i % 2) * (CW + 6); y = GY + (i / 2) * (CH + 6)
    ink = st[:card].call(o, c, x, y, x + CW, y + CH, m, i == SEL)
    card_content(o, c, x, y, CW, CH, m, ink.is_a?(Color) ? ink : nil)
  end
  m = MONS[SEL]
  inks = st[:details].call(o, c, DX, GY, DX + DW, GY + DH, m)
  details_content(o, c, DX, GY, DW, m, *(inks.is_a?(Array) ? inks : []))
end
def plain_header(o, c, title, fill = nil)
  o.fill_rect(0, 0, SW, 30, fill || c[:panel])
  o.fill_rect(0, 30, SW, 1, c[:line])
  P2.text(o, 0, 4, SW, 22, title, c[:txt], PF::ROW, 2)
end

DESIGNS = []

# S1 Type Stripe: pinstripes behind; each card has a stripe of its type
# down the left edge (a fusion or dual type splits it); a Poké Ball by the
# title and a red line under the header; the panel's top band in the
# highlighted one's type colour
DESIGNS << ["QA_PS1a_type_stripe", MAIN_HINTS, proc { |o, c|
  layout(o, c, {
    :bg => proc { |o, c|
      o.fill_rect(0, 0, SW, SH, c[:bg])
      pin = MIX.call(c[:bg], c[:line], 0.45)
      (31...HINT_TOP).each { |y| ((y % 10)...SW).step(10) { |x| o.fill_rect(x, y, 1, 1, pin) } }
    },
    :header => proc { |o, c, t|
      plain_header(o, c, t)
      o.fill_rect(0, 29, SW, 2, POKE_RED)
      tw = P2.width(PF::ROW, t)
      pokeball(o, SW / 2 - tw / 2 - 16, 15, 8)
    },
    :card => proc { |o, c, x0, y0, x1, y1, m, sel|
      P2.ui.rbox(o, x0, y0, x1, y1, 6, sel ? c[:sel] : c[:panel2], sel ? c[:selb] : c[:line])
      ts = m[:egg] ? [] : m[:types]
      ts.each_with_index do |t, k|
        h = (y1 - y0 - 8) / ts.length
        o.fill_rect(x0 + 3, y0 + 4 + k * h, 4, h, fainted?(m) ? MIX.call(tcol(t), c[:dark], 0.5) : tcol(t))
      end
      nil
    },
    :details => proc { |o, c, x0, y0, x1, y1, m|
      P2.ui.rbox(o, x0, y0, x1, y1, 6, c[:panel], c[:line])
      grad(o, x0 + 1, y0 + 1, x1 - 1, y0 + 80, MIX.call(c[:panel], tcol(m[:types][0]), 0.45), c[:panel], round_inset(y0 + 1, y0 + 160, 5))
      nil
    }
  })
}]

# S2 Glow: a soft vignette with a dot grid; cards lit from the top in their
# type's colour with a bright top edge; the highlighted card glows
DESIGNS << ["QA_PS1b_glow", MAIN_HINTS, proc { |o, c|
  layout(o, c, {
    :bg => proc { |o, c|
      grad(o, 0, 0, SW, SH, MIX.call(c[:bg], c[:sel], 0.35), MIX.call(c[:bg], Color.new(0, 0, 0), 0.4))
      dot = MIX.call(c[:bg], c[:line], 0.6)
      (40...HINT_TOP).step(12) { |y| (6...SW).step(12) { |x| o.fill_rect(x, y, 1, 1, dot) } }
    },
    :header => proc { |o, c, t|
      grad(o, 0, 0, SW, 30, MIX.call(c[:panel], c[:selb], 0.25), c[:panel])
      o.fill_rect(0, 30, SW, 1, MIX.call(c[:line], c[:selb], 0.5))
      P2.text(o, 0, 4, SW, 22, t, c[:txt], PF::ROW, 2)
    },
    :card => proc { |o, c, x0, y0, x1, y1, m, sel|
      if sel
        P2.ui.rbox(o, x0 - 3, y0 - 3, x1 + 3, y1 + 3, 9, MIX.call(c[:bg], c[:selb], 0.25))
        P2.ui.rbox(o, x0 - 1, y0 - 1, x1 + 1, y1 + 1, 7, MIX.call(c[:bg], c[:selb], 0.6))
      end
      top = MIX.call(c[:panel2], tone(c, m), m[:egg] ? 0.1 : 0.5)
      round_grad(o, x0, y0, x1, y1, 6, top, MIX.call(c[:panel2], c[:dark], 0.5), sel ? c[:selb] : MIX.call(c[:line], tone(c, m), 0.4))
      o.fill_rect(x0 + 6, y0 + 1, x1 - x0 - 12, 1, MIX.call(tone(c, m), WHITE, 0.4)) unless m[:egg]
      nil
    },
    :details => proc { |o, c, x0, y0, x1, y1, m|
      round_grad(o, x0, y0, x1, y1, 6, MIX.call(c[:panel], tcol(m[:types][0]), 0.4), MIX.call(c[:panel], c[:dark], 0.4), MIX.call(c[:line], tcol(m[:types][0]), 0.5))
      nil
    }
  })
}]

# S3 Watermark: faint Poké Balls behind everything; each card's type symbol
# big and faint on its right; the panel carries the highlighted one's
# symbols huge behind its sprite
DESIGNS << ["QA_PS1c_watermark", MAIN_HINTS, proc { |o, c|
  layout(o, c, {
    :bg => proc { |o, c|
      o.fill_rect(0, 0, SW, SH, c[:bg])
      ring = MIX.call(c[:bg], c[:line], 0.5)
      (0..SW + 64).step(96) do |x|
        (40..HINT_TOP + 40).step(96) do |y|
          xx = x + ((y / 96) % 2) * 48
          circle(o, xx, y, 30, ring); o.fill_rect(xx - 30, y, 61, 1, ring); circle(o, xx, y, 7, ring)
        end
      end
      o.fill_rect(0, HINT_TOP, SW, SH - HINT_TOP, c[:bg])
    },
    :header => proc { |o, c, t| plain_header(o, c, t) },
    :card => proc { |o, c, x0, y0, x1, y1, m, sel|
      fill = fainted?(m) ? MIX.call(c[:panel2], RED_T, 0.22) : tint(c, m, sel)
      P2.ui.rbox(o, x0, y0, x1, y1, 6, fill, sel ? c[:selb] : c[:line])
      symbol(o, m[:types][0], x1 - 70, y0 + 14, 4, fill, 0.22) unless m[:egg]
      nil
    },
    :details => proc { |o, c, x0, y0, x1, y1, m|
      P2.ui.rbox(o, x0, y0, x1, y1, 6, c[:panel], c[:line])
      symbol(o, m[:types][0], x0 + (x1 - x0) / 2 - 56, y0 - 2, 7, c[:panel], 0.16)
      nil
    }
  })
}]

# S4 Angled: broad diagonal bands behind; cards with two corners cut and a
# slash of their type's colour behind the sprite; an angled title plate
DESIGNS << ["QA_PS1d_angled", MAIN_HINTS, proc { |o, c|
  layout(o, c, {
    :bg => proc { |o, c|
      o.fill_rect(0, 0, SW, SH, c[:bg])
      band = MIX.call(c[:bg], c[:panel2], 0.5)
      (31...HINT_TOP).each { |y| (-SH..SW).step(56) { |x| o.fill_rect(x + y, y, 20, 1, band) } }
    },
    :header => proc { |o, c, t|
      o.fill_rect(0, 0, SW, 31, c[:bg])
      tw = P2.width(PF::ROW, t) + 60
      x0 = (SW - tw) / 2
      (0...28).each { |y| o.fill_rect(x0 + 14 - y / 2, y, tw, 1, c[:panel]) }
      (0...28).each { |y| o.fill_rect(x0 + 14 - y / 2, y, 3, 1, c[:selb]); o.fill_rect(x0 + tw + 11 - y / 2, y, 3, 1, c[:selb]) }
      o.fill_rect(0, 28, SW, 2, c[:selb])
      P2.text(o, 0, 3, SW, 22, t, c[:txt], PF::ROW, 2)
    },
    :card => proc { |o, c, x0, y0, x1, y1, m, sel|
      chamfer(o, x0, y0, x1, y1, 12, sel ? c[:sel] : c[:panel2], sel ? c[:selb] : c[:line])
      unless m[:egg]
        col = MIX.call(sel ? c[:sel] : c[:panel2], tone(c, m), 0.55)
        (y0 + 1...y1 - 1).each { |y| o.fill_rect(x0 + 8 + (y1 - y) / 3, y, 30, 1, col) }
      end
      nil
    },
    :details => proc { |o, c, x0, y0, x1, y1, m|
      chamfer(o, x0, y0, x1, y1, 16, c[:panel], c[:line])
      col = MIX.call(c[:panel], tcol(m[:types][0]), 0.4)
      (y0 + 1...y0 + 90).each { |y| o.fill_rect(x0 + 40 + (y0 + 90 - y) / 2, y, 70, 1, col) }
      nil
    }
  })
}]

# S5 Field Notes: a paper-and-ink look on a dark desk: cream cards with a
# type-coloured tab, dark ink; the panel ruled like a notebook page
INK = Color.new(46, 40, 34)
PAPER = Color.new(236, 226, 204)
PAPER_DIM = Color.new(120, 106, 88)
DESIGNS << ["QA_PS1e_field_notes", MAIN_HINTS, proc { |o, c|
  $level_col = Color.new(176, 104, 16)     # gold reads poorly on paper
  layout(o, c, {
    :bg => proc { |o, c|
      grad(o, 0, 0, SW, SH, Color.new(58, 44, 34), Color.new(30, 22, 18))
      grain = Color.new(70, 54, 42)
      (40...HINT_TOP).step(7) { |y| o.fill_rect(0, y, SW, 1, grain) }
    },
    :header => proc { |o, c, t|
      o.fill_rect(0, 0, SW, 30, Color.new(40, 30, 24))
      o.fill_rect(0, 30, SW, 1, Color.new(90, 70, 54))
      P2.text(o, 0, 4, SW, 22, t, PAPER, PF::ROW, 2)
    },
    :card => proc { |o, c, x0, y0, x1, y1, m, sel|
      P2.ui.rbox(o, x0 + 2, y0 + 3, x1 + 2, y1 + 3, 4, Color.new(20, 14, 10))
      paper = fainted?(m) ? Color.new(226, 196, 186) : PAPER
      P2.ui.rbox(o, x0, y0, x1, y1, 4, paper, sel ? Color.new(200, 70, 60) : Color.new(150, 132, 108))
      P2.ui.rbox(o, x0 + 1, y0 + 1, x1 - 1, y1 - 1, 3, paper, Color.new(200, 70, 60)) if sel
      o.fill_rect(x0 + 50, y0 + 4, 4, 14, tone(c, m)) unless m[:egg]
      INK
    },
    :details => proc { |o, c, x0, y0, x1, y1, m|
      P2.ui.rbox(o, x0 + 2, y0 + 3, x1 + 2, y1 + 3, 4, Color.new(20, 14, 10))
      P2.ui.rbox(o, x0, y0, x1, y1, 4, PAPER, Color.new(150, 132, 108))
      (y0 + 150..y1 - 6).step(17) { |y| o.fill_rect(x0 + 6, y + 15, x1 - x0 - 12, 1, Color.new(200, 186, 160)) }
      o.fill_rect(x0 + 6, y0 + 4, x1 - x0 - 12, 3, tcol(m[:types][0]))
      [INK, PAPER_DIM, Color.new(170, 150, 120)]
    }
  })
  $level_col = nil
}]

# 6, his pick (2026-10-21): Glow, with a little smaller type labels on the
# right panel, the red line under the header from Type Stripe, the slash of
# type colour behind the sprite from Angled on the party cards only, and
# Angled's plates (two corners cut) for the cards and the panel; then (his
# next ask) HP bars outlined, a red line under the panel's type labels, and
# an angled band of the Pokémon's type colour above it
# the look he locked in (QA_PS1f), for the next screens' mockups too
def his_mix_style
  return {
      :bg => proc { |o, c|
        grad(o, 0, 0, SW, SH, MIX.call(c[:bg], c[:sel], 0.35), MIX.call(c[:bg], Color.new(0, 0, 0), 0.4))
        dot = MIX.call(c[:bg], c[:line], 0.6)
        (40...HINT_TOP).step(12) { |y| (6...SW).step(12) { |x| o.fill_rect(x, y, 1, 1, dot) } }
      },
      :header => proc { |o, c, t|
        grad(o, 0, 0, SW, 30, MIX.call(c[:panel], c[:selb], 0.25), c[:panel])
        o.fill_rect(0, 29, SW, 2, POKE_RED)
        P2.text(o, 0, 4, SW, 22, t, c[:txt], PF::ROW, 2)
      },
      :card => proc { |o, c, x0, y0, x1, y1, m, sel|
        cut = 12
        if sel
          chamfer(o, x0 - 3, y0 - 3, x1 + 3, y1 + 3, cut + 2, MIX.call(c[:bg], c[:selb], 0.25), MIX.call(c[:bg], c[:selb], 0.25))
          chamfer(o, x0 - 1, y0 - 1, x1 + 1, y1 + 1, cut + 1, MIX.call(c[:bg], c[:selb], 0.6), MIX.call(c[:bg], c[:selb], 0.6))
        end
        top = MIX.call(c[:panel2], tone(c, m), m[:egg] ? 0.1 : 0.5)
        bottom = MIX.call(c[:panel2], c[:dark], 0.5)
        chamfer_grad(o, x0, y0, x1, y1, cut, top, bottom, sel ? c[:selb] : MIX.call(c[:line], tone(c, m), 0.4))
        unless m[:egg]
          (y0 + 2...y1 - 2).each do |y|
            under = MIX.call(top, bottom, (y - y0).to_f / (y1 - y0))
            o.fill_rect(x0 + 8 + (y1 - y) / 3, y, 30, 1, MIX.call(under, tone(c, m), 0.45))
          end
          o.fill_rect(x0 + 13, y0 + 1, x1 - x0 - 16, 1, MIX.call(tone(c, m), WHITE, 0.4))
        end
        nil
      },
      :details => proc { |o, c, x0, y0, x1, y1, m|
        top = MIX.call(c[:panel], tcol(m[:types][0]), 0.4); bottom = MIX.call(c[:panel], c[:dark], 0.4)
        chamfer_grad(o, x0, y0, x1, y1, 16, top, bottom, MIX.call(c[:line], tcol(m[:types][0]), 0.5))
        # the angled band of its type behind the sprite, down to the red line
        line_y = y0 + 137
        (y0 + 2...line_y).each do |y|
          under = MIX.call(top, bottom, (y - y0).to_f / (y1 - y0))
          o.fill_rect(x0 + 52 + (line_y - y) / 3, y, 64, 1, MIX.call(under, tcol(m[:types][0]), 0.4))
        end
        o.fill_rect(x0 + 8, line_y, x1 - x0 - 16, 2, POKE_RED)
        nil
      }
    }
end
def his_mix(o, c)
  $type_scale = 0.75
  $hp_outline = Color.new(150, 166, 188)
  layout(o, c, his_mix_style)
  $type_scale = nil
  $hp_outline = nil
end
DESIGNS << ["QA_PS1f_his_mix", MAIN_HINTS, proc { |o, c| his_mix(o, c) }]

run_designs("Party screen, styled", DESIGNS) unless defined?(PARTY_LOOK_ONLY)
