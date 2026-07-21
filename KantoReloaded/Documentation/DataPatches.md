#======================================================
# Kanto Reloaded Data Patches
# Author: Stonewall
#======================================================
# Documents the Kanto Reloaded runtime data patch system.
#
# Responsibilities:
#   - Explain where mods put data patch files.
#   - Define supported data patch operations.
#   - Explain validation, conflicts, logging, and runtime access.
#   - Show examples for mod authors.
#
#======================================================

`KantoReloaded::DataPatches` lets enabled mods add or change structured runtime data
without replacing whole base game files.

This runtime layer is intentionally conservative. It collects, validates, logs,
and applies JSON-style data in memory only. It does not permanently rewrite base
game `.dat`, `.rxdata`, `.json`, or PBS files.

## Quick Summary

Data patches are mod-provided JSON files that safely add or change game data at
runtime. They are useful for adding modded items, changing move/species data,
adding trainers, editing encounters, or extending outfit data without replacing
vanilla data files.

Supported data patch targets:

- `items` - add or edit item data, including name, pocket, price, description, use flags, type, and move link.
- `moves` - add or edit move data, including type, category, power, accuracy, PP, effects, flags, and descriptions.
- `abilities` - add or edit ability names, descriptions, and related metadata.
- `species.core` - edit core species data such as names, stats, types, gender ratio, growth, egg groups, moves metadata, and flags.
- `species.learnsets` - add, replace, or edit species level-up learnsets.
- `species.evolutions` - add, replace, or edit species evolution data.
- `species.abilities` - edit regular, hidden, and special ability lists for species.
- `trainer_types` - add or edit trainer type data such as display names, battle BGM, gender, base money, skill, and sprites.
- `trainers.classic` - add or edit trainers in Classic mode.
- `trainers.remix` - add or edit trainers in Remix mode.
- `trainers.expert` - add or edit trainers in Expert mode.
- `encounters.classic` - add or edit wild encounter data in Classic mode.
- `encounters.remix` - add or edit wild encounter data in Remix mode.
- `encounters.randomized` - add or edit wild encounter data in Randomized mode.
- `outfits.clothes` - add or edit clothing outfit definitions.
- `outfits.hats` - add or edit hat outfit definitions.
- `outfits.hairstyles` - add or edit hairstyle outfit definitions.

## Folder Layout

Mods can include data patches here:

```text
Mods/<Mod Folder>/DataPatches/*.json
Mods/<Mod Folder>/DataPatches/**/*.json
```

`ModDev/<Mod Folder>/DataPatches/` works the same way when ModDev is enabled.

## Supported Operations

- `add` - Creates a new runtime entry. Fails if the entry already exists.
- `edit` - Changes existing fields only. Fails if the entry or field is missing.
- `merge` - Deep-merges into an existing entry. May add new fields.
- `replace` - Replaces the full runtime entry.

`remove` is intentionally not supported.

## Patch File Format

A file can contain one patch object:

```json
{
  "target": "example_data",
  "operation": "add",
  "id": "example_entry",
  "data": {
    "name": "Example Entry",
    "value": 10
  }
}
```

Or a grouped patch file:

```json
{
  "target": "example_data",
  "patches": [
    {
      "operation": "add",
      "id": "example_entry",
      "data": {
        "name": "Example Entry",
        "value": 10
      }
    },
    {
      "operation": "merge",
      "id": "example_entry",
      "data": {
        "flags": {
          "visible": true
        }
      }
    }
  ]
}
```

Or an array of patch objects:

```json
[
  {
    "target": "example_data",
    "operation": "add",
    "id": "entry_one",
    "data": {
      "name": "Entry One"
    }
  }
]
```

## Runtime API

Read all patched data:

```ruby
KantoReloaded::DataPatches.data
```

Read one target:

```ruby
KantoReloaded::DataPatches.data("example_data")
```

Read one entry:

```ruby
KantoReloaded::DataPatches.entry("example_data", "example_entry")
```

Register a Kanto Reloaded-owned runtime target before patches are rebuilt:

```ruby
KantoReloaded::DataPatches.register_target(
  "example_data",
  {
    "base_entry" => {
      "name" => "Base Entry",
      "value" => 1
    }
  },
  owner: :reloaded,
  description: "Example runtime data target."
)
```

Query status:

