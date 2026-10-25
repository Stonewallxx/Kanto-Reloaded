#==============================================================================
# Kanto Reloaded: its sections in the improved settings screen
#==============================================================================
# The improved settings screen (UI/SettingsScreen.rb, UI/SettingsSections.rb)
# shows Kanto Reloaded's settings as a section per feature, under Kanto
# Reloaded in the sidebar (his pick, 2026-10-25: Indented Tree, a Section
# per Feature). Each section's headers are its feature's pages; the panel
# shows only the chosen section. KIF's own screen (Reloaded Settings Off)
# keeps its one list of headings.
#
# LIST is the order, grouped by kind (his pick): Core first, then the look
# and controls, saves, your run, items and Pokémon, battles, the world, and
# the developer tools last. Each entry: [id, name, [page ids], description].
# Several features' pages can share one section (his plan: consolidate
# later, e.g. the save-related ones into one). A page of the Kanto Reloaded
# section that isn't listed gets a section of its own, before the
# developer ones. A section shows only while one of its pages has a row
# to show (a feature switched Off takes its section with it).
#==============================================================================

module Reloaded
  module SettingsSections
    LIST = [
      [:core,            "Core",            [:systems, :features], "Each Kanto Reloaded system and feature, On or Off."],
      [:interface,       "Interface",       [:interface]],
      [:controls,        "Controls",        [:controls]],
      [:speed_up,        "Speed-Up",        [:speed_up]],
      [:overworld_menu,  "Overworld Menu",  [:overworld_menu]],
      [:saves,           "Saves",           [:saves]],
      [:bug_report,      "Bug Report",      [:bug_report]],
      [:difficulty,      "Difficulty",      [:difficulty]],
      [:randomizer,      "Randomizer",      [:randomizer]],
      [:quality_of_life, "Quality of Life", [:quality_of_life]],
      [:bag,             "Reloaded Bag",    [:bag, :bag_sort]],
      [:pokevial,        "PokeVial",        [:pokevial]],
      [:egg_manager,     "Egg Manager",     [:egg_manager]],
      [:data_patches,    "Data Patches",    [:data_patches]],
      [:profiler,        "Timing Profiler", [:profiler, :profiler_time, :profiler_report]]
    ].freeze
    # Always last; a page nobody listed goes before them
    DEVELOPER = [:data_patches, :profiler].freeze
    # A name too long for the sidebar: the short one there
    SHORT = { "Battle Cursor and Icons" => "Battle Cursor" }.freeze
    # A header's own name in its section where it isn't the page's (the
    # page keeps its name: the Overworld Menu finds its rows by it)
    HEADERS = { :bag => "Reloaded Bag" }.freeze

    class << self
      # Every section, in order, with its pages that are in the Kanto
      # Reloaded section now: [[id, name, [page ids], description], ...]
      def all
        pages = Reloaded::Settings.pages(:general)
        listed = LIST.flat_map { |e| e[2] }
        out = LIST.map { |id, name, ids, desc| [id, name, ids, desc] }
        extra = pages.reject { |pg| listed.include?(pg[:id]) }.map { |pg| [pg[:id], pg[:name], [pg[:id]], nil] }
        at = out.index { |e| DEVELOPER.include?(e[0]) } || out.length
        out.insert(at, *extra)
        return out
      end

      # The section a page is in (its own id when it isn't listed)
      def of_page(page_id)
        e = LIST.find { |entry| entry[2].include?(page_id) }
        return e ? e[0] : page_id
      end

      # A header in its section: its own name (HEADERS), else the page's
      # without the name before " - " (Bag - Auto-Sort in Reloaded Bag is
      # Auto-Sort; Timing Profiler - Time is Time)
      def header(page_id, page_name)
        return _INTL(HEADERS[page_id]) if HEADERS[page_id]
        name = page_name.to_s
        i = name.index(" - ")
        return i ? name[(i + 3)..-1] : name
      end

      def short(name)
        return SHORT[name.to_s] || name.to_s
      end

      # What the description box says for a section: its own line, else
      # its first page's description
      def description(entry)
        return _INTL(entry[3]) if entry[3]
        page = entry[2].map { |id| Reloaded::Settings.page(id) }.compact.first
        return page ? _INTL(page[:description].to_s) : ""
      end
    end
  end
end
