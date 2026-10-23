# encoding: utf-8
# Offline preview of Healing Moves' screens on the Overworld Menu's preview
# (its stand-ins, the map behind): Heal with Moves (the healers, their
# moves, one dimmed saying why, the party's HP), Pick a Pokémon, the Heal
# Preview (Before and After), the toast after a heal, Heal Everyone's plan,
# Morning Sun's choice, and Light.
# Usage: ruby   Tools/Tests/healing_moves_preview.rb "<KIF Beta>" <work dir with metrics.json>
#        python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>
TEST = File.join(ARGV[0], "Mods/KantoReloaded/Tools/Tests/overworld_menu_preview.rb")
eval(File.read(TEST, :encoding => "UTF-8").split("#---------------------------------------------------------------- A: ")[0], binding, TEST)

HM = Reloaded::HealingMoves
HMS = Reloaded::HealingMovesScreen
# the Overworld Menu's preview leaves the menu's newer entries out; here
# Heal with Moves is the point
HM.send(:register_menu_entry)
OM.forget_layout
FileUtils.rm_f(LAYOUT)

#---------------------------------------------------------------- the party, with healers
NAMES_HM = { :SOFTBOILED => "Soft-Boiled", :HEALBELL => "Heal Bell", :RECOVER => "Recover", :REST => "Rest", :ROOST => "Roost",
             :MORNINGSUN => "Morning Sun", :THUNDERBOLT => "Thunderbolt", :LICK => "Lick" }.freeze
GameData::Move.singleton_class.prepend(Module.new {
  def get(m); mv = super; mv.instance_variable_set(:@name, NAMES_HM[m]) if NAMES_HM[m]; mv; end
})
MetaHM = Struct.new(:always_bicycle, :can_bicycle, :outdoor_map)
module GameData; class MapMetadata; def self.try_get(_id); MetaHM.new(false, false, true); end; end; end
class HmMove
  attr_accessor :id, :pp
  attr_reader :total_pp
  def initialize(id, pp = 10, total = 10); @id = id; @pp = pp; @total_pp = total; end
  def name; GameData::Move.get(@id).name; end
  def type; :NORMAL; end
end
class HmPk < PkPM
  attr_accessor :statusCount
  def initialize(name, sp, dex, level, hp, total, types, moves, status = nil)
    super(name, sp, level, hp, total, types, [])
    @dex_n = dex
    @moves = moves.map { |m| HmMove.new(m) }
    @status = status
  end
  def dex; @dex_n; end
  def hasMove?(m); @moves.any? { |x| x.id == m }; end
  def hp=(v); @hp = v.clamp(0, @totalhp); end
  def heal_status; @status = nil; end
  def heal_PP; @moves.each { |m| m.pp = m.total_pp }; end
  def hasItem?(_i); false; end
  def fainted?; @hp <= 0; end
end
def hm_party
  [HmPk.new("Chansey", :CHANSEY, 113, 40, 310, 320, [:NORMAL], [:SOFTBOILED, :HEALBELL]),
   HmPk.new("Pikachu", :PIKACHU, 25, 34, 40, 95, [:ELECTRIC], [:THUNDERBOLT]),
   HmPk.new("Gengar", :GENGAR, 94, 37, 70, 110, [:GHOST], [:LICK], :POISON),
   HmPk.new("Alakazam", :ALAKAZAM, 65, 38, 50, 90, [:PSYCHIC], [:RECOVER]),
   HmPk.new("Snorlax", :SNORLAX, 143, 36, 160, 160, [:NORMAL], [:REST]),
   HmPk.new("Pidgeot", :PIDGEOT, 18, 36, 80, 120, [:NORMAL], [:ROOST])]
end
$Trainer.party = hm_party

def list_says?(w); HMS.list_sprite && drawn_on?(HMS.list_sprite.bitmap, w); end
def pop_says?(w); HMS.pop_sprite && drawn_on?(HMS.pop_sprite.bitmap, w); end
def to_row(name); at { om.instance_variable_set(:@sel, row_names.index(name)); om.refresh }; end

check("Heal with Moves is on the Overworld Menu's Main page (#{OM.pages[0]["entries"].inspect})", OM.pages[0]["entries"].include?("heal_with_moves"))

