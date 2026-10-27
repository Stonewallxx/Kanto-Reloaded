#==============================================================================
# Kanto Reloaded: a section per feature in the improved settings screen
#==============================================================================
# His pick (2026-10-25): Kanto Reloaded's settings as a section per feature,
# folded out under Kanto Reloaded in the sidebar (the Indented Tree), in the
# order of Settings/Sections.rb. The panel shows only the chosen section:
# its headers (one per page, even a one-page section repeats its name) and
# their rows. A feature switched Off takes its section with it.
#
#   the Kanto Reloaded title   pinned at the top while its sections scroll;
#                              a stop of its own: A or Left folds them away
#                              (KIF's sections come close), A or Right opens
#                              them again
#   B in its sections          folds them too (his ask); B on the title, or
#                              on KIF's sections, closes as before
#   Search                     every Kanto Reloaded result names its section
#                              and header ("Reloaded Bag > Auto-Sort") with a
#                              small Poke Ball, folded or not
#
# Only this screen splits the rows: KIF's own screen (Reloaded Settings Off)
# keeps one list of headings. The rows themselves are KIF's, unchanged (the
# Overworld Menu finds a setting by its section and heading); only the
# headers are new ones, with the section's names.
#==============================================================================

return unless defined?(Reloaded::SettingsScreen)

