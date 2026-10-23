# encoding: utf-8
# Headless tests for the Kanto Reloaded mod's foundation (KIF Beta).
# Usage: ruby Tools/Tests/foundation_test.rb <KIF Beta root> <empty temp folder>
# Not loaded by the game (mod.json only loads Bootstrap.rb).
require "fileutils"

KIF_ROOT = ARGV[0]
USERDIR = ARGV[1]
require_relative "work_folder"
KRWork.claim(USERDIR)
$log = []
$failed = false

def check(label, cond)
  if cond
    puts "ok   #{label}"
  else
    puts "FAIL #{label}"
    $failed = true
  end
end

load File.join(File.dirname(__FILE__), "test_stubs.rb")

# Something to hook
class Widget
  def value(x, scale: 1); x * scale; end
  def boom; raise ArgumentError, "original fails"; end
  def self.make; :made; end
  private
  def secret; :secret; end
end

# PIF's battle scene commands, as the game has them (to fingerprint a real method)
class PokeBattle_Scene; FIGHT_BOX = 3; end
load File.join(KIF_ROOT, "Data/Scripts/011_Battle/005_Battle scene/008_Scene_Commands.rb")

# PIF's frame settings, as far as Window Frames uses them
module Settings
  SPEECH_WINDOWSKINS = ["speech hgss 1", "speech hgss 2", "speech pl 18"]
end
module MessageConfig
  class << self
    attr_reader :system_frame, :speech_frame
    def pbDefaultSystemFrame; "Graphics/Windowskins/default_transparent"; end
    def pbDefaultSpeechFrame; "Graphics/Windowskins/speech hgss 1"; end
    def pbSetSystemFrame(v); @system_frame = v; end
    def pbSetSpeechFrame(v); @speech_frame = v; end
  end
end

# PIF's command window drawing, as far as the command colours fix uses it
def colorToRgb16(c); format("%04X", ((c.red.to_i >> 3) << 10) | ((c.green.to_i >> 3) << 5) | (c.blue.to_i >> 3)); end
def shadowctag(base, shadow); format("<c2=%s%s>", colorToRgb16(base), colorToRgb16(shadow)); end
def toUnformattedText(text); text.gsub(/<[^>]+>/, ""); end
class Window_AdvancedCommandPokemon
  attr_accessor :baseColor, :shadowColor
  attr_reader :drawn, :commands
  def initialize(commands); @commands = commands; @drawn = []; end
  def drawItem(index, _count, _rect); @drawn << @commands[index]; end
end
class Window_PauseMenuCommand < Window_AdvancedCommandPokemon; end
# EBDX's battle command window as 660_EBDX/007_EBDX_UIWidgets.rb has it
class CommandWindowEBDX
  attr_accessor :index
  attr_reader :indexes
  def initialize(indexes); @indexes = indexes; @index = 0; end
end

#---------------------------------------------------------------- boot
load File.join(KIF_ROOT, "Mods/KantoReloaded/Bootstrap.rb")
R = Reloaded
check("bootstrap ready (#{R::Bootstrap.status}, failures #{R::Bootstrap.failures.inspect})", R::Bootstrap.status == :ready)
check("version read from mod.json", R.version == "2.0.0")
check("data folder is in the save folder", R::Paths.data_dir == File.join(File.expand_path(USERDIR), "Kanto Reloaded"))
same = File.join(USERDIR, "same.txt")
File.write(same, "one")
check("free_name: a name no file has (#{File.basename(R::Paths.free_name(same))})", R::Paths.free_name(same) == File.join(USERDIR, "same (2).txt"))
bad = File.join(USERDIR, "bad.json")
File.write(bad, "first")
R::Paths.set_aside(bad)
File.write(bad, "second")
second = R::Paths.set_aside(bad)
check("set_aside never replaces a file kept earlier (#{second && File.basename(second)})",
      File.read(bad + ".unreadable") == "first" && second && File.read(second) == "second" && !File.exist?(bad))
