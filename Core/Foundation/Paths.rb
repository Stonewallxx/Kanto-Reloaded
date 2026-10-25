#==============================================================================
# Kanto Reloaded: Paths
#==============================================================================
# Where Kanto Reloaded keeps its files. Only what belongs to saves goes in
# the save folder; the rest stays in the mod folder:
#
#   Reloaded::ROOT   the mod folder (Mods\KantoReloaded): code and assets
#   settings_dir     <ROOT>\Settings: settings, controls, layouts, features,
#                    presets, What's New, crash detection, the Pause Menu's
#                    layout, the Timing Profiler's sessions and the Hook
#                    Check's state
#   logs_dir         <ROOT>\Logging: logs, and reports in folders of their
#                    own (Save Checks, Hook Checks, Style Checks)
#   bug_reports_dir  <ROOT>\Logging\Bug Reports
#   user_dir         the game's save folder (%APPDATA%\KIF in KIF Beta)
#   data_dir         <user_dir>\Kanto Reloaded: save things only (each
#                    save's .kr copy, notes and color tags, previews, Set
#                    Aside)
#
# KIF's mod catalog never touches files a mod writes into its own folder,
# and the Release Builder leaves Settings and Logging out. The first start
# after this layout moves the old files over (migrate), and the Bug Reports
# that were in the mod folder's own Bug Reports folder into Logging.
#==============================================================================

