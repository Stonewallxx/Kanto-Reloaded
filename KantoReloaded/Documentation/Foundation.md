# Foundation

The foundation is what every Kanto Reloaded feature is built on. It lives in `Core/`. KIF Beta loads the mod through `mod.json`, which lists only `Bootstrap.rb`; nothing in KIF Beta's own files is edited.

## Loading

`Bootstrap.rb` loads every file listed in `LoadOrder.rb`, in order, then boots the core systems listed in `LoadOrder::SYSTEMS`. A file or system that fails is logged and skipped, and the game keeps running. A new file must be added to `LoadOrder.rb`, or it doesn't load.

The `Dev` folder holds tools only for making Kanto Reloaded (the Hook Checker). It is never in a release. When it's there, Bootstrap loads `Dev/Dev.rb` after the other files and boots it last.

Everything lives in `module Reloaded`. Inside it, `Settings` means `Reloaded::Settings`; the game's settings module is written `::Settings`.

## Files

`Reloaded::Paths` keeps what belongs to saves beside KIF Beta's saves, and everything else in the mod's own folder. Nothing is written into the game folder. `Paths.write_atomic` writes through a temporary copy, so a crash never leaves a half-written file.

In the mod folder (`Mods\KantoReloaded`):

| Folder (`Paths`) | What it holds |
|---|---|
| `Settings` (`settings_dir`) | `Settings.json` (Global settings, "seen" settings, pins), `Features.json` (each feature's On/Off), `Controls.json` (controls the player rebound; everything else follows F1 or its default), `ControlLayouts.json`, `Whats New.json`, `Session.json` and `Last Crash.json` (Bug Reports), `Pause Menu.json` (Your Row and the Favorite), `Overworld Menu.json` (its pages), `Battle Menu.json` (the Battle Menu's order on each page, its Favorite and the page left on), `Timing Sessions.json`, `Hook Check.json` and `Hook Check Version.json` (Developer: the Hook Check runs at the Main Menu only when KIF's version or Kanto Reloaded's hooks changed since the last check) |
| `Logging` (`logs_dir`) | `Kanto Reloaded.log` (this session's; `.old.log` is the last one), `TimingProfile.txt`, and a folder each for reports: `Save Checks`, `Bug Reports` (`bug_reports_dir`: the bug reports made), `Hook Checks` (the newest 5 KIF versions' kept) and `Style Checks` (the developer Style Checker's reports and fix backups). Reports from before these folders move in by themselves |
| `Trainer Cards` (`TrainerCard.folder`) | The Trainer Card's Save as Image pictures (a phone whose mod folder can't be written gets them in the save folder's `Trainer Cards` instead) |

In the save folder (`%APPDATA%\KIF\Kanto Reloaded`, `Paths.data_dir`), save things only:

| File | What it holds |
|---|---|
| `Saves\<save>.kr` | Last-resort copy of each save's Kanto Reloaded data (for saves from before it was kept with the game's own) |
| `Save Notes.json` | Each save's note and color tag |
| `Save Previews.json` | What the save lists show, until the save changes |
| `Set Aside\` | What the Save Checker set aside to make a save loadable |

KIF's mod catalog never touches files a mod writes into its own folder, so updating Kanto Reloaded keeps them. The Release Builder leaves the three folders out. The first start after the change moves the old files from the save folder over (`Paths.migrate`); when both places have a file, the newer one is kept.

## JSON

`Reloaded::JSON.parse` and `Reloaded::JSON.generate(value, pretty)` read and write strict JSON. Never use PIF's `::JSON`: its `parse` runs the text as Ruby code.

## Log

```ruby
Reloaded::Log.info("Message", :channel)
Reloaded::Log.exception("What failed", error, :channel)
```

Warnings and errors also go to KIF's session log, and exceptions to KIF's crash log, so a KIF Beta bug report shows them.

**What the game runs on** (`Core/Foundation/Runtime.rb`): right after "booted", one line says what the game is running on, so any player's log (a Bug Report's too) shows what their game can do. On Windows, Linux or Steam Deck through Wine, or a phone (JoiPlay, Kirin), which reimplement the engine and may lack parts of it. It names the Ruby version and platform and the system the engine reports, and whether these are there: Windows calls (the Recycle Bin), Wine (its version, asked of Wine itself), the raw keyboard (Reloaded Controls), the controller functions, the mouse or touch position (clicks in Kanto Reloaded's screens), the clipboard (share codes, copying on a phone), and PIF's own Device option (PC / Mobile). It also says whether it's a phone, known by the signs the old Kanto Reloaded used (Ruby's platform saying android, Android's own environment variables, JoiPlay's marker; `Reloaded::Runtime.phone?` for the rest of the mod), and whether Kanto Reloaded's folder can be written, since its Settings and Logging live there and the old mod's notes say JoiPlay's game folder is read-only (unconfirmed until a phone log says). It changes nothing.

**On a phone, Copy Instead**: a phone can't open File Explorer or a browser, so the buttons that would (Open Folder in the Save Manager, the Save Checker's Report Saved, Bug Reports' Report Made) become **Copy the Path** or **Copy the Link** there. They put the full path or link on the clipboard and say **Copied**, or **Couldn't Copy** with the text to write down if the clipboard isn't there. Screens use `copy_for_phone(text, words)` from `Core/UI/Frame.rb`.

## Events

```ruby
Reloaded::Events.on(:save_loaded, :my_feature) { |context| ... }
```

| Event | When |
|---|---|
| `:core_booted` | Bootstrap finished |
| `:system_ready` | The game set up `$PokemonSystem` at startup |
| `:title_screen` | The title/load screen opened (no save is loaded) |
| `:save_loaded` | A save loaded, or a new game started (`context[:new_game]`) |
| `:new_game` | A new game's values were created |
| `:saving` | Just before Kanto Reloaded's save data is written |
| `:saved` | The game saved (`context[:path]`) |
| `:setting_changed` | `{ :key, :value, :old_value }` |
| `:feature_changed` | `{ :id, :state, :old_state }` |
| `:game_data_loaded` | The game loaded its data (Data Patches' targets read their base data) |
| `:data_patches_apply` | Data Patches' targets make the game's data from the patches (theirs only) |
| `:data_patches_loaded` | Every mod's data patches were applied and checked (`{ :summary, :patches, :errors }`) |
| `:profiler_session` | The Timing Profiler finished a session (`{ :session }`) |

## Features

Every feature can be switched On or Off. Off leaves the game as it was: the feature's hooks fall straight through to the game's own code, and its settings and menu entries hide.

```ruby
Reloaded::Features.register(:overworld_menu, :name => "Overworld Menu",
  :description => "A quick menu on the map.", :default => :on, :page => :overworld_menu)
