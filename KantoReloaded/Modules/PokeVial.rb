#==============================================================================
# Kanto Reloaded - PokeVial
#==============================================================================
# Limited-use party healing for KIF's pause menu and KR Overworld Menu.
# The module owns no items, reward handlers, grant APIs, or shared callbacks.
#==============================================================================

module KantoReloaded
  module PokeVial
    SAVE_SYSTEM = :poke_vial

    SETTINGS_ACTION = :poke_vial_settings
    ENABLED_SETTING = :poke_vial_enabled
    PROGRESSIVE_SETTING = :poke_vial_progressive
    MAX_USES_SETTING = :poke_vial_max_uses
    HEAL_MODE_SETTING = :poke_vial_heal_mode
    COOLDOWN_SETTING = :poke_vial_cooldown
    COOLDOWN_TIME_SETTING = :poke_vial_cooldown_time
    REFILL_MODE_SETTING = :poke_vial_refill_mode
    REFILL_COST_SETTING = :poke_vial_refill_cost
    COST_PER_CHARGE_SETTING = :poke_vial_cost_per_charge

    DEFAULT_MAX_USES = 3
    MAX_USES_CAP = 5
    DEFAULT_REFILL_COST = 500
    COOLDOWN_MINUTES = [5, 10, 15, 20, 25, 30, 35, 40, 45].freeze
    REFILL_MODES = [:ask, :automatic, :never].freeze
    BLOCKED_MAP_IDS = [
      304, 306, 307,
      315, 316, 317, 318, 328, 343,
      720, 722, 723, 724,
      776, 777, 778, 779, 780, 781, 782, 783, 784
    ].freeze

    @recover_all_depth = 0
    @healing_from_vial = false
    @refill_prompt_active = false
    @progression_step_event_registered = false unless
      instance_variable_defined?(:@progression_step_event_registered)

    class << self
      def install
        register_settings
        register_overworld_menu
        hooks_ready = register_hooks
        events_ready = register_events
        clamp_uses
        initialize_progressive_capacity
        if defined?(KantoReloaded::Log)
          state = hooks_ready && events_ready ? "ready" : "unavailable"
          KantoReloaded::Log.info(
            "Installed PokeVial module (hooks #{state})",
            :modules
          )
        end
        hooks_ready && events_ready
      rescue StandardError => e
        KantoReloaded::Log.exception(
          "PokeVial install failed", e, channel: :modules
        ) if defined?(KantoReloaded::Log)
        false
      end

      def enabled?
        truthy_setting(ENABLED_SETTING, 1)
      end

      def progressive?
        truthy_setting(PROGRESSIVE_SETTING, 1)
      end

      def hp_only?
        KantoReloaded::Settings.get(HEAL_MODE_SETTING, 0).to_i == 1
      rescue StandardError
        false
      end

      def cooldown_enabled?
        truthy_setting(COOLDOWN_SETTING, 0)
      end

      def refill_cost_enabled?
        truthy_setting(REFILL_COST_SETTING, 0)
      end

      def refill_mode
        index = KantoReloaded::Settings.get(REFILL_MODE_SETTING, 0).to_i
        index = [[index, 0].max, REFILL_MODES.length - 1].min
        REFILL_MODES[index]
      rescue StandardError
        :ask
      end

      def configured_max_uses
        value = if progressive?
                  1 + (badge_count / 2)
                else
                  KantoReloaded::Settings.get(
                    MAX_USES_SETTING, DEFAULT_MAX_USES
                  ).to_i
                end
        [[value, 1].max, MAX_USES_CAP].min
      rescue StandardError
        DEFAULT_MAX_USES
      end

      def uses
        maximum = configured_max_uses
        value = state_get(:uses, nil)
        if value.nil?
          state_set(:uses, maximum)
          return maximum
        end
        clamped = [[value.to_i, 0].max, maximum].min
        state_set(:uses, clamped) if clamped != value.to_i
        clamped
      rescue StandardError
        0
      end

      def status_text
        return "" unless enabled?
        remaining = cooldown_remaining_seconds
        return "CD #{format_time(remaining)}" if remaining > 0
        return "Empty" if uses <= 0
        "#{uses}/#{configured_max_uses}"
      rescue StandardError
        ""
      end

      def status_color
        return Color.new(235, 80, 80) if uses <= 0
        return Color.new(255, 205, 90) if cooldown_remaining_seconds > 0
        maximum = configured_max_uses
        return Color.new(255, 205, 90) if maximum > 0 && uses * 100 / maximum <= 35
        Color.new(120, 230, 150)
      rescue StandardError
        nil
      end

      def pause_label
        text = pause_status_text
        text.empty? ? _INTL("PokeVial") : _INTL("PokeVial ({1})", text)
      end

      def pause_status_text
        return "" unless enabled?
        return "0" if uses <= 0
        "#{uses}/#{configured_max_uses}"
      rescue StandardError
        ""
      end

      def use_from_pause_menu
        use(:pause_menu, proc { |message|
          KantoReloaded::PopupWindow.message(message)
        })
      end

      def use_from_overworld_menu(screen)
        choice = if screen && screen.respond_to?(:show_popup_menu)
                   screen.show_popup_menu("POKEVIAL", ["Use PokeVial", "Back"])
                 else
                   KantoReloaded::PopupWindow.choice(
                     _INTL("Use the PokeVial?"),
                     [
                       { :label => _INTL("Use PokeVial"), :value => :use },
                       { :label => _INTL("Back"), :value => :back }
                     ]
                   )
                 end
        return false unless choice == 0 || choice == :use
        popup = proc do |message|
          if screen && screen.respond_to?(:show_popup)
            screen.show_popup("POKEVIAL", [message])
          else
            KantoReloaded::PopupWindow.message(message)
          end
        end
        use(:overworld_menu, popup)
      end

      def adapt_pause_commands(commands)
        original = Array(commands)
        display = []
        mapping = []
        replaced = false

        original.each_with_index do |command, index|
          if heal_command?(command)
            display << pause_label
            mapping << :poke_vial
            replaced = true
          else
            display << command
            mapping << index
          end
        end

        unless replaced
          insertion = pause_insertion_index(original)
          display.insert(insertion, pause_label)
          mapping.insert(insertion, :poke_vial)
        end
        [display, mapping]
      end

      def handle_pause_selection(hook, commands, arguments)
        return hook.call(commands, *arguments) unless enabled? && party_ready?
        loop do
          display, mapping = adapt_pause_commands(commands)
          selected = hook.call(display, *arguments)
          return selected if selected.nil? || selected.to_i < 0
          mapped = mapping[selected.to_i]
          unless mapped == :poke_vial
            return mapped.nil? ? selected : mapped
          end
          use_from_pause_menu
        end
      end

      def with_recover_all_context
        @recover_all_depth = @recover_all_depth.to_i + 1
        yield
      ensure
        @recover_all_depth = [@recover_all_depth.to_i - 1, 0].max
      end

      def after_native_party_heal
        return false unless enabled?
        return false if @healing_from_vial
        return false unless @recover_all_depth.to_i > 0
        return false unless pokemon_center_map?
        sync_progressive_capacity
        prompt_pokemon_center_refill
      rescue StandardError => e
        KantoReloaded::Log.exception(
          "PokeVial center refill check failed", e, channel: :modules
        ) if defined?(KantoReloaded::Log)
        false
      end

      def sync_progressive_capacity(notify = true)
        return false unless progressive?
        return false unless trainer_ready?
        maximum = configured_max_uses
        seen = state_get(:progressive_max_seen, nil)
        if seen.nil?
          state_set(:progressive_max_seen, maximum)
          return false
        end
        seen = [[seen.to_i, 1].max, MAX_USES_CAP].min
        return false if maximum <= seen

        current = state_get(:uses, nil)
        current = seen if current.nil?
        current = [[current.to_i, 0].max, maximum].min
        target = [current + (maximum - seen), maximum].min
        gained = target - current
        return false unless state_set(:uses, target)
        return false unless state_set(:progressive_max_seen, maximum)

        if notify && defined?(KantoReloaded::Toast)
          KantoReloaded::Toast.success(
            _INTL(
              "PokeVial capacity increased to {1}. Added {2} {3}.",
              maximum, gained, charge_word(gained)
            )
          )
        end
        KantoReloaded::Log.info(
          "PokeVial capacity increased #{seen}->#{maximum} charges_added=#{gained}",
          :modules
        ) if defined?(KantoReloaded::Log)
        true
      rescue StandardError => e
        KantoReloaded::Log.exception(
          "PokeVial progression sync failed", e, channel: :modules
        ) if defined?(KantoReloaded::Log)
        false
      end

      private

      def register_settings
        return false unless defined?(KantoReloaded::Settings)
        register_settings_action
        register_module_settings
        KantoReloaded::Settings.register_on_change(
          PROGRESSIVE_SETTING,
          :poke_vial_progressive_capacity,
          :owner => :poke_vial
        ) do |_value|
          KantoReloaded::PokeVial.send(:clamp_uses)
          KantoReloaded::PokeVial.sync_progressive_capacity
        end
        KantoReloaded::Settings.register_on_change(
          MAX_USES_SETTING,
          :poke_vial_manual_capacity,
          :owner => :poke_vial
        ) do |_value|
          KantoReloaded::PokeVial.send(:clamp_uses)
        end
        true
      end

      def register_settings_action
        KantoReloaded::Settings.register(SETTINGS_ACTION, {
          :name => "PokeVial",
          :description => "Configure PokeVial charges, healing, cooldown, and refills.",
          :type => :button,
          :category => :quality_of_life,
          :owner => :kanto_reloaded,
          :priority => 95,
          :on_press => proc {
            KantoReloaded::SettingsUI.open_module(:poke_vial)
          }
        })
      end

      def register_module_settings
        module_visible = proc do |context|
          next false unless context.is_a?(Hash)
          module_id = context[:module] || context["module"]
          owner_id = context[:owner] || context["owner"]
          (module_id || owner_id).to_sym == :poke_vial
        rescue StandardError
          false
        end
        definitions = [
          [ENABLED_SETTING, {
            :name => "PokeVial",
            :description => "Replaces KIF's Heal Pokemon pause command with limited PokeVial healing.",
            :type => :toggle, :default => 1, :priority => 10
          }],
          [PROGRESSIVE_SETTING, {
            :name => "Progressive Uses",
            :description => "Raises maximum charges by one for every two Badges, up to five.",
            :type => :toggle, :default => 1, :priority => 20
          }],
          [MAX_USES_SETTING, {
            :name => "Max Uses",
            :description => "Maximum charges when Progressive Uses is off.",
            :type => :slider, :default => DEFAULT_MAX_USES,
            :minimum => 1, :maximum => MAX_USES_CAP, :step => 1,
            :enabled_if => proc { !KantoReloaded::PokeVial.progressive? },
            :priority => 30
          }],
          [HEAL_MODE_SETTING, {
            :name => "Heal Mode",
            :description => "Full Heal restores HP, status, and PP. HP Only restores HP.",
            :type => :enum, :values => ["Full Heal", "HP Only"],
            :default => 0, :priority => 40
          }],
          [COOLDOWN_SETTING, {
            :name => "Cooldown",
            :description => "Requires real time to pass between PokeVial uses.",
            :type => :toggle, :default => 0, :priority => 50
          }],
          [COOLDOWN_TIME_SETTING, {
            :name => "Cooldown Time",
            :description => "Real-time delay between PokeVial uses.",
            :type => :enum,
            :values => COOLDOWN_MINUTES.map { |minutes| "#{minutes} min" },
            :default => 0,
            :enabled_if => proc { KantoReloaded::PokeVial.cooldown_enabled? },
            :priority => 60
          }],
          [REFILL_MODE_SETTING, {
            :name => "PokeCenter Refill",
            :description => "Ask before refilling, refill automatically, or never refill at PokeCenters.",
            :type => :enum, :values => ["Ask", "Automatic", "Never"],
            :default => 0, :priority => 70
          }],
          [REFILL_COST_SETTING, {
            :name => "PokeCenter Cost",
            :description => "Charges money for each missing charge restored at a PokeCenter.",
            :type => :toggle, :default => 0, :priority => 80
          }],
          [COST_PER_CHARGE_SETTING, {
            :name => "Cost Per Charge",
            :description => "Price of each missing PokeVial charge during a PokeCenter refill.",
            :type => :slider, :default => DEFAULT_REFILL_COST,
            :minimum => 0, :maximum => 5000, :step => 100,
            :enabled_if => proc { KantoReloaded::PokeVial.refill_cost_enabled? },
            :priority => 90
          }]
        ]
        definitions.each do |key, data|
          options = data.merge(
            :category => :quality_of_life,
            :owner => :poke_vial,
            :value_style => :integer,
            :visible_if => module_visible
          )
          KantoReloaded::Settings.register(key, options)
        end
      end

      def register_overworld_menu
        return false unless defined?(OverworldMenu) && OverworldMenu.respond_to?(:register)
        OverworldMenu.register(:poke_vial,
          :label => "PokeVial",
          :priority => 7,
          :default_enabled => true,
          :condition => proc {
            KantoReloaded::PokeVial.enabled? &&
              KantoReloaded::PokeVial.send(:party_ready?)
          },
          :status => proc { KantoReloaded::PokeVial.status_text },
          :status_color => proc { KantoReloaded::PokeVial.status_color },
          :handler => proc { |screen|
            KantoReloaded::PokeVial.use_from_overworld_menu(screen)
          }
        )
      end

      def register_hooks
        return false unless defined?(KantoReloaded::Hooks)
        results = []

        if defined?(PokemonPauseMenu_Scene)
          results << KantoReloaded::Hooks.wrap(
            PokemonPauseMenu_Scene,
            :pbShowCommands,
            :poke_vial_pause_menu
          ) do |hook, commands, *arguments|
            KantoReloaded::PokeVial.handle_pause_selection(
              hook, commands, arguments
            )
          end
        else
          results << false
        end

        if defined?(Interpreter)
          results << KantoReloaded::Hooks.wrap(
            Interpreter,
            :command_314,
            :poke_vial_recover_all
          ) do |hook, *_arguments|
            parameters = instance_variable_get(:@parameters)
            if Array(parameters)[0].to_i == 0
              KantoReloaded::PokeVial.with_recover_all_context { hook.call }
            else
              hook.call
            end
          end
        else
          results << false
        end

        if defined?(Trainer)
          results << KantoReloaded::Hooks.wrap(
            Trainer,
            :heal_party,
            :poke_vial_center_refill
          ) do |hook, *_arguments|
            result = hook.call
            KantoReloaded::PokeVial.after_native_party_heal
            result
          end
        else
          results << false
        end

        results.all?
      end

      def register_events
        kr_events_ready = register_save_events
        step_event_ready = register_progression_step_event
        kr_events_ready && step_event_ready
      end

      def register_save_events
        return false unless defined?(KantoReloaded::Events)
        KantoReloaded::Events.on(
          :kanto_reloaded_save_loaded,
          :poke_vial_progression_initialize,
          :priority => 180
        ) do |_context|
          KantoReloaded::PokeVial.send(:initialize_progressive_capacity)
        end
        KantoReloaded::Events.on(
          :kanto_reloaded_save_new_game,
          :poke_vial_progression_initialize,
          :priority => 180
        ) do |_context|
          KantoReloaded::PokeVial.send(:initialize_progressive_capacity)
        end
        true
      end

      def register_progression_step_event
        return false unless defined?(::Events) &&
          ::Events.respond_to?(:onStepTaken)
        return true if @progression_step_event_registered
        @progression_step_event_handler = proc do |_sender, _event|
          KantoReloaded::PokeVial.sync_progressive_capacity
        end
        ::Events.onStepTaken += @progression_step_event_handler
        @progression_step_event_registered = true
        true
      end

      def use(source, popup)
        return deny(lock_reason, popup) unless selectable?
        sync_progressive_capacity
        return deny(_INTL("The PokeVial is empty. Visit a PokeCenter to refill it."), popup) if uses <= 0
        remaining = cooldown_remaining_seconds
        if remaining > 0
          return show_cooldown_popup
        end
        unless party_needs_healing?
          return deny(_INTL("Your party does not need healing."), popup, false)
        end

        @healing_from_vial = true
        healed = heal_party
        return deny(
          _INTL("The PokeVial could not heal your party."),
          popup,
          true,
          :error
        ) unless healed
        set_uses(uses - 1)
        record_use_time
        play_healing_sound
        message = _INTL("Your party was healed. Charges: {1}/{2}.",
                        uses, configured_max_uses)
        KantoReloaded::Toast.success(message)
        KantoReloaded::Log.info(
          "PokeVial used source=#{source} charges=#{uses}/#{configured_max_uses}",
          :modules
        ) if defined?(KantoReloaded::Log)
        true
      rescue StandardError => e
        KantoReloaded::Log.exception(
          "PokeVial use failed", e, channel: :modules
        ) if defined?(KantoReloaded::Log)
        deny(
          _INTL("The PokeVial cannot be used right now."),
          popup,
          true,
          :error
        )
      ensure
        @healing_from_vial = false
      end

      def heal_party
        return false unless party_ready?
        party.each do |pokemon|
          next unless pokemon
          hp_only? ? pokemon.heal_HP : pokemon.heal
        end
        true
      end

      def party_needs_healing?
        party.any? do |pokemon|
          next false unless pokemon && !pokemon.egg?
          next pokemon.hp < pokemon.totalhp if hp_only?
          pokemon.hp < pokemon.totalhp ||
            pokemon.status != :NONE ||
            pokemon.moves.any? { |move| move && move.pp < move.total_pp }
        end
      rescue StandardError
        false
      end

      def selectable?
        return false unless enabled? && party_ready?
        return false if blocked_map?
        return false if restricted_state?
        true
      rescue StandardError
        false
      end

      def lock_reason
        return _INTL("PokeVial is turned off.") unless enabled?
        return _INTL("You do not have any Pokemon yet.") unless party_ready?
        return _INTL("The PokeVial cannot be used on this map.") if blocked_map?
        _INTL("The PokeVial cannot be used right now.")
      end

      def deny(message, popup, buzzer = true, theme = :warning)
        pbPlayBuzzerSE if buzzer && defined?(pbPlayBuzzerSE)
        if defined?(KantoReloaded::Toast) &&
           KantoReloaded::Toast.respond_to?(theme)
          KantoReloaded::Toast.public_send(theme, message)
        else
          popup.call(message)
        end
        false
      rescue StandardError
        false
      end

      def show_cooldown_popup
        pbPlayBuzzerSE if defined?(pbPlayBuzzerSE)
        text_source = proc do
          _INTL(
            "PokeVial cooldown active.\nReady in {1}.",
            format_time(cooldown_remaining_seconds)
          )
        end
        if KantoReloaded::PopupWindow.respond_to?(:dynamic_message)
          KantoReloaded::PopupWindow.dynamic_message(
            text_source,
            :theme => :warning,
            :width => 280,
            :center_text => true,
            :close_if => proc { cooldown_remaining_seconds <= 0 }
          )
        else
          KantoReloaded::Toast.warning(text_source.call)
        end
        false
      rescue StandardError => e
        KantoReloaded::Log.exception(
          "PokeVial cooldown popup failed", e, channel: :modules
        ) if defined?(KantoReloaded::Log)
        false
      end

      def party
        return [] unless defined?($Trainer) && $Trainer
        Array($Trainer.party)
      end

      def party_ready?
        !party.empty?
      end

      def blocked_map?
        return false if File.exist?("DemICE.krs")
        BLOCKED_MAP_IDS.include?(current_map_id)
      rescue StandardError
        false
      end

      def restricted_state?
        return true if defined?(pbInSafari?) && pbInSafari?
        return true if defined?(pbInBugContest?) && pbInBugContest?
        return true if defined?($game_temp) && $game_temp &&
          $game_temp.respond_to?(:in_battle) && $game_temp.in_battle
        false
      rescue StandardError
        true
      end

      def current_map_id
        return 0 unless defined?($game_map) && $game_map
        $game_map.map_id.to_i
      rescue StandardError
        0
      end

      def pokemon_center_map?
        return false unless defined?($PokemonGlobal) && $PokemonGlobal
        center_id = $PokemonGlobal.pokecenterMapId.to_i
        center_id >= 0 && center_id == current_map_id
      rescue StandardError
        false
      end

      def prompt_pokemon_center_refill
        return false if @refill_prompt_active
        mode = refill_mode
        return false if mode == :never
        missing = configured_max_uses - uses
        return false if missing <= 0
        cost = refill_cost_enabled? ? missing * cost_per_charge : 0
        @refill_prompt_active = true
        if mode == :ask
          prompt = if cost > 0
                     _INTL(
                       "Refill the PokeVial?\nCost: ${1}\nCharges: {2} -> {3}",
                       formatted_number(cost), uses, configured_max_uses
                     )
                   else
                     _INTL(
                       "Refill the PokeVial?\nCharges: {1} -> {2}",
                       uses, configured_max_uses
                     )
                   end
          confirmed = KantoReloaded::PopupWindow.confirm(
            prompt, :default => true
          )
          return false unless confirmed
        end
        if cost > player_money
          KantoReloaded::Toast.error(
            _INTL("You need ${1} to refill the PokeVial.", formatted_number(cost))
          )
          return false
        end
        $Trainer.money = player_money - cost if cost > 0
        set_uses(configured_max_uses)
        pbSEPlay("Mart buy item") if cost > 0 && defined?(pbSEPlay)
        KantoReloaded::Toast.success(refill_summary(missing, cost))
        KantoReloaded::Log.info(
          "PokeVial refilled mode=#{mode} restored=#{missing} cost=#{cost} charges=#{uses}/#{configured_max_uses}",
          :modules
        ) if defined?(KantoReloaded::Log)
        true
      ensure
        @refill_prompt_active = false
      end

      def player_money
        return 0 unless defined?($Trainer) && $Trainer
        $Trainer.money.to_i
      rescue StandardError
        0
      end

      def cost_per_charge
        value = KantoReloaded::Settings.get(
          COST_PER_CHARGE_SETTING, DEFAULT_REFILL_COST
        ).to_i
        [[value, 0].max, 5000].min
      rescue StandardError
        DEFAULT_REFILL_COST
      end

      def badge_count
        return 0 unless defined?($Trainer) && $Trainer
        $Trainer.badge_count.to_i
      rescue StandardError
        0
      end

      def cooldown_seconds
        index = KantoReloaded::Settings.get(
          COOLDOWN_TIME_SETTING, 0
        ).to_i
        index = [[index, 0].max, COOLDOWN_MINUTES.length - 1].min
        COOLDOWN_MINUTES[index] * 60
      rescue StandardError
        COOLDOWN_MINUTES.first * 60
      end

      def cooldown_remaining_seconds
        return 0 unless cooldown_enabled?
        last = state_get(:last_use_time, 0).to_i
        return 0 if last <= 0
        duration = cooldown_seconds
        now = Time.now.to_i
        elapsed = now - last
        if elapsed < 0
          state_set(:last_use_time, now)
          elapsed = 0
          KantoReloaded::Log.warning(
            "PokeVial corrected a future cooldown timestamp",
            :modules
          ) if defined?(KantoReloaded::Log)
        end
        [[duration - elapsed, 0].max, duration].min
      rescue StandardError
        0
      end

      def record_use_time
        state_set(:last_use_time, Time.now.to_i)
      end

      def format_time(total_seconds)
        seconds = [total_seconds.to_i, 0].max
        minutes = seconds / 60
        secs = seconds % 60
        hours = minutes / 60
        minutes %= 60
        if hours > 0
          sprintf("%02d:%02d:%02d", hours, minutes, secs)
        else
          sprintf("%02d:%02d", minutes, secs)
        end
      end

      def state_get(key, default = nil)
        KantoReloaded::SaveData.get(
          SAVE_SYSTEM, key, default, section: :systems
        )
      end

      def state_set(key, value)
        KantoReloaded::SaveData.set(
          SAVE_SYSTEM, key, value, section: :systems
        )
      end

      def set_uses(value)
        maximum = configured_max_uses
        state_set(:uses, [[value.to_i, 0].max, maximum].min)
      end

      def clamp_uses
        value = state_get(:uses, nil)
        set_uses(value) unless value.nil?
      rescue StandardError
        false
      end

      def initialize_progressive_capacity
        return false unless trainer_ready?
        maximum = configured_max_uses
        if progressive? && state_get(:progressive_max_seen, nil).nil?
          state_set(:progressive_max_seen, maximum)
        end
        clamp_uses
        true
      rescue StandardError => e
        KantoReloaded::Log.exception(
          "PokeVial progression initialization failed", e, channel: :modules
        ) if defined?(KantoReloaded::Log)
        false
      end

      def trainer_ready?
        defined?($Trainer) && $Trainer && $Trainer.respond_to?(:badge_count)
      rescue StandardError
        false
      end

      def play_healing_sound
        if defined?(pbSEPlay)
          pbSEPlay("Recovery")
        elsif defined?(pbPlayDecisionSE)
          pbPlayDecisionSE
        end
        true
      rescue StandardError
        pbPlayDecisionSE if defined?(pbPlayDecisionSE)
        false
      end

      def refill_summary(restored, cost)
        if cost.to_i > 0
          _INTL(
            "PokeVial restored {1} {2} for ${3}. Charges: {4}/{5}.",
            restored, charge_word(restored), formatted_number(cost),
            uses, configured_max_uses
          )
        else
          _INTL(
            "PokeVial restored {1} {2}. Charges: {3}/{4}.",
            restored, charge_word(restored), uses, configured_max_uses
          )
        end
      end

      def charge_word(count)
        count.to_i == 1 ? _INTL("charge") : _INTL("charges")
      end

      def truthy_setting(key, fallback)
        value = KantoReloaded::Settings.get(key, fallback)
        value == true ||
          (value.respond_to?(:to_i) && value.to_i == 1)
      rescue StandardError
        fallback.to_i == 1
      end

      def heal_command?(command)
        text = command.to_s.downcase
        text.include?("heal") && text.include?("pok")
      rescue StandardError
        false
      end

      def pc_command?(command)
        command.to_s.strip.downcase == "pc"
      rescue StandardError
        false
      end

      def pause_insertion_index(commands)
        pc_index = commands.index { |command| pc_command?(command) }
        return pc_index + 1 if pc_index
        pokemon_index = commands.index do |command|
          text = command.to_s.downcase
          text.include?("pok") && !text.include?("dex")
        end
        pokemon_index ? pokemon_index + 1 : [commands.length, 3].min
      rescue StandardError
        commands.length
      end

      def formatted_number(value)
        return value.to_i.to_s_formatted if value.to_i.respond_to?(:to_s_formatted)
        value.to_i.to_s
      rescue StandardError
        value.to_i.to_s
      end
    end
  end
end

KantoReloaded::PokeVial.install
