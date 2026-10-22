#==============================================================================
# Kanto Reloaded: Data Patches for Pokémon (species)
#==============================================================================
# Four targets change Pokémon the game has (new Pokémon come with Expanded
# Dex). An entry's id is the Pokémon's symbol, in any case ("PIKACHU",
# "pikachu").
#
#   species.core        name, form_name, category, pokedex_entry,
#                       pokedex_form, type1, type2, base_stats, evs (a stat
#                       object: only the stats named change), base_exp,
#                       growth_rate, gender_ratio, catch_rate, happiness,
#                       wild_item_common/_uncommon/_rare, egg_groups,
#                       hatch_steps, incense, height, weight, color, shape,
#                       habitat, generation
#   species.learnsets   moves ([[level, MOVE], ...] or { "level", "move" }),
#                       tutor_moves, egg_moves; or add_moves, add_tutor_moves,
#                       add_egg_moves to add to the Pokémon's own
#   species.evolutions  evolutions ([[SPECIES, Method, parameter], ...] or
#                       { "species", "method", "parameter" }); or
#                       add_evolutions
#   species.abilities   abilities, hidden_abilities
#
# The changes go straight into the game's Pokémon; the values they replace
# are kept and put back before every build. KIF's own changes come first
# (Species Tweaks), its randomizer's on top when a save loads. A fusion's
# name is built from its parts' names in KIF's name table, so a new name
# shows for the Pokémon itself, not in fusion names.
#==============================================================================