check("settings, logs and bug reports in the mod folder (the test's)",
      R::Paths.settings_dir == File.join(KR_LOCAL_DIR, "Settings") && R::Paths.logs_dir == File.join(KR_LOCAL_DIR, "Logging") &&
      R::Paths.bug_reports_dir == File.join(KR_LOCAL_DIR, "Bug Reports") && File.file?(File.join(KR_LOCAL_DIR, "Logging", "Kanto Reloaded.log")))
check("log file written", File.file?(R::Log.path))

#---------------------------------------------------------------- JSON
J = R::JSON
data = { "a" => [1, 2.5, -3, true, false, nil], "s" => "quote \" slash \\ nl \n tab \t é 漢", "n" => { "x" => {} }, "e" => [] }
check("JSON round-trips (compact)", J.parse(J.generate(data)) == data)
check("JSON round-trips (pretty)", J.parse(J.generate(data, true)) == data)
check("JSON reads \\u escapes and surrogate pairs", J.parse('"é😀"') == "é😀")
check("JSON keys are strings", J.parse('{"k": 1}').keys == ["k"])
bad = ['{"a": `rm -rf`}', '{"a": #{1+1}}', 'system("x")', '{"a":1,}', '[1 2]', '"unterminated', '{"a" 1}', '01', 'nul', '{"a":1} x']
check("JSON rejects non-JSON (no eval): #{bad.length} cases", bad.all? { |t| begin; J.parse(t); false; rescue J::ParseError; true; end })
check("JSON won't write NaN or objects", (begin; J.generate(0.0 / 0); false; rescue ArgumentError; true; end) && (begin; J.generate(Object.new); false; rescue ArgumentError; true; end))
check("JSON rejects deep nesting", (begin; J.parse("[" * 100 + "]" * 100); false; rescue J::ParseError; true; end))

#---------------------------------------------------------------- Features
F = R::Features
F.register(:demo, :name => "Demo", :default => :on)
F.register(:quiet, :name => "Quiet", :default => :off)
F.register(:core_thing, :name => "Core", :core => true)
check("feature defaults", F.on?(:demo) && !F.on?(:quiet) && F.state(:quiet) == :off)
changed = []
R::Events.on(:feature_changed, :test) { |c| changed << [c[:id], c[:state]] }
check("there is no Hidden state, only On and Off", !F.set(:demo, :hidden) && F.state(:demo) == :on)
F.set(:demo, :off)
check("Off stops it and emits feature_changed", !F.on?(:demo) && changed.last == [:demo, :off])
check("states saved to Features.json", J.parse(File.read(File.join(R::Paths.settings_dir, "Features.json")))["states"]["demo"] == "off")
check("core features can't be switched off", !F.set(:core_thing, :off) && F.on?(:core_thing))
F.set(:demo, :on)

# KIF 0.21.52's feature replacement (our Takes Over), as far as Features uses it
module KIF
  module Features
    @replaced = {}
    def self.replace(key, by: nil, owner: nil)
      return false if key == "F-NOPE"
      @replaced[key] = [by, owner]
      return true
    end
    def self.release(owner); @replaced.delete_if { |_k, v| v[1] == owner }; end
    def self.replaced?(key); return @replaced.has_key?(key); end
    def self.replaced_by(key); return @replaced[key] && @replaced[key][0]; end
  end
end
F.register(:takeover, :name => "Takeover", :takes_over => ["F-UI-05_SpeedUp", "F-UI-06_Quicksave"])
check("a feature that's On takes over its KIF features, under Kanto Reloaded",
      KIF::Features.replaced?("F-UI-05_SpeedUp") && KIF::Features.replaced?("F-UI-06_Quicksave") &&
      KIF::Features.replaced_by("F-UI-05_SpeedUp") == "Kanto Reloaded" && F.kif_owner == "KantoReloaded")
F.register(:other_takeover, :name => "Other Takeover", :takes_over => ["F-UI-07_QuickFieldMoves"], :default => :off)
check("an Off feature takes nothing over", !KIF::Features.replaced?("F-UI-07_QuickFieldMoves"))
F.set(:takeover, :off)
check("Off: KIF's features come back", !KIF::Features.replaced?("F-UI-05_SpeedUp") && !KIF::Features.replaced?("F-UI-06_Quicksave"))
F.set(:other_takeover, :on)
F.set(:takeover, :on)
check("each feature switches its own (both on: all three taken over)",
      %w[F-UI-05_SpeedUp F-UI-06_Quicksave F-UI-07_QuickFieldMoves].all? { |k| KIF::Features.replaced?(k) })
