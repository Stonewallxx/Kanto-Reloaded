#==============================================================================
# Kanto Reloaded Battle Menu
#==============================================================================
# Centered OWM-style command overlay for the player's main battle command.
#==============================================================================

legacy_battle_menu_entries = []
if defined?(BattleCommandMenu) && BattleCommandMenu.respond_to?(:registry)
  legacy_battle_menu_entries = Array(BattleCommandMenu.registry).dup rescue []
end
unless KantoReloaded.const_defined?(:LEGACY_BATTLE_MENU_ENTRIES, false)
  KantoReloaded.const_set(:LEGACY_BATTLE_MENU_ENTRIES, legacy_battle_menu_entries)
end

module BattleCommandMenu
  SAVE_SYSTEM = :battle_menu
  MAX_ROWS = 10
  TRIGGER_BUTTON = Input::ACTION
  NATIVE_COMMAND_RESULTS = {
    :fight => 0,
    :bag => 1,
    :party => 2,
    :run => 3,
    :call => 4,
    :debug => -2
  }.freeze

  @registry = []
  @legacy_registrations = KantoReloaded::LEGACY_BATTLE_MENU_ENTRIES.dup
  @fallback_pages = nil
  @fallback_page_index = 0
  @fallback_favorite = nil

  class << self
    def register(key = nil, options = nil, **keywords, &block)
      data = {}
      if key.is_a?(Hash)
        data = key.dup
        key = data[:key] || data["key"]
      elsif options.is_a?(Hash)
        data = options.dup
      end
      keywords.each { |name, value| data[name] = value }
      data[:handler] ||= block
      label = data[:label] || data["label"] || data[:name] || data["name"]
      handler = data[:handler] || data["handler"] || data[:on_press] || data["on_press"] || data[:proc] || data["proc"]
      key = generated_key(label) if key.nil?
      normalized_key = normalize_key(key)
      unless normalized_key
        log_warning("Battle Menu registration rejected: key is empty")
        return false
      end
      unless label.is_a?(String) && !label.strip.empty?
        log_warning("Battle Menu registration rejected for #{normalized_key}: label is empty")
        return false
      end
      unless handler.respond_to?(:call)
        log_warning("Battle Menu registration rejected for #{normalized_key}: handler is not callable")
        return false
      end
      if @registry.any? { |entry| entry[:key] == normalized_key }
        log_warning("Battle Menu registration skipped duplicate key=#{normalized_key}")
        return false
      end
      priority = data.has_key?(:priority) ? data[:priority] : (data["priority"] || 100)
      condition = data[:condition] || data["condition"]
      description = data[:description] || data["description"] || ""
      status = data[:status] || data["status"]
      status_color = data[:status_color] || data["status_color"]
      entry = {
        :key => normalized_key,
        :label => label.to_s,
        :name => label.to_s,
        :handler => handler,
        :proc => handler,
        :description => description.to_s,
        :condition => condition || proc { true },
        :priority => priority.to_i,
        :status => status,
        :status_color => status_color
      }
      @registry << entry
      @registry.sort_by! { |item| [item[:priority], item[:label].downcase, item[:key].to_s] }
      log_debug("Registered Battle Menu command #{normalized_key} priority=#{priority}")
      true
    rescue StandardError => e
      log_exception("Battle Menu registration failed", e)
      false
    end

    def register_command(name, callable, description = "", condition = nil, priority = 100)
      register(nil, {
        :name => name,
        :on_press => callable,
        :description => description,
        :condition => condition,
        :priority => priority
      })
    end

    def registry
      @registry
    end

    def clear_registry
      @registry = []
      true
    end

    def all_registered_entries
      @registry.sort_by { |entry| [entry[:priority], entry[:label].downcase, entry[:key].to_s] }
    end

    def all_registered_keys
      all_registered_entries.map { |entry| entry[:key] }
    end

    def get_available_commands(battle, idx_battler)
      all_registered_entries.select { |entry| condition_met?(entry, battle, idx_battler) }
    end

    def condition_met?(entry, battle, idx_battler)
      callable = entry[:condition]
      return true unless callable
      arity = callable.arity
      value = if arity == 0
                callable.call
              elsif arity == 1
                callable.call(battle)
              else
                callable.call(battle, idx_battler)
              end
      !!value
    rescue StandardError => e
      log_exception("Battle Menu condition failed for #{entry[:key]}", e)
      false
    end

    def execute(entry, battle, idx_battler, scene)
      callable = entry && entry[:handler]
      return nil unless callable.respond_to?(:call)
      arity = callable.arity
      return callable.call if arity == 0
      return callable.call(battle) if arity == 1
      return callable.call(battle, idx_battler) if arity == 2
      callable.call(battle, idx_battler, scene)
    rescue StandardError => e
      log_exception("Battle Menu command failed for #{entry ? entry[:key] : :unknown}", e)
      KantoReloaded.message("That Battle Menu command could not be completed.", :theme => :error) if KantoReloaded.respond_to?(:message)
      nil
    end

    def native_command_result?(value)
      NATIVE_COMMAND_RESULTS.has_key?(value)
    end

    def native_command_value(value)
      NATIVE_COMMAND_RESULTS[value]
    end

    def default_pages
      [{ "name" => "Main", "entries" => all_registered_keys.map(&:to_s), "disabled_entries" => [] }]
    end

    def pages
      raw = save_get(:pages, @fallback_pages)
      normalized = normalize_pages(raw)
      self.pages = normalized if raw != normalized
      normalized
    rescue StandardError => e
      log_exception("Battle Menu pages failed to load", e)
      default_pages
    end

    def pages=(value)
      normalized = normalize_pages(value)
      save_set(:pages, normalized) || (@fallback_pages = normalized)
      normalized
    end

    def page_index
      save_get(:page_index, @fallback_page_index || 0).to_i
    rescue
      0
    end

    def page_index=(value)
      normalized = [value.to_i, 0].max
      save_set(:page_index, normalized) || (@fallback_page_index = normalized)
      normalized
    end

    def favorite
      key = normalize_key(save_get(:favorite, @fallback_favorite))
      return nil unless key
      unless all_registered_keys.include?(key)
        self.favorite = nil
        return nil
      end
      key
    rescue
      nil
    end

    def favorite=(value)
      key = normalize_key(value)
      key = nil unless key && all_registered_keys.include?(key)
      save_set(:favorite, key ? key.to_s : nil) || (@fallback_favorite = key)
      key
    end

    def favorite_entry(battle = nil, idx_battler = nil)
      key = favorite
      entry = all_registered_entries.find { |item| item[:key] == key }
      return nil unless entry
      return entry if battle.nil?
      condition_met?(entry, battle, idx_battler) ? entry : nil
    end

    def menu_pages_for_display(battle, idx_battler)
      available = get_available_commands(battle, idx_battler)
      by_key = {}
      available.each { |entry| by_key[entry[:key]] = entry }
      built = []
      pages.each_with_index do |page, index|
        disabled = page_disabled_entries(page)
        entries = page_entries(page).reject { |key| disabled.include?(key) }.map { |key| by_key[key] }.compact
        next if index > 0 && entries.empty?
        built << { :index => index, :name => page_name(page, index), :entries => entries }
      end
      built << { :index => 0, :name => "Main", :entries => available } if built.empty?
      built
    end

    def page_entries(page)
      Array(page["entries"] || page[:entries]).map { |key| normalize_key(key) }.compact.uniq
    end

    def page_disabled_entries(page)
      Array(page["disabled_entries"] || page[:disabled_entries]).map { |key| normalize_key(key) }.compact.uniq
    end

    def page_name(page, index)
      name = (page["name"] || page[:name]).to_s.strip
      name.empty? ? "Page #{index + 1}" : name
    end

    def enabled?
      return @enabled_cache if instance_variable_defined?(:@enabled_cache)
      value = KantoReloaded::Settings.get(:battle_menu, 1)
      cache_enabled(value)
    rescue
      true
    end

    def cache_enabled(value)
      @enabled_cache = value == true || (value.respond_to?(:to_i) && value.to_i == 1)
    end

    def open(battle, idx_battler, scene)
      return nil unless enabled?
      pages_for_display = menu_pages_for_display(battle, idx_battler)
      if pages_for_display.all? { |page| page[:entries].empty? }
        pbPlayBuzzerSE rescue nil
        return nil
      end
      screen = proc { BattleMenuScreen.new(BattleMenuScene.new).open(battle, idx_battler, scene) }
      if defined?(KantoReloaded::UI::Modal)
        KantoReloaded::UI::Modal.with_modal { screen.call }
      else
        screen.call
      end
    end

    def open_editor
      if all_registered_entries.empty?
        KantoReloaded::PopupWindow.message("No Battle Menu commands are registered.") if defined?(KantoReloaded::PopupWindow)
        return false
      end
      pbFadeOutIn { BattleMenuPageEditorScene.new.main }
      true
    rescue StandardError => e
      log_exception("Battle Menu page editor failed to open", e)
      false
    end

    def import_legacy_registrations
      pending = Array(@legacy_registrations)
      if defined?($BATTLE_COMMAND_MENU_PENDING_REGISTRATIONS)
        pending.concat(Array($BATTLE_COMMAND_MENU_PENDING_REGISTRATIONS))
      end
      pending.each do |entry|
        if entry.respond_to?(:call) && !entry.is_a?(Hash)
          entry.call
        elsif entry.is_a?(Hash)
          register(entry)
        elsif entry.is_a?(Array)
          register_command(*entry)
        end
      end
      @legacy_registrations = []
      $BATTLE_COMMAND_MENU_PENDING_REGISTRATIONS = [] if defined?($BATTLE_COMMAND_MENU_PENDING_REGISTRATIONS)
      true
    rescue StandardError => e
      log_exception("Legacy Battle Menu registration import failed", e)
      false
    end

    def log_debug(message)
      KantoReloaded::Log.debug(message, :modules) if defined?(KantoReloaded::Log)
    rescue
    end

    def log_warning(message)
      KantoReloaded::Log.warning(message, :modules) if defined?(KantoReloaded::Log)
    rescue
    end

    def log_exception(message, error)
      KantoReloaded::Log.exception(message, error, channel: :modules) if defined?(KantoReloaded::Log)
    rescue
    end

    private

    def normalize_key(value)
      text = value.to_s.strip.downcase.gsub(/[^a-z0-9_]+/, "_").gsub(/\A_+|_+\z/, "")
      text.empty? ? nil : text.to_sym
    rescue
      nil
    end

    def generated_key(label)
      base = normalize_key("legacy_#{label}") || :legacy_command
      return base unless @registry.any? { |entry| entry[:key] == base }
      suffix = 2
      suffix += 1 while @registry.any? { |entry| entry[:key] == :"#{base}_#{suffix}" }
      :"#{base}_#{suffix}"
    end

    def normalize_pages(value)
      registered = all_registered_keys
      normalized = Array(value).map.with_index do |page, index|
        next unless page.is_a?(Hash)
        entries = page_entries(page) & registered
        disabled = page_disabled_entries(page) & registered
        entries = (entries + (registered - entries)).uniq if index == 0
        {
          "name" => page_name(page, index),
          "entries" => entries.map(&:to_s),
          "disabled_entries" => disabled.map(&:to_s)
        }
      end.compact
      normalized = default_pages if normalized.empty?
      main_entries = page_entries(normalized[0])
      normalized[0]["entries"] = (main_entries + (registered - main_entries)).uniq.map(&:to_s)
      normalized
    end

    def save_get(key, fallback)
      return fallback unless defined?(KantoReloaded::SaveData)
      KantoReloaded::SaveData.get(SAVE_SYSTEM, key, fallback, section: :systems)
    end

    def save_set(key, value)
      return false unless defined?(KantoReloaded::SaveData)
      KantoReloaded::SaveData.set(SAVE_SYSTEM, key, value, section: :systems)
    end
  end
