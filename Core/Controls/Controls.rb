#==============================================================================
# Kanto Reloaded: Reloaded Controls
#==============================================================================
# Every action the player can bind, with a keyboard and a controller side,
# and the Reloaded Controls toggle (Reloaded Systems, On by default):
#
#   On   Kanto Reloaded reads the keys and controller buttons itself (the
#        Layer) and decides what each one does
#   Off  the game's own controls, exactly: the engine's bindings (F1),
#        no extra actions
#
# The F1 bindings are never written. The game's buttons start on the
# player's own F1 layout and follow it until rebound here, so turning
# Reloaded Controls On changes nothing until the player changes something.
#
# Actions belong to an area: Global, Overworld, Menus or Battle. A
# button may do different things in different areas; the Controls screen
# warns when two actions share one in the same area (or with Global).
#
# For mods:
#
#   Reloaded::Controls.register(:my_mod_menu, :name => "My Menu", :area => :overworld,
#     :group => "Menus", :keys => ["k:63"], :pad => [], :description => "Opens My Menu.",
#     :owner => :my_mod)
#   Reloaded::Controls.trigger?(:my_mod_menu)        # also press?, repeat?, release?
#
#   :follows => :confirm  starts the action on another action's buttons
#                         (it keeps following them until rebound)
#   :button => Input::C   a game button: the engine's binding is the default
#   :group => "Menus"     the heading it's listed under on the Controls screen
#
# While Reloaded Controls is Off, an action that follows a game button reads
# that button; other actions don't fire.
#==============================================================================

