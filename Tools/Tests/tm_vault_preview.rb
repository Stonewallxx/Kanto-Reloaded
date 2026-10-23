# encoding: utf-8
# Offline preview of the TM Vault's screens on the preview tool's stand-ins
# (Tools/UIPreview/preview.rb), with stand-ins of the game's moves, machines,
# types and party (named and shaped as PIF 6.8.2 and KIF Beta have them):
# the Vault (Favorites first, NEW, who knows / can learn / can't, Coverage),
# Left and Right through the party, a Favorite, Sort, the Type Filter (and
# ALL clicked), Search typed into, Can't, teaching with room, Move Compare
# (Side by Side, the one to forget picked), Relearn (an Egg Move), the
# Checklist (its kinds), Relearn Moves from the party menu, the mouse, an
# empty Vault, the toast, and Light (the Randomizer's note).
# Usage: ruby   Tools/Tests/tm_vault_preview.rb "<KIF Beta>" <work dir with metrics.json>
#        python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>
PREVIEW_SETUP_ONLY = true
load File.join(ARGV[0], "Mods/KantoReloaded/Tools/UIPreview/preview.rb")
S = Reloaded::Settings unless defined?(S)
TV = Reloaded::TMVault
$VERBOSE = nil

#---------------------------------------------------------------- the game, as the Vault sees it
module Effectiveness
  INEFFECTIVE = 0; NOT_VERY_EFFECTIVE_ONE = 1; NORMAL_EFFECTIVE_ONE = 2; SUPER_EFFECTIVE_ONE = 4
end
module GameData
  class Type
    DATA = {}
    # PIF's order (the icons' rows), and what each is weak to
    WEAK = { :NORMAL => [:FIGHTING], :FIGHTING => [:FLYING, :PSYCHIC, :FAIRY], :FLYING => [:ELECTRIC, :ICE, :ROCK],
             :POISON => [:GROUND, :PSYCHIC], :GROUND => [:WATER, :GRASS, :ICE], :ROCK => [:WATER, :GRASS, :FIGHTING, :GROUND, :STEEL],
             :BUG => [:FIRE, :FLYING, :ROCK], :GHOST => [:GHOST, :DARK], :STEEL => [:FIRE, :FIGHTING, :GROUND], :QMARKS => [],
             :FIRE => [:WATER, :GROUND, :ROCK], :WATER => [:ELECTRIC, :GRASS], :GRASS => [:FIRE, :ICE, :FLYING, :POISON, :BUG],
             :ELECTRIC => [:GROUND], :PSYCHIC => [:BUG, :GHOST, :DARK], :ICE => [:FIRE, :FIGHTING, :ROCK, :STEEL],
             :DRAGON => [:ICE, :DRAGON, :FAIRY], :DARK => [:FIGHTING, :BUG, :FAIRY], :FAIRY => [:POISON, :STEEL] }.freeze
    attr_reader :id, :icon_position, :name, :pseudo_type
    def initialize(id, pos); @id = id; @icon_position = pos; @name = id == :QMARKS ? "???" : id.to_s.capitalize; @pseudo_type = id == :QMARKS; end
    def self.get(t); DATA[t] || raise("no type #{t}"); end
    def self.try_get(t); DATA[t]; end
    def self.each(&b); DATA.values.each(&b); end
    def effectiveness(attack); WEAK[@id].include?(attack) ? Effectiveness::SUPER_EFFECTIVE_ONE : Effectiveness::NORMAL_EFFECTIVE_ONE; end
  end
  class Move
    DATA = {}
    attr_reader :id, :name, :type, :category, :base_damage, :accuracy, :total_pp, :description
    def initialize(id, name, type, cat, power, acc, pp, desc)
      @id, @name, @type, @category, @base_damage, @accuracy, @total_pp, @description = id, name, type, cat, power, acc, pp, desc
    end
    def self.add(*a); DATA[a[0]] = new(*a); end
    def self.try_get(m); DATA[m.is_a?(String) ? m.to_sym : m]; end
    def self.get(m); try_get(m) || raise("no move #{m}"); end
    def self.exists?(m); !try_get(m).nil?; end
  end
  class Item
    DATA = {}
    attr_reader :id, :move, :name
    def initialize(id, move); @id = id; @move = move; @name = id.to_s; end
    def self.add(id, move); DATA[id] = new(id, move); end
    def self.try_get(i); DATA[i.is_a?(String) ? i.to_sym : i]; end
    def self.get(i); try_get(i) || raise("no item #{i}"); end
    def self.exists?(i); DATA.key?(i); end
    def self.each(&b); DATA.values.each(&b); end
    def self.icon_filename(i); "Graphics/Items/#{i}"; end
    def is_machine?; !@move.nil?; end
  end
