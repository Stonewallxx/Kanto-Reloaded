#==============================================================================
# Kanto Reloaded: the Timing Profiler
#==============================================================================
# Old Kanto Reloaded's Battle Timing Profiler, grown (Roadmap topic 33). With
# KIF's DEBUG option on and Timing Profiler On (Kanto Reloaded > Timing Profiler), it
# times what you do while you play, each a session: battles, map loads,
# menus, saving and loading (Probes.rb); and every mod's hooks (Mod Timings,
# HookTiming.rb). Players never see it.
#
#   Reloaded::Profiler.session(:battle, "Wild Battle") { ... }
#   Reloaded::Profiler.measure("Map Data Load", :owner => "PIF") { ... }
#
# A session's sections each keep calls, total, peak and slow. Times are
# work, not waiting: time spent in Graphics.update (waiting for the next
# frame) is left out, and a section's peak is the most it did within one
# frame. A frame, or a section within one, over Slow Frame counts as slow.
# Every session has Frame Work: each frame's work while it ran.
#
# Kept: the newest sessions (Keep Sessions) in Kanto Reloaded\Timing
# Sessions.json for the Report Viewer, and each one added to
# Logging\TimingProfile.txt (Text Report, as old Kanto Reloaded's).
#==============================================================================

module Reloaded
  module Profiler
    KINDS = {
      :battle  => ["Battles", "profiler.battles"],
      :map     => ["Map Loads", "profiler.map_loads"],
      :menu    => ["Menus", "profiler.menus"],
      :saving  => ["Saving", "profiler.saving"],
      :loading => ["Saving", "profiler.saving"]       # loading a save goes with Saving
    }.freeze
    SLOW = [1 / 60.0, 1 / 30.0, 0.05].freeze           # Slow Frame's choices
    SLOW_NAMES = ["16.7 ms", "33.3 ms", "50 ms"].freeze
    FRAME_WORK = "Frame Work".freeze
    SESSIONS_FILE = "Timing Sessions.json".freeze
    REPORT_FILE = "TimingProfile.txt".freeze
    REPORT_MAX = 2_000_000                              # bytes before it starts again (.old.txt kept)

    @sessions = []     # finished, newest first (Hashes, as the JSON keeps them)
    @stack = []        # sessions running now, innermost last
    @measures = []     # sections running now (their frame chunks)
    @waited = 0.0      # seconds spent in Graphics.update since the game started
    @frame = 0
    @next_id = 1

    class << self
      attr_reader :frame

      def boot
        register_settings
        Reloaded::Hooks.prepend(nil, ::Graphics.singleton_class, FrameClock, :id => :profiler_frame_clock) if defined?(::Graphics)
        Reloaded::Events.on(:setting_changed, :profiler_switch) do |ctx|
          install if ctx[:key].to_s == "profiler.enabled" && ctx[:value]
        end
        # each mod's scripts, for Mod Timings' Startup (the mods that load
        # after Kanto Reloaded: the ones before ran before anything could time them)
        if defined?(::KIF::Mods) && ::KIF::Mods.respond_to?(:load_file)
          Reloaded::Hooks.around(nil, ::KIF::Mods.singleton_class, :load_file, :id => :profiler_mod_scripts) do |original, *args|
            started = clock
            begin
              original.call(*args)
            ensure
              HookTiming.startup(Owners.of(args[0].to_s), :scripts, clock - started)
            end
          end
        end
        return true
      end

      def register_settings
        s = Reloaded::Settings
        debug = proc { Reloaded.debug? }
        s.register_page(:profiler, :group => :general, :name => "Timing Profiler", :icon => :system, :priority => 1000,
          :visible => debug,
          :description => "Times battles, map loads, menus and saving while you play, and each mod's hooks.")
        s.register_page(:profiler_time, :group => :general, :name => "Timing Profiler - Time", :icon => :system, :priority => 1010,
          :visible => debug, :description => "What the Timing Profiler times.")
        s.register_page(:profiler_report, :group => :general, :name => "Timing Profiler - Report", :icon => :system, :priority => 1020,
          :visible => debug, :description => "What counts as slow, and what's kept.")
        s.register(:"profiler.enabled", :page => :profiler, :priority => 0, :type => :toggle, :default => false, :preset => false,
          :name => "Timing Profiler",
          :description => "Times what you pick below while you play, and keeps each session for the Report Viewer. Shown only with DEBUG on (Settings, Advanced).")
        s.register(:"profiler.viewer", :page => :profiler, :priority => 10, :type => :button, :preset => false,
          :name => "Report Viewer",
          :on_press => proc { Reloaded::ProfilerScreen.open(:sessions, true) if defined?(Reloaded::ProfilerScreen) },
          :description => "The sessions timed so far, newest first, and Mod Timings: Each mod's startup and hooks.")
        [["battles", "Battles", "Each battle: Its turns' phases, the scene's frame work and EBDX's windows."],
         ["map_loads", "Map Loads", "Each map you go to: Its data, events, sprites and music."],
         ["menus", "Menus", "The Bag, Party, PC, Summary, Pokédex and Pause Menu, from opening to closing."],
         ["saving", "Saving", "Saving the game, and loading a save."],
         ["mod_timings", "Mod Timings", "Each mod's hooks, timed on their own: Their time per frame and their slowest calls."]].each_with_index do |(key, name, desc), i|
          s.register(:"profiler.#{key}", :page => :profiler_time, :priority => i * 10, :type => :toggle, :default => true,
            :preset => false, :name => name, :description => desc)
        end
        s.register(:"profiler.slow_frame", :page => :profiler_report, :priority => 0, :type => :enum, :default => 1,
          :values => SLOW_NAMES, :preset => false, :name => "Slow Frame",
          :descriptions => ["One frame at 60 frames a second.", "Two frames at 60.", "Three frames at 60."],
          :description => "A frame counts as slow above this: 33.3 ms is two frames at 60, 16.7 ms is one.")
        s.register(:"profiler.keep", :page => :profiler_report, :priority => 10, :type => :number, :default => 25,
          :min => 5, :max => 100, :step => 5, :preset => false, :name => "Keep Sessions",
          :description => "How many sessions the Report Viewer keeps; the oldest go first.")
        s.register(:"profiler.text_report", :page => :profiler_report, :priority => 20, :type => :toggle, :default => true,
          :preset => false, :name => "Text Report",
          :description => "Also adds each session to TimingProfile.txt in the Logging folder, as old Kanto Reloaded's profiler did.")
      end

      #------------------------------------------------------------------------
      # Switches
      #------------------------------------------------------------------------
      def on?
        return Reloaded.debug? && setting(:enabled) ? true : false
      end

      def times?(kind)
        k = KINDS[kind.to_sym]
        return on? && (k.nil? || setting(k[1].sub("profiler.", "")) ? true : false)
      end

      def slow_limit
        return SLOW[setting(:slow_frame).to_i] || SLOW[1]
      end

      def setting(key)
        return Reloaded::Settings.get(:"profiler.#{key}")
      rescue StandardError
        return nil
      end

      # The probes and hook timing go in the first time the profiler runs
      # (players, who never switch it on, never get them).
      def install
        return if @installed
        @installed = true
        Reloaded::Hooks.guard(nil, :profiler_probes) { Probes.install } if defined?(Probes)
      end

      def installed?
        return @installed ? true : false
      end

      #------------------------------------------------------------------------
      # Sessions and sections
      #------------------------------------------------------------------------
      def clock
        return Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      # Time spent waiting in Graphics.update so far (work = elapsed - this).
      def waited
        return @waited
      end

      # Runs the block as a session (when its kind is timed). info: anything
      # the report should say ({ "Turns" => 3 }); a block given to info is
      # asked at the end.
      def session(kind, name, info = {}, &block)
        return yield unless times?(kind)
        s = start_session(kind, name, info)
        begin
          result = yield
        rescue Exception => e
          s["error"] = "#{e.class}: #{e.message}" unless Reloaded::Hooks.passthrough?(e)
          raise
        ensure
          finish_session(s)
        end
        return result
      end

      def start_session(kind, name, info = {})
        install
        s = { "id" => @next_id, "kind" => kind.to_s, "name" => name.to_s, "where" => map_name,
              "started" => Time.now.strftime("%Y-%m-%d %H:%M:%S"), "sections" => {}, "info" => info,
              "t0" => clock, "w0" => @waited, "f0" => @frame }
        @next_id += 1
        @stack << s
        return s
      end

      def finish_session(s)
        @stack.delete(s)
        t = clock
        s["elapsed"] = t - s.delete("t0")
        s["work"] = s["elapsed"] - (@waited - s.delete("w0"))
        s["frames"] = @frame - s.delete("f0")
        s["slow_limit"] = slow_limit
        info = s["info"]
        s["info"] = info.respond_to?(:call) ? (info.call rescue {}) : info
        s["status"] = status_of(s).to_s
        load_kept unless @kept_loaded        # an earlier run's, before this run's are written over them
        @sessions.unshift(s)
        keep = [setting(:keep).to_i, 5].max
        @sessions.slice!(keep..-1) if @sessions.length > keep
        save
        Report.append(s) if setting(:text_report) && defined?(Report)
        Reloaded::Events.emit(:profiler_session, :session => s)
        return s
      rescue StandardError => e
        Reloaded::Log.exception("A timing session couldn't be finished", e, :profiler)
        return s
      end

      # The session running now (the innermost), or nil.
      def current
        return @stack.last
      end

      def running?(s)
        return @stack.include?(s)
      end

      # Times the block as a section of the session running now.
      def measure(label, owner: Owners::PIF, about: nil)
        s = @stack.last
        return yield unless s
        m = { :t0 => clock, :w0 => @waited, :mark => nil, :chunk => 0.0, :f0 => @frame, :label => label }
        m[:mark] = m[:t0]
        @measures << m
        begin
          return yield
        ensure
          @measures.delete(m)
          t = clock
          m[:chunk] = [m[:chunk], t - m[:mark]].max
          record(s, label, t - m[:t0] - (@waited - m[:w0]), m[:chunk], owner, about, @measures.last)
        end
      end

      # Adds one timing to a section of session s. work: its work; peak: its
      # most within one frame. parent: the section it ran inside (nested
      # sections overlap).
      def record(s, label, work, peak, owner, about = nil, parent = nil)
        sec = (s["sections"][label] ||= { "calls" => 0, "total" => 0.0, "peak" => 0.0, "slow" => 0,
                                          "owner" => owner.to_s, "order" => s["sections"].length })
        sec["about"] ||= about if about
        sec["inside"] ||= parent[:label] if parent && parent[:label]
        sec["calls"] += 1
        sec["total"] += [work, 0.0].max
        sec["peak"] = peak if peak > sec["peak"]
        sec["slow"] += 1 if peak > slow_limit
        return sec
      end

      #------------------------------------------------------------------------
      # Frames
      #------------------------------------------------------------------------
      # Called by Graphics.update (FrameClock): the frame's work goes in the
      # session's Frame Work, and sections running across frames close a
      # chunk.
      def frame_start
        t = clock
        if @frame_end
          work = t - @frame_end
          record(@stack.last, FRAME_WORK, work, work, "All", nil) if @stack.last
          HookTiming.add_frame_work(work)
        end
        @measures.each { |m| m[:chunk] = [m[:chunk], t - m[:mark]].max }
        HookTiming.on? ? HookTiming.frame_start(t) : HookTiming.disable
        return t
      end

      def frame_end(started)
        t = clock
        @waited += t - started
        @frame += 1
        @frame_end = t
        @measures.each { |m| m[:mark] = t }
        HookTiming.frame_end(t - started)
      end

      # The profiler is off: Mod Timings' TracePoints too.
      def idle
        HookTiming.disable if HookTiming.enabled?
        @frame_end = nil
      end

      # Where you are: map / battle / other (Mod Timings' per-frame columns).
      def context
        return :battle if defined?($game_temp) && $game_temp && ($game_temp.in_battle rescue false)
        return :map if defined?(::Scene_Map) && $scene.is_a?(::Scene_Map)
        return :other
      end

      #------------------------------------------------------------------------
      # Kept sessions
      #------------------------------------------------------------------------
      # Newest first: this run's, then earlier runs' from the file.
      def sessions
        load_kept unless @kept_loaded
        return @sessions
      end

      def clear
        @sessions = []
        @kept_loaded = true
        save
      end

      # :ok, :amber or :red: the worst peak against Slow Frame (kept as a
      # string in the session).
      def status_of(s)
        limit = s["slow_limit"] || slow_limit
        worst = s["sections"].values.map { |x| x["peak"].to_f }.max || 0.0
        return :red if s["sections"].values.any? { |x| x["slow"].to_i > 0 } || worst > limit
        return :amber if worst > limit / 2
        return :ok
      end

      def severity(ms_or_seconds, limit = slow_limit)
        v = ms_or_seconds.to_f
        return :red if v > limit
        return :amber if v > limit / 2
        return :ok
      end

      def path
        return File.join(Reloaded::Paths.settings_dir, SESSIONS_FILE)
      end

      def save
        list = @sessions.map { |s| s.reject { |k, _| k == "t0" || k == "w0" || k == "f0" } }
        Reloaded::Paths.write_atomic(path, Reloaded::JSON.generate({ "version" => 1, "sessions" => list }))
      rescue StandardError => e
        Reloaded::Log.exception("Timing sessions couldn't be saved", e, :profiler)
      end

      def load_kept
        @kept_loaded = true
        return unless File.file?(path)
        data = Reloaded::JSON.parse(Reloaded::Paths.read_text(path).to_s)
        old = Array(data.is_a?(Hash) ? data["sessions"] : nil).select { |s| s.is_a?(Hash) && s["sections"].is_a?(Hash) }
        ids = @sessions.map { |s| s["id"] }
        old.each do |s|
          s["earlier"] = true
          s["status"] = (s["status"] || "ok").to_s
          s["id"] = "earlier-#{s["id"]}"
          @sessions << s unless ids.include?(s["id"])
        end
        keep = [setting(:keep).to_i, 5].max
        @sessions.slice!(keep..-1) if @sessions.length > keep
      rescue StandardError => e
        Reloaded::Log.exception("Kept timing sessions couldn't be read", e, :profiler)
      end

      def map_name
        return nil unless defined?($game_map) && $game_map
        id = $game_map.map_id
        name = defined?(pbGetMapNameFromId) ? (pbGetMapNameFromId(id) rescue nil) : nil
        return name.to_s.empty? ? "Map #{id}" : name.to_s
      rescue StandardError
        return nil
      end

      # For tests: back to a fresh start.
      def reset
        @sessions = []
        @stack = []
        @measures = []
        @waited = 0.0
        @frame = 0
        @frame_end = nil
        @next_id = 1
        @kept_loaded = false
      end
    end

    # Graphics.update, timed: the wait for the next frame is left out of
    # every section's work. Always in (it's one check per frame); the rest
    # of the profiler goes in when it's first switched on.
    module FrameClock
      def update(*args)
        unless Reloaded::Profiler.on?
          Reloaded::Profiler.idle if Reloaded::Profiler.installed?
          return super
        end
        Reloaded::Profiler.install
        started = Reloaded::Profiler.frame_start
        begin
          return super
        ensure
          Reloaded::Profiler.frame_end(started)
        end
      end
    end
  end
end
