#==============================================================================
# Kanto Reloaded: JSON
#==============================================================================
# A strict JSON reader and writer. PIF's own ::JSON.parse runs the text as
# Ruby code (eval) and its generate doesn't escape strings, so Kanto
# Reloaded never uses it for its files.
#
#   Reloaded::JSON.parse(text)          Hash/Array/String/Integer/Float/
#                                       true/false/nil; object keys are Strings
#   Reloaded::JSON.generate(value, pretty = false)
#
# parse raises Reloaded::JSON::ParseError on anything that isn't JSON.
#==============================================================================

module Reloaded
  module JSON
    class ParseError < StandardError; end

    MAX_DEPTH = 64

    class << self
      def parse(text)
        reader = Reader.new(text.to_s)
        value = reader.value
        reader.finish
        return value
      end

      def generate(value, pretty = false)
        out = +""
        write(out, value, pretty ? 0 : nil)
        return out
      end

      private

      def write(out, value, indent)
        case value
        when Hash
          return out << "{}" if value.empty?
          out << "{"
          value.each_with_index do |(key, item), i|
            out << "," if i > 0
            newline(out, indent, 1)
            write_string(out, key.to_s)
            out << (indent ? ": " : ":")
            write(out, item, indent && indent + 1)
          end
          newline(out, indent, 0)
          out << "}"
        when Array
          return out << "[]" if value.empty?
          out << "["
          value.each_with_index do |item, i|
            out << "," if i > 0
            newline(out, indent, 1)
            write(out, item, indent && indent + 1)
          end
          newline(out, indent, 0)
          out << "]"
        when String then write_string(out, value)
        when Symbol then write_string(out, value.to_s)
        when Integer then out << value.to_s
        when Float
          raise ArgumentError, "JSON can't hold #{value}" if value.nan? || value.infinite?
          out << value.to_s
        when true then out << "true"
        when false then out << "false"
        when nil then out << "null"
        else
          raise ArgumentError, "JSON can't hold a #{value.class}"
        end
      end

      def newline(out, indent, extra)
        return unless indent
        out << "\n" << ("  " * (indent + extra))
      end

      ESCAPES = { "\"" => "\\\"", "\\" => "\\\\", "\b" => "\\b", "\f" => "\\f",
                  "\n" => "\\n", "\r" => "\\r", "\t" => "\\t" }.freeze

      def write_string(out, text)
        text = text.dup.force_encoding(Encoding::UTF_8)
        out << "\""
        text.each_char do |ch|
          if ESCAPES[ch]
            out << ESCAPES[ch]
          elsif ch.ord < 0x20
            out << format("\\u%04x", ch.ord)
          else
            out << ch
          end
        end
        out << "\""
      end
    end

    # Recursive-descent reader over the text's characters.
    class Reader
      def initialize(text)
        @text = text.dup.force_encoding(Encoding::UTF_8).delete_prefix("﻿")
        @pos = 0
        @depth = 0
      end

      def value
        skip_space
        ch = @text[@pos]
        case ch
        when "{" then object
        when "[" then array
        when "\"" then string
        when "t" then literal("true", true)
        when "f" then literal("false", false)
        when "n" then literal("null", nil)
        when "-", "0".."9" then number
        when nil then fail!("unexpected end of text")
        else fail!("unexpected #{ch.inspect}")
        end
      end

      def finish
        skip_space
        fail!("unexpected text after the value") if @pos < @text.length
      end

      private

      def object
        nest do
          @pos += 1
          result = {}
          skip_space
          if @text[@pos] == "}"
            @pos += 1
            next result
          end
          loop do
            skip_space
            fail!("expected a key") unless @text[@pos] == "\""
            key = string
            skip_space
            expect(":")
            result[key] = value
            skip_space
            if @text[@pos] == ","
              @pos += 1
            elsif @text[@pos] == "}"
              @pos += 1
              break
            else
              fail!("expected , or }")
            end
          end
          result
        end
      end

      def array
        nest do
          @pos += 1
          result = []
          skip_space
          if @text[@pos] == "]"
            @pos += 1
            next result
          end
          loop do
            result << value
            skip_space
            if @text[@pos] == ","
              @pos += 1
            elsif @text[@pos] == "]"
              @pos += 1
              break
            else
              fail!("expected , or ]")
            end
          end
          result
        end
      end

      def string
        @pos += 1
        out = +""
        loop do
          ch = @text[@pos]
          fail!("unterminated string") if ch.nil?
          @pos += 1
          case ch
          when "\""
            return out
          when "\\"
            out << escape
          else
            fail!("control character in string") if ch.ord < 0x20
            out << ch
          end
        end
      end

      def escape
        ch = @text[@pos]
        @pos += 1
        case ch
        when "\"" then "\""
        when "\\" then "\\"
        when "/" then "/"
        when "b" then "\b"
        when "f" then "\f"
        when "n" then "\n"
        when "r" then "\r"
        when "t" then "\t"
        when "u"
          code = hex4
          if code >= 0xD800 && code <= 0xDBFF && @text[@pos, 2] == "\\u"
            @pos += 2
            low = hex4
            code = 0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00) if low >= 0xDC00 && low <= 0xDFFF
          end
          [code].pack("U")
        else
          fail!("bad escape \\#{ch}")
        end
      end

      def hex4
        digits = @text[@pos, 4].to_s
        fail!("bad \\u escape") unless digits =~ /\A[0-9a-fA-F]{4}\z/
        @pos += 4
        return digits.to_i(16)
      end

      def number
        match = /\A-?(?:0|[1-9]\d*)(\.\d+)?([eE][+-]?\d+)?/.match(@text[@pos..-1])
        fail!("bad number") unless match
        @pos += match[0].length
        return (match[1] || match[2]) ? match[0].to_f : match[0].to_i
      end

      def literal(word, result)
        fail!("unexpected text") unless @text[@pos, word.length] == word
        @pos += word.length
        return result
      end

      def expect(ch)
        fail!("expected #{ch}") unless @text[@pos] == ch
        @pos += 1
      end

      def skip_space
        @pos += 1 while @pos < @text.length && " \t\r\n".include?(@text[@pos])
      end

      def nest
        @depth += 1
        fail!("nested too deeply") if @depth > MAX_DEPTH
        result = yield
        @depth -= 1
        return result
      end

      def fail!(message)
        raise ParseError, "#{message} at character #{@pos}"
      end
    end
  end
end
