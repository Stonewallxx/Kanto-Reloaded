# encoding: utf-8
# Offline preview of the Pause Menu on the preview tool's stand-ins
# (Tools/UIPreview/preview.rb), run by PIF's own pause menu code
# (016_UI/001_UI_PauseMenu.rb) with KIF's own registry
# (990_KIF/000_Core/003_KIF_PauseMenu.rb) and stand-ins of KIF's entries:
# the carousel, Your Row (Add, Set as Favorite, Move), Y opening the
# Favorite, an entry and back to the menu, a locked tile, the Safari Zone,
# a Pinned entry of Kanto Reloaded's taking over KIF's Heal, the mouse,
# Open Favorite from the map, Menu Animations Off, and Reloaded Pause Menu
# Off (the game's own).
# Usage: ruby   Tools/Tests/pause_menu_preview.rb "<KIF Beta>" <work dir with metrics.json>
#        python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>
PREVIEW_SETUP_ONLY = true
load File.join(ARGV[0], "Mods/KantoReloaded/Tools/UIPreview/preview.rb")
require "fileutils"
PM = Reloaded::PauseMenu

#---------------------------------------------------------------- the game, as the menu sees it
$DEBUG = false
module Settings
  USE_CURRENT_REGION_DEX = false
  SAFARI_STEPS = 600
  KANTO = true
end
class PokemonSystem; attr_accessor :kurayqol, :tutornet; end
$PokemonSystem.kurayqol = 1
$PokemonSystem.tutornet = 1
Dex = Struct.new(:accessible_dexes)
class TrainerPM
  attr_accessor :has_pokedex, :pokedex, :party_count, :has_pokegear, :name, :can_change_outfit, :money, :save_slot, :party
end
$Trainer = TrainerPM.new
$Trainer.has_pokedex = true
$Trainer.pokedex = Dex.new([0])
$Trainer.party_count = 2
$Trainer.has_pokegear = true
$Trainer.name = "Red"
$Trainer.can_change_outfit = true
$Trainer.money = 12_450
$Trainer.save_slot = "File A"
$Trainer.party = []
GameSystem = Struct.new(:save_disabled, :menu_disabled)
$game_system = GameSystem.new(false, false)
class GameTemp; attr_accessor :in_menu, :menu_calling, :to_title, :message_window_showing, :fromkurayshop; end
$game_temp = GameTemp.new
MapPM = Struct.new(:map_id) do
  def update; end
end
$game_map = MapPM.new(5)
class PlayerPM; def straighten; end; def moving?; false; end; end
$game_player = PlayerPM.new
class TempPM; attr_accessor :menuLastChoice; end
$PokemonTemp = TempPM.new
$PokemonTemp.menuLastChoice = 0
class GlobalPM; attr_accessor :pokedexDex; end
$PokemonGlobal = GlobalPM.new
$safari = false
$contest = false
def pbInSafari?; $safari; end
def pbInBugContest?; $contest; end
SafariState = Struct.new(:steps, :ballcount)
def pbSafariState; SafariState.new(120, 25); end
def pbGetMapNameFromId(id); { 5 => "Cerulean City (Gym)", 77 => "Safari Zone" }[id] || "Map #{id}"; end
def pbGetTimeNow; Time.new(2026, 10, 21, 15, 42, 0); end      # a Wednesday, 3:42 PM
def getDayOfTheWeekName; pbGetTimeNow.strftime("%A"); end
$map_updates = 0
def pbUpdateSceneMap; $map_updates += 1; end
def pbSEPlay(*a); $log << "SE #{a[0]}"; end
def pbConfirmMessage(msg); $log << "CONFIRM #{msg}"; false; end
module SaveData
  SAVE_DIR = File.join(USERDIR, "saves")
  MANUAL_SLOTS = ("A".."H").map { |l| "File #{l}" }
  AUTO_SLOTS = ["Auto 1", "Auto 2"]
  def self.get_full_path(slot); File.join(SAVE_DIR, "#{slot}.rxdata"); end
