# encoding: utf-8
# Offline preview of the Party Screen on the preview tool's stand-ins
# (Tools/UIPreview/preview.rb), run by PIF's own party logic
# (016_UI/005_UI_Party.rb, PokemonPartyScreen) with KIF Beta's command hook
# (990_KIF/000_Core/005_KIF_PCActions.rb: Kuray Actions and its missing
# commands): the cards and details, the menu in the panel, a submenu and B
# back to the menu, a mod's command, Y to move and Switch's preview, X for
# the Summary, a message, a question, Grey Out with a move being taught, an
# Egg, fewer than six, a battle's menu, the mouse, Light and Frost, and
# Reloaded Party Screen Off.
# Usage: ruby   Tools/Tests/party_screen_preview.rb "<KIF Beta>" <work dir with metrics.json>
#        python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>
PREVIEW_SETUP_ONLY = true
load File.join(ARGV[0], "Mods/KantoReloaded/Tools/UIPreview/preview.rb")
PS = Reloaded::PartyScreen
PP = Reloaded::PartyPaint
S = Reloaded::Settings unless defined?(S)
$VERBOSE = nil

#---------------------------------------------------------------- the game, as the screen sees it
module Settings; MAX_PARTY_SIZE = 6 unless const_defined?(:MAX_PARTY_SIZE); end
class SpriteWrapper < Sprite; end
class Window_CommandPokemon; def initialize(*a); end; end
class PokemonStorageScreen; def organizeActions(*a); end; def pbShowCommands(*a); end; def pbBoxCommands(*a); end; end
module KIF
  module Modules; def self.proc_active?(pr); true; end; end
  def self.draw_evolock_icon(b, x, y); b.fill_rect(x, y + 6, 12, 9, Color.new(232, 184, 48)); end
end
module GameData
  class Type
    POS = { :NORMAL => 0, :FIGHTING => 1, :FLYING => 2, :POISON => 3, :GHOST => 7, :WATER => 11, :ELECTRIC => 13, :DARK => 17, :DRAGON => 16, :STEEL => 8, :GROUND => 4 }.freeze
    attr_reader :icon_position
    def initialize(t); @icon_position = POS[t] || 0; end
    def self.get(t); new(t); end
  end
  class Item
    NAMES = { :LIGHTBALL => "Light Ball", :POTION => "Potion", :LEFTOVERS => "Leftovers" }.freeze
    attr_reader :name, :id
    def initialize(id); @id = id; @name = NAMES[id] || id.to_s; end
    def self.get(i); new(i); end
    def self.exists?(i); NAMES.key?(i); end
    def self.icon_filename(i); "Graphics/Items/#{i}"; end
    def is_mail?; false; end
  end
  class Move
    MoveQ = Struct.new(:id, :name, :type, :base_damage, :accuracy, :description)
    DATA = { :THUNDERBOLT => MoveQ.new(:THUNDERBOLT, "Thunderbolt", :ELECTRIC, 90, 100, "A strong electric blast. It may also paralyze the target.") }.freeze
    def self.get(m); DATA[m] || MoveQ.new(m, m.to_s.capitalize, :NORMAL, 0, 0, ""); end
  end
  class Species
    SpQ = Struct.new(:hatch_steps, :id_number)
    def self.get(sp); SpQ.new(5120, 1); end
  end
  class GrowthRate
    def self.max_level; 100; end
  end
end
GrowthQ = Struct.new(:base) do
  def minimum_exp_for_level(lv); lv * lv * lv; end
