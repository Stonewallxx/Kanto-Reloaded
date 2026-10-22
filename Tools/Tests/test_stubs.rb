# encoding: utf-8
# Stand-ins for the engine, PIF and KIF Beta, as far as Kanto Reloaded's
# foundation uses them. Loaded by the headless tests before Bootstrap.rb;
# they set KIF_ROOT and USERDIR first. Not loaded by the game.
#---------------------------------------------------------------- engine/game stubs
require "zlib"                              # built into the game's engine
class Reset < Exception; end
def echoln(s); $log << "ECHO #{s}"; end
def validate(*a); end
module System; def self.data_directory; USERDIR + "/"; end; end
# Kanto Reloaded's own folders (Settings, Logging, Bug Reports): the test's, not the mod's
KR_LOCAL_DIR = File.join(USERDIR, "KantoReloaded") unless defined?(KR_LOCAL_DIR)
module RTP; def self.getSaveFolder; USERDIR; end; end
module KIF
  def self.log(msg); $log << "KIFLOG #{msg}"; end
  module CrashLog
    def self.write(text); $log << "CRASHLOG #{text.lines.first}"; end
    def self.describe(e, file = nil); "Exception: #{e.class}\r\nMessage: #{e.message}"; end
  end
end
class TrainerStub; attr_accessor :id, :name; def initialize(id); @id = id; end; end
def _INTL(*args)
  s = args[0].to_s.dup
  args[1..-1].each_with_index { |a, i| s.gsub!("{#{i + 1}}", a.to_s) }
  s
end
class Bitmap
  attr_reader :path
  def initialize(*args); @path = args[0]; end
end
module Audio
  def self.se_play(name, vol = 100, pitch = 100); $log << "SE #{name}"; end
  def self.bgm_play(name, vol = 100, pitch = 100, pos = 0); $log << "BGM #{name}"; end
  def self.bgs_play(name, vol = 100, pitch = 100); end
  def self.me_play(name, vol = 100, pitch = 100); end
end
class FontStub; attr_accessor :name; end
def pbSetSystemFont(b); b.font = :system; end
def pbSetSmallFont(b); b.font = :small; end
def pbResolveBitmap(x); nil; end
class PokemonSystemStub; attr_accessor :textspeed; def initialize; @textspeed = 2; end; end

# The real save-value registry from KIF Beta
load File.join(KIF_ROOT, "Data/Scripts/002_Save data/002_SaveData_Value.rb")
module SaveData
  FILE_PATH = File.join(USERDIR, "File 1.rxdata")
  def self.read_from_file(path); $log << "READ #{path}"; stored(path); end
  def self.save_to_file(path); $fake_files[path] = compile_save_hash; true; end
end
$fake_files = {}
# What a save holds: the stand-in's record, or the file Kanto Reloaded's safe
# saving wrote (it writes saves itself)
# (a test planting a save in $fake_files deletes the file first)
def stored(path)
  return File.open(path, "rb") { |f| Marshal.load(f) } if File.file?(path)
  return $fake_files[path]
end
SaveData.register(:player) do
  save_value { $Trainer }
  load_value { |v| $Trainer = v }
  new_game_value { TrainerStub.new(111) }
end

module Game
  def self.set_up_system; $log << "SETUP"; :setup_done; end
end
class PokemonLoadScreen
  def pbStartLoadScreen; $log << "LOADSCREEN"; :title; end
end

# KIF Beta's settings screen and PIF's option classes, as far as the
# Kanto Reloaded bridge uses them
module Input
  USE = 13; RIGHT = 6; LEFT = 4
  def self.trigger?(k); $pressed == k; end
end
def pbPlayDecisionSE; end
class Color
  attr_reader :red, :green, :blue, :alpha
  def initialize(r = 0, g = 0, b = 0, a = 255); @red, @green, @blue, @alpha = r, g, b, a; end
  # as the engine's: comparing with anything not a Color raises
  def ==(o); raise TypeError, "Can't convert #{o.class} into Color" unless o.is_a?(Color); [red, green, blue, alpha] == [o.red, o.green, o.blue, o.alpha]; end
end
module PropertyMixin
  def get; @getProc ? @getProc.call : nil; end
  def set(value); @setProc.call(value) if @setProc; end
end
class Option
  attr_reader :description
  def initialize(description); @description = description; end
end
class EnumOption < Option
  include PropertyMixin
  attr_reader :values, :name
  def initialize(name, options, get_proc, set_proc, description = "")
    super(description); @name = name; @values = options; @getProc = get_proc; @setProc = set_proc
  end
end
class SliderOption < Option
  include PropertyMixin
  attr_reader :name, :optstart, :optend
  def initialize(name, optstart, optend, interval, get_proc, set_proc, description = "")
    super(description); @name = name; @optstart = optstart; @optend = optend; @getProc = get_proc; @setProc = set_proc
  end
end
class NumberOption < SliderOption
  def initialize(name, optstart, optend, get_proc, set_proc, description = ""); super(name, optstart, optend, 1, get_proc, set_proc, description); end
end
module KIF
  module Options
    @menus = {}
    @entries = {}
    def self.register_menu(id, *info); @menus[id] = info; end
    def self.add(menu, scope = :save, &builder); (@entries[menu] ||= []) << [scope, builder]; end
    def self.entries(menu); @entries[menu] || []; end
  end
  module SettingsScreen
    SECTIONS = [[:shinies, "Shinies", [220, 180, 60], [["Odds", ["Wild Shiny Odds"]]]]]
    RENAMES = {}
    module_function
    def defaults_for(opts); opts.each_with_object({}) { |o, h| h[o] = (o.get rescue nil) }; end
  end
  # KIF's pixel fonts (KIF Settings, Battle Info), as far as Global Small Text uses them
  module PixelFont
    FONTS = { [:system, 26] => { :height => 14 }, [:narrow, 26] => { :height => 14 }, [:small, 22] => { :height => 12 } }
    TITLE = [:system, 26]; ROW = [:narrow, 26]; TEXT = [:small, 22]
    module_function
    def data(font); FONTS[font]; end
    def height(font); data(font)[:height]; end
    def glyph_bitmap(font, code, glyph, color); [font, code]; end
  end
end
class ButtonOption < Option
  attr_reader :name
  def initialize(name, on_press, description = ""); super(description); @name = name; @on_press = on_press; end
  def trigger; @on_press.call; end
end
class KifSettingsScreen
  def initialize(inloadscreen = false, start = nil); @inloadscreen = inloadscreen; @start = start; end
  def rebuild; $log << "KIF_REBUILD"; :rebuilt; end
end

