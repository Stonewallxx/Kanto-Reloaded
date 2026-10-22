#==============================================================================
# Kanto Reloaded: writing a zip
#==============================================================================
# A bug report is one .zip that Windows opens on its own. The game has Zlib
# (PIF's plugin manager uses it), so each file is deflated; without it the
# files are stored as they are.
#
#   Reloaded::Zip.write(path, [["Report.md", text], ["logs/KIF_log.txt", text]])
#==============================================================================

module Reloaded
  module Zip
    class << self
      # entries: [[name in the zip, its bytes]]. Returns path.
      def write(path, entries)
        out = "".b
        central = "".b
        time, date = dos_time(Time.now)
        entries.each do |name, data|
          data = data.to_s.b
          name = name.to_s.encode("UTF-8").b
          crc = crc32(data)
          packed, method = pack(data)
          offset = out.bytesize
          # local file header (UTF-8 names: flag bit 11)
          out << [0x04034b50, 20, 0x0800, method, time, date, crc, packed.bytesize, data.bytesize, name.bytesize, 0].pack("VvvvvvVVVvv")
          out << name << packed
          central << [0x02014b50, 20, 20, 0x0800, method, time, date, crc, packed.bytesize, data.bytesize,
                      name.bytesize, 0, 0, 0, 0, 0, offset].pack("VvvvvvvVVVvvvvvVV")
          central << name
        end
        start = out.bytesize
        out << central
        out << [0x06054b50, 0, 0, entries.length, entries.length, central.bytesize, start, 0].pack("VvvvvVVv")
        File.binwrite(path, out)
        return path
      end

      private

      def pack(data)
        if defined?(::Zlib::Deflate) && data.bytesize > 64
          z = ::Zlib::Deflate.new(::Zlib::DEFAULT_COMPRESSION, -::Zlib::MAX_WBITS)
          packed = z.deflate(data, ::Zlib::FINISH)
          z.close
          return [packed, 8] if packed.bytesize < data.bytesize
        end
        return [data, 0]
      end

      def crc32(data)
        return ::Zlib.crc32(data) if defined?(::Zlib) && ::Zlib.respond_to?(:crc32)
        @table ||= (0..255).map do |n|
          c = n
          8.times { c = (c & 1) == 1 ? 0xEDB88320 ^ (c >> 1) : c >> 1 }
          c
        end
        crc = 0xFFFFFFFF
        data.each_byte { |b| crc = @table[(crc ^ b) & 0xFF] ^ (crc >> 8) }
        return crc ^ 0xFFFFFFFF
      end

      # MS-DOS time and date, as zips keep them.
      def dos_time(t)
        time = (t.hour << 11) | (t.min << 5) | (t.sec / 2)
        date = ((t.year - 1980) << 9) | (t.month << 5) | t.day
        return [time, date]
      end
    end
  end
end
