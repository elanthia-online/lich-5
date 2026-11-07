# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

RSpec.describe Lich::Genie::MathCalc do
  describe '.calc' do
    it 'handles the basic operations and their symbol aliases' do
      expect(described_class.calc(10, 'add 5')).to eq(15.0)
      expect(described_class.calc(10, '+ 5')).to eq(15.0)
      expect(described_class.calc(10, 'subtract 4')).to eq(6.0)
      expect(described_class.calc(10, 'sub 4')).to eq(6.0)
      expect(described_class.calc(10, 'substract 4')).to eq(6.0) # Genie's misspelling
      expect(described_class.calc(10, 'set 3')).to eq(3.0)
      expect(described_class.calc(10, '= 3')).to eq(3.0)
      expect(described_class.calc(10, 'multiply 3')).to eq(30.0)
      expect(described_class.calc(10, 'divide 4')).to eq(2.5)
    end

    it 'clamps negative arguments to 0 (Genie quirk)' do
      expect(described_class.calc(10, 'subtract -5')).to eq(10.0)
      expect(described_class.calc(10, 'set -5')).to eq(0.0)
      expect(described_class.calc(10, 'add -5')).to eq(10.0)
    end

    it 'takes remainder with the sign of the dividend' do
      expect(described_class.calc(-5, 'mod 3')).to eq(-2.0)
      expect(described_class.calc(5, 'modulus 3')).to eq(2.0)
      expect(described_class.calc(5, '% 3')).to eq(2.0)
    end

    it 'returns 0 for mod when the current value is 0' do
      expect(described_class.calc(0, 'mod 3')).to eq(0.0)
    end

    # Remix Utility.MathCalc guards the divisor: `if (dNumber != 0) dValue = dValue / dNumber;`
    # (Utility.cs:928 R; upstream 4.5.0.3 divides and yields Infinity). Because the arg is clamped
    # to >= 0 first (Utility.cs:887-890 R) and an unparseable arg is StringToDouble -1, a negative
    # or non-numeric divisor is a zero divisor too. Flow oracle: t42, t56 (D1/D2/C2/G2).
    describe 'divide by a zero divisor (Remix: value unchanged)' do
      it 'leaves the value unchanged for divide 0 and / 0' do
        expect(described_class.calc(10, 'divide 0')).to eq(10.0)
        expect(described_class.calc(10, '/ 0')).to eq(10.0)
        expect(described_class.calc(-3.5, 'divide 0.0')).to eq(-3.5)
      end

      it 'leaves the value unchanged for a negative divisor (clamped to 0)' do
        expect(described_class.calc(10, 'divide -5')).to eq(10.0)
      end

      it 'leaves the value unchanged for a non-numeric or missing divisor' do
        expect(described_class.calc(10, 'divide abc')).to eq(10.0)
        expect(described_class.calc(10, 'divide')).to eq(10.0)
      end

      it 'still divides by a tiny positive divisor (only exactly 0 is skipped)' do
        expect(described_class.calc(1, 'divide 0.5')).to eq(2.0)
        expect(described_class.calc(3, 'divide 1e-300')).to eq(3.0 / 1e-300)
      end

      it 'divides by a NaN divisor (NaN != 0 in C#) and yields NaN' do
        expect(described_class.calc(10, 'divide NaN')).to be_nan
      end

      it 'keeps a NaN value NaN' do
        expect(described_class.calc(Float::NAN, 'divide 0')).to be_nan
      end
    end

    # C# double `%` (Utility.cs:932-946 R, same in upstream): x % 0 is NaN, never an exception.
    # Ruby's Float#remainder(0.0) raises ZeroDivisionError, which killed the script. Flow oracle t56.
    describe 'mod by a zero divisor (both Genie trees: NaN)' do
      it 'yields NaN for mod 0 / modulus 0 / % 0 on a non-zero value' do
        expect(described_class.calc(7, 'mod 0')).to be_nan
        expect(described_class.calc(-7, 'modulus 0')).to be_nan
        expect(described_class.calc(7.5, '% 0')).to be_nan
      end

      it 'yields NaN for a negative or non-numeric divisor (clamped to 0)' do
        expect(described_class.calc(7, 'mod -5')).to be_nan
        expect(described_class.calc(7, 'mod abc')).to be_nan
        expect(described_class.calc(7, 'mod')).to be_nan
      end

      it 'still returns 0 when the value is 0 (the dValue != 0 guard wins)' do
        expect(described_class.calc(0, 'mod 0')).to eq(0.0)
        expect(described_class.calc(-0.0, 'mod 0')).to eq(0.0)
      end

      it 'yields NaN for a NaN divisor or a NaN value' do
        expect(described_class.calc(7, 'mod NaN')).to be_nan
        expect(described_class.calc(Float::NAN, 'mod 3')).to be_nan
      end

      it 'returns the dividend when the divisor dwarfs it (C# fmod; Float#remainder gives 0.0)' do
        # t56 M8: Remix `math k mod 96479729228174488169059713024` on -95 echoes -95.
        expect(described_class.calc(-95, 'mod 96479729228174488169059713024')).to eq(-95.0)
        expect(described_class.calc(7, 'mod 100000000000')).to eq(7.0)
      end

      it 'keeps a fractional remainder with the dividend sign' do
        expect(described_class.calc(-7.5, 'mod 2')).to eq(-1.5)
      end
    end

    it 'raises on an unknown operation' do
      expect { described_class.calc(10, 'frobnicate 5') }.to raise_error(Lich::Genie::Error)
    end
  end
end
