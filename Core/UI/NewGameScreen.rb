# encoding: utf-8
#==============================================================================
# Kanto Reloaded: New Game Setup (the screen)
#==============================================================================
# His pick, Design 2 Step Strip (2026-10-25): one frame, the four steps on a
# strip along the top (L1 / R1 move between them; a click on one jumps):
#
#   Game Mode   Oak on the left; the four mode cards (Legendary locked until
#               New Game+), From a Preset and Share Code, the mode's words
#   Trainer     your trainer on Oak's platform; the application form: Name
#               (typed straight in; a controller's A opens the naming
#               screen), Gender, Age, Skin, Hair (its four colours)
#   Run Setup   Oak again; the rows (Left / Right change them, A opens),
#               the starter set's three Pokémon under them, the row's words
#   Run Card    your trainer; the run's pills and lines, its Run ID, Start
#               and Save as Preset; Square copies the share code
#
# Its popups, drawn over the step they open from (his picks): From a Preset
# (your own show YOURS with their mode's pill right under it), Enter a Share
# Code, Replace Your Setup?, Save as Preset, Back to the Title? (B on Game
# Mode; Stay first), Custom Starter. A on Difficulty opens Choose a
# Difficulty (his pick, Rows Beside Oak) with the Strip kept on top; A on
# Randomizer opens its New Game screen, with Done and Back.
#==============================================================================

return unless defined?(Reloaded::Frame) && defined?(Reloaded::NewGameSetup)

