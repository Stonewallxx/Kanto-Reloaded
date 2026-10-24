# encoding: utf-8
# Mockups: new colours for the Bag's pockets and stronger name colours (his
# ask, 2026-10-23: "those colors just don't go well", and they and the TM
# Vault's type colours aren't saturated enough). Drawn by the real screens
# on their previews' stand-ins.
#   bag    each pocket palette (BagScene.pocket_style: 0 now, 1 Spectrum,
#          2 Icon Hues, 3 Rainbow) on the Bag's Every Pocket list, one item
#          per pocket, in Vivid names: pockets 1-4 and 5-8, Dark and Light
#   vault  each name style (PartyPaint.ink_style: 0 now, 1 Vivid, 2 Pure,
#          3 Neon) on the TM Vault's list, Dark and Light
# His picks: Spectrum and Vivid, now the screens' only colours; the options
# were drawn with switches the screens had for them (the commit "Colour
# mockups"), so this draws the built ones.
# Usage (from the mod folder): ruby Tools/Designs/bag/colour_designs.rb "<KIF Beta>" <work dir with metrics.json> bag|vault
#                              python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>
WHAT = ARGV[2].to_s
if WHAT == "bag"
  TEST = File.join(ARGV[0], "Mods/KantoReloaded/Tools/Tests/bag_preview.rb")
  eval(File.read(TEST, :encoding => "UTF-8").split("#---------------------------------------------------------------- helpers")[0], binding, TEST)
  [[:POKEBALL, 210, "Poké Ball", 3, "A device for catching wild Pokémon.", 0, 1],
   [:GRASSMAIL, 500, "Grass Mail", 6, "Stationery featuring a print of a refreshingly green field.", 0, 0],
   [:XATTACK, 700, "X Attack", 7, "An item that boosts the Attack stat of a Pokémon while it remains in battle.", 0, 1]].each { |a| GameData::Item.add(*a) }
  $PokemonBag = PokemonBag.new
  [:REPEL, :POTION, :POKEBALL, :TM24, :ORANBERRY, :GRASSMAIL, :XATTACK, :BICYCLE].each { |i| $PokemonBag.pbStoreItem(i, 1) }
  B.refresh_seen!
  $bs = nil
  Reloaded::BagScreen.scene_class.prepend(Module.new { def pbStartScene(*a); $bs = self; super; end })
  $pad_name = "Xbox Series X Controller"
  every = proc do |scroll_to|
    at {
      $bs.instance_variable_set(:@query, "")
      $bs.send(:build_rows)
      rows = $bs.instance_variable_get(:@rows)
      $bs.instance_variable_set(:@sel, scroll_to == :end ? rows.length - 1 : 1)
      $bs.send(:draw)
    }
  end
  [1].each do |n|
    [[0, "dark"], [2, "light"]].each do |mode, word|
      S.set(Reloaded::Palette::MODE, mode)
      Input.queue = [every.call(:start), dmp("pk-#{n}-a_#{word}"), every.call(:end), dmp("pk-#{n}-b_#{word}"), I::BACK, I::BACK]
      begin
        PokemonBagScreen.new(PokemonBag_Scene.new, $PokemonBag).pbStartScreen
      rescue QueueEmpty
        nil
      end
    end
  end
  S.set(Reloaded::Palette::MODE, 0)
else
  TEST = File.join(ARGV[0], "Mods/KantoReloaded/Tools/Tests/tm_vault_preview.rb")
  eval(File.read(TEST, :encoding => "UTF-8").split("#---------------------------------------------------------------- A: the Vault")[0], binding, TEST)
  $pad_name = "Xbox Series X Controller"
  [1].each do |n|
    fresh_vault
    $Trainer.party = make_party
    [[0, "dark"], [2, "light"]].each do |mode, word|
      S.set(Reloaded::Palette::MODE, mode)
      vault("ink #{n} #{word}", [dmp("ink-#{n}_#{word}"), I::BACK])
    end
  end
  S.set(Reloaded::Palette::MODE, 0)
end
puts "designs done"
