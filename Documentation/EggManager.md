# Egg Manager

Every Egg in your party and the PC in one place, PC incubators, and the Day Care from anywhere. This is Roadmap topic egg-manager: Hoenn Reloaded's Egg Manager rebuilt on the game's own functions, in the TM Vault's look. The code is in `Core/EggManager/` (`EggManager.rb` the feature, settings and menu entries; `Eggs.rb` finding and moving Eggs; `Incubators.rb`; `DayCare.rb`; `Alerts.rb`; `Hatching.rb`) and `Core/UI/` (`EggManagerScreen.rb` the screen and the Eggs tab, `EggDayCareTab.rb` the Day Care tab, `EggPopups.rb` the Ask Card).

**Egg Manager** in Kanto Reloaded > Features switches it, On to start. It takes over KIF's Hatch to PC Prompt (`F-UI-08_HatchToPC`); Off gives it back.

## Where It Shows

- **The Pause Menu:** Egg Manager, its status the Eggs you have. It glows red while something waits (Hatch Alerts).
- **The Overworld Menu:** Egg Manager, an action, glowing the same way. The Day Care readout glows while an Egg waits there, and its popup gains an Egg Manager hint (Action) that opens the Day Care tab.
- **The Reloaded PC:** Incubate or Take Out of Incubator in an Egg's actions.

It can't be opened in the Bug Contest, or where KIF's menus are shut.

## The Eggs

- **The header:** Sort on the left (L: Steps, fewest first, or Place: the party, then box by box) and Hatch Ready on the right (R: every Ready Egg in the boxes hatches, one after another; faded when there's none).
- **The tabs:** Eggs and Day Care (Action), each with a gold dot when it has news.
- **The list, in sections:** Ready (an Egg in a box at its last step, or a party Egg under 100 steps), Party, PC, and Gift (an Egg not from the Day Care, wherever it is). Each Egg shows once, and empty sections are left out. Each row: "Egg" in its state's colour (gold in Ready, green hatching in the party, blue in an incubator, plain when paused in a box), where it is, its steps (READY when done), a small blue pod with its incubator's number, and the Egg.
- **The details plate,** lit in the state's colour: the Egg, its state, where it is; Steps Left with the bar and PIF's own words for how close it is; the incubators; the Hatch Speed Helper.
- **Inspect Eggs** (a setting, Off to start): a Ready Egg's plate shows Inside in place of the steps and the Hatch Speed: the species and gender, its Poké Ball, nature and ability, the IVs (each stat in Compare's colours, a 31 in gold), and Egg Moves under their own heading.

X puts a boxed Egg into an incubator or takes it out; on a party Egg it moves it to the Egg Box. A opens **Options**: Hatch (a Ready boxed Egg: it hatches where it is), Move to Party, Incubate or Take Out of Incubator, Move to Egg Box, the Egg Box, and Auto-Incubate On or Off.

## Incubators

- **How many:** one at the start, a second at 4 Badges, a third at 8. The row has room for three more, which a mod can give (`add_incubators`). The next to earn shows locked, with its Badges.
- **The heading** reads "Incubators - Auto", Auto green while Auto-Incubate is On and red while it's Off.
- **Counting:** an Egg in one counts down in its box as fast as in the party: 1 a step, 1 more with the Breeder outfit, 1 more with Flame Body or Magma Armor in the party (the game's own rules). It stops at its last step: Ready. With Quality of Life's Instant Hatch On it's Ready at once.
- **Hatching where it is:** the game's own `pbHatch` (the scene, the Pokédex, the nickname); the Pokémon stays in its box.
- **Walking costs almost nothing:** the Eggs in incubators are kept in memory, so a step with none in use is one check, and with some one subtraction each (about 11 µs a step with three in use, measured by the test). The boxes are only looked through when a save loads, the PC closes, the Egg Manager opens and the game saves. That's when Eggs released, taken into the party or moved to the Transfer Box lose their incubator (the Transfer Box is shared by every save).
- **Auto-Incubate:** an Egg the Day Care sends to the PC (your party is full) goes to the Egg Box and into a free incubator, with a toast.

The incubator's number is kept on the Egg itself (`@kr_incubator`), so it moves with the Egg and the save still loads without Kanto Reloaded (the Egg just stops counting until it's back).

## The Egg Box

Where Eggs the Egg Manager sends to the PC go first: Move to Egg Box, Collect with a full party, Auto-Incubate. When it's full (or it's Any Box), the current box, then the first with room. Chosen from Options in the Box List: Any Box, then each box with its Eggs and free places (Full in red), the Egg Box marked with a gold pill.

