# encoding: utf-8
# Offline preview of the Overworld Menu on the preview tool's stand-ins
# (Tools/UIPreview/preview.rb), opened the way the game opens it (F on the
# map, through Reloaded Controls), with stand-ins of the game's Bag, items,
# field moves, save screen, time and Safari Zone: the pages, Quick Items, a
# Repel, the toggles, the Info page, the page editor (a page of your own),
# Fly, the Time Changer, Quick Save, the newer rows (Quest Log, Bicycle,
# Pokédex, Badges, Shiny Odds, coins, roaming Pokémon, the ∞ marks), the
# cutscene guard, the Safari Zone's Quit, the mouse and Menu Animations Off.
# Usage: ruby   Tools/Tests/overworld_menu_preview.rb "<KIF Beta>" <work dir with metrics.json>
#        python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>
PREVIEW_SETUP_ONLY = true
load File.join(ARGV[0], "Mods/KantoReloaded/Tools/UIPreview/preview.rb")
require "fileutils"
OM = Reloaded::OverworldMenu
S = Reloaded::Settings unless defined?(S)

#---------------------------------------------------------------- the game, as the menu sees it
module Settings
  SAFARI_STEPS = 600
end
AUTOSAVE_ENABLED_SWITCH = 48 unless defined?(AUTOSAVE_ENABLED_SWITCH)
SPEEDUP_STAGES = [1, 2, 3]
$GameSpeed = 0
class PokemonSystem; attr_accessor :runstyle, :battlescene, :textspeed, :speedup; end
$PokemonSystem.runstyle = 0
$PokemonSystem.battlescene = 0
$PokemonSystem.textspeed = 0
$PokemonSystem.speedup = 0
$game_switches = Hash.new(false)
$game_variables = Hash.new(0)
class PkPM
  attr_accessor :name, :level, :hp, :totalhp, :types, :moves, :egg, :species, :status, :gender, :shiny, :item_id
  def initialize(name, species, level, hp, total, types, moves = [], egg = false)
    @name, @species, @level, @hp, @totalhp, @types, @moves, @egg = name, species, level, hp, total, types, moves, egg
  end
  def egg?; @egg; end
  def hasMove?(m); @moves.include?(m); end
  def shiny?; @shiny ? true : false; end
  def dex; { :PIKACHU => 25, :PIDGEOT => 18, :GYARADOS => 130, :EEVEE => 133, :DITTO => 132 }[@species] || 1; end
end
class DexPM; def owned?(s); s == :PIDGEY; end; def seen?(s); [:PIDGEY, :RATTATA, :TENTACOOL, :MAGIKARP].include?(s); end; end
class QuestPM; attr_accessor :name, :completed, :type; def initialize(n, t); @name, @type, @completed = n, t, false; end; end
class TrainerOM
  attr_accessor :party, :pokedex, :quests, :save_slot, :money, :name
  def party_count; @party.length; end
end
$Trainer = TrainerOM.new
$Trainer.party = [PkPM.new("Pikachu", :PIKACHU, 34, 78, 95, [:ELECTRIC]),
                  PkPM.new("Pidgeot", :PIDGEOT, 36, 120, 120, [:NORMAL, :FLYING], [:FLY]),
                  PkPM.new("Gyarados", :GYARADOS, 35, 20, 110, [:WATER, :FLYING], [:SURF])]
$Trainer.pokedex = DexPM.new
$Trainer.quests = [QuestPM.new("A side errand", :SIDE_QUEST), QuestPM.new("Earn the Cascade Badge", :MAIN_QUEST)]
$Trainer.save_slot = "File A"
class BagPM
  def initialize; @items = { :SUPERREPEL => 2, :POTION => 5, :BICYCLE => 1, :ITEMFINDER => 1 }; end
  def pbHasItem?(i); @items[i].to_i > 0; end
  def pbQuantity(i); @items[i].to_i; end
end
$PokemonBag = BagPM.new
class GlobalOM; attr_accessor :repel, :newFrameCount, :daycare; end
$PokemonGlobal = GlobalOM.new
$PokemonGlobal.repel = 0
$PokemonGlobal.newFrameCount = 0
class TempOM; attr_accessor :flydata; end
$PokemonTemp = TempOM.new
class GameTempOM; attr_accessor :in_menu, :in_battle, :message_window_showing, :player_transferring, :moving_furniture; end
$game_temp = GameTempOM.new
class GameMapOM
  attr_accessor :map_id, :need_refresh, :refreshed
  def refresh; @refreshed = true; end
  def update; end
end
$game_map = GameMapOM.new
$game_map.map_id = 5
class PlayerOM; attr_accessor :x, :y; def moving?; false; end; def straighten; end; end
$game_player = PlayerOM.new
$game_player.x = 10
$game_player.y = 10
class ScreenOM; attr_accessor :weather_type; end
$game_screen = ScreenOM.new
$game_screen.weather_type = :None
class EncountersOM; def initialize; @encounter_tables = { :Land => [[40, :PIDGEY, 3, 5], [30, :RATTATA, 3, 5], [30, :SPEAROW, 4, 6]] }; end; end
$PokemonEncounters = EncountersOM.new
GameSystemOM = Struct.new(:save_disabled, :menu_disabled)
$game_system = GameSystemOM.new(false, false)
def pbGetMapNameFromId(id); { 5 => "Cerulean City", 77 => "Safari Zone" }[id] || "Map #{id}"; end
def pbGetTimeNow; Time.new(2026, 10, 21, 15, 42, 0); end
module UnrealTime; PROPORTION = 60; end
module PBDayNight; def self.sheduleToneRefresh; $log << "TONE"; end; end
module Graphics; def self.frame_rate; 40; end; end
$interp = false
def pbMapInterpreterRunning?; $interp; end
$safari = false
def pbInSafari?; $safari; end
def pbInBugContest?; false; end
class SafariStateOM
  attr_accessor :decision, :steps, :ballcount
  def initialize; @steps = 120; @ballcount = 25; end
  def pbGoToStart; $log << "SAFARI START"; end
end
$safari_state = SafariStateOM.new
def pbSafariState; $safari_state; end
class HiddenItemOM; attr_reader :x, :y; def initialize(x, y); @x, @y = x, y; end; end
def pbClosestHiddenItem; HiddenItemOM.new(12, 7); end
def pbCanUseHiddenMove?(pkmn, move, show = true); $log << "CANUSE #{move}"; true; end
def pbBetterRegionMap(*a); $log << "REGION MAP"; [3, 12, 9]; end
def pbUseHiddenMove(pkmn, move); $log << "HIDDEN MOVE #{move} #{pkmn.name} #{$PokemonTemp.flydata.inspect} in_menu=#{$game_temp.in_menu.inspect}"; end
def pbConfirmUseHiddenMove(pkmn, move); $log << "CONFIRM #{move} #{pkmn.name}"; true; end
def openAutosaveMenu; $log << "AUTOSAVE MENU"; end    # PIF: Autosave turned On opens its menu
def pbUseKeyItemInField(item); $log << "USE IN FIELD #{item} in_menu=#{$game_temp.in_menu.inspect}"; true; end
def pbUseItem(bag, item, scene = nil); $log << "USE ITEM #{item}"; 1; end
def pbSaveScreen; $log << "SAVE SCREEN in_menu=#{$game_temp.in_menu.inspect}"; end
def pbQuestlog; $log << "QUEST LOG"; end
def pbSEPlay(*a); end
module ItemHandlers
  def self.hasOutHandler(i); [:POTION, :BICYCLE, :SUPERREPEL].include?(i); end
  def self.hasUseInFieldHandler(i); [:BICYCLE, :SUPERREPEL, :REPEL].include?(i); end
  def self.triggerConfirmUseInField(i); true; end
end
# The game's battle sprites (Full Party View): the fused sprite at its size
AnimOM = Struct.new(:bitmap) do
  def dispose; end
