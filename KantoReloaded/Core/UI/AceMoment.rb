# encoding: utf-8
#==============================================================================
# Kanto Reloaded: an Ace Moment on screen (Trainer Control's Ace Moments)
#==============================================================================
# His picks (2026-11-01, round 2): EBDX and PIF's own screen alike, in the
# menus' Dark or Light.
#
#   The cut-in   (Design 3, Speech Pill) before their ace is sent out: the
#                battle dims; the trainer slides in from the right onto
#                their own spot, twice their size (a bigger picture to the
#                same 220 px standing height); their line slides in from the
#                left over the foe's databox place as a big Split Pill, 300
#                wide: the end in their type's colour holds their class
#                (small) over their name, cut on a slant into the line (up
#                to four lines). Its sound: Vs flash. A or B moves on once
#                it's in; it leaves by itself after a while long enough to
#                read it.
#   The ACE pill (Design 1, Big Ace Pill) once the ace is out (after its
#                Mega Evolution, when it has one): the Split Pill at 40 tall
#                from the right edge, under the foe's databoxes: the foe-red
#                end with the ace's icon (the Mega's after a Mega) and name,
#                a gold ACE tag, then each raised stat in green with an up
#                arrow. Its sound: the ability pop-up's (EBDX/Ability
#                Message).
#==============================================================================

