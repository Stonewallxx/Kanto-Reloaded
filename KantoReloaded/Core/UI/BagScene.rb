# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Reloaded Bag's screen
#==============================================================================
# His pick (Roadmap Designs topic bag, 2026-10-23): Design 1, Reloaded Bag,
# Rebuilt, in the TM Vault's look. Kanto Reloaded's scene takes the game's
# place (PokemonBag_Scene.new hands it out while the Reloaded Bag is on), so
# the game's own PokemonBagScreen still makes the item's commands and does
# what's picked: the pause menu's Bag, every item picker, the game's battle
# Bag and PC Deposit all open it, and other mods' item commands still show.
#
#   the header   Search (type into it; L) and Sort (the view; R)
#   the pockets  the eight pockets' icons, NEW dots, the open one lit, its
#                name; Left and Right skip the empty ones (his pick)
#   the list     one panel: each name in its pocket's colour (Spectrum; a
#                TM's in its move's type, Vivid), Favorites starred and first, NEW, the
#                count and the item's picture (a TM: its number and type)
#   the details  lit in the item's colour: its name, what it's good for
#                (USE, IN BATTLE, HOLD, KEY ITEM, QUICK SLOT n), its
#                description and picture; a TM or HM, or an Evolution
#                Stone: who in the party can use it
#
# A opens the item's actions (his picks, 2026-10-23, popups 1-3): Kanto
# Reloaded's menu with a line saying what each does; the game's own first
# (without its Sort Bag; Teach in Use's place on a TM with the TM Vault on),
# then Favorite, Add to / Remove From Quick Items, Move where the pocket
# allows it. Toss shows the item and how many stay, asks with Keep first,
# and says it's done in a toast. Add to Quick Items takes the first empty
# slot (a toast says which); only when all seven are full does a row of
# the slots ask which to replace.
# Y Favorite, R the next view, L Search, B closes (or clears the search).
# In a picker (Give, a Berry, a Quick Item...) a banner over the list says
# what's being chosen (popup 5, his pick: Banner), only what fits shows,
# and nothing saved changes.
# The game's Mart keeps its own Bag for Sell until the Shop has its screen.
#==============================================================================

return unless defined?(Reloaded::Frame) && defined?(::KIF::PixelFont) && defined?(Reloaded::PartyPaint) && defined?(Reloaded::Bag)

