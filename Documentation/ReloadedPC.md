# Reloaded PC

A new PC: the whole box with its details, one press to move, in Reloaded's look. This is Roadmap topic reloaded-pc: Hoenn Reloaded's PC screen and old Kanto Reloaded's ideas, rebuilt on the game's own PC logic. The code is in `Core/PC/ReloadedPC.rb` (the switch, handing out the scene, the words), `Core/UI/PCScene.rb` (the screen) and `Core/UI/PCTools.rb` (the box tools).

**Reloaded PC** in Kanto Reloaded > Reloaded Systems switches it, On to start. Off gives the game's own PC back. It's built in steps: Step 1 is the box view, Step 2 the Actions, Step 3 the box tools (Sort, Box Overview, Rename, Wallpaper). Search, Party Presets and Compare come in the next steps.

## Where It Shows

Only how the PC looks and is driven is replaced. Kanto Reloaded's scene takes the place of the game's (`PokemonStorageScene.new` hands it out), and PIF's own `PokemonStorageScreen` still runs every rule: the last Pokémon, mail, rentals, the Transfer Box and its autosave, fusing, multi-select. KIF Beta's hooks still run too: Kuray Actions and KIF's box commands (the locks, Buy Box, Sort, Export, Import, Battle) arrive in the lists the scene draws. So every place the game opens the PC shows it:

- **The PC itself:** Organise, Withdraw and Deposit.
- **Elsewhere:** the Box Link, KIF's pause-menu PC, the Overworld Menu's PC, the PokéNav, a Secret Base's storage.
- **Choosing a Pokémon from the PC** (events, trades): the ones the game won't take are dimmed, and the header says CHOOSE A POKÉMON.
- **The Purify Chamber** and **KIF's Nuzlocke Graveyard** (its own loop: Summary only).

Old Kanto Reloaded and Hoenn Reloaded ran a PC of their own and copied the game's rules; their worst bugs (lost held Pokémon, Transfer Box losses, the wrong unfuse arguments, KIF's box commands picked by place in the list) came from that copy. None of that code is here.

## The Box

- **The header:** the box before (LB) and after (RB) either side, the box's name in the middle. A box KIF has locked shows a small red padlock and SORT or EXPORT after its name; an unlocked box shows nothing.
- **The box:** the whole 6 x 5 on its wallpaper, in the same places as the game's PC and other saves. The icons are PIF's own box icons, so KIF's Big Pokémon Icons shows in the box at All only (Limited means "except in boxes"), and KIF's shiny and fusion icons show.
- **The plate:** the highlighted one's details, lit in its type's colour: its picture (big at Limited and All), name, gender and shiny star, level, types, nature, ability, item and IVs (a 31 in gold). An Egg shows its steps. The marks it has on show small in the plate's top right corner.
- **The party:** along the bottom with HP bars (big icons at All, as KIF's PC party tab); an empty place is dashed.

## Moving

One press moves: A picks up and puts down, the game's own Quick Swap, which the PC keeps on.

- **Holding:** the held Pokémon floats over the slot under the cursor with a small shadow, and its old slot is outlined. Over an empty slot the plate shows it under HOLDING; over another Pokémon the plate shows that one (A swaps them), dimmed under the held one.
- **B puts it back:** where it came from, or, if that place has been taken (after a swap), the first free place in the box. The game only said "You're holding a Pokémon!".
- **X opens the Actions:** the game's list for the one under the cursor or held (Move, Summary, Fuse, Nickname, Withdraw, Item, Release), Kanto Reloaded's (Mark) and mods' before Release, and RLD Actions after it, each explained under it. A long list scrolls.
- **The box name:** Up from the top row. Left and Right change box there; A opens the Box Overview, X the box's actions (Jump, Select All, Wallpaper, Name, and KIF's).
- **LB and RB** change box from anywhere. B with nothing held asks the game's question (Continue Box operations?).
- **Fusing:** the box name gives way to a gold banner, the Splicer and FUSING WITH LAPRAS; a small Splicer rides with the held one, the plate shows the one you'd fuse with, and fusions are dimmed (they can't be fused again). B stops fusing.
- **The mouse:** pointing at a slot picks it, a click does what A does, a right click what B does, the wheel over the box changes box, a click on the box names either side goes to them.

Withdraw, Deposit, choosing from the PC and the Graveyard run the game's own loops: there A opens the game's list.

## The Actions

- **RLD Actions:** all of KIF's Kuray Actions in one list under small-caps headings: Export (Export, Export All Pokémon), Evolution (Lock or Unlock Evolution, when KIF's option is on) and Shiny (Sell Shininess, and the debug tools with DEBUG on). Gamble for Shiny is left out. A heading with nothing under it doesn't show; KIF's own module switches still hide the ones that are off, and an action a mod adds to KIF's list goes under More.
- **Mark:** PIF's six marks (circle, triangle, square, heart, star, diamond) in a row, lit when on: Left and Right choose, A marks or unmarks, B is done. In the Actions, and in Deposit's and the Purify Chamber's lists where PIF has it. The marks also show in the Summary.
- **The box's actions** (X on the box name): the game's and KIF's (Jump, Select All, Wallpaper, Name, the locks, Buy Box, Sort, Battle, Export, Import), each explained, then mods'.
- **Buy Box:** KIF's message and list become a question, Buy a Box?, or Not Enough Money, with the cost and your money in green when you have enough, red when you don't.

