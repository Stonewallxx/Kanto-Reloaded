# encoding: utf-8
# Checks the Save Checker on KIF Beta's real data: saves written as PIF
# writes them (Marshal), with Pokémon, items, moves and abilities the game
# hasn't got, a removed mod's own objects, and Kanto Reloaded's parts. The
# checks, the quick check behind the Save Manager's badge, Keep Aside and
# Remove, Keep Aside's return, Make It Loadable, the reader's stand-ins,
# all-or-nothing upgrades and the report file.
# Usage: ruby Tools/Tests/save_check_test.rb "<KIF Beta>" <empty temp folder>
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

#---------------------------------------------------------------- the game's data and save classes
load File.join(KIF_ROOT, "Mods/KantoReloaded/Tools/PatchChecker/game_data.rb")
G = GameData
check("KIF Beta's data loaded (#{G::Species::DATA.length} species keys)", G::Species::DATA.key?(:CHARMANDER) && G::Move::DATA.key?(:EMBER))

# PIF's save classes, as far as the checker reads them. Their source is a
# game script's name, as in the game, so they count as the game's.
eval(<<~'RUBY', TOPLEVEL_BINDING, "001_Pokemon.rb", 1)
  class Pokemon
    attr_accessor :species, :name, :item, :moves, :ability, :personalID, :level
    def initialize(species, level = 5, name = nil)
      @species = species
      @level = level
      @name = name
      @item = nil
      @moves = [Pokemon::Move.new(:TACKLE)]
      @ability = nil
      @personalID = rand(2**30)
    end
    class Move
      attr_accessor :id, :pp
      def initialize(id); @id = id; @pp = 10; end
    end
  end
  class Player
    attr_accessor :name, :party, :last_time_saved, :id, :save_slot
    def initialize(name); @name = name; @party = []; @id = 4242; @last_time_saved = Time.now - 600; end
  end
  class PokemonBox
    attr_reader :pokemon
    def initialize(name); @name = name; @pokemon = Array.new(30); end
  end
  class PokemonStorage
    attr_reader :boxes
    def initialize; @boxes = (1..3).map { |i| PokemonBox.new(i == 2 ? "Shinies" : "Box #{i}") }; end
    def pbStoreCaught(pk)
      @boxes.each_with_index { |b, i| j = b.pokemon.index(nil); (b.pokemon[j] = pk; return i) if j }
      return -1
    end
  end
  class PokemonBag
    attr_reader :pockets
    def self.pocketNames; ["", "Items", "Medicine", "Poké Balls", "TMs & HMs", "Berries", "Mail", "Battle Items", "Key Items"]; end
    def initialize; @pockets = Array.new(9) { [] }; @registeredItems = []; end
    def pbStoreItem(item, qty = 1); @pockets[1] << [item, qty]; return true; end
  end
  class PCItemStorage
    attr_reader :items
    def initialize; @items = []; end
  end
  class PokemonGlobalMetadata
    attr_accessor :daycare, :pcItemStorage
  end
RUBY

load File.join(KIF_ROOT, "Mods/KantoReloaded/Tools/Tests/test_stubs.rb")
# PIF's save values, registered from a game script (the stubs' :player came
# from a test file)
SaveData.instance_variable_set(:@values, [])
eval(<<~'RUBY', TOPLEVEL_BINDING, "004_Game_SaveValues.rb", 1)
  [:player, :bag, :storage_system, :global_metadata, :frame_count, :switches].each do |id|
    SaveData.register(id) do
      save_value { $save_values[id] }
      load_value { |v| $save_values[id] = v }
    end
  end
RUBY
$save_values = {}
module SaveData
  SAVE_DIR = USERDIR
  MANUAL_SLOTS = ("A".."H").map { |l| "File #{l}" }
  AUTO_SLOTS = ["Auto 1", "Auto 2"]
  def self.get_full_path(slot); File.join(SAVE_DIR, "#{slot}.rxdata"); end
  def self.get_data_from_file(path); File.open(path, "rb") { |f| Marshal.load(f) }; end
end
module KIF; PORT_VERSION = "0.21.59"; end

