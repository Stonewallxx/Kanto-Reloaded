# Quality Assurance Migration Audit

The old Quality Assurance implementations are read-only migration references:

- `Mods/10_Quality Assurance_old.rb.disabled` is the original monolith.
- `Mods/QualityAssurance` is the later standalone package. Its
  `mod.json.disabled` keeps it retired while preserving its scripts.

QA features that are retained use specifically named files under
`Mods/KantoReloaded/Modules/QualityAssurance/`, such as `InfiniteRepel.rb`.
Generic `Module.rb` files are not used. Each feature uses KR-owned settings,
menus, save data, and hooks as needed. No feature may copy a full base method
from the monolith.

Unless explicitly decided otherwise, retained Quality Assurance features
register an optional Overworld Menu command with `default_enabled: false`.

## Feature Audit

### Infinite Repel

- Legacy key: `miscmods_infinite_repel`
- Old target: private global `isRepelActive`
- Risk: Low
- Decision: Retained and ported.
- KR design: guarded `KantoReloaded::Hooks.wrap`; returns `true` only while
  enabled and delegates all arguments, blocks, visibility, and behavior when
  disabled.
- Overworld Menu: registers an optional On/Off command using the same KR
  setting. The command is available in the page editor but disabled by default.

### Auto Hook Fishing

- KR key: `auto_hook_fishing`
- Old target: removes and recreates `Settings::FISHING_AUTO_HOOK`.
- Risk: Low after redesign.
- Decision: Retained and ported.
- KR design: guarded `Object#pbWaitForInput` wrapper that returns a successful
  reaction only while enabled. It does not change `Settings::FISHING_AUTO_HOOK`
  or KIF's `SWITCH_FISHING_AUTOHOOK`, and delegates unchanged while disabled.
- Overworld Menu: registers an optional On/Off command using the same KR
  setting. The command is available in the page editor but disabled by default.

### Infinite Safari Steps

- KR key: `infinite_safari_steps`
- Old target: removes and recreates `Settings::SAFARI_STEPS`.
- Risk: Low after redesign.
- Decision: Retained and ported.
- KR design: guarded `SafariState#steps=` wrapper that rejects only downward
  changes during an active, undecided Safari game. Initialization, increases,
  cleanup, ball exhaustion, quitting, and disabled behavior remain native.
  `Settings::SAFARI_STEPS` is never changed or assumed to be `600`.
- Display: KIF continues showing its real configured maximum and the current
  frozen step count instead of a fabricated `999999` value.
- Overworld Menu: registers an optional On/Off command using the same KR
  setting. The command is available in the page editor but disabled by default.

### Rematch Money

- KR key: `rematch_money`; the old `miscmods_rematch_money` key is not migrated.
- Old target: `PokeBattle_Battle#pbGainMoney` and `SWITCH_IS_REMATCH`.
- Risk: Medium.
- Decision: Retained and ported as
  `Modules/QualityAssurance/RematchMoney.rb`.
- KR design: a guarded wrapper temporarily clears `SWITCH_IS_REMATCH` only
  while KIF's current `pbGainMoney` implementation runs. An `ensure` block
  restores the exact prior switch value on normal returns and exceptions. The
  wrapper preserves arguments, blocks, visibility, return values, and current
  KIF behavior while disabled or outside a rematch.
- Overworld Menu: optional On/Off command, disabled in the page editor by
  default.

### Move Teaching

- KR key: `level_up_move_learning`; the old
  `miscmods_no_move_auto_teach` and `miscmods_move_teach_prompt` keys are not
  migrated.
- Old targets: `PokeBattle_Battle#pbLearnMove` and private global `pbLearnMove`.
- Risk: Medium after redesign because battle and field level-up paths use
  separate native methods.
- Decision: Retained and redesigned as one `Level-Up Move Learning` enum with
  `Native`, `Ask`, and `Skip` modes. The old standalone Move Teach Prompt is
  retired.
