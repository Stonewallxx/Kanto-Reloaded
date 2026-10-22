# encoding: utf-8
# Checks for the Style Checker (Tools/StyleCheck/style_check.rb) on a
# made-up mod: every rule, the Ignore List, the report and Fix It for Me.
# Usage: ruby Tools/Tests/style_check_test.rb <empty temp folder>
require "fileutils"
require "stringio"
load File.join(File.dirname(__FILE__), "..", "StyleCheck", "style_check.rb")

WORK = ARGV[0]
require_relative "work_folder"
KRWork.claim(WORK)
MOD = File.join(WORK, "TestMod")
OUT = File.join(WORK, "Logs")
FileUtils.mkdir_p(File.join(MOD, "Core"))
FileUtils.mkdir_p(File.join(MOD, "Tools"))
$failed = false

def check(label, cond)
  puts "#{cond ? "ok  " : "FAIL"} #{label}"
  $failed = true unless cond
end

File.write(File.join(MOD, "mod.json"), '{ "name": "Test Mod", "version": "1.2.0" }')
SOURCE = <<~'RUBY'
  module TestMod
    ACTIONS = [
      [:dash, "Quick dash", "Runs fast: hold the button."],
      [:swap, "Swap A and B", "Swaps two buttons."]
    ]
    def self.boot
      register(:"x.speed", :name => "Speed up the Game", :description => "How fast the game runs. Speedup makes it faster.")
      register(:"x.hue", :name => "Menu Colour.", :values => ["Red", "Light blue", "2x"],
               :description => "The colour of menus:  pick one.")
      hint(_INTL("Press Enter to save"), _INTL("Type to Search"), _INTL("of"))
      Reloaded::Log.info("Not text: a log line about colours")
      path = "Graphics/Windowskins/Theme Dark"
    end
  end
RUBY
File.write(File.join(MOD, "Core", "Test.rb"), SOURCE)
File.write(File.join(MOD, "Tools", "Skipped.rb"), 'x = _INTL("Colour of tools")')

SC = StyleCheck
found = SC.check(MOD)
def has(found, rule, raw); found.any? { |f| f.rule == rule && f.raw == raw }; end
check("a table's description: a capital after its colon", has(found, :colon, "Runs fast: hold the button."))
check("...the fix", found.find { |f| f.rule == :colon && f.raw.start_with?("Runs") }.fix == "Runs fast: Hold the button.")
check("a table's name: Title Case", has(found, :title_case, "Quick dash"))
check("a setting's name: Title Case, connecting words lowercase", has(found, :title_case, "Speed up the Game") &&
      SC.fix_title("Speed up the Game") == "Speed Up the Game")
check("choices are labels; numbers are left alone", has(found, :title_case, "Light blue") && !found.any? { |f| f.raw == "2x" })
check("Title Case keeps capitals and accents", SC.fix_title("KIF Settings for Pokémon-style play") == "KIF Settings for Pokémon-Style Play")
check("a connecting word right after a colon is a capital", SC.fix_title("Speed: of the Game") == "Speed: Of the Game")
check("Colour, wherever it is", has(found, :color, "Menu Colour.") && SC.fix_color("Colours and colour, COLOUR") == "Colors and color, COLOR")
check("official names: Speed-Up as written", has(found, :names, "How fast the game runs. Speedup makes it faster.") &&
      found.find { |f| f.rule == :names }.fix == "How fast the game runs. Speed-Up makes it faster.")
check("double spaces", has(found, :double, "The colour of menus:  pick one."))
check("a label with a period", has(found, :period, "Menu Colour."))
check("a keyboard-only hint (no automatic fix)", has(found, :keyboard, "Press Enter to save") &&
      found.find { |f| f.rule == :keyboard }.fix.nil?)
check("a piece of a sentence isn't a label", !found.any? { |f| f.raw == "of" })
check("log lines, paths and the Tools folder aren't text", !found.any? { |f| f.raw.include?("log line") || f.raw.include?("Windowskins") || f.file.start_with?("Tools") })
check("in the rules' order", found.map { |f| SC::RULES.keys.index(f.rule) }.each_cons(2).all? { |a, b| a <= b })

