#==============================================================================
# Kanto Reloaded - Reloaded PC
#==============================================================================
# KR-owned Pokemon Storage scene and tools.
#==============================================================================

module KantoReloaded
  module PCOrganization
    SETTINGS_ACTION = :pc_organization_settings
    SETTING_KEY = :pc_organization
    SPEED_SETTING = :pc_organization_speed
    ANIMATIONS_SETTING = :pc_organization_animations
    ICONS_SETTING = :pc_organization_icons
    SPEED_VALUES = [1, 2, 3].freeze
    ANIMATION_VALUES = [:off, :reduced, :full].freeze
    ICON_VALUES = [:icons, :full_sprites].freeze
    MENU_BACK = :__pc_organization_back

    @menu_commands = {}
    @pc_session_depth = 0

    class << self
      def install
        settings_ready = register_setting
        storage_ready = register_storage_hook
        ready = settings_ready && storage_ready
        if defined?(KantoReloaded::Log)
          state = ready ? "ready" : "unavailable"
          KantoReloaded::Log.info(
            "Installed Reloaded PC module (#{state})", :modules
          )
        end
        ready
      rescue StandardError => e
        if defined?(KantoReloaded::Log)
          KantoReloaded::Log.exception(
            "Reloaded PC module install failed", e,
            :channel => :pc_organization
          )
        end
        false
      end

      def enabled?
        value = KantoReloaded::Settings.get(SETTING_KEY, 1)
        value == true || (value.respond_to?(:to_i) && value.to_i == 1)
      rescue StandardError
        true
      end

      def pc_speed
        index = KantoReloaded::Settings.get(SPEED_SETTING, 0).to_i
        SPEED_VALUES[index] || SPEED_VALUES.first
      rescue StandardError
        SPEED_VALUES.first
      end

      def animation_mode
        index = KantoReloaded::Settings.get(ANIMATIONS_SETTING, 2).to_i
        ANIMATION_VALUES[index] || :full
      rescue StandardError
        :full
      end

      def icon_mode
        index = KantoReloaded::Settings.get(ICONS_SETTING, 1).to_i
        ICON_VALUES[index] || :full_sprites
      rescue StandardError
        :full_sprites
      end

      def full_sprites?
        icon_mode == :full_sprites
      end

      def pc_session_active?
        @pc_session_depth.to_i > 0
      end

      def with_reloaded_session
        entered = false
        return yield unless enabled?
        outermost = !pc_session_active?
        state = capture_speed_state if outermost
        @pc_session_depth = @pc_session_depth.to_i + 1
        entered = true
        apply_pc_speed_state if outermost
        yield
      ensure
        if entered
          @pc_session_depth = [@pc_session_depth.to_i - 1, 0].max
        end
        if entered && outermost
          restore_speed_state(state)
          refresh_speed_title
        end
      end

      def register_menu_command(id, options = {}, &handler)
        key = id.to_sym
        data = options.is_a?(Hash) ? options.dup : {}
        label = data[:label].to_s.strip
        raise ArgumentError, "PC menu command label is required" if label.empty?
        raise ArgumentError, "PC menu command handler is required" unless handler
        @menu_commands[key] = {
          :id => key,
          :label => label,
          :priority => data.fetch(:priority, 100).to_i,
          :enabled => data[:enabled],
          :handler => handler
        }
        true
      end

      def unregister_menu_command(id)
        !!@menu_commands.delete(id.to_sym)
      rescue StandardError
        false
      end

      def menu_commands
        @menu_commands.values.sort_by do |entry|
          [entry[:priority], entry[:label].downcase, entry[:id].to_s]
        end
      end

      def open_menu(scene)
        return false unless defined?(KantoReloaded::PopupWindow)
        scene.instance_variable_set(:@kr_pc_menu_open, true)
        rows = available_menu_commands(scene).map do |entry|
          { :label => entry[:label], :value => entry[:id] }
        end
        rows << { :label => _INTL("Close"), :value => MENU_BACK }
        selected = KantoReloaded::PopupWindow.choice(
          _INTL("Reloaded PC"), rows
        )
        command = @menu_commands[selected]
        command[:handler].call(scene) if command && command_enabled?(command, scene)
        selected
      rescue StandardError => e
        log_exception("Reloaded PC menu failed", e)
        false
      ensure
        scene.instance_variable_set(:@kr_pc_menu_open, false) if scene
      end

      private

      def register_setting
        return false unless defined?(KantoReloaded::Settings)
        action = KantoReloaded::Settings.register(SETTINGS_ACTION, {
          :name => "Reloaded PC",
          :description => "Configure Kanto Reloaded's Pokemon Storage interface.",
          :type => :button,
          :category => :quality_of_life,
          :owner => :kanto_reloaded,
          :priority => 1020,
          :on_press => proc {
            KantoReloaded::SettingsUI.open_module(
              :pc_organization, :title => "Reloaded PC"
            )
          }
        })
        visible = proc do |context|
          next false unless context.is_a?(Hash)
          module_id = context[:module] || context["module"]
          owner_id = context[:owner] || context["owner"]
          (module_id || owner_id).to_sym == :pc_organization
        rescue StandardError
          false
        end
        toggle = KantoReloaded::Settings.register(SETTING_KEY, {
          :name => "Reloaded PC",
          :description => "Use Kanto Reloaded's PC interface and controls.",
          :type => :toggle,
          :category => :quality_of_life,
          :owner => :pc_organization,
          :value_style => :integer,
          :visible_if => visible,
          :default => 1,
          :priority => 10
        })
        animations = KantoReloaded::Settings.register(ANIMATIONS_SETTING, {
          :name => "Animations",
          :description => "Choose full, reduced, or immediate Reloaded PC transitions.",
          :type => :enum,
          :values => ["Off", "Reduced", "Full"],
          :category => :quality_of_life,
          :owner => :pc_organization,
          :value_style => :integer,
          :visible_if => visible,
          :enabled_if => proc { KantoReloaded::PCOrganization.enabled? },
          :default => 2,
          :priority => 20
        })
        speed = KantoReloaded::Settings.register(SPEED_SETTING, {
          :name => "Speed",
          :description => "Use normal, 2x, or 3x speed in Reloaded PC.",
          :type => :enum,
          :values => ["Off", "2x", "3x"],
          :category => :quality_of_life,
          :owner => :pc_organization,
          :value_style => :integer,
          :visible_if => visible,
          :enabled_if => proc { KantoReloaded::PCOrganization.enabled? },
          :default => 0,
          :priority => 30
        })
        icons = KantoReloaded::Settings.register(ICONS_SETTING, {
          :name => "Icons",
          :description => "Show Pokemon icons or full sprites in Reloaded PC slots.",
          :type => :enum,
          :values => ["Icons", "Full Sprites"],
          :category => :quality_of_life,
          :owner => :pc_organization,
          :value_style => :integer,
          :scope => :global,
          :visible_if => visible,
          :enabled_if => proc { KantoReloaded::PCOrganization.enabled? },
          :default => 1,
          :priority => 40
        })
        !action.nil? && !toggle.nil? && !animations.nil? &&
          !speed.nil? && !icons.nil?
      end

      def register_storage_hook
        return false unless defined?(KantoReloaded::Hooks) &&
                            defined?(PokemonStorageScreen)
        KantoReloaded::Hooks.wrap(
          PokemonStorageScreen, :pbStartScreen,
          :pc_organization_session, :required => true
        ) do |invocation, *arguments|
          command = arguments[0]
          if KantoReloaded::PCOrganization.enabled? &&
              defined?(KantoReloaded::ReloadedPC) &&
              KantoReloaded::ReloadedPC.supports?(command)
            KantoReloaded::PCOrganization.with_reloaded_session do
              KantoReloaded::ReloadedPC.open(self, command)
            end
          else
            invocation.call(*arguments)
          end
        end
      end

      def current_game_speed
        defined?($GameSpeed) && $GameSpeed ? $GameSpeed : 1
      rescue StandardError
        1
      end

      def set_game_speed(value)
        $GameSpeed = [value.to_i, 1].max
      rescue StandardError
        $GameSpeed = 1
      end

      def capture_speed_state
        {
          :game_speed => current_game_speed,
          :can_toggle => (defined?($CanToggle) ? $CanToggle : true),
          :speedtoggle => pokemon_speedtoggle
        }
      end

      def apply_pc_speed_state
        $CanToggle = false
        $PokemonSystem.speedtoggle = 0 if pokemon_speedtoggle_available?
        set_game_speed(pc_speed)
        refresh_speed_title
      end

      def restore_speed_state(state)
        data = state.is_a?(Hash) ? state : {}
        set_game_speed(data.fetch(:game_speed, 1))
        $CanToggle = data.fetch(:can_toggle, true)
        if pokemon_speedtoggle_available? && data.key?(:speedtoggle)
          $PokemonSystem.speedtoggle = data[:speedtoggle]
        end
      end

      def pokemon_speedtoggle_available?
        defined?($PokemonSystem) && $PokemonSystem &&
          $PokemonSystem.respond_to?(:speedtoggle) &&
          $PokemonSystem.respond_to?(:speedtoggle=)
      rescue StandardError
        false
      end

      def pokemon_speedtoggle
        pokemon_speedtoggle_available? ? $PokemonSystem.speedtoggle : nil
      rescue StandardError
        nil
      end

      def refresh_speed_title
        Object.new.__send__(:updateTitle)
      rescue StandardError
        nil
      end

      def available_menu_commands(scene)
        menu_commands.select { |entry| command_enabled?(entry, scene) }
      end

      def command_enabled?(entry, scene)
        predicate = entry[:enabled]
        return true unless predicate.respond_to?(:call)
        predicate.call(scene) != false
      rescue StandardError => e
        log_exception("Reloaded PC command availability failed", e)
        false
      end

      def log_exception(message, error)
        KantoReloaded::Log.exception(
          message, error, :channel => :pc_organization
        ) if defined?(KantoReloaded::Log)
      end
    end
  end
end

KantoReloaded::PCOrganization.install if defined?(KantoReloaded::PCOrganization)
