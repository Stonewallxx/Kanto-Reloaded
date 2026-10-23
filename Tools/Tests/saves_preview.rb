# encoding: utf-8
# Offline preview of the Save Manager, the Load Screen and What's New on the
# preview tool's stand-ins (Tools/UIPreview/preview.rb), with real save files
# (written as PIF writes them, stand-in players), driven with button
# presses, typing and holds.
# Usage: ruby   Tools/Tests/saves_preview.rb "<KIF Beta>" <work dir with metrics.json>
#        python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>
PREVIEW_SETUP_ONLY = true
load File.join(ARGV[0], "Mods/KantoReloaded/Tools/UIPreview/preview.rb")
require "fileutils"
SV = Reloaded::Saves
KIF.const_set(:PORT_VERSION, "0.21.57") unless defined?(KIF::PORT_VERSION)
check("the save screens load in the preview",
      defined?(Reloaded::SaveManagerScreen) && defined?(Reloaded::LoadScreen::View) && defined?(Reloaded::WhatsNewScreen))

#---------------------------------------------------------------- saves like the design's
SAVES = File.join(USERDIR, "saves")
FileUtils.mkdir_p(SAVES)
module SaveData
  SAVE_DIR = SAVES
  MANUAL_SLOTS = ("A".."H").map { |l| "File #{l}" }
  AUTO_SLOTS = ["Auto 1", "Auto 2"]
  def self.get_full_path(slot); File.join(SAVE_DIR, "#{slot}.rxdata"); end
  def self.get_data_from_file(path); File.open(path, "rb") { |f| Marshal.load(f) }; end
end
Dex = Struct.new(:owned_count, :seen_count)
Player = Struct.new(:name, :money, :badge_count, :pokedex, :last_time_saved, :selected_difficulty, :id, :party, :girl, :save_slot) do
  def female?; girl; end
  def male?; !girl; end
end
MapStub = Struct.new(:map_id)
Factory = Struct.new(:map)
# The game's icons from its own files: PIF's small ones (64 px frames), or
# KIF Beta's Big Pokémon Icons (the battle sprite, 96 px frames).
PkStub = Struct.new(:species, :dex)
DEX = { :BULBASAUR => 1, :CHARMANDER => 4, :PIKACHU => 25, :CLEFAIRY => 35, :ONIX => 95, :GYARADOS => 130 }.freeze
def pk(*names); names.map { |n| PkStub.new(n, DEX[n]) }; end
$big_icons = false
class PokemonIconSprite < Sprite
  attr_accessor :kif_big_offset
  def initialize(pkmn, vp = nil)
    super(vp)
    if $big_icons
      self.bitmap = Bitmap.new("Graphics/CustomBattlers/spritesheets/spritesheets_base/#{pkmn.dex}.png")
      self.src_rect = Rect.new(0, 0, 96, 96)
    else
      self.bitmap = Bitmap.new("Graphics/Pokemon/Icons/#{pkmn.species}.png")
      self.src_rect = Rect.new(0, 0, 64, 64)
    end
  end
  def update; end
end
def generate_front_trainer_sprite_bitmap(*_a)
  Bitmap.new("Graphics/Characters/player/base/trainer/trainer_default.png")
end
def pbGetMapNameFromId(id); { 5 => "Cerulean City", 7 => "Route 4", 9 => "Mt. Moon", 3 => "Pewter City", 2 => "Viridian Forest" }[id] || "Map #{id}"; end
def write_save(slot, name, map_id, hours, at, remix: false, money: 12_450, badges: 2, girl: false, party: [])
  data = { :player => Player.new(name, money, badges, Dex.new(41, 87), at, 1, slot.sum, party, girl, slot),
           :frame_count => 40 * (hours * 3600 + 12 * 60), :map_factory => Factory.new(MapStub.new(map_id)),
           :switches => remix ? { 974 => true } : {}, :game_version => "6.8.2" }
  File.open(SaveData.get_full_path(slot), "wb") { |f| Marshal.dump(data, f) }
  data
end
now = Time.now
write_save("File A", "Red", 5, 41, now - 600, :party => pk(:CHARMANDER, :CLEFAIRY))
write_save("File B", "Leaf", 3, 12, now - 86_400 * 2, :remix => true, :girl => true,
           :party => pk(:BULBASAUR, :PIKACHU, :ONIX, :GYARADOS, :CHARMANDER, :CLEFAIRY))
