# encoding: utf-8
# Offline preview of the Reloaded Bag's screen on the preview tool's
# stand-ins (Tools/UIPreview/preview.rb), driven through the game's own Bag
# logic (016_UI/007_UI_Bag.rb's PokemonBagScreen, 013_Items/008_PokemonBag.rb's
# PokemonBag, loaded as KIF Beta has them) with stand-ins for the items, the
# party and the game's item handlers: the full Bag (the pockets, empty ones
# skipped, NEW, the counts, the views, a Favorite, Search across pockets), an
# item's actions (the game's without Sort Bag, plus Favorite and Move; Toss
# with its number), a TM (the party check, Teach with the TM Vault), an
# Evolution Stone's check, moving by hand (a Custom List rewritten), leaving
# a pocket clearing NEW, a picker (its title, only what fits, nothing saved
# changing), the mouse, Light, and Off (the game's own scene).
# Usage: ruby   Tools/Tests/bag_preview.rb "<KIF Beta>" <work dir with metrics.json>
#        python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>
PREVIEW_SETUP_ONLY = true
load File.join(ARGV[0], "Mods/KantoReloaded/Tools/UIPreview/preview.rb")
S = Reloaded::Settings unless defined?(S)
B = Reloaded::Bag
$VERBOSE = nil

#---------------------------------------------------------------- the game, as the Bag sees it
module Settings
  def self.bag_pocket_names
    ["", "Items", "Medicine", "Poké Balls", "TMs & HMs", "Berries", "Mail", "Battle Items", "Key Items"]
  end
  BAG_MAX_POCKET_SIZE = [0, -1, -1, -1, -1, -1, -1, -1, -1]
  BAG_MAX_PER_SLOT = 999
  BAG_POCKET_AUTO_SORT = [0, false, false, false, true, true, false, false, false]
end
module GameData
  class Type
    DATA = {}
    attr_reader :id, :id_number, :name
    def initialize(id, n); @id = id; @id_number = n; @name = id.to_s.capitalize; end
    def self.get(t); DATA[t] || raise("no type #{t}"); end
    def self.try_get(t); DATA[t]; end
  end
  class Move
    DATA = {}
    attr_reader :id, :name, :type, :category, :base_damage, :accuracy, :total_pp, :description
    def initialize(*a); @id, @name, @type, @category, @base_damage, @accuracy, @total_pp, @description = a; end
    def self.add(*a); DATA[a[0]] = new(*a); end
    def self.get(m); DATA[m] || raise("no move #{m}"); end
    def self.try_get(m); DATA[m]; end
  end
  class Item
    DATA = {}
    attr_reader :id, :id_number, :name, :pocket, :move, :description, :field_use, :battle_use, :type
    def initialize(id, n, name, pocket, desc, field = 0, battle = 0, move = nil, hold = true)
      @id, @id_number, @name, @pocket, @description, @field_use, @battle_use, @move, @hold = id, n, name, pocket, desc, field, battle, move, hold
      @type = 0
    end
    def self.add(*a); DATA[a[0]] = new(*a); end
    def self.try_get(i); DATA[i.is_a?(String) ? i.to_sym : i]; end
    def self.get(i); try_get(i) || raise("Unknown ID #{i}"); end
    def self.exists?(i); !try_get(i).nil?; end
    def self.each; DATA.values.each { |x| yield x }; end
    def self.icon_filename(i); "Graphics/Items/#{i}"; end
    def name_plural; @name + "s"; end
    def is_machine?; !@move.nil?; end
    def is_mail?; @pocket == 6; end
    def is_key_item?; @pocket == 8; end
    def is_important?; is_key_item? || is_machine?; end
    def is_evolution_stone?; @id.to_s.end_with?("STONE"); end
    def can_hold?; @hold && !is_important?; end
  end
end
%i[NORMAL FIGHTING FLYING POISON GROUND ROCK BUG GHOST STEEL QMARKS FIRE WATER GRASS ELECTRIC PSYCHIC ICE DRAGON DARK FAIRY]
  .each_with_index { |t, i| GameData::Type::DATA[t] = GameData::Type.new(t, i) }
[[:THUNDERBOLT, "Thunderbolt", :ELECTRIC, 1, 90, 100, 15, "A strong electric blast crashes down on the target. This may also leave the target with paralysis."],
 [:ICEBEAM, "Ice Beam", :ICE, 1, 90, 100, 10, "The target is struck with an icy-cold beam of energy. This may also leave the target frozen."],
 [:TOXIC, "Toxic", :POISON, 2, 0, 90, 10, "A move that leaves the target badly poisoned. Its poison damage worsens every turn."]].each { |a| GameData::Move.add(*a) }