end
%i[NORMAL FIGHTING FLYING POISON GROUND ROCK BUG GHOST STEEL QMARKS FIRE WATER GRASS ELECTRIC PSYCHIC ICE DRAGON DARK FAIRY]
  .each_with_index { |t, i| GameData::Type::DATA[t] = GameData::Type.new(t, i) }
[[:THUNDERBOLT, "Thunderbolt", :ELECTRIC, 1, 90, 100, 15, "A strong electric blast crashes down on the target. This may also leave the target with paralysis."],
 [:EARTHQUAKE, "Earthquake", :GROUND, 0, 100, 100, 10, "The user sets off an earthquake that strikes every Pokémon around it."],
 [:ICEBEAM, "Ice Beam", :ICE, 1, 90, 100, 10, "The target is struck with an icy-cold beam of energy. This may also leave the target frozen."],
 [:SHADOWBALL, "Shadow Ball", :GHOST, 1, 80, 100, 15, "The user hurls a shadowy blob at the target. This may also lower the target's Sp. Def stat."],
 [:FLAMETHROWER, "Flamethrower", :FIRE, 1, 90, 100, 15, "The target is scorched with an intense blast of fire. This may also leave the target with a burn."],
 [:PSYCHIC, "Psychic", :PSYCHIC, 1, 90, 100, 10, "The target is hit by a strong telekinetic force. This may also lower the target's Sp. Def stat."],
 [:SURF, "Surf", :WATER, 1, 90, 100, 15, "The user attacks everything around it by swamping its surroundings with a giant wave."],
 [:FLY, "Fly", :FLYING, 0, 90, 95, 15, "The user flies up into the sky and then strikes its target on the next turn."],
 [:TOXIC, "Toxic", :POISON, 2, 0, 90, 10, "A move that leaves the target badly poisoned. Its poison damage worsens every turn."],
 [:BODYSLAM, "Body Slam", :NORMAL, 0, 85, 100, 15, "The user drops onto the target with its full body weight. This may also leave the target with paralysis."],
 [:SEISMICTOSS, "Seismic Toss", :FIGHTING, 0, 1, 100, 20, "The target is thrown using the power of gravity. It inflicts damage equal to the user's level."],
 [:QUICKATTACK, "Quick Attack", :NORMAL, 0, 40, 100, 30, "The user lunges at the target at a speed that makes it almost invisible. This move always goes first."],
 [:IRONTAIL, "Iron Tail", :STEEL, 0, 100, 75, 15, "The target is slammed with a steel-hard tail. This may also lower the target's Defense stat."],
 [:DOUBLETEAM, "Double Team", :NORMAL, 2, 0, 0, 15, "By moving rapidly, the user makes illusory copies of itself to raise its evasiveness."],
 [:HYPNOSIS, "Hypnosis", :PSYCHIC, 2, 0, 60, 20, "The user employs hypnotic suggestion to make the target fall into a deep sleep."],
 [:LICK, "Lick", :GHOST, 0, 30, 100, 30, "The target is licked with a long tongue, causing damage. This may also leave the target with paralysis."],
 [:NIGHTSHADE, "Night Shade", :GHOST, 1, 1, 100, 15, "The user makes the target see a frightening mirage. It inflicts damage equal to the user's level."],
 [:CONFUSERAY, "Confuse Ray", :GHOST, 2, 0, 100, 10, "The target is exposed to a sinister ray that triggers confusion."],
 [:MEANLOOK, "Mean Look", :NORMAL, 2, 0, 0, 5, "The user pins the target with a dark, arresting look. The target becomes unable to flee."],
 [:PERISHSONG, "Perish Song", :NORMAL, 2, 0, 0, 5, "Any Pokémon that hears this song faints in three turns, unless it switches out of battle."],
 [:BITE, "Bite", :DARK, 0, 60, 100, 25, "The target is bitten with viciously sharp fangs. This may also make the target flinch."],
 [:DRAGONRAGE, "Dragon Rage", :DRAGON, 1, 1, 100, 10, "This attack hits the target with a shock wave of pure rage. This attack always inflicts 40 HP damage."],
 [:THRASH, "Thrash", :NORMAL, 0, 120, 100, 10, "The user rampages and attacks for two to three turns. The user then becomes confused."],
 [:WATERFALL, "Waterfall", :WATER, 0, 80, 100, 15, "The user charges at the target and may make it flinch."],
 [:LEER, "Leer", :NORMAL, 2, 0, 100, 30, "The user gives opponents an intimidating leer that lowers the Defense stat."],
 [:REST, "Rest", :PSYCHIC, 2, 0, 0, 5, "The user goes to sleep for two turns. This fully restores the user's HP and heals any status conditions."],
 [:ROAR, "Roar", :NORMAL, 2, 0, 0, 20, "The target is scared off and replaced by another Pokémon in its party. In the wild, the battle ends."],
 [:BULKUP, "Bulk Up", :FIGHTING, 2, 0, 0, 20, "The user tenses its muscles to bulk up its body, raising both its Attack and Defense stats."],
 [:SUNNYDAY, "Sunny Day", :FIRE, 2, 0, 0, 5, "The user intensifies the sun for five turns, powering up Fire-type moves."],
 [:GIGADRAIN, "Giga Drain", :GRASS, 1, 75, 100, 10, "A nutrient-draining attack. The user's HP is restored by half the damage taken by the target."],
 [:DIG, "Dig", :GROUND, 0, 80, 100, 10, "The user burrows into the ground, then attacks on the next turn."],
 [:FIREBLAST, "Fire Blast", :FIRE, 1, 110, 85, 5, "The target is attacked with an intense blast of all-consuming fire. This may also leave the target with a burn."],
 [:THIEF, "Thief", :DARK, 0, 60, 100, 25, "The user attacks and steals the target's held item simultaneously."],
 [:CUT, "Cut", :NORMAL, 0, 50, 95, 30, "The target is cut with a scythe or claw."],
 [:STRENGTH, "Strength", :NORMAL, 0, 80, 100, 15, "The target is slugged with a punch thrown at maximum power."]].each { |a| GameData::Move.add(*a) }
