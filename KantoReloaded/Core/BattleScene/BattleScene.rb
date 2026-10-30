# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Battle Scene
#==============================================================================
# Roadmap topic battle-ui (Wave 6; his picks 2026-10-17 and 2026-10-29),
# EBDX's battle screen made Kanto Reloaded's:
#
#   the cursor     the Reloaded ring (UI/BattleCursor.rb) on EBDX's command
#                  row, Bag, target window and Fight menu in place of its
#                  red brackets; a Battle Cursor row gives EBDX's back
#   spread moves   a ring on every Pokémon the move will hit (EBDX marked
#                  the user's own dimmed button)
#   target icons   every target's small icon centred on its button (EBDX cut
#                  the top 20 px off), a fusion's real icon (EBDX drew the
#                  DNA placeholder for all of them); BattleScene/TargetIcons.rb
#   hint chips     the Battle Menu's button (and any shortcut bound) as chips
#                  over the command row, or in PIF's message box (UI/HintChips.rb)
#   command row    EBDX's Own, Plates (the default), Slim Bar or Corner Panel
#                  (UI/CommandRow.rb)
#
# EBDX's Move List stays EBDX's own (his call), with the Reloaded cursor; the
# move overlap fix is in Fixes (Fixes/EBDXMoveLayers.rb), always on. A
# feature with a switch, On: Off gives EBDX back as it ships. EBDX's code is
# never edited: its windows get prepends that call up, and each window keeps
# what Kanto Reloaded added in one object (@kr_scene), made when the window
# draws, read each frame with no lookups.
#==============================================================================

