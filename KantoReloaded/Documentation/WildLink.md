# Wild Link

Wild Link takes the Poké Radar's place: see every wild Pokémon in an area, pick one you've seen, and it appears nearby for you to battle. The more you hunt a Pokémon, the better the ones you find.

Wild Link is On for each save to start: **Wild Link** in its own section of Kanto Reloaded's settings. Off, Area Encounters and the Poké Radar work as the game has them.

## Where It Is

- **Overworld Menu:** Area Encounters becomes Wild Link (it keeps its place on your pages).
- **Pause Menu:** A Wild Link tile with the Poké Radar's picture, showing your chain.
- **The Poké Radar:** Using it opens Wild Link.

The list is there from the start. **Search** unlocks once you have the Poké Radar (from the researcher on Route 24).

## The Screen

- **The List:** A tab for each way the Pokémon here are met (Land, Cave, Surf, Fishing, Rock Smash), with Seen and Caught. Each row has the Pokémon (a shadow and ??? until you've seen it), a ball once caught, its levels and how often it appears. Each rod's Pokémon are under the rod's name. Only the ways you can meet them from where you are get a tab: grass you can't walk to doesn't count (Pallet Town's is walled off), nor water you can't reach, nor grass across the water until you can surf. Area Encounters lists them the same way.
- **The Weather:** With the Weather System, the weather here shows as a chip in the corner, the Pokémon it brings out more are marked with their raised share, and the place's Weather Visitors are listed as Weather Signals while the weather lasts.
- **The Rare Signal:** The route's Poké Radar Pokémon, last in the Land tab. It stays locked until you've seen every land Pokémon there; then you can search for it even before you've seen it.
- **The Panel:** The picked Pokémon in its type's colour: its Search Level with a bar to the next step, your chain, and its Current Bonuses, each with a meter toward its best. X shows the Search Level steps instead. The line at the bottom says what Search can do (or why not: no Poké Radar yet, no rod, not seen yet).

Up and Down pick a Pokémon, Left and Right change the tab, A searches, X switches the panel and B closes. With the mouse, click a tab or a row; click the picked row again to search.

## Searching

Your target appears 3 to 7 steps away, on screen, somewhere you can reach. It's one of the game's own walking Pokémon and behaves the way that species does: some charge you, some are shy, some run away. Walk into it to battle.

- **Land and Cave:** On the grass, or the cave's floor.
- **Surf:** On the water, while you surf. It stays in open water, off piers and docks.
- **Fishing:** A spot on the water nearby is marked with ripples, bubbles or a fish's shadow (one at random). Face it and fish with the rod the Pokémon is listed under: it bites every time (reel it in as usual; miss and it stays there for another cast).
- **Rock Smash:** A breakable rock appears nearby, wobbling now and then. Smash it and the Pokémon comes out.

Other wild Pokémon still appear while you search, and your Repel doesn't run down.

You can't search in the Safari Zone or the Bug Contest, while a partner walks with you, or when the Randomizer rolls every Pokémon on the spot. With KIF's Nuzlocke on, Search waits until the place's first encounter is used; after that, only a shiny target can be caught.

## Search Level and the Chain

- **Search Level:** Each species has one, up to 999. Catching its target adds 2, knocking it out adds 1.
- **The Chain:** Win battle after battle with the same Pokémon, the same way, on the same map. Running, losing, leaving the map or searching another Pokémon ends it. A target that gets away doesn't: search again.
- **After a Win:** *Continue Search* (Ask, Automatic or Off) asks whether to search again, brings the next one on its own, or stops.

| Bonus | From Search Level | From the Chain |
|---|---|---|
| Shiny | Extra rolls: 1 at 12, 2 at 50, 3 at 100, 4 at 250 | The Poké Radar's odds: 1 in 200 at 20, 1 in 20 at 100, 1 in 10 at 200, still better after (on Wild Shiny Odds) |
| Perfect IVs | 1 at 25 (sometimes at 12), sometimes 2 from 50, 2 at 100, sometimes 3 from 250 | At least 2 at 50, 3 at 100, 4 at 150 |
| Hidden Ability | 2% at 5, up to 25% at 250 | 5% at 10, up to 25% at 150 (50% at most) |
| Egg Move | 10% at 5, up to 70% at 250 | 5% to 25% (90% at most); a second one opens at Search Level 50 or chain 50 |
| Held Item | 5% at 5, up to 30% at 250, leaning to its rarer items | 5% to 30% (60% at most) |
| Level | +0-1 at 5, up to +3-5 at 250 | |

## On the Map

- **Chain HUD:** While your target is out, the top left shows the Pokémon, your chain, its Search Level and the shiny odds. Notices move beside it (or under it) instead of covering it.
- **Notices:** When your target gets away, when your chain breaks, and when a Pokémon reaches a new Search Level step.

## With Other Mods and Online Play

- **Alpha Encounters:** A target can be an Alpha, and keeps its Egg Moves and held item.
- **Hoenn Native Overworld:** Its walking Pokémon and your target share the game's engine; it leaves your target alone.
- **KIF's Multiplayer:** Each player has their own Wild Link: Search Levels, chains and targets. A target shows only on its finder's map, and its battle joins co-op like any wild battle.

## For Mod Makers

```ruby
Reloaded::WildLink.on?                          # On for this save
Reloaded::WildLink.search_level(:ABRA)          # 34
Reloaded::WildLink.chain                        # { "species", "method", "map", "n" } or nil
Reloaded::WildLink::Bonuses.shiny_odds(34, 12)  # 1200: 1 in 1,200
Reloaded::WildLink::Search.target               # the target out, or nil
Reloaded::Events.on(:wild_link_won, :my_mod) { |c| c[:species]; c[:caught]; c[:n]; c[:steps] }
# also :wild_link_target, :wild_link_got_away and :wild_link_chain_broken
```
