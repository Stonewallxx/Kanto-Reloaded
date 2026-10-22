# encoding: utf-8
# Offline preview of Bug Reports' screens on the preview tool's stand-ins
# (Tools/UIPreview/preview.rb): Make a Bug Report (the note typed in, the
# screenshot, What's In It, Include the Save), Make Report and Report Made
# (Open Discord), After a Crash in a mod's code with Report Made pointing to
# its maker, and the next start's offer over the Load Screen.
# Usage: ruby   Tools/Tests/bug_report_preview.rb "<KIF Beta>" <work dir with metrics.json>
#        python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>
PREVIEW_SETUP_ONLY = true
load File.join(ARGV[0], "Mods/KantoReloaded/Tools/UIPreview/preview.rb")
require "fileutils"
require "json"
BR = Reloaded::BugReport
check("Bug Reports' screens load in the preview", defined?(Reloaded::BugReportScreen) && defined?(Reloaded::Notice))

# a home of the test's own (its name is taken out of the report)
HOME = File.join(USERDIR, "home", "TestUser")
FileUtils.mkdir_p(HOME)
ENV["USERPROFILE"] = HOME
ENV["USERNAME"] = "TestUser"
ENV.delete("OneDrive")
SAVES = File.join(USERDIR, "saves")
FileUtils.mkdir_p(SAVES)
module SaveData
  SAVE_DIR = SAVES
  MANUAL_SLOTS = ("A".."H").map { |l| "File #{l}" }
  AUTO_SLOTS = ["Auto 1", "Auto 2"]
  def self.get_full_path(slot); File.join(SAVE_DIR, "#{slot}.rxdata"); end
  def self.get_data_from_file(path); File.open(path, "rb") { |f| Marshal.load(f) }; end
end
Player = Struct.new(:name, :money, :badge_count, :pokedex, :last_time_saved, :selected_difficulty, :id, :party, :girl, :save_slot) do
  def female?; girl; end
  def male?; !girl; end
end
File.binwrite(SaveData.get_full_path("File A"), Marshal.dump({ :player => Player.new("Red", 1200, 2, nil, Time.now - 300, 1, 7, [], false, "File A") }))
# Hard Trainers+, with its own page for bug reports
MODS = File.join(USERDIR, "Mods", "HardTrainers")
FileUtils.mkdir_p(MODS)
File.write(File.join(MODS, "mod.json"), JSON.generate("name" => "Hard Trainers+", "version" => "1.4", "author" => "Ash", "support" => "https://example.com/hard-trainers"))
ModEntry = Struct.new(:id, :name, :path, :on) { def enabled?; on; end }
module KIF
  module Mods
    def self.entries; [ModEntry.new("HardTrainers", "Hard Trainers+", MODS, true)]; end
    def self.status; { "HardTrainers" => { :loaded => true } }; end
  end
end
# the screen the report is about, and what opening things would do
SHOT = Dir.glob(File.join(ARGV[0], "Graphics", "Pictures", "loadbg.png")).first
BR.instance_variable_set(:@screen, Bitmap.new(SHOT)) if SHOT
$opened = []
BR.launcher = proc { |kind, x| $opened << [kind, x] }
BR::Trail.add(:map, "Route 24")
BR::Trail.add(:battle, "Started: Wild Battle")

def scr_br; $br; end
Reloaded::BugReportScreen.prepend(Module.new { def main; $br = self; super; end })

#---------------------------------------------------------------- Make a Bug Report
made = nil
Input.queue = [
  dmp("br_01_what"),
  at { check("opens on What Happened, This Screen chosen (#{scr_br.send(:rows).map { |r| r[0] }.inspect})", scr_br.send(:section_id) == :what) },
  I::USE, "Game froze after Gyarados used Thrash.", :RETURN,
  at { check("the note, typed straight in (#{scr_br.note})", scr_br.note == "Game froze after Gyarados used Thrash.") },
  I::DOWN, I::RIGHT,
  at { check("Right on Screenshot: the next choice", scr_br.instance_variable_get(:@shot) == 1) },
  I::LEFT,
  dmp("br_02_what_filled"),
  I::BACK, I::DOWN, I::RIGHT,
  dmp("br_03_inside"),
  at { check("What's In It: each part, ticked off (#{scr_br.send(:rows).map { |r| r[1] }.inspect})",
             scr_br.send(:rows).map { |r| r[0] } == [:logs, :settings, :mods, :hooks, :check, :steps, :errors, :save]) },
  *[[:held, I::DOWN]] * 7,
  I::RIGHT,
  dmp("br_04_include_save"),
  at { check("Include the Save: Off by default, then File A", scr_br.send(:row)[2] == "File A") },
  I::X,
  dmp("br_05_report_made"),
  I::RIGHT, I::USE,
  at { check("Report Made: Open Discord opens the bug reports channel", $opened.last == [:url, BR::DISCORD_URL]) },
  I::LEFT, I::USE,
  at { check("...Open the Folder shows the file", $opened.last[0] == :folder && $opened.last[1].end_with?(".zip")) },
  I::RIGHT, I::RIGHT, I::USE
]
begin
  made = Reloaded::BugReportScreen.open
  check("Make Report: the report made, the screen closed (#{File.basename(made.to_s)})", made && File.file?(made))
