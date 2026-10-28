# Saves

Kanto Reloaded looks after your save files: the Save Manager, a rebuilt Load Screen with What's New, safe saving, and a Backup Cap. Roadmap topic 1; the code is in `Core/Saves` and the screens in `Core/UI` (`SaveManagerScreen.rb`, `LoadScreen.rb`, `WhatsNewScreen.rb`).

## Safe Saving

PIF writes a save straight over the old one, so a crash or a full disk halfway through leaves a cut-off file. Kanto Reloaded saves like this instead:

1. The save is written to `<save>.reloaded.tmp` and flushed to the disk.
2. That file is read back: It must be a whole save.
3. The old save becomes `<save>.reloaded.previous`, the new one takes its name, and the old one is deleted. Any failure puts the old one back.

If a save fails its check, the game says the save failed and the old save is still there. If the game stopped between those steps, the next start puts things right before anything reads the saves: A missing save comes back from `.previous` (or from a `.tmp` that reads whole), and leftovers are cleared.

## The Save Manager

**Kanto Reloaded > Saves > Save Manager**, or the Load Screen's **Save Manager** row. Three tabs, switched with LB and RB (L and R):

| Tab | Left | Right |
|---|---|---|
| Active | Your save files: Color tag, note, health badge | Trainer, location, saved, play time, party, Notes (Y edits), a status banner |
| Backups | The selected save's backups, newest first; named ones in gold, autosaves marked | The backup's details and health; A restores it, Y names it. Left / Right: another save's backups |
| Deleted | The saves you've deleted | Their details; A restores one (to its slot, or the first free one) or deletes it forever |

On Active, A opens Edit Note, Color Tag, Check This Save (the [Save Checker](SaveChecker.md)), Backups, Back Up Now (a backup named so it's always kept), Delete (to the Deleted tab, with its backups) and Open Folder (on a phone, Copy the Path, which copies the saves folder's full path). A click on the health banner opens the Save Checker too, and on the Backups tab X checks the selected backup.

On Active, X makes a **Test Copy**: a copy of the save to play with Kanto Reloaded off (see [Difficulty.md](Difficulty.md), Test Copy). Test copies are listed last, under a TEST COPIES heading. The details' head shows the save's name and its Run Tags (mode, difficulty, DEBUG); the color tag is the bar beside the name.

The save you're playing (in the game, not at the title screen) can't be deleted or restored over: Do that from the title screen.

### Health

Each save and backup is checked by reading it as the game would, without loading it:

