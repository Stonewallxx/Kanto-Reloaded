#======================================================
# Overworld Menu
# Author: Stonewall
#======================================================
# Compact quick-access overlay for the overworld.
#
# Responsibilities:
#   - Preserve the reference Overworld Menu UI and feature set.
#   - Preserve the legacy OverworldMenu registration API for existing mods.
#   - Store player-facing settings through Kanto Reloaded save data.
#   - Register through the existing map-update event hook without base edits.
#   - Keep module logging visible for troubleshooting.
#
#======================================================

module KantoReloaded
  module OverworldMenuFeature
    ENABLED_SETTING = :overworld_menu
    LEGACY_MIGRATION_KEY = :legacy_settings_imported
    SETTING_KEY_MIGRATION = :setting_key_migration_v2

    class << self
      def install
        register_options
        register_events
        migrate_setting_key
        migrate_legacy_settings
        OverworldMenu.import_legacy_registrations if defined?(OverworldMenu)
        KantoReloaded::Log.info("Installed Overworld Menu module", :modules) if defined?(KantoReloaded::Log)
        true
      rescue StandardError => e
        KantoReloaded::Log.exception("Overworld Menu install failed", e, channel: :modules) if defined?(KantoReloaded::Log)
        false
      end

      def register_options
        return unless defined?(KantoReloaded::Settings)
        KantoReloaded::Settings.register(ENABLED_SETTING, {
          :name => "Overworld Menu",
          :description => "Enables the quick-access Overworld Menu while walking around.",
          :type => :toggle,
          :category => :interface,
          :scope => :global,
          :owner => :kanto_reloaded,
          :value_style => :integer,
          :default => 1,
          :priority => 70
        })
      rescue StandardError => e
        KantoReloaded::Log.exception("Failed to register Overworld Menu options", e, channel: :options) if defined?(KantoReloaded::Log)
      end

      def migrate_legacy_settings
        return unless defined?(KantoReloaded::SaveData)
        return if KantoReloaded::SaveData.get(:overworld_menu, LEGACY_MIGRATION_KEY, false, section: :systems)
        if defined?($PokemonSystem) && $PokemonSystem
          enabled = $PokemonSystem.instance_variable_get(:@hr_om_enabled)
          unless enabled.nil? || KantoReloaded::Settings.stored?(ENABLED_SETTING)
            enabled_value = enabled == true || (enabled.respond_to?(:to_i) && enabled.to_i == 1) ? 1 : 0
            KantoReloaded::Settings.set(ENABLED_SETTING, enabled_value)
          end
          party = $PokemonSystem.instance_variable_get(:@hr_om_party_view)
          OverworldMenu.party_view = party unless party.nil?
        end
        KantoReloaded::SaveData.set(:overworld_menu, LEGACY_MIGRATION_KEY, true, section: :systems)
      end

      def migrate_setting_key
        return unless defined?(KantoReloaded::SaveData) && defined?(KantoReloaded::Settings)
        return if KantoReloaded::SaveData.get(:overworld_menu, SETTING_KEY_MIGRATION, false, section: :systems)
        unless KantoReloaded::Settings.stored?(ENABLED_SETTING)
          if KantoReloaded::Settings.stored?(:overworld_menu_enabled)
            value = KantoReloaded::Settings.get(:overworld_menu_enabled, 1)
            KantoReloaded::Settings.set(ENABLED_SETTING, value, :notify => false)
          elsif defined?(ModSettingsMenu) && ModSettingsMenu.respond_to?(:get)
            value = ModSettingsMenu.get(:overworld_menu) rescue nil
            KantoReloaded::Settings.set(ENABLED_SETTING, value, :notify => false) unless value.nil?
          end
        end
        KantoReloaded::SaveData.set(:overworld_menu, SETTING_KEY_MIGRATION, true, section: :systems)
      rescue StandardError => e
        KantoReloaded::Log.exception("Overworld Menu setting migration failed", e, channel: :modules) if defined?(KantoReloaded::Log)
        false
      end

      def register_events
        return unless defined?(KantoReloaded::Events)
        KantoReloaded::Events.on(:kanto_reloaded_save_loaded, :overworld_menu_legacy_migration, priority: 150) do |_context|
          KantoReloaded::OverworldMenuFeature.migrate_setting_key
          KantoReloaded::OverworldMenuFeature.migrate_legacy_settings
        end
        KantoReloaded::Events.on(:kanto_reloaded_save_new_game, :overworld_menu_legacy_migration, priority: 150) do |_context|
          KantoReloaded::OverworldMenuFeature.migrate_setting_key
          KantoReloaded::OverworldMenuFeature.migrate_legacy_settings
        end
      end
    end
  end
end

legacy_overworld_menu_entries = []
if defined?(OverworldMenu) && OverworldMenu.respond_to?(:registry)
  legacy_overworld_menu_entries = Array(OverworldMenu.registry).dup rescue []
end
KantoReloaded.const_set(:LEGACY_OVERWORLD_MENU_ENTRIES, legacy_overworld_menu_entries) unless KantoReloaded.const_defined?(:LEGACY_OVERWORLD_MENU_ENTRIES, false)

module OverworldMenuConfig
  PRIORITIES = {
    :quick_save => 1,
    :quick_items => 5,
    :repel_counter => 10,
    :time_changer => 20,
    :om_features => 999
  }.freeze

  def self.get_priority(key, default = 99)
    PRIORITIES[key.to_sym] || default
  end
end

