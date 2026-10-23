# encoding: utf-8
# Headless tests for Reloaded Controls: the layer under a fake engine that
# has KIF Beta's kind of Input wrappers (Auto-Battle's confirm, Frame Rate's
# key repeat, the F8 screenshot update), with KIF Beta's own F1 bindings.
# Usage: ruby Tools/Tests/controls_test.rb <KIF Beta root> <empty temp folder>
# Not loaded by the game (mod.json only loads Bootstrap.rb).
require "fileutils"

KIF_ROOT = ARGV[0]
USERDIR = ARGV[1]
require_relative "work_folder"
KRWork.claim(USERDIR)
$log = []
$failed = false

def check(label, cond)
  puts "#{cond ? 'ok  ' : 'FAIL'} #{label}"
  $failed = true unless cond
end

load File.join(File.dirname(__FILE__), "test_stubs.rb")
# The player's copy of the F1 bindings: KIF Beta's defaults
FileUtils.cp(File.join(KIF_ROOT, "Data/keybindings.mkxp1"), File.join(USERDIR, "keybindings.mkxp1"))

#---------------------------------------------------------------- a fake engine
# Input as mkxp-z has it. Defined in "ENGINE" so the test can tell the layer
# these are the engine's methods (the real ones are C code).
ENGINE = <<~'RUBY'
  module Input
    { :DOWN => 2, :LEFT => 4, :RIGHT => 6, :UP => 8, :A => 11, :B => 12, :C => 13, :X => 14, :Y => 15,
      :Z => 16, :L => 17, :R => 18, :SHIFT => 21, :F8 => 28 }.each { |k, v| const_set(k, v) unless const_defined?(k) }
    @raw = Array.new(512, false)
    @cur = {}
    @prev = {}
    class << self
      attr_reader :raw, :text
      # the engine's buttons from its own bindings (F1)
      def update
        @prev = @cur
        @cur = {}
        Reloaded::Controls::Inputs.engine_bindings.each do |button, sides|
          @cur[button] = sides[:keys].any? { |t| @raw[t[2..-1].to_i] } ||
                         sides[:pad].any? { |t| t.start_with?("p:") && Input::Controller.buttons[t[2..-1].to_i] }
        end
        @cur[28] = @raw[65]                       # F8
      end
      def press?(b);   return @cur[b] ? true : false; end
      def trigger?(b); return (@cur[b] && !@prev[b]) ? true : false; end
      def repeat?(b);  return trigger?(b); end
      def release?(b); return (!@cur[b] && @prev[b]) ? true : false; end
      def dir4; return [2, 4, 6, 8].find { |d| @cur[d] } || 0; end
      def dir8; return dir4; end
      def raw_key_states; return @raw.dup; end
      def text_input=(v); @text = v; end
      def triggerex?(k); return false; end
    end
    module Controller
      @buttons = Array.new(21, false)
      @axes = Array.new(6, 0.0)
      @connected = true
      class << self
        attr_accessor :buttons, :axes, :connected
        attr_writer :name
        def connected?; return @connected; end
        def raw_button_states; return @buttons.dup; end
        def raw_axes; return @axes.dup; end
        def name; return @name || "Xbox Controller"; end
      end
    end
  end
RUBY
eval(ENGINE, TOPLEVEL_BINDING, "ENGINE")

# KIF Beta's wrappers, the way it writes them
module Input
  BACK = B unless const_defined?(:BACK)
  ACTION = A unless const_defined?(:ACTION)
  SPECIAL = Z unless const_defined?(:SPECIAL)
  USE = C unless const_defined?(:USE)
  AUX1 = L unless const_defined?(:AUX1)       # PIF's names for the page buttons (SpeedTitle.rb uses them)
  AUX2 = R unless const_defined?(:AUX2)
  class << Input
    alias update_KGC_ScreenCapture update
    alias kif_auto_trigger? trigger?
    alias kif_fps_repeat? repeat?
  end
  def self.update
    update_KGC_ScreenCapture
    $screenshots = $screenshots.to_i + 1 if trigger?(Input::F8)
  end
  def self.trigger?(button)
    return true if $auto_confirm && button == Input::USE
    return kif_auto_trigger?(button)
  end
  def self.repeat?(button)
    return Input.press?(button) ? :between : false if $fps_between
    return kif_fps_repeat?(button)
  end
