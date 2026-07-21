#==============================================================================
# Kanto Reloaded Platform
#==============================================================================
# Runtime detection and portable filesystem/JSON helpers for Windows,
# Proton/Wine, JoiPlay, and unknown hosts.
#==============================================================================

module KantoReloaded
  module Platform
    ROOT = File.expand_path(File.join(File.dirname(__FILE__), "..", ".."))
    GAME_ROOT = File.expand_path(File.join(ROOT, "..", ".."))

    PLATFORM_IDS = [:windows, :proton, :joiplay, :unknown].freeze
    PLATFORM_LABELS = {
      :windows => "Windows",
      :proton  => "Proton",
      :joiplay => "JoiPlay",
      :unknown => "Other"
    }.freeze
    CAPABILITIES = {
      :windows => [
        :gameplay, :mod_manager, :manual_mods, :settings, :save_data,
        :data_patches, :filesystem, :json, :mouse, :clipboard, :open_url,
        :open_folder
      ],
      :proton => [
        :gameplay, :mod_manager, :manual_mods, :settings, :save_data,
        :data_patches, :filesystem, :json, :mouse, :clipboard, :open_url,
        :open_folder
      ],
      :joiplay => [
        :gameplay, :mod_manager, :manual_mods, :settings, :save_data,
        :data_patches, :filesystem, :json, :touch
      ],
      :unknown => [
        :gameplay, :manual_mods, :settings, :save_data, :data_patches,
        :filesystem, :json
      ]
    }.freeze

    @detected_id = nil
    @override_id = nil
    @booted = false

    class << self
      def boot
        return true if @booted
        detected_id
        log_platform
        @booted = true
        true
      rescue StandardError => e
        @booted = false
        KantoReloaded::Log.exception("Platform boot failed", e, channel: :framework) if defined?(KantoReloaded::Log)
        false
      end

      def id
        @override_id || detected_id
      end

      def detected_id
        @detected_id ||= detect
      end

      def label(platform_id = id)
        PLATFORM_LABELS[normalize_id(platform_id)] || PLATFORM_LABELS[:unknown]
      end

      def windows?
        id == :windows
      end

      def proton?
        id == :proton
      end

      def joiplay?
        id == :joiplay
      end

      def unknown?
        id == :unknown
      end

      def supports?(capability)
        key = capability.to_s.strip.downcase.to_sym
        return clipboard_available? if key == :clipboard
        return mouse_available? if key == :mouse
        return json_available? if key == :json
        Array(CAPABILITIES[id]).include?(key)
      rescue
        false
      end

      def capabilities
        Array(CAPABILITIES[id]).select { |capability| supports?(capability) }
      end

      def clipboard_write(text)
        return false unless supports?(:clipboard)
        Input.clipboard = text.to_s
        true
      rescue StandardError => e
        log_adapter_failure(:clipboard, e)
        false
      end

      def open_url(url)
        return false unless supports?(:open_url)
        value = url.to_s.strip
        return false unless value =~ /\Ahttps?:\/\/[^\s]+\z/i
        opened = if proton? && !windows_environment?
                   system("xdg-open", value)
                 else
                   system("cmd", "/c", "start", "", value)
                 end
        raise "The operating system could not open the URL." unless opened
        true
      rescue StandardError => e
        log_adapter_failure(:open_url, e)
        false
      end

      def open_folder(path)
        return false unless supports?(:open_folder)
        folder = File.expand_path(path.to_s)
        return false unless directory?(folder)
        opened = if proton? && !windows_environment?
                   system("xdg-open", folder)
                 else
                   system("explorer.exe", folder.tr("/", "\\"))
                 end
        raise "The operating system could not open the folder." unless opened
        true
      rescue StandardError => e
        log_adapter_failure(:open_folder, e)
        false
      end

      # Runtime-only override for debug tools and platform contract tests.
      def set_override(value)
        normalized = normalize_id(value)
        raise "Unknown platform override: #{value}" if normalized == :unknown && value.to_s.strip.downcase != "unknown"
        @override_id = normalized
      end

      def clear_override
        @override_id = nil
        id
      end

      def reset_detection!
        @detected_id = nil
        @booted = false
        detected_id
      end

      def normalize_path(path)
        value = path.to_s.tr("\\", "/")
        unc_path = value.start_with?("//")
        value = value.gsub(%r{/+}, "/")
        value = "/" + value if unc_path
        value = value.sub(%r{\A([A-Za-z]):/}) { "#{$1.upcase}:/" }
        value
      rescue
        path.to_s
      end

      def absolute_path(path, base = GAME_ROOT)
        normalize_path(File.expand_path(path.to_s, base.to_s))
      end

      def join_path(*parts)
        normalize_path(File.join(*parts.compact.map(&:to_s)))
      end

      def path_within?(path, root = GAME_ROOT)
        target = comparable_path(absolute_path(path, root))
        boundary = comparable_path(absolute_path(root, root))
        target == boundary || target.start_with?(boundary + "/")
      rescue
        false
      end

      def file?(path)
        File.file?(path.to_s)
      rescue
        false
      end

      def directory?(path)
        File.directory?(path.to_s)
      rescue
        false
      end

      def exist?(path)
        return safeExists?(path.to_s) if defined?(safeExists?)
        File.exist?(path.to_s)
      rescue
        false
      end

      def glob(pattern)
        normalized = normalize_path(pattern)
        wildcard_index = normalized.index(/[*?\[]/)
        return exist?(normalized) ? [absolute_path(normalized)] : [] unless wildcard_index

        separator_index = normalized.rindex("/", wildcard_index)
        if separator_index
          base = normalized[0...separator_index]
          base = "/" if base.empty?
          base += "/" if base =~ /\A[A-Za-z]:\z/
          relative_pattern = normalized[(separator_index + 1)..-1]
        else
          base = "."
          relative_pattern = normalized
        end

        matches = Dir.chdir(base) { Dir[relative_pattern] }
        matches.map { |entry| absolute_path(entry, base) }.sort
      rescue
        []
      end

      def read_text(path)
        File.open(path.to_s, "rb") { |file| file.read }
      end

      def json_available?
        json_adapter != nil
      rescue
        false
      end

      def parse_json(value)
        adapter = json_adapter
        raise "JSON is not available in this runtime." unless adapter
        adapter[:parse].call(value.to_s)
      end

      def generate_json(value)
        adapter = json_adapter
        raise "JSON is not available in this runtime." unless adapter
        adapter[:generate].call(value)
      end

      def temporary_directory
        candidates = [environment("TEMP"), environment("TMP"), environment("TMPDIR"), GAME_ROOT]
        root = candidates.find { |path| !path.empty? && directory?(path) } || GAME_ROOT
        path = File.expand_path(File.join(root, "KantoReloaded"))
        Dir.mkdir(path) unless directory?(path)
        normalize_path(path)
      end

      def user_data_directory
        app_data = environment("APPDATA")
        return absolute_path(File.join(app_data, "Kanto Reloaded"), app_data) if windows? && !app_data.empty?
        home = environment("HOME")
        return absolute_path(File.join(home, ".local", "share", "Kanto Reloaded"), home) unless home.empty?
        normalize_path(GAME_ROOT)
      end

      def display_path(path)
        root = normalize_path(GAME_ROOT)
        value = normalize_path(path)
        comparable_value = comparable_path(value)
        comparable_root = comparable_path(root)
        return "." if comparable_value == comparable_root
        return value[(root.length + 1)..-1] if comparable_value.start_with?(comparable_root + "/")
        File.basename(value)
      rescue
        File.basename(path.to_s)
      end

      private

      def detect
        return :joiplay if joiplay_environment?
        return :proton if proton_environment?
        return :windows if windows_environment?
        :unknown
      end

      def normalize_id(value)
        key = value.to_s.strip.downcase
        return :proton if ["steamdeck", "steam_deck", "steam deck", "steamos", "wine"].include?(key)
        return :joiplay if ["android", "joiplay"].include?(key)
        symbol = key.to_sym
        PLATFORM_IDS.include?(symbol) ? symbol : :unknown
      end

      def windows_environment?
        probe = [(RUBY_PLATFORM rescue ""), environment("OS")].join(" ").downcase
        !!(probe =~ /windows|mingw|mswin|cygwin/)
      end

      def proton_environment?
        keys = [
          "STEAM_COMPAT_DATA_PATH", "STEAM_COMPAT_CLIENT_INSTALL_PATH",
          "PROTON_VERSION", "WINEPREFIX", "WINELOADERNOEXEC"
        ]
        keys.any? { |key| !environment(key).empty? }
      end

      def joiplay_environment?
        platform = (RUBY_PLATFORM rescue "").to_s.downcase
        keys = ["JOIPLAY", "ANDROID_ROOT", "ANDROID_DATA", "ANDROID_STORAGE"]
        platform.include?("android") || defined?(JoiPlay) || keys.any? { |key| !environment(key).empty? }
      end

      def environment(key)
        (ENV[key] rescue nil).to_s.strip
      end

      def comparable_path(path)
        value = normalize_path(path)
        windows? || proton? ? value.downcase : value
      end

      def clipboard_available?
        return false unless Array(CAPABILITIES[id]).include?(:clipboard)
        defined?(Input) && Input.respond_to?(:clipboard) && Input.respond_to?(:clipboard=)
      rescue
        false
      end

      def mouse_available?
        return false unless Array(CAPABILITIES[id]).include?(:mouse)
        defined?(Mouse) || (defined?(Input) && (Input.respond_to?(:mouse_x) || Input.respond_to?(:mouse_in?)))
      rescue
        false
      end

      def json_adapter
        if defined?(::JSON) && ::JSON.respond_to?(:parse)
          generator = if ::JSON.respond_to?(:generate)
                        proc { |value| ::JSON.generate(value) }
                      elsif ::JSON.respond_to?(:dump)
                        proc { |value| ::JSON.dump(value) }
                      end
          return { :parse => proc { |value| ::JSON.parse(value) }, :generate => generator } if generator
        end
        if defined?(::ModManager::JSON) && ::ModManager::JSON.respond_to?(:parse) && ::ModManager::JSON.respond_to?(:dump)
          return {
            :parse => proc { |value| ::ModManager::JSON.parse(value) },
            :generate => proc { |value| ::ModManager::JSON.dump(value) }
          }
        end
        if defined?(::HTTPLite::JSON) && ::HTTPLite::JSON.respond_to?(:parse) && ::HTTPLite::JSON.respond_to?(:stringify)
          return {
            :parse => proc { |value| ::HTTPLite::JSON.parse(value) },
            :generate => proc { |value| ::HTTPLite::JSON.stringify(value) }
          }
        end
        nil
      end

      def log_platform
        return unless defined?(KantoReloaded::Log)
        names = capabilities.map(&:to_s).join(", ")
        KantoReloaded::Log.info("Platform: #{label} | Capabilities: #{names}", :framework)
      end

      def log_adapter_failure(adapter, error)
        return unless defined?(KantoReloaded::Log)
        KantoReloaded::Log.warning(
          "Platform adapter #{adapter} failed: #{error.class}: #{error.message}",
          :framework
        )
      rescue
        nil
      end
    end
  end
end

KantoReloaded::Platform.boot if defined?(KantoReloaded::Platform)
