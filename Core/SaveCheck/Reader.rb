#==============================================================================
# Kanto Reloaded: the Save Checker's reader
#==============================================================================
# Reads a save file the way the game does (Marshal), without failing on a
# class the game hasn't got (a mod that's off or gone): each one is stood in
# for while the check runs (Stub), and taken away after. The file is only
# read here.
#
#   Reloaded::SaveCheck::Reader.open(path) do |data, missing|
#     # data: the save's Hash; missing: ["MegaMod::Data", ...]
#   end
#
# A stand-in keeps what the save held (its instance variables, or its
# _dump / marshal_dump data), so anything written back out (Make It
# Loadable's side file, a fixed save) is written exactly as it was read.
# Structs and user subclasses of String, Array and Hash can't be stood in
# for: such a save is reported as one the checker can't open.
#==============================================================================

module Reloaded
  module SaveCheck
    # An object of a class the game hasn't got, while a save is checked.
    class Stub
      def self._load(str)
        obj = allocate
        obj.instance_variable_set(:@__kr_dump, str)
        return obj
      end

      def _dump(_level = -1)
        return @__kr_dump
      end

      def marshal_load(data)
        @__kr_data = data
      end

      def marshal_dump
        return @__kr_data
      end

      # Written back the way it was read: _dump or marshal_dump only for
      # the objects that came that way.
      def respond_to?(name, include_all = false)
        return instance_variable_defined?(:@__kr_dump) if name.to_sym == :_dump
        return instance_variable_defined?(:@__kr_data) if name.to_sym == :marshal_dump
        return super
      end

      # What it holds, for the Inspector.
      def kr_held
        return @__kr_dump if instance_variable_defined?(:@__kr_dump)
        return @__kr_data if instance_variable_defined?(:@__kr_data)
        return nil
      end
    end

    module Reader
      LIMIT = 200        # stand-ins at most, before a save counts as unreadable

      @made = []         # [{ :parent, :name, :full, :obj }] while a save is open
      @lent = []         # [[class, method, :singleton or :instance]] lent for the read

      class << self
        # Opens a save; yields its data and the classes stood in for, with
        # the stand-ins in place until the block returns.
        def open(path)
          bytes = Reloaded::SaveFile.bytes(path)          # a backup KIF packed, unpacked
          asked = []
          begin
            data = load(bytes, asked)
            return yield(data, asked.uniq)
          ensure
            remove_all
          end
        end

        # The class (or module) was one the game hasn't got.
        def stub?(klass)
          return false unless klass.is_a?(Module)
          return true if klass.is_a?(Class) && klass < Stub
          return @made.any? { |m| m[:obj].equal?(klass) }
        end

        # Something stood in for, anywhere in value (a whole save value).
        def holds_stub?(value)
          return false if @made.empty?
          found = false
          SaveCheck.walk(value) do |obj, _path|
            if obj.is_a?(Stub) || extended_by_stub?(obj)
              found = true
              :stop
            end
          end
          return found
        end

        def extended_by_stub?(obj)
          return false if @made.empty? || obj.is_a?(Module)
          mods = (obj.singleton_class.included_modules rescue [])
          return mods.any? { |m| @made.any? { |x| x[:obj].equal?(m) } }
        end

        private

        def load(bytes, asked)
          tries = 0
          begin
            return Marshal.load(bytes)
          rescue ArgumentError, TypeError => e
            tries += 1
            raise if tries > LIMIT
            msg = e.message.to_s
            if (m = msg.match(%r{undefined class/module ([A-Za-z_][\w:]*)}))
              # "Outer::" is the module around a missing class
              if m[1].end_with?("::")
                stand_in(m[1].chomp("::"), false)
              else
                asked << m[1]
                stand_in(m[1], true)
              end
              retry
            elsif (m = msg.match(/([A-Za-z_][\w:]*) does not refer to (class|module)/)) && swap(m[1], m[2] == "class")
              retry
            elsif (m = msg.match(/class ([A-Za-z_][\w:]*) needs to have method .?_load/)) && lend(m[1], :_load)
              retry
            elsif (m = msg.match(/instance of ([A-Za-z_][\w:]*) needs to have method .?marshal_load/)) && lend(m[1], :marshal_load)
              retry
            end
            raise
          end
        end

        # A class (or a module: the last part) in modules (the parts before
        # it), each made only where the game has nothing by that name.
        def stand_in(name, last_is_class)
          parts = name.split("::")
          parent = Object
          parts.each_with_index do |part, i|
            if parent.const_defined?(part, false)
              parent = parent.const_get(part, false)
              raise TypeError, "#{name} can't be stood in for" unless parent.is_a?(Module)
              next
            end
            obj = i == parts.length - 1 && last_is_class ? Class.new(Stub) : Module.new
            parent.const_set(part, obj)
            @made << { :parent => parent, :name => part, :full => parts[0..i].join("::"), :obj => obj }
            parent = obj
          end
        end

        # A stand-in made as the wrong kind (a module where a class goes, or
        # the other way round), made again as the right one.
        def swap(full, want_class)
          entry = @made.find { |m| m[:full] == full }
          return false unless entry
          old = entry[:obj]
          obj = want_class ? Class.new(Stub) : Module.new
          old.constants(false).each { |c| obj.const_set(c, old.const_get(c, false)) }
          entry[:parent].send(:remove_const, entry[:name])
          entry[:parent].const_set(entry[:name], obj)
          @made.each { |m| m[:parent] = obj if m[:parent].equal?(old) }
          entry[:obj] = obj
          return true
        end

        # A class the game has, but without the way back from how the save
        # wrote it (a mod's class changed; outside the game, the engine's
        # Color, Tone and Table): lent _load (or marshal_load) for the read,
        # the way a stand-in reads it.
        def lend(name, how)
          klass = (Object.const_get(name) rescue nil)
          return false unless klass.is_a?(Class) && !(klass < Stub)
          if how == :_load
            return false if klass.respond_to?(:_load)
            klass.define_singleton_method(:_load) do |str|
              obj = allocate
              obj.instance_variable_set(:@__kr_dump, str)
              obj
            end
            @lent << [klass, :_load, :singleton]
            unless klass.method_defined?(:_dump)
              klass.send(:define_method, :_dump) { |_level = -1| @__kr_dump }
              @lent << [klass, :_dump, :instance]
            end
          else
            return false if klass.method_defined?(:marshal_load)
            klass.send(:define_method, :marshal_load) { |data| @__kr_data = data }
            @lent << [klass, :marshal_load, :instance]
            unless klass.method_defined?(:marshal_dump)
              klass.send(:define_method, :marshal_dump) { @__kr_data }
              @lent << [klass, :marshal_dump, :instance]
            end
          end
          return true
        end

        def remove_all
          @lent.reverse_each do |klass, name, where|
            target = where == :singleton ? klass.singleton_class : klass
            target.send(:remove_method, name) rescue nil
          end
          @lent = []
          @made.reverse_each do |m|
            parent = m[:parent]
            next unless parent.const_defined?(m[:name], false) && parent.const_get(m[:name], false).equal?(m[:obj])
            parent.send(:remove_const, m[:name])
          end
          @made = []
        end
      end
    end
  end
end
