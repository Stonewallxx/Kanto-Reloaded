#==============================================================================
# Kanto Reloaded - Critical EV Gain
#==============================================================================

module KantoReloaded
  module CriticalEVGain
    MODULE_ID = :critical_ev_gain
    SETTINGS_ACTION = :critical_ev_gain_settings
    ENABLED_SETTING = :critical_ev_gain
    MODE_SETTING = :critical_ev_mode
    CHANCE_SETTING = :critical_ev_chance
    AMOUNT_SETTING = :critical_ev_amount
    SHOW_POPUP_SETTING = :critical_ev_show_message
    LEGACY_STATS_SETTING = :critical_ev_stats

    MODE_RANDOM = 0
    MODE_NATURAL = 1
    DEFAULT_CHANCE = 5
    DEFAULT_AMOUNT = 3
    TRACKING_IVAR = :@kanto_reloaded_critical_ev_natural_stats
    RECIPIENTS_IVAR = :@kanto_reloaded_critical_ev_recipients
    MAP_READY_UPDATES = 8

    STAT_SETTINGS = {
      :HP => :critical_ev_stat_hp,
      :ATTACK => :critical_ev_stat_attack,
      :DEFENSE => :critical_ev_stat_defense,
      :SPECIAL_ATTACK => :critical_ev_stat_special_attack,
      :SPECIAL_DEFENSE => :critical_ev_stat_special_defense,
      :SPEED => :critical_ev_stat_speed
    }.freeze

    class ChanceAction < KantoReloaded::Options::ActionButton
      def initialize(scene)
        @scene = scene
        super(
          _INTL("Critical Chance"),
          proc { choose_value },
          _INTL("Set the chance that each participating Pokemon receives bonus EVs.")
        )
      end

      def name
        _INTL("Critical Chance < {1}% >", KantoReloaded::CriticalEVGain.chance)
      end

      def disabled?
        !KantoReloaded::CriticalEVGain.enabled?
      end

      private

      def choose_value
        selected = KantoReloaded::NumberPicker.open(
          _INTL("Critical Chance"),
          :min => 0,
          :max => 100,
          :initial => KantoReloaded::CriticalEVGain.chance,
          :digits => 3,
          :label => _INTL("Chance per participant")
        )
        return if selected.nil?
        KantoReloaded::Settings.set(CHANCE_SETTING, selected.to_i)
        @scene.sync_window_values if @scene.respond_to?(:sync_window_values)
      end
    end

    class AmountAction < KantoReloaded::Options::ActionButton
      def initialize(scene)
        @scene = scene
        super(
          _INTL("Critical Amount"),
          proc { choose_value },
          _INTL("Set the number of bonus EVs awarded after a successful roll.")
        )
      end

      def name
        _INTL("Critical Amount < {1} >", KantoReloaded::CriticalEVGain.amount)
      end

      def disabled?
        !KantoReloaded::CriticalEVGain.enabled?
      end

      private

      def choose_value
        selected = KantoReloaded::NumberPicker.open(
          _INTL("Critical Amount"),
          :min => 1,
          :max => 10,
          :initial => KantoReloaded::CriticalEVGain.amount,
          :digits => 2,
          :label => _INTL("Bonus EVs per success")
        )
        return if selected.nil?
        KantoReloaded::Settings.set(AMOUNT_SETTING, selected.to_i)
        @scene.sync_window_values if @scene.respond_to?(:sync_window_values)
      end
    end

    class SettingsScene < KantoReloaded::SettingsUI::BaseScene
      def scene_title
        "Critical EV Gain"
      end

      def scene_description
        "Configure bonus EV rewards for Pokemon that earn EVs in victorious battles."
      end

      def pbGetOptions(_inloadscreen = false)
        rows = []
        rows << KantoReloaded::Options::CollapsibleHeader.new(
          _INTL("Critical EV Gain"),
          _INTL("Award extra EVs to Pokemon that earn EVs during eligible victories."),
          :collapsed => true
        )
        rows << setting_row(ENABLED_SETTING)
        rows << setting_row(MODE_SETTING)
        rows << ChanceAction.new(self)
        rows << AmountAction.new(self)
        rows << setting_row(SHOW_POPUP_SETTING)

        rows << KantoReloaded::Options::CollapsibleHeader.new(
          _INTL("Eligible Stats"),
          _INTL("Choose which stats can receive Critical EVs."),
          :collapsed => true
        )
        STAT_SETTINGS.each_value { |key| rows << setting_row(key) }

        rows << KantoReloaded::Options::ActionButton.new(
          _INTL("Reset Module"),
          proc { reset_module },
          _INTL("Restore all Critical EV Gain settings to their defaults.")
        )
        rows.compact
      end

      private

      def setting_row(key)
        definition = KantoReloaded::Settings.definition(key)
        return nil unless definition
        KantoReloaded::SettingsUI::RowFactory.build(
          definition,
          :scene => self, :critical_ev_gain => true
        )
      end

      def reset_module
        return unless KantoReloaded::PopupWindow.confirm(
          _INTL("Reset all Critical EV Gain settings to their defaults?"),
          :default => false
        )
        KantoReloaded::Settings.reset_module(MODULE_ID)
        sync_window_values
        KantoReloaded::Toast.success(_INTL("Critical EV Gain settings reset."))
      end
    end

    class << self
      def boot
        return true if @booted
        settings_ready = register_settings
        events_ready = register_events
        hooks_ready = install_hooks
        @booted = settings_ready && events_ready && hooks_ready
        if defined?(KantoReloaded::Log)
          state = @booted ? "ready" : "partial"
          KantoReloaded::Log.info(
            "Critical EV Gain integration #{state}", :critical_ev_gain
          )
        end
        @booted
      rescue StandardError => e
        @booted = false
        log_exception("Critical EV Gain failed to boot", e)
        false
      end

      def enabled?
        truthy?(KantoReloaded::Settings.get(ENABLED_SETTING, false))
      rescue StandardError
        false
      end

      def mode
        value = KantoReloaded::Settings.get(MODE_SETTING, MODE_NATURAL).to_i
        value == MODE_RANDOM ? MODE_RANDOM : MODE_NATURAL
      rescue StandardError
        MODE_NATURAL
      end

      def chance
        clamp(KantoReloaded::Settings.get(CHANCE_SETTING, DEFAULT_CHANCE), 0, 100)
      end

      def amount
        clamp(KantoReloaded::Settings.get(AMOUNT_SETTING, DEFAULT_AMOUNT), 1, 10)
      end

      def show_popup?
        truthy?(KantoReloaded::Settings.get(SHOW_POPUP_SETTING, true))
      rescue StandardError
        true
      end

      def enabled_stats
        STAT_SETTINGS.each_with_object([]) do |(stat, key), values|
          values << stat if truthy?(KantoReloaded::Settings.get(key, true))
        end
      rescue StandardError
        STAT_SETTINGS.keys
      end

      def capture_evs(pokemon)
        return nil unless pokemon && pokemon.respond_to?(:ev)
        STAT_SETTINGS.keys.each_with_object({}) do |stat, values|
          values[stat] = pokemon.ev[stat].to_i
        end
      rescue StandardError
        nil
      end

      def record_natural_gains(battle, party_index, pokemon, before)
        return false unless battle && pokemon && before.is_a?(Hash)
        gained = STAT_SETTINGS.keys.each_with_object({}) do |stat, values|
          amount = pokemon.ev[stat].to_i - before[stat].to_i
          values[stat] = amount if amount > 0
        end
        return false if gained.empty?
        tracking = battle.instance_variable_get(TRACKING_IVAR)
        tracking = {} unless tracking.is_a?(Hash)
        tracking[party_index.to_i] ||= {}
        gained.each do |stat, amount|
          current = tracking[party_index.to_i][stat].to_i
          tracking[party_index.to_i][stat] = current + amount.to_i
        end
        battle.instance_variable_set(TRACKING_IVAR, tracking)
        true
      rescue StandardError => e
        log_exception("Could not record natural EV gains", e)
        false
      end

      def record_recipient(battle, party_index)
        return false unless battle
        recipients = battle.instance_variable_get(RECIPIENTS_IVAR)
        recipients = {} unless recipients.is_a?(Hash)
        recipients[party_index.to_i] = true
        battle.instance_variable_set(RECIPIENTS_IVAR, recipients)
        true
      rescue StandardError => e
        log_exception("Could not record Critical EV recipient", e)
        false
      end

      def default_gains_for(battle, party_index)
        tracking = battle.instance_variable_get(TRACKING_IVAR)
        values = tracking.is_a?(Hash) ? tracking[party_index.to_i] : nil
        values.is_a?(Hash) ? values.dup : {}
      rescue StandardError
        {}
      end

      def resolve(battle, decision)
        return [] unless enabled?
        return [] unless eligible_battle?(battle, decision)
        results = []
        party = battle.pbParty(0)
        recipients = battle.instance_variable_get(RECIPIENTS_IVAR)
        Array(party).each_with_index do |pokemon, index|
          next unless pokemon && recipients.is_a?(Hash) && recipients[index]
          next if pokemon.respond_to?(:egg?) && pokemon.egg?
          stats = eligible_stats_for(battle, index)
          next if stats.empty? || rand(100) >= chance
          awarded = award(pokemon, stats, amount)
          unless awarded.empty?
            results << [pokemon, awarded, default_gains_for(battle, index)]
          end
        end
        queue_results(results) unless results.empty?
        KantoReloaded::Log.debug(
          "Critical EV Gain awarded #{results.length} of #{recipients.length} recipient(s)",
          :critical_ev_gain
        ) if defined?(KantoReloaded::Log) && !results.empty?
        results
      rescue StandardError => e
        log_exception("Could not resolve Critical EV Gain", e)
        []
      end

      def clear_tracking(battle)
        return false unless battle
        battle.remove_instance_variable(TRACKING_IVAR) if
          battle.instance_variable_defined?(TRACKING_IVAR)
        battle.remove_instance_variable(RECIPIENTS_IVAR) if
          battle.instance_variable_defined?(RECIPIENTS_IVAR)
        true
      rescue StandardError
        false
      end

      def show_pending_results(sender = nil)
        return false if @showing_results
        return false if @pending_result_pages.nil? || @pending_result_pages.empty?
        return false if defined?(Scene_Map) && sender && !sender.is_a?(Scene_Map)
        if defined?(KantoReloaded::UI::Modal) && KantoReloaded::UI::Modal.active?
          return false
        end
        return false unless map_ready_for_popup?
        pages = @pending_result_pages
        @pending_result_pages = []
        @pending_map_updates = 0
        @showing_results = true
        KantoReloaded::PopupWindow.paged_summary(
          _INTL("Critical EV Gain"),
          pages,
          :theme => :success,
          :start_index => 0,
          :show_dim => false
        )
        true
      rescue StandardError => e
        log_exception("Could not show Critical EV results", e)
        false
      ensure
        @showing_results = false
      end

      private

      def register_settings
        visible = proc do |context|
          context.is_a?(Hash) && !!(
            context[:critical_ev_gain] || context["critical_ev_gain"]
          )
        end
        enabled = proc { KantoReloaded::CriticalEVGain.enabled? }

        action = KantoReloaded::Settings.register(SETTINGS_ACTION, {
          :name => "Critical EV Gain",
          :description => "Configure occasional bonus EV rewards after victorious battles.",
          :type => :button,
          :category => :gameplay,
          :owner => :kanto_reloaded,
          :priority => 1700,
          :on_press => proc {
            pbFadeOutIn {
              PokemonOptionScreen.new(
                KantoReloaded::CriticalEVGain::SettingsScene.new
              ).pbStartScreen
            }
          }
        })

        definitions = [
          [ENABLED_SETTING, {
            :name => "Critical EV Gain",
            :description => "Allow Pokemon that earn battle EVs to receive bonus EVs after eligible victories.",
            :type => :toggle, :default => false, :priority => 10
          }],
          [MODE_SETTING, {
            :name => "Distribution",
            :description => "Use naturally earned stats or choose randomly from enabled stats.",
            :type => :enum, :values => ["Random", "Natural"],
            :default => MODE_NATURAL, :priority => 20,
            :enabled_if => enabled
          }],
          [CHANCE_SETTING, {
            :name => "Critical Chance",
            :description => "Chance per Pokemon that earned EVs after an eligible victory.",
            :type => :number, :min => 0, :max => 100,
            :default => DEFAULT_CHANCE, :priority => 30,
            :enabled_if => enabled
          }],
          [AMOUNT_SETTING, {
            :name => "Critical Amount",
            :description => "Bonus EVs awarded after a successful roll.",
            :type => :number, :min => 1, :max => 10,
            :default => DEFAULT_AMOUNT, :priority => 40,
            :enabled_if => enabled
          }],
          [SHOW_POPUP_SETTING, {
            :name => "Show Result Popup",
            :description => "Show a result popup after returning to the overworld.",
            :type => :toggle, :default => true, :priority => 50,
            :enabled_if => enabled
          }]
        ]

        STAT_SETTINGS.each_with_index do |(stat, key), index|
          definitions << [key, {
            :name => stat_name(stat),
            :description => "Allow Critical EVs to be assigned to #{stat_name(stat)}.",
            :type => :toggle, :default => true,
            :priority => 60 + index, :enabled_if => enabled
          }]
        end

        registered = definitions.map do |key, options|
          KantoReloaded::Settings.register(key, options.merge(
            :category => :gameplay,
            :owner => MODULE_ID,
            :visible_if => visible
          ))
        end
        !action.nil? && registered.none?(&:nil?)
      end

      def register_events
        return false unless defined?(KantoReloaded::Events)
        KantoReloaded::Events.on(
          :kanto_reloaded_save_loaded,
          :critical_ev_gain_legacy_stats,
          :priority => 320
        ) { |_context| KantoReloaded::CriticalEVGain.send(:migrate_legacy_stats) }
        register_map_event
      end

      def register_map_event
        return true if @map_event_registered
        return false unless defined?(::Events) && ::Events.respond_to?(:onMapUpdate)
        @map_event_handler = proc do |sender, _event|
          KantoReloaded::CriticalEVGain.show_pending_results(sender)
        end
        ::Events.onMapUpdate += @map_event_handler
        @map_event_registered = true
        true
      end

      def install_hooks
        return false unless defined?(KantoReloaded::Hooks)
        return false unless defined?(PokeBattle_Battle)
        gain_ready = KantoReloaded::Hooks.wrap(
          PokeBattle_Battle,
          :pbGainEVsOne,
          :critical_ev_gain_observe,
          :required => true
        ) do |hook, party_index, _defeated_battler, *_arguments|
          module_api = KantoReloaded::CriticalEVGain
          pokemon = pbParty(0)[party_index] rescue nil
          before = module_api.enabled? ? module_api.capture_evs(pokemon) : nil
          result = hook.call
          if before
            module_api.record_recipient(self, party_index)
            module_api.record_natural_gains(self, party_index, pokemon, before)
          end
          result
        end

        end_ready = KantoReloaded::Hooks.wrap(
          PokeBattle_Battle,
          :pbEndOfBattle,
          :critical_ev_gain_award,
          :required => true
        ) do |hook, *_arguments|
          module_api = KantoReloaded::CriticalEVGain
          begin
            result = hook.call
            module_api.resolve(self, result)
            result
          ensure
            module_api.clear_tracking(self)
          end
        end
        gain_ready && end_ready
      end

      def migrate_legacy_stats
        return true if STAT_SETTINGS.values.any? do |key|
          KantoReloaded::Settings.stored?(key)
        end
        legacy = KantoReloaded::Settings.get(LEGACY_STATS_SETTING, nil)
        return true unless legacy.is_a?(Array)
        selected = legacy.map { |value| value.to_s.upcase.to_sym }
        STAT_SETTINGS.each do |stat, key|
          KantoReloaded::Settings.set(key, selected.include?(stat), :notify => false)
        end
        true
      rescue StandardError => e
        log_exception("Could not migrate legacy Critical EV stats", e)
        false
      end

      def eligible_battle?(battle, decision)
        return false unless battle
        internal = battle.instance_variable_get(:@internalBattle)
        !!internal && decision.to_i == 1
      rescue StandardError
        false
      end

      def map_ready_for_popup?
        if defined?($game_temp) && $game_temp
          return false if $game_temp.respond_to?(:transition_processing) &&
                          $game_temp.transition_processing
          return false if $game_temp.respond_to?(:message_window_showing) &&
                          $game_temp.message_window_showing
          return false if $game_temp.respond_to?(:in_menu) && $game_temp.in_menu
          return false if $game_temp.respond_to?(:in_battle) && $game_temp.in_battle
        end
        if defined?(Graphics) && Graphics.respond_to?(:brightness)
          return false if Graphics.brightness.to_i < 255
        end
        @pending_map_updates = @pending_map_updates.to_i + 1
        @pending_map_updates >= MAP_READY_UPDATES
      rescue StandardError
        false
      end

      def eligible_stats_for(battle, party_index)
        selected = enabled_stats
        return selected if mode == MODE_RANDOM
        tracking = battle.instance_variable_get(TRACKING_IVAR)
        natural = tracking.is_a?(Hash) ? tracking[party_index.to_i] : nil
        return [] unless natural.is_a?(Hash)
        selected.select { |stat| natural[stat].to_i > 0 }
      rescue StandardError
        []
      end

      def award(pokemon, stats, desired)
        return {} unless pokemon && pokemon.respond_to?(:ev)
        stat_limit = defined?(Pokemon::EV_STAT_LIMIT) ? Pokemon::EV_STAT_LIMIT.to_i : 252
        total_limit = defined?(Pokemon::EV_LIMIT) ? Pokemon::EV_LIMIT.to_i : 510
        total = STAT_SETTINGS.keys.inject(0) do |sum, stat|
          sum + pokemon.ev[stat].to_i
        end
        total_capacity = [total_limit - total, 0].max
        target = [[desired.to_i, total_capacity].min, 0].max
        capacities = Array(stats).each_with_object({}) do |stat, values|
          values[stat] = [stat_limit - pokemon.ev[stat].to_i, 0].max
        end
        allocations = Hash.new(0)
        target.times do
          available = capacities.keys.select do |stat|
            allocations[stat] < capacities[stat]
          end
          break if available.empty?
          allocations[available[rand(available.length)]] += 1
        end
        allocations.each_with_object({}) do |(stat, value), granted|
          amount_given = pbJustRaiseEffortValues(pokemon, stat, value)
          granted[stat] = amount_given if amount_given.to_i > 0
        end
      rescue StandardError => e
        log_exception("Could not award Critical EVs", e)
        {}
      end

      def queue_results(results)
        return false unless show_popup?
        pages = results.map do |pokemon, awarded, default_gains|
          total = awarded.values.inject(0) { |sum, value| sum + value.to_i }
          default_gains = {} unless default_gains.is_a?(Hash)
          displayed_stats = STAT_SETTINGS.keys.select do |stat|
            default_gains[stat].to_i > 0 || awarded[stat].to_i > 0
          end
          {
            :label => _INTL("{1}: +{2} EVs", pokemon.name, total),
            :details => displayed_stats.map do |stat|
              normal = default_gains[stat].to_i
              critical = awarded[stat].to_i
              {
                :label => stat_name(stat),
                :normal => normal > 0 ? "+#{normal}" : "",
                :critical => critical > 0 ? "+#{critical}" : ""
              }
            end,
            :value => true
          }
        end
        @pending_result_pages ||= []
        @pending_result_pages.concat(pages)
        @pending_map_updates = 0
        true
      rescue StandardError => e
        log_exception("Could not queue Critical EV results", e)
        false
      end

      def stat_name(stat)
        data = GameData::Stat.try_get(stat) rescue nil
        return data.name.to_s if data && data.respond_to?(:name)
        stat.to_s.split("_").map { |part| part.capitalize }.join(" ")
      rescue StandardError
        stat.to_s
      end

      def clamp(value, minimum, maximum)
        [[value.to_i, minimum].max, maximum].min
      rescue StandardError
        minimum
      end

      def truthy?(value)
        value == true || (value.respond_to?(:to_i) && value.to_i == 1)
      rescue StandardError
        false
      end

      def log_exception(message, error)
        KantoReloaded::Log.exception(
          message, error, :channel => :critical_ev_gain
        ) if defined?(KantoReloaded::Log)
      end
    end
  end
end

KantoReloaded::CriticalEVGain.boot
