#==============================================================================
# Kanto Reloaded: the controls layer
#==============================================================================
# While Reloaded Controls is On, this decides what every key and controller
# button does. Once per game step (Input.update) it reads the raw keyboard
# (Input.raw_key_states), the controller's buttons and axes
# (Input::Controller), and works out each action's state from its bindings:
# pressed, just pressed, released, and repeating.
#
# The game asks for its buttons with Input.press?/trigger?/repeat?/
# release?/dir4/dir8. KIF Beta and PIF wrap some of those in Ruby (Auto-
# Battle's confirm, Cody's Frame Rate key repeat, the speed keys, F8
# screenshots); the wrappers call the engine's methods by other names. The
# layer replaces only the engine's methods, under every wrapper, so the
# wrappers keep working on the layer's answers. Everything else (Shift,
# Ctrl, Alt, F5-F9, the mouse, raw keys) is still the engine's.
#
#   - tap and hold: an input with a hold action fires its tap actions when
#     it's let go before Hold Time, and its hold actions once held that long
#   - while text is being typed, keys that type a character only type (a
#     letter never presses a game button); arrows, Enter, Esc and the
#     controller still work
#   - switching on while a button is held doesn't count it as a new press
#   - Swap A and B swaps the controller's bottom and right face buttons
#   - the stick counts past Stick Deadzone, a trigger past Trigger Press
#
# If the layer ever fails it logs why and turns itself off for the session:
# the engine's own controls take over again.
#==============================================================================

