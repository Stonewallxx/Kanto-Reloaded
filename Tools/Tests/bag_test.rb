# encoding: utf-8
# Checks the Reloaded Bag's order, NEW and Favorites outside the game, on
# the game's own Bag (013_Items/008_PokemonBag.rb, loaded as KIF Beta has it)
# with stand-ins for its items: each pocket's Auto-Sort (Custom List with
# old Kanto Reloaded's defaults, A-Z, Number, Off with New Items), sorting in
# place, NEW (the first look, a new kind, leaving the pocket, more of
# something you had, getting something back), Favorites, the views, moving by
# hand (a Custom List rewritten), Kanto Reloaded Legacy's lists, favorites and
# modes brought in once, and Off.
# Usage: ruby Tools/Tests/bag_test.rb "<KIF Beta>" <empty temp folder>
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

#---------------------------------------------------------------- the game's items, as stand-ins
eval(<<~'RUBY', TOPLEVEL_BINDING, "013_Fake_Items.rb", 1)
  module Settings
    def self.bag_pocket_names
      ["", "Items", "Medicine", "Poké Balls", "TMs & HMs", "Berries", "Mail", "Battle Items", "Key Items"]
    end
    BAG_MAX_POCKET_SIZE = [0, -1, -1, -1, -1, -1, -1, -1, -1]
    BAG_MAX_PER_SLOT = 999
    BAG_POCKET_AUTO_SORT = [0, false, false, false, true, true, false, false, false]
  end
  module GameData
    class Item
      DATA = {}
      attr_reader :id, :id_number, :name, :pocket, :type, :move
      def initialize(id, n, name, pocket, move = nil); @id, @id_number, @name, @pocket, @move = id, n, name, pocket, move; @type = 0; end
      def self.add(*a); DATA[a[0]] = new(*a); end
      def self.try_get(i); DATA[i.is_a?(String) ? i.to_sym : i]; end
      def self.get(i); try_get(i) || raise("Unknown ID #{i}"); end
      def self.exists?(i); !try_get(i).nil?; end
      def is_machine?; !@move.nil?; end
    end
  end
  $pinkan = 0
  def updatePinkanBerryDisplay; $pinkan += 1; end
RUBY
[[:POTION, 17, "Potion", 2], [:SUPERPOTION, 18, "Super Potion", 2], [:HYPERPOTION, 19, "Hyper Potion", 2],
 [:RARECANDY, 50, "Rare Candy", 2], [:ZZTONIC, 900, "Aqua Tonic", 2], [:BOLTTONIC, 901, "Bolt Tonic", 2],
 [:REPEL, 30, "Repel", 1], [:ESCAPEROPE, 31, "Escape Rope", 1], [:HONEY, 32, "Honey", 1],
 [:TM06, 300, "TM06", 4, :TOXIC], [:TM24, 318, "TM24", 4, :THUNDERBOLT], [:TM13, 307, "TM13", 4, :ICEBEAM],
 [:POKEBALL, 200, "Poké Ball", 3], [:GREATBALL, 201, "Great Ball", 3], [:QUICKBALL, 220, "Quick Ball", 3]].each { |a| GameData::Item.add(*a) }
# the game's own Bag
load File.join(KIF_ROOT, "Data/Scripts/013_Items/008_PokemonBag.rb")
$PokemonBag = PokemonBag.new

load File.join(KIF_ROOT, "Mods/KantoReloaded/Bootstrap.rb")
R = Reloaded
B = R::Bag
S = R::Settings
check("Kanto Reloaded boots with the Reloaded Bag (#{R::Bootstrap.status}, #{R::Bootstrap.failures.inspect})", R::Bootstrap.status == :ready)
check("a feature, On to start, with its own page in the Kanto Reloaded section",
      R::Features.on?(:reloaded_bag) && S.page(:bag) && S.page(:bag)[:name] == "Bag")
check("each pocket's Auto-Sort: Custom List to start, TMs & HMs and Berries by Number (the game's own) (#{B.pockets.map { |p| B.mode(p) }.inspect})",
      B.pockets.map { |p| B.mode(p) } == [1, 1, 1, 3, 3, 1, 1, 1])
