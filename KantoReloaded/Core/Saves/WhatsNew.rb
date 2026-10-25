#==============================================================================
# Kanto Reloaded: What's New (the notes of each version)
#==============================================================================
# The What's New screen's sources, each with its versions and their notes:
#
#   Kanto Reloaded   its Documentation\Changelogs folder
#   KIF Beta         Data\KIF\update_notes.txt (KIF ships only the current
#                    version's, so each one is kept as it arrives, in
#                    Kanto Reloaded\Whats New.json)
#   a mod            its Documentation\Changelogs folder, or a Changelogs
#                    folder at its root (Documentation\Changelogs wins);
#                    without one, Changelog.md (or CHANGELOG.md) in its
#                    folder, or its scripts: Reloaded::WhatsNew.add("My Mod",
#                    "1.2.0", ["A note", "Another"], "2026-10-20")
#
# A Changelogs folder (his changelog system, Admin Tools\Changelog
# System.md): each vX.Y.Z.md is one version. Unreleased.md, other files and
# Dev\ are never read, and neither is a version whose Release Date is
# Unreleased. Its Update line, Release Date, Works On and sub-sections are
# read, forgiving: what a file misses is left out, and a file that can't be
# read is skipped.
#
#   # My Mod
#   ## Update #2 - Lights Out (Hotfix 1)
#   - **Version:** v1.1.1
#   - **Release Date:** November 14, 2026
#   - **Works On:** KIF 1.2.1+
#   ### Fixed
#   - **Town Lights:** A note
#     - a note under it
#
# The old single Changelog.md:
#
#   # My Mod
#   ## 1.2.0 (2026-10-20)
#   - A note
#     - a note under it
#
# A version is NEW until the What's New screen has shown it. The first time
# a source is seen, only its newest version is NEW.
#==============================================================================

