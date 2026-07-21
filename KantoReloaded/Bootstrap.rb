#==============================================================================
# Kanto Reloaded Bootstrap
#==============================================================================

module KantoReloaded
  ROOT = File.expand_path(File.dirname(__FILE__)) unless const_defined?(:ROOT, false)

  class << self
    def version
      if defined?(::ModManager) && ::ModManager.respond_to?(:get_mod)
        info = ::ModManager.get_mod("kanto_reloaded")
        return info.version.to_s if info && info.respond_to?(:version)
      end
      "0.15.0"
    rescue
      "0.15.0"
    end
  end

  module Bootstrap
    class << self
      def boot
        return true if @booted
        load File.join(KantoReloaded::ROOT, "LoadOrder.rb")
        KantoReloaded::LoadOrder.files.each { |relative| load_file(relative) }
        @booted = true
        KantoReloaded::Log.info("Kanto Reloaded #{KantoReloaded.version} loaded", :bootstrap) if defined?(KantoReloaded::Log)
        true
      rescue StandardError => e
        if defined?(KantoReloaded::Log)
          KantoReloaded::Log.exception("Kanto Reloaded bootstrap failed", e, channel: :bootstrap)
        else
          echoln("[KantoReloaded] Bootstrap failed: #{e.class}: #{e.message}") rescue nil
        end
        raise
      end

      private

      def load_file(relative)
        path = File.expand_path(File.join(KantoReloaded::ROOT, relative))
        raise "Load path escapes Kanto Reloaded: #{relative}" unless path.start_with?(KantoReloaded::ROOT)
        raise "Missing Kanto Reloaded file: #{relative}" unless File.file?(path)
        load path
      end
    end
  end
end

KantoReloaded::Bootstrap.boot