```ruby
KantoReloaded::DataPatches.summary
KantoReloaded::DataPatches.patches
KantoReloaded::DataPatches.applied
KantoReloaded::DataPatches.errors
KantoReloaded::DataPatches.warnings
```

## Built-In Runtime Targets

Kanto Reloaded currently includes these direct runtime targets:

- `items`
- `moves`
- `abilities`
- `species.core`
- `species.learnsets`
- `species.evolutions`
- `species.abilities`
- `trainer_types`
- `trainers.classic`
- `trainers.remix`
- `trainers.expert`
- `encounters.classic`
- `encounters.remix`
- `encounters.randomized`
- `outfits.clothes`
- `outfits.hats`
- `outfits.hairstyles`

### Items

`items` patches apply to `GameData::Item::DATA` at runtime. They do not edit
`Data/items.dat`.

Example item entry:

```json
{
  "target": "items",
  "operation": "add",
  "id": "example_reloaded_item",
  "data": {
    "name": "Example Kanto Reloaded Item",
    "name_plural": "Example Kanto Reloaded Items",
    "pocket": 1,
    "price": 100,
    "description": "A safe example item added by a Kanto Reloaded data patch.",
    "field_use": 0,
    "battle_use": 0,
    "type": 0
  }
}
```

Supported item fields:

- `id`
- `id_number`
- `name`
- `name_plural`
- `pocket`
- `price`
- `description`
- `field_use`
- `battle_use`
- `type`
- `move`

`id_number` is optional. If omitted, Kanto Reloaded assigns the next available item
number at runtime. Advanced mods may provide an explicit `id_number`, but it
must not conflict with another item.

Item data patches only add or change item data. If an item needs custom field,
battle, or use behavior, the mod should add that behavior through scripts in
its `Scripts/` folder.

### Moves

`moves` patches apply to `GameData::Move::DATA` at runtime. They do not edit
`Data/moves.dat`.

Example move entry:

```json
{
  "target": "moves",
  "operation": "add",
  "id": "example_reloaded_move",
  "data": {
    "name": "Example Kanto Reloaded Move",
    "function_code": "000",
    "base_damage": 40,
    "type": "NORMAL",
    "category": "Physical",
    "accuracy": 100,
    "total_pp": 35,
    "effect_chance": 0,
    "target": "NearOther",
    "priority": 0,
    "flags": "abef",
    "description": "A safe example move added by a Kanto Reloaded data patch."
  }
}
```

Supported move fields:

- `id`
- `id_number`
- `name`
- `function_code`
- `base_damage`
- `type`
- `category`
- `accuracy`
- `total_pp`
- `effect_chance`
- `target`
- `priority`
- `flags`
- `description`

`id_number` is optional. If omitted, Kanto Reloaded assigns the next available move
number at runtime. Advanced mods may provide an explicit `id_number`, but it
must not conflict with another move.

Move field notes:

- `function_code` tells the battle engine which special move behavior class to
  use. This game uses classic numeric/hex function codes such as `000`, `005`,
  and `0F2`. Use `000` for a normal damage-only move. Use another vanilla move's
  function code to reuse that move's special behavior. Brand-new behavior still
  requires a Ruby script defining the matching `PokeBattle_Move_<code>` class.
- `base_damage` is the move's base power. Use `0` for status moves.
- `type` is a type ID such as `NORMAL`, `FIRE`, `WATER`, or `FAIRY`.
- `category` can be `Physical`, `Special`, `Status`, or the matching numeric
  values `0`, `1`, `2`.
- `accuracy` is the move accuracy percent.
- `total_pp` is the move's maximum PP before PP Ups.
- `effect_chance` is the percent chance for the move's secondary effect.
- `target` is the battle target mode. Common values include `NearOther`, `User`,
  `NearFoe`, `AllNearFoes`, `UserAndAllies`, `FoeSide`, and `BothSides`.
  Kanto Reloaded resolves this against `GameData::Target`, so `nearother`,
  `NEAROTHER`, and `NearOther` all resolve back to the engine ID `NearOther`.
- `priority` controls turn order. `0` is normal, positive numbers move earlier,
  and negative numbers move later.