- KR design: guarded wrappers mark only `pbChangeLevel` as a level-up context,
  exclude nested evolution learning, and apply the decision before native
  global or battle teaching. Actual teaching, move forgetting, battler updates,
  and return behavior remain native.
- Multiplayer: non-player party members always delegate to KIF's existing
  battle wrapper.
- TM Vault, machines, tutors, relearning, and evolution remain unchanged.
- Overworld Menu: registers an optional mode-cycling command. The command is
  available in the page editor but disabled by default.

### Infinite Money

- KR key: `infinite_money`; the old `miscmods_infinite_money` key is not
  migrated.
- Old targets: stale `Trainer#money=` and per-frame `Scene_Map#update` polling.
- Risk: Medium. The setter can be wrapped safely, but map polling is wasteful
  and couples unrelated PP features to the same override.
- Decision: Retained and ported as
  `Modules/QualityAssurance/InfiniteMoney.rb`.
- KR design: a guarded `Player#money=` wrapper delegates to KIF's original
  setter with `Settings::MAX_MONEY` while enabled and delegates unchanged while
  disabled. A setting callback immediately fills the current player's balance
  when enabled and reapplies on KR save-load/new-game callback passes. No map
  update polling is installed.
- Category action: `Reset Money` is anchored immediately after Infinite Money.
  It confirms through KR's shared popup, disables Infinite Money, assigns
  `Settings::INITIAL_MONEY` through the original setter, and reports the result
  through KR's shared toast API.
- Overworld Menu: optional On/Off command, disabled in the page editor by
  default.

### Upgraded PP

- KR key: `upgraded_pp`; the old `miscmods_upgraded_pp` key is not migrated.
- Old targets: `Pokemon#learn_move` and per-frame party scans.
- Risk: Medium because it repeatedly mutates every party move.
- Decision: Retained and ported as
  `Modules/QualityAssurance/UpgradedPP.rb`.
- KR design: a setting callback upgrades the current party when enabled and on
  KR save-load/new-game callback passes. An additive battle-start event catches
  newly received or hatched party members, while a guarded `Pokemon#learn_move`
  wrapper upgrades future learned moves without relying on the method's `nil`
  return value. KIF's supported maximum of `3` PP Ups is used instead of the
  legacy script's out-of-range value of `5`. No map update polling is installed.
- Overworld Menu: optional On/Off command, disabled in the page editor by
  default.

### Infinite PP

- KR key: `infinite_pp`; the old `miscmods_infinite_pp` key is not migrated.
- Old target: per-frame `Scene_Map#update` party scans.
- Risk: Medium because it performs continuous unrelated map work.
- Decision: Retained and ported as
  `Modules/QualityAssurance/InfinitePP.rb`.
- KR design: setting and save callback passes restore the current party, and
  additive battle-start/end events restore PP at defined lifecycle points. A
  guarded player-only `PokeBattle_Battler#pbSetPP` wrapper delegates the normal
  PP change first, then refills a move only if it reached `0`; partial PP loss,
  opponent PP, arguments, visibility, and the original return value are
  preserved. No map update polling is installed.
- Overworld Menu: optional On/Off command, disabled in the page editor by
  default.

### Always Obey

- KR key: `always_obey`; the old inverted `miscmods_remove_disobedience` key is
  not migrated.
- Old targets: `PokeBattle_Battler#pbObedienceCheck?` and `#pbDisobey`.
- Risk: Low to Medium.
- Decision: Retained, renamed, and ported as
  `Modules/QualityAssurance/AlwaysObey.rb`.
- KR design: guarded wrappers return `true` while enabled and delegate all
  arguments, blocks, visibility, return values, and current KIF or Multiplayer
  behavior while disabled.
- Overworld Menu: optional On/Off command, disabled in the page editor by
  default.

### Manual Evolution

- Legacy key: `miscmods_no_auto_evolve`
- Old targets: private globals `pbChangeLevel` and `pbEvolutionCheck`, Pokemon
  instance variables, and the complete party menu.
