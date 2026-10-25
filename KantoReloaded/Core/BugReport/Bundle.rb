#==============================================================================
# Kanto Reloaded: what goes in a bug report
#==============================================================================
# One zip (Zip.rb) in the mod's Logging\Bug Reports folder, named
# "KR Bug Report <date> <time>.zip":
#
#   Report.md         what happened (the player's note), the crash, the
#                     versions, this session's errors and Recent Steps
#   logs/             every log: Kanto Reloaded's (its log, the one before
#                     it, the Timing Profiler's), every file in KIF's Logs
#                     folder, and PIF's errorlog.txt (each cut to its last
#                     512 KB)
#   settings/         Kanto Reloaded's settings, controls, layouts and
#                     features, KIF's settings
#   mods.md           every mod: on or off, loaded or not, its version,
#                     author and the order they load in
#   hooks.md          Kanto Reloaded's hooks and any other code on the same
#                     methods
#   save-check.md     the Save Checker's report on the current save
#   screenshot.png    the screen it's about (or the last screenshot)
#   save/<slot>.rxdata   only with Include the Save
#
# The Windows user name is taken out of every text file (its home folder
# becomes %USERPROFILE%, a folder named after it USERNAME).
#==============================================================================

module Reloaded
  module BugReport
    module Bundle
      LOG_MAX = 512 * 1024

      class << self
        #----------------------------------------------------------------------
        # What's in it (the Make a Bug Report screen's rows)
        #----------------------------------------------------------------------
        # [[label, where]] of every log that's there: Kanto Reloaded's (the
        # .log and .txt files in Logging, its own log first; the reports'
        # folders stay out), every file in KIF's Logs folder but its READ
        # ME, and PIF's errorlog.txt.
        def logs
          out = [["Kanto Reloaded.log", Reloaded::Log.path]]
          kr = Reloaded::Paths.logs_dir
          files_in(kr).each do |n|
            out << [n, File.join(kr, n)] if [".log", ".txt"].include?(File.extname(n).downcase) && n != File.basename(Reloaded::Log.path.to_s)
          end
          kif = kif_logs_dir
          files_in(kif).each { |n| out << [n, File.join(kif, n)] unless n.downcase == "read me.txt" } if kif
          out << ["errorlog.txt", pif_errorlog]
          seen = {}
          return out.select { |n, f| f && File.file?(f) && !seen[n] && (seen[n] = true) }
        end

        # KIF's Logs folder (KIF::Paths.logs, or where KIF::Paths.log puts
        # its log), or the game folder's Logs
        def kif_logs_dir
          kp = defined?(::KIF::Paths) ? ::KIF::Paths : nil
          dir = (kp.logs rescue nil) if kp && kp.respond_to?(:logs)
          dir ||= (File.dirname(kp.log("KIF_log.txt")) rescue nil) if kp && kp.respond_to?(:log)
          dir ||= File.join(Reloaded::Paths.game_dir, "Logs")
          return File.directory?(dir.to_s) ? dir : nil
        end

        def files_in(dir)
          return [] unless dir && File.directory?(dir)
          return Dir.children(dir).select { |n| File.file?(File.join(dir, n)) }.sort_by(&:downcase)
        rescue StandardError
          return []
        end

        def pif_errorlog
          return (RTP.getSaveFileName("errorlog.txt") rescue nil) if defined?(::RTP) && ::RTP.respond_to?(:getSaveFileName)
          return File.join(Reloaded::Saves.dir, "errorlog.txt")
        end

        # Every mod KIF knows: [{ :name, :folder, :on, :state, :version, :author, :support }]
        def mods
          return [] unless defined?(::KIF::Mods) && ::KIF::Mods.respond_to?(:entries)
          status = (::KIF::Mods.status rescue {}) || {}
          (::KIF::Mods.entries rescue []).map do |e|
            json = mod_json(e)
            st = status[e.id] || {}
            state = if st[:blocked] then "blocked: #{st[:blocked]}"
                    elsif st[:error] then "failed: #{st[:error]}"
                    elsif st[:loaded] then "loaded"
                    else ((e.enabled? rescue true) ? "on" : "off")
                    end
            { :name => e.name.to_s, :folder => (File.basename(e.path.to_s) rescue e.id.to_s), :on => (e.enabled? rescue true),
              :state => state, :version => json["version"], :author => json["author"], :support => json["support"] }
          end
        rescue StandardError
          return []
        end

        # A mod's mod.json (its "support" link is where its bug reports go).
        def mod_json(entry)
          path = entry.respond_to?(:path) && entry.path ? File.join(entry.path.to_s, "mod.json") : nil
          return {} unless path && File.file?(path)
          data = Reloaded::JSON.parse(Reloaded::Paths.read_text(path).to_s) rescue nil
          return data.is_a?(Hash) ? data : {}
        end

        # A mod by its name in KIF's list (for After a Crash's "send it to").
        def mod_named(name)
          return mods.find { |m| m[:name] == name.to_s }
        end

        # Errors this session that didn't close the game: Kanto Reloaded's
        # (a hook switched off after breaking...) and mods that didn't load.
        def quiet_errors
          out = Reloaded::Log.errors.map { |t, channel, text| "#{t.strftime("%H:%M:%S")} Kanto Reloaded (#{channel}): #{text}" }
          mods.each { |m| out << "#{m[:name]}: #{m[:state]}" if m[:state].start_with?("failed", "blocked") }
          return out
        end

        # The save a report is about: the one being played, else the newest.
        def current_slot
          slot = Reloaded::Saves.playing
          return slot if slot
          return Reloaded::Saves.slots.max_by { |s| File.mtime(Reloaded::Saves.path(s)) rescue Time.at(0) }
        end

        #----------------------------------------------------------------------
        # Making it
        #----------------------------------------------------------------------
        # note: what happened; screenshot: a Bitmap, a .png path or nil;
        # save: a slot to include, or nil; crash: After a Crash's details.
        # Returns { :path, :size, :words } (words: what's in it, in a line).
        def make(note: "", screenshot: nil, save: nil, crash: nil)
          entries = []
          slot = current_slot
          check = save_check(slot)
          entries << ["Report.md", scrub(report_text(note, crash, slot))]
          logs.each { |name, file| entries << ["logs/#{name}", scrub(tail(file))] }
          settings.each { |name, text| entries << ["settings/#{name}", scrub(text)] }
          entries << ["mods.md", scrub(mods_text)]
          entries << ["hooks.md", scrub(hooks_text)]
          entries << ["save-check.md", scrub(check)] if check
          png = screenshot_bytes(screenshot)
          entries << ["screenshot.png", png] if png
          if save && File.file?(Reloaded::Saves.path(save))
            entries << ["save/#{save}.rxdata", File.binread(Reloaded::Saves.path(save))]
          end
          path = target_path
          Reloaded::Zip.write(path, entries)
          words = [_INTL("logs"), _INTL("settings"), _INTL("mods")]
          words << _INTL("the Save Check") if check
          words << _INTL("the save") if entries.any? { |n, _d| n.start_with?("save/") }
          Reloaded::Log.info("Bug report made: #{File.basename(path)} (#{entries.length} files, #{File.size(path)} bytes)", :bug_report)
          return { :path => path, :size => File.size(path), :words => SaveCheck.join_words(words) }
        end

        # The user name out of a text: the home folder becomes
        # %USERPROFILE%, a folder named after the user USERNAME.
        def scrub(text)
          t = text.to_s.dup.force_encoding("UTF-8")
          t = t.scrub("?") unless t.valid_encoding?
          home = ENV["USERPROFILE"] || ENV["HOME"]
          if home && home.length > 3
            [home, home.tr("\\", "/")].uniq.each { |h| t = t.gsub(/#{Regexp.escape(h)}/i, "%USERPROFILE%") }
          end
          user = ENV["USERNAME"] || ENV["USER"]
          if user && user.length >= 2
            t = t.gsub(/([\\\/])#{Regexp.escape(user)}(?=[\\\/])/i) { "#{$1}USERNAME" }
          end
          return t
        end

        # Where it goes: Mods\KantoReloaded\Logging\Bug Reports.
        def target_dir
          return Reloaded::Paths.bug_reports_dir
        end

        private

        def target_path
          dir = target_dir
          base = "KR Bug Report #{Time.now.strftime("%Y-%m-%d %H-%M")}"
          path = File.join(dir, base + ".zip")
          path = File.join(dir, "#{base}-#{Time.now.strftime("%S")}.zip") if File.exist?(path)
          return Reloaded::Paths.free_name(path)   # an earlier report is never written over
        end

        def tail(file)
          size = File.size(file)
          return File.binread(file) if size <= LOG_MAX
          return "[...the first #{size - LOG_MAX} bytes are left out...]\n" + File.binread(file, LOG_MAX, size - LOG_MAX)
        rescue StandardError => e
          return "(couldn't be read: #{e.class}: #{e.message})"
        end

        def settings
          out = []
          %w[Settings.json Controls.json ControlLayouts.json Features.json].each do |name|
            file = File.join(Reloaded::Paths.settings_dir, name)
            out << ["Kanto Reloaded #{name}", Reloaded::Paths.read_text(file).to_s] if File.file?(file)
          end
          out << ["KIF Settings.txt", kif_settings] if defined?(::KIF::Options) && $PokemonSystem
          return out
        end

        def kif_settings
          lines = ["# KIF's settings (* changed from the default)", ""]
          ::KIF::Options.defaults.each do |key, default|
            value = ($PokemonSystem.send(key) rescue nil)
            lines << "#{value == default ? " " : "*"} #{key} = #{value.inspect}"
          end
          return lines.join("\n") + "\n"
        end

        def mods_text
          lines = ["# Mods", "", "Kanto Reloaded #{Reloaded.version}, KIF #{(::KIF::PORT_VERSION rescue "?")}, game #{(::Settings::GAME_VERSION_NUMBER rescue "?")}", "",
                   "| # | Mod | Folder | Version | Author | State |", "|---|---|---|---|---|---|"]
          mods.each_with_index do |m, i|
            lines << "| #{i + 1} | #{m[:name]} | #{m[:folder]} | #{m[:version]} | #{m[:author]} | #{m[:state]} |"
          end
          if defined?(Reloaded::DataPatches) && Reloaded::DataPatches.respond_to?(:mods)
            order = (Reloaded::DataPatches.mods rescue []).map { |m| m[:name] }
            lines += ["", "Data Patches load order: #{order.join(" > ")}"] unless order.empty?
          end
          return lines.join("\n") + "\n"
        end

        def hooks_text
          h = Reloaded::Hooks
          lines = ["# Kanto Reloaded's hooks", ""]
          lines += h.summary.map { |l| "- #{l}" }
          conflicts = (h.conflicts rescue [])
          lines += ["", "## Other code on the same methods", ""]
          if conflicts.empty?
            lines << "None."
          else
            conflicts.each { |entry, others| lines << "- #{entry[:target]}##{entry[:method]}: #{others.map(&:to_s).join(", ")}" }
          end
          return lines.join("\n") + "\n"
        end

        def save_check(slot)
          return nil unless slot && defined?(Reloaded::SaveCheck)
          path = Reloaded::Saves.path(slot)
          return nil unless File.file?(path)
          return Reloaded::SaveCheck.report_text(Reloaded::SaveCheck.run(path, :slot => slot))
        rescue StandardError => e
          return "# Save Check: #{slot}\n\nThe check couldn't run: #{e.class}: #{e.message}\n"
        end

        def screenshot_bytes(shot)
          return nil unless shot
          return (File.binread(shot) rescue nil) if shot.is_a?(String)
          return nil unless shot.respond_to?(:to_file) && !(shot.disposed? rescue true)
          # a name of its own, so no file of yours is written over or removed
          tmp = Reloaded::Paths.free_name(File.join(Reloaded::Paths.bug_reports_dir, "Bug Report screenshot #{Process.pid}.tmp.png"))
          shot.to_file(tmp)
          data = File.binread(tmp)
          File.delete(tmp) rescue nil
          return data
        rescue StandardError
          return nil
        end

        def report_text(note, crash, slot)
          out = ["# Kanto Reloaded Bug Report", ""]
          out << "- Made: #{Time.now.strftime("%Y-%m-%d %H:%M:%S")}"
          out << "- Kanto Reloaded #{Reloaded.version}, KIF #{(::KIF::PORT_VERSION rescue "?")}, game #{(::Settings::GAME_VERSION_NUMBER rescue "?")}"
          out << "- Save: #{slot || "none"}"
          out += Reloaded::QualityOfLife.report_lines if defined?(Reloaded::QualityOfLife)
          out += Reloaded::Difficulty.report_lines if defined?(Reloaded::Difficulty)
          out += ["", "## What Happened", "", note.to_s.strip.empty? ? "(no note)" : note.to_s.strip]
          if crash
            out += ["", "## The Crash", "", "- Error: #{crash[:error]}", "- Where: #{crash[:where]}", "- In: #{crash[:owner]}"]
            out << "- Map: #{crash[:map]}" if crash[:map]
            out += ["", "```", Array(crash[:backtrace]).first(25).join("\n"), "```"] unless Array(crash[:backtrace]).empty?
          end
          errors = quiet_errors
          out += ["", "## Errors This Session (#{errors.length})", ""]
          out += errors.empty? ? ["None."] : errors.map { |e| "- #{e}" }
          steps = Trail.lines
          out += ["", "## Recent Steps (#{steps.length})", ""]
          out += steps.empty? ? ["None yet."] : ["```"] + steps + ["```"]
          return out.join("\n") + "\n"
        end
      end
    end
  end
end