[[:HM01, :CUT], [:HM02, :FLY], [:HM03, :SURF], [:HM04, :STRENGTH], [:TM05, :ROAR], [:TM06, :TOXIC], [:TM08, :BULKUP],
 [:TM11, :SUNNYDAY], [:TM13, :ICEBEAM], [:TM19, :GIGADRAIN], [:TM24, :THUNDERBOLT], [:TM26, :EARTHQUAKE], [:TM28, :DIG],
 [:TM29, :PSYCHIC], [:TM30, :SHADOWBALL], [:TM35, :FLAMETHROWER], [:TM38, :FIREBLAST], [:TM46, :THIEF], [:POTION, nil]]
  .each { |a| GameData::Item.add(*a) }
# the kinds the maps give (the logic test reads real map bytes; here, the result)
TV.instance_variable_set(:@kinds, { "TM05" => :ground, "TM08" => :store, "TM11" => :store, "TM19" => :gift, "TM28" => :ground,
                                    "TM38" => :gift, "HM01" => :gift, "HM04" => :gift })
class Pokemon
  MAX_MOVES = 4 unless const_defined?(:MAX_MOVES)
  class Move; attr_reader :id; def initialize(id); @id = id; end; end
end
class PkT < Pokemon
  attr_accessor :name, :species, :dex, :moves, :first_moves, :relearn, :eggs, :levels
  def initialize(name, species, dex, moves, can, opts = {})
    @name, @species, @dex = name, species, dex
    @moves = moves.map { |m| Pokemon::Move.new(m) }
    @can = can
    @egg = opts[:egg]
    @first_moves = []
    @relearn = opts[:relearn] || []
    @eggs = opts[:eggs] || []
    @levels = opts[:levels] || []
  end
  def egg?; @egg ? true : false; end
  def hasMove?(m); @moves.any? { |x| x.id == m }; end
  def compatible_with_move?(m); @can.include?(m); end
  def learn_move(m); return if hasMove?(m); @moves << Pokemon::Move.new(m); @moves.shift if @moves.length > Pokemon::MAX_MOVES; end
  def forget_move_at_index(i); @relearn << @moves[i].id; @moves.delete_at(i); end
  def getMoveRelearnerList; @levels; end