module Reloaded
  # The game's Bag scenes: Kanto Reloaded's while the Reloaded Bag is on
  module BagScreen
    @full = false        # the full Bag is opening (the pause menu's), not a picker
    @title = nil         # what a picker is choosing for: [banner, A's word]
    @mart = false        # the Mart's Sell is opening (the game's own, for now)

    class << self
      attr_accessor :full, :title, :mart

      def boot
        install
        return true
      end

      def active?
        return Reloaded::Bag.on? && Reloaded::Pixel.available? ? true : false
      end

      def scene_class
        return @scene_class if @scene_class
        # what watches the game's Bag scene (Recent Steps, the Timing
        # Profiler) watches ours too
        return @scene_class = Reloaded::Hooks.scene_class(::PokemonBag_Scene, Class.new(::PokemonBag_Scene) { include Reloaded::BagScene })
      end

      # Around a call: what's opening (the full Bag, a picker's title, the Mart)
      def during(field, value)
        before = instance_variable_get(field)
        instance_variable_set(field, value)
        return yield
      ensure
        instance_variable_set(field, before)
      end

      # A picker's [banner, A's word], with the Pokémon's name when there is one
      def titled(words, verb, pk)
        name = pk && pk.respond_to?(:name) ? pk.name.to_s : ""
        words = words.sub(/ (to|on) \{1\}\z/, "") if name.empty?
        return [_INTL(words, name), _INTL(verb)]
      end

      def highlighted(scene)
        party = scene.instance_variable_get(:@party)
        i = scene.instance_variable_get(:@activecmd)
        return party.is_a?(Array) && i.is_a?(Integer) ? party[i] : nil
      rescue StandardError
        return nil
      end

      #------------------------------------------------------------------------
      # The Bag page's Export and Import (Kanto Reloaded > Bag)
      #------------------------------------------------------------------------
      # Done: where it went and what's in it, Open Folder (his pick, small
      # popup design 3; a phone copies the path)
      def export_pressed
        path = Reloaded::Bag.export_lists
        screen = settings_screen
        return say(_INTL("Lists Exported"), _INTL("Saved to the Kanto Reloaded folder: Exports\\{1}", File.basename(path))) unless screen
        phone = defined?(Reloaded::Runtime) && Reloaded::Runtime.phone?
        choice = on_screen(screen) do
          Reloaded::Dialogs.ask(screen, _INTL("Lists Exported"), _INTL("Saved to the Kanto Reloaded folder: Exports\\{1}", File.basename(path)),
                                [[tally_words(Reloaded::Bag.current_tally) + ".", screen.palette[:dim]]],
                                [phone ? _INTL("Copy the Path") : _INTL("Open Folder"), _INTL("OK")], 1)
        end
        return unless choice == 0
        return on_screen(screen) { screen.copy_for_phone(File.expand_path(path), _INTL("Where the lists are, ready to paste.")) } if phone
        system("explorer /select,\"#{File.expand_path(path).tr("/", "\\")}\"")
      rescue StandardError => e
        Reloaded::Log.exception("The Bag's lists couldn't be exported", e, :bag)
        say(_INTL("Lists Not Exported"), _INTL("The file couldn't be written. The log has why."))
      end

      # Asks with what the file holds, Keep Mine first (his pick, small
      # popup design 2); after, the same look says what came in
      def import_pressed
        path = Reloaded::Bag.import_path
        unless path
          return say(_INTL("No Lists to Import"), _INTL("Export Lists makes the file: Exports\\{1} in the Kanto Reloaded folder.", Reloaded::Bag::EXPORT_FILE))
        end
        peek = Reloaded::Bag.peek_lists(path)
        return say(_INTL("Nothing to Import"), _INTL("{1} has no lists in it.", File.basename(path))) unless peek
        screen = settings_screen
        ok = if screen
               on_screen(screen) do
                 Reloaded::Dialogs.ask(screen, _INTL("Replace Your Lists?"),
                                       _INTL("{1} replaces the lists, Favorites and Auto-Sort it has.", File.basename(path)),
                                       [[_INTL("In it: {1}, exported {2}.", tally_words(peek, true), when_words(peek[:time])), screen.palette[:dim]]],
                                       [_INTL("Replace"), _INTL("Keep Mine")], 1) == 0
               end
             else
               true
             end
        return unless ok
        got = Reloaded::Bag.import_lists(path)
        return say(_INTL("Nothing to Import"), _INTL("{1} has no lists in it.", File.basename(path))) unless got
        extra = got[:ignored] > 0 ? _INTL(" {1} unknown entries were left out.", got[:ignored]) : ""
        say(_INTL("Lists Imported"), _INTL("From {1}.", got[:file]), tally_words(Reloaded::Bag.current_tally, true) + "." + extra)
      rescue StandardError => e
        Reloaded::Log.exception("The Bag's lists couldn't be imported", e, :bag)
        say(_INTL("Lists Not Imported"), _INTL("The file couldn't be read. The log has why."))
      end

      # "8 pockets, 312 items, 6 headings and 9 Favorites"
      def tally_words(t, favorites = false)
        parts = [t[:pockets] == 1 ? _INTL("1 pocket") : _INTL("{1} pockets", t[:pockets]),
                 t[:items] == 1 ? _INTL("1 item") : _INTL("{1} items", t[:items])]
        parts << (t[:headings] == 1 ? _INTL("1 heading") : _INTL("{1} headings", t[:headings])) if t[:headings] > 0
        parts << (t[:favorites] == 1 ? _INTL("1 Favorite") : _INTL("{1} Favorites", t[:favorites])) if favorites && t[:favorites] > 0
        return parts.length > 1 ? parts[0...-1].join(", ") + _INTL(" and ") + parts[-1] : parts[0]
      end

      def when_words(time)
        return _INTL("today at {1}", time.strftime("%H:%M")) if time.strftime("%Y%m%d") == Time.now.strftime("%Y%m%d")
        return _INTL("on {1}", time.strftime("%b %-d"))
      rescue StandardError
        return ""
      end

      private

      def settings_screen
        return defined?(Reloaded::SettingsScreen) && Reloaded::SettingsScreen.respond_to?(:showing) ? Reloaded::SettingsScreen.showing : nil
      end

      # A notice on the settings screen (a line under it in its own colour)
      def say(title, text, line = nil)
        screen = settings_screen
        if screen
          segs = line ? [[line, screen.palette[:dim]]] : nil
          return on_screen(screen) { Reloaded::Dialogs.ask(screen, title, text, segs, [_INTL("OK")], 0) } if segs
          return on_screen(screen) { Reloaded::Dialogs.notice(screen, title, text) }
        end
        pbMessage(text) if defined?(pbMessage)
        return true
      end

      # A button's press hides the settings screen (another screen takes
      # over); a popup of its own shows it again while it's up
      def on_screen(screen)
        hid = screen.send(:sprites).reject { |s| s.disposed? || s.visible }
        hid.each { |s| s.visible = true }
        return yield
      ensure
        (hid || []).each { |s| s.visible = false unless s.disposed? }
      end

      public

      private

      def install
        h = Reloaded::Hooks
        if defined?(::PokemonBag_Scene) && !@new_hooked
          @new_hooked = true
          h.prepend(nil, ::PokemonBag_Scene.singleton_class, SceneChoice, :id => :bag_scene)
        end
        if defined?(::PokemonBagScreen) && !@screen_hooked
          @screen_hooked = true
          h.around(Bag::FEATURE, ::PokemonBagScreen, :pbStartScreen, :id => :bag_full) do |original, *args|
            Reloaded::BagScreen.during(:@full, true) { original.call(*args) }
          end
          if ::PokemonBagScreen.method_defined?(:pbDepositItemScreen)
            h.around(Bag::FEATURE, ::PokemonBagScreen, :pbDepositItemScreen, :id => :bag_deposit) do |original, *args|
              Reloaded::BagScreen.during(:@title, [_INTL("Deposit an Item"), _INTL("Deposit")]) { original.call(*args) }
            end
          end
        end
        if defined?(::PokemonParty_Scene) && !@party_hooked
          @party_hooked = true
          # the Pokémon is the party screen's highlighted one (the game's
          # and Kanto Reloaded's both keep @party and @activecmd)
          { :pbChooseItem => ["Give an Item to {1}", "Give"], :pbUseItem => ["Use an Item on {1}", "Use"] }.each do |name, (words, verb)|
            next unless ::PokemonParty_Scene.method_defined?(name)
            h.around(Bag::FEATURE, ::PokemonParty_Scene, name, :id => :"bag_title_#{name}") do |original, *args|
              scene = original.receiver
              pk = name == :pbUseItem && args[1] ? args[1] : Reloaded::BagScreen.highlighted(scene)
              Reloaded::BagScreen.during(:@title, Reloaded::BagScreen.titled(words, verb, pk)) { original.call(*args) }
            end
          end
        end
        if defined?(::PokemonSummary_Scene) && ::PokemonSummary_Scene.method_defined?(:pbOptions) && !@summary_hooked
          @summary_hooked = true
          h.around(Bag::FEATURE, ::PokemonSummary_Scene, :pbOptions, :id => :bag_title_summary) do |original, *args|
            pk = original.receiver.instance_variable_get(:@pokemon)
            Reloaded::BagScreen.during(:@title, Reloaded::BagScreen.titled("Give an Item to {1}", "Give", pk)) { original.call(*args) }
          end
        end
        if defined?(::PokeBattle_Scene) && ::PokeBattle_Scene.method_defined?(:pbItemMenu) && !@battle_hooked
          @battle_hooked = true
          h.around(Bag::FEATURE, ::PokeBattle_Scene, :pbItemMenu, :id => :bag_title_battle) do |original, *args|
            Reloaded::BagScreen.during(:@title, [_INTL("Use an Item"), _INTL("Use")]) { original.call(*args) }
          end
        end
        unless @global_hooked
          @global_hooked = true
          { :pbBerryPlant => :soil, :pbChooseApricorn => ["Choose an Apricorn", "Select"],
            :pbChooseFossil => ["Choose a Fossil", "Select"] }.each do |name, title|
            next unless ::Object.private_method_defined?(name) || ::Object.method_defined?(name)
            h.around(Bag::FEATURE, ::Object, name, :id => :"bag_title_#{name}") do |original, *args, &blk|
              t = title.is_a?(Array) ? [_INTL(title[0]), _INTL(title[1])] : title
              Reloaded::BagScreen.during(:@title, t) { original.call(*args, &blk) }
            end
          end
        end
        if defined?(::PokemonMart_Scene) && ::PokemonMart_Scene.method_defined?(:pbStartSellScene2) && !@mart_hooked
          @mart_hooked = true
          h.around(Bag::FEATURE, ::PokemonMart_Scene, :pbStartSellScene2, :id => :bag_mart_sell) do |original, *args|
            Reloaded::BagScreen.during(:@mart, true) { original.call(*args) }
          end
        end
      end
    end

    module SceneChoice
      def new(*args, &block)
        if equal?(::PokemonBag_Scene) && Reloaded::BagScreen.active? && !Reloaded::BagScreen.mart
          begin
            return Reloaded::BagScreen.scene_class.new(*args, &block)
          rescue Exception => e
            raise if Reloaded::Hooks.passthrough?(e)
            Reloaded::Log.exception("The Bag didn't open; the game's own instead", e, :bag)
          end
        end
        super
      end
    end
  end

  # Kanto Reloaded's Bag scene (included in a subclass of the game's)
  module BagScene
    include Reloaded::Frame
    include Reloaded::BagLook

    PF = ::KIF::PixelFont
    PP = Reloaded::PartyPaint
    B = Reloaded::Bag
    # PIF's own words (his ask, 2026-10-24: Learned, Able)
    CHECK_WORDS = { :knows => ["Learned", :blue], :learn => ["Able", :green], :cant => ["Not Able", :dim] }.freeze
    # What a healing item does, for Who Needs It (his pick, 2026-10-24:
    # the party in its details, as the TMs' check): :hp, :restore (HP and
    # status), :revive, :status (any), :pp, or the statuses it cures
    HEAL_KINDS = {
      :POTION => :hp, :SUPERPOTION => :hp, :HYPERPOTION => :hp, :MAXPOTION => :hp, :FRESHWATER => :hp, :SODAPOP => :hp,
      :LEMONADE => :hp, :MOOMOOMILK => :hp, :ENERGYPOWDER => :hp, :ENERGYROOT => :hp, :BERRYJUICE => :hp, :SWEETHEART => :hp,
      :ORANBERRY => :hp, :SITRUSBERRY => :hp, :FULLRESTORE => :restore,
      :REVIVE => :revive, :MAXREVIVE => :revive, :REVIVALHERB => :revive,
      :FULLHEAL => :status, :HEALPOWDER => :status, :LAVACOOKIE => :status, :OLDGATEAU => :status, :CASTELIACONE => :status,
      :LUMBERRY => :status,
      :ANTIDOTE => [:POISON], :PECHABERRY => [:POISON], :BURNHEAL => [:BURN], :RAWSTBERRY => [:BURN],
      :ICEHEAL => [:FROZEN], :ASPEARBERRY => [:FROZEN], :AWAKENING => [:SLEEP], :CHESTOBERRY => [:SLEEP],
      :PARLYZHEAL => [:PARALYSIS], :CHERIBERRY => [:PARALYSIS],
      :ETHER => :pp, :MAXETHER => :pp, :ELIXIR => :pp, :MAXELIXIR => :pp, :LEPPABERRY => :pp
    }.freeze
    SEARCH_BOX = [6, 4, 166, 26].freeze
    SORT_BOX = [W - 166, 4, W - 6, 26].freeze
    BAR_Y = 34
    LIST_Y0 = 66
    LIST_Y1 = 245
    ROW_H = 25
    HEAD_H = 16
    BANNER_H = 22
    LIST_X = 14
    LIST_W = W - 38
    DETAILS_Y = 249

    #--------------------------------------------------------------------------
    # The game's scene methods
    #--------------------------------------------------------------------------
    def pbStartScene(bag, choosing = false, filterproc = nil, resetpocket = true)
      @bag = bag
      @choosing = choosing
      @filterproc = filterproc
      @sprites = {}
      @kr_full = !choosing && Reloaded::BagScreen.full
      @kr_title = choosing ? picker_title(Reloaded::BagScreen.title) : nil
      @query = nil
      @entry = nil
      @moving = nil
      @kr_toss = nil
      @popup_hints = nil
      @pictures = {}
      @icons = []
      frame_init
      pbRefreshFilter
      pocket = choosing && resetpocket ? 1 : @bag.lastpocket.to_i
      pocket = 1 unless B.pockets.include?(pocket)
      pocket = next_pocket(pocket, 1) unless usable?(pocket)
      @pocket = pocket
      @bag.lastpocket = pocket
      B.refresh_seen!(@bag) if @kr_full
      open_sprites
      make_icons
      build_rows
      choose_saved
      draw
    end

    def pbChooseItem
      loop do
        Graphics.update
        Input.update
        pbUpdate
        result = handle_input
        next if result == :stay
        return result
      end
    end

    def pbRefresh
      build_rows
      remember
      draw if @sprite && !@sprite.disposed?
    end

    def pbRefreshIndexChanged
      draw if @sprite && !@sprite.disposed?
    end

    # What a picker allows: each pocket's item ids that fit
    def pbRefreshFilter
      @allowed = nil
      return unless @choosing && @filterproc
      @allowed = {}
      B.pockets.each do |p|
        @allowed[p] = B.slots(@bag, p).map { |s| s && s[0] }.compact.select { |id| (@filterproc.call(id) rescue false) }
      end
    end

    def pbUpdate
      update_frame
      @icons.each { |s| s.update if s && !s.disposed? && s.respond_to?(:update) }
      Reloaded::Toast.update if defined?(Reloaded::Toast)
    end

    def pbFadeOutScene
      @kr_shown = sprites.select(&:visible)
      @kr_shown.each { |s| s.visible = false }
    end

    def pbFadeInScene
      (@kr_shown || []).each { |s| s.visible = true unless s.disposed? }
      @kr_shown = nil
    end

    def pbEndScene
      B.seen!(@pocket, @bag) if @kr_full
      remember
      dispose_icons
      dispose_sprites
      @pictures.each_value { |b| b.dispose if b && !b.disposed? }
      @pictures = {}
    end

    # The game's Toss ends here ("Threw away..."): a toast (his pick)
    def pbDisplay(msg, brief = false)
      if (toss = @kr_toss) && toss[1]
        @kr_toss = nil
        tossed(toss[0], toss[1])
        refresh
        return
      end
      Reloaded::Dialogs.notice(self, _INTL("Bag"), msg.to_s)
      refresh
    end

    # The game's Toss asks before throwing away: Kanto Reloaded's question,
    # Keep chosen first so a quick A twice throws nothing away (his pick)
    def pbConfirm(msg)
      if (toss = @kr_toss)
        toss[1] ||= 1
        ret = toss_question(toss[0], toss[1])
        @kr_toss = nil unless ret
        refresh
        return ret
      end
      ret = Reloaded::Dialogs.confirm(self, _INTL("Bag"), msg.to_s)
      refresh
      return ret
    end

    def pbChooseNumber(helptext, maximum, initnum = 1)
      if (toss = @kr_toss)
        n = toss_number(toss[0], maximum)
        toss[1] = n
        @kr_toss = nil unless n
        refresh
        return n || 0
      end
      n = Reloaded::Dialogs.number(self, PF.fit(PF::TEXT, helptext.to_s, 280), initnum, 1, maximum)
      refresh
      return n || 0
    end

    # The item's actions (his pick: Kanto Reloaded's menu, each explained):
    # the game's list (its Sort Bag left out: Kanto Reloaded's order
    # replaces it; Teach in Use's place for a TM with the TM Vault on), then
    # Favorite, Quick Items and Move. Kanto Reloaded's run here, and the
    # game's own loop just goes back to the list (its Cancel).
    def pbShowCommands(helptext, commands, index = 0)
      item = @kr_menu_item
      @kr_menu_item = nil
      @kr_toss = nil
      cancel = commands.length - 1
      unless item && commands.last.to_s == _INTL("Cancel")
        ret = with_hints(menu_hints) { Reloaded::Dialogs.menu(self, PF.fit(PF::TEXT, helptext.to_s, 280), commands.map(&:to_s), [], index) }
        refresh
        return ret.nil? ? cancel : ret
      end
      it = B.item_data(item)
      labels = []
      notes = []
      map = []
      use = use_index(item, commands)
      commands.each_with_index do |label, i|
        next if i == cancel || label.to_s == _INTL("Sort bag")
        if teach?(it) && i == use
          labels << _INTL("Teach")
          notes << _INTL("Opens the TM Vault on {1}. Teaching is free.", display_name(item))
          map << :teach
          next
        end
        labels << label.to_s
        notes << game_note(label.to_s, it, i == use)
        map << (label.to_s == _INTL("Toss") ? [:toss, i] : i)
      end
      if @kr_full && tm_search?(it)
        labels << _INTL("Who Can Learn")
        notes << _INTL("Every Pokémon that can learn {1}: Yours first, the PC's too.", display_name(item))
        map << :tm_learners
        labels << _INTL("Search TMs")
        notes << _INTL("Every TM and HM by its move, ones you don't have too.")
        map << :tm_search
      end
      if @kr_full
        fav = B.favorite?(item)
        labels << (fav ? _INTL("Remove Favorite") : _INTL("Favorite"))
        notes << (fav ? _INTL("Take its star off.") : _INTL("Keep it at the top of {1}.", B.pocket_name(@pocket)))
        map << :favorite
        if quick_ok?(item)
          slot = quick_slot(item)
          labels << (slot ? _INTL("Remove From Quick Items") : _INTL("Add to Quick Items"))
          notes << (slot ? _INTL("Take it out of Quick Items slot {1}.", slot) : _INTL("Put it in a Quick Items slot (the Overworld Menu)."))
          map << (slot ? :unquick : :quick)
        end
        if B.can_move?(@pocket) && @query.nil? && B.slots(@bag, @pocket).length > 1
          labels << _INTL("Move")
          notes << (B.mode(@pocket) == 1 ? _INTL("Move it in {1}'s Custom List.", B.pocket_name(@pocket)) : _INTL("Move it in {1}.", B.pocket_name(@pocket)))
          map << :move
        end
      end
      labels << _INTL("Cancel")
      notes << _INTL("Back to the Bag.")
      map << cancel
      choice = with_hints(menu_hints) { Reloaded::Dialogs.menu(self, display_name(item), labels, notes, 0) }
      act = choice.nil? ? cancel : map[choice]
      case act
      when :favorite then favorite(item)
      when :quick then add_quick(item)
      when :unquick then remove_quick(item)
      when :move then start_move(item)
      when :teach then teach(item)
      when :tm_learners then tm_search(:show, item)
      when :tm_search then tm_search(:search, item)
      when Array
        @kr_toss = [item, quantity(item) > 1 ? nil : 1]
        refresh
        return act[1]
      else
        refresh
        return act
      end
      refresh
      return cancel
    end

    def get_current_pocket
      return @bag.pockets[@pocket]
    end

    def entry=(state)
      @entry = state
    end

    def entry_changed
      draw if @sprite && !@sprite.disposed?
    end

    def refresh
      draw if @sprite && !@sprite.disposed?
    end

    private

    #--------------------------------------------------------------------------
    # The pockets and rows
    #--------------------------------------------------------------------------
    def ids_in(pocket)
      list = B.slots(@bag, pocket).map { |s| s && s[0] }.compact
      list = list.select { |id| @allowed[pocket].include?(id) } if @allowed
      return list
    end

    # A pocket Left and Right stop on: one with something in it (that fits)
    def usable?(pocket)
      return !ids_in(pocket).empty?
    end

    def next_pocket(from, dir)
      dir = 1 if dir == 0
      list = B.pockets
      i = list.index(from) || 0
      list.length.times do
        i = (i + dir) % list.length
        return list[i] if usable?(list[i])
      end
      return from
    end

    # [[:item, id, qty] | [:heading, pocket]]
    def build_rows
      @rows = if @query
                out = []
                B.pockets.each do |p|
                  hits = ids_in(p).uniq.select { |id| match?(id) }
                  next if hits.empty?
                  out << [:heading, p]
                  hits.sort_by { |id| display_name(id).downcase }.each { |id| out << [:item, id, quantity(id)] }
                end
                out
              elsif @moving
                B.slots(@bag, @pocket).compact.map { |s| [:item, s[0], s[1]] }
              else
                allowed = ids_in(@pocket)
                ids = B.rows(@pocket, B.view(@pocket), @bag).select { |id| allowed.include?(id) }.uniq
                # a Custom List's headings (a String; a pocket's heading in a search is its number)
                sec = B.sectioned(@pocket, ids)
                sec ? sec.map { |e| e.is_a?(String) ? [:heading, e] : [:item, e, quantity(e)] } : ids.map { |id| [:item, id, quantity(id)] }
              end
      @sel = [[@sel.to_i, @rows.length - 1].min, 0].max
      @sel += 1 while @rows[@sel] && @rows[@sel][0] == :heading && @sel < @rows.length - 1
    end

    def quantity(id)
      return (@bag.pbQuantity(id) rescue 0).to_i
    end

    # The bag's remembered place in the pocket: the row it points at
    def choose_saved
      i = @bag.getChoice(@pocket).to_i rescue 0
      slot = B.slots(@bag, @pocket)[i]
      k = slot ? @rows.index { |r| r[0] == :item && r[1] == slot[0] } : nil
      @sel = k || 0
    end

    # The game keeps the place in the pocket (the battle reads it while the
    # Bag is open): the real slot of the row
    def remember
      @bag.lastpocket = @pocket if @bag.respond_to?(:lastpocket=) && B.pockets.include?(@pocket)
      id = current
      i = id ? B.slots(@bag, @pocket).index { |s| s && s[0] == id } : nil
      @bag.setChoice(@pocket, i) if i && @bag.respond_to?(:setChoice)
    rescue StandardError
      nil
    end

    def current
      r = @rows && @rows[@sel]
      return r && r[0] == :item ? r[1] : nil
    end

    # A word starting with what's typed (his pick): "ice" finds Never-Melt
    # Ice and Ice Beam, not Choice Scarf; a TM's number too ("tm24")
    def match?(id)
      q = @query.to_s.downcase
      return true if q.empty?
      it = B.item_data(id)
      words = [display_name(id), it ? it.name : id.to_s].map { |w| w.to_s.downcase }
      return words.any? { |w| w.start_with?(q) || w.split(/[\s\-]+/).any? { |part| part.start_with?(q) } }
    end

    #--------------------------------------------------------------------------
    # Input
    #--------------------------------------------------------------------------
    def handle_input
      return moving_input if @moving
      return search if Input.trigger?(Input::JUMPUP) || Input.trigger?(Input::SPECIAL) || clicked?(*SEARCH_BOX)
      return next_view if Input.trigger?(Input::JUMPDOWN) || clicked?(*SORT_BOX)
      handled, result = mouse_input
      return result if handled
      if Input.trigger?(Input::BACK)
        return back
      elsif Input.trigger?(Input::USE)
        return choose
      elsif Input.trigger?(Input::X) && @kr_full && current
        favorite(current)
      elsif Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)
        step_pocket(Input.trigger?(Input::RIGHT) ? 1 : -1)
      elsif Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)
        step_row(Input.repeat?(Input::DOWN) ? 1 : -1)
      end
      return :stay
    end

    def choose
      id = current
      unless id
        pbPlayBuzzerSE
        return :stay
      end
      pbPlayDecisionSE
      remember
      @kr_menu_item = id if @kr_full
      return id
    end

    def back
      if @query
        pbPlayCancelSE
        @query = nil
        build_rows
        choose_saved
        draw
        return :stay
      end
      pbPlayCloseMenuSE
      remember
      return nil
    end

    def step_row(dir)
      n = @rows.length
      return if n == 0
      target = @sel
      loop do
        target += dir
        if target < 0 || target >= n
          return unless fresh?(dir)
          target = dir < 0 ? n - 1 : 0
        end
        break unless @rows[target][0] == :heading
      end
      return if target == @sel
      @sel = target
      pbPlayCursorSE
      remember
      draw
    end

    def step_pocket(dir)
      return pbPlayBuzzerSE if @query
      to = next_pocket(@pocket, dir)
      return if to == @pocket
      set_pocket(to)
    end

    def set_pocket(to)
      B.seen!(@pocket, @bag) if @kr_full
      @pocket = to
      @sel = 0
      build_rows
      choose_saved
      remember
      pbPlayCursorSE
      draw
    end

    # R: the next view of this pocket (the screen's order only)
    def next_view
      if @query
        pbPlayBuzzerSE
        return :stay
      end
      B.set_view(@pocket, B.view(@pocket) + 1)
      id = current
      build_rows
      @sel = @rows.index { |r| r[0] == :item && r[1] == id } || 0
      pbPlayCursorSE
      draw
      return :stay
    end

    def favorite(id)
      return pbPlayBuzzerSE unless @kr_full
      B.toggle_favorite(id)
      pbPlayDecisionSE
      build_rows
      @sel = @rows.index { |r| r[0] == :item && r[1] == id } || 0
      draw
    end

    # Search: typed into the header, every pocket's matches under headings
    def search
      pbPlayDecisionSE
      before = current
      text, _how = Reloaded::TextEntry.run(self, _INTL("Type to Search"), @query || "", 20,
                                           :prompt => _INTL("Search the Bag"), :down => true) do |t|
        @query = t.strip.empty? ? nil : t.strip
        @sel = 0
        build_rows
      end
      @query = text.to_s.strip.empty? ? nil : text.strip
      build_rows
      if @query.nil?
        @sel = @rows.index { |r| r[0] == :item && r[1] == before } || 0
      end
      draw
      return :stay
    end

    # Move (an Off or Custom List pocket): Up and Down carry the item, A puts
    # it down, B puts it back
    def start_move(id)
      i = B.slots(@bag, @pocket).index { |s| s && s[0] == id }
      return pbPlayBuzzerSE unless i
      @moving = [id, i]
      build_rows
      @sel = i
    end

    def moving_input
      id, from = @moving
      at = B.slots(@bag, @pocket).index { |s| s && s[0] == id } || from
      if Input.trigger?(Input::USE) || Input.trigger?(Input::ACTION)
        pbPlayDecisionSE
        finish_move
      elsif Input.trigger?(Input::BACK)
        pbPlayCancelSE
        B.move(@pocket, at, from, @bag) if at != from
        finish_move
      elsif Input.repeat?(Input::DOWN) || Input.repeat?(Input::UP)
        to = at + (Input.repeat?(Input::DOWN) ? 1 : -1)
        if to.between?(0, B.slots(@bag, @pocket).length - 1) && B.move(@pocket, at, to, @bag)
          pbPlayCursorSE
          build_rows
          @sel = to
          draw
        end
      end
      return :stay
    end

    def finish_move
      id = @moving[0]
      @moving = nil
      build_rows
      @sel = @rows.index { |r| r[0] == :item && r[1] == id } || 0
      remember
      draw
    end

    # Teach (a TM with the TM Vault on): the Vault on that move (his pick)
    def teach(id)
      it = B.item_data(id)
      hidden { Reloaded::TMVault.open(tab: :vault, focus: it.move) }
      make_icons
    end

    def teach?(it)
      return machine?(it) && defined?(Reloaded::TMVault) && Reloaded::TMVault.on? && defined?(Reloaded::TMVaultScreen)
    end

    # KIF 1.2.6's TM Search (C-ITEM-01_TMSearch): its Who Can Learn and
    # Search TMs, which it adds to the game's Bag menu, in this one's too,
    # with Teach (his pick, 2026-10-26). They open KIF's own screens.
    def tm_search?(it)
      return false unless defined?(::KIF::TMSearch) && ::KIF::TMSearch.respond_to?(:show) && ::KIF::TMSearch.respond_to?(:search)
      return machine?(it)
    end

    def tm_search(how, id)
      it = B.item_data(id)
      hidden { how == :show ? ::KIF::TMSearch.show(it.id) : ::KIF::TMSearch.search }
      make_icons
    end

    # Which of the game's commands is its Use (a machine's)
    def use_index(item, commands)
      text = defined?(::ItemHandlers) && ::ItemHandlers.hasUseText(item) ? ::ItemHandlers.getUseText(item) : _INTL("Use")
      return commands.index { |c| c.to_s == text.to_s }
    rescue StandardError
      return commands.index { |c| c.to_s == _INTL("Use") }
    end

    # What one of the game's actions does (another mod's: nothing said)
    def game_note(label, it, use)
      if use
        field = it && it.respond_to?(:field_use) ? it.field_use.to_i : 0
        return _INTL("Use it on a Pokémon.") if [1, 5].include?(field)
        return _INTL("Use it now.")
      end
      case label
      when _INTL("Read") then return _INTL("Read the letter.")
      when _INTL("Give") then return _INTL("Give it to a Pokémon to hold.")
      when _INTL("Toss") then return _INTL("Throw some away.")
      when _INTL("Register") then return _INTL("Put it on the game's Ready Menu.")
      when _INTL("Deselect") then return _INTL("Take it off the game's Ready Menu.")
      when _INTL("Debug") then return _INTL("Change how many there are, or make a Mystery Gift.")
      end
      return ""
    end

    # A picker's [banner, A's word] (Reloaded::BagScreen.title); Berry soil
    # tells its mulch picker from its Berry one by what the picker takes
    def picker_title(t)
      if t == :soil
        mulch = nil
        ::GameData::Item.each { |it| (mulch = it.id) && break if it.respond_to?(:is_mulch?) && it.is_mulch? } rescue nil
        takes = mulch && @filterproc ? (@filterproc.call(mulch) rescue false) : false
        return takes ? [_INTL("Scatter a Mulch"), _INTL("Scatter")] : [_INTL("Plant a Berry"), _INTL("Plant")]
      end
      return [t.to_s, _INTL("Select")] if t.is_a?(String)
      return t if t.is_a?(Array)
      return [_INTL("Choose an Item"), _INTL("Select")]
    end

    # A popup's own hints on the hint line while it shows
    def with_hints(pairs)
      before = @popup_hints
      @popup_hints = pairs
      draw if @sprite && !@sprite.disposed?
      return yield
    ensure
      @popup_hints = before
    end

    def menu_hints
      return [[:ud, _INTL("Choose")], [button(:C), _INTL("Pick")], [button(:B), _INTL("Back")]]
    end

    #--------------------------------------------------------------------------
    # Toss (his pick: the number with the item, Keep first, a toast)
    #--------------------------------------------------------------------------
    def stay_words(left)
      return _INTL("None stay in the Bag.") if left <= 0
      return _INTL("1 stays in the Bag.") if left == 1
      return _INTL("{1} stay in the Bag.", left)
    end

    def item_words(it, n)
      return n > 1 && it.respond_to?(:name_plural) ? it.name_plural : it.name
    end

    def toss_number(item, max)
      hints = [[:lr, _INTL("One")], [:ud, _INTL("Ten")], [button(:C), _INTL("Toss")], [button(:B), _INTL("Cancel")]]
      return with_hints(hints) do
        Reloaded::Dialogs.number(self, _INTL("Toss How Many?"), 1, 1, max, 1, "", :icon => item,
                                 :note => proc { |n| stay_words(max - n) })
      end
    end

    def toss_question(item, n)
      it = B.item_data(item)
      left = quantity(item) - n
      hints = [[:lr, _INTL("Choose")], [button(:C), _INTL("OK")], [button(:B), _INTL("Keep")]]
      choice = with_hints(hints) do
        Reloaded::Dialogs.ask(self, _INTL("Toss {1} {2}?", n, item_words(it, n)),
                              n > 1 ? _INTL("You can't get them back.") : _INTL("You can't get it back."),
                              [[stay_words(left), palette[:dim]]], [_INTL("Toss"), _INTL("Keep")], 1)
      end
      return choice == 0
    end

    # Said before the game takes them away: what's left after
    def tossed(item, n)
      it = B.item_data(item)
      left = quantity(item) - n
      Reloaded::Toast.show(_INTL("Tossed {1} {2}", n, item_words(it, n)), :icon => item,
                           :pill => left > 0 ? [_INTL("{1} LEFT", left), :gold] : nil)
    end

    #--------------------------------------------------------------------------
    # Quick Items (the Overworld Menu's; his pick: the first empty slot)
    #--------------------------------------------------------------------------
    def quick_ok?(item)
      om = defined?(Reloaded::OverworldMenu) ? Reloaded::OverworldMenu : nil
      return om && om.on? && om.respond_to?(:add_quick_item) && om.quick_item?(item) ? true : false
    rescue StandardError
      return false
    end

    def add_quick(item)
      om = Reloaded::OverworldMenu
      slot = om.add_quick_item(item)
      unless slot
        slot = choose_slot(item)
        return unless slot
        om.set_quick_item(slot, item)
      end
      Reloaded::Toast.show(_INTL("Quick Items: {1}", display_name(item)), :icon => item, :pill => [_INTL("SLOT {1}", slot + 1), :gold])
    end

    def remove_quick(item)
      slot = Reloaded::OverworldMenu.remove_quick_item(item)
      Reloaded::Toast.show(_INTL("Removed From Quick Items: {1}", display_name(item)), :icon => item) if slot
    end

    # Every slot full: a row of them, the one picked replaced (Left/Right,
    # A replaces, B keeps them all)
    def choose_slot(item)
      slots = Reloaded::OverworldMenu.quick_items
      sel = 0
      hints = [[:lr, _INTL("Slot")], [button(:C), _INTL("Replace")], [button(:B), _INTL("Cancel")]]
      with_hints(hints) do
        redraw = true
        loop do
          draw_slots(slots, sel, item) if redraw
          redraw = false
          Graphics.update
          Input.update
          pbUpdate
          pt = Reloaded::Pointer
          if pt.moved? && (i = Reloaded::Dialogs.hit) && i != sel
            sel = i
            pbPlayCursorSE
            redraw = true
          end
          if pt.left? && (i = Reloaded::Dialogs.hit)
            pbPlayDecisionSE
            return i
          elsif pt.right? || Input.trigger?(Input::BACK)
            pbPlayCancelSE
            return nil
          elsif Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)
            sel = (sel + (Input.repeat?(Input::LEFT) ? -1 : 1)) % slots.length
            pbPlayCursorSE
            redraw = true
          elsif Input.trigger?(Input::USE)
            pbPlayDecisionSE
            return sel
          end
        end
      end
    ensure
      overlay.clear if overlay && !overlay.disposed?
    end

    def draw_slots(slots, sel, item)
      b = overlay
      c = palette
      w = 320
      h = 148
      x = (W - w) / 2
      y = (H - h) / 2
      Reloaded::Dialogs.frame(b, c, x, y, w, h, _INTL("Replace Which Slot?"))
      s = 32
      step = 40
      sx = x + (w - (slots.length * step - (step - s))) / 2
      hits = []
      slots.each_with_index do |id, i|
        bx = sx + i * step
        on = i == sel
        P.ui.rbox(b, bx, y + 46, bx + s, y + 46 + s, 4, on ? mix(c[:selb], c[:panel2], 0.55) : c[:panel], on ? c[:selb] : c[:line])
        item_icon(b, id, bx + (s - 24) / 2, y + 46 + (s - 24) / 2, 24) if id
        P.text(b, bx, y + 80, s, 12, (i + 1).to_s, on ? c[:txt] : c[:dim], PF::TINY, 2)
        hits << [i, bx, y + 46, bx + s, y + 46 + s]
      end
      Reloaded::Dialogs.hits = hits
      old = slots[sel]
      label = old ? _INTL("Slot {1}: {2}", sel + 1, display_name(old)) : _INTL("Slot {1}", sel + 1)
      P.text(b, x, y + 96, w, 22, PF.fit(PF::TEXT, label, w - 20), c[:txt], PF::TEXT, 2)
      P.small(b, x, y + 120, w, 16, _INTL("{1} goes in its place.", display_name(item)), c[:dim], 2)
    end

    # The mouse: pointing at a row picks it; a click on a row chooses it, on
    # a pocket opens it; the wheel scrolls; a right click goes back
    def mouse_input
      pt = Reloaded::Pointer
      if pointer_hover && !@entry && (k = pt.hit(@row_hits || [])) && k != @sel
        @sel = k
        remember
        draw
      end
      return [true, back] if pt.right?
      dir = pt.wheel
      if dir != 0
        step_row(dir)
        return [true, :stay]
      end
      return [false, nil] unless pt.left?
      handled, result = hint_click
      return [true, result] if handled
      if (p = pt.hit(@pocket_hits || []))
        set_pocket(p) if p != @pocket && usable?(p) && @query.nil?
        return [true, :stay]
      elsif (k = pt.hit(@row_hits || []))
        @sel = k
        return [true, choose]
      end
      return [true, :stay]
    end

    def hint_back
      return back
    end

    def hint_choose
      return choose
    end

    def hint_favorite
      favorite(current) if current
      return :stay
    end

    def left_box
      return SEARCH_BOX
    end

    def right_box
      return SORT_BOX
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
      @dots = []
      PP.paint_background(base, c)
      draw_header(base, top, c)
      draw_pockets(base, top, c)
      draw_list(base, top, c)
      draw_details(base, top, c)
      flush_dots
      paint_hints(base, c)
      place_cursor
    end

    def draw_header(base, top, c)
      if @entry
        Reloaded::TextEntry.draw_field(base, top, c, @entry, 8, 4, W - 16, 23, 26)
        magnifier(base, 15, c[:txt], c[:dark])
        return
      end
      PP.paint_title(top, c, _INTL("Bag"))
      x0, y0, x1, y1 = SEARCH_BOX
      lit = @query || @hover_box == :left
      PP.chamfer_grad(base, x0, y0, x1, y1, 6, mix(c[:panel2], c[:selb], lit ? 0.4 : 0.15), c[:panel2], lit ? c[:selb] : c[:line])
      P.text(top, x0 + 8, y0 + 1, x1 - x0 - 12, 20, PF.fit(PF::TEXT, @query || _INTL("Search"), x1 - x0 - 12), @query ? c[:txt] : c[:dim], PF::TEXT)
      Reloaded::ButtonIcons.draw(top, x1 + 4, 6, left_key, c, Reloaded::Prompts.style, 18)
      x0, y0, x1, y1 = SORT_BOX
      lit = @hover_box == :right
      PP.chamfer_grad(base, x0, y0, x1, y1, 6, mix(c[:panel2], c[:selb], lit ? 0.4 : 0.15), c[:panel2], lit ? c[:selb] : c[:line])
      label = PF.fit(PF::TEXT, _INTL("Sort: {1}", _INTL(B::VIEWS[B.view(@pocket)])), x1 - x0 - 10)
      P.text(top, x0, y0 + 1, x1 - x0, 20, label, c[:txt], PF::TEXT, 2)
      key = right_key
      Reloaded::ButtonIcons.draw(top, x0 - 4 - Reloaded::ButtonIcons.width(key, Reloaded::Prompts.style, 18), 6, key, c, Reloaded::Prompts.style, 18)
    end

    # The pockets' icons (faint when nothing in them fits), the open one lit,
    # NEW dots; its name between arrows
    def draw_pockets(base, top, c)
      @pocket_hits = []
      B.pockets.each do |i|
        x = 10 + (i - 1) * 32
        on = @query.nil? && i == @pocket
        if on
          PP.chamfer_grad(base, x - 3, BAR_Y - 1, x + 31, BAR_Y + 29, 6, mix(c[:panel2], c[:selb], 0.55),
                          mix(c[:panel2], c[:selb], 0.25), c[:selb])
        end
        faint = @query ? @rows.none? { |r| r[0] == :heading && r[1] == i } : !usable?(i)
        pocket_icon(top, i, x, BAR_Y, 28, faint)
        new_dot(top, c, x + 26, BAR_Y + 3) if B.pocket_new?(i, @bag)
        @pocket_hits << [i, x - 3, BAR_Y - 1, x + 31, BAR_Y + 29]
      end
      label = @query ? _INTL("Every Pocket") : B.pocket_name(@pocket)
      lw = P.width(PF::TEXT, label)
      rx = W - 22
      P.ui.tri(top, rx + 4, BAR_Y + 9, :r, c[:dim], 5)
      P.text(top, rx - 4 - lw, BAR_Y + 2, lw, 24, label, c[:txt], PF::TEXT)
      P.ui.tri(top, rx - 18 - lw, BAR_Y + 9, :l, c[:dim], 5)
    end

    # A pocket's NEW dot, drawn after every icon (so the next one never
    # hides it)
    def new_dot(b, c, cx, cy)
      @dots << [b, c, cx, cy]
    end

    def flush_dots
      @dots.each do |b, c, cx, cy|
        PP.disc(b, cx, cy, 4, c[:light] ? PP::WHITE : c[:dark])
        PP.disc(b, cx, cy, 3, c[:green])
      end
      @dots = []
    end

    def row_height(r)
      return r[0] == :heading ? HEAD_H : ROW_H
    end

    # A picker's banner across the list's top: what's being chosen (his
    # pick, popup 5)
    def draw_banner(base, top, c)
      x0 = 8
      y0 = LIST_Y0 + 2
      x1 = W - 8
      PP.chamfer_grad(base, x0, y0, x1, y0 + BANNER_H - 2, 6, mix(c[:panel2], c[:acc], 0.45), mix(c[:panel2], c[:acc], 0.2), c[:selb])
      words = @kr_title[0].to_s.upcase
      P.text(top, x0, y0 + 2, x1 - x0, 16, PF.fit(PF::TINY, words, x1 - x0 - 16), c[:strong], PF::TINY, 2)
    end

    def draw_list(base, top, c)
      PP.chamfer_grad(base, 6, LIST_Y0, W - 6, LIST_Y1, 10, c[:panel2], mix(c[:panel2], c[:dark], 0.3), c[:line])
      @row_hits = []
      y0 = LIST_Y0
      if @kr_title
        draw_banner(base, top, c)
        y0 += BANNER_H
      end
      if @rows.empty?
        msg = @query ? _INTL("Nothing matches \"{1}\".", @query) : (@choosing ? _INTL("Nothing here can be used for this.") : _INTL("Nothing in your Bag yet."))
        P.small(top, LIST_X, y0 + 8, LIST_W, 16, msg, c[:dim])
        return
      end
      space = (LIST_Y1 - y0 - 4)
      space -= space % ROW_H
      @scroll = [[@scroll.to_i, @sel].min, 0].max
      @scroll += 1 while @scroll < @sel && @rows[@scroll..@sel].sum { |r| row_height(r) } > space
      @scroll -= 1 while @scroll > 0 && @rows[@scroll - 1][0] == :heading && @rows[(@scroll - 1)..@sel].sum { |r| row_height(r) } <= space
      total = @rows.sum { |r| row_height(r) }
      y = y0 + 2
      shown = 0
      @rows[@scroll..-1].to_a.each_with_index do |r, k|
        h = row_height(r)
        break if y + h > y0 + 2 + space
        break if r[0] == :heading && y + h + ROW_H > y0 + 2 + space     # no heading alone at the bottom
        shown += h
        if r[0] == :heading && r[1].is_a?(String)
          section_heading(top, c, y, r[1])
        elsif r[0] == :heading
          pocket_icon(top, r[1], LIST_X, y, 16)
          P.heading(top, LIST_X + 20, LIST_X + LIST_W, y + 2, B.pocket_name(r[1]), c[:head], c[:line])
        else
          i = @scroll + k
          @cursor_rect = [LIST_X - 4, y, LIST_W + 8, ROW_H - 1] if i == @sel && !@entry
          item_row(top, c, LIST_X, y, LIST_W, r)
          @row_hits << [i, LIST_X, y, LIST_X + LIST_W, y + ROW_H - 1]
        end
        y += h
      end
      return unless total > space
      track = space - 2
      bar = [track * space / total, 10].max
      above = @rows[0...@scroll].sum { |r| row_height(r) }
      pos = (track - bar) * above / [total - shown, 1].max
      base.fill_rect(LIST_X + LIST_W + 6, y0 + 2, 2, track, c[:line])
      base.fill_rect(LIST_X + LIST_W + 6, y0 + 2 + [pos, track - bar].min, 2, bar, c[:dim])
    end

    # One of a Custom List's headings: small capitals and a line, as the
    # Custom List editor's (his pick, 2026-10-23: Like the Editor)
    def section_heading(top, c, y, name)
      P.heading(top, LIST_X, LIST_X + LIST_W, y + 2, name, c[:head], c[:line])
    end

    def item_row(top, c, x, y, w, r)
      _k, id, qty = r
      it = B.item_data(id)
      PP.pixels(top, PP::STAR, x, y + (ROW_H - 7) / 2, c[:gold]) if B.favorite?(id)
      nx = x + 11
      right = x + w
      if machine?(it)
        small_type(top, ::GameData::Move.get(it.move).type, right - 16, y + (ROW_H - 16) / 2)
        right -= 20
        lw = P.width(PF::TINY, it.name)
        P.text(top, right - lw, y + (ROW_H - 16) / 2 + 1, lw, 16, it.name, c[:dim], PF::TINY)
        right -= lw + 8
      else
        item_icon(top, id, right - 24, y, 24)
        right -= 30
        unless it && it.respond_to?(:is_important?) && it.is_important?
          qt = "x#{qty}"
          qw = P.width(PF::TEXT, qt)
          P.text(top, right - qw, y + 1, qw, ROW_H - 2, qt, c[:dim], PF::TEXT)
          right -= qw + 8
        end
      end
      # Moving (the Party Screen's Switch look, as the Custom List editor's):
      # a gold edge and MOVING
      moving = @moving && @moving[0] == id
      if moving
        PP.chamfer_outline(top, x - 5, y - 1, x + w + 5, y + ROW_H, 6, c[:gold])
        right -= P.pill(top, right, y + (ROW_H - 15) / 2, _INTL("MOVING"), *PP.badge(c, [240, 200, 80]), true) + 8
      end
      room = right - nx
      fresh = B.new?(id)
      held = !holders(id).empty?
      room -= P.width(PF::TINY, _INTL("NEW")) + 18 if fresh
      room -= P.width(PF::TINY, _INTL("HELD")) + 18 if held
      col = item_ink(c, id)
      nw = P.text(top, nx, y + 1, room, ROW_H - 2, PF.fit(PF::TEXT, display_name(id), room), col, PF::TEXT)
      px = nx + nw + 6
      px += pill(top, c, px, y + (ROW_H - 15) / 2, _INTL("NEW"), :green) + 6 if fresh
      pill(top, c, px, y + (ROW_H - 15) / 2, _INTL("HELD"), :gold) if held
    end

    #--------------------------------------------------------------------------
    # The details
    #--------------------------------------------------------------------------
    def draw_details(base, top, c)
      @icons.each { |s| s.visible = false if s }
      id = current
      return unless id
      it = B.item_data(id)
      return unless it
      py0 = DETAILS_Y
      py1 = H - P::HINT_H - 5
      plate(base, c, PP.rgb(item_rgb(id)), 6, py0, W - 6, py1, 12)
      if machine?(it) || stone?(it) || heal_kind(id) || plate_type(id) || ev_reset?(id)
        party_details(top, c, py0, id, it)
      else
        P.text(top, 18, py0 + 5, 300, 22, PF.fit(PF::ROW, it.name, 340), c[:strong], PF::ROW)
        pw = use_pills(top, c, 18, py0 + 32, it)
        slot = quick_slot(id)
        pw += pill(top, c, 18 + pw, py0 + 32, _INTL("QUICK SLOT {1}", slot), :amber) + 6 if slot
        who = holders(id)
        pill(top, c, 18 + pw, py0 + 32, _INTL("HELD"), :gold) unless who.empty?
        desc_lines(top, it.description.to_s, 360, who.empty? ? 3 : 2).each_with_index { |ln, i| P.small(top, 18, py0 + 52 + i * 16, 360, 16, ln, c[:txt]) }
        held_by(top, c, 18, py0 + 86, who) unless who.empty?
        P.ui.rbox(base, W - 92, py0 + 8, W - 18, py0 + 70, 6,
                  c[:light] ? mix(c[:panel2], PP::WHITE, 0.5) : mix(c[:dark], c[:panel], 0.3), c[:line])
        item_icon(top, id, W - 79, py0 + 15, 48)
      end
    end

    # A TM or HM (its move), or an Evolution Stone: who in the party can use
    # it (his pick, 2026-10-23)
    def party_details(top, c, py0, id, it)
      if machine?(it)
        d = ::GameData::Move.get(it.move)
        nw = P.text(top, 18, py0 + 5, 220, 22, PF.fit(PF::ROW, d.name, 220), c[:strong], PF::ROW)
        P.text(top, 18 + nw + 8, py0 + 9, 60, 16, it.name, c[:dim], PF::TINY)
        dy = move_badges(top, c, 18, py0 + 32, d, 282)
        desc_lines(top, d.description.to_s, 282, 3 - dy / 20).each_with_index { |ln, i| P.small(top, 18, py0 + 52 + dy + i * 15, 282, 15, ln, c[:txt]) }
      else
        P.text(top, 18, py0 + 5, 280, 22, PF.fit(PF::ROW, it.name, 280), c[:strong], PF::ROW)
        pw = use_pills(top, c, 18, py0 + 32, it)
        pill(top, c, 18 + pw, py0 + 32, _INTL("HELD"), :gold) unless holders(id).empty?
        desc_lines(top, it.description.to_s, 282, 3).each_with_index { |ln, i| P.small(top, 18, py0 + 52 + i * 15, 282, 15, ln, c[:txt]) }
      end
      if heal_kind(id)
        heal_grid(top, c, 308, py0 + 6, id)
      elsif (to = plate_type(id))
        plate_grid(top, c, 308, py0 + 6, to)
      elsif ev_reset?(id)
        evs_grid(top, c, 308, py0 + 6)
      else
        party_grid(top, c, 308, py0 + 6, 3, 64, 50, 26, it)
      end
    end

    # A plate (Hidden Power): the type it sets, or nil
    def plate_type(id)
      return nil unless defined?(Reloaded::HiddenPower::Plates)
      return Reloaded::HiddenPower::Plates.type_of(id)
    end

    # The Fresh-Start Mochi (Critical EV Gain): it resets EVs
    def ev_reset?(id)
      return defined?(Reloaded::CriticalEVGain::Mochi) && id.to_s == Reloaded::CriticalEVGain::Mochi::ID.to_s
    end

    # Each Pokémon's EVs in all; "No EVs" where the Mochi would change
    # nothing (his pick, Party Grid)
    def evs_grid(top, c, x, y)
      party.each_with_index do |p, i|
        cx = x + (i % 3) * 64 + 32
        cy = y + (i / 3) * 50
        fit_icon(i, cx, cy + 14, 26)
        n = p.egg? ? 0 : Reloaded::CriticalEVGain::Mochi.total(p)
        word, col = if p.egg? then [_INTL("Egg"), c[:dim]]
                    elsif n == 0 then [_INTL("No EVs"), c[:dim]]
                    else [_INTL("{1} EVs", n), c[:txt]]
                    end
        P.text(top, cx - 32, cy + 28, 64, 12, word, col, PF::TINY, 2)
      end
    end

    # Each Pokémon's Hidden Power type now, in its colour; "Already Ice"
    # where the plate would change nothing (his pick, Q11 Design 1)
    def plate_grid(top, c, x, y, to)
      party.each_with_index do |p, i|
        cx = x + (i % 3) * 64 + 32
        cy = y + (i / 3) * 50
        fit_icon(i, cx, cy + 14, 26)
        if p.egg?
          word, col = _INTL("Egg"), c[:dim]
        elsif Reloaded::HiddenPower.unown?(p)
          word, col = _INTL("Neutral"), c[:dim]
        elsif (t = Reloaded::HiddenPower.type_of(p)) == to
          word, col = _INTL("Already {1}", ::GameData::Type.get(to).name), c[:dim]
        else
          word, col = ::GameData::Type.get(t).name, PP.ink(c, Reloaded::PartyScreen.type_rgb(t))
        end
        P.text(top, cx - 32, cy + 28, 64, 12, word, col, PF::TINY, 2)
      end
    end

    #--------------------------------------------------------------------------
    # Who Needs It (his pick: Party Grid): each Pokémon's icon, its HP and a
    # word for what the item would do
    #--------------------------------------------------------------------------
    def heal_kind(id)
      return HEAL_KINDS[id.to_s.to_sym]
    end

    def heal_grid(top, c, x, y, id)
      kind = heal_kind(id)
      party.each_with_index do |p, i|
        cx = x + (i % 3) * 64 + 32
        cy = y + (i / 3) * 52
        fit_icon(i, cx, cy + 12, 24)
        unless p.egg?
          PP.bar(top, c, cx - 18, cy + 27, 36, p.hp.to_f / [p.totalhp, 1].max, PP.hp_colour(c, p), 3)
        end
        word, tone = heal_word(p, kind)
        P.text(top, cx - 32, cy + 33, 64, 12, word, c[tone] || c[:dim], PF::TINY, 2)
      end
    end

    def heal_word(p, kind)
      return [_INTL("Egg"), :dim] if p.egg?
      fainted = p.hp.to_i <= 0
      status = (p.status rescue :NONE)
      status = :NONE if status.nil?
      case kind
      when :revive
        return fainted ? [_INTL("Can Revive"), :green] : [_INTL("Not Fainted"), :dim]
      when :hp
        return [_INTL("Fainted"), :red] if fainted
        return p.hp >= p.totalhp ? [_INTL("Full HP"), :dim] : [_INTL("Can Heal"), :green]
      when :restore
        return [_INTL("Fainted"), :red] if fainted
        return p.hp < p.totalhp || status != :NONE ? [_INTL("Can Heal"), :green] : [_INTL("Healthy"), :dim]
      when :pp
        low = (p.moves rescue []).any? { |m| m && m.respond_to?(:pp) && m.pp.to_i < m.total_pp.to_i }
        return low ? [_INTL("Can Restore"), :green] : [_INTL("Full PP"), :dim]
      end
      return [_INTL("Fainted"), :dim] if fainted
      return [_INTL("Healthy"), :dim] if status == :NONE
      cures = kind == :status || Array(kind).include?(status)
      return cures ? [_INTL("Can Cure"), :green] : [_INTL("Can't Cure"), :dim]
    end

    #--------------------------------------------------------------------------
    # Held Items (his pick: a HELD pill, and who holds it)
    #--------------------------------------------------------------------------
    def holders(id)
      return party.select do |p|
        next false if p.egg?
        held = p.respond_to?(:item_id) ? p.item_id : (p.item.respond_to?(:id) ? p.item.id : p.item)
        held && held.to_s == id.to_s
      end
    rescue StandardError
      return []
    end

    # "Held by:" then each holder's icon and name
    def held_by(top, c, x, y, who)
      label = _INTL("Held by:")
      P.small(top, x, y, 80, 16, label, c[:dim])
      P.small_font(top)
      hx = x + top.text_size(label).width + 8
      who.first(3).each do |p|
        i = party.index(p)
        fit_icon(i, hx + 9, y + 8, 18) if i
        P.small(top, hx + 20, y, 120, 16, p.name, c[:txt])
        P.small_font(top)
        hx += 20 + top.text_size(p.name).width + 12
      end
    end

    def move_badges(top, c, x, y, d, w)
      bx = x
      by = y
      bx += big_type(top, d.type, bx, by - 1) + 4
      bx += big_category(top, d.category, bx, by - 1) + 6
      [_INTL("POW {1}", d.base_damage.to_i > 1 ? d.base_damage : "--"), _INTL("ACC {1}", d.accuracy.to_i > 0 ? d.accuracy : "--"),
       _INTL("PP {1}", d.total_pp)].each do |label|
        pw = P.width(PF::TINY, label) + 12
        if bx + pw > x + w
          bx = x
          by += 20
        end
        P.pill(top, bx, by, label, c[:pill], c[:txt], false)
        bx += pw + 6
      end
      return by - y
    end

    # The party: what each can do with a TM's move, or an Evolution Stone
    def party_grid(top, c, x, y, cols, cw, ch, icon_box, it)
      party.each_with_index do |p, i|
        cx = x + (i % cols) * cw + cw / 2
        cy = y + (i / cols) * ch
        fit_icon(i, cx, cy + icon_box / 2 + 1, icon_box)
        word, tone = party_word(p, it)
        P.text(top, cx - cw / 2, cy + icon_box + 2, cw, 12, word, c[tone] || c[:dim], PF::TINY, 2)
      end
    end

    def party_word(p, it)
      return [_INTL("Egg"), :dim] if p.egg?
      if machine?(it)
        how = if defined?(Reloaded::TMVault) then Reloaded::TMVault.compat(it.move, p)
              elsif p.hasMove?(it.move) then :knows
              else (p.compatible_with_move?(it.move) rescue false) ? :learn : :cant
              end
        word, tone = CHECK_WORDS[how]
        return [_INTL(word), tone]
      end
      can = (p.check_evolution_on_use_item(it.id) rescue nil)
      return can ? [_INTL("Can Evolve"), :green] : [_INTL("Can't"), :dim]
    end

    #--------------------------------------------------------------------------
    # The party's icons (Big Pokémon Icons as the player has them)
    #--------------------------------------------------------------------------
    def party
      return ($Trainer && $Trainer.party ? $Trainer.party : []).compact.first(6)
    end

    def make_icons
      dispose_icons
      @icons = party.map { |p| Reloaded::PartyIcons.icon(p, @viewport, 2) }   # under the popups (the overlay is 3)
      @icon_rects = @icons.map { |s| s && s.bitmap ? Reloaded::PartyIcons.art_rect(s.bitmap, [s.src_rect.height, 1].max) : nil }
      @icons.each { |s| s.visible = false if s }
    end

    def fit_icon(i, cx, cy, box)
      s = @icons[i]
      r = (@icon_rects || [])[i]
      return unless s && r && !s.disposed?
      s.zoom_x = s.zoom_y = box.to_f / [r.width, r.height, 1].max
      s.ox = r.x + r.width / 2
      s.oy = r.y + r.height / 2
      s.x = cx
      s.y = cy
      s.visible = true
    end

    def dispose_icons
      (@icons || []).each { |s| s.dispose if s && !s.disposed? }
      @icons = []
      @icon_rects = []
    end

    def sprites
      return super + (@icons || []).compact.reject(&:disposed?)
    end

    #--------------------------------------------------------------------------
    # The hint line
    #--------------------------------------------------------------------------
    def hint_pairs
      return @popup_hints if @popup_hints
      back = button(:B)
      return [[button(:C), _INTL("Type")], [back, _INTL("Done")]] if @entry
      return [[:ud, _INTL("Move")], [button(:C), _INTL("Done")], [back, _INTL("Cancel")]] if @moving
      out = [[:ud, _INTL("Choose")]]
      out << [:lr, _INTL("Pockets")] if @query.nil? && B.pockets.count { |p| usable?(p) } > 1
      out << [button(:C), @kr_full ? _INTL("Actions") : (@kr_title ? @kr_title[1] : _INTL("Select")), :hint_choose] if current
      out << [button(:X), _INTL("Favorite"), :hint_favorite] if @kr_full && current
      out << [back, @query ? _INTL("Clear") : (@choosing ? _INTL("Cancel") : _INTL("Close")), :hint_back]
      return out
    end
  end
end
