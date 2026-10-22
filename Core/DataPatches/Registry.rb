#==============================================================================
# Kanto Reloaded: Data Patches
#==============================================================================
# Mods change the game's data with JSON files instead of replacing its data
# files (Roadmap topic 30; Hoenn Reloaded's Data Patches, ported):
#
#   Mods/<mod>/DataPatches/**/*.json
#
# Each patch names a target ("items", "species.core", "trainers.remix"...),
# an operation, an entry id and data:
#
#   add      a new entry (an error if it's there already)
#   edit     existing fields only (an error if the entry or a field isn't)
#   merge    deep-merged into an existing entry (new fields allowed)
#   replace  the whole entry (items, moves, abilities and trainer types
#            fill fields left out with the game's own; species and
#            encounters change only what's named)
#
# There's no remove. Everything happens in memory after the game loads its
# data (KIF::DataLoad), never in the game's files. A patch that fails a check
# is skipped, not a crash; two mods on the same entry is a conflict that load
# order decides: the order the mods' scripts load in (Mod Manager's mods
# first, in its load order, when it's there; then KIF's folders,
# alphabetical, the mods named in a mod's dependencies and load_after (KIF
# 0.21.59) first).
#
# The registry keeps each target's data as plain hashes; a target's own file
# (Items.rb, Species.rb...) turns them into the game's data when
# :data_patches_apply fires, and reports what it had to refuse (reject), so
# the Patch Viewer can say why in plain words.
#
#   Reloaded::DataPatches.data("items")          a target's data
#   Reloaded::DataPatches.entry("items", "x")    one entry
#   Reloaded::DataPatches.register_target(...)   a target and its base data
#   Reloaded::DataPatches.mods                   the mods, with their patches
#   Reloaded::DataPatches.reload                 again, without a restart
#
# Events: :game_data_loaded (targets refresh their base data),
# :data_patches_apply (the targets make the game's data; theirs only), then
# :data_patches_loaded once everything applied ({ :summary, :patches,
# :errors }, after the targets' own checks).
# The full guide is Documentation/DataPatches.md.
#==============================================================================