module Reloaded
  class SettingsScreen
    module Sections
      KR = Reloaded::KIFBridge::SECTION
      SS = Reloaded::SettingsSections
      PF = ::KIF::PixelFont
      SIDE_Y0 = ::KifSettingsScreen::SIDE_Y0
      SIDE_DY = ::KifSettingsScreen::SIDE_DY

      def initialize(inloadscreen = false, start = nil)
        super
        # opened on Kanto Reloaded: its first section, not the title
        if section_id == KR && (k = @sections.index { |s| kr_sub?(s[0]) })
          @section = k
          @focus = :side
        end
      end

      def rebuild
        super
        kr_split
        kr_place if @sections
      end

      # A section's rows; the title has none (its sections are below it)
      def rows
        return @sub[:rows] if @sub
        return kr_query_rows if @query
        return [] if section_id == KR
        return super
      end

      # Opens on a heading's first row (KIFBridge.open_heading): in its
      # section. False when no section has it.
      def open_at_heading(heading)
        key = kr_key_of(heading)
        return false unless key
        @kr_open = true
        kr_place
        @section = @sections.index { |s| s[0] == key } || @section
        list = rows
        head = list.index { |x| x.kind == :head && x.heading.to_s == heading.to_s }
        k = head && opt_rows.index { |i| i > head }
        return false unless k
        @sel = k
        @scroll = 0
        @focus = :list
        return true
      end

      private

      #------------------------------------------------------------------------
      # The sections
      #------------------------------------------------------------------------
      def kr_sub?(id)
        return id.to_s.start_with?("kr.")
      end

      # Folded to start, then as it was left (his ask, 2026-10-25)
      def kr_open?
        if @kr_open.nil?
          @kr_open = kr_remember_fold? ? (Reloaded::Settings.get(Reloaded::KIFBridge::SECTION_OPEN) ? true : false) : true
        end
        return @kr_open
      end

      # Whether this screen keeps its folding for next time (Per-Save
      # Settings opens with them open and leaves it alone)
      def kr_remember_fold?
        return true
      end

      # Kanto Reloaded's rows, a list per section: KIF's rows as they are,
      # each page's under a header named for the section
      def kr_split
        all = @rows[KR] || []
        ids = {}
        Reloaded::Settings.pages(:general).each { |pg| ids[_INTL(pg[:name])] = pg[:id] }
        by_page = Hash.new { |h, k| h[k] = [] }
        all.each { |r| (pid = ids[r.heading.to_s]) && by_page[pid] << r }
        (@kr_list || []).each { |key, _name| @rows.delete(key) }
        @kr_list = []
        @kr_entries = {}
        SS.all.each do |entry|
          id, name, pages = entry
          key = :"kr.#{id}"
          out = []
          pages.each do |pid|
            rs = by_page[pid]
            next if rs.none? { |r| r.kind == :opt }
            rs.each do |r|
              out << (r.kind == :head ? ::KIF::SettingsScreen::Row.new(:head, nil, nil, SS.header(pid, r.label), key, r.heading, 0, nil, nil) : r)
            end
          end
          next if out.none? { |r| r.kind == :opt }
          @rows[key] = kr_chips(out)
          @kr_list << [key, _INTL(name)]
          @kr_entries[key] = entry
        end
      end

      # A feature's toggles in one chips group (their :chips) become one
      # row of chips (SettingsScreen::ChipsOption); a :range's two sliders
      # one two-handle bar, a :chip_pick choice a row of chips to pick
      # (SettingsRangeRows.rb)
      def kr_chips(list)
        @kr_chip_state ||= {}
        out = []
        ss = Reloaded::SettingsScreen
        list.each do |r|
          k = r.kind == :opt && r.opt.respond_to?(:kr_key) ? r.opt.kr_key : nil
          d = k ? Reloaded::Settings.definition(k) : nil
          group = d && d[:chips]
          last = out.last
          if d && d[:range] && defined?(ss::RangeOption)
            grp, which, name = d[:range]
            if which == :ceiling && last && last.opt.is_a?(ss::RangeOption) && last.opt.group == grp
              last.opt.ceiling = r.opt
            else
              label = _INTL((name || r.label).to_s)
              out << ::KIF::SettingsScreen::Row.new(:opt, ss::RangeOption.new(label, grp, r.opt, @kr_chip_state), r.scope, label,
                                                    r.section, r.heading, 0, nil, nil)
            end
          elsif d && d[:chip_pick] && defined?(ss::PickChipsOption)
            out << ::KIF::SettingsScreen::Row.new(:opt, ss::PickChipsOption.new(r.label, r.opt, @kr_chip_state), r.scope, r.label,
                                                  r.section, r.heading, 0, nil, nil)
          elsif group && last && last.opt.is_a?(Reloaded::SettingsScreen::ChipsOption) && last.opt.name == _INTL(group)
            last.opt.parts << r.opt
            last.opt.labels << _INTL(d[:chip] || r.label)
          elsif group
            chips = Reloaded::SettingsScreen::ChipsOption.new(_INTL(group), [r.opt], [_INTL(d[:chip] || r.label)], @kr_chip_state)
            out << ::KIF::SettingsScreen::Row.new(:opt, chips, r.scope, _INTL(group), r.section, r.heading, 0, nil, nil)
          else
            out << r
          end
        end
        return out
      end

      # The sidebar: the sections under the title while they're open (the
      # one chosen stays chosen; one that went, its feature Off, gives way
      # to the title)
      def kr_place
        current = @sections[@section] && @sections[@section][0]
        @sections.reject! { |s| kr_sub?(s[0]) }
        t = @sections.index { |s| s[0] == KR }
        if t && kr_open?
          col = @sections[t][2]
          @sections.insert(t + 1, *@kr_list.map { |key, name| [key, name, col] })
        end
        i = current && @sections.index { |s| s[0] == current }
        @section = i || t || [@section.to_i, @sections.length - 1].min
      end

      # The section a page's heading is in now
      def kr_key_of(heading)
        page = Reloaded::Settings.pages(:general).find { |pg| _INTL(pg[:name]) == heading.to_s }
        return nil unless page
        key = :"kr.#{SS.of_page(page[:id])}"
        return @kr_entries && @kr_entries[key] ? key : nil
      end

      # After a change, KIF puts the cursor back on the section at the same
      # place in the list; a section that came or went (DEBUG On brings the
      # Timing Profiler's) moves the rest, so it follows the section instead:
      # one that went (its feature switched Off in it) gives way to the title
      def after_change
        id = section_id
        super
        i = @sections.index { |s| s[0] == id }
        i ||= @sections.index { |s| s[0] == KR } if kr_sub?(id)
        return if i.nil? || i == @section
        @section = i
        @focus = :side unless (@rows[id] || []).any? { |r| r.kind == :opt }
        @sel = 0 if @sel >= [opt_rows.length, 1].max
        refresh
      end

      # Folds the sections away (or opens them); the cursor on the title
      def kr_fold(open)
        @kr_open = open
        Reloaded::Settings.set(Reloaded::KIFBridge::SECTION_OPEN, open ? true : false) if kr_remember_fold?
        kr_place
        @section = @sections.index { |s| s[0] == KR } || @section
        @sel = 0
        @scroll = 0
        @focus = :side
        open ? pbPlayDecisionSE : pbPlayCancelSE
        refresh
        return nil
      end

      #------------------------------------------------------------------------
      # Input
      #------------------------------------------------------------------------
      def side_input
        id = section_id
        if id == KR && !@query
          return kr_fold(!kr_open?) if Input.trigger?(Input::USE)
          if Input.trigger?(Input::LEFT)
            return kr_open? ? kr_fold(false) : pbPlayBuzzerSE
          elsif Input.trigger?(Input::RIGHT)
            return kr_fold(true) unless kr_open?
            @section += 1 if kr_sub?((@sections[@section + 1] || [])[0])   # into its first section
            pbPlayCursorSE
            refresh
            return nil
          end
        elsif kr_sub?(id) && !@query && Input.trigger?(Input::BACK)
          return kr_fold(false)                    # B in its sections folds them (his ask)
        end
        return super
      end

      def click_section(i)
        return super unless @sections[i] && @sections[i][0] == KR && !@query
        @section = i
        return kr_fold(!kr_open?)
      end

      def mouse_open
        return kr_fold(!kr_open?) if section_id == KR && !@query
        return super
      end

      def mouse_back
        return kr_fold(false) if @focus == :side && !@query && kr_sub?(section_id)
        return super
      end

      #------------------------------------------------------------------------
      # Go to Settings: the heading is in a section now
      #------------------------------------------------------------------------
      def go_to_settings
        r = current
        heading = goes_to(r)
        return pbPlayBuzzerSE unless heading
        key = kr_key_of(heading)
        return pbPlayBuzzerSE unless key
        back = { :key => r.opt.kr_key, :scroll => @query ? nil : @scroll, :section => section_id }
        self.query = nil if @query
        @sub = nil
        @kr_open = true
        kr_place
        @section = @sections.index { |s| s[0] == key } || @section
        list = rows
        head = list.index { |x| x.kind == :head && x.heading.to_s == heading }
        k = head && opt_rows.index { |i| i > head }
        return pbPlayBuzzerSE unless k
        @came_from = back
        @sel = k
        ys = []
        y = 0
        list.each { |x| ys << y; y += row_h(x) }
        avail = (LIST_Y1 - 4) - (LIST_Y0 + 4)
        @scroll = [ys[head], ys.find { |v| y - v <= avail } || 0].min       # no further than the list goes
        @focus = :list
        pbPlayDecisionSE
        refresh
        return nil
      end

      # B after Go to Settings: back on the switch, in its section
      def return_from_jump
        back = @came_from
        @came_from = nil
        return false unless back && back[:section] && !@query && !@sub
        i = @sections.index { |s| s[0] == back[:section] }
        return false unless i
        @section = i
        list = rows
        k = opt_rows.index { |li| list[li].opt.respond_to?(:kr_key) && list[li].opt.kr_key == back[:key] }
        return false unless k
        @sel = k
        @scroll = back[:scroll] if back[:scroll]
        return true
      end

      def jump_back?
        return @came_from && @came_from[:section] && !@query && !@sub ? true : false
      end

      #------------------------------------------------------------------------
      # Search: every section, folded or not
      #------------------------------------------------------------------------
      def kr_query_rows
        key = [@query, @rows.object_id]
        return @kr_query if @kr_qkey == key
        words = PF.utf8(@query).downcase.split(/\s+/)
        @kr_found = {}
        out = []
        places = []
        @sections.each do |id, label, _c|
          next if kr_sub?(id)
          if id == KR
            @kr_list.each { |k, name| places << [k, name, true] }
          else
            places << [id, label, false]
          end
        end
        places.each do |id, label, kr|
          found = (@rows[id] || []).select do |r|
            next false unless r.kind == :opt
            hay = PF.utf8("#{r.label} #{r.opt.name} #{desc_of(r.opt)}").downcase
            words.all? { |w| hay.include?(w) }
          end
          next if found.empty?
          @kr_found[id] = true if kr
          found.group_by(&:heading).each do |h, rs|
            title = if kr
                      pid = Reloaded::Settings.pages(:general).find { |pg| _INTL(pg[:name]) == h.to_s }
                      head = pid ? SS.header(pid[:id], h) : h.to_s
                      head == label ? label : "#{label} > #{head}"
                    else
                      h ? "#{label} > #{h}" : label
                    end
            out << ::KIF::SettingsScreen::Row.new(:head, nil, nil, kr ? "     " + title : title, id, h, 0, kr ? :kr_result : nil, nil)
            out.concat(rs)
          end
        end
        @kr_qkey = key
        return @kr_query = out
      end

      #------------------------------------------------------------------------
      # Drawing
      #------------------------------------------------------------------------
      # Search results: a small Poke Ball before Kanto Reloaded's
      def paint_list(base, top, c)
        super
        return unless @query && !@sub
        list = rows
        out, = layout_rows
        out.each { |i, y| P.poke_ball(top, LIST_X0 + 10, y + 3, 11) if list[i].kind == :head && list[i].mod == :kr_result }
      end

      # Which sections show: the chosen one in view; while Kanto Reloaded's
      # sections scroll under it, its title stays on top
      def side_slots(fit, t)
        n = @sections.length
        @side_scroll = @section - fit + 1 if @section >= @side_scroll + fit
        @side_scroll = @section if @section < @side_scroll
        @side_scroll = [[@side_scroll, n - fit].min, 0].max
        slots = (@side_scroll...[@side_scroll + fit, n].min).to_a
        return slots unless t && !slots.empty? && slots.first > t && kr_sub?(@sections[slots.first][0])
        if slots.first == @section            # it would be under the title: one up
          @side_scroll -= 1
          return side_slots(fit, t)
        end
        slots[0] = t
        return slots
      end

      def paint_sidebar(base, top, c)
        P.ui.rbox(base, 6, 36, SIDE_X1, LIST_Y1, 6, c[:panel])
        n = @sections.length
        fit = (LIST_Y1 - 4 - SIDE_Y0) / SIDE_DY
        t = @sections.index { |s| s[0] == KR }
        slots = side_slots(fit, t)
        scrolls = n > fit
        right = SIDE_X1 - (scrolls ? 8 : 3)
        found = {}
        rows.each { |r| found[r.section] = true if r.kind == :opt } if @query
        faded = Reloaded::Palette.mix(c[:dim], c[:panel], 0.45)
        last_sub = @sections.rindex { |s| kr_sub?(s[0]) }
        in_kr = kr_sub?(section_id)
        @side_hits = []
        y = SIDE_Y0
        slots.each do |i|
          id, label, col = @sections[i]
          edge = id == KR ? SIDE_X1 - 3 : right          # the title's row: no scroll bar beside it
          @side_hits << [i, 9, y - 1, edge, y + SIDE_DY - 2]
          active = i == @section && !@query
          @cursor_rect = [9, y - 1, edge - 9 + 1, SIDE_DY] if active && @focus == :side && !@entry
          name = PF.utf8(_INTL(label))
          if kr_sub?(id)
            # the list's own indent marks, from the Poke Ball down
            base.fill_rect(21, y - 3, 1, i == last_sub ? 12 : SIDE_DY, c[:line])
            base.fill_rect(21, y + 9, 6, 1, c[:line])
            dim = @query && !(@kr_found || {})[id]
            P.small(top, 30, y + 1, right - 33, 18, PF.utf8(SS.short(name)), active ? c[:strong] : (dim ? faded : c[:dim]))
          else
            own = Reloaded::Settings.group(id)
            if id == KR
              P.poke_ball(top, 14, y + 2, 15)      # Kanto Reloaded: a Poke Ball instead of a tile
            elsif own && own[:ball]
              P.poke_ball(top, 14, y + 2, 15, own[:ball])   # a group's own section: its ball (KR Debug's grey)
            elsif (icon = Reloaded::ModIcons.for(label))
              Reloaded::ModIcons.draw(top, 14, y + 2, icon)  # a mod's own ball (Reloaded::ModIcons)
            else
              P.ui.rbox(top, 14, y + 2, 28, y + 16, 3, Color.new(*col))
              P.glyph(top, 14, y + 2, 15, 15, name[0], TILE_TEXT)
            end
            dim = if @query then id == KR ? (@kr_found || {}).empty? : !found[id]
                  else id == KR ? false : empty_section?(i)
                  end
            colour = active || (id == KR && in_kr) ? c[:strong] : (dim ? faded : c[:dim])
            room = (id == KR ? SIDE_X1 - 3 : right) - 36        # the title: the scroll bar starts under it
            P.text(top, 33, y + 2, room, 15, PF.fit(PF::TEXT, name, room), colour)
          end
          y += SIDE_DY
        end
        return unless scrolls
        y0 = SIDE_Y0 + SIDE_DY                 # under the first row (the title, pinned or at the top)
        track = (fit - 1) * SIDE_DY - 6
        bar = [track * fit / n, 12].max
        pos = (track - bar) * @side_scroll / [n - fit, 1].max
        base.fill_rect(SIDE_X1 - 5, y0, 2, track, c[:line])
        base.fill_rect(SIDE_X1 - 5, y0 + pos, 2, bar, c[:dim])
      end

      # What the chosen section holds (the description box, in the sidebar)
      def section_help
        return super if @sub
        id = section_id
        return _INTL("Kanto Reloaded's settings, a section for each feature.") if id == KR
        return SS.description(@kr_entries[id]) if kr_sub?(id) && @kr_entries && @kr_entries[id]
        return super
      end

      def empty_message
        return super unless section_id == KR && !@query && !@sub
        return kr_open? ? _INTL("Its sections are below it.") : _INTL("Its sections are folded away.")
      end

      # The hint line in the sidebar: the title folds and opens; B in its
      # sections folds them
      def hint_pairs
        pairs = super
        return pairs unless @focus == :side && !@entry && !@dropdown && !@query
        back = button(:B)
        if section_id == KR
          return [[:ud, _INTL("Section")], [button(:C), kr_open? ? _INTL("Fold") : _INTL("Open"), :mouse_open],
                  [back, _INTL("Close"), :mouse_back]]
        end
        return pairs unless kr_sub?(section_id)
        return pairs.map { |p| p[0] == back ? [back, _INTL("Fold"), :mouse_back] : p }
      end
    end

    prepend Sections
  end
end