Reloaded::Features.on?(:overworld_menu)
```

`:restart => true` marks a feature that changes game data while the game starts, so a change applies after a restart. A feature that raises an error is switched off for the session and logged once.

`:takes_over => ["F-UI-05_SpeedUp"]` names KIF features ours takes over (KIF 0.21.52's `KIF::Features`, which KIF calls replacing). While ours runs, KIF's acts as if its module were Off: its hooks fall through and its settings hide. KIF's Mods list says Kanto Reloaded replaces it. Switching ours Off, or ours failing, gives KIF's back at once. The feature ids are in `KIF::Features.list`, or in cody's `MOD_REPLACE_API.md`.

`:replaces => ["KIF's Randomizer Screens"]` declares a takeover KIF isn't told of, for when only part of a KIF folder is replaced and the rest must keep running (KIF's own takeover would switch the whole folder off). It's Kanto Reloaded's record only; the feature's hooks do the work. The Reloaded Randomizer takes over cody's Randomizer screens this way, while his engine runs on.

Each feature gets an On/Off row on the Features page, and another at the top of its own page (`:page`). The Features row goes to that page with Go to Settings (see The settings screen).

### KIF features Kanto Reloaded turns off

`mod.json` locks these Off while Kanto Reloaded is on (KIF applies them before Kanto Reloaded's scripts load, and undoes them if they fail):

| What | How | Shows as |
|---|---|---|
| Auto-Battle and Self-Battle (KIF's **Auto Battle** module) | `"modules": {"auto_battle": "off"}` | KIF Settings > Modules: Auto Battle Off, LOCKED BY Kanto Reloaded; their settings hide |
| KIF's Save Backups | `"locks": {"savebackups": 0}` | Infinite, LOCKED BY Kanto Reloaded (Backup Cap takes over) |

While the **Battle Menu** is On, Kanto Reloaded also locks cody's **Battle Info** Off with `KIF::Locks` (`BattleMenu.sync_kif_battle_info`, at boot and whenever the switch changes): KIF Settings shows it LOCKED BY Kanto Reloaded, and Controls leaves out its action. With the Battle Menu Off it's freed, and the player's own setting is back ([BattleMenu.md](BattleMenu.md)).

`KIF::Locks.release` drops every lock Kanto Reloaded holds, these included.

## Hooks

Kanto Reloaded changes the game's and KIF's code through hooks, never edits. Every hook belongs to a feature and is listed in `Reloaded::Hooks.registry`.

```ruby
Reloaded::Hooks.around(:pc, "PokemonStorageScreen", :pbStartScreen, :id => :pc_open) do |original, *args|
  # ...
  original.call(*args)
