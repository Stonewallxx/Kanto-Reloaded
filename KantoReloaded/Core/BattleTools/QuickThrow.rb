# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Quick Throw
#==============================================================================
# Roadmap topic battle-tools (Wave 6; his picks 2026-10-17 and 2026-10-29):
# throw a ball without opening the Bag. A feature with a switch, On.
#
#   the entry      Quick Throw on the Battle Menu's Main page (its Favorite by
#                  default): A opens the panel (UI/QuickThrowPanel.rb), every
#                  ball you have with its chance of catching the foe right
#                  now (BattleTools/CatchChance.rb), the best one starred
#   a direct throw the Favorite's double press, or Quick Throw's own Controls
#                  action (Battle area, unbound at first): the Quick Throw
#                  ball, thrown at once. Two foes out: the game's target
#                  window asks which, as the Bag does
#   the ball       the last ball you threw from the Bag (each save its own);
#                  Y in the panel sets another. The Master Ball is never
#                  the Quick Throw ball by itself, never starred, and asks
#                  before it's thrown. Run out of it: "Throw your best ball
#                  instead?" (the saved ball stays)
#   the balls      the Bag's Poké Balls pocket only (his ask, 2026-10-29),
#                  in its own order (the Reloaded Bag's pocket order and
#                  Favorites), the Master Ball where the Bag puts it
#   trainers       not offered (locked), except with KIF's Rocket Mode On:
#                  then only the balls it lets through, the rest padlocked
#   the gauge      the Quick Throw ball's chance in a ring by a wild foe's HP
#                  bar (BattleTools/CatchGauge.rb), its own row to turn it off
#
# The throw is the game's: the request waits on the battle until the
# command box hands over to pbItemMenu, which registers the ball with
# pbRegisterItem after the game's own checks (its messages, if something
# changed). The Safari Zone and the Bug Contest have their own throws: no
# Quick Throw there (the Bug Contest keeps the gauge, for its Sport Ball).
#==============================================================================

