# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Weather System, the fronts
#==============================================================================
# One step of the weather (his picks, 2026-11-13): from the weather now to the
# weather next cycle. A snapshot is plain values, saved as they are:
#   { place key => [weather, strength 1-10], ... }   (only places with weather)
#
#   each front   strengthens (25%), weakens (25%) or holds; fades now and
#                then (weak ones sooner, as PIF's Hoenn weather); a storm that
#                fades leaves rain behind
#   moving       now and then a front moves to a neighbour as one piece
#                (old KR's way)
#   spilling     a strong front (7+) also spills a weaker edge (2 less) into
#                the places next to it (PIF's spreading), his mix
#   meeting      rain meets sun: fog; rain meets wind: a storm (either at 5+);
#                otherwise the stronger stays
#   places       snow drifting somewhere it can't snow turns to rain (not in
#                winter); ash never leaves volcanic places; no front enters a
#                place that can't have its kind (a mountain's pool, ...)
#   new fronts   a few start on clear places from their pool (2 to 4 strong);
#                the season nudges the odds (x1.5: Spring rain, Summer sun
#                and storms, Autumn fog and wind, Winter snow); at least a
#                few fronts are always up somewhere
#
# The weather shown is the front's own, grown at 8+: Heavy Rain, a Blizzard,
# Strong Winds (Weather.shown_type).
#==============================================================================

module Reloaded
  module Weather
    module Fronts
      # Balanced on the game's own places (weather_test.rb, 900 cycles):
      # about a quarter of places with weather (a tenth to nearly half),
      # rain the most common, an eighth of fronts grown at 8+
      GROW = 25           # % a front strengthens
      WEAKEN = 25         # % it weakens
      FADE_BASE = 3       # % it fades at strength 10 (more when weaker)
      FADE_STEP = 3       # ...plus this per point under 10
      MOVE = 15           # % it moves to a neighbour
      SPILL_AT = 7        # strength a front spills from
      SPILL = 30          # % per neighbour
      NEW_FRONT = 90      # per thousand, each clear place, each step
      MIN_FRONTS = 4      # always at least this many fronts up
      START = (2..4)      # a new front's strength
      SEASON_TYPES = [[:Rain], [:Sunny, :Storm], [:Fog, :Wind], [:Snow]].freeze
      SEASON_NUDGE = 1.5
      MOVING = [:Rain, :Storm, :Sunny, :Fog, :Snow, :Wind].freeze   # Ash stays put; Sandstorm is the field move's

      module_function

      # The next snapshot from now. places: the Places module (or a test's),
      # rng: a Random, season: 0-3.
      def step(now, places, rng, season)
        nxt = {}
        now.keys.sort.each do |key|
          type, n = now[key]
          type = type.to_sym
          n = n.to_i
          next unless places[key]
          if rng.rand(100) < FADE_BASE + (10 - n) * FADE_STEP
            put(nxt, places, key, :Rain, n - 2, false, season) if type == :Storm && n > 3
            next
          end
          r = rng.rand(100)
          n += 1 if r < GROW
          n -= 1 if r >= GROW && r < GROW + WEAKEN
          n = [[n, 1].max, 10].min
          nbs = places.neighbours(key)
          if MOVING.include?(type) && !nbs.empty? && rng.rand(100) < MOVE
            put(nxt, places, nbs[rng.rand(nbs.length)], type, n, false, season)
            next
          end
          put(nxt, places, key, type, n, false, season)
          next unless n >= SPILL_AT && MOVING.include?(type)
          nbs.each { |nb| put(nxt, places, nb, type, n - 2, true, season) if rng.rand(100) < SPILL }
        end
        start_fronts(nxt, places, rng, season)
        return nxt
      end

      # A front arrives at a place (a spill never pushes a stronger front out)
      def put(snap, places, key, type, n, spill, season)
        return if n < 1
        pl = places[key]
        return unless pl
        type = settle(type, pl, season)
        return unless type
        old = snap[key]
        unless old
          snap[key] = [type.to_s, n]
          return
        end
        ot = old[0].to_sym
        on = old[1].to_i
        met = meet(type, n, ot, on)
        return if spill && met[0] == ot && on >= n
        snap[key] = [met[0].to_s, met[1]]
      end

      # What a front becomes at a place: snow turns to rain where it can't
      # snow (not in winter); ash and kinds a place's pool doesn't have don't
      # arrive
      def settle(type, pl, season)
        pool = pl.pool
        case type
        when :Snow
          return :Snow if pool.key?(:Snow) || season == 3
          return :Rain
        when :Ash
          return pool.key?(:Ash) ? :Ash : nil
        when :Rain, :Storm
          return :Snow if pool[:Snow].to_i >= 25 && type == :Rain
        end
        return type
      end

      # Two fronts at one place: [type, strength]
      def meet(a, an, b, bn)
        return [a, [an, bn].max] if a == b
        pair = [a, b]
        if pair.include?(:Rain) && pair.include?(:Sunny)
          return [:Fog, [[an, bn].min + 2, 10].min]
        end
        if (pair.include?(:Rain) || pair.include?(:Storm)) && pair.include?(:Wind) && (an >= 5 || bn >= 5)
          return [:Storm, [an, bn].max]
        end
        return an >= bn ? [a, an] : [b, bn]
      end

      # New fronts on clear places, and enough of them to keep a few up
      def start_fronts(snap, places, rng, season)
        clear = places.keys.sort.reject { |k| snap[k] }
        clear.each do |key|
          next unless rng.rand(1000) < NEW_FRONT
          type = pick(places[key].pool, rng, season, true)
          snap[key] = [type.to_s, START.min + rng.rand(START.max - START.min + 1)] if type && type != :None
        end
        tries = 0
        while snap.length < MIN_FRONTS && tries < 50
          tries += 1
          clear = places.keys.sort.reject { |k| snap[k] }
          break if clear.empty?
          key = clear[rng.rand(clear.length)]
          type = pick(places[key].pool, rng, season, false)
          snap[key] = [type.to_s, START.min + rng.rand(START.max - START.min + 1)] if type
        end
      end

      # A weather from a pool, the season's kinds nudged up (with_none: None
      # can come up, meaning no new front)
      def pick(pool, rng, season, with_none)
        list = pool.map do |t, w|
          next nil if t == :None && !with_none
          w = w * SEASON_NUDGE if (SEASON_TYPES[season] || []).include?(t)
          [t, w]
        end.compact
        total = list.sum { |_t, w| w }
        return nil if total <= 0
        roll = rng.rand * total
        list.each do |t, w|
          roll -= w
          return t if roll < 0
        end
        return list.last[0]
      end

      # The first weather of a save: a fifth of the places with a front
      def first(places, rng, season)
        snap = {}
        places.keys.sort.each do |key|
          next unless rng.rand(100) < 20
          type = pick(places[key].pool, rng, season, false)
          snap[key] = [type.to_s, START.min + rng.rand(START.max - START.min + 1)] if type
        end
        start_fronts(snap, places, rng, season)
        return snap
      end
    end
  end
end