[[:POTION, 17, "Potion", 2, "A spray-type medicine for wounds. It restores the HP of one Pokémon by 20 points.", 1, 1],
 [:SUPERPOTION, 18, "Super Potion", 2, "A spray-type medicine for wounds. It restores the HP of one Pokémon by 50 points.", 1, 1],
 [:HYPERPOTION, 19, "Hyper Potion", 2, "A spray-type medicine for wounds. It restores the HP of one Pokémon by 200 points.", 1, 1],
 [:ICEHEAL, 23, "Ice Heal", 2, "A spray-type medicine for freezing. It can be used once to defrost a Pokémon.", 1, 1],
 [:FULLHEAL, 27, "Full Heal", 2, "A spray-type medicine that is broadly effective. It heals all the status problems of one Pokémon.", 1, 1],
 [:RARECANDY, 50, "Rare Candy", 2, "A candy that is packed with energy. It raises the level of a single Pokémon by one.", 1, 0],
 [:REPEL, 30, "Repel", 1, "An item that prevents weak wild Pokémon from appearing for 100 steps.", 2, 0],
 [:ESCAPEROPE, 31, "Escape Rope", 1, "A long, durable rope. Use it to escape instantly from a cave or a dungeon.", 2, 0],
 [:NEVERMELTICE, 33, "Never-Melt Ice", 1, "A piece of ice that repels heat effects. It boosts the power of Ice-type moves.", 0, 0],
 [:THUNDERSTONE, 34, "Thunder Stone", 1, "A peculiar stone that makes certain species of Pokémon evolve.", 1, 0],
 [:ORANBERRY, 400, "Oran Berry", 5, "A Berry to be held by a Pokémon. It restores 10 HP when its HP is low.", 1, 1],
 [:TM24, 318, "TM24", 4, "", 3, 0, :THUNDERBOLT], [:TM13, 307, "TM13", 4, "", 3, 0, :ICEBEAM], [:TM06, 300, "TM06", 4, "", 3, 0, :TOXIC],
 [:BICYCLE, 600, "Bicycle", 8, "A folding Bicycle that enables a rider to get around much faster than with Running Shoes.", 2, 0]]
  .each { |a| GameData::Item.add(*a) }
def updatePinkanBerryDisplay; end
module ItemHandlers
  def self.hasOutHandler(i); ![:NEVERMELTICE].include?(i); end
  def self.hasUseText(i); false; end
  def self.getUseText(i); nil; end
  def self.hasUseInFieldHandler(i); [:REPEL, :ESCAPEROPE, :BICYCLE].include?(i); end
end
def pbCanRegisterItem?(item); GameData::Item.get(item).is_key_item?; end
def pbUseItem(bag, item, scene = nil); $log << "USE ITEM #{item}"; 1; end
class Window_DrawableCommand; end
# the game's own Bag and its screen
load File.join(SCRIPTS, "013_Items/008_PokemonBag.rb")
load File.join(SCRIPTS, "016_UI/007_UI_Bag.rb")
B.send(:install)
Reloaded::BagScreen.send(:install)
class PkB
  attr_reader :name, :species, :dex, :moves
  attr_accessor :hp, :totalhp, :status, :item_id         # 014_Pokemon/001_Pokemon.rb (item_id: the held item's id)
  Mv = Struct.new(:id)
  def initialize(name, species, dex, moves, can, evolves = nil, egg = false)
    @name, @species, @dex, @can, @evolves, @egg = name, species, dex, can, evolves, egg
    @moves = moves.map { |m| Mv.new(m) }
    @hp = @totalhp = 100
    @status = :NONE
    @item_id = nil
  end
  def egg?; @egg; end
  def hasMove?(m); @moves.any? { |x| x.id == m }; end
  def compatible_with_move?(m); @can.include?(m); end
  def check_evolution_on_use_item(item); @evolves == item ? :RAICHU : nil; end
end
class PokemonIconSprite < Sprite
  attr_accessor :kif_big_offset
  def initialize(pkmn, vp = nil)
    super(vp)
    self.bitmap = Bitmap.new(pkmn.egg? ? "Graphics/Icons/iconEgg" : "Graphics/Pokemon/Icons/#{pkmn.species}.png")
    self.src_rect = Rect.new(0, 0, 64, 64)
  end
  def update; end
end
module KIF; module BigIcons; end; end
KIF::BigIcons.define_singleton_method(:mode) { 0 }
class TrainerB
  attr_accessor :party
  def pokemon_party; @party.reject(&:egg?); end
  def pokemon_count; pokemon_party.length; end
  def party_count; @party.length; end
  def female?; false; end
end
$Trainer = TrainerB.new
$Trainer.party = [PkB.new("Pikachu", :PIKACHU, 25, [:THUNDERBOLT], [:THUNDERBOLT, :TOXIC], :THUNDERSTONE),
                  PkB.new("Gengar", :GENGAR, 94, [], [:THUNDERBOLT, :ICEBEAM, :TOXIC]),
                  PkB.new("Gyarados", :GYARADOS, 130, [], [:ICEBEAM, :TOXIC]),
                  PkB.new("Snorlax", :SNORLAX, 143, [], [:ICEBEAM, :THUNDERBOLT, :TOXIC]),
                  PkB.new("Egg", :EGG, 0, [], [], nil, true)]
