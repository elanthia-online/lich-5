# frozen_string_literal: true

require 'timeout'
require 'tempfile'
require 'rbconfig'

require_relative '../../spec_helper'
require_relative '../../../lib/common/shutdown_watchdog'
require_relative '../../../lib/common/shutdown_coordinator'
require_relative '../../../lib/common/shutdown_intent'
require_relative '../../../lib/common/orderly_shutdown'

# A ConditionVariable that records when a thread enters #wait, so a test can
# deterministically synchronize with the watchdog's waiting thread instead of
# guessing with sleeps. Each #wait entry pushes an incrementing count onto a
# queue; {#await_wait} blocks until the nth wait has begun.
#
# The count is incremented under the caller's mutex (the watchdog calls #wait
# while holding it), so it is never touched concurrently; the queue is the only
# cross-thread channel and is itself thread-safe.
class InstrumentedConditionVariable < Thread::ConditionVariable
  def initialize
    super
    @entries = Queue.new
    @count = 0
  end

  # @param mutex [Mutex] passed straight through to ConditionVariable#wait
  # @param timeout [Numeric, nil] passed straight through
  # @return [void]
  def wait(mutex, timeout = nil)
    @count += 1
    @entries << @count
    super
  end

  # Blocks until at least +n+ waits have begun (no polling, no sleeps).
  #
  # @param n [Integer] the wait ordinal to wait for
  # @param timeout [Numeric] safety bound so a hang fails fast
  # @return [void]
  def await_wait(n, timeout: 2)
    Timeout.timeout(timeout) do
      loop { break if @entries.pop >= n }
    end
  end
end