module Reloaded
  module BattleScene
    FEATURE = :battle_scene
    PAGE = :battle_scene
    CURSOR = :"battle_scene.cursor"
    HINTS = :"battle_scene.hints"
    ROW = :"battle_scene.command_row"
    CURSORS = ["Reloaded", "EBDX's Own"].freeze
    ROWS = ["EBDX's Own", "Plates", "Slim Bar", "Corner Panel"].freeze
    ROW_KINDS = [:ebdx, :plates, :slim, :corner].freeze
    COLOUR_KEYS = ["interface.cursor_color", "interface.theme"].freeze

    class << self
      def boot
        register_settings
        Reloaded::Features.register(FEATURE, :name => "Battle Scene", :page => PAGE, :order => 58,
          :description => "EBDX's battle screen made Kanto Reloaded's: The Reloaded cursor, a ring on every Pokémon a move will hit, " \
                          "real fusion icons when you pick a target, button hints and a choice of command rows.")
        Reloaded::Events.on(:setting_changed, :battle_scene_cursor_colour) do |e|
          key = e.is_a?(Hash) ? e[:key].to_s : ""
          Reloaded::BattleCursor.reset if COLOUR_KEYS.include?(key) || key == Reloaded::Palette::MODE.to_s
        end
        install
        return true
      end

      def register_settings
        s = Reloaded::Settings
        s.register_page(PAGE, :group => :general, :name => "Battle Scene", :icon => :features, :priority => 47,
          :feature => FEATURE,
          :description => "EBDX's battle screen: The cursor, the button hints and the command row.")
        s.register(CURSOR, :page => PAGE, :priority => 10, :type => :enum, :values => CURSORS, :default => 0,
          :name => "Battle Cursor",
          :description => "Reloaded: A ring in your Cursor Color on EBDX's buttons, the Bag and the target window. EBDX's Own: Its red corners.")
        s.register(HINTS, :page => PAGE, :priority => 20, :type => :toggle, :default => true, :name => "Button Hints",
          :description => "The Battle Menu's button, and any Battle Menu shortcut you bound, as hints while you choose Fight, Bag, Pokémon or Run.")
        s.register(ROW, :page => PAGE, :priority => 30, :type => :enum, :values => ROWS, :default => 1,
          :name => "Command Row",
          :description => "How EBDX's Fight, Bag, Party and Run look. Plates: Kanto Reloaded's plates in EBDX's places. " \
                          "Slim Bar: One bar along the bottom. Corner Panel: The four in a corner, what's on the field beside them.")
      end

      def on?
        return Reloaded::Features.on?(FEATURE)
      end

      # The Reloaded ring on EBDX's own windows (read when a window draws)
      def ring?
        return on? && Reloaded::Settings.get(CURSOR).to_i == 0
      end

      def hints?
        return on? && Reloaded::Settings.get(HINTS) != false &&
               defined?(Reloaded::BattleMenu) && Reloaded::BattleMenu.on?
      end

      # :ebdx, :plates, :slim or :corner
      def row
        return :ebdx unless on?
        return ROW_KINDS[Reloaded::Settings.get(ROW).to_i] || :plates
      end

      def ebdx?(scene)
        cw = scene.instance_variable_get(:@commandWindow)
        return defined?(::CommandWindowEBDX) && cw.is_a?(::CommandWindowEBDX) ? true : false
      end

      # Where the Field Strip goes (UI/FieldStrip.rb): nil its usual place,
      # [bottom line's top, right edge], or :none (the Corner Panel draws it)
      def strip_spot(scene)
        return nil unless on? && scene && ebdx?(scene)
        kind = scene.instance_variable_get(:@commandWindow).instance_variable_get(:@kr_scene)&.kind || row
        return :none if kind == :corner
        bottom = kind == :slim ? Reloaded::CommandRow::SLIM_STRIP : Reloaded::FieldStrip::EBDX_BOTTOM
        left = hints? ? Reloaded::HintChips.left_edge(Reloaded::HintChips::EBDX_RIGHT) : nil
        x1 = Reloaded::FieldStrip::X0 + Reloaded::FieldStrip::ROOM
        x1 = [x1, left - 6].min if left
        return [bottom, x1]
      end

      #------------------------------------------------------------------------
      # The hooks
      #------------------------------------------------------------------------
      # Each hook is made only when its target is there (EBDX's classes are
      # in KIF Beta whether EBDX is on or not; tests and the preview tool
      # load what they need)
      def install
        h = Reloaded::Hooks
        hook = proc do |name, mod, id|
          next unless Object.const_defined?(name)
          h.prepend(FEATURE, Object.const_get(name), mod, :id => id)
        end
        hook.call("CommandWindowEBDX", CommandHooks, :battle_scene_command_row)
        hook.call("FightWindowEBDX", FightHooks, :battle_scene_fight)
        hook.call("TargetWindowEBDX", TargetHooks, :battle_scene_target)
        hook.call("BagWindowEBDX", BagHooks, :battle_scene_bag)
        hook.call("SelectorSprite", SelectorHooks, :battle_scene_selector)
        if Object.const_defined?(:PokeBattle_SceneEBDX) && ::PokeBattle_SceneEBDX.method_defined?(:pbChooseTarget)
          h.around(FEATURE, ::PokeBattle_SceneEBDX, :pbChooseTarget, :id => :battle_scene_spread) do |original, *args|
            Reloaded::BattleScene.mark_spread(original.receiver, args[1])
            original.call(*args)
          end
        end
        [["PokeBattle_Scene", :pif], ["PokeBattle_SceneEBDX", :ebdx]].each do |name, tag|
          next unless Object.const_defined?(name) && Object.const_get(name).method_defined?(:pbCommandMenu)
          h.around(FEATURE, Object.const_get(name), :pbCommandMenu, :id => :"battle_scene_hints_#{tag}") do |original, *args|
            Reloaded::BattleScene.with_hints(original.receiver) { original.call(*args) }
          end
        end
        if Object.const_defined?(:PokeBattle_Battle) && ::PokeBattle_Battle.method_defined?(:pbEndOfBattle)
          h.around(FEATURE, ::PokeBattle_Battle, :pbEndOfBattle, :id => :battle_scene_end) do |original, *args|
            Reloaded::HintChips.dispose
            original.call(*args)
          end
        end
      end

      # A battle's first window: the last battle's pictures go
      def new_battle
        Reloaded::BattleCursor.dispose_all
        Reloaded::BattleScene::TargetIcons.reset if defined?(Reloaded::BattleScene::TargetIcons)
      end

      # A spread move (target_data.num_targets isn't 1): every target ringed
      def mark_spread(scene, target_data)
        tw = scene.instance_variable_get(:@targetWindow)
        return unless tw
        spread = target_data.respond_to?(:num_targets) && target_data.num_targets != 1
        tw.instance_variable_set(:@kr_spread, spread)
      rescue StandardError => e
        Reloaded::Log.exception("Battle Scene: a spread move's targets", e, FEATURE)
      end

      # The hint chips while a command box runs (EBDX's rows but the Corner
      # Panel's, which draws its own; PIF's command box)
      def with_hints(scene)
        Reloaded::HintChips.show(scene) if hints? && scene
        return yield
      ensure
        Reloaded::HintChips.hide
      end
    end

    #--------------------------------------------------------------------------
    # EBDX's command row (UI/CommandRow.rb does the drawing)
    #--------------------------------------------------------------------------
    module CommandHooks
      def initialize(*args)
        Reloaded::BattleScene.new_battle if Reloaded::BattleScene.on?
        super
      end

      def compileCommands(*args)
        ret = super
        @kr_labels = ret
        return ret
      end

      def refreshCommands(index)
        super
        unless Reloaded::BattleScene.on?
          @kr_scene&.dispose
          @kr_scene = nil
          return
        end
        begin
          (@kr_scene ||= Reloaded::CommandRow.new(self)).refresh(index, @kr_labels || [])
        rescue StandardError => e
          Reloaded::Log.exception("Battle Scene: the command row couldn't be drawn", e, Reloaded::BattleScene::FEATURE)
          @kr_scene&.dispose
          @kr_scene = nil
        end
      end

      def update
        super
        @kr_scene.update(@index) if @kr_scene
      end

      def show
        super
        @kr_scene.slide(-10) if @kr_scene
      end

      def hide(skip = false)
        super
        @kr_scene.slide(10) if @kr_scene && !skip
      end

      # The Corner Panel is a 2 x 2: Up and Down move a row (EBDX's loop
      # moves one either way, 021_EBDX_CursorMemory.rb)
      def index=(value)
        if @kr_scene && @kr_scene.kind == :corner && value.is_a?(Integer) && @index.is_a?(Integer) &&
           !Input.trigger?(Input::LEFT) && !Input.trigger?(Input::RIGHT)
          n = (@indexes || []).length
          if n == 4 && Input.trigger?(Input::UP)
            value = (@index + 2) % 4
          elsif n == 4 && Input.trigger?(Input::DOWN)
            value = (@index + 2) % 4
          end
        end
        super(value)
      end

      def dispose
        @kr_scene.dispose if @kr_scene
        @kr_scene = nil
        super
      end
    end

    #--------------------------------------------------------------------------
    # EBDX's Fight menu: the Reloaded ring round the picked move
    #--------------------------------------------------------------------------
    module FightHooks
      def generateButtons(*args)
        super
        if Reloaded::BattleScene.ring?
          @kr_scene ||= Reloaded::BattleCursor::Ring.new(@viewport, 199, :edge)
        elsif @kr_scene
          @kr_scene.dispose
          @kr_scene = nil
        end
      end

      def update
        super
        ring = @kr_scene
        return unless ring
        @sel.visible = false if @sel
        b = @button && @button["#{@index}"]
        b ? ring.follow(b) : ring.hide
      end

      def show
        super
        @kr_scene.hide if @kr_scene
      end

      def hide
        super
        @kr_scene.hide if @kr_scene
      end

      def dispose
        @kr_scene.dispose if @kr_scene
        @kr_scene = nil
        super
      end
    end

    #--------------------------------------------------------------------------
    # EBDX's target window: rings (one, or every target of a spread move)
    # and the targets' pictures
    #--------------------------------------------------------------------------
    module TargetHooks
      def initialize(*args)
        super
        @sel.instance_variable_set(:@kr_sel, :blank) if @sel && Reloaded::BattleScene.ring?
      end

      def refresh(texts)
        super
        return unless Reloaded::BattleScene.on?
        begin
          Reloaded::BattleScene::TargetIcons.redraw(self, texts) if defined?(Reloaded::BattleScene::TargetIcons)
          (@kr_scene ||= Reloaded::BattleScene::TargetRings.new(self)).refresh(texts, @kr_spread)
        rescue StandardError => e
          Reloaded::Log.exception("Battle Scene: the target window", e, Reloaded::BattleScene::FEATURE)
        end
      end

      def update
        super
        @kr_scene.update(@index) if @kr_scene
      end

      def hidePlay
        @kr_scene.hide if @kr_scene
        super
      end

      def dispose
        @kr_scene.dispose if @kr_scene
        @kr_scene = nil
        super
      end
    end

    class TargetRings
      def initialize(win)
        @win = win
        @buttons = win.instance_variable_get(:@buttons)
        @viewport = win.instance_variable_get(:@viewport)
        @rings = []
      end

      def refresh(texts, spread)
        @buttons = @win.instance_variable_get(:@buttons)
        @on = Reloaded::BattleScene.ring?
        @spread = spread ? true : false
        @valid = []
        texts.each_with_index { |t, i| @valid << i unless t.nil? }
        want = @on ? (@spread ? [@valid.length, 1].max : 1) : 0
        @rings.pop.dispose while @rings.length > want
        @rings << Reloaded::BattleCursor::Ring.new(@viewport, 99_999, :edge) while @rings.length < want
        hide
      end

      def update(index)
        return if @rings.empty?
        if @spread
          @valid.each_with_index { |i, k| @rings[k].follow(@buttons["#{i}"]) }
        else
          @rings[0].follow(@buttons["#{index}"])
        end
      end

      def hide
        @rings.each(&:hide)
      end

      def dispose
        @rings.each(&:dispose)
        @rings = []
      end
    end

    #--------------------------------------------------------------------------
    # EBDX's Bag and the target window: their selectors (SelectorSprite)
    #--------------------------------------------------------------------------
    module BagHooks
      def initialize(*args)
        super
        sel = @sprites && @sprites["sel"]
        sel.instance_variable_set(:@kr_sel, :ring) if sel && Reloaded::BattleScene.ring?
      end

      def clearSel
        super
        sel = @sprites && @sprites["sel"]
        return unless sel && sel.instance_variable_get(:@kr_sel)
        sel.instance_variable_set(:@kr_cleared, true)
        sel.instance_variable_get(:@kr_ring)&.hide
      end

      def visible=(value)
        super
        sel = @sprites && @sprites["sel"]
        sel.instance_variable_get(:@kr_ring)&.hide if sel && !value
      end
    end

    # A selector Kanto Reloaded took over (:ring follows its anchor with the
    # Reloaded ring; :blank only hides it, its window rings its own) draws
    # nothing: its brackets are cleared each time it's drawn for a button
    module SelectorHooks
      def render(*args)
        super
        bitmap.clear if @kr_sel && bitmap && !bitmap.disposed?
      end

      def target(sprite)
        @kr_cleared = false if @kr_sel
        super
      end

      def update
        super
        return unless @kr_sel == :ring
        @kr_ring ||= Reloaded::BattleCursor::Ring.new(viewport, z, :edge)
        @kr_cleared || anchor.nil? ? @kr_ring.hide : @kr_ring.follow(anchor)
      end

      def dispose
        @kr_ring.dispose if @kr_ring
        @kr_ring = nil
        super
      end
    end
  end
end
