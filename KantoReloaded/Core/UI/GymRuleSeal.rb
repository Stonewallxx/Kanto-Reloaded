# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Leader's Seal (Trainer Control's Gym Rules)
#==============================================================================
# His pick (2026-11-01, Design 2 of four): as a gym battle opens, once both
# Pokémon are out, a seal pops up over the dimmed battle (the message box
# stays clear): the leader's face on a plate in the gym's colour, LEADER'S
# RULE (or RULES) and each rule large with its type and whose side it's on
# (YOUR SIDE green, THEIR SIDE red, WHOLE FIELD gold). Each rule's line shows
# in the message box in turn while it's up (the game's own for weather and
# terrain); then it shrinks away toward the Field Strip, where each rule's
# chip stays. Its sound: the Trainer Card opening (his pick). EBDX and PIF's
# own screen alike, in the menus' Dark or Light.
#==============================================================================

module Reloaded
  module GymRuleSeal
    W = 236
    CX = 256
    CY = 150
    DIM = 110
    TO = [60, 284]                         # where it shrinks to: the Field Strip's place
    POP = [[0.5, 40], [0.8, 80], [1.06, 110], [1.0, 110]].freeze   # [zoom, dim] each step in
    SHRINK = [[0.7, 70, 255], [0.4, 30, 195], [0.18, 0, 135]].freeze
    STEP = 4                               # frames a step lasts
    SE = "GUI trainer card open"
    SIDES = { :yours => ["YOUR SIDE", :green], :theirs => ["THEIR SIDE", :red], :field => ["WHOLE FIELD", :gold] }.freeze
    P = Reloaded::Pixel
    PF = ::KIF::PixelFont
    PP = Reloaded::PartyPaint

    class << self
      # The seal for a battle's rules: up until close
      def open(battle)
        rules = Reloaded::TrainerControl::GymRules.rules(battle)
        return if rules.empty? || !battle.respond_to?(:opponent)
        tr = Array(battle.opponent).find { |t| Reloaded::TrainerControl::GymRules.gym?((t.trainer_type rescue nil)) }
        return if tr.nil?
        scene = battle.scene
        vp, z = place_in(scene)
        return unless vp
        c = Reloaded::Palette.map_menu
        @dim = Sprite.new(vp)
        @dim.bitmap = Bitmap.new(Graphics.width, Graphics.height)
        @dim.bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(0, 0, 0))
        @dim.z = z
        @sprite = Sprite.new(vp)
        @sprite.bitmap = draw(c, tr, rules)
        @sprite.ox = @sprite.bitmap.width / 2
        @sprite.oy = @sprite.bitmap.height / 2
        @sprite.z = z + 1
        @scene = scene
        pbSEPlay(SE) if defined?(pbSEPlay)
        POP.each { |zoom, dim| frame(zoom, dim, 255, CX, CY) }
      rescue StandardError => e
        Reloaded::Log.exception("The Leader's Seal couldn't open", e, :trainer_control)
        dispose
      end

      # It shrinks toward the Field Strip and goes
      def close
        return unless @sprite && !@sprite.disposed?
        SHRINK.each_with_index do |(zoom, dim, opacity), i|
          x = CX + (TO[0] - CX) * (i + 1) / SHRINK.length
          y = CY + (TO[1] - CY) * (i + 1) / SHRINK.length
          frame(zoom, dim, opacity, x, y)
        end
      rescue StandardError => e
        Reloaded::Log.exception("The Leader's Seal couldn't close", e, :trainer_control)
      ensure
        dispose
      end

      def open?
        return @sprite && !@sprite.disposed? ? true : false
      end

      # EBDX's message viewport under its message box; PIF's battle
      # viewport under its message box (z 195)
      def place_in(scene)
        msg = scene.instance_variable_get(:@msgview)
        return [msg, 99_990] if msg && !msg.disposed?
        vp = scene.instance_variable_get(:@viewport)
        return [vp, 190] if vp && !vp.disposed?
        return [nil, 0]
      end

      def frame(zoom, dim, opacity, x, y)
        @sprite.zoom_x = @sprite.zoom_y = zoom
        @sprite.opacity = opacity
        @sprite.x = x
        @sprite.y = y
        @dim.opacity = dim
        STEP.times { tick }
      end

      def tick
        if @scene && @scene.respond_to?(:pbUpdate)
          @scene.pbUpdate
        else
          Graphics.update
        end
      end

      def dispose
        [@sprite, @dim].each do |s|
          next unless s && !s.disposed?
          s.bitmap.dispose if s.bitmap && !s.bitmap.disposed?
          s.dispose
        end
        @sprite = @dim = @scene = nil
      end

      #------------------------------------------------------------------------
      # The seal
      #------------------------------------------------------------------------
      def mix(a, b, t)
        return Reloaded::Palette.mix(a, b, t)
      end

      def rgb(type)
        return (Reloaded::PartyScreen.type_rgb(type) rescue nil) || [150, 150, 150]
      end

      def pill_w(label)
        return P.width(PF::TINY, label) + 12
      end

      def side_pill(b, c, x, y, side, right)
        words, tone = SIDES[side]
        fill, ink = Reloaded::Toast.pill_colours(c, tone)
        return P.pill(b, x, y, _INTL(words), fill, ink, right)
      end

      def type_label(b, type, x, y, w, h)
        sheet = PP.type_sheet
        b.stretch_blt(Rect.new(x, y, w, h), sheet, Rect.new(0, PP.type_row(type) * 28, 64, 28)) if sheet
      end

      # The leader's face from their picture, a square from the top of them
      def face(b, type, x, y, size)
        pics = Reloaded::TrainerControl::Pictures
        bm = pics.bitmap(type)
        return unless bm
        _l, t, _r, _bt, hx = pics.bounds(bm)
        crop = [bm.width * 3 / 8, 48].max
        sx = [[hx - crop / 2, 0].max, bm.width - crop].min
        b.stretch_blt(Rect.new(x, y, size, size), bm, Rect.new(sx, [t - 2, 0].max, crop, crop))
        bm.dispose
      end

      def draw(c, tr, rules)
        gr = Reloaded::TrainerControl::GymRules
        two = rules.length > 1
        defs = rules.map { |k| gr::RULES[k] }
        w = two ? [defs.map { |d| 50 + P.width(PF::TEXT, _INTL(d[4])) + 12 + pill_w(_INTL(SIDES[d[2]][0])) }.max + 32, W].max : W
        h = two ? 104 + rules.length * 24 + 8 : 168
        gym_type = Reloaded::TrainerControl.theme_type(tr.trainer_type, Array(tr.party).compact.map { |pk| [pk.species, pk.level] }) || defs[0][3]
        tc = PP.rgb(rgb(gym_type))
        o = Bitmap.new(w, h)
        PP.chamfer_grad(o, 0, 0, w, h, 16, mix(c[:panel], tc, 0.22), mix(c[:panel], c[:dark], c[:light] ? 0.05 : 0.25), mix(c[:line], tc, 0.7))
        fx = (w - 76) / 2
        PP.chamfer_grad(o, fx, 10, fx + 76, 86, 10, mix(c[:panel2], tc, 0.7), mix(c[:panel2], tc, 0.35), mix(c[:line], tc, 0.8))
        face(o, tr.trainer_type, fx + 4, 14, 68)
        name = tr.name.to_s.upcase
        head = two ? _INTL("{1}'S RULES", name) : _INTL("{1}'S RULE", name)
        P.text(o, 0, 92, w, 13, head, PP.ink(c, rgb(gym_type)), PF::TINY, 2)
        unless two
          d = defs[0]
          P.text(o, 0, 106, w, 24, _INTL(d[4]), c[:strong], PF::ROW, 2)
          lw = 44 + 6 + pill_w(_INTL(SIDES[d[2]][0]))
          x0 = (w - lw) / 2
          type_label(o, d[3], x0, 138, 44, 18)
          side_pill(o, c, x0 + 50, 139, d[2], false)
          return o
        end
        defs.each_with_index do |d, i|
          y = 108 + i * 24
          type_label(o, d[3], 16, y + 3, 40, 16)
          P.text(o, 62, y, w - 62 - pill_w(_INTL(SIDES[d[2]][0])) - 20, 22, _INTL(d[4]), c[:strong], PF::TEXT)
          side_pill(o, c, w - 16, y + 4, d[2], true)
        end
        return o
      end
    end
  end
end
