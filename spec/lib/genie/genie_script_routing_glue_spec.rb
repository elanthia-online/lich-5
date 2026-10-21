# frozen_string_literal: true

require 'timeout'
require_relative 'support/example_timeout'
require_relative '../../spec_helper'
require_relative '../../../lib/common/limitedarray'
require_relative '../../../lib/common/feature_flags'
require_relative '../../../lib/common/downstreamhook'
require_relative '../../../lib/common/upstreamhook'
require_relative '../../../lib/genie'
require_relative 'support/glue_autoinstall_off'

# The routing glue in lib/genie/genie_script.rb, loaded for real on Lich's real Script class (setup as
# in genie_script_queue_glue_spec.rb):
#   * a genie script's game text is GameState's printed texts, delivered by the engine; the
#     strip_xml lines Lich pushes from its game parser thread are dropped (GenieScript::InputBuffer);
#   * a game row's dispatch runs on the trigger worker (game_state_listener);
#   * the engine's own output never reaches matchwait or the #triggers (engine_respond);
#   * a send or a typed command is trigger-on-input (LichGamePort, input_broadcast, the typed-command hook);
#   * a #trigger body's launch on the trigger / queue worker waits for the first run;
#   * the genieHook data attribute is entity-encoded;
#   * the automapper hook for `#var roomname|prompt`; the gated game-state tap at Lich load.
module GenieRoutingGlueSpec
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

