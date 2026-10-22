#==============================================================================
# Kanto Reloaded: the Pause Menu's screen
#==============================================================================
# Info Sidebar (Roadmap topic 34, design 2), over the map, which shows
# through dimmed:
#
#   left    Pause Menu, Money, Location (map, day, a clock that ticks),
#           the Safari Zone's or Bug Contest's balls and steps while you're
#           in one, and the Favorite (Y opens it)
#   right   Pinned (empty until Kanto Reloaded's own Shop, TM Vault,
#           PokeVial and PC are built), Your Row (up to 4, with an Add
#           tile) and All, a carousel of every entry you can use now
#
# Controller first: Left/Right choose, Up/Down change rows, A opens, X
# edits a tile (Set as Favorite, Add to Your Row, Move, Remove), Y opens the
# Favorite, B closes. The mouse: hover picks, a click opens (a side tile of
# the carousel turns to it), the wheel turns the carousel, a right click
# closes. Menu Animations: the column slides in, the tiles fade in, the
# carousel slides.
#
# PIF's scene methods stay as they were for everything else in the game
# (SceneView answers each of them: the list in, the chosen row's index out),
# and the screen falls back to PIF's own if it fails.
#==============================================================================

return unless defined?(Reloaded::Frame) && defined?(::KIF::PixelFont)

