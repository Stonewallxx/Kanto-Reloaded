# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Trainer Control's trainer pictures
#==============================================================================
# A class's picture (the game's front sprite), where its art is inside the
# frame, and its face: a square around the head, for the Battle Records
# list and the record toast. Each is looked at every 2 pixels.
# The faces he placed himself (the Trainer Face Picker, 2026-11-01: no one
# rule finds every face past a net, a pitchfork or a raised hand) are FACES;
# any other picture, or one of a different size (a mod's), takes the rule.
#
#   Pictures.bitmap(type)   a new Bitmap, or nil (the caller disposes it)
#   Pictures.bounds(bm)     [left, top, right, bottom, the head's middle]
#   Pictures.box(type, bm)  [x, y, size]: the face's square in the picture
#   Pictures.face(type)     a new 64 x 64 Bitmap, or nil
#==============================================================================

module Reloaded
  module TrainerControl
    module Pictures
      FACE = 64
      # picture name => [x, y, size, the picture's width, height]
      FACES = {
        "AROMALADY" => [55, 17, 60, 160, 160],
        "BUGCATCHER" => [43, 28, 71, 160, 160],
        "BUGCATCHER_F" => [71, 41, 46, 160, 160],
        "CHAMPION_Sinnoh" => [48, 0, 66, 160, 160],
        "CHANNELER" => [38, 35, 58, 150, 150],
        "CLOWN" => [55, 13, 61, 160, 160],
        "COOLCOUPLE" => [24, 0, 71, 128, 128],
        "COOLTRAINER_F" => [59, 10, 68, 160, 160],
        "COOLTRAINER_F2" => [47, 4, 72, 160, 160],
        "CRUSHGIRL" => [50, 19, 62, 160, 160],
        "CRUSHKIN" => [27, 0, 79, 128, 128],
        "CUEBALL" => [55, 0, 84, 160, 160],
        "DELIVERYMAN" => [37, 5, 73, 160, 160],
        "DELIVERYMAN2" => [43, 0, 82, 160, 160],
        "ELITEFOUR_Agatha" => [51, 15, 61, 160, 160],
        "ELITEFOUR_Bruno" => [42, 0, 76, 160, 160],
        "ELITEFOUR_Lance" => [39, 0, 75, 160, 160],
        "ELITEFOUR_Lorelei" => [49, 4, 71, 160, 160],
        "ENGINEER" => [33, 0, 63, 128, 128],
        "FARMER" => [46, 18, 80, 160, 160],
        "FISHERMAN" => [93, 21, 79, 172, 160],
        "GAMBLER" => [43, 16, 54, 128, 128],
        "GENTLEMAN" => [36, 6, 78, 160, 160],
        "HAUNTEDGIRL" => [42, 1, 62, 128, 128],
        "HAUNTEDGIRL_YOUNG" => [18, 59, 87, 128, 171],
        "HIKER" => [50, 0, 83, 160, 160],
        "HIPSTER" => [42, 19, 75, 160, 178],
        "JUGGLER" => [45, 3, 82, 160, 160],
        "KIMONOGIRL" => [39, 0, 80, 160, 160],
        "LADY" => [30, 0, 67, 128, 128],
        "LASS" => [39, 8, 77, 160, 160],
        "LASS_blue" => [39, 14, 76, 160, 160],
        "LEADER_Blaine" => [30, 0, 84, 160, 160],
        "LEADER_Brock" => [30, 11, 53, 128, 128],
        "LEADER_Clair" => [49, 5, 63, 160, 160],
        "LEADER_Erika" => [57, 7, 61, 160, 160],
        "LEADER_Falkner" => [29, 12, 61, 160, 160],
        "LEADER_Jasmine" => [55, 7, 58, 160, 160],
        "LEADER_Koga" => [48, 12, 63, 160, 160],
        "LEADER_Kurt" => [38, 4, 70, 160, 160],
        "LEADER_Misty" => [58, 37, 58, 160, 160],
        "LEADER_Whitney" => [36, 4, 68, 160, 160],
        "MR_FUJI" => [38, 7, 60, 128, 128],
        "PICNICKER" => [61, 8, 86, 160, 160],
        "POKEMANIAC" => [39, 7, 79, 160, 160],
        "POKEMONRANGER_F" => [46, 11, 75, 160, 160],
        "POKEMONRANGER_M" => [44, 9, 80, 160, 160],
        "POKEMONTRAINER_Gold" => [43, 23, 64, 160, 160],
        "POKEMONTRAINER_May" => [40, 12, 49, 128, 128],
        "POKEMONTRAINER_Red" => [47, 17, 74, 160, 160],
        "PRESCHOOLER_F" => [36, 40, 54, 128, 128],
        "PRESCHOOLER_M" => [42, 40, 47, 128, 128],
        "PSYCHIC_F" => [41, 14, 79, 160, 164],
        "PSYCHIC_M" => [48, 12, 72, 160, 160],
        "PYROMANIAC" => [52, 1, 74, 160, 160],
        "RIVAL1" => [54, 3, 61, 160, 160],
        "RIVAL2" => [46, 9, 54, 128, 128],
        "ROBOT" => [49, 16, 68, 160, 160],
        "ROCKER" => [34, 0, 64, 128, 128],
        "ROCKETEXEC_F" => [27, 17, 67, 160, 160],
        "ROCKETEXEC_M" => [66, 25, 62, 160, 160],
        "ROUGHNECK" => [35, 20, 50, 128, 128],
        "RUINMANIAC" => [39, 15, 62, 128, 128],
        "SAILOR" => [44, 6, 76, 160, 160],
        "SCIENTIST" => [51, 7, 72, 160, 160],
        "SCIENTIST_Colress" => [53, 0, 76, 160, 160],
        "SISANDBRO" => [24, 1, 84, 128, 128],
        "SKIER_F" => [41, 12, 72, 160, 160],
        "SOCIALITE" => [30, 0, 60, 136, 136],
        "SUPERNERD" => [67, 42, 65, 160, 160],
        "SWIMMER2_F" => [32, 6, 58, 128, 128],
        "SWIMMER2_M" => [33, 25, 54, 128, 128],
        "SWIMMER_F" => [44, 4, 70, 160, 160],
        "SWIMMER_M" => [31, 25, 57, 128, 128],
        "TAMER" => [30, 1, 60, 128, 128],
        "TEACHER" => [40, 0, 66, 140, 140],
        "TEAMPLASMA_M" => [54, 6, 80, 160, 160],
        "TEAMROCKET_F" => [27, 21, 64, 160, 160],
        "TUBER2_F" => [41, 46, 51, 128, 128],
        "TUBER2_M" => [40, 34, 55, 128, 128],
        "TUBER_F" => [39, 47, 53, 128, 128],
        "TUBER_M" => [42, 34, 56, 128, 128],
        "TWINS" => [38, 27, 56, 128, 128],
        "WORKER" => [38, 25, 66, 160, 160],
        "YOUNGCOUPLE" => [26, 8, 82, 160, 160],
        "YOUNGSTER" => [51, 42, 64, 160, 160],
      }.freeze

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

      def box(type, bm)
        his = FACES[File.basename(path(type).to_s, ".*")]
        return his[0, 3] if his && his[3] == bm.width && his[4] == bm.height
        l, t, r, b, hx = bounds(bm)
        s = [[(b - t) * 0.42, r - l].min, 44].max.round
        x = [[hx - s / 2, 0].max, [bm.width - s, 0].max].min
        return [x, [t - 2, 0].max, s]
      end

      def face(type)
        bm = bitmap(type)
        return nil unless bm
        x, y, s = box(type, bm)
        out = Bitmap.new(FACE, FACE)
        out.stretch_blt(Rect.new(0, 0, FACE, FACE), bm, Rect.new(x, y, s, s))
        return out
      rescue StandardError
        return nil
      ensure
        bm.dispose if bm && !bm.disposed?
      end
    end
  end
end
