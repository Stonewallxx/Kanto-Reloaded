# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Double Abilities
#==============================================================================
# Every fusion has two abilities, one from its head and one from its body:
# yours, trainers' and wild ones (Roadmap topic double-abilities, his picks
# 2026-10-26). A feature with a switch, On.
#
#   The pair     the head's pick is the game's own ability (PIF's
#                @ability_index, an odd index of the fused species' list: so
#                without Kanto Reloaded the fusion keeps it); the body's is
#                Kanto Reloaded's @kr_ability2_index (an even one). A fused
#                list keeps the head odd and the body even, so evolving keeps
#                each pick on its side. The second always comes from the side
#                the main ability isn't from (an old save's fusion whose main
#                is the body's gets the head's)
#   Worked out   a fusion with no pick of its own (wild, trainers', gifts,
#                every fusion already in a save) gets one of the other side's
#                regular abilities, chosen by its personality value, never a
#                banned pair: the same every time, nothing saved
#   Repaired     a pick that's banned with the main ability now (an evolution,
#                a mod's new pair) falls back to the worked-out one, logged once
#   The same     both sides with one ability count it once
#   Legacy       Kanto Reloaded Legacy's picks are read once into ours; its own
#                fields stay
#   Wonder Guard a fusion with Wonder Guard on either side has 1 HP; in battle
#                a paired Wonder Guard blocks Wonder Guard Blocks hits, then
#                wears off (Battle.rb)
#   KIF-ER       with KIF: Elite Redux's Innates On, its choice abilities are
#                the pair (EliteRedux.rb)
#   Possessed    a Ghostly Possession host has the Ghost's side as its second
#                while possessed (worked out, never its stored pick)
#
#   Reloaded::DoubleAbilities.applies?(pkmn)     it has two (a fusion, not a
#                                                triple, the feature On)
#   Reloaded::DoubleAbilities.second_id(pkmn)    its second ability
#   Reloaded::DoubleAbilities.pair(pkmn)         [[:head, id], [:body, id]]
#   Reloaded::DoubleAbilities.choices(pkmn, side) a side's [index, id, hidden?]
#   Reloaded::DoubleAbilities.ban(a, b, ...)     a banned pair (Banned.rb)
#==============================================================================