## The Day Care

It opens here once you've left a Pokémon at the Day Care in person (a save that already has one there counts).

- **The list:** the Pokémon there, Find a Partner (with one there), Egg Waiting, Deposit a Pokémon (with room).
- **The plate:** the two side by side, how well they get along (the words and pips), **Egg Chance** ("50% Every 256 Steps": 20, 50 or 70%, 40, 80 or 88% with the Oval Charm), each one's levels gained and what taking it back costs (green when you can pay, red when you can't), and the waiting Egg with Collect and Discard (Left and Right on its row).
- **Withdraw:** A on one there: to your party or the PC, for the game's cost (`pbDayCareWithdraw`, so KIF's Level Caps still apply). Refused when you can't pay or there's no room.
- **Collect:** the game's own `pbDayCareGenerateEgg`. Refused when your party and the PC are full (PIF would lose the Egg).
- **Deposit:** your party, then box by box. A Pokémon that can battle always stays in your party.
- **The Partner Finder:** with one Pokémon there, every Pokémon in your party and boxes that can breed with it, in sections by Egg Chance, best first. The plate shows the pair as it would be, where the partner is and why ("Same Species · Other Trainer", or the egg group they share). The game decides each pair: the two are put in the Day Care's slots for a moment and `pbDayCareGetCompat` asked, so KIF's Head Legendary Breeding and cody's Legendary Breeding apply, then the slots are put back.

## Alerts

With **Hatch Alerts** On, each once as it happens, a toast with the Egg, one line and a pill:

- "An Egg is about to hatch!" (60 STEPS): a party Egg under 100 steps.
- "An Egg in Box 3 is ready to hatch." (READY): an incubated Egg at its last step.
- "The Day Care has an Egg for you." (DAY CARE).
- "An Egg went into Incubator 3." (BOX 5): Auto-Incubate.

The ones already shown are kept by the save, so loading doesn't repeat them. While the Egg Manager is open it says these itself.

## Hatched Pokémon

Takes over KIF's Hatch to PC Prompt. After a Pokémon hatches in your party (the scene and its nickname done):

- **Stay:** it stays.
- **Ask:** the Ask Card over the map: its picture, level, nature and ability, "Keep it, or send it to the PC?", where it would go ("Goes to Box 3 (12 Free)"), Keep in Party (the default, and B) or Send to PC. With every box full, Send to PC is dimmed and it says so in red.
- **Send to PC:** it goes by itself, and a toast says which box.

As KIF's did, it never asks when it's the only Pokémon in your party that isn't an Egg. One that hatched in a box stays there. A save that had KIF's prompt Off starts on Stay.

## Settings

Kanto Reloaded > Egg Manager: Hatched Pokémon (kept by each save), Auto-Incubate, Hatch Alerts, Hatch Speed Helper, Inspect Eggs.

## Debug

The **Kanto Reloaded Debug** mod (its own folder, `Mods/KantoReloadedDebug`) has an **Egg Manager** page in its KR Debug section of KIF Settings, shown while the Egg Manager is On: random Eggs (how many, where, their steps, fusions), a gift Egg, every Egg Ready, the Day Care filled or emptied, a Day Care Egg now, incubators given and taken back, the visit forgotten, alerts shown again, every Egg removed (it asks first). Its guide is in that mod's Documentation.

## For Other Mods

```ruby
Reloaded::EggManager.open(tab: :day_care)
Reloaded::EggManager.add_incubators(1, source: :my_mod)
Reloaded::EggManager::Incubators.incubate(egg)          # its number, or nil
Reloaded::EggManager::Eggs.all                          # every Egg: Entry(pkmn, box, slot), box -1 for the party
```

Events: `:egg_hatched` (`:pokemon`, `:box`, `:slot`) and `:day_care_deposit` (`:pokemon`). The save keeps the Sort, the Egg Box, the alerts shown, the Day Care visited and incubators a mod gave (SaveStore section `egg_manager`).

## Tests

```text
ruby Tools/Tests/egg_manager_test.rb "<KIF Beta>" <empty temp folder>
ruby Tools/Tests/egg_manager_preview.rb "<KIF Beta>" <work dir with metrics.json>
```

The test loads KIF Beta's own `007_Overworld_DayCare.rb`. In the game, still to try: hatching in the PC with EBDX on and off, collecting with a full party and a free incubator, and a save without Kanto Reloaded.

The design mockups are in `Tools/Designs/eggmanager/`.
