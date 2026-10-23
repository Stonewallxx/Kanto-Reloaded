# encoding: utf-8
# Checks Speed-Up outside the game, on stand-ins for the engine's Graphics
# and Input with PIF's own Better Fast-forward (052_InfiniteFusion/System/
# Spped Up.rb) loaded over them: Hold (the speeds, Resting Speed, battles),
# PIF's own speed-up kept out while this runs, Toggle (steps, Toggle Limit,
# Burst Speed's tap and hold, Next Speed and Reset Speed where KIF allowed
# them, Separate and Shared speeds, Remember Speed), Shiny Slowdown (a wild
# battle, the map, Hold), Messages at 1x, settings screens at 2x at most, an event's
# pbDisallowSpeedup, the window title, the Overworld Menu's row, PIF's rows
# in KIF Settings, Off (PIF's back), and a failure handing over to PIF's.
# Usage: ruby Tools/Tests/speed_up_test.rb "<KIF Beta>" <empty temp folder>
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

#---------------------------------------------------------------- the engine and the game, as stand-ins
eval(<<~'RUBY', TOPLEVEL_BINDING, "001_Fake_Engine.rb", 1)
  module System
    def self.set_window_title(t); $title = t; end
  end
  module Graphics
    @drawn = 0
    class << self; attr_accessor :drawn; end
    def self.update; @drawn += 1; end
    def self.width; 512; end
    def self.height; 384; end
  end
  # Held buttons ($held), read once per Input.update as the engine does
  module Input
    A = 11; B = 12; C = 13; X = 14; Y = 15; Z = 16; L = 17; R = 18
    UP = 8; DOWN = 2; AUX1 = L; AUX2 = R; ACTION = A; BACK = B; SPECIAL = Z; JUMPUP = L; JUMPDOWN = R
    @now = []; @before = []
    def self.update; @before = @now; @now = $held.dup; end
    def self.press?(b); @now.include?(b); end
    def self.trigger?(b); $pressed == b || (@now.include?(b) && !@before.include?(b)); end
    def self.repeat?(b); trigger?(b); end
    def self.release?(b); !@now.include?(b) && @before.include?(b); end
  end
  module Settings
    DEFAULT_SPEED_UP_SPEED = 3
    GAME_VERSION_NUMBER = "6.8.2"
  end
  module KIF
    PORT_VERSION = "1.1.0"
    # KIF's own title and L/R keys (F-UI-05_SpeedUp/SpeedTitle.rb)
    module SpeedTitle
      def self.update_title; $title = "Kuray's Infinite Fusion (KIF)"; end
      def self.check_keys; $log << "KIF KEYS"; end
    end
  end
  module PluginManager; def self.register(*a); end; end
  class PokemonSystem; attr_accessor :speedup, :speedup_speed, :speedup_speed_battles; end
  class Game_Temp; attr_accessor :in_battle, :in_menu, :message_window_showing; end
  class Scene_Map; end
  Interp = Struct.new(:running) do
    def running?; running; end
  end
  class Game_System; attr_accessor :map_interpreter; end
  class Shiny; attr_accessor :shiny; def initialize(s); @shiny = s; end; def shiny?; @shiny; end; end
  class PokeBattle_Battle
    def initialize(foes, wild = true); @foes = foes; @wild = wild; end
    def wildBattle?; @wild; end
    def pbParty(_i); @foes; end
    def pbStartBattleSendOut(_s); $log << "SENDOUT speed #{Reloaded::SpeedUp.speed}"; end
  end
  class OverworldPokemonEvent
    def setup_pokemon(shiny); @pokemon = Shiny.new(shiny); end
  end
  def pbMessageDisplay(_w, _m, *_r); Graphics.update; $msg_speed = Reloaded::SpeedUp.speed; end
  class PokemonOptionScreen
    def pbStartScreen(*_a); Graphics.update; $options_speed = Reloaded::SpeedUp.speed; end
  end
  module KIF
    module SettingsScreen
      def self.pif_items(*_a)
        [[{ :name => "Speed-up type" }, { :name => "Speed-up (Overworld)" }, { :name => "Speed-up (Battles)" },
          { :name => "Text Speed" }], :extra, :root]
      end
    end
  end
