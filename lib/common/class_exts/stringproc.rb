# Carve out from lich.rbw
# extension to StringProc class 2024-06-13

module Lich
  module Common
    class StringProc
      # Creates a delayed-evaluation wrapper for map/script mini-code.
      #
      # Map data and legacy serialized StringProc payloads may contain bare
      # carriage returns from older editors, imports, or platform-specific
      # line endings. Ruby warns when `eval` receives `\r` in the middle of a
      # line, even though it treats the character as whitespace. Normalize
      # CRLF and bare CR to LF at construction time so later evaluation is
      # warning-free and serialized output is kept in the canonical newline
      # form.
      #
      # @param string [String, #to_s] Ruby source text to evaluate when called.
      # @return [void]
      def initialize(string)
        @string = string.to_s.gsub(/\r\n?/, "\n")
      end

      def kind_of?(type)
        Proc.new {}.kind_of? type
      end

      def class
        Proc
      end

      def call(*_a)
        proc { eval(@string) }.call
      end

      def _dump(_d = nil)
        @string
      end

      def inspect
        "StringProc.new(#{@string.inspect})"
      end

      def to_json(*args)
        ";e #{_dump}".to_json(args)
      end

      def StringProc._load(string)
        StringProc.new(string)
      end
    end
  end
end
