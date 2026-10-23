# encoding: utf-8
# Mockup: the chosen Speed-Up section of the Controls page (topic speed-up,
# Design 1: the other type's rows locked) with the rows agreed on
# 2026-10-23: Burst Speed and Remember Speed (Toggle), Shiny Slowdown,
# Messages at 1x; the Speed Indicator is now the corner toast.
# Hold on the left, Toggle on the right; each scrolled to a new row.
# Built on ../spd_designs.rb (its pieces) and ../controls.rb.
# Usage (cwd = KIF Beta): ruby section_designs.rb "<KIF Beta>" <work dir with metrics.json>
SPD = File.join(File.dirname(File.expand_path(__FILE__)), "..", "spd_designs.rb")
eval(File.read(SPD, :encoding => "UTF-8").split("c = palette(2)")[0], binding, SPD)

def new_items(hold)
  [[:head, "Game Speed"],
   [:row, "Speed-Up Type", hold ? "Hold" : "Toggle", false],
   [:row, "Speed-Up (Overworld)", "4x", !hold],
   [:row, "Speed-Up (Battles)", "4x", !hold],
   [:row, "Resting Speed", "1x", !hold],
   [:row, "Toggle Limit", "5x", hold],
   [:row, "Toggle Speeds", "Separate", hold],
   [:row, "Burst Speed", "10x", hold],
   [:row, "Remember Speed", "On", hold],
   [:row, "Shiny Slowdown", "On", false],
   [:row, "Messages at 1x", "Off", false],
   [:row, "Speed Indicator", "On", false],
   [:head, "Buttons"], [:bind, :speed_up], [:bind, :speed_next], [:bind, :speed_reset]]
end

c = palette(2)
ctl(c); spd_list(c, new_items(true), 8)
description(c, "Shiny Slowdown", ["NEW", "ALL SAVES", "DEFAULT: ON"],
            "When a shiny appears, in a wild battle or on the map, the speed drops to 1x so you don't fly past it.")
hints(c, H_SET); dump("SU_section_hold")
ctl(c); spd_list(c, new_items(false), 6)
description(c, "Burst Speed", ["NEW", "DEFAULT: 10X"],
            "Toggle: Hold the Speed-Up button to run at this speed until you let go; a tap still steps through the speeds.")
hints(c, H_SET); dump("SU_section_toggle")
puts "section done"
