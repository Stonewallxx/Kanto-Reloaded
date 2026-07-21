#==============================================================================
# Kanto Reloaded Quality of Life - Level Lock Manager
#==============================================================================

module KantoReloaded
  module QualityAssurance
    module LevelLockManager
      ACTION_KEY = :level_lock_manager

      class << self
        def open
          party = current_party
          unless party && !party.empty?
            KantoReloaded.message(_INTL("There are no Pokemon in the party."), :theme => :warning)
            return false
          end
          return run_party_session(party) unless defined?(pbFadeOutIn)
          result = false
          pbFadeOutIn { result = run_party_session(party) }
          result
        rescue StandardError => e
          log_exception("Level Lock Manager failed", e)
          KantoReloaded.message(_INTL("Level Lock Manager could not be opened."), :theme => :error)
          false
        end

        def install
          register_action
          register_overworld_menu
          KantoReloaded::Log.info("Installed Level Lock Manager module", :modules) if defined?(KantoReloaded::Log)
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

        def party_available?
          party = current_party
          party && !party.empty?
        end

        def locked_party_count
          Array(current_party).count do |pokemon|
            KantoReloaded::LevelLocking.lock_for(pokemon)
          end
        rescue
          0
        end

        def run_party_session(party)
          scene = PokemonParty_Scene.new
          screen = PokemonPartyScreen.new(scene, party)
          started = false
          screen.pbStartScene(_INTL("Choose a Pokemon."), false)
          started = true
          loop do
            chosen = screen.pbChoosePokemon(_INTL("Choose a Pokemon."))
            break if !chosen || chosen < 0
            pokemon = party[chosen]
            next unless pokemon
            if pokemon.egg?
              KantoReloaded.message(_INTL("Eggs can't have level locks."), :theme => :warning)
              next
            end
            manage_pokemon(pokemon)
            screen.pbRefreshSingle(chosen) if screen.respond_to?(:pbRefreshSingle)
          end
          true
        ensure
          screen.pbEndScene if started && screen
        end

        def manage_pokemon(pokemon)
          loop do
            lock = KantoReloaded::LevelLocking.lock_for(pokemon)
            rows = [
              {
                :label => lock ? _INTL("Change Level Lock") : _INTL("Set Level Lock"),
                :value => :set
              }
            ]
            rows << { :label => _INTL("Remove Level Lock"), :value => :remove } if lock
            rows << { :label => _INTL("Back"), :value => :back }
            title = lock ?
              _INTL("{1}'s level lock: Lv. {2}", pokemon.name, lock) :
              _INTL("{1} has no level lock.", pokemon.name)
            choice = KantoReloaded::PopupWindow.choice(title, rows)
            return if choice == -1 || choice == :back
            if choice == :set
              choose_and_set_lock(pokemon, lock)
            elsif choice == :remove
              remove_lock(pokemon)
            end
          end
        end

        def choose_and_set_lock(pokemon, current_lock)
          current_level = KantoReloaded::LevelLocking.current_level(pokemon)
          maximum_level = KantoReloaded::LevelLocking.maximum_level
          start_level = current_lock || current_level
          selected = KantoReloaded::NumberPicker.open(
            _INTL("Set {1}'s maximum level.", pokemon.name),
            :min => current_level,
            :max => maximum_level,
            :initial => start_level
          )
          return false if selected.nil?
          if KantoReloaded::LevelLocking.set_lock(pokemon, selected)
            KantoReloaded.toast_success(
              _INTL("{1}'s level lock was set to Lv. {2}.", pokemon.name, selected)
            )
            true
          else
            KantoReloaded.toast_error(_INTL("That level lock could not be set."))
            false
          end
        end

        def remove_lock(pokemon)
          lock = KantoReloaded::LevelLocking.lock_for(pokemon)
          return false unless lock
          return false unless KantoReloaded.confirm(
            _INTL("Remove {1}'s Lv. {2} level lock?", pokemon.name, lock),
            :default => false
          )
          if KantoReloaded::LevelLocking.clear_lock(pokemon)
            KantoReloaded.toast_success(_INTL("{1}'s level lock was removed.", pokemon.name))
            true
          else
            KantoReloaded.toast_error(_INTL("That level lock could not be removed."))
            false
          end
        end

        def register_action
          KantoReloaded::Settings.register(ACTION_KEY, {
            :name => "Manage Level Locks",
            :description => "Set or remove an individual maximum level for each party Pokemon.",
            :type => :button,
            :category => :quality_of_life,
            :owner => :quality_assurance,
            :priority => 81,
            :enabled_if => proc {
              KantoReloaded::QualityAssurance::LevelLockManager.send(:party_available?)
            },
            :on_press => proc {
              KantoReloaded::QualityAssurance::LevelLockManager.open
            }
          })
        end

        def register_overworld_menu
          return false unless defined?(OverworldMenu) && OverworldMenu.respond_to?(:register)
          OverworldMenu.register(ACTION_KEY,
            :label => "Level Lock Manager",
            :priority => 22,
            :default_enabled => false,
            :status => proc {
              count = KantoReloaded::QualityAssurance::LevelLockManager.send(:locked_party_count)
              count > 0 ? "#{count} Locked" : "No Locks"
            },
            :condition => proc {
              KantoReloaded::QualityAssurance::LevelLockManager.send(:party_available?)
            },
            :handler => proc { |screen|
              screen.run_with_overlay_hidden do
                KantoReloaded::QualityAssurance::LevelLockManager.open
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

KantoReloaded::QualityAssurance::LevelLockManager.install
