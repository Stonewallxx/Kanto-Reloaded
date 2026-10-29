# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Battle Menu's panel
#==============================================================================
# Design 1, Centred Panel (his pick 2026-10-17, redrawn in the kit; its
# popups picked as drawn 2026-10-28, sheet battle-menu-popups-2): the
# entries as rows with their pictures and statuses, the Favorite starred in
# gold, the description box under the panel with the hints in it, so the
# battle's command box stays in view. Over the battle, dimmed.
#
#   Main / Mods   LB and RB turn the pages, a dot each under the title;
#                 with no other mod's entries only Main (no LB, RB or dots).
#                 A mod's row shows its mod's name where Main's show statuses
#   A             runs the entry (dimmed with a padlock when it can't now:
#                 the reason in red in the description box)
#   the Battle Menu button   runs the Favorite (none: closes the panel)
#   Y             Options: Set as Favorite or Remove Favorite, Move, Cancel
#   B             closes it
# The mouse too: a click runs a row, the wheel moves, a right click closes.
# Dark or Light only (Theme Mode), like every full KR screen.
#==============================================================================

module Reloaded
  class BattleMenuPanel
    include Reloaded::Frame
    PF = ::KIF::PixelFont
    PP = Reloaded::PartyPaint
    DL = Reloaded::Dialogs
    BI = Reloaded::ButtonIcons
    PW = 300          # the panel's width
    PY = 30           # its top
    RH = 30           # a row
    MAX_ROWS = 7      # rows before the list scrolls
    DESC_H = 66       # the description box
    DIM = 70          # the battle behind, dimmed

    def initialize(ctx)
      frame_init
      @ctx = ctx
      @bm = Reloaded::BattleMenu
      @pictures = {}
      @index = 0
      @top = 0
      @moving = false
      @pages = @bm.pages(ctx)
      @page = [[@bm.page_index, 0].max, @pages.length - 1].min
    end

    def main
      @ctx.screen = self
      open_sprites
      @hint_sprite.visible = false          # the hints live in the description box
      refresh
      loop do
        Graphics.update
        Input.update
        update_frame
        return nil if over?
        r = handle_input
        next if r.nil?
        return r == :close ? nil : r
      end
    ensure
      @ctx.screen = nil
      @pictures.each_value { |b| b.dispose if b && !b.disposed? }
      @pictures = {}
      dispose_sprites if @viewport
    end

    # The battle ended under it (a forfeit, Multiplayer's abort)
    def over?
      return @ctx.battle.decision.to_i != 0
    rescue StandardError
      return false
    end

    def page_key
      return @pages[@page] || "main"
    end

    def list
      return @list ||= @bm.page_entries(page_key, @ctx)
    end

    def current
      return list[@index]
    end

    #--------------------------------------------------------------------------
    # Input
    #--------------------------------------------------------------------------
    # nil keeps the panel open; :close, or a game command (:bag...) closes it
    def handle_input
      pt = Reloaded::Pointer
      if pt.moved? && (i = row_at) && i != @index
        @index = i
        refresh
      end
      if @moving
        return moving_input
      elsif @bm.trigger?(:battle_menu)
        return favorite
      elsif pt.left? && (i = row_at)
        @index = i
        return use
      elsif pt.left? && (act = hint_hit)
        return send(act)
      elsif pt.right?
        pbPlayCancelSE
        return :close
      elsif pt.wheel != 0
        step(pt.wheel)
      elsif Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN)
        step(Input.repeat?(Input::UP) ? -1 : 1, Input.trigger?(Input::UP) || Input.trigger?(Input::DOWN))
      elsif Input.trigger?(Input::L) || Input.trigger?(Input::R)
        turn_page(Input.trigger?(Input::L) ? -1 : 1)
      elsif Input.trigger?(Input::USE)
        return use
      elsif Input.trigger?(Input::X)
        return options
      elsif Input.trigger?(Input::BACK)
        pbPlayCancelSE
        return :close
      end
      return nil
    end

    def step(dir, wrap = false)
      return if list.empty?
      to = @index + dir
      if to < 0 || to >= list.length
        return unless wrap
        to %= list.length
      end
      @index = to
      pbPlayCursorSE
      refresh
    end

    def turn_page(dir)
      return if @pages.length < 2
      @page = (@page + dir) % @pages.length
      @bm.page_index = Reloaded::BattleMenu::PAGES.index(page_key)
      @index = 0
      @top = 0
      @list = nil
      pbPlayCursorSE
      refresh
    end

    # A: the entry
    def use
      e = current
      return nil unless e
      r = @bm.run(e, @ctx)
      return after_run(e, r)
    end

    # What an entry's answer does to the panel
    def after_run(e, r)
      if r.is_a?(Array) && r[0] == :locked
        pbPlayBuzzerSE
        return nil
      end
      if r == :failed
        pbPlayBuzzerSE
        Reloaded::Toast.show(_INTL("{1} couldn't be done.", e.name)) if defined?(Reloaded::Toast)
      end
      return :close if r == :close
      return r if r.is_a?(Symbol) && Reloaded::BattleMenu::COMMANDS[r]
      @list = nil
      @index = [[@index, list.length - 1].min, 0].max
      refresh unless @viewport.nil? || @viewport.disposed?
      return nil
    end

    # The Battle Menu button again: the Favorite (none: the panel closes)
    def favorite
      e = @bm.entry(@bm.favorite_key)
      unless e && @bm.shown?(e, @ctx)
        pbPlayCancelSE
        return :close
      end
      pbPlayDecisionSE
      return after_run(e, @bm.run(e, @ctx))
    end

    # Y: the entry's options (KR's standard menu)
    def options
      e = current
      return nil unless e
      pbPlayDecisionSE
      fav = @bm.favorite?(e)
      labels = [fav ? _INTL("Remove Favorite") : _INTL("Set as Favorite"), _INTL("Move"), _INTL("Cancel")]
      descs = [fav ? _INTL("The Battle Menu button won't use it any more.") : _INTL("The Battle Menu button uses it, here in the Battle Menu."),
               _INTL("Carry it up or down this page."),
               _INTL("Back to the Battle Menu.")]
      case DL.menu(self, _INTL(e.name), labels, descs)
      when 0
        @bm.favorite = fav ? nil : e.key
      when 1
        @moving = true if list.length > 1
      end
      refresh
      return nil
    end

    # Carrying an entry: Up and Down move it, A or B puts it down
    def moving_input
      if Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN)
        dir = Input.repeat?(Input::UP) ? -1 : 1
        if @bm.move(page_key, current.key, dir, @ctx)
          @index += dir
          @list = nil
          pbPlayCursorSE
          refresh
        end
      elsif Input.trigger?(Input::USE) || Input.trigger?(Input::BACK) || Reloaded::Pointer.left? || Reloaded::Pointer.right?
        @moving = false
        pbPlayDecisionSE
        refresh
      end
      return nil
    end

    def row_at
      return nil unless @row_hits
      return Reloaded::Pointer.hit(@row_hits)
    end

    def hint_hit
      return nil unless @hint_hits
      i = Reloaded::Pointer.hit(@hint_hits)
      return i ? @hint_acts[i] : nil
    end

    def back; pbPlayCancelSE; return :close; end

    #--------------------------------------------------------------------------
    # Drawing
    #--------------------------------------------------------------------------
    def refresh
      c = palette
      base = @sprite.bitmap
      top = @top_sprite.bitmap
      base.clear
      top.clear
      base.fill_rect(0, 0, W, H, Color.new(0, 0, 0, DIM))
      @index = [[@index, list.length - 1].min, 0].max
      @top = @index if @index < @top
      @top = @index - MAX_ROWS + 1 if @index >= @top + MAX_ROWS
      rows = [[list.length, 1].max, MAX_ROWS].min
      px = (W - PW) / 2
      ph = 40 + rows * RH + 12
      DL.send(:panel, base, c, px, PY, PW, ph)
      DL.send(:title_bar, base, c, px, PY, PW, _INTL("Battle Menu"))
      paint_pages(top, c, px)
      paint_rows(top, c, px)
      paint_description(base, top, c, px, PY + ph + 4)
      place_cursor
    end

    # LB and RB at the title plate's ends, a dot per page under the red line
    def paint_pages(top, c, px)
      return if @pages.length < 2
      style = Reloaded::Prompts.style
      lb = Reloaded::Prompts.input(:L)
      rb = Reloaded::Prompts.input(:R)
      BI.draw(top, px + 12, PY + 10, lb, c, style) if lb
      BI.draw(top, px + PW - 12 - BI.width(rb, style), PY + 10, rb, c, style) if rb
      n = @pages.length
      n.times { |i| PP.disc(top, W / 2 - 5 * (n - 1) + i * 10, PY + 43, 2, i == @page ? c[:strong] : c[:line]) }
    end

    def paint_rows(top, c, px)
      @row_hits = []
      @cursor_rect = nil
      if list.empty?
        P.text(top, px, PY + 48, PW, RH - 2, _INTL("Nothing Here Right Now"), c[:dim], PF::TEXT, 2)
        return
      end
      list[@top, MAX_ROWS].each_with_index do |e, k|
        i = @top + k
        ry = PY + 48 + k * RH
        @row_hits << [i, px + 8, ry, px + PW - 8, ry + RH - 2]
        @cursor_rect = [px + 8, ry, PW - 16, RH - 2] if i == @index
        locked = @bm.usable(e, @ctx) != true
        fav = @bm.favorite?(e)
        icon(top, e.icon, px + 14, ry + 1, 26, locked)
        nx = px + 46
        if fav
          PP.pixels(top, PP::STAR, nx, ry + 11, locked ? mix(c[:gold], c[:dim], 0.5) : c[:gold])
          nx += 11
        end
        x1 = px + PW - 16
        sw = 0
        if locked
          PP.pixels(top, PP::LOCK, x1 - 10, ry + 10, c[:dim])
          sw = 10
        elsif e.owner != Reloaded::BattleMenu::OWNER
          sw = mod_name(top, c, e, x1, ry, RH - 2)
        elsif (st = @bm.status(e, @ctx))
          sw = P.text(top, x1 - P.width(PF::TEXT, st[0]), ry, P.width(PF::TEXT, st[0]) + 2, RH - 2, st[0], tone(c, st[1]))
        end
        room = x1 - (sw > 0 ? sw + 8 : 0) - nx
        ink = if locked then mix(fav ? c[:gold] : c[:opt], c[:dim], 0.55)
              elsif fav then c[:gold]
              else c[:opt]
              end
        ink = c[:strong] if @moving && i == @index
        P.text(top, nx, ry, room, RH - 2, PF.fit(PF::ROW, _INTL(e.name), room), ink, PF::ROW)
      end
      # more rows than fit: small arrows at the panel's right edge
      P.ui.tri(top, px + PW - 10, PY + 46, :u, c[:dim], 3) if @top > 0
      P.ui.tri(top, px + PW - 10, PY + 48 + MAX_ROWS * RH - 4, :d, c[:dim], 3) if @top + MAX_ROWS < list.length
    end

    # A mod's entry: the mod's name, small and dim, where Main shows statuses
    def mod_name(top, c, e, x1, y, h)
      name = @bm.mod_name(e).upcase
      name = PF.fit(PF::TINY, name, 120)
      w = P.width(PF::TINY, name)
      P.text(top, x1 - w, y + 1, w + 2, h, name, c[:dim], PF::TINY)
      return w
    end

    # The highlighted entry explained (locked: why, in red), the hints under it
    def paint_description(base, top, c, px, dy)
      e = current
      locked = e && (why = @bm.usable(e, @ctx)) != true
      edge = locked ? mix(c[:line], c[:red], 0.5) : mix(c[:line], c[:acc], 0.35)
      PP.chamfer_grad(base, px, dy, px + PW, dy + DESC_H, 10, c[:panel2], mix(c[:panel2], c[:dark], 0.3), edge)
      lines = []
      if @moving
        lines = [[_INTL("Up and Down carry it. A puts it down."), c[:txt]]]
      elsif locked
        # why, in red; its words under it when they fit one line
        reason = P.small_wrap(top, _INTL("Locked: {1}", why), PW - 24)
        reason.first(2).each { |ln| lines << [ln, c[:red]] }
        words = reason.length == 1 ? P.small_wrap(top, _INTL(e.description), PW - 24) : []
        lines << [words[0], c[:dim]] if words.length == 1
      elsif e
        P.small_wrap(top, _INTL(e.description), PW - 24).first(2).each { |ln| lines << [ln, c[:txt]] }
      end
      lines.first(2).each_with_index { |(ln, col), i| P.small(top, px + 12, dy + 6 + i * 17, PW - 24, 17, ln, col) }
      top.fill_rect(px + 10, dy + 42, PW - 20, 1, c[:line])
      paint_box_hints(top, c, dy + 43)
    end

    def paint_box_hints(top, c, y)
      pairs = []
      acts = []
      if @moving
        pairs << [:ud, _INTL("Move")]; acts << nil
        pairs << [button(:C), _INTL("Done")]; acts << nil
      else
        pairs << [button(:C), _INTL("Use")]; acts << :use
        fav = @bm.entry(@bm.favorite_key)
        if fav && @bm.shown?(fav, @ctx)
          pairs << [menu_button, _INTL("Favorite")]; acts << :favorite
        end
        pairs << [button(:X), _INTL("Options")]; acts << :options
        pairs << [button(:B), _INTL("Back")]; acts << :back
      end
      style = Reloaded::Prompts.style
      font = nil
      w = P.hints_width(top, pairs, style)
      if w > PW - 16                # keyboard keys are wider: the labels in the tiny pixel font
        font = PF::TINY
        w = P.hints_width(top, pairs, style, font)
      end
      spans = []
      x0 = W / 2 - w / 2
      P.draw_hints(top, x0, y, c, pairs, style, nil, spans, font)
      @hint_hits = spans.map { |i, a, b| [i, a, y, b, y + P::HINT_H] }
      @hint_acts = acts
    end

    # The Battle Menu's own button for its hint
    def menu_button
      if Reloaded::Prompts.controls?
        side = Reloaded::Prompts.controller? ? :pad : :keys
        token = Reloaded::Controls.bindings(:battle_menu, side).first
        return Reloaded::Controls.shown_input(token) if token
      end
      return button(:A)
    end

    def hint_pairs
      return []
    end

    def tone(c, key)
      return c[key] || c[:txt] if key.is_a?(Symbol)
      return key.is_a?(Array) ? PP.ink(c, key) : c[:txt]
    end

    def mix(a, b, t)
      return Reloaded::Palette.mix(a, b, t)
    end

    # An item's picture, or a picture's path, fitted to size (greyed: locked)
    def icon(b, id, x, y, size, faded = false)
      return unless id
      path = id.is_a?(Symbol) ? (GameData::Item.icon_filename(id) rescue nil) : id.to_s
      return unless path
      bm = @pictures.key?(path) ? @pictures[path] : (@pictures[path] = (Bitmap.new(pbResolveBitmap(path) || path) rescue nil))
      return unless bm
      b.stretch_blt(Rect.new(x, y, size, size), bm, Rect.new(0, 0, bm.width, bm.height), faded ? 110 : 255)
    end
  end
end
