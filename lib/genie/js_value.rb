# frozen_string_literal: true

module Lich
  module Genie
    # The JavaScript values the in-Lich stand-in for Remix's Jint 4 engine ({JsRuntime}) works with,
    # and the conversions Jint and the CLR apply to them. Ruby carries them as:
    #   String = a JS string, Float = a JS number, true/false = a JS boolean,
    #   nil = undefined, {NULL} = null.
    # Nothing else (objects, arrays, functions) ever escapes into a script: whatever would is
    # {JsRuntime::Unsupported}.
    module JsValue
      # JS null (undefined is nil).
      NULL = Object.new.tap do |null|
        null.define_singleton_method(:inspect) { 'null' }
        null.freeze
      end

      # JS WhiteSpace + LineTerminator (ECMA-262 StringToNumber trims these).
      WHITESPACE = [0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x20, 0xA0, 0x1680, *0x2000..0x200A, 0x2028, 0x2029,
                    0x202F, 0x205F, 0x3000, 0xFEFF].pack('U*').freeze

      module_function

      # @return [Boolean] undefined or null
      def nullish?(value)
        value.nil? || value.equal?(NULL)
      end

      # ECMA-262 ToString of a primitive (Number::toString for numbers: "1e+21", "1.5", "0").
      # @return [String]
      def to_string(value)
        case value
        when String then value
        when Float then number_to_s(value)
        when true then 'true'
        when false then 'false'
        when nil then 'undefined'
        else 'null'
        end
      end

      # Number::toString(x) (ECMA-262 6.1.6.1.20) with the shortest round-trip digits.
      # @param number [Float]
      # @return [String]
      def number_to_s(number)
        return 'NaN' if number.nan?
        return number.positive? ? 'Infinity' : '-Infinity' if number.infinite?
        return '0' if number.zero?

        digits, exp = Numeric.shortest_digits(number.abs)
        body = layout(digits, exp + 1) # value = 0.digits * 10**n
        number.negative? ? "-#{body}" : body
      end

      def layout(digits, n)
        k = digits.length
        if k <= n && n <= 21 then digits + ('0' * (n - k))
        elsif n.positive? && n <= 21 then "#{digits[0, n]}.#{digits[n..]}"
        elsif n > -6 && n <= 0 then "0.#{'0' * -n}#{digits}"
        else
          e = n - 1
          mantissa = k == 1 ? digits : "#{digits[0]}.#{digits[1..]}"
          "#{mantissa}e#{e.negative? ? '-' : '+'}#{e.abs}"
        end
      end
      private_class_method :layout

      # A JS value handed to a CLR `string` parameter (getVar's / setVar's name, Script.cs:701-704
      # R): Jint converts it with ToString (`getVar(1e21)` reads the local "1e+21"; genieflow
      # probe), undefined/null arrive as null.
      # @return [String, nil]
      def param_string(value)
        nullish?(value) ? nil : to_string(value)
      end

      # A JS value handed to a CLR `object` parameter, then `o.ToString()` / `Conversions.ToString`
      # (echo, put, setVar's value, Script.cs:708-776 R): a number arrives as a double (.NET
      # formatting: "1E+21", "-0"), a boolean as a bool ("True"), undefined/null as null.
      # @return [String, nil]
      def clr_string(value)
        case value
        when String then value
        when Float then Numeric.format_double(value)
        when true then 'True'
        when false then 'False'
        end
      end

      # `value[0]` (a member read): a string's first UTF-16 unit, undefined for any other
      # primitive or an empty string.
      # @return [String, nil]
      # @raise [JsRuntime::JsError] on undefined/null
      def index0(value)
        member_guard(value, '0')
        value.is_a?(String) ? value[0] : nil
      end

      # `value.toString()`.
      # @return [String]
      # @raise [JsRuntime::JsError] on undefined/null
      def call_to_string(value)
        member_guard(value, 'toString')
        to_string(value)
      end

      # Jint 4's TypeError for a member read on undefined/null (genieflow probe).
      def member_guard(value, name)
        return unless nullish?(value)

        raise JsRuntime::JsError, "Cannot read property '#{name}' of #{to_string(value)}"
      end

      # ECMA-262 ToNumber of a primitive (StringToNumber for strings).
      # @return [Float]
      def to_number(value)
        case value
        when Float then value
        when true then 1.0
        when false, NULL then 0.0
        when String then string_to_number(value)
        else Float::NAN
        end
      end

      def string_to_number(text)
        body = text.gsub(/\A[#{WHITESPACE}]+|[#{WHITESPACE}]+\z/o, '')
        case body
        when '' then 0.0
        when /\A0[xX]([0-9a-fA-F]+)\z/ then Regexp.last_match(1).to_i(16).to_f
        when /\A0[oO]([0-7]+)\z/ then Regexp.last_match(1).to_i(8).to_f
        when /\A0[bB]([01]+)\z/ then Regexp.last_match(1).to_i(2).to_f
        when /\A([+-]?)Infinity\z/ then Regexp.last_match(1) == '-' ? -Float::INFINITY : Float::INFINITY
        when /\A[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?\z/ then Float(body)
        else Float::NAN
        end
      end
      private_class_method :string_to_number

      # ToUint32 (ECMA-262 7.1.7).
      # @param number [Float]
      # @return [Integer]
      def to_uint32(number)
        return 0 if number.nan? || number.infinite?

        number.truncate % (2**32)
      end

      # `String.prototype.split("|")`: the empty string is one empty element.
      # @param text [String]
      # @return [Array<String>]
      def split_bar(text)
        text.empty? ? [''] : text.split('|', -1)
      end

      # `Array.prototype.join("|")`: holes, undefined and null are empty.
      # @param list [Array]
      # @return [String]
      def join_bar(list)
        list.map { |item| nullish?(item) ? '' : to_string(item) }.join('|')
      end
    end
  end
end
