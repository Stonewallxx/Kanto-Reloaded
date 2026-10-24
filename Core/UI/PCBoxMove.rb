# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Reloaded PC's Move Box
#==============================================================================
# More of the PC scene (UI/PCScene.rb), his pick (2026-10-25): Move Whole
# Boxes, Lifted Tile. In Box Overview, Y picks up the box under the cursor
# (Move Box in a box's actions picks up the one you're in): the tiles show
# the new order as it moves, the moving one lit, with a MOVING pill and a
# soft shadow under it. A puts it down, B puts it back where it was.
#
# A box moves with its Pokémon, name, wallpaper and locks. The Transfer
# Box keeps its place, and the box you're in stays the one you're in. The
# moving is Reloaded::PC.move_box.
#==============================================================================

return unless defined?(Reloaded::PCScene)

module Reloaded
  module PC
    class << self
      # Box from goes where box to is, the boxes between shifting along; a
      # box that can't move (the Transfer Box) keeps its place. The box being
      # looked at stays the current one. True when it moved.
      def move_box(storage, from, to)
        spots = (0...storage.maxBoxes).select { |i| movable_box?(storage[i]) }
        return false if from == to || !spots.include?(from) || !spots.include?(to)
        current = storage.boxes[storage.currentBox]
        order = spots.map { |i| storage.boxes[i] }
        order.insert(spots.index(to), order.delete_at(spots.index(from)))
        spots.each_with_index { |i, k| storage.boxes[i] = order[k] }
        now = storage.boxes.index { |b| b.equal?(current) }
        storage.currentBox = now if now
        return true
      end

      def movable_box?(b)
        return false unless b
        return !(defined?(::StorageTransferBox) && b.is_a?(::StorageTransferBox))
      end
    end
  end

  module PCScene
    # Move Box in a box's actions: the one you're in, picked up in Box
    # Overview; it closes again once it's put down
    def kr_move_box
      return pbPlayBuzzerSE unless box_move_ok? && Reloaded::PC.movable_box?(box)
      box_overview(true)
    end

    # Why Move Box is dimmed (nil: it isn't)
    def kr_box_move_reason
      return _INTL("The Transfer Box stays where it is.") unless Reloaded::PC.movable_box?(box)
      return _INTL("Put down what you're holding first.") if held || !multi_held.empty?
      return _INTL("There's only one box.") unless box_move_ok?
      return nil
    end

    private

    # A box can be picked up: organising, nothing held, two boxes or more
    def box_move_ok?
      return false unless quick? && held.nil? && multi_held.empty? && !fusing?
      return overview_tiles.count { |t| t.is_a?(Integer) } > 1
    end

    def ov_moving
      return @kr_ov && @kr_ov[:moving]
    end

    # How many tiles the cursor can reach: the boxes only while one moves
    def ov_count
      tiles = @kr_ov[:tiles]
      return ov_moving ? tiles.count { |t| t.is_a?(Integer) } : tiles.length
    end

    # Y: the box under the cursor is picked up
    def ov_pick_up(once = false)
      tile = @kr_ov[:tiles][@kr_ov[:sel]]
      unless tile.is_a?(Integer) && box_move_ok?
        pbPlayBuzzerSE
        return
      end
      pbPlayDecisionSE
      @kr_ov[:moving] = { :from => @kr_ov[:sel], :keep => @kr_ov[:tiles].dup, :once => once }
      refresh
    end

    # The moving box goes to tile to, the others shifting along
    def ov_carry(to)
      return if to < 0 || to >= ov_count || to == @kr_ov[:sel]
      tiles = @kr_ov[:tiles]
      tiles.insert(to, tiles.delete_at(@kr_ov[:sel]))
      @kr_ov[:sel] = to
      ov_scroll
      pbPlayCursorSE
      refresh
    end

    # A: the box is put down where it is now
    def ov_put_down
      mv = @kr_ov.delete(:moving)
      keep = mv[:keep]
      to = @kr_ov[:sel]
      picked = @kr_picks && @storage.boxes[@kr_picks[0]]
      if to != mv[:from] && Reloaded::PC.move_box(@storage, keep[mv[:from]], keep[to])
        pbPlayDecisionSE
        if picked                                    # the picks stay with their box
          now = @storage.boxes.index { |b| b.equal?(picked) }
          now ? @kr_picks[0] = now : @kr_picks = nil
        end
      else
        pbPlayCursorSE
      end
      @kr_ov[:tiles] = overview_tiles
      @kr_match = {}
      refresh
    end

    # B: the box goes back where it was
    def ov_put_back
      mv = @kr_ov.delete(:moving)
      @kr_ov[:tiles] = mv[:keep]
      @kr_ov[:sel] = mv[:from]
      ov_scroll
      pbPlayCancelSE
      refresh
    end

    # The moving box: lit by the cursor, a MOVING pill and a soft shadow
    # under it, on the marks layer (over the icons)
    def moving_marks(c, tx, ty, locked)
      m = marks
      m.fill_rect(tx + 6, ty + OV_TH + 2, OV_TW - 12, 3, Color.new(0, 0, 0, 80))
      words = _INTL("MOVING")
      w = P.width(PF::TINY, words) + 12
      P.pill(m, tx + OV_TW - w - (locked ? 22 : 6), ty + OV_TH - 18, words, c[:gold], c[:dark], false)
    end

    def moving_hints
      return [[:ud, _INTL("Choose")], [button(:C), _INTL("Put Here")], [button(:B), _INTL("Cancel")]]
    end
  end
end
