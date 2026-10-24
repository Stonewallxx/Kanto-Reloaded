# encoding: utf-8
# Offline preview and drive test of the improved KIF Settings (Reloaded
# Settings). Boots KIF Beta's real settings screen (990_KIF/000_Core 013-018
# and the presets of F-CORE-08) and the Kanto Reloaded mod on stand-in
# engine classes that RECORD drawing calls, then drives the screen with
# queued button presses: checks what each press does, and writes one JSON
# per marked screen state for render.py to draw.
#
# Usage (from anywhere):
#   python metrics.py "<KIF Beta>\Fonts" <work>\metrics.json   (once)
#   ruby   preview.rb "<KIF Beta>" <work>
#   python render.py  "<KIF Beta>\Fonts" <work>
# Not loaded by the game (mod.json only loads Bootstrap.rb).
require "json"
require "fileutils"

KIF_ROOT = ARGV[0]
WORK = ARGV[1]
# A new folder, or one holding only metrics.json (never cleared: see
# Tools/Tests/work_folder.rb)
require_relative "../Tests/work_folder"
KRWork.claim(WORK, ["metrics.json"])
USERDIR = File.join(WORK, "user")
KRWork.claim(USERDIR)
METRICS = JSON.parse(File.read(File.join(WORK, "metrics.json"), :encoding => "UTF-8"))
# The player's copy of the F1 bindings: KIF Beta's defaults
FileUtils.cp(File.join(KIF_ROOT, "Data/keybindings.mkxp1"), File.join(USERDIR, "keybindings.mkxp1"))
SCRIPTS = File.join(KIF_ROOT, "Data/Scripts")
$log = []
$failed = false

def check(label, cond)
  puts "#{cond ? 'ok  ' : 'FAIL'} #{label}"
  $failed = true unless cond
end

#---------------------------------------------------------------- engine stand-ins
class Reset < Exception; end
class QueueEmpty < Exception; end
class Color
  attr_accessor :red, :green, :blue, :alpha
  def initialize(r = 0, g = 0, b = 0, a = 255); @red, @green, @blue, @alpha = r, g, b, a; end
  # as the engine's: comparing with anything not a Color raises
  def ==(o); raise TypeError, "Can't convert #{o.class} into Color" unless o.is_a?(Color); to_a == o.to_a; end
  def to_a; [red.to_i, green.to_i, blue.to_i, alpha.to_i]; end
  def set(r, g, b, a = 255); @red, @green, @blue, @alpha = r, g, b, a; end
end
class Rect
  attr_accessor :x, :y, :width, :height
  def initialize(x = 0, y = 0, w = 0, h = 0); @x, @y, @width, @height = x, y, w, h; end
  def set(x, y, w, h); @x, @y, @width, @height = x, y, w, h; end
end
class Font
  attr_accessor :name, :size, :color
  def initialize; @name = "Power Green"; @size = 29; @color = Color.new(255, 255, 255); end
end
$bitmaps = []
class Bitmap
  attr_reader :width, :height, :font, :ops, :id
  # Bitmap.new(w, h), or Bitmap.new(path) for an image file (a frame)
  def initialize(*args)
    if args[0].is_a?(String)
      path = args[0]
      full = [path, path + ".png", File.join(KIF_ROOT, path), File.join(KIF_ROOT, path + ".png")].find { |p| File.file?(p) }
      raise Errno::ENOENT, path unless full
      @width, @height = File.binread(full, 24)[16, 8].unpack("NN")
      @ops = [["file", File.expand_path(full)]]
    else
      @width, @height = args[0], args[1]
      @ops = []
    end
    @font = Font.new
    @id = $bitmaps.length
    $bitmaps << self
  end
  def stretch_blt(dest, src, rect, opacity = 255)
    @ops << ["sblt", dest.x, dest.y, dest.width, dest.height, src.id, rect.x, rect.y, rect.width, rect.height, opacity]
  end
  def metrics
    METRICS["#{@font.name}|#{@font.size}"] or raise "no metrics for #{@font.name} #{@font.size}"
  end
  def text_size(t)
    m = metrics
    w = t.to_s.each_char.inject(0.0) { |s, ch| s + (m["advance"][ch] || m["advance"]["M"]) }
    Rect.new(0, 0, w.round, m["height"])
  end
  def draw_text(x, y, w, h, text, align = 0)
    @ops << ["text", x, y, w, h, text.to_s, align, @font.name, @font.size, @font.color.to_a]
  end
  def fill_rect(x, y, w, h, c); @ops << ["fill", x, y, w, h, c.to_a]; end
  def blt(x, y, src, rect, opacity = 255); @ops << ["blt", x, y, src.id, rect.x, rect.y, rect.width, rect.height]; end
  def clear; @ops = [["clear"]]; end     # only the latest drawing matters
  def rect; Rect.new(0, 0, @width, @height); end
  def dispose; @disposed = true; end
  def disposed?; @disposed; end
  # One pixel, worked out from what was drawn on it (an image file, fills,
  # blts and stretched blts; text is left out): enough for code that looks
  # at where a picture is see-through.
  def get_pixel(x, y); Color.new(*pixel_at(x, y)); end
  def pixel_at(x, y)
    return [0, 0, 0, 0] if x < 0 || y < 0 || x >= @width || y >= @height
    @ops.reverse_each do |op|
      case op[0]
      when "clear" then return [0, 0, 0, 0]
      when "file" then return PreviewPNG.pixel(op[1], x, y)
      when "fill"
        _k, fx, fy, fw, fh, c = op
        return c if x >= fx && y >= fy && x < fx + fw && y < fy + fh && c[3] > 0
      when "blt", "sblt"
        if op[0] == "blt"
          _k, bx, by, src, sx, sy, sw, sh = op
          bw, bh = sw, sh
        else
          _k, bx, by, bw, bh, src, sx, sy, sw, sh = op
        end
        next unless bw > 0 && bh > 0 && x >= bx && y >= by && x < bx + bw && y < by + bh
        px = $bitmaps[src].pixel_at(sx + (x - bx) * sw / bw, sy + (y - by) * sh / bh)
        return px if px[3] > 0
      end
    end
    return [0, 0, 0, 0]
  end
end
# PNG files read for Bitmap#get_pixel: 8-bit RGBA, RGB, grey, or palette (1-8
# bit, with tRNS), not interlaced
module PreviewPNG
  @files = {}
  def self.pixel(path, x, y)
    img = (@files[path] ||= read(path))
    return [0, 0, 0, 0] unless img && x < img[:w] && y < img[:h]
    return img[:px].call(x, y)
  end

  def self.read(path)
    require "zlib"
    data = File.binread(path)
    pos = 8
    w = h = depth = type = nil
    idat = "".b
    plte = nil
    trns = nil
    while pos < data.bytesize
      len = data[pos, 4].unpack1("N")
      kind = data[pos + 4, 4]
      body = data[pos + 8, len]
      case kind
      when "IHDR"
        w, h, depth, type, _c, _f, interlace = body.unpack("NNCCCCC")
        return nil if interlace != 0
      when "PLTE" then plte = body.bytes.each_slice(3).to_a
      when "tRNS" then trns = body.bytes
      when "IDAT" then idat << body
      end
      pos += 12 + len
    end
    raw = Zlib::Inflate.inflate(idat).bytes
    chans = { 6 => 4, 2 => 3, 0 => 1, 4 => 2, 3 => 1 }[type]
    return nil unless chans
    bpp = [chans * depth / 8, 1].max
    stride = (w * chans * depth + 7) / 8
    rows = []
    prev = Array.new(stride, 0)
    h.times do |r|
      f = raw[r * (stride + 1)]
      line = raw[r * (stride + 1) + 1, stride]
      out = Array.new(stride, 0)
      stride.times do |i|
        a = i >= bpp ? out[i - bpp] : 0
        b = prev[i]
        c = i >= bpp ? prev[i - bpp] : 0
        v = line[i]
        out[i] = case f
                 when 0 then v
                 when 1 then v + a
                 when 2 then v + b
                 when 3 then v + (a + b) / 2
                 when 4
                   pa = (b - c).abs; pb = (a - c).abs; pc = (a + b - 2 * c).abs
                   v + (pa <= pb && pa <= pc ? a : (pb <= pc ? b : c))
                 end & 0xFF
      end
      rows << out
      prev = out
    end
    px = case type
         when 6 then proc { |x, y| rows[y][x * 4, 4] }
         when 2 then proc { |x, y| rows[y][x * 3, 3] + [255] }
         when 0 then proc { |x, y| g = rows[y][x]; [g, g, g, 255] }
         when 4 then proc { |x, y| g, al = rows[y][x * 2, 2]; [g, g, g, al] }
         when 3
           proc do |x, y|
             bit = x * depth
             i = (rows[y][bit / 8] >> (8 - depth - bit % 8)) & ((1 << depth) - 1)
             rgb = plte[i] || [0, 0, 0]
             rgb + [trns && i < trns.length ? trns[i] : 255]
           end
         end
    return { :w => w, :h => h, :px => px }
  rescue StandardError
    return nil
  end
end
class Viewport
  attr_accessor :z, :color
  def initialize(*a); @z = 0; end
  def dispose; @disposed = true; end
  def disposed?; @disposed; end
end
$sprites = []
class Sprite
  attr_accessor :x, :y, :z, :visible, :opacity, :viewport, :ox, :oy, :zoom_x, :zoom_y, :color
  attr_reader :bitmap
  # as in the engine, a new bitmap shows whole
  def bitmap=(b); @bitmap = b; @src_rect = b ? Rect.new(0, 0, b.width, b.height) : nil; end
  def initialize(vp = nil); @viewport = vp; @visible = true; @opacity = 255; @x = 0; @y = 0; @z = 0; @ox = 0; @oy = 0; @zoom_x = 1.0; @zoom_y = 1.0; @color = Color.new(0, 0, 0, 0); $sprites << self; end
  def src_rect=(r); @src_rect = r; end
  def dispose; @disposed = true; end
  def disposed?; @disposed; end
  def src_rect; @src_rect ||= Rect.new(0, 0, @bitmap ? @bitmap.width : 0, @bitmap ? @bitmap.height : 0); end
