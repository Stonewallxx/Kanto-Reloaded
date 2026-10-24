#==============================================================================
# Kanto Reloaded: Recent Steps
#==============================================================================
# The last 100 things that happened, in memory only, for a bug report's
# timeline: map changes, battles (who, and how they ended), menus opened,
# saves, loads and new games, the title screen, and errors (Log.error adds
# them). Nothing shows while you play.
#
#   Reloaded::BugReport::Trail.add(:map, "Route 1")
#   Reloaded::BugReport::Trail.lines     # ["14:02:11  Map  Route 1", ...]
#==============================================================================

module Reloaded
  module BugReport
    module Trail
      MAX = 100
      KINDS = { :map => "Map", :battle => "Battle", :menu => "Menu", :save => "Save", :load => "Load",
                :title => "Title", :error => "Error", :crash => "Crash", :note => "Note" }.freeze
      MENUS = [["PokemonPauseMenu_Scene", :pbStartScene, "Pause Menu"], ["PokemonBag_Scene", :pbStartScene, "Bag"],
               ["PokemonParty_Scene", :pbStartScene, "Party"], ["PokemonSummary_Scene", :pbStartScene, "Summary"],
               ["PokemonPokedex_Scene", :pbStartScene, "Pokédex"], ["PokemonStorageScene", :pbStartBox, "PC"],
               ["PokemonMart_Scene", :pbStartBuyOrSellScene, "Mart"], ["KifSettingsScreen", :main, "Settings"]].freeze

      @steps = []

      # Mixed into PIF's battle: its start and how it ended.
      module BattleSteps
        def pbStartBattle(*args, **kwargs, &blk)
          Reloaded::BugReport::Trail.battle(self, :start)
          result = super
          Reloaded::BugReport::Trail.battle(self, :end)
          return result
        end
      end

      # Mixed into the map scene: where the player went.
      module MapSteps
        def transfer_player(*args, **kwargs, &blk)
          result = super
          Reloaded::BugReport::Trail.map_changed
          return result
        end
      end

      class << self
        attr_reader :steps

        # The game always has these; outside it (the preview tool) the ones
        # it hasn't got are left out quietly.
        def install
          hooks = Reloaded::Hooks
          hooks.prepend(nil, "PokeBattle_Battle", BattleSteps, :id => :trail_battles) if has?("PokeBattle_Battle", :pbStartBattle)
          hooks.prepend(nil, "Scene_Map", MapSteps, :id => :trail_maps) if has?("Scene_Map", :transfer_player)
          # (watchers: Kanto Reloaded's own Party and Bag scenes are seen too)
          MENUS.each do |target, method, name|
            next unless has?(target, method)
            key = :"trail_menu_#{name.downcase.gsub(/[^a-z]+/, "_")}"
            mod = Module.new do
              define_method(method) do |*args, **kwargs, &blk|
                return super(*args, **kwargs, &blk) if Reloaded::Hooks.watching?(self, key)
                Reloaded::Hooks.watching(self, key) do
                  Reloaded::BugReport::Trail.add(:menu, name)
                  # This Screen: the map behind the Pause Menu (Settings, at the title)
                  if name == "Pause Menu" || name == "Settings"
                    Reloaded::BugReport.remember_screen(name == "Settings" ? :settings : :pause) rescue nil
                  end
                  super(*args, **kwargs, &blk)
                end
              end
            end
            hooks.watch(target, mod, :id => key)
          end
          ev = Reloaded::Events
          ev.on(:saved, :trail_saved) { |c| add(:save, File.basename(c[:path].to_s, ".rxdata")) }
          ev.on(:save_loaded, :trail_loaded) do
            add(:load, loaded_words)
            map_changed(true)                    # where the save starts
          end
          ev.on(:new_game, :trail_new_game) { add(:load, _INTL("New Game")) }
          ev.on(:title_screen, :trail_title) { add(:title, _INTL("Title Screen")) }
          return true
        end

        def has?(target, method)
          klass = (Object.const_get(target) rescue nil)
          return klass.is_a?(Module) && (klass.method_defined?(method) || klass.private_method_defined?(method))
        end

        def add(kind, text)
          @steps << [Time.now, kind, text.to_s[0, 160]]
          @steps.shift while @steps.length > MAX
          return true
        end

        def clear
          @steps = []
        end

        # "14:02:11  Battle  Started: Brock (Trainer)"
        def lines
          return @steps.map { |t, kind, text| "#{t.strftime("%H:%M:%S")}  #{KINDS[kind] || kind.to_s.capitalize}  #{text}" }
        end

        # The last place the player was (After a Crash: "on Route 24").
        def last_map
          step = @steps.reverse.find { |_t, kind, _x| kind == :map }
          return step ? step[2] : nil
        end

        # Last time a battle started and didn't end, it's going on now.
        def in_battle?
          last = @steps.reverse.find { |_t, kind, _x| kind == :battle }
          return last && last[2].start_with?(_INTL("Started"))
        end

        def battle(battle, phase)
          trainers = Array(battle.instance_variable_get(:@opponent)).compact
          who = trainers.empty? ? _INTL("Wild Battle") : trainers.map { |t| (t.name rescue t.to_s).to_s }.uniq.join(" & ")
          if phase == :start
            add(:battle, _INTL("Started: {1}", who))
          else
            turns = battle.instance_variable_get(:@turnCount).to_i
            add(:battle, _INTL("Ended: {1}, {2} after {3} turns", who, decision(battle.instance_variable_get(:@decision)), turns))
          end
        rescue StandardError
          nil
        end

        # loaded: just after a save loaded, when the map is only in
        # $MapFactory (a $game_map then is the last game's).
        def map_changed(loaded = false)
          id = loaded ? ($MapFactory.map.map_id rescue nil) : nil
          id ||= ($game_map.map_id rescue nil)
          return if id.nil?
          name = id && defined?(pbGetMapNameFromId) ? (pbGetMapNameFromId(id) rescue nil) : nil
          name = name.to_s.empty? ? "Map #{id}" : name.to_s
          add(:map, name)
          Crash.where_now(name) if defined?(Crash)
        rescue StandardError
          nil
        end

        private

        def loaded_words
          slot = ($Trainer.save_slot rescue nil)
          return slot ? slot.to_s : _INTL("A Save")
        end

        def decision(value)
          return { 0 => _INTL("Undecided"), 1 => _INTL("Won"), 2 => _INTL("Lost"), 3 => _INTL("Ran"),
                   4 => _INTL("Caught"), 5 => _INTL("Draw") }[value] || value.to_s
        end
      end
    end
  end
end