load File.join(KIF_ROOT, "Mods/KantoReloaded/Bootstrap.rb")
R = Reloaded
SC = R::SaveCheck
check("Kanto Reloaded boots with the Save Checker (#{R::Bootstrap.status}, #{R::Bootstrap.failures.inspect})",
      R::Bootstrap.status == :ready && defined?(SC::Fix) && R::SaveStore.registered.key?("save_check"))
MODS = File.join(USERDIR, "Mods")
SC::ModData::Search.root = MODS

#---------------------------------------------------------------- saves like a player's
def mon(species, level = 10, name = nil)
  pk = Pokemon.new(species, level, name)
  pk
end

def save_hash(party: [], boxes: {}, bag: {}, daycare: nil, pc_items: [], reloaded: nil, extra: {})
  player = Player.new("Red")
  player.party = party
  storage = PokemonStorage.new
  boxes.each { |(b, s), pk| storage.boxes[b].pokemon[s] = pk }
  b = PokemonBag.new
  bag.each { |pocket, items| b.pockets[pocket].concat(items) }
  global = PokemonGlobalMetadata.new
  global.daycare = [[daycare, daycare ? 20 : 0], [nil, 0]]
  global.pcItemStorage = PCItemStorage.new
  global.pcItemStorage.items.concat(pc_items)
  data = { :player => player, :bag => b, :storage_system => storage, :global_metadata => global,
           :frame_count => 40 * 3600, :switches => [] }
  data[:reloaded] = reloaded if reloaded
  return data.merge(extra)
end

def write_save(slot, data)
  path = SaveData.get_full_path(slot)
  File.binwrite(path, Marshal.dump(data))
  return path
end

def reread(path); File.open(path, "rb") { |f| Marshal.load(f) }; end
KR_PART = { "schema" => 1, "versions" => { "save_check" => 1 }, "sections" => { "settings" => { "theme" => "Ocean Blue" } } }.freeze

#---------------------------------------------------------------- a healthy save
healthy = write_save("File A", save_hash(party: [mon(:CHARMANDER), mon(:PIKACHU)], reloaded: Marshal.load(Marshal.dump(KR_PART))))
r = SC.run(healthy)
check("a healthy save: Healthy, every check OK (#{r.verdict}; #{r.checks.map { |c| [c.title, c.state] }.inspect})",
      r.state == :ok && r.verdict == "Healthy" && r.checks.map(&:id) == [:file, :kr, :upgrades, :plain, :missing, :mods] &&
      r.checks.all? { |c| c.state == :ok })
