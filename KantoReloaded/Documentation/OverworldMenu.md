# Overworld Menu Documentation

The Kanto Reloaded Overworld Menu is implemented in:

```text
Mods/KantoReloaded/Modules/OverworldMenu.rb
```

It opens a compact quick-access overlay from the overworld using the same
reference UI layout: a top-right command list and an optional left-side party
panel.

## Options

The module registers one option under Kanto Reloaded's `Interface` category:

```text
Overworld Menu: Off / On
```

`Overworld Menu` controls whether the overworld trigger opens the overlay. Its
KR setting key is `:overworld_menu` and defaults to On for new saves.

The in-menu `Overworld Menu Features` entry controls whether the party panel is
visible when the menu opens.

## Pages and Ordering

`Overworld Menu Features` includes `Customize Pages`.

The page editor stores its layout per save through `KantoReloaded::SaveData`.

Controls:

- `Confirm (C)`: show or hide the selected entry on the current page.
- `Back (B)`: save and return to the Overworld Menu.
- `Action (A)`: pick up and reorder a visible entry.
- `Special (Z)`: open page actions for rename page, add page, remove page, or reset page.
- `Others`: Left/Right changes pages.

The first page starts as `Main`. All Overworld Menu entries are visible by
default in the customizer. Hiding an entry removes it from the live menu.
`Overworld Menu Features` is locked on and cannot be hidden.

Added pages show only entries enabled for that page.

Page names only change when the player uses `Rename Page`. Removing pages does
not automatically rename or renumber the remaining pages.

When the Overworld Menu has multiple visible pages, Left/Right changes pages
while the menu is open. The selected page is saved per save file.

## Quick Items

`Quick Items` opens one Overworld Menu entry that can use up to five selected
items.

The Quick Items popup shows usable selected items and a `Manage Slots` command.
Slot setup uses the normal Bag picker, filtered to items with usable field,
party, machine, or bag handlers. Quick Item slots are saved per save file.
PokeVial Charge and PokeVial Refill are eligible when those items are in the
Bag.

Common field actions such as Bike, Town Map, Repel, Fishing Rod, Escape Rope,
and Honey should be managed by the player through Quick Item slots instead of
separate Overworld Menu entries.

## Built-In Entries

The built-in entries match the reference menu:

- `Quick Items`
- `Quick Save`
- `Repel Counter` when a repel is active
- `Time Changer`
- `Overworld Menu Features`

## Registering Entries

`KantoReloaded::OverworldMenu` is the KR-owned API. The global
`OverworldMenu` constant points to the same registry so older mods continue to
work unchanged. Mods can add entries with either constant:

```ruby
OverworldMenu.register(:my_feature,
  label: "My Feature",
  priority: 50,
  condition: proc { true },
  status: proc { "READY" },
  status_color: proc { Color.new(120, 230, 150) },
  default_enabled: false,
  exit_on_select: false,
  handler: proc { |screen|
    screen.show_popup("MY FEATURE", ["Hello from my feature."])
    nil
  }
)
```

Registration fields:

- `key`: unique Symbol-like ID.
- `label`: text shown in the command list.
- `handler`: callable object. Receives the `OverworldMenuScreen`.
- `priority`: lower values appear earlier.
- `condition`: optional visibility gate.
- `status`: optional right-side status text.
- `status_color`: optional right-side status text color.
- `default_enabled`: whether a newly registered entry starts enabled in the
  page editor. Defaults to `true`; a saved user choice always takes priority.
- `exit_on_select`: closes the menu after the handler when true.

Handlers can return `:exit_menu` to close the menu after custom logic.

New registered entries are automatically added to the Main page customizer and
can be reordered or hidden per save.

The legacy options-hash form remains supported for existing KIF mods:

```ruby
OverworldMenu.register(:my_feature, {
  :label => "My Feature",
  :handler => proc { |screen| screen.show_popup("MY FEATURE", ["Ready."]) },
  :priority => 50
})
```

When KR loads after an older Overworld Menu implementation, it adopts entries
already present in that registry. It also consumes registrations queued in
`$OVERWORLD_MENU_PENDING_REGISTRATIONS` or
`$overworld_menu_pending_registrations`. Duplicate keys are retained only once.

Existing HR-style `@hr_om_enabled` and `@hr_om_party_view` values on
`$PokemonSystem` are imported once without adding methods to `PokemonSystem`.
All subsequent state is owned by the KR save bucket.

The temporary KR key `:overworld_menu_enabled` and MSM's `:overworld_menu`
value are converted once into the KR-owned `:overworld_menu` setting.

Mods that conditionally register only when `OverworldMenu` is defined should
load after Kanto Reloaded. New integrations should declare KR as a dependency
and call `KantoReloaded::OverworldMenu.register` directly.

## Trigger

The reference trigger is preserved through `Input::AUX2` when available. If that
constant is unavailable, the module falls back to `Input::F5`, then
`Input::SPECIAL`.

The module uses the existing `Events.onMapUpdate` hook and does not edit or
replace KIF's `Scene_Map` or `PokemonPauseMenu` methods.
