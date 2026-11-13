# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Trainer Control's Gym Rules (Tougher Trainers D)
#==============================================================================
# PIF Today: a gym battle starts on a plain field (the map's weather aside);
# conditions come only from moves and abilities, for a few turns.
#
# His picks (2026-10-31, part of Leader Builds): every gym brings a rule, a
# condition that lasts the whole battle, by the gym's type (it follows Remix
# and randomized gyms), from his table:
#
#   Normal    Rainbow           Safeguard        Ghost   Trick Room    Wonder Room
#   Fire      Sun               Sea of Fire      Dragon  Tailwind      Reflect
#   Water     Rain              Swamp            Dark    Spikes x2     Toxic Spikes
#   Electric  Electric Terrain  Light Screen     Steel   Reflect       Stealth Rock
#   Grass     Grassy Terrain    Sun              Fairy   Misty Terrain Safeguard
#   Ice       Hail              Mist             Psychic Psychic Terr. Light Screen
#   Fighting  Gravity           Reflect          Bug     Sticky Web    Spikes
#   Poison    Toxic Spikes x2   Spikes           Rock    Sandstorm     Stealth Rock
#   Ground    Spikes            Sandstorm        Flying  Tailwind      Strong Winds
#
# With KIF: Elite Redux (its New battle effects / Moves On): Grass's backup
# Creeping Thorns; Poison Toxic Terrain, then Toxic Spikes; Psychic's backup
# Inverse Room; Ghost Fog, then Trick Room; Dark Smokescreen, then Spikes x2;
# Steel's backup Caltrops.
#
#   Which     the first choice, unless it would hinder more than 2 of their
#             Pokémon (the ace counts like any) or a team member's own
#             weather or terrain would clash: then the backup; then Stealth
#             Rock. Hard brings both (each passing), and the Elite Four and
#             Champions bring two on Normal too
#   Who       Gym Leaders, the Elite Four and Champions; Normal and Hard
#   When      weather and terrain from the start (the game's own words say
#             them); the rest once both leads are out (your lead isn't hit
#             by a hazard it didn't walk into), each with its line. Kept
#             every turn: screens, Tailwind, rooms and the rest come back
#             each round's end, endless; hazards stay until cleared
#
# The Leader's Seal (UI/GymRuleSeal.rb) announces them: up after the send-
# outs, through every rule's line, gone once they're all said. Rematch Ranks' Elite
# trainers bring their type's first choice (rules_for).
#==============================================================================

