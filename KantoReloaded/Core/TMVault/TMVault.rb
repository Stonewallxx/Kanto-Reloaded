# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the TM Vault
#==============================================================================
# Roadmap topic tm-vault (decided 2026-10-17; the Next feature discussion
# and design picks 2026-10-23). Every TM, HM and tutor move you've had,
# taught again for free, any time. It takes over KIF's Tutor.net
# (F-POKE-05_TutorNet) and brings in what Tutor.net had unlocked
# ($Trainer.tutorlist). Old Kanto Reloaded's TM Vault (its structure) with
# Hoenn Reloaded's screen, in Reloaded's plate look (UI/TMVaultScreen.rb).
#
#   moves      a TM or HM reaching the Bag (an item ball, a gift, a shop:
#              PokemonBag#pbStoreItem), a move tutor teaching (pbMoveTutorChoose),
#              Tutor.net's own pbTutorNetAdd, and the Bag at load; a toast
#              says so, and the move is NEW until the Vault has been opened
#   Vault      search, sort (Name, Type, Category, Recent, Level Learned),
#              Type Filter, Favorites at the top, who in the party knows it,
#              can learn it or can't, Coverage
#   Relearn    KIF's own Change Moves list (its Egg Moves and Event Moves
#              options decide), opened from the party menu's Relearn Moves too
#   Checklist  the TMs and HMs you haven't had, each with the kind of place
#              the game gives it (Ground, Store, Gift: read from the game's
#              maps once per KIF version), and a note with the Randomizer on
#   teaching   free; with four moves, Move Compare picks the one to forget
#
# The moves, favorites and what's been seen are kept by the save
# (SaveStore section "tm_vault").
#
#   Reloaded::TMVault.register(:THUNDERBOLT, source: :script)
#   Reloaded::TMVault.moves / known?(:THUNDERBOLT) / open
#==============================================================================