#---------------------------------------------------------------- the report
findings, ignored, path = SC.run(MOD, OUT)
rep = File.read(path, :encoding => "UTF-8")
check("the report: Logs/Style Check Test Mod.md", File.basename(path) == "Style Check Test Mod.md")
check("...real headings: a count table, then each rule's findings", rep.start_with?("# Style Check: Test Mod 1.2.0\n") &&
      rep.include?("| Capital After a Colon | 2 |") && rep.include?("## Capital After a Colon") && rep.include?("### Core/Test.rb:3") &&
      rep.include?("- **Fix:** Runs fast: Hold the button."))
check("...a finding with no automatic fix says so", rep.include?("- **Fix:** By hand:"))

#---------------------------------------------------------------- Fix It for Me
# colon (2): y, n; title case (Quick dash, Swap A and B, then two more): i, i, a; color: q
answers = StringIO.new("y\nn\ni\ni\na\nq\n")
log = StringIO.new
r = SC.fix_it(MOD, OUT, answers, log)
text = File.read(File.join(MOD, "Core", "Test.rb"), :encoding => "UTF-8")
screen = log.string
check("each fix shows its rule, place, before and after, and the choices",
      screen.include?("1 of ") && screen.include?("Capital After a Colon") && screen.include?("Core\\Test.rb:3") &&
      screen.include?("- Runs fast: hold the button.") && screen.include?("+ Runs fast: Hold the button.") &&
      screen.include?("[Y] Fix   [N] Skip   [I] Ignore from now on   [A] Fix all"))
check("Y fixes it in the file", text.include?('"Runs fast: Hold the button."'))
check("N leaves it", text.include?("menus:  pick") || text.include?("menus: pick"))
check("I puts it on the Ignore List (style_check.json), the text as it was",
      File.read(File.join(MOD, "style_check.json")).include?("Quick dash") && text.include?('"Quick dash"') && text.include?('"Swap A and B"'))
check("A fixes the rest of that rule without asking", text.include?('"Speed Up the Game"') && text.include?('"Light Blue"'))
check("Q stops: the rest is left for next time", text.include?("Menu Colour.") && r[:skipped].length >= 2)
check("the changed file was backed up first, as it was", File.read(File.join(r[:backup], "Core", "Test.rb"), :encoding => "UTF-8") == SOURCE)
check("the end says what was fixed, skipped and changed, and where the backup is",
      screen.include?("Done.") && screen.include?("Fixed") && screen.include?("Skipped") && screen.include?("Changed   Test.rb") &&
      screen.include?("Style Fixes "))
again = SC.check(MOD, SC.load_config(MOD)).reject { |f| SC.ignored?(SC.load_config(MOD), f) }
check("checked again: the ignored one stays away", !again.any? { |f| f.raw == "Quick dash" })

# two fixes on one string: Colour and the period on "Menu Colour."
r2 = SC.fix_it(MOD, OUT, StringIO.new("a\n" * 12), StringIO.new)
text = File.read(File.join(MOD, "Core", "Test.rb"), :encoding => "UTF-8")
check("two fixes on one string both land (#{text[/:name => "Menu[^"]*"/]})", text.include?(':name => "Menu Color"'))
check("...and the description's colour, colon and double space (#{text[/menus[^"]*"/]})", text.include?('"The color of menus: Pick one."'))
left = SC.check(MOD, SC.load_config(MOD)).reject { |f| SC.ignored?(SC.load_config(MOD), f) }
check("only the hand fixes are left (#{left.map(&:rule).inspect})", left.map(&:rule) == [:keyboard])

#---------------------------------------------------------------- the command
ok = system(RbConfig.ruby, File.join(File.dirname(__FILE__), "..", "StyleCheck", "style_check.rb"), MOD, "--out", OUT, :out => File::NULL)
check("the command exits 1 while something's found (for the Release Builder)", ok == false && $?.exitstatus == 1)
system(RbConfig.ruby, File.join(File.dirname(__FILE__), "..", "StyleCheck", "style_check.rb"), "--nope", :err => File::NULL)
check("...and 2 for a usage error", $?.exitstatus == 2)

puts $failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED"
exit($failed ? 1 : 0)
