# encoding: utf-8
# Offline preview of the title screen's versions on the preview tool's
# stand-ins: a stand-in of PIF's title screen (GenOneStyle) draws its
# "v.6.8.2" as PIF does; Kanto Reloaded's hook clears it and puts PIF, KIF
# and KR one to a line in the top right, and takes them away with the
# screen.
# Set KR_PREVIEW_BACKDROP to a 512x384 picture of the title screen to render
# it over that.
# Usage: ruby   Tools/Tests/title_versions_preview.rb "<KIF Beta>" <work dir with metrics.json>
#        python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>
PREVIEW_SETUP_ONLY = true
load File.join(ARGV[0], "Mods/KantoReloaded/Tools/UIPreview/preview.rb")
TV = Reloaded::TitleVersions

module Settings; GAME_VERSION_NUMBER = "6.8.2" unless const_defined?(:GAME_VERSION_NUMBER); end
module KIF; PORT_VERSION = "1.0.3" unless const_defined?(:PORT_VERSION); end
$hud = []
def Kernel.pbDisplayText(message, x, y, z = nil, *rest)
  s = Sprite.new(Viewport.new(0, 0, 512, 384))
  s.bitmap = Bitmap.new(512, 384)
  Reloaded::Pixel.small(s.bitmap, x - 40, y, 80, 20, message, Color.new(255, 255, 255))
  $hud << s
  $log << "DISPLAYTEXT #{message}"
end
def Kernel.pbClearText
  $hud.each(&:dispose)
  $hud.clear
  $log << "CLEARTEXT"
end
# PIF's title screen (052_InfiniteFusion/Menus/IntroScreen.rb), as far as
# the versions go
class GenOneStyle
  def initialize
    @viewport = Viewport.new(0, 0, 512, 384)
    @viewport.z = 99_999
  end
  def showUIElements
    Kernel.pbDisplayText("v." + Settings::GAME_VERSION_NUMBER, 455, 5, 99_999)
  end
  def dispose
    Kernel.pbClearText
    @viewport.dispose
  end
end
if ENV["KR_PREVIEW_BACKDROP"].to_s != "" && File.file?(ENV["KR_PREVIEW_BACKDROP"])
  backdrop = Sprite.new(Viewport.new(0, 0, 512, 384))
  backdrop.bitmap = Bitmap.new(ENV["KR_PREVIEW_BACKDROP"])
end
TV.install

$log.clear
title = GenOneStyle.new
title.showUIElements
dump("title_versions")
s = title.instance_variable_get(:@kr_versions)
check("the game's v.6.8.2 is cleared (#{$log.inspect})", $log == ["DISPLAYTEXT v.6.8.2", "CLEARTEXT"] && $hud.empty?)
words = s ? s.bitmap.ops.select { |o| o[0] == "text" }.map { |o| o[5] } : []
check("one to a line in the top right: #{words.inspect}",
      s && s.y == 0 && words == ["PIF 6.8.2", "KIF 1.0.3", "KR #{Reloaded.version}"])
check("...PIF in white, KIF in green, KR in red", TV.parts.map { |_t, c| c } == [TV::WHITE, TV::GREEN, TV::RED])
title.showUIElements
check("shown again: still one line", title.instance_variable_get(:@kr_versions) && !s.disposed? == false)
title.dispose
check("the screen closing takes it away", title.instance_variable_get(:@kr_versions).nil?)

errors = File.read(Reloaded::Log.path).lines.grep(/ERROR|skipped/)
check("no errors or skipped hooks in Kanto Reloaded's log (#{errors.length})", errors.empty?)
errors.first(6).each { |l| puts "  " + l }
puts $failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED"
exit($failed ? 1 : 0)
