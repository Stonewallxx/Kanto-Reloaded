# encoding: utf-8
# Offline preview of the Save Checker's screens on the preview tool's
# stand-ins (Tools/UIPreview/preview.rb), with real save files written as PIF
# writes them: the report card, Missing Content and its fixes, Mod Data with
# a removed mod's objects and Make It Loadable, the Inspector, a backup, and
# the ways in from the Save Manager and the Load Screen.
# Usage: ruby   Tools/Tests/save_check_preview.rb "<KIF Beta>" <work dir with metrics.json>
#        python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>
PREVIEW_SETUP_ONLY = true
load File.join(ARGV[0], "Mods/KantoReloaded/Tools/UIPreview/preview.rb")
require "fileutils"
SC = Reloaded::SaveCheck
check("the Save Checker's screens load in the preview", defined?(Reloaded::SaveCheckScreen) && defined?(Reloaded::SaveInspector))

#---------------------------------------------------------------- the game, as far as the checker asks it
module GameData
  class Species
    DATA = {}
    attr_reader :name
    def initialize(name); @name = name; end
    def self.get(id); DATA[id] || raise("Unknown ID #{id}"); end
  end
  class Item; DATA = {}; end
  class Move; DATA = {}; end
  class Ability; DATA = {}; end
end
%w[CHARMANDER PIKACHU BULBASAUR SQUIRTLE ODDISH CLEFAIRY].each { |s| GameData::Species::DATA[s.to_sym] = GameData::Species.new(s.capitalize) }
%w[POTION POKEBALL].each { |i| GameData::Item::DATA[i.to_sym] = true }
%w[TACKLE EMBER WATERGUN].each { |m| GameData::Move::DATA[m.to_sym] = true }
eval(<<~'RUBY', TOPLEVEL_BINDING, "001_Pokemon.rb", 1)
  class Pokemon
    attr_accessor :species, :name, :item, :moves, :ability, :personalID, :level
    def initialize(species, level = 5, name = nil)
      @species = species; @level = level; @name = name; @item = nil
      @moves = [Pokemon::Move.new(:TACKLE)]; @ability = nil; @personalID = rand(2**30)
    end
    class Move
      attr_accessor :id
      def initialize(id); @id = id; end
    end
  end
  class Player
    attr_accessor :name, :party, :last_time_saved, :id
    def initialize(name); @name = name; @party = []; @id = 4242; @last_time_saved = Time.now - 600; end
  end
  class PokemonBox
    attr_reader :pokemon
    def initialize(name); @name = name; @pokemon = Array.new(30); end
  end
  class PokemonStorage
    attr_reader :boxes
    def initialize; @boxes = (1..4).map { |i| PokemonBox.new("Box #{i}") }; end
  end
  class PokemonBag
    attr_reader :pockets
    def self.pocketNames; ["", "Items", "Medicine", "Poké Balls", "TMs & HMs", "Berries", "Mail", "Battle Items", "Key Items"]; end
    def initialize; @pockets = Array.new(9) { [] }; end
  end
  class PokemonGlobalMetadata
    attr_accessor :daycare
  end
  [:player, :bag, :storage_system, :global_metadata].each do |id|
    SaveData.register(id) do
      save_value { nil }
      load_value { |v| v }
    end
  end
RUBY
SAVES = File.join(USERDIR, "saves")
FileUtils.mkdir_p(SAVES)
module SaveData
  SAVE_DIR = SAVES
  MANUAL_SLOTS = ("A".."H").map { |l| "File #{l}" }
  AUTO_SLOTS = ["Auto 1", "Auto 2"]
  def self.get_full_path(slot); File.join(SAVE_DIR, "#{slot}.rxdata"); end
  def self.get_data_from_file(path); File.open(path, "rb") { |f| Marshal.load(f) }; end
end
MODS = File.join(USERDIR, "Mods")
SC::ModData::Search.root = MODS

