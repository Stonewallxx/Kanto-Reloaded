#==============================================================================
# Kanto Reloaded: the Overworld Menu's screen
#==============================================================================
# Tabbed Panel (Roadmap topic 35, design 4), over the map:
#
#   left          the title, the page tabs, the page's entries (icon, name,
#                 live status) and under them the Quick Items bar (7 slots)
#   top right     where you are: the map, the weather and the time of day,
#                 and how many of the Pokémon found here you've caught
#   right side    a view, Y steps through them (and none): Party View,
#                 Full (big cards down the right side: the battle sprite,
#                 name, level, types, HP, status, held item) or Compact (each
#                 Pokémon's name, HP and status at the bottom right, three to
#                 a row), as its setting says; later views of features'
#
# Controller first. In the list: Up/Down choose, Left/Right change pages, A
# uses (a toggle's switch flips, a choice opens its dropdown, a number its
# slider), X edits the pages, B closes, and so does the Overworld Menu's own
# button; Y steps through the views. On the
# Quick Items bar: Left/Right choose, A uses the item (or picks one for an
# empty slot), X changes or clears it, B goes back. The mouse: hover picks,
# a click uses, a click on a tab turns to it, the wheel scrolls, a right
# click closes.
#
# The colours follow Theme Mode (his pick, 2026-10-21): Dark and Glass the
# Theme's own, Light and Frost the Light frames' look; Glass and Frost
# see-through (Reloaded::Palette.map_menu, menu_alpha). Its popups too.
#
# Opening slides the panel in and fades the rest (Menu Animations). An entry
# that opens another screen hides this one meanwhile (hidden); one that needs
# the map (Fly, Quick Save, Quit) runs once it has closed.
#==============================================================================

return unless defined?(Reloaded::Frame) && defined?(::KIF::PixelFont)

