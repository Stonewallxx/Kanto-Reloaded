#==============================================================================
# Kanto Reloaded: physical inputs
#==============================================================================
# The keys, controller buttons and axes Kanto Reloaded's controls bind, by
# the codes mkxp-z uses:
#
#   "k:225"   a keyboard key, by SDL scancode (225 is Left Shift)
#   "p:0"     a controller button, by SDL game-controller button (0 is the
#             bottom face button: A on Xbox, Cross on PlayStation)
#   "a:1-"    a stick or trigger axis and its direction (1- is the left
#             stick up; 4+ and 5+ are the left and right triggers)
#
# A binding is one of these, or "hold:" and one of these for an action that
# fires while the input is held (Reloaded Controls' tap and hold).
#
# Also reads the engine's own bindings (F1: keybindings.mkxp1): three Int32
# (version, RGSS version, count), then four Int32 per entry: source (1 key,
# 2 controller button, 3 axis), code, axis direction (0 negative), and the
# game button it drives.
#==============================================================================

module Reloaded
  module Controls
    module Inputs
      FILE = "keybindings.mkxp1"
      HOLD = "hold:"

      # SDL scancode => label
      KEYS = {}
      ("A".."Z").each_with_index { |c, i| KEYS[4 + i] = c }
      (1..9).each { |n| KEYS[29 + n] = n.to_s }
      KEYS[39] = "0"
      {
        40 => "Enter", 41 => "Esc", 42 => "Backspace", 43 => "Tab", 44 => "Space", 45 => "-", 46 => "=",
        47 => "[", 48 => "]", 49 => "\\", 51 => ";", 52 => "'", 53 => "`", 54 => ",", 55 => ".", 56 => "/",
        57 => "Caps Lock", 70 => "Print Screen", 71 => "Scroll Lock", 72 => "Pause", 73 => "Insert",
        74 => "Home", 75 => "Page Up", 76 => "Delete", 77 => "End", 78 => "Page Down", 79 => "Right",
        80 => "Left", 81 => "Down", 82 => "Up", 83 => "Num Lock", 84 => "Num /", 85 => "Num *",
        86 => "Num -", 87 => "Num +", 88 => "Num Enter", 98 => "Num 0", 99 => "Num .",
        224 => "Left Ctrl", 225 => "Left Shift", 226 => "Left Alt", 227 => "Left Win",
        228 => "Right Ctrl", 229 => "Right Shift", 230 => "Right Alt", 231 => "Right Win"
      }.each { |k, v| KEYS[k] = v }
      (1..12).each { |n| KEYS[57 + n] = "F#{n}" }
      (1..9).each { |n| KEYS[88 + n] = "Num #{n}" }
      # Keys the engine keeps for itself: F1 its key bindings, F2 its frame
      # counter, F12 the soft reset. They can't be bound.
      RESERVED_KEYS = [58, 59, 69].freeze
      # Keys that type a character: while text is typed they only type
      # (arrows, Enter, Esc, Backspace and the rest still work as buttons)
      TEXT_KEYS = {}
      ((4..39).to_a + (44..56).to_a + (84..87).to_a + (89..99).to_a).each { |k| TEXT_KEYS[k] = true }
      TEXT_KEYS.freeze

      # SDL game-controller buttons, named per style
      PAD = {
        :xbox        => ["A", "B", "X", "Y", "View", "Guide", "Menu", "LS", "RS", "LB", "RB",
                         "D-Pad Up", "D-Pad Down", "D-Pad Left", "D-Pad Right", "Share", "P1", "P2", "P3", "P4", "Touchpad"],
        :playstation => ["Cross", "Circle", "Square", "Triangle", "Share", "PS", "Options", "L3", "R3", "L1", "R1",
                         "D-Pad Up", "D-Pad Down", "D-Pad Left", "D-Pad Right", "Mute", "P1", "P2", "P3", "P4", "Touchpad"],
        :nintendo    => ["B", "A", "Y", "X", "-", "Home", "+", "LS", "RS", "L", "R",
                         "D-Pad Up", "D-Pad Down", "D-Pad Left", "D-Pad Right", "Capture", "P1", "P2", "P3", "P4", "Touchpad"]
      }.freeze
      PAD_A = 0
      PAD_B = 1
      # Axes: [label for -, label for +]; 4 and 5 (triggers) only go +
      AXES = {
        0 => ["Left Stick Left", "Left Stick Right"], 1 => ["Left Stick Up", "Left Stick Down"],
        2 => ["Right Stick Left", "Right Stick Right"], 3 => ["Right Stick Up", "Right Stick Down"]
      }.freeze
      TRIGGERS = { :xbox => ["LT", "RT"], :playstation => ["L2", "R2"], :nintendo => ["ZL", "ZR"] }.freeze
      STICKS = [0, 1, 2, 3].freeze

      module_function

      #------------------------------------------------------------------------
      # Tokens
      #------------------------------------------------------------------------
      def key(code);  return "k:#{code.to_i}"; end
      def pad(code);  return "p:#{code.to_i}"; end
      def axis(code, positive); return "a:#{code.to_i}#{positive ? '+' : '-'}"; end
      def hold(token); return HOLD + token; end

      # [kind, code, positive, hold] or nil for anything that isn't a token.
      def parse(token)
        t = token.to_s
        held = t.start_with?(HOLD)
        t = t[HOLD.length..-1] if held
        m = t.match(/\A([kpa]):(\d{1,3})([+-]?)\z/)
        return nil unless m
        kind = { "k" => :key, "p" => :pad, "a" => :axis }[m[1]]
        return nil if kind == :axis && m[3].empty?
        return nil if kind != :axis && !m[3].empty?
        return [kind, m[2].to_i, m[3] == "+", held]
      end

      def valid?(token)
        return !parse(token).nil?
      end

      def hold?(token)
        return token.to_s.start_with?(HOLD)
      end

      # The token without "hold:".
      def base(token)
        t = token.to_s
        return t.start_with?(HOLD) ? t[HOLD.length..-1] : t
      end

      # True for a key the engine keeps for itself.
      def reserved?(token)
        p = parse(token)
        return p && p[0] == :key && RESERVED_KEYS.include?(p[1]) ? true : false
      end

      def keyboard?(token)
        p = parse(token)
        return p && p[0] == :key
      end

      def controller?(token)
        p = parse(token)
        return p && p[0] != :key
      end

      # What the player sees for a token (style: :xbox, :playstation or
      # :nintendo for controller names).
      def label(token, style = :xbox)
        kind, code, positive, held = parse(token)
        return "" unless kind
        name = case kind
               when :key then KEYS[code] || "Key #{code}"
               when :pad then (PAD[style] || PAD[:xbox])[code] || "Button #{code}"
               else
                 if code >= 4
                   (TRIGGERS[style] || TRIGGERS[:xbox])[code - 4] || "Axis #{code}"
                 else
                   (AXES[code] || [])[positive ? 1 : 0] || "Axis #{code}"
                 end
               end
        return held ? _INTL("Hold {1}", name) : name
      end

      #------------------------------------------------------------------------
      # The engine's bindings (F1)
      #------------------------------------------------------------------------
      def paths
        list = []
        dir = (System.data_directory rescue nil).to_s
        list << dir + FILE unless dir.empty?
        list << File.join("Data", FILE)
        return list
      end

      # game button number => { :keys => [tokens], :pad => [tokens] }, read
      # again whenever the file changes.
      def engine_bindings
        path = paths.find { |p| File.file?(p) }
        return {} unless path
        stamp = [path, File.mtime(path).to_f, File.size(path)]
        return @engine if @engine && @engine_stamp == stamp
        @engine_stamp = stamp
        @engine = read_bindings(File.binread(path))
      rescue StandardError => e
        Reloaded::Log.warning_once("Couldn't read the engine's key bindings (#{e.class}: #{e.message})", :controls)
        return @engine = {}
      end

      def read_bindings(data)
        out = {}
        count = data[8, 4].to_s.unpack1("l<").to_i
        count.times do |i|
          source, code, extra, target = data[12 + i * 16, 16].to_s.unpack("l<4")
          break if target.nil?
          token = case source
                  when 1 then key(code)
                  when 2 then pad(code)
                  when 3 then axis(code, extra.to_i != 0)
                  end
          next unless token
          side = source == 1 ? :keys : :pad
          list = ((out[target] ||= { :keys => [], :pad => [] })[side])
          list << token unless list.include?(token)
        end
        return out
      end

      STYLES = [:auto, :xbox, :playstation, :nintendo].freeze

      # The controller style hints should use, from the controller's name.
      def style_for(name)
        n = name.to_s.downcase
        return :playstation if n =~ /ps3|ps4|ps5|dualshock|dualsense|playstation|sony/
        return :nintendo if n =~ /nintendo|switch|joy-con|joycon|pro controller/
        return :xbox
      end
    end
  end
end
