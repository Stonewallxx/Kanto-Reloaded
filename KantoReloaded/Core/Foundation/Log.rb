#==============================================================================
# Kanto Reloaded: Log
#==============================================================================
# <mod folder>\Logging\Kanto Reloaded.log; the previous session's log is kept as
# Kanto Reloaded.old.log. Warnings and errors also go to KIF's session log
# (KIF_log.txt), and exceptions to KIF's crash log (KIF_errorlog.txt), so a
# bug report from KIF Beta shows them too. This session's errors are kept
# (errors) for Bug Reports to count and list, and each goes on its Recent
# Steps.
#==============================================================================

module Reloaded
  module Log
    FILE = "Kanto Reloaded.log"
    OLD_FILE = "Kanto Reloaded.old.log"

    class << self
      def debug(message, channel = :general)
        write(:debug, message, channel)
      end

      def info(message, channel = :general)
        write(:info, message, channel)
      end

      def warning(message, channel = :general)
        write(:warning, message, channel)
      end

      def error(message, channel = :general)
        write(:error, message, channel)
      end

      def exception(message, error, channel = :general)
        lines = ["#{message}: #{error.class}: #{error.message}"]
        lines.concat(Array(error.backtrace).first(8).map { |line| "  " + line.to_s })
        write(:error, lines.join("\n"), channel)
        if defined?(KIF::CrashLog)
          KIF::CrashLog.write("[Kanto Reloaded] #{message}\r\n" + KIF::CrashLog.describe(error)) rescue nil
        end
      end

      # This session's errors: [[time, channel, first line]].
      def errors
        return @errors ||= []
      end

      # Logs a message only the first time it is seen this session.
      def warning_once(message, channel = :general)
        @seen ||= {}
        return if @seen[message]
        @seen[message] = true
        warning(message, channel)
      end

      def path
        @path ||= begin
          file = File.join(Reloaded::Paths.logs_dir, FILE)
          if File.file?(file)
            old = File.join(Reloaded::Paths.logs_dir, OLD_FILE)
            File.delete(old) if File.file?(old)
            File.rename(file, old)
          end
          file
        end
      end

      private

      def write(level, message, channel)
        line = sprintf("[%s] [%s] [%s] %s", Time.now.strftime("%H:%M:%S"), level.to_s.upcase, channel, message)
        File.open(path, "ab") { |file| file.write(line + "\n") }
        if level == :error
          first = message.to_s.lines.first.to_s.chomp
          errors << [Time.now, channel, first]
          Reloaded::BugReport::Trail.add(:error, first) if defined?(Reloaded::BugReport::Trail)
        end
        if (level == :error || level == :warning) && defined?(KIF) && KIF.respond_to?(:log)
          KIF.log("[Kanto Reloaded] #{level.to_s.upcase}: #{message.to_s.lines.first.to_s.chomp}")
        end
      rescue
        nil
      end
    end
  end
end
