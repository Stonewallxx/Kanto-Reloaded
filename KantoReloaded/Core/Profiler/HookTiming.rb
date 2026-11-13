#==============================================================================
# Kanto Reloaded: Mod Timings
#==============================================================================
# Each mod's share of the game's time (the Timing Profiler's Mod Timings):
# its startup, its Data Patches, its time per frame on the map and in
# battle, and its slowest hooks.
#
# A hook is a mod's code on one of the game's classes or modules: an alias
# wrapper, a prepended module, Kanto Reloaded's Hooks.around and .prepend.
# Each layer of such a method is timed on its own; who a layer belongs to
# is the file it lives in (Owners), and the game's own layers count as PIF
# and KIF. This keeps what's found, saves it and answers the Timing
# Profiler's screen; finding the layers and timing them is Kanto Reloaded
# Debug's (its Core/ModTimings.rb: KIF 2.0.0's Mod Safety grades that red
# in a mod players install), so without it Mod Timings stays off.
#
# The timing is on only while Mod Timings is (Timing Profiler On, Mod
# Timings On, KIF's DEBUG option on); the layers are found the first time.
#==============================================================================

module Reloaded
  module Profiler
    module HookTiming
      SKIP_PATH = %r{/Core/Profiler/}i       # the profiler's own probes aren't a mod's hooks
      GAME_LABEL = "PIF and KIF".freeze

      @layers = []        # [{ :owner, :label, :key, :shared, :tp }]
      @stats = {}         # owner => { label => { "calls", "total", "peak", "slow", "session" } }
      @context = {}       # owner => { :map => seconds, :battle => seconds }
      @frames = Hash.new(0)
      @frame_work = Hash.new(0.0)
      @stack = []
      @startup = {}       # owner => { :scripts => seconds, :data_patches => seconds }
      @labels = {}

      class << self
        attr_reader :layers

        def on?
          return Profiler.on? && Profiler.setting(:mod_timings) ? true : false
        end

        def enabled?
          return @enabled ? true : false
        end

        # Every frame (from the frame clock): the timing goes on, and
        # the next frame is where you are now.
        def frame_start(_t)
          refresh if @enabled && Reloaded::Hooks.registry.length != @hooks_seen
          enable unless @enabled
        end

        # Hooks were added since the hooks were found (a feature switched
        # on): found again.
        def refresh
          disable
          @layers = []
        end

        def frame_end(_waited)
          @ctx = Profiler.context
          save
        end

        #----------------------------------------------------------------------
        # Kept (his ask, 2026-10-27: closing the game lost them). Walking
        # ends no session, so what Mod Timings found goes to Mod Timings.json
        # every SAVE_EVERY seconds while it runs, and into TimingProfile.txt
        # when the game closes (Profiler.closing).
        #----------------------------------------------------------------------
        SAVE_EVERY = 30.0
        FILE = "Mod Timings.json".freeze

        def path
          return File.join(Reloaded::Paths.settings_dir, FILE)
        end

        # What it found, as plain values: frames counted, and per owner its
        # time per frame on the map and in battle, startup, slowest hooks
        def snapshot
          return nil if @frames.values.sum.zero?
          ms = proc { |sec| sec && (sec * 1000.0).round(3) }
          return {
            "taken" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
            "frames" => { "map" => @frames[:map], "battle" => @frames[:battle], "other" => @frames[:other] },
            "owners" => owners.map do |o|
              st = startup_of(o)
              { "owner" => o, "map_ms" => ms.call(per_frame(o, :map)), "battle_ms" => ms.call(per_frame(o, :battle)),
                "startup_ms" => st.empty? ? nil : st.map { |k, v| [k.to_s, ms.call(v.to_f)] }.to_h,
                "hooks" => hooks(o).first(8).map do |label, s|
                  { "hook" => label, "calls" => s["calls"], "total_ms" => ms.call(s["total"]), "peak_ms" => ms.call(s["peak"]),
                    "slow" => s["slow"], "where" => s["where"] }
                end }
            end
          }
        end

        # force: now (the game closing), else at most every SAVE_EVERY seconds
        def save(force = false)
          return unless @enabled || force
          now = Profiler.clock
          return if !force && @saved_at && now - @saved_at < SAVE_EVERY
          snap = snapshot
          return nil unless snap
          @saved_at = now                 # (counted from the first one with something in it)
          Reloaded::Paths.write_atomic(path, Reloaded::JSON.generate(snap))
          return snap
        rescue StandardError => e
          Reloaded::Log.warning_once("Mod Timings couldn't be kept (#{e.class}: #{e.message})", :profiler)
          return nil
        end

        # The frame that just ran: counted where it ran, with its work (for
        # PIF and KIF's share).
        def add_frame_work(work)
          return unless @enabled
          ctx = @ctx || :other
          @frames[ctx] += 1
          @frame_work[ctx] += work
        end

        # Kanto Reloaded Debug's (Core/ModTimings.rb) find the layers and time
        # them; here, nothing is timed
        def enable; end

        def disable
          @enabled = false
          @stack = []
        end

        #----------------------------------------------------------------------
        # Startup
        #----------------------------------------------------------------------
        # part: :scripts or :data_patches
        def startup(owner, part, seconds)
          (@startup[owner.to_s] ||= Hash.new(0.0))[part] += seconds.to_f
        end

        # { :scripts, :data_patches } in seconds; a mod that loads before
        # Kanto Reloaded has no :scripts (it ran before anything could time it).
        def startup_of(owner)
          out = (@startup[owner.to_s] || {}).dup
          out[:scripts] = Reloaded::Bootstrap.seconds if owner.to_s == Owners::KR && Reloaded::Bootstrap.seconds
          dp = defined?(Reloaded::DataPatches) && Reloaded::DataPatches.respond_to?(:timings) ? Reloaded::DataPatches.timings[owner.to_s] : nil
          out[:data_patches] = dp if dp
          return out
        end

        #----------------------------------------------------------------------
        # What it found
        #----------------------------------------------------------------------
        # Every owner with something timed: Kanto Reloaded first, then mods
        # and EBDX by name, PIF and KIF last.
        def owners
          list = (@stats.keys + @context.keys + @startup.keys).uniq - [Owners::KIF, Owners::PIF, GAME_LABEL]
          list = list.sort_by { |o| [o == Owners::KR ? 0 : 1, o.downcase] }
          list << GAME_LABEL if @frames.values.sum > 0
          return list
        end

        # Seconds per frame there (:map or :battle), or nil when it never ran.
        def per_frame(owner, ctx)
          frames = @frames[ctx]
          return nil if frames.zero?
          time = owner == GAME_LABEL ? game_time(ctx) : (@context[owner] || {})[ctx].to_f
          return time > 0 ? time / frames : 0.0
        end

        def frames(ctx)
          return @frames[ctx]
        end

        # owner's hooks, slowest first: [[label, stats]]
        def hooks(owner)
          return (@stats[owner] || {}).sort_by { |_l, s| -s["peak"].to_f }
        end

        def clear
          @stats = {}
          @context = {}
          @frames = Hash.new(0)
          @frame_work = Hash.new(0.0)
          @saved_at = nil          # kept again at the next frame
        end

        private

        # The game's frame work there, less every mod's.
        def game_time(ctx)
          mods = @context.values.sum { |h| h[ctx].to_f }
          return [@frame_work[ctx] - mods, 0.0].max
        end
      end
    end
  end
end
