# encoding: utf-8
# Offline preview of the Patch Viewer (Data Patches): three made-up mods like
# the ones in the design, on the preview tool's stand-ins
# (Tools/UIPreview/preview.rb), driven with button presses, typing and the
# mouse; then Hot Reload after a mod changes, and the screen with no patches.
# Usage: ruby   Tools/Tests/patch_viewer_preview.rb "<KIF Beta>" <work dir with metrics.json>
#        python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>
require "json"
require "fileutils"
PREVIEW_SETUP_ONLY = true
load File.join(ARGV[0], "Mods/KantoReloaded/Tools/UIPreview/preview.rb")
DP = Reloaded::DataPatches
check("the Patch Viewer loads in the preview", defined?(Reloaded::PatchViewer) && defined?(DP::Overview))

#---------------------------------------------------------------- the game's data (a little of it)
NAMES = %w[Bulbasaur Ivysaur Venusaur Charmander Charmeleon Charizard Squirtle Wartortle Blastoise Caterpie
           Metapod Butterfree Weedle Kakuna Beedrill Pidgey Pidgeotto Pidgeot Rattata Raticate Spearow Fearow
           Ekans Arbok Pikachu Raichu Sandshrew Sandslash Nidoqueen Nidoking].freeze
def base_data
  species = NAMES.map { |n| [n.upcase, { "name" => n }] }.to_h
  learnsets = NAMES.map { |n| [n.upcase, { "moves" => [[1, "TACKLE"]] }] }.to_h
  DP.register_target("items", { "POTION" => { "name" => "Potion", "price" => 200 } }, :symbol_ids => true)
  DP.register_target("moves", { "TACKLE" => { "name" => "Tackle", "type" => "NORMAL" } }, :symbol_ids => true)
  DP.register_target("abilities", { "OVERGROW" => { "name" => "Overgrow" } }, :symbol_ids => true)
  DP.register_target("species.core", species, :symbol_ids => true)
  DP.register_target("species.learnsets", learnsets, :symbol_ids => true)
  DP.register_target("trainers.classic", { "LEADER_Brock|Brock|0" => { "name" => "Brock", "pokemon" => [] },
                                           "LEADER_Misty|Misty|0" => { "name" => "Misty", "pokemon" => [] } })
  DP.register_target("encounters.classic", (1..60).map { |m| ["#{m}_0", { "types" => {} }] }.to_h)
end

MODS = File.join(USERDIR, "Mods")
def patch_file(mod, name, data)
  dir = File.join(MODS, mod, "DataPatches")
  FileUtils.mkdir_p(dir)
  File.write(File.join(dir, name), JSON.pretty_generate(data))
end
patch_file("KantoReloaded", "items.json", { "target" => "items", "patches" =>
  [["DYNAMAX_CANDY", "Dynamax Candy"], ["ABILITY_PATCH", "Ability Patch"], ["MINT_BOX", "Mint Box"]].map do |id, name|
    { "operation" => "add", "id" => id, "data" => { "name" => name, "price" => 1000 } }
  end })
patch_file("KantoReloaded", "moves.json", { "target" => "moves", "patches" =>
  [["ICE_SPINNER", "Ice Spinner"], ["TORCH_SONG", "Torch Song"], ["AQUA_STEP", "Aqua Step"], ["TERA_BLAST", "Tera Blast"]].map do |id, name|
    { "operation" => "add", "id" => id, "data" => { "name" => name, "type" => "NORMAL" } }
  end })
patch_file("KantoReloaded", "encounters.json", { "target" => "encounters.classic", "patches" =>
  (1..48).map { |m| { "operation" => "merge", "id" => "#{m}_0", "data" => { "step_chances" => { "Land" => 25 } } } } })
patch_file("Gen9Movepools", "learnsets.json", { "target" => "species.learnsets", "patches" =>
  NAMES.map { |n| { "operation" => "edit", "id" => n.downcase, "data" => { "moves" => [[1, "TACKLE"], [5, "ICE_SPINNER"]] } } } })
patch_file("Gen9Movepools", "moves.json", [{ "target" => "moves", "operation" => "edit", "id" => "tackle", "data" => { "type" => "FIGHTING" } }])
patch_file("HardTrainers", "trainers.json", { "target" => "trainers.classic", "patches" => [
  { "operation" => "merge", "id" => "LEADER_Brock|Brock|0", "data" => { "pokemon" => [{ "species" => "ONIX", "level" => 14 }] } },
  { "operation" => "merge", "id" => "LEADER_Misty|Misty|0", "data" => { "pokemon" => [{ "species" => "STARMIE", "level" => 21 }] } }] })
