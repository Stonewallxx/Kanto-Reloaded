#==============================================================================
# Kanto Reloaded Quality of Life - Nature Selector
#==============================================================================

module KantoReloaded
  module QualityAssurance
    module NatureSelector
      ACTION_KEY = :nature_selector
      STAT_ORDER = [:ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED].freeze

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
          log_exception("Nature Selector failed", e)
          KantoReloaded.message(_INTL("Nature Selector could not be opened."), :theme => :error)
          false
        end

        def install
          register_action
          register_overworld_menu
          KantoReloaded::Log.info("Installed Nature Selector module", :modules) if defined?(KantoReloaded::Log)
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
              KantoReloaded.message(_INTL("Eggs don't have natures."), :theme => :warning)
              next
            end
            nature_id = choose_nature(pokemon)
            next if nature_id == -1
            changed = apply_nature(pokemon, nature_id)
            screen.pbRefreshSingle(chosen) if changed
          end
          true
        ensure
          screen.pbEndScene if started && screen
        end

        def choose_nature(pokemon)
          rows = nature_rows
          return -1 if rows.empty?
          current = pokemon.nature
          current_id = current ? current.id : nil
          start_index = rows.index { |row| row[:value] == current_id } || 0
          title = _INTL("Choose {1}'s nature.\nCurrent: {2}", pokemon.name, nature_label(current))
          KantoReloaded::UI::PopupWindow.choice(title, rows, :start_index => start_index)
        end

        def nature_rows
          data = []
          GameData::Nature.each do |nature|
            data << {
              :nature => nature,
              :label => nature_label(nature),
              :sort => nature_sort_key(nature)
            }
          end
          data.sort_by { |entry| entry[:sort] }.map do |entry|
            { :label => entry[:label], :value => entry[:nature].id }
          end
        end

        def nature_sort_key(nature)
          increased = Array(nature.stat_changes).find { |change| change[1].to_i > 0 }
          group = increased ? (STAT_ORDER.index(increased[0]) || STAT_ORDER.length) : STAT_ORDER.length
          [group, nature.name.to_s]
        end

        def nature_label(nature)
          return _INTL("Unknown") unless nature
          increases = []
          decreases = []
          Array(nature.stat_changes).each do |change|
            label = stat_label(change[0])
            increases << label if change[1].to_i > 0
            decreases << label if change[1].to_i < 0
          end
          return _INTL("{1} (Neutral)", nature.name) if increases.empty? && decreases.empty?
          _INTL("{1} (+{2}, -{3})", nature.name, increases.join("/"), decreases.join("/"))
        end

        def stat_label(stat_id)
          stat = GameData::Stat.get(stat_id)
          return stat.name_brief.to_s if stat.respond_to?(:name_brief)
          return stat.name.to_s if stat.respond_to?(:name)
          stat_id.to_s
        rescue
          stat_id.to_s
        end

        def apply_nature(pokemon, nature_id)
          nature = GameData::Nature.get(nature_id)
          old_nature = pokemon.nature
          old_name = old_nature ? old_nature.name : _INTL("Unknown")
          override = pokemon.respond_to?(:nature_for_stats_id) ? pokemon.nature_for_stats_id : nil
          return false if old_nature && old_nature.id == nature.id && !override
          pokemon.nature = nature.id
          if override && pokemon.respond_to?(:nature_for_stats=)
            pokemon.nature_for_stats = nil
          end
          KantoReloaded.toast_success(
            _INTL("{1}'s nature changed from {2} to {3}.", pokemon.name, old_name, nature.name)
          )
          true
        rescue StandardError => e
          log_exception("Could not change #{pokemon.name}'s nature", e)
          KantoReloaded.message(_INTL("That Pokemon's nature could not be changed."), :theme => :error)
          false
        end

        def register_action
          KantoReloaded::Settings.register(ACTION_KEY, {
            :name => "Nature Selector",
            :description => "Choose the nature and stat modifiers of a party Pokemon.",
            :type => :button,
            :category => :quality_of_life,
            :owner => :quality_assurance,
            :priority => 80,
            :enabled_if => proc { KantoReloaded::QualityAssurance::NatureSelector.send(:party_available?) },
            :on_press => proc { KantoReloaded::QualityAssurance::NatureSelector.open }
          })
        end

        def register_overworld_menu
          return false unless defined?(OverworldMenu) && OverworldMenu.respond_to?(:register)
          OverworldMenu.register(ACTION_KEY,
            :label => "Nature Selector",
            :priority => 18,
            :default_enabled => false,
            :condition => proc {
              KantoReloaded::QualityAssurance::NatureSelector.send(:party_available?)
            },
            :handler => proc { |screen|
              screen.run_with_overlay_hidden do
                KantoReloaded::QualityAssurance::NatureSelector.open
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

KantoReloaded::QualityAssurance::NatureSelector.install
