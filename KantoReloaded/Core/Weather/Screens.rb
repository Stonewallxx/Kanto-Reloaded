# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Weather System, where the Forecast opens and the Fly map
#==============================================================================
# Stage 4 (his picks, 2026-11-13). While the Weather System is On:
#
#   Overworld Menu   a Forecast action on Main (after Fly): the weather here,
#                    its 16 px icon and its name in its colour (Design 1, Icon
#                    and Word); A opens the Forecast
#   Pause Menu       a Forecast tile (Design 1, Poke Ball Sun), its status the
#                    weather here
#   PokéNav          Hoenn Essentials' Weather app (and PIF's own) opens the
#                    Forecast in place of PIF's weather map
#   Fly map and      PIF's map screen as it is, with the weather on it
#   Town Map         (Design 1, Your Mix, Rebuilt): every place's 32 px icon
#                    on its tile (scrolling with the map, gone when it closes:
#                    PIF's own layer did neither), a card beside the cursor in
#                    the weather's colour (the place, its icon, weather and
#                    strength, the bar, Next / Starts, the types More Common),
#                    "Weather: Now" on the title bar, X Now / Next and Y
#                    Forecast on the bottom bar. The card and keys follow
#                    Theme Mode.
#==============================================================================

module Reloaded
  module Weather
    module Screens
      ICON = "Graphics/PauseMenu/FORECAST"

      class << self
        def install
          return if @installed
          @installed = true
          register_menus
          if Object.private_method_defined?(:pbWeatherMap) || Object.method_defined?(:pbWeatherMap)
            Reloaded::Hooks.around(FEATURE, Object, :pbWeatherMap, :id => :weather_pokenav) do |original, *args|
              if Reloaded::Weather.on? && defined?(Reloaded::WeatherForecastScreen)
                Reloaded::WeatherForecastScreen.open
                nil
              else
                original.call(*args)
              end
            end
          end
          Reloaded::Hooks.prepend(FEATURE, ::BetterRegionMap, FlyMap, :id => :weather_fly_map) if defined?(::BetterRegionMap)
        end

        def open_forecast
          Reloaded::WeatherForecastScreen.open if defined?(Reloaded::WeatherForecastScreen)
        end

        # The weather here: [type, strength] (ours; or what the screen shows on
        # a map that keeps its own, or under a story's), or nil indoors
        def here
          return nil unless Reloaded::Weather.on? && defined?($game_map) && $game_map
          map = $game_map.map_id
          key = Places.of_map(map)
          return Display.shown(key, "now") if key && !Reloaded::Weather.external?(map)
          meta = (::GameData::MapMetadata.try_get(map) rescue nil)
          return nil unless meta && meta.outdoor_map
          t = defined?($game_screen) && $game_screen ? $game_screen.weather_type : nil
          return [:None, 0] if t.nil? || t == :None
          return [t, Battle.screen_strength]
        rescue StandardError
          return nil
        end

        def register_menus
          if defined?(Reloaded::PauseMenu)
            Reloaded::PauseMenu.register(:forecast, "Forecast", :feature => FEATURE, :order => 23,
              :icon => ICON, :small_icon => "menuIcons/POKEMON",
              :visible => proc { Reloaded::Weather.on? },
              :status => proc { Reloaded::Weather::Screens.status },
              :handler => proc { |_scene| Reloaded::Weather::Screens.open_forecast; :stay })
          end
          if defined?(Reloaded::OverworldMenu)
            Reloaded::OverworldMenu.register(:forecast, :name => "Forecast", :kind => :action, :priority => 22, :feature => FEATURE,
              :condition => proc { Reloaded::Weather.on? },
              :paint => proc { |b, x1, y, h, c, room| Reloaded::Weather::Screens.paint_row(b, x1, y, h, c, room) },
              :description => "The weather here and across Kanto, now and next. Opens the Weather Forecast.",
              :handler => proc { |menu| Reloaded::Weather::Screens.open_forecast; menu.refresh rescue nil; nil })
          end
        end

        # The Pause Menu tile's status: ["Rain, Moderate", nil, "Rain"]
        def status
          w = here
          return [_INTL("Indoors"), nil, _INTL("Indoors")] unless w
          type, n = w
          word = Display.strength_word(type, n)
          long = word.empty? ? Display.name(type) : _INTL("{1}, {2}", Display.name(type), word)
          return [long, nil, Display.name(type)]
        end

        # The Overworld Menu row: the weather's 16 px icon, then its name in
        # its colour, ending at x1 (nothing indoors)
        def paint_row(b, x1, y, h, c, _room)
          w = here
          return 0 unless w
          type, n = w
          pp = Reloaded::PartyPaint
          pf = ::KIF::PixelFont
          word = Display.name(type)
          tw = Reloaded::Pixel.width(pf::ROW, word)
          Reloaded::Pixel.text(b, x1 - tw, y, tw, h, word, pp.ink(c, Display.rgb(type)), pf::ROW)
          ic = icon_bitmap(Display.icon(type, n))
          b.stretch_blt(Rect.new(x1 - tw - 20, y + h / 2 - 8, 16, 16), ic, Rect.new(0, 0, ic.height, ic.height)) if ic
          return tw + 20
        rescue StandardError
          return 0
        end

        def icon_bitmap(path)
          @icons ||= {}
          bm = @icons[path]
          return bm if bm && !bm.disposed?
          @icons[path] = (Bitmap.new(path) rescue nil)
        end
      end

      #------------------------------------------------------------------------
      # The Fly map and the Town Map (PIF's BetterRegionMap, its own screen
      # only: not a quest map or the randomizer's, not the Pokédex's area map)
      #------------------------------------------------------------------------
      module FlyMap
        # (region, show_player, can_fly, wallmap, species, fly_anywhere, show_weather)
        def initialize(*args)
          @kr_weather = instance_of?(::BetterRegionMap) && args[4].nil? && !args[6] && Reloaded::Weather.on? ? true : false
          if @kr_weather
            args += [-1, true, false, false, nil, false][args.length..-1] if args.length < 6
            args[6] = true
          end
          super(*args)
        end

        def after_init_graphics(*args)
          ret = super
          Reloaded::Weather::Screens::Fly.open(self) if @kr_weather
          return ret
        end

        def draw_all_weather(*args)
          return Reloaded::Weather::Screens::Fly.icons(self) if @kr_weather
          return super
        end

        def update_weather_text(location, *args)
          return Reloaded::Weather::Screens::Fly.hover(location) if @kr_weather
          return super
        end

        # PIF's map text without the point of interest on the right (the keys
        # are there)
        def update_text_at_location(location, *args)
          return super unless @kr_weather
          Reloaded::Weather::Screens::Fly.hover(location)
          text = location ? (pbGetMessageFromHash(MessageTypes::PlaceNames, location[2]) rescue location[2].to_s) : ""
          region_y = 0
          location_y = 354
          if defined?(getCurrentLanguage) && (getCurrentLanguage rescue nil) == :CHINESE
            region_y -= 6
            location_y -= 6
          end
          white = Color.new(255, 255, 255)
          black = Color.new(0, 0, 0)
          @sprites["txt"].draw([[(pbGetMessage(MessageTypes::RegionNames, @region) rescue ""), 16, region_y, 0, white, black],
                                [text, 16, location_y, 0, white, black]], true)
        end

        def on_update(*args)
          ret = super
          Reloaded::Weather::Screens::Fly.update(self) if @kr_weather
          return ret
        end

        # PIF's debug X (a new Hoenn cycle): not with ours
        def new_weather_cycle(*args)
          return nil if @kr_weather
          return super
        end

        def dispose(*args)
          Reloaded::Weather::Screens::Fly.close if @kr_weather
          return super
        end
      end

      module Fly
        CARD_W = 160
        CARD_H = 106
        WHITE = Color.new(248, 248, 248)
        SHADOW = Color.new(40, 40, 48)
        P = Reloaded::Pixel

        class << self
          attr_reader :tab

          def open(map)
            close
            @map = map
            @tab = :now
            @location = nil
            @spots = []
            vp = map.instance_variable_get(:@viewport2)
            @card = Sprite.new(vp)
            @card.bitmap = Bitmap.new(CARD_W, CARD_H)
            @card.z = 6000
            @card.visible = false
            @keys = Sprite.new(vp)
            @keys.bitmap = Bitmap.new(512, 384)
            @keys.z = 6000
            sp = map.instance_variable_get(:@sprites)
            pif = sp ? sp["weather"] : nil
            pif.visible = false if pif && pif.respond_to?(:visible=)
            draw_keys
          rescue StandardError => e
            Reloaded::Log.exception("Weather: the Fly map's weather couldn't be set up", e, :weather)
          end

          def close
            [@card, @keys].each do |s|
              next unless s && !s.disposed?
              s.bitmap.dispose if s.bitmap && !s.bitmap.disposed?
              s.dispose
            end
            @card = @keys = @map = nil
            @spots = []
          end

          def palette
            return Reloaded::Palette.map_menu
          end

          def which
            return @tab == :now ? "now" : "next"
          end

          # A sprite for every place on the Town Map, on the map's own layer
          # (so it scrolls with it and goes when it closes)
          def icons(map)
            win = map.instance_variable_get(:@window)
            vp = map.instance_variable_get(:@mapvp)
            return unless win && vp
            @spots = []
            Places.keys.each_with_index do |k, i|
              spot = Places[k].spot
              next unless spot && spot[0].to_i == 0
              s = Sprite.new(vp)
              s.x = 16 * spot[1].to_i + 8
              s.y = 16 * spot[2].to_i + 8
              s.ox = 16
              s.oy = 16
              win.add("kr_weather_#{i}", s)
              @spots << [k, s]
            end
            paint_icons
          rescue StandardError => e
            Reloaded::Log.exception("Weather: the Fly map's icons couldn't be drawn", e, :weather)
          end

          def paint_icons
            @spots.each do |k, s|
              next if s.disposed?
              type, n = Display.shown(k, which)
              if type == :None
                s.visible = false
                next
              end
              s.bitmap = Screens.icon_bitmap(Display.icon(type, n))
              s.src_rect = Rect.new(0, 0, 32, 32)
              s.visible = true
            end
          end

          # The place under the cursor: the Town Map's own spot (its map), else
          # a place at that tile
          def place_at(location)
            return nil unless location
            key = location[4] ? Places.of_map(location[4]) : nil
            return key if key
            Places.keys.find { |k| (s = Places[k].spot) && s[1].to_i == location[0] && s[2].to_i == location[1] }
          end

          def hover(location)
            key = place_at(location)
            return if key == @location && @drawn_tab == @tab
            @location = key
            draw_card
          end

          # Each frame: the card follows the cursor; X and Y
          def update(map)
            return unless @card && !@card.disposed?
            if Input.trigger?(Input::X)
              @tab = @tab == :now ? :next : :now
              pbPlayCursorSE
              paint_icons
              draw_card
              draw_keys
            elsif Input.trigger?(Input::Y)
              pbPlayDecisionSE
              Reloaded::WeatherForecastScreen.open(@tab, 100_100) if defined?(Reloaded::WeatherForecastScreen)
            end
            place_card(map)
          rescue StandardError => e
            Reloaded::Log.warning_once("Weather: the Fly map's card couldn't update (#{e.class})", :weather)
          end

          def place_card(map)
            return unless @card.visible
            sp = map.instance_variable_get(:@sprites)
            cur = sp ? sp["cursor"] : nil
            return unless cur
            x0 = cur.x.to_i + 30
            x0 = cur.x.to_i - CARD_W - 14 if x0 + CARD_W > 496
            y0 = [[cur.y.to_i - 14, 36].max, 350 - CARD_H].min
            @card.x = x0
            @card.y = y0
          end

          def draw_card
            @drawn_tab = @tab
            return unless @card && !@card.disposed?
            b = @card.bitmap
            b.clear
            unless @location && Places[@location]
              @card.visible = false
              return
            end
            c = palette
            pp = Reloaded::PartyPaint
            pf = ::KIF::PixelFont
            mix = proc { |a, z, t| Reloaded::Palette.mix(a, z, t) }
            type, n = Display.shown(@location, which)
            col = Display.colour(type)
            pp.chamfer_grad(b, 0, 0, CARD_W - 1, CARD_H - 1, 10, mix.call(c[:panel], col, 0.4), mix.call(c[:panel], c[:dark], 0.4), mix.call(c[:line], col, 0.5))
            w = CARD_W
            P.text(b, 8, 3, w - 16, 22, pf.fit(pf::ROW, Places[@location].name, w - 16), c[:strong], pf::ROW)
            b.fill_rect(6, 26, w - 12, 2, pp::POKE_RED)
            ic = Screens.icon_bitmap(Display.icon(type, n))
            b.blt(8, 32, ic, Rect.new(0, 0, 32, 32)) if ic
            tw = P.text(b, 44, 31, 90, 18, Display.name(type), pp.ink(c, Display.rgb(type)), pf::TEXT)
            P.small(b, 50 + tw, 32, w - 60 - tw, 18, Display.strength_word(type, n), c[:txt])
            segs = 10
            bw = w - 54
            sw = (bw - 2 * (segs - 1)) / segs
            filled = type == :None || type == :Rainbow ? 0 : n.to_i
            segs.times { |i| b.fill_rect(44 + i * (sw + 2), 54, sw, 4, i < filled ? col : mix.call(c[:dark], c[:line], 0.4)) }
            soon = Display.in_words
            if @tab == :now
              nt, = Display.shown(@location, "next")
              P.small(b, 8, 64, 60, 18, _INTL("Next"), c[:dim])
              P.small(b, 8, 64, w - 16, 18, _INTL("{1}, in {2}", Display.name(nt), soon), pp.ink(c, Display.rgb(nt)), 1)
            else
              P.small(b, 8, 64, 60, 18, _INTL("Starts"), c[:dim])
              P.small(b, 8, 64, w - 16, 18, _INTL("In {1}", soon), c[:txt], 1)
            end
            types = type == :None || type == :Rainbow ? [] : Encounters.more_types(Display.base(type))
            if types.empty?
              P.small(b, 8, 83, w - 16, 18, _INTL("Nothing Extra"), c[:dim])
            else
              sheet = Screens.icon_bitmap(pp::TYPES_SMALL)
              tx = 8
              types.each do |t|
                b.blt(tx, 84, sheet, Rect.new(0, pp.type_row(t) * 16, 16, 16)) if sheet
                label = (::GameData::Type.get(t).name rescue t.to_s.capitalize)
                tx += 18 + P.small(b, tx + 18, 83, 80, 18, label, c[:txt]) + 8
              end
            end
            @card.visible = true
          rescue StandardError => e
            Reloaded::Log.exception("Weather: the Fly map's card couldn't be drawn", e, :weather)
          end

          # "Weather: Now" on the title bar (PIF's white text), X and Y on the
          # bottom bar's right
          def draw_keys
            return unless @keys && !@keys.disposed?
            b = @keys.bitmap
            b.clear
            pif_text(b, 280, 10, 216, @tab == :now ? _INTL("Weather: Now") : _INTL("Weather: Next"), 1)
            c = palette
            style = Reloaded::Prompts.style
            key = proc { |sym| Reloaded::Prompts.input(sym) || Reloaded::Prompts.name(sym) }
            pairs = [[key.call(:X), @tab == :now ? _INTL("Next") : _INTL("Now")], [key.call(:Y), _INTL("Forecast")]]
            pf = ::KIF::PixelFont
            widths = pairs.map { |k, l| Reloaded::ButtonIcons.width(k, style, 18) + 4 + P.width(pf::TEXT, l) }
            x = 500 - widths.sum - 12 * (pairs.length - 1)
            pairs.each_with_index do |(k, l), i|
              Reloaded::ButtonIcons.draw(b, x, 360, k, c, style, 18)
              kx = x + Reloaded::ButtonIcons.width(k, style, 18) + 4
              P.text(b, kx + 1, 361, 200, 18, l, SHADOW, pf::TEXT)
              P.text(b, kx, 360, 200, 18, l, WHITE, pf::TEXT)
              x += widths[i] + 12
            end
          end

          # PIF's map text: the system font, white with a dark shadow
          def pif_text(b, x, y, w, str, align = 0)
            if defined?(pbSetSystemFont)
              pbSetSystemFont(b)
            else
              b.font.name = "Power Green"
              b.font.size = 29
            end
            [[2, 0], [0, 2], [2, 2]].each do |dx, dy|
              b.font.color = SHADOW
              b.draw_text(x + dx, y + dy, w, 26, str, align)
            end
            b.font.color = WHITE
            b.draw_text(x, y, w, 26, str, align)
          end
        end
      end
    end
  end
end
