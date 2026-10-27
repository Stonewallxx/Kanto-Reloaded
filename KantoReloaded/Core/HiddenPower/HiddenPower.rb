# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Hidden Power
#==============================================================================
# Every Pokémon's Hidden Power has a type of its own (Roadmap topic
# hidden-power, his picks 2026-10-25). Always on with Kanto Reloaded: no
# switch.
#
#   The type   rolled when a Pokémon is made, from the 17 standard types but
#              Normal, and kept in PIF's own field (Pokemon#hiddenPowerType),
#              which PIF's move, its AI and cody's Move Effectiveness already
#              read, so a save keeps every type without Kanto Reloaded
#   Unown      and any fusion with Unown: a neutral ??? Hidden Power that
#              hits every type x1 (the researcher's words, now true); nothing
#              changes it
#   Old saves  each Pokémon keeps the type it has now (its IVs', or the
#              Hidden Chamber's); one with a neutral type (PIF's list takes
#              28 types in KIF Beta) gets a roll. Once per load, then
#              nothing to do
#   Fusions    a roll of their own, from the two Pokémon: the same two fused
#              again get the same type, and a type changed while fused is
#              remembered for that pair. Unfused, each gets its own back
#   Power      PIF's 30 to 70 from the IVs (generation 5), shown as it is
#   Trainers   rolled like every other; the Endgame Challenge's Shedproofing
#              gets the type its counter needs (its IV spreads never did)
#
# PIF's pbHiddenPower sorts every type on every call (the AI calls it for
# each move it weighs); with a stored type it now answers at once.
#
#   Reloaded::HiddenPower.type_of(pkmn)        the type (fills an old one)
#   Reloaded::HiddenPower.power_of(pkmn)       its power
#   Reloaded::HiddenPower.set(pkmn, type)      for plates, the altar, mods
#   Reloaded::HiddenPower.reroll(pkmn)         a new type, never the one now
#   Reloaded::HiddenPower.move_type(pkmn, id)  a move's type for this Pokémon
#   Reloaded::HiddenPower.move_power(pkmn, id) a move's power for this Pokémon
#   Events: :hidden_power_changed (:pokemon, :from, :to, :how)
#==============================================================================

