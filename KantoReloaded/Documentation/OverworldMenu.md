# Overworld Menu

A quick menu you open while walking, in the Tabbed Panel design. This is Roadmap topic 35. The code is in `Core/OverworldMenu`, and the screens are `Core/UI/OverworldMenuScreen.rb` and `Core/UI/OverworldPagesScreen.rb`.

## Opening It

**Overworld Menu** is its own action in **Controls > Overworld > Menus**: **Select** (tapped) and **F** at first. In the Pokémon-Style layout, holding Select still Quicksaves.

It never opens during a cutscene, a message, a map change, while placing furniture, or wherever the game has the menu shut. A press while you're mid-step opens it once you stop. With Reloaded Controls Off, F still opens it.

Switch it off in **KIF Settings > Kanto Reloaded > Features**.

## What It Shows

The map stays in view. Its colours follow **Theme Mode** (Kanto Reloaded > Interface), as the Pause Menu's do: Dark, Glass (see-through), Light (the Light frames' pale look) or Frost (Light, see-through), its popups too.

- **Left panel:** The page tabs, the page's entries (name and live status; no icons) and the **Quick Items** bar under it.
- **Top right:** Where you are (the map's name in green), the weather and the time of day, and how many of the Pokémon found here you've caught ("3 of 7 Caught").
- **A view:** **Y** steps through the views, then none, and the menu remembers the one you left on. Today there's **Party View**; Weather View comes with the Weather System. How Party View looks is a setting on the Overworld Menu page:
  - **Full:** Big cards over the right side, two to a row and three rows (design 1, Two Columns). The held item is top right, and the name is centred beside it (across the whole card when there's no item); a name too long even then uses the tiny pixel font, never "...". The battle sprite (its fused one) is on the left, and the level (with the gender, and a star when shiny), types (up to three), status and HP are centred beside it, with the HP bar along the bottom. Y hides the view when it's in the way.
  - **Compact** (the first setting): The bottom right, three to a row, each card with the Pokémon's icon, name and level, HP and any status (a long name shortens to fit beside its level); four to six Pokémon stack a second row above the first.

## The Pages

**Main** is the one built-in page, and it starts with the actions: **Quick Items**, **Time Changer**, **Fly** (when a Pokémon knows it), **Field Moves**, **Repel** (steps left, or Off; while none is on, use one of yours from here; a gold ∞ mark while Infinite Repel is On) and **Quick Save** (the game's save screen, once the menu has closed; its row says when you last saved, green under 30 minutes, orange under an hour, and red after that or before the first save).

**Field Moves** (when a Pokémon knows one besides Fly) lists the others your party can use where you stand, as KIF Beta's Ready Menu finds them: Cut, Surf, Strength, Rock Smash, Flash, Dig, Teleport, Waterfall, Sweet Scent and more, one row per move with the Pokémon that knows it. A pick runs once the menu has closed, after the game's own "use it?" question; Teleport opens the region map, as Fly does.

Everything else, settings included, starts on no page. You put what you want on Main or on a page of your own (Edit Pages, Z):

| Kind | Entries |
|---|---|
| Settings | **Any setting** in KIF Settings (KIF Beta's, PIF's and Kanto Reloaded's own: On/Off, choices, sliders and numbers), and **any button** there (Change Controls, Save Manager, Make a Bug Report...), named as KIF Settings names it. Not the rows that only open another page of KIF Settings, nor the Overworld Menu's own switch (it would close the menu from inside it). Edit Pages > **Add a Setting** opens KIF Settings in pick mode (its sections and search): A on a setting puts it on the page, and nothing is changed there. On the page, an On/Off setting is a green switch A flips, a choice opens its dropdown, the same as in KIF Settings (each choice explained under it), a slider or number opens its slider (see below), and a button is pressed as KIF Settings presses it, the menu out of sight while its screen is open. A setting a mod has locked says so and can't be changed. One that isn't there now (its module Off, its mod removed) stays on the page, out of sight, and so does one of Kanto Reloaded's from a page that's hidden now (the Timing Profiler's and Developer Tools', with DEBUG Off) |
| Actions | The **Quality of Life** tools (Nature Selector, Level Lock Manager, Super Candy), **Area Encounters** (the wild Pokémon here: see below), **Last Used Item** (the item you used last, from the Bag or the map, by its name and how many you have: used again the game's way), **PC** (KIF Beta's PC from anywhere, while KIF's QoL setting has it in the pause menu), **Return** (the Entrance Randomizer's way back, named as KIF Beta names it; the menu closes for the trip), **Quest Log** (the quest log, whether or not you have a main quest), **Quit Safari** and **Quit Contest** (only in the Safari Zone or the Bug Contest) |
| Toggles | **Speed-Up** (it follows the type: Toggle, the speed now, x1 to Toggle Limit; Hold, Speed-Up (Overworld), x1 to x10; A opens its dropdown. With Kanto Reloaded's Speed-Up Off, PIF's stages, while PIF's is set to Toggle; see [SpeedUp.md](SpeedUp.md)), **Bicycle** (once you have it: its switch is On while you ride, and A gets on or off where you can, saying why when you can't, as the Bicycle itself does), and every **Quality of Life** toggle (an On/Off one is a switch, a choice like Encounter Rate opens its dropdown; see [QualityOfLife.md](QualityOfLife.md)) |
| Readouts | **Quest** (your main quest by name; it opens the quest log), **Safari Balls** and **Safari Steps** (steps left; the gold ∞ mark while Infinite Safari is On), or **Caught** and **Sport Balls** (each its own row: a row has room for one), **Met This Session** (wild Pokémon met since the game started this time), **Since a Shiny** (in this save), **Itemfinder** (the nearest hidden item, "3 N, 2 E", once you have the Itemfinder), **Level Cap** (while KIF's or PIF's Level Caps are on, KIF's first, as Super Candy reads them), **Day Care** (Egg, how many are inside, or Empty; A opens the Egg Manager's Day Care panel as a popup, Design 1: the two side by side, how well they get along in hearts, each one's levels gained and what taking it back costs, and the Egg waiting; while the Egg Manager is On it glows while an Egg waits, says to collect it in the Egg Manager, and its Egg Manager hint (Action) opens the Day Care tab, see [EggManager.md](EggManager.md)), **Poké Radar Chain** (while there's a chain), **Play Time** ("41h 12m"), **Pokédex** (SEEN 112 CAUGHT 64, once you have it; A opens it as the pause menu does), **Badges** (eight pips, the earned ones gold; sixteen once one past the eighth is earned), **Shiny Odds** (1 in 4096: KIF's Wild Shiny Odds with the Shiny Charm's extra rolls and PIF's friends'; during a Poké Radar chain, its shaking grass's), **Coins** (Game Corner coins, once you have the Coin Case), **Roaming Pokémon** (once one is loose: its name and the map it's on, or how many there are; A lists each and where it is) |

A layout saved before 2026-10-20 had Toggles and Info as built-in pages. The first start after it drops each one, unless you'd put an entry of another kind on it (then it stays, as a page of your own), and moves Time Changer up below Quick Items.

Kanto Reloaded's later features add theirs: PokeVial (in place of KIF's Heal), Heal with Moves, TM Vault (see [TMVault.md](TMVault.md)), Reloaded Shop (in place of the Kuray Shop), Egg Manager, EV Gains (the last battle's board: see [CriticalEVGain.md](CriticalEVGain.md)) and Wild Link.

Something you can't use now shows dimmed with a lock, and says why when chosen: Fly where you can't fly, or Quick Save in the Safari Zone.

### Area Encounters

Wild Link's list in a popup (Design 1, so the quick look and the DexNav match). A tab for each way the wild Pokémon here are met (Grass, Cave, Surfing, Fishing, Rock Smash, and the Bug Contest during the contest), with Seen and Caught for it. Each row has the Pokémon (a silhouette until you've seen it, and ??? for its name), a ball once caught, its levels and how often it appears. The picture is cut down to the Pokémon itself and fitted to 34 px, so it fills its row whatever the size of its frame (Bigger Rows, his pick 2026-10-21). Fishing puts each rod under its own heading. The tables are the game's own, for the time of day now, as the game picks them.

Left and Right (or a click) change the tab; Up and Down (or the wheel) scroll a long one; B, A or a right click close it. It opens on Surfing while you surf, and it's only as tall as the longest tab needs (up to six rows; a rod's heading takes less room than a row).

With KIF Beta's **Big Pokémon Icons** on, its rows show each one's battle sprite, and so does the Day Care popup (its Egg too), each in the small icon's room.

### Sliders and Numbers

A slider or number from KIF Settings (Music Volume, Wild Shiny Odds...) shows its value on its row. A drops its slider over the rows under it (above it near the bottom), as a choice's dropdown drops: Dropped Slider, his pick 2026-10-21. It has the value, the lowest and highest, and a bar. Left and Right change it a step (the setting's own: Music Volume goes by 5), L and R ten steps, and the wheel a step; a click on the bar puts it there. A, or a click off the bar, sets it; B or a right click leaves it as it was.

### Time Changer

Pick **Days Ahead** (0 to 9) and the **Hour**. The popup shows the time now and where it lands ("Then Thu 6:00 PM"). Time only goes forward: today with an hour that's gone means tomorrow. The map refreshes afterward, so lighting and time events follow. It's hidden while the game has time stopped.

## Controls

| Button | In the list | On the Quick Items bar |
|---|---|---|
| Up / Down | Choose | Up goes back to the list |
| Left / Right | Change pages | Choose a slot |
| A | Use (a switch flips, a choice opens its dropdown, a number its slider) | Use the item, or pick one for an empty slot |
| X | Edit Pages | Change or clear the slot |
| Y | The next view | |
| B | Close | Back to the list |
| Its own button (Select, F) | Close | Close |

With the mouse, pointing picks, a click uses, a click on a tab turns to it, the wheel scrolls, and a right click closes. The hints at the bottom can be clicked.

## Quick Items

Seven slots, kept in each save. A slot takes any item with a use outside battle: Potions, Repels, the Bicycle, Rods, TMs. The game's own Bag picks it, showing only those (the Reloaded Bag's banner says which slot). The Reloaded Bag's actions add an item to the first empty slot or take it out (`quick_slot`, `add_quick_item`, `remove_quick_item`).

