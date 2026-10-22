#==============================================================================
# Kanto Reloaded: Data Patches for trainers
#==============================================================================
# trainers.classic   GameData::Trainer        (trainers.dat)
# trainers.remix     GameData::TrainerModern  (trainers_remix.dat)
# trainers.expert    GameData::TrainerExpert  (trainers_expert.dat)
#
# KIF picks the set by game mode; a trainer the mode's set doesn't have comes
# from Classic, and so does KIF's Endgame Challenge for its own trainers'
# fallbacks. An entry's id is "TYPE|Name|version" ("LEADER_Brock|Brock|0").
#
# Fields: trainer_type, name, version, items (or bag_items), lose_text, the
# rematch and battle texts (loseText_rematch, battleText, preRematchText and
# its _caught/_evolved/_fused/_unfused/_reversed/_gift kinds, infoText; or
# their snake_case names), pokemon (the whole party), and to change a party
# instead of writing it out: edit_pokemon / replace_pokemon ([{ "slot", ... }])
# and add_pokemon. A party member: species, level, form, name, moves,
# moves_hard, moves_easy, ability, ability_index, item (or held_item), gender,
# nature, iv, ev, happiness, shininess, shadowness, poke_ball. Fusions are
# written B<body>H<head>.
#
# The game's own trainers are kept as they are and put back before every
# build, so Hot Reload never stacks one build on another. KIF's randomizer
# shuffles trainers when a game starts; a trainer added later may need the
# shuffle again (KIF asks).
#==============================================================================

