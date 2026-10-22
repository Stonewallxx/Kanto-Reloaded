#==============================================================================
# Kanto Reloaded: Events
#==============================================================================
# A small event bus. Handlers run in priority order (lower first, equal ones
# in the order they were added); a handler that raises is logged and the
# rest still run.
#
#   Reloaded::Events.on(:save_loaded, :my_feature) { |context| ... }
#   Reloaded::Events.emit(:save_loaded, :slot => 1)
#   Reloaded::Events.off(:save_loaded, :my_feature)
#
# Events raised by the core:
#   :core_booted     after Bootstrap finished
#   :system_ready    after the game set up $PokemonSystem at startup
#   :title_screen    the title/load screen opened (no save is loaded)
#   :save_loaded     after a save file was loaded
#   :new_game        after a new game's values were created
#   :saving          just before Kanto Reloaded's save data is written
#   :saved           after the game was saved { :path }
#   :setting_changed { :key, :value, :old_value }
#   :feature_changed { :id, :state, :old_state }
#   :game_data_loaded     the game loaded its data (Data Patches' targets read it)
#   :data_patches_apply   Data Patches' targets make the game's data (theirs only)
#   :data_patches_loaded  every mod's data patches applied { :summary, :patches, :errors }
#   :profiler_session     the Timing Profiler finished a session { :session }
#==============================================================================

module Reloaded
  module Events
    @handlers = {}

    class << self
      def on(event, id, priority = 100, &block)
        raise ArgumentError, "No block given for event #{event}" unless block
        list = (@handlers[event.to_sym] ||= [])
        list.reject! { |entry| entry[:id] == id.to_sym }
        list << { :id => id.to_sym, :priority => priority, :block => block }
        # equal priorities run in the order they were added (sort_by alone isn't stable)
        list.replace(list.each_with_index.sort_by { |entry, i| [entry[:priority], i] }.map(&:first))
        return true
      end

      def off(event, id)
        list = @handlers[event.to_sym]
        return false unless list
        before = list.length
        list.reject! { |entry| entry[:id] == id.to_sym }
        return list.length != before
      end

      def emit(event, context = {})
        Array(@handlers[event.to_sym]).dup.each do |entry|
          begin
            entry[:block].call(context)
          rescue Exception => e
            raise if (defined?(Reset) && e.is_a?(Reset)) || e.is_a?(SystemExit)
            Reloaded::Log.exception("Event #{event} handler #{entry[:id]} failed", e, :events)
          end
        end
        return true
      end
    end
  end
end
