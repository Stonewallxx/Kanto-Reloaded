# encoding: utf-8
# Checks Kanto Reloaded's saves outside the game: safe saving (a checked
# temporary file, putting things right after a crash), the save library
# (slots, previews and health, backups, restoring, the Backup Cap, deleting
# to the Deleted tab and back, old Kanto Reloaded's deleted saves, notes and
# colour tags) and What's New's notes, on real save files written as PIF
# writes them (Marshal) with stand-in players.
# Usage: ruby Tools/Tests/saves_test.rb "<KIF Beta>" <empty temp folder>
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

# PIF's save slots and raw reader (MultiSaves.rb, 001_SaveData.rb)
module SaveData
  SAVE_DIR = USERDIR
  MANUAL_SLOTS = ("A".."H").map { |l| "File #{l}" }
  AUTO_SLOTS = ["Auto 1", "Auto 2"]
  def self.get_full_path(slot); File.join(SAVE_DIR, "#{slot}.rxdata"); end
  def self.get_data_from_file(path); $raw_reads = $raw_reads.to_i + 1; File.open(path, "rb") { |f| Marshal.load(f) }; end
end
module KIF; PORT_VERSION = "0.21.57"; end

# A save, as PIF keeps one
Dex = Struct.new(:owned_count, :seen_count)
Player = Struct.new(:name, :money, :badge_count, :pokedex, :last_time_saved, :selected_difficulty, :id, :party, :girl, :save_slot) do
  def female?; girl; end
  def male?; !girl; end
end
MapStub = Struct.new(:map_id)
Factory = Struct.new(:map)
GameSystem = Struct.new(:save_count)
def write_save(slot, name, map_id: 5, money: 1200, id: 1001, remix: false, frames: 40 * 3600 * 2 + 40 * 60 * 12)
  data = { :player => Player.new(name, money, 3, Dex.new(41, 87), Time.local(2026, 10, 18, 15, 42, 0), 1, id, [], false, slot),
           :frame_count => frames, :map_factory => Factory.new(MapStub.new(map_id)),
           :switches => remix ? { 974 => true } : {}, :game_system => GameSystem.new(7), :game_version => "6.8.2" }
  File.open(SaveData.get_full_path(slot), "wb") { |f| Marshal.dump(data, f) }
  data
end
def pbGetMapNameFromId(id); { 5 => "Cerulean City", 7 => "Route 4" }[id] || "Map #{id}"; end
def backup_file(slot, stamp, tail = "")
  dir = File.join(USERDIR, "backups", slot)
  FileUtils.mkdir_p(dir)
  file = File.join(dir, "#{slot}_#{stamp}#{tail}.rxdata")
  FileUtils.cp(SaveData.get_full_path(slot), file)
  file
end

# KIF Beta's look for mod updates before the main menu (0.21.68+), stood in
module KIF
  module ModCatalogUI
    def self.startup_check
      $mod_checks = ($mod_checks || 0) + 1
      return true
    end
  end
end
load File.join(KIF_ROOT, "Mods/KantoReloaded/Bootstrap.rb")
R = Reloaded
S = R::Saves
WN = R::WhatsNew
check("Kanto Reloaded boots with its saves (#{R::Bootstrap.status}, #{R::Bootstrap.failures.inspect})", R::Bootstrap.status == :ready)
KIF::ModCatalogUI.startup_check
check("Startup Mod-Check, a Reloaded Systems setting, On at first: KIF's look for mod updates runs ($mod_checks)",
      R::Settings.definition(S::MOD_CHECK)[:page] == :systems && R::Settings.get(S::MOD_CHECK) == true && $mod_checks == 1)
R::Settings.set(S::MOD_CHECK, false)
skipped = KIF::ModCatalogUI.startup_check
check("...Off: it's skipped", skipped == false && $mod_checks == 1)
R::Settings.set(S::MOD_CHECK, true)
check("settings: Reloaded Load Screen (On), the Saves page's Save Manager and Backup Cap (Unlimited)",
      R::Settings.get(S::LOAD_SCREEN) == true && R::Settings.definition(:"saves.manager")[:type] == :button && S.cap.nil?)

