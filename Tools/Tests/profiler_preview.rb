# encoding: utf-8
# Offline preview of the Timing Profiler's screens and its settings in the
# Kanto Reloaded section (Tools/UIPreview/preview.rb's stand-ins): sessions and Mod Timings like the
# ones in the design, driven with button presses and the mouse.
# Usage: ruby   Tools/Tests/profiler_preview.rb "<KIF Beta>" <work dir with metrics.json>
#        python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>
PREVIEW_SETUP_ONLY = true
load File.join(ARGV[0], "Mods/KantoReloaded/Tools/UIPreview/preview.rb")
PR = Reloaded::Profiler
HT = PR::HookTiming
OW = PR::Owners
check("the Timing Profiler's screens load in the preview", defined?(Reloaded::ProfilerScreen) && defined?(Reloaded::SplitScreen))

#---------------------------------------------------------------- in the Kanto Reloaded section
DEV_ROWS = ["Timing Profiler", "Timing Profiler", "Report Viewer", "Timing Profiler - Time", "Battles", "Map Loads", "Menus", "Saving",
            "Mod Timings", "Timing Profiler - Report", "Slow Frame", "Keep Sessions", "Text Report", "Developer Tools", "Hook Check"].freeze
def section_ids(screen); screen.instance_variable_get(:@sections).map { |x| x[0] }; end
def kr_rows(screen); (screen.instance_variable_get(:@rows)[:kanto_reloaded] || []).map(&:label); end
def dev_part(screen); r = kr_rows(screen); i = r.index("Timing Profiler"); i ? r[i..-1] : []; end
$DEBUG = false
drive("DEBUG off", [
  at { check("DEBUG off: none of it in the Kanto Reloaded section, and no section of its own (#{section_ids(scr).first(3).inspect}...)",
             dev_part(scr).empty? && section_ids(scr).none? { |id| id.to_s.include?("developer") }) },
  at { $DEBUG = true; scr.send(:rebuild) },
  at { check("switching DEBUG on in Settings adds its headings, last in the Kanto Reloaded section (#{dev_part(scr).first(4).inspect}...)",
             dev_part(scr) == DEV_ROWS && kr_rows(scr).last(DEV_ROWS.length) == DEV_ROWS) },
  at { $DEBUG = false; scr.send(:rebuild) },
  at { check("...and switching it off takes them out", dev_part(scr).empty?) },
  I::BACK
])
$DEBUG = true
Input.queue = [
  dmp("pr_10_developer"),
  at { check("on Timing Profiler, Off by default (#{row_name})", row_name == "Timing Profiler" && !Reloaded::Settings.get(:"profiler.enabled")) },
  [:held, I::DOWN], [:held, I::DOWN], [:held, I::DOWN], [:held, I::DOWN], [:held, I::DOWN], [:held, I::DOWN], [:held, I::DOWN],
  dmp("pr_11_report_settings"),
  at { check("Slow Frame, 33.3 ms by default (#{row_name})", row_name == "Slow Frame" && Reloaded::Settings.get(:"profiler.slow_frame") == 1) },
  I::BACK, I::BACK
]
begin
  Reloaded::KIFBridge.open_heading("Timing Profiler")
  check("the Profiler's Settings box: KIF Settings on the Timing Profiler heading: opened and closed", true)
rescue Exception => e
  check("the Profiler's Settings box: #{e.class}: #{e.message} #{e.backtrace.first(3).inspect}", false)
end

#---------------------------------------------------------------- sessions like the design's
# (Mod Timings' TracePoints stay off here: they'd time the preview's own helpers)
HT.define_singleton_method(:enable) { }
Reloaded::Settings.set(:"profiler.enabled", true)
PR.reset
def add_session(kind, name, where, sections, info = {}, frames = 600)
  s = PR.start_session(kind, name, info)
  s["where"] = where
  sections.each do |label, owner, peak, calls, slow_peaks, about, inside|
    calls.times { |i| PR.record(s, label, peak / 1000.0 * (i.zero? ? 1 : 0.4), i.zero? ? peak / 1000.0 : peak / 2500.0, owner, about) }
    s["sections"][label]["inside"] = inside if inside
    s["sections"][label]["slow"] = slow_peaks
  end
  PR.finish_session(s)
  s["frames"] = frames
  s["elapsed"] = frames / 60.0
  s["work"] = frames / 60.0 * 0.3
  s["status"] = PR.status_of(s).to_s
  s
