# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Randomizer's Dynamic rolls
#==============================================================================
# A Rolls row (Fixed / Dynamic) under the parts the seed fixes: Fixed is
# cody's (the same seed and settings, the same game); Dynamic rolls again
# on the spot, so the seed won't give the same result each time.
#
#   Trainer Teams    (Trainers: Random) every battle rolls the team again,
#                    with his rules (Strength Range, Class Themes, Custom
#                    Sprites Only, Fuse Everything, Unfused Pokémon, Team
#                    Size); the seed's team stays underneath. The rival's
#                    with Rival Keeps His Team and Gym teams that stick to
#                    their type stay his
#   Starters         rolled the first time the game asks for them, kept for
#                    the run (the rival's starter is made from them too)
#   Static           every battle with an overworld Pokémon rolls a new one
#   Gifts            every gift rolls its own when you get it
#   Trades           (Trades: Random) rolled again each time you enter the
#                    trade's map; the same all through one visit, so what
#                    the NPC says and what you get agree
#   NPC Requests     (NPC Requests: Swapped) a new Pokémon asked for each
#                    time you enter the map
#   Learnsets        (Learnsets: Random) every Pokémon rolls its own
#                    (Learnsets.roll_for)
#   Items            (Item Mode: Dynamic, a value of its own) every item ball
#                    and gift, items and TMs, rolls when you get it, from his
#                    pool for it (his bans, Keep Categories). Shops stay By
#                    Spot (the Shops feature takes them over later)
#
# Starters, statics and gifts roll like his Dynamic wild encounters (his
# dynamic_species: the wild Strength Range, Legendaries, Fuse Everything,
# Custom Sprites Only, the bans). A map visit's rolls come from a salt made
# when the map is entered (kept in the save; loading isn't entering).
# Pinkan Island plays as in PIF.
#==============================================================================

