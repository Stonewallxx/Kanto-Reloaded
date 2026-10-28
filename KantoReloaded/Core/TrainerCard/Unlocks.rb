# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Trainer Card's unlocks
#==============================================================================
# His picks (2026-10-28, the unlock design round): what Style can show and
# how each one is earned. Everything is per save (the "trainer_card"
# section): "unlocked" (category => ids), "style" (the plate, title, badge
# case and Run Tag look in use) and "tracked" (a milestone the Stats tab
# shows instead of the nearest).
#
#   Plate Colors   Glass White and Glass Charcoal from the start (Theme
#                  Mode picks one until another is chosen); 12 more
#   Badge Cases    Glass from the start; Leather, Velvet, Denim, Wood,
#                  Cork, Steel, Royal
#   Run Tag Looks  Pills from the start; Solid, Plates, Dots
#   Titles         Pokémon Trainer from the start; 7 story titles, 17
#                  milestone titles and Hard-Mode Champion
#   Backgrounds    PIF's own (its Printers, the Sprite Gallery, bought here
#                  at the Printers' price), and two only Kanto Reloaded
#                  gives (Explosion, 500000 Flag), added to PIF's own list
#
# Milestones: each stat and record has tiers, each giving one unlock (the
# Stats tab's Next Milestone is the nearest, or the tracked one). Hard
# Rewards: beating the League on Hard (kept after lowering; Debug saves
# earn them too, his calls). An unlock earned shows a New Unlock toast on
# the map; an older save gets what it already reaches quietly.
#
# A later feature brings its own (Trainer Control, the Shiny Log):
#
#   Reloaded::TrainerCard::Unlocks.register(:titles, :rival_slayer, :name => "Rival Slayer",
#     :need => "Beat Your Rival 10 Times", :from => "Trainer Control",
#     :check => proc { ... true when earned })
#==============================================================================

