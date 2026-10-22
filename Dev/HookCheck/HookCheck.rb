#==============================================================================
# Kanto Reloaded (Dev): the Hook Checker
#==============================================================================
# Stonewall's own tool, never in a release (Roadmap topic 34). It checks
# Kanto Reloaded's hooks (Reloaded::Hooks.around and .prepend) against the
# KIF Beta they run on:
#
#   Broken            a hook whose class or method is gone (skipped at boot,
#                     or a prepend with nothing left under it), whose
#                     method's arguments changed, or that raised and was
#                     switched off
#   Changed Upstream  the same arguments, a new body: what changed since the
#                     KIF version checked before
#   Shared            other code on the same method (KIF features, mods), in
#                     the order it runs and how (prepend or alias)
#   Missing           a takeover's KIF feature folder, a lock or module in
#                     mod.json, a KIF setting Kanto Reloaded reads, or a
#                     split's file, gone under its name
#
# Each hooked method's arguments, visibility and body are kept for the KIF
# version they were seen on (Settings/Hook Check.json). At the first load
# screen of a session, when KIF Beta's version or Kanto Reloaded's hooks
# changed since the last check (Settings/Hook Check Version.json, a small
# file read at every start), the check runs; for a new KIF it compares with
# the copy from the version before, writes the report (Logging/Hook Check
# <version>.md, Report.rb) and shows the Update Alert (Alert.rb). With
# nothing changed it doesn't run, so the Main Menu isn't held up. KIF Settings > Kanto Reloaded > Developer Tools > Hook
# Check (KIF's DEBUG option on) opens the results (Screen.rb) any time.
#==============================================================================

