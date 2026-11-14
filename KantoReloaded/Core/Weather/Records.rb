# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Weather System, Weather Records
#==============================================================================
# Stage 7 (his pick, 2026-11-13: Design 1, Weather Tab). Battles won in each
# weather are counted (the weather on the map as the battle started; Heavy
# Rain counts as rain, a blizzard as snow, strong winds as wind), kept by
# the save. The Trainer Card's Weather tab (after Stats) shows them, your
# favourite weather and the next weather title. Ten wins in a weather earn
# its title (Trainer Card > Style), with the New Unlock toast:
#
#   Rain Dancer, Storm Chaser, Sun Seeker, Windrider, Fog Walker,
#   Snow Drifter, Dune Runner, Ash Walker
#==============================================================================

module Reloaded
  module Weather
    module Records
      # [kind, the word on the card, the title, what it asks]
      KINDS = [[:Rain, "Rain", :weather_rain, "Rain Dancer", "Win 10 Battles in Rain"],
               [:Storm, "Storm", :weather_storm, "Storm Chaser", "Win 10 Battles in a Storm"],
               [:Sunny, "Sun", :weather_sun, "Sun Seeker", "Win 10 Battles in Sun"],
               [:Wind, "Wind", :weather_wind, "Windrider", "Win 10 Battles in Wind"],
               [:Fog, "Fog", :weather_fog, "Fog Walker", "Win 10 Battles in Fog"],
               [:Snow, "Snow", :weather_snow, "Snow Drifter", "Win 10 Battles in Snow"],
               [:Sandstorm, "Sandstorm", :weather_sandstorm, "Dune Runner", "Win 10 Battles in a Sandstorm"],
               [:Ash, "Ash", :weather_ash, "Ash Walker", "Win 10 Battles in Ash"]].freeze
      TITLE_AT = 10

      class << self
        def install
          return if @installed
          @installed = true
          if defined?(::PokeBattle_Battle) && ::PokeBattle_Battle.method_defined?(:pbEndOfBattle)
            Reloaded::Hooks.around(FEATURE, ::PokeBattle_Battle, :pbEndOfBattle, :id => :weather_records) do |original, *args|
              ret = original.call(*args)
              Reloaded::Weather::Records.battle_ended(original.receiver)
              ret
            end
          end
          register_titles
        end

        def register_titles
          return unless defined?(Reloaded::TrainerCard::Unlocks)
          KINDS.each do |kind, _word, id, title, need|
            Reloaded::TrainerCard::Unlocks.register(:titles, id, :name => title, :need => need, :from => "Weather System",
              :check => proc { Reloaded::Weather::Records.wins(kind) >= TITLE_AT })
          end
        end

        # The kind a weather counts as (nil: none, or not one counted)
        def kind_of(type)
          t = Display.base(type)
          return KINDS.any? { |k, *_r| k == t } ? t : nil
        end

        def table
          d = Reloaded::Weather.data
          return nil unless d
          return (d["records"] ||= {})
        end

        def wins(kind)
          t = table
          return t ? t[kind.to_s].to_i : 0
        end

        def all_wins
          return KINDS.sum { |k, *_r| wins(k) }
        end

        # A battle won in a weather: counted (and its title, at ten)
        def battle_ended(battle)
          return unless Reloaded::Weather.on?
          return unless battle.instance_variable_get(:@decision) == 1
          info = Battle.info(battle)
          kind = info && info[:record]
          return unless kind && table
          table[kind.to_s] = wins(kind) + 1
          Reloaded::TrainerCard::Unlocks.check if defined?(Reloaded::TrainerCard::Unlocks)
        rescue StandardError => e
          Reloaded::Log.exception("Weather: a weather win couldn't be counted", e, :weather)
        end

        # [kind, word, wins] of the weather you've won most in, or nil
        def favorite
          best = KINDS.max_by { |k, *_r| wins(k) }
          return nil unless best && wins(best[0]) > 0
          return [best[0], best[1], wins(best[0])]
        end

        # [title, wins, of] of the nearest title not earned yet, or nil
        def next_title
          left = KINDS.select { |k, *_r| wins(k) < TITLE_AT }
          return nil if left.empty?
          k = left.max_by { |kk, *_r| wins(kk) }
          return [k[3], wins(k[0]), TITLE_AT]
        end
      end
    end
  end
end