rescue Exception => e
  check("Make a Bug Report: #{e.class}: #{e.message} #{e.backtrace.first(4).inspect}", false)
end
check("...in the mod's Bug Reports folder", made && File.dirname(made) == File.join(KR_LOCAL_DIR, "Bug Reports"))

#---------------------------------------------------------------- After a Crash
info = BR::Crash.describe(RuntimeError.new("undefined method 'hp' for nil").tap do |e|
  e.set_backtrace([File.join(ARGV[0], "Mods", "HardTrainers", "battle_handlers.rb") + ":212:in 'pbCalcDamage'", "999_Main.rb:12:in 'main'"])
end)
Input.queue = [
  dmp("br_06_crash"),
  I::USE,
  dmp("br_07_made_closing"),
  at { check("after a crash in Hard Trainers+: Report Made points to its maker's page", $opened.length == 2) },
  I::RIGHT, I::USE,
  at { check("...Open Their Page opens it", $opened.last == [:url, "https://example.com/hard-trainers"]) },
  I::RIGHT, I::USE
]
begin
  BR::Crash.send(:after_crash, info, nil)
  check("After a Crash: Make a Bug Report, then Close the Game", true)
rescue Exception => e
  check("After a Crash: #{e.class}: #{e.message} #{e.backtrace.first(4).inspect}", false)
end
check("...it named the mod", info["mod"] == "Hard Trainers+")

#---------------------------------------------------------------- the next start
File.write(File.join(Reloaded::Paths.settings_dir, "Last Crash.json"),
           JSON.generate(info.merge("reported" => false, "offered" => true)))
Reloaded::LoadScreen.offered = false
COMMANDS = ["File A", "New Game", "Options", "Quit Game"].freeze
data = File.open(SaveData.get_full_path("File A"), "rb") { |f| Marshal.load(f) }
v = Reloaded::LoadScreen::View.new(COMMANDS.dup, true, data[:player], 0, 0)
v.open
Input.queue = [dmp("br_08_offer"), I::RIGHT, I::USE, I::DOWN, I::USE]
begin
  v.choose(COMMANDS.dup, 0)
  check("next start: The Game Closed Unexpectedly over the Load Screen, Not Now, then the menu", BR::Crash.pending.nil?)
rescue Exception => e
  check("the offer: #{e.class}: #{e.message} #{e.backtrace.first(4).inspect}", false)
end
v.close(false)

#---------------------------------------------------------------- on a phone: Copy Instead
ENV["ANDROID_ROOT"] = "/system"            # what an Android player has
Reloaded::Runtime.reset
$opened.clear
Input.clipboard = ""
$titles = []
Reloaded::Notice.singleton_class.prepend(Module.new { def show(**o); $titles << [o[:title], o[:buttons]]; super(**o); end })
Input.queue = [
  I::X,
  dmp("br_09_phone_made"),
  I::USE,
  dmp("br_10_phone_copied"),
  at { check("on a phone, Report Made offers Copy the Path and Copy the Link (#{$titles.find { |t, _| t == "Bug Report Made" }.inspect})",
             $titles.any? { |t, b| t == "Bug Report Made" && b.first(2) == ["Copy the Path", "Copy the Link"] }) },
  at { check("...Copy the Path puts the report's full path on the clipboard and says Copied (#{File.basename(Input.clipboard)})",
             Input.clipboard.end_with?(".zip") && File.file?(Input.clipboard) && $titles.last[0] == "Copied") },
  I::USE,
  I::RIGHT, I::USE,
  at { check("...Copy the Link copies Discord's link", Input.clipboard == BR::DISCORD_URL && $titles.last[0] == "Copied") },
  I::USE,
  I::RIGHT, I::USE
]
begin
  Reloaded::BugReportScreen.open
rescue Exception => e
  check("on a phone: #{e.class}: #{e.message} #{e.backtrace.first(3).inspect}", false)
end
check("...and nothing tried to open File Explorer or a browser", $opened.empty?)
ENV.delete("ANDROID_ROOT")
Reloaded::Runtime.reset

errors = File.read(Reloaded::Log.path).lines.grep(/ERROR/)
check("no errors in the log (#{errors.length})", errors.empty?)
errors.first(6).each { |l| puts "  " + l }
puts $failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED"
exit($failed ? 1 : 0)