module Reloaded
  module DataPatches
    OPERATIONS = ["add", "edit", "merge", "replace"].freeze
    FOLDER = "DataPatches".freeze
    OWN_NAME = "Kanto Reloaded".freeze

    # Each target as players read it (the Patch Viewer, Hot Reload's report,
    # messages), in the order they're listed, and the word for its entries
    # (one, more).
    TARGETS = [
      ["items",                 "Items",                ["item", "items"]],
      ["moves",                 "Moves",                ["move", "moves"]],
      ["abilities",             "Abilities",            ["ability", "abilities"]],
      ["trainer_types",         "Trainer Types",        ["trainer type", "trainer types"]],
      ["species.core",          "Species",              ["species", "species"]],
      ["species.learnsets",     "Learnsets",            ["learnset", "learnsets"]],
      ["species.evolutions",    "Evolutions",           ["species' evolutions", "species' evolutions"]],
      ["species.abilities",     "Species Abilities",    ["species' abilities", "species' abilities"]],
      ["trainers.classic",      "Trainers",             ["trainer", "trainers"]],
      ["trainers.remix",        "Remix Trainers",       ["Remix trainer", "Remix trainers"]],
      ["trainers.expert",       "Expert Trainers",      ["Expert trainer", "Expert trainers"]],
      ["encounters.classic",    "Encounters",           ["map's encounters", "maps' encounters"]],
      ["encounters.remix",      "Remix Encounters",     ["map's Remix encounters", "maps' Remix encounters"]],
      ["encounters.randomized", "Random Encounters",    ["map's randomized encounters", "maps' randomized encounters"]],
      ["outfits.clothes",       "Clothes",              ["outfit", "outfits"]],
      ["outfits.hats",          "Hats",                 ["hat", "hats"]],
      ["outfits.hairstyles",    "Hairstyles",           ["hairstyle", "hairstyles"]]
    ].freeze

    @targets = {}
    @data = {}
    @patches = []
    @internal = []
    @errors = []
    @warnings = []
    @mods = []
    @logged = {}

    class << self
      # Mods to read instead of KIF's list ([{ :id, :name, :folder_path }]),
      # for tests and the Patch Checker.
      attr_accessor :mods_override

      # The targets, in the order they apply: what others refer to first
      # (a trainer's Pokémon can know a patched move).
      TARGET_MODULES = [:DataPatchItems, :DataPatchMoves, :DataPatchAbilities, :DataPatchTrainerTypes,
                        :DataPatchSpecies, :DataPatchTrainers, :DataPatchEncounters, :DataPatchOutfits].freeze

      def boot
        TARGET_MODULES.each do |name|
          next unless Reloaded.const_defined?(name)
          Reloaded::Hooks.guard(nil, :"data_patches_#{name}") { Reloaded.const_get(name).install }
        end
        if defined?(::KIF::DataLoad)
          ::KIF::DataLoad.after_load_all("Kanto Reloaded's Data Patches") { Reloaded::DataPatches.after_game_data_load }
        elsif defined?(::GameData)
          Reloaded::Hooks.around(nil, ::GameData.singleton_class, :load_all, :id => :data_patches_load_all) do |original, *args|
            result = original.call(*args)
            Reloaded::DataPatches.after_game_data_load
            result
          end
        end
        register_settings
        return true
      end

      # Kanto Reloaded > Data Patches > Patch Viewer.
      def register_settings
        s = Reloaded::Settings
        s.register_page(:data_patches, :group => :general, :name => "Data Patches", :icon => :data_patches, :priority => 40,
          :description => "What your mods change in the game's data: Items, moves, species, trainers, encounters and outfits.")
        s.register(:"data_patches.viewer", :page => :data_patches, :type => :button, :priority => 0, :preset => false,
          :name => "Patch Viewer",
          :on_press => proc { Reloaded::PatchViewer.open if defined?(Reloaded::PatchViewer) },
          :description => "Each mod's data patches: What it adds and edits, where two mods change the same thing, and why a patch was rejected.")
      end

      #------------------------------------------------------------------------
      # Targets
      #------------------------------------------------------------------------
      # A target and its base data ({ id => { field => value } }).
      # defer_missing_entries: an edit to an entry that isn't there waits for
      # the target to make it (no error). symbol_ids: ids are the game's
      # symbols, so "potion", "Potion" and "POTION" are the same entry.
      def register_target(target, initial_data = {}, owner: :kanto_reloaded, description: nil,
                          defer_missing_entries: false, symbol_ids: false)
        key = normalize_target(target)
        return nil if key.empty?
        @targets[key] = {
          :target => key, :owner => owner.to_s, :description => description.to_s,
          :defer_missing_entries => !!defer_missing_entries, :symbol_ids => !!symbol_ids,
          :initial_data => deep_dup(initial_data.is_a?(Hash) ? initial_data : {})
        }
        if symbol_ids          # "Super Potion" finds SUPERPOTION
          @targets[key][:loose] = {}
          @targets[key][:initial_data].each_key { |id| @targets[key][:loose][loose(id)] ||= id.to_s }
        end
        @data[key] = deep_dup(@targets[key][:initial_data])
        return key
      rescue StandardError => e
        Reloaded::Log.exception("Data patch target #{target} couldn't be registered", e, :data_patches)
        return nil
      end

      def targets
        return @targets.keys
      end

      # "species.learnsets" => "Learnsets"; a target that isn't listed, as
      # it was written.
      def label(target)
        row = TARGETS.find { |t| t[0] == target.to_s }
        return row ? row[1] : target.to_s
      end

      # "move" / "moves" (count n).
      def noun(target, n)
        row = TARGETS.find { |t| t[0] == target.to_s }
        return n == 1 ? "entry" : "entries" unless row
        return n == 1 ? row[2][0] : row[2][1]
      end

      # Where a target is listed (unlisted ones after).
      def target_rank(target)
        return TARGETS.index { |t| t[0] == target.to_s } || TARGETS.length
      end

      # The entry isn't one the game had (an add, or a replace of nothing).
      def new_entry?(target, id)
        config = @targets[normalize_target(target)]
        return true unless config
        return !config[:initial_data].key?(entry_key(config[:target], id))
      end

      #------------------------------------------------------------------------
      # Building
      #------------------------------------------------------------------------
      # After the game's data loads: targets refresh their base data, then
      # every mod's patches apply.
      def after_game_data_load
        Reloaded::Events.emit(:game_data_loaded)
        rebuild
      end

      # Hot Reload: the patches again, without a restart. Returns how long
      # it took (seconds).
      def reload
        started = Time.now
        @reloading = true
        after_game_data_load
        return Time.now - started
      ensure
        @reloading = false
      end

      # True during Hot Reload (a target refreshes what's on screen).
      def reloading?
        return @reloading ? true : false
      end

      def rebuild(mods = nil)
        reset_runtime
        @timings = Hash.new(0.0)
        @mods = mods || active_mods
        @mods.each { |mod| timed(mod[:name]) { scan_mod(mod) } }
        detect_conflicts
        apply_patches
        # the targets make the game's data (and refuse what fails): Kanto Reloaded's work, for every mod
        timed(OWN_NAME) { Reloaded::Events.emit(:data_patches_apply) }
        log_summary
        @built = true
        Reloaded::Events.emit(:data_patches_loaded, :summary => summary, :patches => patches, :errors => errors)
        return true
      rescue StandardError => e
        Reloaded::Log.exception("Data patches couldn't be built", e, :data_patches)
        return false
      end

      def built?
        return @built ? true : false
      end

      # The mods whose patches apply, in KIF's load order.
      def active_mods
        return Array(@mods_override) if @mods_override
        return [] unless defined?(::KIF::Mods) && ::KIF::Mods.respond_to?(:entries)
        list = ::KIF::Mods.entries.select do |e|
          e.path && File.directory?(e.path.to_s) && (e.enabled? rescue false) && !(e.respond_to?(:blocked) && e.blocked)
        end
        # Mod Manager's mods load first (its loader is one of the loose
        # scripts KIF loads before its folders), in Mod Manager's own order
        mm = list.select { |e| e.id.to_s.start_with?("mm:") }
        order = defined?(::ModManager) && ::ModManager.respond_to?(:load_order) ? Array(::ModManager.load_order).map(&:to_s) : []
        mm = mm.select { |e| order.include?(e.id.to_s.sub(/\Amm:/, "")) } unless order.empty?
        mm = mm.each_with_index.sort_by { |e, i| [order.index(e.id.to_s.sub(/\Amm:/, "")) || order.length, i] }.map(&:first)
        native = (list - mm).select { |e| e.source.respond_to?(:order) }
        ordered = native.empty? ? [] : native.first.source.order(native)
        return (mm + ordered + (list - mm - native)).map do |e|
          json = File.join(e.path.to_s, "mod.json")
          info = File.file?(json) ? (Reloaded::JSON.parse(Reloaded::Paths.read_text(json).to_s) rescue nil) : nil
          id = info.is_a?(Hash) && info["id"] ? info["id"].to_s : e.id.to_s.sub(/\Amm:/, "")
          { :id => id, :name => e.name.to_s, :folder_path => e.path.to_s }
        end
      rescue StandardError => e
        Reloaded::Log.exception("The mods' list for data patches couldn't be read", e, :data_patches)
        return []
      end

      # A patch from code instead of a file (a Kanto Reloaded feature's data,
      # a mod's Reloaded::Abilities.register), hidden from the Patch Viewer
      # unless hidden is false. name: the mod it shows under.
      def register_internal_patch(target, id, data, operation: "add", owner: :kanto_reloaded, name: OWN_NAME, hidden: true)
        mod = { :id => owner.to_s, :name => name.to_s }
        patch = build_patch(mod, "Kanto Reloaded/#{owner}", { "target" => target, "operation" => operation, "id" => id, "data" => data }, 0)
        patch[:key] = "internal:#{owner}:#{patch[:target]}:#{patch[:id]}"
        patch[:internal] = true
        patch[:hidden] = hidden ? true : false
        @internal.reject! { |p| p[:key] == patch[:key] }
        return false unless patch[:errors].empty?
        @internal << patch
        return true
      end

      #------------------------------------------------------------------------
      # Reading
      #------------------------------------------------------------------------
      def data(target = nil)
        return deep_dup(@data) if target.nil?
        return deep_dup(@data[normalize_target(target)] || {})
      end

      def entry(target, id)
        t = normalize_target(target)
        return deep_dup((@data[t] || {})[entry_key(t, id)])
      end

      # Every patch read (hidden ones too when all is true).
      def patches(target = nil, all: false)
        list = target.nil? ? @patches : @patches.select { |p| p[:target] == normalize_target(target) }
        list = list.reject { |p| p[:hidden] } unless all
        return list.map(&:dup)
      end

      # The patches that took effect.
      def applied(target = nil, all: false)
        return patches(target, :all => all).select { |p| p[:applied] && !p[:rejected] }
      end

      def errors
        return @errors.reject { |e| e[:hidden] }.map(&:dup)
      end

      # The last build's time by mod name, in seconds: reading and applying
      # its patches (Kanto Reloaded's also has making the game's data).
      def timings
        return (@timings || {}).dup
      end

      def warnings
        return @warnings.reject { |e| e[:hidden] }.map(&:dup)
      end

      # The mods read last time, in load order: [{ :id, :name, :folder_path }]
      def mods
        return @mods.map(&:dup)
      end

      def summary
        visible = @patches.reject { |p| p[:hidden] }
        return { :targets => @data.keys.length, :patches => visible.length,
                 :applied => visible.count { |p| p[:applied] && !p[:rejected] },
                 :errors => errors.length, :warnings => warnings.length }
      end

      # A target's own check refused what a patch asked for: the patches on
      # that entry are marked rejected, with why (the Patch Viewer shows it).
      def reject(target, id, message)
        t = normalize_target(target)
        i = entry_key(t, id)
        list = @patches.select { |p| p[:target] == t && p[:id] == i && p[:applied] }
        list.each { |p| p[:rejected] = message.to_s }
        add_error(list.last, message, list.last ? nil : "#{t}/#{i}")
        @errors.last[:refused] = true          # a target's own check (rebase checks again)
        return false
      end

      # A target's base changed after the build (KIF made the Randomized
      # tables again): its data is built again on the new base, with its
      # patches; the target then checks and applies them as usual.
      def rebase(target, initial_data)
        key = normalize_target(target)
        config = @targets[key]
        return false unless config
        config[:initial_data] = deep_dup(initial_data.is_a?(Hash) ? initial_data : {})
        @data[key] = deep_dup(config[:initial_data])
        again = @patches.select { |p| p[:target] == key && p[:errors].empty? }
        spots = again.map { |p| [p[:file], p[:index]] }
        @errors.reject! { |e| e[:target] == key && (e[:refused] || spots.include?([e[:file], e[:index]])) }
        again.each do |p|               # each tried again: one that failed may work on the new base, and the other way round
          p[:applied] = false
          p[:rejected] = nil
          p.delete(:deferred)
          apply_patch(p)
        end
        return true
      end

      private

      def reset_runtime
        @data = {}
        @targets.each { |target, config| @data[target] = deep_dup(config[:initial_data]) }
        @patches = @internal.map { |p| deep_dup(p) }
        @errors = []
        @warnings = []
      end

      def scan_mod(mod)
        folder = mod[:folder_path].to_s
        return if folder.empty?
        Dir[File.join(folder, FOLDER, "**", "*.json")].sort.each { |path| read_file(mod, path) }
      end

      def read_file(mod, path)
        parsed = Reloaded::JSON.parse(Reloaded::Paths.read_text(path).to_s)
        entries_in(parsed).each_with_index do |entry, index|
          patch = build_patch(mod, path, entry, index)
          @patches << patch
        end
      rescue StandardError => e
        patch = build_patch(mod, path, {}, 0)
        patch[:errors] = ["The file couldn't be read as JSON: #{e.message}"]
        @patches << patch
      end

      # One patch, a { "target", "patches": [...] } group, or an array.
      def entries_in(parsed)
        return parsed if parsed.is_a?(Array)
        return [{ "errors" => ["A patch file holds an object, an array, or a patches array."] }] unless parsed.is_a?(Hash)
        list = value_of(parsed, "patches")
        return [parsed] unless list.is_a?(Array)
        target = value_of(parsed, "target")
        return list.map do |entry|
          next entry unless entry.is_a?(Hash) && target && !key?(entry, "target")
          entry.merge("target" => target)
        end
      end

      def build_patch(mod, path, entry, index)
        errors = []
        errors.concat(Array(value_of(entry, "errors"))) if entry.is_a?(Hash) && value_of(entry, "errors")
        unless entry.is_a?(Hash)
          errors << "A patch is an object (with target, operation, id and data)."
          entry = {}
        end
        raw_operation = value_of(entry, "operation")
        target = normalize_target(value_of(entry, "target"))
        operation = raw_operation.to_s.strip.downcase
        id = entry_key(target, value_of(entry, "id"))
        data = value_of(entry, "data")
        errors << "It has no target." if target.empty?
        errors << "It has no operation." if operation.empty?
        errors << "\"#{raw_operation}\" isn't an operation (add, edit, merge or replace)." unless operation.empty? || OPERATIONS.include?(operation)
        errors << "It has no id." if id.empty?
        errors << "It has no data." if data.nil?
        errors << "Its data isn't an object." if !data.nil? && !data.is_a?(Hash)
        return {
          :key => "#{mod[:id]}:#{path.to_s.tr("\\", "/")}:#{index}",
          :mod_id => mod[:id].to_s, :mod_name => mod[:name].to_s,
          :target => target, :operation => operation, :id => id,
          :data => deep_dup(data.is_a?(Hash) ? data : {}),
          :file => short_file(mod, path), :index => index,
          :errors => errors, :conflicts => [], :applied => false, :rejected => nil
        }
      end

      # A file as a mod maker knows it: "Mods/<mod>/DataPatches/items.json".
      def short_file(mod, path)
        p = path.to_s.tr("\\", "/")
        i = p.index("/Mods/")
        return i ? p[(i + 1)..-1] : p
      end

      # add/replace twice on one entry: both are errors (nothing applies);
      # edits and merges of one field from two mods: load order decides.
      def detect_conflicts
        @patches.reject { |p| !p[:errors].empty? }.group_by { |p| [p[:target], p[:id]] }.each_value do |list|
          whole = list.select { |p| ["add", "replace"].include?(p[:operation]) }
          if whole.length > 1
            whole.each do |p|
              verb = p[:operation] == "add" ? "adds" : "replaces"
              others = (whole - [p]).map { |o| o[:mod_name] }.uniq - [p[:mod_name]]
              if others.empty?
                p[:errors] << "#{p[:mod_name]} #{verb} #{shown_id(p)} (#{label(p[:target])}) more than once, so none of them applies."
              else
                p[:errors] << "#{others.join(" and ")} also #{verb} #{shown_id(p)} (#{label(p[:target])}), so neither applies."
                p[:conflicts].concat(others)
              end
            end
          end
          # a replace from another mod after an edit: the edit is lost (a
          # later add is refused anyway: the entry's there)
          if whole.length == 1 && whole.first[:operation] == "replace"
            w = whole.first
            list.each do |p|
              next unless ["edit", "merge"].include?(p[:operation]) && p[:mod_id] != w[:mod_id] && @patches.index(w) > @patches.index(p)
              p[:conflicts] << w[:mod_name]
              add_warning(p, "#{w[:mod_name]} replaces #{shown_id(p)} (#{label(p[:target])}) after this, so this change is lost.")
            end
          end
          # the same field from two mods (each field down to its last level;
          # add_ lists add up, so they don't clash)
          fields = {}
          list.each do |p|
            next unless ["edit", "merge"].include?(p[:operation])
            leaves(p[:data]).each { |f| (fields[f] ||= []) << p }
          end
          fields.each do |field, ps|
            next if ps.map { |p| p[:mod_id] }.uniq.length < 2
            winner = ps.last
            ps.each do |p|
              others = (ps - [p]).map { |o| o[:mod_name] }.uniq - [p[:mod_name]]
              next if others.empty?
              p[:conflicts].concat(others)
              text = "#{others.join(" and ")} also change#{others.length == 1 ? "s" : ""} #{shown_id(p)}'s #{field} (#{label(p[:target])}); " \
                     "#{winner[:mod_name]} loads last, so its value is used."
              add_warning(p, text)
            end
          end
          list.each { |p| p[:conflicts].uniq! }
        end
      end

      # An entry as a message names it: the game's name for it ("Potion"),
      # else its id.
      def shown_id(p)
        target = p[:target].to_s.start_with?("species.") ? "species.core" : p[:target]
        entry = (@data[target] || {})[p[:id]]
        name = entry.is_a?(Hash) ? entry["name"] : nil
        return blank?(name) || p[:target].to_s.start_with?("trainers.") ? p[:id].to_s : name.to_s
      end

      def apply_patches
        @patches.each do |p|
          timed(p[:mod_name]) do
            if p[:errors].empty?
              apply_patch(p)
            else
              p[:errors].each { |e| add_error(p, e) }
            end
          end
        end
      end

      # Seconds spent on each mod's patches (the Timing Profiler's Mod Timings).
      def timed(name)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        return yield
      ensure
        @timings[name.to_s] += Process.clock_gettime(Process::CLOCK_MONOTONIC) - started if @timings
      end

      def apply_patch(p)
        unless @targets.key?(p[:target])
          near = @targets.keys.min_by { |t| distance(t, p[:target]) }
          hint = near && distance(near, p[:target]) <= 2 ? "; did you mean \"#{near}\"?" : " (the guide lists them)."
          return add_error(p, "No target is called \"#{p[:target]}\"#{hint}")
        end
        data = (@data[p[:target]] ||= {})
        case p[:operation]
        when "add"
          return add_error(p, "#{shown_id(p)} is already in #{label(p[:target])}, so it can't be added (use edit, merge or replace).") if data.key?(p[:id])
          data[p[:id]] = deep_dup(p[:data])
        when "edit"
          existing = data[p[:id]]
          unless existing.is_a?(Hash)
            return defer(p) if defer?(p)
            return add_error(p, "There's no #{p[:id]} in #{label(p[:target])} to edit.")
          end
          missing = p[:data].keys.reject { |f| existing.key?(f) }
          return add_error(p, "#{shown_id(p)} (#{label(p[:target])}) has no #{missing.join(", ")} to edit (merge adds new fields).") unless missing.empty?
          p[:data].each do |f, v|        # a part of a field (base_stats' SPEED) keeps the rest
            if existing[f].is_a?(Hash) && v.is_a?(Hash)
              deep_merge!(existing[f], v)
            else
              existing[f] = deep_dup(v)
            end
          end
        when "merge"
          existing = data[p[:id]]
          unless existing.is_a?(Hash)
            return defer(p) if defer?(p)
            return add_error(p, "There's no #{p[:id]} in #{label(p[:target])} to merge into.")
          end
          deep_merge!(existing, p[:data])
        when "replace"
          data[p[:id]] = deep_dup(p[:data])
        end
        p[:applied] = true
        return true
      end

      # How many letters apart two words are (a typo is 1 or 2).
      def distance(a, b)
        row = (0..b.length).to_a
        a.each_char.with_index(1) do |ca, i|
          prev = row.dup
          row[0] = i
          b.each_char.with_index(1) do |cb, j|
            row[j] = [prev[j] + 1, row[j - 1] + 1, prev[j - 1] + (ca == cb ? 0 : 1)].min
          end
        end
        return row[b.length]
      end

      def defer?(p)
        config = @targets[p[:target]]
        return config && config[:defer_missing_entries] && config[:initial_data].empty?
      end

      # The target makes the entry itself later: the patch waits, no error.
      def defer(p)
        p[:deferred] = true
        return false
      end

      def add_error(p, message, where = nil)
        entry = { :mod_id => p ? p[:mod_id] : nil, :mod_name => p ? p[:mod_name] : nil, :file => p ? p[:file] : where.to_s,
                  :index => p ? p[:index] : nil, :target => p ? p[:target] : nil, :id => p ? p[:id] : nil,
                  :message => message.to_s, :hidden => p ? p[:hidden] : false }
        @errors << entry
        log_once(:error, "Data patch #{entry[:file]}#{entry[:index] ? ", patch #{entry[:index] + 1}" : ""}: #{entry[:message]}")
        return false
      end

      def add_warning(p, message)
        @warnings << { :mod_id => p[:mod_id], :mod_name => p[:mod_name], :file => p[:file], :index => p[:index],
                       :target => p[:target], :id => p[:id], :message => message.to_s, :hidden => p[:hidden] }
        log_once(:warning, "Data patch #{p[:file]}, patch #{p[:index].to_i + 1}: #{message}")
      end

      # Hot Reload builds again: a message already logged isn't logged twice.
      def log_once(level, message)
        return if @logged[message]
        @logged[message] = true
        level == :error ? Reloaded::Log.error(message, :data_patches) : Reloaded::Log.warning(message, :data_patches)
      end

      def log_summary
        s = summary
        sig = [s, @patches.map { |p| [p[:key], p[:applied]] }]
        return if sig == @last_summary
        @last_summary = sig
        Reloaded::Log.info("Data patches: #{s[:applied]} of #{s[:patches]} applied from #{@mods.length} mod(s), " \
                           "#{s[:warnings]} warning(s), #{s[:errors]} error(s)", :data_patches)
      end

      def normalize_target(value)
        return value.to_s.strip.downcase.gsub(/[^a-z0-9_.:-]+/, "_")
      end

      def normalize_id(value)
        return value.to_s.strip
      end

      # An entry's id as its target keeps it.
      def entry_key(target, id)
        config = @targets[target]
        return normalize_id(id) unless config && config[:symbol_ids] && !blank?(id)
        sym = symbol(id).to_s
        return sym if config[:initial_data].key?(sym)
        return (config[:loose] || {})[loose(id)] || sym
      end

      # "Super Potion", "super-potion" => "superpotion"
      def loose(id)
        return id.to_s.downcase.gsub(/[^a-z0-9]/, "")
      end

      # A patch's fields, down to their last level: "price", "base_stats.SPEED".
      # add_ fields add up, so they're left out.
      def leaves(hash, prefix = nil)
        out = []
        hash.each do |k, v|
          next if k.to_s.start_with?("add_")
          path = prefix ? "#{prefix}.#{k}" : k.to_s
          v.is_a?(Hash) && !v.empty? ? out.concat(leaves(v, path)) : out << path
        end
        return out
      end

      def value_of(hash, key)
        return nil unless hash.is_a?(Hash)
        return hash[key] if hash.key?(key)
        return hash[key.to_sym] if hash.key?(key.to_sym)
        return nil
      end

      def key?(hash, key)
        return hash.is_a?(Hash) && (hash.key?(key) || hash.key?(key.to_sym))
      end

      def deep_dup(value)
        return Marshal.load(Marshal.dump(value))
      rescue StandardError
        return value.is_a?(Hash) ? value.dup : value
      end

      # Into base; inside an add_ field (add_moves, add_types...) lists add
      # up, so two mods' additions both stay.
      def deep_merge!(base, incoming, adding = false)
        incoming.each do |k, v|
          add = adding || k.to_s.start_with?("add_")
          if base[k].is_a?(Hash) && v.is_a?(Hash)
            deep_merge!(base[k], v, add)
          elsif add && base[k].is_a?(Array) && v.is_a?(Array)
            base[k] = base[k] + deep_dup(v)
          else
            base[k] = deep_dup(v)
          end
        end
        return base
      end
    end
  end
end