end
MoveP = Struct.new(:id, :name, :type, :pp, :total_pp)
NatureQ = Struct.new(:name)
AbilityQ = Struct.new(:name)
class PkP
  attr_accessor :name, :species, :level, :hp, :totalhp, :status, :item, :gender, :shiny, :types, :moves, :exp,
                :steps_to_hatch, :evolock, :pkrs, :dex, :mail, :evolve_from_party, :nature, :ability
  def initialize(name, sp, dex, level, hp, total, types, moves, opts = {})
    @name, @species, @dex, @level, @hp, @totalhp, @types = name, sp, dex, level, hp, total, types
    @moves = moves.map { |n, t, pp, tot| MoveP.new(n.upcase.gsub(" ", "").to_sym, n, t, pp, tot) }
    @status = opts[:status] || :NONE
    @item = opts[:item]
    @gender = opts[:gender] || 0
    @shiny = opts[:shiny]
    @exp = opts[:exp] || level * level * level
    @steps_to_hatch = opts[:steps] || 0
    @evolock = opts[:evolock]
    @pkrs = opts[:pkrs]
    @nature = NatureQ.new(opts[:nature] || "Hardy")
    @ability = AbilityQ.new(opts[:ability] || "Static")
  end
  def egg?; @steps_to_hatch > 0; end
  def fainted?; @hp <= 0; end
  def able?; !egg? && @hp > 0; end
  def male?; @gender == 0; end
  def female?; @gender == 1; end
  def genderless?; @gender == 2; end
  def shiny?; @shiny ? true : false; end
  def bodyShiny?; shiny?; end
  def headShiny?; false; end
  def debugShiny?; false; end
  def radarShiny?; false; end
  def pokerusStage; @pkrs ? 1 : 0; end
  def growth_rate; GrowthQ.new(1); end
  def numMoves; @moves.length; end
  def hasItem?; !@item.nil?; end
  def hasMove?(m); @moves.any? { |x| x.id == m }; end
  def speciesName; @species.to_s.capitalize; end
  def isFusion?; false; end
  def kif_evo_locked?; @evolock ? true : false; end
  def item_id; @item; end
end
# Party icons from the game's own files (as the Overworld Menu's preview)
$big_icons = false
class PokemonIconSprite < Sprite
  attr_accessor :kif_big_offset
  def initialize(pkmn, vp = nil)
    super(vp)
    if pkmn.egg?
      self.bitmap = Bitmap.new("Graphics/Icons/iconEgg")
      self.src_rect = Rect.new(0, 0, 64, 64)
    elsif $big_icons
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
class GameTempP; attr_accessor :in_battle, :in_menu; end
$game_temp = GameTempP.new
$game_temp.in_battle = false
def pokemonAllowedToEvolve(pkmn); true; end
module HiddenMoveHandlers; def self.hasHandler(id); id == :SURF; end; end
def canPutHatOnPokemon(pkmn); false; end
$fusion_items = false
def playerHasFusionItems; $fusion_items; end
def pbSEPlay(*a); $log << "SE #{a[0]}"; end
def pbTakeItemFromPokemon(pkmn, screen)
  name = GameData::Item.get(pkmn.item).name
  screen.pbDisplay(_INTL("You received the {1} from {2}.", name, pkmn.name))
  pkmn.item = nil
  true
end
class PokemonSummary_Scene; end
class PokemonSummaryScreen
  def initialize(scene, inbattle = false); @inbattle = inbattle; end
  def pbStartScreen(party, i); $log << "SUMMARY #{party[i].name} inbattle=#{@inbattle} hidden=#{$ps.send(:sprites).none?(&:visible)}"; end
end
class PokemonBag_Scene; end
# PIF's party logic and KIF's command hook, as the game has them
load File.join(SCRIPTS, "016_UI/005_UI_Party.rb")
load File.join(SCRIPTS, "990_KIF/000_Core/005_KIF_PCActions.rb")
KIF::PCActions.add(:evolock, proc { |pkmn| _INTL("Lock Evolution") }, proc { |host, pkmn, *_| host.pbDisplay(_INTL("Pokemon evolution locked!")) })
$export_on = true
KIF::PCActions.add(:export, proc { |pkmn| $export_on ? _INTL("Export") : nil }, proc { |host, pkmn, *_| host.pbDisplay("Exported #{pkmn.name}.") })
# A TM, as the game teaches one (013_Items: pbMoveTutorChoose)
def pbMoveTutorChoose(move, movelist = nil, bymachine = false, oneusemachine = false)
  annot = $Trainer.party.map { |p| p.egg? ? _INTL("NOT ABLE") : (p.hasMove?(move) ? _INTL("LEARNED") : (p.types.include?(:ELECTRIC) || p.types.include?(:WATER) ? _INTL("ABLE") : _INTL("NOT ABLE"))) }
  scene = PokemonParty_Scene.new
  screen = PokemonPartyScreen.new(scene, $Trainer.party)
  screen.pbStartScene(_INTL("Teach which Pokémon?"), false, annot)
  $chosen = screen.pbChoosePokemon
  screen.pbEndScene
