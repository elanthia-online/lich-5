# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# Every expected order below is what the REAL Remix v4.2.4 writer produced (genieflow
# `#var save` over a --vars file / script, .NET ICU collation, 2026-10-19), except the
# lines marked "ICU root" (characters ParseArgs cannot carry in a key).
RSpec.describe Lich::Genie::Collation do
  def u(*codes) = codes.pack('U*')

  def expect_order(list)
    expect(described_class.sort(list.reverse)).to eq(list)
    expect(described_class.sort(list.rotate(list.length / 2))).to eq(list)
  end

  it 'orders ASCII punctuation and symbols as ICU root, before digits, before letters (measured)' do
    expect_order(['a b', 'a_b', 'a-b', 'a,b', 'a;b', 'a:b', 'a!b', 'a?b', 'a.b', "a'b", 'a(b', 'a)b',
                  'a[b', 'a]b', 'a@b', 'a*b', 'a/b', 'a\\b', 'a&b', 'a#b', 'a%b', 'a`b', 'a^b', 'a+b',
                  'a<b', 'a=b', 'a>b', 'a|b', 'a~b', 'a$b', 'a0b', 'a1b', 'a9b', 'aab', 'aAb', 'abb',
                  'aBb', 'azb', 'aZb'])
  end

  it 'places the double quote and braces where ICU root does (ICU root)' do
    expect_order(["a'b", 'a"b', 'a(b', 'a)b', 'a[b', 'a]b', 'a{b', 'a}b', 'a@b'])
  end

  # The shapes of a real variables.cfg head; the first and last lists measured with genieflow's
  # `#var` listing (Remix's SortedList over the same names, 2026-10-22).
  it 'reproduces the order of real variables.cfg name shapes (measured)' do
    expect_order(['.alt', '0', 'Abbey', 'acdc', 'acid'])
    expect_order(%w[ExpTracker.DisplayREXP ExpTracker.DisplaySleep ExpTracker.ReportType ExpTracker.REXP_Format
                    ExpTracker.REXP_Usable ExpTracker.ShortNames])
    expect_order(%w[tvtriggers tw(x twabc])
  end

  it 'compares case only after the whole string, lowercase first at the first difference (measured)' do
    expect_order(%w[aa Aa ab aB Ab AB abc Abc ABC])
    expect_order(%w[alpha Alpha brace])
  end

  it 'never folds case into equality (distinct SortedList keys)' do
    expect(described_class.key('Abc')).not_to eq(described_class.key('abc'))
  end

  it 'treats the hyphen as a real character, not ignorable (measured)' do
    expect_order(%w[co-op coop cop])
  end

  it 'compares digits one by one, not numerically' do
    expect_order(%w[1 10 9 a])
  end

  it 'sorts a prefix before its extensions' do
    expect_order(['ab', 'ab ', 'ab_', 'abc'])
  end

  it 'puts accents after case: e < E < e-acute < E-acute (measured)' do
    expect_order(['e', 'E', u(0xE9), u(0xC9), 'ea', 'Ea', "#{u(0xE9)}a", 'eb', "#{u(0xE9)}x", 'f'])
  end

  it 'handles the measured expansions: a-umlaut, ae ligature, sharp s, o-stroke' do
    expect_order([u(0xE4), 'aa', 'ae', u(0xE6), 'e'])
    expect_order(['ss', u(0xDF), 'st', 'z'])
    expect_order(['o', u(0xF8), 'p'])
  end

  it 'gives decomposed and precomposed accents the same key' do
    expect(described_class.key(u(0xE9))[0..2]).to eq(described_class.key("e#{u(0x301)}")[0..2])
  end

  it 'sorts other non-ASCII letters after z, by code point' do
    expect_order(['z', u(0x3B1), u(0x430), u(0x4E00)])
  end

  it 'ignores control characters at every level but still keeps the keys distinct' do
    plain = described_class.key('ab')
    with_control = described_class.key("a\u0001b".encode('UTF-8'))
    expect(with_control[0..2]).to eq(plain[0..2])
    expect(with_control).not_to eq(plain)
  end

  it 'survives a string that is not valid UTF-8' do
    expect { described_class.sort(["a#{[0xFF].pack('C')}b", 'ab']) }.not_to raise_error
  end

  it 'survives a UTF-8-tagged string with invalid bytes, sorting it as if the bad byte were U+FFFD' do
    bad = "a#{[0xFF].pack('C')}b".dup.force_encoding(Encoding::UTF_8)
    replaced = "a#{[0xFFFD].pack('U')}b"
    expect(described_class.key(bad)[0..2]).to eq(described_class.key(replaced)[0..2])
    expect(described_class.sort([bad, 'ab', 'az'])).to eq(['ab', 'az', bad])
  end
end
