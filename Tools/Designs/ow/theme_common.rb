# encoding: utf-8
# Mockups: Theme Mode Light for the Pause Menu and Overworld Menu (his
# pick, 2026-10-21: the map menus follow Theme Mode). Each design is a light
# palette made from the Theme's own colours (Ocean Blue here) and darker
# status colours, put on the real screens: the palette the screens read
# (Reloaded::Palette.current) and their status colours are swapped.
# Design 1 = the Light frames' own look (make_theme_frames.py), so a menu
# matches the windows around it.
module ThemeDesigns
  module_function

  def hex(t); Reloaded::Palette.hex(t); end
  def mix(a, b, t); Reloaded::Palette.mix(a, b, t); end
  def rgb(*v); Color.new(*v); end

  WHITE = [248, 248, 248]

  # Status colours that read on a pale panel
  STATUS = { :GREEN => [30, 140, 70], :GOLD => [176, 118, 0], :RED => [196, 48, 48], :AMBER => [196, 104, 0],
             :BLUE => [30, 96, 196], :PINK => [196, 56, 116] }.freeze

  # [name, words, palette]
  def designs(theme = "Ocean Blue")
    t = Reloaded::Palette::THEMES[theme]
    acc = hex(t[:accent])
    inner = hex(t[:inner])
    border = hex(t[:border])
    ink = hex(t[:panel])
    white = rgb(*WHITE)
    out = []
    # 1: the Light frames' look: a near-white panel with a tenth of the
    # accent, the frames' blue border, the Theme's dark ink for text
    p = base
    p[:panel2] = mix(white, acc, 0.10)
    p[:panel] = mix(white, acc, 0.17)
    p[:bg] = mix(white, acc, 0.24)
    p[:line] = mix(inner, p[:panel2], 0.35)
    p[:txt] = ink
    p[:dim] = mix(ink, p[:panel2], 0.48)
    p[:sel] = mix(p[:panel2], acc, 0.35)
    p[:selb] = inner
    p[:acc] = inner
    p[:head] = border
    p[:key] = mix(p[:panel2], inner, 0.30)
    p[:pill] = p[:key]
    p[:dark] = mix(p[:panel2], border, 0.14)
    p[:segon] = inner
    out << ["Matching Frames", "The Light frames' own look: A near-white panel with a touch of the Theme's color, the frames' blue lines, the Theme's dark ink for words.", finish(p)]
    # 2: clean white: no tint, grey lines, the Theme's color only where
    # something's chosen
    p = base
    p[:panel2] = rgb(250, 250, 251)
    p[:panel] = rgb(240, 242, 245)
    p[:bg] = rgb(228, 231, 236)
    p[:line] = rgb(196, 202, 211)
    p[:txt] = rgb(32, 38, 48)
    p[:dim] = rgb(112, 120, 133)
    p[:sel] = mix(white, acc, 0.28)
    p[:selb] = inner
    p[:acc] = inner
    p[:head] = inner
    p[:key] = rgb(224, 228, 234)
    p[:pill] = p[:key]
    p[:dark] = rgb(226, 229, 234)
    p[:segon] = inner
    out << ["Clean White", "Plain white panels and grey lines; the Theme's color only on what's chosen and the headings.", finish(p)]
    # 3: pastel: a stronger tint, the Theme's deep border for lines and
    # what's chosen
    p = base
    p[:panel2] = mix(white, acc, 0.42)
    p[:panel] = mix(white, acc, 0.52)
    p[:bg] = mix(white, acc, 0.60)
    p[:line] = mix(border, p[:panel2], 0.25)
    p[:txt] = hex(t[:bg])
    p[:dim] = mix(hex(t[:bg]), p[:panel2], 0.45)
    p[:sel] = mix(p[:panel2], inner, 0.40)
    p[:selb] = border
    p[:acc] = border
    p[:head] = border
    p[:key] = mix(p[:panel2], border, 0.25)
    p[:pill] = p[:key]
    p[:dark] = mix(p[:panel2], border, 0.20)
    p[:segon] = border
    out << ["Pastel", "A stronger tint of the Theme's color, its deep border for lines and what's chosen.", finish(p)]
    return out
  end

  def base
    return Reloaded::Palette.build(Reloaded::Palette::DEFAULT_THEME, 0, 0).dup
  end

  def finish(p)
    p[:title] = p[:txt]
    p[:opt] = p[:txt]
    p[:sidesel] = p[:sel]
    p[:warn] = rgb(*STATUS[:AMBER])
    p[:dot] = p[:acc]
    p[:shadow] = p[:panel2]
    p[:white] = rgb(255, 255, 255)
    p[:base] = false
    return p
  end

  # The screens read this palette and these status colours, and draw their
  # panels nearly solid, as the Light frames are
  def use(palette)
    $theme_palette = palette
    $VERBOSE = nil
    owners = [Reloaded::OverworldMenuScreen]
    owners << Reloaded::PauseMenu::View if defined?(Reloaded::PauseMenu::View)
    owners << Reloaded::Notice if defined?(Reloaded::Notice)
    owners.each do |k|
      STATUS.each { |name, v| (k.send(:remove_const, name); k.const_set(name, rgb(*v))) if k.const_defined?(name, false) }
      [[:PANEL_ALPHA, 250], [:TILE_ALPHA, 245]].each { |name, v| (k.send(:remove_const, name); k.const_set(name, v)) if k.const_defined?(name, false) }
    end
  end
end
# The cursor, lighter over a pale panel so the dark words show through it
Reloaded::Palette.singleton_class.prepend(Module.new do
  def current; $theme_palette || super; end
  def cursor(value = nil)
    p = $theme_palette
    return super unless p
    a = p[:acc]
    return [Color.new(a.red, a.green, a.blue, 60), Color.new(a.red, a.green, a.blue, 230)]
  end
end)

# Light badges: a pale fill of the badge's color, its words darkened to read
Reloaded::Pixel.singleton_class.prepend(Module.new do
  def pill(b, x, y, label, fill, color, right = true)
    p = $theme_palette
    if p && fill.red + fill.green + fill.blue < 240
      color = Reloaded::Palette.mix(color, Color.new(0, 0, 0), 0.35) if color.red + color.green + color.blue > 420
      fill = Reloaded::Palette.mix(p[:panel2], color, 0.22)
    end
    super(b, x, y, label, fill, color, right)
  end
end)

# The Pause Menu's map wash: pale for Light, so its dark headings read
if defined?(Reloaded::PauseMenu::View)
  Reloaded::PauseMenu::View.prepend(Module.new do
    def open
      super
      p = $theme_palette
      return unless p && @dim
      @dim.bitmap.clear
      w = p[:panel2]
      @dim.bitmap.fill_rect(0, 0, @dim.bitmap.width, @dim.bitmap.height, Color.new(w.red, w.green, w.blue, 130))
    end
  end)
end
