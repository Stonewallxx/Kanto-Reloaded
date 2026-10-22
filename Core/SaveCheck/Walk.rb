#==============================================================================
# Kanto Reloaded: walking a save
#==============================================================================
# The Save Checker looks through everything a save holds with one walker:
# every object once, with the path to it from where the walk began.
#
#   Reloaded::SaveCheck.walk(data) do |obj, path|
#     # path: [:storage_system, :@boxes, 3, :@pokemon, 6]
#     :skip if obj.is_a?(Pokemon)      # don't look inside this one
#   end
#
# Plain values (nil, true, false, numbers, symbols, strings, times) are
# passed over; arrays, hashes, structs and objects are looked inside (hash
# values, not keys). A save with more than NODE_LIMIT objects is cut short
# (the walk returns :limit).
#==============================================================================

module Reloaded
  module SaveCheck
    NODE_LIMIT = 500_000

    class << self
      # Each object in value, once. The block may return :skip (not inside
      # this one) or :stop (the walk ends).
      def walk(value, start = [])
        seen = {}.compare_by_identity
        stack = [[value, start]]
        n = 0
        until stack.empty?
          obj, path = stack.pop
          next if leaf?(obj) || seen[obj]
          seen[obj] = true
          return :limit if (n += 1) > NODE_LIMIT
          case yield(obj, path)
          when :stop then return :stop
          when :skip then next
          end
          case obj
          when Array then (obj.length - 1).downto(0) { |i| stack << [obj[i], path + [i]] }
          when Hash then obj.to_a.reverse_each { |k, v| stack << [v, path + [k]] }
          when Struct then obj.each_pair.to_a.reverse_each { |k, v| stack << [v, path + [k]] }
          when Module then next
          else obj.instance_variables.reverse_each { |iv| stack << [obj.instance_variable_get(iv), path + [iv]] }
          end
        end
        return nil
      end

      # A value with nothing inside to look at.
      def leaf?(obj)
        return obj.nil? || obj.equal?(true) || obj.equal?(false) || obj.is_a?(Numeric) || obj.is_a?(Symbol) ||
               obj.is_a?(String) || obj.is_a?(Time) || obj.is_a?(Regexp)
      end

      # A path, for a report: "player > @party > 2".
      def path_words(path)
        return path.map(&:to_s).join(" > ")
      end
    end
  end
end
