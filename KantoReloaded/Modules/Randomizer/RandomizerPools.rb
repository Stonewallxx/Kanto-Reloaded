#==============================================================================
# Kanto Reloaded - Randomizer Pools
#==============================================================================
# Bounded candidate selection and cached metadata for dynamic randomization.
# The legacy Dynamic Randomiser concept was created by An Unsocial Pigeon.
#==============================================================================

module KantoReloaded
  module Randomizer
    module Pools
      ATTEMPTS_PER_RANGE = 48
      RANGE_EXPANSIONS = [0, 25, 50, 100, 200, 9999].freeze
      INTERNAL_ITEM_TOKENS = ["DEBUG", "DUMMY", "PLACEHOLDER", "UNUSED", "INVALID"].freeze

      class << self
        def choose_species(source_species, recent_species = [])
          source_id = species_number(source_species)
          return source_species unless source_id && source_id > 0
          return source_species if protected_species?(source_id)

          use_bst_range = KantoReloaded::Randomizer.use_bst_range?
          target_bst = use_bst_range ? species_bst(source_id) : nil
          return source_species if use_bst_range && !target_bst
          custom_only = base_switch(:SWITCH_RANDOM_WILD_ONLY_CUSTOMS)
          source_legendary = legendary?(source_id)
          allow_legendaries = base_switch(:SWITCH_RANDOM_WILD_LEGENDARIES)
          recent = Array(recent_species).map { |value| species_number(value) }.compact
          recent_candidate = nil

          range_expansions = use_bst_range ? RANGE_EXPANSIONS : [9999]
          range_expansions.each do |increase|
            allowed_range = increase == 9999 ? increase : bst_range + increase
            ATTEMPTS_PER_RANGE.times do
              candidate = random_species_id(custom_only)
              next unless candidate && candidate > 0
              next if candidate == source_id
              next unless species_allowed?(
                candidate, target_bst, allowed_range,
                source_legendary, allow_legendaries, use_bst_range
              )
              if recent.include?(candidate)
                recent_candidate ||= candidate
                next
              end
              return candidate
            end
          end
          recent_candidate || source_species
        rescue StandardError => e
          log_exception("Dynamic species selection failed", e)
          source_species
        end

        def choose_item(kind)
          candidates = item_pool(kind)
          return nil if candidates.empty?
          candidates[rand(candidates.length)]
        rescue StandardError => e
          log_exception("Dynamic item selection failed", e)
          nil
        end

        def protected_item?(item)
          return true unless item
          return true if item.respond_to?(:is_key_item?) && item.is_key_item?
          return true if item.respond_to?(:is_HM?) && item.is_HM?
          return true if item.respond_to?(:id_number) && item.id_number.to_i < 0
          return true if protected_item_ids.include?(item.id)
          item_id = item.id.to_s.upcase
          INTERNAL_ITEM_TOKENS.any? { |token| item_id.include?(token) }
        rescue StandardError
          true
        end

        def clear!
          @item_pools = nil
          @protected_item_ids = nil
          @custom_species_ids = nil
          @species_bst = nil
          @legendary = nil
          true
        end

        private

        def item_pool(kind)
          @item_pools ||= {}
          key = kind.to_sym
          return @item_pools[key] if @item_pools.has_key?(key)
          values = GameData::Item.list_all.values
          @item_pools[key] = values.select do |item|
            next false if protected_item?(item)
            case key
            when :tm
              item.is_TM?
            when :berry
              item.is_berry?
            else
              !item.is_machine? && !item.is_key_item? && !item.is_berry?
            end
          end
        end

        def protected_item_ids
          return @protected_item_ids if @protected_item_ids
          ids = []
          [:NON_RANDOMIZE_ITEMS, :INVALID_ITEMS, :RANDOM_ITEM_EXCEPTIONS].each do |name|
            ids.concat(Array(Object.const_get(name))) if Object.const_defined?(name)
          end
          @protected_item_ids = ids.compact.map { |id| id.to_sym }.uniq
        end

        def random_species_id(custom_only)
          if custom_only
            candidates = custom_species_ids
            return nil if candidates.empty?
            return candidates[rand(candidates.length)]
          end
          maximum = species_upper_bound
          return nil if maximum < 1
          rand(maximum) + 1
        end

        def custom_species_ids
          return @custom_species_ids if @custom_species_ids
          values = runtime_custom_species
          if values.empty? && Object.private_method_defined?(:getCustomSpeciesList)
            values = Object.new.send(:getCustomSpeciesList, false)
          end
          @custom_species_ids = Array(values).map do |value|
            species_number(value)
          end.compact.select do |value|
            value > 0 && value <= species_upper_bound
          end.uniq
        rescue StandardError => e
          log_exception("Custom sprite species cache failed", e)
          @custom_species_ids = []
        end

        def runtime_custom_species
          return [] unless $game_temp && $game_temp.respond_to?(:custom_sprites_list)
          list = $game_temp.custom_sprites_list
          return list.keys if list.respond_to?(:keys)
          Array(list)
        rescue StandardError
          []
        end

        def species_allowed?(candidate, target_bst, allowed_range,
                             source_legendary, allow_legendaries, use_bst_range)
          if use_bst_range
            candidate_bst = species_bst(candidate)
            return false unless candidate_bst
            return false if (candidate_bst - target_bst).abs > allowed_range
          end
          candidate_legendary = legendary?(candidate)
          return candidate_legendary if source_legendary
          allow_legendaries || !candidate_legendary
        end

        def species_bst(species)
          @species_bst ||= {}
          number = species_number(species)
          return nil unless number
          return @species_bst[number] if @species_bst.has_key?(number)
          stats = GameData::Species.get(number).base_stats
          total = 0
          [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED].each do |stat|
            total += stats[stat].to_i
          end
          @species_bst[number] = total
        rescue StandardError
          @species_bst[number] = nil if number
          nil
        end

        def legendary?(species)
          @legendary ||= {}
          number = species_number(species)
          return false unless number
          return @legendary[number] if @legendary.has_key?(number)
          value = if Object.private_method_defined?(:is_legendary)
                    Object.new.send(:is_legendary, number)
                  else
                    false
                  end
          @legendary[number] = !!value
        rescue StandardError
          @legendary[number] = false if number
          false
        end

        def species_number(species)
          return species.to_i if species.is_a?(Integer)
          if Object.private_method_defined?(:dexNum)
            return Object.new.send(:dexNum, species).to_i
          end
          GameData::Species.get(species).id_number.to_i
        rescue StandardError
          nil
        end

        def protected_species?(number)
          if defined?(Settings::RIVAL_STARTER_PLACEHOLDER_SPECIES)
            return true if number == Settings::RIVAL_STARTER_PLACEHOLDER_SPECIES.to_i
          end
          defined?(Settings::ZAPMOLCUNO_NB) && number >= Settings::ZAPMOLCUNO_NB.to_i
        end

        def species_upper_bound
          maximum = defined?(PBSpecies) ? PBSpecies.maxValue.to_i : 0
          if defined?(Settings::ZAPMOLCUNO_NB)
            maximum = [maximum, Settings::ZAPMOLCUNO_NB.to_i - 1].min
          end
          maximum
        end

        def bst_range
          value = if defined?(VAR_RANDOMIZER_WILD_POKE_BST) && $game_variables
                    $game_variables[VAR_RANDOMIZER_WILD_POKE_BST]
                  end
          [[value.to_i, 0].max, 500].min
        rescue StandardError
          50
        end

        def base_switch(name)
          return false unless Object.const_defined?(name) && $game_switches
          !!$game_switches[Object.const_get(name)]
        rescue StandardError
          false
        end

        def log_exception(message, error)
          KantoReloaded::Log.exception(
            message, error, channel: :randomizer
          ) if defined?(KantoReloaded::Log)
        end
      end
    end
  end
end
