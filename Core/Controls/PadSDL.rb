#==============================================================================
# Kanto Reloaded: the engine's own SDL, for controllers
#==============================================================================
# KIF Beta's engine (InfiniteFusion.exe / Game.exe, PIF 6.8.2's mkxp-z) has
# SDL built in and exports its functions, so a script can ask SDL directly
# what the game itself can't say: every device SDL sees, by name and model
# (vendor:product), and whether SDL counts it as a controller. One SDL
# doesn't know isn't a controller to the game at all: the engine's list of
# controller models (SDL's controller DB) is from 2021.
#
# Reached through Win32API, the way KIF's updater calls Windows. The
# running exe is loaded by its own path (asking for the other name would
# load a second, separate SDL). Text SDL hands back is copied with
# Windows' own string calls, so a missing name can't crash the game. Under
# Wine / Proton (Linux, Steam Deck, Mac) it's the same exe and works the
# same. Anything that fails makes it say why and stop.
#
# Nothing here depends on the rest of Kanto Reloaded, so the same file can
# go to KIF Beta.
#==============================================================================

module Reloaded
  module Controls
    module PadSDL
      class << self
        # Why it can't be used (a short reason), or nil when it can.
        attr_reader :problem

        def available?
          return false if @problem
          return true if @exe
          raise "Win32API isn't here" unless defined?(::Win32API)
          @exe = exe_path
          raise "the game's exe wasn't found" if @exe.to_s.empty?
          fn("SDL_NumJoysticks", "", "I").call
          return true
        rescue StandardError, LoadError, NotImplementedError => e
          @problem = "#{e.class}: #{e.message}"
          return false
        end

        # "2.0.12", the SDL inside the engine
        def version
          buf = "\0" * 3
          fn("SDL_GetVersion", "P", "V").call(buf)
          return buf.unpack("C3").join(".")
        end

        def count
          return fn("SDL_NumJoysticks", "", "I").call.to_i
        end

        # [{ :name, :vendor, :product, :controller }] for every device SDL
        # sees ("054c:0ce6" style model numbers come from vendor/product)
        def devices
          (0...count).map do |i|
            { :name => c_string(fn("SDL_JoystickNameForIndex", "I", "L").call(i)),
              :vendor => fn("SDL_JoystickGetDeviceVendor", "I", "I").call(i).to_i & 0xFFFF,
              :product => fn("SDL_JoystickGetDeviceProduct", "I", "I").call(i).to_i & 0xFFFF,
              :controller => fn("SDL_IsGameController", "I", "I").call(i).to_i != 0 }
          end
        end

        def model(dev)
          return format("%04x:%04x", dev[:vendor], dev[:product])
        end

        # The fix: newer controller models for the engine's list (one line
        # each, SDL's mapping format; ControllerModels.txt). A model SDL
        # already has is never replaced, so a controller that works now
        # stays as it is. [added, already known]
        def add_models(lines)
          added = known = 0
          lines.each do |line|
            line = line.strip
            next if line.empty? || line.start_with?("#")
            guid = line[0, 32]
            next unless guid =~ /\A[0-9a-f]{32}\z/
            if mapping_for(guid)
              known += 1
              next
            end
            added += 1 if fn("SDL_GameControllerAddMapping", "P", "I").call(line).to_i == 1
          end
          return [added, known]
        end

        def add_models_from(path)
          return add_models(File.readlines(path, :encoding => "UTF-8"))
        end

        # SDL's mapping for a GUID (32 hex digits), or nil. A 16-byte struct
        # is passed by pointer on 64-bit Windows, so a pointer to its bytes is
        # what SDL expects; the text it returns is SDL's to free.
        def mapping_for(guid)
          address = fn("SDL_GameControllerMappingForGUID", "P", "L").call([guid].pack("H*")).to_i
          return nil if address == 0
          text = c_string(address)
          fn("SDL_free", "L", "V").call(address)
          return text
        end

        # A controller SDL now knows, already plugged in: SDL only announces
        # one as it's plugged in, so the engine is told the way SDL tells it
        # (SDL_CONTROLLERDEVICEADDED, the device's index). SDL_Event is 56
        # bytes.
        CONTROLLER_ADDED = 0x653

        def open_in_engine(index)
          event = [CONTROLLER_ADDED, 0, index].pack("LLl") + ("\0" * 44)
          return fn("SDL_PushEvent", "P", "I").call(event).to_i == 1
        end

        # Wine's version ("9.0") under Wine / Proton, else nil
        def wine
          return @wine unless @wine.nil?
          @wine = begin
            v = ::Win32API.new("ntdll", "wine_get_version", "", "P").call.to_s
            v.empty? ? false : v
          rescue StandardError, LoadError, NotImplementedError
            false
          end
          return @wine || nil
        end

        # Forget everything (the tests start again)
        def reset
          @problem = @exe = @wine = nil
          @fns = {}
          @k32 = {}
        end

        private

        # One of the engine's SDL functions
        def fn(name, args, ret)
          @fns ||= {}
          return @fns[name] ||= ::Win32API.new(@exe, name, args, ret)
        end

        # One of Windows' own (kernel32)
        def k32(name, args, ret)
          @k32 ||= {}
          return @k32[name] ||= ::Win32API.new("kernel32", name, args, ret)
        end

        # The running exe's own path (Game.exe or InfiniteFusion.exe)
        def exe_path
          buf = "\0" * 520
          n = k32("GetModuleFileNameA", "LPL", "L").call(0, buf, buf.bytesize).to_i
          return n > 0 ? buf[0, n] : nil
        end

        # The text at a C string's address (nil for none), copied with
        # Windows' own calls
        def c_string(address)
          address = address.to_i
          return nil if address == 0
          len = k32("lstrlenA", "L", "I").call(address).to_i
          return "" if len <= 0
          buf = "\0" * len
          k32("RtlMoveMemory", "PLL", "V").call(buf, address, len)
          return buf.force_encoding("UTF-8").scrub("?")
        end
      end
    end
  end
end