end
KR = OW::KR
add_session(:map, "Pewter City", "Route 2", [["Map Data Load", "PIF", 30.1, 2, 0], ["Sprites Build", "PIF", 12.0, 1, 0],
                                             ["Music Change", "PIF", 0.8, 1, 0], ["Frame Work", "All", 30.4, 40, 0]])
add_session(:battle, "Brock", "Pewter City Gym", [["Attack Phase", "PIF", 9.0, 6, 0], ["EBDX Frame Work", "EBDX", 6.1, 300, 0],
                                                  ["Frame Work", "All", 14.0, 300, 0]], { "Turns" => 6, "Decision" => "Won" })
add_session(:saving, "Saving", "Pewter City", [["Write Save File", "PIF", 12.2, 1, 0], ["Frame Work", "All", 13.0, 1, 0]])
add_session(:menu, "Bag", "Route 2", [["Open", "PIF", 9.4, 1, 0], ["Refresh", "PIF", 2.1, 4, 0], ["Frame Work", "All", 9.9, 60, 0]])
add_session(:map, "Viridian City", "Route 1",
            [["Map Data Load", "PIF", 88.5, 3, 2, "Loading the map and the maps next to it: their data, tiles and events."],
             ["Sprites Build", "PIF", 54.0, 1, 1, "Building the new map's tilemap, character sprites and weather."],
             ["Map Setup", "PIF", 31.3, 3, 0, "One map's setup: its data file, tileset, fog and every event on it.", "Map Data Load"],
             ["Events Setup", "PIF", 22.7, 48, 0, "Making the map's events, one call each.", "Map Setup"],
             ["Fusion Sprite Load", "KIF Beta", 17.3, 6, 0], ["Overworld Pokémon", KR, 4.0, 1, 0],
             ["Music Change", "PIF", 1.2, 1, 0], ["Frame Work", "All", 96.0, 22, 2]])
add_session(:battle, "Wild Battle", "Route 1",
            [["Target Icon Prewarm", KR, 38.6, 1, 1, "One frame of battle froze while the target icons were drawn ahead of time."],
             ["Battle Menu Draw", KR, 21.5, 14, 0], ["EBDX Frame Work", "EBDX", 18.4, 700, 0],
             ["EBDX Fight Refresh", "EBDX", 11.2, 9, 0], ["EBDX Command Refresh", "EBDX", 9.8, 9, 0],
             ["Native Frame Work", "PIF", 5.2, 700, 0], ["Double Abilities", KR, 0.9, 3, 0],
             ["End-of-Round Phase", "PIF", 1.0, 3, 0], ["Frame Work", "All", 39.0, 700, 1]],
            { "Turns" => 3, "Decision" => "Caught", "Sides" => "1 vs 1", "Network" => "Solo" }, 740)
WILD_ID = PR.sessions.first["id"]
BROCK_ID = PR.sessions.find { |s| s["name"] == "Brock" }["id"]

# Mod Timings like the design's
HT.instance_variable_set(:@stats, {
  KR => { "Target Icon Prewarm" => { "calls" => 1, "total" => 0.0386, "peak" => 0.0386, "slow" => 1, "session" => WILD_ID, "where" => "Wild Battle" },
          "Battle Menu Draw" => { "calls" => 14, "total" => 0.09, "peak" => 0.0215, "slow" => 0, "session" => WILD_ID, "where" => "Wild Battle" },
          "Overworld Pokémon" => { "calls" => 900, "total" => 0.3, "peak" => 0.004, "slow" => 0 } },
  "Hard Trainers+" => { "PokeBattle_Battle#pbStartBattle" => { "calls" => 2, "total" => 0.07, "peak" => 0.064, "slow" => 1, "session" => BROCK_ID, "where" => "Brock" },
                        "PokeBattle_Battler#pbSpeech" => { "calls" => 40, "total" => 0.02, "peak" => 0.0011, "slow" => 0 } },
  "EBDX" => { "PokeBattle_Scene#pbRefresh" => { "calls" => 300, "total" => 0.4, "peak" => 0.006, "slow" => 0 } },
  "Gen 9 Movepools" => {}, "Multiplayer" => { "Scene_Map#update" => { "calls" => 3000, "total" => 0.6, "peak" => 0.0009, "slow" => 0 } } })
