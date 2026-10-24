# encoding: utf-8
# Mockups: two Bag additions (his picks, 2026-10-23), three designs each,
# drawn by the real Bag on its preview's stand-ins (Tools/Tests/bag_preview.rb).
#   med   Who Needs It: the party in a healing item's details (Potion, then
#         Revive and Ice Heal):
#           1 Party Grid      as the TMs' check: each icon, an HP bar, a word
#           2 Party List      a row each: name, HP bar, status, the word
#           3 Lit Icons       icons and HP bars only; who it can't help faint
#   held  Held Items: Leftovers, which Pikachu holds:
#           1 HELD Pill       a HELD pill on the row; the details say who
#           2 Held Heading    the pocket opens with what your party holds
#           3 Party Strip     the details show each Pokémon's held item,
#                             the ones holding this lit
# Usage (from the mod folder): ruby Tools/Designs/bag/party_check_designs.rb "<KIF Beta>" <work dir with metrics.json>
#                              python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>
TEST = File.join(ARGV[0], "Mods/KantoReloaded/Tools/Tests/bag_preview.rb")
eval(File.read(TEST, :encoding => "UTF-8").split("#---------------------------------------------------------------- helpers")[0], binding, TEST)
P = Reloaded::Pixel unless defined?(P)
PF = ::KIF::PixelFont unless defined?(PF)
PP = Reloaded::PartyPaint unless defined?(PP)
DETAILS_Y = Reloaded::BagScene::DETAILS_Y
ROW_H = Reloaded::BagScene::ROW_H
W = 512 unless defined?(W)
H = 384 unless defined?(H)
class PkB
  attr_accessor :hp, :totalhp, :status, :item, :level
end
hp = [[78, 95, :NONE, :LEFTOVERS, 34], [0, 120, :NONE, nil, 40], [110, 110, :NONE, :MYSTICWATER, 35], [60, 160, :POISON, nil, 41], [1, 1, :NONE, nil, 1]]
$Trainer.party.each_with_index { |p, i| p.hp, p.totalhp, p.status, p.item, p.level = hp[i] }
[[:REVIVE, 28, "Revive", 2, "A medicine that revives a fainted Pokémon. It restores half the Pokémon's maximum HP.", 1, 1],
 [:LEFTOVERS, 600, "Leftovers", 1, "An item to be held by a Pokémon. The holder's HP is gradually restored during battle.", 0, 0],
 [:MYSTICWATER, 601, "Mystic Water", 1, "An item to be held by a Pokémon. It's a teardrop-shaped gem that boosts the power of Water-type moves.", 0, 0]]
  .each { |a| GameData::Item.add(*a) }
