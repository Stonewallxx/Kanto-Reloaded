# encoding: utf-8
# Checks the PokeVial outside the game, on stand-ins for the game's classes
# (named and shaped as PIF 6.8.2 and KIF Beta have them): its menu entries
# taking over KIF's Heal Pokémon, charges and Progressive Uses, the Heal
# Preview's words and each Heal Mode, the cooldown, where it's blocked, the
# Low HP Reminder, refilling at a Pokémon Center (Ask, Automatic, Never,
# the cost), the items, the API for other mods, and switching it Off.
# Usage: ruby Tools/Tests/pokevial_test.rb "<KIF Beta>" <empty temp folder>
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
class FakeEvent
  def initialize; @procs = []; end
  def +(p); @procs << p; self; end
  def trigger(*a); @procs.each { |p| p.call(nil, a) }; end
end
module Events
  @onStepTaken = FakeEvent.new
  class << self; attr_accessor :onStepTaken; end
end
eval(<<~RUBY, TOPLEVEL_BINDING, "014_Fake_Game.rb", 1)
  module GameData
    StatusData = Struct.new(:id, :name)
    class Status
      def self.get(id); StatusData.new(id, { :POISON => "Poison", :BURN => "Burn" }[id] || id.to_s); end
    end
  end
  class Pokemon
    class Move
      attr_accessor :pp
      attr_reader :total_pp
      def initialize(total, pp = total); @total_pp = total; @pp = pp; end
    end
    attr_accessor :name, :hp, :status, :moves, :steps_to_hatch
    attr_reader :totalhp
    def initialize(name, hp, total, status = :NONE, moves = [Move.new(10)]); @name = name; @hp = hp; @totalhp = total; @status = status; @moves = moves; @steps_to_hatch = 0; end
    def egg?; @steps_to_hatch > 0; end
    def fainted?; @hp <= 0; end
    def heal_HP; @hp = @totalhp unless egg? || (fainted? && $PokemonSystem.no_reviving); end
    def heal_status; @status = :NONE; end
    def heal_PP; @moves.each { |m| m.pp = m.total_pp }; end
    def heal; return if egg? || (fainted? && $PokemonSystem.no_reviving); heal_HP; heal_status; heal_PP; end
  end
  class Trainer
    attr_accessor :party
    def heal_party; @party.each(&:heal); end
  end
  class Player < Trainer
    attr_accessor :money, :badge_count
    def initialize; @money = 3000; @party = []; @badge_count = 2; end
  end
  class Interpreter
    attr_accessor :parameters
    def command_314; $Trainer.heal_party if @parameters[0] == 0; true; end
  end
  module ItemHandlers
    module UseFromBag
      @h = {}
      def self.add(id, pr); @h[id] = pr; end
      def self.trigger(id); @h[id] ? @h[id].call(id) : 0; end
      def self.registered?(id); @h.key?(id); end
    end
  end
  module KIF
    module PauseMenu
      Entry = Struct.new(:id, :label, :condition, :handler)
      @entries = []
      @restricted = false
      class << self
        attr_accessor :restricted
        def add(id, label, icon: nil, order: 100, condition: nil, handler: nil)
          @entries.reject! { |e| e.id == id }
          @entries << Entry.new(id, label, condition, handler)
        end
        def restricted?; @restricted; end
        def active_entries; @entries.select { |e| e.condition.nil? || e.condition.call }; end
      end
    end
  end
  class PokemonSystem; attr_accessor :kurayqol, :no_reviving, :no_healing_items_ow; end
  class PokemonGlobalMetadata; attr_accessor :pokecenterMapId; end
  class GameMap; attr_accessor :map_id; end
  class GameTemp; attr_accessor :in_battle; end
  class MapInterpreter; attr_accessor :running; def running?; @running; end; end
  class GameSystem; attr_accessor :map_interpreter; end
  def pbGetMapNameFromId(id); { 5 => "Cerulean City", 6 => "Pokémon Center", 9 => "Your House" }[id] || "Map"; end
  def pbInSafari?; $safari; end
  def pbInBugContest?; false; end
  def pbPlayBuzzerSE; end
