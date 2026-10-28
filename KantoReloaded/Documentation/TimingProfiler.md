# Timing Profiler

The Timing Profiler times what you do while you play: battles, map loads, menus, saving and loading. Each one becomes a **session**. Mod Timings shows each mod's share: its startup, its time per frame and its slowest hooks.

It's a tool for making Kanto Reloaded and mods. Players never see it: it shows only while KIF's DEBUG option is on (KIF Settings > System > Advanced > DEBUG). It grew out of old Kanto Reloaded's Battle Timing Profiler (Roadmap topic 33). The code is in `Core/Profiler`, and the screens are in `Core/UI/ProfilerScreen.rb`.

## Switching It On

1. In KIF Settings, turn **DEBUG** On (System > Advanced). The Timing Profiler's headings appear at the end of the **Kanto Reloaded** section.
2. Under **Kanto Reloaded > Timing Profiler**, turn **Timing Profiler** On.
3. Play. Then open **Kanto Reloaded > Timing Profiler > Report Viewer**.

Nothing of the profiler runs until it's first switched on: its probes and hook timing go in then, so a player who never uses it pays nothing but one check per frame.

## Settings

All of them are in the Kanto Reloaded section, under Timing Profiler, Timing Profiler - Time and Timing Profiler - Report, for every save.

| Heading | Setting | Default | What It Does |
|---|---|---|---|
| Timing Profiler | Timing Profiler | Off | Times what you pick below while you play. |
| Timing Profiler | Report Viewer | | Opens the sessions and Mod Timings. |
| Time | Battles | On | Each battle: its phases, the scene's frame work, EBDX's windows. |
| Time | Map Loads | On | Each map you go to: its data, events, sprites, music. |
| Time | Menus | On | The Bag, Party, PC, Summary, Pokédex and Pause Menu, from opening to closing. |
| Time | Saving | On | Saving the game, and loading a save. |
| Time | Mod Timings | On | Each mod's hooks, timed on their own. |
| Report | Slow Frame | 33.3 ms | Above this, a frame (or a section within one) counts as slow. 16.7 ms is one frame at 60, 33.3 ms two, 50 ms three. |
| Report | Keep Sessions | 25 | How many sessions are kept; the oldest go first. |
| Report | Text Report | On | Also adds each session to `Logs\TimingProfile.txt`. |

## Sessions and Sections

A session is one battle, one map load, one menu (from opening to closing), one save or one load. Its **sections** are the parts that were timed in it, each with:

