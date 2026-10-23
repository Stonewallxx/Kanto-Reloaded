# encoding: utf-8
# Checks the Timing Profiler outside the game: its switches, sessions and
# their sections (work without the wait for the next frame, peaks within one
# frame, slow frames, nesting), kept sessions and the text report, probes on
# made-up game classes, and Mod Timings timing a mod's and Kanto Reloaded's
# hooks on their own.
# Usage: ruby Tools/Tests/profiler_test.rb "<KIF Beta>" <empty temp folder>
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

# Work that takes a known time (sleep is too coarse on Windows)
def busy(ms)
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  nil while Process.clock_gettime(Process::CLOCK_MONOTONIC) - t < ms / 1000.0
end

# The engine's frame: waits a known time, as the game waits for the next frame
module Graphics
  @wait = 4
  class << self
    attr_accessor :wait
    def update; busy(@wait); end
  end
end
class Scene_Map; end
GameTemp = Struct.new(:in_battle)
$game_temp = GameTemp.new(false)
$scene = Scene_Map.new

# Made-up game classes, loaded as the game loads Data\Scripts (a bare file name)
eval(<<~RUBY, TOPLEVEL_BINDING, "002_Fake_Game.rb", 1)
  class FakeBattle
    def pbStartBattle; pbCommandPhase; Graphics.update; pbAttackPhase; Graphics.update; :done; end
    def pbCommandPhase; busy(3); end
    def pbAttackPhase; busy(20); end
  end
  class FakeMenu_Scene
    def pbStartScene; busy(4); end
    def pbEndScene; busy(1); end
    def pbRefresh; busy(2); end
  end
  class FakeLong
    def run; busy(10); Graphics.update; busy(10); end
  end
  class FakeMap
    def update; busy(2); end
  end
RUBY
# A mod hooking FakeMap#update the alias way, loaded as KIF loads mods (full path)
eval(<<~RUBY, TOPLEVEL_BINDING, File.join(KIF_ROOT, "Mods/FakeMod/hook.rb"), 1)
  class FakeMap
    alias fakemod_update update
    def update; busy(3); fakemod_update; end
  end
RUBY

load File.join(KIF_ROOT, "Mods/KantoReloaded/Bootstrap.rb")
R = Reloaded
PR = R::Profiler
HT = PR::HookTiming
OW = PR::Owners
S = R::Settings
def near(seconds, ms, slack = 1.5); (seconds.to_f * 1000 - ms).abs <= slack; end
def ms(x); (x.to_f * 1000).round(1); end

check("Kanto Reloaded boots with the Timing Profiler (#{R::Bootstrap.status}, #{R::Bootstrap.failures.inspect})", R::Bootstrap.status == :ready)
check("its settings are Kanto Reloaded pages of its own, after the others, with Developer Tools last",
      %i[profiler profiler_time profiler_report].map { |p| S.page(p) && S.page(p)[:name] } ==
        ["Timing Profiler", "Timing Profiler - Time", "Timing Profiler - Report"] &&
      S.page(:developer)[:name] == "Developer Tools" && S.page(:developer)[:priority] > S.page(:profiler_report)[:priority])

#---------------------------------------------------------------- switches
check("off by default", !PR.on?)
S.set(:"profiler.enabled", true)
check("On isn't enough: KIF's DEBUG option has to be on too", !PR.on?)
$DEBUG = true
check("with DEBUG on, it runs", PR.on?)
S.set(:"profiler.slow_frame", 0)
check("Slow Frame 16.7 ms (#{ms(PR.slow_limit)} ms)", near(PR.slow_limit, 16.7, 0.1))

#---------------------------------------------------------------- owners
check("owners: a mod by its folder, Kanto Reloaded by its own",
      OW.of(File.join(KIF_ROOT, "Mods/FakeMod/hook.rb")) == "FakeMod" && OW.of(File.join(R::ROOT, "Core/Profiler/Profiler.rb")) == OW::KR)
check("owners: the game's bare file names: EBDX, KIF, PIF (#{OW.of("010_EBDX_Scene.rb")}, #{OW.of("Mods.rb")}, #{OW.of("002_Scene_Map.rb")})",
      OW.of("010_EBDX_Scene.rb") == OW::EBDX && OW.of("Mods.rb") == OW::KIF && OW.of("002_Scene_Map.rb") == OW::PIF)

