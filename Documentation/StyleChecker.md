# Style Checker

The Style Checker reads a mod's player-facing text and checks it against Kanto Reloaded's house rules. It ships with Kanto Reloaded in `Tools/StyleCheck`, so you can check your own mod too. The Release Builder runs it on Kanto Reloaded before every release.

## Running It

```
ruby Tools/StyleCheck/style_check.rb [<mod folder>] [--fix] [--out <folder>]
```

- **Mod folder:** the mod to check. Without one, it checks Kanto Reloaded itself.
- **--fix:** Fix It for Me (below).
- **--out:** where the report and backups go. Without it, Kanto Reloaded's Logging folder (`Mods\KantoReloaded\Logging`).

It writes `Style Check <mod name>.md` there and prints how many problems it found. It exits with 0 when there's nothing to fix, 1 when there is, and 2 for a mistake in the command.

## What It Reads

Player-facing text in the mod's Ruby files:

- `_INTL("...")` text.
- `:name`, `:description`, `:values` and the like, in settings, pages, features and actions.
- Text in data tables, such as an action's name and description in an array: any string that starts with a capital, has no `#{...}` and isn't a file path.

Lines that log, raise or print are left out, and so are the `Tools`, `Dev` and `Tests` folders.

A label is a setting's name, a choice, or short `_INTL` text of one to five words with no sentence punctuation. Short pieces of a sentence that code joins together start in lowercase, so they aren't labels.

## The Rules

| Rule | What it asks for | Fix |
|---|---|---|
| Capital After a Colon | A capital letter right after a colon | Automatic |
| Title Case Labels | Labels in Title Case; connecting words (a, an, and, as, at, but, by, for, in, nor, of, on, or, the, to, vs, with) lowercase unless first | Automatic |
| Spelling: Color | Color, as the setting names say it | Automatic |
| Official Names | Speed-Up, Pokédex, Pokémon, Poké Ball, Wild Link and Kanto Reloaded as written | Automatic |
| No Double Spaces | One space between words | Automatic |
| Labels Without a Period | A label doesn't end in a period | Automatic |
| No Keyboard-Only Hints | No "Press Enter" or "Esc key": name the action instead | By hand |

## The Report

The report is Markdown with real headings. It starts with a table of how many each rule found, then lists each rule's findings with the file and line, the text, and the fix. The last section lists what's on the Ignore List.

## Fix It for Me

With `--fix`, each fix comes in turn: the rule, the file and line, the text before (red) and after (green). Then:

- **Y:** Fix it.
- **N:** Skip it. It shows again next time.
- **I:** Ignore it from now on (the Ignore List).
- **A:** Fix every remaining finding of this rule without asking.
- **Q:** Stop. The rest shows again next time.

Before a file changes, it's copied as it was to `Logs\Style Fixes <date and time>\`. At the end you see what was fixed, skipped and ignored, which files changed, and where the backup is. Findings that need fixing by hand are counted at the start and listed in the report.

## The Ignore List

A false positive, such as the button letter A in "Swap A and B", is marked once with I and stops showing. The list lives in the mod's `style_check.json`, which can also add official names of your own:

```json
{
  "ignore": [{ "rule": "title_case", "file": "Core/Controls/Controls.rb", "text": "Swap A and B" }],
  "names": { "Pokégear": ["Pokegear", "PokeGear"] }
}
```

An ignored finding matches by rule and text (and file, when one is given), so it stays ignored when its line moves.
