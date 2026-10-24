# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Reloaded PC
#==============================================================================
# Roadmap topic reloaded-pc (his picks, 2026-10-24): Design 1 Rebuilt, the
# whole 6 x 5 box, One Press to Move, Big Icons as KIF has them, locks as a
# padlock only when locked, Lifted holding, the Header Banner while fusing.
#
# Only how the PC looks and is driven is replaced (his pick: Replace Only
# the Scene): whenever the game makes a PokemonStorageScene while Reloaded
# PC is On (Reloaded Systems), it gets Kanto Reloaded's subclass of it
# (UI/PCScene.rb). PIF's own PokemonStorageScreen still runs every rule (the
# last Pokémon, mail, rentals, the Transfer Box, fusing, autosaves), and
# KIF's and other mods' hooks on it still run: Kuray Actions and KIF's box
# commands arrive in the lists the scene draws. So every way into the PC
# works: the PC itself, the Box Link, KIF's pause-menu PC, choosing a
# Pokémon from the PC, the Purify Chamber, KIF's Nuzlocke Graveyard.
#
# If Kanto Reloaded's scene fails during a visit, it puts a held Pokémon
# back, hands the rest of the visit to the game's own scene and logs why;
# the game's PC opens from then on until the game restarts.
#
# A mod can add an action to the PC (Step 2, the Actions): a Pokémon's
# (in its Actions, or under a heading in RLD Actions with :group) or a
# box's (in the box's actions). A nil label hides it; a disabled one shows
# dimmed with its reason.
#
#   Reloaded::PC.add_action(:id, :label => "Name" or proc { |pkmn| ... },
#     :description => "...", :group => nil or "Heading", :scope => :pokemon or :box,
#     :enabled => proc { |pkmn| true }, :disabled_reason => "Why not.") do |screen, pkmn, selected, heldpoke|
#     ...                                  # a box's: do |screen| ... end
#   end
#==============================================================================

