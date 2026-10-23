# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the PokeVial
#==============================================================================
# Roadmap topic 42 (Confirm Dialog, chosen 2026-10-17; contents agreed
# 2026-10-22): limited party healing in place of KIF's unlimited Heal
# Pokémon (Kuray QoL), merged from the old Kanto Reloaded's and Hoenn
# Reloaded's. Its charges refill at Pokémon Centers.
#
#   where        the Pause Menu's Pinned row (KIF's Heal Pokémon steps aside
#                while it's on) and the Overworld Menu's Main page; both
#                show while Kuray QoL is On, as KIF's Heal did
#   using it     a dialog with the charges and a Heal Preview (each
#                Pokémon's HP, what it regains), Use and Back
#                (UI/PokeVialScreen.rb). A charge is only used when someone
#                needs healing.
#   charges      3, or with Progressive Uses one more for every two Badges,
#                up to 5; a new one arrives full, with a toast
#   cooldown     optional real time between uses; the dialog's Use button
#                counts down, or a toast says when (Cooldown Wait)
#   refills      at a Pokémon Center once the nurse heals you: Ask (a
#                dialog with the cost), Automatic or Never; a cost per
#                missing charge is optional
#   Low HP       the PokeVial's tile and row glow red while a Pokémon has
#   Reminder     fainted or the party's HP is under half (and a charge is
#                left)
#   items        PokeVial Charge (one charge) and PokeVial Refill (all of
#                them), used from the Bag; added now, sold once the Shop
#                adds them
#   blocked      wherever KIF blocks its Heal (KIF::PauseMenu.restricted?),
#                in battle, the Safari Zone and the Bug-Catching Contest, and
#                while PIF's No heals (overworld) challenge is On
#
# Balance settings are kept by each save; the Low HP Reminder and Cooldown
# Wait are a preference for every save. The charges, the capacity last seen
# and the last use are in the save (SaveStore section "pokevial").
#
# For other mods (Hoenn Reloaded's API, the same names):
#
#   Reloaded::PokeVial.uses / configured_max_uses
#   Reloaded::PokeVial.add_uses(1, source: :my_mod)          # charges given
#   Reloaded::PokeVial.grant_full_refill(source: :my_mod)
#   Reloaded::PokeVial.increase_max_uses(1, source: :my_mod, refill: true)
#   Reloaded::PokeVial.register_refill_source(:my_bed) { |vial| true }
#   Reloaded::PokeVial.refill_from_source(:my_bed)
#   Reloaded::PokeVial.on(:before_use, :my_mod) { |ctx| false }   # false stops it
#
# Events: :before_use, :after_use, :before_refill, :after_refill and
# :capacity_changed, each with a context hash (:source, :uses_before,
# :uses_after, :max_uses, ...). A :before_ handler returning false stops it
# (ctx[:message] says why).
#==============================================================================

