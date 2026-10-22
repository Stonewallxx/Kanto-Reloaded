#==============================================================================
# Kanto Reloaded: Lifecycle
#==============================================================================
# Core hooks that turn the game's start-up, title screen, loading and saving
# into Reloaded::Events (see Events.rb for the list).
#
#   Game.set_up_system                  -> :system_ready (after)
#   PokemonLoadScreen#pbStartLoadScreen -> :title_screen (before)
#   SaveData.read_from_file             -> remembers which file was read
#   SaveData.load_all_values            -> :save_loaded (after)
#   SaveData.load_new_game_values       -> :new_game, then :save_loaded
#   SaveData.save_to_file               -> :saved (after it succeeded)
#
# Reloaded::Lifecycle.incoming_save_data is the whole save being loaded, so
# features can read data the game itself doesn't keep (for example the old
# Kanto Reloaded mod's bucket in a KIF 0.20.7 save).
#==============================================================================

module Reloaded
  module Lifecycle
    class << self
      attr_reader :incoming_save_data, :last_save_path, :system_ready

      def boot
        hooks = Reloaded::Hooks
        # safe saving first: the innermost writer, so :saved still follows it
        Reloaded::Hooks.guard(nil, :safe_save) { Reloaded::SafeSave.install } if defined?(Reloaded::SafeSave)
        hooks.around(nil, ::Game.singleton_class, :set_up_system, :id => :lifecycle_system) do |original, *args|
          result = original.call(*args)
          @system_ready = true
          Reloaded::Events.emit(:system_ready)
          result
        end
        hooks.around(nil, "PokemonLoadScreen", :pbStartLoadScreen, :id => :lifecycle_title) do |original, *args|
          Reloaded::Events.emit(:title_screen)
          original.call(*args)
        end
        save = ::SaveData.singleton_class
        hooks.around(nil, save, :read_from_file, :id => :lifecycle_read) do |original, path, *rest|
          @last_save_path = path
          original.call(path, *rest)
        end
        hooks.around(nil, save, :load_all_values, :id => :lifecycle_load) do |original, save_data, *rest|
          @incoming_save_data = save_data
          begin
            result = original.call(save_data, *rest)
            Reloaded::Events.emit(:save_loaded, :new_game => false, :path => @last_save_path)
            result
          ensure
            @incoming_save_data = nil
          end
        end
        hooks.around(nil, save, :load_new_game_values, :id => :lifecycle_new_game) do |original, *args|
          @incoming_save_data = nil
          result = original.call(*args)
          Reloaded::Events.emit(:new_game)
          Reloaded::Events.emit(:save_loaded, :new_game => true, :path => nil)
          result
        end
        hooks.around(nil, save, :save_to_file, :id => :lifecycle_saved) do |original, path, *rest|
          result = original.call(path, *rest)
          @last_save_path = path
          Reloaded::Events.emit(:saved, :path => path)
          result
        end
        return true
      end
    end
  end
end