F.set(:other_takeover, :off)
check("...one off: only its KIF feature comes back",
      KIF::Features.replaced?("F-UI-05_SpeedUp") && !KIF::Features.replaced?("F-UI-07_QuickFieldMoves"))
F.fail!(:takeover, RuntimeError.new("boom"))
check("a feature that fails gives KIF's back", !KIF::Features.replaced?("F-UI-05_SpeedUp"))
F.register(:refused, :name => "Refused", :takes_over => ["F-NOPE"])
check("a take-over KIF refuses is logged", File.read(R::Log.path).include?("F-NOPE couldn't be taken over"))

#---------------------------------------------------------------- Hooks
H = R::Hooks
H.around(:demo, Widget, :value, :id => :double) { |orig, x, **kw| orig.call(x, **kw) * 2 }
w = Widget.new
check("around hook runs (kwargs pass through)", w.value(3) == 6 && w.value(3, scale: 10) == 60)
F.set(:demo, :off)
check("feature Off: straight to the original", w.value(3) == 3)
F.set(:demo, :on)
H.around(:demo, Widget, :boom, :id => :boom) { |orig| orig.call }
check("an error in the original passes through and doesn't switch the feature off",
      (begin; w.boom; false; rescue ArgumentError; true; end) && F.on?(:demo))
F.register(:fragile, :name => "Fragile", :default => :on)
H.around(:fragile, Widget.singleton_class, :make, :id => :fragile_make) { |orig| raise "hook bug" }
check("a hook error falls back to the original (class method)", Widget.make == :made)
check("...and switches its feature off for the session", !F.on?(:fragile) && F.failed?(:fragile) && F.state(:fragile) == :on)
check("...logged once to KIF's crash log", $log.count { |l| l.include?("CRASHLOG") && l.include?("Fragile") } == 1)
H.around(:demo, Widget, :secret, :id => :secret) { |orig| [orig.call, :hooked] }
check("private methods stay private", (begin; w.secret; false; rescue NoMethodError; true; end) && w.send(:secret) == [:secret, :hooked])
check("missing target is skipped, not raised", H.around(:demo, "NoSuchClass", :x) { } == false)
check("missing method is skipped", H.around(:demo, Widget, :nope) { } == false)
check("registry lists hooks", H.summary.any? { |s| s.start_with?("double: Widget#value") })
H.around(nil, Widget, :value, :id => :core_value) { |orig, x, **kw| raise "core bug" }
check("a failing core hook only turns itself off", w.value(2) == 4 && !H.registry.find { |e| e[:id] == "core_value" }[:active] && F.on?(:demo))

