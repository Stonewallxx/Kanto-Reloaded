# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Reloaded PC's scene
#==============================================================================
# Kanto Reloaded's PokemonStorageScene (Reloaded::PC.scene_class includes
# this): the same methods PIF's PC logic (PokemonStorageScreen, its
# multi-select, KIF's box commands and Kuray Actions) calls, drawn his way.
#
#   the header    the previous box (LB) and the next (RB) either side, the
#                 box's name in the middle, a red padlock and SORT / EXPORT
#                 after it only when KIF has locked it (his pick: Padlock
#                 When Locked). While fusing, a gold banner with the
#                 Splicer and FUSING WITH LAPRAS in the name's place (his
#                 pick: Header Banner); while choosing for something, a
#                 banner saying so.
#   the box       the whole 6 x 5 on its wallpaper (his pick), each slot's
#                 Pokémon with PIF's box icon (so KIF's Big Pokémon Icons
#                 show here at All only, as KIF has it, his pick)
#   the plate     the highlighted one's details, lit in its type's colour:
#                 the picture, name, level, types, nature, ability, item,
#                 IVs (a 31 in gold); an Egg's steps
#   the party     along the bottom with HP bars; empty places dashed
#
# One press to move (his pick): A picks up and puts down (PIF's own Quick
# Swap mode, which the scene keeps on), X opens the Actions (PIF's list,
# KIF's and mods' rows in it), LB / RB change box, B closes; with a
# Pokémon held, B puts it back where it came from. Up from the top row
# reaches the box name (A: the Box Overview, X: the box's actions; the box
# tools are in UI/PCTools.rb). A held Pokémon floats
# over the slot under the cursor with a small shadow, a soft patch in its old slot
# (his pick: Lifted). Y picks several (Free Picks, UI/PCPicks.rb), RS
# searches (UI/PCSearch.rb). The mouse: pointing picks, a click does what A does,
# a right click goes back, the wheel over the box changes box.
#
# Withdraw, Deposit, choosing from the PC (the ones that can't be chosen
# dimmed), the Purify Chamber and KIF's Graveyard run the game's own loops
# on this scene: A there does what the game does (its list).
#==============================================================================

return unless defined?(Reloaded::Frame) && defined?(Reloaded::PartyPaint) && defined?(::KIF::PixelFont)

