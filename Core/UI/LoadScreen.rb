#==============================================================================
# Kanto Reloaded: the Load Screen
#==============================================================================
# PIF's load screen, rebuilt (Roadmap topic 1, design 1): the big Continue
# panel (◂ ▸ switches save file; its note, trainer, badges, play time,
# Pokédex, backups, money, its Run Tags (mode, difficulty, DEBUG: RunTags),
# health and party; a test copy's purple strip in its note's place), then the
# rows: New Game, What's New (NEW until read), Mystery Gift, Options, Save
# Manager, KIF Beta's links, Quit. The list scrolls like PIF's; Kanto
# Reloaded's and KIF Beta's versions are centred above the Continue panel.
#
# On Continue: Y edits the save's note, holding Y opens the Save Checker;
# holding A lists its backups to go back to; a damaged save offers its
# newest good backup.
#
# Only the view is replaced (PokemonLoad_Scene, a prepended module): PIF's
# PokemonLoadScreen still runs the menu, so KIF Beta's updater, imports and
# first-run questions all still happen. pbChoose answers as PIF's does (an
# entry's index; -3 / -2 for Left / Right on Continue). What's New and Save
# Manager are rows of PIF's link list (Settings::MAIN_MENU_LINKS, as KIF
# adds its own) with addresses this catches. After a restore or a change in
# the Save Manager, the menu reads the saves again (KIF's way: -3, landing
# on the slot asked for). Always on with Kanto Reloaded (his call, 2026-10-25).
#==============================================================================

return unless defined?(Reloaded::Frame) && defined?(::KIF::PixelFont)

