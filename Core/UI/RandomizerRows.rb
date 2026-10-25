# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Randomizer's rows
#==============================================================================
# Cody's Randomizer pages, as rows of Kanto Reloaded's screens. Each page of
# his (Pokémon, Trainers, Gyms, Items, Pokémon Data, Evolutions, Exclusions,
# Entrances) is built by his own code and captured instead of opened (his
# open_page, hooked while collecting), so every row he has, or adds later,
# comes over with its values and descriptions; Kanto Reloaded renames them
# to Title Case, adds headings on the long pages and puts its own rows in
# (Learnsets for his Moves Follow Type; Per Pokémon under Abilities, its
# Trainers under it; the Expanded Pokédex's on saves that have it; a Rolls
# row, Fixed or Dynamic, under each row the seed fixes, Dynamic.rb). A value
# that rolls on the spot (his Dynamic ones too) says the seed won't give the
# same result each time.
#
#   Rows.sections       the screen's sections: Overview, each part, Seed
#   Rows.part_state     a part's state for the Overview ("Route", on?)
#   Rows.summary        a part's settings that aren't at their default
#   Rows.waiting?       a row, or a part, changed since Randomize Now
#
# A row Archipelago holds on a linked save shows the value it holds, locked,
# with why (KIF::AP::FORCED; cody's own rows read the save's switches).
#==============================================================================

