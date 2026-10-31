# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Trainer Control's bond moments
#==============================================================================
# His pick (Roadmap Designs topic trainer-control, 2026-10-31): Design 1,
# Words and a Card. Back on the map after a win that reaches a bond step:
#
#   Gift   the trainer speaks in the game's message box while a Header
#          Plate card above it shows the gift (its picture, name and
#          description) and the bond track (done gold, next blue); then the
#          game's own "obtained" message
#   Egg    the same card with the Egg (their ace's first stage)
#   Tutor  "Marcos Teaches a Move": your party, each marked ABLE, LEARNED or
#          NOT ABLE, and what the highlighted one can learn from their
#          team; then "Teach <Pokémon>": their moves with type, category,
#          power, accuracy and "From <their Pokémon>", the description
#          under them.
#          The game's own move learning teaches it (forgetting one too).
#          Back asks first: skipping the lesson is final (a claimed step
#          stays claimed).
#==============================================================================

return unless defined?(Reloaded::Frame) && defined?(::KIF::PixelFont) && defined?(Reloaded::PartyPaint)

module Reloaded
  module BondMoments
    P = Reloaded::Pixel
    PF = ::KIF::PixelFont
    PP = Reloaded::PartyPaint
    DL = Reloaded::Dialogs
    BOND = Reloaded::TrainerControl::Bond
    W = 512
    H = 384
    CARD_W = 380
    CARD_H = 176

    module_function

    def who(rec)
      return (rec["shown"] || rec["name"]).to_s
    end

    def mix(a, b, t)
      return Reloaded::Palette.mix(a, b, t)
    end

    #--------------------------------------------------------------------------
    # The card above the message box, while the trainer speaks
    #--------------------------------------------------------------------------
    def with_card(title)
      c = Reloaded::Palette.map_menu
      vp = Viewport.new(0, 0, W, H)
      vp.z = 99_998                        # (under the message box)
      s = Sprite.new(vp)
      s.bitmap = Bitmap.new(W, H)
      x = (W - CARD_W) / 2
      y = H - 96 - CARD_H - 12
      DL.send(:panel, s.bitmap, c, x, y, CARD_W, CARD_H)
      DL.send(:title_bar, s.bitmap, c, x, y, CARD_W, title)
      yield s.bitmap, c, x, y
      return s
    end

    def drop(card)
      return unless card
      vp = card.viewport
      card.bitmap.dispose if card.bitmap && !card.bitmap.disposed?
      card.dispose unless card.disposed?
      vp.dispose if vp && !vp.disposed?
    end

    def speak(card, words)
      pbMessage(words) if defined?(pbMessage)
    ensure
      drop(card)
    end

    # A soft patch (no edge) and a picture in it
    def soft(b, c, x0, y0, x1, y1, col, k)
      P.ui.rbox(b, x0, y0, x1, y1, 8, mix(c[:panel2], col, k))
    end

    def picture(path)
      resolved = defined?(pbResolveBitmap) ? (pbResolveBitmap(path) || path) : path
      return (Bitmap.new(resolved) rescue nil)
    end

    def item_pic(b, item, x, y, size)
      bm = picture((::GameData::Item.icon_filename(item) rescue nil) || "Graphics/Items/#{item}")
      return unless bm
      b.stretch_blt(Rect.new(x, y, size, size), bm, Rect.new(0, 0, bm.width, bm.height))
      bm.dispose
    end

    def mon_pic(b, species, cx, cy, size)
      bm = species == :EGG ? Reloaded::PartyIcons.egg_bitmap : Reloaded::PartyIcons.species_bitmap(species)
      return unless bm
      r = Reloaded::PartyIcons.art_rect(bm, [bm.height, 1].max)
      z = size.to_f / [r.width, r.height, 1].max
      w = (r.width * z).round
      h = (r.height * z).round
      b.stretch_blt(Rect.new(cx - w / 2, cy - h / 2, w, h), bm, r)
      bm.dispose
    end

    # The bond track: the three steps shown, done gold, the next blue,
    # later dim, a bar to the last one reached
    def track(b, c, rec, x0, x1, y)
      steps = BOND.shown(rec)
      wins = rec["wins"].to_i
      pts = steps.each_index.map { |i| x0 + ((x1 - x0) * i / [steps.length - 1, 1].max.to_f).round }
      done = steps.count { |_k, at| wins >= at }
      frac = done <= 1 ? 0.0 : (done - 1).to_f / [steps.length - 1, 1].max
      PP.bar(b, c, x0, y, x1 - x0, frac, c[:gold], 3)
      nxt = BOND.next_step(rec)[1]
      steps.each_with_index do |(kind, at), i|
        col = wins >= at ? c[:gold] : (at == nxt ? c[:blue] : c[:dim])
        PP.disc(b, pts[i], y + 1, 6, c[:light] ? c[:panel2] : c[:dark])
        PP.disc(b, pts[i], y + 1, 5, col)
        word = BOND.word(kind).upcase
        lw = P.width(PF::TINY, word)
        P.text(b, [[pts[i] - lw / 2, x0 - 4].max, x1 + 4 - lw].min, y + 9, lw + 2, 12, word, col, PF::TINY)
        P.text(b, pts[i] - 12, y - 15, 24, 12, at.to_s, col, PF::TINY, 2)
      end
    end

    def gift(rec, at, item)
      d = (::GameData::Item.get(item) rescue nil)
      name = d ? d.name : item.to_s
      card = with_card(_INTL("Gift From {1}", who(rec))) do |b, c, x, y|
        soft(b, c, x + 14, y + 46, x + 70, y + 102, c[:gold], 0.16)
        item_pic(b, item, x + 18, y + 50, 48)
        P.text(b, x + 82, y + 44, CARD_W - 92, 18, name, c[:strong], PF::TEXT)
        P.small_wrap(b, d ? d.description.to_s : "", CARD_W - 96).first(4).each_with_index do |ln, i|
          P.small(b, x + 82, y + 64 + i * 15, CARD_W - 92, 16, ln, c[:dim])
        end
        track(b, c, rec, x + 40, x + CARD_W - 40, y + CARD_H - 34)
      end
      speak(card, _INTL("You keep getting stronger every time we battle. You've earned this {1}!", name))
    end

    def egg(rec, at, species)
      sp = (::GameData::Species.get(species) rescue nil)
      name = sp ? sp.name : species.to_s
      card = with_card(_INTL("Egg From {1}", who(rec))) do |b, c, x, y|
        soft(b, c, x + 14, y + 46, x + 78, y + 110, c[:green], 0.14)
        mon_pic(b, :EGG, x + 46, y + 78, 58)
        P.text(b, x + 90, y + 46, CARD_W - 100, 18, _INTL("{1} Egg", name), c[:strong], PF::TEXT)
        P.small_wrap(b, _INTL("An Egg of {1}'s favourite Pokémon. Raise it well.", who(rec)), CARD_W - 104).first(3).each_with_index do |ln, i|
          P.small(b, x + 90, y + 66 + i * 15, CARD_W - 100, 16, ln, c[:dim])
        end
        track(b, c, rec, x + 40, x + CARD_W - 40, y + CARD_H - 34)
      end
      speak(card, _INTL("My {1} had an Egg. I'd like you to raise it!", name))
    end

    # The tutor: the move taught, or nil (the lesson skipped)
    def tutor(rec, at, moves)
      pbMessage(_INTL("You've got a strong team. Let one of yours learn a move from mine!")) if defined?(pbMessage)
      return BondTutor.new(rec, moves).run
    end
  end

  #============================================================================
  # The tutor's two popups over the map
  #============================================================================
  class BondTutor
    include Reloaded::Frame

    PF = ::KIF::PixelFont
    PP = Reloaded::PartyPaint
    DL = Reloaded::Dialogs
    CATEGORY = "Graphics/Pictures/category"
    WHO_W = 460
    WHO_H = 270
    MOVE_W = 430

    attr_reader :sel, :mode, :pick

    def initialize(rec, moves)
      frame_init
      @rec = rec
      @moves = Array(moves).map { |m, s| [m.to_s.to_sym, s.to_s] }.select { |m, _s| (::GameData::Move.exists?(m) rescue false) }
      @party = ($Trainer ? $Trainer.party : []).compact.first(6)
      @sel = [@party.index { |pk| note(pk) == :able } || 0, 0].max
      @mode = :who
      @pick = 0
      @pictures = {}
      @icons = []
    end

    def run
      open_sprites
      @icons = @party.map { |pk| Reloaded::PartyIcons.icon(pk, @viewport, 4) }   # over the popup
      @icon_rects = @icons.map { |s| s && s.bitmap ? Reloaded::PartyIcons.art_rect(s.bitmap, [s.src_rect.height, 1].max) : nil }
      refresh
      loop do
        Graphics.update
        Input.update
        update_frame
        @icons.each { |s| s.update if s && !s.disposed? && s.respond_to?(:update) }
        r = handle_input
        return r[1] if r.is_a?(Array) && r[0] == :done
      end
    ensure
      @icons.each { |s| s.dispose if s && !s.disposed? }
      @pictures.each_value { |b| b.dispose if b && !b.disposed? }
      dispose_sprites
    end

    def refresh
      draw if @sprite && !@sprite.disposed?
    end

    def who
      return (@rec["shown"] || @rec["name"]).to_s
    end

    # What its moves from his team are for one of yours
    def learnable(pk)
      return [] if pk.nil? || pk.egg?
      return @moves.select { |m, _s| !pk.hasMove?(m) && (pk.compatible_with_move?(m) rescue false) }
    end

    def note(pk)
      return nil if pk.nil? || pk.egg?
      return :able unless learnable(pk).empty?
      return :learned if @moves.any? { |m, _s| pk.hasMove?(m) }
      return :cant
    end

    private

    def sprites
      return super + @icons.compact.reject(&:disposed?)
    end

    def show_icons(on)
      @icons.each { |s| s.visible = on if s && !s.disposed? }
    end

    #--------------------------------------------------------------------------
    # Input
    #--------------------------------------------------------------------------
    def handle_input
      pt = Reloaded::Pointer
      if pointer_hover && (k = pt.hit(@row_hits || [])) && k != current_index
        set_index(k)
        refresh
      end
      if Input.trigger?(Input::BACK) || pt.right?
        return back
      elsif Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)
        n = @mode == :who ? @party.length : learnable(@party[@sel]).length
        return nil if n == 0
        set_index((current_index + (Input.repeat?(Input::DOWN) ? 1 : -1)) % n)
        pbPlayCursorSE
        refresh
      elsif Input.trigger?(Input::USE) || (pt.left? && pt.hit(@row_hits || []))
        return choose
      elsif Input.trigger?(Input::ACTION) && @mode == :who
        summary
      end
      return nil
    end

    def current_index
      return @mode == :who ? @sel : @pick
    end

    def set_index(i)
      @mode == :who ? @sel = i : @pick = i
    end

    def choose
      pk = @party[@sel]
      if @mode == :who
        return pbPlayBuzzerSE unless note(pk) == :able
        pbPlayDecisionSE
        @mode = :move
        @pick = 0
        refresh
        return nil
      end
      move, _from = learnable(pk)[@pick]
      return nil unless move
      pbPlayDecisionSE
      learned = false
      hidden { learned = pbLearnMove(pk, move) ? true : false }
      if learned
        return [:done, move]
      end
      @mode = :who
      refresh
      return nil
    end

    def back
      if @mode == :move
        pbPlayCancelSE
        @mode = :who
        refresh
        return nil
      end
      show_icons(false)
      skip = DL.confirm(self, _INTL("Skip the Lesson?"), _INTL("{1} won't offer this lesson again.", who), _INTL("Skip"), _INTL("Keep Choosing"), false)
      refresh
      return skip ? [:done, nil] : nil
    end

    def summary
      pk = @party[@sel]
      return pbPlayBuzzerSE if pk.nil? || !defined?(::PokemonSummaryScreen)
      pbPlayDecisionSE
      hidden do
        scene = ::PokemonSummary_Scene.new
        ::PokemonSummaryScreen.new(scene).pbStartScreen(@party, @sel)
      end
      refresh
    end

    #--------------------------------------------------------------------------
    # Drawing (on the popup layer, over the map)
    #--------------------------------------------------------------------------
    def picture(path)
      return @pictures[path] if @pictures.key?(path)
      resolved = defined?(pbResolveBitmap) ? (pbResolveBitmap(path) || path) : path
      return @pictures[path] = (Bitmap.new(resolved) rescue nil)
    end

    def mix(a, b, t)
      return Reloaded::Palette.mix(a, b, t)
    end

    def small_type(b, type, x, y)
      sheet = picture(PP::TYPES_SMALL)
      b.blt(x, y, sheet, Rect.new(0, PP.type_row(type) * 16, 16, 16)) if sheet
    end

    def category(b, cat, x, y)
      sheet = picture(CATEGORY)
      b.stretch_blt(Rect.new(x, y, 32, 14), sheet, Rect.new(0, cat.to_i * 28, 64, 28)) if sheet
    end

    def tone_pill(b, c, x, y, label, key, right = false)
      tone = c[key] || c[:dim]
      fill = c[:light] ? mix(c[:panel2], tone, 0.22) : mix(c[:panel2], tone, 0.28)
      return P.pill(b, x, y, label, fill, tone, right)
    end

    def draw
      c = palette
      [@sprite.bitmap, @top_sprite.bitmap, overlay].each(&:clear)
      @cursor_rect = nil
      @row_hits = []
      @mode == :who ? draw_who(overlay, c) : draw_move(overlay, c)
      P.hints(overlay, overlay, c, popup_hints, Reloaded::Prompts.style)
    end

    def popup_hints
      return [[:ud, _INTL("Choose")], [button(:C), _INTL("Teach")], [button(:B), _INTL("Back")]] if @mode == :move
      return [[:ud, _INTL("Choose")], [button(:C), _INTL("Teach")], [button(:A), _INTL("Summary")], [button(:B), _INTL("Cancel")]]
    end

    def fit_icon(i, cx, cy, box, faded)
      s = @icons[i]
      r = (@icon_rects || [])[i]
      return unless s && r && !s.disposed?
      s.zoom_x = s.zoom_y = box.to_f / [r.width, r.height, 1].max
      s.ox = r.x + r.width / 2
      s.oy = r.y + r.height / 2
      s.x = cx
      s.y = cy
      s.opacity = faded ? 140 : 255
      s.visible = true
    end

    def draw_who(b, c)
      x = (W - WHO_W) / 2
      y = (H - P::HINT_H - WHO_H) / 2
      DL.frame(b, c, x, y, WHO_W, WHO_H, _INTL("{1} Teaches a Move", who))
      lx1 = x + 232
      @party.each_with_index do |pk, i|
        ry = y + 42 + i * 36
        n = note(pk)
        off = n != :able
        DL.send(:cursor_row, b, c, x + 6, ry, lx1, ry + 33) if i == @sel
        fit_icon(i, x + 26, ry + 17, 30, off)
        P.text(b, x + 46, ry + 2, 110, 18, pk.name.to_s, off ? c[:dim] : (i == @sel ? c[:strong] : c[:txt]), PF::TEXT)
        P.text(b, x + 47, ry + 20, 60, 12, _INTL("Lv. {1}", pk.level), c[:gold], PF::TINY) unless pk.egg?
        @row_hits << [i, x + 6, ry, lx1, ry + 33]
        next unless n
        label, key = { :able => [_INTL("ABLE"), :green], :learned => [_INTL("LEARNED"), :blue], :cant => [_INTL("NOT ABLE"), :dim] }[n]
        tone_pill(b, c, lx1 - 8, ry + 10, label, key, true)
      end
      rx = lx1 + 12
      pk = @party[@sel]
      P.heading(b, rx, x + WHO_W - 10, y + 44, pk && !pk.egg? ? _INTL("{1} Can Learn", pk.name) : _INTL("Can Learn"), c[:dim], c[:line])
      list = learnable(pk)
      if list.empty?
        P.small(b, rx, y + 60, x + WHO_W - 10 - rx, 16, _INTL("Nothing from {1}'s team.", who), c[:dim])
      end
      list.first(8).each_with_index do |(m, _from), j|
        d = ::GameData::Move.get(m)
        my = y + 60 + j * 20
        b.fill_rect(rx, my + 4, 4, 11, PP.rgb(Reloaded::PartyScreen.type_rgb(d.type)))
        P.text(b, rx + 8, my + 1, x + WHO_W - 18 - rx, 18, PF.fit(PF::TEXT, d.name, x + WHO_W - 18 - rx), c[:txt], PF::TEXT)
      end
      P.small_wrap(b, _INTL("Moves from {1}'s team that it can learn.", who), x + WHO_W - 10 - rx).first(2).each_with_index do |ln, i|
        P.small(b, rx, y + WHO_H - 42 + i * 15, x + WHO_W - 10 - rx, 16, ln, c[:dim])
      end
    end

    def draw_move(b, c)
      show_icons(false)
      pk = @party[@sel]
      list = learnable(pk)
      rows = [list.length, 1].max
      h = 40 + rows * 26 + 8 + 62
      x = (W - MOVE_W) / 2
      y = (H - P::HINT_H - h) / 2
      DL.frame(b, c, x, y, MOVE_W, h, _INTL("Teach {1}", pk.name))
      list.each_with_index do |(m, from), j|
        d = ::GameData::Move.get(m)
        ry = y + 42 + j * 26
        DL.send(:cursor_row, b, c, x + 6, ry, x + MOVE_W - 6, ry + 24) if j == @pick
        small_type(b, d.type, x + 14, ry + 4)
        P.text(b, x + 36, ry + 3, 130, 18, PF.fit(PF::TEXT, d.name, 128), j == @pick ? c[:strong] : c[:txt], PF::TEXT)
        category(b, d.category, x + 168, ry + 5)
        P.text(b, x + 206, ry + 6, 36, 12, d.base_damage.to_i > 1 ? d.base_damage.to_s : "---", c[:txt], PF::TINY, 1)
        P.text(b, x + 248, ry + 6, 40, 12, d.accuracy.to_i > 0 ? "#{d.accuracy}%" : "---", c[:dim], PF::TINY, 1)
        sp = (::GameData::Species.get(from.to_sym).name rescue from)
        P.small(b, x + 300, ry + 4, MOVE_W - 312, 16, _INTL("From {1}", sp), c[:dim], 1)
        @row_hits << [j, x + 6, ry, x + MOVE_W - 6, ry + 24]
      end
      dy = y + 42 + rows * 26 + 6
      b.fill_rect(x + 10, dy, MOVE_W - 20, 1, c[:line])
      m = list[@pick]
      return unless m
      desc = (::GameData::Move.get(m[0]).description rescue "").to_s
      P.small_wrap(b, desc, MOVE_W - 28).first(3).each_with_index { |ln, i| P.small(b, x + 14, dy + 6 + i * 16, MOVE_W - 28, 16, ln, c[:dim]) }
    end
  end
end
