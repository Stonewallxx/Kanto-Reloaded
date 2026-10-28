# Reloaded PC

A new PC: the whole box with its details, one press to move, in Reloaded's look. This is Roadmap topic reloaded-pc: Hoenn Reloaded's PC screen and old Kanto Reloaded's ideas, rebuilt on the game's own PC logic. The code is in `Core/PC/ReloadedPC.rb` (the switch, handing out the scene, the words), `Core/UI/PCScene.rb` (the screen), `Core/UI/PCTools.rb` (the box tools), `Core/UI/PCPicks.rb` (Free Picks), `Core/UI/PCSearch.rb` (Search), `Core/PC/Presets.rb` and `Core/UI/PCPresets.rb` (Party Presets), `Core/UI/PCCompare.rb` (Compare), `Core/UI/PCBoxMove.rb` (Move Box).

**Reloaded PC** in Kanto Reloaded > Reloaded Systems switches it, On to start. Off gives the game's own PC back. It's built in steps: Step 1 is the box view, Step 2 the Actions, Step 3 the box tools (Sort, Box Overview, Rename, Wallpaper), Step 4 Free Picks and Search, Step 5 Party Presets, Step 6 Compare.

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

- **Holding:** the held Pokémon floats over the slot under the cursor with a small shadow, and its old slot keeps a soft dark patch, like a shadow of where it was. Over an empty slot the plate shows it under HOLDING; over another Pokémon the plate shows that one (A swaps them), dimmed under the held one.
- **B puts it back:** where it came from, or, if that place has been taken (after a swap), the first free place in the box. The game only said "You're holding a Pokémon!".
- **X opens the Actions:** the game's list for the one under the cursor or held (Move, Summary, Fuse, Nickname, Withdraw, Item, Release), Kanto Reloaded's (Mark) and mods' before Release, and RLD Actions after it, each explained under it. A long list scrolls.
- **The box name:** Up from the top row. Left and Right change box there; A opens the Box Overview, X the box's actions (Jump, Select All, Wallpaper, Name, and KIF's).
- **LB and RB** change box from anywhere. B with nothing held asks the game's question (Continue Box operations?).
- **Fusing:** the box name gives way to a gold banner, the Splicer and FUSING WITH LAPRAS; a small Splicer rides with the held one, the plate shows the one you'd fuse with, and fusions are dimmed (they can't be fused again). B stops fusing.
- **The mouse:** pointing at a slot picks it, a click does what A does, a right click what B does, the wheel over the box changes box, a click on the box names either side goes to them.
- **Drag and drop:** press on a Pokémon (or a picked one, for all the picks) and move with the button held: it floats right under the pointer, and letting go puts it down on the place there (or swaps, as A would). Let go off the places and it goes back where it came from. A click without moving still just picks up.

Withdraw, Deposit, choosing from the PC and the Graveyard run the game's own loops: there A opens the game's list.

## The Actions

- **RLD Actions:** all of KIF's Kuray Actions in one list under small-caps headings: Export (Export, Export All Pokémon), Evolution (Lock or Unlock Evolution, when KIF's option is on) and Shiny (Sell Shininess, and the debug tools with DEBUG on). Gamble for Shiny is left out. A heading with nothing under it doesn't show; KIF's own module switches still hide the ones that are off, and an action a mod adds to KIF's list goes under More.
- **Mark:** PIF's six marks (circle, triangle, square, heart, star, diamond) in a row, lit when on: Left and Right choose, A marks or unmarks, B is done. In the Actions, and in Deposit's and the Purify Chamber's lists where PIF has it. The marks also show in the Summary.
- **The box's actions** (X on the box name): the game's and KIF's (Jump, Select All, Wallpaper, Name, the locks, Buy Box, Sort, Battle, Export, Import), each explained, then mods'.
- **Buy Box:** KIF's message and list become a question, Buy a Box?, or Not Enough Money, with the cost and your money in green when you have enough, red when you don't.

## The Box Tools