# the TM Vault's Teach: logged (the Vault has its own preview)
Reloaded::TMVault.singleton_class.prepend(Module.new { def open(tab: :vault, pkmn: nil, focus: nil); $log << "TM VAULT #{tab} #{focus}"; true; end })

Reloaded::SaveStore.__send__(:from_save, nil)
Reloaded::Events.emit(:save_loaded, {})
$PokemonBag = PokemonBag.new
[[:POTION, 5], [:HYPERPOTION, 3], [:RARECANDY, 2], [:REPEL, 4], [:ESCAPEROPE, 1], [:NEVERMELTICE, 1], [:THUNDERSTONE, 1],
 [:TM24, 1], [:TM06, 1], [:ORANBERRY, 6], [:BICYCLE, 1]].each { |i, q| $PokemonBag.pbStoreItem(i, q) }
B.refresh_seen!                                   # what's there counts as seen
$PokemonBag.pbStoreItem(:SUPERPOTION, 2)          # ...and these came since
$PokemonBag.pbStoreItem(:TM13, 1)
$PokemonBag.pbStoreItem(:ICEHEAL, 1)
$PokemonBag.lastpocket = 2

#---------------------------------------------------------------- helpers
$pf_texts = Hash.new { |h, k| h[k] = [] }
Reloaded::Pixel.singleton_class.prepend(Module.new { def text(b, x, y, w, h, str, *r); $pf_texts[b.id] << str.to_s; super; end })
Bitmap.prepend(Module.new { def clear(*a); $pf_texts.delete(id); super; end })
$bs = nil
Reloaded::BagScreen.scene_class.prepend(Module.new { def pbStartScene(*a); $bs = self; super; end })
# Recent Steps, as the game boots it (here the game's Bag comes after Kanto Reloaded)
Reloaded::BugReport::Trail.install
def bag_steps; Reloaded::BugReport::Trail.lines.count { |l| l.end_with?("Menu  Bag") }; end
def bs_iv(n); $bs.instance_variable_get(n); end
def said?(sprite, word)
  b = bs_iv(sprite).bitmap
  $pf_texts[b.id].any? { |s| s.include?(word) } || b.ops.any? { |o| o[0] == "text" && o[5].to_s.include?(word) }
end
def top_says?(w); said?(:@top_sprite, w); end
def over_says?(w); said?(:@overlay_sprite, w); end
def hints; $bs.send(:hint_pairs).map { |p| p[1] }; end
def rows; bs_iv(:@rows).map { |r| r[0] == :item ? r[1] : [:heading, r[1]] }; end
def cur; $bs.send(:current); end
def to_item(id)
  at {
    t = bs_iv(:@rows).index { |r| r[0] == :item && r[1] == id }
    raise "no row #{id}" unless t
    n = t - bs_iv(:@sel)
    Input.queue.unshift(*[n > 0 ? I::DOWN : I::UP] * n.abs) if n != 0
  }
end
def pocket_ids(n); $PokemonBag.pockets[n].map { |s| s[0] }; end
OM = Reloaded::OverworldMenu
def toast_says?(w)
  sp = Reloaded::Toast.instance_variable_get(:@sprite)
  return sp && !sp.disposed? && ($pf_texts[sp.bitmap.id].any? { |s| s.include?(w) } || sp.bitmap.ops.any? { |o| o[0] == "text" && o[5].to_s.include?(w) })
end
# Down to an action in the open menu (its rows as the overlay drew them)
def menu_down_to(label)
  said = $pf_texts[bs_iv(:@overlay_sprite).bitmap.id]
  labels = said.drop(1).take_while { |s| s != _INTL("Cancel") } + [_INTL("Cancel")]
  n = labels.index(label)
  raise "no action #{label} in #{labels.inspect}" unless n
  Input.queue.unshift(*[I::DOWN] * n)
end
# The pause menu's Bag, as the game opens it
def full_bag(label, queue)
  Input.queue = queue.dup
  $bs = nil
  $ret = PokemonBagScreen.new(PokemonBag_Scene.new, $PokemonBag).pbStartScreen
  check("#{label}: done", true)
rescue QueueEmpty => e
  check("#{label}: #{e.message}", false)
rescue Exception => e
  check("#{label}: #{e.class}: #{e.message} #{e.backtrace.first(5).inspect}", false)
end

check("the game makes Kanto Reloaded's Bag scene", PokemonBag_Scene.new.is_a?(Reloaded::BagScene))