#---------------------------------------------------------------- safe saving
path = SaveData.get_full_path("File A")
$Trainer = TrainerStub.new(111)                  # a game being played
SaveData.save_to_file(path)
$Trainer = nil
check("safe saving writes the save (#{File.size(path)} bytes), nothing left over",
      File.file?(path) && stored(path)[:player] && Dir.glob(File.join(USERDIR, "*.reloaded.*")).empty?)
before = File.binread(path)
module SaveData
  class << self
    alias test_compile compile_save_hash
    def compile_save_hash; {}; end              # a save that isn't whole
  end
end
failed = (SaveData.save_to_file(path) rescue $!)
check("a save that doesn't read back whole isn't written: the old one stays (#{failed.class})",
      failed.is_a?(IOError) && File.binread(path) == before && !File.file?(path + ".reloaded.tmp"))
module SaveData; class << self; alias compile_save_hash test_compile; end; end
File.rename(path, path + ".reloaded.previous")
File.write(path + ".reloaded.tmp", "half a save")
fixed = R::SafeSave.recover(USERDIR)
check("after a crash mid-save, the save comes back from before it (#{fixed} put right), leftovers gone",
      fixed == 1 && File.binread(path) == before && Dir.glob(File.join(USERDIR, "*.reloaded.*")).empty?)
File.binwrite(path + ".reloaded.tmp", before)          # a whole save that never took the save's place
File.binwrite(path + ".reloaded.previous", before)     # and the save from before it
R::SafeSave.recover(USERDIR)
kept_dir = File.join(USERDIR, "backups", "File A")
kept = File.directory?(kept_dir) ? Dir.children(kept_dir) : []
check("...a whole save left over is kept as a backup, never deleted (#{kept.inspect})",
      kept.any? { |f| f.end_with?("_Unfinished Save.rxdata") } && kept.any? { |f| f.end_with?("_Before Crash.rxdata") } &&
      File.binread(path) == before && Dir.glob(File.join(USERDIR, "*.reloaded.*")).empty?)
File.rename(kept_dir, kept_dir + " (crash check)")    # out of File A's backups, counted below

#---------------------------------------------------------------- slots and previews
write_save("File A", "Red")
write_save("File C", "Blue", :map_id => 7, :remix => true, :id => 2002)
check("slots: the save files there are (#{S.slots.inspect}), the first free one #{S.free_slot}",
      S.slots == ["File A", "File C"] && S.free_slot == "File B")
pv = S.preview(SaveData.get_full_path("File A"))
check("a preview: #{pv[:name]}, #{pv[:map]}, #{pv[:seconds] / 3600}h #{pv[:seconds] / 60 % 60}m, badges #{pv[:badges]}, Pokédex #{pv[:owned]}/#{pv[:seen]}, #{pv[:mode]}, #{pv[:health]}",
      pv[:name] == "Red" && pv[:map] == "Cerulean City" && pv[:seconds] == 2 * 3600 + 12 * 60 && pv[:badges] == 3 &&
      pv[:owned] == 41 && pv[:mode] == "Classic" && pv[:health] == :healthy && pv[:party] == [])
check("Remix from its switch (#{S.preview(SaveData.get_full_path("File C"))[:mode]})", S.preview(SaveData.get_full_path("File C"))[:mode] == "Remix")
reads = $raw_reads
S.preview(SaveData.get_full_path("File A"))
check("read once until the file changes", $raw_reads == reads)
S.save_kept_previews
S.reset
S.preview(SaveData.get_full_path("File A"), :party => false)
check("...and after a restart, a preview without the party comes from Save Previews.json, not the file", $raw_reads == reads)
check("a preview with the party reads the file", (S.preview(SaveData.get_full_path("File A")) && $raw_reads == reads + 1))