module Reloaded
  module TrainerControl
    module GymRules
      STATE = :@kr_gym_rules               # on the battle: { "rules" => [keys], "laid" => true }
      GYM = /\A(LEADER_|ELITEFOUR|CHAMPION)/
      LEAGUE = /\A(ELITEFOUR|CHAMPION)/
      HINDER_MAX = 2
      FULL = 5                             # a kept timed effect's turns, every round
      TABLE = {
        :NORMAL => [:rainbow, :safeguard], :FIRE => [:sun, :sea_of_fire], :WATER => [:rain, :swamp],
        :ELECTRIC => [:electric_terrain, :light_screen], :GRASS => [:grassy_terrain, :sun], :ICE => [:hail, :mist],
        :FIGHTING => [:gravity, :reflect], :POISON => [:toxic_spikes2, :spikes], :GROUND => [:spikes, :sandstorm],
        :FLYING => [:tailwind, :strong_winds], :PSYCHIC => [:psychic_terrain, :light_screen], :BUG => [:sticky_web, :spikes],
        :ROCK => [:sandstorm, :stealth_rock], :GHOST => [:trick_room, :wonder_room], :DRAGON => [:tailwind, :reflect],
        :DARK => [:spikes2, :toxic_spikes], :STEEL => [:reflect, :stealth_rock], :FAIRY => [:misty_terrain, :safeguard]
      }.freeze
      # KIF-ER's column: [first, backup] (nil: as the table)
      KIFER_TABLE = { :GRASS => [nil, :creeping_thorns], :POISON => [:toxic_terrain, :toxic_spikes2], :PSYCHIC => [nil, :inverse_room],
                      :GHOST => [:fog, :trick_room], :DARK => [:smokescreen, :spikes2], :STEEL => [nil, :caltrops] }.freeze
      # key => [kind, what, side (:yours, :theirs, :field), type, words, the opening line (nil: the game says it)]
      RULES = {
        :sun => [:weather, :Sun, :field, :FIRE, "Sun", nil],
        :rain => [:weather, :Rain, :field, :WATER, "Rain", nil],
        :sandstorm => [:weather, :Sandstorm, :field, :ROCK, "Sandstorm", nil],
        :hail => [:weather, :Hail, :field, :ICE, "Hail", nil],
        :strong_winds => [:weather, :StrongWinds, :field, :FLYING, "Strong Winds", nil],
        :fog => [:weather, :Fog, :field, :GHOST, "Fog", "A deep fog rolled in!"],
        :electric_terrain => [:terrain, :Electric, :field, :ELECTRIC, "Electric Terrain", nil],
        :grassy_terrain => [:terrain, :Grassy, :field, :GRASS, "Grassy Terrain", nil],
        :psychic_terrain => [:terrain, :Psychic, :field, :PSYCHIC, "Psychic Terrain", nil],
        :misty_terrain => [:terrain, :Misty, :field, :FAIRY, "Misty Terrain", nil],
        :toxic_terrain => [:terrain, :Toxic, :field, :POISON, "Toxic Terrain", "Toxic sludge covers the battlefield!"],
        :rainbow => [:side, :Rainbow, :theirs, :NORMAL, "Rainbow", "A rainbow appeared in the sky on the opposing team's side!"],
        :safeguard => [:side, :Safeguard, :theirs, :NORMAL, "Safeguard", "The opposing team became cloaked in a mystical veil!"],
        :mist => [:side, :Mist, :theirs, :ICE, "Mist", "The opposing team became shrouded in mist!"],
        :reflect => [:side, :Reflect, :theirs, :PSYCHIC, "Reflect", "Reflect raised the opposing team's Defense!"],
        :light_screen => [:side, :LightScreen, :theirs, :PSYCHIC, "Light Screen", "Light Screen raised the opposing team's Special Defense!"],
        :tailwind => [:side, :Tailwind, :theirs, :FLYING, "Tailwind", "The Tailwind blew from behind the opposing team!"],
        :sea_of_fire => [:side, :SeaOfFire, :yours, :FIRE, "Sea of Fire", "A sea of fire enveloped your team!"],
        :swamp => [:side, :Swamp, :yours, :WATER, "Swamp", "A swamp enveloped your team!"],
        :gravity => [:field, :Gravity, :field, :PSYCHIC, "Gravity", "Gravity intensified!"],
        :trick_room => [:field, :TrickRoom, :field, :PSYCHIC, "Trick Room", "{1} twisted the dimensions!"],
        :wonder_room => [:field, :WonderRoom, :field, :PSYCHIC, "Wonder Room", "A bizarre area swaps every Pokémon's Defense and Sp. Def!"],
        :spikes => [:hazard, :Spikes, :yours, :GROUND, "Spikes", "Spikes were scattered all around your team's feet!", 1],
        :spikes2 => [:hazard, :Spikes, :yours, :GROUND, "Spikes", "Spikes were scattered all around your team's feet!", 2],
        :toxic_spikes => [:hazard, :ToxicSpikes, :yours, :POISON, "Toxic Spikes", "Poison spikes were scattered all around your team's feet!", 1],
        :toxic_spikes2 => [:hazard, :ToxicSpikes, :yours, :POISON, "Toxic Spikes", "Poison spikes were scattered all around your team's feet!", 2],
        :sticky_web => [:hazard, :StickyWeb, :yours, :BUG, "Sticky Web", "A sticky web has been laid out beneath your team's feet!", true],
        :stealth_rock => [:hazard, :StealthRock, :yours, :ROCK, "Stealth Rock", "Pointed stones float in the air around your team!", true],
        :smokescreen => [:kifer_side, :@kifer_mx_smoke, :theirs, :DARK, "Smokescreen", "Smoke obscured the opposing team!"],
        :creeping_thorns => [:kifer_hazard, :@kifer_mx_thorns, :yours, :GRASS, "Creeping Thorns", "Creeping thorns surround your team!"],
        :caltrops => [:kifer_hazard, :@kifer_nm3_caltrops, :yours, :STEEL, "Caltrops", "Caltrops are scattered around your team!"],
        :inverse_room => [:kifer_field, :@kifer_sp1_inverse, :field, :PSYCHIC, "Inverse Room", "Inverse Room reversed the type matchups!"]
      }.freeze
      WEATHER_SETTERS = { :DROUGHT => :Sun, :DRIZZLE => :Rain, :SANDSTREAM => :Sandstorm, :SNOWWARNING => :Hail,
                          :DESOLATELAND => :HarshSun, :PRIMORDIALSEA => :HeavyRain, :DELTASTREAM => :StrongWinds }.freeze
      TERRAIN_SETTERS = { :ELECTRICSURGE => :Electric, :GRASSYSURGE => :Grassy, :PSYCHICSURGE => :Psychic, :MISTYSURGE => :Misty }.freeze

      class << self
        def install
          return unless defined?(::PokeBattle_Battle)
          h = Reloaded::Hooks
          b = ::PokeBattle_Battle
          if TrainerControl.defined_method?(b, :pbStartBattle)
            h.around(nil, b, :pbStartBattle, :id => :gym_rules_start) do |original, *args|
              Reloaded::TrainerControl::GymRules.start(original.receiver)
              original.call(*args)
            end
          end
          if TrainerControl.defined_method?(b, :pbStartBattleSendOut)
            h.around(nil, b, :pbStartBattleSendOut, :id => :gym_rules_seal) do |original, *args|
              ret = original.call(*args)
              Reloaded::GymRuleSeal.open(original.receiver) if defined?(Reloaded::GymRuleSeal)
              ret
            end
          end
          if TrainerControl.defined_method?(b, :pbOnActiveAll)
            h.around(nil, b, :pbOnActiveAll, :id => :gym_rules_lay) do |original, *args|
              ret = original.call(*args)
              Reloaded::TrainerControl::GymRules.lay(original.receiver)
              ret
            end
          end
          if TrainerControl.defined_method?(b, :pbEndOfRoundPhase)
            h.around(nil, b, :pbEndOfRoundPhase, :id => :gym_rules_keep) do |original, *args|
              ret = original.call(*args)
              Reloaded::TrainerControl::GymRules.keep(original.receiver)
              ret
            end
          end
        end

        def on?
          return defined?(Reloaded::Difficulty) && Reloaded::Difficulty.respond_to?(:level) && Reloaded::Difficulty.level >= 1
        end

        def hard?
          return Reloaded::Difficulty.level >= 2
        end

        def gym?(type)
          return type.to_s =~ GYM ? true : false
        end

        def kifer_effects?
          return defined?(::KIFER) && ::KIFER.respond_to?(:feature_on?) && ::KIFER.feature_on? ? true : false
        end

        def kifer_moves?
          return defined?(::KIFER::Moves) && ::KIFER::Moves.respond_to?(:applied?) && ::KIFER::Moves.applied? ? true : false
        end

        # A rule the game can bring: KIF-ER's need it On, Fog and Toxic its weather and terrain
        def available?(key)
          kind = RULES[key][0]
          case key
          when :fog then return kifer_effects? && (::GameData::BattleWeather.exists?(:Fog) rescue false)
          when :toxic_terrain then return kifer_effects? && (::GameData::BattleTerrain.exists?(:Toxic) rescue false)
          when :inverse_room then return kifer_effects?
          end
          return kifer_moves? if kind == :kifer_side || kind == :kifer_hazard
          return true
        end

        # [first, backup] for a type; KIF-ER's column as a pair, when what
        # it brings of KIF-ER's own is on (Ghost: Fog then Trick Room, or
        # the table's Trick Room then Wonder Room)
        def candidates(type)
          first, backup = TABLE[type.to_s.to_sym] || [nil, nil]
          row = KIFER_TABLE[type.to_s.to_sym]
          if row && row.compact.all? { |k| available?(k) }
            first = row[0] || first
            backup = row[1] || backup
          end
          return [first, backup]
        end

        #----------------------------------------------------------------------
        # Who it hinders, what clashes
        #----------------------------------------------------------------------
        def types_of(pk)
          t = (pk.types rescue nil) || [(pk.type1 rescue nil), (pk.type2 rescue nil)]
          return Array(t).compact.map { |x| x.to_s.to_sym }.uniq
        end

        def abilities_of(pk)
          list = [(pk.ability_id rescue nil)]
          list.concat(Array(pk.innates)) if pk.respond_to?(:innates)
          return list.compact.map { |a| a.to_s.to_sym }
        end

        # One of their Pokémon the rule works against
        def hinders?(key, pk)
          t = types_of(pk)
          case key
          when :sun then return t.include?(:WATER)
          when :rain then return t.include?(:FIRE)
          when :sandstorm then return (t & [:ROCK, :GROUND, :STEEL]).empty?
          when :hail then return !t.include?(:ICE)
          when :grassy_terrain then return t.include?(:GROUND)
          when :misty_terrain then return t.include?(:DRAGON)
          when :toxic_terrain then return (t & [:POISON, :STEEL]).empty?
          when :gravity then return t.include?(:FLYING) || abilities_of(pk).include?(:LEVITATE)
          when :trick_room
            base = (pk.baseStats rescue nil) || {}
            return base[:SPEED].to_i >= 90
          end
          return false
        end

        # A team member's own weather or terrain unlike the rule's
        def clashes?(key, party)
          kind, what = RULES[key]
          setters = kind == :weather ? WEATHER_SETTERS : (kind == :terrain ? TERRAIN_SETTERS : nil)
          return false unless setters
          return party.any? { |pk| abilities_of(pk).any? { |a| setters[a] && setters[a] != what } }
        end

        def fits?(key, party)
          return false unless key && RULES[key] && available?(key)
          return false if clashes?(key, party)
          return party.count { |pk| hinders?(key, pk) } <= HINDER_MAX
        end

        # The rules for a type and a team: count of them (1 or 2), Stealth
        # Rock where neither fits
        def rules_for(type, party, count)
          out = candidates(type).compact.select { |k| fits?(k, party) }.first(count)
          out << :stealth_rock if out.length < count && !out.include?(:stealth_rock)
          return out.first(count)
        end

        # A gym battle's rules, chosen as it starts: its leader's type and team
        def choose(battle)
          return [] unless on? && battle.respond_to?(:opponent)
          tr = Array(battle.opponent).find { |t| gym?((t.trainer_type rescue nil)) }
          ranked = tr ? nil : Array(battle.opponent).find { |t| t && ranked_rule?(t) }
          tr ||= ranked
          return [] unless tr
          party = Array(tr.party).compact
          type = TrainerControl.theme_type(tr.trainer_type, party.map { |pk| [pk.species, pk.level] })
          return [] unless type
          count = !ranked && (hard? || tr.trainer_type.to_s =~ LEAGUE) ? 2 : 1
          return rules_for(type, party, count)
        end

        # Rematch Ranks' Elite: an ordinary trainer brings their type's rule
        def ranked_rule?(trainer)
          return defined?(RematchRanks) && RematchRanks.gym_rule?(RematchRanks.rank_in_battle(trainer)) ? true : false
        end

        def rules(battle)
          st = battle.instance_variable_get(STATE)
          return st ? st["rules"] : []
        end

        # Who set the rules: the gym's leader, else an Elite trainer
        def leader_name(battle)
          list = battle.respond_to?(:opponent) ? Array(battle.opponent).compact : []
          tr = list.find { |t| gym?((t.trainer_type rescue nil)) } || list.find { |t| ranked_rule?(t) }
          return tr ? tr.name.to_s : ""
        end

        #----------------------------------------------------------------------
        # Bringing them in, keeping them
        #----------------------------------------------------------------------
        # Before the battle starts: weather and terrain (the game says them)
        def start(battle)
          return if battle.instance_variable_get(STATE)
          list = choose(battle)
          battle.instance_variable_set(STATE, { "rules" => list, "laid" => false })
          return if list.empty?
          list.each do |key|
            kind, what = RULES[key]
            case kind
            when :weather
              battle.defaultWeather = what
              battle.instance_variable_set(:@wind_side, 1) if what == :StrongWinds
            when :terrain then battle.defaultTerrain = what
            end
          end
        rescue StandardError => e
          Reloaded::Log.exception("Gym Rules couldn't start", e, :trainer_control)
        end

        # Once both leads are out: the rest, each with its line (KIF-ER's Fog
        # and Toxic Terrain too, which the game's start doesn't say)
        def lay(battle)
          st = battle.instance_variable_get(STATE)
          return unless st && !st["laid"]
          st["laid"] = true
          st["rules"].each do |key|
            kind = RULES[key][0]
            set(battle, key) unless kind == :weather || kind == :terrain
            words = line(battle, key)
            battle.pbDisplay(words) if words
          end
        rescue StandardError => e
          Reloaded::Log.exception("Gym Rules couldn't lay their rules", e, :trainer_control)
        ensure
          Reloaded::GymRuleSeal.close if defined?(Reloaded::GymRuleSeal) && st && st["laid"]
        end

        # The opening line (nil: the game's own said it)
        def line(battle, key)
          words = RULES[key][5]
          return nil unless words
          words = "A bizarre area swaps every Pokémon's Attack and Sp. Atk!" if key == :wonder_room && kifer_moves?
          return _INTL(words, leader_name(battle))
        end

        def side_of(battle, key)
          return battle.sides[RULES[key][2] == :yours ? 0 : 1]
        end

        def set(battle, key)
          kind, what, _side, _t, _w, _l, layers = RULES[key]
          case kind
          when :side then side_of(battle, key).effects[PBEffects.const_get(what)] = FULL
          when :field then field_set(battle, key, what)
          when :hazard then side_of(battle, key).effects[PBEffects.const_get(what)] = layers
          when :kifer_side then side_of(battle, key).instance_variable_set(what, FULL)
          when :kifer_hazard then side_of(battle, key).instance_variable_set(what, true)
          when :kifer_field then battle.instance_variable_set(what, FULL)
          end
        end

        # Wonder Room is KIF-ER's own while its Moves are On
        def field_set(battle, key, what)
          if key == :wonder_room && kifer_moves?
            battle.instance_variable_set(:@kifer_mx_wonder, FULL)
          else
            battle.field.effects[PBEffects.const_get(what)] = FULL
          end
        end

        # Each round's end: the timed ones back to full (hazards stay until cleared)
        def keep(battle)
          st = battle.instance_variable_get(STATE)
          return unless st && st["laid"]
          st["rules"].each do |key|
            kind = RULES[key][0]
            set(battle, key) if [:side, :field, :kifer_side, :kifer_field].include?(kind)
          end
        rescue StandardError => e
          Reloaded::Log.exception("Gym Rules couldn't keep their rules", e, :trainer_control)
        end

        # A timed effect a rule holds all battle (Battle Menu's reader shows it endless)
        def held?(battle, effect, side)
          rules(battle).any? do |key|
            kind, what, s = RULES[key]
            next false unless (kind == :side || kind == :field) && what.to_s == effect.to_s
            s == :field ? side == :field : (s == :yours ? side == 0 : side == 1)
          end
        rescue StandardError
          return false
        end
      end
    end
  end
end
