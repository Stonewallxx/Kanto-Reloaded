# Quality Assurance

Quality Assurance features are built-in Kanto Reloaded modules. Features with
settings register them directly in Quality of Life rather than opening a
separate Quality Assurance scene; menu-native features use KR's shared menus.

Each retained feature receives a specifically named Ruby file in this folder,
such as `InfiniteRepel.rb`. Generic `Module.rb` files are not used. Features are
audited separately before migration; code from the disabled monolith is never
copied wholesale.

Unless a feature-specific design says otherwise, retained Quality Assurance
features also register an optional Overworld Menu command that is disabled in
the page editor by default.

## Migration Status

The legacy Quality Assurance audit is complete. Runtime features are loaded
from the specifically named modules in this folder. Relearn Moves and optional
Egg/Event Moves are provided by TM Vault, while Manual Evolution and Quick Rare
Candy were deliberately retired because their old implementations duplicated
KIF's evolution and level-change workflows. The disabled legacy scripts are
reference-only and are not runtime dependencies.

## Infinite Repel

- Setting key: `miscmods_infinite_repel`
- Default: Off
- Hook target: private global `isRepelActive`
- Behavior: returns active while enabled and delegates to KIF otherwise
- Overworld Menu: optional toggle command, disabled on pages by default

The legacy setting key is retained so values from the former standalone mod can
be migrated without creating a second option.

## Instant Hatch

- Setting key: `instant_hatch`
- Default: Off
- Integration: additive `Events.onStepTaken` callback
- Behavior: immediately prepares current party Eggs when enabled, then reduces
  newly encountered party Egg counters above `1` to `1` during the step event;
  KIF performs the hatch
- Overworld Menu: optional toggle command, disabled on pages by default
- Migration: none; the old MSM key is intentionally ignored

## Egg Manager

- Setting key: none; this is a Quality of Life action
- Egg index: every Egg in the party and every box in the active PC storage
- Egg actions: inspect hidden details, transfer between party and PC, or release
  through two confirmations
- Day Care: inspect both parents, compatibility, current breeding-check
  progress, and waiting-Egg status
- Day Care actions: use KIF's native storage picker to deposit a party or PC
  Pokemon, withdraw either parent to the party or PC using KIF's current cost,
  collect a native waiting Egg to the party or PC, or discard the waiting Egg
- Day Care display: deposited parents use full front sprites; Egg lists use
  normal Pokemon icons
- Safety: collection calls KIF's current `pbDayCareGenerateEgg`; KR does not
  reproduce or force Egg generation
- Instant Hatch: collected or party-bound Eggs are prepared immediately while
  Instant Hatch is enabled
- Overworld Menu: optional action with Party, PC, and waiting-Egg status,
  disabled on pages by default

## Always Obey

- Setting key: `always_obey`
- Default: Off
- Hook targets: `PokeBattle_Battler#pbObedienceCheck?` and `#pbDisobey`
- Behavior: bypasses disobedience only while enabled and delegates otherwise
- Overworld Menu: optional toggle command, disabled on pages by default
- Migration: none; the old inverted MSM key is intentionally ignored

## Rematch Money

- Setting key: `rematch_money`
- Default: Off
- Hook target: `PokeBattle_Battle#pbGainMoney`
- Behavior: temporarily clears the rematch switch so KIF awards its normal
  trainer payout, then restores the exact original switch value in `ensure`
- Overworld Menu: optional toggle command, disabled on pages by default
- Migration: none; the old MSM key is intentionally ignored

## Infinite Money

- Setting key: `infinite_money`
- Default: Off
- Hook target: `Player#money=`
- Behavior: immediately fills the current player's money when enabled and
  routes later assignments through KIF's original setter at
  `Settings::MAX_MONEY`; disabling leaves the current balance unchanged and
  restores normal future money changes
- Category action: `Reset Money` appears directly below the toggle, confirms
  through KR's shared popup, disables Infinite Money, and restores
  `Settings::INITIAL_MONEY`
- Overworld Menu: optional toggle command, disabled on pages by default
- Migration: none; the old MSM key is intentionally ignored

## Upgraded PP

- Setting key: `upgraded_pp`
- Default: Off
- Hook target: `Pokemon#learn_move`
- Integration: setting/save callbacks and an additive battle-start event apply
  the upgrade to the current party; newly learned party moves are upgraded by a
  guarded wrapper that preserves `learn_move`'s return value
- Behavior: sets eligible moves to KIF's maximum of `3` PP Ups and restores
  them to their new total PP; existing upgrades are not removed when disabled
- Overworld Menu: optional toggle command, disabled on pages by default
- Migration: none; the old MSM key is intentionally ignored

## Infinite PP

- Setting key: `infinite_pp`
- Default: Off
- Hook target: `PokeBattle_Battler#pbSetPP`, scoped to player-owned battlers
- Integration: setting/save callbacks and additive battle-start/end events
  restore the party without map-frame polling
- Behavior: normal partial PP loss remains, but a player-owned move that reaches
  `0` PP during battle is immediately restored to its current total PP
- Overworld Menu: optional toggle command, disabled on pages by default
- Migration: none; the old MSM key is intentionally ignored

## Quick Throw

- Battle Menu commands: `Quick Throw` and `Select Quick Throw Ball`
- Setting key: none; the commands are always registered
- Fast activation: make `Quick Throw` the per-save Favorite and press Action
  twice from KIF's main battle command
- Save data: selected ball, blacklist, and one-time legacy migration marker
- Hook targets: `PokeBattle_Battle#pbItemMenu`, `#pbRegisterItem`, and a scoped
  `#pbOpposingBattlerCount` validation wrapper
- Behavior: uses native item registration and capture handling without replacing
  KIF's battle command menu or command phase

## Nature Selector

- Setting key: none; this is a Quality of Life action
- Integration: KIF's native party screen and KR's shared popup list
- Behavior: changes a selected non-Egg party Pokemon's nature, clears an
  existing stat-nature override, and lets KIF recalculate the affected stats
- Overworld Menu: optional action, disabled on pages by default
- Migration: none; the old feature did not store a setting

## Level Locking

- Save data: namespaced per-Pokemon `@kanto_reloaded_data["level_lock"]`
- Behavior: allows the locked level and caps EXP one point before the following
  level; excess EXP is not banked
- Integration: guarded level, EXP, Rare Candy, and battle EXP boundaries
- Manager: native party picker with shared KR popups and digit Number Picker
- Overworld Menu: optional manager action, disabled on pages by default
- Migration: none; the old setting and generic Pokemon field are ignored

## Super Candy

- Setting key: none; this is a Quality of Life action
- Targets: KIF level cap, highest eligible party level, or a level entered
  through KR's digit Number Picker
- Behavior: raises the whole eligible party while honoring personal Level
  Locks, KIF's level cap, and KIF's maximum level
- Integration: intermediate moves use KR's level-up Move Teaching context;
  evolution uses KIF's native evolution check and EvoLock behavior
- Overworld Menu: optional action, disabled on pages by default
- Migration: none; the old mode and custom-level settings are ignored

See `Documentation/QualityAssurance.md` for the feature-by-feature migration
audit and retirement status of the old standalone sources.