RUBY
KIF::PauseMenu.add(:kif_heal, "Heal Pokémon", condition: proc { $PokemonSystem.kurayqol == 1 }, handler: proc { $Trainer.heal_party; :stay })
KIF::PauseMenu.add(:kif_pc, "PC", condition: proc { $PokemonSystem.kurayqol == 1 })
$PokemonSystem = PokemonSystem.new
$PokemonSystem.kurayqol = 1
$PokemonGlobal = PokemonGlobalMetadata.new
$PokemonGlobal.pokecenterMapId = 6
$game_map = GameMap.new
$game_map.map_id = 5
$game_temp = GameTemp.new
$game_system = GameSystem.new
$game_system.map_interpreter = MapInterpreter.new
$Trainer = Player.new
$safari = false

def make_party
  [Pokemon.new("Pikachu", 78, 95), Pokemon.new("Gyarados", 0, 120), Pokemon.new("Gengar", 40, 110, :POISON),
   Pokemon.new("Eevee", 60, 60, :NONE, [Pokemon::Move.new(10, 3)]), Pokemon.new("Egg", 10, 10).tap { |e| e.steps_to_hatch = 500 }]
end
def healthy_party; [Pokemon.new("Pikachu", 95, 95), Pokemon.new("Eevee", 60, 60)]; end
$Trainer.party = make_party

load File.join(KIF_ROOT, "Mods/KantoReloaded/Bootstrap.rb")
R = Reloaded
PV = R::PokeVial
S = R::Settings
check("Kanto Reloaded boots with the PokeVial (#{R::Bootstrap.status}, #{R::Bootstrap.failures.inspect})", R::Bootstrap.status == :ready)

# The screens (UI/PokeVialScreen.rb) need the game's drawing; here they say what they'd show
$asked = []
$answer = true
$toasts = []
module Reloaded
  module PokeVialScreen
    def self.ask_refill; $asked << [PokeVial.missing, PokeVial.refill_cost]; $answer; end
    def self.toast(text, full: false, red_pill: nil); $toasts << [:toast, text, full, red_pill]; true; end
    def self.charges_toast(text); $toasts << [:charges, text, PokeVial.uses]; true; end
    def self.capacity_toast(max, gained); $toasts << [:capacity, max, gained]; true; end
    def self.cooldown_toast; $toasts << [:cooldown]; true; end
  end
end
R::SaveStore.__send__(:from_save, nil)
R::Events.emit(:save_loaded, {})
def set(id, v); S.set(PV.key(id), v); end
def pm_ids; KIF::PauseMenu.active_entries.map { |e| e.id }; end
def recover_all(map)
  $game_map.map_id = map
  i = Interpreter.new
  i.parameters = [0]
  i.command_314
end

#---------------------------------------------------------------- settings, the feature, its entries
keys = S.keys(:pokevial)
check("a PokeVial page: its On/Off row and 10 settings (#{keys.length})", keys.length == 11 && keys.first == :"pokevial.enabled")
saves = [:progressive, :max_uses, :heal_mode, :cooldown, :cooldown_time, :center_refill, :refill_cost, :cost_per_charge]
check("balance settings are kept by each save; Low HP Reminder and Cooldown Wait are for every save",
      saves.all? { |k| S.definition(PV.key(k))[:scope] == :save } && [:low_hp, :cooldown_wait].all? { |k| S.definition(PV.key(k))[:scope] == :global })
check("defaults: Progressive Uses On, Max Uses 3, Full Heal, no cooldown, Ask, free, Low HP Reminder On",
      S.get(PV.key(:progressive)) == true && S.get(PV.key(:max_uses)) == 3 && S.get(PV.key(:heal_mode)) == 0 &&
      S.get(PV.key(:cooldown)) == false && S.get(PV.key(:center_refill)) == 0 && S.get(PV.key(:refill_cost)) == false &&
      S.get(PV.key(:low_hp)) == true)
