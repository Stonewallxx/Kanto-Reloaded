# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Reloaded Bag (its order, NEW, Favorites)
#==============================================================================
# Roadmap topic bag (decided 2026-10-17; the Next feature discussion and
# picks 2026-10-23). Old Kanto Reloaded's real pocket sorting with Hoenn
# Reloaded's screen, in Reloaded's look (UI/BagScene.rb draws it; the game's
# own PokemonBagScreen still does what's picked).
#
#   Auto-Sort   each pocket's real order (the "Bag - Auto-Sort" page in the
#               Kanto Reloaded section, each save its own): Off, Custom
#               List, A-Z or Number. A new kind of item is placed as it
#               comes. Sorted in place, so the game and other mods keep the
#               same pocket
#   Custom      a list per pocket, kept by the save; old Kanto Reloaded's
#   Lists       curated order to start (DefaultLists.rb). Headings of the
#               player's own ("#Name") sort nothing. Moving an item by
#               hand in a Custom List pocket rewrites the list (his ask);
#               the editor is UI/BagListScreen.rb
#   Export      every pocket's list, favorites and Auto-Sort to a text file
#   Import      in the mod folder (Exports\Bag Lists.txt; old Kanto
#               Reloaded's file reads too) and back
#   Views       what the screen shows (R): Bag Order, A-Z, Quantity, Type,
#               Number, Recent; per pocket, Favorites first, then NEW
#               items where New Items puts them (In Place, First, Last).
#               Only the screen's order: the real Bag doesn't change
#   NEW         an item the Bag didn't have the last time you looked;
#               leaving its pocket in the full Bag clears it (pickers never
#               do). More of something you had isn't NEW
#   Favorites   a star, first in every view
#   Legacy      the first time a save with Kanto Reloaded Legacy's lists
#               loads, its lists, favorites and Auto-Sort modes come in
#
# The save keeps it (SaveStore section "bag"); nothing is kept on
# $PokemonBag itself (KIF's Self-Battle copies it).
#
#   Reloaded::Bag.mode(2)            # 0 Off, 1 Custom List, 2 A-Z, 3 Number
#   Reloaded::Bag.custom_list(2)     # the pocket's Custom List (item ids)
#   Reloaded::Bag.rows(2, view)      # the pocket's item ids as the screen shows them
#   Reloaded::Bag.new?(:POTION) / favorite?(:POTION)
#==============================================================================

