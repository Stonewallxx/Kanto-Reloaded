# encoding: utf-8
#==============================================================================
# Kanto Reloaded: how well a move does against a Pokémon, as the player knows it
#==============================================================================
# One helper for Effectiveness (EBDX)'s Fight menu and Battle Info's
# Matchup tab. cody's rules (C-BATTLE-01_Effectiveness, credited)
# on what the battle has shown (his pick, 2026-10-30):
#
#   the maths     the battle's own (pbCalcType, pbCalcTypeMod: KIF's type
#                 buffs, Scrappy, Ring Target, grounded Flying types,
#                 Freeze-Dry, Weather Ball...) on a copy of the target that
#                 holds only what the player knows: a foe's item once it's
#                 used or named (Air Balloon says so when it comes in), its
#                 abilities once their pop-up showed (Double Abilities'
#                 second and KIF-ER's innates too), an Illusion's disguise's
#                 types. Your own Pokémon are known in full.
#   immunities    a known ability that makes its holder immune (Levitate,
#                 Flash Fire, the Absorbs, Soundproof, Bulletproof, Wonder
#                 Guard, Telepathy for your partner, KIF-ER's), unless the
#                 user has Mold Breaker; Air Balloon, Magnet Rise and
#                 Telekinesis against Ground. KIF's own list is asked too
#                 (KIF::MoveEffect.known_immunity?, which KIF-ER extends), as
#                 its Foe Info "As seen" has it. Mods add theirs:
#                   Reloaded::Matchup.immunity(:EARTHEATER, :GROUND)
#                   Reloaded::Matchup.immunity(:MYABILITY) { |move, type, user, target, value| ... }
#   fixed damage  Seismic Toss, Super Fang, the OHKO moves...: x1, or x0
#                 where the type can't hit
#   status moves  nothing, but Thunder Wave: x0 where it fails
#
# Nothing in the battle changes: the move's values are put back after its
# type is worked out, and the user and target are copies (the game's
# ability checks leave marks on the battler they ask).
#==============================================================================

