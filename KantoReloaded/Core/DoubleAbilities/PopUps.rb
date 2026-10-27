# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Double Abilities (Pop-Ups)
#==============================================================================
# Kanto Reloaded's own ability pop-up, the Split Pill (his pick 2026-10-26,
# Design 6 of nine), in place of EBDX's (a dark box with a thin white
# border) and PIF's ability bar, for every ability pop-up: one ability or
# two, yours and foes', KIF: Elite Redux's innates too (they come through the
# same call).
#
#   The pill     a capsule 28 tall: on the edge it comes from, a segment of
#                the side's colour (yours blue, foes red) holding the icon of
#                the side the ability is from (the head's or the body's; a
#                Pokémon that isn't a fusion its own) and the Pokémon's name,
#                cut on a slant into the panel holding the ability. A second
#                pill for the same Pokémon shows only its icon there; the two
#                are as wide as the wider
#   Places       EBDX's: yours 10 from the left edge centred on y 200, a foe's
#                10 from the right edge on y 80; in PIF's scene its bar's (y
#                180 and 80, 32 tall). Each slides in from its edge as EBDX's
#                does (10 frames, easing out, fading in) and out the same way
#   Together     when both abilities work in the same moment (the handlers'
#                dispatch, Battle.rb), the first waits for the second: they
#                show together and leave together (his pick, Q16). Otherwise
#                the second shows alone in the usual place
#   PIF's scene  as PIF's bar does, the battle waits while a pill slides
#   Theme        Dark or Light, as Kanto Reloaded's menus
#==============================================================================

