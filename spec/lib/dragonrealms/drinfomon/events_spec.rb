# frozen_string_literal: true

require 'rspec'

require_relative '../../../../lib/dragonrealms/drinfomon/events'

RSpec.describe Lich::DragonRealms::Flags do
  let(:described_class) { Lich::DragonRealms::Flags }

  before(:each) do
    # Reset flags state
    described_class.class_variable_set(:@@flags, {})
    described_class.class_variable_set(:@@matchers, {})
  end

  describe '.add' do
    it 'initializes flag to false' do
      described_class.add('test_flag', 'some pattern')
      expect(described_class['test_flag']).to be false
    end

    it 'stores regexp matchers as-is' do
      pattern = /test\s+pattern/i
      described_class.add('test_flag', pattern)

      expect(described_class.matchers['test_flag']).to include(pattern)
    end

    it 'converts string matchers to case-insensitive regexp' do
      described_class.add('test_flag', 'hello world')

      matcher = described_class.matchers['test_flag'].first
      expect(matcher).to be_a(Regexp)
      expect('Hello World').to match(matcher)
      expect('HELLO WORLD').to match(matcher)
    end

    it 'escapes regex metacharacters in string matchers (BUG FIX)' do
      # This is the critical bug fix - before Regexp.escape, these would
      # be interpreted as regex metacharacters
      described_class.add('test_flag', 'test.*pattern')

      matcher = described_class.matchers['test_flag'].first

      # Should NOT match as regex wildcard
      expect('test anything pattern').not_to match(matcher)

      # Should match literal "test.*pattern"
      expect('test.*pattern').to match(matcher)
    end

    it 'escapes parentheses in string matchers (BUG FIX)' do
      described_class.add('test_flag', 'hello (world)')

      matcher = described_class.matchers['test_flag'].first

      # Should match the literal parentheses
      expect('hello (world)').to match(matcher)
    end

    it 'escapes pipe (alternation) in string matchers (BUG FIX)' do
      described_class.add('test_flag', 'foo|bar')

      matcher = described_class.matchers['test_flag'].first

      # Should NOT match "foo" alone (that would happen without escape)
      expect('foo').not_to match(matcher)

      # Should NOT match "bar" alone
      expect('bar').not_to match(matcher)

      # Should match the literal "foo|bar"
      expect('foo|bar').to match(matcher)
    end

    it 'escapes brackets in string matchers (BUG FIX)' do
      described_class.add('test_flag', '[item]')

      matcher = described_class.matchers['test_flag'].first

      # Without escape, [item] would be a character class matching i, t, e, m
      expect('i').not_to match(matcher)
      expect('t').not_to match(matcher)

      # Should match the literal "[item]"
      expect('[item]').to match(matcher)
    end

    it 'escapes dollar signs in string matchers (BUG FIX)' do
      described_class.add('test_flag', 'costs $5.00')

      matcher = described_class.matchers['test_flag'].first

      # Should match the literal string with $ and .
      expect('costs $5.00').to match(matcher)
    end

    it 'escapes caret in string matchers (BUG FIX)' do
      described_class.add('test_flag', '^start')

      matcher = described_class.matchers['test_flag'].first

      # Without escape, ^ would be a start-of-string anchor
      expect('not ^start').to match(matcher) # Should match in middle
      expect('^start of line').to match(matcher)
    end

    it 'handles multiple matchers' do
      described_class.add('test_flag', 'pattern1', /regex2/, 'pattern3.*escaped')

      matchers = described_class.matchers['test_flag']
      expect(matchers.length).to eq(3)
      expect(matchers[0]).to be_a(Regexp)
      expect(matchers[1]).to eq(/regex2/)
      expect(matchers[2]).to be_a(Regexp)
    end

    it 'preserves regex behavior for Regexp matchers' do
      described_class.add('test_flag', /test.*pattern/)

      matcher = described_class.matchers['test_flag'].first

      # Regexp matchers should work as regex
      expect('test anything pattern').to match(matcher)
    end
  end

  describe '.[]' do
    it 'returns nil for unknown flags' do
      expect(described_class['unknown']).to be_nil
    end

    it 'returns flag value' do
      described_class.add('test_flag', 'pattern')
      expect(described_class['test_flag']).to be false

      described_class['test_flag'] = true
      expect(described_class['test_flag']).to be true
    end
  end

  describe '.[]=' do
    it 'sets flag value' do
      described_class.add('test_flag', 'pattern')
      described_class['test_flag'] = 'matched text'

      expect(described_class['test_flag']).to eq('matched text')
    end
  end

  describe '.reset' do
    it 'sets flag back to false' do
      described_class.add('test_flag', 'pattern')
      described_class['test_flag'] = true

      described_class.reset('test_flag')

      expect(described_class['test_flag']).to be false
    end
  end

  describe '.delete' do
    it 'removes flag from flags hash' do
      described_class.add('test_flag', 'pattern')
      described_class.delete('test_flag')

      expect(described_class['test_flag']).to be_nil
    end

    it 'removes matchers from matchers hash' do
      described_class.add('test_flag', 'pattern')
      described_class.delete('test_flag')

      expect(described_class.matchers['test_flag']).to be_nil
    end
  end

  describe '.flags' do
    it 'returns the flags hash' do
      described_class.add('flag1', 'pattern1')
      described_class.add('flag2', 'pattern2')

      flags = described_class.flags

      expect(flags).to be_a(Hash)
      expect(flags.keys).to contain_exactly('flag1', 'flag2')
    end
  end

  describe '.matchers' do
    it 'returns the matchers hash' do
      described_class.add('flag1', 'pattern1')
      described_class.add('flag2', /regex/)

      matchers = described_class.matchers

      expect(matchers).to be_a(Hash)
      expect(matchers.keys).to contain_exactly('flag1', 'flag2')
    end
  end

  describe 'real-world examples' do
    it 'handles game output with special characters' do
      # Real game output often has special regex chars
      described_class.add('gem_pouch', 'You put .* in your gem pouch.')

      matcher = described_class.matchers['gem_pouch'].first

      # Before fix: would match "You put anything in your gem pouch."
      expect('You put a ruby in your gem pouch.').not_to match(matcher)

      # After fix: matches literal string only
      expect('You put .* in your gem pouch.').to match(matcher)
    end

    it 'handles escaped flags for item patterns with parens' do
      # Item names sometimes have (rare) or (uncommon) etc.
      described_class.add('got_item', 'a golden ring (rare)')

      matcher = described_class.matchers['got_item'].first

      expect('You see a golden ring (rare) on the ground.').to match(matcher)
    end
  end
end
