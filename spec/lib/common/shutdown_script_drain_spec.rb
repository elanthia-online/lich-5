# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/shutdown_script_drain'

RSpec.describe Lich::Common::ShutdownScriptDrain do
  def build_script(name)
    Struct.new(:name, :kill_contexts) do
      def kill(context:)
        kill_contexts << context
      end
    end.new(name, [])
  end

  def build_failing_script(name)
    Struct.new(:name) do
      def kill(context:)
        raise StandardError, "cannot kill #{name} with #{context}"
      end
    end.new(name)
  end

  it 'kills each unique script with shutdown context' do
    script = build_script('fast')

    result = described_class.run(
      initial_scripts: [script, script],
      remaining_scripts: proc { [] },
      slow_threshold: 1.5,
      clock: proc { 0.0 },
      sleeper: proc { |_duration| raise 'should not sleep' }
    )

    expect(script.kill_contexts).to eq([:shutdown])
    expect(result.details).to eq(
      'scripts_started=1 slow_script_threshold=1.500s slow_scripts=[] scripts_remaining=0 remaining_scripts=[]'
    )
  end

  it 'continues killing scripts when one shutdown kill raises' do
    failing_script = build_failing_script('broken')
    later_script = build_script('later')
    allow(Lich).to receive(:log)

    described_class.run(
      initial_scripts: [failing_script, later_script],
      remaining_scripts: proc { [] },
      slow_threshold: 1.5,
      clock: proc { 0.0 },
      sleeper: proc { |_duration| raise 'should not sleep' }
    )

    expect(later_script.kill_contexts).to eq([:shutdown])
    expect(Lich).to have_received(:log).with(
      'warning: shutdown script kill failed for broken: StandardError: cannot kill broken with shutdown'
    )
  end

  it 'adopts and kills scripts that appear while draining' do
    initial_script = build_script('initial')
    late_script = build_script('late')
    poll = 0

    result = described_class.run(
      initial_scripts: [initial_script],
      remaining_scripts: proc {
        poll += 1
        poll == 1 ? [initial_script, late_script] : []
      },
      slow_threshold: 1.5,
      clock: proc { 0.0 },
      sleeper: proc { |_duration| nil }
    )

    expect(initial_script.kill_contexts).to eq([:shutdown])
    expect(late_script.kill_contexts).to eq([:shutdown])
    expect(result.scripts_started).to eq(2)
    expect(result.scripts_remaining).to eq(0)
  end

  it 'kills a script first observed by the final status poll' do
    initial_script = build_script('initial')
    late_script = build_script('late')
    poll = 0

    result = described_class.run(
      initial_scripts: [initial_script],
      remaining_scripts: proc {
        poll += 1
        case poll
        when 1 then []
        when 2 then [late_script]
        else []
        end
      },
      slow_threshold: 1.5,
      clock: proc { 0.0 },
      sleeper: proc { |_duration| nil }
    )

    expect(late_script.kill_contexts).to eq([:shutdown])
    expect(result.scripts_started).to eq(2)
    expect(result.remaining_scripts).to be_empty
  end

  it 'includes a final-poll kill in slow-script timing' do
    now = 0.0
    late_script = Struct.new(:name) do
      define_method(:kill) do |context:|
        raise "unexpected context: #{context}" unless context == :shutdown

        now = Thread.current[:shutdown_drain_clock]
        Thread.current[:shutdown_drain_clock] = now + 2.0
      end
    end.new('late')
    poll = 0
    Thread.current[:shutdown_drain_clock] = now

    result = described_class.run(
      initial_scripts: [],
      remaining_scripts: proc {
        poll += 1
        poll == 2 ? [late_script] : []
      },
      slow_threshold: 1.5,
      clock: proc { Thread.current[:shutdown_drain_clock] },
      sleeper: proc { |_duration| nil }
    )

    expect(result.slow_scripts).to eq(['late=2.000s'])
  ensure
    Thread.current[:shutdown_drain_clock] = nil
  end

  it 'records a script that exits after the slow threshold' do
    script = build_script('slow-finished')
    now = 0.0

    result = described_class.run(
      initial_scripts: [script],
      remaining_scripts: proc { now >= 1.6 ? [] : [script] },
      slow_threshold: 1.5,
      drain_interval: 0.1,
      clock: proc { now },
      sleeper: proc { |duration| now += duration }
    )

    expect(result.slow_scripts).to eq(['slow-finished=1.600s'])
    expect(result.remaining_scripts).to eq([])
  end

  it 'records a script that remains after the bounded drain expires' do
    script = build_script('still-running')
    now = 0.0

    result = described_class.run(
      initial_scripts: [script],
      remaining_scripts: proc { [script] },
      slow_threshold: 1.0,
      drain_attempts: 3,
      drain_interval: 0.5,
      clock: proc { now },
      sleeper: proc { |duration| now += duration }
    )

    expect(result.slow_scripts).to eq(['still-running=1.500s'])
    expect(result.scripts_remaining).to eq(1)
    expect(result.remaining_scripts).to eq(['still-running'])
  end

  it 'sorts script names for stable shutdown trace details' do
    alpha = build_script('alpha')
    beta = build_script('beta')

    result = described_class.run(
      initial_scripts: [beta, alpha],
      remaining_scripts: proc { [beta, alpha] },
      slow_threshold: 0.0,
      drain_attempts: 0,
      clock: proc { 0.0 },
      sleeper: proc { |_duration| raise 'should not sleep' }
    )

    expect(result.slow_scripts).to eq(['alpha=0.000s', 'beta=0.000s'])
    expect(result.remaining_scripts).to eq(%w[alpha beta])
  end
end
