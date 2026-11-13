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
#                   lead, one that hits your strongest when it isn't your
#                   lead (his pick, 2026-11-09), or a berry against your
#                   favourite type (an Occa Berry against your Fire). Never
#                   a new Pokémon.
#   Rematches       their own memory of you: each win over them adds 2
#                   changes (his call, 2026-11-09: was 3, 4 from the
#                   seventh), kept and built up to 2 per Pokémon plus one
#                   lead change, 2 bag items (their own room: his pick) and
#                   the counter Pokémon; the oldest go first. An evolution stays
#                   for good, outside the 2 (his pick, 2026-11-09), one
#                   stage at a time (his pick: a later one goes further). Each
#                   change is one that does something to their team as it
#                   was (his pick: a berry on one weak to it, a move on one
#                   that can learn it...), else another is rolled. Nothing
#                   changes after you lose to them.
#   What changes    half answer your habits (a resist berry, a counter move,
#                   a lead, the counter Pokémon), half any of what a
#                   trainer can do (held and battle items, bulk and utility
#                   moves, an evolution, a stronger level-up move), their
#                   class's own 3 times as likely (his pick, 2026-11-09:
#                   Hikers bulk up, Psychics and Team Rocket favour status,
#                   Cooltrainers and Type Experts items, the rest hit
#                   harder). Their ace is never replaced.
#   Easy            lighter (his pick, 2026-11-09): no first meetings, one
#                   change fewer from each win, no counter Pokémon.
#   Leaders, rival  one more change (2 on a first meeting from 2 badges);
#                   leaders take the counter Pokémon only once you're Feared
#                   (Notoriety; it was a 10-win streak before).
#   Notoriety       Known: one more change for every trainer, on a first
#                   meeting and from each win.
#   The counter     a fusion of their class's type and a type that beats
#                   your lead, as strong as their team, at its level; it
#                   takes their lowest-level one's place, never the ace's
#                   (his pick, 2026-11-09; only an ace: it joins).
#   Reloads         every roll comes from the save, the person and the win
#                   count: a reload gives the same team. One memory per
#                   person (all their versions share it).
#   Shown           once the battle reveals it, a purple ADAPTED pill on
#                   Battle Info's tab for that Pokémon, for every player (his
#                   pick, 2026-11-09, Design 2; it was KR Debug's only).
#                   Kanto Reloaded Debug's Trainer Inspector and Team Drawer
#                   show every change with its reason (the mark's notes).
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
      PER_WIN = 2                         # changes from each win (his call, 2026-11-09: was 3, 4 from the seventh)
      TRIES = 6                           # rolls for a change that does something, before it's skipped
      ITEM_KINDS = %w[berry bulk_item held_item].freeze
      MARK = :@kr_tc_adapted              # on a changed Pokémon: { "item" => why, "moves" => [ids],
                                          #   "notes" => [{ "kind", "what", "why", "first" }] }
      BAG = :@kr_tc_bag                   # on the trainer: battle items it was given [[item, why], ...]
      SLOT = :@kr_tc_slot                 # on a loaded Pokémon: the place its changes are rolled for
      SOME_POWER = 60                     # a move of no set power (Magnitude, Low Kick...) counts as this
      RESIST_BERRIES = { :NORMAL => :CHILANBERRY, :FIRE => :OCCABERRY, :WATER => :PASSHOBERRY, :ELECTRIC => :WACANBERRY,
                         :GRASS => :RINDOBERRY, :ICE => :YACHEBERRY, :FIGHTING => :CHOPLEBERRY, :POISON => :KEBIABERRY,
                         :GROUND => :SHUCABERRY, :FLYING => :COBABERRY, :PSYCHIC => :PAYAPABERRY, :BUG => :TANGABERRY,
                         :ROCK => :CHARTIBERRY, :GHOST => :KASIBBERRY, :DRAGON => :HABANBERRY, :DARK => :COLBURBERRY,
                         :STEEL => :BABIRIBERRY, :FAIRY => :ROSELIBERRY }.freeze
      BATTLE_ITEMS = [:HYPERPOTION, :FULLHEAL, :FULLRESTORE, :XATTACK, :XDEFENSE, :XSPEED, :XSPATK].freeze
      # Old KR's class personalities
      # (regrouped, his pick 2026-11-09: classes the game hasn't got gone;
      # Team Rocket and Plasma's grunts play dirty, its executives carry items)
      PERSONALITY = {
        :bulk => /\A(HIKER|BLACKBELT|SAILOR|CRUSH|CUEBALL|ROUGHNECK|ENGINEER|WORKER|FISHERMAN|BIKER|POLICE|TAMER|FARMER)/,
        :status => /\A(PSYCHIC|CHANNELER|SAGE|HAUNTED|JUGGLER|SCIENTIST|BURGLAR|SUPERNERD|KIMONOGIRL|MYSTICALMAN|TEAMROCKET|TEAMPLASMA)/,
        :items => /\A(COOLTRAINER|GENTLEMAN|BEAUTY|LADY|SOCIALITE|LEADER_|ELITEFOUR|CHAMPION|ROCKETBOSS|RIVAL|POKEMONRANGER|GAMBLER|AROMALADY|POKEMONBREEDER|TYPE_EXPERT|ROCKETEXEC)/
      }.freeze
      # Every trainer can get any of these; their class's are 3 times as
      # likely (his pick, 2026-11-09)
      ALL_KINDS = %w[bulk_item held_item battle_item bulk_move utility_move stronger_move evolution].freeze
      LEAN = 2                            # each time a kind is in their class's list: this much more likely
      KIND_WORDS = { "bulk_item" => "Bulking Up", "bulk_move" => "Bulking Up", "utility_move" => "Trying Status",
                     "held_item" => "Carrying Items", "battle_item" => "Carrying Items",
                     "stronger_move" => "Hitting Harder", "evolution" => "Hitting Harder" }.freeze
      KINDS = { :bulk => [:bulk_item, :bulk_move, :evolution], :status => [:utility_move, :utility_move, :held_item],
                :items => [:held_item, :battle_item, :stronger_move], :hard => [:stronger_move, :evolution, :held_item] }.freeze
      BULK_ITEMS = [:LEFTOVERS, :SITRUSBERRY, :ROCKYHELMET].freeze
      ROLE_ITEMS = [:LIFEORB, :EXPERTBELT, :SITRUSBERRY, :LUMBERRY, :SCOPELENS, :SHELLBELL, :QUICKCLAW].freeze
      BULK_MOVES = [:BULKUP, :IRONDEFENSE, :AMNESIA, :HARDEN, :DEFENSECURL, :REST, :PROTECT].freeze
      STATUS_MOVES = [:THUNDERWAVE, :HYPNOSIS, :TOXIC, :WILLOWISP, :CONFUSERAY, :SLEEPPOWDER, :STUNSPORE, :GLARE].freeze
      # A class's habit, for a change's reason ("Hikers Bulk Up")
      HABIT_WORDS = { :bulk => "{1} Bulk Up", :status => "{1} Favour Status", :items => "{1} Carry Items", :hard => "{1} Hit Harder" }.freeze

      class << self
        def install
          Reloaded::Events.on(:trainer_battle_ended, :trainer_control_adaptation, 105) { |c| battle_ended(c) }
          h = Reloaded::Hooks
          if defined?(::PokeBattle_Battle) && TrainerControl.defined_method?(::PokeBattle_Battle, :pbOnActiveAll)
            h.prepend(nil, ::PokeBattle_Battle, LeadWatch, :id => :trainer_control_lead)
          end
          # cody's C-BATTLE-02 keeps each trainer Pokémon's rolls (ability,
          # personal ID, shininess) by its place in the team; a lead swap
          # mustn't hand them to another Pokémon
          if defined?(::KIF::TrainerRolls) && ::KIF::TrainerRolls.respond_to?(:apply)
            h.prepend(nil, ::KIF::TrainerRolls.singleton_class, RollsByPlace, :id => :trainer_control_rolls_by_place)
          end
          return unless defined?(::PokeBattle_Battler) && TrainerControl.defined_method?(::PokeBattle_Battler, :pbUseMove)
          h.prepend(nil, ::PokeBattle_Battler, MoveWatch, :id => :trainer_control_moves)
        end

        # A trainer's team in its written order for cody's rolls: each
        # Pokémon at its place in the data, the rest (a counter that took a
        # place, Team Expansion's) in the gaps and after
        def written_order(party)
          tag = LeaderBuilds::DATA
          placed = party.select { |p| p && p.instance_variable_defined?(tag) }
          return nil if placed.empty?
          rest = party.reject { |p| placed.any? { |q| q.equal?(p) } }
          slots = []
          placed.each { |p| slots[p.instance_variable_get(tag).to_i] = p }
          slots.each_index { |i| slots[i] ||= rest.shift }
          return slots.compact + rest
        end

        def seed(*parts)
          id = ($Trainer.id rescue 0).to_i
          return (parts.join("|").sum * 2_654_435 + id) & 0x7FFFFFFF
        end

        def badges
          return ($Trainer.badge_count rescue 0).to_i
        end

        # Easy (his pick, 2026-11-09): lighter, no first meetings, one change
        # fewer from each win, no counter Pokémon
        def easy?
          return defined?(Reloaded::Difficulty) && Reloaded::Difficulty.respond_to?(:level) && Reloaded::Difficulty.level.to_i == 0 ? true : false
        rescue StandardError
          return false
        end

        # Notoriety's Known: one more change
        def notoriety_changes
          return defined?(Notoriety) ? Notoriety.extra_changes : 0
        end

        # Notoriety's Feared: leaders bring their counter Pokémon
        def leaders_counter?
          return defined?(Notoriety) && Notoriety.feared? ? true : false
        end

        def personality(type)
          PERSONALITY.each { |k, re| return k if type.to_s =~ re }
          return :hard
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

        # One of your moves, after it's used: counted when it was damaging,
        # didn't fail and a foe lost HP to it, by the type it hit with.
        # before: [[foe, its HP before], ...]
        def tally(user, move, before)
          return unless move && (move.damagingMove? rescue false)
          return if (user.lastMoveFailed rescue false)
          return unless Array(before).any? { |b, hp| b.hp.to_i < hp.to_i }
          t = (user.lastMoveUsedType rescue nil) || (move.calcType rescue nil) || (move.type rescue nil)
          return unless t
          battle = user.battle
          moves = battle.instance_variable_get(:@kr_tc_moves) || battle.instance_variable_set(:@kr_tc_moves, {})
          moves[t.to_s] = moves[t.to_s].to_i + 1
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
            learn(rec, key, team_of(battle, key)) if context[:won]     # nothing after you lose to them
          end
        rescue StandardError => e
          Reloaded::Log.exception("Trainer Control couldn't remember a battle", e, :trainer_control)
        end

        # Their team as this battle had it, in the places their changes go
        # (SLOT, given as it loaded; a team Adaptation didn't load: as it is)
        def team_of(battle, key)
          tr = Array(battle && battle.opponent).find { |t| (TrainerControl.person(t) rescue nil) == key }
          party = tr ? Array(tr.party).compact : []
          return party.each_with_index.sort_by { |pk, i| [pk.instance_variable_get(SLOT) || 1000 + i, i] }.map(&:first)
        end

        def tag_places(party)
          party.each_with_index { |pk, i| pk.instance_variable_set(SLOT, i) if pk }
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
        # team: their Pokémon as the battle had them, in place order (each
        # change is one that does something to them; none: the old way)
        def learn(rec, key, team = nil)
          mem = rec["adapt"]
          kind = TrainerControl.kind(rec["type"])
          wins = rec["wins"].to_i
          n = PER_WIN - (easy? ? 1 : 0) + (kind == :trainer ? 0 : 1) + notoriety_changes
          rng = Random.new(seed(key, wins))
          habits = summary(mem["seen"])
          habits = summary((Records.data || {})["habits"]) if habits.all?(&:empty?)
          team = Array(team).compact
          size = team.empty? ? Array(rec["team"]).length : team.length
          changes = (mem["changes"] ||= [])
          strong = strongest_target(mem["seen"])
          n.times do |i|
            counter = i.even?
            ch = nil
            TRIES.times do
              c = counter ? counterplay_change(habits, rng, size, !easy?, strong) : personality_change(rec["type"], rng, size)
              break unless c
              c = fit(c, team, changes, rng) unless team.empty?
              next unless c
              ch = c
              break
            end
            next unless ch
            if ch["kind"] == "counter"
              mem["counter"] = { "lead" => main_lead(mem["seen"]).map(&:to_s), "at" => wins }
              next
            end
            ch["at"] = wins
            keep(changes, ch, rec["type"])
          end
        end

        # A learned change kept. An evolution stays for good and takes none of
        # the Pokémon's 2 places (his pick, 2026-11-09: a trainer's Pokémon
        # never goes back a stage); a second one on the same Pokémon is its
        # next stage (one stage at a time). Anything else takes a place, the
        # Pokémon's oldest going.
        # A lead change and the bag items have their own room (his pick,
        # 2026-11-09): the newest lead change replaces the old, bag items
        # keep 2 of their own.
        def keep(changes, ch, _type = nil)
          if ch["kind"] == "lead"
            changes.reject! { |c| c["kind"] == "lead" }
          elsif !evolution?(ch)
            same = if ch["kind"] == "battle_item"
                     changes.select { |c| c["kind"] == "battle_item" }
                   else
                     changes.select { |c| !c["slot"].nil? && c["slot"] == ch["slot"] && !evolution?(c) }
                   end
            if same.length >= PER_SLOT
              old = same.min_by { |c| c["at"].to_i }
              changes.delete_at(changes.index { |c| c.equal?(old) })
            end
          end
          changes << ch
        end

        def evolution?(ch)
          return ch["kind"] == "evolution"
        end

        #----------------------------------------------------------------------
        # Every change does something (his pick, 2026-11-09): checked on
        # their team as it was, it goes where it works, else nil and another
        # is rolled. A berry on one weak to its type; a move on one that can
        # learn it (a stronger move only when it's stronger); an evolution on
        # one that can still evolve; an item on one without Adaptation's
        # item already; a lead only when one of theirs hits your lead hard
        # and isn't leading.
        #----------------------------------------------------------------------
        def fit(ch, team, changes, rng)
          kind = ch["kind"]
          return ch if kind == "counter" || kind == "battle_item"
          if kind == "lead"
            return nil if changes.any? { |c| c["kind"] == "lead" && c["type"].to_s == ch["type"].to_s }
            trial = team.dup
            lead_swap(trial, ch["type"].to_s.to_sym)
            return trial[0].equal?(team[0]) ? nil : ch
          end
          places = (0...team.length).select { |i| fits?(ch, team[i], i, changes) }
          return nil if places.empty?
          ch["slot"] = places[rng.rand(places.length)]
          return ch
        end

        def fits?(ch, pk, i, changes)
          return false unless pk
          on = changes.select { |c| c["slot"] == i }
          case ch["kind"]
          when "berry", "bulk_item", "held_item"
            return false if on.any? { |c| ITEM_KINDS.include?(c["kind"]) }
            return ch["kind"] != "berry" || weak_to_type?(pk, ch["type"])
          when "counter_move" then return !counter_move(pk, ch["type"].to_s.to_sym, Random.new(0)).nil?
          when "strongest_move" then return !counter_move(pk, Array(ch["types"]).map(&:to_sym), Random.new(0)).nil?
          when "bulk_move" then return !learnable(pk, BULK_MOVES, ch["roll"]).nil?
          when "utility_move" then return !learnable(pk, STATUS_MOVES, ch["roll"]).nil?
          when "stronger_move" then return !stronger_pick(pk).nil?
          when "evolution"                         # (its next stage: one it already took doesn't stop it)
            sp = next_stage(pk.species, pk.level.to_i + 5, Random.new(0))
            return !sp.nil? && sp != pk.species
          end
          return true
        rescue StandardError
          return false
        end

        # This type hits it hard (a resist berry would work on it)
        def weak_to_type?(pk, type)
          return (Effectiveness.super_effective_type?(type.to_s.to_sym, *types_of(pk).first(2)) rescue false) ? true : false
        end

        # The lead you use most, its whole typing (Fire/Flying for a
        # Charizard): what the counter Pokémon is made to beat. Not the types
        # of different leads put together (Fire from Charmander and Grass from
        # Oddish isn't one Pokémon).
        def main_lead(seen)
          return main_typing(seen, "lead")
        end

        # The typing seen most in one habit's field ("lead" or "top"), these
        # battles' else your last 5's
        def main_typing(seen, field)
          list = Array(seen).map { |h| Array(h[field]).map(&:to_s) }.reject(&:empty?)
          list = Array((Records.data || {})["habits"]).map { |h| Array(h[field]).map(&:to_s) }.reject(&:empty?) if list.empty?
          return [] if list.empty?
          counts = Hash.new(0)
          list.each { |l| counts[l] += 1 }
          best = counts.values.max
          return list.reverse.find { |l| counts[l] == best }       # (a tie: the latest)
        end

        # Your strongest Pokémon's typing when it isn't your lead's (his
        # pick, 2026-11-09: they can learn a move that hits it hard), else nil
        def strongest_target(seen)
          top = main_typing(seen, "top")
          return nil if top.empty? || top.sort == main_lead(seen).sort
          return top
        end

        # A change answering your habits; a counter Pokémon only on rematches.
        # strong: your strongest's typing when it isn't your lead's (or nil)
        def counterplay_change(habits, rng, size, rematch, strong = nil)
          leads, moves, _tops = habits
          opts = []
          opts << "berry" unless moves.empty?
          opts << "counter_move" unless leads.empty?
          opts << "lead" unless leads.empty?
          opts << "strongest_move" unless Array(strong).empty?
          opts << "counter" if rematch && !leads.empty? && rng.rand(3) == 0
          return nil if opts.empty?
          pick = opts[rng.rand(opts.length)]
          slot = rng.rand([size, 1].max)
          case pick
          when "berry" then return { "kind" => "berry", "slot" => slot, "type" => moves[0].to_s }
          when "counter_move" then return { "kind" => "counter_move", "slot" => slot, "type" => leads[0].to_s }
          when "lead" then return { "kind" => "lead", "slot" => nil, "type" => leads[0].to_s }
          when "strongest_move" then return { "kind" => "strongest_move", "slot" => slot, "types" => Array(strong).map(&:to_s) }
          end
          return { "kind" => "counter" }
        end

        # Any of the kinds, their class's leaning (his pick, 2026-11-09)
        def personality_change(type, rng, size)
          own = KINDS[personality(type)].map(&:to_s)
          bag = []
          ALL_KINDS.each { |k| (1 + LEAN * own.count(k)).times { bag << k } }
          kind = bag[rng.rand(bag.length)]
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
          mem = rec ? (rec["adapt"] || {}) : {}
          # Word that got around stays until they've learned from a win (a
          # loss to them changes nothing)
          if rec.nil? || Records.battles(rec) == 0 || (rec["wins"].to_i == 0 && Array(mem["changes"]).empty? && mem["counter"].nil?)
            tag_places(party)
            first_meeting(trainer, key, kind)
            return
          end
          # The counter Pokémon first: a place their memory rolled past the
          # team as written is the counter's (it's in the record's team)
          # it follows your lead (his pick, 2026-11-09): made each time against
          # the lead you've used most in your last 3 battles with them
          counter = mem["counter"]
          if counter && !easy? && (kind == :trainer || kind == :rival || leaders_counter?)
            lead = main_lead(mem["seen"])
            lead = Array(counter["lead"]).map(&:to_s) if lead.empty?
            add_counter(trainer, type, counter.merge("lead" => lead), Random.new(seed(key, "counter", counter["at"], lead.join("/"))))
          end
          # Each change on the Pokémon at its place in the team as it loads,
          # the lead swaps after (his pick, 2026-11-09): a swap dropped from
          # their memory never moves a change onto another Pokémon. Each roll
          # comes from the change itself, never its place in the list, so a
          # change dropped before it doesn't change what it does.
          tag_places(party)
          leads, rest = Array(mem["changes"]).partition { |ch| ch["kind"] == "lead" }
          (rest + leads).each do |ch|
            apply_change(trainer, ch, Random.new(seed(key, ch["at"], ch["kind"], ch["slot"], ch["roll"] || ch["type"])))
          end
        rescue StandardError => e
          Reloaded::Log.exception("Trainer Control couldn't adapt #{type} #{name}", e, :trainer_control)
        end

        # Word gets around: from 2 badges, one change (leaders and your
        # rival: 2) from your last battles; never a new Pokémon
        def first_meeting(trainer, key, kind)
          return if badges < FIRST_BADGES || easy?
          habits = summary((Records.data || {})["habits"])
          return if habits.all?(&:empty?)
          rng = Random.new(seed(key, "first", badges))
          party = trainer.party.compact
          picked = []
          strong = strongest_target((Records.data || {})["habits"])
          # each one that does something to this team (his pick), all chosen
          # before any goes on, the lead swap last
          ((kind == :trainer ? 1 : 2) + notoriety_changes).times do
            TRIES.times do
              c = counterplay_change(habits, rng, party.length, false, strong)
              break unless c
              c = fit(c, party, picked, rng)
              next unless c
              picked << c
              break
            end
          end
          leads, rest = picked.each_with_index.partition { |c, _i| c["kind"] == "lead" }
          (rest + leads).each { |c, i| apply_change(trainer, c, Random.new(seed(key, "first", i)), true) }
        end

        def ace_index(party)
          return party.each_with_index.max_by { |pk, _i| pk.level.to_i }[1]
        end

        # first: a first meeting's change (word got around)
        def apply_change(trainer, ch, rng, first = false)
          party = trainer.party
          slot = ch["slot"]
          pk = slot.nil? ? nil : party[slot.to_i % party.length]
          @first = first
          why = why_for(ch, trainer)
          case ch["kind"]
          when "berry"
            berry = RESIST_BERRIES[ch["type"].to_s.to_sym]
            give_item(pk, berry, why) if berry && pk
          when "counter_move"
            move = counter_move(pk, ch["type"].to_s.to_sym, rng) if pk
            teach(pk, move, why) if move
          when "strongest_move"
            move = counter_move(pk, Array(ch["types"]).map(&:to_sym), rng) if pk
            teach(pk, move, why) if move
          when "lead" then lead_swap(party, ch["type"].to_s.to_sym, why)
          when "bulk_item" then give_item(pk, BULK_ITEMS[ch["roll"].to_i % BULK_ITEMS.length], why) if pk
          when "held_item" then give_item(pk, ROLE_ITEMS[ch["roll"].to_i % ROLE_ITEMS.length], why) if pk
          when "bulk_move" then teach(pk, learnable(pk, BULK_MOVES, ch["roll"]), why) if pk
          when "utility_move" then teach(pk, learnable(pk, STATUS_MOVES, ch["roll"]), why) if pk
          when "battle_item"
            item = BATTLE_ITEMS[ch["roll"].to_i % BATTLE_ITEMS.length]
            if trainer.respond_to?(:items) && trainer.items.is_a?(Array) && item_exists?(item)
              trainer.items << item
              bag = trainer.instance_variable_get(BAG) || trainer.instance_variable_set(BAG, [])
              bag << [item.to_s, why]
            end
          when "evolution" then evolve(pk, rng, why) if pk
          when "stronger_move" then stronger_move(pk, why) if pk
          end
        rescue StandardError
          nil
        ensure
          @first = false
        end

        # A change's reason: what of yours it answers, or their class's habit
        def why_for(ch, trainer)
          case ch["kind"]
          when "berry" then return _INTL("Answers Your {1}", type_name(ch["type"]))
          when "counter_move" then return _INTL("Hits Your {1} Lead", type_name(ch["type"]))
          when "lead" then return _INTL("Leads Against Your {1}", type_name(ch["type"]))
          when "strongest_move" then return _INTL("Hits Your Strongest")
          end
          type = (trainer.trainer_type rescue nil)
          group = personality(type)
          # one of their class's own: its habit ("Hikers Bulk Up"); another: what it is
          return _INTL(KIND_WORDS[ch["kind"].to_s] || "Adapted") unless KINDS[group].map(&:to_s).include?(ch["kind"].to_s)
          return _INTL(HABIT_WORDS[group], class_plural(type))
        end

        # "Hikers", "Lasses", "Ladies", "Gentlemen"
        def class_plural(type)
          name = Records.class_name(type).to_s
          return _INTL("Trainers") if name.empty?
          return name.sub(/man\z/, "men") if name =~ /man\z/
          return name.sub(/y\z/, "ies") if name =~ /[^aeiou]y\z/
          return name + "es" if name =~ /(s|sh|ch|x)\z/
          return name + "s"
        end

        def type_name(t)
          return (::GameData::Type.get(t.to_s.to_sym).name rescue t.to_s.capitalize)
        end

        def item_exists?(item)
          return (::GameData::Item.exists?(item) rescue false)
        end

        def mark(pk)
          m = pk.instance_variable_get(MARK)
          return m || pk.instance_variable_set(MARK, { "item" => nil, "moves" => [], "notes" => [] })
        end

        # What changed on it and why (Kanto Reloaded Debug shows these)
        def note(pk, kind, what, why)
          n = { "kind" => kind, "what" => what ? what.to_s : nil, "why" => why.to_s }
          n["first"] = true if @first
          (mark(pk)["notes"] ||= []) << n
        end

        # (with the Randomizer's Held Items on it replaces the random item:
        # his pick, 2026-11-09, Adaptation's items win)
        def give_item(pk, item, why)
          return unless pk && item && item_exists?(item)
          pk.item = item
          mark(pk)["item"] = why
          mark(pk)["item_id"] = item.to_s           # (the reason is shown only while it still holds it)
          note(pk, "item", item, why)
        end

        # A move it can really learn that hits this type hard (damaging, of
        # a type super effective on it); target: a type, or a whole typing
        def counter_move(pk, target, rng)
          list = counter_moves(target).select { |m| !pk.hasMove?(m) && (pk.compatible_with_move?(m) rescue false) }
          return list.empty? ? nil : list[rng.rand(list.length)]
        end

        def counter_moves(target)
          @counters ||= {}
          return @counters[target] if @counters.key?(target)
          types = Array(target).first(2)
          out = []
          ::GameData::Move.each do |m|
            next unless m.base_damage.to_i.between?(55, 100) && m.accuracy.to_i >= 85
            next unless (Effectiveness.super_effective_type?(m.type, *types) rescue false)
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

        # A move's power for choosing (status 0; one of no set power, as if 60)
        def power(id)
          bd = (::GameData::Move.get(id.to_s.to_sym).base_damage rescue 0).to_i
          return bd == 1 ? SOME_POWER : bd
        end

        # Where a new move goes: a free place, else its weakest move that
        # Adaptation didn't teach (status moves count as weakest), so one
        # taught move never pushes out another
        def free_place(pk, damaging_only = false)
          moves = pk.moves
          return nil if moves.length < 4
          m = pk.instance_variable_get(MARK)                 # (read only: a check marks nothing)
          taught = m ? Array(m["moves"]).map(&:to_s) : []
          list = (0...moves.length).reject { |i| taught.include?(moves[i].id.to_s) }
          list = (0...moves.length).to_a if list.empty?
          list = list.select { |i| power(moves[i].id) > 0 } if damaging_only
          return list.min_by { |i| power(moves[i].id) }
        end

        def place_move(pk, move, at = nil)
          moves = pk.moves
          if moves.length < 4
            pk.learn_move(move)
          else
            at ||= free_place(pk)
            moves[at] = ::Pokemon::Move.new(move) if at
          end
        end

        # A new move in place of its weakest (status moves count as weakest)
        def teach(pk, move, why = nil, at = nil)
          return unless pk && move
          place_move(pk, move, at)
          mark(pk)["moves"] << move.to_s
          note(pk, "move", move, why || _INTL("Adapted"))
        end

        # Level Scaling made a raised Pokémon's moves again (its new level's):
        # the moves Adaptation taught it go back on
        def reteach(pk)
          m = pk ? pk.instance_variable_get(MARK) : nil
          return unless m
          Array(m["moves"]).each do |id|
            mv = id.to_s.to_sym
            place_move(pk, mv) unless pk.hasMove?(mv)
          end
        rescue StandardError
          nil
        end

        # A lead that beats yours: the one with a type that hits your lead's
        # hardest (super effective, or no swap), the one your lead hits
        # least on a tie; it stays put when it already leads
        def lead_swap(party, target, why = nil)
          hit = proc { |pk| types_of(pk).map { |t| (Effectiveness.calculate(t, target) rescue 0).to_i }.max.to_i }
          took = proc { |pk| (Effectiveness.calculate(target, *types_of(pk).first(2)) rescue 0).to_i }
          able = party.each_index.select do |i|
            party[i] && types_of(party[i]).any? { |t| (Effectiveness.super_effective_type?(t, target) rescue false) }
          end
          best = able.max_by { |i| [hit.call(party[i]), -took.call(party[i]), -i] }
          return unless best && best > 0
          party.unshift(party.delete_at(best))
          note(party[0], "lead", nil, why) if why
        end

        # One stage at a time (his pick, 2026-11-09): the next stage, once its
        # level + 5 reaches it; a fusion's head first, else its body (as PIF's
        # rematch evolutions step). A later evolution takes it further.
        def next_stage(species, lv, rng)
          lt = defined?(::KIF::LeaderTeams) ? ::KIF::LeaderTeams : nil
          return nil unless lt && lt.respond_to?(:min_level) && lt.respond_to?(:dex)
          top = defined?(::NB_POKEMON) ? ::NB_POKEMON : 100_000
          step = proc do |dex|
            evos = (::GameData::Species.get(dex).get_evolutions(true) rescue []).map { |e| lt.dex(e[0]) }
            evos = evos.select { |d| d.to_i > 0 && d <= top && lt.min_level(d) <= lv }
            evos.empty? ? nil : evos[rng.rand(evos.length)]
          end
          if species.to_s =~ /\AB(\d+)H(\d+)\z/
            body = Regexp.last_match(1).to_i
            head = Regexp.last_match(2).to_i
            h = step.call(head)
            return (getFusionSpecies(body, h).id rescue nil) if h
            b = step.call(body)
            return b ? (getFusionSpecies(b, head).id rescue nil) : nil
          end
          dex = (::GameData::Species.get(species).id_number rescue nil)
          got = dex ? step.call(dex) : nil
          return got ? (::GameData::Species.get(got).id rescue nil) : nil
        rescue StandardError
          return nil
        end

        def evolve(pk, rng, why = nil)
          sp = next_stage(pk.species, pk.level.to_i + 5, rng)
          return unless sp && sp != pk.species
          pk.species = sp
          pk.calc_stats
          pk.hp = pk.totalhp
          note(pk, "evolution", sp, why) if why
        end

        # Its strongest level-up move it's reached and doesn't know, in place
        # of its weakest damaging one
        # (only when it's stronger than that one: never a step down)
        def stronger_move(pk, why = nil)
          got = stronger_pick(pk)
          teach(pk, got[0], why, got[1]) if got
        end

        # [the move, its place (nil: a free one)], or nil when none is stronger
        def stronger_pick(pk)
          list = (pk.getMoveList rescue [])
          best = list.select { |lv, _m| lv.to_i <= pk.level.to_i }.map { |_lv, m| m }.uniq.reject { |m| pk.hasMove?(m) }
          best = best.max_by { |m| power(m) }
          return nil unless best && power(best) > 0
          at = free_place(pk, true)
          return nil if at && power(best) <= power(pk.moves[at].id)
          return [best, at]
        end

        #----------------------------------------------------------------------
        # The counter Pokémon: their class's type fused with a type that
        # beats your lead; it takes the weakest one's place (only an ace: joins)
        #----------------------------------------------------------------------
        def beater(lead)
          types = []
          ::GameData::Type.each { |t| types << t.id unless (t.pseudo_type rescue false) }
          return types.select { |t| (Effectiveness.super_effective_type?(t, *lead.first(2)) rescue false) }
        end

        # The counter's fusion: a type that beats your lead, never one your
        # lead hits hard, their class's type when it can (the first tries
        # ask all three, then all but the class's type, then the old way)
        def counter_species(lt, theme, beats, lead, level, target, used, rng)
          fuse = defined?(::KIF::Rand) && ::KIF::Rand.respond_to?(:fuse)
          last = nil
          [true, true, true, true, false, false, false, false].each do |want_theme|
            b = beats[rng.rand(beats.length)]
            x = lt.pick_one(theme || b, level, target, 0.0, used, [], rng)
            y = lt.pick_one(b, level, target, 0.0, used + [x].compact, [], rng)
            next unless x && y
            d = fuse ? ::KIF::Rand.fuse(x, y) : x
            d = ::KIF::Rand.fuse(y, x) if fuse && !lt.has_type?(d, b)
            last ||= [d, b]
            next unless lt.has_type?(d, b)
            next if weak_to?(d, lead)
            next if want_theme && theme && !lt.has_type?(d, theme)
            return [d, b]
          end
          return last
        end

        # Your lead's types hit this Pokémon hard
        def weak_to?(dex, lead)
          sp = ::GameData::Species.get(dex)
          types = [sp.type1, sp.type2].compact.uniq
          return lead.any? { |t| (Effectiveness.super_effective_type?(t, *types) rescue false) }
        rescue StandardError
          return false
        end

        # The same Pokémon on every load: its nature and personal ID from
        # the roll (its gender and the rest follow the ID)
        def steady(pk, rng)
          natures = []
          ::GameData::Nature.each { |n| natures << n.id } rescue nil
          pk.nature = natures[rng.rand(natures.length)] unless natures.empty?
          if pk.respond_to?(:personalID=)
            pk.personalID = rng.rand(0x100000000)
            pk.instance_variable_set(:@gender, nil) if pk.instance_variable_defined?(:@gender) && !(pk.singleGendered? rescue false)
            pk.instance_variable_set(:@ability_index, nil)      # (PIF works both out from the ID when asked)
            pk.calc_stats if pk.respond_to?(:calc_stats)
          end
        rescue StandardError
          nil
        end

        def add_counter(trainer, type, counter, rng)
          lt = defined?(::KIF::LeaderTeams) ? ::KIF::LeaderTeams : nil
          party = trainer.party
          lead = Array(counter["lead"]).map(&:to_sym)
          return unless lt && !lead.empty?
          # made from their team as written (LeaderBuilds' data place): a
          # Pokémon Team Expansion or a Rematch Rank adds doesn't change who
          # their counter is (his catch, 2026-11-10: Seasoned's Pokémon did)
          base = party.select { |p| p && p.instance_variable_defined?(LeaderBuilds::DATA) }
          base = party.compact if base.empty?
          theme = TrainerControl.theme_type(type, base.map { |p| [p.species, p.level] })
          beats = beater(lead)
          return if beats.empty?
          level = (base.sum { |p| p.level.to_i }.to_f / base.length).round
          target = base.sum { |p| lt.bst(lt.dex(p.species)) }.to_f / base.length
          used = base.map { |p| lt.dex(p.species) }
          d, b = counter_species(lt, theme, beats, lead, level, target, used, rng)
          return unless d
          pk = lt.make_pokemon(d, level, trainer, nil)
          steady(pk, rng)
          mark(pk)["counter"] = true
          note(pk, "counter", nil, _INTL("Beats Your {1} Lead", lead.map { |t| type_name(t) }.join("/")))
          # a move of the type that beats your lead, if it has none that does
          hits = pk.moves.any? { |m| power(m.id) > 0 && (Effectiveness.super_effective_type?(::GameData::Move.get(m.id).type, *lead.first(2)) rescue false) }
          unless hits
            move = counter_move(pk, lead[0], rng)
            teach(pk, move, _INTL("Beats Your {1} Lead", lead.map { |t| type_name(t) }.join("/"))) if move
          end
          # it takes their lowest-level Pokémon's place, never the ace's (his
          # pick, 2026-11-09: teams stay the size the game made them; growing
          # them is Team Expansion's); only their ace: it's a second Pokémon
          ace = ace_index(party)
          others = (0...party.length).reject { |i| i == ace }
          if others.empty?
            party << pk
          else
            party[others.min_by { |i| party[i].level.to_i }] = pk
          end
        rescue StandardError => e
          Reloaded::Log.warning_once("Trainer Control's counter Pokémon couldn't be made: #{e.message}", :trainer_control)
        end
      end

      # Your lead: the Pokémon you sent out first (not whoever is first in
      # your party when the battle ends)
      module LeadWatch
        def pbOnActiveAll(*args)
          unless instance_variable_defined?(:@kr_tc_lead)
            b = (@battlers[0] rescue nil)
            @kr_tc_lead = b && b.pokemon && !(b.pokemon.egg? rescue false) ? b.pokemon : nil
          end
          super
        end
      end

      # cody's rolls put back by each Pokémon's written place
      module RollsByPlace
        def apply(trainer, k)
          party = trainer.respond_to?(:party) ? trainer.party : nil
          order = party.is_a?(Array) ? (Reloaded::TrainerControl::Adaptation.written_order(party) rescue nil) : nil
          return super unless order && order.length == party.length
          was = party.dup
          begin
            party.replace(order)
            return super
          ensure
            party.replace(was)
          end
        end
      end

      # Your Pokémon's moves in a trainer battle, by type (your habits). His
      # pick (2026-11-09): only damaging moves that landed (a foe lost HP
      # to it), by the type they hit with (Weather Ball in rain is Water,
      # Hidden Power its own); a move another calls (Metronome, Sleep Talk)
      # counts once, in its own use
      module MoveWatch
        def pbUseMove(choice, *args)
          before = nil
          begin
            if pbOwnedByPlayer? && (@battle.trainerBattle? rescue false) && choice.is_a?(Array) && choice[2]
              before = Array(@battle.battlers).select { |b| b && opposes?(b) && !b.fainted? }.map { |b| [b, b.hp] }
            end
          rescue StandardError
            before = nil
          end
          ret = super
          begin
            Reloaded::TrainerControl::Adaptation.tally(self, choice[2], before) if before
          rescue StandardError
            nil
          end
          return ret
        end
      end
    end
  end
end
