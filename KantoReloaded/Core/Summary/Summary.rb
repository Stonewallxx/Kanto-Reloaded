# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Reloaded Summary
#==============================================================================
# Roadmap topic summary-icons, Wave 8 (his picks, 2026-11-16): the Reloaded
# Summary pages on the plate frame (the Skills page Design 1, Rebuilt, and
# every other page Built as Drawn), the tab named STATS. On every page the
# left column (the Pokémon's plate in its first type's colour: its name,
# level, types, picture and Additional), and on the right:
#
#   INFO       Info (Dex No. or the fusion's two, Species, OT, ID No., Item),
#              Exp. with its bar, Memo (nature, where and when met, its
#              characteristic); the ability's text along the bottom
#   STATS      the stats with IV, EV and BASE, the nature's up red and down
#              blue; Ability and Weakness (ability-aware); the ability's text
#   ABILITIES  with KIF: Elite Redux's Innates On: its ability and innates,
#              A changes them (KIF-ER's own code)
#   MOVES      the four with type and PP, the picked one's details (Hidden
#              Power's real type); A picks one and A on another swaps them
#   POKÉDEX    opens the Pokémon's Pokédex entry, as PIF's does
#
# Learning a move (and choosing one) shows the Moves page with the new one
# fifth. An Egg has its own page. Other mods on the pages: Alpha Encounters'
# ALPHA badge, Ghostly Possession's possessed Pokémon, KIF: Elite Redux's page,
# Double Abilities' two abilities (Action: the Abilities Card), KIF's EV
# points (A spends them on STATS), Evolution Lock, gender and Soul Link.
# Another trainer's Pokémon (Hoenn Essentials' rematches, Wandering
# Trainers, a co-op partner's) is view-only.
#
# Only the screen's visuals are replaced: Kanto Reloaded's scene is a
# subclass of the game's PokemonSummary_Scene (UI/SummaryScene.rb), made
# whenever the game makes one while Reloaded Summary is On (Reloaded
# Systems). The game's start is replaced at its innermost method, so a mod
# that wraps it (Megas' party sync, KIF-ER's tab switch) still runs around
# ours; its Options (give an item, a hat, the Pokédex, Mark) are the game's,
# shown in Kanto Reloaded's popups. In the Hoenn contest lobby the game's
# own (its contest pages). Off: PIF's Summary with KIF's IVs & EVs.
#
# Sounds (his picks, 2026-11-16): a page PIF's page sound, another Pokémon
# its cry (as PIF), two moves swapped PIF's party switch sound.
#==============================================================================

