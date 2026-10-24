# Reloaded Bag

A new Bag with real pocket sorting, Search, NEW, Favorites, views and who in your party can use each TM. This is Roadmap topic bag: old Kanto Reloaded's Autosort Bag (real pocket order, Custom Lists) with Hoenn Reloaded's screen ideas, rebuilt in Reloaded's look. The code is in `Core/Bag/Bag.rb` (the order, NEW, Favorites, views, Export and Import, the hooks), `Core/Bag/DefaultLists.rb` (old Kanto Reloaded's lists, cleaned for KIF), `Core/UI/BagLook.rb` (what the Bag's screens draw with), `Core/UI/BagScene.rb` (the Bag) and `Core/UI/BagListScreen.rb` (the Custom List editor).

**Reloaded Bag** in Kanto Reloaded > Features switches it, On to start. Off gives the game's own Bag back.

## Where It Shows

Kanto Reloaded's scene takes the place of the game's (`PokemonBag_Scene.new` hands it out), and the game's own `PokemonBagScreen` still makes each item's actions and does what's picked. So every place the game opens its Bag shows it:

- **The Pause Menu's Bag:** the full Bag.
- **Every picker:** Give an Item (the party menu, the Summary), Use an Item, a Berry for soft soil (or a Mulch), an Apricorn, a Fossil, a Quick Items slot (the Overworld Menu), PC Deposit, the battle Bag, and any event or mod's `pbChooseItemScreen`.
- **Not the Mart's Sell:** it keeps the game's Bag until the Shop has its own screen.

Other mods' item actions still show (they come from the game's list).

## The Bag

