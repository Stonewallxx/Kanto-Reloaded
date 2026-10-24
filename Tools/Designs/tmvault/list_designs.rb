# encoding: utf-8
# Mockups: the TM Vault's list without plates (his ask, 2026-10-23: "it
# looked way better and much clearer, colored texts was better and seeing
# the type icon was better"), drawn by the real screen on the TM Vault
# preview's stand-ins. One panel; each move's name in its type's colour.
#   Design 1 Coloured Names: the TM's number and the type's icon at the end
#            (the 2026-10-17 look, with Favorites, NEW and the Type Filter)
#   Design 2 Type Labels: PIF's type label at the end instead of the icon
#   Design 3 Icon First: the type's icon before the name, the number at the end
# Each in Dark and Light, the Vault and the Checklist, with a controller's
# prompts. His pick: Design 1, now the screen's only look; the three were
# drawn with a switch the screen had for them (commit 3bfa1a1), so this
# draws the built one.
# Usage (from the mod folder): ruby Tools/Designs/tmvault/list_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                              python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>
TEST = File.join(ARGV[0], "Mods/KantoReloaded/Tools/Tests/tm_vault_preview.rb")
eval(File.read(TEST, :encoding => "UTF-8").split("#---------------------------------------------------------------- A: the Vault")[0], binding, TEST)

$pad_name = "Xbox Series X Controller"
MODE = Reloaded::Palette::MODE
def both(name)
  [at { S.set(MODE, 0); $tv.refresh }, dmp("#{name}_dark"), at { S.set(MODE, 2); $tv.refresh }, dmp("#{name}_light"),
   at { S.set(MODE, 0); $tv.refresh }]
end
[1].each do |n|
  fresh_vault
  TV.toggle_favorite(:EARTHQUAKE)
  $Trainer.party = make_party
  vault("list design #{n}", [*both("tvl-#{n}"), I::ACTION, I::ACTION, *both("tvl-cl-#{n}"), I::BACK])
end
puts $failed ? "SOME FAILED" : "designs done"
