# encoding: utf-8
# Checks Data Patches on KIF Beta's real data: its data classes and .dat
# files load as the game loads them, Kanto Reloaded boots on the foundation
# tests' stand-ins, and two made-up mods patch every target. Then one mod
# changes and Hot Reload builds again.
# Usage: ruby Tools/Tests/data_patches_test.rb <KIF Beta root> <empty temp folder>
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

#---------------------------------------------------------------- the game's data, as it loads
load File.join(KIF_ROOT, "Mods/KantoReloaded/Tools/PatchChecker/game_data.rb")
G = GameData
check("KIF Beta's data loaded (#{G::Item::DATA.length} item keys, #{G::Move::DATA.length} moves, #{G::Trainer::DATA.length} trainer keys)",
      G::Item::DATA.key?(:POTION) && G::Move::DATA.key?(:TACKLE) && G::Species::DATA.key?(:PIKACHU))
check("KIF's moves have no number keys (symbols only)", G::Move::DATA.keys.none? { |k| k.is_a?(Integer) })
MOVE_MAX = G::Move::DATA.values.map(&:id_number).max
ITEM_MAX = G::Item::DATA.keys.select { |k| k.is_a?(Integer) }.max
BRUNO = G::Trainer::DATA.find { |k, t| k.is_a?(Array) && t.trainer_type.to_s.start_with?("LEADER") }&.last
check("a gym leader to patch: #{BRUNO && BRUNO.id.inspect}", !BRUNO.nil?)
LEADER_ID = "#{BRUNO.trainer_type}|#{BRUNO.real_name}|#{BRUNO.version}"
LEADER_PARTY = BRUNO.pokemon.length
PIKA_SPEED = G::Species::DATA[:PIKACHU].base_stats[:SPEED]
PIKA_ATK = G::Species::DATA[:PIKACHU].base_stats[:ATTACK]
ROUTE = G::Encounter::DATA.keys.find { |k| G::Encounter::DATA[k].types[:Land] }
LAND = G::Encounter::DATA[ROUTE].types[:Land].length

#---------------------------------------------------------------- two mods
MODS = File.join(USERDIR, "Mods")
def patch_file(mod, name, data)
  dir = File.join(MODS, mod, "DataPatches")
  FileUtils.mkdir_p(dir)
  File.write(File.join(dir, name), JSON.pretty_generate(data))
end
patch_file("TestA", "items.json", { "target" => "items", "patches" => [
  { "operation" => "add", "id" => "kr_test_item", "data" => { "name" => "Test Item", "price" => 300, "description" => "A test." } },
  { "operation" => "edit", "id" => "potion", "data" => { "price" => 1 } },
  { "operation" => "add", "id" => "bad_tm", "data" => { "name" => "Bad TM", "move" => "NOT_A_MOVE" } }
] })
patch_file("TestA", "moves.json", [
  { "target" => "moves", "operation" => "add", "id" => "KR_TEST_MOVE",
    "data" => { "name" => "Test Move", "type" => "electric", "base_damage" => 80, "category" => "special", "total_pp" => 10 } }
])
patch_file("TestA", "abilities.json", { "target" => "abilities", "operation" => "add", "id" => "KR_TEST_ABILITY",
                                        "data" => { "name" => "Test Ability", "description" => "Tests." } })
patch_file("TestA", "trainer_types.json", { "target" => "trainer_types", "operation" => "add", "id" => "KR_TESTER",
                                            "data" => { "name" => "Tester", "base_money" => 60 } })
