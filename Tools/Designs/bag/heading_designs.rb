# encoding: utf-8
# Mockups: a Custom List's headings in the Bag (his ask, 2026-10-23: the
# Bag should show the sections added in the Custom Lists). Drawn by the real
# Bag on its preview's stand-ins (Tools/Tests/bag_preview.rb): Medicine on
# Custom List, Bag Order, with two headings of the player's own, a
# Favorite, and two items not on the list. Dark and Light.
#   1 Like the Editor  small capitals and a line, as the Custom List editor;
#                      Favorites under their own heading, then each heading,
#                      then Not on Your List
#   2 Pocket Colour    the same, in Medicine's colour; Favorites stay in
#                      their heading, starred
#   3 Bands            a slim band in Medicine's colour for each heading
# (BagScreen.section_style is the mockups' switch until his pick.)
# Usage (from the mod folder): ruby Tools/Designs/bag/heading_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                              python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>
TEST = File.join(ARGV[0], "Mods/KantoReloaded/Tools/Tests/bag_preview.rb")
eval(File.read(TEST, :encoding => "UTF-8").split("#---------------------------------------------------------------- helpers")[0], binding, TEST)
[[:REVIVE, 28, "Revive"], [:ANTIDOTE, 20, "Antidote"]].each { |id, n, name| GameData::Item.add(id, n, name, 2, "A medicine that revives a fainted Pokémon.", 1, 1) }
$PokemonBag.pbStoreItem(:REVIVE, 2)
$PokemonBag.pbStoreItem(:ANTIDOTE, 3)
B.set_list(2, ["#Candy", "RARECANDY", "#Healing", "POTION", "SUPERPOTION", "HYPERPOTION", "#Status", "ICEHEAL", "FULLHEAL"])
S.set(:"bag.mode2", 1)
B.set_view(2, 0)
B.toggle_favorite(:HYPERPOTION) unless B.favorite?(:HYPERPOTION)
B.refresh_seen!
B.seen!(2)
$PokemonBag.lastpocket = 2
$pad_name = "Xbox Series X Controller"
$bs = nil
Reloaded::BagScreen.scene_class.prepend(Module.new { def pbStartScene(*a); $bs = self; super; end })
[1, 2, 3].each do |d|
  Reloaded::BagScreen.section_style = d - 1
  [[0, "dark"], [2, "light"]].each do |mode, word|
    S.set(Reloaded::Palette::MODE, mode)
    Input.queue = [at { $bs.instance_variable_set(:@sel, 1); $bs.instance_variable_set(:@scroll, 0); $bs.send(:draw) }, dmp("hd-#{d}a_#{word}"),
                   at { $bs.instance_variable_set(:@sel, $bs.instance_variable_get(:@rows).length - 1); $bs.send(:draw) }, dmp("hd-#{d}b_#{word}"),
                   I::BACK]
    begin
      PokemonBagScreen.new(PokemonBag_Scene.new, $PokemonBag).pbStartScreen
    rescue QueueEmpty
      check("design #{d} #{word}: ran out of input", false)
    end
  end
end
Reloaded::BagScreen.section_style = 0
S.set(Reloaded::Palette::MODE, 0)
puts "designs done"
