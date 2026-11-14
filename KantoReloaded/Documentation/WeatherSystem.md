# Weather System

Weather that moves across the region and lasts, in place of each map rolling its own when you arrive. This is Roadmap topic weather-system. It's part of Kanto Reloaded, with its own switch per save.

The code is in `Core/Weather/Weather.rb` (the switch, the cycle, the weather on the map), `Places.rb` (where weather can be), `Fronts.rb` (how it moves), `Link.rb` (the game's own weather code and other mods), `Battle.rb` (the weather in battle), `Encounters.rb` (the weather's Pokémon), `Display.rb` (names, colours, icons), `Screens.rb` (where the Forecast opens, the Fly map), `Alerts.rb`, `Sounds.rb`, `FieldMoves.rb`, `Records.rb`, `Rainbow.rb`, `Strikes.rb`, `Multiplayer.rb` and `Core/UI/WeatherForecastScreen.rb` (the Forecast). The weather icons are in `Graphics/Pictures/Weather`: old Kanto Reloaded's set (the game's own map icons), the game's Wind and Ash from the same set, and a Rainbow.

## Settings

In *KIF Settings*, the *Weather System* section under *Kanto Reloaded*, kept by each save:

- **Weather System:** On at first. Off: Each map rolls its own weather when you arrive, as the game does.
- **Weather Changes:** How often the weather changes across the region. Slow (every 12 hours of the game's clock), Normal (6) or Fast (3). An hour of the game's clock is a minute of play; the clock stops in menus and while the game is closed.
- **Weather Alerts:** On. A short notice when the weather changes where you are, and when Heavy Rain, a Blizzard or Strong Winds is coming. Kept for every save.
- **Weather Sounds:** On. Rain, storms and thunder you can hear outdoors. Kept for every save.

## Places

Every outdoor map belongs to a place by its name: two maps called Route 2 share one place's weather, and the Safari Zone's areas are one place. Left out: maps with no name, the debug and message maps, and Underwater.

Each place has its own kinds of weather, by what kind of place it is:

| Kind | Weather |
|---|---|
| Most places | Rain the most, then sun, wind, fog and the odd storm |
| Forests, gardens and parks | Rain and fog more, little sun |
| Coasts, islands and sea roads | Rain, wind and storms more |
| Mountains | Snow, wind and fog |
| Volcanic places (Cinnabar Island) | Ash, and sun |

Some routes have their own leanings (Route 10 rainy and stormy, Routes 19 to 21 windy). There are no sandstorms: Only the Sandstorm field move makes one.

A map whose own weather always happens keeps it: *Route 25*'s rain, *Mt. Ember*'s sun, the *Ice Mountains*' snow and *Mt. Silver*'s snowy peak. A map that only sometimes rains (*Cerulean Cape*, *Lavender Town*, *Treasure Beach*, *New Bark Town*) joins in, rainier than its neighbours.

## How It Moves

The whole region changes at once, every cycle:

- **Fronts:** A front strengthens, weakens or holds, and sometimes fades. A storm that fades leaves rain.
- **Moving:** Now and then a front moves to a place next to it.
- **Strong fronts:** At 7 or more, a front also spills a weaker edge into the places around it. At 8 or more it grows: Rain into Heavy Rain, Snow into a Blizzard, Wind into Strong Winds.
- **Meeting:** Rain meeting sun makes fog; rain meeting wind (either at 5 or more) makes a storm.
- **New fronts:** New ones start now and then from each place's kinds of weather, and a few are always up somewhere.
- **Seasons:** The game's own season makes its weather more likely: rain in Spring, sun and storms in Summer, fog and wind in Autumn, snow in Winter. Snow that drifts somewhere it can't snow turns to rain, except in Winter.

About a quarter of the region has weather at a time.

The weather now and the weather next are kept in your save, so loading never changes them. If a lot of time passes at once (the Time Changer, a long sleep), the weather catches up a few cycles, not all of them.

## On the Map

Outdoors, you see your place's weather. The sun doesn't show in the evening or at night; it's back in the morning. Weather a story event sets stays while you're on that map.

## In Battle

The weather on the map comes into battle, as the game does: Rain, a storm or heavy rain bring Rain; snow or a blizzard bring Hail (Snow with KIF's *Modern Hail*); sun brings Sun (never after dark). Then:

- **Wind:** Everyday wind gives one side Tailwind for 4 turns, nothing else. Strong winds (8 or more) bring the game's full Strong Winds, and the Tailwind.
- **Fog:** Outdoors, every move is less accurate, for both sides: x0.9 in light fog down to x0.6 in thick fog. Moves that never miss still never miss. A FOG chip with the accuracy leads the *Battle Menu*'s Field Strip, and *Battle Info*'s *Field* tab shows it too, on both battle screens.

A battle that sets its own weather (some story battles) keeps it, with no fog.

## The Weather's Pokémon

Outdoors, while a place has weather (grass, surfing and fishing alike; Hoenn Native Overworld's walking Pokémon too):

- **More Common:** The place's own Pokémon of the weather's types show up more: x1.5 in light weather up to x3 at full strength.

| Weather | Types |
|---|---|
| Rain (and Heavy Rain) | Water, Electric |
| Storm | Electric, Water |
| Sunny | Fire, Grass |
| Fog | Ghost, Psychic |
| Snow (and Blizzards) | Ice |
| Wind (and Strong Winds) | Flying, Normal |
| Ash | Fire, Rock |
| Sandstorm | Ground, Rock |

- **Weather Visitors:** Now and then (2% of encounters in light weather, up to 8% at full strength) a Pokémon from outside the place's list: of the weather's types, at home in that kind of place (by its habitat: forest, coast, mountain...), at the place's levels, in the stage that fits them. Never a legendary or a fossil. Each place has the same two for each weather in a save, two on grass and two on water. The Randomizer changes them as it changes any wild Pokémon. Hoenn Native's PokéRadar app lists them.

No weather Pokémon after dark in the sun (the sun's down), under weather a story event set, or in places that keep their own weather.

## Field Weather Moves

Your Pokémon change the weather where you are, from their menu in the party (a field move), outdoors in a place of the Weather System's (not indoors, nor a place that keeps its own weather):

| Move | Weather |
|---|---|
| Rain Dance | Rain (a storm when it's windy) |
| Sunny Day | Sun (not after dark) |
| Hail | Snow |
| Sandstorm | A sandstorm (the only way to get one) |
| Thunder | A storm |
| Whirlwind, Tailwind | Wind (a storm when it's raining) |
| Mist | Fog |
| Defog, Haze | Clears the fog or the ash |

First a card shows what it will do: the weather and where, until the weather next changes, its strength, the types more common, what it does in battle, the weather it replaces and the cost. Use or Cancel. Each use costs the move 1 PP (a Pokémon Center refills it) and plays the Pokémon's cry. The weather starts at strength 5 and holds until the weather next changes across the region; then it joins the others and can grow, fade or drift away. After dark, Sunny Day's card says the sun has set, and no PP is used.

With the Weather System Off, these moves are as in the game (Hoenn only).

## Rainbows, Lightning and Weather Records

- **Rainbows:** When rain or a storm clears by day, the place gets a rainbow for 3 hours of the game's clock (3 minutes of play): a see-through rainbow arcs across the sky on its maps, fading in, and the Forecast shows it. Under it the rain's Weather Visitors come twice as often as in light rain. Seen as it appears, a notice says so (with *Weather Alerts* On). It goes at dusk, when weather comes back, or when its time is up.
- **Lightning Strikes:** Now and then in a storm (a few minutes of play apart, on average), lightning strikes a tile near you: the bolt, a white flash, a snap of thunder. A sparkle stays on the tile; step on it for what the strike left: a hidden item (a Thunder Stone now and then, else a Cell Battery or a Magnet) or an Electric Visitor at the place's levels. It goes when you leave the map.
- **Weather Records:** Battles won in each weather (the weather as the battle started; heavy rain counts as rain, a blizzard as snow, strong winds as wind) are counted for the save. The *Trainer Card*'s *Weather* tab, after *Stats*, shows each weather's wins, your favourite weather and the next weather title. Ten wins in a weather earn its title for the card: Rain Dancer, Storm Chaser, Sun Seeker, Windrider, Fog Walker, Snow Drifter, Dune Runner and Ash Walker. The tab shows while the Weather System is On.

## Alerts and Sounds

- **Alerts:** When the weather changes across the region and your place's changes with it, a notice at the top of the screen: the weather's icon, what happened ("Rain Started", "Fog Rolled In", "The Weather Cleared") and the place with the strength. When Heavy Rain, a Blizzard or Strong Winds will reach your place next cycle, a heads-up with a red HEADS UP badge and how long until then. They go after 3 seconds, make no sound, and never stop you.
- **Sounds:** Outdoors, old Kanto Reloaded's rain, storm and heavy rain sounds, louder the stronger it is, with thunder now and then in storms (every 6 to 14 seconds) and heavy rain (every 10 to 20), both of its thunders in turn. Wind makes no sound. A map with a sound of its own (the sea, a waterfall) keeps it. The sounds are in `Audio/BGS` and `Audio/SE`.

## The Weather Forecast

Opens from the *Overworld Menu* (Forecast, on Main after Fly), the *Pause Menu* (the Forecast tile), the *Fly map* and *Town Map* (Y), and the PokéNav's Weather app (Hoenn Essentials', or the game's own).

- **The map:** The Town Map at full size, each place's weather as an icon on its tile, your spot marked, the cursor on the place you're looking at. Johto and the Sevii Islands show once you've been there, as on the game's Town Map.
- **The place:** Lit in its weather's colour: the weather's icon, the place, the weather and its strength (Light, Moderate or Heavy), a 10-step strength bar, its climate, the trend (Rising, Fading or Steady) and what's next (Now), or what it replaces and when it starts (Next), the season, the types more common, and its two Weather Visitors: their pictures once you've seen them in battle, shadows until then. At the bottom, when the weather changes (minutes of play).
- **The title bar:** The season (Spring, Summer, Autumn or Winter) on the left; NOW and NEXT on the right.

The arrows move between places, X switches Now and Next, Y goes back to your place, B closes. With the mouse, click a place or a tab; a right click closes.

## The Fly Map and the Town Map

The game's own map screen, with the weather on it: every place's weather icon on its tile (moving with the map), and a card beside the cursor in the weather's colour (the place, the weather and its strength, the bar, what's next or when it starts, the types more common). "Weather: Now" on the title bar; X switches Now and Next, Y opens the Forecast. The card and keys follow Theme Mode. The place's point of interest (a lab, a shop) isn't shown while the weather is.

## Multiplayer

With KIF's Multiplayer, while players are connected and each has Kanto Reloaded:

- **The host's weather for everyone:** Every guest sees the host's weather, on the map, in battle, in the Forecast and in the alerts. A guest's own saved weather is left as it was (its clock waits) and comes back when they leave. The sun after dark still follows each player's own clock.
- **Guests' Field Weather Moves:** A guest's move asks the host's game to change that place, so everyone sees it. The PP and the cry are the guest's; their save's weather isn't changed.

## Other Mods and the Game's Own Weather Code

- **The game's own weather code:** The game's fog, trees blowing in the wind and Feebas in the rain follow this weather.
- **Hoenn Native Overworld:** Its Pokémon react to the weather in Kanto: storms make them slower to notice you, fog shortens how far they see, and wind, rain and sun change how they roam.
- **Hoenn Essentials:** While the Weather System is On, its own weather stands aside, and so do its Weather Visitors (this one's take over, so there's one set, the one the Forecast shows) and its weather sharing in Multiplayer. Off, it runs as before.
