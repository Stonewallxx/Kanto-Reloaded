# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Double Abilities (Fusing, Capsules, the Summary)
#==============================================================================
#   Fusing     PIF asks for the ability after the fusion is made
#              (PokemonFusion.rb:1076-1085, pbChooseAbility): Kanto
#              Reloaded's Fusion Screen instead of PIF's options
#              (FusionMenu.rb), for both picks, the nature and the nickname
#              (as PIF asks it: a row when both are nicknamed, else the one
#              nickname there is). The head's pick is the game's own ability
#              (his pick, Q5), the body's Kanto Reloaded's; with KIF: Elite
#              Redux's Innates On they're its Ability 1 and 2. The parents'
#              own indexes are kept for unfusing, as PIF keeps them
#   Capsules   the Ability Capsule (regular abilities) and the Secret Capsule
#              (hidden ones too) ask which side first, then that side's list,
#              banned ones locked (his pick, Q18); used up only on a change.
#              On a scene of the game's own: KIF's capsule
#   Summary    PIF's Skills page: Abilities, both rows with their HEAD or
#              BODY badge (his pick, Q19); the Action button opens the
#              Abilities Card, both in full (his pick 2026-10-26)
#==============================================================================

module Reloaded
  module DoubleAbilities
    module Fusing
      CAPSULES = [:ABILITYCAPSULE, :SECRETCAPSULE].freeze
      CARD_W = 480                      # the Abilities Card (one size up
      LINE = 19                         # from the picked design: his ask)
      @handled = false

      class << self
        def install
          h = Reloaded::Hooks
          install_items(h) if defined?(::ItemHandlers)
          install_summary(h) if defined?(::PokemonSummary_Scene)
          return true unless defined?(::PokemonFusionScene)
          h.around(FEATURE, "PokemonFusionScene", :pbChooseAbility, :id => :double_abilities_fusing) do |original, *args|
            scene = original.receiver
            fused = scene.instance_variable_get(:@pokemon1)
            head = scene.instance_variable_get(:@pokemon2)
            if fused && head && Reloaded::DoubleAbilities.applies?(fused) && defined?(Reloaded::FusionAbilityScreen)
              Reloaded::DoubleAbilities::Fusing.choose(scene, fused, head, *args)
            else
              original.call(*args)
            end
          end
          return true
        end

        def install_items(h)
          h.around(FEATURE, ::ItemHandlers.singleton_class, :triggerUseOnPokemon, :id => :double_abilities_capsules) do |original, item, pkmn, scene, *rest|
            fu = Reloaded::DoubleAbilities::Fusing
            if CAPSULES.include?(item) && fu.capsule?(pkmn, scene)
              fu.capsule(item, pkmn, scene)
            else
              original.call(item, pkmn, scene, *rest)
            end
          end
        end

        def install_summary(h)
          h.around(FEATURE, ::PokemonSummary_Scene, :drawPageThree, :id => :double_abilities_summary) do |original, *args|
            ret = original.call(*args)
            Reloaded::DoubleAbilities::Fusing.summary(original.receiver)
            ret
          end
          h.prepend(FEATURE, ::PokemonSummary_Scene, SummaryKeys, :id => :double_abilities_summary_keys)
        end

        # KIF-ER's own picks after a fusion stand down once Kanto Reloaded's
        # screen made them (EliteRedux.rb)
        def take_handled
          was = @handled
          @handled = false
          return was
        end

        def id_of(a)
          return nil if a.nil?
          return a if a.is_a?(Symbol)
          return a.respond_to?(:id) ? a.id : a
        end

        #----------------------------------------------------------------------
        # Fusing
        #----------------------------------------------------------------------
        # scene: PIF's fusion scene. Its own options start by clearing its
        # sprites (PokemonFusion.rb:1165-1169, a method that draws on the
        # scene's @sprites), so the screen opens on a clean background
        def choose(scene, fused, head, body_ability = nil, head_ability = nil)
          scene.send(:clearUIForMoves) if scene.respond_to?(:clearUIForMoves, true)
          r = Reloaded::FusionAbilityScreen.open(fused, head, id_of(body_ability), id_of(head_ability))
          fused.body_original_ability_index = fused.ability_index if fused.respond_to?(:body_original_ability_index=)
          fused.head_original_ability_index = head.ability_index if fused.respond_to?(:head_original_ability_index=)
          if r[:elite_redux]
            ::KIFER.set_choice(fused, r[:head][0])
            ::KIFER.set_choice2(fused, r[:body][0])
            fused.ability_index = 1
            fused.instance_variable_set(:@ability, nil)
            @handled = true
          else
            fused.ability_index = r[:head][0]
            fused.instance_variable_set(:@ability, nil)
            Reloaded::DoubleAbilities.set_second(fused, r[:body][0])
          end
          fused.nature = r[:nature] if r[:nature]
          nick = r[:nickname]
          nick ||= head.name if !fused.nicknamed? && head.respond_to?(:nicknamed?) && head.nicknamed?
          fused.name = nick if nick
          fused.calc_stats
          return true
        end

        #----------------------------------------------------------------------
        # The capsules
        #----------------------------------------------------------------------
        def capsule?(pkmn, scene)
          da = Reloaded::DoubleAbilities
          return false unless pkmn && da.applies?(pkmn) && scene.respond_to?(:overlay) && scene.respond_to?(:palette)
          return !da.pair(pkmn).nil?
        end

        def capsule(item, pkmn, scene)
          da = Reloaded::DoubleAbilities
          er = da.elite_redux?(pkmn)
          pair = da.pair(pkmn)
          side = Reloaded::DoubleAbilitiesPopups.side(scene, pkmn, pair, er)
          return false unless side
          now = pair.find { |s, _id| s == side }[1]
          other = pair.find { |s, _id| s != side }
          other_id = other ? other[1] : nil
          if er
            entries = EliteRedux.entries(pkmn, side).reject { |_i, a, _h| a == now }
            banned = proc { |_id| nil }
          else
            entries = da.choices(pkmn, side, item == :SECRETCAPSULE).reject { |_i, a, _h| a == now }
            banned = proc { |id| Banned.with(id, other_id) }
          end
          if entries.empty?
            scene.pbDisplay(_INTL("It won't have any effect.")) if scene.respond_to?(:pbDisplay)
            return false
          end
          sp = side == :head ? pkmn.get_head_species : pkmn.get_body_species
          pick = Reloaded::DoubleAbilitiesPopups.list(scene, _INTL("{1}'s Ability", sp.name), entries, banned, er)
          return false unless pick
          index, id, = pick
          if er
            EliteRedux.change(pkmn, now, index)
          elsif side == da.main_side(pkmn)
            pkmn.ability_index = index
            pkmn.instance_variable_set(:@ability, nil)
          else
            da.set_second(pkmn, index)
          end
          pkmn.calc_stats
          scene.pbHardRefresh if scene.respond_to?(:pbHardRefresh)
          name = Reloaded::DoubleAbilitiesLook.ability_name(id, er)
          scene.pbDisplay(_INTL("{1}'s Ability changed to {2}!", pkmn.name, name)) if scene.respond_to?(:pbDisplay)
          return true
        end

        #----------------------------------------------------------------------
        # The Summary's Skills page (006_UI_Summary.rb:692-745: the label at
        # 224, 278, the name at 362, the description at 224, 320; bg_3's two
        # white rows at 316-347 and 349-380)
        #----------------------------------------------------------------------
        def summary(scene)
          pk = scene.instance_variable_get(:@pokemon)
          pair = pk ? Reloaded::DoubleAbilities.pair(pk) : nil
          return unless pair
          er = Reloaded::DoubleAbilities.elite_redux?(pk)
          sprites = scene.instance_variable_get(:@sprites)
          overlay = sprites && sprites["overlay"] ? sprites["overlay"].bitmap : nil
          return unless overlay
          # the page's own font back after (Pixel's small text sets the small
          # one: every page drawn after was small, his test 2026-10-26)
          font = overlay.font
          col = font.color
          saved = [font.name, font.size, col ? Color.new(col.red, col.green, col.blue, col.alpha) : nil]
          begin
            summary_rows(scene, overlay, pk, pair, er)
          ensure
            overlay.font.name = saved[0]
            overlay.font.size = saved[1]
            overlay.font.color = saved[2] if saved[2]
          end
        rescue StandardError => e
          Reloaded::Log.warning_once("Double Abilities: the Summary's abilities couldn't be drawn (#{e.class}: #{e.message})", FEATURE)
        end

        def summary_rows(scene, overlay, pk, pair, er)
          base = Color.new(248, 248, 248)
          shadow = Color.new(104, 104, 104)
          ink = scene.instance_variable_get(:@text_color_base) || Color.new(64, 64, 64)
          ink_s = scene.instance_variable_get(:@text_color_shadow) || Color.new(176, 176, 176)
          overlay.fill_rect(218, 274, 294, 110, Color.new(0, 0, 0, 0))
          pbDrawTextPositions(overlay, [[_INTL("Abilities"), 224, 278, 0, base, shadow]])
          # PIF's page doesn't follow Theme Mode: the badges in the Light look,
          # which reads on its pale cells
          c = Reloaded::Palette.light_from(Reloaded::Palette.current, nil)
          look = Reloaded::DoubleAbilitiesLook
          pr = Reloaded::Prompts
          pairs = [[pr.input(:A) || pr.name(:A), _INTL("Descriptions")]]
          w = Reloaded::Pixel.hints_width(overlay, pairs, pr.style)
          Reloaded::Pixel.draw_hints(overlay, 434 - w / 2, 284, c, pairs, pr.style)
          pair.each_with_index do |(side, id), i|
            y = [316, 349][i]
            look.tag(overlay, c, 226, y + 9, look.side_tag(side))
            pbDrawTextPositions(overlay, [[look.ability_name(id, er), 272, y - 8, 0, ink, ink_s]])
          end
        end

        #----------------------------------------------------------------------
        # The Abilities Card (his pick 2026-10-26, Design 2): the Action button
        # on the Skills page shows both abilities in full over the Summary, in
        # Kanto Reloaded's look (Dark or Light), each with its side's icon and
        # badge. B (or A, Action, a click) closes it; the press that closes it
        # is used up here, so the Summary doesn't see it. Its words are a size
        # up from a popup's (his ask 2026-10-27): the title and names in TITLE,
        # the texts and the hint in TEXT, the badges in the small text
        #----------------------------------------------------------------------
        def abilities_card(pk)
          pair = Reloaded::DoubleAbilities.pair(pk)
          return unless pair
          er = Reloaded::DoubleAbilities.elite_redux?(pk)
          look = Reloaded::DoubleAbilitiesLook
          pi = Reloaded::Pixel
          pf = pi.pf
          c = Reloaded::Palette.map_menu
          sw = Graphics.width
          sh = Graphics.height
          vp = Viewport.new(0, 0, sw, sh)
          vp.z = 99_999
          card = Sprite.new(vp)
          card.bitmap = Bitmap.new(sw, sh)
          card.z = 1
          b = card.bitmap
          icons = []
          blocks = pair.map { |side, id| [side, id, pi.wrap(look.ability_text(id, er), CARD_W - 78)] }
          # long texts share the room there is
          room = (sh - 16 - 40 - 32 - blocks.length * 42) / LINE
          if blocks.sum { |blk| blk[2].length } > room
            each = [room / blocks.length, 2].max
            blocks.each { |blk| blk[2] = blk[2].first(each) }
          end
          ph = 40 + blocks.sum { |_s, _i, lines| 42 + lines.length * LINE } + 32
          px = (sw - CARD_W) / 2
          py = [(sh - ph) / 2, 8].max
          title = _INTL("{1}'s Abilities", species_name(pk))
          Reloaded::Dialogs.frame(b, c, px, py, CARD_W, ph, "")
          pi.text(b, px + 8, py + 4, CARD_W - 16, 26, pf.fit(pf::TITLE, title, CARD_W - 28), c[:title], pf::TITLE, 2)
          y = py + 44
          blocks.each_with_index do |(side, id, lines), i|
            sp = side == :head ? pk.get_head_species : pk.get_body_species
            icons << look.species_icon(vp, sp.respond_to?(:id) ? sp.id : sp, px + 32, y + 15, 40, 2)
            pi.text(b, px + 60, y, 320, 28, pf.fit(pf::TITLE, look.ability_name(id, er), 310), c[:head], pf::TITLE)
            card_tag(b, c, px + CARD_W - 16, y + 4, look.side_tag(side))
            lines.each_with_index { |ln, k| pi.text(b, px + 60, y + 31 + k * LINE, CARD_W - 78, LINE, ln, c[:txt]) }
            y += 42 + lines.length * LINE
            b.fill_rect(px + 12, y - 6, CARD_W - 24, 1, c[:line]) if i < blocks.length - 1
          end
          pr = Reloaded::Prompts
          pairs = [[pr.input(:B) || pr.name(:B), _INTL("Close")]]
          w = pi.hints_width(b, pairs, pr.style, pf::TEXT)
          pi.draw_hints(b, sw / 2 - w / 2, py + ph - 28, c, pairs, pr.style, nil, nil, pf::TEXT)
          loop do
            Graphics.update
            Input.update
            pt = Reloaded::Pointer
            next unless Input.trigger?(Input::BACK) || Input.trigger?(Input::USE) || Input.trigger?(Input::ACTION) || pt.left? || pt.right?
            pbPlayCloseMenuSE
            break
          end
          Graphics.update
          Input.update
        rescue StandardError => e
          Reloaded::Log.warning_once("Double Abilities: the Abilities Card couldn't be shown (#{e.class}: #{e.message})", FEATURE)
        ensure
          (icons || []).each { |s, bm| s.dispose if s && !s.disposed?; bm.dispose if bm && !bm.disposed? }
          if card && !card.disposed?
            card.bitmap.dispose
            card.dispose
          end
          vp.dispose if vp && !vp.disposed?
        end

        # A HEAD or BODY badge a size up (DoubleAbilitiesLook.tag's, in the
        # small text), its right edge at x
        def card_tag(b, c, x, y, label)
          pi = Reloaded::Pixel
          pi.small_font(b)
          w = b.text_size(label).width + 14
          pi.ui.rbox(b, x - w, y, x, y + 19, 5, c[:pill])
          pi.small(b, x - w, y, w, 20, label, c[:txt], 2)
        end

        def species_name(pk)
          return pk.speciesName if pk.respond_to?(:speciesName)
          return pk.species_data.name
        end
      end

      # The Action button on the Skills page: the Abilities Card (PIF's own
      # plays the cry; the card uses that press up first)
      module SummaryKeys
        def pbUpdate
          ret = super
          if Input.trigger?(Input::ACTION) && @page == 3 && @pokemon && Reloaded::DoubleAbilities.pair(@pokemon)
            pbPlayDecisionSE
            Reloaded::DoubleAbilities::Fusing.abilities_card(@pokemon)
          end
          return ret
        end
      end
    end
  end
end
