# encoding: utf-8
# Mockups: Go to Settings (his ask, 2026-10-24): a button over a Reloaded
# Systems or Features switch takes you to that one's own settings in the
# Kanto Reloaded section. Drawn on the real improved KIF Settings (the UI
# preview's stand-ins, Tools/UIPreview/preview.rb). Each design: on the
# Features page's Speed-Up row, then after the jump (Speed-Up's heading at
# the top, B goes back to the row you came from).
#   1 SETTINGS Pill     a small pill after the name of each row that has settings
#   2 Hint Only         nothing on the rows; the hint line shows the button
#   3 Button on the Row the button's icon after the highlighted row's name (his pick)
# Usage (from the mod folder): ruby Tools/Designs/settings_jump_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                              python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>
PREVIEW_SETUP_ONLY = true
load File.join(ARGV[0], "Mods/KantoReloaded/Tools/UIPreview/preview.rb")
$VERBOSE = nil
$pad_name = "Xbox Series X Controller"

# Rows with settings of their own: [the row's heading, its name] => the heading it goes to
GOES_TO = {
  ["Reloaded Systems", "Reloaded Controls"] => "Controls",
  ["Reloaded Systems", "Reloaded Load Screen"] => "Saves",
  ["Features", "Overworld Menu"] => "Overworld Menu",
  ["Features", "Quality of Life"] => "Quality of Life",
  ["Features", "PokeVial"] => "PokeVial",
  ["Features", "Speed-Up"] => "Speed-Up",
  ["Features", "Reloaded Bag"] => "Bag"
}.freeze

SS = Reloaded::SettingsScreen
module JumpMock
  def goes_to(r)
    return nil unless r && r.kind == :opt
    return GOES_TO[[r.heading.to_s, r.label.to_s]]
  end

  def paint_list(base, top, c)
    super
    return unless $design == 1 || $design == 3
    list = rows
    sel = current
    (@row_hits || []).each do |i, _x0, y, *|
      r = list[i]
      next unless goes_to(r)
      selected = r.equal?(sel) && @focus == :list
      x = SS::NAME_X + r.indent * 16 + Reloaded::Pixel.width(::KIF::PixelFont::ROW, r.label) + 6
      if $design == 1
        Reloaded::Pixel.pill(top, x, y + 4, _INTL("SETTINGS"), selected ? c[:selb] : c[:pill], selected ? c[:dark] : c[:txt], false)
      elsif selected
        Reloaded::ButtonIcons.draw(top, x, y + 4, button(:X), c, Reloaded::Prompts.style)
      end
    end
  end

  def hint_pairs
    pairs = super
    return pairs if @dropdown || @entry || @focus != :list
    pairs = pairs.map { |p| p[1] == _INTL("Sections") && @came_from ? [p[0], _INTL("Back"), p[2]] : p }
    if goes_to(current)
      pairs.insert(pairs.length - 1, [button(:X), _INTL("Go to Settings")])
    end
    return pairs
  end

  # The jump: the heading at the top of the list, the cursor on its first row
  def mock_jump
    to = goes_to(current)
    list = rows
    head = list.index { |r| r.kind == :head && r.label.to_s == to }
    raise "no heading #{to}" unless head
    @came_from = @sel
    @sel = opt_rows.index(head + 1)
    ys = []
    y = 0
    list.each { |r| ys << y; y += row_h(r) }
    avail = (SS::LIST_Y1 - 4) - (SS::LIST_Y0 + 4)
    last = ys.find { |v| y - v <= avail } || 0
    @scroll = [ys[head], last].min
    refresh
  end
end
Reloaded::SettingsScreen.prepend(JumpMock)

# every feature with a page On, so its heading shows
Reloaded::Features.all.each { |f| Reloaded::Features.set(f[:id], :on) if f[:page] && !f[:core] }
S.set(:"interface.theme", 2)

[[0, "dark"], [2, "light"]].each do |mode, tone|
  S.set(Reloaded::Palette::MODE, mode)
  [1, 2, 3].each do |d|
    $design = d
    drive("design #{d} #{tone}", [
      I::RIGHT, down_to("Speed-Up"),
      at { check("on the Features page's Speed-Up (#{scr.current.heading})", scr.current.heading.to_s == "Features") },
      dmp("sj_#{d}_on_#{tone}"),
      at { scr.mock_jump },
      at { check("...then on Speed-Up's own heading (#{scr.current.heading})", scr.current.heading.to_s == "Speed-Up") },
      dmp("sj_#{d}_jumped_#{tone}"),
      I::BACK, I::BACK
    ])
  end
end
