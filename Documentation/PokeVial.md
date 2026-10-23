# PokeVial

Limited party healing in place of KIF's unlimited Heal Pokémon: a few charges, refilled at Pokémon Centers. This is Roadmap topic pokevial (Confirm Dialog), merged from the old Kanto Reloaded's PokeVial and Hoenn Reloaded's. The code is in `Core/PokeVial/PokeVial.rb` (charges, settings, refills, items, the API) and `Core/UI/PokeVialScreen.rb` (the dialogs and toasts).

## Where It Shows

- **The Pause Menu:** Its tile is in the Pinned row's third slot, and KIF's Heal Pokémon steps aside while it's on. The tile's pill shows the charges ("2/4", red when empty).
- **The Overworld Menu:** An action on Main, its charges drawn as little Poké Balls.

Both show while Kuray QoL is On (KIF Settings > Others), as KIF's Heal Pokémon did. **PokeVial** in Kanto Reloaded > Features switches it; Off brings KIF's Heal Pokémon back.

It's locked, saying why, wherever KIF blocks its own Heal (the Elite Four, Victory Road, Mt. Silver and the dream maps: `KIF::PauseMenu.restricted?`), in battle, in the Safari Zone and in the Bug-Catching Contest.

## Using It

Choosing it opens a dialog: the vial and the charges on the title plate, then the **Heal Preview**: each Pokémon in the party (not Eggs), its HP, and what a charge would do for it ("+17 HP", "Revived", "+70 HP, Cures Poison", "PP Restored", or "Healthy"). **Use PokeVial** heals the party and uses a charge; the dialog then shows who was healed, and Back becomes Done.

Use is dimmed, with the reason on it, when it can't be used:

| Reason | When |
|---|---|
| No Charges Left | Every charge is used. A Pokémon Center refills it. |
| All Healthy | Nobody needs healing, so no charge is used. |
| Ready in 4:32 | The cooldown is still running; a line under it fills as it goes. |

With **Cooldown Wait** set to Toast, choosing it while it cools down shows a toast with the time left instead of the dialog.

| Button | In the dialog |
|---|---|
| Left / Right | Choose Use or Back |
| A | Pick it |
| B | Back |

The mouse works too: pointing picks, a click uses, a right click is Back.

## Charges

It holds 3 charges, or with **Progressive Uses** one more for every two Badges, up to 5 (0 Badges: 1, 2 Badges: 2 ... 8 Badges: 5). A new charge arrives full, and a toast says so ("PokeVial now holds 4 charges", +1) on the next step after the Badge.

## Refilling

At a Pokémon Center, once the nurse heals your party (Recover All, or a nurse made with a script call during her event), **Pokémon Center Refill** decides:

- **Ask:** A dialog, "Refill PokeVial?", with the missing charges, the cost and the money you have; Refill or Not Now. Without enough money, Refill is dimmed.
- **Automatic:** It refills by itself, with a toast (and pays, if there's a cost; without enough money, a toast says so).
- **Never:** Only items and other mods refill it.

**Refill Cost** charges money for each missing charge (**Cost Per Charge**, $500 to start).

## The Low HP Reminder

While a Pokémon has fainted or the party's HP is under half, and the PokeVial has a charge, its Pause Menu tile and Overworld Menu row glow red, slowly pulsing (not while the cursor is on it). **Low HP Reminder** switches it.

## Items

Two items, used from the Bag (Medicine). Kanto Reloaded adds them through its own Data Patches; no shop sells them yet.

| Item | Price | Does |
|---|---|---|
| PokeVial Charge | $500 | One charge back |
| PokeVial Refill | $1,500 | Every charge back |

Using one shows a toast with the charges; when the PokeVial is already full, a FULL toast, and the item isn't used.

## Settings

Kanto Reloaded > PokeVial. The ones that change how hard the game is are kept by each save.

| Setting | Kept | Does |
|---|---|---|
| Progressive Uses | Each save | One more charge for every two Badges, up to five (On) |
| Max Uses | Each save | Charges while Progressive Uses is Off (1 to 5, 3) |
| Heal Mode | Each save | Full Heal; HP Only (status and PP stay); No Revive (fainted Pokémon stay fainted) |
| Cooldown | Each save | Real time has to pass between uses (Off) |
| Cooldown Time | Each save | 5 to 45 minutes |
| Cooldown Wait | Every save | What choosing it shows while it cools down: In the Dialog, or a Toast |
| Pokémon Center Refill | Each save | Ask, Automatic or Never |
| Refill Cost | Each save | Money for each missing charge (Off) |
| Cost Per Charge | Each save | $0 to $5,000, by $100 |
| Low HP Reminder | Every save | The glow in the menus (On) |

The charges, the capacity last seen and the last use are kept in the save (SaveStore section `pokevial`).

## For Other Mods

The same names as Hoenn Reloaded's PokeVial:

```ruby
Reloaded::PokeVial.uses                                    # charges left
Reloaded::PokeVial.configured_max_uses                     # how many it holds
Reloaded::PokeVial.add_uses(1, source: :my_mod)            # give charges (never past the top)
Reloaded::PokeVial.grant_full_refill(source: :my_mod)
Reloaded::PokeVial.increase_max_uses(1, source: :my_mod, refill: true)
Reloaded::PokeVial.register_refill_source(:my_inn) { |vial| true }
Reloaded::PokeVial.refill_from_source(:my_inn)
Reloaded::PokeVial.on(:before_use, :my_mod) { |ctx| false }    # false stops it
Reloaded::PokeVial.unregister_callback(:before_use, :my_mod)
```

Events: `:before_use`, `:after_use`, `:before_refill`, `:after_refill` and `:capacity_changed`, each with a context hash (`:source`, `:uses_before`, `:uses_after`, `:max_uses`, and more for each). A `:before_` handler that returns false stops it. `notify: false` skips the toast.

## Tests

```text
ruby Tools/Tests/pokevial_test.rb "<KIF Beta>" <empty temp folder>
ruby Tools/Tests/pokevial_preview.rb "<KIF Beta>" <work dir with metrics.json>
python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>
```

The first runs on stand-ins for the game's classes. It covers the menu entries taking over KIF's Heal Pokémon, Kuray QoL Off, the charges and Progressive Uses, the Heal Preview's words in each Heal Mode, using it (and a mod saying no), the cooldown, where it's blocked, the Low HP Reminder, refilling at a Pokémon Center (Ask, Automatic, Never, the cost, not enough money, a nurse made with a script), the items, the API, and switching it Off.

The second drives the screens on the Overworld Menu's preview: the row and its glow, the dialog (ready, used, cooling down, empty), Cooldown Wait's toast, the refill dialog (Refill, Not Now, not enough money), the toasts, and Light. The Pause Menu's preview checks the tile and its glow.

The mockups for its small popups (cooldown, capacity, charges, Low HP, item messages) are in `Tools/Designs/pokevial`.
