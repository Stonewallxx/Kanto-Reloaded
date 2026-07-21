# Kanto Reloaded Save Data

Kanto Reloaded registers one `:kanto_reloaded` entry with KIF's `SaveData`
system. Framework services, built-in modules, and external mods receive separate
namespaces inside that bucket.

```ruby
KantoReloaded::SaveData.system(:framework_service)
KantoReloaded::SaveData.module_data(:module_id)
KantoReloaded::SaveData.mod(:external_mod_id)

KantoReloaded::SaveData.get(:module_id, :key, nil, :section => :modules)
KantoReloaded::SaveData.set(:module_id, :key, value, :section => :modules)
```

Only values accepted by `Marshal.dump` can be stored. If a save was created by
a newer KR schema, or a migration fails, KR preserves the original bucket and
blocks KR bucket writes for that session.

`KantoReloaded::SaveProtection` tracks the source slot through a guarded wrapper
around `SaveData.read_from_file`. Before a KR schema migration, it creates and
size-verifies a rolling backup under `backups/<slot>` beside the source save.
It does not replace KIF's normal save writer or backup behavior.

## Migrations

Increase `KantoReloaded::SaveData::SCHEMA_VERSION` only when existing bucket
data must change shape. Every migration advances exactly one schema version.

```ruby
KantoReloaded::SaveMigrations.register(
  :schema_1_to_2,
  :from => 1,
  :to => 2
) do |bucket|
  bucket[:modules][:new_id] = bucket[:modules].delete(:old_id) || {}
  bucket
end
```

Adding an optional key with a runtime default does not require a schema change.
Legacy Mod Settings Menu import is a separate compatibility migration because
that data is stored outside the KR save bucket. `KantoReloaded::MSMCompatibility`
imports legacy values once, records `msm_values_v1` under the settings system,
and leaves the original MSM data untouched.
