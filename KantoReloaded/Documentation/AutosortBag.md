# Autosort Bag

Autosort Bag is a Kanto Reloaded module that adds save-backed, per-pocket Bag
ordering without replacing KIF's item storage implementation.

## Settings

Open `Options > Kanto Reloaded > Quality of Life > Autosort Bag`.

- **Per-Pocket Sorting** selects one policy for each Bag pocket.
- **Sorting Lists** opens the custom list, separator, and favorite editor.
- **Export Configuration** writes settings, policies, lists, and favorites to
  `Exports/AutosortBag_lists.txt`.
- **Import Configuration** first reads that text file from `Exports`. If it is
  absent, KR also checks the KantoReloaded folder and the legacy Mods folder.
- **Sort All Pockets Now** immediately applies every active pocket policy.
- **Autosort New Items** controls automatic post-receipt sorting.
- **Always Move Recent** independently moves every received item to the first
  or last pocket slot after sorting.
- **Manual Sort Button** allows the Special input to sort the active pocket in
  the normal Bag scene.

The available policies are:

- **Off** leaves KIF's native pocket behavior unchanged.
- **Custom List** orders favorites first, then listed items, then unlisted
  items alphabetically.
- **Alphabetical** orders favorites first and all other items by name.

Always Move Recent has `Off`, `First`, and `Last` choices. `First` and `Last`
are absolute positions applied after the pocket policy, including for items
that already had a stack in the Bag. The temporary placement remains through
the first normal Bag session where that pocket is viewed. The pocket returns
to its normal policy order the next time it is viewed after reopening the Bag.
Item-selection Bag scenes do not consume the temporary placement.

TMs/HMs and Berries default to Off because KIF already sorts those pockets by
item ID. Other pockets default to Custom List.

## Editor Controls

- Confirm opens actions for the selected item or separator.
- Back exits the editor.
- Action toggles Favorite for the selected item.
- Special opens list-wide actions such as Add Item and Restore Defaults.
- X immediately enters row-move mode and places the row when pressed again.
- Left/Right changes pockets.
- Move mode uses repeatable Up/Down movement and Left/Right five-row jumps.
- The mouse wheel scrolls the list; mouse hover only changes selection while
  the mouse is actively moving or clicking.

If hold-to-speed is active when the editor opens, the editor preserves that
speed while X is released. The next X press can therefore start row movement;
the original speed mode is restored when the editor closes.

All editor data is stored in the Kanto Reloaded per-save bucket. Runtime
separators are ignored by sorting; they only organize the editor.

## Item Picker Controls

- Confirm selects the highlighted item.
- Back returns without adding an item.
- Action opens text search across item names and IDs.
- Special clears the current search.
- Up/Down moves one item; Left/Right jumps five items.
- Mouse wheel and active mouse hover/click are supported.

## Hooks

The module uses `KantoReloaded::Hooks.wrap` for three narrow extensions:

1. `PokemonBag#pbStoreItem` runs KIF's original method first, preserves its
   arguments, block, return value, and visibility, then applies the selected
   pocket policy after a successful store.
2. `PokemonBag_Scene#pbStartScene` marks only the normal Bag scene as eligible
   for manual sorting and starts its recent-item viewing session.
3. `Window_PokemonBag#update` observes pocket changes after the native update,
   restores previously viewed recent placements when appropriate, and handles
   the Special manual-sort input.

No KIF base script, Mod Manager script, or Multiplayer script is edited.

## Migration

On the first loaded or new save, KR imports recognized legacy Mod Settings Menu
values when available. It also performs a one-time, size-limited import of the
old `AutosortBag_list.kro` and `AutosortBag_favorites.kro` files from the Mods
folder. Imported data is normalized into the KR save bucket; the legacy files
are never modified.

Stored Recent First or Recent Last pocket modes migrate to the global Always
Move Recent setting, and those pockets switch to Off so the previous
recent-placement behavior is preserved.

The text import format is intentionally non-executable:

```text
[Settings]
Autosort New Items = On
Always Move Recent = First
Manual Sort Button = On
Items = Custom List

[Items]
* POTION
-- HEALING --
REPEL
```

`*` marks a favorite and `-- NAME --` creates an editor separator. Invalid
settings, items, and items assigned to the wrong pocket are ignored. Older
list-only exports remain importable, including their documented hyphen, star,
and numbered list prefixes. A legacy star prefix is treated as a bullet because
that export format stored favorites separately.