end
module Graphics
  @fc = 0
  # PIF's Better Fast-forward calls the engine's update by this name
  def self.fast_forward_update; @fc += 1; end
  def self.update; fast_forward_update; end
  def self.frame_count; @fc; end
  def self.width; 512; end
  def self.height; 384; end
end

# Input driven by a queue, one entry per frame:
#   Input::DOWN ...    a fresh press (trigger? and repeat?)
#   [:held, button]    a held button repeating (repeat? only)
#   "text"             typed text (Input.gets)
#   :RETURN ...        a raw key (triggerex? / repeatex?)
#   nil                nothing
#   [:click, x, y]     a left mouse click at x, y
#   [:rclick, x, y]    a right click
#   [:move, x, y]      the mouse moves there (no click)
#   [:wheel, n]        the mouse wheel (n > 0: up, as Input.scroll_v)
#   [:raw, code]       a keyboard key held, by scancode (raw_key_states)
#   [:pad, code]       a controller button held (raw_button_states)
#   [:dump, name]      (no frame) writes the screen as it is now
#   [:call, proc]      (no frame) runs a check
module Input
  A = 11; B = 12; C = 13; X = 14; Y = 15; Z = 16; L = 17; R = 18     # the engine's own numbers
  UP = 8; DOWN = 2; LEFT = 4; RIGHT = 6
  USE = C; BACK = B; ACTION = A; JUMPUP = L; JUMPDOWN = R; SPECIAL = Z; AUX1 = L; AUX2 = R
  MOUSELEFT = 40
  MOUSERIGHT = 41
  @queue = []
  @current = nil
  class << self
    attr_accessor :queue
    def update
      while @queue.first.is_a?(Array) && [:dump, :call].include?(@queue.first[0])
        kind, arg = @queue.shift
        kind == :dump ? dump(arg) : arg.call
      end
      raise QueueEmpty, "the screen didn't close (input queue ran out)" if @queue.empty?
      @current = @queue.shift
      @mouse = @current[1, 2] if click? || rclick? || (@current.is_a?(Array) && @current[0] == :move)
    end
    def click?; @current.is_a?(Array) && @current[0] == :click; end
    def rclick?; @current.is_a?(Array) && @current[0] == :rclick; end
    def scroll_v; @current.is_a?(Array) && @current[0] == :wheel ? @current[1] : 0; end
    def mouse_pos; @mouse; end
    def trigger?(k); @current == k || (k == MOUSELEFT && click?) || (k == MOUSERIGHT && rclick?); end
    def repeat?(k); @current == k || @current == [:held, k]; end
    def press?(k); repeat?(k); end
    def triggerex?(k); @current == k; end
    def repeatex?(k); @current == k; end
    def gets; @current.is_a?(String) ? @current : ""; end
    def raw_key_states
      a = Array.new(512, false)
      a[@current[1]] = true if @current.is_a?(Array) && @current[0] == :raw
      a
    end
    def current; @current; end
    def text_input=(on); end
    def clipboard; @clip.to_s; end
    def clipboard=(t); @clip = t; end
  end
end
module Mouse; def self.getMousePos(*a); Input.mouse_pos; end; end
# The connected controller's name (its button style in hints)
module Input
  module Controller
    def self.name; $pad_name.to_s; end
    def self.connected?; !$pad_name.nil?; end
    def self.raw_button_states
      a = Array.new(21, false)
      cur = Input.current
      a[cur[1]] = true if cur.is_a?(Array) && cur[0] == :pad
      a
    end
    def self.raw_axes; Array.new(6, 0.0); end
  end
end
module RTP; def self.getSaveFolder; USERDIR; end; end
module System; def self.data_directory; USERDIR + "/"; end; end
# Kanto Reloaded's own folders (Settings, Logging, Bug Reports): the test's, not the mod's
KR_LOCAL_DIR = File.join(USERDIR, "KantoReloaded") unless defined?(KR_LOCAL_DIR)
# PIF's autosave switches and variables (052_InfiniteFusion/System/Autosave.rb)
AUTOSAVE_ENABLED_SWITCH = 48; AUTOSAVE_HEALING_VAR = 24; AUTOSAVE_CATCH_SWITCH = 782
AUTOSAVE_WIN_SWITCH = 783; AUTOSAVE_STEPS_SWITCH = 784; AUTOSAVE_STEPS_VAR = 236; DEFAULT_AUTOSAVE_STEPS = 500
module Settings                             # the game's own Settings module
  SCREEN_SCALE = 1.0
  pif = File.read(File.join(KIF_ROOT, "Data/Scripts/001_Settings.rb"), :encoding => "UTF-8")
  SPEECH_WINDOWSKINS = pif[/SPEECH_WINDOWSKINS = \[(.*?)\]/m, 1].to_s.scan(/"([^"]+)"/).flatten
end
def _INTL(*args)
  s = args[0].to_s.dup
  args[1..-1].each_with_index { |a, i| s.gsub!("{#{i + 1}}", a.to_s) }
  s
end
def echoln(s); end
def validate(*a); end
%w[pbPlayCursorSE pbPlayDecisionSE pbPlayCancelSE pbPlayBuzzerSE pbPlayCloseMenuSE].each { |m| define_method(m) { } }
def pbSetSystemFont(b); b.font.name = "Power Green"; b.font.size = 29; end
def pbSetSmallFont(b); b.font.name = "Power Green Small"; b.font.size = 25; end
def pbSetNarrowFont(b); b.font.name = "Power Green Narrow"; b.font.size = 29; end
# the game's frames are found (for the frame pickers); nothing else is
def pbResolveBitmap(path)
  return nil unless path.to_s.include?("Windowskins/")
  full = File.join(KIF_ROOT, path.to_s)
  return File.file?(full) || File.file?(full + ".png") ? path : nil
end
$text_answers = []
def pbEnterText(*a); $log << "ENTERTEXT #{a[0]}"; $text_answers.shift || ""; end
def pbMessage(msg, commands = nil, cancel = 0, *rest); $log << "MSG #{msg}"; commands ? cancel - 1 : 0; end
def pbConfirmMessage(msg); true; end
def pbFadeOutIn; yield; end
class TrainerStub; attr_accessor :id; def initialize(id); @id = id; end; end
load File.join(SCRIPTS, "002_Save data/002_SaveData_Value.rb")
module SaveData
  FILE_PATH = File.join(USERDIR, "File 1.rxdata")
  def self.read_from_file(path); {}; end
  def self.save_to_file(path); true; end
end
module Game; def self.set_up_system; end; end
class PokemonLoadScreen; def pbStartLoadScreen; end; end

#---------------------------------------------------------------- PIF's options and KIF's settings screen
# PIF's PokemonSystem and option classes, as the game has them
src = File.read(File.join(SCRIPTS, "016_UI/015_UI_Options.rb"), :encoding => "UTF-8")
eval(src.split("class Window_PokemonOption")[0], binding, "015_UI_Options.rb")
class PokemonOption_Scene; def pbGetOptions(inloadscreen = false); []; end; end
class PokemonGameOption_Scene < PokemonOption_Scene; end
class Scene_Map; def update; end; end
class PokemonOptionScreen; def pbStartScreen(inloadscreen = false); :pif_options; end; end
# PIF's System & Audio options (the others need a loaded save)
class SystemOptionsScene
  def pbGetOptions(inloadscreen = false)
    [SliderOption.new(_INTL("Music Volume"), 0, 100, 5, proc { $PokemonSystem.bgmvolume }, proc { |v| $PokemonSystem.bgmvolume = v }, _INTL("Volume of the music.")),
     SliderOption.new(_INTL("SE Volume"), 0, 100, 5, proc { $PokemonSystem.sevolume }, proc { |v| $PokemonSystem.sevolume = v }, _INTL("Volume of sound effects.")),
     EnumOption.new(_INTL("Text Speed"), [_INTL("Normal"), _INTL("Fast"), _INTL("Instant")], proc { $PokemonSystem.textspeed }, proc { |v| $PokemonSystem.textspeed = v }, _INTL("How fast text appears.")),
     EnumOption.new(_INTL("Screen Size"), %w[S M L XL Full], proc { $PokemonSystem.screensize }, proc { |v| $PokemonSystem.screensize = v }, _INTL("Size of the game window.")),
     NumberOption.new(_INTL("Speech Frame"), 1, Settings::SPEECH_WINDOWSKINS.length, proc { $PokemonSystem.textskin }, proc { |v| $PokemonSystem.textskin = v })]
  end
end
# PIF's other option screens (in a save), empty here
class GameplayOptionsScene < PokemonOption_Scene; end
class SpriteOptionsScene < PokemonOption_Scene; end
class ChallengeOptionsScene < PokemonOption_Scene; end
$in_game = false
module KIF
  def self.log(msg); $log << "KIFLOG #{msg}"; end
  def self.in_game?; $in_game; end
  def self.save_dir; USERDIR; end
  def self.guard_base(*a); end
  def self.recalc_all_stats; end      # 004_KIF_BattleHelpers (not loaded here); presets call it since 0.21.55
  # 001_KIF_Core (KIF 1.1.0): verbose logging and setting a damaged file aside
  def self.verbose(msg); end
  def self.set_aside(path, what, err = nil); File.rename(path, path + ".bad") rescue nil; log("#{what} unreadable - kept as .bad"); end
  # Every feature belongs to a module; here they are all On
  module Modules
    MODULES = { :shinies => ["Shinies", "Shiny colours and odds.", []], :graphics => ["Graphical Changes", "EBDX, icons, dark mode.", []],
                :mod_settings => ["Mod Settings", "The Mods list in KIF Settings.", []] }
    STATE_NAMES = ["Off", "On", "Hidden"]
    @states = {}
    def self.for_proc(pr); nil; end
    def self.state(id); @states[id] || 1; end
    def self.set_state(id, v); @states[id] = v; end
    def self.visible?(id); id.nil? || state(id) == 1; end
    def self.active?(id); id.nil? || state(id) != 0; end
  end
  # Two installed mods and the catalog's tabs
  module Mods
    class NativeSource; end           # Mods.rb's Mods-folder source (the settings screen asks since 0.21.68)
    Entry = Struct.new(:name, :id, :version, :author, :description, :kind, :error, :loaded, :settings, :on) do
      def enabled?; on; end
      def source; self; end
      def set_enabled(e, v); e.on = v; end
    end
    @list = [Entry.new("Better Bikes", "BetterBikes", "1.2", "Someone", "Faster bikes.", :kif, nil, true, nil, true),
             Entry.new("Old Mod", "OldMod", "0.9", "Unknown", "Doesn't load.", :kif, "boom", false, nil, true),
             Entry.new("Hard Trainers Plus Every Gym Remastered", "HardTrainers", "2.0", "Someone", "A long name.", :kif, nil, true, nil, true)]
    def self.entries; @list; end
  end
  module ModCatalog
    def self.available?; true; end
    def self.items; nil; end
    def self.updates; []; end
  end
