# encoding: utf-8
# Offline preview of the startup checks in Reloaded's look, on the preview
# tool's stand-ins (Tools/UIPreview/preview.rb) and stand-ins for KIF Beta's
# updater and mod catalog that follow KIF's own code and words
# (C-SYS-06_Updater/Updater.rb, Updater_Startup.rb, F-CORE-04_Mods/
# ModCatalog.rb): the checks held until the load screen has faded in, then
# run over it; Checking for Updates (the toast, held while they run, then
# Everything's Up to Date or Couldn't Check), mod updates (Open Updates, Update All,
# B), a new KIF (What's New, Later, Skip This Version, Update Now and its
# download), KIF's first-start questions after them, Updates Off, Startup
# Mod-Check Off (nothing comes up), and Reloaded Load Screen Off (KIF's own,
# before the load screen).
# Usage: ruby   Tools/Tests/update_checks_preview.rb "<KIF Beta>" <work dir with metrics.json>
#        python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>

#---------------------------------------------------------------- KIF's updater and catalog, as stand-ins
$channel = 0
$remote = "1.1.0"
$skipped = nil
$due = true
$ups = []
$installed = {}
module KIF
  module Updater
    module_function

    def channel; $channel; end
    def current_version; "1.1.0"; end
    def remote_version(_base); $remote; end
    def unreachable; @unreachable ? true : false; end
    def skipped_version; $skipped; end
    def newer?(a, b); Gem::Version.new(a) > Gem::Version.new(b); end
    def store_choice(_k, v); $skipped = v; end
    # KIF's own: a dark full screen (here, only noted)
    def status(title, line, frac = nil, foot = nil); $log << "KIF STATUS #{title} | #{line}"; nil; end
    def hide_status; $log << "KIF HIDE"; end

    # as KIF's check (manual false: at the load screen)
    def check(manual = false)
      ch = channel
      return false if ch == 2 && !manual
      v = remote_version("base")
      @unreachable = v.nil?
      return false if v.nil?
      return false unless newer?(v, current_version)
      return false if !manual && skipped_version == v
      loop do
        cmd = pbMessage(_INTL("KIF {1} is out (you have {2}).", v, current_version),
                        [_INTL("Update now"), _INTL("What's new"), _INTL("Later"), _INTL("Skip this version")], 3)
        case cmd
        when 0 then return update("base", v)
        when 1 then show_notes("base")
        when 3
          store_choice("skip", v)
          pbMessage(_INTL("You won't be asked about {1} again. Options > System > Check for Updates still finds it.", v))
          return false
        else
          return false
        end
      end
    end

    def show_notes(_base)
      lines = ["Faster start-up.", "Shinies sparkle again.", "Fixes for the Bag.", "Mods can add moves."]
      lines.each_slice(3) { |chunk| pbMessage(chunk.join("\n")) }
    end

    def update(_base, version)
      status(_INTL("Updating to KIF {1}", version), _INTL("Reading the file list..."))
      hide_status
      return false unless pbConfirmMessage(_INTL("{1} files to download ({2}).", 12, "3.4 MB") + " " + _INTL("Update now?"))
      status(_INTL("Updating to KIF {1}", version), _INTL("{1} of {2}", "1.2 MB", "3.4 MB"), 0.35,
             _INTL("{1}: cancel (you can update later)", "X"))
      hide_status
      pbMessage(_INTL("KIF {1} is ready. The game closes now and starts again in a moment.", version))
      $log << "KIF UPDATED"
      return true
    end
  end

  module ModCatalog
    Item = Struct.new(:name, :version, :folder)
    module_function

    def updater; KIF::Updater; end
    def startup_updates
      updater.status(_INTL("Reading the mod list"), _INTL("Contacting GitHub ({1})...", "KIF-Mods"))
      3.times { |i| updater.status(_INTL("Reading the mod list"), _INTL("{1}: {2} of {3}", "KIF-Mods", i + 1, 3), (i + 1) / 3.0) }
      updater.hide_status
      return $ups
    end
    def installed_version(item); $installed[item.name]; end
    def install(list)
      list.each_with_index { |it, i| updater.status(_INTL("Installing {1} ({2} of {3})", it.name, i + 1, list.length), _INTL("Downloading..."), (i + 1).to_f / list.length) }
      updater.hide_status
      $log << "INSTALLED #{list.map(&:name).join(', ')}"
      return [list, [], nil]
    end
  end

  module ModCatalogUI
    module_function

    def cat; KIF::ModCatalog; end
    # as KIF's startup_check
    def startup_check
      return false unless KIF::Updater.channel != 2
      ups = cat.startup_updates
      return false if ups.empty?
      q = ups.length == 1 ? _INTL("An update for 1 mod. Open Mods > Updates?") : _INTL("Updates for {1} mods. Open Mods > Updates?", ups.length)
      return false unless pbMessage(q, [_INTL("Yes"), _INTL("Later")], 2) == 0
      $log << "OPEN MODS UPDATES"
      return true
    end
    # as KIF's run
    def run(list)
      done, failed, cancelled = cat.install(list)
      pbMessage(_INTL("{1} is ready. It starts working the next time the game starts.", done.map(&:name).join(", "))) unless done.empty?
    end
  end

  module Startup
    MOD_CHECK_HOURS = 12
    def self.mod_check_due?; $due; end
    def self.mod_checked!; $due = false; end
  end

  module FirstChoice
    module_function

    def needed?; $first_start ? true : false; end     # only the very first start asks
    def ask; $log << "FIRST CHOICE (checking shown: #{Reloaded::UpdateChecksScreen.checking? ? 'yes' : 'no'})"; end
  end
