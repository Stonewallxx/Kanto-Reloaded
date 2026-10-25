# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Reloaded PC's Free Picks (Step 4)
#==============================================================================
# More of the PC scene (UI/PCScene.rb), his Step 4 picks (2026-10-24):
# Free Picks (Y picks any Pokémon in the box, A picks up every picked one,
# they land in the free places from where they're put, LB / RB carry them)
# drawn as Tick Badges (a green tick in each one's corner, its place lit;
# held, a small fan over the cursor and the places they'll land in soft
# gold patches).
#
# The picks are one box's places at a time: picking in another box starts
# afresh, and they wait while you look at other boxes. PIF's multi-select
# code does the rest. Picking up is its pbHoldMulti (its rules: none from
# the Transfer Box), and what it and KIF's multi-select actions (Battle
# Selected, Export, Release) take as the selection is the picks
# (PokemonStorageScreen#getMultiSelection, hooked in Core/PC/ReloadedPC.rb).
# Putting them down is Kanto Reloaded's: the free places from the cursor on,
# then from the box's start, or the party's end when it has room. B puts
# them back where they came from.
#==============================================================================

return unless defined?(Reloaded::PCScene)

module Reloaded
  module PCScene
    # The picked places of a box, for PIF's multi-select code
    def kr_picks_for(box)
      return nil if @kr_fb || !@kr_picks || @kr_picks[0] != box
      list = @kr_picks[1].select { |i| @storage[box, i] }
      return list.empty? ? nil : list.sort
    end

    private

    # The picks in the box shown (any that have gone are dropped)
    def picks_here
      return [] unless @kr_picks && @kr_picks[0] == @storage.currentBox
      @kr_picks[1].select! { |i| box[i] }
      return @kr_picks[1]
    end

    def picks?
      return !picks_here.empty?
    end

    def in_transfer?
      return defined?(::StorageTransferBox) && box.is_a?(::StorageTransferBox) ? true : false
    end

    def can_pick?
      return quick? && !held && multi_held.empty? && !fusing? && !in_transfer? && !@kr_party_only
    end

    # Y: pick or unpick the one under the cursor
    def toggle_pick
      kind, i = @kr_focus
      unless can_pick? && kind == :box && box[i]
        pbPlayBuzzerSE
        return :stay
      end
      @kr_picks = [@storage.currentBox, []] unless @kr_picks && @kr_picks[0] == @storage.currentBox
      list = @kr_picks[1]
      list.include?(i) ? list.delete(i) : list.push(i)
      @kr_picks = nil if list.empty?
      pbPlayDecisionSE
      refresh
      return :stay
    end

    # Select All (the box's actions): every Pokémon in the box picked
    def pick_all
      list = (0...PokemonBox::BOX_SIZE).select { |i| box[i] }
      unless can_pick? && !list.empty?
        pbPlayBuzzerSE
        return
      end
      @kr_picks = [@storage.currentBox, list]
      refresh
    end

    def clear_picks
      @kr_picks = nil
      pbPlayCancelSE
      refresh
      return :stay
    end

    # A with picks: PIF picks them all up (its pbHoldMulti, its rules)
    def pick_up_all
      list = picks_here.sort
      bx = @storage.currentBox
      from = list.map { |i| [@storage[bx, i], bx, i] }
      @screen.pbHoldMulti(bx, @kr_focus[1])
      unless multi_held.empty?
        @kr_multi_from = from
        @kr_picks = nil
      end
      refresh
      return :stay
    end

    # X with picks: PIF's list for several, with its and KIF's actions on
    # the picks (Release, Battle Selected, Export) and Kanto Reloaded's Pick
    # Up All and Sort (UI/PCScene.rb, picks_menu)
    def picks_actions
      unless @screen.respond_to?(:multipleSelectedPokemonCommands)
        pbPlayBuzzerSE
        return :stay
      end
      @screen.multipleSelectedPokemonCommands([@storage.currentBox, @kr_focus[1]], picks_here.length)
      refresh
      return :stay
    end

    # The free places of a box for n Pokémon: from a place on, then from the
    # box's start
    def landing_spots(bx, from, n)
      size = @storage.maxPokemon(bx)
      order = (from...size).to_a + (0...from).to_a
      return order.select { |k| @storage[bx, k].nil? }.first(n)
    end

    # A with picks held: down in the free places from the cursor on, or at
    # the party's end
    def place_all
      list = multi_held
      kind, i = @kr_focus
      if kind == :party
        if @storage.party.length + list.length > ::Settings::MAX_PARTY_SIZE
          pbPlayBuzzerSE
          Reloaded::Dialogs.notice(self, _INTL("PC"), _INTL("There isn't room for them all in your party."))
          refresh
          return :stay
        end
        list.each { |pk, *_r| @storage.party.push(pk) }
      else
        bx = @storage.currentBox
        spots = in_transfer? ? [] : landing_spots(bx, i, list.length)
        if spots.length < list.length
          pbPlayBuzzerSE
          Reloaded::Dialogs.notice(self, _INTL("PC"), _INTL("There isn't room for them all in this box.")) unless in_transfer?
          refresh
          return :stay
        end
        list.each_with_index { |(pk, *_r), k| @storage[bx, spots[k]] = pk }
      end
      done_placing
      return :stay
    end

    # Box Overview: all of them into a box, from its first free place
    def drop_all_in(bx)
      list = multi_held
      spots = landing_spots(bx, 0, list.length)
      return false if spots.length < list.length
      list.each_with_index { |(pk, *_r), k| @storage[bx, spots[k]] = pk }
      done_placing
      return true
    end

    def done_placing
      @screen.multiheldpkmn = []
      @kr_multi_from = nil
      pbSEPlay("GUI storage put down")
      pbHardRefresh
    end

    # B with picks held: each back where it came from (else its box's first
    # free place), and still picked when they all went back
    def put_picks_back
      first_box = nil
      back = []
      multi_held.each do |pk, *_r|
        from = (@kr_multi_from || []).find { |who, _b, _i| who.equal?(pk) }
        bx, idx = from ? from[1, 2] : [@storage.currentBox, nil]
        first_box ||= bx
        if idx && @storage[bx, idx].nil?
          @storage[bx, idx] = pk
          back << idx
        elsif (free = landing_spots(bx, 0, 1).first)
          @storage[bx, free] = pk
        else
          @storage.pbStoreCaught(pk)
        end
      end
      @kr_picks = [first_box, back] if first_box && back.length == multi_held.length
      @screen.multiheldpkmn = []
      @kr_multi_from = nil
      pbPlayCancelSE
      show_box(first_box) if first_box && first_box != @storage.currentBox
      pbHardRefresh
      return :stay
    end

    #--------------------------------------------------------------------------
    # Drawing (his pick: Tick Badges)
    #--------------------------------------------------------------------------
    # Each picked one's place lit green (see-through, on the text layer) and
    # a tick in its corner (over the icons)
    def draw_picks(top, c)
      list = @kr_party_only ? [] : picks_here
      return if list.empty?
      tint = Color.new(c[:green].red, c[:green].green, c[:green].blue, 60)
      list.each do |i|
        sx, sy, = slot_rect(i)
        top.fill_rect(sx + 2, sy + 2, CELL_W - 4, CELL_H - 4, tint)
        tick(marks, sx + CELL_W - 15, sy + 3, c)
      end
    end

    # Held: a small fan over the cursor (the first in front, +n for more)
    # and, over a box, a soft gold patch in each place they'll land (his
    # pick, 2026-10-25: Soft Patches, no outlines; gold, his ask: green
    # didn't show on green wallpapers)
    def draw_multi_held(top, c, cx, cy)
      list = multi_held
      kind, i = @kr_focus
      if kind == :box && !in_transfer?
        spots = landing_spots(@storage.currentBox, i, list.length)
        if spots.length == list.length
          patch = Color.new(c[:gold].red, c[:gold].green, c[:gold].blue, 120)    # strong enough to show on a green wallpaper
          spots.each do |k|
            sx, sy, = slot_rect(k)
            soft_patch(top, sx, sy, patch)
          end
        end
      end
      shadow = Color.new(0, 0, 0, 60)
      top.fill_rect(cx - 10, cy + 13, 20, 2, shadow)
      top.fill_rect(cx - 7, cy + 12, 14, 4, shadow)
      list.first(3).each_with_index.to_a.reverse.each do |(pk, *_r), k|
        s = box_icon(pk, [:held, k])
        place(s, cx + k * 8, cy - k * 5, 40)
        s.opacity = 255
        s.z = 7 - k
      end
      P.pill(marks, cx + 18, cy - 24, "+#{list.length - 3}", c[:gold], c[:dark], false) if list.length > 3
    end

    def tick(b, x, y, c)
      P.ui.rbox(b, x, y, x + 11, y + 11, 5, c[:green], mix(c[:green], PP::WHITE, 0.3))
      [[2, 5], [3, 6], [4, 7], [5, 6], [6, 5], [7, 4], [8, 3]].each { |dx, dy| b.fill_rect(x + dx, y + dy, 1, 2, PP::WHITE) }
    end

    # The layer over the icons (ticks, outlines); popups stay above it
    def marks
      return @kr_marks.bitmap
    end
  end
end
