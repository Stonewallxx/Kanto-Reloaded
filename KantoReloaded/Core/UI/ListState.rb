#==============================================================================
# Kanto Reloaded List State
#==============================================================================

module KantoReloaded
  module UI
    module ListState
      class State
        attr_reader :rows
        attr_reader :index
        attr_reader :scroll
        attr_reader :visible_rows

        def initialize(rows = [], options = {})
          @visible_rows = [(options[:visible_rows] || 8).to_i, 1].max
          @wrap = options.has_key?(:wrap) ? !!options[:wrap] : false
          @rows = []
          @index = 0
          @scroll = 0
          replace(rows, options[:index] || 0)
        end

        def replace(rows, preferred_index = nil)
          @rows = Array(rows)
          @index = preferred_index.to_i unless preferred_index.nil?
          clamp!
          self
        end

        def empty?
          @rows.empty?
        end

        def current
          @rows[@index]
        end

        def select(value)
          @index = value.to_i
          clamp!
          @index
        end

        def move(amount)
          return false if empty?
          previous = @index
          candidate = @index + amount.to_i
          if @wrap
            candidate %= @rows.length
          else
            candidate = [[candidate, 0].max, @rows.length - 1].min
          end
          @index = candidate
          ensure_visible
          previous != @index
        end

        def page(amount)
          move(amount.to_i * @visible_rows)
        end

        def visible
          @rows[@scroll, @visible_rows] || []
        end

        def local_index
          @index - @scroll
        end

        def ensure_visible
          @scroll = @index if @index < @scroll
          if @index >= @scroll + @visible_rows
            @scroll = @index - @visible_rows + 1
          end
          max_scroll = [@rows.length - @visible_rows, 0].max
          @scroll = [[@scroll, 0].max, max_scroll].min
          @scroll
        end

        private

        def clamp!
          if empty?
            @index = 0
            @scroll = 0
          else
            @index = [[@index, 0].max, @rows.length - 1].min
            ensure_visible
          end
        end
      end
    end
  end

  ListState = UI::ListState unless const_defined?(:ListState, false)
end
