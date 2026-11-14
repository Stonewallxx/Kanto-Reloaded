# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Trainer Control's Level Scaling
#==============================================================================
# His picks (Roadmap Designs topic trainer-control, 2026-10-30), trainers
# that keep up with you, only ever up on a first battle:
#
#   The curve       PIF's level cap for your badges (getCurrentLevelCap:
#                   the next Gym Leader's level, Hard's x1.1 in it), less 4
#                   for regular trainers. A trainer under it rises part of
#                   the way: Half on Easy, Three Quarters on Normal and Hard
#                   (his pick, 2026-11-01: no row; Hard is tougher other ways).
#   Rematches       start at the curve and climb a level each rematch,
#                   up to your party's level (a Rematch Rank's levels past
#                   it: Seasoned 1 .. Master 4, his pick 2026-11-14), then
#                   keep pace with it; never
#                   below the curve (PIF's own rematch levels replaced; its
#                   rematch evolutions stay). Half EXP; prize money (Rematch
#                   Money) half, a quarter, a tenth, then none, per trainer
#                   per in-game day.
#   Leaders, rival  Gym Leaders, the Elite Four, Champions, Team Rocket's bosses
#                   and your rival come at your party's level (the higher of
#                   its average and your highest - 2; Hard: 10% above,
#                   your rival too),
#                   never below their own. On Easy as the game wrote them
#                   (his pick, 2026-11-10).
#   A team rises    its ace to the target, the rest keeping their gaps.
#   Built for it    a raised Pokémon takes the stage its level allows,
#                   its level-up moves (hand-written sets stay), the IVs
#                   and EVs PIF gives that level; Hard's IV floor after.
#   Shown           Battle Info's foe tab: a green +12 beside the level.
#
# Always on (his call, 2026-10-31); one row per save: Rematch Money
# (Trainer Control - Level Scaling). Nothing is scaled with PIF's battle-level override on, for partners, the
# battle facilities, KIF's Self-Battle or the Endgame Challenge's maps.
#==============================================================================