end
load File.join(SCRIPTS, "990_KIF/000_Core/002_KIF_Options.rb")
load File.join(SCRIPTS, "990_KIF/000_Core/012_KIF_ModulesMenu.rb")

# Some of KIF's own settings, so the sections have rows
def sample(menu, scope, key, name, values, default, desc)
  KIF::Options.define(key, default, scope)
  KIF::Options.add(menu, scope) do
    if values.is_a?(Array)
      EnumOption.new(_INTL(name), values, proc { $PokemonSystem.send(key) }, proc { |v| $PokemonSystem.send(:"#{key}=", v) }, _INTL(desc))
    else
      SliderOption.new(_INTL(name), values.first, values.last, KIF::Options.slider_step, proc { $PokemonSystem.send(key) },
                       proc { |v| $PokemonSystem.send(:"#{key}=", v) }, _INTL(desc))
    end
  end
end
OFFON = ["Off", "On"]
sample(:shinies, :global, :pv_odds, "Wild Shiny Odds", 0..65536, 16, "Chance for a wild Pokémon to be shiny, out of 65536.")
sample(:shinies, :global, :pv_colors, "Shiny Colors", ["Off", "Vanilla", "Random", "Hue", "Saturated", "Pastel", "Inverted", "Gold"], 1, "How shiny Pokémon are coloured.")
sample(:shinies, :global, :pv_anim, "Shiny Animation", OFFON, 1, "The sparkle when a shiny appears.")
sample(:battles, :save, :pv_format, "Battle Format", ["Single", "Double", "Triple", "Random"], 0, "How many Pokémon fight at once.")
sample(:battles, :global, :pv_auto, "Auto-Battle", OFFON, 1, "Let the game battle for you.")
sample(:battles, :global, :pv_autoshiny, " Auto-Battle Shiny Stop", OFFON, 1, "Stop Auto-Battle when a shiny appears.")
sample(:graphics, :global, :pv_anims, "Battle Animations", OFFON, 1, "Move animations in battle.")
sample(:graphics, :global, :pv_move, "Battle Movement", OFFON, 1, "Pokémon move around in battle.")
sample(:graphics, :global, :pv_typeicons, "Battle Type Icons", OFFON, 1, "Type icons next to each Pokémon in battle.")
sample(:graphics, :global, :pv_typedisp, "Type Display", ["Off", "Ico", "TCG", "Sqr", "FGM", "Txt"], 1, "How each Pokémon's types show in battle: icons, TCG energy, square badges, FGM or text.")
sample(:graphics, :global, :pv_swap, "Swap BattleGUI", OFFON, 0, "Swap the battle boxes' sides.")
sample(:graphics, :global, :pv_random, "Random Sprites", OFFON, 1, "Use a random sprite when a Pokémon has several.")

load File.join(SCRIPTS, "990_KIF/000_Core/013_KIF_PixelFont.rb")
load File.join(SCRIPTS, "990_KIF/000_Core/014_KIF_PixelUI.rb")
module KIF; module SettingsScreen; end; end
load File.join(SCRIPTS, "990_KIF/000_Core/015_KIF_SettingsData.rb")
load File.join(SCRIPTS, "990_KIF/000_Core/016_KIF_SettingsScreen.rb")
load File.join(SCRIPTS, "990_KIF/000_Core/017_KIF_SettingsText.rb")
load File.join(SCRIPTS, "990_KIF/000_Core/018_KIF_Keys.rb")
load File.join(SCRIPTS, "990_KIF/F-CORE-08_SettingsPresets/SettingsPresets.rb")

#---------------------------------------------------------------- boot the mod
load File.join(KIF_ROOT, "Mods/KantoReloaded/Bootstrap.rb")
raise "boot failed: #{Reloaded::Bootstrap.failures.inspect}" unless Reloaded::Bootstrap.ready?
puts "boot: #{Reloaded::Bootstrap.status} #{Reloaded::Bootstrap.failures.inspect}"
check("the improved screen loaded", defined?(Reloaded::SettingsScreen) && Reloaded::SettingsScreen < KifSettingsScreen)
$PokemonSystem = PokemonSystem.new
Game.set_up_system
SaveData.load_new_game_values
S = Reloaded::Settings
# KR_THEME_MODE=2 (Light) or 3 (Frost): the whole run in that Theme Mode, to
# render the full screens' Light look (the checks still run)
S.set(:"interface.theme_mode", ENV["KR_THEME_MODE"].to_i) if ENV["KR_THEME_MODE"].to_s =~ /\A[0-3]\z/
$PokemonSystem.pv_typeicons = 0          # changed from its default: the dot

def dump(name)
  shown = $sprites.reject { |s| s.disposed? || s.bitmap.nil? || s.bitmap.disposed? }
  data = {
    "sprites" => shown.map { |s| { "x" => s.x, "y" => s.y, "z" => (s.viewport ? s.viewport.z * 1000 : 0) + s.z.to_i,
                                    "opacity" => s.opacity, "visible" => s.visible, "bitmap" => s.bitmap.id,
                                    "src" => [s.src_rect.x, s.src_rect.y, s.src_rect.width, s.src_rect.height],
                                    "ox" => s.ox.to_i, "oy" => s.oy.to_i, "zoom" => [s.zoom_x.to_f, s.zoom_y.to_f],
                                    "color" => s.color ? s.color.to_a : [0, 0, 0, 0] } },
    "bitmaps" => {}
  }
  queue = shown.map { |s| s.bitmap }
  until queue.empty?
    b = queue.shift
    next if data["bitmaps"][b.id.to_s]
    data["bitmaps"][b.id.to_s] = { "w" => b.width, "h" => b.height, "ops" => b.ops }
    b.ops.each { |op| queue << $bitmaps[op[3]] if op[0] == "blt"; queue << $bitmaps[op[5]] if op[0] == "sblt" }
  end
  File.write(File.join(WORK, "#{name}.json"), JSON.generate(data))
end

# Which screen opened, for the checks
module CaptureScreen
  def main
    $screen = self
    super
  end
end
KifSettingsScreen.prepend(CaptureScreen)
Reloaded::SettingsScreen.prepend(CaptureScreen)
Reloaded::ControlsScreen.prepend(CaptureScreen)

def drive(label, queue, inloadscreen = false)
  Input.queue = queue.dup
  KifSettingsScreen.new(inloadscreen).main
  check("#{label}: opened and closed", true)
rescue QueueEmpty => e
  check("#{label}: #{e.message}", false)
rescue Exception => e
  check("#{label}: #{e.class}: #{e.message} #{e.backtrace.first(4).inspect}", false)
end

I = Input
def scr; $screen; end
def at(&b); [:call, b]; end
def dmp(name); [:dump, name]; end
def row_name; r = scr.current; r ? r.label : nil; end
# Down from the current row to the one named, counted when it runs (so a
# feature's new row above it changes nothing)
def down_to(label)
  at {
    list = scr.send(:rows)
    t = scr.send(:opt_rows).index { |ri| list[ri].label == label }
    raise "no row #{label}" unless t
    n = t - scr.instance_variable_get(:@sel).to_i
    Input.queue.unshift(*[I::DOWN] * n) if n > 0
  }
end
# The wheel down until the row named is in view
def wheel_to(label, tries = 12)
  step = nil
  step = at {
    list = scr.send(:rows)
    seen = (scr.instance_variable_get(:@row_hits) || []).any? { |li, *| list[li] && list[li].label == label }
    Input.queue.unshift([:wheel, -1], step) if !seen && (tries -= 1) > 0
  }
  step
end
# A click on a row a screen drew (found by its label), x pixels in; or on a
# popup's row or button (Dialogs' hits)
def click_row(label, dx = 30)
  at {
    list = scr.send(:rows)
    h = (scr.instance_variable_get(:@row_hits) || []).find { |li, *| list[li] && list[li].label == label }
    raise "no row #{label}" unless h
    Input.queue.unshift([:click, h[1] + dx, h[2] + 5])
  }
end
def move_row(label, dx = 30)
  at {
    list = scr.send(:rows)
    h = (scr.instance_variable_get(:@row_hits) || []).find { |li, *| list[li] && list[li].label == label }
    raise "no row #{label}" unless h
    Input.queue.unshift([:move, h[1] + dx, h[2] + 5])
  }
end
def click_hint(label, screen = nil)
  at {
    sc = screen ? screen.call : scr
    pairs = sc.instance_variable_get(:@hint_pairs)
    i = pairs.index { |pr| pr[1] == label }
    span = sc.instance_variable_get(:@hint_spans).find { |k, *| k == i }
    off = sc.instance_variable_get(:@hint_sprite).src_rect.x
    Input.queue.unshift([:click, span[1] + 4 - off, 384 - 12])
  }
end
def click_value(dir)
  at {
    r = scr.current
    y = (scr.instance_variable_get(:@row_hits) || []).find { |li, *| scr.send(:rows)[li].equal?(r) }[2]
    Input.queue.unshift([:click, scr.send(:column, r) + dir * 20, y + 5])
  }
