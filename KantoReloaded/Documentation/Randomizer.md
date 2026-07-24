# Randomizer

Kanto Reloaded's Randomizer module extends KIF's existing randomizer rather
than replacing it. The original Dynamic Randomiser concept is credited to
**An Unsocial Pigeon**.

## Settings

The `Randomizer` action is in Kanto Reloaded's `Gameplay` category. Its two KR
settings are per-save and default to Off:

- `randomizer.dynamic_wild`: chooses a new eligible species for each future
  normal wild encounter.
- `randomizer.wild_mode`: uses KIF's BST range or selects any eligible Pokemon
  randomly. BST Range is the default.
- `randomizer.dynamic_items`: chooses a new eligible item whenever KIF has
  already decided that a found or given item should be randomized.

`Dynamic Wild Pokemon` requires KIF's main `Pokemon` randomizer option to be
On. `Dynamic Items` likewise requires KIF's main `Items` randomizer option to
be On. Trying to adjust either KR setting without its prerequisite opens a
warning that identifies the required KIF option. If a prerequisite is disabled
later, KR preserves the saved setting but pauses that dynamic feature until the
KIF option is enabled again.

Changing either setting does not regenerate KIF's Global or Area mappings.
Those mappings remain intact underneath the dynamic layer and are visible
again as soon as the corresponding dynamic setting is disabled.

## KIF Rules

The module deliberately reuses KIF's existing controls:

- `Custom Sprites Only` selects the custom-sprite pool. When it is Off, all
  eligible Pokemon can appear.
- `Randomness degree` supplies the target BST range.
- `Wild Selection: Random` ignores the BST range while continuing to honor the
  selected Pokemon pool and legendary rules.
- `Allow legendaries` controls whether non-legendary encounters may become
  legendary. Existing legendary encounters still map to legendaries.
- Found Item, Found TM, Given Item, and Given TM options determine which item
  sources can invoke dynamic item selection.
- Item and TM randomizer toggles determine which item types are eligible.

KIF already owns randomization for wild Pokemon, trainers, Gyms, starters,
static encounters, gift Pokemon, found and given items or TMs, shops, trainer
held items, legendary handling, fusion behavior, and custom-sprite filtering.
KR does not duplicate those settings. KIF does not currently expose general
randomization for abilities, evolutions, or learned movesets, so those domains
are not changed by this module.

## Safety

Dynamic wild selection wraps `PokemonEncounters#choose_wild_pokemon`. It does
not wrap `pbGenerateWildPokemon`, so scripted Pokemon, gifts, static encounters,
roaming construction, NPC contest catches, and multiplayer-created copies are
not broadly intercepted. The selected level and encounter metadata are
preserved.

Dynamic item selection wraps `pbGetRandomItem`. Key items, HMs, KIF's protected
item lists, and internal/debug entries are excluded. TMs remain TMs, berries
remain berries, quantities are preserved by the calling KIF workflow, and a
failed candidate search returns the original value.

Species searches are bounded and widen their BST range only when necessary.
Species stats, legendary checks, custom-sprite IDs, and item pools are cached.
The last ten selected species are stored in KR's save bucket to reduce immediate
repeats. The Settings screen provides a command to clear that history.

## Migration

On first load, KR imports enabled values from the legacy Dynamic Randomiser
switches (`1700` for wild Pokemon and KIF's dynamic-item switch) only when the
new KR setting has not already been stored. KR does not continue writing those
legacy switches.
