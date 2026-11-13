#==============================================================================
# Kanto Reloaded: the clipboard
#==============================================================================
# Text to and from the clipboard (a path, a link, a seed, a Randomizer
# settings code), and which values plain JSON data can hold.
#
#   Reloaded::ShareCodes.copy("text")      false when the engine can't
#   Reloaded::ShareCodes.clipboard         "" when the engine can't read it
#
# (Kanto Reloaded's own share codes, Base64 JSON, were cut 2026-11-05: KIF
# 2.0.0's Mod Safety grades Base64 red.)
#==============================================================================

module Reloaded
  module ShareCodes
    class << self
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

      # Values plain JSON data can hold.
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
