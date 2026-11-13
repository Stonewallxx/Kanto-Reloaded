# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Trainer Control's Ace Moments (Tougher Trainers E)
#==============================================================================
# PIF Today: a trainer's last Pokémon comes out like any other, with "Gym
# Leader Brock sent out Onix!". (EBDX's mid-battle trainer lines are off in
# KIF.)
#
# His picks (2026-11-01), on Normal and Hard (Easy as PIF), always on:
#
#   Who        Gym Leaders, the Elite Four, Champions, Team Rocket's bosses and your
#              rival every battle; every other trainer once you're Feared
#              (Notoriety)
#   The ace    the one holding a Mega Stone (Megas), else their highest level
#   The moment before it's sent out, their line (the cut-in,
#              UI/AceMoment.rb); once it's out (its entry effects done), it
#              Mega Evolves when it can, then +1 to its best stat (Hard: its
#              two best) with the ACE pill. An ace that leads (a one-Pokémon
#              team, Adaptation's lead) gets its moment once the battle has
#              opened (the Leader's Seal gone). Dragged in (Roar): no line.
#   Megas      Hard: the leader group's ace holds its Mega Stone from the
#              4th badge; Normal as Megas does it (after Silph Co)
#   The lines  each leader's own (his picks of Line A and B), ordinary
#              trainers' by their class's group (tt-lines.md's picks);
#              classes in no group take the Veterans' line
#
# Kept on the battle while it runs:
#   @kr_ace_moments  { owner index => { "pk", "trainer", "state" (:ready, :cut, :done) } }
#==============================================================================

