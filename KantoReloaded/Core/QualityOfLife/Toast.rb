#==============================================================================
# Kanto Reloaded: Quality of Life: the toast
#==============================================================================
# Auto-Repel Reuse's toast (his pick, 2026-10-21): an item's icon, what
# happened, and a gold badge ("4 LEFT"). The shared toast draws it
# (Core/UI/Toast.rb), and it goes after 3 seconds as every toast does.
#==============================================================================

module Reloaded
  module QualityOfLife
    module Toast
      class << self
        def install
          return true
        end

        def show(item, text, badge)
          return Reloaded::Toast.show(text, :icon => item, :pill => [badge, :gold])
        end

        def update
          Reloaded::Toast.update
        end

        def sprite
          return Reloaded::Toast.sprite
        end

        def dispose
          Reloaded::Toast.dispose
        end
      end
    end
  end
end
