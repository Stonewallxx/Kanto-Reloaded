# encoding: utf-8
# Offline preview of the PokeVial's screens on the Overworld Menu's preview
# (its stand-ins, the map behind): the Overworld Menu's PokeVial row (its
# charges as Poké Balls, the Low HP Reminder's glow), the dialog (ready,
# used, cooling down, empty, Back), the refill dialog (Refill, Not Now, not
# enough money), the toasts, and Light.
# Usage: ruby   Tools/Tests/pokevial_preview.rb "<KIF Beta>" <work dir with metrics.json>
#        python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>
TEST = File.join(ARGV[0], "Mods/KantoReloaded/Tools/Tests/overworld_menu_preview.rb")
eval(File.read(TEST, :encoding => "UTF-8").split("#---------------------------------------------------------------- A: ")[0], binding, TEST)

PV = Reloaded::PokeVial
PVS = Reloaded::PokeVialScreen
# the Overworld Menu's preview leaves the PokeVial out; here it's the point
PV.send(:register_menu_entries)
OM.forget_layout
FileUtils.rm_f(LAYOUT)

#---------------------------------------------------------------- the party, hurt
class PkPM
  def fainted?; @hp <= 0; end
  def heal_HP; @hp = @totalhp unless egg?; end
  def heal; return if egg?; heal_HP; @status = nil; end
end
class TrainerOM; attr_accessor :badge_count; end
$Trainer.badge_count = 4
$Trainer.money = 12_450
def hurt_party
  [PkPM.new("Pikachu", :PIKACHU, 34, 78, 95, [:ELECTRIC]),
   PkPM.new("Pidgeot", :PIDGEOT, 36, 120, 120, [:NORMAL, :FLYING], [:FLY]),
   PkPM.new("Gyarados", :GYARADOS, 35, 0, 110, [:WATER, :FLYING], [:SURF]),
   PkPM.new("Eevee", :EEVEE, 22, 40, 60, [:NORMAL]).tap { |p| p.status = :POISON }]
end
$Trainer.party = hurt_party
Reloaded::SaveStore.__send__(:from_save, nil)
Reloaded::Events.emit(:save_loaded, {})
def set(id, v); S.set(PV.key(id), v); end
set(:progressive, false)
set(:max_uses, 4)
PV.set_uses(2)
PV.data["max_seen"] = 4

def pv_sprite; PVS.sprite; end
def pv_says?(word); pv_sprite && drawn_on?(pv_sprite.bitmap, word); end
def to_row(name); at { om.instance_variable_set(:@sel, row_names.index(name)); om.refresh }; end

check("the PokeVial is on the Overworld Menu's Main page (#{OM.pages[0]["entries"].inspect})", OM.pages[0]["entries"].include?("pokevial"))

#---------------------------------------------------------------- A: the row, the dialog
on_map("A dialog", [
  at { check("its row: the charges as Poké Balls, nothing in words (#{row_names.inspect})", row_names.include?("PokeVial") && !left_says?("2/4")) },
  at { check("a fainted Pokémon: the row glows (the Low HP Reminder)", PV.low_hp_alert? && !iv(om, :@alert_sprite).nil? &&
                                                                      iv(om, :@alert_sprite).bitmap.ops.length > 4) },
  dmp("pv_01_row_glow"),
  to_row("PokeVial"),
  at { check("...not while the cursor's on it", iv(om, :@alert_sprite).bitmap.ops.reject { |o| o[0] == "clear" }.empty?) },
  I::USE,
  dmp("pv_02_dialog"),
  at { check("A: the dialog, its Heal Preview: what a charge does for each (+17 HP, Healthy, Revived, +20 HP and Poison cured)",
             pv_says?("PokeVial") && pv_says?("HEAL PREVIEW") && pv_says?("+17 HP") && pv_says?("Healthy") && pv_says?("Revived") &&
             pv_says?("+20 HP, Cures") && pv_says?("Use PokeVial") && pv_says?("Back")) },
  at { check("...each Pokémon's icon beside it (#{PVS.icons.length})", PVS.icons.length == 4 && PVS.icons.all? { |s| s && s.visible }) },
  I::USE,
  dmp("pv_03_used"),
  at { check("Use: the party healed, a charge fewer (#{PV.uses}), Use dimmed All Healthy, Done",
             PV.uses == 1 && $Trainer.party.all? { |p| p.hp == p.totalhp } && pv_says?("All Healthy") && pv_says?("Done")) },
  at { check("...Healed by the ones it healed, Healthy by the one that already was", pv_says?("Healed") && pv_says?("Healthy")) },
  I::USE,
  at { check("...A on Done closes it, back in the menu", pv_sprite.nil? && !om.nil?) },
  at { check("...the glow's gone with the party healed", !PV.low_hp_alert?) },
  I::BACK
])