end
```

- **Feature Off:** while the feature is Off, calls go straight to the original.
- **Our code fails:** if the hook's own code raises, the feature switches off for the session and the call falls back to the original.
- **The game's code fails:** errors raised by the original pass through untouched.
- **Errors on purpose:** `:passes => [IOError]` lets the hook raise those without being switched off (safe saving raises IOError so the game says the save failed).
- **Class methods** are hooked on the singleton class: `Hooks.around(:x, Game.singleton_class, :set_up_system)`.
- **The object it was called on:** `original.receiver` (an instance method's `self`), for hooks that need it (`Pokemon#exp=` reading the Pokémon's lock).
- **A block:** `original.call(*args)` passes on the block the method was called with (the game's message boxes take one to keep a scene moving), unless the hook gives one of its own.

For code that runs every frame (input, drawing), use `Hooks.prepend(feature, target, Module)`. Its methods call `super` and check `Reloaded::Features.on?(feature)` themselves; `Hooks.guard(feature, where) { ... }` wraps the risky part. A feature of `nil` is a core hook that can't be switched off.

A module that only watches a game scene (Recent Steps, the Timing Profiler) uses `Hooks.watch(target, Module)`. Kanto Reloaded's own Party and Bag scenes are subclasses of the game's that replace its methods without calling up, so a plain prepend on the game's class never sees them; a watcher goes on every scene class Kanto Reloaded makes from that class too (`Hooks.scene_class(base, sub)`, now or later). Its methods check `Hooks.watching?(self, key)` and run inside `Hooks.watching(self, key) { ... }`, so a scene that falls back to the game's own isn't seen twice.

The registry keeps, for each hook, its target, method, kind and where in Kanto Reloaded it was made (`:where`, "Core/Settings/KIFBridge.rb:87"), and the error that switched one off (`:error`). `Hooks.skipped` lists the hooks skipped at boot and why (target or method not found).

Something of the game's that Kanto Reloaded reads by name without hooking it is declared with `Hooks.needs`, so a check after a game update can say it's gone:

```ruby
Reloaded::Hooks.needs(:field, :runstyle, :id => :controls_run_toggle)   # a $PokemonSystem field
Reloaded::Hooks.needs(:kif_option, :cody_battleinfo, :id => :my_split)   # a KIF::Options key
Reloaded::Hooks.needs(:kif_setting, "Quicksave with S", :id => :my_split) # a KIF setting's name
```

A setting bound with `Bind.system(:field)` counts too, as do mod.json's locks and modules, every `:takes_over` feature folder, and the splits' files.

## Save data

```ruby
Reloaded::SaveStore.register(:pc, :version => 2, :migrate => proc { |data, from| data })
data = Reloaded::SaveStore.section(:pc)   # a Hash in the loaded save; nil at the title
```

- **Plain data only.** Sections hold only plain Ruby values (Hash, Array, String, Symbol, numbers, true/false/nil, Time), so a save still loads without Kanto Reloaded.
- **Upgrades.** A section whose stored version is older is upgraded once with `:migrate`, all or nothing: Every pending upgrade runs on a copy and applies only if all of them work. If one fails, none apply, the old data is held in the save and tried again on later loads ([SaveChecker.md](SaveChecker.md)).
- **Kept with KR off.** The game writes only the save values of code that's loaded, so a save made with Kanto Reloaded switched off has no `:reloaded` value. The same data also hangs on the game's own `$PokemonGlobal` (`@kr_reloaded`): the game writes every field of its own objects, so the data is still there after such a save and comes back from it when the save loads. One save pass writes a shared object once, so the save doesn't grow. `SaveStore.value_in(save_data)` finds it in a save file either way (the Save Checker uses it).
- **Last-resort copy.** Each save also writes a copy to `Saves\<save>.kr`. A save with no Kanto Reloaded data anywhere (one from before it was kept with the game's own) gets it back from the copy, but only if the copy belongs to the same player.
- **The seal.** The game counts every save (`$game_system.save_count`), with or without Kanto Reloaded. Each save Kanto Reloaded writes records that count (`"seal"`). A save that comes back with a higher count was saved that many times without Kanto Reloaded: `SaveStore.gaps` lists each gap once (`"saves"`, the game's `"count"`, `"found_at"`, `"since"`), and `SaveStore.played_without?` says whether there's any (Difficulty counts such a run as Debug). Loading and quitting without saving changes nothing. A save Kanto Reloaded hasn't seen before is `"joined"` instead, not a gap.
- **Test copies.** A test copy (`Saves.make_test_copy`) carries `"test_copy"` (`"of"`, the slot it was copied from, and `"at"`) in this data, in both places, so the mark stays when the copy is saved with Kanto Reloaded off. `SaveStore.test_copy` reads it on the loaded save; Difficulty counts it as Debug.

## Settings

```ruby
Reloaded::Settings.register_page(:overworld_menu, :group => :general, :name => "Overworld Menu",
  :icon => :system, :feature => :overworld_menu, :description => "...")
Reloaded::Settings.register(:"overworld_menu.slots", :page => :overworld_menu,
  :name => "Quick Slots", :type => :slider, :min => 1, :max => 8, :default => 5,
  :scope => :global, :description => "...")
Reloaded::Settings.get(:"overworld_menu.slots")
```

| Option | Meaning |
|---|---|
| `:type` | `:toggle`, `:enum` (`:values`), `:slider` / `:number` (`:min`, `:max`, `:step`, `:unit`; a slider's `:steps => [1, 5]` lets Y switch its step in the improved screen), `:text`, `:button` (`:on_press`) |
| `:scope` | `:global` (all saves, `Settings.json`) or `:save` (the save's "settings" section) |
| `:long` | an enum that opens its own picker on A (a centred popup) instead of a dropdown: Theme, the frames, the colours |
| `:swatch` | `:text` or `:cursor`: the picker shows each value's colour |
| `:descriptions` | one text per value, in order: the dropdown explains the highlighted value with it |
| `:locked_choices` | proc returning `{ index => reason }` (or `[index, ...]`): values that can't be picked now. The dropdown shows them locked, Left/Right step over them and `set` refuses them |
| `:chips` / `:chip` | toggles in one group shown as one row of chips in the improved screen (Critical EV Gain's Stats); `:chip` is each one's label |
| `:range` | `[group, :floor / :ceiling, name]`: two sliders shown as one two-handle bar in the improved screen (IV Boundaries); `:range_shown` (proc(group): the numbers shown) and `:range_popup` (proc(screen, option): A on the bar, `[floor, ceiling]` or nil) on the floor |
| `:chip_pick` | an enum shown as a row of chips you pick with A in the improved screen (IV Boundaries' presets); `:locked_text` is what A on a locked one says |
| `:bind` | ties the setting to state the game already reads (`Bind.system`, `.switch`, `.variable`, `.custom`, `.direct`) |
| `:apply` | `proc { |value, restoring| }` when the value changes, and at startup / save load |
| `:commit` | `proc { |value, old_value| }` once when the settings screen closes, if it changed |
| `:needs` / `:needs_text` | locked until another setting is on |
| `:lock` | proc returning a reason when locked; presets respect it |
| `:soft_lock` | like `:lock` for a dependency on another setting; presets ignore it |
| `:feature` | shown only while that feature is On (pages pass it to their settings) |
| `:visible` | proc; hidden when it returns false |
| `:preset` | false keeps it out of presets and share codes |
| `:reset` | a `Settings.json` schema version: a value stored by an older file is dropped once, so the setting starts at its default |
| `:remap` | `[schema, { old => new }]`: an `:enum` value stored by an older `Settings.json` moves to its new index once (for values added mid-list) |
| `:added` | a version: shows "New" until seen (leave it off for the first version) |
| `:goes_to` | a page id: the switch has its own settings there, and the settings screen's Go to Settings (Y) jumps to that page's heading (Reloaded Controls to Controls; feature switches get it from `:page`) |
| `:priority` | order on the page |
| `:no_default` | no Default: X does nothing, no Default dot, `reset` and presets' Reset leave it alone (Difficulty, so one press can't lower a run) |
| `:tones` | one palette colour per value (`[:green, :blue, :red]`): the row's value and the dropdown's choices are drawn in it |
| `:confirm` | `proc { |new_value, old_value| }`: asked before a change (Left/Right, the dropdown, the Overworld Menu's rows); false keeps the old value. Presets (`force`) skip it |
| `:read_only` | shown, never changed: its name dimmed, its value with no arrows, Left/Right/A buzz, and the hint line offers neither Change nor Default (Difficulty's Shown As) |
| `:pill` | the value drawn as a pill in its `:tones` colour instead of words (Shown As) |
| `:tags` | `proc { [[label, [r, g, b] or a palette key], ...] }`: pills drawn left of the value, where a row's badge goes (Shown As's DEBUG) |

Save settings are locked at the title screen with "Load a save to change this".

**Developer pages:** Tools a modder might use are pages of the Kanto Reloaded section like any other, last, and shown only while KIF's DEBUG option is on (Settings > Advanced): the Timing Profiler's headings (Timing Profiler, Timing Profiler - Time, Timing Profiler - Report). Hot Reload in the Patch Viewer and the Save Checker's Inspector follow the same option. A page is hidden with `register_page(..., :visible => proc { Reloaded.debug? })`; an open settings screen gains or loses its headings when it rebuilds, so switching DEBUG in Settings shows them at once. A setting on a hidden page isn't built at all, since KIF Settings puts any row no section names in Game > Other.

## Controls

**Reloaded Controls** (Reloaded Systems, On by default) decides what every key and controller button does. Off gives the game's own controls exactly: the engine's F1 bindings and no extra actions. The F1 file is never written.

- **Actions:** everything the player can bind is an action with a keyboard side and a controller side, in an area: Global, Overworld, Menus or Battle. The game's 12 buttons (Confirm, Back, Action, Special, X, Y, Page Left/Right and the directions) are actions too. They start on the player's own F1 layout and follow it, F1 changes included, until rebound.
- **Feature actions:** a feature that today shares a game button gets its own action that `:follows` that button, so it changes nothing until the player rebinds it.
- **Extra Actions** (`Core/Controls/ExtraActions.rb`): shortcuts the game has no button for, unbound until the player gives them one (Overworld > Shortcuts): **Run Toggle** (flips PIF's Default Movement), **Bicycle** (on or off the Bicycle or Race Bike) and **Poké Radar**. They work on the map when the Ready Menu could open; a press while walking waits until the player stops, and the items go through the game's own field use. Quick Throw comes with Quick Throw and Catch Chances. The Battle Menu adds **Battle Menu** (on the Action button at first), **Open Battle Favorite** and **Open Battle Info** (unbound) to Battle > Battle Menu ([BattleMenu.md](BattleMenu.md)).
- **Splits** (`Core/Controls/Splits.rb`): KIF Beta's and PIF's features on shared buttons are split this way: Run, Pause Menu, Ready Menu, Quicksave and Skip Cutscene (Overworld), Mega Evolve and Shift (Battle), and Speed-Up, Next Speed and Reset Speed (Global). Battle Info has a split too, left out of the Controls screen while its setting is locked Off (as the Battle Menu does while it's On; `Splits.left_out?`). The feature's own code still asks for its button (`Input.trigger?(Input::Y)`); a split answers with the feature's action instead, but only for checks made from the feature's script file (Quicksave.rb's checks of Y are Quicksave's; the Bag's stay Y's). The game loads `Data\Scripts` with only each file's name, so splits name files; at startup the log says if a file no longer checks its button, and that feature then just follows its button. Mods split their own features with `Splits.add`.
- **The layer** (`Core/Controls/Layer.rb`): once per game step it reads the raw keyboard, controller buttons, sticks and triggers. It answers the game's `Input.press?`, `trigger?`, `repeat?`, `release?`, `dir4` and `dir8` by replacing only the engine's methods. So KIF's wrappers (Auto-Battle's confirm, Cody's Frame Rate key repeat, the speed keys, F8 screenshots) keep working on top. If it fails, it turns itself off for the session.
- **Feel** (Kanto Reloaded > Controls): Button Style, Swap A and B, Menu Repeat Speed, Hold Time, Trigger Press and Stick Deadzone.
- **Tap and hold:** an input with a hold action fires its tap actions when it is let go before Hold Time, and its hold actions once held that long.
- **Typing:** while text is typed, character keys only type. Arrows, Enter, Esc and the controller still work.
- **The controller check** (`Core/Controls/PadLog.rb`): Kanto Reloaded's log says what the engine sees of a controller, with Reloaded Controls On or Off. It notes whether one is there at start-up and each time one comes or goes, with the name the engine gives it and its buttons and axes, and the first press of each button and first push of each stick or trigger direction (each once). It notes the session's first click or tap and where it landed, which says whether a phone's touches reach the game as clicks. Bug Reports carry it with the log. KIF's own log names the controller in use (KIF 1.0.6+).
- **No controller fix of its own** (removed 2026-10-22, his call): Kanto Reloaded used to add 141 newer controller models to the engine's SDL (2.0.12, its list from 2021). KIF 1.0.4 went back to old KIF's engine (mkxp-z 2.4.2, SDL 2.28), which knows them and doesn't let scripts reach its SDL, so the fix went.
- **Never locked out:** the directions, Confirm and Back keep at least one key and one controller input. The Controls screen won't remove the last one, and a side left empty anyway (a hand-edited `Controls.json`) uses the engine's F1 inputs for that side. The engine's own keys (F1, F2, F12) can't be bound.

### The Controls screen

**Change Controls** (Kanto Reloaded > Controls) opens it (`Core/UI/ControlsScreen.rb`). It has the improved KIF Settings' layout:

- **Sidebar:** Global, Overworld, Menus, Battle, Speed-Up and Feel. An area with no actions yet is dimmed and skipped. Speed-Up lists Speed-Up's settings under Game Speed, then its three buttons (Global's Game Speed actions, no longer listed under Global) under a Buttons heading that carries the Keyboard and Controller labels (see [SpeedUp.md](SpeedUp.md)).
- **List:** each action with its Keyboard and Controller columns. Left and Right pick the column, and a dot marks a changed one. An input another action in the area also has is underlined, and the description says what else it does. An empty column reads "Not Bound".
- **Change:** Remove an input, Add a Key / Add a Button, or Back to Default. Adding asks the player to press it ("Press a Button or Move a Stick"); keeping it held for Hold Time binds it as a Hold. An input another action has asks Swap, Keep Both or Cancel.
- **Default** puts the selected column back. **Search** finds actions by name.
- **Layouts** (the R button) has Game's Layout (F1), Pokémon-Style, the player's own layouts, Save as New Layout, Paste Share Code, Reset Section and Reset All to Default. A layout of their own (`Core/Controls/Layouts.rb`, up to 12 in `ControlLayouts.json`, for all saves) holds every action's bindings on both columns and the Feel settings; it can be loaded, saved over, renamed, deleted, or copied as a `KRC1:` share code. Loading one keeps what matches the default following F1, and a pasted code is checked input by input.
- **Pokémon-Style** (built in, `Layouts::POKEMON_STYLE`) sets only the controller, as in the main Pokémon games: B runs (held), X and Start open the Pause Menu, Y the Ready Menu, holding Select quicksaves, RT speeds up. Every other controller input goes back to the game's layout and the keyboard stays as it is (`Controls.apply_side`). Tapping Select is left free for the Overworld Menu.
- **Settings** (Feel's, Speed-Up's) step with Left and Right; A (or a click on the value) opens a dropdown of their values, as in KIF Settings. A locked one (the other Speed-Up Type's) is dimmed with a padlock, buzzes, and its description says why. Reset Section resets a section's settings too (the locked ones as well), and Reset All to Default every action, Feel and Speed-Up.

```ruby
Reloaded::Controls.register(:my_mod_menu, :name => "My Menu", :area => :overworld,
  :keys => ["k:63"], :pad => ["hold:p:6"], :description => "Opens My Menu.", :owner => :my_mod)
Reloaded::Controls.trigger?(:my_mod_menu)   # also press?, repeat?, release?
```

Inputs are `"k:<SDL scancode>"`, `"p:<controller button>"`, or `"a:<axis>+"` / `"a:<axis>-"` for sticks and triggers, with `"hold:"` in front for a hold. While Reloaded Controls is Off, an action that follows a game button reads that button, and other actions don't fire. `Reloaded::Prompts.name(:C)` names the binding on the device the player used last.

## Fixes

Bugs in PIF or KIF Beta that Kanto Reloaded fixes, in `Core/Fixes/`, with hooks like everything else. A fix that has to replace a whole method is written against that method's source (found with `Reloaded::Paths.script_file`, since the game loads its scripts with only their names). It applies only while the method's fingerprint (`Reloaded::Fixes.source?`) still matches, so a game update never gets an old copy put over a new method. If it doesn't match, the fix stays off and the log says so.

| Fix | What it fixes |
|---|---|
| `CommandTextColours.rb` | PIF draws a command row with formatting (the pause menu's icon rows) in the font's default white instead of its window's text colours, so it can't be read on a light frame (Theme Mode Light or Frost, the light RLD frames). Each formatted row now starts with the window's colours. |
| `EBDXCommandCursor.rb` | KIF's EBDX cursor memory (`660_EBDX/021_EBDX_CursorMemory.rb`) keeps the picked command's value as the cursor's position, and Battle Info's INFO button has the value 50, so after Battle Info closed the cursor sat on no command and choosing one crashed the battle. `CommandWindowEBDX#index=` now sends a position that isn't there to the command with that value (INFO again), else the first. Kanto Reloaded locks Battle Info Off, so this only comes up if that lock is lifted, or when EBDX's battle commands leave one out (its `BATTLE_COMMANDS` metrics), which shifts every value after it. |
| `EBDXMoveLayers.rb` | EBDX's Fight menu lifts the picked move to show its type and PP, but every move button had the same layer, so the move under it covered its bottom (`660_EBDX/007_EBDX_UIWidgets.rb`, `FightWindowEBDX`). The picked move now goes on top, set only when the pick changes. On whether Battle Scene is or not. |
| `PIFBalls.rb` | PIF's Pure Ball and Status Ball (`052_InfiniteFusion/Gameplay/Items/New Balls.rb`) compared a status with 0, but a status is a symbol (`:NONE` when there's none), so the Pure Ball ("works better on a Pokémon with no status") never got its x3.5 and the Status Ball ("works better on a Pokémon with a status") always got its x2.5. Both handlers are added again as their descriptions say, only while PIF's are as written (a handler's fingerprint: `Reloaded::Fixes.handler_crc`, its first line to its `})`). For everyone, Quick Throw on or off. |
| `KIFMapZoom.rb` | KIF 1.2.13 dropped Map Zoom's 1.5x level (`990_KIF/ZZ_Cody/C-UI-01_MapZoom/MapZoom.rb`: `KIF::MapZoom::LEVELS` is Normal and Far at 1x, and `level` reads an old Far or Farthest as Far), but its setting still offered Normal, Far and Farthest with the old words, so Far and Farthest both zoomed to 1x. Its Graphics builder (`KIF::Options.entries(:graphics)`) is swapped for one offering Normal, Far, **Adaptive** and **Test (1.5x)** (his asks): Adaptive is Far outdoors and Normal on every map PIF marks as not outdoor (buildings, caves, underwater; the map's flag kept per map), Test (1.5x) is map pixels at 1.5x (a scale of 0.75) on every map, to try the step KIF dropped (2x2 art pixels can't land evenly on it). Both are `KIFMapZoomLevels#wanted` on `KIF::MapZoom`, read every map frame, and keep KIF's camera (his pick: it stops at map edges as at Far). They're kept as `kif_mapzoom` 3 and 4, which KIF's `level` reads as Far, so without Kanto Reloaded they play Far. Only while KIF's block is as written (`Reloaded::Fixes.lines_crc`, its first line to its `}`). For everyone. |
| `CardBackgrounds.rb` | PIF's Trainer Card backgrounds: a picture whose file name has a stray space or a capital extension is found by its clean name (Sewers' `SEWERS .png` showed PIF's plain card; Froslass's `FROSLASS _FLAG.png` and, on a phone, Lugia's `LUGIA_FLAG.PNG` had no picture). The Sprite Gallery's flags of the day now include Lugia's (its `.PNG` kept it out) and Froslass's as its own (a name with a space fell back to Pikachu, so it was sold as Pikachu's). A city's Printer leaves off a background with no picture (Cinnabar's). For everyone, the Reloaded Trainer Card On or Off. |

The fixes kept in KR Fork Salvage come here as they're turned into hooks.

## Graphics and sounds

Kanto Reloaded's files stay in `Mods\KantoReloaded\Graphics` and `Audio`. When the game loads `Graphics/Pictures/foo` or plays `Audio/SE/bar`, it gets the mod's file, but only for files the mod ships. Nothing is copied into KIF Beta's folders. Fonts are the exception: the engine loads them only from the game's `Fonts` folder at startup.

### Pokémon icons

Every Pokémon or Egg picture in Kanto Reloaded's screens follows KIF Beta's **Big Pokémon Icons** (Graphics; Limited or All: battle sprites instead of the small icons). They all come from `Core/UI/PartyIcons.rb`, never straight from `Graphics/Pokemon/Icons`:

- `icon(pkmn, viewport, z)` and `place`: a Pokémon, as the game's own icon sprite. Big ones are scaled to the small ones' size and centred the same way.
- `species_bitmap(species)`: a species with no Pokémon behind it (a list of the wild ones here). With Big Pokémon Icons on, the battle sprite the game shows for it (the alt the player picked).
- `egg_bitmap`: an Egg whose species isn't known yet (the Day Care's). With Big Pokémon Icons on, KIF Beta's Egg battle sprite.
- `art_rect(bitmap, frame)`: the part of the first frame the Pokémon is in, so a list can fit the Pokémon itself to its box rather than the frame and its margins (Area Encounters). It looks at about 64 x 64 points of the frame, from each edge in.

## Data Patches

Mods change the game's data (items, moves, abilities, species, trainers, encounters, outfits) with JSON files in `Mods/<mod>/DataPatches`, in memory after the game loads its data, never in its files (`Core/DataPatches`). A patch that fails a check is skipped with a reason in plain words; two mods on one entry is a conflict load order decides. **Kanto Reloaded > Data Patches > Patch Viewer** shows each mod's patches, its conflicts and why a patch was rejected; with KIF's DEBUG option on, Y there reloads them without a restart (Hot Reload). The full guide for mod makers is [DataPatches.md](DataPatches.md).

## Saves

Safe saving (every save written to a temporary file, read back, then swapped in), the Save Manager (Active, Backups, Deleted; notes, colour tags, health), the rebuilt Load Screen (always on with Kanto Reloaded) and What's New. The guide is [Saves.md](Saves.md).

Bug Reports make one file with everything needed to fix a bug (logs, settings, mods, hooks, the Save Check, Recent Steps, a note and a screenshot), and After a Crash offers one before the game closes, naming the mod the crash came from. The guide is [BugReports.md](BugReports.md).

The Save Checker checks a save or backup on a copy: the file, Kanto Reloaded's data and its upgrades, plain values, Missing Content (Keep Aside or Remove) and Mod Data (Make It Loadable), with a report to save. The guide is [SaveChecker.md](SaveChecker.md).

## Timing Profiler

With KIF's DEBUG option on and **Kanto Reloaded > Timing Profiler** On, battles, map loads, menus, saving and loading are timed as you play, each a session; Mod Timings times each mod's hooks on their own (aimed TracePoints, only while it's on). The Report Viewer shows them; the guide is [TimingProfiler.md](TimingProfiler.md).

## Autosave rows

PIF's Autosave setting opened its own "Autosave settings" window when switched On. In KIF Settings (both screens) it is a heading of its own in Game, after Saves (`Core/Settings/AutosaveRows.rb`): **Autosave** (On/Off, no window), and while it's On, **When Healing**, **When Catching Pokémon**, **After Trainer Battles** and **Every X Steps**, plus **Steps Between Saves** (a number) while Every X Steps is On. They use PIF's own switches and variables and its On/Off order, show only in a save, and replace PIF's Autosave row.

## Window frames

Kanto Reloaded > Interface sets the frames around the game's windows (`Core/Interface/WindowFrames.rb`):

- **Theme Mode:** how the Theme frame looks: **Dark** (the default; a dark panel, the Theme's border), **Glass** (see-through), **Light** (a near-white panel tinted by the Theme) or **Frost** (Light, see-through). The map menus (the Pause Menu and the Overworld Menu, with their popups) follow it too, in the Light frames' own look (Matching Frames, his pick 2026-10-21): the Theme's dark ink for words, deeper green, gold and red statuses, pale badges, a fainter cursor, and the Pause Menu washes the map pale instead of darkening it. Glass and Frost make their panels see-through. Full screens are Dark or Light only (his call, 2026-10-21): Glass shows them Dark, Frost shows them Light, never see-through. Every full screen does this through `Frame#palette` (the Light pass, 2026-10-22), and so do the popups and notices over them; bright words on a panel use the palette's `:strong` (white on Dark, the dark ink on Light), statuses its tones, and badge or banner fills `Frame#dark_fill`. **Popups**: Header Plate, a cut-corner frame with the title centred on a plate of its own and the Poké red line under it; buttons get cut corners, list rows the regular cursor (`Reloaded::Dialogs` panel, title_bar, button, cursor_row; a notice passes its own colour). `Reloaded::Palette.map_menu` gives the map menus' colours, `menu_alpha` a panel's see-through amount.
- **Global Frame:** menus and every other window. **Theme** (the default) draws it in the Theme's colours, in the Theme Mode. The other choices are RLD Clear, PIF Clear and PIF Opaque (PIF's own two), and the 30 RLD frames, light and dark, from the old Kanto Reloaded and Hoenn Reloaded.
- **Speech Frame:** text boxes. **Theme** (the default) uses the Global Frame; the others are PIF's speech frames, RLD Clear and the RLD frames. It also takes the place of PIF's own Speech Frame row in KIF Settings > Graphics > Text, as the same setting. A PIF speech frame picked here is copied to PIF's own setting, so it stays if Kanto Reloaded is removed.

Both pickers show each frame. The frames are the mod's files in `Graphics/Windowskins`: `Theme <theme>` (Dark) and `Theme <mode> <theme>` for each Theme, drawn from `Palette.rb`'s colours, plus `RLD Choice <n>`, `RLD Choice <n>a` (dark) and `RLD Transparent` (RLD Clear). PIF gives dark frames white text by itself, and sizes a frame's edges from its picture, so any of them works as a text box.

Values line up on one column per heading, which moves left for the widest value, so long frame names would push other Interface rows onto two lines; the preview checks every Kanto Reloaded row stays on one line.

KIF Settings places rows by name: a Kanto Reloaded setting with one of KIF's names (Speech Frame) shows in KIF's place for it too, as the same row, with its own description.

## The settings screen

Kanto Reloaded's settings live in KIF Settings. `KIFBridge` adds a Kanto Reloaded section, first in the sidebar, with one heading per page and every setting as one of KIF's own rows (the improved screen shows it as a section per feature: see below). The section follows features switching On and Off each time the screen rebuilds.

**Reloaded Settings** picks the screen that Options opens. It is the first row of **Reloaded Systems**, the first heading of the Kanto Reloaded section, which holds the toggles between Kanto Reloaded's version of a system and the game's own. It is On by default:

- **On:** the improved KIF Settings (`Core/UI/SettingsScreen.rb`). It is a subclass of KIF's `KifSettingsScreen`, so it has the same sections, rows, modules, mods, search and defaults. It draws and handles input Kanto Reloaded's way: the theme and colour settings, the pulsing cursor, choices between arrows that step with Left and Right and open a dropdown with A, values (with OPEN, badges and slider numbers) lined up on one column per heading, smaller hints and descriptions, and presets with share codes in the title bar (or R). Search works as KIF's does. A Kanto Reloaded setting another one decides right now (its `:soft_lock`, `:lock` or `:needs`: the other Speed-Up Type's rows, the PokeVial's Max Uses under Progressive Uses) is dimmed with a padlock where its arrows would be; Left, Right, A and the Default button buzz, and its description says why ("Locked: Toggle Only."). The Overworld Menu's setting rows say the same.

**A section per feature:** In the improved screen, Kanto Reloaded's settings are split into sections, one per feature, folded out under Kanto Reloaded in the sidebar (indented, in the smaller text). The right panel shows only the chosen section: a header for each of its pages (a one-page section still has its header), then their rows. The order, and which pages share a section, are in `Core/Settings/Sections.rb` (`Reloaded::SettingsSections::LIST`): **Core** first (Reloaded Systems and Features, the switches), then the look and controls, saves, your run, items and Pokémon, and the developer tools last. A page that isn't listed gets a section of its own, before the developer ones. A section shows only while one of its pages has a row to show, so a feature switched Off takes its section with it.

- **The title:** Kanto Reloaded stays pinned at the top of the sidebar while its sections scroll. It is a stop of its own: A or Left folds the sections away, so KIF's sections come close, and A or Right opens them again. B in one of its sections folds them too; B on the title closes the screen.
- **Folded to Start:** The sections start folded away, and the screen remembers how you left them (open or folded) for next time. Going to a setting from elsewhere (Go to Settings, the Overworld Menu, Search) opens them for that visit without changing it. **Per-Save Settings** always shows them open.
- **Headers:** a page's name without what comes before " - " (Bag - Auto-Sort is Auto-Sort), or its own name in its section (`HEADERS`: the Bag's page is Reloaded Bag there). Long section names get a short one in the sidebar (`SHORT`).
- **Search** looks in every section, folded or not, and names each Kanto Reloaded result's section and header with a small Poké Ball ("Reloaded Bag > Auto-Sort"). KIF's own results keep KIF's "Section > Heading".
- **KIF's own screen** (Reloaded Settings Off) keeps one Kanto Reloaded section with a heading per page. The rows themselves are KIF's in both, so the Overworld Menu finds a setting the same way either way.

**Go to Settings:** On a Reloaded Systems or Features switch that has settings of its own (`:goes_to`), Y (A on a keyboard) jumps to that page's heading in its section: the heading at the top of the list, the cursor on its first setting. The button shows after the highlighted switch's name and in the hints, only while the page is showing (a feature's page hides while it's Off), and a click on either goes too. B goes back to the switch once, then to the sections as before. From a search's results it clears the search first.

**The mouse** works in Kanto Reloaded's own screens and popups, never on the map (`Core/UI/Pointer.rb`):

- **Hover:** moving the mouse over a section, a row (in Controls, an action's column), or a popup's row or button picks it. It only follows the mouse when the mouse moves, so a resting mouse never fights the controller.
- **Click:** one click does the thing: opens a section's list, presses a row (as A), opens a choice's dropdown when it's on the value, steps a value when it's on the value's left or right side, opens the editor of the Controls column under it, or chooses a popup's row or button. A click on a hint does what the hint says (Default, Sections, Close...): a screen's `hint_pairs` give each clickable hint a third part, the method it runs.
- **Wheel:** over a list it scrolls the view and the cursor goes to the row under the mouse; over the sections it moves between them; in a number popup, up adds.
- **Right click:** goes back.
- **Lit:** the Search, Presets and Layouts boxes and the hints light up under the mouse (not a box that can't be used).

Screens note where they drew what can be clicked ("hits") as they paint; `Frame#pointer_hover` handles the title bar and the hint line for every screen.

**On KIF's mouse** (KIF 1.2): the pointer is KIF's (`KIF::Mouse`), so KIF's Mouse option (Options > System > Controls; Touch controls on a phone) turns the mouse on and off in Kanto Reloaded's screens too, and a phone's taps land where they're meant to. KIF makes a click A and B and the wheel Up and Down on every screen; the first time a Kanto Reloaded screen reads the pointer in a frame it claims that frame's click and wheel (`swallow!`, `eat_wheel!`), so a click isn't A as well and the wheel doesn't step twice. A game window opened over a Kanto Reloaded screen (a message's choices) doesn't read it, so KIF's mouse works there as KIF made it. On a KIF without its mouse, the pointer is mkxp-z's own, always on.
- **Off:** KIF Settings as KIF Beta ships it. Only Kanto Reloaded's own choices change: A on one opens its dropdown.

If the improved screen fails, it logs the error and opens KIF Settings as it ships (`KIFBridge.vanilla`).

### Option Dropdowns

A on a choice (or a click on its value) opens a dropdown of its values (`Core/UI/Dropdown.rb`); Left and Right still step through them. It works on every choice in the improved KIF Settings, on the Controls screen's Feel settings, and on Kanto Reloaded's rows in KIF Settings as it ships (`Core/Settings/KIFDropdowns.rb`). KIF's own rows there stay as KIF ships them.

- **Where:** under the value; above it when there's no room below; when neither side has room, under it moved up just enough, over the value. Up to 5 rows show; a longer list scrolls, with arrows and a scrollbar. While it's open, values it would cut through aren't drawn, so no half-covered text shows at its edges.
- **What it shows:** the current value marked NOW, the highlight in Cursor Color, locked values dimmed with a padlock. The description box names the highlighted value and explains it: KIF's per-value descriptions, a Kanto Reloaded setting's `:descriptions`, else the setting's own description. A locked value says why first.
- **Buttons:** Up and Down move (a held direction stops at the ends, a fresh press goes round), Left and Right move a page, A picks, B closes. The hint line reads Choose, Pick, Close.
- **Mouse:** hovering highlights a value, a click picks it, a click on an arrow scrolls, the wheel scrolls, and a click outside or a right click closes it.
- **Not dropdowns:** settings with their own picker (`:long`: Theme, Global Frame, Speech Frame and the colours) keep it, KIF's tab rows step, sliders and numbers open the number popup.

A screen with its own loop uses `Frame#run_dropdown(dropdown)`, draws it with `paint_dropdown`, shows `dropdown_hints`, and explains `@dropdown.index` in its description box while `@dropdown` is set. `Dropdown.run(dropdown, bitmap, colours)` runs one for a screen that has no loop to share.

The screen is built from these parts, which later Kanto Reloaded screens reuse:

| Part | What it does |
|---|---|
| `Palette` | Theme, Header Color, Settings Color and Cursor Color, as `Palette.current` |
| `Prompts` | Button names for hints: controller names while a controller is in use, otherwise the player's keys (Button Prompts) |
| `Pixel` | Text in KIF's pixel fonts, centred on the capitals; the smaller text of hints and descriptions; badges, headings, hints and the cursor |
| `ButtonIcons` | Inputs drawn as icons: keycaps, and Xbox, PlayStation or Nintendo buttons, sticks, triggers and the d-pad (Button Style) |
| `SplitScreen` | The Patch Viewer's and the Timing Profiler's layout (What's New's and Publish a Mod's too): the sidebar of entries, the list of headings and rows, the description box with badges and scrolling (by itself, or by hand with the right stick or the mouse wheel over it, where it then stays) |
| `Frame` | What every settings-like screen shares: the layers, the pulsing cursor, the centred hint line that scrolls when it's too long, the title-bar boxes with their buttons beside them, the description box, running a dropdown, and alerts (`alert_box`: a red glow around a box, pulsing, on its own layer; the PokeVial's Low HP Reminder) |
| `Dialogs` | Popups: `menu` (rows can lead with an input's icon), `picker`, `confirm`, `notice`, `ask` and `number` (with an item's picture and a line under it, `icon:` and `note:`), and `frame` for a popup a screen draws itself (`drawn` runs one with buttons, drawn with `button_row`: the Test Copy question). A settings button's popups draw on `SettingsScreen.showing` |
| `RunTags` | A save's run as pills: its mode, its difficulty (Shown As) and DEBUG, on the Load Screen and in the Save Manager |
| `Toast` | A short line at the top for a moment, no button: an icon, the words, a pill or a drawing of its own. It goes after 3 seconds of real time (its last half second fading), whatever the game is doing; it shows over the map menus |
| `Dropdown` | A choice's values, dropped down from its value (Option Dropdowns) |
| `TextEntry` | Typing into a field, as KIF Settings' search does: the keyboard types straight in (Ctrl+V pastes), and a controller's A opens the game's naming screen |
| `Presets` | KIF's 12 preset slots, with Kanto Reloaded's per-save settings, share codes, Rename and Delete |
| `ShareCodes` | Share codes (a prefix such as `KIF1:` or `KRC1:`, then Base64 JSON, read without eval) and the clipboard |