write_save("File C", "Ethan", 9, 6, now - 86_400 * 5)
File.binwrite(SaveData.get_full_path("File D"), "not a save")
dir = File.join(SAVES, "backups", "File A")
FileUtils.mkdir_p(dir)
[[0, 5, "_Before Misty"], [32, 7, ""], [44, 9, ""], [71, 9, "_autosave"], [115, 9, "_Got Pikachu"], [60 * 24 + 30, 3, ""], [60 * 72, 2, ""]].each do |mins, map, tail|
  t = now - mins * 60 - 600
  write_save("File A", "Red", map, 41, t)
  File.rename(SaveData.get_full_path("File A"), File.join(dir, "File A_#{t.strftime("%Y%m%d%H%M%S")}#{tail}.rxdata"))
end
write_save("File A", "Red", 5, 41, now - 600, :party => pk(:CHARMANDER, :CLEFAIRY))
SV.set_note("File A", "Main run. Misty next; I need a Grass type before the gym.")
SV.set_tag("File A", "Red")
SV.set_note("File B", "Nuzlocke: dupes clause, no items in battle.")
SV.set_tag("File B", "Green")
SV.set_note("File C", "Shiny hunting Abra on Route 24.")
SV.set_tag("File C", "Blue")

def ss; $ss; end
Reloaded::SaveManagerScreen.prepend(Module.new { def main; $ss = self; super; end })
def drive_screen(label, queue)
  Input.queue = queue.dup
  result = yield
  check("#{label}: opened and closed", true)
  result
rescue QueueEmpty => e
  check("#{label}: #{e.message}", false)
rescue Exception => e
  check("#{label}: #{e.class}: #{e.message} #{e.backtrace.first(4).inspect}", false)
end
def sm_tab; ss.send(:tab); end
def sm_cur; ss.send(:current); end
def sm_hints; ss.send(:hint_pairs).map { |p| p[1] }; end
def drawn?(b, word); b.ops.any? { |o| o[0] == "text" && o[5].to_s.include?(word) } || $pf_texts[b.id].any? { |s| s.include?(word) }; end
$pf_texts = Hash.new { |h, k| h[k] = [] }
$pf_colours = Hash.new { |h, k| h[k] = [] }
Reloaded::Pixel.singleton_class.prepend(Module.new { def text(b, x, y, w, h, str, *r); $pf_texts[b.id] << str.to_s; $pf_colours[b.id] << [str.to_s, r[0]]; super; end })
Bitmap.prepend(Module.new { def clear(*a); $pf_texts.delete(id); $pf_colours.delete(id); super; end })
def top_text?(word); drawn?(ss.instance_variable_get(:@top_sprite).bitmap, word); end

#---------------------------------------------------------------- the Save Manager
def icons_of(screen); screen.instance_variable_get(:@icons); end
def overlay_z(screen); screen.instance_variable_get(:@overlay_sprite).z; end
SMS = Reloaded::SaveManagerScreen
drive_screen("save manager", [
  *[nil] * 9,
  dmp("sm_01_active"),
  at { xs = icons_of(ss).map(&:x)
       check("File A's party: a row centred under the details, kept under the popups (x #{xs.inspect})",
             xs.length == 2 && (xs.sum / 2.0 - (SMS::RIGHT_X0 + SMS::RIGHT_X1) / 2.0).abs <= 1 &&
             icons_of(ss).all? { |s| s.z < overlay_z(ss) && s.kif_big_offset == false }) },
  at { check("Active: the saves, File A first, healthy; File D damaged (#{ss.instance_variable_get(:@saves).map { |s| [s[:slot], s[:pv][:health]] }.inspect})",
             ss.instance_variable_get(:@saves).map { |s| s[:pv][:health] } == [:healthy, :healthy, :healthy, :damaged]) },
  at { check("the hints: Choose, Options, Note, Tabs, Close (#{sm_hints.inspect})", sm_hints == ["Choose", "Options", "Note", "Tabs", "Close"]) },
  at { check("File A's details: trainer, location, play time, its note", top_text?("Cerulean City") && top_text?("41:12") && top_text?("Healthy")) },
  I::DOWN, I::DOWN, I::DOWN,
  dmp("sm_02_damaged"),
  at { check("File D: Damaged, and why (#{ss.send(:save_banner, sm_cur)[0]})", ss.send(:save_banner, sm_cur)[0].start_with?("Damaged")) },
  I::UP, I::UP, I::UP,
  I::X, " Shiny Pikachu!", :RETURN,
  at { check("Y: typing the note in place (#{SV.note("File A")[-15..-1].inspect})", SV.note("File A").end_with?("Shiny Pikachu!")) },
  I::JUMPDOWN,
  dmp("sm_03_backups"),
  at { check("LB / RB: Backups, File A's, newest first, named ones in gold (#{ss.send(:backups).map { |b| b[:name] }.inspect})",
             sm_tab == :backups && ss.send(:backups).first[:name] == "Before Misty" && ss.send(:backups).length == 7) },
  *[nil] * 8,
  at { check("each backup's location fills in (#{ss.send(:backups).map { |b| b[:pv] && b[:pv][:map] }.inspect})",
             ss.send(:backups).all? { |b| b[:pv] && b[:pv][:map] }) },
  I::DOWN,
  dmp("sm_04_backup"),
  I::X, "Before Brock", :RETURN,
  at { check("Y: naming a backup", ss.send(:backups).any? { |b| b[:name] == "Before Brock" }) },
  I::USE,
  dmp("sm_05_restore_confirm"),
  I::USE,
  at { check("A asks before restoring; Cancel keeps the save", SV.backups("File A").none? { |b| b[:name] == "Before Restore" }) },
  I::JUMPDOWN,
  dmp("sm_06_deleted_empty"),
  I::JUMPUP, I::JUMPUP,
  I::DOWN, I::DOWN, I::USE,
  dmp("sm_07_options"),
  I::DOWN, I::DOWN, I::DOWN, I::DOWN, I::DOWN, I::USE,
  I::LEFT, I::USE,
  at { check("Options > Delete: File C goes to the Deleted tab", !File.file?(SaveData.get_full_path("File C")) && SV.archived.length == 1) },
  I::JUMPUP,
  dmp("sm_08_deleted"),
  at { check("the Deleted tab: File C, and where it would go back (#{sm_cur && sm_cur[:slot]})", sm_tab == :deleted && sm_cur[:slot] == "File C") },
  I::USE, I::USE,
  at { check("Restore: File C is back", File.file?(SaveData.get_full_path("File C")) && SV.archived.empty?) },
  I::USE,
  I::BACK
]) { Reloaded::SaveManagerScreen.open }

