# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Wild Link's Chain HUD and notices
#==============================================================================
# His picks (2026-11-14, sheets wl-hud, wl-notices):
#
#   Chain HUD  Design 1, Rebuilt: top left while a target is out, a plate in
#              its type's colour: its picture, its name and Chain N in gold;
#              SL N and the shiny odds (1 in N) on the right. Kanto
#              Reloaded's toasts keep clear of it (one that would cover it
#              moves beside it, or under it: Toast.keep_clear); menus cover it
#   Notices    Kanto Reloaded's toast, its picture at 32 px (Big Icons as
#              the player has them), 3 seconds of real time:
#                Got Away           "Abra Got Away" / "Chain 13 kept, search again"
#                Chain Broken       "Chain Broken" / "Abra's chain of 13 ended"
#                Search Level Step  "Search Level 50" / "Abra: A second Egg Move can show up"
#              No sounds of their own (his sounds pick): a target that runs
#              off plays PIF's own cry and Flee as it goes
#==============================================================================

return unless defined?(Reloaded::Pixel) && defined?(::KIF::PixelFont) && defined?(Reloaded::PartyPaint)

module Reloaded
  module WildLink
    module Hud
      W = 206
      H = 42
      Z = 99_000
      GOLD = Color.new(240, 200, 80)
      P = Reloaded::Pixel
      PF = ::KIF::PixelFont
      PP = Reloaded::PartyPaint

      class << self
        def install
          return if @installed
          @installed = true
          if defined?(::Events) && ::Events.respond_to?(:onMapUpdate)
            ::Events.onMapUpdate += proc { |_s, _e| Reloaded::WildLink::Hud.update }
          end
          # toasts keep clear of it (beside it, or under it)
          if defined?(Reloaded::Toast) && Reloaded::Toast.respond_to?(:keep_clear)
            Reloaded::Toast.keep_clear(:wild_link_hud) { Reloaded::WildLink::Hud.visible? ? [8, 8, W, H] : nil }
          end
        end

        # What it shows now, or nil: [species, chain, Search Level, odds]
        def facts
          t = Search.target
          return nil unless t && WildLink.on? && $game_map && t["map"] == $game_map.map_id
          sp = t["species"]
          sl = WildLink.search_level(sp)
          ch = WildLink.chain_for(sp, t["way"], t["map"])
          return [sp, ch, sl, Bonuses.shiny_odds(sl, ch)]
        end

        def update
          return unless defined?(::Viewport) && defined?(::Sprite)
          f = facts
          return hide unless f
          sig = f + [Reloaded::Palette.respond_to?(:mode) ? (Reloaded::Palette.mode rescue 0) : 0]
          make unless @sprite && !@sprite.disposed?
          return if sig == @sig
          @sig = sig
          draw(*f)
        rescue StandardError => e
          Reloaded::Log.warning_once("Wild Link's Chain HUD couldn't show (#{e.class})", :wild_link)
          hide
        end

        def make
          @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
          @viewport.z = Z
          @sprite = Sprite.new(@viewport)
          @sprite.bitmap = Bitmap.new(W, H)
          @sprite.x = 8
          @sprite.y = 8
          @sig = nil
        end

        def hide
          return unless @sprite
          @sprite.bitmap.dispose if !@sprite.disposed? && @sprite.bitmap
          @sprite.dispose unless @sprite.disposed?
          @viewport.dispose if @viewport && !@viewport.disposed?
          @sprite = @viewport = nil
          @sig = nil
        end

        def visible?
          return @sprite && !@sprite.disposed? ? true : false
        end

        def draw(sp, chain, sl, odds)
          c = Reloaded::Palette.map_menu
          o = @sprite.bitmap
          o.clear
          d = (::GameData::Species.get(sp) rescue nil)
          rgb = d && defined?(Reloaded::PartyScreen::TYPE_RGB) ? Reloaded::PartyScreen::TYPE_RGB[d.type1] : nil
          col = Color.new(*(rgb || [150, 160, 175]))
          mix = proc { |a, b, t| Reloaded::Palette.mix(a, b, t) }
          PP.chamfer_grad(o, 0, 0, W - 1, H - 1, 8, mix.call(c[:panel], col, 0.35), mix.call(c[:panel], c[:dark], 0.3), mix.call(c[:line], col, 0.6))
          pic = Notices.picture(sp, 36)
          o.blt(4, 3, pic, Rect.new(0, 0, 36, 36)) if pic
          pic.dispose if pic
          name = (d ? d.name.to_s : sp.to_s)
          P.text(o, 44, 2, 96, 20, PF.fit(PF::ROW, name, 92), c[:strong], PF::ROW)
          P.small(o, 44, 22, 90, 16, _INTL("Chain {1}", chain), c[:gold] || GOLD)
          P.small(o, 0, 4, W - 8, 16, _INTL("SL {1}", sl), c[:txt], 1)
          P.small(o, 0, 22, W - 8, 16, odds <= 1 ? _INTL("Always") : _INTL("1 in {1}", Bonuses.commas(odds)), c[:txt], 1)
        end
      end
    end

    module Notices
      STEP_WORDS = { 5 => "Targets can come a level higher", 12 => "One extra shiny roll for its targets",
                     25 => "Its targets always have a perfect IV", 50 => "A second Egg Move can show up",
                     100 => "Its targets always have two perfect IVs", 250 => "Four shiny rolls, and higher levels" }.freeze

      class << self
        def install
          return if @installed
          @installed = true
          ev = Reloaded::Events
          ev.on(:wild_link_got_away, :wild_link_notices) { |c| got_away(c) }
          ev.on(:wild_link_chain_broken, :wild_link_notices) { |c| broken(c) }
          ev.on(:wild_link_won, :wild_link_notices) { |c| stepped(c) }
        end

        def name(sp)
          return (::GameData::Species.get(sp.to_s.to_sym).name.to_s rescue sp.to_s)
        end

        # The Pokémon's picture, trimmed to the Pokémon and fitted in a
        # size x size square (Big Icons as the player has them)
        def picture(sp, size = 32)
          bm = (Reloaded::PartyIcons.species_bitmap(sp.to_s.to_sym) rescue nil)
          return nil unless bm
          r = Reloaded::PartyIcons.art_rect(bm, [bm.height, 1].max)
          out = Bitmap.new(size, size)
          k = [size.to_f / [r.width, r.height, 1].max, 1.0].min
          w = (r.width * k).round
          h = (r.height * k).round
          out.stretch_blt(Rect.new((size - w) / 2, (size - h) / 2, w, h), bm, r)
          return out
        rescue StandardError
          return nil
        end

        def toast(sp, title, sub)
          return unless defined?(Reloaded::Toast) && WildLink.on?
          Reloaded::Toast.show(title, :icon => picture(sp), :icon_size => 32, :sub => sub)
        rescue StandardError => e
          Reloaded::Log.warning_once("Wild Link's notice couldn't show (#{e.class})", :wild_link)
        end

        def got_away(c)
          n = c[:n].to_i
          sub = n > 0 ? _INTL("Chain {1} kept, search again", n) : _INTL("Open Wild Link to search again")
          toast(c[:species], _INTL("{1} Got Away", name(c[:species])), sub)
        end

        def broken(c)
          toast(c[:species], _INTL("Chain Broken"), _INTL("{1}'s chain of {2} ended", name(c[:species]), c[:n].to_i))
        end

        def stepped(c)
          step = Array(c[:steps]).max
          return unless step
          toast(c[:species], _INTL("Search Level {1}", step), _INTL("{1}: {2}", name(c[:species]), _INTL(STEP_WORDS[step].to_s)))
        end
      end
    end
  end
end
