# Bug Reports

One file with everything needed to fix a bug, ready to send. This is Roadmap topic 37. The code is in `Core/BugReport`, and the screens are in `Core/UI/BugReportScreen.rb` and `Core/UI/Notice.rb`.

## Making One

Go to **KIF Settings > Kanto Reloaded > Bug Report > Make a Bug Report**. The screen has two sections:

- **What Happened:**
  - **Note:** Type straight in what you were doing and what went wrong. On a controller, A opens the naming screen.
  - **Screenshot:** Pick **This Screen**, **Last Screenshot** or **None**. This Screen is the screen as it was when you opened the Pause Menu (the map behind it), or when KIF Settings opened from the title. Last Screenshot is your newest screenshot.
- **What's in It:** Each part is ticked off:
  - Logs, Settings, Mods, Hooks, Save Check and Recent Steps
  - **Errors**: the errors this session that didn't close the game (A lists them)
  - **Include the Save**: off by default; pick a save to add a copy of it, so the bug can be played again

**Make Report** (Y, or the box at the top right) saves the file and shows **Report Made**. That says where the file is and how big it is, with **Open the Folder**, **Open Discord** (Kanto Reloaded's bug reports channel) and **Done**. On a phone they're **Copy the Path** and **Copy the Link**, which put the report's full path or Discord's link on the clipboard and say **Copied**.

## What's in the File

`KR Bug Report <date> <time>.zip` goes in the mod's `Bug Reports` folder (`Mods\KantoReloaded\Bug Reports`):

| File | What it is |
|---|---|
| `Report.md` | Your note, the versions, the crash (if there was one), this session's errors and Recent Steps |
| `logs/` | Kanto Reloaded's log and the one before it, KIF's session log (and the one before), its error log, and PIF's errorlog (each cut to its last 512 KB) |
| `settings/` | Kanto Reloaded's settings, controls, layouts and features, and KIF Beta's settings (changed ones marked) |
| `mods.md` | Every mod: on or off, loaded or not (and why), its version and author, and the Data Patches load order |
| `hooks.md` | Kanto Reloaded's hooks, and any other code on the same methods |
| `save-check.md` | The [Save Checker](SaveChecker.md)'s report on the current save |
| `screenshot.png` | The screenshot you picked |
| `save/<slot>.rxdata` | Only with Include the Save |

Your Windows user name is taken out of every text file. Your home folder becomes `%USERPROFILE%`, and any folder named after you becomes `USERNAME`.

## Recent Steps

Kanto Reloaded keeps the last 100 things that happened, in memory only:

- map changes
- battles (who you fought and how it ended)
- menus opened (Kanto Reloaded's own Party Screen and Bag too)
- saves, loads and new games
- the title screen
- errors

They go into `Report.md` as a timeline. Nothing about it shows while you play.

## After a Crash

When the game crashes, PIF and KIF log the error as they always do, and Kanto Reloaded shows **Something Went Wrong** before the game closes:

- The title names the mod the failing code is in: "Something Went Wrong in Hard Trainers+", or "in Kanto Reloaded". Errors in the game's own code name no one.
- Under the title are the error and where it happened. The notice also says your last save is safe.
- **Make a Bug Report** saves the report with a screenshot of that moment, then shows Report Made.
- **Close the Game** closes the game.

A crash in a mod's code goes to that mod's maker. Report Made names the mod and its author, and **Open Their Page** opens the link in its `mod.json` `"support"`, if it has one. Everything else goes to Kanto Reloaded's Discord.

If anything of Kanto Reloaded's fails while it's showing, PIF's own message box shows instead, as it always did.

### The Next Start

If the last session crashed and no report was made, or the game was closed without warning (killed, or a crash too hard to catch), the next start shows **The Game Closed Unexpectedly** once, over the Load Screen. It says where you were ("during a battle on Route 24") and offers **Make a Bug Report** or **Not Now**. The report has that session's logs (the "before" logs).

## For Mod Makers

Add a `"support"` link to your `mod.json`, and crashes in your code send players there:

```json
{ "name": "Hard Trainers+", "author": "Ash", "support": "https://example.com/hard-trainers" }
```

```ruby
Reloaded::BugReport::Trail.add(:note, "Hard Trainers+: rematch started")   # a step of your own
Reloaded::BugReportScreen.open                                            # the screen
```

The Discord link is `Reloaded::BugReport::DISCORD_URL`. It's a channel link, which opens only for members of the server; an invite link (discord.gg/...) would reach everyone.

## Tests

```text
ruby Tools/Tests/bug_report_test.rb "<KIF Beta>" <empty temp folder>
ruby Tools/Tests/bug_report_preview.rb "<KIF Beta>" <work dir with metrics.json>
python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>
```

The first covers:

- Recent Steps, on stand-in battles and maps hooked as in the game
- this session's errors
- the zip, read back with every file's CRC checked, and what's in it
- the user name taken out
- the mod's Bug Reports folder
- the old files moved over from the save folder, the newer one kept
- naming the mod a crash came from
- the crash path, with PIF's box when ours can't show
- the next start's offer

The second drives the screen and the notices.
