# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Make a Test Copy (the question and the toast)
#==============================================================================
# His pick (Test Copies Apart): before a test copy is made
# (Saves.make_test_copy), the two saves as plates, from and to; after it,
# a toast:
#
#                       Make a Test Copy?
#   | File A                  ▸   File D [TEST]
#     Red · Cerulean City          A copy to test with
#     [STAYS CLEAN]                [DEBUG WITH KR]
#        Play it with Kanto Reloaded off to test a bug.
#                [ Make Copy ]  [ Cancel ]
#
#   Test Copy Made: File D [TEST]                       (the toast)
#
# The Save Manager (Input::A on a save, a controller's X) and the Bug
# Report's Test Copy section ask it.
#==============================================================================

return unless defined?(Reloaded::Dialogs) && defined?(Reloaded::RunTags)

module Reloaded
  module TestCopyAsk
    P = Reloaded::Pixel
    PF = ::KIF::PixelFont
    W = 380
    H = 204
    PLATE_W = 162
    PLATE_H = 76
    GAP = 26

    class << self
      # Asks, makes it and says so: the new slot, or nil (Cancel, or it
      # couldn't: a notice says why)
      def run(scene, slot)
        title = _INTL("Make a Test Copy")
        dest = Reloaded::Saves.free_slot
        return no(scene, title, _INTL("Every File slot is taken: Delete a save first.")) unless dest
        pv = Reloaded::Saves.preview(Reloaded::Saves.path(slot), :party => false)
        return no(scene, title, _INTL("{1} is damaged, so it can't be copied.", slot)) if pv[:health] == :damaged
        choice = Reloaded::Dialogs.drawn(scene, 2, 0) { |b, c, i| draw(b, c, slot, dest, pv, i) }
        return nil unless choice == 0
        made = Reloaded::Saves.make_test_copy(slot)
        made_toast(made)
        return made
      rescue StandardError => e
        Reloaded::Log.exception("The test copy couldn't be made", e, :saves)
        return no(scene, title, _INTL("That didn't work: {1}", e.message))
      end

      # Test Copy Made: File D, its TEST pill at the end
      def made_toast(slot)
        c = Reloaded::Palette.map_menu
        label = _INTL("TEST")
        w = P.width(PF::TINY, label) + 12
        Reloaded::Toast.show(_INTL("Test Copy Made: {1}", slot),
                             :paint => [w, proc { |b, x, y, cc| pill(b, cc, x, y, label, Reloaded::RunTags.purple(cc)) }])
      end

      private

      def no(scene, title, text)
        Reloaded::Dialogs.notice(scene, title, text)
        return nil
      end

      def draw(b, c, slot, dest, pv, choice)
        x = (Reloaded::Dialogs::SCREEN_W - W) / 2
        y = (Reloaded::Dialogs::SCREEN_H - H) / 2
        Reloaded::Dialogs.frame(b, c, x, y, W, H, _INTL("Make a Test Copy?"))
        px0 = x + (W - PLATE_W * 2 - GAP) / 2
        py = y + 46
        # a soft patch: a touch of the accent on Dark, a touch darker on Light
        fill = c[:light] ? Reloaded::Palette.mix(c[:panel2], c[:bg], 0.45) : Reloaded::Palette.mix(c[:panel2], c[:acc], 0.10)
        bar = Reloaded::Saves.tag_rgb(Reloaded::Saves.tag(slot, pv))
        plate(b, c, px0, py, fill, slot, bar, [pv[:name], pv[:map]].compact.join(" · "), _INTL("STAYS CLEAN"), c[:green], false)
        plate(b, c, px0 + PLATE_W + GAP, py, fill, dest, nil, _INTL("A copy to test with"), _INTL("DEBUG WITH KR"),
              Reloaded::RunTags.purple(c), true)
        P.ui.tri(b, px0 + PLATE_W + GAP / 2 - 3, py + PLATE_H / 2 - 5, :r, c[:dim], 5)
        P.small(b, x, py + PLATE_H + 10, W, 16, _INTL("Play it with Kanto Reloaded off to test a bug."), c[:txt], 2)
        Reloaded::Dialogs.button_row(b, c, x, W, y + H - 36, [_INTL("Make Copy"), _INTL("Cancel")], choice)
      end

      # A save as a plate (no outline): its tag's bar, its name (TEST on
      # the copy), a line, and what happens to it
      def plate(b, c, x, y, fill, name, bar, sub, label, tone, test)
        Reloaded::PartyPaint.chamfer(b, x, y, x + PLATE_W, y + PLATE_H, 8, fill, fill)
        tx = x + 14
        if bar
          P.ui.rbox(b, x + 8, y + 9, x + 11, y + 25, 2, Color.new(*bar))
          tx = x + 18
        end
        room = x + PLATE_W - 6 - tx
        nw = P.text(b, tx, y + 5, room, 24, PF.fit(PF::ROW, name.to_s, room - 48), c[:strong], PF::ROW)
        pill(b, c, tx + nw + 6, y + 9, _INTL("TEST"), Reloaded::RunTags.purple(c)) if test
        P.small(b, tx, y + 31, room, 16, fit_small(b, sub.to_s, room), c[:dim])
        pill(b, c, tx, y + 52, label, tone)
      end

      def pill(b, c, x, y, label, colour)
        return P.pill(b, x, y, label, Reloaded::RunTags.fill(c, colour), colour, false)
      end

      def fit_small(b, text, w)
        P.small_font(b)
        return text if b.text_size(text).width <= w
        text = text[0...-1] while text.length > 1 && b.text_size(text + "...").width > w
        return text + "..."
      end
    end
  end
end