module Reloaded
  module Summary
    FEATURE = :reloaded_summary
    TOGGLE = :"systems.summary"
    STATS = [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED].freeze
    STAT_NAMES = ["HP", "Attack", "Defense", "Sp. Atk", "Sp. Def", "Speed"].freeze
    # Abilities that change what hits it: none of a type, half, double
    IMMUNE = { :LEVITATE => :GROUND }.freeze
    HALF = { :THICKFAT => [:FIRE, :ICE], :HEATPROOF => [:FIRE], :WATERBUBBLE => [:FIRE], :PURIFYINGSALT => [:GHOST] }.freeze
    DOUBLE = { :FLUFFY => [:FIRE] }.freeze
    # PIF's characteristics (006_UI_Summary.rb:654-685): by the best IV
    CHARACTERISTICS = {
      :HP => ["Loves to eat.", "Takes plenty of siestas.", "Nods off a lot.", "Scatters things often.", "Likes to relax."],
      :ATTACK => ["Proud of its power.", "Likes to thrash about.", "A little quick tempered.", "Likes to fight.", "Quick tempered."],
      :DEFENSE => ["Sturdy body.", "Capable of taking hits.", "Highly persistent.", "Good endurance.", "Good perseverance."],
      :SPECIAL_ATTACK => ["Highly curious.", "Mischievous.", "Thoroughly cunning.", "Often lost in thought.", "Very finicky."],
      :SPECIAL_DEFENSE => ["Strong willed.", "Somewhat vain.", "Strongly defiant.", "Hates to lose.", "Somewhat stubborn."],
      :SPEED => ["Likes to run.", "Alert to sounds.", "Impetuous and silly.", "Somewhat of a clown.", "Quick to flee."]
    }.freeze
    MONTHS = %w[Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec].freeze
    # PIF's Egg stages, by steps left (as PIF's Summary words them)
    EGG_WORDS = [[1275, "Sounds can be heard coming from inside!", "It will hatch soon!"],
                 [2550, "It appears to move occasionally.", "It may be close to hatching."],
                 [10200, "What will hatch from this?", "It doesn't seem close to hatching."],
                 [nil, "It's very still.", "It will take a long time to hatch."]].freeze

    class << self
      # Set once Kanto Reloaded's Summary has failed: the game's for the rest
      # of the session
      attr_accessor :failed

      def boot
        register_settings
        if defined?(Reloaded::Features)
          Reloaded::Features.register(FEATURE, :name => "Reloaded Summary", :core => true, :order => 33,
            :takes_over_while => { "F-UI-04_SummaryIVEV" => proc { Reloaded::Summary.enabled? } },
            :description => "Kanto Reloaded's Summary pages.")
        end
        install
        return true
      end

      def register_settings
        Reloaded::Settings.register(TOGGLE, :page => :systems, :priority => 33, :type => :toggle, :default => true, :preset => false,
          :name => "Reloaded Summary",
          :description => "Kanto Reloaded's Summary: Info, Stats and Moves on its plates, in battle too. Off shows the game's own, " \
                          "with KIF's IVs and EVs.")
        Reloaded::Settings.on_change(TOGGLE, :summary) do
          Reloaded::Features.resync if defined?(Reloaded::Features) && Reloaded::Features.respond_to?(:resync)
        end
      end

      def enabled?
        return Reloaded::Settings.get(TOGGLE) ? true : false
      rescue StandardError
        return false
      end

      # On, and its screen can draw (not in the Hoenn contest lobby: the
      # game's own there, with its contest pages)
      def active?
        return false unless enabled? && !@failed && Reloaded::Pixel.available? && defined?(Reloaded::SummaryScene)
        return !contest_lobby?
      end

      def contest_lobby?
        return false unless defined?(::ContestSettings) && ::ContestSettings.const_defined?(:DEFAULT_LOBBY_MAP_ID)
        return $game_map && $game_map.map_id == ::ContestSettings::DEFAULT_LOBBY_MAP_ID ? true : false
      rescue StandardError
        return false
      end

      def install
        return true if @installed || !defined?(::PokemonSummary_Scene)
        @installed = true
        Reloaded::Hooks.prepend(nil, ::PokemonSummary_Scene.singleton_class, SceneChoice, :id => :summary_scene)
        return true
      end

      # Kanto Reloaded's scene class: a subclass of the game's, made the
      # first time it's needed (every mod's changes to the game's class are in
      # by then). The game's start, forget start and end are replaced at their
      # innermost method (a mod that aliased them left PIF's under the alias):
      # what wraps them still runs around ours.
      def scene_class
        return @scene_class if @scene_class
        base = ::PokemonSummary_Scene
        k = Class.new(base) { include Reloaded::SummaryScene }
        { :pbStartScene => :kr_start_scene, :pbStartForgetScene => :kr_start_forget, :pbEndScene => :kr_end_scene }.each do |name, ours|
          next unless base.method_defined?(name) || base.private_method_defined?(name)
          inner = innermost(base, name)
          k.send(:define_method, inner) do |*args, &blk|
            @kr_vanilla ? super(*args, &blk) : send(ours, *args, &blk)
          end
        end
        # what watches the game's Summary (Recent Steps, the Timing Profiler)
        # watches ours too
        Reloaded::Hooks.scene_class(base, k)
        return @scene_class = k
      end

      def innermost(klass, name)
        names = klass.instance_methods + klass.private_instance_methods
        pif = names.select do |n|
          m = klass.instance_method(n)
          m.original_name == name && m.source_location && m.source_location[0].to_s =~ /006_UI_Summary/
        end
        return name if pif.empty? || pif.include?(name)
        return pif.first
      rescue StandardError
        return name
      end

      #------------------------------------------------------------------------
      # Whose Pokémon
      #------------------------------------------------------------------------
      # The player's own: the game says so (is_player), and the party is the
      # player's (theirs, a box, the battle's with theirs in it). Hoenn
      # Essentials' rematches and Wandering Trainers show copies of another
      # trainer's team as the player's: view-only, as PIF's other teams are.
      def own?(party, is_player)
        return false unless is_player
        return true if defined?(::PokemonBox) && party.is_a?(::PokemonBox)
        mine = $Trainer && $Trainer.respond_to?(:party) ? $Trainer.party : nil
        return true if mine.nil? || party.equal?(mine)
        list = party.respond_to?(:compact) ? party.compact : []
        return true if list.empty?
        return list.any? { |p| mine.any? { |q| q.equal?(p) } || stored?(p) }
      rescue StandardError
        return true
      end

      def stored?(pkmn)
        st = $PokemonStorage
        return false unless st && st.respond_to?(:maxBoxes)
        st.maxBoxes.times do |b|
          box = st[b] rescue nil
          next unless box
          (box.respond_to?(:length) ? box.length : 30).times { |i| return true if (box[i] rescue nil).equal?(pkmn) }
        end
        return false
      rescue StandardError
        return false
      end

      #------------------------------------------------------------------------
      # Stats
      #------------------------------------------------------------------------
      # [[stat, name, value, iv, ev, base]], as KIF's Skills page has them
      # (No EVs mode: 0 EVs; Max IVs mode: 31 IVs; KIF's effective base
      # stats)
      def stats(pk)
        no_evs = $PokemonSystem && $PokemonSystem.respond_to?(:noevsmode) && $PokemonSystem.noevsmode.to_i > 0
        max_ivs = $PokemonSystem && $PokemonSystem.respond_to?(:maxivsmode) && $PokemonSystem.maxivsmode.to_i > 0
        base = pk.respond_to?(:kif_effective_base_stats) ? pk.kif_effective_base_stats : pk.baseStats
        values = [pk.totalhp, pk.attack, pk.defense, pk.spatk, pk.spdef, pk.speed]
        limit = defined?(::Pokemon::IV_STAT_LIMIT) ? ::Pokemon::IV_STAT_LIMIT : 31
        return STATS.each_with_index.map do |s, i|
          [s, _INTL(STAT_NAMES[i]), values[i].to_i, max_ivs ? limit : pk.iv[s].to_i, no_evs ? 0 : pk.ev[s].to_i, base[s].to_i]
        end
      end

      # The nature's raised and lowered stat ([up, down], nil each), not while
      # a Shadow Pokémon hides its nature
      def nature_marks(pk)
        return [nil, nil] unless nature_shown?(pk)
        up = down = nil
        (pk.nature_for_stats.stat_changes rescue []).each do |s, change|
          up = s if change > 0
          down = s if change < 0
        end
        return [up, down]
      end

      def nature_shown?(pk)
        return !(pk.respond_to?(:shadowPokemon?) && pk.shadowPokemon? && pk.heartStage <= 3)
      rescue StandardError
        return true
      end

      def nature_name(pk)
        return nature_shown?(pk) ? (pk.nature.name rescue "") : "???"
      end

      # "+Sp. Atk, -Attack", or no changes
      def nature_words(pk)
        up, down = nature_marks(pk)
        return "" unless nature_shown?(pk)
        return _INTL("No Stat Changes") unless up || down
        return _INTL("+{1}, -{2}", stat_name(up), stat_name(down))
      end

      def stat_name(s)
        i = STATS.index(s)
        return i ? _INTL(STAT_NAMES[i]) : s.to_s
      end

      # PIF's: the best IV's stat (the personality value breaks ties)
      def characteristic(pk)
        return "" unless nature_shown?(pk)
        order = [:HP, :ATTACK, :DEFENSE, :SPEED, :SPECIAL_ATTACK, :SPECIAL_DEFENSE]
        start = pk.personalID.to_i % order.length
        best = nil
        order.length.times do |i|
          s = order[(i + start) % order.length]
          best = s if best.nil? || pk.iv[s].to_i > pk.iv[best].to_i
        end
        return _INTL(CHARACTERISTICS[best][pk.iv[best].to_i % 5])
      rescue StandardError
        return ""
      end

      #------------------------------------------------------------------------
      # Abilities and what hits it
      #------------------------------------------------------------------------
      def ability_id(pk)
        a = pk.respond_to?(:ability_id) ? pk.ability_id : pk.ability
        return a.respond_to?(:id) ? a.id : a
      rescue StandardError
        return nil
      end

      def ability_name(id)
        return "" if id.nil?
        return ::KIFER.ability_name(id) if defined?(::KIFER) && ::KIFER.respond_to?(:ability_name) && kifer_on?
        return (::GameData::Ability.get(id).name rescue id.to_s)
      end

      def ability_text(id)
        return "" if id.nil?
        if defined?(::KIFER) && kifer_on? && ::KIFER.respond_to?(:ability_full_text)
          t = (::KIFER.ability_full_text(id) rescue nil)
          return t.to_s.split("\n").first.to_s if t && !t.to_s.empty?
        end
        return (::GameData::Ability.get(id).description rescue "").to_s
      end

      def kifer_on?
        return defined?(::KIFER) && ::KIFER.respond_to?(:enabled?) && ::KIFER.enabled? ? true : false
      rescue StandardError
        return false
      end

      # Its species' hidden ability, when it doesn't have it
      def hidden_ability(pk)
        list = Array(pk.species_data.hidden_abilities) rescue []
        id = list.first
        return nil if id.nil? || id == ability_id(pk)
        return id
      end

      # Every ability it has on: its own, Double Abilities' second, KIF-ER's
      # innates
      def abilities_of(pk)
        out = [ability_id(pk)]
        pair = double_pair(pk)
        out += pair.map { |_s, id| id } if pair
        out += Array(pk.innates) if kifer_on? && pk.respond_to?(:innates)
        return out.compact.uniq
      rescue StandardError
        return [ability_id(pk)].compact
      end

      # Double Abilities' pair ([[:head, id], [:body, id]]), nil without one
      def double_pair(pk)
        return nil unless defined?(Reloaded::DoubleAbilities) && Reloaded::DoubleAbilities.respond_to?(:pair)
        return Reloaded::DoubleAbilities.pair(pk)
      rescue StandardError
        return nil
      end

      # What hits it: {:weak => [[type, mult]], :resist => [[type, mult]]}
      # (mult 4, 2, 0.5, 0.25 or 0), its abilities counted
      def weakness(types, abilities)
        immune = IMMUNE.dup
        immune.merge!(Reloaded::Matchup::TYPE_IMMUNE) if defined?(Reloaded::Matchup::TYPE_IMMUNE)
        weak = []
        resist = []
        wonder = abilities.include?(:WONDERGUARD)
        attack_types.each do |t|
          m = 1.0
          types.compact.uniq.each { |d| m *= ::Effectiveness.calculate_one(t, d) / 2.0 }
          abilities.each do |a|
            m = 0.0 if immune[a] == t
            m *= 0.5 if HALF[a] && HALF[a].include?(t)
            m *= 2.0 if DOUBLE[a] && DOUBLE[a].include?(t)
          end
          m = 0.0 if wonder && m <= 1.0
          if m > 1.0 then weak << [t, m]
          elsif m < 1.0 then resist << [t, m]
          end
        end
        weak.sort_by! { |t, m| [-m, attack_types.index(t)] }
        resist.sort_by! { |t, m| [m, attack_types.index(t)] }
        return { :weak => weak, :resist => resist, :wonder => wonder }
      rescue StandardError => e
        Reloaded::Log.warning_once("The Summary's weaknesses couldn't be worked out: #{e.message}", :summary)
        return { :weak => [], :resist => [], :wonder => false }
      end

      def attack_types
        return @attack_types if @attack_types
        list = []
        ::GameData::Type.each { |t| list << t.id unless t.pseudo_type || t.id == :SHADOW } if ::GameData::Type.respond_to?(:each)
        return @attack_types = list
      end

      #------------------------------------------------------------------------
      # Words
      #------------------------------------------------------------------------
      def num(n)
        return n.to_i.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
      end

      def date(t)
        return nil unless t
        return _INTL("{1} {2}, {3}", _INTL(MONTHS[t.mon - 1]), t.day, t.year)
      rescue StandardError
        return nil
      end

      def map_name(id)
        return nil unless id && id.to_i > 0 && defined?(pbGetMapNameFromId)
        name = (pbGetMapNameFromId(id) rescue nil).to_s
        return name.empty? ? nil : name
      end

      # Where and when it came: "Met at Silph Co., Lv 25, Oct 12, 2026."
      def met_line(pk)
        place = pk.respond_to?(:obtain_text) && !pk.obtain_text.to_s.empty? ? pk.obtain_text.to_s : map_name(pk.obtain_map)
        place ||= _INTL("a faraway place")
        when_ = date(pk.timeReceived)
        lv = pk.obtain_level.to_i
        line = case pk.obtain_method.to_i
               when 1 then _INTL("Egg received at {1}", place)
               when 2 then _INTL("Traded at Lv {1}", lv)
               when 4 then _INTL("A fateful encounter at {1}, Lv {2}", place, lv)
               else _INTL("Met at {1}, Lv {2}", place, lv)
               end
        line += ", " + when_ if when_
        return line + "."
      rescue StandardError
        return ""
      end

      # A hatched one: where and when
      def hatched_line(pk)
        return nil unless pk.obtain_method.to_i == 1
        place = map_name(pk.hatched_map) || _INTL("a faraway place")
        when_ = date(pk.timeEggHatched)
        return when_ ? _INTL("Hatched at {1}, {2}.", place, when_) : _INTL("Hatched at {1}.", place)
      rescue StandardError
        return nil
      end

      def egg_words(pk)
        steps = pk.steps_to_hatch.to_i
        return EGG_WORDS.find { |lim, _a, _b| lim.nil? || steps < lim }
      end

      #------------------------------------------------------------------------
      # Other mods
      #------------------------------------------------------------------------
      # Alpha Encounters' alphas
      def alpha?(pk)
        return pk.respond_to?(:alpha?) && pk.alpha? ? true : false
      rescue StandardError
        return false
      end

      # Ghostly Possession: [the possessed visuals (the fusion, a copy), the
      # stats it raises (indexes), the Ghost's move's slot], nil when it's not
      # possessed
      def possessed(pk)
        return nil unless pk && defined?(::GhostlyPossession::PartyLook) && defined?(::GhostlyPossession::Engine)
        return nil unless ::GhostlyPossession::PartyLook.possessed?(pk)
        return ::GhostlyPossession::Engine.battle_view(pk)
      rescue StandardError => e
        Reloaded::Log.warning_once("The Summary couldn't show a possessed Pokémon as possessed: #{e.message}", :summary)
        return nil
      end

      def ghost_of(pk)
        return ::GhostlyPossession::PartyLook.ghost_of(pk)
      rescue StandardError
        return nil
      end

      # Hidden Power's type and power for it (Kanto Reloaded's Hidden Power)
      def hidden_power(pk)
        return nil if pk.nil? || pk.egg?
        if defined?(Reloaded::HiddenPower) && Reloaded::HiddenPower.respond_to?(:type_of)
          return [Reloaded::HiddenPower.type_of(pk), Reloaded::HiddenPower.move_power(pk, :HIDDENPOWER)]
        end
        return [pk.hiddenPowerType, 60] if pk.respond_to?(:hiddenPowerType) && pk.hiddenPowerType
        return nil
      rescue StandardError
        return nil
      end

      def move_type(pk, move)
        return Reloaded::HiddenPower::Summary.type_for(pk, move) if defined?(Reloaded::HiddenPower::Summary)
        return move.type
      end

      def move_power(pk, move)
        return Reloaded::HiddenPower::Summary.power_for(pk, move) if defined?(Reloaded::HiddenPower::Summary)
        return move.base_damage
      end
    end

    #--------------------------------------------------------------------------
    # The game makes its scene: Kanto Reloaded's while it's On
    #--------------------------------------------------------------------------
    module SceneChoice
      def new(*args, &block)
        if equal?(::PokemonSummary_Scene) && Reloaded::Summary.active?
          begin
            return Reloaded::Summary.scene_class.new(*args, &block)
          rescue Exception => e
            raise if Reloaded::Hooks.passthrough?(e)
            Reloaded::Log.exception("The Summary didn't open; the game's own instead", e, :summary)
          end
        end
        super
      end
    end
  end
end
