# frozen_string_literal: true

module Lich
  module Genie
    # A script's jump trace: Remix Script/Trace.cs, a ring of the last 20 entries ("goto x (12)",
    # "gosub y inc.cmd(3)", "return", "passing label z", "match a", "matchwait timeout",
    # "action goto", "exit") that Script.PrintTrace prints after a GOSUB-depth / RETURN error or a
    # script timeout (Script.cs:1822-1824, 1901-1905, 2497-2534 R).
    class Trace
      # @param size [Integer] m_TraceSize
      def initialize(size = 20)
        @size = size
        @entries = Array.new(size)
        @index = -1
      end

      # Trace.Add (Trace.cs:84-112 R): " <file>(<row>)" with both, " <file>" or " (<row>)" with one.
      # @param value [String]
      # @param file_name [String] "" for the main file (Script.GetFileName)
      # @param file_row [Integer]
      # @return [void]
      def add(value, file_name = '', file_row = 0)
        @index += 1
        @index = 0 if @index >= @size
        text = +value.to_s
        if !file_name.empty? && file_row.positive?
          text << " #{file_name}(#{file_row})"
        elsif !file_name.empty?
          text << " #{file_name}"
        elsif file_row.positive?
          text << " (#{file_row})"
        end
        @entries[@index] = text
      end

      # Trace.Clear (Trace.cs:61-64 R): the entries go, the position stays.
      # @return [void]
      def clear
        @entries = Array.new(@size)
      end

      # Trace.ToString (Trace.cs:115-136 R): oldest first, each "\t<entry>\n".
      # @return [String]
      def to_s
        order = ((@index + 1)...@size).to_a + (0..@index).to_a
        order.filter_map { |i| @entries[i] }.reject(&:empty?).map { |entry| "\t#{entry}\n" }.join
      end
    end
  end
end
