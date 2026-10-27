# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Double Abilities' screens and popups
#==============================================================================
# His picks 2026-10-26:
#
#   The Fusion Screen   Q1 Design 1, Columns in the Settings Layout: a Head
#                       and a Body column (the parent's icon, nickname and
#                       species, a HEAD or BODY badge), one row per ability
#                       with its dot; the dot follows the cursor (Q3), a
#                       banned option holds the cursor but not the dot, HIDDEN
#                       on a hidden one. A Fusion heading over Nature, Nickname
#                       (when both are nicknamed, as PIF asks) and Banned
#                       Pairs (OPEN). The description box explains the
#                       highlighted one. A fuses; on a banned option it says
#                       why first (Q22). No Back: PIF asks after the fusion
#   Its columns         Q2: every regular ability of that side, and its
#                       hidden one only when that parent had it. With KIF:
#                       Elite Redux's Innates On (Q2a), the side's three
#                       KIF-ER choices, and its three innates under them as
#                       badges, read only; Banned Pairs reads KIF-ER's Rules
#   Banned Pairs        Q6 Design 1, the Full Page: every pair, a badge each,
#                       the highlighted one's reason in the description box
#   The capsules        Q18: which side first (each with its icon and its
#                       ability now), then that side's list, banned ones
#                       locked and explained
#   Banned Pair         Q22: the notice, OK or Banned Pairs
#
# Off Kanto Reloaded's screens (a scene with no overlay) the capsules use
# the game's own lists.
#==============================================================================

