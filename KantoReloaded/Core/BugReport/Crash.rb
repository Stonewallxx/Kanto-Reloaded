#==============================================================================
# Kanto Reloaded: After a Crash
#==============================================================================
# When the game crashes, PIF's main loop calls pbPrintException, which logs
# the error (errorlog.txt; KIF adds KIF_errorlog.txt and its session log)
# and shows a message box before the game closes. Kanto Reloaded wraps it
# (on the game's top-level object, where the main loop calls it):
#
#   1. the error is logged as before, but PIF's box is held back
#   2. Something Went Wrong (in <the mod its code is in>), the error, and
#      that the last save is safe: Make a Bug Report or Close the Game
#   3. Make a Bug Report saves the report (with a screenshot of that moment)
#      and Report Made says where to send it
#
# If anything of ours fails, PIF's own box shows as it always did.
#
# A crash that kills the game outright (no error to catch) is found on the
# next start: Session.json says the last session never ended. Either way,
# the next start offers a report once, over the Load Screen: The Game
# Closed Unexpectedly, Make a Bug Report or Not Now.
#==============================================================================

module Reloaded
  module BugReport
    module Crash
      SESSION = "Session.json".freeze
      LAST = "Last Crash.json".freeze

      class << self
        attr_reader :previous

        def install
          @previous = read(SESSION)
          @where = nil
          write_session(true)
          at_exit { Reloaded::BugReport::Crash.clean_exit }
          # at_exit only runs on Kernel#exit; closing the window raises
          # SystemExit out of the next engine call instead. KIF's session log
          # finishes on every normal way out (the window, quitting, a soft
          # reset, an update), so the session ends with it.
          if defined?(::KIF::SessionLog) && ::KIF::SessionLog.respond_to?(:finish)
            Reloaded::Hooks.around(nil, ::KIF::SessionLog.singleton_class, :finish, :id => :bug_report_clean_exit) do |original, *args|
              begin
                original.call(*args)
              ensure
                Reloaded::BugReport::Crash.clean_exit
              end
            end
          end
          main = TOPLEVEL_BINDING.receiver
          if main.respond_to?(:pbPrintException, true)
            Reloaded::Hooks.around(nil, main.singleton_class, :pbPrintException, :id => :bug_report_crash) do |original, e|
              Reloaded::BugReport::Crash.handle(original, e)
            end
          end
          # KIF's own load screen: the offer comes as the title screen opens
          Reloaded::Events.on(:title_screen, :bug_report_offer, 90) do
            Reloaded::BugReport::Crash.offer_pending unless Reloaded::Saves.load_screen?
          end
          return true
        end

        # The game is closing normally.
        def clean_exit
          write_session(false)
        rescue StandardError
          nil
        end

        # Where the player is now (Recent Steps tells us).
        def where_now(name)
          @where = name
          write_session(true)
        end

        #----------------------------------------------------------------------
        # The crash
        #----------------------------------------------------------------------
        def handle(original, e)
          shot = (Graphics.snap_to_bitmap rescue nil)
          info = describe(e)
          Trail.add(:crash, info["error"])
          save_json(LAST, info.merge("reported" => false, "offered" => true))
          quiet_print { original.call(e) }
          shown = begin
                    after_crash(info, shot)
                    true
                  rescue Exception => ex
                    raise if Reloaded::Hooks.passthrough?(ex)
                    Reloaded::Log.exception("After a Crash didn't show", ex, :bug_report)
                    false
                  end
          show_pif_box unless shown
          return nil
        ensure
          shot.dispose if shot && !(shot.disposed? rescue true)
        end

        # { "error", "class", "where" (file:line), "owner", "mod" (a mod's
        # name, when its code is where it went wrong), "map", "battle",
        # "backtrace", "time" }
        def describe(e)
          bt = Array(e.backtrace).map(&:to_s)
          owners = defined?(Reloaded::Profiler::Owners) ? Reloaded::Profiler::Owners : nil
          owner = nil
          where = bt.first.to_s
          bt.first(12).each do |line|
            file = line[/\A(.+?):\d+/, 1]
            o = owners ? owners.of(file) : nil
            next if o.nil? || owners.game?(o)
            owner = o
            where = line
            break
          end
          owner ||= owners ? owners.of(bt.first.to_s[/\A(.+?):\d+/, 1]) : nil
          mod = owner && owners && owners.mod?(owner) ? owner : nil
          return { "time" => Time.now.to_i, "error" => "#{e.class}: #{e.message}"[0, 300], "class" => e.class.name.to_s,
                   "where" => short(where), "owner" => owner.to_s, "mod" => mod, "map" => Trail.last_map,
                   "battle" => Trail.in_battle? ? true : false, "backtrace" => bt.first(25) }
        end

        # The crash's details as Bundle.make takes them.
        def bundle_info(info)
          return { :error => info["error"], :where => info["where"], :owner => info["owner"], :map => info["map"],
                   :backtrace => info["backtrace"] }
        end

        #----------------------------------------------------------------------
        # The next start
        #----------------------------------------------------------------------
        # Something to offer a report for: a crash not reported yet, or a
        # session that never ended. nil when there's nothing (or it was
        # offered already).
        def pending
          last = read(LAST)
          if last.is_a?(Hash) && !last["reported"] && !last["offered_again"]
            return last.merge("kind" => "crash")
          end
          prev = @previous
          if prev.is_a?(Hash) && prev["running"] && !prev["offered"]
            return { "kind" => "closed", "map" => prev["map"], "battle" => prev["battle"], "time" => prev["started"] }
          end
          return nil
        end

        # Offers a report once (the Load Screen calls it; KIF's own load
        # screen gets it from :title_screen).
        def offer_pending
          info = pending
          return false unless info
          mark_offered(info)
          return false unless defined?(Reloaded::Notice)
          map = info["map"].to_s
          sub = if info["battle"] && !map.empty? then _INTL("Last time, during a battle on {1}.", map)
                elsif !map.empty? then _INTL("Last time, on {1}.", map)
                else _INTL("Last time you played.")
                end
          safe = BugReport.last_save_words
          choice = Reloaded::Notice.show(:title => _INTL("The Game Closed Unexpectedly"), :colour => Reloaded::Notice::GOLD,
                                         :sub => sub, :body => _INTL("A bug report has the logs from that session. It helps get the bug fixed."),
                                         :line => safe, :line_colour => Reloaded::Notice::GREEN,
                                         :buttons => [_INTL("Make a Bug Report"), _INTL("Not Now")], :cancel => 1)
          return false unless choice == 0
          crash = info["kind"] == "crash" ? bundle_info(info) : nil
          BugReportScreen.open(:crash => crash) if defined?(BugReportScreen)
          return true
        rescue StandardError => e
          Reloaded::Log.exception("The crash report offer didn't show", e, :bug_report)
          return false
        end

        def mark_reported
          last = read(LAST)
          save_json(LAST, last.merge("reported" => true)) if last.is_a?(Hash)
        end

        private

        def mark_offered(info)
          if info["kind"] == "crash"
            save_json(LAST, (read(LAST) || {}).merge("offered_again" => true))
          else
            @previous = @previous.merge("offered" => true)
          end
        end

        def after_crash(info, shot)
          title = if info["mod"] then _INTL("Something Went Wrong in {1}", info["mod"])
                  elsif info["owner"] == "Kanto Reloaded" then _INTL("Something Went Wrong in Kanto Reloaded")
                  else _INTL("Something Went Wrong")
                  end
          sub = _INTL("{1} in {2}", info["class"], info["where"])
          choice = Reloaded::Notice.show(:title => title, :colour => Reloaded::Notice::RED, :sub => sub,
                                         :body => _INTL("The game has to close. A bug report saves what happened, so it can be fixed."),
                                         :line => BugReport.last_save_words, :line_colour => Reloaded::Notice::GREEN,
                                         :buttons => [_INTL("Make a Bug Report"), _INTL("Close the Game")], :cancel => 1)
          return unless choice == 0
          result = Bundle.make(:screenshot => shot, :crash => bundle_info(info))
          mark_reported
          BugReport.report_made(result, :mod => info["mod"], :closing => true)
        end

        # PIF's box held back while it logs: what it would have said is kept.
        def quiet_print
          @printed = nil
          old = ::Kernel.instance_method(:print)
          ::Kernel.send(:define_method, :print) { |*a| Reloaded::BugReport::Crash.instance_variable_set(:@printed, a.join) }
          ::Kernel.send(:private, :print)
          yield
        ensure
          if old
            ::Kernel.send(:define_method, :print, old)
            ::Kernel.send(:private, :print)
          end
        end

        def show_pif_box
          print(@printed) if @printed
        end

        def short(line)
          m = line.to_s.match(/\A(.+?):(\d+)/)
          return line.to_s[0, 80] unless m
          return "#{File.basename(m[1])}:#{m[2]}"
        end

        def write_session(running)
          data = { "started" => (@started ||= Time.now.to_i), "running" => running, "map" => @where,
                   "battle" => (Trail.in_battle? ? true : false), "version" => Reloaded.version }
          save_json(SESSION, data)
        end

        def read(name)
          file = File.join(Reloaded::Paths.settings_dir, name)
          return nil unless File.file?(file)
          data = Reloaded::JSON.parse(Reloaded::Paths.read_text(file).to_s)
          return data.is_a?(Hash) ? data : nil
        rescue StandardError
          return nil
        end

        def save_json(name, data)
          Reloaded::Paths.write_atomic(File.join(Reloaded::Paths.settings_dir, name), Reloaded::JSON.generate(data, true))
        rescue StandardError => e
          Reloaded::Log.exception("#{name} couldn't be written", e, :bug_report)
        end
      end
    end
  end
end