module Reloaded
  module TrainerControl
    module LevelScaling
      PAGE = :trainer_control_levels
      MONEY = :"trainer_control.rematch_money"
      RISE = [0.5, 0.75, 0.75].freeze   # how much of the gap a first battle closes: Easy, Normal, Hard
      UNDER_CURVE = 4                   # regular trainers: 4 under the badge level
      SPREAD = 2                        # your party's level: the higher of its average and your highest - 2
      HARD_LEADERS = 1.1
      PAYS = [0.5, 0.25, 0.1].freeze    # a trainer's rematches the same day, then none
      REMATCH_EXP = 0.5
      FROM = :@kr_tc_from               # on a raised Pokémon: its level before

      @partner = 0

      class << self
        attr_accessor :partner

        def install
          register_settings if defined?(Reloaded::Settings)
          h = Reloaded::Hooks
          if TrainerControl.defined_method?(::Object, :pbRegisterPartner)
            h.around(nil, ::Object, :pbRegisterPartner, :id => :trainer_control_partner) do |original, *args|
              Reloaded::TrainerControl::LevelScaling.partner += 1
              begin
                original.call(*args)
              ensure
                Reloaded::TrainerControl::LevelScaling.partner -= 1
              end
            end
          end
          return unless defined?(::PokeBattle_Battle)
          if TrainerControl.defined_method?(::PokeBattle_Battle, :kif_trainer_exp_multiplier)
            h.around(nil, ::PokeBattle_Battle, :kif_trainer_exp_multiplier, :id => :trainer_control_rematch_exp) do |original, *args|
              m = original.call(*args)
              Reloaded::TrainerControl::LevelScaling.rematch? ? m * REMATCH_EXP : m
            end
          end
          if TrainerControl.defined_method?(::PokeBattle_Battle, :pbGainMoney)
            h.around(nil, ::PokeBattle_Battle, :pbGainMoney, :id => :trainer_control_rematch_money) do |original, *args|
              ret = original.call(*args)
              Reloaded::TrainerControl::LevelScaling.pay_rematch(original.receiver)
              ret
            end
          end
        end

        def register_settings
          s = Reloaded::Settings
          s.register_page(PAGE, :group => :general, :name => "Trainer Control - Level Scaling", :icon => :features, :priority => 49.6,
            :description => "Trainers keep up with you, always: On a first battle, a trainer under the badge curve rises three quarters of the way to it (half on Easy).")
          s.register(MONEY, :page => PAGE, :priority => 21, :type => :toggle, :default => true, :scope => :save,
            :name => "Rematch Money", :description => "Rematches pay prize money: Half the first time each day with a trainer, then a quarter, then a tenth, then nothing until the next day.")
        end

        def on?(key)
          return Reloaded::Settings.get(key) != false
        end

        def rematch?
          return TrainerControl.rematch_battle?
        end

        def hard?
          return defined?(::SWITCH_GAME_DIFFICULTY_HARD) && ($game_switches[::SWITCH_GAME_DIFFICULTY_HARD] rescue false) ? true : false
        end

        def easy?
          return defined?(Reloaded::Difficulty) && Reloaded::Difficulty.respond_to?(:level) && Reloaded::Difficulty.level.to_i == 0 ? true : false
        end

        # How much of the gap to the curve a first battle closes (RISE)
        def rise
          level = defined?(Reloaded::Difficulty) && Reloaded::Difficulty.respond_to?(:level) ? Reloaded::Difficulty.level : (hard? ? 2 : 1)
          return RISE[level.to_i.clamp(0, RISE.length - 1)]
        end

        #----------------------------------------------------------------------
        # The levels
        #----------------------------------------------------------------------
        # The badge curve: PIF's level cap for your badges
        def curve
          return (getCurrentLevelCap rescue nil).to_i
        end

        # Your party's level: the higher of its average and your highest - 2
        # (no Eggs); nil with none
        def party_level
          party = ($Trainer.party rescue nil)
          lv = Array(party).compact.reject { |p| p.egg? }.map { |p| p.level.to_i }
          return nil if lv.empty?
          avg = (lv.sum / lv.length.to_f).round
          return [avg, lv.max - SPREAD].max
        end

        # The ace's new level for this trainer, or nil to leave the team
        # (the ace's level now: ace; the data's own: own, Hard's x1.1 in it)
        def target(kind, key, ace, own = nil)
          return nil if ace.nil?
          if kind == :leader || kind == :rival
            return nil if easy?            # Easy: as the game wrote them (his pick, 2026-11-10)
            pl = party_level
            return nil unless pl
            pl = (pl * HARD_LEADERS).round if hard?          # (leaders and your rival alike: his call, 2026-11-10)
            return pl > ace ? pl : nil
          end
          floor = curve - UNDER_CURVE
          return nil if floor <= 0
          if rematch?
            rec = Records.get(key)
            k = rec ? rec["rematches"].to_i + rec["before"].to_i + 1 : 1   # this rematch's number
            pl = party_level || floor
            # a Rematch Rank climbs past you (his pick, 2026-11-14: Seasoned
            # +1 .. Master +4 over your party's level)
            pl += RematchRanks.extra_levels(RematchRanks.rank(rec)) if defined?(RematchRanks)
            to = [floor, [floor + k - 1, pl].min].max
            return own ? [to, own].max : to                       # (never below their own data)
          end
          return nil unless ace < floor
          up = ((floor - ace) * rise).round
          return up > 0 ? ace + up : nil
        end

        # The data's own ace (PIF's Hard x1.1 on it), before PIF's rematch boost
        def own_ace(data)
          lv = Array(data).map { |d| d.is_a?(Hash) ? d[:level].to_i : 0 }.max.to_i
          return nil if lv <= 0
          lv = (lv * ::Settings::HARD_MODE_LEVEL_MODIFIER).ceil if hard? && defined?(::Settings::HARD_MODE_LEVEL_MODIFIER)
          return lv
        end

        def scaled?
          return false if @partner > 0
          return false if defined?(::Settings::OVERRIDE_BATTLE_LEVEL_SWITCH) && ($game_switches[::Settings::OVERRIDE_BATTLE_LEVEL_SWITCH] rescue false)
          return false if (pbBattleChallenge.pbInChallenge? rescue false)
          return false if defined?(::KIF::SelfBattle) && (::KIF::SelfBattle.active rescue false)
          return false if defined?(::KIF::Endgame) && ((::KIF::Endgame.on? && ::KIF::Endgame.challenge_map?) rescue false)
          return true
        end

        # A trainer just loaded (TrainerControl's pbLoadTrainer hook): its
        # team raised to the target
        def apply(trainer, type, name, version)
          return unless trainer && scaled? && Records.data
          key = TrainerControl.person_key(type, name)
          team = Array(trainer.party).compact
          return if key.nil? || team.empty?
          ace = team.map { |pk| pk.level.to_i }.max
          data = (::GameData::Trainer.try_get(type, name, version).pokemon rescue nil)
          to = target(TrainerControl.kind(type), key, ace, own_ace(data))
          return if to.nil? || to == ace
          max = defined?(::Settings::MAXIMUM_LEVEL) ? ::Settings::MAXIMUM_LEVEL : 100
          rng = Random.new(key.sum * 31 + to)
          team.each do |pk|
            from = pk.level.to_i
            lv = [[from + to - ace, 1].max, max].min
            next if lv == from
            pk.instance_variable_set(FROM, pk.instance_variable_get(FROM) || from)
            build(pk, lv, data_of(pk, data), rng)
          end
          Reloaded::Difficulty.floor_ivs(trainer, data) if defined?(Reloaded::Difficulty) && Reloaded::Difficulty.respond_to?(:floor_ivs)
        rescue StandardError => e
          Reloaded::Log.exception("Trainer Control couldn't scale #{type} #{name}", e, :trainer_control)
        end

        # A Pokémon built for its new level: the stage it allows (up only),
        # its level-up moves unless its set was written for it, the IVs and
        # EVs PIF gives that level unless the data sets them
        # Its own entry in the trainer data: by the place it was loaded at
        # (Adaptation's lead swap moves it; Team Expansion's and the counter
        # Pokémon have none)
        def data_of(pk, data)
          return nil unless data.is_a?(Array)
          i = pk.instance_variable_get(LeaderBuilds::DATA)
          return i.nil? ? nil : data[i.to_i]
        end

        def build(pk, lv, d, rng)
          old_species = pk.species
          pk.level = lv
          sp = stage_for(pk.species, lv, rng)
          pk.species = sp if sp && sp != old_species
          written = d && [d[:moves], d[:moves_hard], d[:moves_easy]].any? { |m| m.is_a?(Array) && !m.empty? } && pk.species == old_species
          unless written
            pk.reset_moves
            Adaptation.reteach(pk) if defined?(Adaptation)   # (what they taught it stays)
          end
          stats = defined?(::GameData::Stat) ? ::GameData::Stat : nil
          if stats
            iv_max = defined?(::Pokemon::IV_STAT_LIMIT) ? ::Pokemon::IV_STAT_LIMIT : 31
            ev_max = defined?(::Pokemon::EV_LIMIT) ? ::Pokemon::EV_LIMIT / 6 : 85
            stats.each_main do |s|
              pk.iv[s.id] = [lv / 2, iv_max].min unless d && d[:iv]
              pk.ev[s.id] = [lv * 3 / 2, ev_max].min unless d && d[:ev]
            end
          end
          pk.calc_stats
          pk.hp = pk.totalhp
        end

        # The stage of its line the level allows, evolving only (cody's
        # LeaderTeams.fit_level; a fusion's head and body each)
        def stage_for(species, lv, rng)
          lt = defined?(::KIF::LeaderTeams) ? ::KIF::LeaderTeams : nil
          return nil unless lt && lt.respond_to?(:fit_level) && lt.respond_to?(:min_level)
          up = proc do |dex|
            got = lt.fit_level(dex, lv, rng)
            got && got != dex && lt.min_level(got) >= lt.min_level(dex) ? got : dex
          end
          sym = species.to_s
          if sym =~ /\AB(\d+)H(\d+)\z/
            body = up.call(Regexp.last_match(1).to_i)
            head = up.call(Regexp.last_match(2).to_i)
            return (getFusionSpecies(body, head).id rescue nil)
          end
          dex = (::GameData::Species.get(species).id_number rescue nil)
          return nil unless dex
          got = up.call(dex)
          return got == dex ? nil : (::GameData::Species.get(got).id rescue nil)
        rescue StandardError
          return nil
        end

        #----------------------------------------------------------------------
        # Rematch money: half, a quarter, a tenth, then none, per trainer per
        # in-game day (PIF pays nothing for rematches)
        #----------------------------------------------------------------------
        def day
          t = (pbGetTimeNow rescue Time.now)
          return t.strftime("%Y-%m-%d")
        end

        def pay_rematch(battle)
          return unless rematch? && on?(MONEY) && Records.data
          return unless battle.instance_variable_get(:@internalBattle) && battle.instance_variable_get(:@moneyGain)
          return unless (battle.trainerBattle? rescue false) && TrainerControl.counted_battle?(battle)
          key = Array(battle.opponent).map { |tr| TrainerControl.person(tr) }.compact.first
          rec = key ? Records.get(key) : nil
          return unless rec
          paid = (rec["paid"] ||= {})
          today = day
          if paid["day"] != today
            paid["day"] = today
            paid["n"] = 0
          end
          share = PAYS[paid["n"].to_i]
          paid["n"] = paid["n"].to_i + 1
          return unless share
          amount = (battle.calculateMoneyGain * share).floor
          return if amount <= 0
          player = battle.pbPlayer
          old = player.money
          player.money += amount
          gained = player.money - old
          battle.pbDisplayPaused(_INTL("You got ${1} for winning!", gained.to_s_formatted)) if gained > 0
        rescue StandardError => e
          Reloaded::Log.exception("Trainer Control couldn't pay a rematch", e, :trainer_control)
        end
      end
    end
  end
end