module Reloaded
  module PC
    TOGGLE = :"systems.reloaded_pc"
    # KIF Beta's labels as Kanto Reloaded names them (as the Party Screen);
    # the rest of the game's lowercase labels in Title Case
    RENAMES = { "Kuray Actions" => "RLD Actions", "Sort (all Boxes)" => "Sort (All Boxes)",
                "Export All Pokemons" => "Export All Pokémon", "Export this Box" => "Export This Box" }.freeze
    # KIF's Kuray Actions under RLD Actions' headings (his pick: Headings in
    # the List); one a mod adds to KIF's list goes under More
    KIF_GROUPS = { :export => "Export", :export_all => "Export", :evolock => "Evolution", :shiny_gamble => "Shiny",
                   :shiny_sell => "Shiny", :shiny_define => "Shiny" }.freeze
    GROUP_ORDER = ["Export", "Evolution", "Shiny"].freeze
    Action = Struct.new(:id, :label, :description, :group, :scope, :enabled, :reason, :handler, :order, :index)
    @actions = []

    class << self
      # Set once Kanto Reloaded's scene has failed: the game's PC for the rest
      # of the session
      attr_accessor :failed
      # Where the cursor was when the PC last closed (his pick, Remember
      # Where You Were: the box is PIF's own currentBox, the slot is kept
      # for the session)
      attr_accessor :last_focus

      def boot
        register_settings
        install
        add_action(:mark, :label => "Mark", :description => "Mark it with shapes.", :order => 10) do |screen, _pkmn, selected, heldpoke|
          screen.pbMark(selected, heldpoke)
        end
        return true
      end

      #------------------------------------------------------------------------
      # Actions (Step 2)
      #------------------------------------------------------------------------
      def add_action(id, label:, description: "", group: nil, scope: :pokemon, enabled: nil, disabled_reason: nil, order: 100, &handler)
        @actions.reject! { |a| a.id == id.to_sym }
        @actions << Action.new(id.to_sym, label, description.to_s, group ? group.to_s : nil, scope.to_sym, enabled, disabled_reason,
                               handler, order, @actions.length)
        return id.to_sym
      end

      def remove_action(id)
        @actions.reject! { |a| a.id == id.to_sym }
      end

      # [[action, label, enabled, reason]] shown for a Pokémon (:pokemon) or a
      # box (:box, its screen)
      def actions(scope, subject)
        list = @actions.select { |a| a.scope == scope }.sort_by { |a| [a.order, a.index] }
        return list.map do |a|
          label = call_or(a.label, subject, a.id)
          next nil unless label
          on = a.enabled.nil? ? true : (call_or(a.enabled, subject, a.id) ? true : false)
          [a, _INTL(label.to_s), on, on ? nil : call_or(a.reason, subject, a.id).to_s]
        end.compact
      end

      def call_or(value, subject, id)
        return value.respond_to?(:call) ? value.call(subject) : value
      rescue StandardError => e
        Reloaded::Log.warning_once("A PC action's label or check failed (#{id}): #{e.message}", :pc)
        return nil
      end

      # Which heading one of KIF's Kuray Actions goes under
      def kif_group(id)
        id = id.to_s.to_sym
        return KIF_GROUPS[id] if KIF_GROUPS.key?(id)
        return "Shiny" if id.to_s.start_with?("shiny_")
        return "More"
      end

      def register_settings
        Reloaded::Settings.register(TOGGLE, :page => :systems, :priority => 34, :type => :toggle, :default => true, :preset => false,
          :name => "Reloaded PC",
          :description => "Kanto Reloaded's PC: The whole box with its details, one press to move, in every place the game opens the PC. Off shows the game's own.")
      end

      def enabled?
        return Reloaded::Settings.get(TOGGLE) ? true : false
      rescue StandardError
        return false
      end

      def active?
        return enabled? && !@failed && Reloaded::Pixel.available? && defined?(Reloaded::PCScene) ? true : false
      end

      def install
        return if @installed || !defined?(::PokemonStorageScene)
        @installed = true
        Reloaded::Hooks.prepend(nil, ::PokemonStorageScene.singleton_class, SceneChoice, :id => :reloaded_pc_scene)
      end

      # Kanto Reloaded's scene class: a subclass of the game's, made the
      # first time it's needed (every mod's changes to the game's class are
      # in by then). What watches the game's PC scene (Recent Steps, the
      # Timing Profiler) watches ours too.
      def scene_class
        return @scene_class if @scene_class
        k = Class.new(::PokemonStorageScene) { include Reloaded::PCScene }
        Reloaded::Hooks.scene_class(::PokemonStorageScene, k)
        return @scene_class = k
      end

      # The game's scene, past Kanto Reloaded's choice (the fallback)
      def game_scene
        return ::PokemonStorageScene.allocate.tap { |s| s.send(:initialize) }
      end

      def rename(label)
        l = label.to_s
        return _INTL(RENAMES[l]) if RENAMES.key?(l)
        return defined?(Reloaded::PartyScreen) ? Reloaded::PartyScreen.title_case(l) : l
      end

      # What an action in the PC's menus does, for the line under it
      def describe(label, pkmn = nil)
        name = pkmn ? pkmn.name : ""
        words = {
          _INTL("Move") => _INTL("Pick it up to move it."),
          _INTL("Place") => _INTL("Put it down here."),
          _INTL("Shift") => _INTL("Swap it with the one here."),
          _INTL("Summary") => _INTL("{1}'s details.", name),
          _INTL("Fuse") => _INTL("Fuse it with another Pokémon, with a Splicer."),
          _INTL("Unfuse") => _INTL("Split it back into two Pokémon."),
          _INTL("Reverse") => _INTL("Swap its head and body."),
          _INTL("Nickname") => _INTL("Give it a nickname, or take it off."),
          _INTL("Withdraw") => _INTL("Take it into your party."),
          _INTL("Store") => _INTL("Put it in a box."),
          _INTL("Item") => _INTL("Give it an item to hold, or take its item."),
          _INTL("Mark") => _INTL("Mark it with shapes."),
          _INTL("Release") => _INTL("Let it go. It won't come back."),
          _INTL("RLD Actions") => _INTL("Export it, and Kanto Reloaded's other actions."),
          _INTL("Debug") => _INTL("Debug options for it."),
          _INTL("Select") => _INTL("Choose this one."),
          _INTL("Choose") => _INTL("Choose this one."),
          _INTL("Jump") => _INTL("Go to another box."),
          _INTL("Select All") => _INTL("Select everything in this box."),
          _INTL("Wallpaper") => _INTL("Change this box's wallpaper."),
          _INTL("Name") => _INTL("Rename this box."),
          _INTL("Info") => _INTL("How the Transfer Box works."),
          _INTL("Sort") => _INTL("Sort this box, or every box that isn't locked."),
          _INTL("Export") => _INTL("Save it to a file."),
          _INTL("Export All Pokémon") => _INTL("Save every Pokémon in your boxes to files."),
          _INTL("Lock Evolution") => _INTL("Keep it from evolving."),
          _INTL("Unlock Evolution") => _INTL("Let it evolve again."),
          _INTL("Sell Shininess") => _INTL("Sell its shine for money."),
          _INTL("Lock Sorting") => _INTL("Sort leaves this box as it is."),
          _INTL("Unlock Sorting") => _INTL("Sort can change this box again."),
          _INTL("Lock Exporting") => _INTL("Exporting leaves this box out."),
          _INTL("Unlock Exporting") => _INTL("Exporting takes this box again."),
          _INTL("Buy Box") => _INTL("Buy another box."),
          _INTL("Sort (All Boxes)") => _INTL("Sort every box that isn't locked."),
          _INTL("Battle") => _INTL("Battle with this box's Pokémon."),
          _INTL("Export This Box") => _INTL("Save this box's Pokémon to files."),
          _INTL("Export All") => _INTL("Save every box's Pokémon to files."),
          _INTL("Import") => _INTL("Bring Pokémon in from files."),
          _INTL("Import Randomly") => _INTL("Bring random Pokémon in from files."),
          _INTL("Continue Fusing") => _INTL("Keep choosing who to fuse with."),
          _INTL("Stop Fusing") => _INTL("Put the Splicer away."),
          _INTL("Cancel") => _INTL("Back to the box.")
        }
        return words[label.to_s] || ""
      end
    end

    # The game makes its PC scene: Kanto Reloaded's, while it's on
    module SceneChoice
      def new(*args, &block)
        if equal?(::PokemonStorageScene) && Reloaded::PC.active?
          begin
            return Reloaded::PC.scene_class.new(*args, &block)
          rescue Exception => e
            raise if Reloaded::Hooks.passthrough?(e)
            Reloaded::Log.exception("The Reloaded PC didn't open; the game's own instead", e, :pc)
          end
        end
        super
      end
    end
  end
end