end

# PIF's load screen scene, as far as these checks go: it fades in with
# pbStartScene2, after the version check below
class PokemonLoad_Scene
  def pbStartScene2; $log << "LOAD SCREEN SHOWN"; end
end
def openUrlInBrowser(url = ""); end

# the load screen's version check, as KIF's Updater_Startup.rb and
# FirstChoice.rb leave it
def find_newer_available_version
  updating = KIF::Updater.check(false)
  if updating != true
    if KIF::Updater.unreachable
      $log << "MOD CHECK SKIPPED"
    elsif KIF::Startup.mod_check_due?
      KIF::ModCatalogUI.startup_check
      KIF::Startup.mod_checked!
    end
  end
  KIF::FirstChoice.ask
  return nil
end

PREVIEW_SETUP_ONLY = true
load File.join(ARGV[0], "Mods/KantoReloaded/Tools/UIPreview/preview.rb")
UC = Reloaded::UpdateChecks
UCS = Reloaded::UpdateChecksScreen

# what the pixel fonts drew, per bitmap
$pf_texts = Hash.new { |h, k| h[k] = [] }
Reloaded::Pixel.singleton_class.prepend(Module.new { def text(b, x, y, w, h, str, *r); $pf_texts[b.id] << str.to_s; super; end })
Bitmap.prepend(Module.new { def clear(*a); $pf_texts.delete(id); super; end })
def shown_text
  $sprites.reject { |s| s.disposed? || s.bitmap.nil? || s.bitmap.disposed? || !s.visible }
          .flat_map { |s| $pf_texts[s.bitmap.id] + s.bitmap.ops.select { |o| o[0] == "text" }.map { |o| o[5].to_s } }
end
# (a wrapped sentence is drawn a line at a time: the lines are read together)
def says?(w); shown_text.join(" ").gsub(/\s+/, " ").include?(w); end

# PIF's load screen starting: the version check (held, with Reloaded Load
# Screen On), then the scene fading in (they run then)
def startup(label, queue)
  Input.queue = queue.dup
  $log.clear
  find_newer_available_version
  $held = $log.empty? && !UCS.checking?
  PokemonLoad_Scene.new.pbStartScene2
  check("#{label}: done", true)
rescue QueueEmpty => e
  check("#{label}: #{e.message}", false)
rescue Exception => e
  check("#{label}: #{e.class}: #{e.message} #{e.backtrace.first(4).inspect}", false)