$big_icons = true
drive_screen("save manager, big icons", [
  I::DOWN, *[nil] * 9,
  dmp("sm_09_big_icons"),
  at { ic = icons_of(ss)
       check("big icons: File B's six in one row inside the panel, scaled to the small ones' size (x #{ic.map(&:x).inspect})",
             ic.length == 6 && ic.first.x - 24 >= SMS::RIGHT_X0 && ic.last.x + 24 <= SMS::RIGHT_X1 &&
             ic.all? { |s| s.oy == 48 && (s.zoom_x * 96 - 64).abs < 0.01 }) },
  I::BACK
]) { Reloaded::SaveManagerScreen.open }
$big_icons = false

#---------------------------------------------------------------- What's New
Reloaded::WhatsNew.add("Hard Trainers+", "2.0", ["Gym leaders: Harder teams", "Rematches with every leader"], "2026-10-19")
def wn; $wn; end
Reloaded::WhatsNewScreen.prepend(Module.new { def main; $wn = self; super; end })
drive_screen("what's new", [
  dmp("wn_01_kr"),
  at { check("What's New: Kanto Reloaded first, its version NEW (#{wn.send(:version).version})",
             wn.send(:source)[:name] == "Kanto Reloaded" && wn.instance_variable_get(:@fresh)[["Kanto Reloaded", Reloaded.version]]) },
  I::RIGHT,
  dmp("wn_02_kif"),
  at { check("Right: KIF's notes", wn.send(:source)[:name] == "KIF") },
  I::RIGHT,
  dmp("wn_03_mod"),
  I::USE, I::DOWN,
  I::BACK, I::BACK
]) { Reloaded::WhatsNewScreen.open }
check("closing it marks every version read", !Reloaded::WhatsNew.unseen?)

#---------------------------------------------------------------- the Load Screen
module RPG                                        # PIF's own (light) background
  module Cache
    def self.picture(name); Bitmap.new("Graphics/Pictures/#{name}"); end
  end
end
COMMANDS = ["File A", "Mystery Gift", "New Game", "Options", "KIF Discord", "KIF Documentation", "What's New", "Save Manager",
            "Savefile management", "Quit Game"].freeze
def load_view(slot = "File A")
  data = SaveData.get_data_from_file(SaveData.get_full_path(slot)) rescue nil
  p = data ? data[:player] : nil
  cmds = COMMANDS.dup
  cmds[0] = slot
  v = Reloaded::LoadScreen::View.new(cmds, true, p, data ? data[:frame_count] : 0, data ? data[:map_factory].map.map_id : 0)
  v.open
  v.party = p if p
  $lv = v
  [v, cmds]
end
def lv; $lv; end
def drawn_in?(screen, word, colour)
  $pf_colours[screen.instance_variable_get(:@top_sprite).bitmap.id].any? { |str, c| str.include?(word) && c && c.to_a == colour.to_a }
