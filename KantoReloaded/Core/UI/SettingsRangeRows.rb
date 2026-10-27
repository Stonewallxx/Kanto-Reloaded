# encoding: utf-8
#==============================================================================
# Kanto Reloaded: range bars and chip picks in the improved settings
#==============================================================================
# Two more row kinds for the improved screen (IV Boundaries' page, his pick
# Range Sliders, 2026-10-25). KIF's own screen, and search, keep the
# settings as they are: two sliders, a choice.
#
#   Range bar   a setting's :range => [group, :floor / :ceiling, name]: the
#               two sliders as one row, a two-handle bar with the range's
#               numbers at the value column. Left/Right move the lit end, Y
#               switches ends (a locked end can't be lit), A opens the
#               floor's :range_popup (screen, option): [floor, ceiling] or
#               nil. :range_shown (group) gives the numbers it shows
#   Chip pick   a choice's :chip_pick: its values as chips over the whole
#               row (no name), wrapping onto more lines; the value lit.
#               Left/Right move a cursor, A uses the chip under it (the
#               setting's :confirm may ask first); a locked one has a
#               padlock, and A on it says why (its reason, then
#               :locked_text)
#==============================================================================

return unless defined?(Reloaded::SettingsScreen)

module Reloaded
  class SettingsScreen
    class RangeOption
      attr_reader :name, :group, :floor
      attr_accessor :ceiling

      def initialize(name, group, floor, state)
        @name = name
        @group = group
        @floor = floor
        @ceiling = nil
        @state = state
      end

      def definition
        return Reloaded::Settings.definition(@floor.kr_key)
      end

      def floor_locked?
        return !Reloaded::Settings.lock_reason(@floor.kr_key).nil?
      end

      def ceiling_locked?
        return @ceiling.nil? || !Reloaded::Settings.lock_reason(@ceiling.kr_key).nil?
      end

      # The lit end (never a locked one while the other isn't)
      def which
        w = @state[@group] || :floor
        w = :ceiling if w == :floor && floor_locked? && !ceiling_locked?
        w = :floor if w == :ceiling && ceiling_locked? && !floor_locked?
        return w
      end

      def which=(w)
        @state[@group] = w
      end

      def part(w = which)
        return w == :ceiling && @ceiling ? @ceiling : @floor
      end

      # The lit end's setting answers for the row (its lock, its scope)
      def kr_key
        return part.kr_key
      end

      def title
        return part.name
      end

      def description
        return (KIF::SettingsScreen.description_for(part) rescue nil) || part.description
      end

      def min
        return definition[:min].to_i
      end

      def max
        return definition[:max].to_i
      end

      # [floor, ceiling] as the bar shows them
      def values
        shown = definition[:range_shown]
        return shown.call(@group) if shown
        lo = Reloaded::Settings.get(@floor.kr_key).to_i
        return [lo, @ceiling ? Reloaded::Settings.get(@ceiling.kr_key).to_i : max]
      end

      def changed?
        return [@floor, @ceiling].compact.any? { |o| Reloaded::Settings.changed?(o.kr_key) }
      end
    end

    class PickChipsOption
      attr_reader :name, :opt

      def initialize(name, opt, state)
        @name = name
        @opt = opt
        @state = state
      end

      def kr_key
        return @opt.kr_key
      end

      def values
        return @opt.values
      end

      def value
        return (@opt.get rescue 0).to_i
      end

      # The chip under the cursor (the value until it moves)
      def cursor
        c = @state[kr_key]
        return c.nil? ? value : c
      end

      def cursor=(i)
        @state[kr_key] = i
      end

      def reset_cursor
        @state.delete(kr_key)
      end

      def get
        return cursor
      end

      def title
        return ::KIF::PixelFont.utf8(values[cursor].to_s)
      end

      def description
        return Reloaded::Settings.choice_description(kr_key, cursor) || (KIF::SettingsScreen.description_for(@opt) rescue nil) || @opt.description
      end

      def locks
        return Reloaded::KIFDropdowns.locks(@opt)
      rescue StandardError
        return {}
      end

      def changed?
        return Reloaded::Settings.changed?(kr_key)
      end
    end

    module RangeRows
      PF = ::KIF::PixelFont                 # (KIF's screen's; a prepended module doesn't see its constants)
      ROW_H = ::KifSettingsScreen::ROW_H
      CHIP_H = 18
      CHIP_GAP = 4

      def value_kind(r)
        return :range if r.opt.is_a?(RangeOption)
        return :pick_chips if r.opt.is_a?(PickChipsOption)
        return super
      end

      # A chip pick spans the row, its name not drawn (as KIF's tab rows)
      def value_mode(r)
        return :tabs if r.opt.is_a?(PickChipsOption)
        return :range if r.opt.is_a?(RangeOption)
        return super
      end

      def row_h(r)
        return super unless r.kind == :opt && r.opt.is_a?(PickChipsOption)
        n = chip_lines(r.opt).length
        return n * CHIP_H + (n - 1) * CHIP_GAP + 6
      end

      def changed?(r)
        return r.opt.changed? if r.opt.is_a?(RangeOption) || r.opt.is_a?(PickChipsOption)
        return super
      end

      def value_hidden?(r, vy)
        return super unless r.opt.is_a?(RangeOption) || r.opt.is_a?(PickChipsOption)
        return @dropdown ? @dropdown.covers?(NAME_X, vy + 4, VAL_X1 + 10, vy + ROW_H - 5) : false
      end

      def paint_value(top, c, r, y, selected, kind)
        return paint_range(top, c, r, y, selected) if kind == :range
        return paint_pick_chips(top, c, r, y, selected) if kind == :pick_chips
        return super
      end

      #------------------------------------------------------------------------
      # Input
      #------------------------------------------------------------------------
      def change(dir, round = false)
        r = current
        o = r && r.opt
        return change_range(o, dir) if o.is_a?(RangeOption)
        return change_pick(o, dir, round) if o.is_a?(PickChipsOption)
        return super
      end

      def press
        r = current
        o = r && r.opt
        return press_range(o) if o.is_a?(RangeOption) && !@pick_mode
        return press_pick(o) if o.is_a?(PickChipsOption) && !@pick_mode
        return super
      end

      def press_x
        r = current
        return swap_end if r && r.opt.is_a?(RangeOption)
        return super
      end

      # Up/Down off a chip pick: its cursor goes back to the value
      def list_input
        before = current
        ret = super
        after = current
        before.opt.reset_cursor if before && !before.equal?(after) && before.opt.is_a?(PickChipsOption)
        return ret
      end

      def hint_pairs
        pairs = super
        r = current
        return pairs unless r && @focus == :list && !@dropdown && !@entry && !@pick_mode
        back = pairs.last
        if r.opt.is_a?(RangeOption)
          return [[:ud, _INTL("Select")], [:lr, _INTL("Move"), :mouse_change], [button(:X), _INTL("Floor / Ceiling"), :swap_end],
                  [button(:C), _INTL("Edit")], back]
        elsif r.opt.is_a?(PickChipsOption)
          return [[:ud, _INTL("Select")], [:lr, _INTL("Choose"), :mouse_change], [button(:C), _INTL("Use")], back]
        end
        return pairs
      end

      def change_range(o, dir)
        k = o.kr_key
        return pbPlayBuzzerSE if Reloaded::Settings.lock_reason(k)
        lo, hi = o.values
        v = (o.which == :ceiling ? hi : lo) + dir
        return if v < o.min || v > o.max
        return unless Reloaded::Settings.set(k, v)
        pbPlayCursorSE
        after_change
      end

      def swap_end(*_args)
        r = current
        o = r && r.opt
        return pbPlayBuzzerSE unless o.is_a?(RangeOption)
        other = o.which == :floor ? :ceiling : :floor
        return pbPlayBuzzerSE if other == :floor ? o.floor_locked? : o.ceiling_locked?
        o.which = other
        pbPlayCursorSE
        refresh
        return nil
      end

      def press_range(o)
        popup = o.definition[:range_popup]
        return pbPlayBuzzerSE unless popup
        pbPlayDecisionSE
        got = popup.call(self, o)
        refresh
        return unless got.is_a?(Array) && got.length == 2
        lo, hi = got.map(&:to_i).minmax
        s = Reloaded::Settings
        s.set(o.ceiling.kr_key, o.max) if o.ceiling && !o.ceiling_locked? && lo > o.values[1]
        s.set(o.floor.kr_key, lo) unless o.floor_locked?
        s.set(o.ceiling.kr_key, hi) if o.ceiling && !o.ceiling_locked?
        after_change
      end

      def change_pick(o, dir, round)
        n = o.values.length
        to = o.cursor + dir
        if to < 0 || to >= n
          return unless round || Input.trigger?(dir > 0 ? Input::RIGHT : Input::LEFT)
          to %= n
        end
        o.cursor = to
        pbPlayCursorSE
        refresh
      end

      def press_pick(o)
        i = o.cursor
        why = o.locks[i]
        if why
          pbPlayBuzzerSE
          d = kr_def(o)
          Reloaded::Dialogs.notice(self, PF.utf8(why.to_s), d && d[:locked_text] ? _INTL(d[:locked_text].to_s) : PF.utf8(why.to_s))
          refresh
          return
        end
        return pbPlayBuzzerSE if kr_lock(o)
        if i == o.value
          o.reset_cursor
          return refresh
        end
        changed = Reloaded::Settings.set(o.kr_key, i)
        o.reset_cursor
        changed ? (pbPlayDecisionSE; after_change) : refresh
      end

      #------------------------------------------------------------------------
      # Painting
      #------------------------------------------------------------------------
      # The chips in lines across the row: [[index, label, width], ...]
      def chip_lines(o)
        x0 = NAME_X - 2
        x1 = VAL_X1 + 6
        locks = o.locks
        lines = [[]]
        width = 0
        o.values.each_with_index do |name, i|
          label = PF.utf8(_INTL(name.to_s)).upcase
          w = PF.width(PF::TINY, label) + 12 + (locks.has_key?(i) ? 14 : 0)
          if width + w > x1 - x0 && !lines.last.empty?
            lines << []
            width = 0
          end
          lines.last << [i, label, w]
          width += w + 5
        end
        return lines
      end

      # The value lit (in the cursor's colours while the row is chosen, the
      # cursor's chip then); a locked one dim with a padlock
      def paint_pick_chips(top, c, r, y, selected)
        o = r.opt
        cur = selected ? o.cursor : o.value
        locks = o.locks
        chip_lines(o).each_with_index do |line, li|
          cx = NAME_X - 2
          cy = y + 3 + li * (CHIP_H + CHIP_GAP)
          line.each do |i, label, w|
            locked = locks.has_key?(i)
            on = i == cur
            fill = if on && selected then c[:selb]
                   elsif on then Reloaded::Palette.mix(c[:panel], c[:selb], c[:light] ? 0.22 : 0.30)
                   else c[:dark]
                   end
            P.ui.rbox(top, cx, cy, cx + w, cy + CHIP_H, 5, fill, on ? c[:selb] : c[:line])
            ink = if on && selected then c[:dark]
                  elsif locked then Reloaded::Palette.mix(c[:dim], c[:panel], 0.4)
                  elsif on then c[:txt]
                  else c[:dim]
                  end
            tx = cx
            if locked
              padlock(top, cx + 7, cy + 4, ink)
              tx += 12
            end
            P.text(top, tx, cy + 1, w - (tx - cx), CHIP_H - 1, label, ink, PF::TINY, 2)
            cx += w + 5
          end
        end
      end

      # The track on min..max, the range between the handles, the lit end's
      # handle in the cursor's colours; the numbers at the value column, a
      # padlock when the floor is locked
      def paint_range(top, c, r, y, selected)
        o = r.opt
        lo, hi = o.values
        cx = column(r)
        x0 = NAME_X + 64
        x1 = cx - 40
        span = [o.max - o.min, 1].max
        kx = ->(v) { x0 + ((v - o.min) * (x1 - x0) / span.to_f).round }
        P.ui.rbox(top, x0, y + 10, x1, y + 14, 2, c[:dark])
        P.ui.rbox(top, kx[lo], y + 10, kx[hi], y + 14, 2, selected ? c[:selb] : c[:segon])
        lit = selected ? o.which : nil
        floor_locked = o.floor_locked?
        [[hi, :ceiling], [lo, :floor]].each do |v, e|
          k = kx[v]
          if e == :floor && floor_locked
            P.ui.rbox(top, k - 4, y + 6, k + 4, y + 18, 3, c[:line])
          elsif lit == e
            P.ui.rbox(top, k - 5, y + 4, k + 5, y + 20, 3, c[:selb], c[:txt])
          else
            P.ui.rbox(top, k - 4, y + 6, k + 4, y + 18, 3, c[:txt])
          end
        end
        text = lo == hi ? lo.to_s : "#{lo}-#{hi}"
        tw = PF.width(PF::TEXT, text)
        P.text(top, cx - tw / 2, y, tw + 2, ROW_H - 2, text, c[:opt])
        padlock(top, cx + tw / 2 + 5, y + 7, c[:dim]) if floor_locked
      end
    end

    prepend RangeRows
  end
end