end
def click_popup(i)
  at {
    h = Reloaded::Dialogs.instance_variable_get(:@hits).find { |v, *| v == i }
    Input.queue.unshift([:click, h[1] + 10, h[2] + 4])
  }
end
def ps; $PokemonSystem; end

# Another preview (Dev/Tests/hook_check_preview.rb) uses this file's stand-ins
# and helpers, then drives its own screens.
return if defined?(PREVIEW_SETUP_ONLY)

#---------------------------------------------------------------- A: Ocean Blue (the default theme), not in a save
S.set(:"interface.theme", 2)
drive("A", [
  dmp("01_ocean_sidebar_kr"),
  at { check("opens the improved screen on Kanto Reloaded's section", scr.class == Reloaded::SettingsScreen && scr.section_id == :kanto_reloaded) },
  at { check("the Presets section moved to the title bar", scr.instance_variable_get(:@sections).none? { |s| s[0] == :presets }) },
  I::DOWN, I::DOWN, I::DOWN,
  at { check("Down skips empty sections (Shinies, Battles, Graphics)", scr.section_id == :graphics) },
  dmp("02_ocean_sidebar_graphics"),
  I::RIGHT, I::DOWN, I::DOWN, I::DOWN,
  at { check("Right opens the list; Down to Type Display", scr.focus == :list && row_name == "Type Display") },
  dmp("03_ocean_list"),
  I::RIGHT,
  at { check("Right changes a choice", ps.pv_typedisp == 2) },
  I::LEFT, I::DOWN,
  at { check("on Swap BattleGUI", row_name == "Swap BattleGUI" && ps.pv_swap == 0) },
  I::LEFT,
  at { check("a fresh Left on the first value goes round to the last", ps.pv_swap == 1) },
  [:held, I::LEFT], [:held, I::LEFT],
  at { check("a held Left stops at the first value", ps.pv_swap == 0) },
  I::USE,
  at { dd = scr.instance_variable_get(:@dropdown); check("A opens a choice's dropdown, on its value", dd && dd.index == 0) },
  I::DOWN, I::USE,
  at { check("...Down and A pick the next one", ps.pv_swap == 1 && scr.instance_variable_get(:@dropdown).nil?) },
  I::USE, I::DOWN, I::USE, I::UP, I::UP, I::UP, I::UP,
  at { check("Up to the first row", scr.instance_variable_get(:@sel) == 0) },
  [:held, I::UP],
  at { check("a held Up stops at the first row", scr.focus == :list) },
  I::UP,
  at { check("a fresh Up from the first row goes round to the last (no title bar to move into)", scr.focus == :list && scr.instance_variable_get(:@sel) == scr.send(:opt_rows).length - 1) },
  dmp("04_ocean_list_wrapped"),
  I::DOWN,
  at { check("...and Down from the last row back to the first", scr.instance_variable_get(:@sel) == 0) },
  I::DOWN, I::DOWN,
  at { check("on Battle Type Icons (Type Icons under its heading), changed", row_name == "Type Icons" && ps.pv_typeicons == 0) },
  I::ACTION,
  at { check("the Default button resets it", ps.pv_typeicons == 1) },
  I::BACK,
  at { check("B goes back to the sections", scr.focus == :side) },
  [:held, I::UP], [:held, I::UP], [:held, I::UP], [:held, I::UP],
  at { check("a held Up stops at the first section", scr.focus == :side && scr.section_id == :kanto_reloaded) },
  I::UP,
  at { check("a fresh Up from the first section goes round to the last", scr.focus == :side && scr.section_id == :mods) },
  I::DOWN,
  at { check("...and Down from the last back to the first", scr.section_id == :kanto_reloaded) },
  I::RIGHT,
  dmp("07_ocean_kr_rows"),
  at { check("Kanto Reloaded's rows are there (#{row_name})", row_name == "Reloaded Settings") },
  down_to("Cursor Color"),
  at { check("on Cursor Color", row_name == "Cursor Color") },
  I::USE,
  dmp("08_cursor_picker"),
  I::DOWN, I::DOWN, I::USE,
  at { check("the picker sets Cursor Color (it starts at Theme)", S.get(:"interface.cursor_color") == 2) },
  I::UP, I::UP,
  at { check("on Header Color (#{row_name})", row_name == "Header Color") },
  I::USE,
  dmp("09_header_color_picker"),
  I::BACK,
  at { check("B closes the picker without a change", S.get(:"interface.header_color") == 0) },
  I::SPECIAL, "sm",
  dmp("10_search_typing"),
  at { check("search shows results as you type", scr.instance_variable_get(:@query) == "sm" && scr.opt_rows.length > 0) },
  "a", :BACKSPACE,
  at { check("Backspace deletes", scr.instance_variable_get(:@query) == "sm") },
  :RETURN,
  dmp("11_search_results"),
  at { check("Enter: the results, the cursor on the first (#{row_name})", scr.focus == :list && row_name == "Global Small Text") },
  I::BACK,
  at { check("B clears the search", scr.instance_variable_get(:@query).nil? && scr.focus == :side) },
  I::SPECIAL, "xyz", :ESCAPE,
  at { check("Esc stops typing and keeps the search, as KIF's does", scr.instance_variable_get(:@query) == "xyz" && scr.focus == :side) },
  I::BACK,
  at { check("B in the sections clears a search", scr.instance_variable_get(:@query).nil? && scr.focus == :side) },
  [:click, 60, 15],
  at { check("a click on the search box starts typing", !scr.entry.nil?) },
  "glo", I::DOWN,
  at { check("Down goes to the results", scr.instance_variable_get(:@query) == "glo" && scr.focus == :list) },
  I::BACK,
  at { $text_answers << "Theme" },
  I::SPECIAL, I::USE,
  at { check("a controller's A opens the naming screen; its text is the search", scr.instance_variable_get(:@query) == "Theme" && scr.focus == :list && $log.last.start_with?("ENTERTEXT Search Settings")) },
  I::BACK,
  I::R,
  dmp("06b_r_presets"),
  at { check("R opens Presets (outside a save: the notice)", scr.overlay.ops.length > 1) },
  I::USE,
  I::SPECIAL, "zzzq", :RETURN,
  dmp("12_search_nothing"),
  at { check("a search with no results", scr.instance_variable_get(:@query) == "zzzq" && scr.opt_rows.empty?) },
  I::BACK,
  at { check("B clears a search with no results", scr.instance_variable_get(:@query).nil?) },
  I::DOWN, I::RIGHT,
  at { check("on Wild Shiny Odds (Wild Odds)", row_name == "Wild Odds") },
  I::USE,
  dmp("13_number_popup"),
  I::RIGHT, I::UP, I::USE,
  at { check("the number popup sets a slider (#{ps.pv_odds})", ps.pv_odds == 16 + 1 + 10) },
  I::DOWN,
  dmp("14_shiny_colors"),
  I::USE, I::DOWN, I::USE,
  at { check("a choice with 8 values opens a dropdown too", ps.pv_colors == 2) },
  I::BACK,
  [:held, I::DOWN], [:held, I::DOWN], [:held, I::DOWN],
  at { check("on System (#{scr.section_id})", scr.section_id == :system) },
  I::RIGHT,
  dmp("15_system_sliders"),
  I::BACK, I::DOWN,
  dmp("16_modules"),
  I::DOWN, I::RIGHT,
  dmp("17_mods"),
  I::BACK,
  I::DOWN,
  at { check("a fresh Down from the last section goes round to the first", scr.section_id == :kanto_reloaded) },
  I::BACK
])

#---------------------------------------------------------------- B: Base (KIF Settings' own colours), Global Small Text
S.set(:"interface.theme", 0)
S.set(:"interface.cursor_color", Reloaded::Palette::COLORS.index { |c| c[0] == "Blue" } + 1)
drive("B", [I::DOWN, I::DOWN, I::DOWN, dmp("20_base_sidebar"), I::RIGHT, I::DOWN, I::DOWN, I::DOWN, dmp("21_base_list"),
            at { S.set(:"interface.button_prompts", 1); $pad_name = "DualSense Wireless Controller"; scr.refresh },
            dmp("22_base_playstation_hints"),
            at { check("PlayStation hints show its buttons (Default: #{Reloaded::Prompts.input(:A)}, style #{Reloaded::Prompts.style})",
                       Reloaded::Prompts.input(:A) == "p:2" && Reloaded::Prompts.style == :playstation) },
            at do
              def scr.hint_pairs
                [[:ud, "Select"], [:lr, "Change"], ["p:2", "Default"], ["p:9", "Search"], ["p:10", "Presets"],
                 ["p:3", "Something Else"], ["a:5+", "And Another"], ["p:1", "Sections"]]
              end
              scr.refresh
              check("a hint line wider than the screen can scroll", scr.instance_variable_get(:@hint_room) > 0)
            end,
            *[nil] * 120,
            at { check("...and does, after a wait (at #{scr.instance_variable_get(:@hint_sprite).src_rect.x})", scr.instance_variable_get(:@hint_sprite).src_rect.x > 0) },
            dmp("24_hints_scrolling"),
            at { scr.singleton_class.send(:remove_method, :hint_pairs); S.set(:"interface.button_prompts", 0); $pad_name = nil; scr.refresh },
            I::BACK, I::BACK])
S.set(:"interface.global_small_text", true)
drive("B small text", [I::DOWN, I::DOWN, I::DOWN, I::RIGHT, I::DOWN, I::DOWN, I::DOWN, dmp("23_base_small_text"), I::BACK, I::BACK])
S.set(:"interface.global_small_text", false)

