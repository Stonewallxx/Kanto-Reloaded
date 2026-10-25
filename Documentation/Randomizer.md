# Randomizer

KIF's Randomizer is cody's: his engine does every shuffle from his seed, and Kanto Reloaded leaves it untouched. Kanto Reloaded takes over his Randomizer screens and adds parts of its own on top. The code is in `Core/Randomizer` (`Randomizer.rb`, `Learnsets.rb`, `Abilities.rb`, `Dynamic.rb`) and `Core/UI` (`RandomizerRows.rb`, `RandomizerScreen.rb`, `RandomizerShare.rb`, `RandomizerBans.rb`, `RandomizerViewers.rb`, `RandomizerNewGame.rb`).

## The Switch

**Reloaded Randomizer** (Kanto Reloaded > Core > Features, On by default) takes over KIF's Randomizer screens; its engine stays. Off brings back KIF's own screens at once, with your run untouched. It's off by itself while KIF's Randomizer module is Off.

The takeover is declared in Kanto Reloaded's settings only. KIF's own takeover works on the whole Randomizer folder, so it would switch cody's engine off too.

## The Screen

During a run, the Randomizer opens in Kanto Reloaded's settings layout wherever cody's opens: KIF Settings' Game > Randomizer, the game's reroll events, the Update Man. Kanto Reloaded's own **Randomizer** section has a row for it too. Both show on randomized saves only.

- **Overview** first: every part with its state (Pokémon Route, Trainers Random, Items Mapped...). The description box sums up the highlighted part's settings, with the seed. A on a part opens it.
- **A section per part** (Pokémon, Trainers, Gyms, Items, Pokémon Data, Evolutions, Exclusions, Entrances): every row of cody's, in Title Case, with headings on the long ones.
- **Seed** last: the seed (A: New Random Seed, Type a Seed, Copy Seed), Settings Code, Spoiler Log and View Spoiler Log.
- **Changes wait for Randomize Now:** An amber dot marks a part or row with a waiting change, and the description box says WAITING. A waiting row's dropdown marks the value the game uses now IN USE.
- **Y: Randomize Now?** lists the waiting changes, old to new. Your party and boxes stay.
- **Leaving with changes waiting** asks Randomize, Undo or Later. Later is the default and what B picks: the changes wait in the save until next time.
- **A save linked to Archipelago:** The rows Archipelago holds (Entrances, Found and Given Items and TMs, NPC Requests) show the value it holds, locked, with why.
- **Door Kinds** (Entrances): While Which Doors is Custom, its seven kinds are rows under it, each with how many doors it has. With every kind Off, the description says NO DOORS SHUFFLED in red.

## The Settings Code and Presets

