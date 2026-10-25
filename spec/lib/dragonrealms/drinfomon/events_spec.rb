# frozen_string_literal: true

require_relative '../../../spec_helper'

require_relative '../../../../lib/dragonrealms/drinfomon/events'

RSpec.describe Lich::DragonRealms::Flags do
  before(:each) do
    # NOTE: class_variable_set used because Flags is a production class with no reset! method
    described_class.class_variable_set(:@@flags, {})
    described_class.class_variable_set(:@@matchers, {}.freeze)
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
    it 'sets the flag value to the assigned string or object' do
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

  describe 'concurrent access' do
    # DRParser.check_events walks Flags.matchers on the game thread for every
    # server line while scripts add and delete flags from their own threads.
    # Parking the reader after its first entry and writing from this thread
    # hits that window on every run instead of leaving it to the scheduler.
    # Returns the keys the parked iteration visited.
    def write_while_iterating(&write)
      parked = Queue.new
      resume = Queue.new
      reader = Thread.new do
        described_class.matchers.each_with_object([]) do |(key, _regexes), seen|
          seen << key
          next unless seen.size == 1

          parked << true
          resume.pop
        end
      end
      parked.pop(timeout: 5) || raise("reader never started iterating")
      begin
        write.call
      ensure
        resume << true
      end
      reader.value
    end

    before do
      described_class.add('flag1', 'pattern1')
      described_class.add('flag2', 'pattern2')
    end

    it 'adds a new flag while the matchers are being iterated' do
      seen = nil
      expect { seen = write_while_iterating { described_class.add('pouch-full', 'is too full') } }.not_to raise_error

      expect(seen).to eq(%w[flag1 flag2])
      expect(described_class.matchers.keys).to eq(%w[flag1 flag2 pouch-full])
      expect(described_class['pouch-full']).to be false
    end

    it 'deletes a flag while the matchers are being iterated, and the iteration still finishes' do
      seen = write_while_iterating { described_class.delete('flag2') }

      expect(seen).to eq(%w[flag1 flag2])
      expect(described_class.matchers.keys).to eq(%w[flag1])
      expect(described_class['flag2']).to be_nil
    end

    it 'survives the add-then-delete cycle a pouch fill runs while the iteration is parked' do
      expect do
        write_while_iterating do
          described_class.add('pouch-full', 'is too full')
          described_class.delete('pouch-full')
          described_class.add('pouch-full', 'is too full')
        end
      end.not_to raise_error

      expect(described_class.matchers.keys).to eq(%w[flag1 flag2 pouch-full])
    end

    it 'keeps both adds when a second thread adds while the first is mid-copy' do
      # Park the first writer after it has copied the matchers but before it
      # swaps the copy in. Without the lock the second writer copies the same
      # old hash and one of the two adds is lost.
      parked = Queue.new
      resume = Queue.new
      merges = 0
      slow = {}
      slow.define_singleton_method(:merge) do |*args|
        result = super(*args)
        merges += 1
        if merges == 1
          parked << true
          resume.pop
        end
        result
      end
      described_class.class_variable_set(:@@matchers, slow)

      first = Thread.new { described_class.add('first', 'p1') }
      expect(parked.pop(timeout: 5)).to be(true), "first writer never copied the matchers"
      second = Thread.new { described_class.add('second', 'p2') }
      Thread.pass until second.status == 'sleep' || !second.alive?
      resume << true
      [first, second].each(&:join)

      expect(described_class.matchers.keys).to contain_exactly('first', 'second')
    end

    it 'hands out a frozen matchers hash so callers cannot mutate it in place' do
      expect { described_class.matchers['rogue'] = [/x/] }.to raise_error(FrozenError)
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
