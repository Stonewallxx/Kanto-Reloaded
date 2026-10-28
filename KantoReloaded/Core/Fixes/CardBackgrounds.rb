# encoding: utf-8
#==============================================================================
# Fixes: PIF's Trainer Card backgrounds (052_InfiniteFusion/Gameplay/Features/
# TrainerCardBackgrounds.rb, Fusion/Credits/SpriteCreditsUtils.rb), found by
# the Trainer Card's prep (his pick, 2026-10-28: fixed for everyone, so PIF's
# own card, its Printers and the Sprite Gallery are right too)
#==============================================================================
#   card_background_names  A picture whose file name has a stray space or a
#                          capital extension is found by its clean name:
#                          Sewers ("SEWERS .png") showed PIF's plain card,
#                          and Froslass's flag ("FROSLASS _FLAG.png") and
#                          Lugia's ("LUGIA_FLAG.PNG", on a phone) had no
#                          picture. Only under Trainer Card/backgrounds.
#   team_flags             The Sprite Gallery's flags of the day: Lugia's was
#                          never offered (its .PNG), and Froslass's was sold
#                          as Pikachu's (a species name with a space falls
#                          back to Pikachu). Now each is its own.
#   card_background_lists  Cinnabar's background is on Cinnabar's Printer
#                          list with no picture: left off it until it has one.
#==============================================================================

module Reloaded
  module Fixes
    module CardBackgrounds
      DIR = "Graphics/Pictures/Trainer Card/backgrounds"
      FLAG = /_FLAG\.png\z/i
      @names = {}

      class << self
        attr_reader :names

        # clean path (no extension, no spaces, lowercase) => the real file
        def build
          @names = {}
          root = Reloaded::Paths.game_dir
          [DIR, "#{DIR}/flags"].each do |dir|
            full = File.join(root, dir)
            next unless File.directory?(full)
            Dir.children(full).each do |f|
              ext = File.extname(f)
              base = File.basename(f, ext)
              next unless ext.downcase == ".png"
              next if ext == ".png" && !base.include?(" ")
              @names[key("#{dir}/#{base}")] = "#{dir}/#{f}"
            end
          end
          return !@names.empty?
        end

        def key(path)
          return path.to_s.tr("\\", "/").sub(/\.png\z/i, "").delete(" ").downcase
        end

        # The real file for a path under Trainer Card/backgrounds, or nil
        def real(path)
          return nil if @names.empty? || !path.is_a?(String) || !path.include?("Trainer Card/backgrounds")
          return @names[key(path)]
        end

        # The Sprite Gallery's flags: every picture named *_FLAG.png (any
        # case), its species' own name (no spaces), only real species
        def daily_flags
          dir = File.join(Reloaded::Paths.game_dir, DIR, "flags")
          names = Dir.children(dir).select { |f| f =~ FLAG }.map { |f| f.sub(FLAG, "").delete(" ") }
          return names.select { |n| ::GameData::Species.exists?(n.to_sym) rescue false }
        end
      end

      module BitmapNames
        def initialize(*args)
          if args[0].is_a?(String) && (fixed = Reloaded::Fixes::CardBackgrounds.real(args[0]))
            args[0] = fixed
          end
          super(*args)
        end
      end

      module ResolveNames
        private

        def pbResolveBitmap(x)
          fixed = Reloaded::Fixes::CardBackgrounds.real(x)
          return fixed ? super(fixed) : super
        end
      end
    end
  end
end

Reloaded::Fixes.register(:card_background_names, "Trainer Card backgrounds with a stray space or a capital extension in their file names are found (Sewers, the Froslass and Lugia flags)") do
  next false unless Reloaded::Fixes::CardBackgrounds.build
  Reloaded::Hooks.prepend(nil, ::Bitmap, Reloaded::Fixes::CardBackgrounds::BitmapNames, :id => :fix_card_background_bitmaps)
  Reloaded::Hooks.prepend(nil, ::Object, Reloaded::Fixes::CardBackgrounds::ResolveNames, :id => :fix_card_background_paths)
end

Reloaded::Fixes.register(:team_flags, "The Sprite Gallery offers Lugia's and Froslass's team flags, each as its own") do
  next false unless ::Object.private_method_defined?(:select_daily_team_flags) || ::Object.method_defined?(:select_daily_team_flags)
  Reloaded::Hooks.around(nil, ::Object, :select_daily_team_flags, :id => :fix_team_flags) do |_original, *_args|
    picked = Reloaded::Fixes::CardBackgrounds.daily_flags.sample(4)
    pbSet(VAR_GALLERY_TEAM_FLAGS, picked)
  end
end

Reloaded::Fixes.register(:card_background_lists, "Cinnabar's Trainer Card background is left off its Printer until it has a picture") do
  next false unless defined?(::CARD_BACKGROUND_CITY_EXCLUSIVES) && ::CARD_BACKGROUND_CITY_EXCLUSIVES.is_a?(Hash) &&
                    !::CARD_BACKGROUND_CITY_EXCLUSIVES.frozen?
  missing = ::CARD_BACKGROUND_CITY_EXCLUSIVES.keys.reject { |id| pbResolveBitmap("#{Reloaded::Fixes::CardBackgrounds::DIR}/#{id}") }
  missing.each { |id| ::CARD_BACKGROUND_CITY_EXCLUSIVES.delete(id) }
  Reloaded::Log.info("Trainer Card backgrounds with no picture, off their Printers: #{missing.join(", ")}", :fixes) unless missing.empty?
  true
end