def mon(species, level = 10, name = nil); Pokemon.new(species, level, name); end
def save_data(party: [], boxes: {}, bag: {}, reloaded: nil, extra: {})
  player = Player.new("Red")
  player.party = party
  storage = PokemonStorage.new
  boxes.each { |(b, s), pk| storage.boxes[b].pokemon[s] = pk }
  b = PokemonBag.new
  bag.each { |pocket, items| b.pockets[pocket].concat(items) }
  global = PokemonGlobalMetadata.new
  global.daycare = [[nil, 0], [nil, 0]]
  return { :player => player, :bag => b, :storage_system => storage, :global_metadata => global }.merge(:reloaded => reloaded).merge(extra)
end
def write_save(slot, data)
  path = SaveData.get_full_path(slot)
  File.binwrite(path, Marshal.dump(data))
  path
end

# File A: two notes (a part to upgrade, and what's missing)
Reloaded::SaveStore.register(:shiny_log, :version => 3, :migrate => proc { |d, _f| d })
kr = { "schema" => 1, "versions" => { "shiny_log" => 2 }, "sections" => { "shiny_log" => { "seen" => 12 }, "settings" => { "theme" => 1 } } }
file_a = write_save("File A", save_data(party: [mon(:CHARMANDER), mon(:PIKACHU), mon(:FUECOCO, 9)],
                                        boxes: { [3, 6] => mon(:SPRIGATITO, 12) }, bag: { 8 => [[:MEGA_RING, 1]] },
                                        reloaded: kr, extra: { :mp_data => { "wins" => 3 } }))
Reloaded::Saves.set_tag("File A", "Red")

def sc; $sc; end
Reloaded::SaveCheckScreen.prepend(Module.new { def main; $sc = self; super; end })
def drive_sc(label, queue, path, **opts)
  Input.queue = queue.dup
  result = Reloaded::SaveCheckScreen.open(path, **opts)
  check("#{label}: opened and closed", true)
  result
rescue QueueEmpty => e
  check("#{label}: #{e.message}", false)
rescue Exception => e
  check("#{label}: #{e.class}: #{e.message} #{e.backtrace.first(4).inspect}", false)
end
def report; sc.report; end
def shown?(word); $pf_texts.values.flatten.any? { |s| s.include?(word) }; end
$pf_texts = Hash.new { |h, k| h[k] = [] }
Reloaded::Pixel.singleton_class.prepend(Module.new { def text(b, x, y, w, h, str, *r); $pf_texts[b.id] << str.to_s; super; end })
Bitmap.prepend(Module.new { def clear(*a); $pf_texts.delete(id); super; end })

#---------------------------------------------------------------- the report card and Missing Content
changed = drive_sc("File A", [
  dmp("sc_01_report"),
  at { check("the report card: Healthy, 2 Notes, the six checks (#{report.verdict}; #{report.checks.map { |c| c.state }.inspect})",
             report.verdict == "Healthy, 2 Notes" && report.checks.map(&:id) == [:file, :kr, :upgrades, :plain, :missing, :mods] &&
             report.checks.count { |c| c.state == :note } == 2) },
  at { check("...Upgrades says which part (#{report.checks[2].line})", report.checks[2].line == "Shiny Log: Version 2 to 3.") },
  I::USE,
  dmp("sc_02_file_details"),
  I::USE,
  I::DOWN, I::DOWN, I::DOWN, I::DOWN,
  I::USE,
  dmp("sc_03_missing"),
  at { check("A on Missing Content: its page, each with where it is (#{report.missing.map(&:where).inspect})",
             sc.mode == :missing && report.missing.map(&:where) == ["Party, slot 3", "Box 4, slot 7", "Bag: Key Items"]) },
  I::DOWN, I::USE,
  dmp("sc_04_fix_menu"),
  I::DOWN, I::USE,
  at { check("A on a row changes its fix: Sprigatito to Remove", report.missing[1].fix == :remove) },
  dmp("sc_05_missing_changed"),
  I::A,
  dmp("sc_06_fix_confirm"),
  I::USE,
  dmp("sc_07_fixed"),
  at { check("X: Fix All Safely, then the report again (#{report.verdict})", report.missing.empty? && report.verdict == "Healthy, 1 Note") },
  I::USE,
  at { check("...back on the report card, Missing Content fixed", sc.mode == :report && report.checks[4].state == :ok) },
  I::DOWN, I::DOWN, I::DOWN, I::DOWN, I::DOWN, I::DOWN,
  at { check("Down from the last check: the buttons", sc.send(:on_button?)) },
  I::RIGHT, I::USE,
  dmp("sc_08_report_saved"),
  I::USE,
  I::BACK
], file_a, :slot => "File A")
check("a fix says the save changed (the Save Manager reads it again)", changed == true)
after = File.open(file_a, "rb") { |f| Marshal.load(f) }
check("the save as fixed: Fuecoco kept aside, Sprigatito gone, the Mega Ring kept",
      after[:player].party.length == 2 && after[:storage_system].boxes[3].pokemon[6].nil? &&
      after[:reloaded]["sections"]["save_check"]["kept"].map { |k| k["id"] }.sort == ["FUECOCO", "MEGA_RING"])
