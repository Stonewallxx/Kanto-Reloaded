# encoding: utf-8
# Offline preview of the Hook Checker's screens (Dev, never in a release):
# the results (List and Detail) and the Update Alert, on the preview tool's
# stand-ins (Tools/UIPreview/preview.rb), driven with button presses.
# Usage: ruby   Dev/Tests/hook_check_preview.rb "<KIF Beta>" <work dir with metrics.json>
#        python Tools/UIPreview/render.py "<KIF Beta>\Fonts" <work dir>
PREVIEW_SETUP_ONLY = true
load File.join(ARGV[0], "Mods/KantoReloaded/Tools/UIPreview/preview.rb")
HC = Reloaded::HookCheck
check("the Hook Checker's screens load in the preview", defined?(HC::Screen) && defined?(HC::Alert))

# A run like the one in the designs: KIF Beta 0.21.55 to 0.21.60
def demo_run(problems = true)
  run = HC::Run.new
  run.version = "0.21.60"
  run.previous = "0.21.55"
  run.version_changed = true
  run.report = File.join(Reloaded::Paths.logs_dir, "Hook Check 0.21.60.md")
  rs = run.results
  if problems
    rs << HC::Result.new(:broken, :autosave_rows, :target => "KIF::SettingsScreen.pif_items", :method_key => "KIF::SettingsScreen.pif_items",
      :where => "Core/Settings/AutosaveRows.rb:32",
      :what => "The method is gone. KIF 0.21.60 has `pif_rows` instead.",
      :effect => "The hook is skipped at boot, so this part of Kanto Reloaded falls back to the game's own code.",
      :fix => "Hook `pif_rows`; it takes the same arguments.")
    rs << HC::Result.new(:missing, "cody_battleinfo", :need => "Lock", :name => "cody_battleinfo", :where => "mod.json",
      :what => "KIF has no setting cody_battleinfo any more.", :effect => "The lock in mod.json does nothing.")
    old = ["def self.description_for(opt)", "  d = DESCRIPTIONS[opt.name.to_s.strip]", "  return nil unless d", "  return KIF::Keys.fill(_INTL(d))", "end"]
    new = ["def self.description_for(opt)", "  d = DESCRIPTIONS[opt.name.to_s.strip]", "  return nil unless d", "  text = KIF::Keys.fill(_INTL(d))",
           "  text = KIF::Locks.note(opt, text) if KIF::Locks.get(opt.name)", "  return text", "end"]
    ops = HC::Diff.lines(old, new)
    added, removed = HC::Diff.counts(ops)
    %w[kif_bridge_descriptions controls_kif_descriptions].each do |id|
      rs << HC::Result.new(:changed, id, :target => "KIF::SettingsScreen.description_for", :method_key => "KIF::SettingsScreen.description_for",
        :where => id.start_with?("kif") ? "Core/Settings/KIFBridge.rb:87" : "Core/Controls/Splits.rb:198",
        :diff => ops, :added => added, :removed => removed,
        :check => "KIF now adds a lock note itself; locked rows may show it twice.")
    end
    rs << HC::Result.new(:shared, :controls_extra_actions, :target => "Scene_Map#update", :method_key => "Scene_Map#update",
      :where => "Core/Controls/ExtraActions.rb:43",
      :others => [{ :who => "Kanto Reloaded: controls_extra_actions", :how => "prepend", :ours => true },
                  { :who => "KIF: C-SYS-01_FrameRate", :how => "alias", :ours => false },
                  { :who => "Mod: MultiPlayer", :how => "alias", :ours => false }])
  end
  18.times { |i| rs << HC::Result.new(:ok, "hook_#{i}", :target => "Something#x", :method_key => "Something#x") }
  run
end

def drive_hc(label, queue)
  Input.queue = queue.dup
  yield
  check("#{label}: opened and closed", true)
rescue QueueEmpty => e
  check("#{label}: #{e.message}", false)
rescue Exception => e
  check("#{label}: #{e.class}: #{e.message} #{e.backtrace.first(4).inspect}", false)
end

def hcs; $hc_screen; end
HC::Screen.prepend(Module.new { def main; $hc_screen = self; super; end })
def sel; hcs.instance_variable_get(:@sel); end
def cur; hcs.send(:current); end

run = demo_run
drive_hc("results", [
  dmp("hc_01_results_broken"),
  at { check("the list: every problem, most serious first (#{hcs.send(:rows).map(&:kind).inspect})",
             hcs.send(:rows).map(&:kind) == [:broken, :changed, :changed, :shared, :missing]) },
  at { check("the hint line: Select, Open Report, Run Again, Back", hcs.send(:hint_pairs).map { |p| p[1] } == ["Select", "Open Report", "Run Again", "Back"]) },
  I::DOWN,
  dmp("hc_02_results_changed"),
  at { check("Down: the next problem (#{cur.id})", cur.id == "kif_bridge_descriptions") },
  I::DOWN, I::DOWN,
  dmp("hc_03_results_shared"),
  I::DOWN,
  dmp("hc_04_results_missing"),
  I::DOWN,
  at { check("a fresh Down from the last goes round to the first", sel == 0) },
  [:move, 100, 42 + 28 + 10],
  at { check("the mouse over a row picks it (#{sel})", sel == 1) },
  I::BACK
]) { HC::Screen.new(run).main }

drive_hc("results, all OK", [dmp("hc_05_results_ok"), I::BACK]) { HC::Screen.new(demo_run(false)).main }

