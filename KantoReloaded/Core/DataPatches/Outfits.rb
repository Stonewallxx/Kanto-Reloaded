#==============================================================================
# Kanto Reloaded: Data Patches for outfits
#==============================================================================
# outfits.clothes     Clothes     ($PokemonGlobal.clothes_data)
# outfits.hats        Hat         ($PokemonGlobal.hats_data)
# outfits.hairstyles  Hairstyle   ($PokemonGlobal.hairstyles_data)
#
# The game fills these lists from its outfit JSON whenever it refreshes them
# (update_global_clothes_list and the others); patched outfits are added
# after each refresh. The same JSON is each target's base, so edit and merge
# work on the game's own outfits too. Fields: name, description, price, tags, storelocation,
# regiontags, pokemontags (each "pokemon-<name>"), contestcondition (not for
# hairstyles). Names and descriptions go through the game's translation as
# its own do. The outfits are made once per build, not on every refresh.
#==============================================================================

module Reloaded
  module DataPatchOutfits
    TARGETS = {
      "outfits.clothes"    => [:clothes_data, "Clothes", :update_global_clothes_list, :CLOTHES_DATA_PATH],
      "outfits.hats"       => [:hats_data, "Hat", :update_global_hats_list, :HATS_DATA_PATH],
      "outfits.hairstyles" => [:hairstyles_data, "Hairstyle", :update_global_hairstyles_list, :HAIRSTYLE_DATA_PATH]
    }.freeze
    FIELDS = %w[name description price tags storelocation regiontags pokemontags contestcondition].freeze
    DP = Reloaded::DataPatches

    @built = {}

    class << self
      def install
        TARGETS.each do |target, (_key, _klass, loader)|
          next unless ::Object.private_method_defined?(loader) || ::Object.method_defined?(loader)
          Reloaded::Hooks.around(nil, ::Object, loader, :id => :"data_patch_#{target.tr(".", "_")}") do |original, *args|
            result = original.call(*args)
            Reloaded::DataPatchOutfits.add_to_list(target)
            result
          end
        end
        Reloaded::Events.on(:game_data_loaded, :data_patch_outfits_base, 50) do
          TARGETS.each_key { |t| DP.register_target(t, base(t), :description => "$PokemonGlobal.#{TARGETS[t][0]}") }
        end
        Reloaded::Events.on(:data_patches_apply, :data_patch_outfits_build, 100) { build_all }
        return true
      end

      # The patched outfits, made once per build.
      def build_all
        TARGETS.each do |target, (_key, klass_name, loader)|
          @built[target] = {}
          klass = DP.resolve(klass_name)
          next unless klass
          DP.applied(target, :all => true).map { |p| p[:id] }.uniq.each do |id|
            obj = build(klass, klass_name, id, DP.stringify(DP.entry(target, id)))
            if obj
              @built[target][obj.id] = obj
            else
              DP.reject(target, id, @why)
            end
          end
          send(loader) if DP.reloading? && $PokemonGlobal && respond_to?(loader, true)
        end
      rescue StandardError => e
        Reloaded::Log.exception("Outfit data patches couldn't be built", e, :data_patches)
      end

      # After the game refreshed a list: the patched outfits join it.
      def add_to_list(target)
        built = @built[target]
        return if built.nil? || built.empty? || $PokemonGlobal.nil?
        list = $PokemonGlobal.send(TARGETS[target][0]) rescue nil
        return unless list.is_a?(Hash)
        built.each { |id, obj| list[id] = obj }
      end

      private

      # The game's own outfits of a target, from its outfit JSON (Settings'
      # path), as patches see them: { id => { field => value } }.
      def base(target)
        const = TARGETS[target][3]
        return {} unless defined?(::Settings) && ::Settings.const_defined?(const, false)
        path = ::Settings.const_get(const, false).to_s
        return {} unless File.file?(path)
        list = Reloaded::JSON.parse(Reloaded::Paths.read_text(path).to_s)
        out = {}
        Array(list).each do |d|
          next unless d.is_a?(Hash) && !DP.blank?(d["id"])
          out[d["id"].to_s] = d.select { |k, _| FIELDS.include?(k) }
        end
        return out
      rescue StandardError => e
        Reloaded::Log.exception("The game's #{target} couldn't be read for data patches", e, :data_patches)
        return {}
      end

      def build(klass, klass_name, id, d)
        tr = defined?(_OUTFIT_INTL) ? method(:_OUTFIT_INTL) : nil
        name = (d["name"] || id).to_s
        desc = (d["description"] || "").to_s
        name = tr.call(name) if tr
        desc = tr.call(desc) if tr && !desc.empty?
        tags = list(d["tags"]) + list(d["storelocation"]) + list(d["regiontags"]) + list(d["pokemontags"]).map { |t| "pokemon-#{t.downcase}" }
        args = [(d["id"] || id).to_s, name, desc, d["price"].to_i, tags, list(d["storelocation"])]
        args << list(d["contestcondition"]) unless klass_name == "Hairstyle"
        return klass.new(*args)
      rescue StandardError => e
        @why = "It couldn't be made: #{e.class}: #{e.message}."
        return nil
      end

      def list(value)
        return value.map { |v| v.to_s.strip }.reject(&:empty?) if value.is_a?(Array)
        return value.to_s.split(",").map(&:strip).reject(&:empty?)
      end
    end
  end
end