end
class Scene_Map; end
# KIF's key names (018), as far as the hints use them
module KIF
  module Keys
    module_function
    def label(button, default = nil); return "F1 key #{button}"; end
    def short(button); return "f1"; end
  end
  # Kanto Reloaded's mod.json locks Battle Info Off (KIF applies it before the scripts load)
  module Locks
    def self.get(key); return key == :cody_battleinfo ? [0, "Kanto Reloaded", "KantoReloaded"] : nil; end
  end
end
class GameTempStub; attr_accessor :in_battle, :in_menu; end

#---------------------------------------------------------------- boot
load File.join(KIF_ROOT, "Mods/KantoReloaded/Bootstrap.rb")
R = Reloaded
C = R::Controls
L = C::Layer
I = C::Inputs
check("bootstrap ready (#{R::Bootstrap.status}, failures #{R::Bootstrap.failures.inspect})", R::Bootstrap.status == :ready)
# The real engine's methods are C code; here, the ones from "ENGINE"
def L.engine_method?(m); return m.source_location.nil? || m.source_location[0] == "ENGINE"; end
L.instance_variable_set(:@installed, false)
L.instance_variable_set(:@replaced, [])
L.install
replaced = L.replaced.map(&:to_s)
check("the engine's methods are replaced under KIF's wrappers (#{replaced.sort.join(' ')})",
      %w[update_KGC_ScreenCapture kif_auto_trigger? kif_fps_repeat? press? release? dir4 dir8 text_input=].all? { |n| replaced.include?(n) } &&
      !replaced.include?("update") && !replaced.include?("trigger?"))

def step(n = 1); n.times { Input.update }; end
def key(code, down = true); Input.raw[code] = down; end
def pad(code, down = true); Input::Controller.buttons[code] = down; end
def release_all
  Input.raw.fill(false)
  Input::Controller.buttons.fill(false)
  Input::Controller.axes.fill(0.0)
  step(2)
end

#---------------------------------------------------------------- the controller check (the log)
def log_count(text); File.read(R::Log.path).scan(text).length; end
step
check("the controller check: the one there at start-up, by the engine's name, with its buttons and axes",
      log_count("Controller there at start-up: \"Xbox Controller\" (21 buttons, 6 axes; Reloaded Controls On)") == 1)
pad(0)
step
pad(0, false)
step
pad(0)
step
check("...a button's first press, once (A pressed and let go twice)", log_count("Controller button 0 (A) pressed") == 1)
Input::Controller.axes[1] = -0.8
step
Input::Controller.axes[4] = 0.3
step
check("...a stick pushed past halfway, with its value; a trigger pressed less isn't",
      log_count("Controller axis 1 (LeftY) - (-0.80)") == 1 && log_count("axis 4 (LeftTrigger)") == 0)
release_all
Input::Controller.connected = false
step
check("...the controller going away", log_count("The controller was disconnected.") == 1)
Input::Controller.name = "PS4 Controller"
Input::Controller.connected = true
R::Settings.set(C::TOGGLE, false)
step
pad(1)
step
check("...a new one coming, by its name; its presses noted again, with Reloaded Controls Off too",
      log_count("Controller connected: \"PS4 Controller\" (21 buttons, 6 axes; Reloaded Controls Off)") == 1 &&
      log_count("Controller button 1 (B) pressed") == 1)
R::Settings.set(C::TOGGLE, true)
Input::Controller.name = nil
release_all
key(40)             # back on the keyboard, the last device used (KIF's key names follow it)
step
release_all

#---------------------------------------------------------------- the toggle and F1
check("Reloaded Controls is On by default, in Reloaded Systems after Reloaded Settings",
      C.enabled? && R::Settings.definition(C::TOGGLE)[:page] == :systems &&
      R::Settings.keys(:systems).first(2) == [:"systems.reloaded_settings", C::TOGGLE])
check("Reloaded Controls stays out of presets", !R::Settings.definition(C::TOGGLE)[:preset])
step
check("the layer answers while Reloaded Controls is On", L.active?)
check("the game's buttons start on the player's F1 keys (Confirm: #{C.bindings(:confirm, :keys).inspect})",
      C.bindings(:confirm, :keys) == ["k:40", "k:6"] && C.bindings(:confirm, :pad) == ["p:0"])
