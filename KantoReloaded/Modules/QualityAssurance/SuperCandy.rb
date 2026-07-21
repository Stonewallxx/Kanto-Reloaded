#==============================================================================
# Kanto Reloaded Quality of Life - Super Candy
#==============================================================================

module KantoReloaded
  module QualityAssurance
    module SuperCandy
      ACTION_KEY = :super_candy
      SETTINGS_PRIORITY = 82
      OVERWORLD_PRIORITY = 23

      class << self
        def open
          party = current_party
          unless party_available?(party)
            KantoReloaded.message(
              _INTL("There are no eligible Pokemon in the party."),
              :theme => :warning
            )
            return false
          end
          unless leveling_available?
            KantoReloaded.message(
              _INTL("Super Candy is unavailable while No Levels Mode is active."),
              :theme => :warning
            )
            return false
          end

          selection = choose_target(party)
          return false unless selection
          plan = build_plan(party, selection)
          if plan[:entries].empty?
            KantoReloaded.message(
              _INTL("No eligible party Pokemon can gain a level under those limits."),
              :theme => :warning
            )
            return false
          end
          return false unless confirm_plan(plan)

          result = apply_plan(plan)
          show_result(result)
          result[:pokemon] > 0
        rescue StandardError => e
          log_exception("Super Candy failed", e)
          KantoReloaded.message(
            _INTL("Super Candy could not finish leveling the party."),
            :theme => :error
          )
          false
        end

        def install
          register_action
          register_overworld_menu
          if defined?(KantoReloaded::Log)
            KantoReloaded::Log.info("Installed Super Candy module", :modules)
          end
          true
        end

        private

        def current_party
          trainer = defined?($Trainer) ? $Trainer : nil
          return nil unless trainer && trainer.respond_to?(:party)
          trainer.party
        rescue
          nil
        end

        def party_available?(party = current_party)
          Array(party).any? { |pokemon| eligible?(pokemon) }
        rescue
          false
        end

        def leveling_available?
          return true unless defined?(SWITCH_NO_LEVELS_MODE)
          return true unless defined?($game_switches) && $game_switches
          !$game_switches[SWITCH_NO_LEVELS_MODE]
        rescue
          true
        end

        def eligible?(pokemon)
          return false unless pokemon
          return false if pokemon.respond_to?(:egg?) && pokemon.egg?
          return false if pokemon.respond_to?(:shadowPokemon?) && pokemon.shadowPokemon?
          true
        rescue
          false
        end

        def choose_target(party)
          cap = kif_level_cap
          highest = highest_party_level(party)
          rows = [
            {
              :label => _INTL("KIF Level Cap (Lv. {1})", cap),
              :value => :level_cap
            },
            {
              :label => _INTL("Highest Party Level (Lv. {1})", highest),
              :value => :highest
            },
            { :label => _INTL("Choose Level"), :value => :custom },
            { :label => _INTL("Back"), :value => :back }
          ]
          mode = KantoReloaded::PopupWindow.choice(
            _INTL("Choose the Super Candy target."),
            rows
          )
          return nil if mode == -1 || mode == :back

          case mode
          when :level_cap
            { :level => cap, :label => _INTL("the KIF level cap (Lv. {1})", cap) }
          when :highest
            { :level => highest, :label => _INTL("the highest party level (Lv. {1})", highest) }
          when :custom
            choose_custom_target(cap)
          else
            nil
          end
        end

        def choose_custom_target(start_level)
          maximum = maximum_level
          selected = KantoReloaded::NumberPicker.open(
            _INTL("Choose the Super Candy level."),
            :min => 1,
            :max => maximum,
            :initial => [[start_level.to_i, 1].max, maximum].min
          )
          return nil if selected.nil?
          {
            :level => selected.to_i,
            :label => _INTL("Lv. {1}", selected.to_i)
          }
        end

        def build_plan(party, selection)
          requested = normalize_level(selection[:level])
          kif_cap = kif_level_cap
          entries = []
          personal_limited = 0
          kif_limited = 0

          Array(party).each do |pokemon|
            next unless eligible?(pokemon)
            current = current_level(pokemon)
            lock = personal_lock(pokemon)
            target = effective_target(pokemon, requested, kif_cap)
            personal_limited += 1 if lock && lock == target && lock < requested
            kif_limited += 1 if kif_cap == target && kif_cap < requested
            next if current >= target
            entries << {
              :pokemon => pokemon,
              :target => target,
              :levels => target - current
            }
          end

          {
            :party => party,
            :selection => selection,
            :requested => requested,
            :entries => entries,
            :levels => entries.inject(0) { |sum, entry| sum + entry[:levels] },
            :personal_limited => personal_limited,
            :kif_limited => kif_limited
          }
        end

        def confirm_plan(plan)
          count = plan[:entries].length
          levels = plan[:levels]
          text = _INTL(
            "Raise {1} party Pokemon toward {2}?\nThis will grant {3} total levels.",
            count,
            plan[:selection][:label],
            levels
          )
          KantoReloaded.confirm(text, :default => false)
        end

        def apply_plan(plan)
          result = {
            :pokemon => 0,
            :levels => 0,
            :personal_limited => plan[:personal_limited],
            :kif_limited => plan[:kif_limited],
            :errors => 0
          }
          plan[:entries].each do |entry|
            gained = advance_pokemon(
              entry[:pokemon],
              entry[:target],
              plan[:party]
            )
            if gained > 0
              result[:pokemon] += 1
              result[:levels] += gained
            end
          rescue StandardError => e
            result[:errors] += 1
            name = entry[:pokemon].respond_to?(:name) ? entry[:pokemon].name : "Pokemon"
            log_exception("Super Candy could not level #{name}", e)
          end
          result
        end

        def advance_pokemon(pokemon, target, party)
          gained = 0
          while current_level(pokemon) < target
            before = current_level(pokemon)
            break unless advance_one_level(pokemon, party)
            after = current_level(pokemon)
            break if after <= before
            gained += after - before
          end
          gained
        end

        def advance_one_level(pokemon, party)
          old_level = current_level(pokemon)
          next_level = old_level + 1
          current_levels = Array(party).map do |party_member|
            party_member ? current_level(party_member) : nil
          end

          pokemon.level = next_level
          actual_level = current_level(pokemon)
          return false if actual_level <= old_level

          pokemon.changeHappiness("vitamin") if pokemon.respond_to?(:changeHappiness)
          pokemon.calc_stats if pokemon.respond_to?(:calc_stats)
          teach_level_moves(pokemon, actual_level)
          run_native_evolution_check(current_levels)
          true
        end

        def teach_level_moves(pokemon, level)
          moves = Array(pokemon.getMoveList).select do |entry|
            entry && entry[0].to_i == level.to_i
          end
          return true if moves.empty?

          teach = proc do
            moves.each do |entry|
              helper_receiver.__send__(:pbLearnMove, pokemon, entry[1], true)
            end
          end
          if defined?(KantoReloaded::QualityAssurance::MoveTeaching)
            KantoReloaded::QualityAssurance::MoveTeaching.with_context(:level_up) do
              teach.call
            end
          else
            teach.call
          end
          true
        end

        def run_native_evolution_check(current_levels)
          receiver = helper_receiver
          return false unless receiver.respond_to?(:pbEvolutionCheck, true)
          receiver.__send__(:pbEvolutionCheck, current_levels)
          true
        end

        def effective_target(pokemon, requested, kif_cap = kif_level_cap)
          limits = [normalize_level(requested), maximum_level, kif_cap]
          lock = personal_lock(pokemon)
          limits << lock if lock
          limits.compact.min
        end

        def personal_lock(pokemon)
          return nil unless defined?(KantoReloaded::LevelLocking)
          KantoReloaded::LevelLocking.lock_for(pokemon)
        rescue
          nil
        end

        def current_level(pokemon)
          if defined?(KantoReloaded::LevelLocking)
            return KantoReloaded::LevelLocking.current_level(pokemon)
          end
          return pokemon.level_simple.to_i if pokemon.respond_to?(:level_simple)
          pokemon.level.to_i
        rescue
          0
        end

        def maximum_level
          if defined?(KantoReloaded::LevelLocking)
            return KantoReloaded::LevelLocking.maximum_level
          end
          return GameData::GrowthRate.max_level if defined?(GameData::GrowthRate)
          100
        rescue
          100
        end

        def normalize_level(value)
          [[value.to_i, 1].max, maximum_level].min
        rescue
          1
        end

        def kif_level_cap
          receiver = helper_receiver
          cap = if receiver.respond_to?(:getkuraylevelcap, true)
                  receiver.__send__(:getkuraylevelcap)
                else
                  maximum_level
                end
          normalize_level(cap)
        rescue
          maximum_level
        end

        def highest_party_level(party)
          levels = Array(party).select { |pokemon| eligible?(pokemon) }.map do |pokemon|
            current_level(pokemon)
          end
          levels.empty? ? 1 : normalize_level(levels.max)
        rescue
          1
        end

        def helper_receiver
          @helper_receiver ||= Object.new
        end

        def show_result(result)
          lines = [
            _INTL(
              "Super Candy raised {1} Pokemon by {2} total levels.",
              result[:pokemon],
              result[:levels]
            )
          ]
          if result[:personal_limited] > 0
            lines << _INTL(
              "{1} Pokemon stopped at personal level locks.",
              result[:personal_limited]
            )
          end
          if result[:kif_limited] > 0
            lines << _INTL(
              "{1} Pokemon stopped at the KIF level cap.",
              result[:kif_limited]
            )
          end
          if result[:errors] > 0
            lines << _INTL(
              "{1} Pokemon could not be fully processed.",
              result[:errors]
            )
          end
          theme = result[:errors] > 0 ? :warning : :success
          KantoReloaded.message(lines.join("\n"), :theme => theme)
        end

        def register_action
          KantoReloaded::Settings.register(ACTION_KEY, {
            :name => "Super Candy",
            :description => "Raise eligible party Pokemon to a shared target while respecting level limits.",
            :type => :button,
            :category => :quality_of_life,
            :owner => :quality_assurance,
            :priority => SETTINGS_PRIORITY,
            :enabled_if => proc {
              KantoReloaded::QualityAssurance::SuperCandy.send(:party_available?) &&
                KantoReloaded::QualityAssurance::SuperCandy.send(:leveling_available?)
            },
            :on_press => proc {
              KantoReloaded::QualityAssurance::SuperCandy.open
            }
          })
        end

        def register_overworld_menu
          return false unless defined?(OverworldMenu) && OverworldMenu.respond_to?(:register)
          OverworldMenu.register(ACTION_KEY,
            :label => "Super Candy",
            :priority => OVERWORLD_PRIORITY,
            :default_enabled => false,
            :condition => proc {
              KantoReloaded::QualityAssurance::SuperCandy.send(:party_available?) &&
                KantoReloaded::QualityAssurance::SuperCandy.send(:leveling_available?)
            },
            :handler => proc { |screen|
              screen.run_with_overlay_hidden do
                KantoReloaded::QualityAssurance::SuperCandy.open
              end
              nil
            }
          )
        end

        def log_exception(message, exception)
          return unless defined?(KantoReloaded::Log)
          KantoReloaded::Log.exception(message, exception, channel: :modules)
        rescue
          nil
        end
      end
    end
  end
end

KantoReloaded::QualityAssurance::SuperCandy.install
