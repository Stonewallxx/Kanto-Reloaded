# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Trainer Control with Hoenn Essentials (TheMagnumChad's)
#==============================================================================
# Hoenn Essentials (Mods/hoenn_essentials, 00_trainer_rematches.rb) makes an
# ordinary trainer you beat a contact: it keeps a copy of their team, and its
# Rematch button battles them with that copy. After each rematch the copy
# grew (+2 levels a win, +1 a loss, up to your best + 3, learning moves and
# evolving), and now and then the trainer catches, fuses or unfuses a
# Pokémon. Its View Team, trades, Recruit Partner and chat read that copy.
#
# His picks (2026-11-14): its roster, Trainer Control's levels. Hoenn
# Essentials decides who's on the team (its catches, fusions, evolutions,
# trades); Trainer Control decides how strong (one curve):
#
#   Rematches   its Rematch counts as a rematch everywhere in Trainer
#               Control (TrainerControl.rematch_battle?): the rematch levels
#               (Rematch Ranks' levels past you included), Records' rematch
#               count, half EXP, Rematch Money (PIF pays nothing in a rematch,
#               so its payout runs as PIF's own rematch would; PIF's own
#               rematch count untouched)
#   Its copy    the trainer's written team (Trainer Control doesn't build
#               while it registers a contact)
#   Battles     Trainer Control builds after its swap (it loads after Kanto
#               Reloaded by folder name, so its swap used to throw Trainer
#               Control's work away), on full copies: its own copies share
#               moves, IVs and EVs with the team it keeps
#   Growth      its +2 / +1 is replaced by Trainer Control's level for the
#               next rematch (Notoriety's Infamous levels in it): up through
#               its own growth (moves, evolutions, its chat), down by
#               lowering, so View Team shows the levels you'll fight
#   From before contacts lose Trainer Control's marks, the Pokémon Team
#               Expansion added, and levels past the curve (a save loading)
#   Arguments   its pbTrainerBattle hook passes on 7 of the game's 11
#               arguments, so a battle's name and trainer type overrides
#               were lost: KIF's 8 lounge battles (Kin Island, the Triple
#               Battle Lounge, Mt. Ember, Mt. Silver Summit) showed
#               "lounge_member" and the wrong class. Carried past it. (Its
#               event and map arguments only matter to PIF's Hoenn game.)
#
# Linked once every mod has loaded (:system_ready), so it works whichever
# order the two load in.
#==============================================================================