#---------------------------------------------------------------- A: the full Bag
full_bag("A full bag", [
  dmp("bag_01_medicine"),
  at { check("the Bag: Search and Sort in the header, the pocket's name (#{rows.inspect})",
             top_says?("Bag") && top_says?("Search") && top_says?("Sort: Bag Order") && top_says?("Medicine")) },
  at { check("...the Medicine pocket in its Custom List's order (old Kanto Reloaded's)",
             rows == [:RARECANDY, :POTION, :SUPERPOTION, :HYPERPOTION, :ICEHEAL]) },
  at { check("...NEW on what came since, the counts (x5)", top_says?("NEW") && top_says?("x5")) },
  at { check("...the hints: Choose, Pockets, Actions, Favorite, Close (#{hints.inspect})",
             hints == ["Choose", "Pockets", "Actions", "Favorite", "Close"]) },
  to_item(:HYPERPOTION),
  dmp("bag_02_details"),
  at { check("an item's details: what it's good for (USE, IN BATTLE), its description",
             top_says?("Hyper Potion") && top_says?("USE") && top_says?("IN BATTLE")) },
  I::JUMPDOWN,
  at { check("R: the next view, A-Z (#{rows.inspect})", top_says?("Sort: A-Z") && rows.first(2) == [:HYPERPOTION, :ICEHEAL]) },
  *[I::JUMPDOWN] * 5,
  at { check("...round to Bag Order again", B.view(2) == 0) },
  to_item(:POTION), I::X,
  at { check("Y (X): Potion a Favorite, first (#{rows.first(2).inspect})", B.favorite?(:POTION) && rows.first == :POTION && cur == :POTION) },
  I::RIGHT,
  at { check("Right: Poké Balls is empty, skipped: TMs & HMs (#{$bs.instance_variable_get(:@pocket)})", bs_iv(:@pocket) == 4) },
  at { check("...leaving Medicine cleared its NEW", !B.new?(:SUPERPOTION) && !B.pocket_new?(2)) },
  dmp("bag_03_tms"),
  at { check("TMs & HMs: the move's names coloured, each TM's number and type (#{rows.inspect})",
             top_says?("Thunderbolt") && top_says?("TM24") && rows == [:TM06, :TM13, :TM24]) },
  at { check("...the party check: Learned, Able, Not Able, Egg (Toxic)",
             top_says?("Able") && top_says?("Egg") && top_says?("POW --")) },
  to_item(:TM24),
  at { check("...Thunderbolt: Pikachu Learned", top_says?("Learned")) },
  I::USE,
  dmp("bag_04_tm_actions"),
  at { check("A: the TM's actions: Teach (the TM Vault) in the game's Use's place, Favorite, no Move (Number) (#{$pf_texts[bs_iv(:@overlay_sprite).bitmap.id].inspect})",
             over_says?("Teach") && over_says?("Favorite") && !over_says?("Move") && !over_says?("Sort bag")) },
  I::USE,
  at { check("...Teach: the TM Vault on Thunderbolt", $log.include?("TM VAULT vault THUNDERBOLT")) },
  I::LEFT, I::LEFT,
  at { check("Left: back past Poké Balls to Medicine, then Items (#{bs_iv(:@pocket)})", bs_iv(:@pocket) == 1) },
  to_item(:THUNDERSTONE),
  dmp("bag_05_stone"),
  at { check("an Evolution Stone: who it can evolve (Pikachu Can Evolve)", top_says?("Can Evolve") && top_says?("Can't")) },
  to_item(:REPEL), I::USE,
  dmp("bag_06_actions"),
  at { check("A on Repel: the game's actions without Sort Bag, plus Favorite and Move (Custom List)",
             over_says?("Use") && over_says?("Toss") && over_says?("Favorite") && over_says?("Move") && !over_says?("Sort bag")) },
  at { Input.queue.unshift(*[I::DOWN] * ($pf_texts[bs_iv(:@overlay_sprite).bitmap.id].index("Move") - $pf_texts[bs_iv(:@overlay_sprite).bitmap.id].index("Use"))) },
  I::USE,
  at { check("Move: the slot carried (#{hints.inspect})", hints == ["Move", "Done", "Cancel"]) },
  I::DOWN,
  dmp("bag_07_moving"),
  I::USE,
  at { check("...put down: the pocket and its Custom List follow (#{pocket_ids(1).inspect})",
             pocket_ids(1).index(:REPEL) > pocket_ids(1).index(:ESCAPEROPE) && B.custom_list(1).index("REPEL") > B.custom_list(1).index("ESCAPEROPE")) },
  to_item(:REPEL), I::USE,
  at { check("...the highlighted action explained under the list (Use: Use it now), Add to Quick Items (#{hints.inspect})",
             over_says?("Use it now.") && over_says?("Add to Quick Items") && hints == ["Choose", "Pick", "Back"]) },
  at { menu_down_to("Favorite") },
  at { check("...Favorite: Keep it at the top of Items", over_says?("Keep it at the top of Items.")) },
  at { Input.queue.unshift(*[I::UP] * 3) },
  at { menu_down_to("Toss") },
  at { check("...Toss: Throw some away", over_says?("Throw some away.")) },
  I::USE,
  dmp("bag_08_toss"),
  at { check("Toss (his pick): how many, with the item's picture and what stays (#{hints.inspect})",
             over_says?("Toss How Many?") && over_says?("3 stay in the Bag") && hints == ["One", "Ten", "Toss", "Cancel"]) },
  I::RIGHT,
  at { check("...Right: one more", over_says?("2 stay in the Bag")) },
  I::USE,
  dmp("bag_08b_toss_question"),
  at { check("...then Kanto Reloaded's question, Keep chosen first (#{hints.inspect})",
             over_says?("Toss 2 Repels?") && over_says?("You can't get them back.") && hints == ["Choose", "OK", "Keep"]) },
  I::USE,
  at { check("...so A at once keeps them (#{$PokemonBag.pbQuantity(:REPEL)})", $PokemonBag.pbQuantity(:REPEL) == 4) },
  I::USE,
  at { menu_down_to("Toss") },
  I::USE, I::RIGHT, I::USE, I::LEFT, I::USE,
  dmp("bag_08c_tossed"),
  at { check("...Toss: 2 of 4 Repels gone, a toast says so (#{$PokemonBag.pbQuantity(:REPEL)})",
             $PokemonBag.pbQuantity(:REPEL) == 2 && toast_says?("Tossed 2 Repels") && toast_says?("2 LEFT")) },
  I::USE,
  at { menu_down_to("Add to Quick Items") },
  I::USE,
  at { check("Add to Quick Items: the first empty slot, a toast says which (#{OM.quick_items.inspect})",
             OM.quick_items[0] == :REPEL && toast_says?("Quick Items: Repel") && toast_says?("SLOT 1")) },
  at { check("...the details: QUICK SLOT 1", top_says?("QUICK SLOT 1")) },
  I::USE,
  at { check("...and the actions offer to take it out", over_says?("Remove From Quick Items")) },
  at { menu_down_to("Remove From Quick Items") },
  at { check("...explained: Take it out of Quick Items slot 1", over_says?("Take it out of Quick Items")) },
  I::USE,
  at { check("...Remove From Quick Items: the slot empty again", OM.quick_items[0].nil? && toast_says?("Removed From Quick Items: Repel")) },
  at { [:POTION, :HYPERPOTION, :RARECANDY, :ESCAPEROPE, :BICYCLE, :TM24, :ORANBERRY].each_with_index { |id, i| OM.set_quick_item(i, id) } },
  to_item(:REPEL), I::USE,
  at { menu_down_to("Add to Quick Items") },
  I::USE,
  dmp("bag_08d_slots"),
  at { check("...all seven full: a row of the slots asks which to replace (#{hints.inspect})",
             over_says?("Replace Which Slot?") && over_says?("Slot 1: Potion") && over_says?("Repel goes in its place.") &&
             hints == ["Slot", "Replace", "Cancel"]) },
  I::RIGHT, I::RIGHT,
  at { check("...Right: slot 3", over_says?("Slot 3: Rare Candy")) },
  I::USE,
  at { check("...A: Repel in slot 3 (#{OM.quick_items.inspect})", OM.quick_items[2] == :REPEL && toast_says?("SLOT 3")) },
  at { OM.quick_items.each_index { |i| OM.set_quick_item(i, nil) } },
  I::SPECIAL, "ice",
  dmp("bag_09_search"),
  at { check("Search: every pocket's matches by word start, under headings (#{rows.inspect})",
             rows == [[:heading, 1], :NEVERMELTICE, [:heading, 2], :ICEHEAL, [:heading, 4], :TM13]) },
  :RETURN,
  at { check("...Enter: kept; Back clears it", top_says?("Every Pocket") && hints.include?("Clear")) },
  I::BACK,
  at { check("...cleared", bs_iv(:@query).nil?) },
  I::BACK
])
check("B: closed", $ret.nil?)
check("Recent Steps saw the Bag open, once (#{bag_steps})", bag_steps == 1)

