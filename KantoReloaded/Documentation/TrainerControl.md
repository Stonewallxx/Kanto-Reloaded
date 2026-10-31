# Trainer Control

Trainers that keep up with you, learn from you, and remember you. This is Roadmap topic trainer-control. It's always on with Kanto Reloaded, with no switch; each part gets its own row per save as it arrives.

The code is in `Core/TrainerControl/TrainerControl.rb` (who a trainer is, which battles count, the hooks), `Records.rb` (the records), `Bond.rb` (the bond steps), `Pictures.rb` (the trainers' faces), `Toasts.rb` (the toasts) and `Core/UI/BattleRecordsScreen.rb` (the screen).

## Records

Kanto Reloaded keeps a record of every trainer you battle.

- **One per person:** a trainer is their class and name (Youngster Joey), every version of them together: a Gym Leader's gym and Fighting Arena battles are one record. Your rival is one record, whatever the battle (the game's rival classes: RIVAL1, RIVAL2 and CHAMPION, named by the name you gave him).
- **What's kept:** wins, losses, the current and best streak, where and when you first met and last battled, their team in the last battle, the versions you've met, how many rematches, and who knocked out whom (your Pokémon that knocked out the most of theirs, and theirs that knocked out the most of yours).
- **Kinds:** leaders (Gym Leaders, the Elite Four, other Champions, Rocket bosses), your rival, and trainers.
- **No resets:** records are your save's history.

### Which Battles Count

| Counted | Not counted |
|---|---|
| Every trainer from the game's data, battles you're allowed to lose too | Other mods' wandering trainers (made at runtime, with no data) |
| Trainers an event builds with a real class (by class and name) | KIF's Self-Battle |
| Each trainer in a double battle | The Endgame Challenge's maps (its League, Fighting Arena and Mt. Silver battles) |
| | The battle facilities, link battles, Multiplayer's battles |
| | A battle with no winner |

### Saves From Before

Once per save:

