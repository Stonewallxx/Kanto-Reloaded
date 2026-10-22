#==============================================================================
# Kanto Reloaded: themes and colours
#==============================================================================
# The colours of Kanto Reloaded's screens (the improved KIF Settings, popups,
# and every KR screen after it), and their Interface settings:
#
#   Theme           Base (KIF Settings' own colours) or one of 9 themes;
#                   Ocean Blue is the default
#   Header Color    screen titles and section headings
#   Settings Color  setting names and their values
#   Cursor Color    the pulsing cursor (the Kanto Reloaded mod's cursor)
#
# Header, Settings and Cursor Color list "Theme" and 45 colours. The text
# colours never change the theme itself.
#
# Palette.current returns the colours as Color objects:
#   :bg :panel :panel2 :line   backgrounds, panels, lines
#   :txt :dim                  text and dimmed text
#   :sel :selb :acc            selection fill, selection border, accent
#   :key :pill :dark :segon    small boxes, badges, dark fields, filled bars
#   :sidesel                   the open section's box (Base only)
#   :warn :dot                 warnings, the changed-setting dot
#   :head :opt                 Header Color, Settings Color
#   :green :gold :red          statuses (and :amber :blue :pink)
#   :base                      true for the Base theme
#
# The map menus (the Pause Menu, the Overworld Menu and their popups) take
# the Theme Mode as the game's windows do (his pick, 2026-10-21): map_menu
# gives their colours. Dark and Glass are the Theme's own; Light and Frost
# the Light frames' look (Matching Frames): a near-white panel with a touch
# of the Theme's accent, its lines, its dark ink for words, deeper statuses
# (:light true). menu_alpha makes a panel see-through for Glass and Frost.
#==============================================================================