- `flags` is a compact string of behavior letters. The currently used flags are:
  `a` contact, `b` affected by Protect, `c` Magic Coat, `d` Snatch, `e` Mirror
  Move, `f` King's Rock/Razor Fang/Stench, `g` thaws the user, `h` high critical
  rate, `i` biting move, `j` punching move, `k` sound move, `l` powder move,
  `m` pulse move, `n` bomb move, and `o` dance move.

Move data patches only add or change move data. If a move needs custom battle
behavior that does not already exist, the mod should add that behavior through
scripts in its `Scripts/` folder.

### Abilities

`abilities` patches apply to `GameData::Ability::DATA` at runtime. They do not
edit `Data/abilities.dat`.

Example ability entry:

```json
{
  "target": "abilities",
  "operation": "add",
  "id": "example_reloaded_ability",
  "data": {
    "name": "Example Kanto Reloaded Ability",
    "description": "A safe example ability added by a Kanto Reloaded data patch."
  }
}
```

Supported ability fields:

- `id`
- `id_number`
- `name`
- `description`

`id_number` is optional. If omitted, Kanto Reloaded assigns the next available
ability number at runtime. Advanced mods may provide an explicit `id_number`,
but it must not conflict with another ability.

Ability data patches only add or change ability data. If an ability needs custom
battle behavior, the mod should add that behavior through scripts in its
`Scripts/` folder by registering or wrapping the relevant battle handlers.

### Species Core Data

`species.core` patches apply to core fields on existing `GameData::Species`
entries. This target does not add new species and does not patch learnsets,
evolutions, forms, encounters, or trainer usage.

Example species core entry:

```json
{
  "target": "species.core",
  "operation": "merge",
  "id": "treecko",
  "data": {
    "type1": "grass",
    "type2": "grass",
    "base_stats": {
      "HP": 40,
      "ATTACK": 45,
      "DEFENSE": 35,
      "SPECIAL_ATTACK": 65,
      "SPECIAL_DEFENSE": 55,
      "SPEED": 75
    },
    "catch_rate": 45,
    "hatch_steps": 5120
  }
}
```

Supported core fields:

- `name`
- `form_name`
- `category`
- `pokedex_entry`
- `pokedex_form`
- `type1`
- `type2`
- `base_stats`
- `evs`
- `base_exp`
- `growth_rate`
- `gender_ratio`
- `catch_rate`
- `happiness`
- `wild_item_common`
- `wild_item_uncommon`
- `wild_item_rare`
- `egg_groups`
- `hatch_steps`
- `incense`
- `height`
- `weight`
- `color`
- `shape`
- `habitat`
- `generation`

Stat hashes use the base stat IDs:

```json
{
  "HP": 40,
  "ATTACK": 45,
  "DEFENSE": 35,
  "SPECIAL_ATTACK": 65,
  "SPECIAL_DEFENSE": 55,
  "SPEED": 75
}
```

Species core enum fields are resolved against the engine's real GameData IDs.
This matters for mixed-case IDs such as `growth_rate`, `gender_ratio`,
`egg_groups`, `color`, `shape`, and `habitat`. For example, `parabolic`,
`PARABOLIC`, and `Parabolic` resolve back to the engine ID `Parabolic`.

`base_stats` and `evs` can be partial objects when using `merge`. Kanto Reloaded keeps
the vanilla values for omitted stats and only changes the provided stats. For
example, a patch with only `"SPEED": 75` keeps the original HP, Attack, Defense,
Special Attack, and Special Defense values.

`merge` is recommended for small species edits. Use `replace` only when the
patch provides the complete core species entry.

Existing saved Pokemon may keep already-calculated or cached values until they
are refreshed by the base game. New/generated Pokemon use the patched species
core data.

### Species Learnsets

`species.learnsets` patches apply to level-up moves, tutor moves, and egg moves
on existing `GameData::Species` entries. This target does not patch evolutions
or forms.

Small additive patch:

```json
{
  "target": "species.learnsets",
  "operation": "merge",
  "id": "treecko",
  "data": {
    "add_moves": [
      {
        "level": 8,
        "move": "example_reloaded_move"
      }
    ],
    "add_tutor_moves": ["example_reloaded_move"],
    "add_egg_moves": ["example_reloaded_move"]
  }
}
```

Full replacement patch:

```json
{
  "target": "species.learnsets",
  "operation": "replace",
  "id": "treecko",
  "data": {
    "moves": [
      {
        "level": 1,
        "move": "pound"
      },
      {
        "level": 8,
        "move": "example_reloaded_move"
      }
    ],
    "tutor_moves": ["example_reloaded_move"],
    "egg_moves": []
  }
}
```

