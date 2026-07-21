#==============================================================================
# TM Vault Tutor.net Compatibility
#==============================================================================
# Keeps Tutor.net active as KIF's data pipeline while redirecting only its
# pause-menu launch into the KR TM Vault scene.
#==============================================================================

module KantoReloaded
  module TMVault
    module TutorNetCompatibility
      TUTOR_NET_LABEL = "Tutor.net"
      TM_VAULT_LABEL = "TM Vault"

      class << self
        def install
          return true if @installed
          install_registration_hook
          install_pause_menu_hook
          install_pause_hide_hook
          install_screen_redirect
          @installed = true
          KantoReloaded::Log.info("Installed TM Vault Tutor.net compatibility", :modules) if defined?(KantoReloaded::Log)
          true
        rescue StandardError => e
          @installed = false
          KantoReloaded::Log.exception("TM Vault Tutor.net compatibility failed", e, channel: :modules) if defined?(KantoReloaded::Log)
          false
        end

        def replace_pause_commands(commands)
          @pause_indices = []
          Array(commands).each_with_index.map do |command, index|
            if tutor_net_label?(command)
              @pause_indices << index
              translated(TM_VAULT_LABEL)
            else
              command
            end
          end
        end

        def remember_pause_selection(index)
          @pending_pause_open = @pause_indices && @pause_indices.include?(index.to_i)
          index
        end

        def reset_pause_request
          @pending_pause_open = false
          @pause_indices = []
        end

        def consume_pause_request?
          pending = !!@pending_pause_open
          @pending_pause_open = false
          pending
        end

        private

        def install_registration_hook
          return false unless Object.private_method_defined?(:pbTutorNetAdd) || Object.method_defined?(:pbTutorNetAdd)
          KantoReloaded::Hooks.wrap(Object, :pbTutorNetAdd, :tm_vault_tutor_net_registration) do |hook, move, *_args|
            result = hook.call
            KantoReloaded::TMVault.register(move, :source => :tutor_net)
            result
          end
        end

        def install_pause_menu_hook
          return false unless defined?(PokemonPauseMenu_Scene)
          KantoReloaded::Hooks.wrap(
            PokemonPauseMenu_Scene, :pbShowCommands, :tm_vault_pause_label
          ) do |hook, commands, *_args|
            compatibility = KantoReloaded::TMVault::TutorNetCompatibility
            compatibility.reset_pause_request
            adapted = compatibility.replace_pause_commands(commands)
            selected = hook.call(adapted)
            compatibility.remember_pause_selection(selected)
          end
        end

        def install_screen_redirect
          return false unless defined?(PokemonTutorNetScreen)
          KantoReloaded::Hooks.wrap(
            PokemonTutorNetScreen, :pbStartScreen, :tm_vault_pause_redirect
          ) do |hook, *_args|
            compatibility = KantoReloaded::TMVault::TutorNetCompatibility
            if compatibility.consume_pause_request?
              KantoReloaded::TMVault.open(:fade => false)
            else
              hook.call
            end
          end
        end

        def install_pause_hide_hook
          return false unless defined?(PokemonPauseMenu_Scene)
          KantoReloaded::Hooks.wrap(
            PokemonPauseMenu_Scene, :pbHideMenu, :tm_vault_clear_pause_request
          ) do |hook, *_args|
            KantoReloaded::TMVault::TutorNetCompatibility.reset_pause_request
            hook.call
          end
        end

        def tutor_net_label?(command)
          command.to_s == translated(TUTOR_NET_LABEL) || command.to_s == TUTOR_NET_LABEL
        rescue
          command.to_s == TUTOR_NET_LABEL
        end

        def translated(text)
          defined?(_INTL) ? _INTL(text) : text
        rescue
          text
        end
      end
    end
  end
end

KantoReloaded::TMVault::TutorNetCompatibility.install if defined?(KantoReloaded::TMVault::TutorNetCompatibility)
