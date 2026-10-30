# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Battle Scene's command rows
#==============================================================================
# EBDX's Fight, Bag, Party and Run (660_EBDX/007_EBDX_UIWidgets.rb,
# CommandWindowEBDX) as Battle Scene's Command Row setting picks (his picks,
# 2026-10-29). Each is drawn into EBDX's own button sprites (two frames: as
# they are and picked), so EBDX's input, slide and cursor memory carry on:
#
#   EBDX's Own     EBDX's buttons; the Reloaded ring round the picked one
#                  (Battle Cursor: Reloaded)
#   Plates         (the default) EBDX's places, each command a Kanto
#                  Reloaded plate (cut corners, lit from the top, a soft
#                  shadow), its word and a bar under it in EBDX's colour for
#                  it; the picked one filled with its colour, raised 2 px, no
#                  bar, the ring on its edge cut like it
#   Slim Bar       one bar along the bottom, a section a command, thin lines
#                  between them; the picked section lights up in its colour
#                  over the lines it touches (no ring)
#   Corner Panel   the four as a 2 x 2 of plates in a panel at the bottom
#                  right (Up and Down move a row); a panel at the bottom left
#                  says "What will X do?" with the Field Strip's chips and the
#                  hint chips. With more than four commands (DEBUG, KIF's
#                  INFO) it's Plates for that turn.
#
# Colours are EBDX's own (read from its button picture, Vivid); words dark on
# a light fill. Drawn when a command box opens; each frame only places the
# ring and the picked section.
#==============================================================================

