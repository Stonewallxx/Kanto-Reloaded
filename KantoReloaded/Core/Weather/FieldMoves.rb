# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Weather System, Field Weather Moves
#==============================================================================
# Stage 6 (his picks, 2026-10-18 and 2026-11-13). PIF's Hoenn weather field
# moves work in Kanto while the Weather System is On, with more of them:
#
#   Rain Dance   rain (a storm when it's windy)
#   Sunny Day    sun (not after dark: the card says the sun has set)
#   Hail         snow
#   Sandstorm    a sandstorm (the only way to get one)
#   Thunder      a storm
#   Whirlwind    wind (a storm when it's raining)
#   Tailwind     wind (a storm when it's raining)
#   Mist         fog
#   Defog, Haze  clear the fog, or the ash
#
# From a Pokémon's menu in the party (Kanto Reloaded's Party Screen or the
# game's), outdoors in a place of the Weather System's. First the Preview
# Card (Design 1: the weather it makes and where, until when, its strength,
# then While It Lasts: More Common, In Battle, what it Replaces, and the cost),
# Use / Cancel. Each use costs the move 1 PP (a Pokémon Center refills it)
# and plays the Pokémon's cry. The weather starts at strength 5 and holds
# until the weather next changes across the region; then it joins the
# fronts (it can grow, fade or drift, as any weather).
#==============================================================================

