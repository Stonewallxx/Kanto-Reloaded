# encoding: utf-8
# Offline preview of Speed-Up's screens on the preview tool's stand-ins
# (Tools/UIPreview/preview.rb): the Controls screen's Speed-Up section (Hold,
# then Toggle: the other type's rows locked, a setting stepped with Left and
# Right, the Default button, a dropdown, the Buttons heading and a button's
# editor), Global without the speed buttons, Search, Reset Section, the
# settings in KIF Settings (the other type's rows dimmed with a padlock, and
# kept as they are), and the corner Speed Indicator (Dark and Light).
# Usage: ruby   Tools/Tests/speed_up_preview.rb "<KIF Beta>" <work dir with metrics.json>
#        python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>
PREVIEW_SETUP_ONLY = true
load File.join(ARGV[0], "Mods/KantoReloaded/Tools/UIPreview/preview.rb")
SU = Reloaded::SpeedUp
SI = Reloaded::SpeedUpIndicator
CT = Reloaded::Controls

check("Speed-Up is on, with its hooks (#{Reloaded::Features.on?(:speed_up)})", Reloaded::Features.on?(:speed_up))

def cs; $screen; end
# The highlighted row's name: a setting's or an action's
def cs_row
  it = cs.send(:current_item)
  return nil unless it
  return it[0] == :set ? S.definition(it[1])[:name] : it[1].name
end
def cs_items; cs.send(:items); end
# Down to the row named, counted when it runs
def cs_to(name)
  at {
    list = cs.send(:selectable)
    k = list.index { |kind, what| (kind == :set ? S.definition(what)[:name] : what.name) == name }
    raise "no row #{name}" unless k
    n = k - cs.instance_variable_get(:@sel).to_i % list.length
    Input.queue.unshift(*(n >= 0 ? [I::DOWN] * n : [I::UP] * -n))
  }
end
# what the pixel fonts drew, per bitmap (as the Overworld Menu's preview keeps it)
$pf_texts = Hash.new { |h, k| h[k] = [] }
$pf_colours = Hash.new { |h, k| h[k] = [] }     # [text, colour] drawn, per bitmap
Reloaded::Pixel.singleton_class.prepend(Module.new {
  def text(b, x, y, w, h, str, *r)
    $pf_texts[b.id] << str.to_s
    $pf_colours[b.id] << [str.to_s, r[0]] if r[0].is_a?(Color)
    super
  end
})
# Drawn on the screen's top layer in its own palette's dim colour
def drawn_dim?(w)
  d = scr.send(:palette)[:dim]
  $pf_colours[scr.instance_variable_get(:@top_sprite).bitmap.id].any? do |t, col|
    t.include?(w) && [col.red, col.green, col.blue] == [d.red, d.green, d.blue]
  end
end
Bitmap.prepend(Module.new { def clear(*a); $pf_texts.delete(id); $pf_colours.delete(id); super; end })
def drawn_on?(b, w); $pf_texts[b.id].any? { |s| s.include?(w) } || b.ops.any? { |o| o[0] == "text" && o[5].to_s.include?(w) }; end
def says?(w)
  [cs.instance_variable_get(:@top_sprite), cs.instance_variable_get(:@sprite)].any? { |sp| sp && drawn_on?(sp.bitmap, w) }
end

def drive_cs(label, queue)
  Input.queue = queue.dup
  Reloaded::ControlsScreen.open
  check("#{label}: opened and closed", true)
rescue QueueEmpty => e
  check("#{label}: #{e.message}", false)
rescue Exception => e
  check("#{label}: #{e.class}: #{e.message} #{e.backtrace.first(4).inspect}", false)
end