| Badge | Meaning |
|---|---|
| HEALTHY | It reads as a save the game can load. |
| CHECK | It reads, but it uses something the game hasn't got (a mod that's off or gone, maybe), its parts aren't what the game expects, it's from an older version (it updates when it's loaded), or it has Pokémon, items or moves the game hasn't got (the Save Checker's quick part, on the party, the boxes, the Day Care and the Bag). |
| DAMAGED | It's empty, cut short or garbled. The Save Manager and the Load Screen offer its newest backup that reads whole. |

### Backups

KIF Beta makes the backups: a copy of the save before each save, in `backups\<save>\` in the save folder, named `<save>_<time>.rxdata` (`_autosave` for autosaves, `_<name>` for named ones). Restoring one keeps the save as it was first, as a backup named Before Restore.

**Packed backups:** Since KIF 1.2, KIF packs its new backups (gzip, about a tenth of the size) under the same names; older ones stay plain until its save menu's Compress Old Backups. The Save Manager, the Load Screen and the Save Checker read either kind (`Core/Saves/SaveFile.rb`). A restored backup is written unpacked, so a save the game plays from is always plain, and Kanto Reloaded's own backups (Back Up Now, Before Restore) are packed the same way when KIF packs.

**Backup Cap** (Kanto Reloaded > Saves) decides how many are kept: Unlimited (the default), or the newest 10, 15, 20, 25, 50 or 100 plain backups of each save. Older plain backups go to the Windows Recycle Bin, where a player can still get one back; when the bin can't be used, they're kept. Named backups are always kept, and KIF keeps its newest 10 autosave backups. It takes over KIF Beta's own Save Backups setting, which Kanto Reloaded locks to Infinite.

Nothing in the Save Manager deletes or writes over a file it didn't make. Restoring from the Deleted tab checks every file's new place first and stops before anything moves when one is taken; a restore or delete that fails partway puts the files back and leaves the folder rather than removing it; Delete Forever only removes a folder inside DELETED SAVES, after its question; two backups in one second take the next free second; and after a crash, a whole save left over (or the save from before it) is kept as a named backup, Unfinished Save or Before Crash.

### Deleted Saves

Deleting moves the save, its backups and Kanto Reloaded's copy of its data to `DELETED SAVES\<save>-<time>\` in the save folder, with a `manifest.json` (old Kanto Reloaded's, plus the note, the tag and a few details). Saves deleted with old Kanto Reloaded's Save Manager show there too. Restoring a save whose slot is taken brings it back as the first free File slot, its backups renamed with it.

### Notes and Color Tags

A save's note and color tag are kept in `Kanto Reloaded\Save Notes.json`, by slot, with the save's player id: A new save in the same slot doesn't take them over. Deleting a save takes them with it, and restoring brings them back.

## The Load Screen

**Startup Mod-Check** (Reloaded Systems, On by default): As the load screen starts, KIF Beta looks for a newer KIF and (0.21.68+) for updates to your mods (see The Startup Checks below). Off skips both, so nothing comes up; Options > System > Check for Updates and Mods > Updates still check when you use them.

**The Load Screen** (always on with Kanto Reloaded) rebuilds PIF's load screen:

- **Continue:** The save's trainer (its outfit, standing on the left), note, badges, play time, Pokédex, backups, money, its Run Tags (mode, difficulty and DEBUG: see [Difficulty.md](Difficulty.md)), health and party, in the Save Manager's colors (play time gold, money green). A test copy shows a purple strip in its note's place. Left / Right switch save file.
- **Rows:** New Game, What's New (NEW until read), Mystery Gift, Options, Save Manager, KIF Beta's links, Quit. The list scrolls like PIF's.
- **The top:** Kanto Reloaded's and KIF Beta's versions, centred above the Continue panel in charcoal.
- **On Continue:** Y edits the note, holding Y opens the [Save Checker](SaveChecker.md); holding A lists the save's backups to go back to; a damaged save offers its newest good backup.

PIF's own menu still runs it, so KIF Beta's updater, imports and first-run questions all still happen; only the drawing is Kanto Reloaded's. Savefile management is left out: the Save Manager and holding A do it, and more. Off: The game's own load screen.

### The Startup Checks

As the load screen starts, KIF Beta checks for a newer KIF and, every 12 hours, for updates to your mods, while Startup Mod-Check is On. They run and finish before you can choose anything. They wait for the load screen to fade in and run over it, instead of on a black screen before it, and they look like Kanto Reloaded's (`Core/Saves/UpdateChecks.rb`, `Core/UI/UpdateChecksScreen.rb`):

- **Checking for Updates...** is Kanto Reloaded's toast at the top (a Poké Ball; his ask, 2026-10-23, design 1 Then Up to Date: the popup came and went at once when the checks were quick). It stays while they run (the game waits on them), then says **Everything's Up to Date** with KIF's version in a green pill, and fades after about two and a half seconds while you use the menu; it goes at once when you load a save or start a new game. When KIF gets no answer it says Couldn't Check for Updates (or Couldn't Check Your Mods); with KIF's own updates Off and the mods checked, Your Mods Are Up to Date. A question (a new KIF, mod updates) takes over from it, and no toast comes after; on the very first start, KIF's first-start questions do. With Updates Off (Options > System) and the mods not due, nothing runs and nothing shows.
- **A new KIF** (design 2, Choice List): the versions (you have, new), then Update Now, What's New, Later and Skip This Version, and what the highlighted one does. B is Later. What's New shows KIF's notes, then comes back to the list.
- **Mod updates** (design 2, Update All): each mod with its versions (old to new), then Update All (KIF's own installer, from the popup; they work from the next start), Open Updates (Mods > Updates, as KIF's Yes) and Later. B is Later.
- **KIF's other waits** (its update download, installing mods, Mods > Browse) are a popup with KIF's title, what it's on, a gold bar, and B to cancel where KIF lets you. KIF's messages and questions along the way are Reloaded's popups.

It's all KIF's own code, hooked: the checks, their answers and what they do are unchanged, and a question of KIF's this doesn't know stays KIF's. KIF's first-start questions come after them, over the load screen too.

## What's New

The Load Screen's **What's New** row: Each source on the left (Kanto Reloaded, KIF Beta, mods with notes), the Versions box under them (version numbers only, a gold dot on NEW ones), and the selected version on the right. A version is NEW until the screen has shown it; the first time a source is seen, only its newest version is.

- **The Card:** `UPDATE #N` (or `VERSION 1.2.0` without an Update line) at the top left and the date at the top right, the version's name under them, then its pills: Version (blue), Works On (green), Hotfix (amber) and NEW (gold, at the end).
- **The Notes:** Drawn as their Markdown has them, in any format. The version's top heading level is its sub-sections, each in its colour (Added green, Changed blue, Fixed amber, Removed red, Supported Mods purple, Known Issues pink, Before You Update gold; any other name in the heading blue). The next level down are headers under them, in the same colour and underlined, each level one step in. Dotted lines in the heading's colour join a sub-section to its headers.
- **In a Line:** Bold is drawn bold, italics pink, `code` amber. Bullets, numbered lines, quotes, divider lines and tables show too.
- **Never Shown, for Safety:** Web addresses. A link shows only its words, as plain text; bare addresses (`https://...`, `www....`, `discord.gg/...`), images, link lines (`[1]: https://...`) and HTML tags are left out.
- **A Mod's Icon:** A mod registered with `Reloaded::ModIcons` shows its own Poké Ball in place of the letter tile (Ghostly Possession: purple, with the possessed Outline).

- **Kanto Reloaded:** Its released changelogs, in its `Documentation\Changelogs` folder.
- **KIF Beta:** `Data\KIF\update_notes.txt` holds only the current version's notes, so each one is kept as it arrives (`Settings\Whats New.json` in the mod folder), and older versions stay after KIF updates.
- **A mod:** Its `Documentation\Changelogs` folder, or a `Changelogs` folder at its root (with both, `Documentation\Changelogs` is read). Each `vX.Y.Z.md` is one version, in this form:

```markdown
# My Mod
## Update #2 - Lights Out
- **Version:** v1.1.0
- **Release Date:** November 14, 2026
- **Works On:** KIF 1.2.2+
## Added
### Town Lights
- Lighthouses sweep a beam over the sea at night.
  - A line under it.
## Fixed
### Team Possession
- A Ghost is no longer lost when you reload.
```

- **What's Read:** Its Update line (number, name and a hotfix label like `(Hotfix 1)`), Release Date, Works On and sub-sections. A file missing some of it still shows what it has, and a file that can't be read is skipped.
- **Never Shown:** A version whose Release Date is `Unreleased`, an `Unreleased.md`, any other file, and the mod's `Dev` folder.
- **One File:** A mod with no Changelogs folder is read from a single `Changelog.md` in its folder, split at its version headings: `## 1.2.0 (2026-10-20)`, Keep a Changelog's `## [1.2.0] - 2026-10-20` (its `[Unreleased]` left out), `## v2.1 - Faster Pedals` (the words after the version are its name) or `## Version 1.2`:

```markdown
# My Mod

## 1.2.0 (2026-10-20)
### Added
- **Gym Leaders:** Harder teams.
  - a note under it
- Rematches with every leader
```

Or from its scripts:

```ruby
Reloaded::WhatsNew.add("My Mod", "1.2.0", ["Gym leaders: Harder teams", "Rematches"], "2026-10-20")
```

### Party Icons

The Load Screen and the Save Manager show a party with the game's own icons, in one centred row (`Core/UI/PartyIcons.rb`). With KIF Beta's **Big Pokémon Icons** on, the battle-sprite icons are scaled to the small icons' size, so a full party always fits, and they're centred like the small ones (KIF's 16 px shift for the party screen is left out). The icons and the trainer stay under popups.

## For Code

```ruby
Reloaded::Saves.slots                     # ["File A", "File C"]
Reloaded::Saves.preview(path)             # { :name, :map, :seconds, :party, :health, :problem, ... }
Reloaded::Saves.backups("File A")         # newest first: [{ :path, :time, :name, :auto }]
Reloaded::Saves.note("File A")            # and set_note, tag, set_tag
Reloaded::SaveManagerScreen.open          # the Save Manager
Reloaded::WhatsNewScreen.open             # What's New
Reloaded::WhatsNew.blocks(lines)          # Markdown lines => [Block] (kind, level, depth, number, segments)
Reloaded::ModIcons.register("My Mod", :ids => ["MyMod"], :ball => [r, g, b], :outline => [r, g, b])
Reloaded::ModIcons.draw(bitmap, x, y, Reloaded::ModIcons.for("My Mod"))   # its ball, 15 px
```

Previews read the whole save (PIF has no small header) with PIF's raw reader, which nothing hooks and which never rewrites the file. They're kept until the file changes, and the light part of each (no party) is kept in `Kanto Reloaded\Save Previews.json`, so lists fill in at once.
