# Healing Overworld Moves

`Modules/HealingOverworld.rb` is a standalone Kanto Reloaded module. It is not
part of the retired Quality Assurance port.

## Setting

- Key: `healing_overworld_moves`
- Name: `Healing Overworld Moves`
- Category: `Quality of Life`
- Default: On
- Placement: final setting in the category, immediately above Reset Category
- Overworld Menu: optional toggle available to the page editor and disabled on
  pages by default

## Integration

The module does not replace `PokemonPartyScreen` and does not add or replace
entries in KIF's `HiddenMoveHandlers` registries. It uses KR's guarded hook API
around these singleton methods:

- `HiddenMoveHandlers.hasHandler`
- `HiddenMoveHandlers.triggerCanUseMove`
- `HiddenMoveHandlers.triggerUseMove`

When the setting is disabled, all three wrappers delegate unchanged. Unrelated
field moves always delegate unchanged.

KIF already implements Milk Drink and Soft-Boiled directly in its party menu.
The module leaves those moves under native ownership.

KIF also owns Morning Sun and Moonlight as outdoor time-changing field moves.
When healing and the native action are both available, KR's shared popup asks
the player to choose Heal, Wait Until Morning/Night, or Cancel. When only one
action is available, it runs directly.

## Behavior

The module supports targeted healing, self healing, party healing, party status
recovery, Revival Blessing, Healing Wish, Lunar Dance, Pollen Puff, Present,
Purify, Dream Eater, Aqua Ring, Refresh, and Rest.

PP is consumed once and only after a valid effect is selected. Targeted moves
use KIF's existing party picker without changing its command construction.
Party status recovery includes full-HP Pokemon, Big Root applies a 30 percent
recovery increase where supported, and Dream Eater cannot knock out its allied
target.

The module performs no map-frame polling and stores no custom runtime state
beyond its KR setting value.