- **Sort:** one popup in place of KIF's Sort and Sort (All Boxes). Three rows: Sort by (KIF's 26 ways; Left and Right step through them, A lists them all), Order (worded for the way: Highest First, A to Z, Newest First) and Boxes (This Box or Every Unlocked Box); Sort or Cancel. The line under the rows says what will happen. KIF's own values are used (Base Stat Total with KIF's fusion rules), Marks sort by how many are on, ties keep their order, Eggs go last, and the Pokémon are packed from the first place. A box locked for sorting is left alone, also when it's the one you're in. The last choice is kept for the session, and a toast says what was done.
- **Box Overview** (A on the box name): every box three across, each with its name, how full it is (gold when full), its 30 places as dots in their Pokémon's type colours, its shinies and Eggs, and a padlock when it's locked; the box you're in is outlined. Buy Box comes last, its price in green when you have the money, red when you don't. A goes to that box. Holding a Pokémon, the title asks Move Lapras to Which Box?, the highlighted box shows how much room it has, the dot of the place it would land in its colour and pulsing, and A drops it there (the game's own placing, so its rules still apply). The Transfer Box isn't shown, as in the game's Jump.
- **Move Box** (Y on a box in Box Overview, or Move Box in a box's actions): the box comes up, lit, with a MOVING pill and a soft shadow under it, and the tiles show the new order as it moves; A puts it down, B puts it back where it was. It moves with its Pokémon, name, wallpaper and locks, the boxes between shift along, the Transfer Box keeps its place, and the box you're in stays the one you're in. From the box's actions, Box Overview closes once it's put down. Nothing can be held while a box moves.
- **Rename** (Name in the box's actions): the box name becomes a field where it is. Type straight in on a keyboard, Enter or Down is done; a controller's A opens the naming screen; B cancels.
- **Wallpaper:** a grid of the wallpapers, five across, instead of the game's list of 200 names (PIF's unlocked ones, then KIF's 160). The highlighted one sits on a plate in the cursor's colours, its name shows under the grid, and the box's own has NOW on it; it scrolls. Only the wallpapers in view are loaded.

## Free Picks

- **Y picks** the Pokémon under the cursor (Y again unpicks it): a green tick in its corner, its place lit, and N PICKED on the plate. Picks are one box's at a time; picking in another box starts afresh, and they wait while you look at other boxes. Select All in the box's actions picks every one. B clears them.
- **A picks them all up** (PIF's own multi-select pick-up, so its rules hold: none from the Transfer Box). Held, they ride in a small fan over the cursor, the plate says HOLDING 4, and a soft green patch marks each place they'll land: the free places from the cursor on, then from the box's start. A puts them down there, or at the party's end when it has room. LB and RB carry them to another box, Box Overview drops them all into a box from its first free place, and B puts them back where they came from, still picked.
- **X with picks** opens the list for several: Pick Up All, Sort (the picked ones, sorted in their own places), PIF's Release with DEBUG on, and KIF's Battle Selected, Export and Release, which all take the picks as the selection.

## Search

- **RS** (or a click on the Search hint) opens it. The box name becomes the field: type straight in, or a controller's A opens the naming screen. The filters take the party's place: Type (A picks one), Shiny, Egg, Fusion and Held Item, with what's found under them (2 here, 1 in 1 other box). Down goes to the filters, Up back to the name; RS or Enter is done, B clears it.
- **More Filters:** MORE ends the filters (MORE: 2 when two of its filters are on); A on it opens the rest as rows. Ability and Knows (a move): type a name straight in (a part of it is enough; a controller's A opens the naming screen), or Left and Right step through the ones your Pokémon have. Nature (A lists yours), Gender, Level (1-10, 11-20 ... 91-100), Perfect IVs (1 or More up to All 6 at 31), Marked (any mark, or one shape) and NEW: Left and Right. What's found shows under the rows as they change; B or Enter is done. An Egg matches none of them but Marked and NEW, as it gives nothing away.
- **What it finds:** the name or nickname (and the species, but never an Egg's) with every filter that's on. Everything else dims as you type, in the box and the party.
- **After:** a pill by the box name says what's searched and how many are here (WATER: 3), the box names either side are the nearest boxes with a match and how many, and LB and RB jump to them. RS changes the search; B clears it. It lasts until it's cleared or the PC closes.

## Party Presets

- **Where:** a page of Box Overview. LB and RB switch between Box Overview and Party Presets (while organising, with nothing held). Each preset is a card with its name and its Pokémon; one that's gone (released, traded, fused into another) shows as a red ?, and the preset that is your party now says NOW.
- **+ Save Current Party** (the last card) saves the party as a new preset, named in place like a box: type straight in, or a controller's A opens the naming screen. An empty name becomes Team 1, Team 2 and so on.
- **A swaps one in.** Each of its Pokémon in a box trades places with a party member that isn't in it, so the boxes stay as they were; party members left over go to the first free places from the box you're in; your party becomes the preset, in its order. Members that are gone or in the Transfer Box are skipped. A toast says it's done; only when someone wasn't found does a notice say who. It's all worked out before anything moves, and it doesn't happen when none of its Pokémon can battle, when a party member going to a box holds Mail, or when the boxes have no room.
- **X gives a preset's options:** Swap In, Save the Party Here (after a question), Rename (in place), Delete (after a question; no Pokémon are moved).
- **Saved in the save:** each member is a reference to that Pokémon (its personal ID), never a copy, so nothing can be duplicated; its name and level at the time are kept only to say who's missing.

## Compare

- **Compare** is in a Pokémon's Actions (not for an Egg). The cursor then picks the second from any box or the party: COMPARE WITH LAPRAS shows in the box name's place, and the first one wears the regular cursor in gold. A on another opens Compare; B stops.
- **The screen:** the two face each other on top (picture, name, level, types). Under them a row per stat (HP, Attack, Defense, Sp. Atk, Sp. Def, Speed), then the base stat total (KIF's, fusions included), IVs and EVs, each with a bar growing outward. The better one's bar and number are in the row's own colour (HP green, Attack and Sp. Atk red, Defense and Sp. Def blue, Attack and Defense the darker ones and Sp. Def a lighter blue, Speed pink, base total a light tan, IVs orange, EVs purple), the other's bar grey. Then nature (its + stat green, its - stat red), ability and item (in its Bag pocket's colour, as the Reloaded Bag shows it).
- **X: their moves**, in detail: each with its type, Physical, Special or Status, power, accuracy and PP; the cursor moves over them (Left and Right between the two) and the highlighted move's description shows at the foot.
- **A** picks another to compare with (the first stays); **B** goes back to the box.

## NEW Marks

Pokémon that came into the boxes since the PC last closed (caught, hatched, imported, sent from a trade) have a small green NEW in their place's corner, and a box's tile in Box Overview says how many (3 NEW). They stay NEW for the whole visit and stop when the PC closes, the TM Vault's way. The save keeps the personal IDs of what was in the boxes and the party when the PC closed; the first visit marks nothing.

## Messages and Lists

The game's messages show as Kanto Reloaded's notice, its Yes and No questions as Kanto Reloaded's question, its other lists as Kanto Reloaded's menu (titled with the Pokémon's name, each action explained), and Jump's box list as Kanto Reloaded's picker.

## If It Fails

If the Reloaded PC fails during a visit, a held Pokémon goes back first (where it came from, else the first free place), the game's own PC takes over for the rest of the visit, and the log says why; the game's PC opens from then on until the game restarts. If it can't open at all, the game's opens.

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
