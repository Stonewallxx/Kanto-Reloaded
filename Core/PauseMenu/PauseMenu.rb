#==============================================================================
# Kanto Reloaded: the Pause Menu
#==============================================================================
# Roadmap topic 34 (Info Sidebar, chosen 2026-10-17; details agreed
# 2026-10-19): the pause menu, rebuilt. A left column with Money, Location
# (map, day, time) and the Favorite, which Y opens; on the right the Pinned
# row (Kanto Reloaded's Shop, TM Vault, PokeVial and PC, each as it's
# built), Your Row (up to 4 entries, edited in place with X) and the All
# carousel of every entry. The map shows through, dimmed.
#
# Only the screen is replaced (PokemonPauseMenu_Scene, a prepended module:
# UI/PauseMenuScreen.rb). PIF's PokemonPauseMenu still builds the list and
# runs every entry, and KIF's registry (KIF::PauseMenu) still adds and runs
# its own, so Safari Quit, Quit Contest, Outfit, KIF's Return and other
# mods' entries all keep working, and closing an entry comes back to the
# menu. Each row of the list is recognized by its KIF id or its icon, never
# by its text (items_for).
#
#   Your Row, the Favorite   the same in every save:
#                            <mod folder>\Settings\Pause Menu.json
#   Open Favorite            a Controls action, no button at first: the
#                            Favorite straight from the map
#   Reloaded Pause Menu Off  the game's own menu
#   Menu Animations          (Interface) shared with the Overworld Menu
#
# Unavailable entries: All shows only what can be used now (as PIF's list
# does); a Your Row tile or the Favorite stays where it was, locked, and
# says why when chosen (lock_reason).
#
# Kanto Reloaded's own entries register here. They join KIF's list (so
# they work in the game's own menu too) and can take a Pinned slot, show a
# status, and take over one of KIF's entries while their feature is on:
#
#   Reloaded::PauseMenu.register(:pokevial, "PokeVial", :feature => :pokevial,
#     :icon => "Graphics/...", :small_icon => "menuIcons/POKEMON", :pinned => 2,
#     :takes_over => :kif_heal, :status => proc { ["Charges: 3/5", nil, "3/5"] },
#     :condition => proc { ... }, :lock_reason => proc { "..." },
#     :visible => proc { ... }, :alert => proc { party_hurt? },
#     :handler => proc { |scene| ...; :stay })
#
# :condition false shows its tile locked (lock_reason says why); :visible
# false hides it altogether, Pinned slot too.
# A status: [words, :red or nil, short words for a row's pill]. An alert
# that's true makes its tile glow red, pulsing (Frame#alert_box), while the
# cursor is elsewhere.
#==============================================================================

