# Trainer Card

Kanto Reloaded's Trainer Card: PIF's background art with no frame, the card's facts on glass plates, and tabs for Records, Stats, Style and Unlocks. This is Roadmap topic trainer-card. The code is in `Core/TrainerCard/TrainerCard.rb` (the switch and the card's data), `Core/TrainerCard/Counters.rb` (the counts), `Core/TrainerCard/Unlocks.rb` (what can be unlocked and how), `Core/UI/TrainerCardScene.rb` (the screen) and `Core/UI/TrainerCardStyle.rb` (Style and Unlocks).

## Where It Shows

Everywhere the game opens the Trainer Card: the pause menu (the game's and Kanto Reloaded's), and the Overworld Menu once you add **Trainer Card** to a page (Edit Pages; it isn't on one by default).

**Reloaded Trainer Card** (KIF Settings > Kanto Reloaded > Reloaded Systems, On by default) switches it. Off gives the game's own card back. The counts on Records and Stats keep going either way, so nothing is lost while it's Off.

## How It Looks

- **The art:** Your card's background, as PIF has it (the Trainer Card Printers and the Sprite Gallery still sell them). Around the art, where PIF's frame was, a mat in the art's own edge colour.
- **The plates:** Glass White in Light and Frost Theme Mode, Glass Charcoal in Dark and Glass, until you pick a Plate Color in Style. On busy or dark art the glass is made stronger, so the words stay easy to read.
- **The words:** In PIF's own colours with their shadows: dark on a light plate, made brighter on a deep one. Tags, badges, hints and the ID number have no shadow.

## The Tabs

- **Front:** A lanyard ID card: your trainer's photo, name, title (Pokémon Trainer) and full Trainer ID; Money (green), Platinum (only with Multiplayer installed), Pokédex (base Pokémon owned of 576, counting those owned as part of a fusion, coloured by how much of it you have), Time (blue) and Started (coloured by the season). Under them your Run Tags (Randomized, Nuzlocke, your difficulty, Debug) and the badge case (Kanto, then Johto after the League). Your trainer stands on the art with your Showcase: three Pokémon of yours (picked in Style; your party fills an empty slot), each tile bordered in its types (the left half its first type, the right half its second).
- **Records:** The card's back with your trainer battles: Wins, Losses, Battles, Best Streak, Current Streak and Gym Rematches, then **Recent Battles**: the last three trainers you fought, each with their face, class and name and WIN or LOSS. Your Win Rate is under your trainer.
- **Stats:** The card's back with eight stats and their item icons: Steps, Caught, Fusions Made, Eggs Hatched, Shinies Found, Trades, Levels Gained and Hall of Fame. Under your trainer, the **Next Milestone**: the one you're closest to (or the one you Track), with its bar and what it unlocks.
- **Style:** The Dressing Room. Down the left, the groups with how many you have: Backgrounds, Plate Colors, Titles, Showcase, Badge Cases, Run Tags. On the right, the group's pick: Left and Right try another on (a plate tints the whole screen, a background changes the art) and A keeps it. Leaving with a change you haven't kept asks **Keep These Changes?** (Keep, or Put Back). On Showcase, Left and Right pick a slot and A opens **Showcase Slot**: your party, then your boxes; A puts the Pokémon there, X clears the slot. Your Money is under it, with your clothes and hats.
- **Unlocks:** Every unlock, by category: Backgrounds, Plate Colors, Titles, Badge Cases, Run Tags. Each shows what it needs and how far along you are; the one picked is previewed with where it comes from. A buys a background a Printer would sell you here (**Buy a Background?**, at the Printers' price), or shows an unlock's details, where **Track It** makes it the Stats tab's Next Milestone.

## PIF's Backgrounds, Fixed

For everyone, with the Reloaded Trainer Card On or Off (`Core/Fixes/CardBackgrounds.rb`): the Sewers background shows (its picture's file name has a space), the Sprite Gallery offers Lugia's team flag and sells Froslass's as Froslass's (it was sold as Pikachu's), and Cinnabar's Printer leaves off its background until it has a picture.

## Using It

| Button | Does |
|---|---|
| LB / RB | The tab before or after (Left / Right too, on Front, Records and Stats) |
| A | Actions: Save as Image, Copy Trainer ID (on Style: Keep; on Unlocks: Buy or Details) |
| B | Close |

With the mouse, a click on a tab opens it, and the hints at the bottom can be clicked. A right click closes the card.

- **Save as Image:** Writes the card as a picture, twice its size (1024 x 768), into the **Trainer Cards** folder in Kanto Reloaded's folder (`Mods/KantoReloaded/Trainer Cards`). **Card Saved** shows it, with Open Folder (on a phone: Copy the Path).
- **Copy Trainer ID:** Puts your full Trainer ID on the clipboard, for a friend's Secret Base, and says so at the top. Where there's no clipboard (a phone), **Couldn't Copy** shows the ID to write down.

## What Can Be Unlocked

| Group | From the Start | To Unlock |
|---|---|---|
| Plate Colors | Glass White, Glass Charcoal | Gold, Silver, Bronze, Ruby, Sapphire, Emerald, Rose Gold, Topaz, Amethyst, Aquamarine, Rose Quartz, Onyx |
| Badge Cases | Glass | Leather, Velvet, Denim, Wood, Cork, Steel, Royal |
| Run Tags | Pills | Solid, Plates, Dots |
| Titles | Pokémon Trainer | 7 for the story (Rookie, Gym Challenger, Badge Master, Champion, Johto Challenger, Two-Region Champion, Mt. Silver Legend), 17 for milestones, and Hard-Mode Champion |
| Backgrounds | Yours | PIF's (its Printers and the Sprite Gallery, as before) and two only Kanto Reloaded gives: Explosion (500 wins) and 500000 Flag (500,000 steps) |

- **Milestones:** Each stat and record has tiers, and each tier gives one unlock: Wins 10 gives the Bronze plate, Fusions Made 1 the Plates Run Tags, Steps 10,000 the Denim case, and so on (Unlocks lists them all).
- **Hard Rewards:** Beating the League on Hard gives the Hard-Mode Champion title, the Onyx plate and the Royal case. Lowering the difficulty later keeps them.
- **A New Unlock** shows a toast on the map when it's earned. A save that's already reached some when the card first sees it gets them without toasts.
- **Backgrounds bought here** cost what a Printer would charge ($250, then $500 more after each one, wherever you buy it), and only the ones a Printer would sell you where you are.

## What Counts

| Shown | Counted |
|---|---|
| Wins, Losses, streaks, Recent Battles | Trainer battles only. Link battles, the battle facilities and Multiplayer's battles are left out. Counting starts the first time Kanto Reloaded sees the save; Losses start from the game's own count |
| Gym Rematches | The game's own count (the Fighting Arena's leader rematches) |
| Caught | Every catch from now, started with the Pokémon you own that you met yourself |
| Shinies Found | Every shiny you meet in a wild battle, catch, hatch or receive, each one once |
| Levels Gained | Levels your Pokémon gain from now (battles, candies, Super Candy), started with how far each Pokémon you own is above the level it was met at |
| Steps, Fusions Made, Eggs Hatched, Trades, Hall of Fame | The game's own counts, read as they are |

Kanto Reloaded's counts are kept in your save, with the rest of its data.

## For Mod Makers

```ruby
Reloaded::TrainerCard::Counters.get(:wins)          # one of Kanto Reloaded's counts
Reloaded::TrainerCard::Counters.stat(:steps)        # any stat or record, the game's own too
Reloaded::TrainerCard::Counters.add(:caught, 1)     # a catch your mod makes outside a battle
Reloaded::TrainerCard.open                          # the card, faded in
Reloaded::TrainerCard::Unlocks.register(:titles, :rival_slayer, :name => "Rival Slayer",
  :need => "Beat Your Rival 10 Times", :from => "My Mod", :check => proc { true when earned })
```

`:card_unlocked` (`:category`, `:id`, `:quiet`) is raised when an unlock is earned.

Kanto Reloaded's scene is a subclass of the game's `PokemonTrainerCard_Scene`, made whenever the game makes one while the card is on, and `PokemonTrainerCardScreen` still runs it. Multiplayer's Platinum is read from `MultiplayerPlatinum.cached_balance`, and its own refresh is asked for once when the card opens.
