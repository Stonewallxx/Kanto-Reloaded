# encoding: utf-8
# Checks Healing Moves outside the game, on stand-ins for the game's classes
# (named and shaped as PIF 6.8.2 and KIF Beta have them): what each kind of
# move does (and its preview's words), why one can't be used, PIF's
# challenges, using one (HP, status, PP), Heal Everyone's plan, the hooks on
# the game's field moves (listed in the party menu, the party screen kept
# open, the game's own Wait Until Morning passed through), Kanto Reloaded's
# Party Screen taking them over, and switching it Off.
# Usage: ruby Tools/Tests/healing_moves_test.rb "<KIF Beta>" <empty temp folder>
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
$msgs = []
eval(<<~RUBY, TOPLEVEL_BINDING, "014_Fake_Game.rb", 1)
  module GameData
    MoveData = Struct.new(:id, :name)
    class Move
      def self.get(id); MoveData.new(id, id.to_s.capitalize.sub("Softboiled", "Soft-Boiled")); end
    end
    StatusData = Struct.new(:id, :name)
    class Status
      def self.get(id); StatusData.new(id, { :POISON => "Poison", :BURN => "Burn", :SLEEP => "Sleep" }[id] || id.to_s); end
    end
    MapMeta = Struct.new(:outdoor_map)
    class MapMetadata
      def self.try_get(_id); MapMeta.new($outdoors); end
    end
  end
  class Pokemon
    class Move
      attr_accessor :id, :pp
      attr_reader :total_pp
      def initialize(id, pp = 10, total = 10); @id = id; @pp = pp; @total_pp = total; end
      def name; GameData::Move.get(@id).name; end
    end
    attr_accessor :name, :moves, :statusCount, :item, :species
    attr_reader :hp, :totalhp, :status
    def initialize(name, hp, total, moves = [], status = :NONE)
      @name = name; @species = name.upcase.to_sym; @hp = hp; @totalhp = total; @status = status
      @moves = moves.map { |m| m.is_a?(Move) ? m : Move.new(m) }; @statusCount = 0
    end
    def egg?; false; end
    def fainted?; @hp <= 0; end
    def hp=(v); return if fainted? && $PokemonSystem.no_reviving; @hp = v.clamp(0, @totalhp); @status = :NONE if @hp == 0; end
    def status=(v); return if fainted?; @status = v; end
    def heal_status; @status = :NONE; end
    def heal_PP; @moves.each { |m| m.pp = m.total_pp }; end
    def hasItem?(i); @item == i; end
    def types; [:NORMAL]; end
  end
  class Trainer; attr_accessor :party; end
  class Player < Trainer; def initialize; @party = []; end; end
  class PokemonSystem; attr_accessor :no_reviving, :no_healing_items_ow; end
  class GameMap; attr_accessor :map_id; end
  module HiddenMoveHandlers
    CanUseMove = {}; ConfirmUseMove = {}; UseMove = {}
    def self.hasHandler(item); !CanUseMove[item].nil? && !UseMove[item].nil?; end
    def self.triggerCanUseMove(item, pokemon, showmsg); CanUseMove[item] ? CanUseMove[item].call(item, pokemon, showmsg) : false; end
    def self.triggerConfirmUseMove(item, pokemon); ConfirmUseMove[item] ? ConfirmUseMove[item].call(item, pokemon) : true; end
    def self.triggerUseMove(item, pokemon); UseMove[item] ? UseMove[item].call(item, pokemon) : false; end
  end
  HiddenMoveHandlers::CanUseMove[:MORNINGSUN] = proc { |_m, _p, _s| $log << "PIF CAN MORNINGSUN"; true }
  HiddenMoveHandlers::UseMove[:MORNINGSUN] = proc { |_m, _p| $log << "PIF WAITED"; true }
  class PokemonPartyScreen
    def initialize(scene); @scene = scene; end
    def pbPokemonScreen; $in_screen = yield_self { HiddenMoveHandlers.triggerConfirmUseMove($confirm_move, $confirm_pkmn) }; end
  end
  def pbMessage(t); $msgs << t; end
RUBY
$PokemonSystem = PokemonSystem.new
$game_map = GameMap.new
$game_map.map_id = 5
$outdoors = true
$Trainer = Player.new

def make_party
  [Pokemon.new("Chansey", 310, 320, [:SOFTBOILED, :HEALBELL]), Pokemon.new("Pikachu", 40, 95, [:THUNDERBOLT]),
   Pokemon.new("Gengar", 70, 110, [:LICK], :POISON), Pokemon.new("Alakazam", 50, 90, [:RECOVER, :HEALPULSE]),
   Pokemon.new("Snorlax", 160, 160, [:REST]), Pokemon.new("Pidgeot", 80, 120, [:ROOST])]
