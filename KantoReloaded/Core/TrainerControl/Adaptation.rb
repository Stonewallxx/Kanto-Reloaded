# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Trainer Control's Adaptation (required, always on)
#==============================================================================
# His picks (Roadmap Designs topic trainer-control, 2026-10-30): trainers
# learn from you.
#
#   First meetings  word gets around: from 2 badges, one change from your
#                   habits (your last 5 trainer battles: your lead, the move
#                   types you used most, your strongest Pokémon), a lead
#                   that beats yours, a move it can learn that hits your
#                   lead, or a berry against your favourite type (an Occa
#                   Berry against your Fire). Never a new Pokémon.
#   Rematches       their own memory of you: each win over them adds 3
#                   changes (4 from the seventh), kept and built up to 2
#                   per Pokémon plus the counter Pokémon; the oldest go
#                   first. Nothing changes after you lose to them.
#   What changes    half answer your habits (a resist berry, a counter move,
#                   a lead, the counter Pokémon), half follow their class
#                   (Hikers bulk up, Psychics favour status, Ace Trainers
#                   items, the rest hit harder): held and battle items,
#                   counter and utility moves, an evolution, a stronger
#                   level-up move. Their ace is never replaced.
#   Leaders, rival  one more change (2 on a first meeting from 2 badges);
#                   leaders take the counter Pokémon only while your win
#                   streak (the Trainer Card's) is 10 or more.
#   The counter     a fusion of their class's type and a type that beats
#                   your lead, as strong as their team, at its level; it
#                   joins, or takes the weakest one's place on a full team.
#   Reloads         every roll comes from the save, the person and the win
#                   count: a reload gives the same team. One memory per
#                   person (all their versions share it).
#   Shown           not to players. With Kanto Reloaded Debug installed,
#                   Battle Info marks what adapted once the battle shows it
#                   ("Occa Berry (Answers Your Fire)", "Rock Slide (Adapted)").
#
# A record keeps its memory as plain values:
#   "adapt" => { "changes" => [{ "kind", "slot", "move" / "item" / "why", "at" }],
#                "counter" => { "dex", "at" }, "seen" => [habits, ...] }
#==============================================================================