end
FileUtils.mkdir_p(SaveData::SAVE_DIR)
SAVED = SaveData.get_full_path("File A")
File.binwrite(SAVED, "a save")
File.utime(Time.now - 12 * 60 - 5, Time.now - 12 * 60 - 5, SAVED)
# The screens the entries open (logged)
class PokemonPokedexMenu_Scene; end
class PokemonPokedexMenuScreen; def initialize(s); end; def pbStartScreen; $log << "POKEDEX"; end; end
class PokemonOptionScreen; def initialize(*a); end; def pbStartScreen(*a); $log << "OPTIONS"; end; end
class PokemonSave_Scene; end
class PokemonSaveScreen; def initialize(s); end; def pbSaveScreen; $log << "SAVE SCREEN"; false; end; end
# PIF's own windows, for the game's own menu (Reloaded Pause Menu Off)
class Window_AdvancedCommandPokemon
  attr_accessor :visible, :viewport, :commands, :index, :top_row, :x, :y, :width
  def initialize(commands); @commands = commands; @index = 0; @width = 120; end
  def resizeToFit(*a); end
  def update; end
  def dispose; @disposed = true; end
  def disposed?; @disposed; end
end
class Window_UnformattedTextPokemon < Window_AdvancedCommandPokemon
  attr_accessor :text
  def self.newWithSize(*a); new([]); end
end
def pbDisposeSpriteHash(h); h.each_value(&:dispose); end
def pbBottomLeft(w); end

# PIF's pause menu and KIF's registry, as the game has them
module KIF
  def self.marker?(*a); false; end
  module Modules; def self.proc_active?(pr); true; end; end
end
load File.join(SCRIPTS, "016_UI/001_UI_PauseMenu.rb")
load File.join(SCRIPTS, "990_KIF/000_Core/003_KIF_PauseMenu.rb")
# KIF's entries (QoLPauseMenu.rb, KurayShop.rb, TutorNet.rb), each logging
KIF::PauseMenu.add(:kif_pc, "PC", icon: "menuIcons/POKEMON", order: 10,
                   condition: proc { $PokemonSystem.kurayqol == 1 }, handler: proc { |s| $log << "KIF PC"; :stay })
KIF::PauseMenu.add(:kif_heal, "Heal Pokémon", icon: "menuIcons/POKEMON", order: 20,
                   condition: proc { $PokemonSystem.kurayqol == 1 }, handler: proc { |s| $log << "KIF HEAL"; :stay })
KIF::PauseMenu.add(:kif_shop, "Kuray Shop", icon: "menuIcons/BAG", order: 30,
                   condition: proc { $PokemonSystem.kurayqol == 1 && !pbInBugContest? }, handler: proc { |s| $log << "KIF SHOP"; :stay })
KIF::PauseMenu.add(:kif_tutornet, "Tutor.net", icon: "menuIcons/POKENAV", order: 40,
                   condition: proc { $PokemonSystem.tutornet == 1 }, handler: proc { |s| $log << "KIF TUTOR"; :stay })
# The game's classes are here now: the hooks the game makes at boot
PM.install
check("the Pause Menu's screen hooks PIF's scene, over KIF's", PokemonPauseMenu_Scene.ancestors.index(PM::SceneView).to_i <
      PokemonPauseMenu_Scene.ancestors.index(KIF::PauseMenu::SceneHook).to_i)
$scene = Scene_Map.new
class Scene_Map
  # PIF's (003_Game processing/002_Scene_Map.rb)
  def call_menu
    $game_temp.menu_calling = false
    $game_temp.in_menu = true
    $game_player.straighten
    $game_map.update
    sscene = PokemonPauseMenu_Scene.new
    sscreen = PokemonPauseMenu.new(sscene)
    sscreen.pbStartPokemonMenu
    $game_temp.in_menu = false
  end
end

# A picture of a map behind the menu, for the renders (KR_PREVIEW_BACKDROP:
# a 512x384 image), as the game's map shows through
if ENV["KR_PREVIEW_BACKDROP"].to_s != "" && File.file?(ENV["KR_PREVIEW_BACKDROP"])
  backdrop = Sprite.new(Viewport.new(0, 0, 512, 384))
  backdrop.bitmap = Bitmap.new(ENV["KR_PREVIEW_BACKDROP"])
