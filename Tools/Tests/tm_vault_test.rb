# encoding: utf-8
# Checks the TM Vault outside the game, on stand-ins for the game's classes
# (named and shaped as PIF 6.8.2 and KIF Beta have them): Tutor.net's
# unlocks and the Bag brought in at load (nothing NEW then), a machine
# reaching the Bag, a move tutor, pbTutorNetAdd, the toast, NEW and
# Favorites, who knows / can learn / can't, Relearn (KIF's Change Moves
# list, its Egg Moves), the level a move is learned at, Coverage, teaching
# (with room, and over a move: the same place), the Checklist and the kinds
# read from the maps, the Randomizer's note, the party menu's Relearn Moves,
# and Off (Tutor.net's back).
# Usage: ruby Tools/Tests/tm_vault_test.rb "<KIF Beta>" <empty temp folder>
require "fileutils"
require "json"

KIF_ROOT = File.expand_path(ARGV[0])
USERDIR = File.expand_path(ARGV[1])
require_relative "work_folder"
KRWork.claim(USERDIR)
$log = []
$failed = false

def check(label, cond)
  puts "#{cond ? "ok  " : "FAIL"} #{label}"
  $failed = true unless cond
end

load File.join(KIF_ROOT, "Mods/KantoReloaded/Tools/Tests/test_stubs.rb")

#---------------------------------------------------------------- the game's classes, as stand-ins
eval(<<~'RUBY', TOPLEVEL_BINDING, "014_Fake_Game.rb", 1)
  module Effectiveness
    INEFFECTIVE = 0; NOT_VERY_EFFECTIVE_ONE = 1; NORMAL_EFFECTIVE_ONE = 2; SUPER_EFFECTIVE_ONE = 4
  end
  module GameData
    class Move
      DATA = {}
      attr_reader :id, :name, :type, :base_damage
      def initialize(id, name, type, dmg); @id, @name, @type, @base_damage = id, name, type, dmg; end
      def self.add(id, name, type, dmg); DATA[id] = new(id, name, type, dmg); end
      def self.try_get(id); DATA[id.is_a?(String) ? id.to_sym : id]; end
      def self.get(id); try_get(id) || raise("no move #{id}"); end
      def self.exists?(id); !try_get(id).nil?; end
    end
    class Item
      DATA = {}
      attr_reader :id, :move
      def initialize(id, move); @id = id; @move = move; end
      def self.add(id, move); DATA[id] = new(id, move); end
      def self.try_get(id); DATA[id.is_a?(String) ? id.to_sym : id]; end
      def self.get(id); try_get(id) || raise("no item #{id}"); end
      def self.each(&b); DATA.values.each(&b); end
      def is_machine?; !@move.nil?; end
    end
    class Type
      DATA = {}
      attr_reader :id, :pseudo_type
      def initialize(id, weak, pseudo = false); @id = id; @weak = weak; @pseudo_type = pseudo; end
      def self.add(id, weak, pseudo = false); DATA[id] = new(id, weak, pseudo); end
      def self.each(&b); DATA.values.each(&b); end
      def effectiveness(attack); @weak.include?(attack) ? Effectiveness::SUPER_EFFECTIVE_ONE : Effectiveness::NORMAL_EFFECTIVE_ONE; end
    end
  end
  class Pokemon
    MAX_MOVES = 4
    class Move; attr_reader :id; def initialize(id); @id = id; end; end
    attr_accessor :name, :moves, :first_moves, :learned
    def initialize(name, moves, can, egg = false)
      @name = name; @moves = moves.map { |m| Move.new(m) }; @can = can; @egg = egg; @first_moves = []; @learned = []
    end
    def egg?; @egg; end
    def shadowPokemon?; false; end
    def hasMove?(m); @moves.any? { |x| x.id == m }; end
    def compatible_with_move?(m); @can.include?(m); end
    def learn_move(m); return if hasMove?(m); @moves << Move.new(m); @moves.shift if @moves.length > MAX_MOVES; end
    def forget_move_at_index(i); @learned << @moves[i].id; @moves.delete_at(i); end
    def getMoveRelearnerList; [[1, :TACKLE], [20, :THUNDERBOLT]]; end
  end
  class PokemonBag
    attr_reader :pockets
    def initialize; @pockets = [[], []]; end
    def pbStoreItem(item, qty = 1); @pockets[1] << [item, qty]; true; end
  end
  class Player; attr_accessor :party, :tutorlist; end
  def pbMoveTutorChoose(move, *a); $tutor_ok; end
  def pbTutorNetAdd(move, cost = 0); ($Trainer.tutorlist ||= []) << [move, cost]; true; end
  class PokemonPartyScreen
    def pbRememberMoves(pkmn); $log << "KIF RELEARNER #{pkmn.name}"; true; end
  end
  module KIF
    PORT_VERSION = "1.1.1"
    module MoveLearning
      def self.change_moves_list(pkmn); [:THUNDERBOLT, :SURF, :TACKLE].reject { |m| pkmn.hasMove?(m) }; end
      def self.egg_moves_for(pkmn); [:SURF]; end
    end
  end