#---------------------------------------------------------------- B: can't use it
$Trainer.party = hurt_party
set(:cooldown, true)
PV.set_uses(2)
PV.data["last_use"] = Time.now.to_f - 108          # 3:12 of 5:00 left
on_map("B cooldown", [
  to_row("PokeVial"), I::USE,
  dmp("pv_04_cooldown"),
  at { check("cooling down: Use dimmed, counting down (Ready in 3:1x)", pv_says?("Ready in 3:1") && PV.use_state[1] == :cooldown) },
  I::LEFT,
  at { check("...the cursor can't go to it", true) },
  I::USE,
  at { check("...A on Back closes it, nothing used (#{PV.uses})", pv_sprite.nil? && PV.uses == 2) },
  I::BACK
])
set(:cooldown_wait, 1)
on_map("B cooldown toast", [
  to_row("PokeVial"), I::USE,
  at { check("Cooldown Wait Toast: no dialog, a toast with the time left", pv_sprite.nil? && !Reloaded::Toast.sprite.nil?) },
  dmp("pv_05_cooldown_toast"),
  at { Reloaded::Toast.dispose },
  I::BACK
])
set(:cooldown_wait, 0)
set(:cooldown, false)
PV.data["last_use"] = nil
PV.set_uses(0)
on_map("B empty", [
  to_row("PokeVial"), I::USE,
  dmp("pv_06_empty"),
  at { check("no charges: Use dimmed, No Charges Left", pv_says?("No Charges Left")) },
  I::BACK,
  at { check("...B closes it", pv_sprite.nil?) },
  I::BACK
])

#---------------------------------------------------------------- C: the refill dialog
set(:refill_cost, true)
PV.set_uses(1)
Input.queue = [dmp("pv_07_refill"),
               at { check("Refill PokeVial?: 3 charges missing, ₽500 each, the money you have",
                          pv_says?("Refill PokeVial?") && pv_says?("3 Charges Missing") && pv_says?("$500 Each: $1,500 (you have $12,450)")) },
               I::USE]
check("...Refill: yes (#{(r = PVS.ask_refill).inspect})", r == true)
Input.queue = [I::RIGHT, I::USE]
check("...Not Now: no", PVS.ask_refill == false)
$Trainer.money = 300
Input.queue = [dmp("pv_08_refill_poor"),
               at { check("not enough money: Refill dimmed, the money in red, the cursor on Not Now", pv_says?("you have $300")) },
               I::LEFT, I::USE]
check("...Left can't reach Refill: A says Not Now", PVS.ask_refill == false)
$Trainer.money = 12_450
set(:refill_cost, false)

#---------------------------------------------------------------- D: toasts
PV.set_uses(3)
PVS.charges_toast("The PokeVial regained a charge.")
on_map("D charge toast", [dmp("pv_09_toast_charge"), at { check("an item's toast: the charges as Poké Balls in a pill, over the menu",
                                                                 !Reloaded::Toast.sprite.nil? && Reloaded::Toast.sprite.viewport.z > iv(om, :@viewport).z) }, I::BACK])
Reloaded::Toast.dispose
PVS.toast("The PokeVial is already full.", :full => true)
on_map("D full toast", [dmp("pv_10_toast_full"), I::BACK])
Reloaded::Toast.dispose
PVS.capacity_toast(4, 1)
on_map("D capacity toast", [dmp("pv_11_toast_capacity"), I::BACK])
Reloaded::Toast.dispose
Reloaded::Toast.show("Fades", :pill => ["1", :gold])
Reloaded::Toast::FRAMES.times { $scene.miniupdate if $scene.respond_to?(:miniupdate); Reloaded::Toast.update unless $scene.respond_to?(:miniupdate) }
check("a toast fades while a menu is open too (the map's miniupdate)", Reloaded::Toast.sprite.nil?)

#---------------------------------------------------------------- E: Light
S.set(Reloaded::Palette::MODE, 2)
$Trainer.party = hurt_party
PV.set_uses(2)
on_map("E light", [
  dmp("pv_12_light_row"),
  to_row("PokeVial"), I::USE,
  dmp("pv_13_light_dialog"),
  at { check("Light: the dialog in the Light colours", Reloaded::Palette.map_menu[:light] == true) },
  I::BACK, I::BACK
])
set(:refill_cost, true)
Input.queue = [dmp("pv_14_light_refill"), I::RIGHT, I::USE]
PVS.ask_refill
S.set(Reloaded::Palette::MODE, 0)

errors = File.read(Reloaded::Log.path).lines.grep(/ERROR|skipped/)
check("no errors or skipped hooks in Kanto Reloaded's log (#{errors.length})", errors.empty?)
errors.first(6).each { |l| puts "  " + l }
puts $failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED"
exit($failed ? 1 : 0)
