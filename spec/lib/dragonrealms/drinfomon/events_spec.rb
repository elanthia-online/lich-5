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

    it 'treats string matchers as regex patterns (allows regex syntax)' do
      # String matchers are converted directly to regex - regex metacharacters
      # are interpreted as regex operators, enabling powerful pattern matching
      described_class.add('test_flag', 'test.*pattern')

      matcher = described_class.matchers['test_flag'].first

      # .* is interpreted as regex wildcard
      expect('test anything pattern').to match(matcher)
      expect('test pattern').to match(matcher)
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
    it 'allows regex wildcards for flexible game output matching' do
      # Using .* to match any item name
      described_class.add('gem_pouch', 'You put .* in your gem pouch')

      matcher = described_class.matchers['gem_pouch'].first

      # .* matches any item name
      expect('You put a ruby in your gem pouch.').to match(matcher)
      expect('You put a large diamond in your gem pouch.').to match(matcher)
    end

    it 'uses alternation for matching multiple patterns' do
      # Using | for alternation
      described_class.add('combat', 'You (hit|miss|dodge)')

      matcher = described_class.matchers['combat'].first

      expect('You hit the troll!').to match(matcher)
      expect('You miss!').to match(matcher)
      expect('You dodge the attack!').to match(matcher)
    end
  end
end
