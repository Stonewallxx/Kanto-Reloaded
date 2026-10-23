# encoding: utf-8
# Checks Bug Reports outside the game: Recent Steps (on stand-in battles and
# map changes hooked as in the game), this session's errors, the zip and
# everything in it (read back and checked), the user name taken out, the
# mod's Bug Reports folder, the old files moved over from the save folder,
# After a Crash naming the mod a crash came from
# (and PIF's own box when ours can't show), and the next start's offer.
# Usage: ruby Tools/Tests/bug_report_test.rb "<KIF Beta>" <empty temp folder>
require "fileutils"
require "json"
require "zlib"
require "stringio"

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

# A home folder of the test's own (its name is taken out of the report)
HOME = File.join(USERDIR, "home", "TestUser")
FileUtils.mkdir_p(HOME)
ENV["USERPROFILE"] = HOME
ENV["HOME"] = HOME
ENV["USERNAME"] = "TestUser"
ENV.delete("OneDrive")

# What an earlier Kanto Reloaded kept in the save folder: all but the save
# things move to the mod folder (here, the test's) when it boots
OLD = File.join(USERDIR, "Kanto Reloaded")
NEW = File.join(USERDIR, "KantoReloaded")
%w[Dev Logs/Save\ Checks Bug\ Reports Saves].each { |d| FileUtils.mkdir_p(File.join(OLD, d)) }
File.write(File.join(OLD, "Controls.json"), '{"old":true}')
File.write(File.join(OLD, "Dev", "Hook Check.json"), "{}")
File.write(File.join(OLD, "Logs", "Save Checks", "File A 2026-10-19 14-02.md"), "# Save Check: File A\n")
File.write(File.join(OLD, "Bug Reports", "KR Bug Report 2026-10-19 20-08.zip"), "PK")
File.write(File.join(OLD, "Save Notes.json"), "{}")
File.write(File.join(OLD, "Saves", "File A.rxdata.kr"), "kr")
FileUtils.mkdir_p(File.join(NEW, "Settings"))
File.write(File.join(NEW, "Settings", "Timing Sessions.json"), '{"newer":true}')
File.write(File.join(OLD, "Timing Sessions.json"), '{"older":true}')
File.utime(Time.now - 3600, Time.now - 3600, File.join(OLD, "Timing Sessions.json"))

load File.join(KIF_ROOT, "Mods/KantoReloaded/Tools/Tests/test_stubs.rb")
module SaveData
  SAVE_DIR = USERDIR
  MANUAL_SLOTS = ("A".."H").map { |l| "File #{l}" }
  AUTO_SLOTS = ["Auto 1", "Auto 2"]
  def self.get_full_path(slot); File.join(SAVE_DIR, "#{slot}.rxdata"); end
  def self.get_data_from_file(path); File.open(path, "rb") { |f| Marshal.load(f) }; end
end

# KIF Beta: its version, its Logs folder, its mods (one that didn't load)
LOGS = File.join(USERDIR, "GameLogs")
FileUtils.mkdir_p(LOGS)
ModEntry = Struct.new(:id, :name, :path, :on) do
  def enabled?; on; end
end
MODS = File.join(USERDIR, "Mods")
FileUtils.mkdir_p(File.join(MODS, "HardTrainers"))
File.write(File.join(MODS, "HardTrainers", "mod.json"), JSON.generate("name" => "Hard Trainers+", "version" => "1.4", "author" => "Ash", "support" => "https://example.com/hard-trainers"))
module KIF
  PORT_VERSION = "0.21.59"
  module Paths
    def self.log(name); File.join(LOGS, name); end
  end
  module Mods
    def self.entries
      [ModEntry.new("HardTrainers", "Hard Trainers+", File.join(MODS, "HardTrainers"), true),
       ModEntry.new("BrokenMod", "Broken Mod", File.join(MODS, "BrokenMod"), true)]
    end
    def self.status
      { "HardTrainers" => { :loaded => true }, "BrokenMod" => { :loaded => false, :error => "NameError in broken.rb" } }
    end
  end
end

# PIF: battles, the map scene, its crash message
class PokeBattle_Battle
  attr_accessor :opponent, :decision, :turnCount
  def initialize(opponent); @opponent = opponent; @decision = 0; @turnCount = 0; end
  def pbStartBattle; @turnCount = 3; @decision = 1; :done; end
