#==============================================================================
# Kanto Reloaded - Trainer Control Pink Slips UI
#==============================================================================

module KantoReloaded
  module TrainerControl
    module PinkSlipsUI
      class << self
        def choose_wager
          return nil unless defined?($Trainer) && $Trainer
          loop do
            index = choose_party_member
            return nil unless index && index >= 0
            pokemon = $Trainer.party[index]
            loop do
              action = KantoReloaded::PopupWindow.choice(
                _INTL("Wager {1}?", pokemon.name),
                [
                  { :label => _INTL("Wager"), :value => :wager },
                  { :label => _INTL("Summary"), :value => :summary },
                  { :label => _INTL("Choose Another"), :value => :back }
                ]
              )
              return index if action == :wager
              if action == :summary
                show_summary(index)
                next
              end
              break
            end
          end
        rescue StandardError => e
          log_exception("Could not choose Pink Slips wager", e)
          nil
        end

        def choose_prize(prizes)
          entries = Array(prizes)
          rows = entries.map do |entry|
            {
              :label => _INTL("{1}  Lv.{2}", entry["name"], entry["level"]),
              :value => entry
            }
          end
          return nil if rows.empty?
          start_index = 0
          loop do
            selected = KantoReloaded::PopupWindow.choice(
              _INTL("Choose the Pokemon you won."), rows,
              :start_index => start_index
            )
            unless selected.is_a?(Hash)
              decline = KantoReloaded::PopupWindow.confirm(
                _INTL("Forfeit your Pink Slips prize?"),
                :default => false
              )
              return nil if decline
              next
            end
            start_index = entries.index(selected) || start_index
            loop do
              action = KantoReloaded::PopupWindow.choice(
                _INTL("Choose what to do with {1}.", selected["name"]),
                [
                  { :label => _INTL("Claim"), :value => :claim },
                  { :label => _INTL("Summary"), :value => :summary },
                  { :label => _INTL("Choose Another"), :value => :back }
                ]
              )
              return selected if action == :claim
              if action == :summary
                show_prize_summary(entries, selected)
                next
              end
              break
            end
          end
        rescue StandardError => e
          log_exception("Could not choose Pink Slips prize", e)
          Array(prizes).first
        end

        private

        def choose_party_member
          scene = PokemonParty_Scene.new
          screen = PokemonPartyScreen.new(scene, $Trainer.party)
          screen.pbChooseAblePokemon(
            proc do |pokemon|
              index = $Trainer.party.index(pokemon)
              index && PinkSlips.wager_candidate?(pokemon, index)
            end,
            false
          )
        end

        def show_summary(index)
          scene = PokemonSummary_Scene.new
          PokemonSummaryScreen.new(scene).pbStartScreen($Trainer.party, index)
        rescue StandardError => e
          log_exception("Could not show Pink Slips wager summary", e)
        end

        def show_prize_summary(entries, selected)
          party = Array(entries).map { |entry| entry["pokemon"] }.compact
          pokemon = selected["pokemon"]
          index = party.index(pokemon)
          return false unless pokemon && index
          scene = PokemonSummary_Scene.new
          PokemonSummaryScreen.new(scene).pbStartScreen(party, index)
          true
        rescue StandardError => e
          log_exception("Could not show Pink Slips prize summary", e)
          false
        end

        def log_exception(message, error)
          KantoReloaded::Log.exception(
            message, error, channel: :trainer_control
          ) if defined?(KantoReloaded::Log)
        end
      end
    end
  end
end
