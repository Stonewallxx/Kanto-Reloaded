# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Critical EV Gain
#==============================================================================
# Now and then, a win trains a little harder (Roadmap topic
# critical-ev-gain, his picks 2026-10-25). A feature with a switch, On.
#
#   The ledger   while a battle runs, what each of your Pokémon really
#                gained from each knockout (PIF's pbGainEVsOne, Power items
#                and Pokérus included), and the Power item PIF read
#   The win      PIF's own win (decision 1, not a wild battle ended by a
#                catch, a battle that pays EVs), checked as pbEndOfBattle
#                starts: after the last EXP and level-ups, before "You
#                defeated...", the money and the win autosave
#   Who rolls    your own Pokémon, standing, that earned at least 1 EV this
#                battle; never while KIF's EVs Train Mode or No-EVs Mode is
#                on (their rows lock)
#   The roll     one per Pokémon, its own random numbers (never the
#                game's): the Chance (5%), doubled by a held Power item
#                whose stat can take it (then the critical goes there)
#   The stat     Natural: one it earned, by weight of what it earned;
#                Random: any allowed stat, evenly. Only allowed stats with
#                room; at 510 in all, no roll
#   The amount   all on that stat (3); what it can't take moves on to
#                another, and the summary says where
#   After        the EV Gains Party Board on the map once you have control
#                (Criticals Only by default; Every Win, Toast or Off), and
#                the Overworld Menu's EV Gains (the last battle, this
#                session)
#   Fusions      unfusing gives both Pokémon the EVs the fusion gained
#                while fused (Keep Fused EVs, On; PIF's own lose them)
#   EV Points    with KIF's EV Allocation On, battle EVs are points to
#                spend: a critical is the Amount as points (any Power item
#                doubles its chance), the board shows points (Three
#                Columns), and Bonus Stats and the Stats chips lock
#
#   Reloaded::CriticalEVGain.results          the last battle's
#   Events: :critical_ev (:pokemon, :stat, :amount, :moved)
#==============================================================================

