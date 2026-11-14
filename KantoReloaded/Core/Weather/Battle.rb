# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Weather System, the weather in battle
#==============================================================================
# Stage 2 (his picks, 2026-11-13). PIF already brings the map's weather into
# battle by its kind (rain, a storm or heavy rain: Rain; snow or a blizzard:
# Hail, or Snow by KIF's Modern Hail; sun: Sun, never after dark, as the map
# shows none; wind: Strong Winds). While the Weather System is On:
#
#   Wind          everyday wind gives one side Tailwind for 4 turns and
#                 nothing else (PIF made every breeze Strong Winds)
#   Strong Winds  (wind at 8+) PIF's full Strong Winds, and the Tailwind
#   Fog           outdoors, every move is less accurate, for both sides, by
#                 the fog's strength: x0.9 in light fog to x0.6 in thick fog;
#                 moves that never miss still never miss. A FOG chip with the
#                 accuracy leads the Battle Menu's Field Strip (Battle Info's
#                 Field tab too), on both battle screens.
#
# A battle that sets its own weather (a script's battle rule) keeps it, and
# no fog. Hoenn Essentials' own fog misses stand aside (Link.rb).
#==============================================================================

module Reloaded
  module Weather
    module Battle
      FOG_LIGHT = 0.9            # accuracy in the lightest fog
      FOG_THICK = 0.6            # and in the thickest (10)

      # Wind, and the fog's word at the start (the weather's own lines are PIF's)
      module BattleStart
        def pbApplyBattleStartWeatherEffects(*args)
          ret = super
          Reloaded::Weather::Battle.battle_start(self)
          return ret
        end
      end

      # Fog: every move less accurate (moves that never miss return before this)
      module FogAccuracy
        def pbCalcAccuracyModifiers(user, target, modifiers)
          ret = super
          m = Reloaded::Weather::Battle.fog_multiplier(@battle)
          modifiers[:accuracy_multiplier] *= m if m && modifiers.is_a?(Hash) && modifiers[:accuracy_multiplier]
          return ret
        end
      end

      class << self
        def install
          return if @installed
          @installed = true
          h = Reloaded::Hooks
          if Object.private_method_defined?(:pbPrepareBattle) || Object.method_defined?(:pbPrepareBattle)
            h.around(FEATURE, Object, :pbPrepareBattle, :id => :weather_battle) do |original, battle, *rest|
              ret = original.call(battle, *rest)
              Reloaded::Weather::Battle.prepare(battle)
              ret
            end
          end
          h.prepend(FEATURE, ::PokeBattle_Battle, BattleStart, :id => :weather_battle_start) if defined?(::PokeBattle_Battle)
          h.prepend(FEATURE, ::PokeBattle_Move, FogAccuracy, :id => :weather_fog_accuracy) if defined?(::PokeBattle_Move)
        end

        # After PIF set the battle's weather from the map's
        def prepare(battle)
          return unless battle
          battle.instance_variable_set(:@reloaded_weather, nil)
          return unless Reloaded::Weather.on?
          rules = defined?($PokemonTemp) && $PokemonTemp ? ($PokemonTemp.battleRules rescue {}) : {}
          return if rules.is_a?(Hash) && !rules["defaultWeather"].nil?
          return unless defined?($game_screen) && $game_screen
          info = {}
          case $game_screen.weather_type
          when :Wind
            battle.defaultWeather = :None if battle.respond_to?(:defaultWeather=)
            info[:tailwind] = true
          when :Fog
            info[:fog] = screen_strength if outdoors?
          end
          # Weather Records: the weather this battle counts for if it's won
          kind = defined?(Records) && outdoors? ? Records.kind_of($game_screen.weather_type) : nil
          info[:record] = kind if kind
          battle.instance_variable_set(:@reloaded_weather, info) unless info.empty?
        rescue StandardError => e
          Reloaded::Log.exception("Weather: the battle's weather couldn't be set", e, :weather)
        end

        def info(battle)
          v = battle ? battle.instance_variable_get(:@reloaded_weather) : nil
          return v.is_a?(Hash) ? v : nil
        end

        # After the weather's own line: the wind's side (as PIF's Strong Winds
        # does, the side Hoenn Native's Pokémon set when they have one), the fog
        def battle_start(battle)
          w = info(battle)
          return unless w
          if w[:tailwind] && battle.field.weather != :StrongWinds
            side = battle.wind_side.nil? ? battle.pbRandom(2) : battle.wind_side.to_i
            side = 0 unless [0, 1].include?(side)
            battle.sides[side].effects[PBEffects::Tailwind] = 4
            if side == 0
              battle.pbDisplay(_INTL("The wind is blowing from your side."))
            else
              battle.pbDisplay(_INTL("The wind is blowing from the opponent's side."))
            end
          end
          battle.pbDisplay(_INTL("The fog is deep.")) if w[:fog]
        rescue StandardError => e
          Reloaded::Log.exception("Weather: the battle's wind couldn't start", e, :weather)
        end

        # The fog's accuracy (1..10: x0.9 .. x0.6), nil without fog
        def fog_multiplier(battle)
          w = info(battle)
          return nil unless w && w[:fog]
          return accuracy_for(w[:fog])
        end

        def accuracy_for(strength)
          s = [[strength.to_i, 1].max, 10].min
          return (FOG_LIGHT - (s - 1) * (FOG_LIGHT - FOG_THICK) / 9.0).round(3)
        end

        def accuracy_label(strength)
          return format("x%.1f", accuracy_for(strength))
        end

        # Battle Menu's Field Strip and Battle Info's Field tab: the fog first
        # ([words, the accuracy in the turns' place, :field, no type, Battle
        # Info's longer words])
        def field_items(battle)
          w = info(battle)
          return [] unless w && w[:fog]
          return [[_INTL("Fog"), accuracy_label(w[:fog]), :field, nil, _INTL("Fog: Less Accurate")]]
        end

        # The weather's strength on the map now: ours, or a script's (its power)
        def screen_strength
          map = $game_map ? $game_map.map_id : nil
          w = map ? Reloaded::Weather.map_weather(map) : nil
          return w[1] if w && w[0] == $game_screen.weather_type && !Reloaded::Weather.external?(map)
          most = defined?(::RPG::Weather::MAX_SPRITES) ? ::RPG::Weather::MAX_SPRITES : 60
          power = ($game_screen.weather_max.to_f * 10 / most).round - 1
          return [[power, 1].max, 10].min
        rescue StandardError
          return 5
        end

        def outdoors?
          return false unless $game_map
          meta = GameData::MapMetadata.try_get($game_map.map_id) rescue nil
          return meta && meta.outdoor_map ? true : false
        end
      end
    end
  end
end