check("...and a report was saved", !SC.newest_report("File A").nil?)

#---------------------------------------------------------------- a removed mod's objects, Mod Data, Make It Loadable
FileUtils.mkdir_p(File.join(MODS, "MegaMod"))
File.write(File.join(MODS, "MegaMod", "mega.rb"), "module MegaMod\n  class Data\n  end\nend\nSaveData.register(:mega_mod) do\nend\n")
module MegaMod
  class Data
    def initialize; @level = 3; @seen = [:CHARIZARD, :VENUSAUR]; end
  end
end
file_b = write_save("File B", save_data(party: [mon(:BULBASAUR)], reloaded: { "schema" => 1, "versions" => {}, "sections" => { "settings" => {} } },
                                        extra: { :mega_mod => { "data" => MegaMod::Data.new, "ring" => true }, :mp_data => { "wins" => 3 } }))
Object.send(:remove_const, :MegaMod)
$DEBUG = true
drive_sc("File B", [
  dmp("sc_10_report_problems"),
  at { check("a removed mod's objects: problems with the file and Mod Data (#{report.verdict})",
             report.state == :problem && report.checks[0].state == :problem && report.checks[5].state == :problem) },
  I::DOWN, I::DOWN, I::DOWN, I::DOWN, I::DOWN, I::USE,
  dmp("sc_11_mods"),
  at { check("Mod Data: MegaMod needed to load (off), the others safe (#{report.mods.map { |m| [m.name, m.needed] }.inspect})",
             sc.mode == :mods && report.mods[0].name == "MegaMod" && report.mods[0].needed && report.mods.count(&:needed) == 1) },
  at { check("...its first button is Make It Loadable", sc.send(:buttons)[0][0] == :make_loadable) },
  I::USE,
  dmp("sc_12_mod_details"),
  at { check("A on a mod: what it keeps in the save (#{sc.send(:rows).map { |l| l[1] }.inspect})",
             sc.mode == :mod && sc.send(:rows).map { |l| l[1] } == [":mega_mod", "MegaMod::Data"]) },
  I::USE,
  dmp("sc_13_inspector"),
  I::USE,
  dmp("sc_14_inspector_inside"),
  I::BACK, I::BACK,
  at { check("the Inspector took its stand-ins away", !defined?(MegaMod)) },
  I::A,
  dmp("sc_15_make_loadable"),
  I::LEFT, I::USE,
  dmp("sc_16_loadable"),
  at { check("Make It Loadable: the file check is fine now (#{report.checks[0].line})", report.checks[0].state == :ok) },
  I::USE,
  I::BACK, I::BACK
], file_b, :slot => "File B")
$DEBUG = false
check("File B loads without MegaMod now", (File.open(file_b, "rb") { |f| Marshal.load(f) }.key?(:mp_data) rescue false))