end

#---------------------------------------------------------------- helpers
$pf_texts = Hash.new { |h, k| h[k] = [] }
Reloaded::Pixel.singleton_class.prepend(Module.new { def text(b, x, y, w, h, str, *r); $pf_texts[b.id] << str.to_s; super; end })
Bitmap.prepend(Module.new { def clear(*a); $pf_texts.delete(id); super; end })
$view = nil
PM::View.prepend(Module.new { def choose(list); $view = self; super; end })
def view; $view; end
def iv(name); view.instance_variable_get(name); end
def drawn?(sprite_name, word)
  b = iv(sprite_name).bitmap
  $pf_texts[b.id].any? { |s| s.include?(word) } || b.ops.any? { |o| o[0] == "text" && o[5].to_s.include?(word) }
end
def hints; view.send(:hint_pairs).map { |p| p[1] }; end
def car_key; iv(:@all)[iv(:@car)].key; end
def all_keys; iv(:@all).map(&:key); end
def overlay_said?(word); $pf_texts[iv(:@overlay_sprite).bitmap.id].any? { |s| s.include?(word) } || iv(:@overlay_sprite).bitmap.ops.any? { |o| o[0] == "text" && o[5].to_s.include?(word) }; end
def menu(label, queue)
  Input.queue = queue.dup
  $view = nil
  PokemonPauseMenu.new(PokemonPauseMenu_Scene.new).pbStartPokemonMenu
  check("#{label}: opened and closed", true)
rescue QueueEmpty => e
  check("#{label}: #{e.message}", false)
rescue Exception => e
  check("#{label}: #{e.class}: #{e.message} #{e.backtrace.first(5).inspect}", false)
end
S = Reloaded::Settings unless defined?(S)
LAYOUT = File.join(KR_LOCAL_DIR, "Settings", "Pause Menu.json")
PM.forget_layout
FileUtils.rm_f(LAYOUT)
# The PokeVial has its own preview (pokevial_preview.rb): out of these checks' way
Reloaded::Features.set(:pokevial, :off)
check("Reloaded Pause Menu is a Reloaded System, On", S.definition(PM::TOGGLE)[:page] == :systems && S.get(PM::TOGGLE) == true)
check("Menu Animations is on the Interface page (both menus), On", S.definition(PM::ANIMATIONS)[:page] == :interface && S.get(PM::ANIMATIONS) == true)
check("Open Favorite is a Controls action on the map, with no button at first",
      Reloaded::Controls.action(:open_favorite) && Reloaded::Controls.action(:open_favorite).area == :overworld &&
      Reloaded::Controls.bindings(:open_favorite, :keys).empty? && Reloaded::Controls.bindings(:open_favorite, :pad).empty?)

