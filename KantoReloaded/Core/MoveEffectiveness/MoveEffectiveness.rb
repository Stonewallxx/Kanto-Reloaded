# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Effectiveness
#==============================================================================
# Roadmap topic move-effectiveness (Wave 6; his picks, 2026-10-30 for EBDX's
# Fight menu, 2026-11-05 for PIF's own): how well each move does, on either
# Fight menu. One feature, one switch (his pick: "Effectiveness", was
# Effectiveness (EBDX)); every row and colour counts on both screens.
#
#   the cursor     EBDX: Battle Scene's ring round the picked move in its
#                  colour. PIF: PIF's own picked-move button recoloured
#                  (PIFMenus.rb). x4 Cyan, x2 Green, x1 the usual cursor,
#                  x1/2 Red, x1/4 Yellow, x0 grey (each changeable; always
#                  Dark's tones: neither screen changes with Theme Mode)
#   multiplier     a Colour Pill on the picked move (EBDX: beside its PP;
#                  PIF: at its right end; x1/2 and x1/4 as a small diagonal
#                  fraction); none for neutral moves
#   move dots      a dot in its colour on each move not picked, on the
#                  right; none for neutral moves
#   target pills   Double Battles: each target's name above the picked move,
#                  outlined in its colour
#   ally warning   a move that would hit your partner: a red "!" in its
#                  button and your partner's pill in red (grey when it
#                  can't be hurt)
#   target window  EBDX: each of Battle Scene's rings in its target's
#                  colour. PIF: each picked button in it
#
# The colour is the best foe's (a one-target move counts only the foes;
# your partner only for moves that hit several). Status moves show nothing
# but Thunder Wave where it fails. The maths and what counts as known:
# Reloaded::Matchup (BattleTools/Matchup.rb). Worked out once when the Fight
# menu opens. EBDX (FightOverlay.rb): the pill, the "!" and the dot are
# drawn into EBDX's own button pictures, so they slide and swap with them;
# each frame only moves the pills' row and sets the ring's colour when the
# pick changes. PIF (PIFMenus.rb): redrawn when the pick changes.
#
# It takes over KIF's own Move Effectiveness (C-BATTLE-01, his pick
# 2026-11-05): while this is On, KIF's draws nothing on either Fight menu
# and its row in Cody Settings hides (:takes_over), and QuietKIF makes
# KIF::MoveEffect.on? answer false (KIF's module switch aside). KIF's
# immunity list (KIF::MoveEffect.known_immunity?) is still read by Matchup.
#
# A feature with a switch, On: Off leaves Battle Scene's plain ring, PIF's
# own buttons, and KIF's own markers and words on both Fight menus again.
#==============================================================================

