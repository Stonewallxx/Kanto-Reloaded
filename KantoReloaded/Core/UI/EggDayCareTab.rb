# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Egg Manager's Day Care tab
#==============================================================================
# His picks (2026-10-23 and 2026-10-25), on the Egg Manager's screen:
#
#   the list    the Pokémon there (name, level, picture), Find a Partner
#               (pink, with one there), Egg Waiting (gold), Deposit a
#               Pokémon (with room)
#   the plate   pink: the two side by side, how well they get along (the
#               words and pips), Egg Chance ("50% Every 256 Steps", the
#               number green 70, gold 50, dim 20), each one's levels gained
#               and what taking it back costs (green when you can pay, red
#               when you can't), the waiting Egg with Collect / Discard
#   Partner     In the Day Care Tab: the list becomes the partners in
#   Finder      sections by Egg Chance; the plate shows the pair as it would
#               be, where the partner is, why ("Same Species · Other
#               Trainer") and Deposit
#   Deposit     the same list look: your party, then box by box; with one
#               there, the plate shows how the two would get along
#
# Until you've left a Pokémon at the Day Care in person, it says so.
#==============================================================================

return unless defined?(Reloaded::EggManagerScreen)

module Reloaded
  class EggManagerScreen
    DC = Reloaded::EggManager::DayCare
    COMPAT_WORDS = ["They Prefer to Play with Others", "They Don't Seem to Like Each Other",
                    "They Seem to Get Along", "They Get Along Very Well"].freeze
    SECTION_WORDS = { 3 => "Very Well", 2 => "Get Along", 1 => "Don't Like Each Other" }.freeze
    CHANCE_TONES = { 3 => :green, 2 => :gold, 1 => :dim, 0 => :dim }.freeze

    private

    def day_care_items
      return [] unless DC.visited?
      case @mode
      when :finder then return finder_items
      when :deposit then return deposit_items
      end
      out = DC.slots.map { |s| [:row, [:parent, s]] }
      out << [:row, [:find, nil]] if DC.count == 1
      out << [:row, [:egg, nil]] if DC.egg_waiting?
      out << [:row, [:deposit, nil]] if DC.count < 2
      return out
    end

    def anchor
      s = DC.slots.first
      return s ? s[0] : nil
    end

    # The partners, in sections by Egg Chance (kept while the finder's open)
    def finder_items
      @partners ||= DC.partners(anchor)
      out = []
      @partners.group_by { |_e, c| c }.sort_by { |c, _l| -c }.each do |compat, list|
        out << [:head, _INTL(SECTION_WORDS[compat]), ["#{DC.chance(compat)}%", CHANCE_TONES[compat]]]
        list.each { |pair| out << [:row, [:partner, pair]] }
      end
      return out
    end

    # Your party, then box by box (Eggs left out)
    def deposit_items
      @depositable ||= begin
        groups = []
        DC.each_pokemon do |e|
          next if e.pkmn.egg?
          key = e.party? ? -1 : e.box
          groups << [key, []] unless groups.last && groups.last[0] == key
          groups.last[1] << e
        end
        groups
      end
      out = []
      @depositable.each do |key, list|
        out << [:head, key < 0 ? _INTL("Party") : EG.box_name(key), nil]
        list.each { |e| out << [:row, [:pick, e]] }
      end
      return out
    end

    def enter_mode(mode)
      @mode_sel = @sel
      @mode = mode
      @partners = nil if mode == :finder
      @depositable = nil if mode == :deposit
      @sel = 0
      @scroll = 0
      pbPlayDecisionSE
      changed!
    end

    def leave_mode
      @mode = :list
      @partners = nil
      @depositable = nil
      @sel = 0
      @scroll = 0
      changed!
    end

    #--------------------------------------------------------------------------
    # Input
    #--------------------------------------------------------------------------
    def day_care_input
      return if move_cursor
      cur = current
      if (Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)) && cur && cur[0] == :egg
        @dc_button = Input.trigger?(Input::LEFT) ? 0 : 1
        pbPlayCursorSE
        refresh
      elsif Input.trigger?(Input::USE)
        day_care_select
      end
    end

    def day_care_select
      cur = current
      return pbPlayBuzzerSE unless cur
      kind, data = cur
      case kind
      when :parent then withdraw(data)
      when :find
        enter_mode(:finder)
        if selectable.empty?
          name = anchor ? anchor.name : ""
          leave_mode
          Reloaded::Dialogs.notice(self, _INTL("Partner Finder"), _INTL("Nothing in your party or boxes can breed with {1}.", name))
        end
      when :egg then @dc_button == 1 ? discard : collect
      when :deposit then enter_mode(:deposit)
      when :partner then deposit(data[0])
      when :pick then deposit(data)
      end
    end

    # The plate's buttons, by the mouse
    def plate_button(b)
      case b
      when :collect then collect
      when :discard then discard
      when :deposit then day_care_select
      when :back then hint_back
      end
    end

    def withdraw(slot_data)
      pk, _lv, slot = slot_data
      price = DC.cost(slot)
      labels = [_INTL("To Your Party"), _INTL("To the PC")]
      notes = [_INTL("It joins your party for ${1}.", money_words(price)), _INTL("It goes to {1} for ${2}.", store_box_words, money_words(price))]
      i = Reloaded::Dialogs.menu(self, _INTL("Take Back {1}?", pk.name), labels, notes)
      refresh
      return if i.nil?
      r = DC.withdraw(slot, i == 0 ? :party : :pc)
      return Reloaded::Dialogs.notice(self, pk.name, r) unless r.is_a?(Array)
      pbSEPlay("Mart buy item") rescue nil
      where = r[1] && !r[1].party? ? EG.box_name(r[1].box) : nil
      changed!
      Reloaded::Dialogs.notice(self, pk.name, where ? _INTL("{1} went to {2}.", pk.name, where) : _INTL("{1} joined your party.", pk.name))
    end

    def store_box_words
      b = EG.store_box
      return b ? EG.box_name(b) : _INTL("the PC")
    end

    def money_words(n)
      return n.to_i.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
    end

    def collect
      r = DC.collect
      return Reloaded::Dialogs.notice(self, _INTL("Egg"), r) unless r.is_a?(Array)
      pbMEPlay("Pkmn get") rescue nil
      e = r[1]
      @dc_button = 0
      changed!
      text = if e.nil? || e.party? then _INTL("The Egg joined your party.")
             elsif (n = INC.number(e.pkmn)) then _INTL("The Egg went to {1}, into Incubator {2}.", EG.box_name(e.box), n)
             else _INTL("The Egg went to {1}.", EG.box_name(e.box))
             end
      Reloaded::Dialogs.notice(self, _INTL("Egg Collected"), text)
    end

    def discard
      return unless Reloaded::Dialogs.confirm(self, _INTL("Discard the Egg?"), _INTL("The Day Care keeps it from you. Another may come later."),
                                              _INTL("Discard"), _INTL("Keep"), false)
      DC.discard
      @dc_button = 0
      changed!
    end

    def deposit(entry)
      r = DC.deposit(entry)
      return Reloaded::Dialogs.notice(self, entry.pkmn.name, r) unless r == true
      pbPlayDecisionSE
      leave_mode
      Reloaded::Dialogs.notice(self, _INTL("Day Care"), _INTL("{1} is at the Day Care now.", entry.pkmn.name))
    end

    def day_care_hints
      back = button(:B)
      if @mode != :list
        return [[:ud, _INTL("Choose")], [button(:C), _INTL("Deposit"), :hint_options], [back, _INTL("Back"), :hint_back]]
      end
      cur = current
      out = cur ? [[:ud, _INTL("Choose")]] : []
      out << [:lr, _INTL("Collect or Discard")] if cur && cur[0] == :egg
      out << [button(:A), _INTL("Tabs"), :hint_tabs]
      out << [button(:C), _INTL("Select"), :hint_options] if cur
      out << [back, _INTL("Close"), :hint_back]
      return out
    end

    #--------------------------------------------------------------------------
    # Drawing
    #--------------------------------------------------------------------------
    def day_care_row(top, c, x, y, data)
      kind, d = data
      case kind
      when :parent
        pk, _lv, _slot = d
        nw = P.text(top, x + 4, y + 3, 150, 20, PF.fit(PF::TEXT, pk.name.to_s, 140), c[:txt], PF::TEXT)
        P.small(top, x + 4 + nw + 8, y + 4, 60, 16, _INTL("Lv {1}", pk.level), c[:dim])
        show_icon(:"dc#{pk.object_id}", pk, x + LIST_W - 12, y + 12, 22)
      when :find
        P.text(top, x + 4, y + 3, 150, 20, _INTL("Find a Partner"), c[:pink], PF::TEXT)
        n = (@partner_count ||= DC.partners(anchor).length)
        P.small(top, x, y + 4, LIST_W - 8, 16, _INTL("{1} Found", n), c[:dim], 1)
      when :egg
        P.text(top, x + 4, y + 3, 150, 20, _INTL("Egg Waiting"), c[:gold], PF::TEXT)
        egg_picture(top, x + LIST_W - 12, y + 12, 22)
      when :deposit
        P.text(top, x + 4, y + 3, 170, 20, _INTL("Deposit a Pokémon"), c[:txt], PF::TEXT)
        P.text(top, x + LIST_W - 40, y + 5, 32, 14, "+", c[:dim], PF::TINY, 1)
      when :partner, :pick
        e = kind == :partner ? d[0] : d
        pk = e.pkmn
        nw = P.text(top, x + 4, y + 3, 120, 20, PF.fit(PF::TEXT, pk.name.to_s, 110), c[:txt], PF::TEXT)
        gx = x + 4 + nw + 4
        gw = gender(top, c, pk, gx, y + 9)
        P.small(top, gx + gw + 6, y + 4, 50, 16, _INTL("Lv {1}", pk.level), c[:dim]) if kind == :pick
        P.small(top, x, y + 4, LIST_W - 30, 16, e.party? ? _INTL("Party") : PF.fit(PF::TINY, EG.box_name(e.box), 60), c[:dim], 1) if kind == :partner
        show_icon(:"dp#{pk.object_id}", pk, x + LIST_W - 12, y + 12, 22)
      end
    end

    def compat_dots(top, c, cx, y, n)
      pink = c[:pink]
      3.times do |i|
        hx = cx - 22 + i * 16
        P.ui.rbox(top, hx, y, hx + 10, y + 10, 5, i < n ? pink : c[:dark], i < n ? pink : c[:line])
      end
    end

    # "Egg Chance: 50% Every 256 Steps", the number in its colour, centred
    def chance_line(top, c, cx, y, compat)
      segs = [[_INTL("Egg Chance: "), c[:dim]], ["#{DC.chance(compat)}%", c[CHANCE_TONES[compat]] || c[:dim]],
              [_INTL(" Every 256 Steps"), c[:dim]]]
      P.send(:small_font, top)
      widths = segs.map { |t, _col| top.text_size(t).width }
      x = cx - widths.sum / 2
      segs.each_with_index do |(t, col), i|
        P.small(top, x, y, widths[i] + 4, 16, t, col)
        x += widths[i]
      end
    end

    def sunken_spot(base, top, c, cx, cy)
      sunk = mix(c[:panel2], c[:dark], 0.45)
      PP.chamfer_grad(base, cx - 20, cy - 20, cx + 20, cy + 20, 6, sunk, sunk, sunk)
      P.text(top, cx - 20, cy - 7, 40, 14, "+", c[:dim], PF::TINY, 2)
    end

    def plate_buttons(base, top, c, x, w, labels, lit)
      by = H - P::HINT_H - 6 - 40
      bw = (w - 10) / 2
      labels.each_with_index do |(id, label), i|
        bx = x + i * (bw + 10)
        on = lit == i
        Reloaded::Dialogs.send(:button, base, c, bx, by, bx + bw, by + 28, on)
        P.text(top, bx, by + 2, bw, 24, label, on ? c[:strong] : c[:txt], PF::TEXT, 2)
        @button_hits << [id, bx, by, bx + bw, by + 28]
      end
    end

    def draw_day_care_plate(base, top, c)
      pink = c[:pink]
      x = PX0 + 14
      w = PX1 - PX0 - 28
      cx = (PX0 + PX1) / 2
      unless DC.visited?
        plate(base, c, pink, PY0 + 112)
        egg_picture(top, cx, PY0 + 50, 40)
        P.small_wrap(top, _INTL("The Day Care is on Route 5. Leave a Pokémon there once, and you can deposit, take back and collect Eggs from here."), w).first(5).each_with_index do |ln, k|
          P.small(top, x, PY0 + 124 + k * 16, w, 16, ln, c[:dim])
        end
        return
      end
      return draw_pair_plate(base, top, c) if @mode != :list
      slots = DC.slots
      plate(base, c, pink, PY0 + 112)
      if slots.length == 2
        show_icon(:dcl, slots[0][0], cx - 50, PY0 + 34, 40)
        show_icon(:dcr, slots[1][0], cx + 50, PY0 + 34, 40)
        compat = DC.compat
        P.text(top, PX0, PY0 + 62, PX1 - PX0, 13, _INTL(COMPAT_WORDS[compat]).upcase, pink, PF::TINY, 2)
        compat_dots(top, c, cx, PY0 + 78, compat)
        chance_line(top, c, cx, PY0 + 93, compat)
      elsif slots.length == 1
        show_icon(:dcl, slots[0][0], cx - 50, PY0 + 34, 40)
        sunken_spot(base, top, c, cx + 50, PY0 + 34)
        P.text(top, PX0, PY0 + 66, PX1 - PX0, 13, _INTL("ONE MORE TO BREED"), c[:dim], PF::TINY, 2)
        compat_dots(top, c, cx, PY0 + 84, 0)
      else
        sunken_spot(base, top, c, cx - 50, PY0 + 34)
        sunken_spot(base, top, c, cx + 50, PY0 + 34)
        P.text(top, PX0, PY0 + 66, PX1 - PX0, 13, _INTL("NOBODY HERE"), c[:dim], PF::TINY, 2)
      end
      y = PY0 + 122
      slots.each do |pk, lv, slot|
        gained = pk.level - lv.to_i
        cost = DC.cost(slot)
        P.text(top, x, y, 120, 20, PF.fit(PF::TEXT, pk.name.to_s, 110), c[:txt], PF::TEXT)
        # the cost green when you can pay, red when you can't (his rule)
        pw = P.small(top, x, y + 2, w, 16, "$#{money_words(cost)}", DC.money >= cost ? c[:green] : c[:red], 1)
        levels = gained == 1 ? _INTL("+1 Level ·") : _INTL("+{1} Levels ·", gained)
        P.small(top, x, y + 2, w - pw - 4, 16, levels, c[:dim], 1)
        y += 24
      end
      top.fill_rect(x, y + 4, w, 1, c[:line])
      cur = current
      if DC.egg_waiting?
        egg_picture(top, x + 16, y + 34, 30)
        P.text(top, x + 38, y + 14, w - 38, 20, _INTL("An Egg Is Waiting"), c[:gold], PF::TEXT)
        where = if EG.party.length < 6 then _INTL("It joins your party.")
                elsif (b = EG.room_box) then _INTL("Your party is full: It goes to {1}.", EG.box_name(b))
                else _INTL("Your party and the PC are full.")
                end
        P.small_wrap(top, where, w - 38).first(2).each_with_index { |ln, k| P.small(top, x + 38, y + 34 + k * 16, w - 38, 16, ln, c[:dim]) }
        lit = cur && cur[0] == :egg ? @dc_button : nil
        plate_buttons(base, top, c, x, w, [[:collect, _INTL("Collect")], [:discard, _INTL("Discard")]], lit)
      elsif slots.length == 1
        n = (@partner_count ||= DC.partners(anchor).length)
        P.text(top, x, y + 14, w, 20, _INTL("Find a Partner"), pink, PF::TEXT)
        text = n > 0 ? _INTL("{1} Pokémon in your party and boxes can breed with {2}. The best are first.", n, slots[0][0].name) :
                       _INTL("Nothing in your party or boxes can breed with {1}.", slots[0][0].name)
        P.small_wrap(top, text, w).first(3).each_with_index { |ln, k| P.small(top, x, y + 36 + k * 16, w, 16, ln, c[:dim]) }
      elsif slots.empty?
        P.small_wrap(top, _INTL("Deposit a Pokémon from your party or the PC."), w).first(2).each_with_index { |ln, k| P.small(top, x, y + 14 + k * 16, w, 16, ln, c[:dim]) }
      else
        P.small_wrap(top, _INTL("An Egg may come as you walk."), w).first(2).each_with_index { |ln, k| P.small(top, x, y + 14 + k * 16, w, 16, ln, c[:dim]) }
      end
    end

    # The Partner Finder's and Deposit's plate: the chosen one beside the one
    # there (how they'd get along), else alone
    def draw_pair_plate(base, top, c)
      pink = c[:pink]
      x = PX0 + 14
      w = PX1 - PX0 - 28
      cx = (PX0 + PX1) / 2
      cur = current
      plate(base, c, pink, PY0 + 128)
      return unless cur
      e = cur[0] == :partner ? cur[1][0] : cur[1]
      pk = e.pkmn
      a = anchor
      if a
        compat = cur[0] == :partner ? cur[1][1] : DC.compat_for(a, pk)
        show_icon(:pfl, a, cx - 50, PY0 + 34, 40)
        show_icon(:pfr, pk, cx + 50, PY0 + 34, 40)
        P.text(top, PX0, PY0 + 64, PX1 - PX0, 13, _INTL(COMPAT_WORDS[compat]).upcase, compat > 0 ? pink : c[:dim], PF::TINY, 2)
        compat_dots(top, c, cx, PY0 + 82, compat)
        chance_line(top, c, cx, PY0 + 100, compat) if compat > 0
      else
        show_icon(:pfr, pk, cx, PY0 + 50, 56)
      end
      y = PY0 + 140
      nw = P.text(top, x, y, 150, 20, PF.fit(PF::TEXT, pk.name.to_s, 140), c[:txt], PF::TEXT)
      gw = gender(top, c, pk, x + nw + 4, y + 6)
      P.small(top, x + nw + 4 + gw + 6, y + 2, 60, 16, _INTL("Lv {1}", pk.level), c[:dim])
      where = e.party? ? _INTL("Party, Slot {1}", e.slot + 1) : _INTL("{1}, Slot {2}", EG.box_name(e.box), e.slot + 1)
      P.small(top, x, y + 22, w, 16, where, c[:dim])
      if a
        why = DC.why(a, pk)
        P.small(top, x, y + 40, w, 16, why, c[:green]) unless why.empty?
        note = _INTL("Deposit it to join {1} in the Day Care.", a.name)
      else
        note = _INTL("Leave it at the Day Care.")
      end
      P.small_wrap(top, note, w).first(2).each_with_index { |ln, k| P.small(top, x, y + 64 + k * 16, w, 16, ln, c[:dim]) }
      plate_buttons(base, top, c, x, w, [[:deposit, _INTL("Deposit")], [:back, _INTL("Back")]], 0)
    end
  end
end