module OverworldMenu
  SAVE_SYSTEM = :overworld_menu
  LOCKED_ENTRY_KEYS = [:om_features].freeze
  QUICK_ITEM_LIMIT = 5

  TRIGGER_BUTTON = if Input.const_defined?(:AUX2)
                     Input::AUX2
                   elsif Input.const_defined?(:F5)
                     Input::F5
                   else
                     Input::SPECIAL
                   end

  @registry = []
  @legacy_registrations = KantoReloaded::LEGACY_OVERWORLD_MENU_ENTRIES.dup
  @fallback_pages = nil
  @fallback_page_index = 0

  class << self
    def register(key, options = nil, **keywords, &block)
      data = options.is_a?(Hash) ? options.dup : {}
      keywords.each { |name, value| data[name] = value }
      data[:handler] ||= block
      key = key.to_sym rescue nil
      unless key
        log_warning("Overworld Menu registration rejected: key must be Symbol-like")
        return false
      end
      label = data[:label] || data["label"]
      handler = data[:handler] || data["handler"]
      priority = data.has_key?(:priority) ? data[:priority] : (data["priority"] || 99)
      condition = data[:condition] || data["condition"]
      exit_on_select = data.has_key?(:exit_on_select) ? data[:exit_on_select] : data["exit_on_select"]
      status = data[:status] || data["status"]
      status_color = data[:status_color] || data["status_color"]
      default_enabled = if data.has_key?(:default_enabled)
                          data[:default_enabled]
                        elsif data.has_key?("default_enabled")
                          data["default_enabled"]
                        else
                          true
                        end
      unless label.is_a?(String) && !label.empty?
        log_warning("Overworld Menu registration rejected for #{key}: label must be a non-empty String")
        return false
      end
      unless handler.respond_to?(:call)
        log_warning("Overworld Menu registration rejected for #{key}: handler must respond to call")
        return false
      end
      if @registry.any? { |entry| entry[:key] == key }
        log_warning("Overworld Menu registration skipped duplicate key=#{key}")
        return false
      end
      @registry << {
        :key => key,
        :label => label,
        :handler => handler,
        :priority => OverworldMenuConfig.get_priority(key, priority).to_i,
        :condition => condition || proc { true },
        :exit_on_select => !!exit_on_select,
        :status => status,
        :status_color => status_color,
        :default_enabled => !!default_enabled
      }
      @registry.sort_by! { |entry| [entry[:priority], entry[:label].to_s] }
      log_debug("Registered Overworld Menu entry #{key} priority=#{priority}")
      true
    rescue StandardError => e
      log_exception("Overworld Menu registration failed", e)
      false
    end

    def import_legacy_registrations
      pending = Array(@legacy_registrations)
      [:$OVERWORLD_MENU_PENDING_REGISTRATIONS, :$overworld_menu_pending_registrations].each do |global_name|
        pending.concat(Array(eval(global_name.to_s))) if global_variables.include?(global_name)
      end
      pending.each do |entry|
        next unless entry
        if entry.is_a?(Hash)
          key = entry[:key] || entry["key"]
          register(key, entry) if key
        elsif entry.is_a?(Array)
          register(*entry)
        end
      end
      @legacy_registrations = []
      $OVERWORLD_MENU_PENDING_REGISTRATIONS = [] if defined?($OVERWORLD_MENU_PENDING_REGISTRATIONS)
      $overworld_menu_pending_registrations = [] if defined?($overworld_menu_pending_registrations)
      true
    rescue StandardError => e
      log_exception("Legacy Overworld Menu registration import failed", e)
      false
    end

    def registry
      @registry
    end

    def available_entries
      @registry.select { |entry| entry[:condition].call rescue false }
    end

    def sorted_available_entries
      available_entries.sort_by { |entry| [entry[:priority].to_i, entry[:label].to_s] }
    end

    def all_registered_entries
      @registry.sort_by { |entry| [entry[:priority].to_i, entry[:label].to_s] }
    end

    def all_registered_keys
      all_registered_entries.map { |entry| entry[:key] }
    end

    def default_pages
      [{
        "name" => "Main",
        "entries" => all_registered_keys.map { |key| key.to_s },
        "disabled_entries" => default_disabled_keys.map { |key| key.to_s }
      }]
    end

    def pages
      raw = if defined?(KantoReloaded::SaveData)
              KantoReloaded::SaveData.get(SAVE_SYSTEM, :pages, nil, section: :systems)
            else
              @fallback_pages
            end
      normalized = normalize_pages(raw)
      self.pages = normalized if raw != normalized
      normalized
    rescue StandardError => e
      log_exception("Overworld Menu pages failed to load", e)
      default_pages
    end

    def pages=(value)
      normalized = normalize_pages(value)
      if defined?(KantoReloaded::SaveData)
        KantoReloaded::SaveData.set(SAVE_SYSTEM, :pages, normalized, section: :systems)
      else
        @fallback_pages = normalized
      end
      normalized
    end

    def page_index
      value = if defined?(KantoReloaded::SaveData)
                KantoReloaded::SaveData.get(SAVE_SYSTEM, :page_index, 0, section: :systems)
              else
                @fallback_page_index
              end
      value.to_i
    rescue
      0
    end

    def page_index=(value)
      normalized = value.to_i
      normalized = 0 if normalized < 0
      if defined?(KantoReloaded::SaveData)
        KantoReloaded::SaveData.set(SAVE_SYSTEM, :page_index, normalized, section: :systems)
      else
        @fallback_page_index = normalized
      end
      normalized
    end

    def quick_items
      raw = if defined?(KantoReloaded::SaveData)
              KantoReloaded::SaveData.get(SAVE_SYSTEM, :quick_items, [], section: :systems)
            else
              @fallback_quick_items ||= []
            end
      normalize_quick_items(raw)
    rescue
      []
    end

    def quick_items=(value)
      normalized = normalize_quick_items(value)
      if defined?(KantoReloaded::SaveData)
        KantoReloaded::SaveData.set(SAVE_SYSTEM, :quick_items, normalized.map { |item| item ? item.to_s : nil }, section: :systems)
      else
        @fallback_quick_items = normalized
      end
      normalized
    end

    def quick_item_eligible?(item)
      item = normalize_item(item)
      return false unless item
      data = GameData::Item.get(item) rescue nil
      return false unless data
      return true if pokevial_quick_item?(item)
      return true if ItemHandlers.hasOutHandler(item)
      return true if data.is_machine? && $Trainer && $Trainer.party.length > 0
      false
    rescue
      false
    end

    def pokevial_quick_item?(item)
      return false unless defined?(ReloadedPokeVial) && ReloadedPokeVial.respond_to?(:item_id?)
      return false unless defined?(ItemHandlers)
      return false unless ItemHandlers.const_defined?(:UseFromBag)
      ReloadedPokeVial.item_id?(item) && !!ItemHandlers::UseFromBag[item]
    rescue
      false
    end

    def usable_quick_items
      quick_items.compact.select { |item| item_available?(item) && quick_item_eligible?(item) }
    end

    def normalize_item(item)
      GameData::Item.get(item).id rescue nil
    end

    def item_available?(item)
      item = normalize_item(item)
      item && $PokemonBag && $PokemonBag.pbHasItem?(item)
    rescue
      false
    end

    def pinned?(key, page_idx = page_index)
      page = pages[page_idx.to_i] || pages.first
      normalized = key.to_sym
      page_entries(page).include?(normalized) && !page_disabled_entries(page).include?(normalized)
    rescue
      false
    end

    def menu_pages_for_display
      source_pages = pages
      available = sorted_available_entries
      built = []
      source_pages.each_with_index do |page, idx|
        entries = entries_for_page(page, available)
        next if idx > 0 && entries.empty?
        built << {
          :index => idx,
          :name => page_name(page, idx),
          :entries => entries
        }
      end
      if built.empty?
        built << { :index => 0, :name => "Main", :entries => available }
      end
      built
    end

    def entries_for_page(page, available = sorted_available_entries)
      keys = page_entries(page)
      disabled = page_disabled_entries(page)
      by_key = {}
      available.each { |entry| by_key[entry[:key]] = entry }
      keys.reject { |key| disabled.include?(key) }.map { |key| by_key[key] }.compact
    end

    def page_entries(page)
      Array(page["entries"] || page[:entries]).map { |key| key.to_sym rescue nil }.compact.uniq
    end

    def page_disabled_entries(page)
      Array(page["disabled_entries"] || page[:disabled_entries]).map { |key| key.to_sym rescue nil }.compact.uniq
    end

    def page_name(page, index)
      name = (page["name"] || page[:name]).to_s.strip
      name.empty? ? "Page #{index + 1}" : name
    end

    def locked_entry?(key)
      LOCKED_ENTRY_KEYS.include?(key.to_sym)
    end

    def enabled?
      value = KantoReloaded::Settings.get(KantoReloaded::OverworldMenuFeature::ENABLED_SETTING, 1)
      value == true || (value.respond_to?(:to_i) && value.to_i == 1)
    rescue
      true
    end

    def party_view
      value = if defined?(KantoReloaded::SaveData)
                KantoReloaded::SaveData.get(SAVE_SYSTEM, :party_view, false, section: :systems)
              else
                @fallback_party_view
              end
      !!value
    rescue
      false
    end

    def party_view=(value)
      normalized = value == true || (value.respond_to?(:to_i) && value.to_i == 1)
      if defined?(KantoReloaded::SaveData)
        KantoReloaded::SaveData.set(SAVE_SYSTEM, :party_view, normalized, section: :systems)
      else
        @fallback_party_view = normalized
      end
      normalized
    end

    def open
      scene = OverworldMenuScene.new
      screen = OverworldMenuScreen.new(scene)
      screen.open
    end

    def can_open?
      return false unless enabled?
      return false unless defined?($Trainer) && $Trainer
      return false if $game_temp && (($game_temp.in_menu rescue false) || ($game_temp.in_battle rescue false) || ($game_temp.message_window_showing rescue false))
      return false if $game_player && ($game_player.moving? rescue false)
      true
    rescue
      false
    end

    def log_info(message)
      KantoReloaded::Log.info(message, :modules) if defined?(KantoReloaded::Log)
    rescue
    end

    def log_warning(message)
      KantoReloaded::Log.warning(message, :modules) if defined?(KantoReloaded::Log)
    rescue
    end

    def log_debug(message)
      KantoReloaded::Log.debug(message, :modules) if defined?(KantoReloaded::Log)
    rescue
    end

    def log_exception(message, error)
      KantoReloaded::Log.exception(message, error, channel: :modules) if defined?(KantoReloaded::Log)
    rescue
    end

    private

    def normalize_pages(value)
      registered_keys = all_registered_keys
      raw_pages = Array(value)
      known_keys = raw_pages.flat_map do |page|
        next [] unless page.is_a?(Hash)
        Array(page["entries"] || page[:entries]) + Array(page["disabled_entries"] || page[:disabled_entries])
      end.map { |key| key.to_sym rescue nil }.compact.uniq
      missing_default_disabled = default_disabled_keys - known_keys
      pages = raw_pages.map.with_index do |page, index|
        next nil unless page.is_a?(Hash)
        name = (page["name"] || page[:name]).to_s.strip
        entries = Array(page["entries"] || page[:entries]).map { |key| key.to_sym rescue nil }.compact.uniq
        disabled = Array(page["disabled_entries"] || page[:disabled_entries]).map { |key| key.to_sym rescue nil }.compact.uniq
        if index == 0
          entries = (entries & registered_keys) + (registered_keys - entries)
          disabled |= missing_default_disabled
          disabled -= LOCKED_ENTRY_KEYS
        else
          entries &= registered_keys
        end
        {
          "name" => name.empty? ? (index == 0 ? "Main" : "Page #{index + 1}") : name,
          "entries" => entries.map { |key| key.to_s },
          "disabled_entries" => disabled.map { |key| key.to_s }
        }
      end.compact
      pages = default_pages if pages.empty?
      pages[0]["name"] = "Main" if pages[0]["name"].to_s.strip.empty?
      main_entries = Array(pages[0]["entries"]).map { |key| key.to_sym rescue nil }.compact
      pages[0]["entries"] = ((main_entries & registered_keys) + (registered_keys - main_entries)).uniq.map { |key| key.to_s }
      pages[0]["disabled_entries"] = (Array(pages[0]["disabled_entries"]).map { |key| key.to_sym rescue nil }.compact - LOCKED_ENTRY_KEYS).uniq.map { |key| key.to_s }
      pages
    end

    def default_disabled_keys
      all_registered_entries.reject { |entry| entry.fetch(:default_enabled, true) }.map { |entry| entry[:key] }
    end

    def normalize_quick_items(value)
      normalized = []
      seen = []
      Array(value).first(QUICK_ITEM_LIMIT).each do |item|
        item_id = normalize_item(item)
        if item_id && !seen.include?(item_id)
          normalized << item_id
          seen << item_id
        else
          normalized << nil
        end
      end
      normalized << nil while normalized.length < QUICK_ITEM_LIMIT
      normalized
    end
  end
