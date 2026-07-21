#==============================================================================
# Kanto Reloaded - Trainer Control
#==============================================================================

module KantoReloaded
  module TrainerControl
    SETTINGS_ACTION = :trainer_control_settings
    MODULE_ID = :trainer_control

    class LevelOffsetAction < KantoReloaded::Options::ActionButton
      def initialize(scene)
        @scene = scene
        super(
          _INTL("Level Offset"),
          proc { choose_offset },
          _INTL("Set the trainer scaling offset from -99 through +99.")
        )
      end

      def name
        _INTL(
          "Level Offset < {1} >",
          KantoReloaded::TrainerControl::LevelScaling.formatted_offset
        )
      end

      def disabled?
        !KantoReloaded::TrainerControl::LevelScaling.enabled?
      end

      private

      def choose_offset
        current = KantoReloaded::TrainerControl::LevelScaling.level_offset
        selected = KantoReloaded::NumberPicker.open(
          _INTL("Level Offset"),
          :min => -99,
          :max => 99,
          :initial => current,
          :digits => 2,
          :label => _INTL("Trainer level adjustment")
        )
        return if selected.nil?
        KantoReloaded::Settings.set(
          KantoReloaded::TrainerControl::LevelScaling::OFFSET_SETTING,
          selected.to_i
        )
        @scene.sync_window_values if @scene.respond_to?(:sync_window_values)
      end
    end

    class ExpansionSizeAction < KantoReloaded::Options::ActionButton
      def initialize(scene)
        @scene = scene
        super(
          _INTL("Team Expansion Size"),
          proc { choose_size },
          _INTL("Set how many Pokemon are added or the target trainer team size.")
        )
      end

      def name
        if TeamExpansion.size_mode == TeamExpansion::SIZE_TARGET
          _INTL("Target Team Size < {1} >", TeamExpansion.target_size)
        else
          _INTL("Add Pokemon < {1} >", TeamExpansion.add_count)
        end
      end

      def disabled?
        !TeamExpansion.enabled?
      end

      private

      def choose_size
        target_mode = TeamExpansion.size_mode == TeamExpansion::SIZE_TARGET
        key = target_mode ? TeamExpansion::TARGET_SIZE_SETTING :
                            TeamExpansion::ADD_COUNT_SETTING
        current = target_mode ? TeamExpansion.target_size : TeamExpansion.add_count
        selected = KantoReloaded::NumberPicker.open(
          target_mode ? _INTL("Target Team Size") : _INTL("Pokemon To Add"),
          :min => 1,
          :max => target_mode ? 6 : 5,
          :initial => current,
          :digits => 1,
          :label => target_mode ? _INTL("Final minimum team size") :
                                  _INTL("Additional Pokemon")
        )
        return if selected.nil?
        KantoReloaded::Settings.set(key, selected.to_i)
        @scene.sync_window_values if @scene.respond_to?(:sync_window_values)
      end
    end

    class PendingPinkSlipsAction < KantoReloaded::Options::ActionButton
      def initialize(scene)
        @scene = scene
        super(
          _INTL("Claim Pending Transfers"),
          proc { claim_pending },
          _INTL("Move pending Pink Slips Pokemon and held items into available storage.")
        )
      end

      def name
        counts = KantoReloaded::TrainerControl::PinkSlips.pending_counts
        _INTL("Claim Pending Transfers ({1}/{2})", counts[0], counts[1])
      end

      private

      def claim_pending
        KantoReloaded::TrainerControl::PinkSlips.deliver_pending(true)
        @scene.sync_window_values if @scene.respond_to?(:sync_window_values)
      end
    end

    class SettingsScene < KantoReloaded::SettingsUI::BaseScene
      def scene_title
        "Trainer Control"
      end

      def scene_description
        "Configure trainer teams, adaptation, level scaling, and per-save records."
      end

      def pbGetOptions(_inloadscreen = false)
        rows = []
        rows << KantoReloaded::Options::CollapsibleHeader.new(
          _INTL("Level Scaling"),
          _INTL("Scale weaker trainer teams upward while preserving their intended structure."),
          :collapsed => true
        )
        rows << setting_row(LevelScaling::ENABLED_SETTING)
        rows << setting_row(LevelScaling::REFERENCE_SETTING)
        rows << LevelOffsetAction.new(self)
        rows << setting_row(LevelScaling::PRESERVE_SETTING)
        rows << setting_row(LevelScaling::REGULAR_SETTING)
        rows << setting_row(LevelScaling::LEADER_SETTING)
        rows << setting_row(LevelScaling::REMATCH_SETTING)

        rows << KantoReloaded::Options::CollapsibleHeader.new(
          _INTL("Team Expansion"),
          _INTL("Expand trainer parties; additions inside Gyms match the Gym type."),
          :collapsed => true
        )
        rows << setting_row(TeamExpansion::MODE_SETTING)
        rows << setting_row(TeamExpansion::SIZE_MODE_SETTING)
        rows << ExpansionSizeAction.new(self)
        rows << setting_row(TeamExpansion::HELD_ITEMS_SETTING)
        rows << setting_row(TeamExpansion::LEADER_FULL_SETTING)

        rows << KantoReloaded::Options::CollapsibleHeader.new(
          _INTL("Trainer Adaptation"),
          _INTL("Let exact trainer versions learn from the player's last five battles."),
          :collapsed => true
        )
        rows << setting_row(TrainerAdaptation::ENABLED_SETTING)
        rows << setting_row(TrainerRewards::ENABLED_SETTING)

        rows << KantoReloaded::Options::CollapsibleHeader.new(
          _INTL("Pink Slips"),
          _INTL("Wager Pokemon in eligible trainer battles; the winner takes one Pokemon."),
          :collapsed => true
        )
        rows << setting_row(PinkSlips::ENABLED_SETTING)
        rows << setting_row(PinkSlips::REPEAT_SETTING)
        rows << PendingPinkSlipsAction.new(self)

        rows << KantoReloaded::Options::CollapsibleHeader.new(
          _INTL("Battle Records"),
          _INTL("Track trainer wins, losses, win rate, and winning streaks per save."),
          :collapsed => true
        )
        rows << KantoReloaded::Options::ActionButton.new(
          _INTL("View Trainer Records"),
          proc { KantoReloaded::TrainerControl::BattleRecordsUI.open },
          _INTL("Search, sort, filter, inspect, and reset individual trainer records.")
        )
        rows << setting_row(BattleRecords::ENABLED_SETTING)
        rows << setting_row(BattleRecords::TOAST_SETTING)
        rows << setting_row(BattleRecords::REGULAR_SETTING)
        rows << setting_row(BattleRecords::LEADER_SETTING)
        rows << setting_row(BattleRecords::REMATCH_SETTING)
        rows << KantoReloaded::Options::ActionButton.new(
          _INTL("Reset All Trainer Records"),
          proc { reset_all_records },
          _INTL("Permanently erase every battle record and trainer memory in this save.")
        )

        rows << KantoReloaded::Options::ActionButton.new(
          _INTL("Reset Module"),
          proc { reset_module },
          _INTL("Restore Trainer Control settings to their defaults without erasing records.")
        )
        rows.compact
      end

      private

      def setting_row(key)
        definition = KantoReloaded::Settings.definition(key)
        return nil unless definition
        KantoReloaded::SettingsUI::RowFactory.build(
          definition,
          :scene => self, :module => MODULE_ID, :trainer_control => true
        )
      end

      def reset_all_records
        records = KantoReloaded::TrainerControl::BattleRecords.all_records
        memories = KantoReloaded::TrainerControl::TrainerMemory.all
        if records.empty? && memories.empty?
          KantoReloaded::Toast.warning(_INTL("There are no trainer records to reset."))
          return
        end
        return unless KantoReloaded::PopupWindow.confirm(
          _INTL("Reset all trainer records and adaptation memory in this save?"),
          :default => false
        )
        count = KantoReloaded::TrainerControl::BattleRecords.clear
        memory_count = KantoReloaded::TrainerControl::TrainerMemory.clear
        KantoReloaded::Toast.success(
          _INTL("Reset {1} records and {2} memories.", count, memory_count)
        )
      end

      def reset_module
        return unless KantoReloaded::PopupWindow.confirm(
          _INTL("Reset all Trainer Control settings to their defaults?"),
          :default => false
        )
        KantoReloaded::Settings.reset_module(MODULE_ID)
        sync_window_values
        KantoReloaded::Toast.success(_INTL("Trainer Control settings reset."))
      end
    end

    class << self
      def boot
        return true if @booted
        register_settings
        register_save_events
        register_trainer_party_event
        install_identity_hook
        TrainerMemory.install_hooks
        install_battle_hook
        @booted = true
        KantoReloaded::Log.info(
          "Trainer Control ready", :trainer_control
        ) if defined?(KantoReloaded::Log)
        true
      rescue StandardError => e
        @booted = false
        KantoReloaded::Log.exception(
          "Trainer Control failed to boot", e, channel: :trainer_control
        ) if defined?(KantoReloaded::Log)
        false
      end

      def run_trainer_battle(hook, arguments)
        previous_context = @battle_context
        return hook.call if excluded_battle?
        context = {
          :opponents => [],
          :seen_objects => {},
          :toast_keys => {},
          :pink_slips_allowed => PinkSlips.context_allowed?(arguments)
        }
        @battle_context = context
        TrainerMemory.begin_battle
        Array(arguments).each do |argument|
          register_opponent(argument) if npc_trainer?(argument)
        end
        decision = hook.call
        PinkSlips.resolve(context, decision)
        TrainerMemory.finish_battle(context[:opponents], decision)
        BattleRecords.record_result(context[:opponents], decision)
        TrainerRewards.process(context[:opponents], decision)
        decision
      ensure
        TrainerMemory.cancel_battle if defined?(TrainerMemory)
        @battle_context = previous_context
      end

      def register_opponent(trainer)
        return false unless @battle_context && trainer
        object_key = trainer.object_id
        return false if @battle_context[:seen_objects][object_key]
        @battle_context[:seen_objects][object_key] = true

        identity = TrainerIdentity.for_trainer(trainer)
        return false unless identity
        scope = trainer_scope(trainer)
        TrainerAdaptation.restore(trainer, identity, scope)
        PinkSlips.apply_roster(trainer, identity, scope, @battle_context)
        TeamExpansion.apply(trainer, identity)
        TrainerAdaptation.apply_pending(trainer, identity, scope)
        LevelScaling.apply(trainer, scope)
        opponent = {
          :trainer => trainer,
          :identity => identity,
          :scope => scope
        }
        @battle_context[:opponents] << opponent
        PinkSlips.prepare_wager(opponent, @battle_context)
        show_record_once(identity, scope)
        true
      rescue StandardError => e
        KantoReloaded::Log.exception(
          "Could not process loaded trainer", e, channel: :trainer_control
        ) if defined?(KantoReloaded::Log)
        false
      end

      def trainer_scope(trainer)
        return :rematch if rematch?
        type = trainer.respond_to?(:trainer_type) ? trainer.trainer_type.to_s.upcase : ""
        type.include?("LEADER") ? :leader : :regular
      rescue StandardError
        :regular
      end

      private

      def register_settings
        KantoReloaded::Settings.register(SETTINGS_ACTION, {
          :name => "Trainer Control",
          :description => "Configure trainer teams, adaptation, level scaling, and per-save records.",
          :type => :button,
          :category => :gameplay,
          :owner => :kanto_reloaded,
          :priority => 1600,
          :on_press => proc {
            pbFadeOutIn {
              PokemonOptionScreen.new(
                KantoReloaded::TrainerControl::SettingsScene.new
              ).pbStartScreen
            }
          }
        })

        visible = proc do |context|
          context.is_a?(Hash) && !!(
            context[:trainer_control] || context["trainer_control"]
          )
        end
        scaling_enabled = proc {
          KantoReloaded::TrainerControl::LevelScaling.enabled?
        }
        records_enabled = proc {
          KantoReloaded::TrainerControl::BattleRecords.enabled?
        }
        expansion_enabled = proc {
          KantoReloaded::TrainerControl::TeamExpansion.enabled?
        }
        pink_slips_enabled = proc {
          KantoReloaded::TrainerControl::PinkSlips.enabled?
        }

        definitions = [
          [LevelScaling::ENABLED_SETTING, {
            :name => "Level Scaling",
            :description => "Raise weaker trainer teams toward the selected player party level.",
            :type => :toggle, :default => false, :priority => 10
          }],
          [LevelScaling::REFERENCE_SETTING, {
            :name => "Reference Level",
            :description => "Use the highest party level or the average non-Egg party level.",
            :type => :enum,
            :values => ["Highest Party Level", "Party Average"],
            :default => 0, :priority => 20, :enabled_if => scaling_enabled
          }],
          [LevelScaling::OFFSET_SETTING, {
            :name => "Level Offset",
            :description => "Trainer scaling offset from -99 through +99.",
            :type => :number, :min => -99, :max => 99,
            :default => 0, :priority => 30
          }],
          [LevelScaling::PRESERVE_SETTING, {
            :name => "Preserve Team Level Spread",
            :description => "Raise every team member by the same amount instead of flattening the team.",
            :type => :toggle, :default => true,
            :priority => 40, :enabled_if => scaling_enabled
          }],
          [LevelScaling::REGULAR_SETTING, {
            :name => "Scale Regular Trainers",
            :description => "Apply level scaling to standard trainer battles.",
            :type => :toggle, :default => true,
            :priority => 50, :enabled_if => scaling_enabled
          }],
          [LevelScaling::LEADER_SETTING, {
            :name => "Scale Gym Leaders",
            :description => "Apply level scaling to Gym Leader battles.",
            :type => :toggle, :default => true,
            :priority => 60, :enabled_if => scaling_enabled
          }],
          [LevelScaling::REMATCH_SETTING, {
            :name => "Scale Rematches",
            :description => "Apply level scaling after KIF calculates rematch levels.",
            :type => :toggle, :default => true,
            :priority => 70, :enabled_if => scaling_enabled
          }],
          [TeamExpansion::MODE_SETTING, {
            :name => "Team Expansion",
            :description => "Add deterministic themed, random, or fused Pokemon. Gym additions match the Gym type.",
            :type => :enum,
            :values => ["Off", "Trainer Theme", "Random", "Random Fusion"],
            :default => TeamExpansion::MODE_OFF, :priority => 80
          }],
          [TeamExpansion::SIZE_MODE_SETTING, {
            :name => "Expansion Sizing",
            :description => "Add a fixed count or raise smaller teams to a target size.",
            :type => :enum,
            :values => ["Add Count", "Target Team Size"],
            :default => TeamExpansion::SIZE_ADD,
            :priority => 81, :enabled_if => expansion_enabled
          }],
          [TeamExpansion::ADD_COUNT_SETTING, {
            :name => "Expansion Add Count",
            :description => "Number of Pokemon added in Add Count mode.",
            :type => :number, :min => 1, :max => 5,
            :default => 1, :priority => 82
          }],
          [TeamExpansion::TARGET_SIZE_SETTING, {
            :name => "Expansion Target Size",
            :description => "Minimum trainer party size in Target Team Size mode.",
            :type => :number, :min => 1, :max => 6,
            :default => 3, :priority => 83
          }],
          [TeamExpansion::LEADER_FULL_SETTING, {
            :name => "Gym Leader Full Party",
            :description => "Fill Gym Leader teams to six with Pokemon matching their Gym type.",
            :type => :toggle, :default => false, :priority => 84
          }],
          [TeamExpansion::HELD_ITEMS_SETTING, {
            :name => "Generated Held Items",
            :description => "Give generated Pokemon suitable held items half the time or always.",
            :type => :enum,
            :values => ["50%", "Always"],
            :default => TeamExpansion::HELD_ITEMS_ALWAYS,
            :priority => 85, :enabled_if => expansion_enabled
          }],
          [TrainerAdaptation::ENABLED_SETTING, {
            :name => "Trainer Adaptation",
            :description => "Save and apply three behavior-weighted changes after each win, then four after seven wins.",
            :type => :toggle, :default => true, :priority => 90
          }],
          [TrainerRewards::ENABLED_SETTING, {
            :name => "Progression Rewards",
            :description => "Grant one-time rewards at 3, 7, and 12 wins against an exact trainer version.",
            :type => :toggle, :default => true, :priority => 95
          }],
          [PinkSlips::ENABLED_SETTING, {
            :name => "Pink Slips",
            :description => "Offer Pokemon wagers in eligible single-trainer battles.",
            :type => :toggle, :default => false, :priority => 96
          }],
          [PinkSlips::REPEAT_SETTING, {
            :name => "Repeat Wagers",
            :description => "Allow additional wagers against an exact trainer version after a decisive wager.",
            :type => :toggle, :default => false, :priority => 97,
            :enabled_if => pink_slips_enabled
          }],
          [BattleRecords::ENABLED_SETTING, {
            :name => "Battle Records",
            :description => "Track decisive wins and losses against trainers in this save.",
            :type => :toggle, :default => true,
            :priority => 100
          }],
          [BattleRecords::TOAST_SETTING, {
            :name => "Record Display Toast",
            :description => "Show the existing trainer record before a battle begins.",
            :type => :toggle, :default => true,
            :priority => 110, :enabled_if => records_enabled
          }],
          [BattleRecords::REGULAR_SETTING, {
            :name => "Record Regular Trainers",
            :description => "Track standard trainer battles.",
            :type => :toggle, :default => true,
            :priority => 120, :enabled_if => records_enabled
          }],
          [BattleRecords::LEADER_SETTING, {
            :name => "Record Gym Leaders",
            :description => "Track Gym Leader battles.",
            :type => :toggle, :default => true,
            :priority => 130, :enabled_if => records_enabled
          }],
          [BattleRecords::REMATCH_SETTING, {
            :name => "Record Rematches",
            :description => "Track decisive wins and losses from trainer rematches.",
            :type => :toggle, :default => true,
            :priority => 140, :enabled_if => records_enabled
          }]
        ]

        definitions.each do |key, options|
          KantoReloaded::Settings.register(key, options.merge(
            :category => :quality_of_life,
            :owner => MODULE_ID,
            :visible_if => visible
          ))
        end
      end

      def register_save_events
        return unless defined?(KantoReloaded::Events)
        KantoReloaded::Events.on(
          :kanto_reloaded_save_loaded,
          :trainer_control_legacy_record_migration,
          priority: 180
        ) { |_context| BattleRecords.migrate_legacy! }
        KantoReloaded::Events.on(
          :kanto_reloaded_save_new_game,
          :trainer_control_new_game_record_migration,
          priority: 180
        ) { |_context| BattleRecords.migrate_legacy! }
      end

      def register_trainer_party_event
        return false unless defined?(::Events) && ::Events.respond_to?(:onTrainerPartyLoad)
        @trainer_party_handler ||= proc do |_sender, event|
          trainer = event.is_a?(Array) ? event[0] : event
          KantoReloaded::TrainerControl.register_opponent(trainer)
        end
        ::Events.onTrainerPartyLoad += @trainer_party_handler
        true
      end

      def install_identity_hook
        return false unless defined?(GameData::Trainer)
        trainer_classes = [GameData::Trainer]
        trainer_classes << GameData::TrainerModern if defined?(GameData::TrainerModern)
        trainer_classes << GameData::TrainerExpert if defined?(GameData::TrainerExpert)
        trainer_classes.uniq.each do |trainer_class|
          next if trainer_class != GameData::Trainer &&
                  trainer_class.instance_method(:to_trainer).owner != trainer_class
          KantoReloaded::Hooks.wrap(
            trainer_class,
            :to_trainer,
            :trainer_control_identity,
            :required => true
          ) do |hook, *_arguments|
            trainer = hook.call
            KantoReloaded::TrainerControl::TrainerIdentity.attach_from_data(
              trainer, self
            )
          end
        end
        true
      end

      def install_battle_hook
        KantoReloaded::Hooks.wrap(
          Object,
          :pbTrainerBattleCore,
          :trainer_control_battle_context,
          :required => true
        ) do |hook, *arguments|
          KantoReloaded::TrainerControl.run_trainer_battle(hook, arguments)
        end
      end

      def show_record_once(identity, scope)
        key = identity["key"].to_s
        return if @battle_context[:toast_keys][key]
        @battle_context[:toast_keys][key] = true
        BattleRecords.show_record_toast(identity, scope)
      end

      def excluded_battle?
        return true if debug_skipped_battle?
        return true if cooperative_battle?
        return true if battle_facility_active?
        return true if scripted_no_exp_battle?
        false
      rescue StandardError
        false
      end

      def debug_skipped_battle?
        if defined?($Trainer) && $Trainer &&
           $Trainer.respond_to?(:able_pokemon_count)
          return true if $Trainer.able_pokemon_count.to_i <= 0
        end
        defined?($DEBUG) && $DEBUG && defined?(Input::CTRL) &&
          Input.press?(Input::CTRL)
      rescue StandardError
        false
      end

      def cooperative_battle?
        defined?(CoopBattleState) &&
          CoopBattleState.respond_to?(:in_coop_battle?) &&
          CoopBattleState.in_coop_battle?
      rescue StandardError
        false
      end

      def battle_facility_active?
        return false unless defined?($PokemonGlobal) && $PokemonGlobal
        challenge = $PokemonGlobal.challenge if $PokemonGlobal.respond_to?(:challenge)
        challenge && challenge.respond_to?(:pbInProgress?) &&
          challenge.pbInProgress?
      rescue StandardError
        false
      end

      def scripted_no_exp_battle?
        return false unless defined?($PokemonTemp) && $PokemonTemp
        rules = $PokemonTemp.battleRules
        return false unless rules.is_a?(Hash)
        rules["expGain"] == false || rules[:expGain] == false ||
          !!(rules["noexp"] || rules[:noexp])
      rescue StandardError
        false
      end

      def rematch?
        return false unless defined?(SWITCH_IS_REMATCH)
        defined?($game_switches) && $game_switches &&
          !!$game_switches[SWITCH_IS_REMATCH]
      rescue StandardError
        false
      end

      def npc_trainer?(value)
        defined?(NPCTrainer) && value.is_a?(NPCTrainer)
      rescue StandardError
        false
      end
    end
  end
end

KantoReloaded::TrainerControl.boot