patch_file("TestA", "species.json", [
  { "target" => "species.core", "operation" => "edit", "id" => "pikachu", "data" => { "base_stats" => { "SPEED" => 120 }, "name" => "Pikachu+" } },
  { "target" => "species.learnsets", "operation" => "merge", "id" => "PIKACHU", "data" => { "add_moves" => [[1, "KR_TEST_MOVE"]] } },
  { "target" => "species.abilities", "operation" => "edit", "id" => "PIKACHU", "data" => { "hidden_abilities" => ["KR_TEST_ABILITY"] } },
  { "target" => "species.evolutions", "operation" => "merge", "id" => "EEVEE", "data" => { "add_evolutions" => [["JOLTEON", "Level", 40]] } },
  { "target" => "species.core", "operation" => "add", "id" => "NEWMON", "data" => { "name" => "Newmon" } }
])
patch_file("TestA", "trainers.json", [
  { "target" => "trainers.classic", "operation" => "merge", "id" => LEADER_ID,
    "data" => { "edit_pokemon" => [{ "slot" => 0, "level" => 99 }], "add_pokemon" => [{ "species" => "B25H1", "level" => 50 }],
                "bag_items" => ["Full Restore"] } },
  { "target" => "trainers.classic", "operation" => "add", "id" => "KR_TESTER|Tess|0",
    "data" => { "pokemon" => [{ "species" => "PIKACHU", "level" => 5, "moves" => ["THUNDERSHOCK"] }] } },
  { "target" => "trainers.classic", "operation" => "add", "id" => "KR_TESTER|Bad|0",
    "data" => { "pokemon" => [{ "species" => "NOT_A_MON", "level" => 5 }] } }
])
patch_file("TestA", "encounters.json", { "target" => "encounters.classic", "operation" => "merge", "id" => ROUTE.to_s,
                                         "data" => { "add_types" => { "Land" => [[5, "PIKACHU", 3, 5]] } } })
patch_file("TestB", "conflict.json", [
  { "target" => "items", "operation" => "edit", "id" => "POTION", "data" => { "price" => 7 } },
  { "target" => "moves", "operation" => "add", "id" => "KR_TEST_MOVE", "data" => { "name" => "Clash" } },
  { "target" => "nonsense", "operation" => "add", "id" => "x", "data" => {} },
  { "target" => "items", "operation" => "delete", "id" => "POTION", "data" => {} },
  { "target" => "species.learnsets", "operation" => "merge", "id" => "bulbasaur", "data" => { "add_moves" => [[98, "FLY"]] } },
  { "target" => "species.core", "operation" => "merge", "id" => "PIKACHU", "data" => { "base_stats" => { "DEFENSE" => 77 } } },
  { "target" => "items", "operation" => "add", "id" => "KR_DUP", "data" => { "name" => "Dup" } },
  { "target" => "items", "operation" => "add", "id" => "KR_DUP", "data" => { "name" => "Dup Again" } },
  { "target" => "items", "operation" => "edit", "id" => "Super Potion", "data" => { "price" => 5 } }
])
RAND_KEY = G::EncounterRandom::DATA.keys.find { |k| G::EncounterRandom::DATA[k].types[:Land] && G::EncounterRandom::DATA[k].types.length >= 2 }
RAND_TYPES = G::EncounterRandom::DATA[RAND_KEY].types.keys
patch_file("TestA", "fixes.json", [
  { "target" => "trainer_types", "operation" => "merge", "id" => "youngster", "data" => { "ai_skill_level" => 77 } },
  { "target" => "species.learnsets", "operation" => "merge", "id" => "BULBASAUR", "data" => { "add_moves" => [[99, "SURF"]] } },
  { "target" => "encounters.randomized", "operation" => "merge", "id" => RAND_KEY.to_s, "data" => { "step_chances" => { "Land" => 21 } } }
])
File.write(File.join(MODS, "TestB", "DataPatches", "broken.json"), "{ not json")
patch_file("TestA", "outfits.json", [
  { "target" => "outfits.hats", "operation" => "add", "id" => "kr_test_hat",
    "data" => { "name" => "Test Hat", "price" => 500, "tags" => "hat", "pokemontags" => "Pikachu", "contestcondition" => "cute" } },
  { "target" => "outfits.hats", "operation" => "edit", "id" => "absolhat", "data" => { "name" => "Absol Cap+", "price" => 1 } },
  { "target" => "outfits.hairstyles", "operation" => "add", "id" => "kr_test_hair", "data" => { "name" => "Test Hair" } },
  { "target" => "outfits.clothes", "operation" => "edit", "id" => "anything", "data" => { "price" => 1 } }
])

#---------------------------------------------------------------- the game's outfits (lists in $PokemonGlobal; game_data.rb loaded the classes)
$PokemonGlobal = PokemonGlobalMetadata.new
update_global_outfit_lists
GAME_HATS = $PokemonGlobal.hats_data.length
ABSOL_CAP = $PokemonGlobal.hats_data["absolhat"]
check("KIF's outfits loaded (#{GAME_HATS} hats, #{$PokemonGlobal.clothes_data.length} clothes)", GAME_HATS > 0 && ABSOL_CAP.is_a?(Hat))

