# encoding: utf-8
# Mockups: the details panel's band (his ask, 2026-10-22): from the top
# right of the whole panel to its bottom left, not only down to the red line.
# Now      = the band behind the sprite, down to the red line.
# Design 1 = Full Diagonal: corner to corner, the same strength all the way.
# Design 2 = Fades Out: corner to corner, fading away toward the bottom left.
# Design 3 = Softer Below the Line: corner to corner, fainter behind About
#            and Moves.
# Design 4 = Two Bands: corner to corner, a thin second band beside it.
# Each in Dark (Pikachu, Gyarados, the menu) and Light.
# Usage (from the KR folder): ruby Tools/Designs/party/band_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                             python Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
PARTY_PREVIEW_SETUP_ONLY = true
load File.join(ARGV[0], "Mods/KantoReloaded/Tools/Tests/party_screen_preview.rb")

$band = :now

PS.scene_class.prepend(Module.new do
  def panel_plate(base, c, col, line_y = PP::GY + PP::LINE_Y, bx = PP::DX + 52, bw = 64)
    return super if $band == :now
    x0, y0, w, h, cut = PP::DX, PP::GY, PP::DW, PP::DH, 16
    top = mix(c[:panel], col, 0.4)
    bottom = mix(c[:panel], c[:dark], 0.4)
    chamfer_grad(base, x0, y0, x0 + w, y0 + h, cut, top, bottom, mix(c[:line], col, 0.5))
    bands = $band == :twin ? [[0, 56, 0.4], [40, 8, 0.4]] : [[0, 64, nil]]
    (y0 + 1...y0 + h - 1).each do |y|
      t = (y - y0).to_f / h
      in0 = x0 + 1 + [cut - (y - y0), 0].max
      in1 = x0 + w - 1 - [cut - (y0 + h - 1 - y), 0].max
      under = mix(top, bottom, t)
      mid = x0 + w - t * w                                   # top right to bottom left
      bands.each do |off, width, k|
        k ||= case $band
              when :fade then 0.5 * (1 - t) + 0.06
              when :soft then y < line_y ? 0.4 : 0.18
              else 0.4
              end
        a = [(mid + off - width / 2.0).round, in0].max
        b = [(mid + off + width / 2.0).round, in1].min
        base.fill_rect(a, y, b - a, 1, mix(under, col, k)) if b > a
      end
    end
    base.fill_rect(x0 + 8, line_y, w - 16, 2, PP::POKE_RED)
  end
end)

[[:now, "PB0_now"], [:full, "PB1_full"], [:fade, "PB2_fade"], [:soft, "PB3_soft"], [:twin, "PB4_twin"]].each do |style, name|
  $band = style
  S.set(Reloaded::Palette::MODE, 0)
  $Trainer.party = make_party
  party_screen("#{name} dark", [dmp("#{name}_pikachu"), I::DOWN, dmp("#{name}_gyarados"), I::UP, I::USE, dmp("#{name}_menu"),
                                I::BACK, I::BACK])
  S.set(Reloaded::Palette::MODE, 2)
  party_screen("#{name} light", [dmp("#{name}_light"), I::BACK])
end
S.set(Reloaded::Palette::MODE, 0)
puts $failed ? "SOME DESIGNS FAILED" : "designs done"