# health
File.binwrite(SaveData.get_full_path("File E"), File.binread(SaveData.get_full_path("File A"))[0, 60])
File.binwrite(SaveData.get_full_path("File F"), "")
class GoneMod; end
File.open(SaveData.get_full_path("File G"), "wb") { |f| Marshal.dump(write_save("File G", "Green").merge(:mod => GoneMod.new), f) }
Object.send(:remove_const, :GoneMod)
he = S.health(SaveData.get_full_path("File E"))
hf = S.health(SaveData.get_full_path("File F"))
hg = S.health(SaveData.get_full_path("File G"))
check("health: cut short is Damaged (#{he[1]})", he[0] == :damaged && he[1].include?("cut short"))
check("health: empty is Damaged", hf[0] == :damaged && hf[1].include?("empty"))
check("health: a class the game hasn't got (a removed mod's) is Check, by name (#{hg[1]})", hg[0] == :check && hg[1].include?("GoneMod"))
%w[E F G].each { |l| File.delete(SaveData.get_full_path("File #{l}")) }

#---------------------------------------------------------------- backups
backup_file("File A", "20261018120000")
backup_file("File A", "20261018130000", "_autosave")
write_save("File A", "Red", :money => 999)
named = backup_file("File A", "20261018140000", "_Before Misty")
write_save("File A", "Red", :money => 5)
list = S.backups("File A")
check("backups, newest first, named and autosave ones told apart (#{list.map { |b| [b[:stamp][8, 4], b[:name], b[:auto]] }.inspect})",
      list.map { |b| b[:stamp] } == %w[20261018140000 20261018130000 20261018120000] && list[0][:name] == "Before Misty" &&
      list[1][:auto] && list[2][:name].nil? && list[0][:time] == Time.local(2026, 10, 18, 14, 0, 0))
renamed = S.name_backup(list[2], "First: Gym?")
check("naming a backup (characters a file can't have go): #{File.basename(renamed)}", File.basename(renamed) == "File A_20261018120000_First Gym.rxdata")
S.restore_backup("File A", S.backups("File A").find { |b| b[:name] == "Before Misty" })
check("restoring a backup: the save is that backup again (money #{S.preview(SaveData.get_full_path("File A"))[:money]})",
      S.preview(SaveData.get_full_path("File A"))[:money] == 999)
check("...and the save as it was is kept, named Before Restore", S.backups("File A").any? { |b| b[:name] == "Before Restore" })
$Trainer = Player.new("Red", 0, 0, nil, nil, 0, 1001, [], false, "File A")
check("at the title screen nothing is being played, though PIF holds a save's $Trainer", S.playing.nil?)
class Scene_Map; end unless defined?(Scene_Map)
$scene = Scene_Map.new                           # on the map: File A is being played
refused = (S.restore_backup("File A", S.backups("File A").first) rescue $!)
check("the save being played can't be restored over (#{refused.message})", refused.is_a?(ArgumentError) && S.playing == "File A")
$scene = nil
$Trainer = nil
5.times { |i| backup_file("File A", "2026101700000#{i}") }
plain = S.backups("File A").count { |b| b[:name].nil? && !b[:auto] }
gone = S.trim_backups("File A", 2)
check("without a Recycle Bin (plain Ruby has no Win32API) the Backup Cap keeps every backup (#{gone} gone)",
      gone == 0 && S.backups("File A").count { |b| b[:name].nil? && !b[:auto] } == plain)
# The game's Recycle Bin, stood in for by a folder in the test's own (the real
# call is SHFileOperationW, checked on Windows by hand)
RECYCLE_BIN = File.join(USERDIR, "Recycle Bin")
module Reloaded::Paths
  class << self
    def recycle(path)
      FileUtils.mkdir_p(RECYCLE_BIN)
      File.rename(path, File.join(RECYCLE_BIN, File.basename(path)))
      return true
    end
  end