def per_ctx(h); Hash.new(0.0).merge(h); end
HT.instance_variable_set(:@context, { KR => per_ctx(:map => 0.31 * 3000 / 1000.0, :battle => 1.4 * 1000 / 1000.0),
                                      "Hard Trainers+" => per_ctx(:battle => 0.2 * 1000 / 1000.0),
                                      "EBDX" => per_ctx(:battle => 3.1 * 1000 / 1000.0), "Multiplayer" => per_ctx(:map => 0.2 * 3000 / 1000.0) })
HT.instance_variable_set(:@frames, Hash.new(0).merge(:map => 3000, :battle => 1000))
HT.instance_variable_set(:@frame_work, Hash.new(0.0).merge(:map => 3000 * 0.004, :battle => 1000 * 0.009))
HT.instance_variable_set(:@startup, { "Hard Trainers+" => Hash.new(0.0).merge(:scripts => 0.031) })
Reloaded::DataPatches.instance_variable_set(:@timings, { KR => 0.288, "Hard Trainers+" => 0.024, "Gen 9 Movepools" => 0.051 })

#---------------------------------------------------------------- driving it
def ps_screen; $ps; end
Reloaded::ProfilerScreen.prepend(Module.new { def main; $ps = self; super; end })
def drive_ps(label, queue, mode = :sessions)
  Input.queue = queue.dup
  Reloaded::ProfilerScreen.open(mode, true)
  check("#{label}: opened and closed", true)
rescue QueueEmpty => e
  check("#{label}: #{e.message}", false)
rescue Exception => e
  check("#{label}: #{e.class}: #{e.message} #{e.backtrace.first(4).inspect}", false)
end
def ps_mode; ps_screen.instance_variable_get(:@mode); end
def ps_entry; ps_screen.send(:entry_at); end
def ps_row; ps_screen.send(:current); end
def ps_hints; ps_screen.send(:hint_pairs).map { |p| p[1] }; end
def ps_rows; ps_screen.send(:rows).map { |r| r[:label] }; end
def ps_desc; ps_screen.send(:description)[1]; end