module Reloaded
  module PauseMenu
    #--------------------------------------------------------------------------
    # PokemonPauseMenu_Scene while Reloaded Pause Menu is on
    #--------------------------------------------------------------------------
    module SceneView
      def pbStartScene
        return super unless Reloaded::PauseMenu.active?
        @kr_view = Reloaded::PauseMenu::View.new(Reloaded::PauseMenu.direct)
        @kr_view.open
        pbSEPlay("GUI menu open") if !@kr_view.direct? && defined?(pbSEPlay)
      rescue StandardError => e
        Reloaded::Log.exception("The Pause Menu couldn't open; the game's own instead", e, :pause_menu)
        kr_drop
        super
      end

      def pbShowInfo(text)
        return super unless @kr_view
        @kr_view.info = text
      end

      def pbShowHelp(text)
        return super unless @kr_view
        @kr_view.help = text
      end

      def pbShowMenu
        return super unless @kr_view
        @kr_view.show
      end

      def pbHideMenu
        return super unless @kr_view
        @kr_view.hide
      end

      def pbRefresh
        return super unless @kr_view
        @kr_view.refresh
      end

      # The list PIF made: KIF's entries go in, and run, as in the game's
      # own menu; the screen answers with the chosen row's index, or -1.
      def pbShowCommands(commands)
        return super unless @kr_view
        if defined?(::KIF::PauseMenu) && ::KIF::PauseMenu.respond_to?(:show_commands)
          return ::KIF::PauseMenu.show_commands(self, commands) { |list| kr_choose(list) }
        end
        return kr_choose(commands)
      end

      def pbEndScene
        return super unless @kr_view
        kr_drop
      end

      private

      def kr_choose(list)
        return pif(:pbShowCommands, list) unless @kr_view       # it fell back during this menu
        return @kr_view.choose(list)
      rescue StandardError => e
        Reloaded::Log.exception("The Pause Menu broke; the game's own instead", e, :pause_menu)
        kr_drop
        pif(:pbStartScene)
        return pif(:pbShowCommands, list)
      end

      def kr_drop
        @kr_view.close if @kr_view
      rescue StandardError
        nil
      ensure
        @kr_view = nil
      end

      # PIF's own method, under every hook.
      def pif(name, *args)
        m = method(name)
        m = m.super_method while m && m.owner != ::PokemonPauseMenu_Scene
        return m ? m.call(*args) : -1
      end
    end

    #--------------------------------------------------------------------------
    # The screen
    #--------------------------------------------------------------------------
    class View
      include Reloaded::Frame

      PF = ::KIF::PixelFont
      P = Reloaded::Pixel
      PM = Reloaded::PauseMenu
      TOP = 6
      BOTTOM = H - P::HINT_H - 6
      LEFT_X0 = 6
      LEFT_X1 = 150
      RX0 = 159                       # the tile rows' first column
      TILE_W = 82
      TILE_H = 84
      TILE_GAP = 6
      RX1 = RX0 + 4 * TILE_W + 3 * TILE_GAP
      PIN_Y = 18                      # each row's tiles (its heading above)
      ROW_Y = 121
      ALL_Y = 224
      CAR_CX = (RX0 + RX1) / 2
      CAR_CY = 288
      # The carousel's slots by distance from the middle: [x offset, w, h]
      # (3: just out of sight, where a tile slides from)
      SLOTS = [[0, 100, 120], [86, 60, 68], [144, 44, 50], [190, 30, 34]].freeze
      FAV_H = 126                     # the Favorite's heading, card and hint
      DIM_ALPHA = 110
      PANEL_ALPHA = 226
      TILE_ALPHA = 214
      GREEN = Color.new(120, 230, 150)
      RED   = Color.new(240, 100, 90)
      GOLD  = Color.new(240, 200, 80)
      STAR = ["...#...", "..###..", "#######", ".#####.", "..###..", ".##.##.", "##...##"].freeze
      LOCK = [".###.", "#...#", "#...#", "#####", "##.##", "##.##", "#####"].freeze

      def initialize(direct = nil)
        frame_init
        @direct = direct
        @items = []
        @all = []
        @pinned = []
        @row = []
        @info = nil
        @hits = []
        @icons = {}
        cur = PM.cursor || {}
        @focus = cur[:focus] || :all
        @col = { :pinned => cur[:pinned].to_i, :row => cur[:row].to_i }
        @car_key = cur[:car]
        @car = 0
        @opened = false
      end

      def direct?
        return !@direct.nil?
      end

      attr_writer :help

      def open
        open_sprites
        @viewport.z = 99_998
        @dim = Sprite.new(@viewport)
        @dim.z = -2
        @dim.bitmap = Bitmap.new(W, H)
        # the map darkened, or on Light and Frost washed pale (its dark
        # headings read on it)
        c = palette
        wash = c[:light] ? Color.new(c[:panel2].red, c[:panel2].green, c[:panel2].blue, 130) : Color.new(0, 0, 0, DIM_ALPHA)
        @dim.bitmap.fill_rect(0, 0, W, H, wash)
        @left = Sprite.new(@viewport)
        @left.bitmap = Bitmap.new(LEFT_X1 - LEFT_X0 + 1, BOTTOM - TOP + 1)
        @left.x = LEFT_X0
        @left.y = TOP
        set_visible(false)
      end

      def close
        PM.cursor = { :focus => @focus, :pinned => @col[:pinned], :row => @col[:row],
                      :car => (@all[@car].key if @all[@car]) }
        [@dim, @left].each do |s|
          next if s.nil? || s.disposed?
          s.bitmap.dispose if s.bitmap && !s.bitmap.disposed?
          s.dispose
        end
        @icons.each_value { |b| b.dispose if b && !b.disposed? }
        @icons = {}
        dispose_sprites
      end

      # The Safari Zone's or Bug Contest's lines (PIF shows them in a box).
      def info=(text)
        @info = text.to_s.empty? ? nil : text.to_s
        refresh if @shown
      end

      def show
        return if direct?
        set_visible(true)
        refresh
      end

      def hide
        set_visible(false)
      end

      # PIF's list in, the chosen row's index out (-1: closed).
      def choose(list)
        @items = PM.items_for(list)
        return direct_pick if direct?
        build
        set_visible(true)
        refresh
        animate(:in) unless @opened
        @opened = true
        loop do
          Graphics.update
          Input.update
          pbUpdateSceneMap if defined?(pbUpdateSceneMap)
          update_frame
          tick_clock
          result = handle_input
          next unless result.is_a?(Integer)
          $PokemonTemp.menuLastChoice = result if result >= 0 && $PokemonTemp && $PokemonTemp.respond_to?(:menuLastChoice=)
          return result
        end
      end

      def refresh
        return unless @sprite && !@sprite.disposed?
        c = palette
        base = @sprite.bitmap
        top = @top_sprite.bitmap
        base.clear
        top.clear
        @hits = []
        @cursor_rect = nil
        paint_left(c)
        paint_rows(base, top, c)
        paint_carousel(base, top, c)
        paint_hints(base, c)
        place_cursor
      end

      private

      #------------------------------------------------------------------------
      # Layers
      #------------------------------------------------------------------------
      def sprites
        return super + [@dim, @left].compact.reject { |s| s.disposed? }
      end

      def set_visible(on)
        @shown = on
        sprites.each { |s| s.visible = on }
        place_cursor if on && @sprite
        @cursor_sprite.visible = false if !on && @cursor_sprite && !@cursor_sprite.disposed?
      end

      # Opening: the column slides in, the rest fades in; closing, the other
      # way. Menu Animations Off: at once.
      def animate(way)
        return unless PM.animations?
        steps = way == :in ? 6 : 5
        fading = [@sprite, @top_sprite, @hint_sprite, @dim]
        steps.times do |k|
          t = (k + 1).to_f / steps
          e = way == :in ? 1 - (1 - t)**2 : (1 - t)**2
          @left.x = LEFT_X0 - ((1 - e) * (LEFT_X1 + 8)).round
          fading.each { |s| s.opacity = (255 * e).round }
          @cursor_sprite.visible = false
          Graphics.update
          pbUpdateSceneMap if defined?(pbUpdateSceneMap)
        end
        @left.x = LEFT_X0
        fading.each { |s| s.opacity = 255 } if way == :in
        place_cursor if way == :in
      end

      #------------------------------------------------------------------------
      # The rows
      #------------------------------------------------------------------------
      def build
        by_key = {}
        @items.each { |it| by_key[it.key] = it }
        @all = @items
        @pinned = PM.pinned_keys.map { |k| k && (by_key[k] || PM.known_item(k)) }
        @row = PM.row.map { |k| by_key[k] || PM.known_item(k) }.compact.first(PM::ROW_MAX)
        fav = PM.favorite
        @fav = fav && (by_key[fav] || PM.known_item(fav))
        if @car_key && (i = @all.index { |it| it.key == @car_key })
          @car = i
        end
        @car = 0 if @car >= @all.length
        @car_key = nil
        fix_focus
      end

      def rebuild
        @car_key = @all[@car].key if @all[@car]
        build
        refresh
      end

      # Your Row's tiles, and Add while there's room
      def row_slots
        return @row.length < PM::ROW_MAX ? @row + [:add] : @row
      end

      def focusable
        out = []
        out << :pinned if @pinned.any?
        out << :row
        out << :all unless @all.empty?
        return out
      end

      def fix_focus
        @focus = focusable.include?(@focus) ? @focus : (focusable.include?(:all) ? :all : :row)
        @col[:row] = [[@col[:row], 0].max, row_slots.length - 1].min
        if @pinned.any? && @pinned[@col[:pinned]].nil?
          @col[:pinned] = @pinned.index { |p| p } || 0
        end
      end

      def current
        case @focus
        when :pinned then return @pinned[@col[:pinned]]
        when :row then return row_slots[@col[:row]]
        end
        return @all[@car]
      end

      #------------------------------------------------------------------------
      # Input
      #------------------------------------------------------------------------
      def handle_input
        return move_input if @moving
        pt = Reloaded::Pointer
        if pointer_hover
          hit = pt.hit(@hits)
          on_fav = !hit.nil? && hit[0] == :favorite
          if on_fav != (@hover_fav ? true : false)
            @hover_fav = on_fav
            refresh
          end
          hover(hit) if hit && !on_fav
        end
        if pt.left?
          handled, result = hint_click
          return result.is_a?(Integer) ? result : nil if handled
          hit = pt.hit(@hits)
          return hit ? click(hit) : nil
        end
        return close_menu if pt.right?
        if (wheel = pt.wheel) != 0
          @focus == :all ? turn(wheel) : step(wheel)
          return nil
        end
        if Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)
          dir = Input.repeat?(Input::LEFT) ? -1 : 1
          @focus == :all ? turn(dir) : step(dir, Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT))
        elsif Input.trigger?(Input::UP) || Input.trigger?(Input::DOWN)
          change_row(Input.trigger?(Input::UP) ? -1 : 1)
        elsif Input.trigger?(Input::USE)
          return pick
        elsif Input.trigger?(Input::ACTION)           # X on a controller
          edit
        elsif Input.trigger?(Input::X)                # Y on a controller
          return open_favorite
        elsif Input.trigger?(Input::BACK)
          return close_menu
        end
        return nil
      end

      # Left/Right in a row (a held direction stops at its ends; a fresh
      # press wraps), over Pinned's empty slots.
      def step(dir, fresh = true)
        slots = @focus == :pinned ? @pinned : row_slots
        n = slots.length
        j = @col[@focus]
        (n - 1).times do
          j += dir
          if j < 0 || j >= n
            return unless fresh
            j %= n
          end
          next unless slots[j]
          @col[@focus] = j
          pbPlayCursorSE
          refresh
          return
        end
      end

      # The carousel turns (it always wraps).
      def turn(dir)
        return if @all.length < 2
        @focus = :all
        @car = (@car + dir) % @all.length
        pbPlayCursorSE
        slide(dir <=> 0)
        refresh
      end

      def change_row(dir)
        order = focusable
        j = order.index(@focus).to_i + dir
        return if j < 0 || j >= order.length
        @focus = order[j]
        fix_focus
        pbPlayCursorSE
        refresh
      end

      def hover(hit)
        kind, i = hit
        changed = case kind
                  when :pinned, :row
                    was = [@focus, @col[kind]]
                    @focus = kind
                    @col[kind] = i
                    was != [kind, i]
                  when :all
                    was = @focus
                    @focus = :all if i == 0
                    was != @focus
                  end
        return unless changed
        pbPlayCursorSE
        refresh
      end

      def click(hit)
        kind, i = hit
        case kind
        when :pinned, :row
          @focus = kind
          @col[kind] = i
          return pick
        when :all
          if i != 0
            turn(i)
            return nil
          end
          @focus = :all
          return pick
        when :favorite
          return open_favorite
        end
        return nil
      end

      def pick
        it = current
        return add_entry if it == :add
        return nil unless it
        return it.index if it.index
        locked(it)
        return nil
      end

      def open_favorite
        unless @fav
          pbPlayBuzzerSE
          return nil
        end
        return @fav.index if @fav.index
        locked(@fav)
        return nil
      end

      def close_menu
        animate(:out)
        return -1
      end

      def locked(it)
        pbPlayBuzzerSE
        Reloaded::Dialogs.notice(self, it.label, PM.lock_reason(it.key))
        refresh
      end

      # X: what can be done with a tile.
      def edit
        it = current
        if !it.is_a?(PM::Item) || PM::SITUATIONAL.include?(it.key)
          pbPlayBuzzerSE
          return nil
        end
        fav = PM.favorite == it.key
        choices = []
        if fav
          choices << [_INTL("Clear Favorite"), :favorite, _INTL("No Favorite until you set another.")]
        else
          choices << [_INTL("Set as Favorite"), :favorite, _INTL("Opens with one button here, and from the map with Open Favorite (Controls).")]
        end
        if @focus == :row
          choices << [_INTL("Move"), :move, _INTL("Move it along Your Row with Left and Right.")] if @row.length > 1
          choices << [_INTL("Remove"), :remove, _INTL("Takes it out of Your Row. It stays in All.")]
        elsif !PM.row.include?(it.key) && @row.length < PM::ROW_MAX
          choices << [_INTL("Add to Your Row"), :add, _INTL("Puts it at the end of Your Row.")]
        end
        pbPlayDecisionSE
        i = Reloaded::Dialogs.menu(self, it.label, choices.map { |ch| ch[0] }, choices.map { |ch| ch[2] })
        case i && choices[i][1]
        when :favorite then PM.favorite = fav ? nil : it.key
        when :move then @moving = it.key
        when :remove then PM.remove_from_row(it.key)
        when :add then PM.add_to_row(it.key)
        end
        rebuild
        return nil
      end

      # The Add tile: an entry from All, at the end of Your Row.
      def add_entry
        choices = @all.reject { |it| PM.row.include?(it.key) || PM::SITUATIONAL.include?(it.key) }
        if choices.empty?
          pbPlayBuzzerSE
          return nil
        end
        pbPlayDecisionSE
        i = Reloaded::Dialogs.menu(self, _INTL("Add to Your Row"), choices.map(&:label))
        if i
          PM.add_to_row(choices[i].key)
          @col[:row] = [PM.row.length, PM::ROW_MAX - 1].min
        end
        rebuild
        return nil
      end

      # Move: Left/Right carry the tile along Your Row; anything else puts
      # it down.
      def move_input
        pt = Reloaded::Pointer
        if Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)
          dir = Input.repeat?(Input::LEFT) ? -1 : 1
          if PM.move_in_row(@moving, dir)
            @col[:row] += dir
            pbPlayCursorSE
            rebuild
          end
        elsif Input.trigger?(Input::USE) || Input.trigger?(Input::BACK) || Input.trigger?(Input::ACTION) || pt.left? || pt.right?
          @moving = nil
          pbPlayDecisionSE
          refresh
        end
        return nil
      end

      # Open Favorite from the map: the Favorite's row at once (the screen
      # never shows), then closed.
      def direct_pick
        return -1 if @direct_done
        @direct_done = true
        it = @items.find { |x| x.key == @direct }
        return it.index if it
        known = PM.known_item(@direct)
        pbPlayBuzzerSE
        @overlay_sprite.visible = true
        Reloaded::Dialogs.notice(self, known ? known.label : _INTL("Favorite"), PM.lock_reason(@direct))
        @overlay_sprite.visible = false
        return -1
      end

      #------------------------------------------------------------------------
      # The left column
      #------------------------------------------------------------------------
      def paint_left(c)
        b = @left.bitmap
        b.clear
        w = b.width
        P.ui.rbox(b, 0, 0, w - 1, b.height - 1, 7, alpha(c[:panel2], panel_alpha), c[:line])
        P.text(b, 0, 6, w, 26, _INTL("Pause Menu"), c[:title], PF::TITLE, 2)
        y = label(b, c, 42, _INTL("Money"))
        P.text(b, 0, y, w, 22, money_text, tone(:green), PF::ROW, 2)
        y = label(b, c, y + 30, _INTL("Location"))
        map, day, clock = where_words
        P.text(b, 6, y, w - 12, 20, PF.fit(PF::TEXT, map, w - 12), c[:txt], PF::TEXT, 2)
        P.text(b, 6, y + 18, w - 12, 18, day, c[:dim], PF::TEXT, 2)
        P.text(b, 6, y + 34, w - 12, 18, clock, c[:dim], PF::TEXT, 2)
        @clock = clock
        y += 56
        if @info
          y = label(b, c, y, PM.in_contest? ? _INTL("Bug Contest") : (PM.in_safari? ? _INTL("Safari Zone") : _INTL("Info")))
          @info.split("\n").each do |ln|
            P.text(b, 6, y, w - 12, 16, PF.fit(PF::TEXT, ln, w - 12), c[:txt], PF::TEXT, 2)
            y += 16
          end
          y += 4
        end
        paint_favorite(b, c, [y, b.height - FAV_H].max)        # at the bottom, as the design has it
      end

      # A small heading, centred; returns where what's under it starts.
      def label(b, c, y, text)
        P.text(b, 0, y, b.width, 13, text.to_s.upcase, c[:head], PF::TINY, 2)
        return y + 14
      end

      def paint_favorite(b, c, y)
        w = b.width
        y = label(b, c, y, _INTL("Favorite"))
        x0 = 10
        x1 = w - 11
        y1 = y + 84
        hover = @hover_fav
        if @fav
          P.ui.rbox(b, x0, y, x1, y1, 6, alpha(hover ? Reloaded::Palette.mix(c[:selb], c[:panel2], 0.55) : c[:panel], tile_alpha),
                    hover ? c[:selb] : c[:line])
          off = @fav.index.nil?
          draw_icon(b, @fav.icon, (x0 + x1) / 2, y + 6, 1, off, 56)
          tile_label(b, x0 + 4, y + 64, x1 - x0 - 8, @fav.label, off ? c[:dim] : tone(:gold))
          lock(b, x1 - 12, y + 6, c[:dim]) if off
          key_hint(b, c, w / 2, y1 + 4, :X, _INTL("Opens It"))
        else
          P.ui.rbox(b, x0, y, x1, y1, 6, alpha(c[:panel2], 120), c[:line])
          P.text(b, x0, y, x1 - x0, y1 - y, _INTL("None Yet"), c[:dim], PF::TEXT, 2)
          key_hint(b, c, w / 2, y1 + 4, :A, _INTL("Sets One"))
        end
        @hits << [[:favorite, 0], LEFT_X0 + x0, TOP + y, LEFT_X0 + x1, TOP + y1]
      end

      # A button and its words, centred at cx.
      def key_hint(b, c, cx, y, sym, text)
        pairs = [[button(sym), text]]
        style = Reloaded::Prompts.style
        width = P.hints_width(b, pairs, style)
        P.draw_hints(b, cx - width / 2, y - 4, c, pairs, style)
      end

      def money_text
        m = ($Trainer.money rescue 0).to_i
        return "$#{m.to_s.reverse.scan(/\d{1,3}/).join(",").reverse}"
      end

      # [map, day, "3:42 PM"], as PIF's location pop-up words them
      def where_words
        id = ($game_map.map_id rescue nil)
        map = id && defined?(pbGetMapNameFromId) ? (pbGetMapNameFromId(id) rescue "").to_s : ""
        map = map.split(" (")[0].to_s
        now = defined?(pbGetTimeNow) ? (pbGetTimeNow rescue Time.now) : Time.now
        day = defined?(getDayOfTheWeekName) ? (getDayOfTheWeekName rescue nil) : nil
        day ||= now.strftime("%A")
        return [map, day.to_s, now.strftime("%l:%M %p").strip]
      end

      # The clock, once a second.
      def tick_clock
        return unless @frame % 20 == 0
        clock = where_words[2]
        paint_left(palette) if clock != @clock
      end

      #------------------------------------------------------------------------
      # Pinned and Your Row
      #------------------------------------------------------------------------
      def paint_rows(base, top, c)
        P.heading(top, RX0, RX1, PIN_Y - 13, _INTL("Pinned"), c[:head], c[:line])
        @pinned.each_index do |i|
          x, y = tile_xy(i, PIN_Y)
          it = @pinned[i]
          if it
            paint_tile(base, top, c, x, y, it, @focus == :pinned && @col[:pinned] == i)
            @hits << [[:pinned, i], x, y, x + TILE_W, y + TILE_H]
          else
            empty_slot(base, c, x, y)
          end
        end
        P.heading(top, RX0, RX1, ROW_Y - 13, _INTL("Your Row"), c[:head], c[:line])
        slots = row_slots
        PM::ROW_MAX.times do |i|
          x, y = tile_xy(i, ROW_Y)
          slot = slots[i]
          on = @focus == :row && @col[:row] == i
          if slot == :add
            paint_add(base, top, c, x, y, on)
          elsif slot
            paint_tile(base, top, c, x, y, slot, on)
            paint_moving(top, c, x, y) if @moving == slot.key
          else
            empty_slot(base, c, x, y)
            next
          end
          @hits << [[:row, i], x, y, x + TILE_W, y + TILE_H]
        end
      end

      def tile_xy(i, y)
        return [RX0 + i * (TILE_W + TILE_GAP), y]
      end

      def empty_slot(base, c, x, y)
        P.ui.rbox(base, x, y, x + TILE_W, y + TILE_H, 6, alpha(c[:panel2], 150), alpha(c[:line], 220))
      end

      # A tile: its icon, its name, its status, a star when it's the
      # Favorite, a lock when it can't be used now. A row's tile shows the
      # status as a pill; the carousel's big middle tile, in full under the
      # name.
      def paint_tile(base, top, c, x, y, it, on, big = false)
        w = big ? SLOTS[0][1] : TILE_W
        h = big ? SLOTS[0][2] : TILE_H
        off = it.index.nil?
        fill = on ? Reloaded::Palette.mix(c[:selb], c[:panel2], 0.55) : c[:panel]
        P.ui.rbox(base, x, y, x + w, y + h, 6, alpha(fill, tile_alpha), on ? c[:selb] : c[:line])
        draw_icon(top, it.icon, x + w / 2, y + (big ? 12 : 8), 1, off, 56)
        tile_label(top, x + 3, y + (big ? 72 : 64), w - 6, it.label, off ? c[:dim] : (fav?(it) ? tone(:gold) : c[:txt]))
        star(top, x + 5, y + 5) if fav?(it)
        lock(top, x + w - 12, y + 6, c[:dim]) if off
        st = !off && PM.status(it.key)
        if st
          colour = st[2] == :red ? tone(:red) : nil
          if big
            P.text(top, x + 2, y + 94, w - 4, 13, PF.fit(PF::TINY, st[0], w - 4), colour || c[:dim], PF::TINY, 2)
          else
            colour ||= c[:txt]
            P.pill(top, x + w - 4, y + 4, st[1], *badge(colour))
          end
        end
        @cursor_rect = [x, y, w + 1, h + 1] if on
      end

      def paint_add(base, top, c, x, y, on)
        fill = on ? Reloaded::Palette.mix(c[:selb], c[:panel2], 0.55) : c[:panel2]
        P.ui.rbox(base, x, y, x + TILE_W, y + TILE_H, 6, alpha(fill, tile_alpha - 40), on ? c[:selb] : c[:line])
        cx = x + TILE_W / 2
        colour = on ? c[:txt] : c[:dim]
        top.fill_rect(cx - 12, y + 30, 24, 4, colour)
        top.fill_rect(cx - 2, y + 20, 4, 24, colour)
        P.text(top, x, y + 62, TILE_W, 18, _INTL("Add"), colour, PF::TEXT, 2)
        @cursor_rect = [x, y, TILE_W + 1, TILE_H + 1] if on
      end

      # Moving a tile: arrows at its sides.
      def paint_moving(top, c, x, y)
        P.ui.tri(top, x - 5, y + TILE_H / 2 - 4, :l, c[:selb], 4) if PM.row.index(@moving).to_i > 0
        P.ui.tri(top, x + TILE_W + 1, y + TILE_H / 2 - 4, :r, c[:selb], 4) if PM.row.index(@moving).to_i < PM.row.length - 1
      end

      def fav?(it)
        return PM.favorite && it.key == PM.favorite
      end

      #------------------------------------------------------------------------
      # All: the carousel
      #------------------------------------------------------------------------
      # @slide: while it turns, how far the tiles still have to go (in
      # slots, its sign the way they move).
      def paint_carousel(base, top, c)
        P.heading(top, RX0, RX1, ALL_Y - 13, _INTL("All"), c[:head], c[:line])
        n = @all.length
        return if n == 0
        lo = -((n - 1) / 2)
        hi = n / 2
        shift = @slide || 0.0
        tiles = (lo..hi).map { |o| [o, o + shift] }.reject { |_o, p| p.abs > 2.6 }
        tiles.sort_by { |_o, p| -p.abs }.each do |o, p|
          it = @all[(@car + o) % n]
          sx, w, h = slot_geom(p)
          x = CAR_CX + sx - w / 2
          y = CAR_CY - h / 2
          if shift == 0 && o == 0
            paint_tile(base, top, c, x, y, it, @focus == :all, true)
          else
            paint_side(base, top, c, x, y, w, h, it)
          end
          @hits << [[:all, o], x, y, x + w, y + h] if shift == 0
        end
      end

      # A slot's [x offset, w, h] between the fixed ones (p: slots from the
      # middle, may be fractional while turning).
      def slot_geom(p)
        a = [p.abs, 3].min
        i0 = a.floor
        i1 = [i0 + 1, 3].min
        f = a - i0
        g = (0..2).map { |k| SLOTS[i0][k] + (SLOTS[i1][k] - SLOTS[i0][k]) * f }
        return [(g[0] * (p <=> 0)).round, g[1].round, g[2].round]
      end

      # Every other tile of the carousel (and the middle one while it
      # turns): just its icon, smaller further out.
      def paint_side(base, top, c, x, y, w, h, it)
        fill = w >= 80 ? c[:panel] : c[:panel2]
        P.ui.rbox(base, x, y, x + w, y + h, 5, alpha(fill, tile_alpha - (w >= 80 ? 0 : 30)), c[:line])
        draw_icon(top, it.icon, x + w / 2, y, w >= 56 ? 1 : 0.5, false, h, 210)
      end

      # The carousel turning: the tiles slide one slot.
      def slide(dir)
        return unless PM.animations? && dir != 0
        steps = 4
        steps.times do |k|
          @slide = dir * (1 - (k + 1).to_f / steps)
          @slide = nil if @slide == 0
          refresh
          Graphics.update
          pbUpdateSceneMap if defined?(pbUpdateSceneMap)
        end
      ensure
        @slide = nil
      end

      #------------------------------------------------------------------------
      # Drawing pieces
      #------------------------------------------------------------------------
      # An entry's name in a tile w wide: in the tile font when it fits,
      # else smaller on one or two lines.
      def tile_label(b, x, y, w, text, colour)
        text = text.to_s
        if P.width(PF::TEXT, text) <= w
          P.text(b, x, y, w, 18, text, colour, PF::TEXT, 2)
          return
        end
        lines = two_lines(text, w)
        if lines.length == 1
          P.text(b, x, y, w, 18, lines[0], colour, PF::TINY, 2)
        else
          lines.each_with_index { |ln, k| P.text(b, x, y - 2 + k * 11, w, 11, ln, colour, PF::TINY, 2) }
        end
      end

      def two_lines(text, w)
        return [text] if P.width(PF::TINY, text) <= w
        words = text.split(" ")
        best = nil
        (1...words.length).each do |k|
          a = words[0...k].join(" ")
          z = words[k..-1].join(" ")
          wide = [P.width(PF::TINY, a), P.width(PF::TINY, z)].max
          best = [wide, [a, z]] if wide <= w && (best.nil? || wide < best[0])
        end
        return best ? best[1] : [PF.fit(PF::TINY, text, w)]
      end

      # An icon [file, scale] centred at cx, from y (centred in box pixels
      # when given); times: 0.5 for a small slot. Dimmed for an entry that
      # can't be used now.
      def draw_icon(b, icon, cx, y, times = 1, off = false, box = nil, opacity = 255)
        return unless icon
        bmp = icon_bitmap(icon[0])
        return unless bmp
        w, h = icon_size(icon, times)
        y += (box - h) / 2 if box
        b.stretch_blt(Rect.new(cx - w / 2, y, w, h), bmp, Rect.new(0, 0, bmp.width, bmp.height), off ? 90 : opacity)
      end

      def icon_size(icon, times)
        bmp = icon && icon_bitmap(icon[0])
        return [0, 0] unless bmp
        s = icon[1].to_f * times
        return [(bmp.width * s).round, (bmp.height * s).round]
      end

      def icon_bitmap(file)
        return @icons[file] if @icons.has_key?(file)
        path = defined?(pbResolveBitmap) ? (pbResolveBitmap(file) || file) : file
        @icons[file] = (Bitmap.new(path) rescue nil)
        return @icons[file]
      end

      def star(b, x, y)
        STAR.each_with_index { |ln, r| ln.each_char.with_index { |ch, k| b.fill_rect(x + k, y + r, 1, 1, tone(:gold)) if ch == "#" } }
      end

      def lock(b, x, y, colour)
        LOCK.each_with_index { |ln, r| ln.each_char.with_index { |ch, k| b.fill_rect(x + k, y + r, 1, 1, colour) if ch == "#" } }
      end

      def alpha(colour, a)
        return Color.new(colour.red, colour.green, colour.blue, a)
      end

      # The map menus' colours, in the Theme Mode (his pick, 2026-10-21; its
      # popups draw with them too)
      def palette
        return Reloaded::Palette.map_menu
      end
      public :palette              # its popups read it

      # A status colour in the Theme Mode (deeper on Light)
      def tone(name)
        return palette[name]
      end

      # The panel's and tiles' see-through amounts in the Theme Mode
      def panel_alpha
        return Reloaded::Palette.menu_alpha(PANEL_ALPHA)
      end

      def tile_alpha
        return Reloaded::Palette.menu_alpha(TILE_ALPHA)
      end

      # A badge's [fill, words]: dark with the colour's words, or on Light
      # pale with them
      def badge(colour)
        c = palette
        return [alpha(Color.new(colour.red / 4, colour.green / 4, colour.blue / 4), 230), colour] unless c[:light]
        return [Reloaded::Palette.mix(c[:panel2], colour, 0.22), colour]
      end

      def hint_pairs
        return [[:lr, _INTL("Move")], [button(:C), _INTL("Done")]] if @moving
        it = current
        out = [[:lr, _INTL("Choose")]]
        out << [:ud, _INTL("Rows")] if focusable.length > 1
        out << [button(:C), it == :add ? _INTL("Add") : _INTL("Open"), :pick]
        out << [button(:A), _INTL("Edit"), :edit] if it.is_a?(PM::Item) && !PM::SITUATIONAL.include?(it.key)
        out << [button(:X), _INTL("Favorite"), :open_favorite] if @fav
        out << [button(:B), _INTL("Close"), :close_menu]
        return out
      end
    end
  end
end
