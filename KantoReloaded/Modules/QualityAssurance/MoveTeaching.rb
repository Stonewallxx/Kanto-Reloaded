#==============================================================================
# Kanto Reloaded Quality of Life - Level-Up Move Learning
#==============================================================================

module KantoReloaded
  module QualityAssurance
    module MoveTeaching
      SETTING_KEY = :level_up_move_learning
      MODES = [:native, :ask, :skip].freeze
      MODE_NAMES = ["Native", "Ask", "Skip"].freeze

      class << self
        def mode_index
          value = KantoReloaded::Settings.get(SETTING_KEY, 0).to_i
          value >= 0 && value < MODES.length ? value : 0
        rescue
          0
        end

        def mode
          MODES[mode_index]
        end

        def mode_name
          MODE_NAMES[mode_index]
        end

        def cycle_mode
          next_index = (mode_index + 1) % MODES.length
          stored = KantoReloaded::Settings.set(SETTING_KEY, next_index)
          stored.nil? ? mode : MODES[stored.to_i] || :native
        rescue
          mode
        end

        def with_context(context)
          @context_stack ||= []
          @context_stack << context.to_sym
          yield
        ensure
          @context_stack.pop if @context_stack && !@context_stack.empty?
        end

        def current_context
          @context_stack && @context_stack.last
        end

        def handle_global(receiver, hook, pokemon, move)
          return hook.call unless current_context == :level_up
          return hook.call unless teachable?(pokemon, move)

          case mode
          when :skip
            receiver.__send__(
              :pbMessage,
              _INTL("{1} gained knowledge of {2}, but did not learn it.", pokemon.name, move_name(move)),
              &hook.block
            )
            false
          when :ask
            return hook.call unless open_move_slot?(pokemon)
            confirmed = receiver.__send__(
              :pbConfirmMessage,
              _INTL("Teach {1} to {2}?", move_name(move), pokemon.name),
              &hook.block
            )
            return hook.call if confirmed
            receiver.__send__(
              :pbMessage,
              _INTL("{1} did not learn {2}.", pokemon.name, move_name(move)),
              &hook.block
            )
            false
          else
            hook.call
          end
        end

        def handle_battle(battle, hook, party_index, move)
          return hook.call if mode == :native
          pokemon = battle_pokemon(battle, party_index)
          return hook.call unless player_owned?(pokemon)
          return hook.call unless teachable?(pokemon, move)

          case mode
          when :skip
            battle.__send__(
              :pbDisplayPaused,
              _INTL("{1} gained knowledge of {2}, but did not learn it.", pokemon.name, move_name(move))
            )
            nil
          when :ask
            return hook.call unless open_move_slot?(pokemon)
            confirmed = battle.__send__(
              :pbDisplayConfirm,
              _INTL("Teach {1} to {2}?", move_name(move), pokemon.name)
            )
            return hook.call if confirmed
            battle.__send__(
              :pbDisplayPaused,
              _INTL("{1} did not learn {2}.", pokemon.name, move_name(move))
            )
            nil
          else
            hook.call
          end
        end

        def install
          register_setting
          register_overworld_menu
          hooks_ready = register_hooks
          if defined?(KantoReloaded::Log)
            state = hooks_ready ? "ready" : "incomplete"
            KantoReloaded::Log.info("Installed Level-Up Move Learning module (hooks #{state})", :modules)
          end
          hooks_ready
        end

        private

        def register_setting
          KantoReloaded::Settings.register(SETTING_KEY, {
            :name => "Level-Up Move Learning",
            :description => "Controls whether level-up moves use native behavior, ask first, or are skipped.",
            :type => :enum,
            :category => :quality_of_life,
            :owner => :quality_assurance,
            :values => MODE_NAMES,
            :default => 0,
            :priority => 29
          })
        end

        def register_overworld_menu
          return false unless defined?(OverworldMenu) && OverworldMenu.respond_to?(:register)
          OverworldMenu.register(:level_up_move_learning,
            :label => "Level-Up Move Learning",
            :priority => 21,
            :default_enabled => false,
            :status => proc {
              KantoReloaded::QualityAssurance::MoveTeaching.mode_name
            },
            :handler => proc { |screen|
              KantoReloaded::QualityAssurance::MoveTeaching.cycle_mode
              name = KantoReloaded::QualityAssurance::MoveTeaching.mode_name
              screen.show_popup("LEVEL-UP MOVE LEARNING", ["Mode changed to #{name}."])
              nil
            }
          )
        end

        def register_hooks
          return false unless defined?(KantoReloaded::Hooks)

          global_ready = KantoReloaded::Hooks.wrap(
            Object,
            :pbLearnMove,
            :quality_of_life_level_up_move_learning_global
          ) do |hook, pokemon, move, *_arguments|
            KantoReloaded::QualityAssurance::MoveTeaching.handle_global(self, hook, pokemon, move)
          end

          level_context_ready = KantoReloaded::Hooks.wrap(
            Object,
            :pbChangeLevel,
            :quality_of_life_level_up_move_learning_context
          ) do |hook, *_arguments|
            KantoReloaded::QualityAssurance::MoveTeaching.with_context(:level_up) { hook.call }
          end

          evolution_context_ready = register_evolution_context
          battle_ready = register_battle_hook
          global_ready && level_context_ready && evolution_context_ready && battle_ready
        end

        def register_evolution_context
          return false unless defined?(::PokemonEvolutionScene)
          KantoReloaded::Hooks.wrap(
            ::PokemonEvolutionScene,
            :pbEvolution,
            :quality_of_life_level_up_move_learning_evolution_context
          ) do |hook, *_arguments|
            KantoReloaded::QualityAssurance::MoveTeaching.with_context(:evolution) { hook.call }
          end
        end

        def register_battle_hook
          return false unless defined?(::PokeBattle_Battle)
          KantoReloaded::Hooks.wrap(
            ::PokeBattle_Battle,
            :pbLearnMove,
            :quality_of_life_level_up_move_learning_battle
          ) do |hook, party_index, move, *_arguments|
            KantoReloaded::QualityAssurance::MoveTeaching.handle_battle(
              self, hook, party_index, move
            )
          end
        end

        def teachable?(pokemon, move)
          return false unless pokemon
          return false if pokemon.respond_to?(:egg?) && pokemon.egg? && !debug_mode?
          return false if pokemon.respond_to?(:shadowPokemon?) && pokemon.shadowPokemon?
          return false if pokemon.respond_to?(:hasMove?) && pokemon.hasMove?(move)
          !GameData::Move.get(move).nil?
        rescue
          false
        end

        def open_move_slot?(pokemon)
          count = if pokemon.respond_to?(:numMoves)
                    pokemon.numMoves.to_i
                  elsif pokemon.respond_to?(:moves)
                    pokemon.moves.length
                  else
                    return false
                  end
          maximum = defined?(Pokemon::MAX_MOVES) ? Pokemon::MAX_MOVES : 4
          count < maximum
        rescue
          false
        end

        def battle_pokemon(battle, party_index)
          party = battle.__send__(:pbParty, 0)
          party && party[party_index]
        rescue
          nil
        end

        def player_owned?(pokemon)
          return false unless pokemon && defined?($Trainer) && $Trainer
          return false unless $Trainer.respond_to?(:party)
          $Trainer.party.any? { |party_member| party_member.equal?(pokemon) }
        rescue
          false
        end

        def move_name(move)
          GameData::Move.get(move).name
        rescue
          move.to_s
        end

        def debug_mode?
          defined?($DEBUG) && $DEBUG
        end
      end
    end
  end
end

KantoReloaded::QualityAssurance::MoveTeaching.install