patch_file("HardTrainers", "learnsets.json", { "target" => "species.learnsets", "patches" => [
  { "operation" => "edit", "id" => "PIKACHU", "data" => { "moves" => [[1, "THUNDERSHOCK"]] } },
  { "operation" => "edit", "id" => "RAICHU", "data" => { "moves" => [[1, "THUNDERSHOCK"]] } }] })
patch_file("HardTrainers", "moves.json", [{ "target" => "moves", "operation" => "edit", "id" => "SHADOWCLAWX", "data" => { "power" => 90 } }])
MOD_LIST = [{ :id => "KantoReloaded", :name => "Kanto Reloaded", :folder_path => File.join(MODS, "KantoReloaded") },
            { :id => "Gen9Movepools", :name => "Gen 9 Movepools", :folder_path => File.join(MODS, "Gen9Movepools") },
            { :id => "HardTrainers", :name => "Hard Trainers+", :folder_path => File.join(MODS, "HardTrainers") }].freeze
DP.mods_override = MOD_LIST
Reloaded::Events.on(:game_data_loaded, :preview_base, 10) { base_data }
DP.after_game_data_load

#---------------------------------------------------------------- driving it
def pv; $pv; end
Reloaded::PatchViewer.prepend(Module.new { def main; $pv = self; super; end })
def drive_pv(label, queue)
  Input.queue = queue.dup
  Reloaded::PatchViewer.open
  check("#{label}: opened and closed", true)
rescue QueueEmpty => e
  check("#{label}: #{e.message}", false)
rescue Exception => e
  check("#{label}: #{e.class}: #{e.message} #{e.backtrace.first(4).inspect}", false)
end
def cur_row; pv.send(:current); end
def section_name; pv.send(:section).name; end
def hints; pv.send(:hint_pairs).map { |p| p[1] }; end
# Pixel-font text is drawn glyph by glyph: what Pixel.text drew, by bitmap,
# since that bitmap's last clear
$pf_texts = Hash.new { |h, k| h[k] = [] }
Reloaded::Pixel.singleton_class.prepend(Module.new do
  def text(b, x, y, w, h, str, color, font = nil, align = 0)
    $pf_texts[b.id] << str.to_s
    super
  end
end)
Bitmap.prepend(Module.new { def clear(*a); $pf_texts.delete(id); super; end })
def drawn?(bitmap, word)
  return true if $pf_texts[bitmap.id].any? { |s| s.include?(word) }
  return bitmap.ops.any? { |o| o[0] == "text" && o[5].to_s.include?(word) }
end
def top_text?(word); drawn?(pv.instance_variable_get(:@top_sprite).bitmap, word); end

drive_pv("browsing", [
  dmp("pv_01_mod"),
  at { check("opens on the first mod in load order (#{section_name}), its rows listed", section_name == "Kanto Reloaded" && pv.send(:rows).length == 3) },
  at { check("the hints: Mod, Open, Close (no Reload without KIF's DEBUG option) (#{hints.inspect})", hints == ["Mod", "Open", "Close"]) },
  at { check("its status: OK", top_text?("OK") && top_text?("KANTO RELOADED")) },
  I::RIGHT,
  dmp("pv_02_row"),
  at { check("Right: its rows (#{cur_row.label} #{cur_row.count} #{cur_row.kind}); Select, Details, Back", cur_row.label == "Items" && hints == ["Select", "Details", "Back"]) },
  I::DOWN, I::DOWN,
  dmp("pv_03_encounters"),
  at { check("Encounters: 48 Edited, in plain words", cur_row.count == 48 && cur_row.kind == :edited && top_text?("Edited")) },
  I::BACK, I::DOWN,
  at { check("B, Down: the next mod (#{section_name})", section_name == "Gen 9 Movepools") },
  dmp("pv_04_conflicts"),
  at { check("...whose heading shows its conflicts", top_text?("CONFLICT")) },
  I::USE, I::DOWN,
  dmp("pv_05_learnsets"),
  at { check("its Learnsets row says who else changes them and who wins", cur_row.label == "Learnsets" && top_text?("loads last")) },
  I::USE,
  dmp("pv_06_details"),
  at { check("A: Details lists the row's entries", drawn?(pv.overlay, "Bulbasaur") && drawn?(pv.overlay, "Learnsets Edited")) },
  I::BACK,
  at { check("B closes Details", pv.overlay.ops == [["clear"]]) },
  I::BACK, I::DOWN, I::RIGHT, I::DOWN, I::DOWN, I::DOWN,
  dmp("pv_07_rejected"),
  at { check("Hard Trainers+: a Rejected row, and why (#{cur_row.label} #{cur_row.kind})", cur_row.kind == :rejected && section_name == "Hard Trainers+") },
  I::R,
  dmp("pv_08_load_order"),
  at { check("R: the load order", drawn?(pv.overlay, "1. Kanto Reloaded") && drawn?(pv.overlay, "3. Hard Trainers+")) },
  I::UP, I::UP, I::USE,
  at { check("picking a mod there opens it (#{section_name})", section_name == "Kanto Reloaded") },
  I::BACK
])

