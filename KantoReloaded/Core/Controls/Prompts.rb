#==============================================================================
# Kanto Reloaded: button prompts
#==============================================================================
# Which button names the hints show. Kanto Reloaded is controller-first:
# hints name controller buttons while a controller is in use, and keyboard
# keys otherwise; Button Prompts can force either. (The Controls feature will
# replace these with the player's own bindings and button icons.)
#
# Keyboard names come from the player's key bindings (KIF::Keys reads them
# from keybindings.mkxp1). Controller names are PIF's default layout
# (Data/keybindings.mkxp1): A = Use, B = Back, X = Action, Y = Input::X,
# LB/RB = L/R, left stick click = Input::Y, right stick click = Input::Z.
#==============================================================================

module Reloaded
  module Prompts
    PAD_NAMES = { :C => "A", :B => "B", :A => "X", :X => "Y", :Y => "LS", :Z => "RS", :L => "LB", :R => "RB" }.freeze
    KEY_DEFAULTS = { :C => "C", :B => "X", :A => "Z", :X => "A", :Y => "S", :Z => "D", :L => "Q", :R => "W" }.freeze

    class << self
      def register_settings
        Reloaded::Settings.register(:"interface.button_prompts", :page => :interface, :priority => 90,
          :name => "Button Prompts", :type => :enum, :default => 0, :values => ["Auto", "Controller", "Keyboard"],
          :description => "Which buttons the hints name. Auto shows controller buttons while a controller is connected.")
      end

      # True when hints should name controller buttons. With Reloaded
      # Controls on, Auto follows what the player used last.
      def controller?
        case Reloaded::Settings.get(:"interface.button_prompts").to_i
        when 1 then return true
        when 2 then return false
        end
        return Reloaded::Controls.device == :controller if controls?
        return controller_state == true
      end

      # Game buttons (:C...) as Reloaded Controls' actions
      ACTIONS = { :C => :confirm, :B => :back, :A => :action, :Z => :special, :X => :x, :Y => :y,
                  :L => :page_left, :R => :page_right }.freeze

      def controls?
        return defined?(Reloaded::Controls) && Reloaded::Controls.active?
      end

      # true or false when mkxp-z can tell whether a controller is
      # connected, nil when it can't.
      def controller_state
        return nil unless defined?(Input::Controller) && Input::Controller.respond_to?(:connected?)
        return !!Input::Controller.connected?
      rescue Exception
        return nil
      end

      # The input a hint shows for a game button (:C, :B, :A...), on the
      # keyboard or the controller in use: a Reloaded Controls input ("k:6",
      # "p:0") for ButtonIcons, or nil. With Reloaded Controls off, the
      # engine's own binding (F1).
      def input(button)
        side = controller? ? :pad : :keys
        if controls? && ACTIONS[button]
          token = pick(Reloaded::Controls.bindings(ACTIONS[button], side), side)
          return Reloaded::Controls.shown_input(token) if token
        end
        return nil unless defined?(Reloaded::Controls::Inputs) && Input.const_defined?(button)
        e = Reloaded::Controls::Inputs.engine_bindings[Input.const_get(button)]
        return e ? pick(e[side], side) : nil
      end

      # A keyboard hint shows the shortest of the keys ("Z", not "Left Shift");
      # a controller one, the first button.
      def pick(tokens, side)
        return tokens.first if side == :pad || tokens.length < 2
        return tokens.min_by { |t| [Reloaded::Controls::Inputs.label(t).length, tokens.index(t)] }
      end

      # :xbox, :playstation or :nintendo: the controller in use.
      def style
        return defined?(Reloaded::Controls::Layer) ? Reloaded::Controls::Layer.style : :xbox
      end

      # The name of a game button (:C, :B, :A, :X, :Y, :Z, :L, :R) for hints.
      def name(button)
        if controls? && ACTIONS[button]
          label = Reloaded::Controls.label(ACTIONS[button], controller? ? :controller : :keyboard)
          return label unless label.empty?
        end
        return PAD_NAMES[button] || button.to_s if controller?
        if defined?(::KIF::Keys) && Input.const_defined?(button)
          label = (::KIF::Keys.label(Input.const_get(button)) rescue nil)
          return label if label
        end
        return KEY_DEFAULTS[button] || button.to_s
      end
    end
  end
end

Reloaded::Prompts.register_settings
