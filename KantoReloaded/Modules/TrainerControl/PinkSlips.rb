#==============================================================================
# Kanto Reloaded - Trainer Control Pink Slips
#==============================================================================

module KantoReloaded
  module TrainerControl
    module PinkSlips
      ENABLED_SETTING = :trainer_control_pink_slips
      REPEAT_SETTING = :trainer_control_pink_slips_repeat
      MEMBER_IVAR = :@kanto_reloaded_pink_slip_id
      APPLIED_IVAR = :@kanto_reloaded_pink_slip_operations
      MAX_PARTY_SIZE = 6

      SPECIAL_TYPE_WORDS = [
        "RIVAL", "LEADER", "ELITE", "CHAMPION", "BOSS"
      ].freeze

      class << self
        def enabled?
          truthy?(setting(ENABLED_SETTING, false))
        end

        def repeat_wagers?
          truthy?(setting(REPEAT_SETTING, false))
        end

        def context_allowed?(arguments)
          return false unless enabled?
          values = Array(arguments)
          return false unless values.length == 1
          return false if partner_battle?
          return false if special_battle_rule?
          true
        rescue StandardError
          false
        end

        def apply_roster(trainer, identity, scope, context)
          return 0 unless context_eligible?(trainer, identity, scope, context)
          entry = trainer_entry(identity)
          operations = Array(entry["operations"]).select { |value| value.is_a?(Hash) }
          original_party = Array(trainer.party).compact.dup
          applied = applied_operation_ids(trainer)
          changed = 0
          operations.each do |operation|
            operation_id = operation["id"].to_s
            next if !operation_id.empty? && applied.include?(operation_id)
            result = apply_operation(trainer, operation)
            next unless result
            applied << operation_id unless operation_id.empty?
            changed += 1 if result == :changed
          end
          recovery_id = ensure_nonempty_roster(trainer, operations, original_party)
          if recovery_id
            applied << recovery_id unless recovery_id == :original
            changed += 1
            log_warning("Recovered an empty Pink Slips trainer roster")
          end
          trainer.party.compact!
          trainer.instance_variable_set(APPLIED_IVAR, applied.uniq)
          log_roster_replay(operations.length, changed, trainer.party.length)
          changed
        rescue StandardError => e
          log_exception("Could not apply Pink Slips roster changes", e)
          0
        end

        def prepare_wager(opponent, context)
          return false unless opponent.is_a?(Hash) && context.is_a?(Hash)
          return false if context[:pink_slips_prepared]
          context[:pink_slips_prepared] = true
          trainer = opponent[:trainer] || opponent["trainer"]
          identity = opponent[:identity] || opponent["identity"]
          scope = opponent[:scope] || opponent["scope"] || :regular
          return false unless context_eligible?(trainer, identity, scope, context)

          deliver_pending(false)
          entry = trainer_entry(identity)
          return false if entry["wagers"].to_i > 0 && !repeat_wagers?
          candidates = prize_candidates(trainer)
          return false if candidates.empty? || eligible_wager_indices.empty?
          return false unless KantoReloaded::PopupWindow.confirm(
            _INTL("Wager a Pokemon against {1}? The winner takes one Pokemon.",
                  identity_value(identity, "display_name", trainer.name)),
            :default => false
          )

          index = KantoReloaded::TrainerControl::PinkSlipsUI.choose_wager
          return false unless index && index >= 0
          pokemon = $Trainer.party[index] rescue nil
          return false unless pokemon && wager_eligible?(pokemon, index)
          context[:pink_slips_wager] = {
            :trainer => trainer,
            :identity => identity,
            :scope => scope.to_sym,
            :wager_object_id => pokemon.object_id,
            :wager_personal_id => pokemon.respond_to?(:personalID) ? pokemon.personalID : nil,
            :wager_name => pokemon.name.to_s,
            :wager_blueprint => transfer_blueprint(pokemon),
            :prizes => candidates
          }
          KantoReloaded::Toast.warning(
            _INTL("{1} is your Pink Slips wager.", pokemon.name)
          ) if defined?(KantoReloaded::Toast)
          true
        rescue StandardError => e
          log_exception("Could not prepare Pink Slips wager", e)
          context.delete(:pink_slips_wager) if context.is_a?(Hash)
          false
        end

        def resolve(context, decision)
          wager = context.is_a?(Hash) ? context[:pink_slips_wager] : nil
          return false unless wager.is_a?(Hash)
          result = decision.to_i
          return false unless result == 1 || result == 2
          identity = wager[:identity]
          entry = trainer_entry(identity)
          sequence = entry["wagers"].to_i + 1
          completed = if result == 1
                        resolve_player_win(wager, entry, sequence)
                      else
                        resolve_player_loss(wager, entry, sequence)
                      end
          return false unless completed
          entry["wagers"] = sequence
          entry["wins"] = entry["wins"].to_i + 1 if result == 1
          entry["losses"] = entry["losses"].to_i + 1 if result == 2
          entry["last_result"] = result == 1 ? "win" : "loss"
          true
        rescue StandardError => e
          log_exception("Could not resolve Pink Slips wager", e)
          false
        ensure
          context.delete(:pink_slips_wager) if context.is_a?(Hash)
        end

        def pending_counts
          [pending_pokemon.length, pending_items.inject(0) { |sum, item| sum + item["quantity"].to_i }]
        rescue StandardError
          [0, 0]
        end

        def pending?
          counts = pending_counts
          counts[0] > 0 || counts[1] > 0
        end

        def wager_candidate?(pokemon, index)
          wager_eligible?(pokemon, index)
        end

        def deliver_pending(show_feedback = true)
          delivered_pokemon = 0
          delivered_items = 0
          remaining_pokemon = []
          pending_pokemon.each do |pokemon|
            if deliver_pokemon(pokemon)
              register_owned(pokemon)
              delivered_pokemon += 1
            else
              remaining_pokemon << pokemon
            end
          end
          data_bucket["pending_pokemon"] = remaining_pokemon

          remaining_items = []
          pending_items.each do |entry|
            item = symbol_value(entry["item"])
            quantity = [entry["quantity"].to_i, 1].max
            if item && return_item(item, quantity, false)
              delivered_items += quantity
            else
              remaining_items << { "item" => entry["item"].to_s, "quantity" => quantity }
            end
          end
          data_bucket["pending_items"] = remaining_items
          show_delivery_feedback(delivered_pokemon, delivered_items) if show_feedback
          delivered_pokemon + delivered_items
        rescue StandardError => e
          log_exception("Could not deliver pending Pink Slips transfers", e)
          0
        end

        def restore_applied_operations(trainer, values)
          return false unless trainer
          trainer.instance_variable_set(
            APPLIED_IVAR,
            Array(values).map { |value| value.to_s }.reject { |value| value.empty? }.uniq
          )
          true
        rescue StandardError
          false
        end

        def applied_operations(trainer)
          applied_operation_ids(trainer).dup
        end

        def inspection_record(key)
          source = trainer_entries[key.to_s]
          source.is_a?(Hash) ? copy_inspection_value(source) : nil
        rescue StandardError
          nil
        end

        def inspection_records
          trainer_entries.values.select { |value| value.is_a?(Hash) }.
            map { |value| copy_inspection_value(value) }
        rescue StandardError
          []
        end

        private

        def context_eligible?(trainer, identity, scope, context)
          return false unless enabled? && trainer && identity.is_a?(Hash)
          return false unless context.is_a?(Hash) && context[:pink_slips_allowed]
          return false if identity_value(identity, "source").to_s == "runtime"
          return false if scope.to_sym == :leader
          return false if special_trainer?(trainer)
          true
        rescue StandardError
          false
        end

        def special_trainer?(trainer)
          type = trainer.respond_to?(:trainer_type) ? trainer.trainer_type.to_s.upcase : ""
          return true if SPECIAL_TYPE_WORDS.any? { |word| type.include?(word) }
          return true if rival_type?(trainer.respond_to?(:trainer_type) ? trainer.trainer_type : nil)
          return true if trainer.respond_to?(:boss?) && trainer.boss?
          false
        rescue StandardError
          true
        end

        def rival_type?(trainer_type)
          return false unless defined?(Settings::RIVAL_NAMES)
          Array(Settings::RIVAL_NAMES).any? do |entry|
            value = entry.is_a?(Array) ? entry[0] : entry
            value.to_s == trainer_type.to_s
          end
        rescue StandardError
          false
        end

        def partner_battle?
          return false unless defined?($PokemonGlobal) && $PokemonGlobal
          rules = if defined?($PokemonTemp) && $PokemonTemp
                    $PokemonTemp.battleRules
                  end
          !!$PokemonGlobal.partner && !(rules.is_a?(Hash) && rules["noPartner"])
        rescue StandardError
          false
        end

        def special_battle_rule?
          return false unless defined?($PokemonTemp) && $PokemonTemp
          rules = $PokemonTemp.battleRules
          return false unless rules.is_a?(Hash)
          !!(rules["birdboss"] || rules[:birdboss])
        rescue StandardError
          false
        end

        def resolve_player_win(wager, entry, sequence)
          prizes = Array(wager[:prizes])
          return false if prizes.empty?
          selected = KantoReloaded::TrainerControl::PinkSlipsUI.choose_prize(prizes)
          unless selected.is_a?(Hash)
            KantoReloaded::Toast.warning(
              _INTL("You forfeited your Pink Slips prize.")
            ) if defined?(KantoReloaded::Toast)
            return true
          end
          trainer = wager[:trainer]
          pokemon = build_player_prize(selected, trainer)
          return false unless pokemon

          operation = {
            "id" => operation_id(sequence, "remove"),
            "type" => "remove",
            "fingerprint" => selected["fingerprint"]
          }
          append_operation(entry, operation)
          if remaining_after_removal(wager[:trainer], selected) <= 0
            fallback = fallback_trainer_blueprint(selected, wager[:trainer])
            fallback ||= {
              "species" => selected["species"].to_s,
              "form" => selected["form"].to_i,
              "level" => [selected["level"].to_i, 1].max
            }
            append_operation(entry, {
              "id" => operation_id(sequence, "fallback"),
              "type" => "add",
              "pokemon" => fallback
            }) if fallback
          end

          location = deliver_pokemon(pokemon)
          if location
            register_owned(pokemon)
            KantoReloaded::Toast.success(
              location == :party ?
                _INTL("You won {1}. It joined your party.", pokemon.name) :
                _INTL("You won {1}. It was sent to the PC.", pokemon.name)
            ) if defined?(KantoReloaded::Toast)
          else
            pending_pokemon << pokemon
            KantoReloaded::Toast.warning(
              _INTL("You won {1}, but storage is full. The prize is pending.", pokemon.name)
            ) if defined?(KantoReloaded::Toast)
          end
          true
        end

        def resolve_player_loss(wager, entry, sequence)
          pokemon, index = locate_wagered_pokemon(wager)
          return false unless pokemon && index
          item = pokemon.respond_to?(:item_id) ? pokemon.item_id : nil
          returned = return_item(item, 1, true) if item
          operation = {
            "id" => operation_id(sequence, "add"),
            "type" => "add",
            "pokemon" => wager[:wager_blueprint],
            "replace_index" => replacement_index(wager[:trainer])
          }
          append_operation(entry, operation)
          $Trainer.party.delete_at(index)
          message = _INTL("You lost {1} to {2}.", wager[:wager_name], wager[:trainer].name)
          message += _INTL(" Its held item was returned.") if item && returned
          message += _INTL(" Its held item is pending because storage is full.") if item && !returned
          KantoReloaded::Toast.error(message) if defined?(KantoReloaded::Toast)
          true
        end

        def locate_wagered_pokemon(wager)
          party = defined?($Trainer) && $Trainer ? Array($Trainer.party) : []
          index = party.index { |pokemon| pokemon.object_id == wager[:wager_object_id] }
          if index.nil? && wager[:wager_personal_id]
            index = party.index do |pokemon|
              pokemon.respond_to?(:personalID) && pokemon.personalID == wager[:wager_personal_id]
            end
          end
          index ? [party[index], index] : [nil, nil]
        rescue StandardError
          [nil, nil]
        end

        def prize_candidates(trainer)
          party = Array(trainer.party).compact
          occurrence = Hash.new(0)
          party.each_with_index.map do |pokemon, index|
            next unless prize_eligible?(pokemon)
            key = species_form_key(pokemon)
            ordinal = occurrence[key]
            occurrence[key] += 1
            {
              "name" => pokemon.name.to_s,
              "level" => pokemon.level.to_i,
              "species" => pokemon.species.to_s,
              "form" => pokemon.respond_to?(:form) ? pokemon.form.to_i : 0,
              "pokemon" => pokemon,
              "fingerprint" => {
                "species" => pokemon.species.to_s,
                "form" => pokemon.respond_to?(:form) ? pokemon.form.to_i : 0,
                "ordinal" => ordinal,
                "slot" => index
              }
            }
          end.compact
        end

        def prize_eligible?(pokemon)
          return false unless pokemon
          return false if pokemon.respond_to?(:egg?) && pokemon.egg?
          return false if pokemon.respond_to?(:isBossAlpha?) && pokemon.isBossAlpha?
          return false if pokemon.respond_to?(:alpha?) && pokemon.alpha?
          return false if pokemon.name.to_s.end_with?(" A")
          true
        rescue StandardError
          false
        end

        def eligible_wager_indices
          return [] unless defined?($Trainer) && $Trainer
          Array($Trainer.party).each_index.select do |index|
            wager_eligible?($Trainer.party[index], index)
          end
        rescue StandardError
          []
        end

        def wager_eligible?(pokemon, index)
          return false unless pokemon
          return false if pokemon.respond_to?(:egg?) && pokemon.egg?
          Array($Trainer.party).each_with_index.any? do |other, other_index|
            next false if other_index == index || !other
            !other.egg? && other.hp.to_i > 0
          end
        rescue StandardError
          false
        end

        def apply_operation(trainer, operation)
          case operation["type"].to_s
          when "remove" then apply_remove(trainer, operation["fingerprint"])
          when "add" then apply_add(trainer, operation)
          else false
          end
        end

        def apply_remove(trainer, fingerprint)
          return true unless fingerprint.is_a?(Hash)
          party = Array(trainer.party)
          species = fingerprint["species"].to_s
          form = fingerprint["form"].to_i
          matches = party.each_index.select do |index|
            pokemon = party[index]
            pokemon && pokemon.species.to_s == species &&
              (!pokemon.respond_to?(:form) || pokemon.form.to_i == form)
          end
          return true if matches.empty?
          ordinal = fingerprint["ordinal"].to_i
          index = matches[ordinal]
          slot = fingerprint["slot"].to_i
          index ||= slot if party[slot] && party[slot].species.to_s == species
          return true unless index
          trainer.party.delete_at(index)
          :changed
        end

        def apply_add(trainer, operation)
          blueprint = operation["pokemon"]
          return false unless blueprint.is_a?(Hash)
          token = operation["id"].to_s
          return true if Array(trainer.party).any? do |pokemon|
            pokemon && pokemon.instance_variable_get(MEMBER_IVAR).to_s == token
          end
          pokemon = build_trainer_transfer(blueprint, trainer, token)
          return false unless pokemon
          if trainer.party.length < max_party_size
            trainer.party << pokemon
          else
            requested = operation["replace_index"].to_i
            requested = trainer.party.length - 1 if requested < 0
            index = [[requested, 0].max, trainer.party.length - 1].min
            trainer.party[index] = pokemon
          end
          :changed
        end

        def ensure_nonempty_roster(trainer, operations, original_party)
          trainer.party.compact!
          return nil unless trainer.party.empty?
          Array(operations).reverse_each do |operation|
            next unless operation.is_a?(Hash) && operation["type"].to_s == "add"
            blueprint = operation["pokemon"]
            next unless blueprint.is_a?(Hash)
            token = operation["id"].to_s
            pokemon = build_trainer_transfer(blueprint, trainer, token)
            next unless pokemon
            trainer.party << pokemon
            return token
          end
          Array(original_party).each do |source|
            next unless source
            token = "pink_slips_recovery"
            pokemon = build_trainer_transfer(
              transfer_blueprint(source), trainer, token
            )
            if pokemon
              trainer.party << pokemon
              return token
            end
          end
          source = Array(original_party).compact.first
          if source
            trainer.party << source
            return :original
          end
          nil
        rescue StandardError => e
          log_exception("Could not recover empty Pink Slips trainer roster", e)
          source = Array(original_party).compact.first
          trainer.party << source if source && trainer.party.empty?
          source ? :original : nil
        end

        def build_player_prize(blueprint, trainer)
          species = valid_species(blueprint["species"])
          return nil unless species
          level = [blueprint["level"].to_i, highest_player_level].min
          level = 1 if level <= 0
          owner = Pokemon::Owner.new_from_trainer(trainer)
          pokemon = Pokemon.new(species, level, owner)
          apply_form_and_moves(pokemon, blueprint["form"])
          pokemon.item = nil if pokemon.respond_to?(:item=)
          pokemon.heal if pokemon.respond_to?(:heal)
          pokemon.calc_stats if pokemon.respond_to?(:calc_stats)
          pokemon
        rescue StandardError => e
          log_exception("Could not reroll Pink Slips prize", e)
          nil
        end

        def build_trainer_transfer(blueprint, trainer, token)
          species = valid_species(blueprint["species"])
          return nil unless species
          level = [blueprint["level"].to_i, 1].max
          pokemon = Pokemon.new(species, level, trainer)
          apply_form_and_moves(pokemon, blueprint["form"])
          pokemon.item = nil if pokemon.respond_to?(:item=)
          pokemon.instance_variable_set(MEMBER_IVAR, token)
          if defined?(TrainerAdaptation::ADDED_IVAR)
            pokemon.instance_variable_set(TrainerAdaptation::ADDED_IVAR, true)
          end
          pokemon.heal if pokemon.respond_to?(:heal)
          pokemon.calc_stats if pokemon.respond_to?(:calc_stats)
          pokemon
        rescue StandardError => e
          log_exception("Could not reroll trainer Pink Slips transfer", e)
          nil
        end

        def apply_form_and_moves(pokemon, form)
          pokemon.form = form.to_i if pokemon.respond_to?(:form=)
          pokemon.reset_moves if pokemon.respond_to?(:reset_moves)
        rescue StandardError
          nil
        end

        def transfer_blueprint(pokemon)
          {
            "species" => pokemon.species.to_s,
            "form" => pokemon.respond_to?(:form) ? pokemon.form.to_i : 0,
            "level" => pokemon.level.to_i
          }
        end

        def fallback_trainer_blueprint(selected, trainer)
          source = valid_species(selected["species"])
          source_type = species_types(source).sample
          pool = if defined?(TeamExpansion) && TeamExpansion.respond_to?(:adaptation_candidates)
                   TeamExpansion.adaptation_candidates(source_type)
                 else
                   []
                 end
          pool = Array(pool).reject { |candidate| candidate.to_s == source.to_s }
          candidate = pool.empty? ? source : pool[rand(pool.length)]
          candidate = candidate.id if candidate.respond_to?(:id)
          return nil unless candidate
          {
            "species" => candidate.to_s,
            "form" => 0,
            "level" => [selected["level"].to_i, 1].max
          }
        rescue StandardError
          nil
        end

        def remaining_after_removal(trainer, selected)
          party = Array(trainer.party)
          fingerprint = selected["fingerprint"]
          return party.length unless fingerprint.is_a?(Hash)
          party.length - 1
        end

        def replacement_index(trainer)
          party = Array(trainer.party)
          return -1 if party.length < max_party_size
          candidates = party.each_with_index.reject do |pokemon, _index|
            pokemon.instance_variable_get(TrainerAdaptation::ACE_IVAR) rescue false
          end
          candidates = party.each_with_index.to_a if candidates.empty?
          selected = candidates.min_by { |pokemon, index| [pokemon.level.to_i, -index] }
          selected ? selected[1] : party.length - 1
        rescue StandardError
          max_party_size - 1
        end

        def append_operation(entry, operation)
          values = Array(entry["operations"]).select { |value| value.is_a?(Hash) }
          values << operation
          entry["operations"] = values.last(100)
          true
        end

        def operation_id(sequence, suffix)
          "w#{sequence.to_i}:#{suffix}"
        end

        def return_item(item, quantity = 1, queue_on_failure = true)
          return true unless item
          quantity = [quantity.to_i, 1].max
          if defined?($PokemonBag) && $PokemonBag &&
             $PokemonBag.pbCanStore?(item, quantity) &&
             $PokemonBag.pbStoreItem(item, quantity)
            return true
          end
          storage = pc_item_storage
          if storage && storage.pbCanStore?(item, quantity) &&
             storage.pbStoreItem(item, quantity)
            return true
          end
          if queue_on_failure
            pending_items << { "item" => item.to_s, "quantity" => quantity }
          end
          false
        rescue StandardError => e
          log_exception("Could not return Pink Slips held item", e)
          pending_items << { "item" => item.to_s, "quantity" => quantity } if queue_on_failure
          false
        end

        def pc_item_storage
          return nil unless defined?($PokemonGlobal) && $PokemonGlobal
          if !$PokemonGlobal.pcItemStorage && defined?(PCItemStorage)
            $PokemonGlobal.pcItemStorage = PCItemStorage.new
          end
          $PokemonGlobal.pcItemStorage
        rescue StandardError
          nil
        end

        def deliver_pokemon(pokemon)
          return false unless pokemon && defined?($Trainer) && $Trainer
          if $Trainer.party.length < max_party_size
            $Trainer.party << pokemon
            return :party
          end
          return false unless defined?($PokemonStorage) && $PokemonStorage
          box = $PokemonStorage.pbStoreCaught(pokemon)
          box && box.to_i >= 0 ? :storage : false
        rescue StandardError
          false
        end

        def register_owned(pokemon)
          return false unless defined?($Trainer) && $Trainer && $Trainer.respond_to?(:pokedex)
          $Trainer.pokedex.register(pokemon)
          $Trainer.pokedex.set_owned(pokemon.species)
          pokemon.record_first_moves if pokemon.respond_to?(:record_first_moves)
          true
        rescue StandardError
          false
        end

        def show_delivery_feedback(pokemon_count, item_count)
          if pokemon_count <= 0 && item_count <= 0
            text = pending? ? _INTL("Pending Pink Slips transfers still need storage space.") :
                              _INTL("There are no pending Pink Slips transfers.")
            KantoReloaded::Toast.warning(text) if defined?(KantoReloaded::Toast)
            return
          end
          KantoReloaded::Toast.success(
            _INTL("Delivered {1} Pokemon and {2} held items.", pokemon_count, item_count)
          ) if defined?(KantoReloaded::Toast)
        end

        def applied_operation_ids(trainer)
          Array(trainer.instance_variable_get(APPLIED_IVAR)).map { |value| value.to_s }.
            reject { |value| value.empty? }.uniq
        rescue StandardError
          []
        end

        def trainer_entry(identity)
          key = identity_value(identity, "key").to_s
          trainers = trainer_entries
          value = trainers[key]
          value = {} unless value.is_a?(Hash)
          value["key"] = key
          value["display_name"] = identity_value(identity, "display_name", "Trainer").to_s
          value["trainer_type"] = identity_value(identity, "trainer_type", "").to_s
          value["version"] = identity_value(identity, "version", 0).to_i
          value["wagers"] = [value["wagers"].to_i, 0].max
          value["wins"] = [value["wins"].to_i, 0].max
          value["losses"] = [value["losses"].to_i, 0].max
          value["operations"] = Array(value["operations"]).select { |item| item.is_a?(Hash) }
          trainers[key] = value
          value
        end

        def trainer_entries
          value = data_bucket["trainers"]
          unless value.is_a?(Hash)
            value = {}
            data_bucket["trainers"] = value
          end
          value
        end

        def pending_pokemon
          value = data_bucket["pending_pokemon"]
          unless value.is_a?(Array)
            value = []
            data_bucket["pending_pokemon"] = value
          end
          value
        end

        def pending_items
          value = data_bucket["pending_items"]
          unless value.is_a?(Array)
            value = []
            data_bucket["pending_items"] = value
          end
          value
        end

        def data_bucket
          root = if defined?(KantoReloaded::SaveData)
                   KantoReloaded::SaveData.module_data(:trainer_control)
                 else
                   @fallback_root ||= {}
                 end
          value = root["pink_slips"] || root[:pink_slips]
          unless value.is_a?(Hash)
            value = {}
            root["pink_slips"] = value
          end
          root.delete(:pink_slips)
          root["pink_slips"] = value
          value
        end

        def highest_player_level
          party = defined?($Trainer) && $Trainer ? Array($Trainer.party) : []
          levels = party.reject { |pokemon| pokemon.respond_to?(:egg?) && pokemon.egg? }.
            map { |pokemon| pokemon.level.to_i }
          [levels.max.to_i, 1].max
        rescue StandardError
          1
        end

        def max_party_size
          value = defined?(Settings::MAX_PARTY_SIZE) ? Settings::MAX_PARTY_SIZE.to_i : MAX_PARTY_SIZE
          value > 0 ? value : MAX_PARTY_SIZE
        end

        def valid_species(value)
          candidate = symbol_value(value)
          return nil unless candidate && defined?(GameData::Species)
          GameData::Species.exists?(candidate) ? candidate : nil
        rescue StandardError
          nil
        end

        def symbol_value(value)
          return value if value.is_a?(Symbol)
          text = value.to_s
          text.empty? ? nil : text.to_sym
        rescue StandardError
          nil
        end

        def copy_inspection_value(value)
          case value
          when Hash
            result = {}
            value.each { |key, child| result[key.to_s] = copy_inspection_value(child) }
            result
          when Array
            value.map { |child| copy_inspection_value(child) }
          when String, Symbol, Numeric, TrueClass, FalseClass, NilClass
            value
          else
            value.to_s
          end
        end

        def species_form_key(pokemon)
          "#{pokemon.species}:#{pokemon.respond_to?(:form) ? pokemon.form.to_i : 0}"
        end

        def species_types(species)
          return [] unless species && defined?(GameData::Species)
          data = GameData::Species.try_get(species) rescue nil
          return [] unless data
          values = data.respond_to?(:types) ? data.types : [data.type1, data.type2]
          Array(values).compact
        rescue StandardError
          []
        end

        def identity_value(identity, key, fallback = nil)
          return fallback unless identity.is_a?(Hash)
          value = identity[key]
          value = identity[key.to_sym] if value.nil?
          value.nil? ? fallback : value
        end

        def setting(key, fallback)
          return fallback unless defined?(KantoReloaded::Settings)
          KantoReloaded::Settings.get(key, fallback)
        end

        def truthy?(value)
          value == true || (value.is_a?(Numeric) && value.to_i != 0) ||
            ["true", "on", "yes", "enabled", "1"].include?(value.to_s.downcase)
        end

        def log_exception(message, error)
          KantoReloaded::Log.exception(
            message, error, channel: :trainer_control
          ) if defined?(KantoReloaded::Log)
        end

        def log_warning(message)
          KantoReloaded::Log.warning(
            message, :trainer_control
          ) if defined?(KantoReloaded::Log)
        end

        def log_roster_replay(operation_count, changed, party_size)
          return unless operation_count.to_i > 0 && defined?(KantoReloaded::Log)
          KantoReloaded::Log.debug(
            "Pink Slips roster replay operations=#{operation_count.to_i} " \
            "changed=#{changed.to_i} party=#{party_size.to_i}",
            :trainer_control
          )
        end
      end
    end
  end
end
