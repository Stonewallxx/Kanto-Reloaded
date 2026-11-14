# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Wild Link's Search Again? popup
#==============================================================================
# His pick (2026-11-14, sheet wl-continue): Design 1, Standard Popup. After
# you win a battle with your target while Continue Search is Ask, over the
# map: Kanto Reloaded's own popup, "Search for Abra again?", then the chain,
# Search Level and shiny odds in a line; Search Again (the default) or Stop.
#
#   Reloaded::WildLink::Continue.ask(:ABRA, 13)   # => true to search again
#
# Left/Right (or the mouse) pick, A chooses, B (or a right click) is Stop.
#==============================================================================

return unless defined?(Reloaded::Pixel) && defined?(::KIF::PixelFont) && defined?(Reloaded::Dialogs)

module Reloaded
  module WildLink
    module Continue
      W = 512
      H = 384
      GOLD = Color.new(240, 200, 80)
      DG = Reloaded::Dialogs

      class << self
        def ask(species, chain)
          @species = species
          @chain = chain
          open_layer
          choice = 0
          picked = nil
          redraw = true
          loop do
            if redraw
              draw(choice)
              redraw = false
            end
            Graphics.update
            Input.update
            pt = Reloaded::Pointer
            hit = DG.hit
            if pt.moved? && hit && hit != choice
              choice = hit
              pbPlayCursorSE
              redraw = true
            end
            if pt.left? && hit
              picked = hit
            elsif pt.right? || Input.trigger?(Input::BACK)
              picked = 1
            elsif Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)
              choice = 1 - choice
              pbPlayCursorSE
              redraw = true
            elsif Input.trigger?(Input::USE)
              picked = choice
            end
            break if picked
          end
          picked == 0 ? pbPlayDecisionSE : pbPlayCancelSE
          return picked == 0
        rescue StandardError => e
          Reloaded::Log.exception("Wild Link's Search Again? couldn't show", e, :wild_link)
          return false
        ensure
          close_layer
        end

        def segments(c)
          sl = WildLink.search_level(@species)
          odds = Bonuses.shiny_odds(sl, @chain)
          words = odds <= 1 ? _INTL("Always Shiny") : _INTL("Shiny 1 in {1}", Bonuses.commas(odds))
          return [[_INTL("Chain {1}", @chain), c[:gold] || GOLD],
                  [" · " + _INTL("Search Level {1}", sl) + " · " + words, c[:txt]]]
        end

        def draw(choice)
          c = Reloaded::Palette.map_menu
          o = @sprite.bitmap
          o.clear
          name = (::GameData::Species.get(@species).name rescue @species.to_s)
          DG.send(:draw_buttons, o, c, _INTL("Wild Link"), _INTL("Search for {1} again?", name),
                  [_INTL("Search Again"), _INTL("Stop")], choice, segments(c))
        end

        def open_layer
          close_layer
          @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
          @viewport.z = 100_400
          @sprite = Sprite.new(@viewport)
          @sprite.bitmap = Bitmap.new(W, H)
        end

        def close_layer
          @sprite.bitmap.dispose if @sprite && !@sprite.disposed? && @sprite.bitmap
          @sprite.dispose if @sprite && !@sprite.disposed?
          @viewport.dispose if @viewport && !@viewport.disposed?
          @sprite = @viewport = nil
        end
      end
    end
  end
end