end
module GameData
  class Species
    SpeciesNameOM = Struct.new(:name, :id_number)
    DEX_OM = { :PIDGEY => 16, :RATTATA => 19, :SPEAROW => 21, :TENTACOOL => 72, :GOLDEEN => 118, :MAGIKARP => 129,
               :GYARADOS => 130, :DITTO => 132, :EEVEE => 133 }.freeze
    def self.get(s); SpeciesNameOM.new(s.to_s.capitalize, DEX_OM[s] || 1); end
    def self.sprite_bitmap_from_pokemon(pkmn)
      sheet = Bitmap.new("Graphics/CustomBattlers/spritesheets/spritesheets_base/#{pkmn.dex}.png")
      big = Bitmap.new(288, 288)
      big.stretch_blt(Rect.new(0, 0, 288, 288), sheet, Rect.new(0, 0, 96, 96))
      AnimOM.new(big)
    end
  end
end
module GameData
  class Item
    attr_reader :name, :id
    NAMES = { :POTION => "Potion", :BICYCLE => "Bicycle", :SUPERREPEL => "Super Repel", :REPEL => "Repel",
              :MAXREPEL => "Max Repel", :ITEMFINDER => "Itemfinder", :TOWNMAP => "Town Map" }.freeze
    def initialize(id); @id = id; @name = NAMES[id] || id.to_s; end
    def self.exists?(i); NAMES.key?(i); end
    def self.get(i); new(i); end
    def self.icon_filename(i); "Graphics/Items/#{i}"; end
    def is_machine?; false; end
  end
  class Move
    NAMES = { :SURF => "Surf", :FLY => "Fly", :CUT => "Cut" }.freeze
    attr_reader :name, :description
    def initialize(m); @name = NAMES[m] || m.to_s.capitalize; @description = "#{@name} out in the field."; end
    def self.get(m); new(m); end
  end
  class Type
    POS = { :NORMAL => 0, :FLYING => 2, :WATER => 11, :ELECTRIC => 13 }.freeze
    attr_reader :icon_position
    def initialize(t); @icon_position = POS[t] || 0; end
    def self.get(t); new(t); end
  end
end
# The game's Bag, choosing an item for a slot
$bag_picks = []
class PokemonBag_Scene; end
class PokemonBagScreen
  def initialize(*a); end
  def pbChooseItemScreen(filter = nil)
    item = $bag_picks.shift
    $log << "BAG CHOOSE #{item.inspect} (allowed: #{filter ? filter.call(item) : "-"})"
    return item && filter && !filter.call(item) ? nil : item
  end
end
# Party icons from the game's own files
# KIF Beta's Big Pokémon Icons (the battle sprite, 96 px frames), as the
# Save Manager's test has it; for a species, the game's BattleSpriteLoader
$big_icons = false
class PokemonIconSprite < Sprite
  attr_accessor :kif_big_offset
  def initialize(pkmn, vp = nil)
    super(vp)
    if $big_icons
      self.bitmap = Bitmap.new("Graphics/CustomBattlers/spritesheets/spritesheets_base/#{pkmn.dex}.png")
      self.src_rect = Rect.new(0, 0, 96, 96)
    else
      self.bitmap = Bitmap.new("Graphics/Pokemon/Icons/#{pkmn.species}.png")
      self.src_rect = Rect.new(0, 0, 64, 64)
    end
  end
  def update; end
end
module KIF; module BigIcons; end; end
KIF::BigIcons.define_singleton_method(:mode) { $big_icons ? 1 : 0 }
class BattleSpriteLoader
  def get_pif_sprite_from_species(dex); dex; end
  # one battle sprite out of the species' sheet, at the game's 288 px
  def load_pif_sprite_directly(dex)
    big = Bitmap.new(288, 288)
    big.stretch_blt(Rect.new(0, 0, 288, 288), Bitmap.new("Graphics/CustomBattlers/spritesheets/spritesheets_base/#{dex}.png"), Rect.new(0, 0, 96, 96))
    AnimOM.new(big)
  end
end
# A picture of a map behind the menu, for the renders (KR_PREVIEW_BACKDROP)
if ENV["KR_PREVIEW_BACKDROP"].to_s != "" && File.file?(ENV["KR_PREVIEW_BACKDROP"])
  backdrop = Sprite.new(Viewport.new(0, 0, 512, 384))
  backdrop.bitmap = Bitmap.new(ENV["KR_PREVIEW_BACKDROP"])
end
class Scene_Map; def update; end; end
$scene = Scene_Map.new

#---------------------------------------------------------------- helpers
$pf_texts = Hash.new { |h, k| h[k] = [] }
$pf_boxes = Hash.new { |h, k| h[k] = [] }
Reloaded::Pixel.singleton_class.prepend(Module.new { def text(b, x, y, w, h, str, *r); $pf_texts[b.id] << str.to_s; $pf_boxes[b.id] << [x, y, w, str.to_s]; super; end })
Bitmap.prepend(Module.new { def clear(*a); $pf_texts.delete(id); $pf_boxes.delete(id); super; end })
$om = nil
Reloaded::OverworldMenuScreen.prepend(Module.new { def main; $om = self; super; end })
$pg = nil
Reloaded::OverworldPagesScreen.prepend(Module.new { def main; $pg = self; super; end })
$sps = nil
Reloaded::SettingsScreen.prepend(Module.new { def main; $sps = self; super; end })
def om; $om; end
def iv(o, name); o.instance_variable_get(name); end
def drawn_on?(b, word); $pf_texts[b.id].any? { |s| s.include?(word) } || b.ops.any? { |o| o[0] == "text" && o[5].to_s.include?(word) }; end
def left_says?(word); drawn_on?(iv(om, :@left).bitmap, word); end
def top_says?(word); drawn_on?(iv(om, :@top_sprite).bitmap, word); end
def top_box(word); $pf_boxes[iv(om, :@top_sprite).bitmap.id].find { |bx| bx[3].include?(word) }; end
def overlay_says?(word); drawn_on?(iv(om, :@overlay_sprite).bitmap, word); end
def row_names; om.send(:rows).map(&:name); end
def cur_name; e = om.send(:current); e ? e.name : nil; end
def hints; om.send(:hint_pairs).map { |p| p[1] }; end
# F on the map (Reloaded Controls' layer is idle on these stand-ins, so the
# menu reads the key itself, as it does with Reloaded Controls Off)
F_KEY = :F
# A press of F on the map, then the menu runs on the rest of the queue
def on_map(label, queue)
  Input.queue = [F_KEY, *queue]
  $om = nil
  Input.update
  $scene.update
  check("#{label}: done", true)
rescue QueueEmpty => e
  check("#{label}: #{e.message}", false)
rescue Exception => e
  check("#{label}: #{e.class}: #{e.message} #{e.backtrace.first(5).inspect}", false)
end
LAYOUT = File.join(KR_LOCAL_DIR, "Settings", "Overworld Menu.json")
FileUtils.rm_f(LAYOUT)
# The PokeVial has its own preview (pokevial_preview.rb): out of these checks' way
OM.instance_variable_get(:@entries).delete("pokevial")
OM.instance_variable_get(:@entries).delete("heal_with_moves")
OM.forget_layout
CT = Reloaded::Controls

check("the Overworld Menu is a Kanto Reloaded feature, On", Reloaded::Features.registered?(:overworld_menu) && OM.on?)
check("Overworld Menu is a Controls action on the map: F and Select at first",
      CT.action(:overworld_menu).area == :overworld && CT.bindings(:overworld_menu, :keys) == ["k:9"] && CT.bindings(:overworld_menu, :pad) == ["p:4"])
check("Menu Animations is shared, on the Interface page", S.definition(Reloaded::PauseMenu::ANIMATIONS)[:page] == :interface)
check("its page in KIF Settings: Edit Pages, and how Party View looks (Full or Compact; Compact at first)",
      S.definition(:"overworld_menu.pages")[:type] == :button && S.definition(OM::PARTY_VIEW)[:values] == ["Full", "Compact"] &&
      S.get(OM::PARTY_VIEW) == 1)
check("the views: Party View, shown at first", OM.views.map { |v| v[:key] } == ["party"] && OM.view == "party")

