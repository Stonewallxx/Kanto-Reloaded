# encoding: utf-8
#==============================================================================
# Kanto Reloaded: what the Battle Menu reads from a battle
#==============================================================================
# Reader: the field (weather, terrain, rooms, each side's screens and
# hazards, Future Sight and Wish), a Pokémon's effects, its stat stages and
# their multipliers, and how a move fares against a foe. Read when a screen
# or the Field Strip is drawn, never per frame. Only what the battle shows
# (his pick, Q12): turns for the field, screens, Taunt, Encore, Disable and
# trapping; confusion and sleep without them.
#
# Notes: what the battle has shown about a foe (cody's Battle Info idea,
# rebuilt): its ability once its pop-up shows, its held item once it's used
# or a message about that Pokémon names it (cody's took any message naming
# the item, so your Leftovers showed a foe's too), the moves it has used.
# Kept on the battle and gone with it. A disguised foe (Illusion) shows as
# the Pokémon it copies until the disguise breaks.
#==============================================================================

module Reloaded
  module BattleMenu
    module Reader
      STATS = [[:ATTACK, "Attack"], [:DEFENSE, "Defense"], [:SPECIAL_ATTACK, "Sp. Atk"], [:SPECIAL_DEFENSE, "Sp. Def"],
               [:SPEED, "Speed"], [:ACCURACY, "Accuracy"], [:EVASION, "Evasion"]].freeze
      # [effect, words, type for its colour]
      FIELD_TIMED = [[:TrickRoom, "Trick Room", :PSYCHIC], [:Gravity, "Gravity", :PSYCHIC], [:WonderRoom, "Wonder Room", :PSYCHIC],
                     [:MagicRoom, "Magic Room", :PSYCHIC], [:MudSportField, "Mud Sport", :GROUND],
                     [:WaterSportField, "Water Sport", :WATER], [:FairyLock, "Fairy Lock", :FAIRY]].freeze
      SIDE_TIMED = [[:Reflect, "Reflect", :PSYCHIC], [:LightScreen, "Light Screen", :PSYCHIC], [:AuroraVeil, "Aurora Veil", :ICE],
                    [:Tailwind, "Tailwind", :FLYING], [:Safeguard, "Safeguard", :NORMAL], [:Mist, "Mist", :ICE],
                    [:LuckyChant, "Lucky Chant", :NORMAL], [:Rainbow, "Rainbow", :FAIRY], [:SeaOfFire, "Sea of Fire", :FIRE],
                    [:Swamp, "Swamp", :GRASS]].freeze
      HAZARDS = [[:StealthRock, "Stealth Rock", :ROCK], [:Spikes, "Spikes", :GROUND], [:ToxicSpikes, "Toxic Spikes", :POISON],
                 [:StickyWeb, "Sticky Web", :BUG]].freeze
      WEATHER_TYPE = { :Sun => :FIRE, :HarshSun => :FIRE, :Rain => :WATER, :HeavyRain => :WATER, :Sandstorm => :ROCK,
                       :Hail => :ICE, :StrongWinds => :FLYING, :ShadowSky => :GHOST }.freeze
      TERRAIN_TYPE = { :Electric => :ELECTRIC, :Grassy => :GRASS, :Misty => :FAIRY, :Psychic => :PSYCHIC }.freeze
      # A Pokémon's effects: [effect, words, how it shows, type for its colour]
      #   :turns  a count down, shown     :on     there (no turns)
      #   :index  set to a Pokémon's index (-1 when not)   :count  a count (Stockpile xN)
      EFFECTS = [[:Taunt, "Taunt", :turns, :DARK], [:Confusion, "Confused", :on, nil], [:Attract, "Infatuated", :index, :NORMAL],
                 [:LeechSeed, "Leech Seed", :index, :GRASS], [:Substitute, "Substitute", :on, :NORMAL],
                 [:HealBlock, "Heal Block", :turns, :PSYCHIC], [:Embargo, "Embargo", :turns, :DARK],
                 [:MagnetRise, "Magnet Rise", :turns, :ELECTRIC], [:Telekinesis, "Telekinesis", :turns, :PSYCHIC],
                 [:ThroatChop, "Throat Chop", :turns, :DARK], [:PerishSong, "Perish Song", :turns, :NORMAL],
                 [:Yawn, "Drowsy", :on, :NORMAL], [:Torment, "Torment", :on, :DARK], [:Curse, "Curse", :on, :GHOST],
                 [:Nightmare, "Nightmare", :on, :GHOST], [:Ingrain, "Ingrain", :on, :GRASS], [:AquaRing, "Aqua Ring", :on, :WATER],
                 [:FocusEnergy, "Focus Energy", :on, :NORMAL], [:LaserFocus, "Laser Focus", :on, :NORMAL],
                 [:Charge, "Charge", :on, :ELECTRIC], [:Stockpile, "Stockpile", :count, :NORMAL],
                 [:MeanLook, "Can't Escape", :index, :NORMAL], [:SmackDown, "Smack Down", :on, :ROCK],
                 [:Foresight, "Foresight", :on, :NORMAL], [:MiracleEye, "Miracle Eye", :on, :PSYCHIC],
                 [:Minimize, "Minimize", :on, :NORMAL], [:Imprison, "Imprison", :on, :PSYCHIC], [:Powder, "Powder", :on, :BUG],
                 [:Electrify, "Electrify", :on, :ELECTRIC], [:Uproar, "Uproar", :turns, :NORMAL],
                 [:Transform, "Transformed", :on, :NORMAL]].freeze
      # Moves that tie up a Pokémon: [effect, its move effect, tag]
      MOVE_EFFECTS = [[:Trapping, :TrappingMove, "TRAPPED"], [:Encore, :EncoreMove, "ENCORE"],
                      [:Disable, :DisableMove, "DISABLED"]].freeze

      module_function

      def const(name)
        return defined?(::PBEffects) && ::PBEffects.const_defined?(name) ? ::PBEffects.const_get(name) : nil
      end

      def eff(effects, name)
        i = const(name)
        return i && effects ? effects[i] : nil
      end

      # The player's side (a partner trainer's Pokémon too: their colours)
      def own?(battler)
        return !battler.opposes?(0)
      end

      # Whose things the player knows in full: their own, not a partner's
      def known?(battle, battler)
        return battle.pbOwnedByPlayer?(battler.index) if battle.respond_to?(:pbOwnedByPlayer?)
        return own?(battler)
      rescue StandardError
        return own?(battler)
      end

      # cody's multiplier (Battle Info): 2/(2-n) or (2+n)/2; 3s for accuracy
      def multiplier(stage, acc = false)
        stage = [[stage.to_i, -6].max, 6].min
        base = acc ? 3 : 2
        return stage >= 0 ? (base + stage).to_f / base : base.to_f / (base - stage)
      end

      def mult_text(m)
        s = format("%.2f", m).sub(/0+\z/, "").sub(/\.\z/, "")
        return "x#{s}"
      end

      # [[words, turns or nil, :field / 0 yours / 1 the foe's, type], ...]:
      # the whole field's first, then each side's
      def field_items(battle)
        out = []
        f = battle.field
        if f.weather && f.weather != :None
          out << [weather_name(f.weather), f.weatherDuration.to_i > 0 ? f.weatherDuration.to_i : nil, :field, WEATHER_TYPE[f.weather]]
        end
        if f.terrain && f.terrain != :None
          out << [terrain_name(f.terrain), f.terrainDuration.to_i > 0 ? f.terrainDuration.to_i : nil, :field, TERRAIN_TYPE[f.terrain]]
        end
        FIELD_TIMED.each do |k, words, t|
          n = eff(f.effects, k).to_i
          out << [_INTL(words), n, :field, t] if n > 0
        end
        [0, 1].each do |side|
          e = battle.sides[side].effects
          SIDE_TIMED.each do |k, words, t|
            n = eff(e, k).to_i
            out << [_INTL(words), n, side, t] if n > 0
          end
          HAZARDS.each do |k, words, t|
            v = eff(e, k)
            next unless v && v != 0
            out << [v.is_a?(Integer) && v > 1 ? "#{_INTL(words)} x#{v}" : _INTL(words), nil, side, t]
          end
        end
        battle.positions.each_with_index do |pos, i|
          next unless pos
          fs = eff(pos.effects, :FutureSightCounter).to_i
          if fs > 0
            mv = eff(pos.effects, :FutureSightMove)
            out << [move_name(mv) || _INTL("Future Sight"), fs, i & 1, move_type(mv) || :PSYCHIC]
          end
          w = eff(pos.effects, :Wish).to_i
          out << [_INTL("Wish"), w, i & 1, :NORMAL] if w > 0
        end
        return out
      rescue StandardError => e
        Reloaded::Log.exception("Battle Menu: reading the field", e, :battle_menu)
        return out || []
      end

      def weather_name(id)
        return (GameData::BattleWeather.get(id).name rescue id.to_s)
      end

      def terrain_name(id)
        return _INTL("{1} Terrain", (GameData::BattleTerrain.get(id).name rescue id.to_s))
      end

      def move_name(id)
        return id ? (GameData::Move.get(id).name rescue nil) : nil
      end

      def move_type(id)
        return id ? (GameData::Move.get(id).type rescue nil) : nil
      end

      # A Pokémon's effects: [[words, turns or nil, tag or nil, type], ...]
      def effects(battler)
        e = battler.effects
        out = []
        MOVE_EFFECTS.each do |k, mk, tag|
          n = eff(e, k).to_i
          next unless n > 0
          mv = eff(e, mk)
          out << [move_name(mv) || _INTL(tag.capitalize), n, _INTL(tag), move_type(mv)]
        end
        EFFECTS.each do |k, words, how, t|
          v = eff(e, k)
          case how
          when :turns then out << [_INTL(words), v.to_i, nil, t] if v.to_i > 0
          when :on then out << [_INTL(words), nil, nil, t] if v.is_a?(Integer) ? v > 0 : v
          when :index then out << [_INTL(words), nil, nil, t] if v.is_a?(Integer) && v >= 0
          when :count then out << ["#{_INTL(words)} x#{v.to_i}", nil, nil, t] if v.to_i > 0
          end
        end
        return out
      rescue StandardError => ex
        Reloaded::Log.exception("Battle Menu: reading a Pokémon's effects", ex, :battle_menu)
        return out || []
      end

      #------------------------------------------------------------------------
      # Matchups (as the foe looks: a disguise's types)
      #------------------------------------------------------------------------
      def types_seen(battler)
        d = Notes.disguise(battler)
        if d
          t = [d.type1, d.type2].compact.uniq rescue [d.type1]
          return t
        end
        return battler.pbTypes(true)
      rescue StandardError
        return [battler.type1, battler.type2].compact.uniq
      end

      # The move's effectiveness against the foe as a multiplier (0, 0.25 ...
      # 4), or nil for a status move. Its type as the battle works it out
      # (Electrify, Ion Deluge, KR's Hidden Power), the foe's types as seen;
      # an ability that makes it immune counts once the battle has shown it.
      def effectiveness(move, user, target)
        return nil if move.nil? || move.statusMove?
        type = calc_type(move, user)
        return nil unless type
        val = if Notes.disguise(target) then Effectiveness.calculate(type, *types_seen(target))
              else (move.pbCalcTypeMod(type, user, target) rescue Effectiveness.calculate(type, *types_seen(target)))
              end
        val = Effectiveness::INEFFECTIVE if known_immunity?(move, type, user, target)
        return val.to_f / Effectiveness::NORMAL_EFFECTIVE
      rescue StandardError
        return nil
      end

      # pbCalcType also sets the move's power boost: kept as it was
      def calc_type(move, user)
        boost = move.instance_variable_get(:@powerBoost)
        type = move.pbCalcType(user)
        move.instance_variable_set(:@powerBoost, boost)
        return type
      rescue StandardError
        return move.type
      end

      # Abilities that make their holder immune to a type (cody's list,
      # Effectiveness.rb)
      TYPE_IMMUNE = { :FLASHFIRE => :FIRE, :LIGHTNINGROD => :ELECTRIC, :MOTORDRIVE => :ELECTRIC,
                      :VOLTABSORB => :ELECTRIC, :SAPSIPPER => :GRASS, :STORMDRAIN => :WATER,
                      :WATERABSORB => :WATER, :DRYSKIN => :WATER, :LEVITATE => :GROUND }.freeze

      def known_immunity?(move, type, user, target)
        return false if user.respond_to?(:hasMoldBreaker?) && user.hasMoldBreaker?
        ab = target.ability_id
        return false unless ab && TYPE_IMMUNE[ab] == type
        return false if ab == :LEVITATE && move.respond_to?(:hitsFlyingTargets?) && move.hitsFlyingTargets?
        return Notes.ability_known?(target.battle, target)
      rescue StandardError
        return false
      end

      # "x4", "x1/2", "x0"
      def mult_label(m)
        return "x0" if m == 0
        return "x1/#{(1 / m).round}" if m < 1
        return "x#{m.round}"
      end

      # A foe's types against every attacking type: { :weak, :resist, :immune }
      # of [[type, multiplier], ...], the biggest first
      def profile(target)
        types = types_seen(target)
        out = { :weak => [], :resist => [], :immune => [] }
        GameData::Type.each do |t|
          next if t.pseudo_type || t.id == :SHADOW || t.id == :QMARKS
          m = Effectiveness.calculate(t.id, *types).to_f / Effectiveness::NORMAL_EFFECTIVE
          if m == 0 then out[:immune] << [t.id, m]
          elsif m < 1 then out[:resist] << [t.id, m]
          elsif m > 1 then out[:weak] << [t.id, m]
          end
        end
        out.each_value { |l| l.sort_by! { |k, m| [-((m - 1).abs), (GameData::Type.get(k).id_number rescue 0)] } }
        return out
      rescue StandardError
        return { :weak => [], :resist => [], :immune => [] }
      end

      # The Pokémon in the battle, in tab order: yours first (by position),
      # then the foes
      def battlers(battle)
        list = battle.battlers.select { |b| b && !b.fainted? && b.pokemon }
        return list.select { |b| own?(b) } + list.reject { |b| own?(b) }
      end
    end

    #--------------------------------------------------------------------------
    # What the battle has shown about the foes
    #--------------------------------------------------------------------------
    module Notes
      KEY = :@kr_battle_notes

      module_function

      # { :abilities => { pokemon id => [ability names shown] },
      #   :items => { pokemon id => item id named }, :moves => { pokemon id => [move ids] } }
      def of(battle)
        n = battle.instance_variable_get(KEY)
        battle.instance_variable_set(KEY, n = { :abilities => {}, :items => {}, :moves => {} }) unless n
        return n
      end

      def key(battler)
        return battler.pokemon ? battler.pokemon.object_id : battler.index
      end

      # The Pokémon a foe is disguised as (Illusion), or nil
      def disguise(battler)
        i = Reader.const(:Illusion)
        d = i && battler && !Reader.own?(battler) ? battler.effects[i] : nil
        return d && !battler.pokemon.equal?(d) ? d : nil
      rescue StandardError
        return nil
      end

      # The pop-up showed an ability (its name: the main one, or a mod's innate)
      def note_ability(battler, name = nil)
        return unless battler
        name ||= battler.abilityName
        list = (of(battler.battle)[:abilities][key(battler)] ||= [])
        list << name.to_s unless name.to_s.empty? || list.include?(name.to_s)
      rescue StandardError
        nil
      end

      def ability_shown?(battle, battler, name)
        return (of(battle)[:abilities][key(battler)] || []).include?(name.to_s)
      end

      def ability_known?(battle, battler)
        return true if Reader.known?(battle, battler)
        return false if disguise(battler)
        return ability_shown?(battle, battler, battler.abilityName)
      end

      def note_item(battler, item = nil)
        return unless battler
        item ||= battler.item_id
        of(battler.battle)[:items][key(battler)] = item if item
      rescue StandardError
        nil
      end

      # The item's words: yours always; a foe's once named ("None" once it's
      # used up), else nil
      def item_text(battle, battler)
        return battler.item ? battler.itemName : _INTL("None") if Reader.known?(battle, battler)
        seen = of(battle)[:items][key(battler)]
        return nil if seen.nil?
        return battler.itemName if battler.item && battler.item_id == seen
        return _INTL("None") unless battler.item
        return nil
      end

      def note_move(battler, move_id)
        return unless battler && move_id
        list = (of(battler.battle)[:moves][key(battler)] ||= [])
        list << move_id unless list.include?(move_id)
      rescue StandardError
        nil
      end

      def moves_used(battle, battler)
        return of(battle)[:moves][key(battler)] || []
      end

      # A message about one Pokémon (its name in it) naming its item or ability
      def note_message(battle, msg)
        return unless msg.is_a?(String) && !msg.empty?
        battle.battlers.each do |b|
          next if b.nil? || b.pokemon.nil? || Reader.known?(battle, b)
          next unless msg.include?(b.pbThis) || msg.include?(b.pbThis(true))
          note_item(b) if b.item && !b.itemName.to_s.empty? && msg.include?(b.itemName.to_s)
          note_ability(b) if b.ability && !b.abilityName.to_s.empty? && msg.include?(b.abilityName.to_s)
        end
      rescue StandardError
        nil
      end

      # Other mods' ability rows (KIF Battle Info's providers: KIF-ER's
      # innates): [[label, name or nil (not seen), seen as revealed], ...]
      def other_abilities(battle, battler)
        return [] unless defined?(::KIF::BattleInfo) && ::KIF::BattleInfo.respond_to?(:ability_providers)
        known = Reader.known?(battle, battler)
        out = []
        ::KIF::BattleInfo.ability_providers.each do |id, prov|
          begin
            Array(prov.call(battle, battler)).each do |e|
              name = e[:name] || (e[:ability] && (GameData::Ability.get(e[:ability]).name rescue e[:ability].to_s))
              seen = known || e[:known] != false || ability_shown?(battle, battler, name)
              out << [(e[:label] || "ABILITY").to_s.upcase, seen ? name.to_s : nil]
            end
          rescue StandardError => ex
            Reloaded::Log.warning_once("Battle Menu: #{id}'s ability rows failed (#{ex.class}: #{ex.message})", :battle_menu)
          end
        end
        return out
      end

      # The pop-up, items used up or set off, and messages: noted after the
      # game's own code runs (nothing in the battle changes)
      def install
        h = Reloaded::Hooks
        return unless defined?(::PokeBattle_Battle)
        if ::PokeBattle_Battle.method_defined?(:pbShowAbilitySplash)
          h.around(FEATURE, ::PokeBattle_Battle, :pbShowAbilitySplash, :id => :battle_menu_note_splash) do |original, *args|
            Reloaded::BattleMenu::Notes.note_ability(args[0], args[3])
            original.call(*args)
          end
        end
        [:pbDisplay, :pbDisplayPaused, :pbDisplayBrief].each do |m|
          next unless ::PokeBattle_Battle.method_defined?(m)
          h.around(FEATURE, ::PokeBattle_Battle, m, :id => :"battle_menu_note_#{m}") do |original, *args|
            battle = original.receiver
            Reloaded::BattleMenu::Notes.note_message(battle, args[0])
            Reloaded::BattleMenu::TurnLog.message(battle, args[0]) if defined?(Reloaded::BattleMenu::TurnLog)
            original.call(*args)
          end
        end
        return unless defined?(::PokeBattle_Battler)
        [:pbHeldItemTriggered, :pbConsumeItem].each do |m|
          next unless ::PokeBattle_Battler.method_defined?(m)
          h.around(FEATURE, ::PokeBattle_Battler, m, :id => :"battle_menu_note_#{m}") do |original, *args|
            b = original.receiver
            Reloaded::BattleMenu::Notes.note_item(b, m == :pbHeldItemTriggered && args[0].is_a?(Symbol) ? args[0] : nil)
            original.call(*args)
          end
        end
      end
    end
  end
end