module Reloaded
  module DataPatchTrainers
    TARGETS = {
      "trainers.classic" => "GameData::Trainer",
      "trainers.remix"   => "GameData::TrainerModern",
      "trainers.expert"  => "GameData::TrainerExpert"
    }.freeze
    TEXTS = %w[loseText_rematch battleText preRematchText preRematchText_caught
               preRematchText_evolved preRematchText_fused preRematchText_unfused preRematchText_reversed
               preRematchText_gift infoText].freeze
    TEXT_ALIASES = { "rematch_lose_text" => "loseText_rematch",
                     "battle_text" => "battleText", "pre_rematch_text" => "preRematchText",
                     "pre_rematch_caught_text" => "preRematchText_caught", "pre_rematch_evolved_text" => "preRematchText_evolved",
                     "pre_rematch_fused_text" => "preRematchText_fused", "pre_rematch_unfused_text" => "preRematchText_unfused",
                     "pre_rematch_reversed_text" => "preRematchText_reversed", "pre_rematch_gift_text" => "preRematchText_gift",
                     "trainer_info" => "infoText", "info_text" => "infoText" }.freeze
    POKEMON_FIELDS = %w[species level form name moves moves_hard moves_easy ability ability_index item held_item
                        gender nature iv ev happiness shininess shadowness poke_ball].freeze
    DP = Reloaded::DataPatches

    @originals = {}      # target => { key => the game's trainer }
    @managed = {}        # target => [[key, number], ...]

    class << self
      def install
        Reloaded::Events.on(:game_data_loaded, :data_patch_trainers_base, 50) { register_targets }
        Reloaded::Events.on(:data_patches_apply, :data_patch_trainers_apply, 100) { apply_all }
        return true
      end

      def register_targets
        TARGETS.each do |target, class_name|
          k = trainer_class(class_name)
          next unless k
          restore(target, k)
          @originals[target] = {}
          base = {}
          k::DATA.each do |key, t|
            next if key.is_a?(Integer) || !t.respond_to?(:pokemon)
            @originals[target][key] = t
            base[entry_id(t.trainer_type, t.real_name, t.version)] = to_hash(t)
          end
          DP.register_target(target, base, :description => "#{class_name}::DATA", :defer_missing_entries => true)
        end
      end

      def apply_all
        TARGETS.each do |target, class_name|
          k = trainer_class(class_name)
          next unless k && !k::DATA.empty?
          restore(target, k)
          DP.applied(target, :all => true).map { |p| p[:id] }.uniq.each do |id|
            apply_entry(target, k, id, DP.entry(target, id))
          end
        end
      rescue StandardError => e
        Reloaded::Log.exception("Trainer data patches couldn't be applied", e, :data_patches)
      end

      private

      def trainer_class(name)
        k = DP.resolve(name)
        return k && k.const_defined?(:DATA) && k.respond_to?(:new) ? k : nil
      end

      # Puts the game's own trainers back where a build changed them.
      def restore(target, k)
        Array(@managed[target]).each do |key, number|
          k::DATA.delete(number)
          original = (@originals[target] || {})[key]
          if original
            k::DATA[key] = original
            k::DATA[original.id_number] = original
          else
            k::DATA.delete(key)
          end
        end
        @managed[target] = []
      end

      def apply_entry(target, k, id, raw)
        @why = nil
        data = build(target, k, id, DP.stringify(raw))
        return DP.reject(target, id, @why) unless data
        owner = k::DATA[data[:id_number]]
        if owner && owner.id != data[:id] && !@managed[target].any? { |_k, n| n == data[:id_number] }
          return DP.reject(target, id, "Number #{data[:id_number]} is #{owner.id.inspect}'s.")
        end
        t = k.new(data)
        t.instance_variable_set(:@kr_data_patch, true)
        k::DATA[data[:id]] = t
        k::DATA[data[:id_number]] = t
        @managed[target] << [data[:id], data[:id_number]]
        return true
      rescue StandardError => e
        return DP.reject(target, id, "It couldn't be made: #{e.class}: #{e.message}.")
      end

      # The game's hash for a patched trainer, or nil (@why says why).
      def build(target, k, id, d)
        parts = id.to_s.split("|", 3)
        d["trainer_type"] = parts[0] if DP.blank?(d["trainer_type"]) && parts.length >= 2
        d["name"] = parts[1] if DP.blank?(d["name"]) && parts.length >= 2
        d["version"] = parts[2].to_i if DP.blank?(d["version"]) && parts.length >= 2
        # the game's own trainers never have these names, so one here is the patch's
        d["items"] = d["bag_items"] if d.key?("bag_items")
        TEXT_ALIASES.each { |a, real| d[real] = d[a] if d.key?(a) }
        type = DP.data_id("GameData::TrainerType", d["trainer_type"])
        return refuse("#{d["trainer_type"].inspect} isn't a trainer type.") unless !DP.blank?(d["trainer_type"]) && DP.known?("GameData::TrainerType", type)
        name = DP.blank?(d["name"]) ? "Unnamed" : d["name"].to_s
        party = []
        Array(d["pokemon"]).each_with_index do |m, i|
          pkmn = pokemon(m, nil, "pokemon #{i + 1}")
          return nil unless pkmn
          party << pkmn
        end
        Array(d["replace_pokemon"]).each do |r|
          r = DP.stringify(r)
          slot = r["slot"]
          return refuse("replace_pokemon names slot #{slot.inspect}; the party has #{party.length}.") unless slot.to_s =~ /\A\d+\z/ && slot.to_i < party.length
          pkmn = pokemon(r["data"] || r["pokemon"] || r, nil, "replace_pokemon slot #{slot}")
          return nil unless pkmn
          party[slot.to_i] = pkmn
        end
        Array(d["edit_pokemon"]).each do |r|
          r = DP.stringify(r)
          slot = r["slot"]
          return refuse("edit_pokemon names slot #{slot.inspect}; the party has #{party.length} (add_pokemon adds one).") unless slot.to_s =~ /\A\d+\z/ && slot.to_i < party.length
          pkmn = pokemon(r["data"] || r["pokemon"] || r, party[slot.to_i], "edit_pokemon slot #{slot}")
          return nil unless pkmn
          party[slot.to_i] = pkmn
        end
        max = defined?(::Settings::MAX_PARTY_SIZE) ? ::Settings::MAX_PARTY_SIZE : 6
        Array(d["add_pokemon"]).each_with_index do |m, i|
          return refuse("add_pokemon would make the party bigger than #{max}.") if party.length >= max
          pkmn = pokemon(m, nil, "add_pokemon #{i + 1}")
          return nil unless pkmn
          party << pkmn
        end
        return refuse("The party is empty.") if party.empty?
        items = []
        Array(d["items"]).each do |it|
          item = DP.data_id("GameData::Item", it)
          return refuse("Its bag item #{it.inspect} isn't an item.") unless DP.known?("GameData::Item", item)
          items << item
        end
        number = DP.blank?(d["id_number"]) ? next_number(k) : d["id_number"].to_i
        out = { :id => [type, name, d["version"].to_i], :id_number => number, :trainer_type => type, :name => name,
                :version => d["version"].to_i, :items => items, :pokemon => party,
                :lose_text => DP.blank?(d["lose_text"]) ? "..." : d["lose_text"].to_s }
        TEXTS.each { |f| out[f.to_sym] = DP.blank?(d[f]) ? nil : d[f].to_s }
        return out
      end

      # A party member as the game keeps it, or nil (@why says why).
      def pokemon(value, base, where)
        raw = DP.stringify(value)
        d = DP.stringify(base)
        POKEMON_FIELDS.each { |f| d[f] = raw[f] if raw.key?(f) }
        d["item"] = d["held_item"] if DP.blank?(d["item"]) && !DP.blank?(d["held_item"])
        return refuse("#{where} has no species.") if DP.blank?(d["species"])
        species = DP.data_id("GameData::Species", d["species"])
        return refuse("#{where}: #{d["species"].inspect} isn't a Pokémon (fusions are B<body>H<head>).") unless DP.species?(species)
        level = DP.blank?(d["level"]) ? 1 : d["level"].to_i
        return refuse("#{where}: level #{d["level"].inspect} isn't 1 or more.") if level <= 0
        out = { :species => species, :level => level }
        out[:form] = d["form"].to_i unless DP.blank?(d["form"])
        out[:name] = d["name"].to_s unless DP.blank?(d["name"])
        %w[moves moves_hard moves_easy].each do |f|
          next unless d.key?(f)
          moves = []
          Array(d[f]).each do |mv|
            move = DP.data_id("GameData::Move", mv)
            return refuse("#{where}: #{mv.inspect} isn't a move.") unless DP.known?("GameData::Move", move)
            moves << move
          end
          out[f.to_sym] = moves
        end
        { "ability" => "GameData::Ability", "item" => "GameData::Item", "nature" => "GameData::Nature" }.each do |f, cls|
          next if DP.blank?(d[f])
          v = DP.data_id(cls, d[f])
          return refuse("#{where}: #{d[f].inspect} isn't a#{f == "item" ? "n" : ""} #{f}.") unless DP.known?(cls, v)
          out[f.to_sym] = v
        end
        out[:ability_index] = d["ability_index"].to_i unless DP.blank?(d["ability_index"])
        out[:gender] = gender(d["gender"]) unless DP.blank?(d["gender"])
        out[:iv] = stats(d["iv"]) if d["iv"].is_a?(Hash)
        out[:ev] = stats(d["ev"]) if d["ev"].is_a?(Hash)
        out[:happiness] = d["happiness"].to_i unless DP.blank?(d["happiness"])
        out[:shininess] = truthy?(d["shininess"]) unless DP.blank?(d["shininess"])
        out[:shadowness] = truthy?(d["shadowness"]) unless DP.blank?(d["shadowness"])
        out[:poke_ball] = d["poke_ball"].to_s unless DP.blank?(d["poke_ball"])
        return out
      end

      def refuse(why)
        @why = why
        return nil
      end

      def to_hash(t)
        out = { "id" => entry_id(t.trainer_type, t.real_name, t.version), "id_number" => t.id_number,
                "trainer_type" => t.trainer_type.to_s, "name" => t.real_name.to_s, "version" => t.version.to_i,
                "items" => Array(t.items).map(&:to_s), "lose_text" => t.real_lose_text.to_s,
                "pokemon" => Array(t.pokemon).map { |m| member_hash(m) } }
        TEXTS.each { |f| out[f] = t.instance_variable_get(:"@#{f}") }
        return out
      end

      def member_hash(m)
        out = {}
        return out unless m.is_a?(Hash)
        POKEMON_FIELDS.each do |f|
          next unless m.key?(f.to_sym)
          v = m[f.to_sym]
          v = v.each_with_object({}) { |(k, x), h| h[k.to_s] = x } if v.is_a?(Hash)
          out[f] = v.is_a?(Symbol) ? v.to_s : (v.is_a?(Array) ? v.map { |x| x.is_a?(Symbol) ? x.to_s : x } : v)
        end
        return out
      end

      # "LEADER_Brock|Brock|0": the type as the game writes it (KIF's are mixed case)
      def entry_id(type, name, version)
        return "#{type}|#{name}|#{version.to_i}"
      end

      def next_number(k)
        n = (k::DATA.keys.select { |x| x.is_a?(Integer) }.max || 0) + 1
        n += 1 while k::DATA.key?(n)
        return n
      end

      # { "HP" => 31, "speed" => 31 } as the game's stat ids
      def stats(value)
        ids = []
        ::GameData::Stat.each_main { |s| ids << s.id } if defined?(::GameData::Stat)
        ids = [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED] if ids.empty?
        raw = DP.stringify(value).each_with_object({}) { |(k, v), h| h[k.upcase] = v }
        return ids.each_with_object({}) { |s, h| h[s] = [raw[s.to_s].to_i, 0].max if raw.key?(s.to_s) }
      end

      def gender(value)
        v = value.to_s.strip.downcase
        return 0 if ["m", "male", "0"].include?(v)
        return 1 if ["f", "female", "1"].include?(v)
        return value.to_i
      end

      def truthy?(value)
        return value if value == true || value == false
        return ["true", "yes", "on", "1"].include?(value.to_s.strip.downcase)
      end
    end
  end
end
