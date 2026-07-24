#==============================================================================
# Kanto Reloaded - Dynamic Wild Pokemon
#==============================================================================

module KantoReloaded
  module Randomizer
    module DynamicWildPokemon
      class << self
        def install
          return true if @installed
          return false unless defined?(PokemonEncounters)
          @installed = KantoReloaded::Hooks.wrap(
            PokemonEncounters,
            :choose_wild_pokemon,
            :randomizer_dynamic_wild,
            :required => true
          ) do |hook, *_arguments|
            encounter = hook.call
            KantoReloaded::Randomizer::DynamicWildPokemon.transform(encounter)
          end
          @installed
        end

        def transform(encounter)
          return encounter unless KantoReloaded::Randomizer.dynamic_wild?
          return encounter unless encounter.is_a?(Array) && encounter.length >= 2
          replacement = KantoReloaded::Randomizer::Pools.choose_species(
            encounter[0], KantoReloaded::Randomizer.recent_species
          )
          return encounter if replacement.nil?
          result = encounter.dup
          result[0] = replacement
          KantoReloaded::Randomizer.remember_species(replacement)
          result
        rescue StandardError => e
          KantoReloaded::Log.exception(
            "Dynamic wild encounter failed", e, channel: :randomizer
          ) if defined?(KantoReloaded::Log)
          encounter
        end
      end
    end
  end
end