#---------------------------------------------------------------- Lifecycle + SaveStore
events = []
[:system_ready, :title_screen, :save_loaded, :new_game, :saved].each { |ev| R::Events.on(ev, :"t_#{ev}") { |c| events << ev } }
check("set_up_system still runs and emits system_ready", Game.set_up_system == :setup_done && events.include?(:system_ready))
check("load screen emits title_screen first", PokemonLoadScreen.new.pbStartLoadScreen == :title && events.last == :title_screen)
S = R::SaveStore
S.register(:demo, :version => 1)
check("no save data at the title", S.section(:demo).nil? && !S.loaded?)
SaveData.load_new_game_values
check("new game: empty section, new_game + save_loaded", S.section(:demo) == {} && events.last(2) == [:new_game, :save_loaded])
S.section(:demo)["coins"] = 5
path = SaveData::FILE_PATH
SaveData.save_to_file(path)
saved = stored(path)
check("saving writes :reloaded into the save", saved[:reloaded]["sections"]["demo"]["coins"] == 5 && events.last == :saved)
check("and a backup copy", File.file?(S.backup_path(path)))
# Load it back
SaveData.mark_values_as_unloaded
R::Events.emit(:title_screen)
SaveData.load_all_values(SaveData.read_from_file(path))
check("loading restores the section", S.section(:demo)["coins"] == 5)
# Saved with Kanto Reloaded off: the save has no :reloaded
stripped = saved.reject { |k, _| k == :reloaded }
File.delete(path) if File.file?(path)
$fake_files[path] = stripped
SaveData.mark_values_as_unloaded
SaveData.load_all_values(SaveData.read_from_file(path))
check("a save made with KR off gets its data back from the backup copy", S.section(:demo)["coins"] == 5 && File.read(R::Log.path).include?("restored the backup copy"))
# Another player's save in that slot
other = stripped.merge(:player => TrainerStub.new(999))
File.delete(path) if File.file?(path)
$fake_files[path] = other
SaveData.mark_values_as_unloaded
SaveData.load_all_values(SaveData.read_from_file(path))
check("another player's save doesn't take the backup copy", S.section(:demo) == {})
# Migration
S.register(:upgrade, :version => 2, :migrate => proc { |d, from| d.merge("from" => from, "new" => true) })
old = saved.dup
old[:reloaded] = Marshal.load(Marshal.dump(saved[:reloaded]))
old[:reloaded]["sections"]["upgrade"] = { "x" => 1 }
old[:reloaded]["versions"]["upgrade"] = 1
File.delete(path) if File.file?(path)
$fake_files[path] = old
SaveData.mark_values_as_unloaded
SaveData.load_all_values(SaveData.read_from_file(path))
check("old section data is upgraded once", S.section(:upgrade) == { "x" => 1, "from" => 1, "new" => true })

#---------------------------------------------------------------- Settings
ST = R::Settings
ST.register_page(:demo_page, :group => :general, :name => "Demo Page", :feature => :demo)
ST.register(:"demo.global", :page => :demo_page, :type => :slider, :min => 0, :max => 10, :default => 3)
ST.register(:"demo.rule", :page => :demo_page, :type => :toggle, :scope => :save, :default => false)
ST.register(:"demo.mode", :page => :demo_page, :type => :enum, :values => ["A", "B", "C"], :default => 0)
# (The game already started up above, so a newly registered bound setting
# reads the game's value straight away.)
$PokemonSystem = PokemonSystemStub.new
$PokemonSystem.textspeed = 3
ST.register(:"demo.speed", :page => :demo_page, :type => :slider, :min => 1, :max => 3, :default => 2,
  :bind => ST::Bind.system(:textspeed))
R::Events.emit(:title_screen)
check("a bound Global setting adopts the game's value the first time", ST.get(:"demo.speed") == 3)
check("defaults", ST.get(:"demo.global") == 3 && ST.get(:"demo.rule") == false)
check("Save settings are locked at the title", ST.lock_reason(:"demo.rule") == "Load a save to change this" && !ST.set(:"demo.rule", true))
check("Global settings change at the title", ST.set(:"demo.global", 7) && ST.get(:"demo.global") == 7)
check("enum steps stop at the ends", !ST.step(:"demo.mode", -1) && ST.step(:"demo.mode", 1) && ST.get(:"demo.mode") == 1)
check("bound setting writes into the game", ST.set(:"demo.speed", 1) && $PokemonSystem.textspeed == 1)
ST.flush
saved_json = J.parse(File.read(File.join(R::Paths.settings_dir, "Settings.json")))
check("Global settings saved to Settings.json", saved_json["values"]["demo.global"] == 7)
SaveData.mark_values_as_unloaded
SaveData.load_new_game_values
check("a new game unlocks Save settings", ST.set(:"demo.rule", true) && ST.get(:"demo.rule") == true)
SaveData.save_to_file(path)
check("Save settings go into the save's settings section", stored(path)[:reloaded]["sections"]["settings"]["demo.rule"] == true)
R::Events.emit(:title_screen)
check("back at the title, Save settings show their default", ST.get(:"demo.rule") == false)
SaveData.mark_values_as_unloaded
SaveData.load_all_values(SaveData.read_from_file(path))
check("loading the save brings its Save settings back", ST.get(:"demo.rule") == true)
F.set(:demo, :off)
check("a feature's settings hide while it is Off", !ST.visible?(:"demo.global") && ST.pages(:general).none? { |p| p[:id] == :demo_page })
F.set(:demo, :on)
check("...and show again when On", ST.visible?(:"demo.global"))
check("search finds settings by name", ST.search("rule") == [:"demo.rule"])
#---------------------------------------------------------------- feature rows
F.register(:demo, :name => "Demo", :default => :on, :page => :demo_page)
R::FeatureSwitches.boot
check("each feature gets a row on the Features page and its own page",
      ST.keys(:features).include?(:"features.demo") && ST.keys(:demo_page).first == :"demo_page.enabled")