end
$Trainer.party = make_party

load File.join(KIF_ROOT, "Mods/KantoReloaded/Bootstrap.rb")
R = Reloaded
HM = R::HealingMoves
check("Kanto Reloaded boots with Healing Moves (#{R::Bootstrap.status}, #{R::Bootstrap.failures.inspect})", R::Bootstrap.status == :ready)
# The screens need the game's drawing; here they say what they'd do
$screen_calls = []
module Reloaded
  module HealingMovesScreen
    def self.from_party(scene, pkmn, id); $screen_calls << [:party, pkmn.name, id]; true; end
    def self.from_field(pkmn, id); $screen_calls << [:field, pkmn.name, id]; true; end
  end
end
def pk; $Trainer.party; end
def words(u, id, t = nil); pv = HM.preview(u, id, t); pv && pv[:rows].map { |r| [pk[r[0]].name, r[4]] }; end

#---------------------------------------------------------------- the feature, its entries
check("Healing Moves is a feature, On to start", R::Features.registered?(:healing_moves) && R::Features.on?(:healing_moves))
om = R::OverworldMenu.entry(:heal_with_moves)
check("the Overworld Menu: Heal with Moves, a Main action, shown while someone knows a healing move",
      om && om.kind == :action && R::OverworldMenu.shown?(om))
check("Kanto Reloaded's Party Screen takes over each healing move, Soft-Boiled and Milk Drink too",
      HM::MOVES.keys.all? { |id| R::PartyScreen.field_move_handler(id) } && R::PartyScreen.field_move_handler(:MILKDRINK))
check("the healers: Chansey, Alakazam, Snorlax, Pidgeot, with their healing moves (#{HM.healers.inspect})",
      HM.healers == [[0, [:SOFTBOILED, :HEALBELL]], [3, [:RECOVER, :HEALPULSE]], [4, [:REST]], [5, [:ROOST]]])

#---------------------------------------------------------------- what each does
check("Recover: heals itself by half its max HP (#{words(3, :RECOVER).inspect})", words(3, :RECOVER) == [["Alakazam", "+40 HP"]])
pv = HM.preview(0, :SOFTBOILED, 1)
check("Soft-Boiled on Pikachu: +55 HP for Pikachu, Chansey gives 64 HP and 1 PP (#{pv[:rows].inspect})",
      pv[:rows][0][0..4] == [1, 40, 95, 95, "+55 HP"] && pv[:rows][1][0..4] == [0, 310, 246, 320, "-64 HP"] &&
      pv[:rows][1][5] == "PP 10 to 9" && pv[:note].include?("a fifth of its max HP"))
check("Heal Pulse: another Pokémon, half its max (#{words(3, :HEALPULSE, 1).inspect}); not itself",
      words(3, :HEALPULSE, 1)[0] == ["Pikachu", "+48 HP"] && HM.preview(3, :HEALPULSE, 3).nil?)
check("Heal Bell: cures the party (#{words(0, :HEALBELL).inspect})", words(0, :HEALBELL)[0] == ["Gengar", "Cures Poison"])
pk[5].moves << Pokemon::Move.new(:LIFEDEW)
check("Life Dew: a quarter for each one hurt (#{words(5, :LIFEDEW).inspect})",
      words(5, :LIFEDEW).include?(["Pikachu", "+23 HP"]) && words(5, :LIFEDEW).none? { |n, _w| n == "Snorlax" })
pk[5].moves << Pokemon::Move.new(:WISH)
check("Wish: the user's half to anyone, itself too (#{words(5, :WISH, 1).inspect})", words(5, :WISH, 1)[0] == ["Pikachu", "+55 HP"] && HM.preview(5, :WISH, 5))
pk[4].hp = 100
check("Rest: full HP, falls asleep (#{words(4, :REST).inspect})", words(4, :REST) == [["Snorlax", "+60 HP, Falls Asleep"]])
pk[2].moves << Pokemon::Move.new(:REFRESH)
check("Refresh: cures its own poison (#{words(2, :REFRESH).inspect})", words(2, :REFRESH) == [["Gengar", "Cures Poison"]])
pk[3].moves << Pokemon::Move.new(:AQUARING)
amount = words(3, :AQUARING)[0][1]
pk[3].item = :BIGROOT
check("Aqua Ring: a sixteenth (#{amount}), more with a Big Root (#{words(3, :AQUARING)[0][1]})", amount == "+5 HP" && words(3, :AQUARING)[0][1] == "+6 HP")
$Trainer.party = make_party

