# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# Strict VB Conversions.ToInteger (EvalShift %argcount, Script.cs:3005 R). EVERY expected
# value / message below was answered by the real .NET 8 runtime through genieoracle
# `tointmsg` (Remix build); genie-port-lab/reference/fuzz_vb_toint.rb fuzzes the rest.
RSpec.describe Lich::Genie::VbConversions do
  invalid = ->(s) { "Conversion from string \"#{s[0, 32]}\" to type 'Integer' is not valid." }
  overflow = 'Arithmetic operation resulted in an overflow.'
  ideographic = [0x3000].pack('U')
  infinity = [0x221E].pack('U')

  rows = [
    ["0", 0],
    ["42", 42],
    ["-7", -7],
    ["+5", 5],
    [" 5 ", 5],
    ["\t5\t", 5],
    ["2.5", 2],
    ["3.5", 4],
    ["-2.5", -2],
    ["0.5", 0],
    ["1.5", 2],
    [".5", 0],
    ["5.", 5],
    ["1e3", 1000],
    ["5e-1", 0],
    ["1E-2", 0],
    ["1,000", 1000],
    ["1,,2", 12],
    ["5,", 5],
    ["1,.5", 2],
    ["5,e2", 500],
    [",5", :invalid],
    ["1.5,3", :invalid],
    ["$5", 5],
    ["5$", 5],
    ["$-5", -5],
    ["-$ 5", -5],
    ["- 5", :invalid],
    ["$ 5", 5],
    ["5 -", -5],
    ["5-", -5],
    ["(5)", -5],
    ["($5)", -5],
    ["(5 )", -5],
    ["( 5 )", :invalid],
    ["(+5)", :invalid],
    ["(5)-", :invalid],
    ["$$5", :invalid],
    ["--5", :invalid],
    ["+-5", :invalid],
    ["1e", :invalid],
    ["1e2.5", :invalid],
    ["&H2", 2],
    ["&h1F", 31],
    ["&O17", 15],
    ["&o8", :invalid],
    ["&H0x1F", 31],
    ["&H+1F", 31],
    [" &H2", 2],
    ["&H2 ", :invalid],
    ["&H", :invalid],
    ["&H ", :invalid],
    ["&B1", :invalid],
    ["&H-1", "String cannot contain a minus sign if the base is not 10."],
    ["&H7FFFFFFF", 2147483647],
    ["&HFFFFFFFF", :overflow],
    ["&HFFFFFFFFFFFFFFFF", -1],
    ["&H8000000000000000", :overflow],
    ["&H10000000000000000", "Value was either too large or too small for a UInt64."],
    ["&H10000000000000000z", "Value was either too large or too small for a UInt64."],
    ["&O0x1", :invalid],
    ["0x2", :invalid],
    ["1_0", :invalid],
    ["abc", :invalid],
    ["", :invalid],
    [" ", :invalid],
    ["Infinity", :invalid],
    ["infinity", :invalid],
    ["NaN", :overflow],
    ["-nan", :overflow],
    ["2147483647", 2147483647],
    ["2147483648", :overflow],
    ["2147483647.5", :overflow],
    ["2147483646.5", 2147483646],
    ["-2147483648.5", -2147483648],
    ["-2147483649", :overflow],
    ["00000000000000000000000000000000002147483647", 2147483647],
    ["1e400", :overflow],
    ["1e-400", 0],
    ["abcdefghijklmnopqrstuvwxyz0123456789XYZ", :invalid],
    [" #{ideographic}&H2", 2],          # U+3000 is skipped before &H ...
    ["#{ideographic}5", :invalid],      # ... but is not number white space
    [infinity, :overflow],
    ["-#{infinity}", :overflow],
    ["#{ideographic}#{infinity} ", :overflow], # the symbol fallback uses String.Trim()
    # Number.TryStringToNumber accepts a run of trailing NULs after the WHOLE
    # number grammar (trailing white, sign, ')' and '$' included: Number.TrailingZeros);
    # anything after the first NUL that is not a NUL, a leading NUL, a NUL inside the
    # parentheses, and the &H/&O and NaN/infinity paths still fail (genieoracle tointmsg).
    ["5\0", 5],
    ["5\0\0", 5],
    ["5 \0", 5],
    [" 5 \0\0", 5],
    ["(5)\0", -5],
    ["5-\0", -5],
    ["-5\0", -5],
    ["5$\0", 5],
    ["2.5\0", 2],
    ["5.\0", 5],
    ["1e3\0", 1000],
    ["1,000\0", 1000],
    ["99999999999\0", :overflow],
    ["5\0 ", :invalid],
    ["5\0\t", :invalid],
    ["5\0x", :invalid],
    ["5\0\0" + "5", :invalid],
    ["\05", :invalid],
    ["(5\0)", :invalid],
    ["5e\0", :invalid],
    ["\0", :invalid],
    [" \0", :invalid],
    ["$\0", :invalid],
    ["&H1F\0", :invalid],
    ["&HFF \0", :invalid],
    ["nan\0", :invalid],
    ["#{infinity}\0", :invalid]
  ].freeze

  it 'maps nil (a missing SortedList key) to 0, like ToInteger(Nothing)' do
    expect(described_class.to_integer(nil)).to eq(0)
  end

  rows.each do |input, expected|
    it "converts #{input.inspect} like the .NET runtime (#{expected.inspect})" do
      case expected
      when Integer then expect(described_class.to_integer(input)).to eq(expected)
      when :invalid then expect { described_class.to_integer(input) }.to raise_error(Lich::Genie::Error, invalid.call(input))
      when :overflow then expect { described_class.to_integer(input) }.to raise_error(Lich::Genie::Error, overflow)
      else expect { described_class.to_integer(input) }.to raise_error(Lich::Genie::Error, expected)
      end
    end
  end

  it 'quotes only the first 32 characters in the InvalidCast message (Strings.Left)' do
    expect { described_class.to_integer('abcdefghijklmnopqrstuvwxyz0123456789XYZ') }
      .to raise_error(Lich::Genie::Error, "Conversion from string \"abcdefghijklmnopqrstuvwxyz012345\" to type 'Integer' is not valid.")
  end

  it 'never lets Ruby warn on an out-of-range exponent (1e999999999 overflows, 1e-999999999 is 0)' do
    expect { described_class.to_integer('1e999999999') }.to raise_error(Lich::Genie::Error, overflow)
    expect(described_class.to_integer('1e-999999999')).to eq(0)
    expect(described_class.to_integer("0.#{'0' * 400}1e399")).to eq(0)
  end
  # MathEval's VB calls (MathEval.cs:146-147, 217, 231, 331, 748-749 R). Values are
  # genieoracle `math` answers (IsNumeric then ToDouble, or the descent).
  describe '.numeric? / .to_double (Information.IsNumeric, Conversions.ToDouble)' do
    it 'accepts what double.TryParse(NumberStyles.Any, en-US) accepts, and &H/&O literals' do
      { '1,000' => 1000.0, '$5' => 5.0, '(5)' => -5.0, '5-' => -5.0, '2 +' => 2.0, ' 5 ' => 5.0,
        '&H10' => 16.0, '&O17' => 15.0, '1e400' => Float::INFINITY, '-1e400' => -Float::INFINITY,
        '1e-320' => 1.0e-320, '0.1' => 0.1 }.each do |text, value|
        expect(described_class.numeric?(text)).to be(true), text
        expect(described_class.to_double(text)).to eq(value), text
      end
      expect(described_class.to_double('NaN').nan?).to be(true)
    end

    it 'parses exactly, correctly rounded (unlike the Int32-only magnitude of to_integer)' do
      expect(described_class.to_double('9007199254740993')).to eq(9_007_199_254_740_992.0)
      expect(described_class.to_double('123456789012.5')).to eq(123_456_789_012.5)
      expect(described_class.to_double('-0')).to eq(0.0)
      expect((1.0 / described_class.to_double('-0')).negative?).to be(true)
    end

    it 'accepts trailing NULs after the whole number like to_integer (same TryStringToNumber; genieoracle math)' do
      { "5\0" => 5.0, "5 \0\0" => 5.0, "(5)\0" => -5.0, "1e400\0" => Float::INFINITY }.each do |text, value|
        expect(described_class.numeric?(text)).to be(true), text.inspect
        expect(described_class.to_double(text)).to eq(value), text.inspect
      end
      ["5\0 ", "\05", "5\0x", "nan\0", "&H1F\0"].each do |text|
        expect(described_class.numeric?(text)).to be(false), text.inspect
      end
    end

    it 'refuses the rest, a malformed &H/&O literal included' do
      ['Infinity', '', ' ', '1.2.3', '+-5', '0x1F', '&HZZ', '&Q1', 'abc', '5abc'].each do |text|
        expect(described_class.numeric?(text)).to be(false), text
      end
      expect(described_class.numeric?(nil)).to be(false)
      expect { described_class.to_double('1.2.3') }
        .to raise_error(Lich::Genie::Error, "Conversion from string \"1.2.3\" to type 'Double' is not valid.")
      expect(described_class.to_double(nil)).to eq(0.0)
    end
  end

  describe '.double_to_integer / .double_to_long (checked casts of Math.Round)' do
    it 'rounds half to even and checks the range' do
      expect(described_class.double_to_integer(2.5)).to eq(2)
      expect(described_class.double_to_integer(-3.5)).to eq(-4)
      expect(described_class.double_to_integer(2_147_483_647.4)).to eq(2_147_483_647)
      expect(described_class.double_to_long(-9_223_372_036_854_775_808.0)).to eq(-9_223_372_036_854_775_808)
      [2_147_483_647.5, Float::NAN, Float::INFINITY].each do |bad|
        expect { described_class.double_to_integer(bad) }.to raise_error(Lich::Genie::Error, overflow), bad.to_s
      end
      [9_223_372_036_854_775_807.0, Float::NAN, -Float::INFINITY].each do |bad|
        expect { described_class.double_to_long(bad) }.to raise_error(Lich::Genie::Error, overflow), bad.to_s
      end
    end
  end
end