drive_pv("search", [
  I::SPECIAL,
  "pika",
  dmp("pv_09_search_typing"),
  :RETURN,
  dmp("pv_10_search_results"),
  at { check("Search: every mod's matching rows (#{pv.send(:rows).map { |r| "#{r.section.name} #{r.label}" }.inspect})",
             pv.send(:rows).map { |r| r.section.name } == ["Gen 9 Movepools", "Hard Trainers+"]) },
  I::BACK,
  at { check("B clears the search", pv.instance_variable_get(:@query).nil?) },
  I::BACK
])

drive_pv("mouse", [
  [:move, 60, 42 + 20 + 6],
  at { check("the mouse over a mod picks it (#{section_name})", section_name == "Gen 9 Movepools") },
  [:click, 60, 42 + 40 + 6],
  at { check("a click opens it (#{section_name}, focus #{pv.instance_variable_get(:@focus)})",
             section_name == "Hard Trainers+" && pv.instance_variable_get(:@focus) == :list) },
  [:rclick, 10, 10],
  [:rclick, 10, 10]
])

# KIF's DEBUG option on at the title screen: KIF hasn't copied it into
# $DEBUG yet (it does that on the map), and Reload shows anyway
$DEBUG = false
$PokemonSystem.debug = 1
drive_pv("debug option, title screen", [
  at { check("KIF's DEBUG option on, $DEBUG still off: Reload shows (#{hints.inspect})", hints.include?("Reload")) },
  I::BACK
])
$PokemonSystem.debug = 0

# Hot Reload: Gen 9 Movepools drops its Tackle edit and adds a move with a
# mistake in it
$DEBUG = true
drive_pv("hot reload", [
  I::DOWN,
  at { check("with KIF's DEBUG option on, Y is Reload (#{hints.inspect})", hints == ["Mod", "Open", "Reload", "Close"]) },
  at {
    patch_file("Gen9Movepools", "moves.json", [
      { "target" => "moves", "operation" => "add", "id" => "KOWTOW_CLEAVE", "data" => { "name" => "Kowtow Cleave", "type" => "DARK" } },
      { "target" => "moves", "operation" => "edit", "id" => "SHADOWCLAWX", "data" => { "type" => "GHOST" } }])
  },
  I::X,
  dmp("pv_11_reloaded"),
  at { check("Y: Patches Reloaded, what changed and the new rejection",
             drawn?(pv.overlay, "Patches Reloaded") && drawn?(pv.overlay, "1 added") && drawn?(pv.overlay, "1 new") &&
             drawn?(pv.overlay, "Gen 9 Movepools,")) },
  I::USE,
  at { check("OK closes it; the screen shows the new patches (#{section_name}: #{pv.send(:section).rows.map(&:label).inspect})",
             pv.overlay.ops == [["clear"]] && section_name == "Gen 9 Movepools" && pv.send(:section).status == :rejected) },
  I::BACK
])
$DEBUG = false

# No mod has patches
DP.mods_override = []
DP.after_game_data_load
drive_pv("no patches", [
  dmp("pv_12_empty"),
  at { check("with no patches: it says so, and the only hint is Close (#{hints.inspect})", top_text?("No mod has data patches.") && hints == ["Close"]) },
  I::BACK
])

# Kanto Reloaded > Data Patches > Patch Viewer
def kr_rows(screen); (screen.instance_variable_get(:@rows)[:kanto_reloaded] || []).map(&:label); end
drive("settings", [
  at { check("Kanto Reloaded's settings: a Data Patches heading with Patch Viewer (#{kr_rows(scr).inspect})",
             kr_rows(scr).include?("Data Patches") && kr_rows(scr).include?("Patch Viewer")) },
  I::BACK
])
$pv = nil
Input.queue = [I::BACK]
Reloaded::Settings.press(:"data_patches.viewer")
check("its button opens the Patch Viewer", !pv.nil?)

errors = File.read(Reloaded::Log.path).lines.grep(/ERROR/).reject { |l| l.include?("Data patch ") }
check("no errors in the log besides the patches' own (#{errors.length})", errors.empty?)
errors.first(6).each { |l| puts "  " + l }
puts $failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED"
exit($failed ? 1 : 0)