#---------------------------------------------------------------- A: the menu, Your Row, the Favorite
start = 0
menu("A pause menu", [
  at { start = Graphics.frame_count },
  dmp("pm_01_open"),
  at { check("it opened with Menu Animations: the column slid in over frames, the map kept moving (#{$map_updates})",
             iv(:@left).x == PM::View::LEFT_X0 && $map_updates >= 6) },
  at { check("All: PIF's entries with KIF's after the Bag, each known by its icon or KIF id (#{all_keys.inspect})",
             all_keys == %w[pokedex pokemon bag kif_pc kif_heal kif_shop kif_tutornet pokenav trainer outfit save options title]) },
  at { check("the trainer's tile is named after the player", iv(:@all).find { |x| x.key == "trainer" }.label == "Red") },
  at { check("the left column: Pause Menu, the money, where and when (the map's own name, no brackets)",
             %w[Pause\ Menu $12,450 Cerulean\ City Wednesday 3:42\ PM].all? { |w| drawn?(:@left, w) } && !drawn?(:@left, "(Gym)")) },
  at { check("no Favorite yet: None Yet, and no Favorite hint (#{hints.inspect})", drawn?(:@left, "None Yet") && hints == ["Choose", "Rows", "Open", "Edit", "Close"]) },
  at { check("PIF's location pop-up stays away (the column shows where you are)", $scene.showLocationWindow.nil?) },
  I::RIGHT,
  at { check("Right turns the carousel to Pokémon", car_key == "pokemon") },
  dmp("pm_02_turned"),
  I::UP,
  at { check("Up: Your Row, its Add tile (Pinned is empty, so it's skipped going up)", iv(:@focus) == :row && view.send(:current) == :add &&
             hints.include?("Add")) },
  I::UP,
  at { check("...and Up again stays (nothing above but the empty Pinned row)", iv(:@focus) == :row) },
  I::USE,
  dmp("pm_03_add_picker"),
  *[I::DOWN] * 5, I::USE,
  at { check("Add: Kuray Shop goes in Your Row, kept in the mod's Settings folder", PM.row == ["kif_shop"] && File.read(LAYOUT).include?("kif_shop")) },
  at { check("...the cursor stays on Add, to add another", view.send(:current) == :add && iv(:@col)[:row] == 1) },
  I::USE, *[I::DOWN] * 9, I::USE,
  at { check("...and Save after it (#{PM.row.inspect})", PM.row == ["kif_shop", "save"]) },
  at { check("Save's tile says when you last saved (12 Min Ago)", drawn?(:@top_sprite, "12 Min Ago")) },
  I::LEFT, I::LEFT, I::ACTION,
  dmp("pm_04_edit"),
  at { check("X on Kuray Shop: Set as Favorite, Move, Remove", overlay_said?("Set as Favorite") && overlay_said?("Move") && overlay_said?("Remove")) },
  I::USE,
  at { check("Set as Favorite: the left column shows it, Y opens it (#{hints.inspect})", PM.favorite == "kif_shop" && drawn?(:@left, "Kuray Shop") &&
             drawn?(:@left, "Opens It") && hints.include?("Favorite")) },
  I::ACTION, I::DOWN, I::USE,
  at { check("Move: picked up (#{hints.inspect})", iv(:@moving) == "kif_shop" && hints == ["Move", "Done"]) },
  I::RIGHT,
  at { check("...Right carries it along Your Row", PM.row == ["save", "kif_shop"]) },
  dmp("pm_05_moving"),
  I::USE,
  at { check("...A puts it down", iv(:@moving).nil?) },
  I::X,
  at { check("Y opens the Favorite: KIF's Kuray Shop runs, through KIF's own registry", $log.include?("KIF SHOP")) },
  at { check("...and the menu is back, as it was", iv(:@shown) && iv(:@focus) == :row) },
  dmp("pm_06_back"),
  I::DOWN, I::LEFT, I::LEFT, I::LEFT,
  at { check("Down to All, Left wraps round to Options (#{car_key})", iv(:@focus) == :all && car_key == "options") },
  I::USE,
  at { check("A opens Options (PIF's own entry code) and comes back to the menu on Options",
             $log.include?("OPTIONS") && car_key == "options" && iv(:@shown)) },
  I::BACK
])
check("B closed it: the screen's gone, where it was is kept for next time", view.instance_variable_get(:@sprite).nil? &&
      PM.cursor[:focus] == :all && PM.cursor[:car] == "options")

#---------------------------------------------------------------- B: a locked tile, the mouse
$Trainer.has_pokegear = false
PM.add_to_row("pokenav")
menu("B locked and mouse", [
  at { check("the carousel opens where it was left (Options)", car_key == "options") },
  at { check("no PokéNav: not in All, but its Your Row tile stays, locked", !all_keys.include?("pokenav") &&
             iv(:@row).map(&:key) == ["save", "kif_shop", "pokenav"] && iv(:@row)[2].index.nil?) },
  dmp("pm_07_locked"),
  [:move, *PM::View.new.send(:tile_xy, 2, PM::View::ROW_Y).map { |v| v + 20 }],
  at { check("the mouse over a tile picks it", iv(:@focus) == :row && iv(:@col)[:row] == 2) },
  I::USE,
  at { check("A on a locked tile says why", overlay_said?("You don't have a PokéNav yet.")) },
  dmp("pm_08_locked_notice"),
  I::USE,
  [:click, PM::View::CAR_CX + 86, PM::View::CAR_CY],
  at { check("a click on the carousel's next tile turns to it (#{car_key})", car_key == "title" && iv(:@focus) == :all) },
  [:wheel, -1],
  at { check("the wheel turns it too (#{car_key})", car_key == "pokedex") },
  [:rclick, 250, 216]
])
check("a right click closed it (on the carousel, where it was)", view.instance_variable_get(:@sprite).nil? && PM.cursor[:focus] == :all)
$Trainer.has_pokegear = true

