# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Healing Moves
#==============================================================================
# Roadmap topic healing-overworld (Healer List, chosen 2026-10-17; contents
# and looks agreed 2026-10-23): your Pokémon's healing moves work outside
# battle, with real PP. The old Kanto Reloaded's Healing Overworld Moves,
# rebuilt.
#
#   where        the Overworld Menu's Heal with Moves list (each healer and
#                its moves, the party's HP, Heal Everyone), and the party
#                menu, where they show among the field moves
#   moves        Recover, Roost, Slack Off, Shore Up, Heal Order,
#                Synthesis, Morning Sun, Moonlight (heal, or the game's own
#                Wait Until Morning or Night, outdoors), Soft-Boiled and
#                Milk Drink (1 PP and a fifth of the user's max HP, to
#                another Pokémon), Heal Pulse, Floral Healing, Wish, Pollen
#                Puff, Purify, Life Dew, Lunar Blessing, Jungle Healing,
#                Heal Bell, Aromatherapy, Revival Blessing, Healing Wish,
#                Lunar Dance, Rest, Refresh and Aqua Ring
#   Heal         the plan with the most HP for the fewest PP (never Rest,
#   Everyone     Healing Wish or Lunar Dance), shown before it runs
#   challenges   PIF's No heals (overworld) locks them; No reviving (KIF's
#                Nuzlocke turns it on) locks Revival Blessing, Healing Wish
#                and Lunar Dance
#
# A feature switch (Kanto Reloaded > Features), On to start. The screens
# are UI/HealingMovesScreen.rb.
#==============================================================================

