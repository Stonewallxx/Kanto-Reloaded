# encoding: utf-8
#==============================================================================
# Fix: KIF 1.2.13's Map Zoom setting (990_KIF/ZZ_Cody/C-UI-01_MapZoom/
# MapZoom.rb), found in his test (2026-10-30), with Adaptive and Test (1.5x),
# his asks
#==============================================================================
#   kif_map_zoom_choices  KIF 1.2.13 dropped the 1.5x level: KIF::MapZoom
#                         has two (LEVELS: Normal, and Far at 1x pixels) and
#                         reads an old Far or Farthest as the new Far, but its
#                         setting still offered Normal, Far and Farthest with
#                         the old words, so Far and Farthest both zoomed to
#                         1x. The setting now offers Normal, Far, Adaptive and
#                         Test (1.5x), and shows the level KIF uses (an old
#                         Farthest: Far).
#   Adaptive              Far outdoors and Normal on every map PIF marks as
#                         not outdoor (buildings, caves, underwater: his pick).
#   Test (1.5x)           The step KIF dropped (map pixels at 1.5x: 2x2 art
#                         pixels can't land evenly on it), on every map, to
#                         try out.
#   Both keep KIF's camera (his pick: it stops at map edges as at Far), and
#   are kept as kif_mapzoom 3 and 4, which KIF reads as Far: without Kanto
#   Reloaded a save on either plays Far.
# For everyone; only while KIF's setting is as written (its block's
# fingerprint).
#==============================================================================

module Reloaded
  module Fixes
    MAP_ZOOM_CRC = 1649440837          # MapZoom.rb:171-178, KIF::Options.add(:graphics) { Map Zoom } as KIF 1.2.13 has it

    module KIFMapZoom
      STORED = [0, 1, 3, 4].freeze     # kif_mapzoom for Normal, Far, Adaptive, Test (1.5x) (KIF::MapZoom.level reads 3 and 4 as Far)
      ADAPTIVE = 3
      TEST = 4
      TEST_SCALE = 0.75                # map pixels at 1.5x (Normal draws them at 2x)

      module_function

      # KIF's Map Zoom builder among the Graphics options, or nil
      def entry
        return nil unless defined?(::KIF::Options) && ::KIF::Options.respond_to?(:entries)
        return ::KIF::Options.entries(:graphics).find do |_scope, builder|
          file, line = builder.source_location
          file && File.basename(file.to_s) == "MapZoom.rb" && Reloaded::Fixes.lines_crc(file, line, "}") == MAP_ZOOM_CRC
        end
      end

      def stored
        return $PokemonSystem ? $PokemonSystem.kif_mapzoom.to_i : 0
      end

      # The map PIF marks as not outdoor (no metadata: not outdoor, as PIF
      # reads it). Read each map frame: kept per map
      def indoors?
        id = $game_map ? $game_map.map_id : nil
        return false unless id
        return @indoors if id == @indoors_of
        @indoors_of = id
        md = (GameData::MapMetadata.try_get(id) rescue nil)
        return @indoors = !(md && md.outdoor_map)
      end

      def option
        return EnumOption.new(_INTL("Map Zoom"), [_INTL("Normal"), _INTL("Far"), _INTL("Adaptive"), _INTL("Test (1.5x)")],
                              proc { STORED.index(stored) || ::KIF::MapZoom.level },
                              proc { |value| $PokemonSystem.kif_mapzoom = STORED[value.to_i] || 0; ::KIF::MapZoom.sync },
                              [_INTL("The overworld at its normal size."),
                               _INTL("Zooms the overworld out (map pixels at 1x): You see about four times as much of the map. Menus and text keep their size."),
                               _INTL("Far outdoors and Normal indoors (buildings and caves)."),
                               _INTL("Map pixels at 1.5x, between Normal and Far, to try out: Some art pixels are drawn wider than others.")])
      end
    end

    # The zoom Adaptive and Test (1.5x) ask for (KIF::MapZoom.wanted is read
    # every map frame; 1.0 when the feature is off or a mod zooms)
    module KIFMapZoomLevels
      def wanted
        w = super
        return w if w == 1.0
        case Reloaded::Fixes::KIFMapZoom.stored
        when Reloaded::Fixes::KIFMapZoom::TEST     then return Reloaded::Fixes::KIFMapZoom::TEST_SCALE
        when Reloaded::Fixes::KIFMapZoom::ADAPTIVE then return Reloaded::Fixes::KIFMapZoom.indoors? ? 1.0 : w
        end
        return w
      end
    end
  end
end

Reloaded::Fixes.register(:kif_map_zoom_choices, "KIF's Map Zoom offers Normal, Far, Adaptive and Test (1.5x)") do
  next false unless defined?(::KIF::MapZoom) && [:level, :sync, :wanted].all? { |m| ::KIF::MapZoom.respond_to?(m) }
  entry = Reloaded::Fixes::KIFMapZoom.entry
  next false unless entry
  entry[1] = proc { Reloaded::Fixes::KIFMapZoom.option }
  Reloaded::Hooks.prepend(nil, ::KIF::MapZoom.singleton_class, Reloaded::Fixes::KIFMapZoomLevels, :id => :fix_kif_map_zoom_levels)
  next true
end