check("...the rows named as the game's pockets (#{S.definition(:"bag.mode2")[:name]})", S.definition(:"bag.mode2")[:name] == "Medicine")
R::SaveStore.__send__(:from_save, nil)
R::Events.emit(:save_loaded, {})
def pocket(n); $PokemonBag.pockets[n].map { |s| s[0] }; end

#---------------------------------------------------------------- Auto-Sort
$PokemonBag.pbStoreItem(:HYPERPOTION, 2)
$PokemonBag.pbStoreItem(:ZZTONIC)
$PokemonBag.pbStoreItem(:POTION, 5)
$PokemonBag.pbStoreItem(:RARECANDY)
$PokemonBag.pbStoreItem(:BOLTTONIC)
check("Custom List: old Kanto Reloaded's order, what isn't on it after, A-Z (#{pocket(2).inspect})",
      pocket(2) == [:RARECANDY, :POTION, :HYPERPOTION, :ZZTONIC, :BOLTTONIC])
slots = $PokemonBag.pockets[2]
$PokemonBag.pbStoreItem(:SUPERPOTION)
check("...sorted in place: the game's own pocket array is the same one", $PokemonBag.pockets[2].equal?(slots) &&
      pocket(2) == [:RARECANDY, :POTION, :SUPERPOTION, :HYPERPOTION, :ZZTONIC, :BOLTTONIC])
$PokemonBag.pbStoreItem(:POTION, 3)
check("...more of something you had: just its count (#{$PokemonBag.pbQuantity(:POTION)})", $PokemonBag.pbQuantity(:POTION) == 8 && pocket(2)[1] == :POTION)
S.set(:"bag.mode2", 2)
check("A-Z: changing the setting sorts the pocket (#{pocket(2).inspect})",
      pocket(2) == [:ZZTONIC, :BOLTTONIC, :HYPERPOTION, :POTION, :RARECANDY, :SUPERPOTION])
$PokemonBag.pbStoreItem(:TM24)
$PokemonBag.pbStoreItem(:TM06)
$PokemonBag.pbStoreItem(:TM13)
check("Number: TMs by their number (#{pocket(4).inspect})", pocket(4) == [:TM06, :TM13, :TM24])
S.set(:"bag.mode1", 0)
$PokemonBag.pbStoreItem(:HONEY)
$PokemonBag.pbStoreItem(:REPEL)
check("Off: where the game puts it (the end) (#{pocket(1).inspect})", pocket(1) == [:HONEY, :REPEL])
S.set(:"bag.new_items", 1)
$PokemonBag.pbStoreItem(:ESCAPEROPE)
check("...New Items never moves the real pocket (#{pocket(1).inspect})", pocket(1) == [:HONEY, :REPEL, :ESCAPEROPE])
S.set(:"bag.new_items", 0)

#---------------------------------------------------------------- NEW
B.refresh_seen!
check("the first look: nothing NEW (what was there counts as seen)", B.held.none? { |id| B.new?(id) })
$PokemonBag.pbStoreItem(:GREATBALL)
check("a new kind of item: NEW, and its pocket has a dot", B.new?(:GREATBALL) && B.pocket_new?(3))
$PokemonBag.pbStoreItem(:POTION)
check("...more of something you had isn't NEW", !B.new?(:POTION))
B.seen!(3)
check("leaving its pocket: seen", !B.new?(:GREATBALL) && !B.pocket_new?(3))
$PokemonBag.pbDeleteItem(:HONEY)
B.refresh_seen!
$PokemonBag.pbStoreItem(:HONEY)
check("getting something back you'd run out of: NEW again", B.new?(:HONEY))
check("New Items In Place: a NEW item where its pocket's order puts it (#{B.rows(1, 0).inspect})",
      B.rows(1, 0) == [:REPEL, :ESCAPEROPE, :HONEY])
S.set(:"bag.new_items", 1)
check("...First: at the top of what the screen shows until it's seen, the real pocket as it was (#{B.rows(1, 0).inspect})",
      B.rows(1, 0) == [:HONEY, :REPEL, :ESCAPEROPE] && pocket(1) == [:REPEL, :ESCAPEROPE, :HONEY])