module Reloaded
  module PCScene
    include Reloaded::Frame

    PF = ::KIF::PixelFont
    PP = Reloaded::PartyPaint
    COLS = 6
    ROWS = 5
    BOX_X = 10            # the box's first slot
    BOX_Y = 40
    CELL_W = 50
    CELL_H = 45
    ART = 40              # a box icon's art fits in this
    PLATE = [320, 36, W - 6, 268].freeze
    PLATE_LINE = 161      # the red line between the picture and the details
    PARTY_Y = 274
    PARTY_Y1 = H - P::HINT_H - 4
    PARTY_STEP = (W - 12 - 24) / 6
    # The box part of a wallpaper (324 x 296), inside its frame
    WALL_SRC = [13, 62, 296, 221].freeze
    BANDS = [[0, 56], [40, 8]].freeze
    IV_KEYS = [[:HP, "HP"], [:ATTACK, "ATK"], [:DEFENSE, "DEF"], [:SPECIAL_ATTACK, "SPA"], [:SPECIAL_DEFENSE, "SPD"], [:SPEED, "SPE"]].freeze
    # Not offered: KIF's Gamble for Shiny in RLD Actions (his ask, 2026-10-24)
    HIDDEN_LABELS = ["Gamble for Shiny", "Gamble for new Color"].freeze
    # PIF's six marks (Graphics/Pictures/Storage/markings: 16 px, off on top,
    # on below), Mark's popup (his pick: Shape Row) and the plate's corner
    SHAPES = ["Circle", "Triangle", "Square", "Heart", "Star", "Diamond"].freeze
    MARK_SHEET = "Graphics/Pictures/Storage/markings"
    MENU_W = 300
    MENU_ROW = 24
    MENU_HEAD = 16
    MENU_ROOM = 192           # the rows' height before the list scrolls

    # What the game's code reaches through scene.sprites: the box sprite's
    # fusion switch, its own refresh; everything else does nothing
    class Stub
      def initialize(scene)
        @scene = scene
      end

      def disableFusions(*_a)
        @scene.kr_fusions(false)
      end

      def enableFusions(*_a)
        @scene.kr_fusions(true)
      end

      def isFusionEnabled
        return true
      end

      def getPokemon(*_a)
        return nil
      end

      def disposed?
        return false
      end

      def method_missing(_name, *_args, &_blk)
        return nil
      end

      def respond_to_missing?(_name, _priv = false)
        return true
      end
    end

    # The screen's layers for Frame, the game's sprite names for its code
    class Sprites < Array
      attr_accessor :stub

      def [](key, *rest)
        return stub if key.is_a?(String)
        return super
      end
    end

    attr_reader :cursormode, :screen, :inTransferBox, :quickswap
    attr_accessor :choseFromParty, :selection

    #--------------------------------------------------------------------------
    # Starting and closing
    #--------------------------------------------------------------------------
    def pbStartBox(screen, command, animate = true)
      return fb(:pbStartBox, screen, command, animate) if @kr_fb
      @screen = screen
      @storage = screen.storage
      @command = command
      @selection = 0
      @quickswap = false
      @choseFromParty ||= false
      @cursormode = quick? ? "quickswap" : "default"
      @kr_held_from = nil
      @kr_fusions_on = true
      @kr_rect = nil
      @kr_name_col = 0
      @kr_party_col = 0
      @kr_chose_seen = false
      @kr_icons = {}
      @kr_art = {}
      @kr_pictures = {}
      @popup_hints = nil
      @kr_stub = Stub.new(self)
      @kr_focus = start_focus
      @kr_picks = nil
      @kr_multi_from = nil
      @kr_search = nil
      @kr_match = {}
      @kr_compare = nil
      @kr_cmp = nil
      @kr_drag = nil
      @kr_fresh = begin                  # NEW marks: here since the last visit
                    Reloaded::PC.fresh_ids(@storage)
                  rescue StandardError
                    {}
                  end
      frame_init
      open_sprites
      @kr_marks = layer(3)               # over the icons: Free Picks' ticks, where they'll land
      @kr_gold = Sprite.new(@viewport)   # Compare: the first one's cursor, in gold (UI/PCCompare.rb)
      @kr_gold.z = 1
      @kr_gold.visible = false
      @overlay_sprite.z = 8              # popups over everything
      checkOpenTransferBox(@storage.currentBox)
      refresh
      pbSEPlay("PC access") if animate
    rescue Exception => e
      raise if Reloaded::Hooks.passthrough?(e)
      fail_over(e)
    end

    def pbCloseBox(animate = true)
      return fb(:pbCloseBox, animate) if @kr_fb
      Reloaded::PC.last_focus = @kr_focus if quick? && Reloaded::PC.respond_to?(:last_focus=)
      begin
        Reloaded::PC.remember_seen(@storage)           # NEW marks clear when the PC closes (his pick)
      rescue StandardError => e
        Reloaded::Log.exception("The Reloaded PC couldn't note what's been seen", e, :pc)
      end
      @kr_picks = nil
      @kr_search = nil
      @kr_compare = nil
      dispose_icons
      dispose_pictures
      dispose_marks
      dispose_gold
      dispose_compare_icons
      dispose_sprites
    end

    # PIF's multi-select puts every Pokémon it held back down and starts the
    # box again: the same screen, redrawn
    def restartBox(screen, command, _animate = true)
      return fb(:restartBox, screen, command, _animate) if @kr_fb
      @screen = screen
      @storage = screen.storage
      @command = command
      dispose_icons
      refresh
    end

    #--------------------------------------------------------------------------
    # Choosing
    #--------------------------------------------------------------------------
    # A box slot [box, index], a party place [-1, index], the box name
    # [-4, -1], or nil (B)
    def pbSelectBox(_party)
      return fb(:pbSelectBox, _party) if @kr_fb
      return guarded(:pbSelectBox, _party) { select_loop(false) }
    end

    # Deposit: a party place's index, or -1 (B)
    def pbSelectParty(_party)
      return fb(:pbSelectParty, _party) if @kr_fb
      return guarded(:pbSelectParty, _party) { select_loop(true) }
    end

    # The game's Quick Swap is how A moves things here; X asks for the
    # Actions by switching to the game's menu mode for one choice
    def pbSetCursorMode(value)
      return fb(:pbSetCursorMode, value) if @kr_fb
      @cursormode = value
      if @screen && @screen.respond_to?(:multiSelectRange) && @screen.multiSelectRange
        @screen.multiSelectRange = nil
        @kr_rect = nil
      end
      refresh
    end

    def pbNextCursorMode
      return fb(:pbNextCursorMode) if @kr_fb
      return if @screen.respond_to?(:pbHolding?) && @screen.pbHolding?
      pbSetCursorMode(@cursormode == "multiselect" ? (quick? ? "quickswap" : "default") : "multiselect")
    end

    def pbSetQuickSwap(value)
      return fb(:pbSetQuickSwap, value) if @kr_fb
      @quickswap = false
      pbSetCursorMode(value ? "quickswap" : "default")
    end

    def setStartingTab(symbol)
      return fb(:setStartingTab, symbol) if @kr_fb
      @command = (symbol == :party ? 1 : 0)
    end

    # PIF's rectangle (Select All): drawn over the box
    def pbUpdateSelectionRect(box, selected)
      return fb(:pbUpdateSelectionRect, box, selected) if @kr_fb
      @kr_rect = @screen.multiSelectRange ? [box, selected] : nil
      refresh
    end

    #--------------------------------------------------------------------------
    # What the game's logic shows as it goes
    #--------------------------------------------------------------------------
    def pbHold(selected)
      return fb(:pbHold, selected) if @kr_fb
      pbSEPlay("GUI storage pick up")
      @kr_held_from = [selected[0], selected[1]]
    end

    def pbPlace(selected, heldpoke)
      return fb(:pbPlace, selected, heldpoke) if @kr_fb
      pbSEPlay("GUI storage put down")
      @kr_held_from = nil
    end

    # The one picked up now came from where the held one goes
    def pbSwap(selected, heldpoke)
      return fb(:pbSwap, selected, heldpoke) if @kr_fb
      pbSEPlay("GUI storage pick up")
      @kr_held_from = [selected[0], selected[1]]
    end

    def pbWithdraw(selected, heldpoke, partyindex)
      return fb(:pbWithdraw, selected, heldpoke, partyindex) if @kr_fb
      pbSEPlay(heldpoke ? "GUI storage put down" : "GUI storage pick up")
      @kr_held_from = nil if heldpoke
    end

    def pbStore(selected, heldpoke, destbox, firstfree)
      return fb(:pbStore, selected, heldpoke, destbox, firstfree) if @kr_fb
      pbSEPlay("GUI storage put down")
      @kr_held_from = nil if heldpoke
    end

    # The Pokémon fades out before the game takes it away
    def pbRelease(selected, heldpoke)
      return fb(:pbRelease, selected, heldpoke) if @kr_fb
      pkmn = heldpoke || @storage[selected[0], selected[1]]
      fade_out([pkmn])
    end

    def pbReleaseInstant(selected, heldpoke)
      return fb(:pbReleaseInstant, selected, heldpoke) if @kr_fb
      @kr_held_from = nil if heldpoke
    end

    def animate_hold_multi(box, selected, _selected_index)
      return fb(:animate_hold_multi, box, selected, _selected_index) if @kr_fb
      pbSEPlay("GUI storage pick up")
    end

    def animate_place_multi(box, index)
      return fb(:animate_place_multi, box, index) if @kr_fb
      pbSEPlay("GUI storage put down")
    end

    def animate_release_multi(box, selected)
      return fb(:animate_release_multi, box, selected) if @kr_fb
      fade_out(Array(selected).map { |i| @storage[box, i] }.compact)
    end

    def pbHoldMulti(*args)
      return animate_hold_multi(*args)
    end

    def pbPlaceMulti(*args)
      return animate_place_multi(*args)
    end

    def pbReleaseMulti(*args)
      return animate_release_multi(*args)
    end

    def pbSetHeldPokemon(_pokemon)
      return fb(:pbSetHeldPokemon, _pokemon) if @kr_fb
      refresh
    end

    def setFusing(fusing, item = 0)
      return fb(:setFusing, fusing, item) if @kr_fb
      @kr_splicer = fusing ? item : nil
      @cursormode = "quickswap" if !fusing && quick? && @cursormode == "default"
      refresh
    end

    def kr_fusions(on)
      @kr_fusions_on = on
      refresh
    end

    def pbChangeBackground(wp)
      return fb(:pbChangeBackground, wp) if @kr_fb
      @storage[@storage.currentBox].background = wp
      refresh
    end

    def pbJumpToBox(newbox)
      return fb(:pbJumpToBox, newbox) if @kr_fb
      show_box(newbox) if @storage.currentBox != newbox
      checkOpenTransferBox(newbox)
    end

    def pbSwitchBoxToLeft(newbox)
      return fb(:pbSwitchBoxToLeft, newbox) if @kr_fb
      show_box(newbox)
    end

    def pbSwitchBoxToRight(newbox)
      return fb(:pbSwitchBoxToRight, newbox) if @kr_fb
      show_box(newbox)
    end

    def pbRefresh(*_a)
      return fb(:pbRefresh, *_a) if @kr_fb
      refresh
    end

    # A Pokémon's look changed (an item, a shiny gamble): its icons again
    def pbHardRefresh
      return fb(:pbHardRefresh) if @kr_fb
      @kr_match = {}
      dispose_icons
      refresh
    end

    def pbUpdateOverlay(_selection, _party = nil)
      return fb(:pbUpdateOverlay, _selection, _party) if @kr_fb
      refresh
    end

    def pbSetMosaic(*_a); end

    def pbSetArrow(*_a); end

    def pbPartySetArrow(*_a); end

    def pbShowPartyTab; end

    def pbHidePartyTab; end

    def update
      return fb(:update) if @kr_fb
      update_frame if @sprite && !@sprite.disposed?
      @kr_gold.opacity = P.cursor_opacity(@frame) if @kr_gold && !@kr_gold.disposed? && @kr_gold.visible
      if @kr_marks && !@kr_marks.disposed?
        @kr_marks.opacity = @kr_ov && drop_held? ? P.cursor_opacity(@frame) : 255
      end
      (@kr_icons || {}).each_value { |s, _k| s.update if s && !s.disposed? }
      @kr_detail[0].update if @kr_detail && !@kr_detail[0].disposed?
      Reloaded::Toast.update if defined?(Reloaded::Toast)
    end

    def sprites
      return fb(:sprites) if @kr_fb
      list = Sprites.new([@sprite, @cursor_sprite, @kr_gold, @top_sprite, @kr_marks, @hint_sprite, @overlay_sprite].compact.reject(&:disposed?) +
                         (@kr_cmp_icons || {}).values.map { |s, _k| s }.reject(&:disposed?) +
                         (@kr_icons || {}).values.map { |s, _k| s }.reject(&:disposed?))
      list.stub = @kr_stub
      return list
    end

    #--------------------------------------------------------------------------
    # Messages and lists, in Kanto Reloaded's popups
    #--------------------------------------------------------------------------
    def pbDisplay(message)
      return fb(:pbDisplay, message) if @kr_fb
      if (m = message.to_s.match(/Not enough Money ! Cost P([\d,]+)/))
        buy_box_dialog(m[1], [_INTL("OK")], _INTL("Not Enough Money"), _INTL("A new box costs more than you have."))
      else
        Reloaded::Dialogs.notice(self, _INTL("PC"), message.to_s)
      end
      refresh
    end

    # The game's lists (its Yes / No questions as Kanto Reloaded's): the
    # index chosen, or -1 on B
    def pbShowCommands(message, commands, index = 0)
      return fb(:pbShowCommands, message, commands, index) if @kr_fb
      labels = commands.map(&:to_s)
      # KIF's Buy Box: Kanto Reloaded's question with the cost in colour
      if labels.length == 2 && message.to_s =~ /\AYou have P[\d,]+\z/ && (b = labels[0].match(/\ABuy! \(P([\d,]+)\)\z/))
        ret = buy_box_dialog(b[1], [_INTL("Buy"), _INTL("Not Now")], _INTL("Buy a Box?"), _INTL("A new box goes after your last one."))
        refresh
        return ret
      end
      # the PC's own lists (Step 2): KIF's Kuray Actions under headings (his
      # pick), a Pokémon's Actions and a box's with Kanto Reloaded's and mods'
      if (pk = kuray_list_pokemon(message, labels))
        ret = rld_menu(labels, pk)
        refresh
        return ret
      elsif organize_list?(labels)
        ret = actions_menu(labels, index)
        refresh
        return ret
      elsif box_list?(message, labels)
        ret = box_menu(labels)
        refresh
        return ret
      elsif wallpaper_list?(message, labels)
        ret = wallpaper_grid(labels, index)
        refresh
        return ret
      elsif picks_list?(message, labels)
        ret = picks_menu(labels)
        refresh
        return ret
      end
      if [labels, labels.reverse].include?([_INTL("Yes"), _INTL("No")]) && labels.length == 2
        yes_first = labels[0] == _INTL("Yes")
        ok = Reloaded::Dialogs.confirm(self, _INTL("PC"), message.to_s, nil, nil, yes_first)
        refresh
        return yes_first ? (ok ? 0 : 1) : (ok ? 1 : 0)
      end
      map = []
      shown = []
      notes = []
      pkmn = focused_pokemon
      labels.each_with_index do |l, i|
        next if HIDDEN_LABELS.include?(l)
        map << i
        shown << Reloaded::PC.rename(l)
        notes << Reloaded::PC.describe(Reloaded::PC.rename(l), pkmn)
      end
      start = map.index(index) || 0
      ret = with_popup_hints(menu_hints) { Reloaded::Dialogs.menu(self, menu_title(message), shown, notes, start) }
      refresh
      return ret.nil? ? -1 : map[ret]
    end

    def pbChooseBox(msg)
      return fb(:pbChooseBox, msg) if @kr_fb
      values = []
      indices = []
      @storage.maxBoxes.times do |i|
        box = @storage[i]
        next unless box
        next if defined?(::StorageTransferBox) && box.is_a?(::StorageTransferBox)
        values << _INTL("{1} ({2}/{3})", box.name, box.nitems, box.length)
        indices << i
      end
      start = indices.index(@storage.currentBox) || 0
      ret = with_popup_hints(menu_hints) { Reloaded::Dialogs.picker(self, menu_title(msg), values, start) }
      refresh
      return ret.nil? ? -1 : indices[ret]
    end

    # Rename (his pick: In the Header, UI/PCTools.rb)
    def pbBoxName(helptext, minchars, maxchars)
      return fb(:pbBoxName, helptext, minchars, maxchars) if @kr_fb
      rename_box(helptext, minchars, maxchars)
      refresh
    end

    # The Bag says what it's choosing for (the Reloaded Bag's banner)
    def pbChooseItem(bag)
      return fb(:pbChooseItem, bag) if @kr_fb
      ret = nil
      pkmn = focused_pokemon
      hidden do
        run = proc do
          scene = ::PokemonBag_Scene.new
          bag_screen = ::PokemonBagScreen.new(scene, bag)
          ret = bag_screen.pbChooseItemScreen(proc { |item| ::GameData::Item.get(item).can_hold? })
        end
        if defined?(Reloaded::BagScreen) && Reloaded::BagScreen.respond_to?(:titled)
          Reloaded::BagScreen.during(:@title, Reloaded::BagScreen.titled("Give an Item to {1}", "Give", pkmn)) { run.call }
        else
          run.call
        end
      end
      refresh
      return ret
    end

    def pbSummary(selected, heldpoke)
      return fb(:pbSummary, selected, heldpoke) if @kr_fb
      hidden do
        scene = ::PokemonSummary_Scene.new
        summary = ::PokemonSummaryScreen.new(scene)
        if heldpoke
          summary.pbStartScreen([heldpoke], 0)
        elsif selected[0] == -1
          i = summary.pbStartScreen(@storage.party, selected[1])
          @kr_focus = [:party, i.to_i] if i.is_a?(Integer)
        else
          i = summary.pbStartScreen(@storage.boxes[selected[0]], selected[1])
          @kr_focus = [:box, i.to_i] if i.is_a?(Integer)
        end
      end
      dispose_icons
      refresh
    end

    # Mark (his pick: Shape Row): the six shapes in a row, lit when on;
    # Left / Right choose, A marks or unmarks, B is done
    def pbMark(selected, heldpoke)
      return fb(:pbMark, selected, heldpoke) if @kr_fb
      pk = heldpoke || @storage[selected[0], selected[1]]
      return unless pk
      bits = pk.markings.to_i
      k = 0
      with_popup_hints([[:lr, _INTL("Choose")], [button(:C), _INTL("Mark")], [button(:B), _INTL("Done")]]) do
        redraw = true
        loop do
          draw_mark(pk, bits, k) if redraw
          redraw = false
          Graphics.update
          Input.update
          update
          pt = Reloaded::Pointer
          if pt.moved? && (i = pt.hit(@kr_mark_hits || [])) && i != k
            k = i
            pbPlayCursorSE
            redraw = true
          end
          if pt.left? && (i = pt.hit(@kr_mark_hits || []))
            k = i
            bits ^= (1 << k)
            pbPlayDecisionSE
            redraw = true
          elsif pt.right? || Input.trigger?(Input::BACK)
            pbPlayCancelSE
            break
          elsif Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)
            k = (k + (Input.repeat?(Input::LEFT) ? -1 : 1)) % SHAPES.length
            pbPlayCursorSE
            redraw = true
          elsif Input.trigger?(Input::USE)
            bits ^= (1 << k)
            pbPlayDecisionSE
            redraw = true
          end
        end
      end
      pk.markings = bits
    ensure
      overlay.clear if @overlay_sprite && !@overlay_sprite.disposed?
      refresh
    end

    def drawMarkings(*_a); end

    #--------------------------------------------------------------------------
    # Readers the game's code asks
    #--------------------------------------------------------------------------
    def cursormode
      return fb(:cursormode) if @kr_fb
      return @cursormode
    end

    def quickswap
      return fb(:quickswap) if @kr_fb
      return false
    end

    def inTransferBox
      return fb(:inTransferBox) if @kr_fb
      return @inTransferBox
    end

    def choseFromParty
      return fb(:choseFromParty) if @kr_fb
      return @choseFromParty
    end

    def choseFromParty=(value)
      return fb(:choseFromParty=, value) if @kr_fb
      @choseFromParty = value
    end

    def selection
      return fb(:selection) if @kr_fb
      return @selection
    end

    # PIF's Select All puts the cursor on the box's last slot
    def selection=(value)
      return fb(:selection=, value) if @kr_fb
      @selection = value
      @kr_focus = [:box, value] if value.is_a?(Integer) && value >= 0
    end

    def screen
      return fb(:screen) if @kr_fb
      return @screen
    end

    #--------------------------------------------------------------------------
    # Popups' hints (Dialogs draw on this screen)
    #--------------------------------------------------------------------------
    def with_popup_hints(pairs)
      before = @popup_hints
      @popup_hints = pairs
      refresh
      return yield
    ensure
      @popup_hints = before
    end

    def refresh
      draw if @sprite && !@sprite.disposed?
    end

    private

    # Buy Box's cost and your Money: green when you have enough, red when
    # you don't (his rule, 2026-10-24: everywhere money shows)
    def buy_box_dialog(cost_words, buttons, title, text)
      c = palette
      cost = cost_words.delete(",").to_i
      money = $Trainer ? $Trainer.money.to_i : 0
      have = money.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
      tone = money >= cost ? c[:green] : c[:red]
      segs = [[_INTL("Cost: "), c[:dim]], ["$#{cost_words}", tone, true],
              [_INTL(" (Money: "), c[:dim]], ["$#{have}", tone, true], [")", c[:dim], true]]
      return Reloaded::Dialogs.ask(self, title, text, segs, buttons, 0)
    end

    #--------------------------------------------------------------------------
    # The PC's lists (Step 2)
    #--------------------------------------------------------------------------
    # KIF's Kuray Actions list for the held one or the one under the cursor
    def kuray_list_pokemon(message, labels)
      return nil unless defined?(::KIF::PCActions) && labels.last == _INTL("Cancel")
      [held, under_cursor].compact.each do |pk|
        next unless message.to_s == _INTL("{1} is selected.", pk.name)
        return pk if labels[0...-1] == ::KIF::PCActions.available(pk).map { |_a, l| l.to_s }
      end
      return nil
    end

    # PIF's organizeActions list: Move / Place / Shift first, Summary,
    # Release, Cancel last
    def organize_list?(labels)
      return labels.last == _INTL("Cancel") && labels.include?(_INTL("Summary")) && labels.include?(_INTL("Release")) &&
             [_INTL("Move"), _INTL("Place"), _INTL("Shift")].include?(labels[0])
    end

    def box_list?(message, labels)
      return message.to_s == _INTL("What do you want to do?") && labels.last == _INTL("Cancel") && labels.include?(_INTL("Jump"))
    end

    # Where the cursor is, as the game's code names a place
    def kr_selected
      kind, i = @kr_focus
      return kind == :party ? [-1, i] : [@storage.currentBox, i]
    end

    # A Pokémon's Actions: the game's list (KIF's RLD Actions in it), with
    # Kanto Reloaded's and mods' (Mark) before Release
    def actions_menu(labels, index)
      pk = held || under_cursor
      cancel = labels.length - 1
      mine = pk ? Reloaded::PC.actions(:pokemon, pk) : []
      own = mine.reject { |a, *| a.group }
      grouped = mine.select { |a, *| a.group }
      rows = []
      labels.each_with_index do |l, i|
        next if i == cancel || HIDDEN_LABELS.include?(l)
        next if l == _INTL("Kuray Actions") && !rld_any?(pk, grouped)
        if l == _INTL("Release")
          own.each { |a, label, on, why| rows << [label, on ? _INTL(a.description) : why, on, [:kr, a]] }
        end
        name = Reloaded::PC.rename(l)
        rows << [name, Reloaded::PC.describe(name, pk), true, i]
        if l == _INTL("Release") && !labels.include?(_INTL("Kuray Actions")) && !grouped.empty?
          rows << [_INTL("RLD Actions"), Reloaded::PC.describe(_INTL("RLD Actions"), pk), true, [:rld]]
        end
      end
      rows << [_INTL("Cancel"), Reloaded::PC.describe(_INTL("Cancel")), true, cancel]
      start = rows.index { |r| r[3] == index } || 0
      ret = pc_menu(menu_title(_INTL("{1} is selected.", pk ? pk.name : "")), rows, start)
      return -1 if ret.nil?
      return ret unless ret.is_a?(Array)
      ret == [:rld] ? rld_menu(nil, pk) : ret[1].handler.call(@screen, pk, kr_selected, held)
      return cancel
    end

    def rld_any?(pk, grouped)
      return true unless grouped.empty?
      return false unless pk && defined?(::KIF::PCActions)
      return ::KIF::PCActions.available(pk).any? { |_a, l| !HIDDEN_LABELS.include?(l.to_s) }
    end

    # RLD Actions (his pick: Headings in the List): KIF's actions and mods'
    # under Export, Evolution, Shiny (then others); labels nil: only mods'
    def rld_menu(labels, pk)
      groups = {}
      if labels && defined?(::KIF::PCActions)
        ::KIF::PCActions.available(pk).each_with_index do |(a, l), i|
          next if HIDDEN_LABELS.include?(l.to_s)
          name = Reloaded::PC.rename(l)
          (groups[Reloaded::PC.kif_group(a.id)] ||= []) << [name, Reloaded::PC.describe(name, pk), true, i]
        end
      end
      Reloaded::PC.actions(:pokemon, pk).each do |a, label, on, why|
        next unless a.group
        (groups[a.group] ||= []) << [label, on ? _INTL(a.description) : why, on, [:kr, a]]
      end
      cancel = labels ? labels.length - 1 : -1
      rows = []
      (Reloaded::PC::GROUP_ORDER + (groups.keys - Reloaded::PC::GROUP_ORDER)).each do |g|
        next unless groups[g]
        rows << [:head, _INTL(g)]
        rows.concat(groups[g])
      end
      rows << [_INTL("Cancel"), Reloaded::PC.describe(_INTL("Cancel")), true, cancel]
      ret = pc_menu(PF.fit(PF::TEXT, pk.name.to_s, 280), rows, rows.index { |r| r[0] != :head } || 0)
      return -1 if ret.nil?
      return ret unless ret.is_a?(Array)
      ret[1].handler.call(@screen, pk, kr_selected, held)
      return cancel
    end

    # A box's actions: the game's and KIF's, then Kanto Reloaded's and mods'.
    # KIF's Sort and Sort (All Boxes) are one Sort (his pick: One Popup).
    def box_menu(labels)
      cancel = labels.length - 1
      rows = []
      labels.each_with_index do |l, i|
        next if i == cancel || l == _INTL("Sort (all Boxes)")
        name = Reloaded::PC.rename(l)
        ret = if l == _INTL("Sort") then [:sort]
              elsif l == _INTL("Select all") then [:pick_all]     # picks every one (his pick: Free Picks)
              else i
              end
        rows << [name, Reloaded::PC.describe(name), true, ret]
      end
      Reloaded::PC.actions(:box, @screen).each { |a, label, on, why| rows << [label, on ? _INTL(a.description) : why, on, [:kr, a]] }
      rows << [_INTL("Cancel"), Reloaded::PC.describe(_INTL("Cancel")), true, cancel]
      ret = pc_menu(PF.fit(PF::TEXT, box.name.to_s, 280), rows, 0)
      return -1 if ret.nil?
      return ret unless ret.is_a?(Array)
      case ret[0]
      when :sort then sort_popup
      when :pick_all then pick_all
      else ret[1].handler.call(@screen)
      end
      return cancel
    end

    # PIF's list for several (Selected 4 Pokémon.): Pick Up All and Sort are
    # Kanto Reloaded's, the rest (Release, KIF's Battle Selected and Export)
    # PIF's and KIF's, on the picks
    def picks_list?(message, labels)
      n = kr_picks_for(@storage.currentBox)
      return n && labels.last == _INTL("Cancel") && labels.include?(_INTL("Move")) &&
             message.to_s == _INTL("Selected {1} Pokémon.", n.length)
    end

    def picks_menu(labels)
      cancel = labels.length - 1
      notes = { _INTL("Release") => _INTL("Let them go. They won't come back."), _INTL("Battle Selected") => _INTL("Battle with the picked ones."),
                _INTL("Export") => _INTL("Save the picked ones to files.") }
      rows = []
      labels.each_with_index do |l, i|
        next if i == cancel
        rows << if l == _INTL("Move") then [_INTL("Pick Up All"), _INTL("Pick them all up."), true, [:pick_up]]
                elsif l == _INTL("Sort") then [_INTL("Sort"), _INTL("Sort the picked ones in their own places."), true, [:sort]]
                else
                  name = Reloaded::PC.rename(l)
                  [name, notes[l] || Reloaded::PC.describe(name), true, i]
                end
      end
      rows << [_INTL("Cancel"), Reloaded::PC.describe(_INTL("Cancel")), true, cancel]
      ret = pc_menu(_INTL("{1} Picked", picks_here.length), rows, 0)
      return -1 if ret.nil?
      return ret unless ret.is_a?(Array)
      ret == [:sort] ? sort_popup(:picked) : pick_up_all
      return cancel
    end

    # Kanto Reloaded's menu (Dialogs.menu's look) with headings and dimmed
    # rows: rows [:head, text] or [label, note, on, ret]; start a row's
    # index. The chosen row's ret, or nil on B. A dimmed row buzzes; its note
    # says why.
    def pc_menu(title, rows, start = 0)
      picks = rows.each_index.reject { |i| rows[i][0] == :head }
      return nil if picks.empty?
      k = picks.index(start) || 0
      top = 0
      ret = nil
      with_popup_hints(menu_hints) do
        redraw = true
        loop do
          top = draw_pc_menu(title, rows, picks[k], top) if redraw
          redraw = false
          Graphics.update
          Input.update
          update
          pt = Reloaded::Pointer
          hit = pt.hit(@kr_menu_hits || [])
          if pt.moved? && hit && hit != picks[k]
            k = picks.index(hit)
            pbPlayCursorSE
            redraw = true
          end
          choose = nil
          if pt.left? && hit
            k = picks.index(hit)
            choose = rows[picks[k]]
          elsif pt.right? || Input.trigger?(Input::BACK)
            pbPlayCancelSE
            break
          elsif (w = pt.wheel) != 0
            k = (k + w).clamp(0, picks.length - 1)     # the wheel: -1 is up
            redraw = true
          elsif Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN)
            to = k + (Input.repeat?(Input::UP) ? -1 : 1)
            if to < 0 || to >= picks.length
              next unless Input.trigger?(Input::UP) || Input.trigger?(Input::DOWN)
              to %= picks.length
            end
            k = to
            pbPlayCursorSE
            redraw = true
          elsif Input.trigger?(Input::USE)
            choose = rows[picks[k]]
          end
          next unless choose
          unless choose[2]
            pbPlayBuzzerSE
            redraw = true
            next
          end
          pbPlayDecisionSE
          ret = choose[3]
          break
        end
      end
      return ret
    ensure
      overlay.clear if @overlay_sprite && !@overlay_sprite.disposed?
    end

    # Returns the list's scroll (pixels) after keeping the chosen row in view
    def draw_pc_menu(title, rows, sel, top)
      b = overlay
      c = palette
      dg = Reloaded::Dialogs
      dg.send(:dim, b)
      heights = rows.map { |r| r[0] == :head ? MENU_HEAD : MENU_ROW }
      ys = []
      total = 0
      heights.each { |h| ys << total; total += h }
      room = [total, MENU_ROOM].min
      first = sel > 0 && rows[sel - 1][0] == :head ? sel - 1 : sel      # its heading too
      top = ys[first] if ys[first] < top
      top = ys[sel] + heights[sel] - room if ys[sel] + heights[sel] > top + room
      w = MENU_W
      notes = rows.reject { |r| r[0] == :head }.map { |r| r[1].to_s }
      lines = notes.map { |d| P.wrap(d, w - 28).length }.max.to_i.clamp(0, 3)
      desc_h = lines > 0 ? lines * 18 + 8 : 0
      h = 40 + room + 8 + desc_h
      x = (W - w) / 2
      y = (H - h) / 2
      dg.send(:panel, b, c, x, y, w, h)
      dg.send(:title_bar, b, c, x, y, w, title)
      @kr_menu_hits = []
      rows.each_with_index do |r, i|
        next if ys[i] < top || ys[i] + heights[i] > top + room
        ry = y + 40 + ys[i] - top
        if r[0] == :head
          P.heading(b, x + 14, x + w - 14, ry + 2, r[1], c[:head] || c[:dim], c[:line])
          next
        end
        @kr_menu_hits << [i, x + 6, ry, x + w - 6, ry + MENU_ROW - 2]
        dg.send(:cursor_row, b, c, x + 6, ry, x + w - 6, ry + MENU_ROW - 2) if i == sel
        P.text(b, x + 18, ry, w - 36, MENU_ROW - 2, r[0].to_s, r[2] ? c[:opt] : c[:dim])
      end
      P.ui.tri(b, x + w / 2 - 4, y + 37, :u, c[:dim], 3) if top > 0
      P.ui.tri(b, x + w / 2 - 4, y + 40 + room, :d, c[:dim], 3) if top + room < total
      if lines > 0
        b.fill_rect(x + 10, y + h - desc_h - 4, w - 20, 1, c[:line])
        P.wrap(rows[sel][1].to_s, w - 28).first(lines).each_with_index do |line, i|
          P.text(b, x + 14, y + h - desc_h + i * 18, w - 28, 18, line, rows[sel][2] ? c[:dim] : c[:red])
        end
      end
      return top
    end

    #--------------------------------------------------------------------------
    # Marks
    #--------------------------------------------------------------------------
    # A shape's pixels at a size, as runs [y, x, length] (cached)
    def mark_runs(k, size)
      @kr_mark_runs ||= {}
      return @kr_mark_runs[[k, size]] if @kr_mark_runs.key?([k, size])
      sheet = picture(MARK_SHEET)
      runs = []
      if sheet
        size.times do |ty|
          start = nil
          (size + 1).times do |tx|
            on = tx < size && sheet.get_pixel(k * 16 + tx * 16 / size, 16 + ty * 16 / size).alpha > 0
            if on && start.nil?
              start = tx
            elsif !on && start
              runs << [ty, start, tx - start]
              start = nil
            end
          end
        end
      end
      return @kr_mark_runs[[k, size]] = runs
    end

    def mark(b, k, x, y, size, col)
      mark_runs(k, size).each { |ty, tx, len| b.fill_rect(x + tx, y + ty, len, 1, col) }
    end

    # The marks that are on, small, in the plate's top right corner (his ask:
    # only those, right in the corner)
    def plate_marks(top, c, pk)
      bits = (pk.markings rescue 0).to_i
      on = (0...SHAPES.length).select { |k| bits & (1 << k) != 0 }
      x = PLATE[2] - 8 - on.length * 12
      on.each_with_index { |k, j| mark(top, k, x + j * 12 + 2, PLATE[1] + 6, 10, c[:selb]) }
    end

    def draw_mark(pk, bits, k)
      b = overlay
      c = palette
      dg = Reloaded::Dialogs
      dg.send(:dim, b)
      w = 300
      h = 40 + 56 + 30 + 26
      x = (W - w) / 2
      y = (H - h) / 2
      dg.send(:panel, b, c, x, y, w, h)
      dg.send(:title_bar, b, c, x, y, w, _INTL("Mark {1}", pk.name))
      step = 44
      x0 = x + (w - step * SHAPES.length) / 2
      @kr_mark_hits = []
      SHAPES.each_index do |i|
        sx = x0 + i * step + 6
        sy = y + 50
        @kr_mark_hits << [i, sx - 6, sy - 6, sx + 37, sy + 37]
        dg.send(:cursor_row, b, c, sx - 6, sy - 6, sx + 37, sy + 37) if i == k
        on = bits & (1 << i) != 0
        mark(b, i, sx, sy, 32, on ? c[:selb] : mix(c[:line], c[:panel2], 0.45))
      end
      state = bits & (1 << k) != 0 ? _INTL("On") : _INTL("Off")
      P.text(b, x, y + 96, w, 18, _INTL("{1}: {2}", _INTL(SHAPES[k]), state), c[:txt], PF::TEXT, 2)
      b.fill_rect(x + 10, y + h - 30, w - 20, 1, c[:line])
      P.text(b, x + 14, y + h - 26, w - 28, 18, _INTL("Also shown in the Summary."), c[:dim])
    end

    #--------------------------------------------------------------------------
    # The fallback: the game's own scene for the rest of the visit
    #--------------------------------------------------------------------------
    def fb(name, *args)
      return @kr_fb.send(name, *args)
    end

    def guarded(name, *args)
      return yield
    rescue Exception => e
      raise if Reloaded::Hooks.passthrough?(e)
      fail_over(e)
      return fb(name, *args)
    end

    # A held Pokémon goes back first (where it came from, else the first free
    # place), so a failure never loses one
    def fail_over(e)
      Reloaded::Log.exception("The Reloaded PC failed; the game's own PC for the rest of this visit", e, :pc)
      Reloaded::PC.failed = true
      begin
        put_held_away
      rescue StandardError => e2
        Reloaded::Log.exception("The Reloaded PC couldn't put a held Pokémon away", e2, :pc)
      end
      begin
        dispose_icons
        dispose_pictures
        dispose_marks
        dispose_gold
        dispose_compare_icons
        dispose_sprites if @viewport
      rescue StandardError
        nil
      end
      @kr_fb = Reloaded::PC.game_scene
      @kr_fb.pbStartBox(@screen, @command, false)
      @kr_fb.choseFromParty = @choseFromParty
    end

    def put_held_away
      return unless @screen
      held = @screen.respond_to?(:pbHeldPokemon) ? @screen.pbHeldPokemon : nil
      if held
        box, idx = @kr_held_from
        if box && box >= 0 && @storage[box, idx].nil?
          @storage[box, idx] = held
        elsif box == -1 && @storage.party.length < 6
          @storage.party.push(held)
        else
          @storage.pbStoreCaught(held)
        end
        @screen.heldpkmn = nil
      end
      multi = @screen.respond_to?(:multiheldpkmn) ? @screen.multiheldpkmn : nil
      if multi && !multi.empty?
        multi.each { |pk, _x, _y| @storage.pbStoreCaught(pk) }
        @screen.multiheldpkmn = []
      end
      if @screen.respond_to?(:fusionMode) && @screen.fusionMode
        @screen.fusionMode = false
      end
    end

    #--------------------------------------------------------------------------
    # Where things are
    #--------------------------------------------------------------------------
    # Organise with PIF's own screen: one press to move
    def quick?
      return @command == 0 && @screen.instance_of?(::PokemonStorageScreen)
    end

    def start_focus
      return [:party, 0] if @command == 2
      last = Reloaded::PC.respond_to?(:last_focus) ? Reloaded::PC.last_focus : nil
      return last if quick? && last.is_a?(Array) && last[0] == :box
      return [:box, 0]
    end

    def box
      return @storage[@storage.currentBox]
    end

    def held
      return nil unless @screen && @screen.respond_to?(:pbHeldPokemon)
      return @screen.pbHeldPokemon
    end

    def multi_held
      return [] unless @screen && @screen.respond_to?(:multiheldpkmn)
      return @screen.multiheldpkmn || []
    end

    def fusing?
      return @screen && @screen.respond_to?(:fusionMode) && @screen.fusionMode ? true : false
    end

    def under_cursor
      kind, i = @kr_focus
      return box[i] if kind == :box
      return @storage.party[i] if kind == :party
      return nil
    end

    # What the plate shows: the one held over a free place, else what's
    # under the cursor
    def focused_pokemon
      pk = under_cursor
      return pk if pk
      return multi_held[0][0] unless multi_held.empty?
      return held if held && !fusing?
      return held if fusing? && @kr_focus[0] != :name
      return nil
    end

    def slot_rect(i)
      return [BOX_X + (i % COLS) * CELL_W, BOX_Y + (i / COLS) * CELL_H, CELL_W, CELL_H]
    end

    def party_centre(i)
      return [6 + 12 + i * PARTY_STEP + PARTY_STEP / 2, PARTY_Y + 38]
    end

    # The header's middle: the box name, a red padlock and SORT / EXPORT
    # when it's locked, and a search's pill, centred together
    def name_group
      name = PF.fit(PF::ROW, box.name.to_s, 230)
      tw = P.width(PF::ROW, name)
      lock = lock_words
      lock_w = lock.empty? ? 0 : 12 + P.width(PF::TINY, lock) + 8
      pill = search_on? ? search_pill_words : nil
      pill_w = pill ? 8 + P.width(PF::TINY, pill) + 12 : 0
      width = tw + lock_w + pill_w
      return { :name => name, :tw => tw, :lock => lock, :lock_w => lock_w, :pill => pill, :width => width,
               :x0 => (W - width) / 2 }
    end

    # The name and its lock (the box name's cursor and click)
    def name_rect
      g = name_group
      return [g[:x0] - 10, 3, g[:tw] + g[:lock_w] + 20, 25]
    end

    def lock_words
      b = box
      words = []
      words << _INTL("SORT") if b.respond_to?(:sortlock?) && b.sortlock?
      words << _INTL("EXPORT") if b.respond_to?(:exportlock?) && b.exportlock?
      return words.join(" ")
    end

    def choosing?
      return @command == 3 || (@choseFromParty && !quick? && @command != 2)
    end

    #--------------------------------------------------------------------------
    # The loop
    #--------------------------------------------------------------------------
    def select_loop(party_only)
      if quick? && @cursormode == "default" && !fusing?
        @cursormode = "quickswap"            # back from one Actions list
      end
      multi_open = @screen.respond_to?(:multiSelectRange) && @screen.multiSelectRange
      if quick? && @cursormode == "multiselect" && !multi_open && multi_held.empty?
        @cursormode = "quickswap"            # PIF's Select All is done with
        @kr_rect = nil
      end
      @kr_party_only = party_only
      if party_only && @kr_focus[0] != :party
        @kr_focus = [:party, 0]
      elsif @choseFromParty && !@kr_chose_seen
        @kr_chose_seen = true
        @kr_focus = [:party, 0] if @storage.party.length > 0
      end
      refresh
      loop do
        Graphics.update
        Input.update
        update
        result = handle_input
        next if result == :stay
        @kr_party_only = false
        return result
      end
    end

    def handle_input
      handled, result = mouse_input
      return result if handled
      if (dir = repeat_dir)
        move(dir)
        return :stay
      end
      unless @kr_party_only
        if Input.trigger?(Input::JUMPUP)
          change_box(-1)
          return :stay
        elsif Input.trigger?(Input::JUMPDOWN)
          change_box(1)
          return :stay
        end
      end
      if comparing?
        return compare_choose if Input.trigger?(Input::USE)
        return compare_cancel if Input.trigger?(Input::BACK)
        return :stay
      end
      return choose if Input.trigger?(Input::USE)
      return actions if Input.trigger?(Input::ACTION)
      return toggle_pick if Input.trigger?(Input::X) && !@kr_party_only        # Y (UI/PCPicks.rb)
      return open_search if Input.trigger?(Input::SPECIAL) && !@kr_party_only  # RS (UI/PCSearch.rb)
      return back if Input.trigger?(Input::BACK)
      return :stay
    end

    def repeat_dir
      return :up if Input.repeat?(Input::UP)
      return :down if Input.repeat?(Input::DOWN)
      return :left if Input.repeat?(Input::LEFT)
      return :right if Input.repeat?(Input::RIGHT)
      return nil
    end

    def move(dir)
      kind, i = @kr_focus
      to = @kr_focus
      if @kr_party_only
        n = [@storage.party.length, 1].max
        to = [:party, (i + (dir == :left ? -1 : 1)) % n] if dir == :left || dir == :right
      else
        case kind
        when :box
          r = i / COLS
          c = i % COLS
          to = case dir
               when :up then r > 0 ? [:box, i - COLS] : [:name]
               when :down then r < ROWS - 1 ? [:box, i + COLS] : [:party, c]
               when :left then [:box, r * COLS + (c - 1) % COLS]
               else [:box, r * COLS + (c + 1) % COLS]
               end
          @kr_name_col = c
        when :party
          to = case dir
               when :up then [:box, (ROWS - 1) * COLS + i]
               when :down then [:name]
               when :left then [:party, (i - 1) % 6]
               else [:party, (i + 1) % 6]
               end
          @kr_party_col = i
        else
          case dir
          when :left then return change_box(-1)
          when :right then return change_box(1)
          when :down then to = [:box, @kr_name_col]
          else to = [:party, @kr_party_col]
          end
        end
      end
      return if to == @kr_focus
      @kr_focus = to
      @selection = to[1] || -1
      pbPlayCursorSE
      refresh
    end

    # LB / RB; while a search is on, to the nearest box with a match
    def change_box(dir)
      n = @storage.maxBoxes
      pbPlayCursorSE
      to = search_on? ? match_boxes[dir < 0 ? 0 : 1] : nil
      show_box(to || (@storage.currentBox + dir) % n)
      checkOpenTransferBox(@storage.currentBox)
      refresh
    end

    def show_box(newbox)
      @storage.currentBox = newbox
      @kr_rect = nil
      refresh
    end

    # A: what the game's loop does with the place chosen; on the box name,
    # the Box Overview (UI/PCTools.rb)
    def choose
      kind, i = @kr_focus
      return compare_choose if comparing?
      return i if @kr_party_only
      return place_all if quick? && !multi_held.empty? && kind != :name
      return pick_up_all if quick? && kind == :box && picks?
      if kind == :box
        return :stay if quick? && !box[i] && !held && multi_held.empty? && @cursormode != "multiselect"
        return [@storage.currentBox, i]
      elsif kind == :party
        return :stay if quick? && !@storage.party[i] && !held && multi_held.empty? && @cursormode != "multiselect"
        return [-1, i]
      end
      return box_overview
    end

    # X: the Actions (the game's list) for what's under the cursor or held;
    # on the box name, the box's
    def actions
      kind, i = @kr_focus
      return [-4, -1] if kind == :name
      if quick? && (picks? || !multi_held.empty?)
        return picks_actions if picks? && multi_held.empty? && kind == :box
        pbPlayBuzzerSE
        return :stay
      end
      return choose unless quick? && @cursormode == "quickswap"
      return :stay unless under_cursor || held
      @cursormode = "default"
      return kind == :party ? [-1, i] : [@storage.currentBox, i]
    end

    # B: a held Pokémon goes back where it came from (several too), picks and
    # then a search are cleared; else the game's B
    def back
      return compare_cancel if comparing?
      return put_picks_back if quick? && !multi_held.empty?
      return clear_picks if quick? && picks? && !held
      return clear_search if search_on? && !held
      if quick? && held && !fusing?
        spot = put_back_spot
        unless spot
          pbPlayBuzzerSE
          return :stay
        end
        pbPlayCancelSE
        return spot
      end
      return -1 if @kr_party_only
      return nil
    end

    # Where B puts the held one: its own place if it's free (its box shown),
    # else the first free place in this box
    def put_back_spot
      from_box, idx = @kr_held_from
      if from_box && from_box >= 0 && @storage[from_box, idx].nil?
        show_box(from_box) if from_box != @storage.currentBox
        @kr_focus = [:box, idx]
        return [from_box, idx]
      end
      if from_box == -1 && @storage.party.length < 6
        @kr_focus = [:party, @storage.party.length]
        return [-1, @storage.party.length]
      end
      free = (0...PokemonBox::BOX_SIZE).find { |k| box[k].nil? }
      return nil unless free
      @kr_focus = [:box, free]
      return [@storage.currentBox, free]
    end

    # The mouse: pointing picks, a click does A, a right click B, the wheel
    # over the box changes box. Drag and drop (his pick: Follows the Mouse
    # Exactly): a press on a Pokémon picks it up as a click does; moved with
    # the button held, it floats under the pointer, and letting go puts it
    # down on the place there (off the places: back where it came from). A
    # click without moving still just picks up.
    def mouse_input
      pt = Reloaded::Pointer
      moved = pt.moved?
      if moved && !@kr_party_only
        hit = pt.hit(@kr_hits || [])
        hit = nil if hit == [:prev] || hit == [:next]
        if hit && hit != @kr_focus
          @kr_focus = hit
          pbPlayCursorSE
          refresh
        elsif dragging?
          refresh                                       # it follows the pointer
        end
      end
      if @kr_drag
        handled, result = drag_input(pt)
        return [true, result] if handled
      end
      return [true, back] if pt.right?
      w = pt.wheel
      if w != 0 && !@kr_party_only && pt.inside?(BOX_X, BOX_Y, BOX_X + CELL_W * COLS, BOX_Y + CELL_H * ROWS)
        change_box(w > 0 ? -1 : 1)
        return [true, :stay]
      end
      return [false, nil] unless pt.left?
      handled, result = hint_click
      return [true, result.nil? ? :stay : result] if handled
      hit = pt.hit(@kr_hits || [])
      return [true, :stay] unless hit
      if hit == [:prev] || hit == [:next]
        change_box(hit == [:prev] ? -1 : 1)
        return [true, :stay]
      end
      @kr_focus = hit
      start = drag_start?(hit)
      result = choose
      @kr_drag = { :from => pt.pos, :moved => false } if start
      return [true, result]
    end

    # A press can start a drag: organising, nothing held, a Pokémon there
    def drag_start?(hit)
      return false unless quick? && !fusing? && !comparing? && !held && multi_held.empty?
      kind, i = hit
      return kind == :box ? !box[i].nil? : (kind == :party && !@storage.party[i].nil?)
    end

    def dragging?
      return @kr_drag && @kr_drag[:moved] && (held || !multi_held.empty?) ? true : false
    end

    # While the button's held: moved far enough, it's a drag. Let go: put
    # down where the pointer is (a click, not moved, keeps holding).
    def drag_input(pt)
      if pt.held?
        p = pt.pos
        f = @kr_drag[:from]
        if !@kr_drag[:moved] && p && f && (p[0] - f[0]).abs + (p[1] - f[1]).abs > 4
          @kr_drag[:moved] = true
          refresh
        end
        return [true, :stay]
      end
      was = dragging?
      @kr_drag = nil
      return [false, nil] unless was
      hit = pt.hit(@kr_hits || [])
      if hit.is_a?(Array) && [:box, :party].include?(hit[0])
        @kr_focus = hit
        return [true, choose]
      end
      return [true, back]
    end

    def fresh?(pk)
      return @kr_fresh && @kr_fresh[pk.personalID] ? true : false
    rescue StandardError
      return false
    end

    #--------------------------------------------------------------------------
    # Hints
    #--------------------------------------------------------------------------
    def hint_pairs
      return @popup_hints if @popup_hints
      b = button(:B)
      kind, = @kr_focus
      if @kr_party_only
        return [[:lr, _INTL("Choose")], [button(:C), _INTL("Actions")], [b, _INTL("Close")]]
      end
      if fusing?
        return [[:ud, _INTL("Choose")], [button(:C), _INTL("Fuse")], [button(:L), _INTL("Box")], [b, _INTL("Stop Fusing")]]
      end
      return overview_hints if @kr_ov
      return compare_hints if @kr_cmp
      if comparing?
        return [[:ud, _INTL("Choose")], [button(:C), _INTL("Compare")], [button(:L), _INTL("Box")], [b, _INTL("Cancel")]]
      end
      # while a search is on: LB / RB to the next box with a match, B clears it
      box_hint = [button(:L), search_on? && match_boxes.any? ? _INTL("Next Match") : _INTL("Box")]
      search_hint = [button(:Z), _INTL("Search"), :open_search]
      close_hint = [b, search_on? ? _INTL("Clear Search") : _INTL("Close")]
      if kind == :name
        return [[:lr, box_hint[1]], [button(:C), _INTL("Box Overview")], [button(:A), _INTL("Box Actions")],
                [:d, _INTL("Back to the Box")], close_hint]
      end
      unless quick?
        verb = choosing? ? _INTL("Choose") : _INTL("Actions")
        return [[:ud, _INTL("Choose")], [button(:C), verb], box_hint, search_hint, close_hint]
      end
      if held
        act = under_cursor ? _INTL("Swap") : _INTL("Place")
        return [[:ud, _INTL("Choose")], [button(:C), act], [button(:A), _INTL("Actions")], [button(:L), _INTL("Box")],
                [b, _INTL("Put Back")]]
      end
      unless multi_held.empty?
        return [[:ud, _INTL("Choose")], [button(:C), _INTL("Place All")], [button(:L), _INTL("Box")], [b, _INTL("Put Back")]]
      end
      if picks?
        pick = kind == :box && picks_here.include?(@kr_focus[1]) ? _INTL("Unpick") : _INTL("Pick")
        return [[:ud, _INTL("Choose")], [button(:X), pick], [button(:C), _INTL("Pick Up All")], [button(:A), _INTL("Actions")],
                [b, _INTL("Clear")]]
      end
      if @cursormode == "multiselect"
        return [[:ud, _INTL("Choose")], [button(:C), _INTL("Select")], [button(:L), _INTL("Box")], [b, _INTL("Close")]]
      end
      if under_cursor
        list = [[:ud, _INTL("Choose")], [button(:C), _INTL("Pick Up")], [button(:A), _INTL("Actions")]]
        list << [button(:X), _INTL("Pick")] if kind == :box && can_pick?
        return list + [box_hint, search_hint, close_hint]
      end
      return [[:ud, _INTL("Choose")], box_hint, search_hint, close_hint]
    end

    def menu_hints
      return [[:ud, _INTL("Choose")], [button(:C), _INTL("Pick")], [button(:B), _INTL("Back")]]
    end

    # "Lapras is selected." titles its menu Lapras; others in Title Case
    def menu_title(message)
      text = message.to_s.strip
      if (m = text.match(/\A(.+) is selected\.\z/))
        return PF.fit(PF::TEXT, m[1], 280)
      end
      return PF.fit(PF::TEXT, box.name.to_s, 280) if text == _INTL("What do you want to do?")
      words = defined?(Reloaded::PartyScreen) ? Reloaded::PartyScreen.title_case(text.sub(/[.?!]\z/, "")) : text
      return PF.fit(PF::TEXT, words, 280)
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
      @kr_hits = []
      @kr_used = {}
      marks.clear if @kr_marks && !@kr_marks.disposed?
      hide_icons
      if @kr_ov || @kr_cmp
        @kr_detail[0].visible = false if @kr_detail && !@kr_detail[0].disposed?
        place_gold(nil)
        @kr_cmp ? draw_compare(base, top, c) : draw_overview(base, top, c)
        paint_hints(base, c)
        place_cursor
        return
      end
      header(base, top, c)
      box_grid(base, top, c)
      draw_picks(top, c)
      plate(base, top, c)
      search_editing? ? filters_row(base, top, c) : party_row(base, top, c)
      held_over(base, top, c)
      drop_unused_icons
      paint_hints(base, c)
      place_cursor
      place_gold(gold_rect)
    end

    def header(base, top, c)
      PP.paint_background(base, c)
      n = @storage.maxBoxes
      cur = @storage.currentBox
      prev_i = (cur - 1) % n
      next_i = (cur + 1) % n
      found = search_on? ? match_boxes : [nil, nil]
      prev_i = found[0] if found[0]
      next_i = found[1] if found[1]
      prev_b = @storage[prev_i]
      next_b = @storage[next_i]
      side = proc { |j, b| found.include?(j) ? _INTL("{1} ({2})", b.name.to_s, matches_in(j)) : b.name.to_s }
      plain = !(fusing? && held) && !choosing? && !search_editing? && !@kr_entry
      # the middle's room (the name with its lock and a search's pill, or a
      # banner or field): the box names either side fit what's left
      mid0, mid1 = W / 2 - 115, W / 2 + 115
      if plain
        g = name_group
        mid0, mid1 = g[:x0] - 10, g[:x0] + g[:width] + 10
      end
      style = Reloaded::Prompts.style
      lk = Reloaded::Prompts.input(:L)
      rk = Reloaded::Prompts.input(:R)
      lw = lk ? Reloaded::ButtonIcons.draw(top, 8, 6, lk, c, style, 18) : 0
      x = 8 + lw + 6
      room = [[mid0 - x - 6, 120].min, 30].max
      pw = P.text(top, x, 4, room + 10, 22, PF.fit(PF::TEXT, side.call(prev_i, prev_b), room), c[:dim], PF::TEXT)
      @kr_hits << [[:prev], 4, 2, x + pw + 4, 28]
      rw = rk ? Reloaded::ButtonIcons.width(rk, style, 18) : 0
      Reloaded::ButtonIcons.draw(top, W - 8 - rw, 6, rk, c, style, 18) if rk
      room = [[W - 14 - rw - mid1 - 6, 120].min, 30].max
      next_name = PF.fit(PF::TEXT, side.call(next_i, next_b), room)
      nw = P.width(PF::TEXT, next_name)
      P.text(top, W - 14 - rw - nw, 4, nw, 22, next_name, c[:dim], PF::TEXT)
      @kr_hits << [[:next], W - 18 - rw - nw, 2, W - 4, 28]
      if fusing? && held
        banner(base, top, c, _INTL("Fusing with {1}", held.name.to_s).upcase, c[:gold], splicer_file)
      elsif comparing?
        banner(base, top, c, _INTL("Compare with {1}", @kr_compare[:first].name.to_s).upcase, c[:acc] || c[:selb], nil)
      elsif choosing?
        banner(base, top, c, _INTL("Choose a Pokémon").upcase, c[:acc] || c[:selb], nil)
      elsif search_editing?
        draw_search_field(base, top, c)
      elsif @kr_entry
        draw_entry_field(base, top, c)
      else
        g = name_group
        x0 = g[:x0]
        P.text(top, x0, 3, g[:tw], 24, g[:name], c[:title], PF::ROW)
        lx = x0 + g[:tw] + 8
        unless g[:lock].empty?
          padlock(top, lx + 1, 9, c[:red])
          P.text(top, lx + 12, 8, 120, 14, g[:lock], c[:red], PF::TINY)
          lx += g[:lock_w]
        end
        P.pill(top, lx, 8, g[:pill], c[:selb], c[:dark], false) if g[:pill]
        nr = name_rect
        @kr_hits << [[:name], nr[0], nr[1], nr[0] + nr[2], nr[1] + nr[3]] unless @kr_party_only
        @cursor_rect = nr if @kr_focus[0] == :name
      end
    end

    # A banner in the box name's place: a Splicer (or nothing) and the words
    def banner(base, top, c, words, tint, picture_file)
      ww = P.width(PF::TINY, words) + (picture_file ? 34 : 20)
      bw = [ww, 160].max
      x0 = (W - bw) / 2
      PP.chamfer_grad(base, x0, 5, x0 + bw, 27, 6, mix(c[:panel2], tint, 0.45), mix(c[:panel2], tint, 0.2), tint)
      tx = x0 + 10
      if picture_file
        picture_fit(top, picture_file, x0 + 6, 6, 20)
        tx = x0 + 28
      end
      P.text(top, tx, 9, bw - (tx - x0) - 6, 14, words, c[:strong], PF::TINY, picture_file ? 0 : 2)
    end

    def splicer_file
      item = @kr_splicer
      item = :DNASPLICERS unless item.is_a?(Symbol) || item.is_a?(String)
      return "Graphics/Items/#{item}"
    end

    # The box on its wallpaper, the game's 6 x 5
    def box_grid(base, top, c)
      gw = CELL_W * COLS
      gh = CELL_H * ROWS
      P.ui.rbox(base, BOX_X - 4, BOX_Y - 4, BOX_X + gw + 3, BOX_Y + gh + 3, 6, c[:panel2], c[:line])
      wall = wallpaper(box)
      base.stretch_blt(Rect.new(BOX_X, BOX_Y, gw, gh), wall, Rect.new(*WALL_SRC)) if wall
      lifted = held && !@kr_party_only ? @kr_focus : nil
      PokemonBox::BOX_SIZE.times do |i|
        sx, sy, = slot_rect(i)
        focus = @kr_focus == [:box, i]
        @kr_hits << [[:box, i], sx, sy, sx + CELL_W - 1, sy + CELL_H - 1] unless @kr_party_only
        @cursor_rect = [sx + 1, sy + 1, CELL_W - 2, CELL_H - 2] if focus && !@kr_party_only
        pk = box[i]
        next unless pk
        s = box_icon(pk)
        place(s, sx + CELL_W / 2, sy + CELL_H / 2 + 1, ART)
        s.opacity = dimmed?(pk) ? 90 : 255
        s.opacity = 110 if lifted == [:box, i]          # under the one held: what A swaps with
        star(top, sx + 3, sy + 3, c) if shiny?(pk)
        # NEW (his pick: NEW Pill), over the icon
        P.pill(marks, sx + CELL_W - 33, sy + CELL_H - 16, _INTL("NEW"), c[:green], c[:dark], false) if fresh?(pk)
      end
      selection_rect(top, c) if @kr_rect
      mark_origin(top)
    end

    def wallpaper(b)
      bg = b.background
      path = if defined?(::KIF::Wallpapers) && ::KIF::Wallpapers.respond_to?(:kif?) && ::KIF::Wallpapers.kif?(bg)
               ::KIF::Wallpapers.path(bg)
             else
               "Graphics/Pictures/Storage/Wallpapers/box_#{bg}"
             end
      return picture(path)
    end

    # PIF's rectangle (Select All, multi-select), see-through on the text layer
    def selection_rect(top, c)
      bx, sel = @kr_rect
      return unless bx && bx >= 0 && @screen.respond_to?(:getSelectionRect)
      r = @screen.getSelectionRect(bx, sel)
      return unless r
      x0 = BOX_X + r.x * CELL_W
      y0 = BOX_Y + r.y * CELL_H
      tint = Color.new(c[:green].red, c[:green].green, c[:green].blue, 70)
      top.fill_rect(x0 + 2, y0 + 2, r.width * CELL_W - 4, r.height * CELL_H - 4, tint)
    end

    # Where the held one came from, while it's held (his pick, 2026-10-25:
    # Soft Patch): a soft dark patch, like a shadow of where it was;
    # see-through, so on the text layer
    def mark_origin(top)
      return unless held && !fusing? && @kr_held_from
      from_box, idx = @kr_held_from
      return unless from_box == @storage.currentBox && idx && box[idx].nil?
      fx, fy, = slot_rect(idx)
      soft_patch(top, fx, fy, Color.new(0, 0, 0, 45))
    end

    # A soft patch over a place (rounded off at its corners): where a held
    # one came from, where held picks will land
    def soft_patch(b, sx, sy, col)
      b.fill_rect(sx + 6, sy + 6, CELL_W - 12, CELL_H - 12, col)
      b.fill_rect(sx + 9, sy + 4, CELL_W - 18, 2, col)
      b.fill_rect(sx + 9, sy + CELL_H - 6, CELL_W - 18, 2, col)
      b.fill_rect(sx + 4, sy + 9, 2, CELL_H - 18, col)
      b.fill_rect(sx + CELL_W - 6, sy + 9, 2, CELL_H - 18, col)
    end

    # The details plate, the Party Screen's two bands
    def plate(base, top, c)
      x0, y0, x1, y1 = PLATE
      pk = focused_pokemon
      @kr_detail[0].visible = false if @kr_detail && !@kr_detail[0].disposed?
      unless pk
        plate_bg(base, c, c[:panel2], x0, y0, x1, y1, nil)
        return
      end
      w = x1 - x0
      plate_bg(base, c, tone(pk), x0, y0, x1, y1, PLATE_LINE)
      detail_picture(pk, x0 + w / 2, y0 + 38)
      name_line(top, c, pk, x0, y0 + 71, w)
      unless pk.egg?
        P.text(top, x0, y0 + 89, w, 12, _INTL("Lv. {1}", pk.level), c[:gold], PF::TINY, 2)
        big_types(top, types_of(pk), x0, y0 + 102, w)
        about_rows(top, c, pk, x0 + 12, PLATE_LINE + 8, w - 24)
      else
        egg_rows(top, c, pk, x0 + 12, PLATE_LINE + 10, w - 24)
      end
      if (held && pk.equal?(held) && !fusing?)
        P.pill(top, x0 + 10, y0 + 8, _INTL("HOLDING"), c[:gold], c[:dark], false)
      elsif !multi_held.empty? && pk.equal?(multi_held[0][0])
        P.pill(top, x0 + 10, y0 + 8, _INTL("HOLDING {1}", multi_held.length), c[:gold], c[:dark], false)
      elsif picks?
        P.pill(top, x0 + 10, y0 + 8, _INTL("{1} PICKED", picks_here.length), c[:green], c[:dark], false)
      end
      plate_marks(top, c, pk)
    end

    def plate_bg(base, c, col, x0, y0, x1, y1, line_y)
      cut = 16
      topc = mix(c[:panel], col, 0.4)
      bottom = mix(c[:panel], c[:dark], 0.4)
      PP.chamfer_grad(base, x0, y0, x1, y1, cut, topc, bottom, mix(c[:line], col, 0.5))
      from = x1 - 48
      to = x0 + 24
      ly = line_y || y1
      (y0 + 1...y1 - 1).each do |y|
        t = (y - y0).to_f / (y1 - y0)
        left = x0 + 1 + [cut - (y - y0), 0].max
        right = x1 - 1 - [cut - (y1 - 1 - y), 0].max
        mid = from + (to - from) * t
        k = y < ly ? 0.4 : 0.22 - 0.18 * (y - ly).to_f / [y1 - ly, 1].max
        tint = mix(mix(topc, bottom, t), col, k)
        BANDS.each do |off, bw|
          a = [(mid + off - bw / 2.0).round, left].max
          b = [(mid + off + bw / 2.0).round, right].min
          base.fill_rect(a, y, b - a, 1, tint) if b > a
        end
      end
      base.fill_rect(x0 + 8, line_y, x1 - x0 - 16, 2, PP::POKE_RED) if line_y
    end

    def name_line(top, c, p, x, y, w)
      font = PF::TEXT
      name = PF.fit(font, p.name.to_s, w - 24)
      nw = P.width(font, name)
      extra = p.egg? ? 0 : (p.male? || p.female? ? 10 : 0) + (shiny?(p) ? 10 : 0)
      nx = x + (w - nw - extra) / 2
      P.text(top, nx, y, nw, 18, name, c[:txt], font)
      gx = nx + nw + 4
      gx += gender_mark(top, c, p, gx, y + 6) + 3 unless p.egg?
      star(top, gx, y + 5, c) if shiny?(p)
    end

    def about_rows(top, c, p, x, y, w)
      kw = 58
      step = 16
      ability = (p.ability rescue nil)
      item = (p.item rescue nil)
      rows = [[_INTL("Nature"), (p.nature.name rescue "")], [_INTL("Ability"), ability ? ability.name : _INTL("None")],
              [_INTL("Item"), item ? item.name : _INTL("None")]]
      rows.each_with_index do |(k, v), j|
        P.small(top, x, y + j * step, kw, 16, k, c[:dim])
        P.small(top, x + kw, y + j * step, w - kw, 16, v.to_s, c[:txt])
      end
      yy = y + rows.length * step
      P.small(top, x, yy, kw, 16, _INTL("IVs"), c[:dim])
      tot = iv_total(p)
      vw = P.small(top, x + kw, yy, 60, 16, "#{tot}/186", c[:blue])
      PP.bar(top, c, x + kw + vw + 10, yy + 7, [w - kw - vw - 14, 20].max, tot / 186.0, c[:blue], 2)
      cw = w / 3
      IV_KEYS.each_with_index do |(k, label), i|
        cx = x + (i % 3) * cw
        cy = yy + step + 3 + (i / 3) * 15
        v = (p.iv[k] rescue 0).to_i
        lw = P.text(top, cx, cy, 30, 12, _INTL(label), c[:dim], PF::TINY)
        P.text(top, cx + lw + 5, cy, 24, 12, v.to_s, v >= 31 ? c[:gold] : c[:txt], PF::TINY)
      end
    end

    def egg_rows(top, c, p, x, y, w)
      words, _s, left, frac = Reloaded::PartyScreen.egg_stage(p)
      P.small(top, x, y, w, 16, _INTL("Steps Left: {1}", left), c[:txt])
      PP.bar(top, c, x + 2, y + 22, w - 4, frac, c[:green])
      P.small_wrap(top, words, w).first(2).each_with_index { |ln, j| P.small(top, x, y + 32 + j * 15, w, 16, ln, c[:dim]) }
    end

    # The party along the bottom: big icons at All only (KIF's PC party
    # tab); empty places dashed
    def party_row(base, top, c)
      bx0 = 6
      bx1 = W - 6
      PP.chamfer_grad(base, bx0, PARTY_Y, bx1, PARTY_Y1, 10, c[:panel2], mix(c[:panel2], c[:dark], 0.35), c[:line])
      P.heading(top, bx0 + 12, bx1 - 12, PARTY_Y + 4, _INTL("Party"), c[:dim], c[:line])
      6.times do |i|
        cx, cy = party_centre(i)
        x0 = cx - PARTY_STEP / 2 + 2
        @kr_hits << [[:party, i], x0, PARTY_Y + 16, x0 + PARTY_STEP - 4, PARTY_Y + 76]
        @cursor_rect = [x0, PARTY_Y + 16, PARTY_STEP - 4, 60] if @kr_focus == [:party, i]
        pk = @storage.party[i]
        unless pk
          dashed(base, c, cx - 22, cy - 18, cx + 22, cy + 22)
          next
        end
        s = box_icon(pk)
        place(s, cx, cy, 38)
        s.opacity = dimmed?(pk) ? 90 : 255
        s.opacity = 110 if held && @kr_focus == [:party, i]
        hp_bar(top, c, pk, cx - 24, PARTY_Y + 64, 48) unless pk.egg?
      end
    end

    def dashed(b, c, x0, y0, x1, y1)
      col = c[:line]
      (x0...x1).step(6) { |x| b.fill_rect(x, y0, 3, 1, col); b.fill_rect(x, y1, 3, 1, col) }
      (y0...y1).step(6) { |y| b.fill_rect(x0, y, 1, 3, col); b.fill_rect(x1, y, 1, 3, col) }
    end

    # The held one (or several) over the cursor's place, with a small shadow
    # (his pick: Lifted); a Splicer rides with it while fusing
    def held_over(base, top, c)
      list = []
      list << [held, 0, 0] if held
      return if list.empty? && multi_held.empty?
      kind, i = @kr_focus
      pointer = dragging? ? Reloaded::Pointer.pos : nil
      cx, cy = if pointer
                 [pointer[0], pointer[1] - 4]               # dragged: right under the pointer
               elsif kind == :box
                 sx, sy, = slot_rect(i)
                 [sx + CELL_W / 2, sy + CELL_H / 2 - 9]
               elsif kind == :party
                 pc = party_centre(i)
                 [pc[0], pc[1] - 12]
               else
                 nr = name_rect
                 [nr[0] + nr[2] / 2, nr[1] + 34]
               end
      # several (Free Picks): a small fan (UI/PCPicks.rb)
      return draw_multi_held(top, c, cx, cy) if list.empty?
      # see-through, so on the clear text layer: a fill there blends over the
      # wallpaper (on the panels' layer it would cut a hole in them)
      shadow = Color.new(0, 0, 0, 60)
      list.each_with_index do |(pk, dx, dy), k|
        x = cx + dx * CELL_W
        y = cy + dy * CELL_H
        top.fill_rect(x - 10, y + 13, 20, 2, shadow)
        top.fill_rect(x - 7, y + 12, 14, 4, shadow)
        s = box_icon(pk, :held)
        place(s, x, y, 44)
        s.opacity = 255
        s.z = 2
      end
      if fusing?
        picture_fit(top, splicer_file, cx + 14, cy - 22, 20)
      end
    end

    #--------------------------------------------------------------------------
    # Pieces
    #--------------------------------------------------------------------------
    def tone(p)
      return Color.new(150, 200, 140) if p.egg?
      return PP.rgb(Reloaded::PartyScreen.type_rgb(types_of(p)[0]))
    end

    def types_of(p)
      return [] if p.egg?
      return [p.type1, p.type2].compact.uniq
    rescue StandardError
      return []
    end

    def big_types(b, types, x, y, w)
      sheet = picture(PP::TYPES_BIG)
      return unless sheet
      total = types.length * 42 - 2
      types.each_with_index do |t, j|
        b.stretch_blt(Rect.new(x + (w - total) / 2 + j * 42, y, 40, 18), sheet, Rect.new(0, PP.type_row(t) * 28, 64, 28))
      end
    end

    def iv_total(p)
      return [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED].sum { |k| (p.iv[k] rescue 0).to_i }
    end

    def hp_bar(top, c, p, x, y, w)
      PP.bar(top, c, x, y, w, p.hp.to_f / [p.totalhp, 1].max, PP.hp_colour(c, p), 3)
    end

    def shiny?(p)
      return !p.egg? && p.shiny? ? true : false
    rescue StandardError
      return false
    end

    def star(b, x, y, c)
      PP.pixels(b, PP::STAR, x + 1, y + 1, c[:light] ? Color.new(120, 90, 0) : Color.new(30, 24, 8))
      PP.pixels(b, PP::STAR, x, y, c[:gold])
    end

    def gender_mark(b, c, p, x, y)
      if p.male? then PP.pixels(b, PP::MALE, x, y, c[:blue]); return 8
      elsif p.female? then PP.pixels(b, PP::FEMALE, x, y, c[:pink]); return 7
      end
      return 0
    end

    # The ones the game's filter won't take (choosing for something), and
    # fusions while fusing (they can't be fused again)
    def dimmed?(pk)
      filter = @screen && @screen.respond_to?(:filterProc) ? @screen.filterProc : nil
      return true if filter && !(filter.call(pk) rescue true)
      return true if !@kr_fusions_on && (pk.isFusion? rescue false)
      return true if @kr_search && !search_match?(pk)            # Search: Dim the Rest
      return false
    end

    def mix(a, b, t)
      return Reloaded::Palette.mix(a, b, t)
    end

    def picture(path)
      @kr_pictures ||= {}
      return @kr_pictures[path] if @kr_pictures.key?(path)
      @kr_pictures[path] = begin
        Bitmap.new(pbResolveBitmap(path) || path)
      rescue StandardError
        nil
      end
    end

    def picture_fit(b, path, x, y, size)
      bm = picture(path)
      b.stretch_blt(Rect.new(x, y, size, size), bm, Rect.new(0, 0, bm.width, bm.height)) if bm
    end

    def dispose_marks
      return unless @kr_marks
      @kr_marks.bitmap.dispose if @kr_marks.bitmap && !@kr_marks.bitmap.disposed?
      @kr_marks.dispose unless @kr_marks.disposed?
      @kr_marks = nil
    end

    def dispose_pictures
      (@kr_pictures || {}).each_value { |bm| bm.dispose if bm && !bm.disposed? }
      @kr_pictures = {}
    end

    #--------------------------------------------------------------------------
    # Icons: PIF's box icons (KIF's Big Pokémon Icons at All, its shiny and
    # fusion icons), and the details' picture (big at Limited and All)
    #--------------------------------------------------------------------------
    def box_icon(pk, key = nil)
      k = key || pk.object_id
      (@kr_used ||= {})[k] = true
      s, who = @kr_icons[k]
      if s && !s.disposed? && who.equal?(pk)
        s.visible = true
        return s
      end
      s.dispose if s && !s.disposed?
      s = ::PokemonBoxIcon.new(pk, @viewport)
      s.z = 2
      @kr_icons[k] = [s, pk]
      return s
    end

    def detail_picture(pk, cx, cy)
      if @kr_detail.nil? || @kr_detail[0].disposed? || !@kr_detail[1].equal?(pk)
        @kr_detail[0].dispose if @kr_detail && !@kr_detail[0].disposed?
        s = Reloaded::PartyIcons.icon(pk, @viewport, 2)
        @kr_detail = s ? [s, pk] : nil
      end
      return unless @kr_detail
      s = @kr_detail[0]
      s.visible = true
      place(s, cx, cy, 62, 1.0)
    end

    def hide_icons
      (@kr_icons || {}).each_value { |s, _pk| s.visible = false unless s.disposed? }
    end

    # Icons of Pokémon no longer on screen (another box, released) go
    def drop_unused_icons
      used = @kr_used || {}
      (@kr_icons || {}).keys.each do |k|
        next if used[k]
        s, _pk = @kr_icons.delete(k)
        s.dispose if s && !s.disposed?
      end
    end

    def dispose_icons
      (@kr_icons || {}).each_value { |s, _pk| s.dispose unless s.disposed? }
      @kr_icons = {}
      @kr_detail[0].dispose if @kr_detail && !@kr_detail[0].disposed?
      @kr_detail = nil
    end

    # The art (not its frame) fitted in size, its middle on cx, cy; small
    # art isn't blown up past cap of its frame. A big icon's KIF shift (made
    # for PIF's own PC) is taken back out.
    def place(s, cx, cy, size, cap = 0.8)
      return unless s.bitmap && !s.bitmap.disposed?
      f = [s.src_rect.height, 1].max
      key = [s.bitmap.object_id, f]
      @kr_art ||= {}
      r = (@kr_art[key] ||= Reloaded::PartyIcons.art_rect(s.bitmap, f))
      z = [size.to_f / [r.width, r.height, 1].max, cap * 96.0 / f].min
      s.zoom_x = s.zoom_y = z
      s.ox = r.x + r.width / 2
      s.oy = r.y + r.height / 2
      shift = s.respond_to?(:kif_big_shift) ? s.kif_big_shift.to_i : 0
      s.x = cx - shift
      s.y = cy - shift
      s.visible = true
    end

    # Release: the Pokémon fades out
    def fade_out(list)
      sprites_of = list.map { |pk| (@kr_icons || {}).values.find { |_s, who| who.equal?(pk) } }.compact.map { |s, _w| s }
      return if sprites_of.empty?
      16.times do |k|
        sprites_of.each { |s| s.opacity = 255 - k * 16 unless s.disposed? }
        Graphics.update
        update_frame
      end
    end
  end
end
