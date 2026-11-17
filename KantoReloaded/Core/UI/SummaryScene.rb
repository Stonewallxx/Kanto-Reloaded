# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Reloaded Summary's screen
#==============================================================================
# His picks (2026-11-16, sheets sum-skills and sum-pages): the Skills page
# Design 1 (Rebuilt, named STATS) and the other pages Built as Drawn, on the
# plate frame. The header: a Poké Ball, the name, the tabs (INFO, STATS,
# ABILITIES with KIF: Elite Redux's Innates On, MOVES, POKÉDEX). The left
# column on every page: the Pokémon's plate in its first type's colour (its
# name, level, gender and shiny marks, types, picture, the red line, then
# Additional: Hidden Power, Friendship, Nature and what it changes).
#
# Buttons: Left / Right the pages (Right from MOVES opens the Pokédex
# entry), Up / Down another Pokémon (on MOVES and ABILITIES: the rows), A
# the game's Options (INFO, STATS: give an item, a hat, the Pokédex, Mark),
# spends KIF's EV points on STATS while it has some, picks and swaps moves
# on MOVES, changes an ability on ABILITIES (KIF-ER's own); Action plays the
# cry, or opens Double Abilities' Abilities Card on STATS; B closes. The
# mouse: a tab, a row or a hint clicked; a right click backs out.
#
# What isn't the player's own (another trainer's team, a partner's in
# co-op) is view-only: no Options, swapping or changing.
#==============================================================================

return unless defined?(Reloaded::Frame) && defined?(::KIF::PixelFont) && defined?(Reloaded::PartyPaint)