module Reloaded
  module LoadScreen
    WHATS_NEW = "kr:whats-new".freeze
    SAVE_MANAGER = "kr:save-manager".freeze
    LINKS = { "What's New" => WHATS_NEW, "Save Manager" => SAVE_MANAGER }.freeze

    class << self
      # The slot the next -3 lands on (:none: no save), and whether pbChoose
      # should give -3 at once.
      attr_accessor :reload_to, :reload_now
      attr_accessor :offered           # the crash report offer, once a session

      def boot
        return true unless defined?(::PokemonLoad_Scene)
        Reloaded::Hooks.prepend(nil, "PokemonLoad_Scene", SceneView, :id => :load_screen_view)
        if defined?(::SaveData) && ::SaveData.respond_to?(:get_prev_slot)
          Reloaded::Hooks.around(nil, ::SaveData.singleton_class, :get_prev_slot, :id => :load_screen_reload) do |original, *args|
            target = Reloaded::LoadScreen.reload_to
            if target
              Reloaded::LoadScreen.reload_to = nil
              next target == :none ? nil : target
            end
            original.call(*args)
          end
        end
        Reloaded::Hooks.around(nil, ::Object, :openUrlInBrowser, :id => :load_screen_links) do |original, url = "", *rest|
          Reloaded::LoadScreen.link(url) || original.call(url, *rest)
        end
        Reloaded::Events.on(:title_screen, :load_screen_rows) { update_links }
        return true
      end

      # Kanto Reloaded's Load Screen is showing.
      def active?
        return Reloaded::Saves.load_screen?
      end

      # What's New and Save Manager are rows only while it's on.
      def update_links
        links = defined?(::Settings::MAIN_MENU_LINKS) ? ::Settings::MAIN_MENU_LINKS : nil
        return unless links.is_a?(Hash) && !links.frozen?
        LINKS.each { |label, url| active? ? links[label] = url : links.delete(label) }
      end

      # A row of ours was chosen (true), or nil for a real link.
      def link(url)
        case url.to_s
        when WHATS_NEW
          Reloaded::WhatsNewScreen.open if defined?(Reloaded::WhatsNewScreen)
          return true
        when SAVE_MANAGER
          slot = SceneView.current_slot
          changed = defined?(Reloaded::SaveManagerScreen) ? Reloaded::SaveManagerScreen.open(true, :active, slot) : false
          reload(File.file?(Reloaded::Saves.path(slot.to_s)) ? slot : nil) if changed
          return true
        end
        return nil
      end

      # The menu reads the saves again, landing on slot (or the newest).
      def reload(slot = nil)
        slot ||= Reloaded::Saves.slots.max_by { |s| File.mtime(Reloaded::Saves.path(s)) rescue Time.at(0) }
        @reload_to = slot || :none
        @reload_now = true
      end
    end

    #--------------------------------------------------------------------------
    # PokemonLoad_Scene, while Kanto Reloaded's Load Screen is on
    #--------------------------------------------------------------------------
    module SceneView
      class << self
        attr_accessor :current_slot
      end

      def pbStartScene(commands, show_continue, trainer, frame_count, map_id)
        return super unless Reloaded::LoadScreen.active?
        @kr_view = Reloaded::LoadScreen::View.new(commands, show_continue, trainer, frame_count, map_id)
        SceneView.current_slot = show_continue ? commands[0].to_s : nil
        @kr_view.open
      rescue StandardError => e
        Reloaded::Log.exception("The Load Screen couldn't open; the game's own instead", e, :saves)
        @kr_view.close(false) rescue nil
        @kr_view = nil
        super
      end

      def pbStartScene2
        return super unless @kr_view
        @kr_view.fade(:in)
      end

      def pbSetParty(trainer)
        return super unless @kr_view
        @kr_view.party = trainer
      end

      def pbUpdate
        return super unless @kr_view
        @kr_view.update_sprites
      end

      def pbChoose(commands, continue_idx = -1, *rest)
        return super unless @kr_view
        if defined?(::KIF::SaveFolder) && ::KIF::SaveFolder.respond_to?(:reload) && ::KIF::SaveFolder.reload
          ::KIF::SaveFolder.reload = false          # KIF imported saves: read them again
          return -3
        end
        if Reloaded::LoadScreen.reload_now
          Reloaded::LoadScreen.reload_now = false
          return -3
        end
        return @kr_view.choose(commands, continue_idx)
      end

      def pbEndScene
        return super unless @kr_view
        @kr_view.close(true)
        @kr_view = nil
      end

      def pbCloseScene
        return super unless @kr_view
        @kr_view.close(false)
        @kr_view = nil
      end
    end

    #--------------------------------------------------------------------------
    # The view
    #--------------------------------------------------------------------------
    class View
      include Reloaded::Frame

      PF = ::KIF::PixelFont
      P = Reloaded::Pixel
      PANEL_X0 = 48
      PANEL_X1 = W - 48
      ROW_X0 = 62
      ROW_X1 = W - 62
      TOP = 26                # where the list starts
      VERSIONS_Y = 7          # the versions' small text, its letters centred in 0..TOP
      PANEL_H = 204
      ROW_H = 22
      ROW_STEP = 24
      INFO_X = PANEL_X0 + 104   # the details' column; the trainer stands left of it
      INFO_X1 = PANEL_X1 - 14
      TRAINER_X = PANEL_X0 + 56
      BOTTOM = H - P::HINT_H - 6
      # (statuses are the palette's tones: c[:green], c[:gold]... deeper in Light)
      CHARCOAL = Color.new(0x38, 0x38, 0x40)   # KIF Beta's version, on PIF's light background
      KR_RED = Color.new(214, 52, 60)          # Kanto Reloaded's (the roadmap's red)
      NEW_FILL = Color.new(60, 50, 10)         # the NEW pill on Dark
      HEALTH = { :healthy => ["HEALTHY", :green], :check => ["CHECK", :amber], :damaged => ["DAMAGED", :red] }.freeze
      S = Reloaded::Saves

      attr_reader :entry

      def initialize(commands, show_continue, trainer, frame_count, map_id)
        frame_init
        @commands = commands
        @show_continue = show_continue
        @trainer = trainer
        @frame_count = frame_count.to_i
        @map_id = map_id
        @slot = show_continue ? commands[0].to_s : nil
        @sel = 0
        @scroll = 0
        @icons = []
        @new = (Reloaded::WhatsNew.unseen? rescue false)
        @order = display_order
        read_save
      end

      def open
        open_sprites
        @viewport.z = 99_998
        @bg = Sprite.new(@viewport)
        @bg.z = -1
        bg = defined?(::RPG::Cache) ? (RPG::Cache.picture("loadbg") rescue nil) : nil
        @bg.bitmap = bg || Bitmap.new(W, H).tap { |b| b.fill_rect(0, 0, W, H, palette[:bg]) }
        refresh
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

      # PIF's: the walking sprite and party icons, from the save's trainer.
      def party=(trainer)
        @trainer = trainer
        make_sprites
        refresh
      end

      def update_sprites
        @icons.each { |s| s.update unless s.disposed? }
      end

      def fade(way)
        return unless @viewport
        steps = 8
        steps.times do |i|
          a = way == :in ? 255 - (i + 1) * 255 / steps : (i + 1) * 255 / steps
          @viewport.color = Color.new(0, 0, 0, a)
          Graphics.update
        end
        @viewport.color = Color.new(0, 0, 0, 0) if way == :in
      end

      def close(fading)
        fade(:out) if fading
        @icons.each { |s| s.dispose unless s.disposed? }
        @icons = []
        if @trainer_sprite && !@trainer_sprite.disposed?
          @trainer_sprite.bitmap.dispose if @trainer_sprite.bitmap && @own_trainer_bitmap
          @trainer_sprite.dispose
        end
        @bg.dispose if @bg && !@bg.disposed?
        dispose_sprites
      end

      # The menu's answer: an entry's index (PIF's numbering), -3 / -2 for
      # Left / Right on Continue.
      def choose(commands, continue_idx)
        @commands = commands
        @order = display_order if @order.length != commands.length
        @new = (Reloaded::WhatsNew.unseen? rescue false)     # What's New may have just been read
        refresh
        offer_report
        loop do
          Graphics.update
          Input.update
          update_frame
          update_sprites
          Reloaded::Toast.update if defined?(Reloaded::Toast)     # the startup checks' toast
          result = handle_input
          return result if result
        end
      end

      private

      #------------------------------------------------------------------------
      # The rows
      #------------------------------------------------------------------------
      # PIF's entries, in the design's order: [index in commands]
      def display_order
        label = ->(t) { _INTL(t) }
        find = ->(t) { @commands.index { |x| x.to_s == label.call(t) || x.to_s == t } }
        first = []
        first << 0 if @show_continue
        named = ["New Game", "New Game +", "What's New", "Mystery Gift", "Options", "Save Manager"].map { |t| find.call(t) }.compact
        last = ["Debug", "Quit Game"].map { |t| find.call(t) }.compact
        hidden = [find.call("Savefile management")].compact       # the Save Manager does it, and more
        rest = (0...@commands.length).to_a - first - named - last - hidden
        return first + named + rest + last
      end

      def continue?(i)
        return @show_continue && @order[i] == 0
      end

      def label_of(i)
        return @commands[@order[i]].to_s
      end

      # The top of row i in the list (before scrolling).
      def row_y(i)
        y = TOP
        y += PANEL_H + 6 if @show_continue && i > 0
        y += ((@show_continue ? i - 1 : i)) * ROW_STEP if i > 0
        return y
      end

      def row_height(i)
        return continue?(i) ? PANEL_H : ROW_H
      end

      def keep_in_view
        y0 = row_y(@sel) - @scroll
        y1 = y0 + row_height(@sel)
        @scroll += y1 - BOTTOM if y1 > BOTTOM
        @scroll -= TOP - y0 if y0 < TOP
        @scroll = [@scroll, 0].max
        place_sprites
      end

      def content_height
        return row_y(@order.length - 1) + ROW_H
      end

      #------------------------------------------------------------------------
      # The save
      #------------------------------------------------------------------------
      def read_save
        return unless @slot
        @path = S.path(@slot)
        @pv = File.file?(@path) ? S.preview(@path, :party => false) : { :health => :damaged, :problem => "The file isn't there." }
        @backups = S.backups(@slot).length
        @note = S.note(@slot, @pv)
        @tag = S.tag(@slot, @pv)
      end

      # Under the popups (the overlay), over the panel.
      def make_sprites
        @icons.each { |s| s.dispose unless s.disposed? }
        @icons = []
        return unless @trainer && @viewport
        @icons = Reloaded::PartyIcons.row((@trainer.party rescue nil), @viewport, 0, 0, INFO_X1 - INFO_X)
        make_trainer
        place_sprites
      end

      # The save's trainer, front on (its outfit), else PIF's walking sprite.
      def make_trainer
        @trainer_sprite = Sprite.new(@viewport)
        @trainer_sprite.z = 2
        bmp = nil
        if defined?(generate_front_trainer_sprite_bitmap)
          old = $Trainer
          begin
            $Trainer = @trainer
            ball = (@trainer.party[0].poke_ball rescue nil)
            made = generate_front_trainer_sprite_bitmap(false, ball)
            bmp = made.respond_to?(:bitmap) ? made.bitmap : made
            @own_trainer_bitmap = true
          rescue StandardError
            bmp = nil
          ensure
            $Trainer = old
          end
        end
        if bmp.nil? && defined?(::GameData::Metadata) && defined?(pbGetPlayerCharset)
          meta = (::GameData::Metadata.get_player(@trainer.character_ID) rescue nil)
          file = meta ? (pbGetPlayerCharset(meta, 1, @trainer, true) rescue nil) : nil
          if file
            bmp = (RPG::Cache.load_bitmap("", file) rescue nil) || (Bitmap.new(file) rescue nil)
            @trainer_sprite.src_rect = Rect.new(0, 0, bmp.width / 4, bmp.height / 4) if bmp
            @own_trainer_bitmap = false
          end
        end
        @trainer_sprite.bitmap = bmp
        return unless bmp
        w = @trainer_sprite.src_rect.width
        h = @trainer_sprite.src_rect.height
        zoom = h > 170 ? 170.0 / h : (h < 48 ? 2.0 : 1.0)
        @trainer_sprite.zoom_x = @trainer_sprite.zoom_y = zoom
        @trainer_sprite.ox = w / 2            # stands on the panel's bottom
        @trainer_sprite.oy = h
      end

      # The trainer left of the details, the party in a row under them.
      def place_sprites
        return unless @show_continue
        y0 = row_y(0) - @scroll
        Reloaded::PartyIcons.arrange(@icons, (INFO_X + INFO_X1) / 2, y0 + 175, INFO_X1 - INFO_X)
        @icons.each { |s| s.visible = y0 + 160 > 0 }
        return unless @trainer_sprite && @trainer_sprite.bitmap
        @trainer_sprite.x = TRAINER_X
        @trainer_sprite.y = y0 + PANEL_H - 4
        @trainer_sprite.visible = y0 + PANEL_H - 40 > 0
      end

      #------------------------------------------------------------------------
      # Input
      #------------------------------------------------------------------------
      def handle_input
        pt = Reloaded::Pointer
        if pointer_hover && (i = pt.hit(@row_hits)) && i != @sel
          select(i)
        end
        if pt.left?
          handled, result = hint_click
          return result if handled
          if (i = pt.hit(@row_hits))
            select(i) if i != @sel
            return pick
          end
          return nil
        end
        if (dir = pt.wheel) != 0
          select([[@sel + dir, 0].max, @order.length - 1].min)
          return nil
        end
        if Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)
          dir = Input.repeat?(Input::DOWN) ? 1 : -1
          target = @sel + dir
          if target < 0 || target >= @order.length
            return nil unless fresh?(dir)
            target = dir < 0 ? @order.length - 1 : 0
          end
          select(target)
        elsif continue?(@sel) && (Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT))
          return switch_file(Input.trigger?(Input::LEFT) ? -3 : -2)
        elsif Input.trigger?(Input::USE)
          return hold_or_pick
        elsif Input.trigger?(Input::X) && continue?(@sel)       # a controller's Y
          return hold_y
        elsif Input.trigger?(Input::BACK) && @sel != 0
          pbPlayCancelSE
          select(0)
        end
        return nil
      end

      def select(i)
        @sel = i
        pbPlayCursorSE
        keep_in_view
        refresh
      end

      def switch_file(code)
        return pbPlayBuzzerSE if S.slots.length < 2
        return code
      end

      # A on Continue: held, its backups; let go, it loads.
      def hold_or_pick
        return pick unless continue?(@sel)
        frames = hold_frames
        held = 0
        while Input.press?(Input::USE) && held < frames
          Graphics.update
          Input.update
          update_frame
          update_sprites
          held += 1
          paint_hold(held.to_f / frames)
        end
        overlay.clear
        return held >= frames ? (backups_menu || nil) : pick
      end

      # Once, over the menu: the last session crashed or never ended, so a
      # bug report is offered (Bug Reports' Crash).
      def offer_report
        return if Reloaded::LoadScreen.offered || !defined?(Reloaded::BugReport::Crash)
        Reloaded::LoadScreen.offered = true
        Graphics.update
        Reloaded::BugReport::Crash.offer_pending if Reloaded::BugReport::Crash.pending
        refresh
      rescue StandardError => e
        Reloaded::Log.exception("The crash report offer didn't show", e, :bug_report)
      end

      # Y on Continue: let go, the note; held, the Save Checker.
      def hold_y
        frames = hold_frames
        held = 0
        while Input.press?(Input::X) && held < frames
          Graphics.update
          Input.update
          update_frame
          update_sprites
          held += 1
          paint_hold(held.to_f / frames)
        end
        overlay.clear
        return check_save if held >= frames
        edit_note
        return nil
      end

      # The Save Checker on the save shown; a fix reads the saves again.
      def check_save
        return pbPlayBuzzerSE unless defined?(Reloaded::SaveCheckScreen) && @path && File.file?(@path)
        pbPlayDecisionSE
        changed = hidden { Reloaded::SaveCheckScreen.open(@path, :slot => @slot) }
        if changed
          Reloaded::LoadScreen.reload(@slot)
          Reloaded::LoadScreen.reload_now = false
          return -3
        end
        refresh
        return nil
      end

      # Hold Time (Controls), as frames.
      def hold_frames
        table = defined?(Reloaded::Controls::HOLD_SECONDS) ? Reloaded::Controls::HOLD_SECONDS : []
        seconds = table[(Reloaded::Settings.get(:"controls.hold_time") rescue nil).to_i] || 0.4
        return [(seconds * (Graphics.frame_rate rescue 40)).round, 8].max
      end

      def paint_hold(fraction)
        c = palette
        o = overlay
        o.clear
        y = row_y(0) - @scroll + PANEL_H - 8
        w = PANEL_X1 - PANEL_X0 - 24
        o.fill_rect(PANEL_X0 + 12, y, w, 3, c[:line])
        o.fill_rect(PANEL_X0 + 12, y, (w * fraction).to_i, 3, c[:selb])
      end

      # The chosen entry (PIF's index); a damaged save asks first.
      def pick
        if continue?(@sel) && @pv && @pv[:health] == :damaged
          return damaged_offer
        end
        return @order[@sel]
      end

      def damaged_offer
        good = S.newest_good_backup(@slot)
        text = _INTL("{1} is damaged: {2}", @slot, @pv[:problem].to_s)
        unless good
          Reloaded::Dialogs.notice(self, _INTL("Damaged Save"), text + " " + _INTL("It has no backup that reads whole."))
          refresh
          return nil
        end
        choice = Reloaded::Dialogs.buttons_dialog(self, _INTL("Damaged Save"),
          text + " " + _INTL("Its newest good backup is from {1}.", when_text(good[:time])),
          [_INTL("Restore It"), _INTL("Continue Anyway"), _INTL("Cancel")], 0)
        refresh
        case choice
        when 0 then return restore(good)
        when 1 then return @order[@sel]
        end
        return nil
      end

      # Holding A: the save's backups, to go back to.
      def backups_menu
        list = S.backups(@slot)
        if list.empty?
          Reloaded::Dialogs.notice(self, _INTL("Backups"), _INTL("{1} has no backups yet.", @slot))
          refresh
          return nil
        end
        labels = list.map { |b| b[:name] ? "#{when_text(b[:time])}: #{b[:name]}" : when_text(b[:time]) }
        descs = list.map do |b|
          pv = S.preview(b[:path], :party => false)
          pv[:health] == :damaged ? _INTL("Damaged: {1}", pv[:problem].to_s) : _INTL("{1}, played {2}.", pv[:map] || "?", play_time(pv[:seconds]))
        end
        i = Reloaded::Dialogs.menu(self, _INTL("{1} Backups", @slot), labels, descs)
        refresh
        return nil unless i
        return restore(list[i])
      end

      # The backup takes the save's place (the save kept as a backup), and
      # the menu reads it again.
      def restore(backup)
        text = _INTL("{1} goes back to {2}. The save as it is now is kept as a backup named Before Restore.", @slot, when_text(backup[:time]))
        return nil unless Reloaded::Dialogs.confirm(self, _INTL("Go Back to This Backup?"), text, _INTL("Go Back"), _INTL("Cancel"), false)
        S.restore_backup(@slot, backup)
        Reloaded::LoadScreen.reload(@slot)
        Reloaded::LoadScreen.reload_now = false
        return -3
      rescue StandardError => e
        Reloaded::Log.exception("A backup couldn't be restored", e, :saves)
        Reloaded::Dialogs.notice(self, _INTL("Backups"), _INTL("That didn't work: {1}", e.message))
        refresh
        return nil
      end

      def edit_note
        pbPlayDecisionSE
        text, how = Reloaded::TextEntry.run(self, _INTL("Type a Note"), @note.to_s, 100, :prompt => _INTL("{1}'s Note", @slot))
        if how == :enter
          S.set_note(@slot, text, @pv)
          @note = S.note(@slot, @pv)
        end
        refresh
      end

      #------------------------------------------------------------------------
      # Painting
      #------------------------------------------------------------------------

      def draw_screen
        c = palette
        base = @sprite.bitmap
        top = @top_sprite.bitmap
        base.clear
        top.clear
        @cursor_rect = nil
        @row_hits = []
        versions(top, c) if @scroll.zero?
        @order.each_index do |i|
          y = row_y(i) - @scroll
          h = row_height(i)
          next if y + h < 0 || y + h > BOTTOM + 2          # nothing under the hint line
          continue?(i) ? paint_continue(base, top, c, y) : paint_row(base, top, c, i, y)
          @row_hits << [i, continue?(i) ? PANEL_X0 : ROW_X0, y, continue?(i) ? PANEL_X1 : ROW_X1, y + h] if y >= 0 && y + h <= BOTTOM + 4
        end
        paint_scroll(base, c)
        paint_hints(base, c)
        place_cursor
      end

      # "Kanto Reloaded 2.0.0 · KIF 1.0.7", centred between the top
      # of the screen and the Continue panel: Kanto Reloaded's in red, KIF
      # Beta's in charcoal (PIF's background is light there).
      def versions(top, c)
        ours = "Kanto Reloaded #{Reloaded.version}"
        kif = Reloaded::WhatsNew.kif_version rescue nil
        rest = kif ? " · KIF #{kif}" : ""
        P.small_font(top)
        w1 = top.text_size(ours).width
        w2 = rest.empty? ? 0 : top.text_size(rest).width
        x = (W - w1 - w2) / 2
        P.small(top, x, VERSIONS_Y, w1 + 4, 16, ours, KR_RED)
        P.small(top, x + w1, VERSIONS_Y, w2 + 4, 16, rest, CHARCOAL) unless rest.empty?
      end

      def paint_continue(base, top, c, y)
        on = @sel == 0
        x0 = PANEL_X0
        x1 = PANEL_X1
        P.ui.rbox(base, x0, y, x1, y + PANEL_H, 7, on ? Reloaded::Palette.mix(c[:selb], c[:panel2], 0.55) : c[:panel2], on ? c[:selb] : c[:line])
        rgb = S.tag_rgb(@tag)
        P.ui.rbox(top, x0 + 5, y + 8, x0 + 9, y + PANEL_H - 8, 2, rgb ? Color.new(*rgb) : c[:line])
        P.text(top, x0 + 18, y + 2, 200, 26, _INTL("Continue"), c[:txt], PF::ROW)
        map = @pv && @pv[:map] || (defined?(pbGetMapNameFromId) && @map_id ? (pbGetMapNameFromId(@map_id) rescue "") : "")
        P.text(top, x1 - 210, y + 2, 198, 26, PF.fit(PF::ROW, map.to_s, 198), c[:green], PF::ROW, 1)
        many = S.slots.length > 1
        P.ui.tri(top, x0 + 20, y + 33, :l, many ? c[:dim] : c[:line], 4) if many
        P.ui.tri(top, x1 - 26, y + 33, :r, many ? c[:dim] : c[:line], 4) if many
        P.text(top, x0, y + 24, x1 - x0, 24, @slot.to_s, c[:txt], PF::ROW, 2)
        lx = INFO_X
        rx = x0 + 246
        test = @pv && @pv[:test_of]
        if @entry
          Reloaded::TextEntry.draw_field(base, top, c, @entry, lx - 4, y + 46, INFO_X1 - lx + 4, 20)
        elsif test && @note.to_s.empty?
          # a test copy: a soft purple strip in the note's place (a fill, no outline)
          colour = Reloaded::RunTags.purple(c)
          P.ui.rbox(base, lx - 4, y + 47, INFO_X1, y + 64, 4, Reloaded::RunTags.fill(c, colour))
          P.text(top, lx - 4, y + 47, INFO_X1 - lx + 4, 17, _INTL("TEST COPY OF {1} · DEBUG IF LOADED HERE", test.to_s.upcase), colour, PF::TINY, 2)
        else
          note = @note.to_s.empty? ? _INTL("No note yet. Y writes one.") : @note
          P.small(top, lx, y + 48, INFO_X1 - lx, 16, fit_small(top, note, INFO_X1 - lx), @note.to_s.empty? ? c[:dim] : c[:gold])
        end
        t = @trainer
        name_colour = t && (t.female? rescue false) ? c[:pink] : c[:blue]
        cols = [[lx, rx - 10], [rx, INFO_X1]]
        # [label, value, label colour, value colour]: the Save Manager's
        # colours (play time gold, money green); the mode and difficulty
        # are Run Tags, on the row under these
        lines = [[[t ? t.name.to_s : "?", nil, name_colour], [_INTL("Time"), play_time(@pv && @pv[:seconds] || @frame_count / 40), nil, c[:gold]]],
                 [[_INTL("Badges"), (t.badge_count rescue 0).to_s], [_INTL("Pokédex"), dex_text]],
                 [[_INTL("Backups"), @backups.to_i.to_s], [_INTL("Money"), money_text, nil, c[:green]]]]
        lines.each_with_index do |row, k|
          ly = y + 66 + k * 22
          row.each_with_index do |cell, j|
            next unless cell
            label, value, colour, value_colour = cell
            from, to = cols[j]
            P.text(top, from, ly, to - from, 22, label.to_s, colour || c[:txt])
            P.text(top, from, ly, to - from, 22, value.to_s, value_colour || c[:txt], nil, 1) if value
          end
        end
        # the Run Tags on the left, the health on the right
        Reloaded::RunTags.draw(top, Reloaded::RunTags.parts(c, @pv), lx, y + 133)
        label, tone = HEALTH[(@pv || {})[:health]] || HEALTH[:damaged]
        colour = c[tone]
        P.pill(top, INFO_X1, y + 133, _INTL(label), dark_fill(colour), colour)
        @cursor_rect = nil if on
      end

      def dex_text
        pd = (@trainer.pokedex rescue nil)
        owned = (@pv && @pv[:owned]) || (pd.owned_count rescue nil)
        seen = (@pv && @pv[:seen]) || (pd.seen_count rescue nil)
        return "#{owned || "?"} / #{seen || "?"}"
      end

      def money_text
        m = (@trainer.money rescue 0).to_i
        return "$#{m.to_s.reverse.scan(/\d{1,3}/).join(",").reverse}"
      end

      def paint_row(base, top, c, i, y)
        on = i == @sel
        P.ui.rbox(base, ROW_X0, y, ROW_X1, y + ROW_H, 5, on ? Reloaded::Palette.mix(c[:selb], c[:panel2], 0.55) : c[:panel2],
                  on ? c[:selb] : c[:line])
        label = label_of(i)
        colour = label == _INTL("Save Manager") || label == "Save Manager" ? c[:gold] : c[:txt]
        P.text(top, ROW_X0 + 14, y - 1, ROW_X1 - ROW_X0 - 80, ROW_H + 2, label, colour, PF::ROW)
        if (label == _INTL("What's New") || label == "What's New") && @new
          P.pill(top, ROW_X1 - 10, y + 4, _INTL("NEW"), c[:light] ? dark_fill(c[:gold]) : NEW_FILL, c[:gold])
        end
      end

      # The bar at the side, when the list is taller than the screen.
      def paint_scroll(base, c)
        total = content_height
        room = BOTTOM - TOP
        return if total <= room
        x = W - 40
        P.ui.rbox(base, x, TOP + 230, x + 14, TOP + 290, 5, c[:dark], c[:line])
        P.ui.tri(base, x + 3, TOP + 236, :u, @scroll > 0 ? c[:txt] : c[:line], 4)
        P.ui.tri(base, x + 3, TOP + 278, :d, @scroll + room < total ? c[:txt] : c[:line], 4)
      end

      #------------------------------------------------------------------------
      # Words
      #------------------------------------------------------------------------
      def when_text(time)
        return "?" unless time.is_a?(Time)
        clock = time.strftime("%l:%M %p").strip
        today = Time.now
        return _INTL("Today {1}", clock) if time.year == today.year && time.yday == today.yday
        y = today - 86_400
        return _INTL("Yesterday {1}", clock) if time.year == y.year && time.yday == y.yday
        return time.strftime(time.year == today.year ? "%b %-d" : "%b %-d %Y")
      end

      # "41h 12m"
      def play_time(seconds)
        return "?" unless seconds
        return _INTL("{1}h {2}m", seconds.to_i / 3600, seconds.to_i / 60 % 60)
      end

      def fit_small(b, text, w)
        P.small_font(b)
        return text if b.text_size(text).width <= w
        text = text[0...-1] while text.length > 1 && b.text_size(text + "...").width > w
        return text + "..."
      end

      def hint_pairs
        if @entry
          return [[button(:C), _INTL("Type")], [button(:B), _INTL("Cancel")]] if Reloaded::Prompts.controller?
          return [[nil, _INTL("Type")], [Reloaded::Controls::Inputs.key(40), _INTL("Done")], [Reloaded::Controls::Inputs.key(41), _INTL("Cancel")]]
        end
        if continue?(@sel)
          out = [[:ud, _INTL("Choose")]]
          out << [:lr, _INTL("Save File")] if S.slots.length > 1
          return out + [[button(:C), _INTL("Select")], [button(:C), _INTL("Hold: Backups")], [button(:X), _INTL("Edit Note")],
                        [button(:X), _INTL("Hold: Check")]]
        end
        return [[:ud, _INTL("Choose")], [button(:C), _INTL("Open")], [button(:B), _INTL("Back")]]
      end
    end
  end
end