module Reloaded
  module Randomizer
    module Dynamic
      class << self
        def r
          return ::KIF::Rand
        end

        # Dynamic for this part: a randomized save, its Rolls row, not on
        # Pinkan Island
        def on?(key)
          return false unless Reloaded::Randomizer.randomized? && Reloaded::Randomizer.get(key) == 1
          return !(r.pinkan? rescue false)
        rescue StandardError
          return false
        end

        def switch?(id)
          return $game_switches && $game_switches[id] ? true : false
        end

        #----------------------------------------------------------------------
        # Trainer teams: rolled again for this battle
        #----------------------------------------------------------------------
        def teams?
          return on?(:kr_teams_dynamic) && r.get(:trainers) == 1 && switch?(::SWITCH_RANDOM_TRAINERS) &&
                 !switch?(::SWITCH_FIRST_RIVAL_BATTLE)
        end

        # A new team in the seed's team's place: [team, the seed's] or nil
        def roll_team(tr)
          hash = $PokemonGlobal && $PokemonGlobal.randomTrainersHash
          seeded = hash.is_a?(Hash) ? hash[tr.id] : nil
          return nil unless seeded.is_a?(Array) && !seeded.empty?
          return nil if r.dget(:rival_team) == 1 && r::RIVAL_TYPES.include?(tr.trainer_type)
          olds = tr.pokemon.map { |p| r.dex_of(p[:species]) }
          theme = r.dget(:class_themes) > 0 ? r.class_theme(tr.trainer_type) : nil
          customs = custom_dexes
          team = seeded.each_with_index.map do |was, i|
            old = olds[i] || r.extra_base(olds)
            next was if i < olds.length && (old == r.rival_placeholder || old >= ::Settings::ZAPMOLCUNO_NB)
            dex = r.dex_of(r.trainer_pick(old, theme, customs))
            dex = r.dex_of(r.fuse_pick(dex, theme)) if r.dget(:trainer_fuse) == 1
            r.valid_dex?(dex) ? dex : was
          end
          return [team, seeded]
        end

        # His Custom Sprites Only for trainers (PIF's switch 600)
        def custom_dexes
          return nil unless r.get(:trainer_custom) == 1
          list = r.custom_list.map { |c| r.dex_of(c) }.select { |d| d > 0 }
          return list.empty? ? nil : list
        end

        def with_team(tr)
          rolled = teams? ? roll_team(tr) : nil
          return yield unless rolled
          hash = $PokemonGlobal.randomTrainersHash
          hash[tr.id] = rolled[0]
          begin
            return yield
          ensure
            hash[tr.id] = rolled[1]
          end
        end

        #----------------------------------------------------------------------
        # Starters: rolled once, the first time they're asked for
        #----------------------------------------------------------------------
        STARTER_DEX = [1, 4, 7].freeze

        def starters?
          return on?(:kr_starters_dynamic) && r.get(:starters) > 0
        end

        # The three, as dex numbers; nil while his shuffle runs (rolls there
        # would take the seed's numbers)
        def starter_roll
          return nil if r.seeded > 0
          kept = r.data[:kr_starter_roll]
          return kept[1] if kept.is_a?(Array) && kept[0] == r.seed && kept[1].is_a?(Array) && kept[1].length == 3
          picks = []
          STARTER_DEX.each do |d|
            pick = nil
            8.times do
              pick = r.dex_of(r.dynamic_species(::GameData::Species.get(d).species))
              break unless picks.include?(pick)
            end
            picks << pick
          end
          r.data[:kr_starter_roll] = [r.seed, picks]
          return picks
        end

        def starter(index)
          picks = starter_roll
          return nil unless picks
          dex = picks[[[index.to_i, 0].max, 2].min]
          if switch?(::SWITCH_RANDOM_STARTER_FIRST_STAGE)
            sp = ::GameData::Species.get(dex)
            dex = ::GameData::Species.get(sp.get_baby_species(false)).id_number
          end
          return dex
        end

        #----------------------------------------------------------------------
        # Statics and gifts: a roll each time
        #----------------------------------------------------------------------
        def statics?
          return on?(:kr_statics_dynamic) && switch?(::SWITCH_RANDOM_WILD) && switch?(::SWITCH_RANDOM_STATIC_ENCOUNTERS) &&
                 r.in_encounter == 0
        end

        def gifts?
          return on?(:kr_gifts_dynamic) && switch?(::SWITCH_RANDOM_WILD) && switch?(::SWITCH_RANDOM_GIFT_POKEMON) &&
                 !switch?(::SWITCH_DONT_RANDOMIZE)
        end

        # A static battle's Pokémon, rolled (his swap check is skipped for it,
        # as he does for grass battles)
        def static_battle(species)
          sp = ::GameData::Species.get(species).id
          return yield(species) if getDexNumberForSpecies(sp) > ::NB_POKEMON
          rolled = r.dynamic_species(sp)
          $game_switches[::SWITCH_RANDOM_STATIC_ENCOUNTERS] = false
          r.statics_off = true
          begin
            return yield(rolled)
          ensure
            r.statics_off = false
            $game_switches[::SWITCH_RANDOM_STATIC_ENCOUNTERS] = true
          end
        end

        def gift(pkmn)
          old = pkmn.species
          rolled = r.dynamic_species(old)
          pkmn.species = rolled if rolled && rolled != old
        end

        #----------------------------------------------------------------------
        # Trades and NPC requests: one roll per visit to the map
        #----------------------------------------------------------------------
        def visit_salt
          v = r.data[:kr_visit]
          return v.is_a?(Integer) ? v : 0
        end

        # Entering a map: a new salt; his NPC lines (cached per event) are
        # worked out again
        def new_visit
          return unless Reloaded::Randomizer.randomized?
          return unless Reloaded::Randomizer.get(:kr_trades_dynamic) == 1 || Reloaded::Randomizer.get(:kr_requests_dynamic) == 1
          r.data[:kr_visit] = Random.new_seed % (2**31)
          cache = r.instance_variable_get(:@req_cache)
          cache.clear if cache.is_a?(Hash)
        end

        # A Pokémon within the wild Strength Range of dex, from this visit's
        # salt and the spot
        def visit_roll(kind, dex, map_id, event_id)
          fusions = switch?(::SWITCH_RANDOM_WILD_TO_FUSION)
          max = (r.fused?(dex) || fusions) ? ::PBSpecies.maxValue : ::NB_POKEMON
          new = r.with_seed(kind, map_id, event_id, dex, visit_salt) {
            r.dex_of(getNewSpecies(dex, r.get(:wild_bst), false, max, switch?(::SWITCH_RANDOM_WILD_LEGENDARIES)))
          }
          return nil unless new && r.valid_dex?(new) && new != dex
          return ::GameData::Species.get(new).species
        end

        def trades?
          return on?(:kr_trades_dynamic) && r.get(:trades) == 2 && r.pokemon_parts_on?
        end

        def trade(species, map_id, event_id)
          dex = r.dex_of(species)
          return nil if dex <= 0 || dex >= ::Settings::ZAPMOLCUNO_NB
          return visit_roll(:kr_trade, dex, map_id || r.map_id, event_id || r.event_id)
        end

        def requests?
          return on?(:kr_requests_dynamic) && r.dget(:npc_requests) == 1 && r.pokemon_parts_on?
        end

        def request(species)
          dex = r.dex_of(species)
          return nil if dex <= 0 || dex >= ::Settings::ZAPMOLCUNO_NB
          return visit_roll(:kr_request, dex, r.map_id, 0)
        end

        #----------------------------------------------------------------------
        # Items: Item Mode Dynamic (his By Spot under it)
        #----------------------------------------------------------------------
        def items?
          return on?(:kr_items_dynamic) && r.dget(:item_mode) == 1
        end

        # An item ball's or a gift's item, from his pool for it (shops never
        # come here: they stay By Spot)
        def item_roll(it)
          targets = r.item_targets(it.is_TM?, r.item_category(it))
          return it.id if targets.empty?
          return targets[Random.new.rand(targets.length)]
        end

        #----------------------------------------------------------------------
        # The spoiler log says which parts roll on the spot
        #----------------------------------------------------------------------
        def log_note(part)
          case part
          when :starters
            return nil unless starters?
            return "Dynamic: The starters are rolled the first time you see them, not by the seed."
          when :trades
            return nil unless trades?
            return "Dynamic: Every trade rolls again each time you enter its map (this visit's below)."
          when :trainers
            return nil unless teams?
            return "Dynamic: Every battle rolls the team again; these are the seed's teams."
          end
          return nil
        end

        #----------------------------------------------------------------------
        # Hooks
        #----------------------------------------------------------------------
        def install
          h = Reloaded::Hooks
          feature = Reloaded::Randomizer::FEATURE
          rand = r.singleton_class
          if defined?(::GameData::Trainer)
            h.around(feature, ::GameData::Trainer, :to_trainer, :id => :randomizer_dynamic_teams) do |original, *args|
              Reloaded::Randomizer::Dynamic.with_team(original.receiver) { original.call(*args) }
            end
          end
          h.around(feature, ::Object, :obtainRandomizedStarter, :id => :randomizer_dynamic_starters) do |original, index, *rest|
            dyn = Reloaded::Randomizer::Dynamic
            (dyn.starters? && dyn.starter(index)) || original.call(index, *rest)
          end
          h.around(feature, ::Object, :pbWildBattle, :id => :randomizer_dynamic_statics) do |original, species, *rest|
            dyn = Reloaded::Randomizer::Dynamic
            next original.call(species, *rest) unless species && dyn.statics?
            dyn.static_battle(species) { |sp| original.call(sp, *rest) }
          end
          h.around(feature, ::Object, :tryRandomizeGiftPokemon, :id => :randomizer_dynamic_gifts) do |original, pkmn, *rest|
            dyn = Reloaded::Randomizer::Dynamic
            dont = rest[0]
            next original.call(pkmn, *rest) unless pkmn.is_a?(::Pokemon) && !dont && dyn.gifts?
            dyn.gift(pkmn)
            nil
          end
          h.around(feature, rand, :trade_result, :id => :randomizer_dynamic_trades) do |original, species, *rest|
            dyn = Reloaded::Randomizer::Dynamic
            next original.call(species, *rest) unless dyn.trades?
            dyn.trade(species, rest[0], rest[1])
          end
          h.around(feature, rand, :request_target, :id => :randomizer_dynamic_requests) do |original, sp, *rest|
            dyn = Reloaded::Randomizer::Dynamic
            # PokéRadar rares stay his (they follow the wild encounters)
            next original.call(sp, *rest) unless dyn.requests? && !::KIF::Rand.radar_rare_originals.include?(sp)
            dyn.request(sp)
          end
          # his roll_item: By Spot's (seed, spot) for shops; an item ball or a
          # gift rolls on the spot with Dynamic
          if r.respond_to?(:roll_item)
            h.around(feature, rand, :roll_item, :id => :randomizer_dynamic_items) do |original, it, *spot|
              dyn = Reloaded::Randomizer::Dynamic
              next original.call(it, *spot) if spot[0] == :shop || !dyn.items?
              dyn.item_roll(it)
            end
          end
          if r.respond_to?(:dynamic_item_lines)
            h.around(feature, rand, :dynamic_item_lines, :id => :randomizer_dynamic_item_log) do |original, *args|
              next original.call(*args) unless Reloaded::Randomizer::Dynamic.items?
              ["Dynamic: Every item ball and gift rolls its item when you get it, so there's no list. Shops are By Spot."]
            end
          end
          # his log calls By Spot "Dynamic": its item and shop parts by their
          # names here
          if r.respond_to?(:sections)
            h.around(feature, rand, :sections, :id => :randomizer_dynamic_log_names) do |original, *args|
              dyn = Reloaded::Randomizer::Dynamic
              Array(original.call(*args)).map do |title, body|
                if title.to_s.start_with?("Items and TMs (Dynamic")
                  [dyn.items? ? "Items and TMs: Dynamic" : "Items and TMs: By Spot", body]
                elsif title.to_s == "Shops" && r.dynamic_items?
                  ["Shops", proc { ["By Spot: Every shop rolls its own stock, the same for the same seed and shop."] }]
                else
                  [title, body]
                end
              end
            end
          end
          [[:sec_starters, :starters], [:trade_lines, :trades], [:sec_trainers, :trainers]].each do |m, part|
            next unless r.respond_to?(m)
            h.around(feature, rand, m, :id => :"randomizer_dynamic_log_#{part}") do |original, *args|
              lines = Array(original.call(*args))
              note = Reloaded::Randomizer::Dynamic.log_note(part)
              note ? [note] + lines : lines
            end
          end
          # (loading a save "changes" to the map it's on: not a visit)
          if defined?(::Events)
            ::Events.onMapChange += proc do |_sender, e|
              was = e.is_a?(Array) ? e[0] : e
              Reloaded::Randomizer::Dynamic.new_visit if Reloaded::Features.on?(feature) && $game_map && was != $game_map.map_id
            end
          end
        end
      end
    end
  end
end