end
# The game's classes are here now: the hooks the game makes at boot
PS.install
class TrainerP; attr_accessor :party; end
$Trainer = TrainerP.new
def make_party
  [PkP.new("Pikachu", :PIKACHU, 25, 34, 78, 95, [:ELECTRIC], [["Thunderbolt", :ELECTRIC, 15, 15], ["Quick Attack", :NORMAL, 30, 30], ["Iron Tail", :STEEL, 15, 15], ["Double Team", :NORMAL, 15, 15]],
          :item => :LIGHTBALL, :pkrs => true, :nature => "Timid", :exp => 34 ** 3 + 2000),
   PkP.new("Pidgeot", :PIDGEOT, 18, 36, 0, 120, [:NORMAL, :FLYING], [["Fly", :FLYING, 15, 15], ["Wing Attack", :FLYING, 35, 35]], :gender => 1, :shiny => true),
   PkP.new("Gyarados", :GYARADOS, 130, 35, 20, 110, [:WATER, :FLYING], [["Surf", :WATER, 15, 15], ["Bite", :DARK, 25, 25], ["Dragon Rage", :DRAGON, 10, 10], ["Thrash", :NORMAL, 8, 10]],
          :nature => "Adamant", :ability => "Intimidate"),
   PkP.new("Eevee", :EEVEE, 133, 22, 60, 60, [:NORMAL], [["Bite", :DARK, 25, 25]], :gender => 1, :evolock => true),
   PkP.new("Haunter", :HAUNTER, 93, 37, 70, 120, [:GHOST, :POISON], [["Lick", :GHOST, 30, 30]], :status => :POISON),
   PkP.new("Egg", :EEVEE, 133, 1, 10, 10, [:NORMAL], [], :steps => 640)]
end
$Trainer.party = make_party
# a level lock on Gyarados (Quality of Life)
Reloaded::SaveStore.__send__(:from_save, nil)
Reloaded::Events.emit(:save_loaded, {})
S.set(Reloaded::QualityOfLife.key(:level_locking), true)
Reloaded::QualityOfLife::LevelLocks.set($Trainer.party[2], 35)
# a mod's command
PS.add_command(:walk, :label => proc { |pkmn| pkmn.egg? ? nil : "Walk Together" }, :description => "Walks with you.",
               :handler => proc { |scene, pkmn, i| $log << "WALK #{pkmn.name} #{i}" })

#---------------------------------------------------------------- helpers
$pf_texts = Hash.new { |h, k| h[k] = [] }
Reloaded::Pixel.singleton_class.prepend(Module.new { def text(b, x, y, w, h, str, *r); $pf_texts[b.id] << str.to_s; super; end })
Bitmap.prepend(Module.new { def clear(*a); $pf_texts.delete(id); super; end })
$ps = nil
Reloaded::PartyScene.prepend(Module.new { def pbStartScene(*a); $ps = self; super; end }) rescue nil
PS.scene_class.prepend(Module.new { def pbStartScene(*a); $ps = self; super; end })
def ps_iv(n); $ps.instance_variable_get(n); end
def said?(sprite, word)
  b = ps_iv(sprite).bitmap
  $pf_texts[b.id].any? { |s| s.include?(word) } || b.ops.any? { |o| o[0] == "text" && o[5].to_s.include?(word) }
end
def top_says?(w); said?(:@top_sprite, w); end
def over_says?(w); said?(:@overlay_sprite, w); end
# Small-font lines in the details panel that run past its edges, measured
# in the game's own font metrics: [[text, left, right]]
def panel_spills
  b = ps_iv(:@top_sprite).bitmap
  ruler = Bitmap.new(1, 1)
  b.ops.select { |o| o[0] == "text" && METRICS.key?("#{o[7]}|#{o[8]}") }.filter_map do |o|
    ruler.font.name = o[7]
    ruler.font.size = o[8]
    w = ruler.text_size(o[5]).width
    next unless o[1] + w / 2 >= PP::DX
    [o[5], o[1], o[1] + w] if o[1] < PP::DX + 2 || o[1] + w > PP::DX + PP::DW - 2
  end
