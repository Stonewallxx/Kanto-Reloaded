#==============================================================================
# Kanto Reloaded - Reloaded PC
#==============================================================================
# KR-owned Pokemon Storage scene for Organise, Withdraw, and Deposit.
#==============================================================================

module KantoReloaded
  module ReloadedPC
    ORGANISE_COMMAND = 0
    WITHDRAW_COMMAND = 1
    DEPOSIT_COMMAND = 2
    SUPPORTED_COMMANDS = [
      ORGANISE_COMMAND, WITHDRAW_COMMAND, DEPOSIT_COMMAND
    ].freeze

    class << self
      def supports?(command)
        SUPPORTED_COMMANDS.include?(command.to_i) && graphics_available?
      rescue StandardError
        false
      end

      def open(storage_screen, command = ORGANISE_COMMAND)
        return false unless supports?(command)
        Scene.new(storage_screen, command).main
      rescue StandardError => e
        KantoReloaded::Log.exception(
          "Reloaded PC scene failed", e, :channel => :pc_organization
        ) if defined?(KantoReloaded::Log)
        raise
      end

      private

      def graphics_available?
        defined?(Graphics) && defined?(Input) && defined?(Viewport) &&
          defined?(BitmapSprite) && defined?(PokemonBoxIcon) &&
          defined?(PokemonSummaryScreen)
      end
    end

    class PokemonVisual
      VISIBLE_BOUNDS_CACHE = {}
      VISIBLE_BOUNDS_CACHE_LIMIT = 2048
      SMALL_ART_THRESHOLD = 0.62
      SMALL_ART_SCALE = 1.2

      attr_reader :sprite

      def initialize(viewport, mode)
        @viewport = viewport
        @mode = mode
        @sprite = nil
        @animated_bitmap = nil
      end

      def set(pokemon, x, y, max_width, max_height, opacity = 255,
              scale_cap = 1.2)
        dispose_sprite
        return unless pokemon
        if @mode == :full_sprites
          create_full_sprite(pokemon)
        else
          create_icon_sprite(pokemon)
        end
        fit(pokemon, x, y, max_width, max_height, opacity, scale_cap)
      rescue StandardError => e
        dispose_sprite
        KantoReloaded::Log.exception(
          "Reloaded PC Pokemon sprite failed", e,
          :channel => :pc_organization
        ) if defined?(KantoReloaded::Log)
      end

      def update
        return unless @sprite
        if @animated_bitmap && @animated_bitmap.respond_to?(:update)
          @animated_bitmap.update
          @sprite.bitmap = @animated_bitmap.bitmap
        elsif @sprite.respond_to?(:update)
          @sprite.update
        end
      rescue StandardError
        nil
      end

      def visible=(value)
        @sprite.visible = value if @sprite && !@sprite.disposed?
      rescue StandardError
        nil
      end

      def move_to(x, y)
        return unless @sprite && !@sprite.disposed?
        @sprite.x = x
        @sprite.y = y
      rescue StandardError
        nil
      end

      def z=(value)
        @sprite.z = value if @sprite && !@sprite.disposed?
      rescue StandardError
        nil
      end

      def dispose
        dispose_sprite
      end

      private

      def create_icon_sprite(pokemon)
        icon = PokemonBoxIcon.new(nil, @viewport)
        icon.define_singleton_method(:use_big_icon?) { false }
        icon.pokemon = pokemon
        icon.refresh
        @sprite = icon
      end

      def create_full_sprite(pokemon)
        @animated_bitmap = GameData::Species.sprite_bitmap_from_pokemon(pokemon)
        return unless @animated_bitmap && @animated_bitmap.bitmap
        @sprite = Sprite.new(@viewport)
        @sprite.bitmap = @animated_bitmap.bitmap
      end

      def fit(pokemon, x, y, max_width, max_height, opacity, scale_cap)
        return unless @sprite && @sprite.bitmap
        source_width = if @sprite.respond_to?(:src_rect) && @sprite.src_rect.width > 0
                         @sprite.src_rect.width
                       else
                         @sprite.bitmap.width
                       end
        source_height = if @sprite.respond_to?(:src_rect) && @sprite.src_rect.height > 0
                          @sprite.src_rect.height
                        else
                          @sprite.bitmap.height
                        end
        bounds = visible_bounds(pokemon, source_width, source_height)
        art_width = [bounds[2], 1].max
        art_height = [bounds[3], 1].max
        frame_scale = [max_width.to_f / source_width,
                       max_height.to_f / source_height,
                       scale_cap.to_f].min
        art_occupancy = [art_width.to_f / source_width,
                         art_height.to_f / source_height].max
        scale = frame_scale
        if art_occupancy < SMALL_ART_THRESHOLD
          scale = [frame_scale * SMALL_ART_SCALE,
                   max_width.to_f / art_width,
                   max_height.to_f / art_height,
                   scale_cap.to_f].min
        end
        @sprite.zoom_x = scale
        @sprite.zoom_y = scale
        @sprite.ox = bounds[0] + art_width / 2
        @sprite.oy = bounds[1] + art_height / 2
        @sprite.x = x
        @sprite.y = y
        @sprite.z = 20
        @sprite.opacity = opacity
      end

      def visible_bounds(pokemon, source_width, source_height)
        key = visible_bounds_key(pokemon, source_width, source_height)
        cached = VISIBLE_BOUNDS_CACHE[key]
        return cached if cached
        bitmap = @sprite.bitmap
        source_x = if @sprite.respond_to?(:src_rect)
                     @sprite.src_rect.x.to_i
                   else
                     0
                   end
        source_y = if @sprite.respond_to?(:src_rect)
                     @sprite.src_rect.y.to_i
                   else
                     0
                   end
        width = [source_width.to_i, bitmap.width - source_x].min
        height = [source_height.to_i, bitmap.height - source_y].min
        return [0, 0, source_width, source_height] if width <= 0 || height <= 0
        step = [[width, height].max / 96, 1].max
        min_x = width
        min_y = height
        max_x = -1
        max_y = -1
        y = 0
        while y < height
          x = 0
          while x < width
            pixel = bitmap.get_pixel(source_x + x, source_y + y)
            if pixel.alpha.to_i > 0
              min_x = x if x < min_x
              min_y = y if y < min_y
              max_x = x if x > max_x
              max_y = y if y > max_y
            end
            x += step
          end
          y += step
        end
        bounds = if max_x < 0 || max_y < 0
                   [0, 0, source_width, source_height]
                 else
                   padding = step
                   left = [min_x - padding, 0].max
                   top = [min_y - padding, 0].max
                   right = [max_x + padding, width - 1].min
                   bottom = [max_y + padding, height - 1].min
                   [left, top, right - left + 1, bottom - top + 1]
                 end
        VISIBLE_BOUNDS_CACHE.shift if
          VISIBLE_BOUNDS_CACHE.length >= VISIBLE_BOUNDS_CACHE_LIMIT
        VISIBLE_BOUNDS_CACHE[key] = bounds
        bounds
      rescue StandardError
        [0, 0, source_width, source_height]
      end

      def visible_bounds_key(pokemon, source_width, source_height)
        values = [
          :species, :form, :gender, :egg?, :spriteform_head,
          :spriteform_body, :kuraycustomfile?, :hat, :hat_x, :hat_y,
          :sprite_scale
        ].map do |method_name|
          pokemon.respond_to?(method_name) ? pokemon.send(method_name) : nil
        end
        [@mode, source_width, source_height, values]
      rescue StandardError
        [@mode, source_width, source_height, pokemon.object_id]
      end

      def dispose_sprite
        if @sprite && !@sprite.disposed?
          @sprite.dispose
        end
        if @animated_bitmap && @animated_bitmap.respond_to?(:dispose)
          @animated_bitmap.dispose
        end
        @sprite = nil
        @animated_bitmap = nil
      rescue StandardError
        @sprite = nil
        @animated_bitmap = nil
      end
    end

    class DetailPokemonVisual
      attr_reader :sprite

      def initialize(viewport)
        sprite_class = if defined?(AutoMosaicPokemonSprite)
                         AutoMosaicPokemonSprite
                       else
                         PokemonSprite
                       end
        @sprite = sprite_class.new(viewport)
        @sprite.setOffset(PictureOrigin::Center) if @sprite.respond_to?(:setOffset)
        @sprite.z = 18
        @pokemon_signature = nil
      end

      def set(pokemon, x, y, max_width, max_height, mosaic = 0,
              scale_multiplier = 1.0)
        unless pokemon
          @sprite.visible = false
          @pokemon_signature = nil
          return
        end
        signature = pokemon_signature(pokemon)
        if signature != @pokemon_signature
          @sprite.setPokemonBitmap(pokemon)
          @sprite.mosaic = mosaic if mosaic.to_i > 0 &&
            @sprite.respond_to?(:mosaic=)
          @pokemon_signature = signature
        end
        fit(x, y, max_width, max_height, scale_multiplier)
        @sprite.visible = true
      rescue StandardError => e
        @sprite.visible = false if @sprite
        KantoReloaded::Log.exception(
          "Reloaded PC detail sprite failed", e,
          :channel => :pc_organization
        ) if defined?(KantoReloaded::Log)
      end

      def update
        @sprite.update if @sprite && !@sprite.disposed?
      rescue StandardError
        nil
      end

      def dispose
        @sprite.dispose if @sprite && !@sprite.disposed?
      rescue StandardError
        nil
      end

      private

      def pokemon_signature(pokemon)
        [pokemon.object_id,
         (pokemon.species rescue nil),
         (pokemon.form rescue nil),
         (pokemon.shiny? rescue false),
         (pokemon.shinyValue? rescue nil),
         (pokemon.shinyR? rescue nil),
         (pokemon.shinyG? rescue nil),
         (pokemon.shinyB? rescue nil),
         ((pokemon.shinyKRS? rescue nil).clone rescue nil),
         (pokemon.egg? rescue false),
         (pokemon.hat rescue nil),
         (pokemon.spriteform_head rescue nil),
         (pokemon.spriteform_body rescue nil),
         (pokemon.kuraycustomfile? rescue nil),
         (pokemon.kuraycustomfile rescue nil)]
      end

      def fit(x, y, max_width, max_height, scale_multiplier)
        return unless @sprite && @sprite.bitmap
        source_width = if @sprite.respond_to?(:src_rect) &&
                          @sprite.src_rect.width.to_i > 0
                         @sprite.src_rect.width
                       else
                         @sprite.bitmap.width
                       end
        source_height = if @sprite.respond_to?(:src_rect) &&
                           @sprite.src_rect.height.to_i > 0
                          @sprite.src_rect.height
                        else
                          @sprite.bitmap.height
                        end
        scale = [max_width.to_f / source_width,
                 max_height.to_f / source_height, 1.5].min
        scale *= scale_multiplier.to_f
        @sprite.zoom_x = scale
        @sprite.zoom_y = scale
        @sprite.x = x
        @sprite.y = y
      end
    end

    class Scene
      attr_reader :storage

      SCREEN_W = 512
      SCREEN_H = 384
      HEADER_H = 42
      FOOTER_H = 30
      MAIN_Y = 46
      MAIN_H = 228
      BOX_X = 6
      BOX_W = 326
      DETAIL_X = 338
      DETAIL_W = 168
      PARTY_Y = 280
      PARTY_H = 70

      BOX_COLUMNS = 5
      BOX_VISIBLE_ROWS = 3
      BOX_CELL_W = 60
      BOX_CELL_H = 66
      BOX_GRID_X = BOX_X + 10
      BOX_GRID_Y = MAIN_Y + 16
      PARTY_CELL_W = 62
      PARTY_CELL_H = 58
      PARTY_GRID_X = 82
      PARTY_GRID_Y = PARTY_Y + 6
      PARTY_VISIBLE_SLOTS = 6
      HEADER_SIDE_W = 146
      HEADER_CENTER_X = HEADER_SIDE_W
      HEADER_CENTER_W = SCREEN_W - (HEADER_SIDE_W * 2)
      TEXT_SIZE = 17
      DRAG_BOX_HOVER_FRAMES = 12
      BOX_SPRITE_WIDTH = 72
      BOX_SPRITE_HEIGHT = 74
      PARTY_SPRITE_WIDTH = 70
      PARTY_SPRITE_HEIGHT = 67
      HELD_SPRITE_SIZE = 94
      SLOT_SCALE_CAP = 1.35
      HELD_SCALE_CAP = 1.68
      HELD_GROUP_SPACING = 48
      FULL_SLIDE_FRAMES = 8
      REDUCED_SLIDE_FRAMES = 3

      BG = Color.new(14, 18, 30)
      PANEL = Color.new(26, 32, 50)
      PANEL_ALT = Color.new(20, 26, 42)
      BORDER = Color.new(60, 80, 130)
      WHITE = Color.new(255, 255, 255)
      GRAY = Color.new(175, 180, 200)
      DIM = Color.new(100, 106, 132)
      BLUE = Color.new(120, 190, 255)
      GREEN = Color.new(105, 224, 164)
      GOLD = Color.new(240, 200, 80)
      RED = Color.new(235, 96, 116)

      def initialize(storage_screen, command = ORGANISE_COMMAND)
        @storage_screen = storage_screen
        @storage = storage_screen.storage
        @command = command.to_i
        @focus = @command == DEPOSIT_COMMAND ? :party : :box
        @box_index = 0
        @party_index = 0
        @party_scroll = 0
        @scroll_row = 0
        @held_pokemon = nil
        @held_source = nil
        @fusion_item = nil
        @held_group = nil
        @cursor_mode = :default
        @multi_selected = []
        @multi_mouse_candidate = nil
        @quickswap_mouse_candidate = nil
        @group_mouse_dragging = false
        @drag_pokemon = nil
        @drag_source = nil
        @drag_origin = nil
        @mouse_dragging = false
        @mouse_left_down = false
        @header_zone = :current
        @drag_hover_zone = nil
        @drag_hover_frames = 0
        @drag_hover_switched = false
        @box_visuals = []
        @party_visuals = []
        @held_group_visuals = []
        @icon_mode = KantoReloaded::PCOrganization.icon_mode
        @rendered_box = nil
        @rendered_box_start = nil
        @rendered_party_start = nil
        @rendered_party_capacity = nil
        @box_background = nil
        @box_background_key = nil
        @detail_images = {}
        @carry_visual_pokemon = nil
        @closed = false
      end

      def main
        setup
        until @closed
          Graphics.update
          Input.update
          update_visuals
          handle_input
        end
        nil
      ensure
        dispose
      end

      # Public action bridge used by KR-owned storage menus and tools.
      def kr_storage
        @storage
      end

      def kr_storage_screen
        @storage_screen
      end

      def kr_current_location
        current_location
      end

      def kr_focused_pokemon
        focused_pokemon
      end

      def kr_held_pokemon
        @held_pokemon
      end

      def kr_held_source
        @held_source && @held_source.dup
      end

      def kr_held_group_count
        @held_group ? @held_group.length : 0
      end

      def kr_cursor_mode
        @cursor_mode
      end

      def kr_selected_locations
        @multi_selected.map(&:dup)
      end

      def kr_visible_box_locations
        start = visible_box_start
        finish = [start + @box_visuals.length, box_capacity].min
        (start...finish).map { |index| [@storage.currentBox, index] }
      end

      def kr_set_selected_locations(locations)
        normalized = Array(locations).map do |location|
          next unless location.is_a?(Array) && location.length >= 2
          [location[0].to_i, location[1].to_i]
        end.compact
        source = normalized.first && normalized.first[0]
        @multi_selected = normalized.select do |location|
          location[0] == source && storage_pokemon(location)
        end.uniq
        redraw_selection
      end

      def kr_clear_selected_locations
        clear_multi_selection
        redraw_selection
      end

      def kr_pick_up_current
        pick_up
      end

      def kr_place_or_swap
        place_or_swap
      end

      def kr_show_summary
        show_summary
      end

      def kr_pick_up_group(locations = nil, pivot = nil)
        entries = locations || @multi_selected
        pick_up_group(entries, pivot || current_location)
      end

      def kr_place_held_group
        place_held_group
      end

      def kr_release_group(locations = nil)
        release_group(locations || @multi_selected)
      end

      def kr_clear_held_pokemon
        @held_pokemon = nil
        @held_source = nil
        @fusion_item = nil
        update_carry_visual(true)
        refresh_all
      end

      def kr_set_held_pokemon(pokemon, source = nil)
        return false if @held_pokemon
        @held_pokemon = pokemon
        @held_source = source && source.dup
        @fusion_item = nil
        update_carry_visual(true)
        refresh_all
        true
      end

      def kr_begin_fusion(item)
        return false unless @held_pokemon && item
        @fusion_item = item
        refresh_all
        true
      end

      def kr_fusion_pending?
        !@fusion_item.nil?
      end

      def kr_fusion_item
        @fusion_item
      end

      def kr_cancel_fusion
        return false unless @fusion_item
        @fusion_item = nil
        pbPlayCancelSE rescue nil
        KantoReloaded.toast(_INTL("Fusion selection canceled."))
        refresh_all
        true
      end

      def kr_refresh
        refresh_all
      end

      def kr_jump_to_location(location)
        return false unless location.is_a?(Array) && location.length >= 2
        box = location[0].to_i
        index = location[1].to_i
        if box == -1
          @focus = :party
          @party_index = [[index, 0].max, party_capacity - 1].min
          ensure_party_visible
        else
          return false if box < 0 || box >= @storage.maxBoxes
          @storage.currentBox = box
          @focus = :box
          @box_index = [[index, 0].max, box_capacity - 1].min
          ensure_box_visible
        end
        refresh_all
        true
      end

      def kr_with_scene_hidden
        sprites = sprite_hash
        old_sprites = pbFadeOutAndHide(sprites)
        yield
      ensure
        pbFadeInAndShow(sprites, old_sprites) if sprites && old_sprites
        refresh_all if @canvas && !@closed
      end

      private

      def setup
        @viewport = Viewport.new(0, 0, SCREEN_W, SCREEN_H)
        @viewport.z = 999_999_000
        @canvas = BitmapSprite.new(SCREEN_W, SCREEN_H, @viewport)
        @canvas.z = 1
        @cursor_layer = BitmapSprite.new(SCREEN_W, SCREEN_H, @viewport)
        @cursor_layer.z = 10
        BOX_VISIBLE_ROWS.times do |row|
          BOX_COLUMNS.times do |column|
            @box_visuals << PokemonVisual.new(@viewport, @icon_mode)
          end
        end
        PARTY_VISIBLE_SLOTS.times do
          @party_visuals << PokemonVisual.new(@viewport, @icon_mode)
        end
        @drag_visual = PokemonVisual.new(@viewport, @icon_mode)
        @detail_visual = DetailPokemonVisual.new(@viewport)
        refresh_all
      end

      def refresh_all
        normalize_selection
        draw
        refresh_pokemon_visuals
        refresh_held_group_visuals
      end

      def redraw_selection
        normalize_selection
        draw
        refresh_pokemon_visuals if visible_visuals_stale?
      end

      def draw
        bitmap = @canvas.bitmap
        bitmap.clear
        @cursor_layer.bitmap.clear if @cursor_layer
        bitmap.fill_rect(0, 0, SCREEN_W, SCREEN_H, BG)
        set_font(bitmap)
        draw_header(bitmap)
        draw_box_panel(bitmap)
        draw_detail_panel(bitmap)
        draw_party_panel(bitmap)
        draw_footer(bitmap)
        draw_active_cursor
      end

      def draw_header(bitmap)
        bitmap.fill_rect(0, 0, SCREEN_W, HEADER_H, PANEL_ALT)
        bitmap.fill_rect(0, HEADER_H - 1, SCREEN_W, 1, BORDER)
        count = current_box.nitems rescue box_pokemon.compact.length
        previous_name = adjacent_box_name(-1)
        next_name = adjacent_box_name(1)
        current_label = _INTL("{1} ({2}/{3})", current_box.name,
                              count, box_capacity)
        draw_header_cursor(bitmap) if @focus == :header
        text(bitmap, 8, 8, HEADER_SIDE_W - 16, 24,
             fitted_text(bitmap, _INTL("< {1}", previous_name),
                         HEADER_SIDE_W - 16), BLUE)
        shadow_text(
          bitmap, HEADER_CENTER_X + 4, 5, HEADER_CENTER_W - 8, 34,
          fitted_text(bitmap, current_label, HEADER_CENTER_W - 8, 29),
          WHITE, 1, 29
        )
        text(bitmap, SCREEN_W - HEADER_SIDE_W + 8, 8,
             HEADER_SIDE_W - 16, 24,
             fitted_text(bitmap, _INTL("{1} >", next_name),
                         HEADER_SIDE_W - 16), BLUE, 2)
      end

      def draw_header_cursor(bitmap)
        x, width = case @header_zone
                   when :previous then [4, HEADER_SIDE_W - 8]
                   when :next then [SCREEN_W - HEADER_SIDE_W + 4,
                                    HEADER_SIDE_W - 8]
                   else [HEADER_CENTER_X + 4, HEADER_CENTER_W - 8]
                   end
        cursor(bitmap, x, 5, width, HEADER_H - 11)
      end

      def adjacent_box_name(amount)
        index = (@storage.currentBox + amount) % @storage.maxBoxes
        @storage.boxes[index].name.to_s
      rescue StandardError
        _INTL("Box {1}", index.to_i + 1)
      end

      def draw_box_panel(bitmap)
        panel(bitmap, BOX_X, MAIN_Y, BOX_W, MAIN_H)
        draw_box_background(bitmap)
        BOX_VISIBLE_ROWS.times do |row|
          BOX_COLUMNS.times do |column|
            local = row * BOX_COLUMNS + column
            index = visible_box_start + local
            x, y = box_cell_position(local)
            selected = @focus == :box && index == @box_index
            held = held_source?(:box, index)
            draw_slot(bitmap, x, y, BOX_CELL_W, BOX_CELL_H - 2,
                      selected, held)
          end
        end
        draw_scrollbar(bitmap)
      end

      def draw_box_background(bitmap)
        source = box_background_bitmap
        return unless source && !source.disposed?
        source_rect = if source.width >= 320 && source.height >= 290
                        Rect.new(4, 56, source.width - 8, source.height - 60)
                      else
                        Rect.new(0, 0, source.width, source.height)
                      end
        destination = Rect.new(BOX_X + 3, MAIN_Y + 3,
                               BOX_W - 6, MAIN_H - 6)
        bitmap.stretch_blt(destination, source, source_rect)
      rescue StandardError => e
        KantoReloaded::Log.exception(
          "Reloaded PC wallpaper failed", e,
          :channel => :pc_organization
        ) if defined?(KantoReloaded::Log)
      end

      def box_background_bitmap
        key = resolved_box_background
        if @box_background.nil? || @box_background_key != key
          @box_background.dispose if @box_background &&
            @box_background.respond_to?(:dispose)
          path = "Graphics/Pictures/Storage/box_#{key}"
          resolved = pbResolveBitmap(path) if defined?(pbResolveBitmap)
          path = "Graphics/Pictures/Storage/missing_box" unless resolved ||
            File.file?("#{path}.png")
          @box_background = AnimatedBitmap.new(path)
          @box_background_key = key
        end
        @box_background.bitmap
      end

      def resolved_box_background
        value = current_box.background rescue nil
        text_value = value.to_s
        quantity = if defined?(PokemonStorage::BASICWALLPAPERQTY)
                     PokemonStorage::BASICWALLPAPERQTY
                   else
                     16
                   end
        fallback = @storage.currentBox % [quantity.to_i, 1].max
        value = fallback if value.nil? || text_value.empty?
        value = $1.to_i if value.to_s =~ /^box_?(\d+)$/i
        value = value.to_i if value.is_a?(String) && value =~ /^\d+$/
        if @storage.respond_to?(:isAvailableWallpaper?) &&
            !@storage.isAvailableWallpaper?(value)
          value = fallback
        end
        value
      end

      def draw_detail_panel(bitmap)
        panel(bitmap, DETAIL_X, MAIN_Y, DETAIL_W, MAIN_H)
        pokemon = @drag_pokemon || @held_pokemon || held_group_pokemon ||
          focused_pokemon
        title = pokemon ? fitted_text(bitmap, pokemon.name.to_s,
                                      DETAIL_W - 16, 20) : _INTL("EMPTY SLOT")
        text(bitmap, DETAIL_X + 8, MAIN_Y + 6, DETAIL_W - 16, 24,
             title, pokemon ? WHITE : DIM, 1, 20)
        draw_gender_icon(bitmap, pokemon) if pokemon
        @detail_visual.set(
          pokemon, DETAIL_X + DETAIL_W / 2, MAIN_Y + 97,
          DETAIL_W - 20, 120, detail_mosaic, 1.15
        )
        return unless pokemon
        draw_type_icons(bitmap, pokemon)
        item = item_text(pokemon)
        held_item = pokemon.item rescue nil
        item_color = held_item ? GOLD : DIM
        text(bitmap, DETAIL_X + 8, MAIN_Y + MAIN_H - 30,
             DETAIL_W - 16, 22,
             fitted_text(bitmap, item, DETAIL_W - 16), item_color, 1)
      end

      def draw_party_panel(bitmap)
        panel(bitmap, BOX_X, PARTY_Y, SCREEN_W - 12, PARTY_H)
        text(bitmap, BOX_X + 10, PARTY_Y + 8, 62, 20, _INTL("PARTY"), BLUE, 1)
        text(bitmap, BOX_X + 10, PARTY_Y + 31, 62, 18,
             _INTL("{1}/{2}", @storage.party.length, party_capacity), GRAY, 1)
        draw_party_navigation(bitmap)
        PARTY_VISIBLE_SLOTS.times do |local|
          index = visible_party_start + local
          next if index >= party_capacity
          x, y = party_cell_position(local)
          selected = @focus == :party && index == @party_index
          held = held_source?(:party, index)
          draw_slot(bitmap, x, y, PARTY_CELL_W, PARTY_CELL_H,
                    selected, held)
        end
      end

      def draw_party_navigation(bitmap)
        return if party_capacity <= PARTY_VISIBLE_SLOTS
        if visible_party_start > 0
          text(bitmap, PARTY_GRID_X - 18, PARTY_Y + 24, 16, 22,
               "<", GREEN, 1, 20)
        end
        if visible_party_start + PARTY_VISIBLE_SLOTS < party_capacity
          text(bitmap, PARTY_GRID_X + PARTY_VISIBLE_SLOTS * PARTY_CELL_W + 2,
               PARTY_Y + 24, 28, 22, ">", GREEN, 1, 20)
        end
      end

      def draw_gender_icon(bitmap, pokemon)
        return if pokemon.egg?
        x = DETAIL_X + DETAIL_W - 29
        y = MAIN_Y + 1
        if pokemon.respond_to?(:pizza?) && pokemon.pizza?
          draw_detail_image(bitmap, "Graphics/Pictures/Storage/gender4",
                            x + 5, y + 1, 18, 18)
        elsif pokemon.respond_to?(:genderless?) && pokemon.genderless?
          draw_detail_image(bitmap, "Graphics/Pictures/Storage/gender3",
                            x + 3, y + 4, 20, 14)
        elsif pokemon.male?
          text(bitmap, x, y, 28, 24, "\u2642", BLUE, 1, 22)
        elsif pokemon.female?
          text(bitmap, x, y, 28, 24, "\u2640", Color.new(244, 104, 206), 1, 22)
        end
      rescue StandardError
        nil
      end

      def draw_detail_image(bitmap, path, x, y, width, height)
        image = @detail_images[path]
        unless image
          image = AnimatedBitmap.new(path)
          @detail_images[path] = image
        end
        source = image.bitmap
        return unless source && !source.disposed?
        bitmap.stretch_blt(Rect.new(x, y, width, height), source, source.rect)
      end

      def draw_type_icons(bitmap, pokemon)
        return if pokemon.egg?
        types = pokemon.types.compact.uniq[0, 2]
        return if types.empty?
        @type_bitmap ||= AnimatedBitmap.new("Graphics/Pictures/types")
        source = @type_bitmap.bitmap
        width = 64
        height = 28
        gap = 4
        total_width = types.length * width + (types.length - 1) * gap
        x = DETAIL_X + (DETAIL_W - total_width) / 2
        y = MAIN_Y + 168
        types.each do |type|
          number = GameData::Type.get(type).id_number
          source_rect = Rect.new(0, number * height, width, height)
          KantoReloaded::UI::Draw.rounded_stretch_blt(
            bitmap, Rect.new(x, y, width, height), source, source_rect, 5
          )
          x += width + gap
        end
      rescue StandardError => e
        KantoReloaded::Log.exception(
          "Reloaded PC type icons failed", e,
          :channel => :pc_organization
        ) if defined?(KantoReloaded::Log)
      end

      def detail_mosaic
        case KantoReloaded::PCOrganization.animation_mode
        when :full
          [(Graphics.frame_rate / 4 rescue 10), 1].max
        when :reduced
          [(Graphics.frame_rate / 10 rescue 4), 1].max
        else
          0
        end
      end

      def draw_footer(bitmap)
        y = SCREEN_H - FOOTER_H
        bitmap.fill_rect(0, y, SCREEN_W, FOOTER_H, BG)
        bitmap.fill_rect(0, y, SCREEN_W, 1, BORDER)
        mode_entry = KantoReloaded::HintText.action(cursor_mode_label)
        mode_entry[:pc_click] = :mode
        menu_entry = KantoReloaded::HintText.other("PC Menu", "Z")
        menu_entry[:pc_click] = :pc_menu
        entries = [
          KantoReloaded::HintText.confirm(
            carrying? ? "Place" : "Select"
          ),
          KantoReloaded::HintText.back("Back"),
          mode_entry,
          KantoReloaded::HintText.other("Focus", "X"),
          menu_entry
        ]
        KantoReloaded::HintText.draw_footer(
          bitmap, entries, 6, y + 3, SCREEN_W - 12,
          :size => 13, :color => WHITE, :height => FOOTER_H,
          :y_offset => -3, :show_hint => false
        )
        register_footer_hitboxes(bitmap, entries, 6, y + 3,
                                  SCREEN_W - 12, 13, FOOTER_H, -3)
      end

      def register_footer_hitboxes(bitmap, entries, x, y, width, size,
                                   height, y_offset)
        @footer_hitboxes = {}
        pbSetSmallFont(bitmap) if defined?(pbSetSmallFont)
        bitmap.font.size = size
        hint = KantoReloaded::HintText.other("Hints", "Z")
        hint_width = [bitmap.text_size(
          KantoReloaded::HintText.format([hint])
        ).width + 8, width / 3].min
        center_width = [width - hint_width - 8, 0].max
        labels = entries.map do |entry|
          KantoReloaded::HintText.format([entry])
        end
        separator_width = bitmap.text_size("   ").width
        total_width = labels.inject(0) do |sum, label|
          sum + bitmap.text_size(label).width
        end
        total_width += separator_width * [labels.length - 1, 0].max
        current_x = x + [(center_width - total_width) / 2, 0].max
        footer_y = y + y_offset
        entries.each_with_index do |entry, index|
          label_width = bitmap.text_size(labels[index]).width
          action = entry[:pc_click]
          if action
            @footer_hitboxes[action] = Rect.new(
              current_x - 3, footer_y, label_width + 6, height
            )
          end
          current_x += label_width + separator_width
        end
      rescue StandardError
        @footer_hitboxes = {}
      end

      def footer_action_at(mouse_x, mouse_y)
        return nil unless @footer_hitboxes
        entry = @footer_hitboxes.find do |_action, rect|
          inside?(mouse_x, mouse_y, rect.x, rect.y, rect.width, rect.height)
        end
        entry && entry[0]
      rescue StandardError
        nil
      end

      def draw_slot(_bitmap, _x, _y, _width, _height, _selected, _held)
      end

      def draw_active_cursor
        return unless @cursor_layer && @cursor_layer.bitmap
        bitmap = @cursor_layer.bitmap
        return if @focus == :header
        if @cursor_mode == :multiselect
          @multi_selected.each do |location|
            rect = cursor_rect_for(location)
            next unless rect
            cursor(bitmap, rect.x, rect.y, rect.width, rect.height)
          end
        end
        rect = cursor_rect_for(current_location)
        if rect
          cursor(bitmap, rect.x, rect.y, rect.width, rect.height, true)
        end
      end

      def refresh_cursor_pulse
        return unless @cursor_layer && @cursor_layer.bitmap
        @cursor_layer.bitmap.clear
        draw_active_cursor
      rescue StandardError
        nil
      end

      def cursor_rect_for(location)
        return nil unless location
        if location[0] == -1
          local = location[1] - visible_party_start
          return nil if local < 0 || local >= PARTY_VISIBLE_SLOTS
          x, y = party_cell_position(local)
          return Rect.new(x + 1, y + 1,
                          PARTY_CELL_W - 2, PARTY_CELL_H - 2)
        end
        return nil unless location[0] == @storage.currentBox
        local = location[1] - visible_box_start
        return nil if local < 0 || local >= @box_visuals.length
        x, y = box_cell_position(local)
        Rect.new(x + 1, y + 1, BOX_CELL_W - 2, BOX_CELL_H - 4)
      end

      def draw_scrollbar(bitmap)
        total_rows = (box_capacity.to_f / BOX_COLUMNS).ceil
        return if total_rows <= BOX_VISIBLE_ROWS
        x = BOX_X + BOX_W - 7
        y = BOX_GRID_Y
        height = BOX_VISIBLE_ROWS * BOX_CELL_H - 4
        bitmap.fill_rect(x, y, 2, height, Color.new(48, 56, 82))
        thumb_h = [height * BOX_VISIBLE_ROWS / total_rows, 12].max
        range = [total_rows - BOX_VISIBLE_ROWS, 1].max
        thumb_y = y + (height - thumb_h) * @scroll_row / range
        bitmap.fill_rect(x - 1, thumb_y, 4, thumb_h, BLUE)
      end

      def panel(bitmap, x, y, width, height)
        KantoReloaded::UI::Draw.rounded_rect(
          bitmap, x, y, width, height, 5, PANEL, BORDER
        )
      end

      def cursor(bitmap, x, y, width, height, pulse = false)
        fill, = KantoReloaded::Options.cursor_colors
        if pulse
          phase = Math.sin(
            (Graphics.frame_count rescue 0) * Math::PI / 20.0
          ) * 0.5 + 0.5
          fill = KantoReloaded::UI::Draw.with_alpha(
            fill, [[fill.alpha.to_i + (phase * 55).to_i, 255].min, 80].max
          )
        end
        KantoReloaded::UI::Draw.rounded_rect(
          bitmap, x, y, width, height, 4, fill
        )
      rescue StandardError
        KantoReloaded::UI::Draw.rounded_rect(
          bitmap, x, y, width, height, 4,
          Color.new(52, 76, 150)
        )
      end

      def set_font(bitmap)
        pbSetSmallFont(bitmap) if defined?(pbSetSmallFont)
        bitmap.font.size = TEXT_SIZE
      end

      def text(bitmap, x, y, width, height, value, color, align = 0,
               size = TEXT_SIZE)
        KantoReloaded::UI::Draw.plain_text(
          bitmap, x, y, width, height, value.to_s, color, align, size
        )
      end

      def shadow_text(bitmap, x, y, width, height, value, color, align = 0,
                      size = TEXT_SIZE)
        old_size = bitmap.font.size
        bitmap.font.size = size
        pbDrawShadowText(
          bitmap, x, y, width, height, value.to_s, color,
          Color.new(8, 10, 18), align
        )
      rescue StandardError
        text(bitmap, x, y, width, height, value, color, align, size)
      ensure
        bitmap.font.size = old_size if bitmap && old_size
      end

      def fitted_text(bitmap, value, width, size = TEXT_SIZE)
        result = value.to_s
        old_size = bitmap.font.size
        bitmap.font.size = size
        return result if bitmap.text_size(result).width <= width
        suffix = "..."
        result = result[0...-1] while !result.empty? &&
          bitmap.text_size(result + suffix).width > width
        result + suffix
      rescue StandardError
        value.to_s
      ensure
        bitmap.font.size = old_size if bitmap && old_size
      end

      def refresh_pokemon_visuals
        @box_visuals.each_with_index do |visual, local|
          index = visible_box_start + local
          pokemon = index < box_capacity ? @storage[@storage.currentBox, index] : nil
          x, y = box_cell_position(local)
          visual.set(pokemon, x + BOX_CELL_W / 2,
                     y + BOX_CELL_H / 2 + 2,
                     BOX_SPRITE_WIDTH, BOX_SPRITE_HEIGHT,
                     held_source?(:box, index) ? 105 : 255,
                     SLOT_SCALE_CAP)
        end
        @party_visuals.each_with_index do |visual, local|
          index = visible_party_start + local
          pokemon = @storage.party[index]
          x, y = party_cell_position(local)
          visual.set(pokemon, x + PARTY_CELL_W / 2,
                     y + PARTY_CELL_H / 2 + 2,
                     PARTY_SPRITE_WIDTH, PARTY_SPRITE_HEIGHT,
                     held_source?(:party, index) ? 105 : 255,
                     SLOT_SCALE_CAP)
        end
        @rendered_box = @storage.currentBox
        @rendered_box_start = visible_box_start
        @rendered_party_start = visible_party_start
        @rendered_party_capacity = party_capacity
      end

      def visible_visuals_stale?
        @rendered_box != @storage.currentBox ||
          @rendered_box_start != visible_box_start ||
          @rendered_party_start != visible_party_start ||
          @rendered_party_capacity != party_capacity
      end

      def update_visuals
        @box_visuals.each { |visual| visual.update }
        @party_visuals.each { |visual| visual.update }
        @held_group_visuals.each { |visual| visual.update }
        @detail_visual.update if @detail_visual
        update_carry_visual
        update_held_group_visuals
        @drag_visual.update if @drag_visual
        refresh_cursor_pulse if ((Graphics.frame_count rescue 0) % 4).zero?
      end

      def update_carry_visual(force = false)
        return if @mouse_dragging
        unless @held_pokemon
          if @carry_visual_pokemon
            @drag_visual.set(nil, 0, 0, 1, 1)
            @carry_visual_pokemon = nil
          end
          return
        end
        position = carry_position
        return unless position
        if force || !@carry_visual_pokemon.equal?(@held_pokemon)
          @drag_visual.set(@held_pokemon, position[0], position[1],
                           HELD_SPRITE_SIZE, HELD_SPRITE_SIZE, 255,
                           HELD_SCALE_CAP)
          @drag_visual.z = 100
          @carry_visual_pokemon = @held_pokemon
        end
        @drag_visual.move_to(position[0], position[1])
      rescue StandardError
        nil
      end

      def refresh_held_group_visuals
        @held_group_visuals.each { |visual| visual.dispose }
        @held_group_visuals = []
        return unless @held_group && !@held_group.empty?
        position = carry_position
        return unless position
        position = held_group_origin(position)
        @held_group.each do |entry|
          visual = PokemonVisual.new(@viewport, @icon_mode)
          visual.set(
            entry[:pokemon], position[0] + entry[:visual_x].to_i,
            position[1] + entry[:visual_y].to_i,
            HELD_SPRITE_SIZE, HELD_SPRITE_SIZE, 255, HELD_SCALE_CAP
          )
          visual.z = 100
          @held_group_visuals << visual
        end
      rescue StandardError => e
        KantoReloaded::Log.exception(
          "Reloaded PC multi-hold visuals failed", e,
          :channel => :pc_organization
        ) if defined?(KantoReloaded::Log)
      end

      def update_held_group_visuals
        return unless @held_group && !@held_group.empty?
        position = carry_position
        return unless position
        position = held_group_origin(position)
        @held_group_visuals.each_with_index do |visual, index|
          entry = @held_group[index]
          next unless entry
          visual.move_to(position[0] + entry[:visual_x].to_i,
                         position[1] + entry[:visual_y].to_i)
        end
      rescue StandardError
        nil
      end

      def carry_position
        router = KantoReloaded::UI::InputRouter
        position = router.raw_position if router.last_method == :mouse
        position || focused_cell_center
      rescue StandardError
        focused_cell_center
      end

      def cursor_mode_label
        case @cursor_mode
        when :quickswap then _INTL("Quick Swap")
        when :multiselect then _INTL("Multi Select")
        else _INTL("Normal")
        end
      end

      def cycle_cursor_mode
        if @held_group && !@held_group.empty?
          pbPlayBuzzerSE rescue nil
          return
        end
        choices = @held_pokemon ? [:default, :quickswap] :
          [:default, :quickswap, :multiselect]
        index = choices.index(@cursor_mode) || -1
        @cursor_mode = choices[(index + 1) % choices.length]
        clear_multi_selection unless @cursor_mode == :multiselect
        pbPlayDecisionSE rescue nil
        redraw_selection
      end

      def clear_multi_selection
        @multi_selected = []
        @multi_mouse_candidate = nil
      end

      def multi_selection_compatible?(location = current_location)
        return false if location[0] == :header
        @multi_selected.empty? || @multi_selected.first[0] == location[0]
      end

      def multi_selected?(location = current_location)
        @multi_selected.include?(location)
      end

      def focused_cell_center
        if @focus == :party
          ensure_party_visible
          local = @party_index - visible_party_start
          x, y = party_cell_position(local)
          return [x + PARTY_CELL_W / 2, y + PARTY_CELL_H / 2]
        end
        ensure_box_visible
        local = @box_index - visible_box_start
        x, y = box_cell_position(local)
        [x + BOX_CELL_W / 2, y + BOX_CELL_H / 2]
      end

      def handle_input
        return if handle_mouse
        if focus_triggered?
          cycle_focus
        elsif previous_box_triggered?
          change_box(-1)
        elsif next_box_triggered?
          change_box(1)
        elsif trigger?(:SPECIAL)
          KantoReloaded::PCOrganization.open_menu(self)
          refresh_all
        elsif Input.repeat?(Input::UP)
          move_vertical(-1)
        elsif Input.repeat?(Input::DOWN)
          move_vertical(1)
        elsif Input.repeat?(Input::LEFT)
          move_horizontal(-1)
        elsif Input.repeat?(Input::RIGHT)
          move_horizontal(1)
        elsif trigger?(:ACTION)
          cycle_cursor_mode
        elsif Input.trigger?(Input::USE)
          confirm_selection
        elsif Input.trigger?(Input::BACK)
          close_or_warn
        end
      end

      def handle_mouse
        raw_position = KantoReloaded::UI::InputRouter.raw_position
        left_down = mouse_pressed?(:MOUSELEFT)
        left_triggered = trigger?(:MOUSELEFT)
        right_triggered = trigger?(:MOUSERIGHT)
        if @quickswap_mouse_candidate
          return handle_quickswap_mouse_candidate(raw_position, left_down)
        end
        return true if handle_mouse_wheel(raw_position)
        if @group_mouse_dragging
          return handle_group_mouse_drag(raw_position, left_down)
        end
        if @multi_mouse_candidate
          return handle_multi_mouse_candidate(raw_position, left_down)
        end
        if @mouse_dragging
          update_drag(raw_position)
          if @mouse_left_down && !left_down
            finish_drag(raw_position)
            @mouse_left_down = false
            return true
          end
          @mouse_left_down = left_down
          return true
        end
        if left_triggered && raw_position
          footer_action = footer_action_at(raw_position[0].to_i,
                                           raw_position[1].to_i)
          if footer_action == :mode
            cycle_cursor_mode
            return true
          elsif footer_action == :pc_menu
            KantoReloaded::PCOrganization.open_menu(self)
            refresh_all
            return true
          end
        end
        position = KantoReloaded::UI::InputRouter.active_position
        return false unless position
        x = position[0].to_i
        y = position[1].to_i
        hover_zone = header_zone_at(x, y)
        if carrying? && [:previous, :next].include?(hover_zone)
          update_drag_box_hover(hover_zone)
        else
          reset_drag_box_hover
        end
        selection = select_from_point(x, y)
        if selection == :changed
          pbPlayCursorSE rescue nil
          draw
        end
        if left_triggered && selection == :party_previous
          move_party_window(-1)
          return true
        elsif left_triggered && selection == :party_next
          move_party_window(1)
          return true
        end
        if left_triggered && selection != :none &&
            selection != :blocked
          if [:previous, :next].include?(hover_zone)
            change_box(hover_zone == :previous ? -1 : 1)
          elsif @focus == :header
            activate_header_zone
          elsif @held_group
            place_held_group
          elsif @held_pokemon
            if @fusion_item && defined?(KantoReloaded::StorageActions)
              KantoReloaded::StorageActions.complete_held_fusion(self)
            else
              place_or_swap
            end
          elsif @cursor_mode == :multiselect && focused_pokemon
            if multi_selected?
              begin_multi_mouse_candidate(raw_position || position)
            else
              multiselect_selection
            end
          elsif @cursor_mode == :quickswap && focused_pokemon
            begin_quickswap_mouse_candidate(raw_position || position)
          elsif focused_pokemon
            start_drag(raw_position || position)
            @mouse_left_down = left_down || left_triggered
          end
          return true
        end
        if right_triggered && !left_down && !left_triggered &&
            selection != :none && selection != :blocked &&
            selection != :box_navigation &&
            selection != :party_previous && selection != :party_next
          open_context_menu
          return true
        end
        selection != :none
      rescue StandardError
        false
      end

      def handle_mouse_wheel(raw_position)
        return false unless raw_position
        wheel = KantoReloaded::UI::InputRouter.wheel_delta
        return false if wheel == 0
        x = raw_position[0].to_i
        y = raw_position[1].to_i
        amount = wheel < 0 ? 1 : -1
        if box_panel_at?(x, y)
          scroll_box_rows(amount)
          return true
        end
        if party_slots_at?(x, y) && party_capacity > PARTY_VISIBLE_SLOTS
          move_party_window(amount)
          return true
        end
        false
      end

      def box_panel_at?(mouse_x, mouse_y)
        inside?(mouse_x, mouse_y, BOX_X, MAIN_Y, BOX_W, MAIN_H)
      end

      def party_slots_at?(mouse_x, mouse_y)
        inside?(mouse_x, mouse_y, PARTY_GRID_X, PARTY_GRID_Y,
                PARTY_VISIBLE_SLOTS * PARTY_CELL_W, PARTY_CELL_H)
      end

      def scroll_box_rows(amount)
        old_scroll = @scroll_row.to_i
        max_scroll = [box_total_rows - BOX_VISIBLE_ROWS, 0].max
        next_scroll = [[old_scroll + amount.to_i, 0].max, max_scroll].min
        return if next_scroll == old_scroll
        row_change = next_scroll - old_scroll
        @scroll_row = next_scroll
        @box_index = [[@box_index + row_change * BOX_COLUMNS, 0].max,
                      box_capacity - 1].min
        @focus = :box
        moved
      end

      def begin_quickswap_mouse_candidate(position)
        return unless position
        @quickswap_mouse_candidate = {
          :location => current_location.dup,
          :x => position[0].to_i,
          :y => position[1].to_i
        }
        @mouse_left_down = true
      end

      def handle_quickswap_mouse_candidate(position, left_down)
        candidate = @quickswap_mouse_candidate
        return false unless candidate
        if left_down
          if position
            distance_x = position[0].to_i - candidate[:x]
            distance_y = position[1].to_i - candidate[:y]
            if distance_x.abs >= 4 || distance_y.abs >= 4
              @quickswap_mouse_candidate = nil
              start_drag(position)
            end
          end
          return true
        end
        @quickswap_mouse_candidate = nil
        @mouse_left_down = false
        quickswap_selection
        true
      end

      def begin_multi_mouse_candidate(position)
        return unless position
        @multi_mouse_candidate = {
          :location => current_location.dup,
          :x => position[0].to_i,
          :y => position[1].to_i
        }
        @mouse_left_down = true
      end

      def handle_multi_mouse_candidate(position, left_down)
        candidate = @multi_mouse_candidate
        return false unless candidate
        if left_down
          if position
            distance_x = position[0].to_i - candidate[:x]
            distance_y = position[1].to_i - candidate[:y]
            if distance_x.abs >= 4 || distance_y.abs >= 4
              locations = @multi_selected.map(&:dup)
              pivot = candidate[:location]
              @multi_mouse_candidate = nil
              pick_up_group(locations, pivot)
              @group_mouse_dragging = !!(@held_group && !@held_group.empty?)
            end
          end
          return true
        end
        @multi_mouse_candidate = nil
        open_multi_selection_actions(candidate[:location])
        true
      end

      def handle_group_mouse_drag(position, left_down)
        if position
          x = position[0].to_i
          y = position[1].to_i
          hover_zone = header_zone_at(x, y)
          if [:previous, :next].include?(hover_zone)
            update_drag_box_hover(hover_zone)
          else
            reset_drag_box_hover
          end
          selection = select_from_point(x, y)
          if selection == :changed
            pbPlayCursorSE rescue nil
            draw
          end
        end
        return true if left_down
        @group_mouse_dragging = false
        reset_drag_box_hover
        if position
          selection = select_from_point(position[0].to_i,
                                        position[1].to_i)
          unless selection == :none || selection == :blocked ||
              selection == :box_navigation ||
              selection == :party_previous || selection == :party_next ||
              @focus == :header
            place_held_group
          end
        end
        true
      end

      def start_drag(position)
        pokemon = focused_pokemon
        return false unless pokemon
        @drag_source = current_location
        @drag_origin = {
          :box => @storage.currentBox,
          :focus => @focus,
          :box_index => @box_index,
          :party_index => @party_index,
          :party_scroll => @party_scroll,
          :scroll_row => @scroll_row
        }
        @drag_pokemon = pokemon
        @mouse_dragging = true
        refresh_all
        update_drag(position)
        pbPlayDecisionSE rescue nil
        true
      end

      def update_drag(position)
        return unless @mouse_dragging && position
        x = position[0].to_i
        y = position[1].to_i
        hover_zone = header_zone_at(x, y)
        if [:previous, :next].include?(hover_zone)
          update_drag_box_hover(hover_zone)
        else
          reset_drag_box_hover
        end
        selection = select_from_point(x, y)
        if selection == :changed
          pbPlayCursorSE rescue nil
          draw
        end
        unless @drag_visual.sprite
          @drag_visual.set(@drag_pokemon, x, y,
                           HELD_SPRITE_SIZE, HELD_SPRITE_SIZE, 255,
                           HELD_SCALE_CAP)
          @drag_visual.z = 100
        end
        @drag_visual.move_to(x, y)
      end

      def finish_drag(position)
        target = drag_target(position)
        completed = target ? drag_swap(target) : false
        restore_drag_origin unless completed
      ensure
        clear_drag
        refresh_all
      end

      def restore_drag_origin
        return unless @drag_origin
        @storage.currentBox = @drag_origin[:box]
        @focus = @drag_origin[:focus]
        @box_index = @drag_origin[:box_index]
        @party_index = @drag_origin[:party_index]
        @party_scroll = @drag_origin[:party_scroll]
        @scroll_row = @drag_origin[:scroll_row]
      end

      def drag_target(position)
        return nil unless position
        result = select_from_point(position[0].to_i, position[1].to_i)
        return nil if result == :none || result == :blocked ||
          result == :box_navigation || result == :party_previous ||
          result == :party_next || @focus == :header
        current_location
      end

      def drag_swap(target)
        source = @drag_source
        return false unless source && target
        return true if source == target
        source_pokemon = storage_pokemon(source)
        return false unless source_pokemon && source_pokemon.equal?(@drag_pokemon)
        target_pokemon = storage_pokemon(target)
        return false unless valid_drag_swap?(source, source_pokemon,
                                             target, target_pokemon)
        pbSEPlay(target_pokemon ? "GUI storage pick up" :
                   "GUI storage put down") rescue nil
        animate_drop_to(focused_cell_center)
        prepare_for_box(source_pokemon) if target[0] >= 0
        prepare_for_box(target_pokemon) if target_pokemon && source[0] >= 0
        @storage[target[0], target[1]] = source_pokemon
        @storage[source[0], source[1]] = target_pokemon
        @storage.party.compact! if source[0] == -1 || target[0] == -1
        true
      end

      def valid_drag_swap?(source, source_pokemon, target, target_pokemon)
        if target[0] >= 0 && pokemon_has_mail?(source_pokemon)
          drag_warning(_INTL("Please remove the Mail."))
          return false
        end
        if source[0] >= 0 && target_pokemon && pokemon_has_mail?(target_pokemon)
          drag_warning(_INTL("Please remove the Mail."))
          return false
        end
        if source[0] == -1 && target[0] != -1 && able?(source_pokemon) &&
            able_party_count <= 1 && !able?(target_pokemon)
          drag_warning(_INTL("That's your last Pokemon!"))
          return false
        end
        if target[0] == -1 && source[0] != -1 && target_pokemon &&
            able?(target_pokemon) && able_party_count <= 1 &&
            !able?(source_pokemon)
          drag_warning(_INTL("That's your last Pokemon!"))
          return false
        end
        true
      end

      def drag_warning(message)
        pbPlayBuzzerSE rescue nil
        KantoReloaded.toast_warning(message)
      end

      def clear_drag
        @drag_visual.set(nil, 0, 0, 1, 1) if @drag_visual
        @carry_visual_pokemon = nil
        @drag_pokemon = nil
        @drag_source = nil
        @drag_origin = nil
        @mouse_dragging = false
        @mouse_left_down = false
        reset_drag_box_hover
      end

      def open_context_menu
        if defined?(KantoReloaded::StorageActions)
          KantoReloaded::StorageActions.open_context(self)
          redraw_selection
          return
        end
        if @focus == :header
          rows = [
            { :label => _INTL("Choose Box"), :value => :choose_box },
            { :label => _INTL("Cancel"), :value => :cancel }
          ]
          choice = KantoReloaded::PopupWindow.choice(
            current_box.name.to_s, rows
          )
          choose_box if choice == :choose_box
          redraw_selection
          return
        end
        pokemon = focused_pokemon
        if @held_group
          rows = [
            { :label => _INTL("Place"), :value => :place },
            { :label => _INTL("Cancel"), :value => :cancel }
          ]
          choice = KantoReloaded::PopupWindow.choice(
            _INTL("{1} Pokemon selected", @held_group.length), rows
          )
          place_held_group if choice == :place
          redraw_selection
          return
        end
        if @held_pokemon
          action_name = pokemon ? _INTL("Swap") : _INTL("Place")
          rows = [
            { :label => action_name, :value => :place },
            { :label => _INTL("Summary"), :value => :summary },
            { :label => _INTL("Cancel"), :value => :cancel }
          ]
          choice = KantoReloaded::PopupWindow.choice(
            @held_pokemon.name.to_s, rows
          )
          case choice
          when :place then place_or_swap
          when :summary then show_summary
          else redraw_selection
          end
          return
        end
        return unless pokemon
        rows = [
          { :label => _INTL("Move"), :value => :move },
          { :label => _INTL("Summary"), :value => :summary },
          { :label => _INTL("Cancel"), :value => :cancel }
        ]
        choice = KantoReloaded::PopupWindow.choice(pokemon.name.to_s, rows)
        case choice
        when :move then pick_up
        when :summary then show_summary
        else redraw_selection
        end
      end

      def select_from_point(mouse_x, mouse_y)
        if mouse_y < HEADER_H
          zone = header_zone_at(mouse_x, mouse_y)
          if carrying?
            return :box_navigation if [:previous, :next].include?(zone)
            return :blocked
          end
          changed = set_focus(:header)
          changed = true if @header_zone != zone
          @header_zone = zone
          return changed ? :changed : :same
        end
        if mouse_y >= PARTY_Y && mouse_y < PARTY_Y + PARTY_H
          navigation = party_navigation_at(mouse_x, mouse_y)
          return navigation if navigation
          PARTY_VISIBLE_SLOTS.times do |local|
            index = visible_party_start + local
            next if index >= party_capacity
            x, y = party_cell_position(local)
            next unless inside?(mouse_x, mouse_y, x, y,
                                PARTY_CELL_W, PARTY_CELL_H)
            changed = set_focus(:party)
            changed = true if @party_index != index
            @party_index = index
            return changed ? :changed : :same
          end
        end
        @box_visuals.each_index do |local|
          x, y = box_cell_position(local)
          next unless inside?(mouse_x, mouse_y, x, y,
                              BOX_CELL_W, BOX_CELL_H - 2)
          index = visible_box_start + local
          next if index >= box_capacity
          changed = set_focus(:box)
          changed = true if @box_index != index
          @box_index = index
          return changed ? :changed : :same
        end
        :none
      end

      def header_zone_at(mouse_x, mouse_y)
        return nil unless mouse_y >= 0 && mouse_y < HEADER_H
        return :previous if mouse_x < HEADER_SIDE_W
        return :next if mouse_x >= SCREEN_W - HEADER_SIDE_W
        :current
      end

      def party_navigation_at(mouse_x, mouse_y)
        return nil if party_capacity <= PARTY_VISIBLE_SLOTS
        if visible_party_start > 0 &&
            inside?(mouse_x, mouse_y, PARTY_GRID_X - 20,
                    PARTY_Y + 16, 20, 38)
          return :party_previous
        end
        if visible_party_start + PARTY_VISIBLE_SLOTS < party_capacity &&
            inside?(mouse_x, mouse_y,
                    PARTY_GRID_X + PARTY_VISIBLE_SLOTS * PARTY_CELL_W,
                    PARTY_Y + 16, 34, 38)
          return :party_next
        end
        nil
      end

      def move_party_window(amount)
        old_start = visible_party_start
        old_capture = capture_party_tray if slide_animation_frames > 0
        @focus = :party
        if amount < 0
          @party_index = [visible_party_start - 1, 0].max
        else
          @party_index = [visible_party_start + PARTY_VISIBLE_SLOTS,
                          party_capacity - 1].min
        end
        ensure_party_visible
        moved
        if old_start != visible_party_start
          animate_party_scroll(old_capture, amount)
        else
          old_capture.dispose if old_capture && !old_capture.disposed?
        end
      end

      def activate_header_zone
        case @header_zone
        when :previous then change_box(-1)
        when :next then change_box(1)
        else choose_box
        end
      end

      def update_drag_box_hover(zone)
        if @drag_hover_zone != zone
          @drag_hover_zone = zone
          @drag_hover_frames = 0
          @drag_hover_switched = false
        end
        return if @drag_hover_switched
        @drag_hover_frames += 1
        return if @drag_hover_frames < DRAG_BOX_HOVER_FRAMES
        change_box(zone == :previous ? -1 : 1, false)
        @drag_hover_switched = true
      end

      def reset_drag_box_hover
        @drag_hover_zone = nil
        @drag_hover_frames = 0
        @drag_hover_switched = false
      end

      def set_focus(value)
        return false if carrying? && value == :header
        changed = @focus != value
        @focus = value
        clear_multi_selection if changed && !@multi_selected.empty?
        changed
      end

      def inside?(point_x, point_y, x, y, width, height)
        point_x >= x && point_x < x + width &&
          point_y >= y && point_y < y + height
      end

      def cycle_focus
        choices = carrying? ? [:box, :party] : [:header, :box, :party]
        index = choices.index(@focus) || -1
        @focus = choices[(index + 1) % choices.length]
        clear_multi_selection unless @multi_selected.empty?
        @header_zone = :current if @focus == :header
        pbPlayCursorSE rescue nil
        redraw_selection
      end

      def move_vertical(amount)
        case @focus
        when :header
          @focus = amount > 0 ? :box : :party
        when :box
          candidate = @box_index + amount * BOX_COLUMNS
          if candidate < 0
            @focus = carrying? ? :party : :header
          elsif candidate >= box_capacity
            @focus = :party
            @party_index = [@box_index % BOX_COLUMNS,
                            party_capacity - 1].min
            ensure_party_visible
          else
            @box_index = candidate
            ensure_box_visible
          end
        when :party
          if amount < 0
            @focus = :box
            row = [box_total_rows - 1, @scroll_row + BOX_VISIBLE_ROWS - 1].min
            @box_index = [row * BOX_COLUMNS +
                          [@party_index, BOX_COLUMNS - 1].min,
                          box_capacity - 1].min
            ensure_box_visible
          elsif !carrying?
            @focus = :header
          else
            @focus = :box
          end
        end
        moved
      end

      def move_horizontal(amount)
        old_party_start = nil
        old_party_capture = nil
        case @focus
        when :header
          change_box(amount)
          return
        when :box
          @box_index = [[@box_index + amount, 0].max,
                        box_capacity - 1].min
          ensure_box_visible
        when :party
          old_party_start = visible_party_start
          old_party_capture = capture_party_tray if slide_animation_frames > 0
          @party_index = [[@party_index + amount, 0].max,
                          party_capacity - 1].min
          ensure_party_visible
        end
        moved
        if old_party_start && old_party_start != visible_party_start
          animate_party_scroll(old_party_capture, amount)
        elsif old_party_capture && !old_party_capture.disposed?
          old_party_capture.dispose
        end
      end

      def moved
        if !@multi_selected.empty? && !multi_selection_compatible?
          clear_multi_selection
        end
        pbPlayCursorSE rescue nil
        redraw_selection
      end

      def change_box(amount, animate = true)
        old_box = @storage.currentBox
        old_capture = capture_box_panel if animate && slide_animation_frames > 0
        @storage.currentBox = (@storage.currentBox + amount) % @storage.maxBoxes
        if old_box == @storage.currentBox
          old_capture.dispose if old_capture && !old_capture.disposed?
          return
        end
        @box_index = [[@box_index.to_i, 0].max, box_capacity - 1].min
        ensure_box_visible
        clear_multi_selection unless @multi_selected.empty?
        pbPlayCursorSE rescue nil
        refresh_all
        animate_box_transition(old_capture, amount) if animate
      end

      def animate_box_transition(old_capture, amount)
        return unless old_capture
        animate_region_slide(
          old_capture, capture_box_panel,
          BOX_X, MAIN_Y, BOX_W, MAIN_H,
          amount, @box_visuals
        )
      end

      def animate_party_scroll(old_capture, amount)
        x = PARTY_GRID_X - 6
        y = PARTY_Y + 3
        width = SCREEN_W - BOX_X - 6 - x
        height = PARTY_H - 6
        animate_region_slide(
          old_capture, capture_party_tray,
          x, y, width, height,
          amount, @party_visuals
        )
      end

      def capture_box_panel
        capture_region(BOX_X, MAIN_Y, BOX_W, MAIN_H, @box_visuals)
      end

      def capture_party_tray
        x = PARTY_GRID_X - 6
        y = PARTY_Y + 3
        width = SCREEN_W - BOX_X - 6 - x
        height = PARTY_H - 6
        capture_region(x, y, width, height, @party_visuals)
      end

      def capture_region(x, y, width, height, visuals)
        bitmap = Bitmap.new(width, height)
        bitmap.blt(0, 0, @canvas.bitmap, Rect.new(x, y, width, height))
        visuals.each do |visual|
          capture_sprite(bitmap, visual.sprite, x, y)
        end
        bitmap
      rescue StandardError => e
        bitmap.dispose if bitmap && !bitmap.disposed?
        KantoReloaded::Log.exception(
          "Reloaded PC transition capture failed", e,
          :channel => :pc_organization
        ) if defined?(KantoReloaded::Log)
        nil
      end

      def capture_sprite(bitmap, sprite, origin_x, origin_y)
        return unless sprite && !sprite.disposed? && sprite.visible &&
          sprite.bitmap && !sprite.bitmap.disposed?
        source = sprite.src_rect
        source = sprite.bitmap.rect if !source || source.width.to_i <= 0 ||
          source.height.to_i <= 0
        width = [(source.width * sprite.zoom_x).round, 1].max
        height = [(source.height * sprite.zoom_y).round, 1].max
        left = (sprite.x - sprite.ox * sprite.zoom_x).round - origin_x
        top = (sprite.y - sprite.oy * sprite.zoom_y).round - origin_y
        bitmap.stretch_blt(
          Rect.new(left, top, width, height), sprite.bitmap, source,
          sprite.opacity
        )
      rescue StandardError
        nil
      end

      def animate_region_slide(old_bitmap, new_bitmap, x, y, width, height,
                               amount, visuals)
        frames = slide_animation_frames
        unless frames > 0 && old_bitmap && new_bitmap
          old_bitmap.dispose if old_bitmap && !old_bitmap.disposed?
          new_bitmap.dispose if new_bitmap && !new_bitmap.disposed?
          return
        end
        previous_visibility = visuals.map do |visual|
          sprite = visual.sprite
          sprite ? sprite.visible : false
        end
        visuals.each { |visual| visual.visible = false }
        overlay = Sprite.new(@viewport)
        overlay.bitmap = Bitmap.new(SCREEN_W, SCREEN_H)
        overlay.z = 80
        direction = amount.to_i < 0 ? -1 : 1
        frames.times do |index|
          progress = ease_out((index + 1).to_f / frames)
          old_offset = (-direction * width * progress).round
          new_offset = (direction * width * (1.0 - progress)).round
          overlay.bitmap.clear
          overlay.bitmap.fill_rect(x, y, width, height, PANEL)
          draw_shifted_region(overlay.bitmap, old_bitmap, x, y,
                              width, height, old_offset)
          draw_shifted_region(overlay.bitmap, new_bitmap, x, y,
                              width, height, new_offset)
          Graphics.update
          Input.update
        end
      rescue StandardError => e
        KantoReloaded::Log.exception(
          "Reloaded PC slide animation failed", e,
          :channel => :pc_organization
        ) if defined?(KantoReloaded::Log)
      ensure
        if visuals && previous_visibility
          visuals.each_with_index do |visual, index|
            visual.visible = previous_visibility[index]
          end
        end
        if overlay
          overlay.bitmap.dispose if overlay.bitmap && !overlay.bitmap.disposed?
          overlay.dispose unless overlay.disposed?
        end
        old_bitmap.dispose if old_bitmap && !old_bitmap.disposed?
        new_bitmap.dispose if new_bitmap && !new_bitmap.disposed?
      end

      def draw_shifted_region(target, source, x, y, width, height, offset)
        destination_x = [offset, 0].max
        source_x = [-offset, 0].max
        copy_width = [width - destination_x, width - source_x].min
        return if copy_width <= 0
        target.blt(
          x + destination_x, y, source,
          Rect.new(source_x, 0, copy_width, height)
        )
      end

      def slide_animation_frames
        case KantoReloaded::PCOrganization.animation_mode
        when :full then FULL_SLIDE_FRAMES
        when :reduced then REDUCED_SLIDE_FRAMES
        else 0
        end
      end

      def action_animation_frames
        case KantoReloaded::PCOrganization.animation_mode
        when :full
          [(8 * (Graphics.frame_rate rescue 40) / 20), 2].max
        when :reduced
          [(4 * (Graphics.frame_rate rescue 40) / 20), 2].max
        else
          0
        end
      end

      def ease_out(progress)
        1.0 - ((1.0 - progress) ** 3)
      end

      def confirm_selection
        if @focus == :header
          if defined?(KantoReloaded::StorageActions)
            KantoReloaded::StorageActions.open_context(self)
            redraw_selection
          else
            choose_box
          end
          return
        end
        if @held_group
          place_held_group
          return
        end
        if @held_pokemon
          if @fusion_item && defined?(KantoReloaded::StorageActions)
            KantoReloaded::StorageActions.complete_held_fusion(self)
          else
            place_or_swap
          end
          return
        end
        if @cursor_mode == :quickswap
          quickswap_selection
          return
        elsif @cursor_mode == :multiselect
          multiselect_selection
          return
        end
        pokemon = focused_pokemon
        unless pokemon
          pbPlayBuzzerSE rescue nil
          return
        end
        if defined?(KantoReloaded::StorageActions)
          KantoReloaded::StorageActions.open_context(self)
          redraw_selection
          return
        end
        rows = [
          { :label => _INTL("Move"), :value => :move },
          { :label => _INTL("Summary"), :value => :summary },
          { :label => _INTL("Cancel"), :value => :cancel }
        ]
        choice = KantoReloaded::PopupWindow.choice(pokemon.name.to_s, rows)
        case choice
        when :move then pick_up
        when :summary then show_summary
        else redraw_selection
        end
      end

      def quickswap_selection
        pokemon = focused_pokemon
        unless pokemon
          pbPlayBuzzerSE rescue nil
          return
        end
        pick_up
      end

      def multiselect_selection
        location = current_location
        return if location[0] == :header
        unless multi_selection_compatible?(location)
          pbPlayBuzzerSE rescue nil
          return
        end
        if multi_selected?(location)
          open_multi_selection_actions(location)
          return
        end
        unless storage_pokemon(location)
          pbPlayBuzzerSE rescue nil
          return
        end
        @multi_selected << location.dup
        pbPlayDecisionSE rescue nil
        redraw_selection
      end

      def open_multi_selection_actions(pivot = current_location)
        if defined?(KantoReloaded::StorageActions)
          KantoReloaded::StorageActions.open_multi(self, pivot)
          redraw_selection
          return
        end
        pokemon_count = @multi_selected.count do |entry|
          storage_pokemon(entry)
        end
        if pokemon_count <= 0
          clear_multi_selection
          pbPlayBuzzerSE rescue nil
          redraw_selection
          return
        end
        rows = [
          { :label => _INTL("Move"), :value => :move },
          { :label => _INTL("Deselect"), :value => :deselect },
          { :label => _INTL("Release"), :value => :release },
          { :label => _INTL("Cancel"), :value => :cancel }
        ]
        choice = KantoReloaded::PopupWindow.choice(
          _INTL("Selected {1} Pokemon", pokemon_count), rows
        )
        completed = case choice
                    when :move
                      pick_up_group(@multi_selected, pivot)
                    when :release
                      release_group(@multi_selected)
                    when :deselect
                      @multi_selected.delete(pivot)
                      pbPlayDecisionSE rescue nil
                      false
                    else
                      false
                    end
        clear_multi_selection if completed
        redraw_selection
      end

      def pick_up_group(locations, _pivot)
        entries = locations.map do |location|
          pokemon = storage_pokemon(location)
          pokemon ? { :pokemon => pokemon, :source => location.dup } : nil
        end.compact
        return if entries.empty?
        source_box = entries.first[:source][0]
        if source_box == -1
          selected_able = entries.count { |entry| able?(entry[:pokemon]) }
          if selected_able >= able_party_count
            if entries.length <= 1
              pbPlayBuzzerSE rescue nil
              KantoReloaded.toast_warning(_INTL("That's your last Pokemon!"))
              return
            end
            protected_entry = entries.find { |entry| able?(entry[:pokemon]) }
            entries.delete(protected_entry)
          end
        end
        arrange_held_group(entries)
        indexes = entries.map { |entry| entry[:source][1] }
        @storage.pbDeleteMulti(source_box, indexes)
        @held_group = entries
        clear_multi_selection
        pbPlayDecisionSE rescue nil
        refresh_all
        true
      end

      def release_group(locations)
        entries = locations.map do |location|
          pokemon = storage_pokemon(location)
          pokemon ? [location, pokemon] : nil
        end.compact
        return if entries.empty?
        entries.each do |_location, pokemon|
          if (pokemon.owner.name.to_s == "RENTAL" rescue false)
            KantoReloaded.toast_warning(
              _INTL("Rental Pokemon cannot be released.")
            )
            return
          elsif pokemon.egg?
            KantoReloaded.toast_warning(_INTL("Eggs cannot be released."))
            return
          elsif pokemon_has_mail?(pokemon)
            KantoReloaded.toast_warning(_INTL("Please remove the Mail."))
            return
          end
        end
        if entries.first[0][0] == -1 &&
            entries.count { |_location, pokemon| able?(pokemon) } >=
              able_party_count
          KantoReloaded.toast_warning(_INTL("That's your last Pokemon!"))
          return
        end
        return unless KantoReloaded::PopupWindow.confirm(
          _INTL("Release {1} Pokemon?", entries.length), :serious => true
        )
        box = entries.first[0][0]
        @storage.pbDeleteMulti(box, entries.map { |entry| entry[0][1] })
        pbPlayDecisionSE rescue nil
        KantoReloaded.toast_success(_INTL("The Pokemon were released."))
        refresh_all
        true
      end

      def place_held_group
        return unless @held_group && !@held_group.empty?
        target = current_location
        return if target[0] == :header
        if target[0] == -1
          if @storage.party.length + @held_group.length > party_capacity
            pbPlayBuzzerSE rescue nil
            KantoReloaded.toast_warning(_INTL("Your party is full!"))
            return
          end
          @held_group.each do |entry|
            @storage.party << entry[:pokemon]
          end
        else
          destinations = held_group_destinations(target[1])
          unless destinations
            pbPlayBuzzerSE rescue nil
            KantoReloaded.toast_warning(_INTL("Can't place that there."))
            return
          end
          if @held_group.any? { |entry| pokemon_has_mail?(entry[:pokemon]) }
            pbPlayBuzzerSE rescue nil
            KantoReloaded.toast_warning(_INTL("Please remove the Mail."))
            return
          end
          @held_group.each_with_index do |entry, index|
            prepare_for_box(entry[:pokemon])
            @storage[target[0], destinations[index]] = entry[:pokemon]
          end
        end
        @held_group = nil
        pbPlayDecisionSE rescue nil
        refresh_all
      end

      def held_group_destinations(target_index)
        count = @held_group ? @held_group.length : 0
        capacity = box_capacity
        return nil if count <= 0 || capacity <= 0
        start = [[target_index.to_i, 0].max, capacity - 1].min
        order = (start...capacity).to_a + (0...start).to_a
        destinations = order.select do |index|
          !@storage[@storage.currentBox, index]
        end
        return nil if destinations.length < count
        destinations.first(count)
      end

      def arrange_held_group(entries)
        entries.sort_by! { |entry| entry[:source][1].to_i }
        count = entries.length
        max_width = SCREEN_W - HELD_SPRITE_SIZE - 16
        spacing = if count > 1
                    [HELD_GROUP_SPACING,
                     max_width.to_f / (count - 1)].min
                  else
                    0
                  end
        start_x = -(spacing * (count - 1) / 2.0)
        entries.each_with_index do |entry, index|
          entry[:visual_x] = (start_x + spacing * index).round
          entry[:visual_y] = 0
        end
      end

      def held_group_origin(position)
        offsets = @held_group.map { |entry| entry[:visual_x].to_i }
        half_width = HELD_SPRITE_SIZE / 2
        minimum_x = half_width - offsets.min
        maximum_x = SCREEN_W - half_width - offsets.max
        x = [[position[0], minimum_x].max, maximum_x].min
        [x, position[1]]
      rescue StandardError
        position
      end

      def pick_up
        pokemon = focused_pokemon
        return unless pokemon
        if @focus == :party && able?(pokemon) && able_party_count <= 1
          pbPlayBuzzerSE rescue nil
          KantoReloaded.toast_warning(_INTL("That's your last Pokemon!"))
          return
        end
        origin = focused_cell_center
        pbSEPlay("GUI storage pick up") rescue nil
        @held_pokemon = pokemon
        source = current_location
        @storage.pbDelete(source[0], source[1])
        @held_source = source.dup
        @party_index = [@party_index, party_capacity - 1].min
        refresh_all
        update_carry_visual(true)
        animate_pickup(origin)
      end

      def place_or_swap
        target = current_location
        return if target[0] == :header
        box, index = target
        target_pokemon = @storage[box, index]
        if box >= 0 && @held_pokemon.respond_to?(:mail) && @held_pokemon.mail
          pbPlayBuzzerSE rescue nil
          KantoReloaded.toast_warning(_INTL("Please remove the Mail."))
          return
        end
        if box == -1 && target_pokemon && able?(target_pokemon) &&
            able_party_count <= 1 && !able?(@held_pokemon)
          pbPlayBuzzerSE rescue nil
          KantoReloaded.toast_warning(_INTL("That's your last Pokemon!"))
          return
        end
        if box == -1 && !target_pokemon && @storage.party_full?
          pbPlayBuzzerSE rescue nil
          KantoReloaded.toast_warning(_INTL("Your party is full!"))
          return
        end
        pbSEPlay(target_pokemon ? "GUI storage pick up" :
                   "GUI storage put down") rescue nil
        animate_drop_to(focused_cell_center)
        prepare_for_box(@held_pokemon) if box >= 0
        @storage[box, index] = @held_pokemon
        @storage.party.compact! if box == -1
        @held_pokemon = target_pokemon
        @held_source = target_pokemon ? target.dup : nil
        refresh_all
        update_carry_visual(true)
      end

      def animate_pickup(origin)
        frames = action_animation_frames
        sprite = @drag_visual.sprite
        return unless frames > 0 && sprite && origin
        target_x = sprite.x
        target_y = sprite.y
        sprite.x = origin[0]
        sprite.y = origin[1]
        frames.times do |index|
          progress = ease_out((index + 1).to_f / frames)
          sprite.x = origin[0] + ((target_x - origin[0]) * progress)
          sprite.y = origin[1] + ((target_y - origin[1]) * progress)
          Graphics.update
          Input.update
          sprite.update rescue nil
        end
        sprite.x = target_x
        sprite.y = target_y
      rescue StandardError => e
        KantoReloaded::Log.exception(
          "Reloaded PC pickup animation failed", e,
          :channel => :pc_organization
        ) if defined?(KantoReloaded::Log)
      end

      def animate_drop_to(target)
        frames = action_animation_frames
        sprite = @drag_visual.sprite
        return unless frames > 0 && sprite && target
        start_x = sprite.x
        start_y = sprite.y
        frames.times do |index|
          progress = ease_out((index + 1).to_f / frames)
          sprite.x = start_x + ((target[0] - start_x) * progress)
          sprite.y = start_y + ((target[1] - start_y) * progress)
          Graphics.update
          Input.update
          sprite.update rescue nil
        end
        sprite.x = target[0]
        sprite.y = target[1]
      rescue StandardError => e
        KantoReloaded::Log.exception(
          "Reloaded PC drop animation failed", e,
          :channel => :pc_organization
        ) if defined?(KantoReloaded::Log)
      end

      def prepare_for_box(pokemon)
        return unless pokemon
        pokemon.time_form_set = nil if pokemon.respond_to?(:time_form_set=)
        if pokemon.respond_to?(:isSpecies?) && pokemon.isSpecies?(:SHAYMIN) &&
            pokemon.respond_to?(:form=)
          pokemon.form = 0
        end
        pokemon.heal if defined?($game_temp) && $game_temp &&
          !$game_temp.fromkurayshop
      rescue StandardError
        nil
      end

      def show_summary
        return if @focus == :header
        pokemon = @held_pokemon || focused_pokemon
        unless pokemon
          pbPlayBuzzerSE rescue nil
          return
        end
        list, index = summary_list_and_index(pokemon)
        sprites = sprite_hash
        old_sprites = pbFadeOutAndHide(sprites)
        begin
          scene = PokemonSummary_Scene.new
          screen = PokemonSummaryScreen.new(scene)
          result = screen.pbStartScreen(list, index)
          apply_summary_index(result, list)
        ensure
          pbFadeInAndShow(sprites, old_sprites)
        end
        refresh_all
      end

      def summary_list_and_index(pokemon)
        if @held_pokemon
          [[pokemon], 0]
        elsif @focus == :party
          [@storage.party, @party_index]
        else
          [current_box, @box_index]
        end
      end

      def apply_summary_index(result, list)
        return unless result.respond_to?(:to_i)
        index = result.to_i
        return if index < 0 || index >= list.length
        if @focus == :party
          @party_index = index
          ensure_party_visible
        elsif @focus == :box
          @box_index = index
          ensure_box_visible
        end
      end

      def choose_box
        return if carrying?
        rows = @storage.boxes.each_with_index.map do |box, index|
          count = box.nitems rescue box.compact.length
          {
            :label => _INTL("{1}  ({2}/{3})", box.name, count, box.length),
            :value => index
          }
        end
        selected = KantoReloaded::PopupWindow.choice(
          _INTL("Choose a Box"), rows,
          :start_index => @storage.currentBox
        )
        return unless selected.is_a?(Integer)
        amount = selected - @storage.currentBox
        change_box(amount) unless amount == 0
      end

      def close_or_warn
        if @fusion_item
          kr_cancel_fusion
          return
        end
        if @cursor_mode == :multiselect && !@multi_selected.empty?
          clear_multi_selection
          pbPlayCancelSE rescue nil
          redraw_selection
          return
        end
        if carrying?
          pbPlayBuzzerSE rescue nil
          KantoReloaded.toast_warning(
            _INTL("Place the Pokemon before leaving the PC.")
          )
          return
        end
        return unless KantoReloaded::PopupWindow.confirm(
          _INTL("Exit from the PC?"), :default => true
        )
        pbSEPlay("PC close") rescue nil
        @closed = true
      end

      def focus_triggered?
        trigger?(:JUMPUP)
      end

      def previous_box_triggered?
        trigger?(:L)
      end

      def next_box_triggered?
        trigger?(:R)
      end

      def trigger?(name)
        KantoReloaded::UI::InputRouter.input_triggered?(name)
      rescue StandardError
        false
      end

      def current_location
        return [:header, 0] if @focus == :header
        return [-1, @party_index] if @focus == :party
        [@storage.currentBox, @box_index]
      end

      def focused_pokemon
        location = current_location
        return nil if location[0] == :header
        @storage[location[0], location[1]]
      rescue StandardError
        nil
      end

      def held_group_pokemon
        entry = @held_group && @held_group.first
        entry && entry[:pokemon]
      rescue StandardError
        nil
      end

      def held_source?(kind, index)
        source = @drag_source || @held_source
        return false unless source
        box = kind == :party ? -1 : @storage.currentBox
        source[0] == box && source[1] == index
      end

      def storage_pokemon(location)
        @storage[location[0], location[1]]
      rescue StandardError
        nil
      end

      def pokemon_has_mail?(pokemon)
        pokemon && pokemon.respond_to?(:mail) && pokemon.mail
      rescue StandardError
        false
      end

      def mouse_pressed?(name)
        return false unless defined?(Input) && Input.const_defined?(name)
        Input.press?(Input.const_get(name))
      rescue StandardError
        false
      end

      def carrying?
        !!(@drag_pokemon || @held_pokemon ||
           (@held_group && !@held_group.empty?))
      end

      def able?(pokemon)
        pokemon && !pokemon.egg? && pokemon.hp.to_i > 0
      rescue StandardError
        false
      end

      def able_party_count
        @storage.party.count { |pokemon| able?(pokemon) }
      end

      def current_box
        @storage.boxes[@storage.currentBox]
      end

      def box_pokemon
        current_box.respond_to?(:pokemon) ? current_box.pokemon : current_box
      end

      def box_capacity
        @storage.maxPokemon(@storage.currentBox)
      end

      def box_total_rows
        (box_capacity.to_f / BOX_COLUMNS).ceil
      end

      def visible_box_start
        @scroll_row * BOX_COLUMNS
      end

      def party_capacity
        configured = @storage.maxPokemon(-1) rescue ::Settings::MAX_PARTY_SIZE
        [configured.to_i, @storage.party.length,
         PARTY_VISIBLE_SLOTS].max
      end

      def visible_party_start
        @party_scroll
      end

      def ensure_box_visible
        row = @box_index / BOX_COLUMNS
        @scroll_row = row if row < @scroll_row
        if row >= @scroll_row + BOX_VISIBLE_ROWS
          @scroll_row = row - BOX_VISIBLE_ROWS + 1
        end
        max_scroll = [box_total_rows - BOX_VISIBLE_ROWS, 0].max
        @scroll_row = [[@scroll_row, 0].max, max_scroll].min
      end

      def ensure_party_visible
        @party_scroll = @party_index if @party_index < @party_scroll
        if @party_index >= @party_scroll + PARTY_VISIBLE_SLOTS
          @party_scroll = @party_index - PARTY_VISIBLE_SLOTS + 1
        end
        max_scroll = [party_capacity - PARTY_VISIBLE_SLOTS, 0].max
        @party_scroll = [[@party_scroll.to_i, 0].max, max_scroll].min
      end

      def normalize_selection
        @storage.currentBox = [[@storage.currentBox.to_i, 0].max,
                               @storage.maxBoxes - 1].min
        @box_index = [[@box_index.to_i, 0].max, box_capacity - 1].min
        @party_index = [[@party_index.to_i, 0].max,
                        party_capacity - 1].min
        @focus = :box if carrying? && @focus == :header
        ensure_box_visible
        ensure_party_visible
      end

      def box_cell_position(local)
        column = local % BOX_COLUMNS
        row = local / BOX_COLUMNS
        [BOX_GRID_X + column * BOX_CELL_W,
         BOX_GRID_Y + row * BOX_CELL_H]
      end

      def party_cell_position(local)
        [PARTY_GRID_X + local * PARTY_CELL_W, PARTY_GRID_Y]
      end

      def type_text(pokemon)
        pokemon.types.map { |type| GameData::Type.get(type).name }.join("/")
      rescue StandardError
        "-"
      end

      def gender_text(pokemon)
        return _INTL("Male") if pokemon.gender.to_i == 0
        return _INTL("Female") if pokemon.gender.to_i == 1
        _INTL("None")
      rescue StandardError
        "-"
      end

      def hp_text(pokemon)
        _INTL("{1}/{2}", pokemon.hp.to_i, pokemon.totalhp.to_i)
      rescue StandardError
        "-"
      end

      def item_text(pokemon)
        item = pokemon.item
        item ? item.name.to_s : _INTL("None")
      rescue StandardError
        _INTL("None")
      end

      def nature_text(pokemon)
        nature = pokemon.nature
        nature ? nature.name.to_s : "-"
      rescue StandardError
        "-"
      end

      def sprite_hash
        result = { "canvas" => @canvas, "cursor" => @cursor_layer }
        (@box_visuals + @party_visuals).each_with_index do |visual, index|
          result["pokemon_#{index}"] = visual.sprite if visual.sprite
        end
        @held_group_visuals.each_with_index do |visual, index|
          result["held_group_#{index}"] = visual.sprite if visual.sprite
        end
        result["dragged_pokemon"] = @drag_visual.sprite if @drag_visual &&
          @drag_visual.sprite
        result["detail_pokemon"] = @detail_visual.sprite if @detail_visual &&
          @detail_visual.sprite
        result
      end

      def dispose
        (@box_visuals + @party_visuals + @held_group_visuals).each do |visual|
          visual.dispose
        end
        @drag_visual.dispose if @drag_visual
        @detail_visual.dispose if @detail_visual
        @detail_images.each_value do |image|
          image.dispose if image && image.respond_to?(:dispose)
        end
        @type_bitmap.dispose if @type_bitmap &&
          @type_bitmap.respond_to?(:dispose)
        @box_background.dispose if @box_background &&
          @box_background.respond_to?(:dispose)
        if @canvas
          @canvas.bitmap.dispose if @canvas.bitmap && !@canvas.bitmap.disposed?
          @canvas.dispose unless @canvas.disposed?
        end
        if @cursor_layer
          if @cursor_layer.bitmap && !@cursor_layer.bitmap.disposed?
            @cursor_layer.bitmap.dispose
          end
          @cursor_layer.dispose unless @cursor_layer.disposed?
        end
        @viewport.dispose if @viewport && !@viewport.disposed?
        Graphics.update if defined?(Graphics)
      rescue StandardError
        nil
      end
    end
  end
end