ST.set(:"features.demo", false)
check("turning it off there switches the feature off", !F.on?(:demo) && F.state(:demo) == :off)
F.set(:demo, :on)
check("the row always shows the feature's real state", ST.get(:"features.demo") == true)
#---------------------------------------------------------------- Global Small Text
bmp = Bitmap.new(1, 1)
bmp.instance_variable_set(:@font, nil)
def bmp.font=(v); @font = v; end
def bmp.font; @font; end
pbSetSystemFont(bmp)
pf = KIF::PixelFont
check("Global Small Text is off by default: the system font and KIF's large pixel fonts as they are",
      ST.get(:"interface.global_small_text") == false && bmp.font == :system && pf.height(pf::TITLE) == 14 && pf.height(pf::ROW) == 14)
ST.set(:"interface.global_small_text", true)
pbSetSystemFont(bmp)
check("on: system text uses the small font", bmp.font == :small)
check("on: KIF Settings' and Battle Info's large pixel fonts draw at the small size",
      pf.height(pf::TITLE) == 12 && pf.height(pf::ROW) == 12 && pf.height(pf::TEXT) == 12)
check("...and their letters are cached as the small font, so switching back never mixes sizes",
      pf.glyph_bitmap(pf::ROW, 65, nil, nil) == [[:small, 22], 65])
ST.set(:"interface.global_small_text", false)
check("off again: the large pixel fonts come back", pf.height(pf::ROW) == 14 && pf.glyph_bitmap(pf::ROW, 65, nil, nil) == [[:narrow, 26], 65])
#---------------------------------------------------------------- Assets
assets_dir = File.join(USERDIR, "fake_mod")
FileUtils.mkdir_p(File.join(assets_dir, "Graphics", "Pictures"))
FileUtils.mkdir_p(File.join(assets_dir, "Audio", "SE"))
File.write(File.join(assets_dir, "Graphics", "Pictures", "kr_test.png"), "x")
File.write(File.join(assets_dir, "Audio", "SE", "kr_ding.ogg"), "x")
check("no shipped assets: paths untouched", Bitmap.new("Graphics/Pictures/kr_test").path == "Graphics/Pictures/kr_test")
R::Assets.send(:build_index, assets_dir)
check("a shipped graphic is loaded from the mod folder", Bitmap.new("Graphics\\Pictures\\KR_Test.png").path.end_with?("fake_mod/Graphics/Pictures/kr_test.png"))
check("other graphics are untouched", Bitmap.new("Graphics/Pictures/other").path == "Graphics/Pictures/other")
check("pbResolveBitmap finds it too", pbResolveBitmap("Graphics/Pictures/kr_test").to_s.end_with?("kr_test.png"))
Audio.se_play("Audio/SE/kr_ding", 80)
check("a shipped sound plays from the mod folder", $log.last.start_with?("SE ") && $log.last.end_with?("fake_mod/Audio/SE/kr_ding.ogg"))
R::Assets.send(:build_index)
check("bitmap sizes still work (Bitmap.new(w, h))", Bitmap.new(32, 32).path == 32)

#---------------------------------------------------------------- KIF Settings bridge + Reloaded Settings toggle
KB = R::KIFBridge
KB.refresh_section          # picks up the demo settings registered above, after boot
sections = KIF::SettingsScreen::SECTIONS
check("Kanto Reloaded is the first section in KIF's sidebar", sections.first[0] == :kanto_reloaded && sections.first[1] == "Kanto Reloaded")
groups = sections.first[3]
interface = groups.find { |h, _| h == "Interface" }
check("one heading per Kanto Reloaded page, rows by name (Interface: #{interface && interface[1].first(3).inspect}...)",
      interface && interface[1].first == "Global Small Text" && !interface[1].include?("Reloaded Settings"))