end

KantoReloaded.const_set(:BattleMenu, BattleCommandMenu) unless KantoReloaded.const_defined?(:BattleMenu, false)

class BattleMenuScene
  STYLE = KantoReloaded::UI::QuickMenuStyle
  PANEL_W = 260
  DESCRIPTION_H = 58
  GAP = 4

  def initialize
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 100_000
    @menu_sprite = Sprite.new(@viewport)
    @description_sprite = Sprite.new(@viewport)
    @menu_sprite.z = 10
    @description_sprite.z = 10
  end

  def draw(entries, cursor, scroll, page_position, page_count)
    visible = [[entries.length - scroll, STYLE::MAX_ROWS].min, 1].max
    menu_h = STYLE::HEADER_HEIGHT + visible * STYLE::ROW_HEIGHT + 4
    total_h = menu_h + GAP + DESCRIPTION_H
    x = (Graphics.width - PANEL_W) / 2
    y = (Graphics.height - total_h) / 2
    replace_bitmap(@menu_sprite, PANEL_W, menu_h)
    replace_bitmap(@description_sprite, PANEL_W, DESCRIPTION_H)
    @menu_sprite.x = x
    @menu_sprite.y = y
    @description_sprite.x = x
    @description_sprite.y = y + menu_h + GAP
    draw_menu(@menu_sprite.bitmap, entries, cursor, scroll, page_position, page_count)
    draw_description(@description_sprite.bitmap, entries[cursor])
  end

  def hide
    @menu_sprite.visible = false
    @description_sprite.visible = false
  end

  def show
    @menu_sprite.visible = true
    @description_sprite.visible = true
  end

  def dispose
    [@menu_sprite, @description_sprite].each do |sprite|
      sprite.bitmap.dispose rescue nil
      sprite.dispose rescue nil
    end
    @viewport.dispose rescue nil
  end

  private

  def replace_bitmap(sprite, width, height)
    return if sprite.bitmap && sprite.bitmap.width == width && sprite.bitmap.height == height
    sprite.bitmap.dispose rescue nil
    sprite.bitmap = Bitmap.new(width, height)
  end

  def draw_menu(bitmap, entries, cursor, scroll, page_position, page_count)
    bitmap.clear
    title = page_count > 1 ? "BATTLE MENU #{page_position + 1}/#{page_count}" : "BATTLE MENU"
    STYLE.draw_panel(bitmap, PANEL_W, bitmap.height, title)
    if entries.empty?
      pbSetSmallFont(bitmap)
      bitmap.font.size = 15
      pbDrawShadowText(bitmap, STYLE::PADDING, STYLE::HEADER_HEIGHT + 3,
                       PANEL_W - STYLE::PADDING * 2, STYLE::ROW_HEIGHT,
                       "No commands", STYLE::DIM, STYLE::SHADOW, 1)
      return
    end
    visible = [entries.length - scroll, STYLE::MAX_ROWS].min
    visible.times do |row|
      index = scroll + row
      entry = entries[index]
      y = STYLE::HEADER_HEIGHT + 2 + row * STYLE::ROW_HEIGHT
      selected = index == cursor
      bitmap.fill_rect(2, y, PANEL_W - 4, STYLE::ROW_HEIGHT - 2, STYLE::SELECTION) if selected
      pbSetSmallFont(bitmap)
      bitmap.font.size = 15
      status = entry_status(entry)
      status_width = status.empty? ? 0 : 86
      color = selected ? STYLE::WHITE : STYLE::GRAY
      pbDrawShadowText(bitmap, STYLE::PADDING + 2, y,
                       PANEL_W - STYLE::PADDING * 2 - status_width,
                       STYLE::ROW_HEIGHT - 2, entry[:label], color, STYLE::SHADOW)
      unless status.empty?
        pbDrawShadowText(bitmap, PANEL_W - STYLE::PADDING - status_width, y,
                         status_width, STYLE::ROW_HEIGHT - 2, status,
                         entry_status_color(entry), STYLE::SHADOW, 2)
      end
    end
    if page_count > 1
      pbSetSmallFont(bitmap)
      bitmap.font.size = 11
      pbDrawShadowText(bitmap, 3, 5, 18, 12, "<", STYLE::DIM, STYLE::SHADOW, 0) if page_position > 0
      pbDrawShadowText(bitmap, PANEL_W - 21, 5, 18, 12, ">", STYLE::DIM, STYLE::SHADOW, 2) if page_position < page_count - 1
    end
    pbDrawShadowText(bitmap, 0, STYLE::HEADER_HEIGHT, PANEL_W, 10, "\u25B2", STYLE::DIM, STYLE::SHADOW, 1) if scroll > 0
    if scroll + STYLE::MAX_ROWS < entries.length
      pbDrawShadowText(bitmap, 0, bitmap.height - 10, PANEL_W, 10, "\u25BC", STYLE::DIM, STYLE::SHADOW, 1)
    end
  end

  def draw_description(bitmap, entry)
    bitmap.clear
    STYLE.draw_panel(bitmap, PANEL_W, DESCRIPTION_H, "DESCRIPTION")
    text = entry ? entry[:description].to_s : ""
    text = "No description provided." if text.empty?
    pbSetSmallFont(bitmap)
    bitmap.font.size = 13
    lines = KantoReloaded::UI::Draw.wrap_lines(bitmap, text, PANEL_W - STYLE::PADDING * 2)
    lines.first(2).each_with_index do |line, index|
      pbDrawShadowText(bitmap, STYLE::PADDING, STYLE::HEADER_HEIGHT + index * 15,
                       PANEL_W - STYLE::PADDING * 2, 15, line, STYLE::GRAY, STYLE::SHADOW)
    end
  end

  def entry_status(entry)
    return "FAVORITE" if entry[:key] == BattleCommandMenu.favorite
    value = entry[:status]
    value = value.call if value.respond_to?(:call)
    value.to_s
  rescue
    ""
  end

  def entry_status_color(entry)
    return STYLE::GOLD if entry[:key] == BattleCommandMenu.favorite
    value = entry[:status_color]
    value = value.call if value.respond_to?(:call)
    value || STYLE::GREEN
  rescue
    STYLE::GREEN
  end
