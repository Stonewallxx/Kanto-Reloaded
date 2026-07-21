#======================================================
# KantoReloaded Data Patch Outfits
# Author: Stonewall
#======================================================
# Direct runtime data patch target for base-game outfit data.
#
# Responsibilities:
#   - Register outfit data patch targets.
#   - Apply patched clothes, hat, and hairstyle entries to $PokemonGlobal.
#   - Wrap the base outfit list refresh methods without editing base files.
#
#======================================================

module KantoReloaded
  module DataPatchOutfits
    TARGETS = {
      "outfits.clothes" => {
        :global_key => :clothes_data,
        :klass => "Clothes",
        :base_loader => :update_global_clothes_list
      },
      "outfits.hats" => {
        :global_key => :hats_data,
        :klass => "Hat",
        :base_loader => :update_global_hats_list
      },
      "outfits.hairstyles" => {
        :global_key => :hairstyles_data,
        :klass => "Hairstyle",
        :base_loader => :update_global_hairstyles_list
      }
    }.freeze

    class << self
      def install
        register_targets
        patch_outfit_refresh_methods
        KantoReloaded::Log.info("Installed KantoReloaded outfit data patch bridge", :mods) if defined?(KantoReloaded::Log)
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Outfit data patch bridge install failed", e, channel: :mods) if defined?(KantoReloaded::Log)
        false
      end

      def register_targets
        return unless defined?(KantoReloaded::DataPatches)
        TARGETS.each_key { |target| KantoReloaded::DataPatches.register_target(target, {}, owner: :kanto_reloaded, description: "Runtime outfit data patch target.") }
      end

      def apply_all
        TARGETS.each_key { |target| apply_target(target) }
      end

      def apply_target(target)
        return false unless defined?(KantoReloaded::DataPatches)
        config = TARGETS[target.to_s]
        return false unless config
        return false unless defined?($PokemonGlobal) && $PokemonGlobal

        existing = $PokemonGlobal.send(config[:global_key]) rescue nil
        return false unless existing.is_a?(Hash)

        patched_entries = KantoReloaded::DataPatches.data(target)
        patched_entries.each do |id, raw_data|
          object = build_outfit_object(config, id, raw_data)
          existing[object.id] = object if object
        end

        if defined?(KantoReloaded::Log) && !patched_entries.empty?
          message = "Applied #{patched_entries.length} #{target} data patch entr#{patched_entries.length == 1 ? 'y' : 'ies'}"
          if KantoReloaded::Log.respond_to?(:info_once)
            KantoReloaded::Log.info_once(message, :mods, key: "outfit_data_patch_applied:#{target}:#{patched_entries.keys.sort.join(",")}")
          else
            KantoReloaded::Log.info(message, :mods)
          end
        end
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Failed to apply outfit data patches for #{target}", e, channel: :mods) if defined?(KantoReloaded::Log)
        false
      end

      private

      def patch_outfit_refresh_methods
        TARGETS.each do |target, config|
          patch_loader(config[:base_loader], target)
        end
      end

      def patch_loader(method_name, target)
        return unless Object.private_method_defined?(method_name) || Object.method_defined?(method_name)
        KantoReloaded::Hooks.wrap(
          Object, method_name, "data_patch_outfits_#{method_name}"
        ) do |hook, *_args|
          result = hook.call
          KantoReloaded::DataPatchOutfits.apply_target(target) if defined?(KantoReloaded::DataPatchOutfits)
          result
        end
      end

      def build_outfit_object(config, id, raw_data)
        data = stringify_keys(raw_data.is_a?(Hash) ? raw_data : {})
        klass = Object.const_get(config[:klass])
        args = [
          data["id"] || id,
          data["name"] || id,
          data["description"] || "",
          data["price"] || 0,
          split_tags(data["tags"]) + split_tags(data["storelocation"]) + split_tags(data["regiontags"]) + pokemon_tags(data["pokemontags"]),
          split_tags(data["storelocation"])
        ]
        args << split_tags(data["contestcondition"]) unless config[:klass] == "Hairstyle"
        klass.new(*args)
      end

      def split_tags(value)
        case value
        when Array
          value.map(&:to_s).map(&:strip).reject(&:empty?)
        else
          value.to_s.split(",").map(&:strip).reject(&:empty?)
        end
      end

      def pokemon_tags(value)
        split_tags(value).map { |tag| "pokemon-#{tag.downcase}" }
      end

      def stringify_keys(hash)
        result = {}
        hash.each { |key, value| result[key.to_s] = value }
        result
      rescue
        {}
      end

    end
  end
end

KantoReloaded::DataPatchOutfits.install if defined?(KantoReloaded::DataPatchOutfits)
