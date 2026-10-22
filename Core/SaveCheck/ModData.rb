#==============================================================================
# Kanto Reloaded: mod data in a save
#==============================================================================
# Which mods have something in a save, and whether the save needs each one
# to load:
#
#   - a save value a mod registered (SaveData.register): its owner is the
#     file the registering code came from (Profiler::Owners); a value nothing
#     registers is a mod that's off or gone, found by searching the mod
#     folders for who registers it
#   - objects of a mod's own classes, anywhere in the save (in its own
#     value, or in the game's: an instance variable on the trainer): the game
#     can't read those without the mod, so the mod is Needed to Load. A class
#     the game hasn't got at all (stood in for by the Reader) is found the
#     same way, in the mod folders
#   - what a mod added with Data Patches that the save holds: it becomes
#     Missing Content without the mod
#
# Plain values (numbers, strings, symbols, arrays, hashes, times...) never
# make a mod needed: the game reads them without it.
#
#   Reloaded::SaveCheck::ModData.scan(data) => [ModEntry]
#==============================================================================

module Reloaded
  module SaveCheck
    # name; installed (true, :off, or false); keys (save values it owns);
    # bytes; classes ({ class name => [where] }); added ([[kind, id, count]]
    # it added with Data Patches, in the save); needed (Needed to Load); kr
    ModEntry = Struct.new(:name, :installed, :keys, :bytes, :classes, :added, :needed, :kr)

    module ModData
      KR = "Kanto Reloaded".freeze
      PLAIN = [Array, Hash, String, Symbol, Integer, Float, NilClass, TrueClass, FalseClass, Time].freeze

      @key_owner = {}
      @class_owner = {}

      class << self
        def scan(data)
          mods = {}
          return [] unless data.is_a?(Hash)
          data.each do |key, value|
            owner = key_owner(key)
            next if owner == :game
            m = entry(mods, owner)
            m.keys << key
            m.bytes += (Marshal.dump(value).bytesize rescue 0)
          end
          classes_in(data).each do |name, places|
            owner = class_owner(name)
            next if owner == :game
            m = entry(mods, owner)
            m.classes[name] = places
            m.needed = true
          end
          added_in(data).each { |owner, list| entry(mods, owner).added.concat(list) }
          list = mods.values
          list.each { |m| m.installed = installed?(m.name) }
          return list.sort_by { |m| [m.kr ? 1 : 0, m.needed ? 0 : 1, m.name.to_s] }
        end

        # Who a save value belongs to: :game, "Kanto Reloaded" or a mod's
        # name.
        def key_owner(key)
          return @key_owner[key] if @key_owner.key?(key)
          return @key_owner[key] = KR if key == :reloaded
          value = registered[key]
          owner = if value
                    code = value.instance_variable_get(:@save_proc) || value.instance_variable_get(:@load_proc)
                    owner_of_file((code.source_location[0] rescue nil))
                  else
                    Search.registers(key) || _INTL("Unknown Mod ({1})", key)
                  end
          return @key_owner[key] = owner
        end

        # Who a class belongs to: :game, "Kanto Reloaded" or a mod's name.
        def class_owner(name)
          return @class_owner[name] if @class_owner.key?(name)
          klass = (Object.const_get(name) rescue nil)
          owner = if klass && !Reader.stub?(klass)
                    loc = (Object.const_source_location(name) rescue nil)
                    loc.nil? || loc.empty? || loc[0].to_s.empty? ? :game : owner_of_file(loc[0])
                  else
                    Search.defines(name) || _INTL("Unknown Mod ({1})", name.split("::").first)
                  end
          return @class_owner[name] = owner
        end

        # Forget what was worked out (mods switched, tests).
        def reset
          @key_owner = {}
          @class_owner = {}
          @registered = nil
          Search.reset
        end

        # The game's own Kanto Reloaded / mod owners for a source file.
        def owner_of_file(file)
          return :game if file.nil? || file.to_s.empty?
          # Kanto Reloaded's Tools stand in for the game's classes outside it
          tools = File.join(Reloaded::ROOT, "Tools").tr("\\", "/").downcase
          return :game if file.to_s.tr("\\", "/").downcase.start_with?(tools + "/")
          owners = defined?(Reloaded::Profiler::Owners) ? Reloaded::Profiler::Owners : nil
          return Search.owner_of_path(file) unless owners
          owner = owners.of(file)
          return :game if owners.game?(owner)
          return owner
        end

        # true (loaded), :off (its folder is there, not loaded) or false.
        def installed?(name)
          return true if name == KR
          return true if loaded_names.include?(name.to_s)
          return :off if Search.folder_names.include?(name.to_s)
          return false
        end

        private

        def entry(mods, owner)
          return mods[owner] ||= ModEntry.new(owner, nil, [], 0, {}, [], false, owner == KR)
        end

        # SaveData's registered values, by id.
        def registered
          return @registered if @registered
          values = defined?(::SaveData) ? ::SaveData.instance_variable_get(:@values) : nil
          @registered = {}
          Array(values).each { |v| @registered[v.id] = v if v.respond_to?(:id) }
          return @registered
        end

        def loaded_names
          return [] unless defined?(::KIF::Mods) && ::KIF::Mods.respond_to?(:entries)
          return (::KIF::Mods.entries rescue []).select { |e| (e.enabled? rescue true) }.map { |e| e.name.to_s }
        end

        # { class name => [save values it's in] }, for every object that
        # isn't a plain value.
        def classes_in(data)
          found = {}
          data.each do |key, value|
            SaveCheck.walk(value) do |obj, _path|
              k = obj.class
              next nil if PLAIN.include?(k)
              name = k.name.to_s
              next nil if name.empty?
              list = (found[name] ||= [])
              list << key unless list.include?(key)
              nil
            end
          end
          return found
        end

        # What each mod added with Data Patches that the save holds:
        # { mod name => [[kind, id, count]] }
        def added_in(data)
          return {} unless defined?(Reloaded::DataPatches) && Reloaded::DataPatches.respond_to?(:patches)
          added = Hash.new { |h, k| h[k] = {} }
          targets = { "species" => :pokemon, "items" => :item, "moves" => :move }
          Array(Reloaded::DataPatches.patches).each do |p|
            kind = targets[p[:target].to_s]
            next unless kind
            next unless p[:operation].to_s == "add" || (p[:operation].to_s == "replace" && (Reloaded::DataPatches.new_entry?(p[:target], p[:id]) rescue false))
            added[p[:mod_name].to_s][[kind, p[:id].to_s.upcase]] = true
          end
          return {} if added.empty?
          counts = Content.ids_in(data)
          out = {}
          added.each do |mod, ids|
            list = ids.keys.map { |kind, id| [kind, id, counts[kind][id].to_i] }.select { |_k, _i, n| n > 0 }
            out[mod] = list unless list.empty?
          end
          return out
        end
      end

      #------------------------------------------------------------------------
      # The mod folders, searched for what isn't loaded
      #------------------------------------------------------------------------
      module Search
        DEFINES = /^\s*(?:class|module)\s+(?:::)?([A-Z][\w:]*)/
        ENGINE = %w[Table Color Tone Rect Bitmap Font Viewport Sprite Plane Window Tilemap].freeze   # mkxp-z's own
        REGISTERS = /register\(\s*:(\w+)/

        class << self
          attr_writer :root      # the Mods folder (a test's own)

          def root
            return @root || File.join(Reloaded::Paths.game_dir, "Mods")
          end

          # The mod (its name) whose scripts register a save value, :game
          # when the game's own do (outside the game nothing is registered),
          # or nil.
          def registers(key)
            return :game if game[:keys][key.to_s]
            folder, = mods.find { |_f, ix| ix[:keys][key.to_s] }
            return folder ? mod_name(folder) : nil
          end

          # :game when the game's scripts define the class (or its outer
          # module), else the mod whose scripts do, or nil.
          def defines(name)
            names = [name.to_s, name.to_s.split("::").first.to_s].uniq.reject(&:empty?)
            return :game if names.any? { |n| ENGINE.include?(n) || game[:names][n] }
            folder, = mods.find { |f, ix| !f.casecmp("KantoReloaded").zero? && names.any? { |n| ix[:names][n] } }
            return folder ? mod_name(folder) : nil
          end

          # Every mod folder's name (KIF's Mods list, or the folder's name).
          def folder_names
            return mods.keys.map { |folder| mod_name(folder) }
          end

          def owner_of_path(file)
            parts = file.to_s.tr("\\", "/").split("/")
            i = parts.rindex { |p| p.casecmp("Mods").zero? }
            return :game unless i && parts[i + 1]
            return mod_name(parts[i + 1])
          end

          # The mod folders are read again (mods come and go); the game's
          # own scripts don't change while it runs.
          def reset
            @mods = nil
          end

          private

          # { folder => { :names => {name => true}, :keys => {key => true} } }
          def mods
            return @mods if @mods
            @mods = {}
            return @mods unless File.directory?(root)
            Dir.children(root).sort.each do |folder|
              path = File.join(root, folder)
              next unless File.directory?(path)
              ix = { :names => {}, :keys => {} }
              Dir.glob(File.join(path, "**", "*.rb")).each { |f| index(f, ix) }
              @mods[folder] = ix
            end
            return @mods
          end

          # What the game's own scripts define and register.
          def game
            return @game if @game
            ix = { :names => {}, :keys => {} }
            dir = File.join(Reloaded::Paths.game_dir, "Data", "Scripts")
            Dir.glob(File.join(dir, "**", "*.rb")).each { |f| index(f, ix) } if File.directory?(dir)
            return @game = ix
          end

          def index(file, ix)
            text = (File.read(file, :encoding => "UTF-8") rescue "").scrub
            text.scan(DEFINES) do |(n)|
              ix[:names][n] = true
              ix[:names][n.split("::").first] = true
            end
            text.scan(REGISTERS) { |(k)| ix[:keys][k] = true }
          end

          def mod_name(folder)
            return KR if folder.to_s.casecmp("KantoReloaded").zero?
            return Reloaded::Profiler::Owners.mod_name(folder) if defined?(Reloaded::Profiler::Owners)
            return folder.to_s
          end
        end
      end
    end
  end
end