module Reloaded
  module MoveEffectiveness
    FEATURE = :move_effectiveness
    PAGE = :move_effectiveness
    MULTIPLIER = :"move_effectiveness.multiplier"
    DOTS = :"move_effectiveness.dots"
    PILLS = :"move_effectiveness.target_pills"
    WARNING = :"move_effectiveness.ally_warning"
    TARGETS = :"move_effectiveness.target_colors"
    # level => [setting, name, default colour, what it is]
    COLORS = {
      :x4   => [:"move_effectiveness.x4_color", "x4 Color", "Cyan", "4 times the damage or more"],
      :x2   => [:"move_effectiveness.x2_color", "x2 Color", "Green", "twice the damage"],
      :x1   => [:"move_effectiveness.x1_color", "x1 Color", nil, "the usual damage"],
      :x1_2 => [:"move_effectiveness.x1_2_color", "x1/2 Color", "Red", "half the damage"],
      :x1_4 => [:"move_effectiveness.x1_4_color", "x1/4 Color", "Yellow", "a quarter of the damage or less"]
    }.freeze
    GREY = Color.new(150, 154, 162)              # x0, always
    WARN = Color.new(232, 64, 64)                # your partner would be hurt
    DARK = { :light => false }.freeze            # PartyPaint.ink's Dark tones
    CHOOSING = :@kr_move_effectiveness_target    # on the battle while a target is picked: [user, move]

    @changes = {}

    class << self
      def boot
        register_settings
        Reloaded::Features.register(FEATURE, :name => "Effectiveness", :page => PAGE, :order => 58,
          :takes_over => ["C-BATTLE-01_Effectiveness"],
          :description => "How well each move does on the Fight menu: The cursor in the move's color, its multiplier by the PP, " \
                          "a dot on the other moves, and in Double Battles each target above the move. Only what the battle has shown counts.")
        Reloaded::Events.on(:setting_changed, :move_effectiveness_colors) do |e|
          key = e.is_a?(Hash) ? e[:key].to_s : ""
          if key.start_with?("move_effectiveness.")
            @colours = nil
            Recolour.clear if defined?(Recolour)
          end
        end
        register_swatch
        user_change(:mega, proc { |win| mega_pressed?(win) }, proc { |_win, u| mega_view(u) })
        install
        return true
      end

      def register_settings
        s = Reloaded::Settings
        s.register_page(PAGE, :group => :general, :name => "Effectiveness", :icon => :features, :priority => 47,
          :feature => FEATURE,
          :description => "How well each move does, on PIF's and EBDX's Fight menus. No Effect is always gray.")
        s.register(MULTIPLIER, :page => PAGE, :priority => 10, :type => :toggle, :default => true, :name => "Multiplier",
          :description => "The picked move's multiplier (x4, x2, x1/2, x1/4 or x0) in a pill by its PP. None for the usual damage.")
        s.register(DOTS, :page => PAGE, :priority => 20, :type => :toggle, :default => true, :name => "Move Dots",
          :description => "A dot in its color on each move you haven't picked. None for the usual damage.")
        s.register(PILLS, :page => PAGE, :priority => 30, :type => :toggle, :default => true, :name => "Target Pills",
          :description => "In Double Battles, the name of each Pokémon the picked move can hit, above it, outlined in its color.")
        s.register(WARNING, :page => PAGE, :priority => 40, :type => :toggle, :default => true, :name => "Ally Warning",
          :description => "A move that would hurt your partner: A red \"!\" on it and your partner's pill in red.")
        s.register(TARGETS, :page => PAGE, :priority => 50, :type => :toggle, :default => true, :name => "Target Window Colors",
          :description => "When you pick a target, its cursor (EBDX) or button (PIF's) in that target's color.")
        names = ["Theme"] + Reloaded::Palette::COLORS.map { |c| c[0] }
        COLORS.each_with_index do |(_lv, (key, name, default, what)), i|
          d = default ? (Reloaded::Palette::COLORS.index { |c| c[0] == default } || -1) + 1 : 0
          s.register(key, :page => PAGE, :priority => 60 + i * 10, :type => :enum, :long => true, :swatch => :move_effect,
            :values => names, :default => d, :name => name,
            :description => "The color of a move that does #{what}. Theme: Your Cursor Color.")
        end
      end

      def on?
        return Reloaded::Features.on?(FEATURE)
      end

      def setting?(key)
        return Reloaded::Settings.get(key) != false
      end

      #------------------------------------------------------------------------
      # The colours
      #------------------------------------------------------------------------
      # A level's colour, Vivid in Dark's tones (x1 and "Theme": the battle
      # cursor's own, as Battle Scene draws it)
      def colour(level)
        return GREY if level == :x0
        return value_colour(Reloaded::Settings.get(COLORS[level][0]).to_i) if level == :x1
        @colours ||= {}
        return @colours[level] ||= value_colour(Reloaded::Settings.get(COLORS[level][0]).to_i)
      end

      # A colour setting's value (0 Theme, then Palette::COLORS)
      def value_colour(v)
        entry = v > 0 ? Reloaded::Palette::COLORS[v - 1] : nil
        return Reloaded::BattleCursor.colour unless entry
        rgb = entry[1].to_i(16)
        return Reloaded::PartyPaint.ink(DARK, [(rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255])
      end

      # The pickers show each colour as the Colour Pill shows it
      def register_swatch
        return unless defined?(Reloaded::Dialogs)
        Reloaded::Dialogs.swatches[:move_effect] = proc do |b, _c, x, y, h, i|
          Reloaded::Pixel.ui.rbox(b, x, y + 5, x + 22, y + h - 7, 5, Reloaded::MoveEffectiveness.value_colour(i))
          22
        end
      end

      # The battle whose player is aiming a move now (pbChooseTarget), for
      # PIF's target window, which doesn't know its battle
      attr_reader :aiming

      # The target window's colours: { battler index => Color } (nil: the
      # usual cursor), for the move being aimed (Q13). win: EBDX's target
      # window (it knows its battle)
      def target_colours(win)
        return target_colours_for(win.instance_variable_get(:@battle))
      end

      def target_colours_for(battle)
        return nil unless on? && setting?(TARGETS)
        user, move = battle && battle.instance_variable_get(CHOOSING)
        return nil unless user && move
        u = user.dup
        out = {}
        battle.battlers.each do |b|
          next if b.nil? || b.fainted? || b.index == user.index
          v = Reloaded::Matchup.value_for(move, u, b)
          next if v.nil?
          out[b.index] = b.opposes?(user) ? level_colour(v) : ally_colour(v)
        end
        return out
      rescue StandardError => e
        Reloaded::Log.exception("Effectiveness: the target window's colors", e, FEATURE)
        return nil
      end

      # nil for x1: the usual cursor
      def level_colour(val)
        lv = Reloaded::Matchup.level(val)
        return lv.nil? || lv == :x1 ? nil : colour(lv)
      end

      # Your partner: red when it would be hurt (Ally Warning), gray when it can't be
      def ally_colour(val)
        return GREY if ::Effectiveness.ineffective?(val)
        return setting?(WARNING) ? WARN : level_colour(val)
      end

      #------------------------------------------------------------------------
      # The hooks
      #------------------------------------------------------------------------
      #------------------------------------------------------------------------
      # Fight menu buttons that change your Pokémon before the turn
      #------------------------------------------------------------------------
      # While a button like Mega Evolution is pressed, the moves are worked
      # out with your Pokémon as it will be (its ability and types change a
      # move's type and what the foes are immune to). Another mod's button:
      #   Reloaded::MoveEffectiveness.user_change(:my_button,
      #     proc { |win| win.instance_variable_get(:@my_button_on) },   # pressed?
      #     proc { |win, user| ... })    # a changed copy of user (a copy already), or nil
      # The Fight menu checks on? each frame and works everything out again
      # when one changes.
      def user_change(id, on, apply)
        @changes[id.to_sym] = [on, apply]
        return true
      end

      # Which buttons are pressed now, as bits (no allocation: read each frame)
      def changes_key(win)
        key = 0
        bit = 1
        @changes.each_value do |on, _apply|
          key |= bit if (on.call(win) rescue false)
          bit <<= 1
        end
        return key
      end

      # Your Pokémon for the maths: a copy, as each pressed button makes it
      def user(win, battler)
        u = battler.dup
        @changes.each do |id, (on, apply)|
          next unless (on.call(win) rescue false)
          begin
            v = apply.call(win, u)
            u = v if v
          rescue StandardError => e
            Reloaded::Log.warning_once("Effectiveness: #{id}'s change to your Pokémon couldn't be worked out (#{e.class}: #{e.message})", FEATURE)
          end
        end
        return u
      end

      # Mega Evolution's button pressed: EBDX's Fight menu keeps it in
      # @megaActive, PIF's shows it pressed in mode 2
      def mega_pressed?(win)
        return true if win.instance_variable_get(:@megaActive)
        return defined?(::FightMenuDisplay) && win.is_a?(::FightMenuDisplay) && win.mode == 2 ? true : false
      end

      # Mega Evolution, or the Megas mod's Primal Reversion on the same
      # button: the user's copy holding a copy of its Pokémon made Mega
      # (PIF's makeMega, or the mod's), with that one's ability and types.
      # nil when it changes neither
      def mega_view(u)
        pk = u.pokemon
        return nil unless pk && (pk.respond_to?(:makeMega) || pk.respond_to?(:makePrimal))
        now = [pk.ability_id, pk.type1, pk.type2]
        [:makeMega, :makePrimal].each do |m|
          next unless pk.respond_to?(m)
          copy = pk.dup
          copy.send(m)
          next if [copy.ability_id, copy.type1, copy.type2] == now
          v = u.dup
          v.instance_variable_set(:@pokemon, copy)
          v.instance_variable_set(:@form, copy.form) if copy.respond_to?(:form)
          v.instance_variable_set(:@type1, copy.type1)
          v.instance_variable_set(:@type2, copy.type2)
          v.instance_variable_set(:@ability_id, copy.ability_id)
          # KIF-ER's innates are the Mega's own
          if v.instance_variable_defined?(:@innate_ids) && defined?(::KIFER) && ::KIFER.respond_to?(:battle_innates)
            v.instance_variable_set(:@innate_ids, ::KIFER.battle_innates(copy))
          end
          return v
        end
        return nil
      end

      def install
        h = Reloaded::Hooks
        h.prepend(FEATURE, ::FightWindowEBDX, FightHooks, :id => :move_effectiveness_fight) if Object.const_defined?(:FightWindowEBDX)
        h.prepend(FEATURE, ::FightMenuDisplay, PifFightHooks, :id => :move_effectiveness_pif_fight) if Object.const_defined?(:FightMenuDisplay)
        h.prepend(FEATURE, ::TargetMenuDisplay, PifTargetHooks, :id => :move_effectiveness_pif_targets) if Object.const_defined?(:TargetMenuDisplay)
        if defined?(::KIF::MoveEffect) && ::KIF::MoveEffect.respond_to?(:on?)
          h.prepend(FEATURE, ::KIF::MoveEffect.singleton_class, QuietKIF, :id => :move_effectiveness_quiet_kif)
        end
        return unless defined?(::PokeBattle_Battle) && ::PokeBattle_Battle.method_defined?(:pbChooseTarget)
        # the move being aimed, for the target windows (the scene's
        # pbChooseTarget gets only its target data; PIF's window not even
        # its battle)
        h.around(FEATURE, ::PokeBattle_Battle, :pbChooseTarget, :id => :move_effectiveness_target) do |original, *args|
          battle = original.receiver
          battle.instance_variable_set(CHOOSING, [args[0], args[1]])
          was = Reloaded::MoveEffectiveness.instance_variable_get(:@aiming)
          Reloaded::MoveEffectiveness.instance_variable_set(:@aiming, battle)
          begin
            original.call(*args)
          ensure
            battle.remove_instance_variable(CHOOSING) if battle.instance_variable_defined?(CHOOSING)
            Reloaded::MoveEffectiveness.instance_variable_set(:@aiming, was)
          end
        end
      end
    end

    # KIF's own Move Effectiveness (C-BATTLE-01), Off on both Fight menus
    # while this feature is On (his pick, 2026-11-05: taken over). Only
    # C-BATTLE-01 asks it; :takes_over turns its module's hooks off too, this
    # covers a game where that can't be done
    module QuietKIF
      def on?
        return false if Reloaded::MoveEffectiveness.on?
        return super
      end
    end

    #--------------------------------------------------------------------------
    # EBDX's Fight menu (FightOverlay.rb draws)
    #--------------------------------------------------------------------------
    module FightHooks
      def generateButtons(*args)
        me = Reloaded::MoveEffectiveness
        @kr_quiet = me.on?
        ret = super
        begin
          if @kr_quiet
            @kr_effect ||= Reloaded::MoveEffectiveness::FightOverlay.new(@viewport)
            return ret if @kr_effect.build(self)
          end
          if @kr_effect
            @kr_effect.dispose
            @kr_effect = nil
          end
          @kr_scene.colour = nil if @kr_scene.respond_to?(:colour=)    # Battle Scene's plain ring
        rescue StandardError => e
          # EBDX's Fight menu goes on as it is
          Reloaded::Log.exception("Effectiveness: EBDX's Fight menu", e, Reloaded::MoveEffectiveness::FEATURE)
          @kr_effect = nil
        end
        return ret
      end

      def update
        fx = @kr_effect
        if fx && fx.changed?(self)
          kr_regenerate
          fx = @kr_effect
        end
        fx.pick(@index, @kr_scene) if fx
        ret = super
        fx.follow(@index) if fx && @kr_quiet
        return ret
      end

      # A button that changes your Pokémon before the turn was pressed:
      # EBDX makes its move buttons again (every mod's drawing on them too,
      # and this feature's, worked out with the change), each where and as it
      # was, the pick kept (no hop)
      def kr_regenerate
        keep = (0...@nummoves.to_i).map do |i|
          b = @button["#{i}"]
          b && !b.disposed? ? [b.x, b.y, b.z, b.visible, b.opacity] : nil
        end
        generateButtons
        keep.each_with_index do |k, i|
          b = @button["#{i}"]
          next unless k && b
          b.x, b.y, b.z, b.visible, b.opacity = k
        end
        @oldindex = @index
      end

      def show
        super
        @kr_effect.hide if @kr_effect
      end

      def hide
        super
        @kr_effect.hide if @kr_effect
      end

      def dispose
        @kr_effect.dispose if @kr_effect
        @kr_effect = nil
        super
      end
    end
  end
end
