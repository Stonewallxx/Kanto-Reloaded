# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Trainer Control's toasts
#==============================================================================
# His picks (Roadmap Designs topic trainer-control, 2026-10-31):
#
#   The record   Design 1, Record Line: Kanto Reloaded's toast with their
#                face and name, your record with them (green ahead, red
#                behind), then pills: STREAK 3 (gold, from 3), their next
#                bond step (TUTOR AT 7, blue: trainers you can battle
#                again), PINK SLIP (pink) when you hold one and they'd
#                wager. When they spot you (their event starts: the "!",
#                as they walk over) or you talk to them; nothing on a first
#                meeting; gone before the battle's transition (a toast up
#                as a battle starts would sit over it).
#   The streak   The same toast with the gold coin and a second line, when
#                your overall win streak (the Trainer Card's) reaches 10:
#                "Word of your streak spreads... Leaders are ready for
#                you." Shown back on the map after that battle.
#
# Who an event battles is read from its own commands: the game's
# pbTrainerBattle and pbDoubleTrainerBattle calls (the trainer's class and
# name), the event's scripts and conditions. An event that battles more
# than one person (a choice of opponents) shows none.
#==============================================================================

return unless defined?(Reloaded::Toast)

module Reloaded
  module TrainerControl
    module Toasts
      BATTLE = /pb(?:Double)?TrainerBattle\(\s*(?:PBTrainers::|:)(\w+)\s*,\s*["']([^"']+)["']/
      STREAK_PILL = 3                   # the STREAK pill from 3 wins in a row
      LEADERS_READY = 10                # your overall streak when leaders get ready
      P = Reloaded::Pixel
      PF = ::KIF::PixelFont

      class << self
        attr_reader :sprite

        def install
          h = Reloaded::Hooks
          h.prepend(nil, ::Interpreter, EventWatch, :id => :trainer_control_toast) if defined?(::Interpreter)
          if TrainerControl.defined_method?(::Object, :pbBattleAnimation)
            h.around(nil, ::Object, :pbBattleAnimation, :id => :trainer_control_toast_gone) do |original, *args|
              Reloaded::TrainerControl::Toasts.gone
              original.call(*args)
            end
          end
          Reloaded::Events.on(:trainer_battle_ended, :trainer_control_streak, 110) { |c| Reloaded::TrainerControl::Toasts.streak_check(c) }
        end

        #----------------------------------------------------------------------
        # Who an event battles
        #----------------------------------------------------------------------
        # Its scripts (a call and its continued lines) and its conditions'
        def scripts(list)
          out = []
          Array(list).each do |cmd|
            case cmd.code
            when 355 then out << cmd.parameters[0].to_s
            when 655 then out[-1] = "#{out[-1]}#{cmd.parameters[0]}" if out[-1]
            when 111 then out << cmd.parameters[1].to_s if cmd.parameters[0] == 12
            end
          end
          return out
        end

        # { person => [class, name] }, each person once
        def people_in(list)
          found = {}
          scripts(list).each do |s|
            next unless s.include?("TrainerBattle")
            s.scan(BATTLE) do |type, name|
              key = TrainerControl.person_key(type, name)
              found[key] ||= [type, name] if key
            end
          end
          return found
        end

        # An event the player set off (talking, touching, or a trainer who
        # saw them), not a parallel or autorun one
        def event_started(list, event_id)
          return if event_id.to_i <= 0 || list.nil? || !$game_map || !Records.data
          ev = ($game_map.events[event_id] rescue nil)
          return unless ev && ev.trigger.to_i < 3
          people = people_in(list)
          return unless people.length == 1
          rec = Records.get(people.keys[0])
          record(rec) if rec && Records.battles(rec) > 0
        rescue StandardError => e
          Reloaded::Log.warning_once("Trainer Control's record toast couldn't be shown: #{e.message}", :trainer_control)
        end

        #----------------------------------------------------------------------
        # The record toast
        #----------------------------------------------------------------------
        def pills(rec)
          out = []
          out << [_INTL("STREAK {1}", rec["streak"].to_i), :gold] if rec["streak"].to_i >= STREAK_PILL
          if Bond.can_reach?(rec)
            kind, at, _left = Bond.next_step(rec)
            out << [_INTL("{1} AT {2}", Bond.word(kind).upcase, at), :blue]
          end
          out << [_INTL("PINK SLIP"), :pink] if defined?(PinkSlips) && PinkSlips.offered?(rec)
          return out
        end

        # The toast's end: the record, then the pills
        def paint(rec)
          w = rec["wins"].to_i
          l = rec["losses"].to_i
          wl = "#{w}-#{l}"
          ww = P.width(PF::TEXT, wl)
          list = pills(rec)
          widths = list.map { |label, _k| P.width(PF::TINY, label) + 12 }
          width = ww + (list.empty? ? 0 : 8 + widths.sum + 5 * (list.length - 1))
          return [width, proc do |b, x0, y0, c|
            col = w > l ? c[:green] : (w < l ? c[:red] : c[:txt])
            P.text(b, x0, y0 - 1, ww + 2, 18, wl, col, PF::TEXT)
            x = x0 + ww + 8
            list.each_with_index do |(label, key), i|
              fill, tone = Reloaded::Toast.pill_colours(c, key)
              P.pill(b, x, y0, label, fill, tone, false)
              x += widths[i] + 5
            end
          end]
        end

        def record(rec)
          face = Pictures.face(rec["type"])
          shown = Reloaded::Toast.show(Records.title(rec), :icon => face, :paint => paint(rec))
          @sprite = shown ? Reloaded::Toast.sprite : nil
          return shown
        ensure
          face.dispose if face && !face.disposed?
        end

        # Before a battle's transition: the record toast goes (another
        # feature's toast stays)
        def gone
          s = Reloaded::Toast.sprite
          Reloaded::Toast.dispose if @sprite && s && s.equal?(@sprite)
          @sprite = nil
        end

        #----------------------------------------------------------------------
        # The streak toast
        #----------------------------------------------------------------------
        def streak_check(context)
          return unless context[:won] && defined?(Reloaded::TrainerCard::Counters)
          @streak_due = true if Reloaded::TrainerCard::Counters.get(:streak).to_i == LEADERS_READY
        end

        def after_battle
          return unless @streak_due
          @streak_due = false
          streak
        end

        def streak
          return Reloaded::Toast.show(_INTL("Word of your streak spreads..."), :coin => LEADERS_READY.to_s,
                                      :sub => _INTL("Leaders are ready for you."))
        end
      end

      # The game setting an event off (Interpreter#setup)
      module EventWatch
        def setup(*args)
          ret = super
          Reloaded::TrainerControl::Toasts.event_started(args[0], args[1])
          ret
        end
      end
    end
  end
end
