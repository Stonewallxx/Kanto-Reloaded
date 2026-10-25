#==============================================================================
# Kanto Reloaded: Bootstrap
#==============================================================================
# KIF Beta loads this file (mod.json "scripts") once at startup, after every
# game script and before the game data and $PokemonSystem are loaded.
#
#   - Loads every file listed in LoadOrder.rb, in order, then Dev/Dev.rb
#     when it's there (Stonewall's own tools, never in a release).
#   - Boots the core systems listed in LoadOrder::SYSTEMS, in order.
#   - A file or system that fails is logged and skipped; the game keeps
#     running, and anything that depends on it falls back to the game's own
#     behaviour.
#
# Everything lives in `module Reloaded`. Inside it, `Settings` means
# Reloaded::Settings; the game's settings module is always `::Settings`.
#==============================================================================

module Reloaded
  ROOT = File.expand_path(File.dirname(__FILE__)) unless const_defined?(:ROOT, false)

  # The version in mod.json.
  def self.version
    @version ||= begin
      text = File.read(File.join(ROOT, "mod.json"), :encoding => "UTF-8") rescue ""
      text[/"version"\s*:\s*"([^"]+)"/, 1] || "0.0.0"
    end
  end

  # KIF's DEBUG option (Settings > Advanced) is on, or the game runs in
  # debug mode: the tools a modder might use show (in the Kanto Reloaded
  # section: the Timing Profiler, Hot Reload, the Save Checker's Inspector).
  # KIF copies the option into $DEBUG only when it's changed and while you're
  # on the map, so the option itself is asked too (at the title screen
  # $DEBUG can still be off with the option on).
  def self.debug?
    return true if $DEBUG
    ps = $PokemonSystem
    return ps.respond_to?(:debug) && (ps.debug rescue 0).to_i == 1
  end

  # The Kanto Reloaded Debug mod is installed: the KR Debug section, which
  # is Stonewall's alone (his ask, 2026-10-25), shows.
  def self.debug_mod?
    return DebugMod.attached?
  end

  # The Kanto Reloaded Debug mod says it's here (its main.rb):
  #   Reloaded::DebugMod.attach(:name => "Kanto Reloaded Debug", :version => "1.0.0")
  module DebugMod
    class << self
      attr_reader :info

      def attach(name: "Kanto Reloaded Debug", version: nil)
        @info = { :name => name.to_s, :version => version.to_s }
        Reloaded::Log.info("#{name} #{version} attached: the KR Debug section is on", :bootstrap) if defined?(Reloaded::Log)
        return true
      end

      def detach
        @info = nil
      end

      def attached?
        return !@info.nil?
      end
    end
  end

  module Bootstrap
    LOAD_ORDER_FILE = File.join(Reloaded::ROOT, "LoadOrder.rb")

    class << self
      def boot
        return true if ready?
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @failures = []
        @status = :running
        unless load_file(LOAD_ORDER_FILE) && defined?(Reloaded::LoadOrder)
          @status = :failed
          report("LoadOrder.rb did not load; Kanto Reloaded is off this session")
          return false
        end
        Reloaded::LoadOrder.files.each do |relative|
          next if load_file(File.join(Reloaded::ROOT, relative))
          @failures << relative
        end
        dev = File.join(Reloaded::ROOT, Reloaded::LoadOrder::DEV_FILE)
        @failures << Reloaded::LoadOrder::DEV_FILE if File.file?(dev) && !load_file(dev)
        Reloaded::LoadOrder::SYSTEMS.each { |name| boot_system(name) }
        @seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
        @status = @failures.empty? ? :ready : :degraded
        Reloaded::Log.info("Kanto Reloaded #{Reloaded.version} booted (#{@status})", :bootstrap) if defined?(Reloaded::Log)
        Reloaded::Runtime.report if defined?(Reloaded::Runtime)     # what the game is running on (a phone too)
        Reloaded::Events.emit(:core_booted) if defined?(Reloaded::Events)
        return true
      rescue Exception => e
        @status = :failed
        report("Boot failed: #{e.class}: #{e.message}", e)
        return false
      end

      def status
        return @status || :not_started
      end

      def ready?
        return status == :ready || status == :degraded
      end

      def failures
        return Array(@failures).dup
      end

      # How long Kanto Reloaded took to load and boot (Mod Timings' Startup).
      def seconds
        return @seconds
      end

      private

      def load_file(path)
        load(path)
        return true
      rescue Exception => e
        report("Could not load #{relative(path)}: #{e.class}: #{e.message}", e)
        return false
      end

      def boot_system(name)
        return unless Reloaded.const_defined?(name, false)
        system = Reloaded.const_get(name, false)
        return unless system.respond_to?(:boot)
        return if system.boot
        @failures << name.to_s
        report("#{name} did not boot")
      rescue Exception => e
        @failures << name.to_s
        report("#{name} failed to boot: #{e.class}: #{e.message}", e)
      end

      def report(message, error = nil)
        if defined?(Reloaded::Log)
          error ? Reloaded::Log.exception(message, error, :bootstrap) : Reloaded::Log.error(message, :bootstrap)
        else
          KIF.log("[Kanto Reloaded] #{message}") if defined?(KIF) && KIF.respond_to?(:log)
        end
      end

      def relative(path)
        return path.to_s.sub(Reloaded::ROOT + "/", "").sub(Reloaded::ROOT + "\\", "")
      end
    end
  end
end

Reloaded::Bootstrap.boot
