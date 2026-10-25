# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Speed-Up
#==============================================================================
# Roadmap topic speed-up (decided 2026-10-18; the Next feature discussion
# 2026-10-23): the old Kanto Reloaded's Speed-Up, taking over KIF's
# (F-UI-05_SpeedUp: its window title, L/R speed keys and Toggle limit).
#
#   Hold     hold the Speed-Up button for Speed-Up (Overworld) or (Battles);
#            let go and the game runs at Resting Speed
#   Toggle   each press steps the speed up to Toggle Limit, then back to 1x;
#            Next Speed and Reset Speed are their own buttons (on the map
#            with nothing open, and in battle, as KIF's L/R). Toggle Speeds:
#            Separate (the overworld and battles each keep their own) or
#            Shared. Burst Speed: held, the button runs at it until let go
#            (a tap still steps). Remember Speed keeps the toggled speeds
#            for next time.
#   Shiny Slowdown   a shiny in a wild battle or on the map drops the speed
#                    to 1x (Hold: until the button is let go)
#   Messages at 1x   message boxes run at 1x (battles keep their speed)
#
# The window title reads "Kanto Reloaded 2.0.0 · KIF 1.1.0 · PIF 6.8.2 ·
# Speed x4", and the Speed Indicator (UI/SpeedUpIndicator.rb) shows the
# speed in the top-right corner for a moment when you change it. KIF
# Settings and the Controls screen run at 2x at most (his call, 2026-10-23:
# faster, held buttons repeat too fast for the cursor).
#
# The settings are on their own page and in the Controls screen's Speed-Up
# section, with the buttons (Controls' Speed-Up, Next Speed and Reset Speed
# actions). PIF's own Speed-up rows step aside while this runs; the type and
# the Hold speeds are kept in PIF's fields, so turning this Off leaves PIF's
# speed-up as you had it.
#
# How: PIF's Graphics.update (Marin's Better Fast-forward, 052_InfiniteFusion/
# System/Spped Up.rb) draws a frame only every <speed> calls. While this
# runs it is kept at 1x, and the frames are skipped here instead, at the
# engine update it calls (fast_forward_update). If this fails, PIF's
# speed-up takes over.
#
#   Reloaded::SpeedUp.speed          # the speed now (1 to 10)
#   Reloaded::SpeedUp.slow_down      # back to 1x, as Shiny Slowdown does
#==============================================================================

