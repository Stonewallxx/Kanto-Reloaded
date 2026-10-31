# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Trainer Control's Team Expansion and the gyms
#==============================================================================
# His picks (Roadmap Designs topic trainer-control, 2026-10-30):
#
#   Team Expansion  optional (Off to start): Add Count (+1 to +5) or Target
#                   Size (1 to 6) for trainers and your rival
#   Leaders         Normal, Add Count, Target Size or Full Party for Gym
#                   Leaders, the Elite Four, Champions and Rocket bosses
#                   (cody's Gym Leader teams, taken over)
#   What It Adds    Local Theme (the class's type from the wild Pokémon of
#                   their own map first, then any of it), Random, Random
#                   Fusion; leaders always their gym's type. Matched to the
#                   team's strength and how often it's fused, at the team's
#                   level, the same every battle for a save, never
#                   legendary or banned (cody's own picker)
#   Held items      a chance that grows with badges (none before 2, 25% at
#                   4, 50% from 8), picked by role and type (old KR's
#                   lists); the Randomizer's random held items win
#   Pokémon in Gyms Follow the Leader (as many as the leader brings; the
#                   game's limit while Leaders is Normal), Normal, +1, +2,
#                   Full (cody's Your Pokémon in gyms, taken over)
#   2v2 and 3v3     with KIF's Battle Format on for trainers, a trainer
#                   short of Pokémon gets just enough to fill their side,
#                   even with Team Expansion Off
#
# On randomized saves with random trainers, the Randomizer's Team size and
# Leader team size decide: these rows lock and say so. cody's two rows hide
# (KIF's takeover of C-GYM-01) and his saved values come across once per
# save; his helpers stay his, and his gym lines still say the real numbers.
#==============================================================================

