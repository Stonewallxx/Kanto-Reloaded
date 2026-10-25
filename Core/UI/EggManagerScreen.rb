# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Egg Manager's screen
#==============================================================================
# His picks (Roadmap Designs topic egg-manager, 2026-10-23 and 2026-10-25),
# in the TM Vault's frame:
#
#   header     Sort on L (Steps, Place), Hatch Ready on R (each Ready Egg in
#              the boxes hatches in turn; faded when there's none)
#   Eggs       the list in sections, Ready / Party / PC / Gift: "Egg" in its
#              state's colour, where it is, its steps (READY when done), a
#              small blue pod with its incubator's number, the Egg at the
#              end; the details plate lit in the state's colour: the Egg,
#              its state, where; Steps Left, the bar and PIF's own words;
#              "Incubators - Auto" (Auto green On, red Off) and the row of
#              incubators (the earned ones, the next locked with its
#              Badges); the Hatch Speed Helper. A Ready Egg with Inspect
#              Eggs On shows Inside (species, nature, ability, IVs in
#              Compare's colours, a 31 in gold) and Egg Moves in place of
#              the steps and the Hatch Speed.
#   Options    the chosen Egg's actions (Hatch, to the party, an incubator,
#              to the Egg Box), the Egg Box, Auto-Incubate
#   Egg Box    the Box List (his pick): Any Box, then each box with its
#              Eggs and free places, the Egg Box's gold pill
#   Day Care   UI/EggDayCareTab.rb
#
# Buttons: Up / Down choose, Action (Square) the next tab, X (Triangle) an
# incubator in or out (a party Egg: to the Egg Box), Confirm Options, L
# Sort, R Hatch Ready, Back closes. The mouse: a row picks it, the tabs and
# the header's plates are buttons, the wheel scrolls.
#==============================================================================

return unless defined?(Reloaded::Frame) && defined?(::KIF::PixelFont) && defined?(Reloaded::PartyPaint)

