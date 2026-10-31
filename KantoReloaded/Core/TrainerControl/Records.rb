# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Trainer Control's records
#==============================================================================
# One record per person (his picks), in the save's "trainer_control" section,
# plain values only:
#
#   "people" => { key => {
#      "type", "name", "shown" (the name shown: your rival's own), "kind",
#      "wins", "losses", "streak", "best",
#      "first" { "map", "time" }, "last" { "map", "time", "won" },
#      "team" [[species, level], ...] (their team in the last battle),
#      "versions" [...], "rematches" (battles PIF ran as a rematch),
#      "mvp" { "you" => { personal ID => { "species", "name", "kos" } },
#              "them" => { species => kos } },
#      "before" (PIF's rematch count from before records), "legacy" true,
#      "rematchable" true (their event offers rematches),
#      "steps" (claimed bond steps: Bond.rb),
#      "pink" { "won", "species", "level" } (their Pink Slip) } }
#
# No resets (his pick): records are the save's history. Started once per
# save: Kanto Reloaded Legacy's records brought in, merged by person (its
# rival's versions become one), and PIF's own rematch counts kept as
# "before" ("Rematched 5 Times Before Records"; no wins or losses made up).
#
#   Records.get(key)  Records.people  Records.mvp(record)
#   Records.list(filter, query, sort)  the Battle Records screen's rows
#==============================================================================

