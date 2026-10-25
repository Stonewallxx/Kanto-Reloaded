#==============================================================================
# Kanto Reloaded: the Save Checker's fixes
#==============================================================================
# Every fix works on the save file as it is, after a backup named for it
# (always kept, whatever the Backup Cap), and writes the save the safe way
# (SafeSave.write_data: a checked temporary file). A save that changed since
# it was checked, the save being played, and a backup aren't fixed.
#
#   Fix.content(report, entries)    Missing Content: each entry's fix
#     :keep     Keep Aside: out of the save into Kanto Reloaded's part of it
#               (plain values: a Pokémon is kept as its Marshal string), back
#               when the game has it again (KeptAside)
#     :remove   gone (a party member, a box slot, a bag item...); a held
#               item, move or ability comes off its Pokémon
#   Fix.make_loadable(report)       a removed mod's own objects set aside
#               (in the backup, and a side file in Kanto Reloaded\Set
#               Aside), so the save loads without it
#==============================================================================

module Reloaded
  module SaveCheck
    module Fix
      SET_ASIDE = "Set Aside".freeze

      class << self
        # Why the save in the report can't be fixed now, or nil.
        def refusal(r)
          return _INTL("This is a backup: Restore it first, then check it again to fix it.") if r.backup
          return _INTL("{1} is the save you're playing. Fix it from the title screen (the Load Screen's Save Manager).", r.slot) if r.slot.to_s == Reloaded::Saves.playing.to_s
          return _INTL("The save changed since it was checked. Check it again first.") if SaveCheck.stamp(r.path) != r.stamp
          return nil
        end

        # Missing Content fixed: entries are the report's (each with :keep
        # or :remove). Returns { :kept, :removed, :backup }.
        def content(r, entries)
          why = refusal(r)
          raise ArgumentError, why if why
          wanted = entries.select { |m| m.fixable && [:keep, :remove].include?(m.fix) }
          return { :kept => 0, :removed => 0, :backup => nil } if wanted.empty?
          done = nil
          Reader.open(r.path) do |data, _missing|
            found = Content.scan(data)
            plan = wanted.map do |m|
              live = found.find { |f| f.kind == m.kind && f.path == m.path && f.id == m.id }
              raise ArgumentError, _INTL("The save changed since it was checked. Check it again first.") unless live
              live.fix = m.fix
              live
            end
            backup = Reloaded::Saves.backup_now(r.slot, _INTL("Before Save Check"))
            kept = plan.count { |m| m.fix == :keep }
            plan.each { |m| keep(data, m) if m.fix == :keep }
            take_out(data, plan)
            Reloaded::SafeSave.write_data(r.path, data)
            done = { :kept => kept, :removed => plan.length - kept, :backup => backup }
          end
          Reloaded::Saves.forget(r.path)
          Reloaded::Log.info("Save Check: #{r.slot}: #{done[:kept]} kept aside, #{done[:removed]} removed", :saves)
          return done
        end

        # The mods whose objects stop the save loading, set aside. Returns
        # { :values (save values taken out), :inside (objects taken out of
        # the game's own values), :backup, :side_file }.
        def make_loadable(r)
          why = refusal(r)
          raise ArgumentError, why if why
          raise ArgumentError, _INTL("Nothing stops this save loading.") if r.missing_classes.empty?
          done = nil
          Reader.open(r.path) do |data, missing|
            raise ArgumentError, _INTL("Nothing stops this save loading.") if missing.empty?
            aside = {}
            data.keys.each do |key|
              next if ModData.key_owner(key) == :game || key == :reloaded
              aside[key] = data.delete(key) if Reader.holds_stub?(data[key])
            end
            inside = strip_stubs(data)
            raise ArgumentError, _INTL("Some of it can't be taken out safely, so nothing was changed.") if Reader.holds_stub?(data)
            backup = Reloaded::Saves.backup_now(r.slot, _INTL("Before Make It Loadable"))
            side = write_side_file(r, aside, inside)
            Reloaded::SafeSave.write_data(r.path, data)
            done = { :values => aside.keys, :inside => inside.length, :backup => backup, :side_file => side }
          end
          Reloaded::Saves.forget(r.path)
          Reloaded::Log.info("Save Check: #{r.slot} made loadable: #{done[:values].inspect} set aside, #{done[:inside]} inside the game's values", :saves)
          return done
        end

        private

        # Keep Aside: what's taken out goes into Kanto Reloaded's part of the
        # save, as plain values.
        def keep(data, m)
          list = (kr_section(data)["kept"] ||= [])
          entry = { "kind" => m.kind.to_s, "id" => m.id.to_s, "name" => m.name.to_s, "from" => m.where.to_s, "at" => Time.now }
          case m.kind
          when :pokemon
            entry["dump"] = Marshal.dump(dig(data, m.path))
          when :item
            entry["qty"] = m.qty.to_i
          else
            entry["pokemon"] = personal_id(m.holder)
          end
          list << entry
        end

        # Kanto Reloaded's section for the Save Checker in data's :reloaded
        # value (made when the save has none yet).
        def kr_section(data)
          value = Reloaded::SaveStore.value_in(data)
          data[:reloaded] = value if value.is_a?(Hash) && !value.empty?
          unless value.is_a?(Hash) && !value.empty?
            value = { "schema" => Reloaded::SaveStore::SCHEMA, "versions" => {}, "sections" => {} }
            data[:reloaded] = value
          end
          value["sections"] ||= {}
          value["versions"] ||= {}
          value["versions"][SECTION.to_s] ||= 1
          return value["sections"][SECTION.to_s] ||= {}
        end

        def personal_id(pk)
          return nil unless pk
          return pk.instance_variable_get(:@personalID) if pk.instance_variable_defined?(:@personalID)
          return (pk.personalID rescue nil)
        end

        # Everything planned comes out of the save. Positions in a list go
        # last first, so the ones before them don't move.
        def take_out(data, plan)
          lists = {}           # list's object id => [list, its Pokémon (moves), indexes]
          at = lambda do |list, index, holder = nil|
            (lists[list.__id__] ||= [list, holder, []])[2] << index
          end
          plan.each do |m|
            case m.kind
            when :pokemon
              path = m.path
              if path[0] == :player
                at.call(data[:player].instance_variable_get(:@party), path[2])
              elsif path[0] == :global_metadata
                slot = dig(data, path[0..-2])
                slot[0] = nil
                slot[1] = 0 if slot.length > 1
              else
                box = dig(data, path[0..-2])
                box[path[-1]] = nil
              end
            when :item
              if m.holder
                m.holder.instance_variable_set(:@item, nil)
              else
                at.call(dig(data, m.path[0..-2]), m.path[-1])
              end
            when :move
              at.call(m.holder.instance_variable_get(:@moves), m.path[-1], m.holder)
            when :ability
              m.holder.instance_variable_set(:@ability, nil)
            end
          end
          lists.each_value do |list, holder, indexes|
            indexes.uniq.sort.reverse_each { |i| list.delete_at(i) }
            give_a_move(holder) if holder && list.empty?
          end
          drop_registered(data)
        end

        # A Pokémon left with no moves gets the first one its species learns
        # that the game has (Tackle if none).
        def give_a_move(pk)
          return unless defined?(::Pokemon::Move)
          species = pk.instance_variable_get(:@species)
          learnset = (::GameData::Species.get(species).moves rescue [])
          id = Array(learnset).map { |e| e.is_a?(Array) ? e[1] : e }.find { |mv| Content.move_known?(mv) && !mv.nil? }
          id ||= :TACKLE
          pk.instance_variable_get(:@moves) << ::Pokemon::Move.new(id)
        rescue StandardError => e
          Reloaded::Log.exception("Save Check: a move for a Pokémon left with none", e, :saves)
        end

        # Registered items the game hasn't got come off the Ready Menu.
        def drop_registered(data)
          bag = data[:bag]
          return unless bag && bag.instance_variable_defined?(:@registeredItems)
          list = bag.instance_variable_get(:@registeredItems)
          list.reject! { |it| !Content.item_known?(it) } if list.is_a?(Array)
        end

        def dig(data, path)
          obj = data[path[0]]
          path[1..-1].each do |step|
            obj = step.is_a?(Symbol) && step.to_s.start_with?("@") ? obj.instance_variable_get(step) : obj[step]
          end
          return obj
        end

        # Stood-in objects inside the game's own values, taken out where they
        # are: [[path words, object]].
        def strip_stubs(data)
          taken = []
          data.each do |key, value|
            next unless Reader.holds_stub?(value)
            SaveCheck.walk(value, [key]) do |obj, path|
              case obj
              when Array
                obj.each_with_index do |x, i|
                  next unless x.is_a?(Stub)
                  taken << [SaveCheck.path_words(path + [i]), x]
                  obj[i] = nil
                end
              when Hash
                obj.keys.each do |k|
                  next unless obj[k].is_a?(Stub)
                  taken << [SaveCheck.path_words(path + [k]), obj[k]]
                  obj.delete(k)
                end
              else
                unless obj.is_a?(Stub) || obj.is_a?(Module)
                  obj.instance_variables.each do |iv|
                    x = obj.instance_variable_get(iv)
                    next unless x.is_a?(Stub)
                    taken << [SaveCheck.path_words(path + [iv]), x]
                    obj.remove_instance_variable(iv)
                  end
                end
              end
              obj.is_a?(Stub) ? :skip : nil
            end
          end
          return taken
        end

        # What was set aside, written as the save wrote it (the mod reads it
        # again), with a note of where each came from.
        def write_side_file(r, aside, inside)
          dir = Reloaded::Paths.ensure_dir(File.join(Reloaded::Paths.data_dir, SET_ASIDE))
          base = File.join(dir, "#{r.slot} #{Time.now.strftime("%Y-%m-%d %H%M%S")}".gsub(/[\\\/:*?"<>|]/, ""))
          # a name no earlier Set Aside file has (its .rxdata and .md go together)
          n = 1
          stem = base
          base = "#{stem} (#{n += 1})" while File.exist?(base + ".rxdata") || File.exist?(base + ".md")
          File.binwrite(base + ".rxdata", Marshal.dump({ "values" => aside, "inside" => inside }))
          lines = ["# Set Aside: #{r.slot}", "",
                   _INTL("Make It Loadable took these out of {1} so it loads without the mods that made them. The backup named Before Make It Loadable has the save as it was: Reinstall the mod, then restore that backup.", r.slot), ""]
          aside.each_key { |k| lines << "- :#{k} (#{ModData.key_owner(k)})" }
          inside.each { |where, obj| lines << "- #{where}: #{obj.class.name}" }
          Reloaded::Paths.write_atomic(base + ".md", lines.join("\n") + "\n")
          return base + ".rxdata"
        end
      end
    end
  end
end