module Reloaded
  class NewGameScreen
    include Reloaded::Frame

    NG = Reloaded::NewGameSetup
    PP = Reloaded::PartyPaint
    PF = ::KIF::PixelFont
    P = Reloaded::Pixel
    DL = Reloaded::Dialogs
    STEPS = ["Game Mode", "Trainer", "Run Setup", "Run Card"].freeze
    OAK = "Graphics/Pictures/introOak"
    BASE_PIC = "Graphics/Pictures/introbase"
    BG = "Graphics/Pictures/introbg"
    STAGE_X = 56
    STRIP_H = 32
    Y0 = 40
    FORM = ["Name", "Gender", "Age", "Skin", "Hair"].freeze
    GENDERS = ["Female", "Male"].freeze
    LEVELS = ["Easy", "Normal", "Hard"].freeze
    # Each mode in words (PIF's select_game_mode texts, shortened)
    MODE_TEXT = [
      "Classic is the game as it's made: Every trainer's team and wild encounter is from the original games, and every Pokémon is still there.",
      "Remix Mode, made by members of the community, changes every trainer's team and the wild encounters to show more Pokémon from the newer generations.",
      "In Randomized Mode, trainers, wild encounters and items can be randomized. You pick exactly what's random in Run Setup.",
      "In Legendary Mode, every trainer's Pokémon is fused with a Legendary. You get a Legendary starter and an Egg of every Legendary in your PC."
    ].freeze
    LOCKED_TEXT = "Legendary Mode opens after New Game+: Beat the League on a save first."
    # A hair colour's swatch when its picture can't be read
    HAIR_FALLBACK = [[236, 200, 120], [200, 136, 80], [136, 80, 48], [64, 64, 76]].freeze
    @@swatches = {}

    attr_reader :entry

    def initialize
      frame_init
      @pictures = {}
      @icons = {}
      @step = 0
      @sel = [NG.mode_index, 0, 0, 0]
      @result = nil
      @sub = nil           # :difficulty while Choose a Difficulty shows
      @popup = nil         # a popup being typed into (drawn on the overlay)
      @trainer_bm = {}
    end

    # :start, or :title (Back to the Title)
    def main
      open_sprites
      refresh
      loop do
        Graphics.update
        Input.update
        update_frame
        handle_input
        break if @result
      end
      return @result
    ensure
      dispose_sprites
      dispose_pictures
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

    #--------------------------------------------------------------------------
    # What the rows open (NewGameSetup's rows call these)
    #--------------------------------------------------------------------------
    def open_difficulty
      pbPlayDecisionSE
      @sub = :difficulty
      @dsel = NG.value(:difficulty).to_i
      refresh
    end

    def open_randomizer
      return pbPlayBuzzerSE unless defined?(Reloaded::RandomizerNewGame)
      pbPlayDecisionSE
      hidden { Reloaded::RandomizerNewGame.new(:setup).main }
      refresh
    end

    def open_per_save
      return pbPlayBuzzerSE unless defined?(Reloaded::PerSaveSettingsScreen)
      pbPlayDecisionSE
      hidden { Reloaded::PerSaveSettingsScreen.new(false).main }
      refresh
    end

    private

    #--------------------------------------------------------------------------
    # Pictures
    #--------------------------------------------------------------------------
    def picture(path)
      return @pictures[path] if @pictures.key?(path)
      file = defined?(pbResolveBitmap) ? (pbResolveBitmap(path) || path) : path
      @pictures[path] = (Bitmap.new(file) rescue nil)
    end

    def dispose_pictures
      (@pictures.values + @icons.values + @trainer_bm.values).each do |b|
        b.dispose if b.respond_to?(:dispose) && !(b.disposed? rescue true)
      end
      @pictures = {}
      @icons = {}
      @trainer_bm = {}
    end

    # The trainer as the form makes them (PIF's own layers), with or
    # without the hat (the Hair row shows the hair)
    def trainer_picture(hat = true)
      look = [NG.trainer.values, ($Trainer.hair rescue nil)]
      if look != @trainer_look                      # a new look: both pictures again
        @trainer_bm.each_value { |b| b.dispose if b.respond_to?(:dispose) && !(b.disposed? rescue true) }
        @trainer_bm = {}
        @trainer_look = look
      end
      return @trainer_bm[hat] if @trainer_bm.key?(hat)
      bm = nil
      if defined?(generate_front_trainer_sprite_bitmap) && $Trainer
        worn = $Trainer.hat
        begin
          $Trainer.hat = nil unless hat
          ab = generate_front_trainer_sprite_bitmap(false, "POKEBALL")
          bm = ab.respond_to?(:bitmap) ? ab.bitmap : ab
        rescue StandardError => e
          Reloaded::Log.warning_once("New Game Setup couldn't draw the trainer: #{e.message}", :new_game)
        ensure
          $Trainer.hat = worn
        end
      end
      return @trainer_bm[hat] = bm
    end

    # A species' picture fitted to a box (Big Pokémon Icons, PartyIcons)
    def species_icon(b, sym, x, y, size)
      bm = (@icons[sym] ||= (Reloaded::PartyIcons.species_bitmap(sym) rescue nil))
      return unless bm
      r = Reloaded::PartyIcons.art_rect(bm, bm.height)
      s = [size.to_f / r.width, size.to_f / r.height].min
      dw = (r.width * s).round
      dh = (r.height * s).round
      b.stretch_blt(Rect.new(x + (size - dw) / 2, y + (size - dh) / 2, dw, dh), bm, r)
    end

    # Each hair colour's swatch: the commonest mid colour of its picture
    def swatch(i)
      style = (getDefaultHair(NG.trainer["gender"]) rescue "red")
      key = [style, i]
      return @@swatches[key] if @@swatches.key?(key)
      col = nil
      begin
        ids = defined?(::CharacterSelectMenuPresenter::HAIR_COLOR_IDS) ? ::CharacterSelectMenuPresenter::HAIR_COLOR_IDS : [1, 2, 3, 4]
        path = getTrainerSpriteHairFilename("#{ids[i]}_#{style}")
        bm = Bitmap.new(pbResolveBitmap(path) || path)
        counts = Hash.new(0)
        (0...bm.height).step(2) do |y|
          (0...bm.width).step(2) do |x|
            px = bm.get_pixel(x, y)
            next if px.alpha < 200
            sum = px.red + px.green + px.blue
            next if sum < 120 || sum > 700          # the outline and highlights
            counts[[px.red.to_i, px.green.to_i, px.blue.to_i]] += 1
          end
        end
        bm.dispose
        best = counts.max_by { |_k, n| n }
        col = Color.new(*best[0]) if best
      rescue StandardError
        col = nil
      end
      return @@swatches[key] = col || Color.new(*HAIR_FALLBACK[i])
    end

    #--------------------------------------------------------------------------
    # Input
    #--------------------------------------------------------------------------
    def handle_input
      return difficulty_input if @sub == :difficulty
      pt = Reloaded::Pointer
      if pointer_hover && (i = pt.hit(@row_hits)) && i != @sel[@step]
        @sel[@step] = i
        selected
        pbPlayCursorSE
        refresh
      end
      if pt.left?
        handled, _r = hint_click
        return if handled
        if (s = pt.hit(@strip_hits))
          return go_step(s)
        end
        if (i = pt.hit(@row_hits))
          @sel[@step] = i
          selected
          return press
        end
        return
      end
      return back if pt.right?
      if Input.trigger?(Input::JUMPUP)
        return @step == 0 ? pbPlayBuzzerSE : go_step(@step - 1)
      elsif Input.trigger?(Input::JUMPDOWN)
        return @step == STEPS.length - 1 ? pbPlayBuzzerSE : go_step(@step + 1)
      end
      if Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)
        move(Input.repeat?(Input::DOWN) ? 1 : -1)
      elsif Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)
        side(Input.repeat?(Input::RIGHT) ? 1 : -1)
      elsif Input.trigger?(Input::USE)
        press
      elsif Input.trigger?(Input::ACTION)
        copy_code if @step == 3
      elsif Input.trigger?(Input::BACK)
        back
      end
    end

    def go_step(s)
      return if s == @step
      pbPlayCursorSE
      @step = s
      @sel[3] = 0 if s == 3
      refresh
    end

    def back
      if @step > 0
        pbPlayCancelSE
        @step -= 1
        return refresh
      end
      pbPlayCancelSE
      choice = DL.drawn(self, 2, 1) do |b, c, i|
        ask_box(b, c, _INTL("Back to the Title?"), _INTL("Nothing is saved yet. New Game starts the intro again."), [],
                [_INTL("Leave"), _INTL("Stay")], i)
      end
      refresh
      @result = :title if choice == 0
    end

    # How many places the step's cursor has
    def count
      case @step
      when 0 then return 6                         # four modes, From a Preset, Share Code
      when 1 then return FORM.length
      when 2 then return NG.rows.length
      end
      return 2                                     # Start, Save as Preset
    end

    def move(dir)
      return side(dir) if @step == 3
      n = count
      i = @sel[@step]
      target = i + dir
      if @step == 0
        target = 3 if dir < 0 && i >= 4                     # up from the buttons
        target = 4 if dir > 0 && i == 3
        target = i if dir > 0 && i >= 4
      end
      if target < 0 || target >= n || target == i
        return unless fresh?(dir)
        target = dir > 0 ? 0 : (@step == 0 ? 4 : n - 1)
      end
      @sel[@step] = target
      selected
      pbPlayCursorSE
      refresh
    end

    # The cursor on a mode card picks it (Legendary stays locked)
    def selected
      return unless @step == 0
      i = @sel[0]
      NG.mode = NG::MODES[i] if i < 4
    end

    def side(dir)
      case @step
      when 0
        return unless @sel[0] >= 4
        @sel[0] = @sel[0] == 4 ? 5 : 4
      when 1
        return if @sel[1] == 0
        field = FORM[@sel[1]].downcase
        NG.set_trainer(field, NG.trainer[field] + dir)
      when 2
        r = NG.rows[@sel[2]]
        return unless r
        return pbPlayBuzzerSE if NG.lock_reason(r[:id]) && [:choice, :number].include?(r[:kind])
        return unless [:choice, :number].include?(r[:kind])
        before = NG.value(r[:id])
        return unless NG.step_value(r[:id], dir)
        return unless starters_changed(r, before)
      when 3
        @sel[3] = 1 - @sel[3]
      end
      pbPlayCursorSE
      refresh
    end

    # Onto Mixed: its three rolled; onto Custom with none picked: the
    # Custom Starter popup (Cancel goes back)
    def starters_changed(r, before)
      return true unless r[:id] == :starters
      v = NG.value(:starters)
      NG.roll_mixed if v == NG::MIXED && !NG.plan["mixed"]
      if v == NG::CUSTOM && !NG.custom_words
        pbPlayCursorSE
        refresh
        NG.set_value(:starters, before) unless custom_starter
        refresh
        return false
      end
      return true
    end

    def press
      case @step
      when 0
        i = @sel[0]
        return from_preset if i == 4
        return share_code if i == 5
        return pbPlayBuzzerSE if NG.mode_locked?(NG::MODES[i])
        NG.mode = NG::MODES[i]
        pbPlayDecisionSE
        @step = 1
        refresh
      when 1
        return pbPlayBuzzerSE unless @sel[1] == 0
        type_name
      when 2
        r = NG.rows[@sel[2]]
        return unless r
        if (why = NG.lock_reason(r[:id]))
          pbPlayBuzzerSE
          DL.notice(self, _INTL(r[:name]), why)
          return refresh
        end
        if r[:id] == :starters && NG.value(:starters) == NG::CUSTOM
          custom_starter
          return refresh
        end
        return pick_money(r) if r[:kind] == :number
        return r[:press].call(self) if r[:press]
        pbPlayBuzzerSE
      when 3
        return save_preset if @sel[3] == 1
        pbPlayDecisionSE
        @result = :start
      end
    end

    def type_name
      pbPlayDecisionSE
      text, how = Reloaded::TextEntry.run(self, _INTL("Type a Name"), NG.trainer["name"], NG.name_max, :prompt => _INTL("Your Name?"))
      NG.set_trainer("name", text) if how == :enter
      refresh
    end

    def pick_money(r)
      pbPlayDecisionSE
      words = r[:display] ? proc { |x| r[:display].call(x) } : nil
      v = DL.number(self, _INTL(r[:name]), NG.value(r[:id]).to_i, r[:min], r[:max], r[:step], "",
                    :format => words, :note => proc { |_x| _INTL("Left / Right: {1}. Up / Down: {2}.", (words || proc { |n| n }).call(r[:step]), (words || proc { |n| n }).call(r[:step] * 10)) })
      NG.set_value(r[:id], v) if v
      refresh
    end

    def copy_code
      pbPlayDecisionSE
      code = NG.code
      if Reloaded::Runtime.phone?
        copy_for_phone(code, _INTL("The share code, ready to paste."))
      elsif Reloaded::ShareCodes.copy(code)
        DL.notice(self, _INTL("Copy Code"), _INTL("Run {1} is copied. Paste it at New Game in any game to start the same run.", NG.run_id))
      else
        DL.notice(self, _INTL("Copy Code"), _INTL("The share code couldn't be copied."))
      end
      refresh
    end

    #--------------------------------------------------------------------------
    # Choose a Difficulty (Rows Beside Oak, the Strip kept on top)
    #--------------------------------------------------------------------------
    def difficulty_input
      pt = Reloaded::Pointer
      if pt.moved? && (i = pt.hit(@row_hits)) && i != @dsel
        @dsel = i
        pbPlayCursorSE
        refresh
      end
      if pt.left?
        handled, _r = hint_click
        return if handled
        if (i = pt.hit(@row_hits))
          @dsel = i
          return difficulty_done(true)
        end
      elsif pt.right?
        difficulty_done(false)
      elsif Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)
        dir = Input.repeat?(Input::DOWN) ? 1 : -1
        target = @dsel + dir
        if target < 0 || target > 2
          return unless fresh?(dir)
          target %= 3
        end
        @dsel = target
        pbPlayCursorSE
        refresh
      elsif Input.trigger?(Input::USE)
        difficulty_done(true)
      elsif Input.trigger?(Input::BACK)
        difficulty_done(false)
      end
    end

    def difficulty_done(pick)
      pick ? pbPlayDecisionSE : pbPlayCancelSE
      NG.set_value(:difficulty, @dsel) if pick
      @sub = nil
      refresh
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
      overlay.clear unless @popup
      @cursor_rect = nil
      @row_hits = []
      if @sub == :difficulty
        draw_difficulty(base, top, c)
      else
        send("draw_step#{@step + 1}", base, top, c)
      end
      draw_strip(base, top, c)
      paint_hints(base, c)
      place_cursor
      draw_popup(c) if @popup
    end

    def backdrop(base, who)
      bg = picture(BG)
      base.stretch_blt(Rect.new(0, 0, W, H), bg, bg.rect) if bg
      pl = picture(BASE_PIC)
      base.blt(STAGE_X - 34, 200, pl, pl.rect) if pl
      if who == :oak
        oak = picture(OAK)
        base.blt(STAGE_X, 68, oak, oak.rect) if oak
      elsif who
        base.blt(STAGE_X - 25, 70, who, who.rect)
      end
    end

    def panel_box
      return [Y0, W - 8, H - P::HINT_H - 6]
    end

    # The four steps along the top: done ones ticked, this one lit
    def draw_strip(base, top, c)
      base.fill_rect(0, 0, W, STRIP_H, c[:panel2])
      base.fill_rect(0, STRIP_H - 1, W, 2, PP::POKE_RED)
      style = Reloaded::Prompts.style
      l = Reloaded::Prompts.input(:L)
      r = Reloaded::Prompts.input(:R)
      Reloaded::ButtonIcons.draw(top, 6, 8, l, c, style) if l
      rw = r ? Reloaded::ButtonIcons.width(r, style) : 0
      Reloaded::ButtonIcons.draw(top, W - 6 - rw, 8, r, c, style) if r
      x0 = 34
      x1 = W - 34
      ws = STEPS.map { |s| PF.width(PF::TEXT, _INTL(s)) + 28 }
      gap = [(x1 - x0 - ws.sum) / (STEPS.length - 1), 2].max
      x = x0 + (x1 - x0 - ws.sum - gap * (STEPS.length - 1)) / 2
      @strip_hits = []
      STEPS.each_with_index do |label, i|
        cx0 = x
        cx1 = x + ws[i]
        x = cx1 + gap
        now = i == @step
        done = i < @step
        PP.chamfer(base, cx0, 4, cx1, 27, 6, c[:sel], c[:selb]) if now
        @strip_hits << [i, cx0, 2, cx1, 29]
        dot = done ? c[:green] : (now ? c[:strong] : c[:line])
        lx = cx0 + 7
        if done
          [[0, 3], [1, 4], [2, 5], [3, 4], [4, 3], [5, 2], [6, 1]].each { |dx, dy| top.fill_rect(lx + dx, 12 + dy, 2, 2, dot) }
        else
          P.ui.rbox(top, lx + 1, 12, lx + 7, 18, 3, dot)
        end
        P.text(top, lx + 14, 5, cx1 - lx - 14, 22, _INTL(label), now ? c[:strong] : (done ? c[:txt] : c[:dim]))
      end
    end

    # Step 1: the four mode cards, then the two other ways in
    def draw_step1(base, top, c)
      backdrop(base, :oak)
      y0, x1, y1 = panel_box
      x0 = 222
      DL.send(:panel, base, c, x0, y0, x1 - x0, y1 - y0)
      NG::MODES.each_with_index do |id, i|
        cx0 = x0 + 10
        cx1 = x1 - 10
        cy0 = y0 + 10 + i * 40
        locked = NG.mode_locked?(id)
        picked = NG.mode == id
        tint = PP.ink(c, NG::MODE_RGB[i])
        strength = locked ? 0.06 : (picked ? 0.30 : 0.14)
        PP.chamfer_grad(base, cx0, cy0, cx1, cy0 + 35, 8, mix(c[:panel2], tint, strength),
                        mix(c[:panel2], tint, locked ? 0.02 : 0.08), mix(c[:line], tint, locked ? 0.2 : (picked ? 0.7 : 0.4)))
        @row_hits << [i, cx0, cy0, cx1, cy0 + 35]
        @cursor_rect = [cx0 + 2, cy0 + 2, cx1 - cx0 - 3, 32] if i == @sel[0]
        P.text(top, cx0 + 10, cy0 + 4, 130, 26, _INTL(NG::MODE_NAMES[i]), locked ? c[:dim] : tint, PF::ROW)
        sub = locked ? _INTL("After New Game+") : _INTL(NG::MODE_SUBS[i])
        P.small(top, cx0 + 10, cy0 + 9, cx1 - cx0 - 20 - (locked ? 16 : 0), 18, sub, c[:dim], 1)
        padlock(top, cx1 - 18, cy0 + 12, c[:dim]) if locked
      end
      by = y0 + 10 + 4 * 40 + 2
      bw = (x1 - x0 - 30) / 2
      [_INTL("From a Preset"), _INTL("Share Code")].each_with_index do |label, k|
        bx = x0 + 10 + k * (bw + 10)
        on = @sel[0] == 4 + k
        DL.send(:button, base, c, bx, by, bx + bw, by + 26, on)
        P.text(top, bx, by, bw, 26, label, on ? c[:strong] : c[:txt], nil, 2)
        @row_hits << [4 + k, bx, by, bx + bw, by + 26]
      end
      ty = by + 34
      base.fill_rect(x0 + 12, ty, x1 - x0 - 24, 1, c[:line])
      text = case @sel[0]
             when 4 then _INTL("A ready-made run, or one you saved: It fills your Run Setup.")
             when 5 then _INTL("A friend's run: Paste their share code to play the same game.")
             else
               i = @sel[0]
               NG.mode_locked?(NG::MODES[i]) ? _INTL(LOCKED_TEXT) : _INTL(MODE_TEXT[i])
             end
      P.small_wrap(top, text, x1 - x0 - 28).first(4).each_with_index do |ln, k|
        P.small(top, x0 + 14, ty + 6 + k * 17, x1 - x0 - 28, 17, ln, c[:txt])
      end
    end

    # Step 2: your trainer stands where Oak stood; the form beside them
    def draw_step2(base, top, c)
      t = NG.trainer
      backdrop(base, trainer_picture(@sel[1] != 4))
      y0, x1, y1 = panel_box
      x0 = 222
      DL.send(:panel, base, c, x0, y0, x1 - x0, y1 - y0)
      P.text(top, x0, y0 + 6, x1 - x0, 13, _INTL("TRAINER APPLICATION FORM"), c[:head], PF::TINY, 2)
      vals = [nil, _INTL(GENDERS[t["gender"]]), t["age"].to_s, _INTL(NG::SKIN_NAMES[t["skin"] - 1]), _INTL(NG::HAIR_NAMES[t["hair"]])]
      cx = x1 - 72
      FORM.each_with_index do |label, i|
        y = y0 + 26 + i * 34
        @row_hits << [i, x0 + 8, y - 2, x1 - 8, y + 26]
        @cursor_rect = [x0 + 8, y - 2, x1 - x0 - 16, 28] if i == @sel[1] && !@entry
        P.text(top, x0 + 18, y, 90, 24, _INTL(label), c[:opt], PF::ROW)
        if i == 0
          if @entry
            Reloaded::TextEntry.draw_field(base, top, c, @entry, x0 + 100, y - 1, x1 - 14 - x0 - 100, 26)
          else
            P.ui.rbox(base, x0 + 100, y - 1, x1 - 14, y + 25, 5, c[:dark], c[:line])
            P.text(top, x0 + 110, y - 1, x1 - x0 - 130, 26, NG.trainer_name, t["name"].to_s.strip.empty? ? c[:dim] : c[:txt])
          end
        else
          arrows(top, c, cx, y, 24, vals[i], c[:txt], i == @sel[1])
        end
      end
      sy = y0 + 26 + 5 * 34
      sw = 18
      gap = 10
      sx0 = cx - (4 * sw + 3 * gap) / 2
      4.times do |k|
        x = sx0 + k * (sw + gap)
        ring(base, x - 3, sy - 3, x + sw + 3, sy + sw + 3, c[:selb]) if k == t["hair"]
        P.ui.rbox(base, x, sy, x + sw, sy + sw, 4, swatch(k))
      end
      note = @sel[1] == 0 ? _INTL("Left Empty, You're {1}.", NG.trainer_name("name" => "", "gender" => t["gender"])) : nil
      P.small(top, x0, y1 - 28, x1 - x0, 16, note, c[:dim], 2) if note
    end

    # Step 3: Run Setup; the starter set's Pokémon under it, the row's words
    def draw_step3(base, top, c)
      backdrop(base, :oak)
      y0, x1, y1 = panel_box
      x0 = 196
      w = x1 - x0
      DL.send(:panel, base, c, x0, y0, w, y1 - y0)
      cx = x1 - 64
      list = NG.rows
      @sel[2] = [[@sel[2], list.length - 1].min, 0].max
      list.each_with_index do |r, i|
        y = y0 + 8 + i * 24
        @row_hits << [i, x0 + 8, y, x1 - 8, y + 23]
        @cursor_rect = [x0 + 8, y, w - 16, 23] if i == @sel[2]
        locked = NG.lock_reason(r[:id])
        P.text(top, x0 + 18, y, 180, 23, _INTL(r[:name]), locked ? c[:dim] : c[:opt], PF::ROW)
        case r[:kind]
        when :choice, :number
          if locked
            vw = PF.width(PF::TEXT, NG.display(r[:id]))
            P.text(top, cx - vw / 2, y, vw + 2, 23, NG.display(r[:id]), c[:dim])
            padlock(top, x1 - 22, y + 6, c[:dim])
          else
            arrows(top, c, cx, y, 23, NG.display(r[:id]), tone_colour(c, NG.tone(r[:id])) || c[:txt], i == @sel[2])
          end
        when :setup then badge(top, c, x1 - 16, y + 4, _INTL("SET UP"), Reloaded::Palette::TONES[:amber])
        when :open then P.pill(top, x1 - 16, y + 4, _INTL("OPEN"), c[:pill], c[:txt])
        end
      end
      dy = y0 + 8 + list.length * 24 + 2
      base.fill_rect(x0 + 14, dy, w - 28, 1, c[:line])
      starters(top, c, x0, dy, w)
      r = list[@sel[2]]
      return unless r
      why = NG.lock_reason(r[:id])
      words = why || row_words(r)
      lines = P.small_wrap(top, words.to_s, w - 32).first(3)
      ly = y1 - 10 - lines.length * 16
      base.fill_rect(x0 + 14, ly - 5, w - 28, 1, c[:line])
      lines.each_with_index { |ln, k| P.small(top, x0 + 16, ly + k * 16, w - 32, 16, ln, why ? c[:amber] : c[:dim], 2) }
    end

    # A row's words: the value's own, else the row's
    def row_words(r)
      d = r[:descriptions]
      v = NG.value(r[:id])
      return _INTL(d[v.to_i]) if d && r[:kind] == :choice && d[v.to_i]
      return _INTL(r[:description].to_s)
    end

    # The set's three Pokémon (Mixed: the three rolled; Custom: its picks)
    def starters(top, c, x0, dy, w)
      why = NG.starters_lock
      v = NG.value(:starters).to_i
      list = if v == NG::CUSTOM
               cu = NG.plan["custom"]
               cu ? [cu["body"], cu["fused"] ? cu["head"] : nil].compact.map(&:to_sym) : []
             else
               NG.starter_list(v) || []
             end
      if why || list.empty?
        text = why ? _INTL("Starters: Set by the Run") : _INTL("Starters: Picked at Start")
        P.small(top, x0, dy + 14, w, 16, text, c[:dim], 2)
        return
      end
      slot = (w - 40) / 3
      off = (3 - list.length) * slot / 2
      list.each_with_index do |sym, k|
        ix = x0 + 20 + off + k * slot
        species_icon(top, sym, ix + (slot - 40) / 2, dy + 3, 40)
      end
    end

    # Step 4: the Run Card with your trainer beside it
    def draw_step4(base, top, c)
      backdrop(base, trainer_picture(true))
      y0, x1, y1 = panel_box
      x0 = 196
      w = x1 - x0
      DL.send(:panel, base, c, x0, y0, w, y1 - y0, c[:gold])
      tx = x0 + 14
      card_tags.each { |label, rgb| tx += badge(top, c, tx, y0 + 10, label, rgb, false) + 5 }
      lines = card_lines
      lines.first(7).each_with_index do |(label, val), i|
        y = y0 + 30 + i * 21
        P.text(top, x0 + 18, y, 120, 21, label, c[:dim])
        room = w - 36 - PF.width(PF::TEXT, label) - 12
        if PF.width(PF::TEXT, val.to_s) <= room
          P.text(top, x0 + 18, y, w - 36, 21, val.to_s, c[:strong], nil, 1)
        else
          P.small(top, x0 + 18, y + 2, w - 36, 18, val.to_s, c[:strong], 1)     # a long one (a fused Custom starter)
        end
      end
      ly = y0 + 30 + 7 * 21 + 4
      base.fill_rect(x0 + 14, ly, w - 28, 1, c[:line])
      P.text(top, x0 + 18, ly + 6, 120, 24, _INTL("Run ID"), c[:dim])
      P.text(top, x0 + 18, ly + 4, w - 36, 28, NG.run_id, c[:strong], PF::TITLE, 1)
      P.small(top, x0, ly + 34, w, 16, _INTL("The Same Run Has the Same Run ID."), c[:dim], 2)
      buttons = [_INTL("Start"), _INTL("Save as Preset")]
      bws = [100, w - 28 - 10 - 100]
      bx = x0 + 14
      buttons.each_with_index do |label, i|
        on = i == @sel[3]
        DL.send(:button, base, c, bx, ly + 56, bx + bws[i], ly + 82, on)
        P.text(top, bx, ly + 56, bws[i], 26, label, on ? c[:strong] : c[:txt], nil, 2)
        @row_hits << [i, bx, ly + 56, bx + bws[i], ly + 82]
        bx += bws[i] + 10
      end
    end

    # The run's pills: its mode, then each row's
    def card_tags
      i = NG.mode_index
      out = [[_INTL(NG::MODE_NAMES[i]).upcase, NG::MODE_RGB[i]]]
      NG.rows.each do |r|
        next unless r[:tag]
        tag = r[:tag].call(NG.value(r[:id]), NG.plan) rescue nil
        out << [_INTL(tag[0]), tag[1]] if tag
      end
      return out
    end

    def card_lines
      t = NG.trainer
      out = [[_INTL("Trainer"), _INTL("{1}, {2}", NG.trainer_name, t["age"])]]
      NG.rows.each do |r|
        next unless r[:card] && !NG.lock_reason(r[:id])
        line = r[:card].call(NG.value(r[:id]), NG.plan) rescue nil
        out << line if line
      end
      return out
    end

    # Choose a Difficulty: Oak, the levels in their colours, What Changes
    # (the plate as wide as the steps' own: the Strip takes its top)
    def draw_difficulty(base, top, c)
      backdrop(base, :oak)
      x0 = 222
      y0 = Y0
      w = W - 8 - x0
      h = H - P::HINT_H - 6 - y0
      DL.send(:panel, base, c, x0, y0, w, h)
      DL.send(:title_bar, base, c, x0, y0, w, _INTL("Choose a Difficulty"))
      d = defined?(Reloaded::Difficulty) ? Reloaded::Difficulty : nil
      LEVELS.each_with_index do |name, i|
        y = y0 + 40 + i * 25
        @row_hits << [i, x0 + 8, y, x0 + w - 8, y + 24]
        @cursor_rect = [x0 + 8, y, w - 16, 24] if i == @dsel
        P.text(top, x0 + 20, y - 1, 140, 26, _INTL(name), level_colour(c, i), PF::ROW)
        if i == 2 && d && d.respond_to?(:rewards?) && d.rewards?
          P.pill(top, x0 + w - 16, y + 5, _INTL("REWARDS"), dark_fill(c[:gold]), c[:gold])
        end
      end
      hy = y0 + 40 + 3 * 25 + 3
      P.heading(top, x0 + 14, x0 + w - 14, hy, _INTL("What Changes"), c[:head], c[:line])
      changes = d ? d.changes(@dsel).map { |t| title_case(t) } : []
      y = hy + 15
      changes.each do |t|
        P.ui.rbox(top, x0 + 18, y + 7, x0 + 22, y + 11, 1, level_colour(c, @dsel))
        P.small_wrap(top, t, w - 42).each do |ln|        # a long one goes on to a second line
          P.small(top, x0 + 28, y, w - 40, 18, ln, c[:txt])
          y += 16
        end
      end
      lines = P.small_wrap(top, _INTL("Change it any time in Settings. Your card shows the lowest you've used."), w - 20)
      ly = y0 + h - 8 - lines.length * 16
      base.fill_rect(x0 + 12, ly - 5, w - 24, 1, c[:line])
      lines.each_with_index { |ln, k| P.small(top, x0 + 10, ly + k * 16, w - 20, 16, ln, c[:dim], 2) }
    end

    # Difficulty's changes as a list's labels (his rule: Title Case, the
    # small joining words lower)
    SMALL_WORDS = %w[a an and or of to the at in on for with by as].freeze

    def title_case(text)
      words = text.to_s.split(" ")
      return words.each_with_index.map do |w, i|
        next w if w =~ /\A([^a-z]|x\d)/ || (i > 0 && SMALL_WORDS.include?(w.downcase) && !words[i - 1].end_with?(":"))   # (x1.1 stays)
        w[0].upcase + w[1..-1]
      end.join(" ")
    end

    def level_colour(c, i)
      tones = defined?(Reloaded::Difficulty) ? Reloaded::Difficulty::TONES : [:green, :blue, :red]
      return c[tones[i]] || c[:txt]
    end

    # A row's tone (a palette key or [r, g, b]) as a colour
    def tone_colour(c, tone)
      return nil unless tone
      return c[tone] if tone.is_a?(Symbol)
      return PP.ink(c, tone)
    end

    #--------------------------------------------------------------------------
    # Drawing pieces
    #--------------------------------------------------------------------------
    def mix(a, b, t)
      return Reloaded::Palette.mix(a, b, t)
    end

    # An HR-style badge: dark with the colour's words (pale on Light)
    def badge(top, c, x, y, label, rgb, right = true)
      fill, col = PP.badge(c, rgb)
      return P.pill(top, x, y, label, fill, col, right)
    end

    # A 2 px ring, its corners cut (the chosen swatch)
    def ring(b, x0, y0, x1, y1, col)
      b.fill_rect(x0 + 2, y0, x1 - x0 - 3, 2, col)
      b.fill_rect(x0 + 2, y1 - 1, x1 - x0 - 3, 2, col)
      b.fill_rect(x0, y0 + 2, 2, y1 - y0 - 3, col)
      b.fill_rect(x1 - 1, y0 + 2, 2, y1 - y0 - 3, col)
    end

    # A value between two arrows, centred on cx
    def arrows(top, c, cx, y, h, text, color, on)
      vw = PF.width(PF::TEXT, text)
      P.text(top, cx - vw / 2, y, vw + 2, h, text, color)
      arrow = on ? c[:txt] : c[:dim]
      P.ui.tri(top, cx - vw / 2 - 12, y + h / 2 - 4, :l, arrow, 4)
      P.ui.tri(top, cx + vw / 2 + 5, y + h / 2 - 4, :r, arrow, 4)
      return vw
    end

    # A popup with coloured lines of words and buttons (a name never splits
    # from its value): [x, y, w, h]
    def ask_box(b, c, title, text, lines, buttons, choice, w = DL::TEXT_W, extra_h = 0)
      tl = text ? P.wrap(text.to_s, w - 32).first(6) : []
      h = 40 + tl.length * 18 + (lines.empty? ? 0 : lines.length * 18 + 8) + 48 + extra_h
      x = (W - w) / 2
      y = (H - h) / 2
      DL.frame(b, c, x, y, w, h, title)
      tl.each_with_index { |ln, i| P.text(b, x + 16, y + 40 + i * 18, w - 32, 18, ln, c[:txt], nil, 2) }
      ly = y + 46 + tl.length * 18 + extra_h
      lines.each_with_index do |line, k|
        lx = x + (w - line_width(b, line)) / 2
        line.each do |t, col|
          if t == :arrow
            P.ui.tri(b, lx + 3, ly + k * 18 + 6, :r, col, 3)
            lx += 12
          else
            lx += P.small(b, lx, ly + k * 18, 300, 18, t, col)
          end
        end
      end
      DL.button_row(b, c, x, w, y + h - 36, buttons, choice) unless buttons.empty?
      return [x, y, w, h]
    end

    def line_width(b, line)
      P.small_font(b)
      return line.inject(0) { |s, (t, _c)| s + (t == :arrow ? 12 : b.text_size(t.to_s).width) }
    end

    #--------------------------------------------------------------------------
    # The hints
    #--------------------------------------------------------------------------
    def hint_pairs
      if @entry
        return [[button(:C), _INTL("Type")], [button(:B), _INTL("Cancel")]] if Reloaded::Prompts.controller?
        return [[nil, _INTL("Type")], [Reloaded::Controls::Inputs.key(40), _INTL("Done")], [Reloaded::Controls::Inputs.key(41), _INTL("Cancel")]]
      end
      return @popup_hints if @popup_hints
      if @sub == :difficulty
        return [[:ud, _INTL("Choose")], [button(:C), _INTL("Confirm"), :press_hint], [button(:B), _INTL("Back"), :back_hint]]
      end
      back_pair = [button(:L), _INTL("Back"), :back]
      next_pair = [button(:R), _INTL("Next"), :next_step]
      case @step
      when 0
        return [[:ud, _INTL("Choose")], [button(:C), _INTL("Pick"), :press], next_pair]
      when 1
        return [[:ud, _INTL("Choose")], [button(:C), _INTL("Type"), :press], back_pair, next_pair] if @sel[1] == 0
        return [[:ud, _INTL("Choose")], [:lr, _INTL("Change")], back_pair, next_pair]
      when 2
        r = NG.rows[@sel[2]]
        open = r && ([:open, :setup].include?(r[:kind]) || r[:press] || r[:kind] == :number ||
                     (r[:id] == :starters && NG.value(:starters) == NG::CUSTOM))
        list = [[:ud, _INTL("Choose")]]
        list << [:lr, _INTL("Change")] if r && [:choice, :number].include?(r[:kind]) && !NG.lock_reason(r[:id])
        list << [button(:C), _INTL("Open"), :press] if open && !NG.lock_reason(r[:id])
        return list + [back_pair, next_pair]
      end
      return [[:lr, _INTL("Choose")], [button(:C), @sel[3] == 0 ? _INTL("Start") : _INTL("Save"), :press],
              [button(:A), _INTL("Copy Code"), :copy_code], back_pair]
    end

    def next_step
      @step < STEPS.length - 1 ? go_step(@step + 1) : pbPlayBuzzerSE
    end

    def press_hint
      difficulty_done(true)
    end

    def back_hint
      difficulty_done(false)
    end

    # The hints a popup shows while it runs (the screen's own come back after)
    def with_hints(pairs)
      before = @popup_hints
      @popup_hints = pairs
      paint_hints(@sprite.bitmap, palette)
      return yield
    ensure
      @popup_hints = before
      paint_hints(@sprite.bitmap, palette) if @sprite && !@sprite.disposed?
    end

    def draw_popup(c)
      send(:"paint_#{@popup[0]}", overlay, c, *@popup[1..-1])
    end
  end
end