# Run Again: a bar that moves with the check's real steps, then what it found
$steps = []
HC.singleton_class.prepend(Module.new do
  def check(reason = :manual, &progress)
    return super unless progress
    super(reason) { |step, steps, label| $steps << [step, steps]; progress.call(step, steps, label) }
  end
end)
def progress_drawn?(word); hcs.overlay.ops.any? { |o| o[0] == "text" && o[5].to_s.include?(word) }; end
drive_hc("run again", [
  at { $before = hcs.instance_variable_get(:@run) },
  I::X,
  dmp("hc_06_run_again_done"),
  at { check("Y runs the check again, the bar stepping with it (#{$steps.length} steps, ending #{$steps.last.inspect})",
             hcs.instance_variable_get(:@run) != $before && $steps.length > 4 && $steps.last[0] == $steps.last[1] &&
             $steps.each_cons(2).all? { |a, b| b[0] > a[0] }) },
  at { check("...then says what it found (and where the report is)", progress_drawn?("Shared") && progress_drawn?("Report:")) },
  at { hcs.send(:paint_progress, 12, 62, "Reading KIF::SettingsScreen.description_for"); dump("hc_07_run_again_progress");
       hcs.send(:paint_progress, 1, 1, nil, true) },
  I::USE,
  at { check("a button closes it, back to the results", hcs.overlay.ops == [["clear"]]) },
  I::BACK
]) { HC::Screen.new(demo_run).main }

opened = false
HC::Screen.singleton_class.prepend(Module.new { define_method(:open) { |r = nil| opened = true; super(r) } })
# the words the pixel font draws, so a button's label can be checked
$hc_texts = []
Reloaded::Pixel.singleton_class.prepend(Module.new { def text(b, x, y, w, h, str, *r); $hc_texts << str.to_s; super; end })
drive_hc("alert", [
  dmp("hc_10_alert"),
  at { check("the alert's buttons: Open Results and Close (not Later)",
             $hc_texts.include?("Open Results") && $hc_texts.include?("Close") && !$hc_texts.include?("Later")) },
  I::RIGHT,
  dmp("hc_11_alert_close"),
  I::LEFT, I::USE,
  at { check("Open Results opens the results", opened && hcs) },
  I::BACK
]) { HC::Alert.show(run) }
drive_hc("alert, all OK", [dmp("hc_12_alert_ok"), I::USE]) { HC::Alert.show(demo_run(false)) }

# The border is the most serious finding's colour; other code on the same
# methods alone isn't a problem
def only(kinds); r = demo_run; r.results.select! { |x| x.kind == :ok || kinds.include?(x.kind) }; r; end
check("the alert's border: red for broken or missing, gold for changed, blue for shared alone, green for all OK",
      HC::Alert.border(demo_run) == HC::Screen::RED && HC::Alert.border(only([:missing])) == HC::Screen::RED &&
      HC::Alert.border(only([:changed, :shared])) == HC::Screen::GOLD && HC::Alert.border(only([:shared])) == HC::Screen::BLUE &&
      HC::Alert.border(demo_run(false)) == HC::Screen::GREEN)
shared_only = only([:shared])
shared_only.previous = nil
shared_only.first = true
drive_hc("alert, shared methods only", [dmp("hc_13_alert_shared"), I::BACK]) { HC::Alert.show(shared_only) }

# Kanto Reloaded > Developer Tools > Hook Check, only with KIF's DEBUG option on
def kr_rows(screen); (screen.instance_variable_get(:@rows)[:kanto_reloaded] || []).map(&:label); end
def placed_elsewhere(screen)
  screen.instance_variable_get(:@rows).reject { |id, _| id == :kanto_reloaded }.values.flatten.select { |r| r.label == "Hook Check" }
end
drive("DEBUG off", [
  at { check("DEBUG off: Hook Check is nowhere (#{placed_elsewhere(scr).map(&:section).inspect})",
             !kr_rows(scr).include?("Hook Check") && placed_elsewhere(scr).empty?) },
  I::BACK
])
$DEBUG = true
$hc_screen = nil
drive("DEBUG on", [
  at { check("DEBUG on: Hook Check last in the Kanto Reloaded section, under Developer Tools (#{kr_rows(scr).last(2).inspect})",
             kr_rows(scr).last(2) == ["Developer Tools", "Hook Check"] && placed_elsewhere(scr).empty?) },
  at { scr.instance_variable_set(:@section, scr.instance_variable_get(:@sections).index { |x| x[0] == :kanto_reloaded }) },
  I::RIGHT, [:held, I::UP], I::UP,
  at { check("on Hook Check (#{row_name})", row_name == "Hook Check") },
  dmp("hc_30_developer_row"),
  I::USE,
  at { check("A opens the results", !hcs.nil?) },
  I::BACK, I::BACK, I::BACK
])
$DEBUG = false

# The real check on the preview's stand-ins, to see it run end to end
real = HC.check(:manual)
check("the real check runs here and writes its report (#{real.count(:broken)} broken, #{real.ok_hooks} OK)", real.report && File.file?(real.report))
drive_hc("results of the real check", [dmp("hc_20_real"), I::BACK]) { HC::Screen.new(real).main }

errors = File.read(Reloaded::Log.path).lines.grep(/ERROR/)
check("no errors in the log (#{errors.length})", errors.empty?)
errors.first(6).each { |l| puts "  " + l }
puts $failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED"
exit($failed ? 1 : 0)
