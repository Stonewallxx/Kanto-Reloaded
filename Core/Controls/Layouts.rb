#==============================================================================
# Kanto Reloaded: controls layouts (the Controls screen's Layouts button)
#==============================================================================
# The player's own layouts: named copies of every action's bindings (both
# columns) and the Feel settings, in <mod folder>\Settings\ControlLayouts.json, for all
# saves (like the controls themselves). Up to MAX of them.
#
#   - Load puts a layout's controls and Feel on
#   - share codes ("KRC1:...") carry one to another game; pasting one checks
#     every input and value, and skips actions that game doesn't have
#
# The built-in layouts (Game's Layout; Pokémon-Style once its features have
# their own actions) aren't stored: the Controls screen offers them itself.
#==============================================================================

module Reloaded
  module Controls
    module Layouts
      FILE = "ControlLayouts.json"
      SCHEMA = 1
      MAX = 12
      NAME_MAX = 16
      CODE_PREFIX = "KRC1:"

      # Pokémon-Style (built in): the controller as in the main Pokémon
      # games, picked 2026-10-17. Every other controller input stays on the
      # game's layout, and the keyboard isn't touched. Tapping Select is
      # left free for the Overworld Menu.
      POKEMON_STYLE = {
        :run        => ["p:1"],              # B, held
        :pause_menu => ["p:2", "p:6"],       # X, Start
        :ready_menu => ["p:3"],              # Y
        :quicksave  => ["hold:p:4"],         # Select, held
        :speed_up   => ["a:5+"]              # RT
      }.freeze

      class << self
        # [{"name", "bindings", "feel"}, ...]
        def list
          load_file unless @list
          return @list
        end

        def full?
          return list.length >= MAX
        end

        # A name for a new layout: "Layout 1", "Layout 2"...
        def next_name
          n = 1
          n += 1 while list.any? { |l| l["name"] == _INTL("Layout {1}", n) }
          return _INTL("Layout {1}", n)
        end

        # The controls and Feel as they are now, as a layout.
        def capture(name)
          feel = {}
          Controls::FEEL.each { |k| feel[k.to_s] = Reloaded::Settings.get(k) }
          return { "name" => clean_name(name), "bindings" => Controls.layout_bindings, "feel" => feel }
        end

        # Saves the controls as they are now as a new layout; false when full
        # or the file couldn't be written.
        def add(name)
          return false if full?
          list << capture(unique_name(name))
          return save
        end

        def save_over(i)
          return false unless list[i]
          list[i] = capture(list[i]["name"])
          return save
        end

        def rename(i, name)
          return false unless list[i] && !clean_name(name).empty?
          list[i]["name"] = unique_name(name, i)
          return save
        end

        def delete(i)
          return false unless list[i]
          list.delete_at(i)
          return save
        end

        # Puts Pokémon-Style on the controller (the keyboard stays as it is).
        def pokemon_style
          Controls.apply_side(:pad, POKEMON_STYLE)
          return true
        end

        # Puts layout i's controls and Feel on.
        def load(i)
          l = list[i]
          return false unless l
          Controls.apply_layout(l["bindings"])
          l["feel"].each do |k, v|
            key = Controls::FEEL.find { |f| f.to_s == k }
            Reloaded::Settings.set(key, v) if key
          end
          return true
        end

        def share_code(i)
          return nil unless list[i]
          return Reloaded::ShareCodes.encode(CODE_PREFIX, list[i])
        end

        # The layout in a share code, checked, or nil.
        def read_code(text)
          return clean(Reloaded::ShareCodes.decode(CODE_PREFIX, text))
        end

        # Adds a layout read from a share code.
        def add_layout(layout)
          return false if full? || !layout
          list << layout.merge("name" => unique_name(layout["name"]))
          return save
        end

        def path
          return File.join(Reloaded::Paths.settings_dir, FILE)
        end

        # Forgets what was read (tests; a changed file).
        def reload
          @list = nil
        end

        private

        def clean_name(name)
          return name.to_s.strip[0, NAME_MAX].to_s
        end

        # The name, or "Name (2)", "Name (3)"... when another layout (not
        # layout skip) already has it.
        def unique_name(name, skip = nil)
          base = clean_name(name)
          taken = list.each_with_index.reject { |_l, i| i == skip }.map { |l, _i| l["name"] }
          return base unless taken.include?(base)
          n = 2
          loop do
            tail = " (#{n})"
            candidate = base[0, NAME_MAX - tail.length].rstrip + tail
            return candidate unless taken.include?(candidate)
            n += 1
          end
        end

        # A layout from a file or a share code with every value checked:
        # inputs that aren't inputs (or are the engine's own keys) and Feel
        # values of the wrong kind are dropped. nil when nothing is left.
        def clean(data)
          return nil unless data.is_a?(Hash)
          bindings = {}
          (data["bindings"].is_a?(Hash) ? data["bindings"] : {}).each do |id, sides|
            next unless id.is_a?(String) && id.length <= 64 && sides.is_a?(Hash)
            entry = {}
            Controls::SIDES.each do |side|
              tokens = sides[side.to_s]
              next unless tokens.is_a?(Array)
              entry[side.to_s] = tokens.select { |t| t.is_a?(String) && Inputs.valid?(t) && !Inputs.reserved?(t) }.uniq.first(16)
            end
            bindings[id] = entry unless entry.empty?
          end
          feel = {}
          (data["feel"].is_a?(Hash) ? data["feel"] : {}).each do |k, v|
            key = Controls::FEEL.find { |f| f.to_s == k }
            feel[key.to_s] = v if key && (v == true || v == false || v.is_a?(Integer))
          end
          return nil if bindings.empty? && feel.empty?
          name = clean_name(data["name"])
          name = _INTL("Shared Layout") if name.empty?
          return { "name" => name, "bindings" => bindings, "feel" => feel }
        end

        def load_file
          @list = []
          text = Reloaded::Paths.read_text(path)
          return if text.nil? || text.strip.empty?
          data = Reloaded::JSON.parse(text)
          return unless data.is_a?(Hash) && data["layouts"].is_a?(Array)
          data["layouts"].first(MAX).each { |l| (l = clean(l)) && @list << l }
        rescue Exception => e
          kept = Reloaded::Paths.set_aside(path)
          Reloaded::Log.exception("Could not read #{FILE}; no layouts (the file was kept as #{kept ? File.basename(kept) : "it was"})", e, :controls)
          @list = []
        end

        def save
          data = { "schema" => SCHEMA, "layouts" => list }
          Reloaded::Paths.write_atomic(path, Reloaded::JSON.generate(data, true))
          return true
        rescue Exception => e
          Reloaded::Log.exception("Could not write #{FILE}", e, :controls)
          return false
        end
      end
    end
  end
end
