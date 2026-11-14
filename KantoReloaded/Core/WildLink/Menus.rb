# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Wild Link's ways in
#==============================================================================
# While Wild Link is On (his picks, 2026-11-14):
#
#   Overworld Menu  Area Encounters becomes Wild Link (the entry keeps its
#                   place; OverworldMenu/Entries.rb)
#   Pause Menu      a Wild Link tile with PIF's own Poké Radar picture (his
#                   pick: a stand-in he can swap), its chain or why not
#   The Poké Radar  using it (the Bag, a registered button, Kanto Reloaded's
#                   quick action) opens Wild Link in place of the radar
#
# A search picked on the screen waits until the menu it came from has closed,
# then starts on the map (Search.start).
#==============================================================================

module Reloaded
  module WildLink
    ICON = "Graphics/PauseMenu/WILDLINK"

    class << self
      attr_accessor :pending

      def install_menus
        return if @menus
        @menus = true
        if defined?(Reloaded::PauseMenu)
          Reloaded::PauseMenu.register(:wild_link, "Wild Link", :feature => FEATURE, :order => 24,
            :icon => ICON, :small_icon => "menuIcons/POKEMON",
            :visible => proc { Reloaded::WildLink.on? },
            :status => proc { Reloaded::WildLink.status },
            :handler => proc { |_scene| Reloaded::WildLink.open_screen ? :close : :stay })
        end
        install_radar
        if defined?(::Events) && ::Events.respond_to?(:onMapUpdate)
          ::Events.onMapUpdate += proc { |_sender, _e| Reloaded::WildLink.start_pending }
        end
      end

      # The Poké Radar opens Wild Link while it's On
      def install_radar
        return unless defined?(::ItemHandlers)
        h = Reloaded::Hooks
        h.around(FEATURE, ::ItemHandlers.singleton_class, :triggerUseFromBag, :id => :wild_link_radar_bag) do |original, item, *rest|
          next original.call(item, *rest) unless item == RADAR && Reloaded::WildLink.on?
          2                                         # the Bag closes; the game then uses it in the field
        end
        h.around(FEATURE, ::ItemHandlers.singleton_class, :triggerUseInField, :id => :wild_link_radar_field) do |original, item, *rest|
          next original.call(item, *rest) unless item == RADAR && Reloaded::WildLink.on?
          Reloaded::WildLink.open_screen
          1
        end
      end

      # The screen; true when a search was picked (it starts once the menus
      # have closed)
      def open_screen(_menu = nil)
        return false unless defined?(Reloaded::WildLinkScreen)
        screen = Reloaded::WildLinkScreen.open
        return false unless screen.result
        @pending = screen.result
        return true
      rescue StandardError => e
        Reloaded::Log.exception("Wild Link's screen failed", e, :wild_link)
        return false
      end

      # On the map again: the search picked, started
      def start_pending
        return unless @pending
        row, way = @pending
        @pending = nil
        return unless defined?(Search) && Search.respond_to?(:start)
        Search.start(row, way)
      rescue StandardError => e
        Reloaded::Log.exception("Wild Link's search couldn't start", e, :wild_link)
      end

      # The Pause Menu tile's status: [words, colour, short words]
      def status
        c = chain
        if c
          name = (::GameData::Species.get(c["species"].to_sym).name rescue c["species"])
          return [_INTL("Chain {1}: {2}", c["n"], name), nil, _INTL("Chain {1}", c["n"])]
        end
        return [_INTL("Needs the Poké Radar"), nil, _INTL("No Radar")] unless unlocked?
        return [_INTL("Ready"), nil, _INTL("Ready")]
      rescue StandardError
        return [_INTL("Ready"), nil, _INTL("Ready")]
      end
    end
  end
end
