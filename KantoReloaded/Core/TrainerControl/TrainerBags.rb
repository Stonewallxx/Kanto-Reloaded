# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Trainer Control's Trainer Bags (Tougher Trainers G)
#==============================================================================
# PIF Today: a trainer uses items only when their data lists some (most
# ordinary trainers have none; some leaders a Hyper Potion or two). PIF's
# Hard text says Hard trainers have healing items; nothing does that.
#
# His picks (2026-11-01): every trainer carries a bag for their team, on
# Normal and Hard (Easy as PIF), always on:
#
#   How many  2 items, 3 from 4 badges; leaders the same; the Elite Four
#             and Champions one more; Hard one more each
#   Which     first the X item for their ace's best stat (X Attack for a
#             hitter, X Speed for a fast one), from the start; then healing
#             for your badges (Potion, Super, Hyper, Max Potion, Full
#             Restore from 8); the third a Full Heal, any more healing
#   Never     smaller or weaker than their data's: what the data lists stays
#             and this bag fills up to its size
#
# Adaptation's learned battle items come on top. With Kanto Reloaded Debug,
# the Trainer Inspector lists the bag and why each item is there.
#==============================================================================

module Reloaded
  module TrainerControl
    module TrainerBags
      MARK = :@kr_tc_bags                  # on the trainer: what this bag added [[item, why], ...]
      ELITE = /\A(ELITEFOUR|CHAMPION)/
      X_ITEMS = { :ATTACK => :XATTACK, :DEFENSE => :XDEFENSE, :SPECIAL_ATTACK => :XSPATK, :SPECIAL_DEFENSE => :XSPDEF,
                  :SPEED => :XSPEED }.freeze
      # healing by your badges: [from badges, item]
      HEALING = [[0, :POTION], [2, :SUPERPOTION], [4, :HYPERPOTION], [6, :MAXPOTION], [8, :FULLRESTORE]].freeze

      class << self
        def on?
          return defined?(Reloaded::Difficulty) && Reloaded::Difficulty.respond_to?(:level) && Reloaded::Difficulty.level >= 1
        end

        def badges
          return ($Trainer.badge_count rescue 0).to_i
        end

        # How many items this trainer carries
        def size(type)
          n = badges >= 4 ? 3 : 2
          n += 1 if type.to_s =~ ELITE
          n += 1 if Reloaded::Difficulty.level >= 2
          return n
        end

        # The X item for the ace's best stat (its base stats, HP aside)
        def x_item(party)
          return nil if party.empty?
          ace = party[Adaptation.ace_index(party)]
          base = (ace.baseStats rescue nil) || {}
          best = X_ITEMS.keys.max_by { |s| [base[s].to_i, -X_ITEMS.keys.index(s)] }
          return X_ITEMS[best]
        end

        def healing
          return HEALING.select { |from, _i| badges >= from }.last[1]
        end

        # This team's bag: [[item, why], ...] in order
        def chosen(party, n)
          out = []
          x = x_item(party)
          out << [x, _INTL("For Their Ace's Best Stat")] if x
          heal = healing
          while out.length < n
            slot = out.length
            if slot == 2
              out << [:FULLHEAL, _INTL("Cures Status")]
            else
              out << [heal, _INTL("Healing for Your Badges")]
            end
          end
          return out.first(n)
        end

        def exists?(item)
          return (::GameData::Item.exists?(item) rescue false)
        end

        # The trainer's items: their data's kept, this bag filling up to its size
        def apply(trainer, type, name, _version)
          return unless on? && trainer && trainer.respond_to?(:items)
          items = trainer.items
          return unless items.is_a?(Array)
          party = Array(trainer.party).compact
          return if party.empty?
          learned = Array(trainer.instance_variable_get(Adaptation::BAG)).length
          own = items.length - learned                          # the data's (Adaptation's come after them)
          n = size(type) + (defined?(RematchRanks) ? RematchRanks.extra_items(type, name) : 0)   # Master: one more
          return if own >= n
          added = []
          chosen(party, n).each do |item, why|
            break if own + added.length >= n
            next unless exists?(item)
            added << [item.to_s, why]
          end
          items.insert(own, *added.map { |i, _w| i.to_sym })
          trainer.instance_variable_set(MARK, added)
        rescue StandardError => e
          Reloaded::Log.exception("Trainer Control couldn't fill #{type}'s bag", e, :trainer_control)
        end
      end
    end
  end
end