RSpec.describe Lich::Common::ShutdownWatchdog do
  before do
    described_class.instance_variable_set(:@armed, false)
    described_class.instance_variable_set(:@thread, nil)
    described_class.instance_variable_set(:@mutex, Mutex.new)
    described_class.instance_variable_set(:@condition, ConditionVariable.new)
  end

  after do
    described_class.disarm
    described_class.instance_variable_get(:@thread)&.join(1)
  end

  describe '.arm' do
    it 'invokes on_expire after the deadline elapses' do
      fired = Queue.new
      expect(described_class.arm(timeout: 0.02, on_expire: -> { fired << :expired })).to be(true)

      expect(Timeout.timeout(2) { fired.pop }).to eq(:expired)
    end

    it 'dumps thread diagnostics before forcing exit' do
      allow(Lich::Common::ShutdownLog).to receive(:error)
      fired = Queue.new
      described_class.arm(timeout: 0.02, on_expire: -> { fired << :expired })

      Timeout.timeout(2) { fired.pop }

      expect(Lich::Common::ShutdownLog).to have_received(:error).at_least(:once)
    end

    it 'does not fire once disarmed before the deadline' do
      fired = Queue.new
      described_class.arm(timeout: 5, on_expire: -> { fired << :expired })

      described_class.disarm
      described_class.instance_variable_get(:@thread)&.join(1)

      sleep 0.05
      expect(fired).to be_empty
    end

    it 'is a no-op when the timeout is zero (disabled)' do
      expect(described_class.arm(timeout: 0, on_expire: -> { raise 'should not run' })).to be(false)
      expect(described_class.armed?).to be(false)
    end

    it 'is a no-op when the timeout is negative' do
      expect(described_class.arm(timeout: -5, on_expire: -> { raise 'should not run' })).to be(false)
    end

    it 'refuses to arm twice concurrently' do
      described_class.arm(timeout: 5, on_expire: -> {})
      expect(described_class.arm(timeout: 5, on_expire: -> {})).to be(false)
    end

    it 'can be re-armed after being disarmed' do
      described_class.arm(timeout: 5, on_expire: -> {})
      described_class.disarm
      described_class.instance_variable_get(:@thread)&.join(1)

      expect(described_class.arm(timeout: 5, on_expire: -> {})).to be(true)
    end

    it 'does not let a disarmed thread fire after a subsequent re-arm' do
      # Regression: an arm/disarm/arm sequence must not let the first (canceled)
      # thread observe the second arming's @armed flag and force an exit.
      first = Queue.new
      described_class.arm(timeout: 0.05, on_expire: -> { first << :first })
      described_class.disarm
      first_thread = described_class.instance_variable_get(:@thread)

      described_class.arm(timeout: 5, on_expire: -> {})
      first_thread&.join(1)
      sleep 0.15 # well past the first arming's 0.05s deadline

      expect(first).to be_empty
    end

    it 'uses an un-trappable Process.exit! as the default on_expire' do
      # Regression for the shipped defect: the default lambda was a bare
      # exit!(1), which resolved against the module and raised NoMethodError --
      # neutering the force-exit guarantee. The default must call a real method.
      exited = Queue.new
      allow(Process).to receive(:exit!) { |code| exited << code }

      described_class.arm(timeout: 0.02) # no on_expire -> exercise the real default

      expect(Timeout.timeout(2) { exited.pop }).to eq(1)
    end

    it 'consumes a genuine spurious wakeup, re-waits, and does not fire early' do
      # Regression: ConditionVariable#wait can return before its timeout on a
      # spurious wakeup. The watchdog must re-wait against a monotonic deadline
      # rather than treat any wakeup while armed as expiry.
      #
      # Determinism: the prior version slept, then signalled. #signal only wakes
      # a thread already parked in #wait -- so if the watchdog thread had not yet
      # reached #wait the signal was silently lost, and the test still passed
      # because the deadline had not elapsed. It could pass without ever
      # delivering its intended wakeup. Here the instrumented condition variable
      # lets us (a) block until the watchdog is genuinely parked in its first
      # wait, then (b) prove the spurious wakeup was delivered AND consumed by
      # observing the thread return to a *second* wait instead of expiring.
      condition = InstrumentedConditionVariable.new
      described_class.instance_variable_set(:@condition, condition)
      mutex = described_class.instance_variable_get(:@mutex)

      fired = Queue.new
      # Large deadline: the real timeout must never fire during this test, so the
      # only thing that could wake the thread early is the spurious signal.
      described_class.arm(timeout: 30, on_expire: -> { fired << :expired })

      condition.await_wait(1) # watchdog is now parked in its first wait

      # Holding @mutex guarantees the watchdog has already released it inside
      # ConditionVariable#wait, so this signal cannot be lost -- it is delivered
      # to a genuinely waiting thread.
      mutex.synchronize { condition.signal }

      # Proof the wakeup was delivered and consumed: the watchdog re-checked the
      # monotonic deadline (still in the future) and returned to a second wait.
      condition.await_wait(2)

      expect(fired).to be_empty # did not treat the spurious wakeup as expiry
      expect(described_class.armed?).to be(true)
      # Eventual firing after the real deadline is covered by
      # 'invokes on_expire after the deadline elapses'.
    end

    it 'still forces exit when diagnostics logging raises' do
      allow(Lich::Common::ShutdownLog).to receive(:error).and_raise(StandardError, 'log sink down')
      fired = Queue.new
      described_class.arm(timeout: 0.02, on_expire: -> { fired << :expired })

      expect(Timeout.timeout(2) { fired.pop }).to eq(:expired)
    end

    it 'treats a non-numeric timeout as disabled rather than arming' do
      expect(described_class.arm(timeout: 'not-a-number', on_expire: -> { raise 'should not run' })).to be(false)
      expect(described_class.armed?).to be(false)
    end

    it 'derives the deadline from configured_timeout when none is supplied' do
      allow(described_class).to receive(:configured_timeout).and_return(0)
      expect(described_class.arm(on_expire: -> { raise 'should not run' })).to be(false)
    end

    it 'admits only one winner when many threads race to arm' do
      results = Queue.new
      threads = Array.new(20) { Thread.new { results << described_class.arm(timeout: 5, on_expire: -> {}) } }
      threads.each(&:join)

      outcomes = Array.new(results.size) { results.pop }
      expect(outcomes.count(true)).to eq(1)
      expect(outcomes.count(false)).to eq(19)
    end
  end

  describe 'real force-exit of a hung teardown (subprocess)' do
    # Every in-process test injects a fake on_expire, so none exercises the
    # actual force-exit guarantee. This one does: a child process arms the real
    # watchdog with its default on_expire (Process.exit!) and then hangs forever,
    # standing in for a teardown step that never returns. If the watchdog works,
    # the child is force-exited after the deadline; if it is broken, the child
    # sleeps until the parent's Timeout fires and the test fails explicitly.
    let(:watchdog_path) { File.expand_path('../../../lib/common/shutdown_watchdog', __dir__) }

    it 'forces a hung process to exit after the deadline' do
      skip 'process spawning unavailable on this platform' unless Process.respond_to?(:spawn)

      child = <<~RUBY
        require #{watchdog_path.inspect}
        # Arm with the real default on_expire (Process.exit!(1)); no custom lambda.
        Lich::Common::ShutdownWatchdog.arm(timeout: 0.5)
        sleep 60 # deliberately hung teardown -- never reaches exit on its own
      RUBY

      script = Tempfile.new(['watchdog_hang', '.rb'])
      begin
        script.write(child)
        script.close

        pid = Process.spawn(RbConfig.ruby, script.path, out: File::NULL, err: File::NULL)
        status = nil
        begin
          # The deadline is 0.5s; 15s is generous slack for spawn + teardown.
          Timeout.timeout(15) { _pid, status = Process.wait2(pid) }
        rescue Timeout::Error
          Process.kill('KILL', pid)
          Process.wait(pid)
          raise 'watchdog did not force-exit a hung teardown within 15s'
        end

        # exitstatus 1 is the forced code -- distinct from a clean exit(0), so we
        # know the watchdog (not some other path) terminated the process.
        expect(status.exitstatus).to eq(1)
      ensure
        script.unlink
      end
    end
  end

  describe '.disarm' do
    it 'is safe to call when not armed' do
      expect { described_class.disarm }.not_to raise_error
      expect(described_class.armed?).to be(false)
    end
  end

  describe '.configured_timeout' do
    it 'falls back to the default when no settings backend is available' do
      hide_const('Lich')
      expect(described_class.configured_timeout).to eq(described_class::DEFAULT_TIMEOUT_SECONDS)
    end

    it 'falls back to the default (never silently disables) on a malformed value' do
      allow(Lich).to receive(:db).and_return(double(get_first_value: 'abc'))
      allow(Lich).to receive(:log)

      expect(described_class.configured_timeout).to eq(described_class::DEFAULT_TIMEOUT_SECONDS)
    end

    it 'honors an explicit positive override' do
      allow(Lich).to receive(:db).and_return(double(get_first_value: '90'))

      expect(described_class.configured_timeout).to eq(90)
    end

    it 'treats an explicit non-positive value as an intentional disable' do
      allow(Lich).to receive(:db).and_return(double(get_first_value: '0'))

      expect(described_class.configured_timeout).to eq(0)
    end

    it 'falls back to the default when the setting row is absent (nil)' do
      allow(Lich).to receive(:db).and_return(double(get_first_value: nil))

      expect(described_class.configured_timeout).to eq(described_class::DEFAULT_TIMEOUT_SECONDS)
    end

    it 'falls back to the default when the settings query raises' do
      db = double
      allow(db).to receive(:get_first_value).and_raise(StandardError, 'db locked')
      allow(Lich).to receive(:db).and_return(db)

      expect(described_class.configured_timeout).to eq(described_class::DEFAULT_TIMEOUT_SECONDS)
    end

    it 'parses a value with surrounding whitespace' do
      allow(Lich).to receive(:db).and_return(double(get_first_value: '  90  '))

      expect(described_class.configured_timeout).to eq(90)
    end

    it 'preserves an explicit negative value as an intentional disable' do
      allow(Lich).to receive(:db).and_return(double(get_first_value: '-5'))

      expect(described_class.configured_timeout).to eq(-5)
    end

    it 'rejects a non-integer numeric string and never silently disables' do
      allow(Lich).to receive(:db).and_return(double(get_first_value: '90.5'))
      allow(Lich).to receive(:log)

      expect(described_class.configured_timeout).to eq(described_class::DEFAULT_TIMEOUT_SECONDS)
    end
  end

  # Integration coverage for the detachable-frontend ";exit" shutdown path.
  #
  # lib/main/main.rb routes both the primary and the detachable frontend exit
  # commands through a single +run_orderly_user_shutdown+ proc that arms this
  # watchdog *before* calling +OrderlyShutdown.request_user_exit+ -- which drains
  # scripts and runs their +before_dying+/+at_exit+ hooks inline. Those inline
  # hooks can hang, so the watchdog must already be armed by the time the drain
  # runs; a bare +request_user_exit+ on the detachable path (as the code did
  # before PR #1452) would run that hang-prone drain unprotected.
  #
  # +lib/main/main.rb+ is a top-level script and cannot be loaded in isolation,
  # so the two relevant snippets -- the proc and the detachable dispatch -- are
  # mirrored here and wired to the REAL watchdog, OrderlyShutdown,
  # ShutdownCoordinator, and ShutdownIntent. Only the game-side collaborators
  # (script drain, Vars, Game) are doubled, exactly as +orderly_shutdown_spec.rb+
  # does. The whole path is synchronous, so the ordering assertion is
  # deterministic: no threads, sleeps, or timing.
  describe 'arming before the inline orderly-shutdown drain (detachable frontend exit)' do
    let(:coordinator) { Lich::Common::ShutdownCoordinator }

    # Records the sequence of lifecycle events so the test can assert ordering.
    let(:sequence) { [] }

    # Script drain double whose #run records whether the watchdog is armed at the
    # exact moment the inline drain executes. It returns a drained-clean result
    # so the orderly runner proceeds normally (see orderly_shutdown_spec.rb).
    let(:script_drain) do
      events = sequence
      drain_result = Struct.new(:scripts_remaining, :slow_scripts, :details, keyword_init: true).new(
        scripts_remaining: 0,
        slow_scripts: [],
        details: 'scripts_started=0 slow_scripts=[] scripts_remaining=0'
      )
      Struct.new(:events, :result) do
        # Accepts the drain keyword contract (initial_scripts:, remaining_scripts:,
        # slow_threshold:) anonymously; only the armed-at-drain observation matters.
        def run(**)
          events << [:drain, Lich::Common::ShutdownWatchdog.armed?]
          result
        end
      end.new(events, drain_result)
    end

    let(:vars) { Struct.new(:calls) { def save = calls << :save }.new([]) }
    let(:game) { Struct.new(:calls) { def close = calls << :close }.new([]) }

    # Faithful mirror of the +run_orderly_user_shutdown+ proc in lib/main/main.rb:
    # arm the watchdog, then run the orderly user-exit sequence. The game-side
    # collaborators are injected; the watchdog/OrderlyShutdown/coordinator are real.
    def run_orderly_user_shutdown(source:)
      described_class.arm if defined?(described_class)
      Lich::Common::OrderlyShutdown.request_user_exit(
        source: source,
        scripts_provider: proc { [] },
        script_drain: script_drain,
        vars: vars,
        game: game,
        active_sessions_lifecycle: nil
      )
    end

    # Faithful mirror of the detachable-frontend dispatch in lib/main/main.rb:
    # a user-exit command routes through the guarded proc with the detachable
    # source, so the watchdog is armed before the inline drain.
    def dispatch_detachable_client(client_string)
      return false unless Lich::Common::ShutdownIntent.user_exit_command?(client_string)

      run_orderly_user_shutdown(source: :detachable_frontend)
      true
    end

    before do
      coordinator.reset!
      allow(Lich).to receive(:log)
      # Keep the real arm behaviour but record when it is called, so ordering
      # relative to the drain can be asserted.
      allow(described_class).to receive(:arm).and_wrap_original do |original, **kwargs|
        sequence << :arm
        # Large deadline: the real watchdog thread must never fire during this
        # synchronous test; it is disarmed in the after hook.
        original.call(timeout: 30, **kwargs)
      end
    end

    after do
      Lich::Common::ShutdownLog.flush_user_exit_summary!
      coordinator.reset!
    end

    it 'recognizes the detachable exit command and routes it through the guarded proc' do
      expect(dispatch_detachable_client('exit')).to be(true)
      expect(coordinator.current.source).to eq('detachable_frontend')
    end

    it 'arms the watchdog before running the inline script drain' do
      dispatch_detachable_client('exit')

      expect(sequence).to eq([:arm, [:drain, true]])
    end

    it 'has the watchdog armed at the moment the inline drain runs' do
      dispatch_detachable_client('exit')

      drain_event = sequence.find { |event| event.is_a?(Array) && event.first == :drain }
      expect(drain_event).to eq([:drain, true])
    end

    it 'completes the orderly shutdown once the drain is protected' do
      dispatch_detachable_client('exit')

      expect(coordinator.orderly_shutdown_completed?).to be(true)
      expect(game.calls).to eq([:close])
      expect(vars.calls).to eq([:save])
    end

    it 'does not treat a non-exit client line as a shutdown' do
      expect(dispatch_detachable_client('look')).to be(false)
      expect(sequence).to be_empty
      expect(coordinator.requested?).to be(false)
      expect(described_class.armed?).to be(false)
    end
  end
end