check("...and F1's sticks (Down: #{C.bindings(:down, :pad).inspect})", C.bindings(:down, :pad).include?("a:1+"))
check("labels: Confirm is Enter on keyboard, A on an Xbox controller",
      C.label(:confirm, :keyboard) == "Enter" && C.label(:confirm, :controller) == "A")

check("KIF's key names follow Reloaded Controls (Confirm: #{KIF::Keys.label(Input::C)})", KIF::Keys.label(Input::C) == "Enter" && KIF::Keys.short(Input::C) == "Enter")
check("...and other buttons are still KIF's", KIF::Keys.label(Input::F8) == "F1 key 28")

#---------------------------------------------------------------- pressing
key(40)
step
check("Enter: Confirm is pressed and just pressed", Input.press?(Input::C) && Input.trigger?(Input::C))
step
check("held: pressed, not just pressed", Input.press?(Input::C) && !Input.trigger?(Input::C))
key(40, false)
step
check("let go: released", !Input.press?(Input::C) && Input.release?(Input::C))
step
$auto_confirm = true
check("KIF's Auto-Battle confirm still works on top of the layer", Input.trigger?(Input::USE))
$auto_confirm = false
check("...and without it nothing is pressed", !Input.trigger?(Input::USE))
key(65)
step
check("F8 (the engine's own key) still takes a screenshot", $screenshots.to_i == 1)
key(65, false)
step

#---------------------------------------------------------------- repeat and directions
key(81)                                     # Down arrow
first, every = C.repeat_timing
hits = []
(first + every * 2 + 1).times { |i| step; hits << i if Input.repeat?(Input::DOWN) }
check("a held button repeats after #{first} steps, then every #{every} (#{hits.inspect})",
      hits == [0, first, first + every, first + every * 2])
$fps_between = true
check("Cody's Frame Rate repeat still runs on the layer's states", Input.repeat?(Input::DOWN) == :between)
$fps_between = false
key(80)                                     # Left as well
step
check("dir4 is the direction pressed last, dir8 combines them", Input.dir4 == 4 && Input.dir8 == 1)
key(80, false)
step
check("let go of Left: dir4 is Down again", Input.dir4 == 2)
release_all

#---------------------------------------------------------------- controller
pad(0)
step
check("the controller's A confirms", Input.trigger?(Input::C) && C.device == :controller)
check("hints follow the controller (Confirm: #{R::Prompts.name(:C)})", R::Prompts.name(:C) == "A")
release_all
R::Settings.set(:"controls.swap_ab", true)
pad(1)
step
check("Swap A and B: the right face button confirms", Input.trigger?(Input::C))
check("...and the hint says so (Confirm: #{C.label(:confirm, :controller)}, Back: #{C.label(:back, :controller)})",
      C.label(:confirm, :controller) == "B" && C.label(:back, :controller) == "A")
release_all
R::Settings.set(:"controls.swap_ab", false)
Input::Controller.name = "DualSense Wireless Controller"
check("a PlayStation controller's names (Confirm: #{C.label(:confirm, :controller)})", C.label(:confirm, :controller) == "Cross")
Input::Controller.name = nil
Input::Controller.axes[1] = 0.3
step
check("the stick inside Stick Deadzone does nothing", !Input.press?(Input::DOWN))
Input::Controller.axes[1] = 0.7
step
check("past it, the stick is Down", Input.press?(Input::DOWN))
release_all

#---------------------------------------------------------------- typing
Input.text_input = true
key(6)                                      # C, which is also Confirm
pad(0)
step
check("while typing, a letter doesn't press a game button; the controller still does",
      L.typing? && Input.press?(Input::C) && C.bindings(:confirm, :keys).include?("k:6"))
pad(0, false)
step
check("...the letter alone presses nothing", !Input.press?(Input::C))
key(81)
step
check("...an arrow still moves (Down for search results)", Input.press?(Input::DOWN))
Input.text_input = false
release_all

