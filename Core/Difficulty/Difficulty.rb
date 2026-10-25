# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Difficulty
#==============================================================================
# PIF's Easy / Normal / Hard with his rules (Roadmap topic difficulty, his
# picks 2026-10-25). Always on with Kanto Reloaded: no switch.
#
#   Shown As   wherever the difficulty shows (the Load Screen, the Hall of
#              Fame, later the Trainer Card), the lowest this save has
#              used: the lower of PIF's own lowest_difficulty and the level
#              the switches say now
#   Lowering   recorded the moment it happens, from any caller
#              (setDifficulty), not only when Options closes; the settings
#              row asks first when it would change Shown As
#   Debug      a Run Tag of its own, purple (not a level): PIF's switch 842,
#              KIF's DEBUG, Kanto Reloaded having seen Debug, saves made
#              without Kanto Reloaded (SaveStore's seal), or a test copy
#              (Saves.make_test_copy). Found, it turns
#              PIF's switch on, so the Hall of Fame and the game mode say
#              Debug too, even with Kanto Reloaded off
#   Hard       PIF's changes, and trainer IVs at least 10: a floor on PIF's
#              own (half their level), so the same trainer is the same
#              every battle
#
# PIF's own code does the rest (it reads switches 665 / 666); Kanto Reloaded
# only sets the level through setDifficulty. At New Game, New Game Setup's
# Difficulty row picks it (NewGame/NewGameSetup.rb: set_difficulty, as PIF's
# Common Event 61 does).
#
#   Reloaded::Difficulty.level / .shown / .shown_name / .tone / .hard_run?
#   Reloaded::Difficulty.debug?                    the Debug Run Tag
#   Events: :difficulty_changed (:from, :to), :difficulty_lowered (:from, :to)
#==============================================================================

