# encoding: utf-8
#==============================================================================
# Kanto Reloaded: IV Boundaries' Fusion IVs
#==============================================================================
# His pick (Q13): By Splicer is PIF's own (DNA Splicers average the two IVs,
# Super Splicers keep the higher of each) and the default; Always Average
# and Always Best of Both apply to every fusion. cody's Fusion Screen
# preview works the IVs out with its own copy of the rule, so it follows the
# same setting.
#==============================================================================

module Reloaded
  module IVBoundaries
    module Fusion
      def self.install
        h = Reloaded::Hooks
        if defined?(::PokemonFusionScene) && ::PokemonFusionScene.method_defined?(:setFusionIVs)
          h.around(FEATURE, ::PokemonFusionScene, :setFusionIVs, :id => :ivb_fusion) do |original, supersplicers|
            scene = original.receiver
            case Reloaded::IVBoundaries.fusion
            when 1 then scene.averageFusionIvs
            when 2 then scene.setHighestFusionIvs
            else original.call(supersplicers)
            end
          end
        end
        fs = defined?(::KIF::FusionScreen) ? ::KIF::FusionScreen : nil
        if fs && fs.respond_to?(:ghost)
          h.around(FEATURE, fs.singleton_class, :ghost, :id => :ivb_fusion_preview) do |original, body, head, dex, level, supersplicers|
            rule = Reloaded::IVBoundaries.fusion
            original.call(body, head, dex, level, rule == 0 ? supersplicers : rule == 2)
          end
        end
      end
    end
  end
end