#---------------------------------------------------------------- B: a picker
Reloaded::Toast.dispose          # the last section's toast, gone (its frames don't run here)
$PokemonBag.pbStoreItem(:SUPERPOTION, 1)
favorites_before = B.favorites(2).dup
Input.queue = [
  dmp("bag_10_picker"),
  at { check("a picker (his pick: a Banner): the Bag's header, a banner over the list says what's chosen, only what fits (Berries) (#{rows.inspect})",
             top_says?("Bag") && top_says?("PLANT A BERRY") && rows == [:ORANBERRY] && bs_iv(:@pocket) == 5) },
  at { check("...the hints: Choose, Plant, Cancel (no Pockets with one, no Favorite) (#{hints.inspect})", hints == ["Choose", "Plant", "Cancel"]) },
  I::X,
  I::USE
]
picked = Reloaded::BagScreen.during(:@title, :soil) do
  PokemonBagScreen.new(PokemonBag_Scene.new, $PokemonBag).pbChooseItemScreen(proc { |i| GameData::Item.get(i).pocket == 5 })
end
check("...A: the item it picked (#{picked.inspect}), nothing saved changed (NEW stays, no Favorite)",
      picked == :ORANBERRY && B.favorites(5).empty? && B.favorites(2) == favorites_before)
pika = $Trainer.party[0]
check("a picker's words: the party's Pokémon named, or not (#{Reloaded::BagScreen.titled("Give an Item to {1}", "Give", pika).inspect})",
      Reloaded::BagScreen.titled("Give an Item to {1}", "Give", pika) == ["Give an Item to Pikachu", "Give"] &&
      Reloaded::BagScreen.titled("Use an Item on {1}", "Use", nil) == ["Use an Item", "Use"])
