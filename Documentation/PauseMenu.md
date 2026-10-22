# Pause Menu

The pause menu, rebuilt in the Info Sidebar design. This is Roadmap topic 34. The code is in `Core/PauseMenu/PauseMenu.rb`, and the screen is in `Core/UI/PauseMenuScreen.rb`.

## What It Shows

The map stays behind it, dimmed. Its colours follow **Theme Mode** (Kanto Reloaded > Interface), as the Overworld Menu's do: Dark, Glass (see-through), Light (the Light frames' pale look, the map washed pale instead of dimmed) or Frost (Light, see-through), its popups too.

- **Left column:**
  - **Money**
  - **Location:** The map, the day and the time. The clock keeps ticking while the menu is open.
  - **Safari Zone** or **Bug Contest:** Steps and balls (or what you caught) while you're in one.
  - **Favorite:** Y opens it.
- **Pinned:** Kanto Reloaded's Shop, TM Vault, PokeVial and PC. Each fills its slot when it's built, so the row is empty for now.
- **Your Row:** Up to 4 entries you pick, with an **Add** tile while there's room.
- **All:** A carousel of every entry you can use now, in the game's order. Kanto Reloaded's and KIF's entries are in it too.

PIF's own location pop-up stays away while the menu is on, since the left column shows the same.

## Controls

| Button | What it does |
|---|---|
| Left / Right | Choose (the carousel turns; a row wraps on a fresh press) |
| Up / Down | Change rows (Pinned only while it has something) |
| A | Open the entry, or Add on the Add tile |
| X | Edit the tile: **Set as Favorite** (or **Clear Favorite**), **Add to Your Row**, and on Your Row's tiles **Move** and **Remove** |
| Y | Open the Favorite |
| B | Close |

With the mouse, pointing at a tile picks it, a click opens it (a side tile of the carousel turns to it), the wheel turns the carousel, and a right click closes. The hints at the bottom can be clicked.

**Move** picks the tile up; Left and Right carry it along Your Row, and anything else puts it down.

**Open Favorite** is in **Controls > Overworld > Menus**, with no button at first. Give it one and it opens your Favorite straight from the map, without showing the menu.

## Entries You Can't Use Now

All shows only what you can use now, as the game's own list does. A tile in Your Row, or the Favorite, stays where you put it, dimmed with a lock, and says why when chosen:

- no Pokédex, Pokémon or PokéNav yet
- the Bag in the Bug Contest
- saving in the Safari Zone or the Bug Contest
- KIF's PC, Heal and Kuray Shop while Kuray QoL is off, and Tutor.net while it's off

Quit (Safari Zone) and Quit Contest are only there while you're in one, so they can't go in Your Row or be the Favorite.

## Status Lines

The Save tile says when you last saved: **Saved 12 Min Ago** in the carousel, a **12 Min Ago** pill in Your Row, or **Not Saved Yet** in red. Kanto Reloaded's own entries can show one too, like the PokeVial's charges.

## Settings

| Setting | Where | What it does |
|---|---|---|
| Reloaded Pause Menu | Reloaded Systems | On: this menu. Off: the game's own. |
| Menu Animations | Interface | The left column slides in, the tiles fade in, and the carousel slides between entries (the Overworld Menu slides in too). Off: everything at once. |

Your Row and the Favorite are the same in every save. They're kept in `Settings\Pause Menu.json` in the mod folder.

## How It Works

Only the screen is replaced. `PokemonPauseMenu_Scene` gets a prepended module (`Reloaded::PauseMenu::SceneView`), and PIF's `PokemonPauseMenu` still builds the list and runs every entry. KIF's registry (`KIF::PauseMenu`) still adds its own entries and runs them. So everything keeps working as in the game's own menu:

- Safari Quit and Quit Contest
- Outfit and the trainer card
- KIF's Return to Pokémon Center
- other mods' entries
- closing an entry and landing back in the menu, on the same tile

Each row of the list is recognized by its KIF id or its icon (`menuIcons/BAG` is the Bag), never by its text. A row another mod adds some other way still shows, by its own name and icon.

If the screen fails, the game's own menu takes over for that menu, and the log says why.

The tile art is Hoenn Reloaded's menu icons, fitted to 56 pixels, in `Graphics/PauseMenu` (KIF's PC, Heal, Kuray Shop and Tutor.net use the PC, PokeVial, Reloaded Mart and TM Vault icons). Return uses the game's Escape Rope, Quit Contest its Sport Ball, and Safari Quit and other mods' rows their own list icons at double size.

## For Kanto Reloaded's Features

A feature adds its entry here. It goes in KIF's list too, so it works in the game's own menu:

```ruby
Reloaded::PauseMenu.register(:pokevial, "PokeVial",
  :feature     => :pokevial,                  # hidden while the feature is off
  :icon        => "Graphics/...",             # the tile's picture
  :small_icon  => "menuIcons/POKEMON",        # the game's own list
  :pinned      => 2,                          # its Pinned slot (0 to 3)
  :takes_over  => :kif_heal,                  # KIF's entry it replaces while on
  :status      => proc { ["Charges: 3/5", nil, "3/5"] },   # words, :red or nil, short words
  :condition   => proc { ... },
  :lock_reason => proc { "..." },
  :handler     => proc { |scene| ...; :stay })            # :stay or :close
```

## Tests

```text
ruby Tools/Tests/pause_menu_preview.rb "<KIF Beta>" <work dir with metrics.json>
python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>
```

It runs PIF's own pause menu code with KIF's own registry, on the preview tool's stand-ins. It covers:

- every entry known by its icon or KIF id
- the left column, and no location pop-up
- the carousel, and Your Row's Add, Set as Favorite and Move
- Y opening the Favorite through KIF's registry, and landing back in the menu
- an entry of PIF's (Options) and back to the menu on it
- a locked tile and why
- the mouse
- the Safari Zone's lines, Quit, and Save locked
- a Pinned entry of Kanto Reloaded's taking over KIF's Heal
- Open Favorite from the map, and a Favorite that can't be used
- Menu Animations Off, and Reloaded Pause Menu Off
- Theme Mode Glass, Light and Frost: the colours, the panel and tiles see-through, the map washed pale

Set `KR_PREVIEW_BACKDROP` to a 512x384 picture of a map to render the menu over it.