end
def hints; $ps.send(:hint_pairs).map { |p| p[1] }; end
def menu_rows; (ps_iv(:@kr_menu) || {})[:rows].to_a.map(&:first); end
def cursor_on; $ps.instance_variable_get(:@activecmd); end
# The party screen from the pause menu, PIF's own logic
def party_screen(label, queue, party = $Trainer.party)
  Input.queue = queue.dup
  $ps = nil
  scene = PokemonParty_Scene.new
  screen = PokemonPartyScreen.new(scene, party)
  $ret = screen.pbPokemonScreen
  check("#{label}: done", true)
rescue QueueEmpty => e
  check("#{label}: #{e.message}", false)
rescue Exception => e
  check("#{label}: #{e.class}: #{e.message} #{e.backtrace.first(6).inspect}", false)
end

# Design scripts load this file for its stand-ins and helpers only
return if defined?(PARTY_PREVIEW_SETUP_ONLY)

check("Reloaded Party Screen is a Reloaded System, On", S.definition(PS::TOGGLE)[:page] == :systems && S.get(PS::TOGGLE) == true)
check("the game's PokemonParty_Scene.new makes Kanto Reloaded's (a subclass of the game's)",
      PokemonParty_Scene.new.class == PS.scene_class && PS.scene_class < PokemonParty_Scene)
check("...its command list and choosing replace the game's innermost methods (#{PS.innermost(PokemonParty_Scene, :pbShowCommands)}, #{PS.innermost(PokemonParty_Scene, :pbChoosePokemon)}), so KIF's hook still runs around them",
      PS.innermost(PokemonParty_Scene, :pbShowCommands) == :kif_party_raw_commands && PS.innermost(PokemonParty_Scene, :pbChoosePokemon) == :kif_party_pbChoosePokemon)