module Reloaded
  module WhatsNew
    FILE = "Whats New.json".freeze
    KR = "Kanto Reloaded".freeze
    KIF = "KIF".freeze
    # notes: [[text, depth]], every line in order (plain words); blocks: the
    # same notes as Markdown has them (Block); from a Changelogs folder also
    # its Update line (update, name, hotfix), Works On and sections:
    # [[title or nil, [[text, depth]]]]; name: a version heading's words
    # ("## v2.1 - Faster Pedals") too
    Version = Struct.new(:version, :date, :notes, :update, :name, :hotfix, :works_on, :sections, :blocks)
    # One piece of a version's notes, however its changelog is written:
    #   kind      :head (level 1-6), :bullet (depth 0-3), :number (number,
    #             depth), :para (depth 0 or 1), :quote, :rule
    #   segments  [[text, style]]: style :plain, :bold, :italic, :code
    #             (a link is only its words, plain; web addresses, images
    #             and HTML tags are left out: his call, for safety)
    Block = Struct.new(:kind, :level, :depth, :number, :segments)
    VERSION_FILE = /\Av(\d+(?:\.\d+)*)\.md\z/i
    UPDATE_LINE = /\A##\s+Update\s+#(\d+)\s*(?:[-:]\s*(.*?))?\s*(?:\((Hotfix\s+\d+)\))?\s*\z/i
    FIELD = /\A[-*]\s+\*\*([^*]+?):\*\*\s*(.*)\z/
    HEADER_FIELDS = ["version", "release date", "works on"].freeze
    MONTHS = %w[january february march april may june july august september october november december].freeze
    HEADING = /\A\s{0,3}(\#{1,6})\s+(.*?)\s*\#*\s*\z/
    # A version in a heading: "1.2.0", "[1.2.0]", "v2.1", "Version 1.2"
    VERSION_TOKEN = /(?<![\w.\-])\[?v?(\d+(?:\.\d+)+)\]?(?![\w.])/i
    INLINE = /(\*\*|__)(.+?)\1|`([^`]+)`|(?<![\w*])\*(?![\s*])(.+?)(?<![\s*])\*(?![\w*])|(?<![\w_])_(?![\s_])(.+?)(?<![\s_])_(?![\w_])/
    LINK = /\[([^\]]*)\](?:\([^)]*\)|\[[^\]]*\])/
    # What never shows: images, and web addresses (with a scheme, www., or a
    # common ending like discord.gg/...)
    IMAGE = /!\[[^\]]*\](?:\([^)]*\)|\[[^\]]*\])/
    ADDR = %r{(?:\b(?:https?|ftp)://|\bwww\.|\b[a-z0-9-]+(?:\.[a-z0-9-]+)*\.(?:com|net|org|io|gg|me|co|dev|app|xyz|ly|link|info|site|gl|be|tk|us|uk|tv)\b(?=[/:?#]|\s|$|[.,;!)]))(?:[^\s<>()\[\]]*[^\s<>()\[\].,;:!?'"])?}i
    ADDRESS = /[ \t]*(?:\(\s*#{ADDR}\s*\)|#{ADDR})/i
    LINK_DEFINITION = /\A\s{0,3}\[[^\]]+\]:\s*\S+/

    @added = {}         # source => [Version] (from scripts)

    class << self
      # A version's notes from a mod's scripts.
      def add(source, version, notes, date = nil)
        list = (@added[source.to_s] ||= [])
        list.reject! { |v| v.version == version.to_s }
        notes = Array(notes).map { |n| n.is_a?(Array) ? n : [n.to_s, 0] }
        list << Version.new(version.to_s, date && date.to_s, notes, nil, nil, nil, nil, nil, note_blocks(notes))
        return true
      end

      # [{ :name, :versions => [Version] newest first, :current }]
      def sources
        list = []
        list << { :name => KR, :versions => folder_or_file(Reloaded::ROOT), :current => Reloaded.version }
        list << { :name => KIF, :versions => kif_versions, :current => kif_version } if kif_version
        mods.each do |name, folder|
          versions = merge(folder_or_file(folder), @added[name] || [])
          list << { :name => name, :versions => versions, :current => versions.first && versions.first.version } unless versions.empty?
        end
        (@added.keys - list.map { |s| s[:name] }).each do |name|
          list << { :name => name, :versions => sorted(@added[name]), :current => sorted(@added[name]).first.version }
        end
        list.each { |s| first_look(s) }
        return list.reject { |s| s[:versions].empty? }
      end

      # Not yet shown: this version, or any (of a source, or of all).
      def new?(source, version)
        return !seen(source).include?(version.to_s)
      end

      def unseen?(source = nil)
        list = source ? sources.select { |s| s[:name] == source } : sources
        return list.any? { |s| s[:versions].any? { |v| new?(s[:name], v.version) } }
      end

      # Everything shown is no longer new.
      def mark_seen(source = nil)
        data = store
        sources.each do |s|
          next if source && s[:name] != source
          data["seen"][s[:name]] = (Array(data["seen"][s[:name]]) | s[:versions].map(&:version))
        end
        save(data)
      end

      # KIF Beta's version now ("0.21.57"), or nil.
      def kif_version
        return ::KIF::PORT_VERSION.to_s if defined?(::KIF::PORT_VERSION)
        return nil
      end

      # A changelog in one file => [Version], newest first. A version starts
      # at a heading (# to ###) with a version number in its first words
      # ("## 1.2.0 (2026-10-20)", "## [1.2.0] - 2026-10-20" as Keep a
      # Changelog has it, "## v2.1 - Faster Pedals", "## Version 1.2");
      # everything up to the next is its notes. One marked Unreleased is
      # left out.
      def parse(text)
        versions = []
        bodies = []
        skip = false
        text.to_s.each_line do |raw|
          line = raw.rstrip
          if (m = line.match(HEADING)) && (head = version_heading(m[2]))
            skip = head[:unreleased]
            next if skip
            versions << Version.new(head[:version], head[:date], [], nil, head[:name], nil, nil, nil, nil)
            bodies << []
          elsif !skip && !bodies.empty?
            bodies.last << line
          end
        end
        versions.each_with_index do |v, i|
          v.blocks = blocks(bodies[i])
          v.notes = notes_of(v.blocks)
        end
        return sorted(versions)
      rescue StandardError
        return []
      end

      # A Changelogs folder's vX.Y.Z.md => Version, or nil (its Release Date
      # is Unreleased, or it can't be read)
      def parse_release(text, file_name)
        v = Version.new(file_name.to_s[VERSION_FILE, 1], nil, [], nil, nil, nil, nil, [], [])
        body = []
        text.to_s.each_line do |raw|
          line = raw.rstrip
          next if line.strip.empty?
          next if line =~ /\A#\s/ && body.empty?                          # the title
          if body.empty? && (m = line.match(UPDATE_LINE))
            v.update = m[1].to_i
            v.name = m[2].to_s.strip.empty? ? nil : m[2].strip
            v.hotfix = m[3]
          elsif body.empty? && (m = line.match(FIELD)) && HEADER_FIELDS.include?(m[1].strip.downcase)
            value = m[2].strip
            case m[1].strip.downcase
            when "version" then v.version = value.sub(/\Av/i, "") unless value.empty?
            when "release date"
              return nil if value =~ /\Aunreleased/i
              v.date = iso_date(value)
            when "works on" then v.works_on = value
            end
          elsif body.empty? && !v.update && (m = line.match(HEADING)) && (head = version_heading(m[2]))
            # another mod's own version heading ("## 1.0.0 (2026-10-01)"): its date and name
            return nil if head[:unreleased]
            v.date ||= head[:date]
            v.name ||= head[:name]
          else
            body << line
          end
        end
        return nil unless v.version
        v.blocks = blocks(body)
        v.sections = sections_of(v.blocks)
        v.notes = v.sections.flat_map { |_title, lines| lines }
        return v
      rescue StandardError
        return nil
      end

      # The blocks' sub-sections: [[title or nil, [[text, depth]]]]. The top
      # heading level makes the sub-sections (## in his format, ### in
      # others); a heading under one (his features) is a line of its own,
      # its words one level in.
      def sections_of(blocks)
        top = blocks.select { |b| b.kind == :head }.map(&:level).min
        out = []
        under = false
        blocks.each do |b|
          next if b.kind == :rule
          if b.kind == :head && b.level == top
            out << [words(b), []]
            under = false
            next
          end
          out << [nil, []] if out.empty?
          if b.kind == :head
            out.last[1] << [words(b), 0]
            under = true
          else
            out.last[1] << [words(b), under || b.depth.to_i > 0 ? 1 : 0]
          end
        end
        return out
      end

      # Markdown lines => [Block]: headings, bullets (and their depth),
      # numbered lines, quotes, divider lines, a table's rows as their cells,
      # and plain lines; blank lines between them left out
      def blocks(lines)
        out = []
        Array(lines).each do |raw|
          line = raw.to_s.rstrip.gsub("\t", "  ")
          next if line.strip.empty? || line =~ LINK_DEFINITION
          if (m = line.match(HEADING))
            out << Block.new(:head, m[1].length, 0, nil, inline(m[2]))
          elsif line =~ /\A\s{0,3}([-*_])(\s*\1){2,}\s*\z/
            out << Block.new(:rule, nil, 0, nil, [])
          elsif (m = line.match(/\A(\s*)[-*+•]\s+(.*)\z/))
            out << Block.new(:bullet, nil, depth_of(m[1]), nil, inline(m[2]))
          elsif (m = line.match(/\A(\s*)(\d{1,3})[.)]\s+(.*)\z/))
            out << Block.new(:number, nil, depth_of(m[1]), m[2].to_i, inline(m[3]))
          elsif (m = line.match(/\A\s*>\s?(.*)\z/))
            out << Block.new(:quote, nil, 0, nil, inline(m[1])) unless m[1].strip.empty?
          elsif line.strip.start_with?("|")
            next if line =~ /\A[\s|:\-]+\z/                                 # a table's divider row
            cells = line.strip.sub(/\A\|/, "").sub(/\|\z/, "").split("|").map(&:strip)
            out << Block.new(:para, nil, 0, nil, inline(cells.join("   ")))
          else
            out << Block.new(:para, nil, line =~ /\A\s{2,}/ ? 1 : 0, nil, inline(line.strip))
          end
        end
        return out
      end

      # Inline Markdown => [[text, style]]: **bold** and __bold__, *italic*
      # and _italic_, `code`; a [link](address) is only its words, plain;
      # images, web addresses and HTML tags out
      def inline(text)
        text = text.to_s.gsub(/<[^>]+>/, "").gsub(IMAGE, "").gsub(LINK) { $1 }.gsub(ADDRESS, "").strip
        out = []
        pos = 0
        text.scan(INLINE) do
          m = Regexp.last_match
          out << [text[pos...m.begin(0)], :plain] if m.begin(0) > pos
          if m[2] then out << [m[2], :bold]
          elsif m[3] then out << [m[3], :code]
          else out << [m[4] || m[5], :italic]
          end
          pos = m.end(0)
        end
        out << [text[pos..-1], :plain] if pos < text.length
        return out.reject { |t, _s| t.to_s.empty? }
      end

      # A block's words, plain
      def words(block)
        return block.segments.map(&:first).join.strip
      end

      private

      # A mod's versions: its Changelogs folder (Documentation\Changelogs
      # first), else its one Changelog.md
      def folder_or_file(folder)
        dir = [File.join(folder, "Documentation", "Changelogs"), File.join(folder, "Changelogs")].find { |d| File.directory?(d) }
        return folder_versions(dir) if dir
        file = ["Changelog.md", "CHANGELOG.md", "changelog.md"].map { |f| File.join(folder, f) }.find { |f| File.file?(f) }
        return file ? parse(read(file)) : []
      end

      def folder_versions(dir)
        names = (Dir.children(dir) rescue []).select { |f| f =~ VERSION_FILE && File.file?(File.join(dir, f)) }
        return sorted(names.map { |f| parse_release(read(File.join(dir, f)), f) }.compact)
      end

      # Markdown marks out (the screen draws the words)
      def plain(text)
        return inline(text).map(&:first).join.strip
      end

      # A heading with a version: { :version, :name, :date, :unreleased },
      # or nil
      def version_heading(text)
        words = plain(text)
        m = words.match(VERSION_TOKEN)
        return nil unless m && m.begin(0) <= 30
        before = words[0...m.begin(0)].strip
        return nil unless before.empty? || before =~ /\A(?:version|release|ver\.?)\z/i
        date = words[/\d{4}-\d\d-\d\d/] || (words[/[A-Za-z]{3,}\.? \d{1,2},? \d{4}/] && iso_date(words[/[A-Za-z]{3,}\.? \d{1,2},? \d{4}/]))
        rest = words[m.end(0)..-1].to_s.gsub(/\d{4}-\d\d-\d\d|[A-Za-z]{3,}\.? \d{1,2},? \d{4}/, "").gsub(/[()\[\]]/, "")
        name = rest.sub(/\A[\s\-:–—,]+/, "").sub(/[\s\-:–—,]+\z/, "").strip
        name = nil if name.empty? || name =~ /\Aunreleased\z/i
        return { :version => m[1], :name => name, :date => date, :unreleased => (words =~ /unreleased/i ? true : false) }
      end

      def depth_of(indent)
        return [indent.to_s.length / 2, 3].min
      end

      # The notes as [[text, depth]] from the blocks (headings and divider
      # lines left out, as before)
      def notes_of(blocks)
        return blocks.reject { |b| [:head, :rule].include?(b.kind) }.map { |b| [words(b), b.depth.to_i > 0 ? 1 : 0] }
      end

      # [[text, depth]] notes => [Block] bullets
      def note_blocks(notes)
        return Array(notes).map { |text, depth| Block.new(:bullet, nil, depth.to_i, nil, inline(text)) }
      end

      # "October 25, 2026" => "2026-10-25"; anything else as it is
      def iso_date(text)
        m = text.to_s.match(/\A([A-Za-z]{3,})\.?\s+(\d{1,2}),?\s+(\d{4})/)
        month = m ? MONTHS.index { |n| n.start_with?(m[1].downcase) || m[1].downcase.start_with?(n[0, 3]) } : nil
        return text.to_s unless month
        return format("%04d-%02d-%02d", m[3].to_i, month + 1, m[2].to_i)
      end

      def read(file)
        return File.file?(file) ? Reloaded::Paths.read_text(file).to_s : ""
      rescue StandardError
        return ""
      end

      # KIF Beta's notes: the current version's file, and every version
      # kept before it.
      def kif_versions
        data = store
        kept = data["kif"]
        file = File.join(Reloaded::Paths.game_dir, "Data", "KIF", "update_notes.txt")
        if File.file?(file) && kif_version && !kept[kif_version]
          lines = read(file).lines.map(&:strip).reject(&:empty?)
          lines.shift if lines.first.to_s.include?(kif_version)
          kept[kif_version] = { "date" => Time.now.strftime("%Y-%m-%d"),
                                "notes" => lines.map { |l| l.sub(/\A[-*•]\s*/, "") } }
          save(data)
        end
        versions = kept.map do |v, h|
          notes = Array(h["notes"]).map { |n| [n.to_s, 0] }
          Version.new(v, h["date"], notes, nil, nil, nil, nil, nil, note_blocks(notes))
        end
        return sorted(versions)
      end

      # Mods with a folder (KIF's list), but not Kanto Reloaded: [[name, folder]]
      def mods
        return [] unless defined?(::KIF::Mods) && ::KIF::Mods.respond_to?(:entries)
        root = File.expand_path(Reloaded::ROOT)
        return (::KIF::Mods.entries rescue []).select { |e| e.respond_to?(:path) && e.path && File.directory?(e.path.to_s) && (e.enabled? rescue true) }
          .reject { |e| File.expand_path(e.path.to_s) == root }.map { |e| [e.name.to_s, e.path.to_s] }
      end

      def merge(a, b)
        out = a.dup
        b.each { |v| out << v unless out.any? { |x| x.version == v.version } }
        return sorted(out)
      end

      # Newest first (by version number).
      def sorted(list)
        return list.sort_by { |v| v.version.to_s.scan(/\d+/).map(&:to_i) }.reverse
      end

      def seen(source)
        return Array(store["seen"][source.to_s])
      end

      # The first time a source is seen, only its newest version is new.
      def first_look(s)
        data = store
        return if data["seen"].key?(s[:name]) || s[:versions].empty?
        data["seen"][s[:name]] = s[:versions][1..-1].map(&:version)
        save(data)
      end

      def store
        return @store if @store
        file = File.join(Reloaded::Paths.settings_dir, FILE)
        data = File.file?(file) ? (Reloaded::JSON.parse(Reloaded::Paths.read_text(file).to_s) rescue nil) : nil
        data = {} unless data.is_a?(Hash)
        data["seen"] = {} unless data["seen"].is_a?(Hash)
        data["kif"] = {} unless data["kif"].is_a?(Hash)
        return @store = data
      end

      def save(data)
        @store = data
        Reloaded::Paths.write_atomic(File.join(Reloaded::Paths.settings_dir, FILE), Reloaded::JSON.generate(data, true))
      rescue StandardError => e
        Reloaded::Log.exception("What's New couldn't be saved", e, :saves)
      end

      public

      # For tests.
      def reset
        @store = nil
        @added = {}
      end
    end
  end
end
