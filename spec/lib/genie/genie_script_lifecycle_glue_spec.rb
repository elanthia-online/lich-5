# frozen_string_literal: true

require 'tmpdir'
require 'timeout'
require_relative 'support/example_timeout'
require_relative '../../spec_helper'
require_relative '../../../lib/common/limitedarray'
require_relative '../../../lib/common/feature_flags'
require_relative '../../../lib/common/downstreamhook'
require_relative '../../../lib/common/upstreamhook'
require_relative '../../../lib/genie'
require_relative 'support/glue_autoinstall_off'

# The launch / script-list glue in lib/genie/genie_script.rb on Lich's REAL Script class
# (setup as in genie_script_timing_glue_spec.rb and spec/lib/common/script_lifecycle_spec.rb):
#   * an engine launch starts exactly <scriptdir>/<name>.cmd through Lich's Script.start
#     (GenieScript::ExactLaunchFinder), never Lich's prefix/.lic/custom finder; a missing file
#     prints Remix's script error (FormMain.cs:4678-4714 R; Script.cs:3683-3800 R);
#   * with abortdupescript every LISTED copy is aborted and the new one starts anyway
#     (Lich's own duplicate refusal is bypassed; FormMain.cs:3401-3426 R);
#   * a script's own launch waits for the child's first run (bounded);
#   * self-abort / membership: GenieScript#genie_abort, LichScriptControl walking the listed scripts,
#     the InputBuffer of an unlisted script.
# The script thread's body (run_genie) is replaced by a probe: these examples are about the
# launch and the list, not the interpreter (flow t158-t165 cover the engine side).
module GenieLifecycleGlueSpec
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