module Reloaded
  module PokeVial
    FEATURE = :pokevial
    PAGE = :pokevial
    SECTION = :pokevial
    ICON = "Graphics/PauseMenu/POKEVIAL"
    MAX_CAP = 5
    DEFAULT_MAX = 3
    COOLDOWNS = [5, 10, 15, 20, 25, 30, 35, 40, 45].freeze      # minutes
    HEAL_MODES = [:full, :hp_only, :no_revive].freeze
    REFILL_MODES = [:ask, :automatic, :never].freeze
    EVENTS = [:before_use, :after_use, :before_refill, :after_refill, :capacity_changed].freeze
    ITEMS = {
      :POKEVIAL_CHARGE => { "name" => "PokeVial Charge", "name_plural" => "PokeVial Charges", "pocket" => 2,
                            "price" => 500, "description" => "A compact charge that restores one PokeVial use." },
      :POKEVIAL_REFILL => { "name" => "PokeVial Refill", "name_plural" => "PokeVial Refills", "pocket" => 2,
                            "price" => 1500, "description" => "A stored refill that restores all PokeVial charges." }
    }.freeze

    @callbacks = {}
    @refill_sources = {}
    @healing = false
    @center_depth = 0

    class << self
      def boot
        register_settings
        Reloaded::Features.register(FEATURE, :name => "PokeVial", :page => PAGE, :order => 25,
          :description => "Heal your party anywhere a few times, then refill it at a Pokémon Center. Off brings back KIF's Heal Pokémon.")
        Reloaded::SaveStore.register(SECTION)
        Reloaded::Events.on(:save_loaded, :pokevial_capacity, 70) { start_capacity }
        Reloaded::Events.on(:new_game, :pokevial_capacity, 70) { start_capacity }
        register_items
        register_menu_entries
        install
        return true
      end

      def key(id)
        return :"pokevial.#{id}"
      end

      def on?
        return Reloaded::Features.on?(FEATURE)
      end

      def setting(id)
        return Reloaded::Settings.get(key(id))
      end

      #------------------------------------------------------------------------
      # Charges
      #------------------------------------------------------------------------
      def data
        return Reloaded::SaveStore.section(SECTION)
      rescue StandardError
        return nil
      end

      def progressive?
        return setting(:progressive) ? true : false
      end

      def badges
        return $Trainer ? $Trainer.badge_count.to_i : 0
      rescue StandardError
        return 0
      end

      # How many charges it holds: one more for every two Badges with
      # Progressive Uses, else Max Uses; never less than a mod unlocked
      def configured_max_uses
        n = progressive? ? 1 + badges / 2 : setting(:max_uses).to_i
        d = data
        n = [n, d["unlocked"].to_i].max if d
        return [[n, 1].max, MAX_CAP].min
      rescue StandardError
        return DEFAULT_MAX
      end
      alias max_charges configured_max_uses

      # Charges left (full on a save that never used it)
      def uses
        d = data
        return 0 unless d
        max = configured_max_uses
        v = d["uses"].nil? ? max : [[d["uses"].to_i, 0].max, max].min
        d["uses"] = v
        return v
      end
      alias charges uses

      def set_uses(n)
        d = data
        return false unless d
        d["uses"] = [[n.to_i, 0].max, configured_max_uses].min
        return true
      end

      # A save starts with the capacity it has (no toast for what it had)
      def start_capacity
        d = data
        return unless d
        d["max_seen"] ||= configured_max_uses
      end

      # More room since last time (a Badge, a mod): the new charges arrive
      # full, and a toast says so. Checked on each step and when it opens.
      def sync_capacity(notify = true)
        d = data
        return false unless d && on?
        max = configured_max_uses
        seen = d["max_seen"]
        if seen.nil? || max < seen.to_i
          d["max_seen"] = max
          return false
        end
        return false if max == seen.to_i
        gained = max - seen.to_i
        before = uses
        d["uses"] = [before + gained, max].min
        d["max_seen"] = max
        run_callbacks(:capacity_changed, :source => :badges, :max_uses => max, :added => gained,
                      :uses_before => before, :uses_after => d["uses"])
        Reloaded::Log.info("PokeVial capacity #{seen}->#{max}, #{gained} charge(s) added", :pokevial)
        Reloaded::PokeVialScreen.capacity_toast(max, gained) if notify && defined?(Reloaded::PokeVialScreen)
        return true
      end

      #------------------------------------------------------------------------
      # Cooldown
      #------------------------------------------------------------------------
      def cooldown?
        return setting(:cooldown) ? true : false
      end

      def cooldown_seconds
        return COOLDOWNS[setting(:cooldown_time).to_i].to_i * 60
      end

      # Seconds until it can be used again (0: ready). A clock set back
      # starts it afresh rather than waiting longer.
      def cooldown_left
        return 0 unless cooldown?
        d = data
        last = d && d["last_use"]
        return 0 unless last
        left = last.to_f + cooldown_seconds - Time.now.to_f
        return 0 if left <= 0 || left > cooldown_seconds
        return left.ceil
      end

      # How far the wait has gone, 0.0 to 1.0
      def cooldown_done
        total = cooldown_seconds
        return 1.0 if total <= 0
        return 1.0 - cooldown_left.to_f / total
      end

      def clock(seconds)
        s = seconds.to_i
        return format("%d:%02d", s / 60, s % 60)
      end

      # The time it'll be ready, as the player's clock says it ("3:47 PM")
      def ready_at
        t = Time.now + cooldown_left
        return t.strftime("%-I:%M %p") rescue t.strftime("%I:%M %p")
      end

      #------------------------------------------------------------------------
      # Healing
      #------------------------------------------------------------------------
      def heal_mode
        return HEAL_MODES[setting(:heal_mode).to_i] || :full
      end

      def party
        return $Trainer ? Array($Trainer.party).compact : []
      rescue StandardError
        return []
      end

      # What a charge would do for one Pokémon: [words, tone] (tones: :green,
      # :pink revived, :blue PP only; :healthy nothing to heal, :dim nothing
      # it can do)
      def preview(pkmn)
        return [_INTL("Egg"), :dim] if pkmn.egg?
        mode = heal_mode
        if pkmn.hp <= 0
          return [_INTL("Dead"), :dim] if nuzlocke_dead?(pkmn)
          return [_INTL("Stays Fainted"), :dim] if mode == :no_revive || no_reviving?
          return [_INTL("Revived"), :pink]
        end
        parts = []
        missing = pkmn.totalhp - pkmn.hp
        parts << _INTL("+{1} HP", missing) if missing > 0
        if mode != :hp_only
          st = pkmn.status
          if st && st != :NONE
            name = (::GameData::Status.get(st).name rescue st.to_s.capitalize)
            parts << _INTL("Cures {1}", name)
          end
          if parts.empty? && pp_missing?(pkmn)
            return [_INTL("PP Restored"), :blue]
          end
        end
        return [_INTL("Healthy"), :healthy] if parts.empty?
        return [parts.join(", "), :green]
      end

      # PIF's No reviving challenge (KIF's Nuzlocke turns it on): the game's
      # own heal leaves a fainted Pokémon fainted
      def no_reviving?
        return $PokemonSystem && $PokemonSystem.respond_to?(:no_reviving) && $PokemonSystem.no_reviving ? true : false
      rescue StandardError
        return false
      end

      # Fainted in KIF's Nuzlocke: dead for good
      def nuzlocke_dead?(pkmn)
        return false unless pkmn.respond_to?(:kif_nz_dead) && pkmn.kif_nz_dead
        return defined?(::KIF::Nuzlocke) && ::KIF::Nuzlocke.respond_to?(:on?) ? (::KIF::Nuzlocke.on? ? true : false) : false
      rescue StandardError
        return false
      end

      # A fainted Pokémon a charge could bring back
      def revivable?(pkmn)
        return pkmn.hp <= 0 && !pkmn.egg? && heal_mode != :no_revive && !no_reviving? && !nuzlocke_dead?(pkmn)
      end

      def pp_missing?(pkmn)
        return Array(pkmn.moves).any? { |m| m && m.pp < m.total_pp }
      rescue StandardError
        return false
      end

      # A charge would do something for this one
      def gains?(pkmn)
        return [:green, :pink, :blue].include?(preview(pkmn)[1])
      end

      def needs_healing?
        return party.any? { |p| !p.egg? && gains?(p) }
      end

      def heal_party
        mode = heal_mode
        party.each do |pkmn|
          next if pkmn.egg?
          case mode
          when :hp_only then pkmn.heal_HP
          when :no_revive then pkmn.heal unless pkmn.hp <= 0
          else pkmn.heal
          end
        end
        return true
      end

      def healing_from_vial?
        return @healing
      end

      # A Pokémon has fainted (one a charge could bring back), or the party's
      # HP is under half (the ones that can't be revived left out)
      def party_hurt?
        mons = party.reject { |p| p.egg? || (p.hp <= 0 && !revivable?(p)) }
        return false if mons.empty?
        return true if mons.any? { |p| p.hp <= 0 }
        total = mons.sum { |p| p.totalhp.to_i }
        return total > 0 && mons.sum { |p| p.hp.to_i } * 2 < total
      rescue StandardError
        return false
      end

      # The Low HP Reminder: hurt, and a charge to do something about it
      def low_hp_alert?
        return false unless on? && setting(:low_hp) && usable == true
        return party_hurt? && uses > 0
      end

      #------------------------------------------------------------------------
      # Where it can be used
      #------------------------------------------------------------------------
      # Shown at all: as KIF's Heal Pokémon was, while Kuray QoL is On
      def shown?
        return false unless on?
        return true unless $PokemonSystem && $PokemonSystem.respond_to?(:kurayqol)
        return $PokemonSystem.kurayqol == 1
      rescue StandardError
        return true
      end

      def blocked?
        return true if defined?(::KIF::PauseMenu) && ::KIF::PauseMenu.respond_to?(:restricted?) && ::KIF::PauseMenu.restricted?
        return true if $game_temp && $game_temp.respond_to?(:in_battle) && $game_temp.in_battle
        return true if respond_to?(:pbInSafari?, true) && pbInSafari?
        return true if respond_to?(:pbInBugContest?, true) && pbInBugContest?
        return false
      rescue StandardError
        return false
      end

      # true, or why it can't be used here (the menus show it locked)
      def usable
        return _INTL("You don't have any Pokémon yet.") if party.reject(&:egg?).empty?
        return _INTL("The No Heals (Overworld) challenge is On.") if no_overworld_heals?
        return _INTL("The PokeVial can't be used here.") if blocked?
        return true
      end

      # PIF's No heals (overworld) challenge: no healing outside battle (his
      # call, 2026-10-23: the PokeVial follows it too)
      def no_overworld_heals?
        return $PokemonSystem && $PokemonSystem.respond_to?(:no_healing_items_ow) && $PokemonSystem.no_healing_items_ow ? true : false
      rescue StandardError
        return false
      end

      # true, or why Use is dimmed in the dialog: [reason, kind]
      def use_state
        return [_INTL("No Charges Left"), :empty] if uses <= 0
        return [_INTL("Ready in {1}", clock(cooldown_left)), :cooldown] if cooldown_left > 0
        return [_INTL("All Healthy"), :healthy] unless needs_healing?
        return true
      end

      # Uses a charge: heals the party as Heal Mode says. Returns true, or
      # false (and nothing changes) when it can't.
      def use!(source = :menu)
        return false unless on? && usable == true && use_state == true
        before = uses
        ctx = { :source => source, :uses_before => before, :uses_after => before - 1,
                :max_uses => configured_max_uses, :heal_mode => heal_mode }
        return false unless run_callbacks(:before_use, ctx)
        @healing = true
        heal_party
        set_uses(before - 1)
        data["last_use"] = Time.now.to_f
        ctx[:uses_after] = uses
        run_callbacks(:after_use, ctx)
        Reloaded::Log.info("PokeVial used (#{source}): #{uses}/#{configured_max_uses} left", :pokevial)
        return true
      ensure
        @healing = false
      end

      #------------------------------------------------------------------------
      # Refills
      #------------------------------------------------------------------------
      def refill_mode
        return REFILL_MODES[setting(:center_refill).to_i] || :ask
      end

      def missing
        return [configured_max_uses - uses, 0].max
      end

      def refill_cost(n = missing)
        return 0 unless setting(:refill_cost)
        return n * setting(:cost_per_charge).to_i
      end

      def money
        return $Trainer ? $Trainer.money.to_i : 0
      rescue StandardError
        return 0
      end

      # Every charge back. source: :pokecenter, :item, a mod's id
      def refill!(source = :script, cost = 0)
        before = uses
        max = configured_max_uses
        return false if before >= max
        ctx = { :source => source, :uses_before => before, :uses_after => max, :max_uses => max,
                :restored => max - before, :cost => cost.to_i }
        return false unless run_callbacks(:before_refill, ctx)
        $Trainer.money -= cost.to_i if cost.to_i > 0 && $Trainer
        set_uses(max)
        ctx[:uses_after] = uses
        run_callbacks(:after_refill, ctx)
        Reloaded::Log.info("PokeVial refilled (#{source}): #{uses}/#{max}#{cost.to_i > 0 ? ", cost #{cost}" : ""}", :pokevial)
        return true
      end

      # The nurse healed the party: Ask, Automatic or Never
      def center_refill
        return false unless on? && shown? && missing > 0
        mode = refill_mode
        return false if mode == :never
        cost = refill_cost
        if mode == :ask
          return false unless defined?(Reloaded::PokeVialScreen) && Reloaded::PokeVialScreen.ask_refill
          return refill!(:pokecenter, refill_cost)
        end
        if cost > money
          Reloaded::PokeVialScreen.toast(_INTL("Not enough money to refill the PokeVial."), :red_pill => "$#{cost}") if defined?(Reloaded::PokeVialScreen)
          return false
        end
        done = refill!(:pokecenter, cost)
        Reloaded::PokeVialScreen.charges_toast(_INTL("The PokeVial was refilled.")) if done && defined?(Reloaded::PokeVialScreen)
        return done
      end

      # A Pokémon Center: the map the game saves as the last one visited,
      # or one whose name says so
      def pokemon_center?
        map = $game_map ? $game_map.map_id.to_i : 0
        return false if map <= 0
        center = ($PokemonGlobal.pokecenterMapId.to_i rescue -1)
        return true if center > 0 && center == map
        name = (pbGetMapNameFromId(map).to_s rescue "").downcase.delete("é")
        return name.include?("pokmon center") || name.include?("poke center") || name.include?("pokecenter")
      rescue StandardError
        return false
      end

      #------------------------------------------------------------------------
      # For other mods (Hoenn Reloaded's API)
      #------------------------------------------------------------------------
      def add_uses(amount, source: :script, notify: true, allow_overflow: false)
        n = amount.to_i
        return 0 if n <= 0 || data.nil?
        before = uses
        target = allow_overflow ? before + n : [before + n, configured_max_uses].min
        data["uses"] = target
        added = target - before
        if added > 0
          Reloaded::Log.info("PokeVial: #{added} charge(s) from #{source}", :pokevial)
          Reloaded::PokeVialScreen.charges_toast(_INTL("The PokeVial regained {1}.", added == 1 ? _INTL("a charge") : _INTL("{1} charges", added))) if notify && defined?(Reloaded::PokeVialScreen)
        end
        return added
      end

      def grant_full_refill(source: :script, notify: true)
        done = refill!(source)
        Reloaded::PokeVialScreen.charges_toast(_INTL("The PokeVial was fully refilled.")) if done && notify && defined?(Reloaded::PokeVialScreen)
        return done
      end
      alias grant_refill grant_full_refill

      def increase_max_uses(amount = 1, source: :script, refill: false, notify: true)
        d = data
        return false unless d
        before = configured_max_uses
        d["unlocked"] = [[before + amount.to_i, 1].max, MAX_CAP].min
        after = configured_max_uses
        return false if after == before
        d["max_seen"] = after
        set_uses(refill ? after : uses + (after - before))
        run_callbacks(:capacity_changed, :source => source, :max_uses => after, :added => after - before)
        Reloaded::PokeVialScreen.capacity_toast(after, after - before) if notify && defined?(Reloaded::PokeVialScreen)
        return true
      end

      def can_refill?
        return on? && missing > 0
      end

      def register_refill_source(id, handler = nil, &block)
        callable = block || handler
        return false unless callable.respond_to?(:call)
        @refill_sources[id.to_sym] = callable
        return true
      end

      def refill_from_source(id, notify: true)
        handler = @refill_sources[id.to_sym]
        return false unless handler && handler.call(self) != false
        return grant_full_refill(source: id.to_sym, notify: notify)
      rescue StandardError => e
        Reloaded::Log.exception("PokeVial refill source #{id} failed", e, :pokevial)
        return false
      end

      def on(event, id = nil, handler = nil, &block)
        return register_callback(event, id, handler, &block)
      end

      def register_callback(event, id = nil, handler = nil, &block)
        event = event.to_sym
        callable = block || handler
        return false unless EVENTS.include?(event) && callable.respond_to?(:call)
        cid = id ? id.to_sym : callable.object_id
        list = (@callbacks[event] ||= [])
        list.reject! { |row| row[0] == cid }
        list << [cid, callable]
        return true
      end

      def unregister_callback(event, id)
        list = @callbacks[event.to_sym]
        return false unless list
        before = list.length
        list.reject! { |row| row[0] == id.to_sym }
        return list.length != before
      end

      # false when a handler said no (the rest don't run)
      def run_callbacks(event, ctx = {})
        Array(@callbacks[event.to_sym]).each do |cid, callable|
          begin
            return false if callable.call(ctx) == false
          rescue StandardError => e
            Reloaded::Log.exception("A PokeVial #{event} handler (#{cid}) failed", e, :pokevial)
          end
        end
        return true
      end

      #------------------------------------------------------------------------
      # The items, used from the Bag (UseFromBag: 0 not used, 3 used up)
      #------------------------------------------------------------------------
      def use_item(item)
        return 0 unless defined?(Reloaded::PokeVialScreen)
        s = Reloaded::PokeVialScreen
        unless on?
          s.toast(_INTL("The PokeVial is switched off."), :red_pill => _INTL("OFF"))
          return 0
        end
        if uses >= configured_max_uses
          s.toast(_INTL("The PokeVial is already full."), :full => true)
          return 0
        end
        if item == :POKEVIAL_REFILL
          refill!(:item)
          s.charges_toast(_INTL("The PokeVial was fully refilled."))
        else
          add_uses(1, source: :item, notify: false)
          s.charges_toast(_INTL("The PokeVial regained a charge."))
        end
        return 3
      end

      private

      def register_settings
        s = Reloaded::Settings
        s.register_page(PAGE, :group => :general, :name => "PokeVial", :icon => :features, :priority => 39,
          :feature => FEATURE,
          :description => "How the PokeVial heals, how many charges it holds, and refilling it at Pokémon Centers.")
        s.register(key(:progressive), :page => PAGE, :priority => 10, :type => :toggle, :default => true, :scope => :save,
          :name => "Progressive Uses",
          :description => "The PokeVial holds one more charge for every two Badges, up to five. Off: Max Uses decides.")
        s.register(key(:max_uses), :page => PAGE, :priority => 20, :type => :slider, :min => 1, :max => MAX_CAP,
          :default => DEFAULT_MAX, :scope => :save, :name => "Max Uses",
          :soft_lock => proc { progressive? ? _INTL("Set by Progressive Uses") : nil },
          :description => "How many charges the PokeVial holds while Progressive Uses is Off.")
        s.register(key(:heal_mode), :page => PAGE, :priority => 30, :type => :enum, :default => 0, :scope => :save,
          :values => ["Full Heal", "HP Only", "No Revive"], :name => "Heal Mode",
          :descriptions => ["HP, status and PP, and fainted Pokémon are revived.",
                            "HP Only: Status and PP stay as they are. Fainted Pokémon are revived.",
                            "HP, status and PP, but fainted Pokémon stay fainted (for Nuzlocke runs)."],
          :description => "What a charge heals.")
        s.register(key(:cooldown), :page => PAGE, :priority => 40, :type => :toggle, :default => false, :scope => :save,
          :name => "Cooldown",
          :description => "Real time has to pass between uses.")
        s.register(key(:cooldown_time), :page => PAGE, :priority => 50, :type => :enum, :default => 0, :scope => :save,
          :values => COOLDOWNS.map { |m| "#{m} min" }, :name => "Cooldown Time", :needs => key(:cooldown),
          :description => "How long to wait between uses, in real time.")
        s.register(key(:cooldown_wait), :page => PAGE, :priority => 60, :type => :enum, :default => 0,
          :values => ["In the Dialog", "Toast"], :name => "Cooldown Wait", :needs => key(:cooldown),
          :descriptions => ["The PokeVial opens as usual, its Use button counting down.",
                            "It doesn't open. A toast says how long until it's ready."],
          :description => "What choosing the PokeVial shows while it cools down.")
        s.register(key(:center_refill), :page => PAGE, :priority => 70, :type => :enum, :default => 0, :scope => :save,
          :values => ["Ask", "Automatic", "Never"], :name => "Pokémon Center Refill",
          :descriptions => ["After the nurse heals you, asks before refilling the PokeVial.",
                            "After the nurse heals you, the PokeVial refills by itself.",
                            "Pokémon Centers never refill it. Only items and other mods do."],
          :description => "Refilling the PokeVial at Pokémon Centers.")
        s.register(key(:refill_cost), :page => PAGE, :priority => 80, :type => :toggle, :default => false, :scope => :save,
          :name => "Refill Cost",
          :description => "Refilling at a Pokémon Center costs money for each missing charge.")
        s.register(key(:cost_per_charge), :page => PAGE, :priority => 90, :type => :number, :min => 0, :max => 5000,
          :step => 100, :default => 500, :scope => :save, :name => "Cost Per Charge", :needs => key(:refill_cost),
          :format => proc { |v| "$#{v}" },        # the game's fonts draw $ as the Pokédollar sign
          :description => "What each missing charge costs at a Pokémon Center.")
        s.register(key(:low_hp), :page => PAGE, :priority => 100, :type => :toggle, :default => true,
          :name => "Low HP Reminder",
          :description => "The PokeVial glows in the Pause Menu and Overworld Menu when a Pokémon has fainted or your party's HP is under half.")
      end

      def register_items
        return unless defined?(Reloaded::DataPatches) && Reloaded::DataPatches.respond_to?(:register_internal_patch)
        ITEMS.each do |id, d|
          Reloaded::DataPatches.register_internal_patch("items", id.to_s,
            d.merge("field_use" => 2, "battle_use" => 0, "type" => 0), owner: :pokevial)
        end
      end

      # The Pause Menu's Pinned slot (KIF's Heal Pokémon steps aside) and
      # the Overworld Menu's Main page
      def register_menu_entries
        if defined?(Reloaded::PauseMenu)
          Reloaded::PauseMenu.register(:pokevial, "PokeVial", :feature => FEATURE, :pinned => 2, :order => 20,
            :takes_over => :kif_heal, :icon => Reloaded::PauseMenu::ICON_DIR + "POKEVIAL", :small_icon => "menuIcons/POKEMON",
            :visible => proc { shown? },
            :condition => proc { shown? && usable == true },
            :lock_reason => proc { r = usable; r == true ? nil : r },
            :status => proc { [_INTL("Charges: {1}/{2}", uses, configured_max_uses), uses <= 0 ? :red : nil, "#{uses}/#{configured_max_uses}"] },
            :alert => proc { low_hp_alert? },
            :handler => proc { |_scene| Reloaded::PokeVialScreen.choose if defined?(Reloaded::PokeVialScreen); :stay })
        end
        if defined?(Reloaded::OverworldMenu)
          Reloaded::OverworldMenu.register(:pokevial, :name => "PokeVial", :kind => :action, :priority => 25, :feature => FEATURE,
            :condition => proc { shown? },
            :usable => proc { usable },
            :paint => proc { |b, x1, y, h, c, _room| Reloaded::PokeVialScreen.balls(b, c, x1, y + h / 2, uses, configured_max_uses) },
            :alert => proc { low_hp_alert? },
            :description => "Heal your party with a charge of the PokeVial.",
            :handler => proc { |menu| Reloaded::PokeVialScreen.choose if defined?(Reloaded::PokeVialScreen); menu.refresh rescue nil; nil })
        end
      end

      def install
        h = Reloaded::Hooks
        # the nurse's Recover All: the refill once the party is healed
        if defined?(::Interpreter)
          h.around(FEATURE, ::Interpreter, :command_314, :id => :pokevial_recover_all) do |original, *args|
            params = original.receiver.instance_variable_get(:@parameters)
            next original.call(*args) unless Array(params)[0].to_i == 0
            @center_depth += 1
            begin
              ret = original.call(*args)
            ensure
              @center_depth -= 1
            end
            center_refill if pokemon_center?
            ret
          end
        end
        # a nurse made with a script call (heal_party) instead
        if defined?(::Trainer)
          h.around(FEATURE, ::Trainer, :heal_party, :id => :pokevial_heal_party) do |original, *args|
            ret = original.call(*args)
            center_refill if @center_depth == 0 && !@healing && pokemon_center? && nurse_event?
            ret
          end
        end
        if defined?(::ItemHandlers) && ::ItemHandlers.const_defined?(:UseFromBag)
          ITEMS.each_key { |id| ::ItemHandlers::UseFromBag.add(id, proc { |item| Reloaded::PokeVial.use_item(item.is_a?(Symbol) ? item : id) }) }
        end
        if defined?(::Events) && ::Events.respond_to?(:onStepTaken)
          ::Events.onStepTaken += proc { |_sender, _e| Reloaded::PokeVial.sync_capacity if Reloaded::PokeVial.on? }
        end
        return true
      end

      # An event is running (the nurse), not the PokeVial or KIF's own Heal
      def nurse_event?
        i = respond_to?(:pbMapInterpreter, true) ? pbMapInterpreter : ($game_system && $game_system.map_interpreter)
        return i && i.running? ? true : false
      rescue StandardError
        return false
      end
    end
  end
end
