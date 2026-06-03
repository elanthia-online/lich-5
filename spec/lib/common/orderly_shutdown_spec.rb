# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/shutdown_coordinator'
require_relative '../../../lib/common/orderly_shutdown'

RSpec.describe Lich::Common::OrderlyShutdown do
  def run_orderly_shutdown(**overrides)
    scripts = overrides.fetch(:initial_scripts, [])
    described_class.run(
      coordinator: overrides.fetch(:coordinator, coordinator),
      initial_scripts: scripts,
      remaining_scripts: overrides.fetch(:remaining_scripts, proc { [] }),
      script_drain: overrides.fetch(:script_drain, script_drain),
      vars: overrides.fetch(:vars, vars),
      game: overrides.fetch(:game, game),
      active_sessions_lifecycle: overrides.fetch(:active_sessions_lifecycle, active_sessions_lifecycle)
    )
  end

  def request_user_exit(**overrides)
    described_class.request_user_exit(
      source: overrides.fetch(:source, :script),
      current_script: overrides[:current_script],
      coordinator: overrides.fetch(:coordinator, coordinator),
      scripts_provider: overrides.fetch(:scripts_provider, proc { [] }),
      script_drain: overrides.fetch(:script_drain, script_drain),
      vars: overrides.fetch(:vars, vars),
      game: overrides.fetch(:game, game),
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

  let(:game) do
    Struct.new(:calls) do
      def close
        calls << :close
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
    coordinator.request(reason: :user_exit, source: :primary_frontend)
    allow(Lich).to receive(:log)
  end

  after do
    coordinator.reset!
  end

  it 'runs local shutdown work before closing the game connection' do
    result = run_orderly_shutdown(initial_scripts: %w[alpha beta])

    expect(active_sessions_lifecycle.calls).to eq([false])
    expect(script_drain.calls.first[:initial_scripts]).to eq(%w[alpha beta])
    expect(script_drain.calls.first[:slow_threshold]).to eq(1.5)
    expect(vars.calls).to eq([:save])
    expect(game.calls).to eq([:close])
    expect(result).to be_completed
    expect(result).to be_scripts_drained
    expect(result).to be_vars_saved
    expect(result).to be_game_closed
    expect(result.script_shutdown_result).to equal(script_drain_result)
    expect(coordinator.orderly_shutdown_result).to equal(result)
  end

  it 'only runs the orderly shutdown sequence once' do
    first = run_orderly_shutdown
    second = run_orderly_shutdown

    expect(second).to equal(first)
    expect(script_drain.calls.length).to eq(1)
    expect(vars.calls).to eq([:save])
    expect(game.calls).to eq([:close])
  end

  it 'requests user exit and excludes the calling script from the drain' do
    coordinator.reset!
    current_script = Struct.new(:name).new('shutdown-caller')
    other_script = Struct.new(:name).new('other')

    result = request_user_exit(
      source: 'script:shutdown-caller',
      current_script: current_script,
      scripts_provider: proc { [current_script, other_script] }
    )

    expect(result).to be_completed
    expect(coordinator.reason).to eq(:user_exit)
    expect(coordinator.current.source).to eq('script:shutdown-caller')
    expect(script_drain.calls.first[:initial_scripts]).to eq([other_script])
    expect(script_drain.calls.first[:remaining_scripts].call).to eq([other_script])
  end

  it 'continues later cleanup steps when one step fails' do
    failing_vars = Struct.new(:calls) do
      def save
        calls << :save
        raise StandardError, 'cannot save'
      end
    end.new([])

    result = run_orderly_shutdown(vars: failing_vars)

    expect(result).not_to be_completed
    expect(result).to be_scripts_drained
    expect(result).not_to be_vars_saved
    expect(result.failures).to eq(['Vars.save: StandardError: cannot save'])
    expect(game.calls).to eq([:close])
    expect(Lich).to have_received(:log).with(
      'warning: Vars.save failed during orderly user shutdown: StandardError: cannot save'
    )
  end

  it 'does not mark scripts drained when the drain leaves scripts registered' do
    script_drain_result.scripts_remaining = 1
    script_drain_result.details = 'scripts_started=2 slow_scripts=[] scripts_remaining=1 remaining_scripts=["slow"]'

    result = run_orderly_shutdown

    expect(result).not_to be_completed
    expect(result).not_to be_scripts_drained
    expect(Lich).to have_received(:log).with(
      'warning: orderly user shutdown script drain scripts_started=2 slow_scripts=[] scripts_remaining=1 remaining_scripts=["slow"]'
    )
  end

  it 'logs slow script drain detail without marking shutdown failed' do
    script_drain_result.slow_scripts = ['slow=1.500s']
    script_drain_result.details = 'scripts_started=1 slow_scripts=["slow=1.500s"] scripts_remaining=0'

    result = run_orderly_shutdown

    expect(result).to be_completed
    expect(Lich).to have_received(:log).with(
      'info: orderly user shutdown script drain scripts_started=1 slow_scripts=["slow=1.500s"] scripts_remaining=0'
    )
  end

  it 'requires a user-exit shutdown reason' do
    coordinator.reset!
    coordinator.request(reason: :game_eof, source: :game_reader)

    expect {
      run_orderly_shutdown
    }.to raise_error(ArgumentError, 'orderly user exit requires reason=:user_exit')
  end

  it 'rejects invalid orderly shutdown dependencies' do
    expect {
      run_orderly_shutdown(vars: Object.new)
    }.to raise_error(ArgumentError, 'vars must respond to #save')
  end
end