module Reloaded
  module CriticalEVGain
    FEATURE = :critical_ev_gain
    PAGE = :critical_ev_gain
    STATS = [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED].freeze
    STAT_NAMES = ["HP", "Attack", "Defense", "Sp. Atk", "Sp. Def", "Speed"].freeze
    STAT_SHORT = ["HP", "ATK", "DEF", "SPA", "SPD", "SPE"].freeze
    STAT_KEYS = [:hp, :atk, :def, :spa, :spd, :spe].freeze
    POWER_ITEMS = [:POWERWEIGHT, :POWERBRACER, :POWERBELT, :POWERLENS, :POWERBAND, :POWERANKLET].freeze
    POWER_NAMES = ["Power Weight", "Power Bracer", "Power Belt", "Power Lens", "Power Band", "Power Anklet"].freeze   # the chips' words (no GameData at boot)
    EV_ITEMS = (POWER_ITEMS + [:MACHOBRACE]).freeze     # what PIF's EV step reads as the held item
    EV_STAT_LIMIT = 252
    EV_LIMIT = 510
    SUMMARY = ["Every Win", "Criticals Only", "Toast", "Off"].freeze
    LEDGER = :@kr_cev_ledger                            # on the battle: gone with it
    WAIT_NOTE = 600                                     # frames (about 10 s): the log says what the summary waits for

    class << self
      def boot
        register_settings
        Reloaded::Features.register(FEATURE, :name => "Critical EV Gain", :page => PAGE, :order => 60,
          :description => "Now and then, a win trains a little harder: A chance of bonus EVs for the stats your Pokémon earned.")
        install
        Mochi.install if const_defined?(:Mochi, false)
        return true
      end

      def on?
        return Reloaded::Features.on?(FEATURE)
      end

      def key(id)
        return :"critical_ev_gain.#{id}"
      end

      def setting(id)
        return Reloaded::Settings.get(key(id))
      end

      def rng
        @rng ||= Random.new
      end

      # For tests: a generator of their own
      def rng=(r)
        @rng = r
      end

      #------------------------------------------------------------------------
      # KIF's EV modes
      #------------------------------------------------------------------------
      def kif_option(name)
        ps = $PokemonSystem
        return false unless ps && ps.respond_to?(name)
        return ps.send(name).to_i == 1
      rescue StandardError
        return false
      end

      def train_mode?
        return kif_option(:evstrain)
      end

      def no_evs_mode?
        return kif_option(:noevsmode)
      end

      # Why the rows can't be changed now, or nil
      def lock_reason
        return _INTL("No-EVs Mode Is On") if no_evs_mode?
        return _INTL("EVs Train Mode Is On") if train_mode?
        return nil
      end

      # KIF's EV Allocation (per save): battle EVs become points to spend on
      # the Summary (Pokemon#kif_ev_pool), so a critical is points too
      def alloc?
        return defined?(::KIF::EVAlloc) && ::KIF::EVAlloc.respond_to?(:on?) && ::KIF::EVAlloc.on? ? true : false
      rescue StandardError
        return false
      end

      def points(pkmn)
        return pkmn.respond_to?(:kif_ev_pool) ? pkmn.kif_ev_pool.to_i : 0
      end

      # Bonus Stats and the Stats chips: points have no stat
      def stats_lock_reason
        return lock_reason || (alloc? ? _INTL("EV Allocation Is On") : nil)
      end

      # A result's critical, on stats or as points
      def crit_total(r)
        return r[:crit].sum + r[:crit_points].to_i
      end

      def allowed
        return STATS.each_index.select { |i| setting(:"stat_#{STAT_KEYS[i]}") != false }
      end

      #------------------------------------------------------------------------
      # The ledger (pbGainEVsOne): what each of your Pokémon gained
      #------------------------------------------------------------------------
      def ledger(battle)
        list = battle.instance_variable_get(LEDGER)
        battle.instance_variable_set(LEDGER, list = []) unless list
        return list
      end

      def evs(pkmn)
        return STATS.map { |s| pkmn.ev[s].to_i }
      end

      # The item PIF read in the EV step: held, else held at the battle's start
      def ev_item(battle, idx, pkmn)
        held = (pkmn.item_id rescue nil)
        return held if EV_ITEMS.include?(held)
        start = (battle.instance_variable_get(:@initialItems)[0][idx] rescue nil)
        start = start.id if start.respond_to?(:id)
        return EV_ITEMS.include?(start) ? start : held
      end

      # before: its EVs before the knockout; pool_before: its EV points then
      # (EV Allocation keeps the EVs as they were and adds points instead)
      def note_gain(battle, idx, pkmn, before, pool_before = nil)
        after = evs(pkmn)
        gain = after.each_index.map { |i| after[i] - before[i] }
        got = pool_before ? points(pkmn) - pool_before : 0
        return if gain.all? { |g| g <= 0 } && got <= 0
        list = ledger(battle)
        entry = list.find { |e| e[:pokemon].equal?(pkmn) }
        list << (entry = { :pokemon => pkmn, :gain => [0] * 6, :points => 0, :item => nil }) unless entry
        gain.each_with_index { |g, i| entry[:gain][i] += g if g > 0 }
        entry[:points] += got if got > 0
        entry[:item] = ev_item(battle, idx, pkmn)
      end

      #------------------------------------------------------------------------
      # The win
      #------------------------------------------------------------------------
      def win?(battle)
        return false unless battle.instance_variable_get(:@decision) == 1
        return false if battle.wildBattle? && Array(battle.instance_variable_get(:@caughtPokemon)).length > 0
        return false unless battle.instance_variable_get(:@internalBattle)
        return false if battle.instance_variable_get(:@expGain) == false
        return true
      end

      def own?(pkmn)
        return $Trainer && Array($Trainer.party).any? { |p| p.equal?(pkmn) }
      end

      # The rolls at the win; the last battle's results. Each entry:
      # { :pokemon, :normal => [6], :crit => [6], :item, :moved, :fainted },
      # and with EV Allocation { :points, :crit_points, :pool } (the points
      # it earned, the critical's, and those waiting to be spent after)
      def on_win(battle)
        all = ledger(battle)
        list = all.select { |e| own?(e[:pokemon]) }
        if list.empty?
          Reloaded::Log.info("EV Gains: A win, but none of your Pokémon earned EVs or EV points (#{all.length} noted)", :critical_ev_gain)
          return @results = []
        end
        locked = !lock_reason.nil?
        @results = list.map do |e|
          pkmn = e[:pokemon]
          r = { :pokemon => pkmn, :normal => e[:gain].dup, :crit => [0] * 6, :item => e[:item], :moved => nil,
                :fainted => !(pkmn.respond_to?(:able?) ? pkmn.able? : pkmn.hp.to_i > 0) }
          if e[:points].to_i > 0
            r[:points] = e[:points]
            r[:crit_points] = 0
            roll_points(r, battle) unless locked || r[:fainted]
            r[:pool] = points(pkmn)
          else
            roll(r, e[:gain]) unless locked || r[:fainted]
          end
          r
        end
        queue_summary(@results)
        Reloaded::Log.info("EV Gains: A win, #{@results.length} earned EVs, #{@results.count { |r| crit_total(r) > 0 }} critical(s)#{locked ? " (#{lock_reason})" : ""}; " \
                           "Summary #{SUMMARY[setting(:summary).to_i]}: #{@pending.nil? ? "nothing to show" : "shown once you have control"}", :critical_ev_gain)
        return @results
      end

      # One Pokémon's roll (r: its result, earned: what each stat gained)
      def roll(r, earned)
        pkmn = r[:pokemon]
        return if earned.sum <= 0
        return if evs(pkmn).sum >= EV_LIMIT
        allow = allowed
        room = ->(i) { pkmn.ev[STATS[i]].to_i < EV_STAT_LIMIT }
        pool = if setting(:mode).to_i == 0 then allow.select { |i| earned[i] > 0 }
               else allow
               end
        pool = pool.select { |i| room.call(i) }
        return if pool.empty?
        chance = setting(:chance).to_i
        forced = nil
        p_item = POWER_ITEMS.index(r[:item])
        if p_item && setting(:boost) != false && pool.include?(p_item)
          chance = [chance * 2, 100].min
          forced = p_item
        end
        return unless rng.rand(100) < chance
        stat = forced || pick(pool, earned)
        give(r, stat, setting(:amount).to_i.clamp(1, 10), pool, earned, allow)
      end

      # With EV Allocation (his pick: Criticals Become Points): the Amount as
      # points to spend, its chance doubled by any held Power item, within
      # 510 in all; KIF's "got N EV points" line after the win counts them
      def roll_points(r, battle)
        pkmn = r[:pokemon]
        return unless defined?(::KIF::EVAlloc) && ::KIF::EVAlloc.room(pkmn) > 0
        chance = setting(:chance).to_i
        chance = [chance * 2, 100].min if POWER_ITEMS.include?(r[:item]) && setting(:boost) != false
        return unless rng.rand(100) < chance
        n = ::KIF::EVAlloc.add_points(pkmn, setting(:amount).to_i.clamp(1, 10))
        return if n <= 0
        r[:crit_points] = n
        told = battle.instance_variable_get(:@kif_eva_gained)
        told[pkmn] += n if told.is_a?(Hash)
        Reloaded::Events.emit(:critical_ev, :pokemon => pkmn, :stat => nil, :amount => n, :moved => nil, :points => true)
      end

      # Natural: by weight of what each stat earned; Random: evenly
      def pick(pool, earned)
        if setting(:mode).to_i == 0
          total = pool.sum { |i| earned[i] }
          n = rng.rand(total)
          pool.each do |i|
            return i if n < earned[i]
            n -= earned[i]
          end
        end
        return pool[rng.rand(pool.length)]
      end

      # The amount on one stat; what it can't take moves on (his pick, Q11):
      # to the pool's others (the most earned first), then any allowed stat
      def give(r, stat, amount, pool, earned, allow = pool)
        pkmn = r[:pokemon]
        got = raise_ev(pkmn, stat, amount)
        r[:crit][stat] += got
        left = amount - got
        order = (pool - [stat]).sort_by { |i| [-earned[i], i] } + (allow - pool - [stat])
        order.each do |i|
          break if left <= 0
          more = raise_ev(pkmn, i, left)
          next if more <= 0
          r[:crit][i] += more
          r[:moved] ||= [stat, i, more]
          left -= more
        end
        Reloaded::Events.emit(:critical_ev, :pokemon => pkmn, :stat => STATS[stat], :amount => amount - left, :moved => r[:moved])
      end

      # PIF's own pbJustRaiseEffortValues (both caps, the stats worked out)
      def raise_ev(pkmn, i, amount)
        return pbJustRaiseEffortValues(pkmn, STATS[i], amount).to_i if defined?(pbJustRaiseEffortValues)
        total = evs(pkmn).sum
        add = [amount, EV_STAT_LIMIT - pkmn.ev[STATS[i]].to_i, EV_LIMIT - total].min
        return 0 if add <= 0
        pkmn.ev[STATS[i]] += add
        pkmn.calc_stats if pkmn.respond_to?(:calc_stats)
        return add
      end

      def results
        return @results || []
      end

      def critical?(list = results)
        return list.any? { |r| crit_total(r) > 0 }
      end

      #------------------------------------------------------------------------
      # After the battle: the summary once you have control
      #------------------------------------------------------------------------
      def queue_summary(list)
        mode = setting(:summary).to_i
        @pending = nil
        return if list.empty? || mode == 3
        return if mode != 0 && !critical?(list)
        @pending = mode
        @waited = 0
      end

      def pending
        return @pending
      end

      def on_map(scene)
        return unless @pending && $scene == scene
        why = waiting_for
        if why
          @waited = @waited.to_i + 1
          Reloaded::Log.info("EV Gains: Still waiting to show the summary (#{why})", :critical_ev_gain) if @waited == WAIT_NOTE
          return
        end
        mode = @pending
        @pending = nil
        Reloaded::Log.info("EV Gains: #{mode == 2 ? "The toast" : "The board"} shown", :critical_ev_gain)
        if mode == 2
          Reloaded::CriticalEVGainScreen.toast(results)        # one toast: the first critical (+N More)
        else
          Reloaded::CriticalEVGainScreen.board(results)
        end
      rescue StandardError => e
        Reloaded::Log.exception("The EV Gains summary couldn't show", e, :critical_ev_gain)
      end

      def can_show?
        return waiting_for.nil?
      end

      # What keeps the summary off the screen now, or nil
      def waiting_for
        return "the map isn't ready" unless $game_temp && $game_player && defined?(Reloaded::CriticalEVGainScreen)
        return "you're moving" if $game_player.moving?
        return "a menu is open" if $game_temp.in_menu
        return "a battle is on" if $game_temp.in_battle
        return "a message is showing" if $game_temp.respond_to?(:message_window_showing) && $game_temp.message_window_showing
        return "a map change" if $game_temp.respond_to?(:player_transferring) && $game_temp.player_transferring
        return "a screen transition" if $game_temp.respond_to?(:transition_processing) && $game_temp.transition_processing
        return "an event is running" if defined?(pbMapInterpreterRunning?) && pbMapInterpreterRunning?
        return nil
      end

      # The Overworld Menu's EV Gains: the last battle's board
      def show_last
        return Reloaded::CriticalEVGainScreen.board(results) unless results.empty?
        Reloaded::CriticalEVGainScreen.nothing
      end

      #------------------------------------------------------------------------
      # Fusions: unfusing gives both Pokémon what the fusion gained
      #------------------------------------------------------------------------
      def carry_fused(fusion)
        return unless setting(:keep_fused) != false
        body = fusion.respond_to?(:original_body) ? fusion.original_body : nil
        head = fusion.respond_to?(:original_head) ? fusion.original_head : nil
        return unless body && head
        gained = STATS.each_index.map { |i| [fusion.ev[STATS[i]].to_i - body.ev[STATS[i]].to_i, 0].max }
        return if gained.sum <= 0
        [head, body].each do |part|
          gained.each_with_index { |g, i| raise_ev(part, i, g) if g > 0 }
        end
      end

      #------------------------------------------------------------------------
      # Hooks (feature :critical_ev_gain)
      #------------------------------------------------------------------------
      def install
        h = Reloaded::Hooks
        h.needs(:kif_option, :evstrain, :id => :cev_train_mode)
        h.needs(:kif_option, :noevsmode, :id => :cev_no_evs_mode)
        if defined?(::PokeBattle_Battle)
          if ::PokeBattle_Battle.method_defined?(:pbGainEVsOne)
            h.around(FEATURE, ::PokeBattle_Battle, :pbGainEVsOne, :id => :cev_ledger) do |original, *args|
              battle = original.receiver
              pkmn = (battle.pbParty(0)[args[0]] rescue nil)
              before = pkmn && pkmn.respond_to?(:ev) ? Reloaded::CriticalEVGain.evs(pkmn) : nil
              pool = before ? Reloaded::CriticalEVGain.points(pkmn) : nil
              ret = original.call(*args)
              Reloaded::CriticalEVGain.note_gain(battle, args[0], pkmn, before, pool) if before
              ret
            end
          end
          if ::PokeBattle_Battle.method_defined?(:pbEndOfBattle)
            h.around(FEATURE, ::PokeBattle_Battle, :pbEndOfBattle, :id => :cev_win) do |original, *args|
              battle = original.receiver
              Reloaded::CriticalEVGain.on_win(battle) if Reloaded::CriticalEVGain.win?(battle)
              original.call(*args)
            end
          end
        end
        if Object.private_method_defined?(:unfuseCore) || Object.method_defined?(:unfuseCore)
          h.around(FEATURE, Object, :unfuseCore, :id => :cev_keep_fused) do |original, *args|
            Reloaded::CriticalEVGain.carry_fused(args[0]) if args[0]
            original.call(*args)
          end
        end
        h.prepend(FEATURE, "Scene_Map", MapHooks, :id => :cev_summary_map) if defined?(::Scene_Map)
        register_menu_entry
      end

      def register_menu_entry
        return unless defined?(Reloaded::OverworldMenu)
        Reloaded::OverworldMenu.register(:ev_gains, :name => "EV Gains", :kind => :action, :priority => 80, :feature => FEATURE,
          :home => false,
          :description => "The EVs your Pokémon gained in your last battle, criticals in gold.",
          :handler => proc { |_menu| Reloaded::CriticalEVGain.show_last; nil })
      end

      #------------------------------------------------------------------------
      # Settings (his picks: Stat Chips; the rules this save, Summary every
      # save)
      #------------------------------------------------------------------------
      def register_settings
        s = Reloaded::Settings
        lock = proc { Reloaded::CriticalEVGain.lock_reason }
        stats_lock = proc { Reloaded::CriticalEVGain.stats_lock_reason }
        s.register_page(PAGE, :group => :general, :name => "Critical EV Gain", :icon => :features, :priority => 47,
          :feature => FEATURE,
          :description => "Bonus EVs after a win, and what you see after it.")
        s.register(key(:chance), :page => PAGE, :priority => 10, :type => :slider, :min => 0, :max => 100, :default => 5,
          :steps => [1, 5], :unit => "%", :scope => :save, :lock => lock, :name => "Chance",
          :description => "After each win, the chance that a Pokémon that earned EVs gets bonus EVs. Holding its Power item doubles it.")
        s.register(key(:amount), :page => PAGE, :priority => 20, :type => :slider, :min => 1, :max => 10, :default => 3,
          :format => proc { |v| "+#{v}" }, :scope => :save, :lock => lock, :name => "Amount",
          :description => "How many bonus EVs a critical gives, all on one stat. What a stat can't take goes to another.")
        s.register(key(:mode), :page => PAGE, :priority => 30, :type => :enum, :values => ["Natural", "Random"], :default => 0,
          :scope => :save, :lock => stats_lock, :name => "Bonus Stats",
          :descriptions => ["One of the stats it earned this battle, most likely the one it earned most.",
                            "Any allowed stat, picked evenly, whatever it earned."],
          :description => "Which stat a critical goes to.")
        s.register(key(:boost), :page => PAGE, :priority => 40, :type => :toggle, :default => true, :scope => :save,
          :lock => lock, :name => "Power Items Boost",
          :description => "Holding a Power item doubles the chance, and the critical goes to that item's stat.")
        s.register(key(:summary), :page => PAGE, :priority => 50, :type => :enum, :values => SUMMARY, :default => 1,
          :lock => lock, :name => "Summary",
          :descriptions => ["After every win, back on the map: Every Pokémon that earned EVs, on one board.",
                            "The same board, only after a battle with a critical.",
                            "No board: A short line at the top after a critical.",
                            "Nothing after the battle. The Overworld Menu's EV Gains still shows the last one."],
          :description => "What you see back on the map after a win.")
        STATS.each_index do |i|
          s.register(key(:"stat_#{STAT_KEYS[i]}"), :page => PAGE, :priority => 60 + i, :type => :toggle, :default => true,
            :scope => :save, :lock => stats_lock, :name => STAT_NAMES[i], :chips => "Stats", :chip => STAT_SHORT[i],
            :description => "Whether a critical can give #{STAT_NAMES[i]} EVs. Normal EVs still count.",
            :descriptions => ["No critical gives #{STAT_NAMES[i]} EVs, even with a #{POWER_NAMES[i]}. Normal EVs still count.",
                              "A critical can give #{STAT_NAMES[i]} EVs. Normal EVs still count."])
        end
        s.register(key(:keep_fused), :page => PAGE, :priority => 80, :type => :toggle, :default => true, :scope => :save,
          :name => "Keep Fused EVs",
          :description => "Unfusing gives both Pokémon the EVs the fusion gained while fused, normal and critical. Off: The game's own way, they're lost.")
      end
    end

    # Scene_Map: the summary once the player has control (one check a frame)
    module MapHooks
      def update
        super
        Reloaded::CriticalEVGain.on_map(self) if Reloaded::CriticalEVGain.pending
      end
    end
  end
end