- **Calls:** How many times it ran.
- **Total:** Its work, all calls together.
- **Peak:** The most it did within one frame. For a part that runs across many frames (a battle's Command Phase), that's its worst frame, not the whole phase.
- **Slow:** How many times its peak went over Slow Frame.
- **Owner:** Whose code it is: Kanto Reloaded, a mod, EBDX, KIF Beta or PIF (by the file it's in).

Times are **work**: the time the game spends waiting for the next frame (in `Graphics.update`) is left out. So a battle's Command Phase counts the menus' work while you pick, not the time you spend thinking.

Every session also has **Frame Work**: each frame's work while it ran, so you can see its slow frames. A session's status dot is red when any frame or section went over Slow Frame, amber when its worst peak is over half of it, and green otherwise.

Sections can be **nested**: Map Setup runs inside Map Data Load, and the Viewer says so. Don't add nested sections together.

### What's Timed

| Session | Sections |
|---|---|
| Battle (named after its trainers, or Wild Battle) | Battle Start, Command Phase, Attack Phase, End-of-Round Phase, Scene Setup, Native Frame Work, EBDX Frame Work, Scene End, EBDX Command / Fight / Bag / Target Refresh |
| Map load (named after the map you go to) | Map Data Load, Map Setup, Events Setup, Sprites Dispose, Sprites Build, Music Change, Town Map Check |
| Menu (Pause Menu, Bag, Party, Summary, Pokédex, PC) | Open, Refresh, Close |
| Saving, Loading Save | Write Save File (and the map load sections while a save loads) |

A probe whose class or method isn't in this game (KIF Beta without EBDX, say) is skipped. A battle's session also keeps its turns, decision, sides, scene and network mode.

## The Report Viewer

The Settings layout. The sessions are on the left, newest first, each with its status dot; sessions from an earlier time the game ran are faded. The selected session's sections are on the right, slowest first, with **PEAK** and **SLOW** and a dot in their owner's colour; Frame Work comes last. The description box explains the selected session or section in plain words, with its slow count and owner as badges.

| Button | What It Does |
|---|---|
| Up / Down | Pick a session, or a section |
| Right or A | A session's sections |
| Y | Sort: Peak, Total, Calls, Name |
| X | Only one owner's sections, then the next, then all again |
| B | Back to the sessions; on the sessions, close |
| Left box (L) | Settings: back to the Timing Profiler's settings |
| Right box (R) | Mod Timings |

The mouse works too: hover picks, a click opens, the wheel scrolls, a right click goes back.

## Mod Timings

Each mod on the left: Kanto Reloaded first, then mods and EBDX by name, **PIF and KIF** last (the game's own work: its frames' work less every mod's hooks). For each:

- **Startup:** How long its scripts took to load, plus its Data Patches. Kanto Reloaded's is its own load and boot. A mod that loads **before** Kanto Reloaded can't be timed: its scripts ran before anything could time them (KIF loads Mod Manager's mods first, then its own folders alphabetically).
- **Data Patches:** Reading and applying its patches. Kanto Reloaded's also has making every mod's patched data into the game's.
- **Per Frame, Map** and **Per Frame, Battle:** Its hooks' time per frame, on average, on the map and in battle.
- **Slowest Hooks:** Its hooks, by their worst call within one frame. A opens the session it was slowest in.

### How Hooks Are Timed

A hook is a mod's code on one of the game's classes or modules (one that has methods from PIF's or KIF Beta's own files):

- an alias wrapper: `alias old_update update; def update ... old_update ... end`;
- a prepended module (`Scene_Map.prepend(MyModule)`);
- Kanto Reloaded's own `Reloaded::Hooks.around` and `.prepend`.

The first time Mod Timings runs, it finds every such method and each of its layers: each mod's, and the game's under them. Each layer gets a TracePoint aimed at it alone (`TracePoint#enable(target:)`), so the rest of the game runs untouched. A layer's time is its own: the layers it calls are taken off (they're timed too), and so is waiting in `Graphics.update`. Hooks Kanto Reloaded adds later (a feature switched on) are found again on the next frame. The TracePoints are on only while Mod Timings is.

Limits:

- A layer written in C (the engine's own methods) can't be aimed at; its time counts toward whoever calls it.
- Only the main thread is timed (Multiplayer's network threads aren't).
- Code that runs inside the game's own frame update, under the profiler's frame clock (KIF's Ruby layers on `Graphics.update`, the engine drawing), counts as the wait for the next frame, as Frame Work does: it isn't timed as anyone's hook.
- A mod's own screens and helpers that aren't hooks count only when a hook calls them.
- TracePoints cost a little on every call to a timed hook, so per-frame numbers run slightly high on hooks called hundreds of times a frame.

What Mod Timings finds is kept: in `Settings\Mod Timings.json` every 30 seconds while it runs (walking ends no session), and added to `Logging\TimingProfile.txt` as one table when the game closes (with Text Report On), so closing the game no longer loses it.

## Files

In the mod folder (`Mods\KantoReloaded`):

| File | What It Holds |
|---|---|
| `Settings\Timing Sessions.json` | The kept sessions (Keep Sessions), for the Report Viewer after a restart |
| `Settings\Mod Timings.json` | Mod Timings as it last stood: each owner's time per frame on the map and in battle, its startup and its slowest hooks |
| `Logging\TimingProfile.txt` | Text Report: each session as a table, as old Kanto Reloaded's profiler wrote it, and Mod Timings as the game closes. Past 2 MB it starts again, keeping `TimingProfile.old.txt` |

Cody's frame log (`Logs\KIF_framelog.txt` in the game folder, KIF Beta's slow overworld steps) stays as it is.

## Timing Your Own Code

A feature (Kanto Reloaded's, or a mod's) can add its own sections:

```ruby
# a part of your code, in whatever session runs then
Reloaded::Profiler.measure("Target Icon Prewarm", :owner => "Kanto Reloaded",
                           :about => "Drawing the target icons ahead of time.") do
  prewarm_icons
end

# a method of the game's, as a section (kind: :battle, :map, :menu, :saving or :loading)
Reloaded::Profiler::Probes.section("PokeBattle_Scene", :pbShowWindow, "Show Window", :battle,
                                   :about => "Switching the battle's windows.")

# a method as a session of its own
Reloaded::Profiler::Probes.session("PokemonTrainerCard_Scene", :pbStartScene, :menu) { |_scene, _args| ["Trainer Card", {}] }
```

`measure` does nothing unless a session is running, so it can stay in your code. After each session, `:profiler_session` fires with `{ :session }`.
