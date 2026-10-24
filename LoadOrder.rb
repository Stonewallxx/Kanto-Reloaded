#==============================================================================
# Kanto Reloaded: Load Order
#==============================================================================
# Every Kanto Reloaded Ruby file, in the order Bootstrap loads them, and the
# core systems Bootstrap boots afterwards (each one's .boot, in order).
# A file that isn't listed here doesn't load.
#==============================================================================

module Reloaded
  module LoadOrder
    FILES = [
      # Foundation
      "Core/Foundation/Paths.rb",
      "Core/Foundation/JSON.rb",
      "Core/Foundation/Log.rb",
      "Core/Foundation/Events.rb",
      "Core/Foundation/Features.rb",
      "Core/Foundation/Hooks.rb",
      "Core/Foundation/Lifecycle.rb",
      "Core/Foundation/SaveStore.rb",
      "Core/Foundation/Assets.rb",
      "Core/Foundation/Settings.rb",
      "Core/Foundation/ShareCodes.rb",
      "Core/Foundation/Runtime.rb",
      "Core/Saves/SaveFile.rb",
      "Core/Saves/SafeSave.rb",
      "Core/Saves/Library.rb",
      "Core/Saves/Saves.rb",
      "Core/Saves/WhatsNew.rb",
      # Core settings pages and interface
      "Core/Settings/Pages.rb",
      "Core/Interface/GlobalSmallText.rb",
      # Themes, colours, button names, drawing, popups and typing for Kanto
      # Reloaded's screens
      "Core/UI/Palette.rb",
      "Core/UI/Prompts.rb",
      "Core/UI/Pixel.rb",
      "Core/UI/Pointer.rb",
      "Core/UI/ButtonIcons.rb",
      "Core/UI/Dialogs.rb",
      "Core/UI/Dropdown.rb",
      "Core/UI/TextEntry.rb",
      "Core/UI/Frame.rb",
      "Core/UI/Toast.rb",
      # The game's window frames: Global Frame and Speech Frame
      "Core/Interface/WindowFrames.rb",
      # Reloaded Controls: inputs, actions and bindings, and the layer that
      # reads keys and controller buttons
      "Core/Controls/Inputs.rb",
      "Core/Controls/PadLog.rb",
      "Core/Controls/Controls.rb",
      "Core/Controls/Layer.rb",
      "Core/Controls/Splits.rb",
      "Core/Controls/ExtraActions.rb",
      "Core/Controls/Layouts.rb",
      # Kanto Reloaded's settings in KIF Settings, the Reloaded Settings
      # toggle, and the improved KIF Settings it switches on
      "Core/Settings/KIFBridge.rb",
      "Core/Settings/KIFDropdowns.rb",
      "Core/Settings/Presets.rb",
      "Core/Settings/AutosaveRows.rb",
      "Core/UI/SettingsScreen.rb",
      "Core/UI/ControlsScreen.rb",
      # Data Patches: mods change the game's data with JSON files
      # (Mods/<mod>/DataPatches), in memory after it loads
      "Core/DataPatches/Registry.rb",
      "Core/DataPatches/Table.rb",
      "Core/DataPatches/Items.rb",
      "Core/DataPatches/Species.rb",
      "Core/DataPatches/Trainers.rb",
      "Core/DataPatches/Encounters.rb",
      "Core/DataPatches/Outfits.rb",
      "Core/DataPatches/AbilityAPI.rb",
      "Core/DataPatches/Overview.rb",
      "Core/UI/SplitScreen.rb",
      "Core/UI/PatchViewer.rb",
      "Core/Profiler/Owners.rb",
      "Core/Profiler/Profiler.rb",
      "Core/Profiler/Report.rb",
      "Core/Profiler/Probes.rb",
      "Core/Profiler/HookTiming.rb",
      "Core/UI/ProfilerScreen.rb",
      # The Save Checker: a full check of a save, its fixes, and Keep
      # Aside's return
      "Core/SaveCheck/Walk.rb",
      "Core/SaveCheck/Reader.rb",
      "Core/SaveCheck/Content.rb",
      "Core/SaveCheck/ModData.rb",
      "Core/SaveCheck/Check.rb",
      "Core/SaveCheck/Fix.rb",
      "Core/SaveCheck/KeptAside.rb",
      # Bug Reports: one file with everything needed to fix a bug
      "Core/BugReport/Zip.rb",
      "Core/BugReport/Trail.rb",
      "Core/BugReport/Bundle.rb",
      "Core/BugReport/Crash.rb",
      "Core/BugReport/BugReport.rb",
      "Core/UI/PartyIcons.rb",
      "Core/UI/SaveCheckScreen.rb",
      "Core/UI/Notice.rb",
      "Core/UI/BugReportScreen.rb",
      "Core/UI/SaveManagerScreen.rb",
      "Core/UI/LoadScreen.rb",
      "Core/UI/WhatsNewScreen.rb",
      # The startup checks (KIF's update checks) in Reloaded's look
      "Core/UI/UpdateChecksScreen.rb",
      "Core/Saves/UpdateChecks.rb",
      # The Pause Menu: entries, Your Row and the Favorite, and its screen
      "Core/PauseMenu/PauseMenu.rb",
      "Core/UI/PauseMenuScreen.rb",
      # The Overworld Menu: entries, pages, Quick Items, its screen and its
      # page editor
      "Core/OverworldMenu/OverworldMenu.rb",
      "Core/OverworldMenu/Entries.rb",
      "Core/OverworldMenu/SettingRows.rb",
      "Core/UI/OverworldMenuScreen.rb",
      "Core/UI/OverworldPagesScreen.rb",
      # Quality of Life: the toggles, level locks, Super Candy, the toast,
      # and the tools' screens
      "Core/QualityOfLife/QualityOfLife.rb",
      "Core/QualityOfLife/LevelLocks.rb",
      "Core/QualityOfLife/SuperCandy.rb",
      "Core/QualityOfLife/Hooks.rb",
      "Core/QualityOfLife/Toast.rb",
      "Core/UI/QualityOfLifeScreens.rb",
      # The title screen's versions (top right) and Kanto Reloaded's logo; KIF's
      # Living title in Kanto Reloaded's look
      "Core/Interface/TitleVersions.rb",
      "Core/Interface/TitleLogo.rb",
      "Core/Interface/LivingTitle.rb",
      # The Party Screen: its switch and commands, its drawing and its scene
      "Core/PartyScreen/PartyScreen.rb",
      "Core/UI/PartyPaint.rb",
      "Core/UI/PartyScene.rb",
      # The PokeVial: its charges, settings and refills, and its dialogs
      "Core/PokeVial/PokeVial.rb",
      "Core/UI/PokeVialScreen.rb",
      # Healing Moves: healing moves outside battle, and their screens
      "Core/HealingMoves/HealingMoves.rb",
      "Core/UI/HealingMovesScreen.rb",
      # Speed-Up: the game's speed, the window title and the corner indicator
      "Core/SpeedUp/SpeedUp.rb",
      "Core/UI/SpeedUpIndicator.rb",
      # The TM Vault: every TM, HM and tutor move, taught again; its screen
      "Core/TMVault/TMVault.rb",
      "Core/UI/TMVaultScreen.rb",
      # The Reloaded Bag: its order, NEW and Favorites, its screen and the
      # Custom List editor
      "Core/Bag/DefaultLists.rb",
      "Core/Bag/Bag.rb",
      "Core/UI/BagLook.rb",
      "Core/UI/BagScene.rb",
      "Core/UI/BagListScreen.rb",
      "Core/Bag/UseSeveral.rb",
      # The Reloaded PC: its switch and words, its scene and the box tools
      "Core/PC/ReloadedPC.rb",
      "Core/PC/Presets.rb",
      "Core/UI/PCScene.rb",
      "Core/UI/PCTools.rb",
      "Core/UI/PCPicks.rb",
      "Core/UI/PCSearch.rb",
      "Core/UI/PCPresets.rb",
      "Core/UI/PCCompare.rb",
      "Core/UI/PCBoxMove.rb",
      # Fixes to the game's own code
      "Core/Fixes/Fixes.rb",
      "Core/Fixes/CommandTextColours.rb",
      "Core/Fixes/EBDXCommandCursor.rb",
      "Core/Fixes/BagFixes.rb",
      # Last: rows for every feature registered above
      "Core/Settings/FeatureSwitches.rb"
    ].freeze

    # Stonewall's own tools (the Hook Checker): loaded after every file above,
    # only when the folder is there. The Release Builder leaves Dev out of
    # every release.
    DEV_FILE = "Dev/Dev.rb"

    # FeatureSwitches registers its rows before KIFBridge adds every setting
    # to KIF Settings. Dev boots last, when it's there. PauseMenu boots
    # before Profiler and BugReport, so their hooks on the pause menu's
    # scene sit over its screen and still see it open.
    SYSTEMS = [:Lifecycle, :SaveStore, :Assets, :Settings, :Controls, :WindowFrames, :PauseMenu, :OverworldMenu, :Toast, :DataPatches, :Profiler, :Saves, :SaveCheck, :BugReport, :LoadScreen, :UpdateChecks, :QualityOfLife, :PartyScreen, :PokeVial, :HealingMoves, :SpeedUp, :TMVault, :Bag, :BagScreen, :UseSeveral, :PC, :TitleVersions, :TitleLogo, :LivingTitle, :Fixes, :FeatureSwitches, :KIFBridge, :KIFDropdowns, :AutosaveRows, :Dev].freeze

    def self.files
      return FILES
    end
  end
end