module Reloaded
  module Paths
    DATA_FOLDER = "Kanto Reloaded"

    class << self
      def user_dir
        @user_dir ||= begin
          folder = nil
          folder = File.dirname(::SaveData::FILE_PATH) if defined?(::SaveData::FILE_PATH)
          folder = (RTP.getSaveFolder rescue nil) if folder.to_s.empty? && defined?(RTP)
          folder = (System.data_directory rescue nil) if folder.to_s.empty?
          folder = "." if folder.to_s.empty?
          File.expand_path(folder.to_s)
        end
      end

      def data_dir
        return ensure_dir(File.join(user_dir, DATA_FOLDER))
      end

      # The mod folder, for what Kanto Reloaded keeps for itself (a test's
      # own folder when KR_LOCAL_DIR is set).
      def local_dir
        return defined?(::KR_LOCAL_DIR) ? ::KR_LOCAL_DIR : Reloaded::ROOT
      end

      def settings_dir
        return ensure_dir(File.join(local_dir, "Settings"))
      end

      def logs_dir
        return ensure_dir(File.join(local_dir, "Logging"))
      end

      def bug_reports_dir
        return ensure_dir(File.join(logs_dir, "Bug Reports"))
      end

      # What used to be in <user_dir>\Kanto Reloaded and isn't a save's,
      # moved to the mod folder on the first start after the change (copied,
      # then removed: the save folder and the game are often on different
      # drives). The number of files moved.
      MOVES = { "Settings.json" => :settings, "Controls.json" => :settings, "ControlLayouts.json" => :settings,
                "Features.json" => :settings, "Whats New.json" => :settings, "Session.json" => :settings,
                "Last Crash.json" => :settings, "Timing Sessions.json" => :settings, "Presets" => :settings,
                "Dev/Hook Check.json" => :settings, "Logs" => :logs, "Bug Reports" => :bug_reports }.freeze

      def migrate
        moved = move_bug_reports
        old = File.join(user_dir, DATA_FOLDER)
        return moved unless File.directory?(old)
        MOVES.each do |name, where|
          from = File.join(old, name)
          next unless File.exist?(from)
          case where
          when :settings then to = File.join(settings_dir, File.basename(name))
          when :logs then to = logs_dir
          else to = bug_reports_dir
          end
          moved += move(from, to)
        end
        dev = File.join(old, "Dev")
        Dir.rmdir(dev) if File.directory?(dev) && Dir.children(dev).empty?
        return moved
      rescue StandardError
        return moved || 0
      end

      # A path inside the mod folder.
      def mod_file(*parts)
        return File.join(Reloaded::ROOT, *parts)
      end

      # The game folder (the mod is in its Mods folder).
      def game_dir
        return File.expand_path(File.join(Reloaded::ROOT, "..", ".."))
      end

      # A game script's file, or nil. The game loads Data\Scripts with only
      # each file's name as its source path, so a bare name is looked up
      # there (nil when two files share it).
      def script_file(path)
        path = path.to_s
        return path if (path.include?("/") || path.include?("\\")) && File.file?(path)
        @scripts ||= Dir.glob(File.join(game_dir, "Data", "Scripts", "**", "*.rb")).group_by { |f| File.basename(f) }
        found = @scripts[File.basename(path)]
        return found && found.length == 1 ? found[0] : nil
      end

      def ensure_dir(path)
        return path if File.directory?(path)
        parent = File.dirname(path)
        ensure_dir(parent) unless parent == path || File.directory?(parent)
        Dir.mkdir(path) unless File.directory?(path)
        return path
      end

      # path when nothing is there, else the first free "<name> (2)<ext>",
      # "(3)"... beside it: a name no file has, so nothing is ever replaced.
      def free_name(path)
        return path unless File.exist?(path)
        ext = File.extname(path)
        base = path[0, path.length - ext.length]
        n = 2
        n += 1 while File.exist?("#{base} (#{n})#{ext}")
        return "#{base} (#{n})#{ext}"
      end

      # Moves a file aside (<name><suffix>, or a free name beside it) and
      # returns where it went, or nil. One kept earlier is never replaced.
      def set_aside(path, suffix = ".unreadable")
        return nil unless File.file?(path)
        to = free_name(path + suffix)
        File.rename(path, to)
        return to
      rescue StandardError
        return nil
      end

      # Sends a file to the Windows Recycle Bin, where it can be got back
      # (SHFileOperationW with Allow Undo, as Explorer's Delete). True when
      # it went; when the bin can't be used nothing is deleted.
      def recycle(path)
        return false unless File.file?(path) && defined?(::Win32API)
        @shfileop ||= ::Win32API.new("shell32", "SHFileOperationW", "P", "I")
        from = (File.expand_path(path).tr("/", "\\") + "\0\0").encode("UTF-16LE").b   # ends in two nulls
        ptr = [from].pack("p")
        flags = 0x0004 | 0x0010 | 0x0040 | 0x0400   # silent, no questions, Allow Undo, no error windows
        # SHFILEOPSTRUCTW: 64-bit (natural alignment) or 32-bit (packed)
        op = if ptr.bytesize == 8
               [0].pack("Q<") + [3, 0].pack("L<L<") + ptr + [0].pack("Q<") + [flags, 0, 0].pack("S<S<L<") + [0, 0].pack("Q<Q<")
             else
               [0, 3].pack("L<L<") + ptr + [0].pack("L<") + [flags].pack("S<") + [0, 0, 0].pack("L<L<L<")
             end
        result = @shfileop.call(op)
        from.bytesize                               # from stays alive until the call is done
        return result.zero? && !File.exist?(path)
      rescue StandardError, NotImplementedError
        return false
      end

      # Writes the file through a temporary copy, so a crash mid-write never
      # leaves a half-written file behind.
      def write_atomic(path, text)
        ensure_dir(File.dirname(path))
        temp = path + ".tmp"
        File.open(temp, "wb") do |file|
          file.write(text)
          file.flush
          file.fsync rescue nil
        end
        raise "Wrote an empty file: #{File.basename(path)}" if File.size(temp) <= 0
        File.delete(path) if File.file?(path)
        File.rename(temp, path)
        return true
      ensure
        File.delete(temp) if temp && File.file?(temp) rescue nil
      end

      # A file, or a folder's files, to a new place (any drive), keeping
      # their times. When the new place has the file already, the newer of
      # the two is kept. The number of files moved.
      def move(from, to)
        if File.directory?(from)
          ensure_dir(to)
          count = Dir.children(from).sum { |c| move(File.join(from, c), File.join(to, c)) }
          Dir.rmdir(from) if Dir.children(from).empty?
          return count
        end
        if File.file?(to) && File.mtime(to) >= File.mtime(from)
          File.delete(from)
          return 0
        end
        ensure_dir(File.dirname(to))
        File.binwrite(to, File.binread(from))
        File.utime(File.atime(from), File.mtime(from), to) rescue nil
        File.delete(from) if File.size(to) == File.size(from)
        return 1
      end

      # Bug Reports from the mod folder's own Bug Reports folder (where they
      # were before) into Logging's
      def move_bug_reports
        from = File.join(local_dir, "Bug Reports")
        return 0 unless File.directory?(from)
        return move(from, bug_reports_dir)
      rescue StandardError
        return 0
      end

      # Reads a file written by write_atomic, recovering the temporary copy if
      # the game closed between deleting the old file and renaming the new one.
      def read_text(path)
        temp = path + ".tmp"
        File.rename(temp, path) if !File.file?(path) && File.file?(temp)
        return nil unless File.file?(path)
        return File.open(path, "rb") { |file| file.read }.force_encoding(Encoding::UTF_8)
      end
    end
  end
end

# Before anything reads or writes them: the old files to their new places.
Reloaded::Paths.migrate
