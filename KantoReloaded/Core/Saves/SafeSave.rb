#==============================================================================
# Kanto Reloaded: safe saving
#==============================================================================
# PIF writes a save straight over the old one (File.open(path, "wb")), so a
# crash, a full disk or an error halfway through leaves a cut-off file and no
# save. Hoenn Reloaded's safe saving, improved:
#
#   1. the save is written to <save>.reloaded.tmp and flushed to the disk
#   2. that file is read back: it must be a whole save (a Hash with a player)
#   3. the old save becomes <save>.reloaded.previous, the new one takes its
#      name, and the old one is deleted; any failure puts the old one back
#
# If the game stopped between those steps, the next start puts things right
# before anything reads the saves (recover): a save that's missing comes
# back from .previous, or from a .tmp that reads as a whole save; leftovers
# are cleared away.
#
# Installed by Lifecycle before its own hooks, so it's the innermost writer
# and :saved (and Kanto Reloaded's .kr copy) still follow every save.
#==============================================================================

module Reloaded
  module SafeSave
    TMP = ".reloaded.tmp".freeze
    PREVIOUS = ".reloaded.previous".freeze

    class << self
      def install
        return false unless defined?(::SaveData) && ::SaveData.respond_to?(:save_to_file)
        # its IOError is the game's "the save failed" (PIF rescues it), not a broken hook
        Reloaded::Hooks.around(nil, ::SaveData.singleton_class, :save_to_file, :id => :safe_save,
                               :passes => [IOError, SystemCallError]) do |_original, path, *_rest|
          Reloaded::SafeSave.write(path)
        end
        recover
        return true
      end

      # Writes the game's save to path, safely. Returns true; raises IOError
      # when it couldn't (the game then says the save failed, and the old
      # save is still there).
      def write(path)
        return write_data(path, ::SaveData.compile_save_hash)
      end

      # Writes save data (a whole save's Hash) to path the same safe way: the
      # Save Checker's fixes use it on a save that isn't being played.
      def write_data(path, data)
        tmp = path + TMP
        File.open(tmp, "wb") do |f|
          Marshal.dump(data, f)
          f.flush
          f.fsync rescue nil
        end
        unless whole?(tmp)
          File.delete(tmp) rescue nil
          raise IOError, "the save didn't read back whole, so the old one was kept"
        end
        replace(tmp, path)
        return true
      end

      # A file that reads as a whole save: a Hash with a player (packed or
      # not, Saves/SaveFile.rb).
      def whole?(file)
        return false unless File.file?(file) && File.size(file) > 0
        data = Reloaded::SaveFile.load(file)
        return data.is_a?(Hash) && data.key?(:player)
      rescue StandardError, NameError
        return false
      end

      # tmp takes path's place; the old file is put back if anything fails.
      def replace(tmp, path)
        previous = path + PREVIOUS
        File.delete(previous) if File.file?(previous)
        had = File.file?(path)
        File.rename(path, previous) if had
        begin
          File.rename(tmp, path)
        rescue StandardError
          File.rename(previous, path) if had && File.file?(previous) && !File.file?(path)
          raise
        end
        File.delete(previous) if had && File.file?(previous)
      end

      # A leftover file into the save's backups (KIF Beta's
      # backups\<slot>\<slot>_<stamp>_<name>.rxdata), at a free name.
      def keep_as_backup(file, path, name)
        slot = File.basename(path, ".rxdata")
        folder = File.join(File.dirname(path), "backups", slot)
        Reloaded::Paths.ensure_dir(folder)
        t = File.mtime(file)
        to = nil
        loop do
          to = File.join(folder, "#{slot}_#{t.strftime("%Y%m%d%H%M%S")}_#{name}.rxdata")
          break unless File.exist?(to)
          t += 1
        end
        File.rename(file, to)
        Reloaded::Log.warning("#{File.basename(path)}: a file left by a save that didn't finish was kept as the backup #{File.basename(to)}", :saves)
      rescue StandardError => e
        Reloaded::Log.exception("#{File.basename(file)} couldn't be kept as a backup (it's still beside the save)", e, :saves)
      end

      # After a crash: every save in the save folder put right.
      def recover(dir = save_dir)
        return 0 unless dir && File.directory?(dir)
        fixed = 0
        Dir.glob(File.join(dir, "*.rxdata{#{TMP},#{PREVIOUS}}")).map { |f| f.sub(/(#{Regexp.escape(TMP)}|#{Regexp.escape(PREVIOUS)})\z/, "") }.uniq.each do |path|
          tmp = path + TMP
          previous = path + PREVIOUS
          if !File.file?(path) && File.file?(previous)
            File.rename(previous, path)
            fixed += 1
            Reloaded::Log.warning("#{File.basename(path)} was put back from before a save that didn't finish", :saves)
          elsif !File.file?(path) && File.file?(tmp) && whole?(tmp)
            File.rename(tmp, path)
            fixed += 1
            Reloaded::Log.warning("#{File.basename(path)} was finished from a save that stopped halfway", :saves)
          end
          # Whatever's left is kept as a named backup (the Backup Cap never
          # takes those): a whole save that didn't take the save's place, or
          # the save from before. Only a half-written temporary file goes.
          if File.file?(tmp)
            whole?(tmp) ? keep_as_backup(tmp, path, "Unfinished Save") : (File.delete(tmp) rescue nil)
          end
          keep_as_backup(previous, path, "Before Crash") if File.file?(previous)
        end
        return fixed
      rescue StandardError => e
        Reloaded::Log.exception("Saves left by a crash couldn't be put right", e, :saves)
        return 0
      end

      def save_dir
        return ::SaveData::SAVE_DIR.to_s if defined?(::SaveData::SAVE_DIR)
        return Reloaded::Paths.user_dir
      end
    end
  end
end
