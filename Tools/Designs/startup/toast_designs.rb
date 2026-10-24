# encoding: utf-8
# Mockups: the startup checks as a toast at the top (his ask, 2026-10-23:
# the Checking for Updates popup came up and went at once over the main
# menu when the checks were quick). Kanto Reloaded's own toast (UI/Toast.rb)
# over the real Load Screen, on the saves preview's stand-ins. Each design:
# while checking (left) and once it's done with nothing new (right); an
# update found still opens its popup (the Choice List, Update All).
#   Design 1 Then Up to Date: "Checking for Updates...", then "Everything's
#            Up to Date" with KIF's version in a green pill.
#   Design 2 Two Pills: a pill for each check (KIF, MODS), dim while it
#            runs, green once it's done.
#   Design 3 Words Only: the same toast without pills ("KIF 1.1.1 Is the
#            Newest").
# Usage (from the mod folder): ruby Tools/Designs/startup/toast_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                              python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>
SAVES_TEST = File.join(ARGV[0], "Mods/KantoReloaded/Tools/Tests/saves_preview.rb")
src = File.read(SAVES_TEST, :encoding => "UTF-8")
head = src.split("#---------------------------------------------------------------- the Save Manager")[0]
screen = src.split("#---------------------------------------------------------------- the Load Screen")[1].split("result = drive_screen(\"load screen\"")[0]
screen = screen.lines.reject { |l| l.start_with?("File.delete") }.join     # What's New's file: not made here
eval(head, binding, SAVES_TEST)
eval(screen, binding, SAVES_TEST)

$pad_name = "Xbox Series X Controller"
P = Reloaded::Pixel
PF = ::KIF::PixelFont
T = Reloaded::Toast
ball = Bitmap.new(13, 13)
P.poke_ball(ball, 0, 0, 13)
BALL = ball

# a pill drawn at the toast's end (the toast's own :paint)
def pills(list)
  w = list.sum { |label, _t| P.width(PF::TINY, label) + 12 } + 6 * (list.length - 1)
  [w, proc { |b, x0, y0, c|
    x = x0
    list.each do |label, tone|
      col = c[tone] || c[:dim]
      fill = c[:light] ? Reloaded::Palette.mix(c[:panel2], col, 0.22) : Reloaded::Palette.mix(c[:panel], col, 0.25)
      x += P.pill(b, x, y0, label, fill, col, false) + 6
    end
  }]
end

STATES = {
  1 => [proc { T.show("Checking for Updates...", :icon => BALL) },
        proc { T.show("Everything's Up to Date", :icon => BALL, :pill => ["KIF 1.1.1", :green]) }],
  2 => [proc { T.show("Checking for Updates", :icon => BALL, :paint => pills([["KIF", :dim], ["MODS", :dim]])) },
        proc { T.show("Up to Date", :icon => BALL, :paint => pills([["KIF 1.1.1", :green], ["MODS", :green]])) }],
  3 => [proc { T.show("Checking for Updates...", :icon => BALL) },
        proc { T.show("KIF 1.1.1 Is the Newest", :icon => BALL) }]
}.freeze

[[0, "dark"], [2, "light"]].each do |mode, word|
  S.set(Reloaded::Palette::MODE, mode)
  queue = []
  STATES.each do |n, (checking, done)|
    queue += [at { checking.call }, dmp("ts-#{n}-a_#{word}"), at { done.call }, dmp("ts-#{n}-b_#{word}")]
  end
  queue += [at { T.dispose }, I::RIGHT]
  drive_screen("toast designs #{word}", queue) { v, cmds = load_view; v.choose(cmds, 0) }
  lv.close(false)
end
S.set(Reloaded::Palette::MODE, 0)
puts $failed ? "SOME FAILED" : "designs done"
