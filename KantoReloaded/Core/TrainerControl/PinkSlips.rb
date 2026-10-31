# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Trainer Control's Pink Slips
#==============================================================================
# His picks (Roadmap Designs topic trainer-control, 2026-10-30):
#
#   The item     a Pink Slip: a possible class gift (bond steps) and rare,
#                pricey stock at the Celadon Department Store's battle items
#                counter ($10,000)
#   The question when a regular trainer challenges you one on one (not a
#                leader, the Elite Four, a Champion, your rival, a Rocket
#                boss, or a team an event builds) and you hold one: "Use a
#                Pink Slip?" (Wager / Just Battle), then Choose Your Stake,
#                then the battle. Never when your party and PC are both full,
#                or with nothing you could stake.
#   The stake    a party Pokémon that can battle, within 10 levels of your
#                highest (no Eggs, no fainted ones)
#   All or       win: claim any one of theirs as it fought you (moves, nature,
#   nothing      ability; its held item stays with them), owned like a trade
#                (they stay its trainer), into your party or the PC; KIF's
#                Nuzlocke counts it as a gift. Lose: yours goes with them for
#                good, its held item back to your Bag, said when you wake in
#                the Pokémon Center. Once per trainer, ever.
#   The row      Pink Slips (On to start): Off, none drop or are offered
#
# The screens (Design 1's popups, Design 3's Choose Your Stake: his mix)
# are UI/PinkSlipScreens.rb.
#==============================================================================