#---------------------------------------------------------------- A: Main, Repel, Quick Items
$log.clear
on_map("A main", [
  dmp("om_01_open"),
  at { check("F on the map opens it, the map still moving", om && $game_temp.in_menu) },
  at { check("Main: Quick Items, Time Changer, Fly, Field Moves, Repel, Quick Save (#{row_names.inspect})",
             row_names == ["Quick Items", "Time Changer", "Fly", "Field Moves", "Repel", "Quick Save"]) },
  at { check("one built-in page, Main (#{OM.pages.map { |pg| pg["name"] }.inspect}); toggles and readouts start on no page",
             OM.pages.map { |pg| pg["id"] } == ["main"] && left_says?("MAIN") && !left_says?("TOGGLES") &&
             OM.entries.reject { |e| e.kind == :action }.none? { |e| OM.pages.any? { |pg| pg["entries"].include?(e.key.to_s) } }) },
  at { check("Repel: Off while none is on (you have Super Repels)", left_says?("Off")) },
  at { check("where you are: the map, the weather and time of day, and what's caught here",
             top_says?("Cerulean City") && top_says?("Clear, Day") && top_says?("1 of 3 Caught") && !top_says?("Here:")) },
  at { check("Party View, Compact: a card each, the name and level over the HP", iv(om, :@cards).length == 3 && top_says?("Pikachu") &&
             top_says?("Lv 34") && top_says?("20/110")) },
  at { check("the hints, with no Pages while Main is the only page (#{hints.inspect})", hints == ["Choose", "Use", "Edit Pages", "Views", "Close"]) },
  I::DOWN, I::DOWN, I::DOWN, I::DOWN,
  at { check("Down to Repel", cur_name == "Repel") },
  I::USE,
  dmp("om_02_repel"),
  at { check("A on Repel while none is on: your Repels to pick", overlay_says?("Use a Repel") && overlay_says?("Super Repel x2")) },
  I::USE,
  at { check("...the game's own Repel use (Super Repel)", $log.any? { |l| l.start_with?("USE IN FIELD SUPERREPEL") }) },
  at { $PokemonGlobal.repel = 142; om.refresh },
  at { check("...and now its steps show", left_says?("142")) },
  I::UP, I::UP, I::UP, I::UP, I::USE,
  at { check("A on Quick Items goes to the bar", om.focus == :quick && hints.include?("Set")) },
  at { $bag_picks = [:POTION] },
  I::USE,
  at { check("A on an empty slot: the game's Bag, showing only usable items, puts Potion in it",
             OM.quick_items[0] == :POTION && $log.any? { |l| l.include?("BAG CHOOSE :POTION (allowed: true)") }) },
  I::RIGHT,
  at { $bag_picks = [:BICYCLE] },
  I::USE,
  at { check("...Bicycle in the next (7 slots: #{OM.quick_items.length})", OM.quick_items[1] == :BICYCLE && OM.quick_items.length == 7) },
  dmp("om_03_quick_items"),
  I::LEFT, I::USE,
  at { check("A on Potion: used through the game's item use, the menu stays", $log.include?("USE ITEM POTION") && om.focus == :quick) },
  I::RIGHT, I::USE
])
check("A on the Bicycle (a field item): the menu closes, then the game rides it", !$game_temp.in_menu &&
      $log.any? { |l| l == "USE IN FIELD BICYCLE in_menu=false" })
$PokemonGlobal.repel = 0
$log.clear
on_map("A field moves", [
  I::DOWN, I::DOWN, I::DOWN,
  at { check("Field Moves: the others your Pokémon can use here", cur_name == "Field Moves") },
  I::USE,
  dmp("om_02b_field_moves"),
  at { check("...a list of them, each with its Pokémon (Surf, Gyarados; Fly has its own row)",
             overlay_says?("Surf (Gyarados)") && !overlay_says?("Fly (")) },
  I::USE
])
check("...picked: the menu closes, then the game's own question and the move", !$game_temp.in_menu &&
      $log.include?("CONFIRM SURF Gyarados") && $log.any? { |l| l.start_with?("HIDDEN MOVE SURF Gyarados") && l.end_with?("in_menu=false") })

#---------------------------------------------------------------- B: Toggles, Info, Party View
# Any setting can be a row: KIF Settings' own, read the way it reads them
SR = Reloaded::OverworldMenu::SettingRows
TEXT_KEY = SR.key_named("Text Speed")
ANIM_KEY = SR.key_named("Animations")         # PIF's Battle Animations, as KIF Settings names it
TYPE_KEY = SR.key_named("Type Display")
check("every On/Off and choice setting can be a row, KIF's and Kanto Reloaded's (#{SR.index.length} here; Text Speed is #{TEXT_KEY})",
      SR.index.length >= 40 && TEXT_KEY && ANIM_KEY && TYPE_KEY && SR.key_named("Autosave") && SR.key_named("Theme Mode"))
CC_KEY = SR.key_named("Change Controls")
MUSIC_KEY = SR.key_named("Music Volume")
check("...and its buttons, such as Change Controls, and its sliders and numbers (Music Volume); not the rows that only open another page of KIF Settings",
      CC_KEY && SR.button?(SR.row(CC_KEY).opt) && MUSIC_KEY && SR.number?(SR.row(MUSIC_KEY).opt) && SR.index.values.none? { |r| r.action } &&
      !SR.fits_row?(KIF::SettingsScreen::Row.new(:opt, ButtonOption.new("A Mod's Page", nil, ""), nil, "A Mod's Page", :mods, nil, 0, nil, [:mod_page, nil])))
check("...nor the Overworld Menu's own switch, in Features or on its page (#{SR.index.keys.grep(/Overworld Menu$/).inspect})",
      SR.index.keys.grep(/Overworld Menu$/).empty? && SR.index.keys.any? { |k| k.include?("/Features/") })
# Change Controls, pressed from a page: its screen is the test's stand-in
Reloaded::ControlsScreen.define_singleton_method(:open) { $log << "CONTROLS OPEN hidden=#{om.send(:sprites).none?(&:visible)}" }
check("Quick Save's time: green under 30 minutes, orange under an hour, red after (and before the first save)",
      [nil, 59, 29 * 60 + 59, 30 * 60, 59 * 60 + 59, 3600, 7200].map { |sec| Reloaded::OverworldMenu::Entries.save_age_colour(sec) } ==
      [:red, :green, :green, :amber, :amber, :red, :red])
