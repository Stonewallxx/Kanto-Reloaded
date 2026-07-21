#==============================================================================
# Kanto Reloaded - Save Manager
#==============================================================================

module KantoReloaded
  module SaveManager
    SETTINGS_ACTION = :save_manager
    TITLE_REFRESH_TAG = :kanto_reloaded_save_manager_refresh

    @installed = false
    @title_depth = 0
    @title_screen = nil

    class << self
      def install
        return true if @installed
        register_settings
        hooks_ready = install_title_hooks
        @installed = true
        KantoReloaded::Log.info("Save Manager installed title_hooks=#{hooks_ready}", :modules) if defined?(KantoReloaded::Log)
        true
      rescue StandardError => e
        @installed = false
        KantoReloaded::Log.exception("Save Manager installation failed", e, channel: :save_manager) if defined?(KantoReloaded::Log)
        false
      end

      def open(options = {})
        data = options.is_a?(Hash) ? options.dup : {}
        data[:title] = title_context? unless data.has_key?(:title)
        data[:active_slot] = current_active_slot unless data.has_key?(:active_slot)
        SaveManagerUI.open(data)
      end

      def open_from_settings
        result = open(:title => title_context?)
        request_title_refresh if title_context? && result[:changed]
        result
      end

      def open_archive_folder
        path = SaveArchive.archive_root
        Dir.mkdir(path) unless Dir.exist?(path)
        if defined?(KantoReloaded::Platform) &&
           KantoReloaded::Platform.respond_to?(:open_folder) &&
           KantoReloaded::Platform.open_folder(path)
          KantoReloaded::Toast.success(_INTL("Opened the Deleted Saves folder."))
          return true
        end
        display = defined?(KantoReloaded::Platform) ? KantoReloaded::Platform.normalize_path(path) : path
        KantoReloaded::PopupWindow.message(
          _INTL("Deleted Saves folder:\n{1}", display), :theme => :warning
        )
        false
      rescue StandardError => e
        KantoReloaded::Log.exception("Could not open Deleted Saves folder", e, channel: :save_manager) if defined?(KantoReloaded::Log)
        KantoReloaded::Toast.error(_INTL("The Deleted Saves folder could not be opened."))
        false
      end

      def title_context?
        @title_depth.to_i > 0
      end

      def with_title_context(screen)
        previous_screen = @title_screen
        @title_screen = screen
        @title_depth = @title_depth.to_i + 1
        yield
      ensure
        @title_depth = [@title_depth.to_i - 1, 0].max
        @title_screen = previous_screen
      end

      def handle_title_shortcut(scene)
        return false unless title_context?
        return false unless defined?(KantoReloaded::UI::InputRouter)
        return false unless KantoReloaded::UI::InputRouter.input_triggered?(:SPECIAL)
        sprites = scene.instance_variable_get(:@sprites) rescue nil
        commands = scene.instance_variable_get(:@commands) rescue nil
        continue_index = scene.instance_variable_get(:@continue_index) rescue nil
        continue_index = 0 if continue_index.nil?
        window = sprites.is_a?(Hash) ? sprites["cmdwindow"] : nil
        return false unless window && window.index.to_i == continue_index.to_i
        command = Array(commands)[continue_index.to_i].to_s
        entry = SaveArchive.active_entries.find { |value| value[:slot].to_s == command }
        return false unless entry
        result = open(:title => true, :focus_slot => entry[:slot], :active_slot => "")
        request_title_refresh if result[:changed]
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Save Manager title shortcut failed", e, channel: :save_manager) if defined?(KantoReloaded::Log)
        false
      end

      def request_title_refresh
        return false unless title_context?
        close_title_scene
        throw(TITLE_REFRESH_TAG, :refresh)
      end

      private

      def register_settings
        return false unless defined?(KantoReloaded::Settings)
        KantoReloaded::Settings.register(SETTINGS_ACTION, {
          :name => "Save Manager",
          :description => "Archive, restore, inspect, or permanently remove save files.",
          :type => :button,
          :category => :utility,
          :owner => :kanto_reloaded,
          :priority => 10,
          :searchable => ["save", "delete", "archive", "restore", "backup", "cleanup"],
          :on_press => proc { KantoReloaded::SaveManager.open_from_settings }
        })
        true
      end

      def install_title_hooks
        return false unless defined?(KantoReloaded::Hooks)
        screen_ready = false
        scene_ready = false
        if defined?(PokemonLoadScreen)
          screen_ready = KantoReloaded::Hooks.wrap(
            PokemonLoadScreen, :pbStartLoadScreen, :save_manager_title_refresh
          ) do |hook, *_arguments|
            KantoReloaded::SaveManager.with_title_context(self) do
              completed = false
              final_result = nil
              until completed
                outcome = catch(KantoReloaded::SaveManager::TITLE_REFRESH_TAG) do
                  [:completed, hook.call]
                end
                if outcome.is_a?(Array) && outcome[0] == :completed
                  completed = true
                  final_result = outcome[1]
                else
                  newest = defined?(::SaveData) && ::SaveData.respond_to?(:get_newest_save_slot) ?
                    ::SaveData.get_newest_save_slot : nil
                  instance_variable_set(:@selected_file, newest)
                end
              end
              final_result
            end
          end
        end
        if defined?(PokemonLoad_Scene)
          scene_ready = KantoReloaded::Hooks.wrap(
            PokemonLoad_Scene, :pbUpdate, :save_manager_title_shortcut
          ) do |hook, *_arguments|
            result = hook.call
            KantoReloaded::SaveManager.handle_title_shortcut(self)
            result
          end
        end
        screen_ready && scene_ready
      end

      def current_active_slot
        return "" unless defined?($Trainer) && $Trainer && $Trainer.respond_to?(:save_slot)
        $Trainer.save_slot.to_s
      rescue
        ""
      end

      def close_title_scene
        return unless @title_screen
        scene = @title_screen.instance_variable_get(:@scene) rescue nil
        return unless scene
        if scene.respond_to?(:pbCloseScene)
          scene.pbCloseScene
        elsif scene.respond_to?(:pbEndScene)
          scene.pbEndScene
        end
      rescue StandardError => e
        KantoReloaded::Log.exception("Could not refresh title scene", e, channel: :save_manager) if defined?(KantoReloaded::Log)
      end
    end
  end
end

KantoReloaded::SaveManager.install if defined?(KantoReloaded::SaveManager)
