# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Egg Manager's Day Care
#==============================================================================
# The Day Care from anywhere, once you've left a Pokémon there in person
# (his pick, Q5: After Your First Visit; a save that already has one there
# counts). Everything goes through the game's own functions, so KIF's
# Level Caps (on withdraw) and its and cody's breeding rules (on
# compatibility) still apply:
#
#   deposit   from the party (pbDayCareDeposit) or a box (the same steps);
#             a Pokémon that can battle always stays in the party
#   withdraw  to the party or a box (pbDayCareWithdraw), for the game's cost
#             (pbDayCareGetCost); refused when you can't pay or there's no
#             room anywhere (PIF would lose it)
#   collect   pbDayCareGenerateEgg, then the waiting Egg cleared; refused
#             when the party and the PC are full (PIF would lose it)
#   discard   the waiting Egg cleared
#
# Egg Chance (his pick, Q13): the game's odds for the two there, 20 / 50 /
# 70% every 256 steps (40 / 80 / 88% with the Oval Charm).
#
# The Partner Finder (his pick: In the Day Care Tab): with one Pokémon
# there, every Pokémon in the party and the boxes that can breed with it,
# best first. The game decides each pair: the two are put in the Day Care's
# slots for a moment and pbDayCareGetCompat asked (every wrapper on it
# runs), then the slots are put back.
#==============================================================================

