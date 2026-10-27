# IV Boundaries

How strong new Pokémon can be: The lowest and highest IVs for wild Pokémon, Eggs and gifts. A feature with a switch (On), in *KIF Settings* > *Kanto Reloaded* > *IV Boundaries*. Every save starts at Vanilla (0 to 31, as the game rolls them), so nothing changes until you pick a range. The code is in `Core/IVBoundaries/` (`IVBoundaries.rb` the ranges and the rule, `Sources.rb` which Pokémon get them, `Fusion.rb`, `MaxIVs.rb`); the rows and popups are in `Core/UI/IVBoundariesRows.rb` and `Core/UI/IVBoundariesScreens.rb`.

## The Ranges

A floor and a ceiling for each of three sources, kept for this save:

| Source | Which New Pokémon |
|---|---|
| **Wild** | Wild Pokémon when they appear, fought or caught: Statics, legendaries, roamers and event battles too |
| **Eggs** | Gift Eggs, the Day Care's Eggs and Kuray Eggs |
| **Gifts** | Pokémon an event gives you: Starters, gifts, in-game trades and Wonder Trade |

**The rule:** An IV inside the range stays as it rolled; one outside is rolled again, evenly inside the range. So a Day Care Egg keeps the IVs it inherited when they're inside your range.

**Only new Pokémon:** A Pokémon made for you right then. Ones you already had never change: the Day Care giving one back, the two Pokémon unfusing gives back, Eusine returning your Pokémon, Mystery Gifts (they keep the IVs their maker set).

**On top:** IV items and bonuses come after the range, like the Perfect Ball's two 31s on a catch and an alpha's two 31s.

## The Page

- **Presets:** A row of chips: Vanilla 0-31, Accessibility 15-31, Strong 20-31, Perfect-ish 25-31, Perfect 31-31, Challenge 0-15 and Custom. Left and Right move along the chips; A uses one, for all three sources. Picking a preset over your own ranges asks first ("Use Strong for All Three?"); your own ranges are kept, and the Custom chip brings them back.
- **Wild, Eggs and Gifts:** Each a bar with two handles, the range's numbers beside it. Left and Right move the lit handle; Y (△ on PlayStation) switches between the floor and the ceiling. A opens **the spinners**: Floor and Ceiling side by side, Up and Down change the lit one, Left and Right switch. Moving any range makes it Custom.
- **The description box** says what the highlighted range means and shows a live preview: six bars, HP to Speed, with the allowed range shaded and a sample Pokémon's IVs (a 31 in gold).
- **Trainers:** Read only. Trainers' IVs follow the difficulty (see *Difficulty*): Half their level on Normal, at least 10 on Hard.
- **Fusion IVs** (under *IV Boundaries - Fusing*): By Splicer (the game's own: DNA Splicers average the two IVs, Super Splicers keep the higher of each), Average or Best of Both for every fusion. The Fusion Screen's preview follows it.

In KIF's own settings screen (with Reloaded Settings Off), each source shows as two sliders, Floor and Ceiling.

## Hard

On Hard, floors stay at 0: New Pokémon can't start stronger than usual. The floor handles show a padlock, and the presets with a floor (Accessibility, Strong, Perfect-ish, Perfect) are locked; A on one says why. A lower ceiling still works (Challenge). Lower the difficulty to Normal and your floors are back.

## KIF's Max IVs Mode

Max IVs Mode counts every IV as 31 for stats, for every Pokémon (foes too), without changing them. Perfect gives new Pokémon real 31s instead. While IV Boundaries is On, KIF's Max IVs row is locked Off ("Locked by Kanto Reloaded"); your own setting is kept, and comes back if IV Boundaries is turned Off.

A save that already has Max IVs Mode On keeps it: no lock there. Turn it Off in KIF Settings and it's locked from then on.

## New Game Setup

Run Setup has an **IV Boundaries** row: a preset for all three sources, set at Start. On Hard, floors still stay at 0.

## For Mods

- `Reloaded::IVBoundaries.range(source)`: `[floor, ceiling]` a new Pokémon of `:wild`, `:egg` or `:gift` rolls in now.
- `Reloaded::IVBoundaries.bound(pkmn, source)`: the rule on one Pokémon (for a Pokémon your mod makes and hands over outside an event script). `roll(source)` gives six IVs inside the range.
- `force_next(source, [lo, hi], count)` and `exempt_next(source)`: the next Pokémon of a source roll in that range, or keep their own IVs.
- `boost(source, [lo, hi], minutes)`: a range for a while, counted in play time.
- Events `:before_bound` and `:after_bound` (`:pokemon`, `:source`, `:range`).
