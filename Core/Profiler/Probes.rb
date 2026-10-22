#==============================================================================
# Kanto Reloaded: what the Timing Profiler times
#==============================================================================
# The probes: each wraps one of the game's methods (a prepended module, so
# it knows its object), as a session or as a section of the session running
# then. They go in the first time the profiler runs.
#
#   Reloaded::Profiler::Probes.section("PokeBattle_Battle", :pbAttackPhase, "Attack Phase", :battle,
#                                      :about => "The turn's moves...")
#
# A feature times its own work with Profiler.measure, or a probe of its own
# (Probes.section). A probe whose class or method isn't in this game is
# skipped (KIF Beta without EBDX, an older PIF).
#==============================================================================

module Reloaded
  module Profiler
    module Probes
      BATTLE = [
        ["PokeBattle_Battle", :pbStartBattleCore, "Battle Start", "Sending out the first Pokémon and the battle's opening, intro animations included."],
        ["PokeBattle_Battle", :pbCommandPhase, "Command Phase", "Choosing what to do: The menus' work while you pick (the time you spend thinking isn't counted, only the frames' work)."],
        ["PokeBattle_Battle", :pbAttackPhase, "Attack Phase", "The turn's moves, items and switches, their animations included."],
        ["PokeBattle_Battle", :pbEndOfRoundPhase, "End-of-Round Phase", "Weather, status damage, held items and other end-of-turn effects."],
        ["PokeBattle_Scene", :pbStartBattle, "Scene Setup", "Making the battle scene: The background, the Pokémon and trainer sprites, the databoxes."],
        ["PokeBattle_Scene", :pbFrameUpdate, "Native Frame Work", "The battle scene's own work each frame (PIF's scene)."],
        ["PokeBattle_SceneEBDX", :pbFrameUpdate, "EBDX Frame Work", "EBDX's work each frame: Its animated scene and sprites."],
        ["PokeBattle_Scene", :pbEndBattle, "Scene End", "Taking the battle scene down at the end."],
        ["CommandWindowEBDX", :refreshCommands, "EBDX Command Refresh", "EBDX redrawing the Fight / Bag / Pokémon / Run buttons."],
        ["FightWindowEBDX", :generateButtons, "EBDX Fight Refresh", "EBDX drawing the four move buttons."],
        ["BagWindowEBDX", :refresh, "EBDX Bag Refresh", "EBDX redrawing the battle bag."],
        ["TargetWindowEBDX", :refresh, "EBDX Target Refresh", "EBDX redrawing the target picker."]
      ].freeze
      MAP = [
        ["PokemonMapFactory", :setup, "Map Data Load", "Loading the map and the maps next to it: Their data, tiles and events."],
        ["Game_Map", :setup, "Map Setup", "One map's setup: Its data file, tileset, fog and every event on it."],
        ["Game_Event", :initialize, "Events Setup", "Making the map's events, one call each."],
        ["Scene_Map", :disposeSpritesets, "Sprites Dispose", "Taking down the last map's sprites."],
        ["Scene_Map", :createSpritesets, "Sprites Build", "Building the new map's tilemap, character sprites and weather."],
        ["Game_Map", :autoplay, "Music Change", "Starting the map's music and sounds."],
        ["Scene_Map", :update_last_visited_location, "Town Map Check", "Looking the map up in the Town Map (the Fly spot you last visited)."]
      ].freeze
      MENUS = [
        ["PokemonPauseMenu_Scene", :pbStartScene, :pbEndScene, "Pause Menu"],
        ["PokemonBag_Scene", :pbStartScene, :pbEndScene, "Bag"],
        ["PokemonParty_Scene", :pbStartScene, :pbEndScene, "Party"],
        ["PokemonSummary_Scene", :pbStartScene, :pbEndScene, "Summary"],
        ["PokemonPokedex_Scene", :pbStartScene, :pbEndScene, "Pokédex"],
        ["PokemonStorageScene", :pbStartBox, :pbCloseBox, "PC"]
      ].freeze

      @installed = []
      @skipped = []

      class << self
        attr_reader :installed, :skipped

        def install
          battle_session
          BATTLE.each { |c, m, label, about| section(c, m, label, :battle, :about => about) }
          map_session
          MAP.each { |c, m, label, about| section(c, m, label, :map, :about => about) }
          MENUS.each { |c, start, finish, name| menu(c, start, finish, name) }
          saving
          return true
        end

        # Times target#method as a section of the session running then
        # (while kind is timed). owner: whose code it is (by default, the
        # file the method is in now).
        def section(target, method, label, kind, about: nil, owner: nil)
          klass = method_target(target, method)
          return false unless klass
          owner ||= owner_of(klass, method)
          mod = Module.new do
            define_method(method) do |*args, **kwargs, &blk|
              return super(*args, **kwargs, &blk) unless Reloaded::Profiler.times?(kind)
              Reloaded::Profiler.measure(label, :owner => owner, :about => about) { super(*args, **kwargs, &blk) }
            end
          end
          return add(klass, method, mod, label)
        end

        # Times target#method as a session: the block gives its name (and
        # info) from the object and arguments: |obj, args| [name, info].
        def session(target, method, kind, about: nil, &namer)
          klass = method_target(target, method)
          return false unless klass
          mod = Module.new do
            define_method(method) do |*args, **kwargs, &blk|
              return super(*args, **kwargs, &blk) unless Reloaded::Profiler.times?(kind)
              name, info = (namer.call(self, args) rescue [nil, nil])
              Reloaded::Profiler.session(kind, name || method.to_s, info || {}) { super(*args, **kwargs, &blk) }
            end
          end
          return add(klass, method, mod, "#{kind} session")
        end

        private

        # A battle: named after its trainers ("Brock"), or Wild Battle.
        def battle_session
          session("PokeBattle_Battle", :pbStartBattle, :battle) do |battle, _args|
            trainers = Array(battle.instance_variable_get(:@opponent)).compact
            name = trainers.empty? ? "Wild Battle" : trainers.map { |t| (t.name rescue t.to_s).to_s }.uniq.join(" & ")
            info = proc do
              { "Turns" => battle.instance_variable_get(:@turnCount), "Decision" => decision(battle.instance_variable_get(:@decision)),
                "Sides" => Array(battle.instance_variable_get(:@sideSizes)).join(" vs "),
                "Scene" => (battle.instance_variable_get(:@scene).class.name rescue "?"), "Network" => network_mode }
            end
            [name, info]
          end
        end

        # A map transfer: named after where you're going.
        def map_session
          session("Scene_Map", :transfer_player, :map) do |_scene, _args|
            id = ($game_temp.player_new_map_id rescue nil)
            name = id && defined?(pbGetMapNameFromId) ? (pbGetMapNameFromId(id) rescue nil) : nil
            [name.to_s.empty? ? "Map #{id}" : name, { "Map" => id }]
          end
        end

        # A menu: a session from opening to closing (Open and Close are its
        # sections; what you do in it, its Frame Work).
        def menu(target, start, finish, name)
          klass = method_target(target, start)
          return false unless klass && method_target(target, finish)
          owner = owner_of(klass, start)
          opener = Module.new do
            define_method(start) do |*args, **kwargs, &blk|
              return super(*args, **kwargs, &blk) unless Reloaded::Profiler.times?(:menu)
              old = instance_variable_get(:@kr_profile)
              Reloaded::Profiler.finish_session(old) if old && Reloaded::Profiler.running?(old)
              s = Reloaded::Profiler.start_session(:menu, name)
              instance_variable_set(:@kr_profile, s)
              Reloaded::Profiler.measure("Open", :owner => owner, :about => "Opening the #{name}: its graphics and the first draw.") do
                super(*args, **kwargs, &blk)
              end
            end
          end
          closer = Module.new do
            define_method(finish) do |*args, **kwargs, &blk|
              s = instance_variable_get(:@kr_profile)
              return super(*args, **kwargs, &blk) unless s && Reloaded::Profiler.running?(s)
              begin
                Reloaded::Profiler.measure("Close", :owner => owner, :about => "Closing the #{name}.") { super(*args, **kwargs, &blk) }
              ensure
                instance_variable_set(:@kr_profile, nil)
                Reloaded::Profiler.finish_session(s)
              end
            end
          end
          add(klass, start, opener, "#{name} open")
          add(klass, finish, closer, "#{name} close")
          section(target, :pbRefresh, "Refresh", :menu, :about => "Redrawing the #{name}.") if klass.method_defined?(:pbRefresh)
          return true
        end

        def saving
          if defined?(::Game) && ::Game.respond_to?(:save)
            session(::Game.singleton_class, :save, :saving) { |_g, _a| ["Saving", {}] }
          end
          if defined?(::SaveData) && ::SaveData.respond_to?(:save_to_file)
            section(::SaveData.singleton_class, :save_to_file, "Write Save File", :saving,
                    :about => "Writing the save file (and its backup).")
          end
          if defined?(::Game) && ::Game.respond_to?(:load)
            session(::Game.singleton_class, :load, :loading) { |_g, _a| ["Loading Save", {}] }
          end
        end

        def decision(value)
          return { 0 => "Undecided", 1 => "Won", 2 => "Lost", 3 => "Ran", 4 => "Caught", 5 => "Draw" }[value] || value.to_s
        end

        def network_mode
          return "Co-op" if defined?(::CoopBattleState) && (::CoopBattleState.in_coop_battle? rescue false)
          return "PvP" if defined?(::MultiplayerClient) && (::MultiplayerClient.pvp_active? rescue false)
          return "Solo"
        end

        def method_target(target, method)
          klass = target.is_a?(Module) ? target : Reloaded::DataPatches.resolve(target.to_s)
          unless klass && (klass.method_defined?(method) || klass.private_method_defined?(method))
            @skipped << "#{target}##{method}"
            return nil
          end
          return klass
        end

        def owner_of(klass, method)
          file = (klass.instance_method(method).source_location || [])[0]
          return Owners.of(file)
        rescue StandardError
          return Owners::PIF
        end

        def add(klass, method, mod, what)
          mod.send(:private, method) if klass.private_method_defined?(method)
          mod.send(:protected, method) if klass.protected_method_defined?(method)
          id = :"profiler_#{klass.name.to_s.downcase.gsub(/[^a-z0-9]+/, "_")}_#{method}_#{@installed.length}"
          Reloaded::Hooks.prepend(nil, klass, mod, :id => id)
          @installed << "#{klass}##{method} (#{what})"
          return true
        end
      end
    end
  end
end