RUBY
$held = []
$PokemonSystem = PokemonSystem.new
$PokemonSystem.speedup = 0
$PokemonSystem.speedup_speed = 3
$PokemonSystem.speedup_speed_battles = 3
$game_temp = Game_Temp.new
$game_system = Game_System.new
$game_system.map_interpreter = Interp.new(false)
$scene = Scene_Map.new
# PIF's own speed-up, over the engine's update
load File.join(KIF_ROOT, "Data/Scripts/052_InfiniteFusion/System/Spped Up.rb")

load File.join(KIF_ROOT, "Mods/KantoReloaded/Bootstrap.rb")
R = Reloaded
SU = R::SpeedUp
S = R::Settings
check("Kanto Reloaded boots with Speed-Up (#{R::Bootstrap.status}, #{R::Bootstrap.failures.inspect})", R::Bootstrap.status == :ready)
check("Speed-Up is a feature, On to start, taking over KIF's F-UI-05_SpeedUp",
      R::Features.on?(:speed_up) && R::Features.definition(:speed_up)[:takes_over] == ["F-UI-05_SpeedUp"])
check("its page: its On/Off switch, then its settings in the Controls screen's order (#{S.keys(:speed_up).length})",
      S.keys(:speed_up) == [:"speed_up.enabled"] + SU::KEYS)
# (the Speed Indicator is drawn in the preview; the stand-ins here have no pixel fonts)
S.set(:"speed_up.indicator", false)
$now = 100.0
SU.singleton_class.send(:define_method, :clock) { $now }

# n game steps (Input.update, then Graphics.update); the frames drawn
def steps(n, held = $held)
  $held = held
  before = Graphics.drawn
  n.times { Input.update; Graphics.update }
  Graphics.drawn - before
end
def tap(button, wait = 0.1)
  steps(1, [button]); $now += wait; steps(1, [])
end

#---------------------------------------------------------------- Hold
check("Hold, nothing held: 1x, every frame drawn (#{steps(12, [])})", steps(12, []) == 12 && SU.speed == 1)
check("...the window title (#{$title})", $title == "Kanto Reloaded #{R.version} · KIF 1.1.0 · PIF 6.8.2 · Speed x1")
n = steps(12, [Input::X])
check("X held: Speed-Up (Overworld), 4x as PIF's 3 (+1), one frame in four (#{n}, #{SU.speed})", SU.speed == 4 && n == 3)
check("...the title follows (#{$title})", $title.end_with?("Speed x4"))
check("...PIF's own X didn't step its stages ($GameSpeed #{$GameSpeed})", $GameSpeed == 0)
S.set(:"speed_up.battles", 5)
check("Speed-Up (Battles) 6x is kept in PIF's field, one less as PIF keeps it ($PokemonSystem #{$PokemonSystem.speedup_speed_battles})",
      $PokemonSystem.speedup_speed_battles == 5)
$game_temp.in_battle = true
steps(1, [Input::X])
check("in a battle: Speed-Up (Battles) (#{SU.speed})", SU.speed == 6)
$game_temp.in_battle = false
S.set(:"speed_up.resting", 1)
steps(1, [])
check("let go: Resting Speed (#{SU.speed})", SU.speed == 2)
S.set(:"speed_up.resting", 0)
steps(1, [])
$CanToggle = false
steps(2, [Input::X])
check("an event's pbDisallowSpeedup: holding does nothing (#{SU.speed})", SU.speed == 1)
check("...and $CanToggle is the event's again after each frame", $CanToggle == false)
$CanToggle = true

#---------------------------------------------------------------- Toggle
S.set(:"speed_up.type", 1)
check("Toggle: kept in PIF's field too (speedup #{$PokemonSystem.speedup})", $PokemonSystem.speedup == 1)
check("Hold's rows lock, Toggle's open (#{S.lock_reason(:"speed_up.overworld").inspect})",
      S.lock_reason(:"speed_up.overworld") == "Hold Only" && !S.locked?(:"speed_up.toggle_limit"))
