#==============================================================================
# Kanto Reloaded: Quality of Life
#==============================================================================
# Toggles that make the game easier or quicker, and three tools, as rows
# under a Quality of Life heading in the Kanto Reloaded section of KIF
# Settings (his pick, 2026-10-17; reviewed 2026-10-21). Any of them can be
# added to an Overworld Menu page (Edit Pages > Add a Setting).
#
# Balance toggles change how hard the game is, so each save keeps its own
# (Infinite Repel, Infinite Money, Rematch Money, Infinite Safari, Infinite
# PP, Upgraded PP, Always Obey, Level Locking, Instant Hatch, Encounter
# Rate, Max Friendship, Day Care Eggs, Guaranteed Catch). Comfort toggles
# are a preference for every save (Auto-Repel Reuse, Auto-Hook Fishing,
# Level-Up Moves, Faster Evolutions). All are Off (or Normal) to start.
#
# A save quietly remembers each balance toggle ever turned on, and play
# with KIF's DEBUG option on, for later difficulty and game modes (his
# ask, 2026-10-21); Bug Reports include it. Reloaded::QualityOfLife.used
#
# The hooks are in Hooks*.rb beside this file, the tools' screens in
# Core/UI/QualityOfLifeScreens.rb.
#==============================================================================

module Reloaded
  module QualityOfLife
    FEATURE = :quality_of_life
    PAGE = :quality_of_life
    SECTION = :quality_of_life

    # key => [name, kind, description, extra]; the page's order
    TOGGLES = [
      [:infinite_repel, "Infinite Repel", :balance, "A Repel's effect is always on, without using one."],
      [:auto_repel, "Auto-Repel Reuse", :comfort, "When a Repel wears off, another of the same kind is used from your Bag. With none of that kind left, the game asks as usual."],
      [:infinite_money, "Infinite Money", :balance, "Shops sell you anything, in any amount, and nothing lowers your money. Your real money is kept: Turn it Off and it's back."],
      [:rematch_money, "Rematch Money", :balance, "Trainer rematches pay prize money, as first battles do."],
      [:infinite_safari, "Infinite Safari", :balance, "Your steps in the Safari Zone never run out."],
      [:infinite_pp, "Infinite PP", :balance, "Your Pokémon's moves never use up PP."],
      [:upgraded_pp, "Upgraded PP", :balance, "Every move's PP counts as if it had 3 PP Ups. Nothing is written into the save: Off puts them back."],
      [:move_learning, "Level-Up Moves", :comfort, "What happens when a Pokémon can learn a move by levelling up.",
       { :values => ["Native", "Ask", "Skip"],
         :descriptions => ["As the game does it: A new move fills a free slot, and it asks when all four are full.",
                           "Asks before learning any new move, even with a free slot.",
                           "Never learns moves by levelling up. The Move Relearner still has them."] }],
      [:always_obey, "Always Obey", :balance, "Your Pokémon always obey, whatever their level and your badges."],
      [:level_locking, "Level Locking", :balance, "Pokémon locked in the Level Lock Manager stop gaining EXP at their level. Setting a lock turns it On; Off pauses every lock without forgetting it."],
      [:instant_hatch, "Instant Hatch", :balance, "Eggs in your party hatch on your next step."],
      [:daycare_eggs, "Day Care Eggs", :balance, "The Day Care has an Egg ready as soon as two Pokémon that get along are left there."],
      [:encounter_rate, "Encounter Rate", :balance, "How often wild Pokémon appear in grass, caves and water.",
       { :values => ["Fewer", "Normal", "More"], :default => 1,
         :descriptions => ["Half as often, for getting around.", "As the game has it.", "Twice as often, for training or shiny hunting."] }],
      [:max_friendship, "Max Friendship", :balance, "Your Pokémon count as fully friendly: Friendship evolutions and Return work at once."],
      [:guaranteed_catch, "Guaranteed Catch", :balance, "Every Poké Ball catches the wild Pokémon it's thrown at."],
      [:auto_hook, "Auto-Hook Fishing", :comfort, "A bite never gets away: Reel it in when you like."],
      [:faster_evolutions, "Faster Evolutions", :comfort, "A shorter evolution scene. B still stops it."]
    ].freeze

    TOOLS = [
      [:nature_selector, "Nature Selector", "Change a party Pokémon's nature.", proc { Reloaded::QualityOfLifeScreens.nature_selector }],
      [:level_locks, "Level Lock Manager", "See and set the level each party Pokémon is locked at.", proc { Reloaded::QualityOfLifeScreens.level_locks }],
      [:super_candy, "Super Candy", "Raise the party to a level, with their moves and evolutions as the game does them.", proc { Reloaded::QualityOfLifeScreens.super_candy }]
    ].freeze

    @used_dirty = false

    class << self
      def boot
        register_settings
        Reloaded::Features.register(FEATURE, :name => "Quality of Life", :page => PAGE, :order => 20,
          :description => "Toggles that make the game easier or quicker, and the Nature Selector, Level Lock Manager and Super Candy.")
        Reloaded::SaveStore.register(SECTION)
        Reloaded::Events.on(:setting_changed, :quality_of_life_used) { |e| note_change(e) }
        Reloaded::Events.on(:save_loaded, :quality_of_life_used, 60) { note_all_on }
        Reloaded::Events.on(:new_game, :quality_of_life_used, 60) { note_all_on }
        Reloaded::Events.on(:saving, :quality_of_life_used, 40) { note_debug }
        install
        return true
      end

      def key(id)
        return :"qol.#{id}"
      end

      # True while the feature runs and the toggle is On (an enum: not its
      # first value). The hooks ask this on every call.
      def on?(id)
        return false unless Reloaded::Features.on?(FEATURE)
        v = Reloaded::Settings.get(key(id))
        return v.is_a?(Integer) ? v != 0 : !!v
      rescue StandardError
        return false
      end

      # An enum's index (Encounter Rate, Level-Up Moves)
      def value(id)
        return nil unless Reloaded::Features.on?(FEATURE)
        return Reloaded::Settings.get(key(id))
      rescue StandardError
        return nil
      end

      def max_level
        return ::GameData::GrowthRate.max_level
      rescue StandardError
        return 100
      end

      # How far a Pokémon may level now: the level cap on now, else the
      # highest level
      def level_cap(pkmn = nil)
        return active_cap(pkmn) || max_level
      end

      # KIF's Level Cap when it's on (for that Pokémon), else PIF's Level
      # Caps option, or nil while neither is (the Overworld Menu's Level Cap
      # reads this too)
      def active_cap(pkmn = nil)
        max = max_level
        if defined?(::KIF::LevelCap)
          c = (pkmn ? ::KIF::LevelCap.cap_for(pkmn) : ::KIF::LevelCap.cap) rescue nil
          return [c.to_i, max].min if c
        end
        if $PokemonSystem && $PokemonSystem.respond_to?(:level_caps) && $PokemonSystem.level_caps == 1 &&
           respond_to?(:getCurrentLevelCap, true) && $Trainer && $Trainer.badge_count < ::Settings::NB_BADGES
          c = (getCurrentLevelCap rescue nil)
          return [c.to_i, max].min if c
        end
        return nil
      end

      # The class (by name) is there, or for Object the top-level method
      def present?(target, method)
        klass = target
        unless klass.is_a?(Module)
          klass = Object
          target.to_s.split("::").each do |name|
            return false unless klass.const_defined?(name, false)
            klass = klass.const_get(name, false)
          end
        end
        return true unless klass == Object
        return Object.private_method_defined?(method) || Object.method_defined?(method)
      rescue StandardError
        return false
      end

      def balance?(id)
        t = TOGGLES.find { |row| row[0] == id.to_sym }
        return t ? t[2] == :balance : false
      end

      #------------------------------------------------------------------------
      # What a save has used: { "infinite_money" => "2026-10-21 14:05", "debug" => ... }
      #------------------------------------------------------------------------
      def used
        data = Reloaded::SaveStore.section(SECTION)
        return {} unless data
        return (data["used"] || {}).dup
      end

      # For a bug report: what's On now, and what this save has ever used
      def report_lines
        return [] unless Reloaded::SaveStore.section(SECTION)
        name = proc { |id| (TOGGLES.find { |t| t[0].to_s == id.to_s } || [nil, id == "debug" ? "Debug" : id.to_s])[1] }
        on = TOGGLES.select { |t| v = Reloaded::Settings.get(key(t[0])); v != Reloaded::Settings.default(key(t[0])) }
        out = ["- Quality of Life on: #{on.empty? ? "none" : on.map { |t| t[1] }.join(", ")}"]
        u = used
        out << "- This save has used: #{u.empty? ? "none" : u.map { |id, at| "#{name.call(id)} (#{at})" }.join(", ")}"
        return out
      rescue StandardError
        return []
      end

      def note_used(id)
        data = Reloaded::SaveStore.section(SECTION)
        return false unless data
        list = (data["used"] ||= {})
        return false if list.has_key?(id.to_s)
        list[id.to_s] = Time.now.strftime("%Y-%m-%d %H:%M")
        Reloaded::Log.info("This save has now used #{id}.", :quality_of_life)
        return true
      end

      private

      def register_settings
        s = Reloaded::Settings
        s.register_page(PAGE, :group => :general, :name => "Quality of Life", :icon => :features, :priority => 38,
          :feature => FEATURE,
          :description => "Toggles that make the game easier or quicker. The ones that change how hard it is are kept by each save.")
        TOGGLES.each_with_index do |(id, name, kind, description, extra), i|
          extra ||= {}
          options = { :page => PAGE, :priority => 10 + i * 10, :name => name, :description => description,
                      :scope => kind == :balance ? :save : :global }
          if extra[:values]
            options[:type] = :enum
            options[:values] = extra[:values]
            options[:descriptions] = extra[:descriptions]
            options[:default] = extra[:default] || 0
          else
            options[:type] = :toggle
            options[:default] = false
          end
          s.register(key(id), options)
        end
        TOOLS.each_with_index do |(id, name, description, opener), i|
          s.register(key(id), :page => PAGE, :priority => 500 + i * 10, :type => :button, :preset => false,
            :name => name, :description => description, :on_press => opener)
        end
      end

      # Each toggle a Toggles entry and each tool an Actions entry in the
      # Overworld Menu's add list (his ask, 2026-10-21), none on a page to
      # start. A toggle kept by each save shows while a save is loaded. An
      # On/Off one is a switch; a choice opens its dropdown, each choice
      # explained.
      def register_menu_entries
        return unless defined?(Reloaded::OverworldMenu) && Reloaded::OverworldMenu.respond_to?(:register)
        om = Reloaded::OverworldMenu
        TOGGLES.each_with_index do |(id, name, kind, description, extra), i|
          choices = extra && extra[:values]
          options = { :name => name, :kind => :toggle, :priority => 200 + i, :feature => FEATURE, :home => false,
                      :condition => proc { kind == :comfort || Reloaded::Settings.save_active? },
                      :description => description }
          if choices
            options[:values] = choices
            options[:get] = proc { Reloaded::Settings.get(key(id)).to_i }
            options[:set] = proc { |v| Reloaded::Settings.set(key(id), v) }
            options[:explain] = proc { |v| extra[:descriptions] ? extra[:descriptions][v].to_s : description }
          else
            options[:get] = proc { Reloaded::Settings.get(key(id)) ? true : false }
            options[:set] = proc { |on| Reloaded::Settings.set(key(id), on ? true : false) }
          end
          om.register(:"qol_#{id}", options)
        end
        TOOLS.each_with_index do |(id, name, description, opener), i|
          om.register(:"qol_#{id}", :name => name, :kind => :action, :priority => 200 + i, :feature => FEATURE, :home => false,
            :condition => proc { Reloaded::Settings.save_active? },
            :description => description,
            :handler => proc { |menu| menu.send(:hidden) { opener.call }; nil })
        end
      end

      def install
        register_menu_entries
        Reloaded::QualityOfLife::Hooks.install if defined?(Reloaded::QualityOfLife::Hooks)
        Reloaded::QualityOfLife::LevelLocks.install if defined?(Reloaded::QualityOfLife::LevelLocks)
        Reloaded::QualityOfLife::Toast.install if defined?(Reloaded::QualityOfLife::Toast)
        return true
      end

      def note_change(e)
        k = e[:key].to_s
        return unless k.start_with?("qol.")
        id = k.sub("qol.", "")
        return unless balance?(id)
        d = Reloaded::Settings.default(e[:key])
        note_used(id) if e[:value] != d
      end

      # a toggle already On when a save loads (set before this was kept)
      def note_all_on
        TOGGLES.each do |id, _name, kind|
          next unless kind == :balance
          v = Reloaded::Settings.get(key(id))
          note_used(id) if v != Reloaded::Settings.default(key(id))
        end
      end

      def note_debug
        note_used(:debug) if $DEBUG
      end
    end
  end
end
