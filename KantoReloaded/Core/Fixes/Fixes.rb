#==============================================================================
# Kanto Reloaded: fixes to the game's own code
#==============================================================================
# Bugs in PIF or KIF Beta that Kanto Reloaded fixes with hooks. A fix that
# has to replace a whole method is written against that method's source:
# it applies only while the method is still that source (its fingerprint
# matches), so an update to the game never gets an old copy over a new
# method. When it doesn't match, the fix stays off and the log says so.
#
#   Reloaded::Fixes.register(:my_fix, "What it fixes") do
#     next false unless Reloaded::Fixes.source?(PokeBattle_Scene, :pbFightMenu, 1739628443)
#     Reloaded::Hooks.prepend(nil, PokeBattle_Scene, MyFix, :id => :fix_my_fix)
#   end
#
# The block returns false when the fix can't apply.
#==============================================================================

module Reloaded
  module Fixes
    @fixes = []

    class << self
      def register(id, name, &apply)
        @fixes << { :id => id.to_sym, :name => name, :apply => apply, :on => false }
        return id
      end

      def boot
        @fixes.each do |fix|
          begin
            fix[:on] = fix[:apply].call ? true : false
            if fix[:on]
              Reloaded::Log.info("Fix on: #{fix[:name]}", :fixes)
            else
              Reloaded::Log.info("Fix off (the game's code isn't what it was written for): #{fix[:name]}", :fixes)
            end
          rescue Exception => e
            raise if Reloaded::Hooks.passthrough?(e)
            Reloaded::Log.exception("Fix failed to apply: #{fix[:name]}", e, :fixes)
          end
        end
        return true
      end

      def on?(id)
        fix = @fixes.find { |f| f[:id] == id.to_sym }
        return fix ? fix[:on] : false
      end

      # True when klass's own method name has this source fingerprint.
      def source?(klass, name, crc)
        return false unless klass.method_defined?(name) || klass.private_method_defined?(name)
        m = klass.instance_method(name)
        return false unless m.owner == klass
        return source_crc(m) == crc
      end

      # CRC32 of a method's source: its def line to the "end" at the same
      # indent, line endings as LF. nil when the source can't be read.
      def source_crc(method)
        file, line = method.source_location
        return lines_crc(file, line)
      end

      # The same for a handler the game adds with a proc (Foo.add(:X, proc { ...
      # }) ): its first line to the "})" closing it
      def handler_crc(prc)
        file, line = prc.source_location
        return lines_crc(file, line, "})")
      end

      def lines_crc(file, line, stop = nil)
        file = Reloaded::Paths.script_file(file) if file   # in game: only the file's name
        return nil unless file && line && File.file?(file)
        lines = File.readlines(file, :encoding => "UTF-8").map { |l| l.chomp.sub(/\r\z/, "") }
        first = lines[line - 1]
        return nil unless first
        stop ||= first[/\A */] + "end"
        out = []
        lines[(line - 1)..-1].each do |l|
          out << l
          break if l == stop
        end
        return Zlib.crc32(out.join("\n"))
      rescue StandardError
        return nil
      end
    end
  end
end
