# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the catch chance by a wild foe's HP bar
#==============================================================================
# Design 3, Ring Gauge (his pick 2026-10-29): the Quick Throw ball in a ring
# that fills with its chance of catching the foe right now, the number in a
# pill beside it, in HR's colour bands. Quick Throw's "Catch Chance on HP
# Bar" row, On.
#
#   EBDX's box     right of the status tag (from the tag's own place and
#                  width, so EBDX's per-species and per-trainer metrics move
#                  it too), level with the HP bar's container: KIF's type
#                  icons sit over the box's right end
#   PIF's box      right of the type icons (his pick 2026-10-29, sheet
#                  battle-tools-pif-gauge: design 1)
#   when           whenever a wild foe's box shows (Rocket Mode's trainer
#                  battles too, the Bug Contest with its Sport Ball; never
#                  the Safari Zone). Redrawn only when what it shows changes:
#                  the ball and how many, HP, status, the turn, Caught Off
#                  Guard, Theme Mode; checked when the box refreshes, after
#                  an HP change and when the command box opens
#   which ball     the Quick Throw ball; run out of it, the best one (what
#                  the direct throw would offer)
#
# The gauge is one sprite in the box's own sprite list, so the box moves,
# hides, fades and flashes it with the rest of itself.
#==============================================================================

