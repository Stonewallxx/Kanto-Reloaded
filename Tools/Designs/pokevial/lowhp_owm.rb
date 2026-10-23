# encoding: utf-8
# Mockups: the Low HP Reminder on the Overworld Menu's PokeVial row (Main),
# its charges as little Poke Balls. The designs are in lowhp_common.rb.
# Sprites: python ../qa/qa_assets.py "<KIF Beta>" first (writes ../qa/art).
# Usage (from this folder): ruby lowhp_owm.rb "<KIF Beta>" <work dir with metrics.json>
#                           python <KR>/Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
load File.join(File.dirname(File.expand_path(__FILE__)), "pokevial_common.rb")
load File.join(File.dirname(File.expand_path(__FILE__)), "lowhp_common.rb")

OM.register(:pokevial, :name => "PokeVial", :kind => :action, :priority => 25,
            :paint => proc { |b, x1, y, h, c, _room| LowHP.balls(b, c, x1, y + h / 2, 2, 4) },
            :description => "Heals your party.", :handler => proc { |_m| nil })

Reloaded::OverworldMenuScreen.prepend(Module.new do
  def paint_row(b, c, e, y, on)
    return super unless e.key.to_s == "pokevial" && $lowhp != :none
    x0 = Reloaded::OverworldMenuScreen::PANEL_X0 + 4
    x1 = Reloaded::OverworldMenuScreen::PANEL_X1 - 4
    LowHP.behind(b, c, x0, y, x1, y + Reloaded::OverworldMenuScreen::ROW_H - 2, true) unless on
    super(b, on ? c : (($lowhp == :name) ? LowHP.colours(c) : c), e, y, on)
    LowHP.over(b, c, x0 + 8 + P2.width(PF::ROW, OM.label(e)) + 6, y + 8)
  end
end)

queue = []
LOWHP_STYLES.each do |style, name|
  [[0, ""], [2, "_light"]].each do |mode, suffix|
    queue << at do
      $lowhp = style
      S.set(:"interface.theme_mode", mode)
      shot("#{name}_owm#{suffix}", nil) { |_o, _c| }
    end
  end
end
queue << at { $lowhp = :none; S.set(:"interface.theme_mode", 0); om.refresh }
queue << I::BACK
on_map("PokeVial Low HP designs", queue)
puts "designs done"