- **The header:** Search on the left (L, or click it: type straight into it; a controller's A opens the naming screen) and Sort on the right (R: the next view). Back clears a search.
- **The pockets:** the eight pockets' icons, the open one lit, a green dot on a pocket with something NEW, its name. Left and Right skip pockets with nothing in them.
- **The list:** each name in its pocket's colour (Spectrum, Vivid; a TM in its move's type), Favorites starred and first, NEW, how many, the item's picture (a TM: its number and type). A Search shows every pocket's matches under their pockets' headings: a word starting with what's typed ("ice" finds Never-Melt Ice and Ice Beam; "tm24" finds TM24).
- **The details**, lit in the item's colour: its name, what it's good for (USE, IN BATTLE, HOLD, KEY ITEM, QUICK SLOT n), its description and picture. A TM or HM, or an Evolution Stone: who in the party can use it (Learned, Able, Not Able; a stone: Can Evolve, Can't; Egg).
- **Who Needs It:** a healing item's details show the party the same way: each Pokémon's icon, its HP and what the item would do (Can Heal, Full HP, Fainted, Can Revive, Not Fainted, Can Cure, Can't Cure, Healthy, Can Restore, Full PP). Potions and drinks, Full Restore, Revives, status heals (and the Berries that do the same), Ethers and Elixirs.
- **Held Items:** an item someone in your party is holding gets a HELD pill on its row and in its details, and the details say who (Held by: Pikachu).
- **Views** (R): Bag Order, A-Z, Quantity, Type, Number, Recent, kept for each pocket. Only the screen's order: the real pocket doesn't change.
- **Your headings:** in a Custom List pocket's Bag Order, the list's headings show in small capitals with a line, as in the editor: Favorites first under their own heading, then each of your headings in your list's order, then Not on Your List. A heading with nothing of yours under it doesn't show.

## An Item's Actions

A opens Kanto Reloaded's menu, each action explained under it:

- The game's own first, in its order: Read, Use (or the item's own word), Give, Toss, Register or Deselect (the game's Ready Menu), Debug, and other mods' actions. KIF's Sort Bag is left out (Auto-Sort and the views replace it). On a TM or HM with the TM Vault on, **Teach** is in Use's place: it opens the TM Vault on that move.
- Then **Favorite** (or Remove Favorite), **Add to Quick Items** (or Remove From Quick Items: the Overworld Menu's seven slots), and **Move** where the pocket allows it.

**Toss:** how many, with the item's picture and how many stay; then a question with Keep chosen first (a quick A twice throws nothing away); then a toast ("Tossed 2 Repels", 2 LEFT).

**Add to Quick Items** puts it in the first empty slot (a toast says which). Only when all seven are full does a row of the slots ask which one to replace.

**Move** (a pocket whose Auto-Sort is Off or Custom List): a gold edge and MOVING. Up and Down carry it, A puts it down, B puts it back. In a Custom List pocket the list follows.

**Use Several at Once:** a Rare Candy, a vitamin (HP Up, Protein, Iron, Calcium, Zinc, Carbos), a Wing, an EV-lowering Berry or an HP item (Potion, Super, Hyper and Max Potion, Fresh Water, Soda Pop, Lemonade, Moomoo Milk, Energy Powder and Root, Berry Juice, Sweet Heart, Oran and Sitrus Berry) used on a Pokémon (from the Bag or the party menu) asks Use How Many?: the item's picture and the Pokémon's, the number (Left and Right one, Up and Down ten), what it makes (Lv. 34 to 39, Attack EVs: 40 to 90, HP: 20 to 80) and the most that still helps (the level cap, the EV room, the friendship left, what fills the HP). Then a notice says what changed. Rare Candies level up once to the new level, with the game's own window, its moves and its evolution. When only one would help, the game's own use runs as before. Needs Kanto Reloaded's Party Screen.

Y (X on a keyboard) stars a Favorite straight from the list.

## Pickers

The same screen. A banner over the list says what's being chosen ("GIVE AN ITEM TO PIKACHU", "PLANT A BERRY"), only what fits shows (pockets with none are faint and skipped), and A says what it does (Give, Plant, Use, Deposit, Pick). Nothing saved changes in a picker: no Favorites, no moving, and NEW stays NEW.

## Sorting

Each pocket keeps a real order (the game, the battle Bag and other mods all see the same pocket), set in **Kanto Reloaded > Bag - Auto-Sort**, each save its own:

- **Off:** as you put things in; moving by hand stays.
- **Custom List:** your list's order, anything not on it after, A to Z. The start for most pockets.
- **A-Z:** by name.
- **Number:** by the game's item number (TMs by their number). The start for TMs & HMs and Berries, as the game has them.

A new kind of item is placed as it comes. **New Items** (Kanto Reloaded > Bag) shows one In Place, First or Last in its pocket until you've seen it.

## Custom Lists

Each pocket's list starts as old Kanto Reloaded's (`DefaultLists.rb`: 721 items, cleaned for KIF Beta). **Starting Lists** (Kanto Reloaded > Bag) picks Plain, or With Sections: the same items under headings (Medicine's Candy, Healing, Drinks and Food, Revival, Status, Herbal, PP, Vitamins and Wings; Berries' Healing, Status, Type Resist, EV Lowering, In a Pinch and Other; and so on). A pocket you haven't edited follows it; the editor's Defaults brings the chosen one back. **Edit Custom Lists** opens the editor, a full screen like the Bag:

- Search (L) and Defaults (R: the pocket's list as it started, after asking with what changes, "5 items, 2 headings become 54 items", Keep Mine first).
- The pockets (Left and Right).
- The list: your headings, and the items, those in your Bag in the pocket's colour with how many, the rest dim.
- The details: IN THE BAG or not, and where the pocket shows it ("After Potion, before Hyper Potion").
- A opens an entry's actions: Move, Remove From List, Add a Heading Above (typed straight in), and for a heading Rename Heading and Remove Heading. X (Action) moves it; Y adds one of the pocket's items not on the list, after the highlighted one: a list to search (Y, L or a click types into its field; those you have first, in the pocket's colour) that says where it goes.

Every change is the save's list straight away, and a Custom List pocket sorts again. Headings sort nothing; they mark parts of the list.

## Export and Import

**Export Lists** writes every pocket's list, Favorites and Auto-Sort to `Exports\Bag Lists.txt` in the Kanto Reloaded folder. One item ID per line; `*` before one marks a Favorite; `-- Name --` is a heading; anything after `#` or `//` is a note. When it's done, a popup says where it went and what's in it, with Open Folder (a phone copies the path). **Import Lists** reads it back, asking first with what the file holds and when it was exported (Keep Mine chosen first), or old Kanto Reloaded's `AutosortBag_lists.txt` in Kanto Reloaded Legacy's Exports folder. What isn't an item, or isn't that pocket's, is left out.

## PIF's Bag, Fixed

With the Reloaded Bag on or off (`Core/Fixes/BagFixes.rb`):

- **Sort Bag turning round:** PIF kept one "backwards" flag for every pocket and kind of sort, so a sort ran backwards whenever the last one anywhere ran forwards. Now only sorting the same pocket the same way again turns it round, and the pocket is sorted in place.
- **Pinkan Island:** taking any item out of the Bag (a Toss, a Potion) played a sound and redrew the Pinkan Berries; now only Pinkan Berries do.
- **pbChangeQuantity:** it asked the Bag for `numPockets`, which only the class has; any call would have crashed.

## Kanto Reloaded Legacy

The first time a save with Kanto Reloaded Legacy's Bag lists loads, its lists (separators become headings), Favorites and Auto-Sort modes come in, once.

## For Other Mods

```ruby
Reloaded::Bag.mode(2)                 # 0 Off, 1 Custom List, 2 A-Z, 3 Number
Reloaded::Bag.custom_list(2)          # item id strings and "#Name" headings
Reloaded::Bag.rows(2)                 # the pocket's item ids as the screen shows them
Reloaded::Bag.new?(:POTION)
Reloaded::Bag.favorite?(:POTION)
Reloaded::BagScreen.during(:@title, ["Feed a Berry", "Feed"]) { ...open the game's Bag picker... }
```

The save keeps the lists, Favorites, views, what's been seen and when each came (SaveStore section `bag`); nothing is kept on `$PokemonBag` itself (KIF's Self-Battle copies it).

## Tests

```text
ruby Tools/Tests/bag_test.rb "<KIF Beta>" <empty temp folder>
ruby Tools/Tests/bag_preview.rb "<KIF Beta>" <work dir with metrics.json>
python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>
```

The first runs on the game's own Bag with stand-ins for its items: each pocket's Auto-Sort, sorting in place, NEW, New Items, Favorites, the views, moving by hand, headings, Defaults, Export and Import (old Kanto Reloaded's file too), Kanto Reloaded Legacy's lists and modes, the Bag pages, and Off.

The second drives the screens through the game's own `PokemonBagScreen`: the full Bag, the views, a Favorite, empty pockets skipped, TMs and a stone's party check, the actions, Teach, Move, Toss, Quick Items (all seven full too), Search, pickers and their banners, the mouse, Light, the Bag pages in KIF Settings (Export, Import, the Auto-Sort dropdown), the Custom List editor, and Off.

The mockups are in `Tools/Designs/bag`.
