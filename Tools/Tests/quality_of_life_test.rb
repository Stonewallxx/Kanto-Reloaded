# encoding: utf-8
# Checks Quality of Life outside the game, on stand-ins for the game's
# classes (named and shaped as PIF 6.8.2 and KIF Beta have them): each
# toggle On and Off, what a save remembers using, level locks, and Super
# Candy's raising.
# Usage: ruby Tools/Tests/quality_of_life_test.rb "<KIF Beta>" <empty temp folder>
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
$confirm = true
$drawn = 0
module Graphics
  def self.update; $drawn += 1; end
  def self.width; 512; end
  def self.height; 384; end
end
class FakeEvent
  def initialize; @procs = []; end
  def +(p); @procs << p; self; end
  def trigger(*a); @procs.each { |p| p.call(nil, a) }; end
end
module Events
  @onStepTaken = FakeEvent.new
  @onStartBattle = FakeEvent.new
  class << self; attr_accessor :onStepTaken, :onStartBattle; end
end
eval(<<~RUBY, TOPLEVEL_BINDING, "014_Fake_Game.rb", 1)
  module Settings; MAX_MONEY = 999_999; NB_BADGES = 8; end
  SWITCH_USED_AN_INCENSE = 1
  SWITCH_IS_REMATCH = 200
  SWITCH_FISHING_AUTOHOOK = 916
  module GameData
    class GrowthRate
      def self.max_level; 100; end
      def minimum_exp_for_level(lv); lv ** 3; end
      def level_from_exp(exp); lv = 1; lv += 1 while lv < 100 && (lv + 1) ** 3 <= exp; lv; end
      def add_exp(exp, gain); [exp + gain, 1_000_000].min; end
      def maximum_exp; 1_000_000; end
    end
    MoveData = Struct.new(:id, :name, :total_pp)
    class Move
      LIST = { :TACKLE => 35, :THUNDER => 10, :THUNDERBOLT => 15, :GROWL => 40, :BITE => 25 }
      def self.get(id); MoveData.new(id, id.to_s.capitalize, LIST[id] || 20); end
    end
    ItemData = Struct.new(:id, :name)
    class Item
      def self.get(id); ItemData.new(id, { :SUPERREPEL => "Super Repel" }[id] || id.to_s); end
      def self.icon_filename(id); "Graphics/Items/\#{id}"; end
    end
  end
  class Pokemon
    MAX_MOVES = 4
    class Move
      attr_reader :id, :pp, :ppup
      def initialize(id); @id = id; @ppup = 0; @pp = total_pp; end
      def pp=(v); @pp = v.clamp(0, total_pp); end
      def total_pp; m = GameData::Move.get(@id).total_pp; m + m * @ppup / 5; end
    end
    attr_accessor :name, :happiness, :owner, :steps_to_hatch, :force_disobey, :species, :movelist
    attr_reader :exp, :moves
    def initialize(name, level, owner = nil)
      @name = name; @species = name.upcase.to_sym; @owner = owner; @moves = []; @steps_to_hatch = 0; @happiness = 70
      @exp = growth_rate.minimum_exp_for_level(level); @movelist = []
    end
    def growth_rate; GameData::GrowthRate.new; end
    def level; growth_rate.level_from_exp(@exp); end
    def level=(v); @exp = growth_rate.minimum_exp_for_level(v); end
    def exp=(v); @exp = v; end
    def egg?; @steps_to_hatch > 0; end
    def hasMove?(m); @moves.any? { |x| x.id == m }; end
    def numMoves; @moves.length; end
    def learn_move(m); @moves << Pokemon::Move.new(m); end
    def getMoveList; @movelist; end
    def changeHappiness(_m); end
    def calc_stats; end
    def shadowPokemon?; false; end
  end
  class Player
    attr_reader :money
    attr_accessor :party, :id, :badge_count
    def initialize; @money = 3000; @party = []; @id = 7; @badge_count = 2; end
    def money=(v); @money = v.clamp(0, Settings::MAX_MONEY); end
  end
  class PokemonGlobalMetadata; attr_accessor :repel, :tempRepel, :daycareEgg; end
  class PokemonMartAdapter
    def getMoney; $Trainer.money; end
    def setMoney(v); $Trainer.money = v; end
  end
  class SafariState
    attr_accessor :steps
    def initialize; @steps = 600; @in = true; end
    def inProgress?; @in; end
    def stop; @in = false; end
  end
  class PokemonEncounters
    def initialize; @step_chances = { :Land => 20 }; end
    def encounter_triggered?(t, repel_active = false, by_step = true); $chance = @step_chances[t]; true; end
  end
  class PokeBattle_Battle
    attr_accessor :moneyGain
    def initialize; @moneyGain = true; end
    def pbParty(_i); $Trainer.party; end
    def pbOwnedByPlayer?(i); i.even?; end
    def pbGainMoney
      $shown = nil
      return if $game_switches[SWITCH_IS_REMATCH]
      return unless @moneyGain
      old = $Trainer.money
      $Trainer.money += 1000
      $shown = $Trainer.money - old
    end
    def pbCaptureCalc(*_a); 1; end
    def pbLearnMove(idx, move); pbParty(0)[idx].learn_move(move); end
    def pbDisplay(t); $msgs << t; end
    def pbDisplayConfirm(t); $msgs << t; $confirm; end
    def pbGainExpOne(idx, *_rest)
      pk = pbParty(0)[idx]
      pk.instance_variable_set(:@exp, pk.growth_rate.add_exp(pk.exp, 50_000))
    end
  end
  class PokeBattle_Battler
    attr_accessor :battle, :index, :pokemon
    def initialize(b, i, pk); @battle = b; @index = i; @pokemon = pk; end
    def pbReducePP(move); move.pp -= 1; true; end
    def pbObedienceCheck?(_choice); false; end
  end
  class PokemonEvolutionScene
    def pbEvolution(*_a); 9.times { Graphics.update }; :evolved; end
    def pbEvolutionSuccess(*_a); end
  end
  class Scene_Map; def update; end; end
  def isRepelActive; $PokemonGlobal.repel > 0; end
  def pbRepel(item, steps); $PokemonGlobal.repel = steps; 3; end
  def pbChangeLevel(pkmn, lv, _scene)
    pkmn.level = lv
    pkmn.getMoveList.each { |l, m| pbLearnMove(pkmn, m, true) if l == pkmn.level }
  end
  def can_use_rare_candy(pkmn); pkmn.level < 100; end
  def pbLearnMove(pkmn, move, ignore = false, bymachine = false, fast = false)
    return false if pkmn.hasMove?(move) || pkmn.numMoves >= 4
    pkmn.learn_move(move)
    true
  end
  def pbMessage(t); $msgs << t; end
  def pbConfirmMessage(t); $msgs << t; $confirm; end
  def pbFishing(*_a); $hooked = $game_switches[SWITCH_FISHING_AUTOHOOK]; true; end
  def rematchable_trainer_battle(*_a); b = PokeBattle_Battle.new; b.moneyGain = false; b.pbGainMoney; end
  def pbEvolutionCheck(levels); $evo_check = levels; end
  def pbDayCareDeposited; $deposited; end
  def pbDayCareGetCompat; $compat; end
