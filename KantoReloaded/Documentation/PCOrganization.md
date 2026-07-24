# Reloaded PC

Reloaded PC provides a KR-owned Pokemon Storage interface, controls, and
storage-wide tools. When the module is Off, KIF's standard PC is left
unchanged.

The `Reloaded PC` action button appears in Kanto Reloaded's Quality of Life
category. Its module page contains the Reloaded PC Off/On toggle, which defaults
to On, followed by Animations, Speed, and Icons. Turning Reloaded PC On routes
Organise, Withdraw, and Deposit into the Reloaded interface. Turning it Off
calls KIF's original storage entry point without applying KR controls,
animations, speed, or presentation.

## Controls

The Reloaded interface always uses these controls:

- Input L switches to the previous box.
- Input R switches to the next box.
- Input X cycles between the box header, PC slots,
  and party. While carrying a Pokemon it cycles only between PC slots and party.
- Input Z opens the Reloaded PC menu from either the box or party panel.

Directional, Confirm, Back, and Input A retain their expected PC roles. Input A
cycles through Normal, Quick Swap, and Multi Select. Normal opens the Pokemon
action popup, Quick Swap picks up or places immediately, and Multi Select adds
individual Pokemon with Use. Using an already selected Pokemon opens the group
action popup. The normal Pokemon popup provides Move, Summary, Store or
Withdraw, Item, Mark, Nickname, Fusion, Kuray Actions, Release, and Debug when
Debug is active. Confirm and right-click use the same popup.

## Speed

`Speed` supports Off, 2x, and 3x. It applies only while the Reloaded interface
is open. The selected speed temporarily replaces the current global game speed
and suppresses KIF's normal Input X speed control, leaving Input X available
for focus cycling.

The player's previous game speed is restored when Pokemon Storage closes,
including when the Reloaded scene exits through an exception.

## Interface

The Reloaded PC toggle controls the interface directly. When On, Organise,
Withdraw, and Deposit use a KR-owned scene with a five-column scrolling box
tray, horizontally scrolling party dock, animated Pokemon detail panel, box
picker, and shared KR action popups. Deposit begins focused on the party;
Organise and Withdraw begin focused on the current box.

The header shows the previous and next box names around the current box name
and occupancy. Clicking either adjacent box changes to it. A Pokemon being
dragged over either adjacent-box header changes boxes after a short hover. The
box tray draws the current box's existing KIF wallpaper without covering it,
uses borderless slots, and displays enlarged Pokemon art. The current box name
and occupancy use the prominent shadowed center header. Switching boxes preserves the
current slot index and scrolls the destination box only as needed to keep that
slot visible. The detail panel centers the selected Pokemon's name and shows an
enlarged native-style animated sprite, gender icon, rounded type icons, and held
item.

The party dock displays six positions at a time. If another compatible mod
increases party capacity, Left and Right move through the full party and scroll
the dock without changing Kanto Reloaded's storage format or imposing its own
party-size limit.

The Reloaded interface supports mouse hover and wheel navigation. In Normal
mode, holding the left mouse button on a Pokemon picks it up visually; releasing
it over another PC or party slot moves it, or swaps both Pokemon when the
destination is occupied. Releasing outside a valid slot cancels the drag without
changing storage. In Quick Swap mode, pressing and releasing without dragging
picks up a Pokemon, and the next click places or swaps it, leaving the wheel
available between clicks. Holding and moving instead starts the same drag flow
used by Normal mode.
Right-clicking a hovered Pokemon opens its action list, while right-clicking the
box header opens the box picker. The wheel moves through PC slot rows while the
pointer is anywhere over the box panel, including while a Pokemon or selected
group is being carried. It scrolls an expanded party dock while the pointer is
over that dock.

In Multi Select mode, left-clicking Pokemon adds them individually. Clicking a
selected Pokemon opens the group action list, while dragging a selected Pokemon
moves the full selected group. Picked-up groups are ordered by their source
slots and displayed together in one centered row. Placing a group in a box
fills free slots from the chosen slot forward, skips occupied positions, crosses
row boundaries, and wraps to the start of the box when needed. The footer's
mode and PC Menu hints are also clickable without adding hover cursors to the
footer.

The active box, party slot, or box header uses KR's borderless rounded pulsing
cursor behind the Pokemon artwork and text. Selected Multi Select slots remain
visibly highlighted.

Choosing `Move` from an action popup uses the same held-Pokemon state as
Confirm placement. The held Pokemon follows the active mouse cursor, or the
selected slot while using keyboard or controller navigation. Carrying a Pokemon
leaves the box wallpaper visible. Pickup and placement use Reloaded PC's
grab/place motion while preserving its larger carried Pokemon artwork.

Choosing `Withdraw` while the party is full picks up the selected Pokemon and
moves focus to Party slot 1 so the player can choose a direct swap. Choosing
`Fusion` picks up the source Pokemon and enters fusion selection. Confirming or
clicking another unfused, non-Egg Pokemon opens KIF's existing fusion preview;
invalid targets buzz without dropping the held Pokemon. Back cancels fusion
selection while leaving the Pokemon held for normal placement.