RSpec.describe 'Genie glue: game-text routing, the trigger worker, engine output and trigger-on-input' do
  before(:context) do
    require_relative '../../../lib/common/script'
    GenieRoutingGlueSpec.load_quietly(GenieRoutingGlueSpec::GLUE_FILE)
  end

  after(:context) do
    GenieRoutingGlueSpec::GLUE_CONSTANTS.each { |name| Lich::Genie.send(:remove_const, name) if Lich::Genie.const_defined?(name, false) }
    %i[SubScript ExecScript WizardScript Script Scripting TRUSTED_SCRIPT_BINDING].each do |const_name|
      Lich::Common.send(:remove_const, const_name) if Lich::Common.const_defined?(const_name, false)
    end
    $LOADED_FEATURES.delete_if { |path| path.end_with?('/lib/common/script.rb') }
  end

  let(:glue) { Lich::Genie::GenieScript }
  let(:said) { [] }
  let(:posted) { [] }
  let(:worker) do
    jobs = posted
    Object.new.tap { |w| w.define_singleton_method(:post) { |&job| jobs << job } }
  end
  let(:state) { Lich::Genie::GameState.new(write_clock: Lich::Genie::WriteClock.new) }
  let(:registry) { Lich::Genie::Triggers.new }

  # The engine is on for the character (the hot paths' gate, Lich::Genie.engine_active?); the
  # turn-off examples say otherwise.
  before { allow(Lich::Genie).to receive(:engine_active?).and_return(true) }

  before do
    log = said
    allow(glue).to receive(:respond) { |text| log << [text, Lich::Genie.engine_output?] }
    allow(Lich::Genie).to receive_messages(trigger_worker: worker, game_state: state, triggers: registry, script_list: Lich::Genie::ScriptList.new)
  end

  def buffer(listed: true, dropping: false)
    glue::InputBuffer.new(dropping: -> { dropping }, unlisted: -> { !listed })
  end

  describe 'GenieScript::InputBuffer (game text comes from GameState, not Lich\'s strip_xml)' do
    it "drops what Lich pushes from its game parser thread, keeps its other pushes and every engine push" do
      buf = buffer
      Thread.new do
        Thread.current[Lich::Genie::GameStateFeed::READER_KEY] = true
        buf.push('stripped game line')
        buf.engine_port.push('routed game line')
      end.join
      Thread.new { buf.push(';send text') }.join
      expect(buf.to_a).to eq(['routed game line', ';send text'])
    end

    it 'drops an engine push for an unlisted script and keeps only a roundtime while `#script pause`d' do
      expect(buffer(listed: false).tap { |b| b.engine_port.push('x') }.to_a).to eq([])
      rt = Lich::Genie::GameEvents::RoundTimeEnd.new(1.0)
      expect(buffer(dropping: true).tap { |b| b.engine_port.push('x', rt) }.to_a).to eq([rt])
    end
  end

  describe '.game_state_listener (Remix\'s trigger-Channel consumer)' do
    it 'posts a game row to the trigger worker and runs a send\'s changes at once' do
      row = Lich::Genie::GameState::Row.new(%w[$health], [])
      ran = []
      allow(glue).to receive(:game_state_changed) { |names| ran << names }
      glue.game_state_listener(row)
      glue.game_state_listener(%w[lastcommand])
      expect([ran, posted.length]).to eq([[%w[lastcommand]], 1])
      posted.shift.call
      expect(ran).to eq([%w[lastcommand], row])
    end

    it 'delivers a row\'s printed text to the #triggers, then the listed scripts\' engine ports, with the trace port' do
      log = []
      registry.add('^ring', '#echo trig')
      allow(glue).to receive(:trigger_runner).and_return(
        Object.new.tap { |r| r.define_singleton_method(:fire) { |c, _cap, **| log << [:fire, c] } }
      )
      port = Object.new.tap { |p| p.define_singleton_method(:push) { |*items| log.concat(items.map { |i| [:push, i] }) } }
      allow(glue).to receive(:genie_recipients).and_return([Lich::Genie::ParseDispatch::Recipient.new(interpreter: nil, buffer: port, paused: false)])
      allow(glue).to receive(:trace_line) { |text| log << [:trace, text] }
      glue.game_state_changed(Lich::Genie::GameState::Row.new([], [Lich::Genie::GameEvents::TextLine.new('ring bell')]))
      expect(log).to eq([[:trace, 'ring bell'], [:fire, '#echo trig'], [:push, 'ring bell']])
    end
  end

  # The assess-ids shim's lines (AssessIds.deliver, on Lich's parser thread in its DownstreamHook,
  # after the row's GameState feed) reach the #triggers and the genie scripts, and no .lic script.
  describe '.text_lines (game lines from outside the row parser)' do
    let(:log) { [] }

    before do
      events = log
      registry.add('\\[#(\\d+)\\]', '#echo id')
      allow(glue).to receive(:trigger_runner).and_return(
        Object.new.tap { |r| r.define_singleton_method(:fire) { |c, cap, **| events << [:fire, c, cap] } }
      )
      port = Object.new.tap { |p| p.define_singleton_method(:push) { |*items| events.concat(items.map { |i| [:push, i] }) } }
      allow(glue).to receive(:genie_recipients).and_return([Lich::Genie::ParseDispatch::Recipient.new(interpreter: nil, buffer: port, paused: false)])
      allow(glue).to receive(:variable_broadcast)
    end

    it 'posts them after the row posted before them, then delivers each as a game line: #triggers first' do
      glue.game_state_listener(Lich::Genie::GameState::Row.new([], [Lich::Genie::GameEvents::TextLine.new('You assess.')]))
      glue.text_lines(["a goblin [#12] (1) at melee range.\r\n", 'an orc [#13]'])
      expect([log, posted.length]).to eq([[], 2])
      posted.each(&:call)
      expect(log).to eq([[:push, 'You assess.'], [:fire, '#echo id', ['12']], [:push, 'a goblin [#12] (1) at melee range.'],
                         [:fire, '#echo id', ['13']], [:push, 'an orc [#13]']])
    end

    it 'decodes invalid UTF-8 (U+FFFD) and posts nothing for blank lines' do
      glue.text_lines(["\r\n", '   '])
      expect(posted).to eq([])
      glue.text_lines([[0x63, 0xE9].pack('C*')])
      posted.shift.call
      expect(log).to eq([[:push, "c#{[0xFFFD].pack('U')}"]])
    end

    # The reviewer's live case (misc_live.rb): with the shim and the engine on, a plain .lic doing
    # `get` must not see a synthetic `[#id]` line. The rows go through the shim's DownstreamHook
    # body on Lich's parser thread and Lich's real Script.new_downstream path stays untouched.
    describe 'AssessIds end to end: Genie scripts only, never a .lic script' do
      let(:server_rows) do
        [%(<pushStream id="assess"/>You assess your combat situation...\r\n),
         %(You (1) are facing <d cmd='look #78195083'>an elder Adan'f sorcerer</d> (2).\r\n),
         %(<popStream/><prompt time="1">&gt;</prompt>\r\n)]
      end
      let(:lic_buffer) { Lich::Common::LimitedArray.new }
      let(:genie_buffer) { buffer }
      let(:flag) { [true] }

      before do
        stub_const('Script', Lich::Common::Script) # lich.rbw's top-level `include Lich::Common`
        lic_script = Struct.new(:downstream_buffer, :want_downstream, :watchfor).new(lic_buffer, true, {})
        genie_script = Struct.new(:downstream_buffer, :want_downstream, :watchfor).new(genie_buffer, true, {})
        allow(Lich::Common::Script).to receive(:__running_snapshot).and_return([lic_script, genie_script])
        allow(glue).to receive(:genie_recipients).and_return([Lich::Genie::ParseDispatch::Recipient.new(interpreter: nil, buffer: genie_buffer.engine_port, paused: false)])
        allow(Lich::Genie).to receive(:text_listener).and_return(->(lines) { glue.text_lines(lines) })
        on = flag
        allow(Lich::Genie::AssessIds).to receive(:enabled?) { on[0] }
        allow(Lich::Common::DownstreamHook).to receive(:add) # the spec drives the hook body (observe) itself
      end

      after do
        %i[@buffer @active @in_assess @installed].each { |ivar| Lich::Genie::AssessIds.instance_variable_set(ivar, nil) }
      end

      def run_rows
        Lich::Genie::AssessIds.install!
        Thread.new do
          Thread.current[Lich::Genie::GameStateFeed::READER_KEY] = true # Lich's parser thread
          server_rows.each { |row| Lich::Genie::AssessIds.observe(row) }
        end.join
        posted.each(&:call)
      end

      it 'delivers the enriched line to the genie script and the #triggers, and nothing to the .lic script' do
        allow(Lich::Common::Script).to receive(:new_downstream).and_call_original
        run_rows
        expect(Lich::Common::Script).not_to have_received(:new_downstream)
        expect(lic_buffer.to_a).to eq([])
        expect(genie_buffer.to_a).to eq(["You (1) are facing an elder Adan'f sorcerer [#78195083] (2)."])
        expect(log).to include([:fire, '#echo id', ['78195083']])
      end

      it 'delivers nothing while the engine is off' do
        allow(Lich::Genie).to receive(:engine_active?).and_return(false)
        run_rows
        expect([posted, lic_buffer.to_a, genie_buffer.to_a]).to eq([[], [], []])
      end

      it 'delivers nothing while the flag is off' do
        flag[0] = false
        run_rows
        expect([posted, lic_buffer.to_a, genie_buffer.to_a]).to eq([[], [], []])
      end
    end
  end

  describe 'engine output (Genie never parses its own echo)' do
    it 'marks the echo port, the trigger error and the diagnostics as engine output' do
      glue.respond_in_chain('echo text')
      glue.singleton_class::TRIGGER_ERROR.call(RuntimeError.new('bad'))
      expect(said).to eq([['echo text', true], ['--- Lich: genie trigger error: bad', true]])
    end

    it 'prints the trace_triggers diagnostics for a game text as engine output, only when tracing' do
      registry.add('^ring', '#echo x', klass: 'bells')
      registry.toggle_class('bells', false)
      glue.trace_line('ring bell')
      expect(said).to eq([])
      allow(Lich::Genie).to receive(:trace_triggers).and_return(true)
      glue.trace_line('ring bell')
      expect(said).to eq([['--- genie rx: "ring bell"', true], ["--- genie trigger MATCH [INACTIVE (class 'bells' off)]: /^ring/", true]])
    end

    it 'never feeds engine output to matchwait or the #triggers; feeds another Lich line trimmed of CR/LF only' do
      fed = []
      allow(Lich::Genie::ParseDispatch).to receive(:feed_output) { |text, **| fed << text }
      allow(glue).to receive(:note_printed)
      Lich::Genie.engine_output { glue.feed_script_output('an echo') }
      glue.feed_script_output("  go2: you're already there\r\n")
      glue.feed_script_output('[sc]>look') # a command echo
      glue.feed_script_output("\r\n")
      expect(fed).to eq(["  go2: you're already there"])
    end

    it 'decodes an invalid UTF-8 Lich line (U+FFFD) before feeding it' do
      fed = []
      allow(Lich::Genie::ParseDispatch).to receive(:feed_output) { |text, **| fed << text }
      allow(glue).to receive(:note_printed)
      glue.feed_script_output([0x63, 0xE9].pack('C*'))
      expect([fed.first.valid_encoding?, fed.first]).to eq([true, "c#{[0xFFFD].pack('U')}"])
    end
  end

  describe 'trigger-on-input' do
    it 'sends, records $lastcommand, then parses the text through ParseDispatch.input' do
      order = []
      port = Lich::Genie::LichGamePort.new
      allow(port).to receive(:put) { |text| order << [:put, text] }
      allow(state).to receive(:sent) { |text| order << [:sent, text] }
      allow(glue).to receive(:input_broadcast) { |text| order << [:input, text] }
      port.send_command('look')
      expect(order).to eq([[:put, 'look'], [:sent, 'look'], [:input, 'look']])
    end

    it "hands a Lich command to do_client marked as the engine's (no typed input) and still records it" do
      port = Lich::Genie::LichGamePort.new
      marks = []
      allow(port).to receive(:do_client) { |text| marks << [text, Thread.current[Lich::Genie::GameStateFeed::ENGINE_CLIENT_KEY]] }
      allow(glue).to receive(:input_broadcast)
      port.send_command(Lich::Genie::LichCommand[',go2 12'])
      expect([marks, state['lastcommand'], Thread.current[Lich::Genie::GameStateFeed::ENGINE_CLIENT_KEY]]).to eq([[[',go2 12', true]], ',go2 12', nil])
    end

    it 'follows triggeroninput: off, nothing is parsed' do
      allow(glue).to receive(:trigger_runner).and_return(Object.new)
      expect(Lich::Genie::ParseDispatch).to receive(:input).once
      glue.input_broadcast('look')
      state.apply_setting('triggeroninput', 'False')
      glue.input_broadcast('look')
    end

    # The typed command's $lastcommand change (eval #triggers) and its
    # trigger-on-input both run on the trigger worker, never on Lich's client thread.
    it 'records a typed command and runs its trigger-on-input on the trigger worker, in that order' do
      hook = nil
      allow(Lich::Common::UpstreamHook).to receive(:add) { |_name, body, **| hook = body }
      feed = Lich::Genie::GameStateFeed.new(game_state: -> { state }, report: ->(e) { raise e })
      allow(Lich::Genie).to receive(:game_state_feed).and_return(feed)
      order = []
      allow(state).to(receive(:sent).and_wrap_original { |m, text, **kw| order << [:sent, text] && m.call(text, **kw) })
      allow(glue).to receive(:input_broadcast) { |text| order << [:input, text] }
      glue.install_upstream_hook!
      expect(hook.call(+'<c>look')).to eq('<c>look')
      expect([order, state['lastcommand'], posted.length]).to eq([[], nil, 1])
      posted.shift.call
      expect([order, state['lastcommand']]).to eq([[[:sent, 'look'], [:input, 'look']], 'look'])
    end
  end

  describe 'host launches (waiting for the first run)' do
    it 'waits for the first run on an engine host thread (trigger / queue worker), not on Lich\'s threads' do
      calls = []
      allow(glue).to receive(:launch) { |name, rest, **opts| calls << [name, rest, opts] }
      glue.host_launch('x', '')
      Thread.new do
        Thread.current[Lich::Genie::TriggerWorker::HOST_THREAD_KEY] = true
        glue.host_launch('y', 'a')
      end.join
      expect(calls).to eq([['x', '', { launcher: nil, wait: false }], ['y', 'a', { launcher: nil, wait: true }]])
    end

    it 'marks the queue worker as a host thread for one released command only' do
      seen = []
      runner = Object.new.tap { |r| r.define_singleton_method(:run_command) { |_a| seen << Thread.current[Lich::Genie::TriggerWorker::HOST_THREAD_KEY] } }
      allow(glue).to receive(:trigger_runner).and_return(runner)
      glue.run_queued_command('look', nil)
      expect([seen, Thread.current[Lich::Genie::TriggerWorker::HOST_THREAD_KEY]]).to eq([[true], nil])
    end
  end

  # Lich commands only from author-written text (security; a decided divergence, PR #1813
  # review item 1): only a LichCommand -- a send whose , or ; the author wrote -- goes
  # to do_client; any other text, however it starts, is a game send.
  describe 'LichGamePort#send_command and Lich commands' do
    let(:port) { Lich::Genie::LichGamePort.new }
    let(:client) { [] }
    let(:game) { [] }

    before do
      client_calls = client
      game_calls = game
      allow(port).to receive(:do_client) { |text| client_calls << text }
      allow(port).to receive(:put) { |text| game_calls << text }
      allow(glue).to receive(:input_broadcast)
    end

    it "puts a plain String starting with , or ; to the game -- the reviewer's relayed whisper never reaches do_client" do
      port.send_command(%(,e respond('PWNED_' + (6*7).to_s)))
      port.send_command(';kill all')
      port.send_command(+'<c>,go2 1')
      expect([client, game]).to eq([[], [%(,e respond('PWNED_' + (6*7).to_s)), ';kill all', '<c>,go2 1']])
    end

    it 'hands a LichCommand to do_client, and records a plain String as $lastcommand' do
      port.send_command(Lich::Genie::LichCommand[' <c>,go2 1'])
      expect([client, game, state['lastcommand'].class]).to eq([['<c>,go2 1'], [], String])
    end

    it 'puts a LichCommand that is not a Lich command shape (", x", a lone ",") to the game' do
      port.send_command(Lich::Genie::LichCommand[', x'])
      port.send_command(Lich::Genie::LichCommand[','])
      expect([client, game]).to eq([[], [', x', ',']])
    end
  end

  # PR #1813 review item 3: `Lich::Genie.enabled = false` mid-session stops every hot path at once
  # and turning it back on resumes them, no restart.
  describe 'turning the engine off mid-session (review item 3)' do
    let(:active) { [true] }

    before do
      flag = active
      allow(Lich::Genie).to receive(:engine_active?) { flag[0] }
    end

    it 'reads the gate as off when it fails, so the line passes as Lich has it' do
      allow(Lich::Genie).to receive(:engine_active?).and_raise(RuntimeError, 'db gone')
      expect(glue.engine_on?).to be(false)
    end

    it 'skips the trigger worker job of a game row (and of game lines) queued before the turn-off' do
      ran = []
      allow(glue).to receive(:game_state_changed) { |names| ran << names }
      allow(glue).to receive(:deliver_events) { |events| ran << events }
      glue.game_state_listener(Lich::Genie::GameState::Row.new(%w[$health], []))
      glue.text_lines(['a goblin'])
      active[0] = false
      posted.each(&:call)
      active[0] = true
      glue.game_state_listener(Lich::Genie::GameState::Row.new(%w[$mana], []))
      posted.last.call
      expect(ran.map(&:to_a)).to eq([%w[$mana]])
    end

    it 'feeds no Lich line to matchwait or the #triggers while off' do
      fed = []
      allow(Lich::Genie::ParseDispatch).to receive(:feed_output) { |text, **| fed << text }
      allow(glue).to receive(:note_printed)
      active[0] = false
      glue.feed_script_output('go2: done')
      active[0] = true
      glue.feed_script_output('go2: again')
      expect(fed).to eq(['go2: again'])
      expect(glue).to have_received(:note_printed).once
    end

    it 'runs no trigger-on-input while off' do
      allow(glue).to receive(:trigger_runner).and_return(Object.new)
      allow(Lich::Genie::ParseDispatch).to receive(:input)
      active[0] = false
      glue.input_broadcast('look')
      expect(Lich::Genie::ParseDispatch).not_to have_received(:input)
    end

    it 'drops a queued command released while off instead of sending it' do
      ran = []
      runner = Object.new.tap { |r| r.define_singleton_method(:run_command) { |a| ran << a } }
      allow(glue).to receive(:trigger_runner).and_return(runner)
      active[0] = false
      glue.run_queued_command('QUEUED_LATE', nil)
      active[0] = true
      glue.run_queued_command('NOW', nil)
      expect(ran).to eq(['NOW'])
    end

    it 'leaves the typed-command hook a pass-through recording nothing while off' do
      hook = nil
      allow(Lich::Common::UpstreamHook).to receive(:add) { |_name, body, **| hook = body }
      feed = Lich::Genie::GameStateFeed.new(game_state: -> { state }, report: ->(e) { raise e })
      allow(Lich::Genie).to receive(:game_state_feed).and_return(feed)
      glue.install_upstream_hook!
      active[0] = false
      expect([hook.call(+'<c>look'), posted.length]).to eq(['<c>look', 0])
      active[0] = true
      expect([hook.call(+'<c>look'), posted.length]).to eq(['<c>look', 1])
    end

    # A running .cmd script sends nothing while the engine is off.
    describe "a script's send while off" do
      let(:port) { Lich::Genie::LichGamePort.new }
      let(:wire) { [] }
      let(:script) do
        Lich::Genie::GenieScript.allocate.tap { |s| s.define_singleton_method(:name) { 'hunt' } }
      end

      before do
        sent = wire
        allow(port).to receive(:put) { |text| sent << text }
        allow(port).to receive(:do_client) { |text| sent << [:client, text] }
        allow(glue).to receive(:input_broadcast)
        allow(Lich::Common::Script).to receive(:current_without_pause).and_return(script)
      end

      it 'drops it -- game text and Lich command alike -- with one notice per off spell, and sends again once on' do
        active[0] = false
        port.send_command('look')
        port.send_command(Lich::Genie::LichCommand[',go2 1'])
        active[0] = true
        port.send_command('bow')
        active[0] = false
        port.send_command('look')
        notice = '[Genie: the engine is off (Lich::Genie.enabled) -- hunt sends nothing until it is turned back on.]'
        expect([wire, said]).to eq([['bow'], [[notice, true], [notice, true]]])
        expect(state['lastcommand']).to eq('bow') # a dropped send records nothing
      end

      it "drops a queued item's release on behalf of its script the same way (the owner asks)" do
        active[0] = false
        Thread.current[Lich::Genie::GenieScript::QUEUE_OWNER_KEY] = script
        port.send_command('look')
        expect([wire, said.length]).to eq([[], 1])
      ensure
        Thread.current[Lich::Genie::GenieScript::QUEUE_OWNER_KEY] = nil
      end

      it 'drops a send with no genie script behind it silently' do
        allow(Lich::Common::Script).to receive(:current_without_pause).and_return(nil)
        active[0] = false
        port.send_command('look')
        expect([wire, said]).to eq([[], []])
      end
    end

    it "stops the session trigger runner's #trigger bodies while off (the gate is wired into the real runner)" do
      allow(Lich::Genie).to receive_messages(global_store: Lich::Genie::GlobalStore.new, lists: Lich::Genie::Lists.new)
      runner = glue.trigger_runner
      active[0] = false
      runner.fire('#var d10_off_probe 1', [], authored: true)
      active[0] = true
      runner.fire('#var d10_on_probe 1', [], authored: true)
      expect([Lich::Genie.global_store.get('d10_off_probe'), Lich::Genie.global_store.get('d10_on_probe')]).to eq([nil, '1'])
    end
  end

  # PR #1813 open question: <genieHook> tags only for a character that turned them on; without them
  # the text of `#echo >window` / `#link` / an input-box text still reaches the player.
  describe 'LichHookSink with hooks off (the default) and on' do
    let(:sink) { Lich::Genie::LichHookSink.new }
    let(:streamed) { [] }
    let(:hooks_on) { [false] }

    before do
      out = streamed
      flag = hooks_on
      messaging = Module.new
      messaging.define_singleton_method(:stream_window) { |msg, window| out << [msg, window, Lich::Genie.engine_output?] }
      stub_const('Lich::Messaging', messaging)
      allow(Lich::Genie).to receive(:hooks_enabled?) { flag[0] }
      allow(sink).to receive(:emit_tag)
    end

    it "shows #echo >window text in Lich's window of that name (lower-cased), as engine output, and writes no tag" do
      sink.emit('echo', 'window' => 'Familiar', 'text' => 'hi there')
      expect([streamed, said]).to eq([[['hi there', 'familiar', true]], []])
      expect(sink).not_to have_received(:emit_tag)
    end

    it "shows a #link's text (its window, or the main window for none)" do
      sink.emit('link', 'window' => '', 'text' => '1. Stats', 'command' => '#send .stats')
      expect(streamed).to eq([['1. Stats', '', true]])
    end

    it 'echoes an input-box text to the main window' do
      sink.emit('inputbox', 'text' => 'say @')
      expect(said).to eq([['say @', true]])
    end

    it 'does nothing for a front-end op with no text to show (highlight, window, beep, class, ...)' do
      %w[highlight window beep class preset macro playsound statusbar comment config].each { |op| sink.emit(op, 'text' => 'x') }
      expect([streamed, said]).to eq([[], []])
      expect(sink).not_to have_received(:emit_tag)
    end

    it "falls back to a plain engine echo when Lich's messaging fails" do
      allow(Lich::Messaging).to receive(:stream_window).and_raise(NoMethodError, 'no XMLData')
      sink.emit('echo', 'window' => 'Log', 'text' => 'kept')
      expect(said).to eq([['kept', true]])
    end

    it 'writes the tag, and nothing else, once the character turned hooks on' do
      hooks_on[0] = true
      sink.emit('echo', 'window' => 'Log', 'text' => 'x')
      sink.emit('highlight', 'pattern' => 'y')
      expect(sink).to have_received(:emit_tag).twice
      expect([streamed, said]).to eq([[], []])
    end
  end

  describe 'the automapper hook (`#var roomname|prompt`)' do
    it 'tells the game state about a script\'s change, never about a game row\'s' do
      allow(Lich::Genie::VariableDispatch).to receive(:broadcast)
      allow(glue).to receive(:trigger_runner).and_return(Object.new)
      allow(state).to receive(:plugin_variable_changed)
      glue.variable_broadcast('$roomname')
      glue.variable_broadcast(%w[$roomname], game: true)
      expect(state).to have_received(:plugin_variable_changed).once.with('$roomname')
    end
  end

  describe 'LichHookSink.hook_tag' do
    it 'entity-encodes the JSON payload and the op so the element is well-formed XML' do
      tag = Lich::Genie::LichHookSink.hook_tag('echo', { 'text' => %(don't <b> & "x") })
      expect(tag).to eq(%(<genieHook v="1" op="echo" data='{&quot;text&quot;:&quot;don&apos;t &lt;b&gt; &amp; \\&quot;x\\&quot;&quot;}'/>))
      require 'rexml/document'
      data = REXML::Document.new(tag).root.attributes['data']
      expect(JSON.parse(data)).to eq('text' => %(don't <b> & "x"))
    end
  end

  describe 'the engine start (install_downstream_hook!)' do
    it 'wires the game-state listener, the game-text intake and the #trigger shut-off report' do
      saved = [Lich::Genie.variable_listener, Lich::Genie.text_listener, Lich::Genie.trigger_disabled_listener]
      allow(Lich::Genie).to receive(:global_store)
      allow(Lich::Genie::AssessIds).to receive(:enabled?).and_return(false)
      %i[install_game_state_tap! install_upstream_hook! install_script_output_trigger_tap!].each { |name| allow(glue).to receive(name) }
      allow(Lich::Common::DownstreamHook).to receive(:add)
      glue.send(:install_downstream_hook!)
      allow(glue).to receive(:game_state_listener)
      allow(glue).to receive(:text_lines)
      Lich::Genie.variable_listener.call(%w[$x])
      Lich::Genie.text_listener.call(%w[line])
      expect(glue).to have_received(:game_state_listener).with(%w[$x])
      expect(glue).to have_received(:text_lines).with(%w[line])
      # wired on the module, not on the registry of the moment
      expect(registry.on_disabled).to be_nil
      Lich::Genie.trigger_disabled_listener.call('(a+)+b')
      expect(said.last).to eq(['--- Lich: genie #trigger disabled: /(a+)+b/ timed out 3 times in a row (add it again to re-enable it)', true])
    ensure
      Lich::Genie.variable_listener, Lich::Genie.text_listener, Lich::Genie.trigger_disabled_listener = saved
    end
  end

  # Lich's DownstreamHook.run removes a hook that raises for the rest of the
  # session (lib/common/downstreamhook.rb) -- the gag/sub hook must fail open.
  describe 'the genie-downstream hook (fail open)' do
    let(:hooks) { {} }

    before do
      store = hooks
      allow(Lich::Genie).to receive(:global_store)
      allow(Lich::Genie::AssessIds).to receive(:enabled?).and_return(false)
      %i[install_game_state_tap! install_upstream_hook! install_script_output_trigger_tap! start_command_queue!].each { |name| allow(glue).to receive(name) }
      allow(Lich::Common::DownstreamHook).to receive(:add) { |name, action, **| store[name] = action }
      @saved = [Lich::Genie.variable_listener, Lich::Genie.text_listener, Lich::Genie.trigger_disabled_listener,
                Lich::Genie.filter_disabled_listener, Lich::Genie.display_globals]
      glue.send(:install_downstream_hook!)
    end

    after do
      Lich::Genie.variable_listener, Lich::Genie.text_listener, Lich::Genie.trigger_disabled_listener,
        Lich::Genie.filter_disabled_listener, Lich::Genie.display_globals = @saved
    end

    it 'passes the line on (and reports) when the filters fault, and Lich keeps the hook' do
      allow(Lich::Genie).to receive(:stream_filters).and_raise(RuntimeError, 'filters broke')
      action = hooks.fetch('genie-downstream')
      expect(action.call("a line\r\n")).to eq("a line\r\n")
      expect(said.map(&:first)).to include(a_string_including('genie display filter error: filters broke'))
      allow(Lich::Common::DownstreamHook).to receive(:add).and_call_original
      Lich::Common::DownstreamHook.add('genie-downstream-spec', action, persist: true)
      expect(Lich::Common::DownstreamHook.run("other\r\n")).to eq("other\r\n")
      expect(Lich::Common::DownstreamHook._hooks).to have_key('genie-downstream-spec')
    ensure
      Lich::Common::DownstreamHook.remove('genie-downstream-spec')
    end

    it 'passes every line as Lich has it while the engine is off (no gag, no queue kick) and gags again once on' do
      filters = Lich::Genie::StreamFilters.new
      filters.add_gag('^SECRET')
      allow(Lich::Genie).to receive(:stream_filters).and_return(filters)
      active = [false]
      allow(Lich::Genie).to receive(:engine_active?) { active[0] }
      action = hooks.fetch('genie-downstream')
      expect(action.call("SECRET line\r\n")).to eq("SECRET line\r\n")
      expect(glue).not_to have_received(:start_command_queue!)
      active[0] = true
      expect(action.call("SECRET line\r\n")).to be_nil # gagged: nothing for the client
      expect(glue).to have_received(:start_command_queue!).once
    end

    it 'gags with the tags kept through the real filters' do
      filters = Lich::Genie::StreamFilters.new
      filters.add_gag('^Ignite')
      allow(Lich::Genie).to receive(:stream_filters).and_return(filters)
      expect(hooks.fetch('genie-downstream').call(%(<pushStream id="percWindow"/>Ignite  (11 roisaen)\r\n))).to eq('<pushStream id="percWindow"/>')
    end

    it 'posts a gag/sub shut-off warning to the trigger worker instead of printing on the parser thread' do
      said.clear # the engine banner
      Lich::Genie.filter_disabled_listener.call('gag', '(a+)+b')
      expect(said).to eq([])
      posted.shift.call
      expect(said.last).to eq(['--- Lich: genie gag disabled: /(a+)+b/ timed out 3 times in a row (add it again to re-enable it)', true])
    end
  end

  # A substitute's replacement is ParseGlobalVars'd by the display port on Lich's parser
  # thread, inside a game-state row. $roomid/$zoneid/$zonename from Lich's Map there deadlocked the
  # parser thread against a map load (Map.load_json holds its load lock across `respond
  # map_loaded_message`, whose script-output tap prints through the game state). The display port's
  # globals replay the host values the live resolvers last read (LichGameState::READINGS); the
  # trigger worker reads the map ones at each automapper room update, from a loaded map only.
  describe 'the display port globals (host values replayed, never read on the parser thread)' do
    let(:readings) { Lich::Genie::HostReadings.new }
    let(:filters) { Lich::Genie::StreamFilters.new }
    let(:display_state) do
      shown = filters
      Lich::Genie::GameState.new(write_clock: Lich::Genie::WriteClock.new, display: ->(text, target) { shown.displayed(text, target) })
    end
    let(:hooks) { {} }

    def fake_map(loaded:, current: nil, &on_current)
      Class.new do
        define_singleton_method(:loaded?) { loaded }
        define_singleton_method(:current) { on_current ? on_current.call : current }
      end
    end

    before do
      store = hooks
      stub_const('Lich::Genie::LichGameState::READINGS', readings)
      allow(Lich::Genie).to receive(:global_store).and_return(Lich::Genie::GlobalStore.new)
      allow(Lich::Genie::AssessIds).to receive(:enabled?).and_return(false)
      %i[install_game_state_tap! install_upstream_hook! install_script_output_trigger_tap! start_command_queue!].each { |name| allow(glue).to receive(name) }
      allow(Lich::Common::DownstreamHook).to receive(:add) { |name, action, **| store[name] = action }
      @saved = [Lich::Genie.variable_listener, Lich::Genie.text_listener, Lich::Genie.trigger_disabled_listener,
                Lich::Genie.filter_disabled_listener, Lich::Genie.display_globals]
      glue.send(:install_downstream_hook!)
      expander = Lich::Genie.display_globals
      filters.globals = ->(text) { expander.call(text) }
      filters.add_sub('^You also see', 'Room $roomid in $zoneid ($zonename):')
    end

    after do
      Lich::Genie.variable_listener, Lich::Genie.text_listener, Lich::Genie.trigger_disabled_listener,
        Lich::Genie.filter_disabled_listener, Lich::Genie.display_globals = @saved
    end

    it 'neither deadlocks Lich\'s parser thread against a map load nor calls Lich\'s Map from it (the probe scenario)' do
      map = MapLoader.use(:dr)
      map.clear # not loaded: a Map.current would wait on the load lock
      parser_calls = []
      %i[current load].each do |name|
        allow(map).to receive(name).and_wrap_original do |original, *args|
          parser_calls << name if Thread.current[:wp10_r2_parser]
          original.call(*args)
        end
      end
      readings.record('roomid', '118')
      allow(Lich::Genie).to receive(:game_state).and_return(display_state)
      display_state.feed(%(<prompt time="1700000000">&gt;</prompt>\r\n))
      entered = Queue.new
      release = Queue.new
      loader = Thread.new do # Map.load_json: synchronize_load { parse; respond map_loaded_message }
        map.synchronize_load do
          entered << true
          release.pop
          glue.feed_script_output('--- Map loaded map-1700000000.json') # respond -> the script-output tap
        end
      end
      entered.pop
      parser = Thread.new do
        Thread.current[:wp10_r2_parser] = true
        display_state.feed("You also see a goblin.\r\n")
      end
      expect(parser.join(10)).not_to be_nil # the row never waits on the map's load lock
      release << true
      expect(loader.join(10)).not_to be_nil
      expect(parser_calls).to eq([])
      expect(display_state.last_row_was_prompt).to be(false) # the loader's line was recorded
      expect(filters.displayed("You also see a goblin.\r\n")).to eq("Room 118 in 0 (0): a goblin.\r\n")
    ensure
      release&.push(true)
      [parser, loader].compact.each { |t| t.join(0.5) || t.kill }
    end

    it 'replays the last live read of every host value and calls no host code itself' do
      stub_const('Lich::Common::Map', fake_map(loaded: true, current: double(genie_id: '7', genie_zone: '1')))
      live = Lich::Genie::LichGameState.new(game_state: state)
      expect([live['roomid'], live['zoneid'], live['scriptlist']]).to eq(%w[7 1 none])
      zone_name = live['zonename']
      stub_const('Lich::Common::Map', fake_map(loaded: true) { raise 'Map read on the display port' })
      allow(Lich::Genie).to receive(:script_list).and_raise('script list read on the display port')
      cached = Lich::Genie::LichGameState.new(game_state: state, cached: true)
      expect([cached['roomid'], cached['zoneid'], cached['scriptlist'], cached['zonename']]).to eq(['7', '1', 'none', zone_name])
      expect(cached.stamp('zoneid')).to eq(state.host_stamp('zoneid', :zone, '1'))
    end

    it 'replays the plugin namespaces too ($Time.*, $<Skill>.*): live wins over a stored copy only once read' do
      live = Lich::Genie::LichGameState.new(game_state: state)
      allow(live).to receive_messages(time_available?: true, sun_day: true)
      cached = Lich::Genie::LichGameState.new(game_state: state, cached: true)
      expect([cached['Time.isDay'], cached.authoritative?('Time.isDay')]).to eq([nil, false])
      expect(live['Time.isDay']).to eq('1')
      allow(cached).to receive(:time_available?).and_raise('host read on the display port')
      expect([cached['Time.isDay'], cached.authoritative?('Time.isDay'), cached.authoritative?('scriptlist')]).to eq(['1', true, true])
      stub_const('Lich::DragonRealms::DRSkill', Class.new { define_singleton_method(:getrank) { |skill| skill == 'Small Edged' ? 312 : 0 } })
      allow(live).to receive(:skills_available?).and_return(true)
      expect([cached['Small_Edged.Ranks'], live['Small_Edged.Ranks'], cached['Small_Edged.Ranks']]).to eq([nil, '312', '312'])
    end

    it 'reads the map values on the trigger worker at a room update, from a loaded map only' do
      reads = []
      stub_const('Lich::Common::Map', fake_map(loaded: false) { reads << :current }) # Map.current would load it
      allow(glue).to receive(:variable_broadcast)
      glue.game_state_changed(Lich::Genie::GameState::Row.new(%w[$roomid], []))
      expect([reads, readings['roomid']]).to eq([[], nil])
      stub_const('Lich::Common::Map', fake_map(loaded: true, current: double(genie_id: '42', genie_zone: '1')))
      glue.game_state_changed(Lich::Genie::GameState::Row.new(%w[$health], []))
      expect(readings['roomid']).to be_nil # not a room update
      glue.game_state_changed(Lich::Genie::GameState::Row.new(%w[$roomid], []))
      expect([readings['roomid'], readings['zoneid']]).to eq(%w[42 1])
    end
  end

  # The explicit opt-out the genie spec support sets (support/glue_autoinstall_off.rb): this file's
  # load of the glue put no game-state tap onto Lich's Script (lich.rbw's load would).
  it 'installs nothing onto Lich\'s Script when loaded with Lich::Genie.autoinstall off' do
    expect(Lich::Genie.autoinstall).to be(false)
    expect(Lich::Genie.game_state_feed.installed?(Lich::Common::Script)).to be(false)
  end

  describe '.install_at_lich_load!' do
    it 'installs the game-state tap gated on engine_active?, starting the engine at the first open row' do
      feed = Object.new
      args = {}
      feed.define_singleton_method(:install) { |klass, **kw| args.merge!(klass: klass, **kw) }
      allow(Lich::Genie).to receive(:game_state_feed).and_return(feed)
      allow(Lich::Genie).to receive(:engine_active?).and_return(false, true)
      allow(glue).to receive(:ensure_downstream_hook!)
      glue.install_at_lich_load!
      expect(args[:klass]).to equal(Lich::Common::Script)
      expect([args[:gate].call, args[:gate].call]).to eq([false, true])
      args[:on_open].call
      expect(glue).to have_received(:ensure_downstream_hook!)
    ensure
      glue.instance_variable_set(:@game_state_tap_installed, false)
    end
  end

  # Game.SendText shows no "[script]: text" echo when any gag -- active or
  # not -- matches the sending script's name (Game.cs:481-511 R); the command still goes out.
  describe 'LichGamePort and the send echo gag' do
    let(:filters) { Lich::Genie::StreamFilters.new }
    let(:port) { Lich::Genie::LichGamePort.new }
    let(:calls) { [] }

    before do
      log = calls
      allow(Lich::Genie).to receive(:stream_filters).and_return(filters)
      allow(glue).to receive(:input_broadcast)
      allow(port).to receive(:put) { |text| log << [:put, text] }
      allow(port).to receive(:put_named) { |name, text, echo:| log << [:put_named, name, text, echo] }
    end

    def genie_script(name) = glue.allocate.tap { |s| s.instance_variable_set(:@name, name) }

    it 'sends a gagged script\'s command without the echo, any other through Lich\'s put' do
      filters.add_gag('^hunt', klass: 'off')
      filters.toggle_class('off', false) # inactive still hides the echo
      allow(Lich::Common::Script).to receive(:current_without_pause).and_return(genie_script('hunter'))
      port.send_command('look')
      allow(Lich::Common::Script).to receive(:current_without_pause).and_return(genie_script('sc'))
      port.send_command('smile')
      allow(Lich::Common::Script).to receive(:current_without_pause).and_return(nil)
      port.send_command('bow')
      expect(calls).to eq([[:put_named, 'hunter', 'look', false], [:put, 'smile'], [:put, 'bow']])
    end

    # A hidden echo skips Remix's whole PrintInputText block (Game.cs:515-543 R), so
    # it leaves m_bLastRowWasPrompt alone; the send still sets $lastcommand.
    it 'leaves the prompt flag for a send whose echo a gag hid, clears it for a shown echo' do
      filters.add_gag('^hunt')
      state.feed(%(<prompt time="1700000000">&gt;</prompt>\r\n))
      allow(Lich::Common::Script).to receive(:current_without_pause).and_return(genie_script('hunter'))
      port.send_command('look')
      expect([state.last_row_was_prompt, state['lastcommand']]).to eq([true, 'look'])
      allow(Lich::Common::Script).to receive(:current_without_pause).and_return(genie_script('sc'))
      port.send_command('smile')
      expect([state.last_row_was_prompt, state['lastcommand']]).to eq([false, 'smile'])
    end

    it 'hides a #trigger body\'s send when a gag matches its origin "Trigger" (TriggerAction, FormMain.cs:4647 R)' do
      filters.add_gag('^Trig')
      allow(Lich::Common::Script).to receive(:current_without_pause).and_return(genie_script('sc'))
      Thread.current[Lich::Genie::TriggerRunner::ORIGIN_KEY] = 'Trigger'
      port.send_command('kneel')
      Thread.current[Lich::Genie::TriggerRunner::ORIGIN_KEY] = nil
      port.send_command('stand')
      expect(calls).to eq([[:put_named, 'sc', 'kneel', false], [:put, 'stand']])
    ensure
      Thread.current[Lich::Genie::TriggerRunner::ORIGIN_KEY] = nil
    end
  end

  # The mycommandchar gate (Game.cs:467, 527, 545 R; settings.cfg `mycommandchar`, '/' by
  # default and in the tester's settings.cfg:6). Remix echoes `/spelltimer` but never sends it to the
  # game nor records $lastcommand; trigger-on-input still parses it (FormMain.cs:4391-4422 R).
  # Corpus: 8 tester `put /spelltimer`, uber `/sort`, uberwatch `/restart` (flow case t266).
  describe 'LichGamePort and a mycommandchar text' do
    let(:filters) { Lich::Genie::StreamFilters.new }
    let(:port) { Lich::Genie::LichGamePort.new }
    let(:calls) { [] }
    let(:wire) { [] }

    before do
      log = calls
      sent = wire
      stub_const('Game', Module.new)
      Game.define_singleton_method(:_puts) { |str| sent << str }
      allow(Lich::Genie).to receive(:stream_filters).and_return(filters)
      allow(glue).to receive(:input_broadcast) { |text| log << [:input, text] }
      allow(port).to receive(:put) { |text| log << [:put, text] }
      allow(port).to receive(:do_client) { |text| log << [:do_client, text] }
      allow(port).to receive(:respond) { |text| log << [:respond, text] }
    end

    def genie_script(name, silent: false)
      glue.allocate.tap do |s|
        s.instance_variable_set(:@name, name)
        s.define_singleton_method(:silent) { silent }
      end
    end

    it 'shows the echo, sends nothing, keeps $lastcommand, and still runs trigger-on-input' do
      allow(Lich::Common::Script).to receive(:current_without_pause).and_return(genie_script('caf'))
      port.send_command('look')
      buffer_before = $_CLIENTBUFFER_.dup
      upstream_before = $_LASTUPSTREAM_
      port.send_command('/spelltimer')
      expect(calls).to eq([[:put, 'look'], [:input, 'look'], [:respond, "[caf]>/spelltimer\r\n"], [:input, '/spelltimer']])
      expect([wire, state['lastcommand'], $_CLIENTBUFFER_, $_LASTUPSTREAM_]).to eq([[], 'look', buffer_before, upstream_before])
    end

    it 'never sends it for a queue release either, and honours the owner\'s silent' do
      Thread.current[Lich::Genie::GenieScript::QUEUE_OWNER_KEY] = genie_script('uber')
      port.send_command('/sort name')
      Thread.current[Lich::Genie::GenieScript::QUEUE_OWNER_KEY] = genie_script('quiet', silent: true)
      port.send_command('/sort')
      expect([wire, calls]).to eq([[], [[:respond, "[uber]>/sort name\r\n"], [:input, '/sort name'], [:input, '/sort']]])
    ensure
      Thread.current[Lich::Genie::GenieScript::QUEUE_OWNER_KEY] = nil
    end

    it 'hides the echo when a gag matches the origin, and leaves the prompt flag then' do
      filters.add_gag('^Trig')
      state.feed(%(<prompt time="1700000000">&gt;</prompt>\r\n))
      allow(Lich::Common::Script).to receive(:current_without_pause).and_return(nil)
      Thread.current[Lich::Genie::TriggerRunner::ORIGIN_KEY] = 'Trigger'
      port.send_command('/track clear')
      expect([calls, state.last_row_was_prompt]).to eq([[[:input, '/track clear']], true])
      Thread.current[Lich::Genie::TriggerRunner::ORIGIN_KEY] = nil
      port.send_command('/restart')
      expect([calls.last(2), state.last_row_was_prompt]).to eq([[[:respond, "[(unknown script)]>/restart\r\n"], [:input, '/restart']], false])
    ensure
      Thread.current[Lich::Genie::TriggerRunner::ORIGIN_KEY] = nil
    end

    it 'checks the raw text against the live mycommandchar before the Lich-command route' do
      allow(Lich::Common::Script).to receive(:current_without_pause).and_return(nil)
      port.send_command(' /x') # StartsWith on the raw text: a game command
      state.apply_setting('mycommandchar', ',')
      port.send_command(',go2 12') # Remix behind Lich never hands it to the socket (= Lich) either
      port.send_command('/y')
      expect(calls.reject { |c| c.first == :input }).to eq([[:put, ' /x'], [:respond, "[(unknown script)]>,go2 12\r\n"], [:put, '/y']])
      expect(state['lastcommand']).to eq('/y')
    end

    it 'records no $lastcommand / $lastinput for a typed one, but runs its trigger-on-input' do
      store = Lich::Genie::GlobalStore.new(write_clock: Lich::Genie::WriteClock.new)
      typed_state = Lich::Genie::GameState.new(write_clock: Lich::Genie::WriteClock.new, globals: store)
      feed = Lich::Genie::GameStateFeed.new(game_state: -> { typed_state }, report: ->(e) { raise e })
      inputs = []
      expect(feed.upstream(+'<c>/spelltimer', on_input: ->(text) { inputs << text })).to eq('<c>/spelltimer')
      expect([typed_state['lastcommand'], store.get('lastinput'), inputs]).to eq([nil, nil, ['/spelltimer']])
    end
  end

  # Command_ScriptDebugLevel (FormMain.cs:6083 R) through the host port.
  describe 'LichScriptControl#debug' do
    it 'sets the level on every listed genie script of the name' do
      interp = Struct.new(:debug_level).new(0)
      script = genie_script_double('hunt', interp)
      control = Lich::Genie::LichScriptControl.new
      allow(control).to receive(:scripts_named).with('hunt').and_return([script])
      control.debug(7, 'hunt')
      expect(interp.debug_level).to eq(7)
    end

    def genie_script_double(name, interp)
      glue.allocate.tap do |s|
        s.instance_variable_set(:@name, name)
        s.instance_variable_set(:@genie_interpreter, interp)
      end
    end
  end
end
