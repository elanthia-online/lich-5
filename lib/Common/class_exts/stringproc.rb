# Carve out from lich.rbw
# extension to StringProc class 2024-06-13

module Lich
  module Common
    class StringProc
      def initialize(string)
        @string = string
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