#---------------------------------------------------------------- a battle
PR.install
check("the built-in probes this game hasn't got are skipped, not errors (#{PR::Probes.skipped.length})",
      PR::Probes.skipped.include?("PokeBattle_Battle#pbStartBattle"))
PR::Probes.session(FakeBattle, :pbStartBattle, :battle) { |_b, _a| ["Wild Battle", { "Turns" => 1 }] }
PR::Probes.section(FakeBattle, :pbCommandPhase, "Command Phase", :battle, :about => "Choosing.")
PR::Probes.section(FakeBattle, :pbAttackPhase, "Attack Phase", :battle)
Graphics.update
FakeBattle.new.pbStartBattle
s = PR.sessions.first
sec = s && s["sections"]
check("a battle is a session, named by its probe (#{s && s["name"]}), its info kept", s && s["name"] == "Wild Battle" && s["info"]["Turns"] == 1)
check("its phases are sections, timed (Command #{ms(sec["Command Phase"]["total"])} ms, Attack #{ms(sec["Attack Phase"]["peak"])} ms)",
      near(sec["Command Phase"]["total"], 3) && near(sec["Attack Phase"]["peak"], 20) && sec["Command Phase"]["about"] == "Choosing.")
check("the wait for the next frame isn't work (#{ms(s["work"])} ms of #{ms(s["elapsed"])} ms, 2 frames of 4 ms)",
      near(s["work"], 23, 2.5) && s["elapsed"] - s["work"] > 0.007 && s["frames"] == 2)
check("Attack Phase is slow at 16.7 ms; Command Phase isn't", sec["Attack Phase"]["slow"] == 1 && sec["Command Phase"]["slow"] == 0)
fw = sec[PR::FRAME_WORK]
check("Frame Work: each frame's work (#{fw && fw["calls"]} frames, worst #{fw && ms(fw["peak"])} ms, #{fw && fw["slow"]} slow)",
      fw && fw["calls"] == 2 && near(fw["peak"], 20, 2) && fw["slow"] == 1)
check("its status is red (a slow frame)", s["status"] == "red")
check("owners: the game's methods are PIF's", sec["Attack Phase"]["owner"] == OW::PIF)

#---------------------------------------------------------------- across frames, nesting
PR::Probes.section(FakeLong, :run, "Long Run", :battle)
r = PR.session(:battle, "Long") { FakeLong.new.run; PR.measure("Outer") { PR.measure("Inner") { busy(1) } } }
s = PR.sessions.first
lr = s["sections"]["Long Run"]
check("a section across frames: its peak is its most in one frame (#{ms(lr["peak"])} ms), its total all of it (#{ms(lr["total"])} ms), not slow",
      near(lr["peak"], 10) && near(lr["total"], 20, 2) && lr["slow"] == 0)
check("a section inside another says which", s["sections"]["Inner"]["inside"] == "Outer" && s["sections"]["Outer"]["inside"].nil?)

#---------------------------------------------------------------- a menu
PR::Probes.send(:menu, FakeMenu_Scene, :pbStartScene, :pbEndScene, "Fake Menu")
m = FakeMenu_Scene.new
m.pbStartScene
m.pbRefresh
Graphics.update
m.pbEndScene
s = PR.sessions.first
check("a menu is a session from opening to closing: Open, Refresh, Close (#{s["sections"].keys.inspect})",
      s["name"] == "Fake Menu" && near(s["sections"]["Open"]["total"], 4) && near(s["sections"]["Refresh"]["total"], 2) &&
      near(s["sections"]["Close"]["total"], 1))
count = PR.sessions.length
S.set(:"profiler.menus", false)
m.pbStartScene
m.pbEndScene
check("Menus Off: no session", PR.sessions.length == count)
S.set(:"profiler.menus", true)

#---------------------------------------------------------------- kept sessions, the report
S.set(:"profiler.keep", 5)
4.times { |i| PR.session(:saving, "Save #{i}") { busy(1) } }
check("Keep Sessions 5: the newest five (#{PR.sessions.map { |x| x["name"] }.inspect})",
      PR.sessions.length == 5 && PR.sessions.first["name"] == "Save 3")
