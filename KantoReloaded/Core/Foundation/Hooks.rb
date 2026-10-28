#==============================================================================
# Kanto Reloaded: Hooks
#==============================================================================
# How Kanto Reloaded changes the game's (and KIF's) code without editing it.
# Every hook belongs to a feature and is listed in a registry, so conflicts
# with KIF and other mods can be logged and shown in bug reports.
#
# 1. around: wraps a method. The block gets a callable for the original
#    and the call's arguments:
#
#      Reloaded::Hooks.around(:pc, "PokemonStorageScreen", :pbStartScreen,
#                             :id => :pc_open) do |original, *args|
#        ...
#        original.call(*args)
#      end
#
#    original.receiver is the object the method was called on (an instance
#    method's self), for hooks that need it. original.call passes on the
#    block the method was called with (the game's message boxes take one
#    to keep a scene moving) unless the hook gives one of its own.
#
#    While the feature is off, or after the hook has failed, calls go
#    straight to the original. If the hook's own code raises, the feature is
#    switched off for the session (logged once) and the call falls back to
#    the original. Errors raised by the original itself pass through
#    untouched, and so do errors the hook raises on purpose, named with
#    :passes => [IOError] (safe saving's "the save didn't write"). A class
#    method is hooked on its singleton class:
#    Hooks.around(:core, Game.singleton_class, :set_up_system, ...).
#
# 2. prepend: for code that runs every frame (input, drawing), where even a
#    small allocation per call matters. The module's methods call `super`
#    and check Reloaded::Features.on?(feature) themselves; Hooks.guard
#    wraps the risky part:
#
#      module ControlsInput
#        def trigger?(button)
#          return super unless Reloaded::Features.on?(:controls)
#          ...
#        end
#      end
#      Reloaded::Hooks.prepend(:controls, Input.singleton_class, ControlsInput, :id => :input)
#
# A target can be a Module/Class or a constant name ("PokemonLoadScreen");
# a name that doesn't exist is logged and the hook is skipped.
# A feature of nil means a core hook: it can't be switched off, and if it
# fails only that hook stops (it falls through to the original).
#
# 3. watch: a prepend that only watches (Recent Steps, the Timing
#    Profiler). Kanto Reloaded's own Party and Bag scenes are subclasses of
#    the game's that replace its methods without calling up, so a module
#    on the game's class alone never sees them. A watcher goes on the
#    game's class and on every scene class Kanto Reloaded makes from it
#    (Hooks.scene_class), now or later. Its methods check
#    Hooks.watching? first, so a scene that falls back to the game's own
#    (and so calls up) isn't seen twice:
#
#      mod = Module.new do
#        def pbStartScene(*args)
#          return super if Reloaded::Hooks.watching?(self, :my_step)
#          Reloaded::Hooks.watching(self, :my_step) { note_it; super }
#        end
#      end
#      Reloaded::Hooks.watch("PokemonParty_Scene", mod, :id => :my_step)
#
# 4. needs: something of the game's Kanto Reloaded reads by name without
#    hooking it (a $PokemonSystem field, a KIF option key, a KIF setting's
#    name), so a check after a game update can say it's gone:
#
#      Reloaded::Hooks.needs(:field, :runstyle, :id => :controls_run_toggle)
#
# The registry keeps each hook's target, method, kind and where in Kanto
# Reloaded it was made; hooks that were skipped (and why), errors that
# switched one off, and the needs. Bug reports and the Hook Checker read it.
#
# 5. Other mods' aliases: a mod that hooks the old way (alias the method,
#    then def a new one) after Kanto Reloaded hooked the same method gets a
#    copy of Kanto Reloaded's hook under its alias (Ruby aliases what the
#    prepended module gives), so the two call each other for ever (Alpha
#    Encounters' Graphics.update, 2026-10-25: the game couldn't start).
#    Kanto Reloaded keeps each method as it was before its first hook on it
#    (the class's own, past every prepended module); repair_aliases, run
#    once every mod has loaded (Lifecycle), points each such alias back at
#    that: what the mod meant to alias. Each hook then runs once, in order.
#==============================================================================

