# Data Patches

Data Patches let a mod change the game's data with JSON files instead of replacing the game's data files. A mod can add items, moves and abilities, change Pokémon, trainers and wild encounters, and add or change outfits.

Kanto Reloaded applies the patches in memory, every time the game loads its data. It never writes them into the game's files, so switching the mod off gives the game its own data back. A patch that fails a check is skipped with a reason in plain words, and the game keeps its own data for that entry. Nothing crashes.

Data patches need Kanto Reloaded. It reads the `DataPatches` folder of every mod that's on, so a mod made only of patches needs no scripts, just a `mod.json`. The code lives in `Core/DataPatches`.

## Quick Summary

| Target | Shows As | What It Changes |
|---|---|---|
| `items` | Items | Name, pocket, price, description, how it's used, the move a TM teaches |
| `moves` | Moves | Type, category, power, accuracy, PP, target, priority, flags, effect |
| `abilities` | Abilities | Name and description (what an ability does comes from scripts) |
| `trainer_types` | Trainer Types | A trainer class's name, prize money, music, gender and AI skill |
| `species.core` | Species | A Pokémon's names, types, stats, EVs, growth, gender ratio, catch rate, egg groups, wild items and size |
| `species.learnsets` | Learnsets | Level-up, tutor and egg moves |
| `species.evolutions` | Evolutions | What a Pokémon evolves into, and how |
| `species.abilities` | Species Abilities | A Pokémon's abilities and hidden abilities |
| `trainers.classic` | Trainers | Trainers in Classic mode |
| `trainers.remix` | Remix Trainers | Trainers in Remix mode |
| `trainers.expert` | Expert Trainers | Trainers in Expert mode |
| `encounters.classic` | Encounters | Wild Pokémon in Classic mode |
| `encounters.remix` | Remix Encounters | Wild Pokémon in Remix mode |
| `encounters.randomized` | Random Encounters | Wild Pokémon in KIF's randomized tables |
| `outfits.clothes` | Clothes | Clothes |
| `outfits.hats` | Hats | Hats |
| `outfits.hairstyles` | Hairstyles | Hairstyles |

**Shows As** is the name the Patch Viewer and the messages use.

## Folder Layout

```text
Mods/<Mod Folder>/mod.json
Mods/<Mod Folder>/DataPatches/*.json
Mods/<Mod Folder>/DataPatches/**/*.json
```

- **Files:** Every `.json` file under `DataPatches` is read, subfolders too, in alphabetical order of their paths. Name and group them as you like.
- **The Mod File:** KIF Beta only lists a folder as a mod when it has a `mod.json` or a script. A mod made only of patches needs a `mod.json`.
- **Mod Id:** The `id` in `mod.json`, or the folder's name when there's none.
- **Mod Name:** The name KIF's Mods list shows (the `name` in `mod.json`). Messages and the Patch Viewer use it.
- **Mods That Are Off:** A mod that's switched off, or that KIF blocks, has its patches skipped.

```json
{
  "name": "My Mod",
  "id": "my_mod",
  "version": "1.0.0",
  "author": "You"
}
```

## Load Order

Patches apply in this order:

