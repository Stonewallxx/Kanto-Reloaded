# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Trainer Control's Smarter Trainers (Tougher Trainers A)
#==============================================================================
# PIF Today: trainers think with PIF 6.8.2's AI; Hard gives them its top
# skill. KIF adds a choice, Battle Settings > Battle AI: PIF or DemICE (the
# community hard-mode mods' AI, F-BATTLE-03), DemICE by default, per save.
#
# His picks (2026-10-31): DemICE's AI as it is, always on with Kanto
# Reloaded: KIF's Battle AI row is locked to DemICE (KIF's Locks: the row
# shows "Set by Kanto Reloaded" and can't be changed). DemICE plays at its
# top skill on every difficulty, so there's no skill floor to add. Kanto
# Reloaded's own AI went to PIF Reloaded instead (the Reloaded AI).
#==============================================================================

module Reloaded
  module TrainerControl
    module Smarter
      KEY = :powerfulai                    # KIF's Battle AI (0 PIF, 1 DemICE)
      DEMICE = 1
      BY = "Kanto Reloaded"
      OWNER = "KantoReloaded"              # the mod's id (KIF's Locks name their owner by it)

      class << self
        def install
          return false unless defined?(::KIF::Locks) && ::KIF::Locks.respond_to?(:set)
          return true if locked?
          return ::KIF::Locks.set(KEY, DEMICE, by: BY, owner: OWNER) ? true : false
        rescue StandardError => e
          Reloaded::Log.exception("Trainer Control couldn't lock KIF's Battle AI to DemICE", e, :trainer_control)
          return false
        end

        def locked?
          lock = ::KIF::Locks.respond_to?(:get) ? ::KIF::Locks.get(KEY) : nil
          return lock && lock[0] == DEMICE && lock[2].to_s == OWNER ? true : false
        end
      end
    end
  end
end
