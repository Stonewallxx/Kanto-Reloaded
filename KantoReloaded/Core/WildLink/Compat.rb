# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Wild Link with other mods and KIF's online play
#==============================================================================
#   Alpha Encounters   (CharmingLoopy's, no longer updated) His pick
#                      (2026-11-14, Can Be Alphas, Bonuses Kept): its chance
#                      applies to Wild Link targets too, but what Wild Link
#                      gave stays: its make_alpha writes an alpha move over
#                      the first move slot (or a random one); an Egg Move
#                      that lost its slot comes back in place of a move that
#                      isn't an Egg Move or an alpha move, and the held item
#                      stays. Linked once every mod has loaded (it loads
#                      after Kanto Reloaded)
#   Hoenn Native       (TheMagnumChad's) its walking Pokémon and Wild Link's
#   Overworld          target share PIF's engine; its map cleanup removes
#                      only its own (named HoennNativeWild), so a target is
#                      left alone. Nothing to link
#   Multiplayer        his pick (Each Their Own): Search Levels, chains and
#                      targets are each player's own; a target is a local
#                      event on its finder's map, and its battle joins co-op
#                      like any wild battle (the finder's game runs it, so
#                      its result reaches only the finder's Wild Link).
#                      Nothing to send
#   PIF's Route 24     the Poké Radar's quest asks for a Buneary
#   quest              (pbHasSpecies?, cody's Randomizer taking the one it
#                      became): the Rare Signal's target counts like any
#==============================================================================

module Reloaded
  module WildLink
    module Compat
      class << self
        def install
          link
          Reloaded::Events.on(:system_ready, :wild_link_compat, 50) { link }
        end

        def link
          return if @alpha || !(Object.private_method_defined?(:make_alpha) || Object.method_defined?(:make_alpha))
          @alpha = true
          Reloaded::Hooks.around(FEATURE, ::Object, :make_alpha, :id => :wild_link_alpha) do |original, pokemon, *rest|
            next original.call(pokemon, *rest) unless pokemon && pokemon.instance_variable_get(:@kr_wl_target)
            keep = Reloaded::WildLink::Compat.snapshot(pokemon)
            ret = original.call(pokemon, *rest)
            Reloaded::WildLink::Compat.restore(pokemon, keep)
            ret
          end
        end

        def snapshot(pk)
          return { :eggs => Array(pk.instance_variable_get(:@kr_wl_eggs)).map(&:to_sym), :item => (pk.item_id rescue nil) }
        end

        def move_id(m)
          return (m.respond_to?(:id) ? m.id : m).to_s.to_sym
        end

        # The Egg Moves it lost back in, in slots that aren't Egg Moves or
        # alpha moves; its held item back
        def restore(pk, keep)
          alpha = Array((pk.alpha_moves rescue nil)).map(&:to_sym)
          eggs = keep[:eggs]
          have = Array(pk.moves).map { |m| move_id(m) }
          (eggs - have).each do |egg|
            i = Array(pk.moves).index { |m| !eggs.include?(move_id(m)) && !alpha.include?(move_id(m)) }
            break unless i
            pk.moves[i] = defined?(::Pokemon::Move) ? ::Pokemon::Move.new(egg) : egg
          end
          pk.item = keep[:item] if keep[:item] && (pk.item_id rescue nil) != keep[:item]
        rescue StandardError => e
          Reloaded::Log.warning_once("Wild Link couldn't keep a target's moves past Alpha Encounters (#{e.class})", :wild_link)
        end
      end
    end
  end
end