end
# KIF's Change Moves list and its Egg Moves (990_KIF: KIF::MoveLearning)
module KIF
  module MoveLearning
    def self.change_moves_list(pkmn); pkmn.relearn + pkmn.eggs; end
    def self.egg_moves_for(pkmn); pkmn.eggs; end
  end
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
class TrainerT; attr_accessor :party, :tutorlist; end
class BagT; attr_reader :pockets; def initialize; @pockets = [[], []]; end; end
$PokemonBag = BagT.new
SWITCH_RANDOM_TMS = 990
$game_switches = Hash.new(false)
def pbMEPlay(*a); $log << "ME #{a[0]}"; end
# the game finds its item pictures (the HM discs) too
Object.prepend(Module.new {
  def pbResolveBitmap(path)
    return path if path.to_s.start_with?("Graphics/Items/") && File.file?(File.join(KIF_ROOT, path.to_s + ".png"))
    return super
  end
})
def make_party
  [PkT.new("Pikachu", :PIKACHU, 25, [:QUICKATTACK, :IRONTAIL, :DOUBLETEAM], [:THUNDERBOLT, :TOXIC, :BODYSLAM, :SEISMICTOSS, :FLY]),
   PkT.new("Gengar", :GENGAR, 94, [:SHADOWBALL, :HYPNOSIS, :LICK, :NIGHTSHADE], [:SHADOWBALL, :PSYCHIC, :THUNDERBOLT, :TOXIC, :ICEBEAM, :BODYSLAM],
           :relearn => [:CONFUSERAY, :MEANLOOK], :eggs => [:PERISHSONG],
           :levels => [[1, :LICK], [1, :HYPNOSIS], [1, :MEANLOOK], [27, :CONFUSERAY], [29, :NIGHTSHADE]]),
   PkT.new("Gyarados", :GYARADOS, 130, [:BITE, :DRAGONRAGE, :THRASH, :WATERFALL], [:SURF, :ICEBEAM, :EARTHQUAKE, :THUNDERBOLT, :TOXIC, :BODYSLAM],
           :relearn => [:LEER], :levels => [[20, :BITE], [1, :LEER]]),
   PkT.new("Snorlax", :SNORLAX, 143, [:BODYSLAM, :REST], [:BODYSLAM, :EARTHQUAKE, :SHADOWBALL, :ICEBEAM, :FLAMETHROWER, :SURF, :PSYCHIC]),
   PkT.new("Egg", :EGG, 0, [], [], :egg => true)]
end
$Trainer = TrainerT.new
$Trainer.party = make_party
$Trainer.tutorlist = []
VAULT = [:THUNDERBOLT, :EARTHQUAKE, :ICEBEAM, :SHADOWBALL, :FLAMETHROWER, :PSYCHIC, :SURF, :FLY, :TOXIC, :BODYSLAM, :SEISMICTOSS]
def fresh_vault
  Reloaded::SaveStore.__send__(:from_save, nil)
  VAULT.each { |m| TV.register(m, source: :tm) }
  TV.seen!
  d = TV.data
  d["seen"] -= ["ICEBEAM", "SHADOWBALL"]     # two came since the last look
  d["favorites"] = ["THUNDERBOLT"]
  d["imported"] = true
end
fresh_vault

#---------------------------------------------------------------- helpers
$pf_texts = Hash.new { |h, k| h[k] = [] }
Reloaded::Pixel.singleton_class.prepend(Module.new { def text(b, x, y, w, h, str, *r); $pf_texts[b.id] << str.to_s; super; end })
Bitmap.prepend(Module.new { def clear(*a); $pf_texts.delete(id); super; end })
$tv = nil
Reloaded::TMVaultScreen.prepend(Module.new { def main; $tv = self; super; end })
def tv_iv(n); $tv.instance_variable_get(n); end
def said?(sprite, word)
  b = tv_iv(sprite).bitmap
  $pf_texts[b.id].any? { |s| s.include?(word) } || b.ops.any? { |o| o[0] == "text" && o[5].to_s.include?(word) }
