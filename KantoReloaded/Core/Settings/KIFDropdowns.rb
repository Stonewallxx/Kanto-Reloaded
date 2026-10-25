#==============================================================================
# Kanto Reloaded: Option Dropdowns in KIF Settings
#==============================================================================
# A on a choice opens a dropdown of its values (Reloaded::Dropdown) instead
# of stepping through them; Left/Right still step. Which choices:
#
#   Reloaded Settings On   every choice in the improved KIF Settings (the
#                          screen opens it: Core/UI/SettingsScreen.rb), and
#                          the Controls screen's Feel settings
#   Reloaded Settings Off  Kanto Reloaded's rows in KIF Settings as it
#                          ships (hooked here); KIF's own rows stay as KIF
#                          ships them
#
# Choices with their own picker (:long: Theme, the frames, the colours)
# keep it. The description box explains the highlighted choice: its own
# description when it has one (KIF's per-value descriptions, a Kanto
# Reloaded setting's :descriptions), else the setting's.
#==============================================================================

module Reloaded
  module KIFDropdowns
    class << self
      # The dropdown open in KIF Settings as it ships, or nil.
      attr_reader :open

      def boot
        return true unless defined?(::KifSettingsScreen) && defined?(::KIF::SettingsScreen)
        Reloaded::Hooks.prepend(nil, "KifSettingsScreen", ScreenPress, :id => :kif_dropdowns)
        return true
      end

      # True when A on this option opens its dropdown.
      def dropdown?(o)
        return false unless o && ::KIF::SettingsScreen.choices?(o) && o.values.length > 1
        return !(own_picker?(o))
      end

      # A Kanto Reloaded choice with its own picker (:long).
      def own_picker?(o)
        return false unless Reloaded::KIFBridge.bridge_option?(o)
        d = Reloaded::Settings.definition(o.kr_key)
        return d ? d[:long] : false
      end

      # The values that can't be picked now: { index => reason }.
      def locks(o)
        return {} unless Reloaded::KIFBridge.bridge_option?(o)
        return Reloaded::Settings.locked_choices(o.kr_key)
      end

      # What choice i of o does: its own description, or nil when it has
      # none (the setting's description then explains it).
      def choice_text(o, i)
        d = nil
        if Reloaded::KIFBridge.bridge_option?(o)
          d = Reloaded::Settings.choice_description(o.kr_key, i)
        elsif defined?(::KIF::SettingsScreen::DESCRIPTIONS)
          t = ::KIF::SettingsScreen::DESCRIPTIONS[o.name.to_s.strip]
          if t.is_a?(Array) && t.length == o.values.length && t[i]
            d = _INTL(t[i])
            d = ::KIF::Keys.fill(d) if defined?(::KIF::Keys) && ::KIF::Keys.respond_to?(:fill)
          end
        end
        if d.nil?
          own = (o.description rescue nil)
          d = own[i] if own.is_a?(Array) && own.length == o.values.length
        end
        return nil if d.nil?
        return ::KIF::PixelFont.utf8(d.to_s).gsub(/\s+/, " ").strip
      end

      # The description box's text for choice i: why it's locked, then what
      # it does (fallback: the setting's own description).
      def explain(o, i, fallback)
        return with_lock(choice_text(o, i) || fallback.to_s, locks(o)[i])
      end

      # The same for a Kanto Reloaded setting (the Controls screen's Feel).
      def explain_setting(key, i, fallback)
        text = Reloaded::Settings.choice_description(key, i)
        text = text ? ::KIF::PixelFont.utf8(text.to_s).gsub(/\s+/, " ").strip : fallback.to_s
        return with_lock(text, Reloaded::Settings.locked_choices(key)[i])
      end

      def with_lock(text, why)
        return text unless why
        lock = why.empty? ? _INTL("Locked.") : _INTL("Locked: {1}.", why)
        return ::KIF::PixelFont.utf8(lock) + " " + text
      end

      #------------------------------------------------------------------------
      # KIF Settings as it ships
      #------------------------------------------------------------------------
      # Opens r's dropdown on screen (a KifSettingsScreen); its value is set
      # when one is picked. False when it couldn't open (KIF's A then).
      def vanilla(screen, r)
        o = r.opt
        vp = screen.instance_variable_get(:@viewport)
        anchor = vanilla_anchor(screen, r)
        return false unless vp && anchor
        k = screen.class
        bounds = [k::LIST_X0 + 4, k::LIST_Y0 + 2, k::LIST_X1 - 4, k::LIST_Y1 - 2]
        c = Reloaded::Palette.build(Reloaded::Palette::THEME_NAMES.index("Base") || 0, 0, 0)
        values = o.values.map { |v| ::KIF::PixelFont.utf8(v.to_s) }
        cur = (o.get rescue 0).to_i
        locked = locks(o)
        general = screen.send(:desc_of, o)
        dd = Reloaded::Dropdown.new(values, cur, anchor, bounds, :locked => locked.keys, :cursor => false)
        sprite = Sprite.new(vp)
        sprite.bitmap = Bitmap.new(Graphics.width, Graphics.height)
        sprite.z = 10
        pbPlayDecisionSE
        @open = dd
        screen.send(:refresh)                # without the values it cuts through
        choice = Reloaded::Dropdown.run(dd, sprite.bitmap, c) do |b, d|
          vanilla_explain(screen, b, values[d.index], explain(o, d.index, general))
        end
        @open = nil
        if choice && choice != cur
          o.set(choice)
          screen.send(:after_change)
        end
        return true
      ensure
        @open = nil
        if sprite && !sprite.disposed?
          sprite.bitmap.dispose
          sprite.dispose
        end
        screen.send(:refresh) rescue nil
      end

      private

      # [x0, y0, x1, y1] of r's value as KIF Settings draws it (choices side
      # by side: their right end, so the list is as wide as its choices,
      # against the right edge).
      def vanilla_anchor(screen, r)
        k = screen.class
        out, = screen.send(:layout_rows)
        list = screen.send(:rows)
        at = out.find { |i, _y| list[i].equal?(r) }
        return nil unless at
        y = at[1]
        mode = screen.send(:value_mode, r)
        vy = mode == :below ? y + k::ROW_H + 1 : y + 2
        pf = ::KIF::PixelFont
        if mode == :arrows
          vw = pf.width(pf::TEXT, pf.fit(pf::TEXT, pf.utf8(r.opt.values[(r.opt.get rescue 0).to_i].to_s), 150))
          return [k::VAL_X1 - vw - 26, vy, k::VAL_X1, vy + 21]
        end
        return [k::VAL_X1 - 40, vy, k::VAL_X1, vy + 21]
      end

      # The highlighted choice in KIF Settings' description box, and the
      # dropdown's hints in its key bar, drawn over the screen.
      def vanilla_explain(screen, b, title, text)
        k = screen.class
        ui = ::KIF::PixelUI
        pf = ::KIF::PixelFont
        w = b.width
        h = b.height
        y0 = k::LIST_Y1 + 4
        screen.send(:rbox, b, 6, y0, w - 6, h - 30, 6, ui::PANEL2, ui::LINE)
        screen.send(:text, b, 14, y0 + 1, 330, 26, pf.fit(pf::ROW, title, 330), ui::TXT, pf::ROW)
        screen.send(:wrap, text, w - 30).first(k::DESC_LINES).each_with_index do |ln, i|
          screen.send(:text, b, 14, y0 + 26 + i * k::DESC_DY, w - 34, k::DESC_DY, ln, ui::TXT)
        end
        pick = ::KIF::Keys.label(Input::USE, "C") rescue "C"
        back = ::KIF::Keys.label(Input::BACK, "Esc") rescue "Esc"
        screen.send(:footer, b, [[:ud, _INTL("Choose")], [pick, _INTL("Pick")], [back, _INTL("Close")]])
      end
    end

    # A on one of Kanto Reloaded's choices in KIF Settings as it ships.
    module ScreenPress
      def press
        return super if defined?(Reloaded::SettingsScreen) && is_a?(Reloaded::SettingsScreen)
        r = current
        o = r && !r.action ? r.opt : nil
        return super unless o && Reloaded::KIFBridge.bridge_option?(o) && Reloaded::KIFDropdowns.dropdown?(o)
        return locked_buzz(r) if locked_by(o)
        done = Reloaded::Hooks.guard(nil, :kif_dropdowns, false) { Reloaded::KIFDropdowns.vanilla(self, r) }
        super unless done
      end

      # While a dropdown is open, a value it would cut through isn't drawn.
      def draw_value(b, r, y, selected, mode)
        dd = Reloaded::KIFDropdowns.open
        return super unless dd
        k = self.class
        return if dd.covers?(k::VAL_X1 - 170, y + 2, k::VAL_X1, y + 19)
        super
      end
    end
  end
end
