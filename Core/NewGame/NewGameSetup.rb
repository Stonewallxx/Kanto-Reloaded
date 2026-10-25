# encoding: utf-8
#==============================================================================
# Kanto Reloaded: New Game Setup (the engine)
#==============================================================================
# His picks (Roadmap topic new-game-setup, 2026-10-25): a new game's choices
# in one screen, in the intro in place of KIF's game mode menu
# (select_game_mode). The screen is UI/NewGameScreen.rb (Design 2, Step
# Strip); this file keeps the run being set up and does the work at Start.
#
#   Game Mode   Classic, Remix, Randomized, Legendary (locked until New
#               Game+, as PIF's menu leaves it out until then)
#   Trainer     name, gender, age (10-17), skin, hair: PIF's form, set the
#               way the form sets them
#   Run Setup   rows from a registry: rows arrive with their features
#               (register_row). Built in: Difficulty, Randomizer, Starters,
#               Starting Money, Autosave, All Per-Save Settings
#   Run Card    the run in short, its Run ID, Start and Save as Preset
#
# The intro's later prompts are skipped once each, by name: the Trainer
# Application Form and Common Events "game difficulty selection", "starter
# set selection" and "Prompt first save" (their choices were made here).
# With Autosave On, PIF's save screen opens once where the first-save
# prompt was. A skip that never comes is logged. Every player gets the
# starter sets (PIF only asked when a save existed).
#
# Share codes (his picks: the run, not you; compressed, with a Run ID):
# "KRN1:" and Base64 of the deflated JSON of what differs from a fresh run:
# the mode, the rows, the Custom starter, the Randomizer's settings code, and
# the per-save settings that differ from their defaults. No trainer, no
# global settings. The Run ID is the JSON's CRC32 (57DA-A91F).
#
# Presets: four built in (Classic, Challenge, Casual, Randomizer Run; each
# with only the rows and settings that exist), and the player's own in KIF's
# preset slots: the slot keeps KIF's per-save settings as KIF does, Kanto
# Reloaded's (:reloaded, as the Presets button does) and the run (:kr_run),
# which KIF's own load skips.
#
# The "Reloaded New Game" switch (Reloaded Systems, On): Off gives PIF's own
# prompts back.
#
#   Reloaded::NewGameSetup.register_row(:iv_boundaries, :name => "IV Boundaries",
#     :kind => :choice, :values => [...], :default => 0, :priority => 25,
#     :apply => proc { |value, plan| ... })
#   Reloaded::NewGameSetup.run       the run this save started with, or nil
#   Events: :new_game_setup_done (:run) after Start
#==============================================================================