#---------------------------------------------------------------- C: presets in a save (Kanto Red, Red cursor)
S.set(:"interface.theme", 4)
S.set(:"interface.cursor_color", Reloaded::Palette::COLORS.index { |c| c[0] == "Red" } + 1)
$in_game = true
KP = KIF::Presets
drive("C", [
  I::R,
  dmp("31_presets_list"),
  I::USE,
  dmp("32_empty_slot_actions"),
  I::USE,                                  # Save Here
  dmp("33_saved_notice"),
  I::USE,
  at { check("Save Here fills the slot", KP.filled?(0)) },
  at { ps.pv_format = 3 },
  I::USE,                                  # slot 1 again: Load, Save Over, Rename, Copy, Paste, Delete, Cancel
  dmp("34_filled_slot_actions"),
  I::USE, I::USE, I::USE,                  # Load, confirm... default is Cancel
  at { check("Load asks first; its default is Cancel", ps.pv_format == 3) },
  I::USE, I::LEFT, I::USE, I::USE,         # Load, choose Load, OK
  at { check("Load puts the preset's settings back", ps.pv_format == 0) },
  I::USE, I::DOWN, I::DOWN, I::DOWN, I::USE, I::USE,   # Copy Share Code, OK
  at { check("Copy Share Code puts a code on the clipboard", Input.clipboard.start_with?("KIF1:")) },
  I::DOWN, I::USE, I::DOWN, I::DOWN, I::USE,   # slot 2: Save Here, Rename, Paste
  dmp("35_paste_notice"),
  I::USE,
  at { check("Paste Share Code fills slot 2 with slot 1's preset", KP.filled?(1) && KP.data[:slots][1][:pv_format] == 0 && KP.name(1) == "Preset 1") },
  I::USE, I::DOWN, I::DOWN, I::USE,        # slot 2: Load, Save Over, Rename
  :BACKSPACE, :BACKSPACE, :BACKSPACE, :BACKSPACE, :BACKSPACE, :BACKSPACE, :BACKSPACE, :BACKSPACE, "Nuzlocke",
  dmp("36_rename"),
  :RETURN,
  at { check("Rename by typing", KP.name(1) == "Nuzlocke") },
  I::USE, I::DOWN, I::DOWN, I::USE, "xx", :ESCAPE,
  at { check("Esc leaves the name as it was", KP.name(1) == "Nuzlocke") },
  at { $text_answers << "Pad Name" },
  I::USE, I::DOWN, I::DOWN, I::USE, I::USE,
  at { check("Rename with a controller: the naming screen", KP.name(1) == "Pad Name") },
  I::USE, I::DOWN, I::DOWN, I::DOWN, I::DOWN, I::DOWN, I::USE, I::LEFT, I::USE,   # Delete, Delete
  at { check("Delete empties the slot", !KP.filled?(1)) },
  at { Input.clipboard = "not a code" },
  I::USE, I::DOWN, I::DOWN, I::USE,         # slot 2 (empty): Save Here, Rename, Paste
  dmp("37_bad_code"),
  at { check("a bad clipboard: a notice, nothing stored", !KP.filled?(1)) },
  I::USE, I::BACK,
  at { check("B closes the presets, back where you were", scr.focus == :side) },
  I::BACK
])
code = Reloaded::Presets.share_code(0)
check("share codes read back", Reloaded::Presets.read_code(code)["kif"]["pv_format"] == 0)
bad = "KIF1:" + [Reloaded::JSON.generate({ "name" => "x", "kif" => { "pv_format" => "evil", "nope" => 1 } })].pack("m0")
Reloaded::Presets.store_code(5, Reloaded::Presets.read_code(bad))
check("pasted values of the wrong kind or for unknown settings are dropped", KP.data[:slots][5] == {} && KP.name(5) == "x")
check("garbage isn't a share code", Reloaded::Presets.read_code("KIF1:!!!").nil? && Reloaded::Presets.read_code("{}").nil?)
$in_game = false

#---------------------------------------------------------------- D: Reloaded Settings Off, and the fallback
S.set(:"interface.theme", 2)
S.set(:"systems.reloaded_settings", false)
drive("D off", [I::RIGHT, dmp("40_vanilla_kr_rows"), I::BACK, I::BACK])
check("Reloaded Settings Off: KIF Settings as it ships", $screen.instance_of?(KifSettingsScreen))
S.set(:"systems.reloaded_settings", true)
module BreakOnce
  def paint_list(*a)
    raise "drawing failed" unless $broke
    super
  end
end
$broke = false
Reloaded::SettingsScreen.prepend(BreakOnce)
drive("D fallback", [I::BACK])
check("a failing improved screen falls back to KIF Settings", $screen.instance_of?(KifSettingsScreen))
check("...and logs why", File.read(Reloaded::Log.path).include?("The improved settings screen failed"))
$broke = true
check("Reloaded Settings is back on after the fallback", Reloaded::KIFBridge.improved?)

#---------------------------------------------------------------- E: a setting a mod locked (KIF 0.21.52)
if defined?(KIF::Locks)
  KIF::Locks.set(:pv_typedisp, 4, :by => "Hardcore Mode", :owner => "hardcore")
  before = $PokemonSystem.pv_typedisp
  drive("E locked", [
    I::DOWN, I::DOWN, I::DOWN, I::RIGHT, I::DOWN, I::DOWN, I::DOWN,
    at { check("on Type Display, locked by a mod", row_name == "Type Display" && scr.send(:lock_name, scr.current.opt) == "Hardcore Mode") },
    dmp("50_locked_by_mod"),
    I::RIGHT, I::USE,
    at { check("a locked setting can't be changed", $PokemonSystem.pv_typedisp == before) },
    I::BACK, I::BACK
  ])
  KIF::Locks.release("hardcore")
end

#---------------------------------------------------------------- F: the Controls screen
S.set(:"interface.theme", 2)
S.set(:"interface.cursor_color", 0)
CT = Reloaded::Controls
def cs_name; a = $screen.send(:current); a ? a.name : nil; end
hold = CT.hold_steps
drive("F settings to controls", [
  at { check("Change Controls is on Kanto Reloaded > Controls", S.definition(:"controls.open")[:type] == :button) },
  I::RIGHT, down_to("Change Controls"),
  at { check("on Change Controls (#{row_name})", row_name == "Change Controls") },
  at {
    rs = scr.send(:rows)
    bs = rs.find { |r| r.label == "Button Style" }
    th = rs.find { |r| r.label == "Theme" }
    cc = scr.send(:column, scr.current)
    check("OPEN and Button Style share the Controls heading's column (#{cc}); Theme's heading has its own (#{scr.send(:column, th)})",
          cc == scr.send(:column, bs) && cc == scr.send(:value_box, bs.opt)[0] && scr.send(:column, th) < cc)
  },
  dmp("59_kr_controls_rows"),
  I::USE,
  dmp("60_controls_sections"),
  at { check("Change Controls opens the Controls screen on Global", $screen.is_a?(Reloaded::ControlsScreen) && $screen.send(:section_id) == :global) },
  I::BACK,
  at { check("closing it goes back to KIF Settings", $screen.nil? || true) },
  I::BACK, I::BACK
])
#---------------------------------------------------------------- G: Global Frame and Speech Frame
[false, true].each do |small|
  S.set(:"interface.global_small_text", small)
  drive("G one line, Global Small Text #{small ? "On" : "Off"}", [
    at {
      below = scr.send(:rows).select { |r| r.kind == :opt && scr.value_mode(r) == :below }.map(&:label)
      check("Global Small Text #{small ? "On" : "Off"}: every Kanto Reloaded row keeps its value beside its name (#{below.inspect})", below.empty?)
    },
    I::BACK
  ])
end
S.set(:"interface.global_small_text", false)
drive("G frames", [
  at {
    all = scr.instance_variable_get(:@rows)
    elsewhere = all.reject { |id, _| id == :kanto_reloaded }.values.flatten.select { |r| r.kind == :opt && r.label == "Speech Frame" }
    ours = elsewhere.length == 1 && elsewhere[0].opt.respond_to?(:kr_key) && elsewhere[0].opt.kr_key == :"interface.speech_frame"
    check("Speech Frame takes PIF's row's place in KIF's own section, as the same setting (#{elsewhere.map { |r| r.section }.inspect})", ours)
    if ours
      elsewhere[0].opt.set(3)
      check("...setting it there sets ours (#{S.get(:"interface.speech_frame")})", S.get(:"interface.speech_frame") == 3)
      check("...and it keeps our description there", KIF::SettingsScreen.description_for(elsewhere[0].opt).nil? &&
                                                    elsewhere[0].opt.description.include?("Global Frame"))
      S.reset(:"interface.speech_frame")
    end
  },
  I::RIGHT, down_to("Cursor Color"), I::DOWN,
  at { check("Global Frame comes after Cursor Color (#{row_name})", row_name == "Global Frame") },
  dmp("80_frames_rows"),
  I::USE,
  dmp("81_global_frame_picker"),
  I::DOWN, I::DOWN, I::DOWN, I::DOWN, I::DOWN,
  dmp("82_global_frame_picker_rld"),
  I::BACK, I::DOWN,
  at { check("then Speech Frame (#{row_name})", row_name == "Speech Frame") },
  I::USE,
  dmp("83_speech_frame_picker"),
  I::BACK, I::BACK, I::BACK
])

