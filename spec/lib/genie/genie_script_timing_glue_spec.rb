# frozen_string_literal: true

require 'tmpdir'
require_relative 'support/example_timeout'
require_relative '../../spec_helper'
require_relative '../../../lib/common/limitedarray'
require_relative '../../../lib/common/feature_flags'
require_relative '../../../lib/common/downstreamhook'
require_relative '../../../lib/common/upstreamhook'
require_relative '../../../lib/genie'
require_relative 'support/glue_autoinstall_off'

# The timing glue in lib/genie/genie_script.rb, loaded for real on Lich's real Script class
# (setup as in genie_script_queue_glue_spec.rb):
#   * a genie script paused through `#script pause` drops what arrives while it is paused,
#     except a roundtime (GenieScript::InputBuffer; Script.cs:1179-1184, 1360-1363, 1434-1485 R);
#     a Lich-level pause (any other source) buffers it instead (a decided
#     divergence: Remix has no external pauser, and a dropped reply could hang a `waitfor`;
#     LichInputPort);
#     an unpause wakes the parked interpreter;
#   * the GameState listener: a game row's changes go out as a game row's and its GameEvents
#     follow, to every genie script (RoundTimeEnd) or the unpaused ones (Prompt, Move), the
#     prompt text to the #triggers first (GameEvents.deliver; FormMain.cs:4425-4512, 6860-6954 R);
#   * LichGamePort sends at once, in roundtime too (no waitrt?).
module GenieTimingGlueSpec
  GLUE_FILE = File.expand_path('../../../lib/genie/genie_script.rb', __dir__)
  GLUE_CONSTANTS = %i[GenieScript LichScriptControl LichGamePort LichInputPort LichHookSink LichGameState].freeze

  def self.load_quietly(file)
    verbose = $VERBOSE
    $VERBOSE = nil
    load file
  ensure
    $VERBOSE = verbose
  end
end