module Reloaded
  module TrainerControl
    module Adaptation
      FIRST_BADGES = 2                    # first meetings adapt from 2 badges
      HABITS = 5                          # your last 5 trainer battles
      PER_SLOT = 2
      LEADER_STREAK = 10                  # leaders take the counter at this win streak
      MARK = :@kr_tc_adapted              # on a changed Pokémon: { "item" => why, "moves" => [ids] }
      RESIST_BERRIES = { :NORMAL => :CHILANBERRY, :FIRE => :OCCABERRY, :WATER => :PASSHOBERRY, :ELECTRIC => :WACANBERRY,
                         :GRASS => :RINDOBERRY, :ICE => :YACHEBERRY, :FIGHTING => :CHOPLEBERRY, :POISON => :KEBIABERRY,
                         :GROUND => :SHUCABERRY, :FLYING => :COBABERRY, :PSYCHIC => :PAYAPABERRY, :BUG => :TANGABERRY,
                         :ROCK => :CHARTIBERRY, :GHOST => :KASIBBERRY, :DRAGON => :HABANBERRY, :DARK => :COLBURBERRY,
                         :STEEL => :BABIRIBERRY, :FAIRY => :ROSELIBERRY }.freeze
      BATTLE_ITEMS = [:HYPERPOTION, :FULLHEAL, :FULLRESTORE, :XATTACK, :XDEFENSE, :XSPEED, :XSPATK].freeze
      # Old KR's class personalities
      PERSONALITY = {
        :bulk => /\A(HIKER|BLACKBELT|SAILOR|CRUSH|CUEBALL|ROUGHNECK|ENGINEER|WORKER|FISHERMAN)/,
        :status => /\A(PSYCHIC|CHANNELER|SAGE|HAUNTED|JUGGLER|MEDIUM|HEXMANIAC|SCIENTIST|BURGLAR)/,
        :items => /\A(COOLTRAINER|ACETRAINER|GENTLEMAN|BEAUTY|RICH|LADY|SOCIALITE|LEADER_|ELITEFOUR|CHAMPION|ROCKETBOSS|RIVAL)/
      }.freeze
      KINDS = { :bulk => [:bulk_item, :bulk_move, :evolution], :status => [:utility_move, :utility_move, :held_item],
                :items => [:held_item, :battle_item, :stronger_move], :hard => [:stronger_move, :evolution, :held_item] }.freeze
      BULK_ITEMS = [:LEFTOVERS, :SITRUSBERRY, :ROCKYHELMET].freeze
      ROLE_ITEMS = [:LIFEORB, :EXPERTBELT, :SITRUSBERRY, :LUMBERRY, :SCOPELENS, :SHELLBELL, :QUICKCLAW].freeze
      BULK_MOVES = [:BULKUP, :IRONDEFENSE, :AMNESIA, :HARDEN, :DEFENSECURL, :REST, :PROTECT].freeze
      STATUS_MOVES = [:THUNDERWAVE, :HYPNOSIS, :TOXIC, :WILLOWISP, :CONFUSERAY, :SLEEPPOWDER, :STUNSPORE, :GLARE].freeze

      class << self
        def install
          Reloaded::Events.on(:trainer_battle_ended, :trainer_control_adaptation, 105) { |c| battle_ended(c) }
          return unless defined?(::PokeBattle_Battler) && TrainerControl.defined_method?(::PokeBattle_Battler, :pbUseMove)
          Reloaded::Hooks.prepend(nil, ::PokeBattle_Battler, MoveWatch, :id => :trainer_control_moves)
        end

        def seed(*parts)
          id = ($Trainer.id rescue 0).to_i
          return (parts.join("|").sum * 2_654_435 + id) & 0x7FFFFFFF
        end

        def badges
          return ($Trainer.badge_count rescue 0).to_i
        end

        def streak
          return defined?(Reloaded::TrainerCard::Counters) ? Reloaded::TrainerCard::Counters.get(:streak).to_i : 0
        end

        def personality(type)
          PERSONALITY.each { |k, re| return k if type.to_s =~ re }
          return :hard
        end

        def debug_marks?
          return defined?(::KRDebug) ? true : false
        end

        #----------------------------------------------------------------------
        # Your habits: what each trainer battle showed (your lead, the move
        # types you used, your strongest Pokémon's types)
        #----------------------------------------------------------------------
        def types_of(pk)
          return [] unless pk
          t = (pk.types rescue nil) || [(pk.type1 rescue nil), (pk.type2 rescue nil)]
          return Array(t).compact.uniq
        end

        def battle_habit(battle)
          party = Array($Trainer ? ($Trainer.party rescue []) : []).compact.reject { |p| p.egg? }
          lead = battle.instance_variable_get(:@kr_tc_lead) || party.first
          top = party.max_by { |p| p.level.to_i }
          moves = battle.instance_variable_get(:@kr_tc_moves) || {}
          return { "lead" => types_of(lead).map(&:to_s), "moves" => moves.dup, "top" => types_of(top).map(&:to_s) }
        end

        def battle_ended(context)
          battle = context[:battle]
          people = Array(context[:people])
          d = Records.data
          return if d.nil? || people.empty? || context[:won].nil?
          habit = battle_habit(battle)
          list = (d["habits"] ||= [])
          list << habit
          list.shift while list.length > HABITS
          people.each do |key|
            rec = Records.get(key)
            next unless rec
            mem = (rec["adapt"] ||= {})
            seen = (mem["seen"] ||= [])
            seen << habit
            seen.shift while seen.length > 3
            learn(rec, key) if context[:won]                  # nothing after you lose to them
          end
        rescue StandardError => e
          Reloaded::Log.exception("Trainer Control couldn't remember a battle", e, :trainer_control)
        end

        # A summary of some habits: [lead types, move types most used first,
        # strongest's types]
        def summary(habits)
          leads = Hash.new(0)
          moves = Hash.new(0)
          tops = Hash.new(0)
          Array(habits).each do |h|
            Array(h["lead"]).each { |t| leads[t] += 1 }
            (h["moves"] || {}).each { |t, n| moves[t] += n.to_i }
            Array(h["top"]).each { |t| tops[t] += 1 }
          end
          order = proc { |hh| hh.sort_by { |t, n| [-n, t.to_s] }.map { |t, _n| t.to_s.to_sym } }
          return [order.call(leads), order.call(moves), order.call(tops)]
        end

        #----------------------------------------------------------------------
        # Learning, after a win over them
        #----------------------------------------------------------------------
        def learn(rec, key)
          mem = rec["adapt"]
          kind = TrainerControl.kind(rec["type"])
          wins = rec["wins"].to_i
          n = (wins >= 7 ? 4 : 3) + (kind == :trainer ? 0 : 1)
          rng = Random.new(seed(key, wins))
          habits = summary(mem["seen"])
          habits = summary((Records.data || {})["habits"]) if habits.all?(&:empty?)
          size = Array(rec["team"]).length
          changes = (mem["changes"] ||= [])
          n.times do |i|
            counter = i.even?
            ch = counter ? counterplay_change(habits, rng, size, true) : personality_change(rec["type"], rng, size)
            next unless ch
            if ch["kind"] == "counter"
              mem["counter"] = { "lead" => habits[0].map(&:to_s), "at" => wins }
              next
            end
            ch["at"] = wins
            same = changes.select { |c| c["slot"] == ch["slot"] }
            changes.delete(same.min_by { |c| c["at"].to_i }) if same.length >= PER_SLOT
            changes << ch
          end
        end

        # A change answering your habits; a counter Pokémon only on rematches
        def counterplay_change(habits, rng, size, rematch)
          leads, moves, _tops = habits
          opts = []
          opts << "berry" unless moves.empty?
          opts << "counter_move" unless leads.empty?
          opts << "lead" unless leads.empty?
          opts << "counter" if rematch && !leads.empty? && rng.rand(3) == 0
          return nil if opts.empty?
          pick = opts[rng.rand(opts.length)]
          slot = rng.rand([size, 1].max)
          case pick
          when "berry" then return { "kind" => "berry", "slot" => slot, "type" => moves[0].to_s }
          when "counter_move" then return { "kind" => "counter_move", "slot" => slot, "type" => leads[0].to_s }
          when "lead" then return { "kind" => "lead", "slot" => nil, "type" => leads[0].to_s }
          end
          return { "kind" => "counter" }
        end

        def personality_change(type, rng, size)
          list = KINDS[personality(type)]
          kind = list[rng.rand(list.length)].to_s
          return { "kind" => kind, "slot" => kind == "battle_item" ? nil : rng.rand([size, 1].max), "roll" => rng.rand(1000) }
        end

        #----------------------------------------------------------------------
        # Applying it as the team loads (after Team Expansion, before Level
        # Scaling)
        #----------------------------------------------------------------------
        def apply(trainer, type, name, version)
          party = trainer ? trainer.party : nil
          return unless party.is_a?(Array) && !party.empty? && Records.data
          key = TrainerControl.person_key(type, name)
          return unless key
          rec = Records.get(key)
          kind = TrainerControl.kind(type)
          if rec.nil? || Records.battles(rec) == 0
            first_meeting(trainer, key, kind)
            return
          end
          mem = rec["adapt"] || {}
          Array(mem["changes"]).each_with_index do |ch, i|
            apply_change(trainer, ch, Random.new(seed(key, ch["at"], i)))
          end
          counter = mem["counter"]
          if counter && (kind == :trainer || kind == :rival || streak >= LEADER_STREAK)
            add_counter(trainer, type, counter, Random.new(seed(key, "counter", counter["at"])))
          end
        rescue StandardError => e
          Reloaded::Log.exception("Trainer Control couldn't adapt #{type} #{name}", e, :trainer_control)
        end

        # Word gets around: from 2 badges, one change (leaders and your
        # rival: 2) from your last battles; never a new Pokémon
        def first_meeting(trainer, key, kind)
          return if badges < FIRST_BADGES
          habits = summary((Records.data || {})["habits"])
          return if habits.all?(&:empty?)
          rng = Random.new(seed(key, "first", badges))
          (kind == :trainer ? 1 : 2).times do |i|
            ch = counterplay_change(habits, rng, trainer.party.length, false)
            apply_change(trainer, ch, Random.new(seed(key, "first", i))) if ch
          end
        end

        def ace_index(party)
          return party.each_with_index.max_by { |pk, _i| pk.level.to_i }[1]
        end

        def apply_change(trainer, ch, rng)
          party = trainer.party
          slot = ch["slot"]
          pk = slot.nil? ? nil : party[slot.to_i % party.length]
          case ch["kind"]
          when "berry"
            berry = RESIST_BERRIES[ch["type"].to_s.to_sym]
            give_item(pk, berry, _INTL("Answers Your {1}", type_name(ch["type"]))) if berry && pk
          when "counter_move"
            move = counter_move(pk, ch["type"].to_s.to_sym, rng) if pk
            teach(pk, move) if move
          when "lead" then lead_swap(party, ch["type"].to_s.to_sym)
          when "bulk_item" then give_item(pk, BULK_ITEMS[ch["roll"].to_i % BULK_ITEMS.length], _INTL("Adapted")) if pk
          when "held_item" then give_item(pk, ROLE_ITEMS[ch["roll"].to_i % ROLE_ITEMS.length], _INTL("Adapted")) if pk
          when "bulk_move" then teach(pk, learnable(pk, BULK_MOVES, ch["roll"])) if pk
          when "utility_move" then teach(pk, learnable(pk, STATUS_MOVES, ch["roll"])) if pk
          when "battle_item"
            item = BATTLE_ITEMS[ch["roll"].to_i % BATTLE_ITEMS.length]
            trainer.items << item if trainer.respond_to?(:items) && trainer.items.is_a?(Array) && item_exists?(item)
          when "evolution" then evolve(pk, rng) if pk
          when "stronger_move" then stronger_move(pk) if pk
          end
        rescue StandardError
          nil
        end

        def type_name(t)
          return (::GameData::Type.get(t.to_s.to_sym).name rescue t.to_s.capitalize)
        end

        def item_exists?(item)
          return (::GameData::Item.exists?(item) rescue false)
        end

        def mark(pk)
          m = pk.instance_variable_get(MARK)
          return m || pk.instance_variable_set(MARK, { "item" => nil, "moves" => [] })
        end

        def give_item(pk, item, why)
          return unless pk && item && item_exists?(item)
          pk.item = item
          mark(pk)["item"] = why
        end

        # A move it can really learn that hits this type hard (damaging, of
        # a type super effective on it)
        def counter_move(pk, target, rng)
          list = counter_moves(target).select { |m| !pk.hasMove?(m) && (pk.compatible_with_move?(m) rescue false) }
          return list.empty? ? nil : list[rng.rand(list.length)]
        end

        def counter_moves(target)
          @counters ||= {}
          return @counters[target] if @counters.key?(target)
          out = []
          ::GameData::Move.each do |m|
            next unless m.base_damage.to_i.between?(55, 100) && m.accuracy.to_i >= 85
            next unless (Effectiveness.super_effective_type?(m.type, target) rescue false)
            out << m.id
          end
          return @counters[target] = out
        rescue StandardError
          return @counters[target] = []
        end

        # The first of these it can learn, from a roll
        def learnable(pk, list, roll)
          rot = list.rotate(roll.to_i % list.length)
          return rot.find { |m| (::GameData::Move.exists?(m) rescue false) && !pk.hasMove?(m) && (pk.compatible_with_move?(m) rescue false) }
        end

        # A new move in place of its weakest (status moves count as weakest)
        def teach(pk, move)
          return unless pk && move
          moves = pk.moves
          if moves.length < 4
            pk.learn_move(move)
          else
            weakest = (0...moves.length).min_by { |i| (::GameData::Move.get(moves[i].id).base_damage rescue 0).to_i }
            moves[weakest] = ::Pokemon::Move.new(move)
          end
          mark(pk)["moves"] << move.to_s
        end

        # A lead that beats yours: the one whose types hit your lead's hardest
        def lead_swap(party, target)
          best = party.each_index.max_by do |i|
            types_of(party[i]).sum { |t| (Effectiveness.calculate(t, target) rescue 0).to_i }
          end
          return unless best && best > 0
          party.unshift(party.delete_at(best))
        end

        def evolve(pk, rng)
          sp = LevelScaling.stage_for(pk.species, pk.level.to_i + 5, rng)
          return unless sp && sp != pk.species
          pk.species = sp
          pk.calc_stats
          pk.hp = pk.totalhp
        end

        # Its strongest level-up move it's reached and doesn't know, in place
        # of its weakest damaging one
        def stronger_move(pk)
          list = (pk.getMoveList rescue [])
          best = list.select { |lv, _m| lv.to_i <= pk.level.to_i }.map { |_lv, m| m }.uniq.reject { |m| pk.hasMove?(m) }
          best = best.max_by { |m| (::GameData::Move.get(m).base_damage rescue 0).to_i }
          return unless best && (::GameData::Move.get(best).base_damage rescue 0).to_i > 0
          teach(pk, best)
        end

        #----------------------------------------------------------------------
        # The counter Pokémon: their class's type fused with a type that
        # beats your lead; it joins, or takes the weakest one's place
        #----------------------------------------------------------------------
        def beater(lead)
          types = []
          ::GameData::Type.each { |t| types << t.id unless (t.pseudo_type rescue false) }
          return types.select { |t| (Effectiveness.super_effective_type?(t, *lead.first(2)) rescue false) }
        end

        def add_counter(trainer, type, counter, rng)
          lt = defined?(::KIF::LeaderTeams) ? ::KIF::LeaderTeams : nil
          party = trainer.party
          lead = Array(counter["lead"]).map(&:to_sym)
          return unless lt && !lead.empty?
          theme = TrainerControl.theme_type(type, party.map { |p| [p.species, p.level] })
          beats = beater(lead)
          return if beats.empty?
          b = beats[rng.rand(beats.length)]
          level = (party.sum { |p| p.level.to_i }.to_f / party.length).round
          target = party.sum { |p| lt.bst(lt.dex(p.species)) }.to_f / party.length
          used = party.map { |p| lt.dex(p.species) }
          x = lt.pick_one(theme || b, level, target, 0.0, used, [], rng)
          y = lt.pick_one(b, level, target, 0.0, used + [x].compact, [], rng)
          return unless x && y
          d = defined?(::KIF::Rand) && ::KIF::Rand.respond_to?(:fuse) ? ::KIF::Rand.fuse(x, y) : x
          d = ::KIF::Rand.fuse(y, x) if defined?(::KIF::Rand) && ::KIF::Rand.respond_to?(:fuse) && !lt.has_type?(d, b)
          pk = lt.make_pokemon(d, level, trainer, nil)
          mark(pk)["counter"] = true
          if party.length >= TeamExpansion::MAX
            ace = ace_index(party)
            weakest = (0...party.length).reject { |i| i == ace }.min_by { |i| party[i].level.to_i }
            party[weakest] = pk
          else
            party << pk
          end
        rescue StandardError => e
          Reloaded::Log.warning_once("Trainer Control's counter Pokémon couldn't be made: #{e.message}", :trainer_control)
        end
      end

      # Your Pokémon's moves in a trainer battle, by type (your habits)
      module MoveWatch
        def pbUseMove(choice, *args)
          begin
            if pbOwnedByPlayer? && (@battle.trainerBattle? rescue false) && choice.is_a?(Array) && choice[2]
              t = (choice[2].type rescue nil)
              if t
                tally = @battle.instance_variable_get(:@kr_tc_moves) || @battle.instance_variable_set(:@kr_tc_moves, {})
                tally[t.to_s] = tally[t.to_s].to_i + 1
              end
            end
          rescue StandardError
            nil
          end
          super
        end
      end
    end
  end
end
