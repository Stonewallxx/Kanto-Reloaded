#==============================================================================
# Kanto Reloaded: the Overworld Menu
#==============================================================================
# Roadmap topic 35 (Tabbed Panel, chosen 2026-10-17; details agreed
# 2026-10-19): a quick menu you open while walking. One tall panel on the
# left with page tabs, entries with icons and live statuses, and the Quick
# Items bar; your party's cards at the bottom right and where you are at the
# top right (UI/OverworldMenuScreen.rb).
#
#   pages        Main, Toggles and Info, and pages of your own (the page
#                editor, UI/OverworldPagesScreen.rb); the same in every save:
#                <mod folder>\Settings\Overworld Menu.json
#   Quick Items  up to 7 items of your choosing, kept in each save
#   opens        its own Controls action, Overworld Menu: Select (tapped)
#                and F at first. Never during a cutscene, a message, or
#                where the game has the menu shut.
#
# Entries register here, each of a kind: :action, :toggle or :info. Main is
# the one built-in page: an action joins it the first time it's seen (one the
# player took off stays off). Toggles and readouts start on no page: the
# player puts the ones they want on Main or a page of their own (Edit Pages).
# An entry whose mod was removed stays in the layout, out of sight, in case
# it comes back.
#
#   Reloaded::OverworldMenu.register(:pokevial, :name => "PokeVial", :kind => :action,
#     :priority => 25, :feature => :pokevial,
#     :home => false,                         # an action that starts on no page
#     :condition => proc { ... },             # shown at all
#     :usable => proc { true or "why not" },   # dimmed, and says why, when not
#     :status => proc { ["3/5", :green] },    # words, and :green, :gold, :red, :dim or nil
#                                             # (INFINITY for the words: the gold ∞ mark)
#     :paint => proc { |b, x1, y, h, colours, room| width },   # or a status drawn
#                                             # its own way, ending at x1, in room
#                                             # (Badges' pips)
#     :label => proc { "..." },               # words of its own in place of its name
#     :alert => proc { true },                # glows red, pulsing, when it wants attention
#     :description => "...",
#     :handler => proc { |menu| ...; nil })   # nil: the menu stays; :close; or a
#                                             # proc to run once it has closed
#   A toggle:  :get => proc { on? }, :set => proc { |on| ... }   (A flips its switch)
#   A choice:  :values => ["Normal", "Fast"], :get => proc { index },
#              :set => proc { |index| ... },                      (A opens its dropdown)
#              :explain => proc { |index| "what this one does" }
#   A number:  :range => [lowest, highest, step, unit], :get => proc { value },
#              :set => proc { |value| ... }                       (A opens its slider)
#==============================================================================