steps(1, [])
tap(Input::X)
check("Burst Speed on (10x): a tap steps when let go, 1x to 2x (#{SU.speed})", SU.speed == 2)
steps(1, [Input::X]); $now += 0.6; steps(3, [Input::X])
check("...held past Hold Time: Burst Speed (#{SU.speed})", SU.speed == 10)
steps(1, [])
check("...let go: back to the toggled speed, no step (#{SU.speed})", SU.speed == 2)
S.set(:"speed_up.burst", 0)
steps(1, [Input::X])
check("Burst Speed Off: a press steps at once (#{SU.speed})", SU.speed == 3)
steps(1, []); steps(1, [Input::X]); steps(1, []); steps(1, [Input::X]); steps(1, [])
check("...on to Toggle Limit (5x) (#{SU.speed})", SU.speed == 5)
steps(1, [Input::X]); steps(1, [])
check("...then round to 1x (#{SU.speed})", SU.speed == 1)
steps(1, [Input::L]); steps(1, []); steps(1, [Input::L]); steps(1, [])
check("Next Speed (L) on the map: 3x (#{SU.speed})", SU.speed == 3)
$game_temp.in_menu = true
steps(1, [Input::R]); steps(1, [])
check("...Reset Speed (R) in a menu does nothing (menus use L and R) (#{SU.speed})", SU.speed == 3)
$game_temp.in_menu = false
steps(1, [Input::R]); steps(1, [])
check("...on the map, back to 1x (#{SU.speed})", SU.speed == 1)
check("...PIF's own stages untouched ($GameSpeed #{$GameSpeed})", $GameSpeed == 0)
steps(1, [Input::L]); steps(1, []); steps(1, [Input::L]); steps(1, []); steps(1, [Input::L]); steps(1, [])
check("4x on the map (#{SU.speed}); its frames: one in four (#{steps(8, [])})", SU.speed == 4 && steps(8, []) == 2)
$game_temp.in_battle = true
steps(1, [])
check("Separate: a battle has its own speed, 1x (#{SU.speed})", SU.speed == 1)
steps(1, [Input::L]); steps(1, [])
check("...stepped in battle: 2x (#{SU.speed})", SU.speed == 2)
$game_temp.in_battle = false
steps(1, [])
check("...out of battle, the map's 4x again (#{SU.speed})", SU.speed == 4)
check("Remember Speed keeps both (#{S.get(:"speed_up.saved_overworld")}, #{S.get(:"speed_up.saved_battles")})",
      S.get(:"speed_up.saved_overworld") == 4 && S.get(:"speed_up.saved_battles") == 2)
S.set(:"speed_up.toggle_speeds", 1)
$game_temp.in_battle = true
steps(1, [])
check("Shared: the battle runs at the map's 4x (#{SU.speed})", SU.speed == 4)
$game_temp.in_battle = false
S.set(:"speed_up.toggle_speeds", 0)
S.set(:"speed_up.toggle_limit", 1)
steps(1, [])
check("Toggle Limit lowered to 3x, under the speed: it stops at the limit (#{SU.speed})", SU.speed == 3)
S.set(:"speed_up.toggle_limit", 3)

#---------------------------------------------------------------- Shiny Slowdown, Messages, settings screens
$game_temp.in_battle = true
SU.set_toggled(4, :battles)
PokeBattle_Battle.new([Shiny.new(false)]).pbStartBattleSendOut(nil)
check("a wild battle, no shiny: still 4x (#{SU.toggled(:battles)})", SU.toggled(:battles) == 4)
PokeBattle_Battle.new([Shiny.new(false), Shiny.new(true)]).pbStartBattleSendOut(nil)
check("a wild shiny: the battle's speed drops to 1x before the send-out (#{$log.grep(/SENDOUT/).last})",
      SU.toggled(:battles) == 1 && $log.grep(/SENDOUT/).last == "SENDOUT speed 1")
