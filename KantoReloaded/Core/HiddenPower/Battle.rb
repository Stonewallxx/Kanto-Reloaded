# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Hidden Power (Battle)
#==============================================================================
# The Fight menu shows each move's type as the battle works it out for the
# Pokémon using it (his picks 2026-10-25: Q13 Design 1, The Type's Own
# Button; Q14 Every Worked-Out Type): Hidden Power's own type, Weather Ball
# in weather, Judgment, Techno Blast and Multi-Attack by item, Natural Gift,
# Revelation Dance, the -ate abilities' Normal moves, Ion Deluge and
# Electrify. Always on with Kanto Reloaded.
#
#   Worked out   once per Fight menu, with the battle's own
#                move.pbCalcType(battler); every value it touches on the move
#                and the battler (PIF's @powerBoost, KIF-ER's notes) is put
#                back after
#   EBDX         the button is EBDX's own art for that type: its colour, its
#                type label, its name colour. While generateButtons runs, the
#                move data it reads (GameData::Move.get) shows the worked-out
#                type, so EBDX draws the button itself, and whatever another
#                mod draws after it (Ghostly Possession's ghost badge) stays
#                on top. EBDX's type indicator (SHOWTYPEADVANTAGE, Off unless
#                a map's or trainer's metrics turn it on) follows that type
#   PIF's scene  the button and the info box's type icon: the battle moves'
#                types are the worked-out ones only while the menu draws them
#                (refreshSelection, refreshMoveData), put back after
#
# The move-data view is shared with the Summary's pages (Summary.rb).
#
#   Reloaded::HiddenPower::Battle.worked_out(move, battler)  its type now
#   Reloaded::HiddenPower::Battle.showing(view) { ... }      while a screen
#       draws, GameData::Move.get gives view.call(data) when that's a move
#   Reloaded::HiddenPower::Battle.shown(data, type, power)   a copy of a
#       move's data showing another type (and power)
#==============================================================================

