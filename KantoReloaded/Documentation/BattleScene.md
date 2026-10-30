# Battle Scene

EBDX's battle screen made Kanto Reloaded's: the Reloaded cursor, a ring on every Pokémon a move will hit, real fusion icons when you pick a target, button hints, and a choice of command rows. This is Roadmap topic battle-ui. The code is in `Core/BattleScene/BattleScene.rb` (the feature, its settings and its hooks on EBDX's windows), `Core/BattleScene/TargetIcons.rb` (the targets' pictures), `Core/UI/BattleCursor.rb` (the cursor), `Core/UI/CommandRow.rb` (the command rows) and `Core/UI/HintChips.rb` (the hint chips).

## Where It Shows

In EBDX's battles (KIF Settings, Graphics; Off for a new player). The hint chips show in PIF's own battle screen too. EBDX's code is never changed: Kanto Reloaded draws over its windows.

**Battle Scene** (KIF Settings > Kanto Reloaded > Core > Features, On by default) switches it. Off gives EBDX back as it ships. The move overlap fix (below) stays on either way.

## The Cursor

A ring in your **Cursor Color** (Kanto Reloaded > Interface; your Theme's colour at first) with the button snug inside it, and a soft glow round it, pulsing like every Kanto Reloaded cursor. In Theme Mode Light it's a deeper shade of the colour. It replaces EBDX's red corners on:

- **The command row** (Fight, Bag, Party, Run).
- **The Bag:** its pockets, items, Back, Confirm and Cancel.
- **The target window:** the Pokémon you pick. A move that hits more than one (Discharge, Earthquake, Surf...) gets a ring on every Pokémon it will hit. EBDX marked the user's own button instead.
- **The Fight menu:** the picked move.

**Battle Cursor** (Kanto Reloaded > Interface > Battle Scene): Reloaded, or EBDX's Own (its red corners).

## Picking a Target

Every Pokémon on its button is centred, so tall ones (Gyarados, Onix) keep their heads; EBDX cut the top off every icon. A fusion shows its own icon, its head and body, instead of EBDX's DNA placeholder. If you set PIF's **Fusion Icons** option to DNA, it stays DNA. The buttons always use the small icons, even with Big Pokémon Icons on: battle sprites came out too small on them.

## Button Hints

While you choose Fight, Bag, Party or Run, chips name the button that opens the Battle Menu, and any Battle Menu shortcut you bound (Open Battle Info, Open Battle Favorite), in your controller's style. They sit on the right above the command row, opposite the Field Strip; in PIF's battle screen, along the bottom of its message box. Only the buttons that work right now are shown. **Button Hints** (Kanto Reloaded > Interface > Battle Scene, On) switches them.

## The Command Row

**Command Row** (Kanto Reloaded > Interface > Battle Scene) picks how Fight, Bag, Party and Run look. Each keeps EBDX's colour for each command: Fight red, Bag green, Party yellow, Run blue.

| Command Row | Looks |
|---|---|
| Plates (at first) | EBDX's buttons in the same places, as Kanto Reloaded plates: each word and a bar under it in its colour. The picked one is filled with its colour and raised, its word in a deeper or paler tone of that colour (whichever stands out from the fill), and the cursor sits on its edge, cut like the plate. |
| Slim Bar | One slim bar along the bottom, thin lines between the commands. The picked one lights up its whole section in its colour, its word in a deeper or paler tone of it; there's no ring. The Field Strip and the hints sit just above it. |
| Corner Panel | The four as a 2 x 2 of plates in a panel at the bottom right (Up and Down move a row too). A panel at the bottom left says "What will Pikachu do?", with the Field Strip and the hint chips in it. With more than four commands (KIF's INFO), that turn uses Plates. |
| EBDX's Own | EBDX's buttons, with the cursor Battle Cursor picks. |

The Fight menu stays EBDX's own, with the cursor and the overlap fix.

## The Move Overlap Fix

EBDX lifts the picked move to show its type and PP, but the move under it covered the bottom of it, so you couldn't read them. The picked move now sits on top. This is a fix (Foundation > Fixes), always on.

## For Mod Makers

- **A Pokémon's picture when picking a target:** `Reloaded::BattleScene::TargetIcons#icon_for(pk)` gives the Pokémon whose picture shows. Prepend it to show another (Ghostly Possession shows a possessed Pokémon as its fusion).
- **The cursor:** `Reloaded::BattleCursor::Ring.new(viewport, z, :edge)` then `follow(sprite)` each frame (the sprite's solid part snug inside it, measured when it changes), or `Ring.new(viewport, z, :plate, :cut => 7)` then `place(x, y, w, h)` (round a Kanto Reloaded plate). Its pictures are made once a size and kept for the battle.
