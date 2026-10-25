# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Egg Manager's incubators
#==============================================================================
# His picks (2026-10-25): one incubator at the start, a second at 4 Badges,
# a third at 8, and room for three more a mod can give (add_incubators).
# An Egg in one counts down in the PC as fast as in the party (1 a step, 1
# more with the Breeder outfit, 1 more with Flame Body or Magma Armor in the
# party, the game's own rules) and stops at its last step: Ready. It hatches
# where it is (hatch: the game's own pbHatch, the scene and the nickname),
# and with Instant Hatch On it's Ready at once.
#
# Walking costs almost nothing: the incubated Eggs are kept (@slots, found
# once by a pass over the boxes when a save loads); a step with none in use
# is one check; with some, one subtraction each. The passes over the boxes
# (rebuild!) run when a save loads, the PC closes, the Egg Manager opens
# and the game saves, never on a step: they catch Eggs released, moved to
# the Transfer Box (its number cleared: that box is shared by every save)
# or taken into the party.
#
# Auto-Incubate: an Egg the Day Care sends to the PC (the party is full)
# goes to the Egg Box and into a free incubator, with a toast.
#==============================================================================

module Reloaded
  module EggManager
    module Incubators
      IVAR = :@kr_incubator
      BADGES = [0, 4, 8].freeze     # each incubator's Badges
      MAX = 6                       # places the row has (three for later)

      @slots = {}                   # number => the Egg in it
      @ready = 0                    # boxed Eggs Ready at the last pass (the menus' glow)

      class << self
        attr_reader :slots
        attr_reader :last_stored    # the Egg the Day Care last sent to the PC

        def badges
          return $Trainer ? $Trainer.badge_count.to_i : 0
        rescue StandardError
          return 0
        end

        # How many there are now
        def count
          n = BADGES.count { |b| badges >= b } + EggManager.extra_incubators
          return [[n, 1].max, MAX].min
        end

        # The Badges the next one needs, or nil
        def next_badges
          return BADGES.find { |b| badges < b }
        end

        def number(pkmn)
          return nil unless pkmn
          n = pkmn.instance_variable_get(IVAR)
          return n.is_a?(Integer) && n > 0 ? n : nil
        end

        # The first incubator not in use, or nil
        def free
          return (1..count).find { |n| !@slots.key?(n) }
        end

        def used
          return @slots.length
        end

        # An Egg in a box into an incubator (the first free, or n): its
        # number, or nil
        def incubate(pkmn, n = nil)
          return nil unless Eggs.egg?(pkmn) && !number(pkmn)
          entry = Eggs.locate(pkmn)
          return nil unless entry && !entry.party?
          n ||= free
          return nil unless n && n <= count && !@slots.key?(n)
          pkmn.instance_variable_set(IVAR, n)
          @slots[n] = pkmn
          ready_check(pkmn)
          return n
        rescue StandardError => e
          Reloaded::Log.exception("An Egg couldn't go into an incubator", e, :egg_manager)
          return nil
        end

        # Out of its incubator (the number taken off the Egg)
        def release(pkmn)
          return false unless pkmn
          n = number(pkmn)
          pkmn.remove_instance_variable(IVAR) if pkmn.instance_variable_defined?(IVAR)
          @slots.delete(n) if n && @slots[n].equal?(pkmn)
          @slots.delete_if { |_k, p| p.equal?(pkmn) }
          return n ? true : false
        end

        # The pass over the boxes: the incubated Eggs found again, numbers on
        # anything that left the PC (the party, the Transfer Box, released,
        # hatched) or past the incubators there are now taken off
        def rebuild!
          @slots = {}
          @ready = 0
          return unless $PokemonStorage
          st = $PokemonStorage
          seen = {}
          (0...st.maxBoxes).each do |i|
            b = (st[i] rescue nil)
            next unless b
            transfer = Eggs.transfer?(b)
            (0...st.maxPokemon(i)).each do |k|
              p = st[i, k]
              next unless p
              n = number(p)
              @ready += 1 if !transfer && Eggs.egg?(p) && p.steps_to_hatch.to_i <= 1
              next unless n
              if transfer || !Eggs.egg?(p) || n > count || seen[n]
                p.remove_instance_variable(IVAR)
                next
              end
              seen[n] = true
              @slots[n] = p
            end
          end
          Eggs.party.each { |p| p.remove_instance_variable(IVAR) if number(p) }
        rescue StandardError => e
          Reloaded::Log.exception("The incubators couldn't be checked", e, :egg_manager)
        end
        alias check! rebuild!

        # Boxed Eggs Ready at the last pass, or since (the menus' glow)
        def ready_count
          return @ready
        end

        # What a step takes off: the game's own rules for party Eggs
        def rate
          r = 1
          r += 1 if breeder?
          r += 1 if Hatching.helper_in_party?
          return r
        end

        def breeder?
          return false unless respond_to?(:isWearingClothes, true) && defined?(::CLOTHES_BREEDER)
          return isWearingClothes(::CLOTHES_BREEDER) ? true : false
        rescue StandardError
          return false
        end

        # Every step: each incubated Egg goes down by the rate, never below
        # its last step; one in the party now is the game's to count
        def step
          return if @slots.empty?
          instant = defined?(Reloaded::QualityOfLife) && Reloaded::QualityOfLife.on?(:instant_hatch)
          by = rate
          party = Eggs.party
          @slots.dup.each do |n, egg|
            if !Eggs.egg?(egg) || party.any? { |p| p.equal?(egg) }
              release(egg)
              next
            end
            was = egg.steps_to_hatch.to_i
            next if was <= 1
            egg.steps_to_hatch = instant ? 1 : [was - by, 1].max
            ready_check(egg) if egg.steps_to_hatch <= 1
          end
        rescue StandardError => e
          Reloaded::Log.exception("The incubators' step failed", e, :egg_manager)
        end

        # Hatches a Ready Egg where it is (the game's own pbHatch: the scene,
        # the Pokédex, the nickname); true when it hatched
        def hatch(pkmn)
          return false unless Eggs.egg?(pkmn) && pkmn.steps_to_hatch.to_i <= 1
          entry = Eggs.locate(pkmn)
          return false unless entry && !entry.party?
          release(pkmn)
          pkmn.steps_to_hatch = 0
          pbHatch(pkmn)
          @ready = [@ready - 1, 0].max
          Reloaded::Events.emit(:egg_hatched, :pokemon => pkmn, :box => entry.box, :slot => entry.slot)
          return true
        rescue StandardError => e
          Reloaded::Log.exception("An Egg couldn't hatch in the PC", e, :egg_manager)
          return false
        end

        # Every Ready Egg in the boxes, one after another: how many hatched
        def hatch_all
          ready = Eggs.all.reject(&:party?).select { |e| e.pkmn.steps_to_hatch.to_i <= 1 }
          return ready.count { |e| hatch(e.pkmn) }
        end

        def install
          h = Reloaded::Hooks
          if defined?(::Events) && ::Events.respond_to?(:onStepTaken)
            ::Events.onStepTaken += proc { |_sender, _e| Reloaded::EggManager::Incubators.each_step }
          end
          # the PC closing: the pass over the boxes
          if defined?(::PokemonStorageScreen) && ::PokemonStorageScreen.method_defined?(:pbStartScreen)
            h.around(FEATURE, ::PokemonStorageScreen, :pbStartScreen, :id => :egg_manager_pc_closed) do |original, *args|
              begin
                original.call(*args)
              ensure
                Reloaded::EggManager::Incubators.check!
              end
            end
          end
          # Auto-Incubate: an Egg the Day Care makes while the party is full
          # goes to the PC through pbStoreCaught (007_Overworld_DayCare.rb:434)
          if Object.private_method_defined?(:pbDayCareGenerateEgg) || Object.method_defined?(:pbDayCareGenerateEgg)
            h.around(FEATURE, Object, :pbDayCareGenerateEgg, :id => :egg_manager_generate) do |original, *args|
              Reloaded::EggManager::Incubators.generating { original.call(*args) }
            end
          end
          if defined?(::PokemonStorage) && ::PokemonStorage.method_defined?(:pbStoreCaught)
            h.around(FEATURE, ::PokemonStorage, :pbStoreCaught, :id => :egg_manager_store) do |original, pkmn, *args|
              ret = original.call(pkmn, *args)
              Reloaded::EggManager::Incubators.stored(pkmn, ret)
              ret
            end
          end
          return true
        end

        # The step handler (Events.onStepTaken): incubators, then the alerts
        def each_step
          return unless EggManager.on? && $Trainer
          step
          Alerts.step
        end

        # While the Day Care makes an Egg: the one it stores in the PC is
        # noted, then sent to the Egg Box and an incubator
        def generating
          @generated = nil
          @last_stored = nil
          @in_generate = true
          ret = yield
          @in_generate = false
          egg = @generated
          @generated = nil
          @last_stored = egg
          after_generate(egg) if egg
          return ret
        ensure
          @in_generate = false
        end

        def stored(pkmn, box)
          @generated = pkmn if @in_generate && Eggs.egg?(pkmn) && box.to_i >= 0
        end

        # Where the game stored it: to the Egg Box if it isn't there (and
        # has room), then into a free incubator with Auto-Incubate On
        def after_generate(egg)
          entry = Eggs.locate(egg)
          return unless entry && !entry.party?
          want = EggManager.egg_box
          if want && entry.box != want && (k = Eggs.free_slot(want))
            $PokemonStorage[entry.box, entry.slot] = nil
            $PokemonStorage[want, k] = egg
            entry = Eggs.locate(egg)
          end
          return unless EggManager.auto_incubate? && (n = incubate(egg))
          Alerts.incubated(n, entry.box)
        rescue StandardError => e
          Reloaded::Log.exception("Auto-Incubate couldn't place the Egg", e, :egg_manager)
        end

        private

        def ready_check(egg)
          return unless egg.steps_to_hatch.to_i <= 1
          @ready += 1
          Alerts.ready(egg)
        end
      end
    end
  end
end
