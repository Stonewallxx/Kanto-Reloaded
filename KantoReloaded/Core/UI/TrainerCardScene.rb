# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Trainer Card's scene
#==============================================================================
# Kanto Reloaded's PokemonTrainerCard_Scene (TrainerCard/TrainerCard.rb makes
# it): his picks of 2026-10-28, as drawn in the prep's mockups.
#
#   The art     PIF's background picture on its own sprite under the plates;
#               a mat in the art's edge colour (toward the Theme Mode's
#               background) where PIF's frame used to be
#   Plates      Glass White on Light, Glass Charcoal on Dark, stronger on
#               busy or dark art (TrainerCard.art_facts); or the Plate Color
#               picked in Style (metals and gems with a soft shine)
#   Words       PIF's light-background colours with their shadows on a
#               light plate, the same colours made Vivid on a deep one; no
#               shadow on tags, badges, hints or the ID
#   Tabs        top right, LB and RB beside them; Left and Right too on
#               Front, Records and Stats
#   Front       Portrait ID: the lanyard card (photo, name, title and ID, the
#               facts, Run Tags, the 16-badge case), the trainer and the
#               Showcase (a border in each Pokémon's types) on the art
#   Records     the card's back (trainer battles), Recent Battles, Win Rate
#   Stats       the card's back with eight stats, the Next Milestone
#   Style       the Dressing Room (UI/TrainerCardStyle.rb)
#   Unlocks     every unlock, what it needs (UI/TrainerCardStyle.rb)
#   Actions (A) Save as Image, Copy Trainer ID
#==============================================================================

return unless defined?(Reloaded::Frame) && defined?(Reloaded::PartyPaint) && defined?(Reloaded::TrainerCard::Unlocks)