RUBY
class Switches
  def initialize; @h = Hash.new(false); end
  def [](i); @h[i]; end
  def []=(i, v); @h[i] = v; end
end
$game_switches = Switches.new
class BagStub
  def initialize; @items = Hash.new(0); end
  def add(i, n); @items[i] += n; end
  def pbHasItem?(i); @items[i] > 0; end
  def pbDeleteItem(i); @items[i] -= 1; end
  def pbQuantity(i); @items[i]; end
end
$PokemonBag = BagStub.new
$PokemonGlobal = PokemonGlobalMetadata.new
$PokemonGlobal.repel = 0
$PokemonGlobal.daycareEgg = 0
$Trainer = Player.new

load File.join(KIF_ROOT, "Mods/KantoReloaded/Bootstrap.rb")
R = Reloaded
QOL = R::QualityOfLife
S = R::Settings
check("Kanto Reloaded boots with Quality of Life (#{R::Bootstrap.status}, #{R::Bootstrap.failures.inspect})", R::Bootstrap.status == :ready)
$toasts = []
QOL::Toast.singleton_class.prepend(Module.new { def show(*a); $toasts << a; true; end })
def toggle(id, v); S.set(QOL.key(id), v); end

#---------------------------------------------------------------- the settings
keys = S.keys(:quality_of_life)
check("a Quality of Life page: its On/Off row, 17 toggles and 3 tools (#{keys.length})", keys.length == 21 && keys.first == :"quality_of_life.enabled")
balance = QOL::TOGGLES.select { |t| t[2] == :balance }.map { |t| S.definition(QOL.key(t[0]))[:scope] }.uniq
comfort = QOL::TOGGLES.select { |t| t[2] == :comfort }.map { |t| S.definition(QOL.key(t[0]))[:scope] }.uniq
check("balance toggles are kept by each save, comfort ones for every save (#{balance.inspect}, #{comfort.inspect})",
      balance == [:save] && comfort == [:global])
