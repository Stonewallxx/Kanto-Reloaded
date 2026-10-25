#==============================================================================
# Kanto Reloaded: Publish a Mod
#==============================================================================
# KIF Beta's Options > Mods > Installed > Publish a mod (KIF::ModPublish,
# cody's, made on Stonewall's ask) in one screen instead of its message
# boxes (his ask, 2026-10-25: cleaner and faster, every piece of what it
# says kept). The screen is Reloaded::PublishScreen; this is its engine.
#
# KIF's own code does the work: the folders (Mods, ModDev), mod.json read
# and written, the catalog's check (ModCheck, the catalog's rules word for
# word), the pull request's text and the window (Tools/publish_mod) that
# signs in to GitHub and uploads. Only the screens are Kanto Reloaded's.
#
# His rule: if KIF ever changes it, Kanto Reloaded's is dropped until it's
# fixed. Each KIF method this replaces or calls is the source it was made
# for (MADE_FOR: its CRC32, read as Reloaded::Fixes reads a method); when
# any differs, KIF's own Publish a mod runs and the log says which.
#
# His picks: always on (no switch), mod.json saved as you change it (the
# check runs again a moment after), and Permission, Tested and the notes
# remembered for each mod (Settings/Publish Answers.json).
#
# A mod's release copy (his ask: Use the Copy, found by A Setting, named the
# ModDev Folder): the ModDev Folder is KIF's own ModDev in the game's folder
# unless another is set (KIF Settings > Mods > For Modders > ModDev Folder,
# under Publish a mod; kept in Settings/Publish.json). A mod in Mods that has
# a copy there (a folder whose
# mod.json has its id, capitals, _ and - aside: his GitHub folders) is shown,
# checked and uploaded from that copy, the files that are shared (no Dev, no
# tools); details changed are saved to both copies.
#
#   Reloaded::Publish.ours?            Kanto Reloaded's screen runs
#   Reloaded::Publish.mods             [Entry] for every folder KIF offers
#   Reloaded::Publish.check(entry)     [problems, things to look at]
#   Reloaded::Publish.field_of(text)   the detail a problem is about, or nil
#   Reloaded::Publish.answers(id)      { "own", "tested", "notes" }
#   Reloaded::Publish.request(entry)   [title, body] of its pull request
#   Reloaded::Publish.publish(entry)   KIF's launch: :started, :manual or false
#==============================================================================

