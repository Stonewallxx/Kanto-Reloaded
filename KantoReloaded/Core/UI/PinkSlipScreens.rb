# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Trainer Control's Pink Slip screens
#==============================================================================
# His mix (Roadmap Designs topic trainer-control, 2026-10-31): Design 1's
# Header Plate popups with Design 3's Choose Your Stake, over the map:
#
#   Choose Your Stake  Face-Off: your stake (its picture, level, held item)
#                      VS their team (the class and name, each Pokémon and
#                      its level); your party below, a slot each, the reason
#                      under each you can't stake (FAINTED, BELOW LV. 12,
#                      CAN'T BATTLE); what winning and losing mean at the
#                      foot. Left / Right choose, Stake, Summary, Just Battle.
#   Claim Your Prize   their team in a list; the picked one's plate: types,
#                      ability, nature, moves, and "Hard Stone stays with
#                      Marcos." Up / Down choose, Claim, Summary.
#   Prize Claimed      a green plate: your prize, PINK SLIP, where it went
#   The loss           a red plate when you wake in the Pokémon Center:
#                      "Marcos Took Pidgeotto", "It goes with them now.", the
#                      held item back in your Bag
# No box behind the Pokémon in the two notices (his change).
#==============================================================================

return unless defined?(Reloaded::Frame) && defined?(::KIF::PixelFont) && defined?(Reloaded::PartyPaint)

