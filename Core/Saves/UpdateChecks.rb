# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the startup checks, in Reloaded's look
#==============================================================================
# As the load screen starts, KIF Beta checks for a newer KIF
# (C-SYS-06_Updater, KIF::Updater.check) and, every 12 hours, for updates to
# your mods (F-CORE-04_Mods, KIF::ModCatalogUI.startup_check). They still
# run and finish before you can choose anything (his call, 2026-10-23), but
# over the load screen: they wait for it to fade in (PokemonLoad_Scene#
# pbStartScene2) instead of running on a black screen before it. How they
# look (UI/UpdateChecksScreen.rb):
#
#   - Checking for Updates... as a toast at the top while they run (his
#     ask, 2026-10-23: the popup came and went at once when they were
#     quick), then Everything's Up to Date with KIF's version
#   - a new KIF: the Choice List (Update Now, What's New, Later, Skip This
#     Version), answering KIF's own question
#   - mod updates: each mod and its versions, with Update All (KIF's own
#     installer, from the popup), Open Updates and Later
#   - KIF's other waits (its update download, installing mods, Mods >
#     Browse) and its messages and questions along the way as Reloaded's
#     popups
#
# Everything is KIF's own code, hooked: the checks, their answers and
# what they do are unchanged. A question of KIF's this doesn't know stays
# KIF's. With Reloaded Load Screen Off (Reloaded Systems), it's all as KIF
# draws it, before the load screen. With Startup Mod-Check Off nothing comes
# up (Saves.rb skips both checks).
#==============================================================================

