# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/main/user_exit_dispatch'
require_relative '../../../lib/common/shutdown_watchdog'
require_relative '../../../lib/common/shutdown_coordinator'
require_relative '../../../lib/common/shutdown_intent'
require_relative '../../../lib/common/orderly_shutdown'

# Exercises the production detachable-frontend exit dispatch directly, so the
# spec fails if main.rb's wiring stops arming the watchdog or changes routing.
#
# The guarantee under test: the shutdown watchdog is armed *before* the inline
# orderly-shutdown drain runs (that drain runs before_dying/at_exit hooks inline
# and can hang). Because everything is synchronous, the ordering assertion is
# deterministic -- no threads, sleeps, or timing. Only the game-side
# collaborators (script drain, Vars, Game) are doubled, exactly as
# orderly_shutdown_spec.rb does; the watchdog, OrderlyShutdown, coordinator, and
# ShutdownIntent are the real production units.
RSpec.describe Lich::Main::UserExitDispatch do
  let(:coordinator) { Lich::Common::ShutdownCoordinator }

  # Records the sequence of lifecycle events so the test can assert ordering.
  let(:sequence) { [] }

  # Script drain double whose #run records whether the watchdog is armed at the
  # exact moment the inline drain executes. Returns a drained-clean result so the
  # orderly runner proceeds normally (see orderly_shutdown_spec.rb).
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

  # Forwards the doubled game-side collaborators into the real
  # OrderlyShutdown.request_user_exit the production dispatch calls.
  def dispatch(client_string, cmd_prefix:)
    described_class.dispatch_detachable_client(
      client_string,
      cmd_prefix: cmd_prefix,
      script_drain: script_drain,
      vars: vars,
      game: game,
      scripts_provider: proc { [] }
    )
  end

  before do
    coordinator.reset!
    allow(Lich).to receive(:log)

    # Reset watchdog module state, then keep the real arm behaviour but record
    # when it is called so ordering relative to the drain can be asserted.
    Lich::Common::ShutdownWatchdog.instance_variable_set(:@armed, false)
    Lich::Common::ShutdownWatchdog.instance_variable_set(:@thread, nil)
    Lich::Common::ShutdownWatchdog.instance_variable_set(:@mutex, Mutex.new)
    Lich::Common::ShutdownWatchdog.instance_variable_set(:@condition, ConditionVariable.new)
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

  describe '.dispatch_detachable_client' do
    it 'routes a prefixed ;exit line through orderly shutdown as the detachable source' do
      expect(dispatch('exit', cmd_prefix: '<c>')).to be(true)
      expect(coordinator.current.source).to eq('detachable_frontend')
    end

    it 'arms the watchdog before running the inline script drain' do
      dispatch('exit', cmd_prefix: '<c>')

      expect(sequence).to eq([:arm, [:drain, true]])
    end

    it 'has the watchdog armed at the moment the inline drain runs' do
      dispatch('exit', cmd_prefix: '<c>')

      drain_event = sequence.find { |event| event.is_a?(Array) && event.first == :drain }
      expect(drain_event).to eq([:drain, true])
    end

    it 'completes the orderly shutdown once the drain is protected' do
      dispatch('exit', cmd_prefix: '<c>')

      expect(coordinator.orderly_shutdown_completed?).to be(true)
      expect(game.calls).to eq([:close])
      expect(vars.calls).to eq([:save])
    end

    it 'also routes an unprefixed exit line' do
      expect(dispatch('exit', cmd_prefix: '')).to be(true)
      expect(coordinator.current.source).to eq('detachable_frontend')
    end

    it 'applies the cmd_prefix before matching, so a non-matching prefix is not an exit' do
      # Proves the prefixing happens inside the unit: a bare "exit" would match,
      # but "garbage-exit" must not -- and nothing is armed or requested.
      expect(dispatch('exit', cmd_prefix: 'garbage-')).to be(false)
      expect(sequence).to be_empty
      expect(coordinator.requested?).to be(false)
      expect(Lich::Common::ShutdownWatchdog.armed?).to be(false)
    end

    it 'does not treat a non-exit client line as a shutdown' do
      expect(dispatch('look', cmd_prefix: '<c>')).to be(false)
      expect(sequence).to be_empty
      expect(coordinator.requested?).to be(false)
      expect(Lich::Common::ShutdownWatchdog.armed?).to be(false)
    end
  end

  describe '.run_orderly_user_shutdown' do
    it 'arms the watchdog before the drain under the default primary source' do
      described_class.run_orderly_user_shutdown(
        script_drain: script_drain, vars: vars, game: game, scripts_provider: proc { [] }
      )

      expect(sequence).to eq([:arm, [:drain, true]])
      expect(coordinator.current.source).to eq('primary_frontend')
    end
  end
end
