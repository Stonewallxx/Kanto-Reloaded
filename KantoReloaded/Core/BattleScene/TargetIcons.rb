# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Battle Scene's target pictures
#==============================================================================
# EBDX's target window (660_EBDX/007_EBDX_UIWidgets.rb, TargetWindowEBDX#
# refresh) draws every fusion as the DNA placeholder and cuts the top 20 px
# off every icon (Gyarados and Onix lose their heads). After it draws, each
# living target's button is drawn again (his picks, 2026-10-29):
#
#   the picture   the game's own small icon for the Pokémon on the field:
#                 a fusion's real icon (KIF's, head and body), shiny ones,
#                 PIF's Fusion Icons option (DNA stays DNA). Small icons
#                 always, Big Pokémon Icons or not (his pick: battle sprites
#                 came out tiny and grainy on these buttons)
#   the crop      1:1, the Pokémon's middle on the button's middle, EBDX's
#                 4 px bottom margin and its 216 opacity kept
#
# Pictures are kept for the battle, by what decides them. Another mod can
# change which Pokémon's picture shows by prepending icon_for (Ghostly
# Possession: a possessed one shows its fusion).
#==============================================================================

module Reloaded
  module BattleScene
    class TargetIcons
      MARGIN = 4           # EBDX's: the icon stops 4 px above the button's bottom
      OPACITY = 216        # EBDX's

      @cache = {}

      class << self
        def instance
          return @instance ||= new
        end

        def reset
          @cache.each_value { |b| b.dispose unless b.disposed? }
          @cache = {}
        end

        attr_reader :cache

        # After EBDX's refresh(texts): each living target's button again
        def redraw(win, texts)
          battle = win.instance_variable_get(:@battle)
          buttons = win.instance_variable_get(:@buttons)
          return unless battle && buttons
          path = win.instance_variable_get(:@path).to_s + win.instance_variable_get(:@btnImg).to_s
          plain = pbBitmap(path)
          texts.each_with_index do |t, i|
            next if t.nil?
            b = buttons["#{i}"]
            battler = battle.battlers[i]
            next unless b && battler && battler.hp > 0
            pk = battler.respond_to?(:displayPokemon) ? battler.displayPokemon : battler.pokemon
            next unless pk
            icon = instance.picture(pk)
            next unless icon
            bm = b.bitmap
            bm.clear
            bm.blt(0, 0, plain, Rect.new(0, 0, plain.width, plain.height))
            instance.centre(bm, icon)
          end
        ensure
          plain.dispose if plain && !plain.disposed?
        end
      end

      # The Pokémon whose picture shows (Ghostly Possession prepends this)
      def icon_for(pk)
        return pk
      end

      # The small icon's first frame, made once a battle
      def picture(pk)
        pk = icon_for(pk)
        return nil unless pk
        key = key_for(pk)
        cache = self.class.cache
        hit = cache[key]
        return hit if hit && !hit.disposed?
        bm = small_icon(pk)
        cache[key] = bm if bm
        return bm
      rescue StandardError => e
        Reloaded::Log.exception("Battle Scene: a target's picture", e, Reloaded::BattleScene::FEATURE)
        return nil
      end

      def key_for(pk)
        style = (defined?(VAR_FUSION_ICON_STYLE) && $game_variables) ? $game_variables[VAR_FUSION_ICON_STYLE] : 0
        return [pk.species, (pk.form rescue 0), (pk.shiny? rescue false),
                (pk.head_shiny? rescue nil), (pk.body_shiny? rescue nil), style]
      end

      # The game's own icon sprite makes it (fusions, shinies, PIF's Fusion
      # Icons option); with Big Pokémon Icons on, its small icon is the one
      # KIF keeps under the big one (BigIcons.rb's kif_big_pokemon_set)
      def small_icon(pk)
        s = PokemonIconSprite.new(pk, nil)
        s.kif_big_pokemon_set(pk) if s.respond_to?(:kif_big_pokemon_set) && big_icons?
        src = s.bitmap
        return nil unless src
        f = s.src_rect.height > 0 ? s.src_rect.height : src.height
        fw = [src.width, f].min
        bm = Bitmap.new(fw, f)
        bm.blt(0, 0, src, Rect.new(0, 0, fw, f))
        return bm
      ensure
        s.dispose if s && !s.disposed?
      end

      def big_icons?
        return defined?(::KIF::BigIcons) && ::KIF::BigIcons.mode >= 1
      rescue StandardError
        return false
      end

      # The icon 1:1 on the button: centred across, and the Pokémon's
      # middle (where its art is in the frame) on the button's middle
      def centre(bm, icon)
        rows = bm.height - MARGIN
        fw = [icon.width, icon.height].min
        r = Reloaded::PartyIcons.art_rect(icon, fw)
        sy = r.y + r.height / 2 - rows / 2
        sy = [[sy, 0].max, [icon.height - rows, 0].max].min
        bm.blt((bm.width - fw) / 2, 0, icon, Rect.new(0, sy, fw, [rows, icon.height].min), OPACITY)
      end
    end
  end
end