#---------------------------------------------------------------- rebinding
C.bind(:confirm, :keys, ["k:44"])           # Space
key(40)
step
check("rebound: Enter no longer confirms", !Input.press?(Input::C))
key(44)
step
check("...Space does", Input.press?(Input::C))
check("the controller side still follows F1", C.bindings(:confirm, :pad) == ["p:0"] && C.customized?(:confirm, :keys) && !C.customized?(:confirm, :pad))
check("bindings are saved to Controls.json", R::JSON.parse(File.read(C.path))["bindings"]["confirm"]["keys"] == ["k:44"])
release_all
C.reset(:confirm)
check("reset: back on F1", C.bindings(:confirm, :keys) == ["k:40", "k:6"] && !C.customized?(:confirm))
C.bind(:confirm, :keys, [])
C.bind(:confirm, :pad, [])
key(40)
step
check("Confirm unbound everywhere falls back to F1, so the game can't lock you out", Input.press?(Input::C))
C.reset(:confirm)
release_all
check("a bad input is refused", (begin; C.bind(:back, :keys, ["k:abc"]); false; rescue ArgumentError; true; end))
check("the engine's own keys (F1, F2, F12) can't be bound",
      %w[k:58 k:59 k:69].all? { |t| begin; C.bind(:back, :keys, [t]); false; rescue ArgumentError; true; end })
C.bind(:down, :keys, [])
C.bind(:down, :pad, [])
key(81)
step
check("moving can't be unbound either: Down falls back to F1", Input.press?(Input::DOWN) && L.active?)
C.reset(:down)
release_all
pad_a = C.bindings(:confirm, :pad).find { |t| t.start_with?("p:") }
C.bind(:confirm, :pad, [])
pad(pad_a[2..-1].to_i)
step
check("each device keeps its own: Confirm's controller side unbound uses F1's #{pad_a}, keys kept",
      Input.press?(Input::C) && C.bindings(:confirm, :keys) == ["k:40", "k:6"])
C.reset(:confirm)
release_all
R::Settings.set(:"controls.button_style", 2)
check("Button Style picks the controller's icons (PlayStation: #{L.style})", L.style == :playstation && C.label(:confirm, :controller) == "Cross")
R::Settings.set(:"controls.button_style", 0)
check("...Auto goes by the controller's name", L.style == :xbox)

#---------------------------------------------------------------- feature actions (the API)
C.register(:test_info, :name => "Test Info", :area => :battle, :follows => :action,
           :description => "Opens Battle Info.", :owner => :kif)
check("a feature action starts on the button it follows", C.bindings(:test_info, :keys) == C.bindings(:action, :keys))
key(225)                                    # Left Shift (Action in F1)
step
check("...and reads it", C.press?(:test_info) && C.trigger?(:test_info))
release_all
check("following isn't a clash", C.clashes(:test_info).empty?)
C.bind(:test_info, :keys, ["k:7"])        # D, which is Special
check("rebound onto Special's key: clashes with Special (Global) and Shift (Battle, follows Special), only those (#{C.clashes(:test_info).map { |a, t| [a.id, t] }.inspect})",
      C.clashes(:test_info).map { |a, t| [a.id, t] } == [[:special, "k:7"], [:shift, "k:7"]])
C.register(:test_mega, :name => "Test Mega", :area => :battle, :follows => :action)
check("two features on the same button they follow don't clash", C.clashes(:test_mega).empty?)
check("...and it no longer follows Action", C.bindings(:test_info, :keys) == ["k:7"])
C.register(:test_toggle, :name => "Test Toggle", :area => :overworld, :keys => ["k:9"])
C.bind(:test_toggle, :keys, ["k:7"])
check("actions in different areas don't clash", C.clashes(:test_toggle).none? { |a, _| a.id == :test_info })
C.reset(:test_info)
C.reset(:test_toggle)
C.bind(:test_toggle, :keys, ["k:9"])
C.bind(:confirm, :keys, ["k:44"])
C.reset_area(:overworld)
check("Reset Section resets one area only", !C.customized?(:test_toggle) && C.customized?(:confirm))
C.reset(:confirm)
C.register(:quick_menu, :name => "Quick Menu", :area => :overworld, :keys => ["hold:k:22"])   # hold S
step
hold = C.hold_steps
key(22)
step(hold - 2)
check("tap and hold: before Hold Time neither fires", !C.press?(:quick_menu) && !Input.press?(Input::Y))
key(22, false)
step
check("let go early: the tap (Y, quicksave) fires on release", Input.trigger?(Input::Y) && !C.press?(:quick_menu))
step
check("...for one step", !Input.press?(Input::Y))
key(22)
step(hold)
check("held for Hold Time: the hold action fires, not the tap", C.trigger?(:quick_menu) && !Input.press?(Input::Y))
key(22, false)
step
check("let go after a hold: no tap", !Input.press?(Input::Y) && C.release?(:quick_menu))
release_all
C.register(:screenshot, :name => "Screenshot", :pad => ["a:5+"])
Input::Controller.axes[5] = 0.3
step
check("a trigger short of Trigger Press does nothing", !C.press?(:screenshot))
Input::Controller.axes[5] = 0.9
step
check("past it, the trigger presses", C.press?(:screenshot))
release_all
check("bad registrations are refused",
      (begin; C.register(:x1, :area => :nowhere); false; rescue ArgumentError; true; end) &&
      (begin; C.register(:x2, :keys => ["q:1"]); false; rescue ArgumentError; true; end))

