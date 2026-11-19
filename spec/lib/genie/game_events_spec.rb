# frozen_string_literal: true

require_relative 'support/example_timeout'
require_relative '../../../lib/genie'

# Lich::Genie::GameEvents: the script-timing events Game.cs raises while it parses a row and
# their delivery to the scripts -- SetRoundTime to every listed script, paused or not (FormMain.cs:
# 6927-6954 R; Script.cs:999-1007 R), the prompt text to the #triggers then TriggerPrompt / the
# text / TriggerMove to the unpaused scripts (ParseTriggers FormMain.cs:4425-4512 R; FormMain.cs:
# 6860-6915 R; Script.cs:1179-1191, 1434-1485 R), over the REAL Triggers registry and TriggerRunner.
RSpec.describe Lich::Genie::GameEvents do
  let(:vars) { Lich::Genie::Variables.new(global_store: Lich::Genie::GlobalStore.new) }
  let(:triggers) { Lich::Genie::Triggers.new }
  let(:echoes) { [] }
  let(:errors) { [] }
  let(:runner) do
    globals = Object.new
    globals.define_singleton_method(:key?) { |name| vars.global_key?(name) }
    Lich::Genie::TriggerRunner.new(vars: vars, eval: Lich::Genie::Eval.new(globals: globals), game: nil, launch: ->(_n, _a) {},
                                   echo: ->(text) { echoes << text })
  end

  def recipient(paused: false)
    Lich::Genie::ParseDispatch::Recipient.new(interpreter: nil, buffer: [], paused: paused)
  end

  def deliver(events, recipients, clock: -> { 100.0 })
    described_class.deliver(events, recipients: recipients, clock: clock, triggers: triggers, runner: runner,
                                    on_error: ->(e) { errors << e.message })
  end

  describe '.deliver' do
    it 'stamps a roundtime on the interpreters\' clock and gives it to every script, a paused one too' do
      running = recipient
      resting = recipient(paused: true)
      deliver([described_class::RoundTime.new(3.5)], [running, resting])
      [running, resting].each do |r|
        expect(r.buffer.length).to eq(1)
        expect(r.buffer.first).to be_a(described_class::RoundTimeEnd)
        expect(r.buffer.first.ends_at).to eq(103.5)
      end
      expect(running.buffer.first).to be(resting.buffer.first) # one item for all (it is frozen)
    end

    it 'reads the clock once per roundtime, at delivery' do
      reads = [10.0, 20.0]
      r = recipient
      deliver([described_class::RoundTime.new(1.0), described_class::RoundTime.new(1.0)], [r], clock: -> { reads.shift })
      expect(r.buffer.map(&:ends_at)).to eq([11.0, 21.0])
    end

    it 'gives a prompt and a move only to the unpaused scripts, in row order' do
      running = recipient
      resting = recipient(paused: true)
      prompt = described_class::Prompt.new('> ')
      deliver([described_class::MOVE, described_class::RoundTime.new(2.0), prompt], [running, resting])
      expect(running.buffer.map(&:class)).to eq([described_class::Move, described_class::RoundTimeEnd, described_class::Prompt])
      expect(resting.buffer.map(&:class)).to eq([described_class::RoundTimeEnd])
      expect(running.buffer.last).to be(prompt)
    end

    it 'reads a callable pause flag when the event reaches the script (an earlier trigger may pause it)' do
      flag = [false]
      r = recipient(paused: -> { flag[0] })
      triggers.add('^R> $', '#echo t')
      runner.define_singleton_method(:fire) do |_commands, _captures, **|
        flag[0] = true
      end
      deliver([described_class::Prompt.new('R> ')], [r])
      expect(r.buffer).to eq([])
    end

    it 'fires the #triggers on the prompt text before any script gets the prompt (ParseTriggers order)' do
      order = []
      triggers.add('^R> $', '#echo rprompt')
      buffer = []
      buffer.define_singleton_method(:push) { |item| order << [:script, item.class] && super(item) }
      runner.define_singleton_method(:fire) { |commands, _captures, **| order << [:trigger, commands] }
      deliver([described_class::Prompt.new('R> ')], [Lich::Genie::ParseDispatch::Recipient.new(interpreter: nil, buffer: buffer, paused: false)])
      expect(order).to eq([[:trigger, '#echo rprompt'], [:script, described_class::Prompt]])
    end

    it 'fires no #trigger for a prompt Remix prints no text for (nil) or a Trim()-empty one' do
      triggers.add('.*', '#echo any')
      triggers.add('^$', '#echo empty')
      r = recipient
      deliver([described_class::Prompt.new(nil), described_class::Prompt.new("  \t")], [r])
      expect(echoes).to eq([])
      expect(r.buffer.map(&:text)).to eq([nil, "  \t"])
    end

    it 'reports a failing trigger action and still delivers the prompt' do
      triggers.add('^> $', '#echo x')
      runner.define_singleton_method(:fire) { |_c, _a, **| raise ArgumentError, 'boom' }
      r = recipient
      deliver([described_class::Prompt.new('> ')], [r])
      expect(errors).to eq(['boom'])
      expect(r.buffer.length).to eq(1)
    end

    it 'delivers nothing for an empty row and ignores an unknown event' do
      r = recipient
      deliver([], [r])
      deliver([Object.new], [r])
      expect(r.buffer).to eq([])
    end
  end

  describe 'the input items' do
    it 'are frozen Strings with an empty text, like every other item on a script\'s input' do
      items = [described_class::RoundTimeEnd.new(1.0), described_class::Prompt.new('> '), described_class::MOVE, described_class::RESUMED]
      expect(items).to all(be_a(String))
      expect(items).to all(be_frozen)
      expect(items.map(&:to_s)).to eq(['', '', '', ''])
    end

    it 'keep a private, frozen copy of the prompt text' do
      text = +'R> '
      prompt = described_class::Prompt.new(text)
      text << 'x'
      expect(prompt.text).to eq('R> ')
      expect(prompt.text).to be_frozen
    end
  end

  describe '.kept_while_paused?' do
    it 'keeps only a roundtime (SetRoundTime has no pause check)' do
      expect(described_class.kept_while_paused?(described_class::RoundTimeEnd.new(1.0))).to be(true)
      [described_class::Prompt.new('> '), described_class::MOVE, described_class::RESUMED, 'a line',
       Lich::Genie::ParseDispatch::Line.new('x', 0), Lich::Genie::VariableDispatch::Change.new('$x', 0), nil].each do |item|
        expect(described_class.kept_while_paused?(item)).to be(false), item.inspect
      end
    end
  end

  describe '.offered?' do
    it 'is TriggerParse\'s blank test: .NET Trim (NBSP trimmed, NUL kept)' do
      expect(described_class.offered?('> ')).to be(true)
      expect(described_class.offered?(nil)).to be(false)
      expect(described_class.offered?(" \r\n")).to be(false)
      expect(described_class.offered?([0xA0].pack('U'))).to be(false)
      expect(described_class.offered?("\0")).to be(true)
    end
  end

  # A printed game text goes to the #triggers first, then to every
  # unpaused script as a plain (game-line) String -- so a trigger body's `#parse` reaches the
  # scripts before the line itself, as in ParseTriggers (FormMain.cs:4425-4512 R).
  describe 'TextLine' do
    it 'fires the #triggers, then queues a plain unfrozen String on the unpaused scripts only' do
      triggers.add('^ring (\\w+)', '#echo trig $1')
      running = recipient
      resting = recipient(paused: true)
      deliver([described_class::TextLine.new('ring bell')], [running, resting])
      expect(echoes).to eq(['trig bell'])
      expect(running.buffer).to eq(['ring bell'])
      expect([running.buffer.first.class, running.buffer.first.frozen?, resting.buffer]).to eq([String, false, []])
    end

    it "delivers a trigger body's #parse before the line that fired it" do
      log = []
      triggers.add('^X$', '#parse Y')
      parse_runner = Lich::Genie::TriggerRunner.new(vars: vars, eval: Lich::Genie::Eval.new(globals: Object.new.tap { |g| g.define_singleton_method(:key?) { |_n| false } }),
                                                    game: nil, launch: ->(_n, _a) {}, parse: ->(text) { log << [:parse, text] })
      r = recipient
      r.buffer.define_singleton_method(:push) { |line| log << [:line, line] }
      described_class.deliver([described_class::TextLine.new('X')], recipients: [r], clock: -> { 0.0 }, triggers: triggers,
                                                                     runner: parse_runner, on_error: ->(e) { errors << e.message })
      expect(log).to eq([[:parse, 'Y'], [:line, 'X']])
    end

    it 'tells the trace port about each text before its #triggers fire' do
      seen = []
      triggers.add('^t', '#echo fired')
      described_class.deliver([described_class::TextLine.new('t1')], recipients: [], clock: -> { 0.0 }, triggers: triggers, runner: runner,
                                                                      on_error: ->(e) { errors << e }, trace: ->(text) { seen << [text, echoes.dup] })
      expect(seen).to eq([['t1', []]])
    end
  end
end
