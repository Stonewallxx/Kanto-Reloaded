# Party Screen

Kanto Reloaded's party screen, in his look (His Mix). This is Roadmap topic party-screen. The code is in `Core/PartyScreen/PartyScreen.rb` (the switch, mods' commands, words), `Core/UI/PartyScene.rb` (the screen) and `Core/UI/PartyPaint.rb` (its drawing).

## Where It Shows

Everywhere the game shows the party: the pause menu, using an item from the Bag, giving an item, choosing a Pokémon for an event (the Day Care, the Name Rater, trades), teaching a TM or a tutor's move, and battles (the game's and EBDX's switch screens). Choosing several Pokémon at once (a Battle Frontier entry) stays the game's own screen.

**Reloaded Party Screen** (KIF Settings > Kanto Reloaded > Reloaded Systems, On by default) switches it. Off gives the game's own party screen back.

## What It Shows

- **The cards:** Six, two across. Each has the Pokémon (Big Pokémon Icons or small, as you have it), its name, level, gender (KIF Beta's genderless and pizza icons too), its shiny star (KIF Beta's, coloured by the kind of shiny), types, status (SLP, PSN, BRN, PAR, FRZ, FNT, PKRS), HP and HP bar, held item or mail, and KIF Beta's evolution lock. A Pokémon with a level lock (Quality of Life) has a gold padlock by its level, dim while Level Locking is Off. Each card is lit in its type's colour, red when fainted; the highlighted one glows.
- **An Egg's card:** "Egg" and how close it is (Soon, Moving, Not Close, A Long Time).
- **Empty spots:** With fewer than six, a dashed outline saying EMPTY.
- **The details panel:** Lit in the highlighted one's type colour, with two bands of it from the top right to the bottom left. The highlighted one's picture, name, level, a thin EXP bar under the level (full and gold at its level lock), its types as the game's big labels (a little smaller, evenly between the EXP bar and the red line), its nature, ability and item, and its moves with PP.
- **An Egg's panel:** The steps left as a number and a bar, with the game's words for how close it is.
- **The title:** "Party", or what you're choosing for ("Move Pikachu Where?", "Teach Thunderbolt to Which?", "Give to Which Pokémon?").

## Using It

| Button | On the cards | In the menu |
|---|---|---|
| Up / Down / Left / Right | Choose (each goes round) | Up / Down choose |
| A | The Pokémon's menu, or picks it for what it's being chosen for | Picks the option |
| X | Its Summary | |
| Y | Picks it up to move (as Switch does) | |
| B | Close (or cancel) | Back (in a submenu: back to the menu) |

With the mouse, pointing picks, a click uses, a right click goes back, and the wheel steps through the cards or the menu. The hints at the bottom can be clicked.

- **The menu:** The details panel turns into it: the Pokémon at the top, then the game's commands in the game's order (field moves in blue, with their type), and what the highlighted one does at the foot. KIF Beta's own commands (the ones its hook adds) and any other mod's show too, because the game still builds the list. A submenu (Item, Mail, Nickname, RLD Actions, a mod's) opens in its place, under its heading.
- **Kanto Reloaded's names (his asks, 2026-10-21):** KIF Beta's Kuray Actions is **RLD Actions**, with only **Export** in it (and it's left out while Export can't be used); Change moves is **Relearn Moves**. Levels read "Lv. 35".
- **Switch:** The one moving keeps a gold edge and a MOVING tag, the title asks where, and the panel shows the two of them with a swap mark. A swaps them, B cancels. Moving an item, or a move used on another Pokémon (Milk Drink), marks the first pick with the gold edge too.
- **Choosing for something:** Those that can't (NOT ABLE) are greyed out and skipped; the rest keep their colour, with a note (ABLE, LEARNED). Teaching a move shows the move in the panel's top half (its name with the TM's icon, its type, POWER and ACC badges, STATUS for a status move, then what it does, up to four lines across the panel's width) and the highlighted Pokémon's moves under the red line.
- **Messages:** In a bar along the bottom; A goes on, a page at a time. A question is Kanto Reloaded's Yes/No popup.

## Theme Mode

Full screens are Dark or Light only (his call, 2026-10-21): Dark and Glass show it dark, Light and Frost in the Light frames' look, with the statuses deepened and the badges pale. It never goes see-through.

## For Mod Makers

```ruby
Reloaded::PartyScreen.add_command(:walk,
  :label => proc { |pkmn| pkmn.egg? ? nil : "Walk Together" },   # nil hides it
  :description => "Walks with you.",                              # at the menu's foot
  :handler => proc { |scene, pkmn, index| ... })
```

It shows before Cancel in a Pokémon's menu, outside battle. A command added to the game's own list (by changing `PokemonPartyScreen#pbPokemonScreen`, or through KIF Beta's hooks) shows as it is.

Kanto Reloaded's scene is a subclass of the game's `PokemonParty_Scene`, made whenever the game makes one while the screen is on. It replaces the game's command list and choosing at their innermost method (`kif_party_raw_commands` and `kif_party_pbChoosePokemon` with KIF Beta), so a mod that wraps them still runs around it.

## Tests

```text
ruby Tools/Tests/party_screen_preview.rb "<KIF Beta>" <work dir with metrics.json>
python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>
```

It runs the game's own party logic (`016_UI/005_UI_Party.rb`) and KIF Beta's command hook on the preview tool's stand-ins. It covers the cards and details, the menu in the panel with KIF Beta's and a mod's commands, a submenu and B back to the menu, RLD Actions (Export only) and Relearn Moves, a message, X for the Summary, Y to move and Switch's preview, an Egg, the mouse, a question, teaching a move (Grey Out), four Pokémon, a battle's menu, Light, Frost and Glass, Big Pokémon Icons, and Reloaded Party Screen Off.