check("Reloaded Settings is on by default, and out of presets", KB.improved? && !ST.definition(:"systems.reloaded_settings")[:preset])
entry = proc { |key| KIF::Options.entries(:kanto_reloaded).map { |scope, b| [scope, b.call] }.find { |_, o| o && o.kr_key == key } }
scope, gst = entry.call(:"interface.global_small_text")
check("each setting is one of KIF's options, scope included", gst.is_a?(EnumOption) && gst.values == ["Off", "On"] && scope == :global)
gst.set(1)
check("changing it in KIF Settings changes the Kanto Reloaded setting", ST.get(:"interface.global_small_text") == true && gst.get == 1)
gst.set(0)
check("KIF works out its default from Kanto Reloaded (Off)", KIF::SettingsScreen.defaults_for([gst])[gst] == 0)
_, slider = entry.call(:"demo.global")
check("sliders map through KIF's slider (value minus its start)", slider.is_a?(SliderOption) && slider.get == ST.get(:"demo.global") - 0)
F.set(:demo, :off)
KIF::Options.entries(:kanto_reloaded).each { |_, b| b.call }
check("a hidden setting has no row (its feature is Off)", entry.call(:"demo.global").nil?)
F.set(:demo, :on)
_, rule = entry.call(:"demo.rule")
check("a Save setting's row is KIF's save scope", KIF::Options.entries(:kanto_reloaded).any? { |sc, b| sc == :save && (o = b.call) && o.kr_key == :"demo.rule" })
R::Events.emit(:title_screen)
check("a locked setting says why in its description", rule.description.include?("Locked: Load a save to change this"))
SaveData.mark_values_as_unloaded
SaveData.load_new_game_values
names = KIF::SettingsScreen::SECTIONS.first[3].flat_map { |_, n| n }
check("names are unique (KIF places rows by name), plain names shown under their heading",
      names.uniq.length == names.length && KIF::SettingsScreen::RENAMES.values.include?("Demo"))
KifSettingsScreen.new.rebuild
check("the section follows features each time KIF Settings rebuilds", $log.include?("KIF_REBUILD"))
module Reloaded; class SettingsScreen < ::KifSettingsScreen; end; end
check("Options opens the improved screen while Reloaded Settings is on", KifSettingsScreen.new(true, :mods).is_a?(R::SettingsScreen))
ST.set(:"systems.reloaded_settings", false)
check("...and KIF Settings as it ships while it's off", KifSettingsScreen.new(true).instance_of?(KifSettingsScreen))
ST.set(:"systems.reloaded_settings", true)
check("the improved screen's fallback opens KIF Settings as it ships",
      R::KIFBridge.vanilla { KifSettingsScreen.new(true).instance_of?(KifSettingsScreen) } && R::KIFBridge.improved?)
check("the improved screen needs KIF's pixel UI (skipped here, nothing failed)", R::Bootstrap.failures.empty?)
KifSettingsScreen.new.rebuild
first = KIF::SettingsScreen::SECTIONS.first[3].first
check("Reloaded Systems is the first heading, Reloaded Settings its first row", first[0] == "Reloaded Systems" && first[1].first == "Reloaded Settings")
check("Header, Settings and Cursor Color start at Theme",
      [:"interface.header_color", :"interface.settings_color", :"interface.cursor_color"].all? { |k| ST.default(k) == 0 })

# A value stored by an older Settings.json is dropped once for a setting with :reset
ST.flush
gpath = ST.send(:global_path)
gdata = J.parse(File.read(gpath))
gdata["schema"] = 1
gdata["values"]["demo.kept"] = true
gdata["values"]["demo.reset"] = true
File.write(gpath, J.generate(gdata))
ST.send(:load_global)
ST.register(:"demo.kept", :page => :interface, :type => :toggle, :default => false)
ST.register(:"demo.reset", :page => :interface, :type => :toggle, :default => false, :reset => 2)
check(":reset drops a value an older Settings.json stored; others are kept", ST.get(:"demo.kept") == true && ST.get(:"demo.reset") == false)
ST.flush
check("...once: the file is written as the new schema", J.parse(File.read(gpath))["schema"] == R::Settings::SCHEMA_VERSION)