end

class BattleMenuScreen
  def initialize(scene)
    @scene = scene
  end

  def open(battle, idx_battler, host_scene)
    pages = BattleCommandMenu.menu_pages_for_display(battle, idx_battler)
    page_position = pages.index { |page| page[:index] == BattleCommandMenu.page_index } || 0
    cursor = 0
    scroll = 0
    Input.update
    loop do
      entries = pages[page_position][:entries]
      cursor = [[cursor, 0].max, [entries.length - 1, 0].max].min
      scroll = [[scroll, cursor].min, [entries.length - BattleCommandMenu::MAX_ROWS, 0].max].min
      @scene.draw(entries, cursor, scroll, page_position, pages.length)
      Graphics.update
      Input.update
      if Input.repeat?(Input::UP) && !entries.empty?
        cursor = (cursor - 1) % entries.length
        scroll = cursor if cursor < scroll
        scroll = [entries.length - BattleCommandMenu::MAX_ROWS, 0].max if cursor >= scroll + BattleCommandMenu::MAX_ROWS
        pbPlayCursorSE
      elsif Input.repeat?(Input::DOWN) && !entries.empty?
        cursor = (cursor + 1) % entries.length
        scroll = 0 if cursor < scroll
        scroll = cursor - BattleCommandMenu::MAX_ROWS + 1 if cursor >= scroll + BattleCommandMenu::MAX_ROWS
        pbPlayCursorSE
      elsif Input.trigger?(Input::LEFT) && pages.length > 1
        page_position = (page_position - 1) % pages.length
        BattleCommandMenu.page_index = pages[page_position][:index]
        cursor = 0
        scroll = 0
        pbPlayCursorSE
      elsif Input.trigger?(Input::RIGHT) && pages.length > 1
        page_position = (page_position + 1) % pages.length
        BattleCommandMenu.page_index = pages[page_position][:index]
        cursor = 0
        scroll = 0
        pbPlayCursorSE
      elsif Input.trigger?(Input::ACTION)
        favorite = BattleCommandMenu.favorite_entry(battle, idx_battler)
        unless favorite
          pbPlayBuzzerSE rescue nil
          next
        end
        result = execute(favorite, battle, idx_battler, host_scene)
        return result unless result == :keep_open
        pages = BattleCommandMenu.menu_pages_for_display(battle, idx_battler)
        page_position = pages.index { |page| page[:index] == BattleCommandMenu.page_index } || 0
        cursor = 0
        scroll = 0
      elsif Input.trigger?(Input::USE)
        entry = entries[cursor]
        if entry
          result = execute(entry, battle, idx_battler, host_scene)
          return result unless result == :keep_open
          pages = BattleCommandMenu.menu_pages_for_display(battle, idx_battler)
          page_position = pages.index { |page| page[:index] == BattleCommandMenu.page_index } || 0
          cursor = 0
          scroll = 0
        end
      elsif Input.trigger?(Input::BACK)
        pbPlayCancelSE
        return nil
      end
    end
  ensure
    @scene.dispose
    Input.update rescue nil
  end

  private

  def execute(entry, battle, idx_battler, host_scene)
    pbPlayDecisionSE
    @scene.hide
    Graphics.update rescue nil
    result = BattleCommandMenu.execute(entry, battle, idx_battler, host_scene)
    @scene.show if result == :keep_open
    result
  end