check("all Off (or Normal) to start", QOL::TOGGLES.all? { |t| !QOL.on?(t[0]) || t[0] == :encounter_rate } && QOL.value(:encounter_rate) == 1)
check("the tools are buttons (#{%i[nature_selector level_locks super_candy].map { |k| S.definition(QOL.key(k))[:type] }.inspect})",
      %i[nature_selector level_locks super_candy].all? { |k| S.definition(QOL.key(k))[:type] == :button })
check("every hook was made (#{R::Hooks.registry.count { |e| e[:id].to_s.start_with?("qol_") }})",
      R::Hooks.registry.count { |e| e[:id].to_s.start_with?("qol_") } >= 28)

# a save loads
R::SaveStore.__send__(:from_save, nil)
R::Events.emit(:save_loaded, {})
check("with a save loaded the balance toggles can change", toggle(:infinite_repel, true) && QOL.on?(:infinite_repel))

#---------------------------------------------------------------- what a save has used
check("the save remembers a balance toggle turned On (#{QOL.used.keys.inspect})", QOL.used.has_key?("infinite_repel"))
toggle(:auto_hook, true)
check("...not a comfort one", !QOL.used.has_key?("auto_hook"))
$DEBUG = true
R::Events.emit(:saving)
$DEBUG = false
check("...and play with Debug on, when it saves", QOL.used.has_key?("debug"))
toggle(:infinite_repel, false)

#---------------------------------------------------------------- repels
check("Infinite Repel Off: no Repel, none active", !isRepelActive)
toggle(:infinite_repel, true)
check("Infinite Repel On: always active", isRepelActive)
$game_switches[SWITCH_USED_AN_INCENSE] = true
check("...but an incense works as the game has it", !isRepelActive)
$game_switches[SWITCH_USED_AN_INCENSE] = false
toggle(:infinite_repel, false)
$PokemonBag.add(:SUPERREPEL, 3)
pbRepel(:SUPERREPEL, 200)
$PokemonGlobal.repel = 1
$PokemonGlobal.repel -= 1
check("Auto-Repel Reuse Off: the Repel wears off", $PokemonGlobal.repel == 0)
toggle(:auto_repel, true)
$PokemonGlobal.repel = 1
$PokemonGlobal.repel -= 1
check("Auto-Repel Reuse On: another of the same kind is used (#{$PokemonGlobal.repel} steps, #{$PokemonBag.pbQuantity(:SUPERREPEL)} left)",
      $PokemonGlobal.repel == 200 && $PokemonBag.pbQuantity(:SUPERREPEL) == 2)
check("...with the toast (#{$toasts.last.inspect})", $toasts.last == [:SUPERREPEL, "Used Another Super Repel", "2 LEFT"])
2.times { $PokemonGlobal.repel = 1; $PokemonGlobal.repel -= 1 }
$PokemonGlobal.repel = 1
$PokemonGlobal.repel -= 1
check("...none of that kind left: it wears off and the game asks as usual", $PokemonGlobal.repel == 0 && $PokemonBag.pbQuantity(:SUPERREPEL) == 0)
$PokemonGlobal.tempRepel = true
$PokemonBag.add(:SUPERREPEL, 1)
$PokemonGlobal.repel = 1
$PokemonGlobal.repel = 0
check("...the Poké Radar's own short Repel is left alone", $PokemonGlobal.repel == 0)
$PokemonGlobal.tempRepel = false

