#==============================================================================
# Kanto Reloaded TM Vault UI
#==============================================================================
# Hoenn Reloaded TM Vault layout adapted to KR shared input and popup APIs.
#==============================================================================

module KantoReloaded
  module TMVault
    SCREEN_W = 512
    SCREEN_H = 384

    BG_COLOR = Color.new(10, 20, 40, 255)
    PANEL_BG = Color.new(18, 32, 62)
    PANEL_BORDER = Color.new(50, 90, 160)
    TITLE_BG = Color.new(12, 24, 50)
    FOOTER_BG = Color.new(12, 24, 50)
    WHITE = Color.new(255, 255, 255)
    GRAY = Color.new(180, 180, 180)
    DIM = Color.new(120, 120, 140)
    SHADOW = Color.new(10, 15, 30)
    COLOR_COMPAT = Color.new(120, 230, 120)
    COLOR_KNOWS = Color.new(120, 200, 255)
    COLOR_CANT = Color.new(200, 60, 60)
    COLOR_GOLD = Color.new(240, 220, 80)
    ROW_NORM = Color.new(255, 255, 255, 8)

    TITLE_H = 36
    FOOTER_H = 28
    LEFT_W = 220
    RIGHT_W = SCREEN_W - LEFT_W - 16
    CONT_Y = TITLE_H + 2
    CONT_H = SCREEN_H - TITLE_H - FOOTER_H - 4
    ROW_H = 20

    PARTY_COLS = 3
    PARTY_X0 = 18
    PARTY_Y0 = 14
    PARTY_X_GAP = 88
    PARTY_Y_GAP = 100
    PARTY_ICO_W = 64
    PARTY_ICO_H = 64

    class PartyIconSprite < PokemonIconSprite
      def use_big_icon?
        false
      end
    end

    class Scene
      def main
        setup
        while @running
          Graphics.update
          Input.update
          @party_icons.compact.each { |icon| icon.update rescue nil }
          @cursor_tick = (@cursor_tick + 1) % 40
          draw_left if @focus == :list && (@cursor_tick % 2).zero?
          draw_footer if (@cursor_tick % 2).zero?
          handle_input
        end
      ensure
        teardown
      end

      private

      def setup
        @running = true
        @sel = 0
        @scroll = 0
        @filter_mon = nil
        @move_mode = :vault
        @relearn_mon = nil
        @pending_relearn_pick = false
        @focus = :list
        @party_sel = first_party_index
        @cursor_tick = 0
        @list_memory = {}
        @party_icons = []
        @relearn_egg_moves = []

        @viewport = Viewport.new(0, 0, SCREEN_W, SCREEN_H)
        @viewport.z = 100_000
        @background = Sprite.new(@viewport)
        @background.bitmap = Bitmap.new(SCREEN_W, SCREEN_H)
        @background.bitmap.fill_rect(0, 0, SCREEN_W, SCREEN_H, BG_COLOR)

        @title_sprite = BitmapSprite.new(SCREEN_W, TITLE_H, @viewport)
        @left_sprite = BitmapSprite.new(LEFT_W, CONT_H, @viewport)
        @right_sprite = BitmapSprite.new(RIGHT_W, CONT_H, @viewport)
        @footer_sprite = BitmapSprite.new(SCREEN_W, FOOTER_H, @viewport)
        @left_sprite.x = 4
        @left_sprite.y = CONT_Y
        @right_sprite.x = LEFT_W + 12
        @right_sprite.y = CONT_Y
        @footer_sprite.y = SCREEN_H - FOOTER_H
        create_party_icons
        build_list
        draw_all
      end

      def teardown
        @party_icons.compact.each { |icon| icon.dispose rescue nil }
        [@footer_sprite, @right_sprite, @left_sprite, @title_sprite, @background].compact.each do |sprite|
          sprite.bitmap.dispose rescue nil
          sprite.dispose rescue nil
        end
        @viewport.dispose rescue nil
      end

      def party
        return [] unless defined?($Trainer) && $Trainer
        Array($Trainer.party)
      end

      def first_party_index
        party.empty? ? 0 : 0
      end

      def create_party_icons
        @party_icons.compact.each { |icon| icon.dispose rescue nil }
        @party_icons = Array.new(6) do |index|
          pokemon = party[index]
          next nil unless pokemon
          col = index % PARTY_COLS
          row = index / PARTY_COLS
          extra_y = row == 1 ? 10 : 0
          icon = PartyIconSprite.new(pokemon, @viewport)
          icon.setOffset(PictureOrigin::Center)
          icon.x = @right_sprite.x + PARTY_X0 + col * PARTY_X_GAP + PARTY_ICO_W / 2
          icon.y = CONT_Y + PARTY_Y0 + row * PARTY_Y_GAP + PARTY_ICO_H / 2 + extra_y
          icon.z = 20
          icon
        end
      end

      def build_list
        remember_list_position
        filter = @filter_mon.nil? ? nil : party[@filter_mon]
        if @move_mode == :relearn
          pokemon = party[@relearn_mon]
          @relearn_egg_moves = TMVault.egg_move_ids_for(pokemon)
          full = sorted_move_ids(TMVault.relearnable_moves(pokemon), pokemon)
        else
          @relearn_egg_moves = []
          full = sorted_vault_moves(filter)
        end
        @list = if filter
                  full.select { |move_id| filter.hasMove?(move_id) || filter.compatible_with_move?(move_id) }
                else
                  full
                end
        @current_list_key = list_key
        restore_list_position
      end

      def sorted_vault_moves(pokemon = nil)
        sorted_move_ids(TMVault.vault, pokemon)
      end

      def sorted_move_ids(move_ids, pokemon = nil)
        original = Array(move_ids)
        indexed = []
        original.each_with_index { |move_id, index| indexed << [move_id, index] }
        indexed.sort_by do |entry|
          move_id = entry[0]
          original_index = entry[1]
          move = GameData::Move.try_get(move_id)
          name = move ? move.name.to_s.downcase : move_id.to_s.downcase
          case TMVault.sort_mode
          when 1
            type_name = move ? (GameData::Type.get(move.type).name rescue "ZZZ") : "ZZZ"
            [type_name.to_s.downcase, name]
          when 2
            [move ? move.category.to_i : 99, name]
          when 3
            [-original_index]
          when 4
            level = TMVault.level_learned_for(pokemon, move_id)
            egg_move = TMVault.egg_move?(pokemon, move_id)
            tier = egg_move ? 2 : (level.nil? ? 1 : 0)
            [tier, level || 0, name]
          else
            [name]
          end
        end.map { |entry| entry[0] }
      rescue
        original || []
      end

      def list_key
        [@move_mode, @filter_mon, @relearn_mon]
      end

      def remember_list_position
        return unless @list && !@list.empty?
        key = @current_list_key || list_key
        @list_memory[key] = { :move => @list[@sel], :scroll => @scroll }
      end

      def restore_list_position
        memory = @list_memory[list_key] || {}
        remembered_index = @list.index(memory[:move]) if memory[:move]
        @sel = remembered_index || 0
        @scroll = memory[:scroll].to_i
        clamp_selection
      end

      def rows_per_page
        (CONT_H / ROW_H).floor
      end

      def clamp_selection
        if @list.empty?
          @sel = 0
          @scroll = 0
          return
        end
        @sel = [[@sel, 0].max, @list.length - 1].min
        @scroll = @sel if @sel < @scroll
        @scroll = @sel - rows_per_page + 1 if @sel >= @scroll + rows_per_page
        max_scroll = [@list.length - rows_per_page, 0].max
        @scroll = [[@scroll, 0].max, max_scroll].min
      end

      def selected_move_id
        @list[@sel]
      end

      def active_filter_pokemon
        @filter_mon.nil? ? nil : party[@filter_mon]
      end

      def draw_all
        draw_title
        draw_left
        draw_right
        draw_footer
      end

      def draw_title
        bitmap = @title_sprite.bitmap
        bitmap.clear
        bitmap.fill_rect(0, 0, SCREEN_W, TITLE_H, TITLE_BG)
        pbSetSystemFont(bitmap)
        bitmap.font.size = 32
        title_width = bitmap.text_size("TM Vault").width
        title_x = (SCREEN_W - title_width) / 2
        pbDrawShadowText(bitmap, title_x, 5, title_width, TITLE_H, "TM Vault", WHITE, SHADOW)
        if @move_mode == :relearn
          bitmap.font.size = 16
          pokemon = party[@relearn_mon]
          label = pokemon ? "RELEARN: #{pokemon.name}" : "RELEARN"
          pbDrawShadowText(bitmap, title_x - 170, 20, 160, 20, label, COLOR_GOLD, SHADOW, 1)
        elsif !@filter_mon.nil? || @focus == :filter
          bitmap.font.size = 16
          pbDrawShadowText(bitmap, title_x - 160, 20, 140, 20, "FILTERING...", COLOR_GOLD, SHADOW, 1)
        end
        count = (!@filter_mon.nil? || @move_mode == :relearn) ? @list.length : TMVault.vault.length
        bitmap.font.size = 13
        pbDrawShadowText(bitmap, SCREEN_W - 18, 2, -1, TITLE_H - 4, count.to_s, DIM, SHADOW, 1)
      end

      def draw_left
        bitmap = @left_sprite.bitmap
        bitmap.clear
        draw_panel(bitmap, LEFT_W, CONT_H)
        pbSetSmallFont(bitmap)
        if @list.empty?
          empty_list_message.split("\n").each_with_index do |line, index|
            pbDrawShadowText(bitmap, 8, CONT_H / 2 - 16 + index * 18, LEFT_W - 16, 18, line, DIM, SHADOW, 2)
          end
          return
        end
        filter = active_filter_pokemon
        @list.each_with_index do |move_id, index|
          next if index < @scroll
          break if index >= @scroll + rows_per_page
          row_y = (index - @scroll) * ROW_H
          if index == @sel
            pulse = (Math.sin(@cursor_tick * Math::PI / 20.0) * 17.5 + 37.5).to_i
            bitmap.fill_rect(2, row_y + 3, LEFT_W - 4, ROW_H - 1, Color.new(255, 255, 255, pulse))
          else
            bitmap.fill_rect(2, row_y + 3, LEFT_W - 4, ROW_H - 1, ROW_NORM)
          end
          move = GameData::Move.try_get(move_id)
          name = move ? move.name : move_id.to_s
          color = move_color(move_id, move, filter)
          pbSetSmallFont(bitmap)
          max_name_width = LEFT_W - 84
          bitmap.font.size -= 2 if bitmap.text_size(name).width > max_name_width
          pbDrawShadowText(bitmap, 10, row_y, max_name_width, ROW_H, name, color, SHADOW)
          type_x = LEFT_W - 38
          draw_egg_icon(bitmap, type_x - 16, row_y + 5) if relearn_egg_move?(move_id)
          draw_type_icon(bitmap, move, type_x, row_y + 5) if move
        end
      end

      def draw_right
        bitmap = @right_sprite.bitmap
        bitmap.clear
        draw_panel(bitmap, RIGHT_W, CONT_H)
        pbSetSmallFont(bitmap)
        move_id = selected_move_id
        party.first(6).each_with_index do |pokemon, index|
          next unless pokemon
          col = index % PARTY_COLS
          row = index / PARTY_COLS
          extra_y = row == 1 ? 10 : 0
          icon_x = PARTY_X0 + col * PARTY_X_GAP
          icon_y = PARTY_Y0 + row * PARTY_Y_GAP + extra_y
          box_x = icon_x - 6
          box_y = icon_y - 1
          box_w = PARTY_ICO_W + 20
          box_h = PARTY_ICO_H + 40
          relearn_selected = @move_mode == :relearn && @relearn_mon == index
          if [:party, :filter].include?(@focus) && @party_sel == index
            color = (@focus == :filter || @move_mode == :relearn) ? Color.new(240, 200, 60, 70) : Color.new(255, 255, 255, 55)
            bitmap.fill_rect(box_x, box_y, box_w, box_h, color)
          elsif @filter_mon == index || relearn_selected
            bitmap.fill_rect(box_x, box_y, box_w, box_h, Color.new(240, 220, 80, 45))
          end
          draw_party_name(bitmap, pokemon, box_x, icon_y, box_w)
          draw_compatibility(bitmap, pokemon, index, move_id, icon_x, icon_y) if move_id
        end
        draw_move_information(bitmap, move_id)
      end

      def draw_party_name(bitmap, pokemon, box_x, icon_y, box_w)
        pbSetSmallFont(bitmap)
        max_width = box_w - 4
        size = [24, 22, 20, 18, 16, 14, 12, 10].find do |candidate|
          bitmap.font.size = candidate
          bitmap.text_size(pokemon.name).width <= max_width
        end || 10
        bitmap.font.size = size
        name_width = bitmap.text_size(pokemon.name).width
        name_x = box_x + (box_w - name_width) / 2
        pbDrawShadowText(bitmap, name_x, icon_y + PARTY_ICO_H + 1, name_width + 2, 14, pokemon.name, WHITE, SHADOW)
      end

      def draw_compatibility(bitmap, pokemon, index, move_id, icon_x, icon_y)
        status = if @move_mode == :relearn && @relearn_mon == index && !pokemon.hasMove?(move_id)
                   :compat
                 else
                   TMVault.compat(move_id, pokemon)
                 end
        label, color = case status
                       when :knows then ["LEARNED", COLOR_KNOWS]
                       when :compat then ["LEARNABLE", COLOR_COMPAT]
                       else ["CAN'T LEARN", COLOR_CANT]
                       end
        bitmap.font.size = 13
        label_width = bitmap.text_size(label).width
        label_x = icon_x + PARTY_ICO_W / 2 - label_width / 2 + 3
        pbDrawShadowText(bitmap, label_x, icon_y + PARTY_ICO_H + 22, label_width + 2, 14, label, color, SHADOW)
      end

      def draw_move_information(bitmap, move_id)
        move = GameData::Move.try_get(move_id) rescue nil
        return unless move
        info_y = PARTY_Y0 + PARTY_Y_GAP + PARTY_ICO_H + 60
        bitmap.fill_rect(8, info_y - 2, RIGHT_W - 16, 1, PANEL_BORDER)
        bitmap.font.size = 12
        category_color = move.category == 0 ? Color.new(220, 60, 60) :
                         move.category == 1 ? Color.new(100, 180, 255) : Color.new(240, 210, 60)
        category_name = ["Physical", "Special", "Status"][move.category] || "???"
        power = move.base_damage <= 1 ? (move.base_damage == 1 ? "???" : "---") : move.base_damage.to_s
        accuracy = move.accuracy == 0 ? "---" : "#{move.accuracy}%"
        pbDrawShadowText(bitmap, 10, info_y, RIGHT_W - 20, 15, move.name, WHITE, SHADOW)
        context_pokemon = @focus == :party ? party[@party_sel] : active_filter_pokemon
        if context_pokemon && [context_pokemon.type1, context_pokemon.type2].compact.uniq.include?(move.type)
          bitmap.font.size = 14
          badge_width = bitmap.text_size("STAB").width + 4
          pbDrawShadowText(bitmap, RIGHT_W - badge_width - 6, info_y, badge_width, 14, "STAB", COLOR_CANT, SHADOW)
        end
        bitmap.font.size = 12
        pbDrawShadowText(bitmap, 10, info_y + 15, 70, 14, category_name, category_color, SHADOW)
        stats = "Power: #{power}   Accuracy: #{accuracy}   PP: #{move.total_pp}"
        stats_x = 10 + bitmap.text_size(category_name).width + 8
        pbDrawShadowText(bitmap, stats_x, info_y + 15, RIGHT_W - stats_x - 6, 14, stats, GRAY, SHADOW)
        draw_wrapped_description(bitmap, move.description.to_s, 10, info_y + 32, RIGHT_W - 20)
      end

      def draw_wrapped_description(bitmap, text, x, y, width)
        line = ""
        text.split(" ").each do |word|
          candidate = line.empty? ? word : "#{line} #{word}"
          if !line.empty? && bitmap.text_size(candidate).width > width
            pbDrawShadowText(bitmap, x, y, width, 14, line, DIM, SHADOW)
            y += 13
            line = word
          else
            line = candidate
          end
        end
        pbDrawShadowText(bitmap, x, y, width, 14, line, DIM, SHADOW) unless line.empty?
      end

      def draw_footer
        bitmap = @footer_sprite.bitmap
        bitmap.clear
        bitmap.fill_rect(0, 0, SCREEN_W, FOOTER_H, FOOTER_BG)
        KantoReloaded::HintText.draw_footer(
          bitmap, hint_entries, 8, 8, SCREEN_W - 16,
          :size => 16,
          :color => WHITE,
          :height => FOOTER_H,
          :y_offset => -5,
          :statuses => hint_statuses,
          :hint_entry => KantoReloaded::HintText.special("Controls")
        )
      rescue
        nil
      end

      def hint_entries
        if @focus == :party
          return [KantoReloaded::HintText.confirm("Teach"), KantoReloaded::HintText.back("Cancel")]
        end
        if @focus == :filter
          label = @pending_relearn_pick ? "Pick Pokemon" : "Pick Filter"
          entries = [KantoReloaded::HintText.confirm(label), KantoReloaded::HintText.back("Cancel")]
          entries << KantoReloaded::HintText.action("Clear Filter") unless @pending_relearn_pick
          return entries
        end
        filter_label = @filter_mon.nil? ? "Filter" : "Clear Filter"
        relearn_label = @move_mode == :relearn ? "Vault Moves" : "Relearn Moves"
        [
          KantoReloaded::HintText.confirm("Select"),
          KantoReloaded::HintText.back,
          KantoReloaded::HintText.action(filter_label),
          KantoReloaded::HintText.other(relearn_label, :sort),
          KantoReloaded::HintText.other("Sort", :quick)
        ]
      end

      def hint_statuses
        statuses = []
        statuses << KantoReloaded::HintText.status(
          "Sort: #{TMVault::SORT_NAMES[TMVault.sort_mode]}", COLOR_KNOWS
        ) if @focus == :list
        statuses << KantoReloaded::HintText.status("Relearn Mode", COLOR_COMPAT) if @move_mode == :relearn
        statuses
      rescue
        []
      end

      def open_hint_popup
        KantoReloaded::HintText.open_popup(
          "Controls", hint_entries, :statuses => hint_statuses
        )
        drain_list_input
      end

      def handle_input
        if KantoReloaded::HintText.triggered? || hint_footer_clicked?
          open_hint_popup
          draw_footer
          return
        end
        case @focus
        when :party then handle_party_input
        when :filter then handle_filter_input
        else handle_list_input
        end
      end

      def handle_list_input
        mouse_index = update_list_mouse
        if mouse_index && KantoReloaded::MouseInput.mouse_triggered?
          activate_selected_move
          return
        end
        wheel = KantoReloaded::MouseInput.wheel_delta
        if mouse_index && wheel != 0
          move_selection(wheel < 0 ? 1 : -1)
        elsif Input.repeat?(Input::UP)
          move_selection(-1)
        elsif Input.repeat?(Input::DOWN)
          move_selection(1)
        elsif Input.repeat?(Input::LEFT)
          move_selection(-3)
        elsif Input.repeat?(Input::RIGHT)
          move_selection(3)
        elsif Input.trigger?(Input::BACK)
          pbPlayCloseMenuSE rescue nil
          if @move_mode == :relearn || !@filter_mon.nil? || @pending_relearn_pick
            return_to_main_vault
          else
            @running = false
          end
        elsif Input.trigger?(Input::USE)
          activate_selected_move
        elsif Input.trigger?(Input::ACTION)
          toggle_filter
        elsif Input.trigger?(Input::L)
          toggle_relearn_mode
        elsif Input.trigger?(Input::R)
          cycle_sort
        end
      end

      def update_list_mouse
        position = KantoReloaded::MouseInput.active_position
        return nil unless position
        x = position[0].to_i
        y = position[1].to_i
        return nil unless x.between?(@left_sprite.x, @left_sprite.x + LEFT_W - 1)
        return nil unless y.between?(CONT_Y, CONT_Y + CONT_H - 1)
        index = @scroll + ((y - CONT_Y) / ROW_H)
        return nil unless index < @list.length
        if @sel != index
          @sel = index
          clamp_selection
          pbPlayCursorSE rescue nil
          draw_left
          draw_right
        end
        index
      end

      def move_selection(amount)
        return if @list.empty?
        old = @sel
        if amount.abs == 1
          @sel = (@sel + amount) % @list.length
        else
          @sel = [[@sel + amount, 0].max, @list.length - 1].min
        end
        return if old == @sel
        clamp_selection
        pbPlayCursorSE rescue nil
        draw_left
        draw_right
      end

      def activate_selected_move
        return if @list.empty?
        pbPlayDecisionSE rescue nil
        if @move_mode == :relearn && !@relearn_mon.nil?
          @party_sel = @relearn_mon
          teach_to_selected_pokemon
        else
          @focus = :party
          @party_sel = first_party_index
          draw_right
          draw_footer
        end
      end

      def handle_filter_input
        if move_party_selection
          draw_right
        elsif Input.trigger?(Input::USE)
          confirm_filter_selection
        elsif Input.trigger?(Input::ACTION) && !@pending_relearn_pick
          @filter_mon = nil
          @focus = :list
          build_list
          draw_all
          drain_list_input
        elsif Input.trigger?(Input::BACK)
          pbPlayCloseMenuSE rescue nil
          @pending_relearn_pick = false
          @focus = :list
          draw_right
          draw_footer
          drain_list_input
        end
      end

      def confirm_filter_selection
        return if party.empty?
        pbPlayDecisionSE rescue nil
        if @pending_relearn_pick
          pokemon = party[@party_sel]
          if pokemon && (pokemon.egg? || pokemon.shadowPokemon?)
            KantoReloaded.message("That Pokemon cannot relearn moves.", :theme => :warning)
            return
          end
          @pending_relearn_pick = false
          @move_mode = :relearn
          @relearn_mon = @party_sel
          @filter_mon = nil
        else
          @filter_mon = (@filter_mon == @party_sel) ? nil : @party_sel
        end
        @focus = :list
        build_list
        draw_all
        drain_list_input
      end

      def handle_party_input
        if move_party_selection
          draw_right
        elsif Input.trigger?(Input::USE)
          teach_to_selected_pokemon
        elsif Input.trigger?(Input::BACK)
          pbPlayCloseMenuSE rescue nil
          @focus = :list
          draw_right
          draw_footer
          drain_list_input
        end
      end

      def move_party_selection
        return false if party.empty?
        new_index = nil
        if Input.repeat?(Input::UP)
          new_index = @party_sel - PARTY_COLS
        elsif Input.repeat?(Input::DOWN)
          new_index = @party_sel + PARTY_COLS
        elsif Input.repeat?(Input::LEFT)
          new_index = @party_sel - 1
        elsif Input.repeat?(Input::RIGHT)
          new_index = @party_sel + 1
        end
        return false unless new_index && new_index >= 0 && new_index < party.length
        @party_sel = new_index
        pbPlayCursorSE rescue nil
        true
      end

      def toggle_filter
        if !@filter_mon.nil?
          pbPlayCloseMenuSE rescue nil
          @filter_mon = nil
          build_list
          draw_all
        elsif party.empty?
          KantoReloaded.message("There are no Pokemon in the party.", :theme => :warning)
        else
          @focus = :filter
          @party_sel = first_party_index
          @pending_relearn_pick = false
          draw_all
        end
      end

      def toggle_relearn_mode
        if @move_mode == :relearn
          return_to_main_vault
        elsif party.empty?
          KantoReloaded.message("There are no Pokemon in the party.", :theme => :warning)
        else
          @focus = :filter
          @party_sel = first_party_index
          @pending_relearn_pick = true
          pbPlayCursorSE rescue nil
          draw_all
        end
      end

      def cycle_sort
        TMVault.sort_mode = (TMVault.sort_mode + 1) % TMVault::SORT_NAMES.length
        build_list
        pbPlayCursorSE rescue nil
        draw_left
        draw_footer
      end

      def return_to_main_vault
        @move_mode = :vault
        @relearn_mon = nil
        @filter_mon = nil
        @pending_relearn_pick = false
        @focus = :list
        build_list
        draw_all
        drain_list_input
      end

      def teach_to_selected_pokemon
        move_id = selected_move_id
        move = GameData::Move.try_get(move_id) rescue nil
        pokemon = party[@party_sel]
        return unless move && pokemon
        if pokemon.egg?
          vault_message("Eggs can't be taught any moves.")
          return
        end
        if pokemon.shadowPokemon?
          vault_message("Shadow Pokemon can't be taught any moves.")
          return
        end
        if pokemon.hasMove?(move_id)
          vault_message(_INTL("{1} already knows {2}.", pokemon.name, move.name))
          return
        end
        if @move_mode != :relearn && !pokemon.compatible_with_move?(move_id)
          vault_message(_INTL("{1} can't learn {2}.", pokemon.name, move.name))
          return
        end
        taught = vault_teach_move(pokemon, move_id)
        if taught
          TMVault.send(:emit, :tm_vault_move_taught, {
            :move => move_id, :move_data => move, :pokemon => pokemon
          })
        end
        @focus = :list
        create_party_icons
        build_list if @move_mode == :relearn
        draw_all
        drain_list_input
      rescue StandardError => e
        KantoReloaded::Log.exception("TM Vault move teaching failed", e, channel: :modules) if defined?(KantoReloaded::Log)
        vault_message("That move could not be taught.")
      end

      def vault_message(text, choices = nil)
        Graphics.update
        Input.update
        lines = text.to_s.split("\n").reject { |line| line.empty? }
        line_count = [lines.length, 2].max
        padding = 12
        line_height = 18
        box_height = padding * 2 + line_count * line_height
        box_y = SCREEN_H - box_height - FOOTER_H

        message_sprite = BitmapSprite.new(SCREEN_W, box_height, @viewport)
        message_sprite.x = 0
        message_sprite.y = box_y
        message_sprite.z = 500
        bitmap = message_sprite.bitmap
        bitmap.fill_rect(0, 0, SCREEN_W, box_height, Color.new(12, 24, 50, 240))
        draw_popup_border(bitmap, SCREEN_W, box_height)
        pbSetSmallFont(bitmap)
        bitmap.font.size = 15
        lines.each_with_index do |line, index|
          pbDrawShadowText(
            bitmap, padding, padding + index * line_height,
            SCREEN_W - padding * 2, line_height, line, WHITE, SHADOW
          )
        end

        selected = 0
        choice_sprite = nil
        redraw_choices = nil
        if choices
          choice_padding = 10
          choice_line_height = 18
          choice_width = 72
          choice_height = choice_padding * 2 + choices.length * choice_line_height
          choice_sprite = BitmapSprite.new(choice_width, choice_height, @viewport)
          choice_sprite.x = SCREEN_W - choice_width - 8
          choice_sprite.y = box_y - choice_height - 4
          choice_sprite.z = 501
          redraw_choices = proc do
            choice_bitmap = choice_sprite.bitmap
            choice_bitmap.clear
            choice_bitmap.fill_rect(
              0, 0, choice_width, choice_height, Color.new(12, 24, 50, 240)
            )
            draw_popup_border(choice_bitmap, choice_width, choice_height)
            pbSetSmallFont(choice_bitmap)
            choice_bitmap.font.size = 15
            choices.each_with_index do |choice, index|
              if index == selected
                choice_bitmap.fill_rect(
                  2, choice_padding + index * choice_line_height - 2,
                  choice_width - 4, choice_line_height, Color.new(30, 60, 110, 255)
                )
              end
              color = index == selected ? WHITE : GRAY
              pbDrawShadowText(
                choice_bitmap, choice_padding,
                choice_padding + index * choice_line_height,
                choice_width - choice_padding * 2, choice_line_height,
                choice, color, SHADOW
              )
            end
          end
          redraw_choices.call
        end

        result = nil
        loop do
          Graphics.update
          Input.update
          if choices
            if Input.trigger?(Input::UP) && selected > 0
              selected -= 1
              redraw_choices.call
            elsif Input.trigger?(Input::DOWN) && selected < choices.length - 1
              selected += 1
              redraw_choices.call
            elsif Input.trigger?(Input::USE)
              result = selected == 0
              break
            elsif Input.trigger?(Input::BACK)
              result = false
              break
            end
          elsif Input.trigger?(Input::USE) || Input.trigger?(Input::BACK)
            break
          end
        end
        result
      ensure
        choice_sprite.dispose if choice_sprite && !choice_sprite.disposed?
        message_sprite.dispose if message_sprite && !message_sprite.disposed?
        drain_list_input
      end

      def draw_popup_border(bitmap, width, height)
        bitmap.fill_rect(2, 0, width - 4, 1, PANEL_BORDER)
        bitmap.fill_rect(2, height - 1, width - 4, 1, PANEL_BORDER)
        bitmap.fill_rect(0, 2, 1, height - 4, PANEL_BORDER)
        bitmap.fill_rect(width - 1, 2, 1, height - 4, PANEL_BORDER)
      end

      def vault_confirm(text)
        vault_message(text, ["Yes", "No"])
      end

      def vault_forget_move(pokemon, move_id)
        previous_z = @viewport.z
        @viewport.z = 1
        pbForgetMove(pokemon, move_id)
      ensure
        @viewport.z = previous_z if @viewport && !@viewport.disposed?
        drain_list_input
      end

      def vault_teach_move(pokemon, move_id)
        move = GameData::Move.get(move_id)
        move_name = move.name
        pokemon_name = pokemon.name
        if pokemon.numMoves < Pokemon::MAX_MOVES
          pokemon.learn_move(move_id)
          pbSEPlay("Pkmn move learnt") rescue nil
          vault_message(_INTL("{1} learned {2}!", pokemon_name, move_name))
          return true
        end

        loop do
          replace = vault_confirm(
            _INTL(
              "{1} wants to learn {2}, but it already knows {3} moves. Replace a move?",
              pokemon_name, move_name, pokemon.numMoves.to_word
            )
          )
          unless replace
            vault_message(_INTL("{1} did not learn {2}.", pokemon_name, move_name))
            return false
          end

          forget_index = vault_forget_move(pokemon, move_id)
          if forget_index >= 0
            old_name = pokemon.moves[forget_index].name
            pokemon.moves[forget_index] = Pokemon::Move.new(move_id)
            pbSEPlay("Battle ball drop") rescue nil
            vault_message(_INTL("{1} forgot {2}.", pokemon_name, old_name))
            pbSEPlay("Pkmn move learnt") rescue nil
            vault_message(_INTL("{1} learned {2}!", pokemon_name, move_name))
            return true
          end

          if vault_confirm(_INTL("Give up on learning {1}?", move_name))
            vault_message(_INTL("{1} did not learn {2}.", pokemon_name, move_name))
            return false
          end
        end
      end

      def empty_list_message
        if @move_mode == :relearn
          return "No Pokemon selected." if @relearn_mon.nil? || !party[@relearn_mon]
          return "No relearnable moves."
        end
        @filter_mon.nil? ? "No moves registered yet.\nFind, buy, or receive TMs." : "No compatible moves."
      end

      def move_color(move_id, move, filter)
        if TMVault.sort_mode == 2 && move
          return Color.new(220, 60, 60) if move.category == 0
          return Color.new(100, 180, 255) if move.category == 1
          return Color.new(240, 210, 60)
        end
        if filter && [0, 3].include?(TMVault.sort_mode)
          return COLOR_KNOWS if filter.hasMove?(move_id)
          return COLOR_COMPAT if filter.compatible_with_move?(move_id)
          return DIM
        end
        type_color(move ? move.type : nil)
      end

      def type_color(type_id)
        colors = {
          :FIRE => Color.new(240, 100, 50), :WATER => Color.new(80, 160, 240),
          :GRASS => Color.new(80, 210, 80), :ELECTRIC => Color.new(240, 210, 50),
          :ICE => Color.new(130, 220, 240), :FIGHTING => Color.new(200, 60, 60),
          :POISON => Color.new(180, 80, 200), :GROUND => Color.new(215, 185, 130),
          :FLYING => Color.new(180, 150, 230), :PSYCHIC => Color.new(240, 80, 140),
          :BUG => Color.new(150, 190, 50), :ROCK => Color.new(190, 160, 70),
          :GHOST => Color.new(110, 80, 160), :DRAGON => Color.new(80, 60, 220),
          :DARK => Color.new(120, 90, 60), :STEEL => Color.new(160, 170, 190),
          :FAIRY => Color.new(240, 140, 200)
        }
        colors[type_id] || WHITE
      end

      def draw_type_icon(bitmap, move, x, y)
        type_data = GameData::Type.get(move.type)
        source = Rect.new(0, type_data.id_number * 28, 64, 28)
        bitmap.stretch_blt(Rect.new(x, y, 32, 14), TMVault.types_bitmap, source)
      rescue
        nil
      end

      def relearn_egg_move?(move_id)
        @move_mode == :relearn && @relearn_egg_moves.include?(move_id)
      rescue
        false
      end

      def draw_egg_icon(bitmap, x, y)
        source_bitmap = TMVault.egg_icon_bitmap
        return unless source_bitmap
        # The 64x64 frame pads the visible Egg to 24x30 pixels.
        source = Rect.new(20, 24, 24, 30)
        bitmap.stretch_blt(Rect.new(x, y, 12, 14), source_bitmap, source)
      rescue
        nil
      end

      def draw_panel(bitmap, width, height)
        KantoReloaded::UI::Draw.rounded_rect(bitmap, 0, 0, width, height, 4, PANEL_BG)
        bitmap.fill_rect(4, 0, width - 8, 1, PANEL_BORDER)
        bitmap.fill_rect(4, height - 1, width - 8, 1, PANEL_BORDER)
        bitmap.fill_rect(0, 4, 1, height - 8, PANEL_BORDER)
        bitmap.fill_rect(width - 1, 4, 1, height - 8, PANEL_BORDER)
      end

      def hint_footer_clicked?
        return false unless KantoReloaded::MouseInput.mouse_triggered?
        position = KantoReloaded::MouseInput.raw_position
        return false unless position
        KantoReloaded::HintText.controls_at?(
          @footer_sprite.bitmap,
          position[0] - @footer_sprite.x,
          position[1] - @footer_sprite.y,
          8, 8, SCREEN_W - 16,
          :height => FOOTER_H,
          :hint_entry => KantoReloaded::HintText.special("Controls")
        )
      rescue
        false
      end

      def drain_list_input
        KantoReloaded::UI::Modal.drain_input if defined?(KantoReloaded::UI::Modal)
      rescue
        nil
      end
    end
  end
end