# Toggles and readouts are the player's to put on a page: two pages of the
# test's own, as a player would make them in Edit Pages
OM.add_page("Toggles")["entries"] = [TEXT_KEY, ANIM_KEY, TYPE_KEY, "speed_up", CC_KEY, MUSIC_KEY]
$PokemonSystem.bgmvolume = 80
# readouts, and the two Quits (actions that start on no page) beside theirs
info = OM.entries.select { |e| e.kind == :info }.map { |e| e.key.to_s }
info.insert(info.index("safari_steps") + 1, "quit_safari")
info.insert(info.index("contest_balls") + 1, "quit_contest")
OM.add_page("Info")["entries"] = info
OM.save_layout
$PokemonSystem.speedup = 1
OM.met(PkPM.new("Pidgey", :PIDGEY, 3, 10, 10, [:NORMAL]))
OM.met(PkPM.new("Rattata", :RATTATA, 3, 10, 10, [:NORMAL]))
on_map("B toggles and info", [
  I::RIGHT,
  dmp("om_04_toggles"),
  at { check("a page of settings: Text Speed, Animations, Type Display, Speed-Up, the Change Controls button, then Music Volume (#{row_names.inspect})",
             row_names == ["Text Speed", "Animations", "Type Display", "Speed-Up", "Change Controls", "Music Volume"]) },
  at { check("...an On/Off one with the green switch, a slider with its value (80)", OM.entry(ANIM_KEY).get && !OM.entry(ANIM_KEY).values && left_says?("80")) },
  I::USE,
  dmp("om_04b_setting_dropdown"),
  at { check("A on a choice setting opens its dropdown (Normal, Fast, Instant)", iv(om, :@choice_dd) && overlay_says?("Instant")) },
  I::DOWN, I::USE,
  at { check("...Fast picked: the game's Text Speed ($PokemonSystem.textspeed #{$PokemonSystem.textspeed})",
             $PokemonSystem.textspeed == 1 && iv(om, :@choice_dd).nil? && left_says?("Fast")) },
  I::DOWN, I::USE,
  at { check("A flips an On/Off setting's switch: Animations Off", SR.value(ANIM_KEY) == 0 && !OM.entry(ANIM_KEY).get.call) },
  I::DOWN, I::USE, I::DOWN, I::USE,
  at { check("Type Display: its dropdown, the next choice picked (#{SR.value(TYPE_KEY)})", SR.value(TYPE_KEY) == 2 && left_says?("TCG")) },
  I::DOWN, I::USE,
  at { check("Speed-Up opens its dropdown too (x1, x2, x3), as every choice does", iv(om, :@choice_dd) && overlay_says?("x3")) },
  I::DOWN, I::USE,
  at { check("...x2 picked", $GameSpeed == 1 && left_says?("x2")) },
  I::DOWN, I::USE,
  at { check("A on Change Controls (a KIF Settings button) opens it, the menu out of sight meanwhile, and back after (#{$log.grep(/CONTROLS/).inspect})",
             $log.include?("CONTROLS OPEN hidden=true") && om.send(:sprites).any?(&:visible) && cur_name == "Change Controls") },
  I::DOWN, I::USE,
  dmp("om_04c_slider"),
  at { check("A on Music Volume (a slider) drops its slider: the value, its lowest and highest (#{hints.inspect})",
             iv(om, :@slider) && overlay_says?("80") && overlay_says?("100") && hints == ["Change", "-50", "+50", "Set", "Cancel"]) },
  I::LEFT,
  at { check("...Left: a step (5) down", overlay_says?("75")) },
  I::JUMPDOWN,
  at { check("...R: ten steps up, no further than its highest", overlay_says?("100")) },
  I::JUMPUP, I::USE,
  at { check("...L ten down, A sets it: the game's Music Volume 50 ($PokemonSystem.bgmvolume #{$PokemonSystem.bgmvolume})",
             $PokemonSystem.bgmvolume == 50 && iv(om, :@slider).nil? && left_says?("50")) },
  I::USE, I::RIGHT, I::BACK,
  at { check("...B leaves it as it was", $PokemonSystem.bgmvolume == 50) },
  I::USE,
  at { h = iv(om, :@slider_bar); Input.queue.unshift([:click, h[0] + (h[2] - h[0]) / 4, h[1] + 10]) },
  at { check("...a click on the bar puts it there (25)", overlay_says?("25")) },
  [:click, 300, 150],
  at { check("...a click off it sets it", $PokemonSystem.bgmvolume == 25 && iv(om, :@slider).nil?) },
  I::RIGHT,
  dmp("om_05_info"),
  at { check("Info: Quest, Met This Session, Since a Shiny, Itemfinder, Day Care, Play Time, Shiny Odds (no Level Cap or chain yet) (#{OM.page_entries(OM.pages[2]).map(&:name).inspect})",
             OM.page_entries(OM.pages[2]).map(&:name) == ["Quest", "Met This Session", "Since a Shiny", "Itemfinder", "Day Care", "Play Time", "Shiny Odds"]) },
  at { check("the main quest by name, and the hidden item's way",
             left_says?("Cascade") && left_says?("3 N, 2 E")) },
  I::USE,
  at { check("A on Quest opens the quest log", $log.include?("QUEST LOG")) },
  I::X,
  at { check("Y steps to the next view (only Party View so far: none)", OM.view.nil? && iv(om, :@cards).empty?) },
  I::X,
  at { check("...and round to Party View again, remembered", OM.view == "party" && iv(om, :@cards).length == 3) },
  at { OM.register_view(:test, :name => "Test View", :draw => proc { |_m, _b, t, c| Reloaded::Pixel.text(t, 300, 200, 150, 20, "TEST VIEW", c[:txt]) }) },
  I::X,
  at { check("a feature's own view joins the steps, and draws itself", OM.view == "test" && iv(om, :@cards).empty? && top_says?("TEST VIEW")) },
  I::X, I::X,
  at { check("...then none, then Party View", OM.view == "party") },
  at { OM.instance_variable_get(:@views).delete("test") },
  F_KEY
])
check("F again, its own button, closed it", !$game_temp.in_menu)
$Trainer.party += [PkPM.new("Pikachu", :PIKACHU, 20, 0, 60, [:ELECTRIC]), PkPM.new("Pidgeot", :PIDGEOT, 22, 50, 70, [:NORMAL, :FLYING]),
                   PkPM.new("Gyarados", :GYARADOS, 21, 60, 80, [:WATER, :FLYING])]
$Trainer.party[4].status = :POISON
$Trainer.party[5].name = "Crabominable"
$Trainer.party[5].level = 100
S.set(OM::PARTY_VIEW, 1)
on_map("B compact six", [
  dmp("om_10_compact_six"),
  at { ys = iv(om, :@cards).map(&:y).uniq.sort
       check("Compact with six: two rows of three, on the bottom edge (#{ys.inspect})", iv(om, :@cards).length == 6 && ys.length == 2) },
  at { check("...a status under the HP (PSN), a fainted one FNT", top_says?("PSN") && top_says?("FNT")) },
  at { nm = top_box("Crab")
       lv = top_box("Lv 100")
       check("...a long name beside Lv 100 shortened to fit before it (#{nm && nm[3]})",
             nm && lv && nm[3] != "Crabominable" && nm[0] + nm[2] <= lv[0] - 2 && nm[1] == lv[1]) },
  I::BACK
])
check("B closed it", !$game_temp.in_menu)
$Trainer.party[5].name = "Gyarados"
$Trainer.party[5].level = 21
S.set(OM::PARTY_VIEW, 0)
pf = $Trainer.party
pf[0].gender = 0; pf[1].gender = 1; pf[2].gender = 0; pf[3].gender = 1; pf[5].gender = 2
pf[1].shiny = true
pf[0].item_id = :POTION
pf[2].item_id = :BICYCLE
pf[2].types = [:WATER, :FLYING, :ELECTRIC]
pf[3].name = "Charmander"                     # long names: a smaller font, not "..."
pf[4].name = "Crabominable"
pf[4].gender = 0
pf[4].shiny = true
on_map("B full", [
  dmp("om_11_full"),
  at { check("Full: six big cards down the right side, two to a row, with names, levels and HP",
             iv(om, :@cards).length == 6 && iv(om, :@cards).map(&:x).uniq.length == 2 && top_says?("Gyarados") && top_says?("Lv 34") &&
             top_says?("120/120")) },
  at { check("...each with its battle sprite, at a quarter of its size (#{iv(om, :@cards).map { |c| c.bitmap.width }.uniq.inspect})",
             iv(om, :@cards).all? { |c| c.bitmap.width == 72 && c.bitmap.height == 72 }) },
  at { check("...a fainted one says FNT", top_says?("FNT")) },
  at { ch = top_box("Charmander")
       cr = top_box("Crabominable")
       check("...long names whole, in a smaller font when they need it (#{ch && ch[3]}, #{cr && cr[3]})",
             ch && ch[3] == "Charmander" && cr && cr[3] == "Crabominable") },
  I::BACK
])
$Trainer.party = $Trainer.party.first(3)
S.set(OM::PARTY_VIEW, 1)
check("Met This Session counts the wild Pokémon met (2), Since a Shiny too", OM.session == 2 && OM.since_shiny == 2)