module Reloaded
  module QuickThrow
    FEATURE = :quick_throw
    PAGE = :quick_throw
    GAUGE = :"quick_throw.gauge"
    SECTION = :quick_throw
    PROTECTED = [:MASTERBALL].freeze       # asks first, never starred, never saved by itself
    POCKET = 3                             # the Bag's Poké Balls pocket: the only one Quick Throw reads (his ask)
    THROWN = [4, 9].freeze                 # battle_use: thrown at a foe
    ROCKET_ONLY = 1                        # KIF's Rocket Mode: Rocket Balls only (2: every ball)

    Request = Struct.new(:battle, :index, :ball, :target)

    class << self
      attr_reader :request

      def boot
        register_settings
        Reloaded::Features.register(FEATURE, :name => "Quick Throw", :page => PAGE, :order => 59,
          :description => "Throw a ball without opening the Bag, with every ball's chance of catching the Pokémon, " \
                          "and that chance in a ring by a wild Pokémon's HP bar.")
        Reloaded::SaveStore.register(SECTION)
        register_controls
        Reloaded::Hooks.needs(:kif_option, :critical_captures, :id => :quick_throw_critical_captures)
        Reloaded::Hooks.needs(:kif_option, :rocketballsteal, :id => :quick_throw_rocket_mode)
        register_entry if defined?(Reloaded::BattleMenu)
        install
        Reloaded::CatchGauge.install if defined?(Reloaded::CatchGauge)
        return true
      end

      def on?
        return Reloaded::Features.on?(FEATURE)
      end

      def register_settings
        s = Reloaded::Settings
        s.register_page(PAGE, :group => :general, :name => "Quick Throw", :icon => :features, :priority => 48,
          :feature => FEATURE,
          :description => "Quick Throw's catch chance by a wild Pokémon's HP bar.")
        s.register(GAUGE, :page => PAGE, :priority => 10, :type => :toggle, :default => true,
          :name => "Catch Chance on HP Bar",
          :description => "The Quick Throw ball's chance of catching a wild Pokémon, in a ring beside its HP bar.")
      end

      def gauge?
        return on? && Reloaded::Settings.get(GAUGE) != false
      end

      def register_controls
        return unless defined?(Reloaded::Controls) && Reloaded::Controls.respond_to?(:register)
        Reloaded::Controls.register(:quick_throw, :name => "Quick Throw", :area => :battle, :group => "Battle Menu",
          :priority => 25, :description => "Throws the Quick Throw ball straight from the battle menu.")
      end

      def register_entry
        bm = Reloaded::BattleMenu
        bm.register(:quick_throw, :owner => bm::OWNER, :name => "Quick Throw", :priority => 5,
          :icon => proc { |_ctx| Reloaded::QuickThrow.quick_ball || :POKEBALL },   # the Quick Throw ball's picture
          :feature => FEATURE,
          :description => "Throw a ball without opening the Bag: Every ball's chance of catching it, the best one starred.",
          :condition => proc { |ctx| Reloaded::QuickThrow.offered?(ctx.battle) },
          :usable => proc { |ctx| (l = Reloaded::QuickThrow.lock(ctx)) ? l[1] : true },
          :status => proc { |ctx| Reloaded::QuickThrow.status(ctx) },
          :handler => proc { |ctx| ctx.favorite ? Reloaded::QuickThrow.direct(ctx) : Reloaded::QuickThrow.open_panel(ctx) })
        bm.shortcut(:quick_throw) { |ctx| Reloaded::QuickThrow.direct(ctx) }
      end

      #------------------------------------------------------------------------
      # The save's data: the Quick Throw ball
      #------------------------------------------------------------------------
      def data
        return Reloaded::SaveStore.section(SECTION)
      rescue StandardError
        return nil
      end

      def saved_ball
        d = data
        id = d && d["ball"]
        return nil unless id && ball?(id)
        return item(id).id
      end

      def save_ball(id)
        d = data
        d["ball"] = id.to_s if d && id
      end

      #------------------------------------------------------------------------
      # The balls
      #------------------------------------------------------------------------
      def item(id)
        return ::GameData::Item.try_get(id.is_a?(String) ? id.to_sym : id)
      rescue StandardError
        return nil
      end

      # In the Poké Balls pocket and thrown at a foe (PIF's Firecracker is in
      # the pocket but its battle use isn't a throw)
      def ball?(id)
        it = item(id)
        return it && it.pocket == POCKET && THROWN.include?(it.battle_use) ? true : false
      end

      def protected?(id)
        return PROTECTED.include?(id)
      end

      def count(id, bag = $PokemonBag)
        return 0 unless id && bag && bag.respond_to?(:pbQuantity)
        return bag.pbQuantity(id).to_i
      end

      # Every ball in the Poké Balls pocket, in the Bag's own order (the
      # Reloaded Bag's, its Favorites first): [[id, how many]]
      def balls(bag = $PokemonBag)
        return [] unless bag
        rb = Reloaded::Bag
        ids = rb.on? ? rb.rows(POCKET, 0, bag) : rb.slots(bag, POCKET).map { |s| s && s[0] }.compact
        out = []
        ids.each do |id|
          next unless ball?(id)
          it = item(id)
          next if out.any? { |o, _n| o == it.id }
          n = count(it.id, bag)
          out << [it.id, n] if n > 0
        end
        return out
      end

      # The saved ball, or the first in the Bag's order (never a protected one)
      def quick_ball(list = nil)
        return saved_ball || ((list || balls).find { |id, _n| !protected?(id) } || [])[0]
      end

      # A trainer battle lets a ball through only with Rocket Mode
      def lets_through?(battle, id)
        return true unless battle.trainerBattle?
        return battle.respond_to?(:kif_rocket_steal_ball?) && battle.kif_rocket_steal_ball?(id) ? true : false
      rescue StandardError
        return false
      end

      def rocket_mode
        return $PokemonSystem && $PokemonSystem.respond_to?(:rocketballsteal) ? $PokemonSystem.rocketballsteal.to_i : 0
      end

      # The best ball for this foe: [id, how many, result], never a protected
      # one or one the trainer would block; the Bag's order breaks a tie
      def best(battle, target, rows)
        pick = nil
        rows.each do |id, n, res|
          next if protected?(id) || !lets_through?(battle, id) || res.nil? || res.chance.nil?
          pick = [id, n, res] if pick.nil? || res.chance > pick[2].chance
        end
        return pick
      end

      # Every ball with its chance on a foe: [[id, how many, result]]
      def rows(battle, target, list = balls)
        return list.map { |id, n| [id, n, Reloaded::CatchChance.chance(battle, target, id)] }
      end

      #------------------------------------------------------------------------
      # Where Quick Throw is, and why it can't be used
      #------------------------------------------------------------------------
      def offered?(battle)
        return false if defined?(::PokeBattle_SafariZone) && battle.is_a?(::PokeBattle_SafariZone)
        return false if bug_contest?(battle)
        return true
      end

      def bug_contest?(battle)
        return defined?(::PokeBattle_BugContestBattle) && battle.is_a?(::PokeBattle_BugContestBattle) ? true : false
      end

      def foes(ctx)
        return ctx.battle.battlers.select { |b| b && !b.fainted? && b.opposes?(ctx.index) }
      end

      # The foe opposite the Pokémon choosing, else the first one
      def default_foe(ctx)
        list = foes(ctx)
        opp = ctx.battler.pbDirectOpposing(true) rescue nil
        return list.find { |b| b.equal?(opp) } || list.first
      end

      def items_allowed?(battle)
        return false unless battle.internalBattle
        return false if defined?(::KIF::Endgame) && ::KIF::Endgame.respond_to?(:on?) && ::KIF::Endgame.on? && battle.trainerBattle?
        return true
      end

      # [kind, words] when Quick Throw can't be used this turn, else nil
      def lock(ctx)
        battle = ctx.battle
        return [:items, _INTL("Items can't be used in this battle.")] unless items_allowed?(battle)
        list = balls
        if battle.trainerBattle? && list.none? { |id, _n| lets_through?(battle, id) }
          return [:trainer, _INTL("The trainer would block the ball and it would be lost.")]
        end
        return [:none, _INTL("You have no Poké Balls.")] if list.empty?
        return [:room, _INTL("Your party and every PC box are full.")] if no_room?(battle)
        return [:first, _INTL("Only your first Pokémon can throw this turn.")] unless ctx.first_action
        nz = nuzlocke(battle)
        return [:nuzlocke, nz] if nz
        return nil
      end

      def no_room?(battle)
        return battle.pbPlayer.party_full? && $PokemonStorage && $PokemonStorage.full? ? true : false
      rescue StandardError
        return false
      end

      # KIF's Nuzlocke (Nuzlocke.rb:568-580): its verdict on this battle;
      # Ghostly Possession's Ghost battles (:ghost, Leave.rb) block balls too
      def nuzlocke(battle)
        verdict = battle.respond_to?(:kif_nz) ? battle.kif_nz : nil
        return _INTL("Nuzlocke: You already had your encounter in {1}.", battle.kif_nz_place) if verdict == :used
        return _INTL("Nuzlocke: You already have its evolution line (Dupes Clause).") if verdict == :dupe
        if verdict == :ghost
          foe = (battle.pbParty(1).compact.first rescue nil)
          return _INTL("Nuzlocke: The {1} can't be caught.", foe ? foe.name : _INTL("Ghost"))
        end
        return nil
      rescue StandardError
        return nil
      end

      # Why this ball can't be thrown at this foe now (the game's own check,
      # quietly), or nil: [reason, what to do]
      def aim(battle, target, ball, first)
        if target.semiInvulnerable?
          under = target.respond_to?(:inTwoTurnAttack?) && target.inTwoTurnAttack?("0CA", "0CB")   # Dig, Dive
          return [_INTL("{1} is out of sight.", target.name),
                  under ? _INTL("Throw when it comes back to the surface.") : _INTL("Throw when it comes back into sight.")]
        end
        if defined?(::SWITCH_SILVERBOSS_BATTLE) && $game_switches && $game_switches[::SWITCH_SILVERBOSS_BATTLE]
          return [_INTL("It's too agitated to aim."), _INTL("Wait for it to calm down.")]
        end
        ok = ::ItemHandlers.triggerCanUseInBattle(ball, target.pokemon, target, nil, first, battle, battle.scene, false)
        return ok ? nil : [_INTL("You can't throw a ball right now."), ""]
      rescue StandardError => e
        Reloaded::Log.exception("Quick Throw: the game's check on #{ball}", e, FEATURE)
        return nil
      end

      # The Battle Menu row's words: the Quick Throw ball's count and chance
      def status(ctx)
        return nil if lock(ctx)
        ball = quick_ball
        return nil unless ball
        n = count(ball)
        return [_INTL("x{1}", n), :red] if n <= 0
        foe = default_foe(ctx)
        return [_INTL("x{1}", n), :dim] unless foe && lets_through?(ctx.battle, ball)
        res = Reloaded::CatchChance.chance(ctx.battle, foe, ball)
        return [_INTL("x{1} {2}", n, Reloaded::CatchChance.percent(res)), Reloaded::CatchChance.tone(res)]
      end

      # A hint chip for Quick Throw's own button: while it's offered here
      def hint?(scene)
        return false unless on? && scene
        battle = scene.instance_variable_get(:@battle)
        return false unless battle && offered?(battle) && items_allowed?(battle)
        list = balls
        return battle.trainerBattle? ? list.any? { |id, _n| lets_through?(battle, id) } : !list.empty?
      rescue StandardError
        return false
      end

      #------------------------------------------------------------------------
      # Throwing
      #------------------------------------------------------------------------
      # The panel (the Battle Menu's entry, Choose a Ball): :bag or nil
      def open_panel(ctx)
        return ctx.hidden { Reloaded::QuickThrowPanel.new(ctx).main }
      end

      # The Quick Throw ball at once (the Favorite's double press, its own
      # button): :bag or nil
      def direct(ctx)
        l = lock(ctx)
        return Reloaded::QuickThrowPanel.refuse(ctx, l) if l
        list = balls
        ball = quick_ball(list)
        return open_panel(ctx) unless ball
        foe = default_foe(ctx)
        if count(ball) <= 0
          pick = foe ? best(ctx.battle, foe, rows(ctx.battle, foe, list)) : nil
          return open_panel(ctx) unless pick
          choice = Reloaded::QuickThrowPanel.with_scene(ctx) { |sc| Reloaded::QuickThrowPanel.ran_out(sc, ball, pick, foe) }
          return nil if choice.nil?
          return open_panel(ctx) if choice == 1
          ball = pick[0]
        end
        return open_panel(ctx) unless lets_through?(ctx.battle, ball)
        if protected?(ball)
          ok = Reloaded::QuickThrowPanel.with_scene(ctx) { |sc| Reloaded::QuickThrowPanel.protected_ok?(sc, ball, foe) }
          return nil unless ok
        end
        targets = foes(ctx)
        target = targets.length == 1 ? targets[0] : nil
        if target && (why = aim(ctx.battle, target, ball, ctx.first_action))
          ctx.toast(why[0])
          return nil
        end
        return send_request(ctx, ball, target)
      end

      # The throw waits on the battle for pbItemMenu (the command box leaves
      # with Bag); the target nil when the game's target window should ask
      def send_request(ctx, ball, target)
        @request = Request.new(ctx.battle, ctx.index, ball, target ? target.index : nil)
        return :bag
      end

      def forget_request
        @request = nil
      end

      #------------------------------------------------------------------------
      # The hooks
      #------------------------------------------------------------------------
      def install
        return unless defined?(::PokeBattle_Battle)
        h = Reloaded::Hooks
        if ::PokeBattle_Battle.method_defined?(:pbItemMenu)
          h.around(FEATURE, ::PokeBattle_Battle, :pbItemMenu, :id => :quick_throw_item_menu) do |original, *args|
            Reloaded::QuickThrow.take(original.receiver, args) { original.call(*args) }
          end
        end
        if ::PokeBattle_Battle.method_defined?(:pbRegisterItem)
          h.around(FEATURE, ::PokeBattle_Battle, :pbRegisterItem, :id => :quick_throw_remember) do |original, *args|
            ret = original.call(*args)
            Reloaded::QuickThrow.remember(original.receiver, args[0], args[1]) if ret
            ret
          end
        end
        if ::PokeBattle_Battle.method_defined?(:pbEndOfBattle)
          h.around(FEATURE, ::PokeBattle_Battle, :pbEndOfBattle, :id => :quick_throw_end) do |original, *args|
            Reloaded::QuickThrow.forget_request
            Reloaded::CatchGauge.reset if defined?(Reloaded::CatchGauge)
            original.call(*args)
          end
        end
      end

      # pbItemMenu: a request for this Pokémon becomes the throw; anything
      # else is the game's Bag
      def take(battle, args)
        r = @request
        return yield unless r && r.battle.equal?(battle) && r.index == args[0].to_i
        @request = nil
        return yield unless items_allowed?(battle)        # the game says why
        return register(battle, r, args[1])
      end

      # The game's own checks, with their messages, then pbRegisterItem
      def register(battle, r, first)
        scene = battle.scene
        return false if count(r.ball) <= 0
        idx = r.target
        if idx.nil?
          if battle.pbOpposingBattlerCount(r.index) == 1
            battle.eachOtherSideBattler(r.index) { |b| idx = b.index }
          else
            idx = scene.pbChooseTarget(r.index, ::GameData::Target.get(:Foe))
          end
        end
        return false if idx.nil? || idx < 0
        target = battle.battlers[idx]
        return false unless target && !target.fainted?
        return false unless ::ItemHandlers.triggerCanUseInBattle(r.ball, target.pokemon, target, nil, first, battle, scene, true)
        @own = true
        begin
          return battle.pbRegisterItem(r.index, r.ball, idx) ? true : false
        ensure
          @own = false
        end
      end

      # A ball the player threw from the Bag becomes the Quick Throw ball
      # (never a protected one; Quick Throw's own throws don't change it)
      def remember(battle, idx, id)
        return if @own
        return unless battle.pbOwnedByPlayer?(idx) && ball?(id)
        it = item(id)
        return if protected?(it.id)
        save_ball(it.id)
      rescue StandardError => e
        Reloaded::Log.exception("Quick Throw couldn't note the ball thrown", e, FEATURE)
      end
    end
  end
end
