# encoding: utf-8
# Mockups: the Pause Menu in each Theme Mode Light design (theme_common.rb),
# over a map (KR_PREVIEW_BACKDROP).
# Usage (from this folder): ruby theme_pm_designs.rb "<KIF Beta>" <empty work dir with metrics.json>
#                           python <KR>/Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
TEST = File.join(ARGV[0], "Mods/KantoReloaded/Tools/Tests/pause_menu_preview.rb")
eval(File.read(TEST, :encoding => "UTF-8").split("#---------------------------------------------------------------- A: ")[0], binding, TEST)
require_relative "theme_common"

PM.row.replace(["kif_shop", "save"]) if PM.respond_to?(:row) && PM.row.respond_to?(:replace)
ThemeDesigns.designs.each_with_index do |(name, _words, palette), i|
  ThemeDesigns.use(palette)
  menu(name, [dmp("PM_TL#{i + 1}"), I::BACK])
end
puts "designs: #{ThemeDesigns.designs.map(&:first).join(', ')}"