module Reloaded
  module NewGameSetup
    TOGGLE = :"systems.new_game"
    SECTION = :new_game
    CODE_PREFIX = "KRN1:"
    CODE_VERSION = 1
    CODE_MAX = 6000                 # characters a pasted code may have
    MODES = ["classic", "remix", "randomized", "legendary"].freeze
    MODE_NAMES = ["Classic", "Remix", "Randomized", "Legendary"].freeze
    MODE_RGB = [[80, 150, 250], [80, 200, 120], [240, 160, 40], [170, 110, 250]].freeze
    MODE_SUBS = ["The Original Game", "Remixed by Players", "Your Rules", "Legends Everywhere"].freeze
    # PIF's game modes (select_game_mode's symbols)
    MODE_SYMBOLS = [:CLASSIC, :REMIX, :RANDOMIZED, :LEGENDARY].freeze
    # PIF's starter sets: [name, its switch, the list's name in Settings]
    STARTER_SETS = [["Kanto", nil, :KANTO_STARTERS], ["Johto", :SWITCH_JOHTO_STARTERS, :JOHTO_STARTERS],
                    ["Hoenn", :SWITCH_HOENN_STARTERS, :HOENN_STARTERS], ["Sinnoh", :SWITCH_SINNOH_STARTERS, :SINNOH_STARTERS],
                    ["Kalos", :SWITCH_KALOS_STARTERS, :KALOS_STARTERS], ["Mixed", :SWITCH_MIXED_STARTERS, nil],
                    ["Custom", :SWITCH_CUSTOM_STARTERS, nil]].freeze
    MIXED = 5
    CUSTOM = 6
    MONEY_STEP = 1000
    MONEY_MAX = 100_000
    AGES = (10..17).freeze          # PIF's form (variable 99 drives events)
    HAIR_NAMES = ["Blonde", "Light Brown", "Dark Brown", "Black"].freeze
    SKIN_NAMES = ["Type A", "Type B", "Type C", "Type D", "Type E", "Type F"].freeze
    # The intro's prompts it answers, by Common Event name
    PROMPTS = { "game difficulty selection" => :difficulty, "starter set selection" => :starters,
                "Prompt first save" => :first_save }.freeze
    # PIF's switches and variables, if its names aren't there
    IDS = { :SWITCH_MODERN_MODE => 974, :SWITCH_LEGENDARY_MODE => 1129, :SWITCH_RANDOMIZED_MODE_INTRO => 957,
            :SWITCH_GAME_DIFFICULTY_EASY => 665, :SWITCH_GAME_DIFFICULTY_HARD => 666,
            :SWITCH_JOHTO_STARTERS => 884, :SWITCH_HOENN_STARTERS => 885, :SWITCH_SINNOH_STARTERS => 886,
            :SWITCH_KALOS_STARTERS => 888, :SWITCH_MIXED_STARTERS => 889, :SWITCH_CUSTOM_STARTERS => 883,
            :VAR_TRAINER_GENDER => 52, :VAR_TRAINER_AGE => 99, :VAR_PLAYER_STARTER_CHOICE => 7,
            :VAR_RIVAL_STARTER_HEAD_CHOICE => 212, :VAR_RIVAL_STARTER_BODY_CHOICE => 213,
            :AUTOSAVE_ENABLED_SWITCH => 48, :AUTOSAVE_HEALING_VAR => 24 }.freeze
    # KIF settings' names, for what a code or preset changes
    KIF_NAMES = { "ch_nuzlocke" => "Nuzlocke", "kuraylevelcap" => "Level Cap", "levelcapbehavior" => "Cap Behavior",
                  "noevsmode" => "No-EVs Mode", "maxivsmode" => "Max IVs Mode", "damage_variance" => "Damage Variance" }.freeze

    @rows = {}
    @plan = nil
    @trainer = nil
    @skips = {}

    class << self
      attr_reader :plan, :trainer

      def boot
        Reloaded::SaveStore.register(SECTION)
        register_settings
        register_builtin_rows
        install
        Reloaded::Events.on(:title_screen, :new_game_setup, 50) { @skips = {} }
        return true
      end

      def register_settings
        Reloaded::Settings.register(TOGGLE, :page => :systems, :priority => 36, :type => :toggle, :default => true, :preset => false,
          :name => "Reloaded New Game",
          :description => "New Game Setup: Game Mode, your trainer, the run's rules and its Run Card in one screen, before Oak's talk. " \
                          "Off asks the game's own questions instead.")
      end

      def enabled?
        return Reloaded::Settings.get(TOGGLE) != false
      rescue StandardError
        return true
      end

      #------------------------------------------------------------------------
      # Rows (Run Setup)
      #------------------------------------------------------------------------
      # kind: :choice (Left / Right through :values), :number (:min, :max,
      # :step; A opens a number picker), :open (A runs :press), :setup (a
      # part set up on its own screen: A runs :press, shown as a pill).
      # :default (a value or proc), :visible / :lock (proc(plan): false /
      # a reason), :display (proc(value): the words), :tone (proc(value):
      # a palette key or [r, g, b]), :apply (proc(value, plan), at Start),
      # :card (proc(value, plan): [label, words] on the Run Card), :tag
      # (proc(value, plan): [label, [r, g, b]] a pill on it), :code (false:
      # not in share codes and presets), :changed_words (proc(value): what
      # Replace Your Setup? says).
      def register_row(id, options = {})
        id = id.to_sym
        @rows[id] = { :id => id, :name => options[:name] || id.to_s, :kind => options[:kind] || :choice,
                      :priority => options[:priority] || 100, :values => options[:values], :default => options[:default],
                      :min => options[:min], :max => options[:max], :step => options[:step] || 1,
                      :visible => options[:visible], :lock => options[:lock], :display => options[:display],
                      :tone => options[:tone], :press => options[:press], :apply => options[:apply],
                      :card => options[:card], :tag => options[:tag], :description => options[:description],
                      :descriptions => options[:descriptions],
                      :code => options.has_key?(:code) ? options[:code] : true }
        @plan["rows"][id.to_s] = default_of(@rows[id]) if @plan && !@plan["rows"].has_key?(id.to_s)
        return id
      end

      def row(id)
        return @rows[id.to_sym]
      end

      # The rows shown now, in order
      def rows
        return @rows.values.select { |r| row_visible?(r) }.sort_by { |r| [r[:priority], r[:name]] }
      end

      def row_visible?(r)
        return true unless r[:visible]
        return r[:visible].call(@plan) ? true : false
      rescue StandardError => e
        Reloaded::Log.warning_once("New Game Setup's #{r[:id]} row couldn't say if it shows: #{e.message}", :new_game)
        return false
      end

      def values_of(r)
        v = r[:values]
        v = v.call if v.respond_to?(:call)
        return Array(v)
      end

      def default_of(r)
        d = r[:default]
        return d.respond_to?(:call) ? d.call : d
      end

      def value(id)
        return nil unless @plan
        return @plan["rows"][id.to_s]
      end

      # A row's value, kept in its range
      def set_value(id, v)
        r = row(id)
        return false unless r && @plan && valid?(r, v)
        @plan["rows"][id.to_s] = v
        return true
      end

      def valid?(r, v)
        case r[:kind]
        when :choice then return v.is_a?(Integer) && v >= 0 && v < values_of(r).length
        when :number then return v.is_a?(Integer) && v >= (r[:min] || 0) && v <= (r[:max] || 999_999)
        end
        return true
      end

      # Left / Right on a row: the next value (a held direction stops at the
      # ends of a number)
      def step_value(id, dir)
        r = row(id)
        return false unless r && !lock_reason(id)
        case r[:kind]
        when :choice
          n = values_of(r).length
          return false if n < 2
          return set_value(id, (value(id).to_i + dir) % n)
        when :number
          to = [[value(id).to_i + dir * r[:step], r[:min] || 0].max, r[:max] || 999_999].min
          return false if to == value(id)
          return set_value(id, to)
        end
        return false
      end

      def lock_reason(id)
        r = row(id)
        return nil unless r && r[:lock]
        return r[:lock].call(@plan)
      rescue StandardError
        return nil
      end

      # The row's value in words
      def display(id)
        r = row(id)
        v = value(id)
        return r[:display].call(v).to_s if r[:display]
        return _INTL(values_of(r)[v.to_i].to_s) if r[:kind] == :choice
        return v.to_s
      end

      def tone(id)
        r = row(id)
        return r && r[:tone] ? r[:tone].call(value(id)) : nil
      end

      #------------------------------------------------------------------------
      # The run being set up
      #------------------------------------------------------------------------
      # A fresh run: Classic, every row at its default, a fresh trainer
      def reset
        @plan = fresh_plan
        @trainer = fresh_trainer
        apply_look                       # the form's own first look (Male, Red's clothes)
        @plan
      end

      def fresh_plan
        p = { "mode" => "classic", "rows" => {}, "custom" => nil, "mixed" => nil, "preset" => nil }
        @rows.each_value { |r| p["rows"][r[:id].to_s] = default_of(r) }
        return p
      end

      def fresh_trainer
        return { "name" => "", "gender" => 1, "age" => AGES.first, "skin" => 5, "hair" => 2 }
      end

      def mode
        return @plan ? @plan["mode"] : "classic"
      end

      def mode_index
        return MODES.index(mode) || 0
      end

      def mode_locked?(m)
        return m == "legendary" && !new_game_plus?
      end

      def new_game_plus?
        return $Trainer && $Trainer.respond_to?(:new_game_plus_unlocked) && $Trainer.new_game_plus_unlocked ? true : false
      end

      def mode=(m)
        m = m.to_s
        return false unless MODES.include?(m) && !mode_locked?(m)
        @plan["mode"] = m
        return true
      end

      def randomized?
        return mode == "randomized"
      end

      # The Reloaded Randomizer's parts (its row, its seed on the card)
      def randomizer?
        return defined?(Reloaded::Randomizer) && Reloaded::Randomizer.on? && defined?(::KIF::Rand) ? true : false
      end

      # The trainer's name, or PIF's default for the gender (Red / Green)
      def trainer_name(t = @trainer)
        name = t["name"].to_s.strip
        return name unless name.empty?
        return getPlayerDefaultName(t["gender"]) if defined?(getPlayerDefaultName)
        return t["gender"] == 0 ? "Green" : "Red"
      rescue StandardError
        return "Red"
      end

      def set_trainer(field, v)
        case field
        when "gender" then v = v.to_i % 2
        when "age" then v = [[v.to_i, AGES.first].max, AGES.last].min
        when "skin" then v = (v.to_i - 1) % SKIN_NAMES.length + 1
        when "hair" then v = v.to_i % HAIR_NAMES.length
        when "name" then v = v.to_s[0, name_max]
        end
        @trainer[field] = v
        apply_look
      end

      def name_max
        return defined?(::Settings::MAX_PLAYER_NAME_SIZE) ? ::Settings::MAX_PLAYER_NAME_SIZE : 10
      end

      #------------------------------------------------------------------------
      # Ids: PIF's names, else its numbers
      #------------------------------------------------------------------------
      def id_of(name)
        return Object.const_defined?(name) ? Object.const_get(name) : IDS[name]
      end

      def switch!(name, on)
        id = name.is_a?(Integer) ? name : id_of(name)
        $game_switches[id] = on if id && $game_switches
      end

      def variable!(name, v)
        id = id_of(name)
        $game_variables[id] = v if id && $game_variables
      end

      #------------------------------------------------------------------------
      # Starters
      #------------------------------------------------------------------------
      # A set's three Pokémon (symbols), or nil (Custom; Mixed until rolled)
      def starter_list(i)
        return @plan && @plan["mixed"] ? @plan["mixed"].map(&:to_sym) : nil if i == MIXED
        list = STARTER_SETS[i] && STARTER_SETS[i][2]
        return nil unless list && defined?(::Settings) && ::Settings.const_defined?(list)
        return ::Settings.const_get(list)
      end

      # Mixed: three rolled once (PIF's own roll), shown and kept for Oak's lab
      def roll_mixed
        list = defined?(generate_mixed_starters_list) ? generate_mixed_starters_list : nil
        @plan["mixed"] = list ? list.map(&:to_s) : nil
      end

      # Random starters in the Randomizer, or Legendary Mode's own: the row
      # has nothing to pick
      def starters_lock
        return _INTL("Legendary Mode gives a Legendary starter.") if mode == "legendary"
        if randomized? && defined?(::KIF::Rand) && (::KIF::Rand.get(:starters).to_i > 0 rescue false)
          return _INTL("Random Starters are on in the Randomizer.")
        end
        return nil
      end

      # The Custom starter in a picture's words: "Chikorita" or "Chikorita / Charmander"
      def custom_words
        c = @plan && @plan["custom"]
        return nil unless c.is_a?(Hash) && c["body"]
        return species_name(c["body"]) unless c["fused"] && c["head"]
        return _INTL("{1} / {2}", species_name(c["body"]), species_name(c["head"]))
      end

      def species_name(sym)
        return ::GameData::Species.get(sym.to_sym).name
      rescue StandardError
        return sym.to_s.capitalize
      end

      def dex_number(sym)
        return getDexNumberForSpecies(sym.to_sym) if defined?(getDexNumberForSpecies)
        return ::GameData::Species.get(sym.to_sym).id_number
      end

      #------------------------------------------------------------------------
      # Per-save settings: those that differ from their defaults
      #------------------------------------------------------------------------
      def kif_keys
        return [] unless defined?(::KIF::Presets) && defined?(::KIF::Options)
        return ::KIF::Presets.keys.select { |k| ::KIF::Options.defaults.has_key?(k) }.sort_by(&:to_s)
      rescue StandardError
        return []
      end

      def kif_changes
        out = {}
        kif_keys.each do |k|
          v = ::KIF::Options.raw(k)
          next if v == ::KIF::Options.defaults[k] || !Reloaded::ShareCodes.json_safe?(v)
          out[k.to_s] = v
        end
        return out
      rescue StandardError
        return {}
      end

      def kr_changes
        out = {}
        Reloaded::Settings.export_values(:save).each do |k, v|
          out[k] = v if v != Reloaded::Settings.default(k) && Reloaded::ShareCodes.json_safe?(v)
        end
        return out
      rescue StandardError
        return {}
      end

      # Every per-save setting back to its default, then these
      def put_settings(kif, kr)
        kif = kif.is_a?(Hash) ? kif : {}
        known = kif_keys
        known.each do |k|
          v = kif.has_key?(k.to_s) ? kif[k.to_s] : ::KIF::Options.defaults[k]
          v = ::KIF::Options.defaults[k] unless same_kind?(v, ::KIF::Options.defaults[k])
          $PokemonSystem.send(:"#{k}=", Marshal.load(Marshal.dump(v))) if $PokemonSystem
        end
        ::KIF.recalc_all_stats if !known.empty? && ::KIF.respond_to?(:recalc_all_stats)
        kr = kr.is_a?(Hash) ? kr : {}
        defaults = {}
        Reloaded::Settings.export_values(:save).each_key { |k| defaults[k] = Reloaded::Settings.default(k) }
        Reloaded::Settings.import_values(defaults.merge(kr.select { |k, _v| defaults.has_key?(k.to_s) }))
      rescue StandardError => e
        Reloaded::Log.exception("New Game Setup couldn't set the per-save settings", e, :new_game)
      end

      def same_kind?(v, current)
        return true if current.nil?
        return [true, false].include?(v) if [true, false].include?(current)
        return v.is_a?(Integer) if current.is_a?(Integer)
        return v.is_a?(String) if current.is_a?(String)
        return v.class == current.class
      end

      # A setting's name, for the popups (Kanto Reloaded's own, KIF's known
      # ones; the rest counted)
      def setting_names(kif, kr)
        names = []
        more = 0
        (kif || {}).each_key { |k| KIF_NAMES[k] ? names << _INTL(KIF_NAMES[k]) : more += 1 }
        (kr || {}).each_key do |k|
          d = Reloaded::Settings.definition(k) rescue nil
          d ? names << _INTL(d[:name]) : more += 1
        end
        names << (names.empty? ? _INTL("{1} Changed", more) : _INTL("{1} More", more)) if more > 0
        return names
      end

      #------------------------------------------------------------------------
      # A run as data: share codes and presets
      #------------------------------------------------------------------------
      # What differs from a fresh run (rows in their order; settings sorted),
      # so the same run always makes the same code
      def payload
        p = { "v" => CODE_VERSION, "mode" => mode }
        rows_out = {}
        @rows.values.sort_by { |r| [r[:priority], r[:id].to_s] }.each do |r|
          next unless r[:code] && row_visible?(r)
          v = value(r[:id])
          rows_out[r[:id].to_s] = v unless v == default_of(r) || !Reloaded::ShareCodes.json_safe?(v)
        end
        p["rows"] = rows_out unless rows_out.empty?
        p["custom"] = @plan["custom"] if value(:starters) == CUSTOM && @plan["custom"].is_a?(Hash)
        kif = kif_changes
        p["kif"] = kif unless kif.empty?
        kr = kr_changes
        p["kr"] = kr unless kr.empty?
        p["rand"] = ::KIF::Rand.settings_code if randomized? && randomizer?
        return p
      end

      def json_of(p)
        return Reloaded::JSON.generate(p)
      end

      def code(p = payload)
        packed = defined?(::Zlib) ? ::Zlib::Deflate.deflate(json_of(p), ::Zlib::BEST_COMPRESSION) : json_of(p)
        return CODE_PREFIX + [packed].pack("m0")
      end

      # 57DA-A91F: the run's JSON's CRC32
      def run_id(p = payload)
        text = json_of(p)
        crc = defined?(::Zlib) ? ::Zlib.crc32(text) : Reloaded::Zip.send(:crc32, text.b)
        hex = crc.to_s(16).upcase.rjust(8, "0")
        return "#{hex[0, 4]}-#{hex[4, 4]}"
      end

      # A pasted code: [payload, nil] or [nil, why]
      def read_code(text)
        text = text.to_s.strip
        return [nil, :empty] if text.empty?
        return [nil, :too_long] if text.length > CODE_MAX
        return [nil, :not_code] unless text.start_with?(CODE_PREFIX)
        raw = text[CODE_PREFIX.length..-1].unpack1("m0")
        json = defined?(::Zlib) ? ::Zlib::Inflate.inflate(raw) : raw
        p = Reloaded::JSON.parse(json.force_encoding(Encoding::UTF_8))
        return [nil, :not_code] unless p.is_a?(Hash) && MODES.include?(p["mode"])
        return [nil, :newer] if p["v"].to_i > CODE_VERSION
        return [p, nil]
      rescue StandardError
        return [nil, :not_code]
      end

      def code_problem(why)
        case why
        when :too_long then return _INTL("That's too long to be a share code.")
        when :newer then return _INTL("This code was made by a newer Kanto Reloaded. Update to use it.")
        when :empty then return _INTL("Paste or type a share code first.")
        end
        return _INTL("That isn't a New Game share code. They start with {1}", CODE_PREFIX)
      end

      # A run (a code's payload, a preset) put in place of the setup. Rows
      # it doesn't name, and settings it doesn't name, go back to their
      # defaults, so the run is the same as the one it came from.
      def apply_run(p, settings = true)
        fresh = fresh_plan
        fresh["mode"] = MODES.include?(p["mode"]) && !mode_locked?(p["mode"]) ? p["mode"] : "classic"
        (p["rows"] || {}).each do |id, v|
          r = row(id)
          fresh["rows"][id.to_s] = v if r && r[:code] && valid?(r, v)
        end
        fresh["custom"] = clean_custom(p["custom"])
        fresh["rows"]["starters"] = 0 if fresh["rows"]["starters"] == CUSTOM && !fresh["custom"]
        fresh["preset"] = p["name"]
        @plan = fresh
        roll_mixed if value(:starters) == MIXED
        put_settings(p["kif"], p["kr"]) if settings
        apply_randomizer(p) if randomized? && randomizer?
        return true
      end

      def clean_custom(c)
        return nil unless c.is_a?(Hash) && c["body"].is_a?(String)
        out = { "fused" => c["fused"] ? true : false, "body" => c["body"] }
        out["head"] = c["head"] if c["fused"] && c["head"].is_a?(String)
        [out["body"], out["head"]].compact.each { |s| ::GameData::Species.get(s.to_sym) }
        return out
      rescue StandardError
        return nil
      end

      # The Randomizer's part of a run: a settings code, or one of cody's
      # built-in presets by name (Kanto Reloaded's parts at their defaults)
      def apply_randomizer(p)
        r = ::KIF::Rand
        if p["rand"].is_a?(String)
          r.apply_code(p["rand"])
        elsif p["rand_builtin"].is_a?(String)
          i = r::BUILTIN_PRESETS.index { |n, _d, _v| n == p["rand_builtin"] }
          if i
            r.load_builtin(i)
            Reloaded::Randomizer.reset! if defined?(Reloaded::Randomizer)
          end
        end
      rescue StandardError => e
        Reloaded::Log.exception("New Game Setup couldn't set the Randomizer", e, :new_game)
      end

      # What a run would change, for Replace Your Setup?: [[label, from,
      # to, from tone, to tone]]
      def changes_to(p)
        out = []
        to_mode = MODES.include?(p["mode"]) ? p["mode"] : "classic"
        out << [_INTL("Game Mode"), _INTL(MODE_NAMES[mode_index]), _INTL(MODE_NAMES[MODES.index(to_mode)]),
                MODE_RGB[mode_index], MODE_RGB[MODES.index(to_mode)]] if to_mode != mode
        @rows.values.sort_by { |r| [r[:priority], r[:id].to_s] }.each do |r|
          next unless r[:code]
          given = (p["rows"] || {})[r[:id].to_s]
          to = valid?(r, given) ? given : default_of(r)
          from = value(r[:id])
          next if to == from
          out << [_INTL(r[:name]), words_for(r, from), words_for(r, to), r[:tone] ? r[:tone].call(from) : nil,
                  r[:tone] ? r[:tone].call(to) : nil]
        end
        kif_now = kif_changes
        kr_now = kr_changes
        if (p["kif"] || {}) != kif_now || (p["kr"] || {}) != kr_now
          names = setting_names(p["kif"], p["kr"])
          out << [_INTL("Per-Save Settings"), nil, names.empty? ? _INTL("All at Default") : names.join(", "), nil, nil]
        end
        return out
      end

      def words_for(r, v)
        return r[:display].call(v).to_s if r[:display]
        return _INTL(values_of(r)[v.to_i].to_s) if r[:kind] == :choice
        return v.to_s
      end

      # Anything set up yet (From a Preset asks before replacing it)
      def changed?
        return true if mode != "classic"
        return true if @rows.values.any? { |r| r[:code] && value(r[:id]) != default_of(r) }
        return !kif_changes.empty? || !kr_changes.empty?
      end

      #------------------------------------------------------------------------
      # Presets
      #------------------------------------------------------------------------
      # [{ "name", "sub", "tag" => [label, rgb], "run" }]: only what exists
      def builtin_presets
        list = []
        list << { "name" => "Classic", "sub" => _INTL("Normal, Nothing Changed"), "tag" => ["CLASSIC", MODE_RGB[0]],
                  "run" => { "mode" => "classic" } }
        kif = {}
        words = [_INTL("Hard")]
        if kif_keys.include?(:ch_nuzlocke)
          kif["ch_nuzlocke"] = 1
          words << _INTL("Nuzlocke")
        end
        if kif_keys.include?(:kuraylevelcap)
          kif["kuraylevelcap"] = 2
          words << _INTL("Level Cap Normal")
        end
        list << { "name" => "Challenge", "sub" => words.join(", "), "tag" => ["HARD", [240, 100, 90]],
                  "run" => { "mode" => "classic", "rows" => { "difficulty" => 2 }, "kif" => kif } }
        list << { "name" => "Casual", "sub" => _INTL("Easy, Autosave On, {1}", money_words(10_000)), "tag" => ["EASY", [120, 230, 150]],
                  "run" => { "mode" => "classic", "rows" => { "difficulty" => 0, "autosave" => 1, "money" => 10_000 } } }
        if randomizer?
          list << { "name" => "Randomizer Run", "sub" => _INTL("Randomized (First Randomizer), Hard"), "tag" => ["RANDOM", MODE_RGB[2]],
                    "run" => { "mode" => "randomized", "rows" => { "difficulty" => 2 }, "rand_builtin" => "First Randomizer" } }
        end
        list.each { |p| p["run"]["name"] = p["name"] }
        return list
      end

      # The player's presets that hold a run: [{ "name", "slot", "run", "sub" }]
      def user_presets
        return [] unless defined?(::KIF::Presets)
        d = ::KIF::Presets.data
        out = []
        ::KIF::Presets::SLOTS.times do |i|
          vals = d[:slots][i]
          next unless vals.is_a?(Hash) && vals[:kr_run].is_a?(Hash)
          run = vals[:kr_run]
          words = []
          diff = (run["rows"] || {})["difficulty"]
          words << Reloaded::Difficulty.shown_name(diff.nil? ? 1 : diff) if defined?(Reloaded::Difficulty)
          words << _INTL("Saved {1}", run["saved"]) if run["saved"]
          out << { "name" => d[:names][i].to_s, "slot" => i, "run" => run, "sub" => words.join(", ") }
        end
        return out
      rescue StandardError => e
        Reloaded::Log.exception("New Game Setup couldn't read KIF's presets", e, :new_game)
        return []
      end

      # A user preset's whole run: its run with KIF's and Kanto Reloaded's
      # settings from the slot (the slot holds all of them, not only changes)
      def user_run(preset)
        vals = ::KIF::Presets.data[:slots][preset["slot"]] || {}
        run = preset["run"].dup
        kif = {}
        vals.each { |k, v| kif[k.to_s] = v if k.is_a?(Symbol) && k != :reloaded && k != :kr_run && Reloaded::ShareCodes.json_safe?(v) }
        run["kif"] = kif.reject { |k, v| ::KIF::Options.defaults[k.to_sym] == v }
        kr = vals[:reloaded].is_a?(Hash) ? vals[:reloaded] : {}
        run["kr"] = kr.reject { |k, v| (Reloaded::Settings.default(k) rescue nil) == v }
        run["name"] = preset["name"]
        return run
      end

      # The first empty slot, or nil
      def free_slot
        return nil unless defined?(::KIF::Presets)
        d = ::KIF::Presets.data
        return (0...::KIF::Presets::SLOTS).find { |i| !d[:slots][i].is_a?(Hash) }
      end

      # The setup into a slot as a preset of its own; true when written
      def save_preset(i, name)
        name = name.to_s.strip[0, 16]
        return false if name.empty? || !::KIF::Presets.save(i)
        d = ::KIF::Presets.data
        return false unless d[:slots][i].is_a?(Hash)
        d[:names][i] = name
        kr = Reloaded::Settings.export_values(:save)
        d[:slots][i][:reloaded] = kr unless kr.empty?
        run = payload
        run.delete("kif")
        run.delete("kr")
        run["saved"] = Time.now.strftime("%b %-d")
        d[:slots][i][:kr_run] = run
        return ::KIF::Presets.write(d)
      rescue StandardError => e
        Reloaded::Log.exception("New Game Setup couldn't save a preset", e, :new_game)
        return false
      end

      def delete_preset(i)
        d = ::KIF::Presets.data
        d[:slots].delete(i)
        return ::KIF::Presets.write(d)
      end

      # (the game's fonts draw $ as the Pokédollar sign)
      def money_words(v)
        return "$" + v.to_i.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
      end

      #------------------------------------------------------------------------
      # Start: the setup goes into the game
      #------------------------------------------------------------------------
      def start!
        apply_mode
        apply_trainer
        rows.each do |r|
          next unless r[:apply] && !lock_reason(r[:id])
          begin
            r[:apply].call(value(r[:id]), @plan)
          rescue StandardError => e
            Reloaded::Log.exception("New Game Setup's #{r[:id]} row couldn't be set", e, :new_game)
          end
        end
        record
        @skips = { :form => true, :difficulty => true, :starters => true, :first_save => true }
        Reloaded::Log.info("New Game Setup: #{MODE_NAMES[mode_index]}, Run ID #{run_id}", :new_game)
        Reloaded::Events.emit(:new_game_setup_done, :run => run)   # (as recorded)
        return MODE_SYMBOLS[mode_index]
      end

      # PIF's apply_game_mode (Classic sets nothing); the Randomizer's
      # settings put back as they were when it isn't Randomized
      def apply_mode
        restore_randomizer unless randomized?
        sym = MODE_SYMBOLS[mode_index]
        apply_game_mode(sym) if sym != :CLASSIC && defined?(apply_game_mode)
      end

      # As PIF's form: gender (its clothes, hat and hair style), hair colour,
      # age, skin, name; setupStartingOutfit after it does the rest
      def apply_trainer
        apply_look
        variable!(:VAR_TRAINER_AGE, @trainer["age"])
        $Trainer.name = trainer_name
      end

      # The trainer's look on $Trainer as the form sets it while you choose
      # (the picture on the stage is drawn from it)
      def apply_look
        return unless $Trainer && @trainer
        g = @trainer["gender"]
        variable!(:VAR_TRAINER_GENDER, g)
        style = defined?(getDefaultHair) ? getDefaultHair(g) : nil
        name = trainer_name
        style = ::HAIR_RIVAL if name == "Gary" && g == 1 && defined?(::HAIR_RIVAL)       # PIF's easter eggs
        style = ::HAIR_BROCK if name == "Brock" && g == 1 && defined?(::HAIR_BROCK)
        style = ::HAIR_MISTY1 if name == "Misty" && g == 0 && defined?(::HAIR_MISTY1)
        ids = defined?(::CharacterSelectMenuPresenter::HAIR_COLOR_IDS) ? ::CharacterSelectMenuPresenter::HAIR_COLOR_IDS : [1, 2, 3, 4]
        $Trainer.hair = "#{ids[@trainer["hair"]]}_#{style}" if style
        $Trainer.clothes = getDefaultClothes(g) if defined?(getDefaultClothes)
        $Trainer.hat = getDefaultHat(g) if defined?(getDefaultHat)
        $Trainer.skin_tone = @trainer["skin"] if $Trainer.respond_to?(:skin_tone=)
      rescue StandardError => e
        Reloaded::Log.warning_once("New Game Setup couldn't set the trainer's look: #{e.message}", :new_game)
      end

      # The run, kept in the save (the Trainer Card's Run Tags read it)
      def record
        d = Reloaded::SaveStore.section(SECTION)
        return unless d
        d.clear
        d.merge!(run_record)
      end

      # The run this save started with (nil: not set up here)
      def run
        d = Reloaded::SaveStore.section(SECTION)
        return d && !d.empty? ? d : nil
      end

      def run_record
        pl = payload
        return { "mode" => pl["mode"], "rows" => @plan["rows"].dup, "custom" => @plan["custom"], "preset" => @plan["preset"],
                 "run_id" => run_id(pl), "code" => code(pl), "seed" => randomized? && randomizer? ? ::KIF::Rand.format_seed : nil,
                 "at" => Time.now }
      end

      # The Randomizer as it was when the setup opened (Randomized wasn't
      # kept: nothing it changed stays)
      def keep_randomizer
        @rand_before = randomizer? ? ::KIF::Rand.capture : nil
      rescue StandardError
        @rand_before = nil
      end

      def restore_randomizer
        ::KIF::Rand.restore(@rand_before) if @rand_before && defined?(::KIF::Rand)
      rescue StandardError => e
        Reloaded::Log.exception("New Game Setup couldn't put the Randomizer back", e, :new_game)
      end

      #------------------------------------------------------------------------
      # The built-in rows
      #------------------------------------------------------------------------
      def register_builtin_rows
        d = defined?(Reloaded::Difficulty) ? Reloaded::Difficulty : nil
        register_row(:difficulty, :name => "Difficulty", :priority => 10, :kind => :choice,
          :values => ["Easy", "Normal", "Hard"], :default => 1,
          :tone => proc { |v| d ? d::TONES[v.to_i] : nil },
          :press => proc { |scene| scene.open_difficulty if scene.respond_to?(:open_difficulty) },
          :apply => proc { |v, _p| Reloaded::NewGameSetup.set_difficulty(v) },
          :tag => proc { |v, _p| v == 1 ? nil : [(v == 0 ? "EASY" : "HARD"), v == 0 ? [120, 230, 150] : [240, 100, 90]] },
          :description => "How hard the game is. A opens what each level changes; change it any time in Settings.")
        register_row(:randomizer, :name => "Randomizer", :priority => 20, :kind => :setup, :code => false,
          :visible => proc { |_p| Reloaded::NewGameSetup.randomized? && Reloaded::NewGameSetup.randomizer? },
          :press => proc { |scene| scene.open_randomizer if scene.respond_to?(:open_randomizer) },
          :apply => proc { |_v, _p| Reloaded::NewGameSetup.randomize! },
          :card => proc { |_v, _p| [_INTL("Seed"), ::KIF::Rand.format_seed] },
          :description => "What's random and the seed. It's randomized once, at Start.")
        register_row(:starters, :name => "Starters", :priority => 40, :kind => :choice,
          :values => STARTER_SETS.map { |s| s[0] }, :default => 0,
          :lock => proc { |_p| Reloaded::NewGameSetup.starters_lock },
          :display => proc { |v| v == CUSTOM && Reloaded::NewGameSetup.custom_words ? _INTL("Custom") : _INTL(STARTER_SETS[v.to_i][0]) },
          :apply => proc { |v, _p| Reloaded::NewGameSetup.set_starters(v) },
          :card => proc { |v, _p| [_INTL("Starters"), v == CUSTOM ? Reloaded::NewGameSetup.custom_words.to_s : _INTL(STARTER_SETS[v.to_i][0])] },
          :descriptions => ["Bulbasaur, Charmander and Squirtle.", "Chikorita, Cyndaquil and Totodile.", "Treecko, Torchic and Mudkip.",
                            "Turtwig, Chimchar and Piplup.", "Chespin, Fennekin and Froakie.",
                            "A Grass, a Fire and a Water starter from any generation.", "Any Pokémon you pick, fused or not."],
          :description => "The three Pokémon Oak offers.")
        register_row(:money, :name => "Starting Money", :priority => 50, :kind => :number,
          :default => proc { defined?(::Settings::INITIAL_MONEY) ? ::Settings::INITIAL_MONEY : 3000 },
          :min => 0, :max => MONEY_MAX, :step => MONEY_STEP,
          :display => proc { |v| Reloaded::NewGameSetup.money_words(v) },
          :apply => proc { |v, _p| $Trainer.money = v.to_i if $Trainer },
          :card => proc { |v, _p| [_INTL("Money"), Reloaded::NewGameSetup.money_words(v)] },
          :description => "The money you start with.")
        register_row(:autosave, :name => "Autosave", :priority => 60, :kind => :choice,
          :values => ["Off", "On"], :default => 0,
          :card => proc { |v, _p| [_INTL("Autosave"), v == 1 ? _INTL("On") : _INTL("Off")] },
          :descriptions => ["You save when you want to.", "The game saves when you heal. The save screen opens once before your journey."],
          :description => "Autosave saves the game when you heal; change it in Settings.")
        register_row(:per_save, :name => "All Per-Save Settings", :priority => 90, :kind => :open, :code => false,
          :press => proc { |scene| scene.open_per_save if scene.respond_to?(:open_per_save) },
          :description => "Every setting this save keeps (Nuzlocke, Level Cap...), before you start.")
      end

      # CE 61's work: the level, the lowest used, PIF's switches
      def set_difficulty(v)
        v = v.to_i.clamp(0, 2)
        $Trainer.selected_difficulty = v if $Trainer.respond_to?(:selected_difficulty=)
        $Trainer.lowest_difficulty = v if $Trainer.respond_to?(:lowest_difficulty=)
        switch!(:SWITCH_GAME_DIFFICULTY_EASY, v == 0)
        switch!(:SWITCH_GAME_DIFFICULTY_HARD, v == 2)
      end

      # CE 46's work: the set's switch; Mixed keeps the three shown; Custom
      # its Pokémon (fused: body * NB_POKEMON + head) and the rival's random
      def set_starters(v)
        STARTER_SETS.each { |_n, name, _l| switch!(name, false) if name }
        set = STARTER_SETS[v.to_i]
        return if set.nil? || set[1].nil?
        if v == CUSTOM
          c = @plan["custom"]
          return unless c.is_a?(Hash) && c["body"]
          nb = defined?(::NB_POKEMON) ? ::NB_POKEMON : 501
          choice = c["fused"] && c["head"] ? dex_number(c["body"]) * nb + dex_number(c["head"]) : dex_number(c["body"])
          variable!(:VAR_PLAYER_STARTER_CHOICE, choice)
          variable!(:VAR_RIVAL_STARTER_HEAD_CHOICE, rand(nb))
          variable!(:VAR_RIVAL_STARTER_BODY_CHOICE, rand(nb))
        end
        switch!(set[1], true)
        $game_temp.starter_options = @plan["mixed"].map(&:to_sym) if v == MIXED && @plan["mixed"] && $game_temp
      end

      # The Randomizer's New Game work (as cody's screen does as it closes
      # in the intro), and its intro loop skipped (Randomizer::IntroSkip)
      def randomize!
        return unless randomizer?
        r = ::KIF::Rand
        r.sync_masters
        if r.data_on?
          r.randomize_data
          r.write_log
        end
        r.screen_closed! if r.respond_to?(:screen_closed!)
        Reloaded::Randomizer.skip_intro_summary = true if Reloaded::Randomizer.respond_to?(:skip_intro_summary=)
      end

      #------------------------------------------------------------------------
      # The intro
      #------------------------------------------------------------------------
      def install
        h = Reloaded::Hooks
        # KIF's game mode menu (and its swap for the first game's download
        # question): the setup instead
        if Object.private_method_defined?(:select_game_mode) || Object.method_defined?(:select_game_mode)
          h.around(nil, Object, :select_game_mode, :id => :new_game_setup) do |original, *args|
            next original.call(*args) unless Reloaded::NewGameSetup.enabled? && defined?(Reloaded::NewGameScreen)
            Reloaded::NewGameSetup.open(original, args)
          end
        end
        # the application form: its choices were made (the game's classes are
        # there in the game; outside it, a hook is made only when its target is)
        if defined?(::CharacterSelectionMenuView)
          h.around(nil, "CharacterSelectionMenuView", :start, :id => :new_game_form) do |original, *args|
            next original.call(*args) unless Reloaded::NewGameSetup.skip?(:form)
            Reloaded::NewGameSetup.close_form(original.receiver)
            nil
          end
        end
        # Common Events 61 / 46 / 47 by name
        if defined?(::Interpreter)
          h.around(nil, "Interpreter", :command_117, :id => :new_game_prompts) do |original, *args|
            interp = original.receiver
            which = Reloaded::NewGameSetup.prompt_of(interp)
            next original.call(*args) unless which && Reloaded::NewGameSetup.skip?(which)
            Reloaded::NewGameSetup.answered(which)
            true
          end
        end
      end

      # The setup's screen; nil when it went back to the title
      def open(original, args)
        reset
        keep_randomizer
        result = Reloaded::NewGameScreen.new.main
        return start! if result == :start
        if result == :title
          to_title
          return nil
        end
        return original.call(*args)
      rescue StandardError => e
        Reloaded::Log.exception("New Game Setup failed; the game's own menu instead", e, :new_game)
        return original.call(*args)
      end

      # Back to the Title: the intro's event waits where it is, and the map
      # goes to the title at the end of this frame (as the event command
      # Return to Title Screen does)
      def to_title
        $game_temp.to_title = true if $game_temp
        interp = defined?(pbMapInterpreter) ? pbMapInterpreter : ($game_system.map_interpreter rescue nil)
        interp.instance_variable_set(:@wait_count, 999_999) if interp
        Reloaded::Log.info("New Game Setup: back to the title", :new_game)
      end

      def skip?(which)
        return @skips[which] ? true : false
      end

      def prompt_of(interp)
        return nil if @skips.empty?
        id = interp.instance_variable_get(:@parameters)
        id = id[0] if id.is_a?(Array)
        ce = ($data_common_events[id] rescue nil)
        return ce ? PROMPTS[ce.name.to_s.strip] : nil
      end

      # The form's picture goes as its own close would take it
      def close_form(view)
        @skips.delete(:form)
        presenter = view.instance_variable_get(:@presenter)
        preview = presenter && presenter.instance_variable_get(:@trainerPreview)
        preview.erase if preview && preview.respond_to?(:erase)
        port = view.instance_variable_get(:@viewport)
        port.dispose if port && !port.disposed?
      rescue StandardError => e
        Reloaded::Log.warning_once("New Game Setup couldn't close the form's picture: #{e.message}", :new_game)
      end

      # A prompt skipped: the first save does what CE 47 does with its answer
      def answered(which)
        @skips.delete(which)
        return unless which == :first_save
        on = value(:autosave).to_i == 1
        variable!(:AUTOSAVE_HEALING_VAR, on ? 0 : 1)
        switch!(:AUTOSAVE_ENABLED_SWITCH, on)
        missed = @skips.keys
        Reloaded::Log.warning("New Game Setup: the intro never asked #{missed.join(", ")} (skips not used)", :new_game) unless missed.empty?
        @skips = {}
        pbSaveScreen if on && defined?(pbSaveScreen)
      end
    end
  end
end
