# Quality of Life

Toggles that make the game easier or quicker, and three tools. This is Roadmap topic 41 (Quality Assurance Toggles). The code is in `Core/QualityOfLife`, and the tools' screens are `Core/UI/QualityOfLifeScreens.rb`.

## Where They Are

**KIF Settings > Kanto Reloaded > Quality of Life**: one row each, under the Quality of Life heading (design 1). The heading's first row switches the whole feature on or off; it's also in **Features**. Every toggle is also in the Overworld Menu's add list under **Toggles** (an On/Off one is a switch A flips; a choice opens its dropdown, each choice explained), and each tool under **Actions**; none starts on a page (Edit Pages). A toggle kept by each save, and the tools, show there while a save is loaded.

## The Toggles

All start Off (Encounter Rate at Normal).

The ones that change how hard the game is are kept by **each save** (the row says THIS SAVE): a new game starts with them Off. The comfort ones are for **every save**.

| Toggle | Kept By | What It Does |
|---|---|---|
| Infinite Repel | Each save | A Repel's effect is always on, without using one. An incense still works as the game has it. |
| Auto-Repel Reuse | Every save | When a Repel wears off, another of the same kind is used from the Bag, with a toast at the top for a moment ("Used Another Super Repel", 4 LEFT): you keep walking. With none of that kind left, the game asks as usual. The Poké Radar's own short Repel is left alone. |
| Infinite Money | Each save | Your money shows the most there can be, and nothing lowers it. Shops sell you anything, in any amount. Money gained still goes into your real money ("You got $X" still shows), and turning it Off gives the real money back. Nothing fake is written into the save. |
| Rematch Money | Each save | Trainer rematches pay prize money, as first battles do (Kanto's rematch switch and rematchable Hoenn-style battles). A battle that pays nothing for another reason still doesn't. |
| Infinite Safari | Each save | No step is taken off while a Safari game is on. |
| Infinite PP | Each save | Your Pokémon's moves spend no PP (the foe's do), and the party's PP is full when a battle starts. |
| Upgraded PP | Each save | Every move's PP counts as if it had 3 PP Ups, the party's and the PC's, and moves learned later. Nothing is written into the save: Off puts each move back to its real most. |
| Level-Up Moves | Every save | Native (the game as it is), Ask (asks before learning any new move, even with a free slot) or Skip (never learns moves by levelling up: the Move Relearner still has them). It applies to level-ups in battle, Rare Candies, Super Candy and moves learned on evolving, not to TMs or tutors. |
| Always Obey | Each save | Your Pokémon always obey, whatever their level and your badges, unless the story makes one disobey. |
| Level Locking | Each save | Locks set in the Level Lock Manager apply. Setting a lock turns it On, so the lock works at once. Off pauses every lock without forgetting it. |
| Instant Hatch | Each save | Eggs in the party hatch on the next step (and an Egg in one of the Egg Manager's incubators is Ready at once). |
| Day Care Eggs | Each save | The Day Care has an Egg ready as soon as two Pokémon that get along are left there. |
| Encounter Rate | Each save | Fewer (half as often), Normal or More (twice as often) wild Pokémon on steps in grass, caves and water. Rock Smash is as it was. |
| Max Friendship | Each save | Your Pokémon count as fully friendly: friendship evolutions and Return work at once. |
| Guaranteed Catch | Each save | Every Poké Ball thrown at a wild Pokémon catches it. |
| Auto-Hook Fishing | Every save | PIF's own auto-hook while fishing: a bite never gets away. |
| Faster Evolutions | Every save | The evolution scene (the game's and EBDX's) plays three times as fast. B still stops it. |

## What a Save Remembers

A save keeps a quiet list of every balance toggle ever turned On in it, with when, and of play with KIF's DEBUG option on (noted when it saves). Nothing shows it in the game yet: later difficulty and game modes can use it (`Reloaded::QualityOfLife.used`). Bug Reports include what's On and the list.

## The Tools

Each opens as a popup over KIF Settings or the Overworld Menu, and needs a save loaded.

- **Nature Selector:** Pick a Pokémon (Party Rows: sprite, name, level, and each one's nature with what it raises and lowers), then a nature. The 25 natures are grouped by the stat they raise (Attack, Defense, Sp. Atk, Sp. Def, Speed), A to Z in each group, with the ones that change nothing last, A to Z. The one it has now says NOW. Beside the list, the Pokémon and each stat now and with the highlighted nature (green up, pink down). A sets it.
- **Level Lock Manager:** The party with each one's lock (a gold padlock and the level, or Not Locked), and a line when Level Locking is Off. A opens its lock: **Lock at** (Left and Right, from its level now to the highest; it turns Level Locking On if it's Off) and **Unlock**. A locked Pokémon is held at the start of its locked level: battle EXP, other EXP, a set level and a Rare Candy stop there, and a Rare Candy is refused instead of used up. The lock is kept on the Pokémon itself, so it goes with it to the PC, a trade or the Day Care.
- **Super Candy:** **Raise to** (Left and Right): the level cap (KIF's Level Cap, else PIF's Level Caps option, else the highest level), the highest in the party, or a level of your own (Up and Down). Under it, where each Pokémon would end up, a gold padlock where a lock stops it, or "Locked at" and "Already There"; a line says when Level Locking is Off and a lock is paused. A raises them one level at a time, learning each level's moves as the game does (Level-Up Moves applies), then evolutions come as after a battle (KIF's evolution lock is kept). No item is used, Eggs are left as they are, and nothing changes in KIF's No Levels mode. **Party Raised** then shows each one's levels, new moves in pink, an evolution, and the locks.

The new party screen (Roadmap topic Party Screen, built next) shows each Pokémon's level lock.

## For Mod Makers

`Reloaded::QualityOfLife.on?(:infinite_money)` says whether a toggle is On now (the feature on, and the toggle not at its first value); `value(:encounter_rate)` gives a choice's index. `level_cap(pokemon)` is the level it may reach now. `Reloaded::QualityOfLife::LevelLocks.get(pokemon)` / `set` / `clear` work a Pokémon's lock.
