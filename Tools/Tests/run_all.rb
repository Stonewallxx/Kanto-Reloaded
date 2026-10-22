# encoding: utf-8
#==============================================================================
# Kanto Reloaded: every test and preview, each given what its own Usage line
# asks for
#==============================================================================
# Usage: ruby Tools/Tests/run_all.rb "<KIF Beta>" [part of a name ...]
#
# Each suite gets a new folder of its own inside this run's folder (made in
# the system's temp folder): an empty one for "<empty temp folder>", one
# holding metrics.json for "<work dir with metrics.json>". The KIF Beta folder
# is passed only where a suite's Usage line names it. A suite whose Usage
# line reads any other way is skipped, never guessed at. Nothing is deleted;
# the run's folder is printed at the end (python Tools/UIPreview/render.py
# draws a preview's states from its folder).
#==============================================================================
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"

KR = File.expand_path("../..", __dir__)
abort("Usage: ruby Tools/Tests/run_all.rb \"<KIF Beta>\" [part of a name ...]") if ARGV.empty?
KIF = File.expand_path(ARGV[0])
unless File.directory?(File.join(KIF, "Data", "Scripts")) && File.file?(File.join(KIF, "Mods", "KantoReloaded", "mod.json"))
  abort("#{KIF} isn't KIF Beta with Kanto Reloaded in its Mods folder (no Data\\Scripts or Mods\\KantoReloaded\\mod.json).")
end
ONLY = ARGV[1..-1]
RUBY = RbConfig.ruby

# Each suite and the inputs its Usage line names, in order
def inputs(path)
  if File.basename(path) == "preview.rb"
    return [:kif, :work]
  end
  line = File.foreach(path).find { |l| l.start_with?("# Usage:") }
  return nil unless line
  words = line.sub(/^# Usage:\s*ruby\s+\S+\s*/, "").scan(/"[^"]*"|<[^>]*>|\[[^\]]*\]|\S+/)
  words.reject { |w| w.start_with?("[") }.map do |w|
    case w
    when /KIF Beta/ then :kif
    when /empty temp folder/ then :empty
    when /work dir with metrics\.json/ then :work
    else return nil
    end
  end
end

suites = Dir.glob(File.join(KR, "Tools", "Tests", "*_{test,preview}.rb")).sort
suites += Dir.glob(File.join(KR, "Dev", "Tests", "*_{test,preview}.rb")).sort
suites << File.join(KR, "Tools", "UIPreview", "preview.rb")
# a suite is asked for by its file's name, or the name the run shows
# (Tools/UIPreview/preview.rb runs as main_preview)
shown = proc { |s| s.end_with?("Tools/UIPreview/preview.rb") ? "main_preview" : File.basename(s, ".rb") }
suites.select! { |s| ONLY.empty? || ONLY.any? { |o| File.basename(s).include?(o) || shown.call(s).include?(o) } }
abort("No suite's name has #{ONLY.join(" or ")} in it.") if suites.empty?

run = Dir.mktmpdir("kr-tests-")
metrics = nil
failed = 0
suites.each do |path|
  rel = path.sub(KR + "/", "")
  name = File.basename(path, ".rb")
  name = "main_preview" if rel == "Tools/UIPreview/preview.rb"
  shape = inputs(path)
  unless shape
    puts "#{name}: skipped (its Usage line doesn't say what it takes)"
    failed += 1
    next
  end
  dir = File.join(run, name)
  args = shape.map do |kind|
    case kind
    when :kif then KIF
    when :empty then dir
    when :work
      unless metrics
        metrics = File.join(run, "metrics.json")
        out, status = Open3.capture2e("python", File.join(KR, "Tools", "UIPreview", "metrics.py"), File.join(KIF, "Fonts"), metrics)
        abort("metrics.py failed:\n#{out}") unless status.success? && File.file?(metrics)
      end
      FileUtils.mkdir_p(dir)
      FileUtils.cp(metrics, File.join(dir, "metrics.json"))
      dir
    end
  end
  out, status = Open3.capture2e(RUBY, path, *args, :chdir => KR)
  File.write(File.join(run, "#{name}.txt"), out)    # every suite's whole output, kept with the run
  lines = out.lines.map(&:chomp)
  oks = lines.count { |l| l.start_with?("ok") }
  fails = lines.select { |l| l.start_with?("FAIL") }
  good = status.success? && fails.empty? && lines.any? { |l| l.include?("ALL CHECKS PASSED") }
  failed += 1 unless good
  puts "#{name}: #{oks} ok, #{fails.length} failed#{good ? "" : " (exit #{status.exitstatus}): #{lines.last}"}"
  fails.first(5).each { |l| puts "    #{l}" }
end
puts
puts failed.zero? ? "Every suite passed." : "#{failed} suite#{failed == 1 ? "" : "s"} didn't pass."
puts "This run's folders: #{run}"
exit(failed.zero? ? 0 : 1)