#---------------------------------------------------------------- boot and build
load File.join(KIF_ROOT, "Mods/KantoReloaded/Bootstrap.rb")
R = Reloaded
DP = R::DataPatches
check("Kanto Reloaded boots with Data Patches (#{R::Bootstrap.status}, #{R::Bootstrap.failures.inspect})", R::Bootstrap.status == :ready)
$ctx = nil
R::Events.on(:data_patches_loaded, :test_context) { |c| $ctx = c }
DP.mods_override = [{ :id => "TestA", :name => "Test A", :folder_path => File.join(MODS, "TestA") },
                    { :id => "TestB", :name => "Test B", :folder_path => File.join(MODS, "TestB") }]
DP.after_game_data_load
def rejected?(target, id); DP.patches(target).any? { |p| p[:id] == id && p[:rejected] }; end

item = G::Item::DATA[:KR_TEST_ITEM]
check("items: added, with its own name and the next free number (#{item && item.id_number} after #{ITEM_MAX})",
      item && item.name == "Test Item" && item.price == 300 && item.id_number == ITEM_MAX + 1 && G::Item::DATA[item.id_number] == item)
check("items: a new item without a pocket goes in pocket 1", item && item.pocket == 1)
check("items: \"potion\" edits POTION (ids in any case); Test B loads last, so its price wins (#{G::Item::DATA[:POTION].price})",
      G::Item::DATA[:POTION].price == 7)
check("...and that's a warning naming both mods", DP.warnings.any? { |w| w[:message].include?("Test A") && w[:message].include?("loads last") })
check("items: one that teaches an unknown move is rejected, with why", rejected?("items", "BAD_TM") && !G::Item::DATA.key?(:BAD_TM) &&
      DP.patches("items").find { |p| p[:id] == "BAD_TM" }[:rejected].include?("NOT_A_MOVE"))
mv = G::Move::DATA[:KR_TEST_MOVE]
check("moves: two mods add KR_TEST_MOVE, so neither applies", mv.nil? && DP.errors.count { |e| e[:id] == "KR_TEST_MOVE" } == 2)
ab = G::Ability::DATA[:KR_TEST_ABILITY]
check("abilities: added, with its own name", ab && ab.name == "Test Ability")
tt = G::TrainerType::DATA[:KR_TESTER]
check("trainer types: added, and its name shows (KIF looks names up by number)", tt && tt.name == "Tester" && tt.base_money == 60)
pk = G::Species::DATA[:PIKACHU]
check("species: \"pikachu\" edits PIKACHU: Speed 120, the other stats stay (#{pk.base_stats.inspect})",
      pk.base_stats[:SPEED] == 120 && pk.base_stats[:ATTACK] == PIKA_ATK && pk.base_stats.length == 6)
check("species: its new name shows", pk.name == "Pikachu+")
check("species: a learnset patch that names a move nobody could add is rejected", rejected?("species.learnsets", "PIKACHU"))
check("species: hidden ability set to a patched ability", pk.hidden_abilities == [:KR_TEST_ABILITY])
ev = G::Species::DATA[:EEVEE].evolutions
check("species: Eevee gets a new evolution, and Jolteon's prevolution is worked out",
      ev.include?([:JOLTEON, :Level, 40, false]) && G::Species::DATA[:JOLTEON].evolutions.any? { |e| e[3] && e[0] == :EEVEE })
check("species: adding a Pokémon is refused (Expanded Dex's job)", DP.errors.any? { |e| e[:id] == "NEWMON" })
leader = G::Trainer::DATA[BRUNO.id]
check("trainers: the leader's first Pokémon edited (level #{leader.pokemon[0][:level]}), a fusion added (#{leader.pokemon.last[:species]})",
      leader.pokemon[0][:level] == 99 && leader.pokemon.length == LEADER_PARTY + 1 && leader.pokemon.last[:species] == :B25H1)