#---------------------------------------------------------------- split features
SP = C::Splits
check("KIF's features are split off their buttons (#{SP.splits.map(&:first).join(", ")})",
      [:run, :pause_menu, :ready_menu, :quicksave, :mega, :speed_up].all? { |id| C.action(id) && C.action(id).follows })
check("Battle Info is locked Off, so it gets no action", C.action(:battle_info).nil?)
check("...each following today's button (Quicksave: Y, Run: Action, Pause Menu: Back)",
      C.action(:quicksave).follows == :y && C.action(:run).follows == :action && C.action(:pause_menu).follows == :back &&
      C.bindings(:quicksave, :keys) == C.bindings(:y, :keys))
# Quicksave's file and the Bag's both check Y; the game loads scripts with only their names
eval("def quicksave_y?; Input.trigger?(Input::Y); end", TOPLEVEL_BINDING, "Quicksave.rb")
eval("def bag_y?; Input.trigger?(Input::Y); end", TOPLEVEL_BINDING, "007_UI_Bag.rb")
pad(7)                                      # L3: Y in F1 (S has a hold action above)
step
check("following Y: L3 quicksaves, and is Y everywhere else too", quicksave_y? && bag_y?)
release_all
C.bind(:quicksave, :pad, ["p:6"])           # Start
pad(7)
step
check("Quicksave moved to Start: L3 no longer quicksaves, but is still Y in the Bag", !quicksave_y? && bag_y?)
release_all
pad(6)
step
check("...Start quicksaves, and isn't Y anywhere else", quicksave_y? && !bag_y?)
release_all
R::Settings.set(C::TOGGLE, false)
step
pad(7)
step
check("Reloaded Controls Off: Quicksave's check is the game's own Y again", quicksave_y?)
release_all
R::Settings.set(C::TOGGLE, true)
step
C.reset(:quicksave)
eval("def run_held?; Input.press?(Input::ACTION); end", TOPLEVEL_BINDING, "010_Game_Player_Visuals.rb")
C.bind(:run, :pad, ["p:1"])                 # Pokémon-Style: B runs
pad(1)
step
check("Run on B: held B runs (and is still Back)", run_held? && Input.press?(Input::B))
release_all
C.reset(:run)
check("a split needs a game button with an action, and files",
      (begin; SP.add(:nope, :button => 99, :files => ["x.rb"]); false; rescue ArgumentError; true; end) &&
      (begin; SP.add(:nope, :button => :Y); false; rescue ArgumentError; true; end))

#---------------------------------------------------------------- areas
$scene = Scene_Map.new
$game_temp = GameTempStub.new
step
check("on the map: Overworld", C.area == :overworld)
$game_temp.in_menu = true
step
check("in the pause menu: Menus", C.area == :menus)
$game_temp.in_battle = true
step
check("in battle: Battle", C.area == :battle)
$scene = nil
$game_temp = nil

#---------------------------------------------------------------- layouts
LA = C::Layouts
File.delete(LA.path) if File.exist?(LA.path)
LA.reload
check("no layouts at first; a new one is named Layout 1", LA.list.empty? && LA.next_name == "Layout 1")
C.bind(:confirm, :keys, ["k:44"])
R::Settings.set(:"controls.swap_ab", true)
check("Save as New keeps the controls and Feel",
      LA.add("Mine") && LA.list[0]["bindings"]["confirm"]["keys"] == ["k:44"] && LA.list[0]["feel"]["controls.swap_ab"] == true)