#---------------------------------------------------------------- A: one move
on_map("A one move", [
  to_row("Heal with Moves"), I::USE,
  dmp("hm_01_list"),
  at { check("the list: Heal Everyone first, each healer and its moves, uses left (#{HMS.rows.length} rows)",
             list_says?("Heal Everyone") && list_says?("Chansey") && list_says?("Soft-Boiled") && list_says?("Heal Bell") &&
             list_says?("Recover") && list_says?("10 Left")) },
  at { check("...a move with nothing to do dimmed, saying why (Rest: Full HP)", list_says?("Full HP")) },
  at { check("...the Overworld Menu out of sight meanwhile", om.send(:sprites).none?(&:visible)) },
  I::DOWN, I::USE,
  dmp("hm_02_pick"),
  at { check("Soft-Boiled: Pick a Pokémon, each saying what it'd do (+55 HP for Pikachu), itself not, Snorlax at Full HP",
             pop_says?("+55 HP") && pop_says?("Itself") && pop_says?("Full HP")) },
  I::USE,
  dmp("hm_03_preview"),
  at { check("A on Pikachu: Soft-Boiled on Pikachu?, both before and after, the PP and the cost",
             pop_says?("Soft-Boiled on Pikachu?") && pop_says?("40 to 95") && pop_says?("310 to 246") && pop_says?("PP 10 to 9") &&
             pop_says?("gives up a fifth")) },
  I::USE,
  at { check("Use: Pikachu healed, Chansey gave 64 HP and 1 PP (#{$Trainer.party[1].hp}, #{$Trainer.party[0].hp})",
             $Trainer.party[1].hp == 95 && $Trainer.party[0].hp == 246 && $Trainer.party[0].moves[0].pp == 9) },
  dmp("hm_04_after"),
  at { check("...a toast says so, back in the list updated", !Reloaded::Toast.sprite.nil? && list_says?("246/320") && list_says?("9 Left")) },
  at { Reloaded::Toast.dispose },
  #---- Heal Everyone
  I::UP, I::USE,
  dmp("hm_05_plan"),
  at { check("Heal Everyone: the plan, its PP, the party's HP after", pop_says?("THE PLAN") && pop_says?("Recover") && pop_says?("Heal Bell") && pop_says?("Itself")) },
  I::USE,
  at { p = $Trainer.party
       check("...run: everyone healed (#{p.map(&:hp).inspect}, Gengar's poison #{p[2].status.inspect})",
             p[3].hp == 90 && p[5].hp == 120 && p[2].status.nil?) },
  dmp("hm_06_healed"),
  at { Reloaded::Toast.dispose },
  I::BACK,
  at { check("B: back to the Overworld Menu", om.send(:sprites).any?(&:visible) && HMS.list_sprite.nil?) },
  I::BACK
])

#---------------------------------------------------------------- B: Morning Sun
$Trainer.party = [HmPk.new("Espeon", :ESPEON, 196, 40, 80, 130, [:PSYCHIC], [:MORNINGSUN])] + hm_party.drop(1).first(2)
on_map("B morning sun", [
  to_row("Heal with Moves"), I::USE, I::DOWN, I::USE,
  dmp("hm_07_time"),
  at { check("Morning Sun: Heal Itself or Wait Until Morning, each saying what it does",
             pop_says?("Heal Itself") && pop_says?("80 to 130 HP") && pop_says?("Wait Until Morning") && pop_says?("skips to morning")) },
  I::USE,
  at { check("...Heal Itself: healed, no second question", $Trainer.party[0].hp == 130) },
  at { Reloaded::Toast.dispose },
  I::BACK, I::BACK
])

#---------------------------------------------------------------- C: Light
$Trainer.party = hm_party
S.set(Reloaded::Palette::MODE, 2)
on_map("C light", [
  to_row("Heal with Moves"), I::USE,
  dmp("hm_08_light_list"),
  I::DOWN, I::USE, I::USE,
  dmp("hm_09_light_preview"),
  at { check("Light: the Light colours", Reloaded::Palette.map_menu[:light] == true) },
  I::BACK, I::BACK, I::BACK
])
S.set(Reloaded::Palette::MODE, 0)
Reloaded::Toast.dispose

errors = File.read(Reloaded::Log.path).lines.grep(/ERROR|skipped/)
check("no errors or skipped hooks in Kanto Reloaded's log (#{errors.length})", errors.empty?)
errors.first(6).each { |l| puts "  " + l }
puts $failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED"
exit($failed ? 1 : 0)