module Reloaded
  module TrainerControl
    module HoennEssentials
      # Trainer Control's marks on a loaded Pokémon that describe one build
      STALE = [:@kr_tc_adapted, :@kr_tc_built, :@kr_tc_from, :@kr_tc_slot].freeze
      ADDED = :@kr_tc_added

      @raw = 0
      @growing = 0
      @carry = []

      class << self
        def install
          link
          Reloaded::Events.on(:system_ready, :trainer_control_hoenn, 50) { link }
          Reloaded::Events.on(:save_loaded, :trainer_control_hoenn, 65) { clean_contacts }   # (after Records, 61)
          return true
        end

        def here?
          return defined?(::HoennTrainerRematches) && ::HoennTrainerRematches.respond_to?(:active_rematch) &&
                 ::HoennTrainerRematches.respond_to?(:register) ? true : false
        end

        def link
          return false if @linked || !here?
          h = Reloaded::Hooks
          he = ::HoennTrainerRematches.singleton_class
          # its contacts get the written team, at Trainer Control's level
          h.around(nil, he, :register, :id => :trainer_control_hoenn_register) do |original, *args|
            hes = Reloaded::TrainerControl::HoennEssentials
            had = (::HoennTrainerRematches.contact(args[3], args[4]) rescue nil)
            entry = hes.raw { original.call(*args) }
            hes.sync(entry) if entry && !had
            entry
          end
          # its growth: Trainer Control's level for the next rematch
          if TrainerControl.defined_method?(he, :grow_team)
            h.around(nil, he, :grow_team, :id => :trainer_control_hoenn_grow) do |original, entry, *_rest|
              Reloaded::TrainerControl::HoennEssentials.grow(entry) { |d| original.call(entry, d) }
            end
          end
          # over its swap, wherever it loaded: Trainer Control builds the team
          # it swapped in
          h.around(nil, ::Object, :pbLoadTrainer, :id => :trainer_control_hoenn_rematch) do |original, *args|
            trainer = original.call(*args)
            Reloaded::TrainerControl::HoennEssentials.after_swap(trainer, args)
            trainer
          end
          # its rematch pays as PIF's own: nothing (Rematch Money pays its share)
          if defined?(::PokeBattle_Battle) && TrainerControl.defined_method?(::PokeBattle_Battle, :pbGainMoney)
            h.around(nil, ::PokeBattle_Battle, :pbGainMoney, :id => :trainer_control_hoenn_money) do |original, *args|
              Reloaded::TrainerControl::HoennEssentials.paid_as_rematch { original.call(*args) }
            end
          end
          # the name and class overrides, past its pbTrainerBattle
          if TrainerControl.defined_method?(::Object, :pbTrainerBattle)
            h.around(nil, ::Object, :pbTrainerBattle, :id => :trainer_control_hoenn_args) do |original, *args|
              Reloaded::TrainerControl::HoennEssentials.carrying(args) { original.call(*args) }
            end
          end
          if TrainerControl.defined_method?(::Object, :pbTrainerBattleCore)
            h.around(nil, ::Object, :pbTrainerBattleCore, :id => :trainer_control_hoenn_core) do |original, *args|
              original.call(*Reloaded::TrainerControl::HoennEssentials.restore(args))
            end
          end
          @linked = true
          clean_contacts
          Reloaded::Log.info("Trainer Control: linked to Hoenn Essentials' trainer rematches", :trainer_control)
          return true
        end

        def linked?
          return @linked ? true : false
        end

        #----------------------------------------------------------------------
        # Its rematches
        #----------------------------------------------------------------------
        # Its Rematch button's battle is on (or its growth after one)
        def rematch_now?
          return false unless linked?
          return true if @growing > 0
          return ::HoennTrainerRematches.active_rematch.is_a?(Hash)
        rescue StandardError
          return false
        end

        # Its rematch for this trainer is on (its own test: class, name and
        # version, a team kept)
        def rematch_for?(args)
          return false unless here?
          entry = ::HoennTrainerRematches.active_rematch
          return false unless entry.is_a?(Hash)
          team = entry[:team]
          return false unless team.is_a?(Array) && !team.empty?
          return entry[:trainer_type] == args[0] && entry[:trainer_name] == args[1] &&
                 entry[:trainer_version].to_i == (args[2] || 0).to_i
        rescue StandardError
          return false
        end

        # PIF pays nothing in its own rematches (its rematch switch): its
        # payout runs so here too, then Rematch Money pays its share
        def paid_as_rematch
          sw = TrainerControl::REMATCH_SWITCH
          return yield unless rematch_now? && $game_switches && !$game_switches[sw]
          $game_switches[sw] = true
          begin
            return yield
          ensure
            $game_switches[sw] = false
          end
        end

        #----------------------------------------------------------------------
        # The team
        #----------------------------------------------------------------------
        # Hoenn Essentials registering a contact: the trainer as written
        def raw
          @raw += 1
          yield
        ensure
          @raw -= 1
        end

        def raw?
          return @raw > 0
        end

        # Trainer Control's own pbLoadTrainer hook builds the team, unless
        # Hoenn Essentials is registering, or about to swap in its own
        def skip_build?(args)
          return false unless linked?
          return raw? || rematch_for?(args)
        end

        # After its swap: full copies of its team, cleaned, then built (its
        # Pokémon keep their place in the written team from when it was
        # registered; one it caught or fused has none)
        def after_swap(trainer, args)
          return unless trainer && trainer.respond_to?(:party) && trainer.respond_to?(:party=) && rematch_for?(args)
          party = Array(trainer.party).compact.map { |pk| Marshal.load(Marshal.dump(pk)) }
          trainer.party = clean(party)
          TrainerControl.build_team(trainer, args[0], args[1], args[2] || 0)
        rescue StandardError => e
          Reloaded::Log.exception("Trainer Control couldn't build a Hoenn Essentials rematch team", e, :trainer_control)
        end

        # Trainer Control's marks off, and the Pokémon it added gone
        def clean(team)
          team = Array(team).reject { |pk| pk.instance_variable_get(ADDED) }
          team.each do |pk|
            STALE.each { |iv| pk.remove_instance_variable(iv) if pk.instance_variable_defined?(iv) }
          end
          return team
        end

        # How far its kept team moves for the next rematch: Trainer Control's
        # level for it (its ace there, the rest keeping their gaps, as Level
        # Scaling raises a team), Infamous's levels in it; 0 when Trainer
        # Control leaves the team as it is
        def level_change(entry)
          return 0 unless entry.is_a?(Hash) && Records.data
          team = Array(entry[:team]).compact
          return 0 if team.empty?
          type = entry[:trainer_type]
          name = entry[:trainer_name]
          key = TrainerControl.person_key(type, name)
          return 0 unless key
          ace = team.map { |pk| pk.level.to_i }.max
          data = (::GameData::Trainer.try_get(type, name, entry[:trainer_version].to_i).pokemon rescue nil)
          @growing += 1
          begin
            to = LevelScaling.target(TrainerControl.kind(type), key, ace, LevelScaling.own_ace(data))
          ensure
            @growing -= 1
          end
          return 0 if to.nil?
          to += Notoriety.extra_levels if defined?(Notoriety) && Notoriety.on?
          max = defined?(::Settings::MAXIMUM_LEVEL) ? ::Settings::MAXIMUM_LEVEL : 100
          return [to, max].min - ace
        end

        # In place of its growth after a rematch: up through its own (it
        # learns the moves and evolves, and says so), down by lowering
        def grow(entry)
          d = level_change(entry)
          if d > 0
            yield d
          elsif d < 0
            lower(entry, d)
          end
        rescue StandardError => e
          Reloaded::Log.exception("Trainer Control couldn't set a Hoenn Essentials contact's levels", e, :trainer_control)
        end

        def lower(entry, d)
          Array(entry[:team]).compact.each do |pk|
            lv = [pk.level.to_i + d, 1].max
            next if lv == pk.level.to_i
            pk.level = lv
            pk.calc_stats if pk.respond_to?(:calc_stats)
          end
        end

        # Its kept team to Trainer Control's level for the next rematch, with
        # no word of it in its chat (a new contact, a save loading): View
        # Team shows the levels you'll fight
        def sync(entry)
          d = level_change(entry)
          return if d == 0
          if d < 0
            lower(entry, d)
            return
          end
          had = entry.key?(:pending_evolution)
          names = entry[:team_event_names]
          ::HoennTrainerRematches.grow_team(entry, d)
          unless had
            entry.delete(:pending_evolution)
            names.nil? ? entry.delete(:team_event_names) : entry[:team_event_names] = names
          end
        rescue StandardError => e
          Reloaded::Log.exception("Trainer Control couldn't set a Hoenn Essentials contact's levels", e, :trainer_control)
        end

        # Contacts saved before: their kept teams cleaned of Trainer Control's
        # old builds, and at Trainer Control's level (a save loading)
        def clean_contacts
          return 0 unless here? && ::HoennTrainerRematches.respond_to?(:contacts)
          n = 0
          ::HoennTrainerRematches.contacts.each_value do |entry|
            next unless entry.is_a?(Hash) && entry[:team].is_a?(Array)
            team = entry[:team]
            if team.any? { |pk| pk.instance_variable_get(ADDED) || STALE.any? { |iv| pk.instance_variable_defined?(iv) } }
              entry[:team] = clean(team)
              n += 1
            end
            sync(entry) if linked?
          end
          Reloaded::Log.info("Trainer Control: #{n} Hoenn Essentials contacts' teams cleaned of its old builds", :trainer_control) if n > 0
          return n
        rescue StandardError => e
          Reloaded::Log.exception("Trainer Control couldn't clean Hoenn Essentials' contacts", e, :trainer_control)
          return 0
        end

        #----------------------------------------------------------------------
        # The arguments
        #----------------------------------------------------------------------
        # pbTrainerBattle(trainerID, trainerName, endSpeech, doubleBattle,
        # trainerPartyID, canLose, outcomeVar, name_override, type_override, ...)
        def carrying(args)
          name = args[7]
          type = args[8]
          return yield if name.nil? && type.nil?
          @carry.push([args[0], args[1], (args[4] || 0).to_i, name, type])
          begin
            return yield
          ensure
            @carry.pop
          end
        end

        # pbTrainerBattleCore([id, name, version, endSpeech, name_override,
        # type_override]): what Hoenn Essentials' hook dropped, back in (the
        # game's one-trainer call only: its call for two trainers spotting
        # you passes no overrides, as it always has)
        def restore(args)
          c = @carry.last
          return args unless c
          return args.map do |a|
            next a unless a.is_a?(Array) && a.length >= 6 && a[0] == c[0] && a[1] == c[1] && (a[2] || 0).to_i == c[2]
            next a unless a[4].nil? && a[5].nil?
            b = a.dup
            b[4] = c[3]
            b[5] = c[4]
            b
          end
        end
      end
    end
  end
end
