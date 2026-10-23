# encoding: utf-8
# Mockups: the Low HP Reminder on the Pause Menu's PokeVial tile (Pinned,
# and in the carousel when it's there). The designs are in lowhp_common.rb.
# Usage (from the KR folder): ruby Tools/Designs/pokevial/lowhp_pause.rb "<KIF Beta>" <work dir with metrics.json>
#                             python Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
PREVIEW_TEST = File.join(ARGV[0], "Mods/KantoReloaded/Tools/Tests/pause_menu_preview.rb")
eval(File.read(PREVIEW_TEST, :encoding => "UTF-8").split("#---------------------------------------------------------------- A: ")[0], binding, PREVIEW_TEST)
load File.join(File.dirname(File.expand_path(__FILE__)), "lowhp_common.rb")

PM.register(:pokevial, "PokeVial", :pinned => 2, :takes_over => :kif_heal, :icon => PM::ICON_DIR + "POKEVIAL",
            :status => proc { ["Charges: 2/4", nil, "2/4"] }, :handler => proc { |s| :stay })

PM::View.prepend(Module.new do
  def paint_tile(base, top, c, x, y, it, on, big = false)
    return super unless it.key.to_s == "pokevial" && $lowhp != :none
    w = big ? PM::View::SLOTS[0][1] : PM::View::TILE_W
    h = big ? PM::View::SLOTS[0][2] : PM::View::TILE_H
    LowHP.behind(base, c, x, y, x + w, y + h, false) unless on
    super(base, top, on ? c : LowHP.colours(c), x, y, it, on, big)
    LowHP.over(top, c, x + 4, y + 4)
  end
end)

LOWHP_STYLES.each do |style, name|
  [[0, ""], [2, "_light"]].each do |mode, suffix|
    $lowhp = style
    S.set(Reloaded::Palette::MODE, mode)
    menu("#{name}#{suffix}", [dmp("#{name}_pause#{suffix}"), I::BACK])
  end
end
S.set(Reloaded::Palette::MODE, 0)
puts $failed ? "SOME DESIGNS FAILED" : "designs done"