#---------------------------------------------------------------- why not
pk[4].moves[0].pp = 0
check("no PP left: says so (#{HM.usable(4, :REST).inspect})", HM.usable(4, :REST) == "No PP Left")
check("full HP: Roost says so once Pidgeot's healed", (pk[5].hp = 120) && HM.usable(5, :ROOST) == "Full HP")
pk[0].hp = 60
check("Soft-Boiled without enough HP to give (#{HM.usable(0, :SOFTBOILED).inspect})", HM.usable(0, :SOFTBOILED) == "Not Enough HP")
pk[2].heal_status
check("Heal Bell with nothing to cure (#{HM.usable(0, :HEALBELL).inspect})", HM.usable(0, :HEALBELL) == "Nothing to Cure")
pk[3].hp = 0
check("a fainted Pokémon can't use its moves (#{HM.usable(3, :RECOVER).inspect})", HM.usable(3, :RECOVER) == "Fainted")
$Trainer.party = make_party
pk[1].moves << Pokemon::Move.new(:REVIVALBLESSING)
check("Revival Blessing with no one fainted (#{HM.usable(1, :REVIVALBLESSING).inspect})", HM.usable(1, :REVIVALBLESSING) == "No One to Revive")
pk[2].hp = 0
check("...with Gengar fainted: revives it to half (#{words(1, :REVIVALBLESSING, 2).inspect})", words(1, :REVIVALBLESSING, 2)[0] == ["Gengar", "Revived"])
$PokemonSystem.no_reviving = true
check("PIF's No reviving (KIF's Nuzlocke turns it on): Revival Blessing locked (#{HM.usable(1, :REVIVALBLESSING).inspect})",
      HM.usable(1, :REVIVALBLESSING) == "Locked by No Reviving")
pk[1].moves << Pokemon::Move.new(:HEALINGWISH)
check("...Healing Wish too: the user would faint for good", HM.usable(1, :HEALINGWISH) == "Locked by No Reviving")
$PokemonSystem.no_reviving = false
$PokemonSystem.no_healing_items_ow = true
check("PIF's No heals (overworld): every healing move locked (#{HM.usable(3, :RECOVER).inspect}), the menu entry too",
      HM.usable(3, :RECOVER) == "Locked by No Heals (Overworld)" && R::OverworldMenu.usable(om) != true)
$PokemonSystem.no_healing_items_ow = false
$Trainer.party = make_party

#---------------------------------------------------------------- using one
before = HM.use!(0, :SOFTBOILED, 1)
check("Soft-Boiled used: Pikachu 95, Chansey 246, one PP fewer",
      before && pk[1].hp == 95 && pk[0].hp == 246 && pk[0].moves[0].pp == 9)
HM.use!(0, :HEALBELL)
check("Heal Bell used: Gengar cured", pk[2].status == :NONE && pk[0].moves[1].pp == 9)
pk[4].hp = 100
HM.use!(4, :REST)
check("Rest used: full HP, asleep for a while", pk[4].hp == 160 && pk[4].status == :SLEEP && pk[4].statusCount == 3)
pk[1].moves << Pokemon::Move.new(:LUNARDANCE)
pk[3].moves[0].pp = 2
pk[3].hp = 30
HM.use!(1, :LUNARDANCE, 3)
check("Lunar Dance: the user faints, Alakazam fully healed with its PP back",
      pk[1].hp == 0 && pk[3].hp == 90 && pk[3].moves[0].pp == 10)
check("a move that can't be used changes nothing", HM.use!(4, :REST).nil? && pk[4].moves[0].pp == 9)
$Trainer.party = make_party

#---------------------------------------------------------------- Heal Everyone
steps, after = HM.plan
plan = steps.map { |u, id, t| [pk[u].name, id, t ? pk[t].name : nil] }
check("Heal Everyone's plan: the most HP for the fewest PP, Heal Pulse before Soft-Boiled (it costs no HP) (#{plan.inspect})",
      plan.include?(["Alakazam", :RECOVER, nil]) && plan.include?(["Alakazam", :HEALPULSE, "Pikachu"]) &&
      plan.include?(["Chansey", :HEALBELL, nil]) && plan.none? { |_n, id, _t| id == :SOFTBOILED })
