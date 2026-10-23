#==============================================================================
# Kanto Reloaded: the Party Screen's scene
#==============================================================================
# Kanto Reloaded's PokemonParty_Scene (Reloaded::PartyScreen.scene_class
# includes this): the same methods the game's party logic calls, drawn his
# way (PartyPaint.rb). Every place the game shows the party uses it: the
# pause menu, items from the Bag, choosing for an event, battles.
#
#   the cards     six, two across; the highlighted one glows. Up/Down/Left/
#                 Right choose, A picks (the Pokemon's menu, or what it's
#                 being chosen for), X its Summary, Y moves it (the Switch
#                 flow in one press), B closes. The mouse: pointing picks,
#                 a click uses, a right click goes back, the wheel scrolls.
#   the panel     the highlighted one's details (an Egg's steps, the move a
#                 TM teaches), or its menu: the game's commands in its order
#                 (KIF's and mods' too), a submenu in place; B in a submenu
#                 goes back to the menu
#   Switch        the one moving keeps a gold edge and a MOVING tag, the
#                 panel shows the swap
#   messages      in a bar along the bottom; a question as Kanto Reloaded's
#                 Yes/No popup
#
# Choosing several (a Battle Frontier entry) is left to the game's own
# scene: that instance runs PIF's methods.
#==============================================================================

return unless defined?(Reloaded::Frame) && defined?(Reloaded::PartyPaint)