S.set(:"bag.new_items", 2)
check("...Last: at the bottom (#{B.rows(1, 1).inspect})", B.rows(1, 1) == [:ESCAPEROPE, :REPEL, :HONEY])
B.seen!(1)
S.set(:"bag.new_items", 1)
check("...seen: back in its place (#{B.rows(1, 0).inspect})", B.rows(1, 0) == [:REPEL, :ESCAPEROPE, :HONEY])
S.set(:"bag.new_items", 0)

#---------------------------------------------------------------- Favorites and views
check("a Favorite: starred, and unstarred again", B.toggle_favorite(:SUPERPOTION) == true && B.favorite?(:SUPERPOTION) &&
      B.toggle_favorite(:SUPERPOTION) == false)
B.toggle_favorite(:RARECANDY)
check("Bag Order: Favorites first, then the pocket's order (#{B.rows(2, 0).inspect})",
      B.rows(2, 0) == [:RARECANDY, :ZZTONIC, :BOLTTONIC, :HYPERPOTION, :POTION, :SUPERPOTION])
check("Quantity: most first (#{B.rows(2, 2).first(2).inspect})", B.rows(2, 2).first(2) == [:RARECANDY, :POTION])
check("Recent: the newest first (#{B.rows(2, 5).inspect})", B.rows(2, 5)[1] == :SUPERPOTION)
check("...the real pocket didn't change", pocket(2) == [:ZZTONIC, :BOLTTONIC, :HYPERPOTION, :POTION, :RARECANDY, :SUPERPOTION])
B.set_view(2, 1)
check("a view is kept per pocket (#{B.view(2)}, #{B.view(1)})", B.view(2) == 1 && B.view(1) == 0)

#---------------------------------------------------------------- moving by hand
check("moving: allowed in Off and Custom List pockets, not A-Z or Number",
      B.can_move?(1) && !B.can_move?(2) && !B.can_move?(4) && B.move(2, 0, 1) == false)
B.move(1, 0, 2)
check("Off: the slot moves (#{pocket(1).inspect})", pocket(1) == [:ESCAPEROPE, :HONEY, :REPEL])
S.set(:"bag.mode2", 1)
B.move(2, pocket(2).index(:BOLTTONIC), 0)
check("Custom List: the slot moves and the list follows (#{B.custom_list(2).first(3).inspect})",
      pocket(2).first == :BOLTTONIC && B.custom_list(2).index("BOLTTONIC") < B.custom_list(2).index("RARECANDY"))
$PokemonBag.pbStoreItem(:BOLTTONIC)
B.sort_pocket!(2)
check("...and it stays there through the next sort (#{pocket(2).first(2).inspect})", pocket(2).first == :BOLTTONIC)

#---------------------------------------------------------------- headings, Defaults, Export and Import
B.set_list(2, ["#Healing", "POTION", "SUPERPOTION", "#Healing", "POTION", "#", "RARECANDY"])
check("a Custom List keeps its headings (they may repeat; each item once; an empty one drops) (#{B.custom_list(2).inspect})",
      B.custom_list(2) == ["#Healing", "POTION", "SUPERPOTION", "#Healing", "RARECANDY"])
check("...headings sort nothing (#{pocket(2).first(3).inspect})", pocket(2).first(3) == [:POTION, :SUPERPOTION, :RARECANDY])
B.toggle_favorite(:POTION) unless B.favorite?(:POTION)
S.set(:"bag.mode3", 2)
path = B.export_lists
text = File.read(path, :encoding => "UTF-8")
check("Export: the file in the mod folder's Exports (#{File.basename(path)})", File.basename(File.dirname(path)) == "Exports" && File.file?(path))
check("...headings as -- Name --, a Favorite starred, the Auto-Sort in [Settings]",
      text.include?("-- Healing --") && text.include?("* POTION") && text.include?("Poké Balls = A-Z") && text.include?("[Medicine]"))
B.set_list(2, ["RARECANDY"], false)
S.set(:"bag.mode3", 0)
got = B.import_lists(path)
check("Import: the lists, Favorites and Auto-Sort back (#{got.inspect}, #{B.custom_list(2).first(3).inspect}, #{B.mode(3)})",
      got && B.custom_list(2).first(3) == ["#Healing", "POTION", "SUPERPOTION"] && B.favorite?(:POTION) && B.mode(3) == 2)
