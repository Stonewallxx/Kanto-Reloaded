#==============================================================================
# Kanto Reloaded: the improved KIF Settings
#==============================================================================
# While Reloaded Settings is on, Options opens this screen instead of KIF
# Settings (KIFBridge picks it). It is KIF Settings itself, a subclass of
# KifSettingsScreen (990_KIF/000_Core/016): the same sections, rows, modules,
# mods, sub-pages, search results and defaults, drawn and driven Kanto
# Reloaded's way:
#
#   - Search top left and Presets top right, each with its button beside
#     it: they open with those buttons (Search also with a mouse click)
#   - the Theme's colours (Base keeps KIF Settings' own), Header Color and
#     Settings Color
#   - choices show between two arrows and cycle with Left/Right; A (or a
#     click on the value) opens a dropdown of them (Reloaded::Dropdown, the
#     highlighted choice explained in the description box); settings with
#     their own picker (Theme, the frames, the colours) keep it; sliders
#     and numbers open a number popup
#   - the Kanto Reloaded mod's pulsing cursor (Cursor Color), on sections
#     and settings
#   - a round dot marks a setting changed from its default
#   - the section you're in shows in white
#   - typing as KIF Settings' search does (TextEntry): straight into the
#     field, results as you type; a controller's A opens the naming screen
#   - hints and descriptions in the smaller text the Kanto Reloaded mod used
#   - presets in Kanto Reloaded's popups (Reloaded::Presets), so the Presets
#     section moves to the title bar
#   - hints show the buttons as icons (the controller's own symbols while
#     one is in use) and scroll when they're too long for the screen
#   - settings a mod locked (KIF 0.21.52 Experiences) can't be changed and
#     say which mod set them, as in KIF Settings
#   - a Kanto Reloaded setting another one decides right now (the other
#     Speed-Up Type's rows, PokeVial's Max Uses under Progressive Uses) is
#     dimmed with a padlock, can't be changed, and its description says why
#   - text centred on its capitals, badges with their text centred
#
# KIF Settings' methods read its layout constants where they are written,
# so every method that draws is redone here; its data methods (rows, search,
# defaults, sub-pages, closing) are used as they are. What every settings-like
# screen shares (layers, cursor, hint line, title-bar boxes) is in
# Reloaded::Frame. If this screen fails, KIF Settings opens as it ships.
#==============================================================================

unless defined?(::KifSettingsScreen) && defined?(::KIF::SettingsScreen) && defined?(::KIF::PixelUI)
  Reloaded::Log.info("KIF Settings isn't here; the improved settings screen is off", :settings)
  return
end