end
def mod(name, version); KIF::ModCatalog::Item.new(name, version, name.delete(" ")); end
MODS = [mod("Kanto Reloaded", "2.0.1"), mod("Multiplayer", "1.5.0"), mod("EBDX", "1.3.1")]
$installed = { "Kanto Reloaded" => "2.0.0", "Multiplayer" => "1.4.2", "EBDX" => "1.3.0" }

#---------------------------------------------------------------- A: KIF up to date, three mod updates
$ups = MODS
startup("A mod updates", [
  at { check("held until the load screen has faded in, then run over it", $held && $log.first == "LOAD SCREEN SHOWN") },
  nil, nil,
  dmp("uc_01_checking"),
  at { check("Checking for Updates...: the toast at the top, held while they run (no popup over the menu)",
             UCS.checking? && Reloaded::Toast.held? && says?("Checking for Updates...") && !says?("IS THE NEWEST")) },
  at { check("...instead of KIF's dark screen (#{$log.grep(/KIF STATUS/).length})", $log.grep(/KIF STATUS/).empty?) },
  nil, nil, nil, nil,
  dmp("uc_02_mods"),
  at { check("Mod Updates: each mod with its versions, Update All first",
             says?("Mod Updates") && says?("3 of your mods have updates.") && says?("Kanto Reloaded") && says?("2.0.0") &&
             says?("2.0.1") && says?("Update All") && says?("Open Updates")) },
  I::RIGHT, I::USE
])
check("Open Updates: KIF opens Mods > Updates, as its own Yes", $log.include?("OPEN MODS UPDATES"))
check("...the toast gone before KIF's first-start questions (#{$log.grep(/FIRST/).inspect})",
      $log.include?("FIRST CHOICE (checking shown: no)") && !UCS.checking?)
check("...and no Up to Date toast after a question", Reloaded::Toast.sprite.nil?)

#---------------------------------------------------------------- A2: nothing new, no answer
$ups = []
$due = true
startup("A2 nothing new", [*[nil] * 8])
check("nothing new: Everything's Up to Date, KIF's version in a pill, not held (it fades)",
      !Reloaded::Toast.held? && !Reloaded::Toast.sprite.nil? && says?("Everything's Up to Date") && says?("KIF 1.1.0"))
dump("uc_08_up_to_date")
150.times { Reloaded::Toast.update }
check("...the menu moves it on: gone after its time", Reloaded::Toast.sprite.nil?)
$first_start = true
startup("A2 first start", [*[nil] * 8])
check("the very first start: no toast, KIF's first-start questions come instead", Reloaded::Toast.sprite.nil?)
$first_start = false
$remote = nil                                   # the update server gives no answer
startup("A2 no answer", [*[nil] * 8])
check("KIF got no answer: Couldn't Check for Updates", says?("Couldn't Check for Updates") && !Reloaded::Toast.held?)
$remote = "1.1.0"
Reloaded::Toast.dispose
$ups = MODS

#---------------------------------------------------------------- B: Update All, then B
$due = true
startup("B update all", [
  *[nil] * 4,
  at { check("Mod Updates on Update All", says?("Update All")) },
  I::USE,
  nil, nil,
  dmp("uc_03_installing"),
  at { check("...KIF's own installer, its wait in Reloaded's look (Installing EBDX (3 of 3)), in the checking popup's place",
             says?("Installing EBDX (3 of 3)") && !says?("Checking for Updates")) },
  nil,
  at { check("...then its message as a notice", says?("is ready. It starts working the next time the game starts.") && says?("OK")) },
  at { check("...the toast gone once the question came", !UCS.checking? && !says?("Checking for Updates")) },
  dmp("uc_04_ready"),
  I::USE
])
check("...installed, Mods not opened", $log.any? { |l| l.start_with?("INSTALLED Kanto Reloaded, Multiplayer, EBDX") } &&
      !$log.include?("OPEN MODS UPDATES"))
$due = true
startup("B later", [*[nil] * 4, I::BACK])
check("B on Mod Updates: Later (Mods not opened)", !$log.include?("OPEN MODS UPDATES") && $log.include?("FIRST CHOICE (checking shown: no)"))

