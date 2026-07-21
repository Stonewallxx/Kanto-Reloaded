#==============================================================================
# Kanto Reloaded - Trainer Control Identity
#==============================================================================

module KantoReloaded
  module TrainerControl
    module TrainerIdentity
      METADATA_IVAR = :@kanto_reloaded_trainer_identity

      class << self
        def attach_from_data(trainer, trainer_data)
          return trainer unless trainer && trainer_data
          metadata = identity_from_data(trainer_data, trainer)
          trainer.instance_variable_set(METADATA_IVAR, metadata)
          trainer
        rescue StandardError => e
          log_exception("Could not attach trainer identity", e)
          trainer
        end

        def for_trainer(trainer)
          return nil unless trainer
          stored = trainer.instance_variable_get(METADATA_IVAR) rescue nil
          return normalize(stored, trainer) if stored.is_a?(Hash)
          runtime_identity(trainer)
        rescue StandardError => e
          log_exception("Could not resolve trainer identity", e)
          nil
        end

        def identity_from_data(trainer_data, trainer = nil)
          trainer_type = read_value(trainer_data, :trainer_type)
          real_name = read_value(trainer_data, :real_name)
          real_name = read_value(trainer_data, :name) if blank?(real_name)
          version = read_value(trainer_data, :version).to_i
          display_name = trainer ? read_value(trainer, :name) : read_value(trainer_data, :name)
          build(
            "pbs",
            trainer_type,
            real_name,
            version,
            display_name,
            current_map_id
          )
        end

        def legacy_candidates
          candidates = {}
          return candidates unless defined?(GameData::Trainer)
          GameData::Trainer.each do |trainer_data|
            type = read_value(trainer_data, :trainer_type).to_s
            names = [
              read_value(trainer_data, :real_name),
              read_value(trainer_data, :name)
            ].compact.map(&:to_s).uniq
            names.each do |name|
              old_key = "#{type}_#{name}"
              existing = candidates[old_key]
              if existing.nil? ||
                 read_value(trainer_data, :version).to_i <
                   read_value(existing, :version).to_i
                candidates[old_key] = trainer_data
              end
            end
          end
          candidates
        rescue StandardError => e
          log_exception("Could not build legacy trainer identities", e)
          {}
        end

        private

        def runtime_identity(trainer)
          build(
            "runtime",
            read_value(trainer, :trainer_type),
            read_value(trainer, :name),
            0,
            read_value(trainer, :name),
            current_map_id
          )
        end

        def normalize(value, trainer)
          source = value["source"] || value[:source] || "runtime"
          trainer_type = value["trainer_type"] || value[:trainer_type]
          real_name = value["real_name"] || value[:real_name]
          version = value["version"] || value[:version] || 0
          display_name = read_value(trainer, :name)
          display_name = value["display_name"] || value[:display_name] if blank?(display_name)
          map_id = value["map_id"] || value[:map_id] || current_map_id
          build(source, trainer_type, real_name, version, display_name, map_id)
        end

        def build(source, trainer_type, real_name, version, display_name, map_id)
          type_text = trainer_type.to_s
          name_text = real_name.to_s
          source_text = source.to_s
          version_number = version.to_i
          identity_parts = [source_text, type_text, name_text, version_number]
          identity_parts << map_id.to_i if source_text == "runtime"
          {
            "key" => encoded_key(identity_parts),
            "source" => source_text,
            "trainer_type" => type_text,
            "real_name" => name_text,
            "display_name" => blank?(display_name) ? name_text : display_name.to_s,
            "version" => version_number,
            "map_id" => map_id.to_i
          }
        end

        def encoded_key(parts)
          Array(parts).map do |value|
            text = value.to_s
            "#{text.bytesize}:#{text}"
          end.join("|")
        end

        def current_map_id
          defined?($game_map) && $game_map ? $game_map.map_id.to_i : 0
        rescue StandardError
          0
        end

        def read_value(object, name)
          object.respond_to?(name) ? object.public_send(name) : nil
        rescue StandardError
          nil
        end

        def blank?(value)
          value.nil? || value.to_s.empty?
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
