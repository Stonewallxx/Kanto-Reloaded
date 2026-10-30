# encoding: utf-8
#==============================================================================
# Kanto Reloaded: catch chances
#==============================================================================
# Roadmap topic battle-tools (Wave 6; his picks 2026-10-29): the chance a
# ball catches a Pokémon right now, worked out from the game's own catch
# maths instead of rolled. That's KIF's pbCaptureCalc
# (990_KIF/F-BATTLE-11_CatchQoL/CriticalCaptures.rb:30-103: PIF's with KIF's
# Critical Captures), or PIF's own (011_Battle/003_Battle/
# 001_PokeBattle_BattleCommon.rb:219-272) when KIF's module is off:
#
#   P(caught) = 1 - (1 - last-ball critical) * (1 - KIF critical) * (1 - (y/65536)^4)
#
# Every ball handler runs on a Probe: a stand-in of the battler (and of the
# battle) that reads through to it but keeps writes to itself, because PIF's
# Dream, Toxic, Scorch, Frost and Spark Balls set a status inside the
# catch maths and the Firecracker takes HP. So a Toxic Ball's chance counts
# the poison it would give (his pick), and nothing is poisoned. A handler
# that tries to change the battle any other way (pbInflictStatus,
# pbRandom...) is stopped and its chance shows "?". Other mods' balls work
# the same way.
#
# Guarded: the method the battle runs is checked once against the two the
# game ships (and the wraps known around them: KIF's Archipelago, worked out
# too, and Alpha Encounters', which changes nothing for a thrown ball; Kanto
# Reloaded's own Guaranteed Catch is read as a setting). Anything else (a
# KIF update, another mod's wrap) and every chance is an estimate: "~" in
# front of it, and the log says why (his pick).
#
#   r = Reloaded::CatchChance.chance(battle, battler, :ULTRABALL)
#   r.chance (0.0..1.0, nil: "?"), r.sure, r.mult, r.status (what it'd see),
#   r.status_set (the ball gave it), r.why
#   Reloaded::CatchChance.percent(r)     "35%", "99%" until it's sure, "<1%"
#==============================================================================