$PokemonBag.pbStoreItem(:REVIVE, 2)
$PokemonBag.pbStoreItem(:LEFTOVERS, 1)
MED = { :POTION => :hp, :SUPERPOTION => :hp, :HYPERPOTION => :hp, :REVIVE => :revive, :ICEHEAL => :status }.freeze
$med = nil
$held = nil
$bs = nil
Reloaded::BagScreen.scene_class.prepend(Module.new do
  def pbStartScene(*a); $bs = self; super; end

  def word_for(p, kind)
    return [_INTL("Egg"), :dim] if p.egg?
    case kind
    when :revive then return p.hp <= 0 ? [_INTL("Can Revive"), :green] : [_INTL("Not Fainted"), :dim]
    when :status
      return [_INTL("Fainted"), :dim] if p.hp <= 0
      return p.status != :NONE ? [_INTL("Can Cure"), :green] : [_INTL("Healthy"), :dim]
    end
    return [_INTL("Fainted"), :red] if p.hp <= 0
    return p.hp >= p.totalhp ? [_INTL("Full HP"), :dim] : [_INTL("Can Heal"), :green]
  end

  def helps?(p, kind)
    return word_for(p, kind)[1] == :green
  end

  def draw_details(base, top, c)
    r = @rows && @rows[@sel]
    return held_row_details(base, top, c, r) if $held == 2 && r && r[0] == :held
    id = current
    return held_details(base, top, c, id) if $held && id == :LEFTOVERS && $held != 2
    kind = MED[id]
    return super unless $med && kind
    @icons.each { |s| s.visible = false if s }
    it = B.item_data(id)
    py0 = DETAILS_Y
    py1 = H - P::HINT_H - 5
    plate(base, c, PP.rgb(item_rgb(id)), 6, py0, W - 6, py1, 12)
    tw = $med == 2 ? 226 : 282
    P.text(top, 18, py0 + 5, tw, 22, PF.fit(PF::ROW, it.name, tw), c[:strong], PF::ROW)
    use_pills(top, c, 18, py0 + 32, it)
    desc_lines(top, it.description.to_s, tw, 3).each_with_index { |ln, i| P.small(top, 18, py0 + 52 + i * 15, tw, 15, ln, c[:txt]) }
    case $med
    when 1
      party.each_with_index do |p, i|
        cx = 308 + (i % 3) * 64 + 32
        cy = py0 + 6 + (i / 3) * 52
        fit_icon(i, cx, cy + 12, 24)
        PP.bar(top, c, cx - 18, cy + 27, 36, p.hp.to_f / [p.totalhp, 1].max, PP.hp_colour(c, p), 3) unless p.egg?
        word, tone = word_for(p, kind)
        P.text(top, cx - 32, cy + 33, 64, 12, word, c[tone] || c[:dim], PF::TINY, 2)
      end
    when 2
      x0 = 250
      party.each_with_index do |p, i|
        ry = py0 + 6 + i * 17
        fit_icon(i, x0 + 8, ry + 7, 16)
        P.text(top, x0 + 20, ry, 70, 14, p.egg? ? _INTL("Egg") : p.name, c[:txt], PF::TINY)
        unless p.egg?
          PP.bar(top, c, x0 + 92, ry + 5, 50, p.hp.to_f / [p.totalhp, 1].max, PP.hp_colour(c, p), 3)
          st = PP::STATUS[p.status]
          P.pill(top, x0 + 150, ry, st[0], *PP.badge(c, st[1]), false) if st && p.hp > 0
        end
        word, tone = word_for(p, kind)
        P.text(top, x0 + 172, ry, W - 18 - (x0 + 172), 14, word, c[tone] || c[:dim], PF::TINY, 1)
      end
    when 3
      party.each_with_index do |p, i|
        cx = 308 + (i % 3) * 64 + 32
        cy = py0 + 10 + (i / 3) * 52
        fit_icon(i, cx, cy + 14, 28)
        @icons[i].opacity = helps?(p, kind) ? 255 : 90 if @icons[i]
        PP.bar(top, c, cx - 18, cy + 32, 36, p.hp.to_f / [p.totalhp, 1].max, PP.hp_colour(c, p), 3) unless p.egg?
      end
    end
  end

  def held_details(base, top, c, id)
    @icons.each { |s| s.visible = false if s }
    it = B.item_data(id)
    py0 = DETAILS_Y
    py1 = H - P::HINT_H - 5
    plate(base, c, PP.rgb(item_rgb(id)), 6, py0, W - 6, py1, 12)
    tw = $held == 3 ? 282 : 360
    P.text(top, 18, py0 + 5, tw, 22, PF.fit(PF::ROW, it.name, tw), c[:strong], PF::ROW)
    bx = 18 + use_pills(top, c, 18, py0 + 32, it)
    pill(top, c, bx, py0 + 32, _INTL("HELD"), :gold) if $held == 1
    if $held == 1
      desc_lines(top, it.description.to_s, 360, 2).each_with_index { |ln, i| P.small(top, 18, py0 + 52 + i * 15, 360, 15, ln, c[:txt]) }
      P.small(top, 18, py0 + 84, 60, 15, _INTL("Held by:"), c[:dim])
      fit_icon(0, 84, py0 + 91, 18)
      P.small(top, 96, py0 + 84, 200, 15, _INTL("Pikachu"), c[:txt])
      P.ui.rbox(base, W - 92, py0 + 8, W - 18, py0 + 70, 6, c[:light] ? mix(c[:panel2], PP::WHITE, 0.5) : mix(c[:dark], c[:panel], 0.3), c[:line])
      item_icon(top, id, W - 79, py0 + 15, 48)
    else
      desc_lines(top, it.description.to_s, 282, 3).each_with_index { |ln, i| P.small(top, 18, py0 + 52 + i * 15, 282, 15, ln, c[:txt]) }
      party.each_with_index do |p, i|
        cx = 308 + (i % 3) * 64 + 32
        cy = py0 + 6 + (i / 3) * 52
        holds = p.item == id
        if holds
          P.ui.rbox(base, cx - 30, cy - 2, cx + 30, cy + 48, 5, mix(c[:panel2], c[:gold], 0.25), c[:gold])
        end
        fit_icon(i, cx - 10, cy + 13, 24)
        item_icon(top, p.item, cx + 8, cy + 4, 20) if p.item
        word = p.egg? ? _INTL("Egg") : (p.item ? B.item_name(p.item) : _INTL("Nothing"))
        P.text(top, cx - 32, cy + 33, 64, 12, PF.fit(PF::TINY, word, 62), holds ? c[:gold] : c[:dim], PF::TINY, 2)
      end
    end
  end

  # Design 2's details for a held row: who holds it; A takes it back
  def held_row_details(base, top, c, r)
    @icons.each { |s| s.visible = false if s }
    _k, id, i = r
    it = B.item_data(id)
    py0 = DETAILS_Y
    py1 = H - P::HINT_H - 5
    plate(base, c, PP.rgb(item_rgb(id)), 6, py0, W - 6, py1, 12)
    P.text(top, 18, py0 + 5, 360, 22, PF.fit(PF::ROW, it.name, 360), c[:strong], PF::ROW)
    pill(top, c, 18, py0 + 32, _INTL("HELD BY {1}", party[i].name.upcase), :gold)
    desc_lines(top, it.description.to_s, 360, 2).each_with_index { |ln, k| P.small(top, 18, py0 + 52 + k * 15, 360, 15, ln, c[:txt]) }
    P.small(top, 18, py0 + 84, 360, 15, _INTL("A takes it back into the Bag."), c[:dim])
    P.ui.rbox(base, W - 92, py0 + 8, W - 18, py0 + 70, 6, c[:light] ? mix(c[:panel2], PP::WHITE, 0.5) : mix(c[:dark], c[:panel], 0.3), c[:line])
    fit_icon(i, W - 55, py0 + 39, 44)
    item_icon(top, id, W - 46, py0 + 46, 24)
  end

  def hint_pairs
    r = @rows && @rows[@sel]
    if $held == 2 && r && r[0] == :held
      return [[:ud, _INTL("Choose")], [:lr, _INTL("Pockets")], [button(:C), _INTL("Take Back")], [button(:B), _INTL("Close")]]
    end
    return super
  end

  # Held Heading (design 2): the pocket opens with what the party holds
  def build_rows
    super
    return unless $held == 2 && @pocket == 1 && @query.nil? && !@moving
    held = party.each_with_index.select { |p, _i| p.item && B.item_data(p.item) && B.item_data(p.item).pocket == 1 }
    return if held.empty?
    extra = [[:heading, _INTL("Held by Your Party")]] + held.map { |p, i| [:held, p.item, i] }
    @rows = extra + [[:heading, _INTL("In the Bag")]] + @rows
    @sel = 1
  end

  def row_height(r)
    return r[0] == :held ? ROW_H : super
  end

  def item_row(top, c, x, y, w, r)
    if r[0] == :held
      _k, id, i = r
      right = x + w
      item_icon(top, id, right - 24, y, 24)
      right -= 30
      fit_icon(i, right - 10, y + 12, 20)
      right -= 26
      col = ink(c, item_rgb(id))
      P.text(top, x + 11, y + 1, right - x - 11, ROW_H - 2, PF.fit(PF::TEXT, B.item_name(id), right - x - 11), col, PF::TEXT)
      return
    end
    super
    _k, id, _q = r
    if $held == 1 && party.any? { |p| p.item == id }
      nw = P.width(PF::TEXT, display_name(id))
      pill(top, c, x + 11 + nw + 6, y + (ROW_H - 15) / 2, _INTL("HELD"), :gold)
    end
  end
end)
$pad_name = "Xbox Series X Controller"

def shoot(name, pocket, item, extra = [])
  [[0, "dark"], [2, "light"]].each do |mode, word|
    S.set(Reloaded::Palette::MODE, mode)
    $PokemonBag.lastpocket = pocket
    Input.queue = [at { t = $bs.instance_variable_get(:@rows).index { |r| r[1] == item && r[0] != :heading }
                        $bs.instance_variable_set(:@sel, t) if t
                        $bs.send(:draw) },
                   dmp("#{name}_#{word}"), *extra, I::BACK]
    begin
      PokemonBagScreen.new(PokemonBag_Scene.new, $PokemonBag).pbStartScreen
    rescue QueueEmpty
      check("#{name} #{word}: ran out of input", false)
    end
  end
end

[1, 2, 3].each do |d|
  $med = d
  shoot("med-#{d}a", 2, :POTION)
  shoot("med-#{d}b", 2, :REVIVE)
  shoot("med-#{d}c", 2, :ICEHEAL)
end
$med = nil
[1, 2, 3].each do |d|
  $held = d
  shoot("held-#{d}", 1, :LEFTOVERS)
end
$held = nil
S.set(Reloaded::Palette::MODE, 0)
puts "designs done"