end

class BattleMenuPageEditorScene
  SCREEN_W = 512
  SCREEN_H = 384
  ITEM_H = 26
  LIST_X = 16
  LIST_Y = 70
  LIST_W = 480
  BOX_SIZE = 12
  NUM_W = 24
  FOOTER_Y = 360
  MAX_VISIBLE_ROWS = 10

  C_BG = Color.new(10, 12, 30, 255)
  C_PANEL = Color.new(16, 20, 38, 235)
  C_BORDER = Color.new(55, 75, 160, 255)
  C_SEL = Color.new(60, 80, 160, 170)
  C_POPUP_SEL = Color.new(60, 88, 190, 235)
  C_PICKUP = Color.new(180, 130, 30, 170)
  C_WHITE = Color.new(255, 255, 255)
  C_GRAY = Color.new(160, 165, 190)
  C_DIM = Color.new(90, 96, 125)
  C_GOLD = Color.new(228, 188, 58)
  C_GREEN = Color.new(80, 200, 100)
  C_SHADOW = Color.new(0, 0, 0, 0)

  def main
    @entries = BattleCommandMenu.all_registered_entries
    return if @entries.empty?
    @pages = BattleCommandMenu.pages
    @page_index = [[BattleCommandMenu.page_index, 0].max, [@pages.length - 1, 0].max].min
    @cursor = 0
    @top_row = 0
    @dragging = false
    @running = true
    @viewport = Viewport.new(0, 0, SCREEN_W, SCREEN_H)
    @viewport.z = 100_000
    @background = BitmapSprite.new(SCREEN_W, SCREEN_H, @viewport)
    @list = BitmapSprite.new(SCREEN_W, SCREEN_H, @viewport)
    @background.z = 5
    @list.z = 10
    draw_background
    draw_list
    while @running
      Graphics.update
      Input.update
      handle_input
    end
  ensure
    persist
    dispose
    Input.update rescue nil
  end

  private

  def current_page
    @pages[@page_index] ||= { "name" => "Page #{@page_index + 1}", "entries" => [], "disabled_entries" => [] }
  end

  def selected_keys
    valid = @entries.map { |entry| entry[:key] }
    disabled = disabled_keys
    BattleCommandMenu.page_entries(current_page).select { |key| valid.include?(key) && !disabled.include?(key) }
  end

  def selected_keys=(value)
    keys = Array(value).map { |key| key.to_sym rescue nil }.compact.uniq
    current_page["entries"] = if @page_index == 0
                                (keys + disabled_keys).uniq.map(&:to_s)
                              else
                                keys.map(&:to_s)
                              end
  end

  def disabled_keys
    valid = @entries.map { |entry| entry[:key] }
    BattleCommandMenu.page_disabled_entries(current_page).select { |key| valid.include?(key) }
  end

  def disabled_keys=(value)
    current_page["disabled_entries"] = Array(value).map { |key| key.to_sym rescue nil }.compact.uniq.map(&:to_s)
  end

  def sorted_items
    selected = selected_keys
    active = selected.map { |key| @entries.find { |entry| entry[:key] == key } }.compact
    active + @entries.reject { |entry| selected.include?(entry[:key]) }
  end

  def draw_background
    bitmap = @background.bitmap
    bitmap.clear
    bitmap.fill_rect(0, 0, SCREEN_W, SCREEN_H, C_BG)
    pbSetSmallFont(bitmap)
    bitmap.font.size = 22
    bitmap.font.bold = true
    pbDrawShadowText(bitmap, 0, 8, SCREEN_W, 28, "BATTLE MENU PAGES", C_WHITE, C_SHADOW, 1)
    bitmap.font.bold = false
    bitmap.font.size = 14
    pbDrawShadowText(bitmap, 0, 38, SCREEN_W, 18, "Left/Right changes pages while editing.", C_GRAY, C_SHADOW, 1)
  end

  def draw_list
    bitmap = @list.bitmap
    bitmap.clear
    items = sorted_items
    selected = selected_keys
    ensure_cursor_visible(items.length)
    draw_page_header(bitmap)
    last = [@top_row + MAX_VISIBLE_ROWS, items.length].min
    Array(items[@top_row...last]).each_with_index do |entry, visible_index|
      index = @top_row + visible_index
      draw_entry_row(bitmap, entry, index, LIST_Y + visible_index * ITEM_H, selected)
    end
    if selected.length > @top_row && selected.length < last
      divider_y = LIST_Y + (selected.length - @top_row) * ITEM_H - 2
      bitmap.fill_rect(LIST_X + 20, divider_y, LIST_W - 40, 1, Color.new(100, 100, 140, 160))
    end
    draw_hint(bitmap)
    Graphics.update
  end

  def draw_page_header(bitmap)
    label = "#{BattleCommandMenu.page_name(current_page, @page_index)}  #{@page_index + 1}/#{@pages.length}"
    bitmap.fill_rect(LIST_X, LIST_Y - 28, LIST_W, 22, C_PANEL)
    bitmap.fill_rect(LIST_X, LIST_Y - 28, LIST_W, 1, C_BORDER)
    bitmap.fill_rect(LIST_X, LIST_Y - 7, LIST_W, 1, C_BORDER)
    bitmap.fill_rect(LIST_X, LIST_Y - 28, 1, 22, C_BORDER)
    bitmap.fill_rect(LIST_X + LIST_W - 1, LIST_Y - 28, 1, 22, C_BORDER)
    pbSetSmallFont(bitmap)
    bitmap.font.size = 15
    pbDrawShadowText(bitmap, LIST_X + 8, LIST_Y - 25, LIST_W - 16, 18, label, C_WHITE, C_SHADOW, 1)
    if @pages.length > 1
      pbDrawShadowText(bitmap, LIST_X + 4, LIST_Y - 25, 20, 18, "<", C_DIM, C_SHADOW) if @page_index > 0
      pbDrawShadowText(bitmap, LIST_X + LIST_W - 24, LIST_Y - 25, 20, 18, ">", C_DIM, C_SHADOW, 2) if @page_index < @pages.length - 1
    end
  end

  def draw_entry_row(bitmap, entry, index, y, selected)
    selected_row = index == @cursor
    active = selected.include?(entry[:key])
    if selected_row && @dragging
      bitmap.fill_rect(LIST_X, y, LIST_W, ITEM_H - 2, C_PICKUP)
    elsif selected_row
      bitmap.fill_rect(LIST_X, y, LIST_W, ITEM_H - 2, C_SEL)
    end
    box_x = LIST_X + 6
    box_y = y + (ITEM_H - BOX_SIZE) / 2
    bitmap.fill_rect(box_x, box_y, BOX_SIZE, BOX_SIZE, active ? C_GREEN : Color.new(120, 120, 140, 180))
    bitmap.fill_rect(box_x, box_y, BOX_SIZE, 1, Color.new(0, 0, 0, 120))
    bitmap.fill_rect(box_x, box_y + BOX_SIZE - 1, BOX_SIZE, 1, Color.new(0, 0, 0, 120))
    bitmap.fill_rect(box_x, box_y, 1, BOX_SIZE, Color.new(0, 0, 0, 120))
    bitmap.fill_rect(box_x + BOX_SIZE - 1, box_y, 1, BOX_SIZE, Color.new(0, 0, 0, 120))
    position = active ? selected.index(entry[:key]) + 1 : nil
    pbSetSmallFont(bitmap)
    bitmap.font.size = 14
    pbDrawShadowText(bitmap, box_x + BOX_SIZE + 6, y + 5, NUM_W, ITEM_H - 5, position.to_s, C_GOLD, C_SHADOW, 1) if position
    label_x = box_x + BOX_SIZE + 6 + NUM_W + 4
    label_w = LIST_W - (label_x - LIST_X) - 88
    color = selected_row ? C_WHITE : (active ? Color.new(205, 220, 205) : C_GRAY)
    color = C_GOLD if selected_row && @dragging
    bitmap.font.size = 16
    pbDrawShadowText(bitmap, label_x, y + 4, label_w, ITEM_H - 4, entry[:label].upcase, color, C_SHADOW)
    if entry[:key] == BattleCommandMenu.favorite
      bitmap.font.size = 12
      pbDrawShadowText(bitmap, LIST_X + LIST_W - 84, y + 6, 76, ITEM_H - 6, "FAVORITE", C_GOLD, C_SHADOW, 2)
    end
  end

  def draw_hint(bitmap)
    hint = if @dragging
             "Confirm (C) Place  Back (B) Cancel  Action (A) Place  Others: Up/Down Move"
           else
             "Confirm (C) Show/Hide  Back (B) Save  Action (A) Reorder  Special (Z) Page Options  Others: Left/Right Page"
           end
    pbSetSmallFont(bitmap)
    bitmap.font.size = 14
    pbDrawTextPositions(bitmap, [[hint, SCREEN_W - 6, FOOTER_Y + 3, 1, C_WHITE, C_SHADOW]])
  end

  def handle_input
    items = sorted_items
    return if items.empty?
    return handle_dragging(items) if @dragging
    if Input.trigger?(Input::DOWN)
      move_cursor(1, items.length)
    elsif Input.trigger?(Input::UP)
      move_cursor(-1, items.length)
    elsif Input.trigger?(Input::LEFT)
      switch_page(-1)
    elsif Input.trigger?(Input::RIGHT)
      switch_page(1)
    elsif Input.trigger?(Input::USE)
      toggle_entry(items[@cursor])
    elsif Input.trigger?(Input::ACTION)
      if selected_keys.include?(items[@cursor][:key])
        @dragging = true
        pbPlayDecisionSE
        draw_list
      else
        pbPlayBuzzerSE rescue nil
      end
    elsif Input.const_defined?(:SPECIAL) && Input.trigger?(Input::SPECIAL)
      open_page_actions(items[@cursor])
    elsif Input.trigger?(Input::BACK)
      pbPlayCloseMenuSE
      @running = false
    end
  end

  def handle_dragging(items)
    keys = selected_keys
    key = items[@cursor][:key]
    index = keys.index(key)
    delta = Input.trigger?(Input::DOWN) ? 1 : (Input.trigger?(Input::UP) ? -1 : 0)
    if delta != 0 && index && (index + delta).between?(0, keys.length - 1)
      keys.delete(key)
      keys.insert(index + delta, key)
      self.selected_keys = keys
      @cursor += delta
      ensure_cursor_visible(sorted_items.length)
      pbPlayCursorSE
      draw_list
    elsif Input.trigger?(Input::USE) || Input.trigger?(Input::ACTION)
      @dragging = false
      pbPlayDecisionSE
      draw_list
    elsif Input.trigger?(Input::BACK)
      @dragging = false
      pbPlayCursorSE
      draw_list
    end
  end

  def move_cursor(delta, count)
    @cursor = (@cursor + delta) % count
    ensure_cursor_visible(count)
    pbPlayCursorSE
    draw_list
  end

  def ensure_cursor_visible(count)
    @cursor = [[@cursor, 0].max, [count - 1, 0].max].min
    max_top = [count - MAX_VISIBLE_ROWS, 0].max
    @top_row = [[@top_row, 0].max, max_top].min
    @top_row = @cursor if @cursor < @top_row
    @top_row = @cursor - MAX_VISIBLE_ROWS + 1 if @cursor >= @top_row + MAX_VISIBLE_ROWS
  end

  def switch_page(delta)
    return if @pages.length <= 1
    @page_index = (@page_index + delta) % @pages.length
    BattleCommandMenu.page_index = @page_index
    @cursor = 0
    @top_row = 0
    @dragging = false
    pbPlayCursorSE
    draw_list
  end

  def toggle_entry(entry)
    keys = selected_keys
    if keys.delete(entry[:key])
      self.disabled_keys = disabled_keys + [entry[:key]] if @page_index == 0
    else
      self.disabled_keys = disabled_keys - [entry[:key]] if @page_index == 0
      keys << entry[:key]
    end
    self.selected_keys = keys
    @cursor = [@cursor, sorted_items.length - 1].min
    pbPlayDecisionSE
    draw_list
  end

  def open_page_actions(entry)
    favorite_label = entry[:key] == BattleCommandMenu.favorite ? "Clear Favorite" : "Set as Favorite"
    commands = [favorite_label, "Rename Page", "Add Page", "Remove Page", "Reset Page", "Back"]
    choice = show_actions_popup(commands)
    case choice
    when 0
      BattleCommandMenu.favorite = entry[:key] == BattleCommandMenu.favorite ? nil : entry[:key]
      pbPlayDecisionSE
    when 1 then rename_page
    when 2
      @pages << { "name" => "Page #{@pages.length + 1}", "entries" => [], "disabled_entries" => [] }
      @page_index = @pages.length - 1
      @cursor = 0
      @top_row = 0
      BattleCommandMenu.page_index = @page_index
      pbPlayDecisionSE
    when 3
      if @page_index > 0
        @pages.delete_at(@page_index)
        @page_index = [@page_index, @pages.length - 1].min
        @cursor = 0
        @top_row = 0
        BattleCommandMenu.page_index = @page_index
        pbPlayDecisionSE
      else
        pbPlayBuzzerSE rescue nil
      end
    when 4
      if @page_index == 0
        self.selected_keys = BattleCommandMenu.all_registered_keys
        self.disabled_keys = []
      else
        self.selected_keys = []
      end
      pbPlayDecisionSE
    else
      pbPlayCancelSE rescue nil
    end
    draw_background
    draw_list
  end

  def rename_page
    old_name = BattleCommandMenu.page_name(current_page, @page_index)
    new_name = nil
    with_editor_hidden { new_name = pbEnterText("Page name?", 1, 16, old_name) }
    new_name = new_name.to_s.strip
    return if new_name.empty? || new_name == old_name
    current_page["name"] = new_name
    pbPlayDecisionSE
  rescue StandardError => e
    BattleCommandMenu.log_exception("Battle Menu page rename failed", e)
    pbPlayBuzzerSE rescue nil
  end

  def with_editor_hidden
    @background.visible = false
    @list.visible = false
    old_z = @viewport.z
    @viewport.z = 0
    Graphics.update
    yield
  ensure
    @viewport.z = old_z rescue 100_000
    @background.visible = true rescue nil
    @list.visible = true rescue nil
    Graphics.update rescue nil
  end

  def show_actions_popup(commands)
    cursor = 0
    width = 250
    row_h = 22
    height = 30 + commands.length * row_h + 8
    sprite = Sprite.new(@viewport)
    sprite.z = 80
    sprite.x = (SCREEN_W - width) / 2
    sprite.y = (SCREEN_H - height) / 2
    loop do
      draw_actions_popup(sprite, commands, cursor, width, height, row_h)
      Graphics.update
      Input.update
      if Input.repeat?(Input::UP)
        cursor = (cursor - 1) % commands.length
        pbPlayCursorSE
      elsif Input.repeat?(Input::DOWN)
        cursor = (cursor + 1) % commands.length
        pbPlayCursorSE
      elsif Input.trigger?(Input::USE)
        return cursor
      elsif Input.trigger?(Input::BACK)
        return nil
      end
    end
  ensure
    sprite.bitmap.dispose rescue nil
    sprite.dispose rescue nil
    Input.update rescue nil
  end

  def draw_actions_popup(sprite, commands, cursor, width, height, row_h)
    sprite.bitmap.dispose rescue nil
    bitmap = Bitmap.new(width, height)
    KantoReloaded::UI::QuickMenuStyle.draw_panel(bitmap, width, height, "PAGE OPTIONS")
    commands.each_with_index do |label, index|
      y = 28 + index * row_h
      selected = index == cursor
      bitmap.fill_rect(2, y, width - 4, row_h - 2, C_POPUP_SEL) if selected
      pbSetSmallFont(bitmap)
      bitmap.font.size = 15
      pbDrawShadowText(bitmap, 10, y + 3, width - 20, row_h - 4, label,
                       selected ? C_WHITE : C_GRAY, C_SHADOW)
    end
    sprite.bitmap = bitmap
  end

  def persist
    return unless @pages
    BattleCommandMenu.pages = @pages
    BattleCommandMenu.page_index = @page_index || 0
  rescue StandardError => e
    BattleCommandMenu.log_exception("Battle Menu page editor failed to save", e)
  end

  def dispose
    [@background, @list].compact.each do |sprite|
      sprite.bitmap.dispose rescue nil
      sprite.dispose rescue nil
    end
    @viewport.dispose rescue nil
  end
