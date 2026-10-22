# encoding: utf-8
# Offline checks for the Hook Checker (Dev, never in a release).
# Boots the mod on the foundation tests' stand-ins, hooks test classes loaded
# from files, then plays a KIF update: methods change, one loses an
# argument, one goes, and the checker has to say so.
# Usage: ruby Dev/Tests/hook_check_test.rb <KIF Beta root> <empty temp folder>
require "fileutils"

KIF_ROOT = ARGV[0]
USERDIR = ARGV[1]
require_relative "../../Tools/Tests/work_folder"
KRWork.claim(USERDIR)
$log = []
$failed = false

def check(label, cond)
  puts "#{cond ? "ok  " : "FAIL"} #{label}"
  $failed = true unless cond
end

load File.join(KIF_ROOT, "Mods/KantoReloaded/Tools/Tests/test_stubs.rb")
class PokemonSystem; attr_accessor :runstyle, :textskin; end
module KIF; PORT_VERSION = "1.0" unless const_defined?(:PORT_VERSION, false); end

# The "game's" code, from files (so the checker can read the bodies)
FIX = File.join(USERDIR, "fixtures")
FileUtils.mkdir_p(FIX)
def fixture(name, text)
  path = File.join(FIX, name)
  File.write(path, text)
  load path
end
fixture("widget.rb", <<~RUBY)
  class HCWidget
    def greet(name)
      "hi " + name
    end

    def size(a, b)
      a + b
    end

    def gone_soon
      1
    end

    def pif_items(list)
      list
    end

    def self.make(x)
      x
    end
  end
RUBY
fixture("other_mod.rb", <<~RUBY)
  class HCWidget
    alias other_greet greet
    def greet(name)
      other_greet(name) + "!"
    end
  end
RUBY

load File.join(KIF_ROOT, "Mods/KantoReloaded/Bootstrap.rb")
R = Reloaded
HC = R::HookCheck
check("boots with the Dev folder (#{R::Bootstrap.status}, #{R::Bootstrap.failures.inspect})", R::Bootstrap.status == :ready && defined?(R::HookCheck))
check("Hook Check is a Developer button, hidden while DEBUG is off", R::Settings.definition(:"developer.hook_check")[:type] == :button &&
      !R::Settings.page_visible?(:developer))
$DEBUG = true
check("...and shown with it on", R::Settings.page_visible?(:developer))
$DEBUG = false

H = R::Hooks
module HCPre; def gone_soon; super + 1; end; def hc_label; "a helper"; end; end   # hc_label: the module's own, nothing under it
H.around(nil, HCWidget, :greet, :id => :hc_greet) { |o, n| o.call(n) }
H.around(nil, HCWidget, :size, :id => :hc_size) { |o, a, b| o.call(a, b) }
H.prepend(nil, HCWidget, HCPre, :id => :hc_gone)
H.around(nil, HCWidget.singleton_class, :make, :id => :hc_make) { |o, x| o.call(x) }
H.around(nil, HCWidget, :pif_items, :id => :hc_items) { |o, l| o.call(l) }
H.around(nil, HCWidget, :no_such, :id => :hc_missing) { |o| o.call }
H.around(nil, "HCNoSuchClass", :x, :id => :hc_noclass) { |o| o.call }
H.needs(:field, :no_such_field, :id => :hc_need)
check("a hook records where it was made", H.registry.find { |e| e[:id] == "hc_size" }[:where].to_s.include?("hook_check_test.rb:"))
check("skipped hooks are kept with their reason",
      H.skipped.map { |s| [s[:id], s[:reason]] }.include?(["hc_missing", "method not found"]) &&
      H.skipped.map { |s| s[:id] }.include?("hc_noclass"))

def result(run, id); run.results.find { |r| r.id == id.to_s }; end

#---------------------------------------------------------------- the first check
run = HC.check(:boot)
check("the first check: KIF's version is new to it", run.version_changed && run.first && run.version == "1.0")
check("a prepended module's own helper (nothing of the target's under it) isn't a hook",
      run.results.count { |r| r.id == "hc_gone" } == 1 && run.results.none? { |r| r.target.to_s.include?("hc_label") })
