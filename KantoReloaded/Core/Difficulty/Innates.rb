# encoding: utf-8
#==============================================================================
# Kanto Reloaded: KIF: Elite Redux's innates by Difficulty
#==============================================================================
# PIF Today: no innates. KIF: Elite Redux adds them: three extra abilities on
# every Pokémon, and Elite Redux's choice abilities, both behind its one
# Innates row (Mod Settings, On by default). The Megas mod's Elite Redux
# Megas need that row On too.
#
# His picks (2026-10-31, Tougher Trainers): no innates on Normal or Hard.
# KIF-ER's Innates row stays On (so Elite Redux's abilities and every Mega
# stay) and Kanto Reloaded empties each Pokémon's innates, yours and
# trainers' alike. On Normal and Hard the row is greyed out and locked On
# (KIF's own lock: "Set by Kanto Reloaded while that mod is On", then why).
# Easy follows KIF-ER's row as the player sets it, for players who want
# Kanto Reloaded's help without the harder game. With no save loaded (the
# title screen) nothing is locked.
#==============================================================================

module Reloaded
  module Difficulty
    module Innates
      KEY = :kifer_enabled                 # KIF-ER's Innates row (0 Off, 1 On)

      class << self
        def install
          h = Reloaded::Hooks
          h.prepend(nil, ::Pokemon, PokemonInnates, :id => :difficulty_no_innates) if defined?(::Pokemon)
          return unless defined?(::KIF::ModSettings)
          ms = ::KIF::ModSettings.singleton_class
          if ms.method_defined?(:get)
            h.around(nil, ms, :get, :id => :difficulty_innates_on) do |original, *args|
              args[0].to_s == KEY.to_s && Reloaded::Difficulty::Innates.locked? ? 1 : original.call(*args)
            end
          end
          if ms.method_defined?(:option_for)
            h.around(nil, ms, :option_for, :id => :difficulty_innates_row) do |original, *args|
              opt = original.call(*args)
              e = args[0]
              e.is_a?(Hash) && e[:key].to_s == KEY.to_s && Reloaded::Difficulty::Innates.locked? ? Reloaded::Difficulty::Innates.locked_row(opt) : opt
            end
          end
        end

        # Normal or Hard on a loaded save, with KIF-ER there
        def locked?
          return false unless defined?(::KIFER) && Reloaded::Difficulty.ready?
          return Reloaded::Difficulty.level >= 1
        end

        # KIF's row, greyed out and locked On, saying why
        def locked_row(opt)
          return opt unless defined?(::KIF::SettingsScreen::BadgeEnum) && opt.respond_to?(:values)
          words = _INTL("Kanto Reloaded's {1} keeps this On without the 3 extra abilities: Elite Redux's abilities and every Mega stay. On Easy, this row is yours.",
                        _INTL(Reloaded::Difficulty::NAMES[Reloaded::Difficulty.level.clamp(0, 2)]))
          row = ::KIF::SettingsScreen::BadgeEnum.new(opt.name, opt.values, proc { 1 }, proc { |_v| nil }, words)
          row.kif_lock = "Kanto Reloaded"
          return row
        rescue StandardError => e
          Reloaded::Log.exception("Couldn't lock KIF-ER's Innates row", e, :difficulty)
          return opt
        end
      end

      # Every Pokémon's innates, emptied on Normal and Hard
      module PokemonInnates
        def innates
          return [] if Reloaded::Difficulty::Innates.locked?
          return defined?(super) ? super : []
        end
      end
    end
  end
end
