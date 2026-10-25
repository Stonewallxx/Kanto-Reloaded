# encoding: utf-8
# The Save Checker outside the game, for mod makers: checks a save file the
# way the in-game Save Checker does, on KIF Beta's real data, and prints the
# report (Markdown). Nothing is written to the save.
#
#   ruby Tools/SaveChecker/save_check.rb "<KIF Beta>" "<save file>" [report.md]
#
# Outside the game none of the game's classes are loaded, so every object
# in the save is stood in for while it's read (SaveCheck::Reader) and its
# owner is found by searching the game's scripts and the Mods folder. What a
# script adds while the game runs (KIF's K-Eggs, items a mod's code makes)
# isn't in the data files read here, so outside the game it shows as
# Missing Content. The exit code is 0 for Healthy (notes or not), 1 for
# problems or a damaged file.
require "fileutils"
require "json"
require "tmpdir"

if ARGV.length < 2
  puts "Usage: ruby Tools/SaveChecker/save_check.rb \"<KIF Beta>\" \"<save file>\" [report.md]"
  exit 2
end
KIF_ROOT = File.expand_path(ARGV[0])
SAVE = File.expand_path(ARGV[1])
OUT = ARGV[2] && File.expand_path(ARGV[2])
abort "There's no save file at #{SAVE}" unless File.file?(SAVE)
USERDIR = Dir.mktmpdir("kr_save_check")
$log = []

begin
  $VERBOSE = nil
  load File.join(KIF_ROOT, "Mods/KantoReloaded/Tools/PatchChecker/game_data.rb")
  # nothing registered here is the game's: its own values are found in its scripts
  SaveData.instance_variable_set(:@values, [])
  module KIF; PORT_VERSION = (GameDataLoader.kif_version || "?") unless const_defined?(:PORT_VERSION); end
  load File.join(KIF_ROOT, "Mods/KantoReloaded/Bootstrap.rb")
  r = Reloaded::SaveCheck.run(SAVE, :slot => File.basename(SAVE, ".rxdata"))
  text = Reloaded::SaveCheck.report_text(r)
  puts text
  if OUT
    File.write(OUT, text)
    puts "", "Report written to #{OUT}"
  end
  exit([:problem, :damaged].include?(r.state) ? 1 : 0)
ensure
  # Only the temporary folder made above, in the system's temp folder
  own = File.expand_path(USERDIR).downcase.start_with?(File.join(File.expand_path(Dir.tmpdir), "kr_save_check").downcase)
  FileUtils.rm_rf(USERDIR) if own
end
