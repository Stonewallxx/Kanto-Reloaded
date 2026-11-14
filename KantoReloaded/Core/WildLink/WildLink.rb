# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Wild Link
#==============================================================================
# Old Kanto Reloaded's Wild Link, rebuilt (his picks, 2026-11-14), as the
# DexNav that takes the Poké Radar's place:
#
#   The switch    per save, On by default, in its own Wild Link section. Off
#                 leaves Area Encounters and the Poké Radar as they are
#   The radar     Wild Link replaces it while On: the list is there from the
#                 start (Area Encounters becomes Wild Link), Search unlocks
#                 once you have the Poké Radar (PIF's Route 24 quest), and
#                 KIF's PokeRadar+ steps aside (Features :takes_over_while)
#   Multiplayer   each player their own: Search Levels, chains and targets
#   Search Level  per species, from target battles only: a catch +2, a
#                 knockout +1, up to 999 (Bonuses.rb has what it brings)
#   The chain     one at a time, saved: it grows with each won target battle
#                 and breaks if you run from it, lose, leave the map or
#                 search another; a target that gets away keeps it
#   Continue      after a won target battle: Ask (a popup), Automatic or Off
#   Where not     the Safari Zone, the Bug Contest, with a partner; with
#                 KIF's Nuzlocke on, Search waits for the place's first
#                 encounter (then only a shiny target can be caught)
#
# Stage 1 (this file, Bonuses.rb, Area.rb): the switch, the save data, the
# rules and the list's data. The screen, the targets, the field methods and
# what shows on the map come in the stages after.
#==============================================================================

