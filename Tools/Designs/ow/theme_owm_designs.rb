# encoding: utf-8
# Mockups: the Overworld Menu in each Theme Mode Light design
# (theme_common.rb), on a page with a switch, a choice, statuses and the
# gold infinity mark, over a map (KR_PREVIEW_BACKDROP).
# Usage (from this folder): ruby theme_owm_designs.rb "<KIF Beta>" <empty work dir with metrics.json>
#                           python <KR>/Tools/UIPreview/render.py "<KIF Beta>/Fonts" <work dir>
TEST = File.join(ARGV[0], "Mods/KantoReloaded/Tools/Tests/overworld_menu_preview.rb")
eval(File.read(TEST, :encoding => "UTF-8").split("#---------------------------------------------------------------- A: ")[0], binding, TEST)
require_relative "theme_common"

SR = Reloaded::OverworldMenu::SettingRows
$PokemonSystem.speedup = 1
$PokemonGlobal.repel = 0
module KIF; module LevelCap; def self.cap; 38; end; end; end
QOL_ON = Reloaded::QualityOfLife.method(:on?)
Reloaded::QualityOfLife.define_singleton_method(:on?) { |id| id == :infinite_repel }
OM.met(PkPM.new("Pidgey", :PIDGEY, 3, 10, 10, [:NORMAL]))
pg = OM.add_page("Mine")
pg["entries"] = ["quick_items", "fly", "repel", SR.key_named("Text Speed"), SR.key_named("Animations"), "speed_up", "level_cap", "quick_save"]
OM.save_layout
$Trainer.party[1].status = :POISON

ThemeDesigns.designs.each_with_index do |(name, _words, palette), i|
  ThemeDesigns.use(palette)
  on_map(name, [
    at { k = OM.pages.length - 1; OM.page_index = k; om.instance_variable_set(:@page, k); om.instance_variable_set(:@sel, 1); om.refresh },
    dmp("OWM_TL#{i + 1}"),
    I::BACK
  ])
end
puts "designs: #{ThemeDesigns.designs.map(&:first).join(', ')}"
