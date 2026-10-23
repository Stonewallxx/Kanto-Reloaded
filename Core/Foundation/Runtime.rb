#==============================================================================
# Kanto Reloaded: what the game is running on, in the log
#==============================================================================
# One line at start-up, so a log from any player says what their game can
# do: Windows, Linux or Steam Deck through Wine, or a phone (JoiPlay, Kirin),
# which reimplement the engine and may lack parts of it (his goal,
# 2026-10-21: Kanto Reloaded working on mobile). It names the Ruby version
# and platform, the system the engine reports, and whether these are there:
# Windows calls (the Recycle Bin), Wine, the engine's
# raw keyboard (Reloaded Controls), its controller functions, the mouse or
# touch position (clicks in Kanto Reloaded's screens), the clipboard (share
# codes, copying a link on a phone), and PIF's own Device
# option (PC / Mobile). Nothing here changes anything.
#
# A phone is known by the signs the old Kanto Reloaded used (Ruby's platform
# saying android, Android's own environment variables, JoiPlay's marker),
# and named JoiPlay when JoiPlay's marker is there. Whether Kanto Reloaded's
# folder can be written is checked too: the old mod's notes say JoiPlay's
# game folder is read-only (unconfirmed), and its Settings and Logging live
# there.
#==============================================================================

module Reloaded
  module Runtime
    class << self
      # { what => value } for the line (and the tests)
      def facts
        {
          :ruby => "#{RUBY_VERSION} (#{RUBY_PLATFORM})",
          :system => system_name,
          :windows_calls => windows_calls?,
          :wine => wine,
          :raw_keys => (defined?(::Input) && ::Input.respond_to?(:raw_key_states)) ? true : false,
          :controller => (defined?(::Input::Controller) && ::Input::Controller.respond_to?(:raw_button_states)) ? true : false,
          :mouse => (defined?(::Input) && ::Input.respond_to?(:mouse_x)) ? true : false,
          :clipboard => (defined?(::Input) && ::Input.respond_to?(:clipboard=)) ? true : false,
          :device => device,
          :phone => phone,
          :writable => writable?
        }
      rescue StandardError
        return {}
      end

      # True on a phone (JoiPlay, Kirin, another Android player)
      def phone?
        return phone ? true : false
      end

      # "JoiPlay", "a phone (Android)", or nil when not on one (worked out
      # once: false then means "not a phone", so it's never handed back as is)
      def phone
        return @phone || nil unless @phone.nil?
        platform = RUBY_PLATFORM.to_s.downcase
        android = platform.include?("android") || %w[ANDROID_ROOT ANDROID_DATA ANDROID_STORAGE].any? { |k| !ENV[k].to_s.empty? } ||
                  system_name.downcase == "android"
        joiplay = defined?(::JoiPlay) || !ENV["JOIPLAY"].to_s.empty?
        @phone = joiplay ? "JoiPlay" : (android ? "a phone (Android)" : false)
        return @phone || nil
      rescue StandardError
        return nil
      end

      def report
        f = facts
        return if f.empty?
        yes = proc { |v| v ? "yes" : "no" }
        Reloaded::Log.info("Running on: Ruby #{f[:ruby]}, #{f[:system]}; Windows calls #{yes.call(f[:windows_calls])}" \
                           "#{f[:wine] ? " (Wine #{f[:wine]})" : ''}, raw keyboard #{yes.call(f[:raw_keys])}, " \
                           "controller #{yes.call(f[:controller])}, mouse or touch #{yes.call(f[:mouse])}, clipboard #{yes.call(f[:clipboard])}; " \
                           "PIF's Device: #{f[:device]}; phone: #{f[:phone] || 'no'}; " \
                           "Kanto Reloaded's folder writable #{yes.call(f[:writable])}", :bootstrap)
      end

      # Wine's version ("9.0") under Wine / Proton (Linux, Steam Deck, Mac),
      # else nil (worked out once)
      def wine
        return @wine || nil unless @wine.nil?
        @wine = begin
          v = ::Win32API.new("ntdll", "wine_get_version", "", "P").call.to_s
          v.empty? ? false : v
        rescue StandardError, LoadError, NotImplementedError
          false
        end
        return @wine || nil
      end

      # Forget what was worked out (the tests start again)
      def reset
        @phone = @wine = nil
      end

      private

      # The system the engine says it's on ("Windows", "Linux", "Android")
      def system_name
        return ::System.platform.to_s if defined?(::System) && ::System.respond_to?(:platform)
        return "system unknown"
      rescue StandardError
        return "system unknown"
      end

      # A harmless Windows call works
      def windows_calls?
        return false unless defined?(::Win32API)
        return ::Win32API.new("kernel32", "GetCurrentProcessId", "", "L").call.to_i > 0
      rescue StandardError, LoadError, NotImplementedError
        return false
      end

      # A file can be made where Kanto Reloaded keeps its Settings and
      # Logging (its own folder), and is removed again
      def writable?
        probe = File.join(Reloaded::Paths.local_dir, ".kr_write_test")
        File.open(probe, "wb") { |f| f.write("") }
        File.delete(probe)
        return true
      rescue StandardError
        return false
      end

      def device
        ps = $PokemonSystem
        return "not read yet" unless ps && ps.respond_to?(:on_mobile)
        return ps.on_mobile ? "Mobile" : "PC"
      rescue StandardError
        return "?"
      end
    end
  end
end