#---------------------------------------------------------------- window frames
WF = R::WindowFrames
gvals = ST.definition(WF::GLOBAL)[:values]
check("Global Frame: Theme, RLD Clear, PIF Clear and Opaque, then RLD 1-30 light and dark (#{gvals.length})",
      gvals.first(4) == ["Theme", "RLD Clear", "PIF Clear", "PIF Opaque"] && gvals.length == 64 && gvals.last == "RLD 30 Dark")
check("Theme Mode: Dark, Glass, Light, Frost, after Theme (#{ST.definition(WF::MODE)[:values].inspect})",
      ST.definition(WF::MODE)[:values] == ["Dark", "Glass", "Light", "Frost"] && ST.get(WF::MODE) == 0 &&
      ST.keys(:interface).index(WF::MODE) == ST.keys(:interface).index(:"interface.theme") + 1)
svals = ST.definition(WF::SPEECH)[:values]
check("Speech Frame: Theme, PIF's speech frames by name, then RLD Clear and the RLD frames (#{svals.first(6).inspect}, #{svals.length})",
      svals.first(6) == ["Theme", "HGSS 1", "HGSS 2", "Platinum 18", "RLD Clear", "RLD 1"] && svals.length == 65)
ST.set(WF::SPEECH, svals.index("RLD 4 Dark"))
check("...an RLD frame as the text box (#{MessageConfig.speech_frame})", MessageConfig.speech_frame.to_s.end_with?("RLD Choice 4a.png"))
ST.reset(WF::SPEECH)
check("both start on Theme, next to the colours on Interface",
      ST.get(WF::GLOBAL) == 0 && ST.get(WF::SPEECH) == 0 && ST.definition(WF::GLOBAL)[:page] == :interface)
skins = File.join(KIF_ROOT, "Mods/KantoReloaded/Graphics/Windowskins")
looks = WF::THEME_MODES.map { |_label, word| word }
ours = R::Palette::THEME_NAMES.flat_map { |n| looks.map { |look| look ? "Theme #{look} #{n}" : "Theme #{n}" } } +
       WF.global_choices.map { |c| c[1] }.select { |s| s.is_a?(String) && !s.start_with?("default_") }
missing = ours.reject { |s| File.file?(File.join(skins, s + ".png")) }
check("the mod ships every frame of its own (each Theme Mode for every theme, the RLD frames: #{ours.length}) (#{missing.inspect})", missing.empty?)
ST.set(:"interface.theme", 7)
ST.set(WF::MODE, 3)
check("Theme Mode picks the Theme frame's look (Sakura, Frost: #{WF.global_skin})",
      WF.global_skin == "Theme Frost Sakura" && MessageConfig.system_frame.to_s.end_with?("Theme Frost Sakura.png"))
check("...and Speech Frame's Theme follows it (#{WF.speech_skin})", WF.speech_skin == "Theme Frost Sakura")
ST.reset(WF::MODE)
ST.reset(:"interface.theme")
ST.set(:"interface.theme", 4)
check("Theme is the Theme's frame (Kanto Red: #{WF.global_skin})", WF.global_skin == "Theme Kanto Red")
check("...the game gets the mod's file for it (#{MessageConfig.system_frame})", MessageConfig.system_frame.to_s.end_with?("Graphics/Windowskins/Theme Kanto Red.png"))
check("...and its windows open with it (#{MessageConfig.pbDefaultSystemFrame})", MessageConfig.pbDefaultSystemFrame.to_s.end_with?("Theme Kanto Red.png"))
ST.set(WF::GLOBAL, gvals.index("RLD 7 Dark"))
check("Speech Frame's Theme uses the Global Frame (#{WF.speech_skin})", WF.speech_skin == "RLD Choice 7a" && MessageConfig.speech_frame.to_s.end_with?("RLD Choice 7a.png"))
ST.reset(WF::GLOBAL)
ST.reset(:"interface.theme")

