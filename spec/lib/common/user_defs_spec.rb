# frozen_string_literal: true

require_relative '../../spec_helper'

require File.join(LIB_DIR, 'common', 'user_defs.rb')

# Exercises the domain-neutral half of the user-definition machinery on a
# throwaway extending module: the memo/reset boundary, the lenient list loop,
# the shape validators, timeout-bounded compilation, guarded matching, and the
# message prefix rules. The DragonRealms CustomSubstitutions spec covers the
# same behaviour through its settings-backed entry point.
RSpec.describe Lich::Common::UserDefs do
  let(:defs) do
    Module.new do
      extend Lich::Common::UserDefs
      const_set(:MESSAGE_PREFIX, '[TestDefs]')

      class << self
        # Public shims so the spec can drive the private helpers.
        def list(raw, key, type)
          validate_entries(raw, key) do |entry, index|
            case type
            when :pairs   then validate_pair(entry, key, index)
            when :names   then validate_name(entry, key, index)
            when :regexes then validate_regex(entry, key, index)
            end
          end
        end

        def cached(key, &block) = memoize(key, &block)
        def prefix = message_prefix
      end
    end
  end

  before(:each) { Lich::Messaging.clear_messages! }

  def last_messages
    Lich::Messaging.messages.map { |m| m[:message] }.join("\n")
  end

  describe 'memoize and reset!' do
    it 'computes once and returns the cached value until reset!' do
      calls = 0
      2.times { defs.cached(:k) { calls += 1 } }
      expect(calls).to eq(1)

      defs.reset!
      defs.cached(:k) { calls += 1 }
      expect(calls).to eq(2)
    end

    it 'caches false and nil rather than recomputing them (presence, not truthiness)' do
      calls = 0
      2.times { defs.cached(:falsy) { calls += 1; false } }
      2.times { defs.cached(:nil) { calls += 1; nil } }
      expect(calls).to eq(2)
      expect(defs.cached(:falsy) { :recomputed }).to be(false)
      expect(defs.cached(:nil) { :recomputed }).to be_nil
    end
  end

  describe 'validate_entries' do
    it 'returns an empty list for nil without reporting' do
      expect(defs.list(nil, :things, :names)).to eq([])
      expect(last_messages).to eq('')
    end

    it 'ignores a non-list value and reports it' do
      expect(defs.list('nope', :things, :names)).to eq([])
      expect(last_messages).to include('[TestDefs] things ignored -- expected a list, got String')
    end

    it 'keeps valid entries while dropping invalid ones by index' do
      expect(defs.list(['good', 7, 'also'], :things, :names)).to eq(%w[good also])
      expect(last_messages).to include('things[1] skipped -- expected a non-empty string, got 7')
    end
  end

  describe 'validate_pair' do
    it 'accepts a [from, to] pair' do
      expect(defs.list([%w[a b]], :pairs, :pairs)).to eq([%w[a b]])
    end

    it 'rejects an empty from, a no-op pair, and non-strings' do
      expect(defs.list([['', 'x'], %w[same same], ['a', 1]], :pairs, :pairs)).to eq([])
      expect(last_messages).to include("'from' must not be empty")
      expect(last_messages).to include('would do nothing')
      expect(last_messages).to include("both 'from' and 'to' must be strings")
    end
  end

  describe 'validate_regex' do
    it 'compiles a string with the shared timeout' do
      compiled = defs.list(['gilded .* hilt'], :rx, :regexes).first
      expect(compiled).to be_a(Regexp)
      expect(compiled.timeout).to eq(described_class::REGEX_TIMEOUT_SECONDS)
    end

    it 're-wraps a pre-compiled Regexp keeping its flags and adding the timeout' do
      compiled = defs.list([/Encircling/i], :rx, :regexes).first
      expect(compiled.casefold?).to be(true)
      expect(compiled.timeout).to eq(described_class::REGEX_TIMEOUT_SECONDS)
    end

    it 'rejects an invalid pattern with the compile error' do
      expect(defs.list(['(unclosed'], :rx, :regexes)).to eq([])
      expect(last_messages).to include('invalid regular expression "(unclosed"')
    end

    it 'warns about non-ASCII but keeps the pattern' do
      source = "na#{[0xEF].pack('U')}ve"
      expect(defs.list([source], :rx, :regexes).size).to eq(1)
      expect(last_messages).to include('contains non-ASCII characters')
    end
  end

  describe 'apply_regexes' do
    it 'strips every matching pattern in order' do
      expect(defs.apply_regexes('a gaudy scroll with gems', [/ with gems$/, /gaudy /])).to eq('a scroll')
    end

    it 'skips a timed-out pattern, reports once, and leaves the text intact' do
      pattern = /(a+)+$/
      text = +'aaaa'
      allow(text).to receive(:sub).with(pattern, '').and_raise(Regexp::TimeoutError)

      expect(defs.apply_regexes(text, [pattern])).to eq('aaaa')
      expect(last_messages).to include('[TestDefs] a custom regular expression')

      Lich::Messaging.clear_messages!
      defs.apply_regexes(text, [pattern])
      expect(last_messages).not_to include('took too long')

      defs.reset!
      defs.apply_regexes(text, [pattern])
      expect(last_messages).to include('took too long') # reset! clears the dedup set
    end
  end

  describe 'message_prefix' do
    it 'uses MESSAGE_PREFIX when the extending module defines one' do
      expect(defs.prefix).to eq('[TestDefs]')
    end

    it 'falls back to the short module name otherwise' do
      stub_const('Lich::Common::PrefixlessDefs', Module.new { extend Lich::Common::UserDefs })
      prefix = Lich::Common::PrefixlessDefs.send(:message_prefix)
      expect(prefix).to eq('[PrefixlessDefs]')
    end
  end

  describe 'isolation between extending modules' do
    it 'gives each extender its own memo and timeout set' do
      other = Module.new { extend Lich::Common::UserDefs }
      defs.cached(:k) { :mine }
      expect(other.send(:memoize, :k) { :theirs }).to eq(:theirs)
    end
  end
end