module Reloaded
  module TrainerControl
    module Records
      LEGACY_RUNTIME = /\A7:runtime\|/      # Legacy's keys for mods' runtime trainers (left out)
      FILTERS = [:all, :rivalries, :leaders, :pink_slips].freeze
      FILTER_WORDS = ["All", "Rivalries", "Leaders", "Pink Slips"].freeze
      SORTS = ["Recent", "Name", "Battles", "Win Rate", "Best Streak", "Place", "Next Step"].freeze

      class << self
        def boot
          Reloaded::Events.on(:save_loaded, :trainer_control_records, 61) { |c| started(c) }
          return true
        end

        def data
          return Reloaded::SaveStore.section(SECTION)
        end

        def people
          d = data
          return {} unless d
          return (d["people"] ||= {})
        end

        def get(key)
          return people[key.to_s]
        end

        # The person's record, made at your first battle with them
        def record_for(key, type, name, shown)
          rec = (people[key] ||= { "type" => type.to_s, "name" => name.to_s, "kind" => TrainerControl.kind(type).to_s,
                                   "wins" => 0, "losses" => 0, "streak" => 0, "best" => 0 })
          rec["shown"] = shown.to_s unless shown.to_s.empty?
          return rec
        end

        #----------------------------------------------------------------------
        # A battle's end (counted battles only: TrainerControl.battle_ended)
        #----------------------------------------------------------------------
        def battle_ended(battle, won)
          return [] unless data
          now = Time.now
          map = $game_map ? $game_map.map_id.to_i : 0
          rematch = ($game_switches[TrainerControl::REMATCH_SWITCH] rescue false) ? true : false
          again = rematch || TrainerControl.rematch_event?
          kos = battle.instance_variable_get(:@kr_tc_kos) || {}
          keys = []
          Array(battle.opponent).each_with_index do |tr, i|
            tag = tr ? (tr.instance_variable_get(TrainerControl::TAG) rescue nil) : nil
            next unless tag
            key = TrainerControl.person_key(tag["type"], tag["name"])
            next if key.nil? || keys.include?(key)
            rec = record_for(key, tag["type"], tag["name"], (tr.name rescue nil))
            if won
              rec["wins"] = rec["wins"].to_i + 1
              rec["streak"] = rec["streak"].to_i + 1
              rec["best"] = [rec["best"].to_i, rec["streak"]].max
            else
              rec["losses"] = rec["losses"].to_i + 1
              rec["streak"] = 0
            end
            rec["first"] ||= { "map" => map, "time" => now }
            rec["last"] = { "map" => map, "time" => now, "won" => won }
            rec["team"] = Array(tr.party).compact.map { |pk| [pk.species.to_s, pk.level.to_i] }
            versions = (rec["versions"] ||= [])
            versions << tag["version"] unless versions.include?(tag["version"])
            rec["rematches"] = rec["rematches"].to_i + 1 if rematch
            rec["rematchable"] = true if again
            add_kos(rec, kos[i])
            keys << key
          end
          return keys
        end

        #----------------------------------------------------------------------
        # MVPs: who knocked out whom (TrainerControl::FaintWatch), kept on the
        # battle by the fainted or attacking foe's trainer, added to their
        # record when the battle counts
        #----------------------------------------------------------------------
        def fainted(b)
          battle = b.battle
          return unless (battle.trainerBattle? rescue false)
          idx = Array(b.lastFoeAttacker).last
          foe = idx ? battle.battlers[idx] : nil
          return unless foe && foe.pokemon && b.pokemon
          tallies = battle.instance_variable_get(:@kr_tc_kos) || battle.instance_variable_set(:@kr_tc_kos, {})
          if b.opposes?
            return unless foe.pbOwnedByPlayer?          # yours (not a partner's) knocked out theirs
            t = (tallies[battle.pbGetOwnerIndexFromBattlerIndex(b.index)] ||= { "you" => {}, "them" => {} })
            pk = foe.pokemon
            e = (t["you"][pk.personalID.to_s] ||= { "species" => pk.species.to_s, "name" => pk.name.to_s, "kos" => 0 })
            e["kos"] += 1
          else
            return unless b.pbOwnedByPlayer?            # theirs knocked out yours
            t = (tallies[battle.pbGetOwnerIndexFromBattlerIndex(idx)] ||= { "you" => {}, "them" => {} })
            sp = foe.pokemon.species.to_s
            t["them"][sp] = t["them"][sp].to_i + 1
          end
        rescue StandardError => e
          Reloaded::Log.warning_once("Trainer Control couldn't count a knockout: #{e.message}", :trainer_control)
        end

        def add_kos(rec, t)
          return unless t
          mvp = (rec["mvp"] ||= { "you" => {}, "them" => {} })
          t["you"].each do |pid, e|
            m = (mvp["you"][pid] ||= { "kos" => 0 })
            m["species"] = e["species"]                 # (its latest: an evolution shows)
            m["name"] = e["name"]
            m["kos"] = m["kos"].to_i + e["kos"].to_i
          end
          t["them"].each { |sp, n| mvp["them"][sp] = mvp["them"][sp].to_i + n.to_i }
        end

        # The MVPs: [your Pokémon's { "pid", "species", "name", "kos" } or
        # nil, [their species, kos] or nil] (the most knockouts; ties: the
        # first)
        def mvp(rec)
          m = rec && rec["mvp"]
          return [nil, nil] unless m
          pid, you = m["you"].max_by { |_pid, e| e["kos"].to_i }
          them = m["them"].max_by { |_sp, n| n.to_i }
          return [you ? you.merge("pid" => pid) : nil, them]
        end

        #----------------------------------------------------------------------
        # What a record says (the Battle Records screen, the toast)
        #----------------------------------------------------------------------
        # Someone you can battle again: their event offers rematches (or one
        # was run), PIF counted rematches before records, or a Gym Leader
        # (the Fighting Arena)
        def rematchable?(rec)
          return false unless rec
          return true if rec["rematchable"] || rec["rematches"].to_i > 0 || rec["before"].to_i > 0
          return rec["type"].to_s.start_with?("LEADER_")
        end

        def battles(rec)
          return rec["wins"].to_i + rec["losses"].to_i
        end

        def rate(rec)
          return ((rec["wins"].to_i * 100.0) / [battles(rec), 1].max).round
        end

        def class_name(type)
          return (::GameData::TrainerType.get(type.to_s.to_sym).name rescue type.to_s)
        end

        # "Hiker Marcos", the rival by the name you gave him
        def title(rec)
          return "#{class_name(rec["type"])} #{rec["shown"] || rec["name"]}".strip
        end

        def place(map)
          return "" if map.to_i <= 0
          return (pbGetMapNameFromId(map.to_i).to_s rescue "")
        end

        def last_place(rec)
          return place((rec["last"] || rec["first"] || {})["map"])
        end

        # The rows for a filter (FILTERS), a search (names, classes and
        # places) and a sort (SORTS' index)
        def list(filter = :all, query = nil, sort = 0)
          out = people.values.select { |r| in_filter?(r, filter) }
          out = out.select { |r| matches?(r, query) } if query && !query.empty?
          return sorted(out, sort)
        end

        def in_filter?(rec, filter)
          case filter
          when :rivalries then return rematchable?(rec)
          when :leaders then return rec["kind"] == "leader"
          when :pink_slips then return rec["pink"].is_a?(Hash)
          end
          return true
        end

        def matches?(rec, query)
          q = query.to_s.downcase
          return [rec["name"], rec["shown"], class_name(rec["type"])].any? { |s| s.to_s.downcase.include?(q) } || !match_place(rec, q).nil?
        end

        # The place a search found them by (the last battle's, then the first meeting's)
        def match_place(rec, query)
          q = query.to_s.downcase
          return nil if q.empty?
          return [rec["last"], rec["first"]].compact.map { |h| place(h["map"]) }.find { |s| !s.empty? && s.downcase.include?(q) }
        end

        def last_time(rec)
          t = (rec["last"] || {})["time"]
          return t.respond_to?(:to_f) ? t.to_f : 0.0
        end

        def sorted(list, sort)
          by_name = proc { |r| [(r["shown"] || r["name"]).to_s.downcase, class_name(r["type"]).downcase] }
          keyed = list.map do |r|
            key = case SORTS[sort.to_i]
                  when "Name" then by_name.call(r)
                  when "Battles" then [-battles(r), by_name.call(r)]
                  when "Win Rate" then [-rate(r), -battles(r), by_name.call(r)]
                  when "Best Streak" then [-r["best"].to_i, by_name.call(r)]
                  when "Place" then [last_place(r).downcase, by_name.call(r)]
                  when "Next Step" then Bond.can_reach?(r) ? [0, Bond.next_step(r)[2], by_name.call(r)] : [1, 0, by_name.call(r)]
                  else [-last_time(r), by_name.call(r)]
                  end
            [key, r]
          end
          return keyed.sort_by(&:first).map(&:last)
        end

        #----------------------------------------------------------------------
        # Started once per save: Legacy's records, PIF's rematch counts
        #----------------------------------------------------------------------
        def started(context)
          d = data
          return unless d
          if context && context[:new_game]
            d["legacy_done"] = true
            d["rematches_seeded"] = true
            return
          end
          import_legacy(d) unless d["legacy_done"]
          seed_rematches(d) unless d["rematches_seeded"]
        rescue StandardError => e
          Reloaded::Log.exception("Trainer Control's records couldn't be started", e, :trainer_control)
        end

        def dig(hash, name)
          return nil unless hash.is_a?(Hash)
          return hash[name.to_sym] || hash[name.to_s]
        end

        # Kanto Reloaded Legacy's save value (:kanto_reloaded > modules >
        # trainer_control > records: per version), merged by person
        def import_legacy(d)
          inc = Reloaded::Lifecycle.incoming_save_data
          recs = dig(dig(dig(dig(inc, :kanto_reloaded), :modules), :trainer_control), :records)
          n = 0
          if recs.is_a?(Hash)
            recs.each do |lkey, r|
              next unless r.is_a?(Hash) && lkey.to_s !~ LEGACY_RUNTIME
              type = r["trainer_type"].to_s
              name = r["display_name"].to_s
              key = TrainerControl.person_key(type, name)
              wins = r["wins"].to_i
              losses = r["losses"].to_i
              next if key.nil? || wins + losses <= 0
              rec = record_for(key, type, name, name)
              rec["wins"] = rec["wins"].to_i + wins
              rec["losses"] = rec["losses"].to_i + losses
              rec["best"] = [rec["best"].to_i, r["best_streak"].to_i].max
              rec["streak"] = [rec["streak"].to_i, r["current_streak"].to_i].max
              rec["legacy"] = true
              n += 1
            end
          end
          d["legacy_done"] = true
          Reloaded::Log.info("Trainer Control: #{n} Kanto Reloaded Legacy records brought in", :trainer_control) if n > 0
        end

        # PIF's RematchTrainer ids are the name followed by the class
        # ("JoeyYOUNGSTER": getRematchId); the longest class it ends with
        def seed_rematches(d)
          list = ($PokemonGlobal.rematchedTrainers rescue nil)
          n = 0
          if list.is_a?(Hash) && !list.empty?
            types = []
            ::GameData::TrainerType.each { |t| types << t.id.to_s }
            types.sort_by! { |t| -t.length }
            list.each_value do |rt|
              id = (rt.id rescue nil).to_s
              times = (rt.nbTimesRematched rescue 0).to_i
              next if times <= 0
              type = types.find { |t| id.length > t.length && id.end_with?(t) }
              next unless type
              name = id[0...-type.length]
              key = TrainerControl.person_key(type, name)
              next unless key
              rec = record_for(key, type, name, nil)
              rec["before"] = rec["before"].to_i + times
              n += 1
            end
          end
          d["rematches_seeded"] = true
          Reloaded::Log.info("Trainer Control: #{n} trainers rematched before records", :trainer_control) if n > 0
        end
      end
    end
  end
end
