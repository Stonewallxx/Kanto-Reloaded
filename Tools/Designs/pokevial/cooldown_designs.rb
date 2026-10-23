# encoding: utf-8
# Mockups: the PokeVial's cooldown wait (picked before it has recharged; the
# Cooldown setting, 5 to 45 minutes of real time between uses). Opened
# from the Overworld Menu here; the Pause Menu's tile opens the same.
# Design 1 = the old Kanto Reloaded's: a popup with a live countdown that
#            closes by itself when the PokeVial is ready.
# Design 2 = In the Dialog: the PokeVial dialog as usual, its Heal Preview
#            shown, the Use button a countdown until it's ready.
# Design 3 = Toast: no popup, a toast saying when it will be ready.
# Sprites: python ../qa/qa_assets.py "<KIF Beta>" first (writes ../qa/art).
# Usage (from this folder): ruby cooldown_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                           python <KR>/Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
load File.join(File.dirname(File.expand_path(__FILE__)), "pokevial_common.rb")

LEFT = "4:32"            # time left
DONE = 0.62              # how far the wait has gone
READY_AT = "3:47 PM"

def countdown_popup(o, c)
  w = 300; h = 168
  x = (SW - w) / 2; y = (HINT_TOP - h) / 2
  frame(o, c, x, y, w, h, "PokeVial", [2, 4])
  P2.text(o, x, y + 42, w, 14, "RECHARGING", c[:head], PF::TINY, 2)
  P2.text(o, x, y + 54, w, 30, LEFT, c[:txt], PF::TITLE, 2)
  bx0 = x + 40; bx1 = x + w - 40; by = y + 92
  PP.bar(o, c, bx0, by, bx1 - bx0, DONE, c[:selb], 5)
  P2.small(o, x, y + 102, w, 16, "Ready at #{READY_AT}. This closes by itself.", c[:dim], 2)
  button(o, c, x + w / 2 - 60, y + h - 38, x + w / 2 + 60, y + h - 10, "OK", true)
end

def in_dialog(o, c)
  vial_dialog(o, c) do |x, _y, w, _h, by|
    # the Use button, waiting: dimmed, its countdown and a filling line
    bx0 = x + 40; bx1 = x + 200
    DG.send(:button, o, c, bx0, by, bx1, by + 28, false)
    P2.text(o, bx0, by + 1, bx1 - bx0, 22, "Ready in #{LEFT}", c[:dim], PF::TEXT, 2)
    o.fill_rect(bx0 + 12, by + 23, ((bx1 - bx0 - 24) * DONE).round, 2, c[:selb])
    button(o, c, x + 214, by, x + w - 40, by + 28, "Back", true)
  end
end

def toast(o, c)
  text = "PokeVial ready in #{LEFT}"
  tw = P2.width(PF::TEXT, text)
  badge = "2 LEFT"
  bw = P2.width(PF::TINY, badge) + 12
  w = 34 + tw + 10 + bw + 10; h = 30
  x = (SW - w) / 2; y = 10
  P2.ui.rbox(o, x, y, x + w - 1, y + h - 1, 7, c[:panel], c[:line])
  vial_icon(o, x + 8, y + 4, 18, 22)
  P2.text(o, x + 34, y + 6, tw + 2, 18, text, c[:txt], PF::TEXT)
  fill = c[:light] ? mix(c[:panel2], c[:gold], 0.22) : Color.new(70, 58, 20)
  P2.pill(o, x + w - 10, y + 7, badge, fill, c[:gold], true)
end

OK_HINT = [[A_PAD, "OK"]]
DIALOG_HINTS = [[:lr, "Choose"], [A_PAD, "Select"], [B_PAD, "Back"]]
DESIGNS = [
  ["PV_CD1_countdown", OK_HINT, 0, proc { |o, c| countdown_popup(o, c) }],
  ["PV_CD1_countdown_light", OK_HINT, 2, proc { |o, c| countdown_popup(o, c) }],
  ["PV_CD2_in_dialog", DIALOG_HINTS, 0, proc { |o, c| in_dialog(o, c) }],
  ["PV_CD3_toast", nil, 0, proc { |o, c| o.clear; toast(o, c) }]
]
run_pokevial("PokeVial cooldown designs", DESIGNS)
