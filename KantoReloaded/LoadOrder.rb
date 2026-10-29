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
      "Core/Saves/TestCopy.rb",
      "Core/Saves/Saves.rb",
      "Core/Saves/WhatsNew.rb",
      # Core settings pages and interface
      "Core/Settings/Pages.rb",
      "Core/Settings/Sections.rb",
      "Core/Interface/GlobalSmallText.rb",
      # Themes, colours, button names, drawing, popups and typing for Kanto
      # Reloaded's screens
      "Core/UI/Palette.rb",
      "Core/UI/Prompts.rb",
      "Core/UI/Pixel.rb",
      "Core/UI/ModIcons.rb",
      "Core/UI/Pointer.rb",
      "Core/UI/ButtonIcons.rb",
      "Core/UI/Dialogs.rb",
      "Core/UI/Dropdown.rb",
      "Core/UI/TextEntry.rb",
      "Core/UI/Frame.rb",
      "Core/UI/Toast.rb",
      "Core/UI/RunTags.rb",
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
      "Core/UI/SettingsSections.rb",
      "Core/UI/SettingsRangeRows.rb",
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
      "Core/UI/TestCopyAsk.rb",
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
      # the Egg Manager (after the PC: its PC action, Compare's colours)
      "Core/EggManager/EggManager.rb",
      "Core/EggManager/Eggs.rb",
      "Core/EggManager/Incubators.rb",
      "Core/EggManager/DayCare.rb",
      "Core/EggManager/Alerts.rb",
      "Core/EggManager/Hatching.rb",
      "Core/UI/EggPopups.rb",
      "Core/UI/EggManagerScreen.rb",
      "Core/UI/EggDayCareTab.rb",
      # Difficulty: Shown As, the Debug Run Tag, Hard's trainer IVs; the
      # question when lowering
      "Core/Difficulty/Difficulty.rb",
      "Core/UI/DifficultyAsk.rb",
      # The Randomizer: Kanto Reloaded's parts on cody's engine (KIF's)
      "Core/Randomizer/Randomizer.rb",
      "Core/Randomizer/Learnsets.rb",
      "Core/Randomizer/Abilities.rb",
      "Core/Randomizer/Dynamic.rb",
      "Core/UI/RandomizerRows.rb",
      "Core/UI/RandomizerScreen.rb",
      "Core/UI/RandomizerShare.rb",
      "Core/UI/RandomizerBans.rb",
      "Core/UI/RandomizerViewers.rb",
      "Core/UI/RandomizerNewGame.rb",
      # New Game Setup: the run set up before Oak's talk (after Difficulty
      # and the Randomizer: its rows use theirs), its screen and popups
      "Core/NewGame/NewGameSetup.rb",
      "Core/UI/NewGameScreen.rb",
      "Core/UI/NewGamePopups.rb",
      # Publish a Mod: KIF's Publish a mod in one screen (after Fixes'
      # source fingerprints, which it reads at the first press)
      "Core/Publish/Publish.rb",
      "Core/UI/PublishScreen.rb",
      "Core/UI/PublishPopups.rb",
      # Hidden Power: each Pokémon's own type, shown everywhere; the researcher's
      # Type Reel, the plates and the Hidden Chamber
      "Core/HiddenPower/HiddenPower.rb",
      "Core/HiddenPower/Battle.rb",
      "Core/HiddenPower/Summary.rb",
      "Core/HiddenPower/Researcher.rb",
      "Core/HiddenPower/Plates.rb",
      "Core/HiddenPower/Chamber.rb",
      "Core/UI/HiddenPowerScreens.rb",
      # Critical EV Gain: bonus EVs after a win, the EV Gains board, the
      # Fresh-Start Mochi
      "Core/CriticalEVGain/CriticalEVGain.rb",
      "Core/CriticalEVGain/Mochi.rb",
      "Core/UI/CriticalEVGainScreens.rb",
      "Core/IVBoundaries/IVBoundaries.rb",
      "Core/IVBoundaries/Sources.rb",
      "Core/IVBoundaries/Fusion.rb",
      "Core/IVBoundaries/MaxIVs.rb",
      "Core/UI/IVBoundariesScreens.rb",
      "Core/UI/IVBoundariesRows.rb",
      # Double Abilities: every fusion's head and body abilities, in battle and
      # out; the Fusion Screen, Banned Pairs, the Split Pill pop-ups
      "Core/DoubleAbilities/DoubleAbilities.rb",
      "Core/DoubleAbilities/Banned.rb",
      "Core/DoubleAbilities/Battle.rb",
      "Core/DoubleAbilities/PopUps.rb",
      "Core/DoubleAbilities/Fusing.rb",
      "Core/DoubleAbilities/EliteRedux.rb",
      "Core/UI/DoubleAbilitiesScreens.rb",
      # A New Trainer Card: its switch and data, the counts (always on), the
      # unlocks, its scene and its Style and Unlocks tabs
      "Core/TrainerCard/TrainerCard.rb",
      "Core/TrainerCard/Counters.rb",
      "Core/TrainerCard/Unlocks.rb",
      "Core/UI/TrainerCardScene.rb",
      "Core/UI/TrainerCardStyle.rb",
      # The Battle Menu: its entries and pages, what it reads from a battle,
      # the Turn Log, the panel, Battle Info and the Field Strip
      "Core/BattleMenu/BattleMenu.rb",
      "Core/BattleMenu/BattleNotes.rb",
      "Core/BattleMenu/TurnLog.rb",
      "Core/BattleMenu/Entries.rb",
      "Core/UI/FieldStrip.rb",
      "Core/UI/BattleMenuPanel.rb",
      "Core/UI/BattleInfoScreen.rb",
      "Core/UI/BattleInfoPopups.rb",
      # Fixes to the game's own code
      "Core/Fixes/Fixes.rb",
      "Core/Fixes/CommandTextColours.rb",
      "Core/Fixes/EBDXCommandCursor.rb",
      "Core/Fixes/BagFixes.rb",
      "Core/Fixes/CardBackgrounds.rb",
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
    SYSTEMS = [:Lifecycle, :SaveStore, :Assets, :Settings, :Controls, :WindowFrames, :PauseMenu, :OverworldMenu, :Toast, :DataPatches, :Profiler, :Saves, :SaveCheck, :BugReport, :LoadScreen, :UpdateChecks, :QualityOfLife, :PartyScreen, :PokeVial, :HealingMoves, :SpeedUp, :TMVault, :Bag, :BagScreen, :UseSeveral, :PC, :EggManager, :Difficulty, :Randomizer, :NewGameSetup, :Publish, :HiddenPower, :CriticalEVGain, :IVBoundaries, :DoubleAbilities, :TrainerCard, :BattleMenu, :TitleVersions, :TitleLogo, :LivingTitle, :Fixes, :FeatureSwitches, :KIFBridge, :KIFDropdowns, :AutosaveRows, :Dev].freeze

    def self.files
      return FILES
    end
  end
end