module Reloaded
  module HiddenPower
    module Battle
      PROXIES_MAX = 64          # copies kept (a move, a type, a power each)
      @view = nil
      @proxies = {}

      class << self
        attr_reader :view

        #----------------------------------------------------------------------
        # The move data a screen reads while it draws
        #----------------------------------------------------------------------
        # Runs the block with view in place (a nested call keeps the outer
        # view after it)
        def showing(view)
          before = @view
          @view = view
          return yield
        ensure
          @view = before
        end

        # GameData::Move.get's answer while a view is in place: the view's
        # copy, else the move's own data. The view is out of place while it
        # answers, so a GameData::Move.get of its own gets the real data.
        def through(data)
          view = @view
          return data unless view && data.is_a?(::GameData::Move)
          @view = nil
          begin
            return view.call(data) || data
          ensure
            @view = view
          end
        rescue StandardError => e
          Reloaded::Log.warning_once("Hidden Power: a move's shown type couldn't be worked out (#{e.class}: #{e.message})", :hidden_power)
          return data
        end

        # A copy of a move's data showing another type and power, or nil
        # when it would show the move as it is. Made once for each move,
        # type and power.
        def shown(data, type, power = nil)
          return nil unless data && type
          power = data.base_damage if power.nil?
          return nil if type == data.type && power == data.base_damage
          key = [data.object_id, type, power]
          kept = @proxies[key]
          return kept[1] if kept && kept[0].equal?(data)      # (a Data Patch that remakes the data makes new copies)
          @proxies.clear if @proxies.length >= PROXIES_MAX
          copy = data.dup
          copy.instance_variable_set(:@type, type)
          copy.instance_variable_set(:@base_damage, power)
          @proxies[key] = [data, copy]
          return copy
        end

        #----------------------------------------------------------------------
        # A move's type as the battle works it out
        #----------------------------------------------------------------------
        # The type the battle works out for move used by battler now (its own
        # pbCalcType). Everything that touched on either is put back: values
        # it set, values it added. nil when it can't be worked out.
        def worked_out(move, battler)
          return nil unless move && battler && move.respond_to?(:pbCalcType)
          kept_move = values(move)
          kept_user = values(battler)
          begin
            return move.pbCalcType(battler)
          ensure
            put_back(move, kept_move)
            put_back(battler, kept_user)
          end
        rescue StandardError => e
          Reloaded::Log.warning_once("Hidden Power: a move's type couldn't be worked out for the Fight menu (#{e.class}: #{e.message})", :hidden_power)
          return nil
        end

        # [[move, type], ...]: the battler's moves whose worked-out type
        # isn't the one they have
        def types_for(battler)
          out = []
          return out unless battler && battler.respond_to?(:moves)
          Array(battler.moves).each do |m|
            next unless m && m.respond_to?(:id) && m.id
            t = worked_out(m, battler)
            out << [m, t] if t && t != m.type
          end
          return out
        end

        # Runs the block with each move's own type the one given, put back
        # after (PIF's menu and EBDX's indicator read the battle moves' type)
        def with_types(pairs)
          kept = pairs.map { |m, _t| [m, m.instance_variable_get(:@type)] }
          pairs.each { |m, t| m.instance_variable_set(:@type, t) }
          return yield
        ensure
          kept.each { |m, t| m.instance_variable_set(:@type, t) } if kept
        end

        #----------------------------------------------------------------------
        # EBDX's Fight menu
        #----------------------------------------------------------------------
        # generateButtons with the worked-out types: EBDX draws each button
        # from its own art for that type
        def ebdx_buttons(win)
          battler = win.respond_to?(:battler) ? win.battler : nil
          pairs = types_for(battler)
          win.instance_variable_set(:@kr_hp_types, pairs)
          win.extend(TypeAdvantage) if win.instance_variable_get(:@showTypeAdvantage) && !win.is_a?(TypeAdvantage)
          map = {}
          pairs.each do |m, t|
            copy = shown(::GameData::Move.get(m.id), t)
            map[copy.id] = copy if copy
          end
          return yield if map.empty?
          return showing(proc { |data| map[data.id] }) { yield }
        end

        #----------------------------------------------------------------------
        # Hooks (core: always on)
        #----------------------------------------------------------------------
        def install
          h = Reloaded::Hooks
          if defined?(::GameData::Move) && ::GameData::Move.respond_to?(:get)
            h.prepend(nil, ::GameData::Move.singleton_class, MoveData, :id => :hidden_power_move_data)
          end
          if defined?(::FightWindowEBDX) && ::FightWindowEBDX.method_defined?(:generateButtons)
            h.around(nil, ::FightWindowEBDX, :generateButtons, :id => :hidden_power_ebdx_buttons) do |original, *args|
              Reloaded::HiddenPower::Battle.ebdx_buttons(original.receiver) { original.call(*args) }
            end
          end
          install_pif
          return true
        end

        # PIF's own Fight menu: worked out when it's given its battler (once
        # per menu), shown while it draws a button or the info box
        def install_pif
          return unless defined?(::FightMenuDisplay)
          h = Reloaded::Hooks
          if ::FightMenuDisplay.method_defined?(:battler=)
            h.around(nil, ::FightMenuDisplay, :battler=, :id => :hidden_power_pif_menu) do |original, battler|
              pairs = Reloaded::HiddenPower::Battle.types_for(battler)
              original.receiver.instance_variable_set(:@kr_hp_types, pairs)
              original.call(battler)
            end
          end
          [[:refreshSelection, :hidden_power_pif_buttons], [:refreshMoveData, :hidden_power_pif_info]].each do |name, id|
            next unless ::FightMenuDisplay.method_defined?(name)
            h.around(nil, ::FightMenuDisplay, name, :id => id) do |original, *args|
              pairs = original.receiver.instance_variable_get(:@kr_hp_types)
              next original.call(*args) if pairs.nil? || pairs.empty?
              Reloaded::HiddenPower::Battle.with_types(pairs) { original.call(*args) }
            end
          end
        end

        private

        def values(obj)
          return obj.instance_variables.map { |v| [v, obj.instance_variable_get(v)] }
        end

        def put_back(obj, kept)
          names = {}
          kept.each do |v, val|
            names[v] = true
            obj.instance_variable_set(v, val) unless obj.instance_variable_get(v).equal?(val)
          end
          obj.instance_variables.each { |v| obj.remove_instance_variable(v) unless names[v] }
        end
      end

      # GameData::Move.get: one check while nothing's showing (a prepend:
      # the game reads move data all the time)
      module MoveData
        def get(other)
          return super unless Reloaded::HiddenPower::Battle.view
          return Reloaded::HiddenPower::Battle.through(super)
        end
      end

      # EBDX's type indicator, on a window that has it on (no other window
      # pays for it): when the chosen move changes, EBDX works out its
      # matchup with the move's shown type
      module TypeAdvantage
        def update
          pairs = @kr_hp_types
          return super() if @oldindex == @index || pairs.nil? || pairs.empty?
          return Reloaded::HiddenPower::Battle.with_types(pairs) { super() }
        end
      end
    end
  end
end