tess = G::Trainer::DATA[[:KR_TESTER, "Tess", 0]]
check("trainers: a new trainer of a patched type", tess && tess.pokemon[0][:species] == :PIKACHU)
check("trainers: one with an unknown Pokémon is rejected, with why",
      rejected?("trainers.classic", "KR_TESTER|Bad|0") && DP.patches("trainers.classic").find { |p| p[:id] == "KR_TESTER|Bad|0" }[:rejected].include?("NOT_A_MON"))
enc = G::Encounter::DATA[ROUTE]
check("encounters: Pikachu added to #{ROUTE}'s Land table (#{LAND} -> #{enc.types[:Land].length})",
      enc.types[:Land].length == LAND + 1 && enc.types[:Land].last == [5, :PIKACHU, 3, 5])
check("a target that doesn't exist, an operation that doesn't, and broken JSON are errors, not crashes",
      DP.errors.any? { |e| e[:message].include?("nonsense") } && DP.errors.any? { |e| e[:message].include?("delete") } &&
      DP.errors.any? { |e| e[:message].include?("JSON") })
check("the mods are listed in load order", DP.mods.map { |m| m[:id] } == ["TestA", "TestB"])
check("each mod's time on its patches, for the Timing Profiler (#{DP.timings.keys.inspect})",
      DP.timings.keys.sort == ["Kanto Reloaded", "Test A", "Test B"] && DP.timings.values.all? { |v| v > 0 })
check("data_patches_loaded comes after the targets' own checks: its summary is the final one (#{$ctx && $ctx[:summary].inspect})",
      $ctx && $ctx[:summary] == DP.summary && $ctx[:errors].length == DP.errors.length)
check("an alias on a merge is used: ai_skill_level (#{G::TrainerType::DATA[:YOUNGSTER].skill_level})", G::TrainerType::DATA[:YOUNGSTER].skill_level == 77)
check("...and bag_items, with an item named loosely (#{G::Trainer::DATA[BRUNO.id].items.inspect})", G::Trainer::DATA[BRUNO.id].items == [:FULLRESTORE])
bm = G::Species::DATA[:BULBASAUR].moves
check("two mods' add_moves both stay, and that's no conflict (#{bm.select { |l, _| l > 90 }.inspect})",
      bm.include?([99, :SURF]) && bm.include?([98, :FLY]) && DP.warnings.none? { |w| w[:id] == "BULBASAUR" })
pk = G::Species::DATA[:PIKACHU]
check("two mods changing different stats both apply, no conflict (Speed #{pk.base_stats[:SPEED]}, Defense #{pk.base_stats[:DEFENSE]})",
      pk.base_stats[:SPEED] == 120 && pk.base_stats[:DEFENSE] == 77 && DP.warnings.none? { |w| w[:id] == "PIKACHU" })
check("one mod adding an entry twice is told so, not as another mod",
      DP.errors.any? { |e| e[:message] == "Test B adds KR_DUP (Items) more than once, so none of them applies." } && !G::Item::DATA.key?(:KR_DUP))
check("\"Super Potion\" finds SUPERPOTION (#{G::Item::DATA[:SUPERPOTION].price})", G::Item::DATA[:SUPERPOTION].price == 5)
check("the log numbers patches from 1, as the Viewer does", File.read(R::Log.path).include?("conflict.json, patch 1: Test A also changes Potion"))
re = G::EncounterRandom::DATA[RAND_KEY]
check("encounters.randomized: an edit of its step chance (#{re.step_chances[:Land]}), its tables kept",
      re.step_chances[:Land] == 21 && re.types.keys == RAND_TYPES)
fresh = G::EncounterRandom.new(:id => RAND_KEY, :map => re.map, :version => re.version, :step_chances => { :Land => 10 },
                               :types => { :Land => [[100, :MEW, 5, 5]] })
G::EncounterRandom::DATA[RAND_KEY] = fresh                # KIF made the Randomized tables again
R::DataPatchEncounters.after_randomize
re = G::EncounterRandom::DATA[RAND_KEY]
check("...after KIF randomizes again: the new tables, with the patch on top (#{re.types[:Land].inspect}, #{re.step_chances[:Land]})",
      re.types[:Land] == [[100, :MEW, 5, 5]] && re.step_chances[:Land] == 21 && re.types.length == 1)
