# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Randomizer at New Game
#==============================================================================
# His pick, Rows Beside Oak: when a new game's intro opens the Randomizer
# (Randomized Mode), Professor Oak on the left and a Randomizer plate on the
# right: the seed first, every part with its state, and an amber Randomize
# Now plate. A on the seed: New Random Seed, Type a Seed, Copy Seed; A on a
# part opens its section of the Randomizer screen (the same as during a
# run); Randomize Now (or Y) asks Randomize Now? with the parts that are on,
# Randomize or Keep Editing.
#
# Randomize does what cody's screen does as it closes in the intro (his
# Pokémon data, the spoiler log, the pause before his strength prompts),
# and PIF's summary and "Are those settings correct?" after it are skipped
# (the intro's loop is left at once, found by its question's text).
#
# From New Game Setup (Run Setup's Randomizer row, his pick): Done in place
# of Randomize Now (Y too), and B goes back; the run is randomized once, at
# Start.
#==============================================================================

return unless defined?(Reloaded::Frame) && defined?(Reloaded::Randomizer::Rows)

module Reloaded
  class RandomizerNewGame
    include Reloaded::Frame

    PP = Reloaded::PartyPaint
    PF = ::KIF::PixelFont
    P = Reloaded::Pixel
    RW = Reloaded::Randomizer::Rows
    OAK = "Graphics/Pictures/introOak"
    BASE_PIC = "Graphics/Pictures/introbase"
    BG = "Graphics/Pictures/introbg"
    X0 = 250                 # the plate
    Y0 = 12
    ROW = 24

    attr_reader :entry

    # how: :intro (the intro's Randomizer step), :setup (New Game Setup's row)
    def initialize(how = :intro)
      frame_init
      @pictures = {}
      @sel = 0
      @done = false
      @setup = how == :setup
    end

    # True when it randomized (the intro goes on)
    def main
      open_sprites
      refresh
      loop do
        Graphics.update
        Input.update
        update_frame
        break if handle_input == :close
      end
      return @done
    ensure
      dispose_sprites
      @pictures.each_value { |b| b.dispose if b && !(b.disposed? rescue true) }
    end

    def refresh
      draw_screen if @sprite && !@sprite.disposed?
    end

    def entry=(state)
      @entry = state
    end

    def entry_changed
      refresh
    end

    private

    def rand
      return ::KIF::Rand
    end

    # [:seed], each part with a page, [:randomize]
    def items
      @items ||= [[:seed, nil]] + RW::PARTS.select { |part, _n| rand.respond_to?(:"page_#{part}") }.map { |part, name| [part, name] } +
                 [[:randomize, nil]]
    end

    def plate_w
      return W - 8 - X0
    end

    def row_y(i)
      return Y0 + 42 if i == 0
      return Y0 + 74 + (i - 1) * ROW if i < items.length - 1
      return Y0 + 274
    end

    #--------------------------------------------------------------------------
    # Input
    #--------------------------------------------------------------------------
    def handle_input
      pt = Reloaded::Pointer
      if pointer_hover && (i = pt.hit(@row_hits)) && i != @sel
        @sel = i
        pbPlayCursorSE
        refresh
      end
      if pt.left?
        handled, result = hint_click
        return result if handled
        if (i = pt.hit(@row_hits))
          @sel = i
          return press
        end
        return nil
      end
      if Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)
        dir = Input.repeat?(Input::DOWN) ? 1 : -1
        n = items.length
        target = @sel + dir
        if target < 0 || target >= n
          return nil unless fresh?(dir)
          target %= n
        end
        @sel = target
        pbPlayCursorSE
        refresh
      elsif Input.trigger?(Input::USE)
        return press
      elsif Input.trigger?(Input::X)         # a controller's Y
        return randomize
      elsif Input.trigger?(Input::BACK)
        return leave if @setup
        pbPlayBuzzerSE                       # (the intro's own step has nothing to go back to)
      end
      return nil
    end

    def leave
      pbPlayCancelSE
      return :close
    end

    def press
      id = items[@sel][0]
      return randomize if id == :randomize
      return seed_menu if id == :seed
      pbPlayDecisionSE
      hidden { Reloaded::RandomizerScreen.new(id).main }
      refresh
      return nil
    end

    def seed_menu
      pbPlayDecisionSE
      labels = [_INTL("New Random Seed"), _INTL("Type a Seed"), _INTL("Copy Seed")]
      descs = [_INTL("A new seed: Same settings, another game."),
               _INTL("8 letters and numbers (no I, O, 0 or 1), from a friend's run."),
               _INTL("Copies {1} to paste somewhere else.", rand.format_seed)]
      case Reloaded::Dialogs.menu(self, _INTL("Seed: {1}", rand.format_seed), labels, descs)
      when 0 then rand.seed = rand.new_seed
      when 1 then type_seed
      when 2
        seed = rand.format_seed
        if Reloaded::Runtime.phone?
          copy_for_phone(seed, _INTL("The seed, ready to paste."))
        else
          ok = (Input.clipboard = seed rescue nil)
          Reloaded::Dialogs.notice(self, _INTL("Copy Seed"), ok ? _INTL("Copied: {1}", seed) : _INTL("Couldn't copy. The seed is {1}.", seed))
        end
      end
      refresh
      return nil
    end

    def type_seed
      text, how = Reloaded::TextEntry.run(self, _INTL("Type a Seed"), rand.format_seed, 9, :prompt => _INTL("Seed"))
      return unless how == :enter
      s = rand.parse_seed(text)
      if s
        rand.seed = s
      elsif !text.to_s.strip.empty?
        pbPlayBuzzerSE
        Reloaded::Dialogs.notice(self, _INTL("Type a Seed"), _INTL("A seed is 8 letters and numbers (no I, O, 0 or 1)."))
      end
    end

    # Randomize Now?: the seed and the parts that are on, in pairs (New
    # Game Setup: Done, randomized at Start)
    def randomize
      pbPlayDecisionSE
      return :close if @setup
      c = palette
      on = items.select { |id, _n| RW::PARTS.any? { |p, _| p == id } }.map { |id, name| [name, *RW.part_state(id)] }.select { |_n, _s, o| o }
      lines = on.each_slice(2).map do |pair|
        pair.each_with_index.flat_map { |(name, st, _o), k| [[(k > 0 ? "   " : "") + _INTL(name) + ": ", c[:dim]], [st, c[:strong]]] }
      end
      text = _INTL("Your journey starts on seed {1}. The same seed and settings always make the same game.", rand.format_seed)
      choice = Reloaded::Dialogs.drawn(self, 2, 0) do |b, cc, i|
        Reloaded::RandomizerScreen.draw_question(b, cc, _INTL("Randomize Now?"), text, lines, [_INTL("Randomize"), _INTL("Keep Editing")], i)
      end
      refresh
      return nil unless choice == 0
      finish
      @done = true
      return :close
    end

    # What cody's screen does as it closes in the intro: his masters, his
    # Pokémon data made first (the intro's shuffles see the new stats), the
    # spoiler log, the pause before his strength prompts. PIF's summary and
    # question after this are skipped.
    def finish
      r = rand
      r.sync_masters
      if r.data_on?
        r.randomize_data
        r.write_log
      end
      r.screen_closed! if r.respond_to?(:screen_closed!)
      Reloaded::Randomizer.skip_intro_summary = true
    rescue StandardError => e
      Reloaded::Log.exception("The Randomizer's New Game work failed", e, :randomizer)
    end

    #--------------------------------------------------------------------------
    # Painting
    #--------------------------------------------------------------------------
    def picture(path)
      return @pictures[path] if @pictures.key?(path)
      file = defined?(pbResolveBitmap) ? (pbResolveBitmap(path) || path) : path
      @pictures[path] = (Bitmap.new(file) rescue nil)
    end

    def draw_screen
      c = palette
      base = @sprite.bitmap
      top = @top_sprite.bitmap
      base.clear
      top.clear
      @cursor_rect = nil
      @row_hits = []
      backdrop(base, 80)
      w = plate_w
      h = H - P::HINT_H - 8 - Y0
      Reloaded::Dialogs.send(:panel, base, c, X0, Y0, w, h)
      Reloaded::Dialogs.send(:title_bar, base, c, X0, Y0, w, _INTL("Randomizer"))
      items.each_with_index do |(id, name), i|
        y = row_y(i)
        if id == :randomize
          on = @sel == i
          PP.chamfer(base, X0 + 14, y, X0 + w - 14, y + 26, 7, dark_fill(c[:amber]), on ? c[:selb] : c[:amber])
          P.text(top, X0 + 14, y + 1, w - 28, 24, @setup ? _INTL("Done") : _INTL("Randomize Now"), c[:amber], PF::ROW, 2)
          @row_hits << [i, X0 + 14, y, X0 + w - 14, y + 26]
          @cursor_rect = [X0 + 14, y, w - 28, 26] if on
          next
        end
        @row_hits << [i, X0 + 8, y, X0 + w - 8, y + 23]
        @cursor_rect = [X0 + 8, y, w - 16, 23] if @sel == i && !@entry
        if id == :seed
          P.text(top, X0 + 20, y, 120, 24, _INTL("Seed"), c[:opt])
          if @entry
            Reloaded::TextEntry.draw_field(base, top, c, @entry, X0 + 90, y, w - 104, 22)
          else
            P.text(top, X0 + 20, y, w - 38, 24, rand.format_seed, c[:strong], nil, 1)
          end
          base.fill_rect(X0 + 14, y + 28, w - 28, 1, c[:line])
          next
        end
        st, on = RW.part_state(id)
        P.text(top, X0 + 20, y, 150, 23, _INTL(name), c[:opt])
        P.text(top, X0 + 20, y, w - 38, 23, st, on ? c[:txt] : c[:dim], nil, 1)
      end
      note(top, c, X0 + 24, Y0 + 306, w - 48)
      paint_hints(base, c)
      place_cursor
    end

    def backdrop(base, ox)
      bg = picture(BG)
      base.stretch_blt(Rect.new(0, 0, W, H), bg, bg.rect) if bg
      pl = picture(BASE_PIC)
      base.blt(ox - 34, 200, pl, pl.rect) if pl
      oak = picture(OAK)
      base.blt(ox, 68, oak, oak.rect) if oak
    end

    # The foot note, centred (broken at its comma when it needs two lines)
    def note(top, c, x, y, w)
      text = _INTL("Same Seed and Settings, Same Game.")
      lines = P.small_wrap(top, text, w)
      lines = text.split(/(?<=,) /) if lines.length > 1
      lines.each_with_index { |ln, k| P.small(top, x, y + k * 16, w, 16, ln, c[:dim], 2) }
    end

    def hint_pairs
      if @entry
        return [[button(:C), _INTL("Type")], [button(:B), _INTL("Cancel")]] if Reloaded::Prompts.controller?
        return [[nil, _INTL("Type")], [Reloaded::Controls::Inputs.key(40), _INTL("Done")], [Reloaded::Controls::Inputs.key(41), _INTL("Cancel")]]
      end
      if @setup
        return [[:ud, _INTL("Choose")], [button(:C), _INTL("Open"), :press], [button(:X), _INTL("Done"), :randomize],
                [button(:B), _INTL("Back"), :leave]]
      end
      return [[:ud, _INTL("Choose")], [button(:C), _INTL("Open"), :press], [button(:X), _INTL("Randomize Now"), :randomize]]
    end
  end
end
