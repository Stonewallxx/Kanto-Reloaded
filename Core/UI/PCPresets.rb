# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Reloaded PC's Party Presets page (Step 5)
#==============================================================================
# More of the PC scene (UI/PCScene.rb), his Step 5 picks (2026-10-24): A
# Page of Box Overview. LB / RB switch Box Overview and Party Presets (while
# organising, nothing held). Cards two across, each preset's name and its
# Pokémon (a member that's gone: a red ?), NOW on the one that's the party,
# + Save Current Party last (named in place, like Rename). A swaps one in;
# X gives its options: Swap In, Save the Party Here, Rename, Delete. After
# Swap In (his pick: A Toast, a Notice When Missing), a toast says it's
# done and, only when a member wasn't found, a notice says who. The logic
# is Core/PC/Presets.rb.
#==============================================================================

return unless defined?(Reloaded::PCScene) && defined?(Reloaded::PC::Presets)

module Reloaded
  module PCScene
    PR_COLS = 2
    PR_ROWS = 4
    PR_W = (W - 12 - 8) / PR_COLS
    PR_H = 66
    PR_GAP = 6
    PR_Y = 38
    PR_STEP = 38              # one member's room on a card

    private

    def presets_offered?
      return quick? && !drop_held? && !choosing? && Reloaded::SaveStore.loaded?
    end

    # The cards: each preset's index, then :new
    def preset_cards
      list = (0...Reloaded::PC::Presets.list.length).to_a
      list << :new unless Reloaded::PC::Presets.full?
      return list
    end

    # LB / RB on Box Overview: the presets page; :boxes (back) or :close
    def presets_page
      @kr_ov[:page] = :presets
      @kr_ov[:psel] ||= 0
      @kr_ov[:ptop] ||= 0
      @kr_pr_where = nil
      pbPlayCursorSE
      pr_scroll
      refresh
      result = :boxes
      loop do
        Graphics.update
        Input.update
        update
        cards = preset_cards
        @kr_ov[:psel] = @kr_ov[:psel].clamp(0, cards.length - 1)
        pt = Reloaded::Pointer
        hit = pt.hit(@kr_hits || [])
        hit = nil unless hit.is_a?(Integer)
        if pt.moved? && hit && hit != @kr_ov[:psel]
          @kr_ov[:psel] = hit
          pbPlayCursorSE
          refresh
        end
        act = nil
        if pt.left? && hit
          @kr_ov[:psel] = hit
          act = :use
        elsif pt.right? || Input.trigger?(Input::BACK)
          pbPlayCancelSE
          result = :close
          break
        elsif Input.trigger?(Input::JUMPUP) || Input.trigger?(Input::JUMPDOWN)
          pbPlayCursorSE
          break
        elsif (w = pt.wheel) != 0
          pr_move(w * PR_COLS, cards.length, false)
        elsif Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)
          pr_move(Input.repeat?(Input::LEFT) ? -1 : 1, cards.length, Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT))
        elsif Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN)
          pr_move(Input.repeat?(Input::UP) ? -PR_COLS : PR_COLS, cards.length, false)
        elsif Input.trigger?(Input::USE)
          act = :use
        elsif Input.trigger?(Input::ACTION)
          act = :options
        end
        next unless act
        card = cards[@kr_ov[:psel]]
        if card == :new
          act == :use ? new_preset : pbPlayBuzzerSE
          refresh
          next
        end
        done = act == :use ? swap_in(card) : preset_options(card)
        if done
          result = :close
          break
        end
        refresh
      end
      @kr_ov[:page] = :boxes
      return result
    end

    def pr_move(step, n, wrap)
      to = @kr_ov[:psel] + step
      if to < 0 || to >= n
        return unless wrap
        to %= n
      end
      to = to.clamp(0, n - 1)
      return if to == @kr_ov[:psel]
      @kr_ov[:psel] = to
      pr_scroll
      pbPlayCursorSE
      refresh
    end

    def pr_scroll
      row = @kr_ov[:psel] / PR_COLS
      @kr_ov[:ptop] = row if row < @kr_ov[:ptop]
      @kr_ov[:ptop] = row - PR_ROWS + 1 if row >= @kr_ov[:ptop] + PR_ROWS
    end

    # + Save Current Party: named in place (typing, or the naming screen)
    def new_preset
      pbPlayDecisionSE
      name = preset_name(:new, "")
      return if name.nil?
      Reloaded::PC::Presets.add(name, @storage.party)
      @kr_ov[:psel] = Reloaded::PC::Presets.list.length - 1
      pr_scroll
      refresh
    end

    # The name typed where the card's name goes; nil when B cancels
    def preset_name(card, initial)
      @kr_ov[:naming] = card
      hints = [[button(:C), _INTL("Type")], [:d, _INTL("Done")], [button(:B), _INTL("Cancel")]]
      text, how = with_popup_hints(hints) do
        Reloaded::TextEntry.run(self, _INTL("Type a Name"), initial, 20, :prompt => _INTL("Name the Preset"), :down => true)
      end
      return how == :enter ? text : nil
    ensure
      @kr_ov[:naming] = nil if @kr_ov
    end

    # X: Swap In, Save the Party Here, Rename, Delete. True when it swapped in.
    def preset_options(i)
      preset = Reloaded::PC::Presets.list[i]
      rows = [[_INTL("Swap In"), _INTL("Its Pokémon trade places with your party."), true, :swap],
              [_INTL("Save the Party Here"), _INTL("Make this preset your party as it is now."), true, :save],
              [_INTL("Rename"), _INTL("Give it a new name."), true, :rename],
              [_INTL("Delete"), _INTL("Forget this preset. No Pokémon are moved."), true, :delete],
              [_INTL("Cancel"), _INTL("Back to the presets."), true, :cancel]]
      pbPlayDecisionSE
      case pc_menu(PF.fit(PF::TEXT, preset["name"].to_s, 280), rows, 0)
      when :swap
        return swap_in(i)
      when :save
        if Reloaded::Dialogs.confirm(self, _INTL("Save Your Party Here?"),
                                     _INTL("{1} becomes your party as it is now.", preset["name"]), _INTL("Save"), _INTL("Cancel"))
          Reloaded::PC::Presets.save_party(i, @storage.party)
        end
      when :rename
        name = preset_name(i, preset["name"].to_s)
        Reloaded::PC::Presets.rename(i, name) if name
      when :delete
        if Reloaded::Dialogs.confirm(self, _INTL("Delete {1}?", preset["name"]), _INTL("No Pokémon are moved."),
                                     _INTL("Delete"), _INTL("Keep"), false)
          Reloaded::PC::Presets.delete(i)
        end
      end
      @kr_pr_where = nil
      refresh
      return false
    end

    # A: the preset becomes the party (Core/PC/Presets.rb). True when done.
    def swap_in(i)
      preset = Reloaded::PC::Presets.list[i]
      plan = Reloaded::PC::Presets.plan(preset, @storage, @storage.currentBox)
      unless plan.ok
        pbPlayBuzzerSE
        title, text = swap_refusal(preset, plan)
        Reloaded::Dialogs.notice(self, title, text)
        refresh
        return false
      end
      pbPlayDecisionSE
      Reloaded::PC::Presets.apply(plan, @storage)
      @kr_pr_where = nil
      pbSEPlay("GUI storage put down")
      pbHardRefresh
      gone = plan.missing + plan.transfer
      unless gone.empty?
        title = gone.length == 1 ? _INTL("One Wasn't Found") : _INTL("{1} Weren't Found", gone.length)
        lines = []
        unless plan.missing.empty?
          lines << (plan.missing.length == 1 ?
            _INTL("{1} isn't in your boxes any more.", Reloaded::PC::Presets.names(plan.missing)) :
            _INTL("{1} aren't in your boxes any more.", Reloaded::PC::Presets.names(plan.missing)))
        end
        unless plan.transfer.empty?
          lines << (plan.transfer.length == 1 ?
            _INTL("{1} is in the Transfer Box.", Reloaded::PC::Presets.names(plan.transfer)) :
            _INTL("{1} are in the Transfer Box.", Reloaded::PC::Presets.names(plan.transfer)))
        end
        lines << (gone.length == 1 ? _INTL("{1} swapped in without it.", preset["name"]) :
                                     _INTL("{1} swapped in without them.", preset["name"]))
        Reloaded::Dialogs.notice(self, title, lines.join(" "))
        refresh
      end
      text = _INTL("{1} Is Your Party Now", preset["name"])
      defined?(Reloaded::Toast) ? Reloaded::Toast.show(text) : Reloaded::Dialogs.notice(self, _INTL("PC"), text)
      return true
    end

    def swap_refusal(preset, plan)
      reason, who = plan.reason
      case reason
      when :mail
        return [_INTL("Can't Swap In"), _INTL("{1} is holding Mail. Take the Mail off first, so it can go in a box.", who.name)]
      when :no_room
        return [_INTL("Can't Swap In"), _INTL("There isn't room in your boxes for the rest of your party.")]
      end
      return [_INTL("Can't Swap In"), _INTL("None of {1}'s Pokémon can battle, or none are in your boxes any more.", preset["name"])]
    end

    #--------------------------------------------------------------------------
    # Drawing (his pick: A Page of Box Overview)
    #--------------------------------------------------------------------------
    # The title as two pages: Box Overview and Party Presets, LB / RB at the
    # ends
    def overview_tabs(top, c, on)
      style = Reloaded::Prompts.style
      lk = Reloaded::Prompts.input(:L)
      rk = Reloaded::Prompts.input(:R)
      Reloaded::ButtonIcons.draw(top, 8, 6, lk, c, style, 18) if lk
      rw = rk ? Reloaded::ButtonIcons.width(rk, style, 18) : 0
      Reloaded::ButtonIcons.draw(top, W - 8 - rw, 6, rk, c, style, 18) if rk
      words = [_INTL("Box Overview"), _INTL("Party Presets")]
      ws = words.map { |w| P.width(PF::ROW, w) }
      x = (W - (ws.sum + 40)) / 2
      words.each_with_index do |w, i|
        lit = (i == 0) == (on == :boxes)
        P.text(top, x, 3, ws[i] + 2, 24, w, lit ? c[:title] : c[:dim], PF::ROW)
        top.fill_rect(x, 26, ws[i], 2, c[:selb]) if lit
        x += ws[i] + 40
      end
    end

    def draw_presets(base, top, c)
      PP.paint_background(base, c)
      overview_tabs(top, c, :presets)
      @kr_pr_where ||= Reloaded::PC::Presets.places(@storage)
      cards = preset_cards
      first = @kr_ov[:ptop] * PR_COLS
      (0...(PR_COLS * PR_ROWS)).each do |slot|
        j = first + slot
        break if j >= cards.length
        x = 6 + (slot % PR_COLS) * (PR_W + 8)
        y = PR_Y + (slot / PR_COLS) * (PR_H + PR_GAP)
        @kr_hits << [j, x, y, x + PR_W, y + PR_H]
        @cursor_rect = [x - 1, y - 1, PR_W + 3, PR_H + 3] if j == @kr_ov[:psel] && !@kr_ov[:naming]
        cards[j] == :new ? new_card(base, top, c, x, y) : preset_card(base, top, c, cards[j], x, y)
      end
      rows = (cards.length + PR_COLS - 1) / PR_COLS
      P.ui.tri(top, W / 2 - 4, PR_Y - 5, :u, c[:dim], 3) if @kr_ov[:ptop] > 0
      P.ui.tri(top, W / 2 - 4, PR_Y + PR_ROWS * (PR_H + PR_GAP) - 3, :d, c[:dim], 3) if @kr_ov[:ptop] + PR_ROWS < rows
    end

    def preset_card(base, top, c, i, x, y)
      preset = Reloaded::PC::Presets.list[i]
      members = Reloaded::PC::Presets.members(preset, @storage, @kr_pr_where)
      now = Reloaded::PC::Presets.party?(preset, @storage.party, @storage, members)
      P.ui.rbox(base, x, y, x + PR_W, y + PR_H, 5, c[:panel2], now ? c[:gold] : c[:line])
      if @kr_ov[:naming] == i && @kr_entry
        Reloaded::TextEntry.draw_field(base, top, c, @kr_entry, x + 6, y + 3, PR_W - 12, 21, 8)
      else
        P.text(top, x + 8, y + 4, PR_W - 60, 18, PF.fit(PF::TEXT, preset["name"].to_s, PR_W - 64), c[:txt])
        P.pill(top, x + PR_W - 40, y + 6, _INTL("NOW"), c[:gold], c[:dark], false) if now
      end
      members.each_with_index do |(pk, _at, _seen), k|
        break if k >= ::Settings::MAX_PARTY_SIZE
        cx = x + 24 + k * PR_STEP
        cy = y + 44
        if pk
          s = box_icon(pk, [:preset, i, k])
          place(s, cx, cy, 30)
          s.opacity = 255
        else
          missing_slot(top, c, cx, cy)
        end
      end
    end

    # + Save Current Party, the party faint in it
    def new_card(base, top, c, x, y)
      P.ui.rbox(base, x, y, x + PR_W, y + PR_H, 5, mix(c[:panel2], c[:bg], 0.4), c[:line])
      if @kr_ov[:naming] == :new && @kr_entry
        Reloaded::TextEntry.draw_field(base, top, c, @kr_entry, x + 6, y + 3, PR_W - 12, 21, 8)
      else
        P.text(top, x + 8, y + 4, PR_W - 16, 18, _INTL("+ Save Current Party"), c[:txt])
      end
      @storage.party.each_with_index do |pk, k|
        s = box_icon(pk, [:preset, :new, k])
        place(s, x + 24 + k * PR_STEP, y + 44, 30)
        s.opacity = 110
      end
    end

    # A member that's gone: a red dashed place with ?
    def missing_slot(b, c, cx, cy)
      x0 = cx - 13
      y0 = cy - 13
      x1 = cx + 13
      y1 = cy + 13
      (x0...x1).step(5) { |x| b.fill_rect(x, y0, 3, 1, c[:red]); b.fill_rect(x, y1, 3, 1, c[:red]) }
      (y0...y1).step(5) { |y| b.fill_rect(x0, y, 1, 3, c[:red]); b.fill_rect(x1, y, 1, 3, c[:red]) }
      P.text(b, x0, cy - 9, 27, 18, "?", c[:red], PF::TEXT, 2)
    end

    def presets_hints
      return @popup_hints if @popup_hints
      verb = preset_cards[@kr_ov[:psel]] == :new ? _INTL("Save Current Party") : _INTL("Swap In")
      list = [[:ud, _INTL("Choose")], [button(:C), verb]]
      list << [button(:A), _INTL("Options")] unless preset_cards[@kr_ov[:psel]] == :new
      return list + [[button(:L), _INTL("Boxes")], [button(:B), _INTL("Back")]]
    end
  end
end