RUBY

[[:THUNDERBOLT, "Thunderbolt", :ELECTRIC, 90], [:ICEBEAM, "Ice Beam", :ICE, 90], [:SURF, "Surf", :WATER, 90],
 [:BODYSLAM, "Body Slam", :NORMAL, 85], [:FLAMETHROWER, "Flamethrower", :FIRE, 90], [:TOXIC, "Toxic", :POISON, 0],
 [:TACKLE, "Tackle", :NORMAL, 40], [:ROAR, "Roar", :NORMAL, 0], [:GIGADRAIN, "Giga Drain", :GRASS, 75],
 [:BULKUP, "Bulk Up", :FIGHTING, 0], [:SUNNYDAY, "Sunny Day", :FIRE, 0]].each { |a| GameData::Move.add(*a) }
[[:HM03, :SURF], [:TM05, :ROAR], [:TM06, :TOXIC], [:TM08, :BULKUP], [:TM11, :SUNNYDAY], [:TM13, :ICEBEAM],
 [:TM19, :GIGADRAIN], [:TM24, :THUNDERBOLT], [:POTION, nil]].each { |a| GameData::Item.add(*a) }
[[:NORMAL, [:FIGHTING]], [:FIRE, [:WATER, :GROUND]], [:WATER, [:ELECTRIC, :GRASS]], [:ELECTRIC, [:GROUND]],
 [:GRASS, [:FIRE, :ICE]], [:ICE, [:FIRE]], [:FLYING, [:ELECTRIC, :ICE]], [:GROUND, [:WATER, :GRASS, :ICE]]].each { |a| GameData::Type.add(*a) }
GameData::Type.add(:QMARKS, [:NORMAL], true)

$Trainer = Player.new
$Trainer.tutorlist = [[:BODYSLAM, 10000]]
$PokemonBag = PokemonBag.new
$PokemonBag.pockets[1] << [:TM24, 1]
$tutor_ok = false

load File.join(KIF_ROOT, "Mods/KantoReloaded/Bootstrap.rb")
R = Reloaded
TV = R::TMVault
check("Kanto Reloaded boots with the TM Vault (#{R::Bootstrap.status}, #{R::Bootstrap.failures.inspect})", R::Bootstrap.status == :ready)
check("a feature, On to start, taking over KIF's Tutor.net (F-POKE-05_TutorNet)",
      R::Features.on?(:tm_vault) && R::Features.definition(:tm_vault)[:takes_over] == ["F-POKE-05_TutorNet"])
$toasts = []
module Reloaded
  module Toast
    def self.show(text, icon: nil, pill: nil, paint: nil); $toasts << [text, icon, pill]; true; end
  end
  class TMVaultScreen
    def self.open(tab, pkmn); $opened << [tab, pkmn && pkmn.name]; true; end
  end
end
$opened = []
R::SaveStore.__send__(:from_save, nil)
R::Events.emit(:save_loaded, {})

