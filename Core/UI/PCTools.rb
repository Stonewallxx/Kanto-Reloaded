# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Reloaded PC's box tools (Step 3)
#==============================================================================
# More of the PC scene (UI/PCScene.rb), his Step 3 picks (2026-10-24):
#
#   Sort           One Popup: Sort by (KIF's ways, A lists them all), Order
#                  (worded for the way: Highest First, A to Z), Boxes (This
#                  Box, Every Unlocked Box); Sort / Cancel. In place of KIF's
#                  Sort and Sort (All Boxes). KIF's own values (BST with
#                  fusions), ties keep their order, Eggs go last, the Pokémon
#                  are packed from the first place. A box locked for sorting
#                  is left alone, also on its own.
#   Box Overview   Mini Boxes, Three Across (his idea): A on the box name.
#                  Each box with its name, how full, its 30 places as dots in
#                  their Pokémon's type colours, shinies and Eggs, a padlock
#                  when locked; Buy Box last, its price green or red. A goes
#                  to the box; holding a Pokémon, A drops it in the box's
#                  first free place (its dot there in its colour, pulsing),
#                  through the game's own placing. Y picks a box up to move
#                  it (UI/PCBoxMove.rb).
#   Rename         In the Header: the box name becomes a field where it is;
#                  type straight in, a controller's A opens the naming
#                  screen, Down or Enter is done, B cancels.
#   Wallpaper      Grid Popup: the wallpapers five across instead of PIF's
#                  list of 200 names, the highlighted one's name under them,
#                  NOW on the box's own; it scrolls.
#==============================================================================

return unless defined?(Reloaded::PCScene)