module Reloaded
  module TMVault
    FEATURE = :tm_vault
    SECTION = :tm_vault
    ICON = "Graphics/PauseMenu/TMVAULT"
    SORTS = ["Name", "Type", "Category", "Recent", "Level Learned"].freeze
    KINDS = [:store, :gift, :ground].freeze          # the first found wins: the easiest way to get it
    KINDS_FILE = "TM Vault Kinds.json"
    # in the maps' events, the call nearest before a machine's id: an item
    # ball, a gift, a shop's list or its price
    KIND_WORDS = { "ItemBall" => :ground, "ReceiveItem" => :gift, "Mart" => :store, "setPrice" => :store }.freeze

    class << self
      def boot
        Reloaded::Features.register(FEATURE, :name => "TM Vault", :order => 28, :takes_over => ["F-POKE-05_TutorNet"],
          :description => "Every TM, HM and tutor move you've had, taught again for free, with Relearn and a Checklist. Off brings back KIF's Tutor.net.")
        Reloaded::SaveStore.register(SECTION)
        Reloaded::Events.on(:save_loaded, :tm_vault_sync, 70) { sync!(true) }
        Reloaded::Events.on(:new_game, :tm_vault_sync, 70) { sync!(true) }
        register_menu_entries
        install
        return true
      end

      def on?
        return Reloaded::Features.on?(FEATURE)
      end

      #------------------------------------------------------------------------
      # The moves
      #------------------------------------------------------------------------
      def data
        return Reloaded::SaveStore.section(SECTION)
      rescue StandardError
        return nil
      end

      # Every move in the Vault (move ids), in the order they came
      def moves
        d = data
        return [] unless d
        return Array(d["moves"]).map { |m| move_id(m) }.compact.uniq
      end

      def known?(move)
        id = move_id(move)
        return id ? moves.include?(id) : false
      end

      # Adds a move. Returns true when it's new. source: :tm, :tutor,
      # :tutor_net, :bag, :script (another mod); notify shows the toast.
      def register(move, source: :script, notify: false)
        id = move_id(move)
        d = data
        return false unless id && d
        list = Array(d["moves"]).map(&:to_s)
        return false if list.include?(id.to_s)
        d["moves"] = list + [id.to_s]
        d["counter"] = d["counter"].to_i + 1
        (d["added"] ||= {})[id.to_s] = d["counter"]
        (d["sources"] ||= {})[id.to_s] = source.to_s
        Reloaded::Events.emit(:tm_vault_registered, :move => id, :source => source)
        toast(id) if notify && on?
        return true
      rescue StandardError => e
        Reloaded::Log.exception("The TM Vault couldn't add #{move}", e, :tm_vault)
        return false
      end

      # Added since you last opened the Vault
      def new?(move)
        d = data
        return false unless d
        return !Array(d["seen"]).include?(move.to_s)
      end

      # Opening the Vault: everything in it has been seen
      def seen!
        d = data
        d["seen"] = Array(d["moves"]).map(&:to_s) if d
      end

      def favorite?(move)
        d = data
        return d ? Array(d["favorites"]).include?(move.to_s) : false
      end

      def toggle_favorite(move)
        d = data
        return false unless d
        favs = Array(d["favorites"]).map(&:to_s)
        key = move.to_s
        d["favorites"] = favs.include?(key) ? favs - [key] : favs + [key]
        return favorite?(move)
      end

      def sort
        d = data
        return d ? d["sort"].to_i.clamp(0, SORTS.length - 1) : 0
      end

      def sort=(i)
        d = data
        d["sort"] = i.to_i % SORTS.length if d
      end

      # When it came (bigger: later)
      def added_at(move)
        d = data
        return d ? (d["added"] || {})[move.to_s].to_i : 0
      end

      # Tutor.net's unlocks and the Bag's machines: once a save loads (first
      # time: everything already there counts as seen, so nothing is NEW)
      def sync!(quiet = false)
        d = data
        return 0 unless d
        first = !d["imported"]
        added = 0
        if $Trainer && $Trainer.respond_to?(:tutorlist) && $Trainer.tutorlist.is_a?(Array)
          $Trainer.tutorlist.each { |e| added += 1 if register(e.is_a?(Array) ? e[0] : e, source: :tutor_net) }
        end
        bag_machines.each { |m| added += 1 if register(m, source: :bag) }
        d["imported"] = true
        seen! if first
        return added
      rescue StandardError => e
        Reloaded::Log.exception("The TM Vault couldn't read Tutor.net and the Bag", e, :tm_vault)
        return 0
      end

      def bag_machines
        out = []
        pockets = $PokemonBag && $PokemonBag.respond_to?(:pockets) ? $PokemonBag.pockets : nil
        Array(pockets).each do |pocket|
          Array(pocket).each do |slot|
            item = machine(slot.is_a?(Array) ? slot[0] : slot)
            out << item.move if item
          end
        end
        return out.uniq
      end

      #------------------------------------------------------------------------
      # A Pokémon and a move
      #------------------------------------------------------------------------
      # :knows, :learn or :cant (an Egg can't)
      def compat(move, pkmn)
        return :cant if pkmn.nil? || pkmn.egg?
        return :knows if pkmn.hasMove?(move)
        return pkmn.compatible_with_move?(move) ? :learn : :cant
      rescue StandardError
        return :cant
      end

      # What it can relearn: KIF's own Change Moves list (KIF's Egg Moves and
      # Event Moves options decide), so the two always agree
      def relearnable(pkmn)
        return [] if pkmn.nil? || pkmn.egg?
        list = if defined?(::KIF::MoveLearning) && ::KIF::MoveLearning.respond_to?(:change_moves_list)
                 ::KIF::MoveLearning.change_moves_list(pkmn)
               elsif defined?(::MoveRelearnerScreen)
                 ::MoveRelearnerScreen.new(nil).pbGetRelearnableMoves(pkmn)
               else
                 []
               end
        return Array(list).map { |m| move_id(m) }.compact.uniq.reject { |m| pkmn.hasMove?(m) }
      rescue StandardError => e
        Reloaded::Log.exception("The TM Vault couldn't read #{pkmn.name}'s moves to relearn", e, :tm_vault)
        return []
      end

      def egg_move?(pkmn, move)
        return false unless pkmn && defined?(::KIF::MoveLearning) && ::KIF::MoveLearning.respond_to?(:egg_moves_for)
        return Array(::KIF::MoveLearning.egg_moves_for(pkmn)).map { |m| move_id(m) }.include?(move_id(move))
      rescue StandardError
        return false
      end

      # The level it learns the move at (its level-up list first; 0: from
      # the start or an egg move), or nil
      def level_learned(pkmn, move)
        return nil unless pkmn
        id = move_id(move)
        list = pkmn.respond_to?(:getMoveRelearnerList) ? pkmn.getMoveRelearnerList : pkmn.getMoveList
        levels = Array(list).select { |e| e.is_a?(Array) && move_id(e[1]) == id }.map { |e| e[0].to_i }
        return levels.min unless levels.empty?
        return 0 if egg_move?(pkmn, id) || Array(pkmn.first_moves).map { |m| move_id(m) }.include?(id)
        return nil
      rescue StandardError
        return nil
      end

      # The types a Pokémon's damaging moves hit for super effective damage:
      # [now, with move (forgetting the one at forget, when given)]
      def coverage(pkmn, move = nil, forget = nil)
        ids = Array(pkmn ? pkmn.moves : []).map(&:id)
        now = hits(ids)
        return [now, now] unless move
        after = ids.dup
        forget ? after[forget] = move_id(move) : after << move_id(move)
        return [now, hits(after)]
      end

      def hits(move_ids)
        out = []
        attack = move_ids.map { |m| ::GameData::Move.try_get(m) }.compact.select { |m| m.base_damage.to_i > 0 }.map(&:type).uniq
        ::GameData::Type.each do |t|
          next if t.respond_to?(:pseudo_type) && t.pseudo_type
          out << t.id if attack.any? { |a| t.effectiveness(a) == ::Effectiveness::SUPER_EFFECTIVE_ONE }
        end
        return out
      rescue StandardError
        return []
      end

      # Teaches it, free. forget: the move it gives up (with four already);
      # the move keeps that one's place. Returns true when it learned it.
      def teach(pkmn, move, forget = nil)
        id = move_id(move)
        return false if pkmn.nil? || pkmn.egg? || id.nil? || pkmn.hasMove?(id)
        if pkmn.moves.length < ::Pokemon::MAX_MOVES
          pkmn.learn_move(id)
        else
          return false if forget.nil?
          pkmn.forget_move_at_index(forget)
          pkmn.learn_move(id)
          pkmn.moves.insert(forget, pkmn.moves.pop)
        end
        Reloaded::Events.emit(:tm_vault_taught, :pokemon => pkmn, :move => id)
        return true
      rescue StandardError => e
        Reloaded::Log.exception("The TM Vault couldn't teach #{move}", e, :tm_vault)
        return false
      end

      #------------------------------------------------------------------------
      # The Checklist
      #------------------------------------------------------------------------
      # [[item, move, kind or nil], ...]: the machines not in the Vault, in
      # the game's order
      def checklist
        have = moves
        out = []
        ::GameData::Item.each do |item|
          next unless item.is_machine? && item.move
          next if have.include?(item.move)
          out << [item, item.move, kinds[item.id.to_s]]
        end
        return out
      rescue StandardError => e
        Reloaded::Log.exception("The TM Vault couldn't list the Checklist", e, :tm_vault)
        return []
      end

      # With the Randomizer's items or TMs on, a TM may be somewhere else
      def randomized?
        sw = $game_switches
        return false unless sw
        return [:SWITCH_RANDOM_ITEMS_GENERAL, :SWITCH_RANDOM_TMS].any? { |c| Object.const_defined?(c) && sw[Object.const_get(c)] }
      rescue StandardError
        return false
      end

      # item id => :store, :gift or :ground: read from the game's maps (the
      # events that give machines), kept for this KIF version
      def kinds
        return @kinds if @kinds
        version = defined?(::KIF::PORT_VERSION) ? ::KIF::PORT_VERSION.to_s : "?"
        path = File.join(Reloaded::Paths.settings_dir, KINDS_FILE)
        text = Reloaded::Paths.read_text(path)
        if text && !text.strip.empty?
          saved = Reloaded::JSON.parse(text) rescue nil
          if saved.is_a?(Hash) && saved["kif"] == version && saved["kinds"].is_a?(Hash)
            return @kinds = saved["kinds"].map { |k, v| [k, v.to_sym] }.to_h
          end
        end
        @kinds = scan_maps
        Reloaded::Paths.write_atomic(path, Reloaded::JSON.generate({ "kif" => version, "kinds" => @kinds.map { |k, v| [k, v.to_s] }.to_h }, true))
        return @kinds
      rescue StandardError => e
        Reloaded::Log.exception("The TM Vault couldn't read the maps for the Checklist", e, :tm_vault)
        return @kinds = {}
      end

      def scan_maps(dir = "Data")
        found = {}
        Dir.glob(File.join(dir, "Map[0-9]*.rxdata")).sort.each do |file|
          bytes = File.binread(file)
          bytes.force_encoding("BINARY")
          bytes.scan(/(?:PBItems::|:)([TH]M\d{2,3})\b/n) do
            id = Regexp.last_match(1)
            from = [Regexp.last_match.begin(0) - 400, 0].max
            before = bytes[from...Regexp.last_match.begin(0)]
            at = KIND_WORDS.map { |w, kind| [before.rindex(w), kind] }.select { |i, _k| i }.max_by { |i, _k| i }
            next unless at
            k = at[1]
            old = found[id]
            found[id] = k if old.nil? || KINDS.index(k) < KINDS.index(old)
          end
        end
        return found
      end

      #------------------------------------------------------------------------
      # Opening it
      #------------------------------------------------------------------------
      # tab: :vault, :relearn or :checklist; pkmn: whose moves (Relearn);
      # focus: a move to start on (the Bag's Teach)
      def open(tab: :vault, pkmn: nil, focus: nil)
        return false unless defined?(Reloaded::TMVaultScreen)
        sync!
        Reloaded::TMVaultScreen.open(tab, pkmn, focus)
        return true
      rescue StandardError => e
        Reloaded::Log.exception("The TM Vault couldn't open", e, :tm_vault)
        return false
      end

      def move_id(move)
        return nil if move.nil?
        m = ::GameData::Move.try_get(move.is_a?(String) ? move.to_sym : move)
        return m ? m.id : nil
      rescue StandardError
        return nil
      end

      def machine(item)
        data = ::GameData::Item.try_get(item)
        return data && data.is_machine? && data.move ? data : nil
      rescue StandardError
        return nil
      end

      # A machine's name for a move ("TM24"), or "Tutor"
      def label(move)
        @labels ||= begin
          h = {}
          ::GameData::Item.each { |it| h[it.move] ||= it.id.to_s if it.is_machine? && it.move }
          h
        end
        return @labels[move_id(move)] || _INTL("Tutor")
      rescue StandardError
        return ""
      end

      # The machine's disc for a move, in its type (an HM's own disc when
      # the game has one for that type)
      def disc_icon(move)
        type = ::GameData::Move.get(move_id(move)).type
        plain = "Graphics/Items/machine_#{type}"
        return plain unless label(move).start_with?("HM")
        hm = "Graphics/Items/machine_hm_#{type}"
        found = (defined?(pbResolveBitmap) && pbResolveBitmap(hm)) || File.file?(hm + ".png")
        return found ? hm : plain
      rescue StandardError
        return "Graphics/Items/machine_NORMAL"
      end

      private

      def toast(id)
        return unless defined?(Reloaded::Toast)
        mv = ::GameData::Move.get(id)
        Reloaded::Toast.show(_INTL("Added to TM Vault: {1}", mv.name), :icon => disc_icon(id),
                             :pill => [_INTL("NEW"), :green])
      rescue StandardError => e
        Reloaded::Log.exception("The TM Vault's toast couldn't show", e, :tm_vault)
      end

      def register_menu_entries
        if defined?(Reloaded::PauseMenu)
          Reloaded::PauseMenu.register(:tm_vault, "TM Vault", :feature => FEATURE, :pinned => 1, :order => 22,
            :takes_over => :kif_tutornet, :icon => ICON, :small_icon => "menuIcons/POKENAV",
            :condition => proc { usable == true },
            :lock_reason => proc { r = usable; r == true ? nil : r },
            :status => proc { [_INTL("Moves: {1}", moves.length), nil, moves.length.to_s] },
            :handler => proc { |_scene| open; :stay })
        end
        if defined?(Reloaded::OverworldMenu)
          Reloaded::OverworldMenu.register(:tm_vault, :name => "TM Vault", :kind => :action, :priority => 27, :feature => FEATURE,
            :usable => proc { usable },
            :description => "Every TM, HM and tutor move you've had, taught again for free.",
            :handler => proc { |menu| open; menu.refresh rescue nil; nil })
        end
      end

      # Where KIF's Tutor.net couldn't be opened either
      def usable
        return _INTL("You can't use that in the Bug Contest.") if respond_to?(:pbInBugContest?, true) && pbInBugContest?
        if defined?(::KIF::PauseMenu) && ::KIF::PauseMenu.respond_to?(:restricted?) && defined?(::KIF::PauseMenu::SHOP_RESTRICTED_MAPS) &&
           ::KIF::PauseMenu.restricted?(::KIF::PauseMenu::SHOP_RESTRICTED_MAPS)
          return _INTL("You can't use that here.")
        end
        return true
      rescue StandardError
        return true
      end

      def install
        h = Reloaded::Hooks
        # a machine reaching the Bag: an item ball, a gift, a shop
        if defined?(::PokemonBag) && ::PokemonBag.method_defined?(:pbStoreItem)
          h.around(FEATURE, ::PokemonBag, :pbStoreItem, :id => :tm_vault_bag) do |original, item, *rest|
            ret = original.call(item, *rest)
            m = ret ? machine(item) : nil
            register(m.move, source: :tm, notify: true) if m
            ret
          end
        end
        # a move tutor teaching
        if Object.private_method_defined?(:pbMoveTutorChoose) || Object.method_defined?(:pbMoveTutorChoose)
          h.around(FEATURE, Object, :pbMoveTutorChoose, :id => :tm_vault_tutor) do |original, move, *rest|
            ret = original.call(move, *rest)
            register(move, source: :tutor, notify: true) if ret
            ret
          end
        end
        # Tutor.net's own (other mods and events call it)
        if Object.private_method_defined?(:pbTutorNetAdd) || Object.method_defined?(:pbTutorNetAdd)
          h.around(FEATURE, Object, :pbTutorNetAdd, :id => :tm_vault_tutor_net) do |original, move, *rest|
            ret = original.call(move, *rest)
            register(move, source: :tutor_net, notify: true)
            ret
          end
        end
        # the party menu's Relearn Moves: the TM Vault's Relearn on it
        if defined?(::PokemonPartyScreen) && ::PokemonPartyScreen.method_defined?(:pbRememberMoves)
          h.around(FEATURE, ::PokemonPartyScreen, :pbRememberMoves, :id => :tm_vault_relearn) do |original, pkmn, *rest|
            next original.call(pkmn, *rest) unless defined?(Reloaded::TMVaultScreen)
            open(tab: :relearn, pkmn: pkmn)
          end
        end
      end
    end
  end
end
