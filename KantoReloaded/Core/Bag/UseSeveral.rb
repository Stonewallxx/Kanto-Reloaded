# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Use Several at Once (a Reloaded Bag addition)
#==============================================================================
# His picks (2026-10-24): after picking the Pokémon for a Rare Candy, a
# vitamin, a Wing or an EV-lowering Berry, "Use How Many?" (Number With
# Both: the item's picture and the Pokémon's, the number, what it makes,
# and the most that still helps), then what it did (A Notice). A Rare
# Candy's result is the game's own level-up window, once, to the new level
# (the moves it learns and the evolution after, as the game does).
# HP items too (his pick, 2026-10-24): Potions, drinks, Energy Powder and
# Root, Berry Juice, Oran and Sitrus Berries, up to what fills the HP.
#
# The game's own item use stays: the hook is on ItemHandlers'
# triggerUseOnPokemon, which both the Bag's Use and the party menu's Item >
# Use call; the game takes one item away after it, Kanto Reloaded the rest.
# Only on Kanto Reloaded's Party Screen (the popups draw on it), and only
# when more than one would help.
#==============================================================================

return unless defined?(Reloaded::Bag) && defined?(Reloaded::Dialogs)

module Reloaded
  module UseSeveral
    VITAMINS = { :HPUP => :HP, :PROTEIN => :ATTACK, :IRON => :DEFENSE, :CALCIUM => :SPECIAL_ATTACK,
                 :ZINC => :SPECIAL_DEFENSE, :CARBOS => :SPEED }.freeze
    WINGS = { :HEALTHWING => :HP, :MUSCLEWING => :ATTACK, :RESISTWING => :DEFENSE, :GENIUSWING => :SPECIAL_ATTACK,
              :CLEVERWING => :SPECIAL_DEFENSE, :SWIFTWING => :SPEED }.freeze
    BERRIES = { :POMEGBERRY => :HP, :KELPSYBERRY => :ATTACK, :QUALOTBERRY => :DEFENSE, :HONDEWBERRY => :SPECIAL_ATTACK,
                :GREPABERRY => :SPECIAL_DEFENSE, :TAMATOBERRY => :SPEED }.freeze
    # The HP each restores (013_Items/002_Item_Effects.rb; his pick,
    # 2026-10-24: HP Items): :full is what's missing, :quarter a quarter
    HP_ITEMS = { :POTION => 20, :SUPERPOTION => 50, :HYPERPOTION => 200, :MAXPOTION => :full, :FRESHWATER => 50,
                 :SODAPOP => 60, :LEMONADE => 80, :MOOMOOMILK => 100, :ENERGYPOWDER => 50, :ENERGYROOT => 200,
                 :BERRYJUICE => 20, :SWEETHEART => 20, :ORANBERRY => 10, :SITRUSBERRY => :quarter }.freeze
    CANDY = :RARECANDY
    P = Reloaded::Pixel
    PF = ::KIF::PixelFont

    class << self
      def boot
        install
        return true
      end

      # :candy, :vitamin, :wing, :berry, :hp or nil
      def kind(item)
        id = item.to_s.to_sym
        return :candy if id == CANDY
        return :vitamin if VITAMINS[id]
        return :wing if WINGS[id]
        return :berry if BERRIES[id]
        return :hp if HP_ITEMS[id]
        return nil
      end

      # The HP one restores on this Pokémon
      def hp_amount(item, pkmn)
        v = HP_ITEMS[item.to_s.to_sym]
        return pkmn.totalhp.to_i - pkmn.hp.to_i if v == :full
        return pkmn.totalhp.to_i / 4 if v == :quarter
        return v.to_i
      end

      # How many it takes to fill HP: 0 when fainted, full, or the challenge
      # option says no healing items (the game's own message then)
      def hp_room(item, pkmn)
        return 0 if $PokemonSystem && ($PokemonSystem.no_healing_items_ow rescue false)
        missing = pkmn.totalhp.to_i - pkmn.hp.to_i
        return 0 if pkmn.hp.to_i <= 0 || missing <= 0
        amount = hp_amount(item, pkmn)
        return 1 if amount <= 0
        return (missing / amount.to_f).ceil
      end

      def stat(item)
        id = item.to_s.to_sym
        return VITAMINS[id] || WINGS[id] || BERRIES[id]
      end

      # How many still help this Pokémon (before what's in the Bag)
      def most(item, pkmn)
        case kind(item)
        when :candy then return candy_room(pkmn)
        when :vitamin, :wing
          s = stat(item)
          ev = pkmn.ev[s].to_i
          total = ev_total(pkmn)
          room = [ev_stat_limit - ev, ev_limit - total].min
          return kind(item) == :wing ? [room, 0].max : ([[100 - ev, room].min, 0].max / 10.0).ceil
        when :berry
          ev_uses = (pkmn.ev[stat(item)].to_i / 10.0).ceil
          return [ev_uses, friendship_uses(pkmn)].max
        when :hp then return hp_room(item, pkmn)
        end
        return 0
      end

      def candy_room(pkmn)
        top = (::GameData::GrowthRate.max_level rescue 100)
        cap = defined?(::KIF::LevelCap) ? (::KIF::LevelCap.cap_for(pkmn) rescue nil) : nil
        if cap
          top = [top, cap].min
        elsif $PokemonSystem && ($PokemonSystem.level_caps rescue 0) == 1 && defined?(getCurrentLevelCap) &&
              $Trainer && $Trainer.badge_count < (::Settings::NB_BADGES rescue 8)
          top = [top, getCurrentLevelCap.to_i].min
        end
        return 0 if (pkmn.shadowPokemon? rescue false)
        return [top - pkmn.level, 0].max
      end

      # An EV-lowering Berry's friendship: +10, +5 or +2 a Berry until 255
      def friendship_uses(pkmn)
        h = pkmn.happiness.to_i
        n = 0
        while h < 255 && n < 999
          h += h < 100 ? 10 : (h < 200 ? 5 : 2)
          n += 1
        end
        return n
      end

      def ev_total(pkmn)
        return [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED].sum { |s| pkmn.ev[s].to_i }
      end

      def ev_limit
        return defined?(::Pokemon::EV_LIMIT) ? ::Pokemon::EV_LIMIT : 510
      end

      def ev_stat_limit
        return defined?(::Pokemon::EV_STAT_LIMIT) ? ::Pokemon::EV_STAT_LIMIT : 252
      end

      def stat_name(s)
        return ::GameData::Stat.get(s).name
      rescue StandardError
        return s.to_s.capitalize
      end

      #------------------------------------------------------------------------
      # Using them
      #------------------------------------------------------------------------
      def use(original, item, pkmn, screen)
        scene = screen.respond_to?(:instance_variable_get) ? screen.instance_variable_get(:@scene) : nil
        k = kind(item)
        return original.call(item, pkmn, screen) unless k && pkmn && !pkmn.egg? && scene.respond_to?(:with_popup_hints)
        have = ($PokemonBag.pbQuantity(item) rescue 0).to_i
        max = [most(item, pkmn), have].min
        return original.call(item, pkmn, screen) if max < 2
        n = ask(scene, item, pkmn, max)
        return false unless n
        return original.call(item, pkmn, screen) if n == 1
        return candies(item, pkmn, screen, n) if k == :candy
        return several(original, item, pkmn, screen, scene, n)
      end

      # Rare Candies: one level-up, to the new level (the game's window)
      def candies(item, pkmn, screen, n)
        pbSet(VAR_STAT_RARE_CANDY, pbGet(VAR_STAT_RARE_CANDY) + n) if defined?(VAR_STAT_RARE_CANDY)
        pbChangeLevel(pkmn, pkmn.level + n, screen)
        screen.pbHardRefresh if screen.respond_to?(:pbHardRefresh)
        $PokemonBag.pbDeleteItem(item, n - 1)
        return true
      end

      # Vitamins, Wings, Berries, HP items: the game's own use, n times,
      # quietly; then what it did
      def several(original, item, pkmn, screen, scene, n)
        s = stat(item)
        value = kind(item) == :hp ? -> { pkmn.hp.to_i } : -> { pkmn.ev[s].to_i }
        before = value.call
        happy_before = pkmn.happiness.to_i
        quiet = Quiet.new(screen)
        used = 0
        n.times do
          break unless original.call(item, pkmn, quiet)
          used += 1
        end
        if used == 0
          screen.pbDisplay(quiet.said.first.to_s) unless quiet.said.empty?
          return false
        end
        $PokemonBag.pbDeleteItem(item, used - 1) if used > 1
        screen.pbHardRefresh if screen.respond_to?(:pbHardRefresh)
        result(scene, item, pkmn, used, s, before, value.call, pkmn.happiness.to_i <=> happy_before)
        return true
      end

      # The game's item use with its words kept (shown once, after)
      class Quiet
        attr_reader :said

        def initialize(screen)
          @screen = screen
          @said = []
        end

        def pbDisplay(text)
          @said << text
        end

        def pbRefresh(*_a); end

        def pbHardRefresh(*_a); end

        def method_missing(name, *args, &blk)
          return @screen.send(name, *args, &blk) if @screen.respond_to?(name, true)
          super
        end

        def respond_to_missing?(name, priv = false)
          return @screen.respond_to?(name, priv) || super
        end
      end

      #------------------------------------------------------------------------
      # The popups (his picks: Number With Both, A Notice)
      #------------------------------------------------------------------------
      # Use How Many? Left/Right one, Up/Down ten, A uses, B cancels. nil on
      # Cancel.
      def ask(scene, item, pkmn, max)
        n = 1
        hints = [[:lr, _INTL("One")], [:ud, _INTL("Ten")], [button(:C), _INTL("Use")], [button(:B), _INTL("Cancel")]]
        mon = Reloaded::PartyIcons.species_bitmap(pkmn.species) rescue nil
        scene.with_popup_hints(hints) do
          redraw = true
          loop do
            draw_ask(scene.overlay, scene.palette, item, pkmn, n, max, mon) if redraw
            redraw = false
            Graphics.update
            Input.update
            scene.update_frame if scene.respond_to?(:update_frame)
            delta = 0
            delta = -1 if Input.repeat?(Input::LEFT)
            delta = 1 if Input.repeat?(Input::RIGHT)
            delta = -10 if Input.repeat?(Input::DOWN)
            delta = 10 if Input.repeat?(Input::UP)
            delta = -Reloaded::Pointer.wheel if delta == 0
            if Reloaded::Pointer.right? || Input.trigger?(Input::BACK)
              pbPlayCancelSE
              return nil
            elsif Reloaded::Pointer.left? || Input.trigger?(Input::USE)
              pbPlayDecisionSE
              return n
            elsif delta != 0
              to = (n + delta).clamp(1, max)
              next if to == n
              n = to
              pbPlayCursorSE
              redraw = true
            end
          end
        end
      ensure
        mon.dispose if mon && !mon.disposed?
        scene.overlay.clear if scene.respond_to?(:overlay) && scene.overlay && !scene.overlay.disposed?
        scene.refresh if scene.respond_to?(:refresh)
      end

      # What it did: a notice with before and after (happy: friendship up 1,
      # down -1, the same 0)
      def result(scene, item, pkmn, used, s, before, after, happy)
        it = ::GameData::Item.get(item)
        words = used > 1 && it.respond_to?(:name_plural) ? it.name_plural : it.name
        hp = kind(item) == :hp
        title = if hp then _INTL("{1}'s HP Was Restored", pkmn.name)
                elsif after > before then _INTL("{1}'s {2} Rose", pkmn.name, stat_name(s))
                elsif after < before then _INTL("{1}'s {2} Fell", pkmn.name, stat_name(s))
                else _INTL("{1} Is Friendlier", pkmn.name)
                end
        text = _INTL("Used {1} {2}.", used, words)
        text += " " + _INTL("{1} is a little friendlier too.", pkmn.name) if happy > 0 && after != before
        text += " " + _INTL("{1} is a little less friendly too.", pkmn.name) if happy < 0
        label = hp ? _INTL("HP: ") : _INTL("{1} EVs: ", stat_name(s))
        scene.with_popup_hints([[button(:C), _INTL("OK")]]) do
          draw_result(scene.overlay, scene.palette, title, text, [label, before.to_s, after.to_s])
          loop do
            Graphics.update
            Input.update
            scene.update_frame if scene.respond_to?(:update_frame)
            if Input.trigger?(Input::USE) || Input.trigger?(Input::BACK) || Reloaded::Pointer.left? || Reloaded::Pointer.right?
              pbPlayDecisionSE
              break
            end
          end
        end
      ensure
        scene.overlay.clear if scene.respond_to?(:overlay) && scene.overlay && !scene.overlay.disposed?
        scene.refresh if scene.respond_to?(:refresh)
      end

      def button(sym)
        return Reloaded::Prompts.input(sym) || Reloaded::Prompts.name(sym)
      end

      def mix(a, b, t)
        return Reloaded::Palette.mix(a, b, t)
      end

      def picture_box(b, c, x0, y0, x1, y1)
        P.ui.rbox(b, x0, y0, x1, y1, 6, c[:light] ? mix(c[:panel2], Reloaded::PartyPaint::WHITE, 0.5) : mix(c[:dark], c[:panel], 0.3), c[:line])
      end

      # "Attack EVs: 40 > 90", centred on cx (the arrow a small triangle: the
      # font has none)
      def change(b, c, cx, y, parts)
        label, before, after = parts
        lw = label.empty? ? 0 : P.width(PF::TEXT, label)
        bw = P.width(PF::TEXT, before)
        aw = P.width(PF::TEXT, after)
        x = cx - (lw + bw + 18 + aw) / 2
        P.text(b, x, y, lw + 2, 20, label, c[:dim], PF::TEXT) if lw > 0
        P.text(b, x + lw, y, bw + 2, 20, before, c[:txt], PF::TEXT)
        P.ui.tri(b, x + lw + bw + 6, y + 6, :r, c[:dim], 4)
        P.text(b, x + lw + bw + 18, y, aw + 2, 20, after, c[:green], PF::TEXT)
      end

      def makes(item, pkmn, n)
        return ["", _INTL("Lv. {1}", pkmn.level), _INTL("Lv. {1}", pkmn.level + n)] if kind(item) == :candy
        if kind(item) == :hp
          return [_INTL("HP: "), pkmn.hp.to_s, [pkmn.hp.to_i + hp_amount(item, pkmn) * n, pkmn.totalhp.to_i].min.to_s]
        end
        s = stat(item)
        ev = pkmn.ev[s].to_i
        after = case kind(item)
                when :vitamin then [ev + 10 * n, 100, ev_stat_limit].min
                when :wing then [ev + n, ev_stat_limit].min
                else [ev - 10 * n, 0].max
                end
        return [_INTL("{1} EVs: ", stat_name(s)), ev.to_s, after.to_s]
      end

      def draw_ask(b, c, item, pkmn, n, max, mon)
        it = ::GameData::Item.get(item)
        w = 330
        h = 168
        x = (512 - w) / 2
        y = (384 - h) / 2 - 10
        b.clear
        Reloaded::Dialogs.frame(b, c, x, y, w, h, _INTL("Use How Many?"))
        picture_box(b, c, x + 14, y + 46, x + 64, y + 96)
        file = (::GameData::Item.icon_filename(item) rescue "Graphics/Items/#{item}")
        bm = (Bitmap.new(pbResolveBitmap(file) || file) rescue nil)
        if bm
          b.stretch_blt(Rect.new(x + 17, y + 49, 44, 44), bm, Rect.new(0, 0, bm.width, bm.height))
          bm.dispose
        end
        picture_box(b, c, x + w - 64, y + 46, x + w - 14, y + 96)
        if mon
          f = [mon.height, 1].max
          r = Reloaded::PartyIcons.art_rect(mon, f) rescue Rect.new(0, 0, f, f)
          side = [r.width, r.height].max
          b.stretch_blt(Rect.new(x + w - 63, y + 47, 48, 48), mon, Rect.new(r.x + (r.width - side) / 2, r.y + (r.height - side) / 2, side, side))
        end
        P.small(b, x, y + 42, w, 16, _INTL("{1} on {2}", it.name, pkmn.name), c[:dim], 2)
        label = n.to_s
        tw = P.width(PF::ROW, label)
        cx = x + w / 2
        P.text(b, cx - 40, y + 58, 80, 30, label, c[:txt], PF::ROW, 2)
        P.ui.tri(b, cx - tw / 2 - 16, y + 68, :l, n > 1 ? c[:selb] : c[:line], 5)
        P.ui.tri(b, cx + tw / 2 + 6, y + 68, :r, n < max ? c[:selb] : c[:line], 5)
        change(b, c, cx, y + 102, makes(item, pkmn, n))
        P.small(b, x, y + h - 28, w, 16, _INTL("1 to {1}: The Most That Helps", max), c[:dim], 2)
      end

      def draw_result(b, c, title, text, parts)
        w = 380
        lines = P.wrap(text, w - 32).first(3)
        h = 40 + lines.length * 18 + 26 + 48
        x = (512 - w) / 2
        y = (384 - h) / 2
        b.clear
        Reloaded::Dialogs.frame(b, c, x, y, w, h, title)
        lines.each_with_index { |ln, i| P.text(b, x + 16, y + 40 + i * 18, w - 32, 18, ln, c[:txt], nil, 2) }
        change(b, c, x + w / 2, y + 44 + lines.length * 18, parts)
        bw = 72
        bx = x + (w - bw) / 2
        by = y + h - 36
        Reloaded::Dialogs.send(:button, b, c, bx, by, bx + bw, by + 24, true)
        P.text(b, bx, by, bw, 24, _INTL("OK"), c[:strong], nil, 2)
      end

      private

      def install
        return if @installed || !defined?(::ItemHandlers) || !::ItemHandlers.respond_to?(:triggerUseOnPokemon)
        @installed = true
        Reloaded::Hooks.around(Reloaded::Bag::FEATURE, ::ItemHandlers.singleton_class, :triggerUseOnPokemon,
                               :id => :bag_use_several) do |original, item, pkmn, screen, *rest|
          next original.call(item, pkmn, screen, *rest) unless rest.empty?
          Reloaded::UseSeveral.use(original, item, pkmn, screen)
        end
      end
    end
  end
end