# the save says it was made 10 minutes ago: in the first 10 minutes after
# midnight that's yesterday
SAVED_DAY = (Time.now - 600).day == Time.now.day ? "today" : "yesterday"
check("...File: it loads, its size and when it was saved (#{r.checks[0].line})", r.checks[0].line =~ /\ALoads\. \d+ KB, saved #{SAVED_DAY}/)
check("...Kanto Reloaded Data: its parts (#{r.checks[1].line})", r.checks[1].line == "Found: 1 part.")
check("...Mod Data: Kanto Reloaded only, safe to remove (#{r.mods.map { |m| [m.name, m.needed, m.keys] }.inspect})",
      r.mods.length == 1 && r.mods[0].kr && !r.mods[0].needed && r.mods[0].keys == [:reloaded])
check("...the save values of the game itself aren't a mod's", r.mods.none? { |m| m.keys.include?(:player) })

#---------------------------------------------------------------- missing content
fuecoco = mon(:FUECOCO, 9)
held = mon(:BULBASAUR, 12)
held.item = :MEGA_RING
moved = mon(:SQUIRTLE, 14, "Shelly")
moved.moves = [Pokemon::Move.new(:WATERGUN), Pokemon::Move.new(:KR_GONE_MOVE)]
abil = mon(:ODDISH, 8)
abil.ability = :KR_GONE_ABILITY
fusion_ok = mon(:B4H25, 20)
fusion_gone = mon(:B4H9999, 20)
sprig = mon(:SPRIGATITO, 12)
data = save_hash(party: [mon(:CHARMANDER), held, moved, abil, fusion_ok, fuecoco],
                 boxes: { [1, 6] => sprig, [0, 0] => fusion_gone },
                 bag: { 8 => [[:MEGA_RING, 1]], 1 => [[:POTION, 3], [:KR_GONE_POTION, 2]] },
                 daycare: mon(:KR_GONE_DAYCARE, 20),
                 pc_items: [[:KR_GONE_STORED, 4]],
                 reloaded: Marshal.load(Marshal.dump(KR_PART)))
missing = write_save("File B", data)
r = SC.run(missing, :slot => "File B")
kinds = r.missing.map { |m| [m.kind, m.id] }
check("Missing Content finds each: Pokémon in the party, a box and the Day Care, a held item, a move, an ability, bag and PC items (#{kinds.inspect})",
      kinds.sort_by(&:to_s) == [[:ability, :KR_GONE_ABILITY], [:item, :KR_GONE_POTION], [:item, :KR_GONE_STORED], [:item, :MEGA_RING],
                                [:item, :MEGA_RING], [:move, :KR_GONE_MOVE], [:pokemon, :B4H9999], [:pokemon, :FUECOCO],
                                [:pokemon, :KR_GONE_DAYCARE], [:pokemon, :SPRIGATITO]].sort_by(&:to_s))
check("...a fusion of two Pokémon the game has isn't missing (B4H25)", kinds.none? { |_k, id| id == :B4H25 })
wheres = r.missing.map(&:where)
check("...where each one is, party first (#{wheres.inspect})",
      wheres[0] == "Party, slot 2, held by Bulbasaur" && wheres.include?("Party, slot 6") && wheres.include?("Day Care") &&
      wheres.include?("Shinies, slot 7") && wheres.include?("Box 1, slot 1") && wheres.include?("Bag: Key Items") &&
      wheres.include?("PC: Items") && wheres.include?("Party, slot 3, Shelly's move"))
check("...party members are marked", r.missing.select(&:party).map(&:id).sort_by(&:to_s) == [:FUECOCO, :KR_GONE_ABILITY, :KR_GONE_MOVE, :MEGA_RING].sort_by(&:to_s))
line = r.checks.find { |c| c.id == :missing }
check("...a missing move is a problem, the rest notes (#{line.state}: #{line.line})",
      line.state == :problem && line.line == "4 Pokémon, 4 items, 1 move and 1 ability." && r.state == :problem && r.verdict == "1 Problem")
check("...names to show for ids the game hasn't got", r.missing.find { |m| m.id == :KR_GONE_POTION }.name == "Kr Gone Potion")

quick = SC::Content.scan(reread(missing), :quick => true)
check("the quick check (the badge) sees the party, the boxes, the Day Care and the bag, not the PC's items (#{quick.length})",
      quick.length == 9 && quick.none? { |m| m.id == :KR_GONE_STORED })
pv = R::Saves.preview(missing)
check("the Save Manager's badge: CHECK, with what's missing (#{pv[:health]}: #{pv[:problem]})",
      pv[:health] == :check && pv[:problem].include?("A missing move can crash a battle"))

#---------------------------------------------------------------- the fixes
r.missing.each { |m| m.fix = :keep }
r.missing.find { |m| m.id == :KR_GONE_POTION }.fix = :remove
moved_party = r.missing.find { |m| m.id == :KR_GONE_MOVE }
done = SC::Fix.content(r, r.missing)
after = reread(missing)
check("Fix: 9 kept aside, 1 removed, a backup named Before Save Check first (#{done.inspect})",
      done[:kept] == 9 && done[:removed] == 1 && File.basename(done[:backup].to_s).include?("Before Save Check"))
check("...the backup is the save as it was", reread(done[:backup])[:player].party.length == 6)
party = after[:player].party.map(&:species)
check("...out of the party (the rest keep their order) (#{party.inspect})", party == [:CHARMANDER, :BULBASAUR, :SQUIRTLE, :ODDISH, :B4H25])
check("...held item off, the move gone (Water Gun stays), the ability reset",
      after[:player].party[1].item.nil? && after[:player].party[2].moves.map(&:id) == [:WATERGUN] && after[:player].party[3].ability.nil?)
check("...out of the boxes and the Day Care", after[:storage_system].boxes[1].pokemon[6].nil? && after[:storage_system].boxes[0].pokemon[0].nil? &&
      after[:global_metadata].daycare[0] == [nil, 0])
check("...out of the bag and the PC (Potion stays)", after[:bag].pockets[8].empty? && after[:bag].pockets[1] == [[:POTION, 3]] &&
      after[:global_metadata].pcItemStorage.items.empty?)
kept = after[:reloaded]["sections"]["save_check"]["kept"]
check("...kept aside in Kanto Reloaded's part of the save (#{kept.map { |k| k["id"] }.inspect})",
      kept.length == 9 && kept.find { |k| k["id"] == "FUECOCO" }["dump"].is_a?(String) && kept.none? { |k| k["id"] == "KR_GONE_POTION" })
r2 = SC.run(missing, :slot => "File B")
check("...checked again: Healthy, its Kanto Reloaded data still plain values (#{r2.verdict}; #{r2.checks.map(&:state).inspect})",
      r2.missing.empty? && r2.checks.find { |c| c.id == :plain }.state == :ok && r2.state == :ok)
check("a fix refuses a save that changed since it was checked", (SC::Fix.content(r, r.missing) rescue $!).is_a?(ArgumentError))

lonely = mon(:SQUIRTLE, 5)
lonely.moves = [Pokemon::Move.new(:KR_GONE_MOVE)]
alone = write_save("File C", save_hash(party: [lonely]))
r3 = SC.run(alone, :slot => "File C")
r3.missing.each { |m| m.fix = :remove }
SC::Fix.content(r3, r3.missing)
moves = reread(alone)[:player].party[0].moves.map(&:id)
check("a Pokémon whose only move goes gets one its species learns (#{moves.inspect})", moves.length == 1 && G::Move::DATA.key?(moves[0]))
check("...and a save with no Kanto Reloaded part gets none for Remove", reread(alone)[:reloaded].nil?)

#---------------------------------------------------------------- Keep Aside, back again
kept_data = reread(missing)
R::SaveStore.send(:from_save, kept_data[:reloaded])
$Trainer = kept_data[:player]
$PokemonStorage = kept_data[:storage_system]
$PokemonBag = kept_data[:bag]
check("nothing comes back while the game still hasn't got it", SC::KeptAside.give_back.empty? && SC::KeptAside.waiting.length == 9)
G::Species::DATA[:FUECOCO] = G::Species::DATA[:CHARMANDER]
G::Item::DATA[:MEGA_RING] = G::Item::DATA[:POTION]
G::Move::DATA[:KR_GONE_MOVE] = G::Move::DATA[:TACKLE]
back = SC::KeptAside.give_back
check("when it has: the Pokémon into the PC, the items into the Bag, the move onto its Pokémon (#{back.inspect})",
      back.include?("Fuecoco (in the PC)") && back.count { |w| w == "Mega Ring (in the Bag)" } == 2 && back.include?("Kr Gone Move (on Shelly)"))
check("...in the PC for real, and Shelly knows it again",
      $PokemonStorage.boxes.flatten.map(&:pokemon).flatten.compact.any? { |pk| pk.species == :FUECOCO } &&
      $Trainer.party[2].moves.map(&:id) == [:WATERGUN, :KR_GONE_MOVE])
check("...the rest still waits (#{SC::KeptAside.waiting.map { |k| k["id"] }.inspect})", SC::KeptAside.waiting.length == 5)
check("...and a message waits for the map", SC::KeptAside.pending_words.length == 4)
G::Species::DATA.delete(:FUECOCO)
G::Item::DATA.delete(:MEGA_RING)
G::Move::DATA.delete(:KR_GONE_MOVE)

#---------------------------------------------------------------- a removed mod's objects
FileUtils.mkdir_p(File.join(MODS, "MegaMod"))
File.write(File.join(MODS, "MegaMod", "mega.rb"), "module MegaMod\n  class Data\n  end\nend\nSaveData.register(:mega_mod) do\nend\n")
module MegaMod
  class Data
    def initialize; @level = 3; @seen = [:CHARIZARD]; end
  end
  class Packed
    def initialize(s); @s = s; end
    def _dump(_l); @s; end
    def self._load(s); new(s); end
  end
  class Kept
    def initialize(v); @v = v; end
    def marshal_dump; [@v, 1]; end
    def marshal_load(a); @v = a[0]; end
  end
end
module GoneMod
  class Badge
    def initialize; @shiny = true; end
  end
end
player = Player.new("Red")
player.party = [mon(:CHARMANDER)]
player.instance_variable_set(:@gone_badge, GoneMod::Badge.new)
modsave = save_hash(party: [mon(:CHARMANDER)], reloaded: Marshal.load(Marshal.dump(KR_PART)),
                    extra: { :mega_mod => { "data" => MegaMod::Data.new, "packed" => MegaMod::Packed.new("abc"), "kept" => MegaMod::Kept.new(7) },
                             :plain_mod => { "count" => 3 } })
modsave[:player] = player
original = Marshal.dump(modsave)
modfile = File.join(USERDIR, "File D.rxdata")
File.binwrite(modfile, original)
Object.send(:remove_const, :MegaMod)
Object.send(:remove_const, :GoneMod)
plain_fail = (reread(modfile) rescue $!)
check("the game can't read it now (#{plain_fail.class}: #{plain_fail.message[0, 50]})", plain_fail.is_a?(ArgumentError))

back_out = nil
SC::Reader.open(modfile) do |d, missing_classes|
  back_out = Marshal.dump(d)
  check("the reader stands in for what's missing (#{missing_classes.inspect})",
        missing_classes.sort == ["GoneMod::Badge", "MegaMod::Data", "MegaMod::Kept", "MegaMod::Packed"] && d[:mega_mod]["data"].is_a?(SC::Stub))
end
check("...and writes it back exactly as it was read (_dump, marshal_dump and plain objects alike)", back_out == original)
check("...and takes its stand-ins away after", !defined?(MegaMod) && !defined?(GoneMod))

r = SC.run(modfile, :slot => "File D")
file_line = r.checks.find { |c| c.id == :file }
check("File: needs the mods that made what it holds (#{file_line.line})",
      file_line.state == :problem && file_line.line.include?("MegaMod") && file_line.line.include?("Unknown Mod (GoneMod)"))
mega = r.mods.find { |m| m.name == "MegaMod" }
check("Mod Data: MegaMod found in the mod folders, off, needed to load, with its save value (#{mega.to_a.first(4).inspect})",
      mega && mega.installed == :off && mega.needed && mega.keys == [:mega_mod] && mega.classes.keys.sort == ["MegaMod::Data", "MegaMod::Kept", "MegaMod::Packed"])
gone = r.mods.find { |m| m.name == "Unknown Mod (GoneMod)" }
check("...a mod that's gone: its object on the trainer, needed (#{gone && gone.classes.inspect})", gone && gone.needed && gone.classes["GoneMod::Badge"] == [:player])
plain = r.mods.find { |m| m.name == "Unknown Mod (plain_mod)" }
check("...a mod with plain values only is safe to remove", plain && !plain.needed && plain.keys == [:plain_mod])
check("...the Mod Data line says what stops it (#{r.checks.find { |c| c.id == :mods }.line})",
      r.checks.find { |c| c.id == :mods }.state == :problem)

done = SC::Fix.make_loadable(r)
fixed = (reread(modfile) rescue $!)
check("Make It Loadable: the game reads it now (#{fixed.class})", fixed.is_a?(Hash) && !fixed.key?(:mega_mod) && fixed.key?(:plain_mod))
check("...the trainer keeps everything but the gone mod's object",
      fixed[:player].party.length == 1 && !fixed[:player].instance_variable_defined?(:@gone_badge))
check("...a backup first, and a side file with what was set aside (#{done[:values].inspect}, #{done[:inside]} inside)",
      File.basename(done[:backup].to_s).include?("Before Make It Loadable") && File.file?(done[:side_file]) &&
      done[:values] == [:mega_mod] && done[:inside] == 1 && File.file?(done[:side_file].sub(/\.rxdata\z/, ".md")))
SC::Reader.open(done[:side_file]) do |d, _m|
  check("...the side file holds the mod's data as it was", d["values"][:mega_mod]["packed"].kr_held == "abc" && d["inside"][0][0] == "player > @gone_badge")
end
check("...checked again: no problem with the file", SC.run(modfile, :slot => "File D").checks.find { |c| c.id == :file }.state == :ok)

#---------------------------------------------------------------- upgrades, all or nothing
R::SaveStore.register(:kr_test_a, :version => 2, :migrate => proc { |d, _from| d.merge("upgraded" => true) })
R::SaveStore.register(:kr_test_b, :version => 3, :migrate => proc { |_d, _from| raise "broken upgrade" })
old = { "schema" => 1, "versions" => { "kr_test_a" => 1, "kr_test_b" => 1 },
        "sections" => { "kr_test_a" => { "x" => 1 }, "kr_test_b" => { "y" => 2 } } }
upfile = write_save("File E", save_hash(reloaded: Marshal.load(Marshal.dump(old))))
r = SC.run(upfile, :slot => "File E")
up = r.checks.find { |c| c.id == :upgrades }
check("Upgrades: parts on an older version are a note (#{up.line})", up.state == :note && up.line.include?("Kr Test A: Version 1 to 2") && up.line.include?("And 1 more"))
loaded = R::SaveStore.send(:from_save, Marshal.load(Marshal.dump(old)))
check("one upgrade fails: none apply, both parts' old data is held, and they start empty",
      loaded["held"].keys.sort == ["kr_test_a", "kr_test_b"] && loaded["held"]["kr_test_a"]["data"] == { "x" => 1 } &&
      loaded["sections"]["kr_test_a"] == {} && loaded["held"]["kr_test_b"]["error"].include?("broken upgrade"))
File.binwrite(upfile, Marshal.dump(save_hash(reloaded: loaded)))
up = SC.run(upfile, :slot => "File E").checks.find { |c| c.id == :upgrades }
check("...the check says so: held, nothing lost (#{up.line})", up.state == :problem && up.line.include?("old data is held"))
R::SaveStore.register(:kr_test_b, :version => 3, :migrate => proc { |d, _from| d.merge("fixed" => true) })
again = R::SaveStore.send(:from_save, loaded)
check("...a later Kanto Reloaded that can upgrade it takes it back from held",
      again["held"].empty? && again["sections"]["kr_test_a"] == { "x" => 1, "upgraded" => true } && again["sections"]["kr_test_b"] == { "y" => 2, "fixed" => true })
R::SaveStore.instance_variable_get(:@sections).delete("kr_test_a")
R::SaveStore.instance_variable_get(:@sections).delete("kr_test_b")

#---------------------------------------------------------------- what's left
broken = File.join(USERDIR, "File F.rxdata")
File.binwrite(broken, Marshal.dump(save_hash)[0, 200])
r = SC.run(broken, :slot => "File F")
check("a cut-short save: Damaged (#{r.verdict}: #{r.sub})", r.state == :damaged && r.verdict == "Damaged")
r = SC.run(healthy)
file = SC.write_report(r)
text = File.read(file, :encoding => "UTF-8")
check("Save the Report: a Markdown report in Logging\\Save Checks (#{File.basename(file)})",
      text.start_with?("# Save Check: File A") && text.include?("| Missing Content | OK |") && SC.newest_report("File A") == file)
bk_dir = File.join(USERDIR, "backups", "File A")
FileUtils.mkdir_p(bk_dir)
bk = File.join(bk_dir, "File A_20261019120000.rxdata")
FileUtils.cp(healthy, bk)
r = SC.run(bk, :backup => true)
check("a backup is checked as File A's, and fixes refuse it (#{r.slot})", r.slot == "File A" && SC::Fix.refusal(r).to_s.start_with?("This is a backup"))

tool = File.join(KIF_ROOT, "Mods/KantoReloaded/Tools/SaveChecker/save_check.rb")
out = IO.popen(["ruby", tool, KIF_ROOT, healthy], :err => File::NULL, &:read)
check("the Tools script checks a save outside the game, every class stood in for (exit #{$?.exitstatus})",
      $?.exitstatus == 0 && out.include?("# Save Check: File A") && out.include?("| File | OK |"))

errors = File.read(R::Log.path).lines.grep(/ERROR/).reject { |l| l.include?("couldn't be read") || l.include?("broken upgrade") || l.include?("SaveCheckScreen") }
check("no other errors in the log (#{errors.length})", errors.empty?)
errors.first(6).each { |l| puts "  " + l }
puts $failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED"
exit($failed ? 1 : 0)