check("...no PP on a top-up under 5% (Chansey's 10 HP)", plan.none? { |_n, _id, t| t == "Chansey" })
check("...never Rest, Healing Wish or Lunar Dance", plan.none? { |_n, id, _t| [:REST, :HEALINGWISH, :LUNARDANCE].include?(id) })
check("...everyone better off after it (#{after.map { |h| h[:hp] }.inspect})",
      after[1][:hp] == 95 && after[2][:hp] == 110 && after[3][:hp] == 90 && after[5][:hp] == 120 && after[2][:status].nil?)
$Trainer.party = [Pokemon.new("Chansey", 310, 320, [:SOFTBOILED]), Pokemon.new("Pikachu", 40, 95, [:THUNDERBOLT])]
check("...with Soft-Boiled the only way: it's used (#{HM.plan[0].inspect})", HM.plan[0].first == [0, :SOFTBOILED, 1])
$Trainer.party = make_party
steps, after = HM.plan
n = HM.run_plan(steps)
check("...run: each step used (#{n} of #{steps.length})", n == steps.length && pk[1].hp == 95 && pk[2].status == :NONE)
check("...and then nothing left to plan", HM.plan[0].empty?)
$Trainer.party = make_party

#---------------------------------------------------------------- the game's field moves
check("the party menu lists them as field moves (hasHandler)", HiddenMoveHandlers.hasHandler(:RECOVER) && HiddenMoveHandlers.hasHandler(:HEALBELL))
check("...can use: as Healing Moves says", HiddenMoveHandlers.triggerCanUseMove(:RECOVER, pk[3], false) == true)
pk[5].hp = 120
$msgs.clear
check("...and says why not (#{$msgs.inspect})", HiddenMoveHandlers.triggerCanUseMove(:ROOST, pk[5], true) == false && $msgs == ["Full HP"])
$confirm_move = :RECOVER
$confirm_pkmn = pk[3]
$screen_calls.clear
PokemonPartyScreen.new(:scene).pbPokemonScreen
check("in the game's party screen: the move is used there and the screen stays open (#{$screen_calls.inspect}, #{$in_screen.inspect})",
      $screen_calls == [[:party, "Alakazam", :RECOVER]] && $in_screen == false)
$screen_calls.clear
check("outside a party screen: Confirm lets it go on, and using it runs here (#{$screen_calls.inspect})",
      HiddenMoveHandlers.triggerConfirmUseMove(:RECOVER, pk[3]) == true && HiddenMoveHandlers.triggerUseMove(:RECOVER, pk[3]) == true &&
      $screen_calls == [[:field, "Alakazam", :RECOVER]])
espeon = Pokemon.new("Espeon", 130, 130, [:MORNINGSUN])
$Trainer.party << espeon
$log.clear
HM.defer_wait(espeon, :MORNINGSUN)
ok = HiddenMoveHandlers.triggerCanUseMove(:MORNINGSUN, espeon, true) && HiddenMoveHandlers.triggerConfirmUseMove(:MORNINGSUN, espeon) &&
     HiddenMoveHandlers.triggerUseMove(:MORNINGSUN, espeon)
check("Morning Sun's Wait: the game's own handlers run, once (#{$log.inspect})", ok && $log == ["PIF CAN MORNINGSUN", "PIF WAITED"] && !HM.deferred?(espeon, :MORNINGSUN))
check("...a full-HP Espeon outdoors can still wait", HM.usable(pk.index(espeon), :MORNINGSUN) == true)
$outdoors = false
check("...indoors, with nothing to heal: Full HP", HM.usable(pk.index(espeon), :MORNINGSUN) == "Full HP")
$outdoors = true
$Trainer.party = make_party

#---------------------------------------------------------------- Off
R::Features.set(:healing_moves, :off)
check("Off: not listed as field moves, the game's own again", !HiddenMoveHandlers.hasHandler(:RECOVER) && HiddenMoveHandlers.hasHandler(:MORNINGSUN))
check("...the Party Screen's takeover says no (the game's Soft-Boiled)", R::PartyScreen.field_move_handler(:SOFTBOILED).call(nil, pk[0], :SOFTBOILED) == false)
check("...and the menu entry hides", !R::OverworldMenu.shown?(om))
R::Features.set(:healing_moves, :on)

lines = File.read(R::Log.path).lines
errors = lines.grep(/ERROR/) + lines.grep(/skipped/).grep(/healing|toast/)
check("no errors, and none of Healing Moves' hooks skipped, in Kanto Reloaded's log (#{errors.length})", errors.empty?)
errors.first(6).each { |l| puts "  " + l }
puts $failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED"
exit($failed ? 1 : 0)
