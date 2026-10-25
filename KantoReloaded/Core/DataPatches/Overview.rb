#==============================================================================
# Kanto Reloaded: what the Patch Viewer shows
#==============================================================================
# The registry's patches as the Patch Viewer lists them, with no drawing here
# (the offline test checks every word): each mod a section in load order,
# its rows a target and what happened to it (Added, Edited, Rejected), and
# what the description box and Details say, in plain words. Hot Reload's
# report compares two snapshots.
#
#   o = Reloaded::DataPatches::Overview.new
#   o.sections                     [Section], in the order the patches apply
#   o.describe(row)                the description box's text for a row
#   o.describe_section(section)    ...for a mod
#   o.entries(row)                 [[name, text]], what Details lists
#   o.matches?(row, "claw")        Search
#
#   before = Overview.snapshot
#   seconds = Reloaded::DataPatches.reload
#   Overview.changes(before, Overview.snapshot)   what Hot Reload changed
#==============================================================================

module Reloaded
  module DataPatches
    class Overview
      # status: :ok, :conflict or :rejected (the worst), count: how many
      Section = Struct.new(:key, :name, :order, :rows, :patches, :files, :conflicts, :rejected, :code) do
        def status
          return :rejected if rejected > 0
          return :conflict if conflicts > 0
          return :ok
        end

        # Kanto Reloaded's own (its Poke Ball in the list).
        def own?
          return name == Reloaded::DataPatches::OWN_NAME
        end
      end

      # kind: :added, :edited or :rejected; count: entries (patches, when
      # rejected)
      Row = Struct.new(:section, :target, :kind, :patches, :count) do
        def label
          return Reloaded::DataPatches.label(target) unless target.to_s.empty?
          return "Patch Files"
        end
      end

      SHOWN_NAMES = 3       # names a description lists before "and N more"
      SHOWN_REASONS = 4     # rejected patches a description explains

      DP = Reloaded::DataPatches

      attr_reader :sections

      def initialize
        @errors = index(DP.errors)
        @warnings = index(DP.warnings)
        @names = {}
        @sections = build_sections
      end

      def empty?
        return @sections.empty?
      end

      #------------------------------------------------------------------------
      # Words
      #------------------------------------------------------------------------
      def describe_section(s)
        n = @sections.length
        text = if s.code
                 "#{s.name}'s patches come from its scripts, not files."
               else
                 "#{s.name} loads #{ordinal(s.order)} of #{n}: #{count(s.patches.length, "patch", "patches")} " \
                   "from #{count(s.files, "file", "files")}."
               end
        parts = []
        parts << "#{count(s.rejected, "patch was", "patches were")} rejected; the Rejected rows say why." if s.rejected > 0
        if s.conflicts > 0
          parts << "#{count(s.conflicts, "entry is", "entries are")} also changed by another mod, " \
                   "and the mod that loads last wins."
        end
        parts << "Nothing conflicts and nothing was rejected." if parts.empty?
        return ([text] + parts).join(" ")
      end

      def describe(row)
        if row.kind == :rejected
          head = "#{count(row.count, "patch", "patches")} #{row.count == 1 ? "was" : "were"} rejected, " \
                 "so the game's data is as it was without #{row.count == 1 ? "it" : "them"}."
          why = row.patches.first(SHOWN_REASONS).map do |p|
            reason = reasons(p).first
            reason.include?(who(p)) ? reason : "#{who(p)}: #{reason}"
          end
          more = row.patches.length > SHOWN_REASONS ? ["Details (A) lists all #{row.patches.length}."] : []
          return ([head] + why + more).join(" ")
        end
        names = names(row)
        verb = row.kind == :added ? "adds" : "edits"
        text = "#{row.section.name} #{verb} #{row.count} #{DP.noun(row.target, row.count)}: #{list(names)}."
        warns = row.patches.flat_map { |p| warnings(p) }.uniq
        return ([text] + warns).join(" ")
      end

      # Details: every entry of a row, and what happened to it.
      def entries(row)
        if row.kind == :rejected
          return row.patches.map do |p|
            [who(p), "#{reasons(p).join(" ")} (#{where(p)})"]
          end
        end
        return row.patches.group_by { |p| p[:id] }.map do |id, ps|
          text = ps.map do |p|
            fields = p[:data].keys.map(&:to_s)
            how = case p[:operation]
                  when "add" then "Added"
                  when "replace" then "Replaced"
                  when "merge" then "Merged #{fields.join(", ")}"
                  else "Edited #{fields.join(", ")}"
                  end
            "#{how} in #{where(p)}."
          end
          [entry_name(row.target, id, ps.last[:data]), (text + ps.flat_map { |p| warnings(p) }.uniq).join(" ")]
        end
      end

      # Search: the mod, the target, or one of the row's entries.
      def matches?(row, query)
        q = query.to_s.strip.downcase
        return true if q.empty?
        return true if row.section.name.downcase.include?(q) || row.label.downcase.include?(q)
        return names(row).any? { |n| n.downcase.include?(q) } ||
               row.patches.any? { |p| p[:id].to_s.downcase.include?(q) }
      end

      # How an entry reads: its name, else a readable id.
      def entry_name(target, id, data = nil)
        name = data.is_a?(Hash) ? (data["name"] || data[:name]) : nil
        if DP.blank?(name)
          base = DP.entry(target.to_s.start_with?("species.") ? "species.core" : target, id)
          name = base["name"] if base.is_a?(Hash) && !target.to_s.start_with?("trainers.")
        end
        return name.to_s unless DP.blank?(name)
        case target.to_s
        when /\Atrainers\./
          type, tname, version = id.to_s.split("|")
          kind = DP.entry("trainer_types", type)
          kind = kind.is_a?(Hash) && !DP.blank?(kind["name"]) ? kind["name"] : titleize(type)
          return "#{tname} (#{kind}#{version.to_i > 0 ? " #{version}" : ""})"
        when /\Aencounters\./
          map, version = id.to_s.split("_")
          return "#{map_name(map)}#{version.to_i > 0 ? " (#{version})" : ""}"
        end
        return titleize(id)
      end

      #------------------------------------------------------------------------
      # Hot Reload
      #------------------------------------------------------------------------
      # What's applied, rejected and read, to compare after a reload.
      def self.snapshot
        applied = {}
        mods = {}
        DP.patches.each do |p|
          (mods[p[:mod_id]] ||= [p[:mod_name], []])[1] << [p[:file], p[:target], p[:id], p[:operation], p[:data], p[:applied], p[:rejected]]
          next if rejected?(p)
          (applied[[p[:target], p[:id]]] ||= []) << [p[:mod_id], p[:operation], p[:data]]
        end
        errors = DP.errors.map { |e| [e[:file], e[:target], e[:id], e[:message]] }.uniq
        return { :applied => applied, :mods => mods, :errors => errors }
      end

      # { :targets => [[target, { :added, :changed, :removed }]], :new_errors =>
      #   ["Moves: ..."], :fixed => n, :mods => ["a mod's name", ...] }
      def self.changes(before, after)
        counts = Hash.new { |h, t| h[t] = { :added => 0, :changed => 0, :removed => 0 } }
        (before[:applied].keys | after[:applied].keys).each do |key|
          was = before[:applied][key]
          now = after[:applied][key]
          next if was == now
          target, id = key
          kind = if was.nil? then DP.new_entry?(target, id) ? :added : :changed
                 elsif now.nil? then DP.new_entry?(target, id) ? :removed : :changed
                 else :changed
                 end
          counts[target][kind] += 1
        end
        targets = counts.keys.sort_by { |t| [DP.target_rank(t), t] }.map { |t| [t, counts[t]] }
        fresh = after[:errors] - before[:errors]
        new_errors = fresh.map do |file, target, _id, message|
          where = target.to_s.empty? ? File.basename(file.to_s) : DP.label(target)
          message.to_s.include?(where) ? message.to_s : "#{where}: #{message}"
        end
        mods = (before[:mods].keys | after[:mods].keys).select { |m| before[:mods][m] != after[:mods][m] }
        names = mods.map { |m| (after[:mods][m] || before[:mods][m])[0] }
        return { :targets => targets, :new_errors => new_errors, :fixed => (before[:errors] - after[:errors]).length,
                 :mods => names }
      end

      # Not applied: a check refused it, or it never could be.
      def self.rejected?(p)
        return true unless p[:errors].empty?
        return true if p[:rejected]
        return !p[:applied] && !p[:deferred]
      end

      private

      #------------------------------------------------------------------------
      # Building
      #------------------------------------------------------------------------
      # In the order the patches apply (scripts' patches first, then each
      # mod's files in load order); a mod's scripts and files are one section.
      def build_sections
        by_key = {}
        list = []
        DP.patches.each do |p|
          s = by_key[p[:mod_id]] || list.find { |x| x.name == p[:mod_name].to_s }
          unless s
            s = Section.new(p[:mod_id], p[:mod_name].to_s, list.length + 1, [], [], 0, 0, 0, true)
            list << s
          end
          by_key[p[:mod_id]] = s
          s.patches << p
          s.code = false unless p[:internal]
        end
        list.each { |s| fill(s) }
        return list
      end

      def fill(s)
        s.files = s.patches.reject { |p| p[:internal] }.map { |p| p[:file] }.uniq.length
        s.rejected = s.patches.count { |p| Overview.rejected?(p) }
        s.conflicts = s.patches.reject { |p| Overview.rejected?(p) || p[:conflicts].empty? }.map { |p| [p[:target], p[:id]] }.uniq.length
        groups = s.patches.group_by do |p|
          kind = if Overview.rejected?(p) then :rejected
                 elsif p[:operation] == "add" || (p[:operation] == "replace" && DP.new_entry?(p[:target], p[:id])) then :added
                 else :edited
                 end
          [p[:target].to_s, kind]
        end
        rows = groups.map do |(target, kind), ps|
          known = target.empty? || DP.targets.include?(target)
          Row.new(s, known ? target : "", kind, ps, kind == :rejected ? ps.length : ps.map { |p| p[:id] }.uniq.length)
        end
        # Patch Files (no target, or one that isn't there) last; one row each
        rows = rows.group_by { |r| [r.target, r.kind] }.map do |(target, kind), rs|
          next rs.first if rs.length == 1
          ps = rs.flat_map(&:patches)
          Row.new(s, target, kind, ps, kind == :rejected ? ps.length : ps.map { |p| p[:id] }.uniq.length)
        end
        order = [:added, :edited, :rejected]
        s.rows = rows.sort_by { |r| [r.target.empty? ? 1 : 0, DP.target_rank(r.target), r.target, order.index(r.kind)] }
      end

      def index(list)
        out = Hash.new { |h, k| h[k] = [] }
        list.each { |e| out[[e[:mod_id], e[:file], e[:index]]] << e[:message] }
        return out
      end

      #------------------------------------------------------------------------
      # Wording
      #------------------------------------------------------------------------
      def reasons(p)
        list = []
        list << p[:rejected] if p[:rejected]
        list.concat(@errors[[p[:mod_id], p[:file], p[:index]]])
        list.concat(p[:errors])
        list = list.compact.map(&:to_s).uniq
        return list.empty? ? ["It wasn't applied."] : list
      end

      def warnings(p)
        return @warnings[[p[:mod_id], p[:file], p[:index]]].uniq
      end

      # A rejected patch, as its id (or its file, when it has none).
      def who(p)
        return DP.blank?(p[:id]) ? File.basename(p[:file].to_s) : p[:id].to_s
      end

      # Its file inside the mod's DataPatches folder, and which patch in it.
      def where(p)
        return "#{p[:mod_name]}'s scripts" if p[:internal]
        file = p[:file].to_s
        i = file.index("/#{DP::FOLDER}/")
        return "#{i ? file[(i + DP::FOLDER.length + 2)..-1] : File.basename(file)}, patch #{p[:index].to_i + 1}"
      end

      def names(row)
        return @names[row.object_id] ||= row.patches.map { |p| p[:id] }.uniq.map do |id|
          entry_name(row.target, id, row.patches.reverse.find { |p| p[:id] == id }[:data])
        end
      end

      # "A, B, C and 169 more" / "A and B"
      def list(names)
        shown = names.first(SHOWN_NAMES)
        rest = names.length - shown.length
        return "#{shown.join(", ")} and #{rest} more" if rest > 0
        return shown.first.to_s if shown.length == 1
        return "#{shown[0...-1].join(", ")} and #{shown.last}"
      end

      def count(n, one, more)
        return "#{n} #{n == 1 ? one : more}"
      end

      def ordinal(n)
        suffix = (11..13).include?(n % 100) ? "th" : { 1 => "st", 2 => "nd", 3 => "rd" }.fetch(n % 10, "th")
        return "#{n}#{suffix}"
      end

      # "SHADOW_CLAW" => "Shadow Claw"
      def titleize(id)
        return id.to_s.split(/_+/).reject(&:empty?).map { |w| w[0].upcase + w[1..-1].to_s.downcase }.join(" ")
      end

      def map_name(map)
        name = defined?(pbGetMapNameFromId) ? (pbGetMapNameFromId(map.to_i) rescue nil) : nil
        return DP.blank?(name) ? "Map #{map}" : "#{name} (Map #{map})"
      end
    end
  end
end