end
gone = S.trim_backups("File A", 2)
check("Backup Cap 2: the oldest plain backups go to the Recycle Bin (#{gone} of #{plain}), named and autosave ones stay",
      gone == plain - 2 && S.backups("File A").count { |b| b[:name].nil? && !b[:auto] } == 2 &&
      S.backups("File A").any? { |b| b[:auto] } && S.backups("File A").count { |b| b[:name] } == 3 &&
      Dir.children(RECYCLE_BIN).length == gone)
R::Settings.set(:"saves.backup_cap", 1)                  # 10
12.times { |i| backup_file("File C", format("202610160000%02d", i)) }
R::Events.emit(:saved, :path => SaveData.get_full_path("File C"))
check("after each save, Backup Cap 10 trims that save's backups (#{S.backups("File C").length})", S.backups("File C").length == 10)
R::Settings.set(:"saves.backup_cap", 0)

#---------------------------------------------------------------- notes and tags
S.set_note("File C", "Nuzlocke: dupes clause")
S.set_tag("File C", "Blue")
check("a note and a colour tag (#{S.note("File C").inspect}, #{S.tag("File C")}, #{S.tag_rgb("Blue").inspect})",
      S.note("File C") == "Nuzlocke: dupes clause" && S.tag("File C") == "Blue" && S.tag_rgb("Blue"))
S.set_note("File A", "Main run")
write_save("File A", "Leaf", :id => 9999)
S.forget(SaveData.get_full_path("File A"))
check("a new save in the slot (another player) doesn't take the old one's note", S.note("File A") == "")

#---------------------------------------------------------------- the Deleted tab
FileUtils.mkdir_p(File.join(R::Paths.data_dir, "Saves"))
kr = File.join(R::Paths.data_dir, "Saves", "File C.rxdata.kr")
File.write(kr, "kr data")
c_backups = S.backups("File C").length
folder = S.archive("File C")
manifest = JSON.parse(File.read(File.join(folder, "manifest.json")))
check("deleting File C: the save, its backups and Kanto Reloaded's copy move to DELETED SAVES (#{File.basename(folder)})",
      !File.file?(SaveData.get_full_path("File C")) && !File.directory?(File.join(USERDIR, "backups", "File C")) &&
      File.file?(File.join(folder, "File C.rxdata")) && File.directory?(File.join(folder, "backups")) && File.file?(File.join(folder, "File C.rxdata.kr")))
check("...with old Kanto Reloaded's manifest, plus its note and tag", manifest["schema_version"] == 1 && manifest["slot"] == "File C" &&
      manifest["files"].any? { |f| f["original_name"] == "File C.rxdata" } && manifest["kanto_reloaded"]["note"] == "Nuzlocke: dupes clause")
a = S.archived.first
check("the Deleted tab lists it, note and tag kept (#{a && [a[:slot], a[:note], a[:tag]].inspect})",
      a && a[:slot] == "File C" && a[:note] == "Nuzlocke: dupes clause" && a[:tag] == "Blue" && S.note("File C") == "")
write_save("File C", "Someone Else", :id => 3003)
back = S.restore_archive(a)
check("restoring it while File C is taken: it comes back as #{back}, its backups renamed with it",
      back == "File B" && S.preview(SaveData.get_full_path("File B"))[:name] == "Blue" &&
      S.backups("File B").length == c_backups && S.note("File B") == "Nuzlocke: dupes clause" && S.archived.empty? &&
      File.file?(File.join(R::Paths.data_dir, "Saves", "File B.rxdata.kr")))
old = File.join(USERDIR, "DELETED SAVES", "File D-20250101-120000")
FileUtils.mkdir_p(old)
write_save("File D", "Old Run")
File.rename(SaveData.get_full_path("File D"), File.join(old, "File D.rxdata"))
File.write(File.join(old, "manifest.json"), JSON.generate({ "schema_version" => 1, "slot" => "File D", "archived_at" => "2025-01-01T12:00:00Z",
                                                            "files" => [{ "original_name" => "File D.rxdata" }] }))
