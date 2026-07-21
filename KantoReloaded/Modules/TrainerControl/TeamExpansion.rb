#==============================================================================
# Kanto Reloaded - Trainer Control Team Expansion
#==============================================================================

module KantoReloaded
  module TrainerControl
    module TeamExpansion
      MODE_SETTING = :trainer_control_expansion_mode
      SIZE_MODE_SETTING = :trainer_control_expansion_size_mode
      ADD_COUNT_SETTING = :trainer_control_expansion_add_count
      TARGET_SIZE_SETTING = :trainer_control_expansion_target_size
      LEADER_FULL_SETTING = :trainer_control_gym_leader_full_party
      HELD_ITEMS_SETTING = :trainer_control_expansion_held_items

      MODE_OFF = 0
      MODE_THEME = 1
      MODE_RANDOM = 2
      MODE_FUSION = 3
      SIZE_ADD = 0
      SIZE_TARGET = 1
      HELD_ITEMS_HALF = 0
      HELD_ITEMS_ALWAYS = 1
      ADDED_IVAR = :@kanto_reloaded_team_expansion

      TYPE_ITEMS = {
        :NORMAL => :SILKSCARF, :FIRE => :CHARCOAL, :WATER => :MYSTICWATER,
        :ELECTRIC => :MAGNET, :GRASS => :MIRACLESEED,
        :ICE => :NEVERMELTICE, :FIGHTING => :BLACKBELT,
        :POISON => :POISONBARB, :GROUND => :SOFTSAND,
        :FLYING => :SHARPBEAK, :PSYCHIC => :TWISTEDSPOON,
        :BUG => :SILVERPOWDER, :ROCK => :HARDSTONE,
        :GHOST => :SPELLTAG, :DRAGON => :DRAGONFANG,
        :DARK => :BLACKGLASSES, :STEEL => :METALCOAT
      }.freeze

      FALLBACK_LEGENDARIES = [
        :ARTICUNO, :ZAPDOS, :MOLTRES, :MEWTWO, :MEW,
        :ENTEI, :RAIKOU, :SUICUNE, :HOOH, :LUGIA, :CELEBI,
        :GROUDON, :KYOGRE, :RAYQUAZA, :DEOXYS, :JIRACHI, :LATIAS, :LATIOS,
        :REGIGIGAS, :DIALGA, :PALKIA, :GIRATINA, :DARKRAI, :CRESSELIA,
        :ARCEUS, :GENESECT, :RESHIRAM, :ZEKROM, :KYUREM, :MELOETTA,
        :NECROZMA, :U_NECROZMA
      ].freeze

      class DeterministicRng
        def initialize(seed)
          @state = seed.to_i & 0xFFFFFFFF
          @state = 0x6D2B79F5 if @state == 0
        end

        def next_u32
          @state = ((1_664_525 * @state) + 1_013_904_223) & 0xFFFFFFFF
        end

        def index(length)
          size = length.to_i
          return nil if size <= 0
          (next_u32 >> 8) % size
        end

        def pick(values)
          list = Array(values)
          selected = index(list.length)
          selected.nil? ? nil : list[selected]
        end
      end

      class << self
        def enabled?
          selection_mode != MODE_OFF
        end

        def selection_mode
          [[setting(MODE_SETTING, MODE_OFF).to_i, MODE_OFF].max, MODE_FUSION].min
        end

        def size_mode
          setting(SIZE_MODE_SETTING, SIZE_ADD).to_i == SIZE_TARGET ?
            SIZE_TARGET : SIZE_ADD
        end

        def add_count
          [[setting(ADD_COUNT_SETTING, 1).to_i, 1].max, 5].min
        end

        def target_size
          [[setting(TARGET_SIZE_SETTING, 3).to_i, 1].max, max_party_size].min
        end

        def leader_full_party?
          truthy?(setting(LEADER_FULL_SETTING, false))
        end

        def held_items_mode
          setting(HELD_ITEMS_SETTING, HELD_ITEMS_ALWAYS).to_i == HELD_ITEMS_ALWAYS ?
            HELD_ITEMS_ALWAYS : HELD_ITEMS_HALF
        end

        def apply(trainer, identity = nil)
          return 0 unless trainer && trainer.respond_to?(:party)
          original_party = Array(trainer.party).compact.dup
          return 0 if original_party.empty?

          leader = gym_leader?(trainer)
          force_full = leader && leader_full_party?
          return 0 unless enabled? || force_full

          desired_size = requested_size(original_party.length, force_full)
          desired_size = [desired_size, max_party_size].min
          return 0 if trainer.party.length >= desired_size

          gym_type = active_gym_type
          gym_type = gym_type_for(original_party) if !gym_type && force_full
          seed = deterministic_seed(trainer, identity, original_party, gym_type)
          rng = DeterministicRng.new(seed)
          item_rng = DeterministicRng.new(stable_hash("#{seed}|held_items"))
          used_species = existing_species_numbers(original_party)
          used_components = {}
          theme_types = weighted_party_types(original_party)
          level = original_average_level(original_party)
          added = 0
          failed_attempts = 0

          while trainer.party.length < desired_size && failed_attempts < 12
            candidate = choose_candidate(
              rng, selection_mode, gym_type, theme_types,
              used_species, used_components
            )
            break unless candidate
            pokemon = create_pokemon(candidate, level, trainer, rng)
            unless pokemon
              used_species[candidate[:number]] = true
              failed_attempts += 1
              next
            end
            pokemon.instance_variable_set(ADDED_IVAR, true)
            assign_generated_item(pokemon, item_rng, trainer.party)
            trainer.party << pokemon
            used_species[candidate[:number]] = true
            Array(candidate[:components]).each { |number| used_components[number] = true }
            added += 1
          end

          log_expansion(trainer, added, desired_size, gym_type) if added > 0
          added
        rescue StandardError => e
          KantoReloaded::Log.exception(
            "Trainer team expansion failed", e, channel: :trainer_control
          ) if defined?(KantoReloaded::Log)
          0
        end

        def clear_caches!
          @base_species = nil
          @type_pools = nil
          true
        end

        def adaptation_candidates(type = nil)
          pool = type ? type_pool(type) : selectable_base_species
          Array(pool).dup
        end

        def current_gym_type
          active_gym_type
        end

        def dominant_party_types(party)
          weighted_party_types(party).uniq
        end

        private

        def requested_size(original_size, force_full)
          return max_party_size if force_full
          return original_size unless enabled?
          if size_mode == SIZE_TARGET
            [original_size, target_size].max
          else
            original_size + add_count
          end
        end

        def choose_candidate(rng, mode, gym_type, theme_types,
                             used_species, used_components)
          if gym_type
            return choose_fusion(
              rng, gym_type, used_species, used_components
            ) if mode == MODE_FUSION
            return choose_base(rng, type_pool(gym_type), used_species)
          end

          case mode
          when MODE_THEME
            choose_themed_base(rng, theme_types, used_species)
          when MODE_RANDOM
            choose_base(rng, selectable_base_species, used_species)
          when MODE_FUSION
            choose_fusion(rng, nil, used_species, used_components)
          else
            nil
          end
        end

        def choose_themed_base(rng, theme_types, used_species)
          available_types = Array(theme_types).dup
          until available_types.empty?
            type = rng.pick(available_types)
            candidate = choose_base(rng, type_pool(type), used_species)
            return candidate if candidate
            available_types.delete(type)
          end
          choose_base(rng, selectable_base_species, used_species)
        end

        def choose_base(rng, pool, used_species)
          candidates = Array(pool).reject do |data|
            used_species[data.id_number.to_i]
          end
          data = rng.pick(candidates)
          return nil unless data
          {
            :id => data.id,
            :number => data.id_number.to_i,
            :components => []
          }
        end

        def choose_fusion(rng, required_type, used_species, used_components)
          available = selectable_base_species.reject do |data|
            used_components[data.id_number.to_i]
          end
          return nil if available.length < 2

          unless required_type
            first = rng.pick(available)
            remaining = available.reject { |data| data.id_number == first.id_number }
            second = rng.pick(remaining)
            return nil unless first && second
            head, body = rng.next_u32.even? ? [first, second] : [second, first]
            return build_fusion_candidate(head, body, nil, used_species)
          end

          typed_species = available.select do |data|
            species_types(data).include?(required_type)
          end
          return nil if typed_species.empty?

          96.times do
            anchor = rng.pick(typed_species)
            others = available.reject { |data| data.id_number == anchor.id_number }
            other = rng.pick(others)
            next unless anchor && other
            if rng.next_u32.even?
              head = anchor
              body = other
            else
              head = other
              body = anchor
            end
            candidate = build_fusion_candidate(
              head, body, required_type, used_species
            )
            return candidate if candidate
          end
          nil
        rescue StandardError
          nil
        end

        def build_fusion_candidate(head, body, required_type, used_species)
          return nil unless head && body
          head_number = head.id_number.to_i
          body_number = body.id_number.to_i
          return nil if head_number == body_number
          fusion_number = body_number * base_species_limit + head_number
          return nil if used_species[fusion_number]
          data = GameData::Species.try_get(fusion_number)
          return nil unless data
          return nil if required_type && !species_types(data).include?(required_type)
          {
            :id => data.id,
            :number => fusion_number,
            :components => [head_number, body_number]
          }
        rescue StandardError
          nil
        end

        def create_pokemon(candidate, level, trainer, rng)
          pokemon = Pokemon.new(candidate[:id], level, trainer)
          pokemon.personalID = rng.next_u32 if pokemon.respond_to?(:personalID=)
          pokemon.shiny = false if pokemon.respond_to?(:shiny=)
          if trainer.respond_to?(:male?) && pokemon.respond_to?(:gender=)
            pokemon.gender = trainer.male? ? 0 : 1
          end
          apply_trainer_values(pokemon, level)
          pokemon.calc_stats if pokemon.respond_to?(:calc_stats)
          pokemon
        rescue StandardError => e
          KantoReloaded::Log.exception(
            "Could not create expanded trainer Pokemon", e,
            channel: :trainer_control
          ) if defined?(KantoReloaded::Log)
          nil
        end

        def apply_trainer_values(pokemon, level)
          iv_value = [level.to_i / 2, pokemon_iv_limit].min
          ev_value = [level.to_i * 3 / 2, pokemon_ev_limit / 6].min
          if pokemon.respond_to?(:iv) && pokemon.iv.is_a?(Hash)
            pokemon.iv.keys.each { |key| pokemon.iv[key] = iv_value }
          end
          if pokemon.respond_to?(:ev) && pokemon.ev.is_a?(Hash)
            pokemon.ev.keys.each { |key| pokemon.ev[key] = ev_value }
          end
        rescue StandardError
          nil
        end

        def assign_generated_item(pokemon, rng, party = [])
          return false unless pokemon && pokemon.respond_to?(:item=)
          return false if pokemon.respond_to?(:item_id) && pokemon.item_id
          if held_items_mode == HELD_ITEMS_HALF
            return false unless rng.next_u32.even?
          end
          candidates = held_item_candidates(pokemon)
          blocked = Array(party).map do |member|
            member.item_id.to_s if member.respond_to?(:item_id) && member.item_id
          end.compact
          candidates.reject! { |item| blocked.include?(item.to_s) }
          selected = rng.pick(candidates)
          return false unless selected
          pokemon.item = selected
          true
        rescue StandardError
          false
        end

        def held_item_candidates(pokemon)
          candidates = [:SITRUSBERRY, :LUMBERRY, :EXPERTBELT]
          physical = 0
          special = 0
          status = 0
          Array(pokemon.moves).each do |move|
            data = GameData::Move.try_get(move.id) rescue nil
            next unless data
            if data.base_damage.to_i <= 0
              status += 1
            elsif data.respond_to?(:physical?) && data.physical?
              physical += 1
            elsif data.respond_to?(:special?) && data.special?
              special += 1
            end
          end
          if status >= 2
            candidates.concat([
              :LEFTOVERS, :FOCUSSASH, :ROCKYHELMET, :LIGHTCLAY,
              :MENTALHERB
            ])
          elsif physical > special
            candidates.concat([
              :MUSCLEBAND, :LIFEORB, :CHOICEBAND, :CHOICESCARF,
              :SCOPELENS
            ])
          elsif special > physical
            candidates.concat([
              :WISEGLASSES, :LIFEORB, :CHOICESPECS, :CHOICESCARF,
              :SCOPELENS
            ])
          else
            candidates.concat([
              :LEFTOVERS, :LIFEORB, :ASSAULTVEST, :SHELLBELL,
              :QUICKCLAW
            ])
          end
          pokemon_types = if pokemon.respond_to?(:types)
                            pokemon.types
                          else
                            [pokemon.type1, pokemon.type2]
                          end
          Array(pokemon_types).compact.each do |type|
            item = TYPE_ITEMS[normalize_type(type)]
            candidates << item if item
          end
          candidates.compact.uniq.select do |item|
            defined?(GameData::Item) && GameData::Item.exists?(item)
          end
        rescue StandardError
          []
        end

        def pokemon_iv_limit
          defined?(Pokemon::IV_STAT_LIMIT) ? Pokemon::IV_STAT_LIMIT.to_i : 31
        end

        def pokemon_ev_limit
          defined?(Pokemon::EV_LIMIT) ? Pokemon::EV_LIMIT.to_i : 510
        end

        def base_species
          return @base_species if @base_species
          values = []
          seen = {}
          if defined?(GameData::Species)
            GameData::Species.each do |data|
              number = data.id_number.to_i
              next if number <= 0 || number > base_species_limit
              next if data.respond_to?(:form) && data.form.to_i != 0
              next if seen[number] || forbidden_species?(data)
              seen[number] = true
              values << data
            end
          end
          @base_species = values.sort_by { |data| data.id_number.to_i }.freeze
        rescue StandardError => e
          KantoReloaded::Log.exception(
            "Could not build Trainer Control species pool", e,
            channel: :trainer_control
          ) if defined?(KantoReloaded::Log)
          @base_species = [].freeze
        end

        def type_pool(type)
          normalized = normalize_type(type)
          return [] unless normalized
          @type_pools ||= {}
          pool = @type_pools[normalized] ||= base_species.select do |data|
            species_types(data).include?(normalized)
          end.freeze
          npt_species_disabled? ? pool.reject { |data| npt_species?(data) } : pool
        end

        def selectable_base_species
          pool = base_species
          return pool unless npt_species_disabled?
          pool.reject { |data| npt_species?(data) }
        end

        def npt_species_disabled?
          defined?(::NPT::Toggle) &&
            ::NPT::Toggle.respond_to?(:new_pokemon_disabled?) &&
            ::NPT::Toggle.new_pokemon_disabled?
        rescue StandardError
          false
        end

        def npt_species?(data)
          return false unless defined?(::NPT::Toggle) &&
                              ::NPT::Toggle.respond_to?(:npt_species?)
          ::NPT::Toggle.npt_species?(data.id)
        rescue StandardError
          false
        end

        def forbidden_species?(data)
          id = data.respond_to?(:species) ? data.species : data.id
          id = id.to_sym rescue id
          return true if [:EGG, :MISSINGNO].include?(id)
          legends = FALLBACK_LEGENDARIES
          legends = legends | ::LEGENDARIES_LIST if defined?(::LEGENDARIES_LIST)
          legends.include?(id)
        rescue StandardError
          true
        end

        def weighted_party_types(party)
          counts = {}
          Array(party).each do |pokemon|
            data = pokemon_species_data(pokemon)
            species_types(data).each do |type|
              counts[type] = counts.fetch(type, 0) + 1
            end
          end
          weighted = []
          counts.sort_by { |type, count| [-count, type.to_s] }.each do |type, count|
            count.times { weighted << type }
          end
          weighted
        end

        def gym_type_for(original_party)
          active = active_gym_type
          return active if active
          weighted_party_types(original_party).first
        end

        def active_gym_type
          return nil unless defined?($game_variables) && $game_variables
          return nil unless defined?(VAR_CURRENT_GYM_TYPE) &&
                            defined?(VAR_GYM_TYPES_ARRAY)
          index = $game_variables[VAR_CURRENT_GYM_TYPE].to_i
          return nil if index < 0
          values = $game_variables[VAR_GYM_TYPES_ARRAY]
          return nil unless values.respond_to?(:[]) && index < values.length
          normalize_type(values[index])
        rescue StandardError
          nil
        end

        def normalize_type(value)
          return nil if value.nil? || !defined?(GameData::Type)
          data = GameData::Type.try_get(value) rescue nil
          if !data && (value.is_a?(String) || value.is_a?(Symbol))
            data = GameData::Type.try_get(value.to_s.upcase.to_sym) rescue nil
          end
          data ? data.id : nil
        end

        def species_types(data)
          return [] unless data
          values = if data.respond_to?(:types)
                     data.types
                   else
                     [data.type1, data.type2]
                   end
          Array(values).compact.map { |type| normalize_type(type) || type.to_sym }.
            compact.uniq
        rescue StandardError
          []
        end

        def pokemon_species_data(pokemon)
          return pokemon.species_data if pokemon.respond_to?(:species_data)
          GameData::Species.try_get(pokemon.species) if pokemon.respond_to?(:species)
        rescue StandardError
          nil
        end

        def existing_species_numbers(party)
          used = {}
          Array(party).each do |pokemon|
            data = pokemon_species_data(pokemon)
            used[data.id_number.to_i] = true if data
          end
          used
        end

        def original_average_level(party)
          levels = Array(party).map do |pokemon|
            next nil if pokemon.respond_to?(:egg?) && pokemon.egg?
            pokemon.level.to_i if pokemon.respond_to?(:level)
          end.compact.select { |level| level > 0 }
          return 1 if levels.empty?
          value = (levels.inject(0) { |sum, level| sum + level }.to_f / levels.length).round
          [[value, 1].max, maximum_level].min
        end

        def deterministic_seed(trainer, identity, party, gym_type)
          identity_key = if identity.is_a?(Hash)
                           identity["key"] || identity[:key]
                         end
          identity_key = "#{trainer.trainer_type}:#{trainer.name}" if identity_key.to_s.empty?
          signature = Array(party).map do |pokemon|
            data = pokemon_species_data(pokemon)
            data ? data.id_number.to_i : 0
          end.join(",")
          stable_hash([
            identity_key, signature, selection_mode, size_mode,
            add_count, target_size, gym_type, npt_species_disabled?
          ].join("|"))
        end

        def stable_hash(value)
          hash = 2_166_136_261
          value.to_s.each_byte do |byte|
            hash ^= byte
            hash = (hash * 16_777_619) & 0xFFFFFFFF
          end
          hash
        end

        def gym_leader?(trainer)
          type = trainer.respond_to?(:trainer_type) ? trainer.trainer_type.to_s.upcase : ""
          type.include?("LEADER")
        rescue StandardError
          false
        end

        def max_party_size
          value = defined?(::Settings::MAX_PARTY_SIZE) ?
                    ::Settings::MAX_PARTY_SIZE.to_i : 6
          value > 0 ? value : 6
        end

        def base_species_limit
          return ::Settings::NB_POKEMON.to_i if defined?(::Settings::NB_POKEMON)
          return NB_POKEMON.to_i if defined?(NB_POKEMON)
          501
        end

        def maximum_level
          return GameData::GrowthRate.max_level.to_i if defined?(GameData::GrowthRate)
          100
        rescue StandardError
          100
        end

        def setting(key, fallback)
          return fallback unless defined?(KantoReloaded::Settings)
          KantoReloaded::Settings.get(key, fallback)
        end

        def truthy?(value)
          value == true || (value.is_a?(Numeric) && value.to_i != 0) ||
            ["true", "on", "yes", "enabled", "1"].include?(value.to_s.downcase)
        end

        def log_expansion(trainer, added, target, gym_type)
          name = trainer.respond_to?(:name) ? trainer.name.to_s : "Trainer"
          suffix = gym_type ? " gym_type=#{gym_type}" : ""
          KantoReloaded::Log.debug(
            "Expanded #{name} by #{added} Pokemon target=#{target}#{suffix}",
            :trainer_control
          ) if defined?(KantoReloaded::Log)
        end
      end
    end
  end
end