module Reloaded
  module HealingMoves
    FEATURE = :healing_moves
    # move => what it does outside battle
    MOVES = {
      :RECOVER => :self, :ROOST => :self, :SLACKOFF => :self, :SHOREUP => :self, :HEALORDER => :self, :SYNTHESIS => :self,
      :MORNINGSUN => :time, :MOONLIGHT => :time,
      :SOFTBOILED => :give, :MILKDRINK => :give,
      :HEALPULSE => :other, :POLLENPUFF => :other, :FLORALHEALING => :target, :WISH => :wish, :PURIFY => :purify,
      :LIFEDEW => :party, :LUNARBLESSING => :party_cure, :JUNGLEHEALING => :party_cure,
      :HEALBELL => :party_status, :AROMATHERAPY => :party_status,
      :REVIVALBLESSING => :revive, :HEALINGWISH => :sacrifice, :LUNARDANCE => :sacrifice_pp,
      :REST => :rest, :REFRESH => :refresh, :AQUARING => :aquaring
    }.freeze
    TARGETED = [:give, :other, :target, :wish, :purify, :revive, :sacrifice, :sacrifice_pp].freeze
    REVIVING = [:revive, :sacrifice, :sacrifice_pp].freeze
    NOT_PLANNED = [:rest, :sacrifice, :sacrifice_pp].freeze
    WORDS = {
      :self => "Heals Itself", :time => "Heals Itself, or Waits", :give => "Heals One Pokémon", :other => "Heals One Pokémon",
      :target => "Heals One Pokémon", :wish => "Heals One Pokémon", :purify => "Cures One Pokémon", :party => "Heals the Party",
      :party_cure => "Heals and Cures the Party", :party_status => "Cures the Party", :revive => "Revives One Pokémon",
      :sacrifice => "Faints to Heal One Pokémon", :sacrifice_pp => "Faints to Heal One Pokémon", :rest => "Heals Itself, Sleeps",
      :refresh => "Cures Itself", :aquaring => "Heals Itself a Little"
    }.freeze
    REFRESHABLE = [:BURN, :POISON, :PARALYSIS].freeze

    @deferred = nil
    @screens = []

    class << self
      def boot
        Reloaded::Features.register(FEATURE, :name => "Healing Moves", :order => 26,
          :description => "Your Pokémon's healing moves work outside battle, with real PP: Heal with Moves in the Overworld Menu, and the party menu.")
        register_menu_entry
        install
        return true
      end

      def on?
        return Reloaded::Features.on?(FEATURE)
      end

      def handles?(id)
        return MOVES.key?(id.to_s.upcase.to_sym)
      end

      def kind(id)
        return MOVES[id.to_s.upcase.to_sym]
      end

      def party
        return $Trainer ? Array($Trainer.party).compact : []
      rescue StandardError
        return []
      end

      def move_name(id)
        return (::GameData::Move.get(id).name rescue id.to_s.capitalize)
      end

      #------------------------------------------------------------------------
      # The party as plain numbers, so a move's effect can be worked out
      # (and Heal Everyone's plan) without touching the Pokémon
      #------------------------------------------------------------------------
      def snapshot(list = party)
        return list.map do |p|
          pp = {}
          Array(p.moves).each { |m| pp[m.id] = m.pp if m }
          { :hp => p.hp.to_i, :max => p.totalhp.to_i, :status => status_of(p), :egg => p.egg?,
            :pp => pp, :pp_full => pp_full?(p), :big_root => big_root?(p) }
        end
      end

      def status_of(p)
        st = p.status
        return st.nil? || st == :NONE ? nil : st
      rescue StandardError
        return nil
      end

      def pp_full?(p)
        return Array(p.moves).all? { |m| m.nil? || m.pp >= m.total_pp }
      rescue StandardError
        return true
      end

      def big_root?(p)
        return p.respond_to?(:hasItem?) && p.hasItem?(:BIGROOT) ? true : false
      rescue StandardError
        return false
      end

      def deep(s)
        return s.map { |h| h.merge(:pp => h[:pp].dup) }
      end

      def living?(h)
        return !h[:egg] && h[:hp] > 0
      end

      def half(n)
        return [(n + 1) / 2, 1].max
      end

      def heal_by(h, amount)
        h[:hp] = [h[:hp] + amount, h[:max]].min
      end

      # The party after user u uses move id (on target t), or nil when it
      # would do nothing (or can't be used)
      def effect(s, u, id, t = nil)
        k = kind(id)
        return nil unless k && s[u] && living?(s[u]) && s[u][:pp][id].to_i > 0
        st = deep(s)
        user = st[u]
        tgt = t.nil? ? nil : st[t]
        case k
        when :self, :time
          return nil if user[:hp] >= user[:max]
          heal_by(user, half(user[:max]))
        when :aquaring
          return nil if user[:hp] >= user[:max]
          amount = [user[:max] / 16, 1].max
          amount = amount * 13 / 10 if user[:big_root]
          heal_by(user, amount)
        when :give
          return nil unless tgt && t != u && living?(tgt) && tgt[:hp] < tgt[:max]
          amount = [user[:max] / 5, 1].max
          return nil if user[:hp] <= amount
          user[:hp] -= amount
          heal_by(tgt, amount)
        when :other, :target
          return nil unless tgt && (k == :target || t != u) && living?(tgt) && tgt[:hp] < tgt[:max]
          heal_by(tgt, half(tgt[:max]))
        when :wish
          return nil unless tgt && living?(tgt) && tgt[:hp] < tgt[:max]
          heal_by(tgt, half(user[:max]))
        when :purify
          return nil unless tgt && t != u && living?(tgt) && tgt[:status]
          tgt[:status] = nil
          heal_by(user, half(user[:max]))
        when :party, :party_cure
          changed = false
          st.each do |h|
            next unless living?(h)
            changed ||= h[:hp] < h[:max] || (k == :party_cure && h[:status])
            heal_by(h, [h[:max] / 4, 1].max)
            h[:status] = nil if k == :party_cure
          end
          return nil unless changed
        when :party_status
          return nil unless st.any? { |h| living?(h) && h[:status] }
          st.each { |h| h[:status] = nil if living?(h) }
        when :revive
          return nil unless tgt && !tgt[:egg] && tgt[:hp] <= 0
          tgt[:hp] = half(tgt[:max])
          tgt[:status] = nil
        when :sacrifice, :sacrifice_pp
          return nil unless tgt && t != u && living?(tgt)
          return nil unless tgt[:hp] < tgt[:max] || tgt[:status] || (k == :sacrifice_pp && !tgt[:pp_full])
          tgt[:hp] = tgt[:max]
          tgt[:status] = nil
          tgt[:pp_full] = true if k == :sacrifice_pp
          user[:hp] = 0
          user[:status] = nil
        when :rest
          return nil unless user[:hp] < user[:max] || (user[:status] && user[:status] != :SLEEP)
          user[:hp] = user[:max]
          user[:status] = :SLEEP
        when :refresh
          return nil unless REFRESHABLE.include?(user[:status])
          user[:status] = nil
        end
        user[:pp][id] -= 1
        return st
      end

      def targeted?(id)
        return TARGETED.include?(kind(id))
      end

      # Who it can be used on now
      def targets(u, id, s = snapshot)
        return [] unless targeted?(id)
        return (0...s.length).select { |t| effect(s, u, id, t) }
      end

      #------------------------------------------------------------------------
      # Rules and challenges
      #------------------------------------------------------------------------
      def no_overworld_heals?
        return $PokemonSystem && $PokemonSystem.respond_to?(:no_healing_items_ow) && $PokemonSystem.no_healing_items_ow ? true : false
      rescue StandardError
        return false
      end

      def no_reviving?
        return $PokemonSystem && $PokemonSystem.respond_to?(:no_reviving) && $PokemonSystem.no_reviving ? true : false
      rescue StandardError
        return false
      end

      # Waiting until morning or night works outdoors only (the game's own)
      def outdoors?
        meta = ::GameData::MapMetadata.try_get($game_map.map_id)
        return meta && meta.outdoor_map ? true : false
      rescue StandardError
        return false
      end

      # true, or why user u can't use the move now
      def usable(u, id, s = snapshot)
        user = s[u]
        k = kind(id)
        return _INTL("Can't Be Used") unless user && k
        return _INTL("Fainted") unless living?(user)
        return _INTL("Locked by No Heals (Overworld)") if no_overworld_heals?
        return _INTL("Locked by No Reviving") if REVIVING.include?(k) && no_reviving?
        return _INTL("No PP Left") if user[:pp][id].to_i <= 0
        return _INTL("Not Enough HP") if k == :give && user[:hp] <= [user[:max] / 5, 1].max
        if targeted?(id)
          return true unless targets(u, id, s).empty?
          return case k
                 when :revive then _INTL("No One to Revive")
                 when :purify then _INTL("Nothing to Cure")
                 else _INTL("No One to Heal")
                 end
        end
        return true if effect(s, u, id)
        return true if k == :time && outdoors?
        return case k
               when :party_status, :refresh then _INTL("Nothing to Cure")
               when :party, :party_cure then _INTL("Everyone's Healthy")
               else _INTL("Full HP")
               end
      end

      # The healers: [[party index, [move ids]]], in party order
      def healers(list = party)
        out = []
        list.each_with_index do |p, i|
          next if p.egg?
          ids = Array(p.moves).compact.map(&:id).select { |id| handles?(id) }
          out << [i, ids] unless ids.empty?
        end
        return out
      end

      #------------------------------------------------------------------------
      # What a move would do: [[party index, hp, hp after, max, words]] for
      # each Pokémon it changes (the user's row last), and a line about it
      #------------------------------------------------------------------------
      def preview(u, id, t = nil, s = snapshot)
        after = effect(s, u, id, t)
        return nil unless after
        rows = []
        order = (0...s.length).to_a
        order = [t] + (order - [t, u]) + [u] if t
        order = (order - [u]) + [u] unless t
        order.uniq.each do |i|
          a = s[i]
          b = after[i]
          next if a == b && i != u
          rows << [i, a[:hp], b[:hp], a[:max], change_words(a, b)]
        end
        user_row = rows.find { |r| r[0] == u }
        pp_before = s[u][:pp][id].to_i
        user_row << _INTL("PP {1} to {2}", pp_before, pp_before - 1) if user_row
        return { :rows => rows, :note => note_for(u, id, t) }
      end

      def change_words(a, b)
        parts = []
        if a[:hp] <= 0 && b[:hp] > 0
          parts << _INTL("Revived")
        elsif b[:hp] <= 0 && a[:hp] > 0
          parts << _INTL("Faints")
        elsif b[:hp] > a[:hp]
          parts << _INTL("+{1} HP", b[:hp] - a[:hp])
        elsif b[:hp] < a[:hp]
          parts << _INTL("-{1} HP", a[:hp] - b[:hp])
        end
        if a[:status] && !b[:status] && b[:hp] > 0
          parts << _INTL("Cures {1}", status_name(a[:status]))
        elsif b[:status] == :SLEEP && a[:status] != :SLEEP
          parts << _INTL("Falls Asleep")
        end
        parts << _INTL("PP Restored") if !a[:pp_full] && b[:pp_full]
        return parts.join(", ")
      end

      def status_name(st)
        return (::GameData::Status.get(st).name rescue st.to_s.capitalize)
      end

      def note_for(u, id, t)
        user = party[u]
        name = user ? user.name : ""
        case kind(id)
        when :give then return _INTL("{1} gives up a fifth of its max HP.", name)
        when :sacrifice, :sacrifice_pp then return _INTL("{1} faints to heal {2}.", name, t ? party[t].name : "")
        when :rest then return _INTL("{1} falls asleep.", name)
        end
        return nil
      end

      #------------------------------------------------------------------------
      # Using a move: the Pokémon change as effect says. Returns the
      # preview it followed, or nil when it couldn't be used.
      #------------------------------------------------------------------------
      def use!(u, id, t = nil)
        list = party
        s = snapshot(list)
        return nil unless usable(u, id, s) == true
        before = preview(u, id, t, s)
        after = effect(s, u, id, t)
        return nil unless after && before
        write(list, s, after, u, id)
        Reloaded::Log.info("Healing move: #{list[u].name}'s #{id}#{t ? " on #{list[t].name}" : ""}", :healing_moves)
        return before
      end

      def write(list, s, after, u, id)
        list.each_with_index do |p, i|
          a = s[i]
          b = after[i]
          next if a == b
          if b[:hp] != a[:hp]
            if b[:hp] <= 0
              p.hp = 0
            elsif a[:hp] <= 0
              p.hp = b[:hp]                    # revived
            else
              p.hp = b[:hp]
            end
          end
          if a[:status] && !b[:status]
            p.heal_status
          elsif b[:status] == :SLEEP && a[:status] != :SLEEP
            p.status = :SLEEP
            p.statusCount = 3 if p.respond_to?(:statusCount=)
          end
          p.heal_PP if !a[:pp_full] && b[:pp_full]
        end
        mv = Array(list[u].moves).find { |m| m && m.id == id }
        mv.pp = mv.pp - 1 if mv
      end

      #------------------------------------------------------------------------
      # Heal Everyone: the plan with the most HP for the fewest PP, worked
      # out on the numbers: each step the move that does the most good, until
      # none would do 5% of a Pokémon's HP (no PP spent on tiny top-ups).
      # [[user, move, target]] in order, and the party after it.
      #------------------------------------------------------------------------
      def plan(s = snapshot)
        steps = []
        cur = s
        return [[], s] if no_overworld_heals?
        40.times do
          best = nil
          best_score = 0.05
          healers_now = (0...cur.length).select { |u| living?(cur[u]) }
          healers_now.each do |u|
            cur[u][:pp].each_key do |id|
              k = kind(id)
              next if k.nil? || NOT_PLANNED.include?(k) || (k == :revive && no_reviving?)
              (targeted?(id) ? (0...cur.length).to_a : [nil]).each do |t|
                after = effect(cur, u, id, t)
                next unless after
                sc = score(cur, after)
                if sc > best_score
                  best = [u, id, t, after]
                  best_score = sc
                end
              end
            end
          end
          break unless best
          steps << best[0, 3]
          cur = best[3]
        end
        return [steps, cur]
      end

      # How much better off the party is: each Pokémon's HP as a share of its
      # max, a cured status worth a quarter, a revive half more
      def score(a, b)
        sc = 0.0
        a.each_with_index do |x, i|
          y = b[i]
          next if x[:egg]
          sc += (y[:hp] - x[:hp]).to_f / [x[:max], 1].max
          sc += 0.25 if x[:status] && !y[:status] && y[:hp] > 0
          sc += 0.5 if x[:hp] <= 0 && y[:hp] > 0
        end
        return sc
      end

      # Runs a plan, each step checked again as it goes; how many ran
      def run_plan(steps)
        done = 0
        steps.each { |u, id, t| done += 1 if use!(u, id, t) }
        Reloaded::Log.info("Heal Everyone: #{done} of #{steps.length} moves", :healing_moves)
        return done
      end

      def plan_pp(steps)
        return steps.length
      end

      #------------------------------------------------------------------------
      # The game's own Wait Until Morning or Night, passed through once
      #------------------------------------------------------------------------
      def defer_wait(pkmn, id)
        @deferred = [pkmn.object_id, id]
      end

      def take_deferred?(pkmn, id)
        hit = @deferred == [pkmn.object_id, id]
        @deferred = nil if hit
        return hit
      end

      def deferred?(pkmn, id)
        return @deferred == [pkmn.object_id, id]
      end

      def party_screen
        return @screens.last
      end

      private

      def register_menu_entry
        return unless defined?(Reloaded::OverworldMenu)
        Reloaded::OverworldMenu.register(:heal_with_moves, :name => "Heal with Moves", :kind => :action, :priority => 26,
          :feature => FEATURE,
          :condition => proc { !healers.empty? },
          :usable => proc { no_overworld_heals? ? _INTL("The No Heals (Overworld) challenge is On.") : true },
          :description => "Use your Pokémon's healing moves, or Heal Everyone.",
          :handler => proc { |menu|
            result = nil
            if defined?(Reloaded::HealingMovesScreen)
              menu.send(:hidden) { result = Reloaded::HealingMovesScreen.open_list }
            end
            result.respond_to?(:call) ? result : nil
          })
      end

      def install
        h = Reloaded::Hooks
        if defined?(::HiddenMoveHandlers)
          hm = ::HiddenMoveHandlers.singleton_class
          # the party menu lists them as field moves
          h.around(FEATURE, hm, :hasHandler, :id => :healing_moves_listed) do |original, *args|
            handles?(args[0]) ? true : original.call(*args)
          end
          h.around(FEATURE, hm, :triggerCanUseMove, :id => :healing_moves_can_use) do |original, *args|
            id, pkmn, showmsg = args
            next original.call(*args) unless handles?(id) && !deferred?(pkmn, id)
            u = party.index(pkmn)
            r = u ? usable(u, id) : _INTL("Can't Be Used")
            if r != true
              pbMessage(r.to_s) if showmsg && defined?(pbMessage)
              next false
            end
            true
          end
          # the game's own party screen (Kanto Reloaded's takes them over
          # before this): the move is used there, and the screen stays open
          h.around(FEATURE, hm, :triggerConfirmUseMove, :id => :healing_moves_confirm) do |original, *args|
            id, pkmn = args
            next original.call(*args) unless handles?(id)
            next original.call(*args) if deferred?(pkmn, id)
            screen = party_screen
            next true unless screen && defined?(Reloaded::HealingMovesScreen)
            handled = Reloaded::HealingMovesScreen.from_party(screen.instance_variable_get(:@scene), pkmn, id)
            handled ? false : original.call(*args)
          end
          h.around(FEATURE, hm, :triggerUseMove, :id => :healing_moves_use) do |original, *args|
            id, pkmn = args
            next original.call(*args) unless handles?(id)
            next original.call(*args) if take_deferred?(pkmn, id)
            next false unless defined?(Reloaded::HealingMovesScreen)
            Reloaded::HealingMovesScreen.from_field(pkmn, id)
          end
        end
        if defined?(::PokemonPartyScreen)
          h.around(FEATURE, ::PokemonPartyScreen, :pbPokemonScreen, :id => :healing_moves_party) do |original, *args|
            @screens << original.receiver
            begin
              original.call(*args)
            ensure
              @screens.pop
            end
          end
        end
        # Kanto Reloaded's Party Screen: picked in a Pokémon's menu, the move
        # is used right there (Soft-Boiled and Milk Drink too)
        if defined?(Reloaded::PartyScreen) && Reloaded::PartyScreen.respond_to?(:take_field_move)
          MOVES.each_key do |id|
            Reloaded::PartyScreen.take_field_move(id) do |scene, pkmn, move_id|
              on? && defined?(Reloaded::HealingMovesScreen) ? Reloaded::HealingMovesScreen.from_party(scene, pkmn, move_id) : false
            end
          end
        end
        return true
      end
    end
  end
end
