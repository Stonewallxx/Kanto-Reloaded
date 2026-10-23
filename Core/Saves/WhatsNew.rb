#==============================================================================
# Kanto Reloaded: What's New (the notes of each version)
#==============================================================================
# The What's New screen's sources, each with its versions and their notes:
#
#   Kanto Reloaded   Changelog.md in its folder
#   KIF Beta         Data\KIF\update_notes.txt (KIF ships only the current
#                    version's, so each one is kept as it arrives, in
#                    Kanto Reloaded\Whats New.json)
#   a mod            Changelog.md (or CHANGELOG.md) in its folder, or its
#                    scripts: Reloaded::WhatsNew.add("My Mod", "1.2.0",
#                    ["A note", "Another"], "2026-10-20")
#
# A Changelog.md:
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
    Version = Struct.new(:version, :date, :notes)       # notes: [[text, depth]]

    @added = {}         # source => [Version] (from scripts)

    class << self
      # A version's notes from a mod's scripts.
      def add(source, version, notes, date = nil)
        list = (@added[source.to_s] ||= [])
        list.reject! { |v| v.version == version.to_s }
        list << Version.new(version.to_s, date && date.to_s, Array(notes).map { |n| n.is_a?(Array) ? n : [n.to_s, 0] })
        return true
      end

      # [{ :name, :versions => [Version] newest first, :current }]
      def sources
        list = []
        list << { :name => KR, :versions => parse(read(File.join(Reloaded::ROOT, "Changelog.md"))), :current => Reloaded.version }
        list << { :name => KIF, :versions => kif_versions, :current => kif_version } if kif_version
        mods.each do |name, folder|
          file = ["Changelog.md", "CHANGELOG.md", "changelog.md"].map { |f| File.join(folder, f) }.find { |f| File.file?(f) }
          versions = file ? parse(read(file)) : []
          versions = merge(versions, @added[name] || [])
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

      # Markdown changelog text => [Version], newest first.
      def parse(text)
        versions = []
        text.to_s.each_line do |line|
          line = line.rstrip
          if (m = line.match(/\A\#{2,3}\s+(?:Version\s+)?v?(\d[\w.\-]*)\s*(?:\(([^)]*)\))?/i))
            versions << Version.new(m[1], m[2], [])
          elsif versions.last && (m = line.match(/\A(\s*)[-*•]\s+(.*)\z/))
            versions.last.notes << [m[2].strip, m[1].length >= 2 ? 1 : 0]
          elsif versions.last && !line.strip.empty? && !line.start_with?("#")
            versions.last.notes << [line.strip, 0]
          end
        end
        return sorted(versions)
      end

      private

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
        versions = kept.map { |v, h| Version.new(v, h["date"], Array(h["notes"]).map { |n| [n.to_s, 0] }) }
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