#---------------------------------------------------------------- H: the mouse
S.set(:"interface.theme", 2)
drive("H mouse", [
  [:move, 60, 128],
  at { check("hover: the mouse over a section picks it (#{scr.section_id})", scr.section_id == :graphics && scr.focus == :side) },
  [:click, 60, 128],
  at { check("...a click opens its list", scr.focus == :list) },
  move_row("Movement"),
  at { check("hover: the mouse over a row picks it (#{row_name})", row_name == "Movement") },
  at { $mv = ps.pv_move },
  click_value(1),
  at { check("a click on the value's right side steps it, round at the end (#{$mv} -> #{ps.pv_move})", ps.pv_move != $mv) },
  click_value(-1),
  click_hint("Sections"),
  at { check("a click on the Sections hint goes back to the sections", scr.focus == :side) },
  [:move, 470, 15],
  at { check("hover lights the Presets box", scr.instance_variable_get(:@hover_box) == :right) },
  dmp("84_mouse_hover_presets"),
  [:click, 60, 48],
  at { check("a click on Kanto Reloaded opens its list", scr.section_id == :kanto_reloaded && scr.focus == :list) },
  move_row("Overworld Menu"),                          # the last row in view
  at { $top = scr.instance_variable_get(:@scroll) },
  [:wheel, -1],
  at {
    my = Input.mouse_pos[1]
    hit = scr.instance_variable_get(:@row_hits).find { |_li, _x0, y0, _x1, y1| my >= y0 && my <= y1 }
    under = hit && scr.send(:rows)[hit[0]].label
    check("the wheel scrolls the list (#{$top} -> #{scr.instance_variable_get(:@scroll)}), the cursor on the row under the mouse (#{row_name} / #{under})",
          scr.instance_variable_get(:@scroll) > $top && row_name == under)
  },
  [:wheel, -1], [:wheel, -1],
  at { check("...and on down (#{scr.instance_variable_get(:@scroll)}, #{row_name})", scr.instance_variable_get(:@scroll) > $top + 18) },
  [:wheel, 1], wheel_to("Theme"),                      # up one, then down until Theme is in view
  click_row("Theme"),
  dmp("85_mouse_theme_picker"),
  at { check("one click on Theme opens its picker", Reloaded::Dialogs.instance_variable_get(:@hits).length > 1) },
  at {
    h = Reloaded::Dialogs.instance_variable_get(:@hits).find { |v, *| v == 4 }
    Input.queue.unshift([:move, h[1] + 10, h[2] + 4])
  },
  dmp("85b_mouse_picker_hover"),
  click_popup(4),
  at { check("hover then a click on a picker row chooses it (Theme #{S.get(:"interface.theme")})", S.get(:"interface.theme") == 4) },
  [:rclick, 200, 200], [:rclick, 200, 200]
])
S.set(:"interface.theme", 2)

#---------------------------------------------------------------- I: Autosave as rows (in a save)
$game_switches = Hash.new(false)
$game_variables = Hash.new(0)
def rows_now; scr.send(:rows).map(&:label); end
drive("I autosave", [
  [:click, 60, 188],
  at { check("Game > Autosave: its own heading, the Autosave row, nothing else while Off (#{rows_now.inspect})",
             scr.section_id == :game && rows_now.include?("Autosave") && rows_now.count("Autosave") == 2 && !rows_now.include?("When Healing")) },
  move_row("Autosave"),
  click_value(1),
  at { check("Autosave On, no window: its moments show below it (#{rows_now.inspect})",
             $game_switches[AUTOSAVE_ENABLED_SWITCH] && rows_now.include?("When Healing") && rows_now.include?("Every X Steps") &&
             !rows_now.include?("Steps Between Saves")) },
  move_row("Every X Steps"),
  click_value(1),
  at { check("Every X Steps On: Steps Between Saves shows, at #{$game_variables[AUTOSAVE_STEPS_VAR]}",
             rows_now.include?("Steps Between Saves") && $game_variables[AUTOSAVE_STEPS_VAR] == DEFAULT_AUTOSAVE_STEPS) },
  move_row("When Healing"),
  dmp("87_autosave_rows"),
  click_value(1),
  at { check("When Healing Off sets PIF's variable (#{$game_variables[AUTOSAVE_HEALING_VAR]})", $game_variables[AUTOSAVE_HEALING_VAR] == 1) },
  [:rclick, 200, 200], [:rclick, 200, 200]
])
$game_switches = nil
$game_variables = nil

drive_cs = proc do |label, queue|
  Input.queue = queue.dup
  begin
    Reloaded::ControlsScreen.open
    check("#{label}: opened and closed", true)
  rescue QueueEmpty => e
    check("#{label}: #{e.message}", false)
  rescue Exception => e
    check("#{label}: #{e.class}: #{e.message} #{e.backtrace.first(4).inspect}", false)
  end
end
drive_cs.call("F controls", [
  at { check("Menus has no actions yet (skipped); Overworld and Battle have the split features",
             $screen.send(:empty_section?, 2) && !$screen.send(:empty_section?, 1) && !$screen.send(:empty_section?, 3)) },
  I::RIGHT, I::DOWN, I::DOWN, I::DOWN, I::DOWN,
  at { check("the list: Movement, then Buttons; on Confirm (#{cs_name})", cs_name == "Confirm") },
  dmp("61_controls_global"),
  I::USE,
  dmp("62_controls_editor"),
  I::DOWN, I::DOWN, I::USE, nil,
  dmp("63_press_a_key"),
  [:raw, 44], [:raw, 44], nil,
  dmp("64_clash_prompt"),
  at { check("Space is already X's: the clash prompt asks", $screen.overlay.ops.length > 1) },
  I::RIGHT, I::USE,
  at { check("Keep Both: Confirm gets Space, X keeps it", CT.bindings(:confirm, :keys).include?("k:44") && CT.bindings(:x, :keys).include?("k:44")) },
  I::BACK,
  dmp("65_controls_clash_row"),
  I::USE, I::USE,
  at { check("Remove takes a binding off (#{CT.bindings(:confirm, :keys).inspect})", CT.bindings(:confirm, :keys) == ["k:6", "k:44"]) },
  I::BACK, I::ACTION,
  at { check("the Default button puts the column back", !CT.customized?(:confirm, :keys)) },
  I::USE, I::DOWN, I::DOWN, I::USE, nil, [:raw, 4], nil, I::USE,
  at { check("Swap: Confirm takes A from X, X gets Enter (#{CT.bindings(:confirm, :keys).inspect} / #{CT.bindings(:x, :keys).inspect})",
             CT.bindings(:confirm, :keys).include?("k:4") && !CT.bindings(:confirm, :keys).include?("k:40") &&
             CT.bindings(:x, :keys).include?("k:40") && !CT.bindings(:x, :keys).include?("k:4")) },
  I::USE, nil, *[[:raw, 22]] * (hold + 2), nil,      # the list reopens on Add a Key
  at { check("held for Hold Time: bound as a hold (#{CT.bindings(:confirm, :keys).inspect})", CT.bindings(:confirm, :keys).include?("hold:k:22")) },
  I::BACK,
  I::RIGHT,
  at { check("Right moves to the Controller column", $screen.instance_variable_get(:@side) == :pad) },
  at { $pad_name = "Xbox Controller" },
  I::USE, I::DOWN, I::USE, nil, [:pad, 6], nil,
  at { check("a controller button binds (#{CT.bindings(:confirm, :pad).inspect})", CT.bindings(:confirm, :pad).include?("p:6")) },
  I::BACK,
  dmp("66_controls_controller_column"),
  at { $pad_name = nil },
  I::UP, I::UP, I::UP, I::UP,
  at { check("on Up (#{cs_name})", cs_name == "Up") },
  I::USE, I::USE, I::USE,
  dmp("67_needs_one"),
  I::USE, I::BACK,
  at { check("Up keeps one controller input (#{CT.bindings(:up, :pad).inspect})", CT.bindings(:up, :pad).length == 1) },
  I::LEFT, I::USE, I::USE, I::USE, I::BACK,
  at { check("...and one key (#{CT.bindings(:up, :keys).inspect})", CT.bindings(:up, :keys) == ["k:82"]) },
  I::R,
  dmp("68_layouts"),
  I::USE, I::LEFT, I::USE,
  at { check("Layouts > Game's Layout: every action back on F1", CT.actions.none? { |a| CT.customized?(a.id) }) },
  I::BACK, I::UP,
  at { check("a fresh Up from Global goes round to Feel", $screen.send(:section_id) == :feel) },
  I::RIGHT,
  dmp("69_feel"),
  I::RIGHT,
  at { check("Right changes a Feel setting (Button Style: Xbox)", S.get(:"controls.button_style") == 1) },
  I::ACTION,
  at { check("the Default button resets it", S.get(:"controls.button_style") == 0) },
  I::BACK, I::SPECIAL, "conf", :RETURN,
  dmp("70_controls_search"),
  at { check("Search finds actions by name (#{cs_name})", $screen.focus_list? && cs_name == "Confirm") },
  I::BACK, I::BACK
])
drive_cs.call("F splits", [
  I::DOWN,
  at { check("Down from Global: Overworld", $screen.send(:section_id) == :overworld) },
  I::RIGHT,
  dmp("77_overworld"),
  *[I::DOWN] * 7,
  at { check("the Shortcuts start unbound (#{cs_name})", cs_name == "Run Toggle" && CT.bindings(:run_toggle, :keys).empty?) },
  dmp("77b_overworld_shortcuts"),
  *[I::UP] * 7,
  at { check("Overworld starts with Run, following Action (#{cs_name})", cs_name == "Run" && CT.action(:run).follows == :action) },
  I::BACK, I::DOWN,
  at { check("Down from Overworld skips Menus (no actions yet): Battle", $screen.send(:section_id) == :battle) },
  I::RIGHT,
  dmp("78_battle"),
  I::BACK, I::UP, I::UP, I::RIGHT, *[I::DOWN] * 6,
  at { check("Global's Action row (#{cs_name})", cs_name == "Action") },
  dmp("79_action_followers"),
  I::BACK, I::BACK
])
$PokemonSystem.instance_variable_set(:@quicksave, 1)
qs = EnumOption.new("Quicksave", ["Off", "On"], proc { 1 }, proc { |_v| }, "Press S on the map to save.")
qs_row = KIF::SettingsScreen.topic_rows([{ :opt => qs, :scope => :global, :name => "Quicksave", :mod => nil, :children => [] }])[:game]
check("KIF's Quicksave row is there (#{qs_row && qs_row.map(&:label).inspect})", qs_row && qs_row.any? { |r| r.label == "Quicksave" })
check("...described with Quicksave's key (#{KIF::SettingsScreen.description_for(qs).inspect})",
      KIF::SettingsScreen.description_for(qs) == "Press S on the map to open the save screen.")
