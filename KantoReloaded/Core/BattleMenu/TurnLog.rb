# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Turn Log
#==============================================================================
# What happened each turn of this battle (his picks, Q16-Q18): a row per
# event with result badges, kept on the battle and gone with it. Battle
# Info's Turn Log tab shows it, the latest turn first.
#
#   a move     who used it, the move (in its type's colour), at whom; the
#              damage (a foe's in %, as its HP bar shows it; yours in HP),
#              x4 / x1/2 / NO EFFECT, CRIT, MISSED, FAILED, FAINTED; what it
#              changed: a status, stat stages, the weather, a side's screens
#              or hazards, TRAPPED
#   end of turn  HP lost or gained after the moves (weather, poison, Leech
#              Seed, Leftovers...), named from the battle's message about it
#   switching  who was sent out; fainting outside a move
#
# Each watcher runs after the game's own code and only reads (the battle
# AI's and KIF-ER's damage estimates never use these methods), so a
# multiplayer battle stays the same on every side.
#==============================================================================

module Reloaded
  module BattleMenu
    module TurnLog
      LOG = :@kr_turn_log          # on the battle: { turn => [rows] }
      NOW = :@kr_turn_log_now      # the moves being used (a stack: Metronome calls another)
      EOR = :@kr_turn_log_eor      # the end of turn's rows still to be named
      STARTED = :@kr_turn_log_started
      MAX_PILLS = 4
      STAT_SHORT = { :ATTACK => "ATK", :DEFENSE => "DEF", :SPECIAL_ATTACK => "SPA", :SPECIAL_DEFENSE => "SPD",
                     :SPEED => "SPE", :ACCURACY => "ACC", :EVASION => "EVA" }.freeze

      # A row: { :who => [name, pokemon, own], :words, :type, :plain (dim words),
      #          :target => [name, pokemon, own], :pills => [[label, tone or rgb]] }

      module_function

      def rows(battle)
        return battle.instance_variable_get(LOG) || {}
      end

      # The turn being played: 0 before the first choice (Pokémon sent out)
      def turn(battle)
        return battle.instance_variable_get(STARTED) ? battle.turnCount.to_i + 1 : 0
      end

      def add(battle, row)
        log = battle.instance_variable_get(LOG) || battle.instance_variable_set(LOG, {})
        (log[turn(battle)] ||= []) << row
        return row
      end

      def who(battler)
        return [battler.name.to_s, battler.pokemon, Reader.own?(battler)]
      end

      def pill(row, label, tone)
        row[:pills] << [label, tone] if row[:pills].length < MAX_PILLS && !row[:pills].any? { |l, _t| l == label }
      end

      # HP as the screen shows it: a foe's in %, yours in HP
      def hp_words(battler, amount, sign)
        return "#{sign}#{amount} HP" if Reader.known?(battler.battle, battler)
        pct = (amount * 100.0 / [battler.totalhp, 1].max).round
        return "#{sign}#{[pct, 1].max}%"
      end

      #------------------------------------------------------------------------
      # Snapshots: what a move or the end of turn changed
      #------------------------------------------------------------------------
      def snapshot(battle)
        f = battle.field
        s = { :weather => f.weather, :terrain => f.terrain,
              :field => Reader::FIELD_TIMED.map { |k, _w, _t| Reader.eff(f.effects, k).to_i > 0 },
              :sides => [0, 1].map do |i|
                e = battle.sides[i].effects
                Reader::SIDE_TIMED.map { |k, _w, _t| Reader.eff(e, k).to_i > 0 } +
                  Reader::HAZARDS.map { |k, _w, _t| v = Reader.eff(e, k); v.is_a?(Integer) ? v : (v ? 1 : 0) }
              end,
              :battlers => {} }
        battle.battlers.each do |b|
          next unless b && b.pokemon
          s[:battlers][b.index] = { :pokemon => b.pokemon, :hp => b.hp, :status => b.status,
                                    :stages => b.stages.dup, :confused => Reader.eff(b.effects, :Confusion).to_i > 0,
                                    :trapped => Reader.eff(b.effects, :Trapping).to_i > 0 }
        end
        return s
      end

      # The changes since a snapshot, as badges on the rows (each Pokémon's
      # on its own row when it has one, else on the first)
      def changes(battle, before, rows_by_index, first)
        f = battle.field
        if f.weather != before[:weather] && f.weather && f.weather != :None
          pill(first, Reader.weather_name(f.weather).upcase, :blue)
        end
        if f.terrain != before[:terrain] && f.terrain && f.terrain != :None
          pill(first, Reader.terrain_name(f.terrain).upcase, :blue)
        end
        Reader::FIELD_TIMED.each_with_index do |(k, words, _t), i|
          pill(first, _INTL(words).upcase, :blue) if Reader.eff(f.effects, k).to_i > 0 && !before[:field][i]
        end
        [0, 1].each do |side|
          now = snapshot_side(battle, side)
          next unless now.each_with_index.any? { |v, i| v.is_a?(Integer) ? v > before[:sides][side][i].to_i : (v && !before[:sides][side][i]) }
          mine = side == 0
          pill(first, mine ? _INTL("YOUR SIDE") : _INTL("FOE'S SIDE"), mine ? :green : :red)
        end
        battle.battlers.each do |b|
          next unless b && b.pokemon
          was = before[:battlers][b.index]
          next unless was && was[:pokemon].equal?(b.pokemon)
          row = rows_by_index[b.index] || first
          if b.status != was[:status] && b.status && b.status != :NONE
            st = Reloaded::PartyPaint::STATUS[b.status] if defined?(Reloaded::PartyPaint::STATUS)
            pill(row, st ? st[0] : b.status.to_s, st ? st[1] : :amber)
          end
          pill(row, _INTL("CONFUSED"), :amber) if Reader.eff(b.effects, :Confusion).to_i > 0 && !was[:confused]
          pill(row, _INTL("TRAPPED"), :amber) if Reader.eff(b.effects, :Trapping).to_i > 0 && !was[:trapped]
          Reader::STATS.each do |stat, _l|
            d = b.stages[stat].to_i - was[:stages][stat].to_i
            next if d == 0
            pill(row, "#{d > 0 ? '+' : ''}#{d} #{STAT_SHORT[stat]}", d > 0 ? :green : :red)
          end
        end
      end

      def snapshot_side(battle, side)
        e = battle.sides[side].effects
        return Reader::SIDE_TIMED.map { |k, _w, _t| Reader.eff(e, k).to_i > 0 } +
               Reader::HAZARDS.map { |k, _w, _t| v = Reader.eff(e, k); v.is_a?(Integer) ? v : (v ? 1 : 0) }
      end

      #------------------------------------------------------------------------
      # A move
      #------------------------------------------------------------------------
      def move_started(user, choice)
        battle = user.battle
        move = choice.is_a?(Array) ? choice[2] : nil
        stack = battle.instance_variable_get(NOW) || battle.instance_variable_set(NOW, [])
        stack << { :user => user, :move => move, :who => who(user), :before => snapshot(battle), :targets => nil }
      rescue StandardError => e
        Reloaded::Log.exception("Turn Log: a move starting", e, :battle_menu)
      end

      def targets_found(user, targets)
        now = (user.battle.instance_variable_get(NOW) || []).last
        now[:targets] ||= Array(targets).compact.map { |b| [b, who(b)] } if now && now[:user].equal?(user)
      rescue StandardError
        nil
      end

      def move_ended(user)
        battle = user.battle
        now = (battle.instance_variable_get(NOW) || []).pop
        return unless now
        # not used (asleep, flinched, fully paralyzed...): no row
        used = user.instance_variable_get(:@lastMoveUsed)
        move = now[:move]
        return if used.nil? || move.nil?
        Notes.note_move(user, used)
        move_id = move.respond_to?(:id) ? move.id : used
        type = Reader.calc_type(move, user) rescue nil
        base = { :who => now[:who], :words => (move.name rescue Reader.move_name(move_id)).to_s, :type => type, :pills => [] }
        rows = {}
        list = []
        (now[:targets] || []).each do |b, w|
          next if b.equal?(user) && !(b.damageState.totalHPLost.to_i > 0)
          ds = b.damageState
          row = base.merge(:target => w, :pills => [])
          lost = ds.totalHPLost.to_i
          if ds.missed
            pill(row, _INTL("MISSED"), :dim)
          elsif ds.protected
            pill(row, _INTL("PROTECTED"), :dim)
          elsif lost > 0
            pill(row, hp_words(b, lost, "-"), :red)
            m = ds.typeMod.to_f / Effectiveness::NORMAL_EFFECTIVE
            pill(row, Reader.mult_label(m), m > 1 ? :green : :amber) if m != 1 && m > 0
            pill(row, _INTL("CRIT"), :gold) if ds.critical
            pill(row, _INTL("SUBSTITUTE"), :dim) if ds.substitute
          elsif move.damagingMove? && ds.typeMod.to_i == Effectiveness::INEFFECTIVE
            pill(row, _INTL("NO EFFECT"), :dim)
          end
          rows[b.index] = row
          list << row
        end
        if list.empty?
          list << base.dup
          rows[user.index] ||= list[0]
        end
        pill(list[0], _INTL("FAILED"), :dim) if user.instance_variable_get(:@lastMoveFailed) && list[0][:pills].empty?
        changes(battle, now[:before], rows, list[0])
        Array(now[:fainted]).each do |i|
          row = rows[i]
          if row
            pill(row, _INTL("FAINTED"), :red)
          else
            b = battle.battlers[i]
            list << { :who => who(b), :plain => _INTL("Fainted"), :pills => [[_INTL("FAINTED"), :red]] } if b
          end
        end
        list.each { |r| add(battle, r) }
        now[:rows] = rows
        @last_move_rows = [battle, rows]
      rescue StandardError => e
        Reloaded::Log.exception("Turn Log: a move ending", e, :battle_menu)
      end

      #------------------------------------------------------------------------
      # The end of the turn: HP changes, named from the message about them
      #------------------------------------------------------------------------
      def eor_started(battle)
        battle.instance_variable_set(EOR, { :before => snapshot(battle), :rows => [], :said => {} })
      end

      def eor_ended(battle)
        eor = battle.instance_variable_get(EOR)
        battle.instance_variable_set(EOR, nil)
        return unless eor
        eor[:rows].each { |r| r[:plain] ||= _INTL("End of Turn") }
      rescue StandardError => e
        Reloaded::Log.exception("Turn Log: the end of a turn", e, :battle_menu)
      end

      def hp_changed(battler, amount, sign)
        battle = battler.battle
        return if amount.to_i <= 0
        return if (battle.instance_variable_get(NOW) || []).any?     # a move's: on its row
        eor = battle.instance_variable_get(EOR)
        row = { :who => who(battler), :pills => [[hp_words(battler, amount, sign), sign == "-" ? :red : :green]], :index => battler.index }
        if eor
          said = eor[:said].delete(battler.index)
          row[:plain] = cause(battler, said) if said
          eor[:rows] << row
        else
          row[:plain] = sign == "-" ? _INTL("Lost HP") : _INTL("Restored HP")
        end
        add(battle, row)
      rescue StandardError => e
        Reloaded::Log.exception("Turn Log: an HP change", e, :battle_menu)
      end

      # A battle message: at the end of a turn, it names the HP change about
      # that Pokémon just before it (or the next one)
      def message(battle, msg)
        eor = battle.instance_variable_get(EOR)
        return unless eor && msg.is_a?(String)
        battle.battlers.each do |b|
          next unless b && b.pokemon && (msg.include?(b.pbThis) || msg.include?(b.pbThis(true)))
          row = eor[:rows].reverse.find { |r| r[:index] == b.index }
          if row && row[:plain].nil?
            row[:plain] = cause(b, msg)
          else
            eor[:said][b.index] = msg
          end
        end
      rescue StandardError
        nil
      end

      # What a message says did it: a move, item or ability it names, else
      # the weather or a status, else nil (End of Turn)
      def cause(battler, msg)
        trap = Reader.move_name(Reader.eff(battler.effects, :TrappingMove))
        return _INTL("{1} Damage", trap) if trap && msg.include?(trap)
        return battler.itemName if battler.item && !battler.itemName.to_s.empty? && msg.include?(battler.itemName.to_s)
        return battler.abilityName if battler.ability && !battler.abilityName.to_s.empty? && msg.include?(battler.abilityName.to_s)
        low = msg.downcase
        [[:Sandstorm, "sandstorm"], [:Hail, "hail"], [:ShadowSky, "shadow sky"]].each do |w, word|
          return Reader.weather_name(w) if low.include?(word)
        end
        { "poison" => _INTL("Poison"), "burn" => _INTL("Burn"), "leech seed" => _INTL("Leech Seed"),
          "nightmare" => _INTL("Nightmare"), "curse" => _INTL("Curse"), "sea of fire" => _INTL("Sea of Fire"),
          "aqua ring" => _INTL("Aqua Ring"), "roots" => _INTL("Ingrain"), "wish" => _INTL("Wish"),
          "perish" => _INTL("Perish Song") }.each { |word, label| return label if low.include?(word) }
        return nil
      end

      #------------------------------------------------------------------------
      # Switching and fainting
      #------------------------------------------------------------------------
      def came_in(battle, idx)
        b = battle.battlers[idx]
        return unless b && b.pokemon
        add(battle, { :who => who(b), :plain => _INTL("Sent Out"), :pills => [] })
      rescue StandardError
        nil
      end

      def fainted(battler)
        battle = battler.battle
        now = (battle.instance_variable_get(NOW) || []).last
        if now                    # inside a move: on its row once the move ends
          (now[:fainted] ||= []) << battler.index
          return
        end
        last = @last_move_rows
        if last && last[0].equal?(battle) && (row = last[1][battler.index]) && rows(battle)[turn(battle)].to_a.include?(row)
          pill(row, _INTL("FAINTED"), :red)
          return
        end
        add(battle, { :who => who(battler), :plain => _INTL("Fainted"), :pills => [[_INTL("FAINTED"), :red]] })
      rescue StandardError
        nil
      end

      #------------------------------------------------------------------------
      # The watchers
      #------------------------------------------------------------------------
      def install
        h = Reloaded::Hooks
        tl = self
        if defined?(::PokeBattle_Battle)
          if ::PokeBattle_Battle.method_defined?(:pbCommandPhase)
            h.around(FEATURE, ::PokeBattle_Battle, :pbCommandPhase, :id => :turn_log_turn) do |original, *args|
              original.receiver.instance_variable_set(STARTED, true)
              original.call(*args)
            end
          end
          if ::PokeBattle_Battle.method_defined?(:pbEndOfRoundPhase)
            h.around(FEATURE, ::PokeBattle_Battle, :pbEndOfRoundPhase, :id => :turn_log_end_of_turn) do |original, *args|
              battle = original.receiver
              tl.eor_started(battle)
              begin
                original.call(*args)
              ensure
                tl.eor_ended(battle)
              end
            end
          end
          if ::PokeBattle_Battle.method_defined?(:pbRecallAndReplace)
            h.around(FEATURE, ::PokeBattle_Battle, :pbRecallAndReplace, :id => :turn_log_switch) do |original, *args|
              ret = original.call(*args)
              tl.came_in(original.receiver, args[0])
              ret
            end
          end
        end
        return unless defined?(::PokeBattle_Battler)
        if ::PokeBattle_Battler.method_defined?(:pbUseMove)
          h.around(FEATURE, ::PokeBattle_Battler, :pbUseMove, :id => :turn_log_move) do |original, *args|
            user = original.receiver
            tl.move_started(user, args[0])
            begin
              original.call(*args)
            ensure
              tl.move_ended(user)
            end
          end
        end
        if ::PokeBattle_Battler.method_defined?(:pbChangeTargets)
          h.around(FEATURE, ::PokeBattle_Battler, :pbChangeTargets, :id => :turn_log_targets) do |original, *args|
            ret = original.call(*args)
            tl.targets_found(original.receiver, ret)
            ret
          end
        end
        [[:pbReduceHP, "-"], [:pbRecoverHP, "+"]].each do |m, sign|
          next unless ::PokeBattle_Battler.method_defined?(m)
          h.around(FEATURE, ::PokeBattle_Battler, m, :id => :"turn_log_#{m}") do |original, *args|
            ret = original.call(*args)
            tl.hp_changed(original.receiver, ret, sign) if ret.is_a?(Integer)
            ret
          end
        end
        if ::PokeBattle_Battler.method_defined?(:pbFaint)
          h.around(FEATURE, ::PokeBattle_Battler, :pbFaint, :id => :turn_log_faint) do |original, *args|
            b = original.receiver
            was = b.instance_variable_get(:@fainted)
            ret = original.call(*args)
            tl.fainted(b) if !was && b.instance_variable_get(:@fainted)
            ret
          end
        end
      end
    end
  end
end