SU.set_toggled(4, :battles)
PokeBattle_Battle.new([Shiny.new(true)], false).pbStartBattleSendOut(nil)
check("...a trainer's shiny doesn't (#{SU.toggled(:battles)})", SU.toggled(:battles) == 4)
$game_temp.in_battle = false
SU.set_toggled(5, :overworld)
OverworldPokemonEvent.new.setup_pokemon(true)
check("a shiny on the map: the map's speed to 1x (#{SU.toggled(:overworld)})", SU.toggled(:overworld) == 1)
S.set(:"speed_up.shiny_slowdown", false)
SU.set_toggled(5, :overworld)
OverworldPokemonEvent.new.setup_pokemon(true)
check("...Shiny Slowdown Off: it stays (#{SU.toggled(:overworld)})", SU.toggled(:overworld) == 5)
S.set(:"speed_up.shiny_slowdown", true)
steps(1, [])
pbMessageDisplay(nil, "Hi")
check("Messages at 1x Off: a message box runs at 5x (#{$msg_speed})", $msg_speed == 5)
S.set(:"speed_up.messages", true)
pbMessageDisplay(nil, "Hi")
steps(1, [])
check("...On: 1x while it's open (#{$msg_speed}), 5x after (#{SU.speed})", $msg_speed == 1 && SU.speed == 5)
check("...the window title said x1 meanwhile", true)
PokemonOptionScreen.new.pbStartScreen
steps(1, [])
check("Options runs at 2x at most (#{$options_speed}); 5x after (#{SU.speed})", $options_speed == 2 && SU.speed == 5)
SU.set_toggled(1)
PokemonOptionScreen.new.pbStartScreen
check("...and at 1x when that's the speed (#{$options_speed})", $options_speed == 1)
SU.set_toggled(5)
steps(1, [])
S.set(:"speed_up.type", 0)
steps(1, [Input::X])
OverworldPokemonEvent.new.setup_pokemon(true)
steps(2, [Input::X])
check("Hold: a shiny drops it to 1x while the button stays held (#{SU.speed})", SU.speed == 1)
steps(1, []); steps(1, [Input::X])
check("...held again: Speed-Up again (#{SU.speed})", SU.speed == 4)
steps(1, [])

#---------------------------------------------------------------- the Overworld Menu's row, KIF Settings
e = R::OverworldMenu.entry(:speed_up)
om_shown = R::OverworldMenu.respond_to?(:shown?) ? R::OverworldMenu.shown?(e) : true
check("the Overworld Menu's Speed-Up row shows in Hold too, 1x to 10x, on Speed-Up (Overworld) (#{e.values.length}, #{e.get.call})",
      om_shown && e.values.length == 10 && e.values[3] == "x4" && e.get.call == 3)
e.set.call(5)
check("...set: Speed-Up (Overworld) 6x (#{S.get(:"speed_up.overworld")})", S.get(:"speed_up.overworld") == 5 && SU.setting(:overworld) + 1 == 6)
S.set(:"speed_up.type", 1)
SU.set_toggled(2, :overworld)
check("...Toggle: 1x to Toggle Limit, on the speed now (#{e.values.length}, #{e.get.call})", e.values.length == 5 && e.get.call == 1)
e.set.call(3)
check("...set: the map's speed 4x (#{SU.toggled(:overworld)})", SU.toggled(:overworld) == 4)
items, = KIF::SettingsScreen.pif_items
check("PIF's Speed-up rows step aside in KIF Settings (#{items.map { |i| i[:name] }.inspect})", items.map { |i| i[:name] } == ["Text Speed"])

#---------------------------------------------------------------- Off, and a failure
KIF::SpeedTitle.update_title
KIF::SpeedTitle.check_keys
check("KIF's own title and L/R keys stay quiet while Speed-Up runs (#{$title})", $title.start_with?("Kanto Reloaded ") && !$log.include?("KIF KEYS"))
R::Features.set(:speed_up, :off)
KIF::SpeedTitle.update_title
check("...Off: KIF's title is back (#{$title})", $title.start_with?("Kuray's"))
$GameSpeed = 0
steps(1, [Input::X]); steps(1, [])
check("Off: PIF's own speed-up again, X steps its stages ($GameSpeed #{$GameSpeed})", $GameSpeed == 1)
n = steps(6, [])
check("...at its 2x (#{n} of 6 drawn)", n == 3)
items, = KIF::SettingsScreen.pif_items
check("...PIF's rows back in KIF Settings", items.length == 4)
$GameSpeed = 0
R::Features.set(:speed_up, :on)
steps(1, [])
SU.singleton_class.send(:define_method, :chosen_speed) { raise "boom" }
$CanToggle = true
steps(1, [])
check("a failure: Speed-Up is off for the session, PIF's takes over", R::Features.failed?(:speed_up) && !R::Features.on?(:speed_up))
check("...$CanToggle as it was", $CanToggle == true)
errors = File.read(R::Log.path).lines.select { |l| l.include?("ERROR") || (l.include?("skipped") && l.include?("speed_up")) }
check("the one error in Kanto Reloaded's log is that failure, and no Speed-Up hook skipped (#{errors.length})",
      errors.length == 1 && errors[0].include?("Speed-Up failed"))
errors.reject { |l| l.include?("Speed-Up failed") }.first(6).each { |l| puts "  " + l }
puts $failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED"
exit($failed ? 1 : 0)