Supported learnset fields:

- `moves` - full level-up move list replacement.
- `add_moves` - additive level-up move entries.
- `tutor_moves` - full tutor move list replacement.
- `add_tutor_moves` - additive tutor moves.
- `egg_moves` - full egg move list replacement.
- `add_egg_moves` - additive egg moves.

Level-up moves can be written as objects:

```json
{
  "level": 8,
  "move": "example_reloaded_move"
}
```

or compact arrays:

```json
[8, "example_reloaded_move"]
```

`add_*` fields ignore exact duplicates. `remove` is not supported, so replacing
the full relevant list is the current way to intentionally omit a vanilla move.

### Species Evolutions

`species.evolutions` patches apply to forward evolution entries on existing
`GameData::Species` entries. Kanto Reloaded rebuilds generated prevolution entries
after applying evolution patches so family/evolution checks stay consistent.

Small additive patch:

```json
{
  "target": "species.evolutions",
  "operation": "merge",
  "id": "treecko",
  "data": {
    "add_evolutions": [
      {
        "species": "grovyle",
        "method": "Level",
        "parameter": 16
      }
    ]
  }
}
```

Full replacement patch:

```json
{
  "target": "species.evolutions",
  "operation": "replace",
  "id": "treecko",
  "data": {
    "evolutions": [
      {
        "species": "grovyle",
        "method": "Level",
        "parameter": 16
      }
    ]
  }
}
```

Supported evolution fields:

- `evolutions` - full forward evolution list replacement.
- `add_evolutions` - additive forward evolution entries.

Evolution entries use:

- `species` - target species ID.
- `method` - evolution method ID, such as `Level`, `Item`, or another base game
  evolution method.
- `parameter` - the method parameter. Level methods usually use a number. Item,
  move, species, map, and type methods usually use an ID.

Evolution method IDs are resolved against `GameData::Evolution`, so `level`,
`LEVEL`, and `Level` resolve back to the engine ID `Level`.

Evolution parameters for `Item`, `Move`, `Species`, and `Type` methods are
resolved against their matching `GameData` tables, so common casing differences
are corrected before runtime.

`add_evolutions` ignores exact duplicates. `remove` is not supported, so
replacing the full `evolutions` list is the current way to intentionally omit a
vanilla evolution.

### Trainers

Trainer patches apply to runtime `GameData::Trainer` records. The game has three
trainer datasets, so Kanto Reloaded exposes three targets:

- `trainers.classic` - base/classic trainer data.
- `trainers.remix` - remix/modern trainer data.
- `trainers.expert` - expert trainer data.

Trainer patch IDs use this format:

```text
TRAINER_TYPE|Trainer Name|Version
```

Example trainer entry:

```json
{
  "target": "trainers.classic",
  "operation": "merge",
  "id": "YOUNGSTER|Kanto Reloaded Example|0",
  "data": {
    "bag_items": ["POTION"],
    "battle_text": "Kanto Reloaded data patch trainer test!",
    "lose_text": "That was a Kanto Reloaded trainer data patch.",
    "trainer_info": "Example trainer created by a Kanto Reloaded trainer data patch.",
    "add_pokemon": [
      {
        "species": "poochyena",
        "level": 5,
        "held_item": "ORANBERRY",
        "moves": ["tackle"]
      }
    ]
  }
}
```

Supported trainer fields:

- `trainer_type`
- `name`
- `version`
- `id_number`
- `items`
- `bag_items`
- `lose_text`
- `rematch_lose_text`
- `rematch_double_lose_text`
- `battle_text`
- `pre_rematch_text`
- `pre_rematch_caught_text`
- `pre_rematch_evolved_text`
- `pre_rematch_fused_text`
- `pre_rematch_unfused_text`
- `pre_rematch_reversed_text`
- `pre_rematch_gift_text`
- `trainer_info`
- `info_text`
- `pokemon`
- `replace_pokemon`
- `edit_pokemon`
- `add_pokemon`

`items` is the base game trainer battle item list. Kanto Reloaded also accepts
`bag_items` as a clearer alias for the same field. These items are assigned to
the opposing trainer's battle inventory, not held by Pokemon.