end
TrainerName = Struct.new(:name)
class Scene_Map
  def transfer_player(*_a); $game_map = MapNow.new(7); end
end
MapNow = Struct.new(:map_id)
def pbGetMapNameFromId(id); { 5 => "Cerulean City", 7 => "Route 24" }[id] || "Map #{id}"; end
def pbPrintException(e)
  File.open(File.join(USERDIR, "errorlog.txt"), "ab") { |f| f.write("Exception: #{e.class}\nMessage: #{e.message}\n") }
  print("PIF's box: #{e.message}")
end

load File.join(KIF_ROOT, "Mods/KantoReloaded/Bootstrap.rb")
R = Reloaded
BR = R::BugReport
check("Kanto Reloaded boots with Bug Reports (#{R::Bootstrap.status}, #{R::Bootstrap.failures.inspect})", R::Bootstrap.status == :ready)
check("the old files moved to the mod folder: Settings, Logging and Bug Reports",
      File.read(File.join(NEW, "Settings", "Controls.json")) == '{"old":true}' && File.file?(File.join(NEW, "Settings", "Hook Check.json")) &&
      File.file?(File.join(NEW, "Logging", "Save Checks", "File A 2026-10-19 14-02.md")) &&
      File.file?(File.join(NEW, "Bug Reports", "KR Bug Report 2026-10-19 20-08.zip")))
check("...the newer one kept when both places had it", File.read(File.join(NEW, "Settings", "Timing Sessions.json")) == '{"newer":true}')
check("...and the save folder keeps the save things only (#{Dir.children(OLD).sort.join(", ")})",
      Dir.children(OLD).sort == ["Save Notes.json", "Saves"] && File.file?(File.join(OLD, "Saves", "File A.rxdata.kr")))
check("...once: nothing left to move", R::Paths.migrate == 0)
check("Make a Bug Report: a button under its own Bug Report heading in the Kanto Reloaded section",
      R::Settings.page(:bug_report)[:name] == "Bug Report" && R::Settings.definition(:"bug_report.make")[:type] == :button)
check("the hooks: battles, maps and the crash (#{R::Hooks.registry.map { |e| e[:id] }.grep(/trail|crash/).inspect})",
      %w[trail_battles trail_maps bug_report_crash].all? { |id| R::Hooks.registry.any? { |e| e[:id] == id } })

#---------------------------------------------------------------- Recent Steps
BR::Trail.clear
PokeBattle_Battle.new([TrainerName.new("Brock")]).pbStartBattle
Scene_Map.new.transfer_player
R::Events.emit(:saved, :path => SaveData.get_full_path("File A"))
lines = BR::Trail.lines
check("a battle's start and end, a map change and a save go on Recent Steps (#{lines.inspect})",
      lines.length == 4 && lines[0].include?("Battle  Started: Brock") && lines[1].include?("Ended: Brock, Won after 3 turns") &&
      lines[2].include?("Map  Route 24") && lines[3].include?("Save  File A"))
check("...the last place the player was", BR::Trail.last_map == "Route 24")
FactoryNow = Struct.new(:map)
$MapFactory = FactoryNow.new(MapNow.new(5))
R::Events.emit(:save_loaded, {})
check("loading a save: the load and the map it starts on (#{BR::Trail.lines.last(2).inspect})",
      BR::Trail.lines[-2].include?("Load") && BR::Trail.lines[-1].include?("Map  Cerulean City"))
R::Log.error("Something broke in a test", :tests)
check("an error goes on Recent Steps, and on this session's errors", BR::Trail.lines.last.include?("Error  Something broke") &&
      R::Log.errors.any? { |_t, _c, text| text == "Something broke in a test" })
150.times { |i| BR::Trail.add(:menu, "Menu #{i}") }
check("only the last 100 are kept", BR::Trail.steps.length == 100 && BR::Trail.lines.last.include?("Menu 149"))
quiet = BR::Bundle.quiet_errors
check("quiet errors: Kanto Reloaded's and a mod that didn't load (#{quiet.length})",
      quiet.any? { |q| q.include?("Something broke") } && quiet.any? { |q| q.start_with?("Broken Mod: failed") })

