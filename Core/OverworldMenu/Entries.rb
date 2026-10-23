#==============================================================================
# Kanto Reloaded: the Overworld Menu's own entries
#==============================================================================
# Actions (on Main)  Quick Items, Time Changer, Fly, Field Moves, Repel,
#                    Quick Save
# Toggles            Speed-Up, Bicycle (and any setting, as a row:
#                    SettingRows.rb)
# Readouts           Quest, Safari Zone / Bug Contest, Met This Session, Since
#                    a Shiny, Itemfinder, Level Cap, Day Care, Poké Radar
#                    Chain, Play Time, Pokédex, Badges, Shiny Odds, Game
#                    Corner Coins, Roaming Pokémon
# Actions on no page Area Encounters, Last Used Item, PC, Return, Quest Log,
#                    Quit Safari, Quit Contest (the player adds them)
# Toggles and readouts start on no page: the player adds the ones they want.
#
# Everything goes through the game's own code: Fly through the region map
# and the field move, Repels and Quick Items through the game's item use,
# Quick Save through the save screen, Quit through the Safari Zone's and
# Bug Contest's own endings. Kanto Reloaded's features add theirs (PokeVial,
# Heal with Moves, Egg Manager, Wild Link) when they're built.
#==============================================================================

module Reloaded
  module OverworldMenu
    module Entries
      # The scene a KIF Beta pause-menu entry is given here: the menu is
      # already hidden, so there's nothing to hide or show
      class KIFScene
        def pbHideMenu; end
        def pbShowMenu; end
        def pbRefresh; end
      end

      REPELS = [[:REPEL, 100], [:SUPERREPEL, 200], [:MAXREPEL, 250], [:FUSIONREPEL, 50]].freeze
      BIKES = [:BICYCLE, :RACEBIKE].freeze
      WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"].freeze
      # The Ready Menu's field moves (KIF Beta's pbUseKeyItem) but Fly, which
      # has its own row
      FIELD_MOVES = [:CUT, :DEFOG, :DIG, :DIVE, :FLASH, :ROCKCLIMB, :ROCKSMASH, :SECRETPOWER, :STRENGTH, :SURF,
                     :SWEETSCENT, :TELEPORT, :WATERFALL, :WHIRLPOOL, :BOUNCE, :SUNNYDAY, :RAINDANCE, :WHIRLWIND].freeze

      class << self
        def register_all
          main
          toggles
          info
        end

        def om
          return Reloaded::OverworldMenu
        end

        #----------------------------------------------------------------------
        # Main
        #----------------------------------------------------------------------
        def main
          om.register(:quick_items, :name => "Quick Items", :kind => :action, :priority => 10,
            :status => proc { n = Reloaded::OverworldMenu.quick_items.count { |i| i && Reloaded::OverworldMenu.has_item?(i) }; n > 0 ? [n.to_s, nil] : nil },
            :description => "Up to 7 items of your choosing, one press away. Use one, or change or clear a slot.",
            :handler => proc { |menu| menu.focus_quick_items; nil })
          om.register(:fly, :name => "Fly", :kind => :action, :priority => 20,
            :condition => proc { !fly_user.nil? },
            :usable => proc { can_fly? ? true : _INTL("You can't fly from here.") },
            :description => "Fly to a town you've been to, with the Pokémon that knows Fly.",
            :handler => proc { |menu| fly(menu) })
          om.register(:field_moves, :name => "Field Moves", :kind => :action, :priority => 25,
            :condition => proc { !known_field_moves.empty? },
            :usable => proc { field_moves.empty? ? _INTL("None of your field moves work here.") : true },
            :description => "Your Pokémon's other field moves that work where you stand: Cut, Surf, Strength, Flash, Dig, Teleport and more.",
            :handler => proc { |menu| field_move(menu) })
          om.register(:repel, :name => "Repel", :kind => :action, :priority => 30,
            :condition => proc { repel_steps > 0 || !repels.empty? || qol?(:infinite_repel) },
            :status => proc { repel_status },
            :description => "The steps your Repel has left (the ∞ mark while Infinite Repel is On). While none is on, use one of yours from here.",
            :handler => proc { |menu| repel(menu) })
          om.register(:time_changer, :name => "Time Changer", :kind => :action, :priority => 15,
            :condition => proc { defined?(::UnrealTime) && !time_stopped? },
            :description => "Moves time forward by the days and to the hour you pick. Never backward.",
            :handler => proc { |menu| change_time(menu) })
          om.register(:quick_save, :name => "Quick Save", :kind => :action, :priority => 90,
            :condition => proc { !($game_system && $game_system.save_disabled) },
            :usable => proc { save_reason || true },
            :status => proc { quick_save_status },
            :description => "The game's save screen. The menu closes first.",
            :handler => proc { |_menu| proc { pbSaveScreen if defined?(pbSaveScreen) } })
          # added by the player (none of these start on a page)
          om.register(:area_encounters, :name => "Area Encounters", :kind => :action, :priority => 50, :home => false,
            :condition => proc { !area_tabs.empty? },
            :description => "The wild Pokémon here, by how you meet them, with their levels and how often they appear: A ball on the ones you've caught, ??? for the ones you haven't seen.",
            :handler => proc { |menu| menu.area_encounters; nil })
          om.register(:last_item, :name => "Last Used Item", :kind => :action, :priority => 55, :home => false,
            :condition => proc { (i = Reloaded::OverworldMenu.last_item) && Reloaded::OverworldMenu.has_item?(i) },
            :label => proc { i = Reloaded::OverworldMenu.last_item; i ? item_name(i) : "" },
            :status => proc { i = Reloaded::OverworldMenu.last_item; i ? ["x#{($PokemonBag.pbQuantity(i) rescue 1)}", nil] : nil },
            :description => "The item you used last, from the Bag or the map, used again.",
            :handler => proc { |menu| menu.use_item(Reloaded::OverworldMenu.last_item) })
          om.register(:kif_pc, :name => "PC", :kind => :action, :priority => 60, :home => false,
            :condition => proc { !kif_entry(:kif_pc).nil? },
            :description => "KIF's PC: Your boxes, from wherever you are (KIF's QoL setting).",
            :handler => proc { |menu| run_kif_entry(menu, :kif_pc) })
          om.register(:kif_return, :name => "Return", :kind => :action, :priority => 65, :home => false,
            :condition => proc { !kif_entry(:kif_er_return).nil? },
            :label => proc { kif_label(:kif_er_return) || "Return" },
            :description => "The Entrance Randomizer's way back to where you came in.",
            :handler => proc { |menu| run_kif_entry(menu, :kif_er_return) })
          om.register(:quest_log, :name => "Quest Log", :kind => :action, :priority => 70, :home => false,
            :condition => proc { defined?(pbQuestlog) && $Trainer && $Trainer.respond_to?(:quests) },
            :description => "The quest log, whether or not you have a main quest.",
            :handler => proc { |menu| menu.hidden { pbFadeOutIn { pbQuestlog } }; nil })
        end

        # A Quality of Life toggle is On (Repel's and Safari Steps' ∞ mark)
        def qol?(id)
          return defined?(Reloaded::QualityOfLife) && Reloaded::QualityOfLife.on?(id) ? true : false
        end

        def repel_status
          return [Reloaded::OverworldMenu::INFINITY, :gold] if qol?(:infinite_repel)
          return repel_steps > 0 ? [repel_steps.to_s, :green] : [_INTL("Off"), :dim]
        end
        # When it last saved, coloured by how long ago (his call, 2026-10-21)
        def quick_save_status
          return nil unless defined?(Reloaded::PauseMenu)
          s = Reloaded::PauseMenu.save_status
          return s ? [s[1], save_age_colour(Reloaded::PauseMenu.save_age)] : nil
        end

        # Green under 30 minutes, orange under an hour, red after that (and
        # before the first save)
        def save_age_colour(seconds)
          return :red if seconds.nil? || seconds >= 60 * 60
          return seconds < 30 * 60 ? :green : :amber
        end

        # The item's name, or its id
        def item_name(item)
          return ::GameData::Item.get(item).name.to_s
        rescue StandardError
          return item.to_s
        end

        # KIF Beta's pause-menu entry with this id while it's on, or nil
        def kif_entry(id)
          return nil unless defined?(::KIF::PauseMenu) && ::KIF::PauseMenu.respond_to?(:active_entries)
          return ::KIF::PauseMenu.active_entries.find { |e| e.id == id }
        rescue StandardError
          return nil
        end

        def kif_label(id)
          e = kif_entry(id)
          return e && ::KIF::PauseMenu.respond_to?(:label_for) ? ::KIF::PauseMenu.label_for(e).to_s : nil
        rescue StandardError
          return nil
        end

        # A KIF Beta pause-menu entry run as the pause menu runs it, this menu
        # hidden meanwhile (the entry's scene is a stand-in: nothing to hide).
        # :close closes this menu too, so the Entrance Randomizer's Return
        # happens once the map runs again.
        def run_kif_entry(menu, id)
          e = kif_entry(id)
          return nil unless e
          result = nil
          menu.hidden { result = e.handler.call(KIFScene.new) }
          return result == :close ? :close : nil
        end

        def fly_user
          return nil unless $Trainer && $Trainer.respond_to?(:party)
          return $Trainer.party.find { |p| p && !(p.egg? rescue false) && (p.hasMove?(:FLY) rescue false) }
        end

        def can_fly?
          user = fly_user
          return false unless user && defined?(pbCanUseHiddenMove?)
          return pbCanUseHiddenMove?(user, :FLY, false) ? true : false
        rescue StandardError
          return false
        end

        # The region map as the Ready Menu opens it; the flight once the
        # menu has closed.
        def fly(menu)
          user = fly_user
          spot = nil
          menu.hidden { spot = pbBetterRegionMap(-1, true, true) } if defined?(pbBetterRegionMap)
          return nil unless spot
          return proc do
            $PokemonTemp.flydata = spot
            pbUseHiddenMove(user, :FLY)
          end
        end

        # [[move, Pokémon]] of the field moves the party knows (eggs left out)
        def known_field_moves
          return [] unless $Trainer && $Trainer.respond_to?(:party)
          out = []
          FIELD_MOVES.each do |m|
            $Trainer.party.each { |p| out << [m, p] if p && !(p.egg? rescue false) && (p.hasMove?(m) rescue false) }
          end
          return out
        end

        # The ones that work where you stand, one row per move (the first
        # Pokémon that can use it), as the Ready Menu tells
        def field_moves
          return [] unless defined?(pbCanUseHiddenMove?)
          done = {}
          return known_field_moves.select do |m, p|
            next false if done[m]
            done[m] = (pbCanUseHiddenMove?(p, m, false) rescue false) ? true : nil
          end
        end

        # A move picked from the list, used the Ready Menu's way once the menu
        # has closed: Teleport through the region map (KIF Beta's), the rest
        # after the game's own "use it?" question.
        def field_move(menu)
          list = field_moves
          if list.empty?
            menu.notice(_INTL("Field Moves"), _INTL("None of your field moves work here."))
            return nil
          end
          labels = list.map { |m, p| _INTL("{1} ({2})", ::GameData::Move.get(m).name, p.name) }
          descs = list.map { |m, _p| (::GameData::Move.get(m).description rescue "").to_s }
          i = menu.choose(_INTL("Field Moves"), labels, descs)
          return nil unless i
          move, user = list[i]
          if move == :TELEPORT
            spot = nil
            menu.hidden { spot = pbBetterRegionMap(-1, true, true) } if defined?(pbBetterRegionMap)
            return nil unless spot
            return proc do
              $PokemonTemp.flydata = spot
              pbUseHiddenMove(user, move)
            end
          end
          return proc { pbUseHiddenMove(user, move) if pbConfirmUseHiddenMove(user, move) }
        end

        def repel_steps
          return ($PokemonGlobal.repel rescue 0).to_i
        end

        # [[item, steps, count]] of the Repels in the Bag
        def repels
          return [] unless $PokemonBag && defined?(::GameData::Item)
          return REPELS.select { |id, _s| ::GameData::Item.exists?(id) && $PokemonBag.pbHasItem?(id) }.map do |id, steps|
            [id, steps, ($PokemonBag.pbQuantity(id) rescue 1)]
          end
        end

        def repel(menu)
          if qol?(:infinite_repel)
            menu.notice(_INTL("Repel"), _INTL("Infinite Repel is On: A Repel's effect is always on."))
            return nil
          end
          if repel_steps > 0
            menu.notice(_INTL("Repel"), _INTL("Your Repel has {1} steps left.", repel_steps))
            return nil
          end
          list = repels
          if list.empty?
            menu.notice(_INTL("Repel"), _INTL("You don't have any Repels."))
            return nil
          end
          labels = list.map { |id, _s, n| "#{::GameData::Item.get(id).name} x#{n}" }
          descs = list.map { |_id, s, _n| _INTL("{1} steps without wild Pokémon.", s) }
          i = menu.choose(_INTL("Use a Repel"), labels, descs)
          return nil unless i
          menu.hidden { pbUseKeyItemInField(list[i][0]) }
          return nil
        end

        def time_stopped?
          return defined?(SWITCH_TIME_PAUSED) && $game_switches && $game_switches[SWITCH_TIME_PAUSED] ? true : false
        end

        def change_time(menu)
          pick = menu.time_changer
          return nil unless pick
          days, hour = pick
          seconds = seconds_to(days, hour)
          return nil unless seconds > 0
          $PokemonGlobal.newFrameCount += seconds * Graphics.frame_rate / ::UnrealTime::PROPORTION.to_f
          PBDayNight.sheduleToneRefresh if defined?(PBDayNight) && PBDayNight.respond_to?(:sheduleToneRefresh)
          $game_map.need_refresh = true if $game_map && $game_map.respond_to?(:need_refresh=)
          $game_map.refresh if $game_map && $game_map.respond_to?(:refresh)
          return nil
        end

        # Seconds from now to the hour, days ahead (0 days and an hour that's
        # gone today: tomorrow). Always forward.
        def seconds_to(days, hour, now = nil)
          now ||= defined?(pbGetTimeNow) ? pbGetTimeNow : Time.now
          into_day = now.hour * 3600 + now.min * 60 + now.sec
          ahead = hour * 3600 - into_day + days * 86_400
          ahead += 86_400 if ahead <= 0
          return ahead
        end

        # "Thu 9:00 PM", where days and hour land
        def landing_words(days, hour, now = nil)
          now ||= defined?(pbGetTimeNow) ? pbGetTimeNow : Time.now
          at = now + seconds_to(days, hour, now)
          return "#{_INTL(WEEKDAYS[at.wday])} #{at.strftime("%l:%M %p").strip}"
        end

        def save_reason
          pm = Reloaded::PauseMenu if defined?(Reloaded::PauseMenu)
          return _INTL("You can't save in the Safari Zone.") if pm && pm.in_safari?
          return _INTL("You can't save in the Bug Contest.") if pm && pm.in_contest?
          return nil
        end

        #----------------------------------------------------------------------
        # Toggles
        #----------------------------------------------------------------------
        def toggles
          om.register(:speed_up, :name => "Speed-Up", :kind => :toggle, :priority => 50,
            :condition => proc { defined?(SPEEDUP_STAGES) && $PokemonSystem && $PokemonSystem.respond_to?(:speedup) && $PokemonSystem.speedup.to_i == 1 },
            :values => [],
            :get => proc { $GameSpeed.to_i },
            :set => proc { |i| $GameSpeed = i },
            :description => "The game's speed, while Speed-Up is set to Toggle.")
          om.entry(:speed_up).values = SpeedValues.new
          om.register(:bicycle, :name => "Bicycle", :kind => :toggle, :priority => 55,
            :condition => proc { !bike.nil? },
            :usable => proc { bike_reason || true },
            :get => proc { $PokemonGlobal.bicycle ? true : false },
            :set => proc { |on| on ? pbMountBike : pbDismountBike },
            :description => "On while you ride: A gets on or off, where you can ride, without the Bag.")
        end

        # The Bicycle (or PIF's Race Bike) you have, or nil
        def bike
          return BIKES.find { |i| Reloaded::OverworldMenu.has_item?(i) }
        end

        # Why you can't get on or off here, as the Bicycle's own check
        # (pbBikeCheck) says, or nil
        def bike_reason
          g = $PokemonGlobal
          return _INTL("You can't ride here.") if g.surfing || g.diving || (!g.bicycle && $game_player.pbTerrainTag.must_walk)
          return _INTL("You can't ride with someone following you.") if $game_player.pbHasDependentEvents?
          meta = ::GameData::MapMetadata.try_get($game_map.map_id)
          if g.bicycle
            return meta && meta.always_bicycle ? _INTL("You can't get off your Bike here.") : nil
          end
          return _INTL("You can't ride here.") if !meta || (!meta.can_bicycle && !meta.outdoor_map)
          return nil
        rescue StandardError
          return _INTL("You can't ride here.")
        end

        #----------------------------------------------------------------------
        # Info
        #----------------------------------------------------------------------
        def info
          om.register(:quest, :name => "Quest", :kind => :info, :priority => 10,
            :condition => proc { !main_quest.nil? },
            :label => proc { q = main_quest; q ? q.name.to_s : "" },
            :description => "Your main quest, by name. It opens the quest log.",
            :handler => proc { |menu| menu.hidden { pbFadeOutIn { pbQuestlog } } if defined?(pbQuestlog); nil })
          om.register(:safari, :name => "Safari Balls", :kind => :info, :priority => 20,
            :condition => proc { safari? },
            :status => proc { [pbSafariState.ballcount.to_s, nil] },
            :description => "The Safari Balls you have left.")
          om.register(:safari_steps, :name => "Safari Steps", :kind => :info, :priority => 20,
            :condition => proc { safari? && defined?(::Settings::SAFARI_STEPS) && ::Settings::SAFARI_STEPS > 0 },
            :status => proc { qol?(:infinite_safari) ? [Reloaded::OverworldMenu::INFINITY, :gold] : ["#{pbSafariState.steps}/#{::Settings::SAFARI_STEPS}", nil] },
            :description => "The steps you have left in the Safari Zone, of the most you can take (the ∞ mark while Infinite Safari is On).")
          om.register(:quit_safari, :name => "Quit Safari", :kind => :action, :priority => 80, :home => false,
            :condition => proc { safari? },
            :description => "Leave the Safari Game now.",
            :handler => proc { |menu| quit_safari(menu) })
          om.register(:contest, :name => "Caught", :kind => :info, :priority => 22,
            :condition => proc { contest? },
            :status => proc { [contest_words, nil] },
            :description => "The Pokémon you've caught in the Bug-Catching Contest.")
          om.register(:contest_balls, :name => "Sport Balls", :kind => :info, :priority => 22,
            :condition => proc { contest? },
            :status => proc { [pbBugContestState.ballcount.to_s, nil] },
            :description => "The Sport Balls you have left.")
          om.register(:quit_contest, :name => "Quit Contest", :kind => :action, :priority => 81, :home => false,
            :condition => proc { contest? },
            :description => "End the Bug-Catching Contest now.",
            :handler => proc { |menu| quit_contest(menu) })
          om.register(:encounters, :name => "Met This Session", :kind => :info, :priority => 30,
            :status => proc { [Reloaded::OverworldMenu.session.to_s, nil] },
            :description => "Wild Pokémon you've met since the game started this time.")
          om.register(:since_shiny, :name => "Since a Shiny", :kind => :info, :priority => 31,
            :status => proc { [Reloaded::OverworldMenu.since_shiny.to_s, nil] },
            :description => "Wild Pokémon you've met in this save since the last shiny one.")
          om.register(:itemfinder, :name => "Itemfinder", :kind => :info, :priority => 40,
            :condition => proc { itemfinder? },
            :status => proc { hidden_item_words },
            :description => "How far the nearest hidden item is, and which way.")
          om.register(:level_cap, :name => "Level Cap", :kind => :info, :priority => 50,
            :condition => proc { !level_cap.nil? },
            :status => proc { [level_cap.to_s, :gold] },
            :description => "The level cap now, while KIF's or PIF's Level Caps are on (KIF's first).")
          om.register(:day_care, :name => "Day Care", :kind => :info, :priority => 55,
            :condition => proc { $PokemonGlobal && $PokemonGlobal.respond_to?(:daycare) },
            :status => proc { day_care_status },
            :description => "An egg waiting, or how many Pokémon are there. A shows who's there, how well they get along, the levels each has gained and what taking it back costs.",
            :handler => proc { |menu| menu.day_care; nil })
          om.register(:radar_chain, :name => "Poké Radar Chain", :kind => :info, :priority => 60,
            :condition => proc { radar_chain > 0 },
            :status => proc { [radar_chain.to_s, :green] },
            :description => "The Poké Radar's chain now.")
          om.register(:play_time, :name => "Play Time", :kind => :info, :priority => 65,
            :condition => proc { defined?(Graphics) && Graphics.respond_to?(:frame_count) },
            :status => proc { [play_time_words, nil] },
            :description => "How long you've played this save.")
          om.register(:pokedex, :name => "Pokédex", :kind => :info, :priority => 70,
            :condition => proc { $Trainer && $Trainer.respond_to?(:has_pokedex) && $Trainer.has_pokedex },
            :paint => proc { |b, x1, y, h, colours, room| paint_dex(b, x1, y, h, colours, room) },
            :description => "How many Pokémon you've seen and caught. A opens the Pokédex.",
            :handler => proc { |menu| open_pokedex(menu); nil })
          om.register(:badges, :name => "Badges", :kind => :info, :priority => 71,
            :condition => proc { $Trainer && $Trainer.respond_to?(:badges) && $Trainer.badges.is_a?(Array) },
            :paint => proc { |b, x1, y, h, colours| paint_badges(b, x1, y, h, colours) },
            :description => "Your badges, the ones you've earned lit.")
          om.register(:shiny_odds, :name => "Shiny Odds", :kind => :info, :priority => 72,
            :status => proc { [_INTL("1 in {1}", shiny_odds), :gold] },
            :description => "Your chance of a shiny wild Pokémon now: KIF's Wild Shiny Odds, with the Shiny Charm and your friends. While a Poké Radar chain is going, the chance in its shaking grass.")
          om.register(:coins, :name => "Coins", :kind => :info, :priority => 73,
            :condition => proc { Reloaded::OverworldMenu.has_item?(:COINCASE) && $Trainer.respond_to?(:coins) },
            :status => proc { [number_words($Trainer.coins), nil] },
            :description => "Your Game Corner coins, once you have the Coin Case.")
          om.register(:roaming, :name => "Roaming Pokémon", :kind => :info, :priority => 74,
            :condition => proc { !roamers.empty? },
            :label => proc { r = roamers; r.length == 1 ? r[0][0] : "" },
            :status => proc { r = roamers; r.length == 1 ? [r[0][1], nil] : [r.length.to_s, nil] },
            :description => "Where a roaming Pokémon is now, once one is loose. A lists each one and where it is.",
            :handler => proc { |menu| roaming(menu); nil })
        end

        # SEEN 112 CAUGHT 64 ending at x1: the counts in the row's font, small
        # words before each (all small when that's wider than room). Returns
        # its width.
        def paint_dex(b, x1, y, h, c, room)
          px = Reloaded::Pixel
          pf = ::KIF::PixelFont
          dex = $Trainer.pokedex
          seen = number_words(dex.seen_count)
          caught = number_words(dex.owned_count)
          parts = [[_INTL("SEEN"), pf::TINY, c[:dim], 3], [seen, pf::ROW, c[:txt], 8],
                   [_INTL("CAUGHT"), pf::TINY, c[:dim], 3], [caught, pf::ROW, c[:green], 0]]
          w = parts.sum { |t, f, _c, gap| px.width(f, t) + gap }
          if room && w > room
            text = _INTL("Seen {1} · Caught {2}", seen, caught)
            tw = px.width(pf::TINY, text)
            px.text(b, x1 - tw, y + 8, tw + 2, 11, text, c[:txt], pf::TINY)
            return tw
          end
          x = x1 - w
          parts.each do |t, f, colour, gap|
            tw = px.width(f, t)
            f == pf::TINY ? px.text(b, x, y + 9, tw + 2, 11, t, colour, f) : px.text(b, x, y, tw + 2, h, t, colour, f)
            x += tw + gap
          end
          return w
        end

        # The Pokédex, as the pause menu opens it (the menu out of sight)
        def open_pokedex(menu)
          menu.hidden do
            if defined?(::Settings::USE_CURRENT_REGION_DEX) && ::Settings::USE_CURRENT_REGION_DEX
              pbFadeOutIn { ::PokemonPokedexScreen.new(::PokemonPokedex_Scene.new).pbStartScreen }
            else
              $PokemonGlobal.pokedexDex = $Trainer.pokedex.accessible_dexes[0]
              pbFadeOutIn { ::PokemonPokedexMenuScreen.new(::PokemonPokedexMenu_Scene.new).pbStartScreen }
            end
          end
        end

        # The badges as pips ending at x1, the earned ones gold: eight, or
        # sixteen once one past the eighth is earned. Returns their width.
        def paint_badges(b, x1, y, h, c)
          list = $Trainer.badges
          n = list.length > 8 && list[8..-1].any? ? 16 : 8
          size = n == 16 ? 6 : 8
          gap = n == 16 ? 2 : 3
          w = n * size + (n - 1) * gap
          x = x1 - w
          top = y + (h - size) / 2
          n.times do |i|
            lit = list[i] == true
            px = x + i * (size + gap)
            fill = lit ? c[:gold] : c[:dark]
            Reloaded::Pixel.ui.rbox(b, px, top, px + size, top + size, 2, fill, lit ? c[:gold] : c[:line])
          end
          return w
        end

        # 1 in this many: KIF's Wild Shiny Odds (out of 65536), with the
        # Shiny Charm's two extra rolls and PIF's friends' rolls; while a
        # Poké Radar chain is going, its shaking grass's (KIF's, else PIF's)
        def shiny_odds
          odds = defined?(::KIF) && ::KIF.respond_to?(:shiny_odds) ? ::KIF.shiny_odds.to_i : ::Settings::SHINY_POKEMON_CHANCE.to_i
          odds = [odds, 1].max
          chain = radar_chain
          if chain > 0
            return ::KIF::RadarPlus.odds_denominator(chain, odds) if defined?(::KIF::RadarPlus) && ::KIF::RadarPlus.respond_to?(:odds_denominator)
            return [(65536 / odds) - [chain, 40].min * 200, 200].max
          end
          p = [odds / 65536.0, 1.0].min
          rolls = 1
          rolls += 2 if defined?(::GameData::Item) && ::GameData::Item.exists?(:SHINYCHARM) && Reloaded::OverworldMenu.has_item?(:SHINYCHARM)
          friends = ($Trainer.nb_npc_friends.to_i rescue 0).clamp(0, 100) / 100.0 * 2
          miss = (1 - p)**(rolls + friends.floor) * (1 - (friends - friends.floor) * p)
          return [(1.0 / [1 - miss, 1e-9].max).round, 1].max
        rescue StandardError
          return 4096
        end

        # 12,345
        def number_words(n)
          n = n.to_i
          return n.respond_to?(:to_s_formatted) ? n.to_s_formatted : n.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
        end

        # [[name, the map it's on]] of the roaming Pokémon loose now, as PIF
        # finds them (its switch on, not caught)
        def roamers
          return [] unless defined?(::Settings::ROAMING_SPECIES) && $PokemonGlobal && $PokemonGlobal.respond_to?(:roamPosition)
          spots = $PokemonGlobal.roamPosition || {}
          caught = Array($PokemonGlobal.roamPokemon)
          out = []
          ::Settings::ROAMING_SPECIES.each_with_index do |data, i|
            next if data[2].to_i > 0 && !($game_switches[data[2]] rescue false)
            next if caught[i] == true || spots[i].nil?
            name = (::GameData::Species.get(data[0]).name.to_s rescue data[0].to_s)
            map = defined?(pbGetMapNameFromId) ? (pbGetMapNameFromId(spots[i]) rescue "").to_s.split(" (")[0].to_s : spots[i].to_s
            out << [name, map]
          end
          return out
        rescue StandardError
          return []
        end

        def roaming(menu)
          list = roamers
          return nil if list.empty?
          words = list.map { |name, map| _INTL("{1}: {2}.", name, map) }.join(" ")
          menu.notice(_INTL("Roaming Pokémon"), words)
          return nil
        end

        # Area Encounters' tabs, in this order: how the wild Pokémon here are
        # met, each from the game's tables (base types: the one for the time
        # of day is used, as the game does). A table named other than its tab
        # gets its own heading (the rods, the other grass patches).
        AREA_TABS = [["Grass", [[:Land, "Grass"], [:Land1, "Grass 2"], [:Land2, "Grass 3"], [:Land3, "Grass 4"], [:TallGrass, "Tall Grass"]]],
                     ["Cave", [[:Cave, "Cave"]]],
                     ["Surfing", [[:Water, "Surfing"]]],
                     ["Fishing", [[:OldRod, "Old Rod"], [:GoodRod, "Good Rod"], [:SuperRod, "Super Rod"]]],
                     ["Rock Smash", [[:RockSmash, "Rock Smash"]]],
                     ["Bug Contest", [[:BugContest, "Bug Contest"]]]].freeze

        # [[tab, [[heading or nil, [[rate, species, min level, max level]...]]...]]...]
        # for this map now; the Bug Contest's only during the contest
        def area_tabs
          enc = $PokemonEncounters
          tables = enc ? (enc.instance_variable_get(:@encounter_tables) || {}) : {}
          return [] if tables.empty?
          now = defined?(pbGetTimeNow) ? pbGetTimeNow : Time.now
          out = []
          AREA_TABS.each do |tab, parts|
            next if tab == "Bug Contest" && !(defined?(pbInBugContest?) && pbInBugContest?)
            sections = []
            parts.each do |base, words|
              type = enc.respond_to?(:find_valid_encounter_type_for_time) ? enc.find_valid_encounter_type_for_time(base, now) : base
              rows = area_rows(tables[type])
              sections << [words == tab ? nil : words, rows] unless rows.empty?
            end
            out << [tab, sections] unless sections.empty?
          end
          return out
        rescue StandardError => e
          Reloaded::Log.exception("Area Encounters couldn't read this map's encounters", e, :overworld_menu)
          return []
        end

        # A table's slots, one row per species (its chances added up, its
        # levels from lowest to highest), the likeliest first
        def area_rows(slots)
          rows = {}
          Array(slots).each do |slot|
            next unless slot.is_a?(Array) && slot[1]
            r = (rows[slot[1]] ||= [0, slot[1], slot[2].to_i, slot[3].to_i])
            r[0] += slot[0].to_i
            r[2] = [r[2], slot[2].to_i].min
            r[3] = [r[3], slot[3].to_i].max
          end
          return rows.values.each_with_index.sort_by { |r, i| [-r[0], i] }.map(&:first)
        end

        # KIF's Level Cap, else PIF's Level Caps option (as Super Candy reads
        # them), or nil while neither is on
        def level_cap
          return Reloaded::QualityOfLife.active_cap if defined?(Reloaded::QualityOfLife) && Reloaded::QualityOfLife.respond_to?(:active_cap)
          return nil unless defined?(::KIF::LevelCap) && ::KIF::LevelCap.respond_to?(:cap)
          return ::KIF::LevelCap.cap
        rescue StandardError
          return nil
        end

        # [[Pokémon, level when left, slot]] in the Day Care
        def day_care
          return Array($PokemonGlobal.daycare).each_with_index.map { |(p, lv), i| [p, lv, i] }.select { |p, _lv, _i| p }
        rescue StandardError
          return []
        end

        # What taking one back costs, as the game charges it
        def day_care_cost(slot, pkmn, level)
          return pbDayCareGetCost(slot).to_i if defined?(pbDayCareGetCost)
          return (pkmn.level - level.to_i + 1) * 100
        rescue StandardError
          return 0
        end

        # How well the two get along, 0 (no Eggs) to 3, as the game works it
        # out (KIF Beta's own for fusions and legendaries)
        def day_care_compat
          return 0 if day_care.length < 2 || !defined?(pbDayCareGetCompat)
          return pbDayCareGetCompat.to_i.clamp(0, 3)
        rescue StandardError
          return 0
        end

        def day_care_egg?
          return defined?(pbEggGenerated?) && pbEggGenerated? ? true : false
        rescue StandardError
          return false
        end

        def day_care_status
          return [_INTL("Egg"), :gold] if day_care_egg?
          n = day_care.length
          return n > 0 ? [_INTL("{1} Inside", n), nil] : [_INTL("Empty"), :dim]
        end

        def radar_chain
          return ::KIF::RadarPlus.chain.to_i if defined?(::KIF::RadarPlus) && ::KIF::RadarPlus.respond_to?(:chain)
          r = $PokemonTemp && $PokemonTemp.respond_to?(:pokeradar) ? $PokemonTemp.pokeradar : nil
          return r ? r[2].to_i : 0
        rescue StandardError
          return 0
        end

        # "41h 12m"
        def play_time_words
          seconds = Graphics.frame_count / [Graphics.frame_rate, 1].max
          return "#{seconds / 3600}h #{seconds / 60 % 60}m"
        end

        def main_quest
          return nil unless $Trainer && $Trainer.respond_to?(:quests) && $Trainer.quests
          return $Trainer.quests.find { |q| q && !q.completed && q.type == :MAIN_QUEST }
        rescue StandardError
          return nil
        end

        def safari?
          return defined?(pbInSafari?) && pbInSafari? ? true : false
        rescue StandardError
          return false
        end

        def contest?
          return defined?(pbInBugContest?) && pbInBugContest? ? true : false
        rescue StandardError
          return false
        end

        def contest_words
          s = pbBugContestState
          return s.lastPokemon ? "#{s.lastPokemon.speciesName} Lv #{s.lastPokemon.level}" : _INTL("Nothing Yet")
        end

        def quit_safari(menu)
          return nil unless menu.confirm(_INTL("Quit Safari"), _INTL("Leave the Safari Game right now?"))
          return proc do
            pbSafariState.decision = 1
            pbSafariState.pbGoToStart
          end
        end

        def quit_contest(menu)
          return nil unless menu.confirm(_INTL("Quit Contest"), _INTL("End the Contest now?"))
          return proc { pbBugContestState.pbStartJudging }
        end

        def itemfinder?
          return [:ITEMFINDER, :DOWSINGMACHINE, :DOWSINGMCHN].any? { |i| Reloaded::OverworldMenu.has_item?(i) }
        end

        # ["3 N, 2 E", :green], ["Right Here"], or ["None Nearby", :dim]
        def hidden_item_words
          ev = defined?(pbClosestHiddenItem) ? pbClosestHiddenItem : nil
          return [_INTL("None Nearby"), :dim] unless ev
          dx = ev.x - $game_player.x
          dy = ev.y - $game_player.y
          parts = []
          parts << "#{dy.abs} #{dy < 0 ? _INTL("N") : _INTL("S")}" if dy != 0
          parts << "#{dx.abs} #{dx < 0 ? _INTL("W") : _INTL("E")}" if dx != 0
          return [parts.empty? ? _INTL("Right Here") : parts.join(", "), :green]
        rescue StandardError
          return nil
        end
      end

      # Speed-Up's choices follow the game's speeds (KIF's limit can change
      # them): x1, x2, x3...
      class SpeedValues
        def [](i)
          return "x#{(SPEEDUP_STAGES[i] rescue 1)}"
        end

        def length
          return (SPEEDUP_STAGES.length rescue 1)
        end
      end
    end
  end
end
