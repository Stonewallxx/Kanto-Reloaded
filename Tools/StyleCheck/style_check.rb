# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Style Checker
#==============================================================================
# Checks a mod's player-facing text against Kanto Reloaded's house rules
# (Roadmap topic 39). Ships with Kanto Reloaded so mod makers can check
# their own mods; the Release Builder runs it before every release.
#
#   Capital After a Colon     "Opens the Ready Menu: The key items..."
#   Title Case Labels         setting names, choices, buttons and hints;
#                             connecting words (a, an, and, as, at, by,
#                             for, in, of, on, or, the, to...) lowercase
#                             unless first
#   Spelling: Color           Color, as the setting names say it
#   Official Names            Speed-Up, Pokédex, Wild Link... as written
#   No Double Spaces
#   Labels Without a Period
#   No Keyboard-Only Hints    no "Press Enter": controller players have none
#
# What's player-facing: _INTL("...") text, and :name, :description,
# :values (and the like) in settings, pages, features and actions. Tools,
# Dev and Tests folders are left out, and so are the folders a mod writes
# for itself (Settings, Logging: this checker's own backups, Bug Reports).
#
# Usage (from anywhere):
#   ruby Tools/StyleCheck/style_check.rb [<mod folder>] [--fix] [--out <folder>]
#     <mod folder>  the mod to check (Kanto Reloaded's own folder if left out)
#     --fix         Fix It for Me: each fix in turn, before and after, then
#                   Y Fix, N Skip, I Ignore from now on, A Fix all of this
#                   rule, Q Stop. Changed files are backed up first.
#     --out         where the report and the backups go (Kanto Reloaded's
#                   Logging\Style Checks folder if left out)
# The report: <out>/Style Check <mod name>.md. Exit status 0 when nothing was
# found, 1 when something was, 2 for a usage error.
#
# The mod's style_check.json keeps its Ignore List (a false positive marked
# once stops showing) and more official names:
#   { "ignore": [{ "rule": "title_case", "file": "Core/UI/ControlsScreen.rb",
#                  "text": "Swap A and B" }],
#     "names": { "Pokégear": ["Pokegear"] } }
#==============================================================================

require "json"
require "fileutils"