#---------------------------------------------------------------- money
$Trainer.money = 3000
toggle(:infinite_money, true)
check("Infinite Money On: the most there can be (#{$Trainer.money})", $Trainer.money == 999_999)
$Trainer.money -= 500
check("...spending changes nothing (real #{$Trainer.instance_variable_get(:@money)})", $Trainer.instance_variable_get(:@money) == 3000)
$Trainer.money += 250
check("...money gained goes into the real money (#{$Trainer.instance_variable_get(:@money)})", $Trainer.instance_variable_get(:@money) == 3250)
mart = PokemonMartAdapter.new
check("...shops: anything, in any amount (#{mart.getMoney})", mart.getMoney >= 999_999_999)
mart.setMoney(mart.getMoney - 50_000)
check("...buying costs nothing", $Trainer.instance_variable_get(:@money) == 3250)
mart.setMoney(mart.getMoney + 400)
check("...selling adds (#{$Trainer.instance_variable_get(:@money)})", $Trainer.instance_variable_get(:@money) == 3650)
PokeBattle_Battle.new.pbGainMoney
check("...a prize still says what it gave ($#{$shown}) and adds it (#{$Trainer.instance_variable_get(:@money)})",
      $shown == 1000 && $Trainer.instance_variable_get(:@money) == 4650)
toggle(:infinite_money, false)
check("Infinite Money Off: the real money is back (#{$Trainer.money})", $Trainer.money == 4650)

#---------------------------------------------------------------- rematch money
$game_switches[SWITCH_IS_REMATCH] = true
PokeBattle_Battle.new.pbGainMoney
check("Rematch Money Off: a rematch pays nothing", $shown.nil?)
toggle(:rematch_money, true)
PokeBattle_Battle.new.pbGainMoney
check("Rematch Money On: it pays ($#{$shown}), and the rematch switch is put back", $shown == 1000 && $game_switches[SWITCH_IS_REMATCH] == true)
$game_switches[SWITCH_IS_REMATCH] = false
rematchable_trainer_battle
check("...a rematchable (Hoenn-style) battle pays too ($#{$shown})", $shown == 1000)
b = PokeBattle_Battle.new
b.moneyGain = false
b.pbGainMoney
check("...but a battle that pays nothing for another reason still doesn't", $shown.nil?)
toggle(:rematch_money, false)

#---------------------------------------------------------------- Safari
safari = SafariState.new
safari.steps -= 1
check("Infinite Safari Off: steps count down", safari.steps == 599)
toggle(:infinite_safari, true)
safari.steps -= 1
check("Infinite Safari On: they don't", safari.steps == 599)
safari.stop
safari.steps = 0
check("...and the game still ends as it would", safari.steps == 0)
toggle(:infinite_safari, false)

#---------------------------------------------------------------- PP
battle = PokeBattle_Battle.new
mine = Pokemon.new("Pikachu", 20, $Trainer)
mine.learn_move(:TACKLE)
foe = Pokemon.new("Rattata", 5)
foe.learn_move(:TACKLE)
mb = PokeBattle_Battler.new(battle, 0, mine)
fb = PokeBattle_Battler.new(battle, 1, foe)
toggle(:infinite_pp, true)
mb.pbReducePP(mine.moves[0])
fb.pbReducePP(foe.moves[0])
check("Infinite PP On: the player's moves spend no PP, the foe's do (#{mine.moves[0].pp}, #{foe.moves[0].pp})",
      mine.moves[0].pp == 35 && foe.moves[0].pp == 34)
$Trainer.party = [mine]
mine.moves[0].pp = 3
Events.onStartBattle.trigger
check("...and the party's PP is full when a battle starts (#{mine.moves[0].pp})", mine.moves[0].pp == 35)
toggle(:infinite_pp, false)
toggle(:upgraded_pp, true)
check("Upgraded PP On: as if it had 3 PP Ups (#{mine.moves[0].total_pp})", mine.moves[0].total_pp == 56)
mine.moves[0].pp = 56
toggle(:upgraded_pp, false)
check("Upgraded PP Off: back to its real most, and its PP within it (#{mine.moves[0].total_pp}, #{mine.moves[0].pp})",
      mine.moves[0].total_pp == 35 && mine.moves[0].pp == 35)