module Reloaded
  module TrainerControl
    module AceMoments
      STATE = :@kr_ace_moments
      OPENING = :@kr_ace_opening
      STONE_BADGES = 4
      STATS = [:ATTACK, :SPECIAL_ATTACK, :SPEED, :DEFENSE, :SPECIAL_DEFENSE].freeze   # a tie goes to the first
      STAT_VARS = { :ATTACK => :@attack, :DEFENSE => :@defense, :SPECIAL_ATTACK => :@spatk, :SPECIAL_DEFENSE => :@spdef,
                    :SPEED => :@speed }.freeze
      # His picks, {1} the ace's name
      LEADER_LINES = {
        :LEADER_Brock => "{1}, show them what we trained for!",
        :LEADER_Misty => "{1}, let's wash them right out of my gym!",
        :LEADER_Surge => "{1}! Light 'em up, soldier!",
        :LEADER_Erika => "{1}, please... bloom for me now.",
        :LEADER_Koga => "Fwahahaha! Now you face my true poison. Go, {1}!",
        :LEADER_Sabrina => "I saw this moment long ago. {1}, end it.",
        :LEADER_Blaine => "Hah! {1}, turn up the heat!",
        :LEADER_Giovanni => "{1}. Crush them.",
        :LEADER_Falkner => "{1}, show them the real power of bird Pokémon!",
        :LEADER_Kurt => "This one's my finest work. Go on, {1}!",
        :LEADER_Whitney => "My turn now! {1}, roll right over them!",
        :LEADER_Morty => "The veil lifts... {1}, it's your time.",
        :LEADER_Chuck => "All that training pays off right now! Go, {1}!",
        :LEADER_Jasmine => "Um... {1}, please. Let's show them our strength.",
        :LEADER_Pryce => "Like ice, my will doesn't break. Go, {1}.",
        :LEADER_Clair => "I'm the world's best dragon master! {1}, prove it!",
        :ELITEFOUR_Lorelei => "{1}, freeze them where they stand.",
        :ELITEFOUR_Bruno => "Hoo hah! {1}, show them our power!",
        :ELITEFOUR_Agatha => "Oak's had his day. Now it's {1}'s turn!",
        :ELITEFOUR_Lance => "This is where dragons rule. Go, {1}!",
        :CHAMPION => "{1}! We're the best in the world. Prove it!",
        :CHAMPION_Sinnoh => "{1}. Let's give them everything we have.",
        :ROCKETBOSS => "Team Rocket does not lose. {1}, remind them.",
        :RIVAL1 => "{1}! Show them who's going to be Champion!",
        :RIVAL2 => "{1}! Show them who's going to be Champion!"
      }.freeze
      GROUP_LINES = [
        [/\A(YOUNGSTER|LASS|BUGCATCHER|CAMPER|PICNICKER|TUBER|PRESCHOOLER)/, "{1}, it's your turn! Show them what we've got!"],
        [/\A(HIKER|RUINMANIAC|WORKER|FARMER)/, "Steady as the mountain, {1}! Let's go!"],
        [/\A(SWIMMER|SAILOR|FISHERMAN)/, "Here's my big catch! Go, {1}!"],
        [/\ABIRDKEEPER/, "{1}, take to the skies!"],
        [/\A(BLACKBELT|CRUSHGIRL|CUEBALL|ROUGHNECK|BIKER)/, "No holding back! {1}, hit 'em hard!"],
        [/\A(PSYCHIC|CHANNELER|HAUNTEDGIRL|SAGE|KIMONOGIRL|JUGGLER)/, "The spirits say it's your time, {1}."],
        [/\A(SCIENTIST|ENGINEER|SUPERNERD|POKEMANIAC|BURGLAR|GAMBLER|PYROMANIAC)/, "My calculations say {1} wins this. Go!"],
        [/\A(BEAUTY|LADY|SOCIALITE|GENTLEMAN|AROMALADY|PAINTER)/, "And now, my pride and joy. Darling {1}, if you please!"],
        [/\ATYPE_EXPERT/, "{1} is the best my type has to offer!"],
        [/\A(TEAMROCKET|ROCKETEXEC|TEAMPLASMA)/, "You picked a fight with the wrong team! {1}, go!"],
        [/\A(COOLCOUPLE|YOUNGCOUPLE|SISANDBRO|TWINS|CRUSHKIN)/, "Together now! {1}, show them!"]
      ].freeze
      OTHER_LINE = "You're good. But {1} is better."    # the Veterans' (Cool Trainers, Rangers, Tamers...) and any class in no group

      class << self
        def install
          return unless defined?(::PokeBattle_Battle) && defined?(::PokeBattle_Battler)
          h = Reloaded::Hooks
          b = ::PokeBattle_Battle
          if TrainerControl.defined_method?(b, :pbStartBattle)
            h.around(nil, b, :pbStartBattle, :id => :ace_moments_stones) do |original, *args|
              Reloaded::TrainerControl::AceMoments.give_stones(original.receiver)
              original.call(*args)
            end
          end
          if TrainerControl.defined_method?(b, :pbMessagesOnReplace)
            h.around(nil, b, :pbMessagesOnReplace, :id => :ace_moments_line) do |original, *args|
              Reloaded::TrainerControl::AceMoments.before_send_out(original.receiver, *args)
              original.call(*args)
            end
          end
          if TrainerControl.defined_method?(b, :pbOnActiveAll)
            h.around(nil, b, :pbOnActiveAll, :id => :ace_moments_opening) do |original, *args|
              battle = original.receiver
              battle.instance_variable_set(OPENING, true)
              begin
                ret = original.call(*args)
              ensure
                battle.instance_variable_set(OPENING, nil)
              end
              Reloaded::TrainerControl::AceMoments.opened(battle)
              ret
            end
          end
          if TrainerControl.defined_method?(::PokeBattle_Battler, :pbEffectsOnSwitchIn)
            h.around(nil, ::PokeBattle_Battler, :pbEffectsOnSwitchIn, :id => :ace_moments_arrival) do |original, *args|
              ret = original.call(*args)
              Reloaded::TrainerControl::AceMoments.switched_in(original.receiver) if args[0]
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

        def badges
          return ($Trainer.badge_count rescue 0).to_i
        end

        # The leader group every battle; others once you're Feared
        def moment_for?(type)
          return true if TrainerControl.kind(type) != :trainer
          return defined?(Notoriety) && Notoriety.feared? ? true : false
        end

        def line_for(type, ace)
          line = LEADER_LINES[type.to_s.to_sym]
          line ||= (GROUP_LINES.find { |re, _l| type.to_s =~ re } || [nil, OTHER_LINE])[1]
          return _INTL(line, ace)
        end

        #----------------------------------------------------------------------
        # The ace
        #----------------------------------------------------------------------
        def stone?(pk)
          return false unless defined?(::Megas) && ::Megas.respond_to?(:stone_species)
          id = (pk.item_id rescue nil)
          return id && ::Megas.stone_species.key?(id) ? true : false
        end

        # The Mega Stone's holder, else the highest level (the first on a tie)
        def ace_of(party)
          list = party.compact.reject { |pk| (pk.egg? rescue false) }
          return nil if list.empty?
          return list.find { |pk| stone?(pk) } || list[Adaptation.ace_index(list)]
        end

        # Each opposing trainer's Pokémon in the battle
        def party_of(battle, owner)
          party = Array(battle.pbParty(1))
          return party.each_index.select { |j| party[j] && battle.pbGetOwnerIndexFromPartyIndex(1, j) == owner }.map { |j| party[j] }
        end

        # The battle's moments, found once (after Megas has handed out stones)
        def aces(battle)
          got = battle.instance_variable_get(STATE)
          return got if got
          out = {}
          if on? && TrainerControl.counted_battle?(battle)
            Array(battle.opponent).each_with_index do |t, i|
              next unless t && moment_for?(t.trainer_type)
              ace = ace_of(party_of(battle, i))
              out[i] = { "pk" => ace, "trainer" => t, "state" => :ready } if ace
            end
          end
          return battle.instance_variable_set(STATE, out)
        rescue StandardError => e
          Reloaded::Log.exception("Ace Moments couldn't find the aces", e, :trainer_control)
          return battle.instance_variable_set(STATE, {})
        end

        def entry(battle, pk)
          return nil unless pk
          return aces(battle).values.find { |e| e["pk"].equal?(pk) && e["state"] != :done }
        end

        # Hard: the leader group's ace holds its Mega Stone from the 4th
        # badge (before Megas' own start, which leaves a holder alone)
        def give_stones(battle)
          return unless on? && hard? && badges >= STONE_BADGES && defined?(::Megas) && ::Megas.respond_to?(:give_ace_stone)
          return unless TrainerControl.counted_battle?(battle)
          Array(battle.opponent).each_with_index do |t, i|
            next unless t && TrainerControl.kind(t.trainer_type) != :trainer
            ::Megas.give_ace_stone(party_of(battle, i))
          end
        rescue StandardError => e
          Reloaded::Log.exception("Ace Moments couldn't hand out a Mega Stone", e, :trainer_control)
        end

        #----------------------------------------------------------------------
        # The moment
        #----------------------------------------------------------------------
        # Before "Brock sent out Onix!": the line
        def before_send_out(battle, idx_battler, idx_party)
          return unless battle.opposes?(idx_battler)
          e = entry(battle, Array(battle.pbParty(idx_battler))[idx_party])
          return unless e && e["state"] == :ready
          e["state"] = :cut
          line(battle, e, shown_name(battle, idx_battler, idx_party))
        rescue StandardError => ex
          Reloaded::Log.exception("An Ace Moment's line couldn't show", ex, :trainer_control)
        end

        # The name the send-out says (an Illusion's disguise, as the game does)
        def shown_name(battle, idx_battler, idx_party)
          party = battle.pbParty(idx_battler)
          name = party[idx_party].name
          if (party[idx_party].ability == :ILLUSION rescue false)
            j = battle.pbLastInTeam(idx_battler)
            name = party[j].name if j >= 0 && j != idx_party
          end
          return name
        end

        def line(battle, e, ace_name)
          t = e["trainer"]
          party = party_of(battle, Array(battle.opponent).index(t) || 0)
          type = TrainerControl.theme_type(t.trainer_type, party.map { |pk| [pk.species, pk.level] }) || ace_type(e["pk"])
          Reloaded::AceMoment.cut_in(battle, t, line_for(t.trainer_type, ace_name), type) if defined?(Reloaded::AceMoment)
        end

        def ace_type(pk)
          return (pk.type1 rescue nil) || :NORMAL
        end

        # Its entry effects done: the rest of the moment (not inside the
        # battle's opening: that comes once it has opened)
        def switched_in(battler)
          battle = battler.battle
          return if battle.instance_variable_get(OPENING) || !battler.opposes?
          e = entry(battle, battler.pokemon)
          arrive(battle, battler, e) if e
        rescue StandardError => ex
          Reloaded::Log.exception("An Ace Moment couldn't play", ex, :trainer_control)
        end

        # The battle has opened (both sides out, the Leader's Seal gone): an
        # ace that leads gets its whole moment now
        def opened(battle)
          aces(battle).each_value do |e|
            next unless e["state"] == :ready
            b = Array(battle.battlers).find { |x| x && x.opposes? && x.pokemon.equal?(e["pk"]) && !x.fainted? }
            next unless b
            e["state"] = :cut
            line(battle, e, b.name)
            arrive(battle, b, e)
          end
        rescue StandardError => ex
          Reloaded::Log.exception("An Ace Moment couldn't play", ex, :trainer_control)
        end

        def arrive(battle, battler, e)
          e["state"] = :done
          return if battler.fainted?
          mega(battle, battler)
          return if battler.fainted?
          stats = boost(battler)
          Reloaded::AceMoment.pill(battle, battler, stats) if defined?(Reloaded::AceMoment)
        end

        # It Mega Evolves in its moment when it can (Megas' Once per battle;
        # Permanent ones are Mega already)
        def mega(battle, battler)
          return unless battler.respond_to?(:hasMega?) && battler.hasMega? && !battler.mega?
          return unless (battle.pbCanMegaEvolve?(battler.index) rescue false)
          battle.pbMegaEvolve(battler.index)
        end

        # +1 to its best stat (Hard: its two best), as it is now (a Mega's)
        def best_stats(battler, n)
          return STATS.each_with_index.sort_by { |s, i| [-battler.instance_variable_get(STAT_VARS[s]).to_i, i] }.first(n).map(&:first)
        end

        def boost(battler)
          picks = best_stats(battler, hard? ? 2 : 1)
          picks.select! { |s| battler.stages[s].to_i < 6 }
          picks.each { |s| battler.pbRaiseStatStageBasic(s, 1, true) }
          return picks
        end
      end
    end
  end
end
