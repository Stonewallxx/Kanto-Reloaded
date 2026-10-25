# encoding: utf-8
#==============================================================================
# Kanto Reloaded: New Game Setup's popups
#==============================================================================
# His picks (2026-10-25), drawn over the step they open from:
#
#   From a Preset         the built-in presets, then your own (YOURS, their
#                         mode's pill right under it); A uses one, Square
#                         deletes one of yours
#   Enter a Share Code    the code's field (Triangle pastes; A types, a
#                         controller's A opening the naming screen), its Run
#                         ID and what it sets, Use This Run / Cancel
#   Replace Your Setup?   what a preset or code would change, Replace /
#                         Keep Mine (Keep Mine first)
#   Save as Preset        a name typed straight in, the slot it goes in
#   Custom Starter        Fused On / Off, the Pokémon (Big Icons), Use /
#                         Cancel
#
# And All Per-Save Settings: the improved KIF Settings with only this save's
# rows (KIF's Modules left out, as their states are global; Difficulty left
# out, as Run Setup has its own row).
#==============================================================================

return unless defined?(Reloaded::NewGameScreen)

module Reloaded
  class NewGameScreen
    YOURS_RGB = [240, 200, 80].freeze
    PRESET_ROW = 44
    PRESET_SHOWN = 5
    @@species = nil

    private

    #--------------------------------------------------------------------------
    # From a Preset
    #--------------------------------------------------------------------------
    def preset_entries
      list = NG.builtin_presets.map { |p| p.merge("builtin" => true) }
      NG.user_presets.each do |p|
        m = NG::MODES.index((p["run"]["mode"] rescue nil)) || 0
        list << p.merge("tag" => ["YOURS", YOURS_RGB], "mode_tag" => [NG::MODE_NAMES[m].upcase, NG::MODE_RGB[m]])
      end
      return list
    end

    def from_preset
      pbPlayDecisionSE
      list = preset_entries
      i = 0
      top = 0
      loop do
        top = i if i < top
        top = i - PRESET_SHOWN + 1 if i >= top + PRESET_SHOWN
        @popup = [:presets, list, i, top]
        mine = !list[i]["builtin"]
        hints = [[:ud, _INTL("Choose")], [button(:C), _INTL("Use")]]
        hints << [button(:A), _INTL("Delete")] if mine
        hints << [button(:B), _INTL("Back")]
        @popup_hints = hints
        refresh
        act = nil
        loop do
          Graphics.update
          Input.update
          update_frame
          pt = Reloaded::Pointer
          if pt.moved? && (k = pt.hit(@popup_hits)) && k != i
            i = k
            pbPlayCursorSE
            break
          end
          if pt.left? && (k = pt.hit(@popup_hits))
            i = k
            act = :use
          elsif pt.right? || Input.trigger?(Input::BACK)
            act = :back
          elsif Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)
            dir = Input.repeat?(Input::DOWN) ? 1 : -1
            t = i + dir
            if t < 0 || t >= list.length
              next unless fresh?(dir)
              t %= list.length
            end
            i = t
            pbPlayCursorSE
            break
          elsif Input.trigger?(Input::USE)
            act = :use
          elsif Input.trigger?(Input::ACTION) && mine
            act = :delete
          end
          break if act
        end
        next unless act
        if act == :back
          pbPlayCancelSE
          break
        end
        p = list[i]
        if act == :delete
          pbPlayDecisionSE
          close_popup
          if delete_preset?(p)
            NG.delete_preset(p["slot"])
            list = preset_entries
            i = [i, list.length - 1].min
          end
          next
        end
        pbPlayDecisionSE
        run = p["builtin"] ? p["run"] : NG.user_run(p)
        close_popup
        break if use_run(run, p["name"])
      end
    ensure
      close_popup
      refresh
    end

    def delete_preset?(p)
      choice = DL.drawn(self, 2, 1) do |b, c, k|
        ask_box(b, c, _INTL("Delete {1}?", p["name"]), _INTL("It's gone from KIF's preset slots too."), [],
                [_INTL("Delete"), _INTL("Keep")], k)
      end
      return choice == 0
    end

    def paint_presets(b, c, list, i, top)
      w = 330
      shown = [list.length, PRESET_SHOWN].min
      h = 40 + shown * PRESET_ROW + 8 + 2 * 16 + 12
      x = (W - w) / 2
      y = (H - h) / 2
      DL.frame(b, c, x, y, w, h, _INTL("From a Preset"))
      @popup_hits = []
      list[top, shown].each_with_index do |p, k|
        idx = top + k
        ry = y + 40 + k * PRESET_ROW
        DL.send(:cursor_row, b, c, x + 6, ry, x + w - 6, ry + 42) if idx == i
        @popup_hits << [idx, x + 6, ry, x + w - 6, ry + 42]
        P.text(b, x + 18, ry + 1, 190, 22, p["builtin"] ? _INTL(p["name"]) : p["name"], c[:opt], PF::ROW)
        P.small(b, x + 18, ry + 24, w - 110, 16, p["sub"].to_s, c[:dim])
        badge(b, c, x + w - 16, ry + 5, _INTL(p["tag"][0]), p["tag"][1])
        badge(b, c, x + w - 16, ry + 23, _INTL(p["mode_tag"][0]), p["mode_tag"][1]) if p["mode_tag"]   # (his ask: the mode right under YOURS)
      end
      if list.length > shown
        P.ui.tri(b, x + w / 2 - 4, y + 34, :u, c[:dim], 4) if top > 0
        P.ui.tri(b, x + w / 2 - 4, y + 40 + shown * PRESET_ROW, :d, c[:dim], 4) if top + shown < list.length
      end
      ly = y + 40 + shown * PRESET_ROW + 4
      b.fill_rect(x + 10, ly, w - 20, 1, c[:line])
      [_INTL("A preset fills your Run Setup."), _INTL("Yours stay in KIF's preset slots.")].each_with_index do |ln, k|
        P.small(b, x, ly + 5 + k * 16, w, 16, ln, c[:dim], 2)
      end
    end

    # A run in place of the setup, asking first when that changes anything
    # you set; true when it was used
    def use_run(run, name)
      if NG.changed? && !replace?(run, name)
        refresh
        return false
      end
      NG.apply_run(run)
      @sel[0] = NG.mode_index
      refresh
      return true
    end

    def replace?(run, name)
      changes = NG.changes_to(run)
      return true if changes.empty?
      shown = changes.first(6)
      choice = with_hints([[:lr, _INTL("Choose")], [button(:C), _INTL("OK")], [button(:B), _INTL("Back")]]) do
        DL.drawn(self, 2, 1) do |b, c, k|
          lines = shown.map do |label, from, to, ft, tt|
            seg = [[label + ": ", c[:dim]]]
            seg += [[from, tone_colour(c, ft) || c[:txt]], [:arrow, c[:dim]]] if from
            seg << [to, tone_colour(c, tt) || c[:txt]]
          end
          lines << [[_INTL("And {1} More", changes.length - shown.length), c[:dim]]] if changes.length > shown.length
          ask_box(b, c, _INTL("Replace Your Setup?"), _INTL("{1} would change these.", name), lines,
                  [_INTL("Replace"), _INTL("Keep Mine")], k)
        end
      end
      return choice == 0
    end

    #--------------------------------------------------------------------------
    # Enter a Share Code
    #--------------------------------------------------------------------------
    def share_code
      pbPlayDecisionSE
      clip = Reloaded::ShareCodes.clipboard.to_s.strip
      st = { :text => clip.start_with?(NG::CODE_PREFIX) ? clip : "", :focus => :field, :choice => 0 }
      code_read(st)
      st[:focus] = :buttons if st[:payload]
      loop do
        @popup = [:code, st]
        @popup_hints = code_hints(st)
        refresh
        act = nil
        loop do
          Graphics.update
          Input.update
          update_frame
          pt = Reloaded::Pointer
          if pt.left?
            if (k = pt.hit(@popup_hits))
              if k == :field
                act = :type
              else
                st[:choice] = k
                act = :press
              end
            end
          elsif pt.right? || Input.trigger?(Input::BACK)
            act = :cancel
          elsif Input.trigger?(Input::X)                 # Triangle / Y: paste
            act = :paste
          elsif Input.trigger?(Input::DOWN) && st[:focus] == :field
            st[:focus] = :buttons
            act = :moved
          elsif Input.trigger?(Input::UP) && st[:focus] == :buttons
            st[:focus] = :field
            act = :moved
          elsif st[:focus] == :buttons && (Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT))
            st[:choice] = 1 - st[:choice]
            act = :moved
          elsif Input.trigger?(Input::USE)
            act = st[:focus] == :field ? :type : :press
          end
          break if act
        end
        case act
        when :moved
          pbPlayCursorSE
        when :paste
          pbPlayDecisionSE
          st[:text] = Reloaded::ShareCodes.clipboard.to_s.strip[0, NG::CODE_MAX + 1]
          code_read(st)
          st[:focus] = :buttons if st[:payload]
        when :type
          pbPlayDecisionSE
          text, how = Reloaded::TextEntry.run(self, _INTL("Paste or Type a Code"), st[:text], NG::CODE_MAX + 1, :prompt => _INTL("Share Code"))
          if how == :enter
            st[:text] = text
            code_read(st)
            st[:focus] = :buttons
          end
        when :cancel
          pbPlayCancelSE
          break
        when :press
          if st[:choice] == 1
            pbPlayCancelSE
            break
          end
          unless st[:payload]
            pbPlayBuzzerSE
            close_popup
            DL.notice(self, _INTL("Enter a Share Code"), NG.code_problem(st[:why]))
            next
          end
          pbPlayDecisionSE
          close_popup
          break if use_run(st[:payload], _INTL("Run {1}", NG.run_id(st[:payload])))
        end
      end
    ensure
      close_popup
      refresh
    end

    def code_read(st)
      st[:payload], st[:why] = st[:text].to_s.strip.empty? ? [nil, :empty] : NG.read_code(st[:text])
    end

    def code_hints(st)
      list = [[button(:X), _INTL("Paste")]]
      if st[:focus] == :field
        list << [button(:C), _INTL("Type")]
        list << [:ud, _INTL("Buttons")]
      else
        list << [:lr, _INTL("Choose")]
        list << [button(:C), _INTL("OK")]
      end
      return list << [button(:B), _INTL("Cancel")]
    end

    # What a code sets, in pairs: [[label, words, colour key or rgb]]
    def code_items(p, c)
      out = []
      m = NG::MODES.index(p["mode"]) || 0
      out << [_INTL("Mode"), _INTL(NG::MODE_NAMES[m]), PP.ink(c, NG::MODE_RGB[m])]
      rows = p["rows"] || {}
      NG.rows.each do |r|
        next unless r[:code]
        v = rows[r[:id].to_s]
        next if v.nil? || !NG.valid?(r, v)
        out << [_INTL(r[:name]), NG.words_for(r, v), tone_colour(c, r[:tone] ? r[:tone].call(v) : nil) || c[:txt]]
      end
      seed = p["rand"].to_s.split("-")[1]
      out << [_INTL("Seed"), "#{seed[0, 4]}-#{seed[4, 4]}", c[:txt]] if seed && seed.length >= 8
      names = NG.setting_names(p["kif"], p["kr"])
      out << [_INTL("Settings"), names.join(", "), c[:txt]] unless names.empty?
      return out
    end

    def paint_code(b, c, st)
      w = 400
      p = st[:payload]
      items = p ? code_items(p, c) : []
      lines = []
      items.first(6).each_slice(2) do |pair|
        line = []
        pair.each_with_index do |(label, words, col), k|
          line << [(k > 0 ? "   " : "") + label + ": ", c[:dim]]
          line << [words, col]
        end
        lines << line
      end
      lines << [[_INTL("And {1} More", items.length - 6), c[:dim]]] if items.length > 6
      lines = [[[st[:text].to_s.strip.empty? ? _INTL("Paste a code a friend copied from their Run Card.") : NG.code_problem(st[:why]), c[:dim]]]] if lines.empty?
      choice = st[:focus] == :buttons ? st[:choice] : -1
      x, y, w, _h = ask_box(b, c, _INTL("Enter a Share Code"), nil, lines, [_INTL("Use This Run"), _INTL("Cancel")], choice, w, 50)
      hits = DL.instance_variable_get(:@hits) || []
      field = Reloaded::TextEntry::State.new(_INTL("Paste or Type a Code"), st[:text], NG::CODE_MAX + 1)
      show = @entry || field
      fx = x + 16
      fw = w - 32
      DL.send(:cursor_row, b, c, fx - 4, y + 39, fx + fw + 4, y + 69) if st[:focus] == :field && !@entry   # the field has the focus
      Reloaded::TextEntry.draw_field(b, b, c, show, fx, y + 42, fw, 24)
      @popup_hits = hits + [[:field, fx, y + 42, fx + fw, y + 66]]
      id = p ? _INTL("Run ID {1}", NG.run_id(p)) : ""
      P.small(b, x, y + 70, w, 16, id, c[:dim], 2)
    end

    #--------------------------------------------------------------------------
    # Save as Preset
    #--------------------------------------------------------------------------
    def save_preset
      pbPlayDecisionSE
      slot = NG.free_slot
      slot = pick_slot if slot.nil?
      return refresh if slot.nil?
      name = "#{NG::MODE_NAMES[NG.mode_index]} #{LEVELS[NG.value(:difficulty).to_i]}"
      name = "Random #{LEVELS[NG.value(:difficulty).to_i]}" if name.length > 16     # (KIF's names: 16 letters)
      @popup = [:name, slot, name]
      text, how = Reloaded::TextEntry.run(self, _INTL("Type a Name"), name, 16, :prompt => _INTL("Preset Name?"))
      unless how == :enter && !text.to_s.strip.empty?
        close_popup
        return refresh
      end
      name = text.to_s.strip
      @popup = [:name, slot, name]
      choice = with_hints([[:lr, _INTL("Choose")], [button(:C), _INTL("OK")], [button(:B), _INTL("Cancel")]]) do
        DL.drawn(self, 2, 0) { |b, c, k| paint_name(b, c, slot, name, k) }
      end
      close_popup
      if choice == 0
        ok = NG.save_preset(slot, name)
        DL.notice(self, _INTL("Save as Preset"), ok ? _INTL("{1} is saved. It shows under From a Preset.", name) : _INTL("The preset couldn't be saved."))
      end
      refresh
    ensure
      close_popup
    end

    # Every slot full: which to save over
    def pick_slot
      d = ::KIF::Presets.data
      labels = Array.new(::KIF::Presets::SLOTS) { |i| d[:names][i].to_s }
      descs = Array.new(::KIF::Presets::SLOTS) { _INTL("Every slot is in use: This one is saved over.") }
      return DL.menu(self, _INTL("Save Over Which?"), labels, descs)
    end

    def paint_name(b, c, slot, name, choice = -1)
      words = _INTL("Goes in Slot {1}. It Shows Under From a Preset.", slot + 1)
      x, y, w, _h = ask_box(b, c, _INTL("Save as Preset"), nil, [[[words, c[:dim]]]], [_INTL("Save"), _INTL("Cancel")], choice, 360, 34)
      st = @entry || Reloaded::TextEntry::State.new(_INTL("Type a Name"), name, 16)
      Reloaded::TextEntry.draw_field(b, b, c, st, x + 16, y + 44, w - 32, 26)
    end

    #--------------------------------------------------------------------------
    # Custom Starter
    #--------------------------------------------------------------------------
    # True when picked (Use)
    def custom_starter
      pbPlayDecisionSE
      cu = NG.plan["custom"] || {}
      st = { :fused => cu["fused"] ? true : false, :body => cu["body"], :head => cu["head"], :focus => 1, :choice => 0 }
      result = false
      loop do
        @popup = [:starter, st]
        @popup_hints = [[:ud, _INTL("Choose")],
                        st[:focus] == 0 ? [:lr, _INTL("Change")] : (st[:focus] == 3 ? [:lr, _INTL("Choose")] : [button(:C), _INTL("Pick a Pokémon")]),
                        [button(:B), _INTL("Cancel")]]
        refresh
        act = nil
        loop do
          Graphics.update
          Input.update
          update_frame
          pt = Reloaded::Pointer
          if pt.left? && (k = pt.hit(@popup_hits))
            if k.is_a?(Integer)
              st[:focus] = 3
              st[:choice] = k
              act = :press
            else
              st[:focus] = { :fused => 0, :body => 1, :head => 2 }[k]
              act = :press
            end
          elsif pt.right? || Input.trigger?(Input::BACK)
            act = :cancel
          elsif Input.trigger?(Input::DOWN) || Input.trigger?(Input::UP)
            dir = Input.trigger?(Input::DOWN) ? 1 : -1
            stops = [0, 1, 3]                       # (Head is beside Body: Left / Right)
            at = stops.index(st[:focus] == 2 ? 1 : st[:focus]) || 0
            st[:focus] = stops[(at + dir) % stops.length]
            act = :moved
          elsif Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)
            case st[:focus]
            when 0 then st[:fused] = !st[:fused]
            when 1, 2 then st[:focus] = st[:fused] ? 3 - st[:focus] : 1
            when 3 then st[:choice] = 1 - st[:choice]
            end
            act = :moved
          elsif Input.trigger?(Input::USE)
            act = :press
          end
          break if act
        end
        case act
        when :moved then pbPlayCursorSE
        when :cancel
          pbPlayCancelSE
          break
        when :press
          case st[:focus]
          when 0
            pbPlayCursorSE
            st[:fused] = !st[:fused]
          when 1, 2
            pbPlayDecisionSE
            key = st[:focus] == 1 ? :body : :head
            picked = pick_species(st[key])
            st[key] = picked if picked
          when 3
            if st[:choice] == 1
              pbPlayCancelSE
              break
            end
            if st[:body].nil? || (st[:fused] && st[:head].nil?)
              pbPlayBuzzerSE
              next
            end
            pbPlayDecisionSE
            NG.plan["custom"] = { "fused" => st[:fused], "body" => st[:body].to_s }
            NG.plan["custom"]["head"] = st[:head].to_s if st[:fused]
            result = true
            break
          end
        end
      end
      return result
    ensure
      close_popup
    end

    def species_list
      return @@species if @@species
      n = defined?(::NB_POKEMON) ? ::NB_POKEMON - 4 : 0
      list = []
      (1..n).each do |i|
        sp = ::GameData::Species.get(i) rescue nil
        list << [sp.id.to_s, format("%03d %s", i, sp.name)] if sp
      end
      return @@species = list
    end

    def pick_species(current)
      list = species_list
      return nil if list.empty?
      at = list.index { |id, _n| id == current.to_s } || 0
      i = with_hints([[:ud, _INTL("Choose")], [:lr, _INTL("Page")], [button(:C), _INTL("Pick")], [button(:B), _INTL("Back")]]) do
        DL.picker(self, _INTL("Pick a Pokémon"), list.map { |_id, name| name }, at)
      end
      return i.nil? ? nil : list[i][0]
    end

    def paint_starter(b, c, st)
      x, y, w, h = ask_box(b, c, _INTL("Custom Starter"), nil, [], [_INTL("Use"), _INTL("Cancel")], st[:focus] == 3 ? st[:choice] : -1, 380, 138)
      hits = DL.instance_variable_get(:@hits) || []
      DL.send(:cursor_row, b, c, x + 8, y + 42, x + w - 8, y + 66) if st[:focus] == 0
      P.text(b, x + 18, y + 42, 120, 24, _INTL("Fused"), c[:opt], PF::ROW)
      on = st[:fused] ? _INTL("On") : _INTL("Off")
      vw = PF.width(PF::TEXT, on)
      cx = x + w - 60
      P.text(b, cx - vw / 2, y + 42, vw + 2, 24, on, st[:fused] ? c[:green] : c[:txt])
      arrow = st[:focus] == 0 ? c[:txt] : c[:dim]
      P.ui.tri(b, cx - vw / 2 - 12, y + 50, :l, arrow, 4)
      P.ui.tri(b, cx + vw / 2 + 5, y + 50, :r, arrow, 4)
      hits << [:fused, x + 8, y + 42, x + w - 8, y + 66]
      cards = st[:fused] ? [[_INTL("BODY"), :body, 1], [_INTL("HEAD"), :head, 2]] : [[_INTL("POKÉMON"), :body, 1]]
      cw = (w - 46) / 2
      cards.each_with_index do |(label, key, focus), k|
        cx0 = st[:fused] ? x + 18 + k * (cw + 10) : x + (w - cw) / 2
        lit = st[:focus] == focus
        PP.chamfer(b, cx0, y + 74, cx0 + cw, y + 170, 8, mix(c[:panel2], c[:bg], 0.45), lit ? c[:selb] : c[:line])
        P.text(b, cx0, y + 78, cw, 13, label, c[:head], PF::TINY, 2)
        sym = st[key]
        if sym
          species_icon(b, sym.to_sym, cx0 + (cw - 56) / 2, y + 92, 56)
          P.text(b, cx0, y + 148, cw, 20, NG.species_name(sym), c[:txt], nil, 2)
        else
          P.small(b, cx0, y + 112, cw, 18, _INTL("Pick a Pokémon"), c[:dim], 2)
        end
        hits << [key, cx0, y + 74, cx0 + cw, y + 170]
      end
      @popup_hits = hits
    end

    #--------------------------------------------------------------------------
    # The popup being shown
    #--------------------------------------------------------------------------
    def close_popup
      @popup = nil
      @popup_hints = nil
      @popup_hits = nil
      overlay.clear if @overlay_sprite && !@overlay_sprite.disposed?
      return true
    end
  end

  #============================================================================
  # All Per-Save Settings: the improved KIF Settings, this save's rows only
  #============================================================================
  if defined?(Reloaded::SettingsScreen)
    class PerSaveSettingsScreen < Reloaded::SettingsScreen
      LEFT_OUT = [:modules, :mods, :presets].freeze

      def rebuild
        super
        keep = []
        @rows.each_key do |id|
          # KIF's Modules rows say :save, but module states are global
          list = LEFT_OUT.include?(id) ? [] : (@rows[id] || [])
          out = []
          head = nil
          list.each do |r|
            if r.kind == :head
              head = r
              next
            end
            next unless r.kind == :opt && r.scope == :save && !run_setup_row?(r)
            if head
              out << head
              head = nil
            end
            out << r
          end
          @rows[id] = out
          keep << id unless out.empty?
        end
        @sections = @sections.select { |s| keep.include?(s[0]) } if @sections
      end

      private

      # Only this save's rows: every section open, the Settings screen's
      # folding left as it is
      def kr_remember_fold?
        return false
      end

      # Run Setup has its own Difficulty row
      def run_setup_row?(r)
        opt = r.opt
        return false unless opt && opt.respond_to?(:kr_key) && opt.kr_key
        return opt.kr_key.to_s.start_with?("difficulty.")
      end

      def paint_title(base, top, c)
        return super if @entry
        paint_title_bar(base, c)
        P.text(top, 0, 2, W, 28, _INTL("Per-Save Settings"), c[:title], PF::TITLE, 2)
        title_box(base, top, c, 8, @query || _INTL("Search"), :search => true, :active => !@query.nil?)
        title_box(base, top, c, W - 8 - BUTTON_W, _INTL("Presets"), :off => !Reloaded::Presets.available?)
        title_keys(top, c, left_key, right_key)
      end
    end
  end
end