old = File.join(USERDIR, "AutosortBag_lists.txt")
File.write(old, ["# Kanto Reloaded Autosort Bag", "[Settings]", "Always Move Recent = First", "Poké Balls = Alphabetical",
                 "[Medicine]", "-- Cures --", "* HYPERPOTION   # the best one, for now", "POTION, SUPERPOTION // two at once",
                 "NOTANITEM", "REPEL", "[Pok_Balls]", "QUICKBALL"].join("\r\n"))
got = B.import_lists(old)
check("...old Kanto Reloaded's file too: notes with commas, its separators as headings, Always Move Recent as New Items (#{B.custom_list(2).inspect})",
      B.custom_list(2) == ["#Cures", "HYPERPOTION", "POTION", "SUPERPOTION"] && B.favorites(2) == ["HYPERPOTION"] && B.new_place == 1)
check("...what isn't an item, or isn't that pocket's, left out (#{got[:ignored]}) and named pockets read (#{B.custom_list(3).inspect})",
      got[:ignored] == 2 && B.custom_list(3) == ["QUICKBALL"])
S.set(:"bag.new_items", 0)
B.restore_list(2)
check("Defaults: old Kanto Reloaded's list again", B.custom_list(2) == B.default_list(2) && !B.default_list(2).empty?)
same = B.pockets.all? do |p|
  items = B::SECTIONED_LISTS[p].reject { |e| B.heading?(e) }
  items.sort == B::DEFAULT_LISTS[p].sort && items.uniq.length == items.length
end
check("the sectioned starting lists: each pocket the same items as the plain ones, once each", same)
B.set_list(3, ["QUICKBALL", "POKEBALL"], false)
S.set(:"bag.start_lists", 1)
d = R::SaveStore.section(:bag)
d["lists"].delete("5")
check("Starting Lists With Sections: a pocket not edited follows it (#{B.custom_list(5).first(2).inspect}), an edited one keeps yours",
      B.custom_list(5).first == "#Healing" && B.custom_list(3) == ["QUICKBALL", "POKEBALL"])
B.restore_list(3)
check("...and Defaults brings the sectioned one back (#{B.custom_list(3).first(2).inspect})", B.custom_list(3).first == "#Everyday")
S.set(:"bag.start_lists", 0)
check("...Plain again: no headings", B.default_list(3).none? { |e| B.heading?(e) })
B.set_list(2, ["#Candy", "RARECANDY", "#Healing", "POTION", "SUPERPOTION", "HYPERPOTION"], false)
S.set(:"bag.mode2", 1)
B.set_view(2, 0)
B.set_favorites(2, ["HYPERPOTION"])
shown = B.sectioned(2, B.rows(2, 0))
check("the Bag shows a Custom List's headings: Favorites first, then the list's, then what isn't on it (#{shown.inspect})",
      shown == ["Favorites", :HYPERPOTION, "Candy", :RARECANDY, "Healing", :POTION, :SUPERPOTION, "Not on Your List", :ZZTONIC, :BOLTTONIC])
B.set_view(2, 1)
check("...only in Bag Order (A-Z: none)", B.sectioned(2, B.rows(2, 1)).nil?)
B.set_view(2, 0)
check("the Bag page and Bag - Auto-Sort: two headings, each save its own",
      S.page(:bag_sort) && S.page(:bag_sort)[:name] == "Bag - Auto-Sort" && S.definition(:"bag.mode1")[:page] == :bag_sort &&
      S.definition(:"bag.mode1")[:scope] == :save && S.definition(:"bag.new_items")[:scope] == :save &&
      [:"bag.edit_lists", :"bag.export", :"bag.import"].all? { |k| S.definition(k)[:type] == :button })

#---------------------------------------------------------------- PIF's Bag, fixed (his pick)
check("PIF's pbChangeQuantity no longer crashes (#{R::Fixes.on?(:bag_change_quantity)})",
      R::Fixes.on?(:bag_change_quantity) && (begin; $PokemonBag.pbChangeQuantity(1, 0, 3); true; rescue NoMethodError; false; end))