check("a method that isn't there: Broken, with its hook's place", result(run, :hc_missing).kind == :broken &&
      result(run, :hc_missing).where.to_s.include?("hook_check_test.rb"))
check("a class that isn't there: Broken", result(run, :hc_noclass).kind == :broken && result(run, :hc_noclass).what.include?("HCNoSuchClass"))
g = result(run, :hc_greet)
check("a method another file wraps by alias: Shared (#{g.kind}, #{g.others.inspect})", g.kind == :shared &&
      g.others.any? { |o| o[:how] == "alias" && o[:who] == "other_mod.rb" } && g.others.first[:ours])
check("a plain hook: OK", result(run, :hc_size).kind == :ok)
check("a $PokemonSystem field that isn't there: Missing", result(run, :no_such_field).kind == :missing)
check("the fields Kanto Reloaded reads are there", result(run, :runstyle).kind == :ok && result(run, :textskin).kind == :ok)
check("mod.json's lock and module are checked", run.needs.any? { |r| r.need == "Lock" && r.name == "cody_battleinfo" } &&
      run.needs.any? { |r| r.need == "Module" && r.name == "auto_battle" })
check("the report is written", run.report && File.file?(run.report) && File.basename(run.report) == "Hook Check 1.0.md")
rep = File.read(run.report, :encoding => "UTF-8")
check("the report: real headings in the chosen order", rep.start_with?("# Hook Check: KIF Beta 1.0\n") &&
      %w[Broken Changed\ Upstream Others\ on\ the\ Same\ Method Takeovers\ and\ Settings OK].map { |h| rep.index("\n## #{h}\n") }.each_cons(2).all? { |a, b| a && b && a < b })
check("...a count table", rep.include?("| Broken | #{run.count(:broken)} |") && rep.include?("| Result | Count |"))
check("...the first check says there's nothing to compare yet", rep.include?("Nothing to compare yet"))
check("the saved copy is kept", File.file?(HC.state_path))
again = HC.check(:boot)
check("the same KIF again at boot: no alert, no new report", !again.version_changed && again.report.nil?)
check("...and what it checked is kept in a small file of its own (#{File.read(HC.stamp_path).strip})",
      File.file?(HC.stamp_path) && File.read(HC.stamp_path).include?("\"kif\":\"1.0\"") && !HC.needs_check?)
before = HC.last
HC.instance_variable_set(:@load_screen_done, nil)
HC.at_load_screen
check("the Main Menu with the same KIF and the same hooks: no check at all, so it isn't held up", HC.last.equal?(before))

#---------------------------------------------------------------- KIF updates
KIF.send(:remove_const, :PORT_VERSION)
KIF.const_set(:PORT_VERSION, "1.1")
fixture("widget_v2.rb", <<~RUBY)
  class HCWidget
    def size(a, b)
      total = a + b
      total
    end

    def self.make(x, y)
      x + y
    end
  end
RUBY
HCWidget.send(:remove_method, :gone_soon)
HCWidget.send(:remove_method, :pif_items)
HCWidget.send(:define_method, :pif_rows) { |list| list }
check("a new KIF: the Main Menu's check would run", HC.needs_check?)
run = HC.check(:boot)
check("KIF updated: compared with the copy from 1.0", run.version_changed && !run.first && run.previous == "1.0")
s = result(run, :hc_size)
check("a new body with the same arguments: Changed Upstream, with the diff (+#{s.added} -#{s.removed})",
      s.kind == :changed && s.added == 2 && s.removed == 1 && s.diff.include?([:add, "    total = a + b"]))
m = result(run, :hc_make)
check("arguments changed: Broken (#{m.what})", m.kind == :broken && m.what.include?("(x) is now (x, y)"))
gs = result(run, :hc_gone)
check("a prepend with nothing under it: Broken (#{gs.what})", gs.kind == :broken && gs.what.include?("gone"))
check("...while the module's own helper still isn't one", run.results.count { |r| r.id == "hc_gone" } == 1 &&
      run.results.none? { |r| r.target.to_s.include?("hc_label") })
it = result(run, :hc_items)
check("...and a renamed method is suggested: #{it.what}", it.kind == :broken && it.what.include?("`pif_rows` instead") &&
      it.fix == "Hook `pif_rows`; it takes the same arguments.")
