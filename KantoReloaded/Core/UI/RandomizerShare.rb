# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Randomizer's Settings Code and Presets
#==============================================================================
# His picks (2026-10-25, design sheets rnd-sub-code and rnd-sub-presets):
#
#   Settings Code   the Code Card: one popup on the Seed section's Settings
#                   Code row. The whole code in a well, coloured by part
#                   (KIFR2 and the bans dim, the seed bright, the settings in
#                   text colour, Kanto Reloaded's part in the accent), SEED
#                   and KANTO RELOADED PART badges, Copy Code, Paste Code,
#                   Close. Paste asks Load These Settings? with every change
#                   old to new (Load first: the changes only wait for
#                   Randomize Now). Where the clipboard can't be used,
#                   Couldn't Copy shows the code to write down.
#   Presets         Menu With Headings (R1, the title bar's Presets): cody's
#                   six built-ins, then YOUR PRESETS (his files in
#                   Randomizer/Presets) and Save as Preset (a name typed in
#                   the title bar). A built-in asks Load <name>? with what
#                   changes; a file opens Load, Copy Code and Delete.
#
# The codes, files and built-ins are cody's (KIF::Rand); Kanto Reloaded's
# part of a code goes with them (Randomizer.rb's hooks).
#==============================================================================

return unless defined?(Reloaded::RandomizerScreen)

