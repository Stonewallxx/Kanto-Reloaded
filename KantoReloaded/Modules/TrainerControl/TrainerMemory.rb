#==============================================================================
# Kanto Reloaded - Trainer Control Memory
#==============================================================================

module KantoReloaded
  module TrainerControl
    module TrainerMemory
      MODULE_ID = :trainer_control
      WINDOW_SIZE = 5

      SETUP_MOVES = [
        :AGILITY, :BELLYDRUM, :BULKUP, :CALMMIND, :COIL, :COSMICPOWER,
        :CURSE, :DRAGONDANCE, :GEOMANCY, :GROWTH, :HONECLAWS, :IRONDEFENSE,
        :NASTYPLOT, :QUIVERDANCE, :ROCKPOLISH, :SHELLSMASH, :SHIFTGEAR,
        :SWORDSDANCE, :TAILGLOW
      ].freeze
      HAZARD_MOVES = [:SPIKES, :STEALTHROCK, :STICKYWEB, :TOXICSPIKES].freeze
      HEALING_MOVES = [
        :AQUARING, :HEALORDER, :LIFEDEW, :MILKDRINK, :MOONLIGHT,
        :MORNINGSUN, :RECOVER, :REST, :ROOST, :SHOREUP, :SLACKOFF,
        :SOFTBOILED, :STRENGTHSAP, :SYNTHESIS, :WISH
      ].freeze
      WEATHER_MOVES = [:HAIL, :RAINDANCE, :SANDSTORM, :SNOWSCAPE, :SUNNYDAY].freeze
      TERRAIN_MOVES = [
        :ELECTRICTERRAIN, :GRASSYTERRAIN, :MISTYTERRAIN, :PSYCHICTERRAIN
      ].freeze
      PIVOT_MOVES = [:BATONPASS, :FLIPTURN, :PARTINGSHOT, :TELEPORT,
                     :UTURN, :VOLTSWITCH].freeze

      class << self
        def install_hooks
          return true if @hooks_installed
          return false unless defined?(PokeBattle_Battler)
          KantoReloaded::Hooks.wrap(
            PokeBattle_Battler, :pbInitialize,
            :trainer_memory_participant, :required => true
          ) do |hook, *arguments|
            result = hook.call
            KantoReloaded::TrainerControl::TrainerMemory.observe_battler(self)
            result
          end
          KantoReloaded::Hooks.wrap(
            PokeBattle_Battler, :pbUseMove,
            :trainer_memory_successful_move, :required => true
          ) do |hook, *arguments|
            special_usage = arguments.length > 1 ? arguments[1] : false
            multi_turn = respond_to?(:usingMultiTurnAttack?) && usingMultiTurnAttack?
            result = hook.call
            unless special_usage || multi_turn
              KantoReloaded::TrainerControl::TrainerMemory.observe_move(self)
            end
            result
          end
          @hooks_installed = true
          true
        rescue StandardError => e
          log_exception("Trainer memory hooks failed", e)
          false
        end

        def begin_battle
          @session = blank_encounter
          @session["participants_seen"] = {}
          @session["leads_seen"] = {}
          @session["lead_limit"] = nil
          true
        end

        def active?
          @session.is_a?(Hash)
        end

        def observe_battler(battler)
          return false unless active? && player_owned?(battler)
          pokemon = battler.respond_to?(:pokemon) ? battler.pokemon : nil
          return false unless pokemon
          object_key = pokemon.object_id
          return false if @session["participants_seen"][object_key]
          @session["participants_seen"][object_key] = true
          pokemon_types(pokemon).each do |type|
            increment(@session["pokemon_types"], type)
          end
          limit = @session["lead_limit"] ||= battle_side_size(battler)
          if @session["leads_seen"].length < limit
            species = pokemon.respond_to?(:species) ? pokemon.species.to_s : ""
            unless species.empty? || @session["leads_seen"][species]
              @session["leads_seen"][species] = true
              increment(@session["leads"], species)
            end
          end
          true
        rescue StandardError => e
          log_exception("Could not observe battle participant", e)
          false
        end

        def observe_move(battler)
          return false unless active? && player_owned?(battler)
          return false if battler.respond_to?(:lastMoveFailed) && battler.lastMoveFailed
          move_id = battler.respond_to?(:lastRegularMoveUsed) ?
                      battler.lastRegularMoveUsed : nil
          return false unless move_id && defined?(GameData::Move)
          move = GameData::Move.try_get(move_id) rescue nil
          return false unless move
          type = if battler.respond_to?(:lastMoveUsedType)
                   battler.lastMoveUsedType
                 end
          type ||= move.type
          increment(@session["move_types"], type.to_s)
          style = move_style(move)
          increment(@session["styles"], style.to_s) if style
          true
        rescue StandardError => e
          log_exception("Could not observe successful move", e)
          false
        end

        def finish_battle(opponents, decision)
          result = decision.to_i
          return cancel_battle unless result == 1 || result == 2
          encounter = compact_encounter(@session)
          Array(opponents).each do |opponent|
            identity = opponent.is_a?(Hash) ?
                         (opponent[:identity] || opponent["identity"]) : nil
            update(identity, encounter, result == 1) if identity.is_a?(Hash)
          end
          cancel_battle
          true
        rescue StandardError => e
          log_exception("Could not save trainer memory", e)
          cancel_battle
          false
        end

        def cancel_battle
          @session = nil
          true
        end

        def find(key)
          value = memory_hash[key.to_s]
          value.is_a?(Hash) ? value : nil
        rescue StandardError
          nil
        end

        def adaptation_state(key)
          entry = find(key)
          value = entry && entry["adaptation_state"]
          value.is_a?(Hash) ? value : nil
        rescue StandardError
          nil
        end

        def save_adaptation_state(key, state)
          entry = find(key)
          return false unless entry && state.is_a?(Hash)
          entry["adaptation_state"] = state
          true
        rescue StandardError => e
          log_exception("Could not save trainer adaptation state", e)
          false
        end

        def reward_claimed?(key, milestone)
          entry = find(key)
          return false unless entry
          Array(entry["reward_milestones"]).map { |value| value.to_i }.
            include?(milestone.to_i)
        rescue StandardError
          false
        end

        def claim_reward(key, milestone)
          entry = find(key)
          return false unless entry
          values = Array(entry["reward_milestones"]).map { |value| value.to_i }
          value = milestone.to_i
          return false if value <= 0 || values.include?(value)
          values << value
          entry["reward_milestones"] = values.uniq.sort
          true
        rescue StandardError => e
          log_exception("Could not claim trainer reward milestone", e)
          false
        end

        def all
          memory_hash.values.select { |entry| entry.is_a?(Hash) }
        rescue StandardError
          []
        end

        def delete(key)
          !!memory_hash.delete(key.to_s)
        rescue StandardError => e
          log_exception("Could not delete trainer memory", e)
          false
        end

        def clear
          count = memory_hash.length
          memory_hash.clear
          count
        rescue StandardError => e
          log_exception("Could not clear trainer memory", e)
          0
        end

        def summary_lines(key)
          entry = find(key)
          return [_INTL("No adaptation memory has been earned yet.")] unless entry
          snapshot = entry["snapshot"].is_a?(Hash) ? entry["snapshot"] : {}
          observed = entry["observed"].is_a?(Hash) ? entry["observed"] : {}
          wins = entry["revision"].to_i
          [
            _INTL("Adaptation wins: {1}", wins),
            _INTL("Next battle changes: {1}", TrainerAdaptation.changes_for_wins(wins)),
            _INTL("Recent battles observed: {1}", Array(entry["encounters"]).length),
            _INTL("Adapted from: {1}", Array(snapshot["encounters"]).length),
            _INTL("Common Pokemon types: {1}", top_names(observed["pokemon_types"])),
            _INTL("Common move types: {1}", top_names(observed["move_types"])),
            _INTL("Observed strategies: {1}", top_names(observed["styles"]))
          ]
        rescue StandardError
          [_INTL("Trainer memory could not be read.")]
        end

        private

        def update(identity, encounter, player_won)
          key = value(identity, "key").to_s
          return false if key.empty?
          entry = memory_hash[key]
          entry = {} unless entry.is_a?(Hash)
          entry["key"] = key
          entry["display_name"] = value(identity, "display_name", "Trainer").to_s
          entry["trainer_type"] = value(identity, "trainer_type", "").to_s
          entry["version"] = value(identity, "version", 0).to_i
          encounters = Array(entry["encounters"])
          encounters << deep_copy_encounter(encounter)
          encounters.shift while encounters.length > WINDOW_SIZE
          entry["encounters"] = encounters
          entry["observed"] = aggregate(encounters)
          entry["last_result"] = player_won ? "win" : "loss"
          if player_won
            entry["revision"] = entry["revision"].to_i + 1
            entry["snapshot"] = aggregate(encounters)
            entry["snapshot"]["encounters"] = encounters.map { |item| deep_copy_encounter(item) }
          else
            entry["loss_revision"] = entry["loss_revision"].to_i + 1
            entry["loss_snapshot"] = aggregate(encounters)
            entry["loss_snapshot"]["encounters"] = encounters.map do |item|
              deep_copy_encounter(item)
            end
          end
          entry.delete("confidence")
          memory_hash[key] = entry
          true
        end

        def blank_encounter
          {
            "pokemon_types" => {}, "move_types" => {},
            "styles" => {}, "leads" => {}
          }
        end

        def compact_encounter(source)
          result = blank_encounter
          result.keys.each do |key|
            values = source.is_a?(Hash) ? source[key] : nil
            result[key] = compact_counts(values)
          end
          result
        end

        def aggregate(encounters)
          result = blank_encounter
          Array(encounters).each do |encounter|
            result.keys.each do |key|
              values = encounter.is_a?(Hash) ? encounter[key] : nil
              next unless values.is_a?(Hash)
              values.each { |name, count| increment(result[key], name, count) }
            end
          end
          result
        end

        def compact_counts(values)
          result = {}
          return result unless values.is_a?(Hash)
          values.each do |name, count|
            number = count.to_i
            result[name.to_s] = number if number > 0
          end
          result
        end

        def deep_copy_encounter(encounter)
          result = blank_encounter
          result.keys.each do |key|
            result[key] = compact_counts(encounter[key])
          end
          result
        end

        def move_style(move)
          id = move.id
          return :setup if SETUP_MOVES.include?(id)
          return :hazard if HAZARD_MOVES.include?(id)
          return :healing if HEALING_MOVES.include?(id)
          return :weather if WEATHER_MOVES.include?(id)
          return :terrain if TERRAIN_MOVES.include?(id)
          return :pivot if PIVOT_MOVES.include?(id)
          return :status if move.base_damage.to_i <= 0
          nil
        end

        def player_owned?(battler)
          battler.respond_to?(:pbOwnedByPlayer?) && battler.pbOwnedByPlayer?
        rescue StandardError
          false
        end

        def battle_side_size(battler)
          battle = battler.instance_variable_get(:@battle)
          value = battle.pbSideSize(0).to_i if battle && battle.respond_to?(:pbSideSize)
          value && value > 0 ? value : 1
        rescue StandardError
          1
        end

        def pokemon_types(pokemon)
          values = []
          values << pokemon.type1 if pokemon.respond_to?(:type1)
          values << pokemon.type2 if pokemon.respond_to?(:type2)
          values.compact.map { |type| type.to_s }.uniq
        rescue StandardError
          []
        end

        def increment(hash, key, amount = 1)
          return if key.nil? || key.to_s.empty?
          name = key.to_s
          hash[name] = hash.fetch(name, 0).to_i + amount.to_i
        end

        def top_names(counts)
          return _INTL("None") unless counts.is_a?(Hash) && !counts.empty?
          counts.sort_by { |name, count| [-count.to_i, name.to_s] }.
            first(3).map { |name, _count| name.to_s.gsub("_", " ").capitalize }.
            join(", ")
        end

        def value(hash, key, fallback = nil)
          found = hash[key]
          found = hash[key.to_sym] if found.nil?
          found.nil? ? fallback : found
        end

        def memory_hash
          data = module_bucket
          memory = data["memory"] || data[:memory]
          unless memory.is_a?(Hash)
            memory = {}
            data["memory"] = memory
          end
          data.delete(:memory)
          data["memory"] = memory
          memory
        end

        def module_bucket
          return @fallback_bucket ||= {} unless defined?(KantoReloaded::SaveData)
          KantoReloaded::SaveData.module_data(MODULE_ID)
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