module Reloaded
  class OverworldMenuScreen
    include Reloaded::Frame

    PF = ::KIF::PixelFont
    P = Reloaded::Pixel
    OM = Reloaded::OverworldMenu
    PANEL_X0 = 6
    PANEL_X1 = 232
    PANEL_Y0 = 6
    PANEL_Y1 = 292
    TABS_Y = 38
    ROWS_Y = 60
    ROW_H = 28
    ROWS = 8
    QUICK_Y0 = 296
    QUICK_Y1 = H - P::HINT_H - 6
    SLOT = 28
    SLOT_STEP = 31
    SLOT_X0 = 12
    SLOT_Y = 316
    AREA_X0 = 300
    AREA_X1 = W - 6
    CARD_X0 = 236
    CARD_W = 88               # Compact: three to a row, on the bottom edge
    CARD_H = 50
    CARD_GAP = 3
    CARD_Y0 = 250
    FULL_X0 = 236             # Full (design 1, Two Columns): two to a row,
    FULL_W = 133              # three rows, under the area panel (Y hides
    FULL_H = 93               # the view when it's in the way)
    FULL_Y0 = 66
    FULL_INFO_X = 64          # the info column: centred between here and the edge
    TYPE_ICONS = "Graphics/OverworldMenu/typesSmall16"   # the game's small type icons at 16 px
    TYPE_PX = 16
    MALE = ["..####", "....##", "...#.#", ".##...", "#..#..", "#..#..", ".##..."].freeze
    FEMALE = [".###.", "#...#", "#...#", ".###.", "..#..", ".###.", "..#.."].freeze
    PINK = Color.new(240, 130, 160)
    STATUS = { :SLEEP => ["SLP", [150, 160, 175]], :POISON => ["PSN", [190, 110, 220]], :BURN => ["BRN", [240, 130, 70]],
               :PARALYSIS => ["PAR", [240, 210, 70]], :FROZEN => ["FRZ", [120, 200, 240]] }.freeze
    PANEL_ALPHA = 232
    GREEN = Color.new(120, 230, 150)
    GOLD  = Color.new(240, 200, 80)
    RED   = Color.new(240, 100, 90)
    AMBER = Color.new(240, 170, 60)
    BLUE  = Color.new(130, 190, 250)
    LOCK = [".###.", "#...#", "#...#", "#####", "##.##", "##.##", "#####"].freeze
    # The ∞ mark (Infinite Repel, Infinite Safari), drawn at 2 px a dot
    INFINITY = [".###...###.", "#...#.#...#", "#....#....#", "#...#.#...#", ".###...###."].freeze
    SLIDER_H = 54             # the Dropped Slider's panel
    WEATHER = { :Rain => "Rain", :Storm => "Thunderstorm", :Snow => "Snow", :Blizzard => "Blizzard",
                :Sandstorm => "Sandstorm", :HeavyRain => "Heavy Rain", :Sun => "Harsh Sun", :Fog => "Fog" }.freeze

    attr_reader :focus, :sel, :slot

    def initialize
      frame_init
      @page = OM.page_index
      @sel = 0
      @scroll = 0
      @slot = 0
      @focus = :list
      @icons = {}
      @cards = []
      @own_bitmaps = []          # the battle sprites Full made
      @after = nil
    end

    def main
      open_sprites
      @left = Sprite.new(@viewport)
      @left.bitmap = Bitmap.new(W, H)
      @left.z = 0
      build_cards
      refresh
      animate(:in)
      loop do
        Graphics.update
        Input.update
        pbUpdateSceneMap if defined?(pbUpdateSceneMap)
        update_frame
        @cards.each { |s| s.update if !s.disposed? && s.respond_to?(:update) }     # icons animate
        refresh if @frame % 40 == 0                 # live statuses (Repel steps, the clock)
        result = handle_input
        next if result.nil?
        @after = result if result.respond_to?(:call)
        break
      end
      animate(:out)
      return @after
    ensure
      close
    end

    # The map menus' colours, in the Theme Mode (its popups draw with them too)
    def palette
      return Reloaded::Palette.map_menu
    end

    def refresh
      return unless @sprite && !@sprite.disposed?
      c = palette
      base = @sprite.bitmap
      top = @top_sprite.bitmap
      base.clear
      top.clear
      @left.bitmap.clear
      @hits = []
      @cursor_rect = nil
      paint_panel(c)
      paint_quick(c)
      paint_area(base, top, c)
      paint_cards(base, top, c)
      paint_hints(base, c)
      place_cursor
    end

    #--------------------------------------------------------------------------
    # For entries (Reloaded::OverworldMenu::Entries)
    #--------------------------------------------------------------------------
    def focus_quick_items
      @focus = :quick
      pbPlayCursorSE
      refresh
    end

    def notice(title, text)
      Reloaded::Dialogs.notice(self, title, text)
      refresh
    end

    def confirm(title, text)
      ok = Reloaded::Dialogs.confirm(self, title, text, _INTL("Yes"), _INTL("No"), false)
      refresh
      return ok
    end

    # An item used the way the game uses one (Quick Items, Last Used Item): a
    # field item once this menu has closed, any other from here.
    def use_item(item)
      unless item && OM.has_item?(item)
        pbPlayBuzzerSE
        notice(item ? item_name(item) : _INTL("Item"), _INTL("You don't have any right now."))
        return nil
      end
      pbPlayDecisionSE
      if defined?(::ItemHandlers) && ::ItemHandlers.hasUseInFieldHandler(item)
        return proc { pbUseKeyItemInField(item) if ::ItemHandlers.triggerConfirmUseInField(item) }
      end
      result = 0
      hidden { result = pbUseItem($PokemonBag, item) } if defined?(pbUseItem)
      build_cards
      refresh
      return result == 2 ? :close : nil
    rescue StandardError => e
      Reloaded::Log.exception("An item couldn't be used from the Overworld Menu", e, :overworld_menu)
      pbPlayBuzzerSE
      return nil
    end

    # A KIF Settings button on a page (Change Controls...): pressed as KIF
    # Settings presses it, this menu out of sight meanwhile. Edit Pages can
    # take pages away, so the page stays in range.
    def press_setting(e)
      hidden { Reloaded::OverworldMenu::SettingRows.press(e.key) }
      @page = [[@page, OM.pages.length - 1].min, 0].max
      return nil
    end

    # A choice's row (a setting from Edit Pages > Add a Setting, a Quality
    # of Life choice, Speed-Up): its dropdown, dropped from the row's value
    # as in KIF Settings, the highlighted choice explained under it; the map
    # keeps moving.
    def choice_dropdown(e)
      return nil unless e.values && e.get && e.set
      rows = Reloaded::OverworldMenu::SettingRows
      y = (@cursor_rect || [0, PANEL_Y0])[1]
      anchor = [PANEL_X1 - 84, y + 2, PANEL_X1 - 8, y + ROW_H - 4]
      bounds = [PANEL_X0 + 4, PANEL_Y0 + 4, W - 8, QUICK_Y0 - 4]
      locked = rows.setting?(e.key) ? rows.locked_choices(e.key) : []
      cur = e.get.call.to_i
      values = (0...e.values.length).map { |i| PF.utf8(_INTL(e.values[i].to_s)) }
      dd = Reloaded::Dropdown.new(values, cur, anchor, bounds, :locked => locked, :cursor => false)
      pbPlayDecisionSE
      @choice_dd = dd
      refresh
      choice = nil
      redraw = true
      loop do
        if redraw
          paint_choice_dropdown(dd, values, e)
          redraw = false
        end
        Graphics.update
        Input.update
        pbUpdateSceneMap if defined?(pbUpdateSceneMap)
        event = dd.update
        if event == :pick
          choice = dd.index
          break
        end
        break if event == :close
        redraw = true if event
      end
      e.set.call(choice) if choice && choice != cur
      return nil
    ensure
      @choice_dd = nil
      overlay.clear
      refresh
    end

    def paint_choice_dropdown(dd, values, e)
      o = overlay
      c = palette
      o.clear
      dd.draw(o, c)
      # the highlighted choice, explained above the hint line
      y0 = QUICK_Y0
      y1 = QUICK_Y1
      P.ui.rbox(o, PANEL_X0, y0, W - 6, y1, 7, c[:panel2], c[:line])
      P.text(o, PANEL_X0 + 10, y0 + 3, W - 32, 18, values[dd.index].to_s, c[:head], PF::TEXT)
      words = (e.explain ? e.explain.call(dd.index) : nil).to_s
      words = e.description.to_s if words.empty?
      P.wrap(_INTL(words), W - 40, PF::TINY).first(3).each_with_index do |ln, i|
        P.text(o, PANEL_X0 + 10, y0 + 22 + i * 12, W - 32, 12, ln, c[:txt], PF::TINY)
      end
    end

    # A slider or number's row (Dropped Slider, his pick 2026-10-21): a panel
    # dropped over the rows under it (above it near the bottom), as a
    # choice's dropdown drops, with the value, its lowest and highest, and a
    # bar. Left/Right change it a step, L/R ten steps, the wheel a step; a
    # click on the bar puts it there. A (or a click off the bar) sets it, B
    # (or a right click) leaves it as it was. The map keeps moving.
    def number_slider(e)
      return nil unless e.range && e.get && e.set
      min, max, step = e.range
      step = [step.to_i, 1].max
      cur = e.get.call.to_i
      value = [[cur, min].max, max].min
      y = (@cursor_rect || [0, ROWS_Y])[1]
      top = y + ROW_H - 1
      top = y - SLIDER_H + 1 if top + SLIDER_H > QUICK_Y0 - 2
      @slider = [step]
      pbPlayDecisionSE
      refresh
      chosen = nil
      redraw = true
      loop do
        if redraw
          paint_slider(e, value, top)
          redraw = false
        end
        Graphics.update
        Input.update
        pbUpdateSceneMap if defined?(pbUpdateSceneMap)
        pt = Reloaded::Pointer
        delta = 0
        delta = -step if Input.repeat?(Input::LEFT)
        delta = step if Input.repeat?(Input::RIGHT)
        delta = -step * 10 if Input.repeat?(Input::JUMPUP)
        delta = step * 10 if Input.repeat?(Input::JUMPDOWN)
        delta = -step * pt.wheel if delta == 0          # the wheel: up adds
        if pt.right? || Input.trigger?(Input::BACK)
          pbPlayCancelSE
          break
        elsif pt.left?
          at = slider_value_at(pt.pos, min, max, step)
          if at.nil?
            pbPlayDecisionSE
            chosen = value
            break
          end
          if at != value
            value = at
            pbPlayCursorSE
            redraw = true
          end
        elsif delta != 0
          target = [[value + delta, min].max, max].min
          if target != value
            value = target
            pbPlayCursorSE
            redraw = true
          end
        elsif Input.trigger?(Input::USE)
          pbPlayDecisionSE
          chosen = value
          break
        end
      end
      e.set.call(chosen) if chosen && chosen != cur
      return nil
    ensure
      @slider = nil
      @slider_bar = nil
      overlay.clear
      refresh
    end

    def paint_slider(e, value, top)
      o = overlay
      c = palette
      o.clear
      min, max, _step, unit = e.range
      x0 = PANEL_X0 + 4
      x1 = PANEL_X1 - 2
      Reloaded::Dialogs.send(:panel, o, c, x0, top, x1 - x0, SLIDER_H)
      P.small(o, x0 + 10, top + 6, 60, 16, "#{min}#{unit}", c[:dim], 0)
      P.text(o, x0, top + 3, x1 - x0, 20, "#{value}#{unit}", tone(:gold), PF::ROW, 2)
      P.small(o, x1 - 70, top + 6, 60, 16, "#{max}#{unit}", c[:dim], 1)
      bx0 = x0 + 14
      bx1 = x1 - 14
      by = top + 34
      span = [max - min, 1].max
      kx = bx0 + ((bx1 - bx0) * (value - min).to_f / span).round
      P.ui.rbox(o, bx0, by, bx1, by + 6, 3, c[:dark], c[:line])
      P.ui.rbox(o, bx0, by, kx, by + 6, 3, c[:selb]) if kx > bx0
      P.ui.rbox(o, kx - 5, by - 4, kx + 5, by + 10, 3, c[:txt], c[:selb])
      @slider_bar = [bx0, by - 8, bx1, by + 14]
    end

    # The value at a click on the slider's bar (to its step), or nil off it
    def slider_value_at(pos, min, max, step)
      return nil unless pos && @slider_bar
      bx0, y0, bx1, y1 = @slider_bar
      return nil unless pos[0] >= bx0 - 6 && pos[0] <= bx1 + 6 && pos[1] >= y0 && pos[1] <= y1
      frac = [[(pos[0] - bx0).to_f / [bx1 - bx0, 1].max, 0].max, 1].min
      v = min + ((max - min) * frac / step).round * step
      return [[v, min].max, max].min
    end

    # Area Encounters: Design 1, Wild Link's List (his pick, 2026-10-20),
    # with Bigger Rows (2026-10-21): each Pokémon trimmed and fitted to
    # ENC_ICON
    ENC_W = 392
    ENC_ROWS = 6                        # rows in its list at most (less when no tab here needs them)
    ENC_ROW_H = 36                      # a Pokémon's row
    ENC_HEAD_H = 22                     # a heading (each rod)
    ENC_ICON = 34

    # Area Encounters, Wild Link's list in a popup (so the quick look and
    # the DexNav match): a tab for each way the wild Pokémon here are met,
    # Seen and Caught for it, and a row each with the icon (a silhouette
    # until seen), a ball once caught, its levels and how often it appears;
    # each rod under its own heading. It opens on Surfing while you surf.
    # Left/Right or a click change the tab, Up/Down or the wheel scroll a
    # long one; B, A or a right click close it.
    def area_encounters
      tabs = Reloaded::OverworldMenu::Entries.area_tabs
      return nil if tabs.empty?
      pbPlayDecisionSE
      surfing = $PokemonGlobal && $PokemonGlobal.respond_to?(:surfing) && $PokemonGlobal.surfing
      tab = (surfing && tabs.index { |t, _s| t == "Surfing" }) || 0
      top = 0
      lines = nil
      @enc_list_h = [tabs.map { |_t, sections| encounter_lines(sections).sum { |l| encounter_line_h(l) } }.max,
                     ENC_ROWS * ENC_ROW_H].min
      @enc_icons = Array.new(ENC_ROWS) do
        sp = Sprite.new(@viewport)
        sp.z = 4
        sp.visible = false
        sp
      end
      @enc_bitmaps = {}
      @enc_arts = {}
      redraw = true
      loop do
        if redraw
          lines = encounter_lines(tabs[tab][1])
          @encounters = [tabs.length > 1, encounter_most(lines) > 0]
          refresh
          paint_encounters(tabs, tab, lines, top)
          redraw = false
        end
        Graphics.update
        Input.update
        pbUpdateSceneMap if defined?(pbUpdateSceneMap)
        pt = Reloaded::Pointer
        wheel = pt.wheel
        move = Input.repeat?(Input::RIGHT) ? 1 : (Input.repeat?(Input::LEFT) ? -1 : 0)
        clicked = pt.left? ? encounter_tab_at(pt.pos) : nil
        step = Input.repeat?(Input::DOWN) || wheel > 0 ? 1 : (Input.repeat?(Input::UP) || wheel < 0 ? -1 : 0)
        if (move != 0 && tabs.length > 1) || (clicked && clicked != tab)
          tab = clicked || (tab + move) % tabs.length
          top = 0
          pbPlayCursorSE
          redraw = true
        elsif step != 0
          t = [[top + step, 0].max, encounter_most(lines)].min
          if t != top
            top = t
            pbPlayCursorSE
            redraw = true
          end
        elsif Input.trigger?(Input::BACK) || Input.trigger?(Input::USE) || pt.right?
          pbPlayCancelSE
          break
        end
      end
      return nil
    ensure
      (@enc_icons || []).each { |sp| sp.dispose unless sp.disposed? }
      (@enc_bitmaps || {}).each_value { |bm| bm.dispose if bm && !bm.disposed? }
      @enc_icons = @enc_bitmaps = @enc_arts = @enc_tab_hits = @enc_list_h = nil
      @encounters = nil
      overlay.clear
      refresh
    end

    # A tab's lines: [:head, words] and [:row, rate, species, min, max]
    def encounter_lines(sections)
      lines = []
      sections.each do |words, rows|
        lines << [:head, words] if words
        rows.each { |r| lines << [:row, *r] }
      end
      return lines
    end

    def encounter_line_h(l)
      return l[0] == :head ? ENC_HEAD_H : ENC_ROW_H
    end

    # How far a tab scrolls: the first line from which the rest fit
    def encounter_most(lines)
      rest = 0
      (lines.length - 1).downto(0) do |i|
        rest += encounter_line_h(lines[i])
        return i + 1 if rest > @enc_list_h
      end
      return 0
    end

    def paint_encounters(tabs, tab, lines, top)
      o = overlay
      c = palette
      Reloaded::Dialogs.send(:dim, o)
      h = 60 + @enc_list_h + 8
      x = (W - ENC_W) / 2
      y = (H - P::HINT_H - h) / 2
      Reloaded::Dialogs.send(:panel, o, c, x, y, ENC_W, h)
      Reloaded::Dialogs.send(:title_bar, o, c, x, y, ENC_W, _INTL("Area Encounters"))
      # the tabs, as the menu's page tabs
      @enc_tab_hits = []
      tx = x + 10
      tabs.each_with_index do |(words, _sections), i|
        label = _INTL(words).upcase
        tw = P.width(PF::TINY, label) + 14
        P.ui.rbox(o, tx, y + 40, tx + tw, y + 57, 4, Reloaded::Palette.mix(c[:selb], c[:panel2], 0.7), c[:selb]) if i == tab
        P.text(o, tx, y + 40, tw, 18, label, i == tab ? c[:txt] : c[:dim], PF::TINY, 2)
        @enc_tab_hits << [i, tx, y + 40, tx + tw, y + 57]
        tx += tw + 4
      end
      # Seen and Caught for this tab, shorter when the tabs leave less room
      species = lines.select { |l| l[0] == :row }.map { |l| l[2] }.uniq
      seen = species.count { |sp| encounter_state(sp) != :unseen }
      caught = species.count { |sp| encounter_state(sp) == :caught }
      room = x + ENC_W - 10 - tx
      seen_words = _INTL("Seen {1}/{2}", seen, species.length)
      caught_words = _INTL("Caught {1}/{2}", caught, species.length)
      P.small_font(o)
      sw = o.text_size(seen_words).width
      cw = o.text_size(caught_words).width
      P.small(o, tx, y + 41, room, 16, caught_words, c[:dim], 1) if cw <= room
      P.small(o, tx, y + 41, room - cw - 14, 16, seen_words, c[:dim], 1) if sw + 14 + cw <= room
      # the rows
      most = encounter_most(lines)
      rw = ENC_W - (most > 0 ? 24 : 12)
      @enc_icons.each { |sp| sp.visible = false }
      ly = y + 62
      icon = 0
      lines[top..-1].each do |l|
        lh = encounter_line_h(l)
        break if ly + lh > y + 62 + @enc_list_h
        if l[0] == :head
          P.heading(o, x + 12, x + rw, ly + 5, _INTL(l[1]).upcase, c[:head], c[:line])
        else
          _kind, rate, sp, lo, hi = l
          state = encounter_state(sp)
          encounter_icon(@enc_icons[icon], sp, x + 28, ly + lh / 2, state == :unseen)
          icon += 1
          P.poke_ball(o, x + 50, ly + lh / 2 - 6, 11) if state == :caught
          name = state == :unseen ? "???" : encounter_name(sp)
          P.text(o, x + 66, ly + (lh - 18) / 2, rw - 178, 18, PF.fit(PF::TEXT, name, rw - 178), state == :unseen ? c[:dim] : c[:txt], PF::TEXT)
          P.small(o, x + 6 + rw - 112, ly + (lh - 16) / 2, 70, 16, lo == hi ? _INTL("Lv {1}", lo) : _INTL("Lv {1}-{2}", lo, hi), c[:dim])
          P.small(o, x + 6 + rw - 46, ly + (lh - 16) / 2, 38, 16, "#{rate}%", c[:dim], 1)
        end
        ly += lh
      end
      if most > 0
        P.ui.tri(o, x + ENC_W - 14, y + 66, :u, top > 0 ? c[:txt] : c[:dim], 3)
        P.ui.tri(o, x + ENC_W - 14, y + h - 14, :d, top < most ? c[:txt] : c[:dim], 3)
      end
    end

    # :caught, :seen or :unseen, from the Pokédex
    def encounter_state(sp)
      dex = $Trainer.pokedex
      return :caught if (dex.owned?(sp) rescue false)
      return (dex.seen?(sp) rescue false) ? :seen : :unseen
    end

    def encounter_name(sp)
      return ::GameData::Species.get(sp).name.to_s
    rescue StandardError
      return sp.to_s.capitalize
    end

    # A row's icon: the species' Pokémon, trimmed and fitted to ENC_ICON, or
    # its silhouette (a sprite over the popup, tinted: as Wild Link's unseen
    # ones)
    def encounter_icon(spr, sp, cx, cy, unseen)
      unless @enc_bitmaps.key?(sp)
        bm = encounter_bitmap(sp)
        @enc_bitmaps[sp] = bm
        # the Pokémon itself in the first frame (a frame is as wide as the
        # icon is tall), so it fills its box rather than the frame does
        @enc_arts[sp] = bm ? Reloaded::PartyIcons.art_rect(bm, [bm.height, 1].max) : nil
      end
      bm = @enc_bitmaps[sp]
      r = @enc_arts[sp]
      return unless bm && r
      spr.bitmap = bm
      spr.src_rect = Rect.new(r.x, r.y, r.width, r.height)
      spr.zoom_x = spr.zoom_y = ENC_ICON.to_f / [r.width, r.height, 1].max
      spr.ox = r.width / 2
      spr.oy = r.height / 2
      spr.x = cx
      spr.y = cy
      spr.color = unseen ? Color.new(12, 14, 22) : Color.new(0, 0, 0, 0)
      spr.visible = true
    end

    # Big Pokémon Icons or small, as the player has it
    def encounter_bitmap(sp)
      return Reloaded::PartyIcons.species_bitmap(sp)
    end

    # The tab under the mouse, or nil
    def encounter_tab_at(pos)
      return nil unless pos && @enc_tab_hits
      hit = @enc_tab_hits.find { |_i, x0, y0, x1, y1| pos[0] >= x0 && pos[0] <= x1 && pos[1] >= y0 && pos[1] <= y1 }
      return hit ? hit[0] : nil
    end

    # Day Care: Design 1, the Egg Manager's Panel (his pick, 2026-10-20)
    DC_W = 300
    COMPAT_WORDS = ["They Prefer to Play with Others", "They Don't Seem to Like Each Other",
                    "They Seem to Get Along", "They Get Along Very Well"].freeze

    # A on the Day Care readout: the Egg Manager's Day Care tab as a popup
    # (so the two match): the two side by side, how well they get along
    # (hearts), each one's levels gained and what taking it back costs, and
    # the Egg waiting. B, A or a right click close it; the map keeps moving.
    def day_care
      ent = Reloaded::OverworldMenu::Entries
      mons = ent.day_care
      pbPlayDecisionSE
      @day_care_open = true
      refresh
      @dc_icons = mons.map { |pk, _lv, _i| Reloaded::PartyIcons.icon(pk, @viewport, 4) }
      paint_day_care(mons, ent.day_care_egg?, ent.day_care_compat)
      loop do
        Graphics.update
        Input.update
        pbUpdateSceneMap if defined?(pbUpdateSceneMap)
        @dc_icons.each { |sp| sp.update if sp && !sp.disposed? && sp.respond_to?(:update) }
        break if Input.trigger?(Input::BACK) || Input.trigger?(Input::USE) || Reloaded::Pointer.right?
      end
      pbPlayCancelSE
      return nil
    ensure
      (@dc_icons || []).each { |sp| sp.dispose if sp && !sp.disposed? }
      @dc_icons = nil
      @day_care_open = nil
      overlay.clear
      refresh
    end

    def paint_day_care(mons, egg, compat)
      o = overlay
      c = palette
      Reloaded::Dialogs.send(:dim, o)
      two = mons.length == 2
      h = 40 + mons.length * 24 + 8
      h += 64 unless mons.empty?          # the icons
      h += 34 if two                      # how well they get along
      h += 30 if mons.empty?              # nobody there
      h += 56 if egg
      x = (W - DC_W) / 2
      y = (H - P::HINT_H - h) / 2
      Reloaded::Dialogs.send(:panel, o, c, x, y, DC_W, h)
      Reloaded::Dialogs.send(:title_bar, o, c, x, y, DC_W, _INTL("Day Care"))
      cy = y + 40
      unless mons.empty?
        xs = two ? [x + DC_W / 2 - 50, x + DC_W / 2 + 50] : [x + DC_W / 2]
        @dc_icons.each_with_index { |sp, i| Reloaded::PartyIcons.place(sp, xs[i], cy + 30) if sp }
        cy += 64
      end
      if two
        P.text(o, x, cy - 4, DC_W, 13, _INTL(COMPAT_WORDS[compat]).upcase, tone(:pink), PF::TINY, 2)
        3.times do |i|
          hx = x + DC_W / 2 - 22 + i * 16
          P.ui.rbox(o, hx, cy + 12, hx + 10, cy + 22, 5, i < compat ? tone(:pink) : c[:dark], i < compat ? tone(:pink) : c[:line])
        end
        cy += 34
      end
      mons.each do |pk, lv, slot|
        gained = pk.level - lv.to_i
        levels = gained == 1 ? _INTL("+1 Level") : _INTL("+{1} Levels", gained)
        cost = Reloaded::OverworldMenu::Entries.day_care_cost(slot, pk, lv)
        cost = cost.respond_to?(:to_s_formatted) ? cost.to_s_formatted : cost.to_s
        P.text(o, x + 14, cy, 130, 20, PF.fit(PF::TEXT, pk.name.to_s, 130), c[:txt], PF::TEXT)
        P.small(o, x + DC_W - 164, cy + 2, 150, 16, _INTL("{1} · ${2}", levels, cost), c[:dim], 1)
        cy += 24
      end
      if mons.empty?
        P.small(o, x, cy + 6, DC_W, 16, _INTL("No Pokémon are there."), c[:dim], 2)
        cy += 30
      end
      return unless egg
      o.fill_rect(x + 12, cy + 4, DC_W - 24, 1, c[:line])
      egg_icon(o, x + 30, cy + 32)
      P.text(o, x + 52, cy + 14, 200, 20, _INTL("An Egg Is Waiting"), tone(:gold), PF::TEXT)
      P.small(o, x + 52, cy + 34, DC_W - 64, 16, _INTL("Collect it from the Day Care Man."), c[:dim])
    end

    # The Egg, 34 px, centred at cx, cy (Big Pokémon Icons or small)
    def egg_icon(b, cx, cy)
      bm = Reloaded::PartyIcons.egg_bitmap
      return unless bm
      f = [bm.height, 1].max
      b.stretch_blt(Rect.new(cx - 17, cy - 17, 34, 34), bm, Rect.new(0, 0, f, f))
      bm.dispose
    rescue StandardError
      nil
    end

    def choose(title, labels, descriptions = [])
      i = Reloaded::Dialogs.menu(self, title, labels, descriptions)
      refresh
      return i
    end

    # Days ahead (0 to 9) and an hour: [days, hour], or nil.
    def time_changer
      now = defined?(pbGetTimeNow) ? pbGetTimeNow : Time.now
      days = 0
      hour = (now.hour + 1) % 24
      field = 1
      redraw = true
      loop do
        if redraw
          paint_time(days, hour, field, now)
          redraw = false
        end
        Graphics.update
        Input.update
        pbUpdateSceneMap if defined?(pbUpdateSceneMap)
        pt = Reloaded::Pointer
        if pt.moved? && (h = pt.hit(@time_hits)) && h[0] == :field && h[1] != field
          field = h[1]
          redraw = true
        end
        if pt.left? && (h = pt.hit(@time_hits))
          case h[0]
          when :field then field = h[1]
          when :step
            field = h[1]
            field == 0 ? days = (days + h[2]) % 10 : hour = (hour + h[2]) % 24
            pbPlayCursorSE
          when :ok
            pbPlayDecisionSE
            overlay.clear
            return [days, hour]
          end
          redraw = true
        elsif pt.right? || Input.trigger?(Input::BACK)
          pbPlayCancelSE
          overlay.clear
          return nil
        elsif (w = pt.wheel) != 0
          field == 0 ? days = (days - w) % 10 : hour = (hour - w) % 24
          pbPlayCursorSE
          redraw = true
        elsif Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)
          step = Input.repeat?(Input::LEFT) ? -1 : 1
          field == 0 ? days = (days + step) % 10 : hour = (hour + step) % 24
          pbPlayCursorSE
          redraw = true
        elsif Input.trigger?(Input::UP) || Input.trigger?(Input::DOWN)
          field = 1 - field
          pbPlayCursorSE
          redraw = true
        elsif Input.trigger?(Input::USE)
          pbPlayDecisionSE
          overlay.clear
          return [days, hour]
        end
      end
    end

    private

    #--------------------------------------------------------------------------
    # Layers
    #--------------------------------------------------------------------------
    def sprites
      return super + [@left].compact.reject { |s| s.disposed? } + @cards.reject { |s| s.disposed? }
    end

    def close
      @cards.each { |s| s.dispose unless s.disposed? }
      @cards = []
      @own_bitmaps.each { |b| b.dispose unless b.disposed? }
      @own_bitmaps = []
      @icons.each_value { |b| b.dispose if b && !b.disposed? }
      @icons = {}
      if @left && !@left.disposed?
        @left.bitmap.dispose if @left.bitmap && !@left.bitmap.disposed?
        @left.dispose
      end
      dispose_sprites
    end

    def animate(way)
      return unless defined?(Reloaded::PauseMenu) && Reloaded::PauseMenu.animations?
      steps = way == :in ? 6 : 5
      fading = [@sprite, @top_sprite, @hint_sprite] + @cards
      steps.times do |k|
        t = (k + 1).to_f / steps
        e = way == :in ? 1 - (1 - t)**2 : (1 - t)**2
        @left.x = -((1 - e) * (PANEL_X1 + 10)).round
        fading.each { |s| s.opacity = (255 * e).round unless s.disposed? }
        @cursor_sprite.visible = false
        Graphics.update
        pbUpdateSceneMap if defined?(pbUpdateSceneMap)
      end
      @left.x = 0
      return unless way == :in
      fading.each { |s| s.opacity = 255 unless s.disposed? }
      place_cursor
    end

    #--------------------------------------------------------------------------
    # The page and its entries
    #--------------------------------------------------------------------------
    def page
      return OM.pages[@page] || OM.pages[0]
    end

    def rows
      return OM.page_entries(page)
    end

    def current
      return rows[@sel]
    end

    def turn_page(dir)
      n = OM.pages.length
      return if n < 2
      @page = (@page + dir) % n
      OM.page_index = @page
      @sel = 0
      @scroll = 0
      pbPlayCursorSE
      refresh
    end

    #--------------------------------------------------------------------------
    # Input
    #--------------------------------------------------------------------------
    def handle_input
      return close_menu if OM.pressed?            # the button that opened it closes it
      pt = Reloaded::Pointer
      if pointer_hover && (hit = pt.hit(@hits))
        hover(hit)
      end
      if pt.left?
        handled, result = hint_click
        return result if handled && (result == :close || result.respond_to?(:call))
        return nil if handled
        hit = pt.hit(@hits)
        return hit ? click(hit) : nil
      end
      return close_menu if pt.right?
      if (wheel = pt.wheel) != 0
        @focus == :quick ? step_slot(wheel) : move(wheel, true)
        return nil
      end
      return quick_input if @focus == :quick
      if Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN)
        dir = Input.repeat?(Input::UP) ? -1 : 1
        move(dir, Input.trigger?(Input::UP) || Input.trigger?(Input::DOWN))
      elsif Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)
        turn_page(Input.trigger?(Input::LEFT) ? -1 : 1)
      elsif Input.trigger?(Input::USE)
        return use_current
      elsif Input.trigger?(Input::ACTION)            # X on a controller
        edit_pages
      elsif Input.trigger?(Input::X)                 # Y on a controller
        next_view
      elsif Input.trigger?(Input::BACK)
        return close_menu
      end
      return nil
    end

    def quick_input
      if Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)
        step_slot(Input.repeat?(Input::LEFT) ? -1 : 1)
      elsif Input.trigger?(Input::USE)
        return use_slot
      elsif Input.trigger?(Input::ACTION)
        edit_slot
      elsif Input.trigger?(Input::BACK) || Input.trigger?(Input::UP)
        @focus = :list
        pbPlayCancelSE
        refresh
      end
      return nil
    end

    # Up/Down through the entries (a held direction stops at the ends; a
    # fresh press wraps).
    def move(dir, fresh)
      n = rows.length
      return if n == 0
      target = @sel + dir
      if target < 0 || target >= n
        return unless fresh
        target %= n
      end
      @sel = target
      pbPlayCursorSE
      refresh
    end

    def step_slot(dir)
      @slot = (@slot + dir) % OM::QUICK_MAX
      @focus = :quick
      pbPlayCursorSE
      refresh
    end

    def hover(hit)
      kind, i = hit
      changed = case kind
                when :row then [@focus, @sel] != [:list, i]
                when :slot then [@focus, @slot] != [:quick, i]
                else false
                end
      return unless changed
      kind == :row ? (@focus = :list; @sel = i) : (@focus = :quick; @slot = i)
      pbPlayCursorSE
      refresh
    end

    def click(hit)
      kind, i = hit
      case kind
      when :row
        @focus = :list
        @sel = i
        return use_current
      when :slot
        @focus = :quick
        @slot = i
        return use_slot
      when :tab
        return nil if i == @page
        turn_page(i - @page)
      when :more
        move(i, true)
      end
      return nil
    end

    def close_menu
      pbPlayCloseMenuSE if defined?(pbPlayCloseMenuSE)
      return :close
    end

    # A: an entry does its thing; a toggle's switch flips; a choice opens
    # its dropdown, a number its slider.
    def use_current
      e = current
      return nil unless e
      reason = OM.usable(e)
      if reason != true
        pbPlayBuzzerSE
        notice(e.name, reason)
        return nil
      end
      if e.get && e.set && !e.handler
        if e.values
          choice_dropdown(e)
        elsif e.range
          number_slider(e)
        else
          e.set.call(!e.get.call)
          pbPlayCursorSE
        end
        refresh
        return nil
      end
      unless e.handler
        pbPlayBuzzerSE
        return nil
      end
      pbPlayDecisionSE
      result = e.handler.call(self)
      build_cards
      @sel = [@sel, [rows.length - 1, 0].max].min
      refresh
      return :close if result == :close
      return result if result.respond_to?(:call)
      return nil
    rescue StandardError => ex
      Reloaded::Log.exception("The Overworld Menu's #{e && e.name} failed", ex, :overworld_menu)
      pbPlayBuzzerSE
      notice(e ? e.name : _INTL("Overworld Menu"), _INTL("That didn't work. Kanto Reloaded's log says why."))
      return nil
    end

    # Y: the right side's next view (then none).
    def next_view
      OM.next_view
      pbPlayCursorSE
      build_cards
      refresh
    end

    def edit_pages
      return pbPlayBuzzerSE unless defined?(Reloaded::OverworldPagesScreen)
      pbPlayDecisionSE
      hidden { Reloaded::OverworldPagesScreen.open(@page) }
      @page = OM.page_index
      @sel = 0
      @scroll = 0
      refresh
    end

    #--------------------------------------------------------------------------
    # Quick Items
    #--------------------------------------------------------------------------
    def slot_item
      return OM.quick_items[@slot]
    end

    # A: the item is used (a field item once the menu has closed; one used on
    # a Pokémon or from the Bag here); an empty slot picks one.
    def use_slot
      item = slot_item
      return pick_item if item.nil?
      return use_item(item)
    end

    # X: change or clear a slot (an empty one picks straight away).
    def edit_slot
      return pick_item if slot_item.nil?
      i = choose(item_name(slot_item), [_INTL("Change"), _INTL("Clear")],
                 [_INTL("Pick another item for this slot."), _INTL("Empty this slot.")])
      case i
      when 0 then pick_item
      when 1
        OM.set_quick_item(@slot, nil)
        refresh
      end
      return nil
    end

    # The game's Bag, showing only items that can go in a slot.
    def pick_item
      unless defined?(::PokemonBagScreen) && $PokemonBag
        pbPlayBuzzerSE
        return nil
      end
      pbPlayDecisionSE
      item = nil
      hidden do
        pbFadeOutIn do
          screen = ::PokemonBagScreen.new(::PokemonBag_Scene.new, $PokemonBag)
          item = screen.pbChooseItemScreen(proc { |it| OM.quick_item?(it) })
        end
      end
      OM.set_quick_item(@slot, item) if item
      refresh
      return nil
    end

    def item_name(item)
      return ::GameData::Item.get(item).name
    rescue StandardError
      return item.to_s
    end

    #--------------------------------------------------------------------------
    # Painting: the panel
    #--------------------------------------------------------------------------
    def paint_panel(c)
      b = @left.bitmap
      P.ui.rbox(b, PANEL_X0, PANEL_Y0, PANEL_X1, PANEL_Y1, 7, alpha(c[:panel2], panel_alpha), c[:line])
      P.text(b, PANEL_X0, PANEL_Y0 + 2, PANEL_X1 - PANEL_X0, 26, _INTL("Overworld Menu"), c[:title], PF::TITLE, 2)
      paint_tabs(b, c)
      list = rows
      @sel = [[@sel, 0].max, [list.length - 1, 0].max].min
      @scroll = @sel - ROWS + 1 if @sel >= @scroll + ROWS
      @scroll = @sel if @sel < @scroll
      @scroll = [[@scroll, [list.length - ROWS, 0].max].min, 0].max
      if list.empty?
        P.text(b, PANEL_X0, ROWS_Y + 20, PANEL_X1 - PANEL_X0, 20, _INTL("Nothing Here Now"), c[:dim], PF::TEXT, 2)
      end
      list[@scroll, ROWS].to_a.each_with_index do |e, k|
        i = @scroll + k
        y = ROWS_Y + k * ROW_H
        paint_row(b, c, e, y, @focus == :list && i == @sel)
        @hits << [[:row, i], PANEL_X0 + 3, y, PANEL_X1 - 3, y + ROW_H - 1]
      end
      if list.length > ROWS
        up = @scroll > 0
        down = @scroll + ROWS < list.length
        cx = (PANEL_X0 + PANEL_X1) / 2
        P.ui.tri(b, cx - 4, ROWS_Y - 6, :u, up ? c[:dim] : c[:line], 3) if up
        P.ui.tri(b, cx - 4, ROWS_Y + ROWS * ROW_H + 2, :d, down ? c[:dim] : c[:line], 3) if down
        @hits << [[:more, -1], cx - 20, ROWS_Y - 8, cx + 20, ROWS_Y - 1] if up
        @hits << [[:more, 1], cx - 20, ROWS_Y + ROWS * ROW_H, cx + 20, ROWS_Y + ROWS * ROW_H + 8] if down
      end
    end

    # The pages as tabs; the current one boxed. More than fit: the ones
    # around the current, with arrows.
    def paint_tabs(b, c)
      names = OM.pages.map { |pg| OM.page_name(pg).upcase }
      widths = names.map { |n| P.width(PF::TINY, n) + 14 }
      room = PANEL_X1 - PANEL_X0 - 24
      gap = 4
      if widths.sum + gap * (widths.length - 1) <= room
        each = (room - gap * (names.length - 1)) / [names.length, 1].max
        widths = widths.map { |w| [w, each].max } if widths.max <= each
        first = 0
      else
        first = @page
        first -= 1 while first > 0 && widths[first - 1..@page].sum + gap * (@page - first + 1) <= room
      end
      x = PANEL_X0 + 12
      last = first
      (first...names.length).each do |i|
        w = widths[i]
        break if x + w > PANEL_X1 - 12
        on = i == @page
        if on
          P.ui.rbox(b, x, TABS_Y, x + w, TABS_Y + 17, 4, Reloaded::Palette.mix(c[:selb], c[:panel2], 0.7), c[:selb])
        end
        P.text(b, x, TABS_Y, w, 18, names[i], on ? c[:txt] : c[:dim], PF::TINY, 2)
        @hits << [[:tab, i], x, TABS_Y, x + w, TABS_Y + 17]
        x += w + gap
        last = i
      end
      P.ui.tri(b, PANEL_X0 + 4, TABS_Y + 5, :l, c[:dim], 3) if first > 0
      P.ui.tri(b, PANEL_X1 - 8, TABS_Y + 5, :r, c[:dim], 3) if last < names.length - 1
    end

    def paint_row(b, c, e, y, on)
      x0 = PANEL_X0 + 4
      x1 = PANEL_X1 - 4
      if on
        P.ui.rbox(b, x0, y, x1, y + ROW_H - 2, 5, Reloaded::Palette.mix(c[:selb], c[:panel2], 0.55), c[:selb])
        @cursor_rect = [x0, y, x1 - x0 + 1, ROW_H - 1]
      end
      reason = OM.usable(e)
      off = reason != true
      lx = x0 + 8                       # no icons on the rows (his call, 2026-10-20)
      label = OM.label(e)
      room = x1 - 6 - lx
      sw = 0
      st_room = [room - [P.width(PF::ROW, label), room / 2].min - 8, 40].max
      if e.get && !e.values && !e.range
        draw_switch(b, c, x1 - 18, y + ROW_H / 2 - 1, (e.get.call rescue false), off)
        sw = 32
      elsif e.paint
        sw = (e.paint.call(b, x1 - 6, y, ROW_H - 2, c, st_room).to_i rescue 0) + 8
      elsif (st = OM.status(e))
        colour = off ? c[:dim] : status_colour(st[1], c)
        if st[0] == OM::INFINITY
          infinity(b, x1 - 6 - 22, y + ROW_H / 2 - 6, colour)
          sw = 30
        else
          sw = P.text(b, x0, y, x1 - x0 - 6, ROW_H - 2, PF.fit(PF::ROW, st[0].to_s, st_room), colour, PF::ROW, 1) + 8
        end
      end
      row_label(b, lx, y, room - sw, label, off ? c[:dim] : c[:txt])
      lock(b, x1 - sw - 14, y + 9, c[:dim]) if off && sw == 0
    end

    # A toggle's switch: lit with the knob to the right when on.
    def draw_switch(b, c, cx, cy, on, off)
      colour = on && !off ? tone(:green) : c[:dim]
      fill = Reloaded::Palette.mix(colour, c[:panel2], on ? 0.55 : 0.8)
      P.ui.rbox(b, cx - 12, cy - 6, cx + 12, cy + 6, 6, fill, colour)
      kx = on ? cx + 1 : cx - 10
      P.ui.rbox(b, kx, cy - 4, kx + 9, cy + 4, 4, on ? c[:white] : c[:dim])
    end

    # A row's words: the row's font when they fit, else smaller, on two
    # lines if need be (a quest's long name).
    def row_label(b, x, y, room, text, colour)
      if P.width(PF::ROW, text) <= room
        P.text(b, x, y, room, ROW_H - 2, text, colour, PF::ROW)
        return
      end
      return P.text(b, x, y, room, ROW_H - 2, text, colour, PF::TINY) if P.width(PF::TINY, text) <= room
      words = text.split(" ")
      best = nil
      (1...words.length).each do |k|
        a = words[0...k].join(" ")
        z = words[k..-1].join(" ")
        wide = [P.width(PF::TINY, a), P.width(PF::TINY, z)].max
        best = [wide, [a, z]] if wide <= room && (best.nil? || wide < best[0])
      end
      lines = best ? best[1] : [PF.fit(PF::TINY, text, room)]
      lines.each_with_index { |ln, k| P.text(b, x, y + (lines.length == 1 ? 7 : 2 + k * 11), room, 11, ln, colour, PF::TINY) }
    end

    def status_colour(sym, c)
      case sym
      when :green then return tone(:green)
      when :gold then return tone(:gold)
      when :red then return tone(:red)
      when :amber then return tone(:amber)
      when :dim then return c[:dim]
      end
      return c[:txt]
    end

    # A picture centred at cx, cy; scale 0.5 halves the game's 2x item art.
    def draw_picture(b, icon, cx, cy, opacity = 255)
      bmp = picture(icon[0])
      return unless bmp
      s = icon[1].to_f
      w = (bmp.width * s).round
      h = (bmp.height * s).round
      b.stretch_blt(Rect.new(cx - w / 2, cy - h / 2, w, h), bmp, Rect.new(0, 0, bmp.width, bmp.height), opacity)
    end

    def picture(file)
      return @icons[file] if @icons.has_key?(file)
      path = defined?(pbResolveBitmap) ? (pbResolveBitmap(file) || file) : file
      @icons[file] = (Bitmap.new(path) rescue nil)
      return @icons[file]
    end

    def lock(b, x, y, colour)
      LOCK.each_with_index { |ln, r| ln.each_char.with_index { |ch, k| b.fill_rect(x + k, y + r, 1, 1, colour) if ch == "#" } }
    end

    # The ∞ mark, 22 by 10, from x, y
    def infinity(b, x, y, colour)
      INFINITY.each_with_index { |ln, r| ln.each_char.with_index { |ch, k| b.fill_rect(x + k * 2, y + r * 2, 2, 2, colour) if ch == "#" } }
    end

    def alpha(colour, a)
      return Color.new(colour.red, colour.green, colour.blue, a)
    end

    # A status colour in the Theme Mode (:green, :gold, :red, :amber, :blue,
    # :pink; deeper on Light)
    def tone(name)
      return palette[name]
    end

    # The panels' see-through amount in the Theme Mode
    def panel_alpha
      return Reloaded::Palette.menu_alpha(PANEL_ALPHA)
    end

    # A badge's [fill, words] for a status rgb: dark with the colour's words,
    # or on Light, pale with them deepened
    def badge(rgb)
      colour = Color.new(*rgb)
      c = palette
      return [Color.new(rgb[0] / 4, rgb[1] / 4, rgb[2] / 4), colour] unless c[:light]
      ink = Reloaded::Palette.mix(colour, Color.new(0, 0, 0), 0.35)
      return [Reloaded::Palette.mix(c[:panel2], ink, 0.22), ink]
    end

    #--------------------------------------------------------------------------
    # Painting: Quick Items
    #--------------------------------------------------------------------------
    def paint_quick(c)
      b = @left.bitmap
      P.ui.rbox(b, PANEL_X0, QUICK_Y0, PANEL_X1, QUICK_Y1, 7, alpha(c[:panel2], panel_alpha), c[:line])
      P.text(b, PANEL_X0 + 8, QUICK_Y0 + 3, 150, 13, _INTL("Quick Items").upcase, c[:head], PF::TINY)
      items = OM.quick_items
      items.each_with_index do |item, i|
        x = SLOT_X0 + i * SLOT_STEP
        on = @focus == :quick && i == @slot
        fill = on ? Reloaded::Palette.mix(c[:selb], c[:panel2], 0.55) : c[:panel]
        P.ui.rbox(b, x, SLOT_Y, x + SLOT, SLOT_Y + SLOT, 4, fill, on ? c[:selb] : c[:line])
        if item
          have = OM.has_item?(item)
          draw_picture(b, [item_icon(item), 0.5], x + SLOT / 2, SLOT_Y + SLOT / 2, have ? 255 : 90)
        else
          colour = on ? c[:txt] : c[:line]
          b.fill_rect(x + SLOT / 2 - 5, SLOT_Y + SLOT / 2 - 1, 10, 2, colour)
          b.fill_rect(x + SLOT / 2 - 1, SLOT_Y + SLOT / 2 - 5, 2, 10, colour)
        end
        @cursor_rect = [x, SLOT_Y, SLOT + 1, SLOT + 1] if on
        @hits << [[:slot, i], x, SLOT_Y, x + SLOT, SLOT_Y + SLOT]
      end
    end

    def item_icon(item)
      return ::GameData::Item.icon_filename(item) if defined?(::GameData::Item) && ::GameData::Item.respond_to?(:icon_filename)
      return "Graphics/Items/#{item}"
    rescue StandardError
      return "Graphics/Items/#{item}"
    end

    #--------------------------------------------------------------------------
    # Painting: where you are
    #--------------------------------------------------------------------------
    def paint_area(base, top, c)
      here = here_words
      y1 = here ? 62 : 46
      P.ui.rbox(base, AREA_X0, PANEL_Y0, AREA_X1, y1, 7, alpha(c[:panel2], panel_alpha), c[:line])
      w = AREA_X1 - AREA_X0 - 16
      # each line centred in the box (his ask, 2026-10-21)
      P.text(top, AREA_X0 + 8, PANEL_Y0 + 2, w, 22, PF.fit(PF::ROW, map_name, w), tone(:green), PF::ROW, 2)
      P.text(top, AREA_X0 + 8, PANEL_Y0 + 23, w, 16, PF.fit(PF::TEXT, sky_words, w), tone(:blue), PF::TEXT, 2)
      P.text(top, AREA_X0 + 8, PANEL_Y0 + 39, w, 16, PF.fit(PF::TEXT, here[0], w), here[1] ? tone(:green) : c[:txt], PF::TEXT, 2) if here
    end

    def map_name
      id = ($game_map.map_id rescue nil)
      name = id && defined?(pbGetMapNameFromId) ? (pbGetMapNameFromId(id) rescue "").to_s : ""
      return name.split(" (")[0].to_s
    end

    # "Rain, Evening"
    def sky_words
      type = ($game_screen.weather_type rescue nil)
      weather = WEATHER[type] ? _INTL(WEATHER[type]) : _INTL("Clear")
      hour = (defined?(pbGetTimeNow) ? pbGetTimeNow : Time.now).hour
      period = if hour >= 5 && hour < 10 then _INTL("Morning")
               elsif hour >= 10 && hour < 17 then _INTL("Day")
               elsif hour >= 17 && hour < 20 then _INTL("Evening")
               else _INTL("Night")
               end
      return _INTL("{1}, {2}", weather, period)
    end

    # ["3 of 7 Caught", all caught?] from the map's wild Pokémon, or nil
    def here_words
      tables = $PokemonEncounters ? ($PokemonEncounters.instance_variable_get(:@encounter_tables) || {}) : {}
      species = tables.values.flatten(1).map { |slot| slot.is_a?(Array) ? slot[1] : nil }.compact.uniq
      return nil if species.empty?
      caught = species.count { |s| ($Trainer.pokedex.owned?(s) rescue false) }
      return [_INTL("{1} of {2} Caught", caught, species.length), caught == species.length]
    rescue StandardError
      return nil
    end

    #--------------------------------------------------------------------------
    # Painting: Party View
    #--------------------------------------------------------------------------
    def party
      return [] unless $Trainer && $Trainer.respond_to?(:party)
      return Array($Trainer.party).compact.first(6)
    end

    # :full, :compact (the Party View setting), or :off while another view
    # (or none) shows
    def party_mode
      return :off unless OM.view == "party"
      return Reloaded::Settings.get(OM::PARTY_VIEW).to_i == 0 ? :full : :compact
    end

    # Compact: three to a row, the rows sitting on the bottom (four to six
    # Pokémon: a second row above the first). Full: two to a row, down from
    # the area panel.
    def card_xy(i)
      if party_mode == :full
        return [FULL_X0 + (i % 2) * (FULL_W + CARD_GAP), FULL_Y0 + (i / 2) * (FULL_H + CARD_GAP)]
      end
      rows = [(party.length + 2) / 3, 1].max
      y0 = CARD_Y0 + (2 - rows) * (CARD_H + CARD_GAP)
      return [CARD_X0 + (i % 3) * (CARD_W + CARD_GAP), y0 + (i / 3) * (CARD_H + CARD_GAP)]
    end

    # The icons, made again after anything that may have changed the party.
    def build_cards
      @cards.each { |s| s.dispose unless s.disposed? }
      @cards = []
      @own_bitmaps.each { |b| b.dispose unless b.disposed? }
      @own_bitmaps = []
      mode = party_mode
      return if mode == :off || @viewport.nil?
      party.each_with_index do |pkmn, i|
        x, y = card_xy(i)
        s = mode == :full ? battle_sprite(pkmn) : nil
        if s
          s.x = x + 34
          s.y = y + 52
        else
          s = Reloaded::PartyIcons.icon(pkmn, @viewport, 2)
          next unless s
          if mode == :full
            Reloaded::PartyIcons.place(s, x + 34, y + 50)
            s.zoom_x = s.zoom_y = s.zoom_x * 0.9
          else
            Reloaded::PartyIcons.place(s, x + 20, y + 31)
            s.zoom_x = s.zoom_y = s.zoom_x * 0.55
          end
        end
        @cards << s
      end
    end

    # Full: the Pokémon's battle sprite (its fusion's, as the game draws it
    # in battle) at a quarter of its size, an Egg's at half; nil when the
    # game can't give one (its icon instead).
    def battle_sprite(pkmn)
      return nil unless defined?(::GameData::Species) && ::GameData::Species.respond_to?(:sprite_bitmap_from_pokemon)
      anim = ::GameData::Species.sprite_bitmap_from_pokemon(pkmn)
      return nil unless anim
      src = anim.respond_to?(:bitmap) ? anim.bitmap : anim
      scale = (pkmn.egg? rescue false) ? 0.5 : 0.25
      w = [(src.width * scale).round, 1].max
      h = [(src.height * scale).round, 1].max
      bmp = Bitmap.new(w, h)
      bmp.stretch_blt(Rect.new(0, 0, w, h), src, Rect.new(0, 0, src.width, src.height))
      anim.dispose if anim.respond_to?(:dispose) && !(anim.respond_to?(:disposed?) && anim.disposed?)
      s = Sprite.new(@viewport)
      s.bitmap = bmp
      s.ox = w / 2
      s.oy = h / 2
      s.z = 2
      @own_bitmaps << bmp
      return s
    rescue StandardError => e
      Reloaded::Log.warning_once("Party View couldn't draw a battle sprite: #{e.class}: #{e.message}", :overworld_menu)
      return nil
    end

    def paint_cards(base, top, c)
      case party_mode
      when :compact then party.each_with_index { |pkmn, i| paint_compact(base, top, c, pkmn, *card_xy(i)) }
      when :full then party.each_with_index { |pkmn, i| paint_full(base, top, c, pkmn, *card_xy(i)) }
      else paint_view(base, top, c)
      end
    end

    # A view of a feature's own draws itself.
    def paint_view(base, top, c)
      v = OM.views.find { |x| x[:key] == OM.view }
      v[:draw].call(self, base, top, c) if v && v[:draw]
    rescue StandardError => e
      Reloaded::Log.warning_once("The Overworld Menu's #{v && v[:name]} couldn't draw: #{e.class}: #{e.message}", :overworld_menu)
    end

    # Compact (design 1, Three Cards): the name and level across the top, the
    # HP under them and any status under that, the bar along the bottom.
    def paint_compact(base, top, c, pkmn, x, y)
      P.ui.rbox(base, x, y, x + CARD_W, y + CARD_H, 6, alpha(c[:panel2], panel_alpha), c[:line])
      if (pkmn.egg? rescue false)
        P.text(top, x + 4, y + 3, CARD_W - 8, 11, _INTL("Egg"), c[:dim], PF::TINY)
        return
      end
      lv = _INTL("Lv {1}", pkmn.level)
      lw = P.width(PF::TINY, lv)
      room = CARD_W - 12 - lw
      P.text(top, x + 4, y + 3, room, 11, PF.fit(PF::TINY, (pkmn.name rescue "?").to_s, room), c[:txt], PF::TINY)
      P.text(top, x + CARD_W - 4 - lw, y + 3, lw, 11, lv, tone(:gold), PF::TINY)
      hp, total = hp_of(pkmn)
      P.text(top, x + 34, y + 16, CARD_W - 38, 11, "#{hp}/#{total}", hp > 0 ? c[:txt] : tone(:red), PF::TINY, 1)
      word, rgb = status_of(pkmn, hp)
      P.pill(top, x + CARD_W - 4, y + 28, word, *badge(rgb), true) if word
      hp_bar(base, c, x + 4, y + CARD_H - 5, CARD_W - 8, hp, total)
    end

    # ["PSN", rgb]: fainted, or the status condition, or nil
    def status_of(pkmn, hp)
      return ["FNT", [240, 100, 90]] if hp <= 0
      return STATUS[(pkmn.status rescue nil)]
    end

    # Full: the held item top right; the name (gender, a star when shiny)
    # centred between the left edge and it; the battle sprite on the left;
    # level, types (up to three), status and HP centred in the info column
    # beside it; the HP bar along the bottom.
    def paint_full(base, top, c, pkmn, x, y)
      P.ui.rbox(base, x, y, x + FULL_W, y + FULL_H, 7, alpha(c[:panel2], panel_alpha), c[:line])
      item = held_item(pkmn)
      if item
        P.ui.rbox(top, x + FULL_W - 26, y + 4, x + FULL_W - 4, y + 26, 4, c[:dark], c[:line])
        draw_picture(top, [item_icon(item), 0.5], x + FULL_W - 15, y + 15)
      end
      if (pkmn.egg? rescue false)
        P.text(top, x + 4, y + 4, FULL_W - 34, 18, _INTL("Egg"), c[:dim], PF::TEXT, 2)
        return
      end
      # the name has the top line to itself (the item box's space too when
      # there's no item); its gender and shiny star go beside the level
      name_line(top, c, pkmn, x + 4, y + 4, item ? FULL_W - 34 : FULL_W - 8)
      ix = x + FULL_INFO_X
      iw = FULL_W - 4 - FULL_INFO_X
      lv = _INTL("Lv {1}", pkmn.level)
      lw = P.width(PF::TINY, lv)
      mw = marks(top, pkmn, 0, 0, false)
      lx = ix + (iw - lw - (mw > 0 ? 3 + mw : 0)) / 2
      P.text(top, lx, y + 27, lw + 2, 11, lv, tone(:gold), PF::TINY)
      marks(top, pkmn, lx + lw + 3, y + 29) if mw > 0
      list = types(pkmn).first(3)
      tw = list.length * TYPE_PX + (list.length - 1) * 2
      list.each_with_index { |t, k| type_icon(top, t, ix + (iw - tw) / 2 + k * (TYPE_PX + 2), y + 40) }
      hp, total = hp_of(pkmn)
      word, rgb = status_of(pkmn, hp)
      if word
        pw = P.width(PF::TINY, word) + 12
        P.pill(top, ix + (iw - pw) / 2, y + 58, word, *badge(rgb), false)
      end
      P.text(top, ix, y + 74, iw, 11, "#{hp}/#{total}", hp > 0 ? c[:txt] : tone(:red), PF::TINY, 2)
      hp_bar(base, c, x + 6, y + FULL_H - 7, FULL_W - 12, hp, total)
    end

    # The name, centred in room from x (its gender and star are by the level).
    # A long name steps down to the tiny pixel font (KIF's pixel fonts have
    # only these two sizes) before it's ever cut ([font, y nudge]).
    # (a method: KIF's pixel UI isn't there yet when this file loads)
    def name_fonts
      return [[PF::TEXT, 0], [PF::TINY, 3]]
    end

    def name_line(top, c, pkmn, x, y, room)
      full = (pkmn.name rescue "?").to_s
      font, nudge = name_fonts.find { |f, _| P.width(f, full) <= room } || name_fonts.last
      name = PF.fit(font, full, room)
      P.text(top, x + (room - P.width(font, name)) / 2, y + nudge, room, 18, name, c[:txt], font)
    end

    # The gender mark and a star when shiny, from x; returns their width
    # (draw false: only the width).
    def marks(top, pkmn, x, y, draw = true)
      g = (pkmn.gender rescue 2)
      w = 0
      if g == 0
        pixels(top, MALE, x, y, tone(:blue)) if draw
        w += 9
      elsif g == 1
        pixels(top, FEMALE, x, y, tone(:pink)) if draw
        w += 8
      end
      if (pkmn.shiny? rescue false)
        star(top, x + w, y) if draw
        w += 10
      end
      return w
    end

    def pixels(b, rows, x, y, colour)
      rows.each_with_index { |ln, r| ln.each_char.with_index { |ch, k| b.fill_rect(x + k, y + r, 1, 1, colour) if ch == "#" } }
    end

    def hp_of(pkmn)
      return [(pkmn.hp rescue 0).to_i, [(pkmn.totalhp rescue 1).to_i, 1].max]
    end

    def hp_bar(base, c, x, y, w, hp, total)
      frac = hp.to_f / total
      colour = frac > 0.5 ? tone(:green) : (frac > 0.25 ? tone(:amber) : tone(:red))
      base.fill_rect(x, y, w, 3, c[:dark])
      base.fill_rect(x, y, (w * frac).round, 3, colour) if hp > 0
    end

    def held_item(pkmn)
      item = pkmn.respond_to?(:item_id) ? pkmn.item_id : (pkmn.item rescue nil)
      item = item.id if item.respond_to?(:id)
      return item.nil? || item.to_s.empty? ? nil : item
    rescue StandardError
      return nil
    end

    # Up to three (a fusion's third type too, where the game has one).
    def types(pkmn)
      list = pkmn.respond_to?(:types) ? Array(pkmn.types) : [pkmn.type1, pkmn.type2]
      list += [pkmn.type3] if pkmn.respond_to?(:type3)
      return list.compact.uniq
    rescue StandardError
      return []
    end

    # The game's small type icons at 16 px (Graphics/OverworldMenu, one per
    # row, made from Graphics/Pictures/Battle/typesSmall).
    def type_icon(b, type, x, y)
      sheet = picture(TYPE_ICONS)
      return unless sheet && defined?(::GameData::Type)
      row = ::GameData::Type.get(type).icon_position
      b.blt(x, y, sheet, Rect.new(0, row * TYPE_PX, TYPE_PX, TYPE_PX))
    rescue StandardError
      nil
    end

    STAR = ["...#...", "..###..", "#######", ".#####.", "..###..", ".##.##.", "##...##"].freeze

    def star(b, x, y)
      STAR.each_with_index { |ln, r| ln.each_char.with_index { |ch, k| b.fill_rect(x + k, y + r, 1, 1, tone(:gold)) if ch == "#" } }
    end

    #--------------------------------------------------------------------------
    # The Time Changer's popup
    #--------------------------------------------------------------------------
    def paint_time(days, hour, field, now)
      o = overlay
      c = palette
      Reloaded::Dialogs.send(:dim, o)
      w = 300
      h = 168
      x = (W - w) / 2
      y = (H - h) / 2 - 10
      Reloaded::Dialogs.send(:panel, o, c, x, y, w, h)
      Reloaded::Dialogs.send(:title_bar, o, c, x, y, w, _INTL("Time Changer"))
      @time_hits = []
      labels = [[_INTL("Days Ahead"), days.to_s], [_INTL("Hour"), "#{hour_words(hour)} (#{period_words(hour)})"]]
      labels.each_with_index do |(label, value), i|
        ry = y + 42 + i * 28
        on = i == field
        Reloaded::Dialogs.send(:cursor_row, o, c, x + 10, ry, x + w - 10, ry + 24) if on
        P.text(o, x + 18, ry, 120, 24, label, c[:opt], PF::ROW)
        vw = P.width(PF::ROW, value)
        P.ui.tri(o, x + w - 34 - vw, ry + 8, :l, c[:dim], 3)
        P.text(o, x + w - 24 - vw, ry, vw, 24, value, c[:txt], PF::ROW)
        P.ui.tri(o, x + w - 20, ry + 8, :r, c[:dim], 3)
        @time_hits << [[:field, i], x + 10, ry, x + w - 50 - vw, ry + 24]
        @time_hits << [[:step, i, -1], x + w - 50 - vw, ry, x + w - 22 - vw, ry + 24]
        @time_hits << [[:step, i, 1], x + w - 24, ry, x + w - 10, ry + 24]
      end
      words = Reloaded::OverworldMenu::Entries
      now_text = "#{_INTL(words::WEEKDAYS[now.wday])} #{now.strftime("%l:%M %p").strip}"
      P.small(o, x, y + 102, w, 16, _INTL("Now {1}", now_text), c[:dim], 2)
      P.text(o, x, y + 118, w, 18, _INTL("Then {1}", words.landing_words(days, hour, now)), tone(:gold), PF::TEXT, 2)
      bx = x + w / 2 - 60
      by = y + h - 30
      P.ui.rbox(o, bx, by, bx + 120, by + 22, 5, Reloaded::Palette.mix(c[:selb], c[:panel2], 0.55), c[:selb])
      P.text(o, bx, by, 120, 22, _INTL("Change Time"), c[:txt], PF::TEXT, 2)
      @time_hits << [[:ok], bx, by, bx + 120, by + 22]
    end

    def hour_words(hour)
      h = hour % 12
      h = 12 if h == 0
      return "#{h} #{hour < 12 ? "AM" : "PM"}"
    end

    def period_words(hour)
      return _INTL("Morning") if hour >= 5 && hour < 10
      return _INTL("Day") if hour >= 10 && hour < 17
      return _INTL("Evening") if hour >= 17 && hour < 20
      return _INTL("Night")
    end

    #--------------------------------------------------------------------------
    # Hints
    #--------------------------------------------------------------------------
    def hint_pairs
      return [[:ud, _INTL("Choose")], [button(:C), _INTL("Pick")], [button(:B), _INTL("Close")]] if @choice_dd
      if @slider
        ten = @slider[0] * 10
        return [[:lr, _INTL("Change")], [Reloaded::Prompts.input(:L) || button(:L), "-#{ten}"],
                [Reloaded::Prompts.input(:R) || button(:R), "+#{ten}"], [button(:C), _INTL("Set")], [button(:B), _INTL("Cancel")]]
      end
      return [[button(:B), _INTL("Close")]] if @day_care_open
      if @encounters
        tabs, scroll = @encounters
        pairs = []
        pairs << [:lr, _INTL("Method")] if tabs
        pairs << [:ud, _INTL("Scroll")] if scroll
        return pairs << [button(:B), _INTL("Close")]
      end
      if @focus == :quick
        empty = slot_item.nil?
        return [[:lr, _INTL("Choose")], [button(:C), empty ? _INTL("Set") : _INTL("Use"), :use_slot],
                [button(:A), _INTL("Edit"), :edit_slot], [button(:B), _INTL("Back")]]
      end
      out = [[:ud, _INTL("Choose")]]
      out << [:lr, _INTL("Pages")] if OM.pages.length > 1
      out << [button(:C), _INTL("Use"), :use_current] if current
      out << [button(:A), _INTL("Edit Pages"), :edit_pages]
      out << [button(:X), _INTL("Views"), :next_view]
      out << [button(:B), _INTL("Close"), :close_menu]
      return out
    end
  end
end