#---------------------------------------------------------------- C: a new KIF
$remote = "1.2.0"
$due = false
$ups = []
startup("C new KIF", [
  dmp("uc_05_kif"),
  at { check("A new KIF: the Choice List, the versions (1.1.0 to 1.2.0), Update Now first, what it does",
             says?("KIF Update") && says?("1.1.0") && says?("1.2.0") && says?("Update Now") && says?("Skip This Version") &&
             says?("then restarts the game")) },
  at { check("...the toast gone while it's open", !UCS.checking? && !says?("Checking for Updates")) },
  I::DOWN, I::USE,
  dmp("uc_06_notes"),
  at { check("What's New: KIF's notes, a line each", says?("What's New") && says?("Faster start-up.") && says?("Shinies sparkle again.")) },
  I::USE, I::USE,
  at { check("...back on the list, on What's New", says?("What changed in 1.2.0.")) },
  I::DOWN, I::USE
])
check("Later: no update, nothing skipped", !$log.include?("KIF UPDATED") && $skipped.nil?)
startup("C skip", [
  I::DOWN, I::DOWN, I::DOWN, I::USE,
  at { check("Skip This Version: KIF's word as a notice", says?("You won't be asked about 1.2.0 again.")) },
  I::USE
])
check("...1.2.0 skipped", $skipped == "1.2.0")
startup("C skipped", [])
check("skipped: nothing asked next time, the checks ran through", $log.include?("FIRST CHOICE (checking shown: no)"))
$skipped = nil
startup("C update now", [
  I::USE,
  nil,
  at { check("Update Now: KIF's question as Yes and No", says?("12 files to download") && says?("Yes") && says?("No")) },
  I::USE,
  dmp("uc_07_download"),
  at { check("...the download's wait: the bar and B to cancel", says?("Updating to KIF 1.2.0") && says?("1.2 MB of 3.4 MB") && says?("Cancel")) },
  nil,
  at { check("...then KIF's word that it restarts", says?("KIF 1.2.0 is ready.")) },
  I::USE
])
check("...updated", $log.include?("KIF UPDATED"))

#---------------------------------------------------------------- D: Updates Off, Startup Mod-Check Off, Reloaded Load Screen Off
$channel = 2
startup("D updates off", [at { check("Updates Off: nothing shows", !UCS.checking? && !says?("Checking for Updates")) }])
$channel = 0
$remote = "1.2.0"
$due = true
$ups = MODS
S.set(Reloaded::Saves::MOD_CHECK, false)
startup("D startup checks off", [])
check("Startup Mod-Check Off: nothing comes up, neither check runs, KIF's first-start questions still do (#{$log.inspect})",
      $log.include?("FIRST CHOICE (checking shown: no)") && $log.none? { |l| l.start_with?("MSG", "KIF STATUS", "OPEN MODS", "INSTALLED") } &&
      !UCS.checking?)
S.set(Reloaded::Saves::MOD_CHECK, true)
$due = true
S.set(Reloaded::Saves::LOAD_SCREEN, false)
startup("D KIF's own", [])
check("...KIF's own runs before the load screen, as KIF has it", !$held && $log.index { |l| l.start_with?("MSG KIF 1.2.0") } < $log.index("LOAD SCREEN SHOWN"))
check("Reloaded Load Screen Off: KIF's own questions and wait (#{$log.grep(/MSG|KIF STATUS/).length})",
      $log.any? { |l| l.start_with?("MSG KIF 1.2.0 is out") } && $log.any? { |l| l.start_with?("KIF STATUS Reading the mod list") } &&
      $log.any? { |l| l.start_with?("MSG Updates for 3 mods") })
S.set(Reloaded::Saves::LOAD_SCREEN, true)
check("title case for KIF's titles (#{UCS.title_case("Reading the mod list")})",
      UCS.title_case("Reading the mod list") == "Reading the Mod List" && UCS.title_case("Updating to KIF 1.2.0") == "Updating to KIF 1.2.0")

errors = File.read(Reloaded::Log.path).lines.grep(/ERROR|skipped/)
check("no errors or skipped hooks in Kanto Reloaded's log (#{errors.length})", errors.empty?)
errors.first(6).each { |l| puts "  " + l }
puts $failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED"
exit($failed ? 1 : 0)