#---------------------------------------------------------------- C: the page editor, a page of your own
OM.page_index = 0
on_map("C pages", [
  I::ACTION,
  dmp("om_06_pages"),
  at { check("X: Edit Pages, Main first", $pg && iv($pg, :@section) == 0) },
  I::USE,
  at { check("A goes to Main's entries", iv($pg, :@focus) == :list) },
  I::DOWN, I::USE,
  at { check("A takes Time Changer off Main", !OM.pages[0]["entries"].include?("time_changer")) },
  I::DOWN, I::DOWN, I::ACTION, I::UP, I::UP,
  at { check("X picks Repel up, Up carries it above Fly (#{OM.pages[0]["entries"].first(3).inspect})",
             OM.pages[0]["entries"].first(3) == ["quick_items", "repel", "fly"]) },
  I::USE, I::BACK, I::DOWN, I::DOWN, I::DOWN,
  at { check("...down the pages to Add Page", $pg.send(:add_slot?)) },
  I::USE,
  "Travel", :RETURN,
  dmp("om_07_new_page"),
  at { check("Add Page: a page named Travel, on its empty list", OM.pages.length == 4 && OM.pages[3]["name"] == "Travel" && iv($pg, :@focus) == :list) },
  at { check("...every entry can go on it, then Add a Setting (#{$pg.send(:rows).length})",
             $pg.send(:rows).length == OM.entries.length + 1 && $pg.send(:rows).last[0].name == "Add a Setting") },
  I::DOWN, I::DOWN, I::USE,
  at { check("A puts Fly on Travel", OM.pages[3]["entries"] == ["fly"]) },
  at { $pg.instance_variable_set(:@sel, $pg.send(:rows).length - 1); $pg.send(:refresh) },
  dmp("om_07b_add_a_setting"),
  I::USE,
  dmp("om_07c_pick_mode"),
  at { check("Add a Setting: KIF Settings in pick mode", $sps.is_a?(Reloaded::SettingsScreen) && $sps.instance_variable_get(:@pick_mode)) },
  I::RIGHT, I::RIGHT, I::LEFT,
  at { check("...nothing changes there (Left and Right just buzz)", S.get(:"systems.reloaded_settings") == true) },
  I::USE,
  *[nil] * 12,                                    # frames for the pick screen to slide shut
  at { k = OM.pages[3]["entries"].last
       check("...A on Reloaded Settings picks it, and it's on Travel (#{k})", OM.pages[3]["entries"].length == 2 &&
             k.start_with?("setting:") && OM.entry(k).name == "Reloaded Settings") },
  I::BACK, I::BACK,
  at { check("back in the menu: four tabs", OM.pages.length == 4 && left_says?("TRAVEL")) },
  I::LEFT,
  at { check("Left from Main turns round to Travel: Fly and Reloaded Settings (#{row_names.inspect})", row_names == ["Fly", "Reloaded Settings"]) },
  I::BACK
])
saved = JSON.parse(File.read(LAYOUT))
check("the pages are kept for every save (Settings\\Overworld Menu.json)", saved["pages"].map { |p| p["name"] } == ["Main", "Toggles", "Info", "Travel"])

#---------------------------------------------------------------- D: Fly, the Time Changer, Quick Save
$log.clear
on_map("D fly", [
  at { check("it opens on the page last shown (Travel)", row_names == ["Fly", "Reloaded Settings"]) },
  I::USE
])
check("Fly: the region map, then once the menu has closed, the flight", $log.include?("REGION MAP") &&
      $log.any? { |l| l == "HIDDEN MOVE FLY Pidgeot [3, 12, 9] in_menu=false" })
OM.page_index = 0
before = $PokemonGlobal.newFrameCount
on_map("D time", [
  I::DOWN, I::DOWN, I::DOWN,
  at { OM.reset_page(OM.pages[0]); om.refresh },
  at { check("Main reset: Time Changer back (#{row_names.inspect})", row_names.include?("Time Changer")) },
  at { om.instance_variable_set(:@sel, row_names.index("Time Changer")); om.refresh },
  I::USE,
  dmp("om_08_time_changer"),
  at { check("the Time Changer: the next hour, today, from 3:42 PM", overlay_says?("4 PM") && overlay_says?("Then Wed 4:00 PM")) },
  I::UP, I::RIGHT, I::DOWN, I::RIGHT, I::RIGHT,
  at { check("...1 day ahead, 6 PM (Evening)", overlay_says?("6 PM (Evening)") && overlay_says?("Then Thu 6:00 PM")) },
  I::USE,
  I::BACK
])
gain = ($PokemonGlobal.newFrameCount - before) / 40.0 * 60
check("...time moved forward to then (#{(gain / 3600.0).round(2)} hours), the map refreshed", (gain - (26 * 3600 + 18 * 60)).abs < 2 && $game_map.refreshed)
on_map("D save", [
  at { om.instance_variable_set(:@sel, row_names.index("Quick Save")); om.refresh },
  I::USE
])
check("Quick Save: the menu closes, then the game's save screen", $log.include?("SAVE SCREEN in_menu=false"))

#---------------------------------------------------------------- D2: the actions and readouts players add
# KIF Beta's level cap, Poké Radar, and pause-menu PC and Return, stood in
module KIF
  module LevelCap; def self.cap; 25; end; end
  module RadarPlus; def self.chain; $radar_chain.to_i; end; end
  module PauseMenu
    KEntryOM = Struct.new(:id, :handler)
    def self.active_entries
      [KEntryOM.new(:kif_pc, proc { |scene| $log << "KIF PC #{scene.respond_to?(:pbHideMenu)}"; :stay }),
       KEntryOM.new(:kif_er_return, proc { |_scene| $log << "KIF RETURN"; :close })]
    end
    def self.label_for(e); e.id == :kif_er_return ? "Return to Pallet" : "PC"; end
  end
end
$radar_chain = 0
$egg = false
def pbEggGenerated?; $egg; end
def pbDayCareGetCompat; 2; end
$PokemonGlobal.daycare = [[PkPM.new("Eevee", :EEVEE, 15, 40, 40, [:NORMAL]), 12], [nil, 0]]
Graphics.instance_variable_set(:@fc, 40 * (41 * 3600 + 12 * 60))     # 41h 12m at 40 frames a second
OM.install_item_hooks                           # the test's own pbUseItem and pbUseKeyItemInField are here now
pbUseItem($PokemonBag, :POTION)
check("Last Used Item knows the last item used from the Bag (#{OM.last_item.inspect})", OM.last_item == :POTION)
ADDED = ["area_encounters", "last_item", "kif_pc", "kif_return", "level_cap", "day_care", "radar_chain", "play_time"]
# a map with grass, water and three rods (Fishing: 10 lines, more than fit)
LAND_ONLY = $PokemonEncounters.instance_variable_get(:@encounter_tables)
$PokemonEncounters.instance_variable_set(:@encounter_tables, LAND_ONLY.merge(
  :Water => [[100, :TENTACOOL, 15, 25]],
  :OldRod => [[70, :MAGIKARP, 5, 5], [30, :GOLDEEN, 5, 10]],
  :GoodRod => [[60, :MAGIKARP, 10, 15], [40, :GOLDEEN, 10, 15]],
  :SuperRod => [[40, :MAGIKARP, 15, 20], [35, :GOLDEEN, 15, 20], [25, :GYARADOS, 20, 25]]))
def enc_icons; iv(om, :@enc_icons) || []; end
# a picture file drawn on the popups' layer
def overlay_draws?(file)
  iv(om, :@overlay_sprite).bitmap.ops.any? { |o| o[0] == "sblt" && ($bitmaps[o[5]].ops[0] || [])[1].to_s.include?(file) }
