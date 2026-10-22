#==============================================================================
# Kanto Reloaded: Bug Reports
#==============================================================================
# Roadmap topic 37: one file with everything needed to fix a bug.
#
#   Bundle.rb      what goes in the zip (Zip.rb writes it), the user name
#                  taken out
#   Trail.rb       Recent Steps: the last 100 things that happened
#   Crash.rb       After a Crash, and the next start's offer
#   ../UI/BugReportScreen.rb   Make a Bug Report (the Settings layout)
#   ../UI/Notice.rb            the notice look (After a Crash, Report Made)
#
# Make a Bug Report is a heading of its own in the Kanto Reloaded section.
# "This Screen" is the screen as it was when the Pause Menu opened (or KIF
# Settings, from the title). A report about Kanto Reloaded, KIF Beta or the
# game goes to Kanto Reloaded's Discord (DISCORD_URL); one about a mod's code
# goes to that mod's maker (its mod.json "author", and "support" link).
#==============================================================================

module Reloaded
  module BugReport
    # Kanto Reloaded's bug reports channel. A channel link opens only for
    # members of the server: an invite link (discord.gg/...) reaches anyone.
    DISCORD_URL = "https://discord.com/channels/1121345297352753243/1529078153786429552/1529078153786429552".freeze
    SCREEN_FRESH = 600           # seconds the Pause Menu's screen stays "this screen"

    class << self
      attr_accessor :launcher    # tests: what opening a folder or a link does

      def boot
        register_settings
        Trail.install
        Crash.install
        return true
      end

      def register_settings
        s = Reloaded::Settings
        s.register_page(:bug_report, :group => :general, :name => "Bug Report", :icon => :system, :priority => 900,
          :description => "Everything needed to fix a bug, in one file to send.")
        s.register(:"bug_report.make", :page => :bug_report, :priority => 0, :type => :button, :preset => false,
          :name => "Make a Bug Report",
          :on_press => proc { Reloaded::BugReportScreen.open if defined?(Reloaded::BugReportScreen) },
          :description => "One file with the logs, your settings and mods, what led up to the bug and a note from you, to send in Kanto Reloaded's Discord.")
      end

      #------------------------------------------------------------------------
      # The screenshot
      #------------------------------------------------------------------------
      # The screen as it is now, kept for "This Screen" (the Pause Menu
      # opening: the map behind it; KIF Settings from the title).
      def remember_screen(from)
        fresh = @screen && !(@screen.disposed? rescue true) && @screen_at && Time.now - @screen_at < SCREEN_FRESH
        return if from == :settings && fresh
        shot = (Graphics.snap_to_bitmap rescue nil)
        return unless shot
        @screen.dispose if @screen && !(@screen.disposed? rescue true)
        @screen = shot
        @screen_at = Time.now
      end

      def screen
        return nil if @screen.nil? || (@screen.disposed? rescue true)
        return @screen
      end

      # The newest screenshot the game took (PIF keeps them in the save
      # folder), or nil.
      def last_screenshot
        return Dir.glob(File.join(Reloaded::Saves.dir, "*.png")).max_by { |f| File.mtime(f) rescue Time.at(0) }
      end

      #------------------------------------------------------------------------
      # Words
      #------------------------------------------------------------------------
      # "Your last save is safe: today 1:40 PM." (the newest save file)
      def last_save_words
        slot = Reloaded::Saves.playing || Bundle.current_slot
        return nil unless slot && File.file?(Reloaded::Saves.path(slot))
        return _INTL("Your last save is safe: {1}.", SaveCheck.when_words(File.mtime(Reloaded::Saves.path(slot))))
      end

      # Report Made: where the file is and where to send it, with Open the
      # Folder, Open Discord (or the mod's own page) and Done.
      def report_made(result, mod: nil, closing: false)
        place = _INTL("Bug Reports")
        sub2 = "#{SaveCheck.size_words(result[:size])}, #{result[:words]}"
        info = mod ? Bundle.mod_named(mod) : nil
        link = nil
        if mod
          author = info && !info[:author].to_s.empty? ? " (#{info[:author]})" : ""
          body = _INTL("This came from {1}. Send it to its maker{2}, with what happened.", mod, author)
          if info && !info[:support].to_s.empty?
            link = [_INTL("Open Their Page"), info[:support].to_s]
          end
        else
          body = _INTL("Send it in Kanto Reloaded's Discord, in the bug reports channel, with what happened.")
          link = [_INTL("Open Discord"), DISCORD_URL]
        end
        line, colour = closing ? [_INTL("The game closes when you're done."), Reloaded::Notice::GOLD] : [_INTL("Thank you: It helps get the bug fixed."), Reloaded::Notice::DIM]
        phone = Reloaded::Runtime.phone?      # no File Explorer or browser: Copy Instead (his pick)
        buttons = [phone ? _INTL("Copy the Path") : _INTL("Open the Folder")]
        buttons << (phone ? _INTL("Copy the Link") : link[0]) if link
        buttons << (closing ? _INTL("Close the Game") : _INTL("Done"))
        choice = 0
        loop do
          choice = Reloaded::Notice.show(:title => _INTL("Bug Report Made"), :colour => Reloaded::Notice::GREEN,
                                         :sub => "#{place}: #{File.basename(result[:path])}", :sub2 => sub2, :body => body,
                                         :line => line, :line_colour => colour, :buttons => buttons, :choice => choice)
          break if choice == buttons.length - 1
          if phone
            choice == 0 ? copy_text(result[:path], _INTL("Where your report is, ready to paste.")) :
                          copy_text(link[1], _INTL("The link, ready to paste in your browser."))
          else
            choice == 0 ? open_folder(result[:path]) : open_url(link[1])
          end
        end
      end

      #------------------------------------------------------------------------
      # Opening things
      #------------------------------------------------------------------------
      # On a phone: the text on the clipboard and a short Copied notice; when
      # the clipboard can't be used, the notice shows the text itself
      def copy_text(text, words)
        if Reloaded::ShareCodes.copy(File.file?(text.to_s) ? File.expand_path(text.to_s) : text.to_s)
          Reloaded::Notice.show(:title => _INTL("Copied"), :colour => Reloaded::Notice::GREEN, :body => words,
                                :buttons => [_INTL("OK")])
        else
          Reloaded::Notice.show(:title => _INTL("Couldn't Copy"), :colour => Reloaded::Notice::GOLD, :body => text.to_s,
                                :buttons => [_INTL("OK")])
        end
      end

      # File Explorer, on the file.
      def open_folder(path)
        return @launcher.call(:folder, path) if @launcher
        system("explorer /select,\"#{path.to_s.tr("/", "\\")}\"")
      rescue StandardError
        nil
      end

      def open_url(url)
        return @launcher.call(:url, url) if @launcher
        return openUrlInBrowser(url) if defined?(openUrlInBrowser)
        system("start \"\" \"#{url}\"")
      rescue StandardError
        nil
      end
    end
  end
end
