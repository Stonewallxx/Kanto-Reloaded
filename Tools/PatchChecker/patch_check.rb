# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Patch Checker
#==============================================================================
# For mod makers, before a release: checks a mod's DataPatches against KIF
# Beta's real data, outside the game, and lists every error and warning by
# file and patch, in the same words the Patch Viewer uses. Nothing in KIF
# Beta or the mod is changed.
#
#   ruby Tools/PatchChecker/patch_check.rb "<KIF Beta>" "<your mod's folder>"
#
# More mod folders after the first load after it, in that order, to check
# them together (conflicts between them show as warnings):
#
#   ruby Tools/PatchChecker/patch_check.rb "<KIF Beta>" "Mods/MyMod" "Mods/OtherMod"
#
# Exits 1 when a patch is rejected (it would be skipped in the game), else 0.
# Documentation/DataPatches.md explains each target and operation.
#==============================================================================
require "fileutils"
require "tmpdir"

if ARGV.length < 2
  puts "Usage: ruby Tools/PatchChecker/patch_check.rb \"<KIF Beta>\" \"<mod folder>\" [more mod folders...]"
  exit 2
end
KIF_ROOT = File.expand_path(ARGV[0])
FOLDERS = ARGV[1..-1].map { |f| File.expand_path(f, KIF_ROOT) }
missing = FOLDERS.reject { |f| File.directory?(f) }
unless missing.empty? && File.directory?(File.join(KIF_ROOT, "Data", "Scripts"))
  puts "Not found: #{(missing.empty? ? [File.join(KIF_ROOT, "Data", "Scripts")] : missing).join(", ")}"
  exit 2
end
USERDIR = Dir.mktmpdir("kr_patch_check")     # Kanto Reloaded's log and settings while it checks
$log = []

begin
  print "Loading KIF Beta's data... "
  load File.join(KIF_ROOT, "Mods/KantoReloaded/Tools/PatchChecker/game_data.rb")
  load File.join(KIF_ROOT, "Mods/KantoReloaded/Bootstrap.rb")
  DP = Reloaded::DataPatches
  puts "done (KIF Beta #{GameDataLoader.kif_version || "?"})."

  mods = FOLDERS.map do |folder|
    info = File.file?(File.join(folder, "mod.json")) ? (Reloaded::JSON.parse(File.read(File.join(folder, "mod.json"), :encoding => "UTF-8")) rescue nil) : nil
    info = {} unless info.is_a?(Hash)
    { :id => (info["id"] || File.basename(folder)).to_s, :name => (info["name"] || File.basename(folder)).to_s, :folder_path => folder }
  end
  DP.mods_override = mods
  DP.after_game_data_load

  errors = DP.errors
  warnings = DP.warnings
  mods.each do |mod|
    puts
    puts "#{mod[:name]} (#{mod[:folder_path]})"
    patches = DP.patches.select { |p| p[:mod_id] == mod[:id] }
    if patches.empty?
      folder = File.join(mod[:folder_path], DP::FOLDER)
      puts File.directory?(folder) ? "  No patches in #{DP::FOLDER}." : "  No #{DP::FOLDER} folder."
      next
    end
    patches.group_by { |p| p[:file] }.each do |file, ps|
      applied = ps.count { |p| !DP::Overview.rejected?(p) }
      puts "  #{File.basename(file)}: #{ps.length} patch#{ps.length == 1 ? "" : "es"}, #{applied} applied"
      ps.each do |p|
        what = [p[:target].to_s.empty? ? nil : DP.label(p[:target]), p[:id].to_s.empty? ? nil : p[:id]].compact.join(" ")
        where = "patch #{p[:index].to_i + 1}#{what.empty? ? "" : " (#{what})"}"
        found = errors.select { |e| e[:mod_id] == mod[:id] && e[:file] == file && e[:index] == p[:index] }.map { |e| e[:message] }
        found.unshift(p[:rejected]) if p[:rejected]
        found.uniq.each { |m| puts "    ERROR #{where}: #{m}" }
        warnings.select { |w| w[:mod_id] == mod[:id] && w[:file] == file && w[:index] == p[:index] }.map { |w| w[:message] }.uniq.each do |m|
          puts "    WARNING #{where}: #{m}"
        end
      end
    end
  end

  rejected = DP.patches.count { |p| DP::Overview.rejected?(p) }
  puts
  if rejected.zero?
    puts "Result: Every patch applies#{warnings.empty? ? "" : " (#{warnings.length} warning#{warnings.length == 1 ? "" : "s"}: load order decides those)"}."
  else
    puts "Result: #{rejected} patch#{rejected == 1 ? " is" : "es are"} rejected; the game skips #{rejected == 1 ? "it" : "them"} until fixed."
  end
  exit(rejected.zero? ? 0 : 1)
ensure
  # Only the temporary folder made above, in the system's temp folder
  own = File.expand_path(USERDIR).downcase.start_with?(File.join(File.expand_path(Dir.tmpdir), "kr_patch_check").downcase)
  FileUtils.rm_rf(USERDIR) if own
end
