#==============================================================================
# Kanto Reloaded Public API Contracts
#==============================================================================

module KantoReloaded
  module API
    CONTRACTS = {
      :log             => { :classification => :stable, :constant => "KantoReloaded::Log" },
      :platform        => { :classification => :stable, :constant => "KantoReloaded::Platform" },
      :hooks           => { :classification => :stable, :constant => "KantoReloaded::Hooks" },
      :events          => { :classification => :stable, :constant => "KantoReloaded::Events" },
      :save_data       => { :classification => :stable, :constant => "KantoReloaded::SaveData" },
      :save_migrations => { :classification => :stable, :constant => "KantoReloaded::SaveMigrations" },
      :save_protection => { :classification => :stable, :constant => "KantoReloaded::SaveProtection" },
      :settings        => { :classification => :stable, :constant => "KantoReloaded::Settings" },
      :messaging       => { :classification => :stable, :constant => "KantoReloaded" },
      :shared_ui       => { :classification => :stable, :constant => "KantoReloaded::UI" },
      :popup_window    => { :classification => :stable, :constant => "KantoReloaded::PopupWindow" },
      :number_picker   => { :classification => :stable, :constant => "KantoReloaded::NumberPicker" },
      :list_state      => { :classification => :stable, :constant => "KantoReloaded::ListState" },
      :item_picker     => { :classification => :stable, :constant => "KantoReloaded::ItemPicker" },
      :bug_report      => { :classification => :stable, :constant => "KantoReloaded::BugReport" },
      :toast           => { :classification => :stable, :constant => "KantoReloaded::Toast" },
      :hint_text       => { :classification => :stable, :constant => "KantoReloaded::HintText" },
      :options_ui      => { :classification => :stable, :constant => "KantoReloaded::Options" },
      :settings_ui     => { :classification => :stable, :constant => "KantoReloaded::SettingsUI" },
      :overworld_menu  => { :classification => :stable, :constant => "KantoReloaded::OverworldMenu" },
      :battle_menu     => { :classification => :stable, :constant => "KantoReloaded::BattleMenu" },
      :save_manager    => { :classification => :stable, :constant => "KantoReloaded::SaveManager" },
      :tm_vault        => { :classification => :stable, :constant => "KantoReloaded::TMVault" },
      :reloaded_shop   => { :classification => :stable, :constant => "KantoReloaded::ReloadedShop" },
      :randomizer      => { :classification => :stable, :constant => "KantoReloaded::Randomizer" },
      :pc_organization => { :classification => :stable, :constant => "KantoReloaded::PCOrganization" },
      :level_locking   => { :classification => :stable, :constant => "KantoReloaded::LevelLocking" },
      :kif_options     => { :classification => :compatibility, :constant => "KantoReloaded::KIFOptionsIntegration" },
      :msm_compatibility => { :classification => :compatibility, :constant => "KantoReloaded::MSMCompatibility" },
      :data_patches    => { :classification => :stable, :constant => "KantoReloaded::DataPatches" },
      :abilities       => { :classification => :stable, :constant => "KantoReloaded::Abilities" }
    }.freeze

    def self.contract(name)
      entry = CONTRACTS[name.to_sym]
      entry ? entry.merge(:name => name.to_sym) : nil
    rescue
      nil
    end

    def self.contracts
      result = {}
      CONTRACTS.each { |name, entry| result[name] = entry.merge(:name => name) }
      result
    end
  end
end