update_global_outfit_lists                   # the game refreshes its lists (a save loading, a shop)
hat = $PokemonGlobal.hats_data["kr_test_hat"]
check("outfits: a new hat joins the game's list when it refreshes, with its Pokémon tag and contest condition (#{hat && hat.tags.inspect})",
      hat.is_a?(Hat) && hat.name == "Test Hat" && hat.price == 500 && hat.tags.include?("pokemon-pikachu") &&
      hat.contest_condition == ["cute"] && $PokemonGlobal.hats_data.length == GAME_HATS + 1)
ab = $PokemonGlobal.hats_data["absolhat"]
check("outfits: a game hat edited (name and price), the rest of it kept (#{ab.name}, #{ab.price}, #{ab.tags.inspect})",
      ab.name == "Absol Cap+" && ab.price == 1 && ab.tags.include?("pokemon-absol") && ab.contest_condition == ["cool"])
check("outfits: a new hairstyle", $PokemonGlobal.hairstyles_data["kr_test_hair"].is_a?(Hairstyle))
check("outfits: an edit of an outfit the game doesn't have is refused",
      DP.errors.any? { |e| e[:target] == "outfits.clothes" && e[:message].include?("There's no anything in Clothes to edit") })

#---------------------------------------------------------------- what the Patch Viewer shows
OV = DP::Overview
ov = OV.new
a, b = ov.sections
def row_of(s, target, kind); s && s.rows.find { |r| r.target == target && r.kind == kind }; end
check("Patch Viewer: each mod a section, in load order (#{ov.sections.map(&:name).inspect})", ov.sections.map(&:name) == ["Test A", "Test B"])
check("...Test A's rows: a target and what happened (#{a.rows.map { |r| "#{r.label} #{r.count} #{r.kind}" }.join(", ")})",
      row_of(a, "items", :added).count == 1 && row_of(a, "items", :edited).count == 1 && row_of(a, "items", :rejected).count == 1 &&
      row_of(a, "trainers.classic", :added).count == 1 && row_of(a, "species.core", :rejected) && a.rows.first.target == "items")
check("...both have rejected patches, so that's their status (#{a.status}, #{a.rejected}; #{b.status}, #{b.rejected})",
      a.status == :rejected && b.status == :rejected && a.conflicts == 1)
d = ov.describe(row_of(a, "items", :added))
check("...an Added row in plain words: #{d}", d == "Test A adds 1 item: Test Item.")
d = ov.describe(row_of(a, "items", :edited))
check("...an Edited row names the other mod and who wins: #{d}", d.start_with?("Test A edits 1 item: Potion.") && d.include?("changes Potion's price") && d.include?("Test B loads last"))
d = ov.describe(row_of(a, "items", :rejected))
check("...a Rejected row says why: #{d}", d.include?("BAD_TM") && d.include?("NOT_A_MOVE"))
pf = row_of(b, "", :rejected)
check("...Test B's unknown target and broken file are one Patch Files row, listed last (#{pf && pf.count})",
      pf && pf.count == 2 && pf.label == "Patch Files" && b.rows.last.equal?(pf))
d = ov.describe_section(a)
check("...a mod's description: #{d}", d.start_with?("Test A loads 1st of 2:") && d.include?("rejected") && d.include?("1 entry is also changed"))
e = ov.entries(row_of(a, "items", :edited))
check("...Details lists each entry, where it's from and the conflict: #{e.inspect}",
      e.length == 1 && e[0][0] == "Potion" && e[0][1].include?("in items.json, patch 2") && e[0][1].include?("Test B"))
e = ov.entries(row_of(a, "trainers.classic", :added))
check("...a trainer reads as its name and type's name (#{e[0][0]})", e[0][0] == "Tess (Tester)")
hits = ov.sections.flat_map(&:rows).select { |r| ov.matches?(r, "pikachu") }.map { |r| "#{r.target} #{r.kind}" }
check("...Search finds rows by an entry's name or id (#{hits.inspect})",
      hits.include?("species.core edited") && hits.include?("species.learnsets rejected") && ov.matches?(row_of(a, "items", :added), "test item"))

