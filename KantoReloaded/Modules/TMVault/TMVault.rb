#==============================================================================
# Kanto Reloaded TM Vault
#==============================================================================
# Persistent TM, HM, and tutor move collection backed by the KR save bucket.
# Tutor.net remains the acquisition backend so KIF and other mods keep working.
#==============================================================================

module KantoReloaded
  module TMVault
    SAVE_SYSTEM = :tm_vault
    EGG_MOVES_SETTING = :tm_vault_egg_moves
    IMPORT_MARKER = :tutor_net_imported
    SORT_NAMES = ["Name", "Type", "Category", "Recent", "Level Learned"].freeze

    class << self
      def data
        KantoReloaded::SaveData.system(SAVE_SYSTEM)
      end

      def vault
        raw = data["moves"] || data[:moves] || []
        valid = []
        invalid = []
        Array(raw).each do |entry|
          move_id = normalize_move_id(entry)
          move_id ? valid << move_id : invalid << entry
        end
        valid.uniq!
        if !invalid.empty? || Array(raw) != valid
          log_invalid_moves(invalid)
          save_vault(valid)
        end
        valid
      rescue StandardError => e
        log_exception("TM Vault move list could not be read", e)
        []
      end

      def save_vault(entries)
        normalized = Array(entries).map { |entry| normalize_move_id(entry) }.compact.uniq
        KantoReloaded::SaveData.set(SAVE_SYSTEM, :moves, normalized, section: :systems)
        prune_sources(normalized)
        normalized
      rescue StandardError => e
        log_exception("TM Vault move list could not be saved", e)
        []
      end

      def source_map
        raw = data["sources"] || data[:sources]
        raw = {} unless raw.is_a?(Hash)
        data["sources"] = raw
        raw
      end

      def source_for(move_id)
        Array(source_map[move_key(move_id)])
      end

      def sort_mode
        value = data["sort_mode"] || data[:sort_mode] || 0
        [[value.to_i, 0].max, SORT_NAMES.length - 1].min
      end

      def sort_mode=(value)
        normalized = [[value.to_i, 0].max, SORT_NAMES.length - 1].min
        KantoReloaded::SaveData.set(SAVE_SYSTEM, :sort_mode, normalized, section: :systems)
        normalized
      end

      def egg_moves_enabled?
        KantoReloaded::Settings.get(EGG_MOVES_SETTING, 1).to_i == 1
      rescue
        true
      end

      def normalize_move_id(move_id)
        move = GameData::Move.try_get(move_id) rescue nil
        move ? move.id : nil
      end

      def register(move_id, options = {})
        return false unless defined?(GameData::Move)
        move = GameData::Move.try_get(move_id) rescue nil
        unless move
          log_invalid_moves([move_id])
          return false
        end
        source = options[:source] || :script
        id = move.id
        list = vault
        already_registered = list.include?(id)
        record_source(id, source)
        return false if already_registered
        list << id
        save_vault(list)
        emit(:tm_vault_move_registered, {
          :move => id,
          :move_data => move,
          :source => normalize_source(source)
        })
        if options[:notify]
          KantoReloaded.toast_success(_INTL("{1} was added to your TM Vault!", move.name))
        end
        true
      rescue StandardError => e
        log_exception("TM Vault could not register #{move_id}", e)
        false
      end

      def sync_tutor_net!
        return 0 unless defined?($Trainer) && $Trainer
        list = $Trainer.respond_to?(:tutorlist) ? $Trainer.tutorlist : nil
        return 0 unless list.is_a?(Array)
        imported = 0
        list.each do |entry|
          move_id = entry.is_a?(Array) ? entry[0] : entry
          imported += 1 if register(move_id, :source => :tutor_net)
        end
        unless KantoReloaded::SaveData.get(SAVE_SYSTEM, IMPORT_MARKER, false, section: :systems)
          KantoReloaded::SaveData.set(SAVE_SYSTEM, IMPORT_MARKER, true, section: :systems)
          KantoReloaded::Log.info("Imported Tutor.net moves into TM Vault", :modules) if defined?(KantoReloaded::Log)
        end
        imported
      rescue StandardError => e
        log_exception("Tutor.net import failed", e)
        0
      end

      def pocket_scan
        return 0 unless defined?($PokemonBag) && $PokemonBag
        pockets = $PokemonBag.pockets rescue nil
        return 0 unless pockets.is_a?(Array)
        registered = 0
        pockets.each do |pocket|
          next unless pocket.is_a?(Array)
          pocket.each do |entry|
            item_id = entry.is_a?(Array) ? entry[0] : entry
            item = GameData::Item.try_get(item_id) rescue nil
            next unless item && item.is_machine? && item.move
            registered += 1 if register(item.move, :source => :bag_scan)
          end
        end
        registered
      rescue StandardError => e
        log_exception("TM Vault Bag scan failed", e)
        0
      end

      def sync!
        sync_tutor_net!
        pocket_scan
        vault.length
      end

      def compat(move_id, pokemon)
        return :none unless pokemon && !pokemon.egg?
        return :knows if pokemon.hasMove?(move_id)
        return :compat if pokemon.compatible_with_move?(move_id)
        :cant
      rescue
        :cant
      end

      def relearnable_moves(pokemon)
        return [] unless pokemon && !pokemon.egg? && !pokemon.shadowPokemon?
        moves = native_relearnable_moves(pokemon)
        moves.concat(egg_moves_for(pokemon)) if egg_moves_enabled?
        moves.concat(event_moves_for(pokemon)) if event_moves_enabled?
        moves.map { |move_id| normalize_move_id(move_id) }.compact.uniq.reject do |move_id|
          pokemon.hasMove?(move_id)
        end
      rescue StandardError => e
        log_exception("TM Vault relearn list failed", e)
        []
      end

      def native_relearnable_moves(pokemon)
        if defined?(MoveRelearnerScreen)
          return Array(MoveRelearnerScreen.new(nil).pbGetRelearnableMoves(pokemon))
        end
        moves = []
        Array(pokemon.getMoveRelearnerList).each do |entry|
          next unless entry.is_a?(Array) && entry.length >= 2
          next if entry[0].to_i > pokemon.level || pokemon.hasMove?(entry[1])
          moves << entry[1]
        end
        Array(pokemon.first_moves).each do |move_id|
          moves.unshift(move_id) unless pokemon.hasMove?(move_id) || moves.include?(move_id)
        end
        moves
      rescue
        []
      end

      def egg_moves_for(pokemon)
        baby = pbGetBabySpecies(pokemon.species) rescue pokemon.species
        moves = pbGetSpeciesEggMoves(baby) rescue []
        Array(moves)
      end

      def egg_move_ids_for(pokemon)
        Array(egg_moves_for(pokemon)).map do |move_id|
          normalize_move_id(move_id)
        end.compact.uniq
      rescue
        []
      end

      def egg_move?(pokemon, move_id)
        normalized = normalize_move_id(move_id)
        normalized && egg_move_ids_for(pokemon).include?(normalized)
      rescue
        false
      end

      def level_learned_for(pokemon, move_id)
        return nil unless pokemon
        normalized = normalize_move_id(move_id)
        return nil unless normalized
        return 0 if egg_move?(pokemon, normalized)
        first_moves = Array(pokemon.first_moves).map do |entry|
          normalize_move_id(entry)
        end.compact
        return 0 if first_moves.include?(normalized)

        levels = []
        Array(pokemon.getMoveRelearnerList).each do |entry|
          next unless entry.is_a?(Array) && entry.length >= 2
          learned_move = normalize_move_id(entry[1])
          levels << entry[0].to_i if learned_move == normalized
        end
        levels.empty? ? nil : levels.min
      rescue
        nil
      end

      def event_moves_for(pokemon)
        return [] unless pokemon.respond_to?(:getEventMoveList)
        Array(pokemon.getEventMoveList)
      rescue
        []
      end

      def event_moves_enabled?
        defined?($PokemonSystem) && $PokemonSystem &&
          $PokemonSystem.respond_to?(:eventmoves) && $PokemonSystem.eventmoves.to_i > 0
      rescue
        false
      end

      def tm_label_cache
        return @tm_label_cache if @tm_label_cache
        @tm_label_cache = {}
        GameData::Item.each do |item|
          next unless item.is_machine? && item.move
          @tm_label_cache[item.move] = item.name
        end
        @tm_label_cache
      rescue
        @tm_label_cache ||= {}
      end

      def types_bitmap
        return @types_bitmap if @types_bitmap
        @types_animated_bitmap = AnimatedBitmap.new("Graphics/Pictures/types")
        @types_bitmap = @types_animated_bitmap.bitmap
      rescue
        @types_bitmap = nil
      end

      def egg_icon_bitmap
        return @egg_icon_bitmap if @egg_icon_bitmap
        @egg_icon_animated_bitmap = AnimatedBitmap.new("Graphics/Icons/iconEgg")
        @egg_icon_bitmap = @egg_icon_animated_bitmap.bitmap
      rescue
        @egg_icon_bitmap = nil
      end

      def open(options = {})
        return false unless defined?(KantoReloaded::TMVault::Scene)
        sync!
        emit(:tm_vault_opened, :move_count => vault.length)
        runner = proc { KantoReloaded::TMVault::Scene.new.main }
        options[:fade] == false || !defined?(pbFadeOutIn) ? runner.call : pbFadeOutIn(&runner)
        true
      rescue StandardError => e
        log_exception("TM Vault could not be opened", e)
        KantoReloaded.message(_INTL("TM Vault could not be opened."), :theme => :error)
        false
      end

      def install
        return true if @installed
        register_setting
        register_events
        @installed = true
        true
      rescue StandardError => e
        @installed = false
        log_exception("TM Vault initialization failed", e)
        false
      end

      private

      def register_setting
        KantoReloaded::Settings.register(EGG_MOVES_SETTING, {
          :type => :toggle,
          :name => "TM Vault Egg Moves",
          :description => "Include Egg Moves in TM Vault's Relearn Moves list.",
          :default => 1,
          :category => :quality_of_life,
          :owner => :tm_vault,
          :priority => 35
        })
      end

      def register_events
        return unless defined?(KantoReloaded::Events)
        KantoReloaded::Events.on(:kanto_reloaded_save_loaded, :tm_vault_tutor_net_import, priority: 170) do |_context|
          KantoReloaded::TMVault.sync_tutor_net!
        end
        KantoReloaded::Events.on(:kanto_reloaded_save_new_game, :tm_vault_tutor_net_import, priority: 170) do |_context|
          KantoReloaded::TMVault.sync_tutor_net!
        end
      end

      def move_key(move_id)
        (normalize_move_id(move_id) || move_id).to_s
      end

      def record_source(move_id, source)
        key = move_key(move_id)
        sources = Array(source_map[key])
        label = normalize_source(source)
        sources << label unless sources.include?(label)
        source_map[key] = sources
        KantoReloaded::SaveData.set(SAVE_SYSTEM, :sources, source_map, section: :systems)
      end

      def prune_sources(valid_moves)
        valid_keys = Array(valid_moves).map { |move_id| move_key(move_id) }
        sources = source_map
        changed = false
        sources.keys.each do |key|
          next if valid_keys.include?(key.to_s)
          sources.delete(key)
          changed = true
        end
        KantoReloaded::SaveData.set(SAVE_SYSTEM, :sources, sources, section: :systems) if changed
      end

      def normalize_source(source)
        case source.to_s.strip.downcase
        when "tm", "hm", "machine" then "Machine"
        when "tutor", "move_tutor" then "Tutor"
        when "tutor_net", "tutornet" then "Tutor.net"
        when "shop", "mart" then "Shop"
        when "pickup", "item_ball" then "Pickup"
        when "receive", "gift", "event" then "Receive"
        when "bag", "bag_scan" then "Bag Scan"
        else "Script"
        end
      end

      def log_invalid_moves(entries)
        @invalid_log_once ||= {}
        Array(entries).each do |entry|
          key = entry.to_s
          next if key.empty? || @invalid_log_once[key]
          @invalid_log_once[key] = true
          KantoReloaded::Log.warning("TM Vault removed invalid move #{key}", :modules) if defined?(KantoReloaded::Log)
        end
      end

      def emit(event_name, context)
        KantoReloaded::Events.emit(event_name, context) if defined?(KantoReloaded::Events)
      rescue StandardError => e
        log_exception("TM Vault event #{event_name} failed", e)
      end

      def log_exception(message, error)
        KantoReloaded::Log.exception(message, error, channel: :modules) if defined?(KantoReloaded::Log)
      end
    end
  end
end

KantoReloaded::TMVault.install if defined?(KantoReloaded::TMVault)