module Reloaded
  module Difficulty
    PAGE = :difficulty
    KEY = :"difficulty.level"
    SHOWN_KEY = :"difficulty.shown"
    SECTION = :difficulty
    NAMES = ["Easy", "Normal", "Hard"].freeze
    TONES = [:green, :blue, :red].freeze          # the Load Screen's colours
    DEBUG_COLOUR = [150, 96, 220].freeze          # KR Debug's purple (his pick)
    IV_FLOOR = 10
    HISTORY = 20
    # PIF's switches (CONSTANTS_Switches.rb), if its names aren't there
    SWITCHES = { :SWITCH_GAME_DIFFICULTY_EASY => 665, :SWITCH_GAME_DIFFICULTY_HARD => 666,
                 :ENABLED_DEBUG_MODE_AT_LEAST_ONCE => 842 }.freeze
    # What each level changes, as PIF's code does it (not its "Hard trainers
    # have healing items", which nothing does)
    CHANGES = [
      ["The whole party gains EXP", "No poison damage while walking", "Trainers use their easier movesets"],
      [],
      ["Trainer levels x1.1", "The smartest trainer AI", "Trainers use their harder movesets",
       "Their next Pokémon stays hidden (Switch style)", "Trainer IVs at least 10", "Level caps x1.1"]
    ].freeze

    class << self
      def boot
        Reloaded::SaveStore.register(SECTION)
        register_settings
        install
        # a new game: PIF's Trainer.new says Hard until its prompt sets the level
        Reloaded::Events.on(:save_loaded, :difficulty, 40) { |c| loaded! unless c.is_a?(Hash) && c[:new_game] }
        Reloaded::Events.on(:saving, :difficulty, 40) { loaded! }
        return true
      end

      #------------------------------------------------------------------------
      # The level, the lowest, Shown As
      #------------------------------------------------------------------------
      def ready?
        return $Trainer && $game_switches ? true : false
      end

      def switch_id(name)
        return Object.const_defined?(name) ? Object.const_get(name) : SWITCHES[name]
      end

      def switch?(name)
        return $game_switches && $game_switches[switch_id(name)] ? true : false
      rescue StandardError
        return false
      end

      # The level now, as the game reads it: 0 Easy, 1 Normal, 2 Hard
      def level
        return 2 if switch?(:SWITCH_GAME_DIFFICULTY_HARD)
        return 0 if switch?(:SWITCH_GAME_DIFFICULTY_EASY)
        return 1
      end

      def lowest
        value = ($Trainer.lowest_difficulty rescue nil)
        return value.nil? ? level : value.to_i
      end

      # Shown As: the lowest this save has used
      def shown
        return [[lowest, level].min, 0].max
      end

      def shown_name(index = shown)
        return _INTL(NAMES[index.to_i] || NAMES[1])
      end

      def tone(index = shown)
        return TONES[index.to_i] || :blue
      end

      def hard_run?
        return ready? && shown == 2
      end

      # Each change a level makes, for the settings and New Game Setup
      def changes(index)
        list = CHANGES[index.to_i] || []
        return list.empty? ? [_INTL("The game as it's made: Levels like the official games.")] : list.map { |c| _INTL(c) }
      end

      def data
        return Reloaded::SaveStore.section(SECTION)
      end

      #------------------------------------------------------------------------
      # Debug: a Run Tag of its own
      #------------------------------------------------------------------------
      def debug?
        return true if switch?(:ENABLED_DEBUG_MODE_AT_LEAST_ONCE)
        return true if $DEBUG
        ps = $PokemonSystem
        return true if ps && ps.respond_to?(:debug) && (ps.debug rescue 0).to_i == 1
        return true if defined?(Reloaded::QualityOfLife) && Reloaded::QualityOfLife.used.has_key?("debug")
        return true if Reloaded::SaveStore.played_without?
        return true if Reloaded::SaveStore.test_copy
        return false
      rescue StandardError
        return false
      end

      # Debug found: PIF's own switch on, so its screens say it too
      def mark_debug!
        return unless ready? && debug? && !switch?(:ENABLED_DEBUG_MODE_AT_LEAST_ONCE)
        $game_switches[switch_id(:ENABLED_DEBUG_MODE_AT_LEAST_ONCE)] = true
        Reloaded::Log.info("Debug found on this save: PIF's debug switch is on now", :difficulty)
      end

      #------------------------------------------------------------------------
      # Changes
      #------------------------------------------------------------------------
      # Loaded or saving: a level the switches say that setDifficulty never
      # saw (an event, another mod), and Debug
      def loaded!
        return unless ready?
        sync_lowest(:switches)
        mark_debug!
      end

      def sync_lowest(source)
        lv = level
        low = ($Trainer.lowest_difficulty rescue nil)
        return unless low.nil? || lv < low.to_i
        before = low.nil? ? nil : [low.to_i, lv].max
        $Trainer.lowest_difficulty = lv if $Trainer.respond_to?(:lowest_difficulty=)
        return if low.nil?                     # an old save: nothing was lowered
        note(before, lv, source)
        Reloaded::Events.emit(:difficulty_lowered, :from => low.to_i, :to => lv)
      end

      # After setDifficulty: the lowest at once, the history, the events
      def changed(from)
        return unless ready?
        to = level
        return if from == to
        shown_before = [($Trainer.lowest_difficulty rescue nil) || from, from].min
        $Trainer.lowest_difficulty = to if $Trainer.respond_to?(:lowest_difficulty=) && to < lowest_raw(from)
        note(from, to, :set)
        Reloaded::Events.emit(:difficulty_changed, :from => from, :to => to)
        Reloaded::Events.emit(:difficulty_lowered, :from => shown_before, :to => to) if to < shown_before
      end

      def lowest_raw(fallback)
        value = ($Trainer.lowest_difficulty rescue nil)
        return value.nil? ? fallback : value.to_i
      end

      # A short history for Bug Reports: [{ "from", "to", "at", "how" }]
      def note(from, to, how)
        d = data
        return unless d
        list = (d["history"] ||= [])
        list << { "from" => from, "to" => to, "at" => Time.now, "how" => how.to_s }
        list.shift while list.length > HISTORY
      end

      def history
        d = data
        return d ? Array(d["history"]) : []
      end

      # For a bug report: the level now, the lowest, Shown As, Debug, saves
      # made without Kanto Reloaded, and the last changes
      def report_lines
        return [] unless ready? && data
        out = ["- Difficulty: #{NAMES[level]} now, lowest #{NAMES[lowest] || "?"}, Shown As #{NAMES[shown]}#{debug? ? ", Debug" : ""}"]
        gaps = Reloaded::SaveStore.gaps
        out << "- Saved without Kanto Reloaded: #{gaps.map { |g| "#{g["saves"]} time(s) since #{g["since"]}" }.join("; ")}" unless gaps.empty?
        copy = Reloaded::SaveStore.test_copy
        out << "- A test copy of #{copy["of"]}, made #{copy["at"]}" if copy
        last = history.last(5)
        out << "- Difficulty changes: #{last.map { |h| "#{NAMES[h["from"].to_i]} to #{NAMES[h["to"].to_i]} (#{h["how"]}, #{h["at"]})" }.join("; ")}" unless last.empty?
        return out
      rescue StandardError
        return []
      end

      #------------------------------------------------------------------------
      # Hard's trainer IVs: at least 10, on top of PIF's own
      #------------------------------------------------------------------------
      def floor_ivs(trainer)
        return unless ready? && level == 2 && trainer.respond_to?(:party)
        Array(trainer.party).each do |pk|
          next unless pk && pk.respond_to?(:iv) && pk.iv.is_a?(Hash)
          low = pk.iv.keys.select { |s| pk.iv[s].to_i < IV_FLOOR }
          next if low.empty?
          low.each { |s| pk.iv[s] = IV_FLOOR }
          pk.calc_stats if pk.respond_to?(:calc_stats)
        end
      end

      #------------------------------------------------------------------------
      # Hooks (core: Difficulty is always on)
      #------------------------------------------------------------------------
      def install
        h = Reloaded::Hooks
        h.needs(:kif_setting, "Difficulty", :id => :difficulty_kif_row)
        # (PIF's GameDifficulty.rb: always there in the game)
        if game_method?(:setDifficulty)
          h.around(nil, Object, :setDifficulty, :id => :difficulty_set) do |original, *args|
            from = Reloaded::Difficulty.ready? ? Reloaded::Difficulty.level : nil
            result = original.call(*args)
            Reloaded::Difficulty.changed(from) unless from.nil?
            result
          end
        end
        # the Hall of Fame (and anything else asking): Shown As
        if game_method?(:getDisplayDifficulty)
          h.around(nil, Object, :getDisplayDifficulty, :id => :difficulty_display) do |original, *args|
            next original.call(*args) unless Reloaded::Difficulty.ready?
            Reloaded::Difficulty.shown_name
          end
        end
        if defined?(::GameData::Trainer)
          h.around(nil, ::GameData::Trainer, :to_trainer, :id => :difficulty_trainer_ivs) do |original, *args|
            trainer = original.call(*args)
            Reloaded::Difficulty.floor_ivs(trainer)
            trainer
          end
        end
        # PIF's Difficulty row in KIF Settings (Game > Difficulty): this one
        # takes its place, as Speech Frame does in Graphics > Text
        if defined?(::KIF::SettingsScreen) && ::KIF::SettingsScreen.respond_to?(:pif_items)
          h.around(nil, ::KIF::SettingsScreen.singleton_class, :pif_items, :id => :difficulty_pif_row) do |original, *args|
            items, extra, root = original.call(*args)
            [items.reject { |it| it[:name] == "Difficulty" }, extra, root]
          end
        end
      end

      #------------------------------------------------------------------------
      # Settings: Difficulty and Shown As (his pick: Rows and Dropdown)
      #------------------------------------------------------------------------
      def register_settings
        s = Reloaded::Settings
        s.register_page(PAGE, :group => :general, :name => "Difficulty", :icon => :features, :priority => 42,
          :description => "How hard the game is, and the lowest this save has used.")
        s.register(KEY, :page => PAGE, :priority => 10, :type => :enum, :scope => :save, :preset => false,
          :name => "Difficulty", :values => NAMES, :default => 1, :no_default => true, :tones => TONES,
          :bind => Reloaded::Settings::Bind.direct(proc { Reloaded::Difficulty.level },
                                                    proc { |v| Reloaded::Difficulty.set_level(v) }),
          :confirm => proc { |v, _old| Reloaded::Difficulty.confirm_lower(v) },
          :descriptions => NAMES.each_index.map { |i| changes(i).map { |c| c.end_with?(".") ? c : c + "." }.join(" ") },
          :description => "Pick any level, any time. Wherever your difficulty shows (Load Screen, Hall of Fame, Trainer Card), it's the lowest this save has used.")
        s.register(SHOWN_KEY, :page => PAGE, :priority => 20, :type => :enum, :scope => :save, :preset => false,
          :name => "Shown As", :values => NAMES, :default => 1, :no_default => true, :read_only => true, :tones => TONES,
          :pill => true, :tags => proc { Reloaded::Difficulty.debug? ? [["DEBUG", DEBUG_COLOUR]] : [] },
          :bind => Reloaded::Settings::Bind.direct(proc { Reloaded::Difficulty.shown }, proc { |_v| nil }),
          :description => "The lowest difficulty this save has used, as the Load Screen, Hall of Fame and Trainer Card show it. " \
                          "DEBUG: Debug tools, saved without Kanto Reloaded, or a test copy.")
      end

      def game_method?(name)
        return Object.private_method_defined?(name) || Object.method_defined?(name)
      end

      def set_level(index)
        return false unless ready? && game_method?(:setDifficulty)
        setDifficulty(index.to_i.clamp(0, 2))
        return true
      end

      #------------------------------------------------------------------------
      # A save file that isn't loaded (the Load Screen, the Save Manager)
      #------------------------------------------------------------------------
      # Shown As from its player and its switches (sw: id -> on?)
      def shown_in(player, sw)
        lv = sw.call(switch_id(:SWITCH_GAME_DIFFICULTY_HARD)) ? 2 : (sw.call(switch_id(:SWITCH_GAME_DIFFICULTY_EASY)) ? 0 : 1)
        low = (player.lowest_difficulty rescue nil)
        return low.nil? ? lv : [low.to_i, lv].min
      end

      def debug_in(data, sw)
        return true if sw.call(switch_id(:ENABLED_DEBUG_MODE_AT_LEAST_ONCE))
        ps = data[:pokemon_system]
        return true if ps.respond_to?(:debug) && (ps.debug rescue 0).to_i == 1
        kr = Reloaded::SaveStore.value_in(data)
        return false unless kr.is_a?(Hash)
        return true unless Array(kr["gaps"]).empty?
        return true if kr[Reloaded::SaveStore::TEST_COPY]
        used = ((kr["sections"] || {})["quality_of_life"] || {})["used"]
        return used.is_a?(Hash) && used.has_key?("debug")
      rescue StandardError
        return false
      end

      # Asks first only when the change would lower Shown As (his pick)
      def confirm_lower(index)
        return true unless ready? && index.to_i < shown
        return Reloaded::DifficultyAsk.lower(index.to_i) if defined?(Reloaded::DifficultyAsk)
        return defined?(pbConfirmMessage) ? pbConfirmMessage(_INTL("Lower to {1}? Your card will show {1} from now on.", shown_name(index))) : true
      end
    end
  end
end