module Reloaded
  module UpdateChecks
    MOD_LIST_TITLE = "Reading the mod list"                    # KIF's status title while it reads the mod list
    KIF_PROMPT = /KIF (\S+) is out \(you have ([^)]+)\)/       # KIF's question about a new KIF
    MODS_PROMPT = /Open Mods > Updates\?/                      # and about mod updates

    @context = nil      # :kif or :mods while one of KIF's startup checks runs
    @rows = nil         # what each check found (the toast's words at the end)
    @asked = false      # a question came up (a new KIF, mod updates): no toast after it
    @waiting = false    # the load screen's checks, held until it has faded in
    @now = false        # running them now

    class << self
      def boot
        return true unless defined?(::KIF::Updater) && defined?(Reloaded::UpdateChecksScreen)
        return true unless defined?(::Viewport) && defined?(::Graphics)     # no engine (the headless tests)
        install
        return true
      end

      # Reloaded's look for them: with Reloaded Load Screen On
      def on?
        return Reloaded::Saves.load_screen?
      end

      def context
        return @context
      end

      private

      def screen
        return Reloaded::UpdateChecksScreen
      end

      def install
        h = Reloaded::Hooks
        up = ::KIF::Updater
        h.around(nil, up.singleton_class, :check, :id => :update_checks_kif) do |original, *args|
          next original.call(*args) if args[0] || !on? || checks_off?
          kif_check { original.call(*args) }
        end
        if up.respond_to?(:remote_version)
          h.around(nil, up.singleton_class, :remote_version, :id => :update_checks_remote) do |original, *args|
            v = original.call(*args)
            @remote = v if @context == :kif
            v
          end
        end
        if up.respond_to?(:status) && up.respond_to?(:hide_status)
          h.around(nil, up.singleton_class, :status, :id => :update_checks_status) do |original, *args|
            next original.call(*args) unless on?
            status(*args)
          end
          h.around(nil, up.singleton_class, :hide_status, :id => :update_checks_hide_status) do |original, *args|
            screen.hide_status
            original.call(*args)
          end
        end
        if defined?(::KIF::ModCatalogUI) && ::KIF::ModCatalogUI.respond_to?(:startup_check)
          h.around(nil, ::KIF::ModCatalogUI.singleton_class, :startup_check, :id => :update_checks_mods) do |original, *args|
            next original.call(*args) unless on? && Reloaded::Settings.get(Reloaded::Saves::MOD_CHECK) != false
            mods_check { original.call(*args) }
          end
        end
        if defined?(::KIF::ModCatalog) && ::KIF::ModCatalog.respond_to?(:startup_updates)
          h.around(nil, ::KIF::ModCatalog.singleton_class, :startup_updates, :id => :update_checks_found) do |original, *args|
            found = original.call(*args)
            @ups = found if @context == :mods
            found
          end
        end
        [:pbMessage, :pbConfirmMessage].each do |m|
          next unless Object.private_method_defined?(m) || Object.method_defined?(m)
          h.around(nil, Object, m, :id => :"update_checks_#{m}") do |original, *args, &blk|
            next original.call(*args, &blk) unless @context && on?
            m == :pbMessage ? message(original, args, &blk) : screen.confirm(title_now, args[0].to_s)
          end
        end
        # The load screen's version check (and KIF's first-start questions
        # after it) waits for the load screen to fade in, then runs over it;
        # the checking popup goes once they're done, or before those
        # questions
        if (Object.private_method_defined?(:find_newer_available_version) || Object.method_defined?(:find_newer_available_version)) &&
           defined?(::PokemonLoad_Scene) && ::PokemonLoad_Scene.method_defined?(:pbStartScene2)
          h.around(nil, Object, :find_newer_available_version, :id => :update_checks_done) do |original, *args|
            if on? && !@now
              @waiting = true
              next nil
            end
            begin
              original.call(*args)
            ensure
              finish
            end
          end
          h.around(nil, "PokemonLoad_Scene", :pbStartScene2, :id => :update_checks_on_load_screen) do |original, *args|
            ret = original.call(*args)
            run_waiting
            ret
          end
        end
        if defined?(::KIF::FirstChoice) && ::KIF::FirstChoice.respond_to?(:ask)
          h.around(nil, ::KIF::FirstChoice.singleton_class, :ask, :id => :update_checks_first_choice) do |original, *args|
            fc = ::KIF::FirstChoice
            finish(!(fc.respond_to?(:needed?) && fc.needed?))   # KIF's first-start questions take over from the toast
            original.call(*args)
          end
        end
      end

      # The load screen is up: the checks it held run now, over it
      def run_waiting
        return unless @waiting
        @waiting = false
        @now = true
        TOPLEVEL_BINDING.receiver.send(:find_newer_available_version)
      ensure
        @now = false
      end

      # Startup Mod-Check Off: nothing comes up (Saves.rb skips the checks)
      def checks_off?
        return Reloaded::Settings.get(Reloaded::Saves::MOD_CHECK) == false
      end

      def within(ctx)
        before = @context
        @context = ctx
        return yield
      ensure
        @context = before
      end

      #------------------------------------------------------------------------
      # The checks
      #------------------------------------------------------------------------
      def kif_check
        up = ::KIF::Updater
        return yield if (up.channel rescue 0) == 2    # Updates Off: nothing runs, nothing to show
        @rows = { :kif => [:busy, _INTL("Checking..."), nil], :mods => first_mods_row }
        @remote = @kif_new = @kif_choice = nil
        show_rows
        Graphics.update                               # on screen before the check holds the game still
        ret = nil
        begin
          ret = within(:kif) { yield }
        ensure
          @rows[:kif] = kif_result if @rows
          show_rows if screen.checking?
        end
        return ret
      end

      def mods_check
        @rows ||= { :kif => [:wait, ""], :mods => first_mods_row }
        @rows[:mods] = [:busy, _INTL("Checking..."), nil]
        @ups = nil
        show_rows
        Graphics.update
        ret = nil
        begin
          ret = within(:mods) { yield }
        ensure
          n = @ups ? @ups.length : nil
          @rows[:mods] = if n.nil? then [:done, _INTL("NO ANSWER"), :dim]
                         elsif n == 0 then [:done, _INTL("UP TO DATE"), :green]
                         elsif n == 1 then [:done, _INTL("1 UPDATE"), :gold]
                         else [:done, _INTL("{1} UPDATES", n), :gold]
                         end
          show_rows if screen.checking?
        end
        return ret
      end

      # The Mods row before its check: Off, not due yet, or waiting
      def first_mods_row
        return [:done, _INTL("OFF"), :dim] if Reloaded::Settings.get(Reloaded::Saves::MOD_CHECK) == false
        if defined?(::KIF::Startup) && ::KIF::Startup.respond_to?(:mod_check_due?) && !::KIF::Startup.mod_check_due?
          return [:done, _INTL("CHECKED RECENTLY"), :dim]
        end
        return [:wait, _INTL("Waiting")]
      rescue StandardError
        return [:wait, _INTL("Waiting")]
      end

      # The KIF row once its check is done
      def kif_result
        up = ::KIF::Updater
        current = (up.current_version rescue "")
        return [:done, _INTL("NO ANSWER"), :dim] if (up.unreachable rescue false)
        new = @kif_new || (@remote && (up.newer?(@remote, current) rescue false) ? @remote : nil)
        return [:done, _INTL("{1} IS THE NEWEST", current), :green] unless new
        return [:done, _INTL("{1} SKIPPED", new), :dim] if @kif_choice == 3 || @kif_choice.nil?
        return [:done, _INTL("{1} IS OUT", new), :gold]
      end

      # The toast while they run
      def show_rows
        screen.checking
      end

      # Done: the toast says what they found (unless a question took over,
      # or result is false), and fades while you use the menu
      def finish(result = true)
        rows = @rows
        asked = @asked
        @rows = nil
        @asked = false
        words = result && rows && !asked ? done_words(rows) : nil
        words ? screen.done(*words) : screen.close_checking
      end

      # [words, pill]: nothing new, or a check that got no answer
      def done_words(rows)
        kif = rows[:kif] || []
        mods = rows[:mods] || []
        no_answer = _INTL("NO ANSWER")
        return [_INTL("Couldn't Check for Updates"), nil] if kif[1] == no_answer
        version = (::KIF::Updater.current_version rescue nil).to_s
        pill = version.empty? ? nil : [_INTL("KIF {1}", version), :green]
        if kif[0] != :done                          # KIF's own updates Off: the mods only
          return nil unless mods[0] == :done && [_INTL("UP TO DATE"), no_answer].include?(mods[1])
          return mods[1] == no_answer ? [_INTL("Couldn't Check Your Mods"), nil] : [_INTL("Your Mods Are Up to Date"), nil]
        end
        return [_INTL("Couldn't Check Your Mods"), pill] if mods[1] == no_answer
        return [_INTL("Everything's Up to Date"), pill]
      end

      #------------------------------------------------------------------------
      # What KIF shows along the way
      #------------------------------------------------------------------------
      # KIF's waits: reading the mod list goes in the Mods row; anything
      # else (its update download, installing) in a popup of its own. As
      # KIF's own, it moves the game on a frame.
      def status(title, line, frac = nil, foot = nil)
        if @context == :mods && @rows && title.to_s == _INTL(MOD_LIST_TITLE)
          @rows[:mods] = [:busy, line.to_s, frac]
          show_rows
        else
          screen.status(title, line, frac, !foot.nil?)
        end
        Graphics.update
        Input.update
        return nil
      end

      # KIF's questions it knows are Reloaded's popups; its messages are
      # notices; a question it doesn't know stays KIF's
      def message(original, args, &blk)
        text = args[0].to_s
        commands = args[1]
        if commands.is_a?(Array) && commands.length == 4 && (m = text.match(KIF_PROMPT))
          @asked = true
          @kif_new = m[1]
          @kif_choice = screen.choose_kif(m[2], m[1], @kif_choice == 1 ? 1 : 0)
          return @kif_choice
        end
        if commands.is_a?(Array) && commands.length == 2 && text =~ MODS_PROMPT && @ups && !@ups.empty?
          @asked = true
          case screen.choose_mods(mod_rows(@ups))
          when :open then return 0
          when :all
            update_all(@ups)
            return 1
          end
          return 1
        end
        return original.call(*args, &blk) if commands
        @asked = true
        screen.notice(title_now, text)
        return 0
      end

      # Update All: KIF's own installer, as Mods > Updates does it
      def update_all(list)
        ::KIF::ModCatalogUI.run(list)
      rescue StandardError => e
        Reloaded::Log.exception("Update All couldn't install the mods", e, :saves)
        screen.notice(_INTL("Mod Updates"), _INTL("The mods couldn't be updated. Mods > Updates can try again."))
      end

      def mod_rows(list)
        cat = ::KIF::ModCatalog
        return list.map { |it| [it.name, (cat.installed_version(it) rescue nil).to_s, it.version.to_s] }
      end

      def title_now
        return _INTL("What's New") if @context == :kif && @kif_choice == 1
        return @context == :mods ? _INTL("Mod Updates") : _INTL("KIF Update")
      end
    end
  end
end