Input.queue = [
  dmp("bag_10b_give"),
  at { check("...Give from the party: GIVE AN ITEM TO PIKACHU, A says Give (#{hints.inspect})",
             top_says?("GIVE AN ITEM TO PIKACHU") && hints.include?("Give") && bs_iv(:@scroll).to_i == 0) },
  I::BACK
]
party_scene = Object.new
party_scene.instance_variable_set(:@party, $Trainer.party)
party_scene.instance_variable_set(:@activecmd, 0)
Reloaded::BagScreen.during(:@title, Reloaded::BagScreen.titled("Give an Item to {1}", "Give", Reloaded::BagScreen.highlighted(party_scene))) do
  PokemonBagScreen.new(PokemonBag_Scene.new, $PokemonBag).pbChooseItemScreen(proc { |i| GameData::Item.get(i).can_hold? })
end

#---------------------------------------------------------------- C: the mouse, Light
RUN_MODE = S.get(Reloaded::Palette::MODE)     # the run's own Theme Mode (KR_THEME_MODE), back after each section
S.set(Reloaded::Palette::MODE, 2)
full_bag("C light", [
  dmp("bag_11_light"),
  at { check("Light: the Light colours", Reloaded::Palette.map_menu[:light] == true) },
  at { h = bs_iv(:@pocket_hits).find { |p, *| p == 4 }; Input.queue.unshift([:click, h[1] + 10, h[2] + 10]) },
  at { check("a click on TMs & HMs opens it", bs_iv(:@pocket) == 4) },
  dmp("bag_12_light_tms"),
  at { h = bs_iv(:@row_hits).find { |i, *| i == 1 }; Input.queue.unshift([:move, h[1] + 40, h[2] + 6]) },
  at { check("pointing at a row picks it (#{bs_iv(:@sel)})", bs_iv(:@sel) == 1) },
  [:rclick, 300, 200]
])
S.set(Reloaded::Palette::MODE, RUN_MODE)

#---------------------------------------------------------------- E: the Bag page (his pick: two headings)
Reloaded::Toast.dispose          # the last section's toast, gone (its frames don't run here)
$in_game = true
def scr_says?(w)
  b = scr.overlay
  $pf_texts[b.id].any? { |s| s.include?(w) } || b.ops.any? { |o| o[0] == "text" && o[5].to_s.include?(w) }
end
def kr_rows; scr.send(:rows).map(&:label); end
drive("E the Bag page", [
  I::RIGHT,
  at { check("Kanto Reloaded > Bag: New Items, Starting Lists, Edit Custom Lists, Export Lists, Import Lists (#{kr_rows.inspect})",
             (i = kr_rows.index("New Items")) && kr_rows[i, 5] == ["New Items", "Starting Lists", "Edit Custom Lists", "Export Lists", "Import Lists"]) },
  at { check("...then Bag - Auto-Sort: a row per pocket", (i = kr_rows.index("Medicine")) && kr_rows[i - 1] == "Items" && kr_rows[i + 6] == "Key Items") },
  down_to("Export Lists"), I::USE,
  dmp("bag_13_exported"),
  at { check("Export Lists: the file in the Kanto Reloaded folder, where it went and what's in it, Open Folder (his pick)",
             File.file?(B.export_path) && scr_says?("Lists Exported") && scr_says?("pockets") && scr_says?("Open Folder")) },
  I::USE,
  down_to("Import Lists"), I::USE,
  dmp("bag_14_import"),
  at { check("Import Lists: asks first with what's in the file (his pick), Keep Mine chosen", scr_says?("Replace Your Lists?") && scr_says?("Keep Mine") && scr_says?("exported")) },
  I::LEFT, I::USE,
  at { check("...Replace: brought in, a notice says how many", scr_says?("Lists Imported") && scr_says?("pockets")) },
  I::USE,
  down_to("Medicine"),
  dmp("bag_15_page"),
  at { check("...Medicine's row: Custom List, THIS SAVE (#{row_name})", row_name == "Medicine") },
  I::USE,
  dmp("bag_16_dropdown"),
  I::BACK, I::BACK, I::BACK
])

