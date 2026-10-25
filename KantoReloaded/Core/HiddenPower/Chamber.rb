# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Hidden Chamber (Map677), fixed
#==============================================================================
# PIF's chamber stays as it is (his pick, Q12: keep it, fix all four): a
# plate in the basket gives the room its type, and the altar teaches that
# type of Hidden Power. Its faults, fixed in memory:
#
#   The altar      a Pokémon that knows Hidden Power already can take the
#                  room's type, for free (PIF's said "already knows"); with
#                  the basket empty it says so (PIF's taught a Normal-type
#                  Hidden Power that even hit Ghosts)
#   The basket     swapping plates gives the old one back (PIF's called a
#                  PBItems.pbGet there isn't, and lost it)
#   Daily plate    the Flame and Draco Plates too (two outcomes gave the
#                  Mind and Spooky Plates again)
#   The tablet     beside the basket, it says what the basket holds and the
#                  room's type (his pick, 2026-10-25); empty, PIF's "Offer an
#                  elemental plate."
#
# The altar's, the daily plate's and the tablet's lists go through
# EventLists (fingerprints of PIF's: an update that changes them leaves them
# PIF's).
#==============================================================================

module Reloaded
  module HiddenPower
    module Chamber
      MAP = 677
      ALTAR = 1
      ALTAR_CRC = 2_507_626_196
      DAILY = 10
      DAILY_CRC = 2_356_476_187
      TABLET = 4
      TABLET_CRC = 1_732_470_760
      PLATE_VAR = 218               # the plate in the basket
      TYPE_VAR = 219                # the room's type
      # The daily plate's outcomes that repeat another: index in PIF's list,
      # what's there, what it gives now
      DAILY_FIX = { 38 => ["Kernel.pbItemBall(PBItems::MINDPLATE)", "Kernel.pbItemBall(PBItems::FLAMEPLATE)"],
                    54 => ["Kernel.pbItemBall(PBItems::SPOOKYPLATE)", "Kernel.pbItemBall(PBItems::DRACOPLATE)"] }.freeze

      class << self
        def install
          EventLists.register(MAP, ALTAR, ALTAR_CRC, "The Hidden Chamber's Altar") do |_list|
            [EventLists.script("Reloaded::HiddenPower::Chamber.altar"), EventLists.command(0, 0, [])]
          end
          EventLists.register(MAP, DAILY, DAILY_CRC, "The Hidden Chamber's Daily Plate") do |list|
            list.each_with_index.map do |cmd, i|
              fix = DAILY_FIX[i]
              fix && cmd.parameters == [fix[0]] ? EventLists.script(fix[1], cmd.indent) : cmd
            end
          end
          EventLists.register(MAP, TABLET, TABLET_CRC, "The Hidden Chamber's Tablet") do |_list|
            [EventLists.script("Reloaded::HiddenPower::Chamber.tablet"), EventLists.command(0, 0, [])]
          end
          EventLists.install
          fix_basket
          install_altar_learn
        end

        # PIF's basket gives the old plate back with PBItems::pbGet(1)
        def fix_basket
          return unless defined?(::PBItems) && !::PBItems.respond_to?(:pbGet)
          ::PBItems.define_singleton_method(:pbGet) { |id| $game_variables ? $game_variables[id] : nil }
          Reloaded::Log.info("Fix on: the Hidden Chamber's basket gives back the plate it swaps", :hidden_power)
        end

        def room_type
          return nil unless $game_variables
          return nil if $game_variables[PLATE_VAR].nil? || $game_variables[PLATE_VAR] == 0
          t = Reloaded::HiddenPower.normal($game_variables[TYPE_VAR])
          return t && Reloaded::HiddenPower.pool.include?(t) ? t : nil
        end

        # The plate in the basket, by name
        def plate_name
          id = $game_variables ? $game_variables[PLATE_VAR] : nil
          item = (::GameData::Item.try_get(id) rescue nil)
          return item ? item.name : (::PBItems.getName(id) rescue id.to_s)
        end

        # The tablet beside the basket (KR's list): what the room holds
        def tablet
          t = room_type
          return pbMessage(_INTL("Offer an elemental plate.")) unless t
          pbMessage(_INTL("The {1} rests in the basket. The room is imbued with the essence of {2}-type.",
                          plate_name, Reloaded::HiddenPower.type_name(t)))
        end

        # The altar (KR's list): PIF's words, the fixes
        def altar
          t = room_type
          unless t
            Reloaded::HiddenPowerScreen.basket_empty
            return
          end
          name = Reloaded::HiddenPower.type_name(t)
          pbMessage(_INTL("The room is imbued with the essence of {1}-type.", name))
          return unless pbConfirmMessage(_INTL("Learn the {1}-type Hidden Power?", name))
          @teaching = t
          learned = begin
            pbMoveTutorChoose(:HIDDENPOWER, nil, true, false, 1)
          ensure
            @teaching = nil
          end
          return unless learned
          poke = pbGet(1)
          return unless poke
          if Reloaded::HiddenPower.unown?(poke)
            Reloaded::HiddenPowerScreen.unown(poke)
          else
            Reloaded::HiddenPower.set(poke, t, :chamber)
          end
        end

        def teaching
          return @teaching
        end

        # While the altar teaches: one that knows Hidden Power already is
        # asked whether to take the room's type (free), instead of PIF's
        # "already knows"
        def install_altar_learn
          return unless Object.private_method_defined?(:pbLearnMove) || Object.method_defined?(:pbLearnMove)
          Reloaded::Hooks.around(nil, Object, :pbLearnMove, :id => :hidden_power_altar) do |original, *args|
            t = Reloaded::HiddenPower::Chamber.teaching
            pkmn = args[0]
            next original.call(*args) unless t && pkmn && Reloaded::HiddenPower.knows_hidden_power?(pkmn)
            Reloaded::HiddenPower::Chamber.change_known(pkmn, t)
          end
        end

        def change_known(pkmn, to)
          if Reloaded::HiddenPower.unown?(pkmn)
            Reloaded::HiddenPowerScreen.unown(pkmn)
            return false
          end
          from = Reloaded::HiddenPower.type_of(pkmn)
          if from == to
            pbMessage(_INTL("{1}'s Hidden Power is {2}-type already.", pkmn.name, Reloaded::HiddenPower.type_name(to)))
            return false
          end
          return false unless Reloaded::HiddenPowerScreen.altar_ask(pkmn, from, to)
          Reloaded::HiddenPower.set(pkmn, to, :chamber)
          return true
        end
      end
    end
  end
end
