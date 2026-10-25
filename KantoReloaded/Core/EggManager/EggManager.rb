# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Egg Manager
#==============================================================================
# Roadmap topic egg-manager (decided 2026-10-17; the Next feature discussion
# and every design picked 2026-10-25). Every Egg in the party and the PC in
# one place, PC incubators, and the Day Care from anywhere. Hoenn
# Reloaded's Egg Manager rebuilt on the game's own functions, in the TM
# Vault's look (UI/EggManagerScreen.rb).
#
#   Eggs        the list in sections, Ready / Party / PC / Gift (an Egg not
#               from the Day Care), sorted by Steps or Place; the details
#               plate: steps, the game's own words, the incubators, the
#               Hatch Speed Helper (Flame Body or Magma Armor), and with
#               Inspect Eggs On what a Ready Egg holds (Eggs.rb)
#   incubators  one at the start, a second at 4 Badges, a third at 8, room
#               for three more a mod can give; an Egg in one counts down in
#               the PC as fast as in the party and stops at its last step:
#               Ready, hatched where it is (Incubators.rb)
#   Day Care    deposit (party or PC), withdraw (party or PC, the game's
#               cost), collect or discard the waiting Egg, Egg Chance, the
#               Partner Finder; open once you've left a Pokémon there in
#               person (DayCare.rb)
#   Egg Box     where Eggs it sends to the PC go first (Any Box: the
#               current box, then the first with room)
#   alerts      a toast when a party Egg is under 100 steps, an incubated
#               Egg is Ready, the Day Care has an Egg, Auto-Incubate puts
#               one in an incubator; the menus' red glow (Alerts.rb)
#   hatching    takes over KIF's Hatch to PC Prompt: Hatched Pokémon Stay,
#               Ask (the Ask Card) or Send to PC (Hatching.rb)
#
# The incubator number is kept on the Egg itself (@kr_incubator, a plain
# number), so it moves with the Egg and the save loads without Kanto
# Reloaded (the Egg just stops counting). The rest is in the save's
# "egg_manager" section: the Sort, the Egg Box, alerts already shown, the
# Day Care visited, incubators a mod gave.
#
#   Reloaded::EggManager.open(tab: :day_care)
#   Reloaded::EggManager.add_incubators(1, source: :my_mod)
#==============================================================================