#---------------------------------------------------------------- a backup
bdir = File.join(SAVES, "backups", "File B")
FileUtils.mkdir_p(bdir)
bk = File.join(bdir, "File B_20261019120000.rxdata")
FileUtils.cp(file_b, bk)
drive_sc("a backup", [
  dmp("sc_17_backup"),
  at { check("a backup: checked as File B's, Fix Safely faded", report.backup && report.slot == "File B" && sc.send(:off_button?, :fix)) },
  I::A,
  at { check("...X says it's a backup", true) },
  I::USE,
  I::BACK
], bk, :slot => "File B", :backup => true)

#---------------------------------------------------------------- the ways in
$sc = nil
Input.queue = [I::USE, I::DOWN, I::DOWN, dmp("sc_20_manager_options"), I::USE, at { check("Save Manager > Check This Save opens the Save Checker on File A", sc && report.slot == "File A") },
               I::BACK, I::BACK]
begin
  Reloaded::SaveManagerScreen.open
rescue Exception => e
  check("Save Manager: #{e.class}: #{e.message} #{e.backtrace.first(3).inspect}", false)
end
$sc = nil
Input.queue = [I::JUMPDOWN, *[nil] * 3, I::A, at { check("Backups tab, X: the Save Checker on the backup", sc && report.backup) }, I::BACK, I::BACK]
begin
  Reloaded::SaveManagerScreen.open(false, :active, "File B")
rescue Exception => e
  check("Backups tab: #{e.class}: #{e.message} #{e.backtrace.first(3).inspect}", false)
end
$sc = nil
COMMANDS = ["File A", "New Game", "Options", "Quit Game"].freeze
data = File.open(file_a, "rb") { |f| Marshal.load(f) }
v = Reloaded::LoadScreen::View.new(COMMANDS.dup, true, data[:player], 0, 0)
v.open
Input.queue = [I::X, *[[:held, I::X]] * 20, at { check("Load Screen, hold Y on Continue: the Save Checker", sc && report.slot == "File A") }, I::BACK, I::RIGHT]
begin
  v.choose(COMMANDS.dup, 0)
rescue Exception => e
  check("Load Screen: #{e.class}: #{e.message} #{e.backtrace.first(3).inspect}", false)
end
v.close(false)

#---------------------------------------------------------------- on a phone: Copy Instead
ENV["ANDROID_ROOT"] = "/system"            # what an Android player has
Reloaded::Runtime.reset
Input.clipboard = ""
$shell = []                                # nothing may open File Explorer here
Reloaded::SaveCheckScreen.prepend(Module.new { def system(*a); $shell << a; true; end })
$asked = nil
$told = nil
Reloaded::Dialogs.singleton_class.prepend(Module.new do
  def buttons_dialog(scene, title, text, buttons, choice = 0, segments = nil)
    return super unless $phone_dialogs
    $asked = [title, buttons]
    return 0                               # the first button
  end

  def notice(scene, title, text, ok = nil)
    return super unless $phone_dialogs
    $told = [title, text]
    return nil
  end
end)
$phone_dialogs = true
sc.send(:save_report)
$phone_dialogs = false
check("on a phone, Report Saved offers Copy the Path (#{$asked.inspect})", $asked && $asked[1] == ["Copy the Path", "OK"])
check("...the report's full path copied, and Copied said (#{File.basename(Input.clipboard)})",
      File.file?(Input.clipboard) && $told && $told[0] == "Copied")
check("...and nothing tried to open File Explorer", $shell.empty?)
ENV.delete("ANDROID_ROOT")
Reloaded::Runtime.reset

errors = File.read(Reloaded::Log.path).lines.grep(/ERROR/)
check("no errors in the log (#{errors.length})", errors.empty?)
errors.first(6).each { |l| puts "  " + l }
puts $failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED"
exit($failed ? 1 : 0)
