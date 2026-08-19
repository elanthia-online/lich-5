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

      expect(described_class.preserve_quiet_state_tags(chunk)).to eq('<output class=""/>')
    end

    it 'extracts every matching tag, in order, when more than one is present' do
      chunk = %(<output class="mono"/>text<output class=""/>)

      expect(described_class.preserve_quiet_state_tags(chunk))
        .to eq('<output class="mono"/><output class=""/>')
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

      expect(forwarded).to eq('<output class=""/>')
    end

    it 'forwards a bundled tag on an intermediate suppressed chunk, not just the end chunk' do
      run_issue_command(quiet: true)

      captured_proc[:action].call('You currently have the following active effects:') # enters filter
      mid_range_chunk = %(<output class="mono"/>Some Spell.....................  10:00)
      forwarded = captured_proc[:action].call(mid_range_chunk)

      expect(forwarded).to eq('<output class="mono"/>')
    end

    it 'does not alter non-quiet behavior (lines are forwarded unchanged)' do
      run_issue_command(quiet: false)

      start_chunk = 'You currently have the following active effects:'
      end_chunk = %(<output class=""/>\n<prompt time="1787075465">H&gt;</prompt>)

      expect(captured_proc[:action].call(start_chunk)).to eq(start_chunk)
      expect(captured_proc[:action].call(end_chunk)).to eq(end_chunk)
    end
  end
end
