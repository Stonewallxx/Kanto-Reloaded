#==============================================================================
# Kanto Reloaded (Dev): the Hook Check report
#==============================================================================
# The chosen design (By Severity): Markdown with real headings, for VS
# Code's Outline. A count table, then Broken (what, effect, where, fix),
# Changed Upstream with diffs, Others on the Same Method (who, in what
# order, how), Takeovers and Settings, and the OK hooks last.
# Written to Logging/Hook Check <KIF version>.md in the mod folder.
#==============================================================================

module Reloaded
  module HookCheck
    module Report
      WORDS = %w[No One Two Three Four Five Six Seven Eight Nine Ten].freeze

      class << self
        # Writes the run's report; returns its path.
        def write(run)
          path = File.join(Reloaded::Paths.logs_dir, file_name(run.version))
          Reloaded::Paths.write_atomic(path, text(run))
          return path
        rescue StandardError => e
          Reloaded::Log.exception("The Hook Check report couldn't be written", e, :dev)
          return nil
        end

        def file_name(version)
          return "Hook Check #{version}.md"
        end

        # The path as the alert and the results show it: "Logging/Hook Check 0.21.60.md".
        def short(path)
          return path ? "Logging/#{File.basename(path)}" : "(not written)"
        end

        def text(run)
          out = []
          out << "# Hook Check: KIF #{run.version}"
          out << ""
          since = run.first ? "first check, nothing to compare yet" : "last checked: #{run.previous || run.version}"
          out << "Kanto Reloaded #{Reloaded.version} against KIF #{run.version} (#{since}). #{run.time.strftime("%Y-%m-%d %H:%M")}."
          out << ""
          out << "| Result | Count |"
          out << "|---|---|"
          out << "| Broken | #{run.count(:broken)} |"
          out << "| Changed Upstream | #{run.count(:changed)} |"
          out << "| Others on the Same Method | #{run.count(:shared)} |"
          missing = run.count(:missing)
          out << "| Takeovers and Settings | #{missing == 0 ? "OK" : (missing == 1 ? "1 problem" : "#{missing} problems")} |"
          out << "| OK | #{run.ok_hooks} |"
          out << ""
          broken(out, run)
          changed(out, run)
          shared(out, run)
          needs(out, run)
          ok(out, run)
          return out.join("\n") + "\n"
        end

        private

        def broken(out, run)
          out << "## Broken"
          out << ""
          list = run.hooks.select { |r| r.kind == :broken }
          if list.empty?
            out << "Nothing is broken."
            out << ""
            return
          end
          list.each do |r|
            out << "### #{r.id}: #{r.target}"
            out << ""
            out << "- **What:** #{r.what}"
            out << "- **Effect:** #{r.effect}"
            out << "- **Where:** #{r.where || "unknown"}"
            out << "- **Fix:** #{r.fix}"
            out << ""
          end
        end

        def changed(out, run)
          out << "## Changed Upstream"
          out << ""
          list = run.hooks.select { |r| r.kind == :changed }
          if list.empty?
            out << (run.first ? "Nothing to compare yet: this is the first check. Each KIF update from now on is compared with this one." :
                                "Nothing KIF changed under a hook since #{run.previous || run.version}.")
            out << ""
            return
          end
          list.group_by(&:method_key).each do |target, rs|
            r = rs.first
            out << "### #{rs.map(&:id).join(", ")}: #{target}"
            out << ""
            parts = []
            parts << (r.diff ? "Same arguments, new body (+#{r.added} −#{r.removed})#{r.file ? " in #{r.file}" : ""}." : "Same arguments and body.")
            parts << r.what if r.what
            parts << "#{WORDS[rs.length] || rs.length} Kanto Reloaded hooks wrap it." if rs.length > 1
            out << parts.join(" ")
            out << ""
            if r.diff
              out << "```diff"
              Diff.hunks(r.diff, 2).each do |kind, line|
                out << case kind
                       when :add then "+ #{line}"
                       when :del then "- #{line}"
                       when :gap then "  ..."
                       else "  #{line}"
                       end
              end
              out << "```"
              out << ""
            end
            rs.each { |x| out << "- **Check:** #{x.check}" }
            out << ""
          end
        end

        def shared(out, run)
          out << "## Others on the Same Method"
          out << ""
          list = run.hooks.select { |r| r.others && r.others.any? { |o| !o[:ours] } }
          if list.empty?
            out << "Nothing else is on the methods Kanto Reloaded hooks."
            out << ""
            return
          end
          list.group_by(&:method_key).each do |target, rs|
            out << "### #{target}"
            out << ""
            out << "| Order | Who | How |"
            out << "|---|---|---|"
            rs.first.others.each_with_index { |o, i| out << "| #{i + 1} | #{o[:who]} | #{o[:how]} |" }
            out << ""
          end
        end

        def needs(out, run)
          out << "## Takeovers and Settings"
          out << ""
          list = run.needs
          if list.empty?
            out << "Kanto Reloaded takes over nothing and reads no KIF setting by name."
            out << ""
            return
          end
          out << "| Kind | Name | Used By | Result |"
          out << "|---|---|---|---|"
          list.each { |r| out << "| #{r.need} | #{r.name} | #{r.where} | #{r.kind == :ok ? "OK" : "Missing"} |" }
          out << ""
          list.select(&:problem?).each do |r|
            out << "### #{r.need}: #{r.name}"
            out << ""
            out << "- **What:** #{r.what}"
            out << "- **Effect:** #{r.effect}"
            out << "- **Where:** #{r.where}"
            out << "- **Fix:** #{r.fix}"
            out << ""
          end
        end

        def ok(out, run)
          out << "## OK"
          out << ""
          list = run.hooks.select { |r| r.kind == :ok }
          if list.empty?
            out << "No hook is free of findings."
            out << ""
            return
          end
          list.each { |r| out << "- #{r.id}: #{r.target}" }
          out << ""
        end
      end
    end
  end
end
