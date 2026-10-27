# encoding: utf-8
#==============================================================================
# Kanto Reloaded: IV Boundaries
#==============================================================================
# How strong new Pokémon can be (Roadmap topic iv-boundaries, his picks
# 2026-10-25). A feature with a switch, On; every save starts at Vanilla
# (0-31), so nothing changes until a range is picked.
#
#   The ranges   a floor and a ceiling for each source, this save's: Wild
#                (fought or caught, statics, roamers, event battles), Eggs
#                (gift Eggs, the Day Care, Kuray Eggs) and Gifts (an event's
#                hand-overs, starters, in-game trades, Wonder Trade).
#                Presets set all three: Vanilla 0-31, Accessibility 15-31,
#                Strong 20-31, Perfect-ish 25-31, Perfect 31-31, Challenge
#                0-15; any range moved makes it Custom, and Custom keeps
#                your own ranges
#   The rule     an IV inside the range stays, one outside is rolled evenly
#                inside it (HR's), then the stats are worked out again
#   New          only Pokémon made for you right then: rolled now, or made
#                in the same event script that hands them over (Sources.rb).
#                Never one you had: the Day Care's, unfused halves, Eusine's
#                give-back, Mystery Gifts, imports
#   Hard         floors stay at 0 (a ceiling still works)
#   Max IVs Mode KIF's, locked Off while this is On (MaxIVs.rb); a save that
#                has it On keeps it
#   Fusing       By Splicer (PIF's: DNA averages, Super takes the best),
#                Always Average or Always Best of Both; cody's Fusion Screen
#                preview follows (Fusion.rb)
#   Trainers     Difficulty's, shown read only
#   On top       IV items and bonuses come after (the Perfect Ball's 31s,
#                alphas', Wild Link's later): a catch isn't a hand-over
#
#   Reloaded::IVBoundaries.range(source)            [floor, ceiling] a new one rolls in
#   Reloaded::IVBoundaries.bound(pkmn, source)      the rule, on one Pokémon
#   Reloaded::IVBoundaries.roll(source)             six IVs inside the range
#   Reloaded::IVBoundaries.force_next(source, [lo, hi], count)
#   Reloaded::IVBoundaries.exempt_next(source)      the next one keeps its own
#   Reloaded::IVBoundaries.boost(source, [lo, hi], minutes)   counted in play time
#   Events: :before_bound, :after_bound (:pokemon, :source, :range)
#==============================================================================