module Reloaded
  module Weather
    module FieldMoves
      # move => [the weather it makes, the weather that turns it into a storm]
      MOVES = { :RAINDANCE => [:Rain, :Wind], :SUNNYDAY => [:Sunny, nil], :HAIL => [:Snow, nil],
                :SANDSTORM => [:Sandstorm, nil], :THUNDER => [:Storm, nil], :WHIRLWIND => [:Wind, :Rain],
                :TAILWIND => [:Wind, :Rain], :MIST => [:Fog, nil], :DEFOG => [:None, nil], :HAZE => [:None, nil] }.freeze
      CLEARS = [:Fog, :Ash].freeze
      STRENGTH = 5

      # A popup layer of its own, for the game's party screen (Kanto
      # Reloaded's has one)
      class CardHost
        def initialize
          @vp = Viewport.new(0, 0, Graphics.width, Graphics.height)
          @vp.z = 100_250
          @sprite = Sprite.new(@vp)
          @sprite.bitmap = Bitmap.new(512, 384)
        end

        def overlay
          return @sprite.bitmap
        end

        def palette
          return Reloaded::Palette.map_menu
        end

        def dispose
          @sprite.bitmap.dispose if @sprite && !@sprite.disposed? && @sprite.bitmap
          @sprite.dispose if @sprite && !@sprite.disposed?
          @vp.dispose if @vp && !@vp.disposed?
        end
      end

      class << self
        def install
          return if @installed
          @installed = true
          h = Reloaded::Hooks
          if defined?(::HiddenMoveHandlers)
            hm = ::HiddenMoveHandlers.singleton_class
            # listed among a Pokémon's field moves
            h.around(FEATURE, hm, :hasHandler, :id => :weather_moves_listed) do |original, *args|
              ours?(args[0]) ? true : original.call(*args)
            end
            h.around(FEATURE, hm, :triggerCanUseMove, :id => :weather_moves_can_use) do |original, *args|
              id, pkmn, showmsg = args
              next original.call(*args) unless ours?(id)
              r = usable(pkmn, id)
              if r == true || r == :sun_set
                true
              else
                pbMessage(r.to_s) if showmsg && defined?(pbMessage)
                false
              end
            end
            # the game's own party screen (and the Overworld Menu's Field
            # Moves): the card on a layer of its own
            h.around(FEATURE, hm, :triggerConfirmUseMove, :id => :weather_moves_confirm) do |original, *args|
              id, pkmn = args
              next original.call(*args) unless ours?(id)
              host = CardHost.new
              begin
                card(host, pkmn, id)
              ensure
                host.dispose
              end
            end
            h.around(FEATURE, hm, :triggerUseMove, :id => :weather_moves_use) do |original, *args|
              id, pkmn = args
              next original.call(*args) unless ours?(id)
              pbMessage(_INTL("{1} used {2}!", pkmn.name, move_name(id))) if defined?(pbMessage) && !(pbHiddenMoveAnimation(pkmn) rescue false)
              use!(pkmn, id)
            end
          end
          # Kanto Reloaded's Party Screen: the card over it, used right there
          if defined?(Reloaded::PartyScreen) && Reloaded::PartyScreen.respond_to?(:take_field_move)
            MOVES.each_key do |id|
              Reloaded::PartyScreen.take_field_move(id) do |scene, pkmn, move_id|
                Reloaded::Weather::FieldMoves.from_party(scene, pkmn, move_id)
              end
            end
          end
        end

        # One of ours, while the Weather System is On (Off: the game's own)
        def ours?(id)
          return Reloaded::Weather.on? && MOVES.key?(id.to_s.upcase.to_sym)
        rescue StandardError
          return false
        end

        def move_name(id)
          return (::GameData::Move.get(id).name rescue id.to_s.capitalize)
        end

        def place_here
          return nil unless defined?($game_map) && $game_map
          return Places.of_map($game_map.map_id)
        end

        def move_of(pkmn, id)
          return Array(pkmn && pkmn.moves).find { |m| m && m.id == id.to_s.upcase.to_sym }
        end

        # What the move makes here: a weather type (:None when it clears)
        def result(id, key = place_here)
          type, storm_with = MOVES[id.to_s.upcase.to_sym]
          return nil unless type
          cur = key ? Display.base(Display.shown(key, "now")[0]) : :None
          return :Storm if storm_with && cur == storm_with
          return type
        end

        # true, :sun_set, or the words saying why not
        def usable(pkmn, id)
          id = id.to_s.upcase.to_sym
          return _INTL("The weather can't change here.") unless outdoors?
          key = place_here
          map = $game_map.map_id
          return _INTL("The weather can't change here.") unless key && !Places.fixed_weather(map)
          return _INTL("The weather here can't change right now.") if Reloaded::Weather.external?(map)
          mv = move_of(pkmn, id)
          return _INTL("{1} has no PP left.", move_name(id)) unless mv && mv.pp.to_i > 0
          return :sun_set if id == :SUNNYDAY && Reloaded::Weather.dark?
          cur_t, cur_n = Display.shown(key, "now")
          want = result(id, key)
          if want == :None
            return _INTL("There's no fog or ash to clear.") unless CLEARS.include?(Display.base(cur_t))
          elsif Display.base(cur_t) == want && cur_n.to_i >= STRENGTH
            return _INTL("{1} is already here.", Display.name(want))
          end
          return true
        end

        def outdoors?
          meta = (::GameData::MapMetadata.try_get($game_map.map_id) rescue nil)
          return meta && meta.outdoor_map ? true : false
        end

        #----------------------------------------------------------------------
        # Using one
        #----------------------------------------------------------------------
        # Kanto Reloaded's Party Screen: true when handled (always, here)
        def from_party(scene, pkmn, id)
          return false unless ours?(id)
          r = usable(pkmn, id)
          if r.is_a?(String)
            pbPlayBuzzerSE if defined?(pbPlayBuzzerSE)
            scene.respond_to?(:pbDisplay) ? scene.pbDisplay(r) : (pbMessage(r) if defined?(pbMessage))
            return true
          end
          if card(scene, pkmn, id)
            use!(pkmn, id)
            scene.pbRefresh if scene.respond_to?(:pbRefresh)
          end
          return true
        end

        # The weather changes: PP, the cry, the place's weather now (and next,
        # from the fronts), the map, and the change alert
        def use!(pkmn, id)
          key = place_here
          return false unless key
          type = result(id, key)
          mv = move_of(pkmn, id)
          return false unless mv && mv.pp.to_i > 0
          mv.pp -= 1
          begin
            pkmn.respond_to?(:play_cry) ? pkmn.play_cry : (::GameData::Species.play_cry_from_pokemon(pkmn) rescue nil)
          rescue StandardError
            nil
          end
          if defined?(Multiplayer) && Multiplayer.remote?
            Multiplayer.ask_move(key, type)            # a guest: the host's game changes it for everyone
          else
            Reloaded::Weather.set_by_move(key, type, STRENGTH)
          end
          if Alerts.on?
            t, n = Display.shown(key, "now")
            Reloaded::Toast.queue { Alerts.show(Alerts.change_toast(key, t, n)) } if defined?(Reloaded::Toast)
          end
          Reloaded::Events.emit(:weather_move, :move => id, :place => key, :weather => type) if defined?(Reloaded::Events)
          return true
        rescue StandardError => e
          Reloaded::Log.exception("Weather: a Field Weather Move couldn't be used", e, :weather)
          return false
        end

        #----------------------------------------------------------------------
        # The Preview Card (Design 1, in the Header Plate popup): true for Use
        #----------------------------------------------------------------------
        def card(host, pkmn, id)
          id = id.to_s.upcase.to_sym
          if usable(pkmn, id) == :sun_set
            Reloaded::Dialogs.drawn(host, 1) { |b, c, _ch| paint_sun_set(b, c, pkmn, id) }
            return false
          end
          choice = Reloaded::Dialogs.drawn(host, 2) { |b, c, ch| paint_card(b, c, pkmn, id, ch) }
          return choice == 0
        end

        def in_battle_words(type)
          case type
          when :Rain, :Storm then return _INTL("Water up, Fire down")
          when :Sunny then return _INTL("Fire up, Water down")
          when :Snow
            snow = defined?(::KIF::Mechanics) && (::KIF::Mechanics.hail rescue 0) == 2
            return snow ? _INTL("Snow: Ice types' Defense up") : _INTL("Hail hurts all but Ice types")
          when :Sandstorm then return _INTL("Hurts all but Rock, Ground, Steel")
          when :Wind then return _INTL("Tailwind for one side")
          when :Fog then return _INTL("Moves less accurate ({1})", Battle.accuracy_label(STRENGTH))
          end
          return _INTL("Nothing")
        end

        def paint_card(b, c, pkmn, id, choice)
          p = Reloaded::Pixel
          pf = ::KIF::PixelFont
          pp = Reloaded::PartyPaint
          dl = Reloaded::Dialogs
          key = place_here
          type = result(id, key)
          now_t, now_n = Display.shown(key, "now")
          w = 316
          h = 248
          x = (512 - w) / 2
          y = (384 - 25 - h) / 2
          dl.frame(b, c, x, y, w, h, move_name(id))
          p.text(b, x, y + 38, w, 14, pkmn.name.to_s.upcase, c[:dim], pf::TINY, 2)
          shown = type == :None ? :None : type
          ic = Screens.icon_bitmap(Display.icon(shown, STRENGTH))
          b.blt(x + 16, y + 56, ic, Rect.new(0, 0, 32, 32)) if ic
          place = Places[key] ? Places[key].name : ""
          head = type == :None ? _INTL("Clear Skies on {1}", place) : _INTL("{1} on {2}", Display.name(type), place)
          p.text(b, x + 56, y + 54, w - 70, 20, pf.fit(pf::TEXT, head, w - 70), pp.ink(c, Display.rgb(shown)), pf::TEXT)
          p.small(b, x + 56, y + 74, w - 70, 18, _INTL("Until the weather changes, in {1}", Display.in_words), c[:txt])
          if type != :None
            p.small(b, x + 16, y + 94, 80, 18, Display.strength_word(type, STRENGTH), c[:dim])
            bar(b, c, x + 92, y + 101, w - 108, STRENGTH, Display.colour(type))
          end
          p.heading(b, x + 16, x + w - 16, y + 118, _INTL("While It Lasts"), c[:head], c[:line])
          tx = row(b, c, x + 16, y + 132, _INTL("More Common"))
          types = type == :None ? [] : Encounters.more_types(type)
          if types.empty?
            p.small(b, tx, y + 132, w - 110, 18, _INTL("Nothing Extra"), c[:dim])
          else
            sheet = Screens.icon_bitmap(pp::TYPES_SMALL)
            types.each do |t|
              b.blt(tx, y + 133, sheet, Rect.new(0, pp.type_row(t) * 16, 16, 16)) if sheet
              label = (::GameData::Type.get(t).name rescue t.to_s.capitalize)
              tx += 18 + p.small(b, tx + 18, y + 132, 80, 18, label, c[:txt]) + 8
            end
          end
          tx = row(b, c, x + 16, y + 150, _INTL("In Battle"))
          p.small(b, tx, y + 150, w - 110, 18, in_battle_words(type), c[:txt])
          tx = row(b, c, x + 16, y + 168, _INTL("Replaces"))
          ric = Screens.icon_bitmap(Display.icon(now_t, now_n))
          b.stretch_blt(Rect.new(tx, y + 169, 16, 16), ric, Rect.new(0, 0, 32, 32)) if ric
          p.small(b, tx + 20, y + 168, 140, 18, Display.name(now_t), c[:txt])
          tx = row(b, c, x + 16, y + 186, _INTL("Costs"))
          mv = move_of(pkmn, id)
          p.small(b, tx, y + 186, w - 110, 18, _INTL("1 PP ({1} left)", mv ? mv.pp.to_i : 0), c[:txt])
          dl.button_row(b, c, x, w, y + h - 36, [_INTL("Use"), _INTL("Cancel")], choice)
        end

        # Sunny Day after dark: it can't, and uses no PP
        def paint_sun_set(b, c, pkmn, id)
          p = Reloaded::Pixel
          pf = ::KIF::PixelFont
          w = 316
          h = 168
          x = (512 - w) / 2
          y = (384 - 25 - h) / 2
          Reloaded::Dialogs.frame(b, c, x, y, w, h, move_name(id))
          p.text(b, x, y + 38, w, 14, pkmn.name.to_s.upcase, c[:dim], pf::TINY, 2)
          ic = Screens.icon_bitmap(Display.icon(:Sunny, STRENGTH))
          b.blt(x + 16, y + 56, ic, Rect.new(0, 0, 32, 32)) if ic
          p.text(b, x + 56, y + 54, w - 70, 20, _INTL("The Sun Has Set"), Reloaded::PartyPaint.ink(c, [240, 110, 100]), pf::TEXT)
          p.small(b, x + 56, y + 74, w - 70, 18, _INTL("Sunny Day works by day: Try it"), c[:txt])
          p.small(b, x + 56, y + 92, w - 70, 18, _INTL("again in the morning. No PP used."), c[:txt])
          Reloaded::Dialogs.button_row(b, c, x, w, y + h - 36, [_INTL("OK")], 0)
        end

        def row(b, c, x, y, label, lw = 92)
          Reloaded::Pixel.small(b, x, y, lw, 18, label, c[:dim])
          return x + lw
        end

        def bar(b, c, x, y, w, n, color, segs = 10, h = 5)
          gap = 2
          sw = (w - gap * (segs - 1)) / segs
          segs.times { |i| b.fill_rect(x + i * (sw + gap), y, sw, h, i < n ? color : Reloaded::Palette.mix(c[:dark], c[:line], 0.4)) }
        end
      end
    end
  end
end