C.reset_all
R::Settings.reset(:"controls.swap_ab")
LA.reload                                   # read back from the file
loaded = LA.load(0)
check("Load puts them back (Confirm: #{C.bindings(:confirm, :keys).inspect})",
      loaded && C.bindings(:confirm, :keys) == ["k:44"] && C.swap_ab?)
check("...and what matches the default isn't customized, so it keeps following F1",
      !C.customized?(:back) && C.customized?(:confirm, :keys) && !C.customized?(:confirm, :pad))
code = LA.share_code(0)
check("a layout's share code starts KRC1:", code.start_with?("KRC1:"))
check("...and pastes back as the same layout", LA.read_code(code) == LA.list[0])
check("a settings preset's code or junk isn't a layout",
      LA.read_code("KIF1:" + code[5..-1]).nil? && LA.read_code("KRC1:!!!").nil? && LA.read_code("hello").nil?)
bad = R::ShareCodes.encode("KRC1:", { "name" => "Bad",
  "bindings" => { "up" => { "keys" => [], "pad" => ["p:999x"] }, "confirm" => { "keys" => ["k:58", "k:4", 7] },
                  "nope" => { "keys" => ["k:5"] } },
  "feel" => { "controls.repeat" => "fast", "evil" => 1 } })
pasted = LA.read_code(bad)
check("a pasted layout is checked: bad inputs, the engine's keys and odd Feel values dropped (#{pasted.inspect})",
      pasted["bindings"]["confirm"]["keys"] == ["k:4"] && pasted["bindings"]["up"]["pad"] == [] && pasted["feel"].empty?)
LA.add_layout(pasted)
LA.load(1)
check("loading it: Up keeps its default rather than nothing, and actions this game lacks are skipped",
      C.bindings(:up, :keys) == ["k:82"] && !C.bindings(:up, :pad).empty? && C.bindings(:confirm, :keys) == ["k:4"] && C.action(:nope).nil?)
check("Rename (16 letters at most) and Delete",
      LA.rename(1, "  A Very Long Layout Name  ") && LA.list[1]["name"] == "A Very Long Layo" && LA.delete(1) && LA.list.length == 1)
check("a name that's taken gets a number (#{LA.add("Mine") && LA.list[1]["name"]})", LA.list[1]["name"] == "Mine (2)")
check("...cut to fit 16 letters", LA.add("Mine") && LA.rename(2, "A Very Long Layout Name") &&
                                  LA.add("A Very Long Layo") && LA.list[3]["name"] == "A Very Long (2)")
8.times { |i| LA.add("L#{i}") }
check("12 layouts at most", LA.full? && !LA.add("Extra") && LA.list.length == 12)
File.write(LA.path, "{ not json")
LA.reload
check("an unreadable layouts file: no layouts, the file kept aside", LA.list.empty? && File.exist?(LA.path + ".unreadable"))
File.delete(LA.path + ".unreadable")
LA.reload
C.reset_all
R::Settings.reset(:"controls.swap_ab")
release_all

#---------------------------------------------------------------- Pokémon-Style
C.bind(:run, :keys, ["k:9"])                # a key of the player's own
C.bind(:confirm, :pad, ["p:3"])             # a controller change Pokémon-Style puts back
LA.pokemon_style
check("Pokémon-Style: B runs, X and Start open the menu, Y the Ready Menu, Select held quicksaves, RT speeds up",
      C.bindings(:run, :pad) == ["p:1"] && C.bindings(:pause_menu, :pad) == ["p:2", "p:6"] &&
      C.bindings(:ready_menu, :pad) == ["p:3"] && C.bindings(:quicksave, :pad) == ["hold:p:4"] &&
      C.bindings(:speed_up, :pad) == ["a:5+"])
check("...the keyboard stays as it was; the controller's other inputs go back to the game's",
      C.bindings(:run, :keys) == ["k:9"] && !C.customized?(:confirm, :pad))
eval("def map_back?; Input.trigger?(Input::BACK); end", TOPLEVEL_BINDING, "002_Scene_Map.rb")
pad(1)
step
check("...held B runs, and no longer opens the pause menu on the map (but is still Back)",
      run_held? && !map_back? && Input.press?(Input::B))
