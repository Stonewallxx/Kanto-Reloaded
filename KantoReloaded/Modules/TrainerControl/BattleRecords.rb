#==============================================================================
# Kanto Reloaded - Trainer Control Battle Records
#==============================================================================

module KantoReloaded
  module TrainerControl
    module BattleRecords
      ENABLED_SETTING = :trainer_control_battle_records
      TOAST_SETTING = :trainer_control_record_toast
      REGULAR_SETTING = :trainer_control_record_regular
      LEADER_SETTING = :trainer_control_record_leaders
      REMATCH_SETTING = :trainer_control_record_rematches
      MODULE_ID = :trainer_control
      LEGACY_VARIABLE_ID = 999
      LEGACY_MIGRATION_KEY = "legacy_variable_999_imported"

      class << self
        def enabled?
          truthy?(setting(ENABLED_SETTING, true))
        end

        def toast_enabled?
          enabled? && truthy?(setting(TOAST_SETTING, true))
        end

        def scope_enabled?(scope)
          key = case scope.to_sym
                when :leader then LEADER_SETTING
                when :rematch then REMATCH_SETTING
                else REGULAR_SETTING
                end
          enabled? && truthy?(setting(key, true))
        rescue StandardError
          false
        end

        def record_result(opponents, decision)
          result = decision.to_i
          return 0 unless result == 1 || result == 2
          recorded = 0
          Array(opponents).each do |opponent|
            next unless opponent.is_a?(Hash)
            scope = (opponent[:scope] || opponent["scope"] || :regular).to_sym
            next unless scope_enabled?(scope)
            identity = opponent[:identity] || opponent["identity"]
            next unless identity.is_a?(Hash)
            update_record(identity, scope, result == 1)
            recorded += 1
          end
          recorded
        rescue StandardError => e
          log_exception("Could not record trainer battle result", e)
          0
        end

        def show_record_toast(identity, scope)
          return false unless toast_enabled? && scope_enabled?(scope)
          record = find(identity_key(identity))
          return false unless record && total_battles(record) > 0
          wins = integer(record, "wins")
          losses = integer(record, "losses")
          streak = integer(record, "current_streak")
          percentage = win_percentage(record)
          text = _INTL(
            "{1}: {2}W / {3}L | {4}% | Streak: {5}",
            record["display_name"], wins, losses, percentage, streak
          )
          if percentage > 50
            KantoReloaded::Toast.success(text)
          elsif percentage < 50
            KantoReloaded::Toast.error(text)
          else
            KantoReloaded::Toast.show(text)
          end
          true
        rescue StandardError => e
          log_exception("Could not show trainer battle record", e)
          false
        end

        def all_records
          records_hash.values.map { |record| normalize_record(record) }.
            select { |record| total_battles(record) > 0 }
        rescue StandardError => e
          log_exception("Could not read trainer battle records", e)
          []
        end

        def find(key)
          raw = records_hash[key.to_s]
          raw ? normalize_record(raw) : nil
        rescue StandardError
          nil
        end

        def delete(key)
          !!records_hash.delete(key.to_s)
        rescue StandardError => e
          log_exception("Could not delete trainer battle record", e)
          false
        end

        def clear
          count = records_hash.length
          records_hash.clear
          count
        rescue StandardError => e
          log_exception("Could not clear trainer battle records", e)
          0
        end

        def total_battles(record)
          stored = integer(record, "total_battles")
          return stored if stored > 0
          integer(record, "wins") + integer(record, "losses")
        end

        def win_percentage(record)
          total = total_battles(record)
          return 0 if total <= 0
          ((integer(record, "wins") * 100.0) / total).round
        end

        def migrate_legacy!
          data = module_bucket
          return 0 if data[LEGACY_MIGRATION_KEY]
          legacy = legacy_records
          imported = import_legacy_records(legacy)
          data[LEGACY_MIGRATION_KEY] = true
          KantoReloaded::Log.info(
            "Imported #{imported} legacy Trainer Control records",
            :trainer_control
          ) if imported > 0 && defined?(KantoReloaded::Log)
          imported
        rescue StandardError => e
          log_exception("Legacy Trainer Control record migration failed", e)
          0
        end

        private

        def update_record(identity, scope, player_won)
          key = identity_key(identity)
          return false if key.empty?
          record = normalize_record(records_hash[key] || {})
          record["key"] = key
          record["display_name"] = identity_value(identity, "display_name", "Trainer")
          record["trainer_type"] = identity_value(identity, "trainer_type", "")
          record["version"] = identity_value(identity, "version", 0).to_i
          record["scope"] = scope.to_s
          if player_won
            record["wins"] += 1
            record["current_streak"] += 1
            record["best_streak"] = [
              record["best_streak"], record["current_streak"]
            ].max
          else
            record["losses"] += 1
            record["current_streak"] = 0
          end
          record["total_battles"] = record["wins"] + record["losses"]
          records_hash[key] = record
          true
        end

        def normalize_record(value)
          source = value.is_a?(Hash) ? value : {}
          wins = integer(source, "wins")
          losses = integer(source, "losses")
          {
            "key" => text(source, "key"),
            "display_name" => nonempty(text(source, "display_name"), "Trainer"),
            "trainer_type" => text(source, "trainer_type"),
            "version" => integer(source, "version"),
            "scope" => nonempty(text(source, "scope"), "regular"),
            "wins" => wins,
            "losses" => losses,
            "total_battles" => [integer(source, "total_battles"), wins + losses].max,
            "current_streak" => integer(source, "current_streak"),
            "best_streak" => integer(source, "best_streak")
          }
        end

        def records_hash
          data = module_bucket
          records = data["records"] || data[:records]
          unless records.is_a?(Hash)
            records = {}
            data["records"] = records
          end
          data.delete(:records)
          data["records"] = records
          records
        end

        def module_bucket
          return @fallback_bucket ||= {} unless defined?(KantoReloaded::SaveData)
          KantoReloaded::SaveData.module_data(MODULE_ID)
        end

        def legacy_records
          return nil unless defined?($game_variables) && $game_variables
          value = $game_variables[LEGACY_VARIABLE_ID]
          value.is_a?(Hash) ? value : nil
        rescue StandardError
          nil
        end

        def import_legacy_records(legacy)
          return 0 unless legacy.is_a?(Hash)
          candidates = KantoReloaded::TrainerControl::TrainerIdentity.legacy_candidates
          imported = 0
          legacy.each do |old_key, old_record|
            next unless old_record.is_a?(Hash)
            wins = integer(old_record, "wins")
            losses = integer(old_record, "losses")
            next if wins + losses <= 0
            identity = legacy_identity(old_key, candidates[old_key.to_s])
            merge_legacy_record(identity, wins, losses)
            imported += 1
          end
          imported
        end

        def legacy_identity(old_key, trainer_data)
          if trainer_data
            return KantoReloaded::TrainerControl::TrainerIdentity.
              identity_from_data(trainer_data)
          end
          old_text = old_key.to_s
          {
            "key" => "legacy:#{old_text}",
            "source" => "legacy",
            "trainer_type" => "",
            "real_name" => old_text,
            "display_name" => old_text.gsub("_", " "),
            "version" => 0,
            "map_id" => 0
          }
        end

        def merge_legacy_record(identity, wins, losses)
          key = identity_key(identity)
          record = normalize_record(records_hash[key] || {})
          record["key"] = key
          record["display_name"] = identity_value(identity, "display_name", "Trainer")
          record["trainer_type"] = identity_value(identity, "trainer_type", "")
          record["version"] = identity_value(identity, "version", 0).to_i
          record["scope"] = trainer_scope(record["trainer_type"]).to_s
          record["wins"] = [record["wins"], wins.to_i].max
          record["losses"] = [record["losses"], losses.to_i].max
          record["total_battles"] = record["wins"] + record["losses"]
          records_hash[key] = record
        end

        def trainer_scope(trainer_type)
          trainer_type.to_s.upcase.include?("LEADER") ? :leader : :regular
        end

        def identity_key(identity)
          identity_value(identity, "key", "").to_s
        end

        def identity_value(identity, key, fallback = nil)
          return fallback unless identity.is_a?(Hash)
          value = identity[key]
          value = identity[key.to_sym] if value.nil?
          value.nil? ? fallback : value
        end

        def integer(hash, key)
          value = hash[key]
          value = hash[key.to_sym] if value.nil? && hash.respond_to?(:[])
          [value.to_i, 0].max
        rescue StandardError
          0
        end

        def text(hash, key)
          value = hash[key]
          value = hash[key.to_sym] if value.nil? && hash.respond_to?(:[])
          value.to_s
        rescue StandardError
          ""
        end

        def nonempty(value, fallback)
          value.to_s.empty? ? fallback : value.to_s
        end

        def setting(key, fallback)
          return fallback unless defined?(KantoReloaded::Settings)
          KantoReloaded::Settings.get(key, fallback)
        end

        def truthy?(value)
          value == true || (value.is_a?(Numeric) && value.to_i != 0) ||
            ["true", "on", "yes", "enabled", "1"].include?(value.to_s.downcase)
        end

        def log_exception(message, error)
          KantoReloaded::Log.exception(
            message, error, channel: :trainer_control
          ) if defined?(KantoReloaded::Log)
        end
      end
    end
  end
end
