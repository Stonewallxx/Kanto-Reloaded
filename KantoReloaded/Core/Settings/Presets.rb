#==============================================================================
# Kanto Reloaded: presets (the improved KIF Settings' Presets button)
#==============================================================================
# KIF's presets (990_KIF/F-CORE-08: 12 named slots in KIF_Presets.kro, each
# holding one save's per-save settings), with Kanto Reloaded's popups and:
#
#   - Kanto Reloaded's per-save settings saved and loaded with them (kept in
#     the slot as :reloaded, which KIF's own load skips)
#   - Delete, and Rename by typing in the title bar
#
# (Share codes were cut 2026-11-05: KIF 2.0.0's Mod Safety grades their
# Base64 red.)
#
# Slots stay in KIF's file, so KIF Settings as it ships (Reloaded Settings
# Off) sees the same presets.
#==============================================================================

module Reloaded
  module Presets
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
            filled?(d, i) ? _INTL("Load it, save over it or rename it.")
                          : _INTL("Empty. Save your settings here.")
          end
          slot = Reloaded::Dialogs.menu(scene, _INTL("Presets"), labels, descriptions, slot)
          return if slot.nil?
          slot_menu(scene, slot)
        end
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
        actions << [:delete, _INTL("Delete"), _INTL("Empty this preset.")] if filled
        actions << [:cancel, _INTL("Cancel"), _INTL("Back to the presets.")]
        k = Reloaded::Dialogs.menu(scene, name, actions.map { |a| a[1] }, actions.map { |a| a[2] })
        return if k.nil?
        case actions[k][0]
        when :load   then load_slot(scene, i, name)
        when :save   then save_slot(scene, i, name, filled)
        when :rename then rename_slot(scene, i, name)
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

      def delete_slot(scene, i, name)
        return unless Reloaded::Dialogs.confirm(scene, name, _INTL("Empty {1}? Its settings will be gone.", name),
                                                _INTL("Delete"), _INTL("Cancel"), false)
        d = ::KIF::Presets.data
        d[:slots].delete(i)
        ::KIF::Presets.write(d)
      end
    end
  end
end
