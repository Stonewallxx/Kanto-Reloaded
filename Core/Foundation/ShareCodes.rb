#==============================================================================
# Kanto Reloaded: share codes and the clipboard
#==============================================================================
# A share code is data as text a player can copy and paste into another game:
# a prefix that says what it holds and its version ("KIF1:" a settings
# preset, "KRC1:" a controls layout), then the data as Base64 JSON. Reading
# one only parses JSON (Reloaded::JSON, never eval); whoever reads it checks
# every value before using it.
#
#   code = Reloaded::ShareCodes.encode("KRC1:", { "name" => "Mine" })
#   Reloaded::ShareCodes.copy(code)
#   data = Reloaded::ShareCodes.decode("KRC1:", Reloaded::ShareCodes.clipboard)
#==============================================================================

module Reloaded
  module ShareCodes
    class << self
      def encode(prefix, data)
        return prefix + [Reloaded::JSON.generate(data)].pack("m0")
      end

      # The Hash in a share code with this prefix, or nil.
      def decode(prefix, text)
        text = text.to_s.strip
        return nil unless text.start_with?(prefix)
        json = text[prefix.length..-1].unpack1("m0").force_encoding(Encoding::UTF_8)
        data = Reloaded::JSON.parse(json)
        return data.is_a?(Hash) ? data : nil
      rescue ArgumentError, Reloaded::JSON::ParseError
        return nil
      end

      # The clipboard's text ("" when the engine can't read it).
      def clipboard
        return Input.respond_to?(:clipboard) ? Input.clipboard.to_s : ""
      rescue StandardError
        return ""
      end

      # Puts text on the clipboard; false when the engine can't.
      def copy(text)
        return false unless Input.respond_to?(:clipboard=)
        Input.clipboard = text
        return true
      rescue StandardError
        return false
      end

      # Values a share code can hold.
      def json_safe?(v)
        case v
        when Integer, String, true, false, nil then return true
        when Float then return v.finite?
        when Array then return v.all? { |x| json_safe?(x) }
        end
        return false
      end
    end
  end
end