module Reloaded
  module Bag
    FEATURE = :reloaded_bag
    SECTION = :bag
    PAGE = :bag
    SORT_PAGE = :bag_sort
    MODES = ["Off", "Custom List", "A-Z", "Number"].freeze
    NEW_PLACES = ["In Place", "First", "Last"].freeze
    START_LISTS = ["Plain", "With Sections"].freeze
    VIEWS = ["Bag Order", "A-Z", "Quantity", "Type", "Number", "Recent"].freeze
    # the game's TMs & HMs and Berries sort by number (BAG_POCKET_AUTO_SORT)
    NUMBER_POCKETS = [4, 5].freeze
    POCKET_NAMES = ["Items", "Medicine", "Poké Balls", "TMs & HMs", "Berries", "Mail", "Battle Items", "Key Items"].freeze
    HEADING = "#"          # a Custom List entry starting with it is a heading
    HEADING_MAX = 20
    LEGACY_KEY = :kanto_reloaded
    LEGACY_POCKETS = { "items" => 1, "medicine" => 2, "pok_balls" => 3, "tms_hms" => 4, "berries" => 5,
                       "mail" => 6, "battle_items" => 7, "key_items" => 8 }.freeze
    LEGACY_SETTINGS = "KantoReloadedSettings.json"
    EXPORT_FILE = "Bag Lists.txt"
    # old Kanto Reloaded's export (Kanto Reloaded Legacy's folder), read by Import too
    LEGACY_EXPORT = ["KantoReloadedLegacy", "Exports", "AutosortBag_lists.txt"].freeze

    @legacy = nil        # the loading save's Kanto Reloaded Legacy data (its :kanto_reloaded value)

    class << self
      def boot
        Reloaded::Features.register(FEATURE, :name => "Reloaded Bag", :order => 29, :page => PAGE,
          :description => "A new Bag with real pocket sorting, Search, NEW, Favorites, views and who can use each TM. Off brings back the game's own Bag.")
        Reloaded::SaveStore.register(SECTION)
        register_settings
        Reloaded::Events.on(:save_loaded, :bag_sync, 70) { sync! }
        Reloaded::Events.on(:new_game, :bag_sync, 70) { sync! }
        install
        return true
      end

      def on?
        return Reloaded::Features.on?(FEATURE)
      end

      #------------------------------------------------------------------------
      # The pockets
      #------------------------------------------------------------------------
      def pockets
        n = defined?(::PokemonBag) && ::PokemonBag.respond_to?(:numPockets) ? ::PokemonBag.numPockets : 8
        return (1..n).to_a
      end

      def pocket_name(pocket)
        names = defined?(::Settings) && ::Settings.respond_to?(:bag_pocket_names) ? ::Settings.bag_pocket_names : nil
        return (names && names[pocket]).to_s
      end

      def mode(pocket)
        return Reloaded::Settings.get(:"bag.mode#{pocket}").to_i
      end

      def new_place
        return Reloaded::Settings.get(:"bag.new_items").to_i
      end

      # Moving by hand: in an Off or Custom List pocket (his pick, 2026-10-23)
      def can_move?(pocket)
        return [0, 1].include?(mode(pocket))
      end

      #------------------------------------------------------------------------
      # The save's data
      #------------------------------------------------------------------------
      def data
        return Reloaded::SaveStore.section(SECTION)
      rescue StandardError
        return nil
      end

      # The pocket's Custom List (item id strings and "#Name" headings), old
      # Kanto Reloaded's to start
      def custom_list(pocket)
        d = data
        saved = d && d["lists"] && d["lists"][pocket.to_s]
        return (saved || default_list(pocket)).map(&:to_s)
      end

      # The list a pocket starts with: old Kanto Reloaded's, or the same
      # items under headings (Starting Lists, his ask)
      def default_list(pocket)
        sectioned = Reloaded::Settings.get(:"bag.start_lists").to_i == 1 rescue false
        list = (sectioned && SECTIONED_LISTS[pocket.to_i]) || DEFAULT_LISTS[pocket.to_i] || []
        return list.map(&:to_s)
      end

      # Each item once; headings may repeat
      def set_list(pocket, ids, apply = true)
        d = data
        return false unless d
        seen = {}
        clean = Array(ids).map(&:to_s).select { |e| heading?(e) ? e.length > HEADING.length : !seen[e] && (seen[e] = true) }
        (d["lists"] ||= {})[pocket.to_s] = clean
        sort_pocket!(pocket) if apply
        return true
      end

      def heading?(entry)
        return entry.to_s.start_with?(HEADING)
      end

      # (no # or // in a name: the export file reads them as notes)
      def heading(name)
        return HEADING + name.to_s.gsub(%r{#|//}, "").strip[0, HEADING_MAX].to_s
      end

      def heading_name(entry)
        return entry.to_s[HEADING.length..-1].to_s
      end

      # Back to old Kanto Reloaded's list (the editor's Defaults)
      def restore_list(pocket)
        return set_list(pocket, default_list(pocket))
      end

      def favorites(pocket)
        d = data
        return d && d["favorites"] ? Array(d["favorites"][pocket.to_s]).map(&:to_s) : []
      end

      def favorite?(item)
        it = item_data(item)
        return it ? favorites(it.pocket).include?(it.id.to_s) : false
      end

      def set_favorites(pocket, ids)
        d = data
        (d["favorites"] ||= {})[pocket.to_s] = Array(ids).map(&:to_s).uniq if d
      end

      def toggle_favorite(item)
        it = item_data(item)
        d = data
        return false unless it && d
        favs = favorites(it.pocket)
        key = it.id.to_s
        (d["favorites"] ||= {})[it.pocket.to_s] = favs.include?(key) ? favs - [key] : favs + [key]
        return favorite?(it.id)
      end

      def view(pocket)
        d = data
        return d && d["views"] ? d["views"][pocket.to_s].to_i.clamp(0, VIEWS.length - 1) : 0
      end

      def set_view(pocket, index)
        d = data
        (d["views"] ||= {})[pocket.to_s] = index.to_i % VIEWS.length if d
      end

      # When it came (bigger: later); 0 for what was there before
      def added_at(item)
        d = data
        return d && d["added"] ? d["added"][item.to_s].to_i : 0
      end

      #------------------------------------------------------------------------
      # NEW
      #------------------------------------------------------------------------
      # Every item id the Bag holds now
      def held(bag = $PokemonBag)
        out = []
        pockets.each { |p| slots(bag, p).each { |s| out << s[0].to_s if s && s[0] } }
        return out.uniq
      end

      # When the full Bag opens: what's gone drops out of what's been seen
      # (so getting it back is NEW again); the first time, everything there
      # counts as seen
      def refresh_seen!(bag = $PokemonBag)
        d = data
        return unless d && bag
        now = held(bag)
        d["seen"] = d.key?("seen") ? Array(d["seen"]) & now : now
      end

      def new?(item)
        d = data
        return false unless d && d.key?("seen")
        return !Array(d["seen"]).include?(item.to_s)
      end

      def pocket_new?(pocket, bag = $PokemonBag)
        return slots(bag, pocket).any? { |s| s && new?(s[0]) }
      end

      # Leaving a pocket in the full Bag: what's in it has been seen
      def seen!(pocket, bag = $PokemonBag)
        d = data
        return unless d
        ids = slots(bag, pocket).map { |s| s[0].to_s if s }.compact
        d["seen"] = (Array(d["seen"]) | ids)
      end

      #------------------------------------------------------------------------
      # Sorting
      #------------------------------------------------------------------------
      def slots(bag, pocket)
        p = bag && bag.respond_to?(:pockets) ? bag.pockets : nil
        return p && p[pocket].is_a?(Array) ? p[pocket] : []
      end

      def item_data(item)
        return nil if item.nil?
        return ::GameData::Item.try_get(item.is_a?(String) ? item.to_sym : item)
      rescue StandardError
        return nil
      end

      def item_name(item)
        it = item_data(item)
        return it ? it.name.to_s : item.to_s
      rescue StandardError
        return item.to_s
      end

      def number(item)
        it = item_data(item)
        return it && it.respond_to?(:id_number) ? it.id_number.to_i : 0
      end

      # The pocket's real order, in place (the game, the battle Bag, other
      # mods all see the same pocket)
      def sort_pocket!(pocket, bag = $PokemonBag)
        list = slots(bag, pocket)
        return false if list.length < 2
        sorted = case mode(pocket)
                 when 1 then custom_sorted(pocket, list)
                 when 2 then stable(list) { |s| [item_name(s[0]).downcase] }
                 when 3 then stable(list) { |s| [number(s[0])] }
                 else return false
                 end
        list.replace(sorted)
        return true
      rescue StandardError => e
        Reloaded::Log.exception("The Bag couldn't sort pocket #{pocket}", e, :bag)
        return false
      end

      def sort_all!(bag = $PokemonBag)
        pockets.each { |p| sort_pocket!(p, bag) }
      end

      # The list's order first; what isn't on it after, A-Z
      def custom_sorted(pocket, list)
        rank = {}
        custom_list(pocket).each_with_index { |id, i| rank[id] ||= i }
        return stable(list) { |s| r = rank[s[0].to_s]; r ? [0, r, ""] : [1, 0, item_name(s[0]).downcase] }
      end

      def stable(list)
        return list.each_with_index.sort_by { |s, i| yield(s) + [i] }.map(&:first)
      end

      # A store made a new slot (a new kind of item): it's placed by the
      # pocket's Auto-Sort (an Off pocket: where the game put it)
      def after_store(bag, item)
        it = item_data(item)
        return unless it && bag
        d = data
        if d
          d["counter"] = d["counter"].to_i + 1
          (d["added"] ||= {})[it.id.to_s] = d["counter"]
        end
        sort_pocket!(it.pocket.to_i, bag)
      rescue StandardError => e
        Reloaded::Log.exception("The Bag couldn't place #{item}", e, :bag)
      end

      # Moving by hand (an Off or Custom List pocket): the slot from one place
      # to another; in a Custom List pocket the list follows
      def move(pocket, from, to, bag = $PokemonBag)
        return false unless can_move?(pocket)
        list = slots(bag, pocket)
        return false unless from.between?(0, list.length - 1) && to.between?(0, list.length - 1) && from != to
        slot = list.delete_at(from)
        list.insert(to, slot)
        rewrite_list(pocket, list, to) if mode(pocket) == 1
        return true
      end

      # The moved item goes in the list just before the one now after it
      # (or after the one before it); the list's other items keep their
      # places
      def rewrite_list(pocket, list, at)
        id = list[at][0].to_s
        ids = custom_list(pocket) - [id]
        after = list[at + 1] && list[at + 1][0].to_s
        before = at > 0 ? list[at - 1][0].to_s : nil
        pos = if after && ids.index(after) then ids.index(after)
              elsif before && ids.index(before) then ids.index(before) + 1
              else ids.length
              end
        ids.insert(pos, id)
        set_list(pocket, ids, false)
      end

      #------------------------------------------------------------------------
      # Views (the screen's order only)
      #------------------------------------------------------------------------
      # The pocket's item ids as the screen shows them: Favorites first,
      # NEW items where New Items puts them (until they've been seen), then
      # the view
      def rows(pocket, view_index = view(pocket), bag = $PokemonBag)
        list = slots(bag, pocket).compact
        place = new_place
        keyed = list.each_with_index.map do |s, i|
          id = s[0]
          key = case VIEWS[view_index]
                when "A-Z" then [item_name(id).downcase]
                when "Quantity" then [-s[1].to_i, item_name(id).downcase]
                when "Type" then [type_key(id), item_name(id).downcase]
                when "Number" then [number(id)]
                when "Recent" then [-added_at(id), i]
                else [i]
                end
          fresh = place > 0 && new?(id) ? (place == 1 ? 0 : 2) : 1
          [[favorite?(id) ? 0 : 1, fresh] + key + [i], id]
        end
        return keyed.sort_by(&:first).map(&:last)
      end

      # A Custom List pocket in Bag Order, with the list's headings (his ask,
      # 2026-10-23): [heading name (a String) | item id]. Favorites under
      # their own heading (favorites_apart; else in their places), NEW ones
      # New Items puts first or last under New, then each heading's items
      # in the list's order, then what isn't on the list. nil when the
      # pocket shows none (not Custom List, another view, no headings).
      def sectioned(pocket, ids, favorites_apart = true)
        return nil unless mode(pocket) == 1 && view(pocket) == 0
        list = custom_list(pocket)
        return nil unless list.any? { |e| heading?(e) }
        under = {}            # item => the place of its heading in the list (-1: before the first)
        names = { -1 => nil }
        current = -1
        list.each_with_index do |e, i|
          if heading?(e)
            current = i
            names[i] = heading_name(e)
          else
            under[e] = current unless under.key?(e)
          end
        end
        place = new_place
        groups = {}
        ids.each do |id|
          key = if favorites_apart && favorite?(id) then :favorites
                elsif place > 0 && new?(id) then (place == 1 ? :new_first : :new_last)
                elsif under.key?(id.to_s) then [:section, under[id.to_s]]
                else :other
                end
          (groups[key] ||= []) << id
        end
        out = []
        emit = proc do |title, items|
          next if items.nil? || items.empty?
          out << title if title
          out.concat(items)
        end
        emit.call(_INTL("Favorites"), groups[:favorites])
        emit.call(_INTL("New"), groups[:new_first])
        groups.keys.select { |k| k.is_a?(Array) }.sort_by { |k| k[1] }.each { |k| emit.call(names[k[1]], groups[k]) }
        emit.call(_INTL("Not on Your List"), groups[:other])
        emit.call(_INTL("New"), groups[:new_last])
        return out
      end

      # A TM's move type (in the game's order), else the item's kind
      def type_key(id)
        it = item_data(id)
        return 999 unless it
        if it.respond_to?(:is_machine?) && it.is_machine? && it.move
          return Reloaded::PartyPaint.type_row(::GameData::Move.get(it.move).type) if defined?(Reloaded::PartyPaint)
        end
        return it.respond_to?(:type) ? it.type.to_i : 999
      rescue StandardError
        return 999
      end

      #------------------------------------------------------------------------
      # A save loading
      #------------------------------------------------------------------------
      def sync!
        d = data
        return unless d
        import_legacy!(d)
        d["started"] = true
      rescue StandardError => e
        Reloaded::Log.exception("The Bag couldn't read the save", e, :bag)
      end

      # Kanto Reloaded Legacy's lists, favorites and Auto-Sort modes, once
      # (his pick, 2026-10-23)
      def import_legacy!(d)
        legacy = @legacy
        @legacy = nil
        return if d["legacy"] || !legacy.is_a?(Hash)
        systems = legacy[:systems] || legacy["systems"]
        own = systems.is_a?(Hash) ? (systems["autosort_bag"] || systems[:autosort_bag]) : nil
        return unless own.is_a?(Hash)
        lists = own["lists"] || own[:lists]
        favs = own["favorites"] || own[:favorites]
        count = 0
        { "lists" => lists, "favorites" => favs }.each do |field, src|
          next unless src.is_a?(Hash)
          src.each do |key, ids|
            pocket = LEGACY_POCKETS[key.to_s]
            next unless pocket && ids.is_a?(Array)
            clean = ids.map { |e| legacy_entry(e, field == "lists") }.compact
            (d[field] ||= {})[pocket.to_s] = clean
            count += 1
          end
        end
        modes = import_legacy_modes
        d["legacy"] = true
        Reloaded::Log.info("Brought in Kanto Reloaded Legacy's Bag lists (#{count} lists, #{modes} Auto-Sort modes)", :bag)
      end

      # A Legacy list entry: an item id, or its separator ([:__SEPARATOR__,
      # name]) as a heading; nil when KIF hasn't the item
      def legacy_entry(entry, headings)
        if entry.is_a?(Array)
          return headings && entry[0].to_s == "__SEPARATOR__" ? heading(entry[1].to_s.empty? ? "Heading" : entry[1]) : nil
        end
        id = entry.to_s
        return item_data(id) || id.start_with?("KURAYEGG") ? id : nil
      end

      # Legacy kept its modes in its own settings file (0 Off, 1 Custom List,
      # 2 Alphabetical): once, while ours are still as they start
      def import_legacy_modes
        s = Reloaded::Settings
        return 0 if s.get(:"bag.legacy_modes")
        folder = defined?(::RTP) && ::RTP.respond_to?(:getSaveFolder) ? (::RTP.getSaveFolder rescue nil) : nil
        path = folder ? File.join(folder, LEGACY_SETTINGS) : nil
        text = path && File.file?(path) ? Reloaded::Paths.read_text(path) : nil
        values = text ? ((Reloaded::JSON.parse(text) rescue {}) || {})["values"] : nil
        n = 0
        if values.is_a?(Hash)
          LEGACY_POCKETS.each do |key, pocket|
            v = values["autosort_bag_mode_#{key}"]
            next if v.nil?
            s.set(:"bag.mode#{pocket}", [0, 1, 2][v.to_i] || 0)
            n += 1
          end
        end
        s.set(:"bag.legacy_modes", true)
        return n
      rescue StandardError => e
        Reloaded::Log.exception("The Bag couldn't read Kanto Reloaded Legacy's settings", e, :bag)
        return 0
      end

      #------------------------------------------------------------------------
      # Export and Import (old Kanto Reloaded's text file, which reads too)
      #------------------------------------------------------------------------
      def export_path
        return File.join(Reloaded::Paths.local_dir, "Exports", EXPORT_FILE)
      end

      # Ours, else old Kanto Reloaded's (in Kanto Reloaded Legacy's folder)
      def import_path
        legacy = File.join(Reloaded::Paths.game_dir, "Mods", *LEGACY_EXPORT)
        return [export_path, legacy].find { |p| File.file?(p) }
      end

      # Every pocket's list (headings, * Favorites), Auto-Sort and New Items.
      # The file's path.
      def export_lists
        lines = ["# Kanto Reloaded: Bag Lists",
                 "# One item ID per line; * before one marks a Favorite; -- Name -- is a heading.",
                 "# Anything after # or // on a line is a note. Import Lists (Kanto Reloaded > Bag) reads it back.",
                 "", "[Settings]", "New Items = #{NEW_PLACES[new_place]}"]
        pockets.each { |p| lines << "#{file_pocket_name(p)} = #{MODES[mode(p)]}" }
        pockets.each do |p|
          favs = favorites(p)
          lines << "" << "[#{file_pocket_name(p)}]"
          custom_list(p).each do |e|
            lines << (heading?(e) ? "-- #{heading_name(e)} --" : "#{favs.include?(e) ? '* ' : ''}#{e}")
          end
          (favs - custom_list(p)).each { |id| lines << "* #{id}" }
        end
        path = export_path
        Reloaded::Paths.write_atomic(path, lines.join("\r\n") + "\r\n")
        Reloaded::Log.info("Exported the Bag's lists to #{path}", :bag)
        return path
      end

      # The file's lists, favorites and settings, replacing the ones it has
      # (pockets it leaves out keep theirs). { :pockets, :ignored, :file }, or
      # nil when there's no file or nothing in it.
      def import_lists(path = import_path)
        text = path ? Reloaded::Paths.read_text(path) : nil
        return nil unless text
        parsed = parse_lists(text.sub(/\A﻿/, ""))
        return nil if parsed[:lists].empty? && parsed[:settings].empty?
        s = Reloaded::Settings
        parsed[:settings].each { |key, value| s.set(key, value) }
        parsed[:lists].each do |pocket, entries|
          set_list(pocket, entries, false)
          set_favorites(pocket, parsed[:favorites][pocket] || [])
        end
        sort_all! if $PokemonBag
        Reloaded::Log.info("Imported the Bag's lists from #{path} (#{parsed[:lists].length} pockets, #{parsed[:ignored]} ignored)", :bag)
        return { :pockets => parsed[:lists].length, :ignored => parsed[:ignored], :file => File.basename(path) }
      end

      # What's in a file, without bringing it in (Import asks with it):
      # { :pockets, :items, :headings, :favorites, :time }, or nil
      def peek_lists(path = import_path)
        text = path ? Reloaded::Paths.read_text(path) : nil
        return nil unless text
        parsed = parse_lists(text.sub(/\A﻿/, ""))
        return nil if parsed[:lists].empty? && parsed[:settings].empty?
        return tally(parsed[:lists], parsed[:favorites]).merge(:time => File.mtime(path))
      end

      # The save's lists, counted the same way (Export says what it wrote)
      def current_tally
        lists = {}
        favs = {}
        pockets.each do |p|
          lists[p] = custom_list(p)
          favs[p] = favorites(p)
        end
        return tally(lists, favs)
      end

      def tally(lists, favorites)
        entries = lists.values.flatten
        return { :pockets => lists.count { |_p, l| !l.empty? }, :items => entries.count { |e| !heading?(e) },
                 :headings => entries.count { |e| heading?(e) }, :favorites => favorites.values.flatten.length }
      end

      # The file's sections: [Settings] (New Items or old Kanto Reloaded's
      # Always Move Recent, and each pocket's Auto-Sort), then a section per
      # pocket. Notes come off before a line splits (old Kanto Reloaded split
      # first, so a note with a comma broke it).
      def parse_lists(text)
        out = { :lists => {}, :favorites => {}, :settings => {}, :ignored => 0 }
        current = nil
        text.each_line do |raw|
          line = raw.to_s.strip.sub(/\s*(#|\/\/).*\z/, "").strip
          next if line.empty?
          if line =~ /\A\[([^\]]+)\]\z/
            name = Regexp.last_match(1)
            current = squash(name) == "settings" ? :settings : pocket_from_name(name)
            if current.is_a?(Integer)
              out[:lists][current] ||= []
              out[:favorites][current] ||= []
            end
            next
          end
          next unless current
          if current == :settings
            out[:ignored] += 1 unless parse_setting(line, out[:settings])
          elsif line =~ /\A--\s*(.*?)\s*--\z/
            out[:lists][current] << heading(Regexp.last_match(1).to_s.empty? ? "Heading" : Regexp.last_match(1))
          else
            line.split(/[;,]/).each do |token|
              value = token.strip.sub(/\A(?:-|\d+[.:)])\s+/, "")
              fav = value.start_with?("*")
              id = value.sub(/\A\*\s*/, "").upcase.gsub(/[^A-Z0-9_]/, "")
              it = id.empty? ? nil : item_data(id)
              unless (it && it.pocket.to_i == current) || id.start_with?("KURAYEGG")
                out[:ignored] += 1
                next
              end
              out[:lists][current] << id unless out[:lists][current].include?(id)
              out[:favorites][current] << id if fav && !out[:favorites][current].include?(id)
            end
          end
        end
        return out
      end

      def parse_setting(line, settings)
        key, value = line.split("=", 2).map { |x| x.to_s.strip }
        return false if value.nil?
        v = squash(value)
        if ["newitems", "alwaysmoverecent"].include?(squash(key))
          i = { "inplace" => 0, "off" => 0, "first" => 1, "last" => 2 }[v]
          settings[:"bag.new_items"] = i if i
          return !i.nil?
        end
        pocket = pocket_from_name(key)
        i = { "off" => 0, "customlist" => 1, "custom" => 1, "az" => 2, "alphabetical" => 2, "number" => 3 }[v]
        return false unless pocket && i
        settings[:"bag.mode#{pocket}"] = i
        return true
      end

      # Letters and digits only (Poké Balls, pok_balls and Poke Balls all
      # read the same)
      def squash(text)
        return text.to_s.downcase.tr("éè", "ee").gsub(/[^a-z0-9]/, "")
      end

      def pocket_from_name(name)
        key = squash(name)
        pockets.each { |p| return p if squash(pocket_name(p)) == key || squash(file_pocket_name(p)) == key }
        LEGACY_POCKETS.each { |k, p| return p if squash(k) == key || squash(k).sub("pok", "poke") == key }
        return nil
      end

      # (the game's names; PIF's own when the game hasn't them yet)
      def file_pocket_name(pocket)
        name = pocket_name(pocket)
        return name unless name.empty?
        return POCKET_NAMES[pocket.to_i - 1] || "Pocket #{pocket}"
      end

      private

      # Two headings in the Kanto Reloaded section (his pick, 2026-10-23):
      # "Bag" and "Bag - Auto-Sort", each save its own
      def register_settings
        s = Reloaded::Settings
        s.register_page(PAGE, :group => :general, :name => "Bag", :icon => :features, :priority => 36, :feature => FEATURE,
          :description => "Where new items show in Kanto Reloaded's Bag, and your own Custom Lists.")
        s.register_page(SORT_PAGE, :group => :general, :name => "Bag - Auto-Sort", :icon => :features, :priority => 36.5,
          :feature => FEATURE, :description => "How each pocket sorts itself.")
        s.register(:"bag.new_items", :page => PAGE, :priority => 10, :type => :enum, :values => NEW_PLACES, :default => 0,
          :scope => :save, :name => "New Items", :description => "Where a new kind of item shows in its pocket, until you've seen it.",
          :descriptions => ["Where its pocket's order puts it.", "At the top of its pocket until you've seen it.",
                            "At the bottom of its pocket until you've seen it."])
        s.register(:"bag.start_lists", :page => PAGE, :priority => 10.5, :type => :enum, :values => START_LISTS, :default => 0,
          :scope => :save, :name => "Starting Lists",
          :description => "The Custom Lists a pocket starts with. A pocket you've edited keeps yours; the editor's Defaults brings this one back.",
          :descriptions => ["Old Kanto Reloaded's order.", "The same items under headings: Healing, Status, PP, Vitamins and more."],
          :apply => proc { Reloaded::Bag.sort_all! if $PokemonBag })
        s.register(:"bag.edit_lists", :page => PAGE, :priority => 11, :type => :button, :scope => :save, :preset => false,
          :name => "Edit Custom Lists", :on_press => proc { Reloaded::BagListScreen.open if defined?(Reloaded::BagListScreen) },
          :description => "Your own order for each pocket: Move items, add headings, add items you don't have yet.")
        s.register(:"bag.export", :page => PAGE, :priority => 12, :type => :button, :scope => :save, :preset => false,
          :name => "Export Lists", :on_press => proc { Reloaded::BagScreen.export_pressed if defined?(Reloaded::BagScreen) },
          :description => "Saves every pocket's list to a file in the Kanto Reloaded folder, to share or keep.")
        s.register(:"bag.import", :page => PAGE, :priority => 13, :type => :button, :scope => :save, :preset => false,
          :name => "Import Lists", :on_press => proc { Reloaded::BagScreen.import_pressed if defined?(Reloaded::BagScreen) },
          :description => "Loads lists from that file. It asks before replacing yours.")
        pockets.each_with_index do |pocket, i|
          name = file_pocket_name(pocket)
          s.register(:"bag.mode#{pocket}", :page => SORT_PAGE, :priority => 10 + i, :type => :enum, :values => MODES,
            :default => NUMBER_POCKETS.include?(pocket) ? 3 : 1, :name => name, :scope => :save,
            :description => "How #{name} sorts itself, in the Bag and everywhere else it shows (battle, pickers, Mart). The Bag's Sort views only change what you see.",
            :descriptions => ["Kept as you put things in. Moving by hand stays.",
                              "Your list's order: Edit Custom Lists changes it, and so does moving an item by hand in the Bag.",
                              "By name.", "By the game's item number (TMs by their number)."],
            :apply => proc { Reloaded::Bag.sort_pocket!(pocket) if $PokemonBag })
        end
        s.register(:"bag.legacy_modes", :page => SORT_PAGE, :priority => 900, :type => :toggle, :default => false,
          :scope => :save, :preset => false, :visible => proc { false }, :name => "Legacy Modes")
      end

      # (each hook once: outside the game, a test makes the game's classes
      # after Kanto Reloaded boots and calls this again)
      def install
        h = Reloaded::Hooks
        # a new kind of item reaching the Bag: placed by the pocket's order
        if defined?(::PokemonBag) && ::PokemonBag.method_defined?(:pbStoreItem) && !@store_hooked
          @store_hooked = true
          h.around(FEATURE, ::PokemonBag, :pbStoreItem, :id => :bag_store) do |original, item, *rest|
            bag = original.receiver
            before = (bag.pbQuantity(item) rescue 1)
            ret = original.call(item, *rest)
            Reloaded::Bag.after_store(bag, item) if before.to_i <= 0 && (bag.pbQuantity(item) rescue 0).to_i > 0
            ret
          end
        end
        # a save's values as they load: Kanto Reloaded Legacy's, if it has
        # some, for the one-time import
        if defined?(::SaveData) && ::SaveData.respond_to?(:load_all_values) && !@values_hooked
          @values_hooked = true
          h.around(nil, ::SaveData.singleton_class, :load_all_values, :id => :bag_legacy_values) do |original, save_data, *rest|
            value = save_data.is_a?(Hash) ? save_data[LEGACY_KEY] : nil
            Reloaded::Bag.instance_variable_set(:@legacy, value.is_a?(Hash) ? value : nil)
            original.call(save_data, *rest)
          end
        end
      end
    end
  end
end
