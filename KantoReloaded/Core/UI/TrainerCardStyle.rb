# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Trainer Card's Style and Unlocks tabs
#==============================================================================
# His picks (2026-10-28), as drawn (tc-style-groups-sheet, tc-unlocks-cats-
# sheet, the popups sheet):
#
#   Style    the Dressing Room: the groups down the left with how many
#            you've unlocked, your trainer and the Showcase in the middle,
#            the group's pick on the right (◂ ▸ to change it) over your
#            Money. Changes are tried on live (a plate tints the whole
#            screen, a background changes the art); A keeps them, and
#            leaving with any not kept asks Keep These Changes? (Keep, Put
#            Back). Showcase: Left / Right picks a slot, A the Showcase Slot
#            popup (party first, then the boxes; X clears the slot).
#   Unlocks  each category's list (what it needs, how far along, UNLOCKED,
#            or a background's price), the one picked previewed. A buys a
#            background a Printer would sell here (Buy a Background?), or
#            shows an unlock's details (Track It: the Stats tab's Next
#            Milestone shows it).
#==============================================================================

return unless defined?(Reloaded::TrainerCardScene)

module Reloaded
  module TrainerCardScene
    # Style's groups: [key, name, the Bag icon]
    GROUPS = [[:backgrounds, "Backgrounds", :TOWNMAP], [:plates, "Plate Colors", :SHINYCHARM], [:titles, "Titles", :AMULETCOIN],
              [:showcase, "Showcase", :POKEBALL], [:cases, "Badge Cases", :EXPSHARE], [:tags, "Run Tags", :LINKINGCORD]].freeze
    CATS = [:backgrounds, :plates, :titles, :cases, :tags].freeze
    # What one of each is called in a sentence and over its preview
    ONE = { :backgrounds => "Background", :plates => "Plate Color", :titles => "Title", :cases => "Badge Case", :tags => "Run Tag Look" }.freeze
    ROWS = 6                # Unlocks' rows shown at once
    PICK_ROWS = 5           # the Showcase Slot popup's

    #--------------------------------------------------------------------------
    # The strip down the left (groups or categories)
    #--------------------------------------------------------------------------
    def strip(base, top, c, rows, sel, y0 = 48, tile = 42)
      glass(base, c, 32, y0 - 4, 100, y0 + rows.length * tile + 2, 10)
      @strip_hits = []
      rows.each_with_index do |(_name, icon, n, m), i|
        ty = y0 + i * tile
        @strip_hits << [i, 32, ty, 100, ty + tile - 4]
        P.ui.rbox(base, 36, ty, 96, ty + tile - 4, 7, light?(c) ? c[:selb] : c[:sel], c[:selb]) if i == sel
        item(top, icon, 54, ty + 2, 24)
        words = m ? "#{n}/#{m}" : _INTL("Edit")
        pair = i == sel ? [light?(c) ? WHITE : c[:strong], nil] : pif(c, "Dark")
        (i == sel ? method(:plain) : method(:stx)).call(top, 36, ty + 25, 60, 12, words, pair, PF::TINY, 2)
      end
    end

    def strip_rows(keys)
      return keys.map do |key|
        g = GROUPS.find { |k, _n, _i| k == key }
        n, m = key == :showcase ? [nil, nil] : UL.count(key)
        [_INTL(g[1]), g[2], n, m]
      end
    end

    # ◂ name ▸ centred across x0..x1 at y
    def arrows_name(top, c, x0, x1, y, name)
      nw = PF.width(PF::TEXT, name)
      cx = (x0 + x1) / 2
      stx(top, x0, y, x1 - x0, 22, name, pif(c, "Dark"), PF::TEXT, 2)
      P.ui.tri(top, cx - nw / 2 - 12, y + 7, :l, pif(c, "Dark")[0], 4)
      P.ui.tri(top, cx + nw / 2 + 6, y + 7, :r, pif(c, "Dark")[0], 4)
    end

    #--------------------------------------------------------------------------
    # Previews (128 x 96 at x, y)
    #--------------------------------------------------------------------------
    # A small ID in a plate colour over the card's background (the plate's
    # colour mixed with the art's, as glass over it looks)
    def mini_plate(base, top, c, x, y, plate, locked = false)
      thumb(base, top, c, TC.background, x, y)
      if plate
        rgb, = plate.look
        deep = deep?(rgb)
        fill = mix(TC.art_facts(TC.art_path(TC.background).to_s, nil)[0], Color.new(*rgb), deep ? 0.8 : 0.65)
        edge = mix(Color.new(*rgb), WHITE, deep ? 0.35 : 0.6)
        words = deep ? [Color.new(236, 238, 244), Color.new(12, 16, 24)] : TC.skin("Dark")
      else
        fill = light?(c) ? Color.new(214, 226, 246) : mix(c[:panel], TC.art_facts(TC.art_path(TC.background).to_s, nil)[0], 0.25)
        edge = light?(c) ? WHITE : c[:line]
        words = light?(c) ? TC.skin("Dark") : [c[:txt], Color.new(12, 16, 24)]
      end
      P.ui.rbox(top, x + 22, y + 10, x + 106, y + 88, 6, fill, edge)
      10.times { |k| top.fill_rect(x + 28, y + 12 + k, 72, 1, mix(fill, WHITE, 0.4 * (1 - k / 10.0)**2)) } if plate && plate.look[1] == :sheen
      stx(top, x + 22, y + 18, 84, 22, $Trainer.name, words, PF::TEXT, 2)
      stx(top, x + 28, y + 44, 60, 12, _INTL("MONEY"), words, PF::TINY)
      stx(top, x + 28, y + 58, 72, 12, _INTL("TIME"), words, PF::TINY)
      plain(top, x + 28, y + 44, 72, 12, num(TC.money), TC.skin("Green"), PF::TINY, 1)
      plain(top, x + 28, y + 58, 72, 12, TC.play_words, TC.skin("Blue"), PF::TINY, 1)
      padlock(top, x + 112, y + 6, Color.new(250, 252, 255)) if locked
    end

    # A title as the ID shows it
    def mini_title(base, top, c, x, y, title_id)
      glass(base, c, x, y + 14, x + 128, y + 82, 8)
      stx(top, x, y + 22, 128, 26, $Trainer.name, pif(c, "Dark"), PF::TITLE, 2)
      title_id(top, c, x, 128, y + 52, UL.name(:titles, title_id).upcase, " · ID")
    end

    def mini_case(base, top, c, x, y, kind)
      badge_case(base, top, c, x + 6, y + 30, 15, 8, 11, 15, kind)
    end

    def mini_tags(base, top, c, x, y, look)
      run_tags(top, c, x + 4, x + 128, y + 30, look)
    end

    #--------------------------------------------------------------------------
    # Style: the Dressing Room
    #--------------------------------------------------------------------------
    def group_key
      return GROUPS[@group][0]
    end

    # What a group can be set to, in order (plates: Theme first)
    def style_values(key)
      return UL.owned(:backgrounds) if key == :backgrounds
      return [:theme] + UL.owned(:plates).map(&:id) if key == :plates
      return UL.owned(key).map(&:id)
    end

    def kept_value(key)
      case key
      when :backgrounds then return TC.background
      when :plates then return UL.style["plate"] ? UL.style["plate"].to_sym : :theme
      when :titles then return UL.title_id
      when :cases then return (UL.style["case"] || :glass).to_sym
      when :tags then return UL.tag_look
      end
      return nil
    end

    def value_now(key)
      return @pending.key?(key) ? @pending[key] : kept_value(key)
    end

    def value_name(key, v)
      return _INTL("Theme") if key == :plates && v == :theme
      return UL.name(key, v)
    end

    def change_value(dir)
      key = group_key
      list = style_values(key)
      return if list.length < 2
      i = list.index { |v| v.to_s == value_now(key).to_s } || 0
      v = list[(i + dir) % list.length]
      if v.to_s == kept_value(key).to_s
        @pending.delete(key)
      else
        @pending[key] = v
      end
      paint_art(value_now(:backgrounds)) if key == :backgrounds
      pbPlayCursorSE
      refresh
    end

    # A keeps every change tried on
    def keep_changes
      return false if @pending.empty?
      st = UL.style
      @pending.each do |key, v|
        case key
        when :backgrounds then $Trainer.card_background = v.to_s
        when :plates then v == :theme ? st.delete("plate") : st["plate"] = v.to_s
        when :titles then st["title"] = v.to_s
        when :cases then st["case"] = v.to_s
        when :tags then st["tags"] = v.to_s
        end
      end
      Reloaded::Log.info("Trainer Card style kept: #{@pending.map { |k, v| "#{k} #{v}" }.join(", ")}", :trainer_card)
      @pending = {}
      pbSEPlay("GUI trainer card open") rescue pbPlayDecisionSE
      refresh
      return true
    end

    def put_back
      bg = @pending.key?(:backgrounds)
      @pending = {}
      paint_art if bg
      refresh
    end

    # Leaving Style with an unkept change asks first (his pick): Keep is the
    # default, Put Back undoes them. True to go on.
    def leave_style
      return true if @pending.empty?
      c = palette
      names = @pending.keys.map { |k| _INTL(ONE[k]) }
      words = names.length == 1 ? names[0] : names[0..-2].join(", ") + _INTL(" and ") + names[-1]
      segments = []
      @pending.each_with_index do |(key, v), i|
        segments << [(i > 0 ? "   " : "") + _INTL("{1}: ", _INTL(ONE[key])), c[:dim], i > 0]
        segments << [value_name(key, kept_value(key)), c[:txt], true]
        segments << [_INTL(" to "), c[:dim]]
        segments << [value_name(key, v), c[:txt], true]
      end
      pick = with_hints([[:lr, _INTL("Choose")], [button(:C), _INTL("OK")], [button(:B), _INTL("Cancel")]]) do
        DL.ask(self, _INTL("Keep These Changes?"), _INTL("You changed the card's {1}.", words), segments, [_INTL("Keep"), _INTL("Put Back")], 0)
      end
      pick == 0 ? keep_changes : put_back
      return true
    end

    def style_input
      if Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN)
        dir = Input.repeat?(Input::DOWN) ? 1 : -1
        target = @group + dir
        return nil if (target < 0 || target >= GROUPS.length) && !fresh?(dir)
        @group = target % GROUPS.length
        pbPlayCursorSE
        refresh
      elsif Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)
        dir = Input.repeat?(Input::RIGHT) ? 1 : -1
        if group_key == :showcase
          @slot = (@slot + dir) % 3
          pbPlayCursorSE
          refresh
        else
          change_value(dir)
        end
      elsif Input.trigger?(Input::USE)
        return pick_showcase if group_key == :showcase
        keep_changes
      end
      return nil
    end

    def style_hints
      if group_key == :showcase
        return [[:ud, _INTL("Group")], [:lr, _INTL("Slot")], [button(:C), _INTL("Change"), :pick_showcase], [button(:B), _INTL("Close"), :close_card]]
      end
      return [[:ud, _INTL("Group")], [:lr, _INTL("Change")], [button(:C), _INTL("Keep"), :keep_changes], [button(:B), _INTL("Close"), :close_card]]
    end

    def draw_style(base, top, c)
      tabs(base, top, c)
      strip(base, top, c, strip_rows(GROUPS.map(&:first)), @group)
      trainer(base, 124, 88)
      showcase_tiles(base, top, c, 120, 262, 52, 46, 6)
      px0 = 306
      px1 = 482
      glass(base, c, px0, 44, px1, 216, 10)
      key = group_key
      stx(top, px0, 50, px1 - px0, 12, _INTL(GROUPS[@group][1]).upcase, pif(c, "Dark"), PF::TINY, 2)
      x = px0 + 24
      v = value_now(key)
      case key
      when :backgrounds then thumb(base, top, c, v, x, 66)
      when :plates then mini_plate(base, top, c, x, 66, v == :theme ? nil : UL.item(:plates, v))
      when :titles then mini_title(base, top, c, x, 66, v)
      when :cases then mini_case(base, top, c, x, 66, v)
      when :tags then mini_tags(base, top, c, x, 66, v)
      when :showcase then showcase_slots(base, top, c, x)
      end
      if key == :showcase
        pk = @showcase[@slot]
        arrows_name(top, c, px0, px1, 166, _INTL("Slot {1}: {2}", @slot + 1, pk ? pk.name : _INTL("Empty")))
        stx(top, px0, 190, px1 - px0, 18, _INTL("Party or Boxes"), pif(c, "Dark"), PF::TEXT, 2)
      else
        arrows_name(top, c, px0, px1, 166, value_name(key, v))
        n, m = UL.count(key)
        stx(top, px0, 190, px1 - px0, 18, _INTL("{1} of {2} Unlocked", num(n), num(m)), pif(c, "Dark"), PF::TEXT, 2)
      end
      # Money (his pick, Q19), the wardrobe's counts (Q25); Glimmer Coins only when there are some
      glass(base, c, px0, 224, px1, 300, 10)
      stx(top, px0, 230, px1 - px0, 12, _INTL("MONEY"), pif(c, "Dark"), PF::TINY, 2)
      stx(top, px0, 244, px1 - px0, 26, money(TC.money), pif(c, "Green"), PF::TITLE, 2)
      coins = ($Trainer.cosmetics_money rescue 0).to_i
      clothes = (Array($Trainer.unlocked_clothes) rescue []).length
      hats = (Array($Trainer.unlocked_hats) rescue []).length
      line = _INTL("CLOTHES {1} · HATS {2}", clothes, hats)
      line = _INTL("{1} GLIMMER COINS · ", num(coins)) + line if coins > 0
      stx(top, px0, 276, px1 - px0, 12, line, pif(c, "Dark"), PF::TINY, 2)
    end

    # Showcase: the three slots, numbered, the picked one lit
    def showcase_slots(base, top, c, x)
      @showcase.each_with_index do |pk, i|
        tx = x + 2 + i * 44
        showcase_tile_at(base, top, c, pk, tx, 84, 38, 36, 30)
        @cursor_rect = [tx - 3, 81, 44, 42] if i == @slot
        plain(top, tx, 124, 38, 12, (i + 1).to_s, pif(c, "Dark"), PF::TINY, 2)
      end
    end

    #--------------------------------------------------------------------------
    # The Showcase Slot popup: party first, then the boxes
    #--------------------------------------------------------------------------
    def showcase_choices
      out = TC.party.reject { |pk| (pk.egg? rescue true) }.map { |pk| [pk, _INTL("PARTY"), :party] }
      st = $PokemonStorage
      if st
        st.maxBoxes.times do |b|
          next unless st[b]
          st.maxPokemon(b).times { |i| (pk = st[b, i]) && !(pk.egg? rescue true) && out << [pk, _INTL("BOX {1}", b + 1), :box] }
        end
      end
      return out
    rescue StandardError
      return TC.party.map { |pk| [pk, _INTL("PARTY"), :party] }
    end

    def pick_showcase
      list = showcase_choices
      return nil if list.empty?
      pbPlayDecisionSE
      index = 0
      first = 0
      redraw = true
      hints = [[:ud, _INTL("Choose")], [button(:C), _INTL("Put It Here")], [button(:A), _INTL("Clear Slot")], [button(:B), _INTL("Back")]]
      with_hints(hints) do
        loop do
          first = index if index < first
          first = index - PICK_ROWS + 1 if index >= first + PICK_ROWS
          if redraw
            paint_pick(overlay, palette, list, index, first)
            redraw = false
          end
          Graphics.update
          Input.update
          pbUpdate
          pt = Reloaded::Pointer
          if pt.moved? && (i = pt.hit(@pick_hits)) && i != index
            index = i
            redraw = true
          end
          if (pt.left? && (i = pt.hit(@pick_hits))) || Input.trigger?(Input::USE)
            index = i if i
            set_slot((list[index][0].personalID rescue nil))
            pbPlayDecisionSE
            break
          elsif Input.trigger?(Input::ACTION)
            set_slot(nil)
            pbPlayCancelSE
            break
          elsif pt.right? || Input.trigger?(Input::BACK)
            pbPlayCancelSE
            break
          elsif Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN)
            dir = Input.repeat?(Input::DOWN) ? 1 : -1
            target = index + dir
            next if (target < 0 || target >= list.length) && !fresh?(dir)
            index = target % list.length
            pbPlayCursorSE
            redraw = true
          end
        end
      end
      overlay.clear
      refresh
      return nil
    end

    def set_slot(pid)
      d = TC.data
      return unless Reloaded::SaveStore.loaded?
      picks = Array(d["showcase"]).first(3)
      picks.fill(nil, picks.length...3)
      picks[@slot] = pid
      d["showcase"] = picks
      @showcase = TC.showcase
    end

    def paint_pick(b, c, list, index, first)
      w = 330
      rh = 30
      h = 40 + PICK_ROWS * rh + 40
      x = (W - w) / 2
      y = (H - h) / 2
      DL.frame(b, c, x, y, w, h, _INTL("Showcase Slot {1}", @slot + 1))
      @pick_hits = []
      list[first, PICK_ROWS].each_with_index do |(pk, where, kind), k|
        i = first + k
        ry = y + 40 + k * rh
        @pick_hits << [i, x + 6, ry, x + w - 6, ry + rh - 2]
        DL.send(:cursor_row, b, c, x + 6, ry, x + w - 6, ry + rh - 2) if i == index
        icon_at(b, icon_for(pk), x + 30, ry + rh / 2, 26)
        P.text(b, x + 50, ry, 108, rh - 2, PF.fit(PF::TEXT, pk.name.to_s, 106), c[:opt])
        P.text(b, x + 160, ry, 60, rh - 2, _INTL("Lv. {1}", pk.level), c[:dim])
        fill, col = PP.badge(c, kind == :party ? WIN_GREEN : [130, 190, 250])
        P.pill(b, x + w - 16, ry + 7, where, fill, col)
      end
      now = @showcase[@slot]
      P.small(b, x, y + h - 30, w, 16, _INTL("Now: {1}", now ? now.name : _INTL("Empty")), c[:dim], 2)
    end

    #--------------------------------------------------------------------------
    # Unlocks
    #--------------------------------------------------------------------------
    def cat_key
      return CATS[@cat]
    end

    # [name, id, need, progress, state, from, milestone] for each entry;
    # backgrounds owned first, then those to buy here, then the locked
    def unlock_entries
      key = cat_key
      return @entries if @entries && @entries_for == key
      if key == :backgrounds
        rows = UL.backgrounds_all.each_with_index.map do |id, i|
          st, need, from, prog = UL.background_state(id)
          [[UL.name(:backgrounds, id), id, need, prog, st, from, UL.milestone_of(:backgrounds, id)], i]
        end
        order = { :got => 0, :buy => 1, :locked => 2 }
        list = rows.sort_by { |r, i| [order[r[4]], i] }.map(&:first)
      else
        list = UL.items(key).map do |it|
          need, prog, from, m = UL.source(key, it.id)
          st = UL.owned?(key, it.id) ? :got : :locked
          [UL.name(key, it.id), it.id, need, st == :got ? nil : prog, st, from, m]
        end
      end
      @entries_for = key
      return @entries = list
    end

    def forget_entries
      @entries = nil
    end

    def unlocks_input
      list = unlock_entries
      if Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN)
        dir = Input.repeat?(Input::DOWN) ? 1 : -1
        target = @entry + dir
        return nil if (target < 0 || target >= list.length) && !fresh?(dir)
        @entry = target % [list.length, 1].max
        scroll_to_entry
        pbPlayCursorSE
        refresh
      elsif Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)
        @cat = (@cat + (Input.repeat?(Input::RIGHT) ? 1 : -1)) % CATS.length
        @entry = 0
        @first_row = 0
        pbPlayCursorSE
        refresh
      elsif Input.trigger?(Input::USE)
        unlock_action
      end
      return nil
    end

    def scroll_to_entry
      @first_row = @entry if @entry < @first_row
      @first_row = @entry - ROWS + 1 if @entry >= @first_row + ROWS
    end

    # A on an entry: Buy a background a Printer would sell here, else its details
    def unlock_action
      e = unlock_entries[@entry]
      return nil unless e
      if cat_key == :backgrounds && e[4] == :buy
        buy_background(e)
      else
        unlock_details(e)
      end
      forget_entries
      refresh
      return nil
    end

    def unlocks_hints
      e = unlock_entries[@entry]
      word = e && cat_key == :backgrounds && e[4] == :buy ? _INTL("Buy") : _INTL("Details")
      return [[:ud, _INTL("Choose")], [:lr, _INTL("Category")], [button(:C), word, :unlock_action], [button(:B), _INTL("Close"), :close_card]]
    end

    # Clicks on the strips and the list
    def tab_click
      pt = Reloaded::Pointer
      if [:style, :unlocks].include?(TABS[@tab]) && (hit = (@strip_hits || []).find { |_i, x0, y0, x1, y1| pt.inside?(x0, y0, x1, y1) })
        if TABS[@tab] == :style
          @group = hit[0]
        else
          @cat = hit[0]
          @entry = 0
          @first_row = 0
        end
        pbPlayCursorSE
        refresh
        return nil
      end
      if TABS[@tab] == :unlocks && (hit = (@row_hits || []).find { |_i, x0, y0, x1, y1| pt.inside?(x0, y0, x1, y1) })
        return unlock_action if hit[0] == @entry
        @entry = hit[0]
        pbPlayCursorSE
        refresh
        return nil
      end
      return :none
    end

    def draw_unlocks(base, top, c)
      tabs(base, top, c)
      strip(base, top, c, strip_rows(CATS), @cat, 48, 50)
      lx0 = 108
      lx1 = 330
      glass(base, c, lx0, 44, lx1, 352, 10)
      key = cat_key
      n, m = UL.count(key)
      stx(top, lx0 + 10, 50, lx1 - lx0 - 20, 12, _INTL("{1} · {2} OF {3}", _INTL(GROUPS.find { |k, _n, _i| k == key }[1]).upcase, num(n), num(m)),
          pif(c, "Dark"), PF::TINY)
      list = unlock_entries
      @row_hits = []
      dim_ink = [mix(pif(c, "Dark")[0], words_light?(c) ? Color.new(250, 252, 255) : c[:panel], 0.35), pif(c, "Dark")[1]]
      list[@first_row, ROWS].to_a.each_with_index do |(name, _id, need, prog, st, _from, _m), k|
        i = @first_row + k
        y = 66 + k * 47
        @row_hits << [i, lx0 + 4, y - 2, lx1 - 4, y + 43]
        @cursor_rect = [lx0 + 4, y - 2, lx1 - lx0 - 8, 45] if i == @entry
        mark(top, c, lx0 + 10, y + 5, st)
        stx(top, lx0 + 26, y, lx1 - lx0 - 36, 22, PF.fit(PF::TEXT, name, lx1 - lx0 - 36), st == :locked ? dim_ink : pif(c, "Dark"), PF::TEXT)
        stx(top, lx0 + 26, y + 21, lx1 - lx0 - 70, 12, need, pif(c, "Dark"), PF::TINY)
        if st == :got || st == :buy
          price = UL.price
          label, rgb = st == :got ? [_INTL("UNLOCKED"), WIN_GREEN] : [money(price), TC.money >= price ? WIN_GREEN : LOSS_RED]
          on_name = 26 + PF.width(PF::TEXT, name) + 8 + PF.width(PF::TINY, label) + 12 <= lx1 - lx0 - 10
          tag(top, c, lx1 - 10, on_name ? y + 4 : y + 19, label, rgb, true)
        elsif prog
          plain(top, lx0 + 10, y + 20, lx1 - lx0 - 20, 12, "#{num(prog[0])}/#{num(prog[1])}", pif(c, "Dark"), PF::TINY, 1)
          PP.bar(base, c, lx0 + 28, y + 37, lx1 - lx0 - 46, [prog[0].to_f / prog[1], 1.0].min, pif(c, "Blue")[0], 3)
        end
      end
      e = list[@entry]
      return unless e
      name, id, need, _prog, st, from, _m = e
      px0 = 338
      px1 = 484
      glass(base, c, px0, 44, px1, 250, 10)
      stx(top, px0, 50, px1 - px0, 12, _INTL(ONE[key]).upcase, pif(c, "Dark"), PF::TINY, 2)
      preview(base, top, c, key, id, px0 + 9, 66, st == :locked)
      stx(top, px0, 166, px1 - px0, 22, PF.fit(PF::TEXT, name, px1 - px0 - 8), pif(c, "Dark"), PF::TEXT, 2)
      y = 190
      P.wrap(need.to_s.upcase, px1 - px0 - 16, PF::TINY).each { |ln| stx(top, px0, y, px1 - px0, 13, ln, pif(c, "Dark"), PF::TINY, 2); y += 14 }
      y += 4
      P.wrap(_INTL("FROM: {1}", from.to_s.upcase), px1 - px0 - 16, PF::TINY).each { |ln| stx(top, px0, y, px1 - px0, 13, ln, pif(c, "Blue"), PF::TINY, 2); y += 14 } unless from.to_s.empty?
    end

    def preview(base, top, c, key, id, x, y, locked)
      case key
      when :backgrounds then thumb(base, top, c, id, x, y, locked)
      when :plates then mini_plate(base, top, c, x, y, UL.item(:plates, id), locked)
      when :titles then mini_title(base, top, c, x, y, id)
      when :cases then mini_case(base, top, c, x, y, id)
      when :tags then mini_tags(base, top, c, x, y, id)
      end
    end

    # Owned: a green dot; to buy: a blue coin; locked: a padlock
    def mark(top, c, x, y, st)
      case st
      when :got then P.ui.rbox(top, x, y, x + 10, y + 10, 5, pif(c, "Green")[0])
      when :buy
        P.ui.rbox(top, x, y, x + 10, y + 10, 5, pif(c, "Blue")[0])
        P.ui.rbox(top, x + 3, y + 3, x + 7, y + 7, 2, words_light?(c) ? Color.new(250, 252, 255) : c[:panel])
      else padlock(top, x + 1, y, pif(c, "Dark")[0])
      end
    end

    #--------------------------------------------------------------------------
    # Buy a Background? (money at the Printers' price, his picks Q19, Q21)
    #--------------------------------------------------------------------------
    def buy_background(e)
      id = e[1]
      price = UL.price
      enough = TC.money >= price
      choice = with_hints([[:lr, _INTL("Choose")], [button(:C), _INTL("OK")], [button(:B), _INTL("Cancel")]]) do
        DL.drawn(self, enough ? 2 : 1, 0) { |b, c, ch| paint_buy(b, c, ch, e[0], id, price, enough) }
      end
      return unless enough && choice == 0
      if UL.buy(id)
        pbSEPlay("Mart buy item") rescue pbPlayDecisionSE
      end
    end

    def paint_buy(b, c, choice, name, id, price, enough)
      w = 360
      h = 226
      x = (W - w) / 2
      y = (H - h) / 2
      have = TC.money
      DL.frame(b, c, x, y, w, h, _INTL("Buy a Background?"))
      on_popup(c) { thumb(b, b, c, id, x + 16, y + 44) }
      tx = x + 156
      P.text(b, tx, y + 44, w - 172, 24, PF.fit(PF::ROW, name, w - 172), c[:strong], PF::ROW)
      P.small(b, tx, y + 70, w - 172, 16, _INTL("Price"), c[:dim])
      P.text(b, tx, y + 84, w - 172, 20, money(price), enough ? c[:green] : c[:red])
      P.small(b, tx, y + 108, w - 172, 16, _INTL("Money"), c[:dim])
      left = P.text(b, tx, y + 122, 90, 20, money(have), c[:green])
      if enough
        P.ui.tri(b, tx + left + 6, y + 128, :r, c[:dim], 3)
        P.text(b, tx + left + 18, y + 122, 90, 20, money(have - price), c[:green])
        P.small(b, x, y + 150, w, 16, _INTL("The Printers' Price: Up $500 after each one."), c[:dim], 2)
        DL.button_row(b, c, x, w, y + h - 36, [_INTL("Buy"), _INTL("Cancel")], choice)
      else
        P.small(b, x, y + 150, w, 16, _INTL("Not Enough Money: You need {1} more.", money(price - have)), c[:red], 2)
        DL.button_row(b, c, x, w, y + h - 36, [_INTL("OK")], choice)
      end
    end

    #--------------------------------------------------------------------------
    # An unlock's details: what it needs, how far along, where it comes
    # from; Track It for a milestone not reached yet
    #--------------------------------------------------------------------------
    def unlock_details(e)
      name, id, need, prog, st, from, m = e
      key = cat_key
      trackable = m && st == :locked
      tracked = trackable && UL.tracked == m
      buttons = trackable ? [tracked ? _INTL("Stop Tracking") : _INTL("Track It"), _INTL("Close")] : [_INTL("Close")]
      choice = with_hints([[:lr, _INTL("Choose")], [button(:C), _INTL("OK")], [button(:B), _INTL("Cancel")]]) do
        DL.drawn(self, buttons.length, 0) { |b, c, ch| paint_details(b, c, ch, key, e, buttons) }
      end
      return unless trackable && choice == 0
      tracked ? UL.untrack : UL.track(*m)
      pbPlayDecisionSE
    end

    def paint_details(b, c, choice, key, e, buttons)
      name, id, need, prog, st, from, _m = e
      w = 380
      h = 210
      x = (W - w) / 2
      y = (H - h) / 2
      DL.frame(b, c, x, y, w, h, PF.fit(PF::TEXT, name, w - 40))
      on_popup(c) { preview(b, b, c, key, id, x + 16, y + 44, st == :locked) }
      tx = x + 156
      P.small(b, tx, y + 44, w - 172, 16, _INTL(ONE[key]), c[:dim])
      P.text(b, tx, y + 58, w - 172, 22, PF.fit(PF::TEXT, need.to_s, w - 172), c[:strong])
      ny = y + 88
      if prog
        PP.bar(b, c, tx + 2, ny, w - 180, [prog[0].to_f / prog[1], 1.0].min, c[:blue], 5)
        P.text(b, tx, ny + 8, w - 172, 20, _INTL("{1} of {2}", num(prog[0]), num(prog[1])), c[:txt])
        ny += 30
      end
      P.small(b, tx, ny, w - 172, 16, _INTL("From: {1}", from), c[:blue]) unless from.to_s.empty?
      note = if st == :got then _INTL("Unlocked.")
             elsif key == :backgrounds && UL::KR_BACKGROUNDS.key?(id.to_s) then _INTL("PIF never sells this one: Kanto Reloaded gives it.")
             end
      P.small(b, x + 16, y + 148, w - 32, 16, note, c[:dim], 2) if note
      DL.button_row(b, c, x, w, y + h - 36, buttons, choice)
    end
  end
end