#---------------------------------------------------------------- the report
Player = Struct.new(:name, :id, :party)
File.binwrite(SaveData.get_full_path("File A"), Marshal.dump({ :player => Player.new("Red", 1, []) }))
File.write(File.join(LOGS, "KIF_log.txt"), "KIF session\nsaves in #{HOME}\\AppData\\Roaming\\KIF\nD:\\Games\\TestUser\\KIF Beta\n")
File.write(File.join(LOGS, "KIF_errorlog.txt"), "an old crash\n")
File.write(File.join(USERDIR, "errorlog.txt"), "PIF errorlog\n", :mode => "a")
File.write(File.join(R::Paths.settings_dir, "Settings.json"), JSON.generate("interface.theme" => 1))
shot = File.join(USERDIR, "shot.png")
File.binwrite(shot, "\x89PNG\r\n\x1A\nfake".b)
note = "Game froze after Gyarados used Thrash in a double battle."
result = BR::Bundle.make(:note => note, :screenshot => shot, :save => "File A")

# the zip, read back (central directory, deflate, CRC)
def unzip(path)
  data = File.binread(path)
  eocd = data.rindex([0x06054b50].pack("V"))
  count, _size, start = data[eocd + 10, 10].unpack("vVV")
  out = {}
  pos = start
  count.times do
    _sig, _v1, _v2, _flags, method, _t, _d, crc, csize, usize, nlen, elen, clen = data[pos, 34].unpack("VvvvvvvVVVvvv")
    local = data[pos + 42, 4].unpack1("V")
    name = data[pos + 46, nlen].force_encoding("UTF-8")
    lnlen, lelen = data[local + 26, 4].unpack("vv")
    raw = data[local + 30 + lnlen + lelen, csize]
    body = method == 8 ? Zlib::Inflate.new(-Zlib::MAX_WBITS).inflate(raw) : raw
    raise "bad CRC for #{name}" unless Zlib.crc32(body) == crc && body.bytesize == usize
    out[name] = body
    pos += 46 + nlen + elen + clen
  end
  out
end
files = unzip(result[:path])
check("a zip in the mod's Bug Reports folder: KR Bug Report <date> <time>.zip (#{File.basename(result[:path])}, #{result[:size]} bytes)",
      File.dirname(result[:path]) == File.join(NEW, "Bug Reports") && File.basename(result[:path]) =~ /\AKR Bug Report \d{4}-\d\d-\d\d \d\d-\d\d\.zip\z/)
check("...that opens: every file's CRC and size check out (#{files.keys.inspect})",
      %w[Report.md mods.md hooks.md save-check.md screenshot.png save/File\ A.rxdata].all? { |n| files.key?(n) } &&
      files.keys.any? { |n| n == "logs/Kanto Reloaded.log" } && files.key?("logs/KIF_log.txt") && files.key?("logs/errorlog.txt") &&
      files.key?("settings/Kanto Reloaded Settings.json"))
report = files["Report.md"].force_encoding("UTF-8")
check("Report.md: the note, the versions, this session's errors and Recent Steps",
      report.include?(note) && report.include?("Kanto Reloaded #{R.version}, KIF 0.21.59") &&
      report.include?("## Errors This Session") && report.include?("Broken Mod: failed") && report.include?("## Recent Steps (100)"))
mods = files["mods.md"].force_encoding("UTF-8")
check("mods.md: each mod with its version, author and state", mods.include?("| 1 | Hard Trainers+ | HardTrainers | 1.4 | Ash | loaded |") &&
      mods.include?("Broken Mod") && mods.include?("failed: NameError"))
check("hooks.md: Kanto Reloaded's hooks", files["hooks.md"].include?("trail_battles: PokeBattle_Battle#pbStartBattle"))
check("save-check.md: the Save Checker's report on File A", files["save-check.md"].start_with?("# Save Check: File A"))
check("the screenshot and the save, as they are", files["screenshot.png"] == File.binread(shot) &&
      files["save/File A.rxdata"] == File.binread(SaveData.get_full_path("File A")))
kif = files["logs/KIF_log.txt"].force_encoding("UTF-8")
check("the user name is taken out (#{kif.lines[1].strip} / #{kif.lines[2].strip})",
      kif.include?("%USERPROFILE%\\AppData\\Roaming\\KIF") && kif.include?("D:\\Games\\USERNAME\\KIF Beta") && !kif.include?("TestUser"))
check("...everywhere in the report", files.select { |n, _| n.end_with?(".md", ".txt", ".log", ".json") }.values.none? { |t| t.include?("TestUser") })
check("what's in it, in a line (#{result[:words]})", result[:words] == "logs, settings, mods, the Save Check and the save")

