# Trainer Control

Trainers that keep up with you, learn from you, and remember you. This is Roadmap topic trainer-control. It's always on with Kanto Reloaded, with no switch; each part gets its own row per save as it arrives.

The code is in `Core/TrainerControl/TrainerControl.rb` (who a trainer is, which battles count, the hooks), `Records.rb` (the records), `Bond.rb` (the bond steps), `Pictures.rb` (the trainers' faces), `Toasts.rb` (the toasts) and `Core/UI/BattleRecordsScreen.rb` (the screen).

## Records

Kanto Reloaded keeps a record of every trainer you battle.

- **One per person:** a trainer is their class and name (Youngster Joey), every version of them together: a Gym Leader's gym and Fighting Arena battles are one record. Your rival is one record, whatever the battle (the game's rival classes: RIVAL1, RIVAL2 and CHAMPION, named by the name you gave him).
- **What's kept:** wins, losses, the current and best streak, where and when you first met and last battled, their team in the last battle, the versions you've met, how many rematches, and who knocked out whom (your Pokémon that knocked out the most of theirs, and theirs that knocked out the most of yours).
- **Kinds:** leaders (Gym Leaders, the Elite Four, other Champions, Team Rocket's bosses: Giovanni and his executives, Archer and Ariana), your rival, and trainers.
- **No resets:** records are your save's history.

### Which Battles Count

| Counted | Not counted |
|---|---|
| Every trainer from the game's data; in a battle the story lets you lose (your first rival battle), only a win | Other mods' wandering trainers (made at runtime, with no data) |
| Trainers an event builds with a real class (by class and name): Kanto's Elite Four rematches, Hoenn's rival and rematch trainers, the Fossil Maniac, the sprite-credit battles | KIF's Self-Battle |
| Each trainer in a double battle | The Endgame Challenge's maps (its League, Fighting Arena and Mt. Silver battles) |
| | The battle facilities, link battles, Multiplayer's battles |
| | A battle with no winner |

### Saves From Before

Once per save:

- **Kanto Reloaded Legacy:** a save played with it brings its records in, merged by person (its rival's versions become one record). Its records of other mods' runtime trainers are left out.
- **The game's rematch counts:** a trainer you've rematched before shows how many times ("Rematched 5 Times Before Records"). No wins or losses are made up.

The records are kept in your save, with the rest of Kanto Reloaded's data.

## Level Scaling

Trainers that keep up with you, always on. One setting on the Level Scaling page of Trainer Control in Reloaded Settings, per save: Rematch Money.

- **The Badge Curve:** The game's level cap for your badges (the next Gym Leader's level; Hard's 10% is in it), less 4 for regular trainers.
- **Trainers:** On your first battle, a trainer whose strongest Pokémon is under the curve rises three quarters of the way to it (half on Easy). Never down.
- **Rematches:** A rematch starts at the curve and climbs a level each time, up to your party's level (past it by a trainer's Rematch Rank: 1 to 4 levels), then keeps pace with it; never below the curve or the trainer's own levels. This replaces the game's own rematch levels; its rematch evolutions stay. Rematches give half the EXP.
- **Rematch Money:** The game pays nothing for rematches. With this On, the first rematch each day with a trainer pays half the usual prize, then a quarter, then a tenth, then nothing until the next day.
- **Leaders:** Gym Leaders, the Elite Four, Champions and Team Rocket's bosses come at your party's level, never below their own. On Hard, 10% above it. On Easy, as the game wrote them.
- **Rival:** Your rival comes at your party's level, as the leaders do: 10% above it on Hard, as the game wrote them on Easy.
- **Your Party's Level:** The higher of its average and your highest less 2 (no Eggs), so one strong Pokémon and a few low ones can't drag it down.
- **How a Team Rises:** Its strongest Pokémon goes to the new level and the rest keep their gaps under it.
- **Built for It:** A raised Pokémon evolves as far as its new level allows, gets the moves it would know at that level (a trainer's hand-written moves stay), and the game's IVs and EVs for that level (Hard's minimum IVs after).
- **Battle Info:** A raised foe shows a green +12 (how many levels) beside its level.

Nothing is scaled with the game's own battle-level override on, for a partner you're given, in the battle facilities, KIF's Self-Battle or the Endgame Challenge's maps.

## Leader Builds

Gym Leaders, the Elite Four, Champions, Team Rocket's bosses and your rival bring built teams on Normal and Hard (Easy is as the game makes them). Always on, no row. The code is in `Core/TrainerControl/LeaderBuilds.rb`.

- **IVs:** Normal: 10 at the first gym, rising to 31 by the eighth (by your badges). Hard: 31.
- **EVs:** 252 in each of its two role stats: on Normal a share for each gym, all of it by the eighth; on Hard from the start. Its other stats keep what the game gave them, as far as 510 in all allows.
- **Nature:** Raises its Speed when it's faster than it hits, otherwise its better attack, and lowers the attack it doesn't use (Jolly, Adamant, Timid, Modest). Its role stats are its better attack, and Speed (fast) or HP (slow).
- **Ability:** The best it can have. An ability the game's data sets for it stays.
- **Written Builds:** IVs, EVs and natures the trainer data writes (Expert Mode's trainers write more of them) are never lowered: each value is the higher of the two, and a written nature stays.

## Trainer Bags

Every trainer carries a bag for their team on Normal and Hard (Easy is as the game makes them). Always on, no row. The code is in `Core/TrainerControl/TrainerBags.rb`.

- **How Many:** 2 items, 3 from 4 badges. Leaders the same; the Elite Four and Champions one more; Hard one more each. A Master trainer (Rematch Ranks) one more.
- **Which:** First the X item for their ace's best stat (X Speed for a fast one, X Attack for a hitter), from the start. Then healing for your badges: Potion, Super Potion (2 badges), Hyper Potion (4), Max Potion (6), Full Restore (8). The third item is a Full Heal; any more are healing.
- **Never Less:** What the trainer data gives them stays, and the bag fills up to its size around it. Items Adaptation taught them come on top.

## Gym Rules

Every Gym Leader, the Elite Four and Champions bring a rule on Normal and Hard: a condition that lasts the whole battle, by their type (it follows Remix and randomized gyms). The code is in `Core/TrainerControl/GymRules.rb`.

| Type | First Choice | Backup | With KIF: Elite Redux |
|---|---|---|---|
| Normal | Rainbow | Safeguard | Same |
| Fire | Sun | Sea of Fire | Same |
| Water | Rain | Swamp | Same |
| Electric | Electric Terrain | Light Screen | Same |
| Grass | Grassy Terrain | Sun | Backup: Creeping Thorns |
| Ice | Hail | Mist | Same |
| Fighting | Gravity | Reflect | Same |
| Poison | Toxic Spikes (2 layers) | Spikes | First: Toxic Terrain, Backup: Toxic Spikes |
| Ground | Spikes | Sandstorm | Same |
| Flying | Tailwind | Strong Winds | Same |
| Psychic | Psychic Terrain | Light Screen | Backup: Inverse Room |
| Bug | Sticky Web | Spikes | Same |
| Rock | Sandstorm | Stealth Rock | Same |
| Ghost | Trick Room | Wonder Room | First: Fog, Backup: Trick Room |
| Dragon | Tailwind | Reflect | Same |
| Dark | Spikes (2 layers) | Toxic Spikes | First: Smokescreen, Backup: Spikes |
| Steel | Reflect | Stealth Rock | Backup: Caltrops |
| Fairy | Misty Terrain | Safeguard | Same |

- **Which:** The first choice, unless it would hinder more than 2 of their Pokémon (the ace counts like any) or one of their Pokémon brings its own weather or terrain that would clash; then the backup; then Stealth Rock. KIF: Elite Redux's column applies as a pair when what it brings of its own is On (its New Battle Effects for Fog, Toxic Terrain and Inverse Room; its Moves for Smokescreen, Creeping Thorns and Caltrops).
- **How Many:** One; on Hard both (each that fits), and the Elite Four and Champions bring two on Normal too.
- **Elite Trainers:** An ordinary trainer at Rematch Ranks' Elite brings their type's rule too (one, even on Hard), said with its line (no seal).
- **When:** Weather and terrain from the start, in the game's own words. The rest once both Pokémon are out, so your lead isn't hit by a hazard it didn't walk into, each with its line.
- **The Whole Battle:** Screens, Tailwind, rooms and the rest come back at each round's end and show as endless in the Field Strip and Battle Info; weather and terrain return after anything replaces them; hazards stay until cleared.
- **The Leader's Seal:** Once both Pokémon are out, a seal pops up over the dimmed battle (the message box stays clear): the leader's face on a plate in their type's colour, their rule or rules large with each one's type and whose side it's on (Your Side, Their Side, Whole Field). Each rule's line shows in the message box while it's up; then it shrinks away toward the Field Strip, where each rule's chip stays. Its sound is the Trainer Card opening. EBDX and the game's own battle screen alike. The code is in `Core/UI/GymRuleSeal.rb`.

## Notoriety

Word of you gets around. On Normal and Hard (Easy is as the game makes them), your first win over each trainer adds one to your Notoriety (beating them again in a rematch doesn't), and the trainers you meet get tougher as it climbs. A loss to someone you've never beaten drops you to the start of the tier below (from Feared at 14 back to Known's 5), never all the way unless you were Known; a rematch never raises or drops it. Always on, no row. The code is in `Core/TrainerControl/Notoriety.rb` and `Core/UI/NotorietyToast.rb` (its toast).

- **Known (5 Wins):** Every trainer adapts one more way: one more change on a first meeting and from each win (Adaptation).
- **Feared (10 Wins):** Leaders bring their counter Pokémon, and every trainer's ace comes fully built, as a leader's would be (Leader Builds), and gets its Ace Moment.
- **Infamous (20 Wins):** Every trainer comes 2 levels higher, over Level Scaling.
- **The Toast:** Back on the map after the battle that reaches a tier or drops you from one: the tier's diamonds (one for Known, two for Feared, three in a triangle for Infamous) and name on a plate in its colour (Known orange, Feared red, Infamous purple), the line ("Trainers start to fear you...", or "Word of your loss spreads..." under DOWN FROM FEARED), what changes, and the three tiers as pills, the new one lighting up a moment in. Reaching a tier plays Exclaim; a drop plays Voltorb Flip's level drop.
- **On the Trainer Card:** Among the facts on the Front and on Records, the tier's name in its colour beside three diamonds, the tiers you've reached lit (Unknown under Known, all three grey).

## Ace Moments

A trainer's ace makes an entrance on Normal and Hard (Easy is as the game makes it): Gym Leaders, the Elite Four, Champions, Team Rocket's bosses and your rival every battle, every other trainer once you're Feared. Always on, no row. The code is in `Core/TrainerControl/AceMoments.rb` and `Core/UI/AceMoment.rb` (how it looks).

- **The Ace:** The Pokémon holding a Mega Stone (with Megas installed), otherwise their highest level.
- **Their Line:** Before the ace is sent out, the battle dims; the trainer slides in from the right onto their own side, twice their size, and their line slides in from the left over the foe's databox spot, in a big pill with their class and name in their type's colour. Each leader has their own line ("Onix, show them what we trained for!"); other trainers have one for their kind of class. A or B moves it on. Its sound is the VS flash.
- **The Boost:** Once the ace is out, it Mega Evolves when it can, then its best stat rises one stage (Hard: its two best). The ACE pill slides in from the right under the foe's databox: the ace's icon and name, ACE, and each raised stat in green. Its sound is the ability pop-up's.
- **Mega Stones:** On Hard, the leaders' aces hold their Mega Stone from your 4th badge; on Normal, as Megas gives them (after Silph Co).
- **An Ace That Leads:** It gets its whole moment once the battle has opened (after the Leader's Seal). Dragged in by a move like Roar, it skips the line and only gets the boost.

## Rematch Ranks

The more you beat a trainer, the higher they rank, on Normal and Hard (Easy is as the game makes them). Ordinary trainers only: leaders already bring their builds, rules and Ace Moments. Always on, no row. The code is in `Core/TrainerControl/RematchRanks.rb` and `Core/UI/RankToast.rb` (the rank-up toast).

- **Seasoned (3 Wins):** One more Pokémon.
- **Veteran (7 Wins):** Their ace comes fully built (Leader Builds).
- **Elite (12 Wins):** One more Pokémon again, and their type's Gym Rule.
- **Master (22 Wins):** Every Pokémon fully built, and one more item in their bag.
- **Levels Past You:** Each rank lets their rematches keep climbing past your party's level, a level a rematch, up to 1 over at Seasoned, 2 at Veteran, 3 at Elite and 4 at Master.
- **Shown:** The rank's word in its colour on Battle Records (over the name on their record, before the class in the list) and in the record toast ("Veteran Hiker Marcos").
- **Ranking Up:** Back on the map after the win that reaches a rank, a card: their face on a plate in the rank's colour with its insignia (Seasoned one chevron, Veteran two, Elite three, Master a star), PROMOTED and their class over their name, your record with them, four stars with the new one popping in, NOW A VETERAN. Its jingle is BW_lvup. Another toast already up goes first.
- **Their Pokémon:** Added the way Team Expansion adds them (its What Joins Them row), even with Team Expansion Off; never past six.

## Team Expansion and the Gyms

How many Pokémon trainers and leaders bring, and how many you bring to gyms: the Teams page of Trainer Control in Reloaded Settings, per save. Kanto Reloaded takes over KIF's Gym Leader Teams settings (Gym Leader teams, Your Pokémon in gyms): they're hidden while it's installed, and your choices there come across the first time a save loads.

- **Team Expansion:** Off to start. **Add Count** gives each trainer 1 to 5 more Pokémon; **Target Size** brings each up to at least 1 to 6. Never past six.
- **What Joins Them:** **Local Theme** (to start): the trainer's class type (a Hiker's Rock), from the wild Pokémon of the trainer's own map first, then any of that type. **Random**: any Pokémon, fused as often as the rest of their team. **Random Fusion**: always a fusion. Whatever joins is about as strong as the team, at its level, never legendary or banned, and the same every battle for your save.
- **Leaders:** Gym Leaders, the Elite Four, Champions, Team Rocket's bosses and your rival: **Normal**, **Add Count**, **Target Size** or **Full Party** (six). What joins a leader is always their gym's type; your rival's, their own team's.
- **Held Items:** An added Pokémon may hold an item: none before 2 badges, a quarter of the time at 4, half from 8. It's picked for its moves and type (a Rock type might hold a Hard Stone; an attacker a Life Orb). With the Randomizer's random held items on, those decide.
- **Pokémon in Gyms:** How many you may pick before a Kanto Gym Leader battle: **Follow the Leader** (to start: as many as the leader brings; the game's own limit while Leaders is Normal), **Normal**, **+1**, **+2** or **Full**. The leaders' lines say the real numbers.
- **2v2 and 3v3:** With KIF's Battle Format on for trainers, a trainer short of Pokémon gets just enough to fill their side, even with Team Expansion Off.
- **Randomized Saves:** With the Randomizer's random trainers, its Team size and Leader team size decide; these rows lock and say so.

Team Expansion adds before Level Scaling raises, so added Pokémon rise with the team.

## Smarter Trainers

Trainers think with DemICE's AI (KIF's Battle AI, from the community hard-mode mods) on every save: KIF's Battle AI row is locked to DemICE (Set by Kanto Reloaded). It plays at its top skill on every difficulty. The code is in `Core/TrainerControl/Smarter.rb`.

## Adaptation

Trainers learn from you. Always on, no row: it's how trainers think. Nothing shows before it happens: once a battle reveals a move or item a trainer learned from you, Battle Info's tab for that Pokémon marks it with a purple ADAPTED pill.

- **Your Habits:** Your last 5 trainer battles: the Pokémon you sent out first, the move types you use most, and your strongest Pokémon. Only damaging moves that landed count toward your move types, by the type they hit with (Weather Ball in rain is Water); status moves, moves that failed and misses don't, and a move Metronome or Sleep Talk calls counts once.
- **First Meetings:** Word gets around. From 2 badges, a trainer you've never battled makes one change from your habits: a lead with a type that hits yours hard (no change when none of theirs does), a move it can learn that hits your lead hard, a move that hits your strongest Pokémon hard (when it isn't your lead), or a berry that softens your favourite type (an Occa Berry against your Fire). Never a new Pokémon.
- **Rematches:** Each time you beat a trainer, they remember how you fought them and make 2 changes. Changes stay and build up, at most 2 per Pokémon, plus one lead change (the newest), up to 2 bag items and a counter Pokémon; newer ones replace the oldest. An evolution moves a Pokémon up one stage once its level + 5 reaches it (a fusion: its head first, else its body), and a later one takes it further; it stays for good and isn't one of the 2, so a trainer's Pokémon never goes back a stage, and each change stays on the same Pokémon. Lose to them and nothing changes, so you can try the same fight again: a first meeting's change stays too. The moves they learn stay when Level Scaling raises their levels, never push out each other, and a stronger move is never a step down.
- **What Changes:** Half answer your habits (resist berries, counter moves against your lead or your strongest Pokémon, the lead, the counter Pokémon), half can be anything a trainer does (a bulk item like Leftovers, a held item, a bag item, a bulk-up move, a status move, a stronger move, an evolution), three times as likely to be their class's own: Hikers, Bikers, Police and other strong classes bulk up; Psychics, Channelers, Super Nerds and Team Rocket's grunts favour status moves; Cooltrainers, Gentlemen, Rangers, Type Experts, Rocket's executives and leaders use items; the rest hit harder (an evolution, a stronger move they've learned, a held item). Their strongest Pokémon is never replaced. Every change does something to their team: a resist berry only on a Pokémon weak to that type, a move only on one that can learn it, an evolution only on one that can still evolve, an item only on one without an Adaptation item already, and a new lead only when one of theirs hits yours hard; when nothing fits, they make a different change. With the Randomizer's Held Items on, an Adaptation item replaces the random one on the Pokémon it goes on; the rest keep theirs.
- **The Counter Pokémon:** A fusion of their class's type and a type that beats your lead (a Bug Catcher against your Fire lead: a Bug/Rock or Bug/Water fusion), as strong as their team as written (a Pokémon Team Expansion or a Rematch Rank adds doesn't change it), at its level, never a Pokémon your lead hits hard, and with a move that hits your lead hard. It's made each rematch to beat the lead you've used most in your last 3 battles with them (its whole typing: Fire/Flying for a Charizard), so it follows a change of team. It takes their lowest-level Pokémon's place (never their ace), so teams stay the size the game made them; a trainer with only their ace gets it as a second Pokémon.
- **On Easy:** Lighter: no first meetings, one change fewer from each win (1; leaders and your rival 2), and no counter Pokémon, not even one they learned on a harder difficulty.
- **Leaders and Your Rival:** One more change each time (2 on a first meeting). Leaders bring their counter Pokémon only once you're Feared (Notoriety); a loss that drops you to Known puts it back.
- **Fair Rolls:** Every change comes from your save, the trainer and how many times you've beaten them, so loading a save gives the same team, counter Pokémon included; a change does the same thing however many older ones have gone. A trainer's every version shares one memory of you.
- **Teams an Event Builds:** Kanto's Elite Four rematches, Hoenn's rival and rematch trainers, the Fossil Maniac and the sprite-credit battles adapt too (the Elite Four as leaders), on a copy of the team the event hands in, so nothing builds up on it.

## Pink Slips

Wager a Pokémon against a trainer's. The Pink Slips row on the Trainer Control page is On to start; Off, none drop, sell or are offered.

- **The Item:** A Pink Slip. A trainer's gift can be one (their 3-win gift and the gifts at 20, 30, 40 and 50 wins), and the Celadon Department Store's battle items counter (beside the X items) sells them for $10,000.
- **The Question:** When a regular trainer challenges you one on one and you hold a Pink Slip, they ask "Use a Pink Slip?" before the battle: **Wager** or **Just Battle**. Never Gym Leaders, the Elite Four, Champions, your rival, Team Rocket's bosses or teams an event builds; never two trainers at once; never in a battle the story lets you lose, never when your party and PC are both full, or when nothing could be staked. Each trainer wagers once, ever.
- **Choose Your Stake:** Your stake on the left, VS their team on the right, your party below with a reason under each you can't stake: FAINTED, BELOW LV. 12 (more than 10 levels under your highest), CAN'T BATTLE (an Egg). Their team shows the levels it will have in the battle. A win claims one of theirs at your stake's level or lower: those above it fade, and the Win line at the foot says what you can claim ("Claim one of Marcos's at Lv. 19 or lower (three of four)"); a stake that can win nothing says so and can't be staked. Left and Right choose, A stakes, Y shows its Summary, B just battles. The Pink Slip is used when you stake.
- **Win:** Claim Your Prize opens right after the battle: any one of their team at your stake's level or lower (the rest fade and say ABOVE LV. 19, and the cursor passes them), as it fought you (its moves, nature and ability; its held item stays with them). It's yours like a trade (they stay its trainer, and a Pokémon from a trade may not obey above your badges' level), into your party or the PC. With KIF's Nuzlocke, it counts as a gift.
- **Lose:** The Pokémon you staked goes with them for good; its held item comes back to your Bag. You hear about it once you wake in the Pokémon Center.
- **No Winner:** The Pink Slip comes back.
- **The Record:** Battle Records shows the story ("Won Their Graveler", "Lost Your Pidgeotto"), and the Pink Slips filter lists who you can still wager, then everyone you've wagered with. The record toast shows PINK SLIP when you hold one and they'd take it.

## Battle Records

Every trainer you've battled, on one screen. Open it from its row on the Trainer Control page of Reloaded Settings, the Trainer Card's Records side (Actions, then Battle Records), or the Overworld Menu (add Battle Records to a page).

- **The List:** Each trainer's face, name and class (their Rematch Rank before it, in its colour), and your record with them (green when you're ahead, red when behind).
- **Filters:** All, Rivalries (trainers you can battle again: their event offers rematches, or they're a Gym Leader, who you can face again at the Fighting Arena), Leaders (Gym Leaders, the Elite Four, Champions and Team Rocket's bosses), Pink Slips, in two groups: Can Wager (trainers you can battle again and haven't wagered yet, while Pink Slips are On), then Wagered (each with how it went: Won Their Graveler, Lost Your Pidgeotto).
- **Sort:** Recent, Name, Battles, Win Rate, Best Streak, Place, Next Step (the nearest bond step first).
- **Search:** Type a name, class or place; a trainer found by a place shows that place in gold.
- **The Record:** Lit in the class's colour (a Gym Leader's gym type, the class's theme): the trainer and where they are, wins, losses, win rate, battles, streak and best, "Rematched 5 Times Before Records" on an older save, a Pink Slip's story ("Won Their Graveler"), the bond steps, the last battle (when, their team, where) and the MVPs: your Pokémon with the most knockouts on them (as it is now) and theirs with the most on yours.

| Button | Does |
|---|---|
| Up / Down | Choose a trainer |
| Left / Right | The filter |
| L | Search (type straight in; a controller's A opens the naming screen) |
| R | Sort |
| Back | Clear the search, or close |

The mouse works too: click a trainer, a filter, Search or Sort; the wheel scrolls.

### Bond Steps

A trainer you can battle again rewards your growing bond: a gift that fits their class at 3 wins, a move from their own team at 7 (they teach it), an Egg of their favourite Pokémon at 12, then a gift at 20, 30, 40 and 50 wins, and the bond is complete. Leaders' steps come at 2, 4 and 6 wins (the gym is the first), then the same four gifts. The record shows three steps: done ones in gold, the next in blue, each with its reward once it's known; a complete bond says Complete.

- **When:** Back on the map after the win that reaches a step. The trainer speaks while a card above their words shows the reward and your bond track, then it's yours.
- **The Gift:** Their class's own: a Fisherman a better Rod, a Hiker a Hard Stone or Moon Stone, a Bug Catcher Silver Powder, an Engineer a Magnet or Thunder Stone; otherwise their type's item or evolution stone. Later gifts can be Rare Candy or PP Ups. A key item you already have is never given twice.
- **The Tutor:** Choose one of your party (each marked ABLE, LEARNED or NOT ABLE: what they can learn from the trainer's team), then the move: its type, category, power, accuracy and which of their Pokémon knows it. It's taught the game's usual way (forgetting a move if it knows four). Skipping the lesson asks first: it isn't offered again.
- **The Egg:** Their favourite Pokémon, their strongest's first stage. It joins your party, or the PC when the party's full.
- **Claimed Stays Claimed:** Each step is given once, whatever happens to the record. On a save from before, a trainer you'd already beaten more than 3 times gives each step you've passed after your next win over them.

## The Toasts

- **Your Record:** When a trainer you've battled before spots you, or you talk to them, a toast shows their face and name, your record with them, then STREAK 3 (from 3 wins in a row) and their next bond step (TUTOR AT 7). Nothing on a first meeting. It's gone before the battle starts. The Record Toast row on the Trainer Control page (On to start) turns it off.
- **Notoriety:** Reaching a tier or dropping from one ([Notoriety](#notoriety)).
- **Rank Up:** A trainer reaching a Rematch Rank ([Rematch Ranks](#rematch-ranks)).

## With Hoenn Essentials

- **Its Rematches:** Hoenn Essentials' Rematch button is a rematch to Trainer Control. Hoenn Essentials decides who's on the team: the trainer's team as written, then the Pokémon it catches, fuses and evolves. Trainer Control decides the levels, on its rematch curve, with Adaptation, Team Expansion and Rematch Ranks on top, half the EXP and Rematch Money.
- **Its Growth:** After a rematch, Hoenn Essentials' own growth (up to your best level + 3) is replaced by Trainer Control's level for the next one. The team still learns its moves and evolves on the way up, and its chat says so. View Team shows the levels you'll fight.
- **Contacts From Before:** Once a save loads, they lose the marks of Trainer Control's old changes and the Pokémon Team Expansion added, and come to Trainer Control's level (down too, when they'd grown past it).
- **Lounge Trainers:** Its battle hook dropped a battle's name and class, so the lounge trainers on Kin Island, in the Triple Battle Lounge, on Mt. Ember and on Mt. Silver Summit showed as "lounge_member". They keep theirs now.

## For Mod Makers

```ruby
Reloaded::TrainerControl.person(trainer)            # "YOUNGSTER|Joey", "rival", or nil when it doesn't count
Reloaded::TrainerControl::Records.get("YOUNGSTER|Joey")   # the record (a Hash), or nil
Reloaded::TrainerControl::Records.mvp(record)       # [your Pokémon { "pid", "species", "name", "kos" }, [their species, kos]]
Reloaded::TrainerControl::Records.list(:rivalries, "moon", 0)   # the screen's rows: a filter, a search, a sort
Reloaded::TrainerControl::Bond.next_step(record)    # [:tutor, 7, 2]: the kind, at how many wins, wins to go
Reloaded::TrainerControl.theme_type(:HIKER)         # :ROCK: a class's own type
Reloaded::TrainerControl.open_records               # the Battle Records screen
Reloaded::TrainerControl::LevelScaling.party_level  # 28: the higher of the party's average and its highest - 2
pokemon.instance_variable_get(:@kr_tc_from)         # a raised trainer Pokémon's level before (Battle Info's +12)
pokemon.instance_variable_get(:@kr_tc_adapted)      # what Adaptation changed: { "item", "moves", "notes" => [{ "kind", "what", "why", "first" }] }
Reloaded::TrainerControl::Notoriety.tier            # the tier now (key, name, wins, rgb), nil under Known or on Easy
Reloaded::TrainerControl::Notoriety.count           # 14: wins since the last loss's drop
Reloaded::TrainerControl::RematchRanks.rank(record)  # their rank (key, name, wins, rgb, index), nil for none or leaders
Reloaded::Events.on(:trainer_battle_ended, :my_mod) { |c| c[:battle], c[:won], c[:people] }
```

Art in `Graphics/Notoriety` (`known.png`, `feared.png` and `infamous.png`, 32 x 32) takes the place of the diamonds on Notoriety's toast.

`:trainer_battle_ended` comes after every trainer battle, counted or not: `:won` is true, false, or nil (no winner), and `:people` lists the records it counted for. The Trainer Card's counts come from it too, so there's one place a battle's end is counted.
