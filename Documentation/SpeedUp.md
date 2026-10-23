# Speed-Up

How fast the game runs: hold a button to go faster, or press it to step through the speeds. This is Roadmap topic speed-up, the old Kanto Reloaded's Speed-Up taking over KIF's (F-UI-05_SpeedUp: its window title, L/R speed keys and Toggle limit). The code is in `Core/SpeedUp/SpeedUp.rb` (the speeds, the buttons, the hooks) and `Core/UI/SpeedUpIndicator.rb` (the corner indicator).

**Speed-Up** in Kanto Reloaded > Features switches it, On to start. Off brings back KIF's (and PIF's own speed-up under it).

## Where the Settings Are

- **KIF Settings > Kanto Reloaded > Speed-Up**: every setting below. The other type's rows are dimmed with a padlock and can't be changed; the description says why (Toggle Only, Hold Only).
- **The Controls screen's Speed-Up section** (Change Controls, between Battle and Feel): the same settings under Game Speed, then the three buttons under a Buttons heading, with their Keyboard and Controller columns. The other type's rows stay in the list, locked (dimmed, with a padlock; the description says why). Left and Right step a setting, A opens its dropdown, the Default button puts it back. Reset Section (Layouts) puts the settings and the buttons back.
- **The Overworld Menu's Speed-Up row** follows the type: Toggle sets the speed now (1x to Toggle Limit), Hold sets Speed-Up (Overworld) (1x to 10x).

PIF's own Speed-up rows (Game > Speed-up) step aside while Speed-Up is On. The type and the Hold speeds are kept in PIF's fields too, so turning Speed-Up Off leaves PIF's speed-up as you had it.

## The Settings

| Setting | What it does | Default |
|---|---|---|
| Speed-Up Type | Hold: hold the Speed-Up button to go faster. Toggle: press it to step through the speeds | Hold |
| Speed-Up (Overworld) | Hold: the speed while held, outside battle | 4x |
| Speed-Up (Battles) | Hold: the speed while held, in battle | 4x |
| Resting Speed | Hold: the speed when the button isn't held | 1x |
| Toggle Limit | Toggle: the fastest speed a press steps up to before going back to 1x (2x to 10x) | 5x |
| Toggle Speeds | Toggle: Separate (the overworld and battles each remember their own speed, and switch to it as a battle starts and ends) or Shared | Separate |
| Burst Speed | Toggle: hold the Speed-Up button (for Controls' Hold Time) to run at this speed until you let go; a tap still steps. Off: each press steps at once | 10x |
| Remember Speed | Toggle: the toggled speeds stay as you left them the next time you play. Off: the game starts at 1x | On |
| Shiny Slowdown | When a shiny appears, in a wild battle (before it's sent out) or on the map (an overworld Pokémon), the speed drops to 1x. Hold: until you let go of the button | On |
| Messages at 1x | Message boxes (talking, signs, items) run at 1x so you can read them. Battles keep their speed | Off |
| Speed Indicator | The corner indicator (below) | On |

## The Buttons

Reloaded Controls' Global actions (in the Speed-Up section, no longer under Global): **Speed-Up** (follows X: the A key and Y on a controller; Pokémon-Style puts it on RT), **Next Speed** (follows L: Q) and **Reset Speed** (follows R: W). Next Speed and Reset Speed work in Toggle, on the map with nothing open and in battle, as KIF's L and R did (menus use L and R for their pages). With Reloaded Controls Off, they're the game's buttons.

An event that calls `pbDisallowSpeedup` stops the buttons until it calls `pbAllowSpeedup` (Hold: back to 1x; Toggle: the speed stays).

## What Shows

- **The window title:** "Kanto Reloaded 2.0.0 · KIF 1.1.0 · PIF 6.8.2 · Speed x4" (the speed now). Kanto Reloaded doesn't support KIF's Auto-Battle or Self-Battle, so their states aren't in it.
- **The Speed Indicator** (his pick, 2026-10-23: Design 3, the toast, made smaller than Design 1): a small box in the top-right corner, for a moment, when the speed you set changes. A fast-forward mark and the speed in a gold pill; at 1x a play mark and a grey pill. It follows Theme Mode (Dark or Light), shows over the map, battles and menus, and fades in real time. It says the speed running: in a settings screen, the 2x it's held to there (opening or closing one doesn't show it again). Messages at 1x doesn't show.

KIF Settings, Options and the Controls screen run at 2x at most (his call, 2026-10-23: faster, a held button repeats too fast for the cursor). Your speed comes back when they close; the Speed-Up button still works there.

## How It Works

PIF ships Marin's Better Fast-forward (`052_InfiniteFusion/System/Spped Up.rb`): its `Graphics.update` hands a frame to the engine's update (saved as `Graphics.fast_forward_update`) only every <speed> calls, so the game runs <speed> times as fast. While Speed-Up is On:

- `Graphics.update` works out the speed, the title and the indicator, then calls PIF's with its own speed-up kept out (`$CanToggle` off for the call, its stage 0), so PIF's draws every call.
- `Graphics.fast_forward_update` skips the frames instead, every <speed> calls one is drawn.
- `Input.update` reads the buttons once per game step.

Without PIF's Better Fast-forward, Speed-Up stays off and PIF's own stays (the log says so). If Speed-Up's code fails, it's off for the session and PIF's speed-up takes over.

```ruby
Reloaded::SpeedUp.speed           # the speed now (1 to 10)
Reloaded::SpeedUp.slow_down       # back to 1x, as Shiny Slowdown does
Reloaded::SpeedUp.set_toggled(3)  # Toggle: the speed here (the overworld's or, Separate, the battle's)
```

## Tests

```text
ruby Tools/Tests/speed_up_test.rb "<KIF Beta>" <empty temp folder>
ruby Tools/Tests/speed_up_preview.rb "<KIF Beta>" <work dir with metrics.json>
python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>
```

The first runs PIF's own Better Fast-forward over stand-ins for the engine's Graphics and Input. It covers Hold (the speeds, Resting Speed, battles, PIF's fields), PIF's own speed-up kept out, Toggle (steps, Toggle Limit, Burst Speed's tap and hold, Next Speed and Reset Speed where they're allowed, Separate and Shared, Remember Speed), Shiny Slowdown (a wild battle, a trainer's, the map, Hold), Messages at 1x, Options at 2x at most, `pbDisallowSpeedup`, the window title, the Overworld Menu's row, PIF's rows in KIF Settings, Off, and a failure handing over to PIF's.

The second drives the Controls screen's Speed-Up section (Hold and Toggle, locked rows, a dropdown, the Buttons and a button's editor, Reset Section), Global without the speed buttons, Search, KIF Settings, and the Speed Indicator in Dark and Light.

The mockups are in `Tools/Designs/speedup` (and `Tools/Designs/spd_designs.rb`, the section's first designs).
