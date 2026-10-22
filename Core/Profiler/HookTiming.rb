#==============================================================================
# Kanto Reloaded: Mod Timings
#==============================================================================
# Each mod's share of the game's time (the Timing Profiler's Mod Timings):
# its startup, its Data Patches, its time per frame on the map and in
# battle, and its slowest hooks.
#
# A hook is a mod's code on one of the game's classes or modules: an alias
# wrapper (`alias old_update update; def update ... old_update`), a
# prepended module, Kanto Reloaded's Hooks.around and .prepend. Each layer
# of such a method (the mods' and the game's under them) gets a TracePoint
# aimed at it alone, so the rest of the game runs untouched, and a layer's
# time is its own: the layers it calls are taken off (they're timed too),
# and so is waiting in Graphics.update. Who a layer belongs to is the file
# it lives in (Owners); the game's own layers count as PIF and KIF.
#
# The TracePoints are on only while Mod Timings is (Timing Profiler On, Mod
# Timings On, KIF's DEBUG option on); they're found the first time.
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

        # Every frame (from the frame clock): the TracePoints go on, and
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
        end

        # The frame that just ran: counted where it ran, with its work (for
        # PIF and KIF's share).
        def add_frame_work(work)
          return unless @enabled
          ctx = @ctx || :other
          @frames[ctx] += 1
          @frame_work[ctx] += work
        end

        def enable
          return if @enabled
          discover if @layers.empty?
          @stack = []
          @layers.each do |l|
            begin
              l[:tp].enable(:target => l[:method])
            rescue StandardError, ArgumentError
              l[:off] = true      # this Ruby can't aim at it (a C method, an odd iseq)
            end
          end
          @enabled = true
        end

        def disable
          return unless @enabled
          @layers.each { |l| l[:tp].disable rescue nil }
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
        end

        #----------------------------------------------------------------------
        # The TracePoints' work (kept short: it runs on every call)
        #----------------------------------------------------------------------
        def enter
          @stack << [Profiler.clock, Profiler.waited, 0.0, Profiler.frame]
        end

        def leave(layer, tp)
          e = @stack.pop
          return unless e
          work = (Profiler.clock - e[0]) - (Profiler.waited - e[1])
          @stack.last[2] += work if @stack.last
          own = work - e[2]
          owner = layer[:owner]
          return if owner.nil?                # the game's own layer: only taken off its caller
          label = layer[:shared] ? shared_label(layer, tp) : layer[:label]
          return unless label                 # the profiler's own
          ctx = @ctx || :other
          per = (@context[owner] ||= Hash.new(0.0))
          per[ctx] = per[ctx].to_f + own
          s = ((@stats[owner] ||= {})[label] ||= { "calls" => 0, "total" => 0.0, "peak" => 0.0, "slow" => 0 })
          s["calls"] += 1
          s["total"] += own
          return unless Profiler.frame == e[3]       # one that ran across frames has no single-frame peak
          if own > s["peak"]
            s["peak"] = own
            cur = Profiler.current
            s["session"] = cur && cur["id"]
            s["where"] = cur && cur["name"]
          end
          s["slow"] += 1 if own > Profiler.slow_limit
        end

        private

        # The game's frame work there, less every mod's.
        def game_time(ctx)
          mods = @context.values.sum { |h| h[ctx].to_f }
          return [@frame_work[ctx] - mods, 0.0].max
        end

        # Kanto Reloaded's around hooks share one method body: which hook it
        # is comes from the module it's in.
        def shared_label(layer, tp)
          key = [tp.defined_class, tp.method_id]
          return @labels[key] ||= begin
            entry = Reloaded::Hooks.registry.find { |r| r[:module].equal?(tp.defined_class) && r[:method] == tp.method_id }
            if entry && entry[:id].to_s.start_with?("profiler_") then nil
            elsif entry then "#{entry[:klass]}##{entry[:method]} (#{entry[:id]})"
            else "#{tp.defined_class}##{tp.method_id}"
            end
          end
        end

        #----------------------------------------------------------------------
        # Finding the hooks
        #----------------------------------------------------------------------
        # Every game class and module (it has methods from the game's own
        # files) with mod code on it; each hooked method's layers.
        def discover
          started = Profiler.clock
          seen = {}
          @layers = []
          @keys = {}
          @hooks_seen = Reloaded::Hooks.registry.length
          modules = []
          ObjectSpace.each_object(Module) { |m| modules << m }
          modules.each do |m|
            [m, (m.singleton_class rescue nil)].compact.each do |c|
              next if seen[c.object_id]
              seen[c.object_id] = true
              scan(c) if game?(c)
            end
          end
          Reloaded::Log.info("Mod Timings: #{@layers.length} hook layers found in #{((Profiler.clock - started) * 1000).round} ms", :profiler)
        rescue StandardError => e
          Reloaded::Log.exception("Mod Timings couldn't find the hooks", e, :profiler)
        end

        def own_methods(c)
          return (c.instance_methods(false) + c.private_instance_methods(false)).uniq
        rescue StandardError
          return []
        end

        # c's own method (not a prepended module's above it, which is what
        # instance_method answers when one is there).
        def own_method(c, name)
          um = c.instance_method(name)
          um = um.super_method while um && !um.owner.equal?(c)
          return um
        rescue StandardError, NameError
          return nil
        end

        def file_of(c, name)
          um = own_method(c, name)
          loc = um && um.source_location
          return loc && loc[0]
        end

        # Has methods from the game's own files (PIF, KIF Beta).
        def game?(c)
          return own_methods(c).any? do |n|
            f = file_of(c, n)
            f && !f.match?(SKIP_PATH) && [Owners::PIF, Owners::KIF].include?(Owners.of(f))
          end
        end

        # A game class's hooked methods: each name with a mod's layer (its
        # own method, an alias of it, a prepended module's), all its layers.
        def scan(c)
          names = own_methods(c)
          prepended = (c.ancestors.take_while { |a| !a.equal?(c) } rescue [])
          by_name = Hash.new { |h, k| h[k] = [] }
          names.each do |n|
            um = own_method(c, n)
            next unless um && um.source_location
            by_name[um.original_name] << um
          end
          prepended.each do |mod|
            own_methods(mod).each do |n|
              um = (mod.instance_method(n) rescue nil)
              by_name[n] << um if um && um.source_location
            end
          end
          by_name.each do |name, ums|
            owners = ums.map { |um| Owners.of(um.source_location[0]) }
            next unless owners.any? { |o| o != Owners::PIF && o != Owners::KIF }
            ums.each_with_index { |um, i| add_layer(c, name, um, owners[i]) }
          end
        end

        def add_layer(c, name, um, owner)
          file, line = um.source_location
          return if file.match?(SKIP_PATH)
          # one per body and module: aliases share a body (one TracePoint
          # covers them all); define_method bodies are aimed at per method
          key = "#{file}:#{line}:#{um.owner.object_id}"
          return if @keys[key]
          @keys[key] = true
          shared = file.end_with?("Core/Foundation/Hooks.rb")
          mod_owner = [Owners::PIF, Owners::KIF].include?(owner) ? nil : owner
          # Kanto Reloaded's around hooks are one block in many modules: each
          # TracePoint answers only for its own module's calls
          home = shared ? um.owner : nil
          layer = { :owner => mod_owner, :label => "#{c}##{name}", :key => key, :shared => shared, :method => um }
          main = Thread.main
          layer[:tp] = TracePoint.new(:call, :return) do |tp|
            next unless Thread.current.equal?(main)
            next if home && !tp.defined_class.equal?(home)
            tp.event == :call ? HookTiming.enter : HookTiming.leave(layer, tp)
          end
          @layers << layer
        end
      end
    end
  end
end
