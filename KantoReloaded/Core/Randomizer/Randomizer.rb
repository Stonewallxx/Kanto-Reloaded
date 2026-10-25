# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Randomizer (the engine side)
#==============================================================================
# KIF's Randomizer is cody's (Data/Scripts/990_KIF/ZZ_Cody/C-RAND-01): his
# engine does every shuffle, from his seed, and stays untouched. Kanto
# Reloaded takes over his screens (UI/RandomizerScreen.rb) and adds its own
# parts on top, all through hooks: his screens and engine share one folder,
# so KIF's own takeover would switch his engine off too. The takeover is
# declared in Kanto Reloaded's settings only (the Reloaded Randomizer
# switch); Off gives his screens back.
#
#   Random Learnsets   Learnsets: Same / Follow Type (his Moves Follow Type)
#                      / Random (Learnsets.rb)
#   Per Pokémon        each Pokémon rolls its own ability from the pool his
#                      Abilities row picks; trainers' rolls Fixed by the seed
#                      or Dynamic (Abilities.rb)
#   Expanded Dex       the Expanded Pokédex's Pokémon in the pools (In Pools
#                      by default; only on saves that have it)
#   Rolls              Fixed (by the seed) or Dynamic (on the spot) for
#                      trainer teams, starters, static encounters, gifts,
#                      trades, NPC requests and learnsets (Dynamic.rb)
#   Item Mode          Mapped / By Spot (his Dynamic: fixed by the seed and
#                      the spot) / Dynamic (item balls and gifts roll when
#                      you get them; shops stay By Spot)
#
# Kanto Reloaded's settings live in his save data ($PokemonGlobal.kif_rand),
# under keys of its own, so they travel with the run and stay with Kanto
# Reloaded off; his code never reads keys it doesn't know. They join his
# draft (changes wait until Randomize Now). The settings code stays his
# exactly while they're at their defaults; otherwise a seventh part,
# -KR1.<letters>, that Kanto Reloaded takes off before his parser reads the
# rest. Kanto Reloaded's Fixed rolls use their own sub-seeds and never the
# game's random numbers, so the same seed and his settings give the same
# game with or without them; Dynamic ones roll on the spot.
#
# Archipelago (cody's C-AP-01): linking a save to a slot puts Kanto
# Reloaded's parts back to their defaults too (as he does with his own), so
# every save linked to the slot gets the same world; and Difficulty hears of
# the level the slot sets at once.
#
#   Reloaded::Randomizer.on? / randomized? / seed / code / summary
#   Events: :randomized after a Randomize Now
#==============================================================================

