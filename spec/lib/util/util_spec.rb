# frozen_string_literal: true

require 'rspec'
require 'timeout'
require_relative '../../../lib/common/downstreamhook'
require_relative '../../../lib/util/util.rb'
require_relative '../../spec_helper'
require_relative '../../../lib/common/markup'

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

  # Drives the real capture_command against a fake game thread that keeps
  # production's ordering (Game#process_server_string): each server string is
  # first pushed to the calling script's downstream buffer (process_xml_data),
  # then run through DownstreamHook (process_downstream_hooks), whose output
  # is what the frontend sees.
  describe '.capture_command / .issue_command' do
    # Minimal stand-in for the calling Script: the flags issue_command saves
    # and restores, and a thread-safe downstream buffer.
    let(:script_class) do
      Class.new do
        attr_accessor :silent, :want_downstream, :want_downstream_xml
        attr_reader :name

        def initialize
          @queue = Queue.new
          @name = 'spec'
          @want_downstream = false
          @want_downstream_xml = true
        end

        def downstream_buffer = self
        def push(line) = @queue << line
        def gets? = (@queue.pop(true) rescue nil)

        def drain
          lines = []
          while (line = gets?)
            lines << line
          end
          lines
        end
      end
    end

    let(:script) { script_class.new }
    let(:frontend) { [] }
    let(:prompt) { %(<prompt time="1787075465">H&gt;</prompt>\r\n) }

    before do
      # See the note in the old block: bind the real registry regardless of
      # spec_helper's lightweight DownstreamHook mock and load order.
      stub_const('DownstreamHook', Lich::Common::DownstreamHook)
      Script.current = script
      allow(Lich).to receive(:log)
    end

    after do
      DownstreamHook.remove('spec-other-hook')
      Script.current = nil
    end

    # Sends +reply+ as the game's response to the command. +gap+ widens the
    # window between the buffer push and the hook run for every string.
    def reply_with(reply, gap: 0)
      sender = lambda do |*_args, **_opts|
        @game_thread = Thread.new do
          reply.each do |raw|
            if script.want_downstream_xml
              script.push(raw)
            else
              Lich::Common::Markup.strip_xml(raw, type: 'main').to_s.split("\r\n").each { |l| script.push(l) unless l.empty? }
            end
            sleep gap if gap.positive?
            out = DownstreamHook.run(raw)
            frontend << out if out
          end
        end
        true
      end
      allow(described_class).to receive(:fput, &sender)
      allow(described_class).to receive(:put, &sender)
    end

    def capture(*args, **opts)
      result = described_class.capture_command(*args, timeout: 0.3, **opts)
      @game_thread&.join(1) # let the fake game thread finish forwarding
      result
    end

    def fe_lines = frontend.map(&:rstrip)

    it 'captures a multi-line reply through the end line' do
      reply_with(["Your flags:\r\n", "MonsterBold ON\r\n", prompt])
      result = capture('flag', /^Your flags/)

      expect(result.lines).to eq(['Your flags:', 'MonsterBold ON', prompt.rstrip])
      expect(result).to be_complete
    end

    it 'ends on the start line when that line also matches end_pattern' do
      reply_with(["You aren't wearing anything like that.\r\n", prompt, "A goblin arrives.\r\n"])
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = capture('inv combat', /All of your worn|You aren't wearing/, /Use INVENTORY HELP|You aren't wearing/,
                       usexml: false, include_end: false)

      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 0.5
      expect(result.lines).to eq(["You aren't wearing anything like that."])
      expect(result).to be_complete
    end

    it 'completes inv combat with nothing worn on the original patterns, leaving nothing behind' do
      # The reply as logged in DragonRealms: the help line always follows.
      reply_with(["You aren't wearing anything like that.\r\n", "[Use INVENTORY HELP for more options.]\r\n", prompt])
      result = capture('inv combat', /All of your worn combat|You aren't wearing anything like that/,
                       /Use INVENTORY HELP for more options/, usexml: false, include_end: false)

      expect(result).to be_complete
      expect(result.lines).to eq(["You aren't wearing anything like that."])
      expect(script.drain).to eq([])
    end

    it 'omits a separate end line when include_end is false' do
      reply_with(["All of your worn combat equipment:\r\n", "  a shield\r\n", "Use INVENTORY HELP for more options.\r\n"])
      result = capture('inv combat', /All of your worn/, /Use INVENTORY HELP/, usexml: false, include_end: false)

      expect(result.lines).to eq(['All of your worn combat equipment:', '  a shield'])
    end

    it 'with :ignore, captures only the start line' do
      reply_with(["You have 50 silver.\r\n", "A goblin arrives.\r\n", prompt])
      result = capture('wealth', /You have \d+ silver/, :ignore)

      expect(result.lines).to eq(['You have 50 silver.'])
      expect(result).to be_complete
    end

    it 'reports :no_start when the start line never arrives' do
      reply_with(["Something else.\r\n"])
      result = capture('flag', /^Your flags/)

      expect(result.lines).to eq([])
      expect(result.status).to eq(:no_start)
    end

    it 'reports :no_end, with the partial lines, when the end line never arrives' do
      reply_with(["Your flags:\r\n", "MonsterBold ON\r\n"])
      result = capture('flag', /^Your flags/)

      expect(result.lines).to eq(['Your flags:', 'MonsterBold ON'])
      expect(result.status).to eq(:no_end)
    end

    it 'issue_command returns the plain lines Array (partial on timeout), as before' do
      reply_with(["Your flags:\r\n"])
      result = described_class.issue_command('flag', /^Your flags/, timeout: 0.3)

      expect(result).to eq(['Your flags:'])
      expect(result.class).to eq(Array)
    end

    it 'matches text-mode patterns against stripped text, so quiet engages on a tag-led start line' do
      reply_with([%(<output class="mono"/>Usage: FLAG [ON|OFF]\r\n), "  MonsterBold ON\r\n",
                  "For other setting options, see AVOID, SET, and TOGGLE.\r\n", prompt])
      result = capture('flag', /^Usage/, /^For other setting options/, quiet: true, usexml: false)

      expect(result).to be_complete
      expect(fe_lines).to eq([%(<output class="mono"/>), prompt.rstrip])
    end

    it 'warns when a text-mode end_pattern is markup, which stripped text can never match' do
      reply_with([])
      capture('exp mods', /The following skills/, /^<output class=""/, usexml: false)

      expect(Lich).to have_received(:log).with(/looks like markup/)
    end

    it 'consumes the reply from the script buffer but leaves what follows it' do
      reply_with(["Your flags:\r\n", prompt, "A goblin arrives.\r\n"])
      capture('flag', /^Your flags/)

      expect(script.drain).to eq(["A goblin arrives.\r\n"])
    end

    it 'restores the script flags it changed' do
      script.silent = false
      reply_with(["x\r\n", prompt])
      capture('look', /x/, silent: true, usexml: false)

      expect([script.silent, script.want_downstream, script.want_downstream_xml]).to eq([false, false, true])
    end

    it 'stops at once with :error, and restores the script, when matching raises' do
      # Raise only for the observer's private strip buffer, not the fake game's.
      allow(Lich::Common::Markup).to receive(:strip_xml).and_wrap_original do |original, line, type: nil|
        raise 'boom' if type.to_s.start_with?('Util::capture_command')

        original.call(line, type: type)
      end
      reply_with(["Usage:\r\n", "x\r\n"])
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = capture('flag', /^Usage/, /^x/, usexml: false, quiet: true)

      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 0.2
      expect(result.status).to eq(:error)
      expect(Lich).to have_received(:log).with(/RuntimeError: boom/)
      expect(script.want_downstream_xml).to be true
    end

    it 'restores the script flags even if draining the buffer raises' do
      reply_with(["Your flags:\r\n", prompt])
      allow(script).to receive(:gets?).and_raise(RuntimeError, 'guard')

      expect { capture('flag', /^Your flags/, usexml: false) }.to raise_error(RuntimeError, 'guard')
      expect([script.want_downstream, script.want_downstream_xml]).to eq([false, true])
    end

    it 'removes its hooks whether or not the reply completed' do
      reply_with(["Your flags:\r\n"])
      capture('flag', /^Your flags/, quiet: true)

      expect(DownstreamHook.list.grep(/capture_command/)).to be_empty
    end

    context 'with quiet: true' do
      it 'hides start through end line, even when hooks lag the script buffer' do
        reply_with(["You currently have the following active effects:\r\n", "Spell...10:00\r\n", prompt], gap: 0.02)
        result = capture('spell active', /You currently have the following/, quiet: true)

        expect(result).to be_complete
        expect(frontend).to eq([])
      end

      it 'forwards a bundled mono-closing tag instead of dropping the whole end-of-range chunk' do
        reply_with(["You currently have the following active effects:\r\n",
                    %(<output class=""/>\n<prompt time="1787075465">H&gt;</prompt>\r\n)])
        capture('spell active', /You currently have the following/, quiet: true)

        expect(frontend).to eq([%(<output class=""/>\n)])
      end

      it 'forwards a bundled tag on an intermediate suppressed chunk' do
        reply_with(["You currently have the following active effects:\r\n",
                    %(<output class="mono"/>Some Spell.....................  10:00\r\n), prompt])
        capture('spell active', /You currently have the following/, quiet: true)

        expect(frontend).to eq([%(<output class="mono"/>\n)])
      end

      it 'leaves lines outside the reply alone' do
        reply_with(["A goblin arrives.\r\n", "Your flags:\r\n", prompt, "It attacks!\r\n"])
        capture('flag', /^Your flags/, quiet: true)

        expect(fe_lines).to eq(['A goblin arrives.', 'It attacks!'])
      end

      it 'still lets other hooks see the hidden lines' do
        seen = []
        DownstreamHook.add('spec-other-hook', proc { |line| seen << line.rstrip; line }, persist: true)
        reply_with(["Your flags:\r\n", prompt])
        capture('flag', /^Your flags/, quiet: true)

        expect(seen).to eq(['Your flags:', prompt.rstrip])
      end
    end

    it 'captures what the server sent even if another hook rewrites or squelches it' do
      DownstreamHook.add('spec-other-hook', proc { |line| line.include?('MonsterBold') ? nil : line.sub('Your', '>>Your') }, persist: true)
      reply_with(["Your flags:\r\n", "MonsterBold ON\r\n", prompt])
      result = capture('flag', /^Your flags/)

      expect(result.lines).to eq(['Your flags:', 'MonsterBold ON', prompt.rstrip])
      expect(fe_lines).to eq(['>>Your flags:', prompt.rstrip])
    end

    it 'does not alter frontend output when quiet is false' do
      reply_with(["Your flags:\r\n", prompt])
      capture('flag', /^Your flags/)

      expect(fe_lines).to eq(['Your flags:', prompt.rstrip])
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
