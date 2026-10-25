#==============================================================================
# Kanto Reloaded: Data Patches for wild encounters
#==============================================================================
# encounters.classic     GameData::Encounter        (encounters.dat)
# encounters.remix       GameData::EncounterModern  (encounters_remix.dat)
# encounters.randomized  GameData::EncounterRandom  (KIF's randomizer makes it)
#
# An entry's id is "<map>_<version>" ("8_0" is Route 24). Fields:
#   step_chances  { "Land": 21 }             merged into the map's
#   types         { "Land": [[chance, species, min, max], ...] }
#                                             each table named replaces the map's
#   add_types     { "Land": [[20, "PIKACHU", 5, 7]] }  added to the map's
# A table's entry can also be { "chance", "species", "min_level", "max_level" }.
# Fusions are written B<body>H<head>.
#
# The patched tables go into the game's data when it loads, so the game sets
# up each map from them and KIF's randomizer modes (Swap, Dynamic Routes...)
# work on top as usual. KIF makes the Randomized tables again from Classic's
# when it randomizes; randomized patches apply again each time it does.
#==============================================================================

module Reloaded
  module DataPatchEncounters
    TARGETS = {
      "encounters.classic"    => "GameData::Encounter",
      "encounters.remix"      => "GameData::EncounterModern",
      "encounters.randomized" => "GameData::EncounterRandom"
    }.freeze
    DP = Reloaded::DataPatches

    @originals = {}      # target => { key => the game's encounter }
    @managed = {}        # target => [key, ...]

    class << self
      def install
        Reloaded::Events.on(:game_data_loaded, :data_patch_encounters_base, 50) { TARGETS.each_key { |t| register_target(t) } }
        Reloaded::Events.on(:data_patches_apply, :data_patch_encounters_apply, 100) { apply_all }
        if ::Kernel.respond_to?(:randomizeWildPokemonByRoute)
          Reloaded::Hooks.around(nil, ::Kernel.singleton_class, :randomizeWildPokemonByRoute, :id => :data_patch_randomized_encounters) do |original, *args|
            result = original.call(*args)
            Reloaded::DataPatchEncounters.after_randomize
            result
          end
        end
        return true
      end

      def register_target(target)
        k = DP.resolve(TARGETS[target])
        return unless k && k.const_defined?(:DATA)
        restore(target, k)
        DP.register_target(target, snapshot(target, k), :description => "#{TARGETS[target]}::DATA", :defer_missing_entries => true)
      end

      def apply_all
        TARGETS.each_key { |target| apply_target(target) }
        refresh_map if DP.reloading?
      rescue StandardError => e
        Reloaded::Log.exception("Encounter data patches couldn't be applied", e, :data_patches)
      end

      # KIF made the Randomized tables again (from Classic's, patches
      # included): they are its new base, in the registry too (an edit
      # keeps the new tables it doesn't name), and randomized patches go on
      # top.
      def after_randomize
        target = "encounters.randomized"
        k = DP.resolve(TARGETS[target])
        return unless k && k.const_defined?(:DATA)
        @managed[target] = []
        DP.rebase(target, snapshot(target, k))
        apply_target(target)
      rescue StandardError => e
        Reloaded::Log.exception("Randomized encounter patches couldn't be applied", e, :data_patches)
      end

      private

      # The game's tables as they are now: kept to put back, and as patch
      # data ({ "map_version" => { ... } }).
      def snapshot(target, k)
        @originals[target] = {}
        base = {}
        k::DATA.each do |key, enc|
          next unless enc.respond_to?(:types) && enc.respond_to?(:map)
          @originals[target][key] = enc
          base[entry_id(enc.map, enc.version)] = to_hash(enc)
        end
        return base
      end

      def apply_target(target)
        k = DP.resolve(TARGETS[target])
        return unless k && k.const_defined?(:DATA)
        restore(target, k)
        DP.applied(target, :all => true).map { |p| p[:id] }.uniq.each do |id|
          apply_entry(target, k, id, DP.entry(target, id))
        end
      end

      def restore(target, k)
        Array(@managed[target]).each do |key|
          original = (@originals[target] || {})[key]
          if original
            k::DATA[key] = original
          else
            k::DATA.delete(key)
          end
        end
        @managed[target] = []
      end

      def apply_entry(target, k, id, raw)
        d = DP.stringify(raw)
        map, version = id.to_s.split("_").map(&:to_i)
        map = d["map"].to_i if d.key?("map")
        version = d["version"].to_i if d.key?("version")
        return DP.reject(target, id, "\"#{id}\" isn't <map>_<version> (like \"8_0\").") unless map.to_i > 0
        key = :"#{map}_#{version.to_i}"
        original = (@originals[target] || {})[key]
        base = original ? to_hash(original) : { "step_chances" => {}, "types" => {} }
        steps = DP.stringify(base["step_chances"]).merge(DP.stringify(d["step_chances"]))
        types = DP.stringify(base["types"])
        DP.stringify(d["types"]).each { |t, list| types[t] = Array(list) } if d.key?("types") && d["types"] != base["types"]
        DP.stringify(d["add_types"]).each { |t, list| types[t] = Array(types[t]) + Array(list) }
        step_chances = {}
        steps.each do |t, chance|
          type = encounter_type(t)
          return DP.reject(target, id, "#{t} isn't an encounter type (Land, Cave, Water...).") unless DP.known?("GameData::EncounterType", type)
          return DP.reject(target, id, "#{t}'s step chance is below 0.") if chance.to_i < 0
          step_chances[type] = chance.to_i
        end
        tables = {}
        types.each do |t, list|
          type = encounter_type(t)
          return DP.reject(target, id, "#{t} isn't an encounter type (Land, Cave, Water...).") unless DP.known?("GameData::EncounterType", type)
          tables[type] = []
          list.each_with_index do |e, i|
            entry = slot(e)
            where = "#{t} #{i + 1}"
            return DP.reject(target, id, "#{where} isn't [chance, species, min level, max level].") unless entry
            chance, species, min, max = entry
            return DP.reject(target, id, "#{where}: #{species} isn't a Pokémon (fusions are B<body>H<head>).") unless DP.species?(species)
            return DP.reject(target, id, "#{where}: the chance is below 1.") if chance <= 0
            return DP.reject(target, id, "#{where}: levels #{min} to #{max} don't work.") if min <= 0 || max < min
            tables[type] << entry
          end
        end
        enc = k.new(:id => key, :map => map, :version => version.to_i, :step_chances => step_chances, :types => tables)
        enc.instance_variable_set(:@kr_data_patch, true)
        k::DATA[key] = enc
        @managed[target] << key
        return true
      rescue StandardError => e
        return DP.reject(target, id, "It couldn't be made: #{e.class}: #{e.message}.")
      end

      # [chance, :SPECIES, min, max], from an array or a hash
      def slot(e)
        if e.is_a?(Hash)
          h = DP.stringify(e)
          chance = h["chance"] || h["weight"] || h["rarity"]
          species = h["species"] || h["id"]
          min = h["min_level"] || h["level"] || h["min"]
          max = h["max_level"] || h["level"] || h["max"] || min
        elsif e.is_a?(Array)
          chance, species, min, max = e
          max ||= min
        else
          return nil
        end
        return nil if DP.blank?(species)
        return [chance.to_i, DP.data_id("GameData::Species", species), min.to_i, max.to_i]
      end

      def encounter_type(value)
        return DP.data_id("GameData::EncounterType", value)
      end

      def to_hash(enc)
        types = {}
        (enc.types || {}).each { |t, list| types[t.to_s] = Array(list).map { |c, s, mn, mx| [c, s.to_s, mn, mx] } }
        steps = {}
        (enc.step_chances || {}).each { |t, v| steps[t.to_s] = v }
        return { "map" => enc.map, "version" => enc.version, "step_chances" => steps, "types" => types }
      end

      def entry_id(map, version)
        return "#{map.to_i}_#{version.to_i}"
      end

      # Hot Reload: the map you're on picks its tables again.
      def refresh_map
        return unless $PokemonEncounters && $game_map
        $PokemonEncounters.setup($game_map.map_id)
      end
    end
  end
end
