#==============================================================================
# Kanto Reloaded: what the engine sees of a controller, in the log
#==============================================================================
# For the controller question (2026-10-21: does KIF Beta's engine see Xbox
# and PlayStation controllers by itself, or only through DS4Windows or
# Steam?). Once a game step, with Reloaded Controls On or Off, it notes in
# Kanto Reloaded's log:
#
#   - whether a controller is there at start-up, and each time one comes or
#     goes, with the name the engine gives it and how many buttons and axes
#     it reports
#   - the first press of each button and the first push of each stick or
#     trigger direction while it's there (each once, so the log stays short)
#   - every device the engine's SDL sees (PadSDL.rb), by name and model
#     (vendor:product), and whether it's on the engine's controller list:
#     one that isn't, the game can't use. At start-up, and again when the
#     number of devices changes. Also SDL's version, and Wine's under Wine.
#
# The fix comes first, at start-up: the newer controller models in
# ControllerModels.txt (SDL's current list, for models the engine's 2021
# list doesn't have) are added to the engine's list, and a controller that
# only those make known, already plugged in, is opened.
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
      SURVEY_EVERY = 60              # steps between looks at how many devices SDL sees
      MODELS = File.join(File.dirname(__FILE__), "ControllerModels.txt")

      class << self
        def step
          return if @off
          survey_step
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
          @off = @no_api = @connected = @started = nil
          @survey_off = @survey_tick = @survey_count = @clicked = nil
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

        # What SDL itself sees: at start-up, and when the count changes
        def survey_step
          return if @survey_off
          @survey_tick = (@survey_tick || 0) + 1
          return unless @survey_tick == 1 || @survey_tick % SURVEY_EVERY == 0
          # KIF's own fix (C-SYS-08) adds the models and logs the devices:
          # Kanto Reloaded's steps aside (its button notes stay)
          if defined?(::KIF::Controllers)
            @survey_off = true
            note("KIF's own controller fix is here: it adds the newer models and lists the devices in KIF_log.txt")
            return
          end
          sdl = PadSDL
          unless sdl.available?
            @survey_off = true
            note("The engine's SDL couldn't be asked about devices (#{sdl.problem})")
            return
          end
          newly = @survey_tick == 1 ? add_models(sdl) : []
          n = sdl.count
          return if n == @survey_count
          @survey_count = n
          devs = sdl.devices
          under = sdl.wine ? ", under Wine #{sdl.wine}," : ""
          note("SDL #{sdl.version}#{under} sees #{devs.length} #{devs.length == 1 ? 'device' : 'devices'}#{devs.empty? ? '' : ':'}")
          devs.each_with_index do |d, i|
            words = if !d[:controller] then "not on the engine's controller list, so the game can't use it"
                    elsif newly.include?(i) then "a controller (one of the newer models added)"
                    else "a controller"
                    end
            note("  \"#{d[:name] || '?'}\" #{sdl.model(d)}: #{words}")
          end
        rescue StandardError => e
          @survey_off = true
          Reloaded::Log.exception("The device survey stopped", e, :controls)
        end

        # The newer models, added at start-up; the devices only they make
        # known (by index). One plugged in is opened if the game has none.
        def add_models(sdl)
          return [] unless File.file?(MODELS)
          before = sdl.devices.map { |d| d[:controller] }
          added, known = sdl.add_models_from(MODELS)
          note("Added #{added} newer controller models to the engine's list (#{known} it already had)")
          newly = []
          sdl.devices.each_with_index { |d, i| newly << i if d[:controller] && !before[i] }
          c = defined?(::Input::Controller) ? ::Input::Controller : nil
          if !newly.empty? && c && !(c.connected? rescue false)
            note("Asked the engine to open the newly known controller") if sdl.open_in_engine(newly.first)
          end
          return newly
        rescue StandardError => e
          Reloaded::Log.exception("The newer controller models couldn't be added", e, :controls)
          return []
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