end
def top_says?(w); said?(:@top_sprite, w); end
def over_says?(w); said?(:@overlay_sprite, w); end
def hints; $tv.send(:hint_pairs).map { |p| p[1] }; end
def rows; $tv.rows; end
def cur; $tv.current; end
# Down (or Up) from the highlighted row to the move's, counted when it runs
def to_move(move)
  at {
    t = rows.index(move)
    raise "no row #{move}" unless t
    n = t - $tv.sel
    Input.queue.unshift(*[n > 0 ? I::DOWN : I::UP] * n.abs) if n != 0
  }
end
def party(name); $Trainer.party.find { |p| p.name == name }; end
def moves_of(name); party(name).moves.map(&:id); end
# The TM Vault the way the game opens it (the Pause Menu, the Overworld Menu)
def vault(label, queue, tab: :vault, pkmn: nil)
  Input.queue = queue.dup
  $tv = nil
  TV.open(tab: tab, pkmn: pkmn)
  check("#{label}: done", true)
rescue QueueEmpty => e
  check("#{label}: #{e.message}", false)
rescue Exception => e
  check("#{label}: #{e.class}: #{e.message} #{e.backtrace.first(5).inspect}", false)
end

check("the TM Vault's screen is there", defined?(Reloaded::TMVaultScreen) && TV.on?)

