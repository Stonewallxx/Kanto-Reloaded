# Battle Menu

The Kanto Reloaded Battle Menu is implemented in:

```text
Mods/KantoReloaded/Modules/BattleMenu.rb
```

It is a centered OWM-style command overlay available while the player is
choosing the main Fight, Bag, Pokemon, or Run command. It does not replace
KIF's vanilla or EBDX battle command loops.

## Settings

The `Interface` category contains:

- `Battle Menu`: enables or disables the overlay. KR key: `:battle_menu`.
- `Customize Battle Menu`: opens the per-save page editor.

`Battle Menu` defaults to On for new saves. The old MSM
`:battle_command_menu` On value is retained. MSM's old default-Off value is
treated as a retired default so it does not disable KR's menu; saves affected
by the first migration are corrected once and may then be switched Off normally.

## Controls

- `Action`: open the Battle Menu from the main battle command.
- `Up/Down`: change the highlighted command.
- `Left/Right`: change pages.
- `Confirm`: execute the highlighted command.
- `Action` while open: execute the available Favorite command.
- `Back`: close the Battle Menu.

Action is intercepted only while the player is choosing a main battle command.
Fight-menu and other battle-submenu controls are not changed.

## Pages And Favorite

Pages, selected page, hidden commands, ordering, and the Favorite command are
stored per save through `KantoReloaded::SaveData`.

The page editor supports showing, hiding, reordering, renaming, adding,
removing, and resetting pages. `Set as Favorite` and `Clear Favorite` are in
the selected command's Page Options. The Favorite can execute from any page.
If its condition is unavailable, Action plays the buzzer and keeps the menu
open.

## Registering Commands

New integrations should use a stable ID:

```ruby
KantoReloaded::BattleMenu.register(:pokemon_stats,
  :label => "Pokemon Stats",
  :description => "View damage dealt and stat stages.",
  :priority => 50,
  :condition => proc { |battle, idx_battler| true },
  :handler => proc { |battle, idx_battler, scene|
    scene.pbShowTrainerMemo(idx_battler)
    nil
  }
)
```

Fields:

- `key`: stable Symbol-like command ID.
- `label`: displayed command name.
- `description`: text in the description panel.
- `handler`: callable receiving battle, battler index, and battle scene.
- `condition`: optional callable receiving battle and battler index.
- `priority`: lower values sort first before page customization.
- `status`: optional text or callable shown at the right of the row.
- `status_color`: optional Color or callable.

Return `:keep_open` to redraw the Battle Menu after the handler. Other normal
results close it and return to KIF's command selection. The compatibility
result `:quick_throw_used` is preserved for old Quick Throw integrations, but
KR does not use the old Quick Throw battle-loop overrides.

A command may return `:fight`, `:bag`, `:party`, `:run`, `:call`, or `:debug`
to hand control to that native KIF command. KR Quick Throw queues its selected
ball, returns `:bag`, and narrowly handles the resulting Bag request without
replacing the command phase.

## Quick Throw

`Modules/QualityAssurance/QuickThrow.rb` registers `Quick Throw` and
`Select Quick Throw Ball`. There is no enable toggle or separate shortcut.
Players can make `Quick Throw` their Favorite and press Action once to open the
Battle Menu and again to throw.

The selector is a KR PopupWindow carousel with a centered ball sprite, owned
quantity, per-save allow/block status, and an estimated capture percentage.
Left/Right or the mouse wheel rotates balls. Action or right-click changes the
highlighted ball's blacklist status; Confirm selects an allowed ball. Master
Ball starts blocked. The blacklist applies only to Quick Throw and does not
prevent normal Bag use.

Normal Bag throws update the remembered ball unless that ball is blocked.
Quick Throw uses KIF's native item registration, consumption, all-actions rule,
target selection, capture handlers, and animation. Its scoped target-validation
hook allows the explicitly selected opponent in multi-Pokemon battles without
changing normal Bag restrictions.

The catch estimator uses KIF's current `BallHandlers.modifyCatchRate` and
`BallHandlers.isUnconditional?`, then mirrors the base HP, status, shake, and
critical-capture probability. It is labeled estimated because another mod may
replace the complete capture calculation. Multi-target battles show the range
across valid opponents.

## Legacy Compatibility

The global `BattleCommandMenu` points to the KR-owned registry and preserves:

```ruby
BattleCommandMenu.register(...)
BattleCommandMenu.register_command(name, handler, description, condition, priority)
BattleCommandMenu.get_available_commands(battle, idx_battler)
```

Existing registry entries are adopted when KR loads. Registrations queued in
`$BATTLE_COMMAND_MENU_PENDING_REGISTRATIONS` are also processed. A guarded
`pbOpenBattleCommandMenu` scene bridge remains available for older consumers.

## Integration Boundary

KR uses guarded `KantoReloaded::Hooks` wrappers around the final vanilla and
EBDX command/update methods. While KR owns input, it suspends only the active
native command window. Cancelling KR restores that window; returning a native
command leaves it hidden and hands the result back to the existing command
loop. KR does not hook battle shutdown or manage EBDX fight, bag, target, type,
or disposal sprites. It does not edit base scripts, Multiplayer, Mod Manager,
MSM, or the retired Quick Throw implementation.
