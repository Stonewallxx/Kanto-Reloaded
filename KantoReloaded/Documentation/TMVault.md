# TM Vault

Every TM, HM and tutor move you've had, taught again for free, any time. This is Roadmap topic tm-vault: the old Kanto Reloaded's TM Vault (how it keeps the moves) with Hoenn Reloaded's screen, rebuilt in Reloaded's plate look. The code is in `Core/TMVault/TMVault.rb` (the moves, who can learn what, Coverage, teaching, the Checklist, the hooks) and `Core/UI/TMVaultScreen.rb` (the screens).

**TM Vault** in Kanto Reloaded > Features switches it, On to start. It takes over KIF's Tutor.net (`F-POKE-05_TutorNet`) and brings in what Tutor.net had unlocked. Off gives Tutor.net back.

## Where It Shows

- **The Pause Menu:** TM Vault, Pinned in Tutor.net's place (Tutor.net steps aside), its status the moves in it.
- **The Overworld Menu:** TM Vault, an action.
- **The party menu:** Relearn Moves (the game's Change Moves) opens the TM Vault's Relearn tab on that Pokémon.

It can't be opened in the Bug Contest, or on the maps where KIF's Tutor.net couldn't be either.

## What Comes In

- A TM or HM reaching the Bag: an item ball, a gift, a shop (`PokemonBag#pbStoreItem`).
- A move tutor teaching a move (`pbMoveTutorChoose`).
- Tutor.net's own `pbTutorNetAdd` (events and other mods call it).
- When a save loads: Tutor.net's unlocks and the machines already in the Bag (the first time, all of them count as seen, so nothing shows NEW).

Each new move shows a toast ("Added to TM Vault: Ice Beam", the TM's disc in its type and NEW), and stays NEW in the Vault until you've opened it.

## The Vault

- **The header:** Search on the left (L, or click it: type straight into it; a controller's A opens the naming screen) and Sort on the right (R: Name, Type, Category, Recent, Level Learned). Back clears a search.
- **The tabs:** Vault, Relearn and Checklist (Action, a controller's X).
- **The Type Filter:** Up from the top of the list. Left and Right pick a type (only the types the list has), Down goes back.
- **The list:** one panel, each move's name in its type's colour, Favorites first (a star: Favorite, a controller's Y), NEW, the TM's number (or Tutor) and the type's icon. The Checklist's rows have the TM's disc too.
- **The details panel**, lit in the move's type:
  - The party: Learned, Able or Not Able for each (PIF's own words). Left and Right pick who.
  - The move: its type, category, power, accuracy, PP and description.
  - **Coverage** for the one picked: the types its moves hit for super-effective damage now, and (+) what this move adds.

A teaches the move, free. With room, it asks first. With four moves, **Move Compare** opens: the new move on the left, the four it can replace on the right (the one to forget ringed red), and Coverage now and after, with what forgetting that one loses. Up and Down pick, A forgets it, B cancels. A Pokémon that already knows the move, can't learn it, or is an Egg says so.

## Relearn

The picked Pokémon's moves to relearn: KIF's own Change Moves list, so KIF's Egg Moves and Event Moves options decide what's in it. An Egg Move is marked EGG, the others the level they're learned at. The party strip says how many each one has. Teaching works as in the Vault.

## The Checklist

Each TM and HM you haven't had, in the game's order, with the kind of place the game gives it: **GROUND** (an item ball), **STORE** (a shop) or **GIFT** (someone gives it). The kinds are read from the game's maps once (the events that give machines), then kept for that KIF version in Kanto Reloaded's Settings folder (`TM Vault Kinds.json`). With the Randomizer's items or TMs on, a note says it may be somewhere else.

## For Other Mods

```ruby
Reloaded::TMVault.register(:THUNDERBOLT, source: :script, notify: true)   # true when it's new
Reloaded::TMVault.known?(:THUNDERBOLT)
Reloaded::TMVault.moves
Reloaded::TMVault.open(tab: :relearn, pkmn: $Trainer.party[0])
```

Events: `:tm_vault_registered` (`:move`, `:source`) and `:tm_vault_taught` (`:pokemon`, `:move`). The save keeps the moves, Favorites, what's been seen and the sort (SaveStore section `tm_vault`).

## Tests

```text
ruby Tools/Tests/tm_vault_test.rb "<KIF Beta>" <empty temp folder>
ruby Tools/Tests/tm_vault_preview.rb "<KIF Beta>" <work dir with metrics.json>
python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>
```

The first runs on stand-ins for the game's classes. It covers Tutor.net's unlocks and the Bag at load, a machine reaching the Bag, a move tutor, `pbTutorNetAdd`, the toast, NEW and Favorites, who knows, can learn or can't, Relearn (KIF's list and its Egg Moves), the level a move is learned at, Coverage, teaching (with room, and over a move in its place), the kinds read from map files, the Checklist, the Randomizer's note, the party menu's Relearn Moves, the menu entries, and Off.

The second drives the screens: the Vault, the party, a Favorite, Sort, the Type Filter, Search, teaching, Move Compare, Relearn (from the party menu too), the Checklist, the mouse, an empty Vault, the toast, and Light.

The mockups are in `Tools/Designs/tmvault`.