check("the feature is On to start", R::Features.on?(:pokevial))
check("the Pause Menu: PokeVial in KIF's list in place of Heal Pokémon (#{pm_ids.inspect})", pm_ids.include?(:pokevial) && !pm_ids.include?(:kif_heal))
check("...in the Pinned row's third slot (#{R::PauseMenu.pinned_keys.inspect})", R::PauseMenu.pinned_keys[2] == "pokevial")
check("...its status: the charges, short for the tile (#{R::PauseMenu.status(:pokevial).inspect})",
      R::PauseMenu.status(:pokevial) == ["Charges: 2/2", "2/2", nil])
om = R::OverworldMenu.entry(:pokevial)
check("the Overworld Menu: a Main action with its charges drawn, usable, with an alert",
      om && om.kind == :action && om.paint && om.alert && R::OverworldMenu.usable(om) == true && R::OverworldMenu.shown?(om))
patches = R::DataPatches.instance_variable_get(:@internal).select { |p| p[:target] == "items" }
check("the Charge and Refill items: Kanto Reloaded's own items, used from the Bag, not sold yet (#{patches.map { |p| p[:id] }.inspect})",
      patches.map { |p| p[:id].to_s }.sort == ["POKEVIAL_CHARGE", "POKEVIAL_REFILL"] && patches.all? { |p| p[:data]["field_use"] == 2 } &&
      ItemHandlers::UseFromBag.registered?(:POKEVIAL_CHARGE) && ItemHandlers::UseFromBag.registered?(:POKEVIAL_REFILL))
$PokemonSystem.kurayqol = 0
check("Kuray QoL Off: no PokeVial at all, as KIF's Heal (#{pm_ids.inspect}, #{R::PauseMenu.pinned_keys.inspect})",
      !pm_ids.include?(:pokevial) && R::PauseMenu.pinned_keys[2].nil? && !R::OverworldMenu.shown?(om))
$PokemonSystem.kurayqol = 1

#---------------------------------------------------------------- charges and Progressive Uses
check("Progressive Uses: one more charge for every two Badges (2 Badges: #{PV.configured_max_uses})", PV.configured_max_uses == 2)
check("a save that never used it starts full (#{PV.uses})", PV.uses == 2)
$Trainer.badge_count = 4
check("a Badge's worth more: room for 3 (#{PV.configured_max_uses})", PV.configured_max_uses == 3)
Events.onStepTaken.trigger
check("...on the next step the new charge arrives full, with a toast (#{PV.uses}, #{$toasts.last.inspect})",
      PV.uses == 3 && $toasts.last == [:capacity, 3, 1])
$toasts.clear
Events.onStepTaken.trigger
check("...once", $toasts.empty? && PV.uses == 3)
$Trainer.badge_count = 16
check("never more than 5 (#{PV.configured_max_uses})", PV.configured_max_uses == 5)
$Trainer.badge_count = 4
PV.sync_capacity
set(:progressive, false)
check("Progressive Uses Off: Max Uses decides (#{PV.configured_max_uses})", PV.configured_max_uses == 3)
set(:max_uses, 4)
check("...Max Uses 4 (#{PV.configured_max_uses})", PV.configured_max_uses == 4)
set(:progressive, true)
check("Max Uses is locked while Progressive Uses decides (#{S.lock_reason(PV.key(:max_uses)).inspect})",
      S.lock_reason(PV.key(:max_uses)).to_s.include?("Progressive Uses"))
set(:max_uses, 3)
PV.set_uses(3)
PV.data["max_seen"] = 3

#---------------------------------------------------------------- the Heal Preview and Heal Modes
pk = $Trainer.party
words = pk.first(4).map { |p| PV.preview(p) }
check("Full Heal: +HP, Revived, HP and the status cured, PP (#{words.inspect})",
      words == [["+17 HP", :green], ["Revived", :pink], ["+70 HP, Cures Poison", :green], ["PP Restored", :blue]])
set(:heal_mode, 1)
words = pk.first(4).map { |p| PV.preview(p) }
check("HP Only: HP and revives, status and PP stay (#{words.inspect})",
      words == [["+17 HP", :green], ["Revived", :pink], ["+70 HP", :green], ["Healthy", :healthy]])
