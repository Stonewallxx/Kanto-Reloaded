# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Trainer Control
#==============================================================================
# Roadmap topic trainer-control, redesigned with him 2026-10-30 to 31 (every
# pick: Documentation/TrainerControl.md). Always on with Kanto Reloaded, no
# switch (his pick); each part gets its own row per save. Built in stages:
# the records (here and Records.rb), the Battle Records screen
# (UI/BattleRecordsScreen.rb) and the toasts (Toasts.rb), the bond steps
# (Bond.rb), Level Scaling (LevelScaling.rb), Team Expansion and the gyms
# (TeamExpansion.rb), Adaptation (Adaptation.rb), Pink Slips (PinkSlips.rb).
#
#   Who        A person is their class and name (Youngster Joey), every
#              version of them together. Your rival is one person, "rival":
#              PIF's RIVAL_NAMES classes (RIVAL1, RIVAL2, CHAMPION, named by
#              variable 12). Kinds: leaders (Gym Leaders, the Elite Four,
#              other Champions, Rocket bosses), the rival, trainers.
#   Which      Every trainer from the game's data (pbLoadTrainer tags it),
#              battles you may lose too, and trainers an event builds with a
#              class (customTrainerBattle). Not other mods' runtime trainers
#              (GhostNPC's wanderers: nothing tags them), KIF's Self-Battle,
#              the Endgame Challenge's maps, the battle facilities, link or
#              Multiplayer battles. A double gives each trainer a result.
#   The event  :trainer_battle_ended after every trainer battle, counted or
#              not, for the Trainer Card's counts too (one place counts):
#              { :battle, :won (true / false / nil), :people (counted keys) }
#
#   Reloaded::TrainerControl.person(trainer)      # "YOUNGSTER|Joey", "rival" or nil
#   Reloaded::TrainerControl::Records.get(key)    # the person's record (Records.rb)
#==============================================================================