1. Patches from scripts (`Reloaded::Abilities.register` and `register_internal_patch`, under [Runtime API](#runtime-api)).
2. Each mod's files, in the order the mods' scripts load. With Mod Manager installed, its mods come first, in Mod Manager's load order (a mod's dependencies before it). Then KIF's own folders, alphabetical by folder, with the mods named in a mod's `dependencies` or `load_after` (KIF Beta 0.21.59) before it.
3. Within a mod, its files in alphabetical order of their paths, and each file's patches in the order it lists them.

Order matters in two places:

- **Edits Need Their Entry:** An edit or merge of a new entry has to load after the patch that adds it.
- **Conflicts:** When two mods change the same field, the one that loads last wins (see [Conflicts](#conflicts)).

The Patch Viewer's Load Order (R) shows the order.

## Operations

| Operation | What It Does |
|---|---|
| `add` | Adds a new entry. An error if the entry is already there. |
| `edit` | Changes fields the entry already has. An object field (such as `base_stats`) merges key by key, so the keys you leave out stay. An error if the entry or any of the fields isn't there. |
| `merge` | Merges into an entry that's there. Objects merge key by key; anything else (a number, text, a list) is replaced. New fields are allowed. An error if the entry isn't there. |
| `replace` | Puts the patch's data in place of the entry, or adds it when there's none. |

There's no `remove`.

### Edit or Merge

`edit` only takes fields the entry already has, so it catches a mistyped field name. Some fields change a list instead of writing it out (`add_moves`, `add_tutor_moves`, `add_egg_moves`, `add_evolutions`, `add_types`, `add_pokemon`, `edit_pokemon`, `replace_pokemon`), and some targets take friendlier names (`bag_items`, `ai_skill_level`...). Neither kind is a field of the entry, so `edit` refuses them:

```text
Pikachu (Learnsets) has no add_moves to edit (merge adds new fields).
```

Use `merge` for those.

### What Replace Keeps

Each target writes the game's data its own way, so `replace` doesn't mean the same everywhere:

| Target | What `replace` Does |
|---|---|
| `items`, `moves`, `abilities`, `trainer_types` | Fields the patch leaves out keep the game's values. |
| `species.*` | Only the fields the patch names change (the same for every operation). |
| `trainers.*` | Writes the whole trainer. A field left out is empty, or the game's default. |
| `encounters.*` | The tables the patch names are replaced. The map's other tables and step chances stay. |
| `outfits.*` | Writes the whole outfit. |

## Patch File Format

A patch has four keys:

- `target`: Which data it changes (`"items"`, `"species.core"`...).
- `operation`: One of `add`, `edit`, `merge` or `replace`.
- `id`: The entry it changes (see [Entry Ids](#entry-ids)).
- `data`: A JSON object with the fields.

`target` and `operation` can be written in any case. A file can hold one patch:

```json
{
  "target": "items",
  "operation": "edit",
  "id": "POTION",
  "data": {
    "price": 150
  }
}
```

A group of patches for one target (a patch in the list can still name its own `target`):

```json
{
  "target": "items",
  "patches": [
    {
      "operation": "add",
      "id": "STAR_BERRY",
      "data": {
        "name": "Star Berry",
        "pocket": 5,
        "price": 100,
        "description": "A sweet berry."
      }
    },
    {
      "operation": "edit",
      "id": "POTION",
      "data": {
        "price": 150
      }
    }
  ]
}
```

Or a list of patches, each with its own target:

```json
[
  {
    "target": "items",
    "operation": "edit",
    "id": "POTION",
    "data": { "price": 150 }
  },
  {
    "target": "species.core",
    "operation": "merge",
    "id": "PIKACHU",
    "data": { "base_stats": { "SPEED": 100 } }
  }
]
```

Files are strict JSON, with no comments and no trailing commas. A UTF-8 byte order mark is fine.

### Entry Ids

- **Symbol Targets:** `items`, `moves`, `abilities`, `trainer_types` and `species.*` use the game's symbol, in any case. `"potion"`, `"Potion"` and `"POTION"` are the same entry.
- **Trainers:** `trainers.*` use `TYPE|Name|version`, as the game writes them: `"LEADER_Brock|Brock|0"`.
- **Encounters:** `encounters.*` use `map_version`. `"8_0"` is map 8, version 0.
- **Outfits:** `outfits.*` use the outfit's id, as the game writes it: `"absolhat"`, `"aerodactylSkull"`.

A few things to watch:

- **Loose Matching:** When the exact symbol isn't there, an id finds the game's own entry whatever its case, spaces, dashes and underscores. `"Super Potion"` and `"super-potion"` both find `SUPERPOTION`. This only looks at the game's entries, not ones another patch adds.
- **New Entries:** A new entry's id is the symbol form, in capitals, with any character other than a letter, a digit or `_` turned into `_`. `"Dynamax Candy"` becomes `DYNAMAX_CANDY`.
- **Trainer Case:** The trainer type keeps its case (KIF's leader types are mixed case, as in `LEADER_Brock`), and so does the name. The version is a number; a trainer's rematches and variants have their own.
- **Outfit Case:** Case matters. `"absolhat"` is the game's hat, `"AbsolHat"` isn't.

Values that name other data are looser. A move's type, an item's move, a Pokémon's moves, a trainer's items and so on find the game's id whatever the case, spaces and underscores. `"thunder shock"`, `"ThunderShock"` and `"THUNDERSHOCK"` all find `THUNDERSHOCK`, and `"near other"` finds the move target `NearOther`.

Fused Pokémon are written `B<body>H<head>`, with the two Pokémon's numbers. `"B25H1"` is Pikachu's body with Bulbasaur's head. Both numbers must be Pokémon the game has. Trainers, evolutions and encounters take fusions. Species targets don't: They change the Pokémon the game lists, and fusions are made from those.

## Targets

Each target below lists its fields, what a new entry gets when a field is left out, and what its check refuses. A refused patch is rejected, and the reason shows (see [Checks](#checks)).

### Items

`items` changes `GameData::Item`. An entry's id is the item's symbol (`POTION`).

```json
{
  "target": "items",
  "operation": "add",
  "id": "STAR_BERRY",
  "data": {
    "name": "Star Berry",
    "name_plural": "Star Berries",
    "pocket": 5,
    "price": 100,
    "description": "A sweet berry that a Pokémon can hold.",
    "field_use": 0,
    "battle_use": 0,
    "type": 5
  }
}
```

| Field | What It Is | When Left Out (New Item) |
|---|---|---|
| `name` | The item's name | The id |
| `name_plural` | The name for more than one | The name |
| `pocket` | The Bag pocket: 1 Items, 2 Medicine, 3 Poké Balls, 4 TMs & HMs, 5 Berries, 6 Mail, 7 Battle Items, 8 Key Items | 1 |
| `price` | The shop price | 0 |
| `description` | The description | `"???"` |
| `field_use` | How it's used outside battle | 0 (it isn't) |
| `battle_use` | How it's used in battle | 0 (it isn't) |
| `type` | What kind of item it is | 0 (none in particular) |
| `move` | The move a TM or HM teaches | None |
| `id_number` | The item's number | The next free one |

- `field_use`: Copy the value from a game item that works like yours. 1 is used on a Pokémon (Potion), 2 is used from the Bag (Repel), 3 is a TM and 4 an HM.
- `battle_use`: Again, copy a similar item. 1 is used on a Pokémon (Potion), 2 on a move (Ether), 3 on the Pokémon in battle (X Attack), 4 is a Poké Ball and 5 has no target (Poké Doll).
- `type`: 1 Mail, 2 Mail with a picture, 3 Snag Ball, 4 Poké Ball, 5 Berry, 6 Key Item, 7 Evolution Stone, 8 Fossil, 9 Apricorn, 10 Gem, 11 Mulch, 12 Mega Stone.
- `id_number`: A new item gets the first free number after the game's highest. Give one only if you need it. It must be above 0 and not another item's.
- **Names:** A patched item shows its name and description as the patch has them. The game would look them up in its translation files, which don't have them.
- **Behavior:** Patches only set data. What a new item does when used comes from your mod's scripts (the game's `ItemHandlers`).

The check refuses:

- A number that isn't above 0 (`STAR_BERRY has no number above 0.`).
- A `move` the game doesn't have (`TM_ZAP teaches ZAPZAP, and there's no such move.`).
- A number another item has (`STAR_BERRY can't use number 12: it's FIRESTONE's.`).

### Moves

`moves` changes `GameData::Move`. An entry's id is the move's symbol (`TACKLE`). KIF looks moves up by symbol only (no number keys), but a new move still gets the first free number after the game's highest.

```json
{
  "target": "moves",
  "operation": "add",
  "id": "STAR_SHOWER",
  "data": {
    "name": "Star Shower",
    "function_code": "000",
    "base_damage": 70,
    "type": "FAIRY",
    "category": "Special",
    "accuracy": 100,
    "total_pp": 15,
    "effect_chance": 0,
    "target": "AllNearFoes",
    "priority": 0,
    "flags": "be",
    "description": "Stars rain down on the foes."
  }
}
```

| Field | What It Is | When Left Out (New Move) |
|---|---|---|
| `name` | The move's name | The id |
| `function_code` | Which effect it uses (below) | `"000"` |
| `base_damage` | Power; 0 for a status move | 0 |
| `type` | A type (`"NORMAL"`, `"fire"`...) | `NORMAL` |
| `category` | `Physical`, `Special` or `Status`, or 0, 1, 2 | Status at 0 power, else Physical |
| `accuracy` | 0 to 100; 0 never misses | 100 |
| `total_pp` | PP before PP Ups | 5 |
| `effect_chance` | The chance of its added effect, in percent | 0 |
| `target` | Who it hits (below) | `NearOther` |
| `priority` | 0 is normal; higher goes first, lower goes last | 0 |
| `flags` | Letters for what it is (below) | None |
| `description` | The description | `"???"` |
| `id_number` | The move's number | The next free one |

- `function_code`: The game's effect codes, such as `"000"` (damage only) or `"005"`. Use another move's code to give yours its effect. A code the game has no move class for (`PokeBattle_Move_<code>`) isn't refused, but then a damaging move only does damage, and a status move always fails. A new effect needs that class in your mod's scripts.
- `target`: One of `None`, `User`, `NearAlly`, `UserOrNearAlly`, `UserAndAllies`, `NearFoe`, `RandomNearFoe`, `AllNearFoes`, `Foe`, `AllFoes`, `NearOther`, `AllNearOthers`, `Other`, `AllBattlers`, `UserSide`, `FoeSide` or `BothSides`.
- `flags`: `a` makes contact, `b` Protect blocks it, `c` Magic Coat reflects it, `d` Snatch steals it, `e` Mirror Move copies it, `f` King's Rock can flinch, `g` thaws the user, `h` high critical-hit ratio, `i` biting, `j` punching, `k` sound, `l` powder, `m` pulse, `n` bomb, `o` dance.
- **Names:** As with items, a patched move shows the name and description the patch has.

PIF's contest fields work too. A game move keeps its own contest data unless the patch names a field:

| Field | What It Is |
|---|---|
| `contest_type` | `COOL`, `BEAUTY`, `CUTE`, `SMART` or `TOUGH`, in any case |
| `contest_hearts` | Appeal hearts, a number |
| `contest_jam` | Jam, a number |
| `contest_function_code` | The contest effect, such as `Basic` or `CanUseRepeatedly`, in any case |
| `contest_flags` | A list of contest flags |
| `contest_description` | The contest description |

The contest fields aren't checked, so use values the game's own moves use.

The check refuses:

- A number that isn't above 0, or one another move has.
- A type the game doesn't have (`STAR_SHOWER's type STARS isn't a type.`).
- A target the game doesn't have (`STAR_SHOWER's target EVERYONE isn't a move target.`).
- A category that isn't one of the three (`STAR_SHOWER's category is physical, special or status (0, 1 or 2).`).
- Accuracy outside 0 to 100, or PP of 0 or less.

### Abilities

`abilities` changes `GameData::Ability`. An entry's id is the ability's symbol (`OVERGROW`).

```json
{
  "target": "abilities",
  "operation": "add",
  "id": "SAND_SPIRIT",
  "data": {
    "name": "Sand Spirit",
    "description": "Boosts Speed in a sandstorm."
  }
}
```

| Field | What It Is | When Left Out (New Ability) |
|---|---|---|
| `name` | The ability's name | The id |
| `description` | The description | `"???"` |
| `id_number` | The ability's number | The next free one |

The check refuses a number that isn't above 0, or one another ability has.

A patch only gives an ability its name and description. What it does in battle comes from scripts. `Reloaded::Abilities` adds both from one place (see [Reloaded::Abilities](#reloadedabilities)).

### Trainer Types

`trainer_types` changes `GameData::TrainerType`, the trainer classes. A patch changes every trainer of that class. An entry's id is the type's symbol (`YOUNGSTER`, `LEADER_Brock`).

```json
{
  "target": "trainer_types",
  "operation": "merge",
  "id": "YOUNGSTER",
  "data": {
    "base_money": 40,
    "skill_level": 32,
    "skill_code": "RLD"
  }
}
```

| Field | Also Written | What It Is | When Left Out (New Type) |
|---|---|---|---|
| `name` | | The class's name ("Youngster") | The id |
| `base_money` | `money`, `reward_money` | The prize money multiplier, 0 to 999999 | 30 |
| `battle_BGM` | | The battle music (a file in `Audio/BGM`) | The game's default |
| `victory_ME` | | The victory music (`Audio/ME`) | The game's default |
| `intro_ME` | | The music when the trainer spots you (`Audio/ME`) | The game's default |
| `gender` | | 0 male, 1 female, 2 mixed | 2 |
| `skill_level` | `ai_skill_level` | How well the AI battles, 0 to 255 | The same as `base_money` |
| `skill_code` | `ai_flags` | The AI's skill flags, as letters | None |
| `id_number` | | The type's number | The next free one |

- `skill_level`: The game's AI steps up at 1 (basic), 16 (medium), 32 (high) and 100 (best). 0 is a wild Pokémon's.
- `skill_code`: Text or a list of letters. Anything but letters, digits and `_` is dropped.
- **Clamped:** `base_money`, `skill_level` and `gender` outside their range are moved inside it.
- **Also Written:** The other names work with `add`, `merge` and `replace`, and win over the game's name when a patch has both. `edit` refuses them, as they aren't fields of the entry.
- **Names:** A patched type shows the name the patch has (KIF looks class names up by number).

The check refuses a number that isn't above 0, or one another type has.

### Species Core Data

`species.core` changes the Pokémon the game has (`GameData::Species`). An entry's id is the Pokémon's symbol (`PIKACHU`). Adding a Pokémon is refused; that's the job of Expanded Dex, a later Kanto Reloaded feature. A patch on any species target only changes the fields it names, whatever its operation.

```json
{
  "target": "species.core",
  "operation": "merge",
  "id": "PIKACHU",
  "data": {
    "base_stats": {
      "SPEED": 100
    },
    "catch_rate": 150,
    "wild_item_common": "ORANBERRY"
  }
}
```

| Field | What It Is |
|---|---|
| `name` | The Pokémon's name |
| `form_name` | The form's name |
| `category` | The Pokédex category ("Mouse") |
| `pokedex_entry` | The Pokédex text |
| `pokedex_form` | A number |
| `type1`, `type2` | Types. A single-type Pokémon has `type2` the same as `type1`, so set both to change it |
| `base_stats` | A stat object (below) |
| `evs` | The EVs it gives, as a stat object |
| `base_exp` | Base experience |
| `growth_rate` | `Medium`, `Erratic`, `Fluctuating`, `Parabolic`, `Fast` or `Slow` |
| `gender_ratio` | `AlwaysMale`, `AlwaysFemale`, `Genderless`, `FemaleOneEighth`, `Female25Percent`, `Female50Percent`, `Female75Percent` or `FemaleSevenEighths` |
| `catch_rate` | Catch rate |
| `happiness` | Base friendship |
| `wild_item_common`, `wild_item_uncommon`, `wild_item_rare` | Items it holds in the wild; `""` or `null` for none |
| `egg_groups` | A list of egg groups; an empty list is `Undiscovered` |
| `hatch_steps` | Steps to hatch |
| `incense` | The incense that makes its baby form; `""` or `null` for none |
| `height`, `weight` | Whole numbers, in tenths of a metre and tenths of a kilogram, as the game keeps them. Pikachu is height 4 (0.4 m) and weight 60 (6.0 kg). A decimal is rounded |
| `color`, `shape`, `habitat` | The game's body colors, shapes and habitats |
| `generation` | A number |

Stat objects use the stat ids, in any case:

```json
{
  "HP": 35,
  "ATTACK": 55,
  "DEFENSE": 40,
  "SPECIAL_ATTACK": 50,
  "SPECIAL_DEFENSE": 40,
  "SPEED": 90
}
```

- **Partial Stats:** A `base_stats` or `evs` object can name only some stats. The others keep their values, with every operation.
- **Loose Ids:** Types, growth rates, gender ratios, egg groups, colors, shapes, habitats and items find the game's id whatever the case. `"parabolic"` is `Parabolic`.
- **Names:** A patched name, form name, category or Pokédex entry shows as the patch has it. A fusion's name is built from its parts' names in KIF's name table, so a new name shows for the Pokémon itself, not in fusion names.

The check refuses:

- A Pokémon the game doesn't have (`The game has no NEWMON. Species patches change Pokémon the game has (new ones come with Expanded Dex).`).
- A stat field that isn't an object, a stat name the game doesn't have, or a value that isn't a whole number. Base stats below 1 become 1, and EVs below 0 become 0.
- A type, growth rate, gender ratio, color, shape or habitat the game doesn't have (`growth_rate: "Speedy" isn't one the game has.`).
- An egg group or item the game doesn't have.

### Species Learnsets

`species.learnsets` changes a Pokémon's level-up, tutor and egg moves.

Add to the Pokémon's own moves with `merge`:

```json
{
  "target": "species.learnsets",
  "operation": "merge",
  "id": "PIKACHU",
  "data": {
    "add_moves": [
      { "level": 12, "move": "NUZZLE" }
    ],
    "add_tutor_moves": ["THUNDERPUNCH"],
    "add_egg_moves": ["WISH"]
  }
}
```

Or write a list out in full:

```json
{
  "target": "species.learnsets",
  "operation": "replace",
  "id": "PIKACHU",
  "data": {
    "moves": [
      [1, "THUNDERSHOCK"],
      [1, "GROWL"],
      [12, "NUZZLE"]
    ],
    "egg_moves": []
  }
}
```

| Field | What It Does |
|---|---|
| `moves` | Writes the level-up moves out in full |
| `add_moves` | Adds level-up moves to the Pokémon's own |
| `tutor_moves` | Writes the tutor moves out in full |
| `add_tutor_moves` | Adds tutor moves |
| `egg_moves` | Writes the egg moves out in full |
| `add_egg_moves` | Adds egg moves |

- **Level-Up Moves:** Written `{ "level": 12, "move": "NUZZLE" }` or `[12, "NUZZLE"]`. A move with no level is learned at 1. The list is sorted by level afterwards.
- **No Doubles:** The `add_` fields skip a move the list already has (for level-up moves, the same move at the same level).
- **Lists Left Out:** A list the patch doesn't name stays as it is. The `replace` above keeps Pikachu's tutor moves.
- **Leaving a Move Out:** There's no remove, so write the whole list without it.
- **Use Merge:** The `add_` fields need `merge` (`edit` refuses them).
- **Mods Add Up:** When two mods both `add_moves` to one Pokémon, both mods' moves are added. The `add_` fields never count as a conflict.

The check refuses a move the game doesn't have (`"ZAPZAP" isn't a move.`).

### Species Evolutions

`species.evolutions` changes what a Pokémon evolves into. After evolutions change, Kanto Reloaded works out every Pokémon's prevolution again, so the game's family checks stay right.

```json
{
  "target": "species.evolutions",
  "operation": "merge",
  "id": "EEVEE",
  "data": {
    "add_evolutions": [
      { "species": "JOLTEON", "method": "Level", "parameter": 40 }
    ]
  }
}
```

```json
{
  "target": "species.evolutions",
  "operation": "replace",
  "id": "PIKACHU",
  "data": {
    "evolutions": [
      ["RAICHU", "Item", "THUNDERSTONE"]
    ]
  }
}
```

| Field | What It Does |
|---|---|
| `evolutions` | Writes the evolutions out in full; `[]` stops it evolving |
| `add_evolutions` | Adds evolutions to the Pokémon's own (skips one it already has) |

An evolution is `{ "species", "method", "parameter" }` or `[species, method, parameter]`:

- `species`: What it evolves into. Fusions (`B<body>H<head>`) work.
- `method`: The game's evolution method, in any case. `Level`, `Item`, `Trade`, `LevelDay`, `LevelNight` and the rest of `GameData::Evolution`.
- `parameter`: What the method needs, such as a level for `Level` or an item for `Item`. Items, moves, Pokémon and types are looked up like other ids. Leave it out for a method that needs none.

`add_evolutions` needs `merge`. When two mods both add evolutions to one Pokémon, both are added.

The check refuses:

- An evolution with no species or method (`An evolution needs a species and a method.`).
- A Pokémon the game doesn't have (`"JOLTEN" isn't a Pokémon.`).
- A method the game doesn't have (`"Levle" isn't an evolution method.`).

### Species Ability Lists

`species.abilities` changes a Pokémon's abilities and hidden abilities.

```json
{
  "target": "species.abilities",
  "operation": "edit",
  "id": "PIKACHU",
  "data": {
    "abilities": ["STATIC"],
    "hidden_abilities": ["SAND_SPIRIT"]
  }
}
```

| Field | What It Is |
|---|---|
| `abilities` | The abilities, in full |
| `hidden_abilities` | The hidden abilities, in full |

A list the patch leaves out stays as it is. An ability added by a patch (like the Abilities example above) or by `Reloaded::Abilities.register` works here. The check refuses an ability the game doesn't have (`SAND_SPRIT isn't an ability.`).

### Trainers

The game has a set of trainers for each mode, so there are three targets. KIF picks the set by the game's mode, and a trainer the mode's set doesn't have comes from Classic.

| Target | The Game's Data |
|---|---|
| `trainers.classic` | `GameData::Trainer` (`trainers.dat`) |
| `trainers.remix` | `GameData::TrainerModern` (`trainers_remix.dat`) |
| `trainers.expert` | `GameData::TrainerExpert` (`trainers_expert.dat`) |

An entry's id is `TYPE|Name|version`, written as the game writes them: `"LEADER_Brock|Brock|0"`. A new trainer takes its type, name and version from its id.

Change a game trainer's team with `merge`:

```json
{
  "target": "trainers.classic",
  "operation": "merge",
  "id": "LEADER_Brock|Brock|0",
  "data": {
    "edit_pokemon": [
      { "slot": 0, "level": 12 }
    ],
    "add_pokemon": [
      { "species": "B95H74", "level": 14, "moves": ["ROCKTOMB", "BIND"] }
    ],
    "items": ["SUPERPOTION"]
  }
}
```

Or add a trainer:

```json
{
  "target": "trainers.classic",
  "operation": "add",
  "id": "YOUNGSTER|Ziggy|0",
  "data": {
    "lose_text": "My Pikachu lost...",
    "pokemon": [
      { "species": "PIKACHU", "level": 8, "moves": ["THUNDERSHOCK", "QUICKATTACK"], "held_item": "ORANBERRY" }
    ]
  }
}
```

| Field | Also Written | What It Is |
|---|---|---|
| `trainer_type` | | The trainer's type (from the id when left out) |
| `name` | | The trainer's name (from the id when left out) |
| `version` | | The version (from the id when left out) |
| `items` | `bag_items` | Items the trainer uses in battle (not held items) |
| `lose_text` | | What the trainer says after losing (`"..."` when left out) |
| `loseText_rematch` | `rematch_lose_text` | After losing a rematch |
| `battleText` | `battle_text` | Battle text |
| `preRematchText` | `pre_rematch_text` | Before a rematch |
| `preRematchText_caught` | `pre_rematch_caught_text` | Before a rematch, for this case |
| `preRematchText_evolved` | `pre_rematch_evolved_text` | The same |
| `preRematchText_fused` | `pre_rematch_fused_text` | The same |
| `preRematchText_unfused` | `pre_rematch_unfused_text` | The same |
| `preRematchText_reversed` | `pre_rematch_reversed_text` | The same |
| `preRematchText_gift` | `pre_rematch_gift_text` | The same |
| `infoText` | `trainer_info`, `info_text` | The trainer's info text |
| `pokemon` | | The whole party |
| `replace_pokemon` | | Puts a new Pokémon in a party slot |
| `edit_pokemon` | | Changes fields of a party slot's Pokémon |
| `add_pokemon` | | Adds Pokémon to the end of the party |
| `id_number` | | The trainer's number (the next free one when left out) |

- **Also Written:** The friendlier names work with `add`, `merge` and `replace`, and win over the game's name when a patch has both. `edit` refuses them, as they aren't fields of the entry.
- **Slots:** `replace_pokemon` and `edit_pokemon` take `{ "slot": 0, ... }`, counting from 0. The Pokémon's fields go beside `slot`, or in a `"data"` object. The slot must be in the party.
- **Order:** `pokemon` comes first, then `replace_pokemon`, `edit_pokemon` and `add_pokemon`.
- **Party Size:** `add_pokemon` stops at 6 Pokémon, and a party can't be empty.
- **Use Merge:** `replace_pokemon`, `edit_pokemon` and `add_pokemon` need `merge` (or a `replace` that writes `pokemon`).
- **Two Mods:** Two mods' `add_pokemon` add up, so both mods' Pokémon join the party. If together they'd make it bigger than 6, the whole trainer is refused. Two mods' `edit_pokemon` (or `replace_pokemon`) on one trainer conflict, and the list of the mod that loads last is used.
- **Scripted Battles:** A battle that a map event or a script builds itself (not from the game's trainer data), and text an event shows itself, aren't trainer data. Change those with a script.

A party member's fields:

| Field | What It Is |
|---|---|
| `species` | The Pokémon (required). Fusions are `B<body>H<head>` |
| `level` | 1 or more (1 when left out) |
| `form` | A form number |
| `name` | A nickname |
| `moves` | Its moves |
| `moves_hard` | Its moves on Hard difficulty |
| `moves_easy` | Its moves on Easy difficulty |
| `ability` | An ability |
| `ability_index` | Which of its abilities, by number |
| `item` (or `held_item`) | Its held item; `item` wins when both are there |
| `gender` | `"male"` (`"m"`, 0) or `"female"` (`"f"`, 1) |
| `nature` | A nature |
| `iv` | A stat object; stats left out are 0 |
| `ev` | A stat object; stats left out are 0 |
| `happiness` | Friendship |
| `shininess` | `true` for shiny |
| `shadowness` | `true` for Shadow |
| `poke_ball` | The Poké Ball it's in |

Without `iv` and `ev`, the game works them out from the level, as it does for its own trainers.

The check refuses the whole trainer when any of it is wrong:

- A trainer type the game doesn't have (`"LEADER_Brok" isn't a trainer type.`).
- A party member with no species, or one the game doesn't have (`add_pokemon 1: "PIKACHO" isn't a Pokémon (fusions are B<body>H<head>).`).
- A level below 1.
- A move, ability, held item or nature the game doesn't have (`pokemon 1: "THUNDERSHOK" isn't a move.`).
- A slot outside the party (`edit_pokemon names slot 5; the party has 2 (add_pokemon adds one).`).
- A party bigger than 6, or an empty one.
- A battle item the game doesn't have (`Its bag item "SUPERPOTON" isn't an item.`).
- A number another trainer has.

### Encounters

The game has a set of wild encounters for each mode, so there are three targets:

| Target | The Game's Data |
|---|---|
| `encounters.classic` | `GameData::Encounter` (`encounters.dat`) |
| `encounters.remix` | `GameData::EncounterModern` (`encounters_remix.dat`) |
| `encounters.randomized` | `GameData::EncounterRandom` (KIF's randomizer makes it) |

An entry's id is `map_version`. `"8_0"` is map 8, version 0.

Add Pokémon to a map's tables with `merge`:

```json
{
  "target": "encounters.classic",
  "operation": "merge",
  "id": "8_0",
  "data": {
    "add_types": {
      "Land": [
        [5, "PIKACHU", 3, 5]
      ]
    }
  }
}
```

Or give a map new tables:

```json
{
  "target": "encounters.classic",
  "operation": "add",
  "id": "999_0",
  "data": {
    "step_chances": { "Land": 21 },
    "types": {
      "Land": [
        { "chance": 60, "species": "PIDGEY", "min_level": 3, "max_level": 5 },
        { "chance": 40, "species": "B25H16", "min_level": 4, "max_level": 6 }
      ]
    }
  }
}
```

| Field | What It Does |
|---|---|
| `step_chances` | Each table's chance to start an encounter, as `{ "Land": 21 }`. Merged into the map's own |
| `types` | Tables written out in full. Each table named replaces the map's own |
| `add_types` | Entries added to the map's tables, as `{ "Land": [...] }` |
| `map`, `version` | The map and version, when they aren't the id's |

- **Entries:** Written `[chance, species, min level, max level]` or `{ "chance", "species", "min_level", "max_level" }`. With no max level, it's the min level.
- **Tables:** `Land`, `LandMorning`, `LandDay`, `LandAfternoon`, `LandEvening`, `LandNight`, `Cave` and `Water` (each with the same times of day), `Land1`, `Land2` and `Land3` (the game's other grass), `OldRod`, `GoodRod`, `SuperRod`, `RockSmash`, `HeadbuttLow`, `HeadbuttHigh` and `BugContest`, in any case.
- **Times of Day:** The game picks the table for the time of day first (Morning, Afternoon or Evening, then Day; Night at night), and plain `Land` only when the map has none for that time. Map 78 has `LandDay`, `LandMorning` and `LandNight`, so a `Land` table added there is never used. Patch the tables it has.
- **Tables Left Out:** The map's other tables stay, with every operation.
- **Use Merge:** `add_types` needs `merge`. When two mods both `add_types` to one map, both mods' entries are added.

The patched tables go into the game's data when it loads, so the game sets up each map from them, and KIF's randomizer modes (Swap, Dynamic Routes...) work on top as usual.

KIF makes the Randomized tables again when it randomizes the wild Pokémon. It builds them from Classic's, Classic patches included, and saves them in its own file (`Data/encounters_randomized.dat`). The new tables become the base, and every `encounters.randomized` patch goes on top of them again, with each operation working as above.

The check refuses:

- An id that isn't `map_version` (`"route1" isn't <map>_<version> (like "8_0").`).
- A table the game doesn't have (`Grass isn't an encounter type (Land, Cave, Water...).`).
- A step chance below 0.
- An entry that isn't the four values (`Land 2 isn't [chance, species, min level, max level].`).
- A Pokémon the game doesn't have (`Land 1: PIKACHO isn't a Pokémon (fusions are B<body>H<head>).`).
- A chance below 1, a min level below 1, or a max level below the min (`Land 1: levels 9 to 5 don't work.`).

### Outfits

| Target | The Game's List | The Game's File |
|---|---|---|
| `outfits.clothes` | `$PokemonGlobal.clothes_data` | `Data/outfits/clothes_data.json` |
| `outfits.hats` | `$PokemonGlobal.hats_data` | `Data/outfits/hats_data.json` |
| `outfits.hairstyles` | `$PokemonGlobal.hairstyles_data` | `Data/outfits/hairstyles_data.json` |

The game's outfit files are each target's base, so every operation works, on the game's outfits too. An entry's id is the outfit's id as the game writes it, and case matters (`"absolhat"`, `"aerodactylSkull"`).

Change one of the game's hats:

```json
{
  "target": "outfits.hats",
  "operation": "edit",
  "id": "absolhat",
  "data": {
    "price": 1000
  }
}
```

Or add one:

```json
{
  "target": "outfits.hats",
  "operation": "add",
  "id": "starCap",
  "data": {
    "name": "Star Cap",
    "description": "A cap with a star on it.",
    "price": 2500,
    "tags": "hat",
    "storelocation": "lilycove",
    "pokemontags": "clefairy",
    "contestcondition": "cute"
  }
}
```

| Field | What It Is | When Left Out |
|---|---|---|
| `name` | The outfit's name | The id |
| `description` | The description | None |
| `price` | The price | 0 |
| `tags` | Tags, as `"a, b"` or a list | None |
| `storelocation` | Where it's sold; also a tag | None |
| `regiontags` | Regions; also tags | None |
| `pokemontags` | Pokémon it goes with; each becomes the tag `pokemon-<name>` | None |
| `contestcondition` | Its contest condition (clothes and hats) | None |

- **The Game's Outfits:** `edit` and `merge` keep the fields the patch doesn't name. `replace` writes the whole outfit. `add` refuses an id the game already has.
- **In the Game:** The game fills its outfit lists from its files whenever it refreshes them (a save loading, a shop). Patched outfits join each list after each refresh, in the place of the game's outfit with the same id.
- **Names:** Names and descriptions go through the game's translation, as its own do.

The check refuses an outfit the game can't make, with the game's error (`It couldn't be made: ...`).

## Checks

A patch goes through three checks:

1. **The File:** It must be JSON in one of the [three shapes](#patch-file-format), and each patch needs a target, an operation, an id and a data object.
2. **The Operation:** The target must be one Kanto Reloaded has, and the operation must fit the entry. `add` needs a new id, `edit` and `merge` an existing one, and `edit` existing fields. Conflicts between mods are found here too.
3. **The Target:** Each target checks the values against the game's data, as its section above lists.

The messages the first two give:

| Message | Why |
|---|---|
| `The file couldn't be read as JSON: ...` | A JSON mistake; the reader says where |
| `A patch file holds an object, an array, or a patches array.` | The file is something else |
| `A patch is an object (with target, operation, id and data).` | A list item isn't an object |
| `It has no target.` / `It has no operation.` / `It has no id.` / `It has no data.` | A key is missing |
| `"delete" isn't an operation (add, edit, merge or replace).` | Not one of the four |
| `Its data isn't an object.` | `data` is a list, text or a number |
| `No target is called "itemz"; did you mean "items"?` | A mistyped target (the nearest one is suggested) |
| `Potion is already in Items, so it can't be added (use edit, merge or replace).` | `add` on an entry that's there |
| `There's no STAR_BERRY in Items to edit.` | `edit` (or `merge`) on an entry that isn't there |
| `Pikachu (Learnsets) has no add_moves to edit (merge adds new fields).` | `edit` with a field the entry doesn't have |

### When a Patch Is Rejected

- **Skipped:** The patch doesn't apply, and the game keeps its own data for that entry.
- **The Whole Entry:** A target's check looks at the entry with every patch on it applied. When it refuses, every patch on that entry is rejected, from every mod. One mod's bad learnset patch also stops another mod's good one on the same Pokémon.
- **Where It Shows:** In the Patch Viewer (the mod's Rejected rows), in the Patch Checker (an ERROR line), and in Kanto Reloaded's log.

### The Log

Kanto Reloaded's log is `Mods\KantoReloaded\Logging\Kanto Reloaded.log` (the last session's is `Kanto Reloaded.old.log`). Data patch lines are on the `data_patches` channel:

```text
[14:02:11] [WARNING] [data_patches] Data patch Mods/MyMod/DataPatches/items.json, patch 2: Other Mod also changes Potion's price (Items); Other Mod loads last, so its value is used.
[14:02:11] [WARNING] [data_patches] Data patch Mods/OtherMod/DataPatches/prices.json, patch 1: My Mod also changes Potion's price (Items); Other Mod loads last, so its value is used.
[14:02:11] [ERROR] [data_patches] Data patch Mods/MyMod/DataPatches/species/pikachu.json, patch 2: No target is called "species.learnset"; did you mean "species.learnsets"?
[14:02:11] [ERROR] [data_patches] Data patch Mods/MyMod/DataPatches/items.json, patch 3: TM_ZAP teaches ZAPZAP, and there's no such move.
[14:02:11] [INFO] [data_patches] Data patches: 4 of 6 applied from 2 mod(s), 2 warning(s), 2 error(s)
```

Patches are numbered from 1 in their file, as in the Patch Viewer and the Patch Checker. The last line sums up the build, after every target's check. Warnings and errors also go to KIF's session log, so a KIF Beta bug report shows them. A message is logged once per session, even when Hot Reload builds again.

## Conflicts

Kanto Reloaded compares every mod's patches before applying them:

- **Two Adds or Replaces:** Two `add` or `replace` patches on the same entry are all errors, so none of them applies. That holds for two patches in one mod too.

  ```text
  Other Mod also adds STAR_BERRY (Items), so neither applies.
  My Mod adds STAR_BERRY (Items) more than once, so none of them applies.
  ```

- **Two Edits of a Field:** When two mods `edit` or `merge` the same field of an entry, each gets a warning, and the mod that loads last wins.

  ```text
  Other Mod also changes Potion's price (Items); Other Mod loads last, so its value is used.
  ```

- **Down to the Last Key:** Fields are compared key by key, all the way down. One mod's `base_stats.SPEED` and another's `base_stats.DEFENSE` don't clash, and both apply. Two mods' `base_stats.SPEED` do, and the warning names that key:

  ```text
  Mod B also changes Bulbasaur's base_stats.SPEED (Species); Mod B loads last, so its value is used.
  ```

- **The `add_` Fields:** `add_moves`, `add_tutor_moves`, `add_egg_moves`, `add_evolutions`, `add_types` and `add_pokemon` add up across mods, and never count as a conflict.
- **A Replace After an Edit:** A `replace` from another mod that loads after an `edit` or `merge` writes over it, and the edit gets a warning:

  ```text
  Mod B replaces Repel (Items) after this, so this change is lost.
  ```

- **An Edit Before Its Add:** An `edit` or `merge` that loads before the mod that adds its entry finds nothing to change (`There's no ... to edit.`). Put the adding mod in your `dependencies`, or in `load_after` if your mod works without it.
- **A Mistyped Target:** It's an error, with the nearest target suggested when it's one or two letters off.

## The Patch Viewer

**Kanto Reloaded > Data Patches > Patch Viewer** shows what every mod changes. It has the KIF Settings layout:

- **Mods:** On the left, each mod with patches, in load order. Kanto Reloaded's own has a Poké Ball.
- **Rows:** On the right, the selected mod's heading and its rows. A row is a target and what happened to it. **Added** (green) is an `add`, or a `replace` of an entry the game didn't have. **Edited** (blue) is an `edit`, a `merge`, or a `replace` of one of the game's entries. **Rejected** (red) didn't apply. Added and Edited count entries (`+3` for three new ones); Rejected counts patches. Patches with no target, or one Kanto Reloaded doesn't have, are a **Patch Files** row, last.
- **Status:** The heading shows the mod's status. **OK** (green), **N CONFLICT** (amber, for entries another mod also changes) or **N REJECTED** (red). Rejected comes first when a mod has both.
- **Description:** The box at the bottom says what the selected mod or row means, in plain words. For a mod, where it loads, how many patches and files, and what's rejected or in conflict. For a Rejected row, why, for each patch.
- **Details (A):** Every entry of the row and what happened to it (`Edited price in items.json, patch 2.`), with any conflict, or the reason a patch was rejected and where it is.
- **Load Order (R):** The mods in the order their patches apply. When two mods change the same thing, the lower one wins. Picking a mod opens it.
- **Search:** The left box in the title bar (L on a controller). Type straight into it, or press A on a controller for the naming screen. It finds rows by mod, target, or an entry's name or id, across every mod.
- **Buttons:** Up and Down pick a mod, Right or A opens its rows, A on a row opens Details, and B goes back. The mouse works too, with hover, click, the wheel, and a right click to go back.

What the description says, for a mod and three of its rows:

```text
My Mod loads 1st of 2: 5 patches from 2 files. 2 patches were rejected; the Rejected rows say why. 1 entry is also changed by another mod, and the mod that loads last wins.

My Mod adds 1 item: Star Berry.

My Mod edits 1 item: Potion. Other Mod also changes Potion's price (Items); Other Mod loads last, so its value is used.

1 patch was rejected, so the game's data is as it was without it. TM_ZAP teaches ZAPZAP, and there's no such move.
```

### Hot Reload

With KIF's DEBUG option on (Settings > Advanced), Y in the Patch Viewer reloads every mod's patches without a restart. The hint line shows it as Reload.

- **What It Does:** It puts the game's own data back, reads every mod's patch files again, and applies them. Builds never stack, so a reload gives the same result as a fresh start.
- **What It Refreshes:** The map you're on picks its encounter tables again, and the outfit lists refresh.
- **What It Keeps:** Mods' scripts don't run again. Patches they registered (`Reloaded::Abilities.register`) are kept and applied again.
- **The Report:** "Patches Reloaded", which mods changed and how long it took. Then each target that changed (`Items: 1 added, 1 changed`), how many patches are newly rejected (with the first reasons), how many are fixed, or "Nothing Changed". A, B or a click closes it.

## The Patch Checker

The Patch Checker checks a mod's patches against KIF Beta's real data, outside the game. It lists every error and warning by file and patch, in the words the Patch Viewer uses. Run it before a release. It changes nothing in KIF Beta or the mod.

```text
ruby Tools/PatchChecker/patch_check.rb "<KIF Beta>" "<mod folder>" [more mod folders]
```

- **Where:** Run it from Kanto Reloaded's folder (`Mods/KantoReloaded`). A mod folder can be a full path, or a path inside KIF Beta's folder (`"Mods/MyMod"`).
- **More Mods:** Folders after the first load after it, in the order given, so conflicts between them show as warnings.
- **Exit Code:** 0 when every patch applies (warnings allowed), 1 when one is rejected, 2 for a mistake in the command or a folder that isn't there.
- **Scripts:** It doesn't run your mod's scripts, so an ability your scripts register with `Reloaded::Abilities.register` looks unknown to it.

A made-up mod with a mistyped move and a mistyped target, checked with a second mod that changes the same price:

```text
> ruby Tools/PatchChecker/patch_check.rb "<KIF Beta>" "Mods/MyMod" "Mods/OtherMod"
Loading KIF Beta's data... done (KIF Beta 0.21.55).

My Mod (<KIF Beta>/Mods/MyMod)
  items.json: 3 patches, 2 applied
    WARNING patch 2 (Items POTION): Other Mod also changes Potion's price (Items); Other Mod loads last, so its value is used.
    ERROR patch 3 (Items TM_ZAP): TM_ZAP teaches ZAPZAP, and there's no such move.
  pikachu.json: 2 patches, 1 applied
    ERROR patch 2 (species.learnset pikachu): No target is called "species.learnset"; did you mean "species.learnsets"?

Other Mod (<KIF Beta>/Mods/OtherMod)
  prices.json: 1 patch, 1 applied
    WARNING patch 1 (Items POTION): My Mod also changes Potion's price (Items); Other Mod loads last, so its value is used.

Result: 2 patches are rejected; the game skips them until fixed.
```

## Events

| Event | When | Context |
|---|---|---|
| `:game_data_loaded` | The game loaded its data. Kanto Reloaded's targets read the game's data as their base (priority 50). | None |
| `:data_patches_apply` | Every patch was read, compared and applied to the patch data. The targets make the game's data and run their checks (Kanto Reloaded's at priority 100). It's for targets, a mod's own included (see [Your Own Targets](#your-own-targets)). | None |
| `:data_patches_loaded` | Everything is applied and checked, and the game's data is patched. | `{ :summary, :patches, :errors }` |

```ruby
Reloaded::Events.on(:data_patches_loaded, :my_mod_patches) do |context|
  summary = context[:summary]
  Reloaded::Log.info("#{summary[:applied]} of #{summary[:patches]} patches applied", :my_mod)
end
```

- **The Context:** It's the final result. `:summary` and `:errors` count the patches a target's check rejected. Hidden patches from scripts are left out, as in `Reloaded::DataPatches.patches`.
- **Hot Reload:** All three fire again at each Hot Reload.

## Runtime API

### Reading Patched Data

```ruby
Reloaded::DataPatches.data                       # every target: { target => { id => { field => value } } }
Reloaded::DataPatches.data("items")              # one target: { id => { field => value } }
Reloaded::DataPatches.entry("items", "potion")   # one entry (any case for symbol ids), or nil
```

These are copies of the patch data: The game's data with every patch applied, as plain hashes. It's what the patches ask for, so an entry a target's check rejected is still in it, though the game kept its own. The game's data itself (`GameData::Item.get(:POTION)`) is what the game uses.

```ruby
Reloaded::DataPatches.patches                    # every patch read
Reloaded::DataPatches.patches("items")           # one target's
Reloaded::DataPatches.applied                    # the patches that took effect
Reloaded::DataPatches.errors                     # [{ :mod_id, :mod_name, :file, :index, :target, :id, :message }]
Reloaded::DataPatches.warnings                   # the same shape
Reloaded::DataPatches.mods                       # [{ :id, :name, :folder_path }], in load order
Reloaded::DataPatches.summary                    # { :targets, :patches, :applied, :errors, :warnings }
Reloaded::DataPatches.targets                    # the target names
Reloaded::DataPatches.label("species.learnsets") # "Learnsets"; a target that isn't listed, as written
Reloaded::DataPatches.reload                     # Hot Reload; returns how long it took, in seconds
```

`patches` and `applied` take `:all => true` to include hidden patches from scripts. Each patch is a hash:

| Key | What It Is |
|---|---|
| `:mod_id`, `:mod_name` | The mod |
| `:file` | `"Mods/MyMod/DataPatches/items.json"` |
| `:index` | Its place in the file, from 0 (messages count from 1) |
| `:target`, `:operation`, `:id`, `:data` | The patch |
| `:applied` | It was applied to the patch data |
| `:rejected` | `nil`, or why a target's check refused it |
| `:errors` | Why it couldn't apply at all |
| `:conflicts` | The other mods that change its entry |
| `:internal`, `:hidden` | It's from a script; it's hidden from the Patch Viewer |

### Your Own Targets

A mod can make its own data patchable, so other mods can change it the same way:

```ruby
Reloaded::DataPatches.register_target("my_mod.quests",
  { "FIND_PIKACHU" => { "name" => "Find Pikachu", "reward" => 500 } },
  :owner => :my_mod, :description => "My Mod's quests.", :symbol_ids => true)

Reloaded::Events.on(:data_patches_apply, :my_mod_quests) do
  Reloaded::DataPatches.data("my_mod.quests").each do |id, quest|
    next Reloaded::DataPatches.reject("my_mod.quests", id, "#{id} has no reward.") unless quest["reward"]
    MyMod::Quests.add(id, quest)
  end
end
```

Another mod then patches it:

```json
{
  "target": "my_mod.quests",
  "operation": "edit",
  "id": "find_pikachu",
  "data": { "reward": 1000 }
}
```

- **When:** Register before the patches are built, either when your script loads or in a `:game_data_loaded` handler. Registering again replaces the base data.
- **Name:** A target name is lowercase, and characters other than letters, digits, `_`, `.`, `:` and `-` become `_`. The Patch Viewer shows it as written, after Kanto Reloaded's own.
- `symbol_ids`: True makes ids symbols, matched loosely like the game's (`"find_pikachu"` and `"Find Pikachu"` are `FIND_PIKACHU`). Leave it out for ids that keep their case.
- `defer_missing_entries`: True makes an `edit` or `merge` of a missing entry wait instead of failing, while the target's base data is still empty.
- **Build in `:data_patches_apply`:** That's where targets use their data, as in the example. The patch data is complete there, and what you refuse counts in the summary, the log and `:data_patches_loaded`.
- **Checks:** A target has no checks of its own. Refuse an entry with `Reloaded::DataPatches.reject("my_mod.quests", id, "Why, in plain words.")`. Its patches are marked rejected, and the reason shows in the Patch Viewer.

### Patches From Scripts

A script can add a patch without a file:

```ruby
Reloaded::DataPatches.register_internal_patch("items", "MY_TOKEN",
  { "name" => "Token", "pocket" => 8, "description" => "A token from My Mod." },
  :operation => "add", :owner => :my_mod, :name => "My Mod", :hidden => false)
```

- **Order:** Patches from scripts apply before every mod's files.
- **Kept:** They're kept for every build, Hot Reload too. Registering again with the same owner, target and id replaces the patch.
- `hidden`: True (the default, for Kanto Reloaded's own features) keeps the patch out of the Patch Viewer, `errors`, `warnings` and `summary`, though it still applies. Pass `:hidden => false` and your mod's name so players see it.
- **Returns:** True, or false when the patch is malformed (no target, id or data).

### Reloaded::Abilities

For a new ability that needs behavior as well as data:

```ruby
Reloaded::Abilities.register(:SAND_SPIRIT, :name => "Sand Spirit",
  :description => "Boosts Speed in a sandstorm.", :mod => "My Mod")

Reloaded::Abilities.on_speed_calc(:SAND_SPIRIT) do |ability, battler, mult|
  next mult * 2 if battler.battle.pbWeather == :Sandstorm
end

Reloaded::Abilities.copy_behavior(:SANDRUSH, :SAND_SPIRIT)   # or copy another ability's behavior
```

- `register(id, name:, description:, id_number:, mod:)`: Adds the ability as an `abilities` patch from a script. It shows in the Patch Viewer under `mod`, and it's in the game's data after every build. Returns the ability's symbol.
- `on(handler, ability) { ... }`: Adds the block to one of the game's battle handlers (`BattleHandlers::*`). The handler is a name below, or a handler's own name (`:SpeedCalcAbility`). The block gets what the game's handler passes. Returns false, and logs an error, for a handler that isn't there.
- `on_<name>(ability) { ... }`: The same, one method per name below (`on_speed_calc`, `on_switch_in`...).
- `copy_behavior(source, *targets)`: Gives the targets the source ability's behavior, on every handler the source has.
- **Load Order:** Your scripts need Kanto Reloaded loaded first. Add `"dependencies": ["KantoReloaded"]` to your `mod.json`.

| Name | The Game's Handler |
|---|---|
| `speed_calc` | `SpeedCalcAbility` |
| `weight_calc` | `WeightCalcAbility` |
| `hp_dropped_below_half` | `AbilityOnHPDroppedBelowHalf` |
| `status_check_non_ignorable` | `StatusCheckAbilityNonIgnorable` |
| `status_immunity` | `StatusImmunityAbility` |
| `status_immunity_non_ignorable` | `StatusImmunityAbilityNonIgnorable` |
| `status_immunity_ally` | `StatusImmunityAllyAbility` |
| `status_inflicted` | `AbilityOnStatusInflicted` |
| `status_cure` | `StatusCureAbility` |
| `stat_loss_immunity` | `StatLossImmunityAbility` |
| `stat_loss_immunity_non_ignorable` | `StatLossImmunityAbilityNonIgnorable` |
| `stat_loss_immunity_ally` | `StatLossImmunityAllyAbility` |
| `stat_gain` | `AbilityOnStatGain` |
| `stat_loss` | `AbilityOnStatLoss` |
| `priority_change` | `PriorityChangeAbility` |
| `priority_bracket_change` | `PriorityBracketChangeAbility` |
| `priority_bracket_use` | `PriorityBracketUseAbility` |
| `flinch` | `AbilityOnFlinch` |
| `move_blocking` | `MoveBlockingAbility` |
| `move_immunity_target` | `MoveImmunityTargetAbility` |
| `move_base_type_modifier` | `MoveBaseTypeModifierAbility` |
| `accuracy_calc_user` | `AccuracyCalcUserAbility` |
| `accuracy_calc_user_ally` | `AccuracyCalcUserAllyAbility` |
| `accuracy_calc_target` | `AccuracyCalcTargetAbility` |
| `damage_calc_user` | `DamageCalcUserAbility` |
| `damage_calc_user_ally` | `DamageCalcUserAllyAbility` |
| `damage_calc_target` | `DamageCalcTargetAbility` |
| `damage_calc_target_non_ignorable` | `DamageCalcTargetAbilityNonIgnorable` |
| `damage_calc_target_ally` | `DamageCalcTargetAllyAbility` |
| `critical_calc_user` | `CriticalCalcUserAbility` |
| `critical_calc_target` | `CriticalCalcTargetAbility` |
| `target_on_hit` | `TargetAbilityOnHit` |
| `user_on_hit` | `UserAbilityOnHit` |
| `user_end_of_move` | `UserAbilityEndOfMove` |
| `target_after_move_use` | `TargetAbilityAfterMoveUse` |
| `eor_weather` | `EORWeatherAbility` |
| `eor_healing` | `EORHealingAbility` |
| `eor_effect` | `EOREffectAbility` |
| `eor_gain_item` | `EORGainItemAbility` |
| `certain_switching_user` | `CertainSwitchingUserAbility` |
| `trapping_target` | `TrappingTargetAbility` |
| `switch_in` | `AbilityOnSwitchIn` |
| `switch_out` | `AbilityOnSwitchOut` |
| `ability_change_on_battler_fainting` | `AbilityChangeOnBattlerFainting` |
| `battler_fainting` | `AbilityOnBattlerFainting` |
| `run_from_battle` | `RunFromBattleAbility` |

## Limits

- **No Remove:** Leave something out by writing the whole list without it (learnsets, evolutions, encounter tables, a trainer's party).
- **No New Pokémon:** Species targets change the Pokémon the game has. New ones come with Expanded Dex.
- **One Refusal, the Whole Entry:** When a target's check refuses an entry, every patch on that entry is rejected, from every mod (see [When a Patch Is Rejected](#when-a-patch-is-rejected)).
- **Trainers Are All or Nothing:** One bad id anywhere in a trainer (a move, an item, a Pokémon) refuses the whole trainer.
- **Replace Fills In:** On items, moves, abilities and trainer types, `replace` keeps the game's values for the fields it leaves out (see [What Replace Keeps](#what-replace-keeps)).
- **Data, Not Behavior:** A new item, move or ability's effect comes from scripts.
- **Pokémon That Already Exist:** Some values are copied into a Pokémon when it's made, so a Pokémon that already exists may keep its old value. New Pokémon use the patched data.
- **Not Patch Data:** Shops, maps, events, and battles or text that scripts build themselves.
