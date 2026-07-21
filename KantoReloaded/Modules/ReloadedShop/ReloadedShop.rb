#==============================================================================
# Kanto Reloaded - Reloaded Shop
#==============================================================================
# Replaces only KIF's marked Kuray Shop purchase screen. Ordinary Marts are
# delegated to their original implementation unchanged.
#==============================================================================

module KantoReloaded
  module ReloadedShop
    SETTINGS_ACTION = :reloaded_shop_settings
    CONFIRM_SETTING = :reloaded_shop_confirm_purchases

    class << self
      def install
        return true if @installed
        settings_ready = register_settings
        hooks_ready = register_hooks
        @installed = settings_ready && hooks_ready
        KantoReloaded::Log.info(
          "Reloaded Shop installed settings=#{settings_ready} hooks=#{hooks_ready}",
          :modules
        ) if defined?(KantoReloaded::Log)
        @installed
      rescue StandardError => e
        KantoReloaded::Log.exception(
          "Reloaded Shop installation failed", e, channel: :modules
        ) if defined?(KantoReloaded::Log)
        false
      end

      def open(stock, adapter)
        BuyScene.new(stock, adapter).main
      rescue StandardError => e
        KantoReloaded::Log.exception(
          "RLD Shop failed to open", e, channel: :modules
        ) if defined?(KantoReloaded::Log)
        KantoReloaded::PopupWindow.message(
          _INTL("RLD Shop could not be opened."), :theme => :error
        ) if defined?(KantoReloaded::PopupWindow)
        false
      end

      def open_editor
        pbFadeOutIn { EditorScene.new.main }
        true
      rescue StandardError => e
        KantoReloaded::Log.exception(
          "RLD Shop editor failed to open", e, channel: :modules
        ) if defined?(KantoReloaded::Log)
        KantoReloaded::Toast.error(
          _INTL("RLD Shop editor could not be opened.")
        ) if defined?(KantoReloaded::Toast)
        false
      end

      def confirm_purchases?
        setting_enabled?(CONFIRM_SETTING, true)
      end

      private

      def register_settings
        return false unless defined?(KantoReloaded::Settings)
        KantoReloaded::Settings.register(SETTINGS_ACTION, {
          :name => "Reloaded Shop",
          :description => "Configure the Reloaded Shop catalog and purchase interface.",
          :type => :button,
          :category => :economy,
          :owner => :kanto_reloaded,
          :priority => 1010,
          :on_press => proc {
            KantoReloaded::SettingsUI.open_module(:reloaded_shop)
          }
        })

        visible = proc do |context|
          next false unless context.is_a?(Hash)
          value = context[:module] || context["module"] ||
                  context[:owner] || context["owner"]
          value && value.to_sym == :reloaded_shop
        rescue StandardError
          false
        end

        definitions = [
          [:reloaded_shop_edit, {
            :name => "Edit Shop Contents",
            :description => "Add, remove, categorize, reorder, enable, and price shop items.",
            :type => :button, :priority => 10,
            :on_press => proc { KantoReloaded::ReloadedShop.open_editor }
          }],
          [:reloaded_shop_export, {
            :name => "Export Catalog",
            :description => "Export the current RLD Shop catalog to the KR Exports folder.",
            :type => :button, :priority => 20,
            :on_press => proc {
              success, message = KantoReloaded::ReloadedShop::Catalog.export
              success ? KantoReloaded::Toast.success(message) :
                KantoReloaded::Toast.error(message)
            }
          }],
          [:reloaded_shop_import, {
            :name => "Import Catalog",
            :description => "Import the RLD Shop catalog from the KR Exports folder.",
            :type => :button, :priority => 30,
            :on_press => proc {
              next unless KantoReloaded::PopupWindow.confirm(
                _INTL("Import {1}? Current shop edits will be replaced.",
                      KantoReloaded::ReloadedShop::Catalog::EXPORT_FILE),
                :default => false
              )
              success, message = KantoReloaded::ReloadedShop::Catalog.import
              success ? KantoReloaded::Toast.success(message) :
                KantoReloaded::Toast.error(message)
            }
          }],
          [CONFIRM_SETTING, {
            :name => "Confirm Purchases",
            :description => "Ask for confirmation after choosing a purchase quantity.",
            :type => :toggle, :default => 1, :priority => 40
          }],
          [:reloaded_shop_reset, {
            :name => "Reset Reloaded Shop",
            :description => "Remove all catalog edits and restore KIF-driven stock defaults.",
            :type => :button, :priority => 1000,
            :metadata => { :after => CONFIRM_SETTING },
            :on_press => proc {
              next unless KantoReloaded::PopupWindow.confirm(
                _INTL("Reset every RLD Shop category, item, price, and favorite?"),
                :default => false
              )
              KantoReloaded::ReloadedShop::Catalog.reset!
              KantoReloaded::Toast.success(_INTL("RLD Shop defaults restored."))
            }
          }]
        ]
        definitions.each do |key, data|
          KantoReloaded::Settings.register(key, data.merge(
            :category => :quality_of_life,
            :owner => :reloaded_shop,
            :value_style => :integer,
            :visible_if => visible
          ))
        end
        true
      end

      def register_hooks
        return false unless defined?(KantoReloaded::Hooks)
        label_ready = install_pause_label_hook
        screen_ready = install_mart_redirect
        label_ready && screen_ready
      end

      def install_pause_label_hook
        return false unless defined?(PokemonPauseMenu_Scene)
        KantoReloaded::Hooks.wrap(
          PokemonPauseMenu_Scene, :pbShowCommands, :reloaded_shop_pause_label
        ) do |hook, commands, *_arguments|
          renamed = Array(commands).map do |command|
            text = command.to_s
            text.strip.downcase == "kuray shop" ? _INTL("RLD Shop") : command
          end
          hook.call(renamed)
        end
      end

      def install_mart_redirect
        return false unless defined?(PokemonMartScreen)
        KantoReloaded::Hooks.wrap(
          PokemonMartScreen, :pbBuyScreen, :reloaded_shop_buy_screen
        ) do |hook, *_arguments|
          marked = defined?($game_temp) && $game_temp &&
                   $game_temp.respond_to?(:fromkurayshop) &&
                   $game_temp.fromkurayshop
          if marked
            stock = instance_variable_get(:@stock)
            adapter = instance_variable_get(:@adapter)
            KantoReloaded::ReloadedShop.open(stock, adapter)
          else
            hook.call
          end
        end
      end

      def setting_enabled?(key, fallback)
        return fallback unless defined?(KantoReloaded::Settings)
        value = KantoReloaded::Settings.get(key, fallback ? 1 : 0)
        value == true || value.to_i == 1
      rescue StandardError
        fallback
      end
    end
  end
end

KantoReloaded::ReloadedShop.install
