# frozen_string_literal: true

require 'rspec'
require 'timeout'
require_relative '../../../lib/common/downstreamhook'
require_relative '../../../lib/util/util.rb'
require_relative '../../spec_helper'

# Covers Lich::Util.issue_command's quiet: true filtering, specifically the
# fix for dropping bundled display-state tags along with suppressed text.
#
# Background: DownstreamHook.run is called with the raw, unsplit socket
# chunk (see Lich::Common::Game#process_downstream_hooks in lib/games.rb),
# not a single parsed display line. The server is free to bundle a
# formatting-state tag (e.g. the mono-closing `<output class=""/>`) onto the
# same chunk as the `<prompt>` a quiet-filtered range ends on. Before this
# fix, `next(nil)` on a suppressed chunk discarded that tag along with the
# text, leaving the frontend stuck in mono mode until an unrelated later
# mono tag happened to close it.
#
# These specs drive the DownstreamHook proc issue_command registers
# directly (captured via a wrapped DownstreamHook.add), rather than
# simulating the full socket pipeline, since the proc's suppression logic
# is what changed and is independently testable.
RSpec.describe Lich::Util do
  describe '.preserve_quiet_state_tags' do
    it 'returns nil for a chunk with no recognized state tags' do
      expect(described_class.preserve_quiet_state_tags('You are stunned!')).to be_nil
    end

    it 'returns nil for nil input' do
      expect(described_class.preserve_quiet_state_tags(nil)).to be_nil
    end

    it 'extracts a single bundled mono tag from surrounding text' do
      chunk = %(Some Spell.....................  10:00\n<output class=""/>\n<prompt time="1787075465">H&gt;</prompt>)

      expect(described_class.preserve_quiet_state_tags(chunk)).to eq(%(<output class=""/>\n))
    end

    it 'extracts every matching tag, in order, when more than one is present' do
      chunk = %(<output class="mono"/>text<output class=""/>)

      expect(described_class.preserve_quiet_state_tags(chunk))
        .to eq(%(<output class="mono"/><output class=""/>\n))
    end

    it 'terminates the returned tags with a newline, even though the matched tags never include one' do
      # Every other chunk that reaches this pipeline is newline/CRLF-
      # terminated (the game server's stream is line-oriented); a preserved-tag string
      # with no terminator is not a shape of line the pipeline produced
      # before this method existed. For sentinel-supporting frontends
      # (currently only Saga), every forwarded line gets a leading
      # Frontend::ORIGIN_SENTINEL byte the client consumes as routing
      # metadata and strips before display. An unterminated segment gave
      # the client nothing to delimit it by, and the sentinel byte fell
      # through to the display as a literal, visible character instead of
      # being consumed.
      chunk = '<output class="mono"/>'

      expect(described_class.preserve_quiet_state_tags(chunk)).to eq(%(<output class="mono"/>\n))
    end

    it 'preserves the chunk\'s real left-to-right order across two distinct patterns' do
      # QUIET_STATE_TAGS only has one confirmed entry today, so this
      # regression case stubs in a second, unrelated pattern for the
      # duration of this example to exercise the multi-pattern path before
      # a real second entry ever lands. Scanning each pattern separately and
      # concatenating the results groups matches by pattern rather than by
      # position -- invisible with one pattern, but wrong the moment a
      # second one is added and both fire on the same chunk, which matters
      # for tags that are an open/close pair.
      stub_const(
        'Lich::Util::QUIET_STATE_TAG_PATTERN',
        Regexp.union(/<output class="[^"]*"\s*\/>/, /<popBold\s*\/>/)
      )
      chunk = %(<output class="mono"/>text<popBold/>more<output class=""/>)

      expect(described_class.preserve_quiet_state_tags(chunk))
        .to eq(%(<output class="mono"/><popBold/><output class=""/>\n))
    end
  end

  describe '.issue_command with quiet: true' do
    let(:captured_proc) { {} }

    before do
      # issue_command's source calls the bare top-level constant
      # `DownstreamHook` unqualified (production relies on `include
      # Lich::Common` at boot for that to resolve to
      # Lich::Common::DownstreamHook). spec_helper.rb separately defines its
      # own lightweight top-level `DownstreamHook` mock (add/remove-less,
      # `unless defined?` guarded) for specs that don't need real hook
      # behavior. Which one wins the bare `DownstreamHook` name in a full
      # suite run depends on file load order across the whole spec/
      # directory, which this file does not control -- so rather than fight
      # that at load time, stub_const rebinds the constant just for the
      # examples in this block and restores whatever was there afterward,
      # independent of load order.
      stub_const('DownstreamHook', Lich::Common::DownstreamHook)

      # Capture the proc issue_command registers so it can be driven
      # directly with synthetic bundled chunks.
      allow(DownstreamHook).to receive(:add).and_wrap_original do |original, name, action, **kwargs|
        captured_proc[:action] = action
        original.call(name, action, **kwargs)
      end

      Script.current = OpenStruct.new(name: 'spec', silent: false, want_downstream: true, want_downstream_xml: true)
    end

    # Drives issue_command's internal get-loop just far enough for it to
    # match start_pattern then end_pattern and return, independent of the
    # DownstreamHook proc under test (get and DownstreamHook consume the
    # same underlying stream through separate paths in production).
    def run_issue_command(quiet:, timeout: 1)
      allow(described_class).to receive(:get).and_return(
        'You currently have the following active effects:',
        '<prompt time="1787075465">H&gt;</prompt>'
      )

      described_class.issue_command(
        'spell active',
        /You currently have the following/,
        /<prompt/,
        quiet: quiet,
        usexml: true,
        timeout: timeout
      )
    end

    it 'still returns the captured lines to the caller' do
      result = run_issue_command(quiet: true)

      expect(result).to eq(
        [
          'You currently have the following active effects:',
          '<prompt time="1787075465">H&gt;</prompt>'
        ]
      )
    end

    it 'drops a suppressed chunk outright when it carries no state tags' do
      run_issue_command(quiet: true)

      forwarded = captured_proc[:action].call('You currently have the following active effects:')

      expect(forwarded).to be_nil
    end

    it 'forwards a bundled mono-closing tag instead of dropping the whole end-of-range chunk' do
      run_issue_command(quiet: true)

      # Enter the filtering state via the start_pattern chunk.
      captured_proc[:action].call('You currently have the following active effects:')

      # The end-of-range chunk bundles the mono-closing tag with the prompt --
      # this is the exact server behavior from the reported bug.
      bundled_end_chunk = %(<output class=""/>\n<prompt time="1787075465">H&gt;</prompt>)
      forwarded = captured_proc[:action].call(bundled_end_chunk)

      expect(forwarded).to eq(%(<output class=""/>\n))
    end

    it 'forwards a bundled tag on an intermediate suppressed chunk, not just the end chunk' do
      run_issue_command(quiet: true)

      captured_proc[:action].call('You currently have the following active effects:') # enters filter
      mid_range_chunk = %(<output class="mono"/>Some Spell.....................  10:00)
      forwarded = captured_proc[:action].call(mid_range_chunk)

      expect(forwarded).to eq(%(<output class="mono"/>\n))
    end

    it 'does not alter non-quiet behavior (lines are forwarded unchanged)' do
      run_issue_command(quiet: false)

      start_chunk = 'You currently have the following active effects:'
      end_chunk = %(<output class=""/>\n<prompt time="1787075465">H&gt;</prompt>)

      expect(captured_proc[:action].call(start_chunk)).to eq(start_chunk)
      expect(captured_proc[:action].call(end_chunk)).to eq(end_chunk)
    end
  end

  describe '.normalize_lookup' do
    # normalize_lookup evals "Effects::#{effect}" to reach a
    # Lich::Gemstone::Effects::Registry (Effects::Cooldowns, Effects::Debuffs, ...).
    # Production resolves the bare `Effects` constant via `include Lich::Gemstone`
    # at the top level (see lib/main/main.rb), so stub a bare top-level
    # Effects::<name> double here rather than pulling in the full
    # Registry/XMLData.dialogs dependency chain.
    def stub_effect(name, hash)
      registry = Object.new
      registry.define_singleton_method(:to_h) { hash }
      registry.define_singleton_method(:active?) { |val| hash.key?(val) }
      stub_const('Effects', Module.new)
      stub_const("Effects::#{name}", registry)
    end

    it 'matches an underscored PSM lookup value against an effect key containing a colon' do
      # Regression: PSM feat names never encode punctuation ("covert_art_escape_artist"),
      # but some effect keys do ("Covert Art: Escape Artist"). Underscore-to-space
      # substitution alone can't reconstruct the colon, so both the lookup value and the
      # effect keys must be normalized the same way (colons included) before comparing.
      stub_effect('Cooldowns', 'Covert Art: Escape Artist' => Time.now)

      expect(described_class.normalize_lookup('Cooldowns', 'covert_art_escape_artist')).to be true
    end

    it 'still matches a plain underscored lookup against a punctuation-free effect key' do
      stub_effect('Cooldowns', 'Bulwark' => Time.now)

      expect(described_class.normalize_lookup('Cooldowns', 'bulwark')).to be true
    end

    it 'matches a Symbol lookup value the same way as an equivalent String' do
      stub_effect('Cooldowns', 'Covert Art: Escape Artist' => Time.now)

      expect(described_class.normalize_lookup('Cooldowns', :covert_art_escape_artist)).to be true
    end

    it 'returns false when no effect key matches' do
      stub_effect('Cooldowns', 'Bulwark' => Time.now)

      expect(described_class.normalize_lookup('Cooldowns', 'nonexistent_maneuver')).to be false
    end

    it 'delegates to the effect registry\'s active? for an Integer lookup value' do
      stub_effect('Cooldowns', 119_818_740 => Time.now)

      expect(described_class.normalize_lookup('Cooldowns', 119_818_740)).to be true
    end

    it 'raises for an unsupported lookup value type' do
      stub_effect('Cooldowns', {})

      expect { described_class.normalize_lookup('Cooldowns', 1.5) }.to raise_error(RuntimeError, /invalid lookup case/)
    end
  end
end