- Risk: Critical. Evolution state and menu behavior are duplicated across
  several full replacements.
- Decision: Audit complete; intentionally retired rather than ported.
- Reason: KIF already owns global EvoLock, per-Pokemon evolution locks, storage
  commands, and evolution checks. A second KR evolution policy would duplicate
  and conflict with those systems.

### Quick Rare Candy

- Legacy key: `miscmods_quick_rare_candy`
- Old target: complete replacement path inside private global `pbChangeLevel`.
- Risk: Critical because it duplicates level, move-learning, stat, and evolution
  behavior.
- Decision: Audit complete; intentionally retired rather than ported.
- Reason: the old setting only accelerated Rare Candy use by replacing the
  complete level-change workflow. KR's redesigned Super Candy supplies the
  retained bulk-leveling workflow while delegating move learning and evolution
  to the current KR and KIF systems.

### Quick Throw

- Legacy dependency: MSM's `BattleCommandMenu` plus independent battle command
  and command-phase replacements.
- Risk: Critical. The old implementation owns separate Special/AUX2 shortcuts
  and duplicates battle selection loops to consume the turn.
- Decision: Retained and redesigned as
  `Modules/QualityAssurance/QuickThrow.rb`.
- KR design: always-registered `Quick Throw` and `Select Quick Throw Ball`
  Battle Menu commands with no enable toggle or separate keybind. Favorite
  supplies the fast Action-twice workflow. The selected ball and blacklist are
  per-save, Master Ball starts blocked, and the shared PopupWindow carousel
  displays the ball sprite, quantity, access status, and estimated catch rate.
- Runtime boundary: returns KR's native `:bag` command and consumes only its
  owned pending request through guarded `pbItemMenu`, `pbRegisterItem`, and
  scoped opposing-count wrappers. It does not replace command menus, command
  phases, ItemHandlers, Multiplayer, or base battle files.
- Migration: imports the old `:quick_throw_last_ball` and
  `:ball_filter_blacklist` values once when available. The old dedicated-button
  mode, HUD sprite, chord controls, external memory file, hardcoded suggestion
  table, and per-species catch memory are not ported.

### Instant Hatch

- KR key: `instant_hatch`; the old `miscmods_instant_hatch` key is not migrated.
- Old target: additive `Events.onStepTaken` callback that sets egg steps to `1`.
- Risk: Low.
- Decision: Retained and ported as
  `Modules/QualityAssurance/InstantHatch.rb`.
- KR design: enabling the setting immediately prepares current party Eggs, and
  a guarded, nil-safe additive step callback prepares Eggs obtained later. Only
  counters above `1` are changed. KIF retains ownership of counter reduction,
  `pbHatch`, animations, prompts, statistics, and party or PC handling.
- Overworld Menu: optional On/Off command, disabled in the page editor by
  default.

### Egg Manager

- KR key: `egg_manager`; action only.
- Targets: read-only party, active PC storage, and Day Care indexes plus
  narrowly scoped native storage and Day Care mutations.
- Risk: Medium because remote transfers and permanent release actions cross
  party, storage, and Day Care ownership boundaries.
- Decision: New KR Quality of Life feature implemented as
  `Modules/QualityAssurance/EggManager.rb`.
- KR design: a dedicated Eggs/Day Care scene uses KIF Pokemon icons for the Egg
  list, full front sprites for deposited Day Care parents, `hatchbg`, KR input
  routing, shared confirmations, and a hidden Inspect Egg view. The Egg list
  exposes location, remaining steps, and incubation progress; Inspect Egg
  reveals species/form, shininess, nature, ability, IVs, moves, and Poke Ball.
- Storage boundary: party-to-PC transfers remove the party source only after
  `PokemonStorage#pbStoreCaught` accepts the Egg. PC-to-party transfers roll back
  the party append if clearing the source slot fails. Release requires two
  confirmations.
