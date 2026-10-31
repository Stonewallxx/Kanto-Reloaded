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
#                   the way (How Far They Rise: Half by default).
#   Rematches       start at the curve and climb a level each rematch,
#                   up to your party's level, then keep pace with it; never
#                   below the curve (PIF's own rematch levels replaced; its
#                   rematch evolutions stay). Half EXP; prize money (Rematch
#                   Money) half, a quarter, a tenth, then none, per trainer
#                   per in-game day.
#   Leaders, rival  Gym Leaders, the Elite Four, Champions, Rocket bosses
#                   and your rival come at your party's level (the higher of
#                   its average and your highest - 2; Hard: 10% above),
#                   never below their own.
#   A team rises    its ace to the target, the rest keeping their gaps.
#   Built for it    a raised Pokémon takes the stage its level allows,
#                   its level-up moves (hand-written sets stay), the IVs
#                   and EVs PIF gives that level; Hard's IV floor after.
#   Shown           Battle Info's foe tab: a green +12 beside the level.
#
# Each kind has its own row per save (Trainer Control - Level Scaling).
# Nothing is scaled with PIF's battle-level override on, for partners, the
# battle facilities, KIF's Self-Battle or the Endgame Challenge's maps.
#==============================================================================

module Reloaded
  module TrainerControl
    module LevelScaling
      PAGE = :trainer_control_levels
      TRAINERS = :"trainer_control.scale_trainers"
      SHARE = :"trainer_control.scale_share"
      REMATCHES = :"trainer_control.scale_rematches"
      LEADERS = :"trainer_control.scale_leaders"
      RIVALS = :"trainer_control.scale_rivals"
      MONEY = :"trainer_control.rematch_money"
      SHARES = [0.25, 0.5, 0.75, 1.0].freeze
      SHARE_NAMES = ["A Quarter", "Half", "Three Quarters", "All the Way"].freeze
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
            :description => "Trainers that keep up with you: How they rise on a first battle and in rematches.")
          s.register(TRAINERS, :page => PAGE, :priority => 10, :type => :toggle, :default => true, :scope => :save,
            :name => "Trainers", :description => "A trainer under the badge curve (4 under the next Gym Leader's level) rises toward it on your first battle, How Far They Rise of the way. Never down.")
          s.register(SHARE, :page => PAGE, :priority => 11, :type => :enum, :values => SHARE_NAMES, :default => 1, :scope => :save,
            :name => "How Far They Rise", :description => "How much of the gap to the badge curve a trainer closes on your first battle.",
            :descriptions => ["A quarter of the gap.", "Half the gap.", "Three quarters of the gap.", "All the way to the curve."])
          s.register(REMATCHES, :page => PAGE, :priority => 20, :type => :toggle, :default => true, :scope => :save,
            :name => "Rematches", :description => "A rematch starts at the badge curve and climbs a level each time, up to your party's level, then keeps pace with it. Rematches give half the EXP.")
          s.register(MONEY, :page => PAGE, :priority => 21, :type => :toggle, :default => true, :scope => :save,
            :name => "Rematch Money", :description => "Rematches pay prize money: Half the first time each day with a trainer, then a quarter, then a tenth, then nothing until the next day.")
          s.register(LEADERS, :page => PAGE, :priority => 30, :type => :toggle, :default => true, :scope => :save,
            :name => "Leaders", :description => "Gym Leaders, the Elite Four, Champions and Rocket bosses come at your party's level (the higher of its average and your highest less 2), never below their own. On Hard, 10% above.")
          s.register(RIVALS, :page => PAGE, :priority => 31, :type => :toggle, :default => true, :scope => :save,
            :name => "Rival", :description => "Your rival comes at your party's level, as the leaders do.")
        end

        def on?(key)
          return Reloaded::Settings.get(key) != false
        end

        def rematch?
          return ($game_switches[TrainerControl::REMATCH_SWITCH] rescue false) ? true : false
        end

        def hard?
          return defined?(::SWITCH_GAME_DIFFICULTY_HARD) && ($game_switches[::SWITCH_GAME_DIFFICULTY_HARD] rescue false) ? true : false
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
            return nil unless on?(kind == :leader ? LEADERS : RIVALS)
            pl = party_level
            return nil unless pl
            pl = (pl * HARD_LEADERS).round if hard? && kind == :leader
            return pl > ace ? pl : nil
          end
          floor = curve - UNDER_CURVE
          return nil if floor <= 0
          if rematch?
            return nil unless on?(REMATCHES)
            rec = Records.get(key)
            k = rec ? rec["rematches"].to_i + rec["before"].to_i + 1 : 1   # this rematch's number
            pl = party_level || floor
            to = [floor, [floor + k - 1, pl].min].max
            return own ? [to, own].max : to                       # (never below their own data)
          end
          return nil unless on?(TRAINERS) && ace < floor
          share = SHARES[Reloaded::Settings.get(SHARE).to_i] || 0.5
          up = ((floor - ace) * share).round
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
          team.each_with_index do |pk, i|
            from = pk.level.to_i
            lv = [[from + to - ace, 1].max, max].min
            next if lv == from
            pk.instance_variable_set(FROM, pk.instance_variable_get(FROM) || from)
            build(pk, lv, data.is_a?(Array) ? data[i] : nil, rng)
          end
          Reloaded::Difficulty.floor_ivs(trainer, data) if defined?(Reloaded::Difficulty) && Reloaded::Difficulty.respond_to?(:floor_ivs)
        rescue StandardError => e
          Reloaded::Log.exception("Trainer Control couldn't scale #{type} #{name}", e, :trainer_control)
        end

        # A Pokémon built for its new level: the stage it allows (up only),
        # its level-up moves unless its set was written for it, the IVs and
        # EVs PIF gives that level unless the data sets them
        def build(pk, lv, d, rng)
          old_species = pk.species
          pk.level = lv
          sp = stage_for(pk.species, lv, rng)
          pk.species = sp if sp && sp != old_species
          written = d && [d[:moves], d[:moves_hard], d[:moves_easy]].any? { |m| m.is_a?(Array) && !m.empty? } && pk.species == old_species
          pk.reset_moves unless written
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
