# Offline checks for KIF's C-SYS-08_Controllers (the PR), on its own: KIF's
# log, the engine's Input and its SDL are stood in; nothing of Kanto Reloaded.
# Usage: ruby kif_controllers_test.rb <KIF-Beta-PRs clone root>
ROOT = ARGV[0]
$failed = false
def check(label, cond)
  puts "#{cond ? "ok  " : "FAIL"} #{label}"
  $failed = true unless cond
end

$kif_log = []
module KIF
  def self.log(msg); $kif_log << msg; end
  module Paths
    def self.root; ROOT; end
  end
end
# The engine's Input (C methods have no source location; these are Ruby, which is fine here)
module Input
  @updates = 0
  class << self
    attr_reader :updates
    def update; @updates += 1; :engine; end
  end
  module Controller
    @connected = false
    class << self
      attr_accessor :connected, :name
      def connected?; @connected; end
    end
  end
end
def log_has(text); $kif_log.count { |l| l.include?(text) }; end

load File.join(ROOT, "Data/Scripts/990_KIF/ZZ_Cody/C-SYS-08_Controllers/Controllers.rb")
C = KIF::Controllers

#---------------------------------------------------------------- without Win32API
r = Input.update
check("Input.update still runs the engine's, and returns what it did", r == :engine && Input.updates == 1)
check("without Win32API it logs why, once, and stops (#{$kif_log.inspect})",
      log_has("Controllers: the engine's SDL couldn't be used (RuntimeError: Win32API isn't here)") == 1)
Input.update
check("...and does nothing after", $kif_log.length == 1)

#---------------------------------------------------------------- the engine's SDL, stood in
$devs = [["Wireless Controller", 0x054c, 0x0ce6, true], ["8BitDo Pro 2", 0x2dc8, 0x6003, false],
         ["8BitDo Ultimate", 0x2dc8, 0x3011, false]]
$pad_names = { 0 => "PS5 Controller", 2 => "8BitDo Ultimate" }    # SDL's controller names
$text = {}
$dlls = []
$known = ["03000000fa190000918d000000000000"]
$added = []
$pushed = []
$freed = []
$wine = nil
EXE = "E:/Games/KIF/InfiniteFusion.exe"
def guid(vid, pid); format("03000000%02x%02x0000%02x%02x000000000000", vid & 255, vid >> 8, pid & 255, pid >> 8); end
class Win32API
  def initialize(dll, name, _a, _r)
    raise RuntimeError, "no #{name}" if name == "wine_get_version" && !$wine
    @dll, @name = dll, name
  end
  def call(*a)
    $dlls << @dll if @name.start_with?("SDL_")
    case @name
    when "GetModuleFileNameA" then a[1][0, EXE.length] = EXE; EXE.length
    when "SDL_NumJoysticks" then $devs.length
    when "SDL_GetVersion" then a[0][0, 3] = [2, 0, 12].pack("C3"); nil
    when "SDL_JoystickNameForIndex"
      n = $devs[a[0]][0]
      return 0 unless n
      $text[9000 + a[0]] = n
      9000 + a[0]
    when "SDL_JoystickGetDeviceVendor" then $devs[a[0]][1]
    when "SDL_JoystickGetDeviceProduct" then $devs[a[0]][2]
    when "SDL_IsGameController" then $devs[a[0]][3] ? 1 : 0
    when "SDL_GameControllerNameForIndex"
      n = $pad_names[a[0]]
      return 0 unless n
      $text[9500 + a[0]] = n
      9500 + a[0]
    when "SDL_GameControllerMappingForGUID" then $known.include?(a[0].unpack1("H*")) ? 7000 : 0
    when "SDL_free" then $freed << a[0]; nil
    when "SDL_GameControllerAddMapping"
      $added << a[0]
      $devs.each { |d| d[3] = true if guid(d[1], d[2]) == a[0][0, 32] }
      1
    when "SDL_PushEvent" then $pushed << a[0].unpack("LLl"); 1
    when "lstrlenA" then $text[a[0]].to_s.bytesize
    when "RtlMoveMemory" then a[0].replace($text[a[1]].to_s[0, a[2]]); nil
    when "wine_get_version" then $wine
    end
  end
end
%i[@off @started @exe @fns @k32 @wine @count @tick @problem].each { |v| C.instance_variable_set(v, nil) }
$kif_log.clear
Input.update
check("the newer models are added on the first Input.update, one SDL already has left alone (#{$added.length})",
      log_has("Controllers: 140 newer controller models added to the engine's list (1 it already had)") == 1 &&
      $added.length == 140 && $added.none? { |l| l.start_with?($known[0]) } && $freed == [7000])
check("...every device SDL sees, in KIF's own log, a controller also by the name the game gives it",
      log_has("Controllers: SDL 2.0.12 sees 3 devices") == 1 &&
      log_has("\"Wireless Controller\" 054c:0ce6: a controller (\"PS5 Controller\")") == 1)
check("...one only the added models make known, marked",
      log_has("\"8BitDo Ultimate\" 2dc8:3011: a controller (\"8BitDo Ultimate\"), one of the newer models added") == 1)
check("...and which controller the game is using: none yet", log_has("Controllers: the game isn't using a controller") == 1)
check("...one still unknown: named, with its model, and that the game can't use it",
      log_has("\"8BitDo Pro 2\" 2dc8:6003: not on the engine's controller list, so the game can't use it") == 1)
check("...the newly known pad, plugged in with none open, is opened the way SDL announces one (#{$pushed.inspect})",
      $pushed == [[0x653, 0, 2]] && log_has("Controllers: asked the engine to open the newly known controller") == 1)
check("...SDL is asked inside the running exe itself (#{$dlls.uniq.inspect})", $dlls.uniq == [EXE])
n = $kif_log.length
59.times { Input.update }
check("...and not again while nothing changes", $kif_log.length == n)
Input::Controller.connected = true
Input::Controller.name = "PS5 Controller"
60.times { Input.update }
check("once the engine opens one: which, and that the others are ignored (it uses one at a time)",
      log_has("Controllers: the game is using \"PS5 Controller\" (it uses one controller at a time; the others are ignored)") == 1 &&
      log_has("SDL 2.0.12 sees") == 1)
60.times { Input.update }
check("...said once, not every look", log_has("the game is using") == 1)
$devs << [nil, 0x1234, 0x5678, false]
$wine = "9.0"
C.instance_variable_set(:@wine, nil)
60.times { Input.update }
check("a device plugged in later is logged at the next look, a nameless one too; under Wine it says so",
      log_has("Controllers: SDL 2.0.12, under Wine 9.0, sees 4 devices") == 1 && log_has("\"?\" 1234:5678: not on the engine's controller list") == 1)
puts($failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED")
exit($failed ? 1 : 0)
