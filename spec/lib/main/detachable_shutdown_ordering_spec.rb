# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/shutdown_log'
require_relative '../../../lib/common/shutdown_coordinator'
require_relative '../../../lib/common/shutdown_intent'
require_relative '../../../lib/common/orderly_shutdown'
require_relative '../../../lib/common/shutdown_watchdog'

# Integration coverage for the detachable-frontend ";exit" shutdown path.
#
# lib/main/main.rb routes both the primary and the detachable frontend exit
# commands through a single +run_orderly_user_shutdown+ proc that arms the
# shutdown watchdog *before* calling +OrderlyShutdown.request_user_exit+ --
# which drains scripts and runs their +before_dying+/+at_exit+ hooks inline.
# Those inline hooks can hang, so the watchdog must already be armed by the time
# the drain runs; a bare +request_user_exit+ on the detachable path (as the
# code did before PR #1452) would run that hang-prone drain unprotected.
#
# +lib/main/main.rb+ is a top-level script and cannot be loaded in isolation, so
# the two relevant snippets -- the proc and the detachable dispatch -- are
# mirrored here and wired to the REAL watchdog, OrderlyShutdown,
# ShutdownCoordinator, and ShutdownIntent. Only the game-side collaborators
# (script drain, Vars, Game) are doubled, exactly as +orderly_shutdown_spec.rb+
# does. The whole path is synchronous, so the ordering assertion is
# deterministic: no threads, sleeps, or timing.
RSpec.describe 'detachable frontend exit arms the watchdog before the inline drain' do
  let(:coordinator) { Lich::Common::ShutdownCoordinator }

  # Records the sequence of lifecycle events so the test can assert ordering.
  let(:sequence) { [] }

  # Script drain double whose #run records whether the watchdog is armed at the
  # exact moment the inline drain executes. It returns a drained-clean result so
  # the orderly runner proceeds normally (see orderly_shutdown_spec.rb).
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
    Lich::Common::ShutdownWatchdog.arm if defined?(Lich::Common::ShutdownWatchdog)
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
    allow(Lich::Common::ShutdownWatchdog).to receive(:arm).and_wrap_original do |original, **kwargs|
      sequence << :arm
      # Large deadline: the real watchdog thread must never fire during this
      # synchronous test; it is disarmed in the after hook.
      original.call(timeout: 30, **kwargs)
    end
  end

  after do
    Lich::Common::ShutdownWatchdog.disarm
    Lich::Common::ShutdownWatchdog.instance_variable_get(:@thread)&.join(1)
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
    expect(Lich::Common::ShutdownWatchdog.armed?).to be(false)
  end
end
