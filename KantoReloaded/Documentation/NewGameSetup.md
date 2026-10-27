# New Game Setup

A new game's choices in one screen, before Professor Oak's talk: the game mode, your trainer, the run's rules, and a Run Card to check it all before you start. It takes the place of KIF's game mode menu in the intro, and the intro's later questions (the Trainer Application Form, the difficulty, the starter set, the first save) aren't asked again. The code is in `Core/NewGame/NewGameSetup.rb` and `Core/UI` (`NewGameScreen.rb`, `NewGamePopups.rb`).

## The Switch

**Reloaded New Game** (Kanto Reloaded > Core > Reloaded Systems, On by default). Off gives back the game's own questions.

## The Steps

Four steps on a strip along the top. **L1** and **R1** move between them (a click on one jumps there), and the done ones are ticked.

- **Game Mode:** Classic, Remix, Randomized and Legendary, each on its card. The mode follows the cursor, and its words show under the cards. Legendary shows locked until New Game+ (beat the League on a save first). **From a Preset** and **Share Code** are under the cards. A goes on to Trainer; B asks **Back to the Title?** (Stay is first).
- **Trainer:** The Trainer Application Form beside your trainer, who stands on Oak's platform and changes as you choose. **Name** is typed straight in (a controller's A opens the naming screen); left empty, you're Red or Green. **Gender**, **Age** (10 to 17), **Skin** and **Hair** change with Left and Right; on Hair your trainer's hat comes off, and its four colours show under it.
- **Run Setup:** The run's rules beside Oak, a row each. Left and Right change a row; A opens one that has more. The starter set's three Pokémon show under the rows, and the highlighted row's words at the bottom.
- **Run Card:** The run in short beside your trainer: its pills (the mode, Easy or Hard), your trainer, the seed, the starters, the money, Autosave, and its **Run ID**. **Start** begins your journey; **Save as Preset** keeps it. **Square** copies its share code.

## Run Setup's Rows

| Row | What It Does |
|---|---|
| **Difficulty** | Easy, Normal or Hard, each in its colour. A opens **Choose a Difficulty**: the three levels beside Oak and What Changes for each. Change it any time later in Kanto Reloaded's settings. |
| **Randomizer** | In Randomized Mode, with the Reloaded Randomizer on. A opens the Randomizer beside Oak (the seed and every part), with **Done** and **Back**. The run is randomized once, at Start. |
| **IV Boundaries** | With IV Boundaries on: a preset for new Pokémon's IVs (Vanilla, Accessibility, Strong, Perfect-ish, Perfect or Challenge), for wild Pokémon, Eggs and gifts alike. On Hard, floors stay at 0. |
| **Starters** | The three Pokémon Oak offers: Kanto, Johto, Hoenn, Sinnoh, Kalos, Mixed (a Grass, a Fire and a Water starter from any generation, rolled once and shown) or Custom (any Pokémon you pick, fused or not, in the **Custom Starter** popup). Every player gets the sets, on a first game too. Locked, with why, in Legendary Mode and while Random Starters are on in the Randomizer. |
| **Starting Money** | $3,000 to start, in steps of $1,000 up to $100,000. A opens a picker (Up and Down in steps of $10,000). |
| **Autosave** | On: the game saves when you heal, and the save screen opens once, where the game would have asked about Autosave. Off: you save when you want to. Change it later in KIF Settings. |
| **All Per-Save Settings** | KIF Settings with only this save's settings (Nuzlocke, Level Cap, Kanto Reloaded's per-save ones...), to set before you start. KIF's Modules aren't there (they're for every save), and neither is Difficulty (it has its own row). |

## Presets

**From a Preset** lists the built-in presets, then your own:

- **Classic:** Normal, nothing changed.
- **Challenge:** Hard, Nuzlocke, Level Cap Normal.
- **Casual:** Easy, Autosave On, $10,000.
- **Randomizer Run:** Randomized (the Randomizer's First Randomizer), Hard. Only with the Reloaded Randomizer on.

Your own show **YOURS** with their mode's pill under it. **Square** deletes one of yours (it asks first). When you've already set something up, a preset asks **Replace Your Setup?** with each change, old to new (Keep Mine is first).

**Save as Preset** (on the Run Card) asks for a name and keeps the run in KIF's preset slots, beside your per-save settings, so it shows under From a Preset in any new game. KIF's own Presets in KIF Settings load its settings as always.

## Share Codes and Run IDs

A share code holds the run, not you: the mode, the rows you changed, the Custom starter, the Randomizer's settings code, and the per-save settings you changed. No name, no look, nothing for every save. It starts `KRN1:`.

- **Run ID:** A short name for the run (like `57DA-A91F`), on the Run Card. The same run always has the same Run ID, so two players can check they're playing the same game.
- **Copy:** Square on the Run Card.
- **Share Code** (on Game Mode) opens **Enter a Share Code** with a copied code already pasted in: its Run ID and what it sets. **Triangle** pastes, A on the field types one (a controller's A opens the naming screen). **Use This Run** puts it in place of your setup (asking first if you'd set something up); rows and settings it doesn't name go back to their defaults, so the run is the same.
- A code from a newer Kanto Reloaded says so instead.

## Your Save

The run is kept in your save (its mode, rows, Run ID and code), even with Kanto Reloaded off.

## For Other Mods

A feature can add its own row to Run Setup:

```ruby
Reloaded::NewGameSetup.register_row(:my_rule, :name => "My Rule", :priority => 45,
  :kind => :choice, :values => ["Off", "On"], :default => 0,
  :descriptions => ["The game as it is.", "My rule's change."],
  :apply => proc { |value, plan| ... },                       # at Start
  :card => proc { |value, plan| ["My Rule", value == 1 ? "On" : "Off"] })
```

Kinds: `:choice` (Left and Right through `:values`), `:number` (`:min`, `:max`, `:step`; A opens a picker), `:open` and `:setup` (A runs `:press`, given the screen). `:visible` and `:lock` (a proc given the plan: false, or a reason) hide or lock it; `:tone` colours its value; `:tag` adds a pill to the Run Card; `:code => false` leaves it out of share codes and presets.

```ruby
Reloaded::NewGameSetup.run         # this save's run (mode, rows, run_id, code), or nil
```

Event: `:new_game_setup_done` (`:run`) after Start.
