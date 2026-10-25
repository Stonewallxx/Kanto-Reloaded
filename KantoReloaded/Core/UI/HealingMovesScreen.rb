# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Healing Moves' screens
#==============================================================================
# The looks he picked on 2026-10-23 (galleries on Roadmap Designs, topic
# healing-overworld; mockups in Tools/Designs/healing), in Reloaded's plate
# look:
#
#   Heal with Moves   Healer List: Heal Everyone first, each healer on a
#                     plate of its type with its HP, its healing moves under
#                     it (what each does, uses left; one it can't use now
#                     dimmed, saying why), the party's HP along the bottom
#   Pick a Pokémon    Party Rows, each saying what the move would do for it
#   Heal Preview      Before and After: the Pokémon it changes, before and
#                     after (a gain as a paler stretch, a loss in pale red),
#                     the PP, Use / Back
#   Heal Everyone     Plan Steps: each move of the plan, the PP in all, the
#                     party's HP after
#   Morning Sun,      Choice Popup: Heal Itself, or the game's own Wait
#   Moonlight         Until Morning (or Night), outdoors only
#   after a heal      a toast at the top (Pikachu regained 55 HP, 7 LEFT)
#
# From the party menu, the party screen picks the target, as it does for
# items. Controller first; the mouse too.
#==============================================================================

return unless defined?(Reloaded::Pixel) && defined?(::KIF::PixelFont)

