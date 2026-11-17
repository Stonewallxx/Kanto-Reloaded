# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Shiny Log
#==============================================================================
# His picks (2026-11-16; Kanto Reloaded's Shinies is the Log alone: the
# Reloaded Shiny System stays out, KIF's own colours, odds, Gamble and Sell
# Shininess stay as KIF has them):
#
#   Always on    no switch; a record of every shiny met in the save
#   Entries      every shiny met, caught or not, with how it ended: Caught,
#                Got Away (fled), Knocked Out (fainted), Hatched, Received
#                (a gift or a trade), Gambled (KIF's PC Gamble). Opposing
#                trainers' shinies aren't logged (as the Trainer Card's
#                count). Each keeps the Pokémon's KIF colours, so its picture
#                stays after it's gone
#   Took         wild Pokémon met since the last shiny, any species (counted
#                from when Kanto Reloaded first sees the save)
#   Old saves    every shiny owned is rebuilt from PIF's own record on it
#                (where and when it was met or hatched, how, its level;
#                Took unknown); shinies the Trainer Card counted that aren't
#                owned any more show as one Earlier Shinies line, so the Log
#                and the card's Shinies Found always agree
#   Opens from   the Trainer Card's Stats side (first in Actions, like Battle
#                Records; a click on Shinies Found too), an Overworld Menu row
#                (the count in gold), and a shiny's Party menu or PC Actions
#                (straight to its entry)
#   Multiplayer  each player their own Log; a shiny met in a co-op battle goes
#                in both (the game that ran the battle sends it), its ending
#                saying who caught it
#   Sounds       the game's own (his picks: Keep Current)
#
# Kept in the save's "shiny_log" section:
#   "entries"  [{ "pid", "sp", "nm", "lv", "f", "t", "map", "pl", "how",
#                 "end", "took", "by", "with", "rb", "c" }]
#   "since"    wild Pokémon met since the last shiny
#   "earlier"  shinies counted before the Log that aren't owned any more
#   "seeded"   the save's shinies were rebuilt once
#
# how: "grass", "cave", "surf", "rod:OldRod", "rock_smash", "headbutt",
# "wild_link:<chain>", "radar:<chain>", "safari", "contest", "wild" (a
# special battle), "egg", "gift", "trade", "gamble", "met" (rebuilt: met in
# the wild)
#
#   Reloaded::ShinyLog.entries / count / since
#   Reloaded::ShinyLog.open(pid = nil)   # the screen, at a shiny's entry
#==============================================================================

