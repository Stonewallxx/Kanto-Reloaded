#==============================================================================
# Kanto Reloaded Quality of Life - Quick Throw
#==============================================================================
# Battle Menu commands for selecting and throwing a remembered Poke Ball.
# Uses KIF's native item registration, consumption, and capture pipelines.
#==============================================================================

module KantoReloaded
  module QualityAssurance
    module QuickThrow
      SAVE_SYSTEM = :quick_throw
      MIGRATION_KEY = :legacy_quick_throw_migration_v1
      REQUEST_IVAR = :@kr_quick_throw_request
      VALIDATION_IVAR = :@kr_quick_throw_target_validation
      DEFAULT_BLACKLIST = [:MASTERBALL].freeze
      ULTRA_BEASTS = [
        :NIHILEGO, :BUZZWOLE, :PHEROMOSA, :XURKITREE, :CELESTEELA,
        :KARTANA, :GUZZLORD, :POIPOLE, :NAGANADEL, :STAKATAKA,
        :BLACEPHALON
      ].freeze

      @fallback_last_ball = nil
      @fallback_blacklist = DEFAULT_BLACKLIST.dup

      class << self
        def install
          register_events
          migrate_legacy_data
          register_battle_menu_commands
          install_hooks
          KantoReloaded::Log.info("Installed Quick Throw module", :modules) if defined?(KantoReloaded::Log)
          true
        rescue StandardError => e
          log_exception("Quick Throw install failed", e)
          false
        end

        def supported_battle?(battle)
          return false unless battle
          return false unless defined?(PokeBattle_Battle) && battle.is_a?(PokeBattle_Battle)
          return false if defined?(PokeBattle_BugContest) && battle.is_a?(PokeBattle_BugContest)
          true
        rescue
          false
        end

        def last_ball
          normalize_ball(save_get(:last_ball, @fallback_last_ball))
        rescue
          nil
        end

        def last_ball=(value)
          ball = normalize_ball(value)
          save_set(:last_ball, ball ? ball.to_s : nil)
          @fallback_last_ball = ball
          ball
        end

        def blacklist
          raw = save_get(:blacklist, nil)
          raw = @fallback_blacklist if raw.nil?
          normalize_ball_list(raw)
        rescue
          DEFAULT_BLACKLIST.dup
        end

        def blacklist=(value)
          normalized = normalize_ball_list(value)
          save_set(:blacklist, normalized.map(&:to_s))
          @fallback_blacklist = normalized
          normalized
        end

        def blacklisted?(ball)
          normalized = normalize_ball(ball)
          normalized && blacklist.include?(normalized)
        end

        def toggle_blacklist(ball)
          normalized = normalize_ball(ball)
          return false unless normalized
          values = blacklist
          if values.include?(normalized)
            values.delete(normalized)
            blocked = false
          else
            values << normalized
            blocked = true
          end
          self.blacklist = values
          self.last_ball = nil if blocked && last_ball == normalized
          blocked
        end

        def available_balls
          return [] unless defined?(GameData::Item) && defined?($PokemonBag) && $PokemonBag
          values = []
          GameData::Item.each do |item|
            next unless item.is_poke_ball?
            quantity = $PokemonBag.pbQuantity(item.id) rescue 0
            values << item.id if quantity.to_i > 0
          end
          values.sort_by do |ball|
            item = GameData::Item.get(ball)
            [(item.id_number rescue 999_999).to_i, item.name.to_s.downcase]
          end
        rescue StandardError => e
          log_exception("Quick Throw ball inventory failed", e)
          []
        end

        def remember_ball(ball)
          normalized = normalize_ball(ball)
          return false unless normalized
          return false if blacklisted?(normalized)
          self.last_ball = normalized
          true
        end

        def select_ball(battle = nil, idx_battler = 0)
          balls = available_balls
          if balls.empty?
            popup_message(_INTL("You don't have any Poke Balls."))
            return false
          end
          selected = last_ball
          start_index = balls.index(selected) || 0
          entries = balls.map do |ball|
            {
              :label => proc { item_name(ball) },
              :value => ball,
              :item => ball,
              :selectable => proc { !blacklisted?(ball) },
              :details => proc { selector_details(ball, battle, idx_battler) },
              :action_label => proc { blacklisted?(ball) ? _INTL("Allow") : _INTL("Block") }
            }
          end
          result = KantoReloaded::PopupWindow.carousel(
            _INTL("Select Quick Throw Ball"),
            entries,
            :start_index => start_index,
            :width => 340,
            :height => 246,
            :on_action => proc { |ball, _entry| toggle_blacklist(ball) }
          )
          return false if result == -1
          return false if blacklisted?(result)
          self.last_ball = result
          true
        rescue StandardError => e
          log_exception("Quick Throw ball selector failed", e)
          false
        end

        def selector_details(ball, battle, idx_battler = 0)
          quantity = ball_quantity(ball)
          access = blacklisted?(ball) ? _INTL("BLOCKED") : _INTL("Allowed")
          details = [_INTL("Quantity: {1} | {2}", quantity, access)]
          estimate = estimate_range(battle, ball, idx_battler)
          details << _INTL("Estimated Catch Chance: {1}", estimate) if estimate
          details
        end

        def estimate_range(battle, ball, idx_battler = 0)
          return nil unless supported_battle?(battle)
          targets = valid_targets(battle, idx_battler)
          return nil if targets.empty?
          estimates = targets.map { |battler| estimate_catch_chance(battle, battler, ball) }.compact
          return nil if estimates.empty?
          low = format_percentage(estimates.min)
          high = format_percentage(estimates.max)
          low == high ? low : "#{low}-#{high}"
        rescue
          nil
        end

        def estimate_catch_chance(battle, battler, ball)
          return nil unless battle && battler && battler.pokemon
          normalized = normalize_ball(ball)
          return nil unless normalized
          pkmn = battler.pokemon
          catch_rate = pkmn.species_data.catch_rate
          ultra_beast = ULTRA_BEASTS.include?(pkmn.species)
          if !ultra_beast || normalized == :BEASTBALL
            catch_rate = BallHandlers.modifyCatchRate(normalized, catch_rate, battle, battler, ultra_beast)
          else
            catch_rate /= 10
          end
          total_hp = battler.totalhp.to_f
          return nil if total_hp <= 0
          x = ((3.0 * total_hp - 2.0 * battler.hp.to_f) * catch_rate.to_f) / (3.0 * total_hp)
          if battler.status == :SLEEP || battler.status == :FROZEN
            x *= 2.5
          elsif battler.status != :NONE
            x *= 1.5
          end
          x = [x.floor, 1].max
          return 1.0 if x >= 255 || BallHandlers.isUnconditional?(normalized, battle, battler)
          y = (65_536.0 / ((255.0 / x) ** 0.1875)).floor
          normal_chance = (y / 65_536.0) ** 4
          critical_chance = critical_capture_chance(x)
          [[critical_chance + ((1.0 - critical_chance) * normal_chance), 0.0].max, 1.0].min
        rescue StandardError => e
          log_exception("Quick Throw catch estimate failed", e)
          nil
        end

        def queue_throw(battle, idx_battler)
          ball = usable_last_ball(battle)
          return :keep_open unless ball
          battle.instance_variable_set(REQUEST_IVAR, {
            :idx_battler => idx_battler.to_i,
            :ball => ball
          })
          :bag
        rescue StandardError => e
          log_exception("Quick Throw request failed", e)
          :keep_open
        end

        def consume_request(battle, idx_battler, first_action)
          request = battle.instance_variable_get(REQUEST_IVAR)
          return nil unless request.is_a?(Hash) && request[:idx_battler].to_i == idx_battler.to_i
          battle.remove_instance_variable(REQUEST_IVAR) if battle.instance_variable_defined?(REQUEST_IVAR)
          perform_throw(battle, idx_battler, first_action, request[:ball])
        rescue StandardError => e
          battle.remove_instance_variable(REQUEST_IVAR) if battle && battle.instance_variable_defined?(REQUEST_IVAR)
          log_exception("Quick Throw execution failed", e)
          false
        end

        def perform_throw(battle, idx_battler, first_action, ball)
          unless internal_battle?(battle)
            battle.pbDisplay(_INTL("Items can't be used here."))
            return false
          end
          unless ball_quantity(ball) > 0
            battle.pbDisplay(_INTL("You don't have any {1}s left!", item_name(ball)))
            return false
          end
          targets = valid_targets(battle, idx_battler)
          if targets.empty?
            battle.pbDisplay(_INTL("There are no valid targets!"))
            return false
          end
          target = choose_target(battle, idx_battler, targets)
          return false unless target
          return false unless can_use_ball?(battle, target, ball, first_action, targets.length > 1)
          battle.pbRegisterItem(idx_battler, ball, target.index, nil)
        end

        def valid_targets(battle, idx_battler)
          targets = []
          if battle.respond_to?(:eachOtherSideBattler)
            battle.eachOtherSideBattler(idx_battler) { |battler| targets << battler if battler && !battler.fainted? }
          else
            Array(battle.battlers).each do |battler|
              next unless battler && !battler.fainted?
              targets << battler if battle.opposes?(idx_battler, battler.index)
            end
          end
          targets
        rescue
          []
        end

        def choose_target(battle, idx_battler, targets)
          return targets.first if targets.length == 1
          return nil unless battle.scene && battle.scene.respond_to?(:pbChooseTarget)
          target_data = GameData::Target.get(:Foe)
          chosen = battle.scene.pbChooseTarget(idx_battler, target_data)
          targets.find { |battler| battler.index == chosen }
        rescue
          nil
        end

        def can_use_ball?(battle, target, ball, first_action, targeted_multi)
          previous = battle.instance_variable_get(VALIDATION_IVAR)
          battle.instance_variable_set(VALIDATION_IVAR, targeted_multi)
          ItemHandlers.triggerCanUseInBattle(
            ball, target.pokemon, target, nil, !!first_action, battle, battle.scene, true
          )
        ensure
          battle.instance_variable_set(VALIDATION_IVAR, previous) if battle
        end

        def targeted_validation?(battle)
          !!battle.instance_variable_get(VALIDATION_IVAR)
        rescue
          false
        end

        def usable_last_ball(battle)
          ball = last_ball
          if ball && blacklisted?(ball)
            battle.pbDisplay(_INTL("{1} is blocked from Quick Throw.", item_name(ball)))
            return nil
          end
          return ball if ball && ball_quantity(ball) > 0
          if ball && ball != :POKEBALL && !blacklisted?(:POKEBALL) && ball_quantity(:POKEBALL) > 0
            battle.pbDisplay(_INTL("Out of {1}s! Switching to Poke Balls.", item_name(ball)))
            self.last_ball = :POKEBALL
            return :POKEBALL
          end
          if ball
            battle.pbDisplay(_INTL("You don't have any {1}s left!", item_name(ball)))
          else
            battle.pbDisplay(_INTL("Select a Quick Throw Ball first."))
          end
          nil
        end

        def current_status
          ball = last_ball
          return _INTL("Not Set") unless ball
          return _INTL("Blocked") if blacklisted?(ball)
          _INTL("x{1}", ball_quantity(ball))
        rescue
          ""
        end

        def selected_ball_status
          ball = last_ball
          ball ? item_name(ball) : _INTL("Not Set")
        rescue
          ""
        end

        def migrate_legacy_data
          return false unless defined?(KantoReloaded::SaveData)
          return true if save_get(MIGRATION_KEY, false)
          legacy_ball = legacy_setting(:quick_throw_last_ball)
          self.last_ball = legacy_ball if last_ball.nil? && normalize_ball(legacy_ball)
          legacy_blacklist = legacy_setting(:ball_filter_blacklist)
          if legacy_blacklist.is_a?(Array)
            self.blacklist = (blacklist + normalize_ball_list(legacy_blacklist)).uniq
          else
            self.blacklist = blacklist
          end
          save_set(MIGRATION_KEY, true)
          true
        rescue StandardError => e
          log_exception("Quick Throw legacy migration failed", e)
          false
        end

        private

        def register_battle_menu_commands
          return false unless defined?(BattleCommandMenu)
          BattleCommandMenu.register(:quick_throw, {
            :label => _INTL("Quick Throw"),
            :description => _INTL("Throw the selected Poke Ball without opening the Bag."),
            :priority => 1,
            :condition => proc { |battle, _idx| supported_battle?(battle) },
            :status => proc { current_status },
            :handler => proc { |battle, idx_battler, _scene| queue_throw(battle, idx_battler) }
          })
          BattleCommandMenu.register(:select_quick_throw_ball, {
            :label => _INTL("Select Quick Throw Ball"),
            :description => _INTL("Choose which Poke Ball Quick Throw will use."),
            :priority => 2,
            :condition => proc { |battle, _idx| supported_battle?(battle) },
            :status => proc { selected_ball_status },
            :handler => proc do |battle, idx_battler, _scene|
              select_ball(battle, idx_battler)
              :keep_open
            end
          })
          true
        end

        def install_hooks
          return false unless defined?(KantoReloaded::Hooks) && defined?(PokeBattle_Battle)
          KantoReloaded::Hooks.wrap(PokeBattle_Battle, :pbItemMenu, :quality_of_life_quick_throw_item_menu) do |hook, idx_battler, first_action, *_args|
            result = KantoReloaded::QualityAssurance::QuickThrow.consume_request(self, idx_battler, first_action)
            result.nil? ? hook.call : result
          end
          KantoReloaded::Hooks.wrap(PokeBattle_Battle, :pbRegisterItem, :quality_of_life_quick_throw_remember_ball) do |hook, _idx_battler, item, *_args|
            result = hook.call
            if result && KantoReloaded::QualityAssurance::QuickThrow.poke_ball?(item)
              KantoReloaded::QualityAssurance::QuickThrow.remember_ball(item)
            end
            result
          end
          KantoReloaded::Hooks.wrap(PokeBattle_Battle, :pbOpposingBattlerCount, :quality_of_life_quick_throw_target_validation) do |hook, *_args|
            KantoReloaded::QualityAssurance::QuickThrow.targeted_validation?(self) ? 1 : hook.call
          end
          true
        end

        def register_events
          return unless defined?(KantoReloaded::Events)
          KantoReloaded::Events.on(:kanto_reloaded_save_loaded, :quick_throw_legacy_migration, priority: 160) do |_context|
            KantoReloaded::QualityAssurance::QuickThrow.migrate_legacy_data
          end
          KantoReloaded::Events.on(:kanto_reloaded_save_new_game, :quick_throw_legacy_migration, priority: 160) do |_context|
            KantoReloaded::QualityAssurance::QuickThrow.migrate_legacy_data
          end
        end

        def critical_capture_chance(x)
          return 0.0 unless defined?(Settings) && Settings::ENABLE_CRITICAL_CAPTURES
          owned = $Trainer.pokedex.owned_count rescue 0
          multiplier = if owned > 600
                         5
                       elsif owned > 450
                         4
                       elsif owned > 300
                         3
                       else
                         2
                       end
          c = x.to_i * multiplier / 12
          c > 0 ? [c / 256.0, 1.0].min : 0.0
        rescue
          0.0
        end

        def format_percentage(value)
          percentage = value.to_f * 100.0
          return "<1%" if percentage > 0 && percentage < 1
          "#{percentage.round}%"
        end

        def internal_battle?(battle)
          return !!battle.internalBattle if battle.respond_to?(:internalBattle)
          !!battle.instance_variable_get(:@internalBattle)
        rescue
          false
        end

        def ball_quantity(ball)
          return 0 unless defined?($PokemonBag) && $PokemonBag
          $PokemonBag.pbQuantity(ball).to_i
        rescue
          0
        end

        def item_name(ball)
          item = item_data(ball)
          item ? item.name.to_s : ball.to_s
        rescue
          ball.to_s
        end

        def poke_ball?(item)
          data = item_data(item)
          data && data.is_poke_ball?
        rescue
          false
        end

        def normalize_ball(value)
          return nil if value.nil?
          ball = value.respond_to?(:to_sym) ? value.to_sym : value
          item = item_data(ball)
          return nil unless item && item.is_poke_ball?
          item.id
        rescue
          nil
        end

        def normalize_ball_list(values)
          Array(values).map { |value| normalize_ball(value) }.compact.uniq
        end

        def item_data(value)
          return nil unless defined?(GameData::Item)
          GameData::Item.try_get(value)
        rescue
          nil
        end

        def legacy_setting(key)
          if defined?(KantoReloaded::Settings) && KantoReloaded::Settings.stored?(key)
            KantoReloaded::Settings.get(key, nil)
          elsif defined?(ModSettingsMenu) && ModSettingsMenu.respond_to?(:get)
            ModSettingsMenu.get(key) rescue nil
          end
        end

        def save_get(key, fallback)
          return fallback unless defined?(KantoReloaded::SaveData)
          KantoReloaded::SaveData.get(SAVE_SYSTEM, key, fallback, section: :systems)
        end

        def save_set(key, value)
          return false unless defined?(KantoReloaded::SaveData)
          KantoReloaded::SaveData.set(SAVE_SYSTEM, key, value, section: :systems)
        end

        def popup_message(text)
          if defined?(KantoReloaded::PopupWindow)
            KantoReloaded::PopupWindow.message(text)
          elsif defined?(pbMessage)
            pbMessage(text)
          end
        end

        def log_exception(message, error)
          KantoReloaded::Log.exception(message, error, channel: :modules) if defined?(KantoReloaded::Log)
        rescue
          nil
        end

        public :poke_ball?
      end
    end
  end
end

KantoReloaded::QualityAssurance::QuickThrow.install
