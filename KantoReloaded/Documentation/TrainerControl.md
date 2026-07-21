# Trainer Control

Trainer Control is a Kanto Reloaded module for upward-only trainer level
scaling, deterministic team expansion, adaptive trainer builds, and per-save
trainer battle records.

## Team Expansion

- Modes include Off, Trainer Theme, Random, and Random Fusion.
- Sizing can add a fixed count or raise smaller teams to a target size.
- Generation is deterministic for the trainer identity and loaded-party species.
- Exact duplicate species are never added.
- Generated Random Fusion members do not reuse base components.
- KIF's New Pokemon disable setting is respected when building candidate pools.
- New members use the original trainer team's average level before Level
  Scaling processes the completed party.
- Generated Held Items can assign role- and type-appropriate items to 50% or
  all generated members. Assignment is deterministic and never overwrites an
  existing item. Duplicate generated items within one trainer party are avoided
  where another suitable item is available.
- While KIF reports an active Gym type, additions to every expanded trainer in
  that Gym must match the Gym type. Random Fusion additions are validated
  against the resulting fusion's types.
- Gym Leader Full Party fills a leader's team to six even when normal expansion
  is disabled. If KIF does not expose an active Gym type for the leader, added
  members fall back to the dominant type of the original loaded team.

## Level Scaling

- Scaling is disabled by default.
- The reference can be the highest non-Egg party level or the rounded party
  average.
- The signed level offset supports values from -99 through +99.
- Scaling only raises trainer levels.
- Preserved level spread applies one upward difference across the trainer team.
- KIF scripted level overrides remain authoritative.
- Moves, evolutions, abilities, and held items are not changed.

Regular trainers, Gym Leaders, and rematches can be enabled independently.
Cooperative battles, active Battle Frontier challenges, and scripted no-EXP
battles are excluded.

## Trainer Adaptation

- Memory is separated by the exact trainer identity and version.
- The last five decisive battles store only compact counts for deployed Pokemon
  types, successful move types, successful strategies, and player leads.
- A loss updates observations and permits one saved sidegrade for the next
  encounter. Loss sidegrades may rotate a move, held item, or lead, but cannot
  add a Pokemon, evolve a Pokemon, or expand the trainer's battle inventory.
- A player win commits a new behavior snapshot and increments its revision.
- Each win gives the next battle up to three saved adaptation changes.
- Starting with the seventh win, the next battle receives up to four changes.
- Every exact trainer version receives one stable Balanced, Aggressive,
  Defensive, or Control archetype. The archetype weights which valid responses
  are more likely without forcing identical teams.
- Recorded behavior weights the change selection: player and lead types favor
  counter coverage and Counter Pokemon; setup and healing favor disruption;
  hazards and status favor removal or protective items; common move types favor
  resistance items and defensive Counter Pokemon.
- Changes rotate among held items, trainer battle items, compatible counter
  coverage, strategy responses, ordinary level-up evolutions, stronger
  level-up moves, and a possible Counter Pokemon.
- Role-aware nature optimization applies to the full trainer party for free and
  does not consume one of the three or four pending changes.
- Lead order is selected for the player's recently observed leads without
  consuming a pending change.
- Each trainer's highest-level authored member is saved as its ace. Ordinary
  trainer adaptation may replace other authored members, but never the ace.
- The adapted party is stored as a compact per-trainer blueprint. Later fights
  restore that party and apply only newly earned win changes instead of starting
  again from the authored party.
- Recent adaptive items, moves, and Counter Pokemon receive temporary selection
  penalties. They remain possible, but less familiar valid responses retain a
  baseline chance.
- Counter Pokemon are randomly selected from the full suitable themed pool with
  better offensive and defensive matches receiving more weight.
- Adaptive held items avoid duplicates within the party where possible. Full
  Restore, potions, Full Heal, and battle-stat items are added to the trainer's
  functional battle inventory rather than assigned as held items.
- Counter Pokemon are eligible after the first win rather than waiting for four
  victories.
- Authored Pokemon may be replaced only for ordinary trainers. Gym Leaders,
  Bosses, Elite Four members, and Champions keep their authored roster members.
- Counter Pokemon retain the active Gym type. Trainer-theme restrictions apply
  to ordinary trainers only while Team Expansion is in Trainer Theme mode.
- Adaptation runs after Team Expansion and before Level Scaling.

Progression Rewards can grant one-time money and item bonuses at 3, 7, and 12
wins against each exact trainer version. Claimed milestones are stored in the
same trainer memory and cannot be repeatedly farmed at the same milestone.

## Pink Slips

- Pink Slips is disabled by default and only participates in eligible
  single-trainer battles.
- Rivals, Gym Leaders, Elite Four members, Champions, bosses, runtime-scripted
  trainers, cooperative battles, battle facilities, and scripted no-EXP
  battles are excluded.
- Eggs and the player's last usable Pokemon cannot be wagered.
- A decisive winner chooses one eligible Pokemon from the losing side. Drawn,
  aborted, and forfeited battles void the wager.
- Repeat Wagers is disabled by default. Trainer history uses Trainer Control's
  exact identity and version rather than a map/name key.
- Won Pokemon are freshly generated from the selected species, fusion, and
  form. They receive fresh personal values, zero EVs, normal level-up moves,
  no held item, and retain the defeated trainer as their original trainer.
- A prize joins the party when space is available and otherwise goes directly
  to Pokemon Storage. If both are full, the complete prize remains pending in
  the Kanto Reloaded save bucket.
- A lost wagered Pokemon is removed by runtime identity rather than a stale
  party index. Its held item returns to the Bag, then KIF's PC Item Storage;
  if both are full, the item remains pending.
- Persistent roster operations run after the saved adapted roster is restored,
  before Team Expansion adds members. Newly earned adaptation is then applied,
  followed by Level Scaling.
- Pink Slips uses Trainer Control's existing battle wrapper and does not add a
  separate base-method alias or per-frame polling.

## Battle Records

Records are stored in the Kanto Reloaded save bucket and track:

- wins
- losses
- total battles
- current winning streak
- best winning streak
- calculated win percentage

Only battle decisions 1 and 2 are recorded. Each opposing trainer in a
multi-trainer battle receives a result. The optional pre-battle record popup
uses the success theme above 50%, the normal theme at 50%, and the error theme
below 50%.

The records viewer supports searching, filtering, sorting, individual resets,
and a module-level reset-all action. Hidden adaptation state is intentionally
excluded from the player-facing records UI. Existing records
from legacy game variable 999 are imported once without changing the original
variable.

The separately managed `KRTrainerControlInspector` mod exposes archetypes,
saved parties, ace and Pink Slips member markers, revisions, recent choices,
bounded change history, Pink Slips roster operations, capture status, and
pending transfers for development testing. It is not required by Kanto
Reloaded and can be disabled or deleted when testing is complete.

## Base Integration

Trainer Control does not edit base scripts. It uses guarded Kanto Reloaded
wrappers around the available KIF trainer-data `to_trainer` implementations,
`pbTrainerBattleCore`, `PokeBattle_Battler#pbInitialize`, and
`PokeBattle_Battler#pbUseMove`, plus an additive `Events.onTrainerPartyLoad`
handler while a trainer battle context is active.
