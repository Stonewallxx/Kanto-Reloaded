#==============================================================================
# Kanto Reloaded: features split off the game's buttons
#==============================================================================
# KIF Beta and PIF give several features one game button: Back opens the
# pause menu on the map, Action runs, X speeds up, Y quicksaves... Each of
# those features is its own action here. It follows its button, so nothing
# changes until the player rebinds it (Pokémon-Style moves Run to B, say).
#
# A feature asks for its button the usual way: Input.trigger?(Input::Y).
# A split answers that question with the feature's action instead, but only
# for checks made by the feature's own script file: Quicksave.rb's checks of
# Y are Quicksave's, while the Bag's checks of Y stay the Y button's. The
# game loads Data\Scripts with only each file's name, so a split names
# files. If an update moves a feature's check to another file, that feature
# just follows its button again, and the log says so at startup.
#
# Splits answer only while Reloaded Controls is On (Off: the game's own
# controls, untouched). A mod can split its own features the same way:
#
#   Reloaded::Controls::Splits.add(:my_menu, :button => :Z,
#     :files => ["MyMod.rb"], :name => "My Menu", :area => :overworld,
#     :description => "Opens My Menu.")
#==============================================================================

module Reloaded
  module Controls
    module Splits
      # [id, game button, files, name, area, group, description]
      FEATURES = [
        [:run,           :A, ["010_Game_Player_Visuals.rb"], "Run", :overworld, "Moving",
         "Run while held (walk while held when running is the default). On a bike: Its boost or trick."],
        [:pause_menu,    :B, ["002_Scene_Map.rb"], "Pause Menu", :overworld, "Menus",
         "Opens the pause menu on the map."],
        [:ready_menu,    :Z, ["002_Scene_Map.rb"], "Ready Menu", :overworld, "Menus",
         "Opens the Ready Menu: The key items you registered."],
        [:quicksave,     :Y, ["Quicksave.rb"], "Quicksave", :overworld, "Other",
         "Saves on the map, while KIF's Quicksave is on."],
        [:skip_cutscene, :Z, ["002_Game_System.rb"], "Skip Cutscene", :overworld, "Other",
         "Skips a cutscene that can be skipped."],
        [:battle_info,   :A, ["BattleInfo.rb"], "Battle Info", :battle, "Battle Menu",
         "Opens KIF's Battle Info from the battle menu, and closes it again."],
        [:mega,          :A, ["008_Scene_Commands.rb", "010_EBDX_Scene.rb"], "Mega Evolve", :battle, "Fight Menu",
         "Mega Evolves in the fight menu (EBDX battles)."],
        [:shift,         :Z, ["008_Scene_Commands.rb", "010_EBDX_Scene.rb"], "Shift", :battle, "Fight Menu",
         "Moves to the middle in a triple battle."],
        [:speed_up,      :X, ["Spped Up.rb", "SpeedTitle.rb"], "Speed-Up", :global, "Game Speed",
         "Speeds the game up while held, or steps the speed when Speed-Up toggles."],
        [:next_speed,    :L, ["SpeedTitle.rb"], "Next Speed", :global, "Game Speed",
         "The next game speed, when Speed-Up toggles."],
        [:reset_speed,   :R, ["SpeedTitle.rb"], "Reset Speed", :global, "Game Speed",
         "The game speed back to normal, when Speed-Up toggles."]
      ].freeze

      # Splits left out of the Controls screen while a mod locks their KIF
      # setting Off (Kanto Reloaded's Battle Menu, while it's On): split id
      # => KIF setting. They're still made, for when the lock goes.
      OFF_WHEN_LOCKED = { :battle_info => :cody_battleinfo }.freeze

      # KIF settings named after a split feature's key: shown by the feature's
      # name, and described with the key it's on now.
      # KIF name => [action id, label, descriptions by value]
      KIF_SETTINGS = {
        "Quicksave" => [:quicksave, "Quicksave",
                        ["{1} does nothing on the map.", "Press {1} on the map to open the save screen."]]
      }.freeze
      # what KIF Beta called them before (0.21.55 and older): old name => today's
      OLD_KIF_NAMES = { "Quicksave with S" => "Quicksave" }.freeze

      @rules = {}          # game button => [[file name, action id], ...]
      @cache = {}          # button => { caller path => action id or false }
      @splits = []

      # The game's Input, answered for split checks. Its methods sit above
      # every wrapper, so the method calling them is the game's own code.
      module Answer
        def press?(*args)
          id = Reloaded::Controls::Splits.watching?(args[0]) && Reloaded::Controls::Splits.action_at(args[0], caller_locations(1, 1)[0])
          return id ? Reloaded::Controls::Layer.action_state(:press, id) : super
        end

        def trigger?(*args)
          id = Reloaded::Controls::Splits.watching?(args[0]) && Reloaded::Controls::Splits.action_at(args[0], caller_locations(1, 1)[0])
          return id ? Reloaded::Controls::Layer.action_state(:trigger, id) : super
        end

        def repeat?(*args)
          id = Reloaded::Controls::Splits.watching?(args[0]) && Reloaded::Controls::Splits.action_at(args[0], caller_locations(1, 1)[0])
          return id ? Reloaded::Controls::Layer.action_state(:repeat, id) : super
        end

        def release?(*args)
          id = Reloaded::Controls::Splits.watching?(args[0]) && Reloaded::Controls::Splits.action_at(args[0], caller_locations(1, 1)[0])
          return id ? Reloaded::Controls::Layer.action_state(:release, id) : super
        end
      end

      class << self
        attr_reader :splits

        # The game's features, split, and Input answering for them.
        def boot
          FEATURES.each do |id, button, files, name, area, group, desc|
            next unless ::Input.const_defined?(button) && Controls.button_action(::Input.const_get(button))
            add(id, :button => button, :files => files, :name => name, :area => area, :group => group,
                    :description => desc, :owner => :game)
          end
          check_files
          Reloaded::Hooks.prepend(nil, ::Input.singleton_class, Answer, :id => :controls_splits)
          rename_kif_settings
          OFF_WHEN_LOCKED.each { |id, key| Reloaded::Hooks.needs(:kif_option, key, :id => :"controls_split_#{id}") }
          KIF_SETTINGS.each { |name, (id, _l, _t)| Reloaded::Hooks.needs(:kif_setting, name, :id => :"controls_split_#{id}") }
          return true
        end

        # Split files that are gone or no longer check their button:
        # [[split id, file, why], ...] (from boot).
        def file_problems
          return Array(@file_problems).dup
        end

        # The description of a KIF setting in KIF_SETTINGS, with its
        # feature's key now (the key KIF's Y is on while Reloaded Controls
        # is Off), or nil to keep KIF's.
        def kif_description(opt)
          name = opt.name.to_s.strip
          entry = KIF_SETTINGS[name] || KIF_SETTINGS[OLD_KIF_NAMES[name]]
          return nil unless entry
          id, _label, texts = entry
          key = if Layer.active? then Controls.label(id)
                elsif defined?(::KIF::Keys) then ::KIF::Keys.short(Controls.action(Controls.action(id).follows).button)
                end
          return nil if key.to_s.empty?
          v = (opt.get rescue 0)
          text = texts[v.is_a?(Integer) ? v : 0] || texts[0]
          return _INTL(text, key)
        rescue StandardError
          return nil
        end

        # Splits a feature off a game button (:A, :B, :X... or Input::X):
        # registers its action following that button, and answers its
        # files' checks of the button with the action.
        def add(id, options = {})
          button = options[:button]
          button = ::Input.const_get(button) if button.is_a?(Symbol)
          follows = Controls.button_action(button)
          raise ArgumentError, "Split #{id}: no action for button #{options[:button].inspect}" unless follows
          files = Array(options[:files]).map { |f| File.basename(f.to_s) }
          raise ArgumentError, "Split #{id} names no files" if files.empty?
          Controls.register(id, :name => options[:name] || id.to_s, :area => options[:area] || :global,
                                :follows => follows.id, :group => options[:group] || "Other",
                                :description => options[:description], :owner => options[:owner],
                                :priority => options[:priority] || 100 + @splits.length)
          files.each { |f| (@rules[button] ||= []) << [f, id.to_sym] }
          @splits << [id.to_sym, button, files]
          @cache = {}
          return id.to_sym
        end

        # Left out of the Controls screen now: its KIF setting is locked Off
        def left_out?(id)
          return locked_off?(OFF_WHEN_LOCKED[id.to_sym])
        end

        # Whether a check of this button might be a split's: the layer is
        # answering and some split uses the button. (Cheap: every query.)
        def watching?(button)
          return false unless @rules.key?(button)
          return Layer.active?
        end

        # The split action a check of button from this place answers for,
        # or nil.
        def action_at(button, location)
          path = location ? location.path.to_s : ""
          known = (@cache[button] ||= {})
          found = known[path]
          if found.nil?
            base = File.basename(path)
            rule = @rules[button].find { |f, _id| f == base }
            found = known[path] = rule ? rule[1] : false
          end
          return found || nil
        rescue StandardError
          return nil
        end

        private

        def locked_off?(key)
          return false unless key && defined?(::KIF::Locks) && ::KIF::Locks.respond_to?(:get)
          lock = ::KIF::Locks.get(key)
          return lock ? [0, false].include?(lock[0]) : false
        rescue StandardError
          return false
        end

        # KIF Settings shows them by their feature's name (in both screens:
        # KIF's own renames table), and describes them with the key now.
        def rename_kif_settings
          return unless defined?(::KIF::SettingsScreen)
          renames = defined?(::KIF::SettingsScreen::RENAMES) ? ::KIF::SettingsScreen::RENAMES : nil
          if renames.is_a?(Hash) && !renames.frozen?
            KIF_SETTINGS.each { |name, (_id, label, _texts)| renames[name] = label }
            OLD_KIF_NAMES.each { |old, now| renames[old] = KIF_SETTINGS[now][1] }
          end
          Reloaded::Hooks.around(nil, ::KIF::SettingsScreen.singleton_class, :description_for,
                                 :id => :controls_kif_descriptions) do |original, opt|
            Reloaded::Controls::Splits.kif_description(opt) || original.call(opt)
          end
        end

        # Each split's files still check its button (a game update could
        # move a check); a split whose file doesn't just follows its button.
        def check_files
          @file_problems = []
          return unless File.directory?(File.join(Reloaded::Paths.game_dir, "Data", "Scripts"))
          @splits.each do |id, button, files|
            names = ::Input.constants.select { |c| (::Input.const_get(c) rescue nil) == button }
            pattern = /Input::(#{names.join("|")})\b/
            files.each do |f|
              path = Reloaded::Paths.script_file(f)
              text = path ? (File.read(path, :encoding => "UTF-8") rescue "") : ""
              next if text.match?(pattern)
              why = path ? "no longer checks #{names.join(" or ")}" : "isn't in Data\\Scripts"
              @file_problems << [id, f, why]
              Reloaded::Log.info("#{Controls.action(id).name}: #{f} #{why}; there it follows #{Controls.action(Controls.action(id).follows).name}", :controls)
            end
          end
        rescue StandardError => e
          Reloaded::Log.exception("Couldn't check the split features' files", e, :controls)
        end
      end
    end
  end
end
