# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Wild Link's fishing spots and Rock Smash rocks
#==============================================================================
# His picks (2026-11-14, GIFs wl_fish_d1..3, wl_rock_d1):
#
#   Fishing     a water tile you can fish from where you can walk, 2 to 7
#               steps away and on screen, marked one of three ways picked at
#               random (his idea): Ripples spreading from it, Bubbles rising
#               and popping, or a Fish Shadow circling under it, splashing
#               now and then. Face it and fish with the rod the Pokémon is
#               listed under: when it bites, it's your target
#   Rock Smash  PIF's own breakable rock on a tile you can walk to, 3 to 7
#               steps away, wobbling every 2 seconds with a puff of dust.
#               Smash it (Rock Smash as the game asks for it) and your target
#               comes out
#
# Wild Link adds no sounds of its own (his sounds pick, 2026-11-14). The
# target, its bonuses, its battle and the chain are Search.rb's as for any
# other way.
#==============================================================================

module Reloaded
  module WildLink
    module Fields
      WAYS = [:fishing, :rock_smash].freeze
      RODS = { :OldRod => :OLDROD, :GoodRod => :GOODROD, :SuperRod => :SUPERROD }.freeze
      MARKERS = [:ripples, :bubbles, :shadow].freeze
      WOBBLE_EVERY = 120                # frames (2 seconds)
      WOBBLE = [0, 2, 0, -2, 0, 2, 0, -2].freeze
      ROCK_GRAPHIC = "BW_rocksmash"

      class << self
        def install
          return if @installed
          @installed = true
          if defined?(::Events) && ::Events.respond_to?(:onMapUpdate)
            ::Events.onMapUpdate += proc { |_s, _e| Reloaded::WildLink::Fields.update }
          end
          if Object.private_method_defined?(:pbEncounter) || Object.method_defined?(:pbEncounter)
            Reloaded::Hooks.around(FEATURE, ::Object, :pbEncounter, :id => :wild_link_fishing) do |original, enc_type, *rest|
              next original.call(enc_type, *rest) unless Reloaded::WildLink::Fields.fishing_here?(enc_type)
              Reloaded::WildLink::Fields.battle_target
              true
            end
          end
        end

        def handles?(way)
          return WAYS.include?(way)
        end

        # Why this way can't search now (a rod, Rock Smash), or nil
        def gate(row, way)
          case way
          when :fishing
            rod = RODS[row && row[:table]]
            return nil unless rod
            return _INTL("Needs the {1}", (::GameData::Item.get(rod).name rescue rod.to_s)) unless has?(rod)
          when :rock_smash
            return _INTL("Needs Rock Smash") unless can_smash?
          end
          return nil
        end

        def has?(item)
          return $PokemonBag && $PokemonBag.respond_to?(:pbHasItem?) && $PokemonBag.pbHasItem?(item) ? true : false
        rescue StandardError
          return false
        end

        # Rock Smash as the game asks for it: the badge and a Pokémon that
        # knows it, or a Pickaxe
        def can_smash?
          return true if has?(:PICKAXE)
          badge = defined?(::Settings::BADGE_FOR_ROCKSMASH) ? ::Settings::BADGE_FOR_ROCKSMASH : 0
          ok = defined?(pbCheckHiddenMoveBadge) ? pbCheckHiddenMoveBadge(badge, false) : true
          finder = $Trainer && $Trainer.respond_to?(:get_pokemon_with_move) ? $Trainer.get_pokemon_with_move(:ROCKSMASH) : nil
          return ok && finder ? true : false
        rescue StandardError
          return false
        end

        #----------------------------------------------------------------------
        # Starting
        #----------------------------------------------------------------------
        def start(row, way)
          words = gate(row, way)
          return Search.say(words.to_s + ".") && false if words
          spot = way == :fishing ? fishing_spot : rock_spot
          return Search.say(_INTL("Nothing answered nearby. Try somewhere with more room.")) && false unless spot
          species = row[:species]
          map = $game_map.map_id
          c = WildLink.chain
          WildLink.break_chain(:other) if c && c["key"] != WildLink.chain_key(species, way, map)
          Search.clear
          sl = WildLink.search_level(species)
          t = { "kind" => way, "spot" => spot, "map" => map, "species" => species, "way" => way, "row" => row,
                "level" => Search.target_level(row, sl), "rod" => row[:table] }
          if way == :fishing
            t["marker"] = MARKERS[rand(MARKERS.length)]
          else
            ev = make_rock(spot)
            return Search.say(_INTL("Nothing answered nearby.")) && false unless ev
            t["event"] = ev.id
          end
          Search.adopt(t)
          Reloaded::Events.emit(:wild_link_target, :species => species, :way => way, :level => t["level"], :marker => t["marker"])
          return true
        rescue StandardError => e
          Reloaded::Log.exception("Wild Link couldn't make a field target", e, :wild_link)
          return false
        end

        # A water tile you can fish (facing it from where you can walk),
        # 2 to 7 steps away, on screen
        def fishing_spot
          px = $game_player.x
          py = $game_player.y
          found = []
          reachable.each do |(x, y), d|
            Search::DIRS.each do |_dir, dx, dy|
              wx = x + dx
              wy = y + dy
              next unless $game_map.valid?(wx, wy) && fishable?(wx, wy)
              dist = (wx - px).abs + (wy - py).abs
              next unless dist >= 2 && d + 1 <= Search::MAX_STEPS
              next unless (wx - px).abs <= Search::SCREEN_X && (wy - py).abs <= Search::SCREEN_Y
              found << [wx, wy] unless found.include?([wx, wy])
            end
          end
          return found.empty? ? nil : found[rand(found.length)]
        end

        def fishable?(x, y)
          return ($game_map.terrain_tag(x, y).can_fish rescue false) ? true : false
        end

        # A floor tile you can walk to, 3 to 7 steps away, on screen
        def rock_spot
          px = $game_player.x
          py = $game_player.y
          found = reachable.select do |(x, y), d|
            d >= Search::MIN_STEPS && (x - px).abs <= Search::SCREEN_X && (y - py).abs <= Search::SCREEN_Y &&
              (!defined?(can_spawn_pokemon_there) || can_spawn_pokemon_there(x, y, :Land))
          end.map(&:first)
          return found.empty? ? nil : found[rand(found.length)]
        end

        # { [x, y] => steps } you can walk to, up to 7 steps
        def reachable
          px = $game_player.x
          py = $game_player.y
          steps = { [px, py] => 0 }
          queue = [[px, py]]
          until queue.empty?
            x, y = queue.shift
            d = steps[[x, y]]
            next if d >= Search::MAX_STEPS
            Search::DIRS.each do |dir, dx, dy|
              nx = x + dx
              ny = y + dy
              next if steps.key?([nx, ny]) || !$game_map.valid?(nx, ny) || !Search.walkable?(x, y, dir)
              steps[[nx, ny]] = d + 1
              queue << [nx, ny]
            end
          end
          return steps
        end

        #----------------------------------------------------------------------
        # Fishing
        #----------------------------------------------------------------------
        def facing
          d = $game_player.direction
          dx = { 4 => -1, 6 => 1 }[d] || 0
          dy = { 2 => 1, 8 => -1 }[d] || 0
          return [$game_player.x + dx, $game_player.y + dy]
        end

        # Fishing at the target's spot with its rod
        def fishing_here?(enc_type)
          t = Search.target
          return false unless t && t["kind"] == :fishing && WildLink.on?
          return false unless RODS.key?(enc_type.to_s.to_sym)
          return false unless t["map"] == $game_map.map_id && facing == t["spot"]
          return t["rod"].nil? || t["rod"].to_sym == enc_type.to_s.to_sym
        rescue StandardError
          return false
        end

        #----------------------------------------------------------------------
        # The target's battle (fished, or out of its rock)
        #----------------------------------------------------------------------
        def battle_target
          t = Search.target
          return false unless t
          species = t["species"]
          sl = WildLink.search_level(species)
          chain = WildLink.chain_for(species, t["way"], t["map"])
          pk = defined?(pbGenerateWildPokemon) ? pbGenerateWildPokemon(species, t["level"]) : nil
          return false unless pk
          t["got"] = Bonuses.apply(pk, sl, chain) { pk.shiny = true }
          Search.battle = true
          pbWildBattleSpecific(pk) if defined?(pbWildBattleSpecific)
          return true
        rescue StandardError => e
          Reloaded::Log.exception("Wild Link's field target couldn't battle", e, :wild_link)
          Search.battle = false
          return false
        end

        #----------------------------------------------------------------------
        # Rock Smash: PIF's own rock, as a temporary event
        #----------------------------------------------------------------------
        def make_rock(spot)
          return nil unless defined?(::RPG::Event) && defined?(::Game_Event) && $game_map
          id = ($game_map.events.keys.max || 0) + 1
          rpg = ::RPG::Event.new(spot[0], spot[1])
          rpg.id = id
          rpg.name = "smashrock (Wild Link)"
          page = rpg.pages[0]
          page.graphic.character_name = ROCK_GRAPHIC
          page.trigger = 0
          page.list = [::RPG::EventCommand.new(355, 0, ["Reloaded::WildLink::Fields.smash_rock(@event_id)"]),
                       ::RPG::EventCommand.new(0, 0, [])]
          ev = Rock.new($game_map.map_id, rpg, $game_map)
          ev.moveto(spot[0], spot[1])
          $game_map.events[id] = ev
          $PokemonTemp.registerTempEvent($game_map.map_id, ev) if defined?($PokemonTemp) && $PokemonTemp.respond_to?(:registerTempEvent)
          add_sprite(ev)
          return ev
        rescue StandardError => e
          Reloaded::Log.exception("Wild Link couldn't place its rock", e, :wild_link)
          return nil
        end

        def add_sprite(ev)
          return unless defined?($scene) && $scene.respond_to?(:spritesets) && defined?(::Sprite_Character) && defined?(::Spriteset_Map)
          set = $scene.spritesets[$game_map.map_id]
          return unless set
          set.character_sprites.push(::Sprite_Character.new(::Spriteset_Map.viewport, ev))
        end

        # The rock's event: smashed as the game does it, then the target
        def smash_rock(event_id)
          t = Search.target
          ev = $game_map.events[event_id]
          return false unless t && t["kind"] == :rock_smash && t["event"] == event_id && ev
          return false unless defined?(pbRockSmash) && pbRockSmash
          pbSmashEvent(ev) if defined?(pbSmashEvent)
          return battle_target
        end

        def remove_rock(t)
          ev = t && t["event"] && $game_map ? $game_map.events[t["event"]] : nil
          return unless ev.is_a?(Rock)
          set = defined?($scene) && $scene.respond_to?(:spritesets) ? $scene.spritesets[$game_map.map_id] : nil
          if set
            sp = set.character_sprites.find { |s| s.character == ev }
            if sp
              set.character_sprites.delete(sp)
              sp.dispose
            end
          end
          ev.erase if ev.respond_to?(:erase)
          $game_map.events.delete(ev.id)
        rescue StandardError
          nil
        end

        #----------------------------------------------------------------------
        # On the map, every frame: the fishing spot's marker
        #----------------------------------------------------------------------
        def update
          return unless defined?(::Viewport) && defined?(::Sprite)
          t = Search.target
          if t && t["kind"] == :fishing && $game_map && t["map"] == $game_map.map_id
            Marker.show(t["spot"], t["marker"])
          else
            Marker.hide
          end
        rescue StandardError => e
          Reloaded::Log.warning_once("Wild Link's fishing spot couldn't show (#{e.class})", :wild_link)
          Marker.hide
        end
      end

      # The rock: wobbles every 2 seconds, a puff of dust as it starts
      if defined?(::Game_Event)
        class Rock < ::Game_Event
          def update
            super
            @wl_frames = (@wl_frames || 0) + 1
            k = @wl_frames % WOBBLE_EVERY
            if k == 0 && defined?($scene) && $scene.respond_to?(:spriteset) && $scene.spriteset && defined?(::Settings::DUST_ANIMATION_ID)
              $scene.spriteset.addUserAnimation(::Settings::DUST_ANIMATION_ID, @x, @y, true) rescue nil
            end
            @wl_shake = k < WOBBLE.length ? WOBBLE[k] : 0
          end

          def screen_x
            return super + (@wl_shake || 0)
          end
        end
      end

      # The fishing spot's marker on the map's own layer (over the water,
      # under the characters), sized with Map Zoom: Ripples, Bubbles or a
      # Fish Shadow (his three, one at random for each spot)
      module Marker
        SIZE = 32
        class << self
          def show(spot, kind)
            make unless @sprite && !@sprite.disposed?
            return unless @sprite
            @frame = (@frame || 0) + 1
            draw(kind, @frame)
            k = scale
            m = $game_map
            sx = (((spot[0] * 128 - m.display_x) / 4.0).round + 16) * k
            sy = (((spot[1] * 128 - m.display_y) / 4.0).round + 16) * k
            @sprite.x = sx.round
            @sprite.y = sy.round
            @sprite.zoom_x = @sprite.zoom_y = k
            @sprite.visible = true
          end

          def hide
            return unless @sprite
            @sprite.bitmap.dispose if !@sprite.disposed? && @sprite.bitmap
            @sprite.dispose unless @sprite.disposed?
            @own.dispose if @own && !@own.disposed?
            @sprite = @own = nil
          end

          def make
            vp = defined?(::Spriteset_Map) && ::Spriteset_Map.respond_to?(:viewport) ? ::Spriteset_Map.viewport : nil
            @own = nil
            unless vp && !vp.disposed?
              vp = @own = Viewport.new(0, 0, Graphics.width, Graphics.height)
              vp.z = 1
            end
            @sprite = Sprite.new(vp)
            @sprite.bitmap = Bitmap.new(SIZE, SIZE)
            @sprite.ox = SIZE / 2
            @sprite.oy = SIZE / 2
            @sprite.z = 1
          end

          def scale
            return 1.0 unless defined?(::KIF::MapZoom) && ::KIF::MapZoom.respond_to?(:scale)
            s = ::KIF::MapZoom.scale.to_f
            return s > 0 ? s : 1.0
          rescue StandardError
            return 1.0
          end

          LIGHT = Color.new(210, 244, 255)
          FOAM = Color.new(240, 252, 255)
          DEEP = Color.new(8, 22, 44)

          def dot(b, x, y, col, a)
            return if a <= 0
            b.fill_rect((x.round / 2) * 2, (y.round / 2) * 2, 2, 2, Color.new(col.red, col.green, col.blue, a))
          end

          def ring(b, r, a)
            0.step(354, 6) do |deg|
              t = deg * Math::PI / 180
              dot(b, 16 + r * Math.cos(t), 16 + r * 0.5 * Math.sin(t), LIGHT, a)
            end
          end

          # A loop of 30 frames at 10 a second (the GIFs'), slowed to the
          # game's 60
          def draw(kind, frame)
            b = @sprite.bitmap
            b.clear
            f = (frame / 6) % 30
            case kind
            when :ripples
              [0, 15].each do |start|
                k = (f - start) % 30
                ring(b, 3 + k * 0.9, (220 * (1 - k / 14.0)).round) if k < 14
              end
            when :bubbles
              [[-6, 2, 0], [4, -2, 9], [0, 3, 17], [7, 1, 24]].each do |bx, by, t0|
                k = (f - t0) % 30
                if k < 8
                  dot(b, 16 + bx, 16 + by - k / 2, FOAM, 230)
                elsif k < 10
                  ring(b, 3, 160)
                end
              end
            else
              t = f / 30.0 * 2 * Math::PI
              cx = 16 + 6 * Math.cos(t)
              cy = 16 + 3 * Math.sin(t)
              (-9..9).step(2) do |dx|
                h = (4 * Math.sqrt([1 - (dx / 9.0)**2, 0].max)).round
                (-h..h).step(2) { |dy| dot(b, cx + dx, cy + dy, DEEP, 175) }
              end
              if f % 15 < 3
                k = f % 15
                [[-4, -2 - k], [0, -4 - k], [4, -2 - k]].each { |dx, dy| dot(b, cx + dx, cy + dy, FOAM, 230) }
              end
            end
          end
        end
      end
    end
  end
end
