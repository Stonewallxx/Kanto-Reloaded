# Save Checker

The Save Checker looks a save over without loading it into the game. It reads the file into memory and checks what it finds there; the file itself is only read. It's Roadmap topic 36. The code is in `Core/SaveCheck` and the screens are in `Core/UI/SaveCheckScreen.rb`.

## Opening It

- **Save Manager > Active:** Click a save's health banner, or press A on the save and pick **Check This Save**.
- **Save Manager > Backups:** Press X on a backup to check it before you restore it.
- **Load Screen:** Hold Y on Continue to check the save shown there. A tap of Y still edits the note.

The save you're playing can be checked but not fixed. Fix it from the title screen (the Load Screen's Save Manager). A backup can be checked, but not fixed: Restore it first.

## The Report Card

A verdict comes first, then six checks, each with its own line:

| Check | What it looks at |
|---|---|
| File | The file reads, and holds nothing the game hasn't got (a mod's objects with the mod gone) |
| Kanto Reloaded Data | Kanto Reloaded's parts are in the save, or its `.kr` copy can bring them back |
| Upgrades | Parts on an older version, and any whose upgrade failed (held, nothing lost) |
| Plain Values | Kanto Reloaded's data is plain values only, so the save loads without it |
| Missing Content | Pokémon, items, moves and abilities the game hasn't got now |
| Mod Data | Each mod with data in the save, and which ones it can't load without |

The verdict is **Healthy**, **Healthy, N Notes** (things worth a look), **N Problems** (something can stop the save working right) or **Damaged** (the file can't be read).

A on a check says more. Missing Content and Mod Data open pages of their own. **Fix Safely** (X) fixes what's missing; **Save the Report** writes the report to a file.

## Missing Content

These are Pokémon, items, moves and abilities a save holds that the game hasn't got now, because the Expanded Dex isn't loaded or a mod that added them is off or gone. They can be in the party, the boxes, the Day Care, the Bag, the PC's items, or held by a Pokémon. PIF shows a missing Pokémon as a Pikachu and a missing item as Unknown. A missing move can crash a battle, though, so a move is a problem and the rest are notes. A party member is marked in red.

Each one has a fix. A changes it:

- **Keep Aside** (recommended): Taken out of the save into Kanto Reloaded's part of it. When the game has it again, it comes back by itself the next time the save loads: a Pokémon to the PC, an item to the Bag, a move or an ability to its Pokémon. A message says what came back once the map shows.
- **Remove:** Gone for good. A held item, move or ability comes off its Pokémon. A Pokémon left with no moves learns the first move its species learns that the game has.

Fix All Safely (X) makes a backup named **Before Save Check** first. Something in another mod's data stays where it is, because its mod looks after it.

The Save Manager's health badge runs the quick part of this check on the party, the boxes, the Day Care and the Bag. It shows CHECK and the reason, and Continue still loads.

## Mod Data

Mod Data lists each mod with something in the save, its size, and one of two labels:

- **SAFE TO REMOVE:** Plain values only. The game reads them without the mod, so the data just waits in the save.
- **NEEDED TO LOAD:** The mod stores objects of its own classes, in its own save value or on the game's (an instance variable on your trainer). The game can't read those without it, so the save won't load at all if the mod is gone.

A shows what a mod keeps in the save: its save values, its objects and where they are, and what it added with Data Patches that the save holds (that becomes Missing Content without the mod).

A mod that's off or gone is found by searching the Mods folder for the code that registers its save value or defines its classes.

### Make It Loadable

When a mod the save needs isn't installed, Mod Data's first button is **Make It Loadable**:

1. A backup named **Before Make It Loadable** is made.
2. The mod's save values, and any of its objects inside the game's own values, are set aside. They're written to `Kanto Reloaded\Set Aside\<save> <time>.rxdata` exactly as the save held them, with a note of where each came from.
3. The save is written without them, safely, so it loads.

To have the mod's data back, reinstall the mod and restore the Before Make It Loadable backup.

### Inspector

With KIF's DEBUG option on, A on what a mod keeps opens the **Inspector**, a read-only tree of its save values: keys, classes and sizes. A class the game hasn't got is marked in red with a star.

## Reports

**Save the Report** writes `Logging\Save Checks\<save> <date time>.md` in the mod folder: the verdict, each check and its details, what's missing, and each mod's data. **Report Saved** then offers Open Folder and OK (on a phone, Copy the Path, which copies the report's full path). Bug Reports will attach a save's newest report (`Reloaded::SaveCheck.newest_report(slot)`).

## Upgrades

Kanto Reloaded's parts of a save (`Reloaded::SaveStore` sections) upgrade all or nothing, the way Hoenn Reloaded's Save Migrations do. Every part that needs it upgrades on a copy, and the save takes the results only when all of them worked. If one fails, none apply. Each of those parts' old data is held in the save with the version it was and why it failed, and the parts start empty. The held data is tried again each time the save loads, so a newer Kanto Reloaded can finish the upgrade. Nothing is lost.

## For Mod Makers

```text
ruby Tools/SaveChecker/save_check.rb "<KIF Beta>" "<save file>" [report.md]
```

This checks a save outside the game on KIF Beta's real data and prints the report. Every class in the save is stood in for while it's read, and its owner is found in the game's scripts and the Mods folder. Anything a script adds while the game runs (KIF's K-Eggs, items a mod's code makes) isn't in the data files, so outside the game it shows as Missing Content. The exit code is 0 for Healthy, 1 for problems.

To keep a save loadable without your mod, store plain values only (Hash, Array, String, Symbol, numbers, true, false, nil, Time) in your save value. Then Mod Data shows your mod as Safe to Remove.

```ruby
r = Reloaded::SaveCheck.run(path)           # the report: r.state, r.checks, r.missing, r.mods
Reloaded::SaveCheck.write_report(r)          # Logs\Save Checks\...
Reloaded::SaveCheckScreen.open(path)         # the screen
```

## How It Reads a Save

`SaveCheck::Reader` reads the file with Marshal, as the game does. When the save holds a class the game hasn't got, it makes a stand-in for the read (`SaveCheck::Stub`) and takes it away after. A stand-in keeps exactly what the save held, so anything written back out (Make It Loadable's side file, a fixed save) is written as it was read. Structs and user subclasses of String, Array and Hash can't be stood in for, and a save holding one is reported as one the checker can't open.

## Tests

```text
ruby Tools/Tests/save_check_test.rb "<KIF Beta>" <empty temp folder>
ruby Tools/Tests/save_check_preview.rb "<KIF Beta>" <work dir with metrics.json>
python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>
```

The first runs on KIF Beta's real data with saves written as PIF writes them. It covers:

- every check, and the quick check behind the badge
- Keep Aside, Remove, and Keep Aside's return
- a removed mod's objects, the reader's stand-ins, and Make It Loadable
- all-or-nothing upgrades, the report file, and the Tools script

The second drives the screens, including the ways in from the Save Manager and the Load Screen.
