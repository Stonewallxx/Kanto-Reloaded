#==============================================================================
# Kanto Reloaded: reading and writing save files, packed or not
#==============================================================================
# KIF 1.2 keeps its save backups gzip-packed under the same .rxdata names
# (about a tenth of the size) and reads either kind through
# SaveData.get_data_from_file. Kanto Reloaded's save tools follow (his ask,
# 2026-10-25: the Save Manager on the new save system):
#
#   SaveFile.packed?(path)   a gzip file
#   SaveFile.load(path)      what's in it, as PIF's reader gives it (a Hash,
#                            or the old Array of values), packed or not
#   SaveFile.bytes(path)     its plain bytes (unpacked when packed)
#   SaveFile.pack(raw)       raw packed as KIF packs its backups (raw as it is
#                            on a KIF without packing, or when packing doesn't
#                            make it smaller)
#
# A save the game plays from is always plain (a restore unpacks it); backups
# may be either.
#==============================================================================

# The game has Zlib built in; Ruby outside it (the tests) loads it
begin
  require "zlib" unless defined?(::Zlib)
rescue LoadError, StandardError
  nil
end

module Reloaded
  module SaveFile
    GZ = "\x1F\x8B".b.freeze

    class << self
      def packed?(path)
        return File.binread(path, 2) == GZ
      rescue StandardError
        return false
      end

      def load(path)
        return load_packed(path) if packed?(path)
        return ::SaveData.get_data_from_file(path) if defined?(::SaveData) && ::SaveData.respond_to?(:get_data_from_file)
        return File.open(path, "rb") { |f| Marshal.load(f) }
      end

      def bytes(path)
        raw = File.binread(path)
        return raw[0, 2] == GZ ? Zlib.gunzip(raw) : raw
      end

      def pack(raw)
        kb = defined?(::KIF::SaveBackups) ? ::KIF::SaveBackups : nil
        return kb.packed(raw) if kb && kb.respond_to?(:packed)
        return raw
      rescue StandardError
        return raw
      end

      private

      # As PIF's reader (001_SaveData.rb), from the gzip stream: one Hash, or
      # an old save's values one after another
      def load_packed(path)
        Zlib::GzipReader.open(path) do |f|
          data = Marshal.load(f)
          return data if data.is_a?(Hash)
          list = [data]
          list << Marshal.load(f) until f.eof?
          return list
        end
      end
    end
  end
end
