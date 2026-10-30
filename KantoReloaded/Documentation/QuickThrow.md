# Quick Throw

Throw a ball without opening the Bag, with every ball's chance of catching the Pokémon right now, and that chance in a ring by a wild Pokémon's HP bar. This is Roadmap topic battle-tools. The code is in `Core/BattleTools/QuickThrow.rb` (the feature, its Battle Menu entry and the throw), `Core/BattleTools/CatchChance.rb` (the chances), `Core/BattleTools/CatchGauge.rb` (the ring by the HP bar) and `Core/UI/QuickThrowPanel.rb` (the list and its popups).

## Where It Shows

In the Battle Menu (see [Battle Menu](BattleMenu.md)), first on Main and its Favorite at first, in EBDX's battle screen and PIF's. The Safari Zone and the Bug-Catching Contest have their own throws: no Quick Throw there (the Bug-Catching Contest keeps the ring, for its Sport Ball).

**Quick Throw** (KIF Settings > Kanto Reloaded > Core > Features, On by default) switches it. Off takes the entry, the list and the ring away. The Pure Ball and Status Ball fix (below) stays on either way.

## The Quick Throw Ball

The last ball you threw from the Bag (each save its own), or the one you set with Y in the list. Before you've thrown one, it's the first ball in the Bag.

- **Run out of it:** "Throw your best ball instead?", with that ball's chance, or Choose a Ball (the list). The Quick Throw ball stays the same either way.
- **The Master Ball** is never the Quick Throw ball by itself, never starred, and always asks before it's thrown ("Throw Your Master Ball?", Keep It first).

## Throwing

| How | Does |
|---|---|
| Quick Throw in the Battle Menu (A) | The list (below) |
| The Battle Menu button twice (the Favorite) | Throws the Quick Throw ball at once |
| Quick Throw in Controls > Battle > Battle Menu (unbound at first) | Throws the Quick Throw ball at once, straight from the battle menu |

With two foes out, a ball thrown at once asks which one with the game's own target window, as the Bag does. The throw is the game's own: its checks and messages, its animation, the ball taken from the Bag.

## The List

Every ball in your Bag's Poké Balls pocket, in its order (with the Reloaded Bag: its order and Favorites first), each with its picture, how many, a bar and its chance. The best one is starred in gold; the Quick Throw ball has a QUICK THROW badge. Under the list, why the highlighted ball's chance is what it is ("Net Ball works x3 on Water and Bug types."), then the foe's HP, status and the turn.

| Button | Does |
|---|---|
| Up / Down | Choose a ball |
| A | Throw it |
| Y | Set it as the Quick Throw ball |
| LB / RB | The other foe (two out); the chances follow |
| B | Close |

With the mouse, a click on a ball throws it, the wheel moves, the hints can be clicked, and a right click closes.

- **Locked:** When the foe can't be aimed at (underground with Dig, in the sky with Fly...), the reason shows in red and nothing can be thrown.
- **Trainer battles:** Quick Throw is locked: the trainer would block the ball and it would be lost. With KIF's Rocket Mode On, it's open, and only the balls the trainer lets through can be thrown; the rest are padlocked.
- **Also locked**, with the reason: no balls, the party and every PC box full, the second Pokémon choosing in a double battle, items not allowed in the battle, KIF's Nuzlocke (the encounter used, the Dupes Clause) and Ghostly Possession's Ghost battles (no ring by the HP bar either).

## The Chances

Worked out from the game's own catch maths, not rolled: the ball's bonus, HP, status, KIF's Critical Captures (with how many Pokémon you own), your last ball's critical catch (and a shiny always caught with it), and Caught Off Guard.

- **A whole percent** that never rounds up to a sure thing: 99% until it really is 100%, and <1% under one.
- **Colours:** Red under 25%, gold under 50%, green from 50%.
- **Balls that give a status** (PIF's Dream, Toxic, Scorch, Frost and Spark Balls) count the status they'd give, and say so ("Dream Ball puts it to sleep first, for x2.5."). Working the chance out never changes the battle.
- **Guaranteed Catch** (Quality of Life) shows every ball at 100%.
- **"~" in front:** When the game's catch maths isn't what Kanto Reloaded knows (a KIF update, another mod's change), every chance is an estimate, and Kanto Reloaded's log says why. KIF's own switch for its modules (Battles & Challenges On: KIF's maths, Off: PIF's) and Alpha Encounters' change (it doesn't touch a thrown ball) are known, so the chances stay exact with them.

## The Ring by the HP Bar

The Quick Throw ball in a ring that fills with its chance, the number beside it, by a wild foe's HP bar: right of the status tag on EBDX's box, right of the type icons on PIF's. Run out of the Quick Throw ball, it shows the best ball's chance instead. It moves, hides and fades with the box, and is only drawn again when what it shows changes. **Catch Chance on HP Bar** (Kanto Reloaded > Battle Menu > Quick Throw, On) switches it.

## The Pure Ball and Status Ball Fix

PIF's Pure Ball ("works better on a Pokémon with no status") and Status Ball ("works better on a Pokémon with a status") worked the wrong way round. Each now works as its description says. This is a fix (Foundation > Fixes), always on.

## For Mod Makers

- **Another mod's balls** work in the list and the ring like the game's: every item in the Bag's Poké Balls pocket with a Battle Use of 4 or 9 (thrown at a foe) is listed, and its chance comes from its own catch rate handler. Nothing from another pocket is (Ghostly Possession's Cleanse Tag is aimed at a foe too). While the chance is worked out, a handler sees stand-ins of the battler and the battle that keep any change to themselves; a handler that tries to change the battle any other way shows "?".
- **A chance:** `Reloaded::CatchChance.chance(battle, battler, :ULTRABALL)` gives `chance` (0 to 1), `sure`, `mult` (the ball's bonus), `status` and `status_set` (the status it would see, and whether the ball gave it); `Reloaded::CatchChance.percent(result)` writes it.
