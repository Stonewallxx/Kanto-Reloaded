# Battle Menu

A menu of battle tools you open while choosing Fight, Bag, Pokémon or Run: Battle Info, the Turn Log and other mods' tools, with the Field Strip over the battle menu. This is Roadmap topic battle-command-menu. The code is in `Core/BattleMenu/BattleMenu.rb` (the entries, pages, Favorite and the battle menu's hooks), `Core/BattleMenu/BattleNotes.rb` (what it reads from the battle, and what the battle has shown about the foes), `Core/BattleMenu/TurnLog.rb` (the Turn Log), `Core/BattleMenu/Entries.rb` (Main's entries), `Core/UI/BattleMenuPanel.rb` (the menu), `Core/UI/BattleInfoScreen.rb` (Battle Info) and `Core/UI/FieldStrip.rb` (the Field Strip).

## Where It Shows

In every battle where you choose Fight, Bag, Pokémon or Run, in EBDX's battle screen and PIF's. The Safari Zone and the Bug-Catching Contest have their own menus and no Battle Menu.

**Battle Menu** (KIF Settings > Kanto Reloaded > Core > Features, On by default) switches it. Off leaves the battle as KIF has it: no menu, no Field Strip, and KIF's own Battle Info back as you set it (KIF Settings, Others). The two can't be on together: while the Battle Menu is On, KIF's Battle Info is locked Off.

## The Menu

A panel in the middle of the screen, over the battle, with the battle menu still in view under it.

- **Main:** Kanto Reloaded's entries: **Battle Info** and **Turn Log** (with the turn being played).
- **Mods:** Every other mod's entries, each with its mod's name. A mod switched off in KIF's Mods list takes its entries with it at once; they come back where they were. With no other mod's entries there's only Main.
- **The Favorite:** One entry, starred in gold. The Battle Menu button again, inside the menu, runs it (Battle Info at first). With none, the button closes the menu.
- **A locked entry** (one that can't be used right now) is dimmed with a padlock, and the description box says why in red.

| Button | Does |
|---|---|
| Up / Down | Choose an entry |
| LB / RB | Main or Mods |
| A | Use the entry |
| The Battle Menu button (X) | The Favorite |
| Y | Options: Set as Favorite (or Remove Favorite), Move (carry it up or down its page), Cancel |
| B | Close |

With the mouse, a click on an entry uses it, the wheel moves, the hints can be clicked, and a right click closes. The order of each page, the Favorite and the page you were on are the same in every save (`Settings\Battle Menu.json` in Kanto Reloaded's folder).

## Battle Info

A tab for each Pokémon in the battle (yours first, with a green dot; the foes' with a red one), then Matchup, Field and Turn Log. Left and Right (LB and RB too) turn the tabs.

- **A Pokémon:** Its HP (a foe's in %, as its HP bar shows it) and status; its stat stages, each named and with six pips in the stat's colour (Attack and Sp. Atk red, Defense and Sp. Def blue, Speed pink, Accuracy gold, Evasion purple), the change in green or red, and its multiplier (green above x1, white at x1, yellow, orange and red below); under them other mods' abilities (KIF: Elite Redux's innates); its types as they are now; its ability (a second one under it: a fusion's other with Double Abilities, or KIF: Elite Redux's Ability 2) and held item; its effects with the turns they have left; and a foe's Moves Used.
- **Abilities (A):** Its abilities in full, with what each does: Its ability (a fusion's two with Double Abilities), KIF: Elite Redux's Ability 2, and its innates on a tab of their own (Left and Right); a long list (a fusion's six innates) scrolls with Up and Down. One the battle hasn't shown yet is ???.
- **Moves (Y):** Each move with its type, category, power, accuracy, PP and what it does. A foe's show once it has used them, with its PP as its most.
- **Only what the battle has shown:** A foe's ability shows once its pop-up has, and its held item once it's used or a message about that Pokémon names it (a message about yours never names the foe's). Until then they're ???. Turns show for the weather, terrain, rooms, screens, Taunt, Encore, Disable and trapping; confusion and sleep show without them. A foe in disguise (Illusion) shows as the Pokémon it copies until the disguise breaks.
- **Matchup:** Your Pokémon's moves against each foe (x4 to x0, as the battle works out the move's type), with Up and Down for your other Pokémon in a double battle; then each foe's types as seen (its name between its two types), and a row each for what hits it x4, x2, x½, x¼ and x0. An ability that makes a foe immune counts once the battle has shown it.
- **Field:** The whole field (weather, terrain, Trick Room and the other rooms), then your side and the foe's side next to each other (screens, Tailwind, Safeguard, Mist, hazards, Future Sight and Wish). The turns left are green on your side, red on the foe's and gold for the whole field; something that lasts until it's ended has an ∞ badge in the Theme's colour.
- **Turn Log:** Every turn of this battle, the latest first (Up and Down scroll). Each row is who did what at whom, with its result: The damage (HP lost, as a number), x4 / x1/2 / NO EFFECT, CRIT, MISSED, FAILED, FAINTED, and what a move changed (a status, stat stages, the weather, a side's screens or hazards, TRAPPED). Under each turn, what happened at its end: HP lost or restored by the weather, poison, Leech Seed, Leftovers and the rest. It lasts for the battle.

**Open Battle Info** (Controls > Battle, unbound at first) opens it straight from the battle menu.

## The Field Strip

Chips over the battle menu's left while you choose, one for each effect on the field in its type's colour, with the turns it has left (green on your side, red on the foe's, gold for the whole field; endless weather or terrain: an ∞ in the Theme's colour). The foe's side's chips end in a red FOE tag. Two lines at most, then +N MORE (Battle Info's Field tab has them all). **Field Strip** (Kanto Reloaded > Battle Menu, On) switches it. Battle Scene's command rows move it: just above the Slim Bar, or into the Corner Panel's left panel; it stops short of Battle Scene's hint chips.

## Controls

| Action | At First | Does |
|---|---|---|
| Battle Menu | Action (X on a controller, Z on a keyboard) | Opens the Battle Menu while you choose; inside it, runs the Favorite |
| Open Battle Favorite | Unbound | Runs the Favorite straight from the battle menu |
| Open Battle Info | Unbound | Opens Battle Info straight from the battle menu |

All three are in Controls > Battle > Battle Menu. Mega Evolve shares the Action button in the Fight menu; the two never clash.

## For Mod Makers

A mod adds its entry to Mods while its scripts load (Kanto Reloaded first):

```ruby
Reloaded::BattleMenu.register(:battle_camera, :name => "Battle Camera",
  :icon => :POKEDEX,                              # an item's picture, or a picture's path
  :description => "Hides the battle boxes for a screenshot.",
  :priority => 50,                                # its place among the Mods page's entries
  :mod => "Photo Mode",                           # its mod's name, when KIF's Mods list hasn't one
  :condition => proc { |ctx| true },              # listed at all
  :usable => proc { |ctx| true or "Why not." },   # dimmed with a padlock, and says why
  :status => proc { |ctx| ["x4", :gold] },        # words and a tone (:green :gold :red :blue :dim)
  :handler => proc { |ctx| nil })                 # nil stays, :close, or :fight :bag :party :run :call
Reloaded::BattleMenu.unregister(:battle_camera)
Reloaded::BattleMenu.unregister_owner("PhotoMode")
```

- **Its owner** is the mod whose scripts are loading (KIF's `KIF::Mods.current`); its entries hide while that mod is switched off in KIF's Mods list (Mod Manager's mods too). Kanto Reloaded's own entries can't be taken.
- **ctx** (one each time the menu opens): `battle`, `index` (the Pokémon choosing), `battler`, `scene`, `first_action`, `wild?`, `trainer?`; `hidden { }` (the menu steps aside for a screen of your own), `notice(title, text)`, `confirm(title, text, yes, no)` (Kanto Reloaded's question, your mod's name under it; No first), `choose(title, labels, descriptions)`, `toast(text)`.
- **A game command:** A handler that answers `:bag` (or `:fight`, `:party`, `:run`, `:call`) leaves the battle menu with it, as if that button had been picked (EBDX's cursor is kept for next turn as usual). `:run` only works for the first Pokémon to choose.
- **Errors:** An entry whose condition, status or handler raises is logged and dims for the rest of the battle; the menu carries on.
- **Ability rows on Battle Info** come from KIF Battle Info's providers (`KIF::BattleInfo.register_abilities`), as KIF: Elite Redux registers its innates.
