# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/shutdown_coordinator'
require_relative '../../../lib/common/best_effort_shutdown_cleanup'

RSpec.describe Lich::Common::BestEffortShutdownCleanup do
  def run_cleanup(**overrides)
    scripts = overrides.fetch(:initial_scripts, [])
    described_class.run(
      coordinator: overrides.fetch(:coordinator, coordinator),
      initial_scripts: scripts,
      remaining_scripts: overrides.fetch(:remaining_scripts, proc { [] }),
      script_drain: overrides.fetch(:script_drain, script_drain),
      vars: overrides.fetch(:vars, vars),
      active_sessions_lifecycle: overrides.fetch(:active_sessions_lifecycle, active_sessions_lifecycle)
    )
  end

  let(:coordinator) { Lich::Common::ShutdownCoordinator }

  let(:script_drain_result) do
    Struct.new(:scripts_remaining, :slow_scripts, :details, keyword_init: true).new(
      scripts_remaining: 0,
      slow_scripts: [],
      details: 'scripts_started=2 slow_scripts=[] scripts_remaining=0'
    )
  end

  let(:script_drain) do
    result = script_drain_result
    Struct.new(:calls, :result) do
      def run(initial_scripts:, remaining_scripts:, slow_threshold:)
        calls << {
          initial_scripts: initial_scripts,
          remaining_scripts: remaining_scripts,
          slow_threshold: slow_threshold,
        }
        result
      end
    end.new([], result)
  end

  let(:vars) do
    Struct.new(:calls) do
      def save
        calls << :save
      end
    end.new([])
  end

  let(:active_sessions_lifecycle) do
    Struct.new(:calls) do
      def update_connected(value)
        calls << value
      end
    end.new([])
  end

  before do
    coordinator.reset!
    coordinator.request(reason: :connection_reset, source: :game_reader)
    allow(Lich).to receive(:log)
  end

  after do
    coordinator.reset!
  end

  it 'runs local cleanup without closing the game connection' do
    result = run_cleanup(initial_scripts: %w[alpha beta])

    expect(active_sessions_lifecycle.calls).to eq([false])
    expect(script_drain.calls.first[:initial_scripts]).to eq(%w[alpha beta])
    expect(script_drain.calls.first[:slow_threshold]).to eq(1.5)
    expect(vars.calls).to eq([:save])
    expect(result).to be_completed
    expect(result).to be_scripts_drained
    expect(result).to be_vars_saved
    expect(result.script_shutdown_result).to equal(script_drain_result)
    expect(coordinator.best_effort_cleanup_result).to equal(result)
  end

  it 'only runs the best-effort cleanup sequence once' do
    first = run_cleanup
    second = run_cleanup

    expect(second).to equal(first)
    expect(script_drain.calls.length).to eq(1)
    expect(vars.calls).to eq([:save])
  end

  it 'continues later cleanup steps when one step fails' do
    failing_vars = Struct.new(:calls) do
      def save
        calls << :save
        raise StandardError, 'cannot save'
      end
    end.new([])

    result = run_cleanup(vars: failing_vars)

    expect(result).not_to be_completed
    expect(result).to be_scripts_drained
    expect(result).not_to be_vars_saved
    expect(result.failures).to eq(['Vars.save: StandardError: cannot save'])
    expect(Lich).to have_received(:log).with(
      'warning: Vars.save failed during best-effort shutdown cleanup: StandardError: cannot save'
    )
  end

  it 'does not mark scripts drained when the drain leaves scripts registered' do
    script_drain_result.scripts_remaining = 1
    script_drain_result.details = 'scripts_started=2 slow_scripts=[] scripts_remaining=1 remaining_scripts=["slow"]'

    result = run_cleanup

    expect(result).not_to be_completed
    expect(result).not_to be_scripts_drained
    expect(Lich).to have_received(:log).with(
      'warning: best-effort shutdown cleanup script drain scripts_started=2 slow_scripts=[] scripts_remaining=1 remaining_scripts=["slow"]'
    )
  end

  it 'logs slow script drain detail without marking cleanup failed' do
    script_drain_result.slow_scripts = ['slow=1.500s']
    script_drain_result.details = 'scripts_started=1 slow_scripts=["slow=1.500s"] scripts_remaining=0'

    result = run_cleanup

    expect(result).to be_completed
    expect(Lich).to have_received(:log).with(
      'info: best-effort shutdown cleanup script drain scripts_started=1 slow_scripts=["slow=1.500s"] scripts_remaining=0'
    )
  end

  it 'rejects invalid cleanup dependencies' do
    expect {
      run_cleanup(vars: Object.new)
    }.to raise_error(ArgumentError, 'vars must respond to #save')
  end
end
