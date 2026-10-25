#==============================================================================
# Kanto Reloaded: Quality of Life: the toggles' hooks
#==============================================================================
# Where each toggle meets the game (PIF 6.8.2 and KIF Beta, checked
# 2026-10-21). Every hook belongs to the Quality of Life feature: with it
# Off, or a toggle Off, the game's own code runs as it was.
#
#   Infinite Repel      isRepelActive (read before each step's encounter)
#   Auto-Repel Reuse    pbRepel remembers the kind; when the step countdown
#                       sets $PokemonGlobal.repel to 0, one more of that kind
#                       from the Bag is used instead (so the game's "wore
#                       off" question never comes), with a toast. None of
#                       that kind left: the game asks as usual.
#   Infinite Money      Player#money shows the most there can be and spending
#                       never lowers it; money gained still goes into the
#                       real money behind it (and "You got $X" still shows:
#                       pbGainMoney sees the real money). Shops: any item, in
#                       any amount (PokemonMartAdapter#getMoney/setMoney).
#   Rematch Money       pbGainMoney with the rematch switch off, and the
#                       money a rematchable (Hoenn-style) battle's rules turn
#                       off allowed again
#   Infinite Safari     SafariState#steps= never lowers steps in a game
#   Infinite PP         PokeBattle_Battler#pbReducePP spends nothing for the
#                       player's Pokémon; their PP is full at each battle's start
#   Upgraded PP         Pokemon::Move#total_pp as if it had 3 PP Ups;
#                       Pokemon::Move#pp never above it (Off puts them back)
#   Always Obey         pbObedienceCheck? (not a Pokémon the story makes
#                       disobey: force_disobey)
#   Instant Hatch       each step, a party Egg's steps drop to its last one
#   Day Care Eggs       each step, an Egg is ready once the two get along
#   Encounter Rate      PokemonEncounters#encounter_triggered?: the step
#                       chance halved or doubled for that call
#   Max Friendship      Pokemon#happiness reads 255 for the player's Pokémon
#   Guaranteed Catch    pbCaptureCalc returns 4 shakes (caught)
#   Auto-Hook Fishing   PIF's own auto-hook (its switch) while pbFishing runs
#   Move Learning       PokeBattle_Battle#pbLearnMove; the overworld
#                       pbLearnMove while a Pokémon levels up or evolves
#                       (pbChangeLevel, the evolution scenes, Super Candy)
#   Faster Evolutions   both evolution scenes run three game frames per
#                       drawn frame (Graphics.update); B still stops them
#==============================================================================