module Reloaded
  module Matchup
    NORMAL = 8                                   # Effectiveness::NORMAL_EFFECTIVE: x1
    ANNOUNCED_ITEMS = [:AIRBALLOON].freeze       # the battle says so when it comes in
    LEVELS = [:x0, :x1_4, :x1_2, :x1, :x2, :x4].freeze
    # cody's (Effectiveness.rb) and KIF-ER's abilities that block a type
    TYPE_IMMUNE = { :FLASHFIRE => :FIRE, :LIGHTNINGROD => :ELECTRIC, :MOTORDRIVE => :ELECTRIC, :VOLTABSORB => :ELECTRIC,
                    :SAPSIPPER => :GRASS, :STORMDRAIN => :WATER, :WATERABSORB => :WATER, :DRYSKIN => :WATER,
                    :EARTHEATER => :GROUND, :AERODYNAMICS => :FLYING, :ICEDEW => :ICE, :MOUNTAINEER => :ROCK,
                    :POISONABSORB => :POISON, :HEATSINK => :FIRE, :WELLBAKEDBODY => :FIRE, :EVAPORATE => :WATER }.freeze
    GIFTED_TYPES = [:DARK, :GHOST, :BUG].freeze  # KIF-ER's Gifted Mind (KIFER::BatchJ::GIFTED_TYPES)

    @immunities = {}
    @strict = false

    class << self
      # While true KIF's Battle Info answers Foe Info "As seen", so KIF's
      # own list counts only what the battle has shown
      attr_reader :strict

      def boot
        register_defaults
        install
        return true
      end

      # A mod's ability that makes its holder immune: to a type, or when the
      # block says so (the holder's ability known and working)
      def immunity(ability, type = nil, &rule)
        raise ArgumentError, "Matchup.immunity needs a type or a block" unless type || rule
        @immunities[ability.to_sym] = rule || type.to_sym
        return true
      end

      def immunities
        return @immunities
      end

      def register_defaults
        TYPE_IMMUNE.each { |ability, type| immunity(ability, type) }
        immunity(:SOUNDPROOF) { |move| move.soundMove? }
        immunity(:BULLETPROOF) { |move| move.bombMove? }
        immunity(:WONDERGUARD) { |move, _t, _u, _tg, val| move.damagingMove? && !::Effectiveness.super_effective?(val) }
        immunity(:TELEPATHY) { |move, _t, user, target| move.damagingMove? && !target.opposes?(user) }
        # KIF-ER's
        immunity(:GIFTEDMIND) { |_m, type| gifted_types.include?(type) }
        [:AERIALIST, :DRAGONFLY].each do |id|
          immunity(id) { |move, type, _u, target| type == :GROUND && move.damagingMove? && !move.hitsFlyingTargets? && target.airborne? }
        end
        immunity(:WINDRIDER) { |move| kifer_list(:BatchG, :WIND_MOVES).include?(move.id) }
        immunity(:WEATHERCONTROL) { |move| kifer_list(:BatchH, :WEATHER_MOVES).include?(move.id) }
        immunity(:GOODASGOLD) { |move, _t, user| move.statusMove? && move.pbTarget(user).id != :AllBattlers }
      end

      def gifted_types
        list = kifer_list(:BatchJ, :GIFTED_TYPES)
        return list.empty? ? GIFTED_TYPES : list
      end

      def kifer_list(batch, name)
        return [] unless defined?(::KIFER) && ::KIFER.const_defined?(batch, false)
        mod = ::KIFER.const_get(batch, false)
        return mod.const_defined?(name, false) ? Array(mod.const_get(name, false)) : []
      end

      # KIF's Battle Info's Foe Info as "As seen" while KIF's list is asked
      def install
        return unless defined?(::KIF::BattleInfo) && ::KIF::BattleInfo.respond_to?(:show_all?)
        Reloaded::Hooks.prepend(nil, ::KIF::BattleInfo.singleton_class, StrictInfo, :id => :matchup_strict_foe_info)
      end

      #------------------------------------------------------------------------
      # A move against one Pokémon
      #------------------------------------------------------------------------
      # The effectiveness value (NORMAL is x1), or nil when nothing shows: a
      # status move (Thunder Wave aside), or one that can't be worked out
      def value(move, user, target)
        return nil if move.nil? || user.nil? || target.nil?
        return nil if move.statusMove? && move.id != :THUNDERWAVE
        return value_for(move, user.dup, target)
      end

      # (u: a copy of the user, made once for a whole Fight menu)
      def value_for(move, u, target)
        return nil if move.statusMove? && move.id != :THUNDERWAVE
        saved = move.instance_variables.map { |iv| [iv, move.instance_variable_get(iv)] }
        begin
          type = move.pbCalcType(u)
          tv = view(target.battle, target)
          val = move.pbCalcTypeMod(type, u, tv)
          val = ::Effectiveness::INEFFECTIVE if immune?(move, type, u, tv, val)
          return ::Effectiveness.ineffective?(val) ? val : nil if move.statusMove?   # Thunder Wave: fails, or shows nothing
          val = NORMAL if !::Effectiveness.ineffective?(val) && defined?(::PokeBattle_FixedDamageMove) && move.is_a?(::PokeBattle_FixedDamageMove)
          return val
        ensure
          saved.each { |iv, v| move.instance_variable_set(iv, v) }
          (move.instance_variables - saved.map(&:first)).each { |iv| move.remove_instance_variable(iv) }
        end
      rescue StandardError => e
        Reloaded::Log.warning_once("Matchup: a move's effectiveness couldn't be worked out (#{e.class}: #{e.message})", :core)
        return nil
      end

      # :x0, :x1_4, :x1_2, :x1, :x2 or :x4 (x8 counts as x4, x1/8 as x1/4)
      def level(val)
        return nil if val.nil?
        m = val.to_f / NORMAL
        return :x0 if m <= 0
        return :x4 if m >= 4
        return :x2 if m > 1
        return :x1_4 if m <= 0.25
        return :x1_2 if m < 1
        return :x1
      end

      # cody's words: x4, x2, x1, x1/2, x1/4, x0 (x8 and x1/8 with a third type)
      def text(val)
        m = val.to_f / NORMAL
        return "x0" if m == 0
        return "x1/#{(1 / m).round}" if m < 1
        return "x#{m.round}"
      end

      #------------------------------------------------------------------------
      # A move in the Fight menu
      #------------------------------------------------------------------------
      # Who it can hit, by the game's own pbMoveCanTarget?: [foes, allies];
      # your partner only for moves that hit several at once (his pick, Q7)
      def targets(battle, user, move)
        td = move.pbTarget(user)
        foes = []
        allies = []
        battle.battlers.each do |b|
          next if b.nil? || b.fainted? || b.index == user.index
          next unless battle.pbMoveCanTarget?(user.index, b.index, td)
          b.opposes?(user) ? foes << b : allies << b
        end
        allies = [] unless td.num_targets > 1
        return [foes, allies]
      end

      # One move's line: { :best => the best foe's value (nil: show nothing),
      # :per => [[battler, value, your partner?], ...], :warn => your partner
      # would be hurt }. u: a copy of the user (made here when not given)
      def summary(battle, user, move, u = nil)
        u ||= user.dup
        foes, allies = targets(battle, user, move)
        per = foes.map { |b| [b, value_for(move, u, b), false] } + allies.map { |b| [b, value_for(move, u, b), true] }
        vals = per.reject { |_b, _v, ally| ally }.map { |_b, v, _a| v }
        # a status move that works on any foe shows nothing (Thunder Wave)
        best = vals.empty? || vals.include?(nil) ? nil : vals.max
        warn = per.any? { |_b, v, ally| ally && v && !::Effectiveness.ineffective?(v) }
        return { :best => best, :per => per, :warn => warn }
      end

      #------------------------------------------------------------------------
      # What the player knows
      #------------------------------------------------------------------------
      # Your own Pokémon (not a partner trainer's: theirs are learnt as a foe's)
      def own?(battle, b)
        return battle.pbOwnedByPlayer?(b.index) if battle.respond_to?(:pbOwnedByPlayer?)
        return !b.opposes?(0)
      rescue StandardError
        return !b.opposes?(0)
      end

      def item_known?(battle, b)
        return true if own?(battle, b)
        id = b.item_id
        return true if id.nil? || ANNOUNCED_ITEMS.include?(id)
        notes = battle.instance_variable_get(Reloaded::BattleMenu::Notes::KEY)
        return notes ? notes[:items][Reloaded::BattleMenu::Notes.key(b)] == id : false
      end

      # Has the battle shown this ability of a foe's? Kanto Reloaded's notes
      # (the pop-up, messages), KIF's Battle Info's record, KIF-ER's
      def ability_shown?(battle, b, id)
        name = (GameData::Ability.try_get(id)&.name rescue nil)
        return true if name && Reloaded::BattleMenu::Notes.ability_shown?(battle, b, name)
        pk = b.pokemon
        return false unless pk
        cody = battle.instance_variable_get(:@cody_known_abilities)
        return true if cody.is_a?(Hash) && cody[pk.object_id] == id
        kifer = battle.instance_variable_get(:@kifer_as_known)
        return kifer.is_a?(Hash) && Array(kifer[pk.object_id]).include?(id)
      end

      # A copy of the target holding only what the player knows (read only:
      # it shares the battler's effects)
      def view(battle, target)
        return target if own?(battle, target)
        v = target.dup
        disguise = Reloaded::BattleMenu::Notes.disguise(target)
        v.instance_variable_set(:@item_id, nil) unless item_known?(battle, target)
        known = proc { |id| id && !disguise && ability_shown?(battle, target, id) }
        v.instance_variable_set(:@ability_id, nil) unless known.call(target.ability_id)
        a2 = target.instance_variable_get(:@kr_ability2_id)
        v.instance_variable_set(:@kr_ability2_id, nil) if a2 && !known.call(a2)
        innates = target.instance_variable_get(:@innate_ids)
        v.instance_variable_set(:@innate_ids, innates.select { |id| known.call(id) }) if innates.is_a?(Array) && !innates.empty?
        if disguise
          v.instance_variable_set(:@type1, disguise.type1)
          v.instance_variable_set(:@type2, disguise.type2)
        end
        return v
      end

      # The abilities a view holds (the main one, Double Abilities' second,
      # KIF-ER's innates)
      def abilities(v)
        list = [v.ability_id, v.instance_variable_get(:@kr_ability2_id)]
        innates = v.instance_variable_get(:@innate_ids)
        list.concat(innates) if innates.is_a?(Array)
        list.compact!
        list.uniq!
        return list
      end

      # Immune by what the player knows (tv: the target's view)
      def immune?(move, type, user, tv, val)
        return false if ::Effectiveness.ineffective?(val)
        if type == :GROUND && !move.hitsFlyingTargets? && tv.airborne?
          return true if tv.hasActiveItem?(:AIRBALLOON)
          return true if tv.effects[PBEffects::MagnetRise] > 0 || tv.effects[PBEffects::Telekinesis] > 0
          return true if tv.hasActiveAbility?(:LEVITATE) && !user.hasMoldBreaker?
        end
        return false if user.hasMoldBreaker?
        abilities(tv).each do |id|
          rule = @immunities[id]
          next unless rule && tv.hasActiveAbility?(id)
          return true if rule.is_a?(Symbol) ? rule == type : rule.call(move, type, user, tv, val)
        end
        return kif_immune?(move, type, user, tv, val)
      end

      # KIF's own list (KIF-ER adds its revealed innates to it), damaging
      # moves only: it counts Wonder Guard against Thunder Wave
      def kif_immune?(move, type, user, tv, val)
        return false if move.statusMove?
        return false unless defined?(::KIF::MoveEffect) && ::KIF::MoveEffect.respond_to?(:known_immunity?)
        @strict = true
        return ::KIF::MoveEffect.known_immunity?(move, type, user, tv, val) ? true : false
      rescue StandardError
        return false
      ensure
        @strict = false
      end
    end

    # KIF's Battle Info: Foe Info "As seen" while Kanto Reloaded asks
    module StrictInfo
      def show_all?
        return false if Reloaded::Matchup.strict
        return super
      end
    end
  end
end
