# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

RSpec.describe Lich::Genie::MathEval do
  def evl(expr)
    described_class.evaluate(expr)
  end

  describe '.evaluate' do
    # A script thread's stack (Lich runs each script on its own Thread) overflows on deep
    # nesting; SystemStackError is no StandardError, so it once escaped to Lich's wrapper.
    it 'raises Invalid expression, not SystemStackError, for nesting deeper than the stack' do
      deep = "#{'(' * 20_000}1#{')' * 20_000}"
      outcome = Thread.new do
        evl(deep)
      rescue Exception => e # rubocop:disable Lint/RescueException -- the escape under test
        e
      end.value
      expect(outcome).to be_a(Lich::Genie::Error)
      expect(outcome.message).to start_with('Invalid expression: ((((')
    end

    it 'handles the numeric fast path' do
      expect(evl('42')).to eq(42.0)
      expect(evl(' 3.5 ')).to eq(3.5)
    end

    it 'applies standard precedence' do
      expect(evl('2 + 3 * 4')).to eq(14.0)
      expect(evl('(2 + 3) * 4')).to eq(20.0)
      expect(evl('10 - 2 - 3')).to eq(5.0) # left associative
    end

    it 'treats ^ as LEFT-associative (Genie quirk)' do
      expect(evl('2 ^ 3 ^ 2')).to eq(64.0) # (2^3)^2, not 2^(3^2)=512
      expect(evl('2 ^ 10')).to eq(1024.0)
    end

    it 'supports unary minus' do
      expect(evl('-5 + 3')).to eq(-2.0)
      expect(evl('3 * -2')).to eq(-6.0)
    end

    it 'does integer division truncating toward zero' do
      expect(evl('7 \\ 2')).to eq(3.0)
      expect(evl('-7 \\ 2')).to eq(-3.0) # trunc toward zero, not floor (-4)
    end

    it 'takes modulo with the sign of the dividend' do
      expect(evl('-5 % 3')).to eq(-2.0)
      expect(evl('5 % 3')).to eq(2.0)
    end

    # Genie4 differential-fuzzer regressions: C# double `%` stays exact when the operands
    # differ wildly in magnitude, where Ruby's Float#remainder / a subtract-formula don't.
    it 'matches Genie4 modulo for extreme operand magnitudes' do
      expect(evl('-95 % (4! ^ 21.0)')).to eq(-95.0) # |divisor| >> |dividend| -> dividend
      expect(evl('(77 ^ 12.0) % 83')).to eq(80.0)   # |dividend| huge -> still precise
      expect(evl('5 % 0').nan?).to be(true) # C# double x % 0 -> NaN
    end

    # Genie4 uses C# System.Math, which returns NaN/Infinity for domain errors rather
    # than raising (verified via the differential oracle/fuzzer).
    it 'returns NaN/Infinity for domain errors like C# Math (not raising)' do
      expect(evl('sqrt(-1)').nan?).to be(true)
      expect(evl('log(-1)').nan?).to be(true)
      expect(evl('ln(-1)').nan?).to be(true)
      expect(evl('log(0)')).to eq(-Float::INFINITY)
      expect(evl('(-4 ^ 0.5)').nan?).to be(true) # negative base, non-integer exponent
      expect(evl('1 ^ (0 / 0)')).to eq(1.0)      # C# Pow(1, NaN) == 1
      expect(evl('floor(sqrt(-9))').nan?).to be(true) # NaN passes through floor
    end

    # Math.Pow(-Infinity, y) for a non-integer y is +Infinity (y > 0) or +0
    # (y < 0), never NaN; odd integer exponents keep the sign (genieoracle `math`).
    it 'raises -Infinity to a fractional power like C# Math.Pow' do
      expect([evl('neg(1 / 0) ^ 0.5'), evl('neg(1 / 0) ^ 1.5')]).to eq([Float::INFINITY, Float::INFINITY])
      expect([evl('neg(1 / 0) ^ -0.5'), 1.0 / evl('neg(1 / 0) ^ -0.5')]).to eq([0.0, Float::INFINITY]) # +0
      expect([evl('neg(1 / 0) ^ 3'), 1.0 / evl('neg(1 / 0) ^ -3')]).to eq([-Float::INFINITY, -Float::INFINITY]) # -0
      expect(evl('-8 ^ 0.5').nan?).to be(true) # a finite negative base stays NaN
    end

    # .NET decoded the text, each invalid UTF-8 sequence becoming U+FFFD
    # (genieoracle: "5<FF>" = 5, "<FF>5" throws) -- like Eval.
    it 'reads invalid UTF-8 as U+FFFD, like the .NET string it was' do
      broken = ->(bytes) { bytes.pack('C*').force_encoding(Encoding::UTF_8) }
      expect(evl(broken.call([0x35, 0xFF]))).to eq(5)
      expect(evl(broken.call([0x35, 0xFF, 0x20, 0x2B, 0x20, 0x31]))).to eq(5)
      expect { evl(broken.call([0xFF, 0x35])) }
        .to raise_error(Lich::Genie::Error, "Invalid expression: #{[0xFFFD].pack('U')}5")
    end

    it 'computes factorial (postfix !)' do
      expect(evl('5 !')).to eq(120.0)
      expect(evl('0 !')).to eq(1.0)
      expect(evl('1 !')).to eq(1.0)
    end

    it 'exposes constants' do
      expect(evl('pi')).to be_within(1e-12).of(Math::PI)
      expect(evl('e')).to be_within(1e-12).of(Math::E)
    end

    it 'treats log as base-10 and ln as natural (Genie quirk)' do
      expect(evl('log(1000)')).to be_within(1e-9).of(3.0)
      expect(evl('ln(e)')).to be_within(1e-9).of(1.0)
    end

    it 'supports the function library' do
      expect(evl('sqrt(16)')).to eq(4.0)
      expect(evl('abs(-7)')).to eq(7.0)
      expect(evl('floor(3.9)')).to eq(3.0)
      expect(evl('ceiling(3.1)')).to eq(4.0)
      expect(evl('max(3, 7, 5)')).to eq(7.0)
      expect(evl('min(3, 7, 5)')).to eq(3.0)
      expect(evl('neg(4)')).to eq(-4.0)
    end

    it 'rounds using banker\'s rounding' do
      expect(evl('round(2.5)')).to eq(2.0)
      expect(evl('round(3.5)')).to eq(4.0)
      expect(evl('round(3.14159, 2)')).to eq(3.14)
    end

    # --- Literal MathEval.cs port; every value below is a genieoracle (Remix) answer ---

    # Evaluate (MathEval.cs:146-147 R): Information.IsNumeric, then Conversions.ToDouble.
    it 'converts a VB-numeric expression directly (IsNumeric fast path)' do
      expect(evl('1,000')).to eq(1000)
      expect(evl('$5')).to eq(5)
      expect(evl('(5)')).to eq(-5)
      expect(evl('5-')).to eq(-5)
      expect(evl('2 +')).to eq(2) # trailing white then a trailing sign: still a number
      expect(evl('&H10')).to eq(16)
      expect(evl('&O17')).to eq(15)
      expect(evl('1e400')).to eq(Float::INFINITY)
      expect(evl('NaN').nan?).to be(true)
      expect(evl('Infinity')).to eq(0) # not VB-numeric: the identifier "Infinity" is 0
    end

    # level0 returns once its expression ends (MathEval.cs:141-155 R): the rest is ignored.
    it 'evaluates the first expression and ignores the tokens left over' do
      expect(evl('1+1 = 2')).to eq(2)
      expect(evl('3!!')).to eq(6)
      expect(evl('1 2')).to eq(1)
      expect(evl('5abc')).to eq(0) # number state + a letter -> one identifier (state table)
      expect(evl('1e10!')).to eq(0) # the identifier "1e", then 10 and ! are ignored
      expect(evl('pi2')).to eq(Math::PI) # a digit ends an identifier
    end

    # init_operators registers `&` and `(` at LEVEL5 (MathEval.cs:113-117, 128-132 R); calc_op
    # has no case for them (MathEval.cs:157-240 R), so after an operand they yield 0.
    it 'turns a postfix & or ( into 0' do
      expect(evl('2 & 3')).to eq(0)
      expect(evl('1 + 2 & 3')).to eq(1)
      expect(evl('2(3)')).to eq(0)
    end

    # calc_scan's tables (MathEval.cs:61-62, 435-465 R): ALPHA/DIGITS are searched with
    # IndexOf(..) > 0, so `_` and `#` are punctuation; char.ToUpper makes the dotless i a letter.
    it 'lexes with calc_scan: _ and # are punctuation, a function name cannot hold a digit' do
      expect { evl('log10(1000)') }.to raise_error(Lich::Genie::Error, 'Invalid expression: log10(1000)')
      expect { evl('_x') }.to raise_error(Lich::Genie::Error, 'Invalid expression: _x')
      expect { evl('#5') }.to raise_error(Lich::Genie::Error, 'Invalid expression: #5')
      expect(evl([0x131].pack('U'))).to eq(0)
      expect(evl('SQRT(16)')).to eq(4) # function names and constants ignore case
      expect(evl('PI')).to eq(Math::PI)
    end

    it 'raises "Invalid expression: <expr>" wherever MathEval throws' do
      ['', '(2 + 3', '--5', '+-5', '1.2.3', 'sin 1', 'max(1,)', '5 \\ 0', '9223372036854775807 \\ 1',
       '-9223372036854775807 \\ -1', 'round(1, 16)', 'round(1, -1)', '(10^10)!'].each do |bad|
        expect { evl(bad) }.to raise_error(Lich::Genie::Error, "Invalid expression: #{bad}"), bad
      end
    end

    # .NET Core Math.Max/Min (IEEE 754:2019) and Math.Round(x, digits) (scale, round, unscale).
    it 'follows .NET Math.Max/Min/Round' do
      expect(evl('max(1, 0/0)').nan?).to be(true)
      expect(evl('min(0/0, 1)').nan?).to be(true)
      expect(Lich::Genie::Numeric.format_double(evl('min(0, -0)'))).to eq('-0')
      expect(Lich::Genie::Numeric.format_double(evl('max(0, -0)'))).to eq('0')
      expect(Lich::Genie::Numeric.format_double(evl('round(-0.4)'))).to eq('-0')
      expect(evl('round(2.675, 2)')).to eq(2.68)
      expect(evl('round(1.005, 2)')).to eq(1)
      expect(evl('round(2.5, 0, 1)')).to eq(2) # a third argument drops back to Round(x)
    end

    # The `!` case loops from ToInteger(x) down to 1 (MathEval.cs:225-236 R): banker's
    # rounding first, and a product that went infinite stays so (no 2^31 iterations here).
    it 'computes factorials like the C# loop' do
      expect(evl('2.5!')).to eq(2)
      expect(evl('3.5!')).to eq(24)
      expect(evl('-(5)!')).to eq(-120)
      expect(evl('171!')).to eq(Float::INFINITY)
      expect(evl('(2^31 - 1)!')).to eq(Float::INFINITY)
    end
  end
end
