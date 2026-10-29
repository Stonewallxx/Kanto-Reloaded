#==============================================================================
# Kanto Reloaded: the Controls screen
#==============================================================================
# Rebinding every action of Reloaded Controls, in the Options layout (the
# improved KIF Settings' frame, Reloaded::Frame). Opened with Change
# Controls (Kanto Reloaded > Controls in KIF Settings).
#
#   - the sidebar: Global, Overworld, Menus, Battle (areas with no actions
#     yet are dimmed and skipped), Speed-Up (Speed-Up's settings, then its
#     buttons under a Buttons heading) and Feel (the feel settings)
#   - a setting row: Left/Right step it, A or a click on the value opens a
#     dropdown of the values; a locked one (the other Speed-Up Type's) is
#     dimmed, with a padlock
#   - the list: actions under their headings, a Keyboard and a Controller
#     column; Left/Right picks the column, A edits it, the Default button
#     puts it back
#   - editing: Remove a binding, Add a Key / Add a Button, Back to Default;
#     adding waits for the press ("Press a Button or Move a Stick. Keep
#     holding it to bind it as a Hold."); nothing pressed: it closes when
#     the bar runs out
#   - a key another action in the area already has asks: Swap, Keep Both or
#     Cancel
#   - Confirm, Back and the directions always keep at least one input
#   - Search (top left) finds actions by name; Layouts (top right, R) has
#     the game's layout (F1), Reset Section and Reset All
#==============================================================================

unless defined?(::KIF::PixelFont) && defined?(::KIF::PixelUI) && defined?(Reloaded::Frame)
  Reloaded::Log.info("No pixel fonts; the Controls screen is off", :controls)
  return
end

