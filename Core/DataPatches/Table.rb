#==============================================================================
# Kanto Reloaded: Data Patches on one of the game's data tables
#==============================================================================
# What items, moves and abilities share (Hoenn Reloaded had a copy of it in
# each): a GameData class whose DATA holds each entry under its symbol and
# its number.
#
#   module Reloaded::DataPatchItems
#     extend Reloaded::DataPatches::Table
#     TARGET = "items"
#     GAME_CLASS = "GameData::Item"
#     TEXT = [:name, :name_plural, :description]   # shown from the patch
#     NUMBER_KEYS = true                            # DATA also keyed by number
#     def self.to_hash(item) ... end                # an entry as patch data
#     def self.build(id, raw, base) ... end         # patch data as the game's hash
#     def self.check(data) ... end                  # nil, or why it's refused
#   end
#   Reloaded::DataPatchItems.install
#
# At :game_data_loaded it reads the table as it is (its base, and the game's
# own entries, kept); at :data_patches_apply it puts the game's entries back
# where the last build changed them, then writes every patched entry. Moves
# have no number keys (KIF looks them up by symbol only). An entry a check refuses is rejected in the registry
# (DataPatches.reject), with why. Patched entries keep their own name and
# description: the game would look them up in its message files, which
# don't have them.
#==============================================================================

module Reloaded
  module DataPatches
    module Table
      def install
        @base = {}
        @originals = {}
        @managed = []
        text = self::TEXT
        mod = Module.new do
          text.each do |m|
            define_method(m) do |*args|
              return instance_variable_get(:"@real_#{m}") if @kr_data_patch
              super(*args)
            end
          end
        end
        Reloaded::Hooks.prepend(nil, self::GAME_CLASS, mod, :id => :"data_patch_#{self::TARGET}_text") if game_class
        Reloaded::Events.on(:game_data_loaded, :"data_patch_#{self::TARGET}_base", 50) { register_target }
        Reloaded::Events.on(:data_patches_apply, :"data_patch_#{self::TARGET}_apply", 100) { apply_all }
        return true
      end

      def game_class
        return DataPatches.resolve(self::GAME_CLASS)
      end

      # The table as the game loaded it, before any patch (a rebuild puts the
      # last build's entries back first, so they aren't taken for base data).
      def register_target
        k = game_class
        return unless k && k.const_defined?(:DATA)
        restore
        @base = {}
        @originals = {}
        k::DATA.each do |key, obj|
          next unless key.is_a?(Symbol) && obj.is_a?(k)
          @base[key.to_s] = to_hash(obj)
          @originals[key] = obj
        end
        DataPatches.register_target(self::TARGET, @base, :description => "#{self::GAME_CLASS}::DATA", :symbol_ids => true)
      end

      def number_keys?
        return !const_defined?(:NUMBER_KEYS) || self::NUMBER_KEYS
      end

      def apply_all
        k = game_class
        return unless k && k.const_defined?(:DATA) && !k::DATA.empty?
        restore
        ids = DataPatches.applied(self::TARGET, :all => true).map { |p| p[:id] }.uniq
        ids.each { |id| apply_entry(k, id, DataPatches.entry(self::TARGET, id)) }
      rescue StandardError => e
        Reloaded::Log.exception("#{self::TARGET} data patches couldn't be applied", e, :data_patches)
      end

      # Puts the game's own entries back where the last build changed them.
      def restore
        k = game_class
        return unless k && k.const_defined?(:DATA)
        Array(@managed).each do |sym, number|
          k::DATA.delete(number) if number && number_keys?
          original = (@originals || {})[sym]
          if original
            k::DATA[sym] = original
            k::DATA[original.id_number] = original if number_keys? && original.id_number
          else
            k::DATA.delete(sym)
          end
        end
        @managed = []
      end

      def apply_entry(k, id, raw)
        base = @base[DataPatches.symbol(id).to_s] || {}
        data = build(id, DataPatches.stringify(raw), base)
        why = check(data)
        return DataPatches.reject(self::TARGET, id, why) if why
        number = data[:id_number]
        owner = number_owner(k, number)
        if owner && owner.id != data[:id] && !@managed.any? { |_s, n| n == number }
          return DataPatches.reject(self::TARGET, id, "#{data[:id]} can't use number #{number}: it's #{owner.id}'s.")
        end
        obj = k.new(data)
        obj.instance_variable_set(:@kr_data_patch, true)
        k::DATA[data[:id]] = obj
        k::DATA[number] = obj if number && number_keys?
        @managed << [data[:id], number]
        return true
      rescue StandardError => e
        return DataPatches.reject(self::TARGET, id, "It couldn't be made: #{e.class}: #{e.message}.")
      end

      # The entry that has this number, or nil.
      def number_owner(k, number)
        return nil unless number
        return k::DATA[number] if number_keys?
        return k::DATA.values.find { |o| o.respond_to?(:id_number) && o.id_number == number }
      end

      # The first free number after the table's highest.
      def next_number
        k = game_class
        numbers = k::DATA.values.map { |o| o.respond_to?(:id_number) ? o.id_number.to_i : 0 }
        numbers += k::DATA.keys.select { |x| x.is_a?(Integer) }
        return (numbers.max || 0) + 1
      end
    end

    #--------------------------------------------------------------------------
    # Helpers the targets share
    #--------------------------------------------------------------------------
    class << self
      # A class by name, or nil (asked first, so nothing is raised).
      def resolve(name)
        return name.to_s.split("::").inject(Object) do |scope, part|
          return nil unless scope.is_a?(Module) && scope.const_defined?(part, false)
          scope.const_get(part, false)
        end
      rescue NameError
        return nil
      end

      # "Shadow Claw" / "shadow_claw" => :SHADOW_CLAW
      def symbol(value)
        return value.to_s.strip.upcase.gsub(/[^A-Z0-9_]+/, "_").to_sym
      end

      def stringify(hash)
        return {} unless hash.is_a?(Hash)
        out = {}
        hash.each { |k, v| out[k.to_s] = v }
        return out
      end

      def blank?(value)
        return value.nil? || value.to_s.strip.empty?
      end

      # The table's own id for a value written loosely ("near other" =>
      # :NearOther), or the value as a symbol.
      def data_id(class_name, value, default = nil)
        return default if blank?(value)
        k = resolve(class_name)
        exact = value.is_a?(Symbol) ? value : value.to_s.to_sym
        return exact if k && k.const_defined?(:DATA) && k::DATA.key?(exact)
        loose = value.to_s.downcase.gsub(/[^a-z0-9]/, "")
        if k && k.const_defined?(:DATA)
          found = k::DATA.keys.find { |key| !key.is_a?(Integer) && key.to_s.downcase.gsub(/[^a-z0-9]/, "") == loose }
          return found if found
        end
        return symbol(value)
      end

      # The table has it (a table that isn't there doesn't refuse anything).
      def known?(class_name, value)
        k = resolve(class_name)
        return true unless k && k.const_defined?(:DATA)
        return k::DATA.key?(value)
      end

      # A species the game knows, fusions too (KIF makes those on demand:
      # B<body>H<head>).
      def species?(value)
        return false if blank?(value)
        k = resolve("GameData::Species")
        return true unless k && k.const_defined?(:DATA)
        sym = value.is_a?(Symbol) ? value : value.to_s.to_sym
        return true if k::DATA.key?(sym)
        return false unless sym.to_s =~ /\AB(\d+)H(\d+)\z/
        body = $1.to_i
        head = $2.to_i
        return k::DATA[body].is_a?(k) && k::DATA[head].is_a?(k)     # both parts are Pokémon the game has
      end
    end
  end
end
