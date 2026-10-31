# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Trainer Control's bond steps
#==============================================================================
# A growing bond with each trainer you can battle again (his pick, D with
# B): a gift that fits their class at 3 wins, a move from their own team at
# 7 (a tutor), an Egg of their favourite Pokémon at 12, then a gift every 10
# more wins (22, 32...). Leaders 2 / 4 / 6 (their first win is the gym), then
# every 10 the same way. Only trainers you can battle again reach them.
# Claimed steps stay claimed, whatever happens (old KR's farm bug).
#
#   The gift   their class's own (a Fisherman a better Rod, a Hiker a Hard
#              Stone or Moon Stone, a Bug Catcher Silver Powder), else their
#              type's item or stone; the every-10 gifts add Rare Candy and
#              PP Ups. Known ahead (the record's tile shows it), the same for
#              a save; a key item you have already is skipped.
#   The tutor  a move from their team as it fought you, for one of yours
#              that can learn it (UI/BondMoments.rb asks who and which)
#   The Egg    their favourite: their ace's first stage
#
# After a win that reaches a step (and any step an older save passed
# without it), the moment comes back on the map: the trainer's words with
# a card above them (his pick, Design 1, Words and a Card).
#
#   Bond.shown(record)      the three steps the record plate shows
#   Bond.next_step(record)  [kind, wins, wins to go]
#   Bond.reward(record, at) { "kind", "item" / "move" / "species" }
#
# A record keeps its claimed steps as plain values:
#   "steps" => { "3" => { "kind" => "gift", "item" => "HARDSTONE" }, ... }
#==============================================================================