module Reloaded
  module Publish
    ANSWERS_FILE = "Publish Answers.json"
    FOLDER_FILE = "Publish.json"
    # KIF::ModPublish as Kanto Reloaded's screen was made for it (KIF Beta
    # 1.2.2): what it calls, and what its screen takes the place of
    MADE_FOR = {
      :available?    => 944231627,
      :folders       => 3395192420,
      :load_json     => 4129193026,
      :save_json     => 2029871544,
      :raise_version => 4249212042,
      :catalog_items => 2007394588,
      :published     => 2888259924,
      :check         => 1363570181,
      :pr_text       => 204818215,
      :branch_for    => 468868511,
      :request_dir   => 3080038566,
      :write_request => 1185906281,
      :launch        => 3350317677,
      :ask           => 449803951,
      :enter         => 3531810684,
      :pick_tags     => 4103724449,
      :pick_version  => 1882293149,
      :edit          => 634797223,
      :show_problems => 22440599,
      :run           => 2066859623
    }.freeze
    # What each of KIF's check messages is about (Problems Point at Rows)
    FIELDS = [[/\A"id"|\Aid "/, :id], [/\A"name"/, :name], [/\A"version"/, :version],
              [/\A"author"/, :author], [/\A"description"/, :desc]].freeze

    # A mod folder KIF offers: json is nil when its mod.json can't be read;
    # old is the catalog's copy (an update) or nil (new); copy is its copy's
    # folder in the ModDev Folder, or nil
    Entry = Struct.new(:label, :path, :where, :json, :old, :copy) do
      def readable?
        return !json.nil?
      end

      # The folder checked and uploaded: the ModDev Folder's copy when there is one
      def source
        return copy || path
      end

      def id
        return json ? json["id"].to_s : File.basename(path)
      end

      def name
        return json && !json["name"].to_s.empty? ? json["name"].to_s : File.basename(path)
      end

      def version
        return json ? json["version"].to_s : ""
      end

      def description
        d = json && json["description"]
        return d.is_a?(Array) ? d.join(" ") : d.to_s
      end

      # :new, :update, or :raise (the catalog has this version or a later one)
      def state
        return :new unless old
        return ::KIF::ModRules.compare(version, old.version) > 0 ? :update : :raise
      end
    end

    class << self
      def boot
        install
        make_moddev
        return true
      end

      def install
        return unless defined?(::KIF::ModPublish) && ::KIF::ModPublish.respond_to?(:run)
        Reloaded::Hooks.around(nil, ::KIF::ModPublish.singleton_class, :run, :id => :publish_a_mod) do |original, *args|
          # a phone, or KIF changed: KIF's own (it says "on a computer only")
          next original.call(*args) unless defined?(Reloaded::PublishScreen) && ::KIF::ModPublish.available? && Reloaded::Publish.ours?
          Reloaded::PublishScreen.open
        end
        # The ModDev Folder's row, right under KIF's Publish a mod (his ask:
        # for every modder, in the Mods section's For Modders)
        if defined?(::KIF::SettingsScreen) && ::KIF::SettingsScreen.respond_to?(:installed_rows)
          Reloaded::Hooks.around(nil, ::KIF::SettingsScreen.singleton_class, :installed_rows, :id => :publish_moddev_row) do |original, *args|
            rows = original.call(*args)
            Reloaded::Publish.add_folder_row(rows)
          end
        end
      end

      # The row after Publish a mod's (KIF adds it only where publishing works)
      def add_folder_row(rows)
        return rows unless ::KIF::ModPublish.available? && ours? && defined?(::KIF::SettingsScreen::BadgeButton)
        at = rows.index { |r| r.respond_to?(:opt) && r.opt.respond_to?(:name) && r.opt.name.to_s == _INTL("Publish a mod") }
        return rows unless at
        ks = ::KIF::SettingsScreen
        opt = ks::BadgeButton.new(_INTL("ModDev Folder"), proc { Reloaded::Publish.ask_folder },
                                  _INTL("Where your mods' release copies are (the files you share, like a GitHub folder): ModDev in KIF's folder unless you set another. " \
                                        "Publish a Mod checks and uploads a mod from its copy there, so its dev tools and notes stay home, and saves its details to both. " \
                                        "A types the folder; empty goes back to KIF's ModDev."))
        opt.kif_badge = [File.basename(moddev_folder).upcase, defined?(::KIF::PixelUI::PILL) ? ::KIF::PixelUI::PILL : nil]
        head = rows[at]
        rows.insert(at + 1, ks::Row.new(:opt, opt, :global, opt.name, head.section, head.heading, 0, nil))
        return rows
      rescue StandardError => e
        Reloaded::Log.exception("Publish a Mod: the ModDev Folder row couldn't be added", e, :publish)
        return rows
      end

      def kif
        return ::KIF::ModPublish
      end

      # True while every KIF method this uses is still the source it was
      # made for (asked once a session)
      def ours?
        return @ours unless @ours.nil?
        @changed = MADE_FOR.reject { |name, crc| Reloaded::Fixes.source?(kif, name, crc) }.keys
        @ours = @changed.empty?
        unless @ours
          Reloaded::Log.warning("Publish a Mod: KIF changed its Publish a mod (#{@changed.join(', ')}), so KIF's own runs until Kanto Reloaded is updated for it", :publish)
        end
        return @ours
      rescue StandardError => e
        Reloaded::Log.exception("Publish a Mod: KIF's Publish a mod couldn't be read; KIF's own runs", e, :publish)
        @changed = [:unreadable]
        return @ours = false
      end

      # The methods that differ (after ours?)
      def changed
        ours? if @ours.nil?
        return @changed || []
      end

      # Asked again (the KR Debug page)
      def recheck
        @ours = nil
        return ours?
      end

      # KIF's own Publish a mod, once (the KR Debug page, to compare)
      def with_kif
        was = @ours
        @ours = false
        return yield
      ensure
        @ours = was
      end

      # The remembered answers gone (the KR Debug page)
      def forget_answers
        File.delete(answers_path) if File.file?(answers_path)
        return true
      rescue StandardError
        return false
      end

      #------------------------------------------------------------------------
      # The mods
      #------------------------------------------------------------------------
      # The catalog as Browse read it (once each time the screen opens)
      def catalog(fresh = false)
        @items = nil if fresh
        return @items ||= kif.catalog_items
      end

      def mods
        items = catalog(true)
        copies = moddev_copies
        list = kif.folders.map do |label, path|
          where = label.to_s[/\((Mods|ModDev)\)\z/, 1] || "Mods"
          json = kif.load_json(path)
          copy = json ? copies[id_key(json["id"])] : nil
          copy = nil if copy && File.expand_path(copy) == File.expand_path(path)
          copy_json = copy ? kif.load_json(copy) : nil
          json = copy_json if copy_json                 # what goes up is the copy's
          copy = nil unless copy_json
          Entry.new(label, path, where, json, json ? kif.published(json, items) : nil, copy)
        end
        # a copy KIF lists too (in its ModDev): the one row, MODDEV on it
        copied = list.map { |e| e.copy && File.expand_path(e.copy) }.compact
        return list.reject { |e| copied.include?(File.expand_path(e.path)) }
      end

      #------------------------------------------------------------------------
      # The ModDev Folder (his pick: A Setting)
      #------------------------------------------------------------------------
      # KIF's own ModDev in the game's folder, made when it isn't there (his
      # ask), on a computer that can publish; a folder set instead is left be
      def make_moddev
        return false unless defined?(::KIF::ModPublish) && kif.available?
        return false unless read_json(folder_path)["moddev_folder"].to_s.empty?
        dir = File.join(kif.root, kif::MODDEV)
        return true if File.directory?(dir)
        Dir.mkdir(dir)
        Reloaded::Log.info("Publish a Mod: made the ModDev folder (#{dir})", :publish)
        return true
      rescue StandardError => e
        Reloaded::Log.exception("Publish a Mod: the ModDev folder couldn't be made", e, :publish)
        return false
      end

      # The one set, else KIF's own ModDev in the game's folder (his pick)
      def moddev_folder
        dir = read_json(folder_path)["moddev_folder"].to_s
        return dir.empty? ? File.join(kif.root, kif::MODDEV) : dir
      end

      # false when the folder isn't there (empty: KIF's ModDev again)
      def set_moddev_folder(dir)
        dir = dir.to_s.strip.tr("\\", "/").sub(%r{/+\z}, "")
        return false unless dir.empty? || File.directory?(dir)
        Reloaded::Paths.write_atomic(folder_path, Reloaded::JSON.generate({ "moddev_folder" => dir }, true))
        return true
      end

      # The row's press: typed in the improved KIF Settings' title bar (KIF's
      # own text box on KIF's screen), then the rows again for its chip
      def ask_folder
        current = read_json(folder_path)["moddev_folder"].to_s
        scr = defined?(Reloaded::SettingsScreen) ? Reloaded::SettingsScreen.showing : nil
        if scr
          text, how = shown_while(scr) { scr.send(:run_entry, :rename, _INTL("Type a Folder"), current, 260, :prompt => _INTL("ModDev Folder?")) }
          return false unless how == :enter
        else
          text = pbMessageFreeText(_INTL("ModDev Folder (Empty: KIF's ModDev):"), current, false, 260)
          return false if text.nil?
        end
        ok = set_moddev_folder(text)
        make_moddev if ok                     # back to KIF's ModDev: made if it isn't there
        if !ok && scr
          shown_while(scr) { Reloaded::Dialogs.notice(scr, _INTL("ModDev Folder"), _INTL("That folder isn't there: {1}", text.to_s.strip)) }
        elsif !ok
          pbMessage(_INTL("That folder isn't there: {1}", text.to_s.strip))
        end
        if scr
          scr.rebuild if scr.respond_to?(:rebuild)
          scr.refresh if scr.respond_to?(:refresh)
        end
        return ok
      end

      # KIF runs a row's button with its screen stepped aside (hidden): the
      # screen shown again while the folder is typed in its title bar
      def shown_while(scr)
        hid = scr.send(:sprites).reject { |s| s.disposed? || s.visible }
        hid.each { |s| s.visible = true }
        scr.refresh
        return yield
      ensure
        (hid || []).each { |s| s.visible = false unless s.disposed? }
      end

      # Each copy in the ModDev Folder by its mod.json's id: { key => folder }.
      # A copy is a folder there with a mod.json, or one a folder down (a
      # repo holding its mod in a folder of its own: his GitHub layout)
      def moddev_copies
        dir = moddev_folder
        return {} unless File.directory?(dir)
        out = {}
        (Dir.children(dir) rescue []).sort.each do |c|
          path = File.join(dir, c)
          next unless File.directory?(path) && !c.start_with?(".")
          places = File.file?(File.join(path, "mod.json")) ? [path] :
                   (Dir.children(path) rescue []).sort.reject { |g| g.start_with?(".") }.map { |g| File.join(path, g) }
          places.each do |place|
            json_file = File.join(place, "mod.json")
            next unless File.directory?(place) && File.file?(json_file)
            json, _why = (::KIF::ModCheck.parse_json(File.read(json_file, :encoding => "UTF-8")) rescue [nil, nil])
            out[id_key(json["id"])] ||= place if json.is_a?(Hash) && !json["id"].to_s.empty?
          end
        end
        return out
      end

      # An id as copies are matched: capitals, _ and - aside
      def id_key(id)
        return id.to_s.downcase.delete("_-")
      end

      # After its id changed: the catalog's copy again
      def relink(entry)
        entry.old = entry.json ? kif.published(entry.json, catalog) : nil
        return entry
      end

      # mod.json written (to both copies when it has one in the ModDev
      # Folder); false when it couldn't be (KIF logs why)
      def save(entry)
        ok = kif.save_json(entry.source, entry.json)
        ok = kif.save_json(entry.path, entry.json) && ok if entry.copy
        return ok
      end

      # The catalog's check on the folder as it would go up: [problems,
      # things to look at], logged as KIF logs them
      def check(entry)
        errs, warns = kif.check(entry.source, entry.json, catalog)
        kif.log("#{File.basename(entry.source)}: #{errs.length} problems, #{warns.length} to look at")
        (errs.map { |e| "problem: #{e}" } + warns.map { |w| "look at: #{w}" }).each { |l| kif.log("  #{l}") }
        return [errs, warns]
      end

      def field_of(text)
        hit = FIELDS.find { |re, _f| text.to_s =~ re }
        return hit ? hit[1] : nil
      end

      # Raise steps from where the version starts (the catalog's, when
      # that's later): [patch, minor, major]
      def raises(entry, from)
        base = from.to_s
        if entry.old && ::KIF::ModRules.compare(entry.old.version, base) > 0
          base = entry.old.version
        end
        return [:patch, :minor, :major].map { |p| kif.raise_version(base, p) }
      end

      #------------------------------------------------------------------------
      # Remembered answers (his pick: Remember Answers)
      #------------------------------------------------------------------------
      def answers(id)
        a = (load_answers[id.to_s] || {})
        return { "own" => a["own"] == true, "tested" => a["tested"] == true, "notes" => a["notes"].to_s }
      end

      def remember(id, answers)
        all = load_answers
        all[id.to_s] = { "own" => answers["own"] == true, "tested" => answers["tested"] == true, "notes" => answers["notes"].to_s }
        Reloaded::Paths.write_atomic(answers_path, Reloaded::JSON.generate(all, true))
        return true
      rescue StandardError => e
        Reloaded::Log.exception("Publish a Mod: the answers couldn't be kept", e, :publish)
        return false
      end

      def answers_path
        return File.join(Reloaded::Paths.settings_dir, ANSWERS_FILE)
      end

      #------------------------------------------------------------------------
      # Publishing: KIF's own pull request and window
      #------------------------------------------------------------------------
      def folder_of(entry)
        return entry.old ? entry.old.folder : File.basename(entry.path)
      end

      # [title, body], as KIF writes them (with the check's things to look at)
      def request(entry, answers = nil, warns = nil)
        answers ||= answers(entry.id)
        warns ||= check(entry)[1]
        a = { :own => answers["own"] == true, :tested => answers["tested"] == true, :notes => answers["notes"].to_s }
        return kif.pr_text(entry.json, folder_of(entry), entry.old, a, warns)
      end

      # :started, :manual (the command is in Cache/Publish/command.txt) or false
      def publish(entry, answers = nil)
        answers ||= answers(entry.id)
        _errs, warns = kif.check(entry.source, entry.json, catalog)
        title, body = request(entry, answers, warns)
        msg, bod = kif.write_request(title, body)
        return kif.launch([entry.source, folder_of(entry), kif.branch_for(entry.json), msg, bod, entry.json["id"].to_s])
      end

      private

      def load_answers
        return read_json(answers_path)
      end

      def folder_path
        return File.join(Reloaded::Paths.settings_dir, FOLDER_FILE)
      end

      def read_json(path)
        text = Reloaded::Paths.read_text(path)
        data = text ? (Reloaded::JSON.parse(text) rescue nil) : nil
        return data.is_a?(Hash) ? data : {}
      end
    end
  end
end
