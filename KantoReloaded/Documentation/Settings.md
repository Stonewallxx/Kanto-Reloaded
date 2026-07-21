# Kanto Reloaded Settings

`KantoReloaded::Settings` is the persistent registry behind the future KR
settings menu. It does not render a menu and does not depend on Mod Settings
Menu. Setting definitions and callbacks remain runtime-only. Values use
per-save storage by default, while definitions marked `:scope => :global` are
written immediately to KR's global settings file and apply across all saves.

## Register a Setting

```ruby
KantoReloaded::Settings.register(:battle_style, {
  :name => "Battle Style",
  :description => "Select the preferred battle rules.",
  :type => :enum,
  :values => ["Standard", "Fast"],
  :default => 0,
  :scope => :save,
  :category => :gameplay,
  :owner => :example_mod
})
```

Supported types are `:toggle`, `:enum`, `:number`, `:slider`, `:text`,
`:button`, and `:custom`.

Supported scopes are `:save` and `:global`. The default is `:save`, which
stores values inside `SaveData.system(:settings)`. Global values are stored
outside individual save slots and persist as soon as they change. Existing
per-save values are copied to global storage the first time a global setting is
loaded, but never overwrite a global value that already exists.

All current Interface value options use global scope. Battle Menu page layout
and Favorite command customization remain per-save module data and are not
part of the settings registry.

Buttons normally appear before value rows. A button that belongs directly
after a particular setting can declare
`:metadata => { "after" => "setting_key" }`; the settings UI anchors it after
that row while leaving other button ordering unchanged.

```ruby
value = KantoReloaded::Settings.get(:battle_style)
KantoReloaded::Settings.set(:battle_style, 1)
KantoReloaded::Settings.reset(:battle_style)
```

## Categories

```ruby
KantoReloaded::Settings.register_category(:gameplay, {
  :name => "Gameplay",
  :description => "Gameplay behavior and convenience settings.",
  :priority => 100,
  :owner => :example_mod
})
```

The future KR UI reads `Settings.categories` and `Settings.definitions` to
build its screens. `Settings.visible?` and `Settings.enabled?` evaluate optional
`:visible_if` and `:enabled_if` conditions supplied by a registration.

## Module Settings

Module helpers namespace saved keys as `module_id.setting_id`.

```ruby
KantoReloaded::Settings.register(:miscmods_infinite_repel, {
  :name => "Infinite Repel",
  :type => :toggle,
  :default => 0,
  :category => :quality_of_life,
  :owner => :quality_assurance
})

KantoReloaded::Settings.get(:miscmods_infinite_repel)
KantoReloaded::Settings.set(:miscmods_infinite_repel, 1)
```

The built-in Quality Assurance module uses this legacy-compatible key so an
existing Infinite Repel value migrates without creating a duplicate setting.

## Change Callbacks

```ruby
KantoReloaded::Settings.register_on_change(
  :battle_style,
  :example_mod_apply,
  :owner => :example_mod,
  :invoke => true
) do |value, old_value|
  # Apply the setting without replacing a base method.
end
```

Callbacks are reapplied after a KR save bucket loads and when a new game bucket
is created. A failing callback is logged without stopping other callbacks.

## Legacy Import

`import_values` and `export_values` provide the value boundary needed by the
future MSM compatibility layer. The compatibility layer itself is not part of
this registry and will be implemented separately.