Unfusion retains KIF's current mechanics but replaces its three staged
`Unfusing ...` messages with one animated KR progress popup using a rotating
Windows-style dot spinner. Missing splicers and DNA Reversers are reported
before their native fusion actions begin. Reverse fusion
still requires a DNA Reverser or Infinite Reversers. Reverse fusion calls KIF's
native reversal flow. If EBDX is active, KR temporarily disables its evolution
scene for that call because EBDX does not implement reversal, then restores
EBDX in an ensure block.

Reloaded works directly with KIF's existing party and storage objects and does
not create a second storage save format.

## Icons

`Icons` supports Icons and Full Sprites and defaults to Full Sprites. It changes
the Pokemon art in both the box tray and party dock. Both modes are centered
and scaled into the same fixed slot dimensions. Visible-art bounds are cached,
and naturally small artwork receives a bounded 20% enlargement without
changing the slot layout. Held Pokemon use a separate 168% scale so they remain
clear while following the cursor. Full sprites do not resize or shift the
interface. The preference is stored globally.

## Animations

`Animations` supports Off, Reduced, and Full and defaults to Full. It applies
only to Reloaded PC's horizontal box transitions, eased extended-party
scrolling, pickup and drop movement, and selected Pokemon mosaic animation.
Reduced uses shorter transitions and Off applies every state change
immediately.

## Reloaded PC Menu

Input Z opens storage-wide tools rather than duplicating the Pokemon context
menu:

- `Find Pokemon` searches names and species and can filter by type, level,
  Shiny, Egg, fusion status, held item, Ability, Move, OT, marking, and location.
  Selecting a result jumps to its box and slot on the Reloaded interface.
- `Sort & Organize` sorts the current box, each unlocked box independently,
  all unlocked boxes as one pool, or the current Multi Select selection.
  Native sort fields are retained alongside BST, individual base stats, hatch
  progress, fusion status, and form. Eggs remain at the bottom without using
  their hidden species as a sort key. Equal values retain their prior order.
- `Box Management` chooses, summarizes, renames, and changes wallpapers for
  boxes and provides KIF's box purchase and sorting/export lock controls.
- `Selection Tools` appears in Multi Select mode and provides visible/all/invert
  selection, clearing, moving, sorting, releasing, and exporting.
- `KIF Tools` contains KIF's guarded import/export commands.

Compaction fills empty gaps without otherwise changing Pokemon order. Sorting
and compaction never modify the party, and all-storage operations skip boxes
whose native sorting lock is enabled.

`KantoReloaded::PCOrganization.register_menu_command` registers additional
Input Z rows with a label, priority, optional availability callback, and
handler.

```ruby
KantoReloaded::PCOrganization.register_menu_command(
  :search, :label => _INTL("Search"), :priority => 10
) do |storage_scene|
  # Open the tool over the active Reloaded storage scene.
end
```

`unregister_menu_command` removes a registered row. Command handlers receive
the active Reloaded storage scene and run only when the toggle is On. The scene
provides access to KIF's original storage object.

Contextual extensions use the corresponding action registries. Their handlers
receive the active storage scene, the selected Pokemon when applicable, and the
selected locations for multi actions.

```ruby
KantoReloaded::PCOrganization.register_pokemon_action(
  :inspect_custom_data,
  :label => _INTL("Inspect Custom Data"),
  :priority => 200
) do |storage_scene, pokemon, _locations|
  # Read or update the selected Pokemon without replacing the PC menu.
end
```

Equivalent `register_box_action` and `register_multi_action` methods are
available, along with matching `unregister_*` methods.

## Compatibility

Reloaded PC uses one guarded wrapper around
`PokemonStorageScreen#pbStartScreen`. When the toggle is On, Organise, Withdraw,
and Deposit are routed into the KR scene. When the toggle is Off, or a command
is unsupported, the wrapper preserves the original arguments, block, return
value, and visibility and immediately calls KIF's original method.

No `PokemonStorageScene` method or Input constant is wrapped or replaced.
Speed-toggle availability and the pre-PC game speed are restored in ensure
blocks around the KR scene. No global per-frame Graphics or Input wrapper is
installed. No native icon cache, hard-refresh path, transition method,
type-sheet hook, or sprite positioning is changed. The module does not save
duplicate box or party data.

KR-owned action adapters use KIF's existing storage, fusion, Debug, Kuray, and
import/export behavior while replacing their command-list
presentation where the native API permits. Summary, text entry, Bag item
selection, fusion preview/animation, Debug-specific scenes, and file navigation
remain their native full-screen systems. The adapter routes KIF's Kuray shiny
color values through KR's shared number picker and refreshes changed Pokemon
art immediately after the native action returns.

The internal `KantoReloaded::PCOrganization` namespace and existing
`pc_organization` setting keys are retained for save and API compatibility.