end

KantoReloaded.const_set(:OverworldMenu, OverworldMenu) unless KantoReloaded.const_defined?(:OverworldMenu, false)
KantoReloaded::OverworldMenuFeature.install if defined?(KantoReloaded::OverworldMenuFeature)

module KantoReloaded
  class OverworldPokemonIconSprite < PokemonIconSprite
    def use_big_icon?
      false
    end
  end
end

class OverworldMenuScene
  # Match Hoenn Reloaded's overlay coordinate space exactly. KIF may expose a
  # larger render size, but this menu is intentionally laid out at 512x384.
  SW = 512
  SH = 384

  PANEL_W = 182
  PANEL_X = SW - PANEL_W - 3
  PANEL_Y = 3
  HDR_H = 22
  ROW_H = 18
  MAX_ROWS = 10
  PAD = 6

  PARTY_X = 3
  SLOT_COLS = 2
  SLOT_H = 71

  C_BG = Color.new(16, 20, 38, 225)
  C_HDR = Color.new(22, 26, 54, 255)
  C_BORDER = Color.new(55, 75, 160, 255)
  C_SEL = Color.new(44, 64, 148, 215)
  C_WHITE = Color.new(255, 255, 255)
  C_GRAY = Color.new(158, 163, 190)
  C_DIM = Color.new(88, 93, 118)
  C_GOLD = Color.new(228, 188, 58)
  C_SHADOW = Color.new(0, 0, 0, 0)
  C_HP_OK = Color.new(64, 200, 64)
  C_HP_WARN = Color.new(255, 200, 64)
  C_HP_LOW = Color.new(255, 64, 64)
  C_HP_BG = Color.new(38, 38, 38)
  C_SLOT_BG = Color.new(28, 34, 56, 180)

  POPUP_W = 260

  def initialize
    @vp = Viewport.new(0, 0, SW, SH)
    @vp.z = 99999
    @menu_spr = Sprite.new(@vp)
    @menu_spr.z = 10
    @party_spr = Sprite.new(@vp)
    @party_spr.z = 10
    @popup_spr = nil
    @icon_sprites = []
    @party_view = false
    @last_h = 0
    @last_ph = 0
  end

  def setup(party_view: false)
    @party_view = party_view
    if @party_view
      build_icon_sprites
    else
      dispose_icon_sprites
      @party_spr.visible = false
    end
  end

  def max_visible
    MAX_ROWS
  end

  def draw(entries, cursor, scroll = 0, page_position: 0, page_count: 1)
    vis = [[entries.length - scroll, MAX_ROWS].min, 0].max
    panel_h = HDR_H + [vis, 1].max * ROW_H + 4
    if panel_h != @last_h
      @menu_spr.bitmap.dispose rescue nil
      @menu_spr.bitmap = Bitmap.new(PANEL_W, panel_h)
      @last_h = panel_h
    end
    b = @menu_spr.bitmap
    b.clear
    title = page_count > 1 ? "OVERWORLD MENU #{page_position + 1}/#{page_count}" : "OVERWORLD MENU"
    draw_panel_bg(b, PANEL_W, panel_h, title)
    if entries.empty?
      pbSetSmallFont(b)
      b.font.size = 15
      pbDrawShadowText(b, PAD + 2, HDR_H + 4, PANEL_W - PAD * 2, ROW_H - 2, "No entries", C_DIM, C_SHADOW, 1)
    else
      vis.times do |i|
        idx = scroll + i
        break if idx >= entries.length
        y = HDR_H + 2 + i * ROW_H
        selected = idx == cursor
        b.fill_rect(2, y, PANEL_W - 4, ROW_H - 2, C_SEL) if selected
        pbSetSmallFont(b)
        b.font.size = 15
        color = selected ? C_WHITE : C_GRAY
        status = entry_status_text(entries[idx])
        if status.empty?
          pbDrawShadowText(b, PAD + 2, y, PANEL_W - PAD * 2, ROW_H - 2, entries[idx][:label].to_s, color, C_SHADOW)
        else
          measured_status_w = b.text_size(status).width rescue 18
          status_w = [[measured_status_w + 8, 24].max, PANEL_W / 3].min
          label_w = PANEL_W - PAD * 2 - status_w - 4
          pbDrawShadowText(b, PAD + 2, y, label_w, ROW_H - 2, entries[idx][:label].to_s, color, C_SHADOW)
          pbDrawShadowText(b, PANEL_W - PAD - status_w, y, status_w, ROW_H - 2, status, entry_status_color(entries[idx]), C_SHADOW, 2)
        end
      end
    end
    if page_count > 1
      pbSetSmallFont(b)
      b.font.size = 11
      pbDrawShadowText(b, 3, 5, 18, 12, "<", C_DIM, C_SHADOW, 0) if page_position > 0
      pbDrawShadowText(b, PANEL_W - 21, 5, 18, 12, ">", C_DIM, C_SHADOW, 2) if page_position < page_count - 1
    end
    if scroll > 0
      pbSetSmallFont(b)
      b.font.size = 11
      pbDrawShadowText(b, 0, HDR_H, PANEL_W, 10, "\u25B2", C_DIM, C_SHADOW, 1)
    end
    if scroll + MAX_ROWS < entries.length
      pbSetSmallFont(b)
      b.font.size = 11
      pbDrawShadowText(b, 0, HDR_H + [vis, 1].max * ROW_H - 2, PANEL_W, 10, "\u25BC", C_DIM, C_SHADOW, 1)
    end
    @menu_spr.x = PANEL_X
    @menu_spr.y = PANEL_Y
    draw_party_panel if @party_view
  end

  def entry_status_text(entry)
    status = entry[:status]
    status = status.call if status.respond_to?(:call)
    status.to_s.strip
  rescue
    ""
  end

  def entry_status_color(entry)
    color = entry[:status_color]
    color = color.call if color.respond_to?(:call)
    color || C_HP_OK
  rescue
    C_HP_OK
  end

  def party_panel_h
    HDR_H + 4 + 3 * SLOT_H
  end

  def draw_party_panel
    party_w = PANEL_X - PARTY_X - 4
    return if party_w < 80
    ph = party_panel_h
    slot_w = (party_w - 2) / SLOT_COLS
    if ph != @last_ph
      @party_spr.bitmap.dispose rescue nil
      @party_spr.bitmap = Bitmap.new(party_w, ph)
      @last_ph = ph
    end
    b = @party_spr.bitmap
    b.clear
    draw_panel_bg(b, party_w, ph, "PARTY")
    @party_spr.x = PARTY_X
    @party_spr.y = PANEL_Y
    types_bmp = Bitmap.new("Graphics/Pictures/Battle/typesSmall") rescue nil
    statuses_bmp = Bitmap.new("Graphics/Pictures/statuses") rescue nil
    shiny_bmp = Bitmap.new("Mods/KantoReloaded/Graphics/Icons/shiny") rescue nil
    party = ($Trainer.party rescue []) || []
    party.each_with_index do |pkmn, i|
      next unless pkmn
      col = i % SLOT_COLS
      row = i / SLOT_COLS
      sx = 1 + col * slot_w
      sy = HDR_H + 2 + row * SLOT_H
      lx = sx + 60
      tw = slot_w - 62
      b.fill_rect(sx + 1, sy + 1, slot_w - 3, SLOT_H - 3, C_SLOT_BG)
      pbSetSmallFont(b)
      if pkmn.egg?
        b.font.size = 15
        pbDrawShadowText(b, lx, sy + (SLOT_H - 16) / 2, tw, 16, "EGG", C_GRAY, C_SHADOW, 1)
      else
        draw_party_pokemon_details(b, pkmn, sx, sy, lx, tw, types_bmp, statuses_bmp, shiny_bmp)
      end
      if @icon_sprites[i]
        @icon_sprites[i].x = @party_spr.x + sx + 28
        @icon_sprites[i].y = @party_spr.y + sy + 34
      end
    end
    types_bmp.dispose rescue nil
    statuses_bmp.dispose rescue nil
    shiny_bmp.dispose rescue nil
    @party_spr.visible = true
  end

  def draw_party_pokemon_details(bitmap, pkmn, sx, sy, lx, tw, types_bmp, statuses_bmp, shiny_bmp)
    gender_str = pkmn.gender == 0 ? "\u2642" : pkmn.gender == 1 ? "\u2640" : ""
    gender_col = pkmn.gender == 0 ? Color.new(100, 160, 255) : Color.new(255, 120, 160)
    name_w = tw - (gender_str.empty? ? 0 : 14)
    bitmap.font.size = 15
    bitmap.font.bold = true
    pbDrawShadowText(bitmap, lx, sy + 3, name_w, 16, pkmn.name.to_s, C_WHITE, C_SHADOW)
    bitmap.font.bold = false
    unless gender_str.empty?
      bitmap.font.size = 13
      pbDrawShadowText(bitmap, lx + name_w, sy + 4, 14, 14, gender_str, gender_col, C_SHADOW, 1)
    end
    if pkmn.shiny? && shiny_bmp
      bitmap.stretch_blt(Rect.new(sx + 44, sy + 6, 11, 11), shiny_bmp, Rect.new(0, 0, shiny_bmp.width, shiny_bmp.height))
    end
    bitmap.font.size = 13
    pbDrawShadowText(bitmap, lx, sy + 21, 36, 14, "Lv #{pkmn.level}", C_GOLD, C_SHADOW)
    type_x = lx + 35
    if types_bmp
      [pkmn.type1, pkmn.type2, (pkmn.type3 rescue nil)].compact.uniq.first(3).each do |type_symbol|
        type_id = GameData::Type.get(type_symbol).id_number rescue nil
        next unless type_id
        bitmap.stretch_blt(Rect.new(type_x, sy + 23, 14, 14), types_bmp, Rect.new(0, type_id * 19, 19, 19))
        type_x += 16
      end
    end
    hp_pct = pkmn.totalhp > 0 ? pkmn.hp.to_f / pkmn.totalhp : 0.0
    hp_col = hp_pct > 0.5 ? C_HP_OK : (hp_pct > 0.25 ? C_HP_WARN : C_HP_LOW)
    bitmap.fill_rect(lx, sy + 41, tw, 5, C_HP_BG)
    bitmap.fill_rect(lx, sy + 41, (tw * hp_pct).to_i, 5, hp_col)
    hp_str = "#{pkmn.hp}/#{pkmn.totalhp}"
    hp_str_w = bitmap.text_size(hp_str).width rescue 40
    pbDrawShadowText(bitmap, lx, sy + 45, tw, 14, hp_str, hp_col, C_SHADOW)
    draw_status_icon(bitmap, pkmn, statuses_bmp, lx + hp_str_w + 4, sy + 48) if statuses_bmp
    draw_held_item_icon(bitmap, pkmn, sx + 2, sy + 42)
  end

  def draw_status_icon(bitmap, pkmn, statuses_bmp, x, y)
    status_idx = nil
    if pkmn.fainted?
      status_idx = GameData::Status::DATA.keys.length / 2
    elsif pkmn.status != :NONE
      status_idx = GameData::Status.get(pkmn.status).id_number rescue nil
    elsif pkmn.pokerusStage == 1
      status_idx = GameData::Status::DATA.keys.length / 2 + 1
    end
    return unless status_idx && status_idx > 0
    bitmap.stretch_blt(Rect.new(x, y, 27, 10), statuses_bmp, Rect.new(0, 16 * (status_idx - 1), 44, 16))
  rescue
  end

  def draw_held_item_icon(bitmap, pkmn, x, y)
    item_id = pkmn.item rescue 0
    return if item_id.nil? || item_id == 0
    path = GameData::Item.icon_filename(item_id) rescue nil
    return unless path
    item_bmp = Bitmap.new(path) rescue nil
    return unless item_bmp
    bitmap.stretch_blt(Rect.new(x, y, 19, 19), item_bmp, Rect.new(0, 0, item_bmp.width, item_bmp.height))
  ensure
    item_bmp.dispose rescue nil
  end

  def show_popup(title, lines)
    with_popup(title, lines, dismissible: true) { |_spr| wait_dismiss }
  end

  def show_time_changer(on_change: nil)
    hour = (pbGetTimeNow rescue Time.now).hour
    hint = "Up/Down: Hour   Confirm (A)   Close (B)  ||  Applied on confirm"
    build = proc { |h| ["", "{big}#{sprintf('%02d:00', h)}", ""] }
    with_popup("TIME CHANGER", build.call(hour), dismissible: false) do |spr|
      redraw_popup(spr, "TIME CHANGER", build.call(hour) + [hint])
      loop do
        Graphics.update
        Input.update
        if Input.repeat?(Input::UP)
          hour = (hour + 1) % 24
          redraw_popup(spr, "TIME CHANGER", build.call(hour) + [hint])
          pbPlayCursorSE
        elsif Input.repeat?(Input::DOWN)
          hour = (hour - 1) % 24
          redraw_popup(spr, "TIME CHANGER", build.call(hour) + [hint])
          pbPlayCursorSE
        elsif Input.trigger?(Input::USE) || input_c?
          on_change.call(hour) if on_change
          pbUpdateSceneMap rescue nil
          pbPlayDecisionSE
          break
        elsif Input.trigger?(Input::BACK)
          pbPlayCancelSE
          break
        end
      end
    end
  end

  def show_features_menu(party_view_on)
    cursor = 0
    result = nil
    build_items = proc { ["Party View: #{party_view_on ? 'ON ' : 'OFF'}", "Customize Pages", "Back"] }
    with_popup("OVERWORLD MENU FEATURES", [], dismissible: false) do |spr|
      loop do
        items = build_items.call
        redraw_features(spr, items, cursor)
        Graphics.update
        Input.update
        if Input.repeat?(Input::UP)
          cursor = (cursor - 1) % items.length
          pbPlayCursorSE
        elsif Input.repeat?(Input::DOWN)
          cursor = (cursor + 1) % items.length
          pbPlayCursorSE
        elsif Input.trigger?(Input::USE) || input_c?
          if cursor == 0
            party_view_on = !party_view_on
            toggle_party_view(party_view_on)
            result = { :party_view => party_view_on }
            pbPlayDecisionSE
          elsif cursor == 1
            result = { :customize_pages => true, :party_view => party_view_on }
            pbPlayDecisionSE
            break
          else
            pbPlayCancelSE
            break
          end
        elsif Input.trigger?(Input::BACK)
          pbPlayCancelSE
          break
        end
      end
    end
    result
  end

  def show_quick_items_menu(screen)
    loop do
      quick_items = OverworldMenu.usable_quick_items
      labels = quick_items.map { |item| quick_item_label(item) }
      manage_index = labels.length
      labels << "Manage Slots"
      labels << "Back"
      choice = show_popup_menu("QUICK ITEMS", labels)
      return nil if choice.nil? || choice == labels.length - 1
      if choice == manage_index
        manage_quick_items
        next
      end
      item = quick_items[choice]
      return screen.use_quick_item(item) if item
    end
  end

  def manage_quick_items
    loop do
      slots = OverworldMenu.quick_items
      labels = []
      OverworldMenu::QUICK_ITEM_LIMIT.times do |i|
        item = slots[i]
        labels << "Slot #{i + 1}: #{item ? quick_item_label(item) : 'Empty'}"
      end
      labels << "Back"
      choice = show_popup_menu("QUICK ITEM SLOTS", labels)
      return if choice.nil? || choice >= OverworldMenu::QUICK_ITEM_LIMIT
      edit_quick_item_slot(choice)
    end
  end

  def edit_quick_item_slot(index)
    slots = OverworldMenu.quick_items
    item = slots[index]
    commands = item ? ["Change Item", "Clear Slot", "Back"] : ["Set Item", "Back"]
    choice = show_popup_menu("QUICK ITEM SLOT #{index + 1}", commands)
    return if choice.nil?
    if item && choice == 1
      slots[index] = nil
      OverworldMenu.quick_items = slots
      pbPlayDecisionSE
      return
    end
    return if choice >= (item ? 2 : 1)
    chosen = choose_quick_item_from_bag
    return unless chosen
    slots[index] = chosen
    OverworldMenu.quick_items = slots
    pbPlayDecisionSE
  end

  def quick_item_label(item)
    data = GameData::Item.get(item) rescue nil
    return item.to_s if !data
    return data.name if data.is_important?
    qty = $PokemonBag.pbQuantity(data.id) rescue 0
    "#{data.name} x#{qty}"
  end

  def choose_quick_item_from_bag
    has_candidates = false
    ($PokemonBag.pockets rescue []).each do |pocket|
      Array(pocket).each do |slot|
        next unless slot && OverworldMenu.quick_item_eligible?(slot[0])
        has_candidates = true
        break
      end
      break if has_candidates
    end
    unless has_candidates
      show_popup("QUICK ITEMS", ["No usable items are in the Bag."])
      return nil
    end
    item = nil
    filter = proc { |candidate| OverworldMenu.quick_item_eligible?(candidate) }
    with_overlay_hidden do
      pbFadeOutIn do
        scene = PokemonBag_Scene.new
        begin
          scene.pbStartScene($PokemonBag, true, filter)
          item = scene.pbChooseItem
        ensure
          scene.pbEndScene rescue nil
        end
      end
    end
    item ? OverworldMenu.normalize_item(item) : nil
  end

  def show_popup_menu(title, labels)
    return nil if labels.empty?
    cursor = 0
    width = POPUP_W
    row_h = 20
    height = 30 + labels.length * row_h + 8
    sprite = Sprite.new(@vp)
    sprite.z = 55
    sprite.x = (SW - width) / 2
    sprite.y = (SH - height) / 2
    redraw_popup_menu(sprite, title, labels, cursor, width, height, row_h)
    loop do
      Graphics.update
      Input.update
      if Input.repeat?(Input::UP)
        cursor = (cursor - 1) % labels.length
        pbPlayCursorSE
        redraw_popup_menu(sprite, title, labels, cursor, width, height, row_h)
      elsif Input.repeat?(Input::DOWN)
        cursor = (cursor + 1) % labels.length
        pbPlayCursorSE
        redraw_popup_menu(sprite, title, labels, cursor, width, height, row_h)
      elsif Input.trigger?(Input::USE) || input_c?
        return cursor
      elsif Input.trigger?(Input::BACK)
        pbPlayCancelSE
        return nil
      end
    end
  ensure
    sprite.bitmap.dispose rescue nil
    sprite.dispose rescue nil
    Input.update rescue nil
  end

  def redraw_popup_menu(sprite, title, labels, cursor, width, height, row_h)
    sprite.bitmap.dispose rescue nil
    bitmap = Bitmap.new(width, height)
    draw_panel_bg(bitmap, width, height, title)
    pbSetSmallFont(bitmap)
    labels.each_with_index do |label, i|
      y = 28 + i * row_h
      selected = i == cursor
      bitmap.fill_rect(2, y, width - 4, row_h - 2, C_SEL) if selected
      bitmap.font.size = 15
      color = selected ? C_WHITE : C_GRAY
      pbDrawShadowText(bitmap, PAD + 2, y + 2, width - PAD * 2, row_h - 4, label, color, C_SHADOW)
    end
    sprite.bitmap = bitmap
    Graphics.update
  end

  def dispose
    dispose_icon_sprites
    [@menu_spr, @party_spr, @popup_spr].each do |sprite|
      next unless sprite
      sprite.bitmap.dispose rescue nil
      sprite.dispose rescue nil
    end
    @vp.dispose rescue nil
  end

  def toggle_party_view(value)
    @party_view = value
    if value
      build_icon_sprites
      @last_ph = 0
      draw_party_panel
    else
      dispose_icon_sprites
      @party_spr.bitmap.dispose rescue nil
      @party_spr.visible = false
      @last_ph = 0
    end
    Graphics.update
  end

  def update_icons
    @icon_sprites.each { |sprite| sprite.update rescue nil }
  end

  def run_with_overlay_hidden
    with_overlay_hidden { yield }
  end

  private

  def with_overlay_hidden
    menu_visible = @menu_spr.visible rescue true
    party_visible = @party_spr.visible rescue false
    @menu_spr.visible = false rescue nil
    @party_spr.visible = false rescue nil
    @icon_sprites.each { |sprite| sprite.visible = false rescue nil }
    yield
  ensure
    @menu_spr.visible = menu_visible rescue nil
    @party_spr.visible = party_visible rescue nil
    @icon_sprites.each { |sprite| sprite.visible = @party_view rescue nil }
    Graphics.update rescue nil
  end

  def input_c?
    Input.const_defined?(:C) && Input.trigger?(Input::C)
  rescue
    false
  end

  def draw_panel_bg(bitmap, width, height, title)
    if defined?(KantoReloaded::UI::QuickMenuStyle)
      KantoReloaded::UI::QuickMenuStyle.draw_panel(bitmap, width, height, title)
    end
  end

  def popup_h(lines)
    30 + lines.length * 18 + 6
  end

  def build_popup_bitmap(title, lines)
    height = popup_h(lines)
    bitmap = Bitmap.new(POPUP_W, height)
    draw_panel_bg(bitmap, POPUP_W, height, title)
    pbSetSmallFont(bitmap)
    lines.each_with_index do |line, i|
      y = 30 + i * 18
      text = line.to_s
      big = text.start_with?("{big}")
      text = text[5, text.length] if big
      bitmap.font.size = big ? 17 : 13
      if text.include?("||")
        bitmap.fill_rect(2, y - 2, POPUP_W - 4, 1, C_BORDER)
        parts = text.split("||", 2)
        pbDrawShadowText(bitmap, PAD, y, POPUP_W - PAD * 2, 18, parts[0].strip, C_DIM, C_SHADOW, 0)
        pbDrawShadowText(bitmap, PAD, y, POPUP_W - PAD * 2, 18, parts[1].strip, C_WHITE, C_SHADOW, 2)
      else
        pbDrawShadowText(bitmap, PAD, y, POPUP_W - PAD * 2, 18, text, C_GRAY, C_SHADOW, 1)
      end
    end
    bitmap
  end

  def with_popup(title, lines, dismissible: true)
    height = [popup_h(lines), 60].max
    x = (SW - POPUP_W) / 2
    y = (SH - height) / 2
    sprite = Sprite.new(@vp)
    sprite.z = 50
    sprite.bitmap = build_popup_bitmap(title, lines)
    sprite.x = x
    sprite.y = y
    Graphics.update
    yield sprite
  ensure
    sprite.bitmap.dispose rescue nil
    sprite.dispose rescue nil
    Input.update
  end

  def redraw_popup(sprite, title, lines)
    sprite.bitmap.dispose rescue nil
    sprite.bitmap = build_popup_bitmap(title, lines)
    Graphics.update
  end

  def redraw_features(sprite, items, cursor)
    height = 30 + items.length * 20 + 4
    sprite.bitmap.dispose rescue nil
    bitmap = Bitmap.new(POPUP_W, height)
    draw_panel_bg(bitmap, POPUP_W, height, "OVERWORLD MENU FEATURES")
    pbSetSmallFont(bitmap)
    items.each_with_index do |label, i|
      y = 28 + i * 20
      selected = i == cursor
      bitmap.fill_rect(2, y, POPUP_W - 4, 18, C_SEL) if selected
      bitmap.font.size = 15
      color = selected ? C_WHITE : C_GRAY
      pbDrawShadowText(bitmap, PAD + 2, y + 2, POPUP_W - PAD * 2, 16, label, color, C_SHADOW)
    end
    sprite.bitmap = bitmap
    Graphics.update
  end

  def wait_dismiss
    loop do
      Graphics.update
      Input.update
      break if Input.trigger?(Input::USE) || Input.trigger?(Input::BACK) || input_c?
    end
  end

  def build_icon_sprites
    dispose_icon_sprites
    party = ($Trainer.party rescue []) || []
    party_w = PANEL_X - PARTY_X - 4
    slot_w = (party_w - 2) / SLOT_COLS
    party.each_with_index do |pkmn, i|
      next unless pkmn
      col = i % SLOT_COLS
      row = i / SLOT_COLS
      sprite = KantoReloaded::OverworldPokemonIconSprite.new(pkmn, @vp)
      sprite.setOffset(PictureOrigin::Center) rescue nil
      sprite.zoom_x = 0.82
      sprite.zoom_y = 0.82
      sprite.z = 15
      sprite.x = PARTY_X + 1 + col * slot_w + 28
      sprite.y = PANEL_Y + HDR_H + 2 + row * SLOT_H + 34
      @icon_sprites[i] = sprite
    end
  end

  def dispose_icon_sprites
    @icon_sprites.each { |sprite| sprite.dispose rescue nil }
    @icon_sprites.clear
  end