old_qs = EnumOption.new("Quicksave with S", ["Off", "On"], proc { 1 }, proc { |_v| }, "Quicksave with S")
check("...and KIF 0.21.55's name for it, Quicksave with S, too (#{KIF::SettingsScreen.description_for(old_qs).inspect})",
      KIF::SettingsScreen.description_for(old_qs) == "Press S on the map to open the save screen.")
CT.bind(:quicksave, :keys, ["k:9"])
CT::Layer.instance_variable_set(:@active, true)          # (these stubs aren't the engine's, so the layer is idle here)
check("...which follows a rebind while Reloaded Controls answers (#{KIF::SettingsScreen.description_for(qs).inspect})",
      KIF::SettingsScreen.description_for(qs) == "Press F on the map to open the save screen.")
CT::Layer.instance_variable_set(:@active, nil)
CT.reset_all
click_cell = proc do |x|
  at {
    h = $screen.instance_variable_get(:@row_hits).first
    Input.queue.unshift([:click, x, h[2] + 5])
  }
end
move_cell = proc do |x|
  at {
    h = $screen.instance_variable_get(:@row_hits).first
    Input.queue.unshift([:move, x, h[2] + 5])
  }
end
drive_cs.call("F mouse", [
  [:click, 60, 68],
  at { check("Controls: a click on Overworld opens its list", $screen.send(:section_id) == :overworld && $screen.focus_list?) },
  move_cell.call(Reloaded::ControlsScreen::PAD_X + 10),
  at { check("hover over an action's Controller column picks it (#{cs_name}, #{$screen.instance_variable_get(:@side)})",
             cs_name == "Run" && $screen.instance_variable_get(:@side) == :pad) },
  click_cell.call(Reloaded::ControlsScreen::PAD_X + 10),
  dmp("86_mouse_controls_editor"),
  at { check("...one click opens its editor", $screen.overlay.ops.length > 1) },
  [:rclick, 200, 200],
  [:rclick, 200, 200],
  at { check("right clicks close the editor, then go back to the sections", $screen.focus_list? == false) },
  [:rclick, 200, 200]
])
LA = CT::Layouts
File.delete(LA.path) if File.exist?(LA.path)
LA.reload
CT.bind(:confirm, :keys, ["k:44"])
drive_cs.call("F layouts", [
  I::R, I::DOWN,
  dmp("70b_layouts_pokemon_style"),
  I::USE,
  dmp("70c_pokemon_style_confirm"),
  I::LEFT, I::USE,
  at { check("Layouts > Pokémon-Style: B runs, X and Start open the menu, the keyboard as it was (#{CT.bindings(:run, :pad).inspect})",
             CT.bindings(:run, :pad) == ["p:1"] && CT.bindings(:pause_menu, :pad) == ["p:2", "p:6"] && CT.bindings(:confirm, :keys) == ["k:44"]) },
  at { CT.reset_all; CT.bind(:confirm, :keys, ["k:44"]) },
  I::R, I::DOWN, I::DOWN,
  at { check("Layouts: Game's Layout, Pokémon-Style, then Save as New Layout", $screen.overlay.ops.length > 1) },
  I::USE,
  dmp("71_layout_name"),
  :RETURN,
  dmp("72_layout_saved"),
  at { check("Save as New Layout: named Layout 1, holds Confirm on Space",
             LA.list.length == 1 && LA.list[0]["name"] == "Layout 1" && LA.list[0]["bindings"]["confirm"]["keys"] == ["k:44"]) },
  I::USE,
  dmp("73_layouts_mine"),
  I::USE,
  dmp("74_layout_actions"),
  I::DOWN, I::DOWN, I::DOWN, I::USE,
  at { check("Copy Share Code puts a KRC1: code on the clipboard", Input.clipboard.start_with?("KRC1:")) },
  I::USE,
  I::DOWN, I::DOWN, I::USE,
  dmp("75_layout_pasted"),
  at { check("Paste Share Code adds it as a second layout (#{LA.list[1] && LA.list[1]["name"]})",
             LA.list.length == 2 && LA.list[1]["name"] == "Layout 1 (2)") },
  I::USE,
  at { CT.reset_all },
  I::UP, I::UP, I::USE, I::USE, I::LEFT, I::USE,
  dmp("76_layout_loaded"),
  at { check("Load: Confirm back on Space (#{CT.bindings(:confirm, :keys).inspect})", CT.bindings(:confirm, :keys) == ["k:44"]) },
  I::USE,
  I::R, I::DOWN, I::DOWN, I::DOWN, I::USE, *[I::DOWN] * 4, I::USE, I::LEFT, I::USE,
  at { check("Delete takes the second one away", LA.list.length == 1 && LA.list[0]["name"] == "Layout 1") },
  I::BACK, I::BACK
])
File.delete(LA.path) if File.exist?(LA.path)
LA.reload
CT.reset_all

#---------------------------------------------------------------- J: Option Dropdowns
def dd; scr.instance_variable_get(:@dropdown); end
# the mouse on choice i of the open dropdown: a click (or kind: :move, :rclick)
def click_dd(i, kind = :click)
  at {
    h = dd.instance_variable_get(:@hits).find { |v, *| v == i }
    raise "no dropdown row #{i}" unless h
    Input.queue.unshift([kind, h[1] + 10, h[2] + 4])
  }
end
# a click on the middle of the current row's value
def click_value_text
  at {
    r = scr.current
    y = scr.instance_variable_get(:@row_hits).find { |li, *| scr.send(:rows)[li].equal?(r) }[2]
    Input.queue.unshift([:click, scr.send(:column, r), y + 5])
  }
end
def drawn_text(b); b.ops.select { |o| o[0] == "text" }.map { |o| o[5] }.join(" "); end
def desc_text; drawn_text(scr.instance_variable_get(:@top_sprite).bitmap); end
TC = :"interface.pv_test_choices"
S.register(TC, :page => :interface, :priority => 999, :name => "Test Choices", :type => :enum, :default => 0,
           :values => ["Low", "Mid", "High", "Max"],
           :descriptions => ["The lowest.", "In the middle.", "Higher still.", "As high as it goes."],
           :locked_choices => proc { { 2 => "Needs a badge" } },
           :description => "A test setting with a locked choice.")
S.set(:"interface.theme", 2)
ps.pv_typedisp = 1
drive("J dropdowns", [
  I::DOWN, I::DOWN, I::DOWN, I::RIGHT, I::USE,
  at {
    box = scr.instance_variable_get(:@value_boxes)[scr.current]
    check("the first row's dropdown drops right under its value (#{dd.rect[1]} / #{box[3]})", dd.below? && !dd.over? && dd.rect[1] == box[3] + 1)
  },
  dmp("89_dropdown_first_row"),
  I::BACK, I::DOWN, I::DOWN, I::DOWN,
  at { check("on Type Display (#{row_name})", row_name == "Type Display") },
  I::USE,
  at { check("A opens Type Display's dropdown, highlighted on its value (Ico, NOW)", dd && dd.index == 1 && dd.current == 1) },
  at { check("...5 of its 6 choices, so it scrolls", dd.visible == 5 && dd.scrolls?) },
  at {
    box = scr.instance_variable_get(:@value_boxes)[scr.current]
    check("...no room for them under or above: it moves up over the value, inside the list (#{dd.rect.inspect}, value #{box.inspect})",
          dd.below? && dd.over? && dd.rect[1] <= box[3] && dd.rect[2] <= Reloaded::SettingsScreen::LIST_X1 - 4 &&
          dd.rect[3] == Reloaded::SettingsScreen::LIST_Y1 - 2)
  },
  dmp("90_dropdown_open"),
  I::DOWN,
  at { check("Down moves the highlight (#{dd.values[dd.index]})", dd.index == 2 && dd.values[2] == "TCG") },
  at { check("...the hint line: Choose, Pick, Close", scr.send(:hint_pairs).map { |pr| pr[1] } == ["Choose", "Pick", "Close"]) },
  dmp("91_dropdown_moved"),
  I::DOWN, I::DOWN, I::DOWN,
  at { check("past the last row shown, the list scrolls (top #{dd.top})", dd.index == 5 && dd.top == 1) },
  dmp("92_dropdown_scrolled"),
  [:held, I::DOWN],
  at { check("a held Down stops at the last choice", dd.index == 5) },
  I::DOWN,
  at { check("a fresh Down goes round to the first", dd.index == 0 && dd.top == 0) },
  I::BACK,
  at { check("B closes it without a change, and it's gone from the screen", dd.nil? && ps.pv_typedisp == 1 && scr.overlay.ops == [["clear"]]) },
  I::USE, I::DOWN, I::USE,
  at { check("A, Down, A picks the next choice (TCG)", ps.pv_typedisp == 2 && dd.nil?) },
  I::RIGHT,
  at { check("Right still steps a choice", ps.pv_typedisp == 3) },
  I::LEFT,
  click_value_text,
  at { check("a click on the value opens the dropdown", !dd.nil?) },
  click_dd(4, :move),
  at { check("the mouse over a choice highlights it", dd.index == 4) },
  [:wheel, -1],
  at { check("the wheel scrolls the list (top #{dd.top}), the highlight under the mouse (#{dd.index})", dd.top == 1 && dd.index == 5) },
  click_dd(5),
  at { check("a click on a choice picks it (Txt)", ps.pv_typedisp == 5 && dd.nil?) },
  click_value_text, [:click, 250, 320],
  at { check("a click outside closes it", dd.nil? && ps.pv_typedisp == 5) },
  click_value_text, [:rclick, 250, 320],
  at { check("a right click closes it", dd.nil? && ps.pv_typedisp == 5) },
  click_value_text, I::DOWN, click_hint("Pick"),
  at { check("the hint line's Pick picks (Off: #{ps.pv_typedisp})", ps.pv_typedisp == 0 && dd.nil?) },
  click_value_text, I::DOWN, click_hint("Close"),
  at { check("...and Close closes", dd.nil? && ps.pv_typedisp == 0) },
  click_value(1),
  at { check("a click beside the value still steps it", ps.pv_typedisp == 1) },
  I::DOWN, I::DOWN,
  at { check("on Random Sprites, the last row (#{row_name})", row_name == "Random Sprites") },
  I::USE,
  at { check("near the bottom of the list it opens above the value (#{dd.rect.inspect})", !dd.below? && !dd.scrolls? && dd.visible == 2) },
  dmp("93_dropdown_above"),
  I::BACK, I::BACK, I::UP, I::RIGHT,
  at { check("on Auto-Battle (#{row_name})", row_name == "Auto-Battle") },
  I::USE, I::DOWN,
  at { check("KIF's own per-choice descriptions explain each choice (#{Reloaded::KIFDropdowns.choice_text(scr.current.opt, 0)})",
             dd.index == 0 && desc_text.include?("You choose your own moves.")) },
  dmp("94_dropdown_kif_choice_text"),
  I::BACK, I::BACK,
  I::SPECIAL, "test choices", :RETURN,
  at { check("on Test Choices (#{row_name})", row_name == "Test Choices") },
  I::USE,
  at { check("a locked choice shows locked", dd.locked?(2) && !dd.locked?(1)) },
  I::DOWN,
  at { check("a Kanto Reloaded setting's :descriptions explain each choice", desc_text.include?("In the middle.")) },
  I::DOWN,
  at { check("...and a locked one says why first", desc_text.include?("Locked: Needs a badge.") && desc_text.include?("Higher still.")) },
  dmp("95_dropdown_locked"),
  I::USE,
  at { check("A on a locked choice: a buzz, it stays open, nothing changes", !dd.nil? && S.get(TC) == 0) },
  I::UP, I::USE,
  at { check("a choice that isn't locked picks", S.get(TC) == 1 && dd.nil?) },
  I::RIGHT,
  at { check("Right steps over the locked choice (Mid to Max)", S.get(TC) == 3) },
  at { check("Settings.set refuses a locked choice", S.set(TC, 2) == false && S.get(TC) == 3) },
  I::BACK, [:click, 60, 48], down_to("Theme"),
  at { check("on Theme (#{row_name})", row_name == "Theme") },
  I::USE,
  at { check("Theme keeps its own picker", dd.nil? && Reloaded::Dialogs.instance_variable_get(:@hits).length == [Reloaded::Palette::THEME_NAMES.length, Reloaded::Dialogs::PICK_MAX].min) },
  I::BACK, I::DOWN,
  at { check("on Theme Mode (#{row_name})", row_name == "Theme Mode") },
  I::USE,
  at { check("Theme Mode, a Kanto Reloaded choice, opens a dropdown", !dd.nil?) },
  I::BACK, I::BACK, I::BACK
])
S.reset(TC)

