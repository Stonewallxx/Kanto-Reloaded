# Healing Moves

Your Pokémon's healing moves work outside battle, with real PP. This is Roadmap topic healing-overworld (Healer List), the old Kanto Reloaded's Healing Overworld Moves rebuilt in Reloaded's plate look. The code is in `Core/HealingMoves/HealingMoves.rb` (the moves, what each does, the plan, the hooks) and `Core/UI/HealingMovesScreen.rb` (the screens).

**Healing Moves** in Kanto Reloaded > Features switches it, On to start. Off gives back the game's own field moves (and its own Soft-Boiled and Milk Drink).

## Where It Shows

- **The Overworld Menu:** Heal with Moves, an action on Main, shown while someone in the party knows a healing move.
- **The party menu:** A Pokémon's healing moves show among its field moves (blue on Kanto Reloaded's Party Screen). Picked there, the move is used right there and the party screen stays open; the party screen picks the target, as it does for items.

## The Moves

| Move | What it does |
|---|---|
| Recover, Roost, Slack Off, Shore Up, Heal Order, Synthesis | Heals itself by half its max HP |
| Morning Sun, Moonlight | Heals itself by half, or the game's own Wait Until Morning (or Night), outdoors only |
| Soft-Boiled, Milk Drink | 1 PP and a fifth of the user's max HP, given to another Pokémon |
| Heal Pulse, Pollen Puff | Heals another Pokémon by half its max HP |
| Floral Healing | Heals any Pokémon (itself too) by half its max HP |
| Wish | Heals any Pokémon by half the user's max HP |
| Purify | Cures another Pokémon's status; the user heals by half |
| Life Dew | A quarter of each one's max HP, for the party |
| Lunar Blessing, Jungle Healing | A quarter for the party, and cures their status |
| Heal Bell, Aromatherapy | Cures the party's status |
| Revival Blessing | Revives a fainted Pokémon to half its HP |
| Healing Wish, Lunar Dance | The user faints to fully heal another (Lunar Dance: its PP too) |
| Rest | Full HP, its status cured, then it falls asleep |
| Refresh | Cures its own burn, poison or paralysis |
| Aqua Ring | A sixteenth of its max HP (a Big Root gives more) |

Each use costs 1 PP. A move that can't do anything now is dimmed and says why: No PP Left, Full HP, Nothing to Cure, No One to Heal, No One to Revive, Not Enough HP (Soft-Boiled), Fainted.

## Using One

From Heal with Moves: pick a move, then (for one that heals another) the Pokémon in **Pick a Pokémon**, where each row says what the move would do for it. The **Heal Preview** (Before and After) then shows each Pokémon it changes before and after (a gain as a paler stretch of the HP bar, a loss in pale red), the PP, and what it costs; Use or Back. After it's used, a toast says what happened ("Pikachu regained 55 HP", with the uses left), and the list shows the party as it is now.

Morning Sun and Moonlight ask first: **Heal Itself** (the HP and PP) or **Wait Until Morning / Night** (the game's own, outdoors only).

## Heal Everyone

The list's first row works out a plan: each step the move that does the most good (a Pokémon's HP as a share of its max, a cured status, a revive), until none would do 5% of a Pokémon's HP, so no PP goes on tiny top-ups. A healer's HP given away (Soft-Boiled) counts against it, so a move that costs nothing comes first. Rest, Healing Wish and Lunar Dance are never in a plan. The plan shows each step, the PP in all and the party's HP after; Heal Everyone runs it.

## Challenges

- **No heals (overworld)** (PIF's challenge): every healing move is locked, and Heal with Moves too.
- **No reviving** (PIF's challenge; KIF's Nuzlocke turns it on): Revival Blessing, Healing Wish and Lunar Dance are locked (a Pokémon that faints can't come back).

## For Other Mods

Kanto Reloaded's Party Screen lets a feature take over a field move picked in a Pokémon's menu (Healing Moves takes over each of its moves, Soft-Boiled and Milk Drink included):

```ruby
Reloaded::PartyScreen.take_field_move(:SOFTBOILED) { |scene, pkmn, move_id| true }   # true: handled
```

In the game's own party screen, Healing Moves hooks the game's field moves (`HiddenMoveHandlers`): listed, checked, used without closing the screen; Soft-Boiled and Milk Drink stay the game's own there.
