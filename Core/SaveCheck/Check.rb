#==============================================================================
# Kanto Reloaded: the Save Checker
#==============================================================================
# Roadmap topic 36. A full check of one save (or backup), on what's read
# from the file, without loading it into the game:
#
#   File                 it reads; what it needs that the game hasn't got
#   Kanto Reloaded Data  its parts are in the save (or the .kr copy has them)
#   Upgrades             parts on an older version, and any held after an
#                        upgrade failed (SaveStore)
#   Plain Values         Kanto Reloaded's data is plain values only, so the
#                        save loads without Kanto Reloaded
#   Missing Content      Pokémon, items, moves the game hasn't got (Content)
#   Mod Data             each mod with data in it, and which it needs to
#                        load (ModData)
#
#   r = Reloaded::SaveCheck.run(path)        # a Report
#   r.state                                  # :ok, :note, :problem, :damaged
#   Reloaded::SaveCheck.write_report(r)      # Logging\Save Checks\File A ....md
#
# The Save Manager's health badge is the quick part of the same check
# (Content.scan(data, :quick => true) on what its preview read). Fixes are
# in Fix.rb, Keep Aside's return in KeptAside.rb, the screens in
# Core/UI/SaveCheckScreen.rb.
#==============================================================================

module Reloaded
  module SaveCheck
    # A line of the report card: id, state (:ok :note :problem), title, line
    # (under the title) and details (what A shows)
    Line = Struct.new(:id, :state, :title, :line, :details)
    Report = Struct.new(:path, :slot, :backup, :at, :stamp, :size, :saved_at, :state, :verdict, :sub, :checks,
                        :missing, :mods, :missing_classes, :upgrades, :held, :parts, :reason)
    REPORTS = "Save Checks".freeze
    SECTION = :save_check

    class << self
      def boot
        Reloaded::SaveStore.register(SECTION, :version => 1)
        KeptAside.install if defined?(KeptAside)
        return true
      end

      # The whole check of the file at path. slot: its save slot (worked out
      # from the path when not given); backup: it's one of a save's backups.
      def run(path, slot: nil, backup: false)
        ModData.reset                     # mods may have changed since the last check
        r = Report.new(path, slot || slot_of(path), backup, Time.now, stamp(path), 0, nil, nil, nil, nil, [],
                       [], [], [], [], {}, 0, nil)
        return damaged(r, _INTL("The file isn't there.")) unless File.file?(path)
        r.size = File.size(path)
        return damaged(r, _INTL("The file is empty.")) if r.size.zero?
        begin
          Reader.open(path) do |data, missing|
            r.missing_classes = missing
            if data.is_a?(Array)
              r.checks << Line.new(:file, :note, _INTL("File"), _INTL("From an older version of the game. It updates when it's loaded."),
                                   _INTL("PIF changed how saves are kept. The game converts this one when it loads, so the other checks wait until then."))
              next
            end
            unless data.is_a?(Hash) && data.key?(:player)
              damaged(r, _INTL("It isn't a save the game can read."))
              next
            end
            r.saved_at = saved_at(data)
            check_file(r)
            check_kr(r, data)
            check_upgrades(r, data)
            check_plain(r, data)
            check_missing(r, data)
            check_mods(r, data)
          end
        rescue StandardError => e
          Reloaded::Log.exception("Save Check: #{File.basename(path)} couldn't be read", e, :saves)
          damaged(r, _INTL("It's cut short or garbled, so it can't be read."))
        end
        return finish(r)
      end

      # A file's size and time: a fix refuses a save that changed since.
      def stamp(path)
        return nil unless File.file?(path)
        return "#{File.size(path)}|#{File.mtime(path).to_i}"
      end

      # "File A" for ...\File A.rxdata, and for its backups.
      def slot_of(path)
        dir = File.basename(File.dirname(path.to_s))
        base = File.basename(path.to_s, ".rxdata")
        return dir if base.start_with?("#{dir}_") && Reloaded::Saves.all_slots.include?(dir)
        return base
      end

      # "2 Pokémon and 1 item"
      def count_words(list)
        parts = []
        n = list.count { |m| m.kind == :pokemon }
        parts << _INTL("{1} Pokémon", n) if n > 0
        n = list.count { |m| m.kind == :item }
        parts << (n == 1 ? _INTL("1 item") : _INTL("{1} items", n)) if n > 0
        n = list.count { |m| m.kind == :move }
        parts << (n == 1 ? _INTL("1 move") : _INTL("{1} moves", n)) if n > 0
        n = list.count { |m| m.kind == :ability }
        parts << (n == 1 ? _INTL("1 ability") : _INTL("{1} abilities", n)) if n > 0
        return join_words(parts)
      end

      def join_words(parts)
        return parts[0].to_s if parts.length < 2
        return parts[0...-1].join(", ") + " " + _INTL("and") + " " + parts[-1]
      end

      # The badge's words for what the quick check found.
      def badge_problem(missing)
        return nil if missing.empty?
        if missing.any? { |m| m.kind == :move }
          return _INTL("It has {1} the game hasn't got. A missing move can crash a battle.", count_words(missing))
        end
        return _INTL("It has {1} the game hasn't got (a mod that's off or gone, maybe).", count_words(missing))
      end

      # "1.8 MB"
      def size_words(bytes)
        return _INTL("{1} KB", (bytes / 1024.0).ceil) if bytes < 1024 * 1024
        return _INTL("{1} MB", format("%.1f", bytes / (1024.0 * 1024)))
      end

      # "today 3:42 PM", "yesterday 9:05 AM", "Oct 17"
      def when_words(time)
        return "?" unless time.is_a?(Time)
        clock = time.strftime("%l:%M %p").strip
        now = Time.now
        return _INTL("today {1}", clock) if time.year == now.year && time.yday == now.yday
        y = now - 86_400
        return _INTL("yesterday {1}", clock) if time.year == y.year && time.yday == y.yday
        return time.strftime(time.year == now.year ? "%b %-d" : "%b %-d %Y")
      end

      #------------------------------------------------------------------------
      # The report as a file (Save the Report; Bug Reports attaches the
      # newest for a save)
      #------------------------------------------------------------------------
      def report_dir
        return Reloaded::Paths.ensure_dir(File.join(Reloaded::Paths.logs_dir, REPORTS))
      end

      def write_report(r)
        name = "#{r.slot} #{r.at.strftime("%Y-%m-%d %H%M%S")}.md".gsub(/[\\\/:*?"<>|]/, "")
        file = File.join(report_dir, name)
        Reloaded::Paths.write_atomic(file, report_text(r))
        return file
      end

      # The newest report for a save, or nil.
      def newest_report(slot)
        dir = File.join(Reloaded::Paths.logs_dir, REPORTS)
        return nil unless File.directory?(dir)
        list = Dir.glob(File.join(dir, "#{slot} *.md"))
        return list.max_by { |f| File.mtime(f) }
      end

      def report_text(r)
        out = []
        what = r.backup ? _INTL("{1} (a backup)", r.slot) : r.slot.to_s
        out << "# Save Check: #{what}"
        out << ""
        out << "**#{r.verdict}.** #{r.sub}"
        out << ""
        out << "- File: #{r.path.to_s.gsub(%r{[\\/]+}) { "\\" }}"
        out << "- Size: #{size_words(r.size)}" if r.size.to_i > 0
        out << "- Saved: #{r.saved_at.strftime("%Y-%m-%d %H:%M")}" if r.saved_at.is_a?(Time)
        out << "- Checked: #{r.at.strftime("%Y-%m-%d %H:%M:%S")}, on a copy read from the file"
        kif = defined?(::KIF::PORT_VERSION) ? " · KIF Beta #{::KIF::PORT_VERSION}" : ""
        out << "- Kanto Reloaded #{Reloaded.version}#{kif}"
        out << ""
        out << "## Checks"
        out << ""
        out << "| Check | Result | |"
        out << "|---|---|---|"
        r.checks.each { |c| out << "| #{c.title} | #{state_words(c.state)} | #{c.line} |" }
        r.checks.each do |c|
          next if c.details.to_s.empty?
          out << ""
          out << "### #{c.title}"
          out << ""
          out << c.details.to_s
        end
        unless r.missing.empty?
          out << ""
          out << "## Missing Content"
          out << ""
          out << "| What | Kind | Where |"
          out << "|---|---|---|"
          r.missing.each { |m| out << "| #{m.name} (#{m.id}) | #{kind_words(m.kind)} | #{m.where} |" }
        end
        unless r.mods.empty?
          out << ""
          out << "## Mod Data"
          out << ""
          out << "| Mod | Size | Load | Keeps |"
          out << "|---|---|---|---|"
          r.mods.each do |m|
            keeps = (m.keys.map { |k| ":#{k}" } + m.classes.keys).join(", ")
            out << "| #{m.name} | #{size_words(m.bytes)} | #{m.needed ? "Needed to Load" : "Safe to Remove"} | #{keeps} |"
          end
        end
        out << ""
        return out.join("\n")
      end

      def state_words(state)
        case state
        when :ok then return _INTL("OK")
        when :note then return _INTL("Note")
        else return _INTL("Problem")
        end
      end

      def kind_words(kind)
        case kind
        when :pokemon then return _INTL("Pokémon")
        when :item then return _INTL("Item")
        when :move then return _INTL("Move")
        else return _INTL("Ability")
        end
      end

      # A section id ("shiny_log") as words ("Shiny Log").
      def part_words(id)
        return id.to_s.split(/[_\s]+/).map(&:capitalize).join(" ")
      end

      private

      def saved_at(data)
        p = data[:player]
        t = (p.last_time_saved rescue nil)
        t ||= (p.instance_variable_get(:@last_time_saved) rescue nil)
        return t.is_a?(Time) ? t : nil
      end

      def damaged(r, reason)
        r.reason = reason
        r.state = :damaged
        r.checks = [Line.new(:file, :problem, _INTL("File"), reason,
                             _INTL("The file can't be read, so nothing else could be checked. Its newest backup that reads whole is the way back: The Save Manager's Backups tab, or hold A on Continue."))]
        return r
      end

      def finish(r)
        return damaged_verdict(r) if r.state == :damaged
        problems = r.checks.count { |c| c.state == :problem }
        notes = r.checks.count { |c| c.state == :note }
        if problems > 0
          r.state = :problem
          r.verdict = problems == 1 ? _INTL("1 Problem") : _INTL("{1} Problems", problems)
          r.sub = _INTL("Something here can stop the save working right.")
        elsif notes > 0
          r.state = :note
          r.verdict = notes == 1 ? _INTL("Healthy, 1 Note") : _INTL("Healthy, {1} Notes", notes)
          r.sub = notes == 1 ? _INTL("Nothing is wrong with the file. 1 thing is worth a look.") :
                               _INTL("Nothing is wrong with the file. {1} things are worth a look.", notes)
        else
          r.state = :ok
          r.verdict = _INTL("Healthy")
          r.sub = _INTL("Nothing is wrong with the file.")
        end
        return r
      end

      def damaged_verdict(r)
        r.verdict = _INTL("Damaged")
        r.sub = r.reason.to_s
        return r
      end

      def check_file(r)
        size = size_words(r.size)
        # the game's own classes are only stood in for outside the game
        missing = r.missing_classes.reject { |c| ModData.class_owner(c) == :game }
        if missing.empty?
          when_text = r.saved_at ? _INTL("saved {1}", when_words(r.saved_at)) : nil
          line = when_text ? _INTL("Loads. {1}, {2}.", size, when_text) : _INTL("Loads. {1}.", size)
          r.checks << Line.new(:file, :ok, _INTL("File"), line, nil)
          return
        end
        owners = missing.map { |c| ModData.class_owner(c) }.uniq
        details = missing.map { |c| "- #{c}: #{ModData.class_owner(c)}" }.join("\n")
        r.checks << Line.new(:file, :problem, _INTL("File"),
                             _INTL("Needs {1} to load: It holds things the game hasn't got.", join_words(owners)),
                             _INTL("The game can't read these without the mod that made them:") + "\n\n" + details + "\n\n" +
                             _INTL("Install the mod again, or use Make It Loadable in Mod Data."))
      end

      def check_kr(r, data)
        value = data[:reloaded]
        sections = value.is_a?(Hash) && value["sections"].is_a?(Hash) ? value["sections"] : nil
        if sections && !value.empty?
          r.parts = sections.length
          details = sections.map { |id, v| "- #{part_words(id)}: #{size_words((Marshal.dump(v).bytesize rescue 0))}" }.join("\n")
          r.checks << Line.new(:kr, :ok, _INTL("Kanto Reloaded Data"),
                               r.parts == 1 ? _INTL("Found: 1 part.") : _INTL("Found: {1} parts.", r.parts), details)
          return
        end
        copy = r.backup ? nil : Reloaded::SaveStore.backup_path(r.path)
        if copy && File.file?(copy)
          r.checks << Line.new(:kr, :note, _INTL("Kanto Reloaded Data"),
                               _INTL("Not in the save. Its copy brings it back when it's loaded."),
                               _INTL("It was saved with Kanto Reloaded off, maybe. Kanto Reloaded keeps a copy of its data each time the game saves ({1}), and puts it back when this save loads.", File.basename(copy)))
        else
          r.checks << Line.new(:kr, :ok, _INTL("Kanto Reloaded Data"), _INTL("None yet: Last saved without Kanto Reloaded."), nil)
        end
      end

      def check_upgrades(r, data)
        value = data[:reloaded]
        r.upgrades = Reloaded::SaveStore.pending_upgrades(value)
        r.held = value.is_a?(Hash) && value["held"].is_a?(Hash) ? value["held"] : {}
        unless r.held.empty?
          names = r.held.keys.map { |id| part_words(id) }
          details = r.held.map { |id, h| "- #{part_words(id)} (version #{h["version"]}): #{h["error"]}" }.join("\n")
          r.checks << Line.new(:upgrades, :problem, _INTL("Upgrades"),
                               _INTL("{1}: An upgrade failed. Its old data is held, nothing is lost.", join_words(names)),
                               _INTL("When an upgrade fails, none of them apply and the old data is kept in the save. It's tried again each time the save loads, so a newer Kanto Reloaded can finish it.") + "\n\n" + details)
          return
        end
        if r.upgrades.empty?
          r.checks << Line.new(:upgrades, :ok, _INTL("Upgrades"), _INTL("Up to date."), nil)
          return
        end
        id, from, to = r.upgrades[0]
        line = _INTL("{1}: Version {2} to {3}.", part_words(id), from, to)
        line += " " + _INTL("And {1} more.", r.upgrades.length - 1) if r.upgrades.length > 1
        details = r.upgrades.map { |i, f, t| "- #{part_words(i)}: version #{f} to #{t}" }.join("\n")
        r.checks << Line.new(:upgrades, :note, _INTL("Upgrades"), line,
                             _INTL("These upgrade when the save loads, all together on a copy: If one fails, none apply and the old data is kept.") + "\n\n" + details)
      end

      def check_plain(r, data)
        value = data[:reloaded]
        unless value.is_a?(Hash)
          r.checks << Line.new(:plain, :ok, _INTL("Plain Values"), _INTL("Loads without Kanto Reloaded."), nil)
          return
        end
        found = {}
        SaveCheck.walk(value) do |obj, path|
          k = obj.class
          found[k.name.to_s] ||= SaveCheck.path_words(path) unless ModData::PLAIN.include?(k)
          nil
        end
        if found.empty?
          r.checks << Line.new(:plain, :ok, _INTL("Plain Values"), _INTL("Loads without Kanto Reloaded."), nil)
        else
          details = found.map { |k, where| "- #{k}: #{where}" }.join("\n")
          r.checks << Line.new(:plain, :problem, _INTL("Plain Values"),
                               _INTL("Holds {1}: It can't load without Kanto Reloaded.", join_words(found.keys)),
                               _INTL("Kanto Reloaded keeps only plain values in a save, so the save loads without it. These aren't:") + "\n\n" + details)
        end
      end

      def check_missing(r, data)
        unless Content.known_data?
          r.checks << Line.new(:missing, :note, _INTL("Missing Content"), _INTL("Not checked: The game's data isn't loaded."), nil)
          return
        end
        r.missing = Content.scan(data)
        if r.missing.empty?
          r.checks << Line.new(:missing, :ok, _INTL("Missing Content"), _INTL("Nothing missing."), nil)
          return
        end
        state = r.missing.any? { |m| m.kind == :move } ? :problem : :note
        line = count_words(r.missing) + "."
        details = r.missing.map { |m| "- #{m.name} (#{kind_words(m.kind)}): #{m.where}" }.join("\n")
        why = state == :problem ? _INTL("The game shows a missing Pokémon as a Pikachu and a missing item as Unknown, but a missing move can crash a battle.") :
                                  _INTL("The game shows a missing Pokémon as a Pikachu and a missing item as Unknown until it's back.")
        r.checks << Line.new(:missing, state, _INTL("Missing Content"), line, why + "\n\n" + details)
      end

      def check_mods(r, data)
        r.mods = ModData.scan(data)
        blocked = r.mods.select { |m| m.needed && m.installed != true }
        unless blocked.empty?
          m = blocked[0]
          line = m.installed == :off ? _INTL("{1} is needed to load it, and it's off.", m.name) : _INTL("{1} is needed to load it, and isn't installed.", m.name)
          r.checks << Line.new(:mods, :problem, _INTL("Mod Data"), line, nil)
          return
        end
        n = r.mods.length
        line = case n
               when 0 then _INTL("No mod has data in this save.")
               when 1 then _INTL("1 mod has data in this save.")
               else _INTL("{1} mods have data in this save.", n)
               end
        r.checks << Line.new(:mods, :ok, _INTL("Mod Data"), line, nil)
      end
    end
  end
end