release_all
pad(6)
step
check("...Start opens it", map_back?)
release_all
pad(4)
step(C.hold_steps)
check("...holding Select quicksaves", quicksave_y?)
release_all
C.reset_all
release_all

#---------------------------------------------------------------- extra actions
check("Run Toggle, Bicycle and Poké Radar start with no key or button (Overworld)",
      [:run_toggle, :bicycle, :poke_radar].all? { |id| C.action(id) && C.action(id).area == :overworld &&
                                                       C.bindings(id, :keys).empty? && C.bindings(id, :pad).empty? })
# the game, as far as they use it
class ExtraSystem; attr_accessor :runstyle; end
module GameData; class Item; def self.exists?(i); [:BICYCLE, :RACEBIKE, :POKERADAR].include?(i); end; end; end
class ExtraBag; def initialize(items); @items = items; end; def pbHasItem?(i); @items.include?(i); end; end
class ExtraPlayer; attr_accessor :moving; def moving?; @moving; end; def straighten; end; end
$used = []
def pbUseKeyItemInField(item); $used << item; true; end
def pbPlayBuzzerSE; $used << :buzz; end
$PokemonSystem = ExtraSystem.new
$PokemonSystem.runstyle = 0
$PokemonBag = ExtraBag.new([:BICYCLE])
$game_player = ExtraPlayer.new
map = Scene_Map.new
$scene = map
C.bind(:run_toggle, :keys, ["k:9"])         # F
key(9)
step
C::ExtraActions.on_map(map)
check("Run Toggle: one press switches to running (Default Movement: #{$PokemonSystem.runstyle})", $PokemonSystem.runstyle == 1)
release_all
C.bind(:bicycle, :keys, ["k:5"])            # B
$game_player.moving = true
key(5)
step
C::ExtraActions.on_map(map)
check("Bicycle pressed while walking: it waits", $used.empty?)
release_all
$game_player.moving = false
C::ExtraActions.on_map(map)
check("...and gets on the Bicycle once the player stops (#{$used.inspect})", $used == [:BICYCLE])
C.bind(:poke_radar, :keys, ["k:16"])        # M
key(16)
step
C::ExtraActions.on_map(map)
check("Poké Radar without the item: a buzz, nothing used (#{$used.inspect})", $used == [:BICYCLE, :buzz])
release_all
C.reset_all
$scene = $game_player = $PokemonBag = $PokemonSystem = nil

#---------------------------------------------------------------- F1 changes
data = File.binread(File.join(USERDIR, "keybindings.mkxp1"))
extra = [1, 14, 0, 13].pack("l<4")        # K -> C
count = data[8, 4].unpack1("l<") + 1
File.binwrite(File.join(USERDIR, "keybindings.mkxp1"), data[0, 8] + [count].pack("l<") + data[12..-1] + extra)
File.utime(Time.now + 5, Time.now + 5, File.join(USERDIR, "keybindings.mkxp1"))
step(L::CHECK_FILE_EVERY + 1)
check("a change in F1 is picked up (Confirm: #{C.bindings(:confirm, :keys).inspect})", C.bindings(:confirm, :keys).include?("k:14"))
key(14)
step
check("...and works", Input.press?(Input::C))
release_all

#---------------------------------------------------------------- Off
C.bind(:confirm, :keys, ["k:44"])
R::Settings.set(C::TOGGLE, false)
step
key(40)
step
check("Off: the engine answers, with F1's keys (Enter confirms)", !L.active? && Input.press?(Input::C))
key(40, false)
key(44)
step
check("...and the layer's (Space) do nothing", !Input.press?(Input::C))
check("Off: KIF's key names are its own again", KIF::Keys.label(Input::C) == "F1 key 13")
release_all
key(225)
step
check("Off: an action that follows a game button reads that button", C.press?(:test_info))
key(225, false)
key(22)
step(hold + 1)
check("Off: an action of its own doesn't fire", !C.press?(:quick_menu))
release_all
key(79)                                     # Right held while switching back on
step
R::Settings.set(C::TOGGLE, true)
step
check("switched on while Right is held: held, not a new press (no double change)", Input.press?(Input::RIGHT) && !Input.trigger?(Input::RIGHT) && !Input.repeat?(Input::RIGHT))
release_all
C.reset(:confirm)
step