module Reloaded
  module TrainerControl
    module TeamExpansion
      PAGE = :trainer_control_teams
      EXPAND = :"trainer_control.expand"
      EXPAND_ADD = :"trainer_control.expand_add"
      EXPAND_SIZE = :"trainer_control.expand_size"
      ADDS = :"trainer_control.expand_adds"
      LEADERS = :"trainer_control.leader_teams"
      LEADERS_ADD = :"trainer_control.leader_add"
      LEADERS_SIZE = :"trainer_control.leader_size"
      GYM_PARTY = :"trainer_control.gym_party"
      EXPAND_NAMES = ["Off", "Add Count", "Target Size"].freeze
      LEADER_NAMES = ["Normal", "Add Count", "Target Size", "Full Party"].freeze
      ADD_NAMES = ["+1", "+2", "+3", "+4", "+5"].freeze
      SIZE_NAMES = ["1", "2", "3", "4", "5", "6"].freeze
      ADDS_NAMES = ["Local Theme", "Random", "Random Fusion"].freeze
      GYM_NAMES = ["Follow the Leader", "Normal", "+1", "+2", "Full"].freeze
      MAX = 6
      ADDED = :@kr_tc_added               # on a Pokémon Team Expansion added
      # Type-boosting items, then by role (old KR's lists)
      TYPE_ITEMS = { :NORMAL => :SILKSCARF, :FIRE => :CHARCOAL, :WATER => :MYSTICWATER, :ELECTRIC => :MAGNET,
                     :GRASS => :MIRACLESEED, :ICE => :NEVERMELTICE, :FIGHTING => :BLACKBELT, :POISON => :POISONBARB,
                     :GROUND => :SOFTSAND, :FLYING => :SHARPBEAK, :PSYCHIC => :TWISTEDSPOON, :BUG => :SILVERPOWDER,
                     :ROCK => :HARDSTONE, :GHOST => :SPELLTAG, :DRAGON => :DRAGONFANG, :DARK => :BLACKGLASSES,
                     :STEEL => :METALCOAT }.freeze
      ALL_ROLES = [:SITRUSBERRY, :LUMBERRY, :EXPERTBELT].freeze
      ROLE_ITEMS = { :status => [:LEFTOVERS, :FOCUSSASH, :ROCKYHELMET, :LIGHTCLAY, :MENTALHERB],
                     :physical => [:MUSCLEBAND, :LIFEORB, :CHOICEBAND, :CHOICESCARF, :SCOPELENS],
                     :special => [:WISEGLASSES, :LIFEORB, :CHOICESPECS, :CHOICESCARF, :SCOPELENS],
                     :mixed => [:LEFTOVERS, :LIFEORB, :ASSAULTVEST, :SHELLBELL, :QUICKCLAW] }.freeze

      class << self
        attr_accessor :trainers_in_battle

        def lt
          return defined?(::KIF::LeaderTeams) ? ::KIF::LeaderTeams : nil
        end

        def install
          register_settings if defined?(Reloaded::Settings)
          Reloaded::Events.on(:save_loaded, :trainer_control_cody_rows, 62) { |c| import_cody(c) }
          l = lt
          return unless l
          h = Reloaded::Hooks
          sc = l.singleton_class
          if sc.method_defined?(:add_extras)
            h.around(nil, sc, :add_extras, :id => :trainer_control_cody_extras) { |_original, *_args| nil }
          end
          if sc.method_defined?(:player_max)
            h.around(nil, sc, :player_max, :id => :trainer_control_gym_party) do |original, *args|
              Reloaded::TrainerControl::TeamExpansion.gym_party(args[0], original)
            end
          end
          if sc.method_defined?(:counts)
            h.around(nil, sc, :counts, :id => :trainer_control_gym_lines) do |original, *args|
              Reloaded::TrainerControl::TeamExpansion.line_counts(original.call(*args), args[0])
            end
          end
        end

        def register_settings
          s = Reloaded::Settings
          rand_lock = proc { randomizer_decides? ? _INTL("The Randomizer's Team size decides on this save.") : nil }
          leader_lock = proc { randomizer_decides? ? _INTL("The Randomizer's Leader team size decides on this save.") : nil }
          s.register_page(PAGE, :group => :general, :name => "Trainer Control - Teams", :icon => :features, :priority => 49.7,
            :description => "How many Pokémon trainers and leaders bring, what joins them, and how many you bring to gyms.")
          s.register(EXPAND, :page => PAGE, :priority => 10, :type => :enum, :values => EXPAND_NAMES, :default => 0, :scope => :save,
            :name => "Team Expansion", :lock => rand_lock,
            :description => "Trainers and your rival bring more Pokémon.",
            :descriptions => ["Trainers bring the teams the game gives them.", "Each trainer brings a set number more (Add Count).",
                              "Each trainer brings at least a set number (Target Size)."])
          s.register(EXPAND_ADD, :page => PAGE, :priority => 11, :type => :enum, :values => ADD_NAMES, :default => 0, :scope => :save,
            :name => "Add Count", :lock => rand_lock, :visible => proc { Reloaded::Settings.get(EXPAND).to_i == 1 },
            :description => "How many more Pokémon each trainer brings, up to six.")
          s.register(EXPAND_SIZE, :page => PAGE, :priority => 12, :type => :enum, :values => SIZE_NAMES, :default => 3, :scope => :save,
            :name => "Target Size", :lock => rand_lock, :visible => proc { Reloaded::Settings.get(EXPAND).to_i == 2 },
            :description => "Each trainer brings at least this many Pokémon. Bigger teams stay as they are.")
          s.register(ADDS, :page => PAGE, :priority => 13, :type => :enum, :values => ADDS_NAMES, :default => 0, :scope => :save,
            :name => "What Joins Them", :visible => proc { Reloaded::Settings.get(EXPAND).to_i > 0 },
            :description => "What a trainer's added Pokémon are. Always as strong as their team, at its level, the same every battle.",
            :descriptions => ["Their class's type: The wild Pokémon of their own route first.", "Any Pokémon, fused as often as their team is.",
                              "Always a fusion."])
          s.register(LEADERS, :page => PAGE, :priority => 20, :type => :enum, :values => LEADER_NAMES, :default => 0, :scope => :save,
            :name => "Leaders", :lock => leader_lock,
            :description => "How many Pokémon Gym Leaders, the Elite Four, Champions and Rocket bosses bring. What joins them is always their own type.",
            :descriptions => ["Their usual teams.", "A set number more (Add Count).", "At least a set number (Target Size).", "Six Pokémon."])
          s.register(LEADERS_ADD, :page => PAGE, :priority => 21, :type => :enum, :values => ADD_NAMES, :default => 0, :scope => :save,
            :name => "Leaders: Add Count", :lock => leader_lock, :visible => proc { Reloaded::Settings.get(LEADERS).to_i == 1 },
            :description => "How many more Pokémon each leader brings, up to six.")
          s.register(LEADERS_SIZE, :page => PAGE, :priority => 22, :type => :enum, :values => SIZE_NAMES, :default => 3, :scope => :save,
            :name => "Leaders: Target Size", :lock => leader_lock, :visible => proc { Reloaded::Settings.get(LEADERS).to_i == 2 },
            :description => "Each leader brings at least this many Pokémon.")
          s.register(GYM_PARTY, :page => PAGE, :priority => 30, :type => :enum, :values => GYM_NAMES, :default => 0, :scope => :save,
            :name => "Pokémon in Gyms",
            :description => "How many Pokémon you may pick before a Kanto Gym Leader battle.",
            :descriptions => ["As many as the leader brings (the game's own limit while Leaders is Normal).", "The game's own limit.",
                              "One more than the game's limit.", "Two more than the game's limit.", "Your whole party."])
        end

        def setting(key)
          return Reloaded::Settings.get(key).to_i
        end

        def randomizer_decides?
          return defined?(::SWITCH_RANDOM_TRAINERS) && ($game_switches[::SWITCH_RANDOM_TRAINERS] rescue false) ? true : false
        end

        # cody's Gym Leader teams and Your Pokémon in gyms, brought across
        # once per save (KIF hides his rows while Kanto Reloaded has them)
        def import_cody(context)
          d = Records.data
          return unless d && !d["cody_rows"]
          d["cody_rows"] = true
          return if context && context[:new_game]
          ps = $PokemonSystem
          lead = (ps.cody_leader_teams.to_i rescue 0)
          gym = (ps.cody_gym_party.to_i rescue 0)
          s = Reloaded::Settings
          case lead
          when 1, 2
            s.set(LEADERS, 1)
            s.set(LEADERS_ADD, lead - 1)
          when 3 then s.set(LEADERS, 3)
          end
          s.set(GYM_PARTY, gym + 1) if gym.between?(1, 3)
        rescue StandardError => e
          Reloaded::Log.exception("Trainer Control couldn't bring cody's gym settings across", e, :trainer_control)
        end

        #----------------------------------------------------------------------
        # How many
        #----------------------------------------------------------------------
        # A team of n's size by the rows: Add Count, Target Size, Full
        def size_for(kind, n)
          return n if randomizer_decides?
          if kind == :leader
            case setting(LEADERS)
            when 1 then return [n + setting(LEADERS_ADD) + 1, MAX].min
            when 2 then return [[n, setting(LEADERS_SIZE) + 1].max, MAX].min
            when 3 then return MAX
            end
            return n
          end
          case setting(EXPAND)
          when 1 then return [n + setting(EXPAND_ADD) + 1, MAX].min
          when 2 then return [[n, setting(EXPAND_SIZE) + 1].max, MAX].min
          end
          return n
        end

        # KIF's Battle Format for trainers (2v2, 3v3): each trainer's share
        # of their side, when the event didn't set the battle's size
        def side_share
          return 0 unless defined?(::KIF) && ::KIF.respond_to?(:format_for_trainers?) && ::KIF.format_for_trainers?
          rules = ($PokemonTemp.battleRules rescue nil) || {}
          return 0 unless rules["size"].nil? && rules["birdboss"].nil?
          n = [@trainers_in_battle.to_i, 1].max
          return ((::KIF.battle_format.to_i + 1) / n.to_f).ceil
        end

        # The leader's team size now (the gym's lines, Follow the Leader):
        # its data's, by the Leaders row
        def leader_size(type, name, version)
          data = (::GameData::Trainer.try_get(type, name, version) rescue nil)
          return nil unless data
          return size_for(:leader, data.pokemon.length)
        end

        # cody's player_max: Pokémon in Gyms (max: the game's own limit)
        def gym_party(max, original)
          case setting(GYM_PARTY)
          when 1 then return max
          when 2 then return [max + 1, MAX].min
          when 3 then return [max + 2, MAX].min
          when 4 then return MAX
          end
          return max if setting(LEADERS) == 0 && !randomizer_decides?
          info = lt.respond_to?(:dialog_ctx) ? lt.dialog_ctx : nil
          return max unless info
          lead = randomizer_decides? ? nil : leader_size(info[0], info[1], info[2])
          return lead ? [[lead, 1].max, MAX].min : max
        rescue StandardError
          return max
        end

        # cody's gym lines say the real numbers: [leader, base, you, base picker]
        def line_counts(counts, info)
          return counts unless counts.is_a?(Array) && info
          out = counts.dup
          out[0] = leader_size(info[0], info[1], info[2]) || out[0] unless randomizer_decides?
          out[2] = gym_party(info[3].to_i, proc { |m| m })
          return out
        end

        #----------------------------------------------------------------------
        # Adding them
        #----------------------------------------------------------------------
        def apply(trainer, type, name, version)
          l = lt
          party = trainer ? trainer.party : nil
          return unless l && party.is_a?(Array) && !party.empty?
          kind = TrainerControl.kind(type)
          n = party.length
          want = [size_for(kind, n), side_share, n].max
          add = [want, MAX].min - n
          return if add <= 0
          key = TrainerControl.person_key(type, name)
          data = (::GameData::Trainer.try_get(type, name, version) rescue nil)
          rng = Random.new(seed(key, version))
          level = (party.sum { |p| p.level.to_i }.to_f / n).round
          target = party.sum { |p| l.bst(l.dex(p.species)) }.to_f / n
          fused = party.count { |p| p.species.to_s =~ /\AB\d+H\d+\z/ }.to_f / n
          mode = kind == :leader ? :leader : [:local, :random, :fusion][setting(ADDS)] || :local
          type_of = kind == :leader ? (l.gym_type(type, party) rescue nil) : TrainerControl.theme_type(type, party.map { |p| [p.species, p.level] })
          used = party.map { |p| l.dex(p.species) }
          roots = []
          add.times do
            d = pick(mode, type_of, level, target, fused, used, roots, rng)
            break unless d
            used << d
            roots.concat(Array(l.roots_of(d))) if l.respond_to?(:roots_of)
            pk = l.make_pokemon(d, level, trainer, data)
            pk.instance_variable_set(ADDED, true)
            hold(pk, party, rng)
            party << pk
          end
        rescue StandardError => e
          Reloaded::Log.exception("Trainer Control couldn't add to #{type} #{name}'s team", e, :trainer_control)
        end

        # The same for a save and a person, every battle
        def seed(key, version)
          id = ($Trainer.id rescue 0).to_i
          return (key.to_s.sum * 7919 + version.to_i * 104_729 + id) & 0x7FFFFFFF
        end

        # One Pokémon's dex number, or nil
        def pick(mode, type, level, target, fused, used, roots, rng)
          l = lt
          if mode == :local
            d = local(type, level, used, rng)
            return d if d
          end
          frac = mode == :fusion ? 1.0 : fused
          return l.pick_one(mode == :random || mode == :fusion ? nil : type, level, target, frac, used, roots, rng)
        end

        # The class's type among the wild Pokémon of this map (the game's
        # tables, randomized ones too), evolved as far as the level allows
        def local(type, level, used, rng)
          l = lt
          tables = $PokemonEncounters ? ($PokemonEncounters.instance_variable_get(:@encounter_tables) || {}) : {}
          found = tables.values.flatten(1).map { |e| e.is_a?(Array) ? e[1] : nil }.compact.uniq
          dexes = found.map { |sp| (l.dex(sp) rescue 0) }.select { |d| d > 0 }
          dexes = dexes.select { |d| l.has_type?(d, type) } if type
          dexes = dexes.map { |d| l.fit_level(d, level, rng) }.uniq
          dexes.reject! { |d| used.include?(d) || l.legendary?(d) || l.banned?(d) }
          return dexes.empty? ? nil : dexes[rng.rand(dexes.length)]
        rescue StandardError
          return nil
        end

        # A held item: a chance by badges (none before 2, 25% at 4, 50%
        # from 8), by its role and type; the Randomizer's random held items
        # when they're on
        def hold_chance
          b = ($Trainer.badge_count rescue 0).to_i
          return 0.0 if b < 2
          return (b - 2) * 0.125 if b < 4
          return [0.25 + (b - 4) * 0.0625, 0.5].min
        end

        def hold(pk, party, rng)
          if defined?(::SWITCH_RANDOM_HELD_ITEMS) && ($game_switches[::SWITCH_RANDOM_HELD_ITEMS] rescue false)
            pk.item = pbGetRandomHeldItem.id
            return
          end
          return unless rng.rand < hold_chance
          taken = party.map { |p| (p.item_id rescue nil) }.compact.map(&:to_s)
          list = item_choices(pk).reject { |i| taken.include?(i.to_s) }
          pk.item = list[rng.rand(list.length)] unless list.empty?
        rescue StandardError
          nil
        end

        def item_choices(pk)
          counts = Hash.new(0)
          Array(pk.moves).each do |m|
            d = (::GameData::Move.try_get(m.id) rescue nil)
            next unless d
            role = if d.base_damage.to_i <= 0 then :status
                   elsif d.respond_to?(:physical?) && d.physical? then :physical
                   else :special
                   end
            counts[role] += 1
          end
          role = if counts[:status] >= 2 then :status
                 elsif counts[:physical] > counts[:special] then :physical
                 elsif counts[:special] > counts[:physical] then :special
                 else :mixed
                 end
          types = (pk.types rescue [pk.type1, pk.type2]) || []
          out = ALL_ROLES + ROLE_ITEMS[role] + Array(types).compact.map { |t| TYPE_ITEMS[t] }.compact
          return out.uniq.select { |i| (::GameData::Item.exists?(i) rescue false) }
        end
      end
    end
  end
end
