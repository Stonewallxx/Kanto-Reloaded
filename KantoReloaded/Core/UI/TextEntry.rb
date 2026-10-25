#==============================================================================
# Kanto Reloaded: text entry
#==============================================================================
# Typing in a field inside Kanto Reloaded's screens, the way KIF Settings'
# search works: the screen draws the field (draw_field), and what's typed
# goes straight into it.
#
#   text, how = TextEntry.run(scene, "Type to Search", "", 30,
#                             :prompt => "Search settings", :down => true) { |text| ... }
#
# The block runs on every change (Search shows results as you type).
# how is :enter (Enter; Down too when :down is true; or the naming screen)
# or :stop (Esc, or B). The scene answers entry= and entry_changed.
#
# Keyboard: type, Backspace deletes, Ctrl+V pastes, Enter finishes, Esc
# stops.
# Controller: A opens the game's naming screen (pbEnterText) with the text so
# far, and its result is the field's text; B stops.
# A keyboard letter can also be a game button (C is Use, X is Back...), so a
# frame that typed text never counts as a button press.
#==============================================================================

module Reloaded
  module TextEntry
    class State
      attr_accessor :label, :text, :max, :timer

      def initialize(label, text, max)
        @label = label
        @text = text.to_s.dup
        @max = max
        @timer = 0
      end

      def caret_visible?
        return (@timer / 20).even?
      end
    end

    class << self
      def run(scene, label, initial = "", max = 30, prompt: nil, down: false, &on_change)
        state = State.new(label, initial, max)
        scene.entry = state
        set_text_input(true)
        Input.gets if Input.respond_to?(:gets)   # drop the key that opened it
        scene.entry_changed
        loop do
          Graphics.update
          Input.update
          scene.update_frame if scene.respond_to?(:update_frame)
          state.timer += 1
          case step(state, down)
          when :enter
            pbPlayDecisionSE
            return [state.text.strip, :enter]
          when :stop
            pbPlayDecisionSE
            return [state.text.strip, :stop]
          when :pad
            pbPlayDecisionSE
            text = naming_screen(scene, prompt || label, state)
            state.text = text.to_s[0, max] unless text.nil?
            on_change.call(state.text) if on_change
            return [state.text.strip, :enter]
          when :changed
            on_change.call(state.text) if on_change
            scene.entry_changed
          else
            scene.entry_changed if state.timer % 20 == 0     # caret blink
          end
        end
      ensure
        set_text_input(false)
        scene.entry = nil
        scene.entry_changed
      end

      # One frame of input: :enter, :stop, :pad, :changed or nil.
      def step(state, down = false)
        typed = keyboard_text
        return :enter if raw_trigger?(:RETURN) || raw_trigger?(:KP_ENTER)
        return :stop if raw_trigger?(:ESCAPE)
        return delete(state) if raw_repeat?(:BACKSPACE)
        return paste(state) if raw_trigger?(:V) && ctrl_held?
        unless typed.empty?
          typed.each_char { |ch| insert(state, ch) }
          return :changed
        end
        return :enter if down && Input.trigger?(Input::DOWN)
        return :pad if Input.trigger?(Input::USE) && !keyboard_key?(Input::USE)
        return :stop if Input.trigger?(Input::BACK) && !keyboard_key?(Input::BACK)
        return nil
      end

      # The field: base gets the box, top the text and caret. pad is the room
      # left of the text (an icon goes there).
      def draw_field(base, top, c, state, x, y, w, h, pad = 10)
        p = Reloaded::Pixel
        pf = p.pf
        p.ui.rbox(base, x, y, x + w, y + h, 5, c[:dark], c[:selb])
        room = w - pad - 16
        shown = pf.utf8(state.text)
        shown = shown[1..-1] while shown.length > 1 && pf.width(pf::TEXT, shown) > room   # keep the end in view
        tx = x + pad
        tw = shown.empty? ? 0 : p.text(top, tx, y, room, h, shown, c[:txt])
        cx = tx + tw + (tw > 0 ? 2 : 0)
        top.fill_rect(cx, y + 5, 2, h - 10, c[:selb]) if state.caret_visible?
        p.text(top, cx + 6, y, room, h, state.label, c[:dim]) if shown.empty?
      end

      private

      def naming_screen(scene, prompt, state)
        set_text_input(false)
        enter = proc { pbEnterText(prompt, 0, state.max, state.text) }
        return scene.respond_to?(:hidden) ? scene.hidden(&enter) : enter.call
      end

      def insert(state, ch)
        return if state.text.length >= state.max || ch.ord < 32
        state.text << ch
      end

      # Ctrl+V: the clipboard's text, one line, as far as the field takes it
      def paste(state)
        text = Reloaded::ShareCodes.clipboard.to_s.gsub(/[\r\n\t]+/, " ").strip
        return nil if text.empty?
        text.each_char { |ch| insert(state, ch) }
        return :changed
      end

      def ctrl_held?
        return false unless Input.respond_to?(:pressex?)
        return Input.pressex?(:LCTRL) || Input.pressex?(:RCTRL)
      rescue StandardError
        return false
      end

      def delete(state)
        return nil if state.text.empty?
        state.text = state.text[0...-1]
        return :changed
      end

      # True when the button was pressed by a keyboard key bound to it (so
      # it isn't a controller's).
      def keyboard_key?(button)
        return false unless defined?(::KIF::Keys)
        return ::KIF::Keys.symbols(button).any? { |k| raw_trigger?(k) }
      rescue StandardError
        return false
      end

      def keyboard_text
        return "" unless Input.respond_to?(:gets)
        text = Input.gets.to_s.dup.force_encoding(Encoding::UTF_8)
        text = text.scrub("") unless text.valid_encoding?
        return text.gsub(/[[:cntrl:]]/, "")
      rescue StandardError
        return ""
      end

      def raw_trigger?(key)
        return Input.respond_to?(:triggerex?) && Input.triggerex?(key)
      rescue StandardError
        return false
      end

      def raw_repeat?(key)
        return Input.respond_to?(:repeatex?) && Input.repeatex?(key)
      rescue StandardError
        return false
      end

      def set_text_input(on)
        Input.text_input = on if Input.respond_to?(:text_input=)
      rescue StandardError
        nil
      end
    end
  end
end