#---------------------------------------------------------------- obeying, catching, friendship
toggle(:always_obey, true)
check("Always Obey On: the player's Pokémon obey, the foe's are as they were", mb.pbObedienceCheck?(nil) == true && fb.pbObedienceCheck?(nil) == false)
mine.force_disobey = true
check("...not one the story makes disobey", mb.pbObedienceCheck?(nil) == false)
mine.force_disobey = false
toggle(:always_obey, false)
check("Always Obey Off: as the game has it", mb.pbObedienceCheck?(nil) == false)
toggle(:guaranteed_catch, true)
check("Guaranteed Catch On: caught (#{battle.pbCaptureCalc})", battle.pbCaptureCalc == 4)
toggle(:guaranteed_catch, false)
check("Guaranteed Catch Off: as the game has it", battle.pbCaptureCalc == 1)
toggle(:max_friendship, true)
check("Max Friendship On: the player's Pokémon are fully friendly, others as they are (#{mine.happiness}, #{foe.happiness})",
      mine.happiness == 255 && foe.happiness == 70)
toggle(:max_friendship, false)
check("Max Friendship Off: as it was", mine.happiness == 70)

#---------------------------------------------------------------- encounters
enc = PokemonEncounters.new
enc.encounter_triggered?(:Land)
normal = $chance
S.set(QOL.key(:encounter_rate), 0)
enc.encounter_triggered?(:Land)
fewer = $chance
S.set(QOL.key(:encounter_rate), 2)
enc.encounter_triggered?(:Land)
more = $chance
enc.encounter_triggered?(:Land, false, false)
not_step = $chance
S.set(QOL.key(:encounter_rate), 1)
check("Encounter Rate: Fewer halves a step's chance, More doubles it (#{normal}, #{fewer}, #{more})", normal == 20 && fewer == 10 && more == 40)
check("...only for steps (Rock Smash is as it was), and the map's own chance is put back (#{not_step})",
      not_step == 20 && enc.instance_variable_get(:@step_chances)[:Land] == 20)

#---------------------------------------------------------------- Eggs and the Day Care
egg = Pokemon.new("Egg", 1)
egg.steps_to_hatch = 5000
$Trainer.party = [mine, egg]
Events.onStepTaken.trigger
check("Instant Hatch Off: an Egg's steps are as they were", egg.steps_to_hatch == 5000)
toggle(:instant_hatch, true)
Events.onStepTaken.trigger
check("Instant Hatch On: one step left (#{egg.steps_to_hatch})", egg.steps_to_hatch == 1)
toggle(:instant_hatch, false)
$deposited = 2
$compat = 2
Events.onStepTaken.trigger
check("Day Care Eggs Off: no Egg yet", $PokemonGlobal.daycareEgg == 0)
toggle(:daycare_eggs, true)
$compat = 0
Events.onStepTaken.trigger
check("Day Care Eggs On: none from two that won't breed", $PokemonGlobal.daycareEgg == 0)
$compat = 2
Events.onStepTaken.trigger
check("...an Egg once two get along", $PokemonGlobal.daycareEgg == 1)
toggle(:daycare_eggs, false)

#---------------------------------------------------------------- fishing
pbFishing(true, 1)
check("Auto-Hook Fishing On: PIF's own auto-hook while fishing, put back after", $hooked == true && $game_switches[SWITCH_FISHING_AUTOHOOK] == false)
toggle(:auto_hook, false)
pbFishing(true, 1)
check("Auto-Hook Fishing Off: as the game has it", $hooked == false)

#---------------------------------------------------------------- Level-Up Moves
learner = Pokemon.new("Eevee", 20, $Trainer)
learner.learn_move(:TACKLE)
$Trainer.party = [learner]
lb = PokeBattle_Battle.new
S.set(QOL.key(:move_learning), 2)
lb.pbLearnMove(0, :BITE)
check("Skip, in battle: not learned, and it says so (#{$msgs.last})", !learner.hasMove?(:BITE) && $msgs.last.include?("skipped learning"))
S.set(QOL.key(:move_learning), 1)
$confirm = false
lb.pbLearnMove(0, :BITE)
check("Ask, in battle: No leaves it unlearned", !learner.hasMove?(:BITE))
$confirm = true
lb.pbLearnMove(0, :BITE)
check("...Yes learns it", learner.hasMove?(:BITE))
S.set(QOL.key(:move_learning), 2)
pbLearnMove(learner, :GROWL)
check("a move taught outside a level-up (a TM, a tutor) is as the game has it", learner.hasMove?(:GROWL))
learner.movelist = [[21, :THUNDER]]
pbChangeLevel(learner, 21, nil)
check("Skip, on a level-up outside battle (a Rare Candy): not learned", !learner.hasMove?(:THUNDER))
S.set(QOL.key(:move_learning), 0)

