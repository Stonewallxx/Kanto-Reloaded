# encoding: utf-8
#==============================================================================
# Kanto Reloaded: IV Boundaries' sources
#==============================================================================
# Which Pokémon get which range, and when (his picks, 2026-10-25):
#
#   Wild    when they appear, through PIF's own Events.onWildPokemonCreate
#           (no hook), first in its list so a mod's bonus there (an alpha's
#           31s) comes on top: wild, statics, roamers, event battles,
#           Hoenn's overworld Pokémon
#   Gifts   an event's hand-overs (pbAddPokemon and its family,
#           pbAddPokemonID; Kanto's and Hoenn's starters go through them),
#           in-game trades and Wonder Trade (pbStartTrade makes the one you
#           get)
#   Eggs    gift Eggs (pbGenerateEgg and its two aliases, separate methods),
#           Day Care Eggs once their IVs are inherited (inside the range
#           they stay), Kuray Eggs
#
# "New" (his pick, Q1): a Pokémon made while the call runs, or made in the
# same event script that hands it over. A Pokémon passed in that was made
# before (the Day Care's, unfused halves, Eusine's give-back, a Mystery
# Gift) keeps its IVs. Pokemon#initialize joins the open collector (one
# check when none is open); each map event's Script command opens one.
#==============================================================================

module Reloaded
  module IVBoundaries
    module Sources
      GIFTS = [:pbAddPokemon, :pbAddPokemonSilent, :pbAddToParty, :pbAddToPartySilent, :pbAddForeignPokemon, :pbAddPokemonID].freeze
      EGGS = [:pbGenerateEgg, :pbAddEgg, :pbGenEgg].freeze

      # Pokemon#initialize: a new Pokémon joins the open collector
      module Made
        def initialize(*args, &block)
          super
          Reloaded::IVBoundaries.made(self) if Reloaded::IVBoundaries.collect
        end
      end

      # Interpreter#execute_script: the Pokémon a map event's script makes
      # count as new when that script hands them over
      module EventScript
        def execute_script(script)
          return super unless Reloaded::Features.on?(FEATURE)
          ret = nil
          Reloaded::IVBoundaries.collecting { ret = super }
          return ret
        end
      end

      class << self
        def install
          h = Reloaded::Hooks
          me = Reloaded::IVBoundaries
          h.prepend(FEATURE, ::Pokemon, Made, :id => :ivb_made) if defined?(::Pokemon)
          h.prepend(FEATURE, ::Interpreter, EventScript, :id => :ivb_event_script) if defined?(::Interpreter)
          install_wild
          # Gifts: a Pokémon passed in counts only when it's new; anything
          # made inside the call gets its range after it (an Egg, the Eggs')
          gift = proc do |original, pkmn, *rest|
            me.bound(pkmn, :gift) if me.new?(pkmn)
            ret = nil
            made = me.collecting { ret = original.call(pkmn, *rest) }
            made.each_key { |p| me.bound(p, p.respond_to?(:egg?) && p.egg? ? :egg : :gift) unless p.equal?(pkmn) }
            ret
          end
          GIFTS.each { |m| h.around(FEATURE, Object, m, :id => :"ivb_#{m}", &gift) if game_method?(m) }
          # Trades and Wonder Trade: the Pokémon you get (pbStartTrade returns it)
          if game_method?(:pbStartTrade)
            h.around(FEATURE, Object, :pbStartTrade, :id => :ivb_trade) do |original, idx, newpoke, *rest|
              me.bound(newpoke, :gift) if me.new?(newpoke)
              got = nil
              made = me.collecting { got = original.call(idx, newpoke, *rest) }
              made.each_key { |p| me.bound(p, :gift) unless p.equal?(newpoke) }
              got
            end
          end
          # Gift Eggs: all three names (the aliases are separate methods)
          egg = proc do |original, pkmn, *rest|
            me.bound(pkmn, :egg) if me.new?(pkmn)
            ret = nil
            made = me.collecting { ret = original.call(pkmn, *rest) }
            made.each_key { |p| me.bound(p, :egg) unless p.equal?(pkmn) }
            ret
          end
          EGGS.each { |m| h.around(FEATURE, Object, m, :id => :"ivb_#{m}", &egg) if game_method?(m) }
          # The Day Care: its Egg after the parents' IVs are inherited
          if game_method?(:pbDayCareGenerateEgg)
            h.around(FEATURE, Object, :pbDayCareGenerateEgg, :id => :ivb_day_care) do |original, *args|
              ret = nil
              made = me.collecting { ret = original.call(*args) }
              made.each_key { |p| me.bound(p, :egg) }
              ret
            end
          end
          # Kuray Eggs: made by the item just before they're handed over
          k = defined?(::KIF::KurayEggs) ? ::KIF::KurayEggs : nil
          if k && k.respond_to?(:add_like_caught)
            h.around(FEATURE, k.singleton_class, :add_like_caught, :id => :ivb_kuray_eggs) do |original, pkmn, *rest|
              me.bound(pkmn, :egg)
              original.call(pkmn, *rest)
            end
          end
        end

        # PIF's own event, first in its list (a mod's bonus after it stays)
        def install_wild
          return unless defined?(::Events) && ::Events.respond_to?(:onWildPokemonCreate)
          handler = proc do |_sender, e|
            next unless Reloaded::Features.on?(FEATURE)
            begin
              Reloaded::IVBoundaries.bound(e[0], :wild)
            rescue StandardError => err
              Reloaded::Log.exception("IV Boundaries couldn't set a wild Pokémon's IVs", err, FEATURE)
            end
          end
          ev = ::Events.onWildPokemonCreate
          list = ev.instance_variable_get(:@callbacks)
          if list.is_a?(Array)
            list.unshift(handler)
          else
            ::Events.onWildPokemonCreate += handler
          end
        end

        def game_method?(name)
          return Object.private_method_defined?(name) || Object.method_defined?(name)
        end
      end
    end
  end
end