#---------------------------------------------------------------- C: the Safari Zone
$safari = true
$game_map.map_id = 77
menu("C safari", [
  dmp("pm_09_safari"),
  at { check("the Safari Zone's steps and balls are in the left column", drawn?(:@left, "SAFARI ZONE") && drawn?(:@left, "Steps: 120/600") && drawn?(:@left, "Balls: 25")) },
  at { check("All has Quit, not Save; Your Row keeps Save, locked (#{all_keys.inspect})", all_keys.include?("quit") && !all_keys.include?("save") &&
             iv(:@row)[0].key == "save" && iv(:@row)[0].index.nil?) },
  at { check("...it says why", PM.lock_reason("save") == "You can't save in the Safari Zone.") },
  at { check("it opens on All, where it was left", iv(:@focus) == :all) },
  at { view.instance_variable_set(:@car, iv(:@all).index { |x| x.key == "quit" }); view.refresh },
  I::ACTION,
  at { check("Quit can't go in Your Row or be the Favorite: X just buzzes", !overlay_said?("Set as Favorite")) },
  I::USE,
  at { check("Quit is PIF's own: it asks first", $log.any? { |l| l.include?("leave the Safari Game") }) },
  I::BACK
])
$safari = false
$game_map.map_id = 5

#---------------------------------------------------------------- D: Pinned, Kanto Reloaded's own entry
PM.register(:test_vial, "PokeVial", :pinned => 2, :takes_over => :kif_heal, :icon => "Graphics/Items/POTION",
            :status => proc { ["Charges: 3/5", nil, "3/5"] }, :handler => proc { |s| $log << "VIAL"; :stay })
menu("D pinned", [
  dmp("pm_10_pinned"),
  at { check("a registered entry fills its Pinned slot", iv(:@pinned)[2] && iv(:@pinned)[2].key == "test_vial" && iv(:@pinned).compact.length == 1) },
  at { check("...and takes over KIF's Heal while it's on (#{all_keys.inspect})", all_keys.include?("test_vial") && !all_keys.include?("kif_heal")) },
  at { check("...with its status as a pill", drawn?(:@top_sprite, "3/5")) },
  I::UP, I::UP,
  at { check("Up twice: Pinned, on its only tile", iv(:@focus) == :pinned && iv(:@col)[:pinned] == 2) },
  I::LEFT,
  at { check("Left on Pinned steps over its empty slots (it stays)", iv(:@col)[:pinned] == 2) },
  I::USE,
  at { check("A opens it", $log.include?("VIAL")) },
  I::BACK
])
PM.registered.delete("test_vial")
KIF::PauseMenu.instance_variable_get(:@entries).reject! { |e| e.id == :test_vial }

#---------------------------------------------------------------- E: Open Favorite from the map
$log.clear
PM::View.prepend(Module.new { def set_visible(on); $shown_ever = true if on; super; end })
$shown_ever = false
Input.queue = [nil]
PM.open_favorite($scene)
check("Open Favorite: the Favorite runs straight from the map, the menu never shows", PM.favorite == "kif_shop" && $log.include?("KIF SHOP") && !$shown_ever)
check("...and the menu closed after it", !$game_temp.in_menu)
$PokemonSystem.kurayqol = 0
Input.queue = [dmp("pm_11_favorite_locked"), at { check("...a Favorite that can't be used now says why", overlay_said?("Turn on Kuray QoL")) }, I::USE]
begin
  PM.open_favorite($scene)
  check("...then closes", !$game_temp.in_menu)
rescue Exception => e
  check("open favorite locked: #{e.class}: #{e.message} #{e.backtrace.first(4).inspect}", false)
end
$PokemonSystem.kurayqol = 1