#---------------------------------------------------------------- Faster Evolutions
$drawn = 0
PokemonEvolutionScene.new.pbEvolution
plain = $drawn
toggle(:faster_evolutions, true)
$drawn = 0
r = PokemonEvolutionScene.new.pbEvolution
fast = $drawn
toggle(:faster_evolutions, false)
check("Faster Evolutions: a third of the frames drawn (#{plain} > #{fast}), and the scene still finishes", plain == 9 && fast == 3 && r == :evolved)

#---------------------------------------------------------------- level locks
LL = QOL::LevelLocks
lp = Pokemon.new("Machop", 18, $Trainer)
LL.set(lp, 20)
lp.exp = 30 ** 3
check("Level Locking Off: a lock is kept but paused (Lv #{lp.level})", LL.get(lp) == 20 && lp.level == 30)
lp.level = 18
toggle(:level_locking, true)
lp.exp = 30 ** 3
check("Level Locking On: EXP stops at its locked level (Lv #{lp.level})", lp.level == 20)
lp.level = 25
check("...so does setting its level (Lv #{lp.level})", lp.level == 20)
lp.level = 18
$Trainer.party = [lp]
PokeBattle_Battle.new.pbGainExpOne(0)
check("...and battle EXP (Lv #{lp.level})", lp.level == 20)
check("...a Rare Candy is refused, not used up", can_use_rare_candy(lp) == false)
LL.clear(lp)
check("unlocked: a Rare Candy works again", can_use_rare_candy(lp) == true && LL.get(lp).nil?)

#---------------------------------------------------------------- Super Candy
SC = QOL::SuperCandy
a = Pokemon.new("Pikachu", 10, $Trainer)
a.learn_move(:TACKLE)
a.movelist = [[12, :THUNDERBOLT]]
b2 = Pokemon.new("Gyarados", 10, $Trainer)
LL.set(b2, 12)
c = Pokemon.new("Gengar", 30, $Trainer)
d = Pokemon.new("Eevee", 15, $Trainer)
LL.set(d, 15)
e2 = Pokemon.new("Egg", 1)
e2.steps_to_hatch = 300
$Trainer.party = [a, b2, c, d, e2]
check("where each would end up (#{[a, b2, c, d].map { |p| SC.reach(p, 15) }.inspect})",
      SC.reach(a, 15) == [15, :ok] && SC.reach(b2, 15) == [12, :locked_at] && SC.reach(c, 15) == [30, :already] && SC.reach(d, 15) == [15, :locked])
res = SC.raise_party(15)
check("raised: Pikachu to 15 learning Thunderbolt, Gyarados stopped by its lock, the rest left (#{res.map { |r| [r[:result], r[:to], r[:learned]] }.inspect})",
      a.level == 15 && a.hasMove?(:THUNDERBOLT) && b2.level == 12 && c.level == 30 && d.level == 15 && e2.egg? &&
      res[0][:learned] == ["Thunderbolt"] && res[1][:result] == :lock_stop && res[2][:result] == :already && res[3][:result] == :locked && res[4][:result] == :egg)
check("...then evolutions are checked as after a battle (#{$evo_check.inspect})", $evo_check == [10, 10, 30, 15, 1])
check("the level cap: the highest level when no cap is on (#{QOL.level_cap})", QOL.level_cap == 100)

#---------------------------------------------------------------- a bug report
lines = QOL.report_lines
check("a bug report says what's On and what this save has used (#{lines.inspect})",
      lines.length == 2 && lines[0].include?("Level Locking") && lines[1].include?("Infinite Repel (") && lines[1].include?("Debug ("))

#---------------------------------------------------------------- the feature Off
R::Features.set(:quality_of_life, :off)
toggle_ok = isRepelActive
check("Quality of Life switched Off: every toggle is as the game has it", R::Features.on?(:quality_of_life) != true && !QOL.on?(:infinite_repel))
R::Features.set(:quality_of_life, :on)

errors = File.read(R::Log.path).lines.select { |l| l.include?("ERROR") || (l.include?("skipped") && l.include?("qol_")) }
check("no errors, and no Quality of Life hook skipped (#{errors.length})", errors.empty?)
errors.first(6).each { |l| puts "  " + l }
puts $failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED"
exit($failed ? 1 : 0)