od = S.archived.first
check("old Kanto Reloaded's deleted saves show too (#{od && od[:slot]}, #{od && od[:archived_at].year})", od && od[:slot] == "File D" && od[:old])
check("...and restore", S.restore_archive(od) == "File D" && S.preview(SaveData.get_full_path("File D"))[:name] == "Old Run")
bak = File.join(USERDIR, "File D.rxdata.bak")
File.write(bak, "File D's own .bak")
S.archive("File D")                                  # its .bak goes with it
File.write(bak, "someone's other file")              # then another file takes that name
refused = (S.restore_archive(S.archived.first) rescue $!)
check("restoring stops before moving anything when a file is in the way, which stays as it was (#{refused.message rescue refused})",
      refused.is_a?(ArgumentError) && File.read(bak) == "someone's other file" &&
      !File.file?(SaveData.get_full_path("File D")) && S.archived.first && File.file?(S.archived.first[:file].to_s) &&
      File.read(File.join(S.archived.first[:dir], "File D.rxdata.bak")) == "File D's own .bak")
File.rename(bak, File.join(USERDIR, "other file.txt"))
outside = File.join(USERDIR, "not deleted")
FileUtils.mkdir_p(outside)
File.write(File.join(outside, "keep.txt"), "mine")
refused = (S.delete_archive({ :dir => outside }) rescue $!)
check("Delete Forever only ever removes a folder in DELETED SAVES (#{refused.class})",
      refused.is_a?(ArgumentError) && File.file?(File.join(outside, "keep.txt")))
S.delete_archive(S.archived.first)
check("Delete Forever: gone", S.archived.empty? && !File.file?(SaveData.get_full_path("File D")))

#---------------------------------------------------------------- What's New
srcs = WN.sources
kr_src = srcs.find { |s| s[:name] == "Kanto Reloaded" }
kif_src = srcs.find { |s| s[:name] == "KIF Beta" }
check("What's New: Kanto Reloaded's notes from Changelog.md (#{kr_src && kr_src[:versions].map(&:version).inspect})",
      kr_src && kr_src[:versions].first.version == R.version && kr_src[:versions].first.notes.length > 3)
check("KIF Beta's from update_notes.txt (#{kif_src && kif_src[:versions].first.version}: #{kif_src && kif_src[:versions].first.notes.first.inspect})",
      kif_src && kif_src[:versions].first.version == "0.21.57" && !kif_src[:versions].first.notes.empty?)
kept = JSON.parse(File.read(File.join(R::Paths.settings_dir, "Whats New.json")))
check("...kept, so KIF's older notes stay after it updates", kept["kif"]["0.21.57"]["notes"].length >= 1)
parsed = WN.parse("# Mod\n## 1.1.0 (2026-10-20)\n- Faster\n  - much faster\n## 1.0.0\n- First\n")
check("a changelog: versions newest first, notes and the notes under them",
      parsed.map(&:version) == ["1.1.0", "1.0.0"] && parsed[0].date == "2026-10-20" && parsed[0].notes == [["Faster", 0], ["much faster", 1]])
WN.add("Hard Trainers+", "2.0", ["Gym leaders: Harder"], "2026-10-19")
WN.add("Hard Trainers+", "1.0", ["First"], "2026-09-01")
ht = WN.sources.find { |s| s[:name] == "Hard Trainers+" }
check("a mod's notes from its scripts (#{ht && ht[:versions].map(&:version).inspect})", ht && ht[:versions].map(&:version) == ["2.0", "1.0"])
check("the first time, only each source's newest version is new",
      WN.new?("Hard Trainers+", "2.0") && !WN.new?("Hard Trainers+", "1.0") && WN.new?("Kanto Reloaded", R.version) && WN.unseen?)
WN.mark_seen
check("read: nothing new", !WN.unseen?)

errors = File.read(R::Log.path).lines.grep(/ERROR/)
check("no errors in the log (#{errors.length})", errors.empty?)
errors.first(5).each { |l| puts "  " + l }
puts($failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED")
exit($failed ? 1 : 0)