module Reloaded
  module EggManager
    FEATURE = :egg_manager
    PAGE = :egg_manager
    SECTION = :egg_manager
    ICON = "Graphics/PauseMenu/EGGMANAGER"
    SOON = 100                    # a party Egg this close to hatching is Ready (his pick, Q8)
    SORTS = ["Steps", "Place"].freeze
    HATCHED = [:stay, :ask, :pc].freeze
    DAY_CARE_TEXT = "Day-Care Couple"   # the game's obtain_text for its Eggs (007_Overworld_DayCare.rb:425)

    class << self
      attr_accessor :screen_open      # the Egg Manager is open (no toasts over it)

      def boot
        register_settings
        Reloaded::Features.register(FEATURE, :name => "Egg Manager", :page => PAGE, :order => 29,
          :takes_over => ["F-UI-08_HatchToPC"],
          :description => "Every Egg in one place, PC incubators, and the Day Care from anywhere. Off brings back KIF's Hatch to PC Prompt.")
        Reloaded::SaveStore.register(SECTION)
        Reloaded::Events.on(:save_loaded, :egg_manager, 70) { loaded! }
        Reloaded::Events.on(:new_game, :egg_manager, 70) { loaded! }
        Reloaded::Events.on(:saving, :egg_manager, 50) { Incubators.check! if on? && $PokemonStorage }
        register_menu_entries
        Incubators.install
        DayCare.install
        Hatching.install
        register_pc_actions
        return true
      end

      def on?
        return Reloaded::Features.on?(FEATURE)
      end

      def key(id)
        return :"egg_manager.#{id}"
      end

      def setting(id)
        return Reloaded::Settings.get(key(id))
      end

      #------------------------------------------------------------------------
      # The save's section
      #------------------------------------------------------------------------
      def data
        return Reloaded::SaveStore.section(SECTION)
      rescue StandardError
        return nil
      end

      def sort
        d = data
        return d ? d["sort"].to_i.clamp(0, SORTS.length - 1) : 0
      end

      def sort=(i)
        d = data
        d["sort"] = i.to_i % SORTS.length if d
      end

      # The Egg Box: a box's index, or nil (Any Box)
      def egg_box
        d = data
        b = d ? d["egg_box"] : nil
        return nil if b.nil? || !$PokemonStorage || b.to_i >= $PokemonStorage.maxBoxes
        return b.to_i
      end

      def egg_box=(box)
        d = data
        d["egg_box"] = box.nil? ? nil : box.to_i if d
      end

      # Incubators a mod gave (on top of the Badges' three)
      def extra_incubators
        d = data
        return d ? d["extra"].to_i : 0
      end

      def add_incubators(n = 1, source: :script)
        d = data
        return false unless d
        d["extra"] = (d["extra"].to_i + n.to_i).clamp(0, Incubators::MAX - Incubators::BADGES.length)
        Reloaded::Log.info("#{source} gave #{n} incubator(s): #{Incubators.count} now", :egg_manager)
        return true
      end

      # Hatched Pokémon: :stay, :ask or :pc
      def hatched
        return HATCHED[setting(:hatched).to_i] || :ask
      end

      def inspect_eggs?
        return setting(:inspect) ? true : false
      end

      def auto_incubate?
        return setting(:auto_incubate) ? true : false
      end

      #------------------------------------------------------------------------
      # Opening it
      #------------------------------------------------------------------------
      # tab: :eggs or :day_care
      def open(tab: :eggs)
        return false unless defined?(Reloaded::EggManagerScreen)
        Incubators.check!
        Reloaded::EggManagerScreen.open(tab)
        return true
      rescue StandardError => e
        Reloaded::Log.exception("The Egg Manager couldn't open", e, :egg_manager)
        return false
      end

      # Where it can't open (the Bug Contest, KIF's shut menus)
      def usable
        return _INTL("You can't use that in the Bug Contest.") if respond_to?(:pbInBugContest?, true) && pbInBugContest?
        if defined?(::KIF::PauseMenu) && ::KIF::PauseMenu.respond_to?(:restricted?) && defined?(::KIF::PauseMenu::SHOP_RESTRICTED_MAPS) &&
           ::KIF::PauseMenu.restricted?(::KIF::PauseMenu::SHOP_RESTRICTED_MAPS)
          return _INTL("You can't use that here.")
        end
        return true
      rescue StandardError
        return true
      end

      private

      # A save loaded or a new game: the incubators found, the Hatch to PC
      # Prompt's Off carried over once
      def loaded!
        Incubators.rebuild!
        d = data
        return unless d && !d["hatched_adopted"]
        d["hatched_adopted"] = true
        sys = $PokemonSystem
        if sys && sys.respond_to?(:hatchtopc) && sys.hatchtopc.to_i == 0
          Reloaded::Settings.set(key(:hatched), 0)
        end
      rescue StandardError => e
        Reloaded::Log.exception("The Egg Manager couldn't read the save", e, :egg_manager)
      end

      def register_settings
        s = Reloaded::Settings
        s.register_page(PAGE, :group => :general, :name => "Egg Manager", :icon => :features, :priority => 41,
          :feature => FEATURE,
          :description => "Incubators, hatching, the alerts and what Eggs show.")
        s.register(key(:hatched), :page => PAGE, :priority => 10, :type => :enum, :default => 1, :scope => :save,
          :values => ["Stay", "Ask", "Send to PC"], :name => "Hatched Pokémon",
          :descriptions => ["A Pokémon that hatches in your party stays there.",
                            "Asks whether to keep it in your party or send it to the PC.",
                            "It goes to the PC by itself, and a toast says which box."],
          :description => "What happens to a Pokémon that hatches in your party.")
        s.register(key(:auto_incubate), :page => PAGE, :priority => 20, :type => :toggle, :default => true,
          :name => "Auto-Incubate",
          :description => "An Egg the Day Care sends to the PC (your party is full) goes into a free incubator.")
        s.register(key(:alerts), :page => PAGE, :priority => 30, :type => :toggle, :default => true,
          :name => "Hatch Alerts",
          :description => "A toast when an Egg is about to hatch or is Ready, or the Day Care has one, and the Egg Manager glows in the menus.")
        s.register(key(:helper), :page => PAGE, :priority => 40, :type => :toggle, :default => true,
          :name => "Hatch Speed Helper",
          :description => "The Egg Manager says when no Pokémon in your party has Flame Body or Magma Armor, and which one in the PC does.")
        s.register(key(:inspect), :page => PAGE, :priority => 50, :type => :toggle, :default => false,
          :name => "Inspect Eggs",
          :description => "A Ready Egg shows what's inside: Its species, nature, ability, IVs and the moves it inherited.")
      end

      def register_menu_entries
        if defined?(Reloaded::PauseMenu)
          Reloaded::PauseMenu.register(:egg_manager, "Egg Manager", :feature => FEATURE, :order => 24,
            :icon => ICON, :small_icon => "menuIcons/POKEMON",
            :condition => proc { usable == true },
            :lock_reason => proc { r = usable; r == true ? nil : r },
            :status => proc { n = Eggs.all.length; [_INTL("Eggs: {1}", n), nil, n.to_s] },
            :alert => proc { Alerts.any? },
            :handler => proc { |_scene| open; :stay })
        end
        if defined?(Reloaded::OverworldMenu)
          Reloaded::OverworldMenu.register(:egg_manager, :name => "Egg Manager", :kind => :action, :priority => 28, :feature => FEATURE,
            :usable => proc { usable },
            :alert => proc { Alerts.any? },
            :description => "Every Egg in your party and the PC, the incubators and the Day Care.",
            :handler => proc { |menu| open; menu.refresh rescue nil; nil })
        end
      end

      # In the Reloaded PC: an Egg goes into an incubator or comes out
      def register_pc_actions
        return unless defined?(Reloaded::PC) && Reloaded::PC.respond_to?(:add_action)
        Reloaded::PC.add_action(:egg_incubate, :order => 30,
          :label => proc { |pkmn| pkmn && pkmn.egg? && on? ? (Incubators.number(pkmn) ? _INTL("Take Out of Incubator") : _INTL("Incubate")) : nil },
          :description => "Put this Egg in an incubator, or take it out.",
          :enabled => proc { |pkmn| Incubators.number(pkmn) || Incubators.free },
          :disabled_reason => proc { _INTL("Every incubator is in use.") }) do |_screen, pkmn, _selected, heldpoke|
          egg = heldpoke || pkmn
          Incubators.number(egg) ? Incubators.release(egg) : Incubators.incubate(egg)
        end
      end
    end
  end
end
