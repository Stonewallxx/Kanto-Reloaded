# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Reloaded PC's Search (Step 4)
#==============================================================================
# More of the PC scene (UI/PCScene.rb), his Step 4 picks (2026-10-24): Dim
# the Rest, In the Header. RS (or a click on the Search hint) opens it: the
# box name becomes the field (type straight in; a controller's A opens the
# naming screen) and filter chips take the party's place: Type (A picks
# one), Shiny, Egg, Fusion, Held Item. What doesn't match dims as you type,
# in every box and the party. Down goes to the filters, Up back to the
# name; RS or Enter is done, B clears it.
#
# After: a pill by the box name says what's searched and how many are here,
# the names either side are the nearest boxes with a match (and how many),
# and LB / RB jump to them. RS searches again; B clears it. A search lasts
# until it's cleared or the PC closes.
#
# More Search Filters (his pick, 2026-10-25: A More Popup): MORE ends the
# chips (MORE: 2 when two are on); A on it opens the rest as rows. Ability
# and Knows (a move): type a name straight in (a controller's A opens the
# naming screen), or Left / Right step through your Pokémon's. Nature (A
# lists them), Gender, Level (in tens), Perfect IVs (how many at 31),
# Marked (any mark, or one shape) and NEW: Left / Right. An Egg matches
# none of them but Marked and NEW. B or Enter is done.
#==============================================================================

return unless defined?(Reloaded::PCScene)