kept = JSON.parse(File.read(PR.path))
check("kept in Timing Sessions.json for later", kept["sessions"].length == 5 && kept["sessions"][0]["name"] == "Save 3")
PR.reset
check("...and read back after a restart, marked as earlier (#{PR.sessions.length})",
      PR.sessions.length == 5 && PR.sessions.all? { |x| x["earlier"] } && PR.sessions.first["name"] == "Save 3")
report = File.read(PR::Report.path)
check("each session added to TimingProfile.txt (#{report.scan("KANTO RELOADED TIMING PROFILE").length})",
      report.include?("KANTO RELOADED TIMING PROFILE: Battle, Wild Battle") && report.include?("Attack Phase") &&
      report.include?("KANTO RELOADED TIMING PROFILE: Menu, Fake Menu"))
S.set(:"profiler.text_report", false)
size = File.size(PR::Report.path)
PR.session(:saving, "Quiet") { busy(1) }
check("Text Report Off: nothing added", File.size(PR::Report.path) == size)

#---------------------------------------------------------------- Mod Timings
R::Hooks.around(nil, FakeMap, :update, :id => :test_kr_hook) { |original, *args| busy(1); original.call(*args) }
fm = FakeMap.new
Graphics.update                       # Mod Timings' TracePoints go on
check("Mod Timings found the hook layers on FakeMap#update (#{HT.layers.select { |l| l[:label] == "FakeMap#update" }.length + HT.layers.count { |l| l[:shared] }})",
      HT.enabled? && HT.layers.any? { |l| l[:owner] == "FakeMod" && l[:label] == "FakeMap#update" } &&
      HT.layers.any? { |l| l[:owner].nil? && l[:label] == "FakeMap#update" } && HT.layers.any? { |l| l[:shared] })
HT.clear
10.times { fm.update; Graphics.update }
mod = HT.per_frame("FakeMod", :map)
kr = HT.per_frame(OW::KR, :map)
game = HT.per_frame(HT::GAME_LABEL, :map)
check("each layer only its own time, per frame on the map: FakeMod #{ms(mod)} ms, Kanto Reloaded #{ms(kr)} ms, the game #{ms(game)} ms",
      near(mod, 3, 0.6) && near(kr, 1, 0.6) && game > 0.0015 && HT.frames(:map) == 10)
hook = HT.hooks("FakeMod").first
check("FakeMod's slowest hook: FakeMap#update, 3 ms (#{hook && hook[0]}, #{hook && ms(hook[1]["peak"])} ms)",
      hook && hook[0] == "FakeMap#update" && near(hook[1]["peak"], 3, 0.6) && hook[1]["calls"] == 10)
krhook = HT.hooks(OW::KR).find { |l, _| l.include?("test_kr_hook") }
check("Kanto Reloaded's around hook, by its id (#{krhook && krhook[0]})", krhook && near(krhook[1]["peak"], 1, 0.6))
check("the profiler's own hooks aren't listed", HT.hooks(OW::KR).none? { |l, _| l.include?("profiler_") })
check("owners: Kanto Reloaded first, the mod, PIF and KIF last (#{HT.owners.inspect})",
      HT.owners.first == OW::KR && HT.owners.include?("FakeMod") && HT.owners.last == HT::GAME_LABEL)
$game_temp.in_battle = true
Graphics.update
5.times { fm.update; Graphics.update }
check("in battle, counted as battle (#{HT.frames(:battle)} frames, FakeMod #{ms(HT.per_frame("FakeMod", :battle))} ms)",
      HT.frames(:battle) == 5 && near(HT.per_frame("FakeMod", :battle), 3, 0.6))
$game_temp.in_battle = false
S.set(:"profiler.mod_timings", false)
Graphics.update
calls = HT.hooks("FakeMod").first[1]["calls"]
fm.update
check("Mod Timings Off: its TracePoints are off", !HT.enabled? && HT.hooks("FakeMod").first[1]["calls"] == calls)
check("startup: Kanto Reloaded's own boot is timed (#{ms(HT.startup_of(OW::KR)[:scripts])} ms)", HT.startup_of(OW::KR)[:scripts].to_f > 0)
S.set(:"profiler.enabled", false)
Graphics.update
check("Timing Profiler Off: nothing runs", !PR.on? && !HT.enabled?)

errors = File.read(R::Log.path).lines.grep(/ERROR/)
check("no errors in the log (#{errors.length})", errors.empty?)
errors.first(5).each { |l| puts "  " + l }
puts($failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED")
exit($failed ? 1 : 0)