#---------------------------------------------------------------- A: the Speed-Up section, Hold
drive_cs("A hold", [
  at { names = Reloaded::ControlsScreen::SECTIONS.map { |id, *| id }
       check("the sidebar: Speed-Up between Battle and Feel (#{names.inspect})", names[-2..-1] == [:speed_up, :feel]) },
  at { g = cs.send(:items_for, :global).select { |k, _| k == :row }.map { |_, a| a.id }
       check("Global no longer lists the speed buttons (#{(g & [:speed_up, :next_speed, :reset_speed]).inspect})",
             (g & [:speed_up, :next_speed, :reset_speed]).empty?) },
  I::UP, I::UP,
  at { check("Up from Global goes round to Feel, then Speed-Up (#{cs.send(:section_id)})", cs.send(:section_id) == :speed_up) },
  dmp("su_01_section"),
  I::RIGHT,
  at { kinds = cs_items.map(&:first)
       check("its list: Game Speed's 11 settings, then the Buttons heading and its 3 actions (#{kinds.inspect})",
             kinds == [:head] + [:set] * 11 + [:cols] + [:row] * 3 && cs_items[0][1] == "Game Speed" && cs_items[12][1] == "Buttons") },
  at { check("...on Speed-Up Type, Hold (#{cs_row})", cs_row == "Speed-Up Type" && SU.setting(:type) == 0) },
  dmp("su_02_hold"),
  I::DOWN, I::RIGHT,
  at { check("Right steps Speed-Up (Overworld) to 5x (#{S.display(:"speed_up.overworld")})", S.display(:"speed_up.overworld") == "5x") },
  at { check("...kept in PIF's field ($PokemonSystem #{$PokemonSystem.speedup_speed.inspect})", $PokemonSystem.speedup_speed == 4) },
  I::ACTION,
  at { check("the Default button: 4x again", S.display(:"speed_up.overworld") == "4x") },
  cs_to("Toggle Limit"),
  I::RIGHT,
  at { check("Toggle Limit is locked in Hold: Right does nothing (#{S.display(:"speed_up.toggle_limit")})", S.display(:"speed_up.toggle_limit") == "5x") },
  I::USE,
  at { check("...nor A (no dropdown)", cs.instance_variable_get(:@dropdown).nil?) },
  dmp("su_03_locked"),
  at { check("...dimmed with a padlock, and its description says why", says?("Locked: Toggle Only.")) },
  cs_to("Shiny Slowdown"),
  dmp("su_04_shiny"),
  cs_to("Speed-Up"),
  at { check("down to the Buttons: Speed-Up, an action (#{cs_row})", cs_row == "Speed-Up" && cs.send(:current).id == :speed_up) },
  dmp("su_05_buttons"),
  at { check("...under the Buttons heading with Keyboard and Controller", says?("KEYBOARD") && says?("CONTROLLER") && says?("BUTTONS")) },
  I::USE,
  dmp("su_06_editor"),
  at { check("A opens its editor", cs.overlay.ops.length > 1) },
  I::BACK,
  I::BACK, I::BACK
])

#---------------------------------------------------------------- B: Toggle
drive_cs("B toggle", [
  I::UP, I::UP, I::RIGHT,
  I::RIGHT,
  at { check("Right on Speed-Up Type: Toggle, in PIF's field too (#{$PokemonSystem.speedup.inspect})", SU.toggle? && $PokemonSystem.speedup == 1) },
  dmp("su_07_toggle"),
  at { check("Hold's rows locked, Toggle's open", S.locked?(:"speed_up.overworld") && !S.locked?(:"speed_up.burst")) },
  cs_to("Burst Speed"),
  dmp("su_08_burst"),
  I::USE,
  dmp("su_09_dropdown"),
  at { dd = cs.instance_variable_get(:@dropdown)
       check("A: a dropdown of Off, 2x to 10x, on 10x (#{dd && dd.values.length})", dd && dd.values.length == 10 && dd.values[0] == "Off" && dd.index == 9) },
  I::UP, I::USE,
  at { check("...picked: 9x (#{S.display(:"speed_up.burst")})", S.display(:"speed_up.burst") == "9x") },
  at { cs.send(:reset_section); cs.send(:refresh) },
  at { check("Reset Section: Hold again, Burst Speed 10x, the other type's rows too", !SU.toggle? && S.display(:"speed_up.burst") == "10x") },
  I::BACK, I::BACK
])

#---------------------------------------------------------------- C: Search
drive_cs("C search", [
  I::JUMPUP, "Speed", :RETURN,
  at { names = cs.send(:selectable).map { |_k, a| a.name }
       check("Search finds the speed buttons under Global > Game Speed (#{names.inspect})",
             names == ["Speed-Up", "Next Speed", "Reset Speed"] && cs_items[0][1] == "Global > Game Speed") },
  dmp("su_10_search"),
  I::BACK, I::BACK
])