module Reloaded
  module HealingMovesScreen
    PF = ::KIF::PixelFont
    P = Reloaded::Pixel
    PP = Reloaded::PartyPaint
    DG = Reloaded::Dialogs
    HM = Reloaded::HealingMoves
    W = 512
    H = 384
    LIST_Z = 100_200          # under the toast (100_300) and the popups
    POP_Z = 100_400
    ROW_H = 34                # Pick a Pokémon's rows
    SOUND = "Recovery"        # the PokeVial's heal sound

    class << self
      # For tests: the layers and the rows on the list.
      attr_reader :list_sprite, :pop_sprite, :rows

      #------------------------------------------------------------------------
      # The Overworld Menu's Heal with Moves. Returns nil, or a proc to run
      # once the menu has closed (the game's own Wait Until Morning).
      #------------------------------------------------------------------------
      def open_list
        return nil if HM.party.empty?
        open_list_layer
        @sel = 0
        @scroll = 0
        result = nil
        loop do
          build_rows
          act = list_loop
          break if act == :back
          if act == :all
            heal_everyone
          elsif act.is_a?(Array)
            r = use_from_list(act[1], act[2])
            if r.respond_to?(:call)
              result = r
              break
            end
          end
        end
        return result
      ensure
        close_list_layer
      end

      # From a party menu (the game's, or Kanto Reloaded's): true when it
      # was dealt with here, false to let the game's own code go on (Wait)
      def from_party(scene, pkmn, id)
        u = HM.party.index(pkmn)
        return false unless u && HM.handles?(id)
        r = HM.usable(u, id)
        if r != true
          pbPlayBuzzerSE
          show_message(scene, _INTL("{1}: {2}", HM.move_name(id), r))
          return true
        end
        if HM.kind(id) == :time
          case choose_time(u, id)
          when :wait
            HM.defer_wait(pkmn, id)
            return false
          when :heal
            heal_and_toast(u, id, nil)
            scene.pbRefresh if scene.respond_to?(:pbRefresh)
          end
          return true
        end
        t = nil
        if HM.targeted?(id)
          t = party_pick(scene, u, id)
          return true if t.nil?
        end
        if confirm(u, id, t)
          heal_and_toast(u, id, t)
          scene.pbRefresh if scene.respond_to?(:pbRefresh)
        end
        return true
      ensure
        close_pop_layer
      end

      # Outside any menu (the Ready Menu): our own pick; true when used
      def from_field(pkmn, id)
        u = HM.party.index(pkmn)
        return false unless u
        r = HM.usable(u, id)
        if r != true
          pbMessage(_INTL("{1}: {2}", HM.move_name(id), r)) if defined?(pbMessage)
          return false
        end
        used = run_move(u, id)
        return used == true
      ensure
        close_pop_layer
      end

      #------------------------------------------------------------------------
      # Using one move from the list (or the field)
      #------------------------------------------------------------------------
      def use_from_list(u, id)
        r = HM.usable(u, id)
        if r != true
          pbPlayBuzzerSE
          return nil
        end
        out = run_move(u, id)
        close_pop_layer
        return out
      end

      # true when used; a proc for the game's own Wait; nil otherwise
      def run_move(u, id)
        pkmn = HM.party[u]
        if HM.kind(id) == :time
          case choose_time(u, id)
          when :heal then return heal_and_toast(u, id, nil) ? true : nil
          when :wait then return proc { HM.defer_wait(pkmn, id); pbUseHiddenMove(pkmn, id) }
          end
          return nil
        end
        t = nil
        if HM.targeted?(id)
          t = pick_target(u, id)
          return nil if t.nil?
        end
        return nil unless confirm(u, id, t)
        return heal_and_toast(u, id, t) ? true : nil
      end

      def heal_and_toast(u, id, t)
        before = HM.use!(u, id, t)
        return false unless before
        pbSEPlay(SOUND) rescue nil
        toast_after(u, id, before)
        return true
      end

      def heal_everyone
        steps, after = HM.plan
        if steps.empty?
          pbPlayBuzzerSE
          return
        end
        return unless plan_popup(steps, after)
        n = HM.run_plan(steps)
        close_pop_layer
        pbSEPlay(SOUND) rescue nil
        Reloaded::Toast.show(_INTL("Healed Everyone"), :pill => [_INTL("{1} PP", n), :gold])
      end

      # "Pikachu regained 55 HP", the healer's icon and its uses left
      def toast_after(u, id, before)
        list = HM.party
        row = before[:rows].first
        name = list[row[0]].name
        words = row[4].to_s
        text = if words.start_with?("+") && words.include?("HP") then _INTL("{1} regained {2} HP", name, words[/\d+/])
               elsif words.include?(_INTL("Revived")) then _INTL("{1} was revived", name)
               elsif words.include?(_INTL("Cures")) then _INTL("{1} was cured", name)
               elsif words.include?(_INTL("Falls Asleep")) then _INTL("{1} fell asleep, healed", name)
               else _INTL("{1} used {2}", list[u].name, HM.move_name(id))
               end
        mv = Array(list[u].moves).find { |m| m && m.id == id }
        bm = Reloaded::PartyIcons.species_bitmap(list[u].species) rescue nil
        Reloaded::Toast.show(text, :icon => bm, :pill => [_INTL("{1} LEFT", mv ? mv.pp : 0), :gold])
        bm.dispose if bm && !bm.disposed?
      end

      #------------------------------------------------------------------------
      # The list
      #------------------------------------------------------------------------
      def open_list_layer
        close_list_layer
        @list_vp = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @list_vp.z = LIST_Z
        @list_sprite = Sprite.new(@list_vp)
        @list_sprite.bitmap = Bitmap.new(W, H)
        @list_icons = {}
      end

      def close_list_layer
        (@list_icons || {}).each_value { |s, _r| s.dispose if s && !s.disposed? }
        @list_icons = {}
        @list_sprite.bitmap.dispose if @list_sprite && !@list_sprite.disposed? && @list_sprite.bitmap
        @list_sprite.dispose if @list_sprite && !@list_sprite.disposed?
        @list_vp.dispose if @list_vp && !@list_vp.disposed?
        @list_sprite = @list_vp = nil
      end

      # [kind, ...]: [:all], [:head, party index], [:move, party index, id]
      def build_rows
        @rows = [[:all]]
        HM.healers.each do |u, ids|
          @rows << [:head, u]
          ids.each { |id| @rows << [:move, u, id] }
        end
        @picks = @rows.each_index.select { |i| @rows[i][0] != :head }
        @sel = [[@sel, 0].max, @picks.length - 1].min
      end

      def list_loop
        redraw = true
        loop do
          if redraw
            draw_list
            redraw = false
          end
          Graphics.update
          Input.update
          @list_icons.each_value { |s, _r| s.update if s && !s.disposed? }
          pt = Reloaded::Pointer
          hit = pt.hit(@hits)
          if pt.moved? && hit && hit != @sel
            @sel = hit
            redraw = true
          end
          if pt.left? && hit
            @sel = hit
            pbPlayDecisionSE
            return pick_act
          elsif pt.right? || Input.trigger?(Input::BACK)
            pbPlayCancelSE
            return :back
          elsif (wh = pt.wheel) != 0
            @sel = [[@sel + (wh > 0 ? -1 : 1), 0].max, @picks.length - 1].min
            redraw = true
          elsif Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN)
            to = @sel + (Input.repeat?(Input::UP) ? -1 : 1)
            if to < 0 || to >= @picks.length
              next unless Input.trigger?(Input::UP) || Input.trigger?(Input::DOWN)
              to %= @picks.length
            end
            @sel = to
            pbPlayCursorSE
            redraw = true
          elsif Input.trigger?(Input::USE)
            pbPlayDecisionSE
            return pick_act
          end
        end
      end

      def pick_act
        row = @rows[@picks[@sel]]
        return row[0] == :all ? :all : row
      end

      def map_panel(o, c, title)
        x = 10; y = 4; w = W - 20; h = H - P::HINT_H - 8
        o.fill_rect(0, 0, W, H - P::HINT_H, Color.new(0, 0, 0, 90))
        DG.send(:panel, o, c, x, y, w, h)
        DG.send(:title_bar, o, c, x, y, w, _INTL(title))
        return [x, y, w, h]
      end

      def draw_list
        c = Reloaded::Palette.map_menu
        o = @list_sprite.bitmap
        o.clear
        @hits = []
        @list_icons.each_value { |s, _r| s.visible = false }
        x, y, w, h = map_panel(o, c, "Heal with Moves")
        list = HM.party
        s = HM.snapshot(list)
        steps, = HM.plan(s)
        # Heal Everyone
        ty = y + 40
        on = @picks[@sel] == 0
        DG.send(:button, o, c, x + 12, ty, x + w - 12, ty + 24, on)
        P.text(o, x + 26, ty + 3, 200, 18, _INTL("Heal Everyone"), steps.empty? ? c[:dim] : (on ? c[:strong] : c[:txt]), PF::TEXT)
        words = steps.empty? ? _INTL("Nothing to Heal") : _INTL("{1} moves, {2} PP", steps.length, HM.plan_pp(steps))
        P.small(o, x + 12, ty + 4, w - 38, 16, words, c[:dim], 1)
        @hits << [0, x + 12, ty, x + w - 12, ty + 24]
        # the healers and their moves, scrolled to keep the cursor in view
        area0 = ty + 32
        area1 = y + h - 58
        heights = @rows.map { |r| r[0] == :head ? 25 : (r[0] == :move ? 20 : 0) }
        tops = []
        acc = 0
        @rows.each_with_index do |r, i|
          tops << acc
          acc += heights[i]
          acc += 5 if r[0] == :move && (@rows[i + 1].nil? || @rows[i + 1][0] == :head)
        end
        cur = @picks[@sel]
        if cur > 0
          @scroll = tops[cur] - heights[cur] - 25 if tops[cur] - 25 < @scroll
          @scroll = tops[cur] + heights[cur] - (area1 - area0) if tops[cur] + heights[cur] > @scroll + (area1 - area0)
        end
        @scroll = [[@scroll, 0].max, [acc - (area1 - area0), 0].max].min
        @rows.each_with_index do |r, i|
          next if r[0] == :all
          ry = area0 + tops[i] - @scroll
          next if ry < area0 - 2 || ry + heights[i] > area1 + 2
          pkmn = list[r[1]]
          if r[0] == :head
            types = (pkmn.types rescue [pkmn.type1]) rescue [:NORMAL]
            plate(o, c, x + 12, ry, x + w - 12, ry + 22, tcol(Array(types).first))
            place_list_icon(pkmn, x + 30, ry + 11, 20)
            P.text(o, x + 46, ry + 2, 160, 18, PF.fit(PF::TEXT, pkmn.name.to_s, 150), c[:txt], PF::TEXT)
            hp_bar(o, c, x + w - 150, ry + 10, 70, pkmn.hp, pkmn.totalhp)
            P.small(o, x + w - 72, ry + 3, 56, 16, "#{pkmn.hp}/#{pkmn.totalhp}", c[:txt], 1)
          else
            pick = @picks.index(i)
            sel = pick == @sel
            id = r[2]
            ok = HM.usable(r[1], id, s)
            Reloaded::Dialogs.send(:cursor_row, o, c, x + 30, ry - 1, x + w - 14, ry + 18) if sel
            P.text(o, x + 44, ry, 130, 18, HM.move_name(id), ok != true ? c[:dim] : (sel ? c[:strong] : c[:txt]), PF::TEXT)
            P.small(o, x + 176, ry + 1, 200, 16, ok == true ? _INTL(HM::WORDS[HM.kind(id)]) : ok.to_s, c[:dim])
            if ok == true
              mv = Array(pkmn.moves).find { |m| m && m.id == id }
              P.small(o, x + w - 82, ry + 1, 60, 16, _INTL("{1} Left", mv ? mv.pp : 0), c[:green], 1)
            else
              lock_icon(o, x + w - 34, ry + 3, c[:dim])
            end
            @hits << [pick, x + 30, ry - 1, x + w - 14, ry + 18]
          end
        end
        # more above / below
        P.ui.tri(o, x + w / 2 - 4, area0 - 6, :u, c[:dim], 3) if @scroll > 0
        P.ui.tri(o, x + w / 2 - 4, area1 + 1, :d, c[:dim], 3) if @scroll + (area1 - area0) < acc
        party_strip(o, c, list, x + 12, y + h - 50, w - 24, 40)
        pairs = [[:ud, _INTL("Choose")], [button(:C), _INTL("Use")], [button(:B), _INTL("Back")]]
        P.hints(o, o, c, pairs, Reloaded::Prompts.style)
      end

      # the party's HP along the bottom: six small plates
      def party_strip(o, c, list, x, y, w, h)
        gap = 6
        pw = (w - gap * 5) / 6
        list.first(6).each_with_index do |pkmn, i|
          px = x + i * (pw + gap)
          types = (pkmn.types rescue [:NORMAL]) rescue [:NORMAL]
          plate(o, c, px, y, px + pw, y + h, pkmn.egg? ? c[:line] : tcol(Array(types).first), 7)
          place_list_icon(pkmn, px + 16, y + h / 2, 24, :strip)
          next if pkmn.egg?
          st = HM.status_of(pkmn)
          words = st ? short_status(st) : "#{pkmn.hp}/#{pkmn.totalhp}"
          P.text(o, px + 30, y + 8, pw - 36, 12, words, st ? c[:pink] : c[:txt], PF::TINY, 1)
          hp_bar(o, c, px + 32, y + h - 12, pw - 40, pkmn.hp, pkmn.totalhp, 3)
        end
      end

      def short_status(st)
        return { :POISON => "PSN", :BURN => "BRN", :PARALYSIS => "PAR", :SLEEP => "SLP", :FROZEN => "FRZ" }[st] || st.to_s[0, 3]
      end

      def place_list_icon(pkmn, cx, cy, box, where = :head)
        key = [pkmn.object_id, where]
        s, r = @list_icons[key]
        unless s
          s = Reloaded::PartyIcons.icon(pkmn, @list_vp, 2)
          r = s && s.bitmap ? Reloaded::PartyIcons.art_rect(s.bitmap, [s.src_rect.height, 1].max) : nil
          @list_icons[key] = [s, r]
        end
        fit(s, r, cx, cy, box)
      end

      def fit(s, r, cx, cy, box)
        return unless s && r
        s.zoom_x = s.zoom_y = box.to_f / [r.width, r.height, 1].max
        s.ox = r.x + r.width / 2
        s.oy = r.y + r.height / 2
        s.x = cx
        s.y = cy
        s.visible = true
      end

      #------------------------------------------------------------------------
      # Popups
      #------------------------------------------------------------------------
      def open_pop_layer
        return if @pop_vp && !@pop_vp.disposed?
        @pop_vp = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @pop_vp.z = POP_Z
        @pop_sprite = Sprite.new(@pop_vp)
        @pop_sprite.bitmap = Bitmap.new(W, H)
        @pop_icons = {}
      end

      def close_pop_layer
        (@pop_icons || {}).each_value { |s, _r| s.dispose if s && !s.disposed? }
        @pop_icons = {}
        @pop_sprite.bitmap.dispose if @pop_sprite && !@pop_sprite.disposed? && @pop_sprite.bitmap
        @pop_sprite.dispose if @pop_sprite && !@pop_sprite.disposed?
        @pop_vp.dispose if @pop_vp && !@pop_vp.disposed?
        @pop_sprite = @pop_vp = nil
      end

      def start_pop
        open_pop_layer
        o = @pop_sprite.bitmap
        o.clear
        o.fill_rect(0, 0, W, H, Color.new(0, 0, 0, 110))
        @pop_icons.each_value { |s, _r| s.visible = false }
        @hits = []
        return [o, Reloaded::Palette.map_menu]
      end

      def place_pop_icon(pkmn, cx, cy, box)
        key = pkmn.object_id
        s, r = @pop_icons[key]
        unless s
          s = Reloaded::PartyIcons.icon(pkmn, @pop_vp, 2)
          r = s && s.bitmap ? Reloaded::PartyIcons.art_rect(s.bitmap, [s.src_rect.height, 1].max) : nil
          @pop_icons[key] = [s, r]
        end
        fit(s, r, cx, cy, box)
      end

      def frame(o, c, w, h, title)
        x = (W - w) / 2
        y = [(H - P::HINT_H - h) / 2, 4].max
        DG.send(:panel, o, c, x, y, w, h)
        DG.send(:title_bar, o, c, x, y, w, title)
        return [x, y]
      end

      def pop_button(o, c, x0, y0, x1, y1, label, on, off = false)
        DG.send(:button, o, c, x0, y0, x1, y1, on)
        colour = off ? c[:dim] : (on ? (c[:strong] || c[:white]) : c[:txt])
        P.text(o, x0, y0 + 2, x1 - x0, 24, PF.fit(PF::TEXT, label, x1 - x0 - 8), colour, PF::TEXT, 2)
        @hits << [@hits.length, x0, y0, x1, y1]
      end

      # A popup's own loop: Left/Right (or Up/Down with vertical) over n
      # choices, A picks, B is nil; skip: choices that can't be picked
      def choice_loop(n, index, vertical = false, skip = [])
        redraw = true
        loop do
          if redraw
            yield index
            redraw = false
          end
          Graphics.update
          Input.update
          (@pop_icons || {}).each_value { |s, _r| s.update if s && !s.disposed? }
          pt = Reloaded::Pointer
          hit = pt.hit(@hits)
          if pt.moved? && hit && hit != index && !skip.include?(hit)
            index = hit
            redraw = true
          end
          back = vertical ? Input::UP : Input::LEFT
          fwd = vertical ? Input::DOWN : Input::RIGHT
          if pt.left? && hit
            if skip.include?(hit)
              pbPlayBuzzerSE
            else
              pbPlayDecisionSE
              return hit
            end
          elsif pt.right? || Input.trigger?(Input::BACK)
            pbPlayCancelSE
            return nil
          elsif Input.repeat?(back) || Input.repeat?(fwd)
            to = index
            n.times do
              to = (to + (Input.repeat?(back) ? -1 : 1)) % n
              break unless skip.include?(to)
            end
            if to != index
              index = to
              pbPlayCursorSE
              redraw = true
            end
          elsif Input.trigger?(Input::USE)
            if skip.include?(index)
              pbPlayBuzzerSE
            else
              pbPlayDecisionSE
              return index
            end
          end
        end
      end

      # Pick a Pokémon (Party Rows): what the move would do for each
      def pick_target(u, id)
        list = HM.party
        s = HM.snapshot(list)
        w = 380
        h = 42 + list.length * ROW_H + 8
        skip = (0...list.length).reject { |t| HM.effect(s, u, id, t) }
        first = (0...list.length).find { |t| !skip.include?(t) } || 0
        title = _INTL("Use {1} on Which?", HM.move_name(id))
        return choice_loop(list.length, first, true, skip) do |index|
          o, c = start_pop
          x, y = frame(o, c, w, h, title)
          list.each_with_index do |pkmn, i|
            ry = y + 40 + i * ROW_H
            Reloaded::Dialogs.send(:cursor_row, o, c, x + 6, ry, x + w - 6, ry + ROW_H - 2) if i == index
            place_pop_icon(pkmn, x + 26, ry + ROW_H / 2, 28)
            name = pkmn.egg? ? _INTL("Egg") : pkmn.name.to_s
            can = !skip.include?(i)
            P.text(o, x + 48, ry + 7, 100, 18, PF.fit(PF::TEXT, name, 100), can ? c[:txt] : c[:dim], PF::TEXT)
            unless pkmn.egg?
              P.text(o, x + 148, ry + 10, 56, 12, _INTL("LV {1}", pkmn.level), c[:gold], PF::TINY, 2)
              words = if can then HM.preview(u, id, i, s)[:rows].first[4]
                      elsif i == u && [:give, :other, :purify, :sacrifice, :sacrifice_pp].include?(HM.kind(id)) then _INTL("Itself")
                      elsif pkmn.hp <= 0 && HM.kind(id) != :revive then _INTL("Fainted")
                      elsif pkmn.hp >= pkmn.totalhp && HM.kind(id) != :purify then _INTL("Full HP")
                      else _INTL("Nothing to Do")
                      end
              P.small(o, x + 204, ry + 9, w - 220, 16, words, can ? c[:green] : c[:dim], 1)
            end
            @hits << [i, x + 6, ry, x + w - 6, ry + ROW_H - 2]
          end
          P.hints(o, o, c, [[:ud, _INTL("Choose")], [button(:C), _INTL("Select")], [button(:B), _INTL("Back")]], Reloaded::Prompts.style)
        end
      end

      # From a party menu: the party screen picks the target
      def party_pick(scene, u, id)
        s = HM.snapshot
        scene.pbSetHelpText(_INTL("Use {1} on which Pokémon?", HM.move_name(id))) if scene.respond_to?(:pbSetHelpText)
        loop do
          t = scene.pbChoosePokemon(false, u)
          t = t[1] if t.is_a?(Array)
          return nil if t.nil? || t < 0
          return t if HM.effect(s, u, id, t)
          pbPlayBuzzerSE
          show_message(scene, _INTL("{1} can't be used on {2} now.", HM.move_name(id), HM.party[t].name))
        end
      ensure
        scene.pbSetHelpText(_INTL("Choose a Pokémon.")) if scene.respond_to?(:pbSetHelpText)
      end

      # Heal Preview (Before and After): true for Use
      def confirm(u, id, t)
        pv = HM.preview(u, id, t)
        return false unless pv
        list = HM.party
        rows = pv[:rows]
        w = 380
        h = 40 + rows.length * 44 + (pv[:note] ? 18 : 0) + 50
        targeted = t && t != u
        title = targeted ? _INTL("{1} on {2}?", HM.move_name(id), list[t].name) : _INTL("{1}?", HM.move_name(id))
        r = choice_loop(2, 0) do |index|
          o, c = start_pop
          x, y = frame(o, c, w, h, title)
          rows.each_with_index do |(i, hp, after, max, words, pp), k|
            ry = y + 44 + k * 44
            place_pop_icon(list[i], x + 30, ry + 16, 30)
            P.text(o, x + 54, ry - 2, 140, 18, PF.fit(PF::TEXT, list[i].name.to_s, 140), c[:txt], PF::TEXT)
            change_bar(o, c, x + 56, ry + 20, 150, hp, after, max)
            main = hp == after ? "#{hp}/#{max}" : _INTL("{1} to {2}", hp, after)
            P.text(o, x + 214, ry - 2, w - 230, 18, main, after > hp ? c[:green] : (after < hp ? c[:amber] : c[:txt]), PF::TEXT, 1)
            sub = pp ? (words.to_s.empty? || words.start_with?("-") ? pp : "#{words}, #{pp}") : words
            P.small(o, x + 214, ry + 16, w - 230, 16, sub.to_s, pp ? c[:blue] : c[:green], 1)
          end
          P.small(o, x + 16, y + 44 + rows.length * 44, w - 32, 16, pv[:note], c[:dim]) if pv[:note]
          pop_button(o, c, x + 40, y + h - 38, x + w / 2 - 4, y + h - 10, _INTL("Use"), index == 0)
          pop_button(o, c, x + w / 2 + 4, y + h - 38, x + w - 40, y + h - 10, _INTL("Back"), index == 1)
          P.hints(o, o, c, [[:lr, _INTL("Choose")], [button(:C), _INTL("Select")], [button(:B), _INTL("Back")]], Reloaded::Prompts.style)
        end
        return r == 0
      end

      # Morning Sun / Moonlight (Choice Popup): :heal, :wait or nil
      def choose_time(u, id)
        list = HM.party
        s = HM.snapshot(list)
        pkmn = list[u]
        heal = HM.effect(s, u, id)
        wait_ok = HM.outdoors?
        morning = id == :MORNINGSUN
        now = (pbGetTimeNow rescue Time.now)
        clock = now.strftime("%-I:%M %p") rescue now.strftime("%I:%M %p")
        skip = []
        skip << 0 unless heal
        skip << 1 unless wait_ok
        w = 340
        h = 40 + 2 * 44 + 30
        r = choice_loop(2, heal ? 0 : 1, true, skip) do |index|
          o, c = start_pop
          x, y = frame(o, c, w, h, HM.move_name(id))
          rows = [[_INTL("Heal Itself"),
                   heal ? _INTL("{1}: {2} to {3} HP, PP {4} to {5}", pkmn.name, pkmn.hp, heal[u][:hp], s[u][:pp][id], s[u][:pp][id] - 1) : _INTL("Full HP"),
                   heal ? c[:green] : c[:dim]],
                  [morning ? _INTL("Wait Until Morning") : _INTL("Wait Until Night"),
                   wait_ok ? (morning ? _INTL("It's {1}: The game skips to morning", clock) : _INTL("It's {1}: The game skips to night", clock)) : _INTL("Outdoors Only"),
                   wait_ok ? c[:gold] : c[:dim]]]
          rows.each_with_index do |(label, sub, col), i|
            ry = y + 40 + i * 44
            Reloaded::Dialogs.send(:cursor_row, o, c, x + 6, ry, x + w - 6, ry + 40) if i == index
            P.text(o, x + 18, ry + 3, w - 36, 18, label, skip.include?(i) ? c[:dim] : (i == index ? c[:strong] : c[:txt]), PF::TEXT)
            P.small(o, x + 18, ry + 22, w - 36, 16, sub, col)
            @hits << [i, x + 6, ry, x + w - 6, ry + 40]
          end
          P.small(o, x + 12, y + h - 26, w - 24, 16, _INTL("Waiting works outdoors only."), c[:dim], 2)
          P.hints(o, o, c, [[:ud, _INTL("Choose")], [button(:C), _INTL("Select")], [button(:B), _INTL("Back")]], Reloaded::Prompts.style)
        end
        return r == 0 ? :heal : (r == 1 ? :wait : nil)
      end

      # Heal Everyone (Plan Steps): true to run it
      def plan_popup(steps, after)
        list = HM.party
        s = HM.snapshot(list)
        shown = steps.first(8)
        rh = 26
        w = 440
        h = 40 + 16 + shown.length * rh + (steps.length > shown.length ? 16 : 0) + 10 + 44 + 46
        r = choice_loop(2, 0) do |index|
          o, c = start_pop
          x, y = frame(o, c, w, h, _INTL("Heal Everyone"))
          top = y + 40
          P.text(o, x + 16, top, 150, 14, _INTL("THE PLAN"), c[:head], PF::TINY)
          P.text(o, x + w - 166, top, 150, 14, _INTL("{1} PP", HM.plan_pp(steps)), c[:dim], PF::TINY, 1)
          cur = s
          shown.each_with_index do |(u, id, t), k|
            ry = top + 16 + k * rh
            nxt = HM.effect(cur, u, id, t)
            who = t.nil? ? (HM.kind(id).to_s.start_with?("party") ? nil : u) : t
            words = nxt ? (who ? HM.change_words(cur[who], nxt[who]) : (HM.kind(id) == :party_status ? _INTL("Cures the Party") : _INTL("Heals the Party"))) : ""
            words = words.split(", ").reject { |p| p.start_with?("-") }.join(", ")
            place_pop_icon_key([:plan_user, k], list[u], x + 28, ry + rh / 2, 22)
            P.text(o, x + 46, ry + 2, 120, 18, HM.move_name(id), c[:txt], PF::TEXT)
            if who
              P.small(o, x + 164, ry + 4, 22, 16, _INTL("on"), c[:dim])
              place_pop_icon_key([:plan_target, k], list[who], x + 198, ry + rh / 2, 22)
              P.text(o, x + 214, ry + 2, 90, 18, who == u ? _INTL("Itself") : PF.fit(PF::TEXT, list[who].name.to_s, 88), c[:txt], PF::TEXT)
            end
            P.small(o, x + 300, ry + 4, w - 316, 16, words, c[:green], 1)
            cur = nxt || cur
          end
          if steps.length > shown.length
            P.small(o, x + 16, top + 16 + shown.length * rh, w - 32, 16, _INTL("And {1} more", steps.length - shown.length), c[:dim], 2)
          end
          strip_after(o, c, list, s, after, x + 12, y + h - 46 - 44 - 4, w - 24)
          pop_button(o, c, x + 40, y + h - 38, x + w / 2 - 4, y + h - 10, _INTL("Heal Everyone"), index == 0)
          pop_button(o, c, x + w / 2 + 4, y + h - 38, x + w - 40, y + h - 10, _INTL("Back"), index == 1)
          P.hints(o, o, c, [[:lr, _INTL("Choose")], [button(:C), _INTL("Select")], [button(:B), _INTL("Back")]], Reloaded::Prompts.style)
        end
        return r == 0
      end

      def place_pop_icon_key(key, pkmn, cx, cy, box)
        s, r = @pop_icons[key]
        unless s
          s = Reloaded::PartyIcons.icon(pkmn, @pop_vp, 2)
          r = s && s.bitmap ? Reloaded::PartyIcons.art_rect(s.bitmap, [s.src_rect.height, 1].max) : nil
          @pop_icons[key] = [s, r]
        end
        fit(s, r, cx, cy, box)
      end

      # the party's HP after a plan, six small plates
      def strip_after(o, c, list, s, after, x, y, w, h = 40)
        gap = 6
        pw = (w - gap * 5) / 6
        list.first(6).each_with_index do |pkmn, i|
          px = x + i * (pw + gap)
          types = (pkmn.types rescue [:NORMAL]) rescue [:NORMAL]
          plate(o, c, px, y, px + pw, y + h, pkmn.egg? ? c[:line] : tcol(Array(types).first), 7)
          place_pop_icon_key([:strip, i], pkmn, px + 13, y + h / 2, 20)
          next if pkmn.egg?
          a = s[i][:hp]
          b = after[i][:hp]
          P.text(o, px + 24, y + 8, pw - 28, 12, "#{b}/#{s[i][:max]}", b > a ? c[:green] : (b < a ? c[:amber] : c[:txt]), PF::TINY, 1)
          change_bar(o, c, px + 27, y + h - 12, pw - 33, a, b, s[i][:max], 3)
        end
      end

      #------------------------------------------------------------------------
      # Drawing pieces
      #------------------------------------------------------------------------
      def mix(a, b, t); Reloaded::Palette.mix(a, b, t); end

      def tcol(type)
        return Color.new(*Reloaded::PartyScreen.type_rgb(type))
      rescue StandardError
        return Color.new(150, 150, 160)
      end

      def hp_col(c, hp, max)
        f = hp.to_f / [max, 1].max
        return f > 0.5 ? c[:green] : (f > 0.25 ? c[:amber] : c[:red])
      end

      # an angled plate lit in a colour (the Party Screen's)
      def plate(o, c, x0, y0, x1, y1, col, cut = 8)
        top = mix(c[:panel2], col, 0.45)
        bottom = mix(c[:panel2], c[:dark], 0.45)
        PP.chamfer_grad(o, x0, y0, x1, y1, cut, top, bottom, mix(c[:line], col, 0.5))
      end

      def hp_bar(o, c, x, y, w, hp, max, h = 3)
        PP.bar(o, c, x, y, w, hp.to_f / [max, 1].max, hp_col(c, hp, max), h)
      end

      # an HP bar showing the change: a gain as a paler stretch after the HP
      # it has now, a loss as the part that goes, in a pale red
      def change_bar(o, c, x, y, w, hp, after, max, h = 4)
        max = [max, 1].max
        if after >= hp
          PP.bar(o, c, x, y, w, after.to_f / max, mix(hp_col(c, after, max), c[:white], 0.5), h)
          o.fill_rect(x, y, (w * hp.to_f / max).round, h, hp_col(c, hp, max)) if hp > 0
        else
          PP.bar(o, c, x, y, w, hp.to_f / max, mix(c[:red], c[:white], 0.45), h)
          o.fill_rect(x, y, (w * after.to_f / max).round, h, hp_col(c, after, max)) if after > 0
        end
      end

      def lock_icon(o, x, y, col)
        o.fill_rect(x + 2, y, 5, 1, col)
        o.fill_rect(x + 1, y + 1, 1, 4, col)
        o.fill_rect(x + 7, y + 1, 1, 4, col)
        P.ui.rbox(o, x, y + 5, x + 9, y + 11, 1, col)
      end

      def show_message(scene, text)
        if scene && scene.respond_to?(:pbDisplay)
          scene.pbDisplay(text)
        elsif defined?(pbMessage)
          pbMessage(text)
        end
      end

      def button(sym)
        return Reloaded::Prompts.input(sym) || Reloaded::Prompts.name(sym)
      end
    end
  end
end