RSpec.describe 'Genie glue: launches and the script list' do
  let(:script_class) { Lich::Common::Script }
  let(:glue) { Lich::Genie::GenieScript }
  let(:list) { Lich::Genie::ScriptList.new }
  let(:said) { [] }
  # what each probe thread body saw / waits for, keyed by script name
  let(:gates) { Hash.new { |h, k| h[k] = Thread::Queue.new } }
  let(:started) { Thread::Queue.new }

  before(:context) do
    require_relative '../../../lib/common/script'
    GenieLifecycleGlueSpec.load_quietly(GenieLifecycleGlueSpec::GLUE_FILE)
  end

  after(:context) do
    GenieLifecycleGlueSpec::GLUE_CONSTANTS.each { |name| Lich::Genie.send(:remove_const, name) if Lich::Genie.const_defined?(name, false) }
    %i[SubScript ExecScript WizardScript Script Scripting TRUSTED_SCRIPT_BINDING].each do |const_name|
      Lich::Common.send(:remove_const, const_name) if Lich::Common.const_defined?(const_name, false)
    end
    $LOADED_FEATURES.delete_if { |path| path.end_with?('/lib/common/script.rb') }
  end

  around do |example|
    Dir.mktmpdir('genie-wp7a') do |root|
      FileUtils.mkdir_p(File.join(root, 'custom'))
      @root = root
      example.run
    end
  end

  before do
    @threads_before = Thread.list
    {
      :@@running => [], :@@stopping => [], :@@startup_reservations => {}, :@@startup_generation => 0,
      :@@completed_named_starts => {}, :@@completed_start_waiters => {}, :@@shutdown_started => false,
      :@@loaded_libraries => Set.new, :@@loaded_library_owners => {}, :@@loading_libraries => {},
      :@@reloading_libraries => {}, :@@library_waits => {}
    }.each { |name, value| script_class.class_variable_set(name, value) }
    allow(Lich).to receive(:log)
    allow(Lich::Common::FeatureFlags).to receive(:enabled?).with(:script_kill_metrics).and_return(false)
    allow_any_instance_of(script_class).to receive(:report_errors) { |_script, &block| block.call }
    stub_const('SCRIPT_DIR', @root)
    stub_const('LimitedArray', Lich::Common::LimitedArray) unless Object.const_defined?(:LimitedArray)
    allow(Lich::Genie).to receive(:enabled?).and_return(true)
    # an ExecScript (a `#goto` walk's runner) evaluates its code in Lich's trusted binding, whose
    # `_script` lich.rbw makes reachable (as spec/lib/common/script_lifecycle_spec.rb stubs it)
    allow(Lich::Common::TRUSTED_SCRIPT_BINDING).to receive(:call).and_return(Lich::Common::Scripting.new.script)
    allow(Lich::Genie).to receive(:script_list).and_return(list)
    allow(Lich::Genie).to receive(:abort_dupe_script?).and_return(true)
    log = said
    allow(glue).to receive(:respond) { |text| log << text }
    allow(glue).to receive(:script_list_changed)
    allow_any_instance_of(glue).to receive(:respond)
    # the script thread: register like run_genie, end the first run, then hold until released
    probe_gates = gates
    probe_started = started
    allow_any_instance_of(glue).to receive(:run_genie) do |script|
      list.launched(script)
      probe_started << script
      probe_gates["#{script.name}:first"].pop
      list.run_ended(script)
      probe_gates[script.name].pop
    ensure
      list.finished(script)
    end
  end

  after do
    gates.each_value { |gate| 3.times { gate << :go } }
    script_class.list.each { |script| script.kill(context: :shutdown) if script.running? }
    script_class.class_variable_set(:@@running, [])
    script_class.class_variable_set(:@@stopping, [])
    join_example_threads
  end

  # A script thread released or killed by the teardown above ends on its
  # own schedule -- the REAL run_genie's ensure (and a walk's tick end) then raises
  # script_list_changed. Unjoined, under load that call landed in the NEXT example, whose
  # class-level stub counted it ("received: 2 times" at the script's-end example). Every thread
  # the example started (Timeout's long-lived helper aside) ends here, while this example's stubs
  # still catch its calls; one that does not is a leak and fails this example.
  def join_example_threads
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
    (Thread.list - @threads_before).each do |thread|
      next if thread.name == 'Timeout stdlib thread'

      wait_for_end(thread, deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC))
      raise "thread outlived its example: #{thread.inspect}" if thread.alive?
    end
  end

  # Thread#join re-raises what ended the thread; how it ended is not this barrier's business.
  def wait_for_end(thread, seconds)
    thread.join([seconds, 0].max)
  rescue Exception # rubocop:disable Lint/RescueException
    nil
  end

  def write(name, text = "echo hi\n")
    File.write(File.join(@root, name), text)
  end

  def first_run_done(name)
    gates["#{name}:first"] << :go
  end

  def until_listed(script)
    Timeout.timeout(5) { Thread.pass until list.listed?(script) }
  end

  describe 'exact <name>.cmd' do
    it 'starts the .cmd itself where Lich\'s finder would pick custom/<name>.lic or a prefix match' do
      write('custom/hunt.lic', "# quiet\nnil\nDone:\nnil\n")
      write('hunt.cmd')
      write('hunter.cmd')
      script = glue.launch('hunt', 'a "b c"')
      expect(script).to be_a(glue)
      expect([script.name, script.genie_file_name, script.genie_args, File.basename(script.file_name)])
        .to eq(['hunt', 'hunt.cmd', ['a', 'b c'], 'hunt.cmd'])
      expect(Timeout.timeout(5) { started.pop }).to be(script)
    end

    it 'loads `.name.cmd` and a name spelled in another case, naming the script by the lowercased launch' do
      write('Helper.cmd')
      first = glue.launch('helper.cmd', 'x')
      second = glue.launch('helper', 'y')
      expect([first&.name, second&.name, second&.genie_args]).to eq(%w[helper helper] + [['y']])
    end

    it 'prints Remix\'s script error and starts nothing for a missing, prefix-only or empty file' do
      write('hunter.cmd')
      write('empty.cmd', '')
      expect([glue.launch('hunt', ''), glue.launch('', 'x'), glue.launch('empty', '')]).to eq([nil, nil, nil])
      expect(said).to eq(['[Script error: File not found: hunt.cmd]', '[Script error: File not found: .cmd]',
                          '[Script error: Unable to load file: empty.cmd]'])
      expect(script_class.running).to be_empty
    end

    it 'leaves Lich\'s own finder alone outside an engine launch (a typed `;name`)' do
      write('custom/hunt.lic', "# quiet\nnil\nDone:\nnil\n")
      write('hunt.cmd')
      write('other.cmd')
      glue.launch('other', '') # installs the finder override
      lich = script_class.start('hunt')
      expect(lich).not_to be_a(glue)
      expect(lich&.file_name).to end_with('custom/hunt.lic')
    end

    it 'raises ParseArgs\' error for a malformed argument string before anything starts' do
      write('hunt.cmd')
      expect { glue.launch('hunt', 'a "') }.to raise_error(Lich::Genie::Error, /Invalid string in Parse Arguments/)
      expect(script_class.running).to be_empty
    end

    it 'drops the pending entry of a script Lich built but never started' do
      write('hunt.cmd')
      allow(script_class).to receive(:start) { glue.new(File.join(@root, 'hunt.cmd')) && nil }
      expect(glue.launch('hunt', '')).to be_nil
      expect(list.launch_depth(nil)).to eq(1)
      expect(list.listed).to eq([])
      expect(list.wait_first_run(Object.new, timeout: 0)).to be(true)
    end
  end

  describe 'a relaunch replaces the listed copy (abortdupescript)' do
    it 'aborts the listed copy and still starts the new one (no Lich "already running" refusal)' do
      write('hunt.cmd')
      old = glue.launch('hunt', 'one')
      first_run_done('hunt')
      until_listed(old)
      expect(list.value).to eq('hunt')
      fresh = glue.launch('hunt', 'two')
      expect(fresh).to be_a(glue)
      expect(fresh).not_to be(old)
      # off a script thread the abort's list change is stored and raised at once (the new copy
      # is still in its first run)
      expect(list.value).to eq('none')
      expect(glue).to have_received(:script_list_changed).with(no_args).once
      expect(old.join(5)).to be_truthy # killed: Lich's kill from another thread
      expect([list.listed?(old), fresh.genie_args, said.grep(/already running/)]).to eq([false, ['two'], []])
    end

    it 'does not walk a copy still in its first run, and keeps both without abortdupescript' do
      write('hunt.cmd')
      pending = glue.launch('hunt', 'a')
      second = glue.launch('hunt', 'b')
      expect([pending.running?, second.running?]).to eq([true, true])
      allow(Lich::Genie).to receive(:abort_dupe_script?).and_return(false)
      2.times { first_run_done('hunt') }
      Timeout.timeout(5) { Thread.pass until list.listed.size == 2 }
      third = glue.launch('hunt', 'c')
      expect([pending.running?, second.running?, third.running?]).to eq([true, true, true])
    end

    it 'aborts the listed copy even when the new file is gone (LoadScript aborts before LoadFile)' do
      write('hunt.cmd')
      old = glue.launch('hunt', '')
      first_run_done('hunt')
      until_listed(old)
      File.delete(File.join(@root, 'hunt.cmd'))
      expect(glue.launch('hunt', '')).to be_nil
      expect(old.join(5)).to be_truthy
      # Remix: AbortScript's line for the old copy first (FormMain.cs:3403-3416 R), then the error
      # (this probe thread never builds an interpreter: the glue prints the line, run time 0.00)
      expect(said).to eq(['[Script aborted! (Run time: 0.00 seconds): hunt.cmd]', '[Script error: File not found: hunt.cmd]'])
    end
  end

  describe 'a script\'s own launch waits for the child\'s first run' do
    it 'returns only once the child\'s first run is over' do
      write('child.cmd')
      parent = glue.new(File.join(@root, 'child.cmd')) # any genie script as the launcher
      launcher = Thread.new { glue.launch('child', '', launcher: parent) }
      child = Timeout.timeout(5) { started.pop }
      Timeout.timeout(5) { Thread.pass until launcher.status == 'sleep' }
      expect([launcher.alive?, list.frozen?(child)]).to eq([true, false])
      first_run_done('child')
      expect(launcher.join(5)&.value).to be(child)
      expect([list.frozen?(child), list.listed?(child)]).to eq([true, false]) # listed at the parent's run end
      list.run_ended(parent)
      expect(list.listed?(child)).to be(true)
    end

    it 'gives up after FIRST_RUN_WAIT_SECONDS, and a host launch (no launcher) never waits' do
      write('child.cmd')
      stub_const('Lich::Genie::GenieScript::FIRST_RUN_WAIT_SECONDS', 0.05)
      parent = glue.new(File.join(@root, 'child.cmd'))
      expect(glue.launch('child', '', launcher: parent)).to be_a(glue)
      write('other.cmd')
      expect(glue.host_launch('other', '')).to be_a(glue)
      expect(list.listed).to eq([])
    end

    it 'refuses a first run nested past the limit with a script error' do
      write('deep.cmd')
      chain = [glue.new(File.join(@root, 'deep.cmd'))]
      list.launched(chain.first)
      (Lich::Genie::ScriptList::LIMIT - 1).times do
        nxt = glue.new(File.join(@root, 'deep.cmd'))
        list.launched(nxt, launcher: chain.last)
        chain << nxt
      end
      expect(glue.launch('deep', '', launcher: chain.last)).to be_nil
      expect(said).to eq(["[Script error: maximum nested dispatch depth (#{Lich::Genie::ScriptList::LIMIT}) exceeded on: .deep.cmd]"])
    end
  end

  describe 'GenieScript' do
    def built(name)
      write("#{name}.cmd")
      glue.new(File.join(@root, "#{name}.cmd"))
    end

    def listed(name)
      built(name).tap do |script|
        list.launched(script)
        list.run_ended(script)
        script.downstream_buffer.clear
      end
    end

    it 'names a Lich-typed script by its lowercased file name, all dots kept (Remix FileName / %scriptname)' do
      write('MC.Pound.cmd')
      script = glue.new(File.join(@root, 'MC.Pound.cmd'), 'a_b')
      expect([script.name, script.genie_file_name, script.genie_args]).to eq(['mc.pound', 'mc.pound.cmd', ['a b']])
    end

    # GenieScript skips Script#initialize (it reads no Ruby labels), so it must set every ivar
    # Lich's lifecycle reads itself; a Lich update adding one fails here, not live.
    it 'has every instance variable Lich\'s Script#initialize sets, with the same values where both are plain' do
      # a custom/ file: Lich's own @custom regex needs a match outside its NilClass patch
      write('custom/plain.lic', "# quiet\nnil\nDone:\nnil\n")
      lich = script_class.new(file: File.join(@root, 'custom', 'plain.lic'), args: '', publish: false)
      genie = built('plain')
      expect(genie.instance_variables).to include(*lich.instance_variables)
      %i[@watchfor @killed_externally @kill_source @kill_requested @cleanup_started @completed_successfully @ignore_pause
         @paused @hidden @silent].each do |ivar|
        expect(genie.instance_variable_get(ivar)).to eq(lich.instance_variable_get(ivar)), ivar.to_s
      end
      write('custom/mine.cmd')
      expect([glue.new(File.join(@root, 'custom', 'mine.cmd')).custom?, genie.custom?]).to eq([true, false])
    end

    it 'drops everything for an unlisted script, a roundtime too, and keeps it once listed' do
      script = built('hunt')
      script.downstream_buffer.push('line', Lich::Genie::GameEvents::RoundTimeEnd.new(1.0))
      expect(script.downstream_buffer.to_a).to eq([])
      list.launched(script)
      list.run_ended(script)
      expect(script.downstream_buffer.to_a).to eq([Lich::Genie::GameEvents::RESUMED]) # the wake-up
      script.downstream_buffer.push('kept')
      expect(script.downstream_buffer.to_a.last).to eq('kept')
    end

    # `#goto` returns at once; the walk runs in a hidden Lich script of its own
    # (Remix's automapper.cmd is its own script, and DRCT.walk_to's DRC
    # helpers need a calling script), as "automapper" in the genie list, and ends with
    # automapper.cmd's result lines `#parse`d (AutoMapper.cs:1140-1205, 1595-1609 R). A stop kills
    # that script and the scripts its walk started -- never anyone else's go2.
    describe '#goto (GotoWalk through the glue)' do
      let(:store) { Lich::Genie::GlobalStore.new(file: nil) }
      let(:parses) { [] }
      # each item: a proc the stubbed DRCT.walk_to runs on the walk's thread (its result arrives)
      let(:walk_gate) { Thread::Queue.new }
      let(:walks) { Thread::Queue.new }

      before do
        allow(Lich::Genie).to receive(:global_store).and_return(store)
        log = parses
        allow(glue).to receive(:parse_broadcast) { |text| log << text }
        allow(glue).to receive(:variable_broadcast)
        allow(glue).to receive(:resolve_genie_room) { |arg| arg == '12' ? 512 : nil }
        allow(glue).to receive(:current_room_id).and_return(100)
        gate = walk_gate
        seen = walks
        # Lich's DRC helpers resolve their caller through Script.current ("Unable to identify
        # calling script" without one); DRCT.walk_to calls them before and while go2 walks.
        drc = Module.new
        drc.define_singleton_method(:fix_standing) { Lich::Common::Script.current }
        drc.define_singleton_method(:bput) { |*_args| Lich::Common::Script.current&.name.to_s }
        stub_const('Lich::DragonRealms::DRC', drc)
        drct = Module.new
        drct.define_singleton_method(:walk_to) do |target, restart|
          caller_script = drc.fix_standing
          seen << { target: target, restart: restart, script: caller_script, bput: drc.bput('open door', 'You open'),
                    own_group: caller_script&.__send__(:__owns_public_thread_group?, Thread.current.group) }
          gate.pop.call
        end
        stub_const('Lich::DragonRealms::DRCT', drct)
      end

      def next_walk
        Timeout.timeout(5) { walks.pop }
      end

      def until_gone(script)
        Timeout.timeout(5) { Thread.pass while script.running? }
      end

      it 'returns at once, walks in a hidden quiet Lich script of its own and parses ARRIVED from it' do
        walker = listed('walker')
        handle = walker.send(:genie_goto, '12')
        expect(handle).to be_a(Lich::Genie::GotoWalk::Handle)
        expect([parses, store.get('destination'), said]).to eq([['DESTINATION FOUND'], '12', ['#goto 12']])
        walk = next_walk
        runner = walk[:script]
        expect([walk[:target], walk[:restart], runner.class, runner.name, runner.hidden, runner.quiet])
          .to eq([512, false, Lich::Common::ExecScript, 'automapper1', true, true])
        # DRC's helpers see the walk script as their caller, and its thread is in that
        # script's ThreadGroup from the start (never the walker's, nor Default)
        expect(walk[:bput]).to eq('automapper1')
        expect(walk[:own_group]).to be(true)
        expect(list.listed?(handle)).to be(false) # launched in the walker's run: listed at its end
        walker.genie_run_ended
        expect(list.listed.map(&:genie_file_name)).to eq(%w[walker.cmd automapper.cmd])
        walk_gate << -> { true }
        Timeout.timeout(5) { Thread.pass while list.listed?(handle) }
        until_gone(runner)
        expect(parses).to eq(['DESTINATION FOUND', 'YOU HAVE ARRIVED!', 'AUTOMAPPER: YOU HAVE ARRIVED!'])
      end

      it 'stops only what the walk started -- its script and its go2 -- while a go2 started by anyone else runs on' do
        write('go2.cmd')
        foreign = script_class.start('go2', '', { force: true }) # the user's, or a .lic's DRCT.walk_to
        expect(Timeout.timeout(5) { started.pop }).to equal(foreign)
        walker = listed('walker')
        handle = walker.send(:genie_goto, '12')
        walker.genie_run_ended
        runner = next_walk[:script]
        walk_gate << lambda {
          script_class.start('go2', '512', { force: true }) # DRCT.walk_to's own go2
          sleep # walking until stopped
        }
        own = Timeout.timeout(5) { started.pop }
        expect(own).not_to equal(foreign)
        Lich::Genie::LichScriptControl.new.abort('automapper')
        until_gone(runner)
        until_gone(own)
        Timeout.timeout(5) { Thread.pass while list.listed?(handle) } # the killed walk's ensure
        expect([foreign.running?, handle.aborted?, parses]).to eq([true, true, ['DESTINATION FOUND']])
      end

      it 'stops the walk with `#script abort automapper`, no result line, and replaces it on a second #goto' do
        walker = listed('walker')
        first = walker.send(:genie_goto, '12')
        walker.genie_run_ended
        first_runner = next_walk[:script]
        second = walker.send(:genie_goto, '12') # abortdupescript: the listed walk is aborted
        expect(first.aborted?).to be(true)
        until_gone(first_runner)
        walker.genie_run_ended
        second_runner = next_walk[:script]
        Lich::Genie::LichScriptControl.new.abort('automapper')
        expect(second.aborted?).to be(true)
        until_gone(second_runner)
        Timeout.timeout(5) { Thread.pass while list.listed?(second) }
        expect(parses).to eq(['DESTINATION FOUND'] * 2)
      end

      # A #trigger on "YOU HAVE ARRIVED!" that runs `#goto` runs on the walk
      # script's own thread; the dupe check aborts that walk without a Lich kill of the very thread
      # running the trigger body.
      it 'replaces the walk from a #trigger on its own result line without killing the walk script mid-trigger' do
        chained = []
        log = parses
        allow(glue).to receive(:parse_broadcast) do |text|
          log << text
          chained << glue.goto('12') if text == 'YOU HAVE ARRIVED!' && chained.empty?
          log << 'trigger body went on' if text == 'YOU HAVE ARRIVED!'
        end
        walker = listed('walker')
        first = walker.send(:genie_goto, '12')
        walker.genie_run_ended
        first_runner = next_walk[:script]
        kills = [] # what had been parsed when the first walk script was asked to stop
        allow(first_runner).to receive(:kill).and_wrap_original do |original, *args, **opts|
          kills << log.dup
          original.call(*args, **opts)
        end
        walk_gate << -> { true }
        second_runner = next_walk[:script]
        until_gone(first_runner)
        # never from inside the trigger body: only Lich's own end-of-script kill, after it
        expect(kills.map(&:last).uniq).to eq(['trigger body went on'])
        expect(parses).to eq(['DESTINATION FOUND', 'YOU HAVE ARRIVED!', 'DESTINATION FOUND', 'trigger body went on'])
        expect([first.aborted?, list.listed.last]).to eq([true, chained.first])
        walk_gate << -> { false }
        until_gone(second_runner)
        expect(parses.last(2)).to eq(['MOVE FAILED', 'AUTOMAPPER: MOVEMENT FAILED!'])
      end

      # A Lich `;kill automapper1` (or any kill of the walk script that
      # is not the walk's own stop) ends the walk thread; its go2 must not walk on, unowned.
      it 'kills the go2 its walk started when the walk script is killed by Lich itself (;kill automapper1)' do
        write('go2.cmd')
        handle = glue.goto('12')
        runner = next_walk[:script]
        walk_gate << lambda {
          script_class.start('go2', '512', { force: true }) # DRCT.walk_to's own go2
          sleep # walking until stopped
        }
        go2 = Timeout.timeout(5) { started.pop }
        script_class.kill(runner.name)
        until_gone(runner)
        until_gone(go2)
        Timeout.timeout(5) { Thread.pass while list.listed?(handle) }
        expect([go2.running?, parses]).to eq([false, ['DESTINATION FOUND']])
      end

      # Hidden from the walk's first statement, not only once spawn_walk's
      # caller gets the script back (the walk thread may run first).
      it 'is hidden before its body starts walking' do
        allow(Lich::Common::ExecScript).to receive(:start).and_wrap_original do |original, *args, **opts|
          script = original.call(*args, **opts)
          walks << next_walk # the body is already walking before spawn_walk goes on
          script
        end
        seen = []
        drct = Lich::DragonRealms::DRCT
        gate = walk_gate
        q = walks
        drct.define_singleton_method(:walk_to) do |target, _restart|
          me = Lich::Common::Script.current
          seen << me.hidden
          q << { target: target, script: me }
          gate.pop.call
        end
        glue.goto('12')
        runner = next_walk[:script]
        expect(seen).to eq([true])
        walk_gate << -> { true }
        until_gone(runner)
      end

      # A walk script killed before run_walk took its runner (from its registry) leaves the
      # runner behind; the next spawn drops it, and keeps one whose script still runs.
      it 'drops the runner of a walk script that died before taking it, on the next spawn' do
        klass = Lich::Genie::GenieScript
        dead = klass::WalkRunner.new(-> {})
        dead.script = instance_double(Lich::Common::Script, running?: false)
        live = klass::WalkRunner.new(-> {})
        live.script = instance_double(Lich::Common::Script, running?: true)
        klass.instance_variable_set(:@walk_runners, { 901 => dead, 902 => live })
        allow(Lich::Common::ExecScript).to receive(:start).and_return(nil) # Lich started nothing
        expect(klass.send(:spawn_walk) {}).to be_nil
        expect(klass.instance_variable_get(:@walk_runners)).to eq({ 902 => live })
      ensure
        klass.instance_variable_set(:@walk_runners, {})
      end

      # The tracking slot is the walk's only while DRCT.walk_to runs.
      it 'clears the walk-tracking slot after DRCT.walk_to returns and after it raises' do
        key = Lich::Genie::GenieScript::WALK_TRACK_KEY
        runner = Lich::Genie::GenieScript::WalkRunner.new(-> {})
        during = []
        drct = Lich::DragonRealms::DRCT
        drct.define_singleton_method(:walk_to) do |_target, _restart|
          during << Thread.current[key]
          raise 'lost' if during.length == 2

          true
        end
        after = Thread.new do
          Thread.current[Lich::Genie::GenieScript::WALK_RUNNER_KEY] = runner
          [glue.walk_to(512), Thread.current[key], glue.walk_to(512), Thread.current[key]]
        end.value
        expect(during.map { |slot| slot.equal?(runner) }).to eq([true, true])
        expect(after).to eq([true, nil, false, nil])
        expect(said).to eq(['--- Lich: genie #goto error: lost'])
      end

      # A script a #trigger body starts while the walk's DRCT.walk_to
      # prints a Lich line (the script-output feed runs the #triggers on that thread) is the
      # trigger's, not the walk's: a stop of the walk leaves it running.
      it 'does not record as the walk\'s a script a #trigger body starts from the script-output feed' do
        write('foo.cmd')
        launched = []
        allow(Lich::Genie::ParseDispatch).to receive(:feed_output) { launched << script_class.start('foo', '', { force: true }) }
        allow(Lich::Genie).to receive(:triggers).and_return(Lich::Genie::Triggers.new)
        allow(glue).to receive_messages(note_printed: nil, trigger_runner: Object.new)
        handle = glue.goto('12')
        runner_script = next_walk[:script]
        walk_gate << lambda {
          glue.feed_script_output('DRCT: a Lich line') # the #trigger on it runs `.foo`
          sleep
        }
        foo = Timeout.timeout(5) { started.pop }
        expect(launched).to eq([foo])
        expect(handle.instance_variable_get(:@runner).started).to eq([])
        Lich::Genie::LichScriptControl.new.abort('automapper')
        until_gone(runner_script)
        expect(foo.running?).to be(true)
      end

      it 'echoes Remix\'s not-found line, sets $destination 0 and parses DESTINATION NOT FOUND for an unknown room' do
        walker = listed('walker')
        expect(walker.send(:genie_goto, '13')).to be_nil
        expect([parses, store.get('destination'), said])
          .to eq([['DESTINATION NOT FOUND'], '0', ['[AutoMapper] Destination ID #13 not found - your current location is unknown.']])
      end
    end

    # `#goto` room resolution (a decided divergence): a known zone finds only its own node (Remix's
    # m_Nodes.Find on the loaded zone map, AutoMapper.cs:1176-1192 R); the Lich-id / uid fallback
    # stays only for an unstamped (or unknown) current room.
    describe '.resolve_genie_room' do
      let(:rooms) { { 123 => :lich_room_123, 9999 => :here } }

      def map(current:, nodes: {}, uids: {})
        known = rooms
        Class.new do
          define_singleton_method(:current) { current }
          define_singleton_method(:by_genie_ref) { |zone, node| nodes[[zone, node]] }
          define_singleton_method(:list) { known }
          define_singleton_method(:ids_from_uid) { |uid| uids.fetch(uid, []) }
        end
      end

      it 'finds a node of the current zone, and nothing else there: not a Lich room id, not a uid' do
        node = Struct.new(:id).new(4321)
        stub_const('Lich::Common::Map', map(current: double(genie_zone: '1', id: 9999), nodes: { %w[1 7] => node },
                                            uids: { 123_456 => [77] }))
        expect(%w[7 123 9999 123456 bank].map { |arg| glue.resolve_genie_room(arg) }).to eq([4321, nil, nil, nil, nil])
      end

      it 'tries a Lich room id, then a game uid, when the current room carries no Genie stamp or is unknown' do
        [double(genie_zone: nil, id: 9999), double(genie_zone: '', id: 9999), nil].each do |current|
          stub_const('Lich::Common::Map', map(current: current, uids: { 555 => [88, 89] }))
          expect(%w[123 555 777 bank].map { |arg| glue.resolve_genie_room(arg) }).to eq([123, 88, nil, nil]), current.inspect
        end
      end
    end

    # The run end raises the "scriptlist" change for the script itself
    # too (queue_owner), only when it stored a value.
    it 'raises the scriptlist change queued for itself at a run end that stored a value, and only then' do
      parent = built('parent')
      list.launched(parent)
      parent.genie_run_ended # listed: stored
      expect(glue).to have_received(:script_list_changed).with(queue_owner: true).once
      kid = built('kid')
      list.launched(kid, launcher: parent)
      kid.genie_run_ended # nested in the parent's run: no tick end (flow t170)
      parent.genie_run_ended # its run end lists the kid: stored
      parent.genie_run_ended # nothing changed since: not stored
      expect(glue).to have_received(:script_list_changed).with(queue_owner: true).twice
      expect(list.value).to eq('parent|kid')
    end

    it 'aborts on its own thread without a Lich kill, and kills from any other thread' do
      own = listed('own')
      interp = Object.new.tap do |o|
        o.define_singleton_method(:abort_script) { @aborted = true }
        o.define_singleton_method(:abort_announced?) { true }
      end
      own.instance_variable_set(:@genie_interpreter, interp)
      allow(script_class).to receive(:current_without_pause).and_return(own)
      expect(own).not_to receive(:kill)
      own.genie_abort
      expect([interp.instance_variable_get(:@aborted), list.listed?(own)]).to eq([true, false])

      other = listed('other')
      allow(script_class).to receive(:current_without_pause).and_return(nil)
      expect(other).to receive(:kill)
      other.genie_abort
      expect(list.listed?(other)).to be(false)
    end

    # Remix prints "[Script aborted! ...]" (Script.cs:1143-1158 R)
    # as a script print (no trigger parse, FormMain.cs:5611-5618 R); the old kill set
    # killed_externally, so Lich printed "--- Lich: x was killed. (.../genie_script.rb:231:in
    # 'genie_abort')", which reached matchwait and the #triggers (5 tester files match `^--- Lich:`).
    describe 'the stop notice of an engine abort' do
      def with_interpreter(script, source, run: false)
        printed = []
        interp = Lich::Genie::Engine.build(source, name: script.name, file_name: "#{script.name}.cmd",
                                                   print: ->(text, kind) { printed << [kind, text] }, clock: -> { 0.0 })
        interp.run if run
        script.instance_variable_set(:@genie_interpreter, interp)
        printed
      end

      it "prints Remix's abort line, kills without killed_externally and makes the script quiet" do
        victim = listed('victim')
        printed = with_interpreter(victim, "waitfor never\n")
        allow(script_class).to receive(:current_without_pause).and_return(nil)
        expect(victim).to receive(:kill)
        victim.genie_abort
        expect([printed, victim.killed_externally, victim.quiet])
          .to eq([[[:text, '[Script aborted! (Run time: 0.00 seconds): victim.cmd]']], false, true])
      end

      # An abort that lands before the script thread built the interpreter: Remix's LoadFile and
      # RunScript run in one go on the launching thread (m_oScriptStart set at the load,
      # Script.cs:1996 R), so it would print the line, run time 0.00 -- the glue prints it, once.
      it "prints Remix's line itself when the interpreter is not built yet, once, and is quiet" do
        early = listed('early')
        allow(script_class).to receive(:current_without_pause).and_return(nil)
        allow(early).to receive(:kill)
        early.genie_abort
        printed = with_interpreter(early, "waitfor never\n") # the script thread builds it afterwards
        early.genie_abort # a second abort: the line is out already, the late interpreter prints none
        expect([said, printed, early.quiet, early.killed_externally])
          .to eq([['[Script aborted! (Run time: 0.00 seconds): early.cmd]'], [], true, false])
      end

      it 'stays quiet when the interpreter appears between the early line and the notice check' do
        late = listed('late')
        allow(script_class).to receive(:current_without_pause).and_return(nil)
        allow(late).to receive(:kill)
        printed = nil
        log = said
        allow(glue).to receive(:respond) do |text|
          log << text
          printed = with_interpreter(late, "waitfor never\n") # the script thread, mid-abort
        end
        late.genie_abort
        expect([said.size, printed, late.quiet]).to eq([1, [], true])
      end

      it 'chooses and claims under its lock: an abort blocked behind a claim made meanwhile prints nothing' do
        racing = listed('racing')
        allow(script_class).to receive(:current_without_pause).and_return(nil)
        allow(racing).to receive(:kill)
        lock = Object.instance_method(:instance_variable_get).bind_call(racing, :@abort_mutex) # Script hides ivars
        lock.lock
        racer = Thread.new { racing.genie_abort }
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
        Thread.pass until racer.status == 'sleep' || !racer.alive? || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        blocked = racer.status == 'sleep'
        racing.instance_variable_set(:@genie_early_abort, true) # the other abort's claim, under the lock
        lock.unlock
        racer.join(5)
        expect([blocked, said, racing.quiet]).to eq([true, [], true])
      end

      it 'keeps Lich\'s notice for a script that had already finished (Remix prints nothing then)' do
        done = listed('done')
        printed = with_interpreter(done, "echo hi\n", run: true)
        allow(script_class).to receive(:current_without_pause).and_return(nil)
        allow(done).to receive(:kill)
        done.genie_abort
        expect([printed, done.killed_externally, done.quiet]).to eq([[], false, false])
      end

      it 'is quiet after a script-error abort that announced itself, not after a normal end' do
        failed = built('failed')
        allow(failed).to receive(:run_genie).and_call_original # the real ensure (the before block stubs it)
        allow(failed).to receive(:run_genie_interpreter) { with_interpreter(failed, "goto nowhere\n", run: true) }
        failed.run_genie
        ok = built('ok')
        allow(ok).to receive(:run_genie).and_call_original
        allow(ok).to receive(:run_genie_interpreter) { with_interpreter(ok, "echo fine\n", run: true) }
        ok.run_genie
        expect([failed.quiet, ok.quiet]).to eq([true, false])
      end
    end
  end

  describe 'LichScriptControl (walks the listed genie scripts only)' do
    let(:control) { Lich::Genie::LichScriptControl.new }

    def genie(name, listed:)
      write("#{name}.cmd")
      glue.new(File.join(@root, "#{name}.cmd")).tap do |script|
        list.launched(script)
        list.run_ended(script) if listed
      end
    end

    it 'names, aborts and pauses only listed scripts, by exact name, every match' do
      a1 = genie('dup', listed: true)
      a2 = genie('dup', listed: true)
      fresh = genie('fresh', listed: false)
      expect(control.names).to eq(%w[dup dup])
      [a1, a2, fresh].each { |s| allow(s).to receive(:genie_abort) }
      control.abort('fresh')
      control.abort('DUP')
      expect(fresh).not_to have_received(:genie_abort)
      expect(a1).not_to have_received(:genie_abort)
      control.abort('dup')
      expect([a1, a2]).to all(have_received(:genie_abort))
      control.pause('fresh')
      expect(fresh.paused?).to be(false)
    end

    it 'stores a status change in $scriptlist at once off a script thread' do
      genie('hunt', listed: true)
      control.pause('hunt')
      expect(glue).to have_received(:script_list_changed)
      expect(list.value).to eq('hunt')
    end

    it 'reloads a listed script with its own launch arguments' do
      write('hunt.cmd')
      old = glue.new(File.join(@root, 'hunt.cmd'), 'x y')
      list.launched(old)
      list.run_ended(old)
      allow(old).to receive(:genie_abort)
      allow(glue).to receive(:start_request)
      control.reload('hunt')
      expect(old).to have_received(:genie_abort)
      expect(glue).to have_received(:start_request) do |request|
        expect([request.file_name, request.args]).to eq(['hunt.cmd', %w[x y]])
      end
    end
  end

  # The production run end and teardown on the REAL run_genie (only the interpreter body is a
  # probe): LichInputPort#next_line is the one place a running script's run ends for the list,
  # and run_genie's ensure the one place a killed script leaves it.
  describe 'the run end and the teardown of a real run_genie' do
    def bodies(map)
      allow_any_instance_of(glue).to receive(:run_genie).and_call_original
      allow_any_instance_of(glue).to receive(:run_genie_interpreter) { |script, _list| map.fetch(script.name).call(script) }
    end

    before { stub_const('Lich::Genie::GenieScript::FIRST_RUN_WAIT_SECONDS', 60) } # a missed run end holds the launcher

    it 'ends the first run at the first LichInputPort read: the launcher goes on, the list holds the child for it' do
      write('child.cmd')
      parent = glue.new(File.join(@root, 'child.cmd'))
      seen = Thread::Queue.new
      bodies('child' => lambda do |script|
        Lich::Genie::LichInputPort.new(script).next_line(timeout: 0)
        seen << [list.frozen?(script), list.listed?(script)]
        gates['child:end'].pop
      end)
      launcher = Thread.new { glue.launch('child', '', launcher: parent) }
      expect(Timeout.timeout(5) { seen.pop }).to eq([true, false])
      child = launcher.join(5)&.value
      expect(child).to be_a(glue)
      list.run_ended(parent)
      expect(list.listed?(child)).to be(true)
    end

    # run_genie's own registration is the only one a Lich-typed `;name`
    # gets (no engine launch, no LAUNCH_KEY): without it the script is never listed, never gets a
    # game line and `#script` never sees it.
    it 'registers a Lich-typed `;name` itself: listed at its first run end, gets game lines, named by #script' do
      write('hunt.cmd')
      seen = Thread::Queue.new
      bodies('hunt' => lambda do |script|
        Lich::Genie::LichInputPort.new(script).next_line(timeout: 0)
        script.downstream_buffer.clear
        script.downstream_buffer.push('a game line')
        seen << [list.listed?(script), script.downstream_buffer.to_a, Lich::Genie::LichScriptControl.new.names]
        gates['hunt:end'].pop
      end)
      expect(Thread.current[glue::LAUNCH_KEY]).to be_nil
      hunt = script_class.start('hunt')
      expect(hunt).to be_a(glue)
      expect(Timeout.timeout(5) { seen.pop }).to eq([true, ['a game line'], ['hunt']])
    end

    # The script's end is a tick end whose change run_genie raises.
    it 'stores and raises the scriptlist change at the script\'s end' do
      write('hunt.cmd')
      bodies('hunt' => ->(_script) {})
      hunt = script_class.start('hunt')
      expect(hunt.join(5)).to be_truthy
      expect(glue).to have_received(:script_list_changed).with(no_args).once
      expect([list.listed, list.launch_depth(hunt)]).to eq([[], 1])
    end

    it 'leaves no pending entry when Lich kills the script in its first run, and the launcher returns' do
      write('child.cmd')
      parent = glue.new(File.join(@root, 'child.cmd'))
      inside = Thread::Queue.new
      bodies('child' => lambda do |script|
        inside << script
        gates['child:never'].pop
      end)
      launcher = Thread.new { glue.launch('child', '', launcher: parent) }
      child = Timeout.timeout(5) { inside.pop }
      script_class.kill('child')
      expect(launcher.join(5)&.value).to be(child)
      expect([list.wait_first_run(child, timeout: 0), list.launch_depth(child), list.listed?(child)]).to eq([true, 1, false])
    end
  end

  # The launch window's safety lines, each alone.
  describe 'the launch window (LAUNCH_KEY)' do
    it 'is closed again after a launch whose Lich start returns nil or raises' do
      write('hunt.cmd')
      allow(script_class).to receive(:start).and_return(nil)
      expect(glue.launch('hunt', '')).to be_nil
      expect(Thread.current[glue::LAUNCH_KEY]).to be_nil
      allow(script_class).to receive(:start).and_raise(RuntimeError, 'boom')
      expect { glue.launch('hunt', '') }.to raise_error(RuntimeError, 'boom')
      expect(Thread.current[glue::LAUNCH_KEY]).to be_nil
    end

    it 'drops the pending entry of a script Lich built when its start then raises' do
      write('hunt.cmd')
      built = []
      allow(script_class).to receive(:start) do
        built << glue.new(File.join(@root, 'hunt.cmd'))
        raise 'boom'
      end
      expect { glue.launch('hunt', '') }.to raise_error(RuntimeError, 'boom')
      expect([list.wait_first_run(built.first, timeout: 0), list.launch_depth(built.first)]).to eq([true, 1])
    end

    it 'gives the launch only to the launched file and the launched name: other builds and lookups inside the window are Lich\'s' do
      write('hunt.cmd')
      write('other.cmd')
      write('custom/other.lic', "# quiet\nnil\nDone:\nnil\n")
      inner = []
      allow(script_class).to receive(:start).and_wrap_original do |original, *args|
        inner << glue.new(File.join(@root, 'other.cmd'))
        inner << script_class.send(:__find_script_file, 'other')
        original.call(*args)
      end
      script = glue.launch('hunt', 'a')
      other, found = inner
      expect([other.genie_file_name, other.genie_args, list.launch_depth(other)]).to eq(['other.cmd', [], 1])
      expect(found).to eq('/custom/other.lic')
      expect([script.genie_file_name, script.genie_args]).to eq(['hunt.cmd', ['a']])
    end
  end

  # A #trigger body run on a script's own thread (its `#parse`, a variable
  # change it made, its own input) runs inside that script's row in Remix (ClassCommand_RunScript
  # is synchronous), so the script is the launch's launcher: it waits for the first run, and the
  # child is listed after it.
  describe 'a #trigger launch on a script thread' do
    it 'takes the dispatch owner\'s script as the launcher' do
      write('child.cmd')
      parent = glue.new(File.join(@root, 'child.cmd'))
      interp = Object.new
      parent.instance_variable_set(:@genie_interpreter, interp)
      allow(script_class).to receive(:current_without_pause).and_return(parent)
      list.launched(parent) # in its own first run
      launcher = Thread.new { Lich::Genie::ParseDispatch.as_owner(interp) { glue.host_launch('child', '') } }
      child = Timeout.timeout(5) { started.pop }
      Timeout.timeout(5) { Thread.pass until launcher.status == 'sleep' }
      expect(launcher.alive?).to be(true) # waits for the first run
      first_run_done('child')
      expect(launcher.join(5)&.value).to be(child)
      expect(list.listed?(child)).to be(false)
      list.run_ended(parent)
      expect(list.listed).to eq([parent, child])
    end

    it 'has no launcher when the dispatch owner is not that thread\'s genie script, or there is none' do
      write('child.cmd')
      stranger = glue.new(File.join(@root, 'child.cmd'))
      stranger.instance_variable_set(:@genie_interpreter, Object.new)
      list.launched(stranger) # pending: a child it launched would wait for it
      allow(script_class).to receive(:current_without_pause).and_return(stranger, nil)
      [Object.new, Object.new].each do |owner|
        child = Lich::Genie::ParseDispatch.as_owner(owner) { glue.host_launch('child', '') }
        first_run_done('child')
        until_listed(child) # listed at its own first run end: nothing holds it
      end
    end
  end

  # GenieScript#build_interpreter -- Script.LoadFile through Engine.build with the
  # live ignorescriptwarnings, the launch's file name, and the exact include loader.
  describe 'the load model' do
    let(:printed) { [] }

    before do
      lines = printed
      allow(glue).to receive(:respond_in_chain) { |text| lines << text }
    end

    def build(name, ignore:)
      allow(Lich::Genie).to receive(:ignore_script_warnings?).and_return(ignore)
      glue.new(File.join(@root, name)).send(:build_interpreter, Lich::Genie::Variables.new, list)
    end

    it 'prints the load error and builds no interpreter for a script Remix refuses (CR-only lines counted)' do
      File.binwrite(File.join(@root, 'bad.cmd'), "echo a\rwhile 1 DO echo x\r")
      expect(build('bad.cmd', ignore: true)).to be_nil
      expect(printed).to eq(['[Script error(2): Invalid WHILE statement: while 1 DO echo x]'])
    end

    it 'loads an include exactly from the script dir and honours ignorescriptwarnings' do
      File.write(File.join(@root, 'inc.cmd'), "blarg\necho in\n")
      File.write(File.join(@root, 'custom', 'other.cmd'), "echo x\n")
      File.write(File.join(@root, 'main.cmd'), "include inc.cmd\necho main\n")
      File.write(File.join(@root, 'two.cmd'), "include inc.cmd\ninclude other.cmd\n")
      File.write(File.join(@root, 'noext.cmd'), "include inc\n")
      interp = build('main.cmd', ignore: true)
      expect(interp.instance_variable_get(:@program).instructions.map(&:content)).to eq(['echo in', 'echo main'])
      expect(interp.instance_variable_get(:@program).file_name).to eq('main.cmd')
      expect(build('main.cmd', ignore: false)).to be_nil
      expect(build('two.cmd', ignore: true)).to be_nil # custom/ is no include dir
      expect(build('noext.cmd', ignore: true)).to be_nil # no ".cmd" added
      expect(printed).to eq(['[Script error, inc.cmd(1): Unknown script command: blarg]', '[Script error: File not found: other.cmd]',
                             '[Script error: File not found: inc]'])
    end

    # A Lich-typed `;empty` never passes ScriptLaunch.resolve's size check, so the
    # load itself refuses the zero-byte file (AppendFile's fi.Length > 0); a NUL in an
    # include name refuses the load instead of raising Ruby's ArgumentError on the script thread.
    it 'refuses a zero-byte script and a NUL include name with a script error, raising nothing' do
      File.binwrite(File.join(@root, 'empty.cmd'), '')
      File.binwrite(File.join(@root, 'nul.cmd'), "echo a\ninclude in\u0000c.cmd\n")
      expect([build('empty.cmd', ignore: false), build('nul.cmd', ignore: true)]).to eq([nil, nil])
      expect(printed).to eq(['[Script error: Unable to load file: empty.cmd]', "[Script error: Null character in path. (Parameter 'path')]"])
    end
  end
end