#---------------------------------------------------------------- failure
check("the layer never failed before this test (a failure would hide behind the engine)", !L.instance_variable_get(:@failed))
Input.raw[999] = true                      # nothing reads this: a missing key is just "not pressed"
def C.hold_steps; raise "broken"; end       # the layer's own code fails
step
check("if the layer fails it turns itself off and the engine's controls are back", !L.active? && C.enabled?)
check("...and says why in the log", File.read(R::Log.path).include?("The controls layer failed"))
key(40)
step
check("...Enter confirms through the engine", Input.press?(Input::C))

#---------------------------------------------------------------- an unreadable Controls.json
File.write(C.path, "{ not json")
C.send(:load_file)
check("an unreadable Controls.json is kept aside and the defaults are used",
      File.exist?(C.path + ".unreadable") && !C.customized?(:confirm))

#---------------------------------------------------------------- what the game runs on; the first click or tap
line = File.read(R::Log.path)[/Running on: [^\n]*/].to_s
check("at start-up the log says what the game runs on (#{line})",
      line.start_with?("Running on: Ruby #{RUBY_VERSION} (#{RUBY_PLATFORM}), system unknown; Windows calls no, raw keyboard yes, " \
                       "controller yes, mouse or touch no, clipboard no; PIF's Device: ") && log_count("Running on:") == 1)
check("...not a phone here, and its folder can be written (#{line[/phone: .*/]})",
      line.end_with?("; phone: no; Kanto Reloaded's folder writable yes"))
check("...and still not a phone when asked again (the answer is kept, not turned around)",
      !R::Runtime.phone? && !R::Runtime.phone? && R::Runtime.phone.nil?)
ENV["ANDROID_ROOT"] = "/system"
R::Runtime.reset
check("...a phone known by Android's own variables (as the old Kanto Reloaded did)", R::Runtime.phone == "a phone (Android)" && R::Runtime.phone?)
ENV["JOIPLAY"] = "1"
R::Runtime.reset
check("...and JoiPlay by its marker", R::Runtime.phone == "JoiPlay")
ENV.delete("ANDROID_ROOT")
ENV.delete("JOIPLAY")
R::Runtime.reset
check("...and not a phone again without them", !R::Runtime.phone?)
mob = Class.new { def on_mobile; true; end }.new
was_ps = $PokemonSystem
$PokemonSystem = mob
check("...PIF's Device setting read as it is (Mobile)", R::Runtime.facts[:device] == "Mobile")
$PokemonSystem = was_ps
R::Pointer.singleton_class.send(:alias_method, :test_left?, :left?)
R::Pointer.singleton_class.send(:alias_method, :test_pos, :pos)
$tap = nil
R::Pointer.define_singleton_method(:left?) { !$tap.nil? }
R::Pointer.define_singleton_method(:pos) { $tap }
step
check("...no click or tap, nothing noted", log_count("First click or tap") == 0)
$tap = [120, 48]
step
$tap = [300, 200]
step
check("...the first click or tap of the session, where it landed, once (a phone's touches as clicks)",
      log_count("First click or tap at (120, 48)") == 1 && log_count("First click or tap") == 1)
R::Pointer.singleton_class.send(:alias_method, :left?, :test_left?)
R::Pointer.singleton_class.send(:alias_method, :pos, :test_pos)
$tap = nil

#---------------------------------------------------------------- Wine (the controller fix that also asked is gone, 2026-10-22)
check("...not under Wine without Win32API (plain Ruby)", R::Runtime.facts[:wine].nil?)
$wine = "9.0"
class Win32API
  def initialize(dll, name, _args, _ret); @dll, @name = dll, name; end
  def call(*_a); @dll == "ntdll" && @name == "wine_get_version" ? $wine : nil; end
end
R::Runtime.reset
check("...and Wine's version when Wine answers (Linux, Steam Deck)", R::Runtime.facts[:wine] == "9.0")
Object.send(:remove_const, :Win32API)
R::Runtime.reset
C::PadLog.reset
release_all
key(40)
step
release_all

puts "--- log tail"
puts File.read(R::Log.path).lines.last(4)
puts($failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED")
exit($failed ? 1 : 0)
