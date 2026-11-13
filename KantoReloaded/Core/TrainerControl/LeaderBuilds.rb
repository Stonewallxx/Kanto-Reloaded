# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Trainer Control's Leader Builds (Tougher Trainers B)
#==============================================================================
# PIF Today: a trainer's Pokémon get IVs of half their level and EVs of
# their level x 1.5 in every stat (85 at most), a nature from their ID
# numbers, and their data's ability. The data can write any of these, and
# Expert Mode's trainers write more of them.
#
# His picks (2026-10-31): Gym Leaders, the Elite Four, Champions, Rocket
# bosses and your rival (Level Scaling's leader group) bring built teams:
#
#   IVs      Normal: 10 at the first gym, rising to 31 by the eighth (your
#            badges); Hard: 31
#   EVs      252 in each of its two role stats: Normal a share for each gym,
#            all of it by the eighth; Hard from the start. The rest keep
#            what PIF gave, as far as 510 in all allows
#   Nature   raises its Speed when it's faster than it hits, else its better
#            attack; lowers the attack it doesn't use (Jolly, Adamant,
#            Timid, Modest). Its role stats: the better attack, and Speed
#            (fast) or HP (slow)
#   Ability  the best it can have; the data's hand-set ones stay
#   Easy     as PIF
#
# A written build is never lowered: every IV and EV is the higher of the
# data's and the build's, a written nature stays. Always on, Normal and
# Hard. Notoriety's Feared and Rematch Ranks give ordinary trainers' aces
# (and at Master, their teams) the same builds (build).
#==============================================================================