module Reloaded
  module ShinyLog
    FEATURE = :shiny_log
    SECTION = "shiny_log"
    SHARE_ID = "kr_shiny_log"
    VERSION = 1
    ENDINGS = %w[caught fled fainted hatched received gambled].freeze
    OWNED_ENDINGS = %w[caught hatched received gambled].freeze
    WILD_ENDINGS = %w[caught fled fainted].freeze
    HOW = /\A(grass|cave|surf|rod:(OldRod|GoodRod|SuperRod)|rock_smash|headbutt|wild_link:\d{1,4}|radar:\d{1,4}|safari|contest|wild|egg|gift|trade|gamble|met|coop)\z/
    # A fusion's own colour fields (KIF keeps one set per part)
    PART_IVARS = %i[@head_shiny @body_shiny @head_shinyhue @body_shinyhue @head_shinyr @body_shinyr @head_shinyg @body_shinyg
                    @head_shinyb @body_shinyb @head_shinykrs @body_shinykrs @head_shinyimprovpif @body_shinyimprovpif].freeze
    MAX_SHARED = 6
    ROD_NAMES = { "OldRod" => "Old Rod", "GoodRod" => "Good Rod", "SuperRod" => "Super Rod" }.freeze
    ENDING_WORDS = { "caught" => "CAUGHT", "fled" => "GOT AWAY", "fainted" => "KNOCKED OUT", "hatched" => "HATCHED",
                     "received" => "RECEIVED", "gambled" => "GAMBLED" }.freeze
    ENDING_TONES = { "caught" => :green, "fled" => :dim, "fainted" => :red, "hatched" => :amber, "received" => :blue,
                     "gambled" => :pink }.freeze
    MONTHS = %w[Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec].freeze

    class << self
      def boot
        Reloaded::Features.register(FEATURE, :name => "Shiny Log", :core => true, :order => 53,
          :description => "A record of every shiny you meet: When, where, how and how it ended.") if defined?(Reloaded::Features)
        Reloaded::SaveStore.register(SECTION)
        Reloaded::Events.on(:save_loaded, :shiny_log, 64) { |ctx| loaded(ctx) }
        Reloaded::Events.on(:new_game, :shiny_log, 64) { started_fresh }
        Reloaded::Events.on(:saving, :shiny_log, 62) { sweep }
        install
        return true
      end

      def on?
        return Reloaded::Features.on?(FEATURE)
      rescue StandardError
        return false
      end

      #------------------------------------------------------------------------
      # The save's data
      #------------------------------------------------------------------------
      def data
        d = Reloaded::SaveStore.section(SECTION)
        return nil unless d
        d["entries"] ||= []
        return d
      rescue StandardError
        return nil
      end

      def entries
        d = data
        return d ? d["entries"] : []
      end

      def since
        d = data
        return d ? d["since"].to_i : 0
      end

      def earlier
        d = data
        return d ? d["earlier"].to_i : 0
      end

      # Every shiny the Log knows of (entries and Earlier Shinies): the
      # Trainer Card's Shinies Found
      def count
        return entries.length + earlier
      end

      def find(pid)
        return nil if pid.nil?
        return entries.find { |e| e["pid"] == pid.to_i }
      end

      # The newest first (X: the oldest first)
      def sorted(oldest = false)
        list = entries.sort_by { |e| [e["t"].to_i, e["pid"].to_i] }
        return oldest ? list : list.reverse
      end

      #------------------------------------------------------------------------
      # Recording
      #------------------------------------------------------------------------
      # An entry for pk (a new one, or the one it has, filled in): how it was
      # met and how it ended; extra: "took", "by", "with", "rb", "t", "map"...
      def record(pk, how, ending, extra = {})
        return nil unless on? && pk && data
        pid = (pk.personalID rescue nil)
        return nil if pid.nil?
        e = find(pid)
        unless e
          e = snapshot(pk)
          entries << e
        end
        e["how"] = how.to_s if how && (e["how"].nil? || extra[:how_wins])
        e["end"] = ending.to_s if ending
        extra.each { |k, v| e[k.to_s] = v unless k == :how_wins }
        counted(pid)
        return e
      rescue StandardError => e
        Reloaded::Log.exception("The Shiny Log couldn't note a shiny", e, :shiny_log)
        return nil
      end

      # What an entry keeps of the Pokémon itself
      def snapshot(pk)
        map = $game_map ? $game_map.map_id : 0
        return { "pid" => pk.personalID.to_i, "sp" => pk.species.to_s, "nm" => species_name(pk.species), "lv" => pk.level.to_i,
                 "f" => (pk.form.to_i rescue 0), "t" => Time.now.to_i, "map" => map, "pl" => place_name(map), "c" => colours(pk) }
      end

      # KIF's colour fields (rolled now if they weren't yet, as showing it
      # would), and a fusion's per-part ones as they are
      def colours(pk)
        out = {}
        if pk.respond_to?(:kif_shiny_colors)
          c = pk.kif_shiny_colors
          c.each { |k, v| out[k.to_s] = v.is_a?(Array) ? v.dup : v }
        end
        PART_IVARS.each do |iv|
          v = pk.instance_variable_get(iv)
          out[iv.to_s.delete("@")] = v.is_a?(Array) ? v.dup : v unless v.nil?
        end
        return out
      rescue StandardError
        return out || {}
      end

      # The Trainer Card counts it too (its Shinies Found is the Log's count)
      def counted(pid)
        return unless defined?(Reloaded::TrainerCard::Counters)
        list = Reloaded::TrainerCard::Counters.shinies
        list << pid.to_i unless list.include?(pid.to_i)
      rescue StandardError
        nil
      end

      def species_name(sp)
        return ::GameData::Species.get(sp).name.to_s
      rescue StandardError
        return sp.to_s.capitalize
      end

      def place_name(map_id)
        return "" if map_id.to_i <= 0
        return pbGetMapNameFromId(map_id.to_i).to_s if defined?(pbGetMapNameFromId)
        return ""
      rescue StandardError
        return ""
      end

      #------------------------------------------------------------------------
      # Battles
      #------------------------------------------------------------------------
      def wild?(battle)
        return true if defined?(::PokeBattle_SafariZone) && battle.is_a?(::PokeBattle_SafariZone)
        return (battle.wildBattle? rescue false) ? true : false
      end

      def foes(battle)
        return Array(battle.pbParty(1)).compact
      rescue StandardError
        return []
      end

      # A wild battle starts: each foe counts as met; a shiny gets its entry
      # (Got Away until the battle says otherwise)
      def battle_started(battle)
        return unless on? && data && wild?(battle)
        d = data
        pending = []
        foes(battle).each do |pk|
          d["since"] = d["since"].to_i + 1
          next unless (pk.shiny? rescue false)
          e = record(pk, how_now(pk), "fled", "took" => d["since"].to_i)
          d["since"] = 0
          pending << pk if e
        end
        battle.instance_variable_set(:@kr_shiny_log, pending) unless pending.empty?
        battle.instance_variable_set(:@kr_shiny_met, foes(battle).length)
      rescue StandardError => e
        Reloaded::Log.exception("The Shiny Log couldn't read a battle's start", e, :shiny_log)
      end

      # A catch is stored: a shiny among them is Caught
      def caught_now(battle)
        return unless on? && data
        Array(battle.instance_variable_get(:@caughtPokemon)).compact.each do |pk|
          next unless (pk.shiny? rescue false) && (pk.personalID rescue nil)
          if find(pk.personalID)
            record(pk, nil, "caught", "by" => nil)
          else
            # one the start didn't see (a co-op partner's copy of the battle)
            record(pk, how_now(pk), "caught")
          end
        end
      rescue StandardError => e
        Reloaded::Log.exception("The Shiny Log couldn't note a catch", e, :shiny_log)
      end

      # The battle's over: the rest Knocked Out or Got Away; a co-op
      # partner's catch is theirs; the partner's game hears of it
      def battle_ended(battle)
        pending = battle.instance_variable_get(:@kr_shiny_log)
        coop = (battle.kif_coop rescue nil) || battle.instance_variable_get(:@kif_coop)
        theirs = coop ? partner_catches(coop) : {}
        with = coop ? partner_names(coop) : nil
        Array(pending).each do |pk|
          e = find((pk.personalID rescue nil))
          next unless e
          if theirs[pk.personalID]
            e["end"] = "caught"
            e["by"] = theirs[pk.personalID]
          elsif e["end"] != "caught"
            e["end"] = (pk.hp.to_i <= 0 rescue false) ? "fainted" : "fled"
          end
          e["with"] = with if with
        end
        share(battle, coop, Array(pending)) if coop
      rescue StandardError => e
        Reloaded::Log.exception("The Shiny Log couldn't read a battle's end", e, :shiny_log)
      end

      # How a wild Pokémon met now was found
      def how_now(pk)
        if defined?(Reloaded::WildLink::Search)
          s = Reloaded::WildLink::Search
          t = (s.target rescue nil)
          if pk.instance_variable_get(:@kr_wl_target) || ((s.battle rescue false) && t)
            n = t ? Reloaded::WildLink.chain_for(t["species"], t["way"], t["map"]) : 0
            return "wild_link:#{[n.to_i, 9999].min}"
          end
        end
        return "safari" if call?(:pbInSafari?)
        return "contest" if call?(:pbInBugContest?)
        temp = defined?($PokemonTemp) ? $PokemonTemp : nil
        radar = temp && temp.respond_to?(:pokeradar) ? temp.pokeradar : nil
        return "radar:#{[radar[2].to_i, 9999].min}" if radar.is_a?(Array) && radar[2]
        type = temp && temp.respond_to?(:encounterType) ? temp.encounterType.to_s : ""
        case type
        when /\A(OldRod|GoodRod|SuperRod)\z/ then return "rod:#{type}"
        when /\AWater/ then return "surf"
        when /\ACave/ then return "cave"
        when /\ARockSmash/ then return "rock_smash"
        when /Headbutt/ then return "headbutt"
        when /\A(Land|TallGrass)/ then return "grass"
        end
        return "wild"
      rescue StandardError
        return "wild"
      end

      def call?(name)
        return false unless Object.private_method_defined?(name) || Object.method_defined?(name)
        return send(name) ? true : false
      rescue StandardError
        return false
      end

      #------------------------------------------------------------------------
      # Co-op (KIF's Multiplayer, its mod sharing)
      #------------------------------------------------------------------------
      # { pid => the partner who caught it }
      def partner_catches(coop)
        out = {}
        hosts = coop.instance_variable_get(:@hosts) || [coop]
        hosts.each do |h|
          name = (h.name.to_s rescue "")
          Array(h.caught).each { |pk| out[pk.personalID] = name if (pk.personalID rescue nil) }
        end
        return out
      rescue StandardError
        return {}
      end

      def partner_names(coop)
        hosts = coop.instance_variable_get(:@hosts) || [coop]
        names = hosts.map { |h| (h.name.to_s rescue "") }.reject(&:empty?)
        return names.empty? ? nil : names.join(" & ")
      rescue StandardError
        return nil
      end

      def net?
        return defined?(::KIF::Net) && ::KIF::Net.respond_to?(:share) && ::KIF::Net.respond_to?(:on_share)
      end

      def install_share
        return unless net?
        ::KIF::Net.on_share(SHARE_ID) { |from, key, payload| Reloaded::ShinyLog.receive(from, key, payload) }
      rescue StandardError => e
        Reloaded::Log.exception("The Shiny Log's Multiplayer sharing couldn't be set up", e, :shiny_log)
      end

      # The game that ran a co-op battle tells the partners: how many were
      # met, and each shiny (who caught it by name: the player here, or a
      # partner)
      def share(battle, _coop, pending)
        return unless net? && (::KIF::Net.connected? rescue false) && (::KIF::Net.partner_has?(SHARE_ID) rescue false)
        me = ($Trainer.name.to_s rescue "")
        list = pending.first(MAX_SHARED).map do |pk|
          e = find(pk.personalID) or next
          by = e["end"] == "caught" ? (e["by"] || me) : nil
          { "pid" => e["pid"], "sp" => e["sp"], "lv" => e["lv"], "f" => e["f"], "how" => e["how"], "end" => e["end"], "by" => by, "c" => e["c"] }
        end.compact
        n = battle.instance_variable_get(:@kr_shiny_met).to_i
        ::KIF::Net.share(SHARE_ID, "met", { "v" => VERSION, "n" => n, "e" => list })
      rescue StandardError => e
        Reloaded::Log.exception("The Shiny Log couldn't tell a partner of a co-op battle", e, :shiny_log)
      end

      # A partner's co-op battle: the wild Pokémon met count here too; each
      # shiny goes in this Log (one this player caught keeps its own entry)
      def receive(from, key, payload)
        return unless on? && data && key.to_s == "met" && payload.is_a?(Hash)
        d = data
        d["since"] = d["since"].to_i + [[payload["n"].to_i, 0].max, 6].min
        me = ($Trainer.name.to_s rescue "")
        Array(payload["e"]).first(MAX_SHARED).each do |x|
          next unless x.is_a?(Hash)
          sp = x["sp"].to_s
          next unless (::GameData::Species.try_get(sp.to_sym) rescue nil) || (::GameData::Species.get(sp.to_sym) rescue nil)
          ending = ENDINGS.include?(x["end"].to_s) && WILD_ENDINGS.include?(x["end"].to_s) ? x["end"].to_s : "fled"
          how = x["how"].to_s =~ HOW ? x["how"].to_s : "wild"
          pid = x["pid"].to_i
          by = x["by"].to_s.empty? || x["by"].to_s == me ? nil : x["by"].to_s[0, 24]
          e = find(pid)
          if e
            e["how"] = how
            e["with"] = from.to_s[0, 40]
            if e["end"] != "caught" || by.nil?
              e["end"] = ending
              e["by"] = by
            end
          else
            took = d["since"].to_i
            d["since"] = 0
            map = $game_map ? $game_map.map_id : 0
            entries << { "pid" => pid, "sp" => sp, "nm" => species_name(sp.to_sym), "lv" => [[x["lv"].to_i, 1].max, 999].min,
                         "f" => x["f"].to_i, "t" => Time.now.to_i, "map" => map, "pl" => place_name(map), "how" => how,
                         "end" => ending, "took" => took, "by" => by, "with" => from.to_s[0, 40], "c" => clean_colours(x["c"]) }
            counted(pid)
          end
        end
      rescue StandardError => e
        Reloaded::Log.exception("The Shiny Log couldn't read a partner's co-op battle", e, :shiny_log)
      end

      # Colour fields from a partner: numbers and number lists only
      def clean_colours(c)
        return {} unless c.is_a?(Hash)
        out = {}
        c.first(24).each do |k, v|
          next unless k.to_s =~ /\A[a-z_]{1,24}\z/
          if v.is_a?(Integer) || v == true || v == false
            out[k.to_s] = v
          elsif v.is_a?(Array) && v.length <= 12 && v.all? { |n| n.is_a?(Integer) }
            out[k.to_s] = v.dup
          end
        end
        return out
      end

      #------------------------------------------------------------------------
      # Old saves, gifts and trades: the shinies owned
      #------------------------------------------------------------------------
      def owned
        return Reloaded::TrainerCard.owned_pokemon if defined?(Reloaded::TrainerCard) && Reloaded::TrainerCard.respond_to?(:owned_pokemon)
        list = $Trainer ? Array($Trainer.party).compact : []
        return list
      rescue StandardError
        return []
      end

      def owned_by_pid(pid)
        return owned.find { |pk| (pk.personalID rescue nil) == pid }
      end

      def loaded(ctx)
        d = data
        return unless d
        if ctx.is_a?(Hash) && ctx[:new_game]
          started_fresh
        elsif !d["seeded"]
          sweep(true)
          d["seeded"] = true
          Reloaded::Log.info("Shiny Log: #{entries.length} shinies rebuilt from the save, #{earlier} earlier", :shiny_log)
        else
          sweep
        end
      end

      def started_fresh
        d = data
        return unless d
        d["seeded"] = true
      end

      # Every shiny owned that has no entry gets one from PIF's own record on
      # it; then the Trainer Card's count and the Log agree
      def sweep(rebuild = false)
        return unless on? && data
        owned.each do |pk|
          next if pk.nil? || (pk.egg? rescue false) || !(pk.shiny? rescue false)
          pid = (pk.personalID rescue nil)
          next if pid.nil? || find(pid)
          how, ending = obtained(pk, rebuild)
          extra = { "rb" => (rebuild && ending == "caught") ? true : nil }
          t = (pk.timeReceived.to_i rescue 0)
          t = (pk.timeEggHatched.to_i rescue 0) if ending == "hatched" && (pk.timeEggHatched.to_i rescue 0) > 0
          extra["t"] = t if t > 0
          map = ending == "hatched" ? (pk.hatched_map rescue nil) : (pk.obtain_map rescue nil)
          if map.to_i > 0
            extra["map"] = map.to_i
            extra["pl"] = place_name(map)
          end
          met = (pk.obtain_level rescue nil)
          extra["lv"] = met.to_i if met.to_i > 0 && ending != "hatched"
          extra["lv"] = 1 if ending == "hatched"
          extra.delete("rb") unless extra["rb"]
          record(pk, how, ending, extra)
        end
        reconcile
      rescue StandardError => e
        Reloaded::Log.exception("The Shiny Log couldn't look over the shinies owned", e, :shiny_log)
      end

      # How PIF says a Pokémon was obtained: [how, ending]
      def obtained(pk, rebuild)
        case (pk.obtain_method rescue 0).to_i
        when 1 then return ["egg", "hatched"]
        when 2 then return ["trade", "received"]
        when 4 then return ["gift", "received"]
        end
        mine = ($Trainer.id rescue nil)
        foreign = mine && (pk.owner.id rescue mine) != mine
        return ["trade", "received"] if foreign
        return rebuild ? ["met", "caught"] : ["gift", "received"]
      end

      # Shinies the Trainer Card counted with no entry and not owned: the
      # Earlier Shinies line; every entry counted on the card
      def reconcile
        d = data
        return unless d && defined?(Reloaded::TrainerCard::Counters)
        list = Reloaded::TrainerCard::Counters.shinies
        pids = entries.map { |e| e["pid"] }
        pids.each { |p| list << p unless list.include?(p) }
        d["earlier"] = (list - pids).length
      rescue StandardError
        nil
      end

      #------------------------------------------------------------------------
      # An entry's Pokémon: the one owned, else one made from the entry
      #------------------------------------------------------------------------
      def pokemon_for(e)
        pk = owned_by_pid(e["pid"])
        return pk if pk && (pk.shiny? rescue false)
        return made(e)
      end

      def made(e)
        return nil unless defined?(::Pokemon)
        sp = e["sp"].to_s.to_sym
        pk = (::Pokemon.new(sp, [e["lv"].to_i, 1].max, $Trainer, false) rescue nil) || (::Pokemon.new(sp, [e["lv"].to_i, 1].max) rescue nil)
        return nil unless pk
        pk.instance_variable_set(:@personalID, e["pid"].to_i)
        pk.form = e["f"].to_i if e["f"].to_i > 0 && pk.respond_to?(:form=)
        pk.shiny = true if pk.respond_to?(:shiny=)
        c = e["c"].is_a?(Hash) ? e["c"] : {}
        if pk.respond_to?(:kif_set_shiny_colors) && c.key?("hue")
          krs = c["krs"].is_a?(Array) ? c["krs"] : nil
          pk.kif_set_shiny_colors(:hue => c["hue"], :pif => c["pif"], :r => c["r"], :g => c["g"], :b => c["b"],
                                  :krs => krs || [], :filter => c["filter"]) if krs
        end
        PART_IVARS.each do |iv|
          k = iv.to_s.delete("@")
          pk.instance_variable_set(iv, c[k].is_a?(Array) ? c[k].dup : c[k]) if c.key?(k)
        end
        return pk
      rescue StandardError => err
        Reloaded::Log.warning_once("The Shiny Log couldn't make a picture's Pokémon (#{e['sp']}): #{err.message}", :shiny_log)
        return nil
      end

      #------------------------------------------------------------------------
      # Words
      #------------------------------------------------------------------------
      def how_words(e)
        how = e["how"].to_s
        case how
        when "grass" then return _INTL("In the Grass")
        when "cave" then return _INTL("In a Cave")
        when "surf" then return _INTL("Surfing")
        when /\Arod:(\w+)\z/ then return _INTL("Fishing, {1}", _INTL(ROD_NAMES[$1] || $1))
        when "rock_smash" then return _INTL("Rock Smash")
        when "headbutt" then return _INTL("Headbutt")
        when /\Awild_link:(\d+)\z/ then return $1.to_i > 0 ? _INTL("Wild Link, Chain {1}", $1) : _INTL("Wild Link")
        when /\Aradar:(\d+)\z/ then return _INTL("Poké Radar, Chain {1}", $1)
        when "safari" then return _INTL("Safari Zone")
        when "contest" then return _INTL("Bug Contest")
        when "egg" then return _INTL("Hatched")
        when "gift" then return _INTL("Gift")
        when "trade" then return _INTL("Trade")
        when "gamble" then return _INTL("Gamble (PC)")
        when "met" then return _INTL("Met in the Wild")
        end
        return _INTL("Wild Battle")
      end

      def ending_words(e)
        return _INTL("{1} CAUGHT IT", e["by"].to_s.upcase) if e["end"] == "caught" && !e["by"].to_s.empty?
        return _INTL(ENDING_WORDS[e["end"].to_s] || "GOT AWAY")
      end

      def owned_ending?(e)
        return OWNED_ENDINGS.include?(e["end"].to_s) && e["by"].to_s.empty?
      end

      def wild_ending?(e)
        return WILD_ENDINGS.include?(e["end"].to_s)
      end

      def date_words(t, year = false)
        tm = Time.at(t.to_i)
        return year ? "#{MONTHS[tm.month - 1]} #{tm.day}, #{tm.year}" : "#{MONTHS[tm.month - 1]} #{tm.day}"
      rescue StandardError
        return ""
      end

      def num(n)
        return n.to_i.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
      end

      #------------------------------------------------------------------------
      # The screen and its ways in
      #------------------------------------------------------------------------
      def open(pid = nil, z = nil)
        return nil unless on? && defined?(Reloaded::ShinyLogScreen)
        sweep
        return Reloaded::ShinyLogScreen.open(pid, z)
      rescue StandardError => e
        Reloaded::Log.exception("The Shiny Log couldn't open", e, :shiny_log)
        return nil
      end

      def install
        h = Reloaded::Hooks
        if defined?(::PokeBattle_Battle) && ::PokeBattle_Battle.method_defined?(:pbStartBattle)
          h.around(FEATURE, ::PokeBattle_Battle, :pbStartBattle, :id => :shiny_log_battle) do |original, *args|
            battle = original.receiver
            Reloaded::ShinyLog.battle_started(battle)
            begin
              original.call(*args)
            ensure
              Reloaded::ShinyLog.battle_ended(battle)
            end
          end
        end
        if defined?(::PokeBattle_SafariZone) && ::PokeBattle_SafariZone.method_defined?(:pbStartBattle)
          h.around(FEATURE, ::PokeBattle_SafariZone, :pbStartBattle, :id => :shiny_log_safari) do |original, *args|
            battle = original.receiver
            Reloaded::ShinyLog.battle_started(battle)
            begin
              original.call(*args)
            ensure
              Reloaded::ShinyLog.battle_ended(battle)
            end
          end
        end
        [(defined?(::PokeBattle_Battle) ? ::PokeBattle_Battle : nil),
         (defined?(::PokeBattle_SafariZone) ? ::PokeBattle_SafariZone : nil)].compact.each_with_index do |k, i|
          next unless k.method_defined?(:pbRecordAndStoreCaughtPokemon)
          h.around(FEATURE, k, :pbRecordAndStoreCaughtPokemon, :id => :"shiny_log_caught#{i}") do |original, *args|
            Reloaded::ShinyLog.caught_now(original.receiver)
            original.call(*args)
          end
        end
        if ::Object.private_method_defined?(:pbHatch) || ::Object.method_defined?(:pbHatch)
          h.around(FEATURE, ::Object, :pbHatch, :id => :shiny_log_hatched) do |original, pkmn, *rest|
            ret = original.call(pkmn, *rest)
            Reloaded::ShinyLog.record(pkmn, "egg", "hatched", "lv" => 1) if (pkmn.shiny? rescue false)
            ret
          end
        end
        # KIF's PC Gamble (F-SHINY-02): a Pokémon made shiny
        if defined?(::KIF::ShinyActions) && ::KIF::ShinyActions.respond_to?(:make_shiny)
          h.around(FEATURE, ::KIF::ShinyActions.singleton_class, :make_shiny, :id => :shiny_log_gamble) do |original, pkmn, *rest|
            was = (pkmn.shiny? rescue false)
            ret = original.call(pkmn, *rest)
            Reloaded::ShinyLog.record(pkmn, "gamble", "gambled", "took" => nil) if !was && (pkmn.shiny? rescue false)
            ret
          end
        end
        # Hoenn's walk-up Safari: its own catch
        if ::Object.private_method_defined?(:record_safari_catch) || ::Object.method_defined?(:record_safari_catch)
          h.around(FEATURE, ::Object, :record_safari_catch, :id => :shiny_log_hoenn_safari) do |original, pkmn, *rest|
            ret = original.call(pkmn, *rest)
            Reloaded::ShinyLog.record(pkmn, "safari", "caught") if (pkmn.shiny? rescue false)
            ret
          end
        end
        install_share
        install_menus
      end

      def install_menus
        if defined?(Reloaded::OverworldMenu)
          Reloaded::OverworldMenu.register(:shiny_log, :name => "Shiny Log", :kind => :action, :priority => 56, :home => false,
            :feature => FEATURE,
            :paint => proc { |b, x1, y, h, c, _room| Reloaded::ShinyLog.paint_row(b, x1, y, h, c) },
            :description => "Every shiny you've met, caught or not: When, where, how it ended and how many encounters it took.",
            :handler => proc { |menu| Reloaded::ShinyLog.open; menu.refresh rescue nil; nil })
        end
        if defined?(Reloaded::PartyScreen) && Reloaded::PartyScreen.respond_to?(:add_command)
          Reloaded::PartyScreen.add_command(:shiny_log,
            :label => proc { |pkmn| Reloaded::ShinyLog.on? && !(pkmn.egg? rescue true) && (pkmn.shiny? rescue false) ? _INTL("Shiny Log") : nil },
            :description => "This shiny's page in the Shiny Log.",
            :handler => proc { |_scene, pkmn, _index| Reloaded::ShinyLog.open(pkmn.personalID) })
        end
        if defined?(Reloaded::PC) && Reloaded::PC.respond_to?(:add_action)
          Reloaded::PC.add_action(:shiny_log, :order => 30, :description => "This shiny's page in the Shiny Log.",
                                  :label => proc { |pkmn| Reloaded::ShinyLog.on? && pkmn && !(pkmn.egg? rescue true) && (pkmn.shiny? rescue false) ? "Shiny Log" : nil }) do |_screen, pkmn, _selected, heldpoke|
            Reloaded::ShinyLog.open((heldpoke || pkmn).personalID)
          end
        end
      end

      # The Overworld Menu row: the count in gold (his pick, Count)
      def paint_row(b, x1, y, h, c)
        word = num(count)
        pf = ::KIF::PixelFont
        tw = Reloaded::Pixel.width(pf::ROW, word)
        Reloaded::Pixel.text(b, x1 - tw, y, tw, h, word, c[:gold] || Color.new(240, 200, 80), pf::ROW)
        return tw
      rescue StandardError
        return 0
      end
    end
  end
end