module Reloaded
  module SummaryScene
    include Reloaded::Frame

    PF = ::KIF::PixelFont
    PP = Reloaded::PartyPaint
    SU = Reloaded::Summary
    BOTTOM = H - P::HINT_H - 6
    LCX0 = 6                          # the left column's plate
    LCX1 = 168
    RX0 = 174                         # the right side
    RX1 = W - 6
    TOP = 36
    LINE_Y = TOP + 150                # the plate's red line
    PIC_CX = (LCX0 + LCX1) / 2
    PIC_CY = 146
    PIC_BOX = 96
    STRIP_Y = BOTTOM - 40             # the text along the bottom
    MID = (RX0 + RX1) / 2
    GHOST = Color.new(180, 120, 240)
    GOLD = Color.new(240, 200, 80)
    LILAC = [170, 140, 240].freeze
    EGG_RGB = [150, 200, 120].freeze
    TABS = [[:info, "INFO"], [:stats, "STATS"], [:abilities, "ABILITIES"], [:moves, "MOVES"], [:dex, "POKÉDEX"]].freeze
    PAGE_NO = { :info => 1, :abilities => 2, :stats => 3, :moves => 4 }.freeze   # PIF's @page for each
    CATEGORY = [["PHYSICAL", [240, 130, 90]], ["SPECIAL", [170, 140, 240]], ["STATUS", [160, 170, 185]]].freeze
    SHAPES = ["Circle", "Triangle", "Square", "Heart", "Star", "Diamond"].freeze
    MARK_SHEET = "Graphics/Pictures/Storage/markings"
    # What each of the game's Options does (by its words, lowercase)
    OPTIONS = { :give_item => "Give it an item from the Bag.", :take_item => "Put its held item back in the Bag.",
                :hat => "Put a hat on it, or take one off.", :view_pokedex => "Its Pokédex entry.",
                :mark => "Mark it with shapes, for sorting and searching in the PC.", :cancel => "Back to the Summary." }.freeze

    #--------------------------------------------------------------------------
    # Start and end (the game's innermost methods: Summary.scene_class)
    #--------------------------------------------------------------------------
    def kr_start_scene(party, partyindex, inbattle = false, is_player = true)
      @party = party
      @partyindex = partyindex
      @inbattle = inbattle
      @is_player = is_player
      @kr_own = SU.own?(party, is_player)
      @kr_tab = :info
      @page = 1
      kr_open(@party[@partyindex])
      pbFadeInAndShow(kr_fade_sprites) { pbUpdate }
    end

    # Learning a move (move_to_learn) or choosing one (nil): the Moves page,
    # the new one fifth
    def kr_start_forget(party, partyindex, move_to_learn)
      @party = party
      @partyindex = partyindex
      @inbattle = false
      @is_player = true
      @kr_own = true
      @kr_tab = :moves
      @page = 4
      @kr_learning = move_to_learn ? ::Pokemon::Move.new(move_to_learn) : nil
      @kr_choosing = true
      kr_open(@party[@partyindex])
      @kr_move = @kr_learning ? ::Pokemon::MAX_MOVES : 0
      kr_refresh
      pbFadeInAndShow(kr_fade_sprites) { pbUpdate }
    end

    def kr_end_scene
      pbFadeOutAndHide(kr_fade_sprites) { pbUpdate } if @sprite && !@sprite.disposed?
      kr_dispose
    end

    def kr_open(pkmn)
      frame_init
      @text_color_base = defined?(isDarkMode) && isDarkMode ? pbColor(:LIGHT_TEXT_MAIN_COLOR) : Color.new(64, 64, 64) rescue Color.new(64, 64, 64)
      @text_color_shadow = defined?(isDarkMode) && isDarkMode ? pbColor(:LIGHT_TEXT_SHADOW_COLOR) : Color.new(176, 176, 176) rescue Color.new(176, 176, 176)
      @kr_pics = {}
      @kr_move = 0
      @kr_swap = nil
      @kr_row = 0
      open_sprites
      @kr_pic = ::PokemonSprite.new(@viewport)
      @kr_pic.setOffset(::PictureOrigin::Center) if defined?(::PictureOrigin) && @kr_pic.respond_to?(:setOffset)
      @kr_pic.z = 2
      @sprites = { "pokemon" => @kr_pic }
      kr_set_pokemon(pkmn)
      kr_refresh
    end

    def kr_dispose
      [@kr_pic, @kr_ghost].each { |s| s.dispose if s && !s.disposed? }
      @kr_pic = @kr_ghost = nil
      kr_pif_sprites_dispose
      (@kr_pics || {}).each_value { |bm| bm.dispose if bm && !bm.disposed? }
      @kr_pics = {}
      dispose_sprites
      @sprites = {}
    end

    # Every sprite, for PIF's fades
    def kr_fade_sprites
      h = {}
      (sprites + [@kr_pic, @kr_ghost]).compact.each_with_index { |s, i| h["kr#{i}"] = s unless s.disposed? }
      return h
    end

    def pbEndScene
      return super if @kr_vanilla
      kr_end_scene
    end

    #--------------------------------------------------------------------------
    # The Pokémon on the page
    #--------------------------------------------------------------------------
    def kr_set_pokemon(pkmn)
      @pokemon = pkmn
      @kr_look = SU.possessed(pkmn)
      @kr_move = 0 unless @kr_choosing
      @kr_swap = nil
      @kr_row = 0
      @kr_tab = :info if pkmn.egg?
      @page = PAGE_NO[@kr_tab] || 1
      shown = @kr_look ? @kr_look[0] : pkmn
      if @kr_pic && !@kr_pic.disposed?
        @kr_pic.setPokemonBitmap(shown)
        fit_picture(pkmn.egg?)
      end
      kr_ghost_icon
    end

    # The picture fitted to its box (an Egg's a little smaller)
    def fit_picture(egg)
      bm = @kr_pic.bitmap
      return unless bm
      r = @kr_pic.src_rect
      f = [r ? r.width : bm.width, r ? r.height : bm.height, 1].max
      room = PIC_BOX
      if egg && defined?(Reloaded::PartyIcons) && (!r || (r.x == 0 && r.y == 0))
        art = Reloaded::PartyIcons.art_rect(bm, f)
        f = [art.width, art.height, 1].max
        room = 64
      end
      @kr_pic.zoom_x = @kr_pic.zoom_y = [room / f.to_f, 2.0].min
      @kr_pic.x = PIC_CX
      @kr_pic.y = egg ? 130 : PIC_CY
    end

    # Ghostly Possession: the Ghost small in the picture's top right
    def kr_ghost_icon
      @kr_ghost.dispose if @kr_ghost && !@kr_ghost.disposed?
      @kr_ghost = nil
      return unless @kr_look
      ghost = SU.ghost_of(@pokemon)
      return unless ghost && defined?(Reloaded::PartyIcons)
      @kr_ghost = Reloaded::PartyIcons.icon(ghost, @viewport, 3)
      return unless @kr_ghost
      Reloaded::PartyIcons.place(@kr_ghost, LCX1 - 24, 118)
      @kr_ghost.zoom_x = @kr_ghost.zoom_y = @kr_ghost.zoom_x * 0.55
    end

    def pbChangePokemon
      return super if @kr_vanilla
      kr_set_pokemon(@party[@partyindex])
      pbSEStop if defined?(pbSEStop)
      @pokemon.play_cry if @pokemon.respond_to?(:play_cry)
    end

    def pbUpdate
      return super if @kr_vanilla
      update_frame if @sprite && !@sprite.disposed?
      @kr_pic.update if @kr_pic && !@kr_pic.disposed? && @kr_pic.respond_to?(:update)
      @kr_ghost.update if @kr_ghost && !@kr_ghost.disposed? && @kr_ghost.respond_to?(:update)
    end

    # The game's code asks for a page (KIF's EV points, a refresh): this one
    def drawPage(page)
      return super if @kr_vanilla
      kr_refresh
    end

    def drawSelectedMove(*args)
      return super if @kr_vanilla
      kr_refresh
    end

    #--------------------------------------------------------------------------
    # The pages
    #--------------------------------------------------------------------------
    def kifer?
      return respond_to?(:kifer_tab?) && kifer_tab? && respond_to?(:kifer_rows) ? true : false
    rescue StandardError
      return false
    end

    def tabs
      list = [:info, :stats]
      list << :abilities if kifer?
      return list + [:moves]
    end

    def dex_ok?
      return @kr_own && !@kr_choosing && $Trainer && $Trainer.respond_to?(:has_pokedex) && $Trainer.has_pokedex ? true : false
    end

    def shown
      return @kr_look ? @kr_look[0] : @pokemon
    end

    def raised?(i)
      return @kr_look && Array(@kr_look[1]).include?(i)
    end

    #--------------------------------------------------------------------------
    # Input
    #--------------------------------------------------------------------------
    def pbScene
      return super if @kr_vanilla
      @pokemon.play_cry if @pokemon.respond_to?(:play_cry)
      loop do
        Graphics.update
        Input.update
        pbUpdate
        break if kr_input == :close
      end
      return @partyindex
    rescue Exception => e
      raise if Reloaded::Hooks.passthrough?(e)
      SU.failed = true
      Reloaded::Log.exception("The Summary failed; the game's own from now on this session", e, :summary)
      return @partyindex
    end

    def hint_pairs
      return @kr_popup_hints if @kr_popup_hints
      own = @kr_own && !@inbattle
      if @kr_choosing
        new_one = @kr_learning && @kr_move == ::Pokemon::MAX_MOVES
        use = @kr_learning ? (new_one ? _INTL("Don't Learn") : _INTL("Forget")) : _INTL("Choose")
        return [[:ud, _INTL("Moves")], [button(:C), use, :hint_use], [button(:B), _INTL("Cancel"), :hint_back]]
      end
      if @kr_ev
        return [[:ud, _INTL("Stat")], [:lr, _INTL("Take / Give")], [button(:A), _INTL("Reset"), :hint_action],
                [button(:C), _INTL("Done"), :hint_use]]
      end
      out = []
      out << [:lr, _INTL("Pages")] unless @pokemon.egg?
      case @kr_tab
      when :moves
        out << [:ud, _INTL("Moves")]
        if @kr_own && !shadow?
          out << [button(:C), @kr_swap ? _INTL("Swap Here") : _INTL("Swap"), :hint_use]
        end
        out << [button(:B), @kr_swap ? _INTL("Cancel") : _INTL("Back"), :hint_back]
        return out
      when :abilities
        out << [:ud, _INTL("Choose")]
        out << [button(:C), _INTL("Change"), :hint_use] if own && ability_changeable?
        out << [button(:B), _INTL("Back"), :hint_back]
        return out
      end
      out << [:ud, _INTL("Pokémon")] if @party.length > 1
      if @kr_tab == :stats && SU.double_pair(@pokemon) && defined?(Reloaded::DoubleAbilities::Fusing)
        out << [button(:A), _INTL("Abilities"), :hint_action]
      end
      if own
        out << [button(:C), ev_points? && @kr_tab == :stats ? _INTL("Spend EVs") : _INTL("Options"), :hint_use]
      end
      out << [button(:B), _INTL("Back"), :hint_back]
      return out
    end

    def hint_use; return :use; end
    def hint_back; return :back; end
    def hint_action; return :action; end

    def shadow?
      return @pokemon.respond_to?(:shadowPokemon?) && @pokemon.shadowPokemon? ? true : false
    end

    def ev_points?
      return @kr_own && !@inbattle && respond_to?(:kif_eva_here?) && kif_eva_here? && @pokemon.respond_to?(:kif_ev_pool) &&
             @pokemon.kif_ev_pool.to_i > 0 ? true : false
    rescue StandardError
      return false
    end

    # One frame's input: :close to leave
    def kr_input
      act = nil
      pt = Reloaded::Pointer
      pointer_hover
      if pt.moved? && @kr_tab == :moves && (i = pt.hit(@kr_move_hits || [])) && i != @kr_move
        move_to(i)
      end
      if pt.left?
        handled, result = hint_click
        if handled
          act = result
        elsif (t = pt.hit(@kr_tab_hits || []))
          return go_tab(t)
        elsif @kr_tab == :moves && (i = pt.hit(@kr_move_hits || []))
          i == @kr_move ? act = :use : move_to(i)
        elsif @kr_tab == :abilities && (i = pt.hit(@kr_row_hits || []))
          i == @kr_row ? act = :use : row_to(i)
        end
      elsif pt.right?
        act = :back
      elsif (w = pt.wheel) != 0 && !@kr_choosing
        act = w > 0 ? :up : :down
      end
      act ||= if Input.trigger?(Input::BACK) then :back
              elsif Input.trigger?(Input::USE) then :use
              elsif Input.trigger?(Input::ACTION) then :action
              elsif Input.repeat?(Input::UP) then :up
              elsif Input.repeat?(Input::DOWN) then :down
              elsif Input.trigger?(Input::LEFT) then :left
              elsif Input.trigger?(Input::RIGHT) then :right
              end
      return nil unless act
      return choose_input(act) if @kr_choosing
      case act
      when :back
        if @kr_swap
          @kr_swap = nil
          pbPlayCancelSE
          kr_refresh
          return nil
        end
        pbPlayCloseMenuSE
        return :close
      when :use then use_button
      when :action then action_button
      when :up, :down then up_down(act == :up ? -1 : 1)
      when :left, :right then step_page(act == :left ? -1 : 1)
      end
      return nil
    end

    def use_button
      case @kr_tab
      when :moves
        return pbPlayBuzzerSE unless @kr_own && !shadow? && @pokemon.moves[@kr_move]
        if @kr_swap.nil?
          pbPlayDecisionSE
          @kr_swap = @kr_move
        elsif @kr_swap == @kr_move
          pbPlayCancelSE
          @kr_swap = nil
        else
          mv = @pokemon.moves
          mv[@kr_swap], mv[@kr_move] = mv[@kr_move], mv[@kr_swap]
          @kr_swap = nil
          pbSEPlay("GUI party switch")
          @kr_look = SU.possessed(@pokemon)
        end
        kr_refresh
      when :abilities
        return pbPlayBuzzerSE unless @kr_own && !@inbattle && ability_changeable?
        change_ability
      else
        return pbPlayBuzzerSE unless @kr_own && !@inbattle
        pbPlayDecisionSE
        pbOptions
        @pokemon = @party[@partyindex]
        kr_set_pokemon(@pokemon) unless @kr_pic.nil? || @kr_pic.disposed?
        kr_refresh
      end
    end

    # Action: Double Abilities' Abilities Card on STATS, else the cry (PIF's)
    def action_button
      if @kr_tab == :stats && SU.double_pair(@pokemon) && defined?(Reloaded::DoubleAbilities::Fusing)
        pbPlayDecisionSE
        Reloaded::DoubleAbilities::Fusing.abilities_card(@pokemon)
        return
      end
      pbSEStop if defined?(pbSEStop)
      @pokemon.play_cry if @pokemon.respond_to?(:play_cry)
    end

    def up_down(d)
      case @kr_tab
      when :moves
        n = [@pokemon.numMoves, 1].max
        move_to((@kr_move + d) % n)
      when :abilities
        n = [kifer_list.length, 1].max
        row_to((@kr_row + d) % n)
      else
        other_pokemon(d)
      end
    end

    def move_to(i)
      return if i == @kr_move
      @kr_move = i
      pbPlayCursorSE
      kr_refresh
    end

    def row_to(i)
      return if i == @kr_row
      @kr_row = i
      pbPlayCursorSE
      kr_refresh
    end

    # PIF's: an Egg only on INFO
    def other_pokemon(d)
      i = @partyindex
      loop do
        i += d
        return if i < 0 || i >= @party.length
        pk = @party[i]
        next unless pk
        break if @kr_tab == :info || !pk.egg?
      end
      @partyindex = i
      pbChangePokemon
      kr_refresh
    end

    def step_page(d)
      return if @pokemon.egg?
      list = tabs
      i = list.index(@kr_tab) || 0
      if d > 0 && i == list.length - 1
        return open_dex
      end
      return if (i + d) < 0
      go_tab(list[i + d])
    end

    def go_tab(t)
      return if @pokemon.egg?
      return open_dex if t == :dex
      return if t == @kr_tab
      @kr_tab = t
      @page = PAGE_NO[t] || 1
      @kr_swap = nil
      @kr_row = 0
      pbSEPlay("GUI summary change page")
      kr_refresh
    end

    # PIF's Pokédex page: the entry, then back to MOVES
    def open_dex
      return pbPlayBuzzerSE unless dex_ok?
      pbSEPlay("GUI summary change page")
      $Trainer.pokedex.register_last_seen(@pokemon) if $Trainer.pokedex.respond_to?(:register_last_seen)
      pbFadeOutIn do
        scene = ::PokemonPokedexInfo_Scene.new
        ::PokemonPokedexInfoScreen.new(scene).pbStartSceneSingle(@pokemon)
      end
      pbChangePokemon
      kr_refresh
    end

    #--------------------------------------------------------------------------
    # Learning or choosing a move
    #--------------------------------------------------------------------------
    def pbChooseMoveToForget(move_to_learn)
      return super if @kr_vanilla
      loop do
        Graphics.update
        Input.update
        pbUpdate
        r = kr_input
        next unless r.is_a?(Array)
        return r[1]
      end
    end

    def choose_input(act)
      max = @kr_learning ? ::Pokemon::MAX_MOVES : [@pokemon.numMoves - 1, 0].max
      case act
      when :back
        pbPlayCloseMenuSE if @kr_learning
        return [:done, -1]
      when :use
        pbPlayDecisionSE
        return [:done, @kr_move == ::Pokemon::MAX_MOVES ? -1 : @kr_move]
      when :up, :down
        rows = (0...@pokemon.numMoves).to_a
        rows << ::Pokemon::MAX_MOVES if @kr_learning
        i = rows.index(@kr_move) || 0
        @kr_move = rows[(i + (act == :up ? -1 : 1)) % rows.length]
        @kr_move = [@kr_move, max].min
        pbPlayCursorSE
        kr_refresh
      end
      return nil
    end

    #--------------------------------------------------------------------------
    # The game's popups, in Kanto Reloaded's
    #--------------------------------------------------------------------------
    # A message in the bar along the bottom (the Party Screen's, his pick)
    def pbDisplay(text)
      return super if @kr_vanilla
      pbPlayDecisionSE
      message_pages(plain(text)).each do |lines|
        @kr_message = lines
        kr_refresh
        loop do
          Graphics.update
          Input.update
          pbUpdate
          pt = Reloaded::Pointer
          break if Input.trigger?(Input::USE) || Input.trigger?(Input::BACK) || pt.left? || pt.right?
        end
      end
      @kr_message = nil
      kr_refresh
    end

    def pbConfirm(text)
      return super if @kr_vanilla
      ok = Reloaded::Dialogs.confirm(self, @pokemon ? @pokemon.name : _INTL("Summary"), plain(text), _INTL("Yes"), _INTL("No"), true)
      kr_refresh
      return ok
    end

    # The game's Options and other lists: Kanto Reloaded's menu, each row
    # explained; Back gives -1, as the game's does
    def pbShowCommands(commands, index = 0)
      return super if @kr_vanilla
      labels = commands.map { |l| Reloaded::PartyScreen.respond_to?(:title_case) ? Reloaded::PartyScreen.title_case(plain(l)) : plain(l) }
      words = commands.map { |l| (d = OPTIONS[plain(l).downcase.tr("é", "e").gsub(/[^a-z]+/, "_").to_sym]) ? _INTL(d) : "" }
      i = Reloaded::Dialogs.menu(self, @pokemon ? @pokemon.name : _INTL("Summary"), labels, words, index.to_i)
      kr_refresh
      return i.nil? ? -1 : i
    end

    def plain(text)
      t = text.to_s.gsub("\1", "").gsub(/<[^>]*>/, "").gsub(/\\[a-zA-Z]+\[[^\]]*\]/, "").gsub(/\\[nrl]/, " ").gsub(/\\[a-zA-Z.!|^]/, "")
      return t.gsub(/\s+/, " ").strip
    end

    def message_pages(text)
      room = W - 70
      lines = [""]
      text.split(" ").each do |word|
        try = lines.last.empty? ? word : "#{lines.last} #{word}"
        if P.width(PF::TEXT, try) <= room then lines[-1] = try else lines << word end
      end
      return lines.each_slice(2).to_a
    end

    def with_popup_hints(pairs)
      before = @kr_popup_hints
      @kr_popup_hints = pairs
      kr_refresh
      return yield
    ensure
      @kr_popup_hints = before
    end

    # Mark (the Reloaded PC's Shape Row, his pick): the six shapes in a row,
    # lit when on; Left / Right choose, A marks or unmarks, B is done
    def pbMarking(pokemon)
      return super if @kr_vanilla
      bits = pokemon.markings.to_i
      before = bits
      k = 0
      with_popup_hints([[:lr, _INTL("Choose")], [button(:C), _INTL("Mark")], [button(:B), _INTL("Done")]]) do
        redraw = true
        loop do
          draw_mark(pokemon, bits, k) if redraw
          redraw = false
          Graphics.update
          Input.update
          pbUpdate
          pt = Reloaded::Pointer
          if pt.moved? && (i = pt.hit(@kr_mark_hits || [])) && i != k
            k = i
            pbPlayCursorSE
            redraw = true
          end
          if pt.left? && (i = pt.hit(@kr_mark_hits || []))
            k = i
            bits ^= (1 << k)
            pbPlayDecisionSE
            redraw = true
          elsif pt.right? || Input.trigger?(Input::BACK)
            pbPlayCancelSE
            break
          elsif Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)
            k = (k + (Input.repeat?(Input::LEFT) ? -1 : 1)) % SHAPES.length
            pbPlayCursorSE
            redraw = true
          elsif Input.trigger?(Input::USE)
            bits ^= (1 << k)
            pbPlayDecisionSE
            redraw = true
          end
        end
      end
      pokemon.markings = bits
      overlay.clear
      kr_refresh
      return bits != before
    end

    def draw_mark(pk, bits, k)
      b = overlay
      c = palette
      dg = Reloaded::Dialogs
      b.clear
      dg.send(:dim, b)
      w = 300
      h = 40 + 56 + 30 + 26
      x = (W - w) / 2
      y = (H - h) / 2
      dg.send(:panel, b, c, x, y, w, h)
      dg.send(:title_bar, b, c, x, y, w, _INTL("Mark {1}", pk.name))
      step = 44
      x0 = x + (w - step * SHAPES.length) / 2
      @kr_mark_hits = []
      SHAPES.each_index do |i|
        sx = x0 + i * step + 6
        sy = y + 50
        @kr_mark_hits << [i, sx - 6, sy - 6, sx + 37, sy + 37]
        dg.send(:cursor_row, b, c, sx - 6, sy - 6, sx + 37, sy + 37) if i == k
        on = bits & (1 << i) != 0
        mark(b, i, sx, sy, 32, on ? c[:selb] : mix(c[:line], c[:panel2], 0.45))
      end
      state = bits & (1 << k) != 0 ? _INTL("On") : _INTL("Off")
      P.text(b, x, y + 96, w, 18, _INTL("{1}: {2}", _INTL(SHAPES[k]), state), c[:txt], PF::TEXT, 2)
      b.fill_rect(x + 10, y + h - 30, w - 20, 1, c[:line])
      P.text(b, x + 14, y + h - 26, w - 28, 18, _INTL("Also shown in the PC."), c[:dim])
    end

    def mark_runs(k, size)
      @kr_mark_runs ||= {}
      return @kr_mark_runs[[k, size]] if @kr_mark_runs.key?([k, size])
      sheet = pic(MARK_SHEET)
      runs = []
      if sheet
        size.times do |ty|
          start = nil
          (size + 1).times do |tx|
            on = tx < size && sheet.get_pixel(k * 16 + tx * 16 / size, 16 + ty * 16 / size).alpha > 0
            if on && start.nil?
              start = tx
            elsif !on && start
              runs << [ty, start, tx - start]
              start = nil
            end
          end
        end
      end
      return @kr_mark_runs[[k, size]] = runs
    end

    def mark(b, k, x, y, size, col)
      mark_runs(k, size).each { |ty, tx, len| b.fill_rect(x + tx, y + ty, len, 1, col) }
    end

    #--------------------------------------------------------------------------
    # KIF's EV points (F-BATTLE-09): spent on STATS (its Options hook calls
    # this): a stat's row lit, Left / Right take or give, X puts them all
    # back, A or B done
    #--------------------------------------------------------------------------
    def kif_eva_allocate
      return super if @kr_vanilla
      ea = ::KIF::EVAlloc
      @kr_ev = 0
      kr_refresh
      loop do
        Graphics.update
        Input.update
        pbUpdate
        pt = Reloaded::Pointer
        if pt.moved? && (i = pt.hit(@kr_stat_hits || [])) && i != @kr_ev
          @kr_ev = i
          pbPlayCursorSE
          kr_refresh
        end
        stat = ea::STATS[@kr_ev]
        if pt.left? && (i = pt.hit(@kr_stat_hits || []))
          @kr_ev = i
          kif_eva_sound(pt.x >= (RX0 + RX1) / 2 ? ea.give(@pokemon, ea::STATS[i]) : ea.take(@pokemon, ea::STATS[i]))
          kr_refresh
        elsif Input.trigger?(Input::USE) || Input.trigger?(Input::BACK) || pt.right?
          pbPlayCloseMenuSE
          break
        elsif Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN)
          @kr_ev = (@kr_ev + (Input.repeat?(Input::UP) ? -1 : 1)) % 6
          pbPlayCursorSE
          kr_refresh
        elsif Input.repeat?(Input::RIGHT)
          kif_eva_sound(ea.give(@pokemon, stat))
          kr_refresh
        elsif Input.repeat?(Input::LEFT)
          kif_eva_sound(ea.take(@pokemon, stat))
          kr_refresh
        elsif Input.trigger?(Input::ACTION)
          if ea.ev_total(@pokemon) > 0 && pbConfirm(_INTL("Put all of {1}'s EVs back into points?", @pokemon.name))
            kif_eva_sound(nil) unless ea.reset(@pokemon)
          end
          kr_refresh
        end
      end
    ensure
      @kr_ev = nil
      kr_refresh unless @kr_vanilla || @sprite.nil? || @sprite.disposed?
    end

    def kif_eva_sound(n)
      return super if @kr_vanilla
      if n.nil?
        pbPlayBuzzerSE
        pbDisplay(_INTL("{1} would faint without those HP EVs.", @pokemon.name))
      else
        n > 0 ? pbPlayCursorSE : pbPlayBuzzerSE
      end
    end

    #--------------------------------------------------------------------------
    # KIF: Elite Redux's abilities (its own code changes them)
    #--------------------------------------------------------------------------
    def kifer_list
      return kifer? ? (kifer_rows rescue []) : []
    end

    def ability_changeable?
      row = kifer_list[@kr_row]
      return false unless row
      return true if row[0] == :ability || row[0] == :ability2
      return row[0] == :innate && respond_to?(:kifer_innates_pickable?) && kifer_innates_pickable?
    rescue StandardError
      return false
    end

    def change_ability
      kind = kifer_list[@kr_row][0]
      pbPlayDecisionSE
      if kind == :innate
        kr_with_pif_sprites { kifer_pick_innates }
      else
        kifer_pick_choice(kind == :ability2 ? 2 : 1)
      end
      @pokemon.calc_stats if @pokemon.respond_to?(:calc_stats)
      kr_refresh
    end

    # KIF-ER's innate picker draws on PIF's own background and overlay: made
    # for it, over this screen, and put away after
    def kr_with_pif_sprites
      bg = ::IconSprite.new(0, 0, @viewport)
      bg.z = 10
      ov = ::BitmapSprite.new(W, H, @viewport)
      ov.z = 11
      pbSetSystemFont(ov.bitmap) if defined?(pbSetSystemFont)
      @sprites["background"] = bg
      @sprites["overlay"] = ov
      @overlay_sprite.z = 12
      @kifer_bg_hooked = false
      return yield
    ensure
      @overlay_sprite.z = 3 if @overlay_sprite && !@overlay_sprite.disposed?
      kr_pif_sprites_dispose
    end

    def kr_pif_sprites_dispose
      return unless @sprites
      %w[background overlay].each do |k|
        s = @sprites.delete(k)
        next unless s && !s.disposed?
        s.bitmap.dispose if k == "overlay" && s.bitmap && !s.bitmap.disposed?
        s.dispose
      end
    end

    #--------------------------------------------------------------------------
    # Drawing
    #--------------------------------------------------------------------------
    def pic(path)
      @kr_pics ||= {}
      return @kr_pics[path] if @kr_pics.key?(path)
      resolved = defined?(pbResolveBitmap) ? (pbResolveBitmap(path) || path) : path
      @kr_pics[path] = (Bitmap.new(resolved) rescue nil)
    end

    def mix(a, b, t)
      return Reloaded::Palette.mix(a, b, t)
    end

    def tone(c, key)
      return PP.ink(c, Reloaded::Palette::TONES[key])
    end

    def kr_refresh
      return unless @sprite && !@sprite.disposed?
      draw
    end

    def draw
      c = palette
      base = @sprite.bitmap
      top = @top_sprite.bitmap
      base.clear
      top.clear
      @cursor_rect = nil
      @kr_move_hits = []
      @kr_row_hits = []
      @kr_stat_hits = []
      PP.paint_background(base, c)
      header(base, top, c)
      if @pokemon.egg?
        egg_page(base, top, c)
      else
        case @kr_tab
        when :stats then stats_page(base, top, c)
        when :abilities then abilities_page(base, top, c)
        when :moves then moves_page(base, top, c)
        else info_page(base, top, c)
        end
      end
      paint_message(@overlay_sprite.bitmap, c) if @kr_message
      @overlay_sprite.bitmap.clear unless @kr_message || @kr_popup_hints
      paint_hints(base, c)
      place_cursor
    end

    def header(base, top, c)
      P.poke_ball(top, 10, 9, 12)
      name = @pokemon.egg? ? _INTL("Egg") : @pokemon.name.to_s
      list = @pokemon.egg? || @kr_choosing ? [] : tabs + [:dex]
      x = list.include?(:abilities) ? 150 : 176
      P.text(top, 28, 5, x - 34, 22, PF.fit(PF::ROW, name, x - 34), @kr_look ? GHOST : c[:strong], PF::ROW)
      @kr_tab_hits = []
      list.each do |t|
        l = TABS.assoc(t)[1]
        w = P.width(PF::TINY, l) + 16
        on = t == @kr_tab
        off = t == :dex && !dex_ok?
        PP.chamfer_grad(base, x, 6, x + w, 24, 5, on ? mix(c[:panel2], c[:selb], 0.62) : c[:panel2],
                        on ? mix(c[:panel2], c[:selb], 0.4) : c[:panel2], on ? c[:selb] : c[:line])
        P.text(top, x, 8, w, 14, l, on ? c[:strong] : (off ? mix(c[:dim], c[:panel2], 0.5) : c[:dim]), PF::TINY, 2)
        @kr_tab_hits << [t, x, 6, x + w, 24]
        x += w + 3
      end
    end

    def box(base, c, x0, y0, x1, y1)
      PP.chamfer_grad(base, x0, y0, x1, y1, 8, c[:panel2], mix(c[:panel2], c[:dark], 0.3), c[:line])
    end

    # The plate's lit slash and red line (the Weather Forecast's plate)
    def plate(base, c, color, x0, y0, x1, y1, line_y, cut = 16)
      topc = mix(c[:panel], color, 0.4)
      bottom = mix(c[:panel], c[:dark], 0.4)
      PP.chamfer_grad(base, x0, y0, x1, y1, cut, topc, bottom, mix(c[:line], color, 0.5))
      from = x1 - 48
      to = x0 + 24
      (y0 + 1...y1 - 1).each do |y|
        t = (y - y0).to_f / (y1 - y0)
        left = x0 + 1 + [cut - (y - y0), 0].max
        right = x1 - 1 - [cut - (y1 - 1 - y), 0].max
        mid = from + (to - from) * t
        k = y < line_y ? 0.4 : 0.22 - 0.18 * (y - line_y).to_f / [y1 - line_y, 1].max
        tint = mix(mix(topc, bottom, t), color, k)
        [[0, 56], [40, 8]].each do |off, bw|
          a = [(mid + off - bw / 2.0).round, left].max
          e = [(mid + off + bw / 2.0).round, right].min
          base.fill_rect(a, y, e - a, 1, tint) if e > a
        end
      end
      base.fill_rect(x0 + 8, line_y, x1 - x0 - 16, 2, PP::POKE_RED)
    end

    def row(top, c, x, y, w, label, value, color)
      P.small(top, x, y, w, 18, label, c[:dim])
      P.small(top, x, y, w, 18, value, color, 1)
    end

    def small_type(b, type, x, y)
      sheet = pic(PP::TYPES_SMALL)
      b.blt(x, y, sheet, Rect.new(0, PP.type_row(type) * 16, 16, 16)) if sheet && type
    end

    def type_badge(top, type, x, y, w = 50, h = 22)
      sheet = PP.type_sheet
      return unless sheet && type
      top.stretch_blt(Rect.new(x, y, w, h), sheet, Rect.new(0, PP.type_row(type) * 28, 64, 28))
    end

    def types_of(pk)
      list = pk.respond_to?(:types) ? Array(pk.types) : [pk.type1, pk.type2]
      return list.compact.uniq
    rescue StandardError
      return [(pk.type1 rescue :NORMAL)]
    end

    def type_colour(type)
      rgb = Reloaded::PartyScreen.respond_to?(:type_rgb) ? Reloaded::PartyScreen.type_rgb(type) : nil
      rgb ||= (Reloaded::PartyScreen::TYPE_RGB[type] rescue nil) || [150, 150, 160]
      return Color.new(*rgb)
    end

    #---------------------------------------------------------------- the left column
    def left_column(base, top, c)
      pk = @pokemon
      look = shown
      types = types_of(look)
      col = @kr_look ? GHOST : type_colour(types[0])
      plate(base, c, col, LCX0, TOP, LCX1, BOTTOM - 46, LINE_Y)
      pill = if @kr_look then [_INTL("POSSESSED"), GHOST]
             elsif SU.alpha?(pk) then [_INTL("ALPHA"), tone(c, :red)]
             end
      room = 150
      if pill
        pw = P.width(PF::TINY, pill[0]) + 12
        room = LCX1 - 16 - pw - (LCX0 + 10)
        P.pill(top, LCX1 - 12, 44, pill[0], mix(c[:panel2], pill[1], 0.28), pill[1], true)
      end
      P.text(top, LCX0 + 10, 40, room, 22, PF.fit(PF::ROW, pk.name.to_s, room), @kr_look ? GHOST : c[:strong], PF::ROW)
      lw = level_words(top, c, pk, LCX0 + 10, 62)
      marks(top, c, pk, LCX0 + 10 + lw + 6, 66)
      status(top, c, pk, LCX1 - 10, 63)
      type_badge(top, types[0], LCX0 + 10, 80)
      type_badge(top, types[1], LCX0 + 64, 80) if types[1]
      plate_marks(top, c, pk)
      ::KIF.draw_evolock_icon(top, LCX0 + 12, LINE_Y - 22) if defined?(::KIF) && ::KIF.respond_to?(:draw_evolock_icon) &&
                                                          (pk.kif_evo_locked? rescue false)
      y = TOP + 156
      P.heading(top, LCX0 + 10, LCX1 - 10, y, _INTL("Additional"), c[:head], c[:line])
      w = LCX1 - LCX0 - 20
      hp = SU.hidden_power(pk)
      row(top, c, LCX0 + 10, y + 14, w, _INTL("Hidden Power"), hp ? "" : "-", c[:txt])
      small_type(top, hp[0], LCX1 - 26, y + 15) if hp
      if @kr_look
        ghost = SU.ghost_of(pk)
        row(top, c, LCX0 + 10, y + 32, w, _INTL("Ghost"), ghost ? ghost.speciesName.to_s : "", GHOST)
      else
        row(top, c, LCX0 + 10, y + 32, w, _INTL("Friendship"), pk.happiness.to_i.to_s, tone(c, :pink))
      end
      row(top, c, LCX0 + 10, y + 50, w, _INTL("Nature"), SU.nature_name(pk), c[:txt])
      P.small(top, LCX0 + 10, y + 68, w, 16, SU.nature_words(pk), c[:dim])
    end

    # "Lv 32", a padlock with Quality of Life's level lock; its width
    def level_words(top, c, pk, x, y)
      s = _INTL("Lv {1}", pk.level)
      w = P.small(top, x, y, 80, 16, s, c[:txt])
      w = P.width(PF::TEXT, s) unless w.is_a?(Integer)
      lock = defined?(Reloaded::QualityOfLife::LevelLocks) ? (Reloaded::QualityOfLife::LevelLocks.get(pk) rescue nil) : nil
      if lock
        col = (Reloaded::QualityOfLife::LevelLocks.limit(pk) rescue false) ? c[:gold] : c[:dim]
        padlock(top, x + w + 4, y + 3, col)
        w += 13
      end
      return w
    end

    # Gender (KIF's genderless and pizza too) and the shiny star (KIF's, by
    # the kind of shiny)
    def marks(b, c, pk, x, y)
      w = 0
      if (pk.pizza? rescue false) && defined?(::KIF::Gender::ICON_PIZZA)
        pbDrawImagePositions(b, [[::KIF::Gender::ICON_PIZZA, x - 2, y - 4]]) rescue nil
        w += 14
      elsif (pk.male? rescue false)
        PP.pixels(b, PP::MALE, x, y, c[:blue])
        w += 9
      elsif (pk.female? rescue false)
        PP.pixels(b, PP::FEMALE, x, y, c[:pink])
        w += 8
      elsif (pk.genderless? rescue false) && defined?(::KIF::Gender::ICON_GENDERLESS)
        pbDrawImagePositions(b, [[::KIF::Gender::ICON_GENDERLESS, x - 2, y - 2]]) rescue nil
        w += 12
      end
      return unless (pk.shiny? rescue false)
      return if shiny_star(b, pk, x + w - 2, y - 5)
      PP.pixels(b, PP::STAR, x + w, y, c[:gold])
    end

    def shiny_star(b, pk, x, y)
      return false unless defined?(addShinyStarsToGraphicsArray) && defined?(pbDrawImagePositions)
      pos = []
      addShinyStarsToGraphicsArray(pos, x, y, pk.bodyShiny?, pk.headShiny?, pk.debugShiny?, pk.radarShiny?, 0, 0, 16, 16)
      pbDrawImagePositions(b, pos)
      return true
    rescue StandardError
      return false
    end

    def status(b, c, pk, x, y)
      word, col = if pk.hp <= 0 then [_INTL("FNT"), [240, 100, 90]]
                  elsif PP::STATUS[(pk.status rescue nil)] then PP::STATUS[pk.status]
                  elsif (pk.pokerusStage rescue 0) == 1 then [_INTL("PKRS"), [230, 120, 220]]
                  end
      P.pill(b, x, y, word, *PP.badge(c, col), true) if word
    end

    # The marks that are on, small, just over the red line on the right (the
    # Reloaded PC's plate marks)
    def plate_marks(top, c, pk)
      bits = (pk.markings rescue 0).to_i
      on = (0...SHAPES.length).select { |k| bits & (1 << k) != 0 }
      x = LCX1 - 8 - on.length * 12
      on.each_with_index { |k, j| mark(top, k, x + j * 12 + 2, LINE_Y - 14, 10, c[:selb]) }
    end

    def padlock(b, x, y, col)
      b.fill_rect(x + 2, y, 5, 1, col)
      b.fill_rect(x + 1, y + 1, 1, 4, col)
      b.fill_rect(x + 7, y + 1, 1, 4, col)
      b.fill_rect(x, y + 5, 9, 6, col)
    end

    #---------------------------------------------------------------- the ability's text along the bottom
    def text_strip(base, top, c, line1, line2, colour1 = nil, colour2 = nil)
      box(base, c, LCX0, STRIP_Y, RX1, BOTTOM)
      w = RX1 - LCX0 - 20
      P.small(top, LCX0 + 10, STRIP_Y + 5, w, 16, fit_small(top, line1, w), colour1 || c[:txt]) if line1
      P.small(top, LCX0 + 10, STRIP_Y + 22, w, 16, fit_small(top, line2, w), colour2 || c[:dim]) if line2
    end

    # Words in the TEXT font, as lines that fit w
    def text_lines(str, w)
      lines = [""]
      str.to_s.split(" ").each do |word|
        try = lines.last.empty? ? word : "#{lines.last} #{word}"
        if P.width(PF::TEXT, try) <= w then lines[-1] = try else lines << word end
      end
      return lines
    end

    # A line cut to fit, with "..."
    def fit_small(b, str, w)
      lines = P.small_wrap(b, str.to_s, w)
      return str.to_s if lines.length <= 1
      first = lines[0].to_s
      first = first[0...-1] while !first.empty? && P.small_wrap(b, first + "...", w).length > 1
      return first + "..."
    rescue StandardError
      return str.to_s
    end

    def ability_line(pk)
      id = SU.ability_id(pk)
      return nil unless id
      return _INTL("{1}: {2}", SU.ability_name(id), SU.ability_text(id))
    end

    def hidden_power_line(pk)
      hp = SU.hidden_power(pk)
      return nil unless hp
      name = (::GameData::Type.get(hp[0]).name rescue hp[0].to_s.capitalize)
      return _INTL("Hidden Power: {1}, {2} power.", name, hp[1])
    end

    def standard_strip(base, top, c)
      pk = @pokemon
      if @kr_look && @kr_tab == :stats
        ghost = SU.ghost_of(pk)
        text_strip(base, top, c, _INTL("Possessed by {1}: Its ability and raised stats in ghost purple.", ghost ? ghost.speciesName : _INTL("a Ghost")),
                   nil, GHOST)
      elsif @kr_ev
        n = (pk.kif_ev_pool.to_i rescue 0)
        text_strip(base, top, c, _INTL("EV Points Left: {1}", n), _INTL("Left takes {1} EVs, Right gives {1}.", ::KIF::EVAlloc::STEP),
                   tone(c, :green))
      elsif ev_points? && @kr_tab == :stats
        text_strip(base, top, c, ability_line(pk), _INTL("EV Points to Spend: {1}", pk.kif_ev_pool), nil, tone(c, :green))
      else
        text_strip(base, top, c, ability_line(pk), hidden_power_line(pk))
      end
    end

    #---------------------------------------------------------------- INFO
    def info_page(base, top, c)
      pk = @pokemon
      look = shown
      left_column(base, top, c)
      box(base, c, RX0, TOP, RX1, 146)
      P.heading(top, RX0 + 10, RX1 - 10, 42, _INTL("Info"), c[:head], c[:line])
      fused = look.respond_to?(:isFusion?) && look.isFusion?
      rows = []
      if fused
        head = (::GameData::Species.get(look.species_data.get_head_species).name rescue "?")
        body = (::GameData::Species.get(look.species_data.get_body_species).name rescue "?")
        rows << [_INTL("Fusion"), _INTL("{1} / {2}", head, body), @kr_look ? GHOST : c[:txt]]
      else
        rows << [_INTL("Dex No."), format("%03d", (::GameData::Species.get(look.species).id_number rescue 0)), c[:txt]]
      end
      rows << [_INTL("Species"), look.speciesName.to_s, @kr_look ? GHOST : c[:txt]]
      owner = pk.owner rescue nil
      ot = owner && !owner.name.to_s.empty? ? owner.name.to_s : _INTL("Rental")
      rows << [_INTL("OT"), ot, c[:txt]]
      rows << [_INTL("ID No."), owner ? format("%05d", owner.public_id.to_i) : "-----", c[:txt]]
      item = pk.hasItem? ? (pk.item.name rescue pk.item_id.to_s) : _INTL("None")
      rows << [_INTL("Item"), item, pk.hasItem? ? c[:txt] : c[:dim]]
      rows.each_with_index do |(l, v, col), i|
        y = 56 + i * 17
        P.small(top, RX0 + 10, y, 90, 16, l, c[:dim])
        P.text(top, RX0 + 100, y - 1, RX1 - RX0 - 140, 18, PF.fit(PF::TEXT, v, RX1 - RX0 - 140), col, PF::TEXT)
      end
      item_icon(top, pk.item_id, RX1 - 22, 130, 24) if pk.hasItem?
      exp_box(base, top, c, pk)
      memo_box(base, top, c, pk)
      standard_strip(base, top, c)
    end

    def item_icon(b, item, cx, cy, size)
      path = (::GameData::Item.icon_filename(item) rescue nil) || "Graphics/Items/#{item}"
      bm = pic(path)
      return unless bm
      b.stretch_blt(Rect.new(cx - size / 2, cy - size / 2, size, size), bm, Rect.new(0, 0, bm.width, bm.height))
    end

    def exp_box(base, top, c, pk)
      box(base, c, RX0, 152, RX1, 204)
      w = RX1 - RX0 - 20
      P.small(top, RX0 + 10, 156, 120, 16, _INTL("Exp."), c[:dim])
      P.small(top, RX0 + 10, 156, w, 16, SU.num(pk.exp), c[:txt], 1)
      max = (::GameData::GrowthRate.max_level rescue 100)
      if pk.level >= max
        frac = 1.0
        words = _INTL("Max Level")
      else
        nxt = pk.growth_rate.minimum_exp_for_level(pk.level + 1)
        frac = (pk.exp_fraction rescue 0.0).to_f
        words = _INTL("{1} to Lv {2}", SU.num(nxt - pk.exp), pk.level + 1)
      end
      base.fill_rect(RX0 + 10, 176, w, 6, mix(c[:dark], c[:line], 0.4))
      base.fill_rect(RX0 + 10, 176, (w * [[frac, 0].max, 1].min).round, 6, tone(c, :blue))
      P.small(top, RX0 + 10, 184, w, 16, words, c[:dim], 1)
      soul_link(top, pk)
    end

    # KIF's Soul Link: the partner's Pokémon and the pair's dot (NSL-13), at
    # the Exp. box's foot
    def soul_link(top, pk)
      return unless defined?(::KIF::SoulLink::Menu) && (::KIF::SoulLink.linked? rescue false)
      ::KIF::SoulLink::Menu.draw_partner(top, pk, [RX0 + 22, 180, 24, 24], [RX0 + 12, 188])
    rescue StandardError => e
      Reloaded::Log.warning_once("The Summary couldn't show the Soul Link partner: #{e.message}", :summary)
    end

    def memo_box(base, top, c, pk)
      y1 = BOTTOM - 46
      box(base, c, RX0, 210, RX1, y1)
      P.heading(top, RX0 + 10, RX1 - 10, 216, _INTL("Memo"), c[:head], c[:line])
      w = RX1 - RX0 - 20
      lines = []
      lines << [_INTL("{1} nature.", SU.nature_name(pk)), tone(c, :red)] if SU.nature_shown?(pk)
      [SU.met_line(pk), SU.hatched_line(pk)].compact.each do |t|
        P.small_wrap(top, t, w).each { |ln| lines << [ln, c[:txt]] }
      end
      ch = SU.characteristic(pk)
      lines << [ch, c[:txt]] unless ch.empty?
      room = (y1 - 4 - 230) / 16
      lines.first(room).each_with_index { |(t, col), i| P.small(top, RX0 + 10, 230 + i * 16, w, 16, t, col) }
    end

    #---------------------------------------------------------------- STATS
    def stats_page(base, top, c)
      pk = @pokemon
      look = shown
      left_column(base, top, c)
      y1 = TOP + 152
      box(base, c, RX0, TOP, RX1, y1)
      P.heading(top, RX0 + 10, RX1 - 10, 42, _INTL("Stats"), c[:head], c[:line])
      vx, ix, ex, bx = RX0 + 128, RX0 + 182, RX0 + 240, RX1 - 14
      [[ix, "IV"], [ex, "EV"], [bx, _INTL("BASE")]].each { |x, l| P.text(top, x - 40, 56, 40, 14, l, c[:dim], PF::TINY, 1) }
      up, down = SU.nature_marks(pk)
      own_rows = SU.stats(pk)
      rows = @kr_look ? SU.stats(look) : own_rows
      tot = [0, 0, 0]
      own_rows.each_with_index do |(s, n, _v, iv, ev, _b), i|
        y = 70 + i * 17
        v = rows[i][2]
        b = rows[i][5]
        if @kr_ev == i
          @cursor_rect = [RX0 + 4, y - 1, RX1 - RX0 - 8, 18]
        end
        @kr_stat_hits << [i, RX0 + 4, y - 1, RX1 - 4, y + 16]
        name_col = s == up ? tone(c, :red) : (s == down ? tone(c, :blue) : c[:txt])
        P.text(top, RX0 + 10, y, 76, 18, n, name_col, PF::TEXT)
        P.text(top, vx - 40, y, 40, 18, v.to_s, raised?(i) ? GHOST : c[:strong], PF::TEXT, 1)
        P.text(top, ix - 40, y, 40, 18, iv.to_s, iv >= 31 ? GOLD : PP.ink(c, LILAC), PF::TEXT, 1)
        P.text(top, ex - 40, y, 40, 18, ev.to_s, tone(c, :green), PF::TEXT, 1)
        P.text(top, bx - 40, y, 40, 18, b.to_s, raised?(i) ? GHOST : tone(c, :blue), PF::TEXT, 1)
        tot[0] += iv
        tot[1] += ev
        tot[2] += b
      end
      base.fill_rect(RX0 + 10, 173, RX1 - RX0 - 20, 1, c[:line])
      P.small(top, RX0 + 10, 173, 60, 16, _INTL("Total"), c[:dim])
      P.small(top, ix - 40, 173, 40, 16, tot[0].to_s, c[:txt], 1)
      P.small(top, ex - 40, 173, 40, 16, tot[1].to_s, c[:txt], 1)
      P.small(top, bx - 40, 173, 40, 16, tot[2].to_s, c[:txt], 1)
      ability_plate(base, top, c, RX0, y1 + 6, MID - 3, BOTTOM - 46)
      weakness_plate(base, top, c, MID + 3, y1 + 6, RX1, BOTTOM - 46)
      standard_strip(base, top, c)
    end

    def ability_plate(base, top, c, x0, y0, x1, y1)
      pk = @pokemon
      box(base, c, x0, y0, x1, y1)
      w = x1 - x0 - 20
      pair = SU.double_pair(pk)
      look = @kr_look ? @kr_look[0] : nil
      look_pair = look ? SU.double_pair(look) : nil
      P.heading(top, x0 + 10, x1 - 10, y0 + 6, pair ? _INTL("Abilities") : _INTL("Ability"), c[:head], c[:line])
      if pair && defined?(Reloaded::DoubleAbilitiesLook)
        dl = Reloaded::DoubleAbilitiesLook
        room = w - 44
        names = pair.map { |_s, id| SU.ability_name(id) }
        small = names.any? { |n| P.width(PF::TEXT, n) > room }      # both in the small text when one won't fit
        pair.each_with_index do |(side, _id), i|
          y = y0 + 20 + i * 22
          dl.tag(top, c, x0 + 10, y + 2, dl.side_tag(side))
          if small
            P.small(top, x0 + 54, y + 1, room, 18, fit_small(top, names[i], room), c[:strong])
          else
            P.text(top, x0 + 54, y, room, 20, names[i], c[:strong], PF::TEXT)
          end
        end
        return
      end
      id = SU.ability_id(pk)
      P.text(top, x0 + 10, y0 + 20, w, 20, PF.fit(PF::TEXT, SU.ability_name(id), w), c[:strong], PF::TEXT)
      if look_pair
        other = look_pair.map { |_s, a| a }.find { |a| a != id }
        P.small(top, x0 + 10, y0 + 40, w, 16, _INTL("And: {1}", SU.ability_name(other)), GHOST) if other
      elsif kifer? && pk.respond_to?(:innates) && !Array(pk.innates).empty?
        P.small(top, x0 + 10, y0 + 40, w, 16, _INTL("And {1} Innates", Array(pk.innates).length), c[:dim])
      elsif (hid = SU.hidden_ability(pk))
        P.small(top, x0 + 10, y0 + 40, w, 16, fit_small(top, _INTL("Hidden: {1}", SU.ability_name(hid)), w), c[:dim])
      elsif (Array(pk.species_data.hidden_abilities).include?(id) rescue false)
        P.small(top, x0 + 10, y0 + 40, w, 16, _INTL("Its Hidden Ability"), c[:dim])
      end
    end

    # Weak and Resists, each type's icon and its multiplier (x4, 1/4, 0) when
    # it isn't x2 or 1/2; a row runs on when it's full
    def weakness_plate(base, top, c, x0, y0, x1, y1)
      box(base, c, x0, y0, x1, y1)
      P.heading(top, x0 + 10, x1 - 10, y0 + 6, _INTL("Weakness"), c[:head], c[:line])
      w = SU.weakness(types_of(shown), SU.abilities_of(@kr_look ? @kr_look[0] : @pokemon))
      y = y0 + 20
      y = type_flow(top, c, x0, x1, y, _INTL("Weak"), w[:weak]) { |m| m >= 4 ? "x4" : nil }
      if w[:wonder]
        P.small(top, x0 + 10, y - 1, 60, 16, _INTL("Resists"), c[:dim])
        P.small(top, x0 + 72, y - 1, x1 - x0 - 82, 16, _INTL("All Others"), tone(c, :green))
      else
        type_flow(top, c, x0, x1, y, _INTL("Resists"), w[:resist]) { |m| m == 0 ? "0" : (m <= 0.25 ? "1/4" : nil) }
      end
    end

    # One labelled run of type icons; the y after it
    def type_flow(top, c, x0, x1, y, label, list)
      P.small(top, x0 + 10, y - 1, 60, 16, label, c[:dim])
      if list.empty?
        P.small(top, x0 + 72, y - 1, x1 - x0 - 82, 16, _INTL("None"), c[:dim])
        return y + 19
      end
      x = x0 + 72
      list.each do |t, m|
        tag = yield(m)
        need = 18 + (tag ? P.width(PF::TEXT, tag) + 4 : 0)
        if x + need > x1 - 6
          x = x0 + 72
          y += 19
        end
        small_type(top, t, x, y + 1)
        x += 18
        if tag
          col = m == 0 ? tone(c, :green) : c[:txt]
          x += P.small(top, x, y - 1, 30, 16, tag, col).to_i + 4
        end
      end
      return y + 19
    end

    #---------------------------------------------------------------- ABILITIES (KIF: Elite Redux)
    def abilities_page(base, top, c)
      pk = @pokemon
      left_column(base, top, c)
      rows = kifer_list
      abil = rows.reject { |r| r[0] == :innate }
      inn = rows.select { |r| r[0] == :innate }
      y1 = [168, 56 + abil.length * 20 + (inn.empty? ? 0 : 20) + inn.length * 20 + 4].max
      box(base, c, RX0, TOP, RX1, y1)
      P.heading(top, RX0 + 10, RX1 - 10, 42, abil.length > 1 ? _INTL("Abilities") : _INTL("Ability"), c[:head], c[:line])
      y = 56
      rows.each_with_index do |(kind, id, i, n), r|
        if kind == :innate && (r == 0 || rows[r - 1][0] != :innate)
          P.heading(top, RX0 + 10, RX1 - 10, y + 6, _INTL("Innates"), c[:head], c[:line])
          y += 20
        end
        if r == @kr_row
          @cursor_rect = [RX0 + 4, y - 1, RX1 - RX0 - 8, 20]
        end
        @kr_row_hits << [r, RX0 + 4, y - 1, RX1 - 4, y + 19]
        coded = defined?(::KIFER) && ::KIFER.respond_to?(:coded?) ? ::KIFER.coded?(id) : true
        P.text(top, RX0 + 12, y, 200, 18, PF.fit(PF::TEXT, SU.ability_name(id), 200), kind == :innate ? c[:txt] : c[:strong], PF::TEXT)
        if kind == :innate
          P.small(top, RX0 + 10, y + 1, RX1 - RX0 - 20, 16, coded ? _INTL("Always Active") : _INTL("Coming Soon"),
                  coded ? tone(c, :green) : c[:dim], 1)
        elsif n.to_i > 0
          P.pill(top, RX1 - 12, y + 2, _INTL("{1} OF {2}", i.to_i + 1, n), mix(c[:panel2], c[:selb], 0.28), c[:selb], true)
        end
        y += 20
      end
      box(base, c, RX0, y1 + 6, RX1, BOTTOM - 46)
      sel = rows[@kr_row]
      if sel
        w = RX1 - RX0 - 20
        P.text(top, RX0 + 10, y1 + 12, w, 18, PF.fit(PF::TEXT, SU.ability_name(sel[1]), w), c[:strong], PF::TEXT)
        text = defined?(::KIFER) && ::KIFER.respond_to?(:ability_full_text) ? (::KIFER.ability_full_text(sel[1]) rescue "") : SU.ability_text(sel[1])
        room = [(BOTTOM - 46 - 4 - (y1 + 32)) / 17, 1].max
        P.small_wrap(top, text.to_s.tr("\n", " "), w).first(room).each_with_index do |ln, i|
          P.small(top, RX0 + 10, y1 + 32 + i * 17, w, 16, ln, c[:txt])
        end
      else
        P.text(top, RX0 + 10, y1 + 12, RX1 - RX0 - 20, 18, _INTL("No Abilities to Show"), c[:dim], PF::TEXT)
      end
      words = if !(@kr_own && !@inbattle) then nil
              elsif sel && (sel[0] == :ability || sel[0] == :ability2) then _INTL("A: Choose another of its abilities.")
              elsif sel && ability_changeable? then _INTL("A: Choose its {1} innates.", [3, inn.length].min)
              end
      text_strip(base, top, c, words, nil, c[:dim])
    end

    #---------------------------------------------------------------- MOVES
    def moves_page(base, top, c)
      pk = @pokemon
      left_column(base, top, c)
      look = shown
      learning = @kr_learning
      list = (0...::Pokemon::MAX_MOVES).map { |i| look.moves[i] }
      list << learning if learning
      h = learning ? 128 : 112
      box(base, c, RX0, TOP, RX1, TOP + h)
      title = if learning then _INTL("{1} Wants to Learn {2}", pk.name, learning.name)
              elsif @kr_choosing then _INTL("Choose a Move")
              else _INTL("Moves")
              end
      P.heading(top, RX0 + 10, RX1 - 10, 42, PF.fit(PF::TINY, title.upcase, RX1 - RX0 - 40), c[:head], c[:line])
      ghost_slot = @kr_look ? @kr_look[2] : nil
      list.each_with_index do |m, i|
        y = 56 + i * 20
        if m.nil?
          P.text(top, RX0 + 34, y, 170, 18, "-", c[:dim], PF::TEXT)
          next
        end
        @cursor_rect = [RX0 + 4, y - 1, RX1 - RX0 - 8, 20] if i == @kr_move
        @kr_move_hits << [i, RX0 + 4, y - 1, RX1 - 4, y + 19]
        type = SU.move_type(look, m)
        small_type(top, type, RX0 + 12, y + 2)
        col = i == ghost_slot ? GHOST : (i == @kr_swap ? GOLD : c[:strong])
        P.text(top, RX0 + 34, y, 170, 18, PF.fit(PF::TEXT, m.name.to_s, 170), col, PF::TEXT)
        P.small(top, RX0 + 10, y + 1, RX1 - RX0 - 20, 16, pp_words(m), pp_colour(c, m), 1)
        if learning && i == ::Pokemon::MAX_MOVES
          P.pill(top, RX1 - 60, y + 2, _INTL("NEW"), mix(c[:panel2], GOLD, 0.28), GOLD, true)
        elsif i == @kr_swap
          P.pill(top, RX1 - 60, y + 2, _INTL("SWAP"), mix(c[:panel2], GOLD, 0.28), GOLD, true)
        end
      end
      move_details(base, top, c, look, list[@kr_move], TOP + h + 6)
    end

    def pp_words(m)
      return m.total_pp.to_i > 0 ? "#{m.pp}/#{m.total_pp}" : "--"
    end

    def pp_colour(c, m)
      return c[:dim] if m.total_pp.to_i <= 0
      return tone(c, :red) if m.pp.to_i == 0 || m.pp * 4 <= m.total_pp
      return tone(c, :amber) if m.pp * 2 <= m.total_pp
      return c[:dim]
    end

    def move_details(base, top, c, look, m, y0)
      box(base, c, RX0, y0, RX1, BOTTOM)
      return unless m
      type = SU.move_type(look, m)
      type_badge(top, type, RX0 + 10, y0 + 8, 64, 28)
      cat = CATEGORY[(m.category rescue 2).to_i] || CATEGORY[2]
      col = PP.ink(c, cat[1])
      P.pill(top, RX0 + 80, y0 + 14, _INTL(cat[0]), mix(c[:panel2], col, 0.28), col, false)
      power = SU.move_power(look, m).to_i
      power_words = power == 0 ? "---" : (power == 1 ? "???" : power.to_s)
      acc = m.accuracy.to_i == 0 ? "---" : "#{m.accuracy}%"
      P.small(top, RX0 + 160, y0 + 13, 50, 16, _INTL("Power"), c[:dim])
      P.small(top, RX0 + 160, y0 + 13, 76, 16, power_words, c[:txt], 1)
      P.small(top, RX0 + 250, y0 + 13, 40, 16, _INTL("Acc."), c[:dim])
      P.small(top, RX0 + 250, y0 + 13, RX1 - RX0 - 260, 16, acc, c[:txt], 1)
      hidden = defined?(Reloaded::HiddenPower) && (Reloaded::HiddenPower.hidden_power_move?(m.id) rescue false) && !look.egg?
      words = hidden ? _INTL("A move whose type is this Pokémon's own: {1}.", (::GameData::Type.get(type).name rescue type.to_s)) : m.description.to_s
      w = RX1 - RX0 - 20
      room = [(BOTTOM - (hidden ? 30 : 6) - (y0 + 38)) / 17, 1].max
      P.small_wrap(top, words, w).first(room).each_with_index { |ln, i| P.small(top, RX0 + 10, y0 + 38 + i * 17, w, 16, ln, c[:txt]) }
      if hidden
        name = (::GameData::Type.get(type).name rescue type.to_s).to_s.upcase
        P.pill(top, RX0 + 10, BOTTOM - 24, _INTL("REAL TYPE: {1}", name), mix(c[:panel2], GOLD, 0.28), GOLD, false)
      end
    end

    #---------------------------------------------------------------- an Egg
    def egg_page(base, top, c)
      pk = @pokemon
      plate(base, c, Color.new(*EGG_RGB), LCX0, TOP, LCX1, BOTTOM - 46, LINE_Y)
      P.text(top, LCX0 + 10, 40, 150, 22, _INTL("Egg"), c[:strong], PF::ROW)
      plate_marks(top, c, pk)
      box(base, c, RX0, TOP, RX1, 146)
      P.heading(top, RX0 + 10, RX1 - 10, 42, _INTL("The Egg"), c[:head], c[:line])
      _lim, a, b = SU.egg_words(pk)
      w = RX1 - RX0 - 20
      lines = text_lines(_INTL(a), w).first(2)
      lines.each_with_index { |ln, i| P.text(top, RX0 + 10, 58 + i * 20, w, 18, ln, c[:txt], PF::TEXT) }
      P.small(top, RX0 + 10, 60 + lines.length * 20, w, 16, _INTL(b), c[:dim])
      box(base, c, RX0, 152, RX1, BOTTOM - 46)
      P.heading(top, RX0 + 10, RX1 - 10, 158, _INTL("Memo"), c[:head], c[:line])
      place = pk.respond_to?(:obtain_text) && !pk.obtain_text.to_s.empty? ? pk.obtain_text.to_s : SU.map_name(pk.obtain_map)
      P.small(top, RX0 + 10, 172, w, 16, fit_small(top, place ? _INTL("From {1}.", place) : _INTL("A mysterious Pokémon Egg."), w), c[:txt])
      d = SU.date(pk.timeReceived)
      P.small(top, RX0 + 10, 188, w, 16, _INTL("Received {1}.", d), c[:dim]) if d
      text_strip(base, top, c, _INTL("Its other pages open once it hatches."), nil, c[:dim])
    end

    #---------------------------------------------------------------- a message
    # The bar along the bottom (the Party Screen's Message Bar, his pick)
    def paint_message(over, c)
      over.clear
      y0 = H - P::HINT_H - 52
      y1 = H - P::HINT_H - 8
      PP.chamfer_grad(over, 8, y0, W - 8, y1, 12, mix(c[:panel], c[:selb], 0.22), c[:panel], c[:selb])
      over.fill_rect(20, y0 + 1, W - 40, 1, mix(c[:selb], PP::WHITE, 0.4))
      lines = @kr_message
      lines.each_with_index do |ln, j|
        ly = lines.length == 1 ? y0 + 13 : y0 + 4 + j * 18
        P.text(over, 22, ly, W - 70, 18, ln, c[:txt], PF::TEXT)
      end
      P.ui.tri(over, W - 30, y0 + 19, :d, c[:selb], 5)
    end
  end
end
