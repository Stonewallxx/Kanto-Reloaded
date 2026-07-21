#==============================================================================
# Kanto Reloaded Logging
#==============================================================================

module KantoReloaded
  module Log
    ROOT = File.expand_path(File.join(File.dirname(__FILE__), "..", ".."))
    GAME_ROOT = File.expand_path(File.join(ROOT, "..", ".."))
    LOG_DIR = File.join(ROOT, "Logging")
    MAIN_LOG = File.join(LOG_DIR, "Log.txt")
    PREVIOUS_LOG = File.join(LOG_DIR, "Log.previous.txt")
    BUG_REPORT = File.join(LOG_DIR, "LatestBugReport.txt")
    BUG_REPORT_LOG_LIMIT = 300
    MAX_LOG_BYTES = 2 * 1024 * 1024
    LEVELS = [:debug, :info, :warning, :error, :critical, :fatal].freeze
    @once = {}
    @bug_report_exporting = false

    class << self
      def debug(message, channel = :framework); write(channel, message, :level => :debug); end
      def info(message, channel = :framework); write(channel, message, :level => :info); end
      def warning(message, channel = :framework); write(channel, message, :level => :warning); end
      def error(message, channel = :framework); write(channel, message, :level => :error); end
      def critical(message, channel = :framework); write(channel, message, :level => :critical); end
      def fatal(message, channel = :framework); write(channel, message, :level => :fatal); end

      def debug_once(message, channel = :framework, key: nil); write_once(channel, message, :level => :debug, :key => key); end
      def info_once(message, channel = :framework, key: nil); write_once(channel, message, :level => :info, :key => key); end
      def warning_once(message, channel = :framework, key: nil); write_once(channel, message, :level => :warning, :key => key); end
      def error_once(message, channel = :framework, key: nil); write_once(channel, message, :level => :error, :key => key); end

      def write(channel, message, level: :info)
        normalized_level = normalize_level(level)
        line = "[#{timestamp}] [#{normalized_level.to_s.upcase}] [#{sanitize(channel)}] #{sanitize(message)}"
        ensure_log_dir
        rotate_main_log_if_needed(line.bytesize + 2)
        File.open(MAIN_LOG, "a") { |file| file.puts(line) }
        if [:warning, :error, :critical, :fatal].include?(normalized_level)
          echoln(line) rescue nil
        end
        line
      rescue
        nil
      end

      def write_once(channel, message, level: :info, key: nil)
        signature = sanitize(key || "#{channel}:#{level}:#{message}")
        return nil if @once[signature]
        @once[signature] = true
        write(channel, message, :level => level)
      end

      def exception(message, exception, channel: :framework, level: :error)
        write(channel, "#{message}: #{exception.class}: #{exception.message}", :level => level)
        Array(exception.backtrace).first(8).each do |line|
          write(channel, "  #{line}", :level => level)
        end
      end

      def summary(values = {})
        text = values.map { |key, value| "#{key}=#{value}" }.join(" ")
        info(text, :summary)
        values
      end

      def export_bug_report(extra_fields = {}, log_export = true)
        ensure_log_dir
        @bug_report_exporting = true
        lines = []
        lines << "[BUG REPORT]"
        lines << "Game Title: #{bug_report_game_title}"
        lines << "KIF Version: #{bug_report_base_version}"
        lines << "Kanto Reloaded Version: #{bug_report_framework_version}"
        lines << "Timestamp: #{Time.now}"
        lines << "Platform: #{bug_report_platform}"
        lines << "Ruby Platform: #{RUBY_PLATFORM rescue 'unknown'}"
        lines << "Ruby Version: #{RUBY_VERSION rescue 'unknown'}"
        lines << "Debug Mode: #{defined?($DEBUG) && $DEBUG ? 'On' : 'Off'}"
      fields = extra_fields.is_a?(Hash) ? extra_fields : {}
      fields.each do |key, value|
          lines << "#{bug_report_label(key)}: #{sanitize(value)}"
        end
        lines << ""
        lines << "[ENABLED MODS]"
        lines.concat(bug_report_enabled_mods)
        lines << ""
        lines << "[KR STATE]"
        lines.concat(bug_report_framework_state)
        lines << ""
        lines << "[LOG COUNTS]"
        log_snapshot = bug_report_log_snapshot
        log_snapshot[:counts].each do |level, count|
          lines << "#{level.to_s.upcase}: #{count}"
        end
        lines << ""
        lines << "[RECENT LOG]"
        lines.concat(log_snapshot[:recent])
        lines << "[/BUG REPORT]"
        write_bug_report_file(sanitize(lines.join("\n")))
        info("Bug report exported: #{BUG_REPORT}", :framework) if log_export
        BUG_REPORT
      rescue StandardError => e
        write_bug_report_fallback(e)
        nil
      ensure
        @bug_report_exporting = false
      end

      def sanitize(value)
        text = value.to_s.gsub("\\", "/")
        replacements = []
        replacements << [File.expand_path(ROOT).gsub("\\", "/"), "/KantoReloaded"]
        replacements << [File.expand_path(GAME_ROOT).gsub("\\", "/"), "/Game"]
        [ENV["TEMP"], ENV["TMP"], ENV["TMPDIR"]].compact.each do |path|
          replacements << [File.expand_path(path).gsub("\\", "/"), "/Temp"]
        end
        [ENV["USERPROFILE"], ENV["HOME"]].compact.each do |path|
          replacements << [File.expand_path(path).gsub("\\", "/"), "/User"]
        end
        replacements.sort_by { |entry| -entry[0].length }.each do |root, replacement|
          next if root.empty?
          text = text.gsub(/#{Regexp.escape(root)}(?=\/|\z)/i, replacement)
        end
        text = text.gsub(
          /(authorization\s*[:=]\s*)(?:bearer\s+)?[^\s,;]+/i,
          '\1[REDACTED]'
        )
        text = text.gsub(
          /((?:access[_ -]?token|refresh[_ -]?token|api[_ -]?key|password|secret)\s*[:=]\s*)([^\s,;]+)/i,
          '\1[REDACTED]'
        )
        text = text.gsub(
          /([?&](?:token|key|auth|code|password|secret)=)[^&\s]+/i,
          '\1[REDACTED]'
        )
        text = text.gsub(
          %r{https://(?:canary\.|ptb\.)?discord(?:app)?\.com/api/webhooks/\d+/[^\s]+}i,
          "https://discord.com/api/webhooks/[REDACTED]"
        )
        text.gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, "")
      rescue
        value.to_s
      end

      private

      def ensure_log_dir
        Dir.mkdir(LOG_DIR) unless Dir.exist?(LOG_DIR)
      rescue
        nil
      end

      def rotate_main_log_if_needed(incoming_bytes)
        return unless File.file?(MAIN_LOG)
        return if File.size(MAIN_LOG).to_i + incoming_bytes.to_i <= MAX_LOG_BYTES
        File.delete(PREVIOUS_LOG) if File.file?(PREVIOUS_LOG)
        File.rename(MAIN_LOG, PREVIOUS_LOG)
      rescue
        nil
      end

      def normalize_level(level)
        value = level.to_s.downcase.to_sym
        LEVELS.include?(value) ? value : :info
      end

      def timestamp
        Time.now.strftime("%Y-%m-%d %H:%M:%S")
      rescue
        "unknown"
      end

      def bug_report_game_title
        return System.game_title.to_s if defined?(System) && System.respond_to?(:game_title)
        "Kuray's Infinite Fusion"
      rescue
        "Kuray's Infinite Fusion"
      end

      def bug_report_base_version
        return ::Settings::GAME_VERSION_NUMBER.to_s if defined?(::Settings::GAME_VERSION_NUMBER)
        return ::Settings::GAME_VERSION.to_s if defined?(::Settings::GAME_VERSION)
        return ::Settings::IF_VERSION.to_s if defined?(::Settings::IF_VERSION)
        "unknown"
      rescue
        "unknown"
      end

      def bug_report_framework_version
        KantoReloaded.version.to_s
      rescue
        "unknown"
      end

      def bug_report_platform
        return KantoReloaded::Platform.label.to_s if defined?(KantoReloaded::Platform)
        (RUBY_PLATFORM rescue "unknown").to_s
      rescue
        "Other"
      end

      def bug_report_enabled_mods
        return ["Mod Manager state unavailable."] unless defined?(::ModManager)
        return ["Mod Manager state unavailable."] unless ::ModManager.respond_to?(:enabled_mods)
        ids = Array(::ModManager.enabled_mods)
        return ["No enabled mods reported."] if ids.empty?
        ids.sort_by { |id| id.to_s.downcase }.map do |id|
          info = ::ModManager.get_mod(id) if ::ModManager.respond_to?(:get_mod)
          name = info && info.respond_to?(:name) ? info.name.to_s : id.to_s
          version = info && info.respond_to?(:version) ? info.version.to_s : "unknown"
          "- #{sanitize(id)} | #{sanitize(name)} | #{sanitize(version)}"
        end
      rescue StandardError => e
        ["Could not read enabled mod state: #{sanitize(e.class)}"]
      end

      def bug_report_framework_state
        lines = []
        schema = if defined?(KantoReloaded::SaveData::SCHEMA_VERSION)
                   KantoReloaded::SaveData::SCHEMA_VERSION
                 else
                   "unavailable"
                 end
        settings_count = if defined?(KantoReloaded::Settings) &&
                            KantoReloaded::Settings.respond_to?(:definitions)
                           KantoReloaded::Settings.definitions.length
                         else
                           0
                         end
        overworld_count = if defined?(::OverworldMenu) && ::OverworldMenu.respond_to?(:registry)
                            Array(::OverworldMenu.registry).length
                          else
                            0
                          end
        battle_count = if defined?(::BattleCommandMenu) && ::BattleCommandMenu.respond_to?(:registry)
                         Array(::BattleCommandMenu.registry).length
                       else
                         0
                       end
        lines << "Save Schema: #{schema}"
        lines << "Registered Settings: #{settings_count}"
        lines << "Overworld Menu Commands: #{overworld_count}"
        lines << "Battle Menu Commands: #{battle_count}"
        lines << "Current Scene: #{sanitize($scene.class.to_s)}" if defined?($scene) && $scene
        if defined?($game_map) && $game_map && $game_map.respond_to?(:map_id)
          lines << "Map ID: #{$game_map.map_id}"
        end
        if defined?(Graphics) && Graphics.respond_to?(:width) && Graphics.respond_to?(:height)
          lines << "Resolution: #{Graphics.width}x#{Graphics.height}"
        end
        lines
      rescue StandardError => e
        ["Could not read KR state: #{sanitize(e.class)}"]
      end

      def bug_report_log_snapshot
        counts = {}
        LEVELS.each { |level| counts[level] = 0 }
        recent_ring = Array.new(BUG_REPORT_LOG_LIMIT)
        line_count = 0
        [PREVIOUS_LOG, MAIN_LOG].each do |path|
          next unless File.file?(path)
          File.foreach(path) do |line|
            level_name = line[/\[(DEBUG|INFO|WARNING|ERROR|CRITICAL|FATAL)\]/, 1]
            counts[level_name.downcase.to_sym] += 1 if level_name
            recent_ring[line_count % BUG_REPORT_LOG_LIMIT] = sanitize(line.to_s.rstrip)
            line_count += 1
          end
        end
        recent = if line_count <= BUG_REPORT_LOG_LIMIT
                   recent_ring.first(line_count)
                 else
                   start = line_count % BUG_REPORT_LOG_LIMIT
                   recent_ring[start..-1] + recent_ring[0...start]
                 end
        recent = ["Log.txt is empty."] if recent.empty?
        { :counts => counts, :recent => recent }
      rescue StandardError => e
        {
          :counts => counts || {},
          :recent => ["Could not read Log.txt: #{sanitize(e.class)}"]
        }
      end

      def bug_report_label(value)
        value.to_s.split("_").map do |part|
          part[0, 1].to_s.upcase + part[1..-1].to_s
        end.join(" ")
      rescue
        value.to_s
      end

      def write_bug_report_file(content)
        text = content.to_s
        if text.strip.empty?
          text = "[BUG REPORT]\nCould not generate bug report content.\n[/BUG REPORT]"
        end
        temp_path = "#{BUG_REPORT}.tmp"
        File.open(temp_path, "w") { |file| file.puts(text) }
        raise "Bug report temp file was empty." unless File.file?(temp_path) && File.size(temp_path).to_i > 0
        File.delete(BUG_REPORT) if File.file?(BUG_REPORT)
        File.rename(temp_path, BUG_REPORT)
        BUG_REPORT
      ensure
        File.delete(temp_path) if defined?(temp_path) && File.file?(temp_path)
      end

      def write_bug_report_fallback(error)
        ensure_log_dir
        lines = []
        lines << "[BUG REPORT]"
        lines << "Game Title: #{bug_report_game_title}"
        lines << "KIF Version: #{bug_report_base_version}"
        lines << "Kanto Reloaded Version: #{bug_report_framework_version}"
        lines << "Timestamp: #{Time.now}"
        lines << ""
        lines << "Bug report generation failed: #{sanitize(error.class)}: #{sanitize(error.message)}"
        lines << "Check Log.txt for additional information."
        lines << "[/BUG REPORT]"
        File.open(BUG_REPORT, "w") { |file| file.puts(lines.join("\n")) }
        BUG_REPORT
      rescue
        nil
      end
    end
  end
end