#---------------------------------------------------------------- Hot Reload
FileUtils.rm_rf(File.join(MODS, "TestB"))
File.delete(File.join(MODS, "TestA", "DataPatches", "items.json"))
DP.mods_override = DP.mods_override.first(1)
before = OV.snapshot
secs = DP.reload
ch = OV.changes(before, OV.snapshot)
t = ch[:targets].to_h
check("Hot Reload's report: what changed per target (#{ch[:targets].inspect})",
      t["items"] == { :added => 0, :changed => 2, :removed => 1 } && t["moves"][:added] == 1 && t["species.learnsets"][:changed] == 2)
check("...nothing newly rejected, #{ch[:fixed]} fixed, both mods changed (#{ch[:mods].inspect})",
      ch[:new_errors].empty? && ch[:fixed] > 0 && ch[:mods].sort == ["Test A", "Test B"])
check("Hot Reload: built again without a restart (#{(secs * 1000).round} ms)", secs < 30)
check("Hot Reload: the removed item is gone, Potion's price is the game's again (#{G::Item::DATA[:POTION].price})",
      !G::Item::DATA.key?(:KR_TEST_ITEM) && !G::Item::DATA.key?(ITEM_MAX + 1) && G::Item::DATA[:POTION].price > 7)
mv = G::Move::DATA[:KR_TEST_MOVE]
check("Hot Reload: without the clash, the move is added, by symbol only, numbered after the game's (#{mv && mv.id_number})",
      mv && mv.name == "Test Move" && mv.id_number == MOVE_MAX + 1 && G::Move::DATA.keys.none? { |k| k.is_a?(Integer) })
pk = G::Species::DATA[:PIKACHU]
check("Hot Reload: Pikachu's patches don't stack (Speed #{pk.base_stats[:SPEED]}), and its learnset now applies",
      pk.base_stats[:SPEED] == 120 && pk.moves.include?([1, :KR_TEST_MOVE]))
leader = G::Trainer::DATA[BRUNO.id]
check("Hot Reload: the leader is the game's team plus the patch, not twice (#{leader.pokemon.length})", leader.pokemon.length == LEADER_PARTY + 1)
check("Hot Reload: the encounter table isn't added to twice", G::Encounter::DATA[ROUTE].types[:Land].length == LAND + 1)
ev = G::Species::DATA[:JOLTEON].evolutions.count { |e| e[3] && e[0] == :EEVEE }
check("Hot Reload: Jolteon has one prevolution entry (#{ev})", ev == 1)
patch_file("TestA", "bad.json", { "target" => "moves", "operation" => "add", "id" => "KR_BAD_MOVE",
                                  "data" => { "name" => "Bad Move", "type" => "NOT_A_TYPE", "total_pp" => 5 } })
before = OV.snapshot
DP.reload
ch = OV.changes(before, OV.snapshot)
check("Hot Reload's report: a new rejected patch, with why (#{ch[:new_errors].inspect})",
      ch[:new_errors].length == 1 && ch[:new_errors][0].start_with?("Moves: ") && ch[:new_errors][0].include?("NOT_A_TYPE") &&
      ch[:targets].empty? && ch[:mods] == ["Test A"])

FileUtils.rm_rf(File.join(MODS, "TestA"))
DP.reload
pk = G::Species::DATA[:PIKACHU]
check("with no mods, the game's data is back: Pikachu (Speed #{pk.base_stats[:SPEED]}, name #{pk.name.inspect}), the leader, Route, the move",
      pk.base_stats[:SPEED] == PIKA_SPEED && pk.name != "Pikachu+" && G::Trainer::DATA[BRUNO.id].pokemon.length == LEADER_PARTY &&
      G::Encounter::DATA[ROUTE].types[:Land].length == LAND && !G::Move::DATA.key?(:KR_TEST_MOVE) && !G::Ability::DATA.key?(:KR_TEST_ABILITY))
check("...and the game's own trainer object, not a copy", G::Trainer::DATA[BRUNO.id].equal?(BRUNO))
check("...and the Youngster's skill (#{G::TrainerType::DATA[:YOUNGSTER].skill_level})", G::TrainerType::DATA[:YOUNGSTER].skill_level == 16)
check("...and the game's hats: Hot Reload refreshed the list (#{$PokemonGlobal.hats_data.length}, #{$PokemonGlobal.hats_data["absolhat"].name})",
      $PokemonGlobal.hats_data.length == GAME_HATS && !$PokemonGlobal.hats_data.key?("kr_test_hat") &&
      $PokemonGlobal.hats_data["absolhat"].name == ABSOL_CAP.name)

