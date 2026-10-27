# encoding: utf-8
#==============================================================================
# Kanto Reloaded: IV Boundaries and KIF's Max IVs Mode
#==============================================================================
# Max IVs Mode counts every IV as 31 for stats (every Pokémon, foes too);
# Perfect rolls real 31s for new Pokémon. While IV Boundaries is On, KIF's
# row is locked Off with KIF's own Locks (his pick, Q11: not :takes_over,
# which would take its module's four other settings too). The player's own
# value is kept underneath, back when IV Boundaries is Off.
#
# A save that has it On keeps it (his pick, Q12): no lock there. Turned Off
# in KIF Settings, it's locked from then on.
#
# KIF's Locks have no one-key unlock (release drops every lock a mod
# holds), so this one key is taken out of its table.
#==============================================================================

module Reloaded
  module IVBoundaries
    module MaxIVs
      KEY = :maxivsmode
      BY = "Kanto Reloaded"
      OWNER = "KantoReloaded"

      # PokemonSystem#maxivsmode= (KIF Settings): turned Off, it locks
      module Setter
        def maxivsmode=(value)
          super
          Reloaded::IVBoundaries::MaxIVs.sync if Reloaded::IVBoundaries::MaxIVs.ready
        end
      end

      class << self
        attr_reader :ready

        def install
          h = Reloaded::Hooks
          h.needs(:kif_option, KEY, :id => :ivb_max_ivs)
          return unless defined?(::KIF::Locks) && defined?(::KIF::Options) && defined?(::PokemonSystem)
          h.prepend(FEATURE, ::PokemonSystem, Setter, :id => :ivb_max_ivs_set) if ::PokemonSystem.method_defined?(:"#{KEY}=")
          Reloaded::Events.on(:save_loaded, :ivb_max_ivs) { sync }
          Reloaded::Events.on(:new_game, :ivb_max_ivs) { sync }
          Reloaded::Events.on(:feature_changed, :ivb_max_ivs) { |e| sync if e.is_a?(Hash) && e[:id] == FEATURE }
          @ready = true
        end

        # The player's own value (a lock doesn't count)
        def own
          return ::KIF::Options.raw(KEY).to_i
        rescue StandardError
          return 0
        end

        def locked?
          lock = ::KIF::Locks.get(KEY)
          return lock && lock[2] == OWNER ? true : false
        end

        # Locked while IV Boundaries is On and this save's own is Off. The
        # game's value is the same either way, so no stats change
        def sync
          return unless defined?(::KIF::Locks) && $PokemonSystem
          want = Reloaded::Features.on?(FEATURE) && own == 0
          return if want == locked?
          if want
            ::KIF::Locks.set(KEY, 0, by: BY, owner: OWNER)
          else
            ::KIF::Locks.table.delete(KEY)
          end
        rescue StandardError => e
          Reloaded::Log.exception("IV Boundaries couldn't lock or free KIF's Max IVs Mode", e, FEATURE)
        end
      end
    end
  end
end
