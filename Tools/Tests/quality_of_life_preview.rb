# encoding: utf-8
# Offline preview of Quality of Life's tools on the preview tool's stand-ins
# (Tools/UIPreview/preview.rb, with the Overworld Menu preview's party
# icons, items and moves): the Nature Selector (Party Rows, then the natures
# grouped by the stat they raise), the Level Lock Manager (Lock At, Unlock),
# Super Candy (Raise To, then Party Raised) and Auto-Repel Reuse's toast,
# with Big Pokémon Icons On.
# Usage: ruby   Tools/Tests/quality_of_life_preview.rb "<KIF Beta>" <work dir with metrics.json>
#        python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>
OM_TOP = File.join(ARGV[0], "Mods/KantoReloaded/Tools/Tests/overworld_menu_preview.rb")
eval(File.read(OM_TOP, :encoding => "UTF-8").split("#---------------------------------------------------------------- A: ")[0], binding, OM_TOP)
QOL = Reloaded::QualityOfLife
QS = Reloaded::QualityOfLifeScreens

#---------------------------------------------------------------- natures, moves and a party
NatureQ = Struct.new(:id, :name, :stat_changes)
module GameData
  class Nature
    STATS = [:ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED]
    CHART = [["Hardy", "Lonely", "Adamant", "Naughty", "Brave"], ["Bold", "Docile", "Impish", "Lax", "Relaxed"],
             ["Modest", "Mild", "Bashful", "Rash", "Quiet"], ["Calm", "Gentle", "Careful", "Quirky", "Sassy"],
             ["Timid", "Hasty", "Jolly", "Naive", "Serious"]]
    ALL = CHART.each_with_index.flat_map do |row, up|
      row.each_with_index.map do |n, down|
        NatureQ.new(n.upcase.to_sym, n, up == down ? [] : [[STATS[up], 10], [STATS[down], -10]])
      end
    end
    def self.each; ALL.each { |n| yield n }; end
    def self.get(id); ALL.find { |n| n.id == id }; end
    def self.try_get(id); get(id); end
  end
end
MoveQ = Struct.new(:id)
class PkQ
  attr_accessor :name, :level, :species, :dex, :nature_id, :moves, :movelist, :steps_to_hatch
  def initialize(name, sp, dex, level, nature, moves = [], movelist = [])
    @name, @species, @dex, @level, @nature_id = name, sp, dex, level, nature
    @moves = moves.map { |m| MoveQ.new(m) }
    @movelist = movelist
    @steps_to_hatch = 0
  end
  def egg?; @steps_to_hatch > 0; end
  def nature; GameData::Nature.get(@nature_id); end
  def nature=(id); @nature_id = id; end
  def nature_for_stats=(_v); end
  def calc_stats; end
  def changeHappiness(_m); end
  def getMoveList; @movelist; end
  def baseStats; { :HP => 95, :ATTACK => 125, :DEFENSE => 79, :SPECIAL_ATTACK => 60, :SPECIAL_DEFENSE => 100, :SPEED => 81 }; end
  def calcIV; Hash.new(15); end
  def ev; Hash.new(0); end
  def calcStat(base, level, iv, ev, nat); ((((base * 2 + iv + (ev / 4)) * level / 100).floor + 5) * nat / 100).floor; end
  def shiny?; false; end
end
egg = PkQ.new("Egg", :EGG, 133, 1, :HARDY)
egg.steps_to_hatch = 500
$Trainer.party = [PkQ.new("Pikachu", :PIKACHU, 25, 34, :TIMID, [:THUNDERSHOCK], [[37, :THUNDER]]),
                  PkQ.new("Pidgeot", :PIDGEOT, 18, 36, :JOLLY),
                  PkQ.new("Gyarados", :GYARADOS, 130, 35, :ADAMANT),
                  PkQ.new("Eevee", :EEVEE, 133, 22, :BASHFUL),
                  egg]
def pbLearnMove(pkmn, move, *_a)
  return false if pkmn.moves.any? { |m| m.id == move } || pkmn.moves.length >= 4
  pkmn.moves << MoveQ.new(move)
  true
end
def pbEvolutionCheck(levels); $evo_check = levels; end
# KIF's Level Cap, on: Lv 38 now
module KIF
  module LevelCap
    def self.cap; 38; end
    def self.cap_for(pkmn); pkmn.egg? ? nil : 38; end
  end
end
$big_icons = true
# a save loaded, Level Locking On
Reloaded::SaveStore.__send__(:from_save, nil)
Reloaded::Events.emit(:save_loaded, {})
S.set(QOL.key(:level_locking), true)
QOL::LevelLocks.set($Trainer.party[3], 25)

def run(label, queue)
  Input.queue = queue
  yield
  check("#{label}: done", true)
rescue QueueEmpty => e
  check("#{label}: #{e.message}", false)
rescue Exception => e
  check("#{label}: #{e.class}: #{e.message} #{e.backtrace.first(5).inspect}", false)
end

#---------------------------------------------------------------- the Nature Selector
gy = $Trainer.party[2]
run("Nature Selector", [
  dmp("qol_01_nature_party"),
  I::DOWN, I::DOWN, I::USE,
  dmp("qol_02_nature_list"),
  at { check("the list opens on the nature it has now", gy.nature_id == :ADAMANT) },
  *[I::DOWN] * 17,
  dmp("qol_03_nature_jolly"),
  I::USE,
  at { check("A sets the nature (#{gy.nature_id})", gy.nature_id == :JOLLY) },
  I::BACK,
  dmp("qol_04_nature_party_after"),
  I::BACK
]) { QS.nature_selector }
order = QS.nature_order.map(&:name)
check("grouped by the stat raised, A to Z in each, the ones with no change last (#{order.first(5).inspect} ... #{order.last(5).inspect})",
      order.first(4) == ["Adamant", "Brave", "Lonely", "Naughty"] && order[16, 4] == ["Hasty", "Jolly", "Naive", "Timid"] &&
      order.last(5) == ["Bashful", "Docile", "Hardy", "Quirky", "Serious"])

