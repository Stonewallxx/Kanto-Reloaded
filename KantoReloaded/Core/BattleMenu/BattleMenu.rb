# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Battle Menu
#==============================================================================
# Roadmap topic battle-command-menu (Wave 6's first; his picks 2026-10-17
# and 2026-10-28): a panel you open while choosing Fight, Bag, Pokémon or
# Run, with Kanto Reloaded's battle tools and other mods' (UI/BattleMenuPanel.rb),
# Battle Info (UI/BattleInfoScreen.rb) and the Field Strip over the command
# box (UI/FieldStrip.rb). A feature with a switch, On. EBDX's battle screen
# and PIF's alike.
#
#   pages        two, fixed: Main (Kanto Reloaded's entries) and Mods (every
#                other mod's); LB and RB turn them, and with no other mod's
#                entries there's only Main
#   opens        its own Controls action, Battle Menu (Battle area), on the
#                Action button at first. Inside the panel the same button
#                runs the Favorite (Battle Info until Quick Throw is built);
#                Open Battle Favorite and Open Battle Info (unbound) skip it
#   remembers    the order on each page, the Favorite and the page left on,
#                the same in every save: <mod folder>\Settings\Battle Menu.json
#   Battle Info  KIF's own (cody's) can't be on while the Battle Menu is:
#                KIF's Locks keep it Off then (KIF Settings says Kanto
#                Reloaded set it); Off, the player's own value is back
#
# Entries register here. A mod's go on Mods, its owner the mod whose scripts
# are loading (KIF::Mods.current); they hide at once while that mod is
# switched off in KIF's Mods list (Mod Manager's too) and come back where
# they were.
#
#   Reloaded::BattleMenu.register(:battle_camera, :name => "Battle Camera",
#     :icon => :POKEDEX,                          # an item's picture, or a picture's path
#     :description => "Hides the battle boxes for a screenshot.",
#     :priority => 50,
#     :mod => "Photo Mode",                       # its mod's name, when KIF's list hasn't one
#     :condition => proc { |ctx| true },          # listed at all
#     :usable => proc { |ctx| true or "Why not." },   # dimmed with a padlock, and says why
#     :status => proc { |ctx| ["x4", :gold] },    # words and a tone (:green :gold :red :blue :dim)
#     :handler => proc { |ctx| nil })             # nil stays, :close, or :fight :bag :party :run :call
#   Reloaded::BattleMenu.unregister(:battle_camera)
#   Reloaded::BattleMenu.unregister_owner("PhotoMode")
#
#   ctx (one per opening): battle, index (the Pokémon choosing), battler,
#   scene, first_action, wild?, trainer?; hidden { } (step aside for a screen
#   of its own), notice(title, text), confirm(title, text, yes, no) (the
#   mod's name under the words), choose(title, labels, descriptions), toast.
#
# An entry whose condition, status or handler raises is logged and dims for
# the rest of the battle; the Battle Menu itself carries on.
#==============================================================================

