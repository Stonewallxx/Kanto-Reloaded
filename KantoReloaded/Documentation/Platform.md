# Kanto Reloaded Platform

`KantoReloaded::Platform` provides runtime detection and portable helpers for
Windows, Proton/Wine, JoiPlay, and unknown hosts.

```ruby
KantoReloaded::Platform.id
KantoReloaded::Platform.label
KantoReloaded::Platform.windows?
KantoReloaded::Platform.proton?
KantoReloaded::Platform.joiplay?
KantoReloaded::Platform.supports?(:data_patches)
KantoReloaded::Platform.clipboard_write("text")
KantoReloaded::Platform.open_url("https://example.com")
```

## Paths

Use the platform helpers for paths handled by KR modules or external mods:

```ruby
path = KantoReloaded::Platform.join_path(KantoReloaded::Platform::GAME_ROOT, "Mods", "Example")
KantoReloaded::Platform.normalize_path(path)
KantoReloaded::Platform.path_within?(path)
KantoReloaded::Platform.glob(File.join(path, "**", "*.json"))
```

`display_path` returns a log-safe relative or basename-only path. It should be
used in user-facing errors instead of exposing a full local filesystem path.

Windows and Proton expose guarded clipboard and URL-opening adapters. JoiPlay
and unknown runtimes report these desktop capabilities as unavailable so
callers can provide an in-game fallback.

## JSON

The JSON adapter prefers Ruby's standard `JSON`, then KIF Mod Manager's bundled
parser, then `HTTPLite::JSON`. This keeps Data Patches usable on JoiPlay builds
where the standard JSON library may not be available.

```ruby
data = KantoReloaded::Platform.parse_json(text)
text = KantoReloaded::Platform.generate_json(data)
```

## Platform Overrides

`set_override` is runtime-only and intended for debug tools and contract tests.
It does not persist into save data or settings. Call `clear_override` to return
to automatic detection.