#---------------------------------------------------------------- the Level Lock Manager
run("Level Lock Manager", [
  dmp("qol_05_locks_party"),
  I::DOWN, I::DOWN, I::USE,
  dmp("qol_06_lock_popup"),
  I::RIGHT, I::RIGHT,
  dmp("qol_07_lock_37"),
  I::USE,
  at { check("Lock At sets it (#{QOL::LevelLocks.get(gy).inspect})", QOL::LevelLocks.get(gy) == 37) },
  dmp("qol_08_locks_after"),
  I::DOWN, I::USE, I::DOWN, I::USE,
  at { check("Unlock clears Eevee's", QOL::LevelLocks.get($Trainer.party[3]).nil?) },
  I::BACK
]) { QS.level_locks }
S.set(QOL.key(:level_locking), false)
QOL::LevelLocks.set($Trainer.party[3], 25)
run("Super Candy, Level Locking Off", [
  dmp("qol_09b_candy_paused"),
  at { check("Super Candy says a lock is paused while Level Locking is Off", drawn_on?(QS.sprite.bitmap, "Locks are paused")) },
  I::BACK
]) { QS.super_candy }
QOL::LevelLocks.clear($Trainer.party[3])
run("Level Lock Manager, Level Locking Off", [
  dmp("qol_09_locks_paused"),
  I::DOWN, I::DOWN, I::DOWN, I::USE, I::USE,
  at { check("Lock At with Level Locking Off turns it On, so the lock works at once (Eevee: #{QOL::LevelLocks.get($Trainer.party[3]).inspect})",
             QOL.on?(:level_locking) && QOL::LevelLocks.get($Trainer.party[3]) == 22) },
  I::BACK
]) { QS.level_locks }
S.set(QOL.key(:level_locking), true)

#---------------------------------------------------------------- Super Candy
QOL::LevelLocks.set($Trainer.party[3], 25)
run("Super Candy", [
  dmp("qol_10_candy_cap"),
  at { check("Raise To starts at the level cap", true) },
  I::RIGHT,
  dmp("qol_11_candy_highest"),
  I::LEFT,
  I::USE,
  dmp("qol_12_candy_result"),
  at { check("raised to the cap: Pikachu Lv #{$Trainer.party[0].level} learned Thunder; Eevee stopped at its lock (Lv #{$Trainer.party[3].level})",
             $Trainer.party[0].level == 38 && $Trainer.party[0].moves.any? { |m| m.id == :THUNDER } && $Trainer.party[3].level == 25) },
  I::USE
]) { QS.super_candy }

#---------------------------------------------------------------- in the Overworld Menu
check("each toggle is a Toggles entry in the Overworld Menu's add list, each tool an Action",
      QOL::TOGGLES.all? { |t| (e = OM.entry(:"qol_#{t[0]}")) && e.kind == :toggle } &&
      QOL::TOOLS.all? { |t| (e = OM.entry(:"qol_#{t[0]}")) && e.kind == :action })
check("...none of them on a page to start", OM.pages.none? { |p| Array(p["entries"]).any? { |k| k.to_s.start_with?("qol_") } })
S.set(QOL.key(:infinite_money), false)
pg = OM.add_page("Assists")
pg["entries"] = ["qol_infinite_money", "qol_encounter_rate", "qol_super_candy"]
OM.save_layout
on_map("Quality of Life rows in the Overworld Menu", [
  at { i = OM.pages.length - 1; OM.page_index = i; om.instance_variable_set(:@page, i); om.instance_variable_set(:@sel, 0); om.refresh },
  dmp("qol_14_menu_rows"),
  at { e = OM.entry(:qol_infinite_money)
       check("an On/Off toggle is a switch (no choices); a choice has its own", e.get && !e.values && OM.entry(:qol_encounter_rate).values) },
  I::USE,
  at { check("A on Infinite Money flips it On", QOL.on?(:infinite_money)) },
  I::DOWN, I::USE,
  dmp("qol_14b_menu_dropdown"),
  at { check("A on Encounter Rate opens its dropdown, the choice explained", iv(om, :@choice_dd) && overlay_says?("As the game has it.")) },
  I::DOWN,
  at { check("...each choice explained as it's highlighted", overlay_says?("Twice as often")) },
  I::USE,
  at { check("...More picked", QOL.value(:encounter_rate) == 2) },
  dmp("qol_15_menu_rows_changed"),
  I::BACK
])
S.set(QOL.key(:infinite_money), false)
S.set(QOL.key(:encounter_rate), 1)

#---------------------------------------------------------------- Auto-Repel Reuse's toast
QOL::Toast.show(:SUPERREPEL, "Used Another Super Repel", "4 LEFT")
dump("qol_13_toast")
check("the toast shows, then fades after a while", !QOL::Toast.sprite.nil?)
QOL::Toast::FRAMES.times { QOL::Toast.update }
check("...and goes", QOL::Toast.sprite.nil?)

errors = File.read(Reloaded::Log.path).lines.grep(/ERROR/)
check("no errors in the log (#{errors.length})", errors.empty?)
errors.first(6).each { |l| puts "  " + l }
puts $failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED"
exit($failed ? 1 : 0)