module Reloaded
  module TrainerControl
    SECTION = :trainer_control
    TAG = :@kr_tc                         # on a trainer that counts: { "type", "name", "version", "source" }
    RIVAL = "rival"
    LEADER = /\A(LEADER_|ELITEFOUR|CHAMPION|ROCKETBOSS)/   # (CHAMPION itself is the rival's: checked first)
    REMATCH_SWITCH = 200                  # PIF's, on during a rematch (Trainers Rebattle.rb)
    PAGE = :trainer_control

    @event_built = 0                      # inside customTrainerBattle

    class << self
      attr_accessor :event_built

      def boot
        # Always on (a core part: no switch); it takes cody's Gym Leader
        # teams over, so KIF hides his rows (TeamExpansion.rb)
        Reloaded::Features.register(:trainer_control, :name => "Trainer Control", :core => true, :order => 49,
          :takes_over => ["C-GYM-01_LeaderTeams"]) if defined?(Reloaded::Features)
        Reloaded::SaveStore.register(SECTION)
        Records.boot
        install
        Toasts.install if defined?(Toasts)
        register_settings if defined?(Reloaded::Settings)
        LevelScaling.install if defined?(LevelScaling)
        TeamExpansion.install if defined?(TeamExpansion)
        Adaptation.install if defined?(Adaptation)
        Bond.install if defined?(Bond)
        PinkSlips.install if defined?(PinkSlips)
        register_menu_entries
        return true
      end

      #------------------------------------------------------------------------
      # The Battle Records screen: its row, the Overworld Menu, the Trainer
      # Card's Records side
      #------------------------------------------------------------------------
      def register_settings
        s = Reloaded::Settings
        s.register_page(PAGE, :group => :general, :name => "Trainer Control", :icon => :features, :priority => 49.5,
          :description => "Trainers that keep up with you, learn from you, and remember you.")
        s.register(:"trainer_control.records", :page => PAGE, :priority => 10, :type => :button, :scope => :save, :preset => false,
          :name => "Battle Records", :on_press => proc { Reloaded::TrainerControl.open_records },
          :description => "Every trainer you've battled: Your record with them, their last team, your bond and the MVPs.")
      end

      def register_menu_entries
        return unless defined?(Reloaded::OverworldMenu)
        Reloaded::OverworldMenu.register(:battle_records, :name => "Battle Records", :kind => :action, :priority => 76, :home => false,
          :description => "Every trainer you've battled: Your record with them, their last team, your bond and the MVPs.",
          :handler => proc { |menu| open_records; menu.refresh rescue nil; nil })
      end

      def open_records
        return false unless defined?(Reloaded::BattleRecordsScreen) && Records.data
        Reloaded::BattleRecordsScreen.open
        return true
      rescue StandardError => e
        Reloaded::Log.exception("Battle Records couldn't open", e, :trainer_control)
        return false
      end

      # The screen's sort, kept with the save's records
      def sort
        d = Records.data
        return d ? d["sort"].to_i % Records::SORTS.length : 0
      end

      def sort=(v)
        d = Records.data
        d["sort"] = v.to_i % Records::SORTS.length if d
      end

      #------------------------------------------------------------------------
      # A trainer's team as it's loaded (after PIF's to_trainer and every KIF
      # wrapper): Team Expansion adds to it, Adaptation changes it, Level
      # Scaling raises it last
      #------------------------------------------------------------------------
      def build_team(trainer, type, name, version)
        return unless defined?(LevelScaling) && LevelScaling.scaled? && Records.data
        TeamExpansion.apply(trainer, type, name, version) if defined?(TeamExpansion)
        Adaptation.apply(trainer, type, name, version) if defined?(Adaptation)
        LevelScaling.apply(trainer, type, name, version)
      end

      #------------------------------------------------------------------------
      # What a trainer's event and class say
      #------------------------------------------------------------------------
      # The running event offers rematches: one of its pages turns PIF's
      # rematch switch on (187 pages on 54 maps do)
      def rematch_event?
        interp = (pbMapInterpreter rescue nil)
        id = interp ? interp.instance_variable_get(:@event_id).to_i : 0
        return false if id <= 0 || !$game_map
        ev = ($game_map.events[id] rescue nil)
        data = ev ? ev.instance_variable_get(:@event) : nil
        return false unless data && data.respond_to?(:pages)
        return Array(data.pages).any? do |pg|
          Array(pg.list).any? do |cmd|
            cmd.code == 121 && cmd.parameters[0].to_i <= REMATCH_SWITCH && cmd.parameters[1].to_i >= REMATCH_SWITCH && cmd.parameters[2] == 0
          end
        end
      rescue StandardError
        return false
      end

      # A class's own type (the plate's colour; later, what it adds): a Gym
      # Leader's gym, the Randomizer's class theme, PIF's favourite types,
      # else what their last team used most
      def theme_type(type, team = nil)
        sym = type.to_s.to_sym
        if type.to_s.start_with?("LEADER_") && defined?(::KIF::LeaderTeams) && ::KIF::LeaderTeams.respond_to?(:gym_type)
          t = (::KIF::LeaderTeams.gym_type(sym, []) rescue nil)
          return t if t
        end
        th = defined?(::KIF::Rand::CLASS_THEMES) ? ::KIF::Rand::CLASS_THEMES[sym] : nil
        return th[0] if th.is_a?(Array) && th[0]
        fav = (::BattledTrainer::TRAINER_CLASS_FAVORITE_TYPES[sym] rescue nil)
        return fav[0] if fav.is_a?(Array) && fav[0]
        counts = Hash.new(0)
        Array(team).each do |sp, _lv|
          d = (::GameData::Species.get(sp.to_s.to_sym) rescue nil)
          [d.type1, d.type2].compact.uniq.each { |t| counts[t] += 1 } if d
        end
        return counts.empty? ? nil : counts.max_by { |_t, n| n }[0]
      end

      #------------------------------------------------------------------------
      # Who a trainer is
      #------------------------------------------------------------------------
      def rival_class?(type)
        return false if type.nil? || !defined?(::Settings::RIVAL_NAMES)
        return ::Settings::RIVAL_NAMES.any? { |t, _var| t.to_s == type.to_s }
      end

      def kind(type)
        return :rival if rival_class?(type)
        return :leader if type.to_s =~ LEADER
        return :trainer
      end

      def person_key(type, name)
        return RIVAL if rival_class?(type)
        return nil if type.to_s.empty? || name.to_s.empty?
        return "#{type}|#{name}"
      end

      # A trainer in a battle (an NPCTrainer): its person, or nil when it
      # doesn't count
      def person(trainer)
        tag = trainer ? (trainer.instance_variable_get(TAG) rescue nil) : nil
        return tag ? person_key(tag["type"], tag["name"]) : nil
      end

      def tag(trainer, name, version, source)
        return unless trainer && trainer.respond_to?(:trainer_type)
        trainer.instance_variable_set(TAG, { "type" => trainer.trainer_type.to_s, "name" => name.to_s,
                                             "version" => version.to_i, "source" => source })
      rescue StandardError
        nil
      end

      # customTrainerBattle's trainer, built by an event: counted by its class
      # and name when the class is a real one
      def tag_event_built(args)
        args.each do |tr|
          next unless tr.respond_to?(:trainer_type) && tr.instance_variable_get(TAG).nil?
          next unless (::GameData::TrainerType.exists?(tr.trainer_type) rescue false)
          tag(tr, tr.name, 0, "event")
        end
      end

      #------------------------------------------------------------------------
      # Which battles count
      #------------------------------------------------------------------------
      def counted_battle?(battle)
        return false unless (battle.trainerBattle? rescue false)
        return false unless battle.instance_variable_get(:@internalBattle)
        return false if (pbBattleChallenge.pbInChallenge? rescue false)
        return false if battle.class.name.to_s =~ /Multiplayer|Coop|PvP|Online|Sandbox/i
        return false if defined?(::KIF::SelfBattle) && (::KIF::SelfBattle.active rescue false)
        return false if defined?(::KIF::Endgame) && ((::KIF::Endgame.on? && ::KIF::Endgame.challenge_map?) rescue false)
        return true
      end

      def battle_ended(battle)
        return unless (battle.trainerBattle? rescue false)
        won = case battle.instance_variable_get(:@decision)
              when 1 then true
              when 2 then false
              end
        people = []
        begin
          people = Records.battle_ended(battle, won) if !won.nil? && counted_battle?(battle)
        rescue StandardError => e
          Reloaded::Log.exception("Trainer Control couldn't record a battle", e, :trainer_control)
        end
        Reloaded::Events.emit(:trainer_battle_ended, :battle => battle, :won => won, :people => people)
      end

      #------------------------------------------------------------------------
      # Hooks (core: always on)
      #------------------------------------------------------------------------
      def defined_method?(klass, name)
        return klass.method_defined?(name) || klass.private_method_defined?(name)
      end

      def install
        h = Reloaded::Hooks
        if defined_method?(::Object, :pbLoadTrainer)
          h.around(nil, ::Object, :pbLoadTrainer, :id => :trainer_control_load) do |original, *args|
            trainer = original.call(*args)
            Reloaded::TrainerControl.tag(trainer, args[1], args[2] || 0, "data")
            Reloaded::TrainerControl.build_team(trainer, args[0], args[1], args[2] || 0)
            trainer
          end
        end
        if defined_method?(::Object, :customTrainerBattle)
          h.around(nil, ::Object, :customTrainerBattle, :id => :trainer_control_event_built) do |original, *args|
            Reloaded::TrainerControl.event_built += 1
            begin
              original.call(*args)
            ensure
              Reloaded::TrainerControl.event_built -= 1
            end
          end
        end
        if defined_method?(::Object, :pbTrainerBattleCore)
          h.around(nil, ::Object, :pbTrainerBattleCore, :id => :trainer_control_battle) do |original, *args|
            Reloaded::TrainerControl.tag_event_built(args) if Reloaded::TrainerControl.event_built > 0
            te = defined?(Reloaded::TrainerControl::TeamExpansion) ? Reloaded::TrainerControl::TeamExpansion : nil
            was = te ? te.trainers_in_battle : nil
            te.trainers_in_battle = args.length if te
            pink = defined?(Reloaded::TrainerControl::PinkSlips) ? Reloaded::TrainerControl::PinkSlips : nil
            pink.before_battle(args) if pink
            begin
              ret = original.call(*args)
            ensure
              te.trainers_in_battle = was if te
            end
            pink.after_battle if pink
            Reloaded::TrainerControl::Toasts.after_battle if defined?(Reloaded::TrainerControl::Toasts)
            Reloaded::TrainerControl::Bond.after_battle
            ret
          end
        end
        if defined?(::PokeBattle_Battle) && defined_method?(::PokeBattle_Battle, :pbEndOfBattle)
          h.around(nil, ::PokeBattle_Battle, :pbEndOfBattle, :id => :trainer_control_battle_end) do |original, *args|
            Reloaded::TrainerControl.battle_ended(original.receiver)
            original.call(*args)
          end
        end
        if defined?(::PokeBattle_Battler) && defined_method?(::PokeBattle_Battler, :pbFaint)
          h.prepend(nil, ::PokeBattle_Battler, FaintWatch, :id => :trainer_control_kos)
        end
      end
    end

    # Who knocked out whom, for the record's MVPs: read before the game's
    # pbFaint clears the battler's last attackers (pbInitEffects). Once per
    # faint.
    module FaintWatch
      def pbFaint(*args)
        Reloaded::TrainerControl::Records.fainted(self) if fainted? && !@fainted
        super
      end
    end
  end
end