`pokemon` replaces or defines the full party. `replace_pokemon` replaces a
specific party slot. `edit_pokemon` merges changes into an existing party slot.
`add_pokemon` appends new Pokemon until the party reaches the normal party size
limit.

Trainer text metadata:

- `battle_text` - intro text used by trainer systems that read
  `GameData::Trainer#battleText`.
- `lose_text` - normal post-battle lose text.
- `rematch_lose_text` - rematch lose text.
- `rematch_double_lose_text` - double-rematch lose text.
- `pre_rematch_text` - default pre-rematch prompt.
- `pre_rematch_caught_text`, `pre_rematch_evolved_text`,
  `pre_rematch_fused_text`, `pre_rematch_unfused_text`,
  `pre_rematch_reversed_text`, and `pre_rematch_gift_text` - specialized
  rematch/event prompts used by phone/rematch systems.
- `trainer_info` or `info_text` - trainer info text used by systems such as
  contact/info pages.

Some trainer dialogue is event-scripted. If the map event writes text directly
instead of reading `GameData::Trainer`, that text must be changed with a script
hook or event edit instead of a trainer data patch.

Party slot entries use zero-based slots:

```json
{
  "slot": 0,
  "data": {
    "species": "zigzagoon",
    "level": 5
  }
}
```

Supported Pokemon fields:

- `species`
- `level`
- `form`
- `name`
- `moves`
- `moves_hard`
- `moves_easy`
- `ability`
- `ability_index`
- `item`
- `held_item`
- `gender`
- `nature`
- `iv`
- `ev`
- `happiness`
- `shininess`
- `shadowness`
- `poke_ball`

IDs for species, moves, abilities, items, and natures are resolved against their
matching `GameData` tables, so common casing differences are corrected before
runtime.

`item` is the base game held item field for a trainer Pokemon. Kanto Reloaded also
accepts `held_item` as a clearer alias for the same field. If both are present,
`item` wins.

Trainer patch validation:

- Species IDs are required for party members. If a trainer Pokemon references an
  unknown species, Kanto Reloaded logs an error and skips that party member.
- Trainer bag items, held items, moves, and abilities are checked against their
  matching `GameData` tables. Unknown optional IDs are logged as warnings and
  omitted from the runtime trainer data.
- `edit_pokemon` references existing zero-based party slots only. If the slot
  does not exist, Kanto Reloaded logs a warning and ignores that edit. Use
  `add_pokemon` to append a new party member.
- `replace_pokemon` references existing zero-based party slots only. If the slot
  does not exist, Kanto Reloaded logs a warning and ignores that replacement. Use
  `add_pokemon` to append a new party member.
- Patches that target a missing trainer without using `add` are logged as
  warnings. Check the trainer type, trainer name, and version if the patch was
  meant to modify an existing trainer.

Some story battles are not backed by `GameData::Trainer` and are created
dynamically in scripts. Those battles should be changed with a focused script
hook instead of a trainer data patch.

### Trainer Types

Trainer type patches apply to runtime `GameData::TrainerType` records. Use these
for AI skill data and trainer-class-wide settings.

Example trainer type AI patch:

```json
{
  "target": "trainer_types",
  "operation": "merge",
  "id": "YOUNGSTER",
  "data": {
    "ai_skill_level": 32,
    "ai_flags": "RLD",
    "reward_money": 40
  }
}
```

Supported trainer type fields:

- `id`
- `id_number`
- `name`
- `base_money`
- `money`
- `reward_money`
- `battle_BGM`
- `victory_ME`
- `intro_ME`
- `gender`
- `skill_level`
- `ai_skill_level`
- `skill_code`
- `ai_flags`

`skill_level` is the base engine AI value. Kanto Reloaded also accepts
`ai_skill_level` as a clearer alias. Valid values are clamped to `0..255`.

`base_money` controls the trainer type reward multiplier used after battle.
Kanto Reloaded also accepts `money` and `reward_money` as clearer aliases. This is
trainer-type-wide, not per individual trainer.

The engine's default AI thresholds are:

- `0` - wild Pokemon/no trainer AI.
- `1..15` - basic trainer AI.
- `16..31` - medium trainer AI.
- `32..99` - high trainer AI.
- `100+` - best trainer AI.