module Reloaded
  module CatchChance
    FEATURE = :quick_throw
    ULTRA_BEASTS = [:NIHILEGO, :BUZZWOLE, :PHEROMOSA, :XURKITREE, :CELESTEELA, :KARTANA, :GUZZLORD,
                    :POIPOLE, :NAGANADEL, :STAKATAKA, :BLACEPHALON].freeze      # CriticalCaptures.rb:35-37
    # What a ball handler must never run on the real battler or battle
    MUTATORS = [:pbInflictStatus, :pbSleep, :pbPoison, :pbBurn, :pbParalyze, :pbFreeze, :pbCureStatus,
                :pbConfuse, :pbAttract, :pbReduceHP, :pbRecoverHP, :pbFaint, :pbRaiseStatStage,
                :pbLowerStatStage, :pbChangeTypes, :pbChangeForm, :pbRemoveItem, :pbConsumeItem,
                :pbDisplay, :pbDisplayBrief, :pbDisplayPaused, :pbRandom].freeze
    # The game's catch maths, by their source fingerprints (Fixes.source_crc)
    KIF_CRC = 1468445869               # CriticalCaptures.rb:30-103
    PIF_CRC = 4006461737               # 001_PokeBattle_BattleCommon.rb:219-272
    ARCHIPELAGO_CRC = 1817373196       # Archipelago.rb:801-808, around one of them
    ARCHIPELAGO_ALIAS = :kif_ap_pbCaptureCalc
    # Alpha Encounters (Mods/alpha_encounters/Raids.rb:1249-1254): an Alpha's
    # catch rate x0.8, but only a rate passed in, and a thrown ball passes
    # none (pbThrowPokeBall's catch_rate is nil), so the maths under it is
    # what runs
    ALPHA_CRC = 2119097976
    ALPHA_ALIAS = :originalCaptureCalc
    WRAPS = { ARCHIPELAGO_CRC => ARCHIPELAGO_ALIAS, ALPHA_CRC => ALPHA_ALIAS }.freeze

    class Unsafe < StandardError; end

    # Reads go to the real object; writes stay here
    class Probe
      attr_reader :writes

      def initialize(target)
        @target = target
        @writes = {}
      end

      def status; return @writes.key?(:status) ? @writes[:status] : @target.status; end
      def status=(v); @writes[:status] = v; end
      def hp; return @writes.key?(:hp) ? @writes[:hp] : @target.hp; end
      def hp=(v); @writes[:hp] = v.to_i; end

      def respond_to_missing?(name, priv = false)
        return @target.respond_to?(name, priv)
      end

      def method_missing(name, *args, **kw, &blk)
        raise Unsafe, name.to_s if name.to_s.end_with?("=") || MUTATORS.include?(name)
        return @target.__send__(name, *args, **kw, &blk)
      end
    end

    # What a throw would see this turn:
    #   count      that ball in the Bag now (the throw takes one first, so 1
    #              or less is "the last one" when the maths checks)
    #   kif_crits  KIF's Critical Captures runs (its maths and the save's option)
    #   owned      Pokémon owned
    #   guaranteed Kanto Reloaded's Guaranteed Catch, or Archipelago's
    #   min_rate   Archipelago's lowest catch rate, or nil
    Situation = Struct.new(:count, :kif_crits, :owned, :guaranteed, :min_rate)

    Result = Struct.new(:chance, :sure, :base_rate, :rate, :mult, :status, :status_set, :hp, :x, :shake,
                        :last_crit, :kif_crit, :why, :error)

    class << self
      #------------------------------------------------------------------------
      # Which maths the battle runs: :kif, :pif, or nil (estimates)
      #------------------------------------------------------------------------
      def maths
        unless @maths_checked
          @maths_checked = true
          @maths, why = detect
          Reloaded::Log.warning("Catch chances are estimates: #{why}", FEATURE) unless @maths
        end
        return gate_kif? ? :kif : :pif if @maths == :gate
        return @maths
      end

      def estimate?
        return maths.nil?
      end

      def forget_maths
        @maths_checked = false
        @maths = nil
      end

      # [kind, why]: the battle's pbCaptureCalc, past Kanto Reloaded's own hooks
      def detect
        return [nil, "the battle's catch maths isn't there"] unless defined?(::PokeBattle_Battle) &&
                                                                    ::PokeBattle_Battle.method_defined?(:pbCaptureCalc)
        m = ::PokeBattle_Battle.instance_method(:pbCaptureCalc)
        while m
          owner = m.owner
          if Reloaded::Hooks.registry.any? { |e| e[:module].equal?(owner) }
            m = m.super_method
            next
          end
          return gate_check if gate?(m)
          crc = Reloaded::Fixes.source_crc(m)
          case crc
          when KIF_CRC then return [:kif, nil]
          when PIF_CRC then return [:pif, nil]
          when *WRAPS.keys
            under = WRAPS[crc]
            return [nil, "a wrap on pbCaptureCalc has nothing under it (#{under})"] unless owner.method_defined?(under)
            m = owner.instance_method(under)
          else
            where = m.source_location ? File.basename(m.source_location[0].to_s) : "?"
            return [nil, "pbCaptureCalc isn't the game's (#{m.owner}, #{where}, fingerprint #{crc.inspect})"]
          end
        end
        return [nil, "pbCaptureCalc ran out"]
      rescue StandardError => e
        return [nil, "#{e.class}: #{e.message}"]
      end

      #------------------------------------------------------------------------
      # KIF's module gate (990_KIF/zz_ModuleGate/ModuleGate.rb): each method a
      # KIF module changed becomes a switch, the module's version while it's
      # on, the game's without it while it's off. Under pbCaptureCalc's that's
      # Archipelago's wrap (worked out from KIF::AP), then KIF's maths
      # (CriticalCaptures.rb, its Battles & Challenges module) or PIF's. The
      # switch keeps them out of reach, so their sources are checked instead:
      # PIF's as the gate kept it, KIF's and Archipelago's in their files.
      #------------------------------------------------------------------------
      GATE_FILE = "ModuleGate.rb"
      KIF_FILE = "CriticalCaptures.rb"
      ARCHIPELAGO_FILE = "Archipelago.rb"

      def gate?(m)
        loc = m.source_location
        return loc && File.basename(loc[0].to_s) == GATE_FILE ? true : false
      end

      # [:gate, nil] when everything under the gate is the game's, else why not
      def gate_check
        snap = defined?(::KIF::Modules) && ::KIF::Modules.respond_to?(:snapshot) ? ::KIF::Modules.snapshot : nil
        pif = snap ? snap[[::PokeBattle_BattleCommon, :pbCaptureCalc]] : nil
        return [nil, "KIF's module gate kept no pbCaptureCalc of PIF's"] unless pif && Reloaded::Fixes.source_crc(pif) == PIF_CRC
        return [nil, "KIF's #{KIF_FILE} isn't the game's"] unless file_crc(KIF_FILE) == KIF_CRC
        ap = file_crc(ARCHIPELAGO_FILE)
        return [nil, "KIF's #{ARCHIPELAGO_FILE} isn't the game's"] unless ap.nil? || ap == ARCHIPELAGO_CRC
        return [:gate, nil]
      end

      # A KIF file's pbCaptureCalc fingerprint, nil when there's none
      def file_crc(name)
        path = Reloaded::Paths.script_file(name)
        return nil unless path
        at = File.readlines(path, :encoding => "UTF-8").index { |l| l =~ /\A\s*def pbCaptureCalc\b/ }
        return at ? Reloaded::Fixes.lines_crc(path, at + 1) : nil
      end

      # KIF's maths runs while its module is on (asked each time: the player
      # can switch it in KIF's Modules list)
      def gate_kif?
        return kif_module_on?(KIF_FILE)
      end

      def kif_module_on?(name)
        return false unless defined?(::KIF::Modules) && defined?(::KIF::Features)
        path = Reloaded::Paths.script_file(name)
        return false unless path
        return ::KIF::Modules.active?(::KIF::Features.key_for_file(path)) ? true : false
      rescue StandardError
        return false
      end

      #------------------------------------------------------------------------
      # The situation, read from the game when something asks
      #------------------------------------------------------------------------
      def situation(ball)
        count = $PokemonBag && $PokemonBag.respond_to?(:pbQuantity) ? $PokemonBag.pbQuantity(ball).to_i : 0
        crits = maths == :kif && $PokemonSystem.respond_to?(:critical_captures) && $PokemonSystem.critical_captures.to_i == 1
        owned = ($Trainer.pokedex.owned_count rescue 0).to_i
        guaranteed = defined?(Reloaded::QualityOfLife) && Reloaded::QualityOfLife.on?(:guaranteed_catch)
        min = nil
        if archipelago?
          guaranteed ||= ::KIF::AP.opt("guaranteed_catch") == 1
          min = ::KIF::AP.opt("min_catch_rate").to_i
        end
        return Situation.new(count, crits ? true : false, owned, guaranteed ? true : false, min)
      end

      # Archipelago's wrap acts (its module on, behind KIF's gate, and a
      # linked save)
      def archipelago?
        return false unless defined?(::KIF::AP) && ::KIF::AP.respond_to?(:on?) && ::KIF::AP.on?
        return @maths != :gate || kif_module_on?(ARCHIPELAGO_FILE)
      rescue StandardError
        return false
      end

      def kif_k(owned)
        return 5 if owned > 600
        return 4 if owned > 450
        return 3 if owned > 300
        return 2
      end

      #------------------------------------------------------------------------
      # The chance
      #------------------------------------------------------------------------
      def chance(battle, battler, ball, sit = situation(ball))
        pkmn = battler.pokemon
        base = pkmn.species_data.catch_rate
        base = [base, sit.min_rate].max if sit.min_rate
        if sit.guaranteed
          return Result.new(1.0, true, base, base, 1.0, battler.status, false, battler.hp, 255, 1.0, 0.0, 0.0, :guaranteed)
        end
        probe = Probe.new(battler)
        # CriticalCaptures.rb:33-46
        rate = base
        ultra = ULTRA_BEASTS.include?(pkmn.species)
        if !ultra || ball == :BEASTBALL
          rate = ::BallHandlers.modifyCatchRate(ball, rate, Probe.new(battle), probe, ultra)
        else
          rate /= 10
        end
        rate = [rate * 1.5, 255].min if battle.caughtOffGuard
        # :49-59
        a = probe.totalhp
        b = probe.hp
        x = ((3 * a - 2 * b) * rate.to_f) / (3 * a)
        st = probe.status
        if st == :SLEEP || st == :FROZEN
          x *= 2.5
        elsif st != :NONE
          x *= 1.5
        end
        x = x.floor
        x = 1 if x < 1
        res = Result.new(nil, false, base, rate, base > 0 ? rate.to_f / base : 1.0, st, probe.writes.key?(:status), b, x)
        # :61
        if x >= 255 || ::BallHandlers.isUnconditional?(ball, battle, probe)
          res.chance = 1.0
          res.sure = true
          res.why = x >= 255 ? :certain : :unconditional
          return res
        end
        # :63, :97-101: four shake checks, each pbRandom(65536) < y
        y = (65_536 / ((255.0 / x)**0.1875)).floor
        res.shake = (y / 65_536.0)**4
        miss = 1.0 - res.shake
        # :66-74: the last ball (a shiny always caught with it)
        res.last_crit = 0.0
        if sit.count.to_i <= 1
          if pkmn.shiny?
            res.chance = 1.0
            res.sure = true
            res.why = :last_shiny
            return res
          end
          c = x * 6 / 12
          res.last_crit = [c, 256].min / 256.0 if c > 0
          miss *= 1.0 - res.last_crit
        end
        # :79-95: KIF's Critical Captures
        res.kif_crit = 0.0
        if sit.kif_crits
          c = x * kif_k(sit.owned.to_i) / 12
          res.kif_crit = [c, 256].min / 256.0 if c > 0
          miss *= 1.0 - res.kif_crit
        end
        res.chance = 1.0 - miss
        return res
      rescue Unsafe => e
        Reloaded::Log.info("Catch chance: #{ball}'s handler tried #{e.message} (shown as ?)", FEATURE)
        return Result.new(nil, false, base, nil, nil, nil, false, nil, nil, nil, nil, nil, :unsafe, e.message)
      rescue StandardError => e
        Reloaded::Log.exception("Catch chance: #{ball} couldn't be worked out", e, FEATURE)
        return Result.new(nil, false, base, nil, nil, nil, false, nil, nil, nil, nil, nil, :error, "#{e.class}: #{e.message}")
      end

      #------------------------------------------------------------------------
      # Words and colours
      #------------------------------------------------------------------------
      # A whole percent that never rounds up to a sure thing (his pick); "~"
      # in front while the maths is an estimate
      def percent(res)
        return "?" if res.nil? || res.chance.nil?
        words = if res.sure then "100%"
                elsif res.chance * 100.0 < 1 then "<1%"
                elsif res.chance * 100.0 >= 99.5 then "99%"
                else "#{(res.chance * 100.0).round}%"
                end
        return estimate? && !res.sure ? "~" + words : words
      end

      def mult_text(m)
        return nil if m.nil?
        return "x" + format("%.2f", m).sub(/0+\z/, "").sub(/\.\z/, "")
      end

      # HR's bands (his pick): red under 25%, gold under 50%, green from 50%
      def tone(res)
        return :dim if res.nil? || res.chance.nil?
        return :green if res.sure || res.chance >= 0.5
        return :gold if res.chance >= 0.25
        return :red
      end
    end
  end
end