- **Kanto Reloaded Legacy:** a save played with it brings its records in, merged by person (its rival's versions become one record). Its records of other mods' runtime trainers are left out.
- **The game's rematch counts:** a trainer you've rematched before shows how many times ("Rematched 5 Times Before Records"). No wins or losses are made up.

The records are kept in your save, with the rest of Kanto Reloaded's data.

## Level Scaling

Trainers that keep up with you. Each kind has its own row on the Level Scaling page of Trainer Control in Reloaded Settings, per save, all On to start.

- **The Badge Curve:** The game's level cap for your badges (the next Gym Leader's level; Hard's 10% is in it), less 4 for regular trainers.
- **Trainers:** On your first battle, a trainer whose strongest Pokémon is under the curve rises part of the way to it (**How Far They Rise**: a quarter, half, three quarters or all the way; Half to start). Never down.
- **Rematches:** A rematch starts at the curve and climbs a level each time, up to your party's level, then keeps pace with it; never below the curve or the trainer's own levels. This replaces the game's own rematch levels; its rematch evolutions stay. Rematches give half the EXP.
- **Rematch Money:** The game pays nothing for rematches. With this On, the first rematch each day with a trainer pays half the usual prize, then a quarter, then a tenth, then nothing until the next day.
- **Leaders:** Gym Leaders, the Elite Four, Champions and Rocket bosses come at your party's level, never below their own. On Hard, 10% above it.
- **Rival:** Your rival comes at your party's level, as the leaders do.
- **Your Party's Level:** The higher of its average and your highest less 2 (no Eggs), so one strong Pokémon and a few low ones can't drag it down.
- **How a Team Rises:** Its strongest Pokémon goes to the new level and the rest keep their gaps under it.
- **Built for It:** A raised Pokémon evolves as far as its new level allows, gets the moves it would know at that level (a trainer's hand-written moves stay), and the game's IVs and EVs for that level (Hard's minimum IVs after).
- **Battle Info:** A raised foe shows a green +12 (how many levels) beside its level.

Nothing is scaled with the game's own battle-level override on, for a partner you're given, in the battle facilities, KIF's Self-Battle or the Endgame Challenge's maps.

## Team Expansion and the Gyms

How many Pokémon trainers and leaders bring, and how many you bring to gyms: the Teams page of Trainer Control in Reloaded Settings, per save. Kanto Reloaded takes over KIF's Gym Leader Teams settings (Gym Leader teams, Your Pokémon in gyms): they're hidden while it's installed, and your choices there come across the first time a save loads.

- **Team Expansion:** Off to start. **Add Count** gives each trainer (and your rival) 1 to 5 more Pokémon; **Target Size** brings each up to at least 1 to 6. Never past six.
- **What Joins Them:** **Local Theme** (to start): the trainer's class type (a Hiker's Rock), from the wild Pokémon of the trainer's own map first, then any of that type. **Random**: any Pokémon, fused as often as the rest of their team. **Random Fusion**: always a fusion. Whatever joins is about as strong as the team, at its level, never legendary or banned, and the same every battle for your save.
- **Leaders:** Gym Leaders, the Elite Four, Champions and Rocket bosses: **Normal**, **Add Count**, **Target Size** or **Full Party** (six). What joins a leader is always their gym's type.
- **Held Items:** An added Pokémon may hold an item: none before 2 badges, a quarter of the time at 4, half from 8. It's picked for its moves and type (a Rock type might hold a Hard Stone; an attacker a Life Orb). With the Randomizer's random held items on, those decide.
- **Pokémon in Gyms:** How many you may pick before a Kanto Gym Leader battle: **Follow the Leader** (to start: as many as the leader brings; the game's own limit while Leaders is Normal), **Normal**, **+1**, **+2** or **Full**. The leaders' lines say the real numbers.
- **2v2 and 3v3:** With KIF's Battle Format on for trainers, a trainer short of Pokémon gets just enough to fill their side, even with Team Expansion Off.
- **Randomized Saves:** With the Randomizer's random trainers, its Team size and Leader team size decide; these rows lock and say so.

Team Expansion adds before Level Scaling raises, so added Pokémon rise with the team.

## Adaptation

Trainers learn from you. Always on, no row: it's how trainers think, and nothing about it shows on screen.

- **Your Habits:** Your last 5 trainer battles: the Pokémon you lead with, the move types you use most, and your strongest Pokémon.
- **First Meetings:** Word gets around. From 2 badges, a trainer you've never battled makes one change from your habits: a lead that beats yours, a move it can learn that hits your lead hard, or a berry that softens your favourite type (an Occa Berry against your Fire). Never a new Pokémon.
- **Rematches:** Each time you beat a trainer, they remember how you fought them and make 3 changes (4 from your seventh win over them). Changes stay and build up, at most 2 per Pokémon plus a counter Pokémon; newer ones replace the oldest. Lose to them and nothing changes, so you can try the same fight again.
- **What Changes:** Half answer your habits (resist berries, counter moves, the lead, the counter Pokémon), half follow their class: Hikers and other strong classes bulk up, Psychics and Channelers favour status moves, Ace Trainers, Gentlemen and leaders use items, the rest hit harder (an evolution, a stronger move they've learned). Their strongest Pokémon is never replaced.
- **The Counter Pokémon:** A fusion of their class's type and a type that beats your lead (a Bug Catcher against your Fire lead: a Bug/Rock or Bug/Water fusion), as strong as their team, at its level. It joins, or takes their weakest Pokémon's place on a full team.
- **Leaders and Your Rival:** One more change each time (2 on a first meeting). Leaders bring their counter Pokémon only while your win streak (the Trainer Card's) is 10 or more; a loss puts it back.
- **Fair Rolls:** Every change comes from your save, the trainer and how many times you've beaten them, so loading a save gives the same team. A trainer's every version shares one memory of you.

## Pink Slips

Wager a Pokémon against a trainer's. The Pink Slips row on the Trainer Control page is On to start; Off, none drop, sell or are offered.

- **The Item:** A Pink Slip. A trainer's gift can be one (their 3-win gift and the gifts every 10 wins after), and the Celadon Department Store's battle items counter (beside the X items) sells them for $10,000.
- **The Question:** When a regular trainer challenges you one on one and you hold a Pink Slip, they ask "Use a Pink Slip?" before the battle: **Wager** or **Just Battle**. Never Gym Leaders, the Elite Four, Champions, your rival, Rocket bosses or teams an event builds; never two trainers at once; never when your party and PC are both full, or when nothing could be staked. Each trainer wagers once, ever.
- **Choose Your Stake:** Your stake on the left, VS their team on the right, your party below with a reason under each you can't stake: FAINTED, BELOW LV. 12 (more than 10 levels under your highest), CAN'T BATTLE (an Egg). What winning and losing mean is at the foot. Left and Right choose, A stakes, Y shows its Summary, B just battles. The Pink Slip is used when you stake.
- **Win:** Claim Your Prize opens right after the battle: any one of their team, as it fought you (its moves, nature and ability; its held item stays with them). It's yours like a trade (they stay its trainer, and a Pokémon from a trade may not obey above your badges' level), into your party or the PC. With KIF's Nuzlocke, it counts as a gift.
- **Lose:** The Pokémon you staked goes with them for good; its held item comes back to your Bag. You hear about it once you wake in the Pokémon Center.
- **No Winner:** The Pink Slip comes back.
- **The Record:** Battle Records shows the story ("Won Their Graveler", "Lost Your Pidgeotto"), and the Pink Slips filter lists everyone you've wagered with. The record toast shows PINK SLIP when you hold one and they'd take it.

## Battle Records

Every trainer you've battled, on one screen. Open it from its row on the Trainer Control page of Reloaded Settings, the Trainer Card's Records side (Actions, then Battle Records), or the Overworld Menu (add Battle Records to a page).

- **The List:** Each trainer's face, name and class, and your record with them (green when you're ahead, red when behind).
- **Filters:** All, Rivalries (trainers you can battle again: their event offers rematches, or they're a Gym Leader, who you can face again at the Fighting Arena), Leaders (Gym Leaders, the Elite Four, Champions and Rocket bosses), Pink Slips (trainers you've wagered with).
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

A trainer you can battle again rewards your growing bond: a gift that fits their class at 3 wins, a move from their own team at 7 (they teach it), an Egg of their favourite Pokémon at 12, then a gift every 10 more wins. Leaders' steps come at 2, 4 and 6 wins (the gym is the first), then every 10 more. The record shows three steps: done ones in gold, the next in blue, each with its reward once it's known.

- **When:** Back on the map after the win that reaches a step. The trainer speaks while a card above their words shows the reward and your bond track, then it's yours.
- **The Gift:** Their class's own: a Fisherman a better Rod, a Hiker a Hard Stone or Moon Stone, a Bug Catcher Silver Powder, an Engineer a Magnet or Thunder Stone; otherwise their type's item or evolution stone. Later gifts can be Rare Candy or PP Ups. A key item you already have is never given twice.
- **The Tutor:** Choose one of your party (each marked ABLE, LEARNED or NOT ABLE: what they can learn from the trainer's team), then the move: its type, category, power, accuracy and which of their Pokémon knows it. It's taught the game's usual way (forgetting a move if it knows four). Skipping the lesson asks first: it isn't offered again.
- **The Egg:** Their favourite Pokémon, their strongest's first stage. It joins your party, or the PC when the party's full.
- **Claimed Stays Claimed:** Each step is given once, whatever happens to the record. On a save from before, a trainer you'd already beaten more than 3 times gives each step you've passed after your next win over them.

## The Toasts

- **Your Record:** When a trainer you've battled before spots you, or you talk to them, a toast shows their face and name, your record with them, then STREAK 3 (from 3 wins in a row) and their next bond step (TUTOR AT 7). Nothing on a first meeting. It's gone before the battle starts.
- **Your Streak:** Win 10 trainer battles in a row (the Trainer Card's streak) and a toast with a gold coin says "Word of your streak spreads... Leaders are ready for you."

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
Reloaded::Events.on(:trainer_battle_ended, :my_mod) { |c| c[:battle], c[:won], c[:people] }
```

`:trainer_battle_ended` comes after every trainer battle, counted or not: `:won` is true, false, or nil (no winner), and `:people` lists the records it counted for. The Trainer Card's counts come from it too, so there's one place a battle's end is counted.