## The Box Tools

- **Sort:** one popup in place of KIF's Sort and Sort (All Boxes). Three rows: Sort by (KIF's 26 ways; Left and Right step through them, A lists them all), Order (worded for the way: Highest First, A to Z, Newest First) and Boxes (This Box or Every Unlocked Box); Sort or Cancel. The line under the rows says what will happen. KIF's own values are used (Base Stat Total with KIF's fusion rules), Marks sort by how many are on, ties keep their order, Eggs go last, and the Pokémon are packed from the first place. A box locked for sorting is left alone, also when it's the one you're in. The last choice is kept for the session, and a toast says what was done.
- **Box Overview** (A on the box name): every box three across, each with its name, how full it is (gold when full), its 30 places as dots in their Pokémon's type colours, its shinies and Eggs, and a padlock when it's locked; the box you're in is outlined. Buy Box comes last, its price in green when you have the money, red when you don't. A goes to that box. Holding a Pokémon, the title asks Move Lapras to Which Box?, the highlighted box shows how much room it has with its first free place outlined in green, and A drops it there (the game's own placing, so its rules still apply). The Transfer Box isn't shown, as in the game's Jump.
- **Rename** (Name in the box's actions): the box name becomes a field where it is. Type straight in on a keyboard, Enter or Down is done; a controller's A opens the naming screen; B cancels.
- **Wallpaper:** a grid of the wallpapers, five across, instead of the game's list of 200 names (PIF's unlocked ones, then KIF's 160). The highlighted one's name shows under the grid and the box's own has NOW on it; it scrolls. Only the wallpapers in view are loaded.

## Messages and Lists

The game's messages show as Kanto Reloaded's notice, its Yes and No questions as Kanto Reloaded's question, its other lists as Kanto Reloaded's menu (titled with the Pokémon's name, each action explained), and Jump's box list as Kanto Reloaded's picker.

## If It Fails

If the Reloaded PC fails during a visit, a held Pokémon goes back first (where it came from, else the first free place), the game's own PC takes over for the rest of the visit, and the log says why; the game's PC opens from then on until the game restarts. If it can't open at all, the game's opens.

## Coming Next

- **Step 4:** Search (matches lit in every box, LB / RB to the next box with one) and multi-select (Y marks any; Sort gets The Selected, and Box Overview drops all of them in).
- **Step 5:** Party Presets (Swap In trades places).
- **Step 6:** Compare.
- **Also picked:** NEW marks on Pokémon that came in since the last visit, and drag and drop with the mouse. The PC already opens on the slot it was on last (this session).

## For Other Mods

An action for a Pokémon (in its Actions, or under a heading in RLD Actions with `:group`) or for a box (in the box's actions):

```ruby
Reloaded::PC.add_action(:copy_stats, :label => "Copy Its Stats", :group => "Export",
  :description => "Copy its stats as text.",
  :enabled => proc { |pkmn| !pkmn.egg? }, :disabled_reason => "An Egg has no stats yet.") do |screen, pkmn, selected, heldpoke|
  ...
end

Reloaded::PC.add_action(:tidy, :label => "Tidy Up", :scope => :box, :description => "...") do |screen|
  ...
end
```

`:label` can be a proc (nil hides the action), `:enabled` a proc (a disabled action shows dimmed, its `:disabled_reason` under it in red), `:order` sorts them. The handler gets PIF's `PokemonStorageScreen` (its `pbDisplay`, `pbConfirm`, `storage`, `pbHardRefresh`) and, for a Pokémon, where it is (`[box, index]`, `[-1, index]` in the party) and the held one. `Reloaded::PC.remove_action(:id)` takes one away. KIF's own registries (`KIF::PCActions`, `KIF::BoxCommands`, `KIF::MultiCommands`) still work and show in the same lists.

## Tests

`ruby Tools/Tests/reloaded_pc_preview.rb "<KIF Beta>" <work dir with metrics.json>` drives the Reloaded PC with PIF's own storage, scene and screen, 6.8.2's multi-select and KIF Beta's Kuray Actions, box commands, locks and wallpapers on the preview's stand-ins: Organise (pick up, place, swap, B puts back, the Actions, RLD Actions' headings, Mark, the box name and its commands with a mod's, Buy Box, LB and RB, the locks, the party), the box tools (Box Overview with the mouse, Buy Box and dropping a held one in, Sort for one box and every unlocked one with a locked box left alone, Rename by typing and by the naming screen, the wallpaper grid), the fusing banner, Withdraw, Deposit, choosing with the dimmed ones, the mouse, Recent Steps, the fallback and Off.