end

module KantoReloaded
  module BattleMenuFeature
    ENABLED_SETTING = :battle_menu
    CUSTOMIZE_SETTING = :customize_battle_menu
    SETTING_MIGRATION = :setting_key_migration_v1
    DEFAULT_ON_CORRECTION = :legacy_default_on_correction_v2

    class << self
      def install
        register_settings
        register_events
        migrate_setting
        BattleCommandMenu.import_legacy_registrations
        KantoReloaded::BattleMenuIntegration.install
        KantoReloaded::Log.info("Installed Battle Menu module", :modules) if defined?(KantoReloaded::Log)
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Battle Menu install failed", e, channel: :modules) if defined?(KantoReloaded::Log)
        false
      end

      def register_settings
        return unless defined?(KantoReloaded::Settings)
        KantoReloaded::Settings.register(ENABLED_SETTING, {
          :name => "Battle Menu",
          :description => "Press Action during the main battle command to open the Battle Menu.",
          :type => :toggle,
          :category => :interface,
          :scope => :global,
          :owner => :kanto_reloaded,
          :value_style => :integer,
          :default => 1,
          :priority => 80
        })
        KantoReloaded::Settings.register_on_change(
          ENABLED_SETTING,
          :battle_menu_enabled_cache,
          :owner => :kanto_reloaded
        ) do |value|
          BattleCommandMenu.cache_enabled(value)
        end
        KantoReloaded::Settings.register(CUSTOMIZE_SETTING, {
          :name => "Customize Battle Menu",
          :description => "Choose Battle Menu pages, ordering, visibility, and Favorite command.",
          :type => :button,
          :category => :interface,
          :owner => :kanto_reloaded,
          :priority => 90,
          :metadata => { "after" => "battle_menu" },
          :enabled_if => proc { defined?($Trainer) && $Trainer && !BattleCommandMenu.all_registered_entries.empty? },
          :on_press => proc { BattleCommandMenu.open_editor }
        })
      end

      def migrate_setting
        return unless defined?(KantoReloaded::SaveData) && defined?(KantoReloaded::Settings)
        unless KantoReloaded::SaveData.get(:battle_menu, SETTING_MIGRATION, false, section: :systems)
          unless KantoReloaded::Settings.stored?(ENABLED_SETTING)
            value = legacy_setting_value
            # MSM's Battle Command Menu defaulted Off. Treat that value as the
            # retired default, not as an explicit choice for KR's On-by-default menu.
            if enabled_value?(value)
              KantoReloaded::Settings.set(ENABLED_SETTING, 1, :notify => false)
            end
          end
          KantoReloaded::SaveData.set(:battle_menu, SETTING_MIGRATION, true, section: :systems)
        end
        correct_imported_legacy_default
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Battle Menu setting migration failed", e, channel: :modules) if defined?(KantoReloaded::Log)
        false
      end

      def correct_imported_legacy_default
        return if KantoReloaded::SaveData.get(:battle_menu, DEFAULT_ON_CORRECTION, false, section: :systems)
        if defined?(KantoReloaded::GlobalSettings) &&
           KantoReloaded::GlobalSettings.stored?(ENABLED_SETTING)
          KantoReloaded::SaveData.set(:battle_menu, DEFAULT_ON_CORRECTION, true, section: :systems)
          return true
        end
        value = legacy_setting_value
        if KantoReloaded::Settings.stored?(ENABLED_SETTING) &&
           !enabled_value?(KantoReloaded::Settings.get(ENABLED_SETTING, 1)) &&
           !value.nil? && !enabled_value?(value)
          KantoReloaded::Settings.set(ENABLED_SETTING, 1, :notify => false)
        end
        KantoReloaded::SaveData.set(:battle_menu, DEFAULT_ON_CORRECTION, true, section: :systems)
      end

      def legacy_setting_value
        if KantoReloaded::Settings.stored?(:battle_command_menu)
          KantoReloaded::Settings.get(:battle_command_menu, nil)
        elsif defined?(ModSettingsMenu) && ModSettingsMenu.respond_to?(:get)
          ModSettingsMenu.get(:battle_command_menu) rescue nil
        end
      end

      def enabled_value?(value)
        value == true || (value.respond_to?(:to_i) && value.to_i == 1)
      end

      def register_events
        return unless defined?(KantoReloaded::Events)
        KantoReloaded::Events.on(:kanto_reloaded_save_loaded, :battle_menu_setting_migration, priority: 150) do |_context|
          KantoReloaded::BattleMenuFeature.migrate_setting
        end
        KantoReloaded::Events.on(:kanto_reloaded_save_new_game, :battle_menu_setting_migration, priority: 150) do |_context|
          KantoReloaded::BattleMenuFeature.migrate_setting
        end
      end
    end
  end

  module BattleMenuIntegration
    EXIT_TAG = :kanto_reloaded_battle_menu_result

    module SceneBridge
      def pbOpenBattleCommandMenu(idx_battler)
        KantoReloaded::BattleMenuIntegration.open_for(self, idx_battler)
      end
    end

    class << self
      def install
        return false unless defined?(KantoReloaded::Hooks)
        install_target(PokeBattle_Scene, :vanilla) if defined?(PokeBattle_Scene)
        install_target(PokeBattle_SceneEBDX, :ebdx) if defined?(PokeBattle_SceneEBDX)
        install_legacy_bridge
        true
      rescue StandardError => e
        BattleCommandMenu.log_exception("Battle Menu hook installation failed", e)
        false
      end

      def install_target(target, id)
        KantoReloaded::Hooks.wrap(target, :pbCommandMenu, :"battle_menu_context_#{id}") do |hook, idx_battler, *_args|
          KantoReloaded::BattleMenuIntegration.with_context(self, idx_battler) { hook.call }
        end
        KantoReloaded::Hooks.wrap(target, :pbUpdate, :"battle_menu_input_#{id}") do |hook, *_args|
          result = hook.call
          KantoReloaded::BattleMenuIntegration.check_input(self)
          result
        end
      end

      def install_legacy_bridge
        return unless defined?(PokeBattle_Scene)
        if method_available?(PokeBattle_Scene, :pbOpenBattleCommandMenu)
          KantoReloaded::Hooks.wrap(PokeBattle_Scene, :pbOpenBattleCommandMenu, :battle_menu_legacy_open) do |_hook, idx_battler, *_args|
            KantoReloaded::BattleMenuIntegration.open_for(self, idx_battler)
          end
        else
          PokeBattle_Scene.send(:include, SceneBridge)
        end
      end

      def with_context(scene, idx_battler)
        previous = scene.instance_variable_get(:@kr_battle_menu_context)
        scene.instance_variable_set(:@kr_battle_menu_context, { :idx_battler => idx_battler })
        caught = catch(EXIT_TAG) do
          { :normal => true, :value => yield }
        end
        return caught[:value] if caught.is_a?(Hash) && caught[:normal]
        return -10 if caught == :quick_throw_used
        return BattleCommandMenu.native_command_value(caught) if BattleCommandMenu.native_command_result?(caught)
        caught
      ensure
        scene.instance_variable_set(:@kr_battle_menu_context, previous)
      end

      def check_input(scene)
        native_ui = nil
        context = scene.instance_variable_get(:@kr_battle_menu_context)
        return false unless context
        return false if scene.instance_variable_get(:@kr_battle_menu_active)
        return false if scene.instance_variable_get(:@kr_battle_menu_ui_transition)
        return false unless Input.trigger?(BattleCommandMenu::TRIGGER_BUTTON)
        return false unless BattleCommandMenu.enabled?
        return false if defined?(KantoReloaded::UI::Modal) && KantoReloaded::UI::Modal.active?
        native_ui = suspend_native_command_ui(scene)
        result = open_for(scene, context[:idx_battler])
        if result == :quick_throw_used || BattleCommandMenu.native_command_result?(result)
          throw(EXIT_TAG, result)
        end
        resume_native_command_ui(scene, native_ui)
        native_ui = nil
        true
      rescue UncaughtThrowError
        resume_native_command_ui(scene, native_ui) if native_ui
        false
      rescue StandardError => e
        resume_native_command_ui(scene, native_ui) if native_ui
        BattleCommandMenu.log_exception("Battle Menu input handling failed", e)
        false
      end

      def open_for(scene, idx_battler)
        return nil if scene.instance_variable_get(:@kr_battle_menu_active)
        battle = scene.instance_variable_get(:@battle)
        return nil unless battle
        scene.instance_variable_set(:@kr_battle_menu_active, true)
        BattleCommandMenu.open(battle, idx_battler, scene)
      ensure
        scene.instance_variable_set(:@kr_battle_menu_active, false) if scene
      end

      def suspend_native_command_ui(scene)
        command_window = native_command_window(scene)
        return nil unless command_window
        if command_window.respond_to?(:hidePlay) && command_window.respond_to?(:showPlay)
          with_command_ui_transition(scene) { command_window.hidePlay }
          { :kind => :animated, :window => command_window }
        elsif command_window.respond_to?(:visible) && command_window.respond_to?(:visible=)
          visible = command_window.visible
          command_window.visible = false
          { :kind => :visibility, :window => command_window, :visible => visible }
        end
      rescue StandardError => e
        BattleCommandMenu.log_exception("Native battle command UI suspension failed", e)
        nil
      end

      def resume_native_command_ui(scene, state)
        return false unless state && state[:window]
        if state[:kind] == :animated
          with_command_ui_transition(scene) { state[:window].showPlay }
        elsif state[:kind] == :visibility
          state[:window].visible = state[:visible]
        end
        true
      rescue StandardError => e
        BattleCommandMenu.log_exception("Native battle command UI restoration failed", e)
        false
      end

      private

      def native_command_window(scene)
        animated = scene.instance_variable_get(:@commandWindow)
        return animated if animated && animated.respond_to?(:hidePlay) && animated.respond_to?(:showPlay)
        sprites = scene.instance_variable_get(:@sprites)
        sprites.is_a?(Hash) ? sprites["commandWindow"] : nil
      end

      def with_command_ui_transition(scene)
        previous = scene.instance_variable_get(:@kr_battle_menu_ui_transition)
        scene.instance_variable_set(:@kr_battle_menu_ui_transition, true)
        yield
      ensure
        scene.instance_variable_set(:@kr_battle_menu_ui_transition, previous)
      end

      def method_available?(target, method_name)
        target.public_method_defined?(method_name) ||
          target.protected_method_defined?(method_name) ||
          target.private_method_defined?(method_name)
      end
    end
  end
end

KantoReloaded::BattleMenuFeature.install if defined?(KantoReloaded::BattleMenuFeature)