set(:heal_mode, 2)
check("No Revive: a fainted Pokémon stays fainted (#{PV.preview(pk[1]).inspect})", PV.preview(pk[1]) == ["Stays Fainted", :dim])
set(:heal_mode, 0)
$PokemonSystem.no_reviving = true
check("PIF's No reviving (KIF's Nuzlocke turns it on): Stays Fainted, as the game's own heal leaves it (#{PV.preview(pk[1]).inspect})",
      PV.preview(pk[1]) == ["Stays Fainted", :dim])
$Trainer.party = [Pokemon.new("Pikachu", 95, 95), Pokemon.new("Gyarados", 0, 120)]
check("...so a party whose only hurt one can't be revived: All Healthy, no charge used, no glow (#{PV.use_state.inspect})",
      PV.use_state == ["All Healthy", :healthy] && !PV.low_hp_alert?)
$Trainer.party[1].instance_variable_set(:@kif_nz_dead, true)
class Pokemon; attr_accessor :kif_nz_dead; end
module KIF; module Nuzlocke; def self.on?; true; end; end; end
check("a Pokémon dead in KIF's Nuzlocke: Dead (#{PV.preview($Trainer.party[1]).inspect})", PV.preview($Trainer.party[1]) == ["Dead", :dim])
KIF.send(:remove_const, :Nuzlocke)
$PokemonSystem.no_reviving = false
$Trainer.party = make_party
pk = $Trainer.party

#---------------------------------------------------------------- using it
$events = []
PV.on(:before_use, :test) { |ctx| $events << [:before, ctx[:uses_before]]; true }
PV.on(:after_use, :test) { |ctx| $events << [:after, ctx[:uses_after]]; true }
check("ready to use (#{PV.use_state.inspect})", PV.use_state == true)
check("Use heals the party as Full Heal does and uses a charge",
      PV.use!(:menu) && PV.uses == 2 && pk.first(4).all? { |p| p.hp == p.totalhp && p.status == :NONE } && pk[3].moves[0].pp == 10)
check("...the Egg is left alone", pk[4].hp == 10)
check("...the before and after events ran (#{$events.inspect})", $events == [[:before, 3], [:after, 2]])
check("everyone healthy: Use is dimmed, All Healthy, and no charge is used (#{PV.use_state.inspect})",
      PV.use_state == ["All Healthy", :healthy] && !PV.use!(:menu) && PV.uses == 2)
$Trainer.party = make_party
pk = $Trainer.party
PV.on(:before_use, :test) { |ctx| ctx[:message] = "Not now"; false }
check("a mod's before_use saying no stops it: nothing healed, no charge used", !PV.use!(:menu) && PV.uses == 2 && pk[0].hp == 78)
PV.unregister_callback(:before_use, :test)
PV.unregister_callback(:after_use, :test)
set(:heal_mode, 2)
PV.use!(:menu)
check("No Revive: everyone else healed, the fainted one still fainted", pk[1].hp == 0 && pk[0].hp == 95 && pk[2].status == :NONE)
set(:heal_mode, 0)
PV.set_uses(0)
$Trainer.party = make_party
check("no charges left: Use is dimmed and says so (#{PV.use_state.inspect})", PV.use_state == ["No Charges Left", :empty] && !PV.use!(:menu))
PV.set_uses(3)

#---------------------------------------------------------------- the cooldown
set(:cooldown, true)
set(:cooldown_time, 0)
PV.use!(:menu)
$Trainer.party = make_party
left = PV.cooldown_left
check("Cooldown 5 min: it waits after a use (#{left} s, #{PV.use_state.inspect})",
      left.between?(298, 300) && PV.use_state[1] == :cooldown && PV.use_state[0].start_with?("Ready in 5:00", "Ready in 4:5"))