#---------------------------------------------------------------- A: the Vault
vault("A the vault", [
  dmp("tv_01_vault"),
  at { check("the Vault: its tabs (VAULT 11, CHECKLIST 9), Search and Sort in the header",
             top_says?("TM Vault") && top_says?("VAULT 11") && top_says?("CHECKLIST 9") && top_says?("Search") && top_says?("Sort: Name")) },
  at { check("...Favorites first (Thunderbolt), then by name (#{rows.first(3).inspect})", rows.first(3) == [:THUNDERBOLT, :BODYSLAM, :EARTHQUAKE]) },
  at { check("...NEW on the two that came since the last look, the TM's number, Tutor for none",
             top_says?("NEW") && top_says?("TM24") && top_says?("HM02")) },
  at { check("...the party: Knows It, Can Learn, Can't (Thunderbolt: Pikachu, Gengar, Gyarados can learn it, on two lines; Snorlax can't; the Egg)",
             top_says?("Learn") && top_says?("Can't") && top_says?("Egg")) },
  at { check("...Thunderbolt's details and Coverage for Pikachu (adds Flying and Water)",
             top_says?("Thunderbolt") && top_says?("POW 90") && top_says?("ACC 100") && top_says?("PP 15") &&
             top_says?("COVERAGE (PIKACHU)") && top_says?("Thunderbolt adds Flying and")) },
  at { check("...the hints: Choose, Party, Favorite, Tabs, Teach, Close (#{hints.inspect})",
             hints == ["Choose", "Party", "Favorite", "Tabs", "Teach", "Close"]) },
  I::RIGHT,
  dmp("tv_02_gengar"),
  at { check("Right: Gengar picked, its Coverage", $tv.member == 1 && top_says?("COVERAGE (GENGAR)")) },
  I::LEFT, to_move(:EARTHQUAKE), I::X,
  at { check("Y (X): Earthquake a Favorite, at the top, still highlighted (#{rows.first(2).inspect})",
             TV.favorite?(:EARTHQUAKE) && rows.first(2) == [:EARTHQUAKE, :THUNDERBOLT] && cur == :EARTHQUAKE) },
  at { check("...Pikachu can't learn it: it says so", top_says?("Pikachu can't learn it.")) },
  I::JUMPDOWN,
  dmp("tv_03_sort_type"),
  at { check("R: Sort: Type, by the game's type order after the Favorites (#{rows[2, 3].inspect})",
             top_says?("Sort: Type") && rows[2, 3] == [:BODYSLAM, :SEISMICTOSS, :FLY]) },
  I::JUMPDOWN, I::JUMPDOWN, I::JUMPDOWN, I::JUMPDOWN,
  at { check("...round to Name again", TV.sort == 0) },
  at { Input.queue.unshift(*[I::UP] * ($tv.sel + 1)) },
  at { check("Up from the top: the Type Filter (#{hints.inspect})", tv_iv(:@chips) && hints.include?("Type") && hints.include?("List")) },
  *[I::RIGHT] * 9,
  dmp("tv_04_filter"),
  at { check("Right through it: Electric, only Thunderbolt (#{$tv.type_filter.inspect}, #{rows.inspect})",
             $tv.type_filter == :ELECTRIC && rows == [:THUNDERBOLT]) },
  I::DOWN,
  at { check("Down: back in the list", !tv_iv(:@chips)) },
  [:click, 15, 66],
  at { check("ALL clicked: every move again (#{rows.length})", $tv.type_filter.nil? && rows.length == 11) },
  I::SPECIAL, "ice",
  dmp("tv_05_typing"),
  at { check("Search: typed into the header (#{rows.inspect})", rows == [:ICEBEAM] && top_says?("ice")) },
  :RETURN,
  dmp("tv_06_search"),
  at { check("...Enter: the search kept, Back clears it (#{hints.inspect})", $tv.query == "ice" && top_says?("ice") && hints.include?("Clear")) },
  I::BACK,
  at { check("Back: the search cleared, the Vault still open", $tv.query.nil? && rows.length == 11) },
  to_move(:EARTHQUAKE), I::USE,
  dmp("tv_07_cant"),
  at { check("A on a move Pikachu can't learn: it says so", over_says?("Pikachu can't learn Earthquake.")) },
  I::USE,
  to_move(:THUNDERBOLT), I::USE,
  dmp("tv_08_confirm"),
  at { check("A on Thunderbolt (three moves): Teach Thunderbolt to Pikachu?", over_says?("Teach Thunderbolt to Pikachu?") && over_says?("Teach")) },
  I::USE,
  dmp("tv_09_learned"),
  at { check("...Teach: learned, free, said so (#{moves_of("Pikachu").inspect})",
             moves_of("Pikachu") == [:QUICKATTACK, :IRONTAIL, :DOUBLETEAM, :THUNDERBOLT] && over_says?("Pikachu learned Thunderbolt.")) },
  I::USE,
  at { check("...now Knows It", top_says?("Knows It") && top_says?("Pikachu knows it already.")) },
  I::RIGHT, to_move(:PSYCHIC), I::USE,
  dmp("tv_10_compare"),
  at { check("Gengar (four moves) and Psychic: Move Compare, Teach Psychic to Gengar?, its four, FORGET on the first",
             top_says?("Teach Psychic to Gengar?") && top_says?("NEW MOVE") && top_says?("FORGET") && top_says?("Shadow Ball") &&
             top_says?("Night Shade") && top_says?("Now") && top_says?("After")) },
  at { check("...the hints: Choose, Forget This, Cancel (#{hints.inspect})", hints == ["Choose", "Forget This", "Cancel"]) },
  I::DOWN, I::DOWN,
  dmp("tv_11_compare_lick"),
  at { check("Down twice: Lick to forget, what that loses said", tv_iv(:@cmp)[2] == 2 && top_says?("Forgetting Lick")) },
  I::USE,
  at { check("...A: Psychic in Lick's place (#{moves_of("Gengar").inspect}), said so",
             moves_of("Gengar") == [:SHADOWBALL, :HYPNOSIS, :PSYCHIC, :NIGHTSHADE] && over_says?("forgot Lick") && over_says?("Psychic")) },
  I::USE,
  I::ACTION,
  dmp("tv_12_relearn"),
  at { check("X (Action): Relearn, Gengar's moves to relearn: Lick back, an Egg Move marked (#{rows.inspect})",
             rows.include?(:LICK) && rows.include?(:PERISHSONG) && top_says?("EGG") && top_says?("LV 27")) },
  at { check("...the party says how many each has", top_says?("Moves")) },
  I::ACTION,
  dmp("tv_13_checklist"),
  at { check("Checklist: the machines not had, each with its kind (#{rows.map { |r| r[0].id }.inspect})",
             rows.map { |r| r[0].id } == [:HM01, :HM04, :TM05, :TM08, :TM11, :TM19, :TM28, :TM38, :TM46] &&
             top_says?("GROUND") && top_says?("STORE") && top_says?("GIFT") && top_says?("HM01")) },
  I::JUMPDOWN,
  at { check("...in the game's order: Sort: Number, R doesn't change it", top_says?("Sort: Number") && TV.sort == 0) },
  at { check("...no Type Filter, the hints Choose, Tabs, Close (#{hints.inspect})", hints == ["Choose", "Tabs", "Close"]) },
  at { check("...no Randomizer note with it off", !top_says?("Randomizer")) },
  at { check("...an HM's own disc where the game has one (#{TV.disc_icon(:CUT)}, #{TV.disc_icon(:ROAR)})",
             TV.disc_icon(:CUT) == "Graphics/Items/machine_hm_NORMAL" && TV.disc_icon(:ROAR) == "Graphics/Items/machine_NORMAL") },
  I::ACTION, I::BACK
])
check("B: closed, everything seen (no NEW)", !TV.new?(:ICEBEAM) && !TV.new?(:SHADOWBALL))

