#==============================================================================
# Kanto Reloaded - Dynamic Items
#==============================================================================

module KantoReloaded
  module Randomizer
    module DynamicItems
      class << self
        def install
          return true if @installed
          @installed = KantoReloaded::Hooks.wrap(
            Object,
            :pbGetRandomItem,
            :randomizer_dynamic_items,
            :required => true
          ) do |hook, item_id, *_arguments|
            original = KantoReloaded::Randomizer::DynamicItems.resolve_item(item_id)
            next hook.call unless KantoReloaded::Randomizer.dynamic_items?
            next hook.call unless original
            next original if KantoReloaded::Randomizer::Pools.protected_item?(original)
            KantoReloaded::Randomizer::DynamicItems.transform(original)
          end
          @installed
        end

        def resolve_item(item)
          return nil if item.nil?
          GameData::Item.get(item)
        rescue StandardError
          nil
        end

        def transform(item)
          resolved = resolve_item(item)
          return item unless resolved
          return resolved if KantoReloaded::Randomizer::Pools.protected_item?(resolved)

          kind = if resolved.is_TM?
                   return resolved unless base_switch(:SWITCH_RANDOM_TMS)
                   :tm
                 elsif resolved.is_berry?
                   return resolved unless base_switch(:SWITCH_RANDOM_ITEMS)
                   :berry
                 else
                   return resolved unless base_switch(:SWITCH_RANDOM_ITEMS)
                   :normal
                 end
          KantoReloaded::Randomizer::Pools.choose_item(kind) || resolved
        rescue StandardError => e
          KantoReloaded::Log.exception(
            "Dynamic item replacement failed", e, channel: :randomizer
          ) if defined?(KantoReloaded::Log)
          item
        end

        private

        def base_switch(name)
          return false unless Object.const_defined?(name) && $game_switches
          !!$game_switches[Object.const_get(name)]
        rescue StandardError
          false
        end
      end
    end
  end
end