module Reloaded
  module TrainerControl
    module PinkSlips
      ITEM = :PINKSLIP
      ROW = :"trainer_control.pink_slips"
      PRICE = 10_000
      SHOP_MAP = 433                      # the Celadon Department Store's floor with the vitamins and battle items
      SHOP_WITH = :XATTACK                # (the battle items' counter)
      STAKE_RANGE = 10

      @wager = nil
      @due = nil

      class << self
        attr_reader :wager, :due

        def install
          register_item
          if defined?(Reloaded::Settings)
            Reloaded::Settings.register(ROW, :page => TrainerControl::PAGE, :priority => 20, :type => :toggle, :default => true, :scope => :save,
              :name => "Pink Slips", :description => "Wager a Pokémon against a trainer's with a Pink Slip: Win and claim one of theirs, lose and they keep yours. Off: None drop or are offered.")
          end
          Reloaded::Events.on(:trainer_battle_ended, :trainer_control_pink_slips, 107) { |c| battle_ended(c) }
          h = Reloaded::Hooks
          if Object.private_method_defined?(:pbPokemonMart) || Object.method_defined?(:pbPokemonMart)
            h.around(nil, Object, :pbPokemonMart, :id => :trainer_control_pink_shop) do |original, *args|
              stock = args[0]
              if Reloaded::TrainerControl::PinkSlips.sells_here?(stock)
                args = args.dup
                args[0] = stock + [Reloaded::TrainerControl::PinkSlips::ITEM]
              end
              original.call(*args)
            end
          end
          h.prepend(nil, ::Scene_Map, MapWatch, :id => :trainer_control_pink_notice) if defined?(::Scene_Map)
        end

        # Kanto Reloaded's own item (an internal Data Patch), its icon in
        # Graphics/Items; nothing reads the game's data at boot
        def register_item
          return unless defined?(Reloaded::DataPatches) && Reloaded::DataPatches.respond_to?(:register_internal_patch)
          Reloaded::DataPatches.register_internal_patch("items", ITEM.to_s,
            { "name" => "Pink Slip", "name_plural" => "Pink Slips", "pocket" => 1, "price" => PRICE,
              "description" => "A wager: When a trainer challenges you, stake one of your Pokémon. Win and claim one of theirs; lose and they keep yours.",
              "field_use" => 0, "battle_use" => 0, "type" => 0 }, owner: :trainer_control)
        end

        def on?
          return Reloaded::Settings.get(ROW) != false
        end

        def holds?
          return ($PokemonBag.pbHasItem?(ITEM) rescue false) ? true : false
        end

        def sells_here?(stock)
          return false unless on? && stock.is_a?(Array) && $game_map && $game_map.map_id == SHOP_MAP
          return stock.include?(SHOP_WITH) && !stock.include?(ITEM)
        end

        # A possible gift (bond steps: the class gift and the later ones)
        def gift_items(_rec, _at)
          return on? ? [ITEM] : []
        end

        # The toast's PINK SLIP pill: you hold one and they'd take it
        def offered?(rec)
          return on? && holds? && rec["kind"] == "trainer" && !rec["pink"].is_a?(Hash)
        end

        #----------------------------------------------------------------------
        # The stake
        #----------------------------------------------------------------------
        def party
          return ($Trainer ? $Trainer.party : []).compact
        end

        def highest
          return party.reject(&:egg?).map { |p| p.level.to_i }.max || 0
        end

        # Why one can't be staked: [words, tone], or nil when it can
        def stake_reason(pk)
          return [_INTL("CAN'T BATTLE"), :grey] if pk.egg?
          return [_INTL("FAINTED"), :red] if pk.hp.to_i <= 0
          low = highest - STAKE_RANGE
          return [_INTL("BELOW LV. {1}", low), :amber] if pk.level.to_i < low
          return nil
        end

        def stakes
          return party.each_index.select { |i| stake_reason(party[i]).nil? }
        end

        def room?
          full = ($Trainer.party_full? rescue party.length >= 6)
          return !full || !(pbBoxesFull? rescue true)
        end

        #----------------------------------------------------------------------
        # Before the battle: the question, the stake
        #----------------------------------------------------------------------
        # A data trainer, alone, of a regular class, who's never had one
        def wagerable?(args)
          return false unless args.length == 1 && args[0].is_a?(Array)
          type, name, _version = args[0]
          return false unless TrainerControl.kind(type) == :trainer
          rec = Records.get(TrainerControl.person_key(type, name))
          return !(rec && rec["pink"].is_a?(Hash))
        end

        def before_battle(args)
          @wager = nil
          return unless on? && holds? && Records.data && LevelScaling.scaled? && wagerable?(args)
          return unless room? && !stakes.empty?
          type, name, version = args[0]
          key = TrainerControl.person_key(type, name)
          title = "#{Records.class_name(type)} #{name}"
          words = _INTL("Use a Pink Slip? Win: Claim one of {1}'s. Lose: {1} keeps yours.", name)
          choice = pbMessage(words, [_INTL("Wager"), _INTL("Just Battle")], 2)
          return unless choice == 0
          stake = defined?(Reloaded::PinkSlipStake) ? Reloaded::PinkSlipStake.new(title, name, their_team(type, name, version)).run : stakes.first
          return unless stake
          pk = party[stake]
          $PokemonBag.pbDeleteItem(ITEM)
          @wager = { "key" => key, "name" => name, "title" => title, "pid" => pk.personalID, "type" => type.to_s }
          Reloaded::Log.info("Trainer Control: a Pink Slip wager with #{title}: #{pk.name} staked", :trainer_control)
        rescue StandardError => e
          Reloaded::Log.exception("Trainer Control's Pink Slip question failed", e, :trainer_control)
          @wager = nil
        end

        # Their team as you'll see it: as they last fought you, else their data's
        def their_team(type, name, version)
          rec = Records.get(TrainerControl.person_key(type, name))
          return Array(rec["team"]).map { |sp, lv| [sp.to_s, lv.to_i] } if rec && !Array(rec["team"]).empty?
          data = (::GameData::Trainer.try_get(type, name, version) rescue nil)
          return data ? data.pokemon.map { |d| [d[:species].to_s, d[:level].to_i] } : []
        end

        #----------------------------------------------------------------------
        # The battle's end, then back on the map
        #----------------------------------------------------------------------
        def battle_ended(context)
          w = @wager
          return unless w
          battle = context[:battle]
          tr = Array(battle.opponent).find { |t| TrainerControl.person(t) == w["key"] }
          return unless tr
          case context[:won]
          when true then w["team"] = Marshal.load(Marshal.dump(Array(tr.party).compact))
          when false then w["lost"] = true
          else w["void"] = true
          end
        rescue StandardError => e
          Reloaded::Log.exception("Trainer Control couldn't settle a Pink Slip", e, :trainer_control)
        end

        def after_battle
          w = @wager
          @wager = nil
          return unless w
          if w["team"] then claim(w)
          elsif w["lost"] then lose(w)
          else $PokemonBag.pbStoreItem(ITEM)                  # no winner: the slip comes back
          end
        rescue StandardError => e
          Reloaded::Log.exception("Trainer Control couldn't finish a Pink Slip", e, :trainer_control)
        end

        # Win: any one of theirs, as it fought you, its item left with them
        def claim(w)
          team = w["team"]
          i = defined?(Reloaded::PinkSlipClaim) ? Reloaded::PinkSlipClaim.new(w["title"], w["name"], team).run : 0
          prize = team[i.to_i] || team.first
          return unless prize
          prize.item = nil
          prize.heal if prize.respond_to?(:heal)
          prize.obtain_method = 2 if prize.respond_to?(:obtain_method=)          # like a trade: they stay its trainer
          prize.obtain_map = $game_map.map_id if prize.respond_to?(:obtain_map=) && $game_map
          boxed = ($Trainer.party_full? rescue false)
          pbAddPokemonSilent(prize)
          ::KIF::Nuzlocke.gift_received(prize, true) if defined?(::KIF::Nuzlocke) && ::KIF::Nuzlocke.respond_to?(:gift_received)
          rec = Records.get(w["key"])
          rec["pink"] = { "won" => true, "species" => prize.species.to_s, "level" => prize.level.to_i } if rec
          where = boxed ? box_words : _INTL("It joined your party.")
          Reloaded::PinkSlipNotice.claimed(prize, where) if defined?(Reloaded::PinkSlipNotice)
        end

        def box_words
          box = ($PokemonStorage.currentBox rescue nil)
          return _INTL("Sent to the PC: The party is full.") unless box
          return _INTL("Sent to {1}: The party is full.", ($PokemonStorage[box].name rescue "the PC"))
        end

        # Lose: yours goes with them, its item back to your Bag; said once
        # you're on the map again (the Pokémon Center after a whiteout)
        def lose(w)
          idx = ($Trainer.party.index { |p| p && p.personalID == w["pid"] } rescue nil)
          return unless idx
          pk = $Trainer.party.delete_at(idx)
          item = pk.item_id rescue nil
          $PokemonBag.pbStoreItem(item) if item
          rec = Records.get(w["key"])
          rec["pink"] = { "won" => false, "species" => pk.species.to_s, "level" => pk.level.to_i } if rec
          @due = { "name" => w["name"], "species" => pk.species.to_s, "pokemon" => pk.name.to_s, "item" => item ? item.to_s : nil }
          Reloaded::Log.info("Trainer Control: #{w["title"]} took #{pk.name} (a Pink Slip)", :trainer_control)
        end

        # Each map frame while a notice is due: shown once the map is quiet
        def map_frame
          return unless @due
          return if ($game_temp.player_transferring rescue false) || ($game_temp.message_window_showing rescue false)
          return if (pbMapInterpreterRunning? rescue false)
          d = @due
          @due = nil
          Reloaded::PinkSlipNotice.lost(d) if defined?(Reloaded::PinkSlipNotice)
        end
      end

      module MapWatch
        def update(*args)
          ret = super
          Reloaded::TrainerControl::PinkSlips.map_frame if Reloaded::TrainerControl::PinkSlips.due
          ret
        end
      end
    end
  end
end