#---------------------------------------------------------------- the moves
check("at load: Tutor.net's unlocks and the Bag's machines are in (#{TV.moves.inspect})", TV.moves == [:BODYSLAM, :THUNDERBOLT])
check("...nothing NEW from that first look, and no toasts", !TV.new?(:BODYSLAM) && !TV.new?(:THUNDERBOLT) && $toasts.empty?)
$PokemonBag.pbStoreItem(:TM13)
check("a TM reaching the Bag: in the Vault, NEW (#{TV.moves.inspect})", TV.known?(:ICEBEAM) && TV.new?(:ICEBEAM))
check("...the toast: the TM's disc, Added to TM Vault, NEW (#{$toasts.last.inspect})",
      $toasts.last == ["Added to TM Vault: Ice Beam", "Graphics/Items/machine_ICE", ["NEW", :green]])
$PokemonBag.pbStoreItem(:POTION)
check("...anything else in the Bag: nothing (#{TV.moves.length})", TV.moves.length == 3)
pbMoveTutorChoose(:SURF)
check("a move tutor not used (cancelled): nothing", !TV.known?(:SURF))
$tutor_ok = true
pbMoveTutorChoose(:SURF)
check("...used: the move is in (from a tutor)", TV.known?(:SURF) && TV.data["sources"]["SURF"] == "tutor")
pbTutorNetAdd(:FLAMETHROWER, 10000)
check("Tutor.net's own pbTutorNetAdd (events, other mods): in too", TV.known?(:FLAMETHROWER))
check("a move already in: register says so (false), no second toast",
      TV.register(:SURF) == false && $toasts.count { |t| t[0].include?("Surf") } == 1)
check("Recent: the order they came (#{TV.added_at(:ICEBEAM)} < #{TV.added_at(:SURF)})", TV.added_at(:ICEBEAM) < TV.added_at(:SURF))
TV.toggle_favorite(:SURF)
check("Favorites: starred, and unstarred again", TV.favorite?(:SURF) && !TV.toggle_favorite(:SURF) && !TV.favorite?(:SURF))
TV.seen!
check("opening the Vault: nothing NEW any more", TV.moves.none? { |m| TV.new?(m) })
check("a machine's name for a move: TM24, Tutor for a tutor's (#{TV.label(:THUNDERBOLT)}, #{TV.label(:BODYSLAM)})",
      TV.label(:THUNDERBOLT) == "TM24" && TV.label(:BODYSLAM) == "Tutor")

#---------------------------------------------------------------- a Pokémon and a move
pika = Pokemon.new("Pikachu", [:THUNDERBOLT, :TOXIC], [:THUNDERBOLT, :SURF, :ICEBEAM])
egg = Pokemon.new("Egg", [], [:SURF], true)
check("who: knows it, can learn it, can't, an Egg can't",
      TV.compat(:THUNDERBOLT, pika) == :knows && TV.compat(:SURF, pika) == :learn && TV.compat(:FLAMETHROWER, pika) == :cant &&
      TV.compat(:SURF, egg) == :cant)
check("Relearn: KIF's Change Moves list, less what it knows (#{TV.relearnable(pika).inspect})", TV.relearnable(pika) == [:SURF, :TACKLE])
check("...Surf is an Egg Move (KIF's Egg Moves)", TV.egg_move?(pika, :SURF) && !TV.egg_move?(pika, :TACKLE))
check("the level a move is learned at: Thunderbolt 20, Tackle 1, an Egg Move 0 (#{TV.level_learned(pika, :THUNDERBOLT)})",
      TV.level_learned(pika, :THUNDERBOLT) == 20 && TV.level_learned(pika, :TACKLE) == 1 && TV.level_learned(pika, :SURF) == 0)
now, after = TV.coverage(pika, :SURF)
check("Coverage: Thunderbolt hits Water and Flying (#{now.inspect}); with Surf, Fire and Ground too (#{after.inspect})",
      now == [:WATER, :FLYING] && after.sort == [:FIRE, :FLYING, :GROUND, :WATER])