module StyleCheck
  # rule => [name, what it asks for]
  RULES = {
    :colon      => ["Capital After a Colon", "A capital letter right after a colon."],
    :title_case => ["Title Case Labels", "Labels (setting names, choices, buttons, hints) in Title Case. Connecting words (a, an, and, as, at, but, by, for, in, nor, of, on, or, the, to, vs, with) stay lowercase unless they come first."],
    :color      => ["Spelling: Color", "Setting names say Color (Header Color, Settings Color, Cursor Color), so the text should too."],
    :names      => ["Official Names", "Feature names as they are written: Speed-Up, Pokédex, Wild Link and the rest."],
    :double     => ["No Double Spaces", "One space between words."],
    :period     => ["Labels Without a Period", "A label (a setting's name, a choice) doesn't end in a period."],
    :keyboard   => ["No Keyboard-Only Hints", "Name the action, not a keyboard key: controller players have no Enter or Esc, and the hint line already shows each player's own buttons."]
  }.freeze
  SMALL = %w[a an and as at but by for in nor of on or the to vs with].freeze
  NAMES = {
    "Speed-Up"       => ["Speed Up", "Speedup", "SpeedUp"],
    "Pokédex"        => ["Pokedex", "PokeDex", "PokéDex"],
    "Pokémon"        => ["Pokemon"],
    "Poké Ball"      => ["Pokeball", "PokeBall", "Poke Ball", "Pokéball"],
    "Wild Link"      => ["WildLink", "Wild link"],
    "Kanto Reloaded" => ["Kanto reloaded", "KantoReloaded"]
  }.freeze
  SKIP_DIRS = %w[Tools Dev Tests .git Settings Logging Bug\ Reports].freeze
  STRING = '"((?:[^"\\\\]|\\\\.)*)"'
  LABEL_KEYS = %w[name].freeze
  TEXT_KEYS = %w[description desc needs_text text help].freeze
  # Lines whose strings are for the log, an error or the console, not the player
  CODE_LINE = /\bLog\.\w+|\braise\b|\bwarn\b|\bputs\b|\bprint\b|KIF\.log|\breport\(|\brequire\b|\bload\b|\$log\b|\.log\(/
  KEYBOARD = /\b(press|hold|hit|tap|use)\s+(the\s+)?(Enter|Esc|Escape|Shift|Ctrl|Alt|Tab|Space(bar)?|Backspace)\b|\b(Enter|Esc|Escape|Shift|Ctrl|Alt|Tab|Backspace)\s+key\b/i

  # A piece of player-facing text. kind: :label (a name, a choice, a short
  # _INTL label) or :text; raw: as written between the quotes.
  Text = Struct.new(:kind, :file, :line, :raw)

  # One problem. fixer: the fix for a string (nil when there's no automatic
  # one).
  Finding = Struct.new(:rule, :file, :line, :raw, :fixer) do
    def fix(raw = self.raw)
      return fixer ? fixer.call(raw) : nil
    end
  end

  class << self
    #--------------------------------------------------------------------------
    # Reading the mod
    #--------------------------------------------------------------------------
    # Every piece of player-facing text in the mod's Ruby files.
    def texts(root)
      out = []
      Dir.glob(File.join(root, "**", "*.rb")).sort.each do |path|
        rel = relative(root, path)
        next if rel.split("/")[0...-1].any? { |d| SKIP_DIRS.include?(d) }
        File.read(path, :encoding => "UTF-8").split("\n").each_with_index do |line, i|
          next if line.strip.start_with?("#")
          texts_in(line).each { |kind, raw| out << Text.new(kind, rel, i + 1, raw) }
        end
      end
      return out
    end

    # [[kind, raw], ...] on one line of code.
    def texts_in(line)
      found = []
      line.scan(/(?::(\w+)\s*=>|\b(\w+):)\s*#{STRING}/) do |k1, k2, raw|
        key = k1 || k2
        found << [:label, raw] if LABEL_KEYS.include?(key)
        found << [:text, raw] if TEXT_KEYS.include?(key)
      end
      line.scan(/(?::values\s*=>|\bvalues:)\s*\[([^\]]*)\]/) do |(list)|
        list.scan(/#{STRING}/) { |(raw)| found << [:label, raw] unless raw =~ /\d/ }
      end
      line.scan(/_INTL\(\s*#{STRING}/) { |(raw)| found << [label_like?(raw) ? :label : :text, raw] }
      # text in data tables (an action's name and description in an array):
      # any other string that reads as text, on a line that isn't logging
      # or raising
      unless line =~ CODE_LINE
        seen = found.map { |_k, r| r }
        line.scan(/#{STRING}/) do |(raw)|
          next if seen.include?(raw) || !table_text?(raw)
          found << [label_like?(raw) ? :label : :text, raw]
        end
      end
      return found.uniq
    end

    # A string in a table that reads as text: a capital first, letters in
    # it, no code in it (#{...}, paths, file names).
    def table_text?(s)
      return false unless s =~ /\A\p{Lu}/ && s =~ /\p{Ll}/
      return false if s.include?("\#{") || s =~ %r{[/\\]} || s =~ /\.\w{1,4}\z/ || s =~ /\A\w+\z/ && s =~ /_/
      return true
    end

    # A short _INTL string that reads as a label: a capital first, one to
    # five words, no sentence punctuation, no placeholders. Pieces of a
    # sentence put together in code start in lowercase and aren't labels.
    def label_like?(s)
      return false if s.include?("{") || s.include?("#")
      return false if s =~ /[.!?,;]/
      return false unless s =~ /\A\p{Lu}/
      return s.split(/\s+/).length.between?(1, 5)
    end

    def relative(root, path)
      r = File.expand_path(root).tr("\\", "/")
      p = File.expand_path(path).tr("\\", "/")
      return p.start_with?(r + "/") ? p[(r.length + 1)..-1] : p
    end

    #--------------------------------------------------------------------------
    # The rules
    #--------------------------------------------------------------------------
    # Every finding, in the rules' order, then file and line.
    def check(root, config = {})
      names = NAMES.merge(config["names"] || {})
      findings = []
      texts(root).each do |t|
        s = t.raw
        if s =~ /(?<!:):\s+\p{Ll}/ && s !~ %r{://}
          findings << Finding.new(:colon, t.file, t.line, s, method(:fix_colon))
        end
        if t.kind == :label && fix_title(s) != s
          findings << Finding.new(:title_case, t.file, t.line, s, method(:fix_title))
        end
        if s =~ /colour/i
          findings << Finding.new(:color, t.file, t.line, s, method(:fix_color))
        end
        names.each do |official, variants|
          Array(variants).each do |v|
            next unless s =~ name_pattern(v)
            findings << Finding.new(:names, t.file, t.line, s, proc { |x| x.gsub(name_pattern(v), official) })
          end
        end
        if s =~ /\S {2,}\S/
          findings << Finding.new(:double, t.file, t.line, s, proc { |x| x.gsub(/(\S) {2,}(?=\S)/, '\1 ') })
        end
        if t.kind == :label && s =~ /[^.]\.\z/                 # one period, not "..."
          findings << Finding.new(:period, t.file, t.line, s, proc { |x| x.sub(/\.\z/, "") })
        end
        if s =~ KEYBOARD
          findings << Finding.new(:keyboard, t.file, t.line, s, nil)
        end
      end
      order = RULES.keys
      return findings.uniq { |f| [f.rule, f.file, f.line, f.raw] }.sort_by { |f| [order.index(f.rule), f.file, f.line] }
    end

    def name_pattern(variant)
      return /(?<![\p{L}\-])#{Regexp.escape(variant)}(?![\p{L}\-])/
    end

    def fix_colon(s)
      return s.gsub(/(?<!:)(:\s+)(\p{Ll})/) { "#{$1}#{$2.upcase}" }
    end

    def fix_color(s)
      return s.gsub(/COLOUR/, "COLOR").gsub(/([Cc])olour/, '\1olor')
    end

    # Title Case: every word's first letter a capital, connecting words
    # lowercase unless first (or right after a colon); words in capitals
    # (KIF, EBDX) stay as they are.
    def fix_title(s)
      out = s.dup
      first = true
      out.gsub!(/[\p{L}][\p{L}'’]*/) do |w|
        before = $~.pre_match
        lead = first || before =~ /:\s*\z/
        first = false
        if !lead && SMALL.include?(w.downcase)
          w.downcase
        elsif w =~ /\A\p{Ll}/
          w[0].upcase + w[1..-1]
        else
          w
        end
      end
      return out
    end

    #--------------------------------------------------------------------------
    # The Ignore List
    #--------------------------------------------------------------------------
    def config_path(root)
      return File.join(root, "style_check.json")
    end

    def load_config(root)
      path = config_path(root)
      return {} unless File.file?(path)
      data = JSON.parse(File.read(path, :encoding => "UTF-8"))
      return data.is_a?(Hash) ? data : {}
    rescue JSON::ParserError => e
      warn "style_check.json couldn't be read (#{e.message}); checking without it"
      return {}
    end

    def save_config(root, config)
      File.binwrite(config_path(root), JSON.pretty_generate(config) + "\n")      # LF, as the repo keeps it
    end

    def ignored?(config, f)
      return Array(config["ignore"]).any? do |i|
        i["rule"].to_s == f.rule.to_s && i["text"] == f.raw && (i["file"].nil? || i["file"] == f.file)
      end
    end

    def ignore!(config, f)
      (config["ignore"] ||= []) << { "rule" => f.rule.to_s, "file" => f.file, "text" => f.raw }
    end

    #--------------------------------------------------------------------------
    # The report (By Rule)
    #--------------------------------------------------------------------------
    def report(root, findings, ignored, texts)
      mod = mod_info(root)
      labels = texts.count { |t| t.kind == :label }
      out = []
      out << "# Style Check: #{mod["name"]} #{mod["version"]}"
      out << ""
      out << "#{texts.length} player-facing strings checked (#{texts.length - labels} text, #{labels} labels). #{Time.now.strftime("%Y-%m-%d %H:%M")}."
      out << ""
      out << "| Rule | Found |"
      out << "|---|---|"
      RULES.each { |id, (name, _)| out << "| #{name} | #{findings.count { |f| f.rule == id }} |" }
      out << "| Ignored | #{ignored.length} |"
      out << ""
      if findings.empty?
        out << "Nothing to fix."
        out << ""
      end
      RULES.each do |id, (name, what)|
        list = findings.select { |f| f.rule == id }
        next if list.empty?
        out << "## #{name}"
        out << ""
        out << what
        out << ""
        list.each do |f|
          out << "### #{f.file}:#{f.line}"
          out << ""
          out << "- **Text:** #{f.raw}"
          out << (f.fix ? "- **Fix:** #{f.fix}" : "- **Fix:** By hand: #{RULES[f.rule][1]}")
          out << ""
        end
      end
      unless ignored.empty?
        out << "## Ignored"
        out << ""
        out << "#{ignored.length} on the Ignore List (style_check.json):"
        out << ""
        ignored.each { |f| out << "- #{RULES[f.rule][0]}: \"#{f.raw}\" (#{f.file}:#{f.line})" }
        out << ""
      end
      return out.join("\n") + "\n"
    end

    def mod_info(root)
      data = JSON.parse(File.read(File.join(root, "mod.json"), :encoding => "UTF-8")) rescue {}
      return { "name" => data["name"] || File.basename(File.expand_path(root)), "version" => data["version"] || "" }
    end

    # Kanto Reloaded's Logging\Style Checks (reports and fix backups from
    # before it, loose in Logging, moved in)
    def default_out
      logs = File.join(File.expand_path("../..", __dir__), "Logging")
      base = File.join(logs, "Style Checks")
      FileUtils.mkdir_p(base) rescue nil
      return Dir.pwd unless File.directory?(base)
      Dir.children(logs).each do |n|
        next unless n.start_with?("Style Check ", "Style Fixes ")
        to = File.join(base, n)
        File.rename(File.join(logs, n), to) unless File.exist?(to)
      end
      return base
    rescue StandardError
      return base && File.directory?(base) ? base : Dir.pwd
    end

    def report_path(out, root)
      return File.join(out, "Style Check #{mod_info(root)["name"]}.md")
    end

    # Checks the mod and writes the report: [findings, ignored, report path].
    def run(root, out)
      config = load_config(root)
      all = check(root, config)
      ignored, findings = all.partition { |f| ignored?(config, f) }
      FileUtils.mkdir_p(out)
      path = report_path(out, root)
      File.write(path, report(root, findings, ignored, texts(root)))
      return [findings, ignored, path]
    end

    #--------------------------------------------------------------------------
    # Fix It for Me (One at a Time)
    #--------------------------------------------------------------------------
    # Each fix in turn: the rule, the file and line, the line before and
    # after; then Y Fix, N Skip, I Ignore from now on, A Fix all of this
    # rule, Q Stop. input: where the answers come from; io: where it writes.
    def fix_it(root, out, input = $stdin, io = $stdout)
      config = load_config(root)
      all = check(root, config)
      ignored_before, findings = all.partition { |f| ignored?(config, f) }
      fixes = findings.select(&:fix)
      mod = mod_info(root)
      c = Colors.new(io)
      io.puts "#{c.bold("#{mod["name"]} Style Checker")}   #{c.dim("Fix It for Me")}"
      io.puts c.dim("#{short_root(root)}   #{fixes.length} fix#{fixes.length == 1 ? "" : "es"}, #{ignored_before.length} ignored")
      by_hand = findings.length - fixes.length
      io.puts c.dim("#{by_hand} more to fix by hand: see the report") if by_hand > 0
      io.puts
      backup = File.join(out, "Style Fixes #{Time.now.strftime("%Y-%m-%d %H-%M")}")
      current = {}            # [file, line, raw as found] => raw as it is now
      fixed = []
      skipped = []
      new_ignores = 0
      all_of = {}
      stop = false
      fixes.each_with_index do |f, i|
        if stop
          skipped << f
          next
        end
        key = [f.file, f.line, f.raw]
        before = current[key] || f.raw
        after = f.fix(before)
        next if after == before                      # an earlier fix already did it
        answer = all_of[f.rule] ? "a" : nil
        unless answer
          io.puts "#{c.dim("#{i + 1} of #{fixes.length}")}  #{c.yellow_bold(RULES[f.rule][0])}"
          io.puts c.blue("#{f.file.tr("/", "\\")}:#{f.line}")
          io.puts
          io.puts "  #{c.red("- #{before}")}"
          io.puts "  #{c.green("+ #{after}")}"
          io.puts
          rest = fixes[i..-1].count { |x| x.rule == f.rule }
          io.puts c.yellow("[Y] Fix   [N] Skip   [I] Ignore from now on   [A] Fix all #{rest} #{short_rule(f.rule)}   [Q] Stop")
          answer = ask(input, io)
          io.puts
        end
        case answer
        when "y", "a"
          all_of[f.rule] = true if answer == "a"
          if apply(root, backup, f, before, after)
            current[key] = after
            fixed << f
          else
            skipped << f
          end
        when "i"
          ignore!(config, f)
          new_ignores += 1
        when "q"
          skipped << f
          stop = true
        else
          skipped << f
        end
      end
      save_config(root, config) if new_ignores > 0
      FileUtils.mkdir_p(out)
      _f, _i, path = run(root, out)
      changed = fixed.map(&:file).uniq
      io.puts c.green_bold("Done.")
      io.puts
      io.puts "  Fixed     #{c.green(fixed.length.to_s)}"
      line = "  Skipped   #{c.yellow(skipped.length.to_s)}"
      line += "   " + c.dim("#{skipped.map { |s| "#{File.basename(s.file)}:#{s.line}" }.join(", ")} (you'll see #{skipped.length == 1 ? "it" : "them"} next time)") unless skipped.empty?
      io.puts line
      io.puts "  Ignored   #{c.dim("#{new_ignores} new")}"
      io.puts
      unless changed.empty?
        io.puts "  Changed   #{changed.map { |x| File.basename(x) }.join(", ")}"
        io.puts "  Backup    #{c.blue("#{short_out(backup)}\\ (the #{changed.length == 1 ? "file" : "#{changed.length} files"} as #{changed.length == 1 ? "it was" : "they were"})")}"
      end
      io.puts "  Report    #{c.blue(short_out(path))}"
      return { :fixed => fixed, :skipped => skipped, :ignored => new_ignores, :changed => changed, :backup => backup, :report => path }
    end

    def ask(input, io)
      loop do
        io.print "> "
        line = input.gets
        return "q" if line.nil?
        a = line.strip.downcase[0]
        return a if %w[y n i a q].include?(a)
        io.puts "Y, N, I, A or Q."
      end
    end

    # Changes the string on its line (the file backed up first). False when
    # the line no longer has it.
    def apply(root, backup, f, before, after)
      path = File.join(root, f.file)
      data = File.binread(path).force_encoding("UTF-8")
      lines = data.split(/(?<=\n)/)
      line = lines[f.line - 1]
      return false unless line && line.include?("\"#{before}\"")
      dest = File.join(backup, f.file)
      unless File.file?(dest)
        FileUtils.mkdir_p(File.dirname(dest))
        FileUtils.cp(path, dest)
      end
      lines[f.line - 1] = line.sub("\"#{before}\"") { "\"#{after}\"" }
      File.binwrite(path, lines.join)
      return true
    end

    def short_rule(rule)
      return { :colon => "Colon", :title_case => "Title Case", :color => "Color", :names => "Name", :double => "Double Space",
               :period => "Period", :keyboard => "Keyboard" }[rule]
    end

    def short_root(root)
      parts = File.expand_path(root).tr("/", "\\").split("\\")
      return parts.last(3).join("\\")
    end

    def short_out(path)
      p = File.expand_path(path).tr("/", "\\")
      i = p.index("\\Logging\\")
      return i ? p[(i + 1)..-1] : p
    end

    def main(argv)
      root = nil
      out = nil
      fix = false
      args = argv.dup
      until args.empty?
        a = args.shift
        case a
        when "--fix" then fix = true
        when "--out" then out = args.shift
        when "-h", "--help"
          puts File.read(__FILE__, :encoding => "UTF-8")[/# Usage.*?(?=\n# The mod's)/m].gsub(/^# ?/, "")
          return 0
        else
          return usage("unknown option #{a}") if a.start_with?("--")
          root = a
        end
      end
      root ||= File.expand_path(File.join(File.dirname(__FILE__), "..", ".."))
      return usage("#{root} has no mod.json") unless File.file?(File.join(root, "mod.json"))
      out ||= default_out
      if fix
        result = fix_it(root, out)
        return result[:skipped].empty? && check(root, load_config(root)).reject { |f| ignored?(load_config(root), f) }.empty? ? 0 : 1
      end
      findings, ignored, path = run(root, out)
      shown = File.expand_path(path)
      shown = shown.tr("/", "\\") if File::ALT_SEPARATOR
      puts "#{mod_info(root)["name"]}: #{findings.length} to fix, #{ignored.length} ignored. Report: #{shown}"
      RULES.each do |id, (name, _)|
        n = findings.count { |f| f.rule == id }
        puts "  #{name}: #{n}" if n > 0
      end
      return findings.empty? ? 0 : 1
    end

    def usage(problem)
      warn "Style Checker: #{problem}"
      warn "Usage: ruby Tools/StyleCheck/style_check.rb [<mod folder>] [--fix] [--out <folder>]"
      return 2
    end
  end

  # Colours in the terminal, when it is one.
  class Colors
    def initialize(io)
      @on = io.respond_to?(:tty?) && io.tty? && !ENV["NO_COLOR"]
    end

    def paint(code, text)
      return text unless @on
      return "\e[#{code}m#{text}\e[0m"
    end

    def bold(t); paint("1", t); end
    def dim(t); paint("90", t); end
    def red(t); paint("31", t); end
    def green(t); paint("32", t); end
    def green_bold(t); paint("1;32", t); end
    def yellow(t); paint("33", t); end
    def yellow_bold(t); paint("1;33", t); end
    def blue(t); paint("36", t); end
  end
end

exit(StyleCheck.main(ARGV)) if __FILE__ == $0