second = BR::Bundle.make(:note => "")
check("a second one the same minute: its own name, no screenshot without one (#{File.basename(second[:path])})",
      second[:path] != result[:path] && File.file?(result[:path]) && !unzip(second[:path]).key?("screenshot.png"))

#---------------------------------------------------------------- After a Crash
def boom(file)
  e = RuntimeError.new("undefined method 'hp' for nil")
  e.set_backtrace(["#{file}:212:in 'pbCalcDamage'", "005_Battle_Move.rb:40:in 'pbUseMove'", "999_Main.rb:12:in 'main'"])
  e
end
Scene_Map.new.transfer_player
mod_crash = BR::Crash.describe(boom(File.join(KIF_ROOT, "Mods", "HardTrainers", "battle_handlers.rb")))
check("a crash in a mod's code names the mod (#{mod_crash["mod"]}, #{mod_crash["where"]})",
      mod_crash["mod"] == "Hard Trainers+" && mod_crash["where"] == "battle_handlers.rb:212" && mod_crash["map"] == "Route 24")
kr_crash = BR::Crash.describe(boom(File.join(R::ROOT, "Core", "UI", "SaveCheckScreen.rb")))
check("...in Kanto Reloaded's: Kanto Reloaded, not a mod (#{kr_crash["owner"]})", kr_crash["owner"] == "Kanto Reloaded" && kr_crash["mod"].nil?)
game_crash = BR::Crash.describe(boom("004_Game_Map.rb"))
check("...in the game's: no mod (#{game_crash["owner"]})", game_crash["mod"].nil? && %w[PIF KIF\ Beta].include?(game_crash["owner"]))
check("Report Made sends a mod's crash to its maker (its mod.json's author and page)",
      BR::Bundle.mod_named("Hard Trainers+")[:author] == "Ash" && BR::Bundle.mod_named("Hard Trainers+")[:support] == "https://example.com/hard-trainers")

# the crash itself: PIF logs it; ours can't show here (no screens), so PIF's box does
out = StringIO.new
old_stdout = $stdout
$stdout = out
begin
  TOPLEVEL_BINDING.receiver.send(:pbPrintException, boom(File.join(KIF_ROOT, "Mods", "HardTrainers", "battle_handlers.rb")))
ensure
  $stdout = old_stdout
end
check("a crash: PIF still logs it (errorlog.txt)", File.read(File.join(USERDIR, "errorlog.txt")).include?("Message: undefined method 'hp'"))
check("...and when ours can't show, PIF's own box does (#{out.string.strip[0, 40]})", out.string.include?("PIF's box: undefined method 'hp'"))
last = JSON.parse(File.read(File.join(R::Paths.settings_dir, "Last Crash.json")))
check("...written down for the next start (#{last["mod"]}, #{last["where"]})", last["mod"] == "Hard Trainers+" && last["reported"] == false)
check("...and on Recent Steps", BR::Trail.lines.any? { |l| l.include?("Crash  RuntimeError: undefined method 'hp'") })

#---------------------------------------------------------------- the next start
pending = BR::Crash.pending
check("next start: the crash, not reported yet, is offered (#{pending && pending["kind"]})", pending && pending["kind"] == "crash")
BR::Crash.mark_reported
check("...a report made: nothing to offer", BR::Crash.pending.nil?)
BR::Crash.instance_variable_set(:@previous, { "running" => true, "map" => "Route 24", "battle" => true })
closed = BR::Crash.pending
check("a session that never ended (the game was killed): offered too, with where it was", closed && closed["kind"] == "closed" && closed["map"] == "Route 24" && closed["battle"])
BR::Crash.offer_pending
check("...once", BR::Crash.pending.nil?)
BR::Crash.clean_exit
check("closing normally: the session ended", JSON.parse(File.read(File.join(R::Paths.settings_dir, "Session.json")))["running"] == false)

# (no screens here: After a Crash and the offer can't show, as planned)
errors = File.read(R::Log.path).lines.grep(/ERROR/).reject { |l| l =~ /Something broke in a test|After a Crash didn't show|offer didn't show/ }
check("no other errors in the log (#{errors.length})", errors.empty?)
errors.first(6).each { |l| puts "  " + l }
puts $failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED"
exit($failed ? 1 : 0)
