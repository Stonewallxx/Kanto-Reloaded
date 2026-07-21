#==============================================================================
# Kanto Reloaded - Healing Overworld Moves
#==============================================================================
# Adds healing moves to KIF's existing field-move path without replacing the
# party screen or mutating HiddenMoveHandlers registries.
#==============================================================================

module KantoReloaded
  module HealingOverworld
    SETTING_KEY = :healing_overworld_moves
    OVERWORLD_KEY = :healing_overworld_moves

    TARGETED_OTHER_HEAL = [:HEALPULSE].freeze
    TARGETED_HEAL = [:WISH, :FLORALHEALING].freeze
    SELF_HEAL = [
      :ROOST, :RECOVER, :SYNTHESIS, :HEALORDER, :SHOREUP, :SLACKOFF
    ].freeze
    TIME_MOVES = [:MORNINGSUN, :MOONLIGHT].freeze
    PARTY_HEAL = [:LIFEDEW, :LUNARBLESSING, :JUNGLEHEALING].freeze
    PARTY_STATUS = [:AROMATHERAPY, :HEALBELL].freeze
    SPECIAL_MOVES = [
      :REVIVALBLESSING, :HEALINGWISH, :LUNARDANCE, :POLLENPUFF,
      :PRESENT, :PURIFY, :DREAMEATER, :AQUARING, :REFRESH, :REST
    ].freeze
    HANDLED_MOVES = (
      TARGETED_OTHER_HEAL + TARGETED_HEAL + SELF_HEAL + TIME_MOVES +
      PARTY_HEAL + PARTY_STATUS + SPECIAL_MOVES
    ).uniq.freeze

    @enabled_cache = nil

    class << self
      def install
        register_setting
        register_overworld_menu
        register_setting_callback
        cache_enabled(KantoReloaded::Settings.get(SETTING_KEY, 1))
        hooks_ready = register_hooks
        if defined?(KantoReloaded::Log)
          state = hooks_ready ? "ready" : "unavailable"
          KantoReloaded::Log.info(
            "Installed Healing Overworld Moves module (hooks #{state})",
            :modules
          )
        end
        hooks_ready
      rescue StandardError => e
        KantoReloaded::Log.exception(
          "Healing Overworld Moves install failed", e, channel: :modules
        ) if defined?(KantoReloaded::Log)
        false
      end

      def enabled?
        return @enabled_cache unless @enabled_cache.nil?
        cache_enabled(KantoReloaded::Settings.get(SETTING_KEY, 1))
      rescue StandardError
        false
      end

      def cache_enabled(value)
        @enabled_cache = value == true ||
          (value.respond_to?(:to_i) && value.to_i == 1)
      end

      def toggle
        value = enabled? ? 0 : 1
        stored = KantoReloaded::Settings.set(SETTING_KEY, value)
        cache_enabled(stored)
      rescue StandardError
        false
      end

      def handles?(value)
        HANDLED_MOVES.include?(normalize_move_id(value))
      end

      def can_use?(pokemon, move_id, show_message = true)
        id = normalize_move_id(move_id)
        move = move_object(pokemon, id)
        return reject(show_message, _INTL("That move can't be used here.")) unless move
        return reject(show_message, _INTL("Eggs can't use field moves.")) if pokemon.egg?
        return reject(show_message, _INTL("{1} can't use that move while fainted.", pokemon.name)) if pokemon.fainted?
        return reject(show_message, _INTL("Not enough PP...")) if move.pp <= 0
        return true if effect_available?(pokemon, id)
        reject(show_message, unavailable_message(id))
      rescue StandardError => e
        KantoReloaded::Log.exception(
          "Healing move availability check failed", e, channel: :modules
        ) if defined?(KantoReloaded::Log)
        false
      end

      def use(pokemon, move_id)
        id = normalize_move_id(move_id)
        return false unless can_use?(pokemon, id, true)
        move = move_object(pokemon, id)

        case id
        when *TARGETED_OTHER_HEAL
          use_targeted_heal(pokemon, move, false)
        when *TARGETED_HEAL
          use_targeted_heal(pokemon, move, true)
        when *SELF_HEAL, *TIME_MOVES
          use_self_heal(pokemon, move, half_hp(pokemon))
        when :LIFEDEW
          use_party_restore(pokemon, move, false, false)
        when :LUNARBLESSING
          use_party_restore(pokemon, move, true, false)
        when :JUNGLEHEALING
          use_party_restore(pokemon, move, true, false)
        when :REVIVALBLESSING
          use_revival_blessing(pokemon, move)
        when :HEALINGWISH
          use_sacrificial_restore(pokemon, move, false)
        when :LUNARDANCE
          use_sacrificial_restore(pokemon, move, true)
        when :POLLENPUFF
          use_pollen_puff(pokemon, move)
        when :PRESENT
          use_present(pokemon, move)
        when :PURIFY
          use_purify(pokemon, move)
        when :DREAMEATER
          use_dream_eater(pokemon, move)
        when :AQUARING
          amount = big_root_amount(pokemon, [pokemon.totalhp / 16, 1].max)
          use_self_heal(pokemon, move, amount)
        when :REFRESH
          use_refresh(pokemon, move)
        when :REST
          use_rest(pokemon, move)
        when *PARTY_STATUS
          use_party_status(pokemon, move)
        else
          false
        end
      rescue StandardError => e
        KantoReloaded::Log.exception(
          "Healing move use failed for #{id}", e, channel: :modules
        ) if defined?(KantoReloaded::Log)
        false
      end

      def use_time_move(hook, pokemon, move_id)
        healing = can_use?(pokemon, move_id, false)
        native = native_time_available?
        return hook.call unless healing || native
        return use(pokemon, move_id) if healing && !native
        return hook.call if native && !healing

        move = move_object(pokemon, move_id)
        choice = KantoReloaded::PopupWindow.choice(
          _INTL("How should {1} use {2}?", pokemon.name, move.name),
          [
            { :label => _INTL("Heal"), :value => :heal },
            {
              :label => move_id == :MORNINGSUN ?
                _INTL("Wait Until Morning") : _INTL("Wait Until Night"),
              :value => :native
            },
            { :label => _INTL("Cancel"), :value => :cancel }
          ],
          :start_index => 0
        )
        return use(pokemon, move_id) if choice == :heal
        return hook.call if choice == :native
        false
      end

      private

      def register_setting
        KantoReloaded::Settings.register(SETTING_KEY, {
          :name => "Healing Overworld Moves",
          :description => "Allows healing moves to be used from the party menu outside battle.",
          :type => :toggle,
          :category => :quality_of_life,
          :owner => :healing_overworld,
          :value_style => :integer,
          :default => 1,
          :priority => 999
        })
      end

      def register_setting_callback
        KantoReloaded::Settings.register_on_change(
          SETTING_KEY,
          :healing_overworld_moves_cache,
          :owner => :healing_overworld
        ) do |value|
          KantoReloaded::HealingOverworld.cache_enabled(value)
        end
      end

      def register_overworld_menu
        return false unless defined?(OverworldMenu) && OverworldMenu.respond_to?(:register)
        OverworldMenu.register(OVERWORLD_KEY,
          :label => "Healing Overworld Moves",
          :priority => 24,
          :default_enabled => false,
          :status => proc {
            KantoReloaded::HealingOverworld.enabled? ? "On" : "Off"
          },
          :handler => proc { |screen|
            enabled = KantoReloaded::HealingOverworld.toggle
            state = enabled ? "enabled" : "disabled"
            screen.show_popup(
              "HEALING OVERWORLD MOVES",
              ["Healing Overworld Moves is now #{state}."]
            )
            nil
          }
        )
      end

      def register_hooks
        return false unless defined?(KantoReloaded::Hooks)
        return false unless defined?(HiddenMoveHandlers)

        results = []
        results << KantoReloaded::Hooks.wrap(
          HiddenMoveHandlers,
          :hasHandler,
          :healing_overworld_has_handler,
          :singleton => true
        ) do |hook, move_id, *_arguments|
          if KantoReloaded::HealingOverworld.enabled? &&
             KantoReloaded::HealingOverworld.handles?(move_id)
            true
          else
            hook.call
          end
        end

        results << KantoReloaded::Hooks.wrap(
          HiddenMoveHandlers,
          :triggerCanUseMove,
          :healing_overworld_can_use,
          :singleton => true
        ) do |hook, move_id, pokemon, show_message = true, *_arguments|
          module_api = KantoReloaded::HealingOverworld
          unless module_api.enabled? && module_api.handles?(move_id)
            next hook.call
          end
          id = module_api.send(:normalize_move_id, move_id)
          if KantoReloaded::HealingOverworld::TIME_MOVES.include?(id)
            next true if module_api.can_use?(pokemon, id, false)
            next hook.call
          end
          module_api.can_use?(pokemon, id, show_message)
        end

        results << KantoReloaded::Hooks.wrap(
          HiddenMoveHandlers,
          :triggerUseMove,
          :healing_overworld_use,
          :singleton => true
        ) do |hook, move_id, pokemon, *_arguments|
          module_api = KantoReloaded::HealingOverworld
          unless module_api.enabled? && module_api.handles?(move_id)
            next hook.call
          end
          id = module_api.send(:normalize_move_id, move_id)
          if KantoReloaded::HealingOverworld::TIME_MOVES.include?(id)
            next module_api.use_time_move(hook, pokemon, id)
          end
          module_api.use(pokemon, id)
        end

        results.all?
      end

      def normalize_move_id(value)
        value = value.id if !value.is_a?(Symbol) && value.respond_to?(:id)
        value.to_sym
      rescue StandardError
        nil
      end

      def party
        return [] unless defined?($Trainer) && $Trainer
        Array($Trainer.party)
      end

      def move_object(pokemon, move_id)
        return nil unless pokemon && pokemon.respond_to?(:moves)
        pokemon.moves.find do |move|
          move && normalize_move_id(move.id) == move_id
        end
      end

      def effect_available?(user, move_id)
        case move_id
        when *TARGETED_OTHER_HEAL
          party.any? { |target| valid_heal_target?(target) && target != user }
        when *TARGETED_HEAL
          party.any? { |target| valid_heal_target?(target) }
        when *SELF_HEAL, *TIME_MOVES, :AQUARING, :REST
          user.hp > 0 && user.hp < user.totalhp
        when :LIFEDEW
          party.any? { |target| valid_heal_target?(target) }
        when :LUNARBLESSING, :JUNGLEHEALING
          party.any? { |target| valid_restore_target?(target) }
        when :REVIVALBLESSING
          party.any? { |target| valid_revive_target?(target, user) }
        when :HEALINGWISH
          party.any? { |target| valid_sacrifice_target?(target, user, false) }
        when :LUNARDANCE
          party.any? { |target| valid_sacrifice_target?(target, user, true) }
        when :POLLENPUFF, :PRESENT
          party.any? { |target| valid_heal_target?(target) && target != user }
        when :PURIFY
          party.any? { |target| valid_status_target?(target) && target != user }
        when :DREAMEATER
          user.hp < user.totalhp && party.any? do |target|
            valid_dream_target?(target, user)
          end
        when :REFRESH
          statused?(user)
        when *PARTY_STATUS
          party.any? { |target| valid_status_target?(target) }
        else
          false
        end
      end

      def valid_living_target?(pokemon)
        pokemon && !pokemon.egg? && !pokemon.fainted?
      end

      def valid_heal_target?(pokemon)
        valid_living_target?(pokemon) && pokemon.hp < pokemon.totalhp
      end

      def valid_restore_target?(pokemon)
        valid_living_target?(pokemon) &&
          (pokemon.hp < pokemon.totalhp || statused?(pokemon))
      end

      def valid_status_target?(pokemon)
        valid_living_target?(pokemon) && statused?(pokemon)
      end

      def valid_revive_target?(pokemon, user)
        pokemon && pokemon != user && !pokemon.egg? && pokemon.fainted?
      end

      def valid_sacrifice_target?(pokemon, user, restore_pp)
        return false unless valid_living_target?(pokemon) && pokemon != user
        return true if pokemon.hp < pokemon.totalhp || statused?(pokemon)
        restore_pp && pokemon.moves.any? { |move| move && move.pp < move.total_pp }
      end

      def valid_dream_target?(pokemon, user)
        return false unless valid_living_target?(pokemon) && pokemon != user
        return false unless pokemon.status == :SLEEP
        pokemon.hp > dream_damage(pokemon)
      end

      def statused?(pokemon)
        pokemon && !pokemon.status.nil? && pokemon.status != :NONE
      end

      def unavailable_message(move_id)
        case move_id
        when :REFRESH, *PARTY_STATUS
          _INTL("No Pokemon has a status condition that can be cured.")
        when :REVIVALBLESSING
          _INTL("No Pokemon can be revived.")
        when :DREAMEATER
          _INTL("There is no safe sleeping target for Dream Eater.")
        else
          _INTL("There is no valid target for that move.")
        end
      end

      def reject(show_message, text)
        Kernel.pbMessage(text) if show_message
        false
      end

      def native_time_available?
        return false unless defined?($game_map) && $game_map
        return false unless defined?(GameData::MapMetadata)
        metadata = GameData::MapMetadata.try_get($game_map.map_id)
        metadata && metadata.outdoor_map
      rescue StandardError
        false
      end

      def half_hp(pokemon)
        [pokemon.totalhp / 2, 1].max
      end

      def quarter_hp(pokemon)
        [pokemon.totalhp / 4, 1].max
      end

      def big_root_amount(pokemon, amount)
        return amount unless pokemon.hasItem?(:BIGROOT)
        [(amount * 1.3).floor, 1].max
      end

      def consume_pp(move)
        return false unless move && move.pp > 0
        move.pp -= 1
        true
      end

      def display(scene, text)
        if scene
          scene.pbDisplay(text)
        else
          Kernel.pbMessage(text)
        end
      end

      def choose_target(user, help_text)
        selected = party.index(user) || 0
        original = selected
        scene = PokemonParty_Scene.new
        screen = PokemonPartyScreen.new(scene, party)
        screen.pbStartScene(help_text, 0)
        begin
          loop do
            scene.pbPreSelect(original)
            selected = scene.pbChoosePokemon(true, selected)
            return false if selected < 0
            result = yield(scene, original, selected, party[selected])
            if result == :success
              scene.pbSelect(original)
              scene.pbRefresh
              return true
            end
          end
        ensure
          screen.pbEndScene
        end
      end

      def use_targeted_heal(user, move, allow_self)
        choose_target(user, _INTL("Use on which Pokemon?")) do |scene, old_index, target_index, target|
          if target_index == old_index && !allow_self
            display(scene, _INTL("{1} can't use {2} on itself.", user.name, move.name))
            next nil
          end
          unless valid_heal_target?(target)
            display(scene, _INTL("{1} can't be used on that Pokemon.", move.name))
            next nil
          end
          amount = half_hp(target)
          amount = [(target.totalhp * 3) / 4, 1].max if
            move.id == :HEALPULSE && user.hasAbility?(:MEGALAUNCHER)
          next nil unless consume_pp(move)
          gain = pbItemRestoreHP(target, amount)
          display(scene, _INTL("{1}'s HP was restored by {2} points.", target.name, gain))
          :success
        end
      end

      def use_self_heal(user, move, amount)
        return false unless consume_pp(move)
        gain = pbItemRestoreHP(user, amount)
        Kernel.pbMessage(_INTL("{1}'s HP was restored by {2} points.", user.name, gain))
        true
      end

      def use_party_restore(_user, move, heal_status, restore_pp)
        targets = party.select do |target|
          restore_pp ? valid_sacrifice_target?(target, nil, true) :
            (heal_status ? valid_restore_target?(target) : valid_heal_target?(target))
        end
        return false if targets.empty? || !consume_pp(move)
        targets.each do |target|
          pbItemRestoreHP(target, quarter_hp(target)) if target.hp < target.totalhp
          target.heal_status if heal_status && statused?(target)
          if restore_pp
            target.moves.each { |known_move| known_move.pp = known_move.total_pp if known_move }
          end
        end
        Kernel.pbMessage(_INTL("Your party's Pokemon were restored!"))
        true
      end

      def use_revival_blessing(user, move)
        choose_target(user, _INTL("Revive which Pokemon?")) do |scene, _old_index, _target_index, target|
          unless valid_revive_target?(target, user)
            display(scene, _INTL("{1} can't be used on that Pokemon.", move.name))
            next nil
          end
          next nil unless consume_pp(move)
          target.hp = [target.totalhp / 2, 1].max
          target.heal_status
          display(scene, _INTL("{1} was revived.", target.name))
          :success
        end
      end

      def use_sacrificial_restore(user, move, restore_pp)
        choose_target(user, _INTL("Restore which Pokemon?")) do |scene, _old_index, _target_index, target|
          unless valid_sacrifice_target?(target, user, restore_pp)
            display(scene, _INTL("{1} can't be used on that Pokemon.", move.name))
            next nil
          end
          next nil unless consume_pp(move)
          if restore_pp
            target.heal
          else
            target.hp = target.totalhp
            target.heal_status
          end
          user.hp = 0
          display(scene, _INTL("{1} was fully restored, and {2} fainted.", target.name, user.name))
          :success
        end
      end

      def use_pollen_puff(user, move)
        choose_target(user, _INTL("Use on which Pokemon?")) do |scene, _old_index, _target_index, target|
          if target == user || !valid_heal_target?(target)
            display(scene, _INTL("{1} can't be used on that Pokemon.", move.name))
            next nil
          end
          if target.hasAbility?(:BULLETPROOF)
            display(scene, _INTL("{1} is protected by Bulletproof.", target.name))
            next nil
          end
          next nil unless consume_pp(move)
          gain = pbItemRestoreHP(target, half_hp(target))
          display(scene, _INTL("{1}'s HP was restored by {2} points.", target.name, gain))
          :success
        end
      end

      def use_present(user, move)
        choose_target(user, _INTL("Use on which Pokemon?")) do |scene, _old_index, _target_index, target|
          if target == user || !valid_heal_target?(target)
            display(scene, _INTL("{1} can't be used on that Pokemon.", move.name))
            next nil
          end
          if target.hasAbility?(:TELEPATHY)
            display(scene, _INTL("{1} is protected by Telepathy.", target.name))
            next nil
          end
          next nil unless consume_pp(move)
          amount = rand(100) < 20 ? target.totalhp : quarter_hp(target)
          gain = pbItemRestoreHP(target, amount)
          display(scene, _INTL("{1}'s HP was restored by {2} points.", target.name, gain))
          :success
        end
      end

      def use_purify(user, move)
        choose_target(user, _INTL("Purify which Pokemon?")) do |scene, _old_index, _target_index, target|
          if target == user || !valid_status_target?(target)
            display(scene, _INTL("{1} can't be used on that Pokemon.", move.name))
            next nil
          end
          next nil unless consume_pp(move)
          target.heal_status
          gain = pbItemRestoreHP(user, half_hp(user))
          display(scene, _INTL("{1}'s status was cured, and {2} recovered {3} HP.",
                               target.name, user.name, gain))
          :success
        end
      end

      def dream_damage(target)
        [target.totalhp / 4, 1].max
      end

      def use_dream_eater(user, move)
        choose_target(user, _INTL("Use on which sleeping Pokemon?")) do |scene, _old_index, _target_index, target|
          unless valid_dream_target?(target, user)
            display(scene, _INTL("Dream Eater needs a safe sleeping target."))
            next nil
          end
          next nil unless consume_pp(move)
          target.hp -= dream_damage(target)
          amount = big_root_amount(user, half_hp(user))
          gain = pbItemRestoreHP(user, amount)
          display(scene, _INTL("{1} recovered {2} HP, and {3} lost HP.",
                               user.name, gain, target.name))
          :success
        end
      end

      def use_refresh(user, move)
        return false unless consume_pp(move)
        user.heal_status
        Kernel.pbMessage(_INTL("{1}'s status condition was cured.", user.name))
        true
      end

      def use_rest(user, move)
        return false unless consume_pp(move)
        pbItemRestoreHP(user, user.totalhp)
        user.status = :SLEEP
        user.statusCount = 2 if user.respond_to?(:statusCount=)
        Kernel.pbMessage(_INTL("{1} restored its HP and fell asleep.", user.name))
        true
      end

      def use_party_status(_user, move)
        targets = party.select { |target| valid_status_target?(target) }
        return false if targets.empty? || !consume_pp(move)
        targets.each { |target| target.heal_status }
        Kernel.pbMessage(_INTL("Your party's status conditions were cured."))
        true
      end
    end
  end
end

KantoReloaded::HealingOverworld.install
