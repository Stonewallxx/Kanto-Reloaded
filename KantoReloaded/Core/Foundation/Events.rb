#==============================================================================
# Kanto Reloaded Events
#==============================================================================

module KantoReloaded
  module Events
    @handlers = {}

    class << self
      def on(event, id, priority: 100, &block)
        raise ArgumentError, "Event handler block is required" unless block
        key = event.to_sym
        @handlers[key] ||= []
        @handlers[key].reject! { |handler| handler[:id] == id.to_sym }
        @handlers[key] << { :id => id.to_sym, :priority => priority.to_i, :block => block }
        @handlers[key].sort_by! { |handler| [handler[:priority], handler[:id].to_s] }
        true
      end
      alias register on

      def emit(event, context = {})
        count = 0
        Array(@handlers[event.to_sym]).dup.each do |handler|
          begin
            handler[:block].call(context)
            count += 1
          rescue StandardError => e
            KantoReloaded::Log.exception("Event #{event}/#{handler[:id]} failed", e, channel: :events) if defined?(KantoReloaded::Log)
          end
        end
        count
      end

      def remove(event, id)
        list = @handlers[event.to_sym]
        return false unless list
        before = list.length
        list.reject! { |handler| handler[:id] == id.to_sym }
        list.length != before
      end
    end
  end
end