module Reloaded
  module TrainerControl
    module LeaderBuilds
      DATA = :@kr_tc_data                  # on a loaded Pokémon: its place in the trainer's data
      MARK = :@kr_tc_built                 # on a built one: { "iv", "ev", "stats", "nature", "ability" }
      IV_FROM = 10
      IV_TOP = 31
      EV_TOP = 252
      EV_ALL = 510
      GYMS = 8
      # Abilities by how much they help a battler (the best it can have)
      GREAT = %i[HUGEPOWER PUREPOWER SPEEDBOOST ADAPTABILITY DROUGHT DRIZZLE SANDSTREAM SNOWWARNING MAGICGUARD MOXIE
                 PROTEAN LIBERO TECHNICIAN SHEERFORCE GUTS MULTISCALE REGENERATOR INTIMIDATE LEVITATE TOUGHCLAWS
                 SKILLLINK TINTEDLENS SERENEGRACE CONTRARY UNAWARE MAGICBOUNCE PRANKSTER SWIFTSWIM CHLOROPHYLL SANDRUSH
                 SLUSHRUSH STRONGJAW IRONFIST AERILATE PIXILATE REFRIGERATE GALVANIZE POISONHEAL DOWNLOAD BEASTBOOST
                 SHADOWSHIELD PRISMARMOR FILTER SOLIDROCK THICKFAT FLASHFIRE WATERABSORB VOLTABSORB SAPSIPPER STORMDRAIN
                 LIGHTNINGROD MOTORDRIVE DRYSKIN STURDY NATURALCURE UNBURDEN].freeze
      BAD = %i[TRUANT SLOWSTART DEFEATIST KLUTZ STALL RUNAWAY HONEYGATHER PICKUP ILLUMINATE BALLFETCH NORMALIZE
               HEAVYMETAL LIGHTMETAL FRISK].freeze

      class << self
        def on?
          return false unless defined?(Reloaded::Difficulty) && Reloaded::Difficulty.respond_to?(:level)
          return Reloaded::Difficulty.level >= 1
        end

        def hard?
          return Reloaded::Difficulty.level >= 2
        end

        def badges
          return ($Trainer.badge_count rescue 0).to_i
        end

        def leader?(type)
          return TrainerControl.kind(type) != :trainer
        end

        # The trainer's data as the game loads it (Expert Mode's, Modern Mode's)
        def data_of(type, name, version)
          return [] unless defined?(::GameData::Trainer)
          mode = defined?(getTrainersDataMode) ? (getTrainersDataMode rescue ::GameData::Trainer) : ::GameData::Trainer
          d = (mode.try_get(type, name, version) rescue nil) || (::GameData::Trainer.try_get(type, name, version) rescue nil)
          return d ? Array(d.pokemon) : []
        end

        # Each Pokémon's place in its data, before anything moves them
        def tag(trainer)
          Array(trainer && trainer.party).each_with_index { |pk, i| pk.instance_variable_set(DATA, i) if pk }
        end

        # A leader's whole team, built (TrainerControl.build_team, last)
        def apply(trainer, type, name, version)
          return unless on? && leader?(type) && trainer
          data = data_of(type, name, version)
          Array(trainer.party).compact.each do |pk|
            i = pk.instance_variable_get(DATA)
            build(pk, i ? data[i] : nil)
          end
        rescue StandardError => e
          Reloaded::Log.exception("Trainer Control couldn't build #{type} #{name}'s team", e, :trainer_control)
        end

        # IVs and EVs for your badges (Hard: all of them)
        def iv_now
          return IV_TOP if hard?
          return IV_FROM + ((IV_TOP - IV_FROM) * [badges, GYMS - 1].min / (GYMS - 1).to_f).round
        end

        def ev_now
          return EV_TOP if hard?
          return EV_TOP * [badges + 1, GYMS].min / GYMS
        end

        # [better attack, the other attack, the second role stat (Speed or HP)]
        def role(pk)
          base = (pk.baseStats rescue nil) || {}
          atk, spa, spe = base[:ATTACK].to_i, base[:SPECIAL_ATTACK].to_i, base[:SPEED].to_i
          better, other = atk >= spa ? [:ATTACK, :SPECIAL_ATTACK] : [:SPECIAL_ATTACK, :ATTACK]
          return [better, other, spe > [atk, spa].max ? :SPEED : :HP]
        end

        # The nature raising up and lowering down
        def nature_for(up, down)
          ::GameData::Nature.each do |n|
            ch = Array(n.stat_changes)
            return n.id if ch.any? { |s, v| s == up && v > 0 } && ch.any? { |s, v| s == down && v < 0 }
          end
          return nil
        rescue StandardError
          return nil
        end

        def ability_score(id)
          sym = id.to_s.to_sym
          return 3 if GREAT.include?(sym)
          return 0 if BAD.include?(sym)
          return 1
        end

        # The best ability it can have (ties keep the one it has)
        def best_ability(pk)
          list = (pk.getAbilityList rescue nil)
          return nil unless list.is_a?(Array) && !list.empty?
          now = (pk.ability_id rescue nil)
          best = list.max_by { |id, idx| [ability_score(id), id == now ? 1 : 0, -idx.to_i] }
          return best && best[0] != now ? best : nil
        end

        # Written EVs stay; past 510 in all, the role stats give back what they
        # gained (never below what's written)
        def fit_written(pk, stats, written)
          over = -EV_ALL
          ::GameData::Stat.each_main { |s| over += pk.ev[s.id].to_i }
          stats.reverse_each do |s|
            break if over <= 0
            give = [over, pk.ev[s].to_i - written[s].to_i].min
            next if give <= 0
            pk.ev[s] -= give
            over -= give
          end
        end

        # One Pokémon built; entry: its data (a written build is never lowered)
        def build(pk, entry = nil)
          return unless pk && on? && pk.respond_to?(:iv) && pk.respond_to?(:ev)
          entry = {} unless entry.is_a?(Hash)
          iv = iv_now
          ev = ev_now
          better, other, second = role(pk)
          stats = [better, second]
          ::GameData::Stat.each_main { |s| pk.iv[s.id] = [pk.iv[s.id].to_i, iv].max }
          stats.each { |s| pk.ev[s] = [pk.ev[s].to_i, ev].max }
          room = EV_ALL - stats.sum { |s| pk.ev[s].to_i }
          rest = []
          ::GameData::Stat.each_main { |s| rest << s.id unless stats.include?(s.id) }
          if entry[:ev]
            fit_written(pk, stats, entry[:ev])
          else
            each = [room, 0].max / [rest.length, 1].max
            rest.each { |s| pk.ev[s] = [pk.ev[s].to_i, each].min }
          end
          nature = nil
          unless entry[:nature]
            nature = nature_for(second == :SPEED ? :SPEED : better, other)
            pk.nature = nature if nature
          end
          ability = nil
          unless entry[:ability] || entry[:ability_index]
            ability = best_ability(pk)
            pk.ability_index = ability[1] if ability
          end
          pk.calc_stats
          pk.hp = pk.totalhp
          pk.instance_variable_set(MARK, { "iv" => iv, "ev" => ev, "stats" => stats.map(&:to_s),
                                           "nature" => nature ? nature.to_s : nil, "ability" => ability ? ability[0].to_s : nil })
        rescue StandardError => e
          Reloaded::Log.exception("Trainer Control couldn't build a #{pk.species rescue "?"}", e, :trainer_control)
        end
      end
    end
  end
end