`skill_code` is the base engine's compact skill flag string. Kanto Reloaded also
accepts `ai_flags` as a clearer alias. Flags are sanitized to letters, numbers,
and underscores only because the base helper checks the string with a regex.

Trainer type patches affect every trainer using that trainer type while the mod
is enabled. For example, patching `YOUNGSTER` changes all Youngster trainers.

### Encounters

Encounter patches apply to runtime wild encounter data. The game has three
encounter datasets, so Kanto Reloaded exposes three targets:

- `encounters.classic` - base/classic encounter tables.
- `encounters.remix` - remix/modern encounter tables.
- `encounters.randomized` - randomized encounter tables.

Encounter entry IDs use:

```text
<map_id>_<version>
```

For example, map `999`, version `0` is `999_0`.

Use `MapIDs.md` when checking map IDs from `Data/MapInfos.rxdata`.

Example new encounter map entry:

```json
{
  "target": "encounters.classic",
  "operation": "add",
  "id": "999_0",
  "data": {
    "map": 999,
    "version": 0,
    "step_chances": {
      "Land": 10
    },
    "types": {
      "Land": [
        {
          "chance": 100,
          "species": "treecko",
          "min_level": 5,
          "max_level": 5
        }
      ]
    }
  }
}
```

Example additive encounter patch for an existing map/version:

```json
{
  "target": "encounters.classic",
  "operation": "merge",
  "id": "101_0",
  "data": {
    "add_types": {
      "Land": [
        {
          "chance": 5,
          "species": "example_species",
          "min_level": 8,
          "max_level": 10
        }
      ]
    }
  }
}
```

Supported encounter fields:

- `map` - numeric map ID.
- `version` - numeric encounter version.
- `step_chances` - encounter trigger chances by encounter type.
- `types` - full encounter tables by encounter type.
- `add_types` - additive encounter table entries by encounter type.

Encounter type names are resolved against the engine's encounter type IDs, so
`land`, `LAND`, and `Land` all resolve back to `Land`.

The engine checks time-specific land tables before plain `Land`. If a map defines
`LandMorning`, `LandDay`, `LandAfternoon`, `LandEvening`, or `LandNight`, patch
the specific table you want to affect.

Encounter table entries use:

- `chance`
- `species`
- `min_level`
- `max_level`

Compact array entries are also accepted:

```json
[100, "treecko", 5, 5]
```

Use `add_types` for small additions. Use `types` only when replacing or defining
encounter tables for specific encounter types. When using `merge`, omitted
`step_chances` and omitted encounter types keep their vanilla values. `types`
replaces the listed encounter type tables, while `add_types` appends entries to
the listed encounter type tables.

Kanto Reloaded also syncs the active `PokemonEncounters` cache after encounter patches
apply and when a map builds its encounter cache. Developer logs include the
requested encounter version, the actual data version, and the final Land table
for the map, which helps diagnose map-version mismatches.

### Species Ability Lists

`species.abilities` patches apply only to the ability lists on existing
`GameData::Species` entries. This target does not patch stats, moves, forms,
evolutions, egg groups, or other species data yet.

Example species ability entry:

```json
{
  "target": "species.abilities",
  "operation": "replace",
  "id": "treecko",
  "data": {
    "abilities": ["overgrow"],
    "hidden_abilities": ["example_reloaded_ability"]
  }
}
```

Supported fields:

- `abilities`
- `hidden_abilities`

For now, use `replace` for this target and provide the full normal and hidden
ability arrays. This keeps the result explicit and avoids relying on partial
array merge behavior.

Existing saved Pokemon can keep their already assigned/cached ability. New or
regenerated Pokemon follow the patched species ability lists.

### Outfits

These targets patch the base outfit lists after the base game loads
`Data/outfits/*.json`. They do not edit the original JSON files.

Example outfit entry:

```json
{
  "target": "outfits.clothes",
  "operation": "add",
  "id": "exampleKantoReloadedOutfit",
  "data": {
    "id": "exampleKantoReloadedOutfit",
    "author": "Stonewall",
    "name": "Example Kanto Reloaded Outfit",
    "description": "A safe example outfit entry.",
    "price": 100,
    "tags": "mod, example",
    "storelocation": "lilycove",
    "regiontags": "hoenn",
    "contestcondition": "cool"
  }
}
```

Supported outfit fields match the base outfit JSON fields used by the game:

- `id`
- `name`
- `description`
- `price`
- `tags`
- `storelocation`
- `regiontags`
- `pokemontags`
- `contestcondition`

## Data Patch Bridge Files

Data patch code lives in the `008` core range:

- `Core/DataPatches/Registry.rb` - generic scanner, validator, conflict registration, and
  runtime registry.
- `Core/DataPatches/Outfits.rb` - active outfit bridge for clothes, hats, and
  hairstyles.
- `Core/DataPatches/Items.rb` - active item bridge for `GameData::Item::DATA`.
- `Core/DataPatches/Moves.rb` - active move bridge for `GameData::Move::DATA`.
- `Core/DataPatches/Abilities.rb` - active ability bridge for
  `GameData::Ability::DATA`.
- `Core/DataPatches/AbilityAPI.rb` - script-facing ability helper API for data and battle
  handler behavior.
- `Core/DataPatches/Species.rb` - active bridge for species core data, learnsets,
  evolutions, and ability lists.
- `Core/DataPatches/Trainers.rb` - active bridge for classic, remix, and expert
  trainer parties, trainer bag items, held items, text metadata, and validation.
- `Core/DataPatches/Encounters.rb` - active encounter bridge for classic, remix,
  and randomized wild encounter tables.
- `Core/DataPatches/TrainerTypes.rb` - active bridge for trainer type AI skill
  data, skill code flags, and reward money multipliers.
- `Core/DataPatches/Quests.rb` - reserved quest bridge.

Reserved bridge files are intentionally loaded but inactive. They give future
data groups dedicated files without claiming that direct base-game data mutation
is already supported.

Shop/mart data is intentionally not part of the data patch bridge. Kanto Reloaded
shop behavior will belong to the future Economy/Kanto Reloaded Mart system instead.

## Validation

Each patch must include:

- `target`
- `operation`
- `id`
- `data`

`data` must be a JSON object.

Invalid patches are skipped and logged through `KantoReloaded::Log`. The data patch
system writes summary counts into the main Kanto Reloaded log.

GameData-backed patch targets also validate runtime references before writing
into the engine data tables:

- item patches reject invalid `id_number` values and unknown linked `move` IDs;
- move patches reject invalid `id_number` values, unknown `type` IDs, unknown
  `target` IDs, invalid categories, invalid accuracy values, and invalid PP;
- ability patches reject invalid `id_number` values and empty names;
- species core patches reject unknown type, growth rate, gender ratio, item,
  egg group, color, shape, and habitat IDs;
- species `base_stats` and `evs` must be stat objects using valid stat names and
  numeric values;
- species learnset patches reject unknown move IDs;
- species ability-list patches reject unknown ability IDs;
- species evolution patches reject unknown target species and unknown evolution
  methods;
- encounter patches reject unknown encounter types, unknown species, invalid
  chances, invalid map IDs, and invalid level ranges;
- trainer patches reject unknown required trainer types, unknown required
  Pokemon species, invalid Pokemon levels, and invalid party slot edits;
- trainer optional IDs such as moves, held items, bag items, abilities, and
  natures are checked against their matching `GameData` tables and omitted with
  warnings if invalid.

Validation is intentionally strict for data that can crash battles, saves,
evolutions, encounters, or debug menus. If a patch is rejected, check
`Mods/KantoReloaded/Logging/Log.txt` for the exact field and ID that failed.

## Conflicts

The Data Patches registry tracks collisions internally; it does not require the
separate HR patch-conflict framework.

Conflict behavior:

- duplicate `add`/`replace` patches for the same target and ID are blocked,
- duplicate `replace` patches for the same target and ID are blocked,
- multiple `edit`/`merge` patches touching the same field warn that load order
  decides the final value,
- `remove` patches are rejected as unsupported.

## Events

After rebuilding, Kanto Reloaded emits:

```ruby
:data_patches_loaded
```

The event context includes:

- `:summary`
- `:patches`
- `:applied`
- `:errors`
- `:warnings`

GameData-backed targets such as species data may defer `edit` and `merge`
patches during the earliest boot pass if the base data has not loaded yet.
Kanto Reloaded rebuilds those patches automatically after `GameData.load_all`.

## Current Scope

This is the foundation for safe mod data. It does not yet patch species forms,
maps, or quests directly. Those targets should be added one at a time after
their base data structures are reviewed.