- **Settings Code** (the Seed section) opens a card with the whole code, coloured by part: the seed bright, cody's settings in text colour, the bans dim and Kanto Reloaded's part in the accent. **Copy Code** puts it on the clipboard; where there's no clipboard, Couldn't Copy shows the code to write down. **Paste Code** asks **Load These Settings?** with every change, old to new. The changes wait for Randomize Now like any other.
- **Presets** (R1, the title bar's box): cody's six built-ins and your own presets under their headings, and Save as Preset (a name typed into the title bar). A built-in asks **Load <name>?** with what it changes (the rest go to their defaults; the seed, the bans and the Strength Ranges stay). One of yours offers Load, Copy Code and Delete. Presets are files in the Randomizer/Presets folder (on a phone, the save folder).

## Exclusions

Banned Pokémon, Moves, Abilities and Items open the Exclusions screen.

- **The four lists** in the sidebar, an amber dot where a ban waits for Randomize Now.
- **Filters** over the list: All, Banned (with how many), Legendary for Pokémon, Physical, Special and Status for moves. Up from the first row reaches them; Left and Right pick one.
- **Rows:** Pokémon with their Big Icon and number, moves in their type's colour with their kind and power, items with their picture and kind. A red BANNED badge, and an amber dot on a ban made since Randomize Now. The description explains the highlighted one.
- **A** bans or allows, **Left and Right** turn a page, **Square** clears the list (asks first), **Triangle** puts Banned Items back to its starting list (the items that have no use in PIF). **L1** searches, **R1** sorts By Number or By Name. **B** goes to the lists, then back.
- A ban waits for Randomize Now, as every change does: The Overview's Exclusions and Randomize Now? show it.

## The Viewers

- **View Spoiler Log** asks first, then shows the log of what the game uses now: its parts in the sidebar, a line per row (an arrow for "became"), the highlighted line in full below with LINE n OF m. **L1** jumps to a dex number or a word.
- **Class Theme List** (Trainers): each themed class and its types in their colours, and what it means.
- **Entrance Log** (Entrances, and the Town Map while Entrances are on): cody's Town Map lines in Kanto Reloaded's frame, how many doors are found and to go, the chosen door explained under the map, NEWEST on the newest. Up and Down pick a door, Left and Right look at either end, A lists every door.

## At New Game

With New Game Setup (Reloaded New Game On), Randomized Mode's **Randomizer** row in Run Setup opens the Randomizer beside Professor Oak: the seed first, every part with its state, and an amber **Done** plate. **Done** (or Y) and **B** go back to Run Setup; the run is randomized once, when you Start.

- **A on the seed:** New Random Seed, Type a Seed, Copy Seed.
- **A on a part** opens its section of the Randomizer screen, the same as during a run.

With Reloaded New Game Off, choosing Randomized Mode in the game's own menu opens it in the intro instead, with **Randomize Now** (or Y), which asks Randomize Now? with the seed and the parts that are on: Randomize starts the journey, Keep Editing goes back. PIF's summary and "Are those settings correct?" after it are skipped.

## What Kanto Reloaded Adds

| Part | What It Does |
|---|---|
| **Learnsets** | One row in place of cody's Moves Follow Type: **Same**, **Follow Type** (his Moves Follow Type) or **Random**. Random rolls every Pokémon's level-up moves again once, when you randomize: the same levels and count, each move replaced by one of the same kind (physical, special or status) and similar power, of any type, never one you've banned. Fusions follow by themselves. Egg and tutor moves stay, and Pokémon you already have keep their moves. |
| **Per Pokémon** | Under cody's Abilities: each Pokémon rolls its own ability from the pool his Abilities row picks for its types (Random, Flavour or Bound), with his No Self-Harm and your banned abilities. Locked while Abilities is Same. **Trainers**, a row under it, picks Fixed or Dynamic for trainers' Pokémon. |
| **Rolls** | A row one step in under each part the seed decides: Trainers, Starters, Static Encounters, Gift Pokémon, Trades, NPC Requests and Learnsets. **Fixed** (the default) is the seed's; **Dynamic** rolls again on the spot, so the seed won't give the same result each time. Locked, with why, while the row above doesn't randomize. |
| **Item Mode** | cody's Item Mode with three values: **Mapped** (each item always becomes the same other item), **By Spot** (cody's Dynamic: every item ball, gift and shop rolls its own item, the same for the same seed and spot) and **Dynamic** (every item ball and gift, items and TMs, rolls its item when you get it, so the seed won't give the same items each time). Shops stay By Spot under Dynamic. |
| **Expanded Pokédex** | The Expanded Pokédex's Pokémon in the pools (**In Pools** by default), on saves that have it. |

### Per Pokémon, in Detail

- **New Pokémon** (wild, gift, static, egg) roll when they're made. The same Pokémon always rolls the same: the roll comes from the seed, the Pokémon's personal ID and its species.
- **Trainers' Pokémon** (the Trainers row under Per Pokémon): **Fixed** by default (the seed, the trainer and the slot: the same every battle), or **Dynamic** (a new roll each battle).
- **Evolving** keeps the rolled ability. **Fusing** offers the two parts' abilities, as the game does. **Unfusing** gives each part its own back.
- **Turned On mid-run:** Only Pokémon made from then on roll; your party and boxes keep theirs.
- **Pinkan Island:** Nothing rolls there (cody's rule: the island plays as in PIF).
- **Abilities only one Pokémon may have** (Disguise, Stance Change, Wonder Guard, Multitype and the like) stay with their own.

### Rolls, in Detail

| Rolls Under | Dynamic |
|---|---|
| **Trainers** (on Random) | Every battle rolls the trainer's team again, with cody's rules (Strength Range, Class Themes, Custom Sprites Only, Fuse Everything, Unfused Pokémon, Team Size). The seed's teams stay underneath for Fixed. The rival keeps his with Rival Keeps His Team, and gym teams that stick to their type stay cody's. |
| **Starters** | Rolled the first time you see them, then kept for the run (your rival's starter too). |
| **Static Encounters** | Every battle with an overworld Pokémon rolls a new one. |
| **Gift Pokémon** | Every gift rolls its own Pokémon when you get it. |
| **Trades** (on Random) | A trade rolls again each time you enter its map. It's the same all through one visit, so what the NPC says is what you get. |
| **NPC Requests** (on Swapped) | They ask for a new Pokémon each time you enter the map. Can't find it? Come back later. |
| **Learnsets** (on Random) | Every Pokémon rolls its own learnset: two Pidgey can learn different moves. A Pokémon always reads the same list, so levelling up and the move relearner agree; it changes when it evolves or fuses. |

Starters, static encounters and gifts roll like cody's Dynamic wild encounters: the wild Strength Range, Legendaries, Fuse Everything, Custom Sprites Only and your bans. Pinkan Island plays as in PIF.

cody's own values that roll on the spot say so too: Wild Encounters' Dynamic and Dynamic Route, Gyms' Rerandomize Each Battle, and Trainer Held Items' Random. cody's Item Mode Dynamic is the seed's (the same spot always gives the same item), so it's called By Spot here, beside a Dynamic that really rolls.

## Seeds and Settings Codes

- **Same seed, same game:** Kanto Reloaded's Fixed rolls use their own parts of the seed and never the game's random numbers. The same seed and cody's settings give the same game with or without them. Dynamic rolls are the exception: they roll on the spot.
- **The settings code** is cody's exactly while Kanto Reloaded's settings are at their defaults, so a KIF-only player can paste it. Otherwise it gets a seventh part, `-KR1.<letters>`, which Kanto Reloaded reads before cody's code reads the rest.
- **Pasting cody's code alone** puts Kanto Reloaded's parts back to their defaults, so a code always says the whole run.
- **The spoiler log** lists Kanto Reloaded's settings with cody's, and which parts roll on the spot. Its Starters, Trades and Trainers say when they're Dynamic; with Item Mode Dynamic its items part says they roll when you get them, and its shops are By Spot.

## Your Save

Kanto Reloaded's Randomizer settings live in cody's own save data, beside his, so they travel with the run and stay with Kanto Reloaded off. Like his settings, a change waits until **Randomize Now**; Undo and Later work on them too. Random Learnsets are kept in the save with his Pokémon data and put back on every load, so nothing rolls again.

With Kanto Reloaded off, cody's screens come back and his engine carries on. Pokémon keep their rolled ability until they evolve or fuse. A code with the KR part needs Kanto Reloaded to paste.

## Archipelago

Linking a save to an Archipelago slot puts Kanto Reloaded's parts back to their defaults with cody's, so every save linked to the slot gets the same world. A failed link leaves them as they were. Difficulty hears of the level the slot sets at once.

## For Other Mods

```ruby
Reloaded::Randomizer.on?                      # Kanto Reloaded's Randomizer runs
Reloaded::Randomizer.randomized?              # ...and this save is randomized
Reloaded::Randomizer.seed                     # "K7Q2-9XMA"
Reloaded::Randomizer.code                     # the settings code
Reloaded::Randomizer.summary                  # Kanto Reloaded's settings, a line each
Reloaded::Randomizer::Abilities.add_owner_only(:MYABILITY)   # an ability only its own Pokémon may roll
```

Event: `:randomized` (`:seed`) after a Randomize Now.