module Reloaded
  module CatchGauge
    P = Reloaded::Pixel
    PF = ::KIF::PixelFont
    FEATURE = :quick_throw
    SIZE = 27                    # the ring's box
    KEY = "kr_catch_gauge"       # its name in a box's sprite list
    PIF_DX = 233                 # PIF's box: from its x past spriteBaseX (the type icons end at +229)
    PIF_DY = 21

    @balls = {}                  # 16 px ball pictures, by ball

    class << self
      def install
        h = Reloaded::Hooks
        h.prepend(FEATURE, ::DataBoxEBDX, EBDXBox, :id => :quick_throw_gauge_ebdx) if Object.const_defined?(:DataBoxEBDX)
        h.prepend(FEATURE, ::PokemonDataBox, PIFBox, :id => :quick_throw_gauge_pif) if Object.const_defined?(:PokemonDataBox)
        [["PokeBattle_Scene", :pif], ["PokeBattle_SceneEBDX", :ebdx]].each do |name, tag|
          next unless Object.const_defined?(name)
          klass = Object.const_get(name)
          if klass.method_defined?(:pbHPChanged)
            h.around(FEATURE, klass, :pbHPChanged, :id => :"quick_throw_gauge_hp_#{tag}") do |original, *args|
              ret = original.call(*args)
              Reloaded::CatchGauge.refresh_one(original.receiver, args[0])
              ret
            end
          end
          next unless klass.method_defined?(:pbCommandMenu)
          h.around(FEATURE, klass, :pbCommandMenu, :id => :"quick_throw_gauge_turn_#{tag}") do |original, *args|
            Reloaded::CatchGauge.refresh_all(original.receiver)
            original.call(*args)
          end
        end
      end

      # The gauge for this foe: a wild battle's (Rocket Mode's trainer
      # battles, the Bug Contest), never the Safari Zone's, nor one where
      # KIF's Nuzlocke (or Ghostly Possession's Ghost) blocks every ball
      def wanted?(battle, battler)
        return false unless battle && battler && Reloaded::QuickThrow.gauge?
        return false if defined?(::PokeBattle_SafariZone) && battle.is_a?(::PokeBattle_SafariZone)
        return false unless battler.opposes?(0)
        return false if Reloaded::QuickThrow.nuzlocke(battle)
        return true unless battle.trainerBattle?
        return Reloaded::QuickThrow.rocket_mode > 0 && Reloaded::QuickThrow.balls.any? { |id, _n| Reloaded::QuickThrow.lets_through?(battle, id) }
      rescue StandardError
        return false
      end

      # The ball it shows: the Sport Ball in the Bug Contest, the Quick
      # Throw ball, or (run out, or blocked) the best one; nil for none
      def ball_for(battle, battler)
        qt = Reloaded::QuickThrow
        return :SPORTBALL if qt.bug_contest?(battle)
        ball = qt.quick_ball
        return ball if ball && qt.count(ball) > 0 && qt.lets_through?(battle, ball)
        pick = qt.best(battle, battler, qt.rows(battle, battler))
        return pick ? pick[0] : nil
      end

      def refresh_one(scene, battler)
        return unless battler.respond_to?(:index)
        sprites = scene.instance_variable_get(:@sprites)
        box = sprites ? sprites["dataBox_#{battler.index}"] : nil
        box.kr_gauge_refresh if box.respond_to?(:kr_gauge_refresh)
      rescue StandardError => e
        Reloaded::Log.exception("Quick Throw's gauge after an HP change", e, FEATURE)
      end

      def refresh_all(scene)
        sprites = scene.instance_variable_get(:@sprites)
        return unless sprites
        sprites.each do |k, box|
          next unless k.to_s.start_with?("dataBox_")
          box.kr_gauge_refresh if box.respond_to?(:kr_gauge_refresh)
        end
      rescue StandardError => e
        Reloaded::Log.exception("Quick Throw's gauges at the turn's start", e, FEATURE)
      end

      # Draws the gauge on its sprite when what it shows changed
      def paint(sprite, battle, battler)
        return if sprite.nil? || sprite.disposed?
        ball = battler.fainted? ? nil : ball_for(battle, battler)
        c = Reloaded::Palette.map_menu
        res = ball ? Reloaded::CatchChance.chance(battle, battler, ball) : nil
        sig = [ball, ball && Reloaded::QuickThrow.count(ball), battler.pokemon.object_id, battler.hp, battler.totalhp,
               battler.status, battle.turnCount, battle.caughtOffGuard, c[:light] ? 1 : 0, res && Reloaded::CatchChance.percent(res)]
        return if sprite.instance_variable_get(:@kr_sig) == sig
        sprite.instance_variable_set(:@kr_sig, sig)
        sprite.bitmap.dispose if sprite.bitmap && !sprite.bitmap.disposed?
        sprite.bitmap = ball && res ? picture(c, ball, res) : nil
      end

      # The ring, the ball in it, the number in a pill beside it
      def picture(c, ball, res)
        words = Reloaded::CatchChance.percent(res)
        tw = P.width(PF::TEXT, words)
        b = Bitmap.new(SIZE + 2 + tw + 11, SIZE)
        fill = Color.new(c[:panel2].red, c[:panel2].green, c[:panel2].blue, c[:light] ? 240 : 228)
        track = c[:light] ? Reloaded::Palette.mix(c[:panel2], c[:line], 0.7) : Color.new(40, 44, 54, 230)
        tone = c[Reloaded::CatchChance.tone(res)] || c[:txt]
        frac = res.sure ? 1.0 : res.chance.to_f
        cx = cy = SIZE / 2
        P.ui.rbox(b, 0, 0, SIZE - 1, SIZE - 1, SIZE / 2, fill)
        (0...360).step(3) do |deg|
          a = (deg - 90) * Math::PI / 180
          col = deg < frac * 360 ? tone : track
          [10, 11, 12].each { |r| b.fill_rect((cx + r * Math.cos(a)).round, (cy + r * Math.sin(a)).round, 1, 1, col) }
        end
        bm = ball_picture(ball)
        b.stretch_blt(Rect.new(cx - 8, cy - 8, 16, 16), bm, Rect.new(0, 0, bm.width, bm.height)) if bm
        x0 = SIZE + 1
        P.ui.rbox(b, x0, cy - 9, x0 + tw + 10, cy + 9, 5, fill, c[:line])
        P.text(b, x0 + 5, cy - 10, tw + 2, 20, words, tone, PF::TEXT)
        return b
      end

      # The Summary's ball picture (32 px, drawn at 16), else the item's
      def ball_picture(ball)
        return @balls[ball] if @balls.key?(ball)
        path = pbResolveBitmap("Graphics/Pictures/Summary/icon_ball_#{ball}")
        path ||= (::GameData::Item.icon_filename(ball) rescue nil)
        @balls[ball] = path ? (Bitmap.new(path) rescue nil) : nil
      end

      # The battle's over: the pictures go
      def reset
        @balls.each_value { |b| b.dispose if b && !b.disposed? }
        @balls = {}
      end

      def dispose_sprite(sprite)
        return unless sprite && !sprite.disposed?
        sprite.bitmap.dispose if sprite.bitmap && !sprite.bitmap.disposed?
      end
    end

    #--------------------------------------------------------------------------
    # EBDX's box (DataBoxEBDX, 660_EBDX/007_EBDX_UIWidgets.rb): a sprite in
    # its list with its offset (ex, ey), as KIF's stat pills are
    # (007b_EBDX_StatStageOverlay.rb)
    #--------------------------------------------------------------------------
    module EBDXBox
      def setUp
        super
        return unless Reloaded::QuickThrow.on? && Reloaded::CatchGauge.wanted?(@battle, @battler)
        st = @sprites["status"]
        s = Sprite.new(@viewport)
        s.ex = st.ex + (st.bitmap ? st.bitmap.width : 40) + 3
        s.ey = @sprites["container"].ey
        s.z = getMetric("name", :z)
        @sprites[Reloaded::CatchGauge::KEY] = s
      end

      def refresh
        super
        kr_gauge_refresh
      end

      def kr_gauge_refresh
        s = @sprites && @sprites[Reloaded::CatchGauge::KEY]
        return unless s && !s.disposed?
        unless Reloaded::QuickThrow.gauge?
          s.bitmap = nil
          s.instance_variable_set(:@kr_sig, nil)
          return
        end
        Reloaded::CatchGauge.paint(s, @battle, @battler)
      rescue StandardError => e
        Reloaded::Log.exception("Quick Throw's gauge on EBDX's box", e, Reloaded::CatchGauge::FEATURE)
      end

      def dispose
        Reloaded::CatchGauge.dispose_sprite(@sprites && @sprites[Reloaded::CatchGauge::KEY])
        super
      end
    end

    #--------------------------------------------------------------------------
    # PIF's box (PokemonDataBox, 004_PokeBattle_SceneElements.rb): a sprite in
    # its list (its visible=, opacity= and color= walk it); x= and y= place
    # each child by hand, so the gauge is placed here
    #--------------------------------------------------------------------------
    module PIFBox
      def refresh
        super
        kr_gauge_refresh
      end

      def kr_gauge_refresh
        return if disposed?
        g = @sprites[Reloaded::CatchGauge::KEY]
        unless Reloaded::QuickThrow.gauge? && Reloaded::CatchGauge.wanted?(@battler.battle, @battler)
          g.bitmap = nil if g && !g.disposed?
          g.instance_variable_set(:@kr_sig, nil) if g
          return
        end
        unless g
          g = Sprite.new(self.viewport)
          @sprites[Reloaded::CatchGauge::KEY] = g
          g.x = self.x + @spriteBaseX + Reloaded::CatchGauge::PIF_DX
          g.y = self.y + Reloaded::CatchGauge::PIF_DY
          g.z = self.z + 3
          g.visible = self.visible
          g.opacity = self.opacity
        end
        Reloaded::CatchGauge.paint(g, @battler.battle, @battler)
      rescue StandardError => e
        Reloaded::Log.exception("Quick Throw's gauge on PIF's box", e, Reloaded::CatchGauge::FEATURE)
      end

      def x=(value)
        super
        g = @sprites && @sprites[Reloaded::CatchGauge::KEY]
        g.x = value + @spriteBaseX + Reloaded::CatchGauge::PIF_DX if g && !g.disposed?
      end

      def y=(value)
        super
        g = @sprites && @sprites[Reloaded::CatchGauge::KEY]
        g.y = value + Reloaded::CatchGauge::PIF_DY if g && !g.disposed?
      end

      def z=(value)
        super
        g = @sprites && @sprites[Reloaded::CatchGauge::KEY]
        g.z = value + 3 if g && !g.disposed?
      end

      def dispose
        Reloaded::CatchGauge.dispose_sprite(@sprites && @sprites[Reloaded::CatchGauge::KEY])
        super
      end
    end
  end
end
