# encoding: utf-8
# Mockups: the "open" buttons on phones (no File Explorer, links may not
# open), three designs on the real "Bug Report Made" notice (the Bug Reports
# preview's own flow), each with what its button leads to:
#   A Copy Instead: Copy the Path / Copy the Link, then a short "Copied"
#   B Hide Them: phones don't get the two buttons
#   C Show Where: Where It Is / The Link, then a popup with the text written out
# The same goes for the Save Checker's "Report Saved" and the Save Manager's
# Open Folder.
# Usage (from this folder): ruby phone_buttons_designs.rb "<KIF Beta>" <work dir with metrics.json>
TEST = File.join(ARGV[0], "Mods/KantoReloaded/Tools/Tests/bug_report_preview.rb")
eval(File.read(TEST, :encoding => "UTF-8").split("#---------------------------------------------------------------- Make a Bug Report")[0], binding, TEST)

$design = nil
SWAP = {
  "A" => { "Open the Folder" => "Copy the Path", "Open Discord" => "Copy the Link" },
  "B" => { "Open the Folder" => nil, "Open Discord" => nil },
  "C" => { "Open the Folder" => "Where It Is", "Open Discord" => "The Link" }
}
Reloaded::Notice.singleton_class.prepend(Module.new do
  def show(**opts)
    if $design && opts[:buttons] && opts[:title] == _INTL("Bug Report Made")
      m = SWAP[$design]
      opts = opts.merge(:buttons => opts[:buttons].map { |b| m.key?(b) ? m[b] : b }.compact)
    end
    super(**opts)
  end
end)
# what a pressed button leads to, per design
BR.launcher = proc do |kind, x|
  case $design
  when "A"
    Reloaded::Notice.show(:title => _INTL("Copied"), :colour => Reloaded::Notice::GREEN,
                          :body => kind == :folder ? _INTL("Where your report is, ready to paste.") : _INTL("Discord's link, ready to paste in your browser."),
                          :buttons => [_INTL("OK")])
  when "C"
    Reloaded::Notice.show(:title => kind == :folder ? _INTL("Where It Is") : _INTL("The Link"), :colour => Reloaded::Notice::BLUE,
                          :sub => kind == :folder ? _INTL("Kanto Reloaded's Bug Reports folder") : _INTL("Kanto Reloaded's Discord"),
                          :body => kind == :folder ? "In the game's folder:\nMods/KantoReloaded/Bug Reports/\n#{File.basename(x.to_s)}" : x.to_s,
                          :buttons => [_INTL("OK")])
  end
end

def run_design(d, queue)
  $design = d
  Input.queue = queue
  Reloaded::BugReportScreen.open
rescue Exception => e
  puts "design #{d}: #{e.class}: #{e.message} #{e.backtrace.first(3).inspect}"
ensure
  $design = nil
end

# A: the notice, then Copy the Path's "Copied"
run_design("A", [I::X, dmp("PB_A1_notice"), I::USE, dmp("PB_A2_copied"), I::USE, at { $design = nil }, I::RIGHT, I::RIGHT, I::USE])
# B: the notice, only Done
run_design("B", [I::X, dmp("PB_B1_notice"), at { $design = nil }, I::RIGHT, I::RIGHT, I::USE])
# C: the notice, then Where It Is
run_design("C", [I::X, dmp("PB_C1_notice"), I::USE, dmp("PB_C2_where"), I::USE, at { $design = nil }, I::RIGHT, I::RIGHT, I::USE])
puts "designs done"