module Reloaded
  module SpeedUp
    FEATURE = :speed_up
    PAGE = :speed_up
    SETTINGS_MAX = 2     # the fastest settings screens run
    TYPES = ["Hold", "Toggle"].freeze
    SPEEDS = (1..10).map { |v| "#{v}x" }      # index + 1, as PIF's own fields keep them
    LIMITS = (2..10).map { |v| "#{v}x" }      # index + 2
    BURSTS = ["Off"] + LIMITS
    # PIF's rows in KIF Settings that this takes the place of
    PIF_ROWS = ["Speed-up type", "Speed-up (Overworld)", "Speed-up (Battles)"].freeze
    # The settings, in the order the Controls screen lists them
    KEYS = [:"speed_up.type", :"speed_up.overworld", :"speed_up.battles", :"speed_up.resting",
            :"speed_up.toggle_limit", :"speed_up.toggle_speeds", :"speed_up.burst", :"speed_up.remember",
            :"speed_up.shiny_slowdown", :"speed_up.messages", :"speed_up.indicator"].freeze

    @speed = 1           # the speed now, as the frames are drawn
    @chosen = 1          # the speed you set (what the indicator shows)
    @toggled = { :overworld => 1, :battles => 1 }
    @frame = 0
    @holding = false
    @was_pressed = false
    @pressed_at = nil
    @bursting = false
    @blocked = false     # Shiny Slowdown in Hold: until the button is let go
    @paused = 0          # settings screens open
    @messages = 0        # message boxes open
    @title = nil

    class << self
      attr_reader :chosen

      def boot
        register_settings
        # PIF's Better Fast-forward has to be there (it hands each frame to the
        # engine's update as fast_forward_update); without it PIF's own
        # speed-up stays, and so does KIF's
        unless defined?(::Graphics) && defined?(::Input) && ::Graphics.respond_to?(:fast_forward_update)
          Reloaded::Log.warning("Speed-Up stays off: PIF's Better Fast-forward (Graphics.fast_forward_update) isn't there", :speed_up) if defined?(::Graphics)
          return true
        end
        Reloaded::Features.register(FEATURE, :name => "Speed-Up", :page => PAGE, :order => 27,
          :takes_over => ["F-UI-05_SpeedUp"],
          :description => "Hold or toggle the game's speed, with a speed in the window title and a corner indicator. Off brings back KIF's.")
        restore_speeds
        install
        Reloaded::Events.on(:feature_changed, :speed_up_title, 50) { |e| left if e[:id] == FEATURE && e[:state] == :off }
        return true
      end

      def on?
        return Reloaded::Features.on?(FEATURE)
      end

      def setting(id)
        return Reloaded::Settings.get(:"speed_up.#{id}")
      end

      def toggle?
        return setting(:type).to_i == 1
      end

      def in_battle?
        t = $game_temp
        return t && t.respond_to?(:in_battle) && t.in_battle ? true : false
      end

      # The speed now (2x at most while a settings screen is open; 1x while,
      # with Messages at 1x, a message box is)
      def speed
        return @speed
      end

      def limit
        return setting(:toggle_limit).to_i + 2
      end

      # Burst Speed, or nil while it's Off
      def burst
        i = setting(:burst).to_i
        return i > 0 ? i + 1 : nil
      end

      # Whose toggled speed applies here: the battles' (Separate, in a
      # battle) or the overworld's
      def side
        return in_battle? && setting(:toggle_speeds).to_i == 0 ? :battles : :overworld
      end

      def toggled(where = side)
        return [@toggled[where].to_i, 1].max.clamp(1, limit)
      end

      # Sets a toggled speed (the Overworld Menu's row, the buttons)
      def set_toggled(value, where = side)
        @toggled[where] = value.to_i.clamp(1, limit)
        remember
        return @toggled[where]
      end

      # The speed you set, before settings screens' cap and the messages' 1x
      def chosen_speed
        if toggle?
          return burst if @bursting && burst
          return toggled
        end
        return setting(in_battle? ? :battles : :overworld).to_i + 1 if @holding
        return setting(:resting).to_i + 1
      end

      # Back to 1x: the toggled speed here, or (Hold) until the button is
      # let go. Shiny Slowdown calls it; so can other mods.
      def slow_down
        return unless on?
        @bursting = false
        if toggle?
          set_toggled(1)
        else
          @blocked = true
          @holding = false
        end
        step
      end

      # Settings screens run at SETTINGS_MAX at most while open
      def paused
        @paused += 1
        return yield
      ensure
        @paused -= 1
      end

      def paused?
        return @paused > 0
      end

      #------------------------------------------------------------------------
      # Each frame
      #------------------------------------------------------------------------
      # Once per Input.update: the buttons
      def read_input
        if $CanToggle == false
          # disallowed (an event's pbDisallowSpeedup): the buttons do
          # nothing, and a press already held counts no more
          @holding = @bursting = @was_pressed = false
          return
        end
        pressed = press?(:speed_up, :X)
        @blocked = false unless pressed
        @held_since = pressed ? (@held_since || clock) : nil
        if toggle?
          @holding = false
          read_toggle(pressed)
        else
          @bursting = false
          @holding = pressed && !@blocked
        end
        @was_pressed = pressed
      end

      # Once per Graphics.update: the speed, the title and the indicator
      def step
        @chosen = chosen_speed
        now = @messages > 0 && setting(:messages) ? 1 : @chosen
        now = [now, SETTINGS_MAX].min if paused?
        @speed = now
        update_title
        basis = indicator_speed
        indicate(paused? ? [basis, SETTINGS_MAX].min : basis, basis)
      end

      # The speed the Speed Indicator goes by: the speed you set, but in
      # Hold only once the button has been held for Controls' Hold Time (his
      # call, 2026-10-23: a quick X in a menu, Summary say, doesn't flash it)
      def indicator_speed
        return @chosen if toggle? || !@holding
        return @chosen if @held_since && clock - @held_since >= hold_seconds
        return setting(:resting).to_i + 1
      end

      # Called where PIF's speed-up would draw a frame: whether to draw it
      def draw?
        @frame += 1
        return false if @frame < @speed
        @frame = 0
        return true
      end

      def title_text
        kif = defined?(::KIF::PORT_VERSION) ? " · KIF #{::KIF::PORT_VERSION}" : ""
        pif = defined?(::Settings::GAME_VERSION_NUMBER) ? " · PIF #{::Settings::GAME_VERSION_NUMBER}" : ""
        return "Kanto Reloaded #{Reloaded.version}#{kif}#{pif} · Speed x#{@speed}"
      end

      private

      def register_settings
        s = Reloaded::Settings
        s.register_page(PAGE, :group => :general, :name => "Speed-Up", :icon => :controls, :priority => 31,
          :feature => FEATURE,
          :description => "How fast the game runs: Hold or Toggle, the speeds, and what slows it down. Also in Controls' Speed-Up section.")
        hold_only = proc { toggle? ? _INTL("Hold Only") : nil }
        toggle_only = proc { toggle? ? nil : _INTL("Toggle Only") }
        s.register(:"speed_up.type", :page => PAGE, :priority => 10, :type => :enum, :default => 0, :values => TYPES,
          :name => "Speed-Up Type", :bind => Reloaded::Settings::Bind.system(:speedup),
          :descriptions => ["Hold the Speed-Up button to go faster; let go for Resting Speed.",
                            "Press the Speed-Up button to step through the speeds, up to Toggle Limit."],
          :description => "Hold the Speed-Up button to go faster, or press it to step through the speeds.")
        s.register(:"speed_up.overworld", :page => PAGE, :priority => 20, :type => :enum, :values => SPEEDS,
          :default => 3, :name => "Speed-Up (Overworld)", :soft_lock => hold_only,
          :bind => Reloaded::Settings::Bind.system(:speedup_speed),
          :description => "How fast the game runs while you hold the Speed-Up button, outside battle.")
        s.register(:"speed_up.battles", :page => PAGE, :priority => 30, :type => :enum, :values => SPEEDS,
          :default => 3, :name => "Speed-Up (Battles)", :soft_lock => hold_only,
          :bind => Reloaded::Settings::Bind.system(:speedup_speed_battles),
          :description => "How fast the game runs while you hold the Speed-Up button, in battle.")
        s.register(:"speed_up.resting", :page => PAGE, :priority => 40, :type => :enum, :values => SPEEDS,
          :default => 0, :name => "Resting Speed", :soft_lock => hold_only,
          :description => "How fast the game runs when you aren't holding the Speed-Up button. 1x is normal speed.")
        s.register(:"speed_up.toggle_limit", :page => PAGE, :priority => 50, :type => :enum, :values => LIMITS,
          :default => 3, :name => "Toggle Limit", :soft_lock => toggle_only,
          :description => "The fastest speed the Speed-Up button steps up to before going back to 1x.")
        s.register(:"speed_up.toggle_speeds", :page => PAGE, :priority => 60, :type => :enum, :default => 0,
          :values => ["Separate", "Shared"], :name => "Toggle Speeds", :soft_lock => toggle_only,
          :descriptions => ["The overworld and battles each remember their own speed, and switch to it as a battle starts and ends.",
                            "One speed for both."],
          :description => "Whether the overworld and battles keep their own toggled speed.")
        s.register(:"speed_up.burst", :page => PAGE, :priority => 70, :type => :enum, :default => BURSTS.length - 1,
          :values => BURSTS, :name => "Burst Speed", :soft_lock => toggle_only,
          :description => "Hold the Speed-Up button to run at this speed until you let go; a tap still steps through the speeds. Off: Each press steps at once.")
        s.register(:"speed_up.remember", :page => PAGE, :priority => 80, :type => :toggle, :default => true,
          :name => "Remember Speed", :soft_lock => toggle_only,
          :description => "The toggled speeds stay as you left them the next time you play. Off: The game starts at 1x.")
        s.register(:"speed_up.shiny_slowdown", :page => PAGE, :priority => 90, :type => :toggle, :default => true,
          :name => "Shiny Slowdown",
          :description => "When a shiny appears, in a wild battle or on the map, the speed drops to 1x so you don't fly past it.")
        s.register(:"speed_up.messages", :page => PAGE, :priority => 100, :type => :toggle, :default => false,
          :name => "Messages at 1x",
          :description => "Message boxes (talking, signs, items) run at 1x so you can read them. Battles keep their speed.")
        s.register(:"speed_up.indicator", :page => PAGE, :priority => 110, :type => :toggle, :default => true,
          :name => "Speed Indicator",
          :description => "A small box in the top-right corner shows the speed for a moment when you change it.")
        # the toggled speeds Remember Speed keeps (not shown)
        [:saved_overworld, :saved_battles].each_with_index do |id, i|
          s.register(:"speed_up.#{id}", :page => PAGE, :priority => 900 + i, :type => :number, :min => 1, :max => 10,
            :default => 1, :preset => false, :visible => proc { false }, :name => id.to_s)
        end
      end

      def install
        h = Reloaded::Hooks
        h.prepend(FEATURE, ::Graphics.singleton_class, GraphicsHook, :id => :speed_up_frames)
        h.prepend(FEATURE, ::Input.singleton_class, InputHook, :id => :speed_up_buttons)
        h.needs(:field, :speedup, :id => :speed_up_type)
        # KIF's title and L/R keys stay quiet while this runs (its module
        # steps aside too; this makes sure the title is ours)
        if defined?(::KIF::SpeedTitle)
          [:update_title, :check_keys].each do |m|
            next unless ::KIF::SpeedTitle.respond_to?(m)
            h.around(FEATURE, ::KIF::SpeedTitle.singleton_class, m, :id => :"speed_up_kif_#{m}") { |_original, *_args| nil }
          end
        end
        # settings screens at 2x at most
        screens = [["PokemonOptionScreen", :pbStartScreen], ["KifSettingsScreen", :main]]
        screens << [Reloaded::SettingsScreen, :main] if defined?(Reloaded::SettingsScreen)
        screens << [Reloaded::ControlsScreen, :main] if defined?(Reloaded::ControlsScreen)
        screens.each_with_index do |(target, m), i|
          next if target.is_a?(String) && !has?(target, m)
          h.around(FEATURE, target, m, :id => :"speed_up_paused_#{i}") { |original, *args| paused { original.call(*args) } }
        end
        # message boxes, for Messages at 1x
        if Object.private_method_defined?(:pbMessageDisplay) || Object.method_defined?(:pbMessageDisplay)
          h.around(FEATURE, Object, :pbMessageDisplay, :id => :speed_up_messages) do |original, *args|
            @messages += 1
            begin
              original.call(*args)
            ensure
              @messages -= 1
            end
          end
        end
        # Shiny Slowdown: a wild shiny at the start of a battle, or on the map
        if has?("PokeBattle_Battle", :pbStartBattleSendOut)
          h.around(FEATURE, "PokeBattle_Battle", :pbStartBattleSendOut, :id => :speed_up_shiny_battle) do |original, *args|
            b = original.receiver
            shiny_slowdown if b.wildBattle? && b.pbParty(1).any? { |pk| pk && pk.shiny? }
            original.call(*args)
          end
        end
        if has?("OverworldPokemonEvent", :setup_pokemon)
          h.around(FEATURE, "OverworldPokemonEvent", :setup_pokemon, :id => :speed_up_shiny_map) do |original, *args|
            ret = original.call(*args)
            pk = original.receiver.instance_variable_get(:@pokemon)
            shiny_slowdown if pk && pk.shiny?
            ret
          end
        end
        # PIF's Speed-up rows in KIF Settings: these take their place
        if defined?(::KIF::SettingsScreen) && ::KIF::SettingsScreen.respond_to?(:pif_items)
          h.around(FEATURE, ::KIF::SettingsScreen.singleton_class, :pif_items, :id => :speed_up_pif_rows) do |original, *args|
            items, extra, root = original.call(*args)
            [items.reject { |it| PIF_ROWS.include?(it[:name]) }, extra, root]
          end
        end
      end

      def shiny_slowdown
        slow_down if setting(:shiny_slowdown)
      end

      # A class of the game's with that method (PIF's battles, Hoenn's
      # overworld Pokémon), so a hook on it isn't made for nothing
      def has?(name, method)
        return false unless Object.const_defined?(name)
        k = Object.const_get(name)
        return k.method_defined?(method) || k.private_method_defined?(method)
      end

      # A button's state: its Controls action (Reloaded Controls' binding,
      # or the game button it follows), else the game button
      def press?(id, button)
        c = Reloaded::Controls
        return c.press?(id) if c.action(id)
        return ::Input.press?(::Input.const_get(button))
      end

      def trigger?(id, button)
        c = Reloaded::Controls
        return c.trigger?(id) if c.action(id)
        return ::Input.trigger?(::Input.const_get(button))
      end

      # Toggle: a press steps (with Burst Speed: a tap steps when let go, a
      # hold bursts); Next Speed and Reset Speed where KIF allowed L and R
      def read_toggle(pressed)
        b = burst
        if pressed && !@was_pressed
          @pressed_at = clock
          step_toggled unless b
        elsif pressed && b && !@bursting && !@blocked && @pressed_at && clock - @pressed_at >= hold_seconds
          @bursting = true
        elsif !pressed && @was_pressed
          step_toggled if b && !@bursting && !@blocked
          @bursting = false
        end
        reset = trigger?(:reset_speed, :R)
        nxt = !reset && trigger?(:next_speed, :L)
        return unless (reset || nxt) && keys_allowed?
        reset ? set_toggled(1) : step_toggled
      end

      def step_toggled
        v = toggled + 1
        set_toggled(v > limit ? 1 : v)
      end

      # Controls' Hold Time
      def hold_seconds
        return Reloaded::Controls::HOLD_SECONDS[Reloaded::Settings.get(:"controls.hold_time").to_i] || 0.4
      rescue StandardError
        return 0.4
      end

      def clock
        return Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      # The map with nothing open, or any battle (menus use L and R)
      def keys_allowed?
        t = $game_temp
        return false unless t
        return true if in_battle?
        return false unless defined?(::Scene_Map) && $scene.is_a?(::Scene_Map)
        return false if (t.respond_to?(:in_menu) && t.in_menu) || (t.respond_to?(:message_window_showing) && t.message_window_showing)
        return false if t.respond_to?(:moving_furniture) && t.moving_furniture
        gs = $game_system
        return false if gs && gs.respond_to?(:map_interpreter) && gs.map_interpreter && gs.map_interpreter.running?
        return true
      end

      # Remember Speed: the toggled speeds, kept in the settings file
      def remember
        return unless setting(:remember)
        s = Reloaded::Settings
        s.set(:"speed_up.saved_overworld", @toggled[:overworld], true)
        s.set(:"speed_up.saved_battles", @toggled[:battles], true)
      end

      def restore_speeds
        return unless setting(:remember)
        @toggled[:overworld] = setting(:saved_overworld).to_i
        @toggled[:battles] = setting(:saved_battles).to_i
      end

      # The Speed Indicator says the speed running (in a settings screen, its
      # 2x cap; Messages at 1x aside). It shows when the speed you set
      # changes (indicator_speed: Hold counts once held for Hold Time);
      # opening or closing a settings screen only brings a box already
      # showing up to date.
      def indicate(shown, basis = shown)
        ind = defined?(Reloaded::SpeedUpIndicator) ? Reloaded::SpeedUpIndicator : nil
        return unless ind
        if @last_shown.nil? || paused? != @was_paused
          ind.sync(shown)
        elsif basis != @last_chosen || shown != @last_shown
          ind.show(shown)
        else
          ind.update
        end
        @last_chosen = basis
        @last_shown = shown
        @was_paused = paused?
      end

      def update_title
        return if @title == @speed
        @title = @speed
        ::System.set_window_title(title_text) if defined?(::System) && ::System.respond_to?(:set_window_title)
      end

      # Turned Off: KIF's title comes back on its next look
      def left
        @title = @last_shown = nil
        @speed = @chosen = 1
        Reloaded::SpeedUpIndicator.hide if defined?(Reloaded::SpeedUpIndicator)
        st = defined?(::KIF::SpeedTitle) ? ::KIF::SpeedTitle : nil
        st.instance_variable_set(:@last_key, nil) if st
      end
    end

    # Graphics.update: the speed, then PIF's update kept at 1x (no input of
    # its own: $CanToggle off for the call, its stage 0); the frames are
    # skipped at the engine update PIF calls.
    module GraphicsHook
      def update(*args)
        return super unless Reloaded::Features.on?(Reloaded::SpeedUp::FEATURE)
        Reloaded::Hooks.guard(Reloaded::SpeedUp::FEATURE, "speed_up_step") { Reloaded::SpeedUp.step }
        can = $CanToggle
        $CanToggle = false
        $GameSpeed = 0
        begin
          return super
        ensure
          $CanToggle = can
        end
      end

      def fast_forward_update(*args)
        return super unless Reloaded::Features.on?(Reloaded::SpeedUp::FEATURE)
        return nil unless Reloaded::SpeedUp.draw?
        super
      end
    end

    # Input.update: the speed buttons, once per game step
    module InputHook
      def update(*args)
        ret = super
        if Reloaded::Features.on?(Reloaded::SpeedUp::FEATURE)
          Reloaded::Hooks.guard(Reloaded::SpeedUp::FEATURE, "speed_up_buttons") { Reloaded::SpeedUp.read_input }
        end
        return ret
      end
    end
  end
end
