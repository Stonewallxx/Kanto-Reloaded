# Difficulty

PIF's Easy, Normal and Hard, with Kanto Reloaded's rules, and the Run Tags that show a save's run. Always on with Kanto Reloaded: there's no switch. The code is in `Core/Difficulty/Difficulty.rb`; the question when lowering is in `Core/UI/DifficultyAsk.rb`, the Run Tags in `Core/UI/RunTags.rb`, and test copies in `Core/Saves/TestCopy.rb` and `Core/UI/TestCopyAsk.rb`.

## What Each Level Does

Everything a level changes is PIF's own code, which reads switches 665 (Easy) and 666 (Hard). Kanto Reloaded only sets the level through PIF's `setDifficulty`, and adds Hard's trainer IV floor.

| Level | What changes |
|---|---|
| Easy | The whole party gains EXP; no poison damage while walking; trainers use their easier movesets |
| Normal | The game as it's made |
| Hard | Trainer levels x1.1; the smartest trainer AI; trainers use their harder movesets; their next Pokémon stays hidden (Switch battle style); trainer IVs at least 10; level caps x1.1 |

PIF's own text says Hard trainers "have access to healing items". Nothing in the code does that, so Kanto Reloaded never says it.

## Shown As

Wherever the difficulty shows (the Load Screen, the Hall of Fame), it's **the lowest this save has used**: the lower of PIF's own `$Trainer.lowest_difficulty` and the level the switches say now. A switch an event flips is caught too.

- **Recorded at once:** `setDifficulty` from anywhere (the settings row, an event, another mod) lowers `lowest_difficulty` the moment the level drops. PIF and KIF only record it when Options closes.
- **Where it's kept:** in PIF's own field, so PIF's Load Screen and Hall of Fame agree, and it stays with Kanto Reloaded off. Kanto Reloaded's save data keeps only a short history (from, to, when, how) for Bug Reports.
- **A new game:** PIF's `Trainer.new` says Hard until its prompt sets the level, so nothing is recorded then.
- **At New Game,** New Game Setup's Difficulty row picks it (Choose a Difficulty shows What Changes for each). With Reloaded New Game Off, it's PIF's own prompt.

## Debug

Debug isn't a level but a **Run Tag of its own, purple**. A save is Debug when any of these is true:

- PIF's switch 842 (the Magic Boots);
- KIF's DEBUG option is on (it's saved in each save);
- Kanto Reloaded saw Debug on (Quality of Life's note);
- the save was saved without Kanto Reloaded (the seal: see [Foundation.md](Foundation.md), Save data);
- it's a test copy (see Test Copy below).

When Kanto Reloaded finds it (on load and on each save), it turns PIF's switch 842 on, so PIF's Hall of Fame and game mode say Debug too, even with Kanto Reloaded off.

## Run Tags

A save's run shows as a row of pills:

| Pill | What it says |
|---|---|
| The mode | CLASSIC, REMIX, EXPERT, SPECIES, RANDOMIZED or LEGENDARY, in the theme's plain pill. It's read as PIF reads it, each later one winning, so a randomized run says RANDOMIZED whatever it started as. |
| The difficulty | Shown As: EASY green, NORMAL blue, HARD red. |
| DEBUG | Purple, when the save is Debug. |

They show on the Load Screen (under the details, the health badge on the right) and in the Save Manager's details (on the right of the save's name). Settings' Shown As shows the difficulty's pill, with DEBUG beside it.

## Test Copy

A copy of a save to play with Kanto Reloaded off, to see whether a bug is Kanto Reloaded's. The save itself stays clean; the copy counts as Debug when it's loaded with Kanto Reloaded.

- **Where:** X on a save in the Save Manager (Active tab), or the Bug Report's **Test Copy** section (Copy picks the save, Make a Test Copy shows where the copy goes).
- **The question:** "Make a Test Copy?", the two saves as plates: the save (its tag's bar, trainer and location, STAYS CLEAN) and the copy (its slot, TEST, DEBUG WITH KR), then Make Copy or Cancel. After it, a toast: "Test Copy Made: File D" with a TEST pill.
- **The copy:** the save as it was last saved, in the first free File slot. It's marked in Kanto Reloaded's data in both places that data is kept, so the mark stays when the copy is saved with Kanto Reloaded off, and the game saves it to its own slot. With every File slot taken, none is made and it says so.
- **How it shows:** the Save Manager lists test copies last, under a purple TEST COPIES heading, with "Test Copy of File A" under the name (until a note is written), a TEST pill beside the name and a purple banner (Test Copy of File A, For Testing with Kanto Reloaded Off). On the Load Screen, a purple strip takes the note's place: TEST COPY OF FILE A · DEBUG IF LOADED HERE.

## The Settings

A Difficulty heading in the Kanto Reloaded section. The Difficulty row also takes PIF's place in KIF's Game > Difficulty (PIF's own row is dropped there), as Speech Frame does in Graphics > Text.

- **Difficulty:** Easy green, Normal blue, Hard red, in the row and in its dropdown (NOW on the current one). The description box explains each level as the dropdown moves. It has no Default, so X can't lower a run in one press.
- **Shown As:** read-only, its value a pill in its colour, DEBUG beside it on a Debug run. Its name is dimmed, it has no arrows, and Left, Right and A buzz.
- **Lowering asks first,** only when it would change Shown As: on Hard with Shown As already Normal, going to Normal doesn't ask. The question is a Header Plate popup: "Lower to Easy?", that the card keeps the lowest used, then "Your Card Shows: Normal, After: Easy" in their colours, with Lower and Keep (Keep is the default). Off the improved settings screen (KIF's own, the Overworld Menu), it's the game's own yes/no question.

## Hard's Trainer IVs

On Hard, each of a trainer's Pokémon's IVs is at least 10: a floor on PIF's own (half the Pokémon's level). IVs the trainer's data sets on purpose stay as they are, like the Expert trainers' deliberate 0s (Gentleman Nick's Trick Room team at Speed 0). There's no randomness, so the same trainer is the same every battle. Kanto Reloaded's hook on `GameData::Trainer#to_trainer` wraps KIF's own four (Endgame Challenge, Leader Teams, the Randomizer's trainers and items), so their Pokémon get the floor too.

## Bug Reports

Each report says the level now, the lowest, Shown As and Debug, any saves made without Kanto Reloaded, whether the save is a test copy (and of which save), and the last five changes.

## For Other Mods

```ruby
Reloaded::Difficulty.level          # 0 Easy, 1 Normal, 2 Hard (now)
Reloaded::Difficulty.shown          # the lowest used
Reloaded::Difficulty.shown_name     # "Normal"
Reloaded::Difficulty.hard_run?      # Shown As is Hard
Reloaded::Difficulty.debug?         # the Debug Run Tag
Reloaded::Difficulty.changes(2)     # what Hard changes, as words
Reloaded::SaveStore.test_copy       # a test copy: { "of" => "File A", "at" }, or nil
Reloaded::Saves.make_test_copy("File A")   # => "File D" (ArgumentError when it can't)
```

Events: `:difficulty_changed` (`:from`, `:to`) on every level change, and `:difficulty_lowered` (`:from`, `:to`) when Shown As drops.