- Day Care boundary: party deposits, withdrawal, and collection call KIF's
  current `pbDayCareDeposit`, `pbDayCareWithdraw`, and
  `pbDayCareGenerateEgg` methods. PC deposits use a KR-owned transactional
  source-slot transfer because KIF has no native PC-to-Day-Care operation.
  Withdrawal charges the current native cost and restores money if withdrawal
  fails. Waiting state is cleared only after native Egg generation succeeds.
  Forced Egg generation is not provided.
- Overworld Menu: optional manager action with Party/PC/waiting status, disabled
  in the page editor by default.

### Relearn Moves Party Command

- Legacy key: `miscmods_relearn_moves`
- Old target: complete `PokemonPartyScreen#pbPokemonScreen` replacement.
- Risk: Critical. The replacement also copies KIF item, mail, hidden move,
  switching, nickname, follower, and Nuzlocke behavior.
- Decision: Audit complete; retained through TM Vault rather than the party
  screen.
- KR design: TM Vault provides a Relearn Moves mode with its own Pokemon picker
  and move list. No party command or `PokemonPartyScreen` replacement is added.

### Egg and Event Moves

- Legacy key: `miscmods_egg_moves`
- Old target: `MoveRelearnerScreen#pbGetRelearnableMoves` plus global Nuzlocke
  compatibility methods.
- Risk: Medium. The move-list wrapper is narrow, but the global compatibility
  methods create ownership ambiguity.
- Decision: Audit complete; retained through TM Vault.
- KR design: TM Vault optionally merges Egg Moves into its owned Relearn Moves
  list and follows KIF's existing Event Moves setting. It does not replace
  `MoveRelearnerScreen` or add Nuzlocke compatibility methods.

### Level Locking

- KR state: namespaced per-Pokemon `@kanto_reloaded_data["level_lock"]`; the
  old `miscmods_level_locking` key and generic `@level_lock` field are not
  migrated.
- Old targets: `Pokemon#level=`, `#exp=`, `#changeHappiness`, `#calc_stats`,
  `PokeBattle_Battle#pbGainExpOne`, custom Pokemon instance variables, manager
  UI, and the complete party menu.
- Risk: Medium after redesign. Level and direct EXP assignments need guards,
  while battle calculations need the capped result before native level-up
  processing begins.
- Decision: Retained and redesigned as
  `Modules/QualityAssurance/LevelLocking.rb`.
- KR design: `KantoReloaded::LevelLocking` owns lock validation, assignment,
  removal, EXP ceilings, and battle notices. A lock allows the current EXP bar
  to fill to one point below the next level and does not bank excess EXP or
  generate Rare Candies.
- Runtime boundary: guarded `Pokemon#level=` and `#exp=` wrappers enforce direct
  changes. A private `pbChangeLevel` wrapper clamps its requested target before
  KIF chooses level-up messages, moves, and evolution. A guarded
  `PokeBattle_Battle#pbGainExpOne` wrapper establishes only the current gainer
  context, and a guarded `GameData::GrowthRate#add_exp` wrapper caps its native
  result only inside that context. The current `pbGainExpOne` and
  `pbChangeLevel` bodies, `changeHappiness`, `calc_stats`, party menu,
  Multiplayer, and KIF's global level-cap settings remain untouched.

### Level Lock Manager

- KR key: `level_lock_manager`; action only.
- Old targets: custom party-selection and number-input workflow, plus the
  complete party menu replacement.
- Risk: Low after the Level Locking API owns all mutations.
- Decision: Retained and redesigned as
  `Modules/QualityAssurance/LevelLockManager.rb`.
- KR design: uses KIF's native party picker plus KR's shared choice, digit
  Number Picker, confirmation, and toast APIs. Eggs are rejected. Lock values
  range from the Pokemon's current level through KIF's maximum level, and the
  same workflow can change or remove an existing lock.
