# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Reloaded Bag's look
#==============================================================================
# What the Bag (UI/BagScene.rb) and its Custom List editor
# (UI/BagListScreen.rb) both draw with: each pocket's colour and icon, an
# item's picture, name and colour, its use pills, a details plate lit in a
# colour. A screen including it keeps @pictures = {} (the pictures it has
# loaded) and disposes them when it closes.
#==============================================================================

return unless defined?(Reloaded::Frame) && defined?(::KIF::PixelFont) && defined?(Reloaded::PartyPaint) && defined?(Reloaded::Bag)

module Reloaded
  module BagLook
    PF = ::KIF::PixelFont
    PP = Reloaded::PartyPaint
    B = Reloaded::Bag
    P = Reloaded::Pixel
    # Each pocket's colour, Spectrum (his pick, 2026-10-23: the pocket
    # icons' own didn't go well together): hues spread apart so no two
    # pockets look alike. Items blue, Medicine red, Poke Balls gold, TMs
    # & HMs violet, Berries green, Mail teal, Battle Items orange, Key
    # Items magenta. Medicine a slightly lighter red (his ask, 2026-10-23):
    # its own colour lighter, and its names lifted (POCKET_LIFT) above
    # Vivid's one lightness.
    POCKET_RGB = { 1 => [60, 160, 255], 2 => [255, 100, 112], 3 => [255, 196, 32], 4 => [168, 80, 255], 5 => [48, 210, 96],
                   6 => [32, 214, 200], 7 => [255, 128, 32], 8 => [240, 72, 200] }.freeze
    POCKET_LIFT = { 2 => 0.06 }.freeze

    POCKET_ICONS = "Graphics/Pictures/Bag/icon_pocket"

    CATEGORY = "Graphics/Pictures/category"

    private

    def display_name(id)
      it = B.item_data(id)
      return id.to_s unless it
      return ::GameData::Move.get(it.move).name if machine?(it)
      return it.name
    rescue StandardError
      return id.to_s
    end

    def machine?(it)
      return it && it.respond_to?(:is_machine?) && it.is_machine? && it.move ? true : false
    end

    def stone?(it)
      return it && it.respond_to?(:is_evolution_stone?) && it.is_evolution_stone? ? true : false
    end

    def mix(a, b, t)
      return Reloaded::Palette.mix(a, b, t)
    end

    def picture(path)
      return @pictures[path] if @pictures.key?(path)
      resolved = defined?(pbResolveBitmap) ? (pbResolveBitmap(path) || path) : path
      @pictures[path] = (Bitmap.new(resolved) rescue nil)
      return @pictures[path]
    end

    # Words in a colour, made to read on the theme (PartyPaint.ink)
    def ink(c, rgb)
      return PP.ink(c, rgb)
    end

    # An item's name colour: its pocket's (a TM: its move's type), Medicine
    # lifted
    def item_ink(c, id)
      it = B.item_data(id)
      lift = it && !machine?(it) ? POCKET_LIFT[it.pocket.to_i].to_f : 0.0
      return PP.ink(c, item_rgb(id), lift)
    end

    def pocket_rgb(pocket)
      return POCKET_RGB[pocket.to_i] || POCKET_RGB[1]
    end

    def item_rgb(id)
      it = B.item_data(id)
      return Reloaded::PartyScreen.type_rgb(::GameData::Move.get(it.move).type) if machine?(it)
      return pocket_rgb(it ? it.pocket : 1)
    rescue StandardError
      return pocket_rgb(1)
    end

    def pocket_icon(b, i, x, y, size = 28, faint = false)
      sheet = picture(POCKET_ICONS)
      return unless sheet
      b.stretch_blt(Rect.new(x, y, size, size), sheet, Rect.new((i - 1) * 28, 0, 28, 28), faint ? 70 : 255)
    end

    def item_icon(b, id, x, y, size)
      file = (::GameData::Item.icon_filename(id) rescue "Graphics/Items/#{id}")
      bm = picture(file)
      b.stretch_blt(Rect.new(x, y, size, size), bm, Rect.new(0, 0, bm.width, bm.height)) if bm
    end

    def small_type(b, type, x, y)
      sheet = picture(PP::TYPES_SMALL)
      b.blt(x, y, sheet, Rect.new(0, PP.type_row(type) * 16, 16, 16)) if sheet
    end

    def big_type(b, type, x, y)
      sheet = picture(PP::TYPES_BIG)
      b.stretch_blt(Rect.new(x, y, 38, 17), sheet, Rect.new(0, PP.type_row(type) * 28, 64, 28)) if sheet
      return 38
    end

    def big_category(b, cat, x, y)
      sheet = picture(CATEGORY)
      b.stretch_blt(Rect.new(x, y, 38, 17), sheet, Rect.new(0, cat.to_i * 28, 64, 28)) if sheet
      return 38
    end

    def pill(b, c, x, y, label, tone_key, right = false)
      tone = c[tone_key] || c[:dim]
      fill = c[:light] ? mix(c[:panel2], tone, 0.22) : mix(c[:panel2], tone, 0.28)
      return P.pill(b, x, y, label, fill, tone, right)
    end

    def desc_lines(b, text, w, n)
      lines = P.small_wrap(b, text, w)
      return lines if lines.length <= n
      out = lines.first(n)
      last = out[-1]
      P.small_font(b)
      last = last.sub(/\s*\S+\z/, "") while !last.empty? && b.text_size(last + "...").width > w
      out[-1] = last + "..."
      return out
    end

    # A details panel lit in a colour, with the Party Screen's two bands
    def plate(base, c, col, x0, y0, x1, y1, cut = 16)
      topc = mix(c[:panel], col, 0.4)
      bottom = mix(c[:panel], c[:dark], 0.4)
      PP.chamfer_grad(base, x0, y0, x1, y1, cut, topc, bottom, mix(c[:line], col, 0.5))
      from = x1 - 48
      to = x0 + 24
      ly = y0 + (y1 - y0) / 3
      (y0 + 1...y1 - 1).each do |y|
        t = (y - y0).to_f / (y1 - y0)
        left = x0 + 1 + [cut - (y - y0), 0].max
        right = x1 - 1 - [cut - (y1 - 1 - y), 0].max
        mid = from + (to - from) * t
        k = y < ly ? 0.4 : 0.22 - 0.18 * (y - ly).to_f / [y1 - ly, 1].max
        tint = mix(mix(topc, bottom, t), col, k)
        [[0, 56], [40, 8]].each do |off, bw|
          a = [(mid + off - bw / 2.0).round, left].max
          b = [(mid + off + bw / 2.0).round, right].min
          base.fill_rect(a, y, b - a, 1, tint) if b > a
        end
      end
    end

    # What it's good for, from the game's own data (006_Item.rb)
    def use_tags(it)
      tags = []
      field = it.respond_to?(:field_use) ? it.field_use.to_i : 0
      battle = it.respond_to?(:battle_use) ? it.battle_use.to_i : 0
      tags << [_INTL("USE"), :green] if [1, 2, 5].include?(field)
      tags << [_INTL("IN BATTLE"), :blue] if battle > 0
      tags << [_INTL("HOLD"), :gold] if it.respond_to?(:can_hold?) && it.can_hold? && field == 0 && battle == 0
      tags << [_INTL("KEY ITEM"), :pink] if it.respond_to?(:is_key_item?) && it.is_key_item?
      return tags
    end

    def use_pills(top, c, x, y, it)
      bx = x
      use_tags(it).each { |label, tone| bx += pill(top, c, bx, y, label, tone) + 6 }
      return bx - x
    end

    def quick_slot(id)
      return nil unless defined?(Reloaded::OverworldMenu) && Reloaded::OverworldMenu.respond_to?(:quick_items)
      i = Reloaded::OverworldMenu.quick_items.index(id.to_s.to_sym)
      return i ? i + 1 : nil
    rescue StandardError
      return nil
    end
  end
end