module Reloaded
  #----------------------------------------------------------------------------
  # Shared painting
  #----------------------------------------------------------------------------
  module DoubleAbilitiesLook
    PF = ::KIF::PixelFont
    P = Reloaded::Pixel
    TONES = { :red => :red, :blue => :blue, :amber => :amber, :green => :green }.freeze

    module_function

    def ability_name(id, er = false)
      return ::KIFER.ability_name(id) if er && defined?(::KIFER) && ::KIFER.respond_to?(:ability_name)
      a = ::GameData::Ability.try_get(id)
      return a ? a.name : id.to_s
    end

    def ability_text(id, er = false)
      return ::KIFER.ability_full_text(id) if er && defined?(::KIFER) && ::KIFER.respond_to?(:ability_full_text)
      a = ::GameData::Ability.try_get(id)
      return a ? a.description.to_s : ""
    end

    # A badge in a palette tone (the Bag's pills)
    def pill(b, c, x, y, label, tone, right = false)
      col = c[tone] || c[:dim]
      fill = c[:light] ? Reloaded::Palette.mix(c[:panel2], col, 0.22) : Reloaded::Palette.mix(c[:panel2], col, 0.28)
      return P.pill(b, x, y, label, fill, col, right)
    end

    # A quiet badge (HEAD, BODY, HIDDEN)
    def tag(b, c, x, y, label, right = false)
      return P.pill(b, x, y, label, c[:pill], c[:txt], right)
    end

    def side_tag(side)
      return side == :head ? _INTL("HEAD") : _INTL("BODY")
    end

    def side_word(side)
      return side == :head ? _INTL("head") : _INTL("body")
    end

    # A species' icon as a sprite, its art centred on cx, cy, size px
    # (PartyIcons, as every Kanto Reloaded screen does it); [sprite, bitmap]
    def species_icon(viewport, species, cx, cy, size, z)
      bm = Reloaded::PartyIcons.species_bitmap(species)
      return [nil, nil] unless bm
      s = Sprite.new(viewport)
      s.bitmap = bm
      s.src_rect = Rect.new(0, 0, bm.height, bm.height)
      s.z = z
      Reloaded::PartyIcons.place(s, cx, cy)
      s.zoom_x = s.zoom_y = s.zoom_x * size / Reloaded::PartyIcons::FRAME.to_f
      return [s, bm]
    rescue StandardError
      return [nil, nil]
    end

    # A small padlock, 9 by 10, its top left at x, y (Frame's)
    def lock(b, x, y, color)
      b.fill_rect(x + 1, y, 5, 1, color)
      b.fill_rect(x, y + 1, 1, 3, color)
      b.fill_rect(x + 6, y + 1, 1, 3, color)
      b.fill_rect(x - 1, y + 4, 9, 6, color)
    end

    # The pick dot: filled when picked, a ring otherwise
    def dot(b, c, cx, cy, on, locked = false)
      pp = Reloaded::PartyPaint
      if on
        pp.disc(b, cx, cy, 4, c[:selb])
      else
        pp.disc(b, cx, cy, 4, locked ? Reloaded::Palette.mix(c[:line], c[:panel], 0.4) : c[:line])
        pp.disc(b, cx, cy, 2, c[:panel])
      end
    end
  end

  #----------------------------------------------------------------------------
  # The Fusion Screen
  #----------------------------------------------------------------------------
  class FusionAbilityScreen
    include Reloaded::Frame
    include Reloaded::DoubleAbilitiesLook
    PF = ::KIF::PixelFont
    COLS = { :head => [6, 252], :body => [260, W - 6] }.freeze
    SIDES = [:head, :body].freeze
    DESC_Y = 268

    # fused: the Pokémon fusing (the body's, its species already the
    # fusion's), head: the head's Pokémon, abilities: what each had
    def self.open(fused, head, body_ability, head_ability)
      return new(fused, head, body_ability, head_ability).main
    end

    attr_reader :result

    def initialize(fused, head, body_ability, head_ability)
      frame_init
      @fused = fused
      @head = head
      @da = Reloaded::DoubleAbilities
      @er = @da.elite_redux?(fused)
      had = { :head => head_ability, :body => body_ability }
      @opts = {}
      @pick = {}
      SIDES.each do |s|
        @opts[s] = options(s, had[s])
        @pick[s] = @opts[s].index { |o| o[1] == had[s] } || 0
      end
      settle
      @cur = @pick.dup
      @side = :head
      @row = nil
      @natures = [fused.nature, head.nature].compact
      @nature = 0
      @names = fused.respond_to?(:nicknamed?) && fused.nicknamed? && head.respond_to?(:nicknamed?) && head.nicknamed? ? [fused.name, head.name] : nil
      @name_i = 0
      @rows = [:nature] + (@names ? [:nickname] : []) + [:banned]
      @icons = []
    end

    def main
      open_sprites
      make_icons
      refresh
      loop do
        Graphics.update
        Input.update
        update_frame
        break if handle_input == :fuse
      end
      pbPlayDecisionSE
      return result_hash
    ensure
      @icons.each { |s, bm| s.dispose if s && !s.disposed?; bm.dispose if bm && !bm.disposed? }
      @icons = []
      dispose_sprites
    end

    def refresh
      draw_screen if @sprite && !@sprite.disposed?
    end

    def result_hash
      return { :head => @opts[:head][@pick[:head]], :body => @opts[:body][@pick[:body]],
               :nature => @natures[@nature], :nickname => @names ? @names[@name_i] : nil, :elite_redux => @er }
    end

    private

    def other(side)
      return side == :head ? :body : :head
    end

    # A side's options: [index, id, hidden?] (the fused list's index; with
    # KIF-ER, the choice list's)
    def options(side, had)
      if @er
        er = ::KIFER
        head_n = er.choices_of(@fused.get_head_species.id).length
        sp = side == :head ? @fused.get_head_species.id : @fused.get_body_species.id
        start = side == :head ? 0 : head_n
        return er.choices_of(sp).each_with_index.map { |id, k| [start + k, id, false] }
      end
      return @da.choices(@fused, side, true).reject { |_i, a, h| h && a != had }
    end

    def id_of(side, k)
      o = @opts[side][k]
      return o ? o[1] : nil
    end

    def banned_with_pick(side, k)
      return nil if @er
      return Reloaded::DoubleAbilities::Banned.with(id_of(side, k), id_of(other(side), @pick[other(side)]))
    end

    # The picks start as the parents' own; a banned pair moves the body's
    def settle
      return if @er
      return unless banned_with_pick(:body, @pick[:body])
      ok = (0...@opts[:body].length).find { |k| !banned_with_pick(:body, k) }
      if ok
        @pick[:body] = ok
      else
        @pick[:head] = (0...@opts[:head].length).find { |k| !Reloaded::DoubleAbilities::Banned.banned?(id_of(:head, k), id_of(:body, @pick[:body])) } || @pick[:head]
      end
    end

    def make_icons
      SIDES.each do |s|
        x0, = COLS[s]
        sp = s == :head ? @head.species : @fused.get_body_species.id
        @icons << species_icon(@viewport, sp, x0 + 22, 52, 40, 3)
      end
    end

    #--------------------------------------------------------------------------
    # Input
    #--------------------------------------------------------------------------
    def handle_input
      pt = Reloaded::Pointer
      moved = pointer_hover
      if pt.left?
        handled, r = hint_click
        return r if handled
        hit = click_at(pt.pos)
        return press if hit
      end
      hover_at(pt.pos) if moved
      if Input.trigger?(Input::USE)
        return press
      elsif Input.trigger?(Input::BACK) || pt.right?
        pbPlayBuzzerSE
      elsif Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN)
        step(Input.repeat?(Input::UP) ? -1 : 1)
      elsif Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)
        sideways(Input.trigger?(Input::LEFT) ? -1 : 1)
      end
      return nil
    end

    def step(dir)
      if @row.nil?
        k = @cur[@side] + dir
        if k >= @opts[@side].length
          @row = 0
        elsif k >= 0
          move_to(@side, k)
          return
        else
          return
        end
      else
        r = @row + dir
        return if r >= @rows.length
        @row = r < 0 ? nil : r
      end
      pbPlayCursorSE
      refresh
    end

    def move_to(side, k)
      @side = side
      @row = nil
      @cur[side] = k
      @pick[side] = k unless banned_with_pick(side, k)
      pbPlayCursorSE
      refresh
    end

    def sideways(dir)
      if @row.nil?
        to = other(@side)
        @side = to
        move_to(to, [@cur[to], @opts[to].length - 1].min)
        return
      end
      case @rows[@row]
      when :nature
        return if @natures.length < 2
        @nature = (@nature + dir) % @natures.length
      when :nickname
        @name_i = (@name_i + dir) % @names.length
      else
        return
      end
      pbPlayCursorSE
      refresh
    end

    # A: fuse (a banned option says why first; Banned Pairs opens its page)
    def press
      if @row.nil? && banned_with_pick(@side, @cur[@side])
        pbPlayBuzzerSE
        explain
        return nil
      end
      if @row && @rows[@row] == :banned
        return nil if @er
        pbPlayDecisionSE
        hidden { Reloaded::BannedPairsScreen.open }
        refresh
        return nil
      end
      return :fuse
    end

    def explain
      side = @side
      a = id_of(side, @cur[side])
      b = id_of(other(side), @pick[other(side)])
      pair = Reloaded::DoubleAbilities::Banned.with(a, b)
      c = palette
      kept = ability_name(id_of(side, @pick[side]))
      choice = Reloaded::Dialogs.ask(self, _INTL("Banned Pair"),
                                     _INTL("{1} can't pair with {2}: {3}", ability_name(a), ability_name(b), pair ? pair.reason : ""),
                                     [[_INTL("Pick {1}, or change the {2}'s {3}.", kept, side_word(other(side)), ability_name(b)), c[:dim]]],
                                     [_INTL("OK"), _INTL("Banned Pairs")], 0)
      hidden { Reloaded::BannedPairsScreen.open } if choice == 1
      refresh
    end

    # The mouse: over an option or row puts the cursor there
    def rows_hit
      return @row_boxes || []
    end

    def hover_at(pos)
      hit = box_at(pos)
      return unless hit
      kind, side, k = hit
      if kind == :opt
        return if @row.nil? && @side == side && @cur[side] == k
        move_to(side, k)
      elsif @row != k
        @row = k
        pbPlayCursorSE
        refresh
      end
    end

    def click_at(pos)
      hit = box_at(pos)
      return false unless hit
      hover_at(pos)
      kind, _side, k = hit
      return kind == :row && @rows[k] == :banned
    end

    def box_at(pos)
      return nil unless pos
      x, y = pos
      found = rows_hit.find { |_h, x0, y0, x1, y1| x >= x0 && x <= x1 && y >= y0 && y <= y1 }
      return found ? found[0] : nil
    end

    #--------------------------------------------------------------------------
    # Drawing
    #--------------------------------------------------------------------------
    def col_bottom
      return @er ? 172 : 150
    end

    def row_dy
      return @er ? 23 : 26
    end

    def draw_screen
      c = palette
      base = @sprite.bitmap
      top = @top_sprite.bitmap
      base.clear
      top.clear
      base.fill_rect(0, 0, W, H, c[:bg])
      @cursor_rect = nil
      @row_boxes = []
      paint_title_bar(base, c)
      P.text(top, 0, 2, W, 28, _INTL("Fusion"), c[:title], PF::TITLE, 2)
      SIDES.each { |s| draw_column(base, top, c, s) }
      draw_rows(base, top, c)
      draw_description(base, top, c)
      paint_hints(base, c)
      place_cursor
    end

    def draw_column(base, top, c, side)
      x0, x1 = COLS[side]
      P.ui.rbox(base, x0, 36, x1, col_bottom, 6, c[:panel])
      nick = side == :head ? @head.name : @fused.name
      species = side == :head ? ::GameData::Species.get(@head.species).name : @fused.get_body_species.name
      P.text(top, x0 + 44, 38, 150, 24, PF.fit(PF::ROW, nick.to_s, 130), c[:txt], PF::ROW)
      P.small(top, x0 + 44 + [P.width(PF::ROW, PF.fit(PF::ROW, nick.to_s, 130)), 130].min + 6, 40, 90, 22, species.to_s, c[:dim])
      tag(top, c, x1 - 10, 44, side_tag(side), true)
      base.fill_rect(x0 + 8, 64, x1 - x0 - 16, 1, c[:line])
      dy = row_dy
      @opts[side].each_with_index do |(_i, id, hidden), k|
        y = 68 + k * dy
        ban = banned_with_pick(side, k)
        @row_boxes << [[:opt, side, k], x0 + 4, y, x1 - 4, y + dy - 2]
        @cursor_rect = [x0 + 4, y, x1 - x0 - 8, dy - 1] if @row.nil? && @side == side && @cur[side] == k
        dot(top, c, x0 + 16, y + dy / 2, @pick[side] == k, !ban.nil?)
        P.text(top, x0 + 28, y, 170, dy - 1, PF.fit(PF::ROW, ability_name(id, @er), 150), ban ? c[:dim] : c[:opt], PF::ROW)
        rx = x1 - 10
        rx -= pill(top, c, rx, y + (dy - 15) / 2, _INTL("BANNED"), :red, true) + 4 if ban
        tag(top, c, rx, y + (dy - 15) / 2, _INTL("HIDDEN"), true) if hidden && !ban
      end
      draw_innates(top, c, side, x0, x1) if @er
    end

    # KIF-ER's innates: the side's three, as badges, read only
    def draw_innates(top, c, side, x0, x1)
      P.heading(top, x0 + 12, x1 - 12, 139, _INTL("Innates"), c[:dim], c[:line])
      sp = side == :head ? @head.species : @fused.get_body_species.id
      x = x0 + 12
      ::KIFER.species_innates(sp).each do |id|
        label = ability_name(id, true)
        break if x + P.width(PF::TINY, label) + 12 > x1 - 8
        x += tag(top, c, x, 153, label) + 4
      end
    end

    def draw_rows(base, top, c)
      fy = col_bottom + 4
      gap = @er ? 23 : 28
      P.ui.rbox(base, 6, fy, W - 6, DESC_Y - 4, 6, c[:panel])
      P.heading(top, 16, W - 16, fy + 5, _INTL("Fusion"), c[:head], c[:line])
      @rows.each_with_index do |row, k|
        y = fy + 20 + k * gap
        @row_boxes << [[:row, nil, k], 10, y, W - 10, y + gap - 2]
        @cursor_rect = [10, y, W - 20, gap - 1] if @row == k
        case row
        when :nature
          P.text(top, 22, y, 200, 26, _INTL("Nature"), c[:opt], PF::ROW)
          value(top, c, y, nature_name(@natures[@nature]), @natures.length > 1)
        when :nickname
          P.text(top, 22, y, 200, 26, _INTL("Nickname"), c[:opt], PF::ROW)
          value(top, c, y, @names[@name_i].to_s, true)
        when :banned
          P.text(top, 22, y, 200, 26, _INTL("Banned Pairs"), c[:opt], PF::ROW)
          if @er
            column_pill(top, VALUE_CX, y + 5, _INTL("KIF-ER'S RULES"), c[:pill], c[:dim])
          else
            column_pill(top, VALUE_CX, y + 5, _INTL("OPEN"), c[:pill], c[:txt])
          end
        end
      end
    end

    def value(top, c, y, v, arrows)
      vw = P.width(PF::TEXT, v)
      cx = value_centre(vw)
      P.text(top, cx - vw / 2, y + 2, vw + 2, 22, v, c[:opt])
      return unless arrows
      P.ui.tri(top, cx - vw / 2 - 14, y + 9, :l, c[:dim], 4)
      P.ui.tri(top, cx + vw / 2 + 6, y + 9, :r, c[:dim], 4)
    end

    def nature_name(n)
      return n.respond_to?(:name) ? n.name.to_s : n.to_s
    end

    def nature_text(n)
      ch = n.respond_to?(:stat_changes) ? n.stat_changes : []
      return _INTL("No stat changes.") if ch.nil? || ch.empty?
      up = ::GameData::Stat.get(ch[0][0]).name rescue ch[0][0].to_s
      dn = ::GameData::Stat.get(ch[1][0]).name rescue ch[1][0].to_s
      return _INTL("{1} up, {2} down.", up, dn)
    end

    def draw_description(base, top, c)
      description_box(base, c, DESC_Y)
      if @row
        title, lines = row_text(@rows[@row])
        P.text(top, 14, DESC_Y + 1, 300, 26, title, c[:head], PF::ROW)
        lines.first(DESC_LINES).each_with_index { |(t, col), k| P.small(top, 14, DESC_Y + 28 + k * DESC_DY, W - 34, DESC_DY, t, col || c[:txt]) }
        return
      end
      side = @side
      k = @cur[side]
      id = id_of(side, k)
      P.text(top, 14, DESC_Y + 1, 300, 26, ability_name(id, @er), c[:head], PF::ROW)
      ban = banned_with_pick(side, k)
      x = W - 14
      x -= pill(top, c, x, DESC_Y + 7, _INTL("BANNED"), :red, true) + 6 if ban
      tag(top, c, x, DESC_Y + 7, side_tag(side), true)
      lines = P.small_wrap(top, ability_text(id, @er), W - 34).map { |ln| [ln, c[:txt]] }
      o = other(side)
      oid = id_of(o, @pick[o])
      if ban
        lines = lines.first(1)
        lines << [_INTL("Can't pair with {1}: {2}.", ability_name(oid), ban.short), c[:red]]
        lines << [_INTL("{1} stays picked. Change the {2}'s ability to pick this.", ability_name(id_of(side, @pick[side])), side_word(o)), c[:dim]]
      elsif @er
        lines << [_INTL("All six innates work in battle too."), c[:dim]]
      elsif oid == id
        lines << [_INTL("Same as the {1}'s: Counts Once.", side_word(o)), c[:dim]]
      end
      lines.first(DESC_LINES).each_with_index { |(t, col), n| P.small(top, 14, DESC_Y + 28 + n * DESC_DY, W - 34, DESC_DY, t, col) }
    end

    def row_text(row)
      c = palette
      case row
      when :nature
        n = @natures[@nature]
        return [nature_name(n), [[nature_text(n), c[:txt]], [_INTL("The fusion's nature: The body's or the head's."), c[:dim]]]]
      when :nickname
        return [_INTL("Nickname"), [[_INTL("Both are nicknamed: Pick the fusion's."), c[:txt]]]]
      else
        if @er
          return [_INTL("Banned Pairs"), [[_INTL("With KIF: Elite Redux's Innates On, its own rules apply: Copies stack, and no pair is banned."), c[:txt]]]]
        end
        return [_INTL("Banned Pairs"), [[_INTL("The pairs of abilities a fusion can't have together, and why."), c[:txt]]]]
      end
    end

    def hint_pairs
      if @row
        case @rows[@row]
        when :banned
          return [[:ud, _INTL("Select")], [button(:C), _INTL("Open"), :press_hint]] unless @er
          return [[:ud, _INTL("Select")]]
        else
          return [[:ud, _INTL("Select")], [:lr, _INTL("Change")], [button(:C), _INTL("Fuse"), :press_hint]]
        end
      end
      return [[:lr, _INTL("Head / Body")], [:ud, _INTL("Choose")], [button(:C), _INTL("Fuse"), :press_hint]]
    end

    def press_hint
      return press
    end
  end

  #----------------------------------------------------------------------------
  # Banned Pairs
  #----------------------------------------------------------------------------
  class BannedPairsScreen
    include Reloaded::Frame
    include Reloaded::DoubleAbilitiesLook
    PF = ::KIF::PixelFont
    ROW_Y = 60
    ROW_DY = 28
    VISIBLE = 7
    DESC_Y = 268

    def self.open
      return new.main
    end

    def initialize
      frame_init
      @pairs = Reloaded::DoubleAbilities::Banned.shown
      @index = 0
      @top_row = 0
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

    def refresh
      draw_screen if @sprite && !@sprite.disposed?
    end

    private

    def handle_input
      pt = Reloaded::Pointer
      moved = pointer_hover
      if pt.left?
        handled, r = hint_click
        return r if handled
      end
      return back if Input.trigger?(Input::BACK) || pt.right?
      if moved && (k = row_at(pt.pos)) && k != @index
        @index = k
        pbPlayCursorSE
        refresh
      end
      dir = 0
      dir = -1 if Input.repeat?(Input::UP)
      dir = 1 if Input.repeat?(Input::DOWN)
      dir = pt.wheel if dir == 0 && pt.wheel != 0
      if dir != 0 && @pairs.length > 1
        to = @index + dir
        if to < 0 || to >= @pairs.length
          return nil unless Input.trigger?(Input::UP) || Input.trigger?(Input::DOWN)
          to %= @pairs.length
        end
        @index = to
        @top_row = @index if @index < @top_row
        @top_row = @index - VISIBLE + 1 if @index >= @top_row + VISIBLE
        pbPlayCursorSE
        refresh
      end
      return nil
    end

    def back
      pbPlayCloseMenuSE
      return :close
    end

    def row_at(pos)
      return nil unless pos
      x, y = pos
      return nil unless x >= 10 && x <= W - 10 && y >= ROW_Y && y < ROW_Y + VISIBLE * ROW_DY
      k = @top_row + (y - ROW_Y) / ROW_DY
      return k < @pairs.length ? k : nil
    end

    def draw_screen
      c = palette
      base = @sprite.bitmap
      top = @top_sprite.bitmap
      base.clear
      top.clear
      base.fill_rect(0, 0, W, H, c[:bg])
      @cursor_rect = nil
      paint_title_bar(base, c)
      P.text(top, 0, 2, W, 28, _INTL("Banned Pairs"), c[:title], PF::TITLE, 2)
      P.ui.rbox(base, 6, 36, W - 6, DESC_Y - 4, 6, c[:panel])
      P.text(top, 20, 40, 200, 14, _INTL("Head or Body").upcase, c[:head], PF::TINY)
      P.text(top, 236, 40, 200, 14, _INTL("Can't Pair with").upcase, c[:head], PF::TINY)
      base.fill_rect(14, 56, W - 28, 1, c[:line])
      @pairs[@top_row, VISIBLE].to_a.each_with_index do |p, n|
        i = @top_row + n
        y = ROW_Y + n * ROW_DY
        @cursor_rect = [10, y, W - 20, ROW_DY - 1] if i == @index
        P.text(top, 22, y, 190, 27, ability_name(p.a), c[:opt], PF::ROW)
        P.ui.tri(top, 212, y + 10, :r, c[:dim], 4)
        P.text(top, 236, y, 170, 27, ability_name(p.b), c[:opt], PF::ROW)
        pill(top, c, W - 18, y + 6, p.badge, p.tone, true)
      end
      draw_description(base, top, c)
      paint_hints(base, c)
      place_cursor
    end

    def draw_description(base, top, c)
      description_box(base, c, DESC_Y)
      p = @pairs[@index]
      unless p
        P.small(top, 14, DESC_Y + 28, W - 34, DESC_DY, _INTL("No pair is banned."), c[:dim])
        return
      end
      P.text(top, 14, DESC_Y + 1, 400, 26, _INTL("{1} + {2}", ability_name(p.a), ability_name(p.b)), c[:head], PF::ROW)
      pill(top, c, W - 14, DESC_Y + 7, p.badge, p.tone, true)
      lines = P.small_wrap(top, p.reason, W - 30)
      lines << _INTL("Pick another ability for the head or the body.")
      lines.first(DESC_LINES).each_with_index do |ln, k|
        P.small(top, 14, DESC_Y + 28 + k * DESC_DY, W - 34, DESC_DY, ln, k < lines.length - 1 ? c[:txt] : c[:dim])
      end
    end

    def hint_pairs
      return [[:ud, _INTL("Choose")], [button(:B), _INTL("Back"), :back]]
    end
  end

  #----------------------------------------------------------------------------
  # The capsules' popups
  #----------------------------------------------------------------------------
  module DoubleAbilitiesPopups
    extend Reloaded::DoubleAbilitiesLook
    P = Reloaded::Pixel
    PF = ::KIF::PixelFont
    DL = Reloaded::Dialogs

    module_function

    def dl_private(name, *args, &blk)
      return DL.send(name, *args, &blk)
    end

    # Change Which Ability? Head or Body (each with its icon and its ability
    # now): :head, :body or nil
    def side(scene, pkmn, pair, er = false)
      rows = pair
      icons = []
      index = 0
      DL.hits = []
      result = dl_private(:list_loop, scene, rows.length, index, rows.length) do |i, _top|
        icons.each { |s, bm| s.dispose if s && !s.disposed?; bm.dispose if bm && !bm.disposed? }
        icons = []
        b = scene.overlay
        c = scene.palette
        pw = 300
        ph = 40 + rows.length * 34 + 8 + 50
        px = (Reloaded::Frame::W - pw) / 2
        py = 92
        DL.frame(b, c, px, py, pw, ph, _INTL("Change Which Ability?"))
        hits = []
        rows.each_with_index do |(s, id), k|
          y = py + 44 + k * 34
          dl_private(:cursor_row, b, c, px + 8, y, px + pw - 8, y + 31) if k == i
          sp = s == :head ? pkmn.get_head_species.id : pkmn.get_body_species.id
          icons << species_icon(scene.instance_variable_get(:@viewport), sp, px + 30, y + 16, 34, 99_999)
          P.text(b, px + 52, y + 2, 160, 28, ability_name(id, er), k == i ? c[:strong] : c[:txt], PF::ROW)
          tag(b, c, px + pw - 16, y + 9, side_tag(s), true)
          hits << [k, px + 8, y, px + pw - 8, y + 31]
        end
        DL.hits = hits
        s, id = rows[i]
        o, oid = rows[1 - i]
        dy = py + 44 + rows.length * 34 + 6
        b.fill_rect(px + 10, dy, pw - 20, 1, c[:line])
        text = _INTL("The {1}'s {2} changes; the {3} keeps its {4}.", side_word(s), ability_name(id, er), side_word(o), ability_name(oid, er))
        P.small_wrap(b, text, pw - 28).first(2).each_with_index { |ln, k| P.small(b, px + 14, dy + 5 + k * 17, pw - 28, 17, ln, c[:dim]) }
      end
      return result.nil? ? nil : rows[result][0]
    ensure
      (icons || []).each { |s, bm| s.dispose if s && !s.disposed?; bm.dispose if bm && !bm.disposed? }
    end

    # The side's list: [[index, id, hidden?], ...]; banned ones locked
    # (banned: proc(id) giving the pair or nil). The chosen entry, or nil
    def list(scene, title, entries, banned, er = false)
      return nil if entries.empty?
      index = entries.index { |e| banned.call(e[1]).nil? } || 0
      loop do
        DL.hits = []
        pick = dl_private(:list_loop, scene, entries.length, index, 6) do |i, top|
          index = i
          b = scene.overlay
          c = scene.palette
          pw = 320
          shown = entries[top, 6]
          ph = 40 + shown.length * 28 + 8 + 62
          px = (Reloaded::Frame::W - pw) / 2
          py = 86
          DL.frame(b, c, px, py, pw, ph, title)
          hits = []
          shown.each_with_index do |(_x, id, hidden), n|
            k = top + n
            y = py + 44 + n * 28
            ban = banned.call(id)
            dl_private(:cursor_row, b, c, px + 8, y, px + pw - 8, y + 26) if k == i
            name = ability_name(id, er)
            P.text(b, px + 18, y, 180, 26, name, ban ? c[:dim] : (k == i ? c[:strong] : c[:txt]), PF::ROW)
            lock(b, px + 18 + P.width(PF::ROW, name) + 8, y + 8, c[:dim]) if ban
            rx = px + pw - 16
            rx -= pill(b, c, rx, y + 6, _INTL("BANNED"), :red, true) + 4 if ban
            tag(b, c, rx, y + 6, _INTL("HIDDEN"), true) if hidden
            hits << [k, px + 8, y, px + pw - 8, y + 26]
          end
          DL.hits = hits
          dy = py + 44 + shown.length * 28 + 6
          b.fill_rect(px + 10, dy, pw - 20, 1, c[:line])
          _x, id, = entries[i]
          ban = banned.call(id)
          if ban
            other = ban.a == id ? ban.b : ban.a
            P.small(b, px + 14, dy + 5, pw - 28, 17, _INTL("Locked: Banned with {1}.", ability_name(other)), c[:red])
            P.small_wrap(b, ban.reason, pw - 28).first(2).each_with_index { |ln, k| P.small(b, px + 14, dy + 22 + k * 17, pw - 28, 17, ln, c[:txt]) }
          else
            P.small_wrap(b, ability_text(id, er), pw - 28).first(3).each_with_index { |ln, k| P.small(b, px + 14, dy + 5 + k * 17, pw - 28, 17, ln, c[:txt]) }
          end
        end
        return nil if pick.nil?
        return entries[pick] unless banned.call(entries[pick][1])
        pbPlayBuzzerSE
        index = pick
      end
    end
  end
end