drive_ps("report viewer", [
  dmp("pr_01_sessions"),
  at { check("sessions newest first, each with its status (#{PR.sessions.map { |s| "#{s["name"]} #{s["status"]}" }.inspect})",
             ps_entry["name"] == "Wild Battle" && PR.sessions.map { |s| s["status"] } == ["red", "red", "ok", "ok", "ok", "amber"]) },
  at { check("a session's description: #{ps_desc}", ps_desc.include?("740 frames, 1 slow") && ps_desc.include?("Slowest: Target Icon Prewarm, 38.6 ms")) },
  I::RIGHT,
  dmp("pr_02_battle"),
  at { check("its sections, slowest first, Frame Work last (#{ps_rows.first(2).inspect}, #{ps_rows.last})",
             ps_rows.first == "Target Icon Prewarm" && ps_rows.last == "Frame Work") },
  at { check("the hints: Select, Sort: Peak, Owner: All, Sessions (#{ps_hints.inspect})", ps_hints == ["Select", "Sort: Peak", "Owner: All", "Sessions"]) },
  at { check("a section's description: #{ps_desc}", ps_screen.send(:description)[3].map(&:first) == ["KANTO RELOADED", "1 SLOW"] && ps_desc.include?("That's over 33.3 ms: A slow frame.")) },
  I::X,
  at { check("Y: sorted by total (#{ps_rows.first})", ps_hints[1] == "Sort: Total" && ps_rows.first == "EBDX Frame Work") },
  I::X, I::X, I::X,
  I::ACTION,
  at { check("X: one owner's sections (#{ps_rows.inspect})", ps_hints[2] == "Owner: All" || ps_rows.all? { |l| PR.sessions.first["sections"][l]["owner"] == ps_screen.instance_variable_get(:@owner) }) },
  I::ACTION, I::ACTION, I::ACTION, I::ACTION,
  at { check("...round to all again (#{ps_hints[2]})", ps_hints[2] == "Owner: All") },
  I::BACK, I::DOWN, I::RIGHT,
  dmp("pr_03_map"),
  at { check("a map load: Map Data Load at 88.5 ms, 2 slow; a nested section says so", ps_row[:label] == "Map Data Load" && ps_desc.include?("2 of them over 33.3 ms")) },
  I::DOWN, I::DOWN,
  at { check("nested: #{ps_desc}", ps_row[:label] == "Map Setup" && ps_desc.include?("Inside Map Data Load")) },
  I::R,
  dmp("pr_04_mods"),
  at { check("R: Mod Timings, Kanto Reloaded first, PIF and KIF last (#{HT.owners.inspect})",
             ps_mode == :mods && HT.owners.first == KR && HT.owners.last == HT::GAME_LABEL) },
  I::RIGHT,
  dmp("pr_05_kr_startup"),
  at { check("Startup (#{ps_desc})", ps_row[:label] == "Startup" && ps_desc.include?("Data Patches")) },
  I::DOWN, I::DOWN, I::DOWN, I::DOWN,
  dmp("pr_06_kr_hook"),
  at { check("its slowest hook, and A to its session (#{ps_row[:label]}; #{ps_hints.inspect})",
             ps_row[:label] == "Target Icon Prewarm" && ps_hints.include?("Open in Sessions")) },
  I::USE,
  at { check("A: the session it was slowest in (#{ps_entry && ps_entry["name"]})", ps_mode == :sessions && ps_entry["name"] == "Wild Battle") },
  I::R, I::DOWN, I::DOWN, I::DOWN, I::RIGHT,
  dmp("pr_07_mod_before_kr"),
  at { check("a mod loading before Kanto Reloaded: #{ps_desc}", ps_entry == "Hard Trainers+" && ps_screen.send(:description)[1].include?("31.0 ms")) },
  I::DOWN, I::DOWN, I::DOWN, I::DOWN,
  dmp("pr_08_mod_hook"),
  at { check("its hook: #{ps_desc}", ps_desc.include?("64.0 ms at worst (in Brock)")) },
  I::BACK, [:held, I::DOWN], [:held, I::DOWN], [:held, I::DOWN], [:held, I::DOWN],
  at { check("PIF and KIF, last (#{ps_entry})", ps_entry == HT::GAME_LABEL) },
  I::RIGHT,
  dmp("pr_09_game"),
  I::BACK,
  I::SPECIAL,
  at { check("the left box: back to Sessions", ps_mode == :sessions) },
  I::SPECIAL
])

# The mouse
drive_ps("mouse", [
  [:move, 60, 42 + 20 + 6],
  at { check("the mouse over a session picks it (#{ps_entry["name"]})", ps_entry["name"] == "Viridian City") },
  [:click, 300, 42 + 22 + 26 + 6],
  at { check("a click on a row selects it (#{ps_row && ps_row[:label]})", ps_screen.instance_variable_get(:@focus) == :list) },
  [:rclick, 10, 10], [:rclick, 10, 10]
])

# Nothing yet
PR.reset
PR.instance_variable_set(:@kept_loaded, true)
Reloaded::Settings.set(:"profiler.enabled", false)
drive_ps("empty", [
  dmp("pr_12_empty"),
  at { check("with nothing yet, it says how to start (#{ps_desc[0, 40]}...)", ps_desc.include?("The Timing Profiler is Off")) },
  I::BACK
])

# Timing Profiler > Report Viewer opens it
$ps = nil
Input.queue = [I::BACK]
Reloaded::Settings.press(:"profiler.viewer")
check("Report Viewer's button opens it", !ps_screen.nil?)

errors = File.read(Reloaded::Log.path).lines.grep(/ERROR/)
check("no errors in the log (#{errors.length})", errors.empty?)
errors.first(6).each { |l| puts "  " + l }
puts $failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED"
exit($failed ? 1 : 0)
