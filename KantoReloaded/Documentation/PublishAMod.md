# Publish a Mod

KIF Beta's **Publish a mod** (Options > Mods > Installed > For Modders) in one screen instead of a run of message boxes. It sends one of your mods to the community catalog through your own GitHub account. Everything KIF's version says is still there, and KIF's own code still does the work: it reads and writes your mod's `mod.json`, runs the catalog's check, writes the pull request, and opens the window that signs you in to GitHub and uploads the mod.

It's always on with Kanto Reloaded, on a computer (a phone can't publish). If a KIF update ever changes its Publish a mod, Kanto Reloaded's screen steps aside and KIF's own runs until Kanto Reloaded is updated for it.

## The Steps

Four steps on a strip under the title. **L1** and **R1** move between them (a click on one jumps there), and the done ones are ticked. **Y** opens the mod's folder, and **B** leaves: everything is saved as you go.

- **Mod:** Your mods in `Mods` and in `ModDev` next to the game, one row each: its own Poké Ball or letter tile, its name and folder, and a pill. **NEW** means it isn't in the catalog yet. **UPDATE 1.0.0 TO 1.0.1** means it is, with an older version. **RAISE FROM 2.0.0** means the catalog already has this version, so it needs raising first. A mod whose `mod.json` can't be read says **CAN'T READ** and goes no further: Fix it in a text editor first. The description box shows the mod's description.
- **Details:** The mod's `mod.json`, saved the moment you change it.
  - **ID** shows only when it's not allowed (a-z, 0-9, _ and -). It never changes once published.
  - **Name** and **Author** are typed in their row.
  - **Version:** Left and Right raise it a step (patch, minor, major) and back; A types one, like 1.0 or 1.2.3.
  - **Description** is typed in a box of a few lines (one or two lines is plenty).
  - **Tags:** A opens the catalog's 12 tags (Mod Manager 2.0's) in two columns of tick boxes. A tag your `mod.json` had that isn't one of them stays.
  - A row the catalog's check has a problem with is marked red, and the description box says what's wrong.
- **Check:** The catalog's own check, on the folder as it would be uploaded, run again a moment after each change. **Problems** (red) must be fixed before the mod can be published; A on one about a detail goes to its row, and the rest need fixing in the folder. **Things to look at** (amber) don't stop it: the reviewer reads them closely, so say why the mod needs them in your notes. Everything it finds is in `Logs/KIF_log.txt` too. A long one's words scroll in the description box: by themselves, or with the right stick or the mouse wheel over the box.
- **Publish:** The pull request's questions, remembered for each mod:
  - **Permission:** Did you make this mod, or do you have its author's permission to share it (credited in `mod.json`)? Without it, the mod can't be published.
  - **Tested in KIF:** Did you test it in KIF (it loads, a battle works, the game saves and loads)?
  - **Reviewer Notes** (optional), typed in a box.
  - **Pull Request:** The pull request as the reviewer will see it: its title, the mod, the checklist, your notes and the check's things to look at. Up and Down scroll.
  - **Publish:** Locked while there are problems (Fix the Problems First) or Permission is No (Permission Needed).

## Your Release Copies: the ModDev Folder

A mod you work on in `Mods` often has things that shouldn't be shared: dev tools, notes, logs. If you keep a copy of it with only the files you share (a GitHub folder, say), put it in the **ModDev Folder**, and Publish a Mod uses that copy.

- **The ModDev Folder** is `ModDev` in KIF's own folder (made when it isn't there), unless you set another: KIF Settings > Mods > For Modders > **ModDev Folder**, right under Publish a mod. A types the folder in the title bar (Ctrl+V pastes one); empty goes back to KIF's ModDev. Its chip shows the folder's name.
- **A copy is found by its ID:** a folder there whose `mod.json` has the mod's ID (capitals, _ and - aside) is that mod's copy, whatever the folder is called. It can be a folder down too: a repo with its README at the top and the mod in a folder of its own.
- **MODDEV:** A mod with a copy says so in Step 1 and on each step. Its details come from the copy, its check runs on the copy, and the copy is what's uploaded. Details you change are saved to both copies, so they stay the same. **Folder** opens the copy.
- A copy in KIF's own `ModDev` isn't listed twice: its row in `Mods` (with MODDEV) is the one.

## Publishing

Publish asks first: **Publish Ghostly Possession 1.0.1?** A window opens that signs you in to GitHub in your browser (the first time) and uploads the mod; the game stays open. It shows the update (old > new), the folder and the catalog it goes to.

Then one of these:

- **Publish Window Open** (green): Follow the window's steps; it may ask to install Git or the GitHub CLI first. Catalog contributors publish straight away, and players get the mod at their next catalog check. Everyone else gets a pull request, which opens in the browser; it's checked and reviewed before the mod goes live.
- **Run It Yourself** (amber): Open a terminal and run the command saved in `Cache/Publish/command.txt` (in the game folder). **Open Folder** opens it.
- **The Window Didn't Open** (red): See `Logs/KIF_log.txt`. The script is `Tools/publish_mod` in the game folder; **Open Folder** opens it.

## When Something Goes Wrong

- **No mods:** Step 1 says No mod folders found in Mods or ModDev.
- **mod.json not saved:** A red note at the top says mod.json couldn't be saved (see Logs/KIF_log.txt).
