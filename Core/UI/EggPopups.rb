# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Egg Manager's popups over the map
#==============================================================================
# The Ask Card (his pick, 2026-10-25), with Hatched Pokémon on Ask: after a
# Pokémon hatches in the party, over the map: its picture on a plate, its
# level, nature and ability, "Keep it, or send it to the PC?", where it
# would go ("Goes to Box 3 (12 Free)"), Keep in Party (the default, and B)
# or Send to PC. With every box full, Send to PC is dimmed and "Every Box Is
# Full" shows in red.
#
#   Reloaded::HatchAsk.ask(pokemon)   # => :keep or :send
#==============================================================================

return unless defined?(Reloaded::Pixel) && defined?(::KIF::PixelFont) && defined?(Reloaded::Dialogs)

module Reloaded
  module HatchAsk
    W = 512
    H = 384
    CARD_W = 344
    CARD_H = 196
    PLATE = 62
    BUTTON_W = 138
    P = Reloaded::Pixel
    PF = ::KIF::PixelFont
    DG = Reloaded::Dialogs
    EM = Reloaded::EggManager

    class << self
      # :keep or :send
      def ask(pokemon)
        @pkmn = pokemon
        @box = EM::Eggs.store_box
        open_layer
        choice = 0
        redraw = true
        picked = nil
        loop do
          if redraw
            draw(choice)
            redraw = false
          end
          Graphics.update
          Input.update
          @frame += 1
          pt = Reloaded::Pointer
          hit = pt.hit(@hits)
          if pt.moved? && hit && hit != choice && (hit == 0 || @box)
            choice = hit
            pbPlayCursorSE
            redraw = true
          end
          if pt.left? && hit
            picked = hit
          elsif pt.right? || Input.trigger?(Input::BACK)
            picked = 0
          elsif Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)
            target = Input.trigger?(Input::LEFT) ? 0 : 1
            if target == 1 && !@box
              pbPlayBuzzerSE
            elsif target != choice
              choice = target
              pbPlayCursorSE
              redraw = true
            end
          elsif Input.trigger?(Input::USE)
            picked = choice
          end
          next unless picked
          if picked == 1 && !@box
            pbPlayBuzzerSE
            picked = nil
            next
          end
          break
        end
        picked == 1 ? pbPlayDecisionSE : pbPlayCancelSE
        return picked == 1 ? :send : :keep
      rescue StandardError => e
        Reloaded::Log.exception("The Ask Card couldn't show", e, :egg_manager)
        return :keep
      ensure
        close_layer
      end

      private

      def draw(choice)
        c = Reloaded::Palette.map_menu
        o = @sprite.bitmap
        o.clear
        @hits = []
        DG.send(:dim, o)
        x = (W - CARD_W) / 2
        y = [(H - P::HINT_H - CARD_H) / 2, 4].max
        DG.send(:panel, o, c, x, y, CARD_W, CARD_H)
        DG.send(:title_bar, o, c, x, y, CARD_W, _INTL("{1} Hatched!", @pkmn.name))
        px = x + 20
        py = y + 46
        fill = c[:light] ? Reloaded::Palette.mix(c[:panel2], Reloaded::PartyPaint::WHITE, 0.5) : Reloaded::Palette.mix(c[:dark], c[:panel], 0.3)
        P.ui.rbox(o, px, py, px + PLATE, py + PLATE, 8, fill)
        place_icon(px + PLATE / 2, py + PLATE / 2, 48)
        tx = px + PLATE + 14
        tw = CARD_W - (tx - x) - 16
        name = PF.fit(PF::TEXT, @pkmn.name.to_s, tw - 40)
        nw = P.text(o, tx, py + 4, tw, 18, name, c[:txt], PF::TEXT)
        P.text(o, tx + nw + 8, py + 8, 50, 12, _INTL("LV {1}", @pkmn.level), c[:gold], PF::TINY)
        nature = (@pkmn.nature.name rescue nil)
        ability = (@pkmn.ability.name rescue nil)
        P.small(o, tx, py + 26, tw, 16, _INTL("{1} Nature", nature), c[:dim]) if nature
        P.small(o, tx, py + 42, tw, 16, ability.to_s, c[:dim]) if ability
        P.text(o, x, y + 118, CARD_W, 18, _INTL("Keep it, or send it to the PC?"), c[:txt], PF::TEXT, 2)
        where_line(o, c, x + CARD_W / 2, y + 138)
        by = y + CARD_H - 38
        bx = x + (CARD_W - (BUTTON_W * 2 + 12)) / 2
        button(o, c, bx, by, bx + BUTTON_W, by + 28, _INTL("Keep in Party"), choice == 0)
        button(o, c, bx + BUTTON_W + 12, by, bx + BUTTON_W * 2 + 12, by + 28, _INTL("Send to PC"), choice == 1, !@box)
        pairs = [[:lr, _INTL("Choose")], [hint_button(:C), _INTL("Select")], [hint_button(:B), _INTL("Keep in Party")]]
        P.hints(o, o, c, pairs, Reloaded::Prompts.style)
      end

      # "Goes to Box 3 (12 Free)", the box in the text's colour; red when
      # every box is full
      def where_line(o, c, cx, y)
        unless @box
          P.small(o, cx - 150, y, 300, 16, _INTL("Every Box Is Full"), c[:red], 2)
          return
        end
        segs = [[_INTL("Goes to "), c[:dim]], [EM::Eggs.box_name(@box), c[:txt]],
                [_INTL(" ({1} Free)", EM::Eggs.free_places(@box)), c[:dim]]]
        P.send(:small_font, o)
        widths = segs.map { |t, _col| o.text_size(t).width }
        x = cx - widths.sum / 2
        segs.each_with_index do |(t, col), i|
          P.small(o, x, y, widths[i] + 4, 16, t, col)
          x += widths[i]
        end
      end

      def button(o, c, x0, y0, x1, y1, label, on, off = false)
        DG.send(:button, o, c, x0, y0, x1, y1, on)
        ink = off ? c[:dim] : (on ? (c[:strong] || c[:white]) : c[:txt])
        P.text(o, x0, y0 + 2, x1 - x0, 24, label, ink, PF::TEXT, 2)
        @hits << [@hits.length, x0, y0, x1, y1]
      end

      def hint_button(sym)
        return Reloaded::Prompts.input(sym) || Reloaded::Prompts.name(sym)
      end

      def open_layer
        close_layer
        @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @viewport.z = 100_400
        @sprite = Sprite.new(@viewport)
        @sprite.bitmap = Bitmap.new(W, H)
        @icon = Reloaded::PartyIcons.icon(@pkmn, @viewport, 1)
        @art = @icon && @icon.bitmap ? Reloaded::PartyIcons.art_rect(@icon.bitmap, [@icon.src_rect.height, 1].max) : nil
        @hits = []
        @frame = 0
      end

      def close_layer
        @icon.dispose if @icon && !@icon.disposed?
        @icon = nil
        @sprite.bitmap.dispose if @sprite && !@sprite.disposed? && @sprite.bitmap
        @sprite.dispose if @sprite && !@sprite.disposed?
        @viewport.dispose if @viewport && !@viewport.disposed?
        @sprite = @viewport = nil
      end

      # The picture's art box x box, its middle on x, y
      def place_icon(x, y, box)
        return unless @icon && @art
        @icon.zoom_x = @icon.zoom_y = box.to_f / [@art.width, @art.height, 1].max
        @icon.ox = @art.x + @art.width / 2
        @icon.oy = @art.y + @art.height / 2
        @icon.x = x
        @icon.y = y
      end
    end
  end
end