#---------------------------------------------------------------- F: the Custom List editor (his pick: Full Screen)
Reloaded::Toast.dispose          # the last section's toast, gone (its frames don't run here)
$le = nil
Reloaded::BagListScreen.prepend(Module.new { def main; $le = self; super; end })
def le_rows; $le.rows.map { |r| r[0] == :heading ? "#" + r[1] : r[1] }; end
def le_hints; $le.send(:hint_pairs).map { |p| p[1] }; end
def le_top?(w); b = $le.instance_variable_get(:@top_sprite).bitmap; $pf_texts[b.id].any? { |s| s.include?(w) } || b.ops.any? { |o| o[0] == "text" && o[5].to_s.include?(w) }; end
def le_over?(w); b = $le.overlay; $pf_texts[b.id].any? { |s| s.include?(w) } || b.ops.any? { |o| o[0] == "text" && o[5].to_s.include?(w) }; end
def le_to(id); at { t = $le.rows.index { |r| r[1] == id }; n = t - $le.sel; Input.queue.unshift(*[n > 0 ? I::DOWN : I::UP] * n.abs) if n != 0 }; end
B.set_list(2, ["#Candy", "RARECANDY", "#Healing", "POTION", "SUPERPOTION", "HYPERPOTION", "ICEHEAL"])
S.set(:"bag.mode2", 1)
[[0, "dark"], [2, "light"]].each do |mode, word|
  S.set(Reloaded::Palette::MODE, mode)
  Input.queue = [le_to(:SUPERPOTION), dmp("bag_17_editor_#{word}"), I::BACK]
  Reloaded::BagListScreen.open(2)
end
S.set(Reloaded::Palette::MODE, RUN_MODE)
Input.queue = [
  at { check("the editor: Custom Lists, Medicine's list with its headings, those in the Bag coloured (#{le_rows.inspect})",
             le_top?("Custom Lists") && le_top?("Defaults") && le_top?("Medicine") && le_rows == ["#Candy", :RARECANDY, "#Healing", :POTION, :SUPERPOTION, :HYPERPOTION, :ICEHEAL]) },
  at { check("...the hints: Choose, Pockets, Actions, Move, Add Item, Done (#{le_hints.inspect})", le_hints == ["Choose", "Pockets", "Actions", "Move", "Add Item", "Done"]) },
  le_to(:POTION),
  at { check("...the details: IN THE BAG, where Medicine shows it", le_top?("IN THE BAG") && le_top?("After Rare Candy")) },
  le_to(:HYPERPOTION), I::ACTION, I::UP,
  dmp("bag_18_editor_moving"),
  at { check("X (Action): Hyper Potion carried up, MOVING (#{le_hints.inspect})", le_top?("MOVING") && le_top?("Moving Hyper Potion") && le_hints == ["Move", "Put Here", "Cancel"]) },
  I::UP, I::USE,
  at { check("...A puts it down: the save's list follows (#{B.custom_list(2).inspect})",
             B.custom_list(2) == ["#Candy", "RARECANDY", "#Healing", "HYPERPOTION", "POTION", "SUPERPOTION", "ICEHEAL"]) },
  at { check("...and Medicine (a Custom List) sorts again (#{pocket_ids(2).first(3).inspect})", pocket_ids(2).index(:HYPERPOTION) < pocket_ids(2).index(:POTION)) },
  I::ACTION, I::DOWN, I::BACK,
  at { check("...B puts it back", B.custom_list(2)[3] == "HYPERPOTION") },
  I::USE,
  dmp("bag_19_editor_actions"),
  at { check("A: its actions (Move, Remove From List, Add a Heading Above)", le_over?("Remove From List") && le_over?("Add a Heading Above")) },
  I::DOWN, I::DOWN, I::USE, "Strong", :RETURN,
  at { check("...Add a Heading Above: typed in, in its place (#{B.custom_list(2).inspect})", B.custom_list(2)[3] == "#Strong" && B.custom_list(2)[4] == "HYPERPOTION") },
  le_to(:ICEHEAL), I::X,
  dmp("bag_20_editor_add"),
  at { check("Y (X): Add to Medicine (his pick: a list to search), the pocket's items not on the list, where it goes (#{le_hints.inspect})",
             le_over?("Add to Medicine") && le_over?("Type to Search") && le_over?("Full Heal") && le_over?("It goes after Ice Heal.") &&
             le_hints == ["Choose", "Add", "Search", "Back"]) },
  I::X, "zz", :RETURN,
  at { check("...Y types into its field: nothing matches zz", le_over?("Nothing matches") && le_hints.include?("Clear")) },
  I::BACK,
  at { check("...B clears the search first", le_over?("Full Heal") && le_hints.include?("Back")) },
  I::USE,
  at { check("...added after Ice Heal (#{B.custom_list(2).last(2).inspect})", B.custom_list(2).last(2) == ["ICEHEAL", "FULLHEAL"]) },
  I::JUMPDOWN,
  dmp("bag_21_editor_defaults"),
  at { check("R: Defaults asks first with what changes (his pick), Keep Mine chosen", le_over?("Restore the Defaults?") && le_over?("Keep Mine") && le_over?("become")) },
  I::USE,
  at { check("...Keep Mine: nothing changed", B.custom_list(2).include?("#Strong")) },
  I::JUMPDOWN, I::LEFT, I::USE,
  at { check("...Restore: old Kanto Reloaded's list again", B.custom_list(2) == B.default_list(2)) },
  I::RIGHT,
  at { check("Right: the next pocket (#{$le.pocket})", $le.pocket == 3 && le_top?("Poké Balls")) },
  I::BACK
]
Reloaded::BagListScreen.open(2)
check("B: done", true)
drive("F the editor from Kanto Reloaded > Bag", [
  I::RIGHT, down_to("Edit Custom Lists"), I::USE,
  at { check("Edit Custom Lists opens the editor", !$le.nil? && $le.instance_variable_get(:@sprite) && !$le.instance_variable_get(:@sprite).disposed?) },
  I::BACK, I::BACK, I::BACK
])