module Reloaded
  module DoubleAbilities
    module PopUps
      SLIDE = 10                 # EBDX's frames each way (010_EBDX_Scene.rb:2473-2475)
      LINGER = 240               # a pill nobody hides leaves on its own
      H = 28
      RADIUS = 13
      SLANT = 8
      GAP = 4
      EDGE = 10
      ICON = 32
      ALLY_RGB = [40, 130, 255].freeze
      FOE_RGB = [240, 60, 60].freeze
      # [yours, a foe's] centre lines: EBDX's sprite (oy half its art), PIF's bar
      PLACES = { :ebdx => [200, 80], :pif => [196, 96] }.freeze

      class << self
        def install
          h = Reloaded::Hooks
          h.prepend(FEATURE, ::PokeBattle_Scene, PifScene, :id => :double_abilities_pif_popups) if defined?(::PokeBattle_Scene)
          h.prepend(FEATURE, ::PokeBattle_SceneEBDX, EbdxScene, :id => :double_abilities_ebdx_popups) if defined?(::PokeBattle_SceneEBDX)
          return true
        end

        # The scene's pills (made the first time they're needed)
        def manager(scene, make = true)
          m = scene.instance_variable_get(:@kr_pills)
          return m if m || !make
          kind = defined?(::PokeBattle_SceneEBDX) && scene.is_a?(::PokeBattle_SceneEBDX) ? :ebdx : :pif
          return nil unless scene.is_a?(::PokeBattle_Scene)
          return scene.instance_variable_set(:@kr_pills, Manager.new(scene, kind))
        rescue StandardError => e
          Reloaded::Log.warning_once("Double Abilities: the pop-ups couldn't start (#{e.class}: #{e.message})", FEATURE)
          return nil
        end

        # Both of a battler's abilities in one moment: a pill the first shows
        # waits for the second's (Battle.rb's dispatch)
        def holding(battler)
          battle = battler.respond_to?(:battle) ? battler.battle : nil
          scene = battle && battle.respond_to?(:scene) ? battle.scene : nil
          m = scene && Reloaded::DoubleAbilities.on? ? manager(scene) : nil
          return yield unless m
          return m.hold(battler) { yield }
        end

        # The colour of a side's segment, at the theme's lightness
        def side_fill(c, foe)
          hue = Reloaded::PartyPaint.hsl(*(foe ? FOE_RGB : ALLY_RGB))[0]
          return Reloaded::PartyPaint.hsl_color(hue, 0.85, c[:light] ? 0.50 : 0.44)
        end

        # What the pill's icon is: the side the shown ability is from, a
        # Pokémon that isn't a fusion its own, an Illusion's disguise its own
        def icon_for(battler)
          ill = battler.effects[PBEffects::Illusion] rescue nil
          return [:pokemon, ill] if ill
          pk = battler.pokemon
          return nil unless pk
          da = Reloaded::DoubleAbilities
          return [:pokemon, pk] unless da.applies?(pk)
          second = battler.respond_to?(:kr_second_showing?) && battler.kr_second_showing?
          id = second ? battler.instance_variable_get(:@kr_ability2_id) : battler.ability_id
          side = [:head, :body].find { |s| da.choices(pk, s).any? { |_i, a, _h| a == id } }
          sp = side == :head ? pk.get_head_species : (side == :body ? pk.get_body_species : nil)
          return sp ? [:species, (sp.respond_to?(:id) ? sp.id : sp)] : [:pokemon, pk]
        rescue StandardError
          return battler.pokemon ? [:pokemon, battler.pokemon] : nil
        end
      end

      #------------------------------------------------------------------------
      # One pill
      #------------------------------------------------------------------------
      class Pill
        attr_reader :battler_index, :label, :width
        attr_accessor :slot

        def initialize(mgr, battler, label, first, slot)
          @mgr = mgr
          @battler_index = battler.index
          @foe = battler.index.odd?
          @name = battler.name.to_s.upcase
          @label = label.to_s
          @first = first
          @slot = slot
          @icon_of = PopUps.icon_for(battler)
          @state = :in
          @frame = 0
          @width = natural_width
          @sprite = Sprite.new(mgr.viewport)
          @sprite.z = mgr.z
          @sprite.opacity = 0
          make_icon
          draw
          place
        end

        def segment
          return @first ? 40 + ::KIF::PixelFont.width(::KIF::PixelFont::TINY, @name) + 6 : 40
        rescue StandardError
          return 40
        end

        def natural_width
          return segment + SLANT + 10 + Reloaded::Pixel.width(::KIF::PixelFont::ROW, @label) + 14
        end

        def width=(w)
          return if w == @width
          @width = w
          draw
          place
        end

        def draw
          c = Reloaded::Palette.map_menu
          b = @sprite.bitmap
          b.dispose if b && !b.disposed?
          w = @width
          b = Bitmap.new(w, H)
          @sprite.bitmap = b
          P.ui.rbox(b, 0, 0, w, H, RADIUS, c[:panel])
          fill = PopUps.side_fill(c, @foe)
          seg = segment
          (0...H).each do |y|
            d = (y + 0.5 - H / 2.0).abs - (H / 2.0 - RADIUS)
            l = d > 0 ? (RADIUS - Math.sqrt([RADIUS * RADIUS - d * d, 0].max)).round : 0
            split = seg + ((H - 1 - y) * SLANT / (H - 1).to_f).round
            @foe ? b.fill_rect(w - split, y, split - l, 1, fill) : b.fill_rect(l, y, split - l, 1, fill)
          end
          if @first
            tw = ::KIF::PixelFont.width(::KIF::PixelFont::TINY, @name)
            nx = @foe ? w - 38 - tw : 38
            P.text(b, nx, 7, tw + 2, 16, @name, Color.new(255, 255, 255), ::KIF::PixelFont::TINY)
          end
          ax = @foe ? 12 : seg + SLANT + 10
          P.text(b, ax, 1, w - seg - SLANT - 24, 26, @label, c[:txt], ::KIF::PixelFont::ROW, @foe ? 1 : 0)
        end

        def make_icon
          kind, what = @icon_of
          return unless kind
          if kind == :species
            bm = Reloaded::PartyIcons.species_bitmap(what)
            return unless bm
            @icon_bitmap = bm
            @icon = Sprite.new(@mgr.viewport)
            @icon.bitmap = bm
            @icon.src_rect = Rect.new(0, 0, bm.height, bm.height)
          else
            @icon = Reloaded::PartyIcons.icon(what, @mgr.viewport, @mgr.z + 1)
          end
          return unless @icon
          @icon.z = @mgr.z + 1
          @icon.opacity = 0
        rescue StandardError => e
          Reloaded::Log.warning_once("Double Abilities: a pop-up's icon couldn't be made (#{e.class}: #{e.message})", FEATURE)
          @icon = nil
        end

        def rest_x
          return @foe ? Graphics.width - EDGE - @width : EDGE
        end

        def start_x
          return @foe ? Graphics.width : -@width
        end

        def rest_y
          return @mgr.centre(@foe) - H / 2 + @slot * (H + GAP)
        end

        # Where it is now, as far as it has slid
        def place
          t = [@frame.to_f / SLIDE, 1.0].min
          x = rest_x
          op = 255
          case @state
          when :in
            e = 1.0 - (1.0 - t)**2
            x = (start_x + (rest_x - start_x) * e).round
            op = (255 * t).round
          when :out
            e = t * t
            x = (rest_x + (start_x - rest_x) * e).round
            op = (255 * (1.0 - t)).round
          end
          @sprite.x = x
          @sprite.y = rest_y
          @sprite.opacity = op
          return unless @icon
          cx = x + (@foe ? @width - 20 : 20)
          Reloaded::PartyIcons.place(@icon, cx, rest_y + 13)
          @icon.zoom_x = @icon.zoom_y = @icon.zoom_x * ICON / Reloaded::PartyIcons::FRAME.to_f
          @icon.opacity = op
        end

        def leave
          return if @state == :out || @state == :gone
          @frame = @state == :in ? SLIDE - @frame : 0          # a pill still coming in turns back from where it is
          @state = :out
        end

        def leaving?
          return @state == :out || @state == :gone
        end

        def moving?
          return @state == :in || @state == :out
        end

        def gone?
          return @state == :gone
        end

        def update
          @frame += 1
          case @state
          when :in
            if @frame >= SLIDE
              @state = :shown
              @frame = 0
            end
          when :shown
            leave if @frame >= LINGER
          when :out
            if @frame >= SLIDE
              @state = :gone
              dispose
              return
            end
          end
          place
        end

        def dispose
          @state = :gone
          if @sprite && !@sprite.disposed?
            @sprite.bitmap.dispose if @sprite.bitmap && !@sprite.bitmap.disposed?
            @sprite.dispose
          end
          @icon.dispose if @icon && !@icon.disposed?
          @icon_bitmap.dispose if @icon_bitmap && !@icon_bitmap.disposed?
        end

        P = Reloaded::Pixel
      end

      #------------------------------------------------------------------------
      # A scene's pills
      #------------------------------------------------------------------------
      class Manager
        attr_reader :kind

        def initialize(scene, kind)
          @scene = scene
          @kind = kind
          @pills = []
          @hold = Hash.new(0)
          @pending = {}
        end

        # The game's own pop-up's viewport and height
        def viewport
          sprites = @scene.instance_variable_get(:@sprites) || {}
          s = @kind == :ebdx ? sprites["abilityMessage"] : sprites["abilityBar_0"]
          return s.viewport if s && s.respond_to?(:viewport) && s.viewport
          return @scene.instance_variable_get(:@viewport)
        end

        def z
          return @kind == :ebdx ? 99_999 : 130
        end

        def centre(foe)
          return PLACES[@kind][foe ? 1 : 0]
        end

        def mine(battler)
          return @pills.select { |p| p.battler_index == battler.index && !p.leaving? }
        end

        def show(battler, label)
          label = battler.abilityName if label.nil? || label.to_s.empty?
          side = battler.index % 2
          # another Pokémon's pill on this side leaves
          @pills.each { |p| p.leave if p.battler_index % 2 == side && p.battler_index != battler.index }
          now = mine(battler)
          if now.any? { |p| p.label == label.to_s }
            return                                   # the same one again (pbReplaceAbilitySplash)
          elsif now.length == 1 && held?(battler)
            pill = Pill.new(self, battler, label, false, 1)
            @pills << pill
            w = [now[0].natural_width, pill.natural_width].max
            now[0].width = w
            pill.width = w
          else
            now.each(&:leave)
            @pills << Pill.new(self, battler, label, true, 0)
          end
        end

        def hide(battler)
          if battler.nil?
            @pills.each(&:leave)
            return
          end
          if held?(battler)
            @pending[battler.index] = true
            return
          end
          mine(battler).each(&:leave)
        end

        def held?(battler)
          return @hold[battler.index] > 0
        end

        def hold(battler)
          @hold[battler.index] += 1
          return yield
        ensure
          @hold[battler.index] -= 1
          if @hold[battler.index] <= 0
            @hold.delete(battler.index)
            if @pending.delete(battler.index)
              hide(battler)
              wait if @kind == :pif
            end
          end
        end

        def update
          return if @pills.empty?
          @pills.each(&:update)
          @pills.reject!(&:gone?)
        end

        def moving?
          return @pills.any?(&:moving?)
        end

        # PIF's scene waits while a pill slides, as its bar's animation does
        def wait
          n = 0
          while moving? && n < SLIDE * 3
            @scene.pbUpdate
            n += 1
          end
        end

        def dispose
          @pills.each(&:dispose)
          @pills.clear
        end
      end

      #------------------------------------------------------------------------
      # The scenes
      #------------------------------------------------------------------------
      module PifScene
        def pbShowAbilitySplash(battler, secondAbility = false, abilityName = nil)
          return super unless Reloaded::DoubleAbilities.on? && PokeBattle_SceneConstants::USE_ABILITY_SPLASH
          m = Reloaded::DoubleAbilities::PopUps.manager(self)
          return super unless m
          m.show(battler, abilityName.is_a?(String) ? abilityName : nil)
          m.wait
        end

        def pbHideAbilitySplash(battler)
          m = Reloaded::DoubleAbilities::PopUps.manager(self, false)
          return super unless m && Reloaded::DoubleAbilities.on?
          m.hide(battler)
          m.wait
        end

        def pbReplaceAbilitySplash(battler)
          return super unless Reloaded::DoubleAbilities.on? && PokeBattle_SceneConstants::USE_ABILITY_SPLASH
          return pbShowAbilitySplash(battler)
        end

        def pbFrameUpdate(cw = nil)
          ret = super
          m = @kr_pills
          m.update if m
          return ret
        end

        def pbDisposeSprites
          @kr_pills.dispose if @kr_pills
          @kr_pills = nil
          return super
        end
      end

      module EbdxScene
        def pbShowAbilitySplash(battler, delay = false, logTrigger = true, abilityName = nil)
          return super unless Reloaded::DoubleAbilities.on?
          return if !battler || !battler.abilityActive?
          m = Reloaded::DoubleAbilities::PopUps.manager(self)
          return super unless m
          # the battle passes PIF's order (battler, false, name): EBDX takes
          # the name in logTrigger's place (B1)
          name = [abilityName, logTrigger, delay].find { |a| a.is_a?(String) }
          m.show(battler, name)
          pbSEPlay("EBDX/Ability Message") rescue nil
        end

        def pbHideAbilitySplash(battler = nil)
          m = Reloaded::DoubleAbilities::PopUps.manager(self, false)
          return super unless m && Reloaded::DoubleAbilities.on?
          m.hide(battler)
        end

        def pbReplaceAbilitySplash(battler)
          return super unless Reloaded::DoubleAbilities.on?
          return pbShowAbilitySplash(battler)
        end

        # Called every frame (010_EBDX_Scene.rb:818)
        def updateAbilityMessage
          ret = super
          m = @kr_pills
          m.update if m
          return ret
        end

        def pbDisposeSprites
          @kr_pills.dispose if @kr_pills
          @kr_pills = nil
          return super
        end
      end
    end
  end
end