end
check("none of the added actions starts on Main", (ADDED + ["quit_safari", "quit_contest"] & OM.pages[0]["entries"]).empty?)
OM.add_page("More")["entries"] = ADDED.dup
OM.save_layout
$log.clear
on_map("D2 added entries", [
  at { OM.page_index = OM.pages.length - 1; om.instance_variable_set(:@page, OM.pages.length - 1); om.instance_variable_set(:@sel, 0); om.refresh },
  dmp("om_12_added"),
  at { check("a page of added entries (the Poké Radar's hidden with no chain) (#{row_names.inspect})",
             row_names == ["Area Encounters", "Last Used Item", "PC", "Return", "Level Cap", "Day Care", "Play Time"]) },
  at { check("...Last Used Item by the item's name and how many, KIF's Return by its own words, Level Cap 25, Day Care 1 Inside, Play Time 41h 12m",
             left_says?("Potion") && left_says?("x5") && left_says?("Return to Pallet") && left_says?("25") &&
             left_says?("1 Inside") && left_says?("41h 12m")) },
  I::USE,
  dmp("om_12b_area_encounters"),
  at { check("Area Encounters (Design 1, Wild Link's List): a tab per way they're met, the grass's Seen and Caught, levels and rates",
             overlay_says?("Area Encounters") && overlay_says?("GRASS") && overlay_says?("SURFING") && overlay_says?("FISHING") &&
             overlay_says?("Seen 2/3") && overlay_says?("Caught 1/3") && overlay_says?("Lv 3-5") && overlay_says?("40%") && overlay_says?("Lv 4-6")) },
  at { check("...seen ones by name, ??? for one never seen, and its icon a silhouette (#{enc_icons.map { |sp| sp.visible && sp.color.alpha }.inspect})",
             overlay_says?("Pidgey") && overlay_says?("Rattata") && overlay_says?("???") && !overlay_says?("Spearow") &&
             enc_icons.map { |sp| sp.visible && sp.color.alpha } == [0, 0, 255, false, false, false]) },
  at { check("...each one trimmed to the Pokémon in its icon and fitted to 34 px (#{enc_icons.first(3).map { |sp| [sp.src_rect.width, sp.src_rect.height] }.inspect})",
             enc_icons.first(3).all? { |sp| sp.src_rect.width < 64 && sp.src_rect.height < 64 &&
                                             ([sp.src_rect.width, sp.src_rect.height].max * sp.zoom_x).round == 34 }) },
  at { check("...hints: Method and Close; no Scroll while it fits (#{hints.inspect})", hints == ["Method", "Close"]) },
  at { check("...as tall as the longest tab here allows: six rows' worth for the rods (#{iv(om, :@enc_list_h)} px)", iv(om, :@enc_list_h) == 6 * 36) },
  I::RIGHT,
  at { check("Right: Surfing", overlay_says?("Tentacool") && overlay_says?("100%") && !overlay_says?("Pidgey")) },
  I::RIGHT,
  dmp("om_12c_area_fishing"),
  at { check("Fishing: each rod under its heading, Magikarp's levels on each, and it scrolls (#{hints.inspect})",
             overlay_says?("OLD ROD") && overlay_says?("GOOD ROD") && overlay_says?("Lv 10-15") && !overlay_says?("Lv 20-25") &&
             hints == ["Method", "Scroll", "Close"]) },
  I::DOWN, I::DOWN, I::DOWN, I::DOWN,
  at { check("Down scrolls to the end: the Super Rod, Gyarados unseen", overlay_says?("SUPER ROD") && overlay_says?("Lv 20-25") && !overlay_says?("Gyarados")) },
  I::DOWN,
  at { check("...and no further", overlay_says?("Lv 20-25") && overlay_says?("GOOD ROD") == false) },
  I::RIGHT,
  at { check("Right on the last tab: round to Grass, scrolled back up", overlay_says?("Pidgey") && overlay_says?("GRASS")) },
  I::BACK,
  at { check("B closes it, its icons with it", iv(om, :@enc_icons).nil? && iv(om, :@encounters).nil?) },
  I::DOWN, I::USE,
  at { check("Last Used Item: used again, the game's way", $log.include?("USE ITEM POTION")) },
  I::DOWN, I::USE,
  at { check("PC: KIF Beta's own entry, run with a stand-in scene, and the menu stays", $log.include?("KIF PC true") && om) },
  I::DOWN, I::DOWN, I::DOWN, I::USE,
  dmp("om_12e_day_care_one"),
  at { check("Day Care (Design 1, the Egg Manager's Panel): who's there, the levels gained and the cost, no hearts with one (#{hints.inspect})",
             overlay_says?("Eevee") && overlay_says?("+3 Levels · $400") && !overlay_says?("GET ALONG") && !overlay_says?("An Egg Is Waiting") &&
             iv(om, :@dc_icons).length == 1 && hints == ["Close"]) },
  I::USE,
  at { check("A closes it, its icon with it", iv(om, :@dc_icons).nil? && !iv(om, :@day_care_open)) },
  at { $egg = true; $PokemonGlobal.daycare[1] = [PkPM.new("Ditto", :DITTO, 29, 90, 90, [:NORMAL]), 28]; om.refresh },
  at { check("...the readout: Egg, once one's waiting", left_says?("Egg")) },
  I::USE,
  dmp("om_12f_day_care"),
  at { check("...two there and an Egg: how well they get along (hearts), each one's cost (+1 Level, $200), the Egg waiting",
             overlay_says?("THEY SEEM TO GET ALONG") && overlay_says?("Ditto") && overlay_says?("+1 Level · $200") &&
             overlay_says?("An Egg Is Waiting") && iv(om, :@dc_icons).length == 2 && overlay_draws?("Icons/iconEgg")) },
  I::BACK,
  at { $radar_chain = 7; om.refresh },
  at { check("Poké Radar Chain shows while there's a chain (7)", row_names.include?("Poké Radar Chain") && left_says?("7")) },
  I::UP, I::UP, I::USE
])
check("Return: KIF Beta's own entry, and the menu closes so the trip can happen", $log.include?("KIF RETURN") && !$game_temp.in_menu)
$PokemonEncounters.instance_variable_set(:@encounter_tables, LAND_ONLY)
# Level Cap reads PIF's Level Caps when KIF's is off (as Super Candy does)
KIF::LevelCap.define_singleton_method(:cap) { $kif_cap }
KIF::LevelCap.define_singleton_method(:cap_for) { |_p| $kif_cap }
module Settings; NB_BADGES = 16 unless const_defined?(:NB_BADGES); end
class PokemonSystem; attr_accessor :level_caps; end
class TrainerOM; attr_accessor :has_pokedex, :badges, :coins, :nb_npc_friends; def badge_count; Array(@badges).count(true); end; end
$Trainer.badges = [true, true, true, false, false, false, false, false]
def getCurrentLevelCap; 30; end
$kif_cap = nil
$PokemonSystem.level_caps = 0
check("Level Cap: hidden with neither KIF's nor PIF's Level Caps on", Reloaded::OverworldMenu::Entries.level_cap.nil?)
$PokemonSystem.level_caps = 1
check("...PIF's Level Caps On: its cap (#{Reloaded::OverworldMenu::Entries.level_cap.inspect})", Reloaded::OverworldMenu::Entries.level_cap == 30)
$kif_cap = 25
check("...KIF's first, when both are on (#{Reloaded::OverworldMenu::Entries.level_cap.inspect})", Reloaded::OverworldMenu::Entries.level_cap == 25)
$PokemonSystem.level_caps = 0
on_map("D2 one way here", [
  at { i = OM.pages.length - 1; OM.page_index = i; om.instance_variable_set(:@page, i); om.instance_variable_set(:@sel, 0); om.refresh },
  I::USE,
  dmp("om_12d_area_grass_only"),
  at { check("a map with grass only: one tab, as tall as its list, no Method or Scroll (#{iv(om, :@enc_list_h)} px, #{hints.inspect})",
             iv(om, :@enc_list_h) == 3 * 36 && hints == ["Close"]) },
  I::BACK, I::BACK
])
$big_icons = true
on_map("D2 Big Pokémon Icons", [
  at { i = OM.pages.length - 1; OM.page_index = i; om.instance_variable_set(:@page, i); om.instance_variable_set(:@sel, 0); om.refresh },
  I::USE,
  dmp("om_12g_area_big_icons"),
  at { check("Big Pokémon Icons on: Area Encounters shows each one's battle sprite, trimmed to the Pokémon and fitted to 34 px (#{enc_icons.first(3).map { |sp| [sp.src_rect.width, sp.src_rect.height] }.inspect})",
             enc_icons.first(3).all? { |sp| sp.bitmap.height == 288 && sp.src_rect.height < 288 &&
                                             ([sp.src_rect.width, sp.src_rect.height].max * sp.zoom_x).round == 34 } && enc_icons[2].color.alpha == 255) },
  I::BACK,
  at { om.instance_variable_set(:@sel, row_names.index("Day Care")); om.refresh },
  I::USE,
  dmp("om_12h_day_care_big_icons"),
  at { check("...and the Day Care popup its two battle sprites, scaled to the small icons' size (#{iv(om, :@dc_icons).map { |sp| sp.src_rect.height }.inspect})",
             iv(om, :@dc_icons).length == 2 && iv(om, :@dc_icons).all? { |sp| sp.src_rect.height == 96 && (sp.zoom_x * 96).round == 64 }) },
  at { check("...the Egg too: KIF Beta's Egg battle sprite", overlay_draws?("Battlers/Eggs/000")) },
  I::BACK, I::BACK
])
$big_icons = false

