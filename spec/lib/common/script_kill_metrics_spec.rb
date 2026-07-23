# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/common/feature_flags'
# Load the real hook classes so Script's kill cleanup resolves them
# deterministically (rather than the top-level spec_helper mocks), letting us
# assert the cleanup actually removes a registered hook.
require_relative '../../../lib/common/downstreamhook'
require_relative '../../../lib/common/upstreamhook'

RSpec.describe 'Lich::Common::Script kill metrics' do
  let(:thread_group) { instance_double(ThreadGroup, list: [], add: true) }
  let(:script_class) { Lich::Common::Script }

  before(:context) do
    require_relative '../../../lib/common/script'
  end

  after(:context) do
    %i[ExecScript WizardScript Script Scripting TRUSTED_SCRIPT_BINDING].each do |const_name|
      Lich::Common.send(:remove_const, const_name) if Lich::Common.const_defined?(const_name, false)
    end
    $LOADED_FEATURES.delete_if { |path| path.end_with?('/lib/common/script.rb') }
  end

  before do
    script_class.class_variable_set(:@@running, [])
    script_class.class_variable_set(:@@kill_metrics, {
      :minute            => nil,
      :runtime_stops     => 0,
      :duration_total_ms => 0.0,
      :duration_max_ms   => 0.0,
      :failures          => 0
    })
    # Start each example with empty hook registries so a hook left by one
    # example never affects another (these are class-level state).
    Lich::Common::DownstreamHook.class_variable_set(:@@downstream_hooks, {})
    Lich::Common::DownstreamHook.class_variable_set(:@@downstream_hook_sources, {})
    Lich::Common::DownstreamHook.class_variable_set(:@@downstream_hook_owners, {})
    Lich::Common::DownstreamHook.class_variable_set(:@@downstream_hook_persist, {})
    Lich::Common::UpstreamHook.class_variable_set(:@@upstream_hooks, {})
    Lich::Common::UpstreamHook.class_variable_set(:@@upstream_hook_sources, {})
    Lich::Common::UpstreamHook.class_variable_set(:@@upstream_hook_owners, {})
    Lich::Common::UpstreamHook.class_variable_set(:@@upstream_hook_persist, {})
    allow(Lich).to receive(:log)
    allow(Lich::Common::FeatureFlags).to receive(:enabled?).with(:script_kill_metrics).and_return(false)
    allow(Thread).to receive(:new) { |&block| block.call; instance_double(Thread) }
    allow(GC).to receive(:start)
  end

  after do
    script_class.class_variable_set(:@@running, [])
  end

  describe '#kill' do
    it 'removes the script without forcing garbage collection' do
      script = build_script
      script_class.class_variable_set(:@@running, [script])

      expect(script.kill).to eq('metric-target')

      expect(script_class.list).to be_empty
      expect(GC).not_to have_received(:start)
    end

    it 'removes the dying script\'s persist: false hooks and clears its watchfor' do
      script = build_script(name: 'hooky')
      other_owner = Object.new.object_id # a different live script instance

      # Hooks the dying script scoped to itself (persist: false) are removed;
      # a hook owned by another instance is left alone.
      Lich::Common::DownstreamHook.class_variable_set(
        :@@downstream_hooks, { 'hooky-down' => proc { |s| s }, 'keep' => proc { |s| s } }
      )
      Lich::Common::DownstreamHook.class_variable_set(
        :@@downstream_hook_owners, { 'hooky-down' => script.object_id, 'keep' => other_owner }
      )
      Lich::Common::DownstreamHook.class_variable_set(
        :@@downstream_hook_persist, { 'hooky-down' => false, 'keep' => false }
      )
      Lich::Common::UpstreamHook.class_variable_set(:@@upstream_hooks, { 'hooky-up' => proc { |s| s } })
      Lich::Common::UpstreamHook.class_variable_set(:@@upstream_hook_owners, { 'hooky-up' => script.object_id })
      Lich::Common::UpstreamHook.class_variable_set(:@@upstream_hook_persist, { 'hooky-up' => false })

      script.instance_variable_set(:@watchfor, { /trigger/ => proc {} })
      script.instance_variable_set(:@downstream_buffer, ['pending'])
      script.instance_variable_set(:@upstream_buffer, ['pending'])
      script_class.class_variable_set(:@@running, [script])

      script.kill

      # The dying script's hooks are gone; a hook owned by another instance survives.
      expect(Lich::Common::DownstreamHook.list).to contain_exactly('keep')
      expect(Lich::Common::UpstreamHook.list).to be_empty
      expect(script.watchfor).to be_empty
      # Stream buffers are reset to empty LimitedArrays (not nil) so a concurrent
      # new_downstream/new_upstream push cannot raise NoMethodError.
      expect(script.downstream_buffer).to eq([])
      expect(script.upstream_buffer).to eq([])
      expect(script.downstream_buffer).to be_a(Lich::Common::LimitedArray)
      expect(script.upstream_buffer).to be_a(Lich::Common::LimitedArray)
    end

    it 'falls back to inline cleanup when Ruby cannot allocate a cleanup thread' do
      script = build_script
      script_class.class_variable_set(:@@running, [script])
      allow(Thread).to receive(:new).and_raise(ThreadError, "can't alloc thread")
      allow(Lich::Common::FeatureFlags).to receive(:enabled?).with(:script_kill_metrics).and_return(true)
      expect(script_class).not_to receive(:__record_kill_metric)

      expect(script.kill).to eq('metric-target')

      expect(script_class.list).to be_empty
      expect(Lich).to have_received(:log).with(
        "warning: Script#kill cleanup thread unavailable for metric-target: ThreadError: can't alloc thread; running cleanup inline"
      )
    end

    it 'uses shutdown context to skip runtime kill metrics' do
      script = build_script
      script_class.class_variable_set(:@@running, [script])
      allow(Lich::Common::FeatureFlags).to receive(:enabled?).with(:script_kill_metrics).and_return(true)
      expect(script_class).not_to receive(:__record_kill_metric)

      script.kill(context: :shutdown)
    end

    it 'logs only an aggregate runtime-kill summary when the feature flag is enabled and the minute rolls over' do
      first = build_script(name: 'first')
      second = build_script(name: 'second')
      script_class.class_variable_set(:@@running, [first, second])
      allow(Lich::Common::FeatureFlags).to receive(:enabled?).with(:script_kill_metrics).and_return(true)
      allow(Time).to receive(:now).and_return(Time.at(60), Time.at(120))
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(10.0, 10.025, 20.0, 20.050)

      first.kill
      second.kill

      expect(Lich).to have_received(:log).with(
        'debug: script kill metrics runtime_stops_last_minute=1 avg_ms=25.00 max_ms=25.00 failures=0'
      )
    end

    it 'records a failed metric when an at_exit proc raises during runtime kill' do
      first = build_script(name: 'first')
      second = build_script(name: 'second')
      first.at_exit { raise 'cleanup failed' }
      script_class.class_variable_set(:@@running, [first, second])
      allow(Lich::Common::FeatureFlags).to receive(:enabled?).with(:script_kill_metrics).and_return(true)
      allow(Time).to receive(:now).and_return(Time.at(60), Time.at(120))
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(10.0, 10.025, 20.0, 20.050)

      first.kill
      second.kill

      expect(Lich).to have_received(:log).with(
        'debug: script kill metrics runtime_stops_last_minute=1 avg_ms=25.00 max_ms=25.00 failures=1'
      )
    end
  end

  describe 'internal kill metric helpers' do
    it 'returns false when feature flags are unavailable' do
      feature_flags = Lich::Common.send(:remove_const, :FeatureFlags)

      expect(script_class.__send__(:__script_kill_metrics_enabled?)).to be(false)
    ensure
      Lich::Common.const_set(:FeatureFlags, feature_flags) if feature_flags
    end

    it 'returns false and logs when feature flag lookup raises' do
      allow(Lich::Common::FeatureFlags).to receive(:enabled?).with(:script_kill_metrics).and_raise(StandardError, 'flag read failed')

      expect(script_class.__send__(:__script_kill_metrics_enabled?)).to be(false)
      expect(Lich).to have_received(:log).with('warning: script kill metrics flag check failed: StandardError: flag read failed')
    end

    it 'counts failed runtime kills in the next aggregate summary' do
      allow(Lich::Common::FeatureFlags).to receive(:enabled?).with(:script_kill_metrics).and_return(true)
      allow(Time).to receive(:now).and_return(Time.at(60), Time.at(120))

      script_class.__send__(:__record_kill_metric, :duration_ms => 12.5, :failed => true)
      script_class.__send__(:__record_kill_metric, :duration_ms => 1.0, :failed => false)

      expect(Lich).to have_received(:log).with(
        'debug: script kill metrics runtime_stops_last_minute=1 avg_ms=12.50 max_ms=12.50 failures=1'
      )
    end
  end

  def build_script(name: 'metric-target')
    script_class.allocate.tap do |script|
      script.instance_variable_set(:@name, name)
      script.instance_variable_set(:@custom, false)
      script.instance_variable_set(:@quiet, true)
      script.instance_variable_set(:@thread_group, thread_group)
      script.instance_variable_set(:@die_with, [])
      script.instance_variable_set(:@paused, false)
      script.instance_variable_set(:@at_exit_procs, [])
      script.instance_variable_set(:@downstream_buffer, [])
      script.instance_variable_set(:@upstream_buffer, [])
      script.instance_variable_set(:@match_stack_labels, [])
      script.instance_variable_set(:@match_stack_strings, [])
      script.instance_variable_set(:@killer_mutex, Mutex.new)
      script.instance_variable_set(:@killed_externally, false)
      script.instance_variable_set(:@kill_source, nil)
    end
  end
end
