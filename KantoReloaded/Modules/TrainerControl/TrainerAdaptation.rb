#==============================================================================
# Kanto Reloaded - Trainer Control Adaptation
#==============================================================================

module KantoReloaded
  module TrainerControl
    module TrainerAdaptation
      ENABLED_SETTING = :trainer_control_adaptation
      ADDED_IVAR = :@kanto_reloaded_trainer_adaptation
      ACE_IVAR = :@kanto_reloaded_trainer_ace

      ARCHETYPES = [:balanced, :aggressive, :defensive, :control].freeze

      UTILITY_RESPONSES = {
        "setup" => [:HAZE, :CLEARSMOG, :TAUNT, :ROAR, :WHIRLWIND],
        "hazard" => [:DEFOG, :RAPIDSPIN, :COURTCHANGE],
        "status" => [:SAFEGUARD, :AROMATHERAPY, :HEALBELL, :REFRESH],
        "healing" => [:TAUNT, :TOXIC],
        "weather" => [:SUNNYDAY, :RAINDANCE, :SANDSTORM, :HAIL, :SNOWSCAPE],
        "terrain" => [:STEELROLLER, :DEFOG],
        "pivot" => [:STEALTHROCK, :SPIKES, :PURSUIT]
      }.freeze

      NATURES = {
        :physical => [:ADAMANT, :JOLLY],
        :special => [:MODEST, :TIMID],
        :support => [:BOLD, :CALM, :CAREFUL, :IMPISH],
        :mixed => [:HARDY, :SERIOUS]
      }.freeze

      ITEMS = {
        :physical => [
          :LIFEORB, :EXPERTBELT, :MUSCLEBAND, :CHOICEBAND,
          :CHOICESCARF, :SITRUSBERRY, :SCOPELENS
        ],
        :special => [
          :LIFEORB, :EXPERTBELT, :WISEGLASSES, :CHOICESPECS,
          :CHOICESCARF, :SITRUSBERRY, :SCOPELENS
        ],
        :support => [
          :LEFTOVERS, :SITRUSBERRY, :LUMBERRY, :FOCUSSASH,
          :ROCKYHELMET, :LIGHTCLAY, :MENTALHERB
        ],
        :mixed => [
          :EXPERTBELT, :SITRUSBERRY, :LUMBERRY, :ASSAULTVEST,
          :SHELLBELL, :QUICKCLAW
        ]
      }.freeze

      RESIST_BERRIES = {
        "NORMAL" => :CHILANBERRY, "FIRE" => :OCCABERRY,
        "WATER" => :PASSHOBERRY, "ELECTRIC" => :WACANBERRY,
        "GRASS" => :RINDOBERRY, "ICE" => :YACHEBERRY,
        "FIGHTING" => :CHOPLEBERRY, "POISON" => :KEBIABERRY,
        "GROUND" => :SHUCABERRY, "FLYING" => :COBABERRY,
        "PSYCHIC" => :PAYAPABERRY, "BUG" => :TANGABERRY,
        "ROCK" => :CHARTIBERRY, "GHOST" => :KASIBBERRY,
        "DRAGON" => :HABANBERRY, "DARK" => :COLBURBERRY,
        "STEEL" => :BABIRIBERRY, "FAIRY" => :ROSELIBERRY
      }.freeze

      BATTLE_ITEMS = [
        :FULLRESTORE, :MAXPOTION, :HYPERPOTION, :FULLHEAL,
        :XATTACK, :XDEFENSE, :XSPEED, :XSPATK, :XSPDEF
      ].freeze

      class RuntimeRng
        def next_u32
          rand(0x1_0000_0000)
        end

        def index(length)
          size = length.to_i
          return nil if size <= 0
          rand(size)
        end

        def pick(values)
          list = Array(values)
          selected = index(list.length)
          selected.nil? ? nil : list[selected]
        end
      end

      class << self
        def enabled?
          truthy?(setting(ENABLED_SETTING, true))
        end

        def changes_for_wins(wins)
          value = wins.to_i
          return 0 if value <= 0
          value >= 7 ? 4 : 3
        end

        def apply(trainer, identity = nil, scope = nil)
          restore(trainer, identity, scope)
          apply_pending(trainer, identity, scope)
        end

        def restore(trainer, identity = nil, _scope = nil)
          return false unless enabled? && trainer && trainer.respond_to?(:party)
          key = identity_value(identity, "key").to_s
          memory = TrainerMemory.find(key)
          return false unless memory
          persisted = normalize_adaptation_state(
            TrainerMemory.adaptation_state(key)
          )
          return false if persisted["party"].empty?
          restore_adaptation_state(trainer, persisted)
        rescue StandardError => e
          log_exception("Trainer adaptation restore failed", e)
          false
        end

        def apply_pending(trainer, identity = nil, _scope = nil)
          return 0 unless enabled? && trainer && trainer.respond_to?(:party)
          key = identity_value(identity, "key").to_s
          memory = TrainerMemory.find(key)
          return 0 unless memory
          wins = memory["revision"].to_i
          losses = memory["loss_revision"].to_i
          return 0 if wins <= 0 && losses <= 0
          snapshot = memory["snapshot"]
          snapshot = memory["loss_snapshot"] unless snapshot.is_a?(Hash)
          return 0 unless snapshot.is_a?(Hash)
          budget = changes_for_wins(wins)

          persisted = normalize_adaptation_state(
            TrainerMemory.adaptation_state(key)
          )
          had_saved_party = !persisted["party"].empty?
          original_party = Array(trainer.party).compact.dup
          return 0 if original_party.empty?

          rng = RuntimeRng.new
          ensure_archetype(persisted, rng)
          ensure_ace(trainer.party)

          applied_revision = persisted["applied_revision"].to_i
          first_revision = had_saved_party ? applied_revision + 1 : wins

          target_types = ranked_keys(snapshot["pokemon_types"])
          lead_types = lead_target_types(snapshot)
          move_types = ranked_keys(snapshot["move_types"])
          changed = 0
          free_natures = 0

          if wins > 0 && first_revision <= wins
            (first_revision..wins).each do |revision|
              rng = RuntimeRng.new
              revision_snapshot = memory["snapshot"].is_a?(Hash) ?
                                    memory["snapshot"] : snapshot
              target_types = ranked_keys(revision_snapshot["pokemon_types"])
              lead_types = lead_target_types(revision_snapshot)
              move_types = ranked_keys(revision_snapshot["move_types"])
              revision_budget = changes_for_wins(revision)
              state = {
                :trainer => trainer,
                :identity => identity,
                :original_party => Array(trainer.party).compact.dup,
                :snapshot => revision_snapshot,
                :target_types => target_types,
                :lead_types => lead_types,
                :move_types => move_types,
                :persisted => persisted,
                :used_counter_moves => {},
                :used_utility_moves => {},
                :used_progression => {},
                :counter_pokemon_used => false
              }
              free_natures += apply_free_natures(trainer.party, rng)
              revision_changes = 0
              action_queue(revision_snapshot, persisted["archetype"], rng).each do |action|
                break if revision_changes >= revision_budget
                applied = apply_action(action, state, rng)
                if applied > 0
                  revision_changes += applied
                  remember_history(persisted, "win", revision, action)
                end
              end
              changed += revision_changes
              persisted["applied_revision"] = revision
            end
          end

          sidegrade_snapshot = memory["loss_snapshot"]
          if sidegrade_snapshot.is_a?(Hash)
            first_loss = had_saved_party ? persisted["applied_loss_revision"].to_i + 1 : losses
            if first_loss <= losses
              (first_loss..losses).each do |loss_revision|
                sidegrade_state = {
                  :trainer => trainer,
                  :identity => identity,
                  :original_party => Array(trainer.party).compact.dup,
                  :snapshot => sidegrade_snapshot,
                  :target_types => ranked_keys(sidegrade_snapshot["pokemon_types"]),
                  :lead_types => lead_target_types(sidegrade_snapshot),
                  :move_types => ranked_keys(sidegrade_snapshot["move_types"]),
                  :persisted => persisted,
                  :used_counter_moves => {},
                  :used_utility_moves => {}
                }
                action = apply_loss_sidegrade(sidegrade_state, RuntimeRng.new)
                remember_history(persisted, "loss", loss_revision, action) if action
                persisted["applied_loss_revision"] = loss_revision
              end
            end
          end

          if apply_adaptive_lead(trainer.party, lead_types)
            remember_history(persisted, "free", wins, :lead)
          end

          capture_adaptation_state(trainer, persisted)
          TrainerMemory.save_adaptation_state(key, persisted)
          log_adaptation(trainer, memory, budget, changed, free_natures)
          changed
        rescue StandardError => e
          log_exception("Trainer adaptation failed", e)
          0
        end

        def clear_caches!
          @counter_move_cache = nil
          true
        end

        private

        def normalize_adaptation_state(value)
          source = value.is_a?(Hash) ? value : {}
          recent = source["recent"].is_a?(Hash) ? source["recent"] : {}
          {
            "applied_revision" => [source["applied_revision"].to_i, 0].max,
            "applied_loss_revision" => [source["applied_loss_revision"].to_i, 0].max,
            "archetype" => normalize_archetype(source["archetype"]),
            "party" => Array(source["party"]).select { |entry| entry.is_a?(Hash) },
            "pink_slip_operations" => string_array(source["pink_slip_operations"], 100),
            "battle_items" => string_array(source["battle_items"], 8),
            "history" => Array(source["history"]).select { |entry| entry.is_a?(Hash) }.last(30),
            "recent" => {
              "items" => string_array(recent["items"], 10),
              "moves" => string_array(recent["moves"], 12),
              "species" => string_array(recent["species"], 8)
            }
          }
        end

        def normalize_archetype(value)
          candidate = value.to_s.downcase.to_sym rescue nil
          ARCHETYPES.include?(candidate) ? candidate.to_s : nil
        end

        def ensure_archetype(persisted, rng)
          current = normalize_archetype(persisted["archetype"])
          persisted["archetype"] = current || rng.pick(ARCHETYPES).to_s
        end

        def ensure_ace(party)
          members = Array(party).compact
          return false if members.empty?
          return true if members.any? { |pokemon| pokemon.instance_variable_get(ACE_IVAR) }
          authored = members.reject do |pokemon|
            pokemon.instance_variable_get(ADDED_IVAR) ||
              pokemon.instance_variable_get(TeamExpansion::ADDED_IVAR)
          end
          authored = members if authored.empty?
          ace = authored.each_with_index.max_by do |pokemon, index|
            [pokemon.level.to_i, index]
          end
          ace[0].instance_variable_set(ACE_IVAR, true) if ace
          !!ace
        rescue StandardError
          false
        end

        def remember_history(persisted, kind, revision, action)
          return false unless persisted.is_a?(Hash) && action
          values = Array(persisted["history"]).select { |entry| entry.is_a?(Hash) }
          values << {
            "kind" => kind.to_s,
            "revision" => revision.to_i,
            "action" => action.to_s
          }
          persisted["history"] = values.last(30)
          true
        end

        def restore_adaptation_state(trainer, persisted)
          restore_battle_items(trainer, persisted["battle_items"])
          if defined?(PinkSlips)
            PinkSlips.restore_applied_operations(
              trainer, persisted["pink_slip_operations"]
            )
          end
          blueprint = Array(persisted["party"])
          blueprint.each_with_index do |entry, index|
            species = symbol_value(entry["species"])
            next unless species && defined?(GameData::Species) &&
                               GameData::Species.exists?(species)
            current = trainer.party[index]
            unless current && current.respond_to?(:species) && current.species == species
              level = if current && current.respond_to?(:level)
                        current.level.to_i
                      else
                        entry["level"].to_i
                      end
              level = average_level(trainer.party) if level <= 0
              current = Pokemon.new(species, [level, 1].max, trainer)
              trainer.party[index] = current
            end
            apply_pokemon_blueprint(current, entry)
          end
          if !persisted["pink_slip_operations"].empty? &&
             trainer.party.length > blueprint.length
            trainer.party.slice!(blueprint.length, trainer.party.length - blueprint.length)
          end
          true
        rescue StandardError => e
          log_exception("Could not restore trainer adaptation state", e)
          false
        end

        def restore_battle_items(trainer, values)
          return false unless trainer.respond_to?(:items) && trainer.respond_to?(:items=)
          items = Array(trainer.items).compact
          Array(values).each do |value|
            item = symbol_value(value)
            next unless item && GameData::Item.exists?(item)
            items << item unless items.include?(item)
          end
          trainer.items = items
          true
        rescue StandardError
          false
        end

        def apply_pokemon_blueprint(pokemon, entry)
          if pokemon.respond_to?(:form=) && !entry["form"].nil?
            pokemon.form = entry["form"].to_i
          end
          nature = symbol_value(entry["nature"])
          pokemon.nature = nature if nature && pokemon.respond_to?(:nature=) &&
                                     GameData::Nature.exists?(nature)
          item = symbol_value(entry["item"])
          pokemon.item = item if pokemon.respond_to?(:item=) &&
                                 (!item || GameData::Item.exists?(item))
          moves = Array(entry["moves"]).map { |value| symbol_value(value) }.
            compact.select { |move| GameData::Move.exists?(move) }.first(4)
          if pokemon.respond_to?(:moves) && !moves.empty?
            pokemon.moves.replace(moves.map { |move| Pokemon::Move.new(move) })
          end
          pokemon.instance_variable_set(ADDED_IVAR, true) if entry["adaptive"]
          pokemon.instance_variable_set(ACE_IVAR, true) if entry["ace"]
          pokemon.instance_variable_set(
            TeamExpansion::ADDED_IVAR, true
          ) if entry["expanded"]
          if defined?(PinkSlips) && entry["pink_slip_id"]
            pokemon.instance_variable_set(
              PinkSlips::MEMBER_IVAR, entry["pink_slip_id"].to_s
            )
          end
          pokemon.calc_stats if pokemon.respond_to?(:calc_stats)
          true
        rescue StandardError
          false
        end

        def capture_adaptation_state(trainer, persisted)
          if defined?(PinkSlips)
            persisted["pink_slip_operations"] = PinkSlips.applied_operations(trainer)
          end
          persisted["party"] = Array(trainer.party).compact.map do |pokemon|
            {
              "species" => pokemon.species.to_s,
              "form" => pokemon.respond_to?(:form) ? pokemon.form.to_i : 0,
              "level" => pokemon.level.to_i,
              "nature" => pokemon.respond_to?(:nature_id) && pokemon.nature_id ?
                            pokemon.nature_id.to_s : nil,
              "item" => pokemon.respond_to?(:item_id) && pokemon.item_id ?
                          pokemon.item_id.to_s : nil,
              "moves" => Array(pokemon.moves).map { |move| move.id.to_s }.first(4),
              "adaptive" => !!pokemon.instance_variable_get(ADDED_IVAR),
              "ace" => !!pokemon.instance_variable_get(ACE_IVAR),
              "expanded" => !!pokemon.instance_variable_get(TeamExpansion::ADDED_IVAR),
              "pink_slip_id" => if defined?(PinkSlips)
                                    pokemon.instance_variable_get(PinkSlips::MEMBER_IVAR)
                                  end
            }
          end
          true
        rescue StandardError => e
          log_exception("Could not capture trainer adaptation state", e)
          false
        end

        def string_array(values, limit)
          Array(values).map { |value| value.to_s }.reject { |value| value.empty? }.
            last(limit.to_i)
        end

        def symbol_value(value)
          return value if value.is_a?(Symbol)
          text = value.to_s
          text.empty? ? nil : text.to_sym
        rescue StandardError
          nil
        end

        def action_queue(snapshot, archetype, rng)
          weights = action_weights(snapshot, archetype)
          queue = []
          8.times { queue << weighted_pick(weights, rng) }
          actions = weights.keys
          queue + random_shuffle(actions, rng) +
            random_shuffle(actions.reject { |action| action == :counter_pokemon }, rng)
        end

        def action_weights(snapshot, archetype = nil)
          weights = {
            :item => 2,
            :battle_item => 2,
            :counter_move => 3,
            :utility => 2,
            :counter_pokemon => 2,
            :evolution => 2,
            :move_upgrade => 3
          }
          pokemon_types = total_observations(snapshot["pokemon_types"])
          leads = total_observations(snapshot["leads"])
          move_types = total_observations(snapshot["move_types"])
          weights[:counter_move] += [pokemon_types, 8].min
          weights[:counter_move] += [leads, 4].min
          weights[:counter_pokemon] += [pokemon_types, 6].min
          weights[:counter_pokemon] += [move_types, 6].min
          weights[:item] += [move_types, 6].min
          weights[:battle_item] += [move_types, 4].min

          styles = snapshot["styles"].is_a?(Hash) ? snapshot["styles"] : {}
          styles.each do |style, raw_count|
            count = [[raw_count.to_i, 0].max, 5].min
            case style.to_s
            when "setup", "healing"
              weights[:utility] += count * 4
              weights[:battle_item] += count
            when "hazard", "status"
              weights[:utility] += count * 3
              weights[:item] += count * 3
              weights[:battle_item] += count * 2
            when "weather", "terrain", "pivot"
              weights[:utility] += count * 3
            end
          end
          apply_archetype_weights(weights, archetype)
          weights
        end

        def apply_archetype_weights(weights, archetype)
          case normalize_archetype(archetype)
          when "aggressive"
            weights[:counter_move] += 5
            weights[:counter_pokemon] += 4
            weights[:move_upgrade] += 4
          when "defensive"
            weights[:item] += 6
            weights[:battle_item] += 4
            weights[:evolution] += 2
          when "control"
            weights[:utility] += 7
            weights[:counter_move] += 2
            weights[:item] += 2
          else
            weights[:item] += 1
            weights[:counter_move] += 1
            weights[:move_upgrade] += 1
          end
          weights
        end

        def weighted_pick(weights, rng)
          total = weights.values.inject(0) { |sum, value| sum + value.to_i }
          return weights.keys.first if total <= 0
          roll = rng.next_u32 % total
          weights.each do |action, weight|
            roll -= weight.to_i
            return action if roll < 0
          end
          weights.keys.last
        end

        def total_observations(values)
          return 0 unless values.is_a?(Hash)
          values.values.inject(0) { |sum, count| sum + count.to_i }
        end

        def recent_choices(persisted, kind)
          return [] unless persisted.is_a?(Hash)
          recent = persisted["recent"]
          return [] unless recent.is_a?(Hash)
          Array(recent[kind.to_s]).map { |value| value.to_s }
        end

        def remember_choice(persisted, kind, value, limit)
          return false unless persisted.is_a?(Hash) && value
          persisted["recent"] = {} unless persisted["recent"].is_a?(Hash)
          key = kind.to_s
          values = Array(persisted["recent"][key]).map { |entry| entry.to_s }
          values << value.to_s
          persisted["recent"][key] = values.last(limit.to_i)
          true
        end

        def weighted_candidate_pick(candidates, rng, recent)
          values = Array(candidates).compact
          return nil if values.empty?
          recent_values = Array(recent).map { |value| value.to_s }
          weighted = values.map do |candidate|
            id = candidate.respond_to?(:id) ? candidate.id.to_s : candidate.to_s
            weight = block_given? ? yield(candidate).to_i : 20
            weight = [weight, 5].max
            recency = recent_values.reverse.index(id)
            if recency == 0
              weight = [weight / 4, 2].max
            elsif recency && recency <= 2
              weight = [weight / 2, 3].max
            elsif recency
              weight = [weight * 3 / 4, 4].max
            end
            [candidate, weight]
          end
          total = weighted.inject(0) { |sum, pair| sum + pair[1] }
          return rng.pick(values) if total <= 0
          roll = rng.next_u32 % total
          weighted.each do |candidate, weight|
            roll -= weight
            return candidate if roll < 0
          end
          weighted.last[0]
        end

        def random_shuffle(values, rng)
          result = Array(values).dup
          (result.length - 1).downto(1) do |index|
            other = rng.index(index + 1)
            result[index], result[other] = result[other], result[index]
          end
          result
        end

        def apply_action(action, state, rng)
          case action
          when :item
            apply_one_item(state, rng)
          when :battle_item
            apply_battle_item(state, rng)
          when :counter_move
            apply_one_counter_move(state, rng)
          when :utility
            apply_one_utility_move(state, rng)
          when :counter_pokemon
            return 0 if state[:counter_pokemon_used]
            state[:counter_pokemon_used] = true
            add_counter_pokemon(
              state[:trainer], state[:original_party], state[:target_types],
              state[:move_types], state[:identity], state[:persisted], rng
            )
          when :evolution
            apply_one_evolution(state, rng)
          when :move_upgrade
            apply_one_move_upgrade(state, rng)
          else
            0
          end
        end

        def apply_free_natures(party, rng)
          Array(party).compact.inject(0) do |total, pokemon|
            total + apply_nature(pokemon, role_for(pokemon), rng)
          end
        end

        def apply_one_item(state, rng)
          blocked = Array(state[:trainer].party).map do |pokemon|
            pokemon.item_id.to_s if pokemon.respond_to?(:item_id) && pokemon.item_id
          end.compact
          shuffled_party(state[:trainer].party, rng).each do |pokemon|
            changed = apply_item(
              pokemon, role_for(pokemon), state[:snapshot], rng,
              blocked, state[:persisted]
            )
            return changed if changed > 0
          end
          0
        end

        def apply_battle_item(state, rng)
          trainer = state[:trainer]
          persisted = state[:persisted]
          return 0 unless trainer.respond_to?(:items) && trainer.respond_to?(:items=)
          saved = Array(persisted["battle_items"])
          return 0 if saved.length >= 4
          current = Array(trainer.items).compact
          candidates = BATTLE_ITEMS.select do |item|
            GameData::Item.exists?(item) && !current.include?(item)
          end
          selected = weighted_candidate_pick(
            candidates, rng, recent_choices(persisted, "items")
          ) { |_item| 30 }
          return 0 unless selected
          current << selected
          trainer.items = current
          saved << selected.to_s
          persisted["battle_items"] = saved.last(4)
          remember_choice(persisted, "items", selected, 10)
          1
        rescue StandardError
          0
        end

        def apply_one_counter_move(state, rng, replace_only = false)
          shuffled_party(state[:trainer].party, rng).each do |pokemon|
            next if state[:used_counter_moves][pokemon.object_id]
            state[:used_counter_moves][pokemon.object_id] = true
            index = Array(state[:trainer].party).index(pokemon).to_i
            targets = index == 0 && !state[:lead_types].empty? ?
                        (state[:lead_types] + state[:target_types]).uniq :
                        state[:target_types]
            changed = apply_counter_move(
              pokemon, role_for(pokemon), targets, rng, state[:persisted],
              replace_only
            )
            return changed if changed > 0
          end
          0
        end

        def apply_one_utility_move(state, rng, replace_only = false)
          shuffled_party(state[:trainer].party, rng).each do |pokemon|
            next if state[:used_utility_moves][pokemon.object_id]
            state[:used_utility_moves][pokemon.object_id] = true
            changed = apply_utility_response(
              pokemon, role_for(pokemon), state[:snapshot], rng,
              state[:persisted], replace_only
            )
            return changed if changed > 0
          end
          0
        end

        def apply_loss_sidegrade(state, rng)
          weights = action_weights(state[:snapshot], state[:persisted]["archetype"])
          allowed = {
            :item => weights[:item],
            :counter_move => weights[:counter_move],
            :utility => weights[:utility]
          }
          queue = []
          5.times { queue << weighted_pick(allowed, rng) }
          queue.concat(random_shuffle(allowed.keys, rng))
          queue.each do |action|
            changed = case action
                      when :item
                        apply_item_sidegrade(state, rng)
                      when :counter_move
                        apply_one_counter_move(state, rng, true)
                      when :utility
                        apply_one_utility_move(state, rng, true)
                      else
                        0
                      end
            return action if changed > 0
          end
          nil
        end

        def apply_item_sidegrade(state, rng)
          party = Array(state[:trainer].party).compact
          blocked = party.map do |pokemon|
            pokemon.item_id.to_s if pokemon.respond_to?(:item_id) && pokemon.item_id
          end.compact
          shuffled_party(party, rng).each do |pokemon|
            current = pokemon.respond_to?(:item_id) ? pokemon.item_id : nil
            next unless current
            role = role_for(pokemon)
            candidates = Array(ITEMS[role]).dup
            ranked_keys(state[:snapshot]["move_types"]).first(3).each do |type|
              berry = RESIST_BERRIES[type.to_s.upcase]
              candidates << berry if berry
            end
            candidates.select! do |item|
              GameData::Item.exists?(item) && item != current &&
                !blocked.include?(item.to_s)
            end
            selected = weighted_candidate_pick(
              candidates.uniq, rng,
              recent_choices(state[:persisted], "items")
            ) { |_item| 30 }
            next unless selected
            pokemon.item = selected
            remember_choice(state[:persisted], "items", selected, 10)
            return 1
          end
          0
        rescue StandardError
          0
        end

        def apply_adaptive_lead(party, target_types)
          members = Array(party).compact
          targets = Array(target_types).first(3)
          return false if members.length < 2 || targets.empty?
          scores = members.map { |pokemon| adaptive_lead_score(pokemon, targets) }
          best_index = scores.each_index.max_by { |index| [scores[index], -index] }
          return false unless best_index && best_index > 0
          return false unless scores[best_index] > scores[0]
          selected = members.delete_at(best_index)
          members.unshift(selected)
          party.replace(members)
          true
        rescue StandardError
          false
        end

        def adaptive_lead_score(pokemon, target_types)
          score = 0
          pokemon_types = [pokemon.type1, pokemon.type2].compact rescue []
          Array(pokemon.moves).each do |known|
            move = GameData::Move.try_get(known.id) rescue nil
            next unless move && move.base_damage.to_i > 0
            Array(target_types).each_with_index do |target, index|
              target_id = target.to_s.upcase.to_sym
              if Effectiveness.super_effective_type?(move.type, target_id)
                score += 120 - index * 20
              end
            end
            score += move.base_damage.to_i / 4
          end
          Array(target_types).each_with_index do |attack, index|
            attack_id = attack.to_s.upcase.to_sym
            if Effectiveness.resistant_type?(attack_id, *pokemon_types)
              score += 70 - index * 10
            elsif Effectiveness.super_effective_type?(attack_id, *pokemon_types)
              score -= 80 - index * 10
            end
          end
          score
        rescue StandardError
          0
        end

        def apply_one_evolution(state, rng)
          candidates = shuffled_party(state[:trainer].party, rng).reject do |pokemon|
            state[:used_progression][pokemon.object_id]
          end
          candidates.each do |pokemon|
            state[:used_progression][pokemon.object_id] = true
            next if fused_pokemon?(pokemon)
            evolved = pokemon.check_evolution_on_level_up rescue nil
            next unless evolved && GameData::Species.exists?(evolved)
            pokemon.species = evolved
            pokemon.calc_stats if pokemon.respond_to?(:calc_stats)
            return 1
          end
          0
        rescue StandardError
          0
        end

        def apply_one_move_upgrade(state, rng)
          candidates = shuffled_party(state[:trainer].party, rng).reject do |pokemon|
            state[:used_progression][pokemon.object_id]
          end
          candidates.each do |pokemon|
            state[:used_progression][pokemon.object_id] = true
            changed = apply_level_move_upgrade(pokemon, rng, state[:persisted])
            return changed if changed > 0
          end
          0
        end

        def apply_level_move_upgrade(pokemon, rng, persisted)
          return 0 unless pokemon.respond_to?(:getMoveList) && pokemon.respond_to?(:moves)
          known = move_ids(pokemon)
          learnable = Array(pokemon.getMoveList).select do |entry|
            entry.is_a?(Array) && entry[0].to_i <= pokemon.level.to_i &&
              GameData::Move.exists?(entry[1]) && !known.include?(entry[1])
          end.map { |entry| GameData::Move.get(entry[1]) }
          learnable.select! { |move| move.base_damage.to_i > 0 }
          return 0 if learnable.empty?
          role = role_for(pokemon)
          current = Array(pokemon.moves).map do |move|
            GameData::Move.try_get(move.id) rescue nil
          end
          replaceable = current.each_index.select do |index|
            move = current[index]
            next false unless move && move.base_damage.to_i > 0
            (role == :physical && move.physical?) ||
              (role == :special && move.special?) ||
              ![:physical, :special].include?(role)
          end
          return 0 if replaceable.empty?
          weakest = replaceable.min_by { |index| move_score(current[index], role, pokemon) }
          minimum = move_score(current[weakest], role, pokemon)
          upgrades = learnable.select { |move| move_score(move, role, pokemon) > minimum + 100 }
          return 0 if upgrades.empty?
          selected = weighted_candidate_pick(
            upgrades, rng, recent_choices(persisted, "moves")
          ) { |move| [move_score(move, role, pokemon) / 10, 10].max }
          return 0 unless selected
          pokemon.moves[weakest] = Pokemon::Move.new(selected.id)
          remember_choice(persisted, "moves", selected.id, 12)
          1
        rescue StandardError
          0
        end

        def fused_pokemon?(pokemon)
          return true if pokemon.respond_to?(:isFusion?) && pokemon.isFusion?
          defined?(GameData::FusedSpecies) &&
            pokemon.respond_to?(:species_data) &&
            pokemon.species_data.is_a?(GameData::FusedSpecies)
        rescue StandardError
          false
        end

        def shuffled_party(party, rng)
          random_shuffle(Array(party).compact, rng)
        end

        def apply_nature(pokemon, role, rng)
          return 0 unless pokemon.respond_to?(:nature=) && defined?(GameData::Nature)
          candidates = Array(NATURES[role]).select { |id| GameData::Nature.exists?(id) }
          current = pokemon.respond_to?(:nature_id) ? pokemon.nature_id : nil
          candidates.reject! { |id| id == current }
          selected = rng.pick(candidates)
          return 0 unless selected
          pokemon.nature = selected
          1
        rescue StandardError
          0
        end

        def apply_item(pokemon, role, snapshot, rng,
                       blocked_items = [], persisted = nil)
          return 0 unless pokemon.respond_to?(:item=) && defined?(GameData::Item)
          current = pokemon.respond_to?(:item_id) ? pokemon.item_id : nil
          return 0 if current
          candidates = Array(ITEMS[role]).dup
          styles = snapshot["styles"].is_a?(Hash) ? snapshot["styles"] : {}
          ranked_keys(snapshot["move_types"]).first(3).reverse_each do |type|
            berry = RESIST_BERRIES[type.to_s.upcase]
            candidates.unshift(berry) if berry
          end
          candidates.unshift(:HEAVYDUTYBOOTS) if styles["hazard"].to_i > 0
          candidates.unshift(:LUMBERRY) if styles["status"].to_i > 0
          candidates.select! { |id| GameData::Item.exists?(id) }
          blocked = Array(blocked_items).map { |item| item.to_s }
          candidates = candidates.uniq.reject { |item| blocked.include?(item.to_s) }
          selected = weighted_candidate_pick(
            candidates, rng, recent_choices(persisted, "items")
          ) do |item|
            30 + (candidates.length - candidates.index(item).to_i) * 2
          end
          return 0 unless selected
          pokemon.item = selected
          remember_choice(persisted, "items", selected, 10)
          1
        rescue StandardError
          0
        end

        def apply_counter_move(pokemon, role, target_types, rng, persisted = nil,
                               replace_only = false)
          return 0 unless pokemon.respond_to?(:compatible_with_move?)
          existing = move_ids(pokemon)
          candidates = Array(target_types).first(3).flat_map do |type|
            counter_moves_for(type)
          end.uniq
          candidates.select! do |move|
            !existing.include?(move.id) && pokemon.compatible_with_move?(move.id)
          end
          return 0 if candidates.empty?
          selected = weighted_candidate_pick(
            candidates, rng, recent_choices(persisted, "moves")
          ) { |move| [move_score(move, role, pokemon) / 15, 10].max }
          changed = replace_move(pokemon, selected, role, false, !replace_only)
          remember_choice(persisted, "moves", selected.id, 12) if changed > 0
          changed
        rescue StandardError
          0
        end

        def apply_utility_response(pokemon, role, snapshot, rng, persisted = nil,
                                   replace_only = false)
          styles = snapshot["styles"]
          return 0 unless styles.is_a?(Hash) && !styles.empty?
          existing = move_ids(pokemon)
          candidates = ranked_keys(styles).first(2).flat_map do |style|
            Array(UTILITY_RESPONSES[style])
          end.uniq
          candidates.select! do |move_id|
            GameData::Move.exists?(move_id) && !existing.include?(move_id) &&
              pokemon.compatible_with_move?(move_id)
          end
          selected = weighted_candidate_pick(
            candidates, rng, recent_choices(persisted, "moves")
          ) { |_move| 30 }
          return 0 unless selected
          changed = replace_move(
            pokemon, GameData::Move.get(selected), role, true, !replace_only
          )
          remember_choice(persisted, "moves", selected, 12) if changed > 0
          changed
        rescue StandardError
          0
        end

        def replace_move(pokemon, move_data, role, utility = false, allow_add = true)
          return 0 unless move_data && pokemon.respond_to?(:moves)
          moves = Array(pokemon.moves)
          new_move = Pokemon::Move.new(move_data.id)
          if moves.length < 4 && allow_add
            moves << new_move
            return 1
          end
          index = replacement_index(pokemon, role, utility)
          return 0 if index.nil?
          moves[index] = new_move
          1
        rescue StandardError
          0
        end

        def replacement_index(pokemon, role, utility)
          moves = Array(pokemon.moves)
          data = moves.map { |move| GameData::Move.try_get(move.id) rescue nil }
          damaging = data.each_index.select { |index| data[index] && data[index].base_damage.to_i > 0 }
          status = data.each_index.select { |index| data[index] && data[index].base_damage.to_i <= 0 }
          if utility
            return status.last if status.length > 1
          elsif !status.empty?
            return status.last
          end
          return nil if damaging.length <= 1
          preferred = role == :physical ? :physical? : (role == :special ? :special? : nil)
          candidates = damaging.reject do |index|
            preferred && data[index].respond_to?(preferred) && data[index].send(preferred)
          end
          candidates = damaging if candidates.empty?
          protected_index = strongest_stab_index(pokemon, data)
          candidates = candidates.reject { |index| index == protected_index }
          return nil if candidates.empty?
          candidates.min_by { |index| data[index].base_damage.to_i }
        rescue StandardError
          nil
        end

        def strongest_stab_index(pokemon, move_data)
          types = [pokemon.type1, pokemon.type2].compact
          candidates = move_data.each_index.select do |index|
            move = move_data[index]
            move && move.base_damage.to_i > 0 && types.include?(move.type)
          end
          candidates.max_by { |index| move_data[index].base_damage.to_i }
        rescue StandardError
          nil
        end

        def add_counter_pokemon(trainer, original_party, target_types,
                                move_types, identity, persisted, rng)
          target = Array(target_types).first
          return 0 unless target
          required_type = required_theme_type(trainer, original_party)
          candidates = TeamExpansion.adaptation_candidates(required_type)
          existing = Array(trainer.party).map { |pokemon| pokemon.species rescue nil }.compact
          candidates.select! do |species|
            !existing.include?(species.id) && species_counters_type?(species, target)
          end
          selected = weighted_candidate_pick(
            candidates, rng, recent_choices(persisted, "species")
          ) do |species|
            [species_counter_score(species, target_types, move_types), 10].max
          end
          return 0 unless selected
          level = average_level(trainer.party)
          pokemon = Pokemon.new(selected.id, level, trainer)
          pokemon.personalID = rng.next_u32 if pokemon.respond_to?(:personalID=)
          pokemon.shiny = false if pokemon.respond_to?(:shiny=)
          pokemon.instance_variable_set(ADDED_IVAR, true)
          if Array(trainer.party).length < max_party_size
            trainer.party << pokemon
          else
            index = replacement_party_index(trainer)
            return 0 if index.nil?
            trainer.party[index] = pokemon
          end
          role = role_for(pokemon)
          apply_nature(pokemon, role, rng)
          blocked = Array(trainer.party).map do |member|
            member.item_id.to_s if member.respond_to?(:item_id) && member.item_id
          end.compact
          apply_item(
            pokemon, role, { "styles" => {}, "move_types" => {} }, rng,
            blocked, persisted
          )
          apply_counter_move(pokemon, role, target_types, rng, persisted)
          remember_choice(persisted, "species", selected.id, 8)
          pokemon.calc_stats if pokemon.respond_to?(:calc_stats)
          1
        rescue StandardError => e
          log_exception("Could not add adaptive counter Pokemon", e)
          0
        end

        def replacement_party_index(trainer)
          return nil if protected_roster?(trainer)
          party = Array(trainer.party)
          expanded = party.each_index.select do |index|
            party[index].instance_variable_get(TeamExpansion::ADDED_IVAR)
          end
          candidates = expanded.empty? ? party.each_index.to_a : expanded
          candidates = candidates.reject do |index|
            party[index].instance_variable_get(ACE_IVAR)
          end
          candidates.min_by do |index|
            pokemon = party[index]
            [pokemon.level.to_i, pokemon.totalhp.to_i, index]
          end
        rescue StandardError
          nil
        end

        def required_theme_type(trainer, party)
          gym_type = TeamExpansion.current_gym_type
          return gym_type if gym_type
          if trainer_type(trainer).include?("LEADER")
            return TeamExpansion.dominant_party_types(party).first
          end
          return nil unless TeamExpansion.selection_mode == TeamExpansion::MODE_THEME
          TeamExpansion.dominant_party_types(party).first
        rescue StandardError
          nil
        end

        def protected_roster?(trainer)
          type = trainer_type(trainer)
          return true if type =~ /(LEADER|ELITEFOUR|CHAMPION|BOSS)/
          return true if switch_on?(defined?(SWITCH_TRIPLE_BOSS_BATTLE) ?
                                     SWITCH_TRIPLE_BOSS_BATTLE : nil)
          return true if switch_on?(defined?(SWITCH_SILVERBOSS_BATTLE) ?
                                     SWITCH_SILVERBOSS_BATTLE : nil)
          false
        end

        def switch_on?(id)
          id && defined?($game_switches) && $game_switches && $game_switches[id]
        rescue StandardError
          false
        end

        def role_for(pokemon)
          data = Array(pokemon.moves).map do |move|
            GameData::Move.try_get(move.id) rescue nil
          end.compact
          status = data.count { |move| move.base_damage.to_i <= 0 }
          return :support if status >= 2
          physical = data.count { |move| move.respond_to?(:physical?) && move.physical? }
          special = data.count { |move| move.respond_to?(:special?) && move.special? }
          return :physical if physical > special
          return :special if special > physical
          if pokemon.respond_to?(:attack) && pokemon.respond_to?(:spatk)
            return :physical if pokemon.attack.to_i > pokemon.spatk.to_i * 11 / 10
            return :special if pokemon.spatk.to_i > pokemon.attack.to_i * 11 / 10
          end
          :mixed
        rescue StandardError
          :mixed
        end

        def counter_moves_for(target_type)
          @counter_move_cache ||= {}
          key = target_type.to_s.upcase.to_sym
          @counter_move_cache[key] ||= begin
            values = []
            GameData::Move.each do |move|
              next if move.base_damage.to_i <= 0
              next unless Effectiveness.super_effective_type?(move.type, key)
              values << move
            end
            values.freeze
          end
        rescue StandardError
          []
        end

        def species_counters_type?(species, target_type)
          types = species_types(species)
          Array(types).compact.any? do |type|
            Effectiveness.super_effective_type?(type, target_type.to_s.upcase.to_sym)
          end
        rescue StandardError
          false
        end

        def species_counter_score(species, target_types, move_types)
          types = species_types(species)
          return 0 if types.empty?
          score = 0
          Array(target_types).first(3).each_with_index do |target, index|
            if types.any? { |type| Effectiveness.super_effective_type?(type, target.to_s.upcase.to_sym) }
              score += 100 - index * 20
            end
          end
          Array(move_types).first(3).each_with_index do |attack, index|
            attack_type = attack.to_s.upcase.to_sym
            if Effectiveness.resistant_type?(attack_type, *types.first(3))
              score += 80 - index * 15
            elsif Effectiveness.super_effective_type?(attack_type, *types.first(3))
              score -= 60 - index * 10
            end
          end
          score
        rescue StandardError
          0
        end

        def species_types(species)
          values = species.respond_to?(:types) ? species.types :
                   [species.type1, species.type2]
          Array(values).compact.map { |type| type.to_sym }.uniq
        rescue StandardError
          []
        end

        def move_score(move, role, pokemon)
          score = move.base_damage.to_i * 10
          score += move.accuracy.to_i
          score += 250 if role == :physical && move.physical?
          score += 250 if role == :special && move.special?
          types = [pokemon.type1, pokemon.type2] rescue []
          score += 100 if types.compact.include?(move.type)
          score
        end

        def lead_target_types(snapshot)
          leads = ranked_keys(snapshot["leads"])
          return [] if leads.empty?
          types = []
          leads.first(2).each do |species_id|
            data = GameData::Species.try_get(species_id.to_sym) rescue nil
            next unless data
            values = data.respond_to?(:types) ? data.types : [data.type1, data.type2]
            Array(values).compact.each { |type| types << type.to_s }
          end
          types.uniq
        rescue StandardError
          []
        end

        def ranked_keys(counts)
          return [] unless counts.is_a?(Hash)
          counts.sort_by { |name, count| [-count.to_i, name.to_s] }.
            map { |name, _count| name.to_s }
        end

        def move_ids(pokemon)
          Array(pokemon.moves).map { |move| move.id }
        rescue StandardError
          []
        end

        def average_level(party)
          values = Array(party).map { |pokemon| pokemon.level.to_i rescue nil }.
            compact.select { |level| level > 0 }
          return 1 if values.empty?
          (values.inject(0) { |sum, level| sum + level }.to_f / values.length).round
        end

        def max_party_size
          value = defined?(Settings::MAX_PARTY_SIZE) ? Settings::MAX_PARTY_SIZE.to_i : 6
          value > 0 ? value : 6
        end

        def trainer_type(trainer)
          trainer.respond_to?(:trainer_type) ? trainer.trainer_type.to_s.upcase : ""
        rescue StandardError
          ""
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

        def log_adaptation(trainer, memory, budget, changed, free_natures)
          return if changed <= 0 || !defined?(KantoReloaded::Log)
          name = trainer.respond_to?(:name) ? trainer.name.to_s : "Trainer"
          KantoReloaded::Log.debug(
            "Adapted #{name} revision=#{memory["revision"]} " \
            "budget=#{budget} changes=#{changed} natures=#{free_natures}",
            :trainer_control
          )
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