module Reloaded
  module TrainerCardScene
    include Reloaded::Frame

    TC = Reloaded::TrainerCard
    CT = Reloaded::TrainerCard::Counters
    UL = Reloaded::TrainerCard::Unlocks
    P = Reloaded::Pixel
    PF = ::KIF::PixelFont
    PP = Reloaded::PartyPaint
    DL = Reloaded::Dialogs
    W = 512
    H = 384
    ART_X0, ART_Y0, ART_X1, ART_Y1 = Reloaded::TrainerCard::ART
    TABS = [:front, :records, :stats, :style, :unlocks].freeze
    TAB_NAMES = { :front => "Front", :records => "Records", :stats => "Stats", :style => "Style", :unlocks => "Unlocks" }.freeze
    # The lanyard card (Front, Records and Stats) and the trainer's place
    CARD = [40, 56, 232, 356].freeze
    TRAINER_AT = [300, 88].freeze
    WIN_GREEN = [120, 230, 150].freeze
    LOSS_RED = [240, 100, 90].freeze
    WHITE = Color.new(255, 255, 255)
    BLACK = Color.new(0, 0, 0)

    #--------------------------------------------------------------------------
    # The game's scene methods
    #--------------------------------------------------------------------------
    def pbStartScene
      frame_init
      @tab = 0
      @popup_hints = nil
      @pictures = {}
      @faces = {}
      @icon_pics = {}
      @pending = {}
      @group = 0
      @slot = 0
      @cat = 0
      @entry = 0
      @first_row = 0
      open_sprites
      @art_sprite = Sprite.new(@viewport)
      @art_sprite.z = -1
      @art_sprite.bitmap = Bitmap.new(W, H)
      make_trainer
      @dex_owned = TC.dex_owned
      @showcase = TC.showcase
      UL.check
      ask_platinum
      paint_art
      draw
    end

    def pbTrainerCard
      pbSEPlay("GUI trainer card open") rescue nil
      loop do
        Graphics.update
        Input.update
        pbUpdate
        break if handle_input == :close
      end
    end

    def pbUpdate
      update_frame
      Reloaded::Toast.update if defined?(Reloaded::Toast)
    end

    def pbEndScene
      if @art_sprite && !@art_sprite.disposed?
        @art_sprite.bitmap.dispose if @art_sprite.bitmap
        @art_sprite.dispose
      end
      @art_sprite = nil
      @trainer_bitmap.dispose if @trainer_bitmap.respond_to?(:dispose)
      @trainer_bitmap = nil
      @pictures.each_value { |b| b.dispose if b && !b.disposed? }    # (the faces are crops of these)
      @icon_pics.each_value { |b, _r| b.dispose if b && !b.disposed? }
      @pictures = {}
      @faces = {}
      @icon_pics = {}
      dispose_sprites
    end

    def refresh
      draw if @sprite && !@sprite.disposed?
    end

    #--------------------------------------------------------------------------
    # Input
    #--------------------------------------------------------------------------
    def handle_input
      pointer_hover
      pt = Reloaded::Pointer
      if pt.left?
        hit = (@tab_hits || []).find { |_i, x0, y0, x1, y1| pt.inside?(x0, y0, x1, y1) }
        return go_tab(hit[0]) if hit
        handled, result = hint_click
        return result if handled
        r = tab_click
        return r unless r == :none
      end
      if pt.right? || Input.trigger?(Input::BACK)
        return close_card
      end
      if Input.trigger?(Input::JUMPUP) || (Input.trigger?(Input::LEFT) && arrows_turn?)
        return go_tab(@tab - 1)
      elsif Input.trigger?(Input::JUMPDOWN) || (Input.trigger?(Input::RIGHT) && arrows_turn?)
        return go_tab(@tab + 1)
      end
      case TABS[@tab]
      when :style then return style_input
      when :unlocks then return unlocks_input
      end
      return actions if Input.trigger?(Input::USE)
      return nil
    end

    # Left and Right turn the tabs where nothing else uses them (his pick)
    def arrows_turn?
      return [:front, :records, :stats].include?(TABS[@tab])
    end

    def go_tab(i)
      i %= TABS.length
      return nil if i == @tab
      return nil unless leave_style
      @tab = i
      @entry = 0
      @first_row = 0
      pbPlayCursorSE
      refresh
      return nil
    end

    def close_card
      return nil unless leave_style
      pbPlayCloseMenuSE rescue pbPlayCancelSE
      return :close
    end

    #--------------------------------------------------------------------------
    # Actions (A): Save as Image, Copy Trainer ID
    #--------------------------------------------------------------------------
    def actions
      pbPlayDecisionSE
      labels = [_INTL("Save as Image"), _INTL("Copy Trainer ID")]
      words = [_INTL("Saves this card as a picture in Kanto Reloaded's Trainer Cards folder."),
               _INTL("Copies {1} for a friend's Secret Base.", $Trainer.id)]
      pick = with_hints([[:ud, _INTL("Choose")], [button(:C), _INTL("Pick")], [button(:B), _INTL("Back")]]) do
        DL.menu(self, _INTL("Trainer Card"), labels, words, 0)
      end
      case pick
      when 0 then save_image
      when 1 then copy_id
      end
      refresh
      return nil
    end

    def save_image
      unless TC.can_save_image?
        DL.notice(self, _INTL("Pictures Can't Be Saved Here"), _INTL("This game can't write pictures on this device."))
        return
      end
      shot = card_picture
      path = TC.save_image(shot)
      unless path
        shot.dispose
        DL.notice(self, _INTL("Couldn't Save"), _INTL("The picture couldn't be written. The log says why."))
        return
      end
      phone = Reloaded::Runtime.phone?
      buttons = [phone ? _INTL("Copy the Path") : _INTL("Open Folder"), _INTL("OK")]
      choice = with_hints([[:lr, _INTL("Choose")], [button(:C), _INTL("OK")], [button(:B), _INTL("Back")]]) do
        DL.drawn(self, 2, 1) { |b, c, ch| paint_saved(b, c, ch, shot, path, buttons) }
      end
      shot.dispose
      return unless choice == 0
      if phone
        copy_for_phone(path, _INTL("Where the picture is, copied to paste."))
      elsif defined?(Reloaded::BugReport) && Reloaded::BugReport.respond_to?(:open_folder)
        Reloaded::BugReport.open_folder(path)
      end
    end

    def copy_id
      if TC.copy_id
        Reloaded::Toast.show(_INTL("Trainer ID Copied"), :icon => "Graphics/PauseMenu/TRAINERINFO", :pill => [$Trainer.id.to_s, :green])
      else
        with_hints([[button(:C), _INTL("OK")]]) do
          DL.drawn(self, 1, 0) { |b, c, ch| paint_no_copy(b, c, ch) }
        end
      end
    end

    # A popup's own hints on the hint line while it shows
    def with_hints(pairs)
      before = @popup_hints
      @popup_hints = pairs
      refresh
      return yield
    ensure
      @popup_hints = before
    end

    # The card as a picture: the art, the plates and words (no hint line,
    # cursor or popup)
    def card_picture
      shot = Bitmap.new(W, H)
      shot.blt(0, 0, @art_sprite.bitmap, @art_sprite.bitmap.rect)
      keep = Rect.new(0, 0, W, H - P::HINT_H)
      shot.blt(0, 0, @sprite.bitmap, keep)
      shot.blt(0, 0, @top_sprite.bitmap, keep)
      return shot
    end

    #--------------------------------------------------------------------------
    # Drawing
    #--------------------------------------------------------------------------
    def draw
      c = palette
      base = @sprite.bitmap
      top = @top_sprite.bitmap
      base.clear
      top.clear
      @cursor_rect = nil
      @strength = (@art_facts || [nil, 0.0])[1]
      send(:"draw_#{TABS[@tab]}", base, top, c)
      paint_hints(base, c)
      place_cursor
    end

    # The art and the mat around it, for a background (the card's, or the
    # one Style is showing)
    def paint_art(id = nil)
      b = @art_sprite.bitmap
      b.clear
      id ||= TC.background
      path = TC.art_path(id) || TC.art_path("BLUE")
      art = path ? picture(path) : nil
      @art_facts = TC.art_facts(path.to_s, art)
      c = palette
      m = mix(@art_facts[0], c[:bg], c[:light] ? 0.45 : 0.62)
      b.fill_rect(0, 0, W, H, m)
      b.blt(0, 0, art, art.rect) if art
    end

    def make_trainer
      made = generate_front_trainer_sprite_bitmap
      @trainer_bitmap = made
      @trainer = made.respond_to?(:bitmap) ? made.bitmap : made
      @trainer_bounds = bounds_of(@trainer)
    rescue StandardError => e
      Reloaded::Log.warning_once("The Trainer Card couldn't draw the trainer: #{e.message}", :trainer_card)
      @trainer = nil
    end

    # Where the picture's opaque part is, on a 2 px grid: [x0, y0, x1, y1]
    def bounds_of(bm)
      return [0, 0, 159, 159] unless bm && bm.respond_to?(:get_pixel)
      w = bm.width
      h = bm.height
      xs = (0...w).step(2).to_a
      ys = (0...h).step(2).to_a
      seen = proc { |x, y| bm.get_pixel(x, y).alpha > 16 }
      top = ys.find { |y| xs.any? { |x| seen.call(x, y) } } || 0
      bottom = ys.reverse.find { |y| xs.any? { |x| seen.call(x, y) } } || h - 1
      left = xs.find { |x| ys.any? { |y| seen.call(x, y) } } || 0
      right = xs.reverse.find { |x| ys.any? { |y| seen.call(x, y) } } || w - 1
      return [left, top, right, bottom]
    end

    # Multiplayer's Platinum: its own refresh asked once as the card opens
    def ask_platinum
      return unless TC.platinum? && respond_to?(:request_platinum_balance_from_server)
      request_platinum_balance_from_server
    rescue StandardError => e
      Reloaded::Log.warning_once("Multiplayer's Platinum couldn't be asked for: #{e.message}", :trainer_card)
    end

    #--------------------------------------------------------------------------
    # The style shown: what Style is trying on, else what's kept
    #--------------------------------------------------------------------------
    def plate_now
      return @pending[:plates] == :theme ? nil : UL.item(:plates, @pending[:plates]) if @pending.key?(:plates)
      return UL.plate
    end

    def case_now
      return @pending.key?(:cases) ? @pending[:cases].to_sym : (UL.style["case"] || :glass).to_sym
    end

    def tags_now
      return @pending.key?(:tags) ? @pending[:tags].to_sym : UL.tag_look
    end

    def title_now
      return @pending.key?(:titles) ? @pending[:titles].to_sym : UL.title_id
    end

    def deep?(rgb)
      return rgb[0] * 0.299 + rgb[1] * 0.587 + rgb[2] * 0.114 < 150
    end

    #--------------------------------------------------------------------------
    # Plates and words
    #--------------------------------------------------------------------------
    def mix(a, b, t)
      return Reloaded::Palette.mix(a, b, t)
    end

    def light?(c)
      return c[:light] ? true : false
    end

    # A plate: Glass White on Light, Glass Charcoal on Dark, or the Plate
    # Color picked (metals and gems shine down from their top edge)
    def glass(b, c, x0, y0, x1, y1, r = 8, strength = 1.0)
      pl = plate_now
      if pl.nil?
        a = [(TC.glass_alpha(light?(c), @strength) * strength).round, 245].min
        if light?(c)
          P.ui.rbox(b, x0, y0, x1, y1, r, see(Color.new(250, 252, 255), a), see(WHITE, 225))
        else
          P.ui.rbox(b, x0, y0, x1, y1, r, see(c[:panel], a), see(c[:line], 235))
        end
        return
      end
      rgb, kind, alpha, shine = pl.look
      deep = deep?(rgb)
      base_a = if alpha then alpha
               elsif pl.id == :glass_white then TC.glass_alpha(true, @strength)
               elsif pl.id == :glass_charcoal then TC.glass_alpha(false, @strength)
               else (deep ? 205 : 165) + (@strength.to_f * 25).round
               end
      a = [(base_a * strength).round, 245].min
      col = Color.new(*rgb)
      P.ui.rbox(b, x0, y0, x1, y1, r, see(col, a), see(mix(col, WHITE, deep ? 0.35 : 0.6), 230))
      return unless kind == :sheen && y1 - y0 > 40 && x1 - x0 > 60
      h = [(y1 - y0) / 4, 40].min
      h.times do |k|
        t = (shine || (deep ? 0.30 : 0.45)) * (1.0 - k.to_f / h)**2
        next if t < 0.01
        b.fill_rect(x0 + r, y0 + 2 + k, x1 - x0 - 2 * r, 1, see(mix(col, WHITE, t), [a + (t * 60).round, 245].min))
      end
    end

    # A colour seen through at alpha: on the card it stays see-through (the
    # art shows behind it); on a popup it's mixed with the popup's own
    # colour and drawn solid, so a popup is never see-through (his rule)
    def see(col, alpha)
      return Color.new(col.red, col.green, col.blue, alpha) unless @solid_under
      m = mix(@solid_under, col, alpha / 255.0)
      return Color.new(m.red, m.green, m.blue, 255)
    end

    # Drawing on a popup: everything inside is solid over its panel
    def on_popup(c)
      before = @solid_under
      @solid_under = c[:panel2]
      return yield
    ensure
      @solid_under = before
    end

    # The words are PIF's dark-on-light ones on a light plate
    def words_light?(c)
      pl = plate_now
      return light?(c) unless pl
      return !deep?(pl.look[0])
    end

    # [base, shadow] for the card's words: PIF's colour with its shadow on a
    # light plate; on a deep one the same hue made Vivid with a dark shadow
    def pif(c, name)
      base, shadow = TC.skin(name)
      return [base, shadow] if words_light?(c)
      return [light?(c) ? Color.new(236, 238, 244) : c[:txt], Color.new(12, 16, 24)] if name == "Dark"
      col = PP.ink(light?(c) ? { :light => false } : c, [base.red.to_i, base.green.to_i, base.blue.to_i])
      return [col, mix(col, BLACK, 0.72)]
    end

    # Words with PIF's shadow (right, down and both: 2 px, 1 for the tiny font)
    def stx(top, x, y, w, h, str, pair, font = nil, align = 0)
      font ||= PF::TEXT
      base, shadow = pair
      d = font == PF::TINY ? 1 : 2
      if shadow
        P.text(top, x + d, y, w, h, str, shadow, font, align)
        P.text(top, x, y + d, w, h, str, shadow, font, align)
        P.text(top, x + d, y + d, w, h, str, shadow, font, align)
      end
      return P.text(top, x, y, w, h, str, base, font, align)
    end

    # Words with no shadow (tags, badges, hints, the ID: his exceptions)
    def plain(top, x, y, w, h, str, pair, font = nil, align = 0)
      return P.text(top, x, y, w, h, str, pair[0], font || PF::TEXT, align)
    end

    # An HR-style badge (dark with the colour's words; pale on Light); a Run
    # Tag in its look (Pills, Solid, Plates, Dots): its width
    def tag(top, c, x, y, label, rgb, right = false, look = :pill)
      fill, col = PP.badge(c, rgb)
      lw = PF.width(PF::TINY, label)
      case look
      when :solid
        ink = PP.ink(c, rgb)
        bright = ink.red * 0.299 + ink.green * 0.587 + ink.blue * 0.114
        return P.pill(top, x, y, label, ink, bright > 150 ? Color.new(28, 30, 36) : WHITE, right)
      when :plate
        w = lw + 14
        x -= w if right
        PP.chamfer(top, x, y, x + w, y + 15, 4, fill, col)
        P.text(top, x, y, w, 16, label, col, PF::TINY, 2)
        return w
      when :dot
        ink = PP.ink(c, rgb)
        x -= lw + 12 if right
        PP.disc(top, x + 4, y + 7, 3, ink)
        P.text(top, x + 10, y, lw + 2, 16, label, ink, PF::TINY)
        return lw + 12
      end
      return P.pill(top, x, y, label, fill, col, right)
    end

    def run_tag_width(label, look)
      return PF.width(PF::TINY, label) + (look == :plate ? 14 : 12)
    end

    def num(v)
      return CT.num(v)
    end

    def money(v)
      return "$" + num(v)
    end

    def divider(base, c, x0, x1, y)
      l = c[:line]
      base.fill_rect(x0, y, x1 - x0, 1, words_light?(c) ? Color.new(255, 255, 255, 220) : Color.new(l.red, l.green, l.blue, 255))
    end

    #--------------------------------------------------------------------------
    # Pictures
    #--------------------------------------------------------------------------
    def picture(path)
      return @pictures[path] if @pictures.key?(path)
      file = defined?(pbResolveBitmap) ? (pbResolveBitmap(path) || path) : path
      @pictures[path] = (Bitmap.new(file) rescue nil)
      return @pictures[path]
    end

    def trainer(base, x, y)
      base.blt(x, y, @trainer, Rect.new(0, 0, [@trainer.width, 160].min, [@trainer.height, 160].min)) if @trainer
    end

    # The trainer in the card's photo window, cut to it (feet at its bottom)
    def photo(base, c, x0, y0, x1, y1)
      glass(base, c, x0, y0, x1, y1, 6, 0.75)
      return unless @trainer
      l, t, r, btm = @trainer_bounds
      sx = l - 2
      sy = t - 2
      sw = r - l + 6
      sh = btm - t + 6
      scale = 0.5
      dw = (sw * scale).round
      dh = (sh * scale).round
      avail = y1 - y0 - 4
      if dh > avail
        sh -= ((dh - avail) / scale).round
        dh = avail
      end
      base.stretch_blt(Rect.new(x0 + (x1 - x0 - dw) / 2, y1 - 2 - dh, dw, dh), @trainer, Rect.new(sx, sy, sw, sh))
    end

    def item(top, id, x, y, size = 24)
      path = (::GameData::Item.icon_filename(id) rescue nil) || "Graphics/Items/#{id}"
      bm = picture(path)
      top.stretch_blt(Rect.new(x, y, size, size), bm, Rect.new(0, 0, bm.height, bm.height)) if bm
    end

    # A background at a quarter size (128 x 96): its mat, its art; dimmed
    # with a padlock while it's locked
    def thumb(base, top, c, id, x, y, locked = false)
      path = TC.art_path(id) || TC.art_path("BLUE")
      art = path ? picture(path) : nil
      mat = mix(TC.art_facts(path.to_s, art)[0], c[:bg], c[:light] ? 0.45 : 0.62)
      base.fill_rect(x, y, 128, 96, locked ? mix(mat, Color.new(16, 20, 28), 0.6) : mat)
      top.stretch_blt(Rect.new(x, y, 128, 96), art, art.rect, locked ? 90 : 255) if art
      padlock(top, x + 60, y + 41, Color.new(250, 252, 255)) if locked
    end

    # PIF's badge sheet (icon_badges.png, 8 across, Kanto then Johto)
    def badge_icon(top, k, x, y, size = 16)
      bm = picture("Graphics/Pictures/Trainer Card/icon_badges")
      top.stretch_blt(Rect.new(x, y, size, size), bm, Rect.new((k % 8) * 32, (k / 8) * 32, 32, 32)) if bm
    end

    # The badge case in its look: glass slots, or a real case (leather,
    # velvet...) with its slots
    def badge_case(base, top, c, x, y, pitch = 21, per_row = 8, size = 16, row_pitch = nil, kind = case_now)
      rows = TC.league? ? 2 : 1
      rp = row_pitch || pitch
      it = UL.item(:cases, kind)
      look = it ? it.look : nil
      d = size + 2
      if look
        face, slot, trim = look.map { |rgb| Color.new(*rgb) }
        x0 = x - 6
        y0 = y - 5
        x1 = x + (per_row - 1) * pitch + d + 6
        y1 = y + (rows - 1) * rp + d + 5
        P.ui.rbox(base, x0, y0, x1, y1, 6, face, mix(face, BLACK, 0.35))
        case_texture(base, kind, face, slot, trim, x0, y0, x1, y1)
      end
      (rows * 8).times do |k|
        bx = x + (k % per_row) * pitch
        by = y + (k / per_row) * rp
        if look
          rim = [:velvet, :royal].include?(kind) ? Color.new(*look[2]) : mix(Color.new(*look[1]), BLACK, 0.3)
          P.ui.rbox(base, bx, by, bx + d, by + d, d / 2, Color.new(*look[1]), rim)
        else
          glass(base, c, bx, by, bx + d, by + d, d / 2, 0.8)
        end
        badge_icon(top, k, bx + 1, by + 1, size) if TC.badge?(k)
      end
    end

    def case_texture(base, kind, face, slot, trim, x0, y0, x1, y1)
      case kind
      when :leather, :denim
        (x0 + 5...x1 - 5).step(4) { |sx| base.fill_rect(sx, y0 + 2, 2, 1, trim); base.fill_rect(sx, y1 - 2, 2, 1, trim) }
        (y0 + 5...y1 - 5).step(4) { |sy| base.fill_rect(x0 + 2, sy, 1, 2, trim); base.fill_rect(x1 - 2, sy, 1, 2, trim) }
        (y0 + 3...y1 - 2).step(3) { |sy| base.fill_rect(x0 + 4, sy, x1 - x0 - 8, 1, mix(face, WHITE, 0.06)) } if kind == :denim
      when :wood
        [[4, 0.0], [9, 0.6], [15, 0.3], [22, 0.8], [30, 0.2], [37, 0.5]].each do |gy, o|
          next if y0 + gy >= y1 - 2
          base.fill_rect(x0 + 3 + (o * 20).round, y0 + gy, x1 - x0 - 6 - (o * 40).round, 1, trim)
        end
      when :cork
        rng = Random.new(7)
        lighter = mix(face, WHITE, 0.25)
        120.times { base.fill_rect(x0 + 3 + rng.rand(x1 - x0 - 6), y0 + 3 + rng.rand(y1 - y0 - 6), 1, 1, rng.rand < 0.5 ? trim : lighter) }
      when :steel
        [[x0 + 3, y0 + 3], [x1 - 5, y0 + 3], [x0 + 3, y1 - 5], [x1 - 5, y1 - 5]].each { |rx, ry| P.ui.rbox(base, rx, ry, rx + 2, ry + 2, 1, trim) }
        4.times { |k| base.fill_rect(x0 + 6, y0 + 1 + k, x1 - x0 - 12, 1, mix(face, WHITE, 0.25 * (1 - k / 4.0))) }
      when :velvet, :royal
        6.times { |k| base.fill_rect(x0 + 6, y0 + 1 + k, x1 - x0 - 12, 1, mix(face, WHITE, 0.18 * (1 - k / 6.0))) }
        if kind == :royal
          base.fill_rect(x0 + 4, y0 + 2, x1 - x0 - 8, 1, trim)
          base.fill_rect(x0 + 4, y1 - 2, x1 - x0 - 8, 1, trim)
        end
      end
    end

    # The lanyard: two red straps from the top and the clip
    def lanyard(base, cx, top_y, clip_y)
      base.fill_rect(cx - 20, top_y, 4, clip_y - top_y + 4, PP::POKE_RED)
      base.fill_rect(cx + 16, top_y, 4, clip_y - top_y + 4, PP::POKE_RED)
      P.ui.rbox(base, cx - 12, clip_y, cx + 12, clip_y + 13, 4, Color.new(205, 212, 225), Color.new(150, 160, 178))
      P.ui.rbox(base, cx - 6, clip_y + 4, cx + 6, clip_y + 8, 2, Color.new(150, 160, 178))
    end

    # The tabs, top right on the art; LB and RB beside them
    def tabs(base, top, c)
      x1 = ART_X1 - 6
      y = ART_Y0 + 6
      names = TABS.map { |t| _INTL(TAB_NAMES[t]).upcase }
      ws = names.map { |t| PF.width(PF::TINY, t) + 12 }
      style = Reloaded::Prompts.style
      l = Reloaded::Prompts.input(:L)
      r = Reloaded::Prompts.input(:R)
      rw = r ? Reloaded::ButtonIcons.width(r, style, 14) : 0
      x = x1 - rw - 4 - ws.sum - 3 * (names.length - 1)
      lw = l ? Reloaded::ButtonIcons.width(l, style, 14) : 0
      Reloaded::ButtonIcons.draw(top, x - 4 - lw, y + 1, l, c, style, 14) if l
      @tab_hits = []
      names.each_with_index do |t, i|
        @tab_hits << [i, x, y, x + ws[i], y + 15]
        if i == @tab
          P.ui.rbox(base, x, y, x + ws[i], y + 15, 5, c[:selb], light?(c) ? c[:selb] : WHITE)
          P.text(top, x, y, ws[i], 16, t, light?(c) ? WHITE : c[:bg], PF::TINY, 2)
        else
          glass(base, c, x, y, x + ws[i], y + 15, 5)
          plain(top, x, y, ws[i], 16, t, pif(c, "Dark"), PF::TINY, 2)
        end
        x += ws[i] + 3
      end
      Reloaded::ButtonIcons.draw(top, x + 1, y + 1, r, c, style, 14) if r
    end

    # The card's title line: the title with its shadow, then the ID without one
    def title_id(top, c, x, w, y, title, id_text)
      tw = PF.width(PF::TINY, title)
      iw = PF.width(PF::TINY, id_text)
      x0 = x + (w - tw - iw) / 2
      stx(top, x0, y, tw + 2, 12, title, pif(c, "Dark"), PF::TINY)
      plain(top, x0 + tw, y, iw + 2, 12, id_text, pif(c, "Dark"), PF::TINY)
    end

    #--------------------------------------------------------------------------
    # The Showcase: glass tiles, each with a border in its Pokémon's types
    # (his pick, Halves: the left half the first type, the right the
    # second) and its icon (the game's own icon: Big Pokémon Icons, fusions,
    # other mods' looks)
    #--------------------------------------------------------------------------
    def showcase_tiles(base, top, c, x, y, w = 50, h = 44, gap = 6)
      @showcase.each_with_index do |pk, i|
        tx = x + i * (w + gap)
        showcase_tile_at(base, top, c, pk, tx, y, w, h, h - 6)
      end
    end

    def showcase_tile_at(base, top, c, pk, tx, y, w, h, size)
      unless pk
        glass(base, c, tx, y, tx + w, y + h, 8)
        return
      end
      shown = icon_for(pk)
      inks = type_inks(c, shown)
      P.ui.rbox(base, tx, y, tx + w, y + h, 8, inks[0])
      if inks[1]
        half = Bitmap.new(w + 1, h + 1)
        P.ui.rbox(half, 0, 0, w, h, 8, inks[1])
        base.blt(tx + w / 2, y, half, Rect.new(w / 2, 0, w / 2 + 1, h + 1))
        half.dispose
      end
      glass(base, c, tx + 2, y + 2, tx + w - 2, y + h - 2, 6)
      icon_at(top, shown, tx + w / 2, y + h / 2, size)
      showcase_tile(top, c, pk, tx, y, w, h)
    end

    # A type's colour on the border: deepened on Light, a little lifted on Dark
    def type_inks(c, pk)
      types = [(pk.type1 rescue nil), (pk.type2 rescue nil)].compact.uniq
      types = [:NORMAL] if types.empty?
      rgbs = types.map { |t| Reloaded::PartyScreen.type_rgb(t) }
      inks = rgbs.map { |rgb| light?(c) ? PP.ink(c, rgb) : mix(Color.new(*rgb), WHITE, 0.15) }
      return [inks[0], inks[1]]
    end

    # A Pokémon's icon, its art fitted to size, its middle on cx, cy
    def icon_at(top, pk, cx, cy, size)
      bm, r = icon_picture(pk)
      return unless bm
      s = [size.to_f / r.width, size.to_f / r.height].min
      dw = (r.width * s).round
      dh = (r.height * s).round
      top.stretch_blt(Rect.new(cx - dw / 2, cy - dh / 2, dw, dh), bm, r)
    end

    # The first frame of the game's icon for it, and where its art is
    def icon_picture(pk)
      return @icon_pics[pk] if @icon_pics.key?(pk)
      s = Reloaded::PartyIcons.icon(pk, nil)
      return @icon_pics[pk] = nil unless s && s.bitmap
      src = s.src_rect
      f = [src.width, src.height].min
      frame = Bitmap.new(f, f)
      frame.blt(0, 0, s.bitmap, Rect.new(src.x, src.y, f, f))
      s.dispose
      return @icon_pics[pk] = [frame, Reloaded::PartyIcons.art_rect(frame, f)]
    rescue StandardError => e
      Reloaded::Log.warning_once("The Trainer Card couldn't draw an icon: #{e.message}", :trainer_card)
      return @icon_pics[pk] = nil
    end

    # The Pokémon a Showcase tile's icon shows (a mod can show another look:
    # Ghostly Possession shows a possessed one's fusion)
    def icon_for(pk)
      return pk
    end

    # After a Showcase tile is drawn: a mod can mark it (x, y, w, h: the tile)
    def showcase_tile(top, c, pk, x, y, w, h); end

    #--------------------------------------------------------------------------
    # Front: Portrait ID (his pick)
    #--------------------------------------------------------------------------
    def facts(c)
      out = [[_INTL("Money"), money(TC.money), pif(c, "Green")]]
      out << [_INTL("Platinum"), _INTL("{1} Pt", num(TC.platinum)), pif(c, "Cyan")] if TC.platinum?
      out << [_INTL("Pokédex"), "#{@dex_owned}/#{TC.dex_size}", dex_pair(c)]
      out << [_INTL("Time"), TC.play_words, pif(c, "Blue")]
      out << [_INTL("Started"), TC.started_words, season_pair(c)]
      return out
    end

    # The Pokédex's colour by how much of it is owned: red under a third,
    # orange under two, green after, blue when complete
    def dex_pair(c)
      f = @dex_owned.to_f / TC.dex_size
      return pif(c, f >= 1 ? "Blue" : (f >= 2 / 3.0 ? "Green" : (f >= 1 / 3.0 ? "Orange" : "Red")))
    end

    # Started: winter cyan, spring magenta, summer green, autumn purple
    def season_pair(c)
      t = TC.started
      return pif(c, "Dark") unless t
      m = t.mon
      return pif(c, [12, 1, 2].include?(m) ? "Cyan" : ([3, 4, 5].include?(m) ? "Magenta" : ([6, 7, 8].include?(m) ? "Green" : "Purple")))
    end

    # Run Tags in a row, wrapping inside x0..x1 from x, y: the y under them
    def run_tags(top, c, x0, x1, y, look = tags_now)
      tx = x0
      ty = y
      list = TC.run_tags
      list.each do |label, rgb|
        w = run_tag_width(label, look)
        if tx + w > x1
          tx = x0
          ty += 18
        end
        tx += tag(top, c, tx, ty, label, rgb, false, look) + 4
      end
      return list.empty? ? y : ty + 18
    end

    def draw_front(base, top, c)
      tabs(base, top, c)
      x0, y0, x1, y1 = CARD
      lanyard(base, 136, ART_Y0, 42)
      glass(base, c, x0, y0, x1, y1, 10)
      photo(base, c, x0 + 30, y0 + 8, x1 - 30, y0 + 70)
      stx(top, x0, y0 + 72, x1 - x0, 26, $Trainer.name, pif(c, "Dark"), PF::TITLE, 2)
      title_id(top, c, x0, x1 - x0, y0 + 98, UL.name(:titles, title_now).upcase, " · ID #{$Trainer.id}")
      list = facts(c)
      list.each_with_index do |(l, v, pair), i|
        y = y0 + 113 + i * 19
        stx(top, x0 + 12, y, 90, 19, l.upcase, pif(c, "Dark"), PF::TINY)
        stx(top, x0 + 12, y, x1 - x0 - 26, 19, v, pair, PF::TEXT, 1)
      end
      ly = y0 + 113 + list.length * 19 + 2
      divider(base, c, x0 + 12, x1 - 12, ly)
      ty = run_tags(top, c, x0 + 12, x1 - 12, ly + 5)
      badge_case(base, top, c, x0 + 12, ty + 2, 21, 8, 16, 20)
      trainer(base, *TRAINER_AT)
      showcase_tiles(base, top, c, 300, 256, 50, 46, 7)
    end

    #--------------------------------------------------------------------------
    # Records and Stats: the card's back
    #--------------------------------------------------------------------------
    def card_back(base, top, c, title)
      x0, y0, x1, y1 = CARD
      lanyard(base, 136, ART_Y0, 42)
      glass(base, c, x0, y0, x1, y1, 10)
      stx(top, x0, y0 + 6, x1 - x0, 26, title, pif(c, "Dark"), PF::TITLE, 2)
      title_id(top, c, x0, x1 - x0, y0 + 32, $Trainer.name.upcase, " · ID #{$Trainer.id}")
      divider(base, c, x0 + 12, x1 - 12, y0 + 48)
      return [x0, x1, y0, y1]
    end

    def draw_records(base, top, c)
      tabs(base, top, c)
      x0, x1, y0, _y1 = card_back(base, top, c, _INTL("Records"))
      wins = CT.get(:wins)
      battles = CT.stat(:battles)
      rows = [[_INTL("Wins"), wins, pif(c, "Green")], [_INTL("Losses"), CT.get(:losses), pif(c, "Red")],
              [_INTL("Battles"), battles, pif(c, "Dark")], [_INTL("Best Streak"), CT.get(:best_streak), pif(c, "Dark")],
              [_INTL("Current Streak"), CT.get(:streak), pif(c, "Dark")],
              [_INTL("Gym Rematches"), CT.stat(:gym_rematches), pif(c, "Dark")]]
      pitch = 24
      rows.each_with_index do |(l, v, pair), i|
        y = y0 + 54 + i * pitch
        stx(top, x0 + 12, y, 130, pitch, l.upcase, pif(c, "Dark"), PF::TINY)
        stx(top, x0 + 12, y, x1 - x0 - 26, pitch, num(v), pair, PF::ROW, 1)
      end
      ly = y0 + 54 + rows.length * pitch + 4
      divider(base, c, x0 + 12, x1 - 12, ly)
      recent_battles(base, top, c, x0, x1, ly)
      trainer(base, 300, 92)
      glass(base, c, 290, 252, 470, 336, 10)
      stx(top, 290, 258, 180, 12, _INTL("WIN RATE"), pif(c, "Dark"), PF::TINY, 2)
      if battles > 0
        rate = (wins * 100.0 / battles).round
        stx(top, 290, 272, 180, 26, "#{rate}%", pif(c, "Green"), PF::TITLE, 2)
        stx(top, 290, 304, 180, 22, _INTL("{1} of {2} Battles", num(wins), num(battles)), pif(c, "Dark"), PF::TEXT, 2)
      else
        stx(top, 290, 272, 180, 26, "-", pif(c, "Dark"), PF::TITLE, 2)
        stx(top, 290, 304, 180, 22, _INTL("No Battles Yet"), pif(c, "Dark"), PF::TEXT, 2)
      end
    end

    # The last three trainer battles, newest first: the trainer's face, PIF's
    # class small then the name, WIN or LOSS (his pick, in place of Last 5)
    def recent_battles(base, top, c, x0, x1, ly)
      stx(top, x0 + 12, ly + 6, 160, 12, _INTL("RECENT BATTLES"), pif(c, "Dark"), PF::TINY)
      list = CT.recent
      if list.empty?
        stx(top, x0 + 12, ly + 24, x1 - x0 - 24, 20, _INTL("None yet."), pif(c, "Dark"), PF::TEXT)
        return
      end
      list.first(CT::RECENT).each_with_index do |e, i|
        y = ly + 22 + i * 24
        face(base, top, c, e["type"].to_s, x0 + 12, y, 22)
        cls = trainer_class(e["type"]).upcase
        cw = cls.empty? ? -4 : stx(top, x0 + 40, y, 90, 22, cls, pif(c, "Dark"), PF::TINY)
        label = e["won"] ? _INTL("WIN") : _INTL("LOSS")
        room = x1 - 12 - (PF.width(PF::TINY, label) + 12) - 3 - (x0 + 40 + cw + 4)
        name = PF.fit(PF::TEXT, e["name"].to_s, room)
        stx(top, x0 + 40 + cw + 4, y, room, 22, name, pif(c, "Dark"), PF::TEXT)
        tag(top, c, x1 - 12, y + 4, label, e["won"] ? WIN_GREEN : LOSS_RED, true)
      end
    end

    def trainer_class(type)
      return "" if type.to_s.empty?
      return (::GameData::TrainerType.get(type.to_sym).name rescue "").to_s
    end

    # A trainer's face from their battle picture: a square around the head,
    # on a small plate
    def face(base, top, c, type, x, y, size)
      glass(base, c, x, y, x + size, y + size, 6, 0.8)
      crop = face_crop(type)
      return unless crop
      bm, rect = crop
      top.stretch_blt(Rect.new(x + 1, y + 1, size - 2, size - 2), bm, rect)
    end

    def face_crop(type)
      return nil if type.empty?
      return @faces[type] if @faces.key?(type)
      path = (::GameData::TrainerType.front_sprite_filename(type.to_sym) rescue nil) || "Graphics/Trainers/#{type}"
      bm = picture(path)
      return @faces[type] = nil unless bm
      _l, t, _r, _b = bounds_of(bm)
      w = bm.width
      xs = (0...w).step(2).select { |px| (t...[t + 24, bm.height].min).step(2).any? { |py| bm.get_pixel(px, py).alpha > 16 } }
      cx = xs.empty? ? w / 2 : (xs.first + xs.last) / 2
      s = 46
      return @faces[type] = [bm, Rect.new(cx - s / 2, t - 3, s, s)]
    rescue StandardError
      return @faces[type] = nil
    end

    def draw_stats(base, top, c)
      tabs(base, top, c)
      x0, x1, y0, _y1 = card_back(base, top, c, _INTL("Stats"))
      CT::STATS.each_with_index do |(id, name, icon), i|
        y = y0 + 54 + i * 30
        item(top, icon, x0 + 10, y + 3, 24)
        stx(top, x0 + 38, y, 110, 30, _INTL(name).upcase, pif(c, "Dark"), PF::TINY)
        stx(top, x0 + 12, y, x1 - x0 - 26, 30, num(CT.stat(id)), pif(c, "Dark"), PF::ROW, 1)
      end
      trainer(base, 300, 82)
      next_milestone(base, top, c)
    end

    # The Next Milestone under the trainer: the tracked one or the nearest,
    # its bar, what it unlocks
    def next_milestone(base, top, c)
      glass(base, c, 258, 240, 484, 348, 10)
      stx(top, 258, 246, 226, 12, _INTL("NEXT MILESTONE"), pif(c, "Dark"), PF::TINY, 2)
      m = UL.next_milestone
      unless m
        stx(top, 258, 280, 226, 26, _INTL("All Done"), pif(c, "Green"), PF::TITLE, 2)
        return
      end
      stat, tier, now, reward = m
      stx(top, 258, 259, 226, 26, "#{CT.name(stat)} #{num(tier)}", pif(c, "Blue"), PF::TITLE, 2)
      PP.bar(base, c, 292, 291, 158, [now.to_f / tier, 1.0].min, pif(c, "Blue")[0], 5)
      stx(top, 258, 301, 226, 20, _INTL("{1} of {2}", num(now), num(tier)), pif(c, "Dark"), PF::TEXT, 2)
      stx(top, 258, 322, 226, 20, PF.fit(PF::TEXT, _INTL("Next Unlock: {1}", UL.reward_words(*reward)), 214), pif(c, "Dark"), PF::TEXT, 2)
    end

    #--------------------------------------------------------------------------
    # Popups: Card Saved, Couldn't Copy
    #--------------------------------------------------------------------------
    def paint_saved(b, c, choice, shot, path, buttons)
      w = 360
      h = 214
      x = (W - w) / 2
      y = (H - h) / 2
      DL.frame(b, c, x, y, w, h, _INTL("Card Saved"))
      P.ui.rbox(b, x + w / 2 - 66, y + 42, x + w / 2 + 65, y + 141, 4, c[:line])
      b.stretch_blt(Rect.new(x + w / 2 - 64, y + 44, 128, 96), shot, Rect.new(0, 0, W, H))
      words = File.join(TC::FOLDER, File.basename(path)).tr("/", "\\")
      P.small(b, x, y + 144, w, 16, words, c[:dim], 2)
      DL.button_row(b, c, x, w, y + h - 36, buttons, choice)
    end

    def paint_no_copy(b, c, choice)
      w = 320
      h = 150
      x = (W - w) / 2
      y = (H - h) / 2
      DL.frame(b, c, x, y, w, h, _INTL("Couldn't Copy"))
      P.text(b, x, y + 40, w, 20, _INTL("There's no clipboard to copy to."), c[:txt], nil, 2)
      P.text(b, x, y + 62, w, 26, $Trainer.id.to_s, c[:strong], PF::TITLE, 2)
      P.small(b, x, y + 90, w, 16, _INTL("Write it down to give a friend."), c[:dim], 2)
      DL.button_row(b, c, x, w, y + h - 36, [_INTL("OK")], choice)
    end

    #--------------------------------------------------------------------------
    # Hints
    #--------------------------------------------------------------------------
    def hint_pairs
      return @popup_hints if @popup_hints
      case TABS[@tab]
      when :style then return style_hints
      when :unlocks then return unlocks_hints
      end
      return [[:lr, _INTL("Tabs")], [button(:C), _INTL("Actions"), :actions], [button(:B), _INTL("Close"), :close_card]]
    end
  end
end
