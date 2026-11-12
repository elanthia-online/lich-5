# frozen_string_literal: true

require 'zlib'
require 'timeout'
require_relative 'support/example_timeout'
require_relative '../../spec_helper'
require_relative '../../../lib/common/limitedarray'
require_relative '../../../lib/common/feature_flags'
require_relative '../../../lib/common/downstreamhook'
require_relative '../../../lib/common/upstreamhook'
require_relative '../../../lib/genie'

# On Lich's REAL Script lifecycle (lib/common/script.rb): the glue starts
# the CommandQueue::Worker on the first genie script's thread (run_genie ->
# ensure_downstream_hook! -> start_command_queue!), and Lich kills every thread of a script's
# ThreadGroup when the script ends or is killed (script.rb:2212-2214, 2747-2753). The worker
# must outlive that script, or the session's queue (`send`, `#send`, `#queue`, `-N`, the tester's
# login triggers) silently dies. Setup copied from spec/lib/common/script_lifecycle_spec.rb.
RSpec.describe 'Lich::Genie::CommandQueue::Worker under a real Lich script lifecycle' do
  let(:script_class) { Lich::Common::Script }

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
    WORKER_PROBE[:worker]&.instance_variable_get(:@thread)&.kill if defined?(WORKER_PROBE)
  end

  # The script builds and starts the worker on its own thread, proves it drains while the
  # script lives, then either ends or parks until killed.
  def run_starter_script(ending)
    Dir.mktmpdir('genie-queue-lifecycle') do |root|
      FileUtils.mkdir_p(File.join(root, 'custom'))
      File.write(File.join(root, 'custom', 'starter.lic'), <<~RUBY)
        # quiet
        WORKER_PROBE[:worker] = Lich::Genie::CommandQueue::Worker.new(
          queue: WORKER_PROBE[:queue], state: -> { Lich::Genie::CommandQueue::FREE },
          run: ->(action, _owner) { WORKER_PROBE[:ran] << action }, report: ->(e) { WORKER_PROBE[:ran] << e }
        )
        WORKER_PROBE[:thread] = WORKER_PROBE[:worker].start
        WORKER_PROBE[:queue].add(0, 'while-alive', wait_rt: false)
        WORKER_PROBE[:ready] << :started
        #{ending == :killed ? 'sleep' : 'nil'}
        Done:
        nil
      RUBY
      stub_const('SCRIPT_DIR', root)
      stub_const('WORKER_PROBE', { queue: Lich::Genie::CommandQueue.new, ran: Thread::Queue.new, ready: Thread::Queue.new })
      script = script_class.start('starter')
      expect(Timeout.timeout(5) { WORKER_PROBE[:ready].pop }).to eq(:started)
      expect(Timeout.timeout(5) { WORKER_PROBE[:ran].pop }).to eq('while-alive')
      script.kill if ending == :killed
      expect(script.join(5)).to be_truthy
      yield
    end
  end

  %i[ended killed].each do |ending|
    it "keeps draining after the script that started it has #{ending} (its ThreadGroup is gone)" do
      run_starter_script(ending) do
        expect(script_class.running).to be_empty
        expect(WORKER_PROBE[:worker].alive?).to be(true)
        WORKER_PROBE[:queue].add(0, 'after-exit', wait_rt: false)
        expect(Timeout.timeout(5) { WORKER_PROBE[:ran].pop }).to eq('after-exit')
        expect(WORKER_PROBE[:thread].group).to be(ThreadGroup::Default)
      end
    end
  end
end
