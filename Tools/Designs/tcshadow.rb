# encoding: utf-8
# Mockups: five shadow looks for the Trainer Card text (his "Shadow Look"
# change), each drawing the chosen Front (Portrait Lanyard ID).
#   A Soft     - the current one: grey-blue, 1px down-right
#   B PIF      - PIF's card shadow: grey at right, down and down-right
#   C Tinted   - a light tint of each text's own colour, 1px down-right
#   D Deep     - a darker, stronger grey-blue, 1px down-right and 1px down
#   E Outline  - a thin white outline all round
# Usage (from this folder): ruby tcshadow.rb "<KIF Beta>" <work dir with metrics.json>
SRC = File.read(File.join(File.dirname(File.expand_path(__FILE__)), "tclanyard.rb"), :encoding => "UTF-8")
eval(SRC.split("c = palette(2)\n")[0], binding, "tclanyard.rb")

$look = :soft
def shadow_for(color)
  case $look
  when :tinted then Color.new(color.red + (255 - color.red) * 6 / 10, color.green + (255 - color.green) * 6 / 10, color.blue + (255 - color.blue) * 6 / 10)
  when :deep then Color.new(110, 122, 150)
  when :pif then Color.new(160, 160, 160)
  when :outline then Color.new(255, 255, 255)
  else Color.new(150, 160, 184)
  end
end
def offsets
  case $look
  when :pif then [[1, 0], [0, 1], [1, 1]]
  when :deep then [[1, 1], [0, 1]]
  when :outline then [[-1, 0], [1, 0], [0, -1], [0, 1]]
  else [[1, 1]]
  end
end
def stx(t, x, y, w, h, s, color, font = PF::TEXT, align = 0)
  sc = shadow_for(color)
  offsets.each { |dx, dy| P.text(t, x + dx, y + dy, w, h, s, sc, font, align) }
  P.text(t, x, y, w, h, s, color, font, align)
end
def ssm(t, x, y, w, h, s, color, align = 0)
  sc = shadow_for(color)
  offsets.each { |dx, dy| P.small(t, x + dx, y + dy, w, h, s, sc, align) }
  P.small(t, x, y, w, h, s, color, align)
end

c = palette(2)
src = File.read(File.join(HERE, "tclanyard.rb"), :encoding => "UTF-8")
tl1 = src[src.index("#================================================================ TL1")...src.index("#================================================================ TL2")]
tl1 = tl1.sub('shot("TL1")', "shot(\"SH_\#{$look}\")")
[:soft, :pif, :tinted, :deep, :outline].each do |look|
  $look = look
  eval(tl1, binding, "TL1")
end