module Reloaded
  module DataPatchSpecies
    TARGETS = {
      "species.core"       => %w[name form_name category pokedex_entry pokedex_form type1 type2 base_stats evs base_exp
                                 growth_rate gender_ratio catch_rate happiness wild_item_common wild_item_uncommon
                                 wild_item_rare egg_groups hatch_steps incense height weight color shape habitat generation],
      "species.learnsets"  => %w[moves tutor_moves egg_moves],
      "species.evolutions" => %w[evolutions],
      "species.abilities"  => %w[abilities hidden_abilities]
    }.freeze
    # a field and the instance variable it lives in
    IVARS = { "name" => :@real_name, "form_name" => :@real_form_name, "category" => :@real_category,
              "pokedex_entry" => :@real_pokedex_entry }.freeze
    TEXT = [:name, :form_name, :category, :pokedex_entry].freeze
    ITEM_FIELDS = %w[wild_item_common wild_item_uncommon wild_item_rare incense].freeze
    LOOKUPS = { "type1" => "GameData::Type", "type2" => "GameData::Type", "growth_rate" => "GameData::GrowthRate",
                "gender_ratio" => "GameData::GenderRatio", "color" => "GameData::BodyColor",
                "shape" => "GameData::BodyShape", "habitat" => "GameData::Habitat" }.freeze
    DP = Reloaded::DataPatches

    @kept = {}           # species symbol => { ivar => the game's value }

    class << self
      def install
        mod = Module.new do
          TEXT.each do |m|
            define_method(m) do |*args|
              return instance_variable_get(:"@real_#{m}") if @kr_data_patch_text
              super(*args)
            end
          end
        end
        Reloaded::Hooks.prepend(nil, "GameData::Species", mod, :id => :data_patch_species_text) if DP.resolve("GameData::Species")
        Reloaded::Events.on(:game_data_loaded, :data_patch_species_base, 50) { register_targets }
        Reloaded::Events.on(:data_patches_apply, :data_patch_species_apply, 100) { apply_all }
        return true
      end

      def register_targets
        k = DP.resolve("GameData::Species")
        return unless k && k.const_defined?(:DATA)
        restore
        bases = Hash.new { |h, t| h[t] = {} }
        k::DATA.each do |key, sp|
          next unless key.is_a?(Symbol) && sp.is_a?(k)
          id = key.to_s
          bases["species.core"][id] = core_hash(sp)
          bases["species.learnsets"][id] = { "moves" => Array(sp.moves).map { |lv, mv| [lv, mv.to_s] },
                                             "tutor_moves" => Array(sp.tutor_moves).map(&:to_s),
                                             "egg_moves" => Array(sp.egg_moves).map(&:to_s) }
          bases["species.evolutions"][id] = { "evolutions" => Array(sp.evolutions).reject { |e| e[3] }.map { |e| [e[0].to_s, e[1].to_s, e[2].is_a?(Symbol) ? e[2].to_s : e[2]] } }
          bases["species.abilities"][id] = { "abilities" => Array(sp.abilities).map(&:to_s),
                                             "hidden_abilities" => Array(sp.hidden_abilities).map(&:to_s) }
        end
        TARGETS.each_key do |t|
          DP.register_target(t, bases[t], :description => "GameData::Species", :defer_missing_entries => true, :symbol_ids => true)
        end
      end

      def apply_all
        k = DP.resolve("GameData::Species")
        return unless k && k.const_defined?(:DATA) && !k::DATA.empty?
        restore
        evolutions = false
        TARGETS.each_key do |t|
          DP.applied(t, :all => true).map { |p| p[:id] }.uniq.each do |id|
            sp = k::DATA[id.to_sym]
            unless sp.is_a?(k)
              DP.reject(t, id, "The game has no #{id}. Species patches change Pokémon the game has (new ones come with Expanded Dex).")
              next
            end
            why = apply_entry(t, sp, DP.stringify(DP.entry(t, id)))
            if why
              DP.reject(t, id, why)
            elsif t == "species.evolutions"
              evolutions = true
            end
          end
        end
        rebuild_prevolutions if evolutions || @prevolutions_changed
        @prevolutions_changed = evolutions
        ::KIF::Perf.bump_token if defined?(::KIF::Perf) && ::KIF::Perf.respond_to?(:bump_token)
      rescue StandardError => e
        Reloaded::Log.exception("Species data patches couldn't be applied", e, :data_patches)
      end

      private

      # Puts back the values a build changed.
      def restore
        k = DP.resolve("GameData::Species")
        return unless k && k.const_defined?(:DATA)
        @kept.each do |sym, vars|
          sp = k::DATA[sym]
          next unless sp
          vars.each { |iv, v| sp.instance_variable_set(iv, v) }
          sp.instance_variable_set(:@kr_data_patch_text, false)
        end
        @kept = {}
      end

      # Sets one patched entry on the Pokémon; returns why it can't, or nil.
      def apply_entry(target, sp, d)
        changes = case target
                  when "species.core" then core_changes(sp, d)
                  when "species.learnsets" then learnset_changes(sp, d)
                  when "species.evolutions" then evolution_changes(sp, d)
                  else ability_changes(d)
                  end
        return changes if changes.is_a?(String)
        kept = (@kept[sp.id] ||= {})
        changes.each do |iv, v|
          kept[iv] = sp.instance_variable_get(iv) unless kept.key?(iv)
          sp.instance_variable_set(iv, v)
        end
        if target == "species.core" && IVARS.any? { |f, iv| d.key?(f) && kept.key?(iv) && kept[iv] != d[f] }
          sp.instance_variable_set(:@kr_data_patch_text, true)      # its own text, not the game's translation
        end
        return nil
      end

      # { ivar => value }, or why not
      def core_changes(sp, d)
        out = {}
        TARGETS["species.core"].each do |f|
          next unless d.key?(f)
          v = d[f]
          iv = IVARS[f] || :"@#{f}"
          case f
          when "base_stats", "evs"
            return "#{f} is a stat object ({ \"HP\": 45, ... })." unless v.is_a?(Hash)
            stats = stat_hash(v, f == "base_stats" ? 1 : 0)
            return stats if stats.is_a?(String)
            out[iv] = (sp.instance_variable_get(iv) || {}).merge(stats)      # the stats not named stay
          when "egg_groups"
            groups = Array(v).map { |g| DP.data_id("GameData::EggGroup", g) }
            bad = groups.find { |g| !DP.known?("GameData::EggGroup", g) }
            return "#{bad} isn't an egg group." if bad
            out[iv] = groups.empty? ? [:Undiscovered] : groups
          when *ITEM_FIELDS
            if DP.blank?(v)
              out[iv] = nil
            else
              item = DP.data_id("GameData::Item", v)
              return "#{f}: #{v.inspect} isn't an item." unless DP.known?("GameData::Item", item)
              out[iv] = item
            end
          when *LOOKUPS.keys
            id = DP.data_id(LOOKUPS[f], v)
            return "#{f}: #{v.inspect} isn't one the game has." unless DP.known?(LOOKUPS[f], id)
            out[iv] = id
          when "height", "weight"          # tenths of a metre / kilogram, whole numbers as the game keeps them
            out[iv] = v.to_f.round
          when "name", "form_name", "category", "pokedex_entry"
            out[iv] = v.nil? ? nil : v.to_s
          else
            out[iv] = v.to_i
          end
        end
        return out
      end

      # The Pokémon's stats with the ones named changed, or why not.
      def stat_hash(v, minimum)
        ids = stat_ids
        raw = DP.stringify(v).each_with_object({}) { |(k, x), h| h[k.upcase] = x }
        bad = raw.keys.find { |k| !ids.map(&:to_s).include?(k) }
        return "#{bad} isn't a stat (#{ids.join(", ")})." if bad
        out = {}
        ids.each do |s|
          x = raw[s.to_s]
          return "#{s} is #{x.inspect}; stats are whole numbers." if x && x.to_s !~ /\A-?\d+\z/
          out[s] = [x.to_i, minimum].max if x
        end
        return out
      end

      def learnset_changes(sp, d)
        out = {}
        moves = d.key?("moves") ? level_moves(d["moves"]) : Array(sp.moves).map(&:dup)
        return moves if moves.is_a?(String)
        add = level_moves(d["add_moves"])
        return add if add.is_a?(String)
        add.each { |e| moves << e unless moves.include?(e) }
        out[:@moves] = moves.each_with_index.sort_by { |(lv, _m), i| [lv, i] }.map(&:first) if d.key?("moves") || !add.empty?
        { "tutor_moves" => :@tutor_moves, "egg_moves" => :@egg_moves }.each do |f, iv|
          next unless d.key?(f) || d.key?("add_#{f}")
          list = d.key?(f) ? move_list(d[f]) : Array(sp.instance_variable_get(iv)).dup
          return list if list.is_a?(String)
          extra = move_list(d["add_#{f}"])
          return extra if extra.is_a?(String)
          extra.each { |m| list << m unless list.include?(m) }
          out[iv] = list
        end
        return out
      end

      def level_moves(value)
        out = []
        Array(value).each do |e|
          lv, mv = e.is_a?(Hash) ? [DP.stringify(e)["level"], DP.stringify(e)["move"] || DP.stringify(e)["id"]] : Array(e)
          next if DP.blank?(mv)
          move = DP.data_id("GameData::Move", mv)
          return "#{mv.inspect} isn't a move." unless DP.known?("GameData::Move", move)
          out << [DP.blank?(lv) ? 1 : lv.to_i, move]
        end
        return out
      end

      def move_list(value)
        out = []
        Array(value).each do |mv|
          move = DP.data_id("GameData::Move", mv)
          return "#{mv.inspect} isn't a move." unless DP.known?("GameData::Move", move)
          out << move
        end
        return out
      end

      def evolution_changes(sp, d)
        list = d.key?("evolutions") ? evolutions(d["evolutions"]) : Array(sp.evolutions).reject { |e| e[3] }.map(&:dup)
        return list if list.is_a?(String)
        extra = evolutions(d["add_evolutions"])
        return extra if extra.is_a?(String)
        extra.each { |e| list << e unless list.include?(e) }
        return { :@evolutions => list }
      end

      def evolutions(value)
        out = []
        Array(value).each do |e|
          if e.is_a?(Hash)
            h = DP.stringify(e)
            target, method, param = h["species"] || h["id"] || h["target"], h["method"] || h["type"], h.key?("parameter") ? h["parameter"] : h["param"]
          else
            target, method, param = Array(e)
          end
          return "An evolution needs a species and a method." if DP.blank?(target) || DP.blank?(method)
          into = DP.data_id("GameData::Species", target)
          return "#{target.inspect} isn't a Pokémon." unless DP.species?(into)
          how = DP.data_id("GameData::Evolution", method)
          return "#{method.inspect} isn't an evolution method." unless DP.known?("GameData::Evolution", how)
          out << [into, how, parameter(how, param), false]
        end
        return out
      end

      # The parameter as the method wants it: a number, an item, a move...
      def parameter(how, value)
        return nil if DP.blank?(value)
        kind = (::GameData::Evolution.get(how).parameter rescue nil)
        return value.to_i if kind == Integer || (kind.nil? && value.to_s =~ /\A-?\d+\z/)
        cls = { :Item => "GameData::Item", :Move => "GameData::Move", :Species => "GameData::Species", :Type => "GameData::Type" }[kind]
        return cls ? DP.data_id(cls, value) : DP.symbol(value)
      end

      def ability_changes(d)
        out = {}
        { "abilities" => :@abilities, "hidden_abilities" => :@hidden_abilities }.each do |f, iv|
          next unless d.key?(f)
          list = Array(d[f]).map { |a| DP.data_id("GameData::Ability", a) }
          bad = list.find { |a| !DP.known?("GameData::Ability", a) }
          return "#{bad} isn't an ability." if bad
          out[iv] = list
        end
        return out
      end

      # Evolutions also list where each Pokémon evolves from (a 4th true);
      # after evolutions change, those are worked out again for all.
      def rebuild_prevolutions
        k = DP.resolve("GameData::Species")
        all = k::DATA.select { |key, sp| key.is_a?(Symbol) && sp.is_a?(k) }.values   # DATA also has each one by number
        from = {}
        all.each do |sp|
          own = Array(sp.evolutions).reject { |e| e[3] }
          sp.instance_variable_set(:@evolutions, own)
          own.each { |e| from[e[0]] ||= [sp.species, e[1], e[2], true] }
        end
        all.each do |sp|
          pre = from[sp.species]
          sp.evolutions.push(pre.clone) if pre
        end
      rescue StandardError => e
        Reloaded::Log.exception("Evolutions' prevolutions couldn't be rebuilt", e, :data_patches)
      end

      def core_hash(sp)
        out = {}
        TARGETS["species.core"].each do |f|
          v = sp.instance_variable_get(IVARS[f] || :"@#{f}")
          v = v.each_with_object({}) { |(s, x), h| h[s.to_s] = x } if v.is_a?(Hash)
          v = v.map { |x| x.is_a?(Symbol) ? x.to_s : x } if v.is_a?(Array)
          out[f] = v.is_a?(Symbol) ? v.to_s : v
        end
        return out
      end

      def stat_ids
        ids = []
        ::GameData::Stat.each_main { |s| ids << s.id } if defined?(::GameData::Stat)
        return ids.empty? ? [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED] : ids
      end
    end
  end
end