#---------------------------------------------------------------- F: Menu Animations Off, Reloaded Pause Menu Off
S.set(PM::ANIMATIONS, false)
menu("F no animations", [
  at { check("Menu Animations Off: it's there at once", Graphics.frame_count - $f0 <= 1) },
  I::RIGHT,
  at { check("...and the carousel turns at once", Graphics.frame_count - $f0 <= 2) },
  I::BACK
].tap { |q| q.unshift(at { $f0 = Graphics.frame_count }) })
S.set(PM::ANIMATIONS, true)
S.set(PM::TOGGLE, false)
menu("F off", [
  at { check("Reloaded Pause Menu Off: the game's own menu", $view.nil?) },
  I::BACK
])
check("...and PIF's location pop-up is back", (begin; $scene.showLocationWindow; false; rescue NoMethodError; true; end))
S.set(PM::TOGGLE, true)

#---------------------------------------------------------------- G: Theme Mode
# The map menus follow Theme Mode: Glass see-through, Light the Light
# frames' look (the map washed pale), Frost both
def rgb_of(col); [col.red, col.green, col.blue]; end
[[1, "Glass", false, 163, 154], [2, "Light", true, 244, 232], [3, "Frost", true, 181, 171]].each do |mode, name, light, panel, tile|
  S.set(Reloaded::Palette::MODE, mode)
  menu("G #{name}", [
    dmp("pm_10_theme_#{name.downcase}"),
    at { c = view.palette
         check("Theme Mode #{name}: #{light ? "the Light colours, the map washed pale" : "the Theme's own colours"}, its panel #{view.send(:panel_alpha)} and tiles #{view.send(:tile_alpha)} of 255",
               !!c[:light] == light && view.send(:panel_alpha) == panel && view.send(:tile_alpha) == tile &&
               (!light || (rgb_of(c[:green]) == [30, 140, 70] && rgb_of(c[:txt]) == rgb_of(Reloaded::Palette.current[:panel])))) },
    I::BACK
  ])
end
S.set(Reloaded::Palette::MODE, 0)
check("...and Dark again: the Theme's colours, the panel as it was (226)", !Reloaded::Palette.map_menu[:light] && Reloaded::Palette.menu_alpha(226) == 226)

#---------------------------------------------------------------- H: the PokeVial's tile
# (the PokeVial itself: pokevial_test.rb and pokevial_preview.rb)
Reloaded::Features.set(:pokevial, :on)
Reloaded::PokeVial.send(:register_menu_entries)       # into these stand-ins' KIF list, made after it booted
$alert = true
Reloaded::PokeVial.singleton_class.prepend(Module.new {
  def usable; true; end
  def low_hp_alert?; $alert; end
  def uses; 2; end
  def configured_max_uses; 4; end
})
menu("H pokevial", [
  dmp("pm_11_pokevial_glow"),
  at { check("the PokeVial in the Pinned row's third slot, its charges in the pill (#{all_keys.inspect})",
             iv(:@pinned)[2] && iv(:@pinned)[2].key == "pokevial" && drawn?(:@top_sprite, "2/4") && !all_keys.include?("kif_heal")) },
  at { check("the Low HP Reminder: its tile glows red (the alert layer)", (a = iv(:@alert_sprite)) && a.bitmap.ops.any? { |o| o[0] == "fill" }) },
  I::UP, I::UP,
  at { check("...not while the cursor's on it", iv(:@focus) == :pinned && (a = iv(:@alert_sprite)) && a.bitmap.ops.reject { |o| o[0] == "clear" }.empty?) },
  I::BACK
])
$alert = false
menu("H pokevial calm", [
  at { check("...and no glow when the party's fine", (a = iv(:@alert_sprite)).nil? || a.bitmap.ops.reject { |o| o[0] == "clear" }.empty?) },
  I::BACK
])

errors = File.read(Reloaded::Log.path).lines.grep(/ERROR|skipped/)
check("no errors or skipped hooks in Kanto Reloaded's log (#{errors.length})", errors.empty?)
errors.first(5).each { |l| puts "  " + l }
puts $failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED"
exit($failed ? 1 : 0)
