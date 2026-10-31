# Effectiveness (EBDX)

How well each move does against the foes, on EBDX's Fight menu: the cursor in the move's color, its multiplier beside the PP, a dot on the other moves, and in Double Battles each target's name above the move. Only what the battle has shown counts. This is Roadmap topic move-effectiveness. The code is in `Core/MoveEffectiveness/MoveEffectiveness.rb` (the feature, its settings, its colors and hooks), `Core/MoveEffectiveness/FightOverlay.rb` (what the Fight menu shows) and `Core/BattleTools/Matchup.rb` (how a move fares, as the player knows it).

## Where It Shows

In EBDX's battles (KIF Settings, Graphics; Off for a new player), in place of KIF's own Move Effectiveness there (its markers on the buttons and its "Super eff." words above them). PIF's own Fight menu keeps KIF's (KIF Settings > Battles) as it is: Kanto Reloaded doesn't change it.

**Effectiveness (EBDX)** (KIF Settings > Kanto Reloaded > Core > Features, On by default) switches it. Off leaves Battle Scene's plain cursor and gives EBDX's Fight menu KIF's own markers and words again.

## The Fight Menu

| What | Shows |
|---|---|
| The cursor | Battle Scene's ring round the picked move in the move's color (see [Battle Scene](BattleScene.md)). A move that does the usual damage keeps the usual cursor. |
| Multiplier | A pill in the move's color between the category icon and the PP: x4, x2, x1/2, x1/4 or x0 (x1/2 and x1/4 as a small fraction). None for the usual damage. |
| Move Dots | A dot in its color on each move you haven't picked, on the right of its button. None for the usual damage. |
| Target Pills | Double Battles: the name of each Pokémon the picked move can hit, above it, outlined in that Pokémon's color. |
| Ally Warning | A move that would hurt your partner (Discharge, Earthquake, Surf...): a red "!" in its button and your partner's pill in red. Your partner's pill is gray when it can't be hurt (a Volt Absorb or Telepathy partner, a Flying one against Earthquake). |

The color is the best result among the foes the move can reach. A move that hits one Pokémon counts only the foes, even though it could be aimed at your partner; your partner counts only for moves that hit several.

**Mega Evolution:** While its button is on, every move shows how it will do once your Pokémon has Mega Evolved, with the Mega's ability and types (Mega Altaria's Pixilate makes its Normal moves Fairy). The Megas mod's Primal Reversion on the same button too. Turned off, the moves go back. The buttons are made again in place, so other mods' marks on them stay.

## The Target Window

When you pick a target, each of Battle Scene's rings is in its target's color: your partner's red when it would be hurt, gray when it can't be. **Target Window Colors** switches it.

## The Colors

| Level | Color at first |
|---|---|
| x4 (4 times the damage or more) | Cyan |
| x2 | Green |
| x1 (the usual damage) | Theme: your Cursor Color |
| x1/2 | Red |
| x1/4 (a quarter of the damage or less) | Yellow |
| x0 (no effect) | Always gray |

Each one can be changed to Theme (your Cursor Color) or any of Kanto Reloaded's 45 colors. EBDX's battle screen is the same in every Theme Mode, so the colors are always the bright ones of Theme Mode Dark.

## What Counts

- **The game's own maths:** the move's type as the battle works it out (Weather Ball in the weather, an -ate ability, Hidden Power, Electrify...), KIF's type changes, Scrappy, Freeze-Dry, a grounded Flying type, a third type.
- **Only what the battle has shown:** a foe's ability counts once its pop-up has shown (or a message named it), and the same for Double Abilities' second ability and KIF-ER's innates; a foe's held item once it's been used or named (an Air Balloon says so when it comes in). A foe disguised by Illusion counts as the Pokémon it looks like. Your own Pokémon are known in full.
- **Abilities that make a Pokémon immune:** Levitate, Flash Fire, Volt Absorb, Water Absorb, Lightning Rod, Motor Drive, Sap Sipper, Storm Drain, Dry Skin, Soundproof, Bulletproof, Wonder Guard and Telepathy (for your partner), and KIF-ER's (Earth Eater, Aerodynamics, Ice Dew, Mountaineer, Poison Absorb, Heat Sink, Well-Baked Body, Evaporate, Gifted Mind, Aerialist, Dragonfly, Wind Rider, Weather Control, Good as Gold), unless the user has Mold Breaker. Air Balloon, Magnet Rise and Telekinesis against Ground moves.
- **Fixed damage** (Seismic Toss, Night Shade, Super Fang, Dragon Rage, Sonic Boom, the one-hit KO moves...): the usual damage, or no effect where the type can't hit.
- **Status moves** show nothing, but Thunder Wave: no effect on a Pokémon it can't paralyze by type (a Ground type).
- Damage changes that aren't the type (Thick Fat, Filter, Tinted Lens, screens) aren't counted.

## Settings

Kanto Reloaded > Interface > Effectiveness (EBDX): Multiplier, Move Dots, Target Pills, Ally Warning and Target Window Colors (each On), then x4, x2, x1, x1/2 and x1/4 Color.

## For Mod Makers

- **A move against a Pokémon:** `Reloaded::Matchup.value(move, user, target)` gives the effectiveness (`Effectiveness::NORMAL_EFFECTIVE`, 8, is x1) as the player knows it, or nil when nothing shows (a status move, Thunder Wave aside). `Reloaded::Matchup.level(value)` gives `:x0`, `:x1_4`, `:x1_2`, `:x1`, `:x2` or `:x4`; `Reloaded::Matchup.text(value)` the words (x4, x1/2...). `Reloaded::Matchup.summary(battle, user, move)` gives a Fight menu line: `:best` (the best foe's), `:per` (each target, and whether it's your partner) and `:warn`. Nothing in the battle changes: the move's values are put back, the user and target are copies.
- **An ability that makes its holder immune:** `Reloaded::Matchup.immunity(:MYABILITY, :FIRE)`, or with a block that says when: `Reloaded::Matchup.immunity(:MYABILITY) { |move, type, user, target, value| move.soundMove? }`. It counts once the battle has shown the ability, and not against Mold Breaker. Mods that extend KIF's own list (`KIF::MoveEffect.known_immunity?`, as KIF-ER does) are counted too, as KIF's Foe Info "As seen" has it.
- **A Fight menu button that changes your Pokémon before the turn** (like Mega Evolution): `Reloaded::MoveEffectiveness.user_change(:my_button, proc { |win| pressed? }, proc { |win, user| changed copy })`. `win` is EBDX's `FightWindowEBDX`; the second proc gets a copy of your Pokémon (never the battler itself) and returns a copy as it will be (its ability, types or Pokémon), or nil. The Fight menu checks the first each frame and works every move out again when it changes.
- **Credit:** The immunity rules are cody's (KIF's Move Effectiveness, C-BATTLE-01).