module Reloaded
  module DoubleAbilities
    FEATURE = :double_abilities
    PAGE = :double_abilities
    BLOCKS = [1, 3].freeze            # Wonder Guard Blocks' range (his pick: 1 to 3)
    HEAD_IDX = [1, 3, 5].freeze       # a fused list: the head's first, second, hidden
    BODY_IDX = [0, 2, 4].freeze

    class << self
      # Kanto Reloaded boots before the game loads its data: nothing here
      # reads GameData
      def boot
        register_settings
        Reloaded::Features.register(FEATURE, :name => "Double Abilities", :page => PAGE, :order => 62,
          :description => "Every fusion has two abilities, one from its head and one from its body: Yours, trainers' and wild ones.")
        install_pokemon
        [:Banned, :Battle, :PopUps, :Fusing, :EliteRedux].each do |part|
          begin
            const_get(part).install if const_defined?(part, false) && const_get(part).respond_to?(:install)
          rescue StandardError => e
            Reloaded::Log.exception("Double Abilities' #{part} couldn't start", e, FEATURE)
          end
        end
        return true
      end

      def on?
        return Reloaded::Features.on?(FEATURE)
      end

      def key(id)
        return :"double_abilities.#{id}"
      end

      def blocks
        return Reloaded::Settings.get(key(:wonder_guard_blocks)).to_i.clamp(*BLOCKS)
      rescue StandardError
        return BLOCKS[1]
      end

      #------------------------------------------------------------------------
      # Which Pokémon have two
      #------------------------------------------------------------------------
      def applies?(pkmn)
        return false unless pkmn && on?
        return false if pkmn.respond_to?(:egg?) && pkmn.egg?
        return false unless pkmn.respond_to?(:isFusion?) && pkmn.isFusion?
        return false if pkmn.respond_to?(:isTripleFusion?) && pkmn.isTripleFusion?
        return true
      rescue StandardError
        return false
      end

      # KIF: Elite Redux's Innates On, and this Pokémon has its choices: they
      # are its pair (EliteRedux.rb)
      def elite_redux?(pkmn)
        return defined?(Reloaded::DoubleAbilities::EliteRedux) && EliteRedux.runs?(pkmn)
      end

      # Ghostly Possession's host while possessed
      def possessed?(pkmn)
        gp = defined?(::GhostlyPossession::Engine) ? ::GhostlyPossession::Engine : nil
        return gp && gp.respond_to?(:applied?) && gp.applied?(pkmn) ? true : false
      rescue StandardError
        return false
      end

      #------------------------------------------------------------------------
      # The fused species' list (FusedSpecies.rb:220-265): index 0 the body's
      # first, 1 the head's first, 2 and 3 their second (or first again), 4
      # and 5 their hidden (or second again). Even is the body, odd the head
      #------------------------------------------------------------------------
      def at(pkmn, index)
        sd = pkmn.species_data
        return index < 2 ? Array(sd.abilities)[index] : Array(sd.hidden_abilities)[index - 2]
      rescue StandardError
        return nil
      end

      def side_of(index)
        return index.to_i.odd? ? :head : :body
      end

      def other(side)
        return side == :head ? :body : :head
      end

      # A side's abilities as [index, id, hidden?], each once, regular first;
      # the hidden one only when asked (the Secret Capsule, a parent that had it)
      def choices(pkmn, side, hidden = true)
        out = []
        (side == :head ? HEAD_IDX : BODY_IDX).each do |i|
          next if i >= 4 && !hidden
          id = at(pkmn, i)
          next if id.nil? || out.any? { |_j, a, _h| a == id }
          out << [i, id, i >= 4]
        end
        return out
      end

      # The side the main ability is from: its index's, while the index gives
      # it; else the side whose list has it (an ability set by an event, the
      # Ability Ball, Ghostly Possession's host)
      def main_side(pkmn)
        id = pkmn.ability_id
        i = pkmn.ability_index.to_i
        return side_of(i) if at(pkmn, i) == id
        [:head, :body].each { |s| return s if choices(pkmn, s).any? { |_j, a, _h| a == id } }
        return side_of(i)
      end

      #------------------------------------------------------------------------
      # The second
      #------------------------------------------------------------------------
      # Its index in the fused list: the pick, while it's on the other side
      # and not banned with the main; else worked out. nil: none
      def second_index(pkmn)
        return nil unless applies?(pkmn)
        read_legacy(pkmn)
        main = pkmn.ability_id
        side = other(main_side(pkmn))
        stored = pkmn.instance_variable_get(:@kr_ability2_index)
        if stored.is_a?(Integer) && side_of(stored) == side && !possessed?(pkmn)
          id = at(pkmn, stored)
          return stored if id && !banned?(main, id)
          note_repair(pkmn, id, main) if id
        end
        return worked_out(pkmn, main, side)
      end

      # One of the side's regular abilities, never banned with the main,
      # another than the main when there's one, chosen by the personality
      # value (its lowest bit picks PIF's own ability, so the next one)
      def worked_out(pkmn, main, side)
        list = choices(pkmn, side, false).reject { |_i, a, _h| banned?(main, a) }
        return nil if list.empty?
        pick = list.reject { |_i, a, _h| a == main }
        pick = list if pick.empty?
        return pick[(pkmn.personalID.to_i >> 1) % pick.length][0]
      end

      def second_id(pkmn)
        return nil unless applies?(pkmn)
        return EliteRedux.second(pkmn) if elite_redux?(pkmn)
        i = second_index(pkmn)
        return i ? at(pkmn, i) : nil
      end

      # Both, head first: [[:head, id], [:body, id]] (nil when it has one)
      def pair(pkmn)
        return nil unless applies?(pkmn)
        return EliteRedux.pair(pkmn) if elite_redux?(pkmn)
        a2 = second_id(pkmn)
        return nil unless a2
        side = main_side(pkmn)
        both = { side => pkmn.ability_id, other(side) => a2 }
        return [[:head, both[:head]], [:body, both[:body]]]
      end

      # Sets the body's (or the side opposite the main's) pick by its index
      def set_second(pkmn, index)
        if index.nil?
          pkmn.remove_instance_variable(:@kr_ability2_index) if pkmn.instance_variable_defined?(:@kr_ability2_index)
          return
        end
        pkmn.instance_variable_set(:@kr_ability2_index, index.to_i)
      end

      # A pick banned with the main now: the worked-out one stands (logged once)
      def note_repair(pkmn, id, main)
        Reloaded::Log.warning_once("Double Abilities: #{pkmn.name}'s #{id} can't pair with #{main} now, so it has another", FEATURE)
      rescue StandardError
      end

      # Kanto Reloaded Legacy's pick (its @ability2 on a pair it made), read
      # once into ours; its own fields stay (his pick, Q11)
      def read_legacy(pkmn)
        return if pkmn.instance_variable_get(:@kr_da_legacy_read)
        pkmn.instance_variable_set(:@kr_da_legacy_read, true)
        return if pkmn.instance_variable_defined?(:@kr_ability2_index)
        return unless pkmn.instance_variable_get(:@kr_double_abilities_version).to_i > 0
        old = pkmn.instance_variable_get(:@ability2)
        old = old.id if old.respond_to?(:id) && !old.is_a?(Symbol)
        return unless old.is_a?(Symbol)
        side = other(main_side(pkmn))
        hit = choices(pkmn, side).find { |_i, a, _h| a == old }
        pkmn.instance_variable_set(:@kr_ability2_index, hit[0]) if hit
      rescue StandardError => e
        Reloaded::Log.warning_once("Double Abilities: a Legacy pick couldn't be read (#{e.class}: #{e.message})", FEATURE)
      end

      def banned?(a, b)
        return defined?(Reloaded::DoubleAbilities::Banned) ? Banned.banned?(a, b) : false
      end

      # Wonder Guard on either side (not with KIF-ER's Innates On: its rules)
      def wonder_guard?(pkmn)
        return false unless applies?(pkmn) && !elite_redux?(pkmn)
        return pkmn.ability_id == :WONDERGUARD || second_id(pkmn) == :WONDERGUARD
      end

      #------------------------------------------------------------------------
      # The Pokémon: other mods and the game's checks see the second
      #------------------------------------------------------------------------
      module PokemonSecond
        # KIF's ModCompat ability2 family (ModCompat.rb:112-160) answers the
        # second while it applies (with KIF-ER's Innates On, KIF-ER answers)
        def ability2_id
          da = Reloaded::DoubleAbilities
          return super unless da.applies?(self) && !da.elite_redux?(self)
          return da.second_id(self)
        end

        def ability2
          da = Reloaded::DoubleAbilities
          return super unless da.applies?(self) && !da.elite_redux?(self)
          return GameData::Ability.try_get(da.second_id(self))
        end

        def ability2=(value)
          da = Reloaded::DoubleAbilities
          return super unless da.applies?(self) && !da.elite_redux?(self)
          id = value.respond_to?(:id) && !value.is_a?(Symbol) ? value.id : value
          side = da.other(da.main_side(self))
          hit = da.choices(self, side).find { |_i, a, _h| a == id }
          da.set_second(self, hit ? hit[0] : nil) if hit || id.nil?
        end

        # Out of battle a second counts too (Pickup, Intimidate's encounter
        # rate, Flash Fire's...)
        def hasAbility?(check_ability = nil)
          return true if super
          return false if check_ability.nil?
          da = Reloaded::DoubleAbilities
          return false unless da.applies?(self) && !da.elite_redux?(self)
          a2 = da.second_id(self)
          return false unless a2
          want = check_ability.respond_to?(:id) && !check_ability.is_a?(Symbol) ? check_ability.id : check_ability
          return a2 == want
        end

        def adjustHPForWonderGuard(stats)
          return 1 if Reloaded::DoubleAbilities.wonder_guard?(self)
          return super
        end

        # Fusing or unfusing (not evolving) starts the pick again
        def species=(species_id)
          was = isFusion? rescue nil
          ret = super
          now = isFusion? rescue nil
          if was != now && instance_variable_defined?(:@kr_ability2_index)
            remove_instance_variable(:@kr_ability2_index)
          end
          return ret
        end
      end

      def install_pokemon
        Reloaded::Hooks.prepend(FEATURE, ::Pokemon, PokemonSecond, :id => :double_abilities_pokemon) if defined?(::Pokemon)
        # Reversing swaps head and body; each ability stays with its Pokémon
        # (his pick, Q12: PIF's kept the index, so both changed to the other
        # side's counterparts, B8)
        return unless Object.private_method_defined?(:reverseFusion) || Object.method_defined?(:reverseFusion)
        Reloaded::Hooks.around(FEATURE, Object, :reverseFusion, :id => :double_abilities_reverse) do |original, pkmn, *rest|
          before = pkmn.respond_to?(:species) ? pkmn.species : nil
          ret = original.call(pkmn, *rest)
          if pkmn.respond_to?(:species) && pkmn.species != before && pkmn.isFusion?
            Reloaded::DoubleAbilities.swap_sides(pkmn)
          end
          ret
        end
      end

      def swap_sides(pkmn)
        i = pkmn.instance_variable_get(:@ability_index)
        pkmn.instance_variable_set(:@ability_index, i ^ 1) if i.is_a?(Integer)
        j = pkmn.instance_variable_get(:@kr_ability2_index)
        pkmn.instance_variable_set(:@kr_ability2_index, j ^ 1) if j.is_a?(Integer)
        pkmn.instance_variable_set(:@ability, nil)
        pkmn.calc_stats if pkmn.respond_to?(:calc_stats)
      end

      #------------------------------------------------------------------------
      # Settings (his picks: the switch, Banned Pairs, Wonder Guard Blocks)
      #------------------------------------------------------------------------
      def register_settings
        s = Reloaded::Settings
        s.register_page(PAGE, :group => :general, :name => "Double Abilities", :icon => :features, :priority => 49,
          :feature => FEATURE, :description => "Every fusion's two abilities.")
        s.register(key(:banned_pairs), :page => PAGE, :priority => 10, :type => :button, :scope => :global, :preset => false,
          :name => "Banned Pairs",
          :on_press => proc { Reloaded::BannedPairsScreen.open if defined?(Reloaded::BannedPairsScreen) },
          :description => "The pairs of abilities a fusion can't have together, and why. With KIF: Elite Redux's Innates On, its own rules apply.")
        s.register(key(:wonder_guard_blocks), :page => PAGE, :priority => 20, :type => :slider, :min => BLOCKS[0], :max => BLOCKS[1],
          :default => BLOCKS[1], :scope => :save, :name => "Wonder Guard Blocks",
          :description => "A fusion with Wonder Guard and a second ability has 1 HP, and its Wonder Guard blocks this many hits a battle, then wears off.")
      end
    end
  end
end