module Reloaded
  module Hooks
    @registry = []
    @skipped = []
    @needs = []
    @before = {}       # [klass, method] => the class's own method before Kanto Reloaded hooked it
    NEED_KINDS = [:field, :kif_option, :kif_setting].freeze   # $PokemonSystem field, KIF::Options key, KIF setting name

    # The callable an around hook's block gets for the original method.
    class Original
      def initialize(receiver = nil, &block)
        @receiver = receiver
        @block = block
        @ran = false
        @raised = false
      end

      attr_reader :ran, :raised, :result, :receiver

      def call(*args, **kwargs, &blk)
        @ran = true
        begin
          @result = @block.call(*args, **kwargs, &blk)
        rescue Exception
          @raised = true
          raise
        end
        return @result
      end
    end

    class << self
      attr_reader :registry

      def around(feature, target, method_name, options = {}, &body)
        raise ArgumentError, "Hooks.around needs a block" unless body
        where = caller_site
        klass = resolve(target)
        return skip(feature, target, method_name, options, "target not found", where) unless klass
        method_name = method_name.to_sym
        unless klass.method_defined?(method_name) || klass.private_method_defined?(method_name)
          return skip(feature, target, method_name, options, "method not found", where)
        end
        entry = record(feature, klass, method_name, :around, options, where)
        entry[:params] = body.parameters             # the Hook Check: a hook taking (original, *args) fits any arguments
        visibility = visibility_of(klass, method_name)
        passes = Array(options[:passes])
        mod = Module.new
        mod.send(:define_method, method_name) do |*args, **kwargs, &blk|
          unless entry[:active] && (feature.nil? || Reloaded::Features.on?(feature))
            next super(*args, **kwargs, &blk)
          end
          original = Original.new(self) { |*a, **k, &b| super(*a, **k, &(b || blk)) }   # the caller's block, unless the hook gives one
          begin
            next body.call(original, *args, **kwargs, &blk)
          rescue Exception => e
            raise if Reloaded::Hooks.passthrough?(e) || original.raised || passes.any? { |k| e.is_a?(k) }
            Reloaded::Hooks.failed(entry, e)
            next original.result if original.ran
            next super(*args, **kwargs, &blk)
          end
        end
        mod.send(visibility, method_name) unless visibility == :public
        klass.prepend(mod)
        entry[:module] = mod
        return true
      end

      def prepend(feature, target, mod, options = {})
        where = caller_site
        klass = resolve(target)
        names = mod.instance_methods(false) + mod.private_instance_methods(false)
        unless klass
          names.each { |method_name| skip(feature, target, method_name, options, "target not found", where) }
          return false
        end
        entry = nil
        names.each do |method_name|
          entry = record(feature, klass, method_name, :prepend, options, where)
          entry[:module] = mod
          # false: the target has no method of that name, so it's one of the
          # module's own helpers (unless an update took the target's away,
          # which the Hook Check tells from its copy of the version before)
          entry[:overrides] = klass.method_defined?(method_name) || klass.private_method_defined?(method_name)
        end
        klass.prepend(mod)
        return true
      end

      # A watcher: on the game's class and on Kanto Reloaded's scene classes
      # made from it (see the top)
      def watch(target, mod, options = {})
        return false unless prepend(nil, target, mod, options)
        klass = resolve(target)
        (@watchers ||= []) << [klass, mod, options]
        (@scene_classes ||= []).each { |base, sub| mirror(sub, mod, options) if base == klass }
        return true
      end

      # A scene class of Kanto Reloaded's (a subclass of the game's base):
      # the watchers on base go on it too
      def scene_class(base, sub)
        (@scene_classes ||= []) << [base, sub]
        (@watchers || []).each { |klass, mod, options| mirror(sub, mod, options) if klass == base }
        return sub
      end

      # Inside a watcher already, for this object (a scene's fallback calls
      # up to the game's class, where the same watcher sits)
      def watching?(obj, key)
        return obj.instance_variable_get(:"@kr_watching_#{key}") ? true : false
      end

      def watching(obj, key)
        flag = :"@kr_watching_#{key}"
        obj.instance_variable_set(flag, true)
        return yield
      ensure
        obj.instance_variable_set(flag, nil)
      end

      # Runs the block; an error switches the feature off for the session and
      # returns fallback instead.
      def guard(feature, where = nil, fallback = nil)
        return yield
      rescue Exception => e
        raise if passthrough?(e)
        Reloaded::Features.fail!(feature, e, where) if feature
        Reloaded::Log.exception("Hook #{where} failed", e, :hooks) unless feature
        return fallback
      end

      def failed(entry, error)
        entry[:error] ||= "#{error.class}: #{error.message}"
        if entry[:feature]
          Reloaded::Features.fail!(entry[:feature], error, entry[:id])
        else
          entry[:active] = false
          Reloaded::Log.exception("Core hook #{entry[:id]} failed and is off for this session", error, :hooks)
        end
      end

      # Hooks that were skipped: { :id, :feature, :target, :method, :reason,
      # :where }.
      def skipped
        return @skipped.dup
      end

      # Something of the game's read by name (see the top). kind: :field,
      # :kif_option or :kif_setting.
      def needs(kind, name, options = {})
        raise ArgumentError, "Hooks.needs: unknown kind #{kind}" unless NEED_KINDS.include?(kind)
        @needs << { :kind => kind, :name => name, :id => (options[:id] || name).to_s, :where => caller_site }
        return true
      end

      def needs_list
        return @needs.dup
      end

      # Errors that must never be swallowed: the game's soft reset and exit.
      def passthrough?(error)
        return true if error.is_a?(SystemExit)
        return true if defined?(Reset) && error.is_a?(Reset)
        return false
      end

      # Other code that changed the same method: prepended modules above or
      # below ours that aren't Kanto Reloaded's. For bug reports.
      def conflicts
        list = []
        @registry.each do |entry|
          klass = entry[:klass]
          others = klass.ancestors.take_while { |a| a != klass }.reject { |a| a.equal?(entry[:module]) || ours?(a) }
          others = others.select { |a| a.instance_methods(false).include?(entry[:method]) || a.private_instance_methods(false).include?(entry[:method]) }
          list << [entry, others] unless others.empty?
        end
        return list
      end

      # Another mod's alias that copied one of Kanto Reloaded's hooks goes
      # back to the method as it was before Kanto Reloaded (see the top).
      # Returns what was put right: ["Graphics.update via __alias", ...].
      def repair_aliases
        fixed = []
        failed = []
        mine = Reloaded::ROOT.to_s.tr("\\", "/") + "/"
        @before.each do |(klass, name), original|
          next unless original
          (klass.instance_methods(false) + klass.private_instance_methods(false)).each do |m|
            next if m == name
            copy = (klass.instance_method(m) rescue nil)
            next unless copy && copy.original_name == name
            next if copy.source_location == original.source_location      # already the method as it was
            file = copy.source_location && copy.source_location[0].to_s.tr("\\", "/")
            next unless file && file.start_with?(mine)
            begin
              visibility = visibility_of(klass, m)
              klass.send(:define_method, m, original)
              klass.send(visibility, m) unless visibility == :public
              fixed << "#{klass}##{name} via #{m}"
            rescue StandardError => e
              failed << "#{klass}##{name} via #{m} (#{e.class}: #{e.message})"
            end
          end
        end
        # Put right, nothing is wrong any more: INFO, so a real warning
        # stands out (his call, 2026-10-27; Alpha Encounters and KIF-ER do
        # this every start). Only one that couldn't be put right warns.
        unless fixed.empty?
          Reloaded::Log.info("Another mod's alias copied Kanto Reloaded's hook (a loop), now the method as it was: #{fixed.join(", ")}", :hooks)
        end
        unless failed.empty?
          Reloaded::Log.warning("Another mod's alias copied Kanto Reloaded's hook (a loop) and it couldn't be put back, so that method may loop: #{failed.join(", ")}", :hooks)
        end
        return fixed
      rescue StandardError => e
        Reloaded::Log.exception("Other mods' aliases couldn't be checked", e, :hooks)
        return []
      end

      def summary
        return @registry.map do |e|
          state = e[:active] ? (e[:feature].nil? || Reloaded::Features.on?(e[:feature]) ? "on" : "off") : "failed"
          "#{e[:id]}: #{e[:target]}##{e[:method]} (#{e[:kind]}, #{e[:feature] || 'core'}, #{state})"
        end
      end

      private

      def resolve(target)
        return target if target.is_a?(Module)
        name = target.to_s
        return nil if name.empty?
        return name.split("::").inject(Object) { |scope, part| scope.const_get(part, false) }
      rescue NameError
        return nil
      end

      def record(feature, klass, method_name, kind, options, where = nil)
        entry = {
          :id      => (options[:id] || "#{klass}##{method_name}").to_s,
          :feature => feature && feature.to_sym,
          :klass   => klass,
          :target  => klass.to_s,
          :method  => method_name,
          :kind    => kind,
          :active  => true,
          :where   => where
        }
        if @registry.any? { |e| e[:klass] == klass && e[:method] == method_name }
          Reloaded::Log.debug("#{entry[:id]}: another Kanto Reloaded hook already wraps #{entry[:target]}##{method_name}", :hooks)
        end
        key = [klass, method_name]
        @before[key] = own_method(klass, method_name) unless @before.key?(key)
        @registry << entry
        return entry
      end

      def mirror(sub, mod, options)
        return if sub.ancestors.take_while { |a| a != sub }.include?(mod)
        prepend(nil, sub, mod, options.merge(:id => "#{options[:id] || mod}_kr_scene"))
      end

      def skip(feature, target, method_name, options, reason, where = nil)
        id = (options[:id] || "#{target}##{method_name}").to_s
        @skipped << { :id => id, :feature => feature && feature.to_sym, :target => target.to_s,
                      :method => method_name && method_name.to_sym, :reason => reason, :where => where }
        Reloaded::Log.warning("Hook #{id} skipped: #{reason}", :hooks)
        return false
      end

      # Where in Kanto Reloaded a hook was made: "Core/Settings/KIFBridge.rb:87".
      def caller_site
        loc = caller_locations(2, 8).find { |l| !l.path.to_s.end_with?("Hooks.rb") }
        return nil unless loc
        path = loc.path.to_s.tr("\\", "/")
        root = Reloaded::ROOT.to_s.tr("\\", "/")
        path = path[(root.length + 1)..-1] if path.start_with?(root + "/")
        return "#{path}:#{loc.lineno}"
      end

      def visibility_of(klass, method_name)
        return :private if klass.private_method_defined?(method_name)
        return :protected if klass.protected_method_defined?(method_name)
        return :public
      end

      # The class's own method of that name, past every module prepended to
      # it (nil when it has none of its own)
      def own_method(klass, name)
        return nil unless klass.method_defined?(name) || klass.private_method_defined?(name)
        m = klass.instance_method(name)
        m = m.super_method while m && m.owner != klass
        return m
      rescue StandardError
        return nil
      end

      def ours?(mod)
        return @registry.any? { |e| e[:module].equal?(mod) }
      end
    end
  end
end