end

class OverworldMenuPageEditorScene
  SCREEN_W = 512
  SCREEN_H = 384
  ITEM_H = 26
  LIST_X = 16
  LIST_Y = 70
  LIST_W = 480
  BOX_SIZE = 12
  NUM_W = 24
  FOOTER_H = 24
  FOOTER_Y = SCREEN_H - FOOTER_H
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
    @entries = OverworldMenu.all_registered_entries
    return if @entries.empty?
    @pages = OverworldMenu.pages
    @page_index = OverworldMenu.page_index.clamp(0, [@pages.length - 1, 0].max)
    @cursor = 0
    @top_row = 0
    @dragging = false
    @running = true

    @vp = Viewport.new(0, 0, SCREEN_W, SCREEN_H)
    @vp.z = 100_000
    @bg_spr = BitmapSprite.new(SCREEN_W, SCREEN_H, @vp)
    @bg_spr.z = 5
    @list_spr = BitmapSprite.new(SCREEN_W, SCREEN_H, @vp)
    @list_spr.z = 10

    draw_bg
    draw_list
    loop do
      Graphics.update
      Input.update
      break unless @running
      handle_input
    end
  ensure
    persist_pages
    teardown
    Input.update rescue nil
  end

  private

  def current_page
    @pages[@page_index] ||= { "name" => "Page #{@page_index + 1}", "entries" => [], "disabled_entries" => [] }
  end

  def checked_order
    valid_keys = @entries.map { |entry| entry[:key] }
    disabled = disabled_order
    Array(current_page["entries"]).map { |key| key.to_sym rescue nil }.compact.uniq.select { |key| valid_keys.include?(key) && !disabled.include?(key) }
  end

  def checked_order=(value)
    selected = Array(value).map { |key| key.to_sym rescue nil }.compact.uniq
    if @page_index == 0
      current_page["entries"] = (selected + disabled_order).uniq.map { |key| key.to_s }
    else
      current_page["entries"] = selected.map { |key| key.to_s }
    end
  end

  def disabled_order
    valid_keys = @entries.map { |entry| entry[:key] }
    Array(current_page["disabled_entries"]).map { |key| key.to_sym rescue nil }.compact.uniq.select { |key| valid_keys.include?(key) }
  end

  def disabled_order=(value)
    disabled = Array(value).map { |key| key.to_sym rescue nil }.compact.uniq - OverworldMenu::LOCKED_ENTRY_KEYS
    current_page["disabled_entries"] = disabled.map { |key| key.to_s }
  end

  def sorted_items
    selected = checked_order
    active = selected.map { |key| @entries.find { |entry| entry[:key] == key } }.compact
    inactive = @entries.reject { |entry| selected.include?(entry[:key]) }
    active + inactive
  end

  def current_page_name
    OverworldMenu.page_name(current_page, @page_index)
  end

  def draw_bg
    b = @bg_spr.bitmap
    b.clear
    b.fill_rect(0, 0, SCREEN_W, SCREEN_H, C_BG)
    pbSetSmallFont(b)
    b.font.size = 22
    b.font.bold = true
    pbDrawShadowText(b, 0, 8, SCREEN_W, 28, "OVERWORLD MENU PAGES", C_WHITE, C_SHADOW, 1)
    b.font.bold = false
    b.font.size = 14
    pbDrawShadowText(b, 0, 38, SCREEN_W, 18, "Left/Right changes pages while editing.", C_GRAY, C_SHADOW, 1)
    b.fill_rect(0, FOOTER_Y - 2, SCREEN_W, SCREEN_H - FOOTER_Y + 2, C_BG)
  end

  def draw_list
    b = @list_spr.bitmap
    b.clear
    b.fill_rect(0, FOOTER_Y - 2, SCREEN_W, SCREEN_H - FOOTER_Y + 2, C_BG)
    items = sorted_items
    selected = checked_order
    ensure_cursor_visible(items.length)

    draw_page_header(b)
    last_row = [@top_row + MAX_VISIBLE_ROWS, items.length].min
    items[@top_row...last_row].each_with_index do |entry, visible_i|
      i = @top_row + visible_i
      y = LIST_Y + visible_i * ITEM_H
      draw_entry_row(b, entry, i, y, selected)
    end

    if selected.length > @top_row && selected.length < last_row
      div_y = LIST_Y + (selected.length - @top_row) * ITEM_H - 2
      b.fill_rect(LIST_X + 20, div_y, LIST_W - 40, 1, Color.new(100, 100, 140, 160))
    end
    draw_hint(b)
    Graphics.update
  end

  def draw_page_header(bitmap)
    label = "#{current_page_name}  #{@page_index + 1}/#{@pages.length}"
    bitmap.fill_rect(LIST_X, LIST_Y - 28, LIST_W, 22, C_PANEL)
    bitmap.fill_rect(LIST_X, LIST_Y - 28, LIST_W, 1, C_BORDER)
    bitmap.fill_rect(LIST_X, LIST_Y - 7, LIST_W, 1, C_BORDER)
    bitmap.fill_rect(LIST_X, LIST_Y - 28, 1, 22, C_BORDER)
    bitmap.fill_rect(LIST_X + LIST_W - 1, LIST_Y - 28, 1, 22, C_BORDER)
    pbSetSmallFont(bitmap)
    bitmap.font.size = 15
    pbDrawShadowText(bitmap, LIST_X + 8, LIST_Y - 25, LIST_W - 16, 18, label, C_WHITE, C_SHADOW, 1)
    if @pages.length > 1
      pbDrawShadowText(bitmap, LIST_X + 4, LIST_Y - 25, 20, 18, "<", C_DIM, C_SHADOW, 0) if @page_index > 0
      pbDrawShadowText(bitmap, LIST_X + LIST_W - 24, LIST_Y - 25, 20, 18, ">", C_DIM, C_SHADOW, 2) if @page_index < @pages.length - 1
    end
  end

  def draw_entry_row(bitmap, entry, row_index, y, selected_keys)
    selected_row = row_index == @cursor
    active = selected_keys.include?(entry[:key])
    position = active ? selected_keys.index(entry[:key]) + 1 : nil
    locked = entry_toggle_locked?(entry[:key])

    if selected_row && @dragging
      bitmap.fill_rect(LIST_X, y, LIST_W, ITEM_H - 2, C_PICKUP)
    elsif selected_row
      bitmap.fill_rect(LIST_X, y, LIST_W, ITEM_H - 2, C_SEL)
    end

    box_x = LIST_X + 6
    box_y = y + (ITEM_H - BOX_SIZE) / 2
    box_color = active ? C_GREEN : Color.new(120, 120, 140, 180)
    bitmap.fill_rect(box_x, box_y, BOX_SIZE, BOX_SIZE, box_color)
    border = Color.new(0, 0, 0, 120)
    bitmap.fill_rect(box_x, box_y, BOX_SIZE, 1, border)
    bitmap.fill_rect(box_x, box_y + BOX_SIZE - 1, BOX_SIZE, 1, border)
    bitmap.fill_rect(box_x, box_y, 1, BOX_SIZE, border)
    bitmap.fill_rect(box_x + BOX_SIZE - 1, box_y, 1, BOX_SIZE, border)

    num_x = box_x + BOX_SIZE + 6
    pbSetSmallFont(bitmap)
    bitmap.font.size = 14
    pbDrawShadowText(bitmap, num_x, y + 5, NUM_W, ITEM_H - 5, position.to_s, C_GOLD, C_SHADOW, 1) if position

    label_x = num_x + NUM_W + 4
    label_w = LIST_W - (label_x - LIST_X) - 72
    color = if @dragging && selected_row
              C_GOLD
            elsif selected_row
              C_WHITE
            elsif active
              Color.new(205, 220, 205)
            else
              C_GRAY
            end
    bitmap.font.size = 16
    pbDrawShadowText(bitmap, label_x, y + 4, label_w, ITEM_H - 4, entry[:label].to_s.upcase, color, C_SHADOW)
    if locked
      bitmap.font.size = 12
      pbDrawShadowText(bitmap, LIST_X + LIST_W - 66, y + 6, 58, ITEM_H - 6, "LOCKED", C_GOLD, C_SHADOW, 2)
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

  def ensure_cursor_visible(count)
    @cursor = 0 if count <= 0
    @cursor = @cursor.clamp(0, [count - 1, 0].max)
    max_top = [count - MAX_VISIBLE_ROWS, 0].max
    @top_row = [[@top_row, 0].max, max_top].min
    @top_row = @cursor if @cursor < @top_row
    @top_row = @cursor - MAX_VISIBLE_ROWS + 1 if @cursor >= @top_row + MAX_VISIBLE_ROWS
    @top_row = [[@top_row, 0].max, max_top].min
  end

  def handle_input
    items = sorted_items
    return if items.empty?
    if @dragging
      handle_dragging(items)
    else
      handle_normal(items)
    end
  end

  def handle_dragging(items)
    selected = checked_order
    key = items[@cursor][:key]
    idx = selected.index(key)
    if Input.repeat?(Input::DOWN)
      if idx && idx < selected.length - 1
        selected.delete(key)
        selected.insert(idx + 1, key)
        self.checked_order = selected
        @cursor += 1
        ensure_cursor_visible(sorted_items.length)
        pbPlayCursorSE
        draw_list
      end
    elsif Input.repeat?(Input::UP)
      if idx && idx > 0
        selected.delete(key)
        selected.insert(idx - 1, key)
        self.checked_order = selected
        @cursor -= 1
        ensure_cursor_visible(sorted_items.length)
        pbPlayCursorSE
        draw_list
      end
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

  def handle_normal(items)
    if Input.repeat?(Input::DOWN)
      @cursor = (@cursor + 1) % items.length
      ensure_cursor_visible(items.length)
      pbPlayCursorSE
      draw_list
    elsif Input.repeat?(Input::UP)
      @cursor = (@cursor - 1) % items.length
      ensure_cursor_visible(items.length)
      pbPlayCursorSE
      draw_list
    elsif Input.repeat?(Input::LEFT)
      switch_page(-1)
    elsif Input.repeat?(Input::RIGHT)
      switch_page(1)
    elsif Input.trigger?(Input::USE)
      toggle_current_entry(items[@cursor])
    elsif Input.trigger?(Input::ACTION)
      selected = checked_order
      if selected.include?(items[@cursor][:key])
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

  def switch_page(delta)
    return if @pages.length <= 1
    @page_index = (@page_index + delta) % @pages.length
    @cursor = 0
    @top_row = 0
    @dragging = false
    OverworldMenu.page_index = @page_index
    pbPlayCursorSE
    draw_list
  end

  def toggle_current_entry(entry)
    selected = checked_order
    key = entry[:key]
    if selected.include?(key)
      if entry_toggle_locked?(key)
        pbPlayBuzzerSE rescue nil
        return
      end
      selected.delete(key)
      self.disabled_order = disabled_order + [key] if @page_index == 0
      @cursor = [@cursor, sorted_items.length - 1].min
    else
      self.disabled_order = disabled_order - [key] if @page_index == 0
      selected << key
    end
    self.checked_order = selected
    pbPlayDecisionSE
    draw_list
  end

  def open_page_actions(entry)
    commands = ["Rename Page", "Add Page", "Remove Page", "Reset Page", "Back"]
    choice = show_page_actions_popup(commands)
    case choice
    when 0
      rename_current_page
    when 1
      @pages << { "name" => "Page #{@pages.length + 1}", "entries" => [], "disabled_entries" => [] }
      @page_index = @pages.length - 1
      @cursor = 0
      @top_row = 0
      OverworldMenu.page_index = @page_index
      pbPlayDecisionSE
    when 2
      if @page_index > 0
        @pages.delete_at(@page_index)
        @page_index = [@page_index, @pages.length - 1].min
        OverworldMenu.page_index = @page_index
        @cursor = 0
        @top_row = 0
        pbPlayDecisionSE
      else
        pbPlayBuzzerSE rescue nil
      end
    when 3
      if @page_index == 0
        self.checked_order = OverworldMenu.all_registered_keys
        self.disabled_order = []
      else
        self.checked_order = []
      end
      pbPlayDecisionSE
    else
      pbPlayCancelSE rescue nil
    end
    draw_bg
    draw_list
  end

  def rename_current_page
    old_name = current_page_name
    new_name = nil
    run_with_editor_hidden do
      new_name = pbEnterText("Page name?", 1, 16, old_name)
    end
    new_name = new_name.to_s.strip
    return if new_name.empty? || new_name == old_name
    current_page["name"] = new_name
    pbPlayDecisionSE
  rescue StandardError => e
    OverworldMenu.log_exception("Overworld Menu page rename failed", e)
    pbPlayBuzzerSE rescue nil
  end

  def run_with_editor_hidden
    old_z = @vp.z rescue 100_000
    bg_visible = @bg_spr.visible rescue true
    list_visible = @list_spr.visible rescue true
    @bg_spr.visible = false rescue nil
    @list_spr.visible = false rescue nil
    @vp.z = 0 rescue nil
    Graphics.update rescue nil
    yield
  ensure
    @vp.z = old_z rescue nil
    @bg_spr.visible = bg_visible rescue nil
    @list_spr.visible = list_visible rescue nil
    Graphics.update rescue nil
  end

  def show_page_actions_popup(commands)
    cursor = 0
    popup_w = 250
    row_h = 22
    popup_h = 30 + commands.length * row_h + 8
    sprite = Sprite.new(@vp)
    sprite.z = 80
    sprite.x = (SCREEN_W - popup_w) / 2
    sprite.y = (SCREEN_H - popup_h) / 2
    redraw_page_actions_popup(sprite, commands, cursor, popup_w, popup_h, row_h)
    loop do
      Graphics.update
      Input.update
      if Input.repeat?(Input::UP)
        cursor = (cursor - 1) % commands.length
        pbPlayCursorSE
        redraw_page_actions_popup(sprite, commands, cursor, popup_w, popup_h, row_h)
      elsif Input.repeat?(Input::DOWN)
        cursor = (cursor + 1) % commands.length
        pbPlayCursorSE
        redraw_page_actions_popup(sprite, commands, cursor, popup_w, popup_h, row_h)
      elsif Input.trigger?(Input::USE) || input_c?
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

  def redraw_page_actions_popup(sprite, commands, cursor, width, height, row_h)
    sprite.bitmap.dispose rescue nil
    bitmap = Bitmap.new(width, height)
    bitmap.fill_rect(0, 0, width, height, C_PANEL)
    bitmap.fill_rect(0, 0, width, 22, Color.new(22, 26, 54, 255))
    bitmap.fill_rect(0, 0, width, 1, C_BORDER)
    bitmap.fill_rect(0, height - 1, width, 1, C_BORDER)
    bitmap.fill_rect(0, 0, 1, height, C_BORDER)
    bitmap.fill_rect(width - 1, 0, 1, height, C_BORDER)
    bitmap.fill_rect(0, 21, width, 1, C_BORDER)
    pbSetSmallFont(bitmap)
    bitmap.font.size = 15
    pbDrawShadowText(bitmap, 6, 3, width - 12, 16, "PAGE OPTIONS", C_WHITE, C_SHADOW, 1)
    commands.each_with_index do |label, i|
      y = 28 + i * row_h
      selected = i == cursor
      bitmap.fill_rect(2, y, width - 4, row_h - 2, C_POPUP_SEL) if selected
      bitmap.font.size = 15
      color = selected ? C_WHITE : C_GRAY
      pbDrawShadowText(bitmap, 10, y + 3, width - 20, row_h - 4, label, color, C_SHADOW)
    end
    sprite.bitmap = bitmap
    Graphics.update
  end

  def persist_pages
    return unless @pages
    OverworldMenu.pages = @pages
    OverworldMenu.page_index = @page_index || 0
  rescue StandardError => e
    OverworldMenu.log_exception("Overworld Menu page editor failed to save", e)
  end

  def input_c?
    Input.const_defined?(:C) && Input.trigger?(Input::C)
  rescue
    false
  end

  def entry_toggle_locked?(key)
    @page_index == 0 && OverworldMenu.locked_entry?(key)
  end

  def teardown
    [@bg_spr, @list_spr].compact.each do |sprite|
      sprite.bitmap.dispose rescue nil
      sprite.dispose rescue nil
    end
    @popup_spr.dispose rescue nil
    @vp.dispose rescue nil
  end