module Reloaded
  module QualityOfLife
    module Hooks
      REPEL_STEPS = { :REPEL => 100, :SUPERREPEL => 200, :MAXREPEL => 250, :FUSIONREPEL => 50 }.freeze
      QOL = Reloaded::QualityOfLife

      @level_up = 0
      @fast_evolution = false
      @real_money = false

      class << self
        attr_accessor :fast_evolution

        # Runs the block as a level-up (Level-Up Moves applies to
        # the moves learned in it)
        def level_up
          @level_up += 1
          return yield
        ensure
          @level_up -= 1
        end

        def level_up?
          return @level_up > 0
        end

        # Runs the block with the real money showing (prize messages)
        def real_money
          was = @real_money
          @real_money = true
          return yield
        ensure
          @real_money = was
        end

        def real_money?
          return @real_money
        end

        def player_owned?(pkmn)
          return false unless pkmn && $Trainer
          return pkmn.kif_player_owned? if pkmn.respond_to?(:kif_player_owned?)
          return pkmn.owner && pkmn.owner.id == $Trainer.id
        rescue StandardError
          return false
        end

        def max_money
          return defined?(::Settings::MAX_MONEY) ? ::Settings::MAX_MONEY : 999_999
        end

        def install
          install_repel
          install_money
          install_battle
          install_pokemon
          install_steps
          install_safari
          install_fishing
          install_move_learning
          install_evolution
          return true
        end

        private

        def h
          return Reloaded::Hooks
        end

        # A hook, made only when its target is there: the game has every
        # one; tests and the preview tool have few (a top-level method is
        # looked for too, as Object always is)
        def around(target, method, id, &blk)
          return false unless Reloaded::QualityOfLife.present?(target, method)
          return Reloaded::Hooks.around(Reloaded::QualityOfLife::FEATURE, target, method, :id => id, &blk)
        end

        def f
          return QOL::FEATURE
        end

        #----------------------------------------------------------------------
        # Repels
        #----------------------------------------------------------------------
        def install_repel
          around(Object, :isRepelActive, :qol_infinite_repel) do |original, *args|
            QOL.on?(:infinite_repel) && !($game_switches[::SWITCH_USED_AN_INCENSE] rescue false) ? true : original.call(*args)
          end
          around(Object, :pbRepel, :qol_repel_kind) do |original, item, steps, *rest|
            ret = original.call(item, steps, *rest)
            data = Reloaded::SaveStore.section(QOL::SECTION)
            data["repel"] = item.to_s if data && ret == 3
            ret
          end
          around("PokemonGlobalMetadata", :repel=, :qol_auto_repel) do |original, value|
            me = original.receiver
            if value.to_i <= 0 && me.repel.to_i > 0 && !me.tempRepel && QOL.on?(:auto_repel) &&
               (steps = Reloaded::QualityOfLife::Hooks.reuse_repel)
              value = steps
            end
            original.call(value)
          end
        end

        public

        # One more of the last kind used, from the Bag: its steps, or nil
        def reuse_repel
          data = Reloaded::SaveStore.section(QOL::SECTION)
          kind = data && data["repel"] ? data["repel"].to_sym : nil
          return nil unless kind && REPEL_STEPS[kind] && $PokemonBag && $PokemonBag.pbHasItem?(kind)
          $PokemonBag.pbDeleteItem(kind)
          left = $PokemonBag.pbQuantity(kind)
          name = (GameData::Item.get(kind).name rescue kind.to_s)
          Reloaded::QualityOfLife::Toast.show(kind, _INTL("Used Another {1}", name), _INTL("{1} LEFT", left))
          Reloaded::Log.info("Auto-Repel Reuse: another #{name} used (#{left} left).", :quality_of_life)
          return REPEL_STEPS[kind]
        rescue StandardError => e
          Reloaded::Log.exception("Auto-Repel Reuse couldn't use another Repel", e, :quality_of_life)
          return nil
        end

        private

        #----------------------------------------------------------------------
        # Money
        #----------------------------------------------------------------------
        def install_money
          around("Player", :money, :qol_money_shown) do |original|
            QOL.on?(:infinite_money) && !Reloaded::QualityOfLife::Hooks.real_money? ? Reloaded::QualityOfLife::Hooks.max_money : original.call
          end
          around("Player", :money=, :qol_money_kept) do |original, value|
            if QOL.on?(:infinite_money) && !Reloaded::QualityOfLife::Hooks.real_money? && value.is_a?(Integer)
              me = original.receiver
              gain = value - Reloaded::QualityOfLife::Hooks.max_money
              real = me.instance_variable_get(:@money).to_i
              original.call(gain > 0 ? real + gain : real)      # spending changes nothing
            else
              original.call(value)
            end
          end
          # shops: anything, in any amount
          big = 999_999_999
          around("PokemonMartAdapter", :getMoney, :qol_money_shop_get) do |original|
            QOL.on?(:infinite_money) ? big : original.call
          end
          around("PokemonMartAdapter", :setMoney, :qol_money_shop_set) do |original, value|
            if QOL.on?(:infinite_money) && value.is_a?(Integer)
              gain = value - big                              # selling adds, buying costs nothing
              Reloaded::QualityOfLife::Hooks.real_money { $Trainer.money += gain } if gain > 0 && $Trainer
              nil
            else
              original.call(value)
            end
          end
          around("PokeBattle_Battle", :pbGainMoney, :qol_money_prizes) do |original, *args|
            me = original.receiver
            rematch = defined?(::SWITCH_IS_REMATCH) && $game_switches && $game_switches[::SWITCH_IS_REMATCH]
            pay = QOL.on?(:rematch_money)
            was_gain = me.moneyGain
            begin
              $game_switches[::SWITCH_IS_REMATCH] = false if pay && rematch
              me.moneyGain = true if pay && Reloaded::QualityOfLife::Hooks.rematch_battle?
              Reloaded::QualityOfLife::Hooks.real_money { original.call(*args) }
            ensure
              $game_switches[::SWITCH_IS_REMATCH] = true if pay && rematch
              me.moneyGain = was_gain
            end
          end
          around(Object, :rematchable_trainer_battle, :qol_money_rematchable) do |original, *args|
            Reloaded::QualityOfLife::Hooks.rematch_battle = true
            begin
              original.call(*args)
            ensure
              Reloaded::QualityOfLife::Hooks.rematch_battle = false
            end
          end
        end

        public

        attr_writer :rematch_battle

        def rematch_battle?
          return @rematch_battle ? true : false
        end

        private

        #----------------------------------------------------------------------
        # Battles: PP, obedience, catching
        #----------------------------------------------------------------------
        def install_battle
          around("PokeBattle_Battler", :pbReducePP, :qol_infinite_pp) do |original, move, *rest|
            me = original.receiver
            if QOL.on?(:infinite_pp) && (me.battle.pbOwnedByPlayer?(me.index) rescue false)
              true
            else
              original.call(move, *rest)
            end
          end
          if defined?(::Events) && ::Events.respond_to?(:onStartBattle)
            ::Events.onStartBattle += proc do |_sender, _e|
              Reloaded::QualityOfLife::Hooks.refill_pp if QOL.on?(:infinite_pp)
            end
          end
          around("Pokemon::Move", :total_pp, :qol_upgraded_pp) do |original|
            if QOL.on?(:upgraded_pp)
              base = (GameData::Move.get(original.receiver.id).total_pp rescue nil)
              base ? base + base * 3 / 5 : original.call
            else
              original.call
            end
          end
          around("Pokemon::Move", :pp, :qol_pp_within_max) do |original|
            v = original.call
            t = original.receiver.total_pp
            v.is_a?(Integer) && t.is_a?(Integer) && t > 0 && v > t ? t : v
          end
          around("PokeBattle_Battler", :pbObedienceCheck?, :qol_always_obey) do |original, choice, *rest|
            me = original.receiver
            if QOL.on?(:always_obey) && !(me.pokemon.force_disobey rescue false) && (me.battle.pbOwnedByPlayer?(me.index) rescue false)
              true
            else
              original.call(choice, *rest)
            end
          end
          around("PokeBattle_Battle", :pbCaptureCalc, :qol_guaranteed_catch) do |original, *args|
            QOL.on?(:guaranteed_catch) ? 4 : original.call(*args)
          end
        end

        public

        def refill_pp
          Reloaded::QualityOfLifeScreens.party.each do |pkmn|
            next if pkmn.egg?
            pkmn.moves.each { |m| m.pp = m.total_pp if m }
          end
        rescue StandardError => e
          Reloaded::Log.exception("Infinite PP couldn't refill the party's PP", e, :quality_of_life)
        end

        private

        #----------------------------------------------------------------------
        # Pokémon: friendship, encounters
        #----------------------------------------------------------------------
        def install_pokemon
          around("Pokemon", :happiness, :qol_max_friendship) do |original|
            QOL.on?(:max_friendship) && Reloaded::QualityOfLife::Hooks.player_owned?(original.receiver) ? 255 : original.call
          end
          around("PokemonEncounters", :encounter_triggered?, :qol_encounter_rate) do |original, enc_type, repel_active = false, by_step = true|
            rate = QOL.value(:encounter_rate)
            me = original.receiver
            chances = me.instance_variable_get(:@step_chances)
            if by_step && rate && rate != 1 && chances.is_a?(Hash) && chances[enc_type].to_i > 0
              was = chances[enc_type]
              chances[enc_type] = rate == 0 ? [was / 2, 1].max : [was * 2, 100].min
              begin
                original.call(enc_type, repel_active, by_step)
              ensure
                chances[enc_type] = was
              end
            else
              original.call(enc_type, repel_active, by_step)
            end
          end
        end

        #----------------------------------------------------------------------
        # Steps: Eggs and the Day Care
        #----------------------------------------------------------------------
        def install_steps
          return unless defined?(::Events) && ::Events.respond_to?(:onStepTaken)
          ::Events.onStepTaken += proc do |_sender, _e|
            Reloaded::QualityOfLife::Hooks.each_step
          end
        end

        public

        def each_step
          return unless Reloaded::Features.on?(QOL::FEATURE) && $Trainer
          if QOL.on?(:instant_hatch)
            $Trainer.party.each { |egg| egg.steps_to_hatch = 1 if egg && egg.egg? && egg.steps_to_hatch > 1 }
          end
          if QOL.on?(:daycare_eggs) && respond_to?(:pbDayCareDeposited, true) && $PokemonGlobal &&
             pbDayCareDeposited == 2 && $PokemonGlobal.daycareEgg == 0 && pbDayCareGetCompat > 0
            $PokemonGlobal.daycareEgg = 1
            Reloaded::Log.info("Day Care Eggs: an Egg is ready at the Day Care.", :quality_of_life)
          end
        rescue StandardError => e
          Reloaded::Log.exception("A Quality of Life step check failed", e, :quality_of_life)
        end

        private

        #----------------------------------------------------------------------
        # The Safari Zone: no step taken off while a game is on
        #----------------------------------------------------------------------
        def install_safari
          around("SafariState", :steps=, :qol_infinite_safari) do |original, value|
            me = original.receiver
            if QOL.on?(:infinite_safari) && me.inProgress? && (me.decision rescue 0).to_i == 0 && value.to_i < me.steps.to_i
              me.steps
            else
              original.call(value)
            end
          end
        end

        #----------------------------------------------------------------------
        # Fishing
        #----------------------------------------------------------------------
        def install_fishing
          around(Object, :pbFishing, :qol_auto_hook) do |original, *args|
            if QOL.on?(:auto_hook) && defined?(::SWITCH_FISHING_AUTOHOOK) && $game_switches
              was = $game_switches[::SWITCH_FISHING_AUTOHOOK]
              $game_switches[::SWITCH_FISHING_AUTOHOOK] = true
              begin
                original.call(*args)
              ensure
                $game_switches[::SWITCH_FISHING_AUTOHOOK] = was
              end
            else
              original.call(*args)
            end
          end
        end

        #----------------------------------------------------------------------
        # Level-Up Moves: Native (0), Ask (1), Skip (2)
        #----------------------------------------------------------------------
        def install_move_learning
          around("PokeBattle_Battle", :pbLearnMove, :qol_move_learning_battle) do |original, idx, move, *rest|
            me = original.receiver
            mode = QOL.value(:move_learning).to_i
            pkmn = (me.pbParty(0)[idx] rescue nil)
            name = (GameData::Move.get(move).name rescue move.to_s)
            if mode == 0 || pkmn.nil? || pkmn.moves.any? { |m| m && m.id == move }
              original.call(idx, move, *rest)
            elsif mode == 2
              me.pbDisplay(_INTL("{1} skipped learning {2}.", pkmn.name, name))
            elsif pkmn.moves.length < ::Pokemon::MAX_MOVES && !me.pbDisplayConfirm(_INTL("Should {1} learn {2}?", pkmn.name, name))
              me.pbDisplay(_INTL("{1} did not learn {2}.", pkmn.name, name))
            else
              original.call(idx, move, *rest)
            end
          end
          around(Object, :pbLearnMove, :qol_move_learning) do |original, pkmn, move, *rest, &blk|
            mode = Reloaded::QualityOfLife::Hooks.level_up? ? QOL.value(:move_learning).to_i : 0
            name = (GameData::Move.get(move).name rescue move.to_s)
            if mode == 0 || pkmn.nil? || (pkmn.egg? rescue true) || (pkmn.hasMove?(move) rescue false)
              original.call(pkmn, move, *rest, &blk)
            elsif mode == 2
              pbMessage(_INTL("{1} skipped learning {2}.", pkmn.name, name), &blk)
              false
            elsif pkmn.numMoves < ::Pokemon::MAX_MOVES && !pbConfirmMessage(_INTL("Should {1} learn {2}?", pkmn.name, name), &blk)
              pbMessage(_INTL("{1} did not learn {2}.", pkmn.name, name), &blk)
              false
            else
              original.call(pkmn, move, *rest, &blk)
            end
          end
          around(Object, :pbChangeLevel, :qol_move_learning_level) do |original, *args|
            Reloaded::QualityOfLife::Hooks.level_up { original.call(*args) }
          end
          around("PokemonEvolutionScene", :pbEvolutionSuccess, :qol_move_learning_evolved) do |original, *args|
            Reloaded::QualityOfLife::Hooks.level_up { original.call(*args) }
          end
          if defined?(::PokemonEvolutionSceneEBDX)
            around("PokemonEvolutionSceneEBDX", :createEvolved, :qol_move_learning_evolved_ebdx) do |original, *args|
              Reloaded::QualityOfLife::Hooks.level_up { original.call(*args) }
            end
          end
        end

        #----------------------------------------------------------------------
        # Faster Evolutions
        #----------------------------------------------------------------------
        def install_evolution
          ["PokemonEvolutionScene", "PokemonEvolutionSceneEBDX"].each do |scene|
            next unless Object.const_defined?(scene)
            around(scene, :pbEvolution, :"qol_faster_#{scene}") do |original, *args|
              if QOL.on?(:faster_evolutions)
                Reloaded::QualityOfLife::Hooks.fast_evolution = true
                begin
                  original.call(*args)
                ensure
                  Reloaded::QualityOfLife::Hooks.fast_evolution = false
                end
              else
                original.call(*args)
              end
            end
          end
          h.prepend(f, ::Graphics.singleton_class, FastFrames, :id => :qol_faster_evolution_frames) if defined?(::Graphics)
        end
      end

      # While an evolution scene runs with Faster Evolutions On, only every
      # third game frame is drawn: the scene plays three times as fast
      module FastFrames
        def update(*args)
          if Reloaded::QualityOfLife::Hooks.fast_evolution && Reloaded::Features.on?(Reloaded::QualityOfLife::FEATURE)
            @kr_fast_frame = (@kr_fast_frame.to_i + 1) % 3
            return nil unless @kr_fast_frame == 0
          end
          super
        end
      end
    end
  end
end