module Reloaded
  module PC
    class << self
      # The last Sort chosen (way, highest / Z first, every unlocked box),
      # for the rest of the session
      attr_accessor :sort_choice
    end
  end

  module PCScene
    # KIF's ways (KIF::BoxSort::CRITERIA) as Kanto Reloaded names them; a
    # way a mod adds keeps its own name
    WAY_NAMES = {
      :speciesName => "Name", :name => "Nickname", :dexNum => "Dex Number", :level => "Level", :totalhp => "HP",
      :attack => "Attack", :defense => "Defense", :spatk => "Sp. Atk", :spdef => "Sp. Def", :speed => "Speed",
      :bst => "Base Stat Total", :timeReceived => "Caught Date", :shiny => "Shiny", :OT => "Original Trainer",
      :gender => "Gender", :ability => "Ability", :nature => "Nature", :item => "Held Item", :type1 => "First Type",
      :type2 => "Second Type", :obtain_map => "Where Caught", :happiness => "Happiness", :exp => "Experience",
      :markings => "Marks", :totalivs => "Total IVs", :totalevs => "Total EVs"
    }.freeze
    # Each way's order, worded for it: [low first, high first, high first by default]
    WORDS_AZ = ["A to Z", "Z to A", false].freeze
    WORDS_UP = ["Lowest First", "Highest First", true].freeze
    ORDER_WORDS = {
      :speciesName => WORDS_AZ, :name => WORDS_AZ, :OT => WORDS_AZ, :ability => WORDS_AZ, :nature => WORDS_AZ,
      :item => WORDS_AZ, :dexNum => ["Lowest First", "Highest First", false],
      :timeReceived => ["Oldest First", "Newest First", false], :shiny => ["Shiny Last", "Shiny First", true],
      :gender => ["Male First", "Male Last", false], :type1 => ["Type Order", "Reverse Type Order", false],
      :type2 => ["Type Order", "Reverse Type Order", false], :obtain_map => ["Map Order", "Reverse Map Order", false],
      :markings => ["Fewest First", "Most First", true]
    }.freeze
    SORT_W = 360
    SORT_ROW = 30
    SORT_NOTE = 3             # the note's lines (the popup keeps its size)
    # Box Overview: three across, four rows in view
    OV_COLS = 3
    OV_ROWS = 4
    OV_GAP = 8
    OV_TW = (W - 12 - OV_GAP * (OV_COLS - 1)) / OV_COLS
    OV_TH = 72
    OV_Y = 38
    OV_DOT_W = 13
    OV_DOT_H = 8
    # The wallpaper grid: five across, three rows in view
    WP_COLS = 5
    WP_ROWS = 3
    WP_TW = 76
    WP_TH = 57
    WP_GAP = 10
    WP_W = 470

    # TextEntry's field (Rename): what's typed so far, and its redraw
    def entry=(state)
      @kr_entry = state
    end

    def entry_changed
      refresh
    end

    private

    #--------------------------------------------------------------------------
    # Rename (his pick: In the Header)
    #--------------------------------------------------------------------------
    def rename_box(helptext, minchars, maxchars)
      hints = [[button(:C), _INTL("Type")], [:d, _INTL("Done")], [button(:B), _INTL("Cancel")]]
      text, how = with_popup_hints(hints) do
        Reloaded::TextEntry.run(self, _INTL("Type a Name"), box.name.to_s, maxchars, :prompt => helptext, :down => true)
      end
      box.name = text if how == :enter && text.length >= [minchars.to_i, 1].max
    end

    def draw_entry_field(base, top, c)
      Reloaded::TextEntry.draw_field(base, top, c, @kr_entry, (W - 220) / 2, 4, 220, 23, 10)
    end

    #--------------------------------------------------------------------------
    # Sort (his pick: One Popup)
    #--------------------------------------------------------------------------
    def sort_ways
      return [] unless defined?(::KIF::BoxSort)
      return ::KIF::BoxSort::CRITERIA.map do |label, attr|
        name = WAY_NAMES[attr] || label.to_s.sub(/\ASort by /, "")
        [attr, _INTL(name)]
      end
    end

    def order_words(attr)
      words = ORDER_WORDS[attr] || WORDS_UP
      return [_INTL(words[0]), _INTL(words[1]), words[2]]
    end

    # What a sort can take: this box, every unlocked one, and the picked ones
    # (Free Picks) when there are some here
    def sort_scopes
      return picks? ? [:this, :every, :picked] : [:this, :every]
    end

    # The boxes a sort takes: this one, or every one not locked for sorting
    # (a locked box is left alone, the picked ones in it too)
    def sort_boxes(scope)
      return ::KIF::BoxSort.sortable_boxes(@storage) if scope == :every
      b = box
      return [] if b.respond_to?(:sortlock?) && b.sortlock?
      return [@storage.currentBox]
    end

    def sort_count(scope)
      return 0 if sort_boxes(scope).empty?
      return picks_here.length if scope == :picked
      return sort_boxes(scope).sum { |j| @storage.maxPokemon(j).times.count { |k| @storage[j, k] } }
    end

    # start: the scope to open on (the picks' list opens it on them)
    def sort_popup(start = nil)
      ways = sort_ways
      return if ways.empty?
      last = Reloaded::PC.sort_choice
      way = last ? ways.index { |a, _n| a == last[0] } : nil
      way ||= ways.index { |a, _n| a == :level } || 0
      desc = last ? last[1] : order_words(ways[way][0])[2]
      scopes = sort_scopes
      every = start || (last && scopes.include?(last[2]) ? last[2] : :this)
      row = 0
      button_on = 0
      done = false
      hints = [[:ud, _INTL("Choose")], [:lr, _INTL("Change")], [button(:C), _INTL("Sort")], [button(:B), _INTL("Cancel")]]
      with_popup_hints(hints) do
        redraw = true
        loop do
          draw_sort(ways, way, desc, every, row, button_on) if redraw
          redraw = false
          Graphics.update
          Input.update
          update
          pt = Reloaded::Pointer
          hit = pt.hit(@kr_sort_hits || [])
          if pt.moved? && hit && hit != [row, button_on] && hit != row
            row, button_on = hit.is_a?(Array) ? hit : [hit, button_on]
            pbPlayCursorSE
            redraw = true
          end
          act = nil
          if pt.left? && hit
            row, button_on = hit.is_a?(Array) ? hit : [hit, button_on]
            act = row == 3 ? (button_on == 0 ? :sort : :cancel) : (row == 0 ? :list : :change)
          elsif pt.right? || Input.trigger?(Input::BACK)
            pbPlayCancelSE
            break
          elsif Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN)
            row = (row + (Input.repeat?(Input::UP) ? -1 : 1)) % 4
            pbPlayCursorSE
            redraw = true
          elsif Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)
            step = Input.repeat?(Input::LEFT) ? -1 : 1
            case row
            when 0
              way = (way + step) % ways.length
              desc = order_words(ways[way][0])[2]
            when 1 then desc = !desc
            when 2 then every = scopes[(scopes.index(every) + step) % scopes.length]
            else button_on = 1 - button_on
            end
            pbPlayCursorSE
            redraw = true
          elsif Input.trigger?(Input::USE)
            act = row == 0 ? :list : (row == 3 && button_on == 1 ? :cancel : :sort)
          end
          case act
          when :list
            pbPlayDecisionSE
            pick = Reloaded::Dialogs.picker(self, _INTL("Sort by"), ways.map { |_a, n| n }, way)
            if pick && pick != way
              way = pick
              desc = order_words(ways[way][0])[2]
            end
            redraw = true
          when :change
            pbPlayCursorSE
            row == 1 ? desc = !desc : every = scopes[(scopes.index(every) + 1) % scopes.length]
            redraw = true
          when :cancel
            pbPlayCancelSE
            break
          when :sort
            if sort_count(every) == 0
              pbPlayBuzzerSE
              redraw = true
              next
            end
            pbPlayDecisionSE
            Reloaded::PC.sort_choice = [ways[way][0], desc, every]
            every == :picked ? run_sort_picked(picks_here.sort, ways[way][0], desc) : run_sort(sort_boxes(every), ways[way][0], desc)
            done = ways[way][1]
            break
          end
        end
      end
      overlay.clear if @overlay_sprite && !@overlay_sprite.disposed?
      return unless done
      pbHardRefresh
      text = _INTL("Sorted by {1}", done)
      if defined?(Reloaded::Toast)
        Reloaded::Toast.show(text)
      else
        Reloaded::Dialogs.notice(self, _INTL("PC"), text)
      end
    end

    # KIF's values and tie rule; Eggs after the rest; packed from the first
    # place of the first box
    def run_sort(boxes, attr, desc)
      pokes = []
      boxes.each { |j| @storage.maxPokemon(j).times { |k| pokes << @storage[j, k] if @storage[j, k] } }
      sorted = sorted_pokemon(pokes, attr, desc)
      boxes.each { |j| @storage.maxPokemon(j).times { |k| @storage[j, k] = nil } }
      i = 0
      boxes.each do |j|
        @storage.maxPokemon(j).times do |k|
          break if i >= sorted.length
          @storage[j, k] = sorted[i]
          i += 1
        end
      end
    end

    # The picked ones sorted among their own places
    def run_sort_picked(slots, attr, desc)
      bx = @storage.currentBox
      sorted = sorted_pokemon(slots.map { |k| @storage[bx, k] }.compact, attr, desc)
      slots.each_with_index { |k, i| @storage[bx, k] = sorted[i] }
    end

    def sorted_pokemon(pokes, attr, desc)
      pairs = pokes.each_with_index.map { |p, i| [sort_value(p, attr), i] }
      pairs.sort! { |a, b| ::KIF::BoxSort.compare(a, b, desc) }
      sorted = pairs.map { |_v, i| pokes[i] }
      return sorted.reject { |p| p.egg? } + sorted.select { |p| p.egg? }
    end

    # Marks sort by how many are on (KIF's: the marks' bits as a number)
    def sort_value(p, attr)
      if attr == :markings
        bits = (p.markings rescue 0).to_i
        return [bits.to_s(2).count("1"), bits]
      end
      return ::KIF::BoxSort.value(p, attr)
    end

    # The line under the rows: the list's size on Sort by, else what Sort
    # will do (in red when it can't)
    def sort_note(c, count, every, row)
      return [_INTL("{1} ways: A shows them all.", count), c[:dim]] if row == 0
      return [_INTL("This box is locked for sorting."), c[:red]] if sort_boxes(every).empty?
      n = sort_count(every)
      return [_INTL("Nothing to sort."), c[:red]] if n == 0
      case every
      when :every then return [_INTL("{1} Pokémon, packed from the first unlocked box, Eggs last. Locked boxes stay as they are.", n), c[:dim]]
      when :picked then return [_INTL("{1} picked Pokémon, sorted in their own places, Eggs last.", n), c[:dim]]
      end
      return [_INTL("{1} Pokémon, packed from the first place, Eggs last.", n), c[:dim]]
    end

    def scope_words(scope)
      case scope
      when :every then return _INTL("Every Unlocked Box")
      when :picked then return _INTL("The Picked Ones")
      end
      return _INTL("This Box")
    end

    def draw_sort(ways, way, desc, every, row, button_on)
      b = overlay
      c = palette
      dg = Reloaded::Dialogs
      dg.send(:dim, b)
      w = SORT_W
      h = 40 + 3 * SORT_ROW + 8 + SORT_NOTE * 18 + 6 + 40
      x = (W - w) / 2
      y = (H - h) / 2
      dg.send(:panel, b, c, x, y, w, h)
      title = case every
              when :every then _INTL("Sort Your Boxes")
              when :picked then _INTL("Sort the Picked Ones")
              else _INTL("Sort {1}", box.name.to_s)
              end
      dg.send(:title_bar, b, c, x, y, w, title)
      attr = ways[way][0]
      lo, hi, = order_words(attr)
      values = [ways[way][1], desc ? hi : lo, scope_words(every)]
      keys = [_INTL("Sort by"), _INTL("Order"), _INTL("Boxes")]
      @kr_sort_hits = []
      3.times do |i|
        ry = y + 42 + i * SORT_ROW
        @kr_sort_hits << [i, x + 6, ry, x + w - 6, ry + 26]
        dg.send(:cursor_row, b, c, x + 6, ry, x + w - 6, ry + 26) if i == row
        P.text(b, x + 18, ry, 100, 26, keys[i], c[:dim])
        cx = x + w - 124
        v = PF.fit(PF::TEXT, values[i], 190)
        vw = P.width(PF::TEXT, v)
        P.text(b, cx - vw / 2, ry, vw + 2, 26, v, c[:opt])
        arrow = i == row ? c[:txt] : c[:dim]
        P.ui.tri(b, cx - vw / 2 - 14, ry + 9, :l, arrow, 4)
        P.ui.tri(b, cx + vw / 2 + 6, ry + 9, :r, arrow, 4)
      end
      ly = y + 42 + 3 * SORT_ROW + 4
      b.fill_rect(x + 10, ly, w - 20, 1, c[:line])
      note, ink = sort_note(c, ways.length, every, row)
      P.wrap(note, w - 28).first(SORT_NOTE).each_with_index { |line, i| P.text(b, x + 14, ly + 4 + i * 18, w - 28, 18, line, ink) }
      by = y + h - 36
      on = row == 3 ? button_on : 0
      [[_INTL("Sort"), x + 60, x + w / 2 - 6], [_INTL("Cancel"), x + w / 2 + 6, x + w - 60]].each_with_index do |(label, x0, x1), i|
        dg.send(:button, b, c, x0, by, x1, by + 26, i == on)
        P.text(b, x0, by, x1 - x0, 26, label, i == on ? c[:strong] : c[:opt], nil, 2)
        @kr_sort_hits << [[3, i], x0, by, x1, by + 26]
      end
    end

    #--------------------------------------------------------------------------
    # Box Overview (his pick: Mini Boxes, Three Across)
    #--------------------------------------------------------------------------
    # The boxes (the Transfer Box left out, as the game's Jump), then Buy Box
    # when KIF offers it
    def overview_tiles
      tiles = []
      @storage.maxBoxes.times do |i|
        b = @storage[i]
        next unless b
        next if defined?(::StorageTransferBox) && b.is_a?(::StorageTransferBox)
        tiles << i
      end
      tiles << :buy if buy_box_offered?
      return tiles
    end

    def buy_box_offered?
      return false unless defined?(::KIF::BoxSort) && defined?(::KIF::BoxCommands) && ::KIF::BoxSort.respond_to?(:buy_box)
      return ::KIF::BoxCommands.available(@screen).any? { |cmd, _l| cmd.id == :buybox }
    rescue StandardError
      return false
    end

    # KIF's price: 300 a box (the Transfer Box not counted), at most 100,000
    def buy_box_price
      normal = @storage.boxes.count { |b| !(defined?(::StorageTransferBox) && b.is_a?(::StorageTransferBox)) }
      price = [normal * 300, 100_000].min
      price = ::KIF::PCActions.price(price) if defined?(::KIF::PCActions) && ::KIF::PCActions.respond_to?(:price)
      return price
    end

    # A on the box name: what was chosen, as the game's loop takes it (the
    # place a held Pokémon drops into), or :stay. lift: the box you're in
    # comes up to move (Move Box, UI/PCBoxMove.rb).
    def box_overview(lift = false)
      tiles = overview_tiles
      sel = tiles.index(@storage.currentBox) || 0
      @kr_ov = { :tiles => tiles, :sel => sel, :top => 0, :page => :boxes }
      ov_scroll
      result = :stay
      lift ? ov_pick_up(true) : pbPlayDecisionSE
      refresh
      loop do
        Graphics.update
        Input.update
        update
        pt = Reloaded::Pointer
        tiles = @kr_ov[:tiles]
        moving = ov_moving
        hit = pt.hit(@kr_hits || [])
        if pt.moved? && hit.is_a?(Integer) && hit != @kr_ov[:sel]
          if moving
            ov_carry(hit)
          else
            @kr_ov[:sel] = hit
            pbPlayCursorSE
            refresh
          end
        end
        go = false
        if pt.left? && hit.is_a?(Integer) && !(moving && hit >= ov_count)
          moving ? ov_carry(hit) : @kr_ov[:sel] = hit
          go = true
        elsif pt.right? || Input.trigger?(Input::BACK)
          if moving
            ov_put_back
            break if moving[:once]
            next
          end
          pbPlayCancelSE
          break
        elsif moving
          # the box moves with the cursor (his pick: Lifted Tile)
          if (w = pt.wheel) != 0
            ov_move(w * OV_COLS, false)
          elsif Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)
            ov_move(Input.repeat?(Input::LEFT) ? -1 : 1, Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT))
          elsif Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN)
            ov_move(Input.repeat?(Input::UP) ? -OV_COLS : OV_COLS, Input.trigger?(Input::UP) || Input.trigger?(Input::DOWN))
          elsif Input.trigger?(Input::USE)
            go = true
          end
        elsif Input.trigger?(Input::X) && !drop_held?
          ov_pick_up                                  # Y: Move Box (UI/PCBoxMove.rb)
        elsif (Input.trigger?(Input::JUMPUP) || Input.trigger?(Input::JUMPDOWN)) && presets_offered?
          # LB / RB: the Party Presets page (his pick: A Page of Box Overview, UI/PCPresets.rb)
          break if presets_page == :close
          @kr_ov[:tiles] = overview_tiles
          refresh
        elsif (w = pt.wheel) != 0
          ov_move(w * OV_COLS, false)
        elsif Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)
          ov_move(Input.repeat?(Input::LEFT) ? -1 : 1, Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT))
        elsif Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN)
          ov_move(Input.repeat?(Input::UP) ? -OV_COLS : OV_COLS, Input.trigger?(Input::UP) || Input.trigger?(Input::DOWN))
        elsif Input.trigger?(Input::USE)
          go = true
        end
        next unless go
        if moving
          ov_put_down
          break if moving[:once]
          next
        end
        tile = tiles[@kr_ov[:sel]]
        if tile == :buy
          pbPlayDecisionSE
          before = @storage.maxBoxes
          ::KIF::BoxSort.buy_box(@screen)
          @kr_ov[:tiles] = overview_tiles
          if @storage.maxBoxes > before
            # the new box goes after the last one (before the Transfer Box)
            @kr_ov[:sel] = @kr_ov[:tiles].rindex { |t| t != :buy } || 0
          end
          ov_scroll
          refresh
          next
        end
        if drop_held? && !multi_held.empty?
          spots = landing_spots(tile, 0, multi_held.length)
          if spots.length < multi_held.length
            pbPlayBuzzerSE
            next
          end
          show_box(tile)
          drop_all_in(tile)
          @kr_focus = [:box, spots[0]]
          @selection = spots[0]
          break
        end
        if drop_held?
          free = (0...@storage.maxPokemon(tile)).find { |k| @storage[tile, k].nil? }
          unless free
            pbPlayBuzzerSE
            next
          end
          pbPlayDecisionSE
          show_box(tile)
          checkOpenTransferBox(tile)
          @kr_focus = [:box, free]
          @selection = free
          result = [tile, free]
          break
        end
        pbPlayDecisionSE
        show_box(tile) if tile != @storage.currentBox
        checkOpenTransferBox(tile)
        break
      end
      @kr_ov = nil
      refresh
      return result
    end

    # Holding Pokémon to put away: one (not fusing), or several (Free Picks)
    def drop_held?
      return false unless quick? && !fusing?
      return held ? multi_held.empty? : !multi_held.empty?
    end

    def held_count
      return held ? 1 : multi_held.length
    end

    def first_held
      return held || (multi_held[0] && multi_held[0][0])
    end

    # Left / Right step through the tiles, Up / Down a row; past the ends a
    # fresh press wraps (a held one stops). Down to a short last row lands
    # on its last tile.
    def ov_move(step, wrap)
      n = ov_count
      sel = @kr_ov[:sel]
      last_row = (n - 1) / OV_COLS
      to = sel + step
      if to >= n && step > 0 && sel / OV_COLS < last_row
        to = n - 1
      elsif to < 0 || to >= n
        return unless wrap
        to = if step.abs == 1 then to % n
             elsif step < 0 then [last_row * OV_COLS + sel % OV_COLS, n - 1].min
             else sel % OV_COLS
             end
      end
      return if to == @kr_ov[:sel]
      return ov_carry(to) if ov_moving
      @kr_ov[:sel] = to
      ov_scroll
      pbPlayCursorSE
      refresh
    end

    def ov_scroll
      row = @kr_ov[:sel] / OV_COLS
      @kr_ov[:top] = row if row < @kr_ov[:top]
      @kr_ov[:top] = row - OV_ROWS + 1 if row >= @kr_ov[:top] + OV_ROWS
    end

    def draw_overview(base, top, c)
      return draw_presets(base, top, c) if @kr_ov[:page] == :presets
      PP.paint_background(base, c)
      moving = ov_moving
      title = if moving then _INTL("Move {1} Where?", @storage[@kr_ov[:tiles][@kr_ov[:sel]]].name.to_s)
              elsif !drop_held? then _INTL("Box Overview")
              elsif held then _INTL("Move {1} to Which Box?", held.name.to_s)
              else _INTL("Move {1} Pokémon to Which Box?", held_count)
              end
      presets_offered? && !moving ? overview_tabs(top, c, :boxes) : PP.paint_title(top, c, title)
      tiles = @kr_ov[:tiles]
      sel = @kr_ov[:sel]
      first = @kr_ov[:top] * OV_COLS
      (0...(OV_COLS * OV_ROWS)).each do |slot|
        j = first + slot
        break if j >= tiles.length
        tx = 6 + (slot % OV_COLS) * (OV_TW + OV_GAP)
        ty = OV_Y + (slot / OV_COLS) * (OV_TH + 6)
        @kr_hits << [j, tx, ty, tx + OV_TW, ty + OV_TH]
        @cursor_rect = [tx - 1, ty - 1, OV_TW + 3, OV_TH + 3] if j == sel
        tiles[j] == :buy ? buy_tile(base, top, c, tx, ty) : box_tile(base, top, c, tiles[j], tx, ty, j == sel)
        moving_marks(c, tx, ty, box_locked?(@storage[tiles[j]])) if moving && j == sel
      end
      rows = (tiles.length + OV_COLS - 1) / OV_COLS
      P.ui.tri(top, W / 2 - 4, OV_Y - 5, :u, c[:dim], 3) if @kr_ov[:top] > 0
      P.ui.tri(top, W / 2 - 4, OV_Y + OV_ROWS * (OV_TH + 6) - 3, :d, c[:dim], 3) if @kr_ov[:top] + OV_ROWS < rows
    end

    def box_tile(base, top, c, j, tx, ty, chosen)
      b = @storage[j]
      size = @storage.maxPokemon(j)
      pks = (0...size).map { |k| b[k] }
      n = pks.compact.length
      P.ui.rbox(base, tx, ty, tx + OV_TW, ty + OV_TH, 5, c[:panel2], j == @storage.currentBox ? c[:selb] : c[:line])
      count = "#{n}/#{size}"
      cw = P.width(PF::TEXT, count) + 4
      P.text(top, tx + 8, ty + 4, OV_TW - cw - 14, 18, PF.fit(PF::TEXT, b.name.to_s, OV_TW - cw - 14), c[:txt])
      P.text(top, tx + OV_TW - cw - 6, ty + 4, cw, 18, count, n >= size ? c[:gold] : c[:dim], PF::TEXT, 1)
      # the dots go on the text layer, so the cursor's glow doesn't wash them out
      empty = mix(c[:line], c[:panel2], 0.5)
      dropping = chosen && drop_held?
      # where they'd land: the box's first free places
      frees = dropping ? (0...size).select { |k| pks[k].nil? }.first(held_count) : []
      free = frees.length == held_count ? frees.first : nil
      landing = held ? [held] : multi_held.map { |pk, *_r| pk }
      pks.each_with_index do |p, k|
        dx = tx + 8 + (k % COLS) * OV_DOT_W
        dy = ty + 26 + (k / COLS) * OV_DOT_H
        top.fill_rect(dx, dy, OV_DOT_W - 2, 6, p ? tone(p) : empty)
        # where it lands (his pick, 2026-10-25: In Its Colour, Pulsing): the
        # dot in its type's colour on the marks layer, which pulses
        next unless free && (at = frees.index(k)) && landing[at]
        marks.fill_rect(dx, dy, OV_DOT_W - 2, 6, tone(landing[at]))
      end
      sx = tx + 8 + COLS * OV_DOT_W + 6
      if dropping
        words = n >= size ? _INTL("FULL") : _INTL("ROOM FOR {1}", size - n)
        P.text(top, sx, ty + 26, OV_TW - (sx - tx) - 4, 14, words, free ? c[:green] : c[:red], PF::TINY)
        s = box_icon(first_held, :held)
        place(s, tx + OV_TW - 20, ty + OV_TH - 22, 30)
        s.opacity = 255
        s.z = 2
        return
      end
      shiny = pks.count { |p| p && shiny?(p) }
      eggs = pks.count { |p| p && p.egg? }
      iy = ty + 30
      if shiny > 0
        star(top, sx, iy, c)
        sx += P.text(top, sx + 10, iy - 3, 30, 14, shiny.to_s, c[:gold], PF::TINY) + 16
      end
      if eggs > 0
        top.fill_rect(sx + 1, iy + 1, 5, 6, Color.new(150, 200, 140))
        P.text(top, sx + 9, iy - 3, 30, 14, eggs.to_s, c[:dim], PF::TINY)
      end
      fresh = pks.count { |p| p && fresh?(p) }                     # NEW marks (his pick: NEW Pill)
      P.pill(top, tx + 8 + COLS * OV_DOT_W + 6, ty + 46, _INTL("{1} NEW", fresh), c[:green], c[:dark], false) if fresh > 0
      padlock(top, tx + OV_TW - 14, ty + OV_TH - 16, c[:red]) if box_locked?(b)
    end

    def box_locked?(b)
      return (b.respond_to?(:sortlock?) && b.sortlock?) || (b.respond_to?(:exportlock?) && b.exportlock?) ? true : false
    end

    # Buy Box: its price green when you have the money, red when you don't
    def buy_tile(base, top, c, tx, ty)
      P.ui.rbox(base, tx, ty, tx + OV_TW, ty + OV_TH, 5, mix(c[:panel2], c[:bg], 0.4), c[:line])
      price = buy_box_price
      money = $Trainer ? $Trainer.money.to_i : 0
      P.text(top, tx + 8, ty + 4, OV_TW - 16, 20, _INTL("+ Buy Box"), c[:txt])
      P.text(top, tx + 8, ty + 28, OV_TW - 16, 16, "$" + money_words(price), money >= price ? c[:green] : c[:red], PF::TEXT)
    end

    def money_words(n)
      return n.to_i.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
    end

    def overview_hints
      return presets_hints if @kr_ov[:page] == :presets
      return moving_hints if ov_moving
      tile = @kr_ov[:tiles][@kr_ov[:sel]]
      verb = if tile == :buy then _INTL("Buy Box")
             elsif drop_held? then _INTL("Drop Here")
             else _INTL("Go to Box")
             end
      list = [[:ud, _INTL("Choose")], [button(:C), verb]]
      list << [button(:X), _INTL("Move Box")] if tile.is_a?(Integer) && box_move_ok?
      list << [button(:R), _INTL("Presets")] if presets_offered?
      return list + [[button(:B), _INTL("Back")]]
    end

    #--------------------------------------------------------------------------
    # Wallpaper (his pick: Grid Popup)
    #--------------------------------------------------------------------------
    def wallpaper_list?(message, labels)
      return false unless message.to_s == _INTL("Pick the wallpaper.")
      papers = @storage.availableWallpapers
      return false unless papers[0].map(&:to_s) == labels
      @kr_wp_ids = papers[1]
      return true
    end

    # The index chosen, or -1
    def wallpaper_grid(labels, index)
      ids = @kr_wp_ids
      sel = index.to_i.clamp(0, labels.length - 1)
      top_row = [sel / WP_COLS - 1, 0].max
      ret = -1
      hints = [[:ud, _INTL("Choose")], [button(:C), _INTL("Use It")], [button(:B), _INTL("Back")]]
      with_popup_hints(hints) do
        redraw = true
        loop do
          top_row = sel / WP_COLS if sel / WP_COLS < top_row
          top_row = sel / WP_COLS - WP_ROWS + 1 if sel / WP_COLS >= top_row + WP_ROWS
          draw_wallpapers(labels, ids, sel, top_row) if redraw
          redraw = false
          Graphics.update
          Input.update
          update
          pt = Reloaded::Pointer
          hit = pt.hit(@kr_wp_hits || [])
          if pt.moved? && hit && hit != sel
            sel = hit
            pbPlayCursorSE
            redraw = true
          end
          to = nil
          if pt.left? && hit
            sel = hit
            pbPlayDecisionSE
            ret = sel
            break
          elsif pt.right? || Input.trigger?(Input::BACK)
            pbPlayCancelSE
            break
          elsif (w = pt.wheel) != 0
            rows = (labels.length + WP_COLS - 1) / WP_COLS
            top_row = (top_row + w).clamp(0, [rows - WP_ROWS, 0].max)
            sel = sel.clamp(top_row * WP_COLS, [(top_row + WP_ROWS) * WP_COLS - 1, labels.length - 1].min)
            redraw = true
          elsif Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)
            to = (sel + (Input.repeat?(Input::LEFT) ? -1 : 1)) % labels.length
          elsif Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN)
            step = Input.repeat?(Input::UP) ? -WP_COLS : WP_COLS
            to = sel + step
            if to < 0 || to >= labels.length
              to = nil
              if Input.trigger?(Input::UP) || Input.trigger?(Input::DOWN)
                to = step < 0 ? labels.length - 1 : 0
              end
            end
          elsif Input.trigger?(Input::USE)
            pbPlayDecisionSE
            ret = sel
            break
          end
          next unless to && to != sel
          sel = to
          pbPlayCursorSE
          redraw = true
        end
      end
      return ret
    ensure
      overlay.clear if @overlay_sprite && !@overlay_sprite.disposed?
      dispose_walls
    end

    def draw_wallpapers(labels, ids, sel, top_row)
      b = overlay
      c = palette
      dg = Reloaded::Dialogs
      dg.send(:dim, b)
      w = WP_W
      h = 40 + WP_ROWS * (WP_TH + WP_GAP) + 8 + 26
      x = (W - w) / 2
      y = (H - h) / 2
      dg.send(:panel, b, c, x, y, w, h)
      dg.send(:title_bar, b, c, x, y, w, _INTL("{1}'s Wallpaper", box.name.to_s))
      x0 = x + (w - (WP_COLS * WP_TW + (WP_COLS - 1) * WP_GAP)) / 2
      now = box.background
      @kr_wp_hits = []
      (WP_COLS * WP_ROWS).times do |slot|
        i = top_row * WP_COLS + slot
        break if i >= labels.length
        tx = x0 + (slot % WP_COLS) * (WP_TW + WP_GAP)
        ty = y + 44 + (slot / WP_COLS) * (WP_TH + WP_GAP)
        @kr_wp_hits << [i, tx - 3, ty - 3, tx + WP_TW + 3, ty + WP_TH + 3]
        # the highlighted one sits on a plate in the cursor's colours (his
        # pick, 2026-10-25: Lit Plate, no frame)
        if i == sel
          fill, border = Reloaded::Palette.cursor(nil, c)
          P.ui.rbox(b, tx - 5, ty - 5, tx + WP_TW + 4, ty + WP_TH + 4, 5, Reloaded::Palette.over(c[:panel2], fill),
                    Reloaded::Palette.over(c[:panel2], border))
        end
        wall = wall_picture(ids[i])
        if wall
          b.stretch_blt(Rect.new(tx, ty, WP_TW, WP_TH), wall, Rect.new(*WALL_SRC))
        else
          b.fill_rect(tx, ty, WP_TW, WP_TH, c[:panel])
        end
        P.pill(b, tx + 2, ty + 2, _INTL("NOW"), c[:gold], c[:dark], false) if ids[i] == now
      end
      keep_walls(ids[top_row * WP_COLS, WP_COLS * WP_ROWS])
      rows = (labels.length + WP_COLS - 1) / WP_COLS
      P.ui.tri(b, x + w / 2 - 4, y + 38, :u, c[:dim], 3) if top_row > 0
      P.ui.tri(b, x + w / 2 - 4, y + 40 + WP_ROWS * (WP_TH + WP_GAP) + 2, :d, c[:dim], 3) if top_row + WP_ROWS < rows
      b.fill_rect(x + 10, y + h - 30, w - 20, 1, c[:line])
      P.text(b, x + 14, y + h - 26, w - 28, 18, PF.fit(PF::TEXT, labels[sel].to_s, w - 28), c[:txt], PF::TEXT, 2)
    end

    # A wallpaper's picture while it's in view (there are 200: only the ones
    # shown are kept, and none once the grid closes)
    def wall_picture(id)
      @kr_walls ||= {}
      return @kr_walls[id] if @kr_walls.key?(id)
      @kr_walls[id] = begin
        path = if defined?(::KIF::Wallpapers) && ::KIF::Wallpapers.respond_to?(:kif?) && ::KIF::Wallpapers.kif?(id)
                 ::KIF::Wallpapers.path(id)
               else
                 "Graphics/Pictures/Storage/Wallpapers/box_#{id}"
               end
        Bitmap.new(pbResolveBitmap(path) || path)
      rescue StandardError
        nil
      end
    end

    def keep_walls(ids)
      (@kr_walls || {}).keys.each do |id|
        next if ids.include?(id)
        bm = @kr_walls.delete(id)
        bm.dispose if bm && !bm.disposed?
      end
    end

    def dispose_walls
      keep_walls([])
    end
  end
end
