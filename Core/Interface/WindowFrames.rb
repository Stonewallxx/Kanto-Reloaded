#==============================================================================
# Kanto Reloaded: window frames (Global Frame and Speech Frame)
#==============================================================================
# The frames around the game's windows, set in Kanto Reloaded > Interface:
#
#   Theme Mode     how the Theme frame looks: Dark (the default), Glass
#                  (see-through), Light (a near-white panel tinted by the
#                  Theme) or Frost (Light, see-through); the Pause Menu and
#                  Overworld Menu follow it too (Reloaded::Palette.map_menu)
#   Global Frame   menus and every other window. Theme (the default) draws it
#                  in the Theme's colours, in the Theme Mode; or RLD Clear,
#                  PIF Clear and PIF Opaque (PIF's own two), or one of the 30
#                  RLD frames (light and dark, from the old Kanto Reloaded and
#                  Hoenn Reloaded)
#   Speech Frame   text boxes. Theme (the default) uses the Global Frame; or
#                  one of PIF's speech frames, RLD Clear or an RLD frame (the
#                  game sizes a frame's edges from its picture, so the 48x48
#                  frames work as text boxes). It
#                  takes the place of PIF's own Speech Frame row too (KIF
#                  Settings > Graphics > Text: the same setting), and a PIF
#                  frame picked here is copied to PIF's setting, so it stays
#                  without Kanto Reloaded.
#
# The frames are the mod's files in Graphics/Windowskins: "Theme <theme>"
# (Dark) and "Theme <mode> <theme>" (drawn by Tools/Frames/make_theme_frames.py
# from the Theme colours), "RLD Choice <n>" and "RLD Choice <n>a" (dark),
# "RLD Transparent" (RLD Clear). PIF picks white or dark text from a frame's
# centre, so the light ones get dark text.
#==============================================================================

