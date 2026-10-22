#==============================================================================
# Kanto Reloaded: Assets
#==============================================================================
# Kanto Reloaded's graphics and sounds stay in the mod folder
# (Mods\KantoReloaded\Graphics, \Audio); nothing is copied into the game's
# folders. When the game loads "Graphics/Pictures/foo" or plays
# "Audio/SE/bar", these hooks hand it the mod's file instead, but only for
# files the mod ships. With none shipped, the hooks cost one check.
#
#   Bitmap.new / pbResolveBitmap         Graphics/...
#   Audio.bgm/bgs/me/se_play             Audio/...
#
# Fonts are the exception: the engine only loads fonts from the game's
# Fonts folder at startup.
#==============================================================================

module Reloaded
  module Assets
    BITMAP_EXT = %w[.png .gif .jpg .jpeg .bmp].freeze
    AUDIO_EXT  = %w[.ogg .wav .mp3 .mid .midi .wma].freeze
    FOLDERS    = %w[Graphics Audio].freeze

    @index = {}

    class << self
      attr_reader :index

      def boot
        build_index
        install_hooks
        Reloaded::Log.info("#{@index.length} mod asset(s) indexed", :assets) unless @index.empty?
        return true
      end

      # The mod's file for a game path like "Graphics/Pictures/foo", or nil.
      def lookup(path)
        return nil if @index.empty? || !path.is_a?(String)
        return @index[key_for(path)]
      end

      def any?
        return !@index.empty?
      end

      private

      def key_for(path)
        key = path.tr("\\", "/").downcase
        key = key.sub(%r{\A\./}, "")
        ext = File.extname(key)
        key = key[0, key.length - ext.length] if BITMAP_EXT.include?(ext) || AUDIO_EXT.include?(ext)
        return key
      end

      # The mod folder as the game sees it: relative to the game folder
      # (the engine reads files through the game folder).
      def mod_prefix(root = Reloaded::ROOT)
        root = root.tr("\\", "/")
        game = Dir.pwd.tr("\\", "/")
        return root[(game.length + 1)..-1] if root.downcase.start_with?(game.downcase + "/")
        return root
      end

      def build_index(root = Reloaded::ROOT)
        @index = {}
        prefix = mod_prefix(root)
        FOLDERS.each do |folder|
          base = File.join(root, folder)
          next unless File.directory?(base)
          Dir.glob(File.join(base, "**", "*")).each do |file|
            next unless File.file?(file)
            ext = File.extname(file).downcase
            next unless BITMAP_EXT.include?(ext) || AUDIO_EXT.include?(ext)
            relative = file.tr("\\", "/")[(root.tr("\\", "/").length + 1)..-1]
            @index[key_for(relative)] = "#{prefix}/#{relative}"
          end
        end
      end

      def install_hooks
        hooks = Reloaded::Hooks
        hooks.prepend(nil, ::Bitmap, BitmapPaths, :id => :assets_bitmap)
        hooks.prepend(nil, ::Audio.singleton_class, AudioPaths, :id => :assets_audio) if defined?(::Audio)
        hooks.prepend(nil, ::Object, ResolvePaths, :id => :assets_resolve)
      end
    end

    # Bitmap.new("Graphics/...") loads the mod's file when it ships one.
    module BitmapPaths
      def initialize(*args)
        if args[0].is_a?(String) && Reloaded::Assets.any?
          mine = Reloaded::Assets.lookup(args[0])
          args[0] = mine if mine
        end
        super(*args)
      end
    end

    module AudioPaths
      [:bgm_play, :bgs_play, :me_play, :se_play].each do |name|
        define_method(name) do |*args|
          if args[0].is_a?(String) && Reloaded::Assets.any?
            mine = Reloaded::Assets.lookup(args[0])
            args[0] = mine if mine
          end
          super(*args)
        end
      end
    end

    # The game's "does this file exist / where is it" helpers.
    module ResolvePaths
      private

      def pbResolveBitmap(x)
        mine = Reloaded::Assets.lookup(x) if x.is_a?(String) && Reloaded::Assets.any?
        return mine || super
      end
    end
  end
end