module Reloaded
  # What the Pink Slip popups share: pictures, tiles, pills
  module PinkSlipDraw
    P = Reloaded::Pixel
    PF = ::KIF::PixelFont
    PP = Reloaded::PartyPaint
    DL = Reloaded::Dialogs

    def mix(a, b, t)
      return Reloaded::Palette.mix(a, b, t)
    end

    def picture(path)
      @pictures ||= {}
      return @pictures[path] if @pictures.key?(path)
      resolved = defined?(pbResolveBitmap) ? (pbResolveBitmap(path) || path) : path
      return @pictures[path] = (Bitmap.new(resolved) rescue nil)
    end

    def drop_pictures
      (@pictures || {}).each_value { |b| b.dispose if b && !b.disposed? }
      (@mons || {}).each_value { |b, _r| b.dispose if b && !b.disposed? }
      @pictures = {}
      @mons = {}
    end

    # A species' picture (Big Pokémon Icons as the player has them)
    def mon(b, species, cx, cy, size, opacity = 255)
      @mons ||= {}
      bm, r = (@mons[species.to_s] ||= begin
        pic = species.to_s == "EGG" ? Reloaded::PartyIcons.egg_bitmap : Reloaded::PartyIcons.species_bitmap(species.to_s.to_sym)
        [pic, pic ? Reloaded::PartyIcons.art_rect(pic, [pic.height, 1].max) : nil]
      end)
      return unless bm
      z = size.to_f / [r.width, r.height, 1].max
      w = (r.width * z).round
      h = (r.height * z).round
      b.stretch_blt(Rect.new(cx - w / 2, cy - h / 2, w, h), bm, r, opacity)
    end

    def item_pic(b, item, x, y, size)
      bm = picture((::GameData::Item.icon_filename(item) rescue nil) || "Graphics/Items/#{item}")
      b.stretch_blt(Rect.new(x, y, size, size), bm, Rect.new(0, 0, bm.width, bm.height)) if bm
    end

    def item_name(item)
      return (::GameData::Item.get(item).name rescue item.to_s)
    end

    def species_name(sp)
      return (::GameData::Species.get(sp.to_s.to_sym).name rescue sp.to_s)
    end

    def type_col(type)
      return PP.rgb(Reloaded::PartyScreen.type_rgb(type))
    end

    def type_ink(c, type)
      return PP.ink(c, Reloaded::PartyScreen.type_rgb(type))
    end

    def types_of(sp)
      d = (::GameData::Species.get(sp.to_s.to_sym) rescue nil)
      return d ? [d.type1, d.type2].compact.uniq : [:NORMAL]
    end

    def small_type(b, type, x, y)
      sheet = picture(PP::TYPES_SMALL)
      b.blt(x, y, sheet, Rect.new(0, PP.type_row(type) * 16, 16, 16)) if sheet
    end

    def big_types(b, types, x, y, lw = 40, lh = 18)
      sheet = PP.type_sheet
      return unless sheet
      types.each_with_index { |t, i| b.stretch_blt(Rect.new(x + i * (lw + 3), y, lw, lh), sheet, Rect.new(0, PP.type_row(t) * 28, 64, 28)) }
    end

    def tile(b, c, x0, y0, x1, y1, col, k = 0.35, cut = 8)
      PP.chamfer_grad(b, x0, y0, x1, y1, cut, mix(c[:panel2], col, k), mix(c[:panel2], c[:dark], 0.35), mix(c[:line], col, 0.5))
    end

    def pill(b, c, x, y, label, key, right = false)
      fill, ink = Reloaded::Toast.pill_colours(c, key == :grey ? :dim : key)
      fill = c[:light] ? mix(c[:panel2], c[:dim], 0.22) : Color.new(36, 40, 48) if key == :grey
      return P.pill(b, x, y, label, fill, ink, right)
    end

    def level_text(b, c, lv, x, y, w = 50, align = 0)
      P.text(b, x, y, w, 12, _INTL("Lv. {1}", lv), c[:gold], PF::TINY, align)
    end

    def hp_bar(b, c, pk, x, y, w)
      frac = pk.hp.to_f / [pk.totalhp, 1].max
      col = frac > 0.5 ? c[:green] : (frac > 0.25 ? c[:amber] : c[:red])
      PP.bar(b, c, x, y, w, frac, col, 3)
    end

    def popup_hints(b, c, pairs)
      P.hints(b, b, c, pairs, Reloaded::Prompts.style)
    end
  end

  #============================================================================
  # Choose Your Stake (Design 3, Face-Off): the party index staked, or nil
  #============================================================================
  class PinkSlipStake
    include Reloaded::Frame
    include Reloaded::PinkSlipDraw

    PS = Reloaded::TrainerControl::PinkSlips
    NUMBERS = ["none", "one", "two", "three", "four", "five", "six"].freeze

    attr_reader :sel

    def initialize(title, name, team)
      frame_init
      @title = title
      @name = name
      @team = Array(team).first(6)
      @party = PS.party.first(6)
      @sel = PS.stakes.first || 0
    end

    def run
      open_sprites
      @icons = @party.map { |pk| Reloaded::PartyIcons.icon(pk, @viewport, 4) }
      @rects = @icons.map { |s| s && s.bitmap ? Reloaded::PartyIcons.art_rect(s.bitmap, [s.src_rect.height, 1].max) : nil }
      refresh
      loop do
        Graphics.update
        Input.update
        update_frame
        @icons.each { |s| s.update if s && !s.disposed? && s.respond_to?(:update) }
        r = handle_input
        return r[1] if r.is_a?(Array)
      end
    ensure
      (@icons || []).each { |s| s.dispose if s && !s.disposed? }
      drop_pictures
      dispose_sprites
    end

    def refresh
      draw if @sprite && !@sprite.disposed?
    end

    private

    def sprites
      return super + (@icons || []).compact.reject(&:disposed?)
    end

    def handle_input
      pt = Reloaded::Pointer
      if pointer_hover && (k = pt.hit(@hits || [])) && k != @sel
        @sel = k
        refresh
      end
      if Input.trigger?(Input::BACK) || pt.right?
        pbPlayCancelSE
        return [:done, nil]
      elsif Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT) || Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)
        dir = Input.trigger?(Input::RIGHT) || Input.repeat?(Input::DOWN) ? 1 : -1
        @sel = (@sel + dir) % @party.length
        pbPlayCursorSE
        refresh
      elsif Input.trigger?(Input::USE) || (pt.left? && pt.hit(@hits || []))
        return pbPlayBuzzerSE if PS.stake_reason(@party[@sel])
        pbPlayDecisionSE
        return [:done, @sel]
      elsif Input.trigger?(Input::ACTION)
        summary
      end
      return nil
    end

    def summary
      pbPlayDecisionSE
      hidden { ::PokemonSummaryScreen.new(::PokemonSummary_Scene.new).pbStartScreen(@party, @sel) } if defined?(::PokemonSummaryScreen)
      refresh
    end

    def fit_icon(i, cx, cy, box, opacity)
      s = @icons[i]
      r = @rects[i]
      return unless s && r && !s.disposed?
      s.zoom_x = s.zoom_y = box.to_f / [r.width, r.height, 1].max
      s.ox = r.x + r.width / 2
      s.oy = r.y + r.height / 2
      s.x = cx
      s.y = cy
      s.opacity = opacity
      s.visible = true
    end

    def win_lose(b, c, x, y, w, pk)
      lines = [[[_INTL("Win: "), c[:green], true], [_INTL("Claim any one of {1}'s {2}.", @name, _INTL(NUMBERS[@team.length] || @team.length.to_s)), c[:txt]]]]
      item = pk.item_id rescue nil
      lose = item ? _INTL("{1} keeps {2}. Its {3} comes back to you.", @name, pk.name, item_name(item)) : _INTL("{1} keeps {2}.", @name, pk.name)
      lines << [[_INTL("Lose: "), c[:red], true], [lose, c[:txt]]]
      lines.each_with_index { |segs, i| P.small_rich(b, x, y + i * 17, w, 17, segs) }
    end

    def draw
      c = palette
      [@sprite.bitmap, @top_sprite.bitmap, overlay].each(&:clear)
      b = overlay
      w = 492
      h = 300
      x = 10
      y = (H - P::HINT_H - h) / 2
      DL.frame(b, c, x, y, w, h, _INTL("Choose Your Stake"))
      pk = @party[@sel]
      # the stage: your stake, VS, their team
      sx0 = x + 10
      sx1 = x + 210
      tile(b, c, sx0, y + 44, sx1, y + 140, type_col(PS.stake_reason(pk) ? :NORMAL : (pk.types.last rescue :NORMAL)), 0.32, 10)
      @stake_icon_at = [sx0 + 44, y + 92]
      P.text(b, sx0 + 84, y + 62, sx1 - sx0 - 88, 18, PF.fit(PF::TEXT, pk.name.to_s, sx1 - sx0 - 88), c[:strong], PF::TEXT)
      level_text(b, c, pk.level, sx0 + 85, y + 82) unless pk.egg?
      item = pk.item_id rescue nil
      if item
        item_pic(b, item, sx0 + 84, y + 98, 24)
        P.small(b, sx0 + 110, y + 102, sx1 - sx0 - 114, 16, PF.fit(PF::TINY, item_name(item), sx1 - sx0 - 114), c[:dim])
      end
      P.text(b, sx1, y + 80, 30, 24, _INTL("VS"), c[:red], PF::ROW, 2)
      hx0 = sx1 + 30
      hx1 = x + w - 10
      lead = @team.max_by { |_sp, lv| lv.to_i }
      tile(b, c, hx0, y + 44, hx1, y + 140, type_col(lead ? types_of(lead[0]).first : :NORMAL), 0.32, 10)
      P.text(b, hx0 + 10, y + 50, hx1 - hx0 - 20, 12, @title.upcase, c[:head], PF::TINY)
      step = (hx1 - hx0 - 16) / [@team.length, 4].max
      @team.each_with_index do |(sp, lv), i|
        cx = hx0 + 8 + step * i + step / 2
        mon(b, sp, cx, y + 92, [42, step - 4].min)
        level_text(b, c, lv, cx - 25, y + 118, 50, 2)
      end
      # your party, a slot each
      slot = (w - 20) / 6
      @hits = []
      @party.each_with_index do |pm, i|
        px = x + 10 + i * slot
        why = PS.stake_reason(pm)
        if i == @sel
          fill, edge = Reloaded::Palette.cursor(nil, c)
          PP.chamfer(b, px + 2, y + 150, px + slot - 2, y + 228, 8, Reloaded::Palette.over(c[:panel2], fill), Reloaded::Palette.over(c[:panel2], edge))
        else
          PP.chamfer(b, px + 2, y + 150, px + slot - 2, y + 228, 8, mix(c[:panel2], c[:dark], 0.35), mix(c[:panel2], c[:line], 0.6))
        end
        fit_icon(i, px + slot / 2, y + 180, 40, why ? 120 : 255)
        if why
          lw = P.width(PF::TINY, why[0]) + 10
          if lw > slot - 6
            P.text(b, px, y + 210, slot, 12, why[0], c[why[1] == :grey ? :dim : why[1]] || c[:dim], PF::TINY, 2)
          else
            pill(b, c, px + (slot - lw) / 2, y + 208, why[0], why[1])
          end
        else
          level_text(b, c, pm.level, px, y + 210, slot, 2)
        end
        @hits << [i, px + 2, y + 150, px + slot - 2, y + 228]
      end
      win_lose(b, c, x + 10, y + h - 42, w - 20, pk)
      popup_hints(b, c, [[:lr, _INTL("Choose")], [button(:C), _INTL("Stake")], [button(:A), _INTL("Summary")], [button(:B), _INTL("Just Battle")]])
      big_icon(pk)
    end

    # The stake on the stage: the game's own icon (its look, Ghostly
    # Possession's too), made again when the stake changes
    def big_icon(pk)
      if @big_for != pk
        @big.dispose if @big && !@big.disposed?
        @big = Reloaded::PartyIcons.icon(pk, @viewport, 4)
        @big_rect = @big && @big.bitmap ? Reloaded::PartyIcons.art_rect(@big.bitmap, [@big.src_rect.height, 1].max) : nil
        @big_for = pk
        @icons << @big if @big
      end
      return unless @big && @big_rect
      @big.zoom_x = @big.zoom_y = 64.0 / [@big_rect.width, @big_rect.height, 1].max
      @big.ox = @big_rect.x + @big_rect.width / 2
      @big.oy = @big_rect.y + @big_rect.height / 2
      @big.x, @big.y = @stake_icon_at
      @big.opacity = PS.stake_reason(pk) ? 120 : 255
      @big.visible = true
    end
  end

  #============================================================================
  # Claim Your Prize (Design 1): the index claimed
  #============================================================================
  class PinkSlipClaim
    include Reloaded::Frame
    include Reloaded::PinkSlipDraw

    attr_reader :sel

    def initialize(title, name, team)
      frame_init
      @title = title
      @name = name
      @team = Array(team).first(6)
      @sel = [@team.each_index.max_by { |i| @team[i].level.to_i } || 0, 0].max
    end

    def run
      open_sprites
      refresh
      loop do
        Graphics.update
        Input.update
        update_frame
        r = handle_input
        return r[1] if r.is_a?(Array)
      end
    ensure
      drop_pictures
      dispose_sprites
    end

    def refresh
      draw if @sprite && !@sprite.disposed?
    end

    private

    def handle_input
      pt = Reloaded::Pointer
      if pointer_hover && (k = pt.hit(@hits || [])) && k != @sel
        @sel = k
        refresh
      end
      if Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)
        @sel = (@sel + (Input.repeat?(Input::DOWN) ? 1 : -1)) % @team.length
        pbPlayCursorSE
        refresh
      elsif Input.trigger?(Input::USE) || (pt.left? && pt.hit(@hits || []))
        pbPlayDecisionSE
        return [:done, @sel]
      elsif Input.trigger?(Input::ACTION)
        pbPlayDecisionSE
        hidden { ::PokemonSummaryScreen.new(::PokemonSummary_Scene.new).pbStartScreen(@team, @sel, false) } if defined?(::PokemonSummaryScreen)
        refresh
      end
      return nil
    end

    # The details plate (the Party Screen's): picture, types, ability,
    # nature, moves, its item staying with them
    def details(b, c, pk, x0, y0, x1, y1)
      types = (pk.types rescue types_of(pk.species))
      col = type_col(types.first)
      topc = mix(c[:panel], col, 0.32)
      PP.chamfer_grad(b, x0, y0, x1, y1, 14, topc, mix(c[:panel], c[:dark], 0.4), mix(c[:line], col, 0.5))
      b.fill_rect(x0 + 8, y0 + 74, x1 - x0 - 16, 2, PP::POKE_RED)
      mon(b, pk.species, x0 + 40, y0 + 38, 60)
      nx = x0 + 80
      P.text(b, nx, y0 + 8, x1 - nx - 8, 22, PF.fit(PF::ROW, pk.name.to_s, x1 - nx - 8), type_ink(c, types.first), PF::ROW)
      level_text(b, c, pk.level, nx + 1, y0 + 32)
      big_types(b, types, nx, y0 + 48)
      rows = [[_INTL("Ability"), (pk.ability.name rescue "-")], [_INTL("Nature"), (pk.nature.name rescue "-")]]
      rows.each_with_index do |(k, v), j|
        P.small(b, x0 + 12, y0 + 82 + j * 16, 60, 16, k, c[:dim])
        P.small(b, x0 + 70, y0 + 82 + j * 16, x1 - x0 - 80, 16, v.to_s, c[:txt])
      end
      P.heading(b, x0 + 12, x1 - 12, y0 + 120, _INTL("Moves"), c[:dim], c[:line])
      cw = (x1 - x0 - 24) / 2
      Array(pk.moves).each_with_index do |m, j|
        d = (::GameData::Move.get(m.id) rescue nil)
        next unless d
        mx = x0 + 12 + (j % 2) * cw
        my = y0 + 134 + (j / 2) * 18
        b.fill_rect(mx, my + 3, 4, 11, type_col(d.type))
        P.text(b, mx + 8, my, cw - 10, 16, PF.fit(PF::TEXT, d.name, cw - 10), c[:txt], PF::TEXT)
      end
      iy = y1 - 22
      item = pk.item_id rescue nil
      if item
        item_pic(b, item, x0 + 10, iy - 2, 24)
        P.small(b, x0 + 38, iy + 2, x1 - x0 - 48, 16, _INTL("{1} stays with {2}.", item_name(item), @name), c[:dim])
      else
        P.small(b, x0 + 12, iy + 2, x1 - x0 - 24, 16, _INTL("No held item."), c[:dim])
      end
    end

    def draw
      c = palette
      [@sprite.bitmap, @top_sprite.bitmap, overlay].each(&:clear)
      b = overlay
      w = 492
      h = 44 + [@team.length, 4].max * 48 + 10
      x = 10
      y = (H - P::HINT_H - h) / 2
      DL.frame(b, c, x, y, w, h, _INTL("Claim Your Prize"))
      lx1 = x + 184
      @hits = []
      @team.each_with_index do |pk, i|
        ry = y + 44 + i * 48
        DL.send(:cursor_row, b, c, x + 6, ry, lx1, ry + 45) if i == @sel
        types = (pk.types rescue types_of(pk.species))
        mon(b, pk.species, x + 30, ry + 22, 38)
        P.text(b, x + 56, ry + 4, lx1 - x - 60, 18, PF.fit(PF::TEXT, pk.name.to_s, lx1 - x - 62), type_ink(c, types.first), PF::TEXT)
        level_text(b, c, pk.level, x + 57, ry + 26)
        types.each_with_index { |t, k| small_type(b, t, x + 98 + k * 18, ry + 24) }
        @hits << [i, x + 6, ry, lx1, ry + 45]
      end
      details(b, c, @team[@sel], lx1 + 8, y + 42, x + w - 8, y + h - 8) if @team[@sel]
      popup_hints(b, c, [[:ud, _INTL("Choose")], [button(:C), _INTL("Claim")], [button(:A), _INTL("Summary")]])
    end
  end

  #============================================================================
  # The two notices (Design 1): Prize Claimed, and the loss
  #============================================================================
  class PinkSlipNotice
    include Reloaded::Frame
    include Reloaded::PinkSlipDraw

    def self.claimed(pk, where)
      new(:claimed, pk, where).run
    end

    def self.lost(due)
      new(:lost, due, nil).run
    end

    def initialize(kind, what, where)
      frame_init
      @kind = kind
      @what = what
      @where = where
    end

    def run
      open_sprites
      draw
      pbMEPlay("Pkmn get") rescue nil if @kind == :claimed
      loop do
        Graphics.update
        Input.update
        update_frame
        pt = Reloaded::Pointer
        break if Input.trigger?(Input::USE) || Input.trigger?(Input::BACK) || pt.left? || pt.right?
      end
      pbPlayDecisionSE
      return true
    ensure
      drop_pictures
      dispose_sprites
    end

    def refresh
      draw if @sprite && !@sprite.disposed?
    end

    private

    def draw
      c = palette
      [@sprite.bitmap, @top_sprite.bitmap, overlay].each(&:clear)
      @kind == :claimed ? draw_claimed(overlay, c) : draw_lost(overlay, c)
      popup_hints(overlay, c, [[button(:C), _INTL("OK")]])
    end

    def draw_claimed(b, c)
      DL.send(:dim, b)
      w = 340
      h = 168
      x = (W - w) / 2
      y = (H - P::HINT_H - h) / 2
      green = c[:green]
      DL.send(:panel, b, c, x, y, w, h, green)
      DL.send(:title_bar, b, c, x, y, w, _INTL("Prize Claimed"), green, green, green)
      pk = @what
      types = (pk.types rescue types_of(pk.species))
      mon(b, pk.species, x + 51, y + 81, 58)
      P.text(b, x + 98, y + 48, w - 108, 22, PF.fit(PF::ROW, pk.name.to_s, w - 108), type_ink(c, types.first), PF::ROW)
      lv = _INTL("Lv. {1}", pk.level)
      level_text(b, c, pk.level, x + 99, y + 72)
      pill(b, c, x + 99 + P.width(PF::TINY, lv) + 8, y + 72, _INTL("PINK SLIP"), :pink)
      P.small_wrap(b, @where.to_s, w - 108).first(2).each_with_index { |ln, i| P.small(b, x + 98, y + 90 + i * 15, w - 108, 16, ln, c[:txt]) }
      DL.button_row(b, c, x, w, y + h - 36, [_INTL("OK")], 0)
    end

    def draw_lost(b, c)
      DL.send(:dim, b)
      w = 360
      h = 176
      x = (W - w) / 2
      y = (H - P::HINT_H - h) / 2
      red = c[:red]
      d = @what
      DL.send(:panel, b, c, x, y, w, h, red)
      DL.send(:title_bar, b, c, x, y, w, _INTL("{1} Took {2}", d["name"], d["pokemon"]), red, red, red)
      mon(b, d["species"], x + 51, y + 81, 58, 110)
      P.text(b, x + 98, y + 46, w - 108, 18, _INTL("It goes with them now."), c[:txt], PF::TEXT)
      if d["item"]
        item_pic(b, d["item"], x + 98, y + 72, 24)
        P.small_wrap(b, _INTL("Its {1} came back to your Bag.", item_name(d["item"])), w - 140).first(2).each_with_index do |ln, i|
          P.small(b, x + 126, y + 70 + i * 16, w - 136, 16, ln, c[:dim])
        end
      end
      DL.button_row(b, c, x, w, y + h - 36, [_INTL("OK")], 0)
    end
  end
end
