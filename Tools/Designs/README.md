# Designs

The mockup scripts behind the Roadmap's designs. Each draws its designs on the preview tool's stand-ins (`Tools/UIPreview`), so a mockup uses the mod's real screens, fonts and frames wherever it can.

## Running One

Each script's Usage line at the top says what it takes. Most are:

```
ruby <script> "<KIF Beta>" <work dir with metrics.json>
python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>
```

Work folders go in the system's temp folder, never in the mod or the game.

## What's Here

- `*_designs.rb`: One topic or popup each (`ae_designs.rb` is Area Encounters, `dc_designs.rb` the Day Care popup, `phone_buttons_designs.rb` the buttons on phones).
- `*_backdrop.py`: Redraws a game screen (the Pokédex, the party, a battle) as a backdrop for the mockups drawn over it.
- `controls.rb`: The Controls page mockup that `spd_designs.rb` builds on.
- Folders such as `bag`, `egg` and `heal`: A topic's later rounds.
- `hookcheck`: The Hook Check and Style Check report designs (Markdown).
- `frames`: The window frame and theme mockups.
- `early`: The first mockups, kept for reference.

Some older mockups draw over backdrop pictures from their work folder (`../backdrop.png`). Make those again with the matching `*_backdrop.py` first.

The game never loads anything here: `mod.json` only lists `Bootstrap.rb`.