module Reloaded
  module Controls
    module Layer
      QUERIES = [:press?, :trigger?, :repeat?, :release?, :dir4, :dir8].freeze
      CHECK_FILE_EVERY = 60          # steps between looks at the F1 file
      DIRECTIONS = [:up, :down, :left, :right].freeze

      @originals = {}
      @replaced = []
      @states = {}
      @device = :keyboard

      class << self
        attr_reader :device, :area, :replaced

        def boot
          unless defined?(::Input) && ::Input.respond_to?(:update) && ::Input.respond_to?(:raw_key_states)
            Reloaded::Log.info("This engine has no raw input; Reloaded Controls is off", :controls)
            return true
          end
          install
          Reloaded::Log.info("Controls layer ready (engine methods replaced: #{@replaced.join(', ')})", :controls)
          return true
        end

        # True while the layer answers for the game's buttons.
        def active?
          return @active ? true : false
        end

        # Whether a method is the engine's own (C) code, not a Ruby wrapper.
        def engine_method?(method)
          return method.source_location.nil?
        end

        # The engine's methods for the queries and Input.update, under every
        # name they have (wrappers keep them under aliases), are replaced.
        def install
          return if @installed
          sc = ::Input.singleton_class
          names = sc.instance_methods(false) + sc.private_instance_methods(false)
          names.each do |name|
            m = own_method(sc, name)
            next unless m && engine_method?(m)
            kind = m.original_name
            if QUERIES.include?(kind)
              replace(sc, name, m, kind)
            elsif kind == :update
              replace_update(sc, name, m)
            elsif kind == :text_input=
              replace_text_input(sc, name, m)
            end
          end
          @installed = true
        end

        #----------------------------------------------------------------------
        # Every game step
        #----------------------------------------------------------------------
        def poll
          was = @active
          @active = Reloaded::Controls.enabled? && !@failed
          unless @active
            clear if was
            return
          end
          refresh_bindings
          read_raw
          @area = current_area
          held = physical_states
          update_actions(held)
          settle unless was
        rescue Exception => e
          raise if Reloaded::Hooks.passthrough?(e)
          fail!(e)
        end

        # The state of an action this step (:press, :trigger, :repeat,
        # :release).
        def action_state(kind, id)
          st = @states[id]
          return false unless st
          case kind
          when :press   then return st[0]
          when :trigger then return st[0] && !st[1]
          when :release then return !st[0] && st[1]
          when :repeat  then return repeating?(st)
          end
          return false
        end

        # The inputs held right now on one side (:keys or :pad), read straight
        # from the keyboard or controller: the Controls screen's "Press a
        # Button". With Swap A and B, the bottom and right face buttons trade.
        def pressed_inputs(side)
          out = []
          if side.to_sym == :keys
            keys = (::Input.raw_key_states rescue nil) || []
            keys.each_with_index { |down, code| out << Inputs.key(code) if down && Inputs::KEYS[code] }
            return out
          end
          c = defined?(::Input::Controller) ? ::Input::Controller : nil
          return out unless c && (c.connected? rescue false)
          swap = Reloaded::Controls.swap_ab?
          ((c.raw_button_states rescue nil) || []).each_with_index do |down, code|
            next unless down
            code = { Inputs::PAD_A => Inputs::PAD_B, Inputs::PAD_B => Inputs::PAD_A }.fetch(code, code) if swap
            out << Inputs.pad(code)
          end
          dz = Reloaded::Controls.deadzone
          tp = Reloaded::Controls.trigger_threshold
          ((c.raw_axes rescue nil) || []).first(6).each_with_index do |v, code|
            v = v.to_f
            if code >= 4
              out << Inputs.axis(code, true) if v >= tp
            elsif v >= dz
              out << Inputs.axis(code, true)
            elsif v <= -dz
              out << Inputs.axis(code, false)
            end
          end
          return out
        end

        # The controller's button style: Button Style, or by its name (Auto).
        def style
          chosen = Inputs::STYLES[Reloaded::Settings.get(:"controls.button_style").to_i]
          return chosen if chosen && chosen != :auto
          name = (::Input::Controller.name rescue "")
          return Inputs.style_for(name)
        end

        private

        def own_method(sc, name)
          m = sc.instance_method(name)
          m = m.super_method while m && m.owner != sc
          return m
        rescue NameError
          return nil
        end

        def replace(sc, name, original, kind)
          @originals[name] = original
          layer = self
          sc.send(:define_method, name) do |*args, &block|
            ans = layer.answer(kind, args)
            next ans unless ans.nil?
            original.bind(self).call(*args, &block)
          end
          @replaced << name
        end

        def replace_update(sc, name, original)
          @originals[name] = original
          layer = self
          sc.send(:define_method, name) do |*args, &block|
            result = original.bind(self).call(*args, &block)
            Reloaded::Controls::PadLog.step     # what the engine sees of a controller (On or Off)
            layer.poll
            result
          end
          @replaced << name
        end

        def replace_text_input(sc, name, original)
          @originals[name] = original
          layer = self
          sc.send(:define_method, name) do |value|
            layer.typing = value ? true : false
            original.bind(self).call(value)
          end
          @replaced << name
        end

        def fail!(error)
          @failed = true
          @active = false
          clear
          Reloaded::Log.exception("The controls layer failed and is off for this session; the game's own controls are back", error, :controls)
        end

        def clear
          @states = {}
          @dir_order = []
          @hold = {}
          @was_down = {}
        end

        # Just switched on: buttons already held (the one that switched it
        # on, say) count as held, not as new presses.
        def settle
          @states.each_value { |st| st[1] = st[0] }
        end

        #----------------------------------------------------------------------
        # Bindings, resolved once per change
        #----------------------------------------------------------------------
        def refresh_bindings
          @steps = @steps.to_i + 1
          Inputs.engine_bindings if (@steps % CHECK_FILE_EVERY) == 0   # picks up F1 changes
          key = [Reloaded::Controls.version, Inputs.instance_variable_get(:@engine_stamp)]
          return if @resolved && @resolved_key == key
          @resolved_key = key
          @resolved = {}
          @hold_inputs = {}
          Reloaded::Controls.actions.each do |a|
            taps = []
            holds = []
            essential = a.button && Reloaded::Controls::ESSENTIAL.include?(a.id)
            Reloaded::Controls::SIDES.each do |side|
              list = Reloaded::Controls.bindings(a.id, side)
              # Never lose moving, Confirm or Back on either device: a side
              # left unbound uses the engine's (F1)
              list = (Inputs.engine_bindings[a.button] || {})[side] || [] if list.empty? && essential
              list.each do |t|
                base = Inputs.base(t)
                if Inputs.hold?(t)
                  holds << base
                  @hold_inputs[base] = true
                else
                  taps << base
                end
              end
            end
            @resolved[a.id] = [taps, holds]
          end
          @buttons = {}
          Reloaded::Controls.actions.each { |a| @buttons[a.button] = a.id if a.button }
          @parsed = {}
        end

        def read_raw
          @keys = (::Input.raw_key_states rescue nil) || []
          c = defined?(::Input::Controller) ? ::Input::Controller : nil
          connected = c && (c.connected? rescue false)
          @pad = connected ? ((c.raw_button_states rescue nil) || []) : []
          @axes = connected ? ((c.raw_axes rescue nil) || []) : []
          @swap = Reloaded::Controls.swap_ab?
          @deadzone = Reloaded::Controls.deadzone
          @trigger_at = Reloaded::Controls.trigger_threshold
        end

        def down?(token)
          p = (@parsed[token] ||= Inputs.parse(token))
          return false unless p
          kind, code, positive, _ = p
          case kind
          when :key
            return false if @typing && Inputs::TEXT_KEYS[code]
            return @keys[code] ? true : false
          when :pad
            if @swap      # Swap A and B: the bottom and right face buttons trade places
              code = { Inputs::PAD_A => Inputs::PAD_B, Inputs::PAD_B => Inputs::PAD_A }.fetch(code, code)
            end
            return @pad[code] ? true : false
          else
            v = @axes[code].to_f
            return v >= @trigger_at if code >= 4
            return positive ? v >= @deadzone : v <= -@deadzone
          end
        end

        # input => down this step, after tap and hold: [taps, holds]
        def physical_states
          @hold ||= {}
          tap = {}
          hold = {}
          hold_steps = Reloaded::Controls.hold_steps
          inputs = {}
          @resolved.each_value { |taps, holds| (taps + holds).each { |t| inputs[t] = true } }
          @was_down ||= {}
          inputs.each_key do |t|
            d = down?(t)
            note_device(t) if d && !@was_down[t]
            @was_down[t] = d
            unless @hold_inputs[t]
              tap[t] = d
              next
            end
            # an input with a hold action: tap on an early release, hold after Hold Time
            n = @hold[t].to_i
            if d
              @hold[t] = n + 1
              hold[t] = (n + 1) >= hold_steps
            else
              tap[t] = true if n > 0 && n < hold_steps
              @hold[t] = 0
            end
          end
          return [tap, hold]
        end

        def note_device(token)
          @device = Inputs.keyboard?(token) ? :keyboard : :controller
        end

        def update_actions(states)
          tap, hold = states
          @dir_order ||= []
          @resolved.each do |id, (taps, holds)|
            down = taps.any? { |t| tap[t] } || holds.any? { |t| hold[t] }
            st = (@states[id] ||= [false, false, 0])
            st[1] = st[0]
            st[0] = down
            st[2] = down ? st[2] + 1 : 0
            next unless DIRECTIONS.include?(id)
            if down && !st[1]
              @dir_order.delete(id)
              @dir_order.unshift(id)
            elsif !down
              @dir_order.delete(id)
            end
          end
        end

        def repeating?(st)
          return false unless st[0]
          return true unless st[1]
          first, every = Reloaded::Controls.repeat_timing
          held = st[2] - 1
          return held >= first && ((held - first) % every) == 0
        end

        def current_area
          t = defined?($game_temp) ? $game_temp : nil
          return :battle if t && t.respond_to?(:in_battle) && t.in_battle
          if defined?(::Scene_Map) && $scene.is_a?(::Scene_Map) && t && !(t.respond_to?(:in_menu) && t.in_menu)
            return :overworld
          end
          return :menus
        end

        public

        attr_writer :typing

        def typing?
          return @typing ? true : false
        end

        # The answer to an engine query, or nil to let the engine answer.
        def answer(kind, args)
          return nil unless @active
          case kind
          when :dir4 then return dir4
          when :dir8 then return dir8
          end
          id = (@buttons || {})[args[0]]
          return nil unless id
          return action_state(kind.to_s.chomp("?").to_sym, id)
        end

        def dir4
          d = (@dir_order || []).first
          return { :down => 2, :left => 4, :right => 6, :up => 8 }[d] || 0
        end

        def dir8
          up = action_state(:press, :up)
          down = action_state(:press, :down)
          left = action_state(:press, :left)
          right = action_state(:press, :right)
          up = down = false if up && down
          left = right = false if left && right
          return 7 if up && left
          return 9 if up && right
          return 1 if down && left
          return 3 if down && right
          return 8 if up
          return 2 if down
          return 4 if left
          return 6 if right
          return 0
        end
      end
    end
  end
end