module Reloaded
  module WindowFrames
    GLOBAL = :"interface.global_frame"
    SPEECH = :"interface.speech_frame"
    MODE   = :"interface.theme_mode"
    RLD_FRAMES = 30
    SPEECH_NAMES = { "hgss" => "HGSS", "dp" => "DP", "pl" => "Platinum", "em" => "Emerald", "frlg" => "FRLG" }.freeze
    # Theme Mode: [label, the frame files' word] (Dark is "Theme <theme>")
    THEME_MODES = [["Dark", nil], ["Glass", "Glass"], ["Light", "Light"], ["Frost", "Frost"]].freeze
    RESET = 4      # Settings.json schema: the lists changed order, so older picks go back to Theme

    class << self
      # Global Frame's choices: [label, windowskin or :theme]
      def global_choices
        @global_choices ||= [["Theme", :theme], ["RLD Clear", "RLD Transparent"], ["PIF Clear", "default_transparent"],
                             ["PIF Opaque", "default_opaque"]] + rld_frames
      end

      # Speech Frame's choices: [label, windowskin or :global]. Theme (the
      # Global Frame's), PIF's speech frames, then RLD Clear and the RLD
      # frames.
      def speech_choices
        @speech_choices ||= [["Theme", :global]] + pif_speech_frames.map { |s| [speech_label(s), s] } +
                            [["RLD Clear", "RLD Transparent"]] + rld_frames
      end

      # The 30 RLD frames, each light and dark.
      def rld_frames
        return (1..RLD_FRAMES).flat_map { |n| [["RLD #{n}", "RLD Choice #{n}"], ["RLD #{n} Dark", "RLD Choice #{n}a"]] }
      end

      def register_settings
        s = Reloaded::Settings
        s.register(MODE, :page => :interface, :priority => 55,
          :name => "Theme Mode", :type => :enum, :default => 0, :values => THEME_MODES.map(&:first),
          :apply => proc { |_v, _restoring| Reloaded::WindowFrames.apply },
          :description => "How the Theme frame, the Pause Menu and the Overworld Menu look. Glass is see-through, Light a pale panel in the Theme's color, Frost both.")
        s.register(GLOBAL, :page => :interface, :priority => 84,
          :name => "Global Frame", :type => :enum, :long => true, :swatch => :global_frame,
          :default => 0, :reset => RESET, :values => global_choices.map(&:first),
          :apply => proc { |_v, _restoring| Reloaded::WindowFrames.apply },
          :description => "The frame around menus and windows across the game. Theme draws it in the Theme's colors, in the Theme Mode.")
        s.register(SPEECH, :page => :interface, :priority => 86,
          :name => "Speech Frame", :type => :enum, :long => true, :swatch => :speech_frame,
          :default => 0, :reset => RESET, :values => speech_choices.map(&:first),
          :apply => proc { |_v, restoring| Reloaded::WindowFrames.apply(!restoring) },
          :description => "The frame around text boxes. Theme uses the Global Frame.")
      end

      def boot
        hooks = Reloaded::Hooks
        hooks.needs(:field, :textskin, :id => :frames_speech_sync)   # PIF's Speech Frame, kept in step
        if defined?(::MessageConfig)
          wf = Reloaded::WindowFrames
          hooks.around(nil, ::MessageConfig.singleton_class, :pbDefaultSystemFrame, :id => :frames_system) do |original|
            wf.resolved(wf.global_skin) || original.call
          end
          hooks.around(nil, ::MessageConfig.singleton_class, :pbDefaultSpeechFrame, :id => :frames_speech) do |original|
            wf.resolved(wf.speech_skin) || original.call
          end
        end
        # PIF's Speech Frame row: this one takes its place
        if defined?(::KIF::SettingsScreen) && ::KIF::SettingsScreen.respond_to?(:pif_items)
          hooks.around(nil, ::KIF::SettingsScreen.singleton_class, :pif_items, :id => :frames_pif_speech_row) do |original, *args|
            items, extra, root = original.call(*args)
            [items.reject { |it| it[:name] == "Speech Frame" }, extra, root]
          end
        end
        Reloaded::Settings.on_change(:"interface.theme", :window_frames) { apply }
        register_swatches
        return true
      end

      # The windowskin a Global Frame choice uses (Theme: the current Theme's,
      # in the Theme Mode).
      def global_skin(index = nil)
        index = Reloaded::Settings.get(GLOBAL) if index.nil?
        return skin_for((global_choices[index.to_i] || global_choices[0])[1])
      end

      # The windowskin a Speech Frame choice uses (Theme: the Global Frame's).
      def speech_skin(index = nil)
        index = Reloaded::Settings.get(SPEECH) if index.nil?
        skin = (speech_choices[index.to_i] || speech_choices[0])[1]
        return skin == :global ? global_skin : skin_for(skin)
      end

      # :theme as a file ("Theme Ocean Blue", "Theme Glass Ocean Blue"...), or
      # the windowskin itself.
      def skin_for(choice)
        return choice unless choice == :theme
        word = (THEME_MODES[Reloaded::Settings.get(MODE).to_i] || THEME_MODES[0])[1]
        return word ? "Theme #{word} #{theme_name}" : "Theme #{theme_name}"
      end

      def theme_name
        names = Reloaded::Palette::THEME_NAMES
        return names[Reloaded::Settings.get(:"interface.theme").to_i] || names[Reloaded::Palette::DEFAULT_THEME]
      end

      # A windowskin as the game finds it, or nil when it isn't there.
      def resolved(skin)
        path = pbResolveBitmap("Graphics/Windowskins/#{skin}")
        return path.nil? || path.to_s.empty? ? nil : path
      rescue StandardError
        return nil
      end

      # Puts the frames on: the next window uses them. sync: also copy a
      # PIF speech frame to PIF's own setting.
      def apply(sync = true)
        return unless defined?(::MessageConfig)
        sys = resolved(global_skin)
        ::MessageConfig.pbSetSystemFrame(sys) if sys
        speech = resolved(speech_skin)
        ::MessageConfig.pbSetSpeechFrame(speech) if speech
        if sync && $PokemonSystem && $PokemonSystem.respond_to?(:textskin=)
          k = pif_speech_frames.index(speech_skin)          # nil for Theme
          $PokemonSystem.textskin = k if k
        end
      rescue StandardError => e
        Reloaded::Log.exception("Couldn't put the window frames on", e, :interface)
      end

      #------------------------------------------------------------------------
      # The pickers' previews: each frame drawn small before its name
      #------------------------------------------------------------------------
      def register_swatches
        return unless defined?(Reloaded::Dialogs) && Reloaded::Dialogs.respond_to?(:swatches)
        wf = Reloaded::WindowFrames
        Reloaded::Dialogs.swatches[:global_frame] = proc { |b, _c, x, y, h, i| wf.draw_preview(b, x, y + 3, h - 6, wf.global_skin(i)) }
        Reloaded::Dialogs.swatches[:speech_frame] = proc { |b, _c, x, y, h, i| wf.draw_preview(b, x, y + 3, h - 6, wf.speech_skin(i)) }
      end

      PREVIEW_W = 36

      # The frame at half size, its corners kept (nine pieces): returns the
      # width it took.
      def draw_preview(b, x, y, h, skin)
        bmp = skin_bitmap(skin)
        return PREVIEW_W unless bmp
        cw = bmp.width / 3
        ch = bmp.height / 3
        dw = [cw / 2, PREVIEW_W / 2].min
        dh = [ch / 2, h / 2].min
        cols = [[0, cw, 0, dw], [cw, bmp.width - 2 * cw, dw, PREVIEW_W - 2 * dw], [bmp.width - cw, cw, PREVIEW_W - dw, dw]]
        rows = [[0, ch, 0, dh], [ch, bmp.height - 2 * ch, dh, h - 2 * dh], [bmp.height - ch, ch, h - dh, dh]]
        rows.each do |sy, sh, dy, dhh|
          next if dhh <= 0
          cols.each do |sx, sw, dx, dww|
            next if dww <= 0
            b.stretch_blt(Rect.new(x + dx, y + dy, dww, dhh), bmp, Rect.new(sx, sy, sw, sh))
          end
        end
        return PREVIEW_W
      end

      def skin_bitmap(skin)
        @bitmaps ||= {}
        bmp = @bitmaps[skin]
        return bmp if bmp && !bmp.disposed?
        path = resolved(skin)
        return nil unless path
        return @bitmaps[skin] = Bitmap.new(path)
      rescue StandardError
        return nil
      end

      private

      def pif_speech_frames
        return defined?(::Settings::SPEECH_WINDOWSKINS) ? ::Settings::SPEECH_WINDOWSKINS.map(&:to_s) : []
      end

      # "speech hgss 3" -> "HGSS 3", "speech pl 18" -> "Platinum 18"
      def speech_label(skin)
        words = skin.sub(/\Aspeech\s+/i, "").split(/\s+/)
        words = words.map { |w| SPEECH_NAMES[w.downcase] || (w[0, 1].upcase + w[1..-1].to_s) }
        return words.join(" ")
      end
    end
  end
end

Reloaded::WindowFrames.register_settings
