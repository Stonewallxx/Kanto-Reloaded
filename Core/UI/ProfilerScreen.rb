#==============================================================================
# Kanto Reloaded: the Timing Profiler's screens
#==============================================================================
# Two modes of one screen, both design 1 in the Settings layout (Roadmap
# topic 33):
#
#   Report Viewer (:sessions)  the sessions on the left, newest first, each
#                              with a status dot; the selected one's sections
#                              on the right with PEAK and SLOW and their
#                              owner's dot; Y sorts, X filters by owner
#   Mod Timings (:mods)        the mods on the left (Kanto Reloaded first,
#                              PIF and KIF last); Startup, Data Patches, Per
#                              Frame on the map and in battle, then the
#                              slowest hooks; A opens a hook's session
#
# The title bar's boxes: Settings (back to the Timing Profiler's headings in
# the Kanto Reloaded section) and Mod
# Timings, or Sessions and Settings. The words of each description are made
# here from the numbers Reloaded::Profiler keeps.
#==============================================================================

return unless defined?(Reloaded::SplitScreen) && defined?(Reloaded::Profiler)

module Reloaded
  class ProfilerScreen
    include Reloaded::SplitScreen

    PEAK_X1 = VAL_X1 - 56            # the peak column's right edge (Slow is at VAL_X1)
    DOT_X = LIST_X0 + 13
    LABEL_X = LIST_X0 + 24
    BOX_W = 132                      # the right box, so Mod Timings fits
    KIND_TILES = { "battle" => ["B", [200, 80, 80]], "map" => ["M", [60, 170, 150]], "menu" => ["U", [80, 130, 210]],
                   "saving" => ["S", [150, 100, 200]], "loading" => ["L", [150, 100, 200]] }.freeze
    KIND_WORDS = { "battle" => "Battle", "map" => "Map load", "menu" => "Menu", "saving" => "Saving", "loading" => "Loading a save" }.freeze
    OWNER_RGB = { "Kanto Reloaded" => [214, 52, 60], "EBDX" => [230, 140, 50], "KIF" => [80, 160, 220],
                  "PIF" => [150, 150, 160], "All" => [205, 205, 210], "PIF and KIF" => [150, 150, 160] }.freeze
    SORTS = [:peak, :total, :calls, :name].freeze
    SORT_NAMES = { :peak => "Peak", :total => "Total", :calls => "Calls", :name => "Name" }.freeze
    STATS = [[:startup, "Startup"], [:data_patches, "Data Patches"], [:map, "Per Frame, Map"], [:battle, "Per Frame, Battle"]].freeze
    PR = Reloaded::Profiler
    HT = Reloaded::Profiler::HookTiming

    attr_reader :entry

    # mode: :sessions or :mods; from_settings: opened from the Developer
    # section (its Settings box goes back there).
    def self.open(mode = :sessions, from_settings = false)
      return new(mode, from_settings).main
    end

    def initialize(mode = :sessions, from_settings = false)
      frame_init
      @mode = mode
      @from_settings = from_settings
      @section = 0
      @sel = 0
      @scroll = 0
      @side_scroll = 0
      @focus = :side
      @sort = 0
      @owner = nil
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
    end

    def refresh
      draw_screen if @sprite && !@sprite.disposed?
    end

    private

    #--------------------------------------------------------------------------
    # What's shown
    #--------------------------------------------------------------------------
    def sessions
      return PR.sessions
    end

    def owners
      return HT.owners
    end

    # The sidebar's entries, in this mode.
    def entries
      return sessions if @mode == :sessions
      return owners
    end

    def entry_at(i = @section)
      return entries[i]
    end

    # [[:head, x] or [:row, row]]; a row is { :kind, :label, ... }
    def items
      return @items if @items
      list = []
      e = entry_at
      if e && @mode == :sessions
        list << [:head, e]
        section_rows(e).each { |r| list << [:row, r] }
      elsif e
        list << [:head, e]
        STATS.each do |key, label|
          next if e == HT::GAME_LABEL && [:startup, :data_patches].include?(key)
          list << [:row, { :kind => :stat, :key => key, :label => label, :owner => e }]
        end
        hooks = e == HT::GAME_LABEL ? [] : HT.hooks(e)
        unless hooks.empty?
          list << [:head, :hooks]
          hooks.first(12).each { |label, st| list << [:row, { :kind => :hook, :label => label, :stats => st, :owner => e }] }
        end
      end
      return @items = list
    end

    def rows
      return items.select { |kind, _| kind == :row }.map { |_, r| r }
    end

    def current
      return rows[@sel]
    end

    def changed
      @items = nil
      @sel = [[@sel, rows.length - 1].min, 0].max
    end

    # A session's sections: sorted (Y) and filtered by owner (X).
    def section_rows(s)
      list = s["sections"].map { |label, x| { :kind => :section, :label => label, :data => x, :owner => x["owner"].to_s } }
      list = list.select { |r| r[:owner] == @owner } if @owner
      frame, list = list.partition { |r| r[:label] == Reloaded::Profiler::FRAME_WORK }
      list = case SORTS[@sort]
             when :total then list.sort_by { |r| -r[:data]["total"].to_f }
             when :calls then list.sort_by { |r| -r[:data]["calls"].to_i }
             when :name then list.sort_by { |r| r[:label].downcase }
             else list.sort_by { |r| -r[:data]["peak"].to_f }
             end
      return list + frame                 # every frame's work, after the sections
    end

    def session_owners(s)
      return s["sections"].values.map { |x| x["owner"].to_s }.uniq.sort
    end

    #--------------------------------------------------------------------------
    # Input
    #--------------------------------------------------------------------------
    def handle_input
      return left_box_pressed if Input.trigger?(Input::JUMPUP) || Input.trigger?(Input::SPECIAL) || clicked?(*left_box)
      return right_box_pressed if Input.trigger?(Input::R) || clicked?(*right_box)
      handled, result = mouse_input
      return result if handled
      return side_input if @focus == :side
      return list_input
    end

    def side_input
      n = entries.length
      if (Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)) && n > 0
        dir = Input.repeat?(Input::DOWN) ? 1 : -1
        target = @section + dir
        if target < 0 || target >= n
          return nil unless fresh?(dir)
          target = dir < 0 ? n - 1 : 0
        end
        pick(target)
        pbPlayCursorSE
        refresh
      elsif Input.trigger?(Input::RIGHT) || Input.trigger?(Input::USE)
        open_list
      elsif Input.trigger?(Input::BACK)
        return back
      end
      return nil
    end

    def list_input
      n = rows.length
      if (Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)) && n > 0
        dir = Input.repeat?(Input::DOWN) ? 1 : -1
        target = @sel + dir
        if target < 0 || target >= n
          return nil unless fresh?(dir)
          target = dir < 0 ? n - 1 : 0
        end
        @sel = target
        pbPlayCursorSE
        refresh
      elsif Input.trigger?(Input::X) && @mode == :sessions     # a controller's Y
        sort_next
      elsif Input.trigger?(Input::ACTION) && @mode == :sessions  # a controller's X
        owner_next
      elsif Input.trigger?(Input::USE) && @mode == :mods
        open_in_sessions
      elsif Input.trigger?(Input::BACK) || Input.trigger?(Input::LEFT)
        return back
      end
      return nil
    end

    def mouse_input
      pt = Reloaded::Pointer
      if pointer_hover
        if (i = pt.hit(@side_hits)) && (i != @section || @focus != :side)
          pick(i)
          @focus = :side
          pbPlayCursorSE
          refresh
        elsif (k = pt.hit(@row_hits)) && (k != @sel || @focus != :list)
          @focus = :list
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
        elsif !entries.empty?
          pick([[@section + dir, 0].max, entries.length - 1].min)
          @focus = :side
        end
        refresh
        return [true, nil]
      end
      return [false, nil] unless pt.left?
      handled, result = hint_click
      return [true, result] if handled
      if (i = pt.hit(@side_hits))
        pick(i) if i != @section
        open_list
      elsif (k = pt.hit(@row_hits))
        @sel = k
        @focus = :list
        @mode == :mods ? open_in_sessions : refresh
      end
      return [true, nil]
    end

    def pick(i)
      @section = i
      @sel = 0
      @scroll = 0
      @owner = nil
      @items = nil
    end

    def open_list
      return pbPlayBuzzerSE if rows.empty?
      @focus = :list
      pbPlayDecisionSE
      refresh
      return nil
    end

    def back
      if @focus == :list
        pbPlayCancelSE
        @focus = :side
        refresh
        return nil
      end
      pbPlayCloseMenuSE
      return :close
    end

    def set_mode(mode)
      @mode = mode
      @focus = :side
      pick(0)
      refresh
    end

    # Settings (Report Viewer) or Sessions (Mod Timings).
    def left_box_pressed
      return switch_to(:sessions) if @mode == :mods
      return open_settings
    end

    # Mod Timings (Report Viewer) or Settings (Mod Timings).
    def right_box_pressed
      return switch_to(:mods) if @mode == :sessions
      return open_settings
    end

    def switch_to(mode)
      pbPlayDecisionSE
      set_mode(mode)
      return nil
    end

    # Back to the Timing Profiler's settings: closing, when it opened from
    # there.
    def open_settings
      pbPlayDecisionSE
      return :close if @from_settings
      hidden { Reloaded::KIFBridge.open_heading(_INTL("Timing Profiler")) }
      changed
      refresh
      return nil
    end

    # Y: the next order.
    def sort_next
      pbPlayCursorSE
      @sort = (@sort + 1) % SORTS.length
      changed
      refresh
      return nil
    end

    # X: only one owner's sections, then the next, then all again.
    def owner_next
      list = entry_at ? session_owners(entry_at) : []
      return pbPlayBuzzerSE if list.length < 2
      pbPlayCursorSE
      i = @owner ? list.index(@owner) : nil
      @owner = i.nil? ? list.first : list[i + 1]
      changed
      refresh
      return nil
    end

    # A on a hook: the session where it was slowest.
    def open_in_sessions
      r = current
      id = r && r[:kind] == :hook ? r[:stats]["session"] : nil
      i = id && sessions.index { |s| s["id"] == id }
      return pbPlayBuzzerSE unless i
      pbPlayDecisionSE
      @mode = :sessions
      pick(i)
      @focus = rows.empty? ? :side : :list
      refresh
      return nil
    end

    #--------------------------------------------------------------------------
    # Painting
    #--------------------------------------------------------------------------
    def draw_screen
      c = palette
      base = @sprite.bitmap
      top = @top_sprite.bitmap
      base.clear
      top.clear
      base.fill_rect(0, 0, W, H, c[:bg])
      @cursor_rect = nil
      paint_title(base, top, c)
      paint_side(base, top, c)
      paint_list(base, top, c)
      paint_description(base, top, c)
      paint_hints(base, c)
      place_cursor
    end

    def right_w
      return BOX_W
    end

    def left_box
      return [8, 4, 8 + BOX_W, 27]
    end

    def paint_title(base, top, c)
      paint_title_bar(base, c)
      P.text(top, 0, 2, W, 28, @mode == :sessions ? _INTL("Timing Profiler") : _INTL("Mod Timings"), c[:title], PF::TITLE, 2)
      left, right = @mode == :sessions ? [_INTL("Settings"), _INTL("Mod Timings")] : [_INTL("Sessions"), _INTL("Settings")]
      title_box(base, top, c, 8, left, :w => BOX_W)
      title_box(base, top, c, W - 8 - BOX_W, right, :w => BOX_W)
      style = Reloaded::Prompts.style
      Reloaded::ButtonIcons.draw(top, 8 + BOX_W + 6, 8, left_key, c, style) if left_key
      Reloaded::ButtonIcons.draw(top, W - 8 - BOX_W - 6 - Reloaded::ButtonIcons.width(right_key, style), 8, right_key, c, style) if right_key
    end

    def paint_side(base, top, c)
      list = if @mode == :sessions
               sessions.map do |s|
                 { :name => s["name"], :tile => KIND_TILES[s["kind"]] || ["?", [120, 120, 130]],
                   :dot => status_colour(s["status"]), :faded => s["earlier"] }
               end
             else
               owners.map { |o| { :name => o, :tile => o == Reloaded::Profiler::Owners::KR ? :ball : [o[0].to_s.upcase, owner_rgb(o)] } }
             end
      paint_sidebar(base, top, c, list, list.empty? ? nil : @section, @focus == :side)
    end

    def paint_list(base, top, c)
      P.ui.rbox(base, LIST_X0, LIST_Y0, LIST_X1, LIST_Y1, 6, c[:panel])
      @row_hits = []
      if items.empty?
        w = LIST_X1 - LIST_X0 - 24
        P.text(top, LIST_X0 + 12, LIST_Y0 + 8, w, 22, PF.fit(PF::TEXT, empty_line, w), c[:dim])
        return
      end
      sel = current && items.index { |kind, it| kind == :row && it.equal?(current) }
      out, total, avail = layout_items(items, sel)
      out.each do |i, y|
        kind, it = items[i]
        if kind == :head
          paint_heading(top, c, it, y)
          next
        end
        k = rows.index(it)
        @row_hits << [k, LIST_X0 + 4, y, LIST_X1 - 8, y + ROW_H - 2]
        @cursor_rect = [LIST_X0 + 4, y, (LIST_X1 - 8) - (LIST_X0 + 4) + 1, ROW_H - 1] if k == @sel && @focus == :list
        case it[:kind]
        when :section then paint_section_row(top, c, it, y)
        when :stat then paint_stat_row(top, c, it, y)
        when :hook then paint_hook_row(top, c, it, y)
        end
      end
      paint_list_scrollbar(base, c, total, avail)
    end

    def paint_heading(top, c, it, y)
      if it == :hooks
        P.text(top, VAL_X1 - 60, y + 3, 60, 13, _INTL("PEAK"), c[:dim], PF::TINY, 1)
        P.heading(top, LIST_X0 + 10, VAL_X1 - 70, y + 3, _INTL("Slowest Hooks"), c[:head], c[:line])
        return
      end
      if @mode == :sessions
        P.text(top, PEAK_X1 - 60, y + 3, 60, 13, _INTL("PEAK"), c[:dim], PF::TINY, 1)
        P.text(top, VAL_X1 - 44, y + 3, 44, 13, _INTL("SLOW"), c[:dim], PF::TINY, 1)
        title = [it["name"], it["kind"] == "map" ? nil : it["where"]].compact.uniq.join(", ")
        title += "  (#{@owner})" if @owner
        P.heading(top, LIST_X0 + 10, PEAK_X1 - 70, y + 3, title, c[:head], c[:line])
      else
        P.heading(top, LIST_X0 + 10, VAL_X1, y + 3, it.to_s, c[:head], c[:line])
      end
    end

    def paint_section_row(top, c, r, y)
      x = r[:data]
      P.ui.rbox(top, DOT_X, y + 10, DOT_X + 5, y + 15, 3, Color.new(*owner_rgb(r[:owner])))
      peak = ms(x["peak"])
      pw = PF.width(PF::ROW, peak)
      room = PEAK_X1 - pw - 10 - LABEL_X
      P.text(top, LABEL_X, y, room, ROW_H - 2, PF.fit(PF::ROW, r[:label], room), c[:opt], PF::ROW)
      P.text(top, PEAK_X1 - pw, y, pw + 2, ROW_H - 2, peak, severity_colour(x["peak"], c), PF::ROW)
      slow = x["slow"].to_i
      P.text(top, VAL_X1 - 44, y, 44, ROW_H - 2, slow.to_s, slow > 0 ? palette[:red] : c[:opt], PF::ROW, 1)
    end

    def paint_stat_row(top, c, r, y)
      value, colour = stat_value(r, c)
      vw = PF.width(PF::ROW, value)
      room = VAL_X1 - vw - 10 - NAME_X
      P.text(top, NAME_X, y, room, ROW_H - 2, PF.fit(PF::ROW, _INTL(r[:label]), room), c[:opt], PF::ROW)
      P.text(top, VAL_X1 - vw, y, vw + 2, ROW_H - 2, value, colour, PF::ROW)
    end

    def paint_hook_row(top, c, r, y)
      value = "#{ms(r[:stats]["peak"])} ms"
      vw = PF.width(PF::ROW, value)
      room = VAL_X1 - vw - 10 - NAME_X
      P.text(top, NAME_X, y, room, ROW_H - 2, PF.fit(PF::ROW, short_label(r[:label]), room), c[:opt], PF::ROW)
      P.text(top, VAL_X1 - vw, y, vw + 2, ROW_H - 2, value, severity_colour(r[:stats]["peak"], c), PF::ROW)
    end

    # [text, colour] for a Mod Timings stat row.
    def stat_value(r, c)
      seconds = stat_seconds(r)
      return [_INTL("None"), c[:dim]] if seconds.nil? || (seconds == 0.0 && [:map, :battle].include?(r[:key]))
      return ["#{ms(seconds)} ms", c[:opt]]
    end

    def stat_seconds(r)
      o = r[:owner]
      case r[:key]
      when :startup
        st = HT.startup_of(o)
        return nil unless st[:scripts] || st[:data_patches]
        return st[:scripts].to_f + st[:data_patches].to_f
      when :data_patches then return HT.startup_of(o)[:data_patches]
      else return HT.per_frame(o, r[:key])
      end
    end

    def paint_description(base, top, c)
      title, text, key, pills = description
      paint_description_box(base, top, c, title, text, key, pills || [])
    end

    # [title, text, what its scrolling follows, pills]
    def description
      e = entry_at
      return [@mode == :sessions ? _INTL("Timing Profiler") : _INTL("Mod Timings"), empty_text, :"empty_#{@mode}"] unless e
      r = @focus == :list ? current : nil
      if @mode == :sessions
        return [e["name"], session_text(e), e, session_pills(e)] unless r
        return [r[:label], section_text(r, e), r, row_pills(r[:data]["slow"].to_i, r[:owner])]
      end
      return [e, owner_text(e), e] unless r
      return [_INTL(r[:label]), stat_text(r), r] if r[:kind] == :stat
      return [r[:label], hook_text(r), r, row_pills(r[:stats]["slow"].to_i, r[:owner])]
    end

    # Right to left: the owner last on the line, its slow count before it.
    def row_pills(slow, owner)
      out = []
      rgb = Color.new(*owner_rgb(owner))
      out << [PF.utf8(owner.to_s).upcase, dark_fill(rgb), rgb] unless owner.to_s.empty? || owner == "All"
      out << [_INTL("{1} SLOW", slow), dark_fill(palette[:red]), palette[:red]] if slow > 0
      return out
    end

    def session_pills(s)
      slow = s["sections"][Reloaded::Profiler::FRAME_WORK]
      n = slow ? slow["slow"].to_i : 0
      out = []
      out << [_INTL("{1} SLOW", n), dark_fill(palette[:red]), palette[:red]] if n > 0
      out << [_INTL("EARLIER"), c_pill, palette[:txt]] if s["earlier"]
      return out
    end

    def c_pill
      return palette[:pill]
    end

    #--------------------------------------------------------------------------
    # Words
    #--------------------------------------------------------------------------
    def empty_line
      return @mode == :sessions ? _INTL("No sessions yet.") : _INTL("Nothing timed yet.")
    end

    def empty_text
      unless PR.on?
        return _INTL("The Timing Profiler is Off. Switch it On in Kanto Reloaded > Timing Profiler (it needs KIF's DEBUG option), then play: Each battle, map load, menu and save becomes a session here.")
      end
      return _INTL("Play a little: Each battle, map load, menu and save becomes a session here.") if @mode == :sessions
      return _INTL("Mod Timings is Off (Kanto Reloaded > Timing Profiler - Time).") unless PR.setting(:mod_timings)
      return _INTL("Play a little: Each mod's hooks are timed as they run.")
    end

    def session_text(s)
      limit = (s["slow_limit"] || PR.slow_limit).to_f
      what = KIND_WORDS[s["kind"]] || s["kind"].to_s.capitalize
      head = if s["kind"] == "map" then _INTL("{1}, from {2}", s["name"], s["where"] || "?")
             elsif s["where"] then _INTL("{1}: {2}, on {3}", what, s["name"], s["where"])
             else _INTL("{1}: {2}", what, s["name"])
             end
      fw = s["sections"][Reloaded::Profiler::FRAME_WORK]
      parts = [_INTL("{1}. {2} long, {3} of it work (the rest waiting for the next frame); {4} frames, {5} slow (over {6} ms).",
                     head, seconds(s["elapsed"]), seconds(s["work"]), s["frames"].to_i, fw ? fw["slow"].to_i : 0, ms(limit))]
      worst = s["sections"].reject { |l, _| l == Reloaded::Profiler::FRAME_WORK }.max_by { |_l, x| x["peak"].to_f }
      parts << _INTL("Slowest: {1}, {2} ms.", worst[0], ms(worst[1]["peak"])) if worst
      info = (s["info"] || {}).reject { |_k, v| v.to_s.empty? }.map { |k, v| "#{k}: #{v}" }
      parts << info.join(", ") + "." unless info.empty?
      parts << _INTL("From an earlier time the game ran.") if s["earlier"]
      parts << _INTL("It stopped: {1}", s["error"]) if s["error"]
      return parts.join(" ")
    end

    def section_text(r, s)
      x = r[:data]
      calls = x["calls"].to_i
      parts = []
      parts << x["about"] if x["about"]
      if r[:label] == Reloaded::Profiler::FRAME_WORK
        parts << _INTL("Every frame's work while the session ran: {1} frames, {2} ms at worst, {3} ms on average.",
                       calls, ms(x["peak"]), ms(x["total"].to_f / [calls, 1].max))
      elsif calls == 1
        parts << _INTL("Called once: {1} ms.", ms(x["total"]))
      else
        parts << _INTL("Called {1} times: {2} ms at worst in one frame, {3} ms on average, {4} ms in all.",
                       calls, ms(x["peak"]), ms(x["total"].to_f / calls), ms(x["total"]))
      end
      parts << slow_words(x["slow"].to_i, calls, (s["slow_limit"] || PR.slow_limit).to_f)
      parts << _INTL("Inside {1}: Sections overlap, so don't add them together.", x["inside"]) if x["inside"]
      return parts.join(" ")
    end

    def owner_text(o)
      map = HT.per_frame(o, :map)
      battle = HT.per_frame(o, :battle)
      frames = _INTL("{1} ms a frame on the map, {2} ms in battle", map ? ms(map) : "0", battle ? ms(battle) : "0")
      if o == HT::GAME_LABEL
        return _INTL("The game's own work (PIF, KIF and EBDX's code that isn't a hook): Its frames' work less every mod's hooks. {1}.", frames)
      end
      st = HT.startup_of(o)
      start = st[:scripts] || st[:data_patches] ? _INTL("Started in {1} ms. ", ms(st[:scripts].to_f + st[:data_patches].to_f)) : ""
      count = HT.hooks(o).length
      return _INTL("{1}{2}: {3} hooks timed; {4}.", start, o, count, frames)
    end

    def stat_text(r)
      o = r[:owner]
      st = HT.startup_of(o)
      case r[:key]
      when :startup
        if o == Reloaded::Profiler::Owners::KR
          return _INTL("Kanto Reloaded took {1} ms to load its files and start its systems, and {2} ms more on Data Patches.",
                       ms(st[:scripts]), ms(st[:data_patches]))
        end
        return _INTL("{1}'s scripts took {2} ms to load.", o, ms(st[:scripts])) if st[:scripts]
        return _INTL("{1} loads before Kanto Reloaded, so its scripts couldn't be timed (only mods after Kanto Reloaded in the load order are).", o)
      when :data_patches
        return _INTL("{1} has no data patches.", o) unless st[:data_patches]
        if o == Reloaded::Profiler::Owners::KR
          return _INTL("{1} ms: Kanto Reloaded's own patches, and making every mod's patched data into the game's.", ms(st[:data_patches]))
        end
        return _INTL("Reading and applying {1}'s data patches took {2} ms.", o, ms(st[:data_patches]))
      else
        where = r[:key] == :map ? _INTL("on the map") : _INTL("in battle")
        frames = HT.frames(r[:key])
        return _INTL("Nothing has been timed {1} yet.", where) if frames.zero?
        value = HT.per_frame(o, r[:key]).to_f
        return _INTL("None of {1}'s hooks ran {2} ({3} frames).", o, where, frames) if value == 0.0 && o != HT::GAME_LABEL
        return _INTL("{1}: {2} ms a frame on average {3}, over {4} frames.", o, ms(value), where, frames)
      end
    end

    def hook_text(r)
      st = r[:stats]
      calls = st["calls"].to_i
      where = st["where"] ? _INTL(" (in {1})", st["where"]) : ""
      text = if calls == 1
               _INTL("{1}'s hook on {2}: Called once, {3} ms{4}.", r[:owner], r[:label], ms(st["peak"]), where)
             else
               _INTL("{1}'s hook on {2}: {3} ms at worst{4}, {5} ms on average over {6} calls.",
                     r[:owner], r[:label], ms(st["peak"]), where, ms(st["total"].to_f / calls), calls)
             end
      words = slow_words(st["slow"].to_i, calls, PR.slow_limit)
      return words.empty? ? text : "#{text} #{words}"
    end

    # "That's over 33.3 ms: a slow frame." / "2 of them over 33.3 ms." / ""
    def slow_words(slow, calls, limit)
      return "" if slow <= 0
      return _INTL("That's over {1} ms: A slow frame.", ms(limit)) if calls == 1
      return _INTL("{1} of them over {2} ms.", slow, ms(limit))
    end

    # A hook's name in its row: Kanto Reloaded's by its id ("Controls
    # Extra Actions"), others' by the method ("pbStartBattle"); the
    # description's title has it all.
    def short_label(label)
      label = label.to_s
      return $1.split("_").map(&:capitalize).join(" ") if label =~ /\(([a-z0-9_]+)\)\z/
      return label.split(/[#.]/).last if label =~ /[#.]/
      return label
    end

    #--------------------------------------------------------------------------
    # Numbers and colours
    #--------------------------------------------------------------------------
    # "38.6", "0.90", "412" (milliseconds, from seconds)
    def ms(seconds)
      v = seconds.to_f * 1000
      return format("%.0f", v) if v >= 100
      return format("%.1f", v) if v >= 1
      return format("%.2f", v)
    end

    def seconds(value)
      v = value.to_f
      return _INTL("{1} s", format("%.1f", v)) if v >= 1
      return _INTL("{1} ms", ms(v))
    end

    def severity_colour(seconds, c)
      case PR.severity(seconds)
      when :red then return palette[:red]
      when :amber then return palette[:amber]
      end
      return palette[:green]
    end

    def status_colour(status)
      case status.to_s
      when "red" then return palette[:red]
      when "amber" then return palette[:amber]
      end
      return palette[:green]
    end

    # A mod's colour: its own (Kanto Reloaded, EBDX, the game), else by its
    # place among the mods.
    def owner_rgb(owner)
      return OWNER_RGB[owner.to_s] if OWNER_RGB[owner.to_s]
      list = owners - OWNER_RGB.keys
      return tile_colour(list.index(owner.to_s) || owner.to_s.sum)
    end

    def hint_pairs
      back = button(:B)
      if @focus == :side || rows.empty?
        word = @mode == :sessions ? _INTL("Session") : _INTL("Mod")
        return [[back, _INTL("Close"), :back]] if entries.empty?
        return [[:ud, word], [:lr, _INTL("Open"), :open_list], [back, _INTL("Close"), :back]]
      end
      if @mode == :sessions
        owner = @owner || _INTL("All")
        return [[:ud, _INTL("Select")], [button(:X), _INTL("Sort: {1}", _INTL(SORT_NAMES[SORTS[@sort]])), :sort_next],
                [button(:A), _INTL("Owner: {1}", owner), :owner_next], [back, _INTL("Sessions"), :back]]
      end
      out = [[:ud, _INTL("Select")]]
      r = current
      out << [button(:C), _INTL("Open in Sessions"), :open_in_sessions] if r && r[:kind] == :hook && r[:stats]["session"]
      return out + [[back, _INTL("Mods"), :back]]
    end
  end
end
