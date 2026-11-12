# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

RSpec.describe Lich::Genie::Numeric do
  describe '.string_to_double' do
    it 'parses valid numbers' do
      expect(described_class.string_to_double('5')).to eq(5.0)
      expect(described_class.string_to_double(' 5.5 ')).to eq(5.5)
      expect(described_class.string_to_double('-3')).to eq(-3.0)
      expect(described_class.string_to_double('1e3')).to eq(1000.0)
    end

    it 'tolerates thousands separators leniently in the integer part (like .NET)' do
      expect(described_class.string_to_double('1,000')).to eq(1000.0)
      expect(described_class.string_to_double('1,23')).to eq(123.0)     # grouping not validated
      expect(described_class.string_to_double('1,2,3.5')).to eq(123.5)
      expect(described_class.string_to_double('1,,2')).to eq(12.0)      # doubled comma ok
      expect(described_class.string_to_double('5,')).to eq(5.0)         # trailing ok
    end

    it 'returns -1.0 (not 0) on empty/nil/parse failure' do
      expect(described_class.string_to_double(nil)).to eq(-1.0)
      expect(described_class.string_to_double('')).to eq(-1.0)
      expect(described_class.string_to_double('   ')).to eq(-1.0)
      expect(described_class.string_to_double('abc')).to eq(-1.0)
      expect(described_class.string_to_double('5px')).to eq(-1.0)
    end

    # These are the divergences the old Float()-based parse got wrong: Ruby's Float()
    # accepts hex/underscores/"Infinity" and misparses a comma after the decimal, none
    # of which .NET's double.Parse(en-US) does. All confirmed against the s2d oracle.
    it 'rejects forms .NET does not accept (were wrongly parsed before)' do
      expect(described_class.string_to_double('0x1F')).to eq(-1.0)  # Ruby Float would give 31.0
      expect(described_class.string_to_double('1_000')).to eq(-1.0) # Ruby Float would give 1000.0
      expect(described_class.string_to_double('Infinity')).to eq(-1.0)
      expect(described_class.string_to_double('1.5,3')).to eq(-1.0) # comma after decimal
      expect(described_class.string_to_double(',5')).to eq(-1.0)    # leading comma
      expect(described_class.string_to_double('+-5')).to eq(-1.0)
      expect(described_class.string_to_double('1.2.3')).to eq(-1.0)
    end

    it 'parses "NaN" case-insensitively (with optional sign), like .NET' do
      expect(described_class.string_to_double('NaN').nan?).to be(true)
      expect(described_class.string_to_double('nan').nan?).to be(true)
      expect(described_class.string_to_double('-nan').nan?).to be(true)
    end

    it 'parses leading-dot / trailing-dot / signed fractions and exponents' do
      expect(described_class.string_to_double('.5')).to eq(0.5)
      expect(described_class.string_to_double('5.')).to eq(5.0)
      expect(described_class.string_to_double('+.5')).to eq(0.5)
      expect(described_class.string_to_double('1E+5')).to eq(100_000.0)
      expect(described_class.string_to_double('1e999')).to eq(Float::INFINITY)
      expect(described_class.string_to_double('.')).to eq(-1.0)
    end

    # en-US's PositiveInfinitySymbol is U+221E, which double.Parse accepts
    # alone, signed and white-space trimmed (genieoracle s2d, Remix: Utility.cs:664-679 R).
    it 'parses the infinity sign, signed and trimmed, to an infinity; anything around it is -1' do
      inf = [0x221E].pack('U')
      expect(["#{inf}", "+#{inf}", " #{inf} ", "\t#{inf}", "#{inf}\t"].map { |s| described_class.string_to_double(s) })
        .to all(eq(Float::INFINITY))
      expect(["-#{inf}", "-#{inf} "].map { |s| described_class.string_to_double(s) }).to all(eq(-Float::INFINITY))
      expect(["--#{inf}", "1#{inf}", "#{inf}-", ".#{inf}", "#{inf}#{inf}", "#{inf}e5", "- #{inf}", "(#{inf})", 'Infinity',
              '-Infinity'].map { |s| described_class.string_to_double(s) }).to all(eq(-1.0))
    end
  end

  # Utility.StringToInteger (Utility.cs:682-704 R): int.Parse(en-US); <= 0 or a failure is -1.
  # Rows checked with .NET 8's int.Parse (2026-10-20).
  # .NET's number grammar skips only Number.IsWhite (TAB..CR, space) around a number
  # and allows trailing NULs; the NaN / U+221E fallback trims char.IsWhiteSpace. Every value
  # below is genieoracle s2d (remix).
  describe '.string_to_double around a number (Number.IsWhite, TrailingZeros)' do
    nul = "\0"
    nbsp = [0xA0].pack('U')
    ideo = [0x3000].pack('U')
    inf = [0x221E].pack('U')

    it 'fails on a leading NUL but accepts trailing NULs after the number and its white' do
      expect(described_class.string_to_double("#{nul}5")).to eq(-1.0)
      expect(described_class.string_to_double("#{nul} 5")).to eq(-1.0)
      expect(described_class.string_to_double("5#{nul}")).to eq(5.0)
      expect(described_class.string_to_double("5 #{nul}#{nul}")).to eq(5.0)
      expect(described_class.string_to_double("5#{nul} ")).to eq(-1.0)
    end

    it 'skips TAB..CR and space around a number but not U+00A0 / U+3000' do
      expect(described_class.string_to_double("\t\v\f\r\n 1,000.5 \t")).to eq(1000.5)
      expect(described_class.string_to_double("#{nbsp}5")).to eq(-1.0)
      expect(described_class.string_to_double("5#{ideo}")).to eq(-1.0)
    end

    it 'trims char.IsWhiteSpace around the NaN / infinity symbols, never a NUL' do
      expect(described_class.string_to_double("#{ideo}NaN#{nbsp}")).to be_nan
      expect(described_class.string_to_double("#{nbsp}-#{inf}\t")).to eq(-Float::INFINITY)
      expect(described_class.string_to_double("NaN#{nul}")).to eq(-1.0)
      expect(described_class.string_to_double("#{nul}#{inf}")).to eq(-1.0)
    end

    it 'is TryParse via .net_double: nil on a failure, the value otherwise' do
      expect(described_class.net_double('-1')).to eq(-1.0)
      expect(described_class.net_double("#{nul}-1")).to be_nil
      expect(described_class.net_double('')).to be_nil
      expect(described_class.net_double(nil)).to be_nil
    end
  end

  describe '.string_to_integer' do
    it 'parses a positive Int32 like int.Parse (sign, white space, trailing NULs)' do
      expect(%W[5 +5 \s5\s 5\0 05 2147483647].map { |s| described_class.string_to_integer(s) })
        .to eq([5, 5, 5, 5, 5, 2_147_483_647])
    end

    it 'is -1 for zero, a negative, a failure or nil' do
      expect(['0', '-0', '-3', '1,000', '2147483648', '2.0', '0x5', '', ' ', 'r', nil].map { |s| described_class.string_to_integer(s) })
        .to all(eq(-1))
    end
  end

  describe '.format_double' do
    it 'prints integers without a decimal point' do
      expect(described_class.format_double(5.0)).to eq('5')
      expect(described_class.format_double(-12.0)).to eq('-12')
      expect(described_class.format_double(0.0)).to eq('0')
    end

    it 'prints non-integers in shortest form' do
      expect(described_class.format_double(0.5)).to eq('0.5')
      expect(described_class.format_double(3.14)).to eq('3.14')
    end

    it 'handles special values .NET-style (Unicode infinity, signed zero)' do
      infinity = [0x221E].pack('U') # U+221E, kept out of source per AsciiOnlySource cop
      expect(described_class.format_double(Float::NAN)).to eq('NaN')
      expect(described_class.format_double(Float::INFINITY)).to eq(infinity)
      expect(described_class.format_double(-Float::INFINITY)).to eq("-#{infinity}")
      expect(described_class.format_double(-0.0)).to eq('-0')
    end

    # Byte-exact with .NET double.ToString(), verified via the Genie4 differential fuzzer
    # (genie-port-lab/reference/fuzz_format.rb): fixed-point for exponent in [-4, 16],
    # scientific otherwise, shortest round-trip digits throughout.
    it 'matches .NET formatting at magnitude boundaries' do
      expect(described_class.format_double(1e16)).to eq('10000000000000000')  # fixed
      expect(described_class.format_double(1e17)).to eq('1E+17')              # -> scientific
      expect(described_class.format_double(1e-4)).to eq('0.0001')            # fixed
      expect(described_class.format_double(1e-5)).to eq('1E-05')             # -> scientific
      expect(described_class.format_double(8.7**18)).to eq('81535464022366910') # shortest, not exact-int
      expect(described_class.format_double(22.0 / 7)).to eq('3.142857142857143')
    end
  end

  # C# double `%` (fmod). Expected values are Remix genieoracle `math` answers
  # (`7 % 0`, `-95 % 24^21`, `(1/0) % 3`, `7 % (1/0)`, `0 % 0`, ...).
  describe '.double_remainder' do
    it 'keeps the dividend sign, not the divisor sign' do
      expect(described_class.double_remainder(-7.0, 3.0)).to eq(-1.0)
      expect(described_class.double_remainder(7.0, -3.0)).to eq(1.0)
      expect(described_class.double_remainder(-7.5, 2.0)).to eq(-1.5)
    end

    it 'returns NaN for a zero divisor instead of raising (0 % 0 included)' do
      expect(described_class.double_remainder(7.0, 0.0)).to be_nan
      expect(described_class.double_remainder(7.0, -0.0)).to be_nan
      expect(described_class.double_remainder(0.0, 0.0)).to be_nan
    end

    it 'returns the dividend when the divisor dwarfs it' do
      expect(described_class.double_remainder(-95.0, 24.0**21)).to eq(-95.0)
      expect(described_class.double_remainder(7.0, Float::INFINITY)).to eq(7.0)
      expect(described_class.double_remainder(-7.0, -Float::INFINITY)).to eq(-7.0)
    end

    it 'returns NaN for an infinite dividend or a NaN operand' do
      expect(described_class.double_remainder(Float::INFINITY, 3.0)).to be_nan
      # An infinite divisor does not rescue an infinite dividend (fmod; genieoracle
      # `(1 / 0) % neg(1 / 0)` = NaN)
      expect(described_class.double_remainder(Float::INFINITY, -Float::INFINITY)).to be_nan
      expect(described_class.double_remainder(-Float::INFINITY, Float::INFINITY)).to be_nan
      expect(described_class.double_remainder(Float::NAN, 3.0)).to be_nan
      expect(described_class.double_remainder(7.0, Float::NAN)).to be_nan
    end
  end

  # int.TryParse(s) (NumberStyles.Integer): array indices and Game.cs int.Parse.
  describe '.net_int32' do
    it 'accepts a sign, surrounding ASCII white space and trailing NULs' do
      expect(%W[1 +1 -0 01 \t7\s -2147483648 2147483647 5\0\0 6\s\0].map { |s| described_class.net_int32(s) })
        .to eq([1, 1, 0, 1, 7, -2_147_483_648, 2_147_483_647, 5, 6])
    end

    it 'rejects what TryParse rejects: overflow, two signs, inner space, NUL then space, decimals, empty, nil' do
      ['2147483648', '-2147483649', '+-1', '1 2', "5\0 ", '1.0', '1e3', '', ' ', nil, '0x1F', [0x0661].pack('U')].each do |s|
        expect(described_class.net_int32(s)).to be_nil, s.inspect
      end
    end
  end
end
