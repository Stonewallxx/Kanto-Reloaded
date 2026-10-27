# Double Abilities

Every fusion has two abilities, one from its head and one from its body: Yours, trainers' and wild ones. A feature with a switch (On), in *KIF Settings* > *Kanto Reloaded* > *Double Abilities*. The code is in `Core/DoubleAbilities/` (`DoubleAbilities.rb` the pair, `Banned.rb` the banned pairs, `Battle.rb` the battle, `PopUps.rb` the pop-ups, `Fusing.rb` fusing, the capsules and the Summary, `EliteRedux.rb` KIF: Elite Redux); the screens and popups are in `Core/UI/DoubleAbilitiesScreens.rb`.

## The Pair

- **The head's** ability is the fusion's own (the one it keeps if Kanto Reloaded is removed). **The body's** is the second. A fusion from an old save whose own ability is the body's gets the head's as its second.
- **Picked when you fuse** on the Fusion Screen (below). A fusion that never was (wild, trainers', gifts, every fusion already in your save) gets one of the other side's regular abilities, chosen by its personality: The same every time, never a banned pair.
- **Evolving** keeps each pick on its side. **Reversing** (the DNA Reverser) keeps each ability with its Pokémon. **Unfusing** gives each Pokémon its own ability back, as before.
- **The same ability on both sides** counts once.
- A pick that's banned with the other side's ability now (after an evolution, or a mod's new pair) is set aside for one that isn't.
- Kanto Reloaded Legacy's picks are kept.

## The Fusion Screen

When you fuse, after the fusion:

- **Head** and **Body** columns, each with its Pokémon, its nickname and its abilities: Every regular ability of that side, and its hidden ability (HIDDEN) only when that Pokémon had it. A dot marks each pick; it follows the cursor. Left and Right switch columns.
- A banned option is greyed with BANNED and its reason; the cursor can rest on it, but the dot stays. A on it says why, with **Banned Pairs** one press away.
- **Nature** (the body's or the head's), **Nickname** (when both are nicknamed; when one is, the fusion takes it) and **Banned Pairs** (OPEN) below.
- A fuses. There's no going back: The fusion is already made.

## Banned Pairs

Two abilities a fusion can't have together, each with a badge and its reason:

| Pair | Badge | Why |
|---|---|---|
| Wonder Guard + Sturdy | NO KO | Wonder Guard leaves it 1 HP, and Sturdy saves it from any hit at full HP: Nothing could knock it out |
| Huge Power + Pure Power | x4 ATK | Both double its Attack |
| Huge Power + Water Bubble | x4 ATK | Water moves would hit at x4 |
| Pure Power + Water Bubble | x4 ATK | Water moves would hit at x4 |
| Multiscale + Shadow Shield | x1/4 DMG | Both halve the damage it takes at full HP |
| Illusion + Imposter | CLASH | The disguise and the transformation break each other |
| Shadow Tag + Perish Body | TRAPPED | Perish Body's count would faint the trapped foe for certain |

The page (from the Fusion Screen or *Double Abilities* > *Banned Pairs*) lists every pair whose abilities are in the game. Water Bubble and Shadow Shield are on no Pokémon, but the Randomizer and mods can give them; Perish Body comes with KIF: Elite Redux.

## In Battle

- Both abilities work, in EBDX's battles and PIF's alike, wherever the first would: Switch-in, every hit, immunities, the end of the round. A second switch-in effect runs once each time the Pokémon comes in.
- **Abilities that change an ability** change the one that's working: Trace or Receiver as the second change the second; Worry Seed, Simple Beam, Entrainment, Skill Swap, Role Play and Mummy change the first, and the second stays. A change that would make a banned pair switches the second off for the battle. Transform and Imposter copy both. Gastro Acid stops both.
- **Stance Change, Disguise and Shields Down** work from either side.
- **Wonder Guard**: A fusion with Wonder Guard and another ability has 1 HP, and its Wonder Guard blocks a few hits a battle (**Wonder Guard Blocks**, 1 to 3, 3), then wears off. Wonder Guard alone works as always.

## The Pop-Up

Kanto Reloaded's own ability pop-up takes the place of EBDX's and PIF's, for every ability: A pill in your side's blue or a foe's red, the icon of the side the ability is from and the Pokémon's name on it, the ability beside. When both abilities work in the same moment, a second pill joins the first and they leave together. It slides in where the game's own did.

## Capsules and the Summary

- The **Ability Capsule** (regular abilities) and the **Secret Capsule** (hidden ones too) ask which side to change first, then that side's list: Banned ones are locked, with the reason. The capsule is used up only when the ability changes.
- The **Summary**'s Skills page shows **Abilities**: Both, with a HEAD or BODY badge. The Action button opens the **Abilities Card**: Both descriptions in full, long ones wrapped, each with its side's icon and badge (B closes it).

## KIF: Elite Redux

With its Innates On, a fusion's two abilities are its two choice abilities (Ability 1 and 2). The Fusion Screen lists each side's three choices, with its three innates under them, and the head's pick is Ability 1, the body's Ability 2. KIF: Elite Redux runs both in battle with its own rules: Copies stack, no pair is banned, and Wonder Guard keeps its HP.

## Ghostly Possession

A possessed Pokémon has the Ghost's ability as its second while it's possessed.

## Settings

| Setting | What It Does |
|---|---|
| **Double Abilities** | The switch (On). Off: a fusion has one ability again, the game's own pop-ups and screens come back. |
| **Banned Pairs** | Opens the Banned Pairs page. |
| **Wonder Guard Blocks** | 1 to 3 (3), this save's: How many hits a paired Wonder Guard blocks in a battle. |

## For Mods

- `Reloaded::DoubleAbilities.applies?(pkmn)`: the Pokémon has two (a fusion, not a triple, the feature On).
- `Reloaded::DoubleAbilities.second_id(pkmn)`, `.pair(pkmn)`: its second, or both as `[[:head, id], [:body, id]]`. KIF's `pkmn.ability2_id` and `ability2` answer it too, and `hasAbility?` sees both.
- `Reloaded::DoubleAbilities.choices(pkmn, side, hidden = true)`: a side's abilities as `[index, id, hidden?]`; `set_second(pkmn, index)` sets the second's pick.
- `Reloaded::DoubleAbilities.ban(:A, :B, :badge => "BADGE", :tone => :red, :short => "Short reason", :reason => "The reason.")`: your own banned pair. `Reloaded::DoubleAbilities::Banned.banned?(a, b)`.
- In battle a battler's second is `battler.ability2_id`; `hasActiveAbility?` sees it.