module Reloaded
  module OverworldMenu
    FEATURE = :overworld_menu
    PARTY_VIEW = :"overworld_menu.party"         # Party View's look: Full or Compact
    FILE = "Overworld Menu.json"
    QUICK_MAX = 7
    PAGE_MAX = 7
    NAME_MAX = 16
    KINDS = [:action, :toggle, :info].freeze
    # The built-in pages: [id, name, the kind of entry that joins it]
    PAGES = [["main", "Main", :action]].freeze
    # Built-in until layout 2 (2026-10-20): [id, the kind it held]
    OLD_PAGES = [["toggles", :toggle], ["info", :info]].freeze
    LAYOUT_VERSION = 3
    INFINITY = :infinity          # a status's words: the gold ∞ mark (the pixel fonts have no ∞)

    Entry = Struct.new(:key, :name, :kind, :icon, :priority, :feature, :condition, :usable, :status,
                       :description, :handler, :get, :set, :values, :label, :home, :explain, :range, :paint, :alert)

    @entries = {}
    @session = 0

    class << self
      attr_reader :session        # wild Pokémon met this session

      def boot
        register_settings
        Reloaded::Features.register(FEATURE, :name => "Overworld Menu", :page => :overworld_menu, :order => 10,
          :description => "A quick menu you open while walking: Quick Items, quick toggles, your party and where you are.")
        if defined?(Reloaded::Controls) && Reloaded::Controls.respond_to?(:register)
          Reloaded::Controls.register(:overworld_menu, :name => "Overworld Menu", :area => :overworld, :group => "Menus",
            :keys => ["k:9"], :pad => ["p:4"], :priority => 140,
            :description => "Opens the Overworld Menu on the map.")
        end
        Reloaded::SaveStore.register(:overworld_menu)
        Reloaded::OverworldMenu::Entries.register_all if defined?(Reloaded::OverworldMenu::Entries)
        Reloaded::OverworldMenu::SettingRows.boot if defined?(Reloaded::OverworldMenu::SettingRows)
        install
        return true
      end

      def register_settings
        s = Reloaded::Settings
        s.register_page(:overworld_menu, :group => :general, :name => "Overworld Menu", :icon => :interface, :priority => 37,
          :description => "A quick menu you open while walking. Select or F opens it at first (Controls).")
        s.register(:"overworld_menu.pages", :page => :overworld_menu, :priority => 10, :type => :button, :preset => false,
          :name => "Edit Pages",
          :on_press => proc { Reloaded::OverworldPagesScreen.open if defined?(Reloaded::OverworldPagesScreen) },
          :description => "Add, rename and remove pages, and choose what's on each and in what order.")
        s.register(PARTY_VIEW, :page => :overworld_menu, :priority => 20, :type => :enum, :default => 1,
          :values => ["Full", "Compact"], :name => "Party View",
          :descriptions => ["Big cards down the right side, with each Pokémon's battle sprite, name, level, types, HP, status and held item.",
                            "Each Pokémon's name, HP and status at the bottom right, three to a row."],
          :description => "How Party View shows your party. Y in the menu switches between the views.")
      end

      # The game's classes are there in the game; outside it (tests, the
      # preview tool) each hook is made only when its target is.
      def install
        Reloaded::Hooks.prepend(nil, "Scene_Map", MapHooks, :id => :overworld_menu_open) if defined?(::Scene_Map)
        install_item_hooks
        if defined?(::Events) && ::Events.respond_to?(:onWildPokemonCreate) && !@counting
          @counting = true
          ::Events.onWildPokemonCreate += proc { |_sender, e| Reloaded::OverworldMenu.met((e[0] rescue nil)) }
        end
        return true
      end

      def on?
        return Reloaded::Features.on?(FEATURE)
      end

      #------------------------------------------------------------------------
      # Entries
      #------------------------------------------------------------------------
      def register(key, options = {})
        key = key.to_s
        kind = (options[:kind] || :action).to_sym
        kind = :action unless KINDS.include?(kind)
        @entries[key] = Entry.new(key, options[:name].to_s, kind, options[:icon], options[:priority] || 100,
                                  options[:feature], options[:condition], options[:usable], options[:status],
                                  options[:description].to_s, options[:handler], options[:get], options[:set], options[:values],
                                  options[:label], options[:home], options[:explain], options[:range], options[:paint],
                                  options[:alert])
        @layout_checked = false
        return key
      end

      # A registered entry, or a setting's row ("setting:..."), or nil.
      def entry(key)
        e = @entries[key.to_s]
        return e if e
        rows = defined?(Reloaded::OverworldMenu::SettingRows) ? Reloaded::OverworldMenu::SettingRows : nil
        return rows && rows.setting?(key) ? rows.entry(key) : nil
      end

      def entries
        return @entries.values.sort_by { |e| [KINDS.index(e.kind), e.priority, e.name] }
      end

      # Shown now: its feature is on and its condition holds.
      def shown?(e)
        return false if e.feature && !Reloaded::Features.on?(e.feature)
        return true unless e.condition
        return e.condition.call ? true : false
      rescue StandardError
        return false
      end

      # What its row says: its name, or words of its own (:label, the
      # Quest's name).
      def label(e)
        return e.name.to_s unless e.label
        text = e.label.call.to_s
        return text.empty? ? e.name.to_s : text
      rescue StandardError
        return e.name.to_s
      end

      # It wants attention now (its :alert says so)
      def alert?(e)
        return false unless e.alert
        return e.alert.call ? true : false
      rescue StandardError
        return false
      end

      # true, or why it can't be used now
      def usable(e)
        return true unless e.usable
        r = e.usable.call
        return r == true || r.nil? ? true : (r == false ? _INTL("You can't use that right now.") : r.to_s)
      rescue StandardError
        return _INTL("You can't use that right now.")
      end

      # [words, colour] or nil. Toggles: On (green) or Off (dim); choices:
      # the value; numbers: the value and its unit. The words can be
      # INFINITY (the menu draws the ∞ mark).
      def status(e)
        if e.values && e.get
          i = e.get.call.to_i
          return [_INTL(e.values[i].to_s), :gold]
        elsif e.range && e.get
          return ["#{e.get.call.to_i}#{e.range[3]}", :gold]
        elsif e.get
          return e.get.call ? [_INTL("On"), :green] : [_INTL("Off"), :dim]
        end
        return nil unless e.status
        s = e.status.call
        return nil if s.nil?
        words = s.is_a?(Array) ? s[0] : s
        words = words.to_s unless words == INFINITY
        return [words, s.is_a?(Array) ? s[1] : nil]
      rescue StandardError
        return nil
      end

      #------------------------------------------------------------------------
      # Views: what the right side shows (Y steps through them, then none)
      #------------------------------------------------------------------------
      # Party View is the menu's own; a feature adds one of its own (Weather
      # View, with the Weather System):
      #
      #   Reloaded::OverworldMenu.register_view(:weather, :name => "Weather View",
      #     :feature => :weather, :condition => proc { ... },
      #     :draw => proc { |menu, base, top, colours| ... })
      def register_view(key, options = {})
        @views ||= {}
        @views[key.to_s] = options.merge(:key => key.to_s)
        return key.to_s
      end

      # The views that can show now, in their order (Party View first).
      def views
        list = [{ :key => "party", :name => _INTL("Party View") }]
        (@views || {}).each_value do |v|
          next if v[:feature] && !Reloaded::Features.on?(v[:feature])
          next if v[:condition] && !(v[:condition].call rescue false)
          list << v
        end
        return list
      end

      # The view showing ("party", another view's key, or nil for none);
      # the same in every save.
      def view
        key = layout.has_key?("view") ? layout["view"] : "party"
        return nil if key.nil?
        return views.any? { |v| v[:key] == key } ? key : "party"
      end

      def view=(key)
        layout["view"] = key
        save_layout
      end

      # Y: the next view, then none, then the first again.
      def next_view
        keys = views.map { |v| v[:key] } + [nil]
        i = keys.index(view) || 0
        self.view = keys[(i + 1) % keys.length]
        return view
      end

      #------------------------------------------------------------------------
      # Pages (every save)
      #------------------------------------------------------------------------
      # { "pages" => [{ "id", "name", "entries" }], "seen" => [keys], "page" => index }
      def layout
        unless @layout
          text = Reloaded::Paths.read_text(layout_path)
          data = text ? (Reloaded::JSON.parse(text) rescue nil) : nil
          data = {} unless data.is_a?(Hash)
          pages = Array(data["pages"]).select { |p| p.is_a?(Hash) && !p["id"].to_s.empty? }.map do |p|
            { "id" => p["id"].to_s, "name" => p["name"].to_s, "entries" => Array(p["entries"]).map(&:to_s).uniq }
          end
          @layout = { "pages" => pages, "seen" => Array(data["seen"]).map(&:to_s), "page" => data["page"].to_i,
                      "version" => data["version"].to_i }
          @layout["view"] = data["view"] if data.has_key?("view")
          @layout_checked = false
          upgrade_layout
        end
        check_layout unless @layout_checked
        return @layout
      end

      def layout_path
        return File.join(Reloaded::Paths.settings_dir, FILE)
      end

      def save_layout
        Reloaded::Paths.write_atomic(layout_path, Reloaded::JSON.generate(@layout, true)) if @layout
      rescue StandardError => e
        Reloaded::Log.exception("The Overworld Menu's pages couldn't be saved", e, :overworld_menu)
      end

      def forget_layout
        @layout = nil
      end

      # Layout 2: Toggles and Info aren't built-in pages any more. Each goes
      # unless the player put something of another kind on it (then it stays,
      # as one of their own pages); its entries stay ready to add.
      # Layout 3: Time Changer moved up, below Quick Items (his call,
      # 2026-10-20), on a Main page that has both.
      def upgrade_layout
        return if @layout["version"] >= LAYOUT_VERSION
        if @layout["version"] < 2
          OLD_PAGES.each do |id, kind|
            page = @layout["pages"].find { |p| p["id"] == id }
            next unless page
            own = page["entries"].any? { |k| (e = entry(k)) && e.kind != kind }
            @layout["pages"].delete(page) unless own
          end
        end
        main = @layout["pages"].find { |p| p["id"] == "main" }
        list = main ? main["entries"] : []
        if @layout["version"] < 3 && list.include?("time_changer") && list.include?("quick_items")
          list.delete("time_changer")
          list.insert(list.index("quick_items") + 1, "time_changer")
        end
        @layout["version"] = LAYOUT_VERSION
        save_layout
      end

      # The built-in pages are there, and each entry not seen before joins
      # its kind's page (actions: Main), in its place by priority.
      def check_layout
        @layout_checked = true
        pages = @layout["pages"]
        changed = false
        PAGES.each_with_index do |(id, name, _kind), i|
          next if pages.any? { |p| p["id"] == id }
          pages.insert([i, pages.length].min, { "id" => id, "name" => name, "entries" => [] })
          changed = true
        end
        entries.each do |e|
          next if @layout["seen"].include?(e.key)
          home = e.home == false ? nil : PAGES.find { |_i, _n, k| k == e.kind }
          page = home && pages.find { |p| p["id"] == home[0] }
          if page
            list = page["entries"]
            at = list.index { |k| (o = entry(k)) && o.kind == e.kind && o.priority > e.priority }
            at ? list.insert(at, e.key) : list << e.key
          end
          @layout["seen"] << e.key
          changed = true
        end
        save_layout if changed
      end

      def pages
        return layout["pages"]
      end

      def page_index
        return [[layout["page"].to_i, 0].max, pages.length - 1].min
      end

      def page_index=(i)
        layout["page"] = i.to_i
        save_layout
      end

      def builtin?(page)
        return PAGES.any? { |id, _n, _k| id == page["id"] }
      end

      # A page's name as shown (the built-in ones in the player's language).
      def page_name(page)
        builtin = PAGES.find { |id, _n, _k| id == page["id"] }
        return builtin && page["name"] == builtin[1] ? _INTL(builtin[1]) : page["name"].to_s
      end

      # The entries a page shows now.
      def page_entries(page)
        return page["entries"].map { |k| entry(k) }.compact.select { |e| shown?(e) }
      end

      def add_page(name)
        return nil if pages.length >= PAGE_MAX
        n = 1
        n += 1 while pages.any? { |p| p["id"] == "page_#{n}" }
        page = { "id" => "page_#{n}", "name" => clean_name(name, _INTL("Page {1}", pages.length + 1)), "entries" => [] }
        pages << page
        save_layout
        return page
      end

      def rename_page(page, name)
        page["name"] = clean_name(name, page["name"])
        save_layout
      end

      def remove_page(page)
        return false if builtin?(page)
        pages.delete(page)
        save_layout
        return true
      end

      # A built-in page back to every entry of its kind, by priority; one of
      # the player's own, empty.
      def reset_page(page)
        builtin = PAGES.find { |id, _n, _k| id == page["id"] }
        page["entries"] = builtin ? entries.select { |e| e.kind == builtin[2] && e.home != false }.map(&:key) : []
        page["name"] = builtin[1] if builtin
        save_layout
      end

      def clean_name(name, fallback)
        text = name.to_s.strip[0, NAME_MAX].to_s
        return text.empty? ? fallback.to_s : text
      end

      #------------------------------------------------------------------------
      # Quick Items (each save)
      #------------------------------------------------------------------------
      def save_data
        return Reloaded::SaveStore.section(:overworld_menu) if Reloaded::SaveStore.loaded?
        return @no_save ||= {}
      end

      # QUICK_MAX slots: an item's id (a Symbol) or nil.
      def quick_items
        list = Array(save_data["quick_items"]).first(QUICK_MAX).map { |s| s.to_s.empty? ? nil : s.to_s.to_sym }
        list += [nil] * (QUICK_MAX - list.length)
        return list
      end

      def set_quick_item(slot, item)
        list = quick_items.map { |s| s && s.to_s }
        list[slot] = item ? item.to_s : nil
        save_data["quick_items"] = list
      end

      # The item's slot (0 first), or nil (the Bag's Quick Items actions)
      def quick_slot(item)
        return quick_items.index(item.to_s.to_sym)
      end

      # Into the first empty slot: the slot, or nil when all are full
      def add_quick_item(item)
        i = quick_items.index(nil)
        set_quick_item(i, item) if i
        return i
      end

      def remove_quick_item(item)
        i = quick_slot(item)
        set_quick_item(i, nil) if i
        return i
      end

      # Items that can go in a slot: anything with a use outside battle.
      def quick_item?(item)
        return false unless defined?(::ItemHandlers) && defined?(::GameData::Item) && ::GameData::Item.exists?(item)
        return true if ::ItemHandlers.hasOutHandler(item)
        return ::GameData::Item.get(item).is_machine? && $Trainer && $Trainer.party_count > 0
      rescue StandardError
        return false
      end

      def has_item?(item)
        return $PokemonBag && $PokemonBag.pbHasItem?(item)
      rescue StandardError
        return false
      end

      # Last Used Item (each save): the item last used, from the Bag, the map
      # or this menu.
      def last_item
        s = save_data["last_item"].to_s
        return s.empty? ? nil : s.to_sym
      end

      def note_item_used(item)
        save_data["last_item"] = item.to_s if item
      end

      # The game's two ways to use an item (pbUseItem: the Bag's, 1 or 2 when
      # used; pbUseKeyItemInField: the map's, true when used), each hooked
      # once the game has it.
      def install_item_hooks
        @item_hooks ||= {}
        [[:pbUseItem, 1, :bag], [:pbUseKeyItemInField, 0, :field]].each do |name, at, key|
          next if @item_hooks[key]
          next unless ::Object.private_method_defined?(name) || ::Object.method_defined?(name)
          @item_hooks[key] = true
          Reloaded::Hooks.around(nil, ::Object, name, :id => :"overworld_menu_last_item_#{key}") do |original, *args|
            r = original.call(*args)
            Reloaded::OverworldMenu.note_item_used(args[at]) if (r.is_a?(Integer) ? r > 0 : r)
            r
          end
        end
      end

      #------------------------------------------------------------------------
      # The Encounter Counter
      #------------------------------------------------------------------------
      # A wild Pokémon appeared (the game's own event).
      def met(pkmn)
        @session += 1
        data = save_data
        data["encounters"] = data["encounters"].to_i + 1
        data["since_shiny"] = pkmn && (pkmn.shiny? rescue false) ? 0 : data["since_shiny"].to_i + 1
      rescue StandardError
        nil
      end

      def since_shiny
        return save_data["since_shiny"].to_i
      end

      #------------------------------------------------------------------------
      # Opening it
      #------------------------------------------------------------------------
      # Once a map update: a press is kept while the player finishes a step,
      # and dropped when the menu can't open.
      def on_map(scene)
        return unless $scene == scene
        @pending = true if pressed?
        return unless @pending
        return if $game_player && $game_player.moving?
        @pending = false
        open if can_open?
      end

      def pressed?
        return Reloaded::Controls.trigger?(:overworld_menu) if defined?(Reloaded::Controls) && Reloaded::Controls.active?
        return Input.respond_to?(:triggerex?) && Input.triggerex?(:F) ? true : false
      rescue StandardError
        return false
      end

      def can_open?
        return false unless $Trainer && $game_temp && $game_player && Reloaded::Pixel.available?
        return false if $game_temp.in_menu || $game_temp.in_battle
        return false if $game_temp.respond_to?(:message_window_showing) && $game_temp.message_window_showing
        return false if $game_temp.respond_to?(:player_transferring) && $game_temp.player_transferring
        return false if $game_temp.respond_to?(:moving_furniture) && $game_temp.moving_furniture
        return false if defined?(pbMapInterpreterRunning?) && pbMapInterpreterRunning?
        return false if $game_system && $game_system.respond_to?(:menu_disabled) && $game_system.menu_disabled
        return false if defined?(SWITCH_DURING_INTRO) && $game_switches && $game_switches[SWITCH_DURING_INTRO]
        return true
      end

      # The menu, then what an entry left to do once it closed (Fly, Save).
      def open
        after = nil
        begin
          $game_temp.in_menu = true
          $game_player.straighten if $game_player.respond_to?(:straighten)
          after = Reloaded::OverworldMenuScreen.new.main
        rescue StandardError => e
          Reloaded::Log.exception("The Overworld Menu broke", e, :overworld_menu)
          after = nil
        ensure
          $game_temp.in_menu = false
        end
        begin
          after.call if after.respond_to?(:call)
        rescue StandardError => e
          Reloaded::Log.exception("An Overworld Menu entry failed after the menu closed", e, :overworld_menu)
        end
      end
    end

    #--------------------------------------------------------------------------
    # Scene_Map: the Overworld Menu's button
    #--------------------------------------------------------------------------
    module MapHooks
      def update
        super
        Reloaded::OverworldMenu.on_map(self) if Reloaded::OverworldMenu.on?
      end
    end
  end
end