#---------------------------------------------------------------- G: a Custom List's headings in the Bag (his pick: Like the Editor)
Reloaded::Toast.dispose
B.set_list(2, ["#Candy", "RARECANDY", "#Healing", "POTION", "SUPERPOTION", "HYPERPOTION", "#Status", "ICEHEAL"])
S.set(:"bag.mode2", 1)
B.set_view(2, 0)
B.set_favorites(2, ["HYPERPOTION"])
$PokemonBag.lastpocket = 2
full_bag("G headings", [
  dmp("bag_22_headings"),
  at { check("the Bag shows your Custom List's headings: Favorites first, then the list's in order (#{rows.inspect})",
             rows == [[:heading, "Favorites"], :HYPERPOTION, [:heading, "Candy"], :RARECANDY, [:heading, "Healing"], :POTION, :SUPERPOTION,
                      [:heading, "Status"], :ICEHEAL]) },
  at { check("...the cursor skips them", cur.is_a?(Symbol)) },
  I::JUMPDOWN,
  at { check("...not in another view (A-Z)", rows.none? { |r| r.is_a?(Array) }) },
  *[I::JUMPDOWN] * 5,
  I::BACK
])

#---------------------------------------------------------------- H: Who Needs It and Held Items (his picks: Party Grid, HELD Pill)
Reloaded::Toast.dispose
party = $Trainer.party
party[0].hp = 60                          # Pikachu hurt
party[1].hp = 0                           # Gengar fainted
party[3].status = :POISON                 # Snorlax poisoned
party[0].item_id = :NEVERMELTICE          # Pikachu holds Never-Melt Ice (one more in the Bag)
B.set_list(2, B.default_list(2))          # (no headings: to_item steps row by row)
B.set_favorites(2, [])
$PokemonBag.lastpocket = 2
full_bag("H party checks", [
  to_item(:POTION),
  dmp("bag_23_who_needs_it"),
  at { check("Who Needs It: a Potion's details show the party, each Can Heal, Fainted or Full HP",
             top_says?("Can Heal") && top_says?("Fainted") && top_says?("Full HP") && top_says?("Egg")) },
  to_item(:ICEHEAL),
  at { check("...an Ice Heal: Can't Cure the poisoned one, Healthy the rest", top_says?("Can't Cure") && top_says?("Healthy")) },
  I::LEFT,
  to_item(:NEVERMELTICE),
  dmp("bag_24_held"),
  at { check("Held Items: a HELD pill on the row and in the details, and who holds it", top_says?("HELD") && top_says?("Held by:") && top_says?("Pikachu")) },
  I::BACK
])
party.each { |p| p.hp = p.totalhp; p.status = :NONE; p.item_id = nil }

#---------------------------------------------------------------- D: Off
Reloaded::Features.set(:reloaded_bag, :off)
check("Off: the game's own Bag scene", !PokemonBag_Scene.new.is_a?(Reloaded::BagScene))
Reloaded::Features.set(:reloaded_bag, :on)

errors = File.read(Reloaded::Log.path).lines.grep(/ERROR|skipped/)
check("no errors or skipped hooks in Kanto Reloaded's log (#{errors.length})", errors.empty?)
errors.first(6).each { |l| puts "  " + l }
puts $failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED"
exit($failed ? 1 : 0)
