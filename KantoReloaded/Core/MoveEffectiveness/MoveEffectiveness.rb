# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Effectiveness (EBDX)
#==============================================================================
# Roadmap topic move-effectiveness (Wave 6; his picks, 2026-10-30): how well
# each move does, on EBDX's Fight menu.
#
#   the cursor     Battle Scene's ring round the picked move in its colour:
#                  x4 Cyan, x2 Green, x1 the usual Cursor Color, x1/2
#                  Yellow, x1/4 Red, x0 grey (each changeable; always Dark's
#                  tones: EBDX's screen is the same in every Theme Mode)
#   multiplier     a Colour Pill beside the picked move's PP (x1/2 and x1/4
#                  as a small stacked fraction); none for neutral moves
#   move dots      a dot in its colour on each move not picked, on the
#                  right; none for neutral moves
#   target pills   Double Battles: each target's name above the picked move,
#                  outlined in its colour
#   ally warning   a move that would hit your partner: a red "!" in its
#                  button and your partner's pill in red (grey when it
#                  can't be hurt)
#   target window  each of Battle Scene's rings in its target's colour
#
# The colour is the best foe's (a one-target move counts only the foes;
# your partner only for moves that hit several). Status moves show nothing
# but Thunder Wave where it fails. The maths and what counts as known:
# Reloaded::Matchup (BattleTools/Matchup.rb). Worked out once when the Fight
# menu opens (EBDX makes its buttons then): the pill, the "!" and the dot
# are drawn into EBDX's own button pictures, so they slide and swap with
# them; each frame only moves the pills' row and sets the ring's colour
# when the pick changes. EBDX only (his rule, 2026-10-30): PIF's Fight
# menu keeps KIF's own Move Effectiveness as it is; on EBDX's, KIF's
# markers and words are Off while this is On (QuietKIF: KIF::MoveEffect.on?
# answers false inside EBDX's Fight menu).
#
# A feature with a switch, On: Off leaves Battle Scene's plain ring, and
# KIF's own markers and words on EBDX's Fight menu again.
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
      :x1_2 => [:"move_effectiveness.x1_2_color", "x1/2 Color", "Yellow", "half the damage"],
      :x1_4 => [:"move_effectiveness.x1_4_color", "x1/4 Color", "Red", "a quarter of the damage or less"]
    }.freeze
    GREY = Color.new(150, 154, 162)              # x0, always
    WARN = Color.new(232, 64, 64)                # your partner would be hurt
    DARK = { :light => false }.freeze            # PartyPaint.ink's Dark tones
    CHOOSING = :@kr_move_effectiveness_target    # on the battle while a target is picked: [user, move]

    class << self
      def boot
        register_settings
        Reloaded::Features.register(FEATURE, :name => "Effectiveness (EBDX)", :page => PAGE, :order => 58,
          :description => "How well each move does on EBDX's Fight menu: The cursor in the move's color, its multiplier beside the PP, " \
                          "a dot on the other moves, and in Double Battles each target above the move. Only what the battle has shown counts.")
        Reloaded::Events.on(:setting_changed, :move_effectiveness_colors) do |e|
          key = e.is_a?(Hash) ? e[:key].to_s : ""
          @colours = nil if key.start_with?("move_effectiveness.")
        end
        register_swatch
        install
        return true
      end

      def register_settings
        s = Reloaded::Settings
        s.register_page(PAGE, :group => :general, :name => "Effectiveness (EBDX)", :icon => :features, :priority => 47,
          :feature => FEATURE,
          :description => "How well each move does, on EBDX's Fight menu. No Effect is always gray.")
        s.register(MULTIPLIER, :page => PAGE, :priority => 10, :type => :toggle, :default => true, :name => "Multiplier",
          :description => "The picked move's multiplier (x4, x2, x1/2, x1/4 or x0) in a pill beside its PP. None for the usual damage.")
        s.register(DOTS, :page => PAGE, :priority => 20, :type => :toggle, :default => true, :name => "Move Dots",
          :description => "A dot in its color on each move you haven't picked. None for the usual damage.")
        s.register(PILLS, :page => PAGE, :priority => 30, :type => :toggle, :default => true, :name => "Target Pills",
          :description => "In Double Battles, the name of each Pokémon the picked move can hit, above it, outlined in its color.")
        s.register(WARNING, :page => PAGE, :priority => 40, :type => :toggle, :default => true, :name => "Ally Warning",
          :description => "A move that would hurt your partner: A red \"!\" on it and your partner's pill in red.")
        s.register(TARGETS, :page => PAGE, :priority => 50, :type => :toggle, :default => true, :name => "Target Window Colors",
          :description => "When you pick a target, each cursor in that target's color.")
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

      # The target window's colours: { battler index => Color } (nil: the
      # usual cursor), for the move being aimed (Q13)
      def target_colours(win)
        return nil unless on? && setting?(TARGETS)
        battle = win.instance_variable_get(:@battle)
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
        Reloaded::Log.exception("Effectiveness (EBDX): the target window's colors", e, FEATURE)
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
      # While true (inside EBDX's Fight menu, the feature On), KIF's own
      # Move Effectiveness is Off: its markers and words on EBDX's buttons
      # (C-BATTLE-01, its FightWindowEBDX part) give way to these
      attr_accessor :quiet_kif

      def quiet(on)
        return yield unless on
        @quiet_kif = true
        begin
          return yield
        ensure
          @quiet_kif = false
        end
      end

      def install
        h = Reloaded::Hooks
        h.prepend(FEATURE, ::FightWindowEBDX, FightHooks, :id => :move_effectiveness_fight) if Object.const_defined?(:FightWindowEBDX)
        if defined?(::KIF::MoveEffect) && ::KIF::MoveEffect.respond_to?(:on?)
          h.prepend(FEATURE, ::KIF::MoveEffect.singleton_class, QuietKIF, :id => :move_effectiveness_quiet_kif)
        end
        return unless defined?(::PokeBattle_Battle) && ::PokeBattle_Battle.method_defined?(:pbChooseTarget)
        # the move being aimed, for the target window (the scene's
        # pbChooseTarget gets only its target data)
        h.around(FEATURE, ::PokeBattle_Battle, :pbChooseTarget, :id => :move_effectiveness_target) do |original, *args|
          battle = original.receiver
          battle.instance_variable_set(CHOOSING, [args[0], args[1]])
          begin
            original.call(*args)
          ensure
            battle.remove_instance_variable(CHOOSING) if battle.instance_variable_defined?(CHOOSING)
          end
        end
      end
    end

    # KIF's Move Effectiveness, Off while EBDX's Fight menu draws or updates
    # with this feature On (PIF's Fight menu keeps it, his pick Q14)
    module QuietKIF
      def on?
        return false if Reloaded::MoveEffectiveness.quiet_kif
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
        ret = me.quiet(@kr_quiet) { super }
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
          Reloaded::Log.exception("Effectiveness (EBDX): the Fight menu", e, Reloaded::MoveEffectiveness::FEATURE)
          @kr_effect = nil
        end
        return ret
      end

      def update
        fx = @kr_effect
        fx.pick(@index, @kr_scene) if fx
        return super unless @kr_quiet
        Reloaded::MoveEffectiveness.quiet_kif = true
        begin
          super
        ensure
          Reloaded::MoveEffectiveness.quiet_kif = false
        end
        fx.follow(@index) if fx
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