#---------------------------------------------------------------- B: Relearn Moves from the party menu
vault("B relearn", [
  dmp("tv_14_relearn_party"),
  at { check("the party menu's Relearn Moves: Relearn on Gyarados (#{$tv.member}, #{rows.inspect})",
             $tv.member == 2 && $tv.tab == :relearn && rows == [:LEER]) },
  I::USE,
  at { check("...A on Leer (four moves): Move Compare", tv_iv(:@mode) == :compare && top_says?("Teach Leer to Gyarados?")) },
  I::BACK,
  at { check("...B: nothing taught (#{moves_of("Gyarados").inspect})", moves_of("Gyarados") == [:BITE, :DRAGONRAGE, :THRASH, :WATERFALL]) },
  I::BACK
], tab: :relearn, pkmn: party("Gyarados"))

#---------------------------------------------------------------- C: the mouse
vault("C mouse", [
  at { h = tv_iv(:@row_hits).find { |i, *| i == 3 }; Input.queue.unshift([:move, h[1] + 40, h[2] + 6]) },
  at { check("pointing at a row picks it (#{$tv.sel})", $tv.sel == 3) },
  [:wheel, -1],
  at { check("the wheel: the next row (#{$tv.sel})", $tv.sel == 4) },
  at { h = tv_iv(:@party_hits).find { |i, *| i == 3 }; Input.queue.unshift([:click, h[1] + 10, h[2] + 10]) },
  at { check("a click on Snorlax picks it", $tv.member == 3) },
  at { h = tv_iv(:@tab_hits).find { |i, *| i == 2 }; Input.queue.unshift([:click, h[1] + 10, h[2] + 5]) },
  at { check("a click on CHECKLIST opens it", $tv.tab == :checklist) },
  [:rclick, 300, 200]
])

#---------------------------------------------------------------- D: an empty Vault, the toast
Reloaded::SaveStore.__send__(:from_save, nil)
vault("D empty", [
  dmp("tv_15_empty"),
  at { check("an empty Vault says how it fills", top_says?("VAULT 0") && top_says?("Nothing here yet.") && !top_says?("Thunderbolt")) },
  I::BACK
])
TV.register(:ICEBEAM, source: :tm, notify: true)
dump("tv_16_toast")
check("a TM reaching the Bag: the toast, with the TM's disc and NEW", !Reloaded::Toast.sprite.nil?)
Reloaded::Toast.dispose

#---------------------------------------------------------------- E: Light, the Randomizer's note
fresh_vault
$Trainer.party = make_party
S.set(Reloaded::Palette::MODE, 2)
$game_switches[SWITCH_RANDOM_TMS] = true
vault("E light", [
  dmp("tv_17_light_vault"),
  at { check("Light: the Light colours", Reloaded::Palette.map_menu[:light] == true) },
  I::RIGHT, to_move(:PSYCHIC), I::USE,
  dmp("tv_18_light_compare"),
  I::BACK,
  I::ACTION, I::ACTION,
  dmp("tv_19_light_checklist"),
  at { check("the Randomizer on: the Checklist's note", top_says?("Randomizer On")) },
  I::BACK
])
S.set(Reloaded::Palette::MODE, 0)
$game_switches[SWITCH_RANDOM_TMS] = false

errors = File.read(Reloaded::Log.path).lines.grep(/ERROR|skipped/)
check("no errors or skipped hooks in Kanto Reloaded's log (#{errors.length})", errors.empty?)
errors.first(6).each { |l| puts "  " + l }
puts $failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED"
exit($failed ? 1 : 0)