module Reloaded
  class CommandRow
    P = Reloaded::Pixel
    PF = ::KIF::PixelFont
    PP = Reloaded::PartyPaint
    WHITE = Color.new(255, 255, 255)
    BLACK = Color.new(0, 0, 0)
    SLIDE = 80                   # EBDX's show: eight steps of 10
    PLATE_H = 34
    PLATE_CUT = 7
    SLIM_Y = 360
    SLIM_H = 24
    SLIM_STRIP = 338             # the Field Strip's (and hint chips') line over the Slim Bar
    CORNER_W = 112
    CORNER_RIGHT = [262, 298, 246, 84].freeze
    CORNER_LEFT = [4, 298, 252, 84].freeze
    FALLBACK = [[214, 92, 92], [80, 200, 96], [224, 200, 72], [84, 140, 224], [72, 208, 192]].freeze

    attr_reader :kind

    def initialize(win)
      @win = win
      @sprites = win.instance_variable_get(:@sprites)
      @viewport = win.instance_variable_get(:@viewport)
      @battle = win.instance_variable_get(:@battle)
      @extra = []
    end

    # After EBDX's refreshCommands(index): this command box's row
    def refresh(index, labels)
      dispose_extra
      @ring&.dispose
      @ring = nil
      @kind = Reloaded::BattleScene.row
      @kind = :plates if @kind == :corner && labels.length != 4
      @n = labels.length
      @last = nil
      c = Reloaded::Palette.map_menu
      bg = @sprites["bg"]
      case @kind
      when :plates
        plates(c, labels)
        @ring = Reloaded::BattleCursor::Ring.new(@viewport, 99, :plate, :cut => PLATE_CUT)
      when :slim
        slim(c, labels)
      when :corner
        corner(c, labels, index)
        @ring = Reloaded::BattleCursor::Ring.new(@viewport, 99, :plate, :cut => PLATE_CUT)
      else
        @ring = Reloaded::BattleCursor::Ring.new(@viewport, 99, :edge) if Reloaded::BattleScene.ring?
      end
      bg.visible = (@kind == :ebdx || @kind == :plates) if bg
    end

    # Each frame of the command box (after EBDX's update)
    def update(index)
      sel = @sprites["sel"]
      sel.visible = false if sel && (@kind != :ebdx || @ring)
      b = @sprites["b#{index}"]
      return @ring&.hide unless b && !b.disposed?
      case @kind
      when :ebdx
        @ring.follow(b) if @ring
      when :plates
        b.src_rect.y = 0
        b.visible ? @ring.place(b.x - b.ox, b.y - b.oy + 2, @pw, PLATE_H) : @ring.hide
      when :corner
        b.src_rect.y = 0
        b.visible ? @ring.place(b.x - b.ox, b.y - b.oy, CORNER_W, PLATE_H) : @ring.hide
      when :slim
        b.src_rect.y = 0
        if @last != index
          @last = index
          @n.times { |i| s = @sprites["b#{i}"]; s.z = (i == index ? 1 : 0) if s && !s.disposed? }
        end
      end
    end

    # EBDX's show and hide move its buttons 10 a step; the Corner Panel's
    # panels go with them, and the ring waits for the row to stop
    def slide(dy)
      @extra.each { |s| s.y += dy unless s.disposed? }
      @ring&.hide
    end

    def dispose
      dispose_extra
      @ring&.dispose
      @ring = nil
    end

    #--------------------------------------------------------------------------
    private
    #--------------------------------------------------------------------------
    def mix(a, b, t); return Reloaded::Palette.mix(a, b, t); end

    def alpha(col, a); return Color.new(col.red, col.green, col.blue, a); end

    def on_fill(col)
      return (0.3 * col.red + 0.59 * col.green + 0.11 * col.blue) > 150 ? mix(col, BLACK, 0.72) : WHITE
    end

    # EBDX's colour for button i (its picture's row, CommandWindowEBDX#
    # refreshCommands), Vivid
    def colour(c, i)
      rgb = FALLBACK[[i, FALLBACK.length - 1].min]
      btn = @win.instance_variable_get(:@btnCmd)
      if btn && !btn.disposed?
        h = btn.height / 5
        x = i > 3 ? btn.width / 2 : 0
        px = btn.get_pixel(x + 8, h * [i, 4].min + 8)
        rgb = [px.red.to_i, px.green.to_i, px.blue.to_i] if px && px.alpha > 0
      end
      return PP.ink(c, rgb)
    end

    def replace(spr, bm)
      old = spr.bitmap
      spr.bitmap = bm
      old.dispose if old && !old.disposed? && !old.equal?(bm)
    end

    #--------------------------------------------------------------------------
    # Plates
    #--------------------------------------------------------------------------
    def plates(c, labels)
      spacing = 512 / (@n + 1)
      @pw = [96, spacing - 6].min
      labels.each_with_index do |name, i|
        b = @sprites["b#{i}"]
        next unless b
        ink = colour(c, i)
        bm = Bitmap.new(@pw * 2, 42)
        plate(bm, c, 0, 4, @pw, ink, name, false, true)
        plate(bm, c, @pw, 2, @pw, ink, name, true, true)
        replace(b, bm)
        b.src_rect.set(0, 0, @pw, 42)
        b.ox = @pw / 2
        b.oy = 21
      end
    end

    def plate(bm, c, x, y, w, ink, name, picked, shadow)
      h = PLATE_H
      if picked
        bm.fill_rect(x + 3, y + h + 1, w - 4, 2, alpha(BLACK, 90)) if shadow
        PP.chamfer_grad(bm, x, y, x + w, y + h, PLATE_CUT, mix(ink, WHITE, 0.22), ink, mix(ink, BLACK, 0.35))
        bm.fill_rect(x + 8, y + 1, w - 16, 1, mix(ink, WHITE, 0.45))
        P.text(bm, x, y + 5, w, 26, name, on_fill(ink), PF::TEXT, 2)
      else
        bm.fill_rect(x + 3, y + h, w - 4, 2, alpha(BLACK, 70)) if shadow
        PP.chamfer_grad(bm, x, y, x + w, y + h, PLATE_CUT, c[:panel2], c[:panel], c[:line])
        bm.fill_rect(x + 8, y + 1, w - 16, 1, mix(c[:panel2], WHITE, c[:light] ? 0.6 : 0.12))
        bm.fill_rect(x + 8, y + 29, w - 16, 2, ink)
        P.text(bm, x, y + 3, w, 26, name, ink, PF::TEXT, 2)
      end
    end

    #--------------------------------------------------------------------------
    # Slim Bar
    #--------------------------------------------------------------------------
    def slim(c, labels)
      bar = alpha(c[:panel2], c[:light] ? 236 : 224)
      xs = (0..@n).map { |k| 512 * k / @n }
      labels.each_with_index do |name, i|
        b = @sprites["b#{i}"]
        next unless b
        sw = xs[i + 1] - xs[i]
        fw = sw + 1
        ink = colour(c, i)
        bm = Bitmap.new(fw * 2, SLIM_H)
        bm.fill_rect(0, 0, sw, SLIM_H, bar)
        bm.fill_rect(0, 0, sw, 1, c[:line])
        bm.fill_rect(0, 4, 1, 16, c[:line]) if i > 0
        P.text(bm, 0, 2, sw, 20, name, ink, PF::TEXT, 2)
        lw = i < @n - 1 ? sw + 1 : sw           # over the line it touches on its right
        (SLIM_H - 1).times do |k|
          bm.fill_rect(fw, 1 + k, lw, 1, mix(mix(ink, WHITE, 0.25), mix(ink, BLACK, 0.15), k.to_f / (SLIM_H - 2)))
        end
        bm.fill_rect(fw, 0, lw, 1, c[:line])
        bm.fill_rect(fw, 1, lw, 1, mix(ink, WHITE, 0.5))
        P.text(bm, fw, 2, sw, 20, name, on_fill(ink), PF::TEXT, 2)
        replace(b, bm)
        b.src_rect.set(0, 0, fw, SLIM_H)
        b.ox = 0
        b.oy = 0
        b.x = xs[i]
        b.y = SLIM_Y + SLIDE
      end
    end

    #--------------------------------------------------------------------------
    # Corner Panel
    #--------------------------------------------------------------------------
    def corner(c, labels, index)
      rx, ry, rw, rh = CORNER_RIGHT
      add_extra(panel(c, rw, rh), rx, ry)
      lx, ly, lw, lh = CORNER_LEFT
      left = panel(c, lw, lh)
      fill_left(left, c, index)
      add_extra(left, lx, ly)
      labels.each_with_index do |name, i|
        b = @sprites["b#{i}"]
        next unless b
        ink = colour(c, i)
        bm = Bitmap.new(CORNER_W * 2, PLATE_H)
        plate(bm, c, 0, 0, CORNER_W, ink, name, false, false)
        plate(bm, c, CORNER_W, 0, CORNER_W, ink, name, true, false)
        replace(b, bm)
        b.src_rect.set(0, 0, CORNER_W, PLATE_H)
        b.ox = 0
        b.oy = 0
        b.x = rx + 8 + (i.odd? ? CORNER_W + 6 : 0)
        b.y = ry + 6 + (i >= 2 ? PLATE_H + 4 : 0) + SLIDE
      end
    end

    def panel(c, w, h)
      bm = Bitmap.new(w, h)
      PP.chamfer_grad(bm, 0, 0, w, h, 9, alpha(c[:panel2], 236), alpha(c[:panel], 236), c[:line])
      return bm
    end

    # "What will X do?", the field's chips under it, the hint chips at the
    # bottom
    def fill_left(bm, c, index)
      who = (@battle.battlers[index].name rescue "").to_s
      P.text(bm, 12, 5, bm.width - 20, 22, _INTL("What will {1} do?", who), c[:strong], PF::TEXT)
      if defined?(Reloaded::BattleMenu) && Reloaded::BattleMenu.strip?
        items = Reloaded::FieldStrip.strip_items(@battle)
        Reloaded::FieldStrip.flow(bm, c, items, 10, bm.width - 8, 26, 1) unless items.empty?
      end
      Reloaded::HintChips.draw(bm, c, bm.width - 8, 64) if Reloaded::BattleScene.hints?
    rescue StandardError => e
      Reloaded::Log.exception("Battle Scene: the Corner Panel's left panel", e, Reloaded::BattleScene::FEATURE)
    end

    def add_extra(bm, x, y)
      s = Sprite.new(@viewport)
      s.bitmap = bm
      s.x = x
      s.y = y + SLIDE
      s.z = -1
      @extra << s
    end

    def dispose_extra
      @extra.each do |s|
        next if s.disposed?
        s.bitmap.dispose if s.bitmap && !s.bitmap.disposed?
        s.dispose
      end
      @extra = []
    end
  end
end
