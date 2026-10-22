# encoding: utf-8
# Mockups: choosing a Pokémon for an item on the party screen: teaching
# Thunderbolt (a TM). KIF Beta notes each one where its HP goes: ABLE, NOT
# ABLE, LEARNED (PokemonPartyPanel#text). Pikachu knows it, Gyarados and
# Genchoke can learn it, the rest can't; the cursor is on Gyarados. The
# title says what's being chosen. Three designs.
# Sprites: python qa_assets.py "<KIF Beta>" first (writes art/ here).
# Usage (from this folder): ruby party_choose_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                           python <KR>/Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
PARTY_SWITCH_ONLY = true
load File.join(File.dirname(File.expand_path(__FILE__)), "party_switch_designs.rb")

NOTES = ["LEARNED", "NOT ABLE", "ABLE", "NOT ABLE", "ABLE", "NOT ABLE"]
NOTE_RGB = { "ABLE" => [120, 230, 150], "NOT ABLE" => [240, 110, 100], "LEARNED" => [130, 190, 250] }
CHOOSE = MONS.each_with_index.map { |m, i| m.merge(:annot => NOTES[i]) }
CHOOSE_HINTS = [[:ud, "Choose"], [A_PAD, "Teach"], [B_PAD, "Cancel"]]
TITLE = "Teach Thunderbolt to Which?"
def note_col(n); Color.new(*NOTE_RGB[n]); end

# the move being taught, at the top of the panel; the highlighted one's
# moves under it (one of them would make room)
def tm_panel(o, c, st)
  m = CHOOSE[SEL]
  top = MIX.call(c[:panel], tcol(:ELECTRIC), 0.35); bottom = MIX.call(c[:panel], c[:dark], 0.4)
  chamfer_grad(o, DX, GY, DX + DW, GY + DH, 16, top, bottom, MIX.call(c[:line], tcol(:ELECTRIC), 0.5))
  (GY + 2...GY + 137).each do |y|
    under = MIX.call(top, bottom, (y - GY).to_f / DH)
    o.fill_rect(DX + 52 + (GY + 137 - y) / 3, y, 64, 1, MIX.call(under, tcol(:ELECTRIC), 0.4))
  end
  item_icon(o, "machine_ELECTRIC", DX + DW / 2, GY + 30, 40)
  P2.text(o, DX, GY + 54, DW, 18, "Thunderbolt", c[:txt], PF::TEXT, 2)
  big_type(o, :ELECTRIC, DX + (DW - 48) / 2, GY + 76, 0.75)
  P2.small(o, DX, GY + 100, DW, 16, "Power 90 · Accuracy 100", c[:dim], 2)
  P2.small(o, DX + 8, GY + 116, DW - 16, 16, "May paralyze the target.", c[:txt], 2)
  o.fill_rect(DX + 8, GY + 137, DW - 16, 2, POKE_RED)
  P2.heading(o, DX + 8, DX + DW - 8, GY + 146, "#{m[:name]}'s Moves", c[:dim], c[:line])
  m[:moves].each_with_index do |(name, pp, max, t), j|
    yy = GY + 162 + j * 17
    P2.ui.rbox(o, DX + 8, yy + 3, DX + 12, yy + 13, 1, tcol(t))
    P2.text(o, DX + 17, yy, DW - 66, 16, name, c[:txt], PF::TEXT)
    P2.text(o, DX + DW - 48, yy + 2, 40, 12, "#{pp}/#{max}", c[:dim], PF::TINY, 1)
  end
  P2.small(o, DX + 8, GY + 236, DW - 16, 16, "It replaces one of these.", c[:dim], 2)
end

CHOOSE_D = []

# 1 Recommended: each card's note where its HP goes, as a badge in its
# colour; the panel shows the move being taught and the highlighted one's
# moves
CHOOSE_D << ["QA_CH1_note_badges", CHOOSE_HINTS, proc { |o, c|
  $annot_painter = proc do |o, c, x, y, cw, ch, m|
    col = note_col(m[:annot])
    P2.pill(o, x + cw - 10, y + ch - 30, m[:annot], Color.new(col.red / 4, col.green / 4, col.blue / 4), col, true)
  end
  party_view(o, c, TITLE, SEL, nil, proc { |o, c, st| tm_panel(o, c, st) }, CHOOSE)
  $annot_painter = nil
}]

# 2: a strip along each card's foot in its note's colour, with the note
# in it (the HP bar's place); the panel the same as 1
CHOOSE_D << ["QA_CH2_note_strips", CHOOSE_HINTS, proc { |o, c|
  $annot_painter = proc do |o, c, x, y, cw, ch, m|
    col = note_col(m[:annot])
    (y + ch - 20...y + ch - 4).each do |yy|
      inset = [12 - (y + ch - 1 - yy), 0].max
      o.fill_rect(x + 8, yy, cw - 16 - inset, 1, MIX.call(c[:dark], col, 0.35))
    end
    P2.text(o, x + 8, y + ch - 20, cw - 20, 16, m[:annot], col, PF::TINY, 2)
  end
  party_view(o, c, TITLE, SEL, nil, proc { |o, c, st| tm_panel(o, c, st) }, CHOOSE)
  $annot_painter = nil
}]

# 3: those that can't learn it are greyed out (the cursor skips them);
# the rest keep their colour with a small note; the panel shows the
# highlighted one as usual
CHOOSE_D << ["QA_CH3_grey_out", CHOOSE_HINTS, proc { |o, c|
  $annot_painter = proc do |o, c, x, y, cw, ch, m|
    col = note_col(m[:annot])
    P2.pill(o, x + cw - 10, y + ch - 30, m[:annot], Color.new(col.red / 4, col.green / 4, col.blue / 4), col, true) if m[:annot] != "NOT ABLE"
  end
  party_view(o, c, TITLE, SEL, nil, proc { |o, c, st| tm_panel(o, c, st) }, CHOOSE)
  $annot_painter = nil
  CHOOSE.each_with_index do |m, i|
    next unless m[:annot] == "NOT ABLE"
    x, y = slot_xy(i)
    t = Bitmap.new(CW, CH)
    t.fill_rect(0, 0, CW, CH, Color.new(10, 12, 18, 150))
    o.blt(x, y, t, Rect.new(0, 0, CW, CH)); t.dispose
  end
}]

run_designs("Party choose designs", CHOOSE_D)