#---------------------------------------------------------------- D3: the newer rows
# Quest Log, Bicycle, the Pokédex, Badges, Shiny Odds, coins, roaming Pokémon
class DexPM; def seen_count; 112; end; def owned_count; 64; end; def accessible_dexes; [0]; end; end
class GlobalOM; attr_accessor :bicycle, :surfing, :diving, :pokedexDex, :roamPosition, :roamPokemon; end
TerrainOM = Struct.new(:must_walk)
class PlayerOM; def pbTerrainTag; TerrainOM.new($must_walk); end; def pbHasDependentEvents?; $following; end; end
MetaOM = Struct.new(:always_bicycle, :can_bicycle, :outdoor_map)
module GameData; class MapMetadata; def self.try_get(_id); $map_meta; end; end; end
$map_meta = MetaOM.new(false, false, true)
$must_walk = false
$following = false
def pbMountBike; $log << "MOUNT"; $PokemonGlobal.bicycle = true; end
def pbDismountBike; $log << "DISMOUNT"; $PokemonGlobal.bicycle = false; end
module Settings; USE_CURRENT_REGION_DEX = false unless const_defined?(:USE_CURRENT_REGION_DEX); end
class PokemonPokedexMenu_Scene; end
class PokemonPokedexMenuScreen; def initialize(_s); end; def pbStartScreen; $log << "POKEDEX hidden=#{om.send(:sprites).none?(&:visible)}"; end; end
module Settings
  ROAMING_SPECIES = [[:ENTEI, 50, 350, 1], [:RAIKOU, 50, 351, 1], [:SUICUNE, 50, 0, 1]] unless const_defined?(:ROAMING_SPECIES)
end
$game_switches[350] = true
$PokemonGlobal.roamPosition = { 0 => 12, 1 => 9, 2 => 5 }
$PokemonGlobal.roamPokemon = [nil, nil, true]          # Suicune caught; Raikou's switch off
$PokemonGlobal.bicycle = false
$Trainer.has_pokedex = true
$Trainer.coins = 1234
$Trainer.nb_npc_friends = 0
BAG_ITEMS = $PokemonBag.instance_variable_get(:@items)
BAG_ITEMS[:COINCASE] = 1
GameData::Item.define_singleton_method(:exists?) { |i| GameData::Item::NAMES.key?(i) || [:COINCASE, :SHINYCHARM].include?(i) }
module KIF; def self.shiny_odds; 16; end; end
QOL_ON = Reloaded::QualityOfLife.method(:on?)
$qol_on = [:infinite_repel, :infinite_safari]
Reloaded::QualityOfLife.define_singleton_method(:on?) { |id| $qol_on.include?(id) }
$radar_chain = 0
NEWER = ["quest_log", "bicycle", "pokedex", "badges", "shiny_odds", "coins", "roaming", "repel"]
OM.add_page("Newer")["entries"] = NEWER.dup
OM.save_layout
$log.clear
on_map("D3 newer rows", [
  at { i = OM.pages.length - 1; OM.page_index = i; om.instance_variable_set(:@page, i); om.instance_variable_set(:@sel, 0); om.refresh },
  dmp("om_13_newer"),
  at { check("the newer rows, one roaming Pokémon (Entei) by its name (#{row_names.inspect})",
             row_names == ["Quest Log", "Bicycle", "Pokédex", "Badges", "Shiny Odds", "Coins", "Roaming Pokémon", "Repel"] &&
             left_says?("Entei") && left_says?("Map 12")) },
  at { check("...Seen and Caught (112, 64), 1 in 4096, the coins as 1,234",
             left_says?("SEEN") && left_says?("112") && left_says?("CAUGHT") && left_says?("64") && left_says?("1 in 4096") && left_says?("1,234")) },
  at { $safari = true },
  at { check("...Repel and Safari Steps show the ∞ mark while their infinite toggles are On",
             OM.status(OM.entry(:repel)) == [OM::INFINITY, :gold] && OM.status(OM.entry(:safari_steps)) == [OM::INFINITY, :gold]) },
  at { $safari = false },
  I::USE,
  at { check("Quest Log opens the quest log", $log.include?("QUEST LOG")) },
  I::DOWN, I::USE,
  at { check("Bicycle: A gets on (the game's own pbMountBike), its switch On", $PokemonGlobal.bicycle && $log.include?("MOUNT") && OM.entry(:bicycle).get.call) },
  at { $map_meta.always_bicycle = true },
  I::USE,
  at { check("...where you must ride, it says why and stays on", overlay_says?("You can't get off your Bike here.") && $PokemonGlobal.bicycle) },
  I::USE,
  at { $map_meta.always_bicycle = false },
  I::USE,
  at { check("...and off again", !$PokemonGlobal.bicycle && $log.include?("DISMOUNT")) },
  at { $following = true },
  I::USE,
  at { check("...not with someone following you", overlay_says?("someone") && !$PokemonGlobal.bicycle) },
  I::USE,
  at { $following = false; $map_meta.outdoor_map = false },
  I::USE,
  at { check("...nor indoors", overlay_says?("You can't ride here.") && !$PokemonGlobal.bicycle) },
  I::USE,
  at { $map_meta.outdoor_map = true },
  I::DOWN, I::USE,
  at { check("Pokédex: A opens it as the pause menu does, the menu out of sight meanwhile (#{$log.grep(/POKEDEX/).inspect})",
             $log.include?("POKEDEX hidden=true") && $PokemonGlobal.pokedexDex == 0) },
  at { b = Bitmap.new(240, 30)
       w8 = OM.entry(:badges).paint.call(b, 230, 0, 26, om.palette)
       $Trainer.badges = [true] * 9 + [false] * 7
       w16 = OM.entry(:badges).paint.call(b, 230, 0, 26, om.palette)
       $Trainer.badges = [true, true, true, false, false, false, false, false]
       check("Badges: eight pips (#{w8} px), sixteen once one past the eighth is earned (#{w16} px)", w8 == 85 && w16 == 126) },
  at { BAG_ITEMS[:SHINYCHARM] = 1; om.refresh },
  at { check("Shiny Odds with the Shiny Charm (#{OM.status(OM.entry(:shiny_odds)).inspect})", left_says?("1 in 1366")) },
  at { $radar_chain = 7; om.refresh },
  at { check("...during a Poké Radar chain of 7, its shaking grass's (PIF's: 1 in 2696)", left_says?("1 in 2696")) },
  at { $radar_chain = 0; BAG_ITEMS.delete(:SHINYCHARM); $PokemonGlobal.roamPokemon[2] = nil; om.refresh },
  at { check("two roaming: Roaming Pokémon, and how many", left_says?("Roaming Pokémon") && OM.status(OM.entry(:roaming)) == ["2", nil]) },
  dmp("om_13c_two_roaming"),
  at { om.instance_variable_set(:@sel, row_names.index("Roaming Pokémon")); om.refresh },
  I::USE,
  dmp("om_13b_roaming"),
  at { check("...A lists each and where it is", overlay_says?("Entei: Map 12.") && overlay_says?("Suicune: Cerulean City.")) },
  I::USE, I::DOWN, I::USE,
  at { check("Repel with Infinite Repel On: A says so", overlay_says?("Infinite Repel is On")) },
  I::USE, I::BACK
])
Reloaded::QualityOfLife.define_singleton_method(:on?, QOL_ON)
# the newer readouts out of sight again for the pages after
$Trainer.has_pokedex = false
$Trainer.badges = nil
BAG_ITEMS.delete(:COINCASE)
$PokemonGlobal.roamPosition = nil

