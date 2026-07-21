# Kanto Reloaded Shared UI

Kanto Reloaded provides a shared UI foundation in `Core/UI` and keeps all KIF
class integration in `Core/Compatibility/KIFOptionsIntegration.rb`.

## Public APIs

- `KantoReloaded::PopupWindow.message(text, options = {})`
- `KantoReloaded::PopupWindow.confirm(text, options = {})`
- `KantoReloaded::PopupWindow.choice(title, commands, options = {})`
- `KantoReloaded::PopupWindow.carousel(title, entries, options = {})`
- `KantoReloaded::NumberPicker.open(title, min:, max:, initial:)`
- `KantoReloaded.number_picker(title, min:, max:, initial:)`
- `KantoReloaded::Toast.show(text, options = {})`
- `KantoReloaded::Toast.success(text, options = {})`
- `KantoReloaded::Toast.warning(text, options = {})`
- `KantoReloaded::Toast.error(text, options = {})`
- `KantoReloaded::Toast.custom(title, rows = [], options = {})`
- `KantoReloaded::HintText.draw_footer(bitmap, entries, x, y, width, options = {})`
- `KantoReloaded::HintText.open_popup(title, entries, options = {})`
- `KantoReloaded::SettingsUI.open`
- `KantoReloaded::SettingsUI.open_legacy`
- `KantoReloaded::SettingsUI.open_category(category_id)`
- `KantoReloaded::SettingsUI.open_module(module_id)`
- `KantoReloaded.open_settings`
- `KantoReloaded.open_module_settings(module_id)`
- `KantoReloaded.message(text, options = {})`
- `KantoReloaded.confirm(text, options = {})`
- `KantoReloaded.toast(text, options = {})`
- `KantoReloaded.toast_success(text, options = {})`
- `KantoReloaded.toast_warning(text, options = {})`
- `KantoReloaded.toast_error(text, options = {})`

The top-level message helpers use KR's shared popup and toast UI when it is
available, with guarded KIF message fallbacks for early boot or reduced UI
runtimes.

## Settings Rows

Register settings through `KantoReloaded::Settings`. The settings UI converts
toggle, enum, number, slider, text, button, and custom definitions into KR rows.
Definitions retain their existing storage, visibility, enabled-state, callback,
and validation behavior.

Action buttons are presented before value rows inside KR-owned category and
module scenes. Existing KIF scenes keep their original row order.

The main KR settings scene presents registered categories as collapsed headers.
Confirm or a mouse click expands a header in place. Direct category and module
scene APIs remain available for mods that need to open a focused settings page.
The root scene contains Interface, Gameplay, Quality of Life, Economy,
Developer / Utility, and About. Developer / Utility appears directly above
About and contains developer, maintenance, and file-management actions such as
Save Manager.
Legacy MSM-owned categories remain in the separate Mod Settings scene.

The Interface category includes `Global Small Text`. It defaults to On and
uses KIF's existing small system font through a guarded wrapper around
`pbSetSystemFont`; disabling it delegates to KIF's original implementation.

Interface includes `Menu Frame` and `Speech Follows Menu`. Menu Frame is
populated from `Graphics/Windowskins` inside the KR mod and applies globally
through guarded `MessageConfig` hooks. KIF's existing Speech Frame control
stays in its original location and continues using `$PokemonSystem.textskin`.
Speech Follows Menu defaults to On. While enabled, the existing Speech Frame
row displays `Uses Menu` and cannot override the KR frame; turning it Off
restores normal control of the selected speech frame.

## Existing KIF Option Scenes

The compatibility layer aliases `PokemonOption_Scene#initOptionsWindow` and
uses `Window_KROption` only for eligible settings scenes. The original window
factory remains the fallback. Existing option objects are not copied into the
KR save bucket and their getters, setters, actions, and descriptions are not
replaced.

KIF headings written as `### NAME ###` are adapted into collapsible headers by
the KR window. Global and Per-Save File start expanded; all other adapted KIF
headers start collapsed. KIF's Self-Battle & Import and Challenges pages are
also allowed to use their existing in-game option definitions when their normal
scene guard would otherwise return only `### EMPTY ###`.

The root options entries are added through the existing `pbAddOnOptions`
extension point. The previous implementation is always called first. Kanto
Reloaded is placed immediately below Multiplayer, followed by the KR-owned Mod
Settings entry. Any old MSM-provided Mod Settings entry is removed to avoid a
duplicate and to ensure the converted scene is used.

Scenes can opt out or opt in explicitly:

```ruby
def kr_options_style?
  false
end
```

Alternatively, register a class name at runtime:

```ruby
KantoReloaded::KIFOptionsIntegration.exclude_scene(MySpecialScene)
KantoReloaded::KIFOptionsIntegration.include_scene(MySettingsScene)
```

Fusion selection and fusion move selection are excluded by default because
they are gameplay workflows that only reuse KIF option classes.

If the old MSM mod is still active during migration, `ModSettingsScene`, its
preset scene, and its color scene are excluded from KR styling. They are not
opened by KR's Options entry; the exclusions only prevent accidental changes to
the transitional MSM implementation.

## Input Rules

Keyboard, controller, mouse, and touch-capable runtimes share one input router.
Mouse hover changes selection only while the pointer moves or a mouse action is
active. Hover selection does not scroll the list; mouse-wheel input performs
mouse scrolling. A stationary pointer does not take selection away from
keyboard or controller input.

Left and Right adjust value rows only. They do not activate action buttons or
collapsible headers; use Confirm or a mouse click for those rows. Slider tracks
use half of the available value-area width to keep numeric values compact.
Mouse-wheel direction follows the list: scrolling down advances downward and
scrolling up moves upward.

Popups own input while open and drain held Confirm, Back, and mouse inputs when
closing so input does not bleed into the underlying scene.

`PopupWindow.carousel` provides a compact centered item carousel for shared
module workflows. Entries can supply `label`, `value`, `item`, `selectable`,
`details`, and `action_label`; these fields may be callables for live state.
Left/Right and the mouse wheel rotate one entry at a time, Confirm selects,
Back cancels, and the optional `on_action` callback is triggered by Action or
right-click. Item entries use KIF's animated `ItemIconSprite` centered in the
popup.

`NumberPicker` provides a popup-styled non-negative integer editor. Each
numeric position is an individual `0`-`9` slot. Left/Right selects a slot,
Up/Down or the mouse wheel changes its digit, Confirm advances through the
slots and submits from `OK`, and Back or right-click cancels. Mouse hover only
changes the selected slot while the pointer is active. Values outside `min`
and `max` remain editable but cannot be submitted.

KR popups use the Hoenn Reloaded treatment: a centered compact dark panel, dim
screen overlay, small text, blue title, gray/white rows, no text shadow, and a
pulsing rounded cursor. Popup hover follows the shared last-active-input rule.
