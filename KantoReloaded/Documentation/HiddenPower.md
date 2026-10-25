# Hidden Power

Every Pokémon's Hidden Power has a type of its own, shown wherever the move shows, and two ways to change it: the Ruins of Alph researcher's Type Reel and the plates. Always on with Kanto Reloaded: there's no switch. The code is in `Core/HiddenPower/` (`HiddenPower.rb` the type, `Battle.rb` the Fight menu, `Summary.rb` the Summary, `Researcher.rb` the map events, `Plates.rb`, `Chamber.rb`); the popups are in `Core/UI/HiddenPowerScreens.rb`.

## Where a Type Comes From

- **A new Pokémon** (a catch, an Egg, a gift, a trainer's) gets a random type when it's made: one of the 17 standard types but Normal, each as likely. It's kept in PIF's own field (`Pokemon#hiddenPowerType`), which PIF's move, its AI and cody's Move Effectiveness already read, so a save keeps every type even with Kanto Reloaded off.
- **Unown,** and any fusion with Unown, has a neutral Hidden Power (???): It hits every type x1, as the researcher always said. Nothing changes it.
- **A Pokémon from before** keeps the type it has: its IVs' type, or the one the Hidden Chamber gave it. One whose IVs gave a neutral type gets a roll. This runs once when a save loads (the party, every box, the Day Care and the two Pokémon a fusion gives back); after that there's nothing to do.
- **Why not the IVs:** In KIF Beta, PIF's formula picks from 28 types (a second ??? and the triple-fusion types), so more than a third of Pokémon got a Hidden Power that hit everything x1, and any Pokémon with six 31 IVs got Ground/Electric/Psychic.

## Power

PIF's own: 30 to 70, worked out from the IVs (the game runs generation 5's rules). Every screen that shows Hidden Power's power shows the Pokémon's real one.

## Fusions

- **Fusing:** The fusion gets a type of its own, from its two Pokémon. The same two fused again, either way round, get the same type, so fusing again is never a free reroll.
- **Changed while fused:** A spin or a plate on the fusion is remembered for that pair.
- **Unfusing:** Each Pokémon gets back its own type. A DNA Reverser keeps the fusion's.

## Where It Shows

- **Battles:** The Fight menu shows Hidden Power in its real type: EBDX's own button for that type, and PIF's button and type icon with EBDX Off. Every move whose type the battle works out for its user shows its real type too: Weather Ball in weather, Judgment, Techno Blast and Multi-Attack by item, Natural Gift, Revelation Dance, the -ate abilities' Normal moves, Ion Deluge and Electrify.
- **Out of battle:** PIF's Summary (the moves and move-learn pages), and Kanto Reloaded's teaching panel, Party Screen and TM Vault.

## The Researcher

In the Ruins of Alph lab. After his lines about Unown, he offers to spin a Pokémon's Hidden Power for $5,000 a spin.

- **Choosing:** The Party Screen, "Spin Whose Hidden Power?". Eggs can't be chosen; Unown gets its notice.
- **The Type Reel:** The Pokémon beside a reel of the 17 types, its own in the band. Spin takes the money and decides the new type, never the one it has; the reel spins two turns and slows onto it, about 2 seconds (A skips to it). Then Again or Done.
- **Not enough money:** The line and the price in red, and Spin can't be chosen.

## The Plates

The 17 plates set the exact type: Use one from the Bag on any Pokémon but an Egg, and it's used up. One that has that type already doesn't take it, and Unown's stays neutral.

- **In the Bag,** a plate's details show the party: each Pokémon's Hidden Power type now, in its colour, "Already Ice" where the plate would change nothing.
- **After using one,** a notice says what it became (ROCK > ICE) and that the plate was used up.
- **Held,** a plate still powers up its type's moves.
- **Where they are:** Item balls across Kanto and Johto, three in the Hidden Chamber, and one a day from the chamber's visitor.

## The Hidden Chamber

PIF's chamber stays: a plate in the basket gives the room its type, and the altar teaches that type of Hidden Power. Its faults are fixed:

- **A Pokémon that knows Hidden Power** can take the room's type, for free ("Change Pikachu's Hidden Power?"). PIF's said it already knew the move.
- **The basket empty:** The altar says so. PIF's taught a Normal-type Hidden Power that even hit Ghost types.
- **Swapping plates** gives the old one back. PIF's stopped with an error and lost it.
- **The daily plate** can be the Flame or Draco Plate. Two of PIF's outcomes gave the Mind and Spooky Plates again.
- **The tablet** beside the basket says what the basket holds and the room's type ("The Flame Plate rests in the basket."). With the basket empty, it's PIF's "Offer an elemental plate."

## The Endgame Challenge

Against a Wonder Guard party, the challenge's trainers learn Hidden Power to hit it. Their IVs were meant to give Fire, Dark or Fairy, but in KIF Beta they gave other types, so the move did nothing. Their Hidden Power now gets the type the counter needs.

## For Mods

- `Reloaded::HiddenPower.type_of(pkmn)` and `power_of(pkmn)`: a Pokémon's type and power.
- `Reloaded::HiddenPower.move_type(pkmn, move)` and `move_power(pkmn, move)`: a move's type and power for this Pokémon (Hidden Power's own; any other move's from its data).
- `Reloaded::HiddenPower.set(pkmn, type)` sets one (Unown's stays neutral); `reroll(pkmn)` gives a new random one. Each change emits `:hidden_power_changed` (`:pokemon`, `:from`, `:to`, `:how`).
- Hidden Power is matched by its function code, `090`, never by name alone: `HIDDENPOWER2`, and KIF-ER's Secret Power and Techno Blast, use it too.
- **A map event's list:** `Reloaded::HiddenPower::EventLists.register(map, event, crc, name) { |list| new_list }` runs a list of your own in place of PIF's for that event, only while PIF's still has that fingerprint (`EventLists.crc(list)`); after a game update that changes it, PIF's runs and the log says so.