PV.data["last_use"] = Time.now.to_f - 301
check("...ready again after it (#{PV.cooldown_left})", PV.cooldown_left == 0 && PV.use_state == true)
PV.data["last_use"] = Time.now.to_f + 3600
check("...a clock set back doesn't make it wait longer (#{PV.cooldown_left})", PV.cooldown_left == 0)
PV.data["last_use"] = Time.now.to_f - 150
check("...how far the wait has gone (#{PV.cooldown_done.round(2)})", PV.cooldown_done.between?(0.49, 0.51))
check("...the time it'll be ready, as the clock shows it (#{PV.ready_at})", PV.ready_at =~ /\A\d{1,2}:\d\d [AP]M\z/)
set(:cooldown, false)
PV.data["last_use"] = nil

#---------------------------------------------------------------- where it can't be used
KIF::PauseMenu.restricted = true
check("on a map KIF blocks: locked in the menus, saying why (#{PV.usable.inspect})",
      PV.usable == "The PokeVial can't be used here." && !pm_ids.include?(:pokevial) && R::PauseMenu.pinned_keys[2] == "pokevial" &&
      R::OverworldMenu.usable(om) == "The PokeVial can't be used here.")
KIF::PauseMenu.restricted = false
$game_temp.in_battle = true
check("in battle: blocked", PV.blocked?)
$game_temp.in_battle = false
$safari = true
check("in the Safari Zone: blocked", PV.blocked?)
$safari = false
$PokemonSystem.no_healing_items_ow = true
check("PIF's No heals (overworld) challenge: locked, saying why (#{PV.usable.inspect})",
      PV.usable == "The No Heals (Overworld) challenge is On." && !pm_ids.include?(:pokevial))
$PokemonSystem.no_healing_items_ow = false
check("anywhere else: usable", PV.usable == true)

#---------------------------------------------------------------- the Low HP Reminder
$Trainer.party = make_party
check("a fainted Pokémon: the PokeVial glows in both menus", PV.low_hp_alert? && R::PauseMenu.alert?(:pokevial) && R::OverworldMenu.alert?(om))
$Trainer.party = [Pokemon.new("Pikachu", 40, 95), Pokemon.new("Eevee", 20, 60)]
check("the party's HP under half: it glows", PV.low_hp_alert?)
$Trainer.party = [Pokemon.new("Pikachu", 60, 95), Pokemon.new("Eevee", 30, 60)]
check("half or more and nobody fainted: no glow", !PV.low_hp_alert?)
$Trainer.party = make_party
PV.set_uses(0)
check("no charge left: no glow (there's nothing to do)", !PV.low_hp_alert?)
PV.set_uses(3)
set(:low_hp, false)
check("Low HP Reminder Off: no glow", !PV.low_hp_alert? && !R::PauseMenu.alert?(:pokevial))
set(:low_hp, true)

#---------------------------------------------------------------- refills at a Pokémon Center
PV.set_uses(1)
$asked.clear
$answer = true
recover_all(6)
check("the nurse's Recover All at a Pokémon Center asks to refill (#{$asked.inspect}), Refill: full (#{PV.uses}/3)",
      $asked == [[2, 0]] && PV.uses == 3)
PV.set_uses(1)
$answer = false
recover_all(6)
check("...Not Now: left as it was", PV.uses == 1)
$answer = true
$asked.clear
recover_all(9)
check("Recover All anywhere else (your house): no refill", $asked.empty? && PV.uses == 1)
$game_map.map_id = 6
$game_system.map_interpreter.running = true
$Trainer.heal_party
check("a nurse that heals by script during her event: refill too", PV.uses == 3)
PV.set_uses(1)
$game_system.map_interpreter.running = false
$Trainer.heal_party
check("...but not a heal outside an event", PV.uses == 1)
set(:refill_cost, true)
set(:cost_per_charge, 500)
$Trainer.money = 3000
recover_all(6)
check("Refill Cost: ₽500 for each of the 2 missing charges (#{$asked.last.inspect}, ₽#{$Trainer.money})",
      $asked.last == [2, 1000] && $Trainer.money == 2000 && PV.uses == 3)
