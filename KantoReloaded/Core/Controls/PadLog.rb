#==============================================================================
# Kanto Reloaded: what the engine sees of a controller, in the log
#==============================================================================
# For the controller question (2026-10-21: does the engine see Xbox and
# PlayStation controllers by itself, or only through DS4Windows or
# Steam?). Once a game step, with Reloaded Controls On or Off, it notes in
# Kanto Reloaded's log:
#
#   - whether a controller is there at start-up, and each time one comes or
#     goes, with the name the engine gives it and how many buttons and axes
#     it reports
#   - the first press of each button and the first push of each stick or
#     trigger direction while it's there (each once, so the log stays short)
#
# Kanto Reloaded's own controller fix (newer models added to the engine's
# SDL) is gone (his call, 2026-10-22): KIF 1.0.4's engine has SDL 2.28,
# which knows them, and doesn't let scripts reach its SDL. KIF_log.txt
# names the controller in use (KIF's C-SYS-08).
#
# Bug Reports carry the log, so a player's report says what their
# controller looked like to the game. If it ever fails it stops for the
# session; input itself never depends on it.
#==============================================================================

module Reloaded
  module Controls
    module PadLog
      # SDL's controller buttons and axes, in the engine's order
      BUTTONS = %w[A B X Y Back Guide Start LeftStick RightStick LeftShoulder RightShoulder
                   DPadUp DPadDown DPadLeft DPadRight Misc1 Paddle1 Paddle2 Paddle3 Paddle4 Touchpad].freeze
      AXES = %w[LeftX LeftY RightX RightY LeftTrigger RightTrigger].freeze
      PUSH = 0.5                     # how far a stick or trigger goes before it counts

      class << self
        def step
          return if @off
          note_first_click
          c = defined?(::Input::Controller) ? ::Input::Controller : nil
          unless c
            unless @no_api
              @no_api = true
              note("The engine has no Input::Controller, so it can't report a controller")
            end
            return
          end
          on = (c.connected? rescue false) ? true : false
          changed(c, on) if on != @connected
          @started = true
          return unless on
          ((c.raw_button_states rescue nil) || []).each_with_index do |down, i|
            next unless down && !@seen[[:button, i]]
            @seen[[:button, i]] = true
            note("Controller button #{i} (#{BUTTONS[i] || '?'}) pressed")
          end
          ((c.raw_axes rescue nil) || []).each_with_index do |v, i|
            v = v.to_f
            next unless v.abs >= PUSH
            k = [:axis, i, v > 0]
            next if @seen[k]
            @seen[k] = true
            note(format("Controller axis %d (%s) %s (%.2f)", i, AXES[i] || "?", v > 0 ? "+" : "-", v))
          end
        rescue StandardError => e
          @off = true
          Reloaded::Log.exception("The controller check stopped", e, :controls)
        end

        # Forget what's been noted (the tests start again)
        def reset
          @off = @no_api = @connected = @started = @clicked = nil
          @seen = {}
        end

        private

        # The session's first click or tap, and where it landed: whether a
        # phone's touches reach the game as clicks (Kanto Reloaded's screens
        # take them)
        def note_first_click
          return if @clicked
          return unless Reloaded::Pointer.left?
          @clicked = true
          pos = Reloaded::Pointer.pos
          note(pos ? "First click or tap at (#{pos[0]}, #{pos[1]})" : "First click or tap (with no position)")
        end

        def changed(c, on)
          @connected = on
          @seen = {}
          controls = Reloaded::Controls.enabled? ? "On" : "Off"
          unless on
            note(@started ? "The controller was disconnected." : "No controller at start-up (Reloaded Controls #{controls})")
            return
          end
          buttons = ((c.raw_button_states rescue nil) || []).length
          axes = ((c.raw_axes rescue nil) || []).length
          note("Controller #{@started ? 'connected' : 'there at start-up'}: \"#{(c.name rescue '?')}\" " \
               "(#{buttons} buttons, #{axes} axes; Reloaded Controls #{controls})")
        end

        def note(text)
          Reloaded::Log.info(text, :controls)
        end
      end
    end
  end
end
