# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# Property / invariant specs: each checks a structural property over MANY random
# inputs (not hand-picked examples), catching bugs the example specs miss.
# Seeded for determinism. Exhaustive exploration lives in
# genie-port-lab/reference/property_invariants.rb; this is the CI regression subset.
RSpec.describe 'Genie pure-helper invariants' do
  # Per-example iteration count (a method, not a constant, to stay out of
  # Lint/ConstantDefinitionInBlock). ~0.2s total; the exhaustive runner is separate.
  def iter = 3000

  # One seeded generator per example (never Kernel#srand: reseeding the process-global PRNG here
  # made every later spec's rand/sample deterministic for the rest of the run).
  def rng = (@rng ||= Random.new(20_260_824))

  # A random FINITE double: half from raw 64-bit patterns (subnormals + huge),
  # half from structured magnitudes; non-finite values are retried out (the
  # numeric invariants are over finite doubles only).
  def rand_finite_double
    f =
      if rng.rand(2).zero?
        [rng.rand(2**64)].pack('Q').unpack1('D')
      else
        sign = rng.rand(2).zero? ? 1 : -1
        case rng.rand(5)
        when 0 then sign * rng.rand * 10.0**rng.rand(-30..30)
        when 1 then (sign * rng.rand(0..2_000_000_000)).to_f
        when 2 then sign * rng.rand(0..999_999) / 10.0**rng.rand(0..6)
        when 3 then sign * 1.0 * 10.0**rng.rand(-6..17)
        else sign * 10.0**rng.rand(-300..300) * (1 + rng.rand)
        end
      end
    f.nan? || f.infinite? ? rand_finite_double : f
  end

  def bits(f) = [f].pack('D')

  describe Lich::Genie::Numeric do
    it 'round-trips format_double -> string_to_double bit-exactly for finite doubles' do
      iter.times do
        d = rand_finite_double
        back = described_class.string_to_double(described_class.format_double(d))
        expect(bits(back)).to eq(bits(d)), "d=#{d.inspect} formatted=#{described_class.format_double(d).inspect}"
      end
    end

    it 'emits a well-formed .NET fixed/scientific layout for finite doubles' do
      fixed = /\A-?(?:\d+|\d+\.\d+)\z/
      sci   = /\A-?\d(?:\.\d+)?E[+-]\d{2,}\z/
      leadzero = /\A-?0\d/
      iter.times do
        d = rand_finite_double
        s = described_class.format_double(d)
        expect(s).to match(Regexp.union(fixed, sci)), "d=#{d.inspect} -> #{s.inspect}"
        expect(s).not_to match(leadzero), "d=#{d.inspect} -> #{s.inspect}"
      end
    end

    it 'is a canonical form: format_double is stable across a parse for finite doubles' do
      iter.times do
        s1 = described_class.format_double(rand_finite_double)
        s2 = described_class.format_double(described_class.string_to_double(s1))
        expect(s2).to eq(s1)
      end
    end
  end

  describe Lich::Genie::Text do
    split_alpha = ['a', 'b', 'c', '1', ' ', '  ', '{', '}', '"', '\\', ';', ',', '|', 'x', '_']
    seps = [';', ',', '|', '/', ':', '#', '{', '"', '\\', 'z']
    safe_tok = ('a'..'z').to_a + ('0'..'9').to_a

    # Utility.SafeSplit (Utility.cs:782-844 R) cuts only at a separator past the piece start
    # and drops nothing else, so the pieces re-joined give the input back except a final
    # separator that ended the last piece; and no piece is ever empty.
    it 'remix_safe_split(s, sep) never yields an empty piece and re-joins to s (minus a final cut separator)' do
      iter.times do
        s = Array.new(rng.rand(0..14)) { split_alpha.sample(random: rng) }.join
        sep = seps.sample(random: rng)
        pieces = described_class.remix_safe_split(s, sep)
        joined = pieces.join(sep)
        expect(pieces).to all(satisfy { |piece| !piece.empty? }), "s=#{s.inspect} sep=#{sep.inspect}"
        expect([joined, joined + sep]).to include(s), "s=#{s.inspect} sep=#{sep.inspect}"
      end
    end

    it 'parse_args round-trips plain space-joined safe tokens' do
      iter.times do
        toks = Array.new(rng.rand(1..6)) { Array.new(rng.rand(1..6)) { safe_tok.sample(random: rng) }.join }
        expect(described_class.parse_args(toks.join(' '))).to eq(toks)
      end
    end
  end

  describe Lich::Genie::Substitution do
    safe_tok = ('a'..'z').to_a + ('0'..'9').to_a
    nosigil = ('a'..'z').to_a + ('0'..'9').to_a + [' ', '(', ')', '.', '|', '_', '\\']
    # %local + @special only: NO '$' and NO backslash. expand un-escapes and the
    # $-arg pass runs first, so those two break idempotence BY DESIGN.
    sub_alpha = ['a', 'b', 'c', 'o', 'g', 'l', '1', '2', '%', '@', ' ', '(', ')', '.', '|', '_']
    clock = -> { Time.new(2026, 8, 24, 14, 5, 9) }

    it 'expand is a no-op on text containing no %, $, or @' do
      vars = Lich::Genie::Variables.new
      vars.local_set('foo', 'X')
      vars.global_set('bar', 'Y')
      sub = described_class.new(variables: vars,
                                specials: Lich::Genie::Specials.new(clock: clock, timer: -> { '42' }))
      iter.times do
        s = Array.new(rng.rand(0..16)) { nosigil.sample(random: rng) }.join
        expect(sub.expand(s, args: %w[all one two])).to eq(s)
      end
    end

    it 'expand is idempotent for %local/@special input with sigil-free values' do
      iter.times do
        vars = Lich::Genie::Variables.new
        rng.rand(0..4).times do
          name = Array.new(rng.rand(1..4)) { safe_tok.sample(random: rng) }.join
          val = Array.new(rng.rand(0..6)) { (safe_tok + ['|']).sample(random: rng) }.join
          rng.rand(2).zero? ? vars.local_set(name, val) : vars.global_set(name, val)
        end
        sub = described_class.new(variables: vars,
                                  specials: Lich::Genie::Specials.new(clock: clock, timer: -> { '7' }))
        s = Array.new(rng.rand(0..18)) { sub_alpha.sample(random: rng) }.join
        once = sub.expand(s)
        expect(sub.expand(once)).to eq(once), "s=#{s.inspect} once=#{once.inspect}"
      end
    end
  end
end
