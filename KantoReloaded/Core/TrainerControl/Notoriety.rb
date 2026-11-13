# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Trainer Control's Notoriety (Tougher Trainers C)
#==============================================================================
# PIF Today: nothing remembers how you've been doing against trainers as a
# whole; trainers are as tough on your hundredth win as your first.
# (Trainer Control's Adaptation had leaders bring their counter Pokémon
# once the Trainer Card's win streak reached 10.)
#
# His picks (2026-11-01): word of you gets around, on Normal and Hard
# (Easy as PIF), always on:
#
#   The count  its own: your first win over each trainer adds one (his
#              pick, 2026-11-10: rematch wins don't); a loss to someone
#              you've never beaten drops you to the start of the tier below
#              (Feared at 14 to Known's 5), never all the way unless you
#              were Known; a rematch never drops it (his pick)
#   Known      at 5: every trainer adapts one more way (Adaptation: one
#              more change on a first meeting and from each win)
#   Feared     at 10: leaders bring their counter Pokémon (the win streak's
#              old rule, moved here), every trainer's ace comes fully built
#              (a Leader Build), and aces get their Ace Moment
#   Infamous   at 20: every trainer comes 2 levels higher, over Level
#              Scaling
#
# A toast when you reach a tier or drop from one (UI/NotorietyToast.rb),
# after the battle, with its sound; the Trainer Card shows the tier among
# its facts. The count is kept with Trainer Control's records:
#   "notoriety" => count
#==============================================================================

module Reloaded
  module TrainerControl
    module Notoriety
      Tier = Struct.new(:key, :name, :wins, :rgb, :skin, :index)
      TIERS = [Tier.new(:known, "Known", 5, [240, 170, 60], "Orange", 0), Tier.new(:feared, "Feared", 10, [240, 100, 90], "Red", 1),
               Tier.new(:infamous, "Infamous", 20, [176, 96, 240], "Purple", 2)].freeze
      KEY = "notoriety"
      LEVELS = 2                           # Infamous: every trainer this many levels higher

      class << self
        def install
          Reloaded::Events.on(:trainer_battle_ended, :trainer_control_notoriety, 104) { |c| battle_ended(c) }
        end

        def on?
          return defined?(Reloaded::Difficulty) && Reloaded::Difficulty.respond_to?(:level) && Reloaded::Difficulty.level >= 1
        end

        def count
          d = Records.data
          return d ? d[KEY].to_i : 0
        end

        def count=(n)
          d = Records.data
          d[KEY] = [n.to_i, 0].max if d
        end

        # The tier for a count (nil under Known's)
        def tier_for(n)
          return TIERS.reverse.find { |t| n.to_i >= t.wins }
        end

        # The tier now, nil off (Easy) or under Known
        def tier
          return on? ? tier_for(count) : nil
        end

        def tier_index
          t = tier
          return t ? t.index : -1
        end

        def tier_named(key)
          return TIERS.find { |t| t.key == key.to_s.to_sym }
        end

        # Where a loss leaves you: the start of the tier below
        def after_loss(n)
          t = tier_for(n)
          return 0 unless t
          below = t.index > 0 ? TIERS[t.index - 1] : nil
          return below ? below.wins : 0
        end

        #----------------------------------------------------------------------
        # What each tier does (Adaptation, Level Scaling, Leader Builds ask)
        #----------------------------------------------------------------------
        # Known: one more Adaptation change
        def extra_changes
          return tier_index >= 0 ? 1 : 0
        end

        # Feared: leaders bring their counter Pokémon, aces come built
        def feared?
          return tier_index >= 1
        end

        # Infamous: levels over Level Scaling
        def extra_levels
          return tier_index >= 2 ? LEVELS : 0
        end

        # A trainer just loaded (TrainerControl.build_team, after Level
        # Scaling): Infamous's levels on everyone; Feared's build on an
        # ordinary trainer's ace (leaders have theirs: Leader Builds)
        def apply(trainer, type, _name, _version)
          party = trainer ? Array(trainer.party).compact : []
          return if party.empty? || !on?
          up = extra_levels
          if up > 0
            max = defined?(::Settings::MAXIMUM_LEVEL) ? ::Settings::MAXIMUM_LEVEL : 100
            party.each do |pk|
              lv = [pk.level.to_i + up, max].min
              next if lv == pk.level.to_i
              pk.instance_variable_set(LevelScaling::FROM, pk.instance_variable_get(LevelScaling::FROM) || pk.level.to_i)
              pk.level = lv
              pk.calc_stats
              pk.hp = pk.totalhp
            end
          end
          if feared? && TrainerControl.kind(type) == :trainer && defined?(LeaderBuilds)
            ace = party[Adaptation.ace_index(party)]
            LeaderBuilds.build(ace, nil)
          end
        rescue StandardError => e
          Reloaded::Log.exception("Notoriety couldn't touch #{type}'s team", e, :trainer_control)
        end

        #----------------------------------------------------------------------
        # The count after each battle; the toast when the tier changes
        #----------------------------------------------------------------------
        def battle_ended(context)
          return unless on? && Records.data && !Array(context[:people]).empty?
          won = context[:won]
          return if won.nil?
          before = count
          was = tier_for(before)
          if won
            fresh = first_wins(context[:people])
            return if fresh == 0                    # a rematch win: word of it is old news
            self.count = before + fresh
          else
            # only a loss to someone you've never beaten (his pick,
            # 2026-11-10): a rematch neither raises nor drops it
            return unless Array(context[:people]).any? { |key| (r = Records.get(key)) && r["wins"].to_i == 0 }
            self.count = after_loss(before)
          end
          now = tier_for(count)
          return if (was && was.key) == (now && now.key)
          @due = won ? [:up, now] : [:drop, was, now]
        rescue StandardError => e
          Reloaded::Log.exception("Notoriety couldn't count a battle", e, :trainer_control)
        end

        # Each trainer counts once (his pick, 2026-11-10): how many of this
        # battle's people you just beat for the first time (their records
        # count this win already)
        def first_wins(people)
          return Array(people).count { |key| (r = Records.get(key)) && r["wins"].to_i == 1 }
        end

        # Back on the map: the toast (TrainerControl's battle hook)
        def after_battle
          due = @due
          @due = nil
          return unless due && defined?(Reloaded::NotorietyToast)
          due[0] == :up ? Reloaded::NotorietyToast.up(due[1]) : Reloaded::NotorietyToast.drop(due[1], due[2])
        end
      end
    end
  end
end
