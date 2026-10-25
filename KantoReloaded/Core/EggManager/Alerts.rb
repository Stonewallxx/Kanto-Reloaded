# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Egg Manager's alerts
#==============================================================================
# His picks (Q7 All of These, Q8 Under 100 Steps, the Pill Toast): each
# once, as it happens, a toast with the Egg, one line and a pill:
#
#   "An Egg is about to hatch!"              60 STEPS   a party Egg under 100 steps
#   "An Egg in Box 3 is ready to hatch."     READY      an incubated Egg at its last step
#   "The Day Care has an Egg for you."       DAY CARE   the Day Care made one
#   "An Egg went into Incubator 3."          BOX 5      Auto-Incubate
#
# and the Egg Manager's Pause Menu tile and Overworld Menu entry glow red
# while something waits (any?). The ones already shown are kept by the
# save, so loading doesn't repeat them. Hatch Alerts Off: none of these.
#==============================================================================

module Reloaded
  module EggManager
    module Alerts
      KEEP = 200            # shown alerts remembered (the oldest dropped)

      class << self
        def on?
          return EggManager.setting(:alerts) ? true : false
        end

        # Something waits: a Ready Egg, a party Egg about to hatch, the Day
        # Care's Egg (cheap: the party, the incubators' count, one flag)
        def any?
          return false unless EggManager.on? && on?
          return true if Incubators.ready_count > 0
          return true if Eggs.party.any? { |p| p.egg? && p.steps_to_hatch.to_i < EggManager::SOON }
          return DayCare.egg_waiting?
        rescue StandardError
          return false
        end

        # Each step (after the incubators): a party Egg coming close, the
        # Day Care's Egg
        def step
          return unless on?
          instant = defined?(Reloaded::QualityOfLife) && Reloaded::QualityOfLife.on?(:instant_hatch)
          unless instant
            Eggs.party.each do |p|
              next unless p.egg?
              s = p.steps_to_hatch.to_i
              soon(p, s) if s > 0 && s < EggManager::SOON
            end
          end
          day_care_egg if DayCare.egg_waiting?
        end

        def soon(egg, steps)
          return unless once("s#{key(egg)}")
          toast(_INTL("An Egg is about to hatch!"), steps == 1 ? _INTL("1 STEP") : _INTL("{1} STEPS", steps), :gold)
        end

        def ready(egg)
          return unless on? && once("r#{key(egg)}")
          entry = Eggs.locate(egg)
          where = entry && !entry.party? ? Eggs.box_name(entry.box) : _INTL("the PC")
          toast(_INTL("An Egg in {1} is ready to hatch.", where), _INTL("READY"), :gold)
        end

        def day_care_egg
          d = EggManager.data
          return if d.nil? || d["day_care_shown"]
          d["day_care_shown"] = true
          toast(_INTL("The Day Care has an Egg for you."), _INTL("DAY CARE"), :green)
        end

        # The Egg collected or discarded: the next one says so again
        def day_care_reset
          d = EggManager.data
          d["day_care_shown"] = false if d
        end

        def incubated(n, box)
          return unless on?
          toast(_INTL("An Egg went into Incubator {1}.", n), _INTL("BOX {1}", box.to_i + 1), :gold)
        end

        # Not over the Egg Manager or while it works (it says so itself)
        def toast(text, pill, tone)
          return false unless defined?(Reloaded::Toast) && !EggManager.screen_open && !EggManager.quiet?
          return Reloaded::Toast.show(text, :icon => egg_icon, :pill => [pill, tone])
        end

        # The Egg as the player sees Eggs (Big Pokémon Icons or PIF's),
        # trimmed to its art so it fills the toast's square
        def egg_icon
          return @egg_icon if @egg_icon && !@egg_icon.disposed?
          bm = Reloaded::PartyIcons.egg_bitmap
          return nil unless bm
          r = Reloaded::PartyIcons.art_rect(bm, [bm.height, 1].max)
          side = [r.width, r.height, 1].max
          @egg_icon = Bitmap.new(side, side)
          @egg_icon.blt((side - r.width) / 2, (side - r.height) / 2, bm, r)
          bm.dispose
          return @egg_icon
        rescue StandardError
          return nil
        end

        private

        def key(egg)
          return (egg.personalID rescue egg.object_id).to_s
        end

        # True the first time (and remembers it)
        def once(k)
          d = EggManager.data
          return false unless d
          list = Array(d["shown"])
          return false if list.include?(k)
          d["shown"] = (list + [k]).last(KEEP)
          return true
        end
      end
    end
  end
end