end

class OverworldMenuScreen
  def initialize(scene)
    @scene = scene
  end

  def open
    party_view = OverworldMenu.party_view
    run_session(party_view)
  ensure
    $game_temp.in_menu = false if $game_temp
    Input.update
    @scene.dispose
  end

  def show_quick_save
    return false if $game_system && $game_system.save_disabled
    scene = PokemonSave_Scene.new
    screen = PokemonSaveScreen.new(scene)
    screen.pbSaveScreen
  end

  def show_popup(title, lines)
    @scene.show_popup(title, lines)
  end

  def show_popup_menu(title, labels)
    @scene.show_popup_menu(title, labels)
  end

  def show_time_changer
    @scene.show_time_changer(on_change: proc { |hour| apply_hour(hour) })
  end

  def show_quick_items
    @scene.show_quick_items_menu(self)
  end

  def show_features_menu
    party_now = OverworldMenu.party_view
    result = @scene.show_features_menu(party_now)
    if result && result.has_key?(:party_view)
      OverworldMenu.party_view = result[:party_view]
    end
    OverworldMenuPageEditorScene.new.main if result && result[:customize_pages]
  end

  def run_with_overlay_hidden
    return yield unless @scene && @scene.respond_to?(:run_with_overlay_hidden)
    @scene.run_with_overlay_hidden { yield }
  end

  def use_quick_item(item)
    item = OverworldMenu.normalize_item(item)
    unless item && OverworldMenu.item_available?(item)
      @scene.show_popup("QUICK ITEMS", ["That item is not in the Bag."])
      return nil
    end
    field_item = pbCanRegisterItem?(item) rescue false
    return use_field_item(item) if field_item
    ret = nil
    @scene.run_with_overlay_hidden do
      ret = pbUseItem($PokemonBag, item, nil)
    end
    return :exit_menu if ret == 2
    nil
  rescue StandardError => e
    OverworldMenu.log_exception("Overworld Menu quick item failed", e)
    @scene.show_popup("QUICK ITEMS", ["That item could not be used."])
    nil
  end

  def use_field_item(item)
    item = OverworldMenu.normalize_item(item)
    return nil unless item && OverworldMenu.item_available?(item)
    confirmed = false
    used = nil
    @scene.run_with_overlay_hidden do
      confirmed = ItemHandlers.triggerConfirmUseInField(item)
      next unless confirmed
      $game_temp.in_menu = false if $game_temp
      used = pbUseKeyItemInField(item)
    end
    return nil unless confirmed
    $game_temp.in_menu = true if $game_temp && !used
    used ? :exit_menu : nil
  rescue StandardError => e
    $game_temp.in_menu = true if $game_temp
    OverworldMenu.log_exception("Overworld Menu field item failed", e)
    @scene.show_popup("OVERWORLD MENU", ["That field item could not be used."])
    nil
  end

  private

  def run_session(party_view)
    pages = OverworldMenu.menu_pages_for_display
    page_pos = pages.index { |page| page[:index] == OverworldMenu.page_index } || 0
    entries = pages[page_pos][:entries]
    cursor = 0
    scroll = 0
    visible = OverworldMenuScene::MAX_ROWS
    @scene.setup(party_view: party_view)
    @scene.draw(entries, cursor, scroll, page_position: page_pos, page_count: pages.length)
    $game_temp.in_menu = true if $game_temp
    Input.update
    loop do
      Graphics.update
      Input.update
      @scene.update_icons
      if Input.repeat?(Input::UP) && !entries.empty?
        cursor = (cursor - 1) % entries.length
        scroll = cursor if cursor < scroll
        scroll = [entries.length - visible, 0].max if cursor >= scroll + visible
        pbPlayCursorSE
        @scene.draw(entries, cursor, scroll, page_position: page_pos, page_count: pages.length)
      elsif Input.repeat?(Input::DOWN) && !entries.empty?
        cursor = (cursor + 1) % entries.length
        scroll = 0 if cursor < scroll
        scroll = cursor - visible + 1 if cursor >= scroll + visible
        pbPlayCursorSE
        @scene.draw(entries, cursor, scroll, page_position: page_pos, page_count: pages.length)
      elsif Input.trigger?(Input::LEFT) && pages.length > 1
        page_pos = (page_pos - 1) % pages.length
        OverworldMenu.page_index = pages[page_pos][:index]
        entries = pages[page_pos][:entries]
        cursor = 0
        scroll = 0
        pbPlayCursorSE
        @scene.draw(entries, cursor, scroll, page_position: page_pos, page_count: pages.length)
      elsif Input.trigger?(Input::RIGHT) && pages.length > 1
        page_pos = (page_pos + 1) % pages.length
        OverworldMenu.page_index = pages[page_pos][:index]
        entries = pages[page_pos][:entries]
        cursor = 0
        scroll = 0
        pbPlayCursorSE
        @scene.draw(entries, cursor, scroll, page_position: page_pos, page_count: pages.length)
      elsif Input.trigger?(Input::USE) || input_c?
        entry = entries[cursor]
        next unless entry
        pbPlayDecisionSE
        result = entry[:handler].call(self)
        OverworldMenu.log_info("Overworld Menu selected #{entry[:key]}")
        break if entry[:exit_on_select] || result == :exit_menu
        pages = OverworldMenu.menu_pages_for_display
        page_pos = pages.index { |page| page[:index] == OverworldMenu.page_index } || 0
        entries = pages[page_pos][:entries]
        cursor = cursor.clamp(0, [entries.length - 1, 0].max)
        scroll = [[scroll, cursor].min, [entries.length - visible, 0].max].min
        @scene.draw(entries, cursor, scroll, page_position: page_pos, page_count: pages.length)
      elsif Input.trigger?(Input::BACK) || Input.trigger?(OverworldMenu::TRIGGER_BUTTON)
        pbPlayCloseMenuSE
        break
      end
    end
  end

  def input_c?
    Input.const_defined?(:C) && Input.trigger?(Input::C)
  rescue
    false
  end

  def apply_hour(new_hour)
    current = pbGetTimeNow
    current_seconds = current.hour * 3600 + current.min * 60 + current.sec
    target_seconds = new_hour.to_i * 3600
    diff = target_seconds - current_seconds
    UnrealTime.add_seconds(diff) if defined?(UnrealTime) && UnrealTime.respond_to?(:add_seconds)
  rescue StandardError => e
    OverworldMenu.log_exception("Overworld Menu time change failed", e)
  end
