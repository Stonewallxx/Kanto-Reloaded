# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the tests' work folders
#==============================================================================
# Every test and preview takes its work folder through KRWork.claim, and none
# ever clears one: the folder must be new, or completely empty (a preview's
# may hold its metrics.json). Anything else stops the run before a single
# file is touched, so a game, mod or project folder passed by mistake is left
# as it is. Tools/Tests/run_all.rb gives every suite a new folder of its own.
#==============================================================================
require "fileutils"

module KRWork
  # The folder at path, made when it's new. Stops the run when the folder
  # holds anything but the names in allow.
  def self.claim(path, allow = [])
    abort("No work folder given. #{usage}") if path.to_s.strip.empty?
    dir = File.expand_path(path.to_s)
    abort("The work folder #{dir} is a file. #{usage}") if File.exist?(dir) && !File.directory?(dir)
    if File.directory?(dir)
      extra = Dir.children(dir) - allow
      unless extra.empty?
        shown = extra.first(3).join(", ") + (extra.length > 3 ? ", ..." : "")
        abort("The work folder #{dir} isn't empty (#{shown}). Tests never clear a folder: " \
              "give a new or empty one. #{usage}")
      end
    else
      FileUtils.mkdir_p(dir)
    end
    return dir
  end

  # The running script's Usage line, for the messages above.
  def self.usage
    line = File.foreach($0).find { |l| l.start_with?("# Usage") }
    return line ? line.sub(/^#\s*/, "").strip : ""
  rescue StandardError
    return ""
  end
end
