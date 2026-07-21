#==============================================================================
# Kanto Reloaded - Trainer Control Progression Rewards
#==============================================================================

module KantoReloaded
  module TrainerControl
    module TrainerRewards
      ENABLED_SETTING = :trainer_control_progression_rewards

      MILESTONES = {
        3 => {
          :money => 3_000,
          :items => [:RARECANDY, :PPUP, :NUGGET]
        },
        7 => {
          :money => 10_000,
          :items => [:PPMAX, :ABILITYCAPSULE, :MAXREVIVE, :BIGNUGGET]
        },
        12 => {
          :money => 25_000,
          :items => [:PPMAX, :ABILITYCAPSULE, :BOTTLECAP, :BIGNUGGET]
        }
      }.freeze

      class << self
        def enabled?
          truthy?(setting(ENABLED_SETTING, true))
        end

        def process(opponents, decision)
          return false unless enabled? && decision.to_i == 1
          messages = []
          Array(opponents).each do |opponent|
            identity = opponent.is_a?(Hash) ?
                         (opponent[:identity] || opponent["identity"]) : nil
            next unless identity.is_a?(Hash)
            key = value(identity, "key").to_s
            memory = TrainerMemory.find(key)
            next unless memory
            wins = memory["revision"].to_i
            milestone = MILESTONES[wins]
            next unless milestone
            next if TrainerMemory.reward_claimed?(key, wins)
            next unless TrainerMemory.claim_reward(key, wins)
            money = award_money(milestone[:money])
            item = award_item(milestone[:items])
            messages << reward_message(
              value(identity, "display_name", "Trainer"), wins, money, item
            )
          end
          unless messages.empty?
            KantoReloaded::Toast.success(messages.join("\n")) if defined?(KantoReloaded::Toast)
          end
          !messages.empty?
        rescue StandardError => e
          log_exception("Could not grant trainer progression reward", e)
          false
        end

        private

        def award_money(amount)
          return 0 unless defined?($Trainer) && $Trainer && $Trainer.respond_to?(:money=)
          before = $Trainer.money.to_i
          $Trainer.money = before + amount.to_i
          [$Trainer.money.to_i - before, 0].max
        rescue StandardError
          0
        end

        def award_item(candidates)
          return nil unless defined?(GameData::Item) && defined?($PokemonBag) && $PokemonBag
          valid = Array(candidates).select { |item| GameData::Item.exists?(item) }
          valid = random_order(valid)
          valid.each do |item|
            next unless $PokemonBag.pbCanStore?(item, 1)
            return item if $PokemonBag.pbStoreItem(item, 1)
          end
          nil
        rescue StandardError
          nil
        end

        def reward_message(name, wins, money, item)
          parts = []
          parts << _INTL("${1}", money) if money.to_i > 0
          if item
            item_name = GameData::Item.get(item).name rescue item.to_s
            parts << item_name
          end
          reward = parts.empty? ? _INTL("reward recorded") : parts.join(" + ")
          _INTL("{1}: {2}-win reward - {3}", name.to_s, wins.to_i, reward)
        end

        def random_order(values)
          result = Array(values).dup
          (result.length - 1).downto(1) do |index|
            other = rand(index + 1)
            result[index], result[other] = result[other], result[index]
          end
          result
        end

        def setting(key, fallback)
          return fallback unless defined?(KantoReloaded::Settings)
          KantoReloaded::Settings.get(key, fallback)
        end

        def truthy?(value)
          value == true || (value.is_a?(Numeric) && value.to_i != 0) ||
            ["true", "on", "yes", "enabled", "1"].include?(value.to_s.downcase)
        end

        def value(hash, key, fallback = nil)
          found = hash[key]
          found = hash[key.to_sym] if found.nil?
          found.nil? ? fallback : found
        end

        def log_exception(message, error)
          KantoReloaded::Log.exception(
            message, error, channel: :trainer_control
          ) if defined?(KantoReloaded::Log)
        end
      end
    end
  end
end