module Reloaded
  class SettingsScreen < ::KifSettingsScreen
    include Reloaded::Frame

    W = 512
    H = 384
    SIDE_X1 = 174
    LIST_X0 = 180
    LIST_X1 = W - 6
    LIST_Y0 = 36
    LIST_Y1 = H - 120
    NAME_X  = LIST_X0 + 21     # room for the changed dot inside the cursor
    VAL_X1  = LIST_X1 - 12
    VALUE_MAX  = 150      # longer values are shortened
    SLIDER_W   = 104      # a slider's track; its number centres on the value column
    BUTTON_W   = 112      # Search and Presets
    TILE_TEXT  = Color.new(248, 248, 248)
    # LOCKED and LOCKED BY: the red of the Battles section's tile, in every theme
    LOCK_FILL  = begin
                   s = defined?(::KIF::SettingsScreen::SECTIONS) ? ::KIF::SettingsScreen::SECTIONS.find { |x| x[0] == :battles } : nil
                   Color.new(*(s ? s[2] : [210, 80, 80]))
                 end
    COUNT      = Color.new(112, 216, 112)   # counts beside tab labels
    COUNT_ON   = Color.new(28, 112, 48)     # ...on a highlighted tab
    COUNT_GAP  = 5                          # between a tab's label and its count
    SEARCH_BOX = [8, 4, 8 + 112, 27]        # x0, y0, x1, y1
    P = Reloaded::Pixel

    # What a section holds, for the ones without headings
    SECTION_HELP = {
      :modules => "Switch KIF's modules On, Off or Hidden. Hidden keeps a module working with its settings out of sight.",
      :mods    => "Your Mods: Switch them On or Off, open their settings, browse the KIF-Mods catalog."
    }.freeze

    attr_reader :entry, :picked

    def initialize(inloadscreen = false, start = nil)
      super
      frame_init
      drop_presets_section
    end

    # Pick mode (the Overworld Menu's Edit Pages > Add a Setting): the same
    # screen, sections and search, but A on a setting or a button picks it
    # and closes, and nothing is changed. Returns its row key
    # ("setting:..."), or nil.
    def self.pick
      s = new(false)
      s.instance_variable_set(:@pick_mode, true)
      s.main
      return s.picked
    end

    # Default (KIF Settings' A): nothing is changed while picking.
    def reset_default(*args)
      return pbPlayBuzzerSE if @pick_mode
      r = current
      return pbPlayBuzzerSE if r && kr_lock(r.opt)
      super
    end

    def pick_setting
      r = current
      return nil unless r
      rows = Reloaded::OverworldMenu::SettingRows
      unless rows.fits_row?(r)
        pbPlayBuzzerSE
        why = if rows.own_switch?(r.opt) then _INTL("The Overworld Menu's own switch can't go on one of its pages.")
              else _INTL("That row only opens another page of KIF Settings, so it can't go on a page.")
              end
        Reloaded::Dialogs.notice(self, _INTL("Add a Setting"), why)
        return nil
      end
      @picked = rows.key_for(r)
      @pick_done = true
      pbPlayDecisionSE
      return nil
    end

    #--------------------------------------------------------------------------
    # Running
    #--------------------------------------------------------------------------
    def main
      open_sprites
      refresh
      loop do
        Graphics.update
        Input.update
        update_frame
        break if handle_input == :close
        tick_description
      end
      dispose_sprites
      close_effects unless @pick_mode
      return nil
    rescue StandardError => e
      Reloaded::Log.exception("The improved settings screen failed; KIF Settings instead", e, :settings)
      dispose_sprites
      return Reloaded::KIFBridge.vanilla { ::KifSettingsScreen.new(@inloadscreen).main }
    ensure
      dispose_sprites
      # a module or a mod switched here can change the Overworld Menu's setting rows
      Reloaded::OverworldMenu::SettingRows.forget if defined?(Reloaded::OverworldMenu::SettingRows) && !@pick_mode
    end

    def handle_input
      return :close if @pick_done
      return search if Input.trigger?(Input::JUMPUP) || Input.trigger?(Input::SPECIAL) || clicked?(*SEARCH_BOX)
      return open_presets if Input.trigger?(Input::R) || clicked?(*right_box)
      handled, result = mouse_input
      return result if handled
      return side_input if @focus == :side
      return list_input
    end

    # Left/Right: choices cycle (a held direction stops at the ends, a fresh
    # press, or a click, goes round); sliders and numbers step as in KIF
    # Settings.
    def change(dir, round = false)
      return pbPlayBuzzerSE if @pick_mode       # picking, not changing
      r = current
      return unless r
      o = r.opt
      return if KIF::SettingsScreen.button?(o)
      return pbPlayBuzzerSE if lock_name(o)
      if kr_lock(o)
        pbPlayBuzzerSE if round || Input.trigger?(dir > 0 ? Input::RIGHT : Input::LEFT)
        return
      end
      cur = (o.get rescue nil)
      return if cur.nil?
      nv = step_value(o, cur, dir, round)
      return if nv == cur
      o.set(nv)
      pbPlayCursorSE
      after_change
    end

    # The value one step on from cur; choices go round when round (or on a
    # fresh press), and step over the ones that are locked.
    def step_value(o, cur, dir, round)
      choices = KIF::SettingsScreen.choices?(o)
      wrap = choices && o.values.length > 1 && (round || Input.trigger?(dir > 0 ? Input::RIGHT : Input::LEFT))
      locks = choices ? Reloaded::KIFDropdowns.locks(o) : {}
      nv = cur
      (choices ? o.values.length : 1).times do
        step = dir > 0 ? o.next(nv) : o.prev(nv)
        if step == nv
          break unless wrap
          step = dir > 0 ? 0 : o.values.length - 1
        end
        nv = step
        break unless locks.has_key?(nv)
      end
      return locks.has_key?(nv) ? cur : nv
    end

    # A: buttons and KIF's actions as in KIF Settings; choices open their
    # dropdown (their own picker when they have one; tabs cycle); sliders
    # and numbers open a number popup.
    def press
      return pick_setting if @pick_mode
      r = current
      return unless r
      o = r.opt
      return super if r.action || KIF::SettingsScreen.button?(o)
      return pbPlayBuzzerSE if lock_name(o) || kr_lock(o)
      if KIF::SettingsScreen.choices?(o)
        return pick(r) if picker?(o)
        return open_dropdown(r) if dropdown?(r)
        return cycle(o)
      end
      return choose_number(r) if KIF::SettingsScreen.slider?(o) || o.is_a?(NumberOption)
      super
    end

    # Search, as KIF Settings' works: typed straight into the title bar, the
    # list following as you type; Enter or Down goes to the results, Esc
    # stops typing and keeps the search. A controller's A opens the naming
    # screen.
    def search
      pbPlayDecisionSE
      @sub = nil
      text, _how = run_entry(:search, _INTL("Type to Search"), @query || "", 30,
                             :prompt => _INTL("Search Settings"), :down => true) { |t| self.query = t }
      self.query = text
      if @query && !opt_rows.empty?
        @focus = :list
      elsif @focus == :list && opt_rows.empty?
        @focus = :side
      end
      refresh
      return nil
    end

    # Typing in this screen's title bar (TextEntry). kind: :search or
    # :rename. Returns [text, how].
    def run_entry(kind, label, initial, max, prompt: nil, down: false, &on_change)
      @entry_kind = kind
      return Reloaded::TextEntry.run(self, label, initial, max, :prompt => prompt, :down => down, &on_change)
    ensure
      @entry_kind = nil
    end

    def entry=(state)
      @entry = state
    end

    def entry_changed
      refresh
    end

    def rebuild
      @boxes = nil
      super
    end

    #--------------------------------------------------------------------------
    # Drawing
    #--------------------------------------------------------------------------
    def refresh
      draw_screen if @sprite && !@sprite.disposed?
    end

    def draw(_bitmap = nil)
      refresh
    end

    # Choices always show between arrows; :below when the name leaves no room.
    def value_mode(r)
      kind = value_kind(r)
      return kind if kind == :button || kind == :tabs
      name_end = NAME_X + r.indent * 16 + PF.width(PF::ROW, r.label) + 10
      left = kind == :slider ? slider_x0(r) : value_left(r)
      return name_end <= left ? kind : :below
    end

    private

    def drop_presets_section
      id = @sections[@section] && @sections[@section][0]
      @sections = @sections.reject { |s| s[0] == :presets }
      @section = @sections.index { |s| s[0] == id } || next_section(-1, 1) || 0
    end

    #--------------------------------------------------------------------------
    # Input
    #--------------------------------------------------------------------------
    def side_input
      if Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)
        dir = Input.repeat?(Input::DOWN) ? 1 : -1
        target = step_section(@section, dir)
        if target.nil?
          return nil unless fresh?(dir)
          target = dir < 0 ? next_section(@sections.length, -1) : next_section(-1, 1)
        end
        return nil if target.nil? || target == @section
        @section = target
        @sel = 0
        @scroll = 0
        pbPlayCursorSE
        refresh
      elsif Input.trigger?(Input::RIGHT) || Input.trigger?(Input::USE)
        if opt_rows.empty?
          pbPlayBuzzerSE
        else
          @focus = :list
          pbPlayDecisionSE
          refresh
        end
      elsif Input.trigger?(Input::BACK)
        if @query                  # a search with no results: B clears it first
          pbPlayCancelSE
          self.query = nil
          refresh
          return nil
        end
        pbPlayCloseMenuSE
        return :close
      end
      return nil
    end

    # The next section with something in it, or nil at the end of the list.
    def step_section(from, dir)
      i = from + dir
      while i >= 0 && i < @sections.length
        return i unless empty_section?(i)
        i += dir
      end
      return nil
    end

    def list_input
      n = opt_rows.length
      if n == 0
        if @query && Input.trigger?(Input::BACK)
          pbPlayCancelSE
          self.query = nil
          @focus = :side
          refresh
        elsif !@query
          @focus = :side
          refresh
        end
        return nil
      end
      if Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)
        dir = Input.repeat?(Input::DOWN) ? 1 : -1
        target = @sel % n + dir
        if target < 0 || target >= n
          return nil unless fresh?(dir)
          target = dir < 0 ? n - 1 : 0
        end
        @sel = target
        pbPlayCursorSE
        refresh
      elsif Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)
        change(Input.repeat?(Input::RIGHT) ? 1 : -1)
      elsif Input.trigger?(Input::USE)
        press
      elsif Input.trigger?(Input::ACTION)
        reset_default
      elsif Input.trigger?(Input::BACK)
        back_out
      end
      return nil
    end

    # The mouse: moving it over a section or a row picks it (hover); a click
    # opens a section's list, presses a row as A does, or steps a value when
    # it's on the value's left or right side; a click on a hint does what the
    # hint says. The wheel scrolls the list (the cursor stays under the mouse)
    # or, over the sections, moves between them; a right click goes back.
    # Returns [handled, result].
    def mouse_input
      pt = Reloaded::Pointer
      if pointer_hover && !@entry
        if (i = pt.hit(@side_hits))
          hover_section(i)
        elsif (li = pt.hit(@row_hits))
          hover_row(li)
        end
      end
      return [true, mouse_back] if pt.right?
      dir = pt.wheel
      if dir != 0
        pt.inside?(LIST_X0, LIST_Y0, LIST_X1, LIST_Y1) ? wheel_scroll(dir) : wheel_sections(dir)
        return [true, nil]
      end
      return [false, nil] unless pt.left?
      handled, result = hint_click
      return [true, result] if handled
      if (i = pt.hit(@side_hits))
        click_section(i)
      elsif (li = pt.hit(@row_hits))
        click_row(li)
      end
      return [true, nil]
    end

    # B, from the mouse or the hint line: back out of the list, a search, or
    # the screen.
    def mouse_back
      if @focus == :list
        back_out
        return nil
      end
      if @query
        pbPlayCancelSE
        self.query = nil
        refresh
        return nil
      end
      pbPlayCloseMenuSE
      return :close
    end

    # The hint line's Open: the picked section's list.
    def mouse_open
      return pbPlayBuzzerSE if opt_rows.empty?
      @focus = :list
      pbPlayDecisionSE
      refresh
      return nil
    end

    # The hint line's Change: the picked row's value, one step on.
    def mouse_change
      change(1, true)
      return nil
    end

    def hover_section(i)
      return if @query || empty_section?(i)
      return if i == @section && @focus == :side
      @section = i
      @sub = nil
      @sel = 0
      @scroll = 0
      @focus = :side
      pbPlayCursorSE
      refresh
    end

    def hover_row(li)
      k = opt_rows.index(li)
      return unless k
      return if @focus == :list && @sel % opt_rows.length == k
      @focus = :list
      @sel = k
      pbPlayCursorSE
      refresh
    end

    # A section: opens its list.
    def click_section(i)
      return pbPlayBuzzerSE if empty_section?(i) && !@query
      self.query = nil if @query
      if i != @section
        @section = i
        @sub = nil
        @sel = 0
        @scroll = 0
      end
      mouse_open
    end

    # A row: on a choice's value, its dropdown (or picker); on either side
    # of a value, a step that way; elsewhere, what A does.
    def click_row(li)
      hover_row(li)
      r = current
      return unless r
      x = Reloaded::Pointer.pos.to_a[0].to_i
      kind = value_kind(r)
      value_x = case kind
                when :slider then slider_x0(r)
                when :arrows then value_left(r)
                when :tabs   then LIST_X0
                end
      return press unless value_x && x >= value_x
      mid = kind == :tabs ? (LIST_X0 + LIST_X1) / 2 : column(r)
      if kind == :arrows && KIF::SettingsScreen.choices?(r.opt)
        half = PF.width(PF::TEXT, PF.fit(PF::TEXT, shown_value(r.opt), VALUE_MAX)) / 2 + 3
        return press if (x - mid).abs <= half
      end
      change(x < mid ? -1 : 1, true)
    end

    # The wheel over the list: the view scrolls a row, and the cursor goes
    # to the row now under the mouse (or stays in view).
    def wheel_scroll(dir)
      list = rows
      o = opt_rows
      return if o.empty?
      ys = []
      y = 0
      list.each { |r| ys << y; y += row_h(r) }
      avail = (LIST_Y1 - 4) - (LIST_Y0 + 4)
      return if y <= avail
      last = ys.find { |v| y - v <= avail } || 0          # the furthest the view goes
      to = dir > 0 ? (ys.find { |v| v > @scroll } || @scroll) : (ys.reverse.find { |v| v < @scroll } || 0)
      to = [[to, last].min, 0].max
      return if to == @scroll
      @scroll = to
      my = Reloaded::Pointer.pos.to_a[1].to_i
      under = o.index { |li| top = LIST_Y0 + 4 + ys[li] - to; my >= top && my < top + row_h(list[li]) }
      seen = o.each_index.select { |k| ys[o[k]] >= to && ys[o[k]] + row_h(list[o[k]]) - to <= avail }
      k = under || (seen.include?(@sel % o.length) ? @sel % o.length : (dir > 0 ? seen.first : seen.last))
      @sel = k if k
      @focus = :list
      refresh
    end

    # The wheel over the sections: the next one with something in it.
    def wheel_sections(dir)
      target = step_section(@section, dir)
      return unless target
      @section = target
      @sub = nil
      @sel = 0
      @scroll = 0
      @focus = :side
      pbPlayCursorSE
      refresh
    end

    # B in the list: out of a sub-page, the search, or back to the sections.
    def back_out
      pbPlayCancelSE
      if @sub
        @sel = @sub[:ret] || 0
        @sub = @sub[:back]
        @sub[:rows] = @sub[:build].call if @sub
        @scroll = 0
      elsif @query
        self.query = nil
        @focus = :side
      else
        @focus = :side
      end
      refresh
    end

    def open_presets
      pbPlayDecisionSE
      if Reloaded::Presets.available?
        Reloaded::Presets.open(self)
        after_change
      else
        Reloaded::Dialogs.notice(self, _INTL("Presets"),
          _INTL("Load a save to use presets. A preset keeps a save's settings to load into another save."))
        refresh
      end
      return nil
    end

    # Kanto Reloaded's :long settings (Theme, the frames, the colours) open
    # their own picker.
    def picker?(o)
      return Reloaded::KIFDropdowns.own_picker?(o)
    end

    # Choices shown between arrows open a dropdown; tabs cycle.
    def dropdown?(r)
      return value_kind(r) == :arrows && Reloaded::KIFDropdowns.dropdown?(r.opt)
    end

    # The dropdown under r's value (Frame#run_dropdown): the description
    # box explains the highlighted choice as it moves.
    def open_dropdown(r)
      o = r.opt
      anchor = (@value_boxes || {})[r]
      return cycle(o) unless anchor
      cur = (o.get rescue 0).to_i
      values = o.values.map { |v| PF.utf8(v.to_s) }
      dd = Reloaded::Dropdown.new(values, cur, anchor, dropdown_bounds(LIST_X0, LIST_Y0, LIST_X1, LIST_Y1),
                                  :locked => Reloaded::KIFDropdowns.locks(o).keys)
      @dropdown_keys = Array.new(values.length) { Object.new }    # each choice's description scrolls on its own
      choice = run_dropdown(dd) { tick_description }
      return if choice.nil? || choice == cur
      o.set(choice)
      after_change
    end

    def pick(r)
      o = r.opt
      cur = (o.get rescue 0).to_i
      swatch = nil
      if Reloaded::KIFBridge.bridge_option?(o)
        d = Reloaded::Settings.definition(o.kr_key)
        swatch = d[:swatch] if d
      end
      values = o.values.map { |v| PF.utf8(v.to_s) }
      title = PF.fit(PF::ROW, r.label, Reloaded::Dialogs::PICK_W - 20)
      choice = Reloaded::Dialogs.picker(self, title, values, cur, swatch)
      refresh
      return if choice.nil? || choice == cur
      o.set(choice)
      after_change
    end

    def cycle(o)
      cur = (o.get rescue nil)
      return if cur.nil?
      return pbPlayBuzzerSE if o.values.length < 2
      o.set((cur.to_i + 1) % o.values.length)
      pbPlayCursorSE
      after_change
    end

    def choose_number(r)
      o = r.opt
      start = o.optstart.to_i
      cur = (o.get rescue 0).to_i + start
      step = o.instance_variable_get(:@optinterval) || 1
      unit = ""
      if Reloaded::KIFBridge.bridge_option?(o)
        d = Reloaded::Settings.definition(o.kr_key)
        unit = d[:unit].to_s if d
      end
      value = Reloaded::Dialogs.number(self, r.label, cur, start, o.optend.to_i, step, unit)
      refresh
      return if value.nil? || value == cur
      o.set(value - start)
      after_change
    end

    #--------------------------------------------------------------------------
    # Painting
    #--------------------------------------------------------------------------
    def draw_screen
      c = palette
      base = @sprite.bitmap
      top = @top_sprite.bitmap
      base.clear
      top.clear
      base.fill_rect(0, 0, W, H, c[:bg])
      @cursor_rect = nil
      @column_sig = nil
      paint_title(base, top, c)
      paint_sidebar(base, top, c)
      paint_list(base, top, c)
      paint_description(base, top, c)
      paint_hints(base, c)
      paint_dropdown(c)
      place_cursor
    end

    def paint_title(base, top, c)
      paint_title_bar(base, c)
      if @entry
        search = @entry_kind == :search
        Reloaded::TextEntry.draw_field(base, top, c, @entry, 8, 4, W - 16, 23, search ? 26 : 10)
        magnifier(base, 15, c[:txt], c[:dark]) if search
        if search && @query
          n = opt_rows.length
          found = n == 1 ? _INTL("1 Found") : _INTL("{1} Found", n)
          P.small(top, W - 120, 4, 100, 23, found, c[:dim], 1)
        end
        return
      end
      P.text(top, 0, 2, W, 28, @pick_mode ? _INTL("Add a Setting") : _INTL("KIF Settings"), c[:title], PF::TITLE, 2)
      title_box(base, top, c, 8, @query || _INTL("Search"), :search => true, :active => !@query.nil?)
      title_box(base, top, c, W - 8 - BUTTON_W, _INTL("Presets"), :off => !Reloaded::Presets.available?)
      title_keys(top, c, left_key, right_key)   # the buttons that open them
    end

    def paint_sidebar(base, top, c)
      P.ui.rbox(base, 6, 36, SIDE_X1, LIST_Y1, 6, c[:panel])
      fit = (LIST_Y1 - 4 - SIDE_Y0) / SIDE_DY
      @side_scroll = @section - fit + 1 if @section >= @side_scroll + fit
      @side_scroll = @section if @section < @side_scroll
      found = {}
      rows.each { |r| found[r.section] = true if r.kind == :opt } if @query
      faded = Reloaded::Palette.mix(c[:dim], c[:panel], 0.45)
      y = SIDE_Y0
      @side_hits = []                              # for the mouse
      (@sections[@side_scroll, fit] || []).each_with_index do |(id, label, col), k|
        i = k + @side_scroll
        @side_hits << [i, 9, y - 1, SIDE_X1 - 3, y + SIDE_DY - 2]
        active = i == @section && !@query
        @cursor_rect = [9, y - 1, SIDE_X1 - 3 - 9 + 1, SIDE_DY] if active && @focus == :side && !@entry
        name = PF.utf8(_INTL(label))
        if id == Reloaded::KIFBridge::SECTION
          P.poke_ball(top, 14, y + 2, 15)        # Kanto Reloaded: a Poke Ball instead of a tile
        else
          P.ui.rbox(top, 14, y + 2, 28, y + 16, 3, Color.new(*col))
          P.glyph(top, 14, y + 2, 15, 15, name[0], TILE_TEXT)
        end
        dim = @query ? !found[id] : empty_section?(i)
        color = active ? c[:strong] : (dim ? faded : c[:dim])
        P.text(top, 33, y + 2, SIDE_X1 - 37, 15, PF.fit(PF::TEXT, name, SIDE_X1 - 37), color)
        y += SIDE_DY
      end
    end

    def empty_message
      return _INTL("Nothing matches \"{1}\".", @query) if @query
      return _INTL("No mods yet. Put them in the Mods folder.") if section_id == :mods
      return _INTL("Load a save to change these settings.") unless KIF.in_game?
      return _INTL("Nothing here right now.")
    end

    def paint_list(base, top, c)
      P.ui.rbox(base, LIST_X0, LIST_Y0, LIST_X1, LIST_Y1, 6, c[:panel])
      @row_hits = []
      @value_boxes = {}.compare_by_identity         # where each choice's dropdown drops from
      list = rows
      if list.empty?
        w = LIST_X1 - LIST_X0 - 24
        P.text(top, LIST_X0 + 12, LIST_Y0 + 8, w, 22, PF.fit(PF::TEXT, empty_message, w), c[:dim])
        return
      end
      out, total, avail, sel_row = layout_rows
      out.each do |i, y|
        r = list[i]
        if r.kind == :head
          P.heading(top, LIST_X0 + 10, LIST_X1 - 10, y + 3, r.label, c[:head], c[:line])
          next
        end
        @row_hits << [i, LIST_X0 + 4, y, LIST_X1 - 8, y + row_h(r) - 1]
        selected = i == sel_row && @focus == :list && !@entry
        mode = value_mode(r)
        @cursor_rect = [LIST_X0 + 4, y, (LIST_X1 - 8) - (LIST_X0 + 4) + 1, row_h(r) - 1] if selected
        x = NAME_X + r.indent * 16
        if r.indent > 0
          base.fill_rect(x - 9, y + 2, 1, 12, c[:line])
          base.fill_rect(x - 9, y + 13, 6, 1, c[:line])
        end
        if changed?(r)
          dy = y + (ROW_H - 2) / 2 - 3
          P.ui.rrect(top, x - 11, dy, x - 6, dy + 5, 3, c[:dot])
        end
        unless mode == :tabs
          room = (mode == :button ? chip_left(r) - 8 : VAL_X1) - x      # a button row's name stops before its chip
          nw = P.text(top, x, y, room, ROW_H - 2, PF.fit(PF::ROW, r.label, room), kr_lock(r.opt) ? c[:dim] : c[:opt], PF::ROW)
          if lock_name(r.opt)
            lx = x + nw + 6
            room = mode == :below ? VAL_X1 : (value_kind(r) == :slider ? slider_x0(r) : value_left(r)) - 6
            label = _INTL("LOCKED")
            P.pill(top, lx, y + 4, label, LOCK_FILL, c[:white], false) if lx + P.width(PF::TINY, label) + 12 <= room
          end
        end
        vy = mode == :below ? y + ROW_H : y
        paint_value(top, c, r, vy, selected, value_kind(r)) unless value_hidden?(r, vy)
        if value_kind(r) == :arrows
          cx = column(r)
          wmax = value_box(r.opt)[1]
          @value_boxes[r] = [cx - wmax / 2 - 14, vy, cx + wmax / 2 + 10, vy + ROW_H - 2]
        end
      end
      return unless total > avail
      track = LIST_Y1 - LIST_Y0 - 12
      bar = [track * avail / total, 12].max
      pos = (track - bar) * @scroll / [total - avail, 1].max
      base.fill_rect(LIST_X1 - 5, LIST_Y0 + 6, 2, track, c[:line])
      base.fill_rect(LIST_X1 - 5, LIST_Y0 + 6 + pos, 2, bar, c[:dim])
    end

    # While a dropdown is open, a value it would cut through isn't drawn
    # (vy: the top of the value's line).
    def value_hidden?(r, vy)
      return false unless @dropdown
      x0 = case value_kind(r)
           when :slider then slider_x0(r)
           when :tabs   then LIST_X0 + 10
           when :button then column(r) - 30
           else value_left(r)
           end
      return @dropdown.covers?(x0, vy + 4, VAL_X1 + 10, vy + ROW_H - 5)
    end

    # How a row's value shows: :button, :slider, :tabs (a choice with no
    # name: KIF's tab rows) or :arrows.
    def value_kind(r)
      o = r.opt
      return :button if KIF::SettingsScreen.button?(o)
      return :slider if KIF::SettingsScreen.slider?(o)
      return :tabs if KIF::SettingsScreen.choices?(o) && r.label.to_s.strip.empty?
      return :arrows
    end

    # The centre of a row's value column. Values, OPEN, badges and sliders'
    # numbers line up on it, one column per heading: as far right as the
    # widest value under that heading allows (so a long one, like Theme's
    # Thunder Yellow, only moves its own heading's column).
    def column(r)
      sig = [@sub.object_id, @query, @section, @rows.object_id]   # search builds its list anew
      unless @column_sig == sig
        @column_sig = sig
        @columns = {}
        @groups = {}.compare_by_identity
        g = 0
        rows.each do |o|
          g += 1 if o.kind == :head
          @groups[o] = g
          next unless o.kind == :opt && value_kind(o) == :arrows
          @columns[g] = [@columns[g] || VALUE_CX, value_box(o.opt)[0]].min
        end
      end
      return @columns[@groups[r]] || VALUE_CX
    end

    # Where a slider's track starts: its number centres on the column.
    def slider_x0(r)
      return column(r) - 20 - SLIDER_W
    end

    # [centre x, widest value] a row's arrows need on their own.
    def value_box(o)
      @boxes ||= {}.compare_by_identity
      return @boxes[o] if @boxes[o]
      widths = if o.is_a?(NumberOption)
                 [o.optstart, o.optend].map { |v| PF.width(PF::TEXT, v.to_s) }
               elsif KIF::SettingsScreen.choices?(o)
                 o.values.map { |v| PF.width(PF::TEXT, PF.fit(PF::TEXT, PF.utf8(v.to_s), VALUE_MAX)) }
               else
                 [PF.width(PF::TEXT, PF.fit(PF::TEXT, shown_value(o), VALUE_MAX))]
               end
      wmax = widths.max || 0
      return @boxes[o] = [value_centre(wmax), wmax]
    end

    # Where a row's value starts (its left arrow, or its badge).
    def value_left(r)
      o = r.opt
      cx = column(r)
      wmax = value_box(o)[1]
      left = cx - wmax / 2 - 14
      badge = o.respond_to?(:kif_badge) ? o.kif_badge : nil
      left -= P.width(PF::TINY, badge[0]) + 20 if badge
      return left
    end

    def shown_value(o)
      cur = (o.get rescue 0)
      return (cur.to_i + o.optstart.to_i).to_s if o.is_a?(NumberOption)
      vals = (o.respond_to?(:values) && o.values.is_a?(Array)) ? o.values : nil
      return PF.utf8(vals[cur.to_i].to_s) if vals && cur.is_a?(Integer) && vals[cur]
      return PF.utf8(cur.to_s)
    end

    # A tab's label, the count after it (KIF writes "Installed 2"; the
    # count is drawn small, in TINY), and the width of both.
    def tab_parts(value)
      v = PF.utf8(value.to_s)
      m = v.match(/\A(.*\S)\s+(\d+)\z/)
      return [v, nil, PF.width(PF::TEXT, v)] unless m
      return [m[1], m[2], PF.width(PF::TEXT, m[1]) + COUNT_GAP + PF.width(PF::TINY, m[2])]
    end

    # Why a Kanto Reloaded row can't be changed right now (another setting
    # decides it), or nil
    def kr_lock(opt)
      return nil unless opt && opt.respond_to?(:kr_key) && opt.kr_key
      return Reloaded::Settings.lock_reason(opt.kr_key)
    rescue StandardError
      return nil
    end

    # The mod that locked a row's setting (KIF 0.21.52's Experiences), or nil.
    def lock_name(opt)
      return nil unless opt && respond_to?(:locked_by, true)
      return locked_by(opt)
    rescue StandardError
      return nil
    end

    def badge_fill(color, c)
      return c[:pill] if color == KIF::PixelUI::PILL
      return color
    end

    # y: the top of the value's line (ROW_H - 2 tall).
    # Where a button row's chip (OPEN, BLOCKED...) starts, or the value
    # column's end when it has none (long mod names ran under it; KIF
    # Settings stops them there too since 0.21.56).
    def chip_left(r)
      o = r.opt
      badge = o.respond_to?(:kif_badge) ? o.kif_badge : nil
      label = if badge then badge[0]
              elsif o.instance_variable_get(:@onPressProc) || r.action then _INTL("OPEN")
              end
      return VAL_X1 unless label
      w = P.width(PF::TINY, label.to_s) + 12
      return [column(r) - w / 2, Reloaded::Frame::VALUE_X1 - w].min
    end

    def paint_value(top, c, r, y, selected, kind)
      o = r.opt
      locked = kr_lock(o)
      badge = o.respond_to?(:kif_badge) ? o.kif_badge : nil
      cx = column(r) unless kind == :tabs
      case kind
      when :button
        if badge
          column_pill(top, cx, y + 4, badge[0], badge_fill(badge[1], c), c[:txt])
        elsif o.instance_variable_get(:@onPressProc) || r.action
          column_pill(top, cx, y + 4, _INTL("OPEN"), selected ? c[:selb] : c[:pill], selected ? c[:dark] : c[:txt])
        end
      when :slider
        start = o.optstart.to_i
        v = (o.get rescue 0).to_i + start
        span = [o.optend.to_i - start, 1].max
        frac = [[(v - start).to_f / span, 0].max, 1].min
        x0 = slider_x0(r)
        x1 = x0 + SLIDER_W
        kx = x0 + (frac * (x1 - x0)).round
        P.ui.rbox(top, x0, y + 10, x1, y + 14, 2, c[:dark])
        P.ui.rbox(top, x0, y + 10, kx, y + 14, 2, locked ? c[:line] : (selected ? c[:selb] : c[:segon]))
        P.ui.rbox(top, kx - 4, y + 6, kx + 4, y + 18, 3, locked ? c[:dim] : c[:txt])
        P.text(top, cx - 25, y, 50, ROW_H - 2, v.to_s, locked ? c[:dim] : c[:opt], nil, 2)
        padlock(top, cx + P.width(PF::TEXT, v.to_s) / 2 + 6, y + 6, c[:dim]) if locked
      when :tabs
        tabs = o.values.map { |v| tab_parts(v) }
        cur = (o.get rescue 0).to_i
        x0 = LIST_X0 + 10
        widths = tabs.map { |t| t[2] + 12 }
        extra = [(VAL_X1 - x0 - widths.sum) / [tabs.length, 1].max, 0].max
        widths.map! { |w| w + extra }
        P.ui.rbox(top, x0 - 1, y + 1, x0 + widths.sum, y + 22, 4, c[:dark], c[:line])
        tx = x0
        tabs.each_with_index do |(label, count, width), k|
          tw = widths[k]
          on = k == cur && selected
          if k == cur
            P.ui.rbox(top, tx + 1, y + 2, tx + tw - 1, y + 21, 3, on ? c[:selb] : c[:segon])
          end
          lx = tx + (tw - width) / 2
          lw = P.text(top, lx, y, width, ROW_H - 2, label, k == cur ? (on ? c[:dark] : c[:txt]) : c[:dim])
          if count
            # Light: the label's own colour on the highlighted tab, the deeper green elsewhere
            tone = c[:light] ? (on ? c[:dark] : c[:green]) : (on ? COUNT_ON : COUNT)
            P.text(top, lx + lw + COUNT_GAP, y, width, ROW_H - 2, count, tone, PF::TINY)
          end
          tx += tw
        end
      else
        wmax = value_box(o)[1]
        v = PF.fit(PF::TEXT, shown_value(o), VALUE_MAX)
        vw = PF.width(PF::TEXT, v)
        P.text(top, cx - vw / 2, y, vw + 2, ROW_H - 2, v, locked ? c[:dim] : c[:opt])
        if locked
          padlock(top, cx + vw / 2 + 6, y + 6, c[:dim])
        else
          arrow = selected ? c[:txt] : c[:dim]
          P.ui.tri(top, cx - vw / 2 - 14, y + 7, :l, arrow, 4)
          P.ui.tri(top, cx + vw / 2 + 6, y + 7, :r, arrow, 4)
        end
        P.pill(top, cx - wmax / 2 - 20, y + 4, badge[0], badge_fill(badge[1], c), c[:txt]) if badge
      end
    end

    def paint_description(base, top, c)
      y0 = LIST_Y1 + 4
      description_box(base, c, y0)
      r = (@focus == :list || @query) ? current : nil
      if r.nil?
        label = @sub ? @sub[:title] : _INTL(@sections[@section][1])
        P.text(top, 14, y0 + 1, 330, 26, PF.fit(PF::ROW, label, 330), c[:head], PF::ROW)
        paint_lines(top, c, y0, P.small_wrap(top, section_help, W - 30).first(DESC_LINES))
        return
      end
      title = r.label.to_s.strip.empty? ? _INTL(@sections[@section][1]) : r.label
      title = @dropdown.values[@dropdown.index] if @dropdown           # the highlighted choice
      P.text(top, 14, y0 + 1, 330, 26, PF.fit(PF::ROW, title, 330), c[:head], PF::ROW)
      x = W - 14
      if r.scope && r.section != :modules && r.section != :presets && !r.action
        x -= P.pill(top, x, y0 + 7, r.scope == :global ? _INTL("ALL SAVES") : _INTL("THIS SAVE"), c[:pill], c[:txt]) + 6
      end
      if (by = lock_name(r.opt))
        by = PF.utf8(by.to_s)
        by = by[0, 17] + "..." if by.length > 20
        P.pill(top, x, y0 + 7, _INTL("LOCKED BY {1}", by.upcase), LOCK_FILL, c[:white])
      elsif @defaults.has_key?(r.opt) && KIF::SettingsScreen.choices?(r.opt)
        d = r.opt.values[@defaults[r.opt].to_i]
        P.pill(top, x, y0 + 7, _INTL("DEFAULT: {1}", PF.utf8(d.to_s).upcase), c[:pill], c[:txt]) if d
      elsif @defaults.has_key?(r.opt) && KIF::SettingsScreen.slider?(r.opt)
        P.pill(top, x, y0 + 7, _INTL("DEFAULT: {1}", @defaults[r.opt].to_i + r.opt.optstart.to_i), c[:pill], c[:txt])
      end
      text = desc_of(r.opt)
      text = Reloaded::KIFDropdowns.explain(r.opt, @dropdown.index, text) if @dropdown
      lines = P.small_wrap(top, text, W - 30)
      lines = P.small_wrap(top, text, W - 46) if lines.length > DESC_LINES   # room for the arrows
      first = desc_first_line(desc_key(r), lines.length)
      paint_lines(top, c, y0, lines[first, DESC_LINES])
      return unless lines.length > DESC_LINES
      P.ui.tri(top, W - 22, y0 + 32, :u, first > 0 ? c[:dim] : c[:line], 3)
      P.ui.tri(top, W - 22, y0 + 72, :d, first + DESC_LINES < lines.length ? c[:dim] : c[:line], 3)
    end

    # What a description's scrolling follows: the row, or the highlighted
    # choice while a dropdown is open.
    def desc_key(r)
      return @dropdown ? @dropdown_keys[@dropdown.index] : r
    end

    # A description longer than the box scrolls while it stays shown (KIF
    # Settings' own, following desc_key).
    def tick_description
      r = (@focus == :list || @query) ? current : nil
      return unless r && desc_key(r).object_id == @desc_row
      before = @desc_tick.to_i / DESC_STEP
      @desc_tick = @desc_tick.to_i + 1
      refresh if @desc_tick / DESC_STEP != before
    end

    # What the open section holds: its headings.
    def section_help
      return "" if @sub
      id = section_id
      return _INTL(SECTION_HELP[id]) if SECTION_HELP[id]
      heads = (@rows[id] || []).select { |r| r.kind == :head }.map { |r| PF.utf8(r.label.to_s) }.uniq
      return heads.empty? ? "" : heads.join(", ") + "."
    end

    # The hint line. Search and Presets aren't in it: their buttons show
    # beside them in the title bar.
    def hint_pairs
      pr = Reloaded::Prompts
      back = button(:B)
      if @entry
        search = @entry_kind == :search
        if pr.controller?
          return [[button(:C), _INTL("Type")], [:d, _INTL("Results")], [back, _INTL("Done")]] if search
          return [[button(:C), _INTL("Type")], [back, _INTL("Cancel")]]
        end
        enter = Reloaded::Controls::Inputs.key(40)
        esc = Reloaded::Controls::Inputs.key(41)
        return [[nil, _INTL("Type to Search")], [enter, _INTL("Results")], [esc, _INTL("Done")]] if search
        return [[nil, _INTL("Type a Name")], [enter, _INTL("Done")], [esc, _INTL("Cancel")]]
      end
      # a third part: what a click on the hint does
      return dropdown_hints if @dropdown
      if @focus == :side
        return [[:ud, _INTL("Section")], [:lr, _INTL("Open"), :mouse_open], [back, @query ? _INTL("Clear") : _INTL("Close"), :mouse_back]]
      end
      out = @query ? _INTL("Clear") : (@sub ? _INTL("Back") : _INTL("Sections"))
      return [[:ud, _INTL("Select")], [button(:C), _INTL("Add to Page")], [back, out, :mouse_back]] if @pick_mode
      return [[:ud, _INTL("Select")], [:lr, _INTL("Change"), :mouse_change], [button(:A), _INTL("Default"), :reset_default],
              [back, out, :mouse_back]]
    end
  end
end