- Integration: `Manage Level Locks` is a Quality of Life category action. The
  Overworld Menu exposes an optional `Level Lock Manager` action with lock-count
  status, disabled in the page editor by default. No party command is added.

### Super Candy

- KR key: `super_candy`; action only. The old
  `miscmods_super_candy_mode` and `miscmods_super_candy_level` values are not
  migrated.
- Old targets: custom party workflow that temporarily disables Level Locking,
  applies levels, teaches moves, recalculates stats, and triggers evolution.
- Risk: Medium after redesign because party-wide advancement crosses level,
  move-learning, and evolution boundaries.
- Decision: Retained and redesigned as
  `Modules/QualityAssurance/SuperCandy.rb`.
- KR design: the action offers KIF Level Cap, Highest Party Level, and Choose
  Level targets through shared KR popups. Choose Level uses KR's digit Number
  Picker. It only raises eligible party Pokemon, skips Eggs and Shadow Pokemon,
  and uses the lowest of the selected target, the KIF level cap, the Pokemon's
  personal Level Lock, and KIF's maximum level.
- Runtime boundary: KR advances one level at a time so intermediate moves and
  chained evolutions are not skipped. Move decisions run through KR's
  `MoveTeaching` level-up context, while KIF's native `pbEvolutionCheck` owns
  evolution methods, EvoLock behavior, scenes, and cancellation. Super Candy
  does not temporarily disable Level Locking, consume items, replace
  `pbChangeLevel`, or reproduce the old custom evolution table.
- Integration: `Super Candy` is a Quality of Life category action. The
  Overworld Menu entry is disabled in the page editor by default.

### Nature Selector

- Legacy key: none; action only.
- Old targets: custom party and nature-list UI, then `Pokemon#nature=` and
  `#calc_stats`.
- Risk: Medium. Data mutation is contained, but the UI should use KIF's native
  party picker and KR's shared list UI while preserving scene state.
- Decision: Retained and ported as
  `Modules/QualityAssurance/NatureSelector.rb`.
- KR design: uses KIF's native `PokemonPartyScreen` without replacing or
  aliasing it, and uses KR's shared popup choice list for nature selection.
  Eggs are rejected, Back returns from the nature list to the still-open party
  screen, and KIF's `Pokemon#nature=` setter owns stat recalculation.
- Stat behavior: an existing `nature_for_stats` override is cleared after the
  new nature is assigned so the selected nature controls both display and stat
  modifiers. No extra `calc_stats` call is made.
- Overworld Menu: optional action, disabled in the page editor by default.
- Migration: none; the legacy action had no saved setting.

### Reset Money

- Legacy key dependency: `miscmods_infinite_money`
- Old target: action that disables Infinite Money and assigns `3000`.
- Risk: Low, but it is part of the Infinite Money feature rather than a separate
  module.
- Decision: Retained as the `Reset Money` category action inside
  `Modules/QualityAssurance/InfiniteMoney.rb`, using the current game's
  `Settings::INITIAL_MONEY` value instead of hardcoding `3000`.

## Excluded Code

The monolith's Multiplayer platinum reporting, Nuzlocke faint commands,
follower commands, auto-update registration, custom QA settings scene, MSM
submenu, and Overworld Menu registration are not QA feature ports. KR will not
copy or modify Multiplayer, Mod Manager, MSM, or unrelated mod behavior.
The shared Overworld Menu now supplies the registration target separately from
QA; retained QA features may register there without restoring the old QA scene.

## Retirement Status

The later standalone `QualityAssurance` package contained only Infinite Repel
plus its MSM scene. Infinite Repel is now migrated and tested in KR, so that
package remains retired through `mod.json.disabled`. Its Ruby files remain
unchanged as reference.

The older monolith audit is complete. Every feature has been retained through a
KR-owned implementation, superseded by TM Vault or Super Candy, or deliberately
excluded because KIF already owns the behavior. The monolith remains
`10_Quality Assurance_old.rb.disabled` as read-only historical reference and is
not required at runtime.