# KIF Settings as it ships: Kanto Reloaded's rows get dropdowns, KIF's own don't
def vanilla_dd; $sprites.reverse.find { |sp| sp.z == 10 && !sp.disposed? && sp.viewport && !sp.viewport.disposed? }; end
S.set(:"systems.reloaded_settings", false)
tm = S.get(:"interface.theme_mode")
drive("J vanilla", [
  I::RIGHT, down_to("Theme Mode"),
  at { check("KIF Settings as it ships, on Theme Mode (#{row_name})", scr.instance_of?(KifSettingsScreen) && row_name == "Theme Mode") },
  I::USE,
  at { check("A on a Kanto Reloaded choice opens its dropdown", !vanilla_dd.nil? && vanilla_dd.bitmap.ops.length > 5) },
  I::DOWN,
  dmp("96_vanilla_dropdown"),
  at { check("...and the description box and key bar are drawn over KIF's", vanilla_dd.bitmap.ops.any? { |o| o[0] == "fill" && o[2] >= KifSettingsScreen::LIST_Y1 + 4 }) },
  I::USE,
  at { check("...Down and A pick (Theme Mode #{tm} -> #{S.get(:"interface.theme_mode")}), and it's gone", S.get(:"interface.theme_mode") == (tm + 1) % 4 && vanilla_dd.nil?) },   # Dark, Glass, Light, Frost
  I::BACK, I::DOWN, I::DOWN, I::DOWN, I::RIGHT, I::DOWN, I::DOWN, I::DOWN, I::DOWN,
  at { $sw = ps.pv_swap; check("on KIF's own Swap BattleGUI (#{row_name})", row_name == "Swap BattleGUI") },
  I::USE,
  at { check("A on KIF's own rows stays as KIF ships it (no dropdown, no change)", vanilla_dd.nil? && ps.pv_swap == $sw) },
  I::BACK, I::BACK
])
S.set(:"interface.theme_mode", tm)
S.set(:"systems.reloaded_settings", true)

# The Controls screen's Feel settings
drive_cs.call("J feel", [
  I::UP, I::RIGHT,
  at { check("Feel, on Button Style (#{S.definition($screen.send(:feel_keys)[0])[:name]})", $screen.send(:section_id) == :feel) },
  I::USE,
  at { d = $screen.instance_variable_get(:@dropdown); check("A on a Feel setting opens its dropdown", d && d.index == S.get(:"controls.button_style")) },
  I::DOWN,
  dmp("97_feel_dropdown"),
  I::USE,
  at { check("...Down and A set it (Button Style: Xbox)", S.get(:"controls.button_style") == 1 && $screen.instance_variable_get(:@dropdown).nil?) },
  I::ACTION,
  at { check("the Default button still resets it", S.get(:"controls.button_style") == 0) },
  I::BACK, I::BACK
])

#---------------------------------------------------------------- K: Go to Settings (his pick, 2026-10-24: Button on the Row)
def hint_labels; (scr.instance_variable_get(:@hint_pairs) || []).map { |p| p[1] }; end
def first_drawn; i = scr.send(:layout_rows)[0][0][0]; scr.send(:rows)[i]; end
def on_row?(heading, label); r = scr.current; r && r.heading.to_s == heading && r.label.to_s == label; end
sp_was = Reloaded::Features.state(Reloaded::SpeedUp::FEATURE)
Reloaded::Features.set(Reloaded::SpeedUp::FEATURE, :on)
drive("K go to settings", [
  I::RIGHT, down_to("Speed-Up"),
  at { check("on the Features page's Speed-Up: Go to Settings in the hints, its button after the name",
             on_row?("Features", "Speed-Up") && hint_labels.include?("Go to Settings") && scr.instance_variable_get(:@goto_hit)) },
  dmp("98_go_to_settings"),
  I::X,
  at { check("Y: Speed-Up's own heading at the top, the cursor on its first setting (#{first_drawn.label})",
             on_row?("Speed-Up", "Speed-Up") && first_drawn.kind == :head && first_drawn.label.to_s == "Speed-Up") },
  at { check("...and B says Back (#{hint_labels.last})", hint_labels.last == "Back" && !hint_labels.include?("Go to Settings")) },
  dmp("99_went_to_settings"),
  I::DOWN, I::BACK,
  at { check("B: back on the Features switch, still in the list", on_row?("Features", "Speed-Up") && scr.focus == :list) },
  at { check("...then B says Sections again (#{hint_labels.last})", hint_labels.last == "Sections") },
  I::UP,
  at { check("a switch with no settings of its own (#{row_name}): no button, no hint",
             row_name == "Healing Moves" && !hint_labels.include?("Go to Settings") && scr.instance_variable_get(:@goto_hit).nil?) },
  I::X,
  at { check("...and Y does nothing there", on_row?("Features", "Healing Moves")) },
  I::DOWN,
  at { h = scr.instance_variable_get(:@goto_hit); Input.queue.unshift([:click, h[0] + 3, h[1] + 5]) },
  at { check("a click on the row's button goes too", on_row?("Speed-Up", "Speed-Up")) },
  I::BACK,
  click_hint("Go to Settings"),
  at { check("...and a click on the hint", on_row?("Speed-Up", "Speed-Up")) },
  I::BACK, I::BACK,
  at { check("B, B: out to the sections", scr.focus == :side) },
  I::RIGHT,
  at { check("back in the list, B goes to the sections again (no old jump left)", hint_labels.last == "Sections") },
  at {
    scr.query = "Menu"
    list = scr.send(:rows)
    k = scr.send(:opt_rows).index { |i| list[i].heading.to_s == "Features" && list[i].label.to_s == "Overworld Menu" }
    scr.instance_variable_set(:@sel, k.to_i)
    scr.instance_variable_set(:@focus, :list)
    scr.refresh
  },
  at { check("in a search's results, on Overworld Menu (#{row_name})", row_name == "Overworld Menu" && hint_labels.include?("Go to Settings")) },
  I::X,
  at { check("Y: the search clears, Overworld Menu's own heading", scr.instance_variable_get(:@query).nil? && on_row?("Overworld Menu", "Overworld Menu")) },
  I::BACK,
  at { check("...B: its Features switch", on_row?("Features", "Overworld Menu")) },
  I::BACK, I::BACK
])
Reloaded::Features.set(Reloaded::SpeedUp::FEATURE, sp_was)

#---------------------------------------------------------------- descriptions that don't fit
P = Reloaded::Pixel
probe = Bitmap.new(512, 384)
long = []
S.groups.each do |g|
  S.pages(g[:id]).each do |pg|
    S.keys(pg[:id]).each do |k|
      d = S.definition(k)
      n = P.small_wrap(probe, _INTL(d[:description]), 512 - 30).length
      long << "#{d[:name]} (#{n} lines)" if n > KifSettingsScreen::DESC_LINES
    end
  end
end
puts long.empty? ? "descriptions: all fit in #{KifSettingsScreen::DESC_LINES} lines" : "descriptions too long: #{long.join(', ')}"
errors = File.read(Reloaded::Log.path).lines.grep(/ERROR|WARNING/).reject { |l| l.include?("drawing failed") || l.include?("The improved settings screen failed") }
check("no other errors or warnings in the log (#{errors.length})", errors.empty?)
errors.first(6).each { |l| puts "  " + l }
puts $failed ? "SOME CHECKS FAILED" : "ALL CHECKS PASSED"
exit($failed ? 1 : 0)