module Reloaded
  class EggManagerScreen
    include Reloaded::Frame

    PF = ::KIF::PixelFont
    PP = Reloaded::PartyPaint
    EM = Reloaded::EggManager
    EG = Reloaded::EggManager::Eggs
    INC = Reloaded::EggManager::Incubators
    TABS = [:eggs, :day_care].freeze
    LIST_X = 10
    LIST_W = 216
    ROW_H = 25
    HEAD_H = 16
    TABS_W = 228
    PX0 = 244
    PY0 = 36
    PX1 = W - 6
    LIST_Y0 = 64
    SORT_BOX = [6, 4, 132, 26].freeze
    READY_BOX = [W - 132, 4, W - 6, 26].freeze
    POD = 34
    POD_GAP = 6
    STATE_WORDS = { :ready => ["READY", :gold], :hatching => ["HATCHING", :green], :incubating => ["INCUBATING", :blue],
                    :paused => ["PAUSED", :dim] }.freeze
    SECTION_NAMES = { :ready => "Ready", :party => "Party", :pc => "PC", :gift => "Gift" }.freeze
    IV_KEYS = [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED].freeze
    IV_SHORT = ["HP", "ATK", "DEF", "SPA", "SPD", "SPE"].freeze

    def self.open(tab = :eggs)
      screen = new(tab)
      defined?(pbFadeOutIn) ? pbFadeOutIn { screen.main } : screen.main
      return screen
    end

    attr_reader :sel

    def initialize(tab = :eggs)
      frame_init
      @tab = TABS.index(tab) || 0
      @sel = 0
      @scroll = 0
      @mode = :list            # the Day Care tab: :list, :finder or :deposit
      @dc_button = 0           # the waiting Egg's Collect (0) or Discard (1)
      @icons = {}
      @arts = {}
      @pictures = {}
      @items = nil
    end

    def main
      EM.screen_open = true
      Reloaded::Toast.dispose if defined?(Reloaded::Toast)   # it only fades on the map: not frozen over this
      open_sprites
      refresh
      loop do
        Graphics.update
        Input.update
        update_frame
        @icons.each_value { |s| s.update if s.respond_to?(:update) && !s.disposed? && s.visible }
        break if handle_input == :close
      end
      return nil
    ensure
      EM.screen_open = false
      dispose_icons
      dispose_sprites
      @pictures.each_value { |b| b.dispose if b && !b.disposed? }
      @pictures = {}
    end

    def refresh
      draw if @sprite && !@sprite.disposed?
    end

    def tab
      return TABS[@tab]
    end

    # What the list shows: [[:head, label, tone] or [:row, data], ...]
    def items
      @items ||= tab == :eggs ? egg_items : day_care_items
    end

    # The rows the cursor goes to (each item's index)
    def selectable
      return items.each_index.select { |i| items[i][0] == :row }
    end

    def current
      i = selectable[@sel]
      return i ? items[i][1] : nil
    end

    private

    def changed!
      @items = nil
      @ready_boxed = nil
      @partner_count = nil
      @helper_pc_done = false
      n = selectable.length
      @sel = [[@sel, n - 1].min, 0].max
      refresh
    end

    def mix(a, b, t)
      return Reloaded::Palette.mix(a, b, t)
    end

    def egg_items
      out = []
      EG.sections.each do |section, list|
        out << [:head, _INTL(SECTION_NAMES[section]), nil]
        list.each { |e| out << [:row, [section, e]] }
      end
      return out
    end

    #--------------------------------------------------------------------------
    # Input
    #--------------------------------------------------------------------------
    def handle_input
      return cycle_sort if Input.trigger?(Input::JUMPUP) || clicked?(*SORT_BOX)
      return hatch_ready if Input.trigger?(Input::JUMPDOWN) || clicked?(*READY_BOX)
      handled, result = mouse_input
      return result if handled
      if Input.trigger?(Input::BACK)
        return hint_back
      elsif Input.trigger?(Input::ACTION) && @mode == :list
        next_tab
      elsif tab == :day_care
        day_care_input
      else
        eggs_input
      end
      return nil
    end

    def move_cursor
      n = selectable.length
      return false unless Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)
      return true if n == 0
      dir = Input.repeat?(Input::DOWN) ? 1 : -1
      target = @sel + dir
      if target < 0 || target >= n
        return true unless fresh?(dir)
        target = dir < 0 ? n - 1 : 0
      end
      @sel = target
      @dc_button = 0
      pbPlayCursorSE
      refresh
      return true
    end

    def eggs_input
      return if move_cursor
      if Input.trigger?(Input::USE)
        options
      elsif Input.trigger?(Input::X)
        quick_action
      end
    end

    def mouse_input
      pt = Reloaded::Pointer
      if pointer_hover && (k = pt.hit(@row_hits || [])) && k != @sel
        @sel = k
        @dc_button = 0
        refresh
      end
      return [true, hint_back] if pt.right?
      dir = pt.wheel
      if dir != 0
        n = selectable.length
        if n > 0
          @sel = (@sel + dir).clamp(0, n - 1)
          refresh
        end
        return [true, nil]
      end
      return [false, nil] unless pt.left?
      handled, result = hint_click
      return [true, result] if handled
      if (i = pt.hit(@tab_hits || []))
        set_tab(i) if @mode == :list
      elsif (b = pt.hit(@button_hits || []))
        plate_button(b)
      elsif (k = pt.hit(@row_hits || []))
        @sel = k
        tab == :eggs ? options : day_care_select
      end
      return [true, nil]
    end

    def next_tab
      set_tab((@tab + 1) % TABS.length)
    end

    def set_tab(i)
      return if i == @tab
      @tab = i
      @sel = 0
      @scroll = 0
      @mode = :list
      pbPlayCursorSE
      changed!
    end

    def cycle_sort
      return pbPlayBuzzerSE unless tab == :eggs
      EM.sort = EM.sort + 1
      pbPlayCursorSE
      e = current
      @items = nil
      @sel = e ? (selectable.index { |i| items[i][1][1].pkmn.equal?(e[1].pkmn) } || 0) : 0
      refresh
      return nil
    end

    # Ready Eggs in the boxes (kept until something changes: the header asks
    # on every redraw)
    def ready_boxed
      return @ready_boxed ||= EG.all.reject(&:party?).select { |e| e.pkmn.steps_to_hatch.to_i <= 1 }
    end

    def hatch_ready
      return pbPlayBuzzerSE if ready_boxed.empty?
      pbPlayDecisionSE
      hidden { INC.hatch_all }
      INC.check!
      changed!
      return nil
    end

    def hint_back
      if @mode != :list
        pbPlayCancelSE
        @mode = :list
        @sel = @mode_sel || 0
        changed!
        return nil
      end
      pbPlayCloseMenuSE
      return :close
    end

    def hint_tabs
      next_tab
      return nil
    end

    def hint_options
      tab == :eggs ? options : day_care_select
      return nil
    end

    def hint_quick
      quick_action
      return nil
    end

    #--------------------------------------------------------------------------
    # The chosen Egg's actions
    #--------------------------------------------------------------------------
    # X (Triangle): a boxed Egg into an incubator or out; a party Egg to the
    # Egg Box
    def quick_action
      cur = current
      return pbPlayBuzzerSE unless cur && tab == :eggs
      entry = cur[1]
      if entry.party?
        to_egg_box(entry)
      elsif INC.number(entry.pkmn)
        INC.release(entry.pkmn)
        pbPlayCancelSE
        changed!
      elsif INC.incubate(entry.pkmn)
        pbPlayDecisionSE
        changed!
      else
        Reloaded::Dialogs.notice(self, _INTL("Incubators"), _INTL("Every incubator is in use."))
      end
    end

    def quick_word(entry)
      return _INTL("To Egg Box") if entry.party?
      return INC.number(entry.pkmn) ? _INTL("Take Out") : _INTL("Incubate")
    end

    def options
      cur = current
      entry = cur ? cur[1] : nil
      acts = []
      if entry
        p = entry.pkmn
        if !entry.party? && p.steps_to_hatch.to_i <= 1
          acts << [:hatch, _INTL("Hatch"), _INTL("It hatches here, and stays in its box.")]
        end
        if entry.party?
          acts << [:to_box, _INTL("Move to Egg Box"), _INTL("To {1}.", egg_box_words)]
        else
          acts << [:to_party, _INTL("Move to Party"), _INTL("It hatches as you walk, and its incubator is free again.")]
          if INC.number(p)
            acts << [:take_out, _INTL("Take Out of Incubator"), _INTL("It stops counting down until it's in one again.")]
          else
            acts << [:incubate, _INTL("Incubate"), _INTL("It counts down in its box as you walk.")]
          end
          eb = EM.egg_box
          acts << [:to_box, _INTL("Move to Egg Box"), _INTL("To {1}.", egg_box_words)] if eb && entry.box != eb
        end
      end
      acts << [:egg_box, _INTL("Egg Box: {1}", egg_box_words), _INTL("Where Eggs sent to the PC go first.")]
      auto = EM.auto_incubate?
      acts << [:auto, _INTL("Auto-Incubate: {1}", auto ? _INTL("On") : _INTL("Off")),
               _INTL("An Egg the Day Care sends to the PC goes into a free incubator.")]
      i = Reloaded::Dialogs.menu(self, entry ? _INTL("Egg") : _INTL("Options"), acts.map { |a| a[1] }, acts.map { |a| a[2] })
      refresh
      return if i.nil?
      case acts[i][0]
      when :hatch
        hidden { INC.hatch(entry.pkmn) }
        INC.check!
        changed!
      when :to_party
        r = EG.to_party(entry)
        r == true ? changed! : Reloaded::Dialogs.notice(self, _INTL("Egg"), r)
      when :to_box then to_egg_box(entry)
      when :incubate
        INC.incubate(entry.pkmn) ? changed! : Reloaded::Dialogs.notice(self, _INTL("Incubators"), _INTL("Every incubator is in use."))
      when :take_out
        INC.release(entry.pkmn)
        changed!
      when :egg_box then choose_egg_box
      when :auto
        Reloaded::Settings.set(EM.key(:auto_incubate), !auto)
        refresh
      end
    end

    def egg_box_words
      b = EM.egg_box
      return b ? EG.box_name(b) : _INTL("Any Box")
    end

    def to_egg_box(entry)
      if entry.party?
        spot = EG.to_box(entry)
        return Reloaded::Dialogs.notice(self, _INTL("Egg"), _INTL("Every box is full.")) unless spot
      else
        b = EM.egg_box
        k = b ? EG.free_slot(b) : nil
        return Reloaded::Dialogs.notice(self, _INTL("Egg"), _INTL("{1} is full.", EG.box_name(b))) unless k
        $PokemonStorage[entry.box, entry.slot] = nil
        $PokemonStorage[b, k] = entry.pkmn
      end
      pbPlayDecisionSE
      changed!
    end

    #--------------------------------------------------------------------------
    # The Egg Box (his pick: Box List)
    #--------------------------------------------------------------------------
    BOX_ROWS = 9
    BOX_W = 300

    def choose_egg_box
      boxes = [nil]
      EG.each_box { |i, _b| boxes << i }
      eggs = Hash.new(0)
      EG.all.each { |e| eggs[e.box] += 1 unless e.party? }
      sel = boxes.index(EM.egg_box) || 0
      top = 0
      redraw = true
      loop do
        top = sel if sel < top
        top = sel - BOX_ROWS + 1 if sel >= top + BOX_ROWS
        if redraw
          draw_box_list(boxes, eggs, sel, top)
          redraw = false
        end
        Graphics.update
        Input.update
        update_frame
        pt = Reloaded::Pointer
        hit = pt.hit(@box_hits || [])
        if pt.moved? && hit && hit != sel
          sel = hit
          redraw = true
        end
        if pt.left? && hit
          sel = hit
          break
        elsif pt.right? || Input.trigger?(Input::BACK)
          sel = nil
          break
        elsif pt.wheel != 0
          sel = (sel + pt.wheel).clamp(0, boxes.length - 1)
          redraw = true
        elsif Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)
          sel = (sel + (Input.repeat?(Input::DOWN) ? 1 : -1)) % boxes.length
          pbPlayCursorSE
          redraw = true
        elsif Input.trigger?(Input::USE)
          break
        end
      end
      if sel.nil?
        pbPlayCancelSE
      else
        pbPlayDecisionSE
        EM.egg_box = boxes[sel]
      end
    ensure
      overlay.clear
      @box_hits = nil
      refresh
    end

    def draw_box_list(boxes, eggs, sel, top)
      o = overlay
      c = palette
      o.clear
      Reloaded::Dialogs.send(:dim, o)
      rh = 24
      n = [boxes.length, BOX_ROWS].min
      h = 42 + n * rh + 8
      x = (W - BOX_W) / 2
      y = [(H - P::HINT_H - h) / 2, 4].max
      Reloaded::Dialogs.send(:panel, o, c, x, y, BOX_W, h)
      Reloaded::Dialogs.send(:title_bar, o, c, x, y, BOX_W, _INTL("Egg Box"))
      @box_hits = []
      boxes[top, n].each_with_index do |b, k|
        i = top + k
        ry = y + 40 + k * rh
        Reloaded::Dialogs.send(:cursor_row, o, c, x + 6, ry, x + BOX_W - 6, ry + rh - 1) if i == sel
        @box_hits << [i, x + 6, ry, x + BOX_W - 6, ry + rh - 1]
        if b.nil?
          P.text(o, x + 16, ry + 3, 120, 18, _INTL("Any Box"), c[:txt], PF::TEXT)
          P.small(o, x + 16, ry + 4, BOX_W - 32, 16, _INTL("Current Box First"), c[:dim], 1)
          next
        end
        name = PF.fit(PF::TEXT, EG.box_name(b), 110)
        nw = P.text(o, x + 16, ry + 3, 120, 18, name, c[:txt], PF::TEXT)
        pill(o, c, x + 16 + nw + 8, ry + 5, _INTL("EGG BOX"), :gold) if b == EM.egg_box
        egg_count(o, c, x + 170, ry + 4, eggs[b])
        free = EG.free_places(b)
        P.small(o, x + 16, ry + 4, BOX_W - 32, 16, free > 0 ? _INTL("{1} Free", free) : _INTL("Full"), free > 0 ? c[:green] : c[:red], 1)
      end
      if boxes.length > BOX_ROWS
        P.ui.tri(o, x + BOX_W / 2 - 4, y + 34, :u, c[:dim], 3) if top > 0
        P.ui.tri(o, x + BOX_W / 2 - 4, y + h - 6, :d, c[:dim], 3) if top + BOX_ROWS < boxes.length
      end
      P.hints(o, o, c, [[:ud, _INTL("Choose")], [button(:C), _INTL("Select")], [button(:B), _INTL("Back")]], Reloaded::Prompts.style)
    end

    # A little Egg and how many (gold): its width
    def egg_count(o, c, x, y, n)
      return 0 if n.to_i <= 0
      egg_picture(o, x + 5, y + 8, 12)
      return 10 + P.small(o, x + 12, y, 30, 16, n.to_s, c[:gold])
    end

    #--------------------------------------------------------------------------
    # Drawing
    #--------------------------------------------------------------------------
    def draw
      c = palette
      base = @sprite.bitmap
      top = @top_sprite.bitmap
      base.clear
      top.clear
      @cursor_rect = nil
      @row_hits = []
      @button_hits = []
      @shown_icons = {}
      PP.paint_background(base, c)
      draw_header(base, top, c)
      draw_tabs(base, top, c)
      draw_list(base, top, c)
      tab == :eggs ? draw_egg_plate(base, top, c) : draw_day_care_plate(base, top, c)
      @icons.each { |k, s| s.visible = @shown_icons[k] ? true : false unless s.disposed? }
      paint_hints(base, c)
      place_cursor
    end

    def draw_header(base, top, c)
      PP.paint_title(top, c, _INTL("Egg Manager"))
      style = Reloaded::Prompts.style
      x0, y0, x1, y1 = SORT_BOX
      off = tab != :eggs
      lit = @hover_box == :left && !off
      PP.chamfer_grad(base, x0, y0, x1, y1, 6, mix(c[:panel2], c[:selb], lit ? 0.4 : 0.15), c[:panel2], lit ? c[:selb] : c[:line])
      P.text(top, x0, y0 + 1, x1 - x0, 20, _INTL("Sort: {1}", _INTL(EM::SORTS[EM.sort])), off ? mix(c[:dim], c[:panel2], 0.35) : c[:txt], PF::TEXT, 2)
      Reloaded::ButtonIcons.draw(top, x1 + 4, 6, left_key, c, style, 18)
      x0, y0, x1, y1 = READY_BOX
      none = ready_boxed.empty?
      lit = @hover_box == :right && !none
      PP.chamfer_grad(base, x0, y0, x1, y1, 6, mix(c[:panel2], c[:selb], lit ? 0.4 : 0.15), c[:panel2], lit ? c[:selb] : c[:line])
      P.text(top, x0, y0 + 1, x1 - x0, 20, _INTL("Hatch Ready"), none ? mix(c[:dim], c[:panel2], 0.35) : c[:txt], PF::TEXT, 2)
      key = right_key
      Reloaded::ButtonIcons.draw(top, x0 - 4 - Reloaded::ButtonIcons.width(key, style, 18), 6, key, c, style, 18)
    end

    def left_box
      return SORT_BOX
    end

    def right_box
      return READY_BOX
    end

    # The tabs (the TM Vault's), a gold dot after one that has news
    def draw_tabs(base, top, c)
      labels = [_INTL("EGGS"), _INTL("DAY CARE")]
      news = [INC.ready_count > 0 || EG.party.any? { |p| p.egg? && p.steps_to_hatch.to_i < EM::SOON },
              EM::DayCare.egg_waiting?]
      tw = (TABS_W - 4) / 2
      @tab_hits = []
      labels.each_with_index do |l, i|
        tx = 8 + i * (tw + 4)
        on = i == @tab
        PP.chamfer_grad(base, tx, 36, tx + tw, 56, 6, on ? mix(c[:panel2], c[:selb], 0.55) : c[:panel2],
                        on ? mix(c[:panel2], c[:selb], 0.3) : mix(c[:panel2], c[:dark], 0.4), on ? c[:selb] : c[:line])
        lw = P.text(top, tx, 39, tw, 14, l, on ? c[:strong] : c[:dim], PF::TINY, 2)
        PP.disc(top, tx + (tw + lw) / 2 + 6, 46, 2, c[:gold]) if news[i]
        @tab_hits << [i, tx, 36, tx + tw, 56]
      end
    end

    # The list: headings and rows, scrolled so the chosen row shows
    def draw_list(base, top, c)
      y1 = H - P::HINT_H - 6
      PP.chamfer_grad(base, 6, 60, 238, y1, 10, c[:panel2], mix(c[:panel2], c[:dark], 0.3), c[:line])
      list = items
      if selectable.empty?
        empty_list(top, c)
        return
      end
      ys = []
      y = 0
      list.each_with_index do |it, k|
        ys << y
        y += it[0] == :head ? HEAD_H : ROW_H
        y += 4 if it[0] == :row && list[k + 1] && list[k + 1][0] == :head
      end
      total = y
      room = y1 - 4 - LIST_Y0
      at = selectable[@sel]
      sy = ys[at]
      # the heading just above the chosen row shows with it
      sy = ys[at - 1] if at > 0 && list[at - 1][0] == :head
      @scroll = sy if sy < @scroll
      @scroll = ys[at] + ROW_H - room if ys[at] + ROW_H > @scroll + room
      @scroll = [[@scroll, total - room].min, 0].max
      list.each_with_index do |it, k|
        ry = LIST_Y0 + ys[k] - @scroll
        h = it[0] == :head ? HEAD_H : ROW_H
        next if ry < LIST_Y0 - 1 || ry + h > y1 - 2
        if it[0] == :head
          draw_head(top, c, ry + 2, it)
          next
        end
        i = selectable.index(k)
        @cursor_rect = [LIST_X - 3, ry, LIST_W + 6, ROW_H - 1] if i == @sel
        @row_hits << [i, LIST_X, ry, LIST_X + LIST_W, ry + ROW_H - 1]
        tab == :eggs ? egg_row(top, c, LIST_X, ry, it[1]) : day_care_row(top, c, LIST_X, ry, it[1])
      end
      if total > room
        track = room - 2
        bar = [track * room / total, 10].max
        pos = (track - bar) * @scroll / [total - room, 1].max
        base.fill_rect(LIST_X + LIST_W + 6, LIST_Y0, 2, track, c[:line])
        base.fill_rect(LIST_X + LIST_W + 6, LIST_Y0 + pos, 2, bar, c[:dim])
      end
    end

    # A heading in small capitals with a line after it; [:head, label,
    # [prefix, colour key]] puts a coloured word first ("70%")
    def draw_head(top, c, y, it)
      x = LIST_X + 2
      if it[2]
        x += P.text(top, x, y, 60, 13, it[2][0], c[it[2][1]] || c[:head], PF::TINY) + 6
        P.heading(top, x, LIST_X + LIST_W - 2, y, it[1], c[:dim], c[:line])
      else
        P.heading(top, x, LIST_X + LIST_W - 2, y, it[1], c[:head], c[:line])
      end
    end

    def empty_list(top, c)
      msg = if tab == :eggs then _INTL("No Eggs yet. Eggs in your party and the PC show here.")
            elsif !EM::DayCare.visited? then _INTL("Leave a Pokémon at the Day Care once, and you can use it from here.")
            else _INTL("No Pokémon here.")
            end
      P.small_wrap(top, msg, LIST_W - 8).first(4).each_with_index { |ln, i| P.small(top, LIST_X + 4, LIST_Y0 + 4 + i * 16, LIST_W - 8, 16, ln, c[:dim]) }
    end

    def tone(c, st)
      return c[STATE_WORDS[st][1]] || c[:dim]
    end

    def ink(c, st)
      return st == :paused ? c[:txt] : tone(c, st)
    end

    def pill(b, c, x, y, label, tone_key, right = false)
      t = c[tone_key] || c[:dim]
      fill = c[:light] ? mix(c[:panel2], t, 0.22) : mix(c[:panel2], t, 0.28)
      return P.pill(b, x, y, label, fill, t, right)
    end

    # An Egg's row: "Egg" in its state's colour (gold in Ready), where it is,
    # its steps (READY when done), its incubator's number, the Egg
    def egg_row(top, c, x, y, data)
      section, e = data
      st = EG.state(e)
      col = section == :ready ? c[:gold] : ink(c, st)
      where = if e.party? then section == :party ? _INTL("Slot {1}", e.slot + 1) : _INTL("Party")
              else PF.fit(PF::TINY, EG.box_name(e.box), 70)
              end
      nw = P.text(top, x + 4, y + 3, 40, 20, _INTL("Egg"), col, PF::TEXT)
      P.small(top, x + 4 + nw + 8, y + 4, 90, 16, where, c[:dim])
      show_icon(:"row#{e.pkmn.object_id}", e.pkmn, x + LIST_W - 12, y + 11, 20)
      if !e.party? && e.pkmn.steps_to_hatch.to_i <= 1
        pill(top, c, x + LIST_W - 28, y + 5, _INTL("READY"), :gold, true)
        return
      end
      sw = P.text(top, x + LIST_W - 92, y + 5, 64, 16, fmt(e.pkmn.steps_to_hatch), section == :ready ? c[:gold] : c[:dim], PF::TINY, 1)
      n = INC.number(e.pkmn)
      return unless n
      bx = x + LIST_W - 28 - sw - 20
      blue = c[:blue]
      P.ui.rbox(top, bx, y + 5, bx + 14, y + 19, 3, c[:light] ? mix(c[:panel2], blue, 0.22) : mix(c[:panel2], blue, 0.28), blue)
      P.text(top, bx, y + 6, 14, 14, n.to_s, blue, PF::TINY, 2)
    end

    def fmt(n)
      return n.to_i.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
    end

    # The details plate (the TM Vault's: lit in a colour, two bands, the red line)
    def plate(base, c, col, line_y)
      x0 = PX0; y0 = PY0; x1 = PX1; y1 = H - P::HINT_H - 6
      cut = 16
      topc = mix(c[:panel], col, 0.4)
      bottom = mix(c[:panel], c[:dark], 0.4)
      PP.chamfer_grad(base, x0, y0, x1, y1, cut, topc, bottom, mix(c[:line], col, 0.5))
      from = x1 - 48
      to = x0 + 24
      (y0 + 1...y1 - 1).each do |y|
        t = (y - y0).to_f / (y1 - y0)
        left = x0 + 1 + [cut - (y - y0), 0].max
        right = x1 - 1 - [cut - (y1 - 1 - y), 0].max
        mid = from + (to - from) * t
        k = y < line_y ? 0.4 : 0.22 - 0.18 * (y - line_y).to_f / (y1 - line_y)
        tint = mix(mix(topc, bottom, t), col, k)
        [[0, 56], [40, 8]].each do |off, bw|
          a = [(mid + off - bw / 2.0).round, left].max
          b = [(mid + off + bw / 2.0).round, right].min
          base.fill_rect(a, y, b - a, 1, tint) if b > a
        end
      end
      base.fill_rect(x0 + 8, line_y, x1 - x0 - 16, 2, PP::POKE_RED)
    end

    def draw_egg_plate(base, top, c)
      cur = current
      unless cur
        plate(base, c, c[:line], PY0 + 80)
        draw_incubators(base, top, c, PX0 + 14, PY0 + 168, PX1 - PX0 - 28, nil)
        return
      end
      e = cur[1]
      st = EG.state(e)
      col = tone(c, st)
      plate(base, c, col, PY0 + 80)
      x = PX0 + 14
      w = PX1 - PX0 - 28
      show_icon(:big, e.pkmn, PX0 + 42, PY0 + 40, 48)
      P.text(top, PX0 + 80, PY0 + 8, 150, 22, _INTL("Egg"), c[:strong], PF::ROW)
      words, key = STATE_WORDS[st]
      pill(top, c, PX0 + 80, PY0 + 36, _INTL(words), key)
      where = e.party? ? _INTL("Party, Slot {1}", e.slot + 1) : _INTL("{1}, Slot {2}", EG.box_name(e.box), e.slot + 1)
      P.small(top, PX0 + 80, PY0 + 54, PX1 - PX0 - 94, 16, where, c[:dim])
      if st == :ready && EM.inspect_eggs?
        draw_inside(top, c, x, PY0 + 88, w, e.pkmn)
        draw_incubators(base, top, c, x, PY0 + 226, w, e.pkmn)
        return
      end
      y = PY0 + 90
      p = e.pkmn
      P.text(top, x, y, 110, 20, _INTL("Steps Left"), c[:dim], PF::TEXT)
      P.text(top, x, y, w, 20, _INTL("{1} of {2}", fmt(p.steps_to_hatch), fmt(EG.total(p))), c[:txt], PF::TEXT, 1)
      PP.bar(top, c, x + 2, y + 28, w - 46, EG.progress(p), col, 5)
      P.small(top, x, y + 22, w, 16, "#{(EG.progress(p) * 100).floor}%", c[:txt], 1)
      P.small_wrap(top, EG.stage_words(p), w).first(2).each_with_index { |ln, k| P.small(top, x, y + 40 + k * 16, w, 16, ln, c[:dim]) }
      draw_incubators(base, top, c, x, PY0 + 168, w, p)
      draw_helper(top, c, x, PY0 + 236, w) if helper_shown?
    end

    def helper_shown?
      return false unless EM.setting(:helper)
      return !(defined?(Reloaded::QualityOfLife) && Reloaded::QualityOfLife.on?(:instant_hatch))
    end

    # "Incubators - Auto" (Auto green On, red Off), then the row: the earned
    # ones (the Egg in each, its bar; the shown Egg's on a lit plate), the
    # next to earn locked with its Badges
    def draw_incubators(base, top, c, x, y, w, shown)
      label = _INTL("INCUBATORS - ")
      lw = P.text(top, x, y, 200, 13, label, c[:head], PF::TINY)
      auto = EM.auto_incubate?
      aw = P.text(top, x + lw, y, 60, 13, _INTL("AUTO"), auto ? c[:green] : c[:red], PF::TINY)
      top.fill_rect(x + lw + aw + 6, y + 6, w - (lw + aw + 6), 1, c[:line]) if w > lw + aw + 6
      py = y + 17
      n = INC.count
      ring = shown ? INC.number(shown) : nil
      n.times do |k|
        px = x + k * (POD + POD_GAP)
        egg = INC.slots[k + 1]
        if egg
          st = EG.state(EM::Entry.new(egg, 0, 0))
          col = tone(c, st)
          if ring == k + 1
            fill, border = Reloaded::Palette.cursor(nil, c)
            P.ui.rbox(base, px - 3, py - 3, px + POD + 3, py + POD + 3, 7, Reloaded::Palette.over(c[:panel2], fill), Reloaded::Palette.over(c[:panel2], border))
          end
          PP.chamfer_grad(base, px, py, px + POD, py + POD, 6, mix(c[:panel2], col, 0.35), mix(c[:panel2], c[:dark], 0.4), mix(c[:line], col, 0.6))
          show_icon(:"pod#{k}", egg, px + POD / 2, py + POD / 2 - 3, 20)
          PP.bar(top, c, px + 6, py + POD - 7, POD - 12, EG.progress(egg), col, 2)
        else
          sunk = mix(c[:panel2], c[:dark], 0.5)
          PP.chamfer_grad(base, px, py, px + POD, py + POD, 6, sunk, mix(c[:panel2], c[:dark], 0.65), sunk)
          P.text(top, px, py + POD / 2 - 6, POD, 12, "+", c[:dim], PF::TINY, 2)
        end
      end
      need = INC.next_badges
      return unless need && n < INC::MAX
      px = x + n * (POD + POD_GAP)
      sunk = mix(c[:panel2], c[:dark], 0.55)
      PP.chamfer_grad(base, px, py, px + POD, py + POD, 6, sunk, sunk, sunk)
      padlock(top, px + POD / 2 - 4, py + 12, c[:dim])
      tx = px + POD + POD_GAP
      P.small(top, tx, py + 9, w - (tx - x), 16, _INTL("{1} Badges", need), c[:dim])
    end

    # The Hatch Speed Helper: Flame Body or Magma Armor in the party, else
    # the first in the boxes that has it
    def draw_helper(top, c, x, y, w)
      P.heading(top, x, x + w, y, _INTL("Hatch Speed"), c[:head], c[:line])
      y += 18
      party = EG.party.find { |p| EM::Hatching.helper?(p) }
      if party
        show_icon(:helper, party, x + 15, y + 15, 28)
        P.small_wrap(top, _INTL("{1} is in your party: Eggs hatch twice as fast.", party.name), w - 36).first(3).each_with_index do |ln, k|
          P.small(top, x + 36, y - 1 + k * 16, w - 36, 16, ln, c[:green])
        end
        return
      end
      @helper_pc = EM::Hatching.helper_in_pc unless defined?(@helper_pc_done) && @helper_pc_done
      @helper_pc_done = true
      P.small(top, x + 36, y - 1, w - 36, 16, _INTL("No Flame Body in your party."), c[:txt])
      if @helper_pc
        show_icon(:helper, @helper_pc.pkmn, x + 15, y + 15, 28)
        text = _INTL("{1} ({2}) has it: Eggs hatch twice as fast.", @helper_pc.pkmn.name, EG.box_name(@helper_pc.box))
        P.small_wrap(top, text, w - 36).first(2).each_with_index { |ln, k| P.small(top, x + 36, y + 15 + k * 16, w - 36, 16, ln, c[:gold]) }
      else
        P.small(top, x + 36, y + 15, w - 36, 16, _INTL("Flame Body or Magma Armor makes Eggs hatch twice as fast."), c[:dim])
      end
    end

    # Inspect Eggs (his pick: In the Plate, Egg Moves its own heading)
    def draw_inside(top, c, x, y, w, p)
      P.heading(top, x, x + w, y, _INTL("Inside"), c[:head], c[:line])
      show_icon(:inside, p, x + 12, y + 28, 24, true)
      nw = P.text(top, x + 30, y + 18, 120, 20, PF.fit(PF::TEXT, p.speciesName.to_s, 120), c[:txt], PF::TEXT)
      gender(top, c, p, x + 30 + nw + 4, y + 24)
      ball = (::GameData::Item.get(p.poke_ball).name rescue nil)
      P.small(top, x, y + 19, w, 16, ball.to_s, c[:dim], 1) if ball
      nature = (p.nature.name rescue "")
      ability = (p.ability.name rescue "")
      P.small(top, x, y + 40, w, 16, _INTL("{1} Nature", nature), c[:txt])
      P.small(top, x, y + 40, w, 16, ability, c[:txt], 1)
      cw = w / 3
      IV_KEYS.each_with_index do |k, i|
        v = (p.iv[k] rescue 0).to_i
        cx = x + (i % 3) * cw
        cy = y + 60 + (i / 3) * 16
        lw = P.small(top, cx, cy, 30, 16, _INTL(IV_SHORT[i]), iv_tint(c, i))
        P.small(top, cx + lw + 5, cy, 30, 16, v.to_s, v >= 31 ? c[:gold] : c[:txt])
      end
      P.heading(top, x, x + w, y + 96, _INTL("Egg Moves"), c[:head], c[:line])
      moves = Array(p.moves).compact.map { |m| (::GameData::Move.get(m.id).name rescue nil) }.compact
      P.small(top, x, y + 112, w, 16, PF.fit(PF::TINY, moves.join(", "), w), c[:txt])
    end

    # Compare's colours for the stats (his)
    def iv_tint(c, k)
      hue, sat, lift = Reloaded::PCScene::CMP_TINTS[k]
      return PP.hsl_color(hue, sat, (PP::INK_LIGHTNESS[c[:light] ? :light : :dark] + lift).clamp(0.0, 0.9))
    rescue StandardError
      return c[:txt]
    end

    def gender(b, c, p, x, y)
      if p.male? then PP.pixels(b, PP::MALE, x, y, c[:blue]); return 8
      elsif p.female? then PP.pixels(b, PP::FEMALE, x, y, c[:pink]); return 7
      end
      return 0
    rescue StandardError
      return 0
    end

    def hint_pairs
      back = button(:B)
      return day_care_hints if tab == :day_care
      out = [[:ud, _INTL("Choose")], [button(:A), _INTL("Tabs"), :hint_tabs]]
      cur = current
      out << [button(:X), quick_word(cur[1]), :hint_quick] if cur
      out << [button(:C), _INTL("Options"), :hint_options]
      out << [back, _INTL("Close"), :hint_back]
      return out
    end

    #--------------------------------------------------------------------------
    # Pictures (Big Pokémon Icons as the player has them)
    #--------------------------------------------------------------------------
    # One icon sprite per spot (key), the art fitted to a box, its middle on
    # cx, cy; shown this frame. inside: the species an Egg holds (Inspect)
    def show_icon(key, pkmn, cx, cy, box, inside = false)
      s = @icons[key]
      if s && (@icon_owner ||= {})[key] != [pkmn.object_id, inside, pkmn.egg?]
        kill(s)
        s = nil
      end
      unless s
        s = inside ? inside_icon(pkmn) : Reloaded::PartyIcons.icon(pkmn, @viewport, 2)
        return unless s
        @icons[key] = s
        (@icon_owner ||= {})[key] = [pkmn.object_id, inside, pkmn.egg?]
        @arts[key] = s.bitmap ? Reloaded::PartyIcons.art_rect(s.bitmap, [s.src_rect.height, 1].max) : nil
      end
      r = @arts[key]
      return unless r
      s.zoom_x = s.zoom_y = box.to_f / [r.width, r.height, 1].max
      s.ox = r.x + r.width / 2
      s.oy = r.y + r.height / 2
      s.x = cx
      s.y = cy
      @shown_icons[key] = true
    end

    # What an Egg holds, as its species' picture (Inspect Eggs)
    def inside_icon(pkmn)
      bm = Reloaded::PartyIcons.species_bitmap(pkmn.species)
      return nil unless bm
      s = Sprite.new(@viewport)
      s.bitmap = bm
      f = [bm.height, 1].max
      s.src_rect = Rect.new(0, 0, [f, bm.width].min, f)
      s.z = 2
      return s
    end

    def egg_picture(b, cx, cy, size)
      bm = (@pictures[:egg] ||= Reloaded::PartyIcons.egg_bitmap)
      return unless bm
      r = (@egg_rect ||= Reloaded::PartyIcons.art_rect(bm, [bm.height, 1].max))
      k = size.to_f / [r.width, r.height, 1].max
      w = (r.width * k).round
      h = (r.height * k).round
      b.stretch_blt(Rect.new(cx - w / 2, cy - h / 2, w, h), bm, r)
    end

    def dispose_icons
      @icons.each_value { |s| kill(s) }
      @icons = {}
      @arts = {}
      @icon_owner = {}
    end

    # A picture's sprite gone (an Inspect one's own bitmap with it)
    def kill(s)
      return if s.nil? || s.disposed?
      s.bitmap.dispose if s.bitmap && !s.bitmap.disposed? && !(defined?(::PokemonIconSprite) && s.is_a?(::PokemonIconSprite))
      s.dispose
    end

    def sprites
      return super + @icons.values.reject(&:disposed?)
    end
  end
end
