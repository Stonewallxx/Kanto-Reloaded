# MSM Compatibility and Migration

`KantoReloaded::MSMCompatibility` lets older mods continue calling the common
`ModSettingsMenu` APIs without making the old Mod Settings Menu a KR dependency.
It does not edit the MSM mod.

Supported compatibility calls include:

- `register`, `register_toggle`, `register_enum`, `register_number`, and
  `register_slider`
- `register_option` and `register_pending`
- `get`, `set`, `storage`, and `set_storage`
- `register_on_change`
- `registry`, `categories`, and category collapse helpers
- `$MOD_SETTINGS_PENDING_REGISTRATIONS`

When the managed MSM mod is enabled, KR waits for it to load, mirrors its
registrations into `KantoReloaded::Settings`, and wraps value-changing methods
with guarded aliases. When MSM is absent, KR installs a lightweight facade using
the same `ModSettingsMenu` constant and drains pending registrations itself.

The target setup does not require `Mods/ModSettingsMenu` to be active or
installed. KR owns the visible Mod Settings action and scene. Registrations
made through the compatibility facade are converted into KR definitions with
the `legacy_msm` owner and rendered with the shared KR options system.

Legacy categories such as Ghost Settings appear only in the converted Mod
Settings scene. They are intentionally excluded from Kanto Reloaded's own
Interface, Quality of Life, and About scene. The old `Mod Settings Colors`
chooser is not converted because the KR theme is always active in the new scene.
The obsolete `quality_assurance` submenu registration is also ignored because
its individual features now register directly in KR's Quality of Life category.

An enabled MSM installation is supported only as a transition state. KR removes
MSM's old Options entry at runtime, supplies its own entry, and mirrors active
registrations until MSM is disabled or removed. No MSM source file is edited.

## One-Time Value Import

After a KR save bucket loads or a new game begins, KR checks these legacy
locations:

1. `Mod_Settings.kro`, when KIF's legacy JSON loader is available.
2. Active `ModSettingsMenu.storage`.
3. `$PokemonSystem`'s existing `@mod_settings` data.

Later sources take precedence over earlier sources, but existing KR values are
never overwritten by the one-time import. KR records completion under:

```text
systems/settings/legacy_migrations/msm_values_v1
```

The old file and `$PokemonSystem` data are left unchanged so migration is
non-destructive. After migration, an active transitional MSM installation is
mirrored into KR until MSM is disabled.