Using one:

- **A field item** (the Bicycle, a Rod, a Repel): the menu closes and the game uses it.
- **Anything else** (a Potion on a Pokémon): the game's own item use, and the menu stays.

A slot whose item you've run out of stays, dimmed.

## Edit Pages

**X** in the menu, or **Edit Pages** in **KIF Settings > Kanto Reloaded > Overworld Menu**. The pages are on the left, then **Add Page**; the entries are on the right.

- **On a page:** A goes to its entries. **Edit Page** (Y) renames it, resets it, or removes it (your own pages only). Resetting a built-in page puts back every entry it starts with.
- **The list:** **On This Page** first, in the page's order; then everything else under **Actions**, **Toggles**, **Readouts** and **Settings** (Add a Setting).
- **On an entry:** A puts it on the page or takes it off. X picks it up, and Up and Down carry it.
- **Add a Setting** (the last row of every page's list): KIF Settings in pick mode. A on a setting or a button puts it on the page; Left, Right and Default change nothing there.
- **Add Page:** Type a name (or none, for "Page 4"). There can be up to 7 pages.

Every entry can go on any page. The pages are the same in every save, kept in `Settings\Overworld Menu.json` in the mod folder.

A new entry (a feature built later) joins its kind's page the first time it's seen. One you took off a page stays off. An entry whose mod was removed stays in the layout, out of sight, in case the mod comes back.

## Settings

| Setting | Where | What it does |
|---|---|---|
| Overworld Menu | Features, and the Overworld Menu page | On or Off |
| Edit Pages | Overworld Menu | The page editor |
| Party View | Overworld Menu | How Party View looks: Full or Compact |
| Menu Animations | Interface | The panel slides in and the rest fades in; shared with the Pause Menu |

## For Kanto Reloaded's Features

```ruby
Reloaded::OverworldMenu.register(:pokevial, :name => "PokeVial", :kind => :action,
  :priority => 25, :feature => :pokevial,       # hidden while the feature is off
  :home => false,                               # an action that starts on no page (not Main)
  :condition => proc { ... },                   # shown at all
  :usable => proc { true or "why not" },        # dimmed, and says why, when not
  :status => proc { ["3/5", :green] },          # :green, :gold, :red, :dim or nil
  :label => proc { "..." },                     # words of its own in place of its name
  :alert => proc { ... },                       # true: the row glows red, pulsing
  :description => "...",
  :handler => proc { |menu| ...; nil })         # nil: stay; :close; or a proc run once it's closed
```

A toggle has `:get` and `:set` (true or false: A flips its switch). A choice adds `:values` (`:get` and `:set` work its index) and `:explain => proc { |index| "..." }` for each choice's words in its dropdown. A number has `:range => [lowest, highest, step, unit]` (A opens its slider). A status's words can be `Reloaded::OverworldMenu::INFINITY` (the gold ∞ mark), and `:paint => proc { |bitmap, x1, y, height, colours, room| width }` draws a status its own way (Badges' pips).

A view of a feature's own joins Y's steps:

```ruby
Reloaded::OverworldMenu.register_view(:weather, :name => "Weather View", :feature => :weather,
  :draw => proc { |menu, base, top, colours| ... })
``` The handler gets the menu, which has `hidden { }` (step aside for another screen), `notice`, `confirm`, `choose` and `focus_quick_items`.

Errors in an entry are caught: the menu stays, says it didn't work, and the log has the details.