module Reloaded
  module TrainerControl
    module Bond
      FIRST = [3, 7, 12].freeze
      LEADER_FIRST = [2, 4, 6].freeze
      EVERY = 10
      KINDS = [:gift, :tutor, :egg].freeze
      WORDS = { :gift => "Gift", :tutor => "Tutor", :egg => "Egg" }.freeze
      # Gifts that fit a class (by the start of its id), then by its type
      CLASS_GIFTS = [[/\AFISHERMAN/, [:GOODROD, :SUPERROD, :MYSTICWATER]], [/\AHIKER/, [:HARDSTONE, :MOONSTONE, :EVERSTONE]],
                     [/\ABUGCATCHER/, [:SILVERPOWDER, :SHEDSHELL]], [/\ASWIMMER|\ASAILOR|\ATUBER/, [:MYSTICWATER, :WATERSTONE]],
                     [/\ABIRDKEEPER/, [:SHARPBEAK, :PRETTYWING]], [/\APSYCHIC|\ASAGE|\AJUGGLER/, [:TWISTEDSPOON, :MOONSTONE]],
                     [/\ACHANNELER|\AHAUNTED/, [:SPELLTAG, :DUSKSTONE]], [/\ABLACKBELT|\ACRUSH/, [:BLACKBELT, :PROTEIN]],
                     [/\AENGINEER|\ASCIENTIST/, [:MAGNET, :THUNDERSTONE]], [/\ABEAUTY|\ALADY|\ALASS|\APICNICKER/, [:MIRACLESEED, :LEAFSTONE]],
                     [/\AGENTLEMAN|\ARICH/, [:AMULETCOIN, :NUGGET]], [/\ACOOLTRAINER/, [:EXPERTBELT, :LIFEORB]]].freeze
      TYPE_GIFTS = { :NORMAL => [:SILKSCARF], :FIRE => [:CHARCOAL, :FIRESTONE], :WATER => [:MYSTICWATER, :WATERSTONE],
                     :ELECTRIC => [:MAGNET, :THUNDERSTONE], :GRASS => [:MIRACLESEED, :LEAFSTONE], :ICE => [:NEVERMELTICE, :ICESTONE],
                     :FIGHTING => [:BLACKBELT], :POISON => [:POISONBARB], :GROUND => [:SOFTSAND], :FLYING => [:SHARPBEAK],
                     :PSYCHIC => [:TWISTEDSPOON], :BUG => [:SILVERPOWDER], :ROCK => [:HARDSTONE], :GHOST => [:SPELLTAG, :DUSKSTONE],
                     :DRAGON => [:DRAGONFANG], :DARK => [:BLACKGLASSES], :STEEL => [:METALCOAT], :FAIRY => [:MOONSTONE] }.freeze
      LATER_GIFTS = [:RARECANDY, :PPUP, :RARECANDY].freeze

      @pending = []

      class << self
        attr_reader :pending

        def install
          Reloaded::Events.on(:trainer_battle_ended, :trainer_control_bond, 108) { |c| battle_ended(c) }
        end

        def firsts(rec)
          return rec && rec["kind"] == "leader" ? LEADER_FIRST : FIRST
        end

        def can_reach?(rec)
          return Records.rematchable?(rec)
        end

        # Every step up to the first one not reached: [[kind, wins], ...]
        def steps(rec)
          wins = rec["wins"].to_i
          out = KINDS.zip(firsts(rec))
          at = out.last[1]
          while wins >= at
            at += EVERY
            out << [:gift, at]
          end
          return out
        end

        # The three on the plate: the last three up to the next one
        def shown(rec)
          return steps(rec).last(3)
        end

        def next_step(rec)
          kind, at = steps(rec).find { |_k, n| rec["wins"].to_i < n }
          return [kind, at, at - rec["wins"].to_i]
        end

        def word(kind)
          return _INTL(WORDS[kind] || "Gift")
        end

        # A step's claimed reward ({ "kind", "item" / "move" / "species" }), or nil
        def claimed(rec, at)
          s = rec["steps"]
          return s.is_a?(Hash) ? s[at.to_s] : nil
        end

        def kind_at(rec, at)
          step = steps(rec).find { |_k, n| n == at.to_i }
          return step ? step[0] : (at.to_i > firsts(rec).last ? :gift : nil)
        end

        # What the plate shows for a step: its claimed reward, else what it
        # will be (the gift, the Egg; the tutor's move is known once taught)
        def reward(rec, at)
          c = claimed(rec, at)
          return c if c
          case kind_at(rec, at)
          when :gift
            item = gift_for(rec, at)
            return item ? { "kind" => "gift", "item" => item.to_s } : nil
          when :egg
            sp = egg_species(rec)
            return sp ? { "kind" => "egg", "species" => sp.to_s } : nil
          end
          return nil
        end

        #----------------------------------------------------------------------
        # The rewards
        #----------------------------------------------------------------------
        def key_of(rec)
          return TrainerControl.person_key(rec["type"], rec["name"]).to_s
        end

        def item_ok?(item)
          return false unless (::GameData::Item.exists?(item) rescue false)
          key = (::GameData::Item.get(item).is_key_item? rescue false)
          return !(key && ($PokemonBag.pbHasItem?(item) rescue false))
        end

        # The gift for a step: their class's, else their type's; later
        # gifts add Rare Candy and PP Ups (Pink Slips adds its own)
        def gift_pool(rec, at)
          type = rec["type"].to_s
          pool = (CLASS_GIFTS.find { |re, _l| type =~ re } || [nil, []])[1].dup
          t = TrainerControl.theme_type(rec["type"], rec["team"])
          pool.concat(TYPE_GIFTS[t] || []) if t
          pool.concat(LATER_GIFTS) if at.to_i > firsts(rec).last
          pool.concat(PinkSlips.gift_items(rec, at)) if defined?(PinkSlips) && PinkSlips.respond_to?(:gift_items)
          pool = [:SITRUSBERRY] if pool.empty?
          return pool.uniq
        end

        def gift_for(rec, at)
          pool = gift_pool(rec, at).select { |i| item_ok?(i) }
          pool = [:SITRUSBERRY, :RARECANDY].select { |i| item_ok?(i) } if pool.empty?
          return nil if pool.empty?
          return pool[Adaptation.seed(key_of(rec), "gift", at) % pool.length]
        end

        # Their favourite: their ace's first stage (from their last team)
        def egg_species(rec)
          ace = Array(rec["team"]).max_by { |_sp, lv| lv.to_i }
          return nil unless ace
          sp = (::GameData::Species.get(ace[0].to_s.to_sym) rescue nil)
          return nil unless sp
          baby = (sp.get_baby_species rescue sp.id)
          return (::GameData::Species.get(baby).id rescue sp.id)
        end

        # The moves their team fought you with: [[move, species], ...]
        def team_moves(battle, i)
          tr = Array(battle.opponent)[i]
          return [] unless tr
          out = []
          Array(tr.party).compact.each do |pk|
            Array((pk.moves rescue nil)).each { |m| out << [m.id.to_s, pk.species.to_s] if m && out.none? { |id, _s| id == m.id.to_s } }
          end
          return out
        end

        #----------------------------------------------------------------------
        # After a win: the steps reached (and any an older save passed)
        #----------------------------------------------------------------------
        def battle_ended(context)
          return unless context[:won]
          battle = context[:battle]
          Array(context[:people]).each do |key|
            rec = Records.get(key)
            next unless rec && can_reach?(rec)
            i = Array(battle.opponent).index { |tr| TrainerControl.person(tr) == key } || 0
            steps(rec).each do |kind, at|
              next if at > rec["wins"].to_i || claimed(rec, at)
              @pending << { "key" => key, "at" => at, "kind" => kind.to_s, "moves" => kind == :tutor ? team_moves(battle, i) : nil }
            end
          end
        rescue StandardError => e
          Reloaded::Log.exception("Trainer Control couldn't see a bond step", e, :trainer_control)
        end

        # Back on the map after the battle: each moment in turn
        def after_battle
          list = @pending
          @pending = []
          list.each do |p|
            rec = Records.get(p["key"])
            next unless rec && !claimed(rec, p["at"])
            begin
              give(rec, p)
            rescue StandardError => e
              Reloaded::Log.exception("Trainer Control couldn't give a bond step", e, :trainer_control)
            end
          end
        end

        def claim(rec, at, reward)
          (rec["steps"] ||= {})[at.to_s] = reward
        end

        def give(rec, p)
          at = p["at"]
          moments = defined?(Reloaded::BondMoments) ? Reloaded::BondMoments : nil
          case p["kind"]
          when "gift"
            item = gift_for(rec, at)
            return claim(rec, at, { "kind" => "gift", "item" => nil }) unless item
            claim(rec, at, { "kind" => "gift", "item" => item.to_s })      # (claimed first: never twice)
            moments ? moments.gift(rec, at, item) : nil
            pbReceiveItem(item, 1, "", nil, false) if defined?(pbReceiveItem)
          when "egg"
            sp = egg_species(rec)
            claim(rec, at, { "kind" => "egg", "species" => sp.to_s })
            moments ? moments.egg(rec, at, sp) : nil
            pbGenerateEgg(sp, _INTL("A gift from {1}.", Records.title(rec))) if sp && defined?(pbGenerateEgg)
          when "tutor"
            move = moments ? moments.tutor(rec, at, Array(p["moves"])) : nil
            claim(rec, at, { "kind" => "tutor", "move" => move ? move.to_s : nil })
          end
        end
      end
    end
  end
end