module Reloaded
  module Palette
    THEME_NAMES = ["Base", "Purple", "Ocean Blue", "Forest", "Kanto Red", "Ember Orange",
                   "Aqua Cyan", "Sakura", "Thunder Yellow", "Midnight"].freeze
    DEFAULT_THEME = 2      # Ocean Blue
    MODE = :"interface.theme_mode"    # Dark, Glass, Light, Frost (WindowFrames)

    # Statuses on dark panels, and on the Light ones (deeper, to read)
    TONES = { :green => [120, 230, 150], :gold => [240, 200, 80], :red => [240, 100, 90], :amber => [240, 170, 60],
              :blue => [130, 190, 250], :pink => [240, 130, 160] }.freeze
    LIGHT_TONES = { :green => [30, 140, 70], :gold => [176, 118, 0], :red => [196, 48, 48], :amber => [196, 104, 0],
                    :blue => [30, 96, 196], :pink => [196, 56, 116] }.freeze

    # Hex colours per theme (not Base, which is KIF's own).
    THEMES = {
      "Purple"         => { :bg => "0e0a17", :panel => "160f24", :border => "3a2b5c", :inner => "6a55a0", :line => "2a1f44", :sel => "2a1f44", :accent => "b48cff", :text => "f1ebff", :muted => "9a8cb8", :gold => "ffd166" },
      "Ocean Blue"     => { :bg => "08111f", :panel => "0f1b30", :border => "24406e", :inner => "4a78c0", :line => "1a2c4c", :sel => "1c3155", :accent => "6fb2ff", :text => "eaf3ff", :muted => "8aa3c6", :gold => "ffd166" },
      "Forest"         => { :bg => "0a140c", :panel => "102016", :border => "2a5a36", :inner => "4f9a5e", :line => "1a3322", :sel => "1d3a25", :accent => "7ddc8a", :text => "eefbef", :muted => "8fb597", :gold => "f0d36b" },
      "Kanto Red"      => { :bg => "1a0b0b", :panel => "241010", :border => "6b1f1f", :inner => "b03a3a", :line => "3a1616", :sel => "3d1a1a", :accent => "ff6b6b", :text => "fff1ec", :muted => "c79a92", :gold => "ffd166" },
      "Ember Orange"   => { :bg => "1c0e04", :panel => "2a1508", :border => "8a4310", :inner => "e07a20", :line => "40220b", :sel => "47270d", :accent => "ff8c1a", :text => "fff3e6", :muted => "cca07a", :gold => "ffe08a" },
      "Aqua Cyan"      => { :bg => "04161a", :panel => "082228", :border => "1d5c66", :inner => "2fa6b4", :line => "0f343b", :sel => "12393f", :accent => "4fe0e8", :text => "e8fdff", :muted => "82b4ba", :gold => "ffd166" },
      "Sakura"         => { :bg => "1a0a12", :panel => "24101a", :border => "6b2a4a", :inner => "c0588a", :line => "3a1828", :sel => "3e1a2c", :accent => "ff8fc4", :text => "fff0f7", :muted => "c896ae", :gold => "ffd166" },
      "Thunder Yellow" => { :bg => "151305", :panel => "201d08", :border => "6a5c14", :inner => "c8ac28", :line => "34300e", :sel => "3a3410", :accent => "ffe03c", :text => "fffbe6", :muted => "bdb17a", :gold => "ffb347" },
      "Midnight"       => { :bg => "08080a", :panel => "121216", :border => "3a3a44", :inner => "6a6a78", :line => "222228", :sel => "26262e", :accent => "d0d0dc", :text => "f4f4f8", :muted => "9898a6", :gold => "ffd166" }
    }.freeze

    # [name, hex, shadow hex or nil]: the 45 colours of the colour settings.
    COLORS = [
      ["White", "f8f8f8", "485058"], ["Silver", "c8ccd4", nil], ["Gray", "98a0a8", nil],
      ["Charcoal", "383840", nil], ["Black", "505058", "a0a0a8"],
      ["Red", "f07878", "5c2c2c"], ["Crimson", "e04050", nil], ["Ruby", "c02040", nil],
      ["Scarlet", "ff5030", nil], ["Coral", "ff7f60", nil], ["Salmon", "ffa090", nil],
      ["Peach", "ffc8a0", nil], ["Orange", "f8a858", "604020"], ["Amber", "ffbf40", nil],
      ["Gold", "ffd700", nil], ["Yellow", "f0e058", "5c5420"], ["Lemon", "fff380", nil],
      ["Cream", "fff4d0", nil], ["Tan", "d8b888", nil], ["Brown", "a06838", nil],
      ["Olive", "a0a040", nil], ["Lime", "a8f040", nil], ["Green", "32cd32", "146414"],
      ["Emerald", "40d080", nil], ["Forest Green", "2e8b40", nil], ["Mint", "98f0c0", nil],
      ["Teal", "30b0a0", nil], ["Turquoise", "40e0d0", nil], ["Cyan", "58e0e0", "205454"],
      ["Aqua", "70f0f0", nil], ["Ice Blue", "d0f0ff", nil], ["Sky Blue", "90d0ff", nil],
      ["Blue", "58b0f8", "204060"], ["Royal Blue", "4870f0", nil], ["Navy", "283c78", nil],
      ["Indigo", "6050d0", nil], ["Violet", "9060f0", nil], ["Purple", "a880e4", "402c54"],
      ["Lavender", "c8b0ff", nil], ["Lilac", "d8a8e8", nil], ["Magenta", "f040d0", nil],
      ["Hot Pink", "ff60a8", nil], ["Pink", "f888c0", "603448"], ["Rose", "ff8098", nil],
      ["Blush", "ffc0d0", nil]
    ].freeze

    # The Kanto Reloaded mod's 10 cursors, exactly: [fill RGBA, border RGBA].
    KR_CURSORS = {
      "Blue"   => [[100, 160, 220, 160], [60, 120, 180, 220]],  "Purple" => [[160, 120, 220, 160], [100, 60, 170, 220]],
      "Green"  => [[80, 200, 100, 160], [40, 140, 60, 220]],    "Red"    => [[220, 100, 100, 160], [170, 50, 50, 220]],
      "Orange" => [[220, 160, 80, 160], [170, 110, 30, 220]],   "Cyan"   => [[80, 220, 220, 160], [30, 160, 160, 220]],
      "Pink"   => [[220, 120, 180, 160], [160, 60, 120, 220]],  "Yellow" => [[220, 210, 80, 160], [160, 150, 30, 220]],
      "White"  => [[220, 220, 220, 160], [160, 160, 160, 220]], "Black"  => [[60, 60, 70, 160], [30, 30, 40, 220]]
    }.freeze

    # KIF Settings' own colours (990_KIF/000_Core/014_KIF_PixelUI.rb).
    BASE = {
      :bg => [28, 36, 48], :panel => [46, 55, 68], :panel2 => [38, 46, 58], :line => [70, 82, 98],
      :txt => [248, 248, 248], :dim => [150, 160, 175], :sel => [58, 92, 132], :selb => [130, 190, 250],
      :acc => [110, 170, 235], :key => [80, 92, 110], :pill => [70, 84, 104], :dark => [30, 36, 46],
      :segon => [90, 110, 140], :sidesel => [52, 66, 86], :warn => [232, 160, 48], :dot => [232, 160, 48]
    }.freeze

    class << self
      def register_settings
        s = Reloaded::Settings
        color_names = ["Theme"] + COLORS.map { |c| c[0] }
        s.register(:"interface.theme", :page => :interface, :priority => 50,
          :name => "Theme", :type => :enum, :long => true, :default => DEFAULT_THEME, :values => THEME_NAMES,
          :description => "Colors of Kanto Reloaded's screens. Base keeps KIF Settings' own colors.")
        s.register(:"interface.header_color", :page => :interface, :priority => 60,
          :name => "Header Color", :type => :enum, :long => true, :swatch => :text, :default => 0, :reset => 2, :values => color_names,
          :description => "Color of screen titles and section headings. Theme keeps the theme's color.")
        s.register(:"interface.settings_color", :page => :interface, :priority => 70,
          :name => "Settings Color", :type => :enum, :long => true, :swatch => :text, :default => 0, :reset => 2, :values => color_names,
          :description => "Color of setting names and values. Theme keeps the theme's color.")
        s.register(:"interface.cursor_color", :page => :interface, :priority => 80,
          :name => "Cursor Color", :type => :enum, :long => true, :swatch => :cursor, :values => color_names,
          :default => 0, :reset => 2,
          :description => "Color of the pulsing cursor. Theme uses the theme's accent color.")
      end

      # The current colours (cached until a colour setting changes).
      def current
        s = Reloaded::Settings
        key = [s.get(:"interface.theme"), s.get(:"interface.header_color"), s.get(:"interface.settings_color")]
        return @current if @current && @current_key == key
        @current_key = key
        @current = build(*key)
        return @current
      end

      def build(theme_index, header, settings)
        name = THEME_NAMES[theme_index.to_i] || THEME_NAMES[DEFAULT_THEME]
        p = {}
        if name == "Base"
          BASE.each { |k, rgb| p[k] = Color.new(*rgb) }
          p[:base] = true
          p[:head] = p[:acc]
        else
          t = THEMES[name]
          bg = hex(t[:bg])
          panel = hex(t[:panel])
          p[:bg] = bg
          p[:panel] = panel
          p[:panel2] = mix(bg, panel, 0.5)
          p[:line] = hex(t[:line])
          p[:txt] = hex(t[:text])
          p[:dim] = hex(t[:muted])
          p[:sel] = hex(t[:sel])
          p[:selb] = hex(t[:accent])
          p[:acc] = hex(t[:accent])
          p[:key] = hex(t[:border])
          p[:pill] = hex(t[:border])
          p[:dark] = bg
          p[:segon] = hex(t[:inner])
          p[:sidesel] = hex(t[:sel])
          p[:warn] = hex(t[:gold])
          p[:dot] = hex(t[:accent])
          p[:base] = false
          p[:head] = p[:acc]
        end
        p[:title] = p[:txt]
        p[:opt] = p[:txt]
        if header.to_i > 0 && COLORS[header.to_i - 1]
          p[:head] = hex(COLORS[header.to_i - 1][1])
          p[:title] = p[:head]
        end
        p[:opt] = hex(COLORS[settings.to_i - 1][1]) if settings.to_i > 0 && COLORS[settings.to_i - 1]
        p[:shadow] = Color.new(16, 20, 28)
        p[:white] = Color.new(255, 255, 255)
        TONES.each { |k, rgb| p[k] = Color.new(*rgb) }
        return p
      end

      # 0 Dark, 1 Glass, 2 Light, 3 Frost
      def menu_mode
        return (Reloaded::Settings.get(MODE) rescue 0).to_i
      end

      def light_mode?
        m = menu_mode
        return m == 2 || m == 3
      end

      # The map menus' colours in the Theme Mode (cached with current)
      def map_menu
        dark = current
        return dark unless light_mode?
        return @light if @light && @light_of.equal?(dark)
        @light_of = dark
        return @light = light_from(dark, @current_key)
      end

      # A map menu panel's see-through amount (0-255) in the Theme Mode,
      # from its Dark one: Glass and Frost see-through as their frames are,
      # Light nearly solid
      def menu_alpha(a)
        case menu_mode
        when 1 then return (a * 0.72).round
        when 2 then return [a + 18, 248].min
        when 3 then return (a * 0.8).round
        end
        return a
      end

      # The Light frames' look from a Theme's colours: a near-white panel
      # with a tenth of the accent, the Theme's lines and dark ink; a Header
      # or Settings Color picked is deepened to read on it
      def light_from(d, key)
        white = Color.new(248, 248, 248)
        ink = d[:panel]
        inner = d[:segon]
        p = d.dup
        p[:panel2] = mix(white, d[:acc], 0.10)
        p[:panel] = mix(white, d[:acc], 0.17)
        p[:bg] = mix(white, d[:acc], 0.24)
        p[:line] = mix(inner, p[:panel2], 0.35)
        p[:txt] = ink
        p[:dim] = mix(ink, p[:panel2], 0.48)
        p[:sel] = mix(p[:panel2], d[:acc], 0.35)
        p[:sidesel] = p[:sel]
        p[:selb] = inner
        p[:acc] = inner
        p[:dot] = inner
        p[:segon] = inner
        p[:key] = mix(p[:panel2], inner, 0.30)
        p[:pill] = p[:key]
        p[:dark] = mix(p[:panel2], d[:key], 0.14)
        header = key && key[1].to_i > 0
        settings = key && key[2].to_i > 0
        p[:head] = header ? mix(d[:head], ink, 0.55) : d[:key]
        p[:title] = header ? p[:head] : ink
        p[:opt] = settings ? mix(d[:opt], ink, 0.55) : ink
        p[:shadow] = p[:panel2]
        LIGHT_TONES.each { |k, rgb| p[k] = Color.new(*rgb) }
        p[:warn] = p[:amber]
        p[:light] = true
        return p
      end

      # [fill, border] Colors (with alpha) for a Cursor Color value; 0 is the
      # theme's accent. On a Light palette, fainter, so the dark words under
      # it read.
      def cursor(value = nil, palette = nil)
        fill, border = cursor_colours(value)
        return [fill, border] unless palette && palette[:light]
        return [Color.new(fill.red, fill.green, fill.blue, 60), Color.new(border.red, border.green, border.blue, 230)]
      end

      def cursor_colours(value = nil)
        value = Reloaded::Settings.get(:"interface.cursor_color") if value.nil?
        value = value.to_i
        if value <= 0 || COLORS[value - 1].nil?
          a = current[:selb]
          return cursor_pair([a.red.to_i, a.green.to_i, a.blue.to_i])
        end
        name, rgb_hex, _ = COLORS[value - 1]
        if KR_CURSORS[name]
          fill, border = KR_CURSORS[name]
          return [Color.new(*fill), Color.new(*border)]
        end
        v = rgb_hex.to_i(16)
        return cursor_pair([(v >> 16) & 255, (v >> 8) & 255, v & 255])
      end

      # A colour as a cursor: itself as the fill, a darker border.
      def cursor_pair(rgb)
        r, g, b = rgb
        return [Color.new(r, g, b, 160), Color.new((r * 0.65).round, (g * 0.65).round, (b * 0.65).round, 220)]
      end

      # The colour a Header/Settings Color value draws in (for swatches).
      def text_color(value)
        value = value.to_i
        return current[:txt] if value <= 0 || COLORS[value - 1].nil?
        return hex(COLORS[value - 1][1])
      end

      def hex(text)
        v = text.to_i(16)
        return Color.new((v >> 16) & 255, (v >> 8) & 255, v & 255)
      end

      def mix(a, b, t)
        return Color.new((a.red + (b.red - a.red) * t).round, (a.green + (b.green - a.green) * t).round,
                         (a.blue + (b.blue - a.blue) * t).round)
      end

      # A colour over another, as if drawn with alpha (fill_rect replaces
      # pixels, so see-through colours are blended here when needed).
      def over(under, color, alpha = nil)
        alpha ||= color.alpha
        t = alpha / 255.0
        return Color.new((under.red + (color.red - under.red) * t).round, (under.green + (color.green - under.green) * t).round,
                         (under.blue + (color.blue - under.blue) * t).round)
      end
    end
  end
end

Reloaded::Palette.register_settings