rep = File.read(run.report, :encoding => "UTF-8")
check("the report for 1.1: Broken, then the diff in Changed Upstream", rep.include?("### hc_make: HCWidget.make") &&
      rep.include?("### hc_size: HCWidget#size") && rep.include?("```diff") && rep.include?("+     total = a + b") &&
      rep.include?("- **Check:**") && rep.include?("(last checked: 1.0)"))
check("...Others on the Same Method as a table", rep.include?("### HCWidget#greet") && rep.include?("| 1 | Kanto Reloaded: hc_greet | prepend |") &&
      rep.include?("| other_mod.rb | alias |"))
check("the problems come most serious first", run.problems.map(&:kind).each_cons(2).all? { |a, b| HC::KINDS.index(a) <= HC::KINDS.index(b) })
manual = HC.check(:manual)
check("Run Again on the same KIF still compares with 1.0, and writes the report", !manual.version_changed &&
      result(manual, :hc_size).kind == :changed && manual.report)
KIF.send(:remove_const, :PORT_VERSION)
KIF.const_set(:PORT_VERSION, "1.2")
run = HC.check(:boot)
check("the next KIF compares with 1.1: the old change isn't news any more", run.previous == "1.1" && result(run, :hc_size).kind == :ok)

#---------------------------------------------------------------- parts
D = HC::Diff
ops = D.lines(%w[a b c d], %w[a x c d e])
check("diff: a change and an addition", ops == [[:same, "a"], [:del, "b"], [:add, "x"], [:same, "c"], [:same, "d"], [:add, "e"]] &&
      D.counts(ops) == [2, 1])
long = (1..20).map(&:to_s)
h = D.hunks(D.lines(long, long.map { |x| x == "3" || x == "17" ? x + "!" : x }), 1)
check("diff hunks: context around each change, a gap between", h.count { |k, _| k == :gap } == 1 && h.first == [:same, "2"])
check("owners: a KIF feature folder", HC.owner_of("FrameRate.rb") == "KIF: C-SYS-01_FrameRate")
check("owners: KIF's core files", HC.owner_of("016_KIF_SettingsScreen.rb") == "KIF: 016_KIF_SettingsScreen")
check("owners: PIF's own scripts", HC.owner_of("013_UI_Load.rb") == "PIF: 013_UI_Load.rb")
check("owners: Kanto Reloaded", HC.owner_of(File.join(R::ROOT, "Core", "Foundation", "Hooks.rb")) == "Kanto Reloaded")
check("targets: a class method and an instance method", HC.target_name(HCWidget.singleton_class, :make) == "HCWidget.make" &&
      HC.target_name(HCWidget, :size) == "HCWidget#size")
body = HC.method_body(File.join(FIX, "widget_v2.rb"), 2)
check("a method's body, from def to its end", body == "  def size(a, b)\n    total = a + b\n    total\n  end")

#---------------------------------------------------------------- the same keys every start
a = HC.key_of(:id => :crash, :target => "#<Class:#<Object:0x0000019a8c6102d0>>", :method => :pbPrintException)
b = HC.key_of(:id => :crash, :target => "#<Class:#<Object:0x00000277a42702e0>>", :method => :pbPrintException)
check("a hook on one object's own methods has the same key every start (#{a})", a == b && !a.include?("0x"))

#---------------------------------------------------------------- a hook added
check("before: nothing to check", !HC.needs_check?)
H.around(nil, HCWidget, :size, :id => :hc_added_later) { |original, *args| original.call(*args) }
check("a hook added (Kanto Reloaded updated): the Main Menu notices it", HC.needs_check?)
before = HC.last
HC.instance_variable_set(:@load_screen_done, nil)
HC.at_load_screen
key = HC.key_of(H.registry.find { |e| e[:id] == "hc_added_later" })
check("...and only notes the new hook (no full check, so the Main Menu isn't held up)",
      HC.last.equal?(before) && HC.send(:load_state)["baseline"].has_key?(key) && !HC.needs_check?)

errors = File.read(R::Log.path).lines.grep(/ERROR/)
check("no errors in the log (#{errors.length})", errors.empty?)
errors.first(4).each { |l| puts "  " + l }
puts($failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED")
exit($failed ? 1 : 0)
