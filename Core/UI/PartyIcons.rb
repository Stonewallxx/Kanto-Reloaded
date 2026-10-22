#==============================================================================
# Kanto Reloaded: party icons in Kanto Reloaded's screens
#==============================================================================
# The game's own icons (PokemonIconSprite), whichever kind the player has:
# PIF's small icons (64 px frames, the art low in the frame) or KIF Beta's
# Big Pokémon Icons (battle sprites at a third, 96 px frames, the art in the
# middle). Big ones are scaled to the small ones' size, so six always fit in
# a row (decided 2026-10-19), and KIF's 16 px shift for big icons (made
# for the party screen) is left out. Each is placed by the middle of its
# art, so a row sits the same either way.
#==============================================================================

module Reloaded
  module PartyIcons
    MAX_STEP = 52           # the most room between two icons' middles
    FRAME = 64              # PIF's icon frame: bigger ones are scaled to it

    module_function

    # A row of up to six icons, centred on cx, their art's middle on cy,
    # inside `room` pixels.
    def row(party, viewport, cx, cy, room, z = 2)
      return [] unless defined?(::PokemonIconSprite)
      icons = Array(party).compact.first(6).map { |pkmn| icon(pkmn, viewport, z) }.compact
      arrange(icons, cx, cy, room)
      return icons
    end

    # The row again, somewhere else (a list that scrolls).
    def arrange(icons, cx, cy, room)
      return if icons.empty?
      step = [room / icons.length, MAX_STEP].min
      x0 = cx - step * (icons.length - 1) / 2.0
      icons.each_with_index { |s, i| place(s, (x0 + i * step).round, cy) }
    end

    def icon(pkmn, viewport, z = 2)
      s = ::PokemonIconSprite.new(pkmn, viewport)
      s.kif_big_offset = false if s.respond_to?(:kif_big_offset=)
      s.z = z
      return s
    rescue StandardError => e
      Reloaded::Log.exception("A party icon couldn't be made", e, :saves)
      return nil
    end

    # KIF Beta's Big Pokémon Icons is on (Limited or All: Kanto Reloaded's
    # screens aren't the PC boxes)
    def big?
      return defined?(::KIF::BigIcons) && ::KIF::BigIcons.mode >= 1 ? true : false
    rescue StandardError
      return false
    end

    # A species' icon when there's no Pokémon to make one from (a list of
    # the wild ones here): square frames, the first one the picture; the
    # caller disposes it. With Big Pokémon Icons on, the battle sprite the
    # game shows for that species (the alt the player picked); else PIF's
    # small icon.
    def species_bitmap(species)
      if big?
        b = big_species_bitmap(species)
        return b if b
      end
      path = (::GameData::Species.icon_filename_from_species(species) rescue nil) || "Graphics/Pokemon/Icons/#{species}"
      return Bitmap.new(path)
    rescue StandardError
      return nil
    end

    # An Egg whose species isn't known yet (the one a Day Care has
    # waiting): KIF Beta's Egg battle sprite with Big Pokémon Icons on,
    # else PIF's Egg icon. The caller disposes it.
    def egg_bitmap
      return Bitmap.new(big? ? "Graphics/Battlers/Eggs/000" : "Graphics/Icons/iconEgg")
    rescue StandardError
      return nil
    end

    def big_species_bitmap(species)
      return nil unless defined?(::BattleSpriteLoader)
      loader = ::BattleSpriteLoader.new
      pif = loader.get_pif_sprite_from_species(::GameData::Species.get(species).id_number)
      anim = pif ? loader.load_pif_sprite_directly(pif) : nil
      return nil unless anim && anim.bitmap
      src = anim.bitmap
      f = [src.height, 1].max
      out = Bitmap.new(f, f)
      out.blt(0, 0, src, Rect.new(0, 0, f, f))
      anim.dispose if anim.respond_to?(:dispose)
      return out
    rescue StandardError => e
      Reloaded::Log.exception("A big icon couldn't be made for #{species}", e, :ui)
      return nil
    end

    # The part of a square frame (the first, f px) the Pokémon is in, so a
    # list can fit the Pokémon itself to its box rather than the frame and
    # its margins. The frame is looked at on a grid of about 64 x 64 points
    # (from each edge in, stopping at the first one it finds), then widened
    # by one step, as a point between them may be part of it.
    def art_rect(bm, f)
      whole = Rect.new(0, 0, f, f)
      return whole unless bm.respond_to?(:get_pixel)
      s = [f / 64, 1].max
      pts = (0...f).step(s).to_a
      seen = proc { |x, y| bm.get_pixel(x, y).alpha > 16 }
      top = pts.find { |y| pts.any? { |x| seen.call(x, y) } }
      return whole unless top
      bottom = pts.reverse.find { |y| pts.any? { |x| seen.call(x, y) } }
      inside = pts.select { |y| y >= top && y <= bottom }
      left = pts.find { |x| inside.any? { |y| seen.call(x, y) } }
      right = pts.reverse.find { |x| inside.any? { |y| seen.call(x, y) } }
      x0 = [left - s, 0].max
      y0 = [top - s, 0].max
      x1 = [right + s, f - 1].min
      y1 = [bottom + s, f - 1].min
      return Rect.new(x0, y0, x1 - x0 + 1, y1 - y0 + 1)
    rescue StandardError
      return whole
    end

    # The art's middle on x, y: PIF's icons leave the top quarter of the
    # frame blank, battle sprites stand in the middle of theirs.
    def place(s, x, y)
      w = s.src_rect.width
      h = s.src_rect.height
      zoom = h > FRAME ? FRAME.to_f / h : 1.0
      s.zoom_x = s.zoom_y = zoom
      s.ox = w / 2
      s.oy = h > FRAME ? h / 2 : h * 9 / 16
      s.x = x
      s.y = y
    end
  end
end
