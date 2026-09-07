# frozen_string_literal: true

require 'zlib'
require 'timeout'
require_relative '../../spec_helper'
require_relative '../../../lib/common/limitedarray'
require_relative '../../../lib/common/feature_flags'
require_relative '../../../lib/common/downstreamhook'
require_relative '../../../lib/common/upstreamhook'

RSpec.describe 'Lich::Common::Script lifecycle extensions' do
  let(:script_class) { Lich::Common::Script }
  let(:subscript_class) { Lich::Common::SubScript }
  let(:exec_script_class) { Lich::Common::ExecScript }

  before(:context) do
    require_relative '../../../lib/common/script'
  end

  after(:context) do
    %i[SubScript ExecScript WizardScript Script Scripting TRUSTED_SCRIPT_BINDING].each do |const_name|
      Lich::Common.send(:remove_const, const_name) if Lich::Common.const_defined?(const_name, false)
    end
    $LOADED_FEATURES.delete_if { |path| path.end_with?('/lib/common/script.rb') }
  end

  before do
    script_class.class_variable_set(:@@running, [])
    script_class.class_variable_set(:@@stopping, [])
    script_class.class_variable_set(:@@startup_reservations, {})
    script_class.class_variable_set(:@@startup_generation, 0)
    script_class.class_variable_set(:@@completed_named_starts, {})
    script_class.class_variable_set(:@@completed_start_waiters, {})
    script_class.class_variable_set(:@@shutdown_started, false)
    script_class.class_variable_set(:@@loaded_libraries, Set.new)
    script_class.class_variable_set(:@@loaded_library_owners, {})
    script_class.class_variable_set(:@@loading_libraries, {})
    script_class.class_variable_set(:@@reloading_libraries, {})
    script_class.class_variable_set(:@@library_waits, {})
    allow(Lich).to receive(:log)
    allow(Lich::Common::FeatureFlags).to receive(:enabled?).with(:script_kill_metrics).and_return(false)
    allow_any_instance_of(script_class).to receive(:report_errors) { |_script, &block| block.call }
  end

  after do
    script_class.list.each { |script| script.kill(context: :shutdown) if script.running? }
    script_class.class_variable_set(:@@running, [])
    script_class.class_variable_set(:@@stopping, [])
  end

  describe '.start' do
    it 'constructs and starts an ordinary Ruby script' do
      Dir.mktmpdir('script-start') do |root|
        custom_dir = File.join(root, 'custom')
        FileUtils.mkdir_p(custom_dir)
        File.write(File.join(custom_dir, 'ordinary.lic'), "# quiet\nnil\nDone:\nnil\n")
        stub_const('SCRIPT_DIR', root)

        started = script_class.start('ordinary')

        expect(started).to be_a(script_class)
        expect(started.join(2)).to equal(started)
        expect(started).to be_completed_successfully
      end
    end

    it 'tears down an ordinary script whose worker dies during current-script lookup' do
      Dir.mktmpdir('script-worker-current') do |root|
        custom_dir = File.join(root, 'custom')
        FileUtils.mkdir_p(custom_dir)
        File.write(File.join(custom_dir, 'ordinary.lic'), "# quiet\nnil\nDone:\nnil\n")
        stub_const('SCRIPT_DIR', root)

        script = kill_worker_during_current { script_class.start('ordinary') }

        expect(script.join(1)).to equal(script)
        expect(script).not_to be_running
      end
    end

    it 'does not publish an ordinary script before its worker is allocated' do
      Dir.mktmpdir('script-start') do |root|
        custom_dir = File.join(root, 'custom')
        FileUtils.mkdir_p(custom_dir)
        File.write(File.join(custom_dir, 'ordinary.lic'), "# quiet\nnil\nDone:\nnil\n")
        stub_const('SCRIPT_DIR', root)
        allocation_entered = Queue.new
        release_allocation = Queue.new
        start_launch = Queue.new
        launcher = Thread.new do
          start_launch.pop
          script_class.start('ordinary')
        end
        first_allocation = true
        allow(Thread).to receive(:new).and_wrap_original do |method, *args, &block|
          if first_allocation
            first_allocation = false
            allocation_entered << true
            release_allocation.pop
          end
          method.call(*args, &block)
        end

        start_launch << true
        allocation_entered.pop

        expect(script_class.list).to be_empty
        expect(script_class.start('ordinary')).to be_nil

        release_allocation << true
        script = launcher.value
        expect(script.join(2)).to equal(script)
      end
    end

    it 'waits for in-flight startup before taking the shutdown snapshot' do
      Dir.mktmpdir('script-shutdown-start') do |root|
        custom_dir = File.join(root, 'custom')
        FileUtils.mkdir_p(custom_dir)
        File.write(File.join(custom_dir, 'ordinary.lic'), "# quiet\nQueue.new.pop\nDone:\nnil\n")
        stub_const('SCRIPT_DIR', root)
        allocation_entered = Queue.new
        release_allocation = Queue.new
        start_launch = Queue.new
        launcher = Thread.new do
          start_launch.pop
          script_class.start('ordinary')
        end
        first_allocation = true
        allow(Thread).to receive(:new).and_wrap_original do |method, *args, &block|
          if first_allocation
            first_allocation = false
            allocation_entered << true
            release_allocation.pop
          end
          method.call(*args, &block)
        end

        start_launch << true
        allocation_entered.pop
        shutdown = Thread.new { script_class.begin_shutdown }
        expect(shutdown.join(0.02)).to be_nil

        release_allocation << true
        script = launcher.value
        expect(shutdown.value).to contain_exactly(script)
        expect(script_class.start('ordinary')).to be_nil

        script.kill(:context => :shutdown)
      end
    end

    it 'releases startup coordination before taking the shutdown snapshot' do
      startup_mutex = script_class.class_variable_get(:@@startup_mutex)
      startup_mutex_owned = nil
      allow(script_class).to receive(:shutdown_scripts) do
        startup_mutex_owned = startup_mutex.owned?
        []
      end

      expect(script_class.begin_shutdown).to be_empty
      expect(startup_mutex_owned).to be(false)
    end

    it 'rejects direct constructor publication after shutdown begins' do
      Dir.mktmpdir('script-direct-shutdown') do |root|
        custom_dir = File.join(root, 'custom')
        FileUtils.mkdir_p(custom_dir)
        file_name = File.join(custom_dir, 'direct.lic')
        File.write(file_name, "# quiet\nnil\n")
        script_class.begin_shutdown

        expect {
          script_class.new(:file => file_name, :args => [], :quiet => true)
        }.to raise_error(ThreadError, /shutting down/)
        expect(script_class.list).to be_empty
      end
    end

    it 'releases a startup reservation when the starter is cancelled during admission' do
      Dir.mktmpdir('script-cancelled-admission') do |root|
        custom_dir = File.join(root, 'custom')
        FileUtils.mkdir_p(custom_dir)
        File.write(File.join(custom_dir, 'cancelled.lic'), "# quiet\nnil\n")
        stub_const('SCRIPT_DIR', root)
        admitted = Queue.new
        allow(script_class).to receive(:__begin_start).and_wrap_original do |method, *args, **kwargs|
          result = method.call(*args, **kwargs)
          admitted << true
          Queue.new.pop
          result
        end
        starter = Thread.new { script_class.start('cancelled') }
        admitted.pop

        starter.kill
        starter.join

        expect(script_class.class_variable_get(:@@startup_reservations)).to be_empty
        expect(Thread.new { script_class.begin_shutdown }.value).to be_empty
      end
    end

    it 'reaps a startup reservation whose owner dies before its ensure runs' do
      reservation = Object.new
      admitted = Queue.new
      owner = Thread.new do
        script_class.__send__(:__begin_start, reservation, 'libabandoned', :force => false)
        admitted << true
        Queue.new.pop
      end
      admitted.pop
      owner.kill
      owner.join

      expect(Timeout.timeout(1) { script_class.begin_shutdown }).to be_empty
      expect(script_class.class_variable_get(:@@startup_reservations)).to be_empty
    end

    it 'releases startup waiter accounting when cancelled after registration' do
      reservation = Object.new
      script_class.__send__(:__begin_start, reservation, 'libwaiting', :force => true)
      interrupting_waiters = Class.new(Hash) do
        def initialize
          super(0)
        end

        def []=(name, count)
          super
          unless defined?(@interrupted)
            @interrupted = true
            Thread.current.kill
          end
        end
      end.new
      script_class.class_variable_set(:@@completed_start_waiters, interrupting_waiters)

      waiter = Thread.new do
        script_class.__send__(:__begin_library_start, Object.new, 'libwaiting')
      end
      waiter.join

      expect(script_class.class_variable_get(:@@completed_start_waiters)).to be_empty
      expect(script_class.class_variable_get(:@@completed_named_starts)).to be_empty
    ensure
      script_class.__send__(:__finish_start, reservation) if defined?(reservation) && reservation
      waiter&.kill
    end

    it 'does not decrement startup waiter accounting when cancelled before registration' do
      reservation = Object.new
      script_class.__send__(:__begin_start, reservation, 'libwaiting', :force => true)
      interrupting_waiters = Class.new(Hash) do
        def initialize
          super(0)
        end

        def [](name)
          unless defined?(@interrupted)
            @interrupted = true
            Thread.current.kill
          end
          super
        end
      end.new
      script_class.class_variable_set(:@@completed_start_waiters, interrupting_waiters)

      waiter = Thread.new do
        script_class.__send__(:__begin_library_start, Object.new, 'libwaiting')
      end
      waiter.join

      expect(script_class.class_variable_get(:@@completed_start_waiters)).to be_empty
    ensure
      script_class.__send__(:__finish_start, reservation) if defined?(reservation) && reservation
      waiter&.kill
    end

    it 'consumes a gate value enqueued immediately before its owner exits' do
      gate = Queue.new
      release_owner = Queue.new
      owner = Thread.new do
        release_owner.pop
        gate << true
      end
      first_pop = true
      gate.define_singleton_method(:pop) do |non_block = false|
        if first_pop
          first_pop = false
          release_owner << true
          owner.join
          raise ThreadError, 'simulated stale empty observation'
        end
        super(non_block)
      end

      result = script_class.__send__(:__await_thread_gate, gate, owner, false)

      expect(result).to be(true)
    ensure
      release_owner << true if defined?(release_owner) && release_owner
      owner&.kill
    end

    it 'uses the published name when reserving a compressed script' do
      Dir.mktmpdir('script-compressed-start') do |root|
        custom_dir = File.join(root, 'custom')
        FileUtils.mkdir_p(custom_dir)
        Zlib::GzipWriter.open(File.join(custom_dir, 'compressed.lic.gz')) do |file|
          file.write("# quiet\nQueue.new.pop\nDone:\nnil\n")
        end
        stub_const('SCRIPT_DIR', root)

        first = script_class.start('compressed')

        expect(first.name).to eq('compressed')
        expect(script_class.start('compressed')).to be_nil
        first.kill(:context => :shutdown)
      end
    end

    it 'rejects a non-forced start while the same name is still stopping' do
      Dir.mktmpdir('script-stopping-start') do |root|
        custom_dir = File.join(root, 'custom')
        FileUtils.mkdir_p(custom_dir)
        File.write(File.join(custom_dir, 'ordinary.lic'), "# quiet\nnil\nDone:\nnil\n")
        stub_const('SCRIPT_DIR', root)
        stopping = build_script('ordinary')
        script_class.class_variable_set(:@@stopping, [stopping])

        expect(script_class.start('ordinary')).to be_nil
        expect(script_class.list).to be_empty
      end
    end

    it 'allows a non-forced restart after a completed stopping entry is stranded' do
      Dir.mktmpdir('script-completed-stopper-start') do |root|
        custom_dir = File.join(root, 'custom')
        FileUtils.mkdir_p(custom_dir)
        File.write(File.join(custom_dir, 'ordinary.lic'), "# quiet\nnil\nDone:\nnil\n")
        stub_const('SCRIPT_DIR', root)
        stopping = build_script('ordinary')
        stopping.instance_variable_set(:@cleanup_complete, true)
        script_class.class_variable_set(:@@stopping, [stopping])

        restarted = script_class.start('ordinary')

        expect(restarted).to be_a(script_class)
        expect(restarted.join(2)).to equal(restarted)
      end
    end

    it 'does not retain an unclaimed completed library start' do
      reservation = Object.new
      library = build_script('libunused')
      script_class.__send__(:__begin_start, reservation, 'libunused', :force => true)

      script_class.__send__(:__finish_start, reservation, library)

      expect(script_class.class_variable_get(:@@completed_named_starts)).to be_empty
    end

    it 'retains a completed library handoff strongly for a waiter' do
      reservation = Object.new
      library = build_script('libwaiting')
      script_class.__send__(:__begin_start, reservation, 'libwaiting', :force => true)
      script_class.class_variable_get(:@@completed_start_waiters)['libwaiting'] = 1

      script_class.__send__(:__finish_start, reservation, library)

      completed = script_class.class_variable_get(:@@completed_named_starts)
      expect(completed.fetch('libwaiting').last).to equal(library)
    end

    it 'records a missing-label jump as unsuccessful execution' do
      Dir.mktmpdir('script-label-error') do |root|
        custom_dir = File.join(root, 'custom')
        FileUtils.mkdir_p(custom_dir)
        File.write(
          File.join(custom_dir, 'badjump.lic'),
          <<~RUBY
            # quiet
            Lich::Common::Script.current.jump_label = 'missing'
            raise Lich::Common::Script::JUMP
            Done:
            nil
          RUBY
        )
        stub_const('SCRIPT_DIR', root)

        started = script_class.start('badjump')

        expect(started.join(2)).to equal(started)
        expect(started.exit_error).to equal(script_class::JUMP_ERROR)
        expect(started).not_to be_completed_successfully
      end
    end

    it 'does not publish when binding construction fails' do
      Dir.mktmpdir('script-binding') do |root|
        custom_dir = File.join(root, 'custom')
        FileUtils.mkdir_p(custom_dir)
        File.write(File.join(custom_dir, 'binding_failure.lic'), "# quiet\nnil\nDone:\nnil\n")
        stub_const('SCRIPT_DIR', root)
        allow_any_instance_of(Lich::Common::Scripting).to receive(:script).and_raise(RuntimeError, 'forced binding failure')

        expect(script_class.start('binding_failure')).to be_nil
        expect(script_class.list).to be_empty
      end
    end

    it 'does not publish a Wizard script when binding construction fails' do
      Dir.mktmpdir('wizard-binding') do |root|
        custom_dir = File.join(root, 'custom')
        FileUtils.mkdir_p(custom_dir)
        File.write(File.join(custom_dir, 'binding_failure.cmd'), "exit\n")
        stub_const('SCRIPT_DIR', root)
        allow_any_instance_of(Lich::Common::Scripting).to receive(:script).and_raise(RuntimeError, 'forced binding failure')

        expect(script_class.start('binding_failure')).to be_nil
        expect(script_class.list).to be_empty
      end
    end

    it 'loads an ordinary library through the production startup path' do
      Dir.mktmpdir('script-library') do |root|
        custom_dir = File.join(root, 'custom')
        FileUtils.mkdir_p(custom_dir)
        File.write(File.join(custom_dir, 'libsample.lic'), "# quiet\nnil\nDone:\nnil\n")
        stub_const('SCRIPT_DIR', root)

        expect(script_class.loadlib('sample')).to be(true)
        expect(script_class.libs).to include('libsample')
        expect(script_class.class_variable_get(:@@completed_named_starts)).to be_empty
      end
    end

    it 'executes a new generation when reloading a production library' do
      Dir.mktmpdir('script-library-reload') do |root|
        custom_dir = File.join(root, 'custom')
        FileUtils.mkdir_p(custom_dir)
        File.write(
          File.join(custom_dir, 'libreload.lic'),
          "# quiet\n$script_lifecycle_reload_runs = $script_lifecycle_reload_runs.to_i + 1\nDone:\nnil\n"
        )
        stub_const('SCRIPT_DIR', root)

        expect(script_class.loadlib('reload')).to be(true)
        expect(script_class.list).to be_empty
        expect(script_class.class_variable_get(:@@startup_reservations)).to be_empty
        expect(script_class.class_variable_get(:@@completed_named_starts)).to be_empty
        expect(script_class.reloadlibs).to be(true)
        expect($script_lifecycle_reload_runs).to eq(2)
      ensure
        $script_lifecycle_reload_runs = nil
      end
    end

    it 'does not load a library that exits unsuccessfully' do
      Dir.mktmpdir('script-library-exit') do |root|
        custom_dir = File.join(root, 'custom')
        FileUtils.mkdir_p(custom_dir)
        File.write(File.join(custom_dir, 'libfailure.lic'), "# quiet\nexit(false)\nDone:\nnil\n")
        stub_const('SCRIPT_DIR', root)

        expect { script_class.loadlib('failure') }.to raise_error(LoadError, /failed/)
        expect(script_class.libs).not_to include('libfailure')
      end
    end

    it 'does not discard a published script when gate release is interrupted' do
      Dir.mktmpdir('script-gate-release') do |root|
        custom_dir = File.join(root, 'custom')
        FileUtils.mkdir_p(custom_dir)
        File.write(File.join(custom_dir, 'gate_release.lic'), "# quiet\nsleep 1\nDone:\nnil\n")
        stub_const('SCRIPT_DIR', root)
        interrupt_next_queue_release(:after)

        expect { script_class.start('gate_release') }.to raise_error(Timeout::Error, /gate release/)

        script = script_class.list.find { |candidate| candidate.name == 'gate_release' }
        expect(script).not_to be_nil
        expect(script.kill_sync(:timeout => 1)).to equal(script)
      end
    end

    it 'tears down a gated script when its launcher is killed after publication' do
      Dir.mktmpdir('script-killed-gate-release') do |root|
        custom_dir = File.join(root, 'custom')
        FileUtils.mkdir_p(custom_dir)
        File.write(File.join(custom_dir, 'gate_release.lic'), "# quiet\nsleep 1\nDone:\nnil\n")
        stub_const('SCRIPT_DIR', root)
        gate_entered, release_gate = block_next_queue_release
        launcher = Thread.new { script_class.start('gate_release') }
        gate_entered.pop

        expect(script_class.list.map(&:name)).to include('gate_release')
        launcher.kill
        launcher.join

        Timeout.timeout(1) { sleep 0.01 until script_class.list.empty? }
      ensure
        release_gate << true if defined?(release_gate) && release_gate
        launcher&.kill
      end
    end
  end

  describe 'Script facade' do
    it 'starts an anonymous child through Script.subscript' do
      parent = build_script('parent')
      child = build_script('child')
      block = proc {}
      allow(script_class).to receive(:current).and_return(parent)
      expect(subscript_class).to receive(:start)
        .with(:parent => parent, :quiet => true)
        .and_return(child)

      expect(script_class.subscript(&block)).to equal(child)
    end

    it 'raises when anonymous child startup is rejected' do
      parent = build_script('stopping-parent')
      script_class.class_variable_set(:@@running, [parent])
      parent.kill(:context => :shutdown)
      allow(script_class).to receive(:current).and_return(parent)

      expect {
        script_class.subscript {}
      }.to raise_error(ThreadError, /shutdown or parent teardown/)
    end

    it 'requires a block when starting an anonymous child' do
      expect { script_class.subscript }.to raise_error(ArgumentError, /block is required/)
    end

    it 'registers a named child through Script.start_child' do
      Dir.mktmpdir('script-facade-child') do |root|
        custom_dir = File.join(root, 'custom')
        FileUtils.mkdir_p(custom_dir)
        File.write(File.join(custom_dir, 'child.lic'), "# quiet\nSCRIPT_FACADE_RELEASE.pop\nDone:\nnil\n")
        stub_const('SCRIPT_DIR', root)
        stub_const('SCRIPT_FACADE_RELEASE', Queue.new)
        parent = build_script('parent')
        script_class.class_variable_set(:@@running, [parent])
        parent.thread_group.add(Thread.current)

        child = script_class.start_child('child')
        ThreadGroup::Default.add(Thread.current)

        expect(parent.child_scripts).to contain_exactly(child)
        SCRIPT_FACADE_RELEASE << true
        expect(child.join(1)).to equal(child)
        expect(parent.child_scripts).to be_empty
      ensure
        ThreadGroup::Default.add(Thread.current)
      end
    end

    it 'waits for a child through Script.run_child' do
      child = build_script('child')
      allow(script_class).to receive(:start_child).with('child').and_return(child)
      expect(child).to receive(:join).with(nil).and_return(child)

      expect(script_class.run_child('child')).to equal(child)
    end

    it 'tears down and raises when the Script.run_child timeout expires' do
      child = build_script('child')
      allow(script_class).to receive(:start_child).with('child').and_return(child)
      expect(child).to receive(:join).with(0.25).and_return(nil)
      expect(child).to receive(:kill_sync)

      expect {
        script_class.run_child('child', :timeout => 0.25)
      }.to raise_error(script_class::TimeoutError) { |error|
        expect(error.script).to equal(child)
      }
    end

    it 'raises when a Script.run_child child cannot be started' do
      allow(script_class).to receive(:start_child).with('child').and_return(nil)

      expect {
        script_class.run_child('child')
      }.to raise_error(script_class::StartError, /script failed to start: child/)
    end

    it 'rejects a negative Script.run_child timeout before starting the child' do
      expect(script_class).not_to receive(:start_child)

      expect {
        script_class.run_child('child', :timeout => -1)
      }.to raise_error(ArgumentError, /non-negative/)
    end

    it 'marks the current script as a daemon' do
      script = build_script('daemon')
      allow(script_class).to receive(:current).and_return(script)

      expect(script_class.daemon_me).to equal(script)
      expect(script.hidden).to be(true)
      expect(script.no_kill_all).to be(true)
      expect(script.no_pause_all).to be(true)
    end
  end

  describe 'SubScript' do
    it 'preserves direct constructor publication and shutdown admission' do
      script = subscript_class.new

      expect(script.name).to eq('subscript1')
      expect(script).to be_running
      script.kill(:context => :shutdown)

      script_class.begin_shutdown
      expect { subscript_class.new }.to raise_error(ThreadError, /shutting down/)
    end

    it 'runs a block with its own Script.current identity' do
      observed = Queue.new
      subscript = subscript_class.start { observed << script_class.current }

      expect(subscript.join(2)).to equal(subscript)
      expect(observed.pop(true)).to equal(subscript)
      expect(subscript).to be_a(subscript_class)
      expect(subscript).to be_completed_successfully
    end

    it 'records JumpError raised by a subscript block' do
      subscript = subscript_class.start(:parent => nil) { raise script_class::JUMP }

      expect(subscript.join(1)).to equal(subscript)
      expect(subscript.exit_error).to be_a(script_class::JumpError)
      expect(subscript).not_to be_completed_successfully
    end

    it 'does not discard a published subscript when gate release is interrupted' do
      interrupt_next_queue_release(:after)

      expect {
        subscript_class.start(:parent => nil) { sleep 1 }
      }.to raise_error(Timeout::Error, /gate release/)

      script = script_class.list.find { |candidate| candidate.name.start_with?('subscript') }
      expect(script).not_to be_nil
      expect(script.kill_sync(:timeout => 1)).to equal(script)
    end

    it 'tears down a subscript whose worker dies during current-script lookup' do
      script = kill_worker_during_current { subscript_class.start(:parent => nil) {} }

      expect(script.join(1)).to equal(script)
      expect(script).not_to be_running
    end

    it 'unregisters itself when it exits naturally' do
      parent = build_script('parent')
      script_class.class_variable_set(:@@running, [parent])

      child = subscript_class.start(:parent => parent) {}
      expect(child.join(2)).to equal(child)

      expect(parent.child_scripts).to be_empty
    end

    it 'is stopped with the parent during runtime teardown' do
      parent = build_script('parent')
      script_class.class_variable_set(:@@running, [parent])
      child = subscript_class.start(:parent => parent) { Queue.new.pop }
      expect(child).to receive(:kill).with(:context => :runtime, :async => true).and_call_original

      expect(parent.kill_sync(:context => :runtime, :timeout => 2)).to equal(parent)

      expect(parent).not_to be_running
      expect(child).not_to be_running
    end

    it 'leaves shutdown children for the process-wide drain' do
      parent = build_script('parent')
      script_class.class_variable_set(:@@running, [parent])
      child = subscript_class.start(:parent => parent) { Queue.new.pop }
      allow(child).to receive(:kill).and_call_original

      parent.kill(:context => :shutdown)

      expect(parent).not_to be_running
      expect(child).to be_running
      expect(child).not_to have_received(:kill)
      child.kill(:context => :shutdown)
    end

    it 'inherits protection flags from its parent' do
      parent = build_script('daemon-parent')
      parent.hidden = true
      parent.no_kill_all = true
      parent.no_pause_all = true
      script_class.class_variable_set(:@@running, [parent])
      release = Queue.new
      child = subscript_class.start(:parent => parent) { release.pop }

      expect(child.hidden).to be(true)
      expect(child.no_kill_all).to be(true)
      expect(child.no_pause_all).to be(true)

      release << true
      child.join(2)
    end

    it 'establishes child ownership and protection before publication' do
      parent = build_script('daemon-parent')
      parent.hidden = true
      parent.no_kill_all = true
      parent.no_pause_all = true
      script_class.class_variable_set(:@@running, [parent])
      publish_entered = Queue.new
      release_publish = Queue.new
      release_child = Queue.new
      child_instance = nil
      allow(subscript_class).to receive(:new).and_wrap_original do |method, *args, **kwargs|
        child_instance = method.call(*args, **kwargs)
        allow(child_instance).to receive(:__publish).and_wrap_original do |publish|
          publish_entered << true
          release_publish.pop
          publish.call
        end
        child_instance
      end
      launcher = Thread.new { subscript_class.start(:parent => parent) { release_child.pop } }
      publish_entered.pop

      expect(child_instance.hidden).to be(true)
      expect(child_instance.no_kill_all).to be(true)
      expect(child_instance.no_pause_all).to be(true)
      expect(script_class.list).to contain_exactly(parent)

      release_publish << true
      child = launcher.value
      expect(parent.child_scripts).to contain_exactly(child)
      release_child << true
      expect(child.join(2)).to equal(child)
    end

    it 'rejects and stops a child registered after parent teardown begins' do
      parent = build_script('stopped-parent')
      script_class.class_variable_set(:@@running, [parent])
      parent.kill(:context => :shutdown)
      child = build_script('late-child')
      script_class.class_variable_set(:@@running, [child])

      expect(parent.register_child(child)).to be_nil
      expect(child).not_to be_running
    end

    it 'returns false when parent teardown rejects subscript startup' do
      parent = build_script('stopping-parent')
      script_class.class_variable_set(:@@running, [parent])
      parent.kill(:context => :shutdown)

      expect(subscript_class.start(:parent => parent) {}).to be(false)
    end

    it 'rolls back registration when worker allocation fails' do
      parent = build_script('parent')
      script_class.class_variable_set(:@@running, [parent])
      allow(Thread).to receive(:new).and_raise(ThreadError, 'forced allocation failure')

      expect { subscript_class.start(:parent => parent) {} }.to raise_error(ThreadError, /forced/)

      expect(script_class.list).to contain_exactly(parent)
      children = Object.instance_method(:instance_variable_get).bind_call(parent, :@child_scripts)
      expect(Array(children)).to be_empty
    end

    it 'rolls back registration when worker release fails' do
      parent = build_script('parent')
      script_class.class_variable_set(:@@running, [parent])
      start_gate = instance_double(Queue)
      allow(start_gate).to receive(:pop) { Thread.stop }
      allow(start_gate).to receive(:<<).with(true).and_raise(ThreadError, 'forced release failure')
      allow(Queue).to receive(:new).and_return(start_gate)
      rolled_back = nil
      allow(subscript_class).to receive(:new).and_wrap_original do |method, *args, **kwargs|
        rolled_back = method.call(*args, **kwargs)
      end

      expect { subscript_class.start(:parent => parent) {} }.to raise_error(ThreadError, /forced/)

      expect(script_class.list).to contain_exactly(parent)
      expect(parent.child_scripts).to be_empty
      expect(rolled_back.join(0.1)).to equal(rolled_back)
    end

    it 'preserves the parent identity for parent exit handlers' do
      parent = build_script('parent')
      script_class.class_variable_set(:@@running, [parent])
      child_ready = Queue.new
      child = subscript_class.start(:parent => parent) { child_ready << true; Queue.new.pop }
      child_ready.pop
      observed = nil
      parent.at_exit { observed = script_class.current }

      expect(parent.kill_sync(:context => :runtime, :timeout => 2)).to equal(parent)

      expect(observed).to equal(parent)
      expect(child.join(1)).to equal(child)
    end

    it 'rejects self-registration and ownership cycles' do
      parent = build_script('parent')
      child = build_script('child')
      script_class.class_variable_set(:@@running, [parent, child])

      expect { parent.register_child(parent) }.to raise_error(ArgumentError, /own child/)
      expect(parent.register_child(child)).to equal(child)
      expect { child.register_child(parent) }.to raise_error(ArgumentError, /cycle/)
    end

    it 'waits for an in-progress child launch before taking the teardown snapshot' do
      parent = build_script('parent')
      child = build_script('child')
      script_class.class_variable_set(:@@running, [parent, child])
      launch_entered = Queue.new
      release_launch = Queue.new
      registration_result = :pending
      launcher = Thread.new do
        parent.__send__(:__launch_child) do
          launch_entered << true
          release_launch.pop
          registration_result = parent.register_child(child)
        end
      end
      launch_entered.pop
      killer = Thread.new { parent.kill_sync(:context => :runtime, :timeout => 2) }

      sleep 0.02
      expect(parent).to be_running

      release_launch << true
      launcher.join
      killer.join
      expect(parent).not_to be_running
      expect(registration_result).to be_nil
      expect(child.join(1)).to equal(child)
    end

    it 'kills a parent worker before waiting on its child launch reservation' do
      parent = build_script('parent')
      script_class.class_variable_set(:@@running, [parent])
      launch_entered = Queue.new
      launcher = Thread.new do
        parent.__send__(:__launch_child) do
          launch_entered << true
          Queue.new.pop
        end
      end
      parent.thread_group.add(launcher)
      launch_entered.pop

      expect(parent.kill_sync(:context => :runtime, :timeout => 1)).to equal(parent)
      expect(launcher).not_to be_alive
    end

    it 'releases a child launch reservation when cancelled after admission' do
      parent = build_script('parent')
      script_class.class_variable_set(:@@running, [parent])
      original_mutex = parent.__send__(:child_scripts_mutex)
      interrupting_mutex = Object.new
      first_synchronize = true
      interrupting_mutex.define_singleton_method(:synchronize) do |&block|
        result = original_mutex.synchronize(&block)
        if first_synchronize
          first_synchronize = false
          Thread.current.kill
        end
        result
      end
      parent.instance_variable_set(:@child_scripts_mutex, interrupting_mutex)

      launcher = Thread.new { parent.__send__(:__launch_child) { raise 'unreachable' } }
      launcher.join

      launches = Object.instance_method(:instance_variable_get).bind_call(parent, :@child_launches)
      expect(launches.nil? || launches.empty?).to be(true)
      expect(parent.kill_sync(:context => :runtime, :timeout => 1)).to equal(parent)
    ensure
      launcher&.kill
    end

    it 'reaps a child launch reservation when its owner dies without signaling' do
      parent = build_script('parent')
      script_class.class_variable_set(:@@running, [parent])
      launch_owner = Thread.new { Queue.new.pop }
      parent.instance_variable_set(:@child_launches, Object.new => launch_owner)
      killer = Thread.new { parent.kill_sync(:context => :runtime, :timeout => 1) }
      sleep 0.02

      launch_owner.kill
      launch_owner.join

      expect(killer.value).to equal(parent)
      expect(parent).not_to be_running
    ensure
      launch_owner&.kill
      killer&.kill
    end

    it 'does not publish a subscript before its worker is allocated' do
      parent = build_script('parent')
      script_class.class_variable_set(:@@running, [parent])
      allocation_entered = Queue.new
      release_allocation = Queue.new
      start_launch = Queue.new
      launcher = Thread.new do
        start_launch.pop
        subscript_class.start(:parent => parent) {}
      end
      first_allocation = true
      allow(Thread).to receive(:new).and_wrap_original do |method, *args, &block|
        if first_allocation
          first_allocation = false
          allocation_entered << true
          release_allocation.pop
        end
        method.call(*args, &block)
      end

      start_launch << true
      allocation_entered.pop

      expect(script_class.list).to contain_exactly(parent)
      children = Object.instance_method(:instance_variable_get).bind_call(parent, :@child_scripts)
      expect(Array(children)).to be_empty

      release_allocation << true
      child = launcher.value
      expect(child.join(2)).to equal(child)
    end

    it 'rolls back subscript publication when the launcher is killed mid-transition' do
      publish_entered = Queue.new
      release_publish = Queue.new
      child_instance = nil
      allow(subscript_class).to receive(:new).and_wrap_original do |method, *args, **kwargs|
        child_instance = method.call(*args, **kwargs)
        allow(child_instance).to receive(:__publish).and_wrap_original do |publish, *publish_args|
          publish_entered << true
          release_publish.pop
          publish.call(*publish_args)
        end
        child_instance
      end
      launcher = Thread.new do
        subscript_class.start(:parent => nil) { Queue.new.pop }
      end
      publish_entered.pop

      launcher.kill
      release_publish << true
      launcher.join

      expect(child_instance).not_to be_running
      expect(script_class.list).to be_empty
      expect(child_instance.__send__(:__worker_threads)).to all(satisfy { |thread| !thread.alive? })
    end
  end

  describe 'ExecScript' do
    it 'records successful and failed execution results' do
      allow(Lich::Common::TRUSTED_SCRIPT_BINDING).to receive(:call).and_return(Lich::Common::Scripting.new.script)
      successful = exec_script_class.start('nil')
      expect(successful.join(1)).to equal(successful)
      expect(successful).to be_completed_successfully
      expect(successful.exit_error).to be_nil

      failed = exec_script_class.start("raise 'exec failed'")
      expect(failed.join(1)).to equal(failed)
      expect(failed).not_to be_completed_successfully
      expect(failed.exit_error).to be_a(RuntimeError)
    end

    it 'records JumpError raised by exec code' do
      allow(Lich::Common::TRUSTED_SCRIPT_BINDING).to receive(:call).and_return(Lich::Common::Scripting.new.script)
      script = exec_script_class.start('raise Lich::Common::Script::JUMP')

      expect(script.join(1)).to equal(script)
      expect(script.exit_error).to be_a(script_class::JumpError)
      expect(script).not_to be_completed_successfully
    end

    it 'tears down an exec script whose worker dies during current-script lookup' do
      script = kill_worker_during_current { exec_script_class.start('nil') }

      expect(script.join(1)).to equal(script)
      expect(script).not_to be_running
    end

    it 'preserves direct constructor publication and shutdown admission' do
      script = exec_script_class.new('nil', :quiet => true)

      expect(script.name).to eq('exec1')
      expect(script).to be_running
      script.kill(:context => :shutdown)

      script_class.begin_shutdown
      expect { exec_script_class.new('nil') }.to raise_error(ThreadError, /shutting down/)
    end

    it 'rolls back startup when worker allocation fails' do
      allow(Thread).to receive(:new).and_raise(ThreadError, 'forced allocation failure')

      expect { exec_script_class.start('nil') }.to raise_error(ThreadError, /forced/)

      expect(script_class.list).to be_empty
    end

    it 'does not publish before its worker is allocated' do
      allocation_entered = Queue.new
      release_allocation = Queue.new
      start_launch = Queue.new
      launcher = Thread.new do
        start_launch.pop
        exec_script_class.start('nil')
      end
      first_allocation = true
      allow(Thread).to receive(:new).and_wrap_original do |method, *args, &block|
        if first_allocation
          first_allocation = false
          allocation_entered << true
          release_allocation.pop
        end
        method.call(*args, &block)
      end

      start_launch << true
      allocation_entered.pop

      expect(script_class.list).to be_empty

      release_allocation << true
      script = launcher.value
      expect(script.join(2)).to equal(script)
    end

    it 'does not discard a published exec script when gate release is interrupted' do
      interrupt_next_queue_release(:after)

      expect {
        exec_script_class.start('sleep 1')
      }.to raise_error(Timeout::Error, /gate release/)

      script = script_class.list.find { |candidate| candidate.name.start_with?('exec') }
      expect(script).not_to be_nil
      expect(script.kill_sync(:timeout => 1)).to equal(script)
    end
  end

  describe 'synchronous lifecycle methods' do
    it 'preserves the standard ThreadGroup surface' do
      script = build_script('thread-group-api')
      script_class.class_variable_set(:@@running, [script])
      worker = Thread.new { Queue.new.pop }
      group = script.thread_group

      expect(group).to be_a(ThreadGroup)
      expect(group).to be_instance_of(ThreadGroup)
      expect(group.add(worker)).to equal(group)
      expect(worker.group).to equal(group)
      expect { group.add(Object.new) }.to raise_error(TypeError, /expected VM\/thread/)
      expect(group).not_to be_enclosed
      expect(group.enclose).to equal(group)
      expect(group).to be_enclosed
      other_group = ThreadGroup.new
      expect { other_group.add(worker) }.to raise_error(ThreadError, /enclosed/)
      expect(worker.group).to equal(group)
    ensure
      worker&.kill
      worker&.join
      script_class.class_variable_set(:@@running, [])
    end

    it 'returns a child after run_child observes complete teardown' do
      child = instance_double(script_class, :join => true)
      allow(script_class).to receive(:start_child).with('worker').and_return(child)

      expect(script_class.run_child('worker')).to equal(child)
    end

    it 'tears down and raises when run_child teardown times out' do
      child = instance_double(script_class, :join => nil, :name => 'worker')
      allow(child).to receive(:kill_sync)
      allow(script_class).to receive(:start_child).with('worker').and_return(child)

      expect { script_class.run_child('worker') }.to raise_error(script_class::TimeoutError)
      expect(child).to have_received(:kill_sync)
    end

    it 'waits for exit handlers in kill_sync' do
      script = build_script('sync')
      script_class.class_variable_set(:@@running, [script])
      cleaned_up = false
      script.at_exit do
        sleep 0.02
        cleaned_up = true
      end

      expect(script.kill_sync).to equal(script)
      expect(cleaned_up).to be(true)
      expect(script).not_to be_running
    end

    it 'returns nil when join times out' do
      script = build_script('waiting')
      script_class.class_variable_set(:@@running, [script])

      expect(script.join(0.01)).to be_nil
    end

    it 'rejects joining from one of the script workers' do
      script = build_script('self-join')
      script_class.class_variable_set(:@@running, [script])
      result = Queue.new
      start = Queue.new
      worker = Thread.new do
        start.pop
        begin
          script.join
        rescue ThreadError => error
          result << error
        end
      end
      script.thread_group.add(worker)
      start << true

      expect(worker.join(1)).to equal(worker)
      expect(result.pop(true).message).to match(/current script/)
    end

    it 'honors join timeout while cleanup holds the killer mutex' do
      script = build_script('slow-cleanup')
      script_class.class_variable_set(:@@running, [script])
      entered = Queue.new
      release = Queue.new
      script.at_exit { entered << true; release.pop }

      script.kill
      entered.pop
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      expect(script.join(0.02)).to be_nil
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at).to be < 0.2

      release << true
      expect(script.join(1)).to equal(script)
    end

    it 'does not block a repeated shutdown kill behind active cleanup' do
      script = build_script('slow-cleanup')
      script_class.class_variable_set(:@@running, [script])
      entered = Queue.new
      release = Queue.new
      script.at_exit { entered << true; release.pop }
      script.kill
      entered.pop

      repeated_kill = Thread.new { script.kill(:context => :shutdown) }
      expect(repeated_kill.join(0.1)).to equal(repeated_kill)

      release << true
      expect(script.join(1)).to equal(script)
    end

    it 'waits for killed worker ensure blocks to finish' do
      ready = Queue.new
      ensure_started = Queue.new
      release = Queue.new
      script = subscript_class.start(:parent => nil) do
        ready << true
        begin
          Queue.new.pop
        ensure
          ensure_started << true
          release.pop
        end
      end
      ready.pop

      script.kill
      ensure_started.pop
      expect(script.join(0.02)).to be_nil

      release << true
      expect(script.join(1)).to equal(script)
    end

    it 'sets the current script identity for an async cleanup thread' do
      child = build_script('child')
      script_class.class_variable_set(:@@running, [child])
      observed = Queue.new
      child.at_exit { observed << script_class.current }

      child.kill

      expect(observed.pop).to equal(child)
      expect(child.join(1)).to equal(child)
    end

    it 'releases async cleanup when the killing caller is killed mid-transition' do
      script = build_script('kill-transition')
      script_class.class_variable_set(:@@running, [script])
      attach_entered = Queue.new
      release_attach = Queue.new
      allow(script).to receive(:__claim_cleanup_thread).and_wrap_original do |method, thread|
        attach_entered << true
        release_attach.pop
        method.call(thread)
      end
      killer = Thread.new { script.kill }
      attach_entered.pop

      killer.kill
      release_attach << true
      killer.join

      expect(script.join(1)).to equal(script)
      expect(script).not_to be_running
    end

    it 'keeps target cleanup alive when the caller script is killed during handoff' do
      caller_script = build_script('caller')
      target_script = build_script('target')
      script_class.class_variable_set(:@@running, [caller_script, target_script])
      attach_entered = Queue.new
      release_attach = Queue.new
      allow(target_script).to receive(:__claim_cleanup_thread).and_wrap_original do |method, thread|
        attach_entered << true
        release_attach.pop
        method.call(thread)
      end
      start_kill = Queue.new
      killer = Thread.new { start_kill.pop; target_script.kill }
      caller_script.thread_group.add(killer)
      start_kill << true
      attach_entered.pop

      caller_script.kill
      release_attach << true

      expect(caller_script.join(1)).to equal(caller_script)
      expect(target_script.join(1)).to equal(target_script)
    end

    it 'runs cleanup when the killing caller is cancelled before worker allocation' do
      script = build_script('kill-allocation-transition')
      script_class.class_variable_set(:@@running, [script])
      start_kill = Queue.new
      allocation_entered = Queue.new
      killer = Thread.new { start_kill.pop; script.kill }
      allow(Thread).to receive(:new).and_wrap_original do |method, *args, &block|
        allocation_entered << true
        Queue.new.pop
        method.call(*args, &block)
      end

      start_kill << true
      allocation_entered.pop
      killer.kill
      killer.join

      expect(script.join(1)).to equal(script)
      expect(script).not_to be_running
    end

    it 'recovers when an asynchronous cleanup executor is killed' do
      script = build_script('abandoned-cleanup')
      script_class.class_variable_set(:@@running, [script])
      cleanup_entered = Queue.new
      first_cleanup = true
      allow(script).to receive(:__run_kill_cleanup).and_wrap_original do |method, **kwargs|
        if first_cleanup
          first_cleanup = false
          cleanup_entered << true
          Queue.new.pop
        else
          method.call(**kwargs)
        end
      end

      script.kill
      cleanup_entered.pop
      cleanup_thread = Object.instance_method(:instance_variable_get).bind_call(script, :@cleanup_thread)
      cleanup_thread.kill
      cleanup_thread.join

      script_class.progress_shutdown
      expect(script.join(1)).to equal(script)
      expect(script).not_to be_running
    end

    it 'recovers a dead cleanup executor when explicitly killed again' do
      script = build_script('runtime-cleanup-retry')
      script_class.class_variable_set(:@@running, [script])
      cleanup_entered = Queue.new
      first_cleanup = true
      allow(script).to receive(:__run_kill_cleanup).and_wrap_original do |method, **kwargs|
        if first_cleanup
          first_cleanup = false
          cleanup_entered << true
          Queue.new.pop
        else
          method.call(**kwargs)
        end
      end

      script.kill
      cleanup_entered.pop
      cleanup_thread = Object.instance_method(:instance_variable_get).bind_call(script, :@cleanup_thread)
      cleanup_thread.kill
      cleanup_thread.join

      script.kill

      expect(script.join(1)).to equal(script)
      expect(script).not_to be_running
    end

    it 'completes cleanup when the launch-gate ensure is interrupted' do
      script = build_script('interrupted-cleanup-gate')
      script_class.class_variable_set(:@@running, [script])
      interrupt_next_queue_release(:before)
      allow(script).to receive(:__claim_cleanup_thread).and_raise(RuntimeError, 'handoff failed')

      expect { script.kill }.to raise_error(Exception)

      expect(script.join(1)).to equal(script)
      expect(script).not_to be_running
    end

    it 'rechecks a dead cleanup executor after launch completion' do
      script = build_script('cleanup-launch-recheck')
      script_class.class_variable_set(:@@running, [script])
      cleanup_entered = Queue.new
      finish_entered = Queue.new
      release_finish = Queue.new
      first_cleanup = true
      finish_blocked = false
      allow(script).to receive(:__run_kill_cleanup).and_wrap_original do |method, **kwargs|
        if first_cleanup
          first_cleanup = false
          cleanup_entered << true
          Queue.new.pop
        else
          method.call(**kwargs)
        end
      end
      allow(script).to receive(:__finish_cleanup_launch).and_wrap_original do |method|
        unless finish_blocked
          finish_blocked = true
          finish_entered << true
          release_finish.pop
        end
        method.call
      end

      first_killer = Thread.new { script.kill }
      cleanup_entered.pop
      finish_entered.pop
      cleanup_thread = Object.instance_method(:instance_variable_get).bind_call(script, :@cleanup_thread)
      cleanup_thread.kill
      cleanup_thread.join

      expect(Thread.new { script.kill }.value).to eq(script.name)
      release_finish << true
      first_killer.join

      expect(script.join(1)).to equal(script)
      expect(script).not_to be_running
    ensure
      release_finish << true if defined?(release_finish) && release_finish
      first_killer&.kill
    end

    it 'does not run abandoned cleanup recovery on a target worker' do
      script = build_script('worker-cleanup-retry')
      script_class.class_variable_set(:@@running, [script])
      cleanup_entered = Queue.new
      retry_kill = Queue.new
      cleanup_executors = Queue.new
      first_cleanup = true
      allow(script).to receive(:__run_kill_cleanup).and_wrap_original do |method, **kwargs|
        if first_cleanup
          first_cleanup = false
          cleanup_entered << true
          Queue.new.pop
        else
          cleanup_executors << Thread.current
          method.call(**kwargs)
        end
      end
      worker = Thread.new do
        retry_kill.pop
        script.kill
      end
      script.thread_group.add(worker)

      script.kill
      cleanup_entered.pop
      cleanup_thread = Object.instance_method(:instance_variable_get).bind_call(script, :@cleanup_thread)
      cleanup_thread.kill
      cleanup_thread.join
      retry_kill << true

      expect(cleanup_executors.pop).not_to equal(worker)
      expect(script.join(1)).to equal(script)
      expect(worker).not_to be_alive
      expect(script).not_to be_running
    ensure
      retry_kill << true if defined?(retry_kill) && retry_kill
      worker&.kill
      worker&.join
    end

    it 'resumes remaining exit callbacks after cleanup executor cancellation' do
      script = build_script('cancelled-callback')
      script_class.class_variable_set(:@@running, [script])
      first_callback_entered = Queue.new
      second_callback_ran = Queue.new
      first_callback_calls = 0
      script.at_exit do
        first_callback_calls += 1
        first_callback_entered << true
        Queue.new.pop
      end
      script.at_exit { second_callback_ran << true }

      script.kill
      first_callback_entered.pop
      cleanup_thread = Object.instance_method(:instance_variable_get).bind_call(script, :@cleanup_thread)
      cleanup_thread.kill
      cleanup_thread.join

      expect(script).to be_running
      script_class.progress_shutdown

      expect(second_callback_ran.pop(true)).to be(true)
      expect(first_callback_calls).to eq(1)
      expect(script.join(1)).to equal(script)
    end

    it 'retries an exit callback when cancellation interrupts its dequeue' do
      dequeue_interrupted = Queue.new
      release_dequeue = Queue.new
      interrupting_callbacks = Class.new(Array) do
        define_method(:shift) do
          entry = super()
          unless defined?(@interrupted)
            @interrupted = true
            dequeue_interrupted << true
            release_dequeue.pop
          end
          entry
        end
      end
      callback_calls = 0
      callback = proc { callback_calls += 1 }
      script = build_script('cancelled-callback-dequeue')
      script.instance_variable_set(:@at_exit_procs, interrupting_callbacks.new([callback, callback]))
      script_class.class_variable_set(:@@running, [script])

      cleanup_thread = Thread.new { script.kill(:context => :shutdown, :async => false) }
      Timeout.timeout(1) { dequeue_interrupted.pop }
      script.at_exit { callback_calls += 10 }
      cleanup_thread.kill
      cleanup_thread.join
      script_class.progress_shutdown

      expect(script.join(1)).to equal(script)
      expect(callback_calls).to eq(12)
    ensure
      release_dequeue << true if defined?(release_dequeue) && release_dequeue
    end

    it 'retries a die-with callback when cancellation interrupts its dequeue' do
      dequeue_interrupted = Queue.new
      release_dequeue = Queue.new
      interrupting_callbacks = Class.new(Array) do
        define_method(:shift) do
          entry = super()
          unless defined?(@interrupted)
            @interrupted = true
            dequeue_interrupted << true
            release_dequeue.pop
          end
          entry
        end
      end
      script = build_script('cancelled-die-with-dequeue')
      script.instance_variable_set(:@die_with, interrupting_callbacks.new(['target']))
      script_class.class_variable_set(:@@running, [script])
      allow(script_class).to receive(:kill).with('target', hash_including(:context)).and_return(true)

      cleanup_thread = Thread.new { script.kill(:context => :shutdown, :async => false) }
      Timeout.timeout(1) { dequeue_interrupted.pop }
      cleanup_thread.kill
      cleanup_thread.join
      script_class.progress_shutdown

      expect(script.join(1)).to equal(script)
      expect(script_class).to have_received(:kill).once
    ensure
      release_dequeue << true if defined?(release_dequeue) && release_dequeue
    end

    it 'does not duplicate a callback when claim restoration is interrupted' do
      interrupting_callbacks = Class.new(Array) do
        def shift
          entry = super()
          unless defined?(@shift_interrupted)
            @shift_interrupted = true
            raise RuntimeError, 'dequeue interrupted'
          end
          entry
        end

        def unshift(*entries)
          result = super
          unless defined?(@restore_interrupted)
            @restore_interrupted = true
            Thread.current.kill
          end
          result
        end

        def []=(index, entry)
          if @interrupt_assignment
            @interrupt_assignment = false
            Thread.current.kill
          end
          super
        end
      end
      callback_calls = 0
      callback = proc { callback_calls += 1 }
      callbacks = interrupting_callbacks.new([callback])
      script = build_script('interrupted-claim-restore')
      cleanup_thread = Thread.new do
        script.__send__(:__run_cleanup_queue, callbacks) { |entry| entry.call }
      end
      cleanup_thread.report_on_exception = false
      cleanup_thread.join
      callbacks.instance_variable_set(:@interrupt_assignment, true)
      retry_thread = Thread.new do
        script.__send__(:__run_cleanup_queue, callbacks) { |entry| entry.call }
      end
      retry_thread.report_on_exception = false
      retry_thread.join
      script.__send__(:__run_cleanup_queue, callbacks) { |entry| entry.call }

      expect(callbacks).to be_empty
      expect(callback_calls).to eq(1)
    ensure
      cleanup_thread&.kill
      retry_thread&.kill
    end

    it 'does not run deferred cleanup from a timeout-bounded join' do
      script = build_script('observational-join')
      script_class.class_variable_set(:@@running, [script])
      script.instance_variable_set(:@kill_requested, true)
      expect(script).not_to receive(:__refresh_deferred_stop)

      expect(script.join(0.01)).to be_nil
    end

    it 'bounds shutdown kill_sync before a blocked exit callback finishes' do
      script = build_script('bounded-shutdown-kill')
      script_class.class_variable_set(:@@running, [script])
      callback_entered = Queue.new
      release_callback = Queue.new
      script.at_exit { callback_entered << true; release_callback.pop }

      expect(script.kill_sync(:context => :shutdown, :timeout => 0.02)).to be_nil
      callback_entered.pop

      release_callback << true
      expect(script.join(1)).to equal(script)
    end

    it 'waits indefinitely for teardown when no timeout is given' do
      worker_ready = Queue.new
      worker_cleanup_entered = Queue.new
      release_worker_cleanup = Queue.new
      script = subscript_class.start(:parent => nil) do
        worker_ready << true
        begin
          Queue.new.pop
        ensure
          worker_cleanup_entered << true
          release_worker_cleanup.pop
        end
      end
      worker_ready.pop

      script.kill
      worker_cleanup_entered.pop
      waiter = Thread.new { script.join }

      expect(waiter.join(0.05)).to be_nil

      release_worker_cleanup << true
      expect(waiter.value).to equal(script)
    end

    it 'keeps shutdown snapshots free of teardown side effects' do
      script = build_script('deferred-cleanup')
      script_class.class_variable_set(:@@stopping, [script])
      allow(script).to receive(:__refresh_deferred_stop)

      expect(script_class.shutdown_scripts).to contain_exactly(script)
      expect(script).not_to have_received(:__refresh_deferred_stop)

      expect(script_class.progress_shutdown).to contain_exactly(script)
      expect(script).to have_received(:__refresh_deferred_stop).once
    end

    it 'finishes inline cleanup when the killing caller is cancelled' do
      script = build_script('cancelled-inline-cleanup')
      script_class.class_variable_set(:@@running, [script])
      cleanup_entered = Queue.new
      first_cleanup = true
      allow(script).to receive(:__run_kill_cleanup).and_wrap_original do |method, **kwargs|
        if first_cleanup
          first_cleanup = false
          cleanup_entered << true
          Queue.new.pop
        else
          method.call(**kwargs)
        end
      end
      killer = Thread.new { script.kill(:context => :shutdown) }
      cleanup_entered.pop

      killer.kill
      killer.join

      expect(script.join(1)).to equal(script)
      expect(script).not_to be_running
    end

    it 'signals completion even when cleanup raises' do
      script = build_script('bad-cleanup')
      script.die_with << '('
      script_class.class_variable_set(:@@running, [script])

      expect(script.kill_sync(timeout: 1)).to equal(script)
      expect(script).not_to be_running
    end

    it 'stops later children when an earlier runtime child cleanup blocks' do
      stub_const('Lich::Common::Script::CHILD_JOIN_TIMEOUT', 0.03)
      parent = build_script('parent')
      blocked = build_script('blocked')
      sibling = build_script('sibling')
      script_class.class_variable_set(:@@running, [parent, blocked, sibling])
      parent.register_child(blocked)
      parent.register_child(sibling)
      entered = Queue.new
      release = Queue.new
      blocked.at_exit { entered << true; release.pop }

      parent.kill
      entered.pop

      expect(sibling).not_to be_running
      expect(blocked).to be_running
      expect(parent.join(1)).to equal(parent)
      expect(parent.child_scripts).to contain_exactly(blocked)

      release << true
      expect(blocked.join(1)).to equal(blocked)
      expect(parent.child_scripts).to be_empty
    end

    it 'retains a timed-out child until its worker ensure block finishes' do
      stub_const('Lich::Common::Script::CHILD_JOIN_TIMEOUT', 0.03)
      parent = build_script('parent')
      script_class.class_variable_set(:@@running, [parent])
      worker_ready = Queue.new
      worker_cleanup_entered = Queue.new
      release_worker_cleanup = Queue.new
      child = subscript_class.start(:parent => parent) do
        worker_ready << true
        begin
          Queue.new.pop
        ensure
          worker_cleanup_entered << true
          release_worker_cleanup.pop
        end
      end
      worker_ready.pop

      parent.kill
      worker_cleanup_entered.pop
      expect(parent.join(1)).to equal(parent)
      expect(child).not_to be_running
      expect(parent.child_scripts).to contain_exactly(child)
      expect(script_class.shutdown_scripts).to include(child)

      release_worker_cleanup << true
      expect(child.join(1)).to equal(child)
      expect(parent.child_scripts).to be_empty
      expect(script_class.shutdown_scripts).to be_empty
    end

    it 'rejects workers created after teardown begins' do
      script = build_script('late-worker')
      script.want_downstream = false
      script_class.class_variable_set(:@@running, [script])
      cleanup_entered = Queue.new
      release_cleanup = Queue.new
      callback_ran = Queue.new
      script.watchfor[/trigger/] = proc { callback_ran << true }
      script.at_exit { cleanup_entered << true; release_cleanup.pop }

      script.kill
      cleanup_entered.pop
      script_class.new_downstream('trigger')
      sleep 0.02

      expect { callback_ran.pop(true) }.to raise_error(ThreadError)

      release_cleanup << true
      expect(script.join(1)).to equal(script)
    end

    it 'releases a watchfor worker when dispatch is cancelled after registration' do
      script = build_script('cancelled-watchfor')
      script_class.class_variable_set(:@@running, [script])
      script.watchfor[/trigger/] = proc {}
      registration_complete = Queue.new
      allow(script).to receive(:__register_worker).and_wrap_original do |method, thread|
        result = method.call(thread)
        registration_complete << true
        Queue.new.pop
        result
      end
      dispatcher = Thread.new { script_class.new_downstream('trigger') }
      registration_complete.pop

      dispatcher.kill
      dispatcher.join

      expect(script.__send__(:__worker_threads)).to all(satisfy { |thread| !thread.alive? })
      script.kill(:context => :shutdown)
    end

    it 'rejects and joins workers added directly during teardown' do
      script = build_script('direct-late-worker')
      script_class.class_variable_set(:@@running, [script])
      cleanup_entered = Queue.new
      release_cleanup = Queue.new
      worker_ready = Queue.new
      worker_cleanup_entered = Queue.new
      release_worker_cleanup = Queue.new
      script.at_exit { cleanup_entered << true; release_cleanup.pop }

      script.kill
      cleanup_entered.pop
      late_worker = Thread.new do
        worker_ready << true
        begin
          Queue.new.pop
        ensure
          worker_cleanup_entered << true
          release_worker_cleanup.pop
        end
      end
      worker_ready.pop
      registration_error = Queue.new
      registrar = Thread.new do
        script.thread_group.add(late_worker)
      rescue ThreadError => e
        registration_error << e
      end
      worker_cleanup_entered.pop
      release_cleanup << true
      expect(script.join(0.02)).to be_nil

      release_worker_cleanup << true
      registrar.join
      expect(registration_error.pop.message).to match(/stopping script/)
      expect(script.join(1)).to equal(script)
    end

    it 'releases rejected worker registration when the registrar is cancelled' do
      script = build_script('cancelled-registration')
      script_class.class_variable_set(:@@running, [script])
      cleanup_entered = Queue.new
      release_cleanup = Queue.new
      worker_cleanup_entered = Queue.new
      release_worker_cleanup = Queue.new
      script.at_exit { cleanup_entered << true; release_cleanup.pop }
      script.kill
      cleanup_entered.pop
      worker = Thread.new do
        begin
          Queue.new.pop
        ensure
          worker_cleanup_entered << true
          release_worker_cleanup.pop
        end
      end
      registrar = Thread.new { script.thread_group.add(worker) }
      worker_cleanup_entered.pop

      registrar.kill
      release_worker_cleanup << true
      registrar.join
      release_cleanup << true

      expect(script.join(1)).to equal(script)
    end

    it 'preserves an underlying thread-group rejection when worker teardown raises' do
      script = build_script('group-rejection')
      script_class.class_variable_set(:@@running, [script])
      source_group = ThreadGroup.new
      worker = Thread.new do
        Thread.current.report_on_exception = false
        begin
          Queue.new.pop
        ensure
          raise 'worker teardown failed'
        end
      end
      source_group.add(worker)
      source_group.enclose

      expect { script.thread_group.add(worker) }.to raise_error(ThreadError, /enclosed/)
    end

    it 'does not block shutdown cleanup on a worker ensure block' do
      worker_ready = Queue.new
      worker_cleanup_entered = Queue.new
      release_worker_cleanup = Queue.new
      script = subscript_class.start(:parent => nil) do
        worker_ready << true
        begin
          Queue.new.pop
        ensure
          worker_cleanup_entered << true
          release_worker_cleanup.pop
        end
      end
      worker_ready.pop
      shutdown_kill = Thread.new { script.kill(:context => :shutdown) }
      worker_cleanup_entered.pop

      expect(shutdown_kill.join(0.2)).to equal(shutdown_kill)
      expect(script_class.shutdown_scripts).to include(script)

      release_worker_cleanup << true
      progress_shutdown_until(script)
      expect(script.join(1)).to equal(script)
    end

    it 'joins descendant workers spawned from a killed worker ensure block' do
      worker_ready = Queue.new
      descendant_ready = Queue.new
      descendant_cleanup_entered = Queue.new
      release_descendant_cleanup = Queue.new
      script = nil
      script = subscript_class.start(:parent => nil) do
        worker_ready << true
        begin
          Queue.new.pop
        ensure
          descendant = Thread.new do
            descendant_ready << true
            begin
              Queue.new.pop
            ensure
              descendant_cleanup_entered << true
              release_descendant_cleanup.pop
            end
          end
          descendant_ready.pop
          begin
            script.thread_group.add(descendant)
          rescue ThreadError
            nil
          end
        end
      end
      worker_ready.pop

      script.kill
      descendant_cleanup_entered.pop
      expect(script.join(0.02)).to be_nil

      release_descendant_cleanup << true
      expect(script.join(1)).to equal(script)
    end

    it 'joins descendant workers spawned by exit callbacks' do
      script = build_script('callback-descendant')
      script_class.class_variable_set(:@@running, [script])
      worker_ready = Queue.new
      worker_cleanup_entered = Queue.new
      release_worker_cleanup = Queue.new
      descendant = nil
      script.at_exit do
        descendant = Thread.new do
          worker_ready << true
          begin
            Queue.new.pop
          ensure
            worker_cleanup_entered << true
            release_worker_cleanup.pop
          end
        end
        worker_ready.pop
      end

      script.kill
      worker_cleanup_entered.pop
      expect(script.thread_group.list).not_to include(descendant)
      expect(descendant.group).not_to equal(script.thread_group)
      expect(script.join(0.02)).to be_nil

      release_worker_cleanup << true
      expect(script.join(1)).to equal(script)
    end

    it 'assigns descendants from nested cleanup to the inner script' do
      outer_script = build_script('outer-cleanup')
      inner_script = build_script('inner-cleanup')
      script_class.class_variable_set(:@@running, [outer_script, inner_script])
      descendant_ready = Queue.new
      descendant_owner = Queue.new
      descendant_cleanup_entered = Queue.new
      release_descendant_cleanup = Queue.new
      inner_completed = Queue.new
      inner_script.at_exit do
        Thread.new do
          descendant_owner << script_class.current
          descendant_ready << true
          begin
            Queue.new.pop
          ensure
            descendant_cleanup_entered << true
            release_descendant_cleanup.pop
          end
        end
        descendant_ready.pop
      end
      outer_script.at_exit do
        inner_script.kill(:context => :shutdown, :async => false)
        inner_completed << inner_script.__send__(:__cleanup_complete?)
      end

      outer_script.kill(:context => :shutdown, :async => false)

      expect(descendant_owner.pop).to equal(inner_script)
      expect(inner_completed.pop).to be(false)
      descendant_cleanup_entered.pop
      release_descendant_cleanup << true
      progress_shutdown_until(inner_script)
      progress_shutdown_until(outer_script)
      expect(inner_script.join(1)).to equal(inner_script)
      expect(outer_script.join(1)).to equal(outer_script)
    ensure
      release_descendant_cleanup << true if defined?(release_descendant_cleanup) && release_descendant_cleanup
    end

    it 'does not run callbacks when cleanup ownership cannot move from an enclosed group' do
      caller_script = build_script('enclosed-caller')
      target_script = build_script('ownership-target')
      child_script = build_script('ownership-child')
      script_class.class_variable_set(:@@running, [caller_script, target_script, child_script])
      target_script.register_child(child_script)
      callback_ran = false
      target_script.at_exit { callback_ran = true }
      result = Queue.new
      caller = Thread.new do
        target_script.kill(:context => :runtime, :async => false)
        result << script_class.current
      end
      caller_script.thread_group.add(caller)
      caller_script.thread_group.enclose

      caller.join

      expect(result.pop).to equal(caller_script)
      expect(target_script.join(1)).to equal(target_script)
      expect(child_script.join(1)).to equal(child_script)
      expect(target_script.child_scripts).to be_empty
      expect(callback_ran).to be(false)
      expect(target_script.exit_error).to be_a(ThreadError)
      expect(target_script.exit_error.message).to match(/cannot establish cleanup ownership/)
    end

    it 'does not run callbacks from an unmanaged non-default thread group' do
      target_script = build_script('unmanaged-ownership-target')
      script_class.class_variable_set(:@@running, [target_script])
      callback_ran = false
      target_script.at_exit { callback_ran = true }
      source_group = ThreadGroup.new
      caller = Thread.new do
        target_script.kill(:context => :shutdown, :async => false)
      end
      source_group.add(caller)

      caller.join

      expect(target_script.join(1)).to equal(target_script)
      expect(callback_ran).to be(false)
      expect(target_script.exit_error).to be_a(ThreadError)
      expect(target_script.exit_error.message).to match(/source thread group is not managed/)
    end

    it 'recognizes cleanup ownership from a script already in the stopping registry' do
      caller_script = build_script('stopping-owner')
      target_script = build_script('stopping-owner-target')
      script_class.class_variable_set(:@@running, [caller_script, target_script])
      callback_ran = false
      target_script.at_exit { callback_ran = true }
      caller = Thread.new do
        target_script.kill(:context => :shutdown, :async => false)
      end
      caller_script.thread_group.add(caller)
      script_class.class_variable_set(:@@running, [target_script])
      script_class.class_variable_set(:@@stopping, [caller_script])

      caller.join

      expect(target_script.join(1)).to equal(target_script)
      expect(callback_ran).to be(true)
      expect(target_script.exit_error).to be_nil
    ensure
      caller&.kill
    end

    it 'does not detach an inline cleanup caller when its group becomes enclosed' do
      caller_script = build_script('caller')
      target_script = build_script('target')
      script_class.class_variable_set(:@@running, [caller_script, target_script])
      observed = Queue.new
      start_cleanup = Queue.new
      descendant_ready = Queue.new
      descendant_cleanup_entered = Queue.new
      release_descendant_cleanup = Queue.new
      later_descendant_ready = Queue.new
      later_descendant_cleanup_entered = Queue.new
      release_later_descendant_cleanup = Queue.new
      target_script.at_exit do
        Thread.new do
          descendant_ready << true
          begin
            Queue.new.pop
          ensure
            descendant_cleanup_entered << true
            release_descendant_cleanup.pop
          end
        end
        descendant_ready.pop
        caller_script.thread_group.enclose
      end
      caller = Thread.new do
        start_cleanup.pop
        target_script.kill(:context => :shutdown, :async => false)
        Thread.new do
          later_descendant_ready << true
          begin
            Queue.new.pop
          ensure
            later_descendant_cleanup_entered << true
            release_later_descendant_cleanup.pop
          end
        end
        later_descendant_ready.pop
        observed << script_class.current
      end
      caller_script.thread_group.add(caller)
      start_cleanup << true

      descendant_cleanup_entered.pop
      expect(target_script.join(0.02)).to be_nil
      release_descendant_cleanup << true
      expect(observed.pop).to equal(caller_script)
      caller.join
      progress_shutdown_until(target_script)
      expect(target_script.join(1)).to equal(target_script)
      caller_script.kill
      later_descendant_cleanup_entered.pop
      expect(caller_script.join(0.02)).to be_nil
      release_later_descendant_cleanup << true
      expect(caller_script.join(1)).to equal(caller_script)
    end

    it 'allows a killed worker to join its own stopping script' do
      worker_ready = Queue.new
      worker_joined = Queue.new
      script = nil
      script = subscript_class.start(:parent => nil) do
        worker_ready << true
        begin
          Queue.new.pop
        ensure
          worker_joined << script.join(1)
        end
      end
      worker_ready.pop

      script.kill

      expect(worker_joined.pop).to equal(script)
      expect(script.join(1)).to equal(script)
    end

    it 'finishes teardown when a killed worker ensure block raises' do
      worker_ready = Queue.new
      script = build_script('raising-worker')
      script_class.class_variable_set(:@@running, [script])
      worker = Thread.new do
        Thread.current.report_on_exception = false
        worker_ready << true
        begin
          Queue.new.pop
        ensure
          raise 'worker cleanup failed'
        end
      end
      script.thread_group.add(worker)
      worker_ready.pop

      script.kill

      expect(script.join(1)).to equal(script)
      expect(script).not_to be_running
      expect(script.exit_error).to be_a(RuntimeError)
    end

    it 'does not complete join until parent unlinking finishes' do
      parent = build_script('parent')
      child = build_script('child')
      script_class.class_variable_set(:@@running, [parent, child])
      expect(parent.register_child(child)).to equal(child)
      parent_lock_held = Queue.new
      release_parent_lock = Queue.new
      parent_mutex = parent.__send__(:child_scripts_mutex)
      lock_holder = Thread.new do
        parent_mutex.synchronize do
          parent_lock_held << true
          release_parent_lock.pop
        end
      end
      parent_lock_held.pop

      child.kill
      expect(child.join(0.02)).to be_nil
      children = Object.instance_method(:instance_variable_get).bind_call(parent, :@child_scripts)
      expect(children).to contain_exactly(child)

      release_parent_lock << true
      lock_holder.join
      expect(child.join(1)).to equal(child)
      expect(parent.child_scripts).to be_empty
    end

    it 'retries parent unlinking when its finalizer is cancelled' do
      parent = build_script('parent')
      child = build_script('child')
      script_class.class_variable_set(:@@running, [parent, child])
      expect(parent.register_child(child)).to equal(child)
      parent_mutex = parent.__send__(:child_scripts_mutex)
      parent_mutex.lock

      child.kill
      sleep 0.005 while child.running?
      cleanup_thread = Object.instance_method(:instance_variable_get).bind_call(child, :@cleanup_thread)
      cleanup_thread.kill
      cleanup_thread.join
      children = Object.instance_method(:instance_variable_get).bind_call(parent, :@child_scripts)
      expect(Array(children)).to contain_exactly(child)

      parent_mutex.unlock
      script_class.progress_shutdown

      expect(child.join(1)).to equal(child)
      expect(parent.child_scripts).to be_empty
    ensure
      parent_mutex&.unlock if parent_mutex&.owned?
    end

    it 'prunes completed scripts from the stopping registry snapshot' do
      script = build_script('completed-stop')
      script.instance_variable_set(:@cleanup_complete, true)
      script_class.class_variable_set(:@@stopping, [script])

      expect(script_class.shutdown_scripts).to be_empty
      expect(script_class.class_variable_get(:@@stopping)).to be_empty
    end

    it 'holds child lifecycle state through public adoption' do
      parent = build_script('parent')
      child = build_script('child')
      script_class.class_variable_set(:@@running, [parent, child])
      adoption_entered = Queue.new
      release_adoption = Queue.new
      allow(parent).to receive(:__adopt_child_locked).and_wrap_original do |method, adopted|
        adoption_entered << true
        release_adoption.pop
        method.call(adopted)
      end

      registrar = Thread.new { parent.register_child(child) }
      adoption_entered.pop
      killer = Thread.new { child.kill_sync(:timeout => 1) }
      expect(killer.join(0.02)).to be_nil

      release_adoption << true
      expect(registrar.value).to equal(child)
      expect(killer.value).to equal(child)
      expect(parent.child_scripts).to be_empty
    end

    it 'preserves the standard ThreadGroup surface' do
      script = build_script('thread-group-api')
      script_class.class_variable_set(:@@running, [script])
      worker = Thread.new { Queue.new.pop }

      expect(script.thread_group).to be_a(ThreadGroup)
      expect(script.thread_group).to be_instance_of(ThreadGroup)
      expect(script.thread_group.add(worker)).to equal(script.thread_group)
      expect(worker.group).to equal(script.thread_group)
      expect { script.thread_group.add(Object.new) }.to raise_error(TypeError, /expected VM\/thread/)
      expect(script.thread_group).not_to be_enclosed
      expect(script.thread_group.enclose).to equal(script.thread_group)
      expect(script.thread_group).to be_enclosed
      other_group = ThreadGroup.new
      expect { other_group.add(worker) }.to raise_error(ThreadError, /enclosed/)
      expect(worker.group).to equal(script.thread_group)
    ensure
      worker&.kill
      worker&.join
    end

    it 'rejects self-registration without stopping the caller' do
      script = build_script('self-registration')
      script_class.class_variable_set(:@@running, [script])
      script.instance_variable_set(:@kill_requested, true)

      expect { script.thread_group.add(Thread.current) }.to raise_error(ThreadError, /stopping script/)
      expect(Thread.current).to be_alive
      stopping_threads = Object.instance_method(:instance_variable_get).bind_call(script, :@stopping_threads)
      expect(Array(stopping_threads)).not_to include(Thread.current)
    end

    it 'runs teardown callbacks after the public thread group is enclosed' do
      script = build_script('enclosed-thread-group')
      script_class.class_variable_set(:@@running, [script])
      callback_ran = false
      script.at_exit { callback_ran = true }
      script.thread_group.enclose

      expect(script.kill_sync(:timeout => 1)).to equal(script)
      expect(callback_ran).to be(true)
      expect(script_class.class_variable_get(:@@stopping)).to be_empty
    end

    it 'kills a worker when native thread-group registration fails' do
      script = build_script('group-rejection')
      script_class.class_variable_set(:@@running, [script])
      source_group = ThreadGroup.new
      worker = Thread.new { Queue.new.pop }
      source_group.add(worker)
      source_group.enclose

      expect { script.thread_group.add(worker) }.to raise_error(ThreadError, /enclosed/)
      expect(worker).not_to be_alive
    ensure
      worker&.kill
      worker&.join
    end

    it 'records cleanup callback failures in lifecycle completion' do
      script = build_script('cleanup-error')
      script_class.class_variable_set(:@@running, [script])
      script.__send__(:__record_successful_exit)
      script.at_exit { raise 'cleanup failed' }

      script.kill

      expect(script.join(1)).to equal(script)
      expect(script.exit_error).to be_a(RuntimeError)
      expect(script).not_to be_completed_successfully
    end
  end

  describe 'library loading' do
    let(:library_script) do
      instance_double(
        script_class,
        :name                    => 'libutil',
        :join                    => true,
        :exit_error              => nil,
        :completed_successfully? => true
      )
    end

    before do
      allow(script_class).to receive(:__find_script_file).and_return('/custom/libutil.lic')
    end

    it 'starts a library only once across concurrent callers' do
      allow(script_class).to receive(:start).with('libutil', { :force => true }).and_return(library_script)

      callers = Array.new(4) { Thread.new { script_class.loadlib('util') } }
      callers.each(&:join)

      expect(script_class).to have_received(:start).with('libutil', { :force => true }).once
      expect(script_class.libs).to eq(Set['libutil'])
    end

    it 'elects one replacement when a reserved library startup is abandoned' do
      startup_token = Object.new
      admitted = Queue.new
      owner = Thread.new do
        script_class.__send__(:__begin_start, startup_token, 'libutil', :force => false)
        admitted << true
        Queue.new.pop
      end
      admitted.pop
      start_entered = Queue.new
      release_start = Queue.new
      allow(script_class).to receive(:start).with('libutil', { :force => true }) do
        start_entered << true
        release_start.pop
        library_script
      end
      loaders = Array.new(2) { Thread.new { script_class.loadlib('util') } }
      waiters = script_class.class_variable_get(:@@completed_start_waiters)
      Timeout.timeout(1) do
        Thread.pass until completed_start_waiter_count(waiters, 'libutil') == loaders.length
      end

      owner.kill
      owner.join
      Timeout.timeout(1) { start_entered.pop }

      reservations = script_class.class_variable_get(:@@startup_reservations)
      expect(reservations.values.map(&:first)).to include('libutil')
      expect(script_class).to have_received(:start).once

      release_start << true
      expect(loaders.map(&:value)).to all be(true)
      expect(script_class).to have_received(:start).once
    ensure
      owner&.kill
      release_start << true if defined?(release_start) && release_start
      loaders&.each(&:kill)
    end

    it 'lets a peer commit completion when the loader owner is cancelled' do
      owner_join_entered = Queue.new
      join_calls = 0
      allow(library_script).to receive(:join) do
        join_calls += 1
        if join_calls == 1
          owner_join_entered << true
          Queue.new.pop
        else
          true
        end
      end
      allow(script_class).to receive(:start).with('libutil', { :force => true }).and_return(library_script)

      owner = Thread.new { script_class.loadlib('util') }
      owner_join_entered.pop
      expect(script_class.loadlib('util')).to be(true)
      owner.kill
      owner.join

      expect(script_class.libs).to include('libutil')
      expect(script_class.class_variable_get(:@@loading_libraries)).to be_empty
    end

    it 'publishes a started library before loader cancellation can take effect' do
      allow(script_class).to receive(:start).with('libutil', { :force => true }) do
        script_class.class_variable_set(:@@completed_named_starts, 'libutil' => library_script)
        Thread.current.kill
        library_script
      end

      loader = Thread.new { script_class.loadlib('util') }
      loader.join

      expect(script_class.class_variable_get(:@@loading_libraries)).to eq('libutil' => library_script)
      expect(script_class.loadlib('util')).to be(true)
      expect(script_class).to have_received(:start).with('libutil', { :force => true }).once
    end

    it 'starts a library without holding the library registry mutex' do
      library_mutex = script_class.class_variable_get(:@@library_mutex)
      mutex_locked_during_start = nil
      allow(script_class).to receive(:start).with('libutil', { :force => true }) do
        mutex_locked_during_start = library_mutex.locked?
        library_script
      end

      expect(script_class.loadlib('util')).to be(true)
      expect(mutex_locked_during_start).to be(false)
    end

    it 'keeps a timed-out generation as the single-flight owner for retry' do
      timed_out_script = instance_double(
        script_class,
        :name                    => 'libutil',
        :exit_error              => nil,
        :completed_successfully? => true
      )
      join_calls = 0
      allow(timed_out_script).to receive(:join) do
        join_calls += 1
        join_calls == 1 ? nil : timed_out_script
      end
      allow(script_class).to receive(:start).with('libutil', { :force => true }).and_return(timed_out_script)

      expect {
        script_class.loadlib('util', :timeout => 0.01)
      }.to raise_error(script_class::LibraryJoinTimeout, /wait timed out/)
      expect(script_class.libs).to be_empty
      expect(script_class.class_variable_get(:@@loading_libraries)).to eq('libutil' => timed_out_script)

      expect(script_class.loadlib('util', :timeout => 0.01)).to be(true)
      expect(script_class).to have_received(:start).with('libutil', { :force => true }).once
      expect(script_class.class_variable_get(:@@loading_libraries)).to be_empty
      expect(script_class.libs).to include('libutil')
    end

    it 'keeps a fast-path timeout as the single-flight owner for retry' do
      join_calls = 0
      allow(library_script).to receive(:join) do
        join_calls += 1
        join_calls == 1 ? nil : library_script
      end
      script_class.class_variable_set(:@@loading_libraries, 'libutil' => library_script)

      expect {
        script_class.loadlib('util', :timeout => 0.01)
      }.to raise_error(script_class::LibraryJoinTimeout, /wait timed out/)
      expect(script_class.class_variable_get(:@@loading_libraries)).to eq('libutil' => library_script)

      expect(script_class.loadlib('util', :timeout => 0.01)).to be(true)
      expect(script_class.class_variable_get(:@@loading_libraries)).to be_empty
      expect(script_class.libs).to include('libutil')
    end

    it 'adopts an admitted plain start across concurrent duplicate callers' do
      admitted_script = instance_double(
        script_class,
        :name                    => 'libutil',
        :join                    => true,
        :exit_error              => nil,
        :completed_successfully? => true
      )
      startup_token = Object.new
      script_class.__send__(:__begin_start, startup_token, 'libutil', :force => false)
      loaders = Array.new(3) { Thread.new { script_class.loadlib('util') } }
      waiters = script_class.class_variable_get(:@@completed_start_waiters)
      Timeout.timeout(1) do
        Thread.pass until completed_start_waiter_count(waiters, 'libutil') == loaders.length
      end
      allow(script_class).to receive(:start)

      script_class.__send__(:__finish_start, startup_token, admitted_script)

      expect(loaders.map(&:value)).to all be(true)
      expect(script_class).not_to have_received(:start)
      expect(script_class.libs).to include('libutil')
    end

    it 'preserves an adopted generation when cancelled before publishing it' do
      startup_token = Object.new
      script_class.__send__(:__begin_start, startup_token, 'libutil', :force => false)
      original_begin = script_class.method(:__begin_library_start)
      allow(script_class).to receive(:__begin_library_start) do |*args, **kwargs|
        result = original_begin.call(*args, **kwargs)
        Thread.current.kill
        result
      end
      loader = Thread.new { script_class.loadlib('util') }
      waiters = script_class.class_variable_get(:@@completed_start_waiters)
      Timeout.timeout(1) do
        Thread.pass until completed_start_waiter_count(waiters, 'libutil') == 1
      end

      script_class.__send__(:__finish_start, startup_token, library_script)
      loader.join
      allow(script_class).to receive(:__begin_library_start).and_call_original
      allow(script_class).to receive(:start)

      expect(script_class.loadlib('util')).to be(true)
      expect(script_class).not_to have_received(:start)
      expect(script_class.class_variable_get(:@@completed_named_starts)).to be_empty
    ensure
      loader&.kill
    end

    it 'clears an older completed generation when a newer startup fails' do
      old_generation = instance_double(script_class)
      script_class.class_variable_set(:@@completed_named_starts, { 'libutil' => old_generation })
      reservation = Object.new
      script_class.__send__(:__begin_start, reservation, 'libutil', :force => true)

      script_class.__send__(:__finish_start, reservation, nil)

      expect(script_class.class_variable_get(:@@completed_named_starts)).to be_empty
    end

    it 'does not let an older failed start erase a newer completion' do
      newer_generation = instance_double(script_class)
      older_reservation = Object.new
      newer_reservation = Object.new
      script_class.__send__(:__begin_start, older_reservation, 'libutil', :force => true)
      script_class.__send__(:__begin_start, newer_reservation, 'libutil', :force => true)
      script_class.class_variable_get(:@@completed_start_waiters)['libutil'] = 1

      script_class.__send__(:__finish_start, newer_reservation, newer_generation)
      script_class.__send__(:__finish_start, older_reservation, nil)

      completed = script_class.class_variable_get(:@@completed_named_starts)['libutil']
      expect(script_class.__send__(:__completed_start_value, completed)).to equal(newer_generation)
    end

    it 'does not let an older completion replace a newer completion' do
      older_generation = instance_double(script_class)
      newer_generation = instance_double(script_class)
      older_reservation = Object.new
      newer_reservation = Object.new
      script_class.__send__(:__begin_start, older_reservation, 'libutil', :force => true)
      script_class.__send__(:__begin_start, newer_reservation, 'libutil', :force => true)
      script_class.class_variable_get(:@@completed_start_waiters)['libutil'] = 1

      script_class.__send__(:__finish_start, newer_reservation, newer_generation)
      script_class.__send__(:__finish_start, older_reservation, older_generation)

      completed = script_class.class_variable_get(:@@completed_named_starts)['libutil']
      expect(script_class.__send__(:__completed_start_value, completed)).to equal(newer_generation)
    end

    it 'does not let a library reservation erase a newer completion' do
      adopted_generation = instance_double(script_class)
      newer_generation = instance_double(script_class)
      adopted_reservation = Object.new
      script_class.__send__(:__begin_start, adopted_reservation, 'libutil', :force => true)
      script_class.class_variable_get(:@@completed_start_waiters)['libutil'] = 1
      script_class.__send__(:__finish_start, adopted_reservation, adopted_generation)
      library_reservation = Object.new
      script_class.__send__(:__begin_library_start, library_reservation, 'libutil')
      newer_reservation = Object.new
      script_class.__send__(:__begin_start, newer_reservation, 'libutil', :force => true)

      script_class.__send__(:__finish_start, newer_reservation, newer_generation)
      script_class.__send__(:__finish_start, library_reservation, nil)

      completed = script_class.class_variable_get(:@@completed_named_starts)['libutil']
      expect(script_class.__send__(:__completed_start_value, completed)).to equal(newer_generation)
    end

    it 'does not retain a forced completion for another thread library reservation' do
      library_reservation = Object.new
      script_class.__send__(:__begin_library_start, library_reservation, 'libutil')
      completed_generation = instance_double(script_class)

      Thread.new do
        forced_reservation = Object.new
        script_class.__send__(:__begin_start, forced_reservation, 'libutil', :force => true)
        script_class.__send__(:__finish_start, forced_reservation, completed_generation)
      end.join

      expect(script_class.class_variable_get(:@@completed_named_starts)).to be_empty
    ensure
      if defined?(library_reservation) && library_reservation
        script_class.__send__(:__finish_start, library_reservation)
      end
    end

    it 'adopts a completed forced generation ahead of an older running generation' do
      old_generation = instance_double(script_class, :name => 'libutil', :running? => false)
      allow(old_generation).to receive(:join) { raise 'older generation should not be joined' }
      new_generation = instance_double(
        script_class,
        :name                    => 'libutil',
        :join                    => true,
        :exit_error              => nil,
        :completed_successfully? => true
      )
      script_class.class_variable_set(:@@running, [old_generation])
      allow(script_class).to receive(:current).and_return(nil)
      reservation = Object.new
      script_class.__send__(:__begin_start, reservation, 'libutil', :force => true)
      script_class.class_variable_get(:@@completed_start_waiters)['libutil'] = 1
      script_class.__send__(:__finish_start, reservation, new_generation)
      script_class.class_variable_get(:@@completed_start_waiters).delete('libutil')

      expect(script_class.loadlib('util')).to be(true)
      expect(old_generation).not_to have_received(:join)
      expect(script_class.libs).to include('libutil')
      expect(script_class.class_variable_get(:@@completed_named_starts)).to be_empty
    end

    it 'uses the resolved library name when adopting a prefix start' do
      admitted_script = instance_double(
        script_class,
        :name                    => 'libutility',
        :join                    => true,
        :exit_error              => nil,
        :completed_successfully? => true
      )
      allow(script_class).to receive(:__find_script_file).with('libutil').and_return('/custom/libutility.lic')
      startup_token = Object.new
      script_class.__send__(:__begin_start, startup_token, 'libutility', :force => false)
      loader = Thread.new { script_class.loadlib('util') }
      expect(loader.join(0.02)).to be_nil
      allow(script_class).to receive(:start)

      script_class.__send__(:__finish_start, startup_token, admitted_script)

      expect(loader.value).to be(true)
      expect(script_class).not_to have_received(:start)
      expect(script_class.libs).to include('libutility')
    end

    it 'allows retry when startup fails' do
      allow(script_class).to receive(:start).with('libutil', { :force => true }).and_return(nil, library_script)

      expect { script_class.loadlib('util') }.to raise_error(LoadError, /failed to start/)
      expect(script_class.libs).to be_empty
      expect(script_class.loadlib('util')).to be(true)
    end

    it 'allows retry when startup raises' do
      attempts = 0
      allow(script_class).to receive(:start).with('libutil', { :force => true }) do
        attempts += 1
        raise ThreadError, 'forced startup failure' if attempts == 1

        library_script
      end

      expect { script_class.loadlib('util') }.to raise_error(ThreadError, /forced/)
      expect(script_class.libs).to be_empty
      expect(script_class.class_variable_get(:@@loading_libraries)).to be_empty
      expect(script_class.loadlib('util')).to be(true)
    end

    it 'does not record a library whose execution fails' do
      error = RuntimeError.new('broken library')
      failed_script = instance_double(
        script_class,
        :name                    => 'libutil',
        :join                    => true,
        :exit_error              => error,
        :completed_successfully? => false
      )
      allow(script_class).to receive(:start).with('libutil', { :force => true }).and_return(failed_script)

      expect { script_class.loadlib('util') }.to raise_error(LoadError, /broken library/)
      expect(script_class.libs).to be_empty
    end

    it 'invalidates the cache when a rerun of a loaded library fails' do
      error = RuntimeError.new('broken rerun')
      failed_rerun = instance_double(
        script_class,
        :name                    => 'libutil',
        :exit_error              => error,
        :completed_successfully? => false
      )
      allow(failed_rerun).to receive(:join) do
        script_class.class_variable_get(:@@running).delete(failed_rerun)
        true
      end
      script_class.class_variable_set(:@@running, [failed_rerun])
      script_class.class_variable_set(:@@loaded_libraries, Set['libutil'])
      allow(script_class).to receive(:current).and_return(nil)

      expect { script_class.loadlib('util') }.to raise_error(LoadError, /broken rerun/)
      expect(script_class.libs).to be_empty
    end

    it 'rejects cyclic library waits' do
      caller_script = build_script('libcaller')
      target_script = instance_double(
        script_class,
        :name                    => 'libtarget',
        :join                    => true,
        :exit_error              => nil,
        :completed_successfully? => true
      )
      script_class.class_variable_set(:@@running, [caller_script])
      script_class.class_variable_set(:@@loading_libraries, { 'libtarget' => target_script })
      script_class.class_variable_set(
        :@@library_waits,
        target_script => { caller_script => Set[Object.new] }
      )
      allow(script_class).to receive(:current).and_return(caller_script)
      allow(script_class).to receive(:__find_script_file).with('libtarget').and_return('/custom/team/libtarget.lic')

      expect { script_class.loadlib('target') }.to raise_error(LoadError, /cyclic/)
      expect(target_script).not_to have_received(:join)
    end

    it 'rejects a library loading itself without blocking' do
      Dir.mktmpdir('script-library-self-cycle') do |root|
        custom_dir = File.join(root, 'custom')
        FileUtils.mkdir_p(custom_dir)
        File.write(
          File.join(custom_dir, 'libselfcycle.lic'),
          "# quiet\nLich::Common::Script.loadlib('selfcycle')\nDone:\nnil\n"
        )
        stub_const('SCRIPT_DIR', root)
        allow(script_class).to receive(:__find_script_file).with('libselfcycle').and_return('/custom/libselfcycle.lic')

        expect {
          Timeout.timeout(1) { script_class.loadlib('selfcycle') }
        }.to raise_error(LoadError, /cyclic script library dependency/)
      end
    end

    it 'does not record an interrupted library as loaded' do
      interrupted_script = instance_double(
        script_class,
        :name                    => 'libutil',
        :join                    => true,
        :exit_error              => nil,
        :completed_successfully? => false
      )
      allow(script_class).to receive(:start).with('libutil', { :force => true }).and_return(interrupted_script)

      expect { script_class.loadlib('util') }.to raise_error(LoadError, /did not complete/)
      expect(script_class.libs).to be_empty
    end

    it 'tracks simultaneous waits from separate threads of one script' do
      caller_script = build_script('libcaller')
      entered = Queue.new
      release = Queue.new
      target_one = instance_double(script_class, :name => 'libone')
      target_two = instance_double(script_class, :name => 'libtwo')
      allow(target_one).to receive(:join) { entered << true; release.pop }
      allow(target_two).to receive(:join) { entered << true; release.pop }
      allow(script_class).to receive(:current).and_return(caller_script)

      waiters = [
        Thread.new { script_class.__send__(:__join_library, 'libone', target_one) },
        Thread.new { script_class.__send__(:__join_library, 'libtwo', target_two) }
      ]
      2.times { entered.pop }

      dependencies = script_class.class_variable_get(:@@library_waits)[caller_script]
      expect(dependencies.keys).to contain_exactly(target_one, target_two)
      expect(dependencies.values.map(&:size)).to contain_exactly(1, 1)

      2.times { release << true }
      waiters.each(&:join)
      expect(script_class.class_variable_get(:@@library_waits)).to be_empty
    end

    it 'retains a shared dependency edge when one same-target waiter is cancelled' do
      caller_script = build_script('libcaller')
      target_script = instance_double(script_class, :name => 'libtarget')
      entered = Queue.new
      release = Queue.new
      allow(target_script).to receive(:join) { entered << true; release.pop }
      allow(script_class).to receive(:current).and_return(caller_script)

      waiters = Array.new(2) do
        Thread.new { script_class.__send__(:__join_library, 'libtarget', target_script) }
      end
      2.times { entered.pop }
      dependencies = script_class.class_variable_get(:@@library_waits)[caller_script]
      expect(dependencies.fetch(target_script).size).to eq(2)

      waiters.first.kill
      waiters.first.join

      dependencies = script_class.class_variable_get(:@@library_waits)[caller_script]
      expect(dependencies.fetch(target_script).size).to eq(1)
      expect(
        script_class.__send__(:__library_dependency_reaches?, caller_script, target_script)
      ).to be(true)

      release << true
      waiters.last.join
      expect(script_class.class_variable_get(:@@library_waits)).to be_empty
    ensure
      waiters&.each(&:kill)
      release << true if defined?(release) && release
    end

    it 'does not remove another waiter edge when cancelled before registration' do
      caller_script = build_script('libcaller')
      target_script = instance_double(script_class, :name => 'libtarget')
      library_mutex = script_class.class_variable_get(:@@library_mutex)
      existing_token = Object.new
      script_class.class_variable_set(
        :@@library_waits,
        caller_script => { target_script => Set[existing_token] }
      )
      allow(script_class).to receive(:current).and_return(caller_script)
      library_mutex.lock

      waiter = Thread.new do
        script_class.__send__(:__join_library, 'libtarget', target_script)
      end
      Timeout.timeout(1) { Thread.pass until waiter.status == 'sleep' }
      waiter.kill
      library_mutex.unlock
      waiter.join

      dependencies = script_class.class_variable_get(:@@library_waits)[caller_script]
      expect(dependencies.fetch(target_script)).to eq(Set[existing_token])
    ensure
      library_mutex&.unlock if library_mutex&.owned?
      waiter&.kill
    end

    it 'completes dependency cleanup after repeated cancellation' do
      caller_script = build_script('libcaller')
      target_script = instance_double(script_class, :name => 'libtarget')
      join_entered = Queue.new
      join_unwinding = Queue.new
      allow(target_script).to receive(:join) do
        join_entered << true
        begin
          Queue.new.pop
        ensure
          join_unwinding << true
        end
      end
      allow(script_class).to receive(:current).and_return(caller_script)
      library_mutex = script_class.class_variable_get(:@@library_mutex)
      waiter = Thread.new do
        script_class.__send__(:__join_library, 'libtarget', target_script)
      end
      join_entered.pop
      library_mutex.lock

      waiter.kill
      join_unwinding.pop
      waiter.kill
      library_mutex.unlock
      waiter.join

      expect(script_class.class_variable_get(:@@library_waits)).to be_empty
    ensure
      library_mutex&.unlock if library_mutex&.owned?
      waiter&.kill
    end

    it 'prunes a dead waiter when cancellation interrupts dependency cleanup' do
      caller_script = build_script('libcaller')
      target_script = instance_double(script_class, :name => 'libtarget', :join => true)
      allow(script_class).to receive(:current).and_return(caller_script)
      original_mutex = script_class.class_variable_get(:@@library_mutex)
      interrupting_mutex = Object.new
      synchronize_calls = 0
      interrupting_mutex.define_singleton_method(:synchronize) do |&block|
        synchronize_calls += 1
        Thread.current.kill if synchronize_calls == 2
        original_mutex.synchronize(&block)
      end
      script_class.class_variable_set(:@@library_mutex, interrupting_mutex)

      waiter = Thread.new do
        script_class.__send__(:__join_library, 'libtarget', target_script)
      end
      waiter.join
      script_class.class_variable_set(:@@library_mutex, original_mutex)

      expect(
        script_class.__send__(:__library_dependency_reaches?, caller_script, target_script)
      ).to be(false)
      expect(script_class.class_variable_get(:@@library_waits)).to be_empty
    ensure
      script_class.class_variable_set(:@@library_mutex, original_mutex) if defined?(original_mutex)
      waiter&.kill
    end

    it 'publishes a dependency token atomically with its target edge' do
      caller_script = build_script('libcaller')
      target_script = instance_double(script_class, :name => 'libtarget')
      assignment_entered = Queue.new
      blocking_dependencies = Class.new(Hash) do
        define_method(:[]=) do |key, value|
          super(key, value)
          assignment_entered << true
          Queue.new.pop
        end
      end.new
      script_class.class_variable_set(:@@library_waits, caller_script => blocking_dependencies)
      allow(script_class).to receive(:current).and_return(caller_script)

      waiter = Thread.new do
        script_class.__send__(:__join_library, 'libtarget', target_script)
      end
      assignment_entered.pop

      expect(blocking_dependencies.fetch(target_script).size).to eq(1)

      waiter.kill
      waiter.join
      expect(script_class.class_variable_get(:@@library_waits)).to be_empty
    ensure
      waiter&.kill
    end

    it 'keeps a completed marker until loaded state is published' do
      interrupting_set = Class.new(Set) do
        def add(value)
          super
          unless defined?(@interrupted)
            @interrupted = true
            Thread.current.kill
          end
          self
        end
      end.new
      script_class.class_variable_set(:@@loaded_libraries, interrupting_set)
      script_class.class_variable_set(:@@loading_libraries, 'libutil' => library_script)

      loader = Thread.new { script_class.loadlib('util') }
      loader.join

      expect(script_class.libs).to include('libutil')
      expect(script_class.class_variable_get(:@@loading_libraries)).to eq('libutil' => library_script)
      expect(script_class.loadlib('util')).to be(true)
      expect(script_class.class_variable_get(:@@loading_libraries)).to be_empty
    ensure
      loader&.kill
    end

    it 'serializes a retry behind the failed generation' do
      first_joined = Queue.new
      join_mutex = Mutex.new
      join_condition = ConditionVariable.new
      first_released = false
      failed_attempt = instance_double(
        script_class,
        :name                    => 'libutil',
        :exit_error              => nil,
        :completed_successfully? => false
      )
      successful_attempt = instance_double(
        script_class,
        :name                    => 'libutil',
        :join                    => true,
        :exit_error              => nil,
        :completed_successfully? => true
      )
      allow(failed_attempt).to receive(:join) do
        first_joined << true
        join_mutex.synchronize { join_condition.wait(join_mutex) until first_released }
        failed_attempt
      end
      allow(script_class).to receive(:start).with('libutil', { :force => true }).and_return(failed_attempt, successful_attempt)

      first_loader = Thread.new do
        script_class.loadlib('util')
      rescue LoadError
        false
      end
      first_joined.pop
      retry_loader = Thread.new { script_class.loadlib('util') }
      expect(retry_loader.join(0.02)).to be_nil

      join_mutex.synchronize do
        first_released = true
        join_condition.broadcast
      end

      expect(first_loader.value).to be(false)
      expect(retry_loader.value).to be(true)
      expect(script_class.libs).to include('libutil')
      expect(script_class).to have_received(:start).with('libutil', { :force => true }).twice
    end

    it 'does not republish a failed generation over a replacement loader' do
      failed_attempt = instance_double(
        script_class,
        :name                    => 'libutil',
        :join                    => true,
        :exit_error              => RuntimeError.new('failed generation'),
        :completed_successfully? => false
      )
      replacement_joined = Queue.new
      release_replacement = Queue.new
      successful_attempt = instance_double(
        script_class,
        :name                    => 'libutil',
        :exit_error              => nil,
        :completed_successfully? => true
      )
      allow(successful_attempt).to receive(:join) do
        replacement_joined << true
        release_replacement.pop
        successful_attempt
      end
      allow(script_class).to receive(:start)
        .with('libutil', { :force => true })
        .and_return(failed_attempt, successful_attempt)
      first_finish_entered = Queue.new
      release_first_finish = Queue.new
      allow(script_class).to receive(:__finish_start).and_wrap_original do |method, *args, **kwargs|
        result = method.call(*args, **kwargs)
        if Thread.current.thread_variable_get(:pause_library_finish) && kwargs[:preserve_completed]
          first_finish_entered << true
          release_first_finish.pop
        end
        result
      end

      first_loader = Thread.new do
        Thread.current.thread_variable_set(:pause_library_finish, true)
        script_class.loadlib('util')
      rescue LoadError
        false
      end
      first_finish_entered.pop
      replacement_loader = Thread.new { script_class.loadlib('util') }
      replacement_joined.pop

      release_first_finish << true
      expect(first_loader.value).to be(false)
      expect(script_class.class_variable_get(:@@loading_libraries)).to eq(
        'libutil' => successful_attempt
      )

      release_replacement << true
      expect(replacement_loader.value).to be(true)
      expect(script_class.libs).to include('libutil')
      expect(script_class).to have_received(:start).twice
    ensure
      release_first_finish << true if defined?(release_first_finish) && release_first_finish
      release_replacement << true if defined?(release_replacement) && release_replacement
      first_loader&.kill
      replacement_loader&.kill
    end

    it 'raises without recording a missing library' do
      allow(script_class).to receive(:__find_script_file).with('libmissing').and_return(nil)

      expect { script_class.loadlib('missing') }.to raise_error(LoadError, /not found/)
      expect(script_class.libs).to be_empty
    end

    it 'reloads a stable snapshot of loaded libraries' do
      script_class.class_variable_set(:@@loaded_libraries, Set['libutil', 'libstatus'])
      allow(script_class).to receive(:loadlib).and_return(true)

      expect(script_class.reloadlibs).to be(true)
      expect(script_class).to have_received(:loadlib).with('libutil', :timeout => 1.0)
      expect(script_class).to have_received(:loadlib).with('libstatus', :timeout => 1.0)
    end

    it 'invalidates a library cache entry when reload fails' do
      script_class.class_variable_set(:@@loaded_libraries, Set['libutil'])
      allow(script_class).to receive(:loadlib).with('libutil', :timeout => 1.0).and_raise(LoadError, 'broken reload')

      expect(script_class.reloadlibs).to be(false)
      expect(script_class.libs).to be_empty
    end

    it 'preserves the current library generation during reload' do
      current_library = build_script('libutil')
      script_class.class_variable_set(:@@loaded_libraries, Set['libutil'])
      allow(script_class).to receive(:current).and_return(current_library)
      allow(script_class).to receive(:loadlib)

      expect(script_class.reloadlibs).to be(true)
      expect(script_class).not_to have_received(:loadlib)
      expect(script_class.libs).to include('libutil')
    end

    it 'bounds reload waits for a still-running library' do
      script_class.class_variable_set(:@@loaded_libraries, Set['libutil'])
      allow(script_class).to receive(:loadlib)
        .with('libutil', :timeout => 0.01)
        .and_raise(script_class::LibraryJoinTimeout, 'still running')

      expect(script_class.reloadlibs(:timeout => 0.01)).to be(false)
      expect(script_class.libs).to be_empty
    end

    it 'starts a replacement when reload consumes an interrupted completion marker' do
      replacement = instance_double(
        script_class,
        :name                    => 'libutil',
        :join                    => true,
        :exit_error              => nil,
        :completed_successfully? => true
      )
      script_class.class_variable_set(:@@loaded_libraries, Set['libutil'])
      script_class.class_variable_set(:@@loaded_library_owners, 'libutil' => library_script.object_id)
      script_class.class_variable_set(:@@loading_libraries, 'libutil' => library_script)
      allow(script_class).to receive(:start)
        .with('libutil', { :force => true })
        .and_return(replacement)

      expect(script_class.reloadlibs).to be(true)
      expect(script_class).to have_received(:start).once
      expect(script_class.libs).to include('libutil')
      expect(script_class.class_variable_get(:@@loading_libraries)).to be_empty
    end

    it 'does not evict a newer active owner while reloading an older generation' do
      newer_generation = instance_double(
        script_class,
        :name                    => 'libutil',
        :join                    => true,
        :exit_error              => nil,
        :completed_successfully? => true
      )
      script_class.class_variable_set(:@@loaded_libraries, Set['libutil'])
      script_class.class_variable_set(:@@loaded_library_owners, 'libutil' => library_script.object_id)
      script_class.class_variable_set(:@@loading_libraries, 'libutil' => newer_generation)
      allow(script_class).to receive(:start)

      expect(script_class.reloadlibs).to be(true)
      expect(script_class).not_to have_received(:start)
      expect(script_class.class_variable_get(:@@loaded_library_owners)).to eq(
        'libutil' => newer_generation.object_id
      )
    end

    it 'completes stale-owner removal after a concurrent reload is interrupted' do
      interrupting_owners = Class.new(Hash) do
        def delete(key)
          value = super
          unless defined?(@interrupted)
            @interrupted = true
            Thread.current.kill
          end
          value
        end
      end.new
      interrupting_owners['libutil'] = library_script.object_id
      replacement = instance_double(
        script_class,
        :name                    => 'libutil',
        :join                    => true,
        :exit_error              => nil,
        :completed_successfully? => true
      )
      script_class.class_variable_set(:@@loaded_libraries, Set['libutil'])
      script_class.class_variable_set(:@@loaded_library_owners, interrupting_owners)
      script_class.class_variable_set(:@@loading_libraries, 'libutil' => library_script)
      allow(script_class).to receive(:start)
        .with('libutil', { :force => true })
        .and_return(replacement)

      interrupted_reload = Thread.new { script_class.reloadlibs }
      interrupted_reload.join

      expect(script_class.reloadlibs).to be(true)
      expect(script_class).to have_received(:start).once
      expect(script_class.libs).to include('libutil')
    ensure
      interrupted_reload&.kill
    end

    it 'retries a reload interrupted after removing its loaded marker' do
      interrupting_libraries = Class.new(Set) do
        def delete?(library)
          removed = super
          unless defined?(@interrupted)
            @interrupted = true
            Thread.current.kill
          end
          removed
        end
      end.new(['libutil'])
      script_class.class_variable_set(:@@loaded_libraries, interrupting_libraries)
      allow(script_class).to receive(:loadlib).with('libutil', :timeout => 1.0) do
        script_class.class_variable_get(:@@loaded_libraries).add('libutil')
        true
      end

      interrupted_reload = Thread.new { script_class.reloadlibs }
      interrupted_reload.join

      expect(script_class.libs).to be_empty
      expect(script_class.reloadlibs).to be(true)
      expect(script_class).to have_received(:loadlib).once
      expect(script_class.class_variable_get(:@@reloading_libraries)).to be_empty
    ensure
      interrupted_reload&.kill
    end

    it 'keeps another reloader marker when an overlapping reload times out' do
      script_class.class_variable_set(:@@loaded_libraries, Set['libutil'])
      first_reload_entered = Queue.new
      release_first_reload = Queue.new
      load_roles = Queue.new
      allow(script_class).to receive(:loadlib).with('libutil', :timeout => 1.0) do
        role = Thread.current.thread_variable_get(:reload_role)
        load_roles << role
        case role
        when :first
          first_reload_entered << true
          release_first_reload.pop
        when :second
          raise script_class::LibraryJoinTimeout, 'overlapping reload timed out'
        else
          script_class.class_variable_get(:@@loaded_libraries).add('libutil')
          true
        end
      end
      first_reloader = Thread.new do
        Thread.current.thread_variable_set(:reload_role, :first)
        script_class.reloadlibs
      end
      first_reload_entered.pop
      second_reloader = Thread.new do
        Thread.current.thread_variable_set(:reload_role, :second)
        script_class.reloadlibs
      end

      expect(second_reloader.value).to be(false)
      expect(script_class.class_variable_get(:@@reloading_libraries).fetch('libutil').size).to eq(1)
      first_reloader.kill
      first_reloader.join

      expect(script_class.reloadlibs).to be(true)
      expect(3.times.map { load_roles.pop }).to contain_exactly(:first, :second, nil)
      expect(script_class.libs).to include('libutil')
      expect(script_class.class_variable_get(:@@reloading_libraries)).to be_empty
    ensure
      release_first_reload << true if defined?(release_first_reload) && release_first_reload
      first_reloader&.kill
      second_reloader&.kill
    end

    it 'keeps a concurrent reloader marker after another reload succeeds' do
      script_class.class_variable_set(:@@loaded_libraries, Set['libutil'])
      first_load_committed = Queue.new
      release_first_reload = Queue.new
      second_reload_entered = Queue.new
      load_roles = Queue.new
      allow(script_class).to receive(:loadlib).with('libutil', :timeout => 1.0) do
        role = Thread.current.thread_variable_get(:reload_role)
        load_roles << role
        case role
        when :first
          script_class.class_variable_get(:@@loaded_libraries).add('libutil')
          first_load_committed << true
          release_first_reload.pop
        when :second
          second_reload_entered << true
          Queue.new.pop
        else
          script_class.class_variable_get(:@@loaded_libraries).add('libutil')
          true
        end
      end
      first_reloader = Thread.new do
        Thread.current.thread_variable_set(:reload_role, :first)
        script_class.reloadlibs
      end
      first_load_committed.pop
      second_reloader = Thread.new do
        Thread.current.thread_variable_set(:reload_role, :second)
        script_class.reloadlibs
      end
      second_reload_entered.pop
      release_first_reload << true

      expect(first_reloader.value).to be(true)
      expect(script_class.class_variable_get(:@@reloading_libraries).fetch('libutil').size).to eq(1)
      second_reloader.kill
      second_reloader.join

      expect(script_class.reloadlibs).to be(true)
      expect(3.times.map { load_roles.pop }).to contain_exactly(:first, :second, nil)
      expect(script_class.libs).to include('libutil')
      expect(script_class.class_variable_get(:@@reloading_libraries)).to be_empty
    ensure
      release_first_reload << true if defined?(release_first_reload) && release_first_reload
      first_reloader&.kill
      second_reloader&.kill
    end

    it 'bounds reload while another startup reservation is live' do
      reservation = Object.new
      script_class.class_variable_set(:@@loaded_libraries, Set['libutil'])
      script_class.__send__(:__begin_start, reservation, 'libutil', :force => true)
      allow(script_class).to receive(:start)

      reload = Thread.new { script_class.reloadlibs(:timeout => 0.01) }

      expect(reload.join(0.2)).to equal(reload)
      expect(reload.value).to be(false)
      expect(script_class).not_to have_received(:start)
    ensure
      script_class.__send__(:__finish_start, reservation, nil) if defined?(reservation) && reservation
      reload&.kill
    end
  end

  describe '.kill_all' do
    it 'preserves protected and hidden scripts unless force is requested' do
      visible = build_script('visible')
      protected_script = build_script('protected')
      protected_script.no_kill_all = true
      hidden = build_script('hidden')
      hidden.hidden = true
      scripts = [visible, protected_script, hidden]
      script_class.class_variable_set(:@@running, scripts)
      scripts.each { |script| allow(script).to receive(:kill) }

      expect(script_class.kill_all).to eq(1)
      expect(visible).to have_received(:kill).with(:context => :runtime).once
      expect(protected_script).not_to have_received(:kill)
      expect(hidden).not_to have_received(:kill)

      expect(script_class.kill_all(:force => true)).to eq(3)
      expect(visible).to have_received(:kill).with(:context => :runtime).twice
      expect(protected_script).to have_received(:kill).with(:context => :runtime).once
      expect(hidden).to have_received(:kill).with(:context => :runtime).once
    end
  end

  def progress_shutdown_until(script)
    Timeout.timeout(1) do
      while script_class.shutdown_scripts.include?(script)
        script_class.progress_shutdown
        sleep 0.005
      end
    end
  rescue Timeout::Error
    state = %i[@kill_requested @cleanup_started @cleanup_complete @cleanup_thread @stopping_threads].to_h do |name|
      [name, Object.instance_method(:instance_variable_get).bind_call(script, name)]
    end
    warn "shutdown progress timed out: #{state.inspect}"
    raise
  end

  def interrupt_next_queue_release(timing)
    first_queue = true
    allow(Queue).to receive(:new).and_wrap_original do |method, *args|
      queue = method.call(*args)
      if first_queue
        first_queue = false
        queue.define_singleton_method(:<<) do |value|
          Thread.current.raise(Timeout::Error, 'gate release interrupted') if timing == :before
          result = super(value)
          Thread.current.raise(Timeout::Error, 'gate release interrupted') if timing == :after
          result
        end
      end
      queue
    end
  end

  def block_next_queue_release
    gate_entered = Queue.new
    release_gate = Queue.new
    first_queue = true
    allow(Queue).to receive(:new).and_wrap_original do |method, *args|
      queue = method.call(*args)
      if first_queue
        first_queue = false
        queue.define_singleton_method(:<<) do |value|
          gate_entered << true
          release_gate.pop
          super(value)
        end
      end
      queue
    end
    [gate_entered, release_gate]
  end

  def completed_start_waiter_count(waiters, name)
    value = waiters[name]
    value.respond_to?(:size) ? value.size : (value || 0).to_i
  end

  def kill_worker_during_current
    main_thread = Thread.current
    lookup_entered = Queue.new
    intercept = true
    allow(script_class).to receive(:current).and_wrap_original do |method|
      if Thread.current != main_thread && intercept
        intercept = false
        lookup_entered << true
        Queue.new.pop
      else
        method.call
      end
    end

    script = yield
    lookup_entered.pop
    worker = script.__send__(:__worker_threads).find(&:alive?)
    worker.kill
    worker.join
    script
  end

  def build_script(name)
    script_class.allocate.tap do |script|
      script.instance_variable_set(:@name, name)
      script.instance_variable_set(:@custom, false)
      script.instance_variable_set(:@quiet, true)
      script.instance_variable_set(:@thread_group, ThreadGroup.new)
      script.instance_variable_set(:@die_with, [])
      script.instance_variable_set(:@paused, false)
      script.instance_variable_set(:@at_exit_procs, [])
      script.instance_variable_set(:@watchfor, {})
      script.instance_variable_set(:@downstream_buffer, [])
      script.instance_variable_set(:@upstream_buffer, [])
      script.instance_variable_set(:@match_stack_labels, [])
      script.instance_variable_set(:@match_stack_strings, [])
      script.instance_variable_set(:@killer_mutex, Mutex.new)
      script.instance_variable_set(:@killed_externally, false)
      script.instance_variable_set(:@kill_source, nil)
      script.instance_variable_set(:@kill_requested, false)
      script.instance_variable_set(:@cleanup_started, false)
      script.instance_variable_set(:@completed_successfully, false)
      script.instance_variable_set(:@hidden, false)
      script.instance_variable_set(:@no_kill_all, false)
      script.instance_variable_set(:@no_pause_all, false)
    end
  end
end