RSpec.describe 'Genie glue: roundtime, prompt, move and pause' do
  before(:context) do
    require_relative '../../../lib/common/script'
    GenieTimingGlueSpec.load_quietly(GenieTimingGlueSpec::GLUE_FILE)
  end

  after(:context) do
    GenieTimingGlueSpec::GLUE_CONSTANTS.each { |name| Lich::Genie.send(:remove_const, name) if Lich::Genie.const_defined?(name, false) }
    %i[SubScript ExecScript WizardScript Script Scripting TRUSTED_SCRIPT_BINDING].each do |const_name|
      Lich::Common.send(:remove_const, const_name) if Lich::Common.const_defined?(const_name, false)
    end
    $LOADED_FEATURES.delete_if { |path| path.end_with?('/lib/common/script.rb') }
  end

  let(:events) { Lich::Genie::GameEvents }
  let(:change) { Lich::Genie::VariableDispatch::Change }

  # The engine is on for the character (the hot paths' gate, Lich::Genie.engine_active?).
  before { allow(Lich::Genie).to receive(:engine_active?).and_return(true) }

  describe 'GenieScript::InputBuffer' do
    let(:paused) { [false] }
    let(:buffer) { Lich::Genie::GenieScript::InputBuffer.new(dropping: -> { paused[0] }) }

    it 'takes everything while its script runs, through push, << and append alike' do
      buffer.push('a line', change.new('$x', 0))
      buffer << events::MOVE
      buffer.append(events::Prompt.new('> '))
      expect(buffer.map(&:class)).to eq([String, change, events::Move, events::Prompt])
    end

    it 'drops lines, variable changes, prompts and moves while paused, and keeps a roundtime' do
      paused[0] = true
      rt = events::RoundTimeEnd.new(12.5)
      buffer.push('a line', change.new('$x', 0), events::MOVE, rt, events::Prompt.new('> '))
      buffer << 'another'
      buffer.append(Lich::Genie::ParseDispatch::Line.new('parsed', 0))
      expect(buffer.to_a).to eq([rt])
      expect(buffer.first).to be(rt)
    end

    it 'keeps what arrived before the pause (Remix handles it once the row loop lets go)' do
      buffer.push('before')
      paused[0] = true
      buffer.push('during')
      paused[0] = false
      buffer.push('after')
      expect(buffer.to_a).to eq(%w[before after])
    end

    it 'still trims to its max size and wakes a blocked reader' do
      buffer.max_size = 2
      buffer.push('1', '2', '3')
      expect(buffer.to_a).to eq(%w[2 3])
      buffer.clear
      reader = Thread.new { buffer.wait_shift(5) }
      # bounded: a reader that died (or never sleeps) fails the example instead of spinning
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
      Thread.pass until reader.status == 'sleep' || !reader.alive? || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      expect(reader.status).to eq('sleep')
      buffer.push('woken')
      expect(reader.value).to eq('woken')
    end
  end

  describe 'GenieScript' do
    let(:glue) { Lich::Genie::GenieScript }

    around do |example|
      Dir.mktmpdir('genie-wp6') do |dir|
        @dir = dir
        example.run
      end
    end

    # A fresh Genie script list per example (Lich::Genie.script_list stubbed, never reassigned);
    # every script built here is a running, LISTED one (an unlisted script drops its input).
    let(:list) { Lich::Genie::ScriptList.new }

    def script(name)
      path = File.join(@dir, "#{name}.cmd")
      File.write(path, "echo #{name}\n")
      glue.new(path).tap do |built|
        list.launched(built)
        list.run_ended(built)
        built.downstream_buffer.clear # the wake-up GenieScript#genie_listed pushes
      end
    end

    before do
      allow(Lich::Genie).to receive(:script_list).and_return(list)
      allow_any_instance_of(Lich::Genie::GenieScript).to receive(:respond)
      # GenieScript#initialize names Lich's top-level LimitedArray (Lich includes Lich::Common at
      # the top level); reverted after each example
      stub_const('LimitedArray', Lich::Common::LimitedArray) unless Object.const_defined?(:LimitedArray)
    end

    it 'gives every genie script an InputBuffer that drops while `#script pause` holds it' do
      hunt = script('hunt')
      expect(hunt.downstream_buffer).to be_a(glue::InputBuffer)
      Lich::Genie::LichScriptControl.new.pause('hunt')
      expect([hunt.paused?, hunt.input_dropped?, hunt.input_held?]).to eq([true, true, false])
      hunt.downstream_buffer.push('while paused')
      expect(hunt.downstream_buffer.to_a).to eq([])
    end

    describe 'a Lich-level pause (a decided divergence: buffered, not dropped)' do
      it 'buffers what arrives instead of dropping it, and the input port reads nothing until the unpause' do
        hunt = script('hunt')
        port = Lich::Genie::LichInputPort.new(hunt)
        hunt.pause # ;pause, pause_script, DRC.pause_all ...
        expect([hunt.input_dropped?, hunt.input_held?]).to eq([false, true])
        hunt.downstream_buffer.push('reply', events::Prompt.new('> '))
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        expect(port.next_line(timeout: 0.05)).to be_nil # held: waits out the timeout, reads nothing
        expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be >= 0.05
        expect(port.next_line(timeout: 0)).to be_nil # a spent timeout only looks
        hunt.unpause
        expect([port.next_line(timeout: 0), port.next_line(timeout: 0).class, port.next_line(timeout: 0)])
          .to eq(['reply', events::Prompt, events::RESUMED])
      end

      def sleeping(thread)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
        Thread.pass until thread.status == 'sleep' || !thread.alive? || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        thread.status
      end

      it 'hands a held read what was buffered first as soon as the unpause comes, even with no timeout' do
        hunt = script('hunt')
        port = Lich::Genie::LichInputPort.new(hunt)
        hunt.pause
        reader = Thread.new { port.next_line(timeout: nil) }
        expect(sleeping(reader)).to eq('sleep')
        hunt.downstream_buffer.push('kept')
        hunt.unpause
        expect(reader.join(2)&.value).to eq('kept') # before any deadline is re-checked
        expect(hunt.downstream_buffer.to_a).to eq([events::RESUMED])
      end

      it 'wakes a held read with a long timeout at the unpause, not when the timeout runs out' do
        hunt = script('hunt')
        port = Lich::Genie::LichInputPort.new(hunt)
        hunt.pause
        hunt.downstream_buffer.push('reply')
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        reader = Thread.new { port.next_line(timeout: 20) }
        expect(sleeping(reader)).to eq('sleep')
        hunt.unpause
        expect(reader.join(5)&.value).to eq('reply')
        expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 5
      end

      it 'pushes back a line that a read already blocked when the pause began takes, in front of the rest' do
        hunt = script('hunt')
        port = Lich::Genie::LichInputPort.new(hunt)
        reader = Thread.new { port.next_line(timeout: nil) } # not held yet: blocked in Script#gets
        expect(sleeping(reader)).to eq('sleep')
        hunt.pause
        hunt.downstream_buffer.push('first in the pause')
        expect(reader.join(2)&.value).to be_nil
        hunt.downstream_buffer.push('second')
        expect(hunt.downstream_buffer.to_a).to eq(['first in the pause', 'second'])
        hunt.unpause
        expect([port.next_line(timeout: 0), port.next_line(timeout: 0), port.next_line(timeout: 0)])
          .to eq(['first in the pause', 'second', events::RESUMED])
      end

      it 'hands a read that a `#script pause` overtakes nothing extra: the push is dropped, the read goes on' do
        hunt = script('hunt')
        port = Lich::Genie::LichInputPort.new(hunt)
        reader = Thread.new { port.next_line(timeout: nil) }
        expect(sleeping(reader)).to eq('sleep')
        hunt.genie_pause
        hunt.downstream_buffer.push('dropped')
        expect(reader.join(0.05)).to be_nil # still waiting: nothing reached the buffer
        hunt.unpause
        expect(reader.join(2)&.value).to eq(events::RESUMED)
      end

      it 'lets a held read go when the pause turns into a `#script pause` (it no longer holds; it drops)' do
        hunt = script('hunt')
        port = Lich::Genie::LichInputPort.new(hunt)
        hunt.pause
        hunt.downstream_buffer.push('kept before')
        reader = Thread.new { port.next_line(timeout: nil) }
        expect(sleeping(reader)).to eq('sleep')
        hunt.genie_pause
        expect(reader.join(2)&.value).to eq('kept before')
      end

      it 'notices a pause flag Lich clears without #unpause (teardown) within its recheck' do
        hunt = script('hunt')
        port = Lich::Genie::LichInputPort.new(hunt)
        hunt.pause
        hunt.downstream_buffer.push('kept')
        reader = Thread.new { port.next_line(timeout: nil) }
        expect(sleeping(reader)).to eq('sleep')
        hunt.instance_variable_set(:@paused, false) # Script's cleanup does exactly this (script.rb)
        expect(reader.join(2)&.value).to eq('kept')
      end

      it 'is not a dispatch skip: the recipients of a Lich-paused script still take a line' do
        hunt, = [script('hunt')].each { |s| s.instance_variable_set(:@genie_interpreter, Object.new) }
        hunt.pause
        expect(glue.genie_recipients.map(&:paused?)).to eq([false])
        hunt.unpause
        hunt.genie_pause
        expect(glue.genie_recipients.map(&:paused?)).to eq([true])
      end

      it 'turns into a dropping `#script pause` when Genie pauses it too, and the unpause ends both' do
        hunt = script('hunt')
        control = Lich::Genie::LichScriptControl.new
        allow(glue).to receive(:script_list_changed)
        hunt.pause
        control.pause('hunt')
        expect([hunt.paused?, hunt.input_dropped?]).to eq([true, true])
        control.resume('hunt')
        expect([hunt.paused?, hunt.input_dropped?, hunt.input_held?]).to eq([false, false, false])
        hunt.pause # a later Lich-level pause buffers again
        expect(hunt.input_held?).to be(true)
      end

      it 'pauses through pauseorresume as Genie\'s own pause (dropping), and resumes any pause' do
        hunt = script('hunt')
        control = Lich::Genie::LichScriptControl.new
        allow(glue).to receive(:script_list_changed)
        control.pauseorresume('hunt')
        expect(hunt.input_dropped?).to be(true)
        control.pauseorresume('hunt')
        expect(hunt.paused?).to be(false)
        hunt.pause
        control.resume('hunt')
        expect(hunt.paused?).to be(false)
      end
    end

    # End to end: a real Interpreter reading through LichInputPort. Its
    # clock is the monotonic clock plus a jump the example makes while the script is paused, so a
    # wait's deadline passes during the pause without the example sleeping it out.
    describe 'an interpreter under a Lich-level pause' do
      let(:jump) { [0.0] }
      let(:log) { Queue.new }

      def start(source)
        hunt = script('hunt')
        clock = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) + jump[0] }
        sent = log
        game = Object.new.tap { |port| port.define_singleton_method(:send_command) { |text| sent << [:send, text] } }
        interpreter = Lich::Genie::Engine.build(source, name: 'hunt', game: game, input: Lich::Genie::LichInputPort.new(hunt),
                                                         echo: ->(text) { sent << text }, queue: Lich::Genie::CommandQueue.new,
                                                         clock: clock, paused: -> { hunt.paused? })
        runner = Thread.new { interpreter.run }
        @runners = (@runners || []) << runner
        [hunt, runner]
      end

      after { (@runners || []).each(&:kill) }

      # bounded wait for +condition+ while +runner+ is parked (fails the example rather than spin)
      def settle(runner, &condition)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
        Thread.pass until (runner.status == 'sleep' && condition.call) || !runner.alive? ||
                          Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        runner.status == 'sleep' && condition.call
      end

      def drained = Array.new(log.size) { log.pop }

      matchwait = "matchre OK reply\nmatchwait 1\necho TIMEOUT\nexit\nOK:\necho MATCHED\n"

      it 'C: matches a reply that came in the pause though the matchwait ran out meanwhile (another line first)' do
        hunt, runner = start(matchwait)
        expect(settle(runner) { true }).to be(true)
        hunt.pause
        hunt.downstream_buffer.push('noise') # the blocked read takes it: pushed back, not handled
        hunt.downstream_buffer.push('the reply')
        expect(settle(runner) { hunt.downstream_buffer.to_a == ['noise', 'the reply'] }).to be(true)
        jump[0] += 5
        hunt.unpause
        expect(runner.join(5)).to be(runner)
        expect(drained).to eq(['MATCHED'])
      end

      it 'C2: matches a reply that was the first line of the pause, after the unpause and not during it' do
        hunt, runner = start(matchwait)
        expect(settle(runner) { true }).to be(true)
        hunt.pause
        hunt.downstream_buffer.push('the reply')
        expect(settle(runner) { hunt.downstream_buffer.to_a == ['the reply'] }).to be(true)
        expect(drained).to eq([])
        jump[0] += 5
        hunt.unpause
        expect(runner.join(5)).to be(runner)
        expect(drained).to eq(['MATCHED'])
      end

      it 'C3: matches a reply that came only after the matchwait had run out in the pause' do
        hunt, runner = start(matchwait)
        expect(settle(runner) { true }).to be(true)
        hunt.pause
        hunt.downstream_buffer.push('noise')
        expect(settle(runner) { hunt.downstream_buffer.to_a == ['noise'] }).to be(true)
        jump[0] += 5
        hunt.downstream_buffer.push('the reply')
        hunt.unpause
        expect(runner.join(5)).to be(runner)
        expect(drained).to eq(['MATCHED'])
      end

      it 'C4: still times out after the unpause when nothing matching came' do
        hunt, runner = start(matchwait)
        expect(settle(runner) { true }).to be(true)
        hunt.pause
        hunt.downstream_buffer.push('noise')
        expect(settle(runner) { hunt.downstream_buffer.to_a == ['noise'] }).to be(true)
        jump[0] += 5
        hunt.unpause
        expect(runner.join(5)).to be(runner)
        expect(drained).to eq(['TIMEOUT'])
      end

      it 'A2: fires no action during the pause; the kept lines fire it and end the waitfor after the unpause' do
        hunt, runner = start("action echo ACT $0 when ^other\nwaitfor reply\necho got\n")
        expect(settle(runner) { true }).to be(true)
        hunt.pause
        hunt.downstream_buffer.push('other line')
        hunt.downstream_buffer.push('the reply')
        expect(settle(runner) { hunt.downstream_buffer.to_a == ['other line', 'the reply'] }).to be(true)
        expect(drained).to eq([])
        hunt.unpause
        expect(runner.join(5)).to be(runner)
        expect(drained).to eq(['ACT other line', 'got'])
      end

      it 'D: a `#script pause` drops the reply, so the waitfor goes on waiting after the unpause' do
        hunt, runner = start("waitfor reply\necho got\n")
        expect(settle(runner) { true }).to be(true)
        hunt.genie_pause
        hunt.downstream_buffer.push('the reply')
        expect(hunt.downstream_buffer.to_a).to eq([])
        hunt.unpause
        expect(settle(runner) { hunt.downstream_buffer.empty? }).to be(true) # the wake-up was read
        expect(runner).to be_alive
        expect(drained).to eq([])
      end

      it 'E: a `pause N` that runs out in a Lich-level pause resumes only after the unpause' do
        hunt, runner = start("pause 0.3\necho resumed\n")
        expect(settle(runner) { true }).to be(true)
        hunt.pause
        jump[0] += 5
        looks = 0
        allow(hunt).to(receive(:paused?).and_wrap_original do |original|
          looks += 1
          original.call
        end)
        expect(settle(runner) { looks >= 3 }).to be(true) # went round its loop after the jump
        expect(drained).to eq([])
        hunt.unpause
        expect(runner.join(5)).to be(runner)
        expect(drained).to eq(['resumed'])
      end
    end

    it 'wakes the parked interpreter on unpause, and pushes nothing when the script was not paused' do
      hunt = script('hunt')
      hunt.unpause
      expect(hunt.downstream_buffer.to_a).to eq([])
      hunt.pause
      hunt.unpause
      expect(hunt.downstream_buffer.to_a).to eq([events::RESUMED])
    end

    describe '.game_state_changed' do
      let(:watcher) do
        Object.new.tap do |interp|
          interp.define_singleton_method(:wants_variable_change?) { |_name| true }
        end
      end
      let(:seen) { [] }
      let(:triggers) do
        log = seen
        Object.new.tap do |registry|
          registry.define_singleton_method(:apply) { |text| log << text }
          registry.define_singleton_method(:eval_candidates) { |_name| [] }
        end
      end

      before do
        allow(Lich::Genie).to receive(:triggers).and_return(triggers)
      end

      def listed(*names)
        names.map { |name| script(name).tap { |s| s.instance_variable_set(:@genie_interpreter, watcher) } }
      end

      it 'delivers a game row\'s changes as a game row\'s, then its events: roundtime to all, prompt/move to the unpaused' do
        running, resting, held = listed('running', 'resting', 'held')
        resting.genie_pause # `#script pause`: drops
        held.pause # a Lich-level pause buffers everything for after the unpause
        row = Lich::Genie::GameState::Row.new(['$prompt'], [events::RoundTime.new(3.0), events::Prompt.new('R> '), events::MOVE])
        before = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        glue.game_state_changed(row)
        items = running.downstream_buffer.to_a
        expect(items.map(&:class)).to eq([change, events::RoundTimeEnd, events::Prompt, events::Move])
        expect(items[0]).to be_game
        expect(items[1].ends_at).to be_within(1.0).of(before + 3.0)
        expect(items[2].text).to eq('R> ')
        expect(resting.downstream_buffer.map(&:class)).to eq([events::RoundTimeEnd])
        expect(held.downstream_buffer.map(&:class)).to eq([change, events::RoundTimeEnd, events::Prompt, events::Move])
        expect(seen).to eq(['R> ']) # ParseTriggers: the #triggers get the prompt text
      end

      it 'delivers a send\'s changes as plain changes and no event' do
        running, = listed('running')
        glue.game_state_changed(['lastcommand'])
        expect(running.downstream_buffer.map { |item| [item.class, item.game?] }).to eq([[change, false]])
        expect(seen).to eq([])
      end

      it 'offers no #trigger a prompt Remix prints no text for' do
        running, = listed('running')
        glue.game_state_changed(Lich::Genie::GameState::Row.new(['$prompt'], [events::Prompt.new(nil)]))
        expect(running.downstream_buffer.last).to be_a(events::Prompt)
        expect(seen).to eq([])
      end
    end
  end

  # Every line Lich echoes (respond/_respond -> Script.new_script_output) is main-window
  # text, so it clears GameState#last_row_was_prompt like FormMain.AddText (FormMain.cs:5100-5122 R)
  # -- a genie echo, a Lich message, a command echo, a line echoed inside a trigger action.
  describe 'GenieScript.feed_script_output and the last-row-was-prompt flag' do
    let(:glue) { Lich::Genie::GenieScript }
    let(:state) { Lich::Genie::GameState.new(clock: -> { Time.new(2026, 1, 1, 0, 0, 0, '+13:00') }) }
    let(:prompt_row) { "<prompt time=\"1700000000\">&gt;</prompt>\r\n" }
    let(:triggers) do
      Object.new.tap do |registry|
        registry.define_singleton_method(:apply) { |_text| nil }
        registry.define_singleton_method(:fire) { |*_args| nil }
      end
    end

    before do
      allow(Lich::Genie).to receive(:game_state).and_return(state)
      allow(Lich::Genie).to receive(:triggers).and_return(triggers)
      allow(Lich::Genie).to receive(:script_list).and_return(Lich::Genie::ScriptList.new) # no genie script runs
      state.feed(prompt_row)
    end

    def flag_after(line, nested: false)
      state.feed("You wait.\r\n")
      state.feed(prompt_row)
      Thread.current[:genie_in_script_trigger] = nested
      glue.feed_script_output(line)
      state.last_row_was_prompt
    ensure
      Thread.current[:genie_in_script_trigger] = false
    end

    it 'clears it for a Lich message, a command echo and a line echoed inside a trigger action' do
      expect(state.last_row_was_prompt).to be(true)
      expect(flag_after('--- Lich: hunt active.')).to be(false)
      expect(flag_after('[hunt]>look')).to be(false)
      expect(flag_after('nested echo', nested: true)).to be(false)
    end

    it 'keeps it for a blank line' do
      expect(flag_after('   ')).to be(true)
    end

    it 'never reports a failing game state through respond (it would re-enter this very path)' do
      allow(state).to receive(:printed).and_raise(RuntimeError, 'no capture')
      allow(glue.singleton_class::FEED_ERROR).to receive(:call)
      expect { glue.feed_script_output('--- Lich: hunt active.') }.not_to raise_error
      expect(glue.singleton_class::FEED_ERROR).not_to have_received(:call)
    end
  end

  describe 'LichGamePort' do
    it 'sends at once and never waits out roundtime (Remix gates resumes, not sends)' do
      port = Lich::Genie::LichGamePort.new
      sent = []
      allow(port).to receive(:waitrt?).and_raise('waitrt? must not be called')
      allow(port).to receive(:put) { |text| sent << text }
      allow(Lich::Genie.game_state).to receive(:sent)
      port.send_command('attack')
      expect(sent).to eq(['attack'])
    end
  end
end
