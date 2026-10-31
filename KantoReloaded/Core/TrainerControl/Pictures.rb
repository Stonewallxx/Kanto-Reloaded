# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Trainer Control's trainer pictures
#==============================================================================
# A class's picture (the game's front sprite), where its art is inside the
# frame, and its face: a square around the head, for the Battle Records
# list and the record toast. Each is looked at every 2 pixels.
#
#   Pictures.bitmap(type)   a new Bitmap, or nil (the caller disposes it)
#   Pictures.bounds(bm)     [left, top, right, bottom, the head's middle]
#   Pictures.face(type)     a new 64 x 64 Bitmap, or nil
#==============================================================================

module Reloaded
  module TrainerControl
    module Pictures
      FACE = 64

      module_function

      def path(type)
        file = (::GameData::TrainerType.front_sprite_filename(type.to_s.to_sym) rescue nil) || "Graphics/Trainers/#{type}"
        return defined?(pbResolveBitmap) ? (pbResolveBitmap(file) || file) : file
      end

      def bitmap(type)
        return nil if type.to_s.empty?
        return Bitmap.new(path(type))
      rescue StandardError
        return nil
      end

      def bounds(bm)
        w = bm.width
        h = bm.height
        return [0, 0, w, h, w / 2] unless bm.respond_to?(:get_pixel)
        xs = (0...w).step(2).to_a
        ys = (0...h).step(2).to_a
        seen = proc { |x, y| bm.get_pixel(x, y).alpha > 16 }
        top = ys.find { |y| xs.any? { |x| seen.call(x, y) } } || 0
        bottom = ys.reverse.find { |y| xs.any? { |x| seen.call(x, y) } } || h - 2
        left = xs.find { |x| ys.any? { |y| seen.call(x, y) } } || 0
        right = xs.reverse.find { |x| ys.any? { |y| seen.call(x, y) } } || w - 2
        head = xs.select { |x| (top..[top + 18, h - 1].min).step(2).any? { |y| seen.call(x, y) } }
        hx = head.empty? ? (left + right) / 2 : (head.min + head.max) / 2
        return [left, top, right + 2, bottom + 2, hx]
      end

      def face(type)
        bm = bitmap(type)
        return nil unless bm
        l, t, r, b, hx = bounds(bm)
        s = [[(b - t) * 0.42, r - l].min, 44].max.round
        x = [[hx - s / 2, 0].max, [bm.width - s, 0].max].min
        out = Bitmap.new(FACE, FACE)
        out.stretch_blt(Rect.new(0, 0, FACE, FACE), bm, Rect.new(x, [t - 2, 0].max, s, s))
        return out
      rescue StandardError
        return nil
      ensure
        bm.dispose if bm && !bm.disposed?
      end
    end
  end
end