module Reloaded
  module BattleMenu
    FEATURE = :battle_menu
    PAGE = :battle_menu
    STRIP = :"battle_menu.field_strip"
    FILE = "Battle Menu.json"
    OWNER = "kanto_reloaded"
    KR_MOD = "KantoReloaded"                     # Kanto Reloaded's id in KIF's Mods list
    KIF_BATTLE_INFO = :cody_battleinfo           # KIF's Battle Info setting (0 Off)
    PAGES = ["main", "mods"].freeze
    COMMANDS = { :fight => 0, :bag => 1, :party => 2, :run => 3, :call => 4 }.freeze
    EXIT = :kr_battle_menu_exit
    FAVORITES = ["quick_throw", "battle_info"].freeze     # the default: the first one there
    CONTEXT = :@kr_battle_menu                   # on the scene while its command box runs
    BROKEN = :@kr_battle_menu_broken             # on the battle: entries that failed in it

    Entry = Struct.new(:key, :name, :owner, :icon, :description, :priority, :feature, :condition, :usable,
                       :status, :handler, :mod)

    @entries = {}

    class << self
      attr_reader :opening            # the panel or a screen of it is open

      def boot
        register_settings
        Reloaded::Features.register(FEATURE, :name => "Battle Menu", :page => PAGE, :order => 57,
          :description => "A menu of battle tools you open while choosing Fight, Bag, Pokémon or Run: Battle Info, the Turn Log and other mods' tools, " \
                          "and the Field Strip over the battle menu.")
        register_controls
        Reloaded::Hooks.needs(:kif_option, KIF_BATTLE_INFO, :id => :battle_menu_kif_battle_info)
        sync_kif_battle_info
        Reloaded::Events.on(:feature_changed, :battle_menu_kif_battle_info) { |e| sync_kif_battle_info if e.is_a?(Hash) && e[:id] == FEATURE }
        Entries.register_all if const_defined?(:Entries, false)
        TurnLog.install if const_defined?(:TurnLog, false)
        Notes.install if const_defined?(:Notes, false)
        install
        return true
      end

      def on?
        return Reloaded::Features.on?(FEATURE)
      end

      def register_settings
        s = Reloaded::Settings
        s.register_page(PAGE, :group => :general, :name => "Battle Menu", :icon => :features, :priority => 46,
          :feature => FEATURE,
          :description => "The Battle Menu and the Field Strip over the battle menu.")
        s.register(STRIP, :page => PAGE, :priority => 10, :type => :toggle, :default => true, :name => "Field Strip",
          :description => "Weather, terrain, rooms, screens and hazards, with the turns they have left, over the battle menu while you choose.")
      end

      # KIF's Battle Info locked Off while the Battle Menu is On, freed when
      # it's Off (KIF's Locks have no one-key unlock: the key leaves its table)
      def sync_kif_battle_info
        return unless defined?(::KIF::Locks) && ::KIF::Locks.respond_to?(:get)
        lock = ::KIF::Locks.get(KIF_BATTLE_INFO)
        mine = lock && lock[2].to_s == KR_MOD
        if on?
          ::KIF::Locks.set(KIF_BATTLE_INFO, 0, by: "Kanto Reloaded", owner: KR_MOD) unless mine
        elsif mine
          ::KIF::Locks.table.delete(KIF_BATTLE_INFO)
        end
      rescue StandardError => e
        Reloaded::Log.exception("The Battle Menu couldn't lock or free KIF's Battle Info", e, :battle_menu)
      end

      def strip?
        return on? && Reloaded::Settings.get(STRIP) != false
      end

      def register_controls
        return unless defined?(Reloaded::Controls) && Reloaded::Controls.respond_to?(:register)
        c = Reloaded::Controls
        c.register(:battle_menu, :name => "Battle Menu", :area => :battle, :group => "Battle Menu", :follows => :action,
          :priority => 10, :description => "Opens the Battle Menu while you choose Fight, Bag, Pokémon or Run. Pressed again in it: The Favorite.")
        c.register(:open_battle_favorite, :name => "Open Battle Favorite", :area => :battle, :group => "Battle Menu",
          :priority => 20, :description => "Runs the Battle Menu's Favorite straight from the battle menu.")
        c.register(:open_battle_info, :name => "Open Battle Info", :area => :battle, :group => "Battle Menu",
          :priority => 30, :description => "Opens Battle Info straight from the battle menu.")
      end

      #------------------------------------------------------------------------
      # Entries
      #------------------------------------------------------------------------
      def register(key, options = {})
        key = key.to_s
        owner = (options[:owner] || current_owner).to_s
        old = @entries[key]
        if old && old.owner != owner && old.owner == OWNER
          Reloaded::Log.warning("Battle Menu: #{owner} can't take Kanto Reloaded's entry #{key}", :battle_menu)
          return nil
        end
        @entries[key] = Entry.new(key, options[:name].to_s, owner, options[:icon], options[:description].to_s,
                                  options[:priority] || 100, options[:feature], options[:condition], options[:usable],
                                  options[:status], options[:handler], options[:mod])
        @checked = false
        return key
      end

      def unregister(key, options = {})
        e = @entries[key.to_s]
        return false unless e
        return false if options[:owner] && e.owner != options[:owner].to_s
        @entries.delete(key.to_s)
        return true
      end

      def unregister_owner(owner)
        before = @entries.length
        @entries.delete_if { |_k, e| e.owner == owner.to_s }
        return before - @entries.length
      end

      def entry(key)
        return @entries[key.to_s]
      end

      def entries
        return @entries.values
      end

      # The mod whose scripts are loading (Kanto Reloaded's own entries say
      # theirs), or "other" when there's none
      def current_owner
        id = defined?(::KIF::Mods) && ::KIF::Mods.respond_to?(:current) ? ::KIF::Mods.current : nil
        return OWNER if id.to_s == KR_MOD
        return id.nil? || id.to_s.empty? ? "other" : id.to_s
      end

      def page_of(e)
        return e.owner == OWNER ? "main" : "mods"
      end

      # Shown now: its feature is on, its mod is on, its condition holds
      def shown?(e, ctx)
        return false if e.feature && !Reloaded::Features.on?(e.feature)
        return false unless mod_on?(e.owner)
        return true unless e.condition
        return e.condition.call(ctx) ? true : false
      rescue StandardError => ex
        failed(e, ctx, ex)
        return false
      end

      # true, or why it can't be used now
      def usable(e, ctx)
        return _INTL("It stopped working in this battle.") if broken?(e, ctx)
        return true unless e.usable
        r = e.usable.call(ctx)
        return r == true || r.nil? ? true : (r == false ? _INTL("You can't use that right now.") : r.to_s)
      rescue StandardError => ex
        failed(e, ctx, ex)
        return _INTL("It stopped working in this battle.")
      end

      # [words, tone] or nil
      def status(e, ctx)
        return nil unless e.status && !broken?(e, ctx)
        s = e.status.call(ctx)
        return nil if s.nil?
        return s.is_a?(Array) ? [s[0].to_s, s[1]] : [s.to_s, nil]
      rescue StandardError => ex
        failed(e, ctx, ex)
        return nil
      end

      def broken?(e, ctx)
        list = ctx && ctx.battle ? ctx.battle.instance_variable_get(BROKEN) : nil
        return list ? list.include?(e.key) : false
      end

      # An entry's code raised: logged, and it dims for the rest of the battle
      def failed(e, ctx, error)
        Reloaded::Log.exception("Battle Menu: #{e.name} (#{e.owner}) failed", error, :battle_menu)
        return unless ctx && ctx.battle
        list = ctx.battle.instance_variable_get(BROKEN) || []
        list << e.key unless list.include?(e.key)
        ctx.battle.instance_variable_set(BROKEN, list)
      end

      #------------------------------------------------------------------------
      # Mods: whose entries show, and their names
      #------------------------------------------------------------------------
      # KIF's Mods list (and Mod Manager's), read once per opening
      def mod_list
        return @mod_list if @mod_list
        @mod_list = defined?(::KIF::Mods) && ::KIF::Mods.respond_to?(:entries) ? Array(::KIF::Mods.entries) : []
      rescue StandardError
        @mod_list = []
      end

      def mod_on?(owner)
        return true if owner == OWNER
        m = mod_list.find { |x| x.id.to_s == owner }
        return m ? (m.enabled? ? true : false) : true
      rescue StandardError
        return true
      end

      # A mod's name, as its row shows it
      def mod_name(e)
        return e.mod.to_s if e.mod
        m = mod_list.find { |x| x.id.to_s == e.owner }
        return m.name.to_s if m && m.name
        return _INTL("Another Mod") if e.owner == "other"
        return defined?(::KIF::Mods) && ::KIF::Mods.respond_to?(:display_name) ? ::KIF::Mods.display_name(e.owner).to_s : e.owner
      rescue StandardError
        return e.owner.to_s
      end

      #------------------------------------------------------------------------
      # The order on each page, the Favorite and the page (every save)
      #------------------------------------------------------------------------
      # { "main" => [keys], "mods" => [keys], "favorite" => key or nil, "page" => 0 }
      def layout
        unless @layout
          text = Reloaded::Paths.read_text(layout_path)
          data = text ? (Reloaded::JSON.parse(text) rescue nil) : nil
          data = {} unless data.is_a?(Hash)
          @layout = { "page" => data["page"].to_i }
          PAGES.each { |p| @layout[p] = Array(data[p]).map(&:to_s).uniq }
          @layout["favorite"] = data["favorite"] && data["favorite"].to_s if data.has_key?("favorite")
          @checked = false
        end
        check_layout unless @checked
        return @layout
      end

      def layout_path
        return File.join(Reloaded::Paths.settings_dir, FILE)
      end

      def save_layout
        Reloaded::Paths.write_atomic(layout_path, Reloaded::JSON.generate(@layout, true)) if @layout
      rescue StandardError => e
        Reloaded::Log.exception("The Battle Menu's order couldn't be saved", e, :battle_menu)
      end

      def forget_layout
        @layout = nil
      end

      # An entry not seen before takes its place on its page by priority; one
      # whose mod is off keeps its place, out of sight
      def check_layout
        @checked = true
        changed = false
        @entries.values.sort_by { |e| [e.priority, e.name] }.each do |e|
          list = @layout[page_of(e)]
          next if list.include?(e.key)
          at = list.index { |k| (o = @entries[k]) && o.priority > e.priority }
          at ? list.insert(at, e.key) : list << e.key
          changed = true
        end
        save_layout if changed
      end

      # The entries a page shows now, in order
      def page_entries(page, ctx)
        return layout[page].map { |k| @entries[k] }.compact.select { |e| shown?(e, ctx) }
      end

      # The pages that have something to show (Main always)
      def pages(ctx)
        return PAGES.select { |p| p == "main" || !page_entries(p, ctx).empty? }
      end

      def page_index
        return layout["page"].to_i
      end

      def page_index=(i)
        layout["page"] = i.to_i
        save_layout
      end

      # One step up (-1) or down (1) among what the page shows now
      def move(page, key, dir, ctx)
        shown = page_entries(page, ctx).map(&:key)
        i = shown.index(key.to_s)
        return false unless i && i + dir >= 0 && i + dir < shown.length
        list = layout[page]
        a = list.index(key.to_s)
        b = list.index(shown[i + dir])
        list[a], list[b] = list[b], list[a]
        save_layout
        return true
      end

      def favorite_key
        return layout["favorite"] if layout.has_key?("favorite")
        return FAVORITES.find { |k| @entries[k] }
      end

      def favorite?(e)
        return e && favorite_key == e.key
      end

      # key, or nil for none
      def favorite=(key)
        layout["favorite"] = key && key.to_s
        save_layout
      end

      #------------------------------------------------------------------------
      # The command box: the hooks
      #------------------------------------------------------------------------
      # The game's classes are there in the game; outside it (tests, the
      # preview tool) each hook is made only when its target is.
      def install
        h = Reloaded::Hooks
        [["PokeBattle_Scene", :pif, SceneInput], ["PokeBattle_SceneEBDX", :ebdx, SceneInputEBDX]].each do |name, tag, mod|
          next unless Object.const_defined?(name)
          klass = Object.const_get(name)
          if klass.method_defined?(:pbCommandMenu)
            h.around(FEATURE, klass, :pbCommandMenu, :id => :"battle_menu_command_#{tag}") do |original, *args|
              Reloaded::BattleMenu.command_menu(original.receiver, args) { original.call(*args) }
            end
          end
          h.prepend(FEATURE, klass, mod, :id => :"battle_menu_input_#{tag}") if klass.method_defined?(:pbUpdate)
        end
        if defined?(::PokeBattle_Battle) && ::PokeBattle_Battle.method_defined?(:pbEndOfBattle)
          h.around(FEATURE, ::PokeBattle_Battle, :pbEndOfBattle, :id => :battle_menu_end) do |original, *args|
            Reloaded::FieldStrip.dispose if defined?(Reloaded::FieldStrip)
            original.call(*args)
          end
        end
      end

      # While the command box runs: the context its scene keeps for the
      # Battle Menu's button, the Field Strip over it, and the way out with a
      # game command (Quick Throw's Bag) when an entry asks for one
      def command_menu(scene, args)
        battle = scene.instance_variable_get(:@battle)
        return yield unless battle
        before = scene.instance_variable_get(CONTEXT)
        scene.instance_variable_set(CONTEXT, Context.new(scene, battle, args[0].to_i, args[1] ? true : false))
        Reloaded::FieldStrip.show(scene, battle) if strip? && defined?(Reloaded::FieldStrip)
        ret = catch(EXIT) { yield }
        return ret unless ret.is_a?(Array) && ret[0] == EXIT
        finish_ebdx(scene, args[0].to_i, ret[1])
        return ret[1]
      ensure
        scene.instance_variable_set(CONTEXT, before) if scene
        Reloaded::FieldStrip.hide if defined?(Reloaded::FieldStrip)
      end

      # EBDX's command loop ends by keeping the cursor for next turn and
      # sliding its buttons away (660_EBDX/021_EBDX_CursorMemory.rb); leaving
      # it with a command skips those lines, so they're done here
      def finish_ebdx(scene, idx, value)
        cw = scene.instance_variable_get(:@commandWindow)
        return unless defined?(::CommandWindowEBDX) && cw.is_a?(::CommandWindowEBDX)
        last = scene.instance_variable_get(:@lastCmd)
        last[idx] = value if last && value >= 0
        cw.hidePlay if cw.respond_to?(:hidePlay)
      rescue StandardError => e
        Reloaded::Log.exception("Battle Menu: EBDX's command box after a command", e, :battle_menu)
      end

      # Once a frame while the command box runs (its pbUpdate)
      def check(scene)
        ctx = scene.instance_variable_get(CONTEXT)
        return if ctx.nil? || @opening
        how = if trigger?(:battle_menu) then :panel
              elsif trigger?(:open_battle_favorite) then :favorite
              elsif trigger?(:open_battle_info) then :info
              end
        open(ctx, how) if how
      end

      def trigger?(id)
        return Reloaded::Controls.trigger?(id) if defined?(Reloaded::Controls) && Reloaded::Controls.respond_to?(:trigger?)
        return id == :battle_menu && Input.trigger?(Input::ACTION)
      end

      # The panel, the Favorite or Battle Info, from the command box. An
      # entry that asks for a game command leaves the command box with it.
      def open(ctx, how)
        @opening = true
        @mod_list = nil
        pbPlayDecisionSE if defined?(pbPlayDecisionSE)
        result = case how
                 when :panel then Reloaded::BattleMenuPanel.new(ctx).main
                 when :favorite then run_favorite(ctx)
                 when :info then open_info(ctx)
                 end
        command = command_of(result, ctx)
        throw(EXIT, [EXIT, command]) if command
      rescue StandardError => e
        Reloaded::Log.exception("The Battle Menu broke", e, :battle_menu)
      ensure
        @opening = false
        Input.update            # the press that closed it isn't read again by the command box
      end

      # A handler's game command as the battle's number, or nil
      def command_of(result, ctx)
        n = result.is_a?(Symbol) ? COMMANDS[result] : nil
        return nil unless n
        return nil if n == 3 && !ctx.first_action      # Run only for the first Pokémon to choose
        return n
      end

      # Runs an entry: true, its handler's answer, or [:locked, why] / :failed
      def run(e, ctx)
        why = usable(e, ctx)
        return [:locked, why] unless why == true
        ctx.entry = e
        return e.handler ? e.handler.call(ctx) : nil
      rescue StandardError => ex
        failed(e, ctx, ex)
        return :failed
      ensure
        ctx.entry = nil if ctx
      end

      # The Favorite straight from the command box (Open Battle Favorite)
      def run_favorite(ctx)
        e = entry(favorite_key)
        unless e && shown?(e, ctx)
          pbPlayBuzzerSE if defined?(pbPlayBuzzerSE)
          return nil
        end
        r = run(e, ctx)
        if r.is_a?(Array) && r[0] == :locked
          Reloaded::Toast.show(r[1]) if defined?(Reloaded::Toast)
          return nil
        end
        Reloaded::Toast.show(_INTL("{1} couldn't be done.", e.name)) if r == :failed && defined?(Reloaded::Toast)
        return r
      end

      # Battle Info, on a tab (:log: the Turn Log)
      def open_info(ctx, tab = nil)
        ctx.hidden { Reloaded::BattleInfoScreen.new(ctx, tab).main }
        return nil
      end
    end

    #--------------------------------------------------------------------------
    # One opening's context (see the top)
    #--------------------------------------------------------------------------
    class Context
      attr_reader :scene, :battle, :index, :first_action
      attr_accessor :screen, :entry

      def initialize(scene, battle, index, first_action)
        @scene = scene
        @battle = battle
        @index = index
        @first_action = first_action
      end

      def battler; return @battle.battlers[@index]; end
      def wild?; return @battle.wildBattle?; end
      def trainer?; return @battle.trainerBattle?; end

      # Another screen takes over: the panel steps aside
      def hidden(&block)
        return @screen ? @screen.hidden(&block) : yield
      end

      def notice(title, text)
        return Reloaded::Dialogs.notice(@screen, title, text) if @screen
        Reloaded::Toast.show(text.to_s) if defined?(Reloaded::Toast)
        return true
      end

      # Yes or No, the mod's name under the words; No first
      def confirm(title, text, yes = nil, no = nil)
        return false unless @screen
        segments = nil
        if @entry && @entry.owner != OWNER
          segments = [[_INTL("From {1}", Reloaded::BattleMenu.mod_name(@entry)), @screen.palette[:dim]]]
        end
        return Reloaded::Dialogs.ask(@screen, title, text, segments, [yes || _INTL("Yes"), no || _INTL("No")], 1) == 0
      end

      def choose(title, labels, descriptions = [])
        return nil unless @screen
        return Reloaded::Dialogs.menu(@screen, title, labels, descriptions)
      end

      def toast(text)
        Reloaded::Toast.show(text.to_s) if defined?(Reloaded::Toast)
      end
    end

    #--------------------------------------------------------------------------
    # The scenes' pbUpdate: the Battle Menu's buttons while the command box
    # runs (an ivar read otherwise). EBDX's scene has its own pbUpdate that
    # doesn't call up, so each class gets its own module.
    #--------------------------------------------------------------------------
    module SceneInput
      def pbUpdate(*args)
        ret = super
        Reloaded::BattleMenu.check(self) if @kr_battle_menu && Reloaded::BattleMenu.on?
        return ret
      end
    end

    module SceneInputEBDX
      def pbUpdate(*args)
        ret = super
        Reloaded::BattleMenu.check(self) if @kr_battle_menu && Reloaded::BattleMenu.on?
        return ret
      end
    end
  end
end
