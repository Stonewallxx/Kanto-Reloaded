#==============================================================================
# Kanto Reloaded: saves (the system)
#==============================================================================
# Roadmap topic 1: Kanto Reloaded's Save Manager (Active, Backups, Deleted;
# notes and color tags; health checks; a backup browser), KIF Beta's
# backups, Hoenn Reloaded's safe saving (SafeSave.rb), and a rebuilt Load
# Screen with a What's New screen.
#
#   Library.rb         the saves themselves (Reloaded::Saves)
#   SafeSave.rb        saving through a checked temporary file
#   WhatsNew.rb        the notes of each version (Kanto Reloaded's, KIF
#                      Beta's, mods')
#   ../UI/SaveManagerScreen.rb, LoadScreen.rb, WhatsNewScreen.rb
#
# Settings: Reloaded Load Screen and Startup Mod-Check (Reloaded Systems:
# Off skips KIF Beta's startup checks, for a newer KIF and for mod
# updates; his call, 2026-10-23), and a Saves page with
# the Save Manager and Backup Cap. Backup Cap takes over KIF Beta's Save
# Backups setting (locked to Infinite in mod.json): Unlimited keeps every
# backup; a number keeps that many plain backups of each save (named ones
# are always kept; KIF keeps its newest 10 autosave backups).
#==============================================================================

module Reloaded
  module Saves
    LOAD_SCREEN = :"systems.reloaded_load_screen"
    MOD_CHECK = :"systems.startup_mod_check"
    CAPS = [nil, 10, 15, 20, 25, 50, 100].freeze
    CAP_NAMES = ["Unlimited", "10", "15", "20", "25", "50", "100"].freeze

    class << self
      def boot
        register_settings
        Reloaded::Events.on(:saved, :saves_backup_cap) { |ctx| after_save(ctx[:path]) }
        hook_mod_check
        return true
      end

      # Startup Mod-Check Off: KIF Beta's startup checks are skipped, so
      # nothing comes up before the load screen: its look for mod updates
      # (ModCatalogUI.startup_check, 0.21.68+) and its look for a newer KIF
      # (Updater.check at the load screen). Mods > Updates and Options >
      # System > Check for Updates still look when they're used.
      def hook_mod_check
        if defined?(::KIF::ModCatalogUI) && ::KIF::ModCatalogUI.respond_to?(:startup_check)
          Reloaded::Hooks.around(nil, ::KIF::ModCatalogUI.singleton_class, :startup_check, :id => :saves_startup_mod_check) do |original, *args|
            Reloaded::Settings.get(MOD_CHECK) == false ? false : original.call(*args)
          end
        end
        if defined?(::KIF::Updater) && ::KIF::Updater.respond_to?(:check)
          Reloaded::Hooks.around(nil, ::KIF::Updater.singleton_class, :check, :id => :saves_startup_kif_check) do |original, *args|
            manual = args[0] ? true : false
            !manual && Reloaded::Settings.get(MOD_CHECK) == false ? false : original.call(*args)
          end
        end
      end

      def register_settings
        s = Reloaded::Settings
        s.register(LOAD_SCREEN, :page => :systems, :priority => 20, :type => :toggle, :default => true, :preset => false,
          :name => "Reloaded Load Screen", :goes_to => :saves,
          :description => "Kanto Reloaded's Load Screen: Your save's note, health and backups, What's New and the Save Manager, and KIF's update checks before it in Reloaded's look. Off shows the game's own.")
        s.register(MOD_CHECK, :page => :systems, :priority => 40, :type => :toggle, :default => true, :preset => false,
          :name => "Startup Mod-Check",
          :description => "Before the load screen, KIF looks for a newer KIF and for updates to your mods. Off skips both, so nothing comes up; Options > System > Check for Updates and Mods > Updates still check.")
        s.register_page(:saves, :group => :general, :name => "Saves", :icon => :saves, :priority => 35,
          :description => "Your save files, their backups and notes.")
        s.register(:"saves.manager", :page => :saves, :priority => 0, :type => :button, :preset => false,
          :name => "Save Manager",
          :on_press => proc { Reloaded::SaveManagerScreen.open if defined?(Reloaded::SaveManagerScreen) },
          :description => "Your save files: Notes, color tags, health, backups to restore, and the saves you've deleted.")
        s.register(:"saves.backup_cap", :page => :saves, :priority => 10, :type => :enum, :default => 0, :preset => false,
          :values => CAP_NAMES, :name => "Backup Cap", :remap => [5, { 2 => 4, 3 => 5, 4 => 6 }],
          :descriptions => ["Every backup is kept."] + CAPS.compact.map { |n| "The newest #{n} backups of each save are kept." },
          :description => "How many backups of each save are kept. Older ones go to the Recycle Bin, and named backups are always kept.")
      end

      # Kanto Reloaded's Load Screen is on.
      def load_screen?
        return Reloaded::Settings.get(LOAD_SCREEN) ? true : false
      rescue StandardError
        return false
      end

      def cap
        return CAPS[Reloaded::Settings.get(:"saves.backup_cap").to_i]
      end

      # After each save: what's known about it is out of date, and the
      # Backup Cap trims its backups.
      def after_save(path)
        return unless path
        forget(path)
        slot = File.basename(path.to_s, ".rxdata")
        n = trim_backups(slot, cap)
        Reloaded::Log.info("Backup Cap: #{n} old backup(s) of #{slot} removed", :saves) if n > 0
      rescue StandardError => e
        Reloaded::Log.exception("Old backups couldn't be trimmed", e, :saves)
      end
    end
  end
end