#---------------------------------------------------------------- abilities from scripts
R::Abilities.register(:KR_SCRIPT_ABILITY, :name => "Script Ability", :mod => "Script Mod")
DP.reload
check("Reloaded::Abilities.register: the ability is in the game's data after a build, under its mod",
      G::Ability::DATA[:KR_SCRIPT_ABILITY] && G::Ability::DATA[:KR_SCRIPT_ABILITY].name == "Script Ability" &&
      DP.patches("abilities").any? { |p| p[:mod_name] == "Script Mod" })
ov = OV.new
s = ov.sections.find { |x| x.name == "Script Mod" }
check("Patch Viewer: a script's ability shows under its mod (#{s && ov.describe_section(s)})",
      s && s.code && s.order == 1 && ov.describe_section(s).start_with?("Script Mod's patches come from its scripts") &&
      row_of(s, "abilities", :added).count == 1)

#---------------------------------------------------------------- load order, with Mod Manager there
# Its mods load first (its loader is one of the loose scripts KIF loads
# before its folders), in its load order (dependencies first), not the order
# its scan found them; then KIF's own folders, in KIF's order.
LoEntry = Struct.new(:id, :name, :path, :source, :blocked) { def enabled?; true; end }
native_source = Object.new
def native_source.order(list); list.sort_by(&:name); end
lo_dirs = %w[MMB MMA NativeZ NativeY].map { |n| File.join(USERDIR, "LoadOrder", n).tap { |d| FileUtils.mkdir_p(d) } }
$lo_entries = [LoEntry.new("mm:b", "MM B", lo_dirs[0], Object.new), LoEntry.new("mm:a", "MM A", lo_dirs[1], Object.new),
               LoEntry.new("NativeZ", "Native Z", lo_dirs[2], native_source), LoEntry.new("NativeY", "Native Y", lo_dirs[3], native_source)]
module KIF; module Mods; def self.entries; $lo_entries; end; end; end
module ModManager; def self.load_order; ["a", "b"]; end; end
kept = DP.mods_override
DP.mods_override = nil
order = DP.active_mods.map { |m| m[:id] }
DP.mods_override = kept
check("load order: Mod Manager's mods first, in its load order, then KIF's folders in KIF's (#{order.inspect})",
      order == ["a", "b", "NativeY", "NativeZ"])

#---------------------------------------------------------------- the Patch Checker
pc_mod = File.join(USERDIR, "CheckMe")
FileUtils.mkdir_p(File.join(pc_mod, "DataPatches"))
File.write(File.join(pc_mod, "DataPatches", "mix.json"), JSON.generate([
  { "target" => "itemz", "operation" => "edit", "id" => "POTION", "data" => { "price" => 1 } },
  { "target" => "moves", "operation" => "edit", "id" => "TACKLE", "data" => { "base_damage" => 50 } },
  { "target" => "outfits.hats", "operation" => "edit", "id" => "absolhat", "data" => { "price" => 1 } }]))
checker = File.join(KIF_ROOT, "Mods/KantoReloaded/Tools/PatchChecker/patch_check.rb")
out = `ruby "#{checker}" "#{KIF_ROOT}" "#{pc_mod}" 2>&1`
ok = $?.exitstatus == 1 && out.include?("mix.json: 3 patches, 2 applied") &&
     out.include?("ERROR patch 1 (itemz POTION): No target is called \"itemz\"; did you mean \"items\"?") && !out.include?("ERROR patch 2")
check("the Patch Checker: on KIF's real data, the bad patch listed with a suggestion, the good ones (an outfit edit too) pass, exit 1", ok)
puts out.lines.map { |l| "    " + l }.join unless ok

errors = File.read(R::Log.path).lines.grep(/ERROR/).reject { |l| l.include?("Data patch ") }
check("no errors in the log besides the patches' own (#{errors.length})", errors.empty?)
errors.first(5).each { |l| puts "  " + l }
puts($failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED")
exit($failed ? 1 : 0)
