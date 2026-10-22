# Offline check of the Controller Fix test mod, unpacked: its Load.rb with KIF,
# the engine's Input and SDL stood in (no Kanto Reloaded).
# Usage: ruby test_mod_check.rb <unpacked ControllerFix folder> <kif_already_has: yes|no>
DIR = ARGV[0]
ALREADY = ARGV[1] == "yes"
$log = []
module KIF
  def self.log(m); $log << m; end
  module Paths; def self.root; "E:/nowhere"; end; end
  module Controllers; end if ALREADY
end
module Input
  class << self; def update; :engine; end; end
  module Controller; def self.connected?; true; end; end
end
$added = 0
class Win32API
  def initialize(dll, name, *_); raise "no #{name}" if name == "wine_get_version"; @name = name; end
  def call(*a)
    case @name
    when "GetModuleFileNameA" then e = "E:/KIF/InfiniteFusion.exe"; a[1][0, e.length] = e; e.length
    when "SDL_NumJoysticks" then 0
    when "SDL_GetVersion" then a[0][0, 3] = [2, 0, 12].pack("C3"); nil
    when "SDL_GameControllerMappingForGUID" then 0
    when "SDL_GameControllerAddMapping" then $added += 1; 1
    end
  end
end
load File.join(DIR, "Load.rb")
Input.update
puts $log
ok = if ALREADY
       $log == ["Controller Fix (test mod): KIF already has this fix, so the mod does nothing"] && $added == 0
     else
       $log.include?("Controller Fix (test mod) 0.1.1: loaded") && $added == 141 &&
         $log.include?("Controllers: 141 newer controller models added to the engine's list (0 it already had)")
     end
puts(ok ? "PASS" : "FAIL")
exit(ok ? 0 : 1)