module Reloaded
  class ControlsScreen
    include Reloaded::Frame

    PF = ::KIF::PixelFont
    C = Reloaded::Controls
    L = Reloaded::Controls::Layouts
    SIDE_X1 = 174
    LIST_X0 = 180
    LIST_X1 = W - 6
    LIST_Y0 = 36
    LIST_Y1 = H - 120
    ROW_H   = 26
    HEAD_H  = 18
    COLS_H  = 18          # the KEYBOARD / CONTROLLER labels
    NAME_X  = LIST_X0 + 21
    KEY_X   = 328         # the keyboard column
    PAD_X   = 428         # the controller column
    VAL_X1  = LIST_X1 - 12
    CAPTURE_STEPS = 200   # how long "Press a Button" waits (5 seconds)
    TILE_TEXT = Color.new(248, 248, 248)
    SEARCH_BOX = [8, 4, 8 + BUTTON_W, 27]
    SPEED_GROUP = "Game Speed"   # Global's actions the Speed-Up section lists instead

    SECTIONS = [[:global, "Global", [96, 160, 232]], [:overworld, "Overworld", [90, 170, 100]],
                [:menus, "Menus", [130, 140, 155]], [:battle, "Battle", [210, 80, 80]],
                [:speed_up, "Speed-Up", [230, 180, 60]], [:feel, "Feel", [160, 110, 200]]].freeze
    SECTION_HELP = {
      :global    => "Buttons that work everywhere, like moving and the game's own buttons.",
      :overworld => "Buttons for walking around the map.",
      :menus     => "Buttons for menus and screens.",
      :battle    => "Buttons for battles.",
      :speed_up  => "How fast the game runs, and the buttons that change it.",
      :feel      => "How the controls feel: Button style, repeat speed, hold time, triggers and sticks."
    }.freeze

    attr_reader :entry

    def self.open
      return new.main
    end

    def initialize
      frame_init
      @section = 0
      @focus = :side
      @sel = 0
      @side = :keys
      @scroll = 0
      @query = nil
    end

    def main
      open_sprites
      refresh
      loop do
        Graphics.update
        Input.update
        update_frame
        break if handle_input == :close
      end
      return nil
    ensure
      dispose_sprites
    end

    # TextEntry (Search) draws through these.
    def entry=(state)
      @entry = state
    end

    def entry_changed
      refresh
    end

    def refresh
      draw_screen if @sprite && !@sprite.disposed?
    end

    def focus_list?
      return @focus == :list
    end

    private

    #--------------------------------------------------------------------------
    # What the list holds
    #--------------------------------------------------------------------------
    def section_id
      return SECTIONS[@section][0]
    end

    def empty_section?(i)
      return selectable(items_for(SECTIONS[i][0])).empty?
    end

    def matching
      words = @query.to_s.downcase.split(/\s+/)
      return C.actions.select do |a|
        next false if C::Splits.left_out?(a.id)
        hay = "#{a.name} #{a.description} #{C.area_name(a.area)} #{a.group}".downcase
        words.all? { |w| hay.include?(w) }
      end
    end

    # [[:head, label], [:cols, label] (a heading with the Keyboard and
    # Controller columns), [:row, action] or [:set, setting key], ...]
    def items
      return action_items(matching) if @query
      return items_for(section_id)
    end

    def items_for(id)
      case id
      when :feel then return setting_items(_INTL("Feel"), feel_keys)
      when :speed_up
        out = setting_items(_INTL("Game Speed"), speed_keys)
        buttons = speed_actions
        out << [:cols, _INTL("Buttons")] unless buttons.empty?
        return out + buttons.map { |a| [:row, a] }
      end
      list = C.actions(id).reject { |a| C::Splits.left_out?(a.id) }
      list = list.reject { |a| a.group == SPEED_GROUP } if id == :global
      return action_items(list)
    end

    def setting_items(head, keys)
      return [] if keys.empty?
      return [[:head, head]] + keys.map { |k| [:set, k] }
    end

    # Actions under their headings (headings in the order of their first
    # action)
    def action_items(list)
      groups = list.group_by { |a| [a.area, a.group] }
      order = groups.keys.sort_by { |area, g| [C::AREAS.index(area), groups[[area, g]].map(&:priority).min] }
      out = []
      order.each do |area, g|
        out << [:head, @query ? "#{C.area_name(area)} > #{_INTL(g)}" : _INTL(g)]
        groups[[area, g]].sort_by { |a| [a.priority, a.name] }.each { |a| out << [:row, a] }
      end
      return out
    end

    # The rows the cursor goes to (actions and settings)
    def selectable(list = items)
      return list.select { |k, _| k == :row || k == :set }
    end

    def actions_listed
      return items.select { |k, _| k == :row }.map { |_, a| a }
    end

    def feel_keys
      return C::FEEL.select { |k| Reloaded::Settings.definition(k) }
    end

    # Speed-Up's settings, while it's On
    def speed_keys
      return [] unless defined?(Reloaded::SpeedUp)
      return Reloaded::SpeedUp::KEYS.select { |k| Reloaded::Settings.visible?(k) }
    end

    def speed_actions
      return C.actions(:global).select { |a| a.group == SPEED_GROUP }.sort_by { |a| [a.priority, a.name] }
    end

    def count
      return selectable.length
    end

    def current_item
      list = selectable
      return list.empty? ? nil : list[@sel % list.length]
    end

    # The action picked, or nil on a setting
    def current
      it = current_item
      return it && it[0] == :row ? it[1] : nil
    end

    # The setting picked, or nil on an action
    def current_key
      it = current_item
      return it && it[0] == :set ? it[1] : nil
    end

    def side_name(side)
      return side == :keys ? _INTL("Keyboard") : _INTL("Controller")
    end

    def label(token)
      return C::Inputs.label(C.shown_input(token), Reloaded::Prompts.style)
    end

    #--------------------------------------------------------------------------
    # Input
    #--------------------------------------------------------------------------
    def handle_input
      return search if Input.trigger?(Input::JUMPUP) || Input.trigger?(Input::SPECIAL) || clicked?(*SEARCH_BOX)
      return layouts if Input.trigger?(Input::R) || clicked?(*right_box)
      handled, result = mouse_input
      return result if handled
      return side_input if @focus == :side
      return list_input
    end

    # The mouse: moving it over a section, an action's column or a Feel row
    # picks it (hover); a click opens a section's list, opens the editor of
    # the column under it, or opens a Feel value's dropdown (on either side
    # of the value, steps it);
    # a click on a hint does what the hint says. The wheel scrolls the list
    # (the cursor stays under the mouse) or, over the sections, moves between
    # them; a right click goes back. Returns [handled, result].
    def mouse_input
      pt = Reloaded::Pointer
      if pointer_hover && !@entry
        if (i = pt.hit(@side_hits))
          hover_section(i)
        elsif (k = pt.hit(@row_hits))
          hover_row(k, pt.pos.to_a[0].to_i)
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
      elsif (k = pt.hit(@row_hits))
        click_row(k, pt.pos.to_a[0].to_i)
      end
      return [true, nil]
    end

    # B, from the mouse or the hint line.
    def mouse_back
      if @focus == :list || @query
        pbPlayCancelSE
        @query = nil
        @focus = :side
        refresh
        return nil
      end
      pbPlayCloseMenuSE
      return :close
    end

    # The hint line's Open: the picked section's list.
    def mouse_open
      return pbPlayBuzzerSE if count == 0
      @focus = :list
      pbPlayDecisionSE
      refresh
      return nil
    end

    # The hint line's Column: the other column.
    def mouse_column
      @side = @side == :keys ? :pad : :keys
      pbPlayCursorSE
      refresh
      return nil
    end

    # The hint line's Change: the picked column's editor (a Feel value: a
    # step on).
    def mouse_change
      current_key ? change_setting(1, true) : edit(current, @side)
      return nil
    end

    def hover_section(i)
      return if @query || empty_section?(i)
      return if i == @section && @focus == :side
      @section = i
      @sel = 0
      @scroll = 0
      @focus = :side
      pbPlayCursorSE
      refresh
    end

    # A row (k: its place among the rows) at x: picks it, and the column
    # under the mouse.
    def hover_row(k, x)
      it = selectable[k]
      side = it && it[0] == :set ? @side : (x < PAD_X - 6 ? :keys : :pad)
      return if @focus == :list && @sel % [count, 1].max == k && @side == side
      @focus = :list
      @sel = k
      @side = side
      pbPlayCursorSE
      refresh
    end

    # A section: opens its list.
    def click_section(i)
      return pbPlayBuzzerSE if empty_section?(i)
      @query = nil
      if i != @section
        @section = i
        @sel = 0
        @scroll = 0
      end
      mouse_open
    end

    # A row: the column's editor; a setting: on its value (or its name),
    # its dropdown; on either side of the value, a step that way.
    def click_row(k, x)
      hover_row(k, x)
      key = current_key
      return edit(current, @side) unless key
      cx = @value_cx || VALUE_CX
      return setting_dropdown if x < cx - 70
      half = P.width(PF::TEXT, Reloaded::Settings.display(key).to_s) / 2 + 3
      return setting_dropdown if (x - cx).abs <= half
      change_setting(x < cx ? -1 : 1, true)
    end

    # The wheel over the list: the view scrolls a row, and the cursor goes
    # to the row now under the mouse (or stays in view).
    def wheel_scroll(dir)
      list = items
      rows = list.each_index.select { |i| list[i][0] == :row || list[i][0] == :set }
      return if rows.empty?
      ys = []
      y = 0
      list.each { |kind, _| ys << y; y += head?(kind) ? HEAD_H : ROW_H }
      y0 = list_top(list)
      avail = LIST_Y1 - 4 - y0
      return if y <= avail
      last = ys.find { |v| y - v <= avail } || 0
      to = dir > 0 ? (ys.find { |v| v > @scroll } || @scroll) : (ys.reverse.find { |v| v < @scroll } || 0)
      to = [[to, last].min, 0].max
      return if to == @scroll
      @scroll = to
      my = Reloaded::Pointer.pos.to_a[1].to_i
      under = rows.index { |i| top = y0 + ys[i] - to; my >= top && my < top + ROW_H }
      seen = rows.each_index.select { |k| ys[rows[k]] >= to && ys[rows[k]] + ROW_H - to <= avail }
      k = under || (seen.include?(@sel % rows.length) ? @sel % rows.length : (dir > 0 ? seen.first : seen.last))
      @sel = k if k
      @focus = :list
      refresh
    end

    def wheel_sections(dir)
      target = step_section(@section, dir)
      return unless target
      @section = target
      @sel = 0
      @scroll = 0
      @focus = :side
      pbPlayCursorSE
      refresh
    end

    def side_input
      if Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)
        dir = Input.repeat?(Input::DOWN) ? 1 : -1
        target = step_section(@section, dir)
        if target.nil?
          return nil unless fresh?(dir)
          target = step_section(dir < 0 ? SECTIONS.length : -1, dir)
        end
        return nil if target.nil? || target == @section
        @section = target
        @sel = 0
        @scroll = 0
        pbPlayCursorSE
        refresh
      elsif Input.trigger?(Input::RIGHT) || Input.trigger?(Input::USE)
        if count == 0
          pbPlayBuzzerSE
        else
          @focus = :list
          pbPlayDecisionSE
          refresh
        end
      elsif Input.trigger?(Input::BACK)
        if @query
          pbPlayCancelSE
          @query = nil
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
      while i >= 0 && i < SECTIONS.length
        return i unless empty_section?(i)
        i += dir
      end
      return nil
    end

    def list_input
      n = count
      if n == 0
        if Input.trigger?(Input::BACK)
          pbPlayCancelSE
          @query = nil
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
        dir = Input.repeat?(Input::RIGHT) ? 1 : -1
        if current_key
          change_setting(dir)
        elsif Input.trigger?(dir > 0 ? Input::RIGHT : Input::LEFT)
          @side = @side == :keys ? :pad : :keys
          pbPlayCursorSE
          refresh
        end
      elsif Input.trigger?(Input::USE)
        current_key ? setting_dropdown : edit(current, @side)
      elsif Input.trigger?(Input::ACTION)
        reset_current
      elsif Input.trigger?(Input::BACK)
        pbPlayCancelSE
        @query = nil if @query
        @focus = :side
        refresh
      end
      return nil
    end

    # Left/Right on a setting: a toggle flips, a choice or a number steps (a
    # fresh press goes round at the ends, a held one stops) over the locked
    # choices. A locked setting buzzes.
    def change_setting(dir, round = false)
      key = current_key
      return unless key
      d = Reloaded::Settings.definition(key)
      s = Reloaded::Settings
      fresh = round || Input.trigger?(dir > 0 ? Input::RIGHT : Input::LEFT)
      if s.locked?(key)
        pbPlayBuzzerSE if fresh
        return
      end
      if d[:type] == :toggle
        return pbPlayBuzzerSE unless s.set(key, !s.get(key))
      elsif d[:type] == :slider || d[:type] == :number
        values = number_values(d)
        i = values.index(s.get(key)).to_i + dir
        if i < 0 || i >= values.length
          return unless fresh
          i %= values.length
        end
        return unless s.set(key, values[i])
      else
        n = d[:values].length
        locks = s.locked_choices(key)
        target = s.get(key).to_i
        n.times do
          target += dir
          if target < 0 || target >= n
            return unless round || Input.trigger?(dir > 0 ? Input::RIGHT : Input::LEFT)
            target %= n
          end
          break unless locks.has_key?(target)
        end
        return if locks.has_key?(target) || target == s.get(key).to_i
        s.set(key, target)
      end
      pbPlayCursorSE
      refresh
    end

    # A on a setting: the dropdown of its values, under its value.
    def setting_dropdown
      key = current_key
      return unless key
      s = Reloaded::Settings
      return pbPlayBuzzerSE if s.locked?(key)
      anchor = (@value_boxes || [])[@sel % [count, 1].max]
      return change_setting(1, true) unless anchor
      values, cur = setting_choices(key)
      dd = Reloaded::Dropdown.new(values, cur, anchor, dropdown_bounds(LIST_X0, LIST_Y0, LIST_X1, LIST_Y1),
                                  :locked => s.locked_choices(key).keys)
      choice = run_dropdown(dd)
      return if choice.nil? || choice == cur
      d = s.definition(key)
      value = case d[:type]
              when :toggle then choice == 1
              when :slider, :number then number_values(d)[choice]
              else choice
              end
      s.set(key, value)
      refresh
    end

    # A setting's values as shown, and the current one's index (a toggle:
    # Off, On).
    def setting_choices(key)
      s = Reloaded::Settings
      d = s.definition(key)
      return [[s.display(key, false), s.display(key, true)], s.get(key) ? 1 : 0] if d[:type] == :toggle
      if d[:type] == :slider || d[:type] == :number
        values = number_values(d)
        return [values.map { |v| s.display(key, v) }, values.index(s.get(key)).to_i]
      end
      return [d[:values].each_index.map { |v| s.display(key, v) }, s.get(key).to_i]
    end

    # A slider's or number's values, min to max
    def number_values(d)
      return (d[:min].to_i..d[:max].to_i).step([d[:step].to_i, 1].max).to_a
    end

    # The Default button: the selected Feel setting, or the selected column
    # of an action.
    def reset_current
      if (key = current_key)
        s = Reloaded::Settings
        return pbPlayBuzzerSE unless s.changed?(key) && !s.locked?(key)
        s.reset(key)
      else
        a = current
        return pbPlayBuzzerSE unless a && C.customized?(a.id, @side)
        C.reset(a.id, @side)
      end
      pbPlayDecisionSE
      refresh
    end

    #--------------------------------------------------------------------------
    # Editing one column of one action
    #--------------------------------------------------------------------------
    def edit(a, side)
      return pbPlayBuzzerSE unless a
      pbPlayDecisionSE
      index = 0
      loop do
        list = C.bindings(a.id, side)
        rows = list.map { |t| [C.shown_input(t), _INTL("Remove")] }
        descs = list.map { _INTL("Takes this one off {1}.", a.name) }
        rows << [nil, side == :keys ? _INTL("Add a Key") : _INTL("Add a Button")]
        descs << _INTL("Press it next. Keep holding it to bind it as a Hold.")
        if C.customized?(a.id, side)
          rows << [nil, a.follows ? _INTL("Back to Default ({1})", C.action(a.follows).name) : _INTL("Back to Default")]
          descs << _INTL("Puts {1}'s {2} buttons back as they were.", a.name, side_name(side))
        end
        index = Reloaded::Dialogs.menu(self, "#{a.name}: #{side_name(side)}", rows, descs, [index, rows.length - 1].min)
        refresh
        return if index.nil?
        if index < list.length
          remove(a, side, list, list[index])
        elsif index == list.length
          token = capture(a, side)
          add(a, side, token) if token
        else
          C.reset(a.id, side)
        end
        refresh
      end
    end

    # Confirm, Back and the directions keep at least one key and one
    # controller input, so neither device can be locked out.
    def remove(a, side, list, token)
      return needs_one(a, side) if C::ESSENTIAL.include?(a.id) && (list - [token]).none? { |t| !C::Inputs.hold?(t) }
      C.bind(a.id, side, list - [token])
    end

    def needs_one(a, side)
      text = side == :keys ? _INTL("{1} needs at least one key.", a.name) : _INTL("{1} needs at least one button or stick.", a.name)
      Reloaded::Dialogs.notice(self, a.name, text)
    end

    # A new binding; one another action in the area has asks first.
    def add(a, side, token)
      current = C.bindings(a.id, side)
      return if current.include?(token)
      others = C.clashes_for(a.id, side, token)
      unless others.empty?
        o = others.first
        old = current.find { |t| !C::Inputs.hold?(t) }      # what Swap gives the other one
        what = side == :keys ? _INTL("key") : _INTL("button")
        text = _INTL("{1} is already {2} ({3}).", label(token), o.name, C.area_name(o.area))
        c = palette
        swap = old ? _INTL(" gives {1} the {2} {3}. ", o.name, label(old), what) : _INTL(" takes it from {1}. ", o.name)
        segments = [[_INTL("Swap"), c[:strong], true], [swap, c[:dim]],
                    [_INTL("Keep Both"), c[:strong], true], [_INTL(" lets {1} do both.", label(token)), c[:dim]]]
        k = Reloaded::Dialogs.ask(self, "#{a.name}: #{side_name(side)}", text, segments,
                                  [_INTL("Swap"), _INTL("Keep Both"), _INTL("Cancel")], 0)
        refresh
        return if k.nil? || k == 2
        if k == 0
          theirs = C.bindings(o.id, side) - [token]
          theirs << old if old && !theirs.include?(old)
          return needs_one(o, side) if C::ESSENTIAL.include?(o.id) && theirs.none? { |t| !C::Inputs.hold?(t) }
          C.bind(o.id, side, theirs)
          current -= [old] if old
        end
      end
      C.bind(a.id, side, current + [token])
    end

    # "Press a Button": the next key or button pressed (held for Hold Time,
    # a hold), or nil when nothing is pressed before the bar runs out.
    def capture(a, side)
      c = palette
      title = "#{a.name}: #{side_name(side)}"
      rest = [_INTL(". Keep holding it to bind it as a Hold."), c[:dim]]
      segments = if side == :keys
                   [[_INTL("Press a Key"), c[:strong], true], rest]
                 else
                   [[_INTL("Press a Button"), c[:strong], true], [" " + _INTL("or") + " ", c[:dim]],
                    [_INTL("Move a Stick"), c[:strong], true], rest]
                 end
      layer = C::Layer
      hold_steps = C.hold_steps
      released = false       # first, the press that opened this has to be let go
      held = nil
      steps = 0
      left = CAPTURE_STEPS
      note = nil
      loop do
        bar = held ? steps.to_f / hold_steps : left.to_f / CAPTURE_STEPS
        draw_capture(c, title, segments, bar, note)
        Graphics.update
        Input.update
        update_frame
        down = layer.pressed_inputs(side)
        unless released
          released = down.empty?
          left -= 1
          return nil if left <= 0
          next
        end
        if held
          return held unless down.include?(held)
          steps += 1
          return C::Inputs.hold(held) if steps >= hold_steps
          next
        end
        fresh = down.find { |t| !C::Inputs.reserved?(t) }
        if fresh
          held = fresh
          steps = 0
        else
          note = _INTL("{1} is the game's own key.", label(down.first)) if down.any? { |t| C::Inputs.reserved?(t) }
          left -= 1
          return nil if left <= 0
        end
      end
    ensure
      wait_release(side)
      overlay.clear if @overlay_sprite && !@overlay_sprite.disposed?
    end

    # Waits until the captured input is let go, so it doesn't press anything.
    def wait_release(side)
      60.times do
        break if C::Layer.pressed_inputs(side).empty?
        Graphics.update
        Input.update
        update_frame
      end
    end

    def draw_capture(c, title, segments, bar, note)
      b = overlay
      b.clear
      b.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 120))
      w = 300
      lines = Bitmap.new(w, 200)
      n = P.small_rich(lines, 0, 0, w - 32, 18, segments)
      lines.dispose
      h = 50 + n * 18 + 22 + (note ? 18 : 0)
      x = (W - w) / 2
      y = (H - h) / 2
      Reloaded::Dialogs.send(:panel, b, c, x, y, w, h)
      Reloaded::Dialogs.send(:title_bar, b, c, x, y, w, title)
      P.small_rich(b, x + 16, y + 42, w - 32, 18, segments)
      by = y + 48 + n * 18
      P.small(b, x, by - 4, w, 18, note, c[:warn], 2) if note
      by += 18 if note
      P.ui.rbox(b, x + 40, by, x + w - 40, by + 4, 2, c[:dark])
      fill = (x + 40 + (w - 80) * [[bar, 0].max, 1].min).round
      P.ui.rbox(b, x + 40, by, fill, by + 4, 2, c[:selb]) if fill > x + 41
    end

    #--------------------------------------------------------------------------
    # Search and Layouts
    #--------------------------------------------------------------------------
    def search
      pbPlayDecisionSE
      text, _how = run_entry(:search, _INTL("Type to Search"), @query || "", 30,
                             :prompt => _INTL("Search Controls"), :down => true) do |t|
        @query = t.strip.empty? ? nil : t.strip
        @sel = 0
        @scroll = 0
      end
      @query = text.to_s.strip.empty? ? nil : text.strip
      @sel = 0
      @scroll = 0
      @focus = @query && count > 0 ? :list : :side
      refresh
      return nil
    end

    # Typing in the title bar: Search, or a layout's name.
    def run_entry(kind, label, initial, max, prompt: nil, down: false, &on_change)
      @entry_kind = kind
      return Reloaded::TextEntry.run(self, label, initial, max, :prompt => prompt, :down => down, &on_change)
    ensure
      @entry_kind = nil
    end

    #--------------------------------------------------------------------------
    # Layouts: the built-in ones, the player's own, and the resets
    #--------------------------------------------------------------------------
    def layouts
      pbPlayDecisionSE
      index = 0
      loop do
        name = _INTL(SECTIONS[@section][1])
        rows = []
        descs = []
        picks = []
        add = proc { |label, desc, pick| rows << label; descs << desc; picks << pick }
        add.call(_INTL("Game's Layout (F1)"), _INTL("Every action back on your F1 keys and buttons. Feel stays as it is."), [:game])
        add.call(_INTL("Pokémon-Style"),
                 _INTL("B runs, X or Start opens the menu, Y the Ready Menu, RT speeds up. Your keys stay."),
                 [:pokemon])
        L.list.each_with_index do |l, i|
          add.call(l["name"], _INTL("Your layout: Load it, save over it, rename it or share it."), [:mine, i])
        end
        add.call(_INTL("Save as New Layout"), _INTL("Keep your controls and Feel as a layout of your own."), [:new]) unless L.full?
        add.call(_INTL("Paste Share Code"), _INTL("Add a layout someone copied for you."), [:paste])
        reset_text = case section_id
                     when :feel then _INTL("Puts the Feel settings back to their defaults.")
                     when :speed_up then _INTL("Puts the Speed-Up settings and buttons back to their defaults.")
                     else _INTL("Puts every action in {1} back to its default.", name)
                     end
        add.call(_INTL("Reset Section ({1})", name), reset_text, [:section])
        add.call(_INTL("Reset All to Default"), _INTL("Every action and setting here back to its default."), [:all])
        add.call(_INTL("Cancel"), _INTL("Back to the controls."), [:cancel])
        index = Reloaded::Dialogs.menu(self, _INTL("Layouts"), rows, descs, index)
        refresh
        return nil if index.nil?
        pick, i = picks[index]
        case pick
        when :cancel then return nil
        when :mine   then return nil if my_layout(i) == :loaded
        when :new    then new_layout
        when :paste  then paste_layout
        else
          reset_layout(pick, rows[index], name)
          return nil
        end
      end
    end

    def reset_layout(pick, title, name)
      question = { :game    => _INTL("Put every action back on your F1 layout?"),
                   :pokemon => _INTL("Put the controller on Pokémon-Style? Your keys stay as they are, and holding Select quicksaves."),
                   :section => _INTL("Reset everything in {1}?", name),
                   :all     => _INTL("Reset every action and setting here?") }[pick]
      yes = pick == :pokemon ? _INTL("Use It") : _INTL("Reset")
      return refresh unless Reloaded::Dialogs.confirm(self, title, question, yes, _INTL("Cancel"), false)
      case pick
      when :game    then C.reset_all
      when :pokemon then L.pokemon_style
      when :section then reset_section
      when :all
        C.reset_all
        reset_feel
        reset_speed
      end
      refresh
    end

    # Reset Section: the actions listed, and the section's settings
    def reset_section
      case section_id
      when :feel then return reset_feel
      when :speed_up
        reset_speed
        speed_actions.each { |a| C.reset(a.id) }
      else
        selectable(items_for(section_id)).each { |_k, a| C.reset(a.id) }
      end
    end

    def reset_feel
      feel_keys.each { |k| Reloaded::Settings.reset(k) }
    end

    # Speed-Up's settings, the other type's locked ones too (the type first)
    def reset_speed
      s = Reloaded::Settings
      speed_keys.each { |k| s.set(k, s.default(k), true) }
    end

    # One of the player's layouts: :loaded when it was put on.
    def my_layout(i)
      name = L.list[i]["name"]
      actions = [[:load, _INTL("Load"), _INTL("Replace your controls and Feel with this layout.")],
                 [:save, _INTL("Save Over"), _INTL("Keep your controls and Feel as they are now in this layout.")],
                 [:rename, _INTL("Rename"), _INTL("Give this layout a new name.")],
                 [:copy, _INTL("Copy Share Code"), _INTL("Copy this layout as text, to paste into Layouts in another game.")],
                 [:delete, _INTL("Delete"), _INTL("Remove this layout.")],
                 [:cancel, _INTL("Cancel"), _INTL("Back to the layouts.")]]
      k = Reloaded::Dialogs.menu(self, name, actions.map { |a| a[1] }, actions.map { |a| a[2] })
      refresh
      return nil if k.nil?
      d = Reloaded::Dialogs
      case actions[k][0]
      when :load
        return nil unless d.confirm(self, name, _INTL("Replace your controls and Feel with {1}?", name), _INTL("Load"), _INTL("Cancel"), false)
        ok = L.load(i)
        refresh
        d.notice(self, name, ok ? _INTL("Loaded {1}.", name) : _INTL("The layout couldn't be loaded."))
        return :loaded if ok
      when :save
        return nil unless d.confirm(self, name, _INTL("Save your controls and Feel over {1}?", name), _INTL("Save"), _INTL("Cancel"), false)
        d.notice(self, name, L.save_over(i) ? _INTL("Your controls and Feel are now in {1}.", name) : _INTL("The layout couldn't be saved."))
      when :rename
        text, how = run_entry(:name, _INTL("Type a Name"), name, L::NAME_MAX, :prompt => _INTL("Layout Name?"))
        L.rename(i, text) if how == :enter && !text.to_s.strip.empty?
      when :copy
        code = L.share_code(i)
        ok = code && Reloaded::ShareCodes.copy(code)
        d.notice(self, name, ok ? _INTL("{1}'s share code is copied. Paste it into Layouts in any game.", name)
                                : _INTL("The share code couldn't be copied."))
      when :delete
        return nil unless d.confirm(self, name, _INTL("Delete {1}? Its controls will be gone.", name), _INTL("Delete"), _INTL("Cancel"), false)
        L.delete(i)
      end
      refresh
      return nil
    end

    def new_layout
      text, how = run_entry(:name, _INTL("Type a Name"), L.next_name, L::NAME_MAX, :prompt => _INTL("Layout Name?"))
      refresh
      return if how != :enter || text.to_s.strip.empty?
      ok = L.add(text)
      name = ok ? L.list.last["name"] : text.strip
      Reloaded::Dialogs.notice(self, name, ok ? _INTL("Your controls and Feel are saved as {1}.", name)
                                              : _INTL("The layout couldn't be saved."))
      refresh
    end

    def paste_layout
      d = Reloaded::Dialogs
      title = _INTL("Paste Share Code")
      layout = L.read_code(Reloaded::ShareCodes.clipboard)
      if layout.nil?
        d.notice(self, title, _INTL("The clipboard doesn't hold a layout's share code. Copy one first."))
      elsif L.full?
        d.notice(self, title, _INTL("You have {1} layouts already. Delete one first.", L::MAX))
      elsif L.add_layout(layout)
        d.notice(self, title, _INTL("{1} is in your layouts. Load it to use it.", L.list.last["name"]))
      else
        d.notice(self, title, _INTL("The layout couldn't be saved."))
      end
      refresh
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
          n = actions_listed.length
          P.small(top, W - 120, 4, 100, 23, n == 1 ? _INTL("1 Found") : _INTL("{1} Found", n), c[:dim], 1)
        end
        return
      end
      P.text(top, 0, 2, W, 28, _INTL("Controls"), c[:title], PF::TITLE, 2)
      title_box(base, top, c, 8, @query || _INTL("Search"), :search => true, :active => !@query.nil?)
      title_box(base, top, c, W - 8 - BUTTON_W, _INTL("Layouts"))
      title_keys(top, c, left_key, right_key)
    end

    def paint_sidebar(base, top, c)
      P.ui.rbox(base, 6, 36, SIDE_X1, LIST_Y1, 6, c[:panel])
      found = {}
      matching.each { |a| found[a.area] = true } if @query
      faded = Reloaded::Palette.mix(c[:dim], c[:panel], 0.45)
      y = 40
      @side_hits = []                              # for the mouse
      SECTIONS.each_with_index do |(id, name, rgb), i|
        @side_hits << [i, 9, y - 1, SIDE_X1 - 3, y + 18]
        active = i == @section && !@query
        @cursor_rect = [9, y - 1, SIDE_X1 - 3 - 9 + 1, 20] if active && @focus == :side && !@entry
        name = _INTL(name)
        P.ui.rbox(top, 14, y + 2, 28, y + 16, 3, Color.new(*rgb))
        P.glyph(top, 14, y + 2, 15, 15, name[0], TILE_TEXT)
        dim = @query ? !found[id] : empty_section?(i)
        P.text(top, 33, y + 2, SIDE_X1 - 37, 15, name, active ? c[:strong] : (dim ? faded : c[:dim]))
        y += 20
      end
    end

    def head?(kind)
      return kind == :head || kind == :cols
    end

    # Where the list's rows start: under the Keyboard and Controller labels
    # when it's all actions (a list with settings labels its Buttons
    # heading instead)
    def list_top(list)
      return LIST_Y0 + 4 if list.any? { |k, _| k == :set || k == :cols }
      return LIST_Y0 + 4 + COLS_H
    end

    def paint_list(base, top, c)
      P.ui.rbox(base, LIST_X0, LIST_Y0, LIST_X1, LIST_Y1, 6, c[:panel])
      @row_hits = []
      @value_boxes = []                # where each setting's dropdown drops from
      list = items
      if list.empty?
        msg = @query ? _INTL("Nothing matches \"{1}\".", @query) : _INTL("Nothing here yet.")
        P.text(top, LIST_X0 + 12, LIST_Y0 + 8, LIST_X1 - LIST_X0 - 24, 22, msg, c[:dim])
        return
      end
      y0 = list_top(list)
      if y0 > LIST_Y0 + 4
        P.text(top, KEY_X, LIST_Y0 + 4, 90, 13, _INTL("KEYBOARD"), c[:dim], PF::TINY)
        P.text(top, PAD_X, LIST_Y0 + 4, 90, 13, _INTL("CONTROLLER"), c[:dim], PF::TINY)
      end
      @value_cx = value_column(list)
      ys = []
      y = 0
      list.each { |k, _| ys << y; y += head?(k) ? HEAD_H : ROW_H }
      total = y
      rows = list.each_index.select { |i| !head?(list[i][0]) }
      si = rows[@sel % [rows.length, 1].max]
      avail = LIST_Y1 - 4 - y0
      if si
        top_needed = (si > 0 && head?(list[si - 1][0])) ? ys[si - 1] : ys[si]
        @scroll = top_needed if top_needed < @scroll
        @scroll = ys[si] + ROW_H - avail if ys[si] + ROW_H - @scroll > avail
      end
      list.each_with_index do |(kind, what), i|
        h = head?(kind) ? HEAD_H : ROW_H
        next if ys[i] < @scroll || ys[i] + h - @scroll > avail
        ry = y0 + ys[i] - @scroll
        case kind
        when :head
          P.heading(top, LIST_X0 + 10, LIST_X1 - 10, ry + 3, what, c[:head], c[:line])
        when :cols
          P.heading(top, LIST_X0 + 10, KEY_X - 10, ry + 3, what, c[:head], c[:line])
          P.text(top, KEY_X, ry + 3, 90, 13, _INTL("KEYBOARD"), c[:dim], PF::TINY)
          P.text(top, PAD_X, ry + 3, 90, 13, _INTL("CONTROLLER"), c[:dim], PF::TINY)
        else
          k = rows.index(i)
          @row_hits << [k, LIST_X0 + 4, ry, LIST_X1 - 8, ry + ROW_H - 1]
          selected = i == si && @focus == :list && !@entry
          if kind == :row
            paint_action(top, c, what, ry, selected)
          else
            @value_boxes[k] = paint_setting(top, c, what, ry, selected)
          end
        end
      end
      return unless total > avail
      track = LIST_Y1 - LIST_Y0 - 12
      bar = [track * avail / total, 12].max
      pos = (track - bar) * @scroll / [total - avail, 1].max
      base.fill_rect(LIST_X1 - 5, LIST_Y0 + 6, 2, track, c[:line])
      base.fill_rect(LIST_X1 - 5, LIST_Y0 + 6 + pos, 2, bar, c[:dim])
    end

    def paint_action(top, c, a, y, selected)
      if selected
        @cursor_rect = [LIST_X0 + 4, y, (LIST_X1 - 8) - (LIST_X0 + 4) + 1, ROW_H - 1]
        cx0 = @side == :keys ? KEY_X - 5 : PAD_X - 5
        cx1 = @side == :keys ? PAD_X - 8 : LIST_X1 - 10
        P.ui.rbox(top, cx0, y + 1, cx1, y + ROW_H - 3, 4, c[:selb])
        P.ui.rbox(top, cx0 + 1, y + 2, cx1 - 1, y + ROW_H - 4, 3, Reloaded::Palette.mix(c[:panel], c[:sel], 0.6))
      end
      if C.customized?(a.id)
        dy = y + (ROW_H - 2) / 2 - 3
        P.ui.rrect(top, NAME_X - 11, dy, NAME_X - 6, dy + 5, 3, c[:dot])
      end
      P.text(top, NAME_X, y, KEY_X - NAME_X - 2, ROW_H - 2, PF.fit(PF::ROW, a.name, KEY_X - NAME_X - 2), c[:opt], PF::ROW)
      clash = C.clashes(a.id).map { |_, t| t }
      chips(top, c, KEY_X, PAD_X - 10, y + 3, C.bindings(a.id, :keys), clash)
      chips(top, c, PAD_X, LIST_X1 - 12, y + 3, C.bindings(a.id, :pad), clash)
    end

    # A column's bindings as icons; a clashing one underlined.
    def chips(top, c, x, x1, y, tokens, clash)
      style = Reloaded::Prompts.style
      shown = 0
      tokens.each do |t|
        icon = C.shown_input(t)
        w = Reloaded::ButtonIcons.width(icon, style, 18)
        break if x + w > x1 && shown > 0
        Reloaded::ButtonIcons.draw(top, x, y, icon, c, style, 18)
        top.fill_rect(x, y + 19, w, 2, c[:warn]) if clash.include?(t)
        x += w + 5
        shown += 1
      end
      if tokens.length > shown
        P.text(top, x, y, 20, 18, "...", c[:dim], PF::TINY)
      elsif tokens.empty?
        P.small(top, x, y, 90, 18, _INTL("Not Bound"), c[:dim])
      end
    end

    # A setting's row: its name, and its value with arrows round it (a
    # locked one dimmed, with a padlock). Returns where its dropdown drops
    # from.
    def paint_setting(top, c, key, y, selected)
      s = Reloaded::Settings
      cx = @value_cx
      locked = s.locked?(key)
      @cursor_rect = [LIST_X0 + 4, y, (LIST_X1 - 8) - (LIST_X0 + 4) + 1, ROW_H - 1] if selected
      if s.changed?(key)
        dy = y + (ROW_H - 2) / 2 - 3
        P.ui.rrect(top, NAME_X - 11, dy, NAME_X - 6, dy + 5, 3, c[:dot])
      end
      P.text(top, NAME_X, y, 200, ROW_H - 2, _INTL(s.definition(key)[:name]), locked ? c[:dim] : c[:opt], PF::ROW)
      v = s.display(key).to_s
      vw = P.width(PF::TEXT, v)
      # (while a dropdown is open, a value it would cut through isn't drawn)
      unless @dropdown && @dropdown.covers?(cx - vw / 2 - 14, y + 4, cx + vw / 2 + 10, y + ROW_H - 5)
        P.text(top, cx - vw / 2, y, vw + 2, ROW_H - 2, v, locked ? c[:dim] : c[:opt])
        if locked
          padlock(top, cx + vw / 2 + 6, y + 6, c[:dim])
        else
          arrow = selected ? c[:txt] : c[:dim]
          P.ui.tri(top, cx - vw / 2 - 14, y + 7, :l, arrow, 4)
          P.ui.tri(top, cx + vw / 2 + 6, y + 7, :r, arrow, 4)
        end
      end
      return [cx - vw / 2 - 14, y, cx + vw / 2 + 10, y + ROW_H - 2]
    end

    # The settings' value column, as KIF Settings lines its values up: left
    # only as far as the widest value needs.
    def value_column(list)
      s = Reloaded::Settings
      list.select { |k, _| k == :set }.map do |_k, key|
        d = s.definition(key)
        values = case d[:type]
                 when :toggle then [true, false]
                 when :slider, :number then number_values(d)
                 else (d[:values] || []).each_index.to_a
                 end
        value_centre(values.map { |v| P.width(PF::TEXT, s.display(key, v).to_s) }.max.to_i)
      end.min || VALUE_CX
    end

    def paint_description(base, top, c)
      y0 = LIST_Y1 + 4
      description_box(base, c, y0)
      if @focus == :side && !@query
        id = section_id
        P.text(top, 14, y0 + 1, 330, 26, _INTL(SECTIONS[@section][1]), c[:head], PF::ROW)
        paint_lines(top, c, y0, P.small_wrap(top, _INTL(SECTION_HELP[id]), W - 30).first(DESC_LINES))
        return
      end
      if (key = current_key)
        s = Reloaded::Settings
        d = s.definition(key)
        title = @dropdown ? @dropdown.values[@dropdown.index] : _INTL(d[:name])   # the highlighted choice
        P.text(top, 14, y0 + 1, 330, 26, title, c[:head], PF::ROW)
        x = W - 14
        x -= P.pill(top, x, y0 + 7, _INTL("ALL SAVES"), c[:pill], c[:txt]) + 6
        dv = s.display(key, d[:default]).to_s.upcase
        P.pill(top, x, y0 + 7, _INTL("DEFAULT: {1}", dv), c[:pill], c[:txt])
        text = _INTL(d[:description])
        text = Reloaded::KIFDropdowns.explain_setting(key, @dropdown.index, text) if @dropdown
        lines = P.small_wrap(top, text, W - 30)
        lock = s.lock_reason(key)
        if lock && !@dropdown
          paint_lines(top, c, y0, lines.first(DESC_LINES - 1))
          P.small(top, 14, y0 + 28 + [lines.length, DESC_LINES - 1].min * DESC_DY, W - 34, DESC_DY,
                  _INTL("Locked: {1}.", lock), c[:dim])
        else
          paint_lines(top, c, y0, lines.first(DESC_LINES))
        end
        return
      end
      a = current
      return unless a
      P.text(top, 14, y0 + 1, 330, 26, PF.fit(PF::ROW, a.name, 300), c[:head], PF::ROW)
      x = W - 14
      x -= P.pill(top, x, y0 + 7, C.area_name(a.area).upcase, c[:pill], c[:txt]) + 6
      if a.follows && !C.customized?(a.id, @side)
        P.pill(top, x, y0 + 7, _INTL("ON {1}", C.action(a.follows).name.upcase), c[:pill], c[:txt])
      end
      lines = P.small_wrap(top, _INTL(a.description), W - 30)
      # the features that follow it (on this column)
      followers = C.actions.select { |f| f.follows == a.id && !C.customized?(f.id, @side) }.map(&:name)
      unless followers.empty?
        text = followers.length == 1 ? _INTL("{1} follows it.", followers[0]) : _INTL("{1} follow it.", names_list(followers))
        lines += P.small_wrap(top, text, W - 30)
      end
      clash = C.clashes(a.id).find { |_, t| C.bindings(a.id, @side).include?(t) }
      if clash
        o, t = clash
        paint_lines(top, c, y0, lines.first(DESC_LINES - 1))
        warn = _INTL("{1} is also {2} ({3}): Both happen.", label(t), o.name, C.area_name(o.area))
        P.small(top, 14, y0 + 28 + (DESC_LINES - 1) * DESC_DY, W - 34, DESC_DY, warn, c[:warn])
      else
        paint_lines(top, c, y0, lines.first(DESC_LINES))
      end
    end

    # "A", "A and B", "A, B and C"
    def names_list(names)
      return names[0].to_s if names.length < 2
      return _INTL("{1} and {2}", names[0..-2].join(", "), names[-1])
    end

    def hint_pairs
      pr = Reloaded::Prompts
      back = button(:B)
      if @entry
        search = @entry_kind == :search
        if pr.controller?
          return [[button(:C), _INTL("Type")], [:d, _INTL("Results")], [back, _INTL("Done")]] if search
          return [[button(:C), _INTL("Type")], [back, _INTL("Cancel")]]
        end
        enter = C::Inputs.key(40)
        esc = C::Inputs.key(41)
        return [[nil, _INTL("Type to Search")], [enter, _INTL("Results")], [esc, _INTL("Done")]] if search
        return [[nil, _INTL("Type a Name")], [enter, _INTL("Done")], [esc, _INTL("Cancel")]]
      end
      # a third part: what a click on the hint does
      return dropdown_hints if @dropdown
      if @focus == :side
        return [[:ud, _INTL("Section")], [:lr, _INTL("Open"), :mouse_open], [back, @query ? _INTL("Clear") : _INTL("Close"), :mouse_back]]
      end
      out = @query ? _INTL("Clear") : _INTL("Sections")
      if current_key
        return [[:ud, _INTL("Select")], [:lr, _INTL("Change"), :mouse_change], [button(:A), _INTL("Default"), :reset_current],
                [back, out, :mouse_back]]
      end
      return [[:ud, _INTL("Select")], [:lr, _INTL("Column"), :mouse_column], [button(:C), _INTL("Change"), :mouse_change],
              [button(:A), _INTL("Default"), :reset_current], [back, out, :mouse_back]]
    end
  end
end