#---------------------------------------------------------------- A: the cards, the details, the menu
$log.clear
party_screen("A main", [
  dmp("ps_01_main"),
  at { check("six cards and Pikachu's details: name, level, types, About and moves; the title Party",
             top_says?("Party") && top_says?("Pikachu") && top_says?("Gyarados") && top_says?("78/95") && top_says?("Timid") &&
             top_says?("Thunderbolt") && top_says?("PKRS") && top_says?("FNT") && top_says?("PSN") && top_says?("Egg") && top_says?("Soon")) },
  at { check("the hints: Choose, Options, Summary, Move, Close (#{hints.inspect})", hints == ["Choose", "Options", "Summary", "Move", "Close"]) },
  at { check("levels as Lv. 34", top_says?("Lv. 34")) },
  at { check("...the details' small text inside the panel (#{panel_spills.inspect})", panel_spills.empty?) },
  I::DOWN,
  at { check("Down: Gyarados below Pikachu", cursor_on == 2) },
  dmp("ps_02_gyarados"),
  at { check("...Gyarados' details inside the panel too (#{panel_spills.inspect})", panel_spills.empty?) },
  I::RIGHT,
  at { check("Right: Eevee beside it", cursor_on == 3) },
  I::DOWN, I::DOWN,
  at { check("Down twice: round the column to Pidgeot (#{cursor_on})", cursor_on == 1) },
  I::LEFT, I::USE,
  dmp("ps_03_menu"),
  at { check("A on Pikachu: its menu in the panel, the game's commands in its order with KIF's Kuray Actions (as RLD Actions), Relearn Moves and the mod's Walk Together before Cancel (#{menu_rows.inspect})",
             menu_rows.first == "Summary" && menu_rows.include?("Switch") && menu_rows.include?("Item") && menu_rows.include?("RLD Actions") &&
             menu_rows.include?("Relearn Moves") && !menu_rows.include?("Kuray Actions") && !menu_rows.include?("Change moves") &&
             menu_rows.include?("Walk Together") && menu_rows.last == "Cancel" && menu_rows.index("Walk Together") == menu_rows.length - 2) },
  at { check("...what the highlighted one does at the foot", top_says?("Pikachu's details.")) },
  at { check("...the menu's small text inside the panel (#{panel_spills.inspect})", panel_spills.empty?) },
  at { check("...the hints: Choose, Select, Back (#{hints.inspect})", hints == ["Choose", "Select", "Back"]) },
  at { ps_iv(:@kr_menu)[:index] = menu_rows.index("Item"); $ps.refresh },
  I::USE,
  dmp("ps_04_item_submenu"),
  at { check("Item: its submenu in place, under its heading (#{menu_rows.inspect})", top_says?("ITEM") && menu_rows.include?("Give") && menu_rows.include?("Take")) },
  I::BACK,
  at { check("B in the submenu: back to Pikachu's menu", menu_rows.first == "Summary") },
  at { ps_iv(:@kr_menu)[:index] = menu_rows.index("Item"); $ps.refresh },
  I::USE,
  at { ps_iv(:@kr_menu)[:index] = menu_rows.index("Take"); $ps.refresh },
  I::USE,
  dmp("ps_05_message"),
  at { check("Take: the game's message in the bar along the bottom", over_says?("You received the Light Ball from Pikachu.") && hints == ["Continue"]) },
  I::USE,
  at { check("...A closes it, and the item's gone", $Trainer.party[0].item.nil? && ps_iv(:@kr_message).nil?) },
  I::USE,
  at { ps_iv(:@kr_menu)[:index] = menu_rows.index("RLD Actions"); $ps.refresh },
  I::USE,
  dmp("ps_06_kuray_actions"),
  at { check("RLD Actions (KIF's Kuray Actions): only Export, under its heading (#{menu_rows.inspect})", top_says?("RLD ACTIONS") && menu_rows == ["Export", "Cancel"]) },
  I::USE,
  at { check("...Export runs (KIF's host shows its message here)", over_says?("Exported Pikachu.")) },
  I::USE,
  I::USE,
  at { ps_iv(:@kr_menu)[:index] = menu_rows.index("Walk Together"); $ps.refresh },
  I::USE,
  at { check("the mod's command runs with the scene, the Pokemon and its place", $log.include?("WALK Pikachu 0")) },
  I::ACTION,
  at { check("X on a card: its Summary, the screen out of sight meanwhile", $log.include?("SUMMARY Pikachu inbattle=false hidden=true")) },
  I::X,
  at { check("Y on Pikachu: moving it, the title asking where (#{$ps.send(:title)})", $ps.send(:title) == "Move Pikachu Where?") },
  I::DOWN,
  dmp("ps_07_switch"),
  at { check("...Pikachu keeps a gold edge and a MOVING tag; the panel shows the swap", top_says?("MOVING") && top_says?("SWITCH") && hints.include?("Switch Here")) },
  I::USE,
  at { check("...A swaps them (#{$Trainer.party.first(3).map(&:name).inspect})", $Trainer.party[0].name == "Gyarados" && $Trainer.party[2].name == "Pikachu") },
  I::BACK
])
check("B closed it", !$ps.nil? && ps_iv(:@sprite).nil? || ps_iv(:@sprite).disposed?)
$Trainer.party = make_party

#---------------------------------------------------------------- B: a question, the Egg, the mouse
party_screen("B egg and mouse", [
  at { $ps.pbSelect(5) },
  dmp("ps_08_egg"),
  at { check("an Egg: the steps left as a number and a bar, PIF's words under it", top_says?("STEPS LEFT") && top_says?("640")) },
  at { check("...the Egg's words inside the panel (#{panel_spills.inspect})", panel_spills.empty?) },
  [:move, 20 + 8, 38 + 50],
  at { check("pointing at Pikachu's card picks it", cursor_on == 0) },
  [:click, 20 + 8, 38 + 50],
  at { check("a click opens its menu", menu_rows.first == "Summary") },
  [:rclick, 200, 200],
  at { check("a right click goes back to the cards", ps_iv(:@kr_mode) == :choose) },
  at { $export_on = false },
  I::USE,
  at { check("no RLD Actions while Export can't be used (#{menu_rows.inspect})", menu_rows.first == "Summary" && !menu_rows.include?("RLD Actions")) },
  I::BACK,
  at { $export_on = true },
  at { r = $ps.pbDisplayConfirm("Do you want to give it a nickname?"); $log << "CONFIRM #{r}" },
  I::USE,
  at { check("a question: Kanto Reloaded's Yes/No popup (#{$log.grep(/CONFIRM/).inspect})", $log.include?("CONFIRM true")) },
  I::BACK
])

