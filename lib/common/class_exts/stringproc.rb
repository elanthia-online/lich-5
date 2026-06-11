# Carve out from lich.rbw
# extension to StringProc class 2024-06-13

module Lich
  module Common
    class StringProc
      ##
      # Create a StringProc that wraps the provided source text and normalizes CRLF and CR newlines to LF.
      # The input is converted with `to_s` and stored with all `\r\n` and `\r` replaced by `\n`.
      # @param [Object] string - The source text to wrap; will be converted to a String and normalized.
      # @param string [String, #to_s] Ruby source text to evaluate when called.
      def initialize(string)
        @string = string.to_s.gsub(/\r\n?/, "\n")
      end

      ##
      # Determine whether an empty Proc is an instance of the given class or module.
      # @param [Module] type - The class or module to check against.
      # @return [Boolean] `true` if a Proc is kind of `type`, `false` otherwise.
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