#---------------------------------------------------------------- what mod.json sets in KIF
mod = J.parse(File.read(File.join(KIF_ROOT, "Mods/KantoReloaded/mod.json"), :encoding => "UTF-8"))
check("mod.json locks KIF's Auto Battle module Off", mod["modules"] == { "auto_battle" => "off" })
check("...and Battle Info Off, and KIF's Save Backups on Infinite (Backup Cap takes over)",
      mod["locks"] == { "cody_battleinfo" => 0, "savebackups" => 0 })
bi = File.read(File.join(KIF_ROOT, "Data/Scripts/990_KIF/ZZ_Cody/C-BATTLE-03_BattleInfo/BattleInfo.rb"), :encoding => "UTF-8")
check("...which is still Battle Info's setting in this KIF (0 = Off)",
      bi.include?("KIF::Options.define(:cody_battleinfo") && bi =~ /EnumOption\.new\(_INTL\("Battle Info"\), \[_INTL\("Off"\)/)
mods_rb = File.read(File.join(KIF_ROOT, "Data/Scripts/990_KIF/000_Core/011_KIF_Modules.rb"), :encoding => "UTF-8")
ab = mods_rb[/:auto_battle\s*=>\s*\[.*?%w\[([^\]]*)\]/m, 1].to_s.split
check("...which is Auto-Battle (F-BATTLE-02) and Self-Battle (F-PC-03) in this KIF (#{ab.inspect})",
      ab.include?("F-BATTLE-02") && ab.include?("F-PC-03"))

#---------------------------------------------------------------- fixes
check("the command colours fix is on", R::Fixes.on?(:command_text_colours))
menu = Window_PauseMenuCommand.new(["Plain", "  <icon=menuIcons/BAG>  Bag"])
menu.baseColor = Color.new(80, 80, 88)          # a light frame's dark text
menu.shadowColor = Color.new(160, 160, 168)
menu.drawItem(0, 2, nil)
menu.drawItem(1, 2, nil)
check("a pause menu icon row is drawn in the window's colours (#{menu.drawn[1]})",
      menu.drawn[1] == shadowctag(menu.baseColor, menu.shadowColor) + "  <icon=menuIcons/BAG>  Bag")
check("...a plain row as it was, and the rows themselves aren't changed",
      menu.drawn[0] == "Plain" && menu.commands == ["Plain", "  <icon=menuIcons/BAG>  Bag"])
check("the EBDX command cursor fix is on", R::Fixes.on?(:ebdx_command_cursor))
w = CommandWindowEBDX.new([0, 1, 2, 3, 50])     # Battle Info's INFO is 50
w.index = 50
check("the cursor memory's INFO value (50) puts the cursor on INFO (#{w.index})", w.index == 4)
w.index = 2
check("...a real position stays", w.index == 2)
w = CommandWindowEBDX.new([0, 1, 3])             # EBDX metrics leaving PARTY out
w.index = 3
check("...a value whose command moved goes to it (RUN at 2: #{w.index})", w.index == 2)
w.index = 9
check("...and one with no command goes to the first", w.index == 0)
check("a fix written against a method's source recognises it (PIF's fight menu)", R::Fixes.source?(PokeBattle_Scene, :pbFightMenu, 1739628443))
check("...and a fix written for other source doesn't apply", !R::Fixes.source?(PokeBattle_Scene, :pbFightMenu, 1))
real = File.join(KIF_ROOT, "Data/Scripts/011_Battle/005_Battle scene/008_Scene_Commands.rb")
check("a game script is found by its name alone", File.expand_path(R::Paths.script_file("008_Scene_Commands.rb").to_s) == File.expand_path(real))
eval(File.read(real), TOPLEVEL_BINDING, "008_Scene_Commands.rb")      # as the game loads it: only the name
check("...so a fix still recognises a method the game loaded that way (#{PokeBattle_Scene.instance_method(:pbFightMenu).source_location[0]})",
      R::Fixes.source?(PokeBattle_Scene, :pbFightMenu, 1739628443))

puts "--- log tail"
puts File.read(R::Log.path).lines.last(6)
puts($failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED")