module Reloaded
  module HookCheck
    STATE_FILE = "Hook Check.json"
    STAMP_FILE = "Hook Check Version.json"   # what the last check was on (read at each start)
    KINDS = [:broken, :changed, :shared, :missing, :ok].freeze
    MAX_BODY = 400                   # lines read for one method's body

    # One finding: a hook (kind :broken, :changed, :shared or :ok) or
    # something read by name (:missing, or :ok).
    class Result
      attr_accessor :kind, :id, :target, :method_key, :where, :feature, :what, :effect, :fix,
                    :diff, :added, :removed, :check, :others, :need, :name, :file

      def initialize(kind, id, fields = {})
        @kind = kind
        @id = id.to_s
        fields.each { |k, v| send("#{k}=", v) }
      end

      def hook?
        return @need.nil?
      end

      def problem?
        return @kind != :ok
      end
    end

    # A check: its results, the KIF versions it compared, its report.
    class Run
      attr_accessor :version, :previous, :results, :report, :version_changed, :time, :first

      def initialize
        @results = []
        @time = Time.now
      end

      def hooks
        return @results.select(&:hook?)
      end

      def needs
        return @results.reject(&:hook?)
      end

      # The problems, most serious first.
      def problems
        return @results.select(&:problem?).sort_by.with_index { |r, i| [KINDS.index(r.kind), i] }
      end

      def count(kind)
        return @results.count { |r| r.kind == kind }
      end

      def ok_hooks
        return hooks.count { |r| r.kind == :ok }
      end

      def all_ok?
        return problems.empty?
      end
    end

    class << self
      # The latest check this session, or nil.
      attr_reader :last

      def boot
        Reloaded::Settings.register(:"developer.hook_check", :page => :developer, :type => :button, :priority => 10,
          :name => "Hook Check", :preset => false,
          :on_press => proc { Reloaded::HookCheck::Screen.open },
          :description => "Checks Kanto Reloaded's hooks against this KIF Beta: what broke, what KIF changed, what else is on the same methods. Runs by itself when KIF updates.")
        if defined?(::PokemonLoad_Scene)
          Reloaded::Hooks.around(nil, "PokemonLoad_Scene", :pbChoose, :id => :hook_check_alert) do |original, *args|
            Reloaded::HookCheck.at_load_screen
            original.call(*args)
          end
        end
        return true
      end

      # The first load screen of the session. A new KIF: the full check runs
      # and the Update Alert shows. Kanto Reloaded's own hooks changed (a
      # new feature) on the same KIF: only the new hooks' methods are noted,
      # so a later KIF update has them to compare with; there's nothing
      # upstream to check. Otherwise nothing. The full check reads its saved
      # copy and every hooked method: seconds the Main Menu sat dim and
      # frozen on (2026-10-21, and again after Quality of Life's hooks).
      def at_load_screen
        return if @load_screen_done
        @load_screen_done = true
        return unless needs_check?
        if kif_changed?
          run = check(:boot)
          Alert.show(run) if run.version_changed
        else
          note_new_hooks
        end
      rescue StandardError => e
        Reloaded::Log.exception("The Hook Check at the load screen failed", e, :dev)
      end

      # Runs the check. reason: :boot (the report is written only when KIF's
      # version changed) or :manual (always written). The block, if given,
      # hears how far it is: |step, steps, what it's on| (Run Again's bar).
      def check(reason = :manual, &progress)
        hooks = Reloaded::Hooks.registry.length
        steps = hooks * 2 + 2
        step = 0
        tick = proc do |label|
          step += 1
          progress.call([step, steps].min, steps, label) if progress
        end
        version = kif_version
        state = load_state
        snap = take_snapshot(&tick)
        run = Run.new
        run.version = version
        if state.nil? || state["checked"] != version
          run.version_changed = true
          run.first = state.nil?
          run.previous = state ? state["checked"] : nil
          state = { "checked" => version, "previous" => run.previous,
                    "baseline" => state ? (state["current"] || {}) : snap, "current" => snap }
        else
          run.previous = state["previous"]
          state["baseline"] ||= {}
          snap.each { |k, v| state["baseline"][k] ||= v }      # a new hook: nothing to compare yet
          state["current"] = snap
        end
        save_state(state)
        write_stamp(version)
        @baseline = state["baseline"]
        compare(run, state["baseline"], snap, &tick)
        tick.call(_INTL("Writing the report"))
        run.report = Report.write(run) if run.version_changed || reason == :manual
        @last = run
        Reloaded::Log.info("Hook Check on KIF #{version}: #{run.count(:broken)} broken, #{run.count(:changed)} changed, " \
                           "#{run.count(:shared)} shared, #{run.count(:missing)} missing, #{run.ok_hooks} OK", :dev)
        return run
      end

      # KIF's version isn't the one last checked (or there's been no check)
      def kif_changed?
        state = load_state
        return state.nil? || state["checked"] != kif_version
      end

      # The hooks added since the last check: their methods as they are now,
      # into the saved copy (nothing is compared). Returns how many.
      def note_new_hooks
        state = load_state
        return 0 unless state
        base = (state["baseline"] ||= {})
        current = (state["current"] ||= {})
        # keys saved with a start's memory address (before they were made
        # the same every start) are dropped
        [base, current].each { |h| h.keys.each { |k| h.delete(k) if k =~ /#<Object:0x[0-9a-f]+>/i } }
        fresh = Reloaded::Hooks.registry.reject { |e| base.has_key?(key_of(e)) }
        forget_files
        fresh.each do |entry|
          data = snapshot_of(entry)
          next unless data
          base[key_of(entry)] = data
          current[key_of(entry)] = data
        end
        save_state(state)
        write_stamp(kif_version)
        Reloaded::Log.info("Hook Check: #{fresh.length} new hooks noted on KIF #{kif_version} (no full check: KIF is the same).", :dev)
        return fresh.length
      end

      def kif_version
        return ::KIF::PORT_VERSION.to_s if defined?(::KIF::PORT_VERSION)
        text = File.read(File.join(Reloaded::Paths.game_dir, "Data", "VERSION")) rescue nil
        return text ? text.strip : "?"
      end

      #------------------------------------------------------------------------
      # The hooked methods, as they are now
      #------------------------------------------------------------------------
      # { hook key => { "target", "args", "visibility", "file", "line", "body" } }
      def take_snapshot
        forget_files                     # read the game's files as they are now
        out = {}
        Reloaded::Hooks.registry.each do |entry|
          yield _INTL("Reading {1}", target_name(entry[:klass], entry[:method])) if block_given?
          data = snapshot_of(entry)
          out[key_of(entry)] = data if data
        end
        return out
      end

      # A hook's key, the same every start: a hook on one object's own
      # methods (the game's top-level object: pbPrintException) is named by
      # the engine with a memory address that changes each start, so that
      # part is left out. With it in, the hooks looked changed at every start
      # and the full check held up the Main Menu each time (2026-10-21).
      def key_of(entry)
        return "#{entry[:id]}|#{stable(entry[:target])}|#{entry[:method]}"
      end

      def stable(target)
        return target.to_s.gsub(/#<Object:0x[0-9a-f]+>/i, "#<Object>")
      end

      def snapshot_of(entry)
        m = original_of(entry)
        return nil unless m
        file, line = m.source_location
        path = full_path(file)
        return {
          "target"     => target_name(entry[:klass], entry[:method]),
          "args"       => m.parameters.map { |kind, name| [kind.to_s, name.to_s] },
          "visibility" => visibility(entry[:klass], entry[:method]).to_s,
          "file"       => path ? short_path(path) : file.to_s,
          "line"       => line,
          "body"       => path && line ? method_body(path, line) : nil
        }
      end

      # The method a hook wraps: the class's own (or an ancestor's), under
      # every module prepended to it.
      def original_of(entry)
        klass = entry[:klass]
        m = entry[:method]
        anc = klass.ancestors
        i = anc.index { |a| a.equal?(klass) } || 0
        owner = anc[i..-1].find { |a| defines?(a, m) }
        return owner ? own_method(klass, owner, m) : nil
      rescue StandardError
        return nil
      end

      # owner's own m, as klass finds it. (klass.instance_method looks in the
      # modules prepended to klass first, so it would find a hook.)
      def own_method(klass, owner, m)
        um = klass.instance_method(m)
        um = um.super_method while um && !um.owner.equal?(owner)
        return um
      end

      def defines?(mod, m)
        return mod.instance_methods(false).include?(m) || mod.private_instance_methods(false).include?(m)
      end

      def visibility(klass, m)
        return :private if klass.private_method_defined?(m)
        return :protected if klass.protected_method_defined?(m)
        return :public
      end

      # "Scene_Map#update", "KIF::SettingsScreen.description_for"
      def target_name(klass, m)
        name = klass.to_s
        return "#{$1}.#{m}" if name =~ /\A#<Class:(.+)>\z/
        return "#{name}##{m}"
      end

      # The game loads Data\Scripts with only each file's name as its source
      # path: a bare name is looked up there.
      def full_path(file)
        return nil if file.nil? || file.to_s.empty?
        return File.expand_path(file) if File.file?(file)
        return Reloaded::Paths.script_file(file)
      end

      # A path from the game folder ("Data/Scripts/...", "Mods/...").
      def short_path(path)
        p = File.expand_path(path).tr("\\", "/")
        root = File.expand_path(Reloaded::Paths.game_dir).tr("\\", "/")
        return p[(root.length + 1)..-1] if p.downcase.start_with?(root.downcase + "/")
        return p
      end

      # A method's lines, from its def to the end at the same indentation.
      def method_body(path, line)
        @files ||= {}
        lines = (@files[path] ||= File.read(path, :encoding => "UTF-8").gsub("\r", "").split("\n", -1))
        first = lines[line - 1]
        return nil unless first
        return first.rstrip if first =~ /\bend\s*\z/ || first =~ /\A\s*def\s+[\w.]+[?!]?(\([^)]*\))?\s*=(?![=~>])/
        indent = first[/\A\s*/].length
        out = [first.rstrip]
        lines[line, MAX_BODY].to_a.each do |ln|
          out << ln.rstrip
          return out.join("\n") if ln =~ /\A\s{#{indent}}end\b/ && ln[/\A\s*/].length == indent
        end
        return first.rstrip
      rescue StandardError
        return nil
      end

      def forget_files
        @files = nil
      end

      #------------------------------------------------------------------------
      # Saved copies
      #------------------------------------------------------------------------
      def state_path
        return File.join(Reloaded::Paths.settings_dir, STATE_FILE)
      end

      def load_state
        text = Reloaded::Paths.read_text(state_path)
        return nil if text.nil? || text.strip.empty?
        data = Reloaded::JSON.parse(text)
        return data.is_a?(Hash) ? data : nil
      rescue StandardError => e
        Reloaded::Log.warning("Hook Check: the saved copy couldn't be read (#{e.class}); starting again", :dev)
        return nil
      end

      def save_state(state)
        Reloaded::Paths.write_atomic(state_path, Reloaded::JSON.generate(state))
      end

      def stamp_path
        return File.join(Reloaded::Paths.settings_dir, STAMP_FILE)
      end

      # KIF's version or Kanto Reloaded's hooks changed since the last check
      # (or there's been none).
      def needs_check?
        text = Reloaded::Paths.read_text(stamp_path)
        data = text.nil? || text.strip.empty? ? nil : Reloaded::JSON.parse(text)
        return true unless data.is_a?(Hash) && File.file?(state_path)
        return data["kif"] != kif_version || data["hooks"] != hooks_stamp
      rescue StandardError
        return true
      end

      def write_stamp(version)
        Reloaded::Paths.write_atomic(stamp_path, Reloaded::JSON.generate({ "kif" => version, "hooks" => hooks_stamp }))
      end

      # Kanto Reloaded's hooks as one short value: one added or taken away
      # changes it.
      def hooks_stamp
        keys = Reloaded::Hooks.registry.map { |e| key_of(e) }.sort.join("\n")
        sum = keys.bytes.inject(0) { |h, b| (h * 31 + b) & 0xFFFFFFFF }
        return "#{Reloaded::Hooks.registry.length}-#{sum.to_s(16)}"
      end

      #------------------------------------------------------------------------
      # Comparing
      #------------------------------------------------------------------------
      def compare(run, baseline, snap)
        Reloaded::Hooks.skipped.each { |s| run.results << skipped_result(s) }
        Reloaded::Hooks.registry.each do |entry|
          yield _INTL("Comparing {1}", target_name(entry[:klass], entry[:method])) if block_given?
          next if helper?(entry, baseline)          # still a step of Run Again's bar
          run.results << hook_result(run, entry, baseline[key_of(entry)], snap[key_of(entry)])
        end
        yield _INTL("Takeovers and settings") if block_given?
        needs_results(run).each { |r| run.results << r }
        return run
      end

      # A prepended module's own helper, not a hook: the target had no method
      # of that name at boot, and no KIF version checked before had one
      # either (one an update took away is still Broken).
      def helper?(entry, baseline)
        return entry[:kind] == :prepend && entry[:overrides] == false && baseline[key_of(entry)].nil?
      end

      def hook_result(run, entry, base, now)
        target = target_name(entry[:klass], entry[:method])
        common = { :target => target, :method_key => target, :where => entry[:where],
                   :feature => entry[:feature], :file => now && now["file"] }
        if entry[:error]
          return Result.new(:broken, entry[:id], common.merge(
            :what => "It raised an error and was switched off this session: #{entry[:error]}.",
            :effect => "#{effect_of(entry[:feature])} until the game restarts.",
            :fix => "See the log for where it failed."))
        end
        if now.nil?
          args = base && base["args"]
          return Result.new(:broken, entry[:id], common.merge(
            :what => "Nothing under it any more: #{target} is gone.#{instead(entry[:klass], entry[:method], args)}",
            :effect => "Calls reach Kanto Reloaded's #{entry[:kind]} with nothing to pass on to.",
            :fix => fix_for(entry[:klass], entry[:method], args)))
        end
        if base && base["args"] != now["args"]
          return Result.new(:broken, entry[:id], common.merge(
            :what => "Its arguments changed: (#{args_text(base["args"])}) is now (#{args_text(now["args"])}).",
            :effect => "The hook still runs, but what it passes on (or reads) may not fit any more.",
            :fix => "Update the hook for the new arguments."))
        end
        others = others_on(entry)
        shared = others.any? { |o| !o[:ours] }
        changed = base && (base["body"] != now["body"] || base["visibility"] != now["visibility"])
        if changed
          r = Result.new(:changed, entry[:id], common.merge(:others => others))
          if base["body"] != now["body"]
            ops = Diff.lines(base["body"].to_s.split("\n"), now["body"].to_s.split("\n"))
            r.diff = ops
            r.added, r.removed = Diff.counts(ops)
          end
          if base["visibility"] != now["visibility"]
            r.what = "It is #{now["visibility"]} now (it was #{base["visibility"]})."
          end
          r.check = "#{entry[:where] || "The hook"} still fits the new #{target}."
          return r
        end
        return Result.new(shared ? :shared : :ok, entry[:id], common.merge(:others => others))
      end

      def skipped_result(s)
        target = s[:method] ? "#{s[:target].sub(/\A#<Class:(.+)>\z/, '\1')}#{s[:target] =~ /\A#<Class:/ ? "." : "#"}#{s[:method]}" : s[:target]
        klass = resolve(s[:target])
        base = (@baseline || {})["#{s[:id]}|#{s[:target]}|#{s[:method]}"]
        args = base && base["args"]
        what = if s[:reason] == "target not found"
                 "The class #{s[:target]} is gone."
               else
                 "The method is gone.#{klass ? instead(klass, s[:method], args) : ""}"
               end
        return Result.new(:broken, s[:id], :target => target, :method_key => target, :where => s[:where], :feature => s[:feature],
                          :what => what, :effect => "The hook is skipped at boot, so #{effect_of(s[:feature], true)}.",
                          :fix => klass ? fix_for(klass, s[:method], args) : "Find what replaced #{s[:target]} and hook that.")
      end

      # What runs without the hook; mid: inside a sentence.
      def effect_of(feature, mid = false)
        if feature && defined?(Reloaded::Features) && (f = Reloaded::Features.definition(feature))
          return "#{f[:name]} runs without it"
        end
        return "#{mid ? "this" : "This"} part of Kanto Reloaded falls back to the game's own code"
      end

      # " KIF 0.21.60 has `x` instead." when the class has a method with a
      # close name (and, when the old arguments are known, the same ones).
      def instead(klass, m, args = nil)
        alt = alternative(klass, m, args)
        return alt ? " KIF #{kif_version} has `#{alt}` instead." : ""
      end

      def fix_for(klass, m, args = nil)
        alt = alternative(klass, m, args)
        return "Find where KIF moved it and hook that." unless alt
        return args ? "Hook `#{alt}`; it takes the same arguments." : "Hook `#{alt}` if it does the same; check its arguments."
      end

      # A name a letter or three away, or with the same start ("pif_items"
      # and "pif_rows"), closest first.
      def alternative(klass, m, args = nil)
        return nil unless klass.is_a?(Module) && m
        m = m.to_s
        names = (klass.instance_methods(false) + klass.private_instance_methods(false)).uniq.map(&:to_s) - [m]
        found = names.select do |n|
          close = distance(n, m) <= [2, m.length / 4].max || common_start(n, m) >= [4, m.length / 2].min
          close && (args.nil? || klass.instance_method(n.to_sym).parameters.map { |k, x| [k.to_s, x.to_s] } == args)
        end
        return found.min_by { |n| [distance(n, m), n] }
      rescue StandardError
        return nil
      end

      def common_start(a, b)
        i = 0
        i += 1 while i < a.length && i < b.length && a[i] == b[i]
        return i
      end

      # Edit distance (short names only).
      def distance(a, b)
        prev = (0..b.length).to_a
        a.each_char.with_index(1) do |ca, i|
          cur = [i]
          b.each_char.with_index(1) { |cb, j| cur << [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (ca == cb ? 0 : 1)].min }
          prev = cur
        end
        return prev.last
      end

      def args_text(args)
        return Array(args).map do |kind, name|
          case kind
          when "req" then name
          when "opt" then "#{name} = ..."
          when "rest" then "*#{name}"
          when "keyreq" then "#{name}:"
          when "key" then "#{name}: ..."
          when "keyrest" then "**#{name}"
          when "block" then "&#{name}"
          else name
          end
        end.join(", ")
      end

      # A class from its name; "#<Class:X>" is X's singleton class.
      def resolve(name)
        name = name.to_s
        if name =~ /\A#<Class:(.+)>\z/
          inner = resolve($1)
          return inner ? inner.singleton_class : nil
        end
        return name.split("::").inject(Object) { |scope, part| scope.const_get(part, false) } if name =~ /\A[A-Z][\w:]*\z/
        return nil
      rescue NameError
        return nil
      end

      #------------------------------------------------------------------------
      # Others on the same method
      #------------------------------------------------------------------------
      # Everything on a hooked method, in the order it runs: modules
      # prepended to the class (Kanto Reloaded's and others'), then the
      # class's own method and the older ones it wraps by alias (the oldest,
      # the method itself, is left out). [{ :who, :how, :ours }, ...]
      def others_on(entry)
        klass = entry[:klass]
        m = entry[:method]
        out = []
        anc = klass.ancestors
        ki = anc.index { |a| a.equal?(klass) } || 0
        anc[0...ki].each do |mod|
          next unless defines?(mod, m)
          ours = Reloaded::Hooks.registry.find { |e| e[:module].equal?(mod) }
          if ours
            out << { :who => "Kanto Reloaded: #{ours[:id]}", :how => "prepend", :ours => true }
          else
            out << { :who => owner_of(file_of(own_method(klass, mod, m))) || mod.to_s, :how => "prepend", :ours => false }
          end
        end
        return out unless defines?(klass, m)
        # the class's method is the newest wrapper; the methods kept by alias
        # are older ones, the oldest (first loaded) the method itself
        newest = full_path(file_of(own_method(klass, klass, m)))
        older = (klass.instance_methods(false) + klass.private_instance_methods(false)).uniq.map do |n|
          next if n == m
          um = own_method(klass, klass, n)
          um && um.original_name == m ? full_path(file_of(um)) : nil
        end.compact.uniq - [newest]
        return out if older.empty?
        base = older.min_by { |f| load_order(f) }
        ([newest] + (older - [base]).sort_by { |f| load_order(f) }.reverse).compact.each do |f|
          who = owner_of(f)
          out << { :who => who, :how => "alias", :ours => who == "Kanto Reloaded" }
        end
        return out
      rescue StandardError
        return out || []
      end

      def file_of(um)
        loc = um.source_location
        return loc ? loc[0] : nil
      end

      # Data\Scripts in its folders' order, then mods.
      def load_order(path)
        s = short_path(path)
        group = s.start_with?("Data/Scripts/") ? 0 : (s.start_with?("Mods/") ? 1 : 2)
        return [group, s.downcase]
      end

      # Who a file belongs to: "Kanto Reloaded", "KIF: F-UI-05_SpeedUp",
      # "PIF: 002_Scene_Map.rb", a mod's folder.
      def owner_of(file)
        path = full_path(file)
        return file ? File.basename(file.to_s) : nil unless path
        root = File.expand_path(Reloaded::ROOT).tr("\\", "/").downcase
        return "Kanto Reloaded" if File.expand_path(path).tr("\\", "/").downcase.start_with?(root + "/")
        s = short_path(path)
        parts = s.split("/")
        if parts[0] == "Data" && parts[1] == "Scripts"
          if parts[2] == "990_KIF"
            rest = parts[3..-1]
            rest = rest[1..-1] if rest[0] == "ZZ_Cody"
            return "KIF: #{rest.length > 1 && rest[0] != "000_Core" ? rest[0] : File.basename(rest.last, ".rb")}"
          end
          return "PIF: #{parts.last}"
        end
        return "Mod: #{parts[1]}" if parts[0] == "Mods" && parts[1]
        return File.basename(s)
      end

      #------------------------------------------------------------------------
      # Takeovers and settings
      #------------------------------------------------------------------------
      def needs_results(run)
        out = []
        game = Reloaded::Paths.game_dir
        if defined?(Reloaded::Features)
          Reloaded::Features.all.each do |f|
            Array(f[:takes_over]).each do |folder|
              found = Dir.glob(File.join(game, "Data", "Scripts", "990_KIF", "**", folder)).any? { |d| File.directory?(d) }
              out << need_result(found, folder, "Takeover", "Features: #{f[:name]}",
                                 "KIF's feature folder #{folder} is gone.", "#{f[:name]} takes over nothing; KIF's feature may run beside it.")
            end
          end
        end
        mod = mod_json
        (mod["locks"] || {}).each_key do |key|
          out << need_result(kif_option?(key), key, "Lock", "mod.json",
                             "KIF has no setting #{key} any more.", "The lock in mod.json does nothing.")
        end
        (mod["modules"] || {}).each_key do |key|
          ok = defined?(::KIF::Modules::MODULES) && ::KIF::Modules::MODULES.key?(key.to_sym)
          out << need_result(ok, key, "Module", "mod.json",
                             "KIF has no module #{key} any more.", "mod.json's module setting does nothing.")
        end
        Reloaded::Hooks.needs_list.each do |n|
          ok, kind = case n[:kind]
                     when :field then [field?(n[:name]), "Setting"]
                     when :kif_option then [kif_option?(n[:name]), "KIF Setting"]
                     else [kif_setting_name?(n[:name]), "KIF Setting"]
                     end
          out << need_result(ok, n[:name], kind, n[:where] || n[:id],
                             "#{n[:kind] == :field ? "$PokemonSystem has no #{n[:name]}" : "KIF has no setting #{n[:name]}"} any more.",
                             "#{n[:id]} reads it and gets nothing.")
        end
        Reloaded::Settings.all_keys.each do |key|
          d = Reloaded::Settings.definition(key)
          b = d && d[:bind]
          next unless b && b.respond_to?(:field) && b.field
          out << need_result(field?(b.field), b.field, "Setting", "Settings: #{d[:name]}",
                             "$PokemonSystem has no #{b.field} any more.", "#{d[:name]} isn't kept in the game's own setting.")
        end
        if defined?(Reloaded::Controls::Splits) && Reloaded::Controls::Splits.respond_to?(:file_problems)
          Reloaded::Controls::Splits::FEATURES.each do |id, _b, files|
            files.each do |f|
              bad = Reloaded::Controls::Splits.file_problems.find { |sid, sf, _| sid == id && sf == f }
              out << need_result(bad.nil?, f, "Split File", "Controls: #{id}",
                                 bad ? "#{f} #{bad[2]}." : "", "#{id} just follows its button there.")
            end
          end
        end
        return merge_needs(out)
      end

      # A KIF setting both locked in mod.json and read by name is one row.
      def merge_needs(list)
        out = []
        list.each do |r|
          same = out.find { |o| o.name == r.name && o.kind == r.kind && [o.need, r.need].all? { |n| n == "Lock" || n == "KIF Setting" } }
          if same
            same.where = "#{same.where}, #{r.where}"
            same.effect = [same.effect, r.effect].compact.join(" ") if r.effect
          else
            out << r
          end
        end
        return out
      end

      def need_result(ok, name, need, where, what, effect)
        return Result.new(ok ? :ok : :missing, name, :need => need, :name => name.to_s, :where => where,
                          :what => ok ? nil : what, :effect => ok ? nil : effect,
                          :fix => ok ? nil : "Find its new name in KIF Beta #{kif_version} and update Kanto Reloaded.")
      end

      def mod_json
        text = Reloaded::Paths.read_text(File.join(Reloaded::ROOT, "mod.json"))
        data = text ? Reloaded::JSON.parse(text) : nil
        return data.is_a?(Hash) ? data : {}
      rescue StandardError
        return {}
      end

      def field?(name)
        return false unless defined?(::PokemonSystem)
        return ::PokemonSystem.method_defined?(name.to_sym) || ::PokemonSystem.private_method_defined?(name.to_sym)
      end

      def kif_option?(key)
        return false unless defined?(::KIF::Options) && ::KIF::Options.respond_to?(:defaults)
        d = ::KIF::Options.defaults
        return d.respond_to?(:key?) && (d.key?(key.to_sym) || d.key?(key.to_s))
      end

      def kif_setting_name?(name)
        return false unless defined?(::KIF::SettingsScreen::DESCRIPTIONS)
        return ::KIF::SettingsScreen::DESCRIPTIONS.key?(name.to_s)
      end
    end
  end
end