#---------------------------------------------------------------- D: KIF Settings
drive("D KIF Settings", [
  at { labels = scr.send(:rows).map(&:label)
       check("Kanto Reloaded's section has Speed-Up's page and rows (#{(labels & ["Speed-Up Type", "Burst Speed", "Messages at 1x"]).inspect})",
             (labels & ["Speed-Up Type", "Burst Speed", "Messages at 1x", "Speed Indicator"]).length == 4) },
  at { labels = scr.send(:rows).map(&:label)
       check("...not the speeds Remember Speed keeps", (labels & ["saved_overworld", "saved_battles"]).empty?) },
  I::RIGHT, down_to("Toggle Limit"),
  at { check("on Toggle Limit, Hold: locked (#{scr.send(:kr_lock, scr.current.opt).inspect})", scr.send(:kr_lock, scr.current.opt) == "Toggle Only") },
  I::RIGHT, I::USE, I::ACTION,
  at { check("...Right, A and the Default button change nothing (#{S.display(:"speed_up.toggle_limit")})",
             S.display(:"speed_up.toggle_limit") == "5x" && scr.instance_variable_get(:@dropdown).nil?) },
  dmp("su_15_kif_settings_locked"),
  at { check("...its name drawn in the dim colour", drawn_dim?("Toggle Limit")) },
  at { check("...and its description says why", scr.instance_variable_get(:@top_sprite) && $pf_texts.values.flatten.any? { |t| t.include?("Locked: Toggle Only.") } ||
             scr.current.opt.description.include?("Locked: Toggle Only.")) },
  I::UP, I::UP, I::UP,
  at { check("up to Speed-Up (Overworld) (#{row_name})", row_name == "Speed-Up (Overworld)") },
  I::RIGHT,
  at { check("an open row still changes: Speed-Up (Overworld) 5x (#{S.display(:"speed_up.overworld")})", S.display(:"speed_up.overworld") == "5x") },
  I::LEFT,
  I::BACK, I::BACK
])

#---------------------------------------------------------------- E: the Speed Indicator
def indicator_shot(name, mode, speed)
  S.set(:"interface.theme_mode", mode)
  SI.hide
  SI.show(speed)
  dump(name)
end
indicator_shot("su_11_indicator", 0, 4)
sp = SI.sprite
check("a speed change shows it in the top-right corner (#{sp && [sp.x, sp.y, sp.bitmap.width]})",
      sp && sp.x + sp.bitmap.width == 512 - 8 && sp.y == 8)
check("...smaller than Design 1's 74 pixels (#{sp && sp.bitmap.width})", sp && sp.bitmap.width < 74)
check("...over menus, under popups (z #{sp && sp.viewport.z})", sp && sp.viewport.z == 100_300)
indicator_shot("su_12_indicator_x1", 0, 1)
indicator_shot("su_13_indicator_light", 2, 4)
indicator_shot("su_14_indicator_light_x1", 2, 1)
S.set(:"interface.theme_mode", 0)
def pill_says?(w); SI.sprite && drawn_on?(SI.sprite.bitmap, w); end
SI.hide
S.set(:"speed_up.type", 1)
SU.set_toggled(4, :overworld)
SU.instance_variable_set(:@last_shown, nil)
Graphics.update
check("the first speed seen shows nothing (the game starting at a remembered speed)", SI.sprite.nil?)
S.set(:"speed_up.indicator", false)
SI.show(3)
check("Speed Indicator Off: nothing shows", SI.sprite.nil?)
S.set(:"speed_up.indicator", true)
SU.set_toggled(3, :overworld)
Graphics.update
check("through the game's frame: a new toggled speed shows, X3 (#{SU.instance_variable_get(:@last_shown)})", pill_says?("X3"))
SI.instance_variable_set(:@until, 0.0)
Graphics.update
check("...and goes once its time is up", SI.sprite.nil?)
SU.paused do
  Graphics.update
  check("opening a settings screen shows nothing new (#{SU.speed})", SI.sprite.nil? && SU.speed == 2)
  SU.set_toggled(4, :overworld)
  Graphics.update
  check("in a settings screen: a new speed shows as the 2x it runs at there, not X4", pill_says?("X2") && !pill_says?("X4"))
  dump("su_16_indicator_settings")
end
Graphics.update
check("...closed: the box still showing says X4 now, without a new one", pill_says?("X4"))
SI.hide
# Hold: a quick press (X for Summary in a menu) doesn't show it; held for
# Hold Time it does, and letting go shows 1x again
S.set(:"speed_up.type", 0)
$now = 50.0
SU.singleton_class.send(:define_method, :clock) { $now }
SU.instance_variable_set(:@last_shown, nil)
Graphics.update
def hold(on); SU.instance_variable_set(:@holding, on); SU.instance_variable_set(:@held_since, on ? (SU.instance_variable_get(:@held_since) || $now) : nil); Graphics.update; end
hold(true); $now += 0.1; hold(true); hold(false)
check("Hold: a quick press shows nothing (#{SI.sprite.inspect})", SI.sprite.nil?)
hold(true); $now += 0.6; hold(true)
check("...held past Hold Time: X4", pill_says?("X4"))
hold(false)
check("...let go: X1", pill_says?("X1"))
SI.hide
S.set(:"speed_up.type", 0)
S.set(:"interface.theme_mode", 0)

errors = File.read(Reloaded::Log.path).lines.grep(/ERROR|skipped/)
check("no errors or skipped hooks in Kanto Reloaded's log (#{errors.length})", errors.empty?)
errors.first(6).each { |l| puts "  " + l }
puts $failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED"
exit($failed ? 1 : 0)