module Reloaded
  module Randomizer
    module Rows
      SMALL = %w[a an and or of to the in on for by at as].freeze
      PARTS = [[:pokemon, "Pokémon"], [:trainers, "Trainers"], [:gyms, "Gyms"], [:items, "Items"], [:data, "Pokémon Data"],
               [:evolutions, "Evolutions"], [:exclusions, "Exclusions"], [:entrances, "Entrances"]].freeze
      # The sidebar's tiles
      SECTIONS = [[:overview, "Overview", [214, 52, 60]], [:pokemon, "Pokémon", [90, 170, 100]], [:trainers, "Trainers", [210, 80, 80]],
                  [:gyms, "Gyms", [230, 180, 60]], [:items, "Items", [96, 160, 232]], [:data, "Pokémon Data", [200, 100, 170]],
                  [:evolutions, "Evolutions", [150, 110, 210]], [:exclusions, "Exclusions", [130, 140, 155]],
                  [:entrances, "Entrances", [60, 170, 160]], [:seed, "Seed", [180, 120, 220]]].freeze
      # Shorter names under a heading (as KIF Settings shortens its own), so
      # Wild Encounters' Dynamic Route keeps one line
      SHORT = { :wild_mode => "Encounters" }.freeze
      # Headings on the longer pages (the rows are cody's)
      GROUPS = {
        :pokemon => [["Wild Pokémon", [:wild_mode, :wild_bst, :wild_legend, :wild_custom, :fuse_all, :kr_expanded]],
                     ["Other Pokémon", [:starters, :kr_starters_dynamic, :statics, :kr_statics_dynamic, :gifts, :kr_gifts_dynamic,
                                        :trades, :kr_trades_dynamic, :npc_requests, :kr_requests_dynamic]]],
        :trainers => [["Teams", [:trainers, :kr_teams_dynamic, :trainer_bst, :trainer_custom, :team_size, :trainer_fuse, :unfused, :rival_team]],
                      ["Class Themes", [:class_themes, :theme_shuffle, :extra_themes, :btn_class_theme_list]]],
        :items => [["Items and TMs", [:kr_items_dynamic, :found_items, :found_tms, :given_items, :given_tms, :shop_items, :held_items]],
                   ["Rules", [:keep_categories, :shop_basics, :__ban_items]]],
        :data => [["Types", [:types, :type_orig]], ["Moves", [:kr_learnsets, :kr_learnsets_dynamic, :tms_follow]],
                  ["Abilities", [:abilities, :kr_per_pokemon, :kr_trainer_rolls, :no_selfharm]], ["Base Stats", [:stats, :chaos_safety]]]
      }.freeze
      # The Rolls rows (Dynamic.rb), each one step in under the row it
      # changes: [that row, key, full name, Fixed, Dynamic]
      ROLL_ROWS = [
        [:trainers, :kr_teams_dynamic, "Team Rolls",
         "Every trainer's team is set by the seed: The same team every battle.",
         "Every battle rolls the trainer's team again, so the seed won't give the same teams each time. The rival keeps his with Rival Keeps His Team."],
        [:starters, :kr_starters_dynamic, "Starter Rolls",
         "The seed picks the starters.",
         "The starters are rolled the first time you see them, so the seed won't give the same starters each time."],
        [:statics, :kr_statics_dynamic, "Static Rolls",
         "Each overworld Pokémon is what the seed swapped it to.",
         "Every battle with an overworld Pokémon rolls a new one, so the seed won't give the same ones each time."],
        [:gifts, :kr_gifts_dynamic, "Gift Rolls",
         "Each gift is what the seed swapped it to.",
         "Every gift rolls its own Pokémon when you get it, so the seed won't give the same gifts each time."],
        [:trades, :kr_trades_dynamic, "Trade Rolls",
         "Every trade's Pokémon is set by the seed.",
         "A trade rolls its Pokémon again each time you enter its map, so the seed won't give the same trades each time."],
        [:npc_requests, :kr_requests_dynamic, "Request Rolls",
         "They ask for what the seed swapped the Pokémon to.",
         "They ask for a new Pokémon each time you enter the map, so the seed won't give the same requests each time. Can't find it? Come back later."],
        [:kr_learnsets, :kr_learnsets_dynamic, "Learnset Rolls",
         "Each species has one learnset, set by the seed.",
         "Every Pokémon rolls its own learnset, so the seed won't give the same moves each time: Two Pidgey can learn different moves."]
      ].freeze
      ROLL_KEYS = ROLL_ROWS.map { |row| row[1] }.freeze
      KR_ROWS = ([:kr_learnsets, :kr_per_pokemon, :kr_trainer_rolls, :kr_expanded, :kr_items_dynamic] + ROLL_KEYS).freeze
      # Rows that are one of cody's settings and one of Kanto Reloaded's
      # together, by Kanto Reloaded's key: his key beside it
      JOINED = { :kr_learnsets => :moves_follow, :kr_items_dynamic => :item_mode }.freeze
      # Rows one or two steps in (a tree line to the row above); Door Kinds'
      # rows (ent_k_<kind>) one step in under Which Doors
      INDENT = ROLL_KEYS.map { |k| [k, 1] }.to_h.merge(:kr_per_pokemon => 1, :kr_trainer_rolls => 2).freeze
      # cody's ban lists, by the word after "Banned" in his rows
      BAN_WORDS = { "pokémon" => :pokemon, "moves" => :moves, "abilities" => :abilities, "items" => :items }.freeze
      BAN_NAMES = { :pokemon => "Banned Pokémon", :moves => "Banned Moves", :abilities => "Banned Abilities",
                    :items => "Banned Items" }.freeze
      BAN_DESCS = { :pokemon => "Pokémon the Randomizer never picks: Not as wild, trainer, gift or starter Pokémon, nor as half of a fusion.",
                    :moves => "Moves the Randomizer never gives a Pokémon when its moves are rolled.",
                    :abilities => "Abilities the Randomizer never gives a Pokémon when its abilities are rolled.",
                    :items => "Items that are never a random result. It starts with the items that have no use in PIF." }.freeze
      # cody's values that roll on the spot: what they say gets the seed's line
      # (his Item Mode Dynamic doesn't: it's fixed by the seed and the spot,
      # so it's By Spot here, beside a real Dynamic)
      DYNAMIC_NOTES = { :wild_mode => { 3 => "The seed won't give the same Pokémon each time.",
                                        4 => "The seed won't give the same routes each time: They follow your visits." },
                        :gym_each => { 1 => "The seed won't give the same gym teams each time." },
                        :held_items => { 1 => "The seed won't give the same items each time." } }.freeze
      # Why a row Archipelago holds can't be changed
      AP_WHY = { :entrances => "This save is linked to Archipelago, whose logic needs the normal doors",
                 :npc_requests => "This save is linked to Archipelago, so any Pokémon will do" }.freeze
      AP_ITEMS_WHY = "This save is linked to Archipelago, which places the items itself"

      # Each kind of row: cody's option kept beside it (rkey: his setting's key)
      class REnum < ::EnumOption; attr_accessor :rkey, :label, :full; end
      class RNum < ::NumberOption; attr_accessor :rkey, :label, :full; end
      class RBtn < ::ButtonOption; attr_accessor :rkey, :label, :full; end
      class PartRow < ::ButtonOption; attr_accessor :part, :label, :rkey, :full; end
      class SeedRow < ::ButtonOption; attr_accessor :label, :rkey, :full; end
      # A ban list (its key cody's draft key, :__ban_<kind>, so a new ban
      # waits like any change); get: how many are banned
      class BanRow < ::ButtonOption
        attr_accessor :kind, :label, :rkey, :full
        def get; return ::KIF::Rand.bans(@kind).length; end
      end

      class << self
        def rand
          return ::KIF::Rand
        end

        def collecting?
          return @collecting ? true : false
        end

        # A page's [title, description, options], built by cody's code (his
        # open_page gives the options back while collecting)
        def page(name)
          @collecting = true
          got = rand.send(:"page_#{name}")
          return got.is_a?(Array) && got.length == 3 ? got : nil
        rescue StandardError => e
          Reloaded::Log.exception("The Randomizer's #{name} page couldn't be read", e, :randomizer)
          return nil
        ensure
          @collecting = false
        end

        def pages
          out = {}
          PARTS.each do |part, _name|
            next if part == :entrances && !rand.respond_to?(:page_entrances)
            got = page(part)
            out[part] = got if got
          end
          return out
        end

        #----------------------------------------------------------------------
        # Archipelago
        #----------------------------------------------------------------------
        def ap
          return defined?(::KIF::AP) && ::KIF::AP.respond_to?(:forced) ? ::KIF::AP : nil
        end

        # A row's value as the game uses it: Archipelago's on a linked save
        def held(key)
          return ap ? ap.forced(key) : nil
        rescue StandardError
          return nil
        end

        def lock_reason(key)
          return nil unless key && ap && (ap.on? rescue false) && ap::FORCED.key?(key)
          return AP_WHY[key] || AP_ITEMS_WHY
        end

        #----------------------------------------------------------------------
        # Rows
        #----------------------------------------------------------------------
        # cody's sentence-case names in Title Case (connecting words small)
        def title(s)
          words = s.to_s.strip.sub(/ \*\z/, "").split(" ")
          return words.each_with_index.map { |w, i|
            next w if i > 0 && SMALL.include?(w)
            w.split("-").map { |p| p.empty? ? p : p[0].upcase + p[1..-1] }.join("-")
          }.join(" ")
        end

        def name_of(o)
          return o.label if o.respond_to?(:label) && o.label
          return o.name.to_s
        end

        def key_for(label)
          return :"btn_#{label.downcase.gsub(/[^a-z]+/, "_").sub(/_\z/, "")}"
        end

        # cody's option, as a row of Kanto Reloaded's screen
        def convert(o, part)
          if o.is_a?(rand::MarkedEnum)
            key = o.instance_variable_get(:@kif_key)
            return learnsets_row if key == :moves_follow
            return item_mode_row if key == :item_mode
            return enum(key, title(o.instance_variable_get(:@name)), o.values.map { |v| title(v) },
                        o.instance_variable_get(:@getProc), o.instance_variable_get(:@setProc), noted(key, o.description))
          end
          if o.is_a?(rand::DynButton) && o.description.to_s.include?("base stat total")   # his three-digit Strength Range
            key = part == :pokemon ? :wild_bst : :trainer_bst
            r = RNum.new("Randomizer Strength Range", 0, 999, proc { rand.get(key) }, proc { |v| rand.set(key, v) },
                         o.description.to_s + " " + _INTL("999 = Anything."))
            r.rkey = key
            r.label = r.full = _INTL("Strength Range")
            return r
          end
          if o.is_a?(::ButtonOption)
            raw = o.name.to_s.sub(/ \*\z/, "")
            kind = raw =~ /\ABanned (\S+)/ ? BAN_WORDS[$1.downcase] : nil
            return ban_row(kind) if kind
            label = title(raw.sub(/\s*\(.*\)\z/, ""))
            return button(key_for(label), label, o.description, o.instance_variable_get(:@onPressProc))
          end
          return nil
        end

        def ban_row(kind)
          b = BanRow.new("Randomizer #{BAN_NAMES[kind]}", proc {}, _INTL(BAN_DESCS[kind]))
          b.kind = kind
          b.rkey = :"__ban_#{kind}"
          b.label = b.full = _INTL(BAN_NAMES[kind])
          return b
        end

        #----------------------------------------------------------------------
        # Door Kinds: his seven kinds as rows under Which Doors while it's
        # Custom (in place of his Door Kinds button), each with its doors
        #----------------------------------------------------------------------
        def door_counts
          @door_counts ||= begin
            h = Hash.new(0)
            er = rand::ER
            d = (er.dat rescue nil)
            Array(d && d[:doors]).each { |o| h[[o[:region] || 0, er.door_kind(o)]] += 1 }
            h
          end
        end

        def door_rows
          r = rand
          counts = door_counts
          r::ENT_KINDS.map do |k, name|
            key = :"ent_k_#{k}"
            more = []
            more << [_INTL("{1} more in Johto with And Johto?", counts[[1, k]])] if counts[[1, k]] > 0
            more << [_INTL("{1} in Sevii with And Sevii?", counts[[2, k]])] if counts[[2, k]] > 0
            tail = more.empty? ? "" : " (#{more.flatten.join(", ")})"
            doors = _INTL("{1} doors in Kanto{2}.", counts[[0, k]], tail)
            d = r::KIND_DESCS[k] || ["", ""]
            enum(key, title(name), [_INTL("Off"), _INTL("On")], proc { r.get(key) }, proc { |v| r.set(key, v) },
                 ["#{_INTL(d[0])} #{doors}", "#{_INTL(d[1])} #{doors}"])
          end
        end

        def door_kind?(key)
          return key.to_s.start_with?("ent_k_")
        end

        # Which Doors is Custom with every kind Off: nothing is shuffled
        def no_doors?(opt)
          return false unless opt.respond_to?(:rkey) && (opt.rkey == :ent_doors || door_kind?(opt.rkey))
          r = rand
          return r.dget(:ent_doors) == 3 && r::ER.custom_kinds.empty?
        rescue StandardError
          return false
        end

        def indent_of(key)
          return 1 if door_kind?(key)
          return INDENT[key].to_i
        end

        # His descriptions, with the seed's line on a value that rolls on the
        # spot
        def noted(key, desc)
          notes = DYNAMIC_NOTES[key]
          return desc unless notes && desc.is_a?(Array)
          return desc.each_with_index.map { |d, i| notes[i] ? "#{d.to_s.strip} #{_INTL(notes[i])}" : d }
        end

        # His descriptions are found by an option's name in KIF Settings: each
        # row gets a name of its own ("Randomizer Types"), its label is shown
        def enum(key, label, values, get, set, desc)
          if ap && ap::FORCED.key?(key)
            own = get
            get = proc { h = Reloaded::Randomizer::Rows.held(key); h.nil? ? own.call : h }
          end
          r = REnum.new("Randomizer #{label}", values, get, set, desc)
          r.rkey = key
          r.label = SHORT[key] || label
          r.full = label
          return r
        end

        def button(key, label, desc, press = nil)
          b = RBtn.new("Randomizer #{label}", press || proc {}, desc)
          b.rkey = key
          b.label = b.full = label
          return b
        end

        # Kanto Reloaded's rows
        def learnsets_row
          z = Reloaded::Randomizer
          return enum(:kr_learnsets, _INTL("Learnsets"), z::LEARNSETS.map { |v| _INTL(v) },
                      proc { z.learnsets }, proc { |v| z.learnsets = v },
                      [_INTL("Level-up moves stay the same."),
                       _INTL("Moves of a Pokémon's old type become its new type's: Same level, similar power. Needs Types on Random or Dual."),
                       _INTL("Every level-up move is rolled again: Same level, same kind (physical, special or status), similar power. Fusions follow.")])
        end

        # His Item Mode, with Dynamic made real: his Dynamic (each spot rolls
        # its own item, fixed by the seed) is By Spot
        def item_mode_row
          z = Reloaded::Randomizer
          return enum(:kr_items_dynamic, _INTL("Item Mode"), z::ITEM_MODES.map { |v| _INTL(v) },
                      proc { z.item_mode }, proc { |v| z.item_mode = v },
                      [_INTL("Each item always becomes the same other item (every Potion is a Lure)."),
                       _INTL("Every item ball, gift and shop rolls its own item. The same spot always gives the same item."),
                       _INTL("Every item ball and gift rolls its item when you get it, so the seed won't give the same items each time. Shops stay By Spot.")])
        end

        def per_pokemon_row
          z = Reloaded::Randomizer
          return enum(:kr_per_pokemon, _INTL("Per Pokémon"), [_INTL("Off"), _INTL("On")],
                      proc { z.get(:kr_per_pokemon) }, proc { |v| z.set(:kr_per_pokemon, v) },
                      [_INTL("Each species has its abilities (Abilities, above)."),
                       _INTL("Every Pokémon rolls its own ability from the Abilities pool, fixed by the seed. Abilities only one Pokémon can use stay with it.")])
        end

        # Under Per Pokémon: trainers' rolls
        def trainer_rolls_row
          z = Reloaded::Randomizer
          r = REnum.new("Randomizer Trainer Abilities", [_INTL("Fixed"), _INTL("Dynamic")],
                        proc { z.get(:kr_trainer_rolls) }, proc { |v| z.set(:kr_trainer_rolls, v) },
                        [_INTL("Trainers' Pokémon roll the same abilities every battle, set by the seed."),
                         _INTL("Trainers' Pokémon roll new abilities every battle, so the seed won't give the same ones each time.")])
          r.rkey = :kr_trainer_rolls
          r.label = _INTL("Trainers")
          r.full = _INTL("Trainer Abilities")
          return r
        end

        # A Rolls row: Fixed / Dynamic (its own name for KIF Settings' search)
        def rolls_row(key, full, fixed, dynamic)
          z = Reloaded::Randomizer
          r = REnum.new("Randomizer #{full}", [_INTL("Fixed"), _INTL("Dynamic")],
                        proc { z.get(key) }, proc { |v| z.set(key, v) }, [_INTL(fixed), _INTL(dynamic)])
          r.rkey = key
          r.label = _INTL("Rolls")
          r.full = _INTL(full)
          return r
        end

        # Each Rolls row (and Trainers under Per Pokémon) in after its row
        def add_rolls(opts)
          ROLL_ROWS.each do |parent, key, full, fixed, dynamic|
            i = opts.index { |o| o.rkey == parent }
            opts.insert(i + 1, rolls_row(key, full, fixed, dynamic)) if i
          end
          if (i = opts.index { |o| o.rkey == :kr_per_pokemon })
            opts.insert(i + 1, trainer_rolls_row)
          end
          return opts
        end

        # Why a Kanto Reloaded row can't be changed now (its row above says
        # it doesn't apply), or nil
        def kr_why(key)
          return nil unless key.is_a?(Symbol) && key.to_s.start_with?("kr_")
          z = Reloaded::Randomizer
          r = rand
          case key
          when :kr_per_pokemon, :kr_trainer_rolls
            return "Abilities is Same: There's no pool to roll from" if r.dget(:abilities) == 0
            return "Per Pokémon is Off: Each species keeps its abilities" if key == :kr_trainer_rolls && !z.per_pokemon?
          when :kr_teams_dynamic
            return "Trainers is Off: There are no teams to roll" if cur(:trainers) == 0
            return "Trainers is on Follow Wild: Teams follow the wild Pokémon" if cur(:trainers) == 2
          when :kr_starters_dynamic
            return "Starters is Off: The starters aren't randomized" if cur(:starters) == 0
          when :kr_statics_dynamic
            return "Static Encounters is Off: They aren't randomized" if cur(:statics) == 0
          when :kr_gifts_dynamic
            return "Gift Pokémon is Off: They aren't randomized" if cur(:gifts) == 0
          when :kr_trades_dynamic
            return "Trades isn't on Random: Only random trades roll again" if cur(:trades) != 2
          when :kr_requests_dynamic
            return "NPC Requests isn't on Swapped: Only swapped requests roll again" if cur(:npc_requests) != 1
          when :kr_learnsets_dynamic
            return "Learnsets isn't on Random: Only random learnsets roll again" if z.learnsets != 2
          end
          return nil
        rescue StandardError
          return nil
        end

        def expanded_row
          z = Reloaded::Randomizer
          return enum(:kr_expanded, _INTL("Expanded Dex"), [_INTL("Off"), _INTL("In Pools")],
                      proc { z.get(:kr_expanded) }, proc { |v| z.set(:kr_expanded, v) },
                      [_INTL("Only the base game's Pokémon are picked."),
                       _INTL("The Expanded Pokédex's Pokémon can be picked too.")])
        end

        def row(opt, sec, head, indent = 0)
          return ::KIF::SettingsScreen::Row.new(:opt, opt, nil, name_of(opt), sec, head, indent, nil, nil)
        end

        def head(label, sec)
          return ::KIF::SettingsScreen::Row.new(:head, nil, nil, label, sec, label, 0, nil, nil)
        end

        # Every section's rows
        def build
          @pages = pages
          out = {}
          out[:overview] = PARTS.select { |part, _n| @pages[part] }.map do |part, name|
            p = PartRow.new("Randomizer #{name}", proc {}, @pages[part][1])
            p.part = part
            p.label = p.full = _INTL(name)
            p.rkey = :"part_#{part}"
            row(p, :overview, nil)
          end
          PARTS.each do |part, _name|
            next unless @pages[part]
            opts = @pages[part][2].map { |o| convert(o, part) }.compact
            opts << expanded_row if part == :pokemon && Reloaded::Randomizer.expanded_from
            if part == :data && (i = opts.index { |o| o.rkey == :abilities })
              opts.insert(i + 1, per_pokemon_row)
            end
            add_rolls(opts)
            if (i = opts.index { |o| o.rkey == :btn_door_kinds })
              opts.delete_at(i)
              w = opts.index { |o| o.rkey == :ent_doors }
              opts.insert(w + 1, *door_rows) if w && rand.dget(:ent_doors) == 3
            end
            groups = GROUPS[part]
            unless groups
              out[part] = opts.map { |o| row(o, part, nil, indent_of(o.rkey)) }
              next
            end
            list = []
            placed = []
            groups.each do |label, keys|
              mine = keys.map { |k| opts.find { |o| o.rkey == k } }.compact
              next if mine.empty?
              list << head(_INTL(label), part)
              mine.each { |o| list << row(o, part, _INTL(label), indent_of(o.rkey)) }
              placed.concat(mine)
            end
            (opts - placed).each { |o| list << row(o, part, nil, indent_of(o.rkey)) }
            out[part] = list
          end
          out[:seed] = seed_rows
          return out
        end

        def seed_rows
          seed = SeedRow.new("Randomizer Seed", proc {}, _INTL("Same seed and settings, same game. A seed is 8 letters and numbers (no I, O, 0 or 1)."))
          seed.label = seed.full = _INTL("Seed")
          seed.rkey = :seed
          code = button(:btn_settings_code, _INTL("Settings Code"),
                        _INTL("Copy the seed and every setting as one line to share, or paste one from a friend."), proc {})
          log = enum(:log, _INTL("Spoiler Log"), [_INTL("Off"), _INTL("On")], proc { rand.log_on? ? 1 : 0 }, proc { |v| rand.data[:log] = (v == 1) },
                     [_INTL("No spoiler log is written."),
                      _INTL("Writes \"Randomizer Log - <seed>.txt\" in the Randomizer/Logs folder (on a phone, in the save folder).")])
          view = button(:btn_view_log, _INTL("View Spoiler Log"), _INTL("Shows everything that was randomized (asks first)."),
                        proc { rand.view_log })
          return [row(seed, :seed, nil), row(code, :seed, nil), row(log, :seed, nil), row(view, :seed, nil)]
        end

        def section_help(id)
          return @pages && @pages[id] ? @pages[id][1].to_s : nil
        end

        #----------------------------------------------------------------------
        # Waiting (cody's draft: changed since the last Randomize Now)
        #----------------------------------------------------------------------
        def drafting?
          return !rand.applied_state.nil?
        end

        def waiting_key?(key)
          return false unless drafting? && key
          return false if key.to_s.start_with?("btn_", "part_") || key == :seed || key == :log
          return rand.changed?(key) || rand.changed?(JOINED[key]) if JOINED[key]
          return rand.changed?(key)
        rescue StandardError
          return false
        end

        def waiting?(opt)
          return false unless opt.respond_to?(:rkey) && opt.rkey
          return part_waiting?(opt.part) if opt.is_a?(PartRow)
          return waiting_key?(opt.rkey)
        end

        def part_rows(rows, part)
          return (rows[part] || []).select { |r| r.kind == :opt }
        end

        def part_waiting?(part, rows = @rows)
          return part_rows(rows || {}, part).any? { |r| r.opt.respond_to?(:rkey) && waiting_key?(r.opt.rkey) }
        end

        attr_writer :rows

        def waiting(rows)
          return PARTS.flat_map { |part, _n| part_rows(rows, part) }.select { |r| r.opt.respond_to?(:rkey) && waiting_key?(r.opt.rkey) }
        end

        # The value a waiting row has in the game now (cody's applied draft;
        # a ban list: how many)
        def applied(key)
          state = rand.applied_state || {}
          return Array(state[key]).length if key.to_s.start_with?("__ban_")
          if key == :kr_learnsets
            return 2 if state[:kr_learnsets].to_i == 1
            return state[:moves_follow].to_i == 1 ? 1 : 0
          end
          if key == :kr_items_dynamic
            spot = state[:item_mode].to_i == 1
            return spot && state[:kr_items_dynamic].to_i == 1 ? 2 : (spot ? 1 : 0)
          end
          return rand.as_int(state[key], 0)
        end

        def shown(opt, v = nil)
          v = (opt.get rescue 0) if v.nil?
          return opt.values[v.to_i].to_s if opt.respond_to?(:values) && opt.values.is_a?(Array)
          return v.to_s
        end

        def cur(key)
          h = held(key)
          return h.nil? ? rand.get(key) : h
        end

        # [state, on?] for a part (the Overview's values)
        def part_state(part)
          r = rand
          case part
          when :pokemon
            m = r.get(:wild_mode)
            return [_INTL(["Off", "Swap", "Route", "Dynamic", "Dynamic Route"][m] || "On"), true] if m > 0
            some = r.get(:starters) > 0 || r.get(:statics) == 1 || r.get(:gifts) == 1 || r.get(:trades) > 0
            return some ? [_INTL("Some"), true] : [_INTL("Off"), false]
          when :trainers
            t = r.get(:trainers)
            return [_INTL(["Off", "Random", "Follow Wild"][t] || "On"), t > 0]
          when :gyms
            return r.get(:gyms) == 1 || r.get(:gym_types) == 1 ? [_INTL("On"), true] : [_INTL("Off"), false]
          when :items
            on = [:found_items, :found_tms, :given_items, :given_tms, :shop_items, :held_items].any? { |k| cur(k) > 0 }
            return on ? [_INTL(Reloaded::Randomizer::ITEM_MODES[Reloaded::Randomizer.item_mode]), true] : [_INTL("Off"), false]
          when :data
            on = r.data_on? || Reloaded::Randomizer.per_pokemon?
            return on ? [_INTL("Custom"), true] : [_INTL("Same"), false]
          when :evolutions
            return r.dget(:evolutions) > 0 ? [_INTL("Random"), true] : [_INTL("Same"), false]
          when :exclusions
            custom = [:pokemon, :moves, :abilities].any? { |k| !r.bans(k).empty? }
            return custom ? [_INTL("Custom"), true] : [_INTL("Default"), false]
          when :entrances
            e = (r.get(:entrances) rescue 0).to_i
            return [_INTL(["Off", "Simple", "Full"][e] || "On"), e > 0]
          end
          return ["", false]
        end

        # A part's settings that aren't at their default: [[name, value,
        # waiting]]
        def summary(rows, part)
          out = []
          part_rows(rows, part).each do |r|
            o = r.opt
            next unless o.is_a?(REnum) || o.is_a?(BanRow)
            v = (o.get rescue 0).to_i
            default = if o.is_a?(BanRow) then o.kind == :items ? rand.default_item_bans.length : 0
                      elsif KR_ROWS.include?(o.rkey) then Reloaded::Randomizer::KEYS[o.rkey] || 0
                      else rand::DATA_DEFAULTS[o.rkey] || 0
                      end
            w = waiting_key?(o.rkey)
            next if v == default && !w
            out << [o.full || o.label, shown(o, v), w]
          end
          return out
        end
      end
    end
  end
end