# DEBUG Off hides a Kanto Reloaded setting from a hidden page (the Timing
# Profiler's), even one already on a page
KR_DEBUG = Reloaded.method(:debug?)
$kr_debug = true
Reloaded.define_singleton_method(:debug?) { $kr_debug }
SR.forget
TP_KEY = SR.key_named("Timing Profiler")
OM.pages.last["entries"] << TP_KEY if TP_KEY
check("DEBUG On: the Timing Profiler's own switch can go on a page (#{TP_KEY})",
      TP_KEY && OM.page_entries(OM.pages.last).any? { |e| e.key == TP_KEY })
$kr_debug = false
check("...DEBUG Off: out of sight there, though nothing has read KIF Settings again",
      SR.row(TP_KEY) && OM.page_entries(OM.pages.last).none? { |e| e.key == TP_KEY })
Reloaded.define_singleton_method(:debug?, KR_DEBUG)
SR.forget

#---------------------------------------------------------------- E: never during a cutscene; feature Off
$interp = true
Input.queue = [F_KEY, nil]
$om = nil
Input.update
$scene.update
check("during a cutscene F does nothing", $om.nil? && !$game_temp.in_menu)
$interp = false
Reloaded::Features.set(:overworld_menu, :off)
Input.queue = [F_KEY, nil]
Input.update
$scene.update
check("Overworld Menu Off: F does nothing", $om.nil?)
Reloaded::Features.set(:overworld_menu, :on)

#---------------------------------------------------------------- F: the Safari Zone
$safari = true
$game_map.map_id = 77
OM.page_index = 2
on_map("F safari", [
  dmp("om_09_safari"),
  at { check("Info in the Safari Zone: its balls and steps, and Quit Safari (#{row_names.inspect})",
             row_names.include?("Safari Balls") && row_names.include?("Quit Safari") && left_says?("25") && left_says?("120/600")) },
  at { OM.page_index = 0; om.instance_variable_set(:@page, 0); om.refresh },
  at { check("Quick Save is there, locked: it says why", om.send(:rows).find { |e| e.name == "Quick Save" } && OM.usable(OM.entry(:quick_save)) == "You can't save in the Safari Zone.") },
  at { om.instance_variable_set(:@page, 2); om.instance_variable_set(:@sel, row_names.index("Quit Safari")); om.refresh },
  I::USE,
  at { check("Quit Safari asks first", overlay_says?("Leave the Safari Game right now?")) },
  I::LEFT, I::USE
])
check("...then, once the menu has closed, the Safari Game ends as the game's own Quit does",
      $safari_state.decision == 1 && $log.include?("SAFARI START"))
$safari = false
$game_map.map_id = 5

#---------------------------------------------------------------- G: the mouse, Menu Animations Off
OM.page_index = 0
on_map("G mouse", [
  at { $f0 = Graphics.frame_count },
  at { h = iv(om, :@hits).find { |v, *| v == [:tab, 1] }; Input.queue.unshift([:click, h[1] + 10, h[2] + 5]) },
  at { check("a click on a tab turns to it (Toggles)", OM.page_index == 1 && row_names.first == "Text Speed") },
  [:move, 100, 60 + 28 + 10],
  at { check("hover picks a row (#{cur_name})", cur_name == "Animations") },
  [:click, 100, 60 + 28 + 10],
  at { check("a click uses it (Animations On again)", SR.value(ANIM_KEY) == 1) },
  [:rclick, 300, 150]
])
check("a right click closed it", !$game_temp.in_menu)
S.set(Reloaded::PauseMenu::ANIMATIONS, false)
on_map("G no animations", [
  at { check("Menu Animations Off: it's there at once", Graphics.frame_count - $f1 <= 2) },
  I::BACK
].tap { |q| q.unshift(at { $f1 = Graphics.frame_count - 1 }) })
S.set(Reloaded::PauseMenu::ANIMATIONS, true)

#---------------------------------------------------------------- H: Theme Mode
# The map menus follow Theme Mode (his pick, 2026-10-21): Glass
# see-through, Light the Light frames' look (Matching Frames), Frost both;
# their popups too. Full screens (Edit Pages, KIF Settings) stay dark.
def rgb_of(col); [col.red, col.green, col.blue]; end
OM.page_index = 1
[[1, "Glass", false, 167], [2, "Light", true, 248], [3, "Frost", true, 186]].each do |mode, name, light, alpha|
  S.set(Reloaded::Palette::MODE, mode)
  on_map("H #{name}", [
    dmp("om_14_theme_#{name.downcase}"),
    at { c = om.palette
         check("Theme Mode #{name}: #{light ? "the Light colours (deeper statuses, the Theme's ink for words)" : "the Theme's own colours"}, its panels #{om.send(:panel_alpha)} of 255",
               !!c[:light] == light && om.send(:panel_alpha) == alpha &&
               (!light || (rgb_of(c[:green]) == [30, 140, 70] && rgb_of(c[:gold]) == [176, 118, 0] &&
                           rgb_of(c[:txt]) == rgb_of(Reloaded::Palette.current[:panel])))) },
    at { check("...its cursor #{light ? "fainter, so the words under it read" : "as ever"} (#{Reloaded::Palette.cursor(nil, om.palette)[0].alpha})",
               Reloaded::Palette.cursor(nil, om.palette)[0].alpha == (light ? 60 : 160)) },
    I::USE,
    *(name == "Light" ? [dmp("om_14b_theme_light_dropdown")] : []),
    at { check("...and its popups: the dropdown draws in them", iv(om, :@choice_dd) && om.palette.equal?(Reloaded::Palette.map_menu)) },
    I::BACK, I::BACK
  ])
end
check("...full screens keep the Theme's dark colours in any Theme Mode (Edit Pages, KIF Settings)", !Reloaded::Palette.current[:light])
S.set(Reloaded::Palette::MODE, 0)
check("...and Dark again: the panels as they were (232)", !Reloaded::Palette.map_menu[:light] && Reloaded::Palette.menu_alpha(232) == 232)

#---------------------------------------------------------------- an older layout (Toggles and Info built in)
old = { "pages" => [{ "id" => "main", "name" => "Main", "entries" => ["quick_items", "fly", "repel", "time_changer", "quick_save"] },
                    { "id" => "toggles", "name" => "Toggles", "entries" => ["always_run", "autosave"] },
                    { "id" => "info", "name" => "Info", "entries" => ["encounters", "quick_save"] }],
        "seen" => OM.entries.map { |e| e.key.to_s }, "page" => 0 }
File.write(OM.layout_path, Reloaded::JSON.generate(old))
OM.forget_layout
ids = OM.pages.map { |pg| pg["id"] }
check("an older layout: its Toggles page goes, Info stays as the player's own (it holds Quick Save), and Time Changer moves below Quick Items (#{ids.inspect}, #{OM.pages[0]["entries"].inspect})",
      ids == ["main", "info"] && !OM.builtin?(OM.pages[1]) && OM.pages[1]["entries"] == ["encounters", "quick_save"] &&
      OM.pages[0]["entries"].first(3) == ["quick_items", "time_changer", "fly"] &&
      Reloaded::JSON.parse(File.read(OM.layout_path))["version"] == OM::LAYOUT_VERSION)

errors = File.read(Reloaded::Log.path).lines.grep(/ERROR|skipped/)
check("no errors or skipped hooks in Kanto Reloaded's log (#{errors.length})", errors.empty?)
errors.first(5).each { |l| puts "  " + l }
puts $failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED"
exit($failed ? 1 : 0)
