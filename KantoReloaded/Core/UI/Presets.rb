#==============================================================================
# Kanto Reloaded: presets (the improved KIF Settings' Presets button)
#==============================================================================
# KIF's presets (990_KIF/F-CORE-08: 12 named slots in KIF_Presets.kro, each
# holding one save's per-save settings), with Kanto Reloaded's popups and:
#
#   - Kanto Reloaded's per-save settings saved and loaded with them (kept in
#     the slot as :reloaded, which KIF's own load skips)
#   - share codes: a preset copied as text ("KIF1:..."), pasted into a slot
#     in any game; only values of the same kind as the game's are taken
#   - Delete, and Rename by typing in the title bar
#
# Slots stay in KIF's file, so KIF Settings as it ships (Reloaded Settings
# Off) sees the same presets.
#==============================================================================

module Reloaded
  module Presets
    CODE_PREFIX = "KIF1:"

    class << self
      # Presets need a loaded save (they hold a save's settings).
      def available?
        return defined?(::KIF::Presets) && defined?(::KIF.in_game?) && ::KIF.in_game? ? true : false
      end

      # The slot list; a chosen slot opens what to do with it, then the list
      # comes back. B closes it.
      def open(scene)
        slot = 0
        loop do
          d = ::KIF::Presets.data
          labels = Array.new(::KIF::Presets::SLOTS) { |i| slot_label(d, i) }
          descriptions = Array.new(::KIF::Presets::SLOTS) do |i|
            filled?(d, i) ? _INTL("Load it, save over it, rename it or share it.")
                          : _INTL("Empty. Save your settings here, or paste a share code.")
          end
          slot = Reloaded::Dialogs.menu(scene, _INTL("Presets"), labels, descriptions, slot)
          return if slot.nil?
          slot_menu(scene, slot)
        end
      end

      # The share code of slot i, or nil when it is empty.
      def share_code(i)
        d = ::KIF::Presets.data
        vals = d[:slots][i]
        return nil unless vals.is_a?(Hash)
        kif = {}
        vals.each { |k, v| kif[k.to_s] = v if k != :reloaded && json_safe?(v) }
        payload = { "name" => d[:names][i].to_s, "kif" => kif }
        kr = vals[:reloaded]
        if kr.is_a?(Hash)
          kr = kr.select { |_k, v| json_safe?(v) }
          payload["kr"] = kr unless kr.empty?
        end
        return Reloaded::ShareCodes.encode(CODE_PREFIX, payload)
      end

      # The preset in a share code ({"name", "kif", "kr"}), or nil.
      def read_code(text)
        data = Reloaded::ShareCodes.decode(CODE_PREFIX, text)
        return data && data["kif"].is_a?(Hash) ? data : nil
      end

      # Puts a share code's preset in slot i (and its name, when it has one).
      # Only settings this game has, with values of the same kind, are kept.
      def store_code(i, data)
        known = ::KIF::Presets.keys
        vals = {}
        data["kif"].each do |k, v|
          key = known.find { |s| s.to_s == k }     # no new symbols from the text
          next unless key && json_safe?(v) && same_kind?(v, current_value(key))
          vals[key] = v
        end
        kr = data["kr"].is_a?(Hash) ? data["kr"].select { |_k, v| json_safe?(v) } : {}
        vals[:reloaded] = kr unless kr.empty?
        d = ::KIF::Presets.data
        d[:slots][i] = vals
        name = data["name"].to_s.strip
        d[:names][i] = name[0, 16] unless name.empty?
        return ::KIF::Presets.write(d)
      end

      private

      def filled?(d, i)
        return d[:slots][i].is_a?(Hash)
      end

      def slot_label(d, i)
        return filled?(d, i) ? d[:names][i].to_s : _INTL("{1} (Empty)", d[:names][i])
      end

      def slot_menu(scene, i)
        d = ::KIF::Presets.data
        name = d[:names][i].to_s
        filled = filled?(d, i)
        actions = []
        actions << [:load, _INTL("Load"), _INTL("Replace this save's settings with this preset.")] if filled
        actions << [:save, filled ? _INTL("Save Over") : _INTL("Save Here"), _INTL("Keep this save's settings in this preset.")]
        actions << [:rename, _INTL("Rename"), _INTL("Give this preset a new name.")]
        actions << [:copy, _INTL("Copy Share Code"), _INTL("Copy this preset as text, to paste into another game.")] if filled
        actions << [:paste, _INTL("Paste Share Code"), _INTL("Put a copied share code into this preset.")]
        actions << [:delete, _INTL("Delete"), _INTL("Empty this preset.")] if filled
        actions << [:cancel, _INTL("Cancel"), _INTL("Back to the presets.")]
        k = Reloaded::Dialogs.menu(scene, name, actions.map { |a| a[1] }, actions.map { |a| a[2] })
        return if k.nil?
        case actions[k][0]
        when :load   then load_slot(scene, i, name)
        when :save   then save_slot(scene, i, name, filled)
        when :rename then rename_slot(scene, i, name)
        when :copy   then copy_slot(scene, name, i)
        when :paste  then paste_slot(scene, i, name, filled)
        when :delete then delete_slot(scene, i, name)
        end
      end

      def load_slot(scene, i, name)
        return unless Reloaded::Dialogs.confirm(scene, name, _INTL("Replace this save's settings with {1}?", name),
                                                _INTL("Load"), _INTL("Cancel"), false)
        ::KIF::Presets.load(i)
        kr = (::KIF::Presets.data[:slots][i] || {})[:reloaded]
        Reloaded::Settings.import_values(kr) if kr.is_a?(Hash)
        Reloaded::Dialogs.notice(scene, name, _INTL("Loaded {1}.", name))
      end

      def save_slot(scene, i, name, filled)
        if filled
          return unless Reloaded::Dialogs.confirm(scene, name, _INTL("Save this save's settings over {1}?", name),
                                                  _INTL("Save"), _INTL("Cancel"), false)
        end
        ok = ::KIF::Presets.save(i) && store_reloaded(i)
        Reloaded::Dialogs.notice(scene, name, ok ? _INTL("This save's settings are now in {1}.", name)
                                                 : _INTL("The preset couldn't be saved."))
      end

      # Kanto Reloaded's per-save settings, next to KIF's in the slot.
      def store_reloaded(i)
        values = Reloaded::Settings.export_values(:save)
        return true if values.empty?
        d = ::KIF::Presets.data
        return false unless d[:slots][i].is_a?(Hash)
        d[:slots][i][:reloaded] = values
        return ::KIF::Presets.write(d)
      end

      # Typed in the title bar (a controller's A opens the naming screen);
      # Esc or B leaves the name as it was.
      def rename_slot(scene, i, name)
        text, how = scene.run_entry(:rename, _INTL("Type a Name"), name, 16, :prompt => _INTL("Preset Name?"))
        return if how != :enter || text.to_s.strip.empty?
        ::KIF::Presets.rename(i, text)
      end

      def copy_slot(scene, name, i)
        code = share_code(i)
        if code && set_clipboard(code)
          Reloaded::Dialogs.notice(scene, name, _INTL("{1}'s share code is copied. Paste it into a preset in any game.", name))
        else
          Reloaded::Dialogs.notice(scene, name, _INTL("The share code couldn't be copied."))
        end
      end

      def paste_slot(scene, i, name, filled)
        data = read_code(clipboard)
        unless data
          Reloaded::Dialogs.notice(scene, _INTL("Paste Share Code"), _INTL("The clipboard doesn't hold a share code. Copy one first."))
          return
        end
        incoming = data["name"].to_s.strip
        incoming = _INTL("the copied preset") if incoming.empty?
        if filled
          return unless Reloaded::Dialogs.confirm(scene, name, _INTL("Put {1} in place of {2}?", incoming, name),
                                                  _INTL("Paste"), _INTL("Cancel"), false)
        end
        if store_code(i, data)
          Reloaded::Dialogs.notice(scene, _INTL("Paste Share Code"), _INTL("{1} is in this slot. Load it to use it.", incoming))
        else
          Reloaded::Dialogs.notice(scene, _INTL("Paste Share Code"), _INTL("The preset couldn't be saved."))
        end
      end

      def delete_slot(scene, i, name)
        return unless Reloaded::Dialogs.confirm(scene, name, _INTL("Empty {1}? Its settings will be gone.", name),
                                                _INTL("Delete"), _INTL("Cancel"), false)
        d = ::KIF::Presets.data
        d[:slots].delete(i)
        ::KIF::Presets.write(d)
      end

      def current_value(key)
        return $PokemonSystem ? $PokemonSystem.send(key) : nil
      rescue StandardError
        return nil
      end

      def json_safe?(v)
        return Reloaded::ShareCodes.json_safe?(v)
      end

      def kind(v)
        return :bool if v == true || v == false
        return :int if v.is_a?(Integer)
        return :num if v.is_a?(Float)
        return :str if v.is_a?(String)
        return :list if v.is_a?(Array)
        return :none
      end

      def same_kind?(v, current)
        return true if current.nil?
        return kind(v) == kind(current)
      end

      def clipboard
        return Reloaded::ShareCodes.clipboard
      end

      def set_clipboard(text)
        return Reloaded::ShareCodes.copy(text)
      end
    end
  end
end
