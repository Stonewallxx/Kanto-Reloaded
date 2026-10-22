#==============================================================================
# Kanto Reloaded: Data Patches for items, moves, abilities and trainer types
#==============================================================================
# The targets backed by one of the game's GameData tables (Table.rb):
#
#   items          GameData::Item          name, name_plural, pocket, price,
#                                          description, field_use, battle_use,
#                                          type, move
#   moves          GameData::Move          name, function_code, base_damage,
#                                          type, category, accuracy, total_pp,
#                                          effect_chance, target, priority,
#                                          flags, description
#   abilities      GameData::Ability       name, description
#   trainer_types  GameData::TrainerType   name, base_money, battle_BGM,
#                                          victory_ME, intro_ME, gender,
#                                          skill_level, skill_code
#
# An entry's id is its symbol (POTION, TACKLE); a new one gets the next free
# number unless the patch gives id_number. A patched entry shows its own name
# and description.
#==============================================================================

module Reloaded
  #----------------------------------------------------------------------------
  # Items
  #----------------------------------------------------------------------------
  module DataPatchItems
    extend Reloaded::DataPatches::Table
    TARGET = "items".freeze
    GAME_CLASS = "GameData::Item".freeze
    TEXT = [:name, :name_plural, :description].freeze
    DP = Reloaded::DataPatches

    def self.to_hash(i)
      return { "id" => i.id.to_s, "id_number" => i.id_number, "name" => i.real_name, "name_plural" => i.real_name_plural,
               "pocket" => i.pocket, "price" => i.price, "description" => i.real_description, "field_use" => i.field_use,
               "battle_use" => i.battle_use, "type" => i.type, "move" => i.move ? i.move.to_s : nil }
    end

    def self.build(id, raw, base)
      d = base.merge(raw)
      name = DP.blank?(d["name"]) ? DP.symbol(id).to_s : d["name"].to_s
      return { :id => DP.symbol(d["id"] || id), :id_number => DP.blank?(d["id_number"]) ? next_number : d["id_number"].to_i,
               :name => name, :name_plural => DP.blank?(d["name_plural"]) ? name : d["name_plural"].to_s,
               :pocket => DP.blank?(d["pocket"]) ? 1 : d["pocket"].to_i, :price => d["price"].to_i,
               :description => DP.blank?(d["description"]) ? "???" : d["description"].to_s,
               :field_use => d["field_use"].to_i, :battle_use => d["battle_use"].to_i, :type => d["type"].to_i,
               :move => DP.blank?(d["move"]) ? nil : DP.data_id("GameData::Move", d["move"]) }
    end

    def self.check(d)
      return "#{d[:id]} has no number above 0." unless d[:id_number].is_a?(Integer) && d[:id_number] > 0
      return "#{d[:id]} teaches #{d[:move]}, and there's no such move." if d[:move] && !DP.known?("GameData::Move", d[:move])
      return nil
    end
  end

  #----------------------------------------------------------------------------
  # Moves
  #----------------------------------------------------------------------------
  module DataPatchMoves
    extend Reloaded::DataPatches::Table
    TARGET = "moves".freeze
    GAME_CLASS = "GameData::Move".freeze
    TEXT = [:name, :description].freeze
    NUMBER_KEYS = false                   # KIF's moves are found by symbol only
    CONTEST = %w[contest_type contest_hearts contest_jam contest_function_code contest_flags contest_description].freeze
    CATEGORIES = { "physical" => 0, "special" => 1, "status" => 2 }.freeze
    DP = Reloaded::DataPatches

    def self.to_hash(m)
      return { "id" => m.id.to_s, "id_number" => m.id_number, "name" => m.real_name, "function_code" => m.function_code,
               "base_damage" => m.base_damage, "type" => m.type ? m.type.to_s : nil, "category" => m.category,
               "accuracy" => m.accuracy, "total_pp" => m.total_pp, "effect_chance" => m.effect_chance,
               "target" => m.target ? m.target.to_s : nil, "priority" => m.priority, "flags" => m.flags,
               "description" => m.real_description }.merge(contest_of(m))
    end

    # PIF's contest data on a move (kept when a patch changes the move).
    def self.contest_of(m)
      out = {}
      CONTEST.each { |f| out[f] = m.instance_variable_get(:"@#{f}") if m.instance_variable_defined?(:"@#{f}") }
      return out
    end

    def self.build(id, raw, base)
      d = base.merge(raw)
      power = DP.blank?(d["base_damage"]) ? 0 : d["base_damage"].to_i
      category = d["category"]
      category = if DP.blank?(category) then power == 0 ? 2 : 0
                 elsif category.to_s =~ /\A-?\d+\z/ then category.to_i
                 else CATEGORIES[category.to_s.strip.downcase] || -1
                 end
      return { :id => DP.symbol(d["id"] || id), :id_number => DP.blank?(d["id_number"]) ? next_number : d["id_number"].to_i,
               :name => DP.blank?(d["name"]) ? DP.symbol(id).to_s : d["name"].to_s,
               :function_code => DP.blank?(d["function_code"]) ? "000" : d["function_code"].to_s.strip.upcase,
               :base_damage => power, :type => DP.symbol(DP.blank?(d["type"]) ? "NORMAL" : d["type"]), :category => category,
               :accuracy => DP.blank?(d["accuracy"]) ? 100 : d["accuracy"].to_i,
               :total_pp => DP.blank?(d["total_pp"]) ? 5 : d["total_pp"].to_i,
               :effect_chance => d["effect_chance"].to_i,
               :target => DP.data_id("GameData::Target", d["target"], :NearOther),
               :priority => d["priority"].to_i, :flags => d["flags"].to_s,
               :description => DP.blank?(d["description"]) ? "???" : d["description"].to_s
             }.merge(contest(d))
    end

    # PIF's contest fields as its move data keeps them: the type and function
    # as symbols ("cool" => its ContestType), hearts and jam as numbers.
    def self.contest(d)
      out = {}
      CONTEST.each do |f|
        next unless d.key?(f) && !d[f].nil?
        v = d[f]
        out[f.to_sym] = case f
                        when "contest_type" then DP.data_id("GameData::ContestType", v)
                        when "contest_function_code" then DP.data_id("GameData::ContestMoveFunction", v)
                        when "contest_hearts", "contest_jam" then v.to_i
                        when "contest_flags" then Array(v).map(&:to_s)
                        else v.to_s
                        end
      end
      return out
    end

    def self.check(d)
      return "#{d[:id]} has no number above 0." unless d[:id_number].is_a?(Integer) && d[:id_number] > 0
      return "#{d[:id]}'s type #{d[:type]} isn't a type." unless DP.known?("GameData::Type", d[:type])
      return "#{d[:id]}'s target #{d[:target]} isn't a move target." unless DP.known?("GameData::Target", d[:target])
      return "#{d[:id]}'s category is physical, special or status (0, 1 or 2)." unless [0, 1, 2].include?(d[:category])
      return "#{d[:id]}'s accuracy is 0 to 100." unless d[:accuracy].between?(0, 100)
      return "#{d[:id]} needs PP above 0." unless d[:total_pp] > 0
      return nil
    end
  end

  #----------------------------------------------------------------------------
  # Abilities
  #----------------------------------------------------------------------------
  module DataPatchAbilities
    extend Reloaded::DataPatches::Table
    TARGET = "abilities".freeze
    GAME_CLASS = "GameData::Ability".freeze
    TEXT = [:name, :description].freeze
    DP = Reloaded::DataPatches

    def self.to_hash(a)
      return { "id" => a.id.to_s, "id_number" => a.id_number, "name" => a.real_name, "description" => a.real_description }
    end

    def self.build(id, raw, base)
      d = base.merge(raw)
      return { :id => DP.symbol(d["id"] || id), :id_number => DP.blank?(d["id_number"]) ? next_number : d["id_number"].to_i,
               :name => DP.blank?(d["name"]) ? DP.symbol(id).to_s : d["name"].to_s,
               :description => DP.blank?(d["description"]) ? "???" : d["description"].to_s }
    end

    def self.check(d)
      return "#{d[:id]} has no number above 0." unless d[:id_number].is_a?(Integer) && d[:id_number] > 0
      return nil
    end
  end

  #----------------------------------------------------------------------------
  # Trainer types
  #----------------------------------------------------------------------------
  module DataPatchTrainerTypes
    extend Reloaded::DataPatches::Table
    TARGET = "trainer_types".freeze
    GAME_CLASS = "GameData::TrainerType".freeze
    TEXT = [:name].freeze                 # a new type's class name (KIF looks names up by number)
    DP = Reloaded::DataPatches

    def self.to_hash(t)
      return { "id" => t.id.to_s, "id_number" => t.id_number, "name" => t.real_name, "base_money" => t.base_money,
               "battle_BGM" => t.battle_BGM, "victory_ME" => t.victory_ME, "intro_ME" => t.intro_ME, "gender" => t.gender,
               "skill_level" => t.skill_level, "skill_code" => t.skill_code }
    end

    def self.build(id, raw, base)
      d = base.merge(raw)
      d["base_money"] = raw["money"] if raw.key?("money")
      d["base_money"] = raw["reward_money"] if raw.key?("reward_money")
      # the game's own entries never have these names, so one here is the patch's
      d["skill_level"] = raw["ai_skill_level"] if raw.key?("ai_skill_level")
      d["skill_code"] = raw["ai_flags"] if raw.key?("ai_flags")
      money = DP.blank?(d["base_money"]) ? 30 : d["base_money"].to_i
      code = d["skill_code"].is_a?(Array) ? d["skill_code"].join : d["skill_code"].to_s
      code = code.gsub(/[^A-Za-z0-9_]/, "")
      return { :id => DP.symbol(d["id"] || id), :id_number => DP.blank?(d["id_number"]) ? next_number : d["id_number"].to_i,
               :name => DP.blank?(d["name"]) ? DP.symbol(id).to_s : d["name"].to_s,
               :base_money => money.clamp(0, 999_999),
               :battle_BGM => DP.blank?(d["battle_BGM"]) ? nil : d["battle_BGM"].to_s,
               :victory_ME => DP.blank?(d["victory_ME"]) ? nil : d["victory_ME"].to_s,
               :intro_ME => DP.blank?(d["intro_ME"]) ? nil : d["intro_ME"].to_s,
               :gender => (DP.blank?(d["gender"]) ? 2 : d["gender"].to_i).clamp(0, 2),
               :skill_level => (DP.blank?(d["skill_level"]) ? money : d["skill_level"].to_i).clamp(0, 255),
               :skill_code => code.empty? ? nil : code }
    end

    def self.check(d)
      return "#{d[:id]} has no number above 0." unless d[:id_number].is_a?(Integer) && d[:id_number] > 0
      return nil
    end
  end
end