end
LV = Reloaded::LoadScreen::View
def lv_order; lv.instance_variable_get(:@order).map { |i| COMMANDS[i] }; end
File.delete(File.join(Reloaded::Paths.settings_dir, "Whats New.json"))
Reloaded::WhatsNew.reset
result = drive_screen("load screen", [
  dmp("lw_01_continue"),
  at { check("the rows in the design's order, Savefile management left out (#{lv_order.inspect})",
             lv_order == ["File A", "New Game", "What's New", "Mystery Gift", "Options", "Save Manager", "KIF Discord", "KIF Documentation", "Quit Game"]) },
  at { check("What's New is NEW again (reset)", lv.instance_variable_get(:@new)) },
  at { check("the Save Manager's colours: Normal blue, time gold, money green",
             lv.send(:difficulty_colour) == lv.palette[:blue] && drawn_in?(lv, "41h 12m", lv.palette[:gold]) &&
             drawn_in?(lv, "12,450", lv.palette[:green])) },
  *[I::DOWN] * 6,
  dmp("lw_02_scrolled"),
  at { check("a lower row scrolls the list (#{lv.instance_variable_get(:@scroll)})", lv.instance_variable_get(:@scroll) > 0) },
  I::BACK,
  at { check("B: back to Continue", lv.instance_variable_get(:@sel) == 0 && lv.instance_variable_get(:@scroll) == 0) },
  at { tr = lv.instance_variable_get(:@trainer_sprite)
       check("the trainer stands left of the details (art #{tr.x - 30}..#{tr.x + 30}, details from #{LV::INFO_X}), "              "the party under them, both under the popups",
             tr.x + 30 < LV::INFO_X && lv.instance_variable_get(:@icons).all? { |s| s.x - 24 >= LV::INFO_X && s.z < overlay_z(lv) } &&
             tr.z < overlay_z(lv)) },
  I::USE, *[[:held, I::USE]] * 20,
  dmp("lw_03_backups"),
  I::BACK,
  I::X, nil, "Before Misty", dmp("lw_06_note_typing"), :ESCAPE,
  I::RIGHT
]) { v, cmds = load_view; v.choose(cmds, 0) }
check("Right on Continue: the next save file (#{result.inspect}, as PIF's -2)", result == -2)
check("What's New is still NEW before it's read", lv.instance_variable_get(:@new))
Input.queue = [I::BACK]
Reloaded::WhatsNewScreen.open                    # the What's New row, read and closed
drive_screen("back from What's New", [at { check("back on the menu, the NEW badge is gone", !lv.instance_variable_get(:@new)) }, I::RIGHT]) do
  lv.choose(COMMANDS.dup, 0)
end
lv.close(false)
$big_icons = true
drive_screen("load screen, big icons", [dmp("lw_07_big_icons"), I::RIGHT]) { v, cmds = load_view("File B"); v.choose(cmds, 0) }
lv.close(false)
$big_icons = false
result = drive_screen("load screen pick", [I::USE, nil]) { v, cmds = load_view; v.choose(cmds, 0) }
check("A, let go: Continue (#{result.inspect})", result == 0)
lv.close(false)
result = drive_screen("damaged save", [dmp("lw_04_damaged"), I::USE, nil, dmp("lw_05_damaged_offer"), I::RIGHT, I::RIGHT, I::USE, I::DOWN, I::USE]) do
  v, cmds = load_view("File D")
  v.choose(cmds, 0)
end
check("a damaged save asks first: Cancel, then the next row (#{result.inspect})", result == 2)
lv.close(false)

#---------------------------------------------------------------- on a phone: Copy Instead
ENV["ANDROID_ROOT"] = "/system"            # what an Android player has
Reloaded::Runtime.reset
Input.clipboard = ""
$shell = []                                # nothing may open File Explorer here
Reloaded::SaveManagerScreen.prepend(Module.new { def system(*a); $shell << a; true; end })
drive_screen("save manager on a phone", [
  I::USE,
  dmp("sm_10_phone_options"),
  *[I::DOWN] * 6, I::USE,
  dmp("sm_11_phone_copied"),
  at { check("on a phone, Options' last entry copies the saves folder's full path (#{Input.clipboard})",
             !Input.clipboard.empty? && File.expand_path(Input.clipboard) == File.expand_path(SV.dir)) },
  I::USE,
  I::BACK
]) { Reloaded::SaveManagerScreen.open }
check("...and nothing tried to open File Explorer", $shell.empty?)
ENV.delete("ANDROID_ROOT")
Reloaded::Runtime.reset

errors = File.read(Reloaded::Log.path).lines.grep(/ERROR/)
check("no errors in the log (#{errors.length})", errors.empty?)
errors.first(6).each { |l| puts "  " + l }
puts $failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED"
exit($failed ? 1 : 0)