end

OverworldMenu.register(:quick_items,
  :label => "Quick Items",
  :priority => 5,
  :condition => proc { defined?($PokemonBag) && $PokemonBag },
  :handler => proc { |screen|
    screen.show_quick_items
  }
)

OverworldMenu.register(:quick_save,
  :label => "Quick Save",
  :priority => 1,
  :condition => proc { !($game_system && $game_system.save_disabled) },
  :exit_on_select => true,
  :handler => proc { |screen|
    screen.show_quick_save
    nil
  }
)

OverworldMenu.register(:repel_counter,
  :label => "Repel Counter",
  :priority => 10,
  :condition => proc { ($PokemonGlobal.repel rescue 0).to_i > 0 },
  :handler => proc { |screen|
    steps = ($PokemonGlobal.repel rescue 0).to_i
    screen.show_popup("REPEL ACTIVE", ["Steps remaining: #{steps}"])
    nil
  }
)

OverworldMenu.register(:time_changer,
  :label => "Time Changer",
  :priority => 20,
  :handler => proc { |screen|
    screen.show_time_changer
    nil
  }
)

OverworldMenu.register(:om_features,
  :label => "Overworld Menu Features",
  :priority => 999,
  :handler => proc { |screen|
    screen.show_features_menu
    nil
  }
)

if defined?(Events) && Events.respond_to?(:onMapUpdate) && !$KANTO_RELOADED_OVERWORLD_MENU_EVENT_INSTALLED
  Events.onMapUpdate += proc { |_sender, _event|
    next unless defined?(OverworldMenu)
    next unless Input.trigger?(OverworldMenu::TRIGGER_BUTTON)
    next unless OverworldMenu.can_open?
    OverworldMenu.open
  }
  $KANTO_RELOADED_OVERWORLD_MENU_EVENT_INSTALLED = true
end