module Reloaded
  module IVBoundaries
    FEATURE = :iv_boundaries
    PAGE = :iv_boundaries
    FUSE_PAGE = :iv_boundaries_fusing
    SECTION = :iv_boundaries              # this save's own: Custom ranges, the API's queue and boosts
    SOURCES = [:wild, :egg, :gift].freeze
    SOURCE_NAMES = { :wild => "Wild", :egg => "Eggs", :gift => "Gifts" }.freeze
    STATS = [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED].freeze
    IV_MAX = 31
    PRESETS = [["Vanilla", 0, 31], ["Accessibility", 15, 31], ["Strong", 20, 31], ["Perfect-ish", 25, 31],
               ["Perfect", 31, 31], ["Challenge", 0, 15]].freeze
    CUSTOM = PRESETS.length                # the last chip: your own ranges
    PRESET_NAMES = (PRESETS.map(&:first) + ["Custom"]).freeze
    FUSION = ["By Splicer", "Average", "Best of Both"].freeze
    HARD_LOCK = "Hard Keeps Floors at 0"

    class << self
      # Pokémon made while a source's call (or an event script) runs
      attr_reader :collect

      # Kanto Reloaded boots before the game loads its data: nothing here
      # reads GameData
      def boot
        register_settings
        Reloaded::Features.register(FEATURE, :name => "IV Boundaries", :page => PAGE, :order => 61,
          :description => "How strong new Pokémon can be: The lowest and highest IVs for wild Pokémon, Eggs and gifts.")
        [:Sources, :Fusion, :MaxIVs].each do |part|
          begin
            const_get(part).install if const_defined?(part, false)
          rescue StandardError => e
            Reloaded::Log.exception("IV Boundaries' #{part} couldn't start", e, FEATURE)
          end
        end
        register_new_game_row
        return true
      end

      def on?
        return Reloaded::Features.on?(FEATURE)
      end

      def key(id)
        return :"iv_boundaries.#{id}"
      end

      def setting(id)
        return Reloaded::Settings.get(key(id))
      end

      def rng
        @rng ||= Random.new
      end

      # For tests: a generator of their own
      def rng=(r)
        @rng = r
      end

      def hard?
        d = defined?(Reloaded::Difficulty) ? Reloaded::Difficulty : nil
        return d && d.respond_to?(:ready?) && d.ready? && d.level == 2 ? true : false
      rescue StandardError
        return false
      end

      #------------------------------------------------------------------------
      # The ranges
      #------------------------------------------------------------------------
      # This save's range for a source, as set
      def stored(src)
        return [setting(:"#{src}_floor").to_i, setting(:"#{src}_ceiling").to_i]
      end

      # As shown and as the player's Pokémon roll it: Hard keeps the floor at 0
      def shown(src)
        lo, hi = stored(src)
        return [hard? ? 0 : lo, hi]
      end

      # What a new Pokémon of this source rolls in now: a mod's boost, else
      # this save's
      def range(src)
        src = src.to_sym
        return boost_for(src) || shown(src)
      end

      def vanilla?(src)
        return range(src) == [0, IV_MAX]
      end

      # The preset all three ranges match now, else Custom
      def preset_index
        all = SOURCES.map { |src| shown(src) }.uniq
        return CUSTOM unless all.length == 1
        return PRESETS.index { |_n, lo, hi| [lo, hi] == all[0] } || CUSTOM
      end

      # The presets with a floor: not on Hard
      def helpful?(i)
        p = PRESETS[i.to_i]
        return p && p[1] > 0 ? true : false
      end

      def locked_presets
        return {} unless hard?
        return PRESETS.each_index.select { |i| helpful?(i) }.map { |i| [i, _INTL(HARD_LOCK)] }.to_h
      end

      # A preset over your own ranges asks first (his pick, Q10)
      def confirm_preset(v, old)
        return true unless old.to_i == CUSTOM && v.to_i != CUSTOM
        return true unless defined?(Reloaded::IVBoundariesScreen)
        return Reloaded::IVBoundariesScreen.replace_ask(v.to_i)
      end

      # A preset sets all three (his pick, Q10); Custom brings your own back.
      # Your own are kept first when a preset replaces them
      def use_preset(i)
        i = i.to_i
        if i == CUSTOM
          mine = custom_ranges
          SOURCES.each { |src| set_range(src, *mine[src]) if mine[src] }
          return true
        end
        p = PRESETS[i]
        return false unless p
        remember_custom if preset_index == CUSTOM
        SOURCES.each { |src| set_range(src, p[1], p[2]) }
        return true
      end

      def set_range(src, lo, hi)
        lo, hi = [lo.to_i.clamp(0, IV_MAX), hi.to_i.clamp(0, IV_MAX)].minmax
        s = Reloaded::Settings
        s.set(key(:"#{src}_ceiling"), IV_MAX, true) if lo > stored(src)[1]      # never floor above ceiling on the way
        s.set(key(:"#{src}_floor"), lo, true)
        s.set(key(:"#{src}_ceiling"), hi, true)
      end

      # One end moved past the other: the other follows
      def keep_order(src, which, value)
        lo, hi = stored(src)
        return unless lo > hi
        if which == :floor
          Reloaded::Settings.set(key(:"#{src}_ceiling"), value, true)
        else
          Reloaded::Settings.set(key(:"#{src}_floor"), value, true)
        end
      end

      # This save's own data (nil at the title screen)
      def data
        return defined?(Reloaded::SaveStore) ? Reloaded::SaveStore.section(SECTION) : nil
      end

      def custom_ranges
        mine = (data || {})["custom"]
        return {} unless mine.is_a?(Hash)
        return SOURCES.map { |src| [src, mine[src.to_s]] }.select { |_s, r| r.is_a?(Array) && r.length == 2 }.to_h
      end

      def remember_custom
        d = data
        return unless d
        d["custom"] = SOURCES.map { |src| [src.to_s, stored(src)] }.to_h
      end

      #------------------------------------------------------------------------
      # The rule
      #------------------------------------------------------------------------
      # Each IV inside the range stays; one outside is rolled evenly inside
      # it. True when an IV changed (its stats worked out again)
      def bound(pkmn, src, rule = nil)
        return false unless pkmn && pkmn.respond_to?(:iv) && pkmn.iv.is_a?(Hash)
        src = src.to_sym
        queued = take_queued(src)
        return false if queued == :exempt
        lo, hi = queued || rule || range(src)
        return false if lo <= 0 && hi >= IV_MAX
        Reloaded::Events.emit(:before_bound, :pokemon => pkmn, :source => src, :range => [lo, hi])
        changed = false
        STATS.each do |s|
          v = pkmn.iv[s].to_i
          next if v >= lo && v <= hi
          pkmn.iv[s] = lo + rng.rand(hi - lo + 1)
          changed = true
        end
        pkmn.calc_stats if changed && pkmn.respond_to?(:calc_stats)
        Reloaded::Events.emit(:after_bound, :pokemon => pkmn, :source => src, :range => [lo, hi])
        return changed
      end

      # Six IVs inside a source's range (for a mod making its own Pokémon)
      def roll(src)
        lo, hi = range(src)
        return STATS.map { |s| [s, lo + rng.rand(hi - lo + 1)] }.to_h
      end

      #------------------------------------------------------------------------
      # Which Pokémon are new: made while a collector is open
      #------------------------------------------------------------------------
      def collecting
        outer = @collect
        mine = {}.compare_by_identity
        @collect = mine
        yield
        return mine
      ensure
        outer.merge!(mine) if outer && mine
        @collect = outer
      end

      def made(pkmn)
        @collect[pkmn] = true if @collect
      end

      def new?(pkmn)
        return @collect && @collect[pkmn] ? true : false
      end

      #------------------------------------------------------------------------
      # The API's queue and boosts (this save's)
      #------------------------------------------------------------------------
      # The next count Pokémon of a source roll in [lo, hi]
      def force_next(src, rule, count = 1)
        d = data
        return false unless d && rule.is_a?(Array) && rule.length == 2
        lo, hi = rule.map { |v| v.to_i.clamp(0, IV_MAX) }.minmax
        q = ((d["queue"] ||= {})[src.to_s] ||= [])
        count.to_i.times { q << [lo, hi] }
        return true
      end

      # The next Pokémon of a source keeps the IVs it was made with
      def exempt_next(src)
        d = data
        return false unless d
        ((d["queue"] ||= {})[src.to_s] ||= []) << "exempt"
        return true
      end

      def take_queued(src)
        d = data
        q = d && d["queue"] && d["queue"][src.to_s]
        return nil unless q && !q.empty?
        entry = q.shift
        return entry == "exempt" ? :exempt : entry
      end

      # A source rolls in [lo, hi] for a while, counted in play time (his
      # pick, Q22: it can't be skipped by the PC's clock)
      def boost(src, rule, minutes)
        d = data
        return false unless d && rule.is_a?(Array) && rule.length == 2
        lo, hi = rule.map { |v| v.to_i.clamp(0, IV_MAX) }.minmax
        (d["boosts"] ||= {})[src.to_s] = [lo, hi, play_seconds + minutes.to_f * 60]
        return true
      end

      def boost_for(src)
        d = data
        b = d && d["boosts"] && d["boosts"][src.to_s]
        return nil unless b
        return b[0, 2] if play_seconds < b[2].to_f
        d["boosts"].delete(src.to_s)
        return nil
      end

      def play_seconds
        return Graphics.frame_count / [Graphics.frame_rate.to_f, 1.0].max
      rescue StandardError
        return 0
      end

      def fusion
        return setting(:fusion).to_i
      end

      #------------------------------------------------------------------------
      # Settings (his picks: Range Sliders, this save's; the switch global)
      #------------------------------------------------------------------------
      def register_settings
        s = Reloaded::Settings
        bind = s::Bind
        me = Reloaded::IVBoundaries
        floor_lock = proc { me.hard? ? _INTL(HARD_LOCK) : nil }
        s.register_page(PAGE, :group => :general, :name => "IV Boundaries", :icon => :features, :priority => 48,
          :feature => FEATURE, :description => "How strong new Pokémon can be.")
        s.register_page(FUSE_PAGE, :group => :general, :name => "IV Boundaries - Fusing", :icon => :features, :priority => 48.5,
          :feature => FEATURE, :description => "How fusing combines two Pokémon's IVs.")
        s.register(key(:preset), :page => PAGE, :priority => 10, :type => :enum, :values => PRESET_NAMES, :default => 0,
          :scope => :save, :preset => false, :name => "Preset", :chip_pick => true,
          :bind => bind.direct(proc { me.preset_index }, proc { |v| me.use_preset(v) }),
          :locked_choices => proc { me.locked_presets },
          :locked_text => "On Hard, new Pokémon can't start stronger than usual. A lower ceiling is fine. "                           "Lower the difficulty to Normal to raise a floor.",
          :confirm => proc { |v, old| me.confirm_preset(v, old) },
          :descriptions => ["As the game makes them: Any IV from 0 to 31.",
                            "Never weak: Every IV from 15 to 31.",
                            "Strong from the start: Every IV from 20 to 31.",
                            "Close to perfect: Every IV from 25 to 31.",
                            "Every new IV is 31.",
                            "A harder run: Every IV from 0 to 15.",
                            "Your own ranges, set below."],
          :description => "Sets all three ranges at once. Moving any range makes it Custom.")
        texts = { :wild => "Wild Pokémon, fought or caught: Statics, roamers and event battles too.",
                  :egg  => "New Eggs: Gift Eggs, the Day Care's and Kuray Eggs. Inherited IVs inside the range stay.",
                  :gift => "Pokémon an event gives you: Starters, gifts and in-game trades, Wonder Trade too." }
        SOURCES.each_with_index do |src, i|
          name = SOURCE_NAMES[src]
          s.register(key(:"#{src}_floor"), :page => PAGE, :priority => 20 + i * 2, :type => :slider, :min => 0, :max => IV_MAX,
            :default => 0, :scope => :save, :name => "#{name} Floor", :range => [src, :floor, name], :lock => floor_lock,
            :range_shown => proc { |g| me.shown(g) },
            :range_popup => proc { |screen, _o| defined?(Reloaded::IVBoundariesScreen) ? Reloaded::IVBoundariesScreen.spinners(screen, src) : nil },
            :apply => proc { |v, restoring| me.keep_order(src, :floor, v) unless restoring },
            :description => "The lowest IV. " + texts[src])
          s.register(key(:"#{src}_ceiling"), :page => PAGE, :priority => 21 + i * 2, :type => :slider, :min => 0, :max => IV_MAX,
            :default => IV_MAX, :scope => :save, :name => "#{name} Ceiling", :range => [src, :ceiling, name],
            :apply => proc { |v, restoring| me.keep_order(src, :ceiling, v) unless restoring },
            :description => "The highest IV. " + texts[src])
        end
        s.register(key(:trainers), :page => PAGE, :priority => 40, :type => :enum, :values => ["Half Their Level", "At Least 10"],
          :default => 0, :scope => :save, :preset => false, :no_default => true, :read_only => true, :name => "Trainers",
          :lock => proc { _INTL("Set by Difficulty") },
          :bind => bind.direct(proc { me.hard? ? 1 : 0 }, proc { |_v| }),
          :description => "Trainers' IVs follow the difficulty. Normal: Half the trainer's level, up to 31. Hard: At least 10. " \
                          "IVs a trainer's data sets stay as they are.")
        s.register(key(:fusion), :page => FUSE_PAGE, :priority => 10, :type => :enum, :values => FUSION, :default => 0,
          :scope => :save, :name => "Fusion IVs",
          :descriptions => ["PIF's own rule: DNA Splicers average the two IVs, Super Splicers keep the higher of each.",
                            "Every fusion averages the two IVs of each stat, rounded down.",
                            "Every fusion keeps the higher IV of each stat."],
          :description => "How a fusion's IVs come from its two Pokémon. The Fusion Screen's preview follows it.")
      end

      # New Game Setup's Run Setup row (its hand-off): a preset, set at Start
      def register_new_game_row
        ng = defined?(Reloaded::NewGameSetup) ? Reloaded::NewGameSetup : nil
        return unless ng && ng.respond_to?(:register_row)
        me = Reloaded::IVBoundaries
        ng.register_row(:iv_boundaries, :name => "IV Boundaries", :priority => 30, :kind => :choice,
          :values => PRESETS.map(&:first), :default => 0,
          :visible => proc { |_p| me.on? },
          :apply => proc { |v, _p| me.use_preset(v.to_i) },
          :card => proc { |v, _p| v.to_i == 0 ? nil : [_INTL("IVs"), "#{_INTL(PRESETS[v.to_i][0])} (#{PRESETS[v.to_i][1]}-#{PRESETS[v.to_i][2]})"] },
          :descriptions => ["As the game makes them: Any IV from 0 to 31.",
                            "Never weak: Every IV from 15 to 31.",
                            "Strong from the start: Every IV from 20 to 31.",
                            "Close to perfect: Every IV from 25 to 31.",
                            "Every new IV is 31.",
                            "A harder run: Every IV from 0 to 15."],
          :description => "How strong new Pokémon can be. On Hard, floors stay at 0.")
      end
    end
  end
end
