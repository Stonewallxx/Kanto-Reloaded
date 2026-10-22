#==============================================================================
# Kanto Reloaded (Dev): line diffs for the Hook Checker
#==============================================================================
# What changed in a method's body between two KIF versions, line by line
# (longest common subsequence; method bodies are short).
#
#   ops = Diff.lines(old_lines, new_lines)   [[:same | :del | :add, line], ...]
#   Diff.counts(ops)                          [added, removed]
#   Diff.hunks(ops, 2)                        the changed lines with 2 lines
#                                             around them; a gap is [:gap, nil]
#==============================================================================

module Reloaded
  module HookCheck
    module Diff
      class << self
        def lines(a, b)
          a = Array(a)
          b = Array(b)
          head = 0
          head += 1 while head < a.length && head < b.length && a[head] == b[head]
          tail = 0
          tail += 1 while tail < a.length - head && tail < b.length - head && a[-1 - tail] == b[-1 - tail]
          mid = lcs(a[head...(a.length - tail)], b[head...(b.length - tail)])
          return a[0...head].map { |l| [:same, l] } + mid + a[(a.length - tail)..-1].map { |l| [:same, l] }
        end

        def counts(ops)
          return [ops.count { |k, _| k == :add }, ops.count { |k, _| k == :del }]
        end

        def hunks(ops, context = 2)
          keep = Array.new(ops.length, false)
          ops.each_with_index do |(k, _), i|
            next if k == :same
            ([i - context, 0].max..[i + context, ops.length - 1].min).each { |j| keep[j] = true }
          end
          out = []
          ops.each_with_index do |op, i|
            if keep[i]
              out << op
            elsif out.any? && out.last[0] != :gap
              out << [:gap, nil]
            end
          end
          out.pop if out.any? && out.last[0] == :gap
          return out
        end

        private

        def lcs(a, b)
          n = a.length
          m = b.length
          return b.map { |l| [:add, l] } if n == 0
          return a.map { |l| [:del, l] } if m == 0
          t = Array.new(n + 1) { Array.new(m + 1, 0) }
          (n - 1).downto(0) do |i|
            (m - 1).downto(0) do |j|
              t[i][j] = a[i] == b[j] ? t[i + 1][j + 1] + 1 : [t[i + 1][j], t[i][j + 1]].max
            end
          end
          out = []
          i = j = 0
          while i < n && j < m
            if a[i] == b[j]
              out << [:same, a[i]]
              i += 1
              j += 1
            elsif t[i + 1][j] >= t[i][j + 1]
              out << [:del, a[i]]
              i += 1
            else
              out << [:add, b[j]]
              j += 1
            end
          end
          a[i..-1].each { |l| out << [:del, l] }
          b[j..-1].each { |l| out << [:add, l] }
          return out
        end
      end
    end
  end
end
