# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Randomizer's ban lists (Exclusions)
#==============================================================================
# His pick (2026-10-25, design sheet rnd-sub-exclusions, Design 1: Settings
# Layout): cody's four ban lists as a screen of their own, in the Randomizer
# screen's look.
#
#   - the lists in the sidebar (Pokémon, Moves, Abilities, Items), an amber
#     dot where a ban waits for Randomize Now
#   - filter chips over the list: All, Banned (with its count), and
#     Legendary for Pokémon, Physical / Special / Status for moves
#   - rows: Big Pokémon Icons with the dex number, moves in their type's
#     colour with their kind and power, items with their picture and kind;
#     a red BANNED badge, an amber dot on a ban made since Randomize Now
#   - the highlighted one explained in the description box
#   - Search (L1) typed into the title bar; R1 sorts By Number or By Name
#   - A bans or allows, Left / Right a page, Square clears the list (asks),
#     Triangle puts the items' starting list back (asks)
#
# The lists are cody's (KIF::Rand.bans); a change waits for Randomize Now
# like any other (his draft holds the bans).
#==============================================================================

return unless defined?(Reloaded::SplitScreen)

module Reloaded
  class RandomizerBans
    include Reloaded::SplitScreen

    KINDS = [:pokemon, :moves, :abilities, :items].freeze
    SIDE = [["Pokémon", "P", [90, 170, 100]], ["Moves", "M", [200, 100, 170]], ["Abilities", "A", [150, 110, 210]],
            ["Items", "I", [96, 160, 232]]].freeze
    TITLES = { :pokemon => "Banned Pokémon", :moves => "Banned Moves", :abilities => "Banned Abilities",
               :items => "Banned Items" }.freeze
    CHIPS = { :pokemon => [["All", nil], ["Banned", :banned], ["Legendary", :legendary]],
              :moves => [["All", nil], ["Banned", :banned], ["Physical", :physical], ["Special", :special], ["Status", :status]],
              :abilities => [["All", nil], ["Banned", :banned]],
              :items => [["All", nil], ["Banned", :banned]] }.freeze
    KIND_WORDS = { :physical => "Physical", :special => "Special", :status => "Status" }.freeze
    ITEM_CATS = { :ball => "Balls", :medicine => "Medicine", :berry => "Berries", :held => "Held", :tm => "TMs" }.freeze
    PIC_CACHE = 64
    # [id, name, number, right-hand text, type (moves), kind (moves)]
    Entry = Struct.new(:id, :name, :number, :right, :type, :move_kind)

    attr_reader :entry

    # intro: during the New Game intro (no draft: nothing waits)
    def initialize(kind = :pokemon, intro = false)
      frame_init
      @section = KINDS.index(kind) || 0
      @intro = intro
      @focus = :list
      @sel = 0
      @first = 0
      @chip = 0
      @on_chips = false
      @query = nil
      @sort = { :pokemon => :number }
      @entries = {}
      @pics = {}
      @item_pics = {}
    end

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
      return nil
    ensure
      dispose_sprites
      (@pics.values.map(&:first) + @item_pics.values).each { |b| b.dispose if b && !b.disposed? }
      @pics = {}
      @item_pics = {}
    end

    def refresh
      draw_screen if @sprite && !@sprite.disposed?
    end

    # TextEntry (Search) asks for these.
    def entry=(state)
      @entry = state
    end

    def entry_changed
      refresh
    end

    private

    def r
      return ::KIF::Rand
    end

    def kind
      return KINDS[@section]
    end

    def u8(s)
      return PF.utf8(s.to_s)
    end

    # The game's (translated) name and text of a species, move, ability or
    # item
    def name_of(o)
      return u8((o.name rescue nil) || o.real_name)
    end

    def text_of(o)
      return u8((o.description rescue nil) || (o.real_description rescue nil) || "")
    end

    #--------------------------------------------------------------------------
    # The lists (cody's: 004_RandScreen.rb's ban_entries)
    #--------------------------------------------------------------------------
    def entries(k)
      return @entries[k] ||= case k
        when :pokemon
          r.base_species.map { |s| Entry.new(s.species, name_of(s), s.id_number, "") }
        when :moves
          r.move_pool.map do |m|
            mk = r.move_kind(m)
            Entry.new(m.id, name_of(m), m.id_number, move_line(m, mk), m.type, mk)
          end
        when :abilities
          r.all_abilities.map { |a| ::GameData::Ability.get(a) }.map { |a| Entry.new(a.id, name_of(a), a.id_number, "") }
        else
          r.ban_entries(:items).map do |id, _name|
            it = ::GameData::Item.get(id)
            Entry.new(it.id, name_of(it), it.id_number, _INTL(ITEM_CATS[r.item_category(it)] || ""))
          end
        end
    end

    def move_line(m, mk)
      return _INTL("Status") if mk == :status
      return m.base_damage.to_i > 1 ? "#{_INTL(KIND_WORDS[mk])} #{m.base_damage}" : _INTL(KIND_WORDS[mk])   # one-hit moves have power 1
    end

    def bans
      return r.bans(kind)
    end

    def banned?(id, k = kind)
      return r.bans(k).include?(id)
    end

    # Banned now but not when last randomized, or the other way round
    def waiting?(id, k = kind)
      st = r.applied_state
      return false unless st && !@intro
      return banned?(id, k) != Array(st[:"__ban_#{k}"]).include?(id)
    end

    def legendary?(id)
      return defined?(::LEGENDARIES_LIST) && ::LEGENDARIES_LIST.include?(id)
    end

    def by_name?
      return (@sort[kind] || :name) == :name
    end

    # What the list shows: the chip's filter (or the search), sorted
    def rows
      return @rows if @rows
      list = entries(kind)
      if @query
        q = @query.downcase
        list = list.select { |e| e.name.downcase.include?(q) || (kind == :pokemon && e.number.to_s == q.sub(/\A0+/, "")) }
      else
        f = CHIPS[kind][@chip][1]
        list = list.select { |e| banned?(e.id) } if f == :banned
        list = list.select { |e| legendary?(e.id) } if f == :legendary
        list = list.select { |e| e.move_kind == f } if KIND_WORDS.key?(f)
      end
      list = by_name? ? list.sort_by { |e| [e.name.downcase, e.number] } : list.sort_by(&:number)
      return @rows = list
    end

    def current
      return rows[@sel]
    end

    def changed
      @rows = nil
      @sel = [[@sel, rows.length - 1].min, 0].max
    end

    def pick_section(i)
      @section = i
      @chip = 0
      @on_chips = false
      @sel = 0
      @first = 0
      @rows = nil
    end

    def query=(text)
      text = text.to_s.strip
      @query = text.empty? ? nil : text
      @on_chips = false
      @rows = nil
      @sel = 0
      @first = 0
    end

    #--------------------------------------------------------------------------
    # Input
    #--------------------------------------------------------------------------
    def handle_input
      return search if Input.trigger?(Input::JUMPUP) || Input.trigger?(Input::SPECIAL) || clicked?(*left_box)
      return sort if Input.trigger?(Input::R) || clicked?(*right_box)
      handled, result = mouse_input
      return result if handled
      return side_input if @focus == :side
      return chips_input if @on_chips
      return list_input
    end

    def side_input
      n = KINDS.length
      if Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)
        dir = Input.repeat?(Input::DOWN) ? 1 : -1
        target = @section + dir
        if target < 0 || target >= n
          return nil unless fresh?(dir)
          target = dir < 0 ? n - 1 : 0
        end
        pick_section(target)
        pbPlayCursorSE
        refresh
      elsif Input.trigger?(Input::RIGHT) || Input.trigger?(Input::USE)
        @focus = :list
        pbPlayDecisionSE
        refresh
      elsif Input.trigger?(Input::BACK)
        return back
      end
      return nil
    end

    # The chips: Left / Right pick a filter, Down (or A) back to the rows
    def chips_input
      n = CHIPS[kind].length
      if Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)
        @chip = (@chip + (Input.repeat?(Input::RIGHT) ? 1 : -1)) % n
        @rows = nil
        @sel = 0
        @first = 0
        pbPlayCursorSE
        refresh
      elsif Input.trigger?(Input::DOWN) || Input.trigger?(Input::USE)
        return pbPlayBuzzerSE if rows.empty?
        @on_chips = false
        pbPlayCursorSE
        refresh
      elsif Input.trigger?(Input::BACK)
        return back
      end
      return nil
    end

    def list_input
      n = rows.length
      if Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)
        dir = Input.repeat?(Input::DOWN) ? 1 : -1
        target = @sel + dir
        if target < 0 && !@query && Input.trigger?(Input::UP)
          @on_chips = true                    # Up from the top: the chips
          pbPlayCursorSE
          return refresh
        end
        if target < 0 || target >= n
          return nil unless n > 0 && fresh?(dir)
          target = dir < 0 ? n - 1 : 0
        end
        @sel = target
        pbPlayCursorSE
        refresh
      elsif Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)
        page(Input.repeat?(Input::RIGHT) ? 1 : -1)
      elsif Input.trigger?(Input::USE)
        toggle
      elsif Input.trigger?(Input::ACTION)
        clear_all
      elsif Input.trigger?(Input::X)
        starting_list
      elsif Input.trigger?(Input::BACK)
        return back
      end
      return nil
    end

    def page(dir)
      n = rows.length
      return if n == 0
      target = [[@sel + dir * fit, 0].max, n - 1].min
      return if target == @sel
      @sel = target
      pbPlayCursorSE
      refresh
    end

    def mouse_input
      pt = Reloaded::Pointer
      if pointer_hover && !@entry
        if (i = pt.hit(@side_hits))
          if i != @section || @focus != :side
            pick_section(i) if i != @section
            @focus = :side
            pbPlayCursorSE
            refresh
          end
        elsif (k = pt.hit(@row_hits)) && (k != @sel || @focus != :list || @on_chips)
          @focus = :list
          @on_chips = false
          @sel = k
          pbPlayCursorSE
          refresh
        end
      end
      return [true, back] if pt.right?
      dir = pt.wheel
      if dir != 0
        if pt.inside?(LIST_X0, LIST_Y0, LIST_X1, LIST_Y1) && !rows.empty?
          @focus = :list
          @sel = [[@sel + dir, 0].max, rows.length - 1].min
          refresh
        end
        return [true, nil]
      end
      return [false, nil] unless pt.left?
      handled, result = hint_click
      return [true, result] if handled
      if (i = pt.hit(@chip_hits))
        @chip = i
        @rows = nil
        @sel = 0
        @first = 0
        pbPlayCursorSE
        refresh
      elsif (i = pt.hit(@side_hits))
        pick_section(i) if i != @section
        @focus = :list
        pbPlayDecisionSE
        refresh
      elsif (k = pt.hit(@row_hits))
        @sel = k
        toggle
      end
      return [true, nil]
    end

    # B: out of the search, then to the lists, then out of the screen
    def back
      if @query
        pbPlayCancelSE
        self.query = nil
        refresh
        return nil
      end
      if @focus == :list
        pbPlayCancelSE
        @focus = :side
        @on_chips = false
        refresh
        return nil
      end
      pbPlayCloseMenuSE
      return :close
    end

    # A: ban or allow the highlighted one
    def toggle
      e = current
      return pbPlayBuzzerSE unless e
      list = bans
      list.include?(e.id) ? list.delete(e.id) : list << e.id
      pbPlayDecisionSE
      changed
      refresh
      return nil
    end

    # Square: every ban in this list gone (asks)
    def clear_all
      return pbPlayBuzzerSE if bans.empty?
      pbPlayDecisionSE
      text = @intro ? _INTL("Everything in {1} is allowed again.", _INTL(TITLES[kind])) :
                      _INTL("Everything in {1} is allowed again. It waits for Randomize Now.", _INTL(TITLES[kind]))
      if Reloaded::Dialogs.confirm(self, _INTL("Clear All?"), text, _INTL("Clear All"), _INTL("Keep"), false)
        bans.clear
        changed
      end
      refresh
      return nil
    end

    # Triangle (items): the starting list back (cody's items with no use in
    # PIF)
    def starting_list
      return nil unless kind == :items
      pbPlayDecisionSE
      start = r.default_item_bans
      text = _INTL("Banned Items goes back to the {1} items that have no use in PIF.", start.length)
      if Reloaded::Dialogs.confirm(self, _INTL("Starting List?"), text, _INTL("Starting List"), _INTL("Keep"), false)
        bans.replace(start)
        changed
      end
      refresh
      return nil
    end

    # R1: By Number or By Name
    def sort
      pbPlayDecisionSE
      @sort[kind] = by_name? ? :number : :name
      id = current && current.id
      @rows = nil
      @sel = rows.index { |e| e.id == id } || 0
      refresh
      return nil
    end

    # Search, as KIF Settings' works: typed straight into the title bar, the
    # list following as you type; a controller's A opens the naming screen
    def search
      pbPlayDecisionSE
      text, _how = Reloaded::TextEntry.run(self, _INTL("Type to Search"), @query || "", 30,
                                           :prompt => _INTL("Search {1}", _INTL(TITLES[kind])), :down => true) { |t| self.query = t }
      self.query = text
      @focus = :list
      refresh
      return nil
    end

    #--------------------------------------------------------------------------
    # Painting
    #--------------------------------------------------------------------------
    def row_h
      return kind == :pokemon || kind == :items ? 28 : 24
    end

    def list_y0
      return LIST_Y0 + 26
    end

    def fit
      return [(LIST_Y1 - 4 - list_y0) / row_h, 1].max
    end

    def draw_screen
      c = palette
      base = @sprite.bitmap
      top = @top_sprite.bitmap
      base.clear
      top.clear
      base.fill_rect(0, 0, W, H, c[:bg])
      @cursor_rect = nil
      paint_title(base, top, c)
      side = SIDE.each_with_index.map do |(name, letter, rgb), i|
        e = { :name => _INTL(name), :tile => [letter, rgb] }
        e[:dot] = c[:amber] if !@intro && r.applied_state && r.changed?(:"__ban_#{KINDS[i]}")
        e
      end
      paint_sidebar(base, top, c, side, @section, @focus == :side)
      paint_list(base, top, c)
      paint_description(base, top, c)
      paint_hints(base, c)
      place_cursor
    end

    def paint_title(base, top, c)
      paint_title_bar(base, c)
      if @entry
        Reloaded::TextEntry.draw_field(base, top, c, @entry, 8, 4, W - 16, 23, 26)
        magnifier(base, 15, c[:txt], c[:dark])
        if @query
          n = rows.length
          P.small(top, W - 120, 4, 100, 23, n == 1 ? _INTL("1 Found") : _INTL("{1} Found", n), c[:dim], 1)
        end
        return
      end
      P.text(top, 0, 2, W, 28, _INTL("Exclusions"), c[:title], PF::TITLE, 2)
      title_box(base, top, c, 8, @query || _INTL("Search"), :search => true, :active => !@query.nil?)
      title_box(base, top, c, W - 8 - BUTTON_W, by_name? ? _INTL("By Name") : _INTL("By Number"))
      title_keys(top, c, left_key, right_key)
    end

    def paint_list(base, top, c)
      P.ui.rbox(base, LIST_X0, LIST_Y0, LIST_X1, LIST_Y1, 6, c[:panel])
      paint_chips(base, top, c)
      @row_hits = []
      list = rows
      if list.empty?
        msg = @query ? _INTL("Nothing matches \"{1}\".", @query) : _INTL("Nothing here is banned.")
        P.text(top, LIST_X0 + 12, list_y0 + 2, LIST_X1 - LIST_X0 - 24, 22, msg, c[:dim])
        return
      end
      rh = row_h
      @first = @sel if @sel < @first
      @first = @sel - fit + 1 if @sel >= @first + fit
      @first = [[@first, list.length - fit].min, 0].max
      (list[@first, fit] || []).each_with_index do |e, k|
        i = @first + k
        ry = list_y0 + k * rh
        @row_hits << [i, LIST_X0 + 4, ry, LIST_X1 - 10, ry + rh - 2]
        @cursor_rect = [LIST_X0 + 4, ry, LIST_X1 - LIST_X0 - 14, rh - 1] if i == @sel && @focus == :list && !@on_chips && !@entry
        paint_row(top, c, e, ry, rh)
      end
      paint_scrollbar(base, c, LIST_X1 - 5, list.length, fit, @first) if list.length > fit
    end

    def paint_row(top, c, e, ry, rh)
      P.ui.rrect(top, LIST_X0 + 8, ry + rh / 2 - 3, LIST_X0 + 13, ry + rh / 2 + 2, 3, c[:amber]) if waiting?(e.id)
      x = LIST_X0 + 18
      case kind
      when :pokemon
        draw_mon(top, e.id, x, ry + 1, rh - 2)
        x += rh + 2
        P.small(top, x, ry, 30, rh - 1, format("%03d", e.number), c[:dim])
        x += 30
      when :items
        draw_item(top, e.id, x, ry + 2, rh - 4)
        x += rh + 2
      end
      rx = LIST_X1 - 16
      if banned?(e.id)
        rx -= P.pill(top, rx, ry + (rh - 15) / 2, _INTL("BANNED"), Reloaded::RandomizerDraw.tone_fill(c, c[:red]), c[:red]) + 5
      end
      P.small(top, rx - 120, ry, 120, rh - 1, e.right, c[:dim], 1) unless e.right.to_s.empty?
      col = kind == :moves && e.type ? Reloaded::PartyPaint.ink(c, Reloaded::PartyScreen.type_rgb(e.type)) : c[:opt]
      room = rx - x - (e.right.to_s.empty? ? 8 : 60)
      P.text(top, x, ry, room, rh - 1, PF.fit(PF::TEXT, e.name, room), col)
    end

    # Filter chips: the one in use on a soft patch; Banned with its count
    def paint_chips(base, top, c)
      @chip_hits = []
      x = LIST_X0 + 8
      y = LIST_Y0 + 6
      on = @query ? -1 : @chip
      CHIPS[kind].each_with_index do |(label, f), i|
        l = _INTL(label).upcase
        lw = P.width(PF::TINY, l)
        n = f == :banned ? bans.length : nil
        nw = n ? P.width(PF::TINY, n.to_s) + 4 : 0
        w = lw + nw + 14
        P.ui.rbox(base, x, y, x + w, y + 15, 4, Reloaded::RandomizerDraw.tone_fill(c, c[:selb], c[:light] ? 0.25 : 0.35)) if i == on
        @cursor_rect = [x - 1, y - 1, w + 3, 18] if i == @chip && @on_chips && @focus == :list && !@entry
        @chip_hits << [i, x, y, x + w, y + 15]
        P.text(top, x + 7, y, lw + 2, 16, l, i == on ? c[:strong] : c[:dim], PF::TINY)
        P.text(top, x + 7 + lw + 4, y, nw, 16, n.to_s, c[:green], PF::TINY) if n
        x += w + 4
      end
    end

    # A species' picture, fitted to its box (Big Pokémon Icons)
    def draw_mon(b, sp, x, y, size)
      bm, rect = mon_pic(sp)
      return unless bm && rect
      s = [size.to_f / rect.width, size.to_f / rect.height].min
      w = [(rect.width * s).round, 1].max
      h = [(rect.height * s).round, 1].max
      b.stretch_blt(Rect.new(x + (size - w) / 2, y + (size - h) / 2, w, h), bm, rect)
    end

    def mon_pic(sp)
      return @pics[sp] if @pics.key?(sp)
      if @pics.length >= PIC_CACHE
        old, (bm, _r) = @pics.first
        bm.dispose if bm && !bm.disposed?
        @pics.delete(old)
      end
      bm = (Reloaded::PartyIcons.species_bitmap(sp) rescue nil)
      return @pics[sp] = [bm, bm ? Reloaded::PartyIcons.art_rect(bm, bm.height) : nil]
    end

    def draw_item(b, id, x, y, size)
      unless @item_pics.key?(id)
        if @item_pics.length >= PIC_CACHE
          old, bm = @item_pics.first
          bm.dispose if bm && !bm.disposed?
          @item_pics.delete(old)
        end
        file = (::GameData::Item.icon_filename(id) rescue "Graphics/Items/#{id}")
        path = defined?(pbResolveBitmap) ? (pbResolveBitmap(file) || file) : file
        @item_pics[id] = (Bitmap.new(path) rescue nil)
      end
      bm = @item_pics[id]
      b.stretch_blt(Rect.new(x, y, size, size), bm, Rect.new(0, 0, bm.width, bm.height)) if bm
    end

    def paint_description(base, top, c)
      e = @focus == :list && !@on_chips ? current : nil
      unless e
        title = @on_chips && @focus == :list ? _INTL("Filter") : _INTL(TITLES[kind])
        text = @on_chips && @focus == :list ? _INTL("Left and Right pick what the list shows. Down goes back to it.") : kind_text
        return paint_description_box(base, top, c, title, text, :"ban_#{kind}")
      end
      pills = []
      pills << [_INTL("BANNED"), Reloaded::RandomizerDraw.tone_fill(c, c[:red]), c[:red]] if banned?(e.id)
      pills << [_INTL("WAITING"), Reloaded::RandomizerDraw.tone_fill(c, c[:amber]), c[:amber]] if waiting?(e.id)
      title = kind == :pokemon ? "##{format("%03d", e.number)} #{e.name}" : e.name
      paint_description_box(base, top, c, title, describe(e), e, pills)
    end

    def kind_text
      n = bans.length
      wait = @intro ? "" : " " + _INTL("Changes wait for Randomize Now.")
      return _INTL("{1} banned. A bans or allows the highlighted one.", n) + wait
    end

    def describe(e)
      wait = waiting?(e.id) ? " " + _INTL("It waits for Randomize Now.") : ""
      case kind
      when :pokemon
        s = ::GameData::Species.get(e.id)
        types = [s.type1, s.type2].uniq.map { |t| (::GameData::Type.get(t).name rescue t.to_s) }.join(" / ")
        bst = (s.base_stats.values.sum rescue 0)
        head = _INTL("{1}, base stats {2}.", types, bst)
        head += " " + _INTL("Legendary.") if legendary?(e.id)
        tail = banned?(e.id) ? _INTL("Banned: Never picked, not as a wild, trainer, gift or starter Pokémon, nor as half of a fusion.") :
                               _INTL("Can be picked. A bans it.")
        return "#{head} #{tail}#{wait}"
      when :moves
        m = ::GameData::Move.get(e.id)
        a = (m.accuracy rescue 0).to_i
        head = [(::GameData::Type.get(m.type).name rescue m.type.to_s), _INTL(KIND_WORDS[e.move_kind])]
        head << _INTL("Power {1}", m.base_damage) if m.base_damage.to_i > 1
        head << _INTL("Accuracy {1}", a) if a > 0
        sure = a > 0 ? "" : " " + _INTL("It never misses.")
        tail = banned?(e.id) ? " " + _INTL("Banned: A rolled learnset never gets it.") : ""
        return "#{head.join(", ")}.#{sure} #{text_of(m)}#{tail}#{wait}"
      when :abilities
        a = ::GameData::Ability.get(e.id)
        tail = banned?(e.id) ? " " + _INTL("Banned: Abilities and Per Pokémon never roll it.") : ""
        return "#{text_of(a)}#{tail}#{wait}"
      end
      it = ::GameData::Item.get(e.id)
      tail = r.default_item_bans.include?(e.id) ? " " + _INTL("Banned from the start: It has no use in PIF.") : ""
      return "#{text_of(it)}#{tail}#{wait}"
    end

    def hint_pairs
      pr = Reloaded::Prompts
      back = button(:B)
      if @entry
        if pr.controller?
          return [[button(:C), _INTL("Type")], [:d, _INTL("Results")], [back, _INTL("Done")]]
        end
        enter = Reloaded::Controls::Inputs.key(40)
        esc = Reloaded::Controls::Inputs.key(41)
        return [[nil, _INTL("Type to Search")], [enter, _INTL("Results")], [esc, _INTL("Done")]]
      end
      return [[:ud, _INTL("List")], [:lr, _INTL("Open")], [back, _INTL("Back"), :back]] if @focus == :side
      return [[:lr, _INTL("Filter")], [:d, _INTL("Rows")], [back, _INTL("Lists"), :back]] if @on_chips
      e = current
      out = [[:ud, _INTL("Choose")]]
      out << [:lr, _INTL("Page")] unless @query
      out << [button(:C), e && banned?(e.id) ? _INTL("Allow") : _INTL("Ban"), :toggle] if e
      out << [button(:A), _INTL("Clear All"), :clear_all] unless bans.empty? || @query
      out << [button(:X), _INTL("Starting List"), :starting_list] if kind == :items && !@query
      out << [back, @query ? _INTL("Clear") : _INTL("Lists"), :back]
      return out
    end
  end
end