module Reloaded
  # Drawing pieces the Randomizer's popups and screens share
  module RandomizerDraw
    P = Reloaded::Pixel
    CODE_LINES = 14            # the most lines of code a card shows

    module_function

    def mix(a, b, t)
      return Reloaded::Palette.mix(a, b, t)
    end

    # A badge's or patch's soft fill of a colour
    def tone_fill(c, col, k = nil)
      return mix(c[:panel2], col, k || (c[:light] ? 0.22 : 0.3))
    end

    # A sunk, filled box (no frame line)
    def well(b, c, x0, y0, x1, y1)
      P.ui.rbox(b, x0, y0, x1, y1, 5, c[:light] ? mix(c[:panel2], c[:line], 0.35) : mix(c[:dark], c[:panel2], 0.25))
    end

    # The settings code a colour per part: KIFR2 and the bans dim, the seed
    # bright, the settings in text colour, Kanto Reloaded's part in its
    # accent
    def code_chars(c, code)
      tones = [c[:dim], c[:strong], c[:txt], c[:txt], c[:txt], c[:dim], c[:acc]]
      out = []
      code.to_s.split("-", -1).each_with_index do |part, i|
        out << ["-", c[:dim]] if i > 0
        part.each_char { |ch| out << [ch, tones[i] || c[:txt]] }
      end
      return out
    end

    # Lines of [text, colour] runs that fit width (a code has no spaces)
    def code_lines(b, c, code, width)
      P.small_font(b)
      lines = [[]]
      w = 0
      code_chars(c, code).each do |ch, col|
        cw = b.text_size(ch).width
        if w + cw > width && !lines.last.empty?
          lines << []
          w = 0
        end
        lines.last << [ch, col]
        w += cw
      end
      return lines.map { |ln| ln.chunk_while { |a, z| a[1] == z[1] }.map { |run| [run.map(&:first).join, run[0][1]] } }
    end

    # [text, colour] runs from x (:arrow: a small arrow); the width used
    def runs(b, x, y, h, segs)
      x0 = x
      segs.each do |t, col|
        if t == :arrow
          P.ui.tri(b, x + 2, y + h / 2 - 3, :r, col, 3)
          x += 11
        else
          x += P.small(b, x, y, 400, h, t.to_s, col)
        end
      end
      return x - x0
    end

    def runs_width(b, segs)
      P.small_font(b)
      return segs.sum { |t, _c| t == :arrow ? 11 : b.text_size(t.to_s).width }
    end

    # Badges in a row, centred on cx (:right: ending at cx)
    def pill_row(b, cx, y, list, align = :centre)
      widths = list.map { |l, _f, _c| P.width(P.pf::TINY, l) + 12 }
      total = widths.sum + 6 * (list.length - 1)
      x = align == :right ? cx - total : cx - total / 2
      list.each_with_index do |(l, f, col), i|
        P.pill(b, x, y, l, f, col, false)
        x += widths[i] + 6
      end
    end

    # old to new lines for a question (at most max, then "And N More")
    def change_lines(c, changes, max = 6)
      lines = changes.first(max).map { |n, a, z| [[n.to_s + ": ", c[:dim]], [a.to_s, c[:txt]], [:arrow, c[:dim]], [z.to_s, c[:amber]]] }
      more = changes.length - max
      lines << [[more == 1 ? _INTL("And 1 More") : _INTL("And {1} More", more), c[:dim]]] if more > 0
      return lines
    end
  end

  class RandomizerScreen
    RD = Reloaded::RandomizerDraw
    BAN_NAMES = { :pokemon => "Banned Pokémon", :moves => "Banned Moves", :abilities => "Banned Abilities",
                  :items => "Banned Items" }.freeze
    PRESETS_LIST_H = 236       # the Presets popup's list, before it scrolls

    # The hint line while a popup of the Randomizer's shows
    def with_hints(pairs)
      before = @popup_hints
      @popup_hints = pairs
      refresh
      return yield
    ensure
      @popup_hints = before
      refresh
    end

    private

    def ask_hints
      return [[:lr, _INTL("Choose")], [button(:C), _INTL("Press")], [button(:B), _INTL("Cancel")]]
    end

    def rd_rand
      return ::KIF::Rand
    end

    #--------------------------------------------------------------------------
    # What a code or a preset changes: [[name, now, then], ...]
    #--------------------------------------------------------------------------
    # A setting's name and values as the rows show them
    def setting_info(key)
      @setting_info ||= begin
        h = {}
        (@rows || {}).each_value do |list|
          list.each do |r|
            o = r.opt
            next unless o && o.respond_to?(:rkey) && o.respond_to?(:values)
            h[o.rkey] = [(o.respond_to?(:full) && o.full) || RW.name_of(o), o.values]
          end
        end
        h
      end
      hit = @setting_info[key]
      return hit if hit
      name, vals = (rd_rand::LABELS[key] rescue nil)
      return [RW.title(name || key.to_s), (vals || []).map { |v| RW.title(v) }]
    end

    def setting_value(key, v)
      _n, vals = setting_info(key)
      return (vals[v.to_i] || v).to_s
    end

    def setting_change(out, key, now, after)
      return if now == after
      out << [setting_info(key)[0], setting_value(key, now), setting_value(key, after)]
    end

    # The Learnsets row is cody's Moves Follow Type and Kanto Reloaded's
    # Random together
    def learnsets_change(out, follow, random)
      after = random == 1 ? 2 : (follow == 1 ? 1 : 0)
      setting_change(out, :kr_learnsets, Reloaded::Randomizer.learnsets, after)
    end

    # The Item Mode row is cody's Item Mode (his Dynamic: By Spot) and
    # Kanto Reloaded's Dynamic together
    def item_mode_change(out, mode, dynamic)
      after = mode == 1 ? (dynamic == 1 ? 2 : 1) : 0
      setting_change(out, :kr_items_dynamic, Reloaded::Randomizer.item_mode, after)
    end

    JOINED_KEYS = [:moves_follow, :item_mode, :kr_learnsets, :kr_items_dynamic].freeze

    def strength_change(out, key, after)
      now = rd_rand.get(key)
      return if now == after
      out << [key == :wild_bst ? _INTL("Wild Strength Range") : _INTL("Trainer Strength Range"), now.to_s, after.to_s]
    end

    # nil when it isn't a settings code
    def code_changes(code)
      r = rd_rand
      split = Reloaded::Randomizer.split_code(code)
      res = split && r.parse_code(split[0])
      return nil unless res
      out = []
      out << [_INTL("Seed"), r.format_seed, r.format_seed(res[0])] if res[0] != r.seed
      res[1].each do |k, v|
        next if JOINED_KEYS.include?(k)
        next strength_change(out, k, v) if k == :wild_bst || k == :trainer_bst
        setting_change(out, k, r.get(k), v)
      end
      kr = split[1] || Reloaded::Randomizer::KEYS
      learnsets_change(out, res[1][:moves_follow].to_i, kr[:kr_learnsets].to_i)
      item_mode_change(out, res[1][:item_mode].to_i, kr[:kr_items_dynamic].to_i)
      Reloaded::Randomizer::KEYS.each_key do |k|
        next if JOINED_KEYS.include?(k)
        setting_change(out, k, Reloaded::Randomizer.get(k), kr[k].to_i)
      end
      (res[2] || {}).each do |kind, list|
        now = r.ban_list(kind)
        after = (list == :default ? r.default_item_bans : list).uniq.sort_by(&:to_s)
        out << [_INTL(BAN_NAMES[kind] || kind.to_s), now.length.to_s, after.length.to_s] if now != after
      end
      return out
    end

    # cody's built-in: every setting to its default, then the preset's (the
    # seed, the bans and the Strength Ranges stay; Kanto Reloaded's too)
    def builtin_changes(i)
      r = rd_rand
      _n, _d, vals = r::BUILTIN_PRESETS[i]
      out = []
      r.code_enums.each do |key, _k, _m|
        next if JOINED_KEYS.include?(key)
        setting_change(out, key, r.get(key), vals.key?(key) ? vals[key] : (r::DATA_DEFAULTS[key] || 0))
      end
      learnsets_change(out, vals[:moves_follow].to_i, Reloaded::Randomizer.get(:kr_learnsets))
      item_mode_change(out, vals[:item_mode].to_i, Reloaded::Randomizer.get(:kr_items_dynamic))
      return out
    end

    def after_share_change
      @setting_info = nil
      after_change
    end

    #--------------------------------------------------------------------------
    # The Code Card
    #--------------------------------------------------------------------------
    def code_card
      pbPlayDecisionSE
      choice = 0
      loop do
        code = rd_rand.settings_code
        choice = with_hints(ask_hints.tap { |h| h[2] = [button(:B), _INTL("Close")] }) do
          Reloaded::Dialogs.drawn(self, 3, choice) { |b, c, i| draw_code_card(b, c, code, _INTL("Settings Code"), nil, [_INTL("Copy Code"), _INTL("Paste Code"), _INTL("Close")], i) }
        end
        case choice
        when 0 then copy_code(code, _INTL("Copy Code"))
        when 1 then paste_code
        else break
        end
      end
      refresh
    end

    # Copied, or the code on a card to write down
    def copy_code(code, title)
      if !Reloaded::Runtime.phone? && Reloaded::ShareCodes.copy(code)
        Reloaded::Dialogs.notice(self, title, _INTL("Copied: Anyone who pastes it gets the same game."))
        return
      end
      with_hints([[button(:C), _INTL("OK")]]) do
        Reloaded::Dialogs.drawn(self, 1, 0) do |b, c, i|
          draw_code_card(b, c, code, _INTL("Couldn't Copy"), _INTL("No clipboard here: Write it down, or take a screenshot."), [_INTL("OK")], i)
        end
      end
    end

    def paste_code
      text = Reloaded::ShareCodes.clipboard.to_s.strip
      changes = code_changes(text)
      unless changes
        Reloaded::Dialogs.notice(self, _INTL("Paste Code"),
          _INTL("The clipboard doesn't hold a settings code: One starts with {1}.", rd_rand::CODE_PREFIX))
        return
      end
      if changes.empty?
        Reloaded::Dialogs.notice(self, _INTL("Paste Code"), _INTL("Those are your settings now: Nothing changes."))
        return
      end
      return unless ask_load(_INTL("Load These Settings?"), changes)
      after_share_change if rd_rand.apply_code(text)
    end

    # Load (first) or Cancel, with the seed and every change old to new
    def ask_load(title, changes, text = nil)
      seed = changes.find { |n, _a, _z| n == _INTL("Seed") }
      rest = changes.reject { |n, _a, _z| n == _INTL("Seed") }
      text ||= if seed
                 rest.length == 1 ? _INTL("Seed {1} and 1 more change. It waits for Randomize Now.", seed[2]) :
                                    _INTL("Seed {1} and {2} more changes. They wait for Randomize Now.", seed[2], rest.length)
               else
                 _INTL("Seed {1} stays. The changes wait for Randomize Now.", rd_rand.format_seed)
               end
      text = text.sub(/ ?(They|It) waits? for Randomize Now\./, "") if intro?      # (the intro randomizes once)
      c = palette
      lines = RD.change_lines(c, rest, rest.length > 6 ? 5 : 6)     # (six lines, "And N More" the last)
      choice = with_hints(ask_hints) do
        Reloaded::Dialogs.drawn(self, 2, 0) do |b, cc, i|
          RandomizerScreen.draw_question(b, cc, title, text, lines, [_INTL("Load"), _INTL("Cancel")], i)
        end
      end
      return choice == 0
    end

    def draw_code_card(b, c, code, title, note, labels, choice)
      dl = Reloaded::Dialogs
      w = 448
      lines = RD.code_lines(b, c, code, w - 44)
      cut = lines.length > RD::CODE_LINES
      lines = lines.first(RD::CODE_LINES)
      well_h = lines.length * 16 + 10
      h = 40 + 22 + well_h + 8 + 18 + 44
      x = (dl::SCREEN_W - w) / 2
      y = (dl::SCREEN_H - h) / 2
      dl.frame(b, c, x, y, w, h, title)
      parts = code.to_s.split("-")
      list = [[_INTL("SEED {1}", rd_rand.format_seed(parts[1].to_s)), c[:pill], c[:txt]]]
      list << [_INTL("KANTO RELOADED PART"), RD.tone_fill(c, c[:acc]), c[:acc]] if parts.length == 7
      RD.pill_row(b, x + w / 2, y + 42, list)
      wy = y + 62
      RD.well(b, c, x + 14, wy, x + w - 14, wy + well_h)
      lines.each_with_index { |ln, k| RD.runs(b, x + 22, wy + 5 + k * 16, 16, ln) }
      note ||= cut ? _INTL("Too long to show it all: Copy Code copies the whole of it.") : _INTL("Anyone who pastes it gets the same game.")
      P.small(b, x, wy + well_h + 5, w, 18, note, c[:dim], 2)
      dl.button_row(b, c, x, w, y + h - 34, labels, choice)
    end

    #--------------------------------------------------------------------------
    # Presets: Menu With Headings
    #--------------------------------------------------------------------------
    def open_presets
      pbPlayDecisionSE
      sel = nil
      loop do
        list = preset_rows
        sel = preset_pick(list, sel)
        break unless sel
        kind, name, extra = list[sel]
        case kind
        when :builtin then load_builtin(extra)
        when :file then preset_file(name)
        when :save then save_preset
        end
      end
      refresh
      return nil
    end

    # [[:head, label] or [:builtin, name, index] or [:file, name] or [:save, label]]
    def preset_rows
      r = rd_rand
      out = [[:head, _INTL("Built-in")]]
      r::BUILTIN_PRESETS.each_with_index { |(n, _d, _v), i| out << [:builtin, _INTL(n), i] }
      out << [:head, _INTL("Your Presets")]
      (r.preset_names rescue []).each { |n| out << [:file, n] }
      out << [:save, _INTL("Save as Preset")]
      return out
    end

    def presets_folder
      return Reloaded::Runtime.phone? ? _INTL("the save folder") : _INTL("the {1} folder", rd_rand::PRESET_DIR)
    end

    # A preset file's settings code (the first line that is one), or nil
    def preset_code(name)
      path = File.join(rd_rand.preset_dir, "#{name}.txt")
      return nil unless File.file?(path)
      lines = File.read(path, :mode => "rb").force_encoding("UTF-8").scrub.split(/\r?\n/).map(&:strip)
      return lines.find { |l| l.start_with?(rd_rand::CODE_PREFIX) || l.start_with?(rd_rand::CODE_PREFIX_V1) }
    rescue StandardError
      return nil
    end

    # What the description area says about a row (coloured words)
    def preset_desc(c, row)
      kind, name, extra = row
      case kind
      when :builtin
        return [[_INTL(rd_rand::BUILTIN_PRESETS[extra][1]), c[:txt]]]
      when :file
        code = preset_code(name)
        return [[_INTL("This file can't be read as a settings code."), c[:red]]] unless code
        n = (code_changes(code) || []).length
        seed = rd_rand.format_seed(code.split("-")[1].to_s)
        return [[_INTL("Yours, in {1}. ", presets_folder), c[:dim]], [_INTL("Seed {1}", seed), c[:txt], :glue],
                [n == 1 ? _INTL(", 1 change from now.") : _INTL(", {1} changes from now.", n), c[:dim]]]
      when :save
        return [[_INTL("Keeps these settings as a file in {1}, to load later or share.", presets_folder), c[:txt]]]
      end
      return []
    end

    # The list until a row is picked (its index) or B (nil); headings are
    # skipped over
    def preset_pick(list, sel)
      picks = list.each_index.reject { |i| list[i][0] == :head }
      sel = picks.include?(sel) ? sel : picks[1] || picks[0]
      @preset_scroll = 0
      hints = [[:ud, _INTL("Choose")], [button(:C), _INTL("Pick")], [button(:B), _INTL("Close")]]
      with_hints(hints) do
        redraw = true
        loop do
          if redraw
            draw_presets(overlay, palette, list, sel)
            redraw = false
          end
          Graphics.update
          Input.update
          update_frame
          pt = Reloaded::Pointer
          k = picks.index(sel)
          if pt.moved? && (i = Reloaded::Dialogs.hit) && i != sel
            sel = i
            pbPlayCursorSE
            redraw = true
          end
          if pt.left? && (i = Reloaded::Dialogs.hit)
            pbPlayDecisionSE
            overlay.clear
            return i
          elsif pt.right? || Input.trigger?(Input::BACK)
            pbPlayCancelSE
            overlay.clear
            return nil
          elsif pt.wheel != 0 || Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN)
            dir = pt.wheel != 0 ? pt.wheel : (Input.repeat?(Input::UP) ? -1 : 1)
            to = k + dir
            if to < 0 || to >= picks.length
              next unless Input.trigger?(Input::UP) || Input.trigger?(Input::DOWN)
              to %= picks.length
            end
            sel = picks[to]
            pbPlayCursorSE
            redraw = true
          elsif Input.trigger?(Input::USE)
            pbPlayDecisionSE
            overlay.clear
            return sel
          end
        end
      end
    end

    def preset_row_h(kind)
      return kind == :head ? 18 : 21
    end

    def draw_presets(b, c, list, sel)
      dl = Reloaded::Dialogs
      dl.send(:dim, b)
      w = 340
      ys = []
      total = 0
      list.each { |kind, *| ys << total; total += preset_row_h(kind) }
      list_h = [total, PRESETS_LIST_H].min
      # the selected row in view (with its heading when that's just above)
      top = ys[sel]
      top = ys[sel - 1] if sel > 0 && list[sel - 1][0] == :head
      @preset_scroll = top if top < @preset_scroll
      @preset_scroll = ys[sel] + 21 - list_h if ys[sel] + 21 > @preset_scroll + list_h
      @preset_scroll = [[@preset_scroll, total - list_h].min, 0].max
      h = 40 + list_h + 10 + 3 * 16 + 10
      x = (dl::SCREEN_W - w) / 2
      y = (dl::SCREEN_H - h) / 2
      dl.send(:panel, b, c, x, y, w, h)
      dl.send(:title_bar, b, c, x, y, w, _INTL("Presets"))
      hits = []
      list.each_with_index do |(kind, name, _e), i|
        rh = preset_row_h(kind)
        ry = y + 38 + ys[i] - @preset_scroll
        next if ys[i] < @preset_scroll || ys[i] + rh > @preset_scroll + list_h
        if kind == :head
          P.heading(b, x + 14, x + w - 14, ry + 4, name, c[:head], c[:line])
          next
        end
        hits << [i, x + 6, ry, x + w - 6, ry + 19]
        dl.send(:cursor_row, b, c, x + 6, ry, x + w - 6, ry + 19) if i == sel
        P.text(b, x + 18, ry, w - 36, 20, P.pf.fit(P.pf::TEXT, name.to_s, w - 36), kind == :save ? c[:acc] : c[:opt])
      end
      dl.hits = hits
      P.ui.tri(b, x + w / 2 - 4, y + 36, :u, c[:dim], 3) if @preset_scroll > 0
      P.ui.tri(b, x + w / 2 - 4, y + 38 + list_h, :d, c[:dim], 3) if @preset_scroll + list_h < total
      dy = y + 38 + list_h + 4
      b.fill_rect(x + 10, dy, w - 20, 1, c[:line])
      rich_left(b, x + 14, dy + 5, w - 28, 16, preset_desc(c, list[sel]), 3)
    end

    def load_builtin(i)
      name, _d, _v = rd_rand::BUILTIN_PRESETS[i]
      changes = builtin_changes(i)
      text = _INTL("The rest go to their defaults; the seed, bans and Strength Ranges stay. It all waits for Randomize Now.")
      return unless ask_load(_INTL("Load {1}?", _INTL(name)), changes, text)
      after_share_change if rd_rand.load_builtin(i)
    end

    # A file of yours: Load, Copy Code, Delete
    def preset_file(name)
      code = preset_code(name)
      labels = [_INTL("Load"), _INTL("Copy Code"), _INTL("Delete")]
      descs = [_INTL("Its settings, waiting for Randomize Now."), _INTL("Its settings code, to share."),
               _INTL("The file goes from {1}.", presets_folder)]
      case Reloaded::Dialogs.menu(self, name, labels, descs)
      when 0
        changes = code && code_changes(code)
        return Reloaded::Dialogs.notice(self, name, _INTL("That preset couldn't be read.")) unless changes
        return Reloaded::Dialogs.notice(self, name, _INTL("Those are your settings now: Nothing changes.")) if changes.empty?
        return unless ask_load(_INTL("Load {1}?", name), changes)
        rd_rand.load_preset(name) ? after_share_change : Reloaded::Dialogs.notice(self, name, _INTL("That preset couldn't be read."))
      when 1
        return Reloaded::Dialogs.notice(self, name, _INTL("That preset couldn't be read.")) unless code
        copy_code(code, _INTL("Copy Code"))
      when 2
        return unless Reloaded::Dialogs.confirm(self, _INTL("Delete {1}?", name),
                                                 _INTL("The file goes from {1}. This can't be undone.", presets_folder),
                                                 _INTL("Delete"), _INTL("Keep"), false)
        begin
          File.delete(File.join(rd_rand.preset_dir, "#{name}.txt"))
        rescue StandardError => e
          Reloaded::Log.exception("A Randomizer preset couldn't be deleted", e, :randomizer)
          Reloaded::Dialogs.notice(self, name, _INTL("That preset couldn't be deleted."))
        end
      end
    end

    # The name typed into the title bar (as Kanto Reloaded's Presets
    # renames a slot)
    def save_preset
      text, how = run_entry(:preset_name, _INTL("Type a Name"), "", 30, :prompt => _INTL("Preset Name"))
      refresh
      return unless how == :enter
      name = text.to_s.gsub(/[\\\/:*?"<>|]/, "").strip
      return if name.empty?
      if (rd_rand.preset_names rescue []).include?(name)
        return unless Reloaded::Dialogs.confirm(self, _INTL("Replace {1}?", name), _INTL("A preset called {1} already exists.", name),
                                                 _INTL("Replace"), _INTL("Keep"), false)
      end
      if rd_rand.save_preset(name)
        Reloaded::Dialogs.notice(self, _INTL("Save as Preset"), _INTL("Saved: {1} is in {2}.", name, presets_folder))
      else
        Reloaded::Dialogs.notice(self, _INTL("Save as Preset"), _INTL("That preset couldn't be saved."))
      end
    end
  end
end