module Reloaded
  module PCScene
    SEARCH_FILTERS = [[:shiny, "Shiny"], [:egg, "Egg"], [:fusion, "Fusion"], [:item, "Held Item"]].freeze
    SEARCH_MAX = 20
    SEARCH_W = 200
    # The More Filters popup's rows; Ability and Knows are typed
    MORE_ROWS = [[:ability, "Ability"], [:nature, "Nature"], [:move, "Knows"], [:gender, "Gender"], [:level, "Level"],
                 [:ivs, "Perfect IVs"], [:marked, "Marked"], [:new, "NEW"]].freeze
    MORE_TYPED = [:ability, :move].freeze
    MORE_W = 340
    MORE_ROW = 22
    GENDER_WORDS = ["Male", "Female", "Genderless"].freeze

    private

    def search_editing?
      return @kr_search && @kr_search[:editing] ? true : false
    end

    # A search is set and done (its results showing)
    def search_on?
      return @kr_search && !@kr_search[:editing] && search_set? ? true : false
    end

    # Something to match: a name or a filter
    def search_set?
      s = @kr_search
      return false unless s
      return !s[:text].to_s.strip.empty? || !s[:type].nil? || SEARCH_FILTERS.any? { |k, _w| s[k] } || more_on > 0
    end

    def new_search
      return { :text => "", :type => nil, :shiny => false, :egg => false, :fusion => false, :item => false,
               :ability => "", :ability_exact => false, :nature => nil, :move => "", :move_exact => false,
               :gender => nil, :level => nil, :ivs => 0, :marked => nil, :new => false,
               :editing => true, :at => :field, :chip => 0 }
    end

    # How many of More's filters are on
    def more_on
      return MORE_ROWS.count { |k, _w| more_set?(k) }
    end

    def more_set?(key)
      v = @kr_search[key]
      return !v.to_s.strip.empty? if MORE_TYPED.include?(key)
      return v.to_i > 0 if key == :ivs
      return v ? true : false
    end

    # RS: search, or change the search
    def open_search
      if @kr_party_only || fusing?
        pbPlayBuzzerSE
        return :stay
      end
      @kr_search ||= new_search
      @kr_search[:editing] = true
      @kr_search[:at] = :field
      @kr_match = {}
      pbPlayDecisionSE
      result = nil
      loop do
        result = @kr_search[:at] == :field ? search_field_loop : search_chips_loop
        break unless result == :down || result == :up
      end
      if result == :cancel || !search_set?
        @kr_search = nil
      else
        @kr_search[:editing] = false
      end
      @kr_match = {}
      refresh
      return :stay
    end

    def clear_search
      @kr_search = nil
      @kr_match = {}
      pbPlayCancelSE
      refresh
      return :stay
    end

    # The name: typed straight in, or a controller's A opens the naming
    # screen. :down (to the filters), :done or :cancel.
    def search_field_loop
      state = Reloaded::TextEntry::State.new(_INTL("Type a Name"), @kr_search[:text], SEARCH_MAX)
      @kr_entry = state
      text_input(true)
      Input.gets if Input.respond_to?(:gets)     # drop the key that opened it
      ret = nil
      hints = [[:d, _INTL("Filters")], [button(:C), _INTL("Type")], [button(:Z), _INTL("Done")], [button(:B), _INTL("Clear")]]
      with_popup_hints(hints) do
        loop do
          Graphics.update
          Input.update
          update
          state.timer += 1
          case Reloaded::TextEntry.step(state, false)
          when :changed
            search_changed(state.text)
          when :enter
            ret = :done
          when :stop
            ret = :cancel
          when :pad
            pbPlayDecisionSE
            text_input(false)
            typed = nil
            hidden { typed = pbEnterText(_INTL("Search for a Name"), 0, SEARCH_MAX, state.text) }
            text_input(true)
            state.text = typed.to_s[0, SEARCH_MAX] unless typed.nil?
            search_changed(state.text)
          else
            if Input.trigger?(Input::DOWN)
              ret = :down
            elsif Input.trigger?(Input::SPECIAL)
              ret = :done
            elsif state.timer % 20 == 0
              refresh                                   # the caret blinks
            end
          end
          break if ret
        end
      end
      case ret
      when :down
        @kr_search[:at] = :chips
        pbPlayCursorSE
      when :done then pbPlayDecisionSE
      else pbPlayCancelSE
      end
      return ret
    ensure
      text_input(false)
      @kr_entry = nil
    end

    # The filters: Left / Right choose, A turns one on or off (on Type, picks
    # a type), Up goes back to the name. :up, :done or :cancel.
    def search_chips_loop
      before = @popup_hints
      ret = nil
      redraw = true
      loop do
        if redraw
          @popup_hints = chip_hints
          refresh
          redraw = false
        end
        Graphics.update
        Input.update
        update
        pt = Reloaded::Pointer
        hit = pt.hit(@kr_chip_hits || [])
        if pt.moved? && hit && hit != @kr_search[:chip]
          @kr_search[:chip] = hit
          pbPlayCursorSE
          redraw = true
        end
        if pt.left? && hit
          @kr_search[:chip] = hit
          toggle_chip
          redraw = true
        elsif pt.right? || Input.trigger?(Input::BACK)
          pbPlayCancelSE
          ret = :cancel
        elsif Input.trigger?(Input::UP)
          pbPlayCursorSE
          @kr_search[:at] = :field
          ret = :up
        elsif Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)
          @kr_search[:chip] = (@kr_search[:chip] + (Input.repeat?(Input::LEFT) ? -1 : 1)) % (SEARCH_FILTERS.length + 2)
          pbPlayCursorSE
          redraw = true
        elsif Input.trigger?(Input::USE)
          toggle_chip
          redraw = true
        elsif Input.trigger?(Input::SPECIAL)
          pbPlayDecisionSE
          ret = :done
        end
        break if ret
      end
      return ret
    ensure
      @popup_hints = before
    end

    def chip_hints
      k = @kr_search[:chip]
      verb = if k == 0 then _INTL("Pick a Type")
             elsif k > SEARCH_FILTERS.length then _INTL("More Filters")
             elsif @kr_search[SEARCH_FILTERS[k - 1][0]] then _INTL("Turn Off")
             else _INTL("Turn On")
             end
      return [[:lr, _INTL("Choose")], [button(:C), verb], [:u, _INTL("Name")], [button(:Z), _INTL("Done")], [button(:B), _INTL("Clear")]]
    end

    def toggle_chip
      k = @kr_search[:chip]
      pbPlayDecisionSE
      if k == 0
        types = search_types
        names = [_INTL("Any Type")] + types.map { |t| ::GameData::Type.get(t).name }
        start = @kr_search[:type] ? (types.index(@kr_search[:type]) || -1) + 1 : 0
        pick = Reloaded::Dialogs.picker(self, _INTL("Type"), names, start)
        @kr_search[:type] = pick == 0 ? nil : types[pick - 1] unless pick.nil?
      elsif k > SEARCH_FILTERS.length
        more_filters
      else
        key = SEARCH_FILTERS[k - 1][0]
        @kr_search[key] = !@kr_search[key]
      end
      @kr_match = {}
    end

    def search_types
      list = []
      ::GameData::Type.each do |t|
        next if (t.respond_to?(:pseudo_type) && t.pseudo_type) || t.id == :QMARKS
        list << t.id
      end
      return list
    end

    def search_changed(text)
      @kr_search[:text] = text.to_s
      @kr_match = {}
      refresh
    end

    def text_input(on)
      Input.text_input = on if Input.respond_to?(:text_input=)
    rescue StandardError
      nil
    end

    #--------------------------------------------------------------------------
    # Matching
    #--------------------------------------------------------------------------
    # Does it match the search (always, with none set)? Kept per Pokémon
    # until the search or the Pokémon changes.
    def search_match?(pk)
      return true unless search_set?
      @kr_match ||= {}
      key = pk.object_id
      return @kr_match[key] if @kr_match.key?(key)
      return @kr_match[key] = search_test(pk)
    end

    def search_test(pk)
      s = @kr_search
      words = s[:text].to_s.strip.downcase
      unless words.empty?
        names = [pk.name.to_s]
        names << pk.speciesName.to_s if !pk.egg? && pk.respond_to?(:speciesName)   # an Egg doesn't give away what's in it
        return false unless names.any? { |n| n.downcase.include?(words) }
      end
      return false if s[:type] && (pk.egg? || !types_of(pk).include?(s[:type]))
      return false if s[:shiny] && !shiny?(pk)
      return false if s[:egg] && !pk.egg?
      return false if s[:fusion] && !(pk.isFusion? rescue false)
      return false if s[:item] && !(pk.respond_to?(:item_id) ? pk.item_id : pk.item)
      return more_test(s, pk)
    rescue StandardError
      return false
    end

    # More's filters; an Egg doesn't give away its ability, nature, moves,
    # gender, level or IVs
    def more_test(s, pk)
      if more_set?(:ability)
        return false if pk.egg? || !name_match?(ability_name(pk), s[:ability], s[:ability_exact])
      end
      return false if s[:nature] && (pk.egg? || nature_name(pk) != s[:nature])
      if more_set?(:move)
        return false if pk.egg? || pk.moves.none? { |m| m && name_match?(m.name, s[:move], s[:move_exact]) }
      end
      return false if s[:gender] && (pk.egg? || pk.gender != s[:gender])
      return false if s[:level] && (pk.egg? || !level_band(s[:level]).cover?(pk.level))
      return false if s[:ivs].to_i > 0 && (pk.egg? || perfect_ivs(pk) < s[:ivs])
      if s[:marked]
        bits = (pk.markings rescue 0).to_i
        return false if s[:marked] == :any ? bits == 0 : bits & (1 << s[:marked]) == 0
      end
      return false if s[:new] && !fresh?(pk)
      return true
    end

    # Typed: a part of the name; stepped to: the whole name
    def name_match?(name, text, exact)
      n = name.to_s.downcase
      t = text.to_s.strip.downcase
      return exact ? n == t : n.include?(t)
    end

    def ability_name(pk)
      return pk.ability ? pk.ability.name.to_s : ""
    rescue StandardError
      return ""
    end

    def nature_name(pk)
      return pk.nature ? pk.nature.name.to_s : nil
    rescue StandardError
      return nil
    end

    def level_band(band)
      return ((band - 1) * 10 + 1)..(band * 10)
    end

    def perfect_ivs(pk)
      return IV_KEYS.count { |k, _w| (pk.iv[k] rescue 0).to_i >= 31 }
    end

    def matches_in(bx)
      b = @storage[bx]
      return 0 unless b
      return (0...@storage.maxPokemon(bx)).count { |k| (pk = @storage[bx, k]) && search_match?(pk) }
    end

    # The nearest boxes with a match before and after this one (nil: none)
    def match_boxes
      n = @storage.maxBoxes
      cur = @storage.currentBox
      before = (1...n).map { |d| (cur - d) % n }.find { |j| matches_in(j) > 0 }
      after = (1...n).map { |d| (cur + d) % n }.find { |j| matches_in(j) > 0 }
      return [before, after]
    end

    # What's searched, in a few words: LAP + WATER + SHINY
    def search_words
      s = @kr_search
      parts = []
      parts << s[:text].to_s.strip.upcase unless s[:text].to_s.strip.empty?
      parts << ::GameData::Type.get(s[:type]).name.upcase if s[:type]
      SEARCH_FILTERS.each { |k, w| parts << _INTL(w).upcase if s[k] }
      MORE_ROWS.each { |k, _w| parts << more_word(k).upcase if more_set?(k) }
      return parts.join(" + ")
    end

    # One of More's filters, in a few words: Knows Surf, Lv 21-30
    def more_word(key)
      s = @kr_search
      case key
      when :ability then return s[:ability].to_s.strip
      when :nature then return s[:nature].to_s
      when :move then return _INTL("Knows {1}", s[:move].to_s.strip)
      when :gender then return _INTL(GENDER_WORDS[s[:gender]])
      when :level then return _INTL("Lv {1}", more_value(:level))
      when :ivs then return s[:ivs] >= IV_KEYS.length ? _INTL("Perfect IVs") : _INTL("{1}+ Perfect IVs", s[:ivs])
      when :marked then return s[:marked] == :any ? _INTL("Marked") : _INTL("{1} Mark", _INTL(SHAPES[s[:marked]]))
      end
      return _INTL("NEW")
    end

    #--------------------------------------------------------------------------
    # More Filters (his pick: A More Popup)
    #--------------------------------------------------------------------------
    # Every value Left / Right step through, Any (or Off) first
    def more_values(key, owned)
      case key
      when :ability, :move, :nature then return [nil] + owned[key]
      when :gender then return [nil, 0, 1, 2]
      when :level then return [nil] + (1..10).to_a
      when :ivs then return (0..IV_KEYS.length).to_a
      when :marked then return [nil, :any] + (0...SHAPES.length).to_a
      end
      return [false, true]
    end

    # The abilities, moves and natures your Pokémon have (not Eggs'), A to Z
    def owned_names
      found = { :ability => {}, :move => {}, :nature => {} }
      each_pokemon do |pk|
        next if pk.egg?
        a = ability_name(pk)
        found[:ability][a] = true unless a.empty?
        n = nature_name(pk)
        found[:nature][n] = true if n
        pk.moves.each { |m| found[:move][m.name.to_s] = true if m && !m.name.to_s.empty? }
      end
      return found.map { |k, h| [k, h.keys.sort] }.to_h
    end

    def each_pokemon(&block)
      @storage.party.each { |pk| block.call(pk) if pk }
      Reloaded::PC.each_boxed(@storage, &block)
    end

    # A row's value in words
    def more_value(key)
      v = @kr_search[key]
      case key
      when :ability, :move then return v.to_s.strip.empty? ? _INTL("Any") : v.to_s
      when :nature then return v ? v.to_s : _INTL("Any")
      when :gender then return v ? _INTL(GENDER_WORDS[v]) : _INTL("Any")
      when :level then return v ? "#{level_band(v).first}-#{level_band(v).last}" : _INTL("Any")
      when :ivs
        return _INTL("Off") if v.to_i == 0
        return v >= IV_KEYS.length ? _INTL("All {1}", v) : _INTL("{1} or More", v)
      when :marked
        return _INTL("Off") unless v
        return v == :any ? _INTL("Any Mark") : _INTL(SHAPES[v])
      end
      return v ? _INTL("On") : _INTL("Off")
    end

    # Left / Right on a row (a typed name steps from where it is in the list)
    def more_step(key, dir, owned)
      list = more_values(key, owned)
      v = @kr_search[key]
      at = if MORE_TYPED.include?(key)
             v.to_s.strip.empty? ? 0 : (list.index { |n| n && n.downcase == v.to_s.strip.downcase } || 0)
           else
             list.index(v) || 0
           end
      v = list[(at + dir) % list.length]
      if MORE_TYPED.include?(key)
        @kr_search[key] = v.to_s
        @kr_search[:"#{key}_exact"] = true
      else
        @kr_search[key] = v
      end
      @kr_match = {}
    end

    def more_filters
      owned = owned_names
      row = 0
      state = nil
      state_key = nil
      before = @popup_hints
      redraw = true
      loop do
        key = MORE_ROWS[row][0]
        if MORE_TYPED.include?(key) && state_key != key
          # a typed row: what's typed goes straight in
          state = Reloaded::TextEntry::State.new(_INTL("Any"), @kr_search[key], SEARCH_MAX)
          state_key = key
          text_input(true)
          Input.gets if Input.respond_to?(:gets)
        elsif !MORE_TYPED.include?(key) && state
          state = nil
          state_key = nil
          text_input(false)
        end
        if redraw
          @popup_hints = more_hints(key)
          refresh
          draw_more(row, state)
          redraw = false
        end
        Graphics.update
        Input.update
        update
        if state
          state.timer += 1
          case Reloaded::TextEntry.step(state, false)
          when :changed
            @kr_search[key] = state.text
            @kr_search[:"#{key}_exact"] = false
            @kr_match = {}
            redraw = true
            next
          when :enter, :stop
            pbPlayDecisionSE
            break
          when :pad
            pbPlayDecisionSE
            text_input(false)
            typed = nil
            hidden { typed = pbEnterText(_INTL("{1} to Search For", _INTL(MORE_ROWS[row][1])), 0, SEARCH_MAX, state.text) }
            text_input(true)
            unless typed.nil?
              state.text = typed.to_s[0, SEARCH_MAX]
              @kr_search[key] = state.text
              @kr_search[:"#{key}_exact"] = false
              @kr_match = {}
            end
            redraw = true
            next
          end
          draw_more(row, state) if state.timer % 20 == 0     # the caret blinks
        end
        pt = Reloaded::Pointer
        hit = pt.hit(@kr_more_hits || [])
        if pt.moved? && hit && hit != row
          row = hit
          pbPlayCursorSE
          redraw = true
        end
        if pt.left? && hit
          row = hit
          unless MORE_TYPED.include?(MORE_ROWS[row][0])
            # left of the value steps back, right of it on
            more_step(MORE_ROWS[row][0], pt.pos[0] < (W + MORE_W) / 2 - 80 ? -1 : 1, owned)
            pbPlayCursorSE
          end
          redraw = true
        elsif pt.right? || (!state && Input.trigger?(Input::BACK))
          pbPlayDecisionSE
          break
        elsif Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN)
          row = (row + (Input.repeat?(Input::UP) ? -1 : 1)) % MORE_ROWS.length
          pbPlayCursorSE
          redraw = true
        elsif Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)
          more_step(key, Input.repeat?(Input::LEFT) ? -1 : 1, owned)
          state.text = @kr_search[key].to_s if state
          pbPlayCursorSE
          redraw = true
        elsif !state && Input.trigger?(Input::USE)
          if key == :nature
            pbPlayDecisionSE
            names = [_INTL("Any")] + owned[:nature]
            pick = Reloaded::Dialogs.picker(self, _INTL("Nature"), names, (owned[:nature].index(@kr_search[:nature]) || -1) + 1)
            @kr_search[:nature] = pick == 0 ? nil : owned[:nature][pick - 1] unless pick.nil?
            @kr_match = {}
          else
            more_step(key, 1, owned)
            pbPlayCursorSE
          end
          redraw = true
        end
      end
    ensure
      text_input(false)
      @popup_hints = before
      overlay.clear if @overlay_sprite && !@overlay_sprite.disposed?
    end

    def more_hints(key)
      list = [[:ud, _INTL("Choose")], [:lr, _INTL("Change")]]
      list << [button(:C), _INTL("Type")] if MORE_TYPED.include?(key)
      list << [button(:C), _INTL("List")] if key == :nature
      return list + [[button(:B), _INTL("Done")]]
    end

    def search_summary
      return _INTL("Type a name, or turn on a filter.") unless search_set?
      cur = @storage.currentBox
      here = matches_in(cur)
      others = (0...@storage.maxBoxes).reject { |j| j == cur }.map { |j| matches_in(j) }.reject(&:zero?)
      return _INTL("Nothing found.") if here == 0 && others.empty?
      return _INTL("{1} here", here) if others.empty?
      return _INTL("{1} here, {2} in 1 other box", here, others.sum) if others.length == 1
      return _INTL("{1} here, {2} in {3} other boxes", here, others.sum, others.length)
    end

    #--------------------------------------------------------------------------
    # Drawing (his pick: In the Header)
    #--------------------------------------------------------------------------
    def draw_search_field(base, top, c)
      state = @kr_entry
      unless state
        state = Reloaded::TextEntry::State.new(_INTL("Type a Name"), @kr_search[:text], SEARCH_MAX)
        state.timer = 20                       # no caret: the filters have the cursor
      end
      x = (W - SEARCH_W) / 2
      Reloaded::TextEntry.draw_field(base, top, c, state, x, 4, SEARCH_W, 23, 24)
      magnifier(top, x + 8, 10, c[:dim])
    end

    # The search pill's words after the box name (and its lock): WATER: 3
    def search_pill_words
      return PF.fit(PF::TINY, _INTL("{1}: {2}", search_words, matches_in(@storage.currentBox)), 120)
    end

    # The filters in the party's place, what's found under them
    def filters_row(base, top, c)
      bx0 = 6
      bx1 = W - 6
      PP.chamfer_grad(base, bx0, PARTY_Y, bx1, PARTY_Y1, 10, c[:panel2], mix(c[:panel2], c[:dark], 0.35), c[:line])
      P.heading(top, bx0 + 12, bx1 - 12, PARTY_Y + 4, _INTL("Filters"), c[:dim], c[:line])
      s = @kr_search
      type = s[:type]
      chips = [[type ? ::GameData::Type.get(type).name.upcase : _INTL("ANY TYPE"), !type.nil?, type || :NONE]]
      SEARCH_FILTERS.each { |k, w| chips << [_INTL(w).upcase, s[k], nil] }
      n = more_on
      chips << [n > 0 ? _INTL("MORE: {1}", n) : _INTL("MORE"), n > 0, nil]
      widths = chips.map { |l, _on, t| chip_width(l, t) }
      x = (W - (widths.sum + 8 * (chips.length - 1))) / 2
      y = PARTY_Y + 24
      @kr_chip_hits = []
      chips.each_with_index do |(label, on, t), k|
        w = chip(top, c, x, y, label, on, t)
        @kr_chip_hits << [k, x - 2, y - 2, x + w + 2, y + 20]
        @cursor_rect = [x - 3, y - 3, w + 7, 24] if s[:at] == :chips && s[:chip] == k
        x += w + 8
      end
      P.text(top, bx0, PARTY_Y + 50, bx1 - bx0, 16, search_summary, c[:dim], PF::TEXT, 2)
    end

    def chip_width(label, type)
      return P.width(PF::TINY, label) + 16 + (type ? 14 : 0)
    end

    # A filter chip: lit when on (the type's own colour on the Type chip,
    # which has arrows: A picks the type); its width
    def chip(b, c, x, y, label, on, type)
      w = chip_width(label, type)
      tint = type && type != :NONE ? PP.rgb(Reloaded::PartyScreen.type_rgb(type)) : c[:selb]
      fill = on ? mix(c[:panel2], tint, 0.35) : mix(c[:panel2], c[:bg], 0.3)
      P.ui.rbox(b, x, y, x + w, y + 18, 4, fill, on ? tint : c[:line])
      tx = x + 8
      if type
        P.ui.tri(b, x + 4, y + 6, :l, c[:txt], 3)
        P.ui.tri(b, x + w - 8, y + 6, :r, c[:txt], 3)
        tx += 7
      end
      P.text(b, tx, y + 2, w - (tx - x) - 4, 14, label, on ? c[:txt] : c[:dim], PF::TINY)
      return w
    end

    # More Filters: the rows, a value between arrows (a typed one with its
    # caret), what's found under them
    def draw_more(row, state)
      b = overlay
      c = palette
      dg = Reloaded::Dialogs
      dg.send(:dim, b)
      w = MORE_W
      h = 40 + MORE_ROWS.length * MORE_ROW + 8 + 26
      x = (W - w) / 2
      y = (H - h) / 2
      dg.send(:panel, b, c, x, y, w, h)
      dg.send(:title_bar, b, c, x, y, w, _INTL("More Filters"))
      @kr_more_hits = []
      cx = x + w - 80
      MORE_ROWS.each_with_index do |(key, label), i|
        ry = y + 40 + i * MORE_ROW
        @kr_more_hits << [i, x + 6, ry, x + w - 6, ry + MORE_ROW - 2]
        dg.send(:cursor_row, b, c, x + 6, ry, x + w - 6, ry + MORE_ROW - 2) if i == row
        P.text(b, x + 16, ry, 150, MORE_ROW - 2, _INTL(label), c[:opt])
        on = more_set?(key)
        v = PF.fit(PF::TEXT, more_value(key), 130)
        vw = P.width(PF::TEXT, v)
        P.text(b, cx - vw / 2, ry, vw + 2, MORE_ROW - 2, v, on ? c[:txt] : c[:dim])
        if state && i == row && state.caret_visible?
          kx = on ? cx + vw / 2 + 2 : cx - vw / 2 - 4
          b.fill_rect(kx, ry + 4, 2, MORE_ROW - 10, c[:selb])
        end
        arrow = i == row ? c[:txt] : c[:dim]
        P.ui.tri(b, cx - vw / 2 - 14, ry + 7, :l, arrow, 3)
        P.ui.tri(b, cx + vw / 2 + 8, ry + 7, :r, arrow, 3)
      end
      b.fill_rect(x + 10, y + h - 30, w - 20, 1, c[:line])
      P.text(b, x + 14, y + h - 26, w - 28, 18, search_summary, c[:dim], PF::TEXT, 2)
    end

    def magnifier(b, x, y, col)
      [[2, 0, 4, 1], [1, 1, 1, 1], [6, 1, 1, 1], [0, 2, 1, 4], [7, 2, 1, 4], [1, 6, 1, 1], [6, 6, 1, 1], [2, 7, 4, 1],
       [7, 7, 2, 2], [8, 8, 2, 2], [9, 9, 2, 2]].each { |dx, dy, w, h| b.fill_rect(x + dx, y + dy, w, h, col) }
    end
  end
end