set(:center_refill, 1)
PV.set_uses(1)
$asked.clear
$toasts.clear
recover_all(6)
check("Automatic: no question, refilled and paid, with a toast (#{$toasts.inspect})",
      $asked.empty? && PV.uses == 3 && $Trainer.money == 1000 && $toasts.last[0] == :charges)
PV.set_uses(0)
$Trainer.money = 200
$toasts.clear
recover_all(6)
check("...not enough money: not refilled, a toast says so (#{$toasts.inspect})", PV.uses == 0 && $Trainer.money == 200 && $toasts.last[3])
set(:center_refill, 2)
recover_all(6)
check("Never: Pokémon Centers leave it alone", PV.uses == 0)
set(:center_refill, 0)
set(:refill_cost, false)
$Trainer.money = 3000

#---------------------------------------------------------------- the items, from the Bag
PV.set_uses(1)
$toasts.clear
r = ItemHandlers::UseFromBag.trigger(:POKEVIAL_CHARGE)
check("a PokeVial Charge: one charge back, used up, a toast with the charges (#{r}, #{$toasts.inspect})",
      r == 3 && PV.uses == 2 && $toasts.last == [:charges, "The PokeVial regained a charge.", 2])
r = ItemHandlers::UseFromBag.trigger(:POKEVIAL_REFILL)
check("a PokeVial Refill: every charge back (#{r}, #{PV.uses})", r == 3 && PV.uses == 3)
r = ItemHandlers::UseFromBag.trigger(:POKEVIAL_CHARGE)
check("already full: the item isn't used, a FULL toast (#{r}, #{$toasts.last.inspect})", r == 0 && $toasts.last[2] == true)

#---------------------------------------------------------------- the API for other mods
PV.set_uses(0)
check("add_uses: given charges, never past the top (#{PV.add_uses(5, source: :test, notify: false)}, #{PV.uses})", PV.uses == 3)
PV.set_uses(0)
check("grant_full_refill (#{PV.grant_full_refill(source: :test, notify: false)}, #{PV.uses})", PV.uses == 3)
check("increase_max_uses: more room, the new charges full (#{PV.increase_max_uses(1, source: :test, notify: false)}, #{PV.uses}/#{PV.configured_max_uses})",
      PV.configured_max_uses == 4 && PV.uses == 4)
PV.set_uses(0)
PV.register_refill_source(:inn) { |_vial| true }
PV.register_refill_source(:closed) { |_vial| false }
check("a refill source refills; one that says no doesn't", !PV.refill_from_source(:closed, notify: false) && PV.uses == 0 &&
      PV.refill_from_source(:inn, notify: false) && PV.uses == 4)
PV.set_uses(0)
PV.on(:before_refill, :test) { |_ctx| false }
check("a before_refill handler saying no stops a refill", !PV.grant_full_refill(source: :test, notify: false) && PV.uses == 0)
PV.unregister_callback(:before_refill, :test)
PV.set_uses(3)

#---------------------------------------------------------------- Off
R::Features.set(:pokevial, :off)
check("Off: KIF's Heal Pokémon is back, the PokeVial gone from both menus (#{pm_ids.inspect})",
      pm_ids.include?(:kif_heal) && !pm_ids.include?(:pokevial) && R::PauseMenu.pinned_keys[2].nil? && !R::OverworldMenu.shown?(om))
check("...its items say it's off and aren't used", ItemHandlers::UseFromBag.trigger(:POKEVIAL_CHARGE) == 0)
PV.set_uses(1)
recover_all(6)
check("...and Pokémon Centers don't touch it", PV.uses == 1)
R::Features.set(:pokevial, :on)

# (other features' hooks skip here: these stand-ins only have what the PokeVial needs)
lines = File.read(R::Log.path).lines
errors = lines.grep(/ERROR/) + lines.grep(/skipped/).grep(/pokevial|toast/)
check("no errors, and none of the PokeVial's hooks skipped, in Kanto Reloaded's log (#{errors.length})", errors.empty?)
errors.first(6).each { |l| puts "  " + l }
puts $failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED"
exit($failed ? 1 : 0)