module Reloaded
  module AceMoment
    STEP = 4                               # frames each step of the mockups' 100 ms lasts
    PILL_W = 300
    STAND = 220                            # the trainer's standing height, at most twice their size
    CX = 392                               # where they stand: the middle of the foe's side
    ART_SLIDE = 330                        # how far right they come in from
    FEET = { :ebdx => 230, :pif => 222 }.freeze
    LINE_TOP = { :ebdx => 30, :pif => 12 }.freeze          # over the foe's databox place
    BOX_BOTTOM = { :ebdx => 76, :pif => 58 }.freeze        # under the foe's databox (one Pokémon a side)
    LOWER = { :ebdx => [0, 0, 34, 84], :pif => [0, 0, 28, 58] }.freeze   # its lowest box in doubles, triples
    EDGE = 10
    LINES = 4
    # [line's offset, trainer's offset (0 home, 1 gone), dim] each step
    CUT_IN = [[1.0, 1.0, 30], [0.55, 0.55, 60], [0.25, 0.25, 80], [0.08, 0.08, 90], [0.0, 0.0, 90]].freeze
    CUT_OUT = [[0.15, 0.15, 60], [0.5, 0.5, 30], [1.0, 1.0, 0]].freeze
    HOLD = 18                              # steps the line stays at least, then a step for every 4 letters
    HOLD_MAX = 45
    SKIP_AFTER = 12                        # frames before A or B can move it on (a press from the last message doesn't)
    PILL_IN = [0.6, 0.3, 0.1, 0.0].freeze
    PILL_OUT = [0.15, 0.45, 1.0].freeze
    PILL_HOLD = 20
    PILL_H = 40
    ICON = 44
    SE_CUT = "Vs flash"
    SE_PILL = "EBDX/Ability Message"
    FOE_RGB = [240, 60, 60].freeze
    GOLD_RGB = [240, 190, 40].freeze
    STAT_WORDS = { :ATTACK => "Attack", :DEFENSE => "Defense", :SPECIAL_ATTACK => "Sp. Atk", :SPECIAL_DEFENSE => "Sp. Def",
                   :SPEED => "Speed" }.freeze
    STAR = ["...#...", "..###..", "#######", ".#####.", "..###..", ".##.##.", ".#...#."].freeze
    UP = ["....#....", "...###...", "..#####..", ".#######.", "#########"].freeze
    WHITE = Color.new(255, 255, 255)
    P = Reloaded::Pixel
    PF = ::KIF::PixelFont
    PP = Reloaded::PartyPaint

    class << self
      def kind(scene)
        return defined?(::PokeBattle_SceneEBDX) && scene.is_a?(::PokeBattle_SceneEBDX) ? :ebdx : :pif
      end

      #------------------------------------------------------------------------
      # The cut-in: trainer, their line (the ace's name in it), the type their
      # end is coloured in
      #------------------------------------------------------------------------
      def cut_in(battle, trainer, line, type)
        scene = battle.scene
        vp, z = Reloaded::GymRuleSeal.place_in(scene)
        return unless vp
        k = kind(scene)
        c = Reloaded::Palette.map_menu
        @scene = scene
        @dim = Sprite.new(vp)
        @dim.bitmap = Bitmap.new(Graphics.width, Graphics.height)
        @dim.bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(0, 0, 0))
        @dim.z = z
        @dim.opacity = 0
        @art = trainer_sprite(vp, trainer.trainer_type, k)
        @art.z = z + 1 if @art
        @line = Sprite.new(vp)
        @line.bitmap = speech_pill(c, trainer, line, type)
        @line.y = LINE_TOP[k]
        @line.z = z + 2
        pbSEPlay(SE_CUT) if defined?(pbSEPlay)
        CUT_IN.each { |lf, af, dim| cut_frame(lf, af, dim) }
        hold = [HOLD + line.to_s.length / 4, HOLD_MAX].min * STEP
        hold.times do |i|
          tick
          break if i >= SKIP_AFTER && (Input.trigger?(Input::USE) || Input.trigger?(Input::BACK))
        end
        CUT_OUT.each { |lf, af, dim| cut_frame(lf, af, dim) }
      rescue StandardError => e
        Reloaded::Log.exception("An Ace Moment's cut-in couldn't show", e, :trainer_control)
      ensure
        dispose
      end

      def cut_frame(line_off, art_off, dim)
        @dim.opacity = dim
        @line.x = EDGE - (line_off * (PILL_W + EDGE)).round
        if @art
          @art.x = @art_x + (art_off * ART_SLIDE).round
          @art.visible = art_off < 1.0
        end
        STEP.times { tick }
      end

      # The trainer on their own spot, twice their size at most (their
      # picture's drawn part STAND tall)
      def trainer_sprite(vp, type, k)
        pics = Reloaded::TrainerControl::Pictures
        bm = pics.bitmap(type)
        return nil unless bm
        l, t, r, b, = pics.bounds(bm)
        zoom = [2.0, STAND.to_f / [b - t, 1].max].min
        s = Sprite.new(vp)
        s.bitmap = bm
        s.zoom_x = s.zoom_y = zoom
        @art_x = (CX - (l + r) / 2.0 * zoom).round
        s.x = @art_x
        s.y = (FEET[k] - b * zoom).round
        return s
      end

      #------------------------------------------------------------------------
      # The ACE pill: the battler, the stats its moment raised
      #------------------------------------------------------------------------
      def pill(battle, battler, stats)
        scene = battle.scene
        vp, z = Reloaded::GymRuleSeal.place_in(scene)
        return unless vp
        k = kind(scene)
        c = Reloaded::Palette.map_menu
        @scene = scene
        @line = Sprite.new(vp)
        @line.bitmap = ace_pill(c, battler.name.to_s.upcase, stats)
        @line.z = z + 2
        size = (battle.pbSideSize(1) rescue 1).to_i.clamp(1, 3)
        @line.y = BOX_BOTTOM[k] + LOWER[k][size]
        shown = (battler.displayPokemon rescue nil) || battler.pokemon          # an Illusion's disguise, as its box shows
        @icon = Reloaded::PartyIcons.icon(shown, vp, z + 3) if shown
        pbSEPlay(SE_PILL) if defined?(pbSEPlay)
        PILL_IN.each { |t| pill_frame(t) }
        (PILL_HOLD * STEP).times do |i|
          tick
          break if i >= SKIP_AFTER && (Input.trigger?(Input::USE) || Input.trigger?(Input::BACK))
        end
        PILL_OUT.each { |t| pill_frame(t) }
      rescue StandardError => e
        Reloaded::Log.exception("An Ace Moment's ACE pill couldn't show", e, :trainer_control)
      ensure
        dispose
      end

      def pill_frame(t)
        w = @line.bitmap.width
        home = Graphics.width - EDGE - w
        @line.x = (home + (Graphics.width - home) * t).round
        @line.opacity = (255 * (1 - t * 0.6)).round
        if @icon
          Reloaded::PartyIcons.place(@icon, @line.x + w - 24, @line.y + 6 + PILL_H / 2 - 1)
          @icon.zoom_x = @icon.zoom_y = @icon.zoom_x * ICON / Reloaded::PartyIcons::FRAME.to_f
          @icon.opacity = @line.opacity
        end
        STEP.times { tick }
      end

      def tick
        if @scene && @scene.respond_to?(:pbUpdate)
          @scene.pbUpdate
        else
          Graphics.update
          Input.update
        end
      end

      def dispose
        [@line, @dim, @art].each do |s|
          next unless s && !s.disposed?
          s.bitmap.dispose if s.bitmap && !s.bitmap.disposed?
          s.dispose
        end
        @icon.dispose if @icon && !@icon.disposed?
        @line = @dim = @art = @icon = @scene = nil
      end

      #------------------------------------------------------------------------
      # Drawing
      #------------------------------------------------------------------------
      def mix(a, b, t)
        return Reloaded::Palette.mix(a, b, t)
      end

      # A colour at the Split Pill's own strength (Double Abilities' ends)
      def vivid(c, rgb)
        hue = PP.hsl(*rgb)[0]
        return PP.hsl_color(hue, 0.85, c[:light] ? 0.50 : 0.44)
      end

      def type_rgb(type)
        return (Reloaded::PartyScreen.type_rgb(type) rescue nil) || [150, 150, 150]
      end

      # A capsule's left edge at row y (radius r, h tall), 0 on its straight part
      def round_in(y, h, r)
        d = (y + 0.5 - h / 2.0).abs - (h / 2.0 - r)
        return d > 0 ? (r - Math.sqrt([r * r - d * d, 0].max)).round : 0
      end

      # The Speech Pill: the class wrapped in two lines at most when it's
      # long (TEAM ROCKET EXECUTIVE), the line in four
      def speech_pill(c, trainer, line, type)
        cls = P.wrap((trainer.trainer_type_name rescue "").to_s.upcase, 100, PF::TINY).first(2)
        name = trainer.name.to_s
        seg = ([P.width(PF::ROW, name)] + cls.map { |l| P.width(PF::TINY, l) }).max + 26
        tw = PILL_W - seg - 10 - 14 - 12
        lines = P.wrap(line, tw, PF::TEXT).first(LINES)
        h = [lines.length * 20 + 16, 56].max
        r = 14
        o = Bitmap.new(PILL_W, h)
        P.ui.rbox(o, 0, 0, PILL_W, h, r, c[:panel])
        fill = vivid(c, type_rgb(type))
        (0...h).each do |y|
          d = [r - y, y - (h - 1 - r), 0].max
          l = d > 0 ? (r - Math.sqrt([r * r - d * d, 0].max)).round : 0
          split = seg + ((h - 1 - y) * 10 / (h - 1).to_f).round
          o.fill_rect(l, y, split - l, 1, fill)
        end
        cy = h / 2 - 20 - (cls.length - 1) * 6
        cls.each_with_index { |l, i| P.text(o, 14, cy + i * 13, seg, 14, l, WHITE, PF::TINY) }
        P.text(o, 14, cy + cls.length * 13, seg, 24, name, WHITE, PF::ROW)
        ty = (h - lines.length * 20) / 2
        lines.each_with_index { |l, i| P.text(o, seg + 22, ty + i * 20, tw + 4, 20, l, c[:strong], PF::TEXT) }
        return o
      end

      def stat_words_w(stats)
        return stats.sum { |s| 13 + P.width(PF::ROW, _INTL(STAT_WORDS[s])) } + 12 * [stats.length - 1, 0].max
      end

      # The Big Ace Pill: 40 tall in a bitmap 6 taller each way (the icon
      # stands over its edge)
      def ace_pill(c, name, stats)
        h = PILL_H
        r = h / 2 - 1
        y0 = 6
        seg = 46 + P.width(PF::TEXT, name) + 8
        tag_w = 18 + P.width(PF::TEXT, _INTL("ACE")) + 10
        inner = tag_w + 10 + stat_words_w(stats)
        w = seg + 10 + 12 + inner + 16
        o = Bitmap.new(w, h + 12)
        P.ui.rbox(o, 0, y0, w, y0 + h, r, c[:panel])
        red = vivid(c, FOE_RGB)
        (0...h).each do |y|
          l = round_in(y, h, r)
          split = seg + ((h - 1 - y) * 10 / (h - 1).to_f).round
          o.fill_rect(w - split, y0 + y, split - l, 1, red)
        end
        nw = P.width(PF::TEXT, name)
        P.text(o, w - 46 - nw, y0, nw + 2, h, name, WHITE, PF::TEXT)
        x = w - seg - 10 - 12 - inner
        P.ui.rbox(o, x, y0 + 8, x + tag_w, y0 + h - 8, 6, vivid(c, GOLD_RGB))
        PP.pixels(o, STAR, x + 6, y0 + h / 2 - 4, WHITE)
        P.text(o, x + 17, y0 + 8, tag_w - 18, h - 16, _INTL("ACE"), WHITE, PF::TEXT)
        x += tag_w + 10
        green = c[:green]
        stats.each do |s|
          PP.pixels(o, UP, x, y0 + h / 2 - 3, green)
          x += 13
          x += P.text(o, x, y0, 200, h, _INTL(STAT_WORDS[s]), green, PF::ROW) + 12
        end
        return o
      end
    end
  end
end