#---------------------------------------------------------------- C: teaching a move (Grey Out), fewer than six
$log.clear
Input.queue = [dmp("ps_09_teach"),
               at { check("teaching Thunderbolt: the title says so, NOT ABLE greyed (the cursor on the first that can, Pikachu: LEARNED) (#{$ps.send(:title)}, #{cursor_on})",
                          $ps.send(:title) == "Teach Thunderbolt to Which?" && cursor_on == 0 && top_says?("LEARNED") && top_says?("POWER 90") && top_says?("ACC 100")) },
               at { check("...the move's words stay inside the panel (#{panel_spills.inspect})", panel_spills.empty?) },
               I::RIGHT,
               dmp("ps_09b_teach_replaces"),
               at { check("...Right skips Pidgeot (NOT ABLE) to Gyarados (#{cursor_on})", cursor_on == 2) },
               at { check("...four moves: it says one is replaced, inside the panel (#{panel_spills.inspect})",
                          top_says?("It must forget one.") && panel_spills.empty?) },
               I::USE]
begin
  pbMoveTutorChoose(:THUNDERBOLT, nil, true)
  check("...A picks Gyarados ($chosen #{$chosen})", $chosen == 2)
rescue Exception => e
  check("C teach: #{e.class}: #{e.message} #{e.backtrace.first(4).inspect}", false)
end
party_screen("C four", [
  dmp("ps_10_four"),
  at { check("four Pokemon: the empty spots dashed, EMPTY", top_says?("EMPTY")) },
  I::BACK
], $Trainer.party.first(4))

#---------------------------------------------------------------- D: a battle's menu
$game_temp.in_battle = true
Input.queue = [I::USE,
               dmp("ps_11_battle_menu"),
               at { check("in battle: the battle's commands, no mod commands (#{menu_rows.inspect})", menu_rows == ["Switch In", "Summary", "Cancel"]) },
               I::BACK, I::BACK]
begin
  scene = PokemonParty_Scene.new
  screen = PokemonPartyScreen.new(scene, $Trainer.party)
  screen.pbStartScene(_INTL("Choose a Pokémon."), 1)
  loop do
    i = screen.pbChoosePokemon
    break if i < 0
    scene.pbShowCommands(_INTL("Do what with {1}?", $Trainer.party[i].name), [_INTL("Switch In"), _INTL("Summary"), _INTL("Cancel")])
  end
  screen.pbEndScene
  check("D battle: done", true)
rescue Exception => e
  check("D battle: #{e.class}: #{e.message} #{e.backtrace.first(4).inspect}", false)
end
$game_temp.in_battle = false

#---------------------------------------------------------------- E: Light and Frost, Big Pokemon Icons
S.set(Reloaded::Palette::MODE, 2)
$big_icons = true
party_screen("E light", [
  dmp("ps_12_light"),
  at { check("Theme Mode Light: the Light colours", $ps.palette[:light] == true) },
  at { s = ps_iv(:@kr_card_icons)[0]
       check("Big Pokemon Icons: the battle sprite, fitted to its 50 px box (#{s.src_rect.height}, #{(s.zoom_x * 96).round})", s.src_rect.height == 96) },
  I::BACK
])
S.set(Reloaded::Palette::MODE, 3)
party_screen("E frost", [at { check("Frost: Light too (a full screen isn't see-through)", $ps.palette[:light] == true && Reloaded::Palette.menu_alpha(232) < 232) }, I::BACK])
S.set(Reloaded::Palette::MODE, 1)
party_screen("E glass", [at { check("Glass: Dark", !$ps.palette[:light]) }, I::BACK])
S.set(Reloaded::Palette::MODE, 0)
$big_icons = false

#---------------------------------------------------------------- F: Off
S.set(PS::TOGGLE, false)
check("Reloaded Party Screen Off: the game's own scene", PokemonParty_Scene.new.class == PokemonParty_Scene)
S.set(PS::TOGGLE, true)

errors = File.read(Reloaded::Log.path).lines.grep(/ERROR|skipped/)
check("no errors or skipped hooks in Kanto Reloaded's log (#{errors.length})", errors.empty?)
errors.first(6).each { |l| puts "  " + l }
puts $failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED"
exit($failed ? 1 : 0)