module Reloaded
  module WildLink
    FEATURE = :wild_link
    PAGE = :wild_link
    SECTION = "wild_link"
    RADAR = :POKERADAR
    KIF_RADAR = "F-ITEM-04_PokeRadarPlus"
    SL_CAP = 999
    SL_CATCH = 2
    SL_KNOCKOUT = 1
    CONTINUE = :"wild_link.continue"          # 0 Ask, 1 Automatic, 2 Off
    ASK = 0
    AUTOMATIC = 1
    STOP = 2
    METHODS = [:land, :cave, :surf, :fishing, :rock_smash].freeze

    class << self
      def boot
        Reloaded::Features.register(FEATURE, :name => "Wild Link", :core => true, :order => 52,
          :description => "Search for the wild Pokémon you've seen, in place of the Poké Radar.",
          :takes_over_while => { KIF_RADAR => proc { Reloaded::WildLink.on? } }) if defined?(Reloaded::Features)
        Reloaded::SaveStore.register(SECTION)
        register_settings if defined?(Reloaded::Settings)
        Reloaded::Events.on(:save_loaded, :wild_link, 62) { |_ctx| loaded }
        install_menus if respond_to?(:install_menus)
        Search.install if defined?(Search)
        Fields.install if defined?(Fields)
        Hud.install if defined?(Hud)
        Notices.install if defined?(Notices)
        Compat.install if defined?(Compat)
        return true
      end

      def key(id)
        return :"wild_link.#{id}"
      end

      def register_settings
        s = Reloaded::Settings
        s.register_page(PAGE, :group => :general, :name => "Wild Link", :icon => :features, :priority => 50.6,
          :description => "Search for the wild Pokémon you've seen, and get better results the more you hunt them.")
        s.register(key(:enabled), :page => PAGE, :priority => 10, :type => :toggle, :default => true, :scope => :save,
          :name => "Wild Link",
          :description => "Wild Link takes the Poké Radar's place: The area's Pokémon from the start, and Search once you have the Poké Radar. Off: Area Encounters and the Poké Radar as the game has them.")
        s.register(CONTINUE, :page => PAGE, :priority => 20, :type => :enum, :default => ASK,
          :values => ["Ask", "Automatic", "Off"], :name => "Continue Search", :needs => key(:enabled),
          :descriptions => ["After you win a battle with your target, a popup asks whether to search for it again.",
                            "After you win, your next target appears on its own while the chain lasts.",
                            "After you win, the search ends. Open Wild Link to search again."],
          :description => "What happens after you win a battle with your Wild Link target.")
        s.on_change(key(:enabled), :wild_link) do
          Reloaded::Features.resync if Reloaded::Features.respond_to?(:resync)
          Search.clear if defined?(Search) && !Reloaded::WildLink.on?
        end
      end

      def loaded
        Reloaded::Features.resync if Reloaded::Features.respond_to?(:resync)
      end

      #------------------------------------------------------------------------
      # On, and where
      #------------------------------------------------------------------------
      def on?
        return false unless Reloaded::Features.on?(FEATURE)
        return Reloaded::Settings.get(key(:enabled)) ? true : false
      rescue StandardError
        return false
      end

      def data
        d = Reloaded::SaveStore.section(SECTION)
        return nil unless d
        d["sl"] ||= {}
        return d
      rescue StandardError
        return nil
      end

      # You have the Poké Radar (PIF's Route 24 quest gives it)
      def unlocked?
        return false unless $PokemonBag
        return $PokemonBag.pbHasItem?(RADAR) ? true : false if $PokemonBag.respond_to?(:pbHasItem?)
        return $PokemonBag.has?(RADAR) ? true : false if $PokemonBag.respond_to?(:has?)
        return false
      rescue StandardError
        return false
      end

      # Why Search can't run here now, or nil when it can:
      #   :off       Wild Link is Off
      #   :radar     no Poké Radar yet
      #   :safari    the Safari Zone (its own encounters)
      #   :contest   the Bug Contest
      #   :partner   a partner walks with you
      #   :nuzlocke  KIF's Nuzlocke: the place's first encounter isn't used
      #   :dynamic   cody's Randomizer rolls every wild Pokémon on the spot
      def blocked(map_id = nil)
        return :off unless on?
        return :radar unless unlocked?
        return :safari if call?(:pbInSafari?)
        return :contest if call?(:pbInBugContest?)
        return :partner if $PokemonGlobal && $PokemonGlobal.respond_to?(:partner) && $PokemonGlobal.partner
        return :dynamic if defined?(::KIF::Rand) && ::KIF::Rand.respond_to?(:dynamic?) && (::KIF::Rand.dynamic? rescue false)
        return :nuzlocke if nuzlocke_waits?(map_id || ($game_map ? $game_map.map_id : 0))
        return nil
      end

      # A game check (pbInSafari?...) that's true now; false when the game has none
      def call?(name)
        return false unless Object.private_method_defined?(name) || Object.method_defined?(name)
        return send(name) ? true : false
      rescue StandardError
        return false
      end

      # KIF's Nuzlocke, started, with this place's encounter still unused
      def nuzlocke_waits?(map_id)
        return false unless defined?(::KIF::Nuzlocke) && (::KIF::Nuzlocke.on? rescue false) && (::KIF::Nuzlocke.started? rescue false)
        place = ::KIF::Nuzlocke.place_name(map_id)
        return !((::KIF::Nuzlocke.state[:places] || {})[place])
      rescue StandardError
        return false
      end

      #------------------------------------------------------------------------
      # Search Levels (per species, kept in the save)
      #------------------------------------------------------------------------
      def species_key(species)
        d = (::GameData::Species.try_get(species) rescue nil)
        return (d ? d.id : species).to_s
      end

      def search_level(species)
        d = data
        return 0 unless d
        return d["sl"][species_key(species)].to_i.clamp(0, SL_CAP)
      end

      # A target battle won: a catch +2, a knockout +1. [before, after]
      def raise_search_level(species, caught)
        d = data
        return [0, 0] unless d
        k = species_key(species)
        was = d["sl"][k].to_i
        now = [was + (caught ? SL_CATCH : SL_KNOCKOUT), SL_CAP].min
        d["sl"][k] = now
        return [was, now]
      end

      # The Search Level steps passed going from one to the other
      def steps_passed(was, now)
        return Bonuses::SL_STEPS.select { |s| was < s && now >= s }
      end

      #------------------------------------------------------------------------
      # The chain (one at a time, kept in the save)
      #------------------------------------------------------------------------
      def chain_key(species, method, map_id)
        return [species_key(species), method.to_s, map_id.to_i].join("|")
      end

      # { "key", "species", "method", "map", "n" } or nil
      def chain
        d = data
        c = d ? d["chain"] : nil
        return c.is_a?(Hash) && c["n"].to_i > 0 ? c : nil
      end

      def chain_for(species, method, map_id)
        c = chain
        return c && c["key"] == chain_key(species, method, map_id) ? c["n"].to_i : 0
      end

      # A won target battle: the chain grows (a new one starts at 1 when it's
      # another species, way or map)
      def advance_chain(species, method, map_id)
        d = data
        return 0 unless d
        k = chain_key(species, method, map_id)
        c = d["chain"]
        n = c.is_a?(Hash) && c["key"] == k ? c["n"].to_i + 1 : 1
        d["chain"] = { "key" => k, "species" => species_key(species), "method" => method.to_s, "map" => map_id.to_i, "n" => n }
        return n
      end

      # It ends (:ran, :lost, :left, :other): what it was, 0 when there was none
      def break_chain(why = nil)
        d = data
        c = chain
        return 0 unless d && c
        d.delete("chain")
        Reloaded::Events.emit(:wild_link_chain_broken, :species => c["species"], :n => c["n"].to_i, :why => why)
        return c["n"].to_i
      end

      def continue_mode
        return (Reloaded::Settings.get(CONTINUE) rescue ASK).to_i
      end
    end
  end
end