module Reloaded
  module PauseMenu
    TOGGLE = :"systems.reloaded_pause_menu"
    ANIMATIONS = :"interface.menu_animations"     # shared with the Overworld Menu
    FILE = "Pause Menu.json"
    ROW_MAX = 4
    PINNED_SLOTS = 4
    ICONS = "Graphics/Icons/"

    # PIF's rows, by their icon (016_UI/001_UI_PauseMenu.rb: ICON_*)
    BASE_ICONS = { "POKEDEX" => "pokedex", "POKEMON" => "pokemon", "BAG" => "bag", "POKENAV" => "pokenav",
                   "PLAYER" => "trainer", "OUTFITS" => "outfit", "SAVE" => "save", "OPTIONS" => "options",
                   "DEBUG" => "debug", "TITLE" => "title", "SAFARI" => "quit" }.freeze
    BASE_NAMES = { "pokedex" => "Pokédex", "pokemon" => "Pokémon", "bag" => "Bag", "pokenav" => "PokéNav",
                   "outfit" => "Outfit", "save" => "Save", "options" => "Options", "debug" => "Debug",
                   "title" => "Title", "quit" => "Quit", "quit_contest" => "Quit Contest" }.freeze
    # Tiles draw these: [file, scale]. Graphics/PauseMenu is the mod's own
    # (Hoenn Reloaded's menu icons, fitted to 56 pixels); the rest is the
    # game's. Anything else draws its list icon at double size.
    ICON_DIR = "Graphics/PauseMenu/"
    TILE_ICONS = {
      "pokedex"       => [ICON_DIR + "POKEDEX", 1],
      "pokemon"       => [ICON_DIR + "POKEMON", 1],
      "bag"           => [ICON_DIR + "BAG", 1],
      "pokenav"       => [ICON_DIR + "POKENAV", 1],
      "trainer"       => [ICON_DIR + "TRAINERINFO", 1],
      "outfit"        => [ICON_DIR + "OUTFIT", 1],
      "save"          => [ICON_DIR + "SAVE", 1],
      "options"       => [ICON_DIR + "OPTIONS", 1],
      "debug"         => [ICON_DIR + "DEBUG", 1],
      "title"         => [ICON_DIR + "TITLE", 1],
      "kif_pc"        => [ICON_DIR + "PC", 1],
      "kif_heal"      => [ICON_DIR + "POKEVIAL", 1],
      "kif_shop"      => [ICON_DIR + "RELOADEDMART", 1],
      "kif_tutornet"  => [ICON_DIR + "TMVAULT", 1],
      "quit_contest"  => ["Graphics/Items/SPORTBALL", 1],
      "kif_er_return" => ["Graphics/Items/ESCAPEROPE", 1]
    }.freeze
    # Only there in the Safari Zone or the Bug Contest: never in Your Row
    # or the Favorite
    SITUATIONAL = ["quit", "quit_contest"].freeze

    # A row of the list as a tile: key, label, [icon file, scale], its index
    # in the list (nil: not in the list now, so locked)
    Item = Struct.new(:key, :label, :icon, :index)

    @registered = {}
    @cursor = {}

    class << self
      attr_reader :registered
      attr_accessor :cursor          # where the menu was left, this session

      def boot
        register_settings
        if defined?(Reloaded::Controls) && Reloaded::Controls.respond_to?(:register)
          Reloaded::Controls.register(:open_favorite, :name => "Open Favorite", :area => :overworld, :group => "Menus",
            :priority => 150, :description => "Opens your Pause Menu Favorite straight from the map.")
        end
        install
        return true
      end

      def register_settings
        s = Reloaded::Settings
        s.register(TOGGLE, :page => :systems, :priority => 30, :type => :toggle, :default => true, :preset => false,
          :name => "Reloaded Pause Menu",
          :description => "Kanto Reloaded's Pause Menu: Money, location and time beside it, a row of your own, a Favorite and every entry in one carousel. Off shows the game's own.")
        s.register(ANIMATIONS, :page => :interface, :priority => 95, :type => :toggle, :default => true,
          :name => "Menu Animations",
          :description => "The Pause Menu and the Overworld Menu slide in and out, and the Pause Menu's carousel slides between entries.")
      end

      # The game's classes are there in the game; outside it (tests, the
      # preview tool) each hook is made only when its target is.
      def install
        h = Reloaded::Hooks
        if defined?(::PokemonPauseMenu_Scene) && defined?(Reloaded::PauseMenu::SceneView)
          h.prepend(nil, "PokemonPauseMenu_Scene", Reloaded::PauseMenu::SceneView, :id => :pause_menu_view)
        end
        if defined?(::Scene_Map)
          h.prepend(nil, "Scene_Map", MapHooks, :id => :pause_menu_map)
        end
        if defined?(::KIF::PauseMenu) && ::KIF::PauseMenu.respond_to?(:active_entries)
          h.around(nil, ::KIF::PauseMenu.singleton_class, :active_entries, :id => :pause_menu_takes_over) do |original, *args|
            list = original.call(*args)
            Reloaded::PauseMenu.taken_over.empty? ? list : list.reject { |e| Reloaded::PauseMenu.taken_over.include?(e.id.to_s) }
          end
        end
        return true
      end

      # Reloaded Pause Menu is on.
      def enabled?
        return Reloaded::Settings.get(TOGGLE) ? true : false
      rescue StandardError
        return false
      end

      # It's on, and its screen can draw.
      def active?
        return enabled? && Reloaded::Pixel.available?
      end

      def animations?
        return Reloaded::Settings.get(ANIMATIONS) ? true : false
      rescue StandardError
        return true
      end

      #------------------------------------------------------------------------
      # Kanto Reloaded's own entries
      #------------------------------------------------------------------------
      def register(id, label, options = {})
        key = id.to_s
        entry = options.merge(:key => key, :label => label)
        @registered[key] = entry
        return key unless defined?(::KIF::PauseMenu)
        feature = options[:feature]
        cond = options[:condition]
        vis = options[:visible]
        ::KIF::PauseMenu.add(id.to_sym, label, :icon => options[:small_icon] || "menuIcons/OPTIONS",
          :order => options[:order] || 100, :handler => options[:handler],
          :condition => proc { (feature.nil? || Reloaded::Features.on?(feature)) && (vis.nil? || vis.call) && (cond.nil? || cond.call) })
        return key
      end

      # A registered entry wants attention now (its :alert says so)
      def alert?(key)
        reg = @registered[key.to_s]
        return false unless reg && reg[:alert]
        return false if reg[:feature] && !Reloaded::Features.on?(reg[:feature])
        return reg[:alert].call ? true : false
      rescue StandardError
        return false
      end

      # KIF entries a registered entry takes over while its feature is on
      def taken_over
        out = []
        @registered.each_value do |e|
          next unless e[:takes_over]
          next if e[:feature] && !Reloaded::Features.on?(e[:feature])
          out << e[:takes_over].to_s
        end
        return out
      end

      # The Pinned row: 4 slots, each a key or nil
      def pinned_keys
        slots = Array.new(PINNED_SLOTS)
        @registered.each_value do |e|
          slot = e[:pinned]
          next unless slot.is_a?(Integer) && slot >= 0 && slot < PINNED_SLOTS && slots[slot].nil?
          next if e[:feature] && !Reloaded::Features.on?(e[:feature])
          next if e[:visible] && !(e[:visible].call rescue false)
          slots[slot] = e[:key]
        end
        return slots
      end

      #------------------------------------------------------------------------
      # The list's rows as tiles
      #------------------------------------------------------------------------
      # Each row of the list the game made (PIF's, with KIF's inserted) as
      # an Item: by its KIF id (KIF's label for it, exactly), else its icon;
      # a row of another mod's, by its text ("row:<text>").
      def items_for(commands)
        kif = kif_labels
        seen = {}
        out = []
        commands.each_with_index do |cmd, i|
          text = cmd.to_s
          plain = plain_label(text)
          icon = text[/<icon=([^>]+)>/, 1]
          key = if kif[text] then kif[text].id.to_s
                elsif icon && BASE_ICONS[File.basename(icon)] then BASE_ICONS[File.basename(icon)]
                elsif icon.nil? && plain == _INTL("Quit Contest") then "quit_contest"
                else "row:#{plain}"
                end
          key = "row:#{plain}" if seen[key]
          key = "row:#{plain}:#{i}" if seen[key]
          seen[key] = true
          out << Item.new(key, plain, tile_icon(key, icon), i)
        end
        return out
      end

      def plain_label(text)
        return text.to_s.gsub(/<[^>]*>/, "").strip
      end

      # KIF's label for each of its entries shown now => the entry
      def kif_labels
        return {} unless defined?(::KIF::PauseMenu) && ::KIF::PauseMenu.respond_to?(:active_entries)
        out = {}
        ::KIF::PauseMenu.active_entries.each do |e|
          begin
            out[::KIF::PauseMenu.label_for(e)] = e
          rescue StandardError
            nil
          end
        end
        return out
      end

      # [file, scale] for a tile's icon
      def tile_icon(key, list_icon = nil)
        reg = @registered[key]
        return [reg[:icon], reg[:icon_scale] || 1] if reg && reg[:icon]
        return TILE_ICONS[key] if TILE_ICONS[key]
        return [ICONS + list_icon, 2] if list_icon
        if (name = BASE_ICONS.key(key))
          return [ICONS + "menuIcons/#{name}", 2]
        end
        if (e = kif_entry(key)) && e.icon
          return [ICONS + e.icon.to_s, 2]
        end
        return nil
      end

      # An entry that isn't in the list now, for a locked tile; nil when
      # nothing knows it any more (a mod that was removed).
      def known_item(key)
        key = key.to_s
        label = if key == "trainer" then ($Trainer.name rescue nil) || _INTL("Trainer")
                elsif BASE_NAMES[key] then _INTL(BASE_NAMES[key])
                elsif @registered[key] then @registered[key][:label].to_s
                elsif (e = kif_entry(key)) then (e.label.is_a?(Proc) ? (e.label.call rescue key) : _INTL(e.label.to_s))
                elsif key.start_with?("row:") then key.sub(/\Arow:/, "").sub(/:\d+\z/, "")
                end
        return nil unless label
        return Item.new(key, label.to_s, tile_icon(key), nil)
      end

      def kif_entry(key)
        return nil unless defined?(::KIF::PauseMenu)
        list = ::KIF::PauseMenu.instance_variable_get(:@entries) || []
        return list.find { |e| e.id.to_s == key.to_s }
      end

      # Why an entry can't be used now.
      def lock_reason(key)
        reg = @registered[key.to_s]
        if reg && reg[:lock_reason]
          text = (reg[:lock_reason].call rescue nil)
          return text.to_s unless text.to_s.empty?
        end
        case key.to_s
        when "pokedex" then return _INTL("You don't have a Pokédex yet.")
        when "pokemon" then return _INTL("You don't have any Pokémon yet.")
        when "bag" then return _INTL("You can't use the Bag in the Bug Contest.")
        when "pokenav" then return _INTL("You don't have a PokéNav yet.")
        when "outfit" then return _INTL("You can't change your outfit here.")
        when "save"
          return _INTL("You can't save in the Safari Zone.") if in_safari?
          return _INTL("You can't save in the Bug Contest.") if in_contest?
          return _INTL("You can't save right now.")
        when "debug" then return _INTL("Debug needs KIF's DEBUG option on.")
        when "kif_pc", "kif_heal", "kif_shop"
          return _INTL("Turn on Kuray QoL in KIF Settings to use it.") if kif_option_off?(:kurayqol)
        when "kif_tutornet"
          return _INTL("Turn on Tutor.net in KIF Settings to use it.") if kif_option_off?(:tutornet)
        end
        return _INTL("You can't use that right now.")
      end

      def kif_option_off?(name)
        return false unless $PokemonSystem && $PokemonSystem.respond_to?(name)
        return $PokemonSystem.send(name).to_i != 1
      rescue StandardError
        return false
      end

      def in_safari?
        return defined?(pbInSafari?) && pbInSafari? ? true : false
      rescue StandardError
        return false
      end

      def in_contest?
        return defined?(pbInBugContest?) && pbInBugContest? ? true : false
      rescue StandardError
        return false
      end

      # A tile's status: [long words, short words, :red or nil], or nil.
      # Save: when it last saved; a registered entry: its own.
      def status(key)
        reg = @registered[key.to_s]
        if reg && reg[:status]
          s = (reg[:status].call rescue nil)
          return s.is_a?(Array) ? [s[0].to_s, (s[2] || s[0]).to_s, s[1]] : nil
        end
        return save_status if key.to_s == "save"
        return nil
      end

      def save_status
        age = save_age
        return [_INTL("Not Saved Yet"), _INTL("Unsaved"), :red] unless age
        ago = ago_words(age)
        return [_INTL("Saved {1}", ago), ago, nil]
      rescue StandardError
        return nil
      end

      # Seconds since this save was last written, or nil before its first
      def save_age
        slot = defined?(Reloaded::Saves) ? Reloaded::Saves.playing : nil
        path = slot ? Reloaded::Saves.path(slot.to_s) : nil
        return nil unless path && File.file?(path)
        return Time.now - File.mtime(path)
      rescue StandardError
        return nil
      end

      # "Just Now", "12 Min Ago", "3 Hr Ago", "2 Days Ago"
      def ago_words(seconds)
        s = seconds.to_i
        return _INTL("Just Now") if s < 60
        return _INTL("{1} Min Ago", s / 60) if s < 3600
        return _INTL("{1} Hr Ago", s / 3600) if s < 86_400
        days = s / 86_400
        return days == 1 ? _INTL("1 Day Ago") : _INTL("{1} Days Ago", days)
      end

      #------------------------------------------------------------------------
      # Your Row and the Favorite (every save)
      #------------------------------------------------------------------------
      def layout
        return @layout if @layout
        text = Reloaded::Paths.read_text(layout_path)
        data = text ? (Reloaded::JSON.parse(text) rescue nil) : nil
        data = {} unless data.is_a?(Hash)
        row = Array(data["row"]).map(&:to_s).reject(&:empty?).uniq
        fav = data["favorite"].to_s
        @layout = { "row" => row, "favorite" => fav.empty? ? nil : fav }
        return @layout
      end

      def layout_path
        return File.join(Reloaded::Paths.settings_dir, FILE)
      end

      def save_layout
        Reloaded::Paths.write_atomic(layout_path, Reloaded::JSON.generate(layout, true))
      rescue StandardError => e
        Reloaded::Log.exception("The Pause Menu's layout couldn't be saved", e, :pause_menu)
      end

      def forget_layout
        @layout = nil
      end

      def row
        return layout["row"]
      end

      def favorite
        return layout["favorite"]
      end

      def favorite=(key)
        layout["favorite"] = key ? key.to_s : nil
        save_layout
      end

      def add_to_row(key)
        return false if row.include?(key.to_s) || SITUATIONAL.include?(key.to_s)
        row << key.to_s
        save_layout
        return true
      end

      def remove_from_row(key)
        row.delete(key.to_s)
        save_layout
      end

      # Your Row with key moved one place left (-1) or right (1).
      def move_in_row(key, dir)
        i = row.index(key.to_s)
        return false unless i
        j = i + dir
        return false if j < 0 || j >= row.length
        row[i], row[j] = row[j], row[i]
        save_layout
        return true
      end

      #------------------------------------------------------------------------
      # Open Favorite, from the map
      #------------------------------------------------------------------------
      # The menu opens as the game opens it, picks the Favorite at once and
      # closes after it (the screen never shows). Read by the screen.
      attr_reader :direct

      def open_favorite(scene)
        key = favorite
        return (pbPlayBuzzerSE if defined?(pbPlayBuzzerSE)) unless key && active?
        @direct = key
        scene.call_menu
      ensure
        @direct = nil
      end

      # Once per map update, a press of Open Favorite (kept until the player
      # can act, as Controls' own shortcuts are).
      def on_map(scene)
        return unless $scene == scene && defined?(Reloaded::Controls) && Reloaded::Controls.active?
        @pending = true if Reloaded::Controls.trigger?(:open_favorite)
        return unless @pending && can_act?
        @pending = false
        open_favorite(scene)
      end

      def can_act?
        return false if $game_temp && $game_temp.respond_to?(:message_window_showing) && $game_temp.message_window_showing
        return false if $game_temp && $game_temp.respond_to?(:in_menu) && $game_temp.in_menu
        return false if defined?(pbMapInterpreterRunning?) && pbMapInterpreterRunning?
        return false if $game_player && $game_player.moving?
        return false if $game_system && $game_system.respond_to?(:menu_disabled) && $game_system.menu_disabled
        return true
      end
    end

    #--------------------------------------------------------------------------
    # Scene_Map: Open Favorite, and no location pop-up when the menu opens
    # (the left column shows where you are)
    #--------------------------------------------------------------------------
    module MapHooks
      def update
        super
        Reloaded::PauseMenu.on_map(self) if Reloaded::PauseMenu.enabled?
      end

      def showLocationWindow(*args)
        return nil if Reloaded::PauseMenu.active?
        return super
      end
    end
  end
end