module Reloaded
  module HiddenPower
    # The 17 standard types but Normal, by name (HR's list): not PIF's
    # filter, which in KIF Beta also takes a second ??? and 10 triple-fusion
    # types
    STANDARD = %i[FIGHTING FLYING POISON GROUND ROCK BUG GHOST STEEL FIRE WATER
                  GRASS ELECTRIC PSYCHIC ICE DRAGON DARK FAIRY].freeze
    NEUTRAL = :QMARKS             # ???: no weaknesses, so every type takes x1
    FUNCTION = "090"              # Hidden Power's function code (HIDDENPOWER2 too)
    PAIRS = :@kr_hp_pairs         # on a Pokémon: { partner's personalID => type }
    POWER_MIN = 30
    POWER_MAX = 70

    class << self
      # Its other parts, each a module of this one with an install
      PARTS = [:Battle, :Summary, :Researcher, :Plates, :Chamber].freeze

      # Kanto Reloaded boots before the game loads its data: nothing here
      # may read GameData (PIF's get of a missing id asks for :PIKACHU, which
      # no table but Species has, for ever)
      def boot
        # a new game's party is made with Pokemon.new: nothing old to fill
        Reloaded::Events.on(:save_loaded, :hidden_power, 60) { |c| fill_save unless c.is_a?(Hash) && c[:new_game] }
        install
        ok = true
        PARTS.each do |name|
          next unless const_defined?(name, false)
          part = const_get(name, false)
          next unless part.respond_to?(:install)
          begin
            part.install
          rescue StandardError, SystemStackError => e
            ok = false
            Reloaded::Log.exception("Hidden Power's #{name} couldn't start", e, :hidden_power)
          end
        end
        return ok
      end

      #------------------------------------------------------------------------
      # Types
      #------------------------------------------------------------------------
      # The pool in the game's order (a type the game hasn't got is left out)
      # (kept once the game's types are there; asked before they load, it's
      # empty and kept for nothing)
      def pool
        return @pool if @pool
        return [] unless game_types?
        list = STANDARD.select { |t| GameData::Type.exists?(t) }.sort_by { |t| GameData::Type.get(t).id_number }
        @pool = list unless list.empty?
        return list
      end

      # Its own generator: rolls never move the global one a seeded
      # randomizer may be using
      def rng
        @rng ||= Random.new
      end

      # The game's types are there (not in a test's stand-ins)
      def game_types?
        return defined?(::GameData::Type) && ::GameData::Type.respond_to?(:exists?) && ::GameData::Type.respond_to?(:get)
      end

      # A new type; never `except` (a reroll)
      def roll(except = nil)
        list = except ? pool - [normal(except)] : pool
        list = pool if list.empty?
        return list.empty? ? nil : list[rng.rand(list.length)]
      end

      # A stored value as a type id: PIF's altar stores a number, KIF's
      # import a String; a type the game doesn't have is nil
      def normal(value)
        return nil if value.nil? || !game_types?
        value = value.to_sym if value.is_a?(String)
        return nil unless GameData::Type.exists?(value)
        return GameData::Type.get(value).id
      rescue StandardError
        return nil
      end

      def type_name(type)
        t = normal(type)
        return _INTL("Neutral") if t == NEUTRAL
        return t ? GameData::Type.get(t).name : "?"
      end

      #------------------------------------------------------------------------
      # A Pokémon's type and power
      #------------------------------------------------------------------------
      def pokemon?(obj)
        return defined?(::Pokemon) && obj.is_a?(::Pokemon)
      end

      # Unown, or a fusion with Unown
      def unown?(pkmn)
        return false unless pkmn.respond_to?(:isSpecies?)
        return true if pkmn.isSpecies?(:UNOWN)
        return pkmn.respond_to?(:isFusion?) && pkmn.isFusion? && pkmn.isFusionOf(:UNOWN)
      rescue StandardError
        return false
      end

      # The researcher and the plates can change it: not an Egg, not Unown
      def changeable?(pkmn)
        return false unless pkmn
        return false if pkmn.respond_to?(:egg?) && pkmn.egg?
        return !unown?(pkmn)
      end

      # The type, filling one a Pokémon hasn't got yet (an old import)
      def type_of(pkmn)
        pkmn = pkmn.pokemon if !pokemon?(pkmn) && pkmn.respond_to?(:pokemon)
        return nil unless pkmn && pkmn.respond_to?(:hiddenPowerType)
        t = normal(pkmn.hiddenPowerType)
        return t if t && (pool.include?(t) || t == NEUTRAL)
        fill(pkmn)
        return normal(pkmn.hiddenPowerType)
      end

      # PIF's power from the IVs (generation 5: 30 to 70; 6 on: the move's)
      def power_of(pkmn)
        iv = pkmn.respond_to?(:iv) ? pkmn.iv : nil
        return 60 unless iv.is_a?(Hash) && ::Settings::MECHANICS_GENERATION <= 5
        bits = ((iv[:HP].to_i & 2) >> 1) | (iv[:ATTACK].to_i & 2) | ((iv[:DEFENSE].to_i & 2) << 1) |
               ((iv[:SPEED].to_i & 2) << 2) | ((iv[:SPECIAL_ATTACK].to_i & 2) << 3) | ((iv[:SPECIAL_DEFENSE].to_i & 2) << 4)
        return POWER_MIN + (POWER_MAX - POWER_MIN) * bits / 63
      end

      # What PIF would give it from its IVs (PIF's own code, this hook
      # stepping aside)
      def iv_type(pkmn)
        @raw = true
        return normal(pbHiddenPower(pkmn)[0])
      rescue StandardError
        return nil
      ensure
        @raw = false
      end

      def raw?
        return @raw ? true : false
      end

      #------------------------------------------------------------------------
      # Moves (out of battle: the Summary, the Party Screen, the TM Vault)
      #------------------------------------------------------------------------
      def hidden_power_move?(move)
        id = move.respond_to?(:id) ? move.id : move
        return false if id.nil?
        @hp_moves ||= {}
        return @hp_moves[id] if @hp_moves.key?(id)
        data = GameData::Move.try_get(id)
        return false unless data                 # (not kept: the game's data may not be loaded yet)
        return @hp_moves[id] = data.function_code.to_s == FUNCTION
      rescue StandardError
        return false
      end

      def move_type(pkmn, move)
        id = move.respond_to?(:id) ? move.id : move
        if pkmn && hidden_power_move?(id)
          t = type_of(pkmn)
          return t if t
        end
        return move.type if move.respond_to?(:type) && !move.is_a?(Symbol)
        return GameData::Move.get(id).type
      end

      # Hidden Power's power is the Pokémon's own (generation 5); other moves'
      # are the move's
      def move_power(pkmn, move)
        id = move.respond_to?(:id) ? move.id : move
        return power_of(pkmn) if pkmn && hidden_power_move?(id) && ::Settings::MECHANICS_GENERATION <= 5
        return move.base_damage if move.respond_to?(:base_damage)
        return GameData::Move.get(id).base_damage
      end

      #------------------------------------------------------------------------
      # Changing it
      #------------------------------------------------------------------------
      # Sets the type (Unown's neutral one stays unless force). Returns the
      # type it had, or nil when nothing changed.
      def set(pkmn, type, how = :set, force = false)
        to = normal(type)
        return nil unless pkmn && to
        return nil if unown?(pkmn) && !force
        from = type_of(pkmn)
        return nil if from == to
        pkmn.hiddenPowerType = to
        remember_fused(pkmn)
        Reloaded::Events.emit(:hidden_power_changed, :pokemon => pkmn, :from => from, :to => to, :how => how)
        return from || to
      end

      # A random new type, never the one it has. Returns [from, to], or nil.
      def reroll(pkmn)
        return nil unless changeable?(pkmn)
        from = type_of(pkmn)
        to = roll(from)
        set(pkmn, to, :reroll)
        return [from, to]
      end

      #------------------------------------------------------------------------
      # New Pokémon, old saves
      #------------------------------------------------------------------------
      # Pokemon#initialize: everyone's own, Unown's neutral
      def on_new(pkmn)
        t = unown?(pkmn) ? NEUTRAL : roll
        pkmn.hiddenPowerType = t if t && pkmn.respond_to?(:hiddenPowerType=)
      end

      # One without a type of the 17 (or Unown's): its IVs' when that's one
      # of them, else a roll. Unown: neutral.
      def fill(pkmn)
        return unless pkmn.respond_to?(:hiddenPowerType=)
        now = normal(pkmn.hiddenPowerType)
        if unown?(pkmn)
          pkmn.hiddenPowerType = NEUTRAL unless now == NEUTRAL
          return
        end
        if now && pool.include?(now)
          pkmn.hiddenPowerType = now unless pkmn.hiddenPowerType == now     # a number or a String made a type id
          return
        end
        t = iv_type(pkmn)
        t = roll unless pool.include?(t)
        pkmn.hiddenPowerType = t if t
      end

      # Every Pokémon in the save: the party, the boxes, the Day Care, and
      # the two a fusion gives back
      def each_saved
        list = []
        list.concat(Array($Trainer.party)) if $Trainer.respond_to?(:party)
        st = $PokemonStorage
        if st && st.respond_to?(:maxBoxes)
          st.maxBoxes.times do |b|
            next unless st[b]
            st.maxPokemon(b).times { |i| (pk = st[b, i]) && list << pk }
          end
        end
        Array($PokemonGlobal.respond_to?(:daycare) ? $PokemonGlobal.daycare : nil).each { |slot| list << slot[0] if slot.is_a?(Array) && slot[0] }
        list.each do |pk|
          next unless pokemon?(pk)
          yield pk
          [:original_head, :original_body].each do |part|
            sub = pk.respond_to?(part) ? pk.send(part) : nil
            yield sub if pokemon?(sub)
          end
        end
      end

      def fill_save
        return 0 if pool.empty?
        filled = 0
        each_saved do |pk|
          t = normal(pk.hiddenPowerType)
          next if t && (unown?(pk) ? t == NEUTRAL : pool.include?(t)) && pk.hiddenPowerType == t
          fill(pk)
          filled += 1
        end
        Reloaded::Log.info("Hidden Power: #{filled} Pokémon given their type", :hidden_power) if filled > 0
        return filled
      rescue StandardError => e
        Reloaded::Log.exception("Hidden Power couldn't check this save's Pokémon", e, :hidden_power)
        return 0
      end

      #------------------------------------------------------------------------
      # Fusions: a pair's type
      #------------------------------------------------------------------------
      def pairs_of(pkmn)
        h = pkmn ? pkmn.instance_variable_get(PAIRS) : nil
        return h.is_a?(Hash) ? h : {}
      end

      # The pair's own roll: the same two Pokémon always give the same type,
      # whichever is the head
      def pair_roll(a, b)
        ids = [a.personalID.to_i, b.personalID.to_i].sort
        return pool[Zlib.crc32("#{ids[0]}-#{ids[1]}") % pool.length]
      end

      def pair_type(head, body)
        return nil unless head && body
        t = normal(pairs_of(body)[head.personalID]) || normal(pairs_of(head)[body.personalID])
        return t || pair_roll(head, body)
      end

      # Each part remembers the fusion's type for its partner (a new Hash:
      # a fused Pokémon and its parts share theirs, made by clone)
      def remember(head, body, type)
        return unless head && body && type
        head.instance_variable_set(PAIRS, pairs_of(head).merge(body.personalID => type))
        body.instance_variable_set(PAIRS, pairs_of(body).merge(head.personalID => type))
      end

      def remember_fused(fusion)
        return unless fusion.respond_to?(:original_head) && fusion.respond_to?(:isFusion?) && fusion.isFusion?
        remember(fusion.original_head, fusion.original_body, normal(fusion.hiddenPowerType))
      rescue StandardError
        nil
      end

      # Fused: the pair's type (Unown's neutral). PIF sets the IVs before
      # the fused species, so Unown is looked for in the two parts.
      def on_fused(fusion)
        head = fusion.original_head
        body = fusion.original_body
        return unless head && body
        fusion.hiddenPowerType = unown?(head) || unown?(body) || unown?(fusion) ? NEUTRAL : pair_type(head, body)
        remember(head, body, fusion.hiddenPowerType)
      end

      #------------------------------------------------------------------------
      # The Endgame Challenge's Shedproofing (KIF::Endgame.tune_team): the
      # type its counter to a Wonder Guard party needs, worked out as it does
      #------------------------------------------------------------------------
      def need(party)
        fairy = dark = fire = false
        Array(party).each do |p|
          next unless p && (p.ability_id rescue nil) == :WONDERGUARD
          fairy = true if p.hasType?(:DARK) && p.hasType?(:GHOST)
          dark = true if p.hasType?(:NORMAL) && p.hasType?(:GHOST)
          fire = true if p.hasType?(:BUG) && p.hasType?(:STEEL)
        end
        list = [fire && :FIRE, dark && :DARK, fairy && :FAIRY].select { |t| t }
        return list.length == 1 ? list[0] : nil
      end

      def knows_hidden_power?(pkmn)
        return Array(pkmn.moves).any? { |m| m && hidden_power_move?(m.id) }
      end

      def after_tune_team(party, knew)
        t = need($Trainer ? $Trainer.party : [])
        return unless t
        Array(party).each_with_index do |p, i|
          p.hiddenPowerType = t if p && knows_hidden_power?(p) && !knew[i]
        end
      end

      #------------------------------------------------------------------------
      # Hooks (core: Hidden Power is always on)
      #------------------------------------------------------------------------
      def install
        h = Reloaded::Hooks
        h.prepend(nil, ::Pokemon, NewPokemon, :id => :hidden_power_new) if defined?(::Pokemon)
        # PIF's type and power: a stored type answers at once; with none
        # passed (the researcher, the Debug menu) the Pokémon's own
        if Object.private_method_defined?(:pbHiddenPower) || Object.method_defined?(:pbHiddenPower)
          h.around(nil, Object, :pbHiddenPower, :id => :hidden_power_type) do |original, *args|
            pkmn = args[0]
            next original.call(*args) if Reloaded::HiddenPower.raw? || pkmn.nil?
            t = Reloaded::HiddenPower.normal(args[1]) || Reloaded::HiddenPower.type_of(pkmn)
            next original.call(*args) unless t
            [t, Reloaded::HiddenPower.power_of(pkmn)]
          end
        end
        if defined?(::PokemonFusionScene) && ::PokemonFusionScene.method_defined?(:setFusionIVs)
          h.around(nil, ::PokemonFusionScene, :setFusionIVs, :id => :hidden_power_fused) do |original, *args|
            ret = original.call(*args)
            fusion = original.receiver.instance_variable_get(:@pokemon1)
            Reloaded::HiddenPower.on_fused(fusion) if fusion
            ret
          end
        end
        if Object.private_method_defined?(:unfuseCore) || Object.method_defined?(:unfuseCore)
          h.around(nil, Object, :unfuseCore, :id => :hidden_power_unfused) do |original, *args|
            Reloaded::HiddenPower.remember_fused(args[0]) if args[0]
            original.call(*args)
          end
        end
        if defined?(::KIF::Endgame) && ::KIF::Endgame.respond_to?(:tune_team)
          h.around(nil, ::KIF::Endgame.singleton_class, :tune_team, :id => :hidden_power_shedproofing) do |original, *args|
            trainer = args[0]
            party = trainer.respond_to?(:party) ? Array(trainer.party) : []
            knew = party.map { |p| p ? Reloaded::HiddenPower.knows_hidden_power?(p) : false }
            ret = original.call(*args)
            Reloaded::HiddenPower.after_tune_team(party, knew)
            ret
          end
        end
      end
    end

    # Every Pokémon made gets its type (a prepend: Pokémon are made often)
    module NewPokemon
      def initialize(*args, &block)
        super
        begin
          Reloaded::HiddenPower.on_new(self)
        rescue StandardError => e
          Reloaded::HiddenPower.new_failed(e)
        end
      end
    end

    class << self
      def new_failed(error)
        return if @new_failed
        @new_failed = true
        Reloaded::Log.exception("Hidden Power couldn't give a new Pokémon its type", error, :hidden_power)
      end
    end
  end
end