p1 = $PokemonBag.pockets[1]
$PokemonBag.lastpocket = 1
$PokemonBag.sort_pocket_alphabetically
first = pocket(1)
$PokemonBag.sort_pocket_alphabetically
again = pocket(1)
$PokemonBag.lastpocket = 2
$PokemonBag.sort_pocket_by_quantity
$PokemonBag.lastpocket = 1
$PokemonBag.sort_pocket_alphabetically
third = pocket(1)
check("PIF's Sort Bag: the same sort again turns round, another pocket's sort doesn't (#{first.inspect}, #{again.inspect}, #{third.inspect})",
      R::Fixes.on?(:bag_sort_direction) && again == first.reverse && third == first)
check("...and the pocket is sorted in place", $PokemonBag.pockets[1].equal?(p1))
$pinkan = 0
$PokemonBag.pbDeleteItem(:REPEL)
before = $pinkan
$PokemonBag.pbStoreItem(:REPEL)
check("Pinkan Island: taking out another item doesn't redraw the Pinkan Berries (#{before})", R::Fixes.on?(:pinkan_toss) && before == 0)
GameData::Item.add(:PINKANBERRY, 999, "Pinkan Berry", 5)
$PokemonBag.pbStoreItem(:PINKANBERRY, 2)
$PokemonBag.pbDeleteItem(:PINKANBERRY)
check("...a Pinkan Berry does (#{$pinkan})", $pinkan == 1)
updatePinkanBerryDisplay
check("...and the game's own calls still do (#{$pinkan})", $pinkan == 2)

#---------------------------------------------------------------- Kanto Reloaded Legacy
File.write(File.join(USERDIR, "KantoReloadedSettings.json"),
           JSON.generate({ "schema_version" => 1, "values" => { "autosort_bag_mode_pok_balls" => 2, "autosort_bag_mode_items" => 0 } }))
legacy = { :systems => { "autosort_bag" => { "lists" => { :medicine => [[:__SEPARATOR__, "Heal"], :HYPERPOTION, :POTION, :NOTANITEM] },
                                             "favorites" => { :medicine => [:POTION] } } } }
SaveData.mark_values_as_unloaded
SaveData.load_all_values({ :player => TrainerStub.new(1001), :kanto_reloaded => legacy })    # no Kanto Reloaded data yet
R::Events.emit(:save_loaded, {})
check("a save with Kanto Reloaded Legacy's lists: brought in, its separators as headings (#{B.custom_list(2).inspect}, #{B.favorites(2).inspect})",
      B.custom_list(2) == ["#Heal", "HYPERPOTION", "POTION"] && B.favorites(2) == ["POTION"])
check("...its Auto-Sort modes from its settings file (Poké Balls A-Z, Items Off)", B.mode(3) == 2 && B.mode(1) == 0)
B.set_list(2, ["POTION"], false)
SaveData.mark_values_as_unloaded
SaveData.load_all_values({ :player => TrainerStub.new(1001), :kanto_reloaded => legacy, :reloaded => R::SaveStore.__send__(:to_save) })
R::Events.emit(:save_loaded, {})
check("...only once (#{B.custom_list(2).inspect})", B.custom_list(2) == ["POTION"])

#---------------------------------------------------------------- Off
R::Features.set(:reloaded_bag, :off)
S.set(:"bag.mode4", 2)
$PokemonBag.pbStoreItem(:TM13)
before = pocket(1).dup
$PokemonBag.pbStoreItem(:HONEY)
check("Off: the game's own Bag (nothing placed or sorted by Kanto Reloaded)", pocket(1) == before)
R::Features.set(:reloaded_bag, :on)

errors = File.read(R::Log.path).lines.select { |l| l.include?("ERROR") || (l.include?("skipped") && l.include?("bag")) }
check("no errors, and none of the Bag's hooks skipped, in Kanto Reloaded's log (#{errors.length})", errors.empty?)
errors.first(6).each { |l| puts "  " + l }
puts $failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED"
exit($failed ? 1 : 0)
