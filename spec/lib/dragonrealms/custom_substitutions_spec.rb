# frozen_string_literal: true

require_relative '../../spec_helper'

require File.join(LIB_DIR, 'dragonrealms', 'custom_substitutions.rb')

# Exercises the shared merge/validate/report/memoize unit that lets players
# extend Lich's built-in substitution lists from their own settings. Focuses on
# the adversarial cases: malformed entries, wrong container types, invalid and
# runaway regexes, and memoization/reset boundaries.
RSpec.describe Lich::DragonRealms::CustomSubstitutions do
  before(:each) do
    described_class.reset!
    Lich::Messaging.clear_messages!
  end

  # Supplies user additions the way the real get_settings would.
  def stub_settings(key, value)
    allow(described_class).to receive(:get_settings).and_return(OpenStruct.new(key => value))
  end

  def last_messages
    Lich::Messaging.messages.map { |m| m[:message] }.join("\n")
  end

  describe '.resolve merging' do
    it 'appends valid additions after the defaults' do
      stub_settings(:custom_pairs, [%w[from-user to-user]])
      merged = described_class.resolve(:custom_pairs, [%w[from-default to-default]], type: :pairs)
      expect(merged).to eq([%w[from-default to-default], %w[from-user to-user]])
    end

    it 'returns the defaults unchanged when there are no additions' do
      stub_settings(:custom_pairs, nil)
      expect(described_class.resolve(:custom_pairs, [%w[a b]], type: :pairs)).to eq([%w[a b]])
    end

    it 'returns the defaults when settings are unavailable (get_settings nil)' do
      allow(described_class).to receive(:get_settings).and_return(nil)
      expect(described_class.resolve(:custom_names, %w[goblin], type: :names)).to eq(%w[goblin])
    end

    it 'deduplicates additions against the defaults and each other' do
      stub_settings(:custom_names, %w[beta alpha beta])
      expect(described_class.resolve(:custom_names, %w[beta], type: :names)).to eq(%w[beta alpha])
    end

    it 'raises for an unsupported type' do
      expect { described_class.resolve(:custom_x, [], type: :bogus) }.to raise_error(ArgumentError, /unsupported type/)
    end
  end

  describe '.resolve memoization' do
    it 'caches the merged list until reset!' do
      stub_settings(:custom_pairs, [%w[a b]])
      first = described_class.resolve(:custom_pairs, [], type: :pairs)

      stub_settings(:custom_pairs, [%w[c d]])
      expect(described_class.resolve(:custom_pairs, [], type: :pairs)).to eq(first)

      described_class.reset!
      expect(described_class.resolve(:custom_pairs, [], type: :pairs)).to eq([%w[c d]])
    end
  end

  describe 'whole-value validation' do
    it 'ignores a non-list settings value and reports it' do
      stub_settings(:custom_pairs, 'not-a-list')
      expect(described_class.resolve(:custom_pairs, [%w[a b]], type: :pairs)).to eq([%w[a b]])
      expect(last_messages).to include('custom_pairs ignored -- expected a list, got String')
    end
  end

  describe ':pairs validation' do
    it 'skips a non-array entry with a descriptive message' do
      stub_settings(:custom_pairs, ['oops'])
      expect(described_class.resolve(:custom_pairs, [], type: :pairs)).to eq([])
      expect(last_messages).to include('custom_pairs[0] skipped -- expected a [from, to] pair, got "oops"')
    end

    it 'skips a wrong-arity entry' do
      stub_settings(:custom_pairs, [%w[only one three]])
      expect(described_class.resolve(:custom_pairs, [], type: :pairs)).to eq([])
      expect(last_messages).to include('expected a [from, to] pair')
    end

    it 'skips a pair whose members are not both strings' do
      stub_settings(:custom_pairs, [['from', 42]])
      expect(described_class.resolve(:custom_pairs, [], type: :pairs)).to eq([])
      expect(last_messages).to include("both 'from' and 'to' must be strings")
    end

    it 'skips a pair with an empty from (would match everything)' do
      stub_settings(:custom_pairs, [['', 'to']])
      expect(described_class.resolve(:custom_pairs, [], type: :pairs)).to eq([])
      expect(last_messages).to include("'from' must not be empty")
    end

    it 'skips a no-op pair where from equals to' do
      stub_settings(:custom_pairs, [%w[same same]])
      expect(described_class.resolve(:custom_pairs, [], type: :pairs)).to eq([])
      expect(last_messages).to include('would do nothing')
    end

    it 'keeps valid pairs while dropping the invalid one in the same list' do
      stub_settings(:custom_pairs, [%w[good rewrite], 'bad'])
      expect(described_class.resolve(:custom_pairs, [], type: :pairs)).to eq([%w[good rewrite]])
      expect(last_messages).to include('custom_pairs[1] skipped')
    end
  end

  describe ':names validation' do
    it 'skips a non-string name' do
      stub_settings(:custom_names, [123])
      expect(described_class.resolve(:custom_names, [], type: :names)).to eq([])
      expect(last_messages).to include('expected a non-empty string, got 123')
    end

    it 'skips an empty string name' do
      stub_settings(:custom_names, [''])
      expect(described_class.resolve(:custom_names, [], type: :names)).to eq([])
      expect(last_messages).to include('expected a non-empty string')
    end

    it 'warns about non-ASCII but still keeps the entry' do
      naive = "na" + [0xEF].pack('U') + "ve pet" # non-ASCII value, ASCII source
      stub_settings(:custom_names, [naive])
      expect(described_class.resolve(:custom_names, [], type: :names)).to eq([naive])
      expect(last_messages).to include('contains non-ASCII characters')
    end
  end

  describe ':regexes validation' do
    it 'compiles a valid regex string' do
      stub_settings(:custom_regexes, ['gilded .* hilt'])
      compiled = described_class.resolve(:custom_regexes, [], type: :regexes)
      expect(compiled.first).to be_a(Regexp)
      expect(compiled.first.source).to eq('gilded .* hilt')
    end

    it 'rejects an invalid regex and reports the compile error' do
      stub_settings(:custom_regexes, ['(unclosed'])
      expect(described_class.resolve(:custom_regexes, [], type: :regexes)).to eq([])
      expect(last_messages).to include('invalid regular expression "(unclosed"')
    end

    it 'accepts a pre-compiled Regexp and preserves its flags' do
      stub_settings(:custom_regexes, [/Encircling/i])
      compiled = described_class.resolve(:custom_regexes, [], type: :regexes)
      expect(compiled.first.source).to eq('Encircling')
      expect(compiled.first.casefold?).to be(true)
    end
  end

  describe '.apply_regexes' do
    it 'strips every matching pattern in order' do
      patterns = [/ with gems$/, /gaudy /]
      expect(described_class.apply_regexes('a gaudy scroll with gems', patterns)).to eq('a scroll')
    end

    # Ruby 3.2+ memoizes match state, defeating classic catastrophic-backtracking
    # patterns, so we simulate the timeout to test the guard logic itself: that a
    # Regexp::TimeoutError is caught, the text is left intact, and it is reported
    # only once per pattern.
    it 'skips a pattern that times out and reports it once, leaving text intact' do
      pattern = /(a+)+$/
      text = +'aaaa' # mutable so the sub stub can define a singleton method
      allow(text).to receive(:sub).with(pattern, '').and_raise(Regexp::TimeoutError)

      expect(described_class.apply_regexes(text, [pattern])).to eq('aaaa')
      expect(last_messages).to include('took too long')

      Lich::Messaging.clear_messages!
      described_class.apply_regexes(text, [pattern])
      expect(last_messages).not_to include('took too long') # deduplicated by source
    end
  end
end