module Reloaded
  module PartyScene
    include Reloaded::Frame
    include Reloaded::PartyPaint

    MENU_Y = 52               # the menu's first row, from the panel's top
    MENU_ROW = 19
    FOOT_Y = 250              # the line over the description
    FADE = 8                  # frames to fade in or out
    SUBS = ["Item", "Mail", "Kuray Actions", "Hat", "Nickname"].freeze
    # KIF Beta's labels as Kanto Reloaded names them (his asks, 2026-10-21)
    RENAMES = { "Kuray Actions" => "RLD Actions", "Change moves" => "Relearn Moves" }.freeze
    # RLD Actions keeps only these of KIF Beta's actions (his ask, 2026-10-21)
    RLD_KEEP = ["Export"].freeze
    # The panel's two bands (Two Bands, his pick, 2026-10-22): from the wide
    # one's middle, each one's offset and width
    BANDS = [[0, 56], [40, 8]].freeze

    #--------------------------------------------------------------------------
    # The game's scene methods
    #--------------------------------------------------------------------------
    def pbStartScene(party, starthelptext, annotations = nil, multiselect = false)
      @kr_vanilla = multiselect ? true : false
      return super if @kr_vanilla
      @party = party
      @multiselect = false
      @activecmd = 0
      @kr_help = starthelptext
      @kr_annot = annotations
      @kr_mode = :choose
      @kr_source = nil
      @kr_switching = false
      @kr_canswitch = 0
      @kr_menu = nil
      @kr_message = nil
      @kr_picked = nil
      @kr_reopen = false
      @kr_bitmaps = {}
      @kr_card_icons = []
      @kr_panel_icons = {}
      @kr_panel_spots = []
      @kr_card_hits = []
      @kr_menu_hits = []
      frame_init
      open_sprites
      build_icons
      refresh
      fade(:in)
    end

    def pbEndScene
      return super if @kr_vanilla
      fade(:out)
      kr_dispose
    end

    # GhostItem Splicers closes the scene this way (KIF's ModCompat)
    def dispose
      return super if @kr_vanilla && defined?(super)
      kr_dispose
    end

    def update
      return super if @kr_vanilla
      (@kr_card_icons + @kr_panel_icons.values).each { |s| s.update if s && !s.disposed? && s.respond_to?(:update) }
      update_frame
    end

    # The colours (Theme Mode: Dark, or Light for Light and Frost); its
    # popups read them too
    def palette
      return Reloaded::Palette.map_menu
    end

    def pbSetHelpText(helptext)
      return super if @kr_vanilla
      @kr_help = helptext
      refresh
    end

    def pbHasAnnotations?
      return super if @kr_vanilla
      return !@kr_annot.nil?
    end

    def pbAnnotate(annot)
      return super if @kr_vanilla
      @kr_annot = annot
      refresh
    end

    def pbSelect(item)
      return super if @kr_vanilla
      @activecmd = item
      refresh
    end

    def pbPreSelect(item)
      return super if @kr_vanilla
      @activecmd = item
    end

    def pbSwitchBegin(oldid, newid)
      return super if @kr_vanilla
      pbSEPlay("GUI party switch") rescue nil
    end

    def pbSwitchEnd(oldid, newid)
      return super if @kr_vanilla
      pbSEPlay("GUI party switch") rescue nil
      @kr_source = nil
      @kr_switching = false
      build_icons
      refresh
    end

    def pbClearSwitching
      return super if @kr_vanilla
      @kr_source = nil
      @kr_switching = false
      refresh
    end

    def pbHardRefresh
      return super if @kr_vanilla
      build_icons
      refresh
    end

    def pbRefresh
      return super if @kr_vanilla
      build_icons
      refresh
    end

    def pbRefreshSingle(i)
      return super if @kr_vanilla
      build_icons
      refresh
    end

    # The Summary, this screen faded out meanwhile
    def pbSummary(pkmnid, inbattle = false)
      return super if @kr_vanilla
      fade(:out)
      hidden do
        scene = ::PokemonSummary_Scene.new
        screen = ::PokemonSummaryScreen.new(scene, inbattle)
        screen.pbStartScreen(@party, pkmnid)
        yield if block_given?
      end
      build_icons
      refresh
      fade(:in)
    end

    # A message, in the bar along the bottom (his pick); A goes on (a long
    # one a page at a time)
    def pbDisplay(text)
      return super if @kr_vanilla
      pages = message_pages(plain(text))
      pbPlayDecisionSE
      pages.each do |lines|
        @kr_message = lines
        refresh
        loop do
          Graphics.update
          Input.update
          update
          pt = Reloaded::Pointer
          break if Input.trigger?(Input::USE) || Input.trigger?(Input::BACK) || pt.left? || pt.right?
        end
      end
      @kr_message = nil
      refresh
    end

    # A question: Kanto Reloaded's Yes/No popup
    def pbDisplayConfirm(text)
      return super if @kr_vanilla
      pkmn = @party[@activecmd]
      title = pkmn ? pkmn.name : _INTL("Party")
      ok = Reloaded::Dialogs.confirm(self, title, plain(text), _INTL("Yes"), _INTL("No"), true)
      refresh
      return ok
    end

    #--------------------------------------------------------------------------
    # Choosing a Pokemon (the game's innermost pbChoosePokemon)
    #--------------------------------------------------------------------------
    def kr_choose_pokemon(switching = false, initialsel = -1, canswitch = 0)
      # B in a submenu went back to the Pokemon's menu: it opens again
      if @kr_reopen && !switching && canswitch == 1 && @party[@activecmd]
        @kr_reopen = false
        return @activecmd
      end
      @kr_reopen = false
      @kr_picked = nil
      @kr_switching = switching
      @kr_source = switching ? @activecmd : nil
      @kr_canswitch = canswitch
      @activecmd = initialsel if initialsel >= 0
      @activecmd = nearest(@activecmd)
      @kr_mode = :choose
      refresh
      loop do
        Graphics.update
        Input.update
        update
        pt = Reloaded::Pointer
        act = nil
        if pointer_hover && (i = pt.hit(@kr_card_hits)) && i != @activecmd && choosable?(i)
          choose(i)
        end
        if pt.left?
          handled, result = hint_click
          if handled
            act = result
          elsif (i = pt.hit(@kr_card_hits))
            if choosable?(i)
              @activecmd = i
              act = :use
            else
              pbPlayBuzzerSE
            end
          end
        elsif pt.right?
          act = :back
        elsif (w = pt.wheel) != 0
          step(w > 0 ? :next : :prev)
        elsif Input.repeat?(Input::UP) then step(:up)
        elsif Input.repeat?(Input::DOWN) then step(:down)
        elsif Input.repeat?(Input::LEFT) then step(:left)
        elsif Input.repeat?(Input::RIGHT) then step(:right)
        elsif Input.trigger?(Input::USE) then act = :use
        elsif Input.trigger?(Input::ACTION) then act = :summary      # X on a controller
        elsif Input.trigger?(Input::X) then act = :move              # Y on a controller
        elsif Input.trigger?(Input::BACK) then act = :back
        end
        case act
        when :use
          if !@party[@activecmd] || greyed?(@activecmd)
            pbPlayBuzzerSE
            next
          end
          pbPlayDecisionSE
          return @activecmd
        when :summary
          next pbPlayBuzzerSE unless @party[@activecmd]
          pbPlayDecisionSE
          pbSummary(@activecmd, in_battle?)
        when :move
          if canswitch == 1 && @party.length > 1 && @party[@activecmd]
            pbPlayDecisionSE
            return [1, @activecmd]
          elsif canswitch == 2
            pbPlayCancelSE
            return -1
          end
          pbPlayBuzzerSE
        when :back
          switching ? pbPlayCancelSE : (pbPlayCloseMenuSE rescue pbPlayCancelSE)
          return -1
        end
      end
    end

    # the hint line's buttons, for the mouse
    def hint_use; return :use; end
    def hint_summary; return :summary; end
    def hint_move; return :move; end
    def hint_back; return :back; end

    def in_battle?
      return $game_temp && $game_temp.respond_to?(:in_battle) && $game_temp.in_battle ? true : false
    end

    def choose(i)
      @activecmd = i
      pbPlayCursorSE
      refresh
    end

    # Can't be chosen for this (Grey Out, his pick): NOT ABLE
    def greyed?(i)
      return false unless @kr_annot && @kr_annot[i]
      return @kr_annot[i].to_s == _INTL("NOT ABLE")
    end

    def choosable?(i)
      return false unless i >= 0 && i < @party.length && @party[i]
      return true unless greyed?(i)
      # all greyed: they can be pointed at (the game says why)
      return (0...@party.length).all? { |k| greyed?(k) }
    end

    def nearest(i)
      i = [[i.to_i, 0].max, [@party.length - 1, 0].max].min
      return i if choosable?(i)
      found = (0...@party.length).map { |k| (i + k) % @party.length }.find { |k| choosable?(k) }
      return found || i
    end

    # Up/Down by row, Left/Right within it, each round to the other end;
    # the mouse wheel through them in order
    def step(dir)
      n = @party.length
      return if n == 0
      i = @activecmd
      column = (0...n).select { |k| k % 2 == i % 2 }
      order = case dir
              when :right then [i + 1] + (1...n).map { |k| (i + k) % n }
              when :left then [i - 1] + (1...n).map { |k| (i - k) % n }
              when :next then (1...n).map { |k| (i + k) % n }
              when :prev then (1...n).map { |k| (i - k) % n }
              when :down then column.rotate(column.index(i).to_i + 1)
              when :up then column.reverse.rotate(column.reverse.index(i).to_i + 1)
              end
      to = order.find { |k| k != i && k >= 0 && k < n && choosable?(k) }
      to ||= (1...n).map { |k| (i + (dir == :up || dir == :left ? -k : k)) % n }.find { |k| choosable?(k) }
      return unless to && to != i
      choose(to)
    end

    #--------------------------------------------------------------------------
    # The menu (the game's innermost pbShowCommands)
    #--------------------------------------------------------------------------
    def kr_show_commands(helptext, commands, index = 0)
      pkmn = @party[@activecmd]
      sub = !@kr_picked.nil?
      extras = []
      if !sub && pkmn && commands.last.to_s == _INTL("Cancel") && !in_battle?
        extras = Reloaded::PartyScreen.commands_for(pkmn)
      end
      # [where it is in the game's list (or [:extra, k], a mod's), the command]
      entries = commands.each_with_index.map { |cmd, i| [i, cmd] }
      unless extras.empty?
        entries = entries[0...-1] + extras.each_with_index.map { |(_c, l), k| [[:extra, k], l] } + [entries.last]
      end
      entries = entries.reject { |_w, cmd| hidden_command?(raw_label(cmd), pkmn, sub) }
      rows = entries.map { |_w, cmd| row_of(cmd, pkmn) }
      heading = sub ? @kr_picked : nil
      note = sub && helptext.to_s != _INTL("Do what with {1}?", pkmn ? pkmn.name : "") ? plain(helptext) : nil
      start = entries.index { |w, _c| w == index.to_i } || 0
      @kr_menu = { :rows => rows, :index => start, :top => 0, :heading => heading, :note => note, :pkmn => pkmn }
      @kr_mode = :menu
      refresh
      ret = run_menu
      @kr_mode = :choose
      @kr_menu = nil
      raw = ret >= 0 ? raw_label(entries[ret][1]) : nil
      what = ret >= 0 ? entries[ret][0] : -1
      if ret < 0 || [_INTL("Cancel"), _INTL("Back")].include?(raw)
        # B (or Cancel) in a submenu goes back to the Pokemon's menu
        @kr_reopen = true if sub
        @kr_picked = nil unless sub
      elsif !sub
        @kr_picked = rows[ret][0]
        @kr_picked_raw = raw
      end
      if what.is_a?(Array)
        run_extra(extras[what[1]][0], pkmn)
        @kr_picked = nil
        refresh
        return commands.length - 1          # "Cancel" in the game's list: nothing more to do
      end
      refresh
      return what
    end

    def raw_label(cmd)
      return cmd.is_a?(Array) ? cmd[0].to_s : cmd.to_s
    end

    # RLD Actions (KIF Beta's Kuray Actions) shows only Export, and only
    # while Export can be used
    def hidden_command?(label, pkmn, sub)
      kuray = _INTL("Kuray Actions")
      if sub
        return false unless @kr_picked_raw == kuray
        return !(RLD_KEEP.map { |k| _INTL(k) } + [_INTL("Cancel")]).include?(label)
      end
      return false unless label == kuray
      return true unless defined?(::KIF::PCActions) && pkmn
      return ::KIF::PCActions.available(pkmn).none? { |_a, l| RLD_KEEP.map { |k| _INTL(k) }.include?(l.to_s) }
    rescue StandardError
      return false
    end

    # a mod's command (Reloaded::PartyScreen.add_command)
    def run_extra(cmd, pkmn)
      cmd.handler.call(self, pkmn, @activecmd) if cmd.handler
    rescue StandardError => e
      Reloaded::Log.exception("A party command failed (#{cmd.id})", e, :party_screen)
    ensure
      build_icons
    end

    # [label, kind, type]: a field move (the game marks it [name, 1]) in
    # blue with its type's chip, an arrow on one that opens more
    def row_of(cmd, pkmn)
      if cmd.is_a?(Array)
        label = cmd[0].to_s
        mv = pkmn && pkmn.moves.find { |m| m && m.name.to_s == label }
        return [label, :field, mv ? (mv.type rescue nil) : nil]
      end
      label = cmd.to_s
      kind = SUBS.any? { |s| _INTL(s) == label } ? :sub : nil
      shown = RENAMES.find { |from, _to| _INTL(from) == label }
      return [shown ? _INTL(shown[1]) : label, kind, nil]
    end

    def run_menu
      m = @kr_menu
      loop do
        Graphics.update
        Input.update
        update
        pt = Reloaded::Pointer
        act = nil
        if pointer_hover && (i = pt.hit(@kr_menu_hits)) && i != m[:index]
          m[:index] = i
          pbPlayCursorSE
          refresh
        end
        if pt.left?
          handled, result = hint_click
          if handled
            act = result
          elsif (i = pt.hit(@kr_menu_hits))
            m[:index] = i
            act = :use
          end
        elsif pt.right?
          act = :back
        elsif (w = pt.wheel) != 0
          menu_step(w > 0 ? 1 : -1, false)
        elsif Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN)
          menu_step(Input.repeat?(Input::UP) ? -1 : 1, Input.trigger?(Input::UP) || Input.trigger?(Input::DOWN))
        elsif Input.trigger?(Input::USE)
          act = :use
        elsif Input.trigger?(Input::BACK)
          act = :back
        end
        if act == :use
          pbPlayDecisionSE
          return m[:index]
        elsif act == :back
          pbPlayCancelSE
          return -1
        end
      end
    end

    # a held direction stops at the ends; a fresh press goes round
    def menu_step(dir, fresh)
      m = @kr_menu
      n = m[:rows].length
      to = m[:index] + dir
      if to < 0 || to >= n
        return unless fresh
        to %= n
      end
      m[:index] = to
      pbPlayCursorSE
      refresh
    end

    #--------------------------------------------------------------------------
    # Words
    #--------------------------------------------------------------------------
    # The game's message codes taken out (\1, \se[...], \wtnp[...])
    def plain(text)
      t = text.to_s.gsub("\1", "").gsub(/\\[a-zA-Z]+\[[^\]]*\]/, "").gsub(/\\[nrl]/, " ").gsub(/\\[a-zA-Z.!|^]/, "")
      return t.gsub(/\s+/, " ").strip
    end

    # The message's lines, two to a page
    def message_pages(text)
      room = W - 70
      lines = [""]
      text.split(" ").each do |word|
        try = lines.last.empty? ? word : "#{lines.last} #{word}"
        if P.width(PF::TEXT, try) <= room then lines[-1] = try else lines << word end
      end
      return lines.each_slice(2).to_a
    end

    def title
      teaching = Reloaded::PartyScreen.teaching
      src = @kr_switching && @kr_source ? @party[@kr_source] : nil
      return Reloaded::PartyScreen.title_for(@kr_help, src, teaching && @kr_annot ? teaching : nil)
    end

    # The Switch flow (not moving an item, or a move used on another)
    def switch_flow?
      return @kr_switching && @kr_source && @kr_help.to_s == _INTL("Move to where?")
    end

    def types_of(pkmn)
      list = pkmn.respond_to?(:types) ? Array(pkmn.types) : [(pkmn.type1 rescue nil), (pkmn.type2 rescue nil)]
      list += [pkmn.type3] if pkmn.respond_to?(:type3)
      return list.compact.uniq
    rescue StandardError
      return []
    end

    #--------------------------------------------------------------------------
    # Hints
    #--------------------------------------------------------------------------
    def hint_pairs
      return [[button(:C), _INTL("Continue"), :hint_use]] if @kr_message
      if @kr_mode == :menu
        return [[:ud, _INTL("Choose")], [button(:C), _INTL("Select"), :hint_use], [button(:B), _INTL("Back"), :hint_back]]
      end
      use = if @kr_canswitch == 1 then _INTL("Options")
            elsif switch_flow? then _INTL("Switch Here")
            elsif Reloaded::PartyScreen.teaching && @kr_annot then _INTL("Teach")
            else _INTL("Select")
            end
      out = [[:ud, _INTL("Choose")], [button(:C), use, :hint_use]]
      out << [button(:A), _INTL("Summary"), :hint_summary] if @party[@activecmd]
      out << [button(:X), _INTL("Move"), :hint_move] if @kr_canswitch == 1 && @party.length > 1
      out << [button(:B), @kr_canswitch == 1 ? _INTL("Close") : _INTL("Cancel"), :hint_back]
      return out
    end

    #--------------------------------------------------------------------------
    # Layers
    #--------------------------------------------------------------------------
    def sprites
      return super + (@kr_card_icons + (@kr_panel_icons || {}).values).compact.reject { |s| s.disposed? }
    end

    def fade(way)
      return unless @viewport && !@viewport.disposed?
      FADE.times do |k|
        a = way == :in ? 255 - 255 * (k + 1) / FADE : 255 * (k + 1) / FADE
        @viewport.color = Color.new(0, 0, 0, a)
        Graphics.update
      end
      @viewport.color = Color.new(0, 0, 0, way == :in ? 0 : 255)
    end

    def kr_dispose
      (@kr_card_icons + (@kr_panel_icons || {}).values).each { |s| s.dispose if s && !s.disposed? }
      @kr_card_icons = []
      @kr_panel_icons = {}
      (@kr_bitmaps || {}).each_value { |b| b.dispose if b && !b.disposed? }
      @kr_bitmaps = {}
      @kr_bg.dispose if @kr_bg && !@kr_bg.disposed?
      @kr_bg = nil
      dispose_sprites
      @viewport.dispose if @viewport && !@viewport.disposed?
    end

    # The cards' icons, made again after anything that may have changed the
    # party (Big Pokemon Icons or small, as the player has it)
    def build_icons
      @kr_card_icons.each { |s| s.dispose if s && !s.disposed? }
      @kr_card_icons = @party.map { |pkmn| pkmn ? icon_for(pkmn) : nil }
      @kr_panel_icons.each_value { |s| s.dispose if s && !s.disposed? }
      @kr_panel_icons = {}
    end

    def icon_for(pkmn)
      s = Reloaded::PartyIcons.icon(pkmn, @viewport, 1)
      return nil unless s
      art = s.bitmap ? Reloaded::PartyIcons.art_rect(s.bitmap, [s.src_rect.height, 1].max) : nil
      s.instance_variable_set(:@kr_art, art)
      s.visible = false
      return s
    end

    # an icon's art fitted to a box x box square, its middle on cx, cy
    def fit(s, cx, cy, box)
      return unless s
      r = s.instance_variable_get(:@kr_art) || Rect.new(0, 0, s.src_rect.width, s.src_rect.height)
      s.zoom_x = s.zoom_y = box.to_f / [r.width, r.height, 1].max
      s.ox = r.x + r.width / 2
      s.oy = r.y + r.height / 2
      s.x = cx
      s.y = cy
      s.visible = true
    end

    def place_icons
      @kr_card_icons.each_with_index do |s, i|
        next unless s
        x, y = slot_xy(i)
        fit(s, x + 30, y + 46, @party[i].egg? ? 34 : 50)
      end
      used = {}
      @kr_panel_spots.each do |pkmn, cx, cy, box|
        key = "#{pkmn.object_id}/#{box}"
        s = (@kr_panel_icons[key] ||= icon_for(pkmn))
        fit(s, cx, cy, box)
        used[key] = true
      end
      @kr_panel_icons.each { |k, s| s.visible = false if s && !used[k] }
    end

    #--------------------------------------------------------------------------
    # Painting
    #--------------------------------------------------------------------------
    def refresh
      return unless @sprite && !@sprite.disposed?
      c = palette
      base = @sprite.bitmap
      top = @top_sprite.bitmap
      over = overlay
      base.clear
      top.clear
      over.clear
      @kr_card_hits = []
      @kr_menu_hits = []
      @kr_panel_spots = []
      base.blt(0, 0, background(c), Rect.new(0, 0, W, H))
      paint_title(top, c, title)
      6.times { |i| paint_slot(base, top, over, c, i) }
      paint_panel(base, top, c)
      paint_hints(base, c)
      paint_message(over, c) if @kr_message
      place_icons
    end

    # the background and header, drawn once for these colours
    def background(c)
      return @kr_bg if @kr_bg && !@kr_bg.disposed? && @kr_bg_for.equal?(c)
      @kr_bg.dispose if @kr_bg && !@kr_bg.disposed?
      @kr_bg = Bitmap.new(W, H)
      paint_background(@kr_bg, c)
      @kr_bg_for = c
      return @kr_bg
    end

    def picture(path)
      return @kr_bitmaps[path] if @kr_bitmaps.key?(path)
      resolved = defined?(pbResolveBitmap) ? (pbResolveBitmap(path) || path) : path
      @kr_bitmaps[path] = (Bitmap.new(resolved) rescue nil)
      return @kr_bitmaps[path]
    end

    def paint_slot(base, top, over, c, i)
      x, y = slot_xy(i)
      pkmn = @party[i]
      return paint_empty(base, top, c, x, y) unless pkmn
      sel = i == @activecmd
      types = types_of(pkmn)
      paint_card_plate(base, c, x, y, pkmn, types, sel)
      card_content(top, c, x, y, pkmn, types, i)
      if @kr_source == i && @kr_switching
        chamfer_outline(top, x, y, x + CW, y + CH, 12, c[:gold])
        P.pill(top, x + 6, y + 6, _INTL("MOVING"), *badge(c, [240, 200, 80]), false) if switch_flow?
      end
      grey_out(over, c, x, y) if greyed?(i)
      @kr_card_hits << [i, x, y, x + CW, y + CH]
    end

    def card_content(top, c, x, y, pkmn, types, i)
      ::KIF.draw_evolock_icon(top, x + 6, y + 64) if defined?(::KIF) && ::KIF.respond_to?(:draw_evolock_icon) &&
                                                   !pkmn.egg? && (pkmn.kif_evo_locked? rescue false)
      if pkmn.egg?
        P.text(top, x + 60, y + 28, CW - 66, 18, _INTL("Egg"), c[:txt], PF::TEXT)
        P.small(top, x + 60, y + 48, CW - 66, 16, Reloaded::PartyScreen.egg_stage(pkmn)[1], c[:dim])
        return
      end
      item = held_item(pkmn)
      item_icon(top, item, x + CW - 14, y + 14, 20) if item
      room = item ? CW - 84 : CW - 66
      font = P.width(PF::TEXT, pkmn.name.to_s) <= room ? PF::TEXT : PF::TINY
      P.text(top, x + 60, y + 6 + (font == PF::TINY ? 3 : 0), room, 18, PF.fit(font, pkmn.name.to_s, room), c[:txt], font)
      lw = paint_level(top, c, pkmn, x + 60, y + 28)
      paint_marks(top, c, pkmn, x + 60 + lw + 5, y + 30)
      small_types(top, types, x + 60, y + 44)
      status_badge(top, c, pkmn, x + CW - 6, y + 44)
      note = @kr_annot && @kr_annot[i]
      if note && !note.to_s.empty?
        unless greyed?(i)
          col = { _INTL("ABLE") => [120, 230, 150], _INTL("LEARNED") => [130, 190, 250] }[note.to_s] || [150, 160, 175]
          P.pill(top, x + CW - 10, y + CH - 30, note.to_s, *badge(c, col), true)
        end
        return
      end
      P.text(top, x + 60, y + 66, CW - 66, 12, "#{pkmn.hp}/#{pkmn.totalhp}", pkmn.hp > 0 ? c[:txt] : c[:red], PF::TINY, 1)
      bar(top, c, x + 10, y + CH - 13, CW - 28, pkmn.hp.to_f / [pkmn.totalhp, 1].max, hp_colour(c, pkmn))
    end

    def held_item(pkmn)
      item = pkmn.respond_to?(:item_id) ? pkmn.item_id : (pkmn.item rescue nil)
      item = item.id if item.respond_to?(:id)
      return item.nil? || item.to_s.empty? ? nil : item
    rescue StandardError
      return nil
    end

    def item_icon(b, item, cx, cy, size)
      path = item.to_s.include?("/") ? item.to_s : ((::GameData::Item.icon_filename(item) rescue nil) || "Graphics/Items/#{item}")
      bm = picture(path)
      return unless bm
      b.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), bm, Rect.new(0, 0, bm.width, bm.height))
    end

    # "LV 35" and a padlock when it has a level lock (gold, or dim while
    # Level Locking is Off); returns the width
    def paint_level(b, c, pkmn, x, y, align = 0, w = 60)
      s = _INTL("Lv. {1}", pkmn.level)
      lock = defined?(Reloaded::QualityOfLife::LevelLocks) ? Reloaded::QualityOfLife::LevelLocks.get(pkmn) : nil
      tw = P.width(PF::TINY, s) + (lock ? 13 : 0)
      x0 = align == 2 ? x + (w - tw) / 2 : x
      P.text(b, x0, y, tw, 12, s, c[:gold], PF::TINY)
      padlock(b, x0 + tw - 9, y, Reloaded::QualityOfLife::LevelLocks.limit(pkmn) ? c[:gold] : c[:dim]) if lock
      return tw
    end

    def padlock(b, x, y, col)
      b.fill_rect(x + 2, y, 5, 1, col)
      b.fill_rect(x + 1, y + 1, 1, 4, col)
      b.fill_rect(x + 7, y + 1, 1, 4, col)
      b.fill_rect(x, y + 5, 9, 6, col)
      b.fill_rect(x + 4, y + 7, 1, 2, mix(col, BLACK, 0.6))
    end

    # gender (KIF's genderless and pizza icons too) and the shiny star
    # (KIF's, coloured by the kind of shiny), from x
    def paint_marks(b, c, pkmn, x, y)
      w = 0
      if (pkmn.pizza? rescue false) && defined?(::KIF::Gender::ICON_PIZZA)
        pbDrawImagePositions(b, [[::KIF::Gender::ICON_PIZZA, x - 2, y - 4]]) rescue nil
        w += 14
      elsif (pkmn.male? rescue false)
        pixels(b, MALE, x, y, c[:blue])
        w += 9
      elsif (pkmn.female? rescue false)
        pixels(b, FEMALE, x, y, c[:pink])
        w += 8
      elsif (pkmn.genderless? rescue false) && defined?(::KIF::Gender::ICON_GENDERLESS)
        pbDrawImagePositions(b, [[::KIF::Gender::ICON_GENDERLESS, x - 2, y - 2]]) rescue nil
        w += 12
      end
      if (pkmn.shiny? rescue false)
        unless shiny_star(b, pkmn, x + w - 2, y - 5)
          pixels(b, STAR, x + w, y, c[:gold])
        end
      end
    end

    def shiny_star(b, pkmn, x, y)
      return false unless defined?(addShinyStarsToGraphicsArray) && defined?(pbDrawImagePositions)
      pos = []
      addShinyStarsToGraphicsArray(pos, x, y, pkmn.bodyShiny?, pkmn.headShiny?, pkmn.debugShiny?, pkmn.radarShiny?, 0, 0, 16, 16)
      pbDrawImagePositions(b, pos)
      return true
    rescue StandardError
      return false
    end

    def small_types(b, types, x, y)
      sheet = picture(TYPES_SMALL)
      return unless sheet
      types.first(3).each_with_index do |t, k|
        row = (::GameData::Type.get(t).icon_position rescue 0)
        b.blt(x + k * 18, y, sheet, Rect.new(0, row * 16, 16, 16))
      end
    end

    # the game's big type labels, a little under two thirds their size
    # (his ask, 2026-10-21), centred in w from x
    def big_types(b, types, x, y, w)
      sheet = picture(TYPES_BIG)
      return unless sheet
      list = types.first(3)
      lw = 40
      lh = 18
      total = list.length * (lw + 2) - 2
      list.each_with_index do |t, j|
        row = (::GameData::Type.get(t).icon_position rescue 0)
        b.stretch_blt(Rect.new(x + (w - total) / 2 + j * (lw + 2), y, lw, lh), sheet, Rect.new(0, row * 28, 64, 28))
      end
    end

    def status_badge(b, c, pkmn, x, y)
      word, col = if pkmn.hp <= 0 then [_INTL("FNT"), [240, 100, 90]]
                  elsif STATUS[(pkmn.status rescue nil)] then STATUS[pkmn.status]
                  elsif (pkmn.pokerusStage rescue 0) == 1 then [_INTL("PKRS"), [230, 120, 220]]
                  end
      P.pill(b, x, y, word, *badge(c, col), true) if word
    end

    #--------------------------------------------------------------------------
    # The panel
    #--------------------------------------------------------------------------
    def paint_panel(base, top, c)
      return paint_menu(base, top, c) if @kr_mode == :menu && @kr_menu
      return paint_swap(base, top, c) if switch_flow? && @party[@kr_source] && @activecmd != @kr_source && @party[@activecmd]
      pkmn = @party[@activecmd]
      return unless pkmn
      teaching = Reloaded::PartyScreen.teaching
      return paint_teach(base, top, c, pkmn, teaching) if teaching && @kr_annot
      return paint_egg_panel(base, top, c, pkmn) if pkmn.egg?
      paint_details(base, top, c, pkmn)
    end

    # the panel's plate, lit in a colour, its two bands running from the
    # top right to the bottom left (through the top and bottom edges, just
    # clipping the sides) and fading away below the red line at line_y
    # (his ask, 2026-10-22)
    def panel_plate(base, c, col, line_y = GY + LINE_Y)
      cut = 16
      top = mix(c[:panel], col, 0.4)
      bottom = mix(c[:panel], c[:dark], 0.4)
      chamfer_grad(base, DX, GY, DX + DW, GY + DH, cut, top, bottom, mix(c[:line], col, 0.5))
      from = DX + DW - 48                     # the wide band's middle at the top...
      to = DX + 24                            # ...and at the bottom
      (GY + 1...GY + DH - 1).each do |y|
        t = (y - GY).to_f / DH
        left = DX + 1 + [cut - (y - GY), 0].max
        right = DX + DW - 1 - [cut - (GY + DH - 1 - y), 0].max
        mid = from + (to - from) * t
        k = y < line_y ? 0.4 : 0.22 - 0.18 * (y - line_y).to_f / (GY + DH - line_y)
        tint = mix(mix(top, bottom, t), col, k)
        BANDS.each do |off, w|
          a = [(mid + off - w / 2.0).round, left].max
          b = [(mid + off + w / 2.0).round, right].min
          base.fill_rect(a, y, b - a, 1, tint) if b > a
        end
      end
      base.fill_rect(DX + 8, line_y, DW - 16, 2, POKE_RED)
    end

    def paint_details(base, top, c, pkmn)
      types = types_of(pkmn)
      panel_plate(base, c, rgb(Reloaded::PartyScreen.type_rgb(types[0])))
      @kr_panel_spots << [pkmn, DX + DW / 2, GY + 40, 64]
      name = PF.fit(PF::TEXT, pkmn.name.to_s, DW - 16)
      P.text(top, DX, GY + 76, DW, 18, name, c[:txt], PF::TEXT, 2)
      paint_level(top, c, pkmn, DX, GY + 95, 2, DW)
      exp_bar(top, c, pkmn)
      big_types(top, types, DX, GY + 116, DW)    # evenly between the EXP bar and the red line
      P.heading(top, DX + 8, DX + DW - 8, GY + 144, _INTL("About"), c[:dim], c[:line])
      item = held_item(pkmn)
      ability = begin
                  pkmn.ability ? pkmn.ability.name : _INTL("None")
                rescue StandardError
                  ""
                end
      rows = [[_INTL("Nature"), (pkmn.nature.name rescue "")], [_INTL("Ability"), ability],
              [_INTL("Item"), item ? (::GameData::Item.get(item).name rescue item.to_s) : _INTL("None")]]
      rows.each_with_index do |(k, v), j|
        P.small(top, DX + 8, GY + 158 + j * 16, 60, 16, k, c[:dim])
        P.small(top, DX + 66, GY + 158 + j * 16, DW - 74, 16, v.to_s, c[:txt])
      end
      P.heading(top, DX + 8, DX + DW - 8, GY + 208, _INTL("Moves"), c[:dim], c[:line])
      moves(top, c, pkmn, GY + 222)
    end

    def moves(top, c, pkmn, y0)
      Array(pkmn.moves).compact.first(4).each_with_index do |m, j|
        yy = y0 + j * 17
        top.fill_rect(DX + 8, yy + 3, 4, 10, rgb(Reloaded::PartyScreen.type_rgb(m.type)))
        P.text(top, DX + 17, yy, DW - 66, 16, PF.fit(PF::TEXT, m.name.to_s, DW - 66), c[:txt], PF::TEXT)
        total = (m.total_pp rescue 0).to_i
        pp = total > 0 ? "#{m.pp}/#{total}" : "---"
        P.text(top, DX + DW - 48, yy + 2, 40, 12, pp, total > 0 && m.pp < total ? c[:amber] : c[:dim], PF::TINY, 1)
      end
    end

    # EXP to the next level: a thin bar under the level (his pick); at its
    # level lock, full and gold
    def exp_bar(top, c, pkmn)
      frac, locked = exp_frac(pkmn)
      return if frac.nil?
      bar(top, c, DX + (DW - 96) / 2, GY + 108, 96, frac, locked ? c[:gold] : c[:blue], 2)
    end

    def exp_frac(pkmn)
      lock = defined?(Reloaded::QualityOfLife::LevelLocks) ? Reloaded::QualityOfLife::LevelLocks.limit(pkmn) : nil
      return [1.0, true] if lock && pkmn.level >= lock
      gr = pkmn.growth_rate
      max = (::GameData::GrowthRate.max_level rescue 100)
      return [1.0, false] if pkmn.level >= max
      a = gr.minimum_exp_for_level(pkmn.level)
      b = gr.minimum_exp_for_level(pkmn.level + 1)
      return [[[(pkmn.exp - a).to_f / [b - a, 1].max, 0.0].max, 1.0].min, false]
    rescue StandardError
      return nil
    end

    # An Egg: the steps left as a number and a bar, PIF's words under it
    # (Steps Bar, his pick)
    def paint_egg_panel(base, top, c, pkmn)
      panel_plate(base, c, Color.new(150, 200, 140))
      @kr_panel_spots << [pkmn, DX + DW / 2, GY + 52, 60]
      P.text(top, DX, GY + 90, DW, 18, _INTL("Egg"), c[:txt], PF::TEXT, 2)
      words, _short, left, frac = Reloaded::PartyScreen.egg_stage(pkmn)
      P.heading(top, DX + 8, DX + DW - 8, GY + 146, _INTL("Steps Left"), c[:dim], c[:line])
      P.text(top, DX, GY + 160, DW, 18, left.to_s, c[:txt], PF::TEXT, 2)
      bar(top, c, DX + 14, GY + 184, DW - 28, frac, c[:green])
      small_wrap(top, words, DW - 20).each_with_index { |ln, j| P.small(top, DX + 10, GY + 198 + j * 15, DW - 20, 16, ln, c[:dim], 2) }
    end

    # Choosing who learns a move (a TM, a tutor): the move at the top, the
    # highlighted one's moves under it (Grey Out, his pick)
    def paint_teach(base, top, c, pkmn, teaching)
      move = (::GameData::Move.get(teaching[0]) rescue nil)
      return paint_details(base, top, c, pkmn) unless move
      line = GY + LINE_Y
      panel_plate(base, c, rgb(Reloaded::PartyScreen.type_rgb(move.type)), line)
      # the top half (his ask): the name (the TM's icon beside it), the
      # type, the power and accuracy, then what the move does
      icon = teaching[1] ? machine_icon(move.id) : nil
      name = PF.fit(PF::TEXT, move.name.to_s, DW - (icon ? 44 : 16))
      nw = P.width(PF::TEXT, name) + (icon ? 28 : 0)
      nx = DX + (DW - nw) / 2
      if icon
        item_icon(top, icon, nx + 12, GY + 17, 24)
        nx += 28
      end
      P.text(top, nx, GY + 8, nw, 18, name, c[:txt], PF::TEXT)
      big_types(top, [move.type], DX, GY + 30, DW)
      power = if move.base_damage.to_i > 1 then _INTL("POWER {1}", move.base_damage)
              elsif move.base_damage.to_i == 1 then _INTL("POWER ---")
              else _INTL("STATUS")
              end
      acc = move.accuracy.to_i > 0 ? _INTL("ACC {1}", move.accuracy) : _INTL("ACC ---")
      w1 = P.width(PF::TINY, power) + 12
      w2 = P.width(PF::TINY, acc) + 12
      x0 = DX + (DW - w1 - 6 - w2) / 2
      P.pill(top, x0, GY + 53, power, c[:pill], c[:txt], false)
      P.pill(top, x0 + w1 + 6, GY + 53, acc, c[:pill], c[:txt], false)
      # nearly the panel's full width (his ask), four lines at most
      lines = small_wrap(top, move.description.to_s, DW - 8)
      if lines.length > 4
        rest = lines[3..-1].join(" ")
        lines = lines.first(3) + [small_wrap(top, rest, DW - 24).first.to_s.sub(/[.,;:!? ]+\z/, "") + "..."]
      end
      lines.each_with_index { |ln, j| P.small(top, DX + 4, GY + 74 + j * 15, DW - 8, 16, ln, c[:txt], 2) }
      # under the red line: the Pokemon's moves
      if pkmn.egg?
        P.small(top, DX, line + 23, DW, 16, _INTL("An Egg can't learn moves."), c[:dim], 2)
        return
      end
      P.heading(top, DX + 8, DX + DW - 8, line + 9, _INTL("{1}'s Moves", pkmn.name), c[:dim], c[:line])
      moves(top, c, pkmn, line + 25)
      if Array(pkmn.moves).compact.length >= 4 && !(pkmn.hasMove?(move.id) rescue false)
        small_wrap(top, _INTL("It must forget one."), DW - 16).each_with_index do |ln, j|
          P.small(top, DX + 8, line + 95 + j * 15, DW - 16, 16, ln, c[:dim], 2)
        end
      end
    end

    # Words wrapped to a width in the small font, which P.small draws in
    # (P.wrap measures the wider pixel font)
    def small_wrap(b, text, width)
      P.small_font(b)
      out = [""]
      text.to_s.split(/\s+/).each do |word|
        try = out.last.empty? ? word : "#{out.last} #{word}"
        if out.last.empty? || b.text_size(try).width <= width
          out[-1] = try
        else
          out << word
        end
      end
      return out.reject(&:empty?)
    end

    # the TM's own icon for a move, or nil
    def machine_icon(move)
      @kr_machine ||= {}
      return @kr_machine[move] if @kr_machine.key?(move)
      item = nil
      if defined?(::GameData::Item) && ::GameData::Item.respond_to?(:each)
        ::GameData::Item.each do |it|
          next unless it.respond_to?(:is_machine?) && it.is_machine? && it.move == move
          item = it.id
          break
        end
      end
      @kr_machine[move] = item ? (::GameData::Item.icon_filename(item) rescue nil) : nil
      return @kr_machine[move]
    rescue StandardError
      return @kr_machine[move] = nil
    end

    # Switch: the two of them, with a swap mark on the red line (Gold Edge
    # and Preview, his pick)
    def paint_swap(base, top, c)
      a = @party[@kr_source]
      b = @party[@activecmd]
      top_col = mix(c[:panel], c[:selb], 0.25)
      bottom = mix(c[:panel], c[:dark], 0.4)
      chamfer_grad(base, DX, GY, DX + DW, GY + DH, 16, top_col, bottom, mix(c[:line], c[:selb], 0.5))
      P.heading(top, DX + 10, DX + DW - 10, GY + 10, _INTL("Switch"), c[:dim], c[:line])
      [[a, GY + 30], [b, GY + 168]].each do |pkmn, yy|
        @kr_panel_spots << [pkmn, DX + DW / 2, yy + 44, 72]
        P.text(top, DX, yy + 86, DW, 18, PF.fit(PF::TEXT, pkmn.name.to_s, DW - 16), c[:txt], PF::TEXT, 2)
      end
      base.fill_rect(DX + 8, GY + 147, DW - 16, 2, POKE_RED)
      swap_badge(top, c, DX + DW / 2, GY + 148)
    end

    # The menu in the panel (Panel Menu, his pick): a short top, the
    # options in the game's order (a submenu under its heading), what the
    # highlighted one does at the foot
    def paint_menu(base, top, c)
      m = @kr_menu
      pkmn = m[:pkmn]
      col = pkmn && !pkmn.egg? ? rgb(Reloaded::PartyScreen.type_rgb(types_of(pkmn)[0])) : c[:line]
      panel_plate(base, c, col, GY + 44)
      if pkmn
        @kr_panel_spots << [pkmn, DX + 26, GY + 22, 34]
        P.text(top, DX + 48, GY + 6, DW - 56, 18, PF.fit(PF::TEXT, pkmn.name.to_s, DW - 56), c[:txt], PF::TEXT)
        paint_level(top, c, pkmn, DX + 48, GY + 25) unless pkmn.egg?
      end
      y = GY + MENU_Y
      if m[:heading]
        P.heading(top, DX + 10, DX + DW - 10, y, m[:heading].to_s, c[:dim], c[:line])
        y += 16
        if m[:note]
          P.small(top, DX + 10, y, DW - 20, 16, m[:note], c[:dim])
          y += 16
        end
      end
      room = [(GY + FOOT_Y - 4 - y) / MENU_ROW, 1].max
      rows = m[:rows]
      m[:top] = m[:index] - room + 1 if m[:index] >= m[:top] + room
      m[:top] = m[:index] if m[:index] < m[:top]
      m[:top] = [[m[:top], [rows.length - room, 0].max].min, 0].max
      rows[m[:top], room].to_a.each_with_index do |row, k|
        i = m[:top] + k
        ry = y + k * MENU_ROW
        cmd_row(top, c, DX + 12, ry, DW - 24, row, i == m[:index])
        @kr_menu_hits << [i, DX + 6, ry, DX + DW - 6, ry + MENU_ROW - 1]
      end
      P.ui.tri(top, DX + DW / 2 - 4, y - 6, :u, c[:dim], 3) if m[:top] > 0
      P.ui.tri(top, DX + DW / 2 - 4, y + room * MENU_ROW - 2, :d, c[:dim], 3) if m[:top] + room < rows.length
      top.fill_rect(DX + 8, GY + FOOT_Y, DW - 16, 1, c[:line])
      words = Reloaded::PartyScreen.describe(rows[m[:index]][0], pkmn)
      if rows[m[:index]][1] == :field && pkmn
        mv = pkmn.moves.find { |x| x && x.name.to_s == rows[m[:index]][0] }
        words = (mv.description.to_s rescue words) if mv
      end
      P.small(top, DX + 8, GY + FOOT_Y + 6, DW - 16, 16, small_wrap(top, words.to_s, DW - 16).first.to_s, c[:dim], 2)
    end

    # one option: a field move in blue with its type's chip, an arrow on
    # one that opens more; a long label steps down to the small font
    def cmd_row(b, c, x, y, w, row, on)
      label, kind, type = row
      Reloaded::Dialogs.send(:cursor_row, b, c, x - 4, y, x + w + 4, y + MENU_ROW - 1) if on
      tx = x + 4
      if kind == :field
        b.fill_rect(tx, y + 4, 4, 10, rgb(Reloaded::PartyScreen.type_rgb(type)))
        tx += 9
      end
      room = w - (tx - x) - (kind == :sub ? 12 : 2)
      font = P.width(PF::TEXT, label) > room ? PF::TINY : PF::TEXT
      P.text(b, tx, y + (font == PF::TINY ? 4 : 1), room, 16, PF.fit(font, label, room), kind == :field ? c[:blue] : c[:txt], font)
      P.ui.tri(b, x + w - 8, y + 5, :r, c[:dim], 4) if kind == :sub
    end

    # The message bar along the bottom (Message Bar, his pick)
    def paint_message(over, c)
      y0 = H - P::HINT_H - 52
      y1 = H - P::HINT_H - 8
      chamfer_grad(over, 8, y0, W - 8, y1, 12, mix(c[:panel], c[:selb], 0.22), c[:panel], c[:selb])
      over.fill_rect(20, y0 + 1, W - 40, 1, mix(c[:selb], WHITE, 0.4))
      lines = @kr_message
      lines.each_with_index do |ln, j|
        ly = lines.length == 1 ? y0 + 13 : y0 + 4 + j * 18
        P.text(over, 22, ly, W - 70, 18, ln, c[:txt], PF::TEXT)
      end
      P.ui.tri(over, W - 30, y0 + 19, :d, c[:selb], 5)
    end
  end
end