module Reloaded
  module Controls
    TOGGLE = :"systems.reloaded_controls"
    FILE = "Controls.json"
    SCHEMA = 1
    AREAS = [:global, :overworld, :menus, :battle].freeze
    SIDES = [:keys, :pad].freeze
    STEPS_PER_SECOND = 40          # game steps (Input.update) per second at the logic rate
    # Menu Repeat Speed: [steps before a held button repeats, then every n steps]
    REPEAT = [[20, 6], [16, 4], [12, 3], [8, 2]].freeze
    HOLD_SECONDS = [0.2, 0.3, 0.4, 0.5, 0.6, 0.8, 1.0].freeze
    PERCENTS = (1..9).map { |i| i * 10 }.freeze

    Action = Struct.new(:id, :name, :area, :button, :follows, :keys, :pad, :description, :owner, :priority, :group)
    AREA_NAMES = { :global => "Global", :overworld => "Overworld", :menus => "Menus", :battle => "Battle" }.freeze
    # The Feel settings, in the order the Controls screen lists them
    FEEL = [:"controls.button_style", :"controls.swap_ab", :"controls.repeat", :"controls.hold_time",
            :"controls.trigger_press", :"controls.deadzone"].freeze

    # The game's own buttons: [id, Input constant, name, heading, what uses it]
    GAME_BUTTONS = [
      [:up,         :UP,    "Up",         "Movement", "Move up; up in menus."],
      [:down,       :DOWN,  "Down",       "Movement", "Move down; down in menus."],
      [:left,       :LEFT,  "Left",       "Movement", "Move left; left in menus, change a value."],
      [:right,      :RIGHT, "Right",      "Movement", "Move right; right in menus, change a value."],
      [:confirm,    :C,     "Confirm",    "Buttons",  "Talk, interact and confirm (the game's Use button)."],
      [:back,       :B,     "Back",       "Buttons",  "Cancel and go back."],
      [:action,     :A,     "Action",     "Buttons",  "Each screen's extra action."],
      [:special,    :Z,     "Special",    "Buttons",  "Each screen's special action."],
      [:x,          :X,     "X",          "Buttons",  "Extra actions on some screens."],
      [:y,          :Y,     "Y",          "Buttons",  "Extra actions on some screens."],
      [:page_left,  :L,     "Page Left",  "Buttons",  "Previous page or tab."],
      [:page_right, :R,     "Page Right", "Buttons",  "Next page or tab."]
    ].freeze

    # Actions whose inputs are never left empty: a side (keyboard or
    # controller) left unbound uses the engine's (F1), so the player can
    # always move, confirm and go back on whatever they play with.
    ESSENTIAL = [:up, :down, :left, :right, :confirm, :back].freeze

    @actions = {}
    @custom = nil
    @version = 0

    # KIF's key names (990_KIF/000_Core/018: the hints and "{ACTION}" in
    # descriptions on KIF's screens) name Reloaded Controls' bindings while
    # it's on.
    module KIFKeyNames
      def label(button, default = nil)
        return Reloaded::Controls.button_label(button) || super
      end

      def short(button)
        return Reloaded::Controls.button_label(button) || super
      end
    end

    class << self
      attr_reader :version

      def register_settings
        s = Reloaded::Settings
        s.register(TOGGLE, :page => :systems, :priority => 10,
          :name => "Reloaded Controls", :type => :toggle, :default => true, :preset => false,
          :description => "Kanto Reloaded's Controls: Rebind every action on keyboard and controller. Off uses the game's own controls (F1).")
        s.register_page(:controls, :group => :general, :name => "Controls", :icon => :controls, :priority => 30,
          :visible => proc { Reloaded::Controls.enabled? },
          :description => "Your controls and how they feel. Reloaded Controls has to be On.")
        s.register(:"controls.open", :page => :controls, :priority => 0, :preset => false,
          :name => "Change Controls", :type => :button,
          :on_press => proc { Reloaded::ControlsScreen.open if defined?(Reloaded::ControlsScreen) },
          :description => "Rebind every action, on keyboard and controller.")
        s.register(:"controls.swap_ab", :page => :controls, :priority => 10,
          :name => "Swap A and B", :type => :toggle, :default => false,
          :description => "Confirm and Back trade places on the controller, as on Nintendo controllers. Hints follow the swap.")
        s.register(:"controls.repeat", :page => :controls, :priority => 20,
          :name => "Menu Repeat Speed", :type => :enum, :default => 1, :values => ["Slow", "Normal", "Fast", "Faster"],
          :description => "How soon a held button starts repeating in menus, and how fast it repeats.")
        s.register(:"controls.hold_time", :page => :controls, :priority => 30,
          :name => "Hold Time", :type => :enum, :default => 2, :values => HOLD_SECONDS.map { |v| "#{v} s" },
          :description => "How long a press has to last to count as a hold, for buttons with a hold action.")
        s.register(:"controls.trigger_press", :page => :controls, :priority => 40,
          :name => "Trigger Press", :type => :enum, :default => 4, :values => PERCENTS.map { |v| "#{v}%" },
          :description => "How far a controller trigger has to be pressed to count.")
        s.register(:"controls.button_style", :page => :controls, :priority => 5,
          :name => "Button Style", :type => :enum, :default => 0, :values => ["Auto", "Xbox", "PlayStation", "Nintendo"],
          :description => "Which controller's buttons hints and Controls show. Auto goes by the controller's name.")
        s.register(:"controls.deadzone", :page => :controls, :priority => 50,
          :name => "Stick Deadzone", :type => :enum, :default => 4, :values => PERCENTS.map { |v| "#{v}%" },
          :description => "How far a stick has to move to count. Raise it for a worn stick that drifts.")
      end

      # The game's buttons as actions.
      def register_game_buttons
        GAME_BUTTONS.each_with_index do |(id, const, name, group, desc), i|
          next unless Input.const_defined?(const)
          register(id, :name => name, :area => :global, :button => Input.const_get(const), :group => group,
                   :description => desc, :owner => :game, :priority => i)
        end
      end

      def area_name(area)
        return _INTL(AREA_NAMES[area.to_sym] || area.to_s)
      end

      #------------------------------------------------------------------------
      # Actions
      #------------------------------------------------------------------------
      def register(id, options = {})
        id = id.to_sym
        area = (options[:area] || :global).to_sym
        raise ArgumentError, "Control #{id} names unknown area #{area}" unless AREAS.include?(area)
        keys = Array(options[:keys]).map(&:to_s)
        pad = Array(options[:pad]).map(&:to_s)
        (keys + pad).each { |t| raise ArgumentError, "Control #{id}: #{t.inspect} isn't an input" unless Inputs.valid?(t) }
        @actions[id] = Action.new(id, options[:name] || id.to_s, area, options[:button],
                                  options[:follows] ? options[:follows].to_sym : nil, keys, pad,
                                  options[:description].to_s, (options[:owner] || :kanto_reloaded).to_sym,
                                  options[:priority] || 100, (options[:group] || "Other").to_s)
        changed
        return id
      end

      def action(id)
        return @actions[id.to_sym]
      end

      def actions(area = nil)
        list = @actions.values
        list = list.select { |a| a.area == area.to_sym } if area
        return list.sort_by { |a| [AREAS.index(a.area), a.priority, a.name] }
      end

      # The game button an action drives, or nil.
      def button_action(button)
        return @actions.values.find { |a| a.button == button }
      end

      #------------------------------------------------------------------------
      # Bindings
      #------------------------------------------------------------------------
      # An action's inputs on one side (:keys or :pad): the player's own, or
      # what it follows, or the engine's (game buttons), or its defaults.
      def bindings(id, side, seen = [])
        a = action(id)
        return [] unless a && !seen.include?(a.id)
        own = custom.dig(a.id.to_s, side.to_s)
        return own.dup if own.is_a?(Array)
        return bindings(a.follows, side, seen + [a.id]) if a.follows
        if a.button
          list = (Inputs.engine_bindings[a.button] || {})[side] || []
          return list.dup
        end
        return (side == :keys ? a.keys : a.pad).dup
      end

      def all_bindings(id)
        return bindings(id, :keys) + bindings(id, :pad)
      end

      def customized?(id, side = nil)
        entry = custom[id.to_s]
        return false unless entry.is_a?(Hash)
        return entry.key?(side.to_s) if side
        return !entry.empty?
      end

      # Binds an action's side to these inputs (an empty list unbinds it).
      def bind(id, side, tokens)
        raise ArgumentError, "No control #{id}" unless action(id)
        raise ArgumentError, "Side must be :keys or :pad" unless SIDES.include?(side.to_sym)
        tokens = Array(tokens).map(&:to_s).uniq
        tokens.each { |t| raise ArgumentError, "#{t.inspect} isn't an input" unless Inputs.valid?(t) }
        tokens.each { |t| raise ArgumentError, "#{Inputs.label(t)} is the engine's own key" if Inputs.reserved?(t) }
        (custom[id.to_s] ||= {})[side.to_s] = tokens
        save
        changed
      end

      # Back to the default (one side, or both).
      def reset(id, side = nil)
        entry = custom[id.to_s]
        return unless entry
        side ? entry.delete(side.to_s) : entry.clear
        custom.delete(id.to_s) if entry.empty?
        save
        changed
      end

      def reset_all
        @custom = {}
        save
        changed
      end

      # Every action of one area back to its default (Reset Section).
      def reset_area(area)
        ids = actions(area).map { |a| a.id.to_s }
        ids.each { |id| custom.delete(id) }
        save
        changed
      end

      # What every action is bound to now, for a layout:
      # {"confirm" => {"keys" => [...], "pad" => [...]}, ...}
      def layout_bindings
        out = {}
        actions.each { |a| out[a.id.to_s] = { "keys" => bindings(a.id, :keys), "pad" => bindings(a.id, :pad) } }
        return out
      end

      # One side (:keys or :pad) of every action back to its default, then
      # these bindings on it ({id => [tokens]}): a built-in layout for the
      # controller that leaves the keyboard as it is. Actions this game
      # doesn't have and bad inputs are skipped.
      def apply_side(side, bindings)
        custom.each_value { |entry| entry.delete(side.to_s) }
        custom.delete_if { |_id, entry| entry.empty? }
        bindings.each do |id, tokens|
          next unless action(id)
          list = Array(tokens).map(&:to_s).select { |t| Inputs.valid?(t) && !Inputs.reserved?(t) }.uniq
          (custom[id.to_s] ||= {})[side.to_s] = list
        end
        save
        changed
      end

      # Puts a layout's bindings on: every action back to its default, then
      # the layout's inputs where they differ from it (so what matches the
      # default keeps following F1). Actions this game doesn't have, bad
      # inputs and the engine's own keys are skipped, and Confirm, Back and
      # the directions keep their default on a side the layout leaves empty.
      def apply_layout(layout)
        @custom = {}
        actions.sort_by { |a| a.follows ? 1 : 0 }.each do |a|      # what they follow first
          sides = layout[a.id.to_s]
          next unless sides.is_a?(Hash)
          SIDES.each do |side|
            list = sides[side.to_s]
            next unless list.is_a?(Array)
            list = list.map(&:to_s).select { |t| Inputs.valid?(t) && !Inputs.reserved?(t) }.uniq
            next if ESSENTIAL.include?(a.id) && list.none? { |t| !Inputs.hold?(t) }
            next if list.sort == bindings(a.id, side).sort
            (@custom[a.id.to_s] ||= {})[side.to_s] = list
          end
        end
        save
        changed
      end

      # Actions in the same area (or Global) that share an input with
      # this one: [[action, token], ...]. Actions that share it because they
      # follow the same one (as the game's features do today) don't clash.
      def clashes(id)
        a = action(id)
        return [] unless a
        out = []
        SIDES.each do |side|
          mine = bindings(id, side)
          next if mine.empty?
          root = root_on(a.id, side)
          @actions.each_value do |o|
            next if o.id == a.id
            next unless o.area == a.area || o.area == :global || a.area == :global
            next if root_on(o.id, side) == root
            (bindings(o.id, side) & mine).each { |t| out << [o, t] }
          end
        end
        return out
      end

      # The actions that would clash if token were bound to id on a side.
      def clashes_for(id, side, token)
        a = action(id)
        return [] unless a
        root = root_on(a.id, side)
        return @actions.values.select do |o|
          o.id != a.id && (o.area == a.area || o.area == :global || a.area == :global) &&
            root_on(o.id, side) != root && bindings(o.id, side).include?(token)
        end
      end

      # The action whose inputs this one uses on a side: itself, or the end
      # of what it follows while not rebound there.
      def root_on(id, side)
        x = action(id)
        seen = []
        while x && x.follows && !customized?(x.id, side) && !seen.include?(x.id)
          seen << x.id
          x = action(x.follows) || x
        end
        return x ? x.id : id
      end

      #------------------------------------------------------------------------
      # Reading actions
      #------------------------------------------------------------------------
      # True when the setting is On (the layer may still be off for the
      # session if it failed).
      def enabled?
        return Reloaded::Settings.get(TOGGLE) ? true : false
      end

      def active?
        return Layer.active?
      end

      def trigger?(id); return query(:trigger, id); end
      def press?(id);   return query(:press, id);   end
      def repeat?(id);  return query(:repeat, id);  end
      def release?(id); return query(:release, id); end

      # :keyboard or :controller: what the player used last.
      def device
        return Layer.device
      end

      def area
        return Layer.area
      end

      # What a hint should name for an action: its first input on the
      # device in use ("" when it has none).
      def label(id, device = nil)
        device ||= self.device
        style = Layer.style
        order = device == :controller ? [:pad, :keys] : [:keys, :pad]
        order.each do |side|
          token = bindings(id, side).first
          return Inputs.label(shown_input(token), style) if token
        end
        return ""
      end

      # The input as the player presses it: with Swap A and B, a binding on
      # the bottom face button is pressed with the right one.
      def shown_input(token)
        return token unless swap_ab?
        held = Inputs.hold?(token)
        base = Inputs.base(token)
        base = { Inputs.pad(Inputs::PAD_A) => Inputs.pad(Inputs::PAD_B),
                 Inputs.pad(Inputs::PAD_B) => Inputs.pad(Inputs::PAD_A) }.fetch(base, base)
        return held ? Inputs.hold(base) : base
      end

      #------------------------------------------------------------------------
      # Feel
      #------------------------------------------------------------------------
      def repeat_timing
        return REPEAT[Reloaded::Settings.get(:"controls.repeat").to_i] || REPEAT[1]
      end

      def hold_steps
        sec = HOLD_SECONDS[Reloaded::Settings.get(:"controls.hold_time").to_i] || 0.4
        return (sec * STEPS_PER_SECOND).round
      end

      def trigger_threshold
        return (PERCENTS[Reloaded::Settings.get(:"controls.trigger_press").to_i] || 50) / 100.0
      end

      def deadzone
        return (PERCENTS[Reloaded::Settings.get(:"controls.deadzone").to_i] || 50) / 100.0
      end

      def swap_ab?
        return Reloaded::Settings.get(:"controls.swap_ab") ? true : false
      end

      #------------------------------------------------------------------------
      # Storage: <mod folder>\Settings\Controls.json
      #------------------------------------------------------------------------
      def path
        return File.join(Reloaded::Paths.settings_dir, FILE)
      end

      def custom
        load_file unless @custom
        return @custom
      end

      def boot
        register_game_buttons
        Splits.boot
        ExtraActions.boot
        load_file
        if defined?(::KIF::Keys)
          Reloaded::Hooks.prepend(nil, ::KIF::Keys.singleton_class, KIFKeyNames, :id => :controls_kif_key_names)
        end
        return Layer.boot
      end

      # The name a hint shows for a game button while Reloaded Controls is
      # on (the device used last), or nil.
      def button_label(button)
        return nil unless active?
        a = button_action(button)
        return nil unless a
        text = label(a.id, Reloaded::Prompts.controller? ? :controller : :keyboard)
        return text.empty? ? nil : text
      end

      private

      def query(kind, id)
        a = action(id)
        return false unless a
        return Layer.action_state(kind, a.id) if Layer.active?
        # Off: an action on a game button reads that button
        target = a
        seen = []
        while target && !target.button && target.follows && !seen.include?(target.id)
          seen << target.id
          target = action(target.follows)
        end
        return false unless target && target.button
        case kind
        when :trigger then return Input.trigger?(target.button)
        when :press   then return Input.press?(target.button)
        when :repeat  then return Input.repeat?(target.button)
        else return Input.respond_to?(:release?) ? Input.release?(target.button) : false
        end
      end

      def changed
        @version += 1
      end

      def load_file
        @custom = {}
        text = Reloaded::Paths.read_text(path)
        return if text.nil? || text.strip.empty?
        data = Reloaded::JSON.parse(text)
        return unless data.is_a?(Hash) && data["bindings"].is_a?(Hash)
        data["bindings"].each do |id, sides|
          next unless sides.is_a?(Hash)
          entry = {}
          SIDES.each do |side|
            list = sides[side.to_s]
            next unless list.is_a?(Array)
            entry[side.to_s] = list.map(&:to_s).select { |t| Inputs.valid?(t) }
          end
          @custom[id.to_s] = entry unless entry.empty?
        end
      rescue Exception => e
        kept = Reloaded::Paths.set_aside(path)
        Reloaded::Log.exception("Could not read #{FILE}; using the default controls (the file was kept as #{kept ? File.basename(kept) : "it was"})", e, :controls)
        @custom = {}
      ensure
        changed
      end

      def save
        data = { "schema" => SCHEMA, "bindings" => custom.sort.to_h }
        Reloaded::Paths.write_atomic(path, Reloaded::JSON.generate(data, true))
      rescue Exception => e
        Reloaded::Log.exception("Could not write #{FILE}", e, :controls)
      end
    end
  end
end

Reloaded::Controls.register_settings
