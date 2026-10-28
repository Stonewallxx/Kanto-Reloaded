#==============================================================================
# Kanto Reloaded: the Timing Profiler's text report
#==============================================================================
# Text Report (On by default): each session is added to
# Logging\TimingProfile.txt as it ends, in old Kanto Reloaded's layout (a table
# of sections), for every kind of session now, not just battles. Past 2 MB
# the file starts again; the last one is kept as TimingProfile.old.txt.
#==============================================================================

module Reloaded
  module Profiler
    module Report
      KIND_NAMES = { "battle" => "Battle", "map" => "Map Load", "menu" => "Menu", "saving" => "Saving",
                     "loading" => "Loading" }.freeze

      class << self
        def path
          return File.join(Reloaded::Paths.logs_dir, REPORT_FILE)
        end

        def append(session)
          file = path
          Reloaded::Paths.ensure_dir(File.dirname(file))
          if File.file?(file) && File.size(file) > REPORT_MAX
            old = file.sub(/\.txt\z/, ".old.txt")
            File.delete(old) if File.file?(old)
            File.rename(file, old)
          end
          File.open(file, "ab") { |f| f.write(render(session)) }
          return true
        rescue StandardError => e
          Reloaded::Log.exception("The timing report couldn't be written", e, :profiler)
          return false
        end

        def render(s)
          limit = (s["slow_limit"] || Profiler.slow_limit).to_f
          lines = []
          lines << "=" * 100
          lines << "KANTO RELOADED TIMING PROFILE: #{KIND_NAMES[s["kind"]] || s["kind"]}, #{s["name"]}"
          lines << "=" * 100
          lines << "Started:     #{s["started"]}"
          lines << format("Elapsed:     %.3f s (work %.3f s, %d frames)", s["elapsed"].to_f, s["work"].to_f, s["frames"].to_i)
          lines << "Where:       #{s["where"]}" if s["where"]
          (s["info"] || {}).each { |k, v| lines << format("%-12s %s", "#{k}:", v) }
          lines << "Error:       #{s["error"]}" if s["error"]
          lines << format("Slow Frame:  %.1f ms", limit * 1000)
          lines << ""
          lines << format("%-30s %-16s %7s %11s %11s %10s %6s", "Section", "Owner", "Calls", "Total ms", "Average ms", "Peak ms", "Slow")
          lines << "-" * 97
          ordered(s).each do |label, x|
            calls = x["calls"].to_i
            avg = calls > 0 ? x["total"].to_f / calls : 0.0
            lines << format("%-30s %-16s %7d %11.3f %11.3f %10.3f %6d", label[0, 30], x["owner"].to_s[0, 16], calls,
                            x["total"].to_f * 1000, avg * 1000, x["peak"].to_f * 1000, x["slow"].to_i)
          end
          lines << ""
          lines << "Notes:"
          lines << "- Times are work: waiting for the next frame (Graphics.update) is left out."
          lines << "- Peak is the most a section did within one frame; Slow counts those over Slow Frame."
          lines << "- Nested sections overlap (Map Setup is inside Map Data Load): don't add them together."
          lines << ""
          return lines.join("\n") + "\n"
        end

        # Mod Timings as the game closed (Profiler.closing): each owner's
        # time per frame and its slowest hooks
        def append_mod_timings(snap)
          File.open(path, "ab") { |f| f.write(render_mod_timings(snap)) }
          return true
        rescue StandardError => e
          Reloaded::Log.exception("Mod Timings couldn't be added to the timing report", e, :profiler)
          return false
        end

        def render_mod_timings(snap)
          fr = snap["frames"] || {}
          lines = ["=" * 100, "KANTO RELOADED TIMING PROFILE: Mod Timings, this play session", "=" * 100]
          lines << format("%-12s %s", "Taken:", snap["taken"])
          lines << format("%-12s %d on the map, %d in battle, %d elsewhere", "Frames:", fr["map"].to_i, fr["battle"].to_i, fr["other"].to_i)
          lines << ""
          lines << format("%-34s %14s %14s", "Owner", "Map ms/frame", "Battle ms/frame")
          lines << "-" * 64
          owners = snap["owners"] || []
          per = proc { |v| v.nil? ? "-" : format("%.3f", v.to_f) }
          owners.each { |o| lines << format("%-34s %14s %14s", o["owner"].to_s[0, 34], per.call(o["map_ms"]), per.call(o["battle_ms"])) }
          lines << ""
          lines << format("%-58s %7s %10s %9s %5s", "Slowest Hooks (by Peak)", "Calls", "Total ms", "Peak ms", "Slow")
          lines << "-" * 93
          owners.each do |o|
            (o["hooks"] || []).each do |h|
              label = "#{o["owner"]}: #{h["hook"]}"
              lines << format("%-58s %7d %10.1f %9.1f %5d", label[0, 58], h["calls"].to_i, h["total_ms"].to_f, h["peak_ms"].to_f, h["slow"].to_i) +
                       (h["where"] ? "  (#{h["where"]})" : "")
            end
          end
          lines << ""
          lines << "Notes:"
          lines << "- A hook's time is its own: the layers it calls are taken off, and so is waiting for the next frame."
          lines << "- \"PIF and KIF\" is the game's frame work less every mod's."
          lines << ""
          return lines.join("\n") + "\n"
        end

        # Slowest peak first, Frame Work last.
        def ordered(s)
          list = s["sections"].to_a
          frame, rest = list.partition { |label, _| label == FRAME_WORK }
          return rest.sort_by { |_l, x| -x["peak"].to_f } + frame
        end
      end
    end
  end
end
