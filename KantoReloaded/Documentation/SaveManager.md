# Save Manager

Save Manager is a Kanto Reloaded utility for moving save slots into a
recoverable archive instead of deleting them immediately.

## Access

- Open `Kanto Reloaded > Developer / Utility > Save Manager`.
- On the title screen, select a Continue save and press `Special` to open Save
  Manager focused on that slot.

The currently loaded save cannot be archived while playing. Other saves can be
managed normally.

## Archives

Archived saves are stored beneath `DELETED SAVES` in KIF's save-data folder.
Each new archive uses its own timestamped directory and manifest. The main save,
its `.bak` file, and slot-named backups move together. Generic `Backup000`
conversion backups are not attributed to a slot and are not moved with it.

Save Manager also recognizes loose files created by the retired Save Delete mod.

Restore is blocked if an active file with the same name already exists. Archive
that active slot first instead of overwriting it. File moves are rolled back when
an operation fails partway through.

Permanent deletion requires two confirmations. `Empty Deleted` permanently
removes every recognized archive and cannot be undone.

Windows and Proton can open the archive folder directly. On platforms without
folder-launch support, Save Manager displays the normalized folder path instead.
