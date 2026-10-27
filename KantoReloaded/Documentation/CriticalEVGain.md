# Critical EV Gain

Now and then, a win trains a little harder: After a battle, each Pokémon that earned EVs has a small chance of bonus EVs, a critical. A feature with a switch (On), in *KIF Settings* > *Kanto Reloaded* > *Critical EV Gain*. The code is in `Core/CriticalEVGain/` (`CriticalEVGain.rb` the rolls, `Mochi.rb` the Fresh-Start Mochi); the popups are in `Core/UI/CriticalEVGainScreens.rb`.

## When It Rolls

- **After a win** that gives EVs: a trainer battle or a wild Pokémon knocked out. A catch, a loss, running and the Battle Frontier's battles don't roll.
- **Who rolls:** Each of your Pokémon that earned at least 1 EV in that battle, with Exp. Share and Exp. All too. One that fainted keeps the EVs it earned but doesn't roll.
- **One roll each,** after the last Exp. and level-ups, before "You defeated...". The rolls use their own random numbers, so a randomizer's seed never moves.
- **Not while KIF's EVs Train Mode or No-EVs Mode is on:** The section's rows lock and say why.

## The Critical

- **Chance:** 5% by default (0 to 100%). Y (△ on PlayStation) switches the slider between steps of 1 and 5.
- **Amount:** +3 by default (+1 to +10), all on one stat.
- **Bonus Stats:**
  - **Natural** (the default): One of the stats it earned this battle, most likely the one it earned most.
  - **Random:** Any allowed stat, picked evenly, whatever it earned.
- **Power Items Boost** (On): Holding a Power item doubles the chance, and the critical goes to that item's stat.
- **Stats:** Six chips, one per stat. A stat turned Off never gets a critical (its normal EVs still count). Left and Right choose a chip, A turns it On or Off.
- **The caps stay:** 252 in a stat, 510 in all. What a full stat can't take goes to another: first the other stats it earned (the most earned first), then any allowed stat. A Pokémon at 510 doesn't roll.

## After the Battle

Back on the map, once you have control (never over a message, an event or a map change):

- **Summary:**
  - **Criticals Only** (the default): The EV Gains board, only after a battle with a critical.
  - **Every Win:** The board after every win.
  - **Toast:** No board, a short line at the top ("Pikachu: +3 Attack").
  - **Off:** Nothing.
- **The EV Gains board:** Each Pokémon that earned EVs, a column per stat. A cell with a critical is gold and counts it in. A Power item that doubled the chance is named under the board, and so is a critical that moved on from a full stat ("Pikachu's Attack Is Full: 1 Went to Sp. Atk"). One that fainted is dimmed with a FAINTED tag. A or B closes it.
- **EV Gains** in the Overworld Menu shows the last battle's board again (this session). It's on no page to start: Add it with *Edit Pages*.

## Fusions

**Keep Fused EVs** (On): Unfusing gives both Pokémon the EVs the fusion gained while fused, normal and critical, within the caps. Off: The game's own way, where they're lost.

## With KIF's EV Allocation

When KIF's EV Allocation is On (*KIF Settings*, per save), battle EVs become points you spend on the Summary's Skills page. Critical EV Gain follows it:

- **A critical is points:** The Amount (+3) as extra EV points to spend, within 510 in all. Any held Power item doubles the chance.
- **KIF's own line** after the win ("Pikachu got 11 EV points to spend") counts the critical's points too.
- **The board** shows three columns: EARNED, CRITICAL (gold) and TO SPEND, with "Spend Them on the Summary's Skills Page" at the foot. The toast says "Pikachu: +3 EV Points".
- **Bonus Stats and the Stats chips lock** (EV Allocation Is On): Points have no stat.

## The Fresh-Start Mochi

A soft rice cake that puts a Pokémon's training back at the start: All six of its EVs go back to 0.

- **Where:** The Celadon Department Store's vitamin counter, beside HP Up and Protein, for $10,000, while Critical EV Gain is on.
- **Using it:** From the Bag (Medicine) on any Pokémon but an Egg. Its details show the party: each Pokémon's EVs in all, "No EVs" where it would change nothing.
- **It asks first:** Its six EVs, then Reset or Keep (Keep chosen). Reset sets them to 0 and uses up the Mochi; Keep leaves both.

## Settings

The rules (Chance, Amount, Bonus Stats, Power Items Boost, Stats, Keep Fused EVs) are kept for this save; Summary is for every save.

## For Mods

- `Reloaded::CriticalEVGain.results`: the last battle's, one entry per Pokémon: `:pokemon`, `:normal` and `:crit` (six numbers each, HP to Speed), `:item` (the Power item PIF read), `:moved` (`[from, to, n]` or nil), `:fainted`.
- Each critical emits `:critical_ev` (`:pokemon`, `:stat`, `:amount`, `:moved`).