_now, swapped = TV.coverage(pika, :SURF, 0)
check("...Surf over Thunderbolt: Fire and Ground, Water and Flying lost (#{swapped.inspect})", swapped.sort == [:FIRE, :GROUND])
check("...no pseudo type (???) in it", !after.include?(:QMARKS))
check("teaching with room: learned (#{TV.teach(pika, :SURF)})", pika.hasMove?(:SURF) && pika.moves.length == 3)
pika.learn_move(:TACKLE)
check("four moves, nothing to forget: not taught", TV.teach(pika, :ICEBEAM) == false && !pika.hasMove?(:ICEBEAM))
TV.teach(pika, :ICEBEAM, 1)
check("...over the second (Toxic): Ice Beam in its place, Toxic left to relearn (#{pika.moves.map(&:id).inspect})",
      pika.moves.map(&:id) == [:THUNDERBOLT, :ICEBEAM, :SURF, :TACKLE] && pika.learned.include?(:TOXIC))
check("an Egg isn't taught", TV.teach(egg, :SURF) == false)

#---------------------------------------------------------------- the Checklist
maps = File.join(USERDIR, "maps")
FileUtils.mkdir_p(maps)
File.binwrite(File.join(maps, "Map001.rxdata"), "\x04\b...Kernel.pbItemBall(PBItems::TM05)...")
File.binwrite(File.join(maps, "Map002.rxdata"), "...pbItemBall(:TM19)......pbReceiveItem(:TM19)...")
File.binwrite(File.join(maps, "Map003.rxdata"), "...setPrice(:TM08,4)...pbPokemonMart([:TM11, :POTION])...")
File.binwrite(File.join(maps, "Map004.rxdata"), "...pbItemBall(:TM11)...")
kinds = TV.scan_maps(maps)
check("the maps read: an item ball Ground, a gift Gift, a shop Store; a shop wins over the ground (#{kinds.inspect})",
      kinds == { "TM05" => :ground, "TM19" => :gift, "TM08" => :store, "TM11" => :store })
TV.instance_variable_set(:@kinds, kinds)
list = TV.checklist.map { |it, mv, k| [it.id, mv, k] }
check("the Checklist: the machines not in the Vault, each with its kind (#{list.inspect})",
      list == [[:TM05, :ROAR, :ground], [:TM06, :TOXIC, nil], [:TM08, :BULKUP, :store], [:TM11, :SUNNYDAY, :store], [:TM19, :GIGADRAIN, :gift]])
check("...the Randomizer off: no note", TV.randomized? == false)
Object.const_set(:SWITCH_RANDOM_ITEMS_GENERAL, 900)
$game_switches = { 900 => true }
check("...its items on: the note shows", TV.randomized? == true)

#---------------------------------------------------------------- the party menu, Off
PokemonPartyScreen.new.pbRememberMoves(pika)
check("the party menu's Relearn Moves: the TM Vault's Relearn on that Pokémon (#{$opened.inspect})",
      $opened.last == [:relearn, "Pikachu"] && !$log.include?("KIF RELEARNER Pikachu"))
check("the Pause Menu: a Pinned TM Vault in Tutor.net's place, and an Overworld Menu action",
      R::PauseMenu.pinned_keys[1].to_s == "tm_vault" && R::PauseMenu.taken_over.include?("kif_tutornet") &&
      R::OverworldMenu.entry(:tm_vault) && R::OverworldMenu.entry(:tm_vault).kind == :action)
R::Features.set(:tm_vault, :off)
PokemonPartyScreen.new.pbRememberMoves(pika)
check("Off: KIF's own relearner again", $log.include?("KIF RELEARNER Pikachu"))
$PokemonBag.pbStoreItem(:TM05)
check("...a TM reaching the Bag isn't kept by it (Tutor.net's again)", !TV.known?(:ROAR))
R::Features.set(:tm_vault, :on)

# (the stand-ins have no game for the other features' hooks: only the TM Vault's count)
errors = File.read(R::Log.path).lines.select { |l| l.include?("ERROR") || (l.include?("skipped") && l.include?("tm_vault")) }
check("no errors, and none of the TM Vault's hooks skipped, in Kanto Reloaded's log (#{errors.length})", errors.empty?)
errors.first(6).each { |l| puts "  " + l }
puts $failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED"
exit($failed ? 1 : 0)