module Reloaded
  module TrainerCard
    module Unlocks
      Item = Struct.new(:cat, :id, :name, :look, :start)
      CATEGORIES = [:backgrounds, :plates, :titles, :cases, :tags].freeze
      # Plates: [id, name, rgb, kind, glass alpha (nil: the Theme's, art-aware), shine]
      PLATES = [[:glass_white, "Glass White", [250, 252, 255], :glass, nil, nil],
                [:glass_charcoal, "Glass Charcoal", [34, 38, 48], :glass, nil, nil],
                [:gold, "Gold", [255, 214, 60], :sheen, 205, 0.55], [:silver, "Silver", [204, 210, 222], :sheen, nil, nil],
                [:bronze, "Bronze", [205, 130, 60], :sheen, nil, nil], [:ruby, "Ruby", [196, 36, 70], :sheen, nil, nil],
                [:sapphire, "Sapphire", [40, 92, 200], :sheen, nil, nil], [:emerald, "Emerald", [28, 150, 100], :sheen, nil, nil],
                [:rose_gold, "Rose Gold", [236, 170, 150], :sheen, nil, nil], [:topaz, "Topaz", [240, 150, 40], :sheen, nil, nil],
                [:amethyst, "Amethyst", [130, 70, 200], :sheen, nil, nil], [:aquamarine, "Aquamarine", [40, 170, 180], :sheen, nil, nil],
                [:rose_quartz, "Rose Quartz", [240, 140, 180], :sheen, nil, nil], [:onyx, "Onyx", [40, 40, 46], :sheen, nil, nil]].freeze
      # Badge cases: [id, name, [face, slot, trim]] (Glass: the card's plates)
      CASES = [[:glass, "Glass", nil], [:leather, "Leather", [[120, 74, 40], [86, 50, 26], [222, 196, 150]]],
               [:velvet, "Velvet", [[120, 26, 44], [70, 12, 26], [232, 190, 80]]], [:denim, "Denim", [[54, 86, 140], [34, 56, 96], [232, 196, 120]]],
               [:wood, "Wood", [[150, 100, 58], [104, 66, 36], [118, 76, 42]]], [:cork, "Cork", [[196, 156, 106], [150, 112, 70], [170, 128, 84]]],
               [:steel, "Steel", [[150, 158, 172], [96, 104, 118], [210, 216, 226]]], [:royal, "Royal", [[88, 44, 140], [52, 24, 88], [232, 190, 80]]]].freeze
      TAG_LOOKS = [[:pill, "Pills"], [:solid, "Solid"], [:plate, "Plates"], [:dot, "Dots"]].freeze
      TITLES = [[:pokemon_trainer, "Pokémon Trainer"], [:rookie, "Rookie"], [:gym_challenger, "Gym Challenger"],
                [:badge_master, "Badge Master"], [:champion, "Champion"], [:johto_challenger, "Johto Challenger"],
                [:two_region_champion, "Two-Region Champion"], [:mt_silver_legend, "Mt. Silver Legend"],
                [:ace_trainer, "Ace Trainer"], [:veteran, "Veteran"], [:on_a_roll, "On a Roll"], [:unbeatable, "Unbeatable"],
                [:collector, "Collector"], [:pokemon_professor, "Pokémon Professor"], [:fusion_fan, "Fusion Fan"],
                [:fusion_master, "Fusion Master"], [:breeder, "Breeder"], [:lucky_star, "Lucky Star"], [:shiny_hunter, "Shiny Hunter"],
                [:wanderer, "Wanderer"], [:trader, "Trader"], [:coach, "Coach"], [:mentor, "Mentor"], [:master_trainer, "Master Trainer"],
                [:reigning_champion, "Reigning Champion"], [:hard_mode_champion, "Hard-Mode Champion"]].freeze
      KR_BACKGROUNDS = { "EXPLOSION" => "Explosion", "500000_FLAG" => "500000 Flag" }.freeze
      # The story titles: [id, need words, the check]
      STORY = [[:rookie, "The First Badge", proc { Unlocks.badges >= 1 }],
               [:gym_challenger, "Four Badges", proc { Unlocks.badges >= 4 }],
               [:badge_master, "All Eight Kanto Badges", proc { (0..7).all? { |i| Reloaded::TrainerCard.badge?(i) } }],
               [:champion, "Beat the League", proc { Reloaded::TrainerCard.league? }],
               [:johto_challenger, "The First Johto Badge", proc { (8..15).any? { |i| Reloaded::TrainerCard.badge?(i) } }],
               [:two_region_champion, "All 16 Badges", proc { (0..15).all? { |i| Reloaded::TrainerCard.badge?(i) } }],
               [:mt_silver_legend, "Beat Mt. Silver", proc { Reloaded::TrainerCard.switch?(:SWITCH_BEAT_MT_SILVER) }]].freeze
      # Milestones per stat: [tier, category, id] (his pick: each tier one unlock)
      MILESTONES = {
        :wins => [[10, :plates, :bronze], [50, :titles, :ace_trainer], [100, :plates, :silver], [250, :titles, :veteran], [500, :backgrounds, "EXPLOSION"]],
        :best_streak => [[5, :tags, :solid], [10, :titles, :on_a_roll], [25, :plates, :gold], [50, :titles, :unbeatable]],
        :caught => [[10, :cases, :leather], [50, :titles, :collector], [100, :plates, :emerald], [250, :titles, :pokemon_professor]],
        :fusions => [[1, :tags, :plate], [10, :titles, :fusion_fan], [50, :plates, :amethyst], [100, :titles, :fusion_master]],
        :eggs => [[1, :cases, :cork], [10, :titles, :breeder], [25, :plates, :rose_quartz], [50, :cases, :velvet]],
        :shinies => [[1, :titles, :lucky_star], [5, :plates, :topaz], [10, :titles, :shiny_hunter], [25, :plates, :rose_gold]],
        :steps => [[10_000, :cases, :denim], [50_000, :titles, :wanderer], [100_000, :plates, :aquamarine], [250_000, :cases, :steel],
                   [500_000, :backgrounds, "500000_FLAG"]],
        :trades => [[1, :tags, :dot], [5, :titles, :trader], [10, :plates, :sapphire], [25, :cases, :wood]],
        :levels => [[100, :titles, :coach], [500, :plates, :ruby], [1_000, :titles, :mentor], [2_500, :titles, :master_trainer]],
        :hall_of_fame => [[5, :titles, :reigning_champion]]
      }.freeze
      HARD = [[:titles, :hard_mode_champion], [:plates, :onyx], [:cases, :royal]].freeze
      # How each stat's tier is worded: [one, many, the milestone's name]
      WORDS = { :wins => ["Win a Battle", "Win {1} Battles", "A Wins Milestone"],
                :best_streak => ["A Best Streak of 1", "A Best Streak of {1}", "A Best Streak Milestone"],
                :caught => ["Catch a Pokémon", "Catch {1} Pokémon", "A Caught Milestone"],
                :fusions => ["Make a Fusion", "Make {1} Fusions", "A Fusions Milestone"],
                :eggs => ["Hatch an Egg", "Hatch {1} Eggs", "An Eggs Milestone"],
                :shinies => ["Find a Shiny", "Find {1} Shinies", "A Shinies Milestone"],
                :steps => ["Walk a Step", "Walk {1} Steps", "A Steps Milestone"],
                :trades => ["Make a Trade", "Make {1} Trades", "A Trades Milestone"],
                :levels => ["Gain a Level", "Gain {1} Levels", "A Levels Milestone"],
                :hall_of_fame => ["Enter the Hall of Fame", "Enter the Hall of Fame {1} Times", "A Hall of Fame Milestone"] }.freeze
      # What PIF's unlock switches mean, for the Backgrounds list
      SWITCH_WORDS = { :SWITCH_BEAT_THE_LEAGUE => "Beat the League", :SWITCH_BEAT_MT_SILVER => "Beat Mt. Silver",
                       :SWITCH_FINISHED_ARCEUS_EVENT => "Finish Arceus's Event", :SWITCH_CAUGHT_DARKRAI => "Catch Darkrai",
                       :SWITCH_CAUGHT_MELOETTA => "Catch Meloetta", :SWITCH_PINKAN_FINISHED => "Finish Pinkan Island",
                       :SWITCH_FINISHED_ROCKET_QUESTS_CERULEAN => "Finish Team Rocket's Cerulean Quests",
                       :SWITCH_FINISHED_ROCKET_QUESTS_CELADON => "Finish Team Rocket's Celadon Quests",
                       :SWITCH_HOENN_HAIR_COLLECTION => "Collect the Hoenn Hairstyles", :SWITCH_UNOVA_HAIR_COLLECTION => "Collect the Unova Hairstyles",
                       :SWITCH_KALOS_HAIR_COLLECTION => "Collect the Kalos Hairstyles", :SWITCH_ALOLA_HAIR_COLLECTION => "Collect the Alola Hairstyles",
                       :SWITCH_PALDEA_HAIR_COLLECTION => "Collect the Paldea Hairstyles" }.freeze
      ICONS = { :backgrounds => :TOWNMAP, :plates => :SHINYCHARM, :titles => :AMULETCOIN, :cases => :EXPSHARE, :tags => :LINKINGCORD }.freeze
      CAT_WORDS = { :backgrounds => "Background", :plates => "Plate", :titles => "Title", :cases => "Badge Case", :tags => "Run Tag Look" }.freeze
      PRICE_START = 250        # the Printers' price (VAR_TRAINER_CARD_BACKGROUND_PRICE, set once with switch 1131)
      PRICE_STEP = 500
      PRICE_SET = 1131
      CHECK_EVERY = 60         # map frames between checks for story unlocks
      @extra = []              # registered by other features: [Item, need, from, check]
      @toasts = []

      class << self
        attr_reader :toasts

        def boot
          Reloaded::Events.on(:save_loaded, :trainer_card_unlocks, 70) { check(true) }
          Reloaded::Events.on(:new_game, :trainer_card_unlocks, 70) { check(true) }
          Reloaded::Hooks.prepend(nil, "Scene_Map", MapCheck, :id => :trainer_card_unlocks_map) if defined?(::Scene_Map)
          return true
        end

        def data
          return Reloaded::TrainerCard.data
        end

        def badges
          return (0..15).count { |i| Reloaded::TrainerCard.badge?(i) }
        end

        #----------------------------------------------------------------------
        # The items
        #----------------------------------------------------------------------
        def items(cat)
          base = case cat
                 when :plates then PLATES.map { |id, n, rgb, kind, a, sh| Item.new(:plates, id, n, [rgb, kind, a, sh], [:glass_white, :glass_charcoal].include?(id)) }
                 when :cases then CASES.map { |id, n, look| Item.new(:cases, id, n, look, id == :glass) }
                 when :tags then TAG_LOOKS.map { |id, n| Item.new(:tags, id, n, nil, id == :pill) }
                 when :titles then TITLES.map { |id, n| Item.new(:titles, id, n, nil, id == :pokemon_trainer) }
                 else []
                 end
          return base + @extra.select { |e| e[0].cat == cat }.map(&:first)
        end

        def item(cat, id)
          return items(cat).find { |i| i.id.to_s == id.to_s }
        end

        def name(cat, id)
          return _INTL(KR_BACKGROUNDS[id.to_s] || (defined?(getDisplayedName) ? getDisplayedName(id.to_s) : id.to_s)) if cat == :backgrounds
          it = item(cat, id)
          return it ? _INTL(it.name) : id.to_s
        end

        # What an unlock is called on its own ("Gold Plate", "Champion Title")
        def reward_words(cat, id)
          n = name(cat, id)
          case cat
          when :titles then return _INTL("{1} Title", n)
          when :tags then return _INTL("{1} Run Tags", n)
          when :cases then return _INTL("{1} Case", n)
          when :backgrounds then return _INTL("{1} Background", n)
          end
          return _INTL("{1} Plate", n)
        end

        # A later feature's own unlock
        def register(cat, id, name:, need:, from:, check:, look: nil)
          @extra.reject! { |e| e[0].cat == cat.to_sym && e[0].id.to_s == id.to_s }
          @extra << [Item.new(cat.to_sym, id.to_sym, name.to_s, look, false), need.to_s, from.to_s, check]
          return id
        end

        #----------------------------------------------------------------------
        # What this save has
        #----------------------------------------------------------------------
        def unlocked(cat)
          d = data
          u = (d["unlocked"] ||= {}) if d.is_a?(Hash) && Reloaded::SaveStore.loaded?
          return [] unless u
          return (u[cat.to_s] ||= [])
        end

        def owned?(cat, id)
          return backgrounds_owned.include?(id.to_s) if cat == :backgrounds
          it = item(cat, id)
          return true if it && it.start
          return unlocked(cat).include?(id.to_s)
        end

        # The ones a player can pick, in the list's order
        def owned(cat)
          return backgrounds_owned if cat == :backgrounds
          return items(cat).select { |i| owned?(cat, i.id) }
        end

        # [owned, of]
        def count(cat)
          return [backgrounds_owned.length, backgrounds_all.length] if cat == :backgrounds
          list = items(cat)
          return [list.count { |i| owned?(cat, i.id) }, list.length]
        end

        def grant(cat, id, quiet = false)
          return false if owned?(cat, id)
          if cat == :backgrounds
            return false unless $Trainer
            $Trainer.unlocked_card_backgrounds = [] unless $Trainer.unlocked_card_backgrounds
            $Trainer.unlocked_card_backgrounds << id.to_s
          else
            list = unlocked(cat)
            list << id.to_s
          end
          Reloaded::Log.info("Trainer Card unlock: #{cat} #{id}#{quiet ? " (already reached)" : ""}", :trainer_card)
          Reloaded::Events.emit(:card_unlocked, :category => cat, :id => id, :quiet => quiet)
          @toasts << [cat, id] unless quiet
          return true
        end

        #----------------------------------------------------------------------
        # The style in use
        #----------------------------------------------------------------------
        def style
          d = data
          return {} unless d.is_a?(Hash)
          return d["style"].is_a?(Hash) ? d["style"] : (Reloaded::SaveStore.loaded? ? (d["style"] = {}) : {})
        end

        # The plate picked (an Item), or nil for the Theme's
        def plate
          id = style["plate"]
          return id ? item(:plates, id) : nil
        end

        def case_look
          id = style["case"]
          return id ? item(:cases, id) : nil
        end

        def tag_look
          id = style["tags"]
          return id ? id.to_sym : :pill
        end

        def title_id
          id = style["title"]
          return id ? id.to_sym : :pokemon_trainer
        end

        #----------------------------------------------------------------------
        # Earning
        #----------------------------------------------------------------------
        # Every way in at once: story, milestones, Hard, other features'.
        # quiet: no toasts (a save already this far when the card first saw it)
        def check(quiet = false)
          return 0 unless Reloaded::SaveStore.loaded? && $Trainer
          got = 0
          STORY.each { |id, _w, ok| got += 1 if (ok.call rescue false) && grant(:titles, id, quiet) }
          MILESTONES.each do |stat, tiers|
            now = Reloaded::TrainerCard::Counters.stat(stat)
            tiers.each { |tier, cat, id| got += 1 if now >= tier && grant(cat, id, quiet) }
          end
          if hard_won?
            HARD.each { |cat, id| got += 1 if grant(cat, id, quiet) }
          end
          @extra.each { |it, _n, _f, ok| got += 1 if (ok.call rescue false) && grant(it.cat, it.id, quiet) }
          untrack_done
          return got
        rescue StandardError => e
          Reloaded::Log.warning_once("The Trainer Card's unlocks couldn't be checked: #{e.message}", :trainer_card)
          return 0
        end

        # The League beaten on Hard: the card's Shown As is Hard (the lowest
        # used, so it was Hard all the way)
        def hard_won?
          return false unless Reloaded::TrainerCard.league? && defined?(Reloaded::Difficulty)
          return (Reloaded::Difficulty.shown rescue nil) == 2
        end

        # The milestone giving this unlock: [stat, tier], or nil
        def milestone_of(cat, id)
          MILESTONES.each do |stat, tiers|
            t = tiers.find { |_tier, c, i| c == cat && i.to_s == id.to_s }
            return [stat, t[0]] if t
          end
          return nil
        end

        def tier_words(stat, tier)
          one, many, _from = WORDS[stat]
          return tier == 1 ? _INTL(one) : _INTL(many, Reloaded::TrainerCard::Counters.num(tier))
        end

        # [need words, [now, tier] or nil, where it comes from, [stat, tier] or nil]
        def source(cat, id)
          it = item(cat, id)
          return [_INTL("From the Start"), nil, _INTL("Every Card"), nil] if it && it.start
          if (m = milestone_of(cat, id))
            stat, tier = m
            now = Reloaded::TrainerCard::Counters.stat(stat)
            return [tier_words(stat, tier), now < tier ? [now, tier] : nil, _INTL(WORDS[stat][2]), m]
          end
          return [_INTL("Beat the League on Hard"), nil, _INTL("A Hard Reward"), nil] if HARD.any? { |c, i| c == cat && i.to_s == id.to_s }
          story = STORY.find { |i, _w, _ok| cat == :titles && i.to_s == id.to_s }
          return [_INTL(story[1]), nil, _INTL("The Story"), nil] if story
          extra = @extra.find { |e| e[0].cat == cat && e[0].id.to_s == id.to_s }
          return [_INTL(extra[1]), nil, _INTL(extra[2]), nil] if extra
          return ["", nil, "", nil]
        end

        #----------------------------------------------------------------------
        # The Next Milestone: the tracked one, else the nearest
        # [stat, tier, now, [category, id]]
        #----------------------------------------------------------------------
        def tracked
          t = data["tracked"]
          return t.is_a?(Array) && t.length == 2 ? [t[0].to_sym, t[1].to_i] : nil
        end

        def track(stat, tier)
          data["tracked"] = [stat.to_s, tier.to_i] if Reloaded::SaveStore.loaded?
        end

        def untrack
          data.delete("tracked") if Reloaded::SaveStore.loaded?
        end

        def untrack_done
          t = tracked
          untrack if t && Reloaded::TrainerCard::Counters.stat(t[0]) >= t[1]
        end

        def next_milestone
          t = tracked
          if t && (tier = (MILESTONES[t[0]] || []).find { |n, _c, _i| n == t[1] })
            now = Reloaded::TrainerCard::Counters.stat(t[0])
            return [t[0], tier[0], now, [tier[1], tier[2]]] if now < tier[0]
          end
          best = nil
          MILESTONES.each do |stat, tiers|
            now = Reloaded::TrainerCard::Counters.stat(stat)
            tier = tiers.find { |n, _c, _i| n > now }
            next unless tier
            key = [now.to_f / tier[0], -tier[0]]
            best = [key, [stat, tier[0], now, [tier[1], tier[2]]]] if best.nil? || (key <=> best[0]) > 0
          end
          return best ? best[1] : nil
        end

        #----------------------------------------------------------------------
        # Backgrounds: PIF's own lists and pictures, owned and buyable as
        # PIF's Printers have them (his pick: PIF's ways stay)
        #----------------------------------------------------------------------
        def backgrounds_owned
          return [] unless $Trainer
          list = Array($Trainer.respond_to?(:unlocked_card_backgrounds) ? $Trainer.unlocked_card_backgrounds : []).map(&:to_s)
          list.unshift(Reloaded::TrainerCard.background)
          default = defined?(::Settings::DEFAULT_TRAINER_CARD_BG) ? ::Settings::DEFAULT_TRAINER_CARD_BG.to_s : "BLUE"
          list.unshift(default)
          return list.uniq.select { |id| Reloaded::TrainerCard.art_path(id) }
        end

        # Every background there is, each once: PIF's lists (with a
        # picture), the Sprite Gallery's flags, Kanto Reloaded's two
        def backgrounds_all
          return @all if @all
          ids = []
          ids += Array(defined?(::CARD_BACKGROUND_DEFAULT_PURCHASABLE) ? ::CARD_BACKGROUND_DEFAULT_PURCHASABLE : [])
          ids += (defined?(::CARD_BACKGROUND_CITY_EXCLUSIVES) ? ::CARD_BACKGROUND_CITY_EXCLUSIVES.keys : [])
          ids += (defined?(::CARD_BACKGROUND_UNLOCKABLES) ? ::CARD_BACKGROUND_UNLOCKABLES.keys : [])
          dir = File.join(Reloaded::Paths.game_dir, Reloaded::TrainerCard::BG_DIR, "flags")
          ids += Dir.children(dir).select { |f| f =~ /_FLAG\.png\z/i }.map { |f| "flags/" + f.sub(/\.png\z/i, "").delete(" ") } if File.directory?(dir)
          ids += KR_BACKGROUNDS.keys
          return @all = ids.map(&:to_s).uniq.select { |id| Reloaded::TrainerCard.art_path(id) }
        end

        # [state (:got, :buy, :locked), need words, where it comes from, [now, tier] or nil]
        def background_state(id)
          return [:got, "", "", nil] if backgrounds_owned.include?(id)
          if KR_BACKGROUNDS.key?(id)
            need, prog, from, _m = source(:backgrounds, id)
            return [:locked, need, from, prog]
          end
          if id.start_with?("flags/")
            return [:locked, _INTL("When the Sprite Gallery Shows It"), _INTL("The Sprite Gallery"), nil]
          end
          if defined?(::CARD_BACKGROUND_DEFAULT_PURCHASABLE) && ::CARD_BACKGROUND_DEFAULT_PURCHASABLE.include?(id)
            return [:buy, _INTL("Any Printer"), _INTL("Any Printer"), nil]
          end
          if defined?(::CARD_BACKGROUND_CITY_EXCLUSIVES) && (city = ::CARD_BACKGROUND_CITY_EXCLUSIVES[id])
            here = city_now == city
            place = city_name(city)
            return [here ? :buy : :locked, _INTL("Only at {1}'s Printer", place), place, nil]
          end
          if defined?(::CARD_BACKGROUND_UNLOCKABLES) && (sw = ::CARD_BACKGROUND_UNLOCKABLES[id])
            on = $game_switches && $game_switches[sw]
            return [on ? :buy : :locked, switch_words(sw), _INTL("Any Printer"), nil]
          end
          return [:locked, "", "", nil]
        end

        def city_now
          v = $game_variables ? $game_variables[Reloaded::TrainerCard.number(:VAR_CURRENT_CITY) || 291] : nil
          return v.is_a?(Symbol) ? v : :PEWTER
        end

        def city_name(city)
          words = city.to_s.capitalize
          words = { "Knotisland" => "Knot Island", "Boonisland" => "Boon Island", "Kinisland" => "Kin Island",
                    "Chronoisland" => "Chrono Island", "Vermillion" => "Vermilion" }[words] || words
          return _INTL(words)
        end

        def switch_words(sw)
          SWITCH_WORDS.each { |name, words| return _INTL(words) if ::Object.const_defined?(name) && ::Object.const_get(name) == sw }
          (1..16).each do |n|
            name = :"SWITCH_GOT_BADGE_#{n}"
            return _INTL("Earn the Badge") if ::Object.const_defined?(name) && ::Object.const_get(name) == sw
          end
          return _INTL("Unlocked by the Story")
        end

        # The Printers' price now (PIF's own, shared with them)
        def price
          return PRICE_START unless $game_switches && $game_switches[PRICE_SET]
          v = Reloaded::TrainerCard.variable(:VAR_TRAINER_CARD_BACKGROUND_PRICE)
          return v > 0 ? v : PRICE_START
        end

        # Buys one, as a Printer does: the money, PIF's own list, the price
        # up $500 everywhere. True when bought.
        def buy(id)
          cost = price
          return false unless $Trainer && $Trainer.money >= cost && background_state(id)[0] == :buy
          $Trainer.money -= cost
          $Trainer.unlocked_card_backgrounds = [] unless $Trainer.unlocked_card_backgrounds
          $Trainer.unlocked_card_backgrounds << id
          var = Reloaded::TrainerCard.number(:VAR_TRAINER_CARD_BACKGROUND_PRICE) || 329
          $game_variables[var] = cost + PRICE_STEP if $game_variables
          $game_switches[PRICE_SET] = true if $game_switches
          Reloaded::Log.info("Trainer Card: bought #{id} for $#{cost}", :trainer_card)
          return true
        end

        #----------------------------------------------------------------------
        # The toasts, on the map one at a time
        #----------------------------------------------------------------------
        def show_toast
          return if @toasts.empty? || !defined?(Reloaded::Toast) || Reloaded::Toast.sprite
          cat, id = @toasts.shift
          Reloaded::Toast.show(_INTL("New {1}: {2}", _INTL(CAT_WORDS[cat]), name(cat, id)), :icon => ICONS[cat], :pill => [_INTL("NEW"), :gold])
        end

        def map_frame
          @frames = (@frames || 0) + 1
          check if @frames % CHECK_EVERY == 0
          show_toast
        end
      end

      # On the map: story unlocks noticed, toasts shown once there's control
      module MapCheck
        def update(*args, &blk)
          ret = super
          Reloaded::TrainerCard::Unlocks.map_frame unless ($game_temp && $game_temp.in_battle) || ($game_temp && $game_temp.message_window_showing rescue false)
          return ret
        end
      end
    end
  end
end