module Reloaded
  module Randomizer
    FEATURE = :randomizer
    MODULE_ID = "C-RAND-01_Randomizer"
    # Kanto Reloaded's settings in his save data, and their defaults (each
    # 0 or 1; the settings code holds them in this order, new ones last)
    KEYS = { :kr_learnsets => 0,      # 1: Random Learnsets (Same and Follow Type are his)
             :kr_per_pokemon => 0,    # 1: Per Pokémon abilities
             :kr_trainer_rolls => 0,  # 0 Fixed by the seed, 1 Dynamic (each battle)
             :kr_expanded => 1,       # 1: the Expanded Pokédex's Pokémon In Pools
             # Rolls: 0 Fixed by the seed, 1 Dynamic (Dynamic.rb)
             :kr_teams_dynamic => 0, :kr_starters_dynamic => 0, :kr_statics_dynamic => 0, :kr_gifts_dynamic => 0,
             :kr_trades_dynamic => 0, :kr_requests_dynamic => 0, :kr_learnsets_dynamic => 0,
             :kr_items_dynamic => 0 }.freeze    # 1: Item Mode Dynamic (his Dynamic is By Spot under it)
    # The Rolls rows, with what each changes (the spoiler log, Bug Reports)
    ROLLS = [[:kr_teams_dynamic, "Trainer Teams"], [:kr_starters_dynamic, "Starters"], [:kr_statics_dynamic, "Static Encounters"],
             [:kr_gifts_dynamic, "Gift Pokémon"], [:kr_trades_dynamic, "Trades"], [:kr_requests_dynamic, "NPC Requests"],
             [:kr_learnsets_dynamic, "Learnsets"], [:kr_items_dynamic, "Found and Given Items"]].freeze
    CODE_TAG = "KR1"
    LEARNSETS = ["Same", "Follow Type", "Random"].freeze
    ITEM_MODES = ["Mapped", "By Spot", "Dynamic"].freeze

    class << self
      # The Expanded Pokédex (Wave 8) sets the first dex number it adds; nil
      # while there's none
      attr_accessor :expanded_from

      def boot
        Reloaded::Features.register(FEATURE, :name => "Reloaded Randomizer", :order => 31, :page => :randomizer,
          :replaces => ["KIF's Randomizer Screens"],
          :description => "Kanto Reloaded's Randomizer screens, at New Game and during a run, with Random Learnsets and Per-Pokémon " \
                          "Abilities. Takes over KIF's Randomizer screens; its engine stays. Off brings back KIF's own screens.")
        register_settings
        if engine?
          install
          Abilities.install
          Learnsets.install
          Dynamic.install
          install_screen if respond_to?(:install_screen)    # UI/RandomizerScreen.rb
          install_viewers if respond_to?(:install_viewers)  # UI/RandomizerViewers.rb (the Town Map's Entrance Log)
        end
        return true
      end

      # A Randomizer section of its own in Kanto Reloaded's settings: the
      # switch, and (on a randomized save) the row that opens the screen
      def register_settings
        s = Reloaded::Settings
        s.register_page(:randomizer, :group => :general, :name => "Randomizer", :icon => :features, :priority => 43,
          :description => "KIF's Randomizer in Kanto Reloaded's look, with Random Learnsets and Per-Pokémon Abilities.")
        s.register(:"randomizer.open", :page => :randomizer, :priority => 10, :type => :button, :preset => false,
          :name => "Randomizer", :visible => proc { Reloaded::Randomizer.randomized? },
          :on_press => proc { Reloaded::RandomizerScreen.open if defined?(Reloaded::RandomizerScreen) },
          :description => "Every part of this run's Randomizer, the seed, and Randomize Now. On randomized saves.")
      end

      #------------------------------------------------------------------------
      # State
      #------------------------------------------------------------------------
      def engine?
        return defined?(::KIF::Rand) && ::KIF::Rand.respond_to?(:data) ? true : false
      end

      # KIF's Randomizer module is on (cody's engine runs)
      def module_on?
        return true unless defined?(::KIF::Modules) && ::KIF::Modules.respond_to?(:active?)
        return ::KIF::Modules.active?(MODULE_ID) ? true : false
      rescue StandardError
        return true
      end

      def on?
        return Reloaded::Features.on?(FEATURE) && engine? && module_on?
      end

      # A save that's been randomized (cody's Randomizer row shows for it)
      def randomized?
        return on? && (::KIF::Rand.available? rescue false) ? true : false
      end

      def data
        return engine? ? ::KIF::Rand.data : {}
      end

      def get(key)
        v = data[key]
        return v.is_a?(Integer) ? v : KEYS[key]
      end

      def set(key, value)
        data[key] = value.to_i if KEYS.has_key?(key)
      end

      def defaults?
        return KEYS.all? { |k, d| get(k) == d }
      end

      def reset!
        KEYS.each_key { |k| data.delete(k) }
      end

      # The Learnsets row: 0 Same, 1 Follow Type (his Moves Follow Type), 2 Random
      def learnsets
        return 2 if get(:kr_learnsets) == 1
        return ::KIF::Rand.dget(:moves_follow) == 1 ? 1 : 0
      end

      def learnsets=(value)
        ::KIF::Rand.set(:moves_follow, value == 1 ? 1 : 0)
        set(:kr_learnsets, value == 2 ? 1 : 0)
      end

      # The Item Mode row: 0 Mapped, 1 By Spot (his Dynamic: each spot rolls
      # its own item, fixed by the seed), 2 Dynamic (rolled when you get it)
      def item_mode
        spot = ::KIF::Rand.dget(:item_mode) == 1
        return 2 if spot && get(:kr_items_dynamic) == 1
        return spot ? 1 : 0
      end

      def item_mode=(value)
        ::KIF::Rand.set(:item_mode, value >= 1 ? 1 : 0)
        set(:kr_items_dynamic, value == 2 ? 1 : 0)
      end

      def per_pokemon?
        return get(:kr_per_pokemon) == 1
      end

      def seed
        return engine? ? ::KIF::Rand.format_seed : nil
      end

      def code
        return engine? ? ::KIF::Rand.settings_code : nil
      end

      # Kanto Reloaded's settings, a line each (the spoiler log, Bug Reports)
      def summary
        lines = ["Item Mode: #{ITEM_MODES[item_mode]}",
                 "Learnsets: #{LEARNSETS[learnsets]}",
                 "Per Pokémon: #{per_pokemon? ? "On" : "Off"} (trainers: #{get(:kr_trainer_rolls) == 1 ? "Dynamic" : "Fixed"})",
                 "Expanded Pokédex: #{get(:kr_expanded) == 1 ? "In Pools" : "Off"}"]
        dynamic = ROLLS.select { |k, _n| get(k) == 1 }.map { |_k, n| n }
        lines << "Dynamic Rolls (not by the seed): #{dynamic.empty? ? "None" : dynamic.join(", ")}"
        return lines
      end

      #------------------------------------------------------------------------
      # The settings code's Kanto Reloaded part: KR1.<one letter per setting>
      #------------------------------------------------------------------------
      def code_part
        return CODE_TAG + "." + KEYS.keys.map { |k| get(k).to_s(36) }.join
      end

      # [his code, {key => value} or nil (no Kanto Reloaded part)], or nil
      # for a Kanto Reloaded part that can't be read
      def split_code(text)
        parts = text.to_s.strip.split("-")
        return [text.to_s.strip, nil] unless parts.length == 7 && parts[6].start_with?(CODE_TAG + ".")
        letters = parts[6][(CODE_TAG.length + 1)..-1].to_s
        vals = {}
        KEYS.keys.each_with_index do |k, i|
          ch = letters[i]
          vals[k] = ch ? ch.to_i(36) : KEYS[k]
        end
        return nil if letters.length > KEYS.length || vals.values.any? { |v| v > 1 }
        return [parts[0, 6].join("-"), vals]
      end

      #------------------------------------------------------------------------
      # Hooks on cody's engine (his names: KIF::Rand)
      #------------------------------------------------------------------------
      def install
        h = Reloaded::Hooks
        rand = ::KIF::Rand.singleton_class
        # Kanto Reloaded's settings join his draft: what Randomize Now applies,
        # what Later keeps, what Undo puts back
        h.around(FEATURE, rand, :capture, :id => :randomizer_capture) do |original, *args|
          state = original.call(*args)
          KEYS.each_key { |k| state[k] = Reloaded::Randomizer.get(k) } if state.is_a?(Hash)
          state
        end
        h.around(FEATURE, rand, :restore, :id => :randomizer_restore) do |original, state, *rest|
          result = original.call(state, *rest)
          KEYS.each_key { |k| Reloaded::Randomizer.set(k, state[k]) if state.is_a?(Hash) && state[k].is_a?(Integer) }
          result
        end
        h.around(FEATURE, rand, :capture_one, :id => :randomizer_capture_one) do |original, key, *rest|
          next Reloaded::Randomizer.get(key) if KEYS.has_key?(key)
          original.call(key, *rest)
        end
        # Random Learnsets make Pokémon data (he only checks his own keys)
        h.around(FEATURE, rand, :data_on?, :id => :randomizer_data_on) do |original, *args|
          original.call(*args) || Reloaded::Randomizer.get(:kr_learnsets) == 1
        end
        h.around(FEATURE, rand, :randomize_data, :id => :randomizer_learnsets) do |original, *args|
          changes = original.call(*args)
          Reloaded::Randomizer.add_learnsets(changes)
        end
        # the settings code
        h.around(FEATURE, rand, :settings_code, :id => :randomizer_code) do |original, *args|
          text = original.call(*args)
          Reloaded::Randomizer.defaults? ? text : "#{text}-#{Reloaded::Randomizer.code_part}"
        end
        h.around(FEATURE, rand, :parse_code, :id => :randomizer_parse_code) do |original, text, *rest|
          split = Reloaded::Randomizer.split_code(text)
          split ? original.call(split[0], *rest) : nil
        end
        h.around(FEATURE, rand, :apply_code, :id => :randomizer_apply_code) do |original, text, *rest|
          split = Reloaded::Randomizer.split_code(text)
          next false unless split
          ok = original.call(split[0], *rest)
          # his code alone: Kanto Reloaded's parts at their defaults, so the
          # code says the whole run
          KEYS.each { |k, d| Reloaded::Randomizer.set(k, split[1] ? split[1][k] : d) } if ok
          ok
        end
        # the spoiler log lists Kanto Reloaded's settings (Item Mode in place
        # of his line: his Dynamic is By Spot here)
        h.around(FEATURE, rand, :sec_settings, :id => :randomizer_log) do |original, *args|
          Array(original.call(*args)).reject { |l| l.to_s =~ /\AItem mode:/ } + Reloaded::Randomizer.summary
        end
        # Expanded Pokédex Off: its Pokémon (or a fusion with one) count as banned
        h.around(FEATURE, rand, :species_banned?, :id => :randomizer_expanded) do |original, dex, *rest|
          original.call(dex, *rest) || Reloaded::Randomizer.expanded_banned?(dex)
        end
        # his pages, captured instead of opened while Kanto Reloaded reads them
        if ::KIF::Rand.respond_to?(:open_page)
          h.around(FEATURE, rand, :open_page, :id => :randomizer_pages) do |original, title, desc, color, *rest, &builder|
            if defined?(Reloaded::Randomizer::Rows) && Reloaded::Randomizer::Rows.collecting?
              next [title, desc, builder.call]
            end
            original.call(title, desc, color, *rest, &builder)
          end
        end
        h.around(FEATURE, rand, :randomize_now, :id => :randomizer_randomized) do |original, *args|
          result = original.call(*args)
          Reloaded::Events.emit(:randomized, :seed => Reloaded::Randomizer.seed)
          result
        end
        install_archipelago
      end

      # After his rolls: Random Learnsets on their own sub-seed, merged into
      # his Pokémon data changes (kept in the save, put on the game data at
      # every load by his apply_data)
      def add_learnsets(changes)
        return changes unless get(:kr_learnsets) == 1 && changes.is_a?(Hash)
        Learnsets.roll.each { |s, fields| (changes[s] ||= {}).merge!(fields) }
        ::KIF::Rand.data[:species] = changes
        ::KIF::Rand.apply_data(changes)
        return changes
      end

      def expanded_banned?(dex)
        return false unless @expanded_from && get(:kr_expanded) == 0
        n = dex.is_a?(Integer) ? dex : (getDexNumberForSpecies(dex) rescue nil)
        return false unless n
        nb = defined?(::NB_POKEMON) ? ::NB_POKEMON : nil
        if nb && n > nb && defined?(::Settings::ZAPMOLCUNO_NB) && n < ::Settings::ZAPMOLCUNO_NB
          body = getBodyID(n)
          head = getHeadID(n, body)
          return expanded_banned?(body) || expanded_banned?(head)
        end
        return n >= @expanded_from
      rescue StandardError
        return false
      end

      #------------------------------------------------------------------------
      # Archipelago (cody's C-AP-01)
      #------------------------------------------------------------------------
      def install_archipelago
        return unless defined?(::KIF::AP) && ::KIF::AP.respond_to?(:apply_settings)
        h = Reloaded::Hooks
        ap = ::KIF::AP.singleton_class
        # the slot's randomizer settings: Kanto Reloaded's parts back to
        # their defaults with his, put back if the link fails
        h.around(FEATURE, ap, :apply_settings, :id => :randomizer_ap_settings) do |original, slot, *rest|
          settings = slot.is_a?(Hash) ? slot["randomizer"] : nil
          kept = KEYS.keys.map { |k| [k, Reloaded::Randomizer.data[k]] }.to_h
          Reloaded::Randomizer.reset! if settings.is_a?(Hash) && !settings.empty?
          begin
            original.call(slot, *rest)
          rescue StandardError
            kept.each { |k, v| v.nil? ? Reloaded::Randomizer.data.delete(k) : Reloaded::Randomizer.data[k] = v }
            raise
          end
        end
        # the slot sets the difficulty's switches: Difficulty hears it at once
        if ::KIF::AP.respond_to?(:link!)
          h.around(nil, ap, :link!, :id => :randomizer_ap_difficulty) do |original, *args|
            result = original.call(*args)
            Reloaded::Difficulty.loaded! if result && defined?(Reloaded::Difficulty)
            result
          end
        end
      end
    end
  end
end