module Reloaded
  module EggManager
    module DayCare
      CHANCES = [0, 20, 50, 70].freeze
      OVAL_CHANCES = [0, 40, 80, 88].freeze

      class << self
        def global
          return $PokemonGlobal && $PokemonGlobal.respond_to?(:daycare) ? $PokemonGlobal : nil
        end

        # [[Pokémon, level when left, slot]]
        def slots
          g = global
          return [] unless g
          return Array(g.daycare).each_with_index.map { |(p, lv), i| [p, lv.to_i, i] }.select { |p, _lv, _i| p }
        rescue StandardError
          return []
        end

        def count
          return slots.length
        end

        def full?
          return count >= 2
        end

        def egg_waiting?
          return respond_to?(:pbEggGenerated?, true) && pbEggGenerated? ? true : false
        rescue StandardError
          return false
        end

        # Open from the Egg Manager: you've left a Pokémon there in person
        # (or the save already has one there)
        def visited?
          d = EggManager.data
          return true if d && d["visited"]
          return false unless count > 0
          d["visited"] = true if d
          return true
        end

        def visit!
          d = EggManager.data
          d["visited"] = true if d
        end

        # How well the two there get along, 0 to 3, as the game works it out
        def compat
          return 0 unless count == 2 && respond_to?(:pbDayCareGetCompat, true)
          return pbDayCareGetCompat.to_i.clamp(0, 3)
        rescue StandardError
          return 0
        end

        # How two Pokémon would get along there: the two put in the Day
        # Care's slots for a moment, the game asked, the slots put back
        def compat_for(a, b)
          g = global
          return 0 unless g && a && b && respond_to?(:pbDayCareGetCompat, true)
          kept = [g.daycare[0].dup, g.daycare[1].dup]
          begin
            g.daycare[0][0] = a
            g.daycare[0][1] = a.level
            g.daycare[1][0] = b
            g.daycare[1][1] = b.level
            return pbDayCareGetCompat.to_i.clamp(0, 3)
          ensure
            g.daycare[0][0], g.daycare[0][1] = kept[0][0], kept[0][1]
            g.daycare[1][0], g.daycare[1][1] = kept[1][0], kept[1][1]
          end
        rescue StandardError
          return 0
        end

        def oval_charm?
          return defined?(::GameData::Item) && ::GameData::Item.exists?(:OVALCHARM) && $PokemonBag &&
                 $PokemonBag.pbHasItem?(:OVALCHARM) ? true : false
        rescue StandardError
          return false
        end

        # The Egg Chance every 256 steps, in percent
        def chance(c = compat)
          return (oval_charm? ? OVAL_CHANCES : CHANCES)[c.to_i.clamp(0, 3)]
        end

        def cost(slot)
          return pbDayCareGetCost(slot).to_i if respond_to?(:pbDayCareGetCost, true)
          p, lv = global.daycare[slot]
          return p ? (p.level - lv.to_i + 1) * 100 : 0
        rescue StandardError
          return 0
        end

        def money
          return $Trainer ? $Trainer.money.to_i : 0
        end

        #----------------------------------------------------------------------
        # The Partner Finder
        #----------------------------------------------------------------------
        # Every Pokémon (party, then box by box) that can breed with anchor:
        # [[Entry, compatibility]], best first
        def partners(anchor)
          return [] unless anchor
          out = []
          each_pokemon do |entry|
            p = entry.pkmn
            next if p.equal?(anchor) || p.egg?
            c = compat_for(anchor, p)
            out << [entry, c] if c > 0
          end
          return out.each_with_index.sort_by { |(e, c), i| [-c, e.pkmn.name.to_s, i] }.map(&:first)
        rescue StandardError => e
          Reloaded::Log.exception("The Partner Finder couldn't look", e, :egg_manager)
          return []
        end

        # Why two get along as well as they do (the plate's green line)
        def why(anchor, partner)
          words = []
          words << _INTL("Same Species") if anchor.species == partner.species
          words << _INTL("Other Trainer") if (anchor.owner.id rescue 0) != (partner.owner.id rescue 0)
          return words.join(" · ") unless words.empty?
          return _INTL("Ditto") if ditto?(anchor) || ditto?(partner)
          group = (egg_groups(anchor) & egg_groups(partner)).first
          return group ? _INTL("{1} Egg Group", group_name(group)) : ""
        rescue StandardError
          return ""
        end

        def egg_groups(p)
          g = defined?(::KIF::Breeding) && ::KIF::Breeding.respond_to?(:egg_groups) ? ::KIF::Breeding.egg_groups(p) : p.species_data.egg_groups
          return Array(g)
        rescue StandardError
          return []
        end

        def ditto?(p)
          return egg_groups(p).include?(:Ditto)
        end

        def group_name(g)
          if defined?(::GameData::EggGroup) && ::GameData::EggGroup.respond_to?(:try_get)
            d = ::GameData::EggGroup.try_get(g)
            return d.name if d && d.respond_to?(:name)
          end
          return g.to_s.gsub(/([a-z])([A-Z0-9])/, '\1 \2')
        rescue StandardError
          return g.to_s
        end

        # Each Pokémon in the party and the boxes, as an Entry
        def each_pokemon
          Eggs.party.each_with_index { |p, i| yield Entry.new(p, -1, i) }
          st = $PokemonStorage
          Eggs.each_box do |b, _box|
            (0...st.maxPokemon(b)).each do |k|
              p = st[b, k]
              yield Entry.new(p, b, k) if p
            end
          end
        end

        #----------------------------------------------------------------------
        # Deposit, withdraw, collect, discard
        #----------------------------------------------------------------------
        # Why it can't be left there, or nil
        def deposit_reason(entry)
          p = entry.pkmn
          return _INTL("The Day Care is full.") if full?
          return _INTL("Eggs can't be left at the Day Care.") if p.egg?
          return _INTL("Shadow Pokémon can't be left there.") if (p.shadowPokemon? rescue false)
          if entry.party?
            others = Eggs.party.each_with_index.count { |q, i| i != entry.slot && !q.egg? && q.hp.to_i > 0 }
            return _INTL("You need another Pokémon that can battle in your party.") if others == 0
          end
          return nil
        end

        # Leaves it there: true, or why not
        def deposit(entry)
          reason = deposit_reason(entry)
          return reason if reason
          g = global
          if entry.party?
            @ours = true
            begin
              pbDayCareDeposit(entry.slot)
            ensure
              @ours = false
            end
          else
            i = g.daycare[0][0] ? 1 : 0
            p = entry.pkmn
            g.daycare[i][0] = p
            g.daycare[i][1] = p.level
            p.heal
            $PokemonStorage[entry.box, entry.slot] = nil
            g.daycareEgg = 0
            g.daycareEggSteps = 0
          end
          Reloaded::Events.emit(:day_care_deposit, :pokemon => entry.pkmn)
          return true
        rescue StandardError => e
          Reloaded::Log.exception("The Day Care couldn't take a Pokémon", e, :egg_manager)
          return _INTL("It couldn't be left there.")
        end

        # Why it can't come back (to :party or :pc), or nil
        def withdraw_reason(slot, to)
          return _INTL("There's no Pokémon there.") unless global && global.daycare[slot][0]
          return _INTL("You don't have enough money.") if money < cost(slot)
          if to == :party
            return _INTL("Your party is full.") if Eggs.party.length >= 6
          else
            return _INTL("The PC is full.") if Eggs.pc_full?
          end
          return nil
        end

        # Takes it back (to :party or :pc) and pays: [true, entry], or why not
        def withdraw(slot, to)
          reason = withdraw_reason(slot, to)
          return reason if reason
          p = global.daycare[slot][0]
          price = cost(slot)
          EggManager.quietly { pbDayCareWithdraw(slot) }
          $Trainer.money = money - price
          entry = Eggs.locate(p)
          if to == :pc && entry && entry.party?
            Eggs.to_box(entry, Eggs.store_box)
            entry = Eggs.locate(p)
          end
          return [true, entry]
        rescue StandardError => e
          Reloaded::Log.exception("The Day Care couldn't give a Pokémon back", e, :egg_manager)
          return _INTL("It couldn't be taken back.")
        end

        def collect_reason
          return _INTL("There's no Egg waiting.") unless egg_waiting?
          return _INTL("Your party and the PC are full.") if Eggs.party.length >= 6 && Eggs.pc_full?
          return nil
        end

        # Collects the waiting Egg: [true, where it went (an Entry)], or why not
        def collect
          reason = collect_reason
          return reason if reason
          before = Eggs.party.length
          EggManager.quietly { pbDayCareGenerateEgg }
          global.daycareEgg = 0
          global.daycareEggSteps = 0
          Alerts.day_care_reset
          egg = Eggs.party.length > before ? Eggs.party.last : Incubators.last_stored
          return [true, egg ? Eggs.locate(egg) : nil]
        rescue StandardError => e
          Reloaded::Log.exception("The Day Care's Egg couldn't be collected", e, :egg_manager)
          return _INTL("The Egg couldn't be collected.")
        end

        def discard
          return false unless egg_waiting?
          global.daycareEgg = 0
          global.daycareEggSteps = 0
          Alerts.day_care_reset
          return true
        end

        def install
          h = Reloaded::Hooks
          # the Day Care Man's deposit: the Day Care visited
          if Object.private_method_defined?(:pbDayCareDeposit) || Object.method_defined?(:pbDayCareDeposit)
            h.around(FEATURE, Object, :pbDayCareDeposit, :id => :egg_manager_visit) do |original, *args|
              ret = original.call(*args)
              Reloaded::EggManager::DayCare.visit! unless Reloaded::EggManager::DayCare.ours?
              ret
            end
          end
          return true
        end

        def ours?
          return @ours ? true : false
        end
      end
    end

    class << self
      # Runs the block with the game's messages kept quiet (the Day Care's
      # "was sent to the PC" while the Egg Manager says it its own way)
      def quietly
        @quiet = true
        return yield
      ensure
        @quiet = false
      end

      def quiet?
        return @quiet ? true : false
      end
    end
  end
end
